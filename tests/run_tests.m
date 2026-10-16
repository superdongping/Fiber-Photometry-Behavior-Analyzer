function run_tests()
% Portable regression suite: generated synthetic data only.
codeRoot=fileparts(fileparts(mfilename('fullpath'))); addpath(codeRoot);
root=fullfile(codeRoot,'tests','artifacts',char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))); mkdir(root);
source=fullfile(root,'synthetic_source'); mkdir(source);
ids={'#A1','#A2','#B1'}; amps=[1 3 2]; tags={[8],[8 16 24],[8 16]};
t=(0:0.05:30)';
for k=1:3
    folder=fullfile(source,'Condition',sprintf('%02d %s',k,ids{k})); mkdir(folder);
    response=zeros(size(t));
    for onset=tags{k}, response(t>=onset & t<=onset+1.5)=1; end
    clock=arrayfun(@(x)sprintf('0:00:00:%010.7f',x),t,'UniformOutput',false);
    T=table(string(clock),10+zeros(size(t)),10*(1+amps(k)*response),20+zeros(size(t)), ...
        20*(1+(amps(k)+1)*response),'VariableNames',{'Time','ROI-1_sig_410','ROI-1_sig_470','ROI-2_sig_410','ROI-2_sig_470'});
    writetable(T,fullfile(folder,'recording(Camera).csv'));
    writer=VideoWriter(fullfile(folder,'recording.avi'),'Motion JPEG AVI'); writer.FrameRate=2; open(writer);
    for z=1:60, frame=uint8(zeros(60,80,3)); frame(:,:,1)=uint8(z*4); writeVideo(writer,frame); end
    close(writer);
end
config=struct('Name','Synthetic validation','BehaviorTask','Synthetic only','Behaviors',{{'Approach','Other'}}, ...
    'Groups',{{'G1','G2'}},'Animals',struct('ID',ids,'Group',{'G1','G1','G2'}), ...
    'ROIs',struct('SourceID',{'ROI-1','ROI-2'},'Name',{'Region_A','Region_B'}));
p=fp.create_project(fullfile(root,'project'),config,source);
p.Settings.LowpassHz=0; p.Settings.PreTime=-2; p.Settings.PostTime=2; p.Settings.Baseline=[-2 0];
p.Settings.AUCWindow=[0 1]; p.Settings.OutputFs=10;
fp.save_project(p); p=fp.load_project(p.Root); assert(numel(p.Sessions)==3);
for k=1:3
    sid=find(strcmp({p.Sessions.AnimalID},ids{k}));
    E=table(repmat("Approach",numel(tags{k}),1),tags{k}(:),'VariableNames',{'Behavior','Time_signal_s'});
    fp.save_events(p,p.Sessions(sid).ID,E);
end
% No automatic assumption of verified video/photometry synchronization.
blocked=fp_analyze_project(p,MakeFigures=false,Visible='off');
assert(isempty(blocked.Trials) && all(strcmp({blocked.QC.Reason},'sync_not_confirmed')));
for k=1:3, p.Sessions(k).SyncConfirmed=true; end
fp.save_project(p);
result=fp_analyze_project(p,Visible='off');
assert(numel(result.Trials)==12 && numel(result.Animals)==6 && numel(result.Groups)==4);
g=result.Groups(strcmp({result.Groups.Group},'G1') & strcmp({result.Groups.ROI},'Region_A'));
assert(g.AnimalCount==2 && g.TrialCount==4);
idx=find(abs(result.Time-0.5)<1e-9);
assert(abs(g.Mean(idx)-200)<1e-10,'Animal weighting regressed to pooled trials.');
assert(abs(g.SEM(idx)-100)<1e-10,'Animal SEM incorrect.');
g2=result.Groups(strcmp({result.Groups.Group},'G2') & strcmp({result.Groups.ROI},'Region_A'));
assert(all(isnan(g2.SEM)),'n=1 must not imply SEM=0.');
assert(numel(dir(fullfile(result.OutputFolder,'*.png')))==2);
% TimeSpan parsing + ROI name mapping + absent ROI rejection.
d=fp.read_recording(p.Sessions(1).CSV,p.ROIs); assert(numel(d.ROIs)==2 && abs(d.Duration-30)<1e-9);
assert(strcmp(d.ROIs(2).Name,'Region_B'));
bad=p.ROIs; bad(2).SourceID='ROI-99'; caught=false;
try, fp.read_recording(p.Sessions(1).CSV,bad); catch, caught=true; end
assert(caught,'Missing ROI must fail instead of silently reading ROI-1.');
% Event rejection at recording edge, and ROI-local missing-data handling.
badEvents=fp.load_events(p,p.Sessions(1).ID);
badEvents=[badEvents;table("Approach",0.1,'VariableNames',badEvents.Properties.VariableNames)];
fp.save_events(p,p.Sessions(1).ID,badEvents);
edge=fp_analyze_project(p,MakeFigures=false,Visible='off');
assert(any(strcmp({edge.QC.Reason},'event_window_outside_recording')));
% Data gap must not be bridged by filtering or event interpolation.
record=fp.read_recording(p.Sessions(1).CSV,p.ROIs);
settings=p.Settings; settings.LowpassHz=2;
r=record.ROIs(1); r.y470(120:140)=NaN;
[~,y]=fp.process_trace(r,'470',settings); assert(all(isnan(y(120:140))));
settings.LowpassHz=0; settings.WavelengthAlignment='interpolate470';
r=record.ROIs(1); keep=~(r.t470>5 & r.t470<6); r.t470=r.t470(keep); r.y470=r.y470(keep);
[tt,yy]=fp.process_trace(r,'ratio',settings); assert(all(isnan(yy(tt>5 & tt<6))));
% GUI callbacks: all modes, two axes, shared playhead, persisted events/offset.
app=fiber_photometry_video_sync_multiroi(p,Visible='off');
assert(numel(app.GetState().Axes)==2);
for mode={'ratio','470','410','both'}
    app.Mode.Value=mode{1}; app.Mode.ValueChangedFcn(app.Mode,[]); state=app.GetState();
    for ax=state.Axes
        curves=findobj(ax,'Tag','SignalTrace');
        if strcmp(mode{1},'both'), assert(numel(curves)==2); else, assert(numel(curves)==1); end
    end
end
app.Seek(5); state=app.GetState(); assert(state.Time==5 && state.VideoTime==5);
app.AddEvent('Other',5); assert(app.SaveEvents());
app.ConfirmSync(true); app.Play(); pause(0.2); app.Pause(); assert(app.GetState().Time>5);
assert(height(fp.load_events(p,state.Session.ID))>=2);
tm=app.Timer; app.Close(); assert(~isvalid(tm) && ~isvalid(app.Figure),'Timer/figure leaked on close.');
manager=fiber_photometry_project(fullfile(p.Root,'project.mat')); delete(manager);
report=struct('Status','PASS','MATLAB',version,'SyntheticBiologicalWeighting',true, ...
    'SEMAndTrialQC',true,'GUIFourModesAndTimerCleanup',true);
fid=fopen(fullfile(root,'test_report.json'),'w'); fprintf(fid,'%s',jsonencode(report,PrettyPrint=true)); fclose(fid);
disp(jsonencode(report,PrettyPrint=true));
end

