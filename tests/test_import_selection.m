function test_import_selection()
codeRoot=fileparts(fileparts(mfilename('fullpath')));addpath(codeRoot);
root=fullfile(codeRoot,'tests','artifacts',['import_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);mkdir(root);
source=fullfile(root,'source');ids={'#M1','#M2','#M3','#M4','#M5'};
groups={'01 ATP Sensor','02 Glu Sensor cyto'};
t=(0:0.05:15)'; clock=string(arrayfun(@(x)sprintf('0:00:00:%010.7f',x),t,'UniformOutput',false));
for phase=1:2
    phaseName={'2026-10-08 NPR E','2026-10-09 NPR R'};
    for a=1:5
        g=groups{1+(a==5)}; stamp=sprintf('2026100%d12%02d00',7+phase,a);
        folder=fullfile(source,phaseName{phase},g,sprintf('%02d %s',a,ids{a}),stamp);mkdir(folder);
        y=ones(size(t));y(t>=8&t<=9)=1+a+phase;
        T=table(clock,10*ones(size(t)),10*y,20*ones(size(t)),20*y, ...
            'VariableNames',{'Time','ROI-1_sig_410','ROI-1_sig_470','ROI-2_sig_410','ROI-2_sig_470'});
        writetable(T,fullfile(folder,'recording(Camera).csv'));
        w=VideoWriter(fullfile(folder,'recording.avi'),'Motion JPEG AVI');w.FrameRate=2;open(w);
        for frame=1:30,writeVideo(w,zeros(40,40,3,'uint8'));end;close(w);
    end
end
config=struct('Name','Nested import regression','BehaviorTask','NPR','Behaviors',{{'Object1'}}, ...
    'Groups',{groups},'Animals',struct('ID',ids,'Group',{groups{1},groups{1},groups{1},groups{1},groups{2}}), ...
    'ROIs',struct('SourceID',{'ROI-1','ROI-2'},'Name',{'Left','Right'}));
p=fp.create_project(fullfile(root,'project'),config,source);
assert(numel(p.Sessions)==10 && all([p.Sessions.Include]));
assert(isequal(sort(unique(string({p.Sessions.Label}))),["Encoding","Retrieval"]));
assert(all(ismember(string({p.Sessions.AnimalID}),string(ids))));
p.Settings.LowpassHz=0;p.Settings.PreTime=-2;p.Settings.PostTime=2;
p.Settings.Baseline=[-2 0];p.Settings.AUCWindow=[0 1];
for k=1:10
    p.Sessions(k).SyncConfirmed=true;
    fp.save_events(p,p.Sessions(k).ID,table("Object1",8,'VariableNames',{'Behavior','Time_signal_s'}));
end
fp.save_project(p);
separate=fp_analyze_project(p,MakeFigures=false);
g=separate.Groups(strcmp({separate.Groups.Group},groups{1}));
assert(numel(g)==4 && all([g.AnimalCount]==4) && all([g.TrialCount]==4));
p.Settings.ConditionGrouping='combine'; combined=fp_analyze_project(p,MakeFigures=false);
g=combined.Groups(strcmp({combined.Groups.Group},groups{1}));
assert(numel(g)==2 && all([g.AnimalCount]==4) && all([g.TrialCount]==8));
index=find(abs(combined.Time-0.5)<1e-8);assert(abs(g(1).Mean(index)-400)<1e-9);
assert(all([combined.Animals.SessionCount]==2));
trial=fp_analyze_project(p,MakeFigures=false,PlotUnit='trial');
assert(numel(trial.PlotGroups)==4 && all(strcmp({trial.PlotGroups.SessionLabel},'Combined conditions')));
% Legacy imports: both wrong timestamps and previously repaired IDs with mouse labels.
legacy=p;
for k=1:10
    folder=fileparts(legacy.Sessions(k).CSV);[parent,stamp]=fileparts(folder);[~,mouse]=fileparts(parent);
    legacy.Sessions(k).AnimalID=stamp;legacy.Sessions(k).Label=mouse;
end
[fixed,changes]=fp.repair_import_metadata(legacy);assert(numel(changes)==20);
assert(isequaln(fixed,p));custom=p;custom.Sessions(1).Label='Deliberate custom condition';
[custom,n]=fp.repair_import_metadata(custom);assert(isempty(n)&&strcmp(custom.Sessions(1).Label,'Deliberate custom condition'));
% Manifest with explicit metadata takes precedence; malformed manifest timestamps recover.
manifest=struct('csv',p.Sessions(1).CSV,'video',p.Sessions(1).Video,'batch','Custom manifest condition','mouse','#M1');
mkdir(fullfile(source,'_conversion'));fid=fopen(fullfile(source,'_conversion','records.json'),'w');fprintf(fid,'%s',jsonencode(manifest));fclose(fid);
r=fp.find_recordings(source);assert(strcmp(r.AnimalID,'#M1')&&strcmp(r.Label,'Custom manifest condition'));
% Persist a malformed legacy file to exercise loading before validation and the UI repair-save path.
project=legacy;save(fullfile(p.Root,'project.mat'),'project');
[loaded,changes]=fp.load_project(p.Root);assert(numel(changes)==20&&isequaln(loaded,p));
fig=fiber_photometry_project(fullfile(p.Root,'project.mat'));fig.Visible='off';
tableUI=findobj(fig,'Tag','SessionsTable'); tableUI.Data=flipud(tableUI.Data);
snapshot=tableUI.Data;
press('UncheckAll');assert(~any(tableUI.Data.Include));
dd=findobj(fig,'Tag','SelectionGroup');dd.Value=groups{1};press('CheckGroup');assert(sum(tableUI.Data.Include)==8);
dd.Value=groups{2};press('OnlyGroup');assert(sum(tableUI.Data.Include)==2);
press('CheckAll');assert(all(tableUI.Data.Include));press('UncheckGroup');assert(sum(tableUI.Data.Include)==8);
assert(isequaln(removevars(snapshot,'Include'),removevars(tableUI.Data,'Include')));
saveButton=findobj(fig,'Text','Save configuration');saveButton.ButtonPushedFcn(saveButton,[]);
saved=fp.load_project(p.Root);assert(sum([saved.Sessions.Include])==8);
assert(~isempty(dir(fullfile(p.Root,'backup_import_repair_*'))));
assert(height(fp.load_events(saved,saved.Sessions(1).ID))==1);
fig.Visible='on';drawnow;exportapp(fig,fullfile(root,'selection-controls.png'));delete(fig);
gui=fp_group_analysis_gui(p.Root,Visible='off');
gui.Controls.ConditionGrouping.Value='combine';assert(strcmp(gui.ReadSettings().ConditionGrouping,'combine'));
gui.Plot();assert(~isempty(gui.GetState().Result));
gui.Figure.Visible='on';drawnow;exportapp(gui.Figure,fullfile(root,'grouping-controls.png'));delete(gui.Figure);
disp(['PASS: nested import, legacy repair, 4-animal pooling, phase separation/combination, all/group selection, annotations preserved. ' root]);
    function press(tag)
        b=findobj(fig,'Tag',tag);b.ButtonPushedFcn(b,[]);
    end
end
