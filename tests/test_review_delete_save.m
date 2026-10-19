function test_review_delete_save()
% Portable keyboard regression: synthetic video/signals/events only.
codeRoot=fileparts(fileparts(mfilename('fullpath'))); addpath(codeRoot);
root=fullfile(codeRoot,'tests','artifacts',['delete_save_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
source=fullfile(root,'source','Encoding','01 #SYNTHETIC'); mkdir(source);
t=(0:.05:20)';
clock=string(arrayfun(@(x)sprintf('0:00:00:%010.7f',x),t,'UniformOutput',false));
T=table(clock,10+0*t,12+sin(t),20+0*t,22+cos(t), ...
    'VariableNames',{'Time','ROI-1_sig_410','ROI-1_sig_470','ROI-2_sig_410','ROI-2_sig_470'});
writetable(T,fullfile(source,'synthetic(Camera).csv'));
writer=VideoWriter(fullfile(source,'synthetic.avi'),'Motion JPEG AVI'); writer.FrameRate=5; open(writer);
for k=1:100, writeVideo(writer,repmat(uint8(mod(k,255)),[40 60 3])); end
close(writer);
config=struct('Name','Synthetic D/S validation','BehaviorTask','Synthetic', ...
    'Groups',{{'Synthetic group'}},'Animals',struct('ID','#SYNTHETIC','Group','Synthetic group'), ...
    'Behaviors',{{'Approach','Other'}},'ROIs',struct('SourceID',{'ROI-1','ROI-2'},'Name',{'Region A','Region B'}));
p=fp.create_project(fullfile(root,'project'),config,fullfile(root,'source'));
p.Settings.LowpassHz=0; fp.save_project(p);
E=table(["Approach";"Other";"Approach"],[1.23456789;2.34567891;3.45678912], ...
    'VariableNames',{'Behavior','Time_signal_s'}); fp.save_events(p,p.Sessions.ID,E);
projectBefore=readBytes(fullfile(p.Root,'project.mat'));
app=fiber_photometry_video_sync_multiroi(p,Visible='on');
cleanup=onCleanup(@() cleanupViewer(app)); %#ok<NASGU>
for key={'d','D'}, [action,~]=fp.review_shortcut(key{1},key{1},{}); assert(strcmp(action,'delete')); end
for key={'s','S'}, [action,~]=fp.review_shortcut(key{1},key{1},{}); assert(strcmp(action,'save')); end
for key={'d','s'}
    [action,~]=fp.review_shortcut(key{1},key{1},{'control'}); assert(isempty(action));
    [action,~]=fp.review_shortcut(key{1},key{1},{'alt'}); assert(isempty(action));
end
assert(contains(findall(app.Figure,'Tag','DeleteSelectedButton').Text,'(D)'));
assert(contains(findall(app.Figure,'Tag','SaveEventsButton').Text,'(S)'));
% Empty selection is a no-op, including dirty state.
send('d'); release('d'); assert(isequaln(app.GetState().Events,E) && ~app.GetState().Dirty);
app.EventTable.Selection=[1 1;1 2;2 1];
send('d'); assert(height(app.GetState().Events)==1 && app.GetState().Dirty);
assert(height(fp.load_events(p,p.Sessions.ID))==3,'Deletion saved without S.');
% Holding D cannot delete a newly selected row until the key is released.
app.EventTable.Selection=[1 1]; send('d'); assert(height(app.GetState().Events)==1);
release('d'); send('d'); release('d'); assert(isempty(app.GetState().Events));
% Save current events, then prove held S does not silently save a later edit.
app.AddEvent('Approach',4.123456789); send('s'); assert(~app.GetState().Dirty);
assert(fp.load_events(p,p.Sessions.ID).Time_signal_s==4.123456789);
app.AddEvent('Other',5.234567891); send('s');
assert(app.GetState().Dirty && height(fp.load_events(p,p.Sessions.ID))==1);
release('s'); send('s'); release('s'); assert(height(fp.load_events(p,p.Sessions.ID))==2);
% Tab focus protection and native editor classification remain intact.
app.AddEvent('Other',6.345678912); app.EventTable.Selection=[1 1];
send('tab'); send('d'); send('s'); release('d'); release('s');
assert(height(app.GetState().Events)==3 && height(fp.load_events(p,p.Sessions.ID))==2);
assert(fp.review_shortcut_blocked(app.EventTable) && fp.review_shortcut_blocked(app.Speed));
numeric=findall(app.Figure,'Type','uinumericeditfield');
assert(~isempty(numeric) && fp.review_shortcut_blocked(numeric(1)));
app.Figure.WindowButtonDownFcn(app.Figure,[]); send('s'); release('s');
assert(isequaln(fp.load_events(p,p.Sessions.ID),app.GetState().Events));
% Selection navigation still seeks full-resolution time; read-only column is distinct.
app.EventTable.Selection=[2 1];
app.EventTable.CellSelectionCallback(app.EventTable,struct('Indices',[2 1]));
assert(abs(app.GetState().Time-5.234567891)<.21,'Seek must land within one 5-fps video frame.');
% Existing T, transport, speed, original event seconds and playing-state save.
send('2'); send('t'); send('t'); release('t'); assert(height(app.GetState().Events)==4);
send('uparrow'); assert(app.GetState().PlaybackRate==1.25);
send('downarrow'); assert(app.GetState().PlaybackRate==1);
send('space'); release('space'); assert(strcmp(app.Timer.Running,'on'));
send('s'); release('s'); assert(strcmp(app.Timer.Running,'on'));
send('space'); release('space'); assert(strcmp(app.Timer.Running,'off'));
assert(isequaln(fp.load_events(p,p.Sessions.ID),app.GetState().Events));
exportapp(app.Figure,fullfile(root,'viewer_DS_preview.png'));
tm=app.Timer; app.Close(); assert(~isvalid(tm));
app=fiber_photometry_video_sync_multiroi(p,Visible='off');
assert(height(app.GetState().Events)==4); app.Close();
assert(isequal(projectBefore,readBytes(fullfile(p.Root,'project.mat'))),'Keyboard edited project settings.');
report=struct('Status','PASS','DeleteSelectedAndNoSelection',true,'DeleteRepeatSuppressed',true, ...
    'SaveCurrentSessionAndRepeatSuppressed',true,'SavedPrecisionAndReload',true,'CtrlAltAndTabProtected',true, ...
    'EditorsClassifiedAsNative',true,'ExistingTransportSpeedTagRegression',true,'SaveKeepsPlaying',true, ...
    'TimerCleanup',true,'ResearchDataUsed',false);
fid=fopen(fullfile(root,'test_report.json'),'w'); fprintf(fid,'%s',jsonencode(report,PrettyPrint=true)); fclose(fid);
disp(jsonencode(report,PrettyPrint=true));
    function send(key)
        app.Figure.WindowKeyPressFcn(app.Figure,struct('Key',key,'Character',key,'Modifier',{{}}));
    end
    function release(key)
        app.Figure.WindowKeyReleaseFcn(app.Figure,struct('Key',key));
    end
end
function data=readBytes(path)
fid=fopen(path,'rb'); c=onCleanup(@() fclose(fid)); %#ok<NASGU>
data=fread(fid,Inf,'*uint8');
end
function cleanupViewer(app)
if isvalid(app.Figure), delete(app.Figure); end
end
