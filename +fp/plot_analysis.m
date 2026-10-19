function figures=plot_analysis(result,p,visible)
% One square trace figure and one square heatmap figure per ROI/condition.
rows=result.PlotRows; groups=result.PlotGroups; grid=result.Time; unit=result.PlotUnit;
p.Settings=fp.plot_settings(p.Settings); display=p.Settings;
curveLimits=sharedCurveLimits(rows,groups,display);
figures=gobjects(0); out=result.OutputFolder;
displayRecord=struct('HeatmapRowLabels',display.HeatmapRowLabels, ...
    'ShowIndividualTraces',logical(display.ShowIndividualTraces), ...
    'RequestedCurveYLim',display.CurveYLim,'AppliedSharedCurveYLim',curveLimits);
fid=fopen(fullfile(out,'plot_display_settings.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot save plot display settings.');
fprintf(fid,'%s',jsonencode(displayRecord,PrettyPrint=true)); fclose(fid);
colors=[0.92 0.39 0.08;0.12 0.40 0.70;0.21 0.58 0.35;0.58 0.28 0.65;0.50 0.35 0.20];
sessions=unique(string({rows.SessionLabel}),'stable'); count=0;
groupExport=table();
for k=1:numel(groups)
    a=groups(k); n=numel(grid);
    t=table(repmat(string(a.Group),n,1),repmat(string(a.SessionLabel),n,1), ...
        repmat(string(a.ROI),n,1),repmat(string(a.Behavior),n,1),repmat(string(unit),n,1), ...
        grid(:),a.Mean(:),a.SEM(:),repmat(a.N_units,n,1),repmat(a.N_animals,n,1),repmat(a.N_trials,n,1), ...
        'VariableNames',{'Group','Session','ROI','Behavior','Unit','Time_s','Mean','SEM','N_units','N_animals','N_trials'});
    groupExport=[groupExport;t]; %#ok<AGROW>
end
writetable(groupExport,fullfile(out,'plot_group_mean_SEM.csv'));
try
for session=sessions
    for r=1:numel(p.ROIs)
        roi=p.ROIs(r).Name;
        chosen=rows(strcmp({rows.SessionLabel},session) & strcmp({rows.ROI},roi));
        if isempty(chosen), continue; end
        behaviors=p.Behaviors; nb=numel(behaviors); cols=min(2,nb); nrows=ceil(nb/cols);
        count=count+1;
        trace=figure('Name',sprintf('%d | Traces | %s | %s | %s',count,roi,session,unit), ...
            'Visible',visible,'Color','w','Position',[60 60 900 900],'Tag','FPAnalysisPlot');
        figures(end+1)=trace; trace.UserData=struct('ROI',roi,'Type','traces','Unit',unit);
        layout=tiledlayout(trace,nrows,cols,'TileSpacing','compact','Padding','compact');
        title(layout,caption(roi,session,unit,'traces'),'Interpreter','none');
        for b=1:nb
            ax=nexttile(layout); hold(ax,'on'); found=false;
            for g=1:numel(p.Groups)
                a=chosen(strcmp({chosen.Behavior},behaviors{b}) & strcmp({chosen.Group},p.Groups{g}));
                stats=groups(strcmp({groups.SessionLabel},session) & strcmp({groups.ROI},roi) & ...
                    strcmp({groups.Behavior},behaviors{b}) & strcmp({groups.Group},p.Groups{g}));
                if isempty(a) || isempty(stats), continue; end
                found=true; stats=stats(1); color=colors(mod(g-1,size(colors,1))+1,:);
                if display.ShowIndividualTraces
                    plot(ax,grid,vertcat(a.Mean)','Color',[.82 .82 .82],'HandleVisibility','off', ...
                        'LineWidth',.5,'Tag','FPIndividualTrace');
                end
                ok=isfinite(stats.Mean) & isfinite(stats.SEM);
                if any(ok)
                    x=grid(ok); mu=stats.Mean(ok); se=stats.SEM(ok);
                    fill(ax,[x fliplr(x)],[mu+se fliplr(mu-se)],color,'FaceAlpha',.18,'EdgeColor','none','HandleVisibility','off','Tag','FPGroupSEM');
                end
                plot(ax,grid,stats.Mean,'Color',color,'LineWidth',2,'Tag','FPGroupMean', ...
                    'DisplayName',sprintf('%s: %d animals, %d trials',p.Groups{g},stats.N_animals,stats.N_trials));
            end
            xline(ax,0,'k--','HandleVisibility','off'); xlabel(ax,'Time from onset (s)'); ylabel(ax,units(p.Settings));
            title(ax,behaviors{b},'Interpreter','none'); style(ax); pbaspect(ax,[1 1 1]);
            ax.Tag='FPTracePanel';
            ylim(ax,curveLimits);
            if found, legend(ax,'show','Location','southoutside','Interpreter','none','FontSize',8);
            else, text(ax,.5,.5,'No accepted events','Units','normalized','HorizontalAlignment','center'); end
        end
        stem=sprintf('%03d_%s_%s_%s_traces',count,safe(session),safe(roi),unit);
        squareExport(trace,fullfile(out,[stem '.png'])); savefig(trace,fullfile(out,[stem '.fig']));
        count=count+1;
        heat=figure('Name',sprintf('%d | Heatmaps | %s | %s | %s',count,roi,session,unit), ...
            'Visible',visible,'Color','w','Position',[90 50 900 900],'Tag','FPAnalysisPlot');
        figures(end+1)=heat; heat.UserData=struct('ROI',roi,'Type','heatmaps','Unit',unit);
        layout=tiledlayout(heat,nb,numel(p.Groups),'TileSpacing','compact','Padding','compact');
        title(layout,caption(roi,session,unit,'heatmaps'),'Interpreter','none');
        pooled=vertcat(chosen.Mean); limits=p.Settings.HeatmapCLim;
        if isempty(limits), limits=prctile(pooled(:),p.Settings.HeatmapPercentiles); end
        if limits(1)==limits(2), limits=limits+[-1 1]*max(abs(limits(1))*.01,1e-5); end
        map=table();
        for b=1:nb
            for g=1:numel(p.Groups)
                ax=nexttile(layout); ax.Tag='FPHeatmapPanel';
                a=chosen(strcmp({chosen.Behavior},behaviors{b}) & strcmp({chosen.Group},p.Groups{g}));
                title(ax,sprintf('%s | %s',behaviors{b},p.Groups{g}),'Interpreter','none','FontSize',9);
                if isempty(a), text(ax,.5,.5,'No accepted events','HorizontalAlignment','center'); axis(ax,'off'); continue; end
                [~,order]=sort([a.AUC],p.Settings.SortOrder); a=a(order);
                imagesc(ax,grid,1:numel(a),vertcat(a.Mean)); ax.YDir='reverse';
                clim(ax,limits); colormap(ax,parula); xline(ax,0,'w--');
                % These numbers are positions AFTER AUC sorting, not original event IDs.
                if strcmp(display.HeatmapRowLabels,'endpoints')
                    ticks=unique([1 numel(a)]);
                    yticks(ax,ticks); yticklabels(ax,cellstr(string(ticks)));
                    ylabel(ax,[unit ' number']);
                else
                    ticks=unique(round(linspace(1,numel(a),min(10,numel(a)))));
                    labels=string({a(ticks).RowID});
                    if strcmp(unit,'trial'), labels=string(ticks)+": "+labels; end
                    yticks(ax,ticks); yticklabels(ax,cellstr(labels)); ylabel(ax,[unit ' rows']);
                end
                ax.TickLabelInterpreter='none'; xlabel(ax,'Time from onset (s)');
                style(ax); ax.FontSize=8; pbaspect(ax,[1 1 1]);
                ax.Tag='FPHeatmapPanel';
                title(ax,sprintf('%s | %s',behaviors{b},p.Groups{g}),'Interpreter','none','FontSize',9);
                for n=1:numel(a)
                    v=a(n);
                    t=table(string(session),string(roi),string(behaviors{b}),string(p.Groups{g}),string(unit), ...
                        n,string(v.RowID),string(v.AnimalID),string(v.SessionID),v.EventIndex,v.Onset_s,v.AUC,v.TrialCount, ...
                        'VariableNames',{'Session','ROI','Behavior','Group','Unit','HeatmapRowTopToBottom', ...
                        'RowID','AnimalID','SessionID','EventIndex','Onset_s','SignedBaselineSubtractedAUC','TrialCount'});
                    if strcmp(unit,'trial'), t.Event="E"+string(v.EventIndex); else, t.Event=""; end
                    map=[map;t]; %#ok<AGROW>
                end
            end
        end
        cb=colorbar(ax); cb.Layout.Tile='east'; ylabel(cb,units(p.Settings));
        stem=sprintf('%03d_%s_%s_%s_heatmaps',count,safe(session),safe(roi),unit);
        squareExport(heat,fullfile(out,[stem '.png'])); savefig(heat,fullfile(out,[stem '.fig']));
        writetable(map,fullfile(out,[stem '_heatmap_rows.csv']));
    end
end
catch ME
    delete(figures(isgraphics(figures))); rethrow(ME);
end
if strcmp(visible,'off'), close(figures); figures=gobjects(0); end
end
function limits=sharedCurveLimits(rows,groups,s)
if ~isempty(s.CurveYLim), limits=reshape(s.CurveYLim,1,2); return; end
values=[];
for k=1:numel(groups)
    g=groups(k); values=[values g.Mean g.Mean-g.SEM g.Mean+g.SEM]; %#ok<AGROW>
end
if s.ShowIndividualTraces && ~isempty(rows), values=[values reshape(vertcat(rows.Mean),1,[])]; end
values=values(isfinite(values));
if isempty(values), limits=[-1 1]; return; end
limits=[min(values) max(values)]; span=diff(limits);
if span==0, span=max(abs(limits(1))*.1,1e-5); end
limits=limits+[-1 1]*span*.05;
end
function text=caption(roi,session,unit,type)
if strcmp(type,'heatmaps')
    if strcmp(unit,'animal'), note='Each row: one animal (mean of its accepted trials)';
    else, note='Each row: one trial (nested within animals)'; end
elseif strcmp(unit,'animal'), note='mean / SEM across animals';
else, note='mean / SEM across trials (nested within animals; descriptive)'; end
text={sprintf('%s | %s',roi,session),note};
end
function squareExport(fig,path)
set(fig,'PaperUnits','inches','PaperPosition',[0 0 8 8],'PaperSize',[8 8]);
print(fig,path,'-dpng','-r160');
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
