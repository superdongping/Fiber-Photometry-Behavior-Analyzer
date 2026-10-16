function app=fiber_photometry_video_sync_multiroi(projectFile,varargin)
% Project-aware successor to v4_6: shared video clock, arbitrary named ROIs.
ip=inputParser; addParameter(ip,'Visible','on'); addParameter(ip,'SessionIndex',1); parse(ip,varargin{:});
p=fp.load_project(projectFile); indices=find([p.Sessions.Include]);
assert(~isempty(indices),'No included sessions. Configure animal IDs and source files in the project first.');
sessionIndex=indices(min(ip.Results.SessionIndex,numel(indices)));
data=[]; video=[]; events=table(); dirty=false; current=0; playOrigin=0; playClock=[]; imageHandle=[];
speedPresets=[0.25 0.5 1 1.25 1.5 2 2.5 3]; playbackRate=1;
keyboardEnabled=true; keyboardFocusExemption=[]; spaceHeld=false; tagHeld=false;
traces=cell(1,numel(p.ROIs)); closing=false;
playheads=gobjects(1,numel(p.ROIs)); signalHandles=cell(1,numel(p.ROIs));
lastFrameTime=NaN; lastFrameIndex=-1; lastPlotUpdate=-Inf; lastTextUpdate=-Inf;
stats=struct('FramesRead',0,'RandomSeeks',0,'DisplayedFrames',0,'PlotUpdates',0);
fig=uifigure('Name',['FP + Video | ' p.Name],'Position',[40 40 1600 930],'Visible',ip.Results.Visible);
root=uigridlayout(fig,[3 1]); root.RowHeight={90,'1x',125}; root.Padding=[8 8 8 8];
top=uigridlayout(root,[2 9]); top.Layout.Row=1;
top.RowHeight={32,32}; top.ColumnWidth={220,145,100,155,105,105,90,100,'1x'};
items=arrayfun(@(r) sprintf('%s | %s | %s',r.ID,r.AnimalID,r.Label),p.Sessions(indices),'UniformOutput',false);
sessionDD=uidropdown(top,'Items',items,'ItemsData',num2cell(indices),'Value',sessionIndex,'ValueChangedFcn',@changeSession);
sessionDD.Layout.Column=[1 3]; sessionDD.Layout.Row=1;
mode=uidropdown(top,'Items',{'470 / 410 ratio','470 only','410 only','470 + 410 traces'}, ...
    'ItemsData',{'ratio','470','410','both'},'Value','ratio','Tag','SignalMode','ValueChangedFcn',@(~,~)replot());
mode.Layout.Column=4; mode.Layout.Row=1;
lp=uicheckbox(top,'Text','Low-pass','Value',true,'ValueChangedFcn',@(~,~)replot()); lp.Layout.Column=5;
baseline=uicheckbox(top,'Text','Cubic detrend','Value',false,'ValueChangedFcn',@(~,~)replot()); baseline.Layout.Column=6;
normalize=uicheckbox(top,'Text','View dF/F%','Value',false,'ValueChangedFcn',@(~,~)replot()); normalize.Layout.Column=7;
subtractLP=uicheckbox(top,'Text','Raw - LP','Value',false,'ValueChangedFcn',@(~,~)replot()); subtractLP.Layout.Column=8;
peaks=uicheckbox(top,'Text','Peaks (mean + 3 SD)','Value',false,'ValueChangedFcn',@(~,~)replot()); peaks.Layout.Column=9;
offsetLabel=uilabel(top,'Text','Video offset (s): signal time at video t=0'); offsetLabel.Layout.Row=2; offsetLabel.Layout.Column=1;
offset=uieditfield(top,'numeric','ValueChangedFcn',@(~,~)changeOffset()); offset.Layout.Row=2; offset.Layout.Column=2;
confirmed=uicheckbox(top,'Text','Sync checked','ValueChangedFcn',@(~,~)saveSync()); confirmed.Layout.Row=2; confirmed.Layout.Column=3;
zoom=uicheckbox(top,'Text','Zoom','Value',true,'ValueChangedFcn',@(~,~)refreshView()); zoom.Layout.Row=2; zoom.Layout.Column=4;
window=uispinner(top,'Limits',[1 3600],'Value',30,'ValueChangedFcn',@(~,~)refreshView()); window.Layout.Row=2; window.Layout.Column=5;
importButton=uibutton(top,'Text','Import old XLSX','ButtonPushedFcn',@(~,~)importTags()); importButton.Layout.Row=2; importButton.Layout.Column=6;
snapshot=uibutton(top,'Text','Snapshot','ButtonPushedFcn',@(~,~)saveSnapshot()); snapshot.Layout.Row=2; snapshot.Layout.Column=7;
visibleROIs=uilistbox(top,'Items',{p.ROIs.Name},'Multiselect','on','Value',{p.ROIs.Name},'ValueChangedFcn',@(~,~)showROIs());
visibleROIs.Layout.Row=2; visibleROIs.Layout.Column=[8 9];
body=uigridlayout(root,[1 3]); body.Layout.Row=2; body.ColumnWidth={'1x','1x',190};
videoPanel=uipanel(body,'Title','Video'); videoGrid=uigridlayout(videoPanel,[1 1]); axVideo=uiaxes(videoGrid); axis(axVideo,'off');
signalPanel=uipanel(body,'Title','Simultaneous ROI signals'); signalGrid=uigridlayout(signalPanel,[numel(p.ROIs) 1]);
axesList=gobjects(1,numel(p.ROIs));
for k=1:numel(p.ROIs)
    axesList(k)=uiaxes(signalGrid); axesList(k).Layout.Row=k; axesList(k).Tag=sprintf('ROI_%d',k);
    axesList(k).FontName='Arial'; axesList(k).Box='off'; axesList(k).TickDir='out';
end
linkaxes(axesList,'x');
eventPanel=uipanel(body,'Title','Behavior onsets','Tag','EventPanel'); eventPanel.Layout.Column=3;
eventGrid=uigridlayout(eventPanel,[2 1]); eventGrid.RowHeight={20,'1x'};
eventGrid.Padding=[3 3 3 3]; eventGrid.RowSpacing=3;
uilabel(eventGrid,'Text','Click a row to review','FontSize',11);
eventTable=uitable(eventGrid,'ColumnEditable',[true true],'CellEditCallback',@editTag, ...
    'CellSelectionCallback',@selectTag,'Tag','EventsTable','RowName',[], ...
    'ColumnWidth',{'1x',70},'ColumnSortable',[false false], ...
    'Tooltip','Click either cell to jump video and ROI traces. Time is original signal seconds; double-click to edit.');
eventTable.Layout.Row=2;
bottom=uigridlayout(root,[3 1]); bottom.Layout.Row=3; bottom.RowHeight={48,34,24};
bottom.Padding=[0 0 0 0]; bottom.RowSpacing=8;
slider=uislider(bottom,'Limits',[0 1],'ValueChangingFcn',@(~,e)manualSeek(e.Value),'ValueChangedFcn',@(s,~)finishScrub(s.Value));
bar=uigridlayout(bottom,[1 12]); bar.Layout.Row=2; bar.ColumnWidth={65,65,65,65,145,95,100,95,40,85,85,'1x'};
bar.Padding=[0 0 0 0]; bar.RowHeight={30};
uibutton(bar,'Text','Play','ButtonPushedFcn',@(~,~)play());
uibutton(bar,'Text','Pause','ButtonPushedFcn',@(~,~)pauseFromControl());
uibutton(bar,'Text','-5 s','Tag','StepBackward','ButtonPushedFcn',@(~,~)stepTime(-5));
uibutton(bar,'Text','+5 s','Tag','StepForward','ButtonPushedFcn',@(~,~)stepTime(5));
slots=fp.behavior_slots(p); behaviorItems=p.Behaviors;
for b=1:numel(behaviorItems)
    n=find(strcmp(slots,p.Behaviors{b}),1);
    if ~isempty(n), behaviorItems{b}=sprintf('%d: %s',n,p.Behaviors{b}); end
end
behavior=uidropdown(bar,'Items',behaviorItems,'ItemsData',p.Behaviors,'Tag','BehaviorSelector', ...
    'Tooltip','Keys 1-9 select a predefined behavior; T tags onset.', 'ValueChangedFcn',@(~,~)activateReviewKeys());
uibutton(bar,'Text','Tag onset (T)','ButtonPushedFcn',@(~,~)addTag());
uibutton(bar,'Text','Delete selected','ButtonPushedFcn',@(~,~)deleteTag());
uibutton(bar,'Text','Save events','ButtonPushedFcn',@(~,~)saveTags());
uilabel(bar,'Text','Speed');
speed=uidropdown(bar,'Items',cellstr(compose('%gx',speedPresets)),'ItemsData',num2cell(speedPresets), ...
    'Value',1,'Tag','PlaybackSpeed','Tooltip','Up arrow: faster / Down arrow: slower; recording timestamps are unchanged.', ...
    'ValueChangedFcn',@(s,~)speedFromControl(s.Value));
uibutton(bar,'Text','Shortcuts','ButtonPushedFcn',@(~,~)showShortcuts());
clockLabel=uilabel(bar,'Text','t = 0.000 s');
status=uilabel(bottom,'Text',''); status.Layout.Row=3;
tm=timer('ExecutionMode','fixedRate','BusyMode','drop','Period',0.05,'TimerFcn',@(~,~)tick(), ...
    'ErrorFcn',@(~,~)pausePlayback());
fig.CloseRequestFcn=@(~,~)closeApp();
fig.DeleteFcn=@(~,~)deleteTimer();
fig.WindowKeyPressFcn=@onKeyPress;
fig.WindowKeyReleaseFcn=@onKeyRelease;
fig.WindowButtonDownFcn=@onPointerDown;
setappdata(fig,'FP_Timer',tm);
try, loadSession(); catch ME, delete(tm); delete(fig); rethrow(ME); end
app=struct('Figure',fig,'Mode',mode,'Seek',@manualSeek,'GetState',@getState, ...
    'Play',@play,'Pause',@pausePlayback,'Close',@closeApp,'Timer',tm, ...
    'AddEvent',@addEvent,'SaveEvents',@saveTags,'ConfirmSync',@confirmSync, ...
    'Speed',speed,'SetSpeed',@setPlaybackRate,'Behavior',behavior);

    function state=getState()
        state=struct('Session',p.Sessions(sessionIndex),'Data',data,'Time',current, ...
            'Events',events,'Axes',axesList,'VideoTime',lastFrameTime,'Dirty',dirty,'PlaybackStats',stats, ...
            'PlaybackRate',playbackRate,'SpeedPresets',speedPresets,'KeyboardEnabled',keyboardEnabled);
    end
    function ok=leaveSession()
        pausePlayback(); ok=true;
        if ~dirty, return; end
        answer=uiconfirm(fig,'Save changed behavior events?','Unsaved events','Options',{'Save','Discard','Cancel'},'DefaultOption',1,'CancelOption',3);
        if strcmp(answer,'Save'), ok=saveTags(); elseif strcmp(answer,'Cancel'), ok=false; end
    end
    function changeSession(~,~)
        if ~leaveSession(), sessionDD.Value=sessionIndex; return; end
        old=sessionIndex; sessionIndex=sessionDD.Value;
        try, loadSession(); catch ME, sessionIndex=old; sessionDD.Value=old; loadSession(); uialert(fig,ME.message,'Load session'); end
    end
    function loadSession()
        r=p.Sessions(sessionIndex); data=fp.read_recording(r.CSV,p.ROIs);
        video=VideoReader(r.Video); events=fp.load_events(p,r.ID); eventTable.Data=events;
        tm.Period=1/min(20,video.FrameRate);
        lastFrameTime=NaN; lastFrameIndex=-1; lastPlotUpdate=-Inf; lastTextUpdate=-Inf;
        stats=struct('FramesRead',0,'RandomSeeks',0,'DisplayedFrames',0,'PlotUpdates',0);
        eventTable.ColumnName={'Behavior','Time (s)'};
        dirty=false; offset.Value=r.VideoOffset_s; confirmed.Value=r.SyncConfirmed;
        slider.Limits=[0 data.Duration]; slider.MajorTicks=linspace(0,data.Duration,6);
        slider.MajorTickLabels=cellstr(compose('%.1f',slider.MajorTicks)); slider.MinorTicks=[]; current=0;
        delete(axVideo.Children); imageHandle=[];
        replot(); seek(0); activateReviewKeys();
    end
    function replot()
        if isempty(data), return; end
        resume=strcmp(tm.Running,'on'); pausePlayback();
        try
            settings=p.Settings; if ~lp.Value, settings.LowpassHz=0; end
            for i=1:numel(data.ROIs)
                % Reset both yyaxis sides, including hidden annotations and old right ruler.
                ax=axesList(i); cla(ax,'reset'); hold(ax,'on');
                ax.FontName='Arial'; ax.Box='off'; ax.TickDir='out';
                if strcmp(mode.Value,'both'), modes={'470','410'}; else, modes={mode.Value}; end
                curves=struct('t',{},'y',{},'Side',{}); handles=gobjects(1,numel(modes));
                for j=1:numel(modes)
                    side=1;
                    if strcmp(mode.Value,'both')
                        if strcmp(modes{j},'470'), yyaxis(ax,'left');
                        else, yyaxis(ax,'right'); side=2; end
                    end
                    rawSettings=settings; rawSettings.LowpassHz=0;
                    [t,raw,label]=fp.process_trace(data.ROIs(i),modes{j},rawSettings);
                    [~,y]=fp.process_trace(data.ROIs(i),modes{j},settings);
                    if subtractLP.Value
                        assert(lp.Value && settings.LowpassHz>0,'Raw - LP requires low-pass enabled.'); y=raw-y;
                    end
                    if baseline.Value
                        good=isfinite(y); if nnz(good)>4, fit=polyfit(t(good),y(good),3); trend=polyval(fit,t); y=y-trend+mean(trend(good)); end
                    end
                    if normalize.Value
                        assert(~subtractLP.Value,'Percent normalization of Raw - LP is not defined; disable View dF/F%.');
                        f0=prctile(y(isfinite(y)),10); assert(isfinite(f0) && abs(f0)>1e-6,'Invalid viewing F0.');
                        y=100*(y-f0)/f0; label='Continuous F0 percentile dF/F (%)';
                    end
                    switch modes{j}
                        case '410', color=[0 0.447 0.741];
                        case '470', color=[0 0.60 0.20];
                        otherwise, color=[0.45 0.45 0.45];
                    end
                    handles(j)=plot(ax,t,y,'LineWidth',1.1,'DisplayName',modes{j},'Color',color,'Tag','SignalTrace');
                    ylabel(ax,label);
                    if normalize.Value && strcmp(mode.Value,'both'), ylabel(ax,[modes{j} ' nm view dF/F (%)']); end
                    ax.YAxis(side).Color=color;
                    curves(end+1)=struct('t',t,'y',y,'Side',side); %#ok<AGROW>
                    if peaks.Value, drawPeaks(ax,t,y,modes{j}); end
                end
                if strcmp(mode.Value,'both'), yyaxis(ax,'left'); end
                traces{i}=curves; signalHandles{i}=handles;
                playheads(i)=line(ax,[current current],ylim(ax),'Color',[0.1 0.1 0.1], ...
                    'LineStyle','-','LineWidth',1,'Tag','Playhead','HandleVisibility','off');
                title(ax,p.ROIs(i).Name,'Interpreter','none'); xlabel(ax,'Signal time (s)');
                grid(ax,'off');
            end
            linkaxes(axesList,'x'); drawEvents(); showROIs(); lastPlotUpdate=-Inf; seek(current);
            if resume, play(); end
            activateReviewKeys();
        catch ME, status.Text=['Display error: ' ME.message]; end
    end
    function drawPeaks(ax,t,y,name)
        assert(exist('findpeaks','file')==2,'Signal Processing Toolbox is required for peak detection.');
        good=isfinite(y); if nnz(good)<4, return; end
        smooth=smoothdata(y,'movmean',max(1,round(0.5/median(diff(t)))),'omitnan');
        threshold=mean(smooth(good))+3*std(smooth(good));
        % Only intact stretches; no detection across missing samples.
        edges=diff([false;good;false]); starts=find(edges==1); ends=find(edges==-1)-1;
        n=0;
        for z=1:numel(starts)
            ix=starts(z):ends(z); if numel(ix)<4, continue; end
            [pk,loc]=findpeaks(smooth(ix),t(ix),'MinPeakHeight',threshold,'MinPeakDistance',0.5);
            plot(ax,loc,pk,'o','Color',[0.65 0 0.65],'HandleVisibility','off'); n=n+numel(pk);
        end
        yline(ax,threshold,':','HandleVisibility','off');
        text(ax,0.02,0.92-0.08*(strcmp(name,'410')),sprintf('%s: %d peaks; threshold=mean+3SD',name,n), ...
            'Units','normalized','FontSize',9,'Interpreter','none');
    end
    function showROIs()
        heights=repmat({'1x'},1,numel(axesList));
        for i=1:numel(axesList)
            visible=ismember(p.ROIs(i).Name,visibleROIs.Value);
            if visible, axesList(i).Visible='on'; else, axesList(i).Visible='off'; heights{i}=0; end
        end
        signalGrid.RowHeight=heights;
    end
    function drawEvents()
        for i=1:numel(axesList)
            ax=axesList(i); eventHandles=gobjects(1,0);
            if numel(ax.YAxis)>1, yyaxis(ax,'left'); end
            % findall includes hidden handles; one NaN-separated line per behavior.
            delete(findall(ax,'Tag','BehaviorLine'));
            colors=[0.90 0.10 0.10;0.10 0.25 0.95;0.70 0.15 0.70;0.95 0.55 0.05; ...
                0.05 0.65 0.65;0.45 0.30 0.10;0.75 0.40 0.55;0.45 0.55 0.10;0.35 0.35 0.65];
            if numel(p.Behaviors)>9, colors=[colors;lines(numel(p.Behaviors)-9)]; end
            limits=ylim(ax);
            for b=1:numel(p.Behaviors)
                times=events.Time_signal_s(string(events.Behavior)==string(p.Behaviors{b}));
                if isempty(times), continue; end
                x=reshape([times';times';nan(1,numel(times))],1,[]);
                y=repmat([limits(1) limits(2) NaN],1,numel(times));
                eventHandles(end+1)=line(ax,x,y,'Color',colors(mod(b-1,size(colors,1))+1,:), ...
                    'LineStyle','--','LineWidth',1.2,'DisplayName',[p.Behaviors{b} ' tag'], ...
                    'Tag','BehaviorLine','UserData',b,'HandleVisibility','on','HitTest','off');
            end
            legend(ax,[signalHandles{i} eventHandles],'Location','northeast','AutoUpdate','off');
        end
    end
    function manualSeek(t)
        pausePlayback(); seek(t);
    end
    function finishScrub(t)
        manualSeek(t); activateReviewKeys();
    end
    function stepTime(delta)
        % Read shared current HERE; anonymous callbacks otherwise capture its initial 0.
        pausePlayback(); seek(current+delta); activateReviewKeys();
    end
    function refreshView()
        % Preserve current position when changing zoom/window controls.
        seek(current);
    end
    function seek(t,playing)
        if nargin<2, playing=false; end
        current=min(max(t,0),data.Duration);
        v=current-offset.Value; newFrame=false;
        if v>=0 && v<video.Duration
            target=min(v,max(0,video.Duration-1/video.FrameRate));
            targetIndex=floor(target*video.FrameRate+1e-6);
            if targetIndex~=lastFrameIndex || isempty(imageHandle) || ~isgraphics(imageHandle)
                if ~playing || ~isfinite(lastFrameTime) || target<lastFrameTime || target-video.CurrentTime>0.5
                    video.CurrentTime=target; stats.RandomSeeks=stats.RandomSeeks+1;
                    frame=readFrame(video); stats.FramesRead=stats.FramesRead+1;
                    lastFrameTime=max(0,video.CurrentTime-1/video.FrameRate); newFrame=true;
                else
                    % Forward playback decodes sequentially; short frame skips do not seek.
                    while hasFrame(video) && video.CurrentTime<=target+1e-6
                        frame=readFrame(video); stats.FramesRead=stats.FramesRead+1;
                        lastFrameTime=max(0,video.CurrentTime-1/video.FrameRate); newFrame=true;
                    end
                end
                if newFrame
                    lastFrameIndex=floor(lastFrameTime*video.FrameRate+1e-6);
                    % Display-only subsampling for large videos; original file is untouched.
                    stride=max(1,ceil(max(size(frame,2)/960,size(frame,1)/720)));
                    frame=frame(1:stride:end,1:stride:end,:);
                    if isempty(imageHandle) || ~isgraphics(imageHandle)
                        imageHandle=image(axVideo,frame); axis(axVideo,'image'); axis(axVideo,'off'); axVideo.YDir='reverse';
                    else, imageHandle.CData=frame; imageHandle.Visible='on'; end
                    stats.DisplayedFrames=stats.DisplayedFrames+1;
                end
            end
            % Tag time and cursor follow the frame actually displayed, not the next frame.
            current=min(max(lastFrameTime+offset.Value,0),data.Duration);
        else
            if isgraphics(imageHandle), imageHandle.Visible='off'; end
            lastFrameTime=NaN; lastFrameIndex=-1;
        end
        slider.Value=current;
        updatePlot=~playing || current-lastPlotUpdate>=0.2 || current<lastPlotUpdate;
        if zoom.Value
            lo=max(0,current-window.Value/2); hi=min(data.Duration,lo+window.Value); lo=max(0,hi-window.Value);
        else, lo=0; hi=data.Duration; end
        if updatePlot
            xlim(axesList(1),[lo max(hi,lo+eps)]);
            stats.PlotUpdates=stats.PlotUpdates+1; lastPlotUpdate=current;
        end
        for i=1:numel(axesList)
            ax=axesList(i);
            if updatePlot
                values=cell(1,numel(ax.YAxis));
                for j=1:numel(traces{i})
                    c=traces{i}(j); visible=c.t>=lo & c.t<=hi;
                    values{c.Side}=[values{c.Side};c.y(visible)];
                    % Only the viewing window is drawn; scientific traces remain full length.
                    ix=find(c.t>=lo-1 & c.t<=hi+1);
                    if numel(ix)>2500, ix=ix(unique(round(linspace(1,numel(ix),2500)))); end
                    signalHandles{i}(j).XData=c.t(ix); signalHandles{i}(j).YData=c.y(ix);
                end
                for side=1:numel(values)
                    finite=values{side}(isfinite(values{side}));
                    if ~isempty(finite)
                        low=min(finite); high=max(finite); pad=max((high-low)*0.08,1e-5);
                        ax.YAxis(side).Limits=[low-pad high+pad];
                    end
                end
                limits=ax.YAxis(1).Limits; playheads(i).YData=limits;
                for eventLine=findall(ax,'Tag','BehaviorLine')'
                    eventLine.YData=repmat([limits NaN],1,numel(eventLine.XData)/3);
                end
            end
            playheads(i).XData=[current current];
        end
        if ~playing || current-lastTextUpdate>=0.1 || current<lastTextUpdate
            clockLabel.Text=sprintf('Signal %.3f s | Video %.3f s | %gx',current,lastFrameTime,playbackRate);
            if isfinite(lastFrameTime), title(axVideo,sprintf('Video %.3f s | signal %.3f s',lastFrameTime,current));
            else, title(axVideo,'Outside video coverage (check offset)'); end
            lastTextUpdate=current;
        end
        if ~playing
            status.Text=sprintf('%s | %s | offset %.3f s | sync checked=%d | events=%d', ...
                p.Sessions(sessionIndex).AnimalID,data.Timing,offset.Value,confirmed.Value,height(events));
        end
        if playing, drawnow limitrate nocallbacks; end
    end
    function play()
        if strcmp(tm.Running,'on'), return; end
        if current>=data.Duration, seek(0); end
        playOrigin=current; playClock=tic; start(tm); activateReviewKeys();
    end
    function tick()
        if closing || ~isvalid(fig), return; end
        target=playOrigin+toc(playClock)*playbackRate; seek(target,true);
        if target>=data.Duration, pausePlayback(); end
    end
    function pausePlayback()
        if isvalid(tm) && strcmp(tm.Running,'on'), stop(tm); end
    end
    function pauseFromControl()
        pausePlayback(); activateReviewKeys();
    end
    function setPlaybackRate(value)
        assert(isscalar(value) && ismember(value,speedPresets),'Unsupported playback speed.');
        if strcmp(tm.Running,'on')
            % Preserve continuous recording time when the clock's multiplier changes.
            playOrigin=min(data.Duration,playOrigin+toc(playClock)*playbackRate);
            playClock=tic;
        end
        playbackRate=value; speed.Value=value;
        clockLabel.Text=sprintf('Signal %.3f s | Video %.3f s | %gx',current,lastFrameTime,playbackRate);
    end
    function speedFromControl(value)
        setPlaybackRate(value); activateReviewKeys();
    end
    function changeSpeed(direction)
        index=find(speedPresets==playbackRate,1);
        index=min(max(index+direction,1),numel(speedPresets));
        setPlaybackRate(speedPresets(index));
    end
    function activateReviewKeys()
        keyboardEnabled=true;
        % CurrentObject can retain the last clicked control after focus returns to figure.
        keyboardFocusExemption=fig.CurrentObject;
        if strcmp(fig.Visible,'on'), focus(fig); end
    end
    function onPointerDown(~,~)
        keyboardFocusExemption=[]; spaceHeld=false; tagHeld=false;
        keyboardEnabled=~fp.review_shortcut_blocked(fig.CurrentObject);
    end
    function onKeyPress(~,event)
        if closing || isempty(data), return; end
        if strcmp(event.Key,'tab')
            keyboardEnabled=false; keyboardFocusExemption=[]; spaceHeld=false; tagHeld=false; return;
        end
        if ~keyboardEnabled, return; end
        object=fig.CurrentObject;
        exempt=~isempty(keyboardFocusExemption) && isequal(object,keyboardFocusExemption);
        if fp.review_shortcut_blocked(object) && ~exempt, return; end
        [action,value]=fp.review_shortcut(event.Key,event.Character,event.Modifier);
        switch action
            case 'toggle'
                if spaceHeld, return; end % OS key-repeat must not flicker between play/pause.
                spaceHeld=true;
                if strcmp(tm.Running,'on'), pausePlayback(); else, play(); end
            case 'step', stepTime(value);
            case 'speed', changeSpeed(value);
            case 'behavior'
                if ~isempty(slots{value}), behavior.Value=slots{value}; end
            case 'tag'
                if tagHeld, return; end
                tagHeld=true;
                try, addTag(); catch ME, status.Text=ME.message; end
        end
    end
    function onKeyRelease(~,event)
        if strcmp(event.Key,'space'), spaceHeld=false; end
        if strcmp(event.Key,'t'), tagHeld=false; end
    end
    function showShortcuts()
        text=sprintf(['Click video/trace to enable review shortcuts.\n\n' ...
            'Space: play / pause\nLeft / Right: -1 / +1 second\n' ...
            'Ctrl+Left: -5 seconds\nCtrl+Right: +5 seconds\n' ...
            'Up / Down: next faster / slower preset\n\n' ...
            '1-9: select predefined behavior (blank slots ignored)\nT: tag onset for selected behavior\n\n' ...
            '0.25x, 0.5x, 1x, 1.25x, 1.5x, 2x, 2.5x, 3x\n' ...
            'Default: 1x. Tags always use original recording seconds.\n' ...
            'Shortcuts are disabled while editing controls or navigating with Tab.']);
        uialert(fig,text,'Review shortcuts','Icon','info');
    end
    function changeOffset()
        pausePlayback(); confirmed.Value=false; saveSync(); seek(current);
    end
    function confirmSync(value)
        confirmed.Value=logical(value); saveSync();
    end
    function saveSync()
        latest=fp.load_project(fullfile(p.Root,'project.mat'));
        id=p.Sessions(sessionIndex).ID; ix=find(strcmp({latest.Sessions.ID},id));
        latest.Sessions(ix).VideoOffset_s=offset.Value; latest.Sessions(ix).SyncConfirmed=confirmed.Value;
        fp.save_project(latest); p=latest;
        % Stored VideoTime is derived; recompute if annotations already exist.
        if isfile(fp.event_file(p,id)), fp.save_events(p,id,fp.load_events(p,id)); end
        seek(current);
    end
    function addTag()
        addEvent(behavior.Value,current); activateReviewKeys();
    end
    function addEvent(name,t)
        assert(ismember(string(name),string(p.Behaviors)) && isfinite(t) && t>=0 && t<=data.Duration,'Invalid behavior event.');
        assert(t-offset.Value>=0 && t-offset.Value<video.Duration,'Cannot tag a behavior outside video coverage.');
        events=[events;table(string(name),t,'VariableNames',{'Behavior','Time_signal_s'})];
        events=sortrows(events,'Time_signal_s'); eventTable.Data=events; dirty=true; drawEvents(); seek(current);
    end
    function editTag(~,~)
        candidate=eventTable.Data;
        if any(~ismember(string(candidate.Behavior),string(p.Behaviors))) || any(~isfinite(candidate.Time_signal_s) | candidate.Time_signal_s<0 | candidate.Time_signal_s>data.Duration)
            eventTable.Data=events; uialert(fig,'Invalid behavior label or onset time.','Events'); return;
        end
        events=candidate; dirty=true; drawEvents();
    end
    function selectTag(~,event)
        if closing || isempty(event.Indices) || isempty(events), return; end
        row=event.Indices(1,1);
        if row<1 || row>height(events), return; end
        t=events.Time_signal_s(row);
        if ~isfinite(t), return; end
        manualSeek(t);
        status.Text=sprintf('Review %s | signal %.4f s | video %.4f s', ...
            char(events.Behavior(row)),t,t-offset.Value);
    end
    function deleteTag()
        selection=eventTable.Selection; if isempty(selection), return; end
        rows=unique(selection(:,1)); events(rows,:)=[]; eventTable.Data=events; dirty=true; drawEvents(); activateReviewKeys();
    end
    function ok=saveTags()
        ok=false;
        try, fp.save_events(p,p.Sessions(sessionIndex).ID,events); dirty=false; ok=true; status.Text='Behavior events saved.'; activateReviewKeys();
        catch ME, uialert(fig,ME.message,'Save events'); end
    end
    function importTags()
        [f,d]=uigetfile('*.xlsx','Select legacy BehaviorTags workbook for THIS session'); if isequal(f,0), return; end
        try
            names=sheetnames(fullfile(d,f)); imported=events([],:);
            for z=1:min(2,numel(p.Behaviors))
                sheet=sprintf('Behavior%d',z); col=sprintf('Behavior%d_Onset_Time_s',z);
                if ~ismember(string(sheet),names), continue; end
                T=readtable(fullfile(d,f),'Sheet',sheet);
                assert(ismember(col,T.Properties.VariableNames),'Missing onset column in legacy tags.');
                imported=[imported;table(repmat(string(p.Behaviors{z}),height(T),1),T.(col)+data.LegacyTimeShift_s,'VariableNames',events.Properties.VariableNames)]; %#ok<AGROW>
            end
            assert(all(isfinite(imported.Time_signal_s) & imported.Time_signal_s>=0 & imported.Time_signal_s<=data.Duration),'Legacy tags contain invalid/out-of-range times.');
            events=unique([events;imported],'rows','stable'); eventTable.Data=events; dirty=true; drawEvents();
        catch ME, uialert(fig,ME.message,'Import old tags'); end
    end
    function saveSnapshot()
        folder=fullfile(p.Root,'results','snapshots'); if ~isfolder(folder), mkdir(folder); end
        file=fullfile(folder,sprintf('%s_%s.tif',p.Sessions(sessionIndex).ID,char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))));
        exportapp(fig,file); status.Text=['Saved ' file];
    end
    function closeApp()
        if closing || ~isvalid(fig), return; end
        if ~leaveSession(), return; end
        closing=true; if isvalid(tm), stop(tm); delete(tm); end
        delete(fig);
    end
    function deleteTimer()
        if isvalid(tm), stop(tm); delete(tm); end
    end
end

