function result=fp_analyze_project(projectFile,varargin)
% Event alignment + LP + event-baseline normalization adapted from V1_3.
% Biological replicate = animal; trials/sessions are not independent animals.
ip=inputParser; addParameter(ip,'Visible','on'); addParameter(ip,'MakeFigures',true); parse(ip,varargin{:});
p=fp.load_project(projectFile); s=p.Settings;
assert(any([p.Sessions.Include]),'No included sessions.');
if s.LowpassHz>0
    assert(exist('butter','file')==2 && exist('filtfilt','file')==2,'Signal Processing Toolbox required for low-pass filtering.');
end
grid=(ceil(s.PreTime*s.OutputFs):floor(s.PostTime*s.OutputFs))/s.OutputFs;
assert(any(grid==0),'Output time grid must contain onset 0.');
base=grid>=s.Baseline(1) & grid<s.Baseline(2);
aucMask=grid>=s.AUCWindow(1) & grid<=s.AUCWindow(2);
assert(nnz(base)>=2 && nnz(aucMask)>=2,'Baseline and AUC windows need at least 2 samples.');
trials=struct('AnimalID',{},'Group',{},'SessionLabel',{},'SessionID',{},'ROI',{},'Behavior',{},'EventIndex',{},'Onset_s',{},'Values',{});
qc=struct('SessionID',{},'AnimalID',{},'ROI',{},'Behavior',{},'EventIndex',{},'Onset_s',{},'Accepted',{},'Reason',{});
inputFiles=struct('SessionID',{},'SelectedCSV',{},'ReadCSV',{},'Timing',{},'Video',{},'VideoDuration_s',{},'VideoOffset_s',{},'SyncConfirmed',{},'EventsFile',{});
for k=find([p.Sessions.Include])
    record=p.Sessions(k); tags=fp.load_events(p,record.ID);
    animal=p.Animals(strcmp({p.Animals.ID},record.AnimalID));
    if s.RequireConfirmedSync && ~record.SyncConfirmed
        qc(end+1)=qrow(record,'','',0,NaN,false,'sync_not_confirmed'); %#ok<AGROW>
        continue;
    end
    if isempty(tags)
        qc(end+1)=qrow(record,'','',0,NaN,false,'no_behavior_events'); %#ok<AGROW>
        continue;
    end
    try
        data=fp.read_recording(record.CSV,p.ROIs);
        videoInfo=VideoReader(record.Video); videoDuration=videoInfo.Duration;
        inputFiles(end+1)=struct('SessionID',record.ID,'SelectedCSV',record.CSV,'ReadCSV',data.ReadFile, ...
            'Timing',data.Timing,'Video',record.Video,'VideoDuration_s',videoDuration, ...
            'VideoOffset_s',record.VideoOffset_s,'SyncConfirmed',record.SyncConfirmed, ...
            'EventsFile',fp.event_file(p,record.ID)); %#ok<AGROW>
    catch ME
        qc(end+1)=qrow(record,'','',0,NaN,false,['import_error: ' ME.message]); %#ok<AGROW>
        continue;
    end
    for r=1:numel(p.ROIs)
        [t,y]=fp.process_trace(data.ROIs(r),s.SignalMode,s);
        dt=median(diff(t));
        for e=1:height(tags)
            behavior=char(tags.Behavior(e)); onset=tags.Time_signal_s(e); desired=onset+grid;
            reason=''; values=[];
            if ~ismember(string(behavior),string(p.Behaviors)) || ~isfinite(onset)
                reason='invalid_behavior_or_time';
            elseif onset-record.VideoOffset_s<0 || onset-record.VideoOffset_s>=videoDuration
                reason='event_onset_outside_video';
            elseif desired(1)<t(1) || desired(end)>t(end)
                reason='event_window_outside_recording';
            else
                gap=find(diff(t)>s.MaxGapFactor*dt);
                crosses=any(desired(1)<t(gap+1) & desired(end)>t(gap));
                if crosses, reason='timestamp_gap'; else
                    values=interp1(t,y,desired,'linear',NaN);
                    if any(~isfinite(values)), reason='missing_or_invalid_signal'; end
                end
            end
            if isempty(reason)
                f0=mean(values(base));
                switch s.Normalization
                    case 'dff_percent'
                        if f0<=1e-6, reason='invalid_baseline_F0'; else, values=100*(values-f0)/f0; end
                    case 'baseline_subtract', values=values-f0;
                    case 'none'
                    otherwise, error('Unknown normalization.');
                end
            end
            accepted=isempty(reason);
            if accepted
                reason='accepted';
                trials(end+1)=struct('AnimalID',record.AnimalID,'Group',animal.Group,'SessionLabel',record.Label, ...
                    'SessionID',record.ID,'ROI',p.ROIs(r).Name,'Behavior',behavior,'EventIndex',e, ...
                    'Onset_s',onset,'Values',values); %#ok<AGROW>
            end
            qc(end+1)=qrow(record,p.ROIs(r).Name,behavior,e,onset,accepted,reason); %#ok<AGROW>
        end
    end
end
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS')); out=fullfile(p.Root,'results',['analysis_' stamp]);
assert(~isfolder(out),'Output folder already exists.'); mkdir(out);
snapshot=p; save(fullfile(out,'project_snapshot.mat'),'snapshot');
fid=fopen(fullfile(out,'project_snapshot.json'),'w','n','UTF-8'); fprintf(fid,'%s',jsonencode(p,PrettyPrint=true)); fclose(fid);
if ~isempty(qc), writetable(struct2table(qc),fullfile(out,'trial_QC.csv')); end
if ~isempty(inputFiles), writetable(struct2table(inputFiles),fullfile(out,'input_provenance.csv')); end
animals=animalMeans(trials,grid,base,aucMask,s.SortOrder);
groups=groupMeans(animals,grid);
result=struct('OutputFolder',out,'Time',grid,'Trials',trials,'Animals',animals,'Groups',groups,'QC',qc,'Settings',s);
save(fullfile(out,'analysis_results.mat'),'result','-v7.3');
exportTables(out,animals,groups,grid);
if ip.Results.MakeFigures && ~isempty(animals)
    drawFigures(out,p,animals,groups,grid,ip.Results.Visible);
end
fprintf('FP analysis: %d accepted ROI-trials, %d animal/condition/ROI/behavior means.\n%s\n',numel(trials),numel(animals),out);
if isempty(trials), warning('FP:NoTrials','No accepted trials. Review trial_QC.csv, event tags and sync confirmation; no group figures generated.'); end
end

function q=qrow(r,roi,behavior,index,onset,accepted,reason)
q=struct('SessionID',r.ID,'AnimalID',r.AnimalID,'ROI',roi,'Behavior',behavior, ...
    'EventIndex',index,'Onset_s',onset,'Accepted',accepted,'Reason',reason);
end

function animals=animalMeans(trials,grid,base,aucMask,sortOrder)
animals=struct('AnimalID',{},'Group',{},'SessionLabel',{},'ROI',{},'Behavior',{}, ...
    'TrialCount',{},'SessionCount',{},'Mean',{},'AUC',{},'SortOrder',{});
if isempty(trials), return; end
keys=unique(string({trials.AnimalID})+"|"+string({trials.Group})+"|"+string({trials.SessionLabel})+"|"+string({trials.ROI})+"|"+string({trials.Behavior}),'stable');
allKeys=string({trials.AnimalID})+"|"+string({trials.Group})+"|"+string({trials.SessionLabel})+"|"+string({trials.ROI})+"|"+string({trials.Behavior});
for key=keys
    subset=trials(allKeys==key); row=subset(1); matrix=vertcat(subset.Values); m=mean(matrix,1);
    signedAUC=trapz(grid(aucMask),m(aucMask)-mean(m(base)));
    animals(end+1)=struct('AnimalID',row.AnimalID,'Group',row.Group,'SessionLabel',row.SessionLabel, ...
        'ROI',row.ROI,'Behavior',row.Behavior,'TrialCount',numel(subset), ...
        'SessionCount',numel(unique(string({subset.SessionID}))),'Mean',m,'AUC',signedAUC,'SortOrder',sortOrder); %#ok<AGROW>
end
end

function groups=groupMeans(animals,grid)
groups=struct('Group',{},'SessionLabel',{},'ROI',{},'Behavior',{},'AnimalCount',{},'TrialCount',{},'Mean',{},'SEM',{});
if isempty(animals), return; end
allKeys=string({animals.Group})+"|"+string({animals.SessionLabel})+"|"+string({animals.ROI})+"|"+string({animals.Behavior});
for key=unique(allKeys,'stable')
    subset=animals(allKeys==key); row=subset(1); matrix=vertcat(subset.Mean); n=size(matrix,1);
    if n>=2, sem=std(matrix,0,1)/sqrt(n); else, sem=nan(size(grid)); end
    groups(end+1)=struct('Group',row.Group,'SessionLabel',row.SessionLabel,'ROI',row.ROI, ...
        'Behavior',row.Behavior,'AnimalCount',n,'TrialCount',sum([subset.TrialCount]), ...
        'Mean',mean(matrix,1),'SEM',sem); %#ok<AGROW>
end
end

function exportTables(out,animals,groups,grid)
if isempty(animals), return; end
T=struct2table(rmfield(animals,'Mean')); writetable(T,fullfile(out,'animal_summary_AUC.csv'));
animalRows=table(); groupRows=table();
for i=1:numel(animals)
    r=animals(i); n=numel(grid);
    row=table(repmat(string(r.AnimalID),n,1),repmat(string(r.Group),n,1), ...
        repmat(string(r.SessionLabel),n,1),repmat(string(r.ROI),n,1),repmat(string(r.Behavior),n,1),grid(:),r.Mean(:), ...
        'VariableNames',{'AnimalID','Group','Session','ROI','Behavior','Time_s','AnimalMean'});
    animalRows=[animalRows;row]; %#ok<AGROW>
end
for i=1:numel(groups)
    r=groups(i); n=numel(grid);
    row=table(repmat(string(r.Group),n,1),repmat(string(r.SessionLabel),n,1), ...
        repmat(string(r.ROI),n,1),repmat(string(r.Behavior),n,1),grid(:),r.Mean(:),r.SEM(:), ...
        repmat(r.AnimalCount,n,1),repmat(r.TrialCount,n,1), ...
        'VariableNames',{'Group','Session','ROI','Behavior','Time_s','Mean','SEM','N_animals','N_trials'});
    groupRows=[groupRows;row]; %#ok<AGROW>
end
writetable(animalRows,fullfile(out,'animal_mean_traces.csv'));
writetable(groupRows,fullfile(out,'group_mean_SEM.csv'));
end

function drawFigures(out,p,animals,groups,grid,visible)
combos=unique(string({groups.SessionLabel})+"|"+string({groups.ROI})+"|"+string({groups.Behavior}),'stable');
allKeys=string({groups.SessionLabel})+"|"+string({groups.ROI})+"|"+string({groups.Behavior});
colors=[0.92 0.39 0.08;0.12 0.40 0.70;0.21 0.58 0.35;0.58 0.28 0.65;0.50 0.35 0.20];
for c=1:numel(combos)
    selected=groups(allKeys==combos(c)); row=selected(1);
    fig=figure('Name',sprintf('%s | %s | %s',row.SessionLabel,row.ROI,row.Behavior),'Visible',visible,'Color','w', ...
        'Position',[80 80 1250 720]);
    tiles=tiledlayout(fig,2,numel(p.Groups),'TileSpacing','compact','Padding','compact');
    ax=nexttile(tiles,[1 numel(p.Groups)]); hold(ax,'on');
    for g=1:numel(p.Groups)
        subset=selected(strcmp({selected.Group},p.Groups{g})); if isempty(subset), continue; end
        group=subset(1); color=colors(mod(g-1,size(colors,1))+1,:);
        a=animals(strcmp({animals.Group},group.Group) & strcmp({animals.SessionLabel},row.SessionLabel) & ...
            strcmp({animals.ROI},row.ROI) & strcmp({animals.Behavior},row.Behavior));
        plot(ax,grid,vertcat(a.Mean)','Color',[0.82 0.82 0.82],'HandleVisibility','off','LineWidth',0.6);
        ok=isfinite(group.Mean) & isfinite(group.SEM);
        if any(ok)
            x=grid(ok); mu=group.Mean(ok); se=group.SEM(ok);
            fill(ax,[x fliplr(x)],[mu+se fliplr(mu-se)],color,'FaceAlpha',0.18,'EdgeColor','none','HandleVisibility','off');
        end
        plot(ax,grid,group.Mean,'Color',color,'LineWidth',2,'DisplayName',sprintf('%s (n=%d animals; %d trials)',group.Group,group.AnimalCount,group.TrialCount));
    end
    xline(ax,0,'k--','HandleVisibility','off'); xlabel(ax,'Time from behavior onset (s)'); ylabel(ax,units(p.Settings));
    title(ax,sprintf('%s | %s | %s | %s',row.SessionLabel,row.ROI,row.Behavior,p.Settings.SignalMode),'Interpreter','none');
    legend(ax,'show','Location','southoutside','Interpreter','none'); style(ax);
    pooled=vertcat(animals(strcmp({animals.SessionLabel},row.SessionLabel) & strcmp({animals.ROI},row.ROI) & strcmp({animals.Behavior},row.Behavior)).Mean);
    limits=p.Settings.HeatmapCLim;
    if isempty(limits), limits=prctile(pooled(:),p.Settings.HeatmapPercentiles); end
    if limits(1)==limits(2), limits=limits+[-1 1]*max(abs(limits(1))*0.01,1e-5); end
    map=table();
    for g=1:numel(p.Groups)
        ax=nexttile(tiles); a=animals(strcmp({animals.Group},p.Groups{g}) & strcmp({animals.SessionLabel},row.SessionLabel) & ...
            strcmp({animals.ROI},row.ROI) & strcmp({animals.Behavior},row.Behavior));
        if isempty(a), text(ax,0.5,0.5,'No accepted animals','HorizontalAlignment','center'); axis(ax,'off'); continue; end
        [~,order]=sort([a.AUC],p.Settings.SortOrder); a=a(order);
        imagesc(ax,grid,1:numel(a),vertcat(a.Mean)); ax.YDir='reverse';
        clim(ax,limits); colormap(ax,parula); cb=colorbar(ax); ylabel(cb,units(p.Settings));
        yticks(ax,1:numel(a)); yticklabels(ax,{a.AnimalID});
        xline(ax,0,'w--'); xlabel(ax,'Time from onset (s)'); ylabel(ax,'Animal (mean of trials)');
        title(ax,p.Groups{g},'Interpreter','none'); style(ax);
        for n=1:numel(a)
            map=[map;table(string(p.Groups{g}),n,string(a(n).AnimalID),a(n).AUC,a(n).TrialCount, ...
                'VariableNames',{'Group','HeatmapRowTopToBottom','AnimalID','SignedBaselineSubtractedAUC','TrialCount'})]; %#ok<AGROW>
        end
    end
    stem=sprintf('%03d_%s_%s_%s_%s',c,safe(row.SessionLabel),safe(row.ROI),safe(row.Behavior),p.Settings.SignalMode);
    exportgraphics(fig,fullfile(out,[stem '.png']),'Resolution',200);
    savefig(fig,fullfile(out,[stem '.fig'])); writetable(map,fullfile(out,[stem '_heatmap_rows.csv']));
    if strcmp(visible,'off'), close(fig); end
end
end

function style(ax)
set(ax,'FontName','Arial','TickDir','out','Box','off','XGrid','off','YGrid','off');
end
function text=units(s)
switch s.Normalization
    case 'dff_percent', text='Event-baseline \DeltaF/F (%)';
    case 'baseline_subtract', text='Baseline-subtracted signal (a.u.)';
    otherwise, text='Signal (a.u.)';
end
end
function text=safe(text)
text=char(matlab.lang.makeValidName(string(text))); if numel(text)>70, text=text(1:70); end
end
