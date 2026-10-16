function fig=fiber_photometry_project(projectFile)
% Local project manager. Launch this entry point in MATLAB R2024a or newer.
if nargin<1, p=[]; else, p=fp.load_project(projectFile); end
fig=uifigure('Name','Fiber Photometry Behavior Analyzer V1.0','Position',[80 80 1400 850]);
root=uigridlayout(fig,[4 1]); root.RowHeight={48,36,'1x',32};
toolbar=uigridlayout(root,[1 6]); toolbar.Layout.Row=1;
uibutton(toolbar,'Text','New project','ButtonPushedFcn',@(~,~)newProject());
uibutton(toolbar,'Text','Open project','ButtonPushedFcn',@(~,~)openProject());
uibutton(toolbar,'Text','Save configuration','ButtonPushedFcn',@(~,~)saveChanges());
uibutton(toolbar,'Text','View video + ROIs','ButtonPushedFcn',@(~,~)viewSession());
uibutton(toolbar,'Text','Run group analysis','ButtonPushedFcn',@(~,~)analyze());
uibutton(toolbar,'Text','Analysis settings','ButtonPushedFcn',@(~,~)settingsDialog());
info=uilabel(root,'Text','Create or open a project. Raw recordings remain in their source folder.'); info.Layout.Row=2;
tabs=uitabgroup(root); tabs.Layout.Row=3;
tab=uitab(tabs,'Title','Sessions (same mouse may have multiple conditions)');
g=uigridlayout(tab,[1 1]); st=uitable(g,'CellEditCallback',@(~,~)markDirty(),'Tag','SessionsTable');
st.ColumnEditable=[false true true true true true true true];
tab=uitab(tabs,'Title','Animal groups'); g=uigridlayout(tab,[1 1]);
at=uitable(g,'ColumnEditable',[false true],'CellEditCallback',@(~,~)markDirty());
tab=uitab(tabs,'Title','ROI names'); g=uigridlayout(tab,[1 1]);
rt=uitable(g,'ColumnEditable',[false true],'CellEditCallback',@(~,~)markDirty());
tab=uitab(tabs,'Title','Behavior types'); g=uigridlayout(tab,[2 1]); g.RowHeight={36,'1x'};
uilabel(g,'Text','Name keys 1-9; blank disables a key. Existing tags retain their original names. Save configuration, then reopen the viewer.');
bt=uitable(g,'ColumnEditable',[false true],'CellEditCallback',@(~,~)markDirty(),'Tag','BehaviorTypesTable');
status=uilabel(root,'Text','Fiber Photometry Behavior Analyzer V1.0 | Source recordings remain unchanged.'); status.Layout.Row=4;
dirty=false; fig.CloseRequestFcn=@(~,~)closeManager();
refresh();

    function refresh()
        if isempty(p), return; end
        info.Text=sprintf('%s | %s | %d animals / %d groups / %d ROIs / %d sessions | %s', ...
            p.Name,p.BehaviorTask,numel(p.Animals),numel(p.Groups),numel(p.ROIs),numel(p.Sessions),strjoin(p.Behaviors,', '));
        st.Data=struct2table(p.Sessions); st.ColumnName=st.Data.Properties.VariableNames;
        at.Data=struct2table(p.Animals); at.ColumnName={'AnimalID','Group'};
        rt.Data=struct2table(p.ROIs); rt.ColumnName={'CSV ROI ID','ROI name'};
        bt.Data=table((1:9)',string(fp.behavior_slots(p))','VariableNames',{'Key','Name'});
        bt.ColumnName={'Shortcut (1-9)','Behavior name'};
        dirty=false;
    end
    function markDirty(), dirty=true; status.Text='Configuration changed; save before using it.'; end
    function ok=saveChanges()
        ok=false; if isempty(p), return; end
        if ~dirty
            p=fp.load_project(fullfile(p.Root,'project.mat')); refresh(); ok=true; return;
        end
        try
            candidate=p;
            candidate.Sessions=table2struct(st.Data); candidate.Animals=table2struct(at.Data); candidate.ROIs=table2struct(rt.Data);
            candidate=fp.set_behavior_slots(candidate,bt.Data.Name);
            latest=fp.load_project(fullfile(p.Root,'project.mat'));
            for k=1:numel(candidate.Sessions)
                % Merge independent viewer sync edits if these cells were not changed here.
                id=candidate.Sessions(k).ID; z=find(strcmp({latest.Sessions.ID},id));
                if isempty(z), continue; end
                for field={'VideoOffset_s','SyncConfirmed'}
                    name=field{1};
                    if isequal(candidate.Sessions(k).(name),p.Sessions(k).(name))
                        candidate.Sessions(k).(name)=latest.Sessions(z).(name);
                    end
                end
            end
            fp.save_project(candidate); p=candidate; dirty=false; ok=true;
            refresh(); status.Text=['Saved ' fullfile(p.Root,'project.mat')];
        catch ME, uialert(fig,ME.message,'Configuration error'); end
    end
    function ok=leave()
        ok=true;
        if ~dirty, return; end
        choice=uiconfirm(fig,'Save configuration changes?','Unsaved project','Options',{'Save','Discard','Cancel'},'DefaultOption',1,'CancelOption',3);
        if strcmp(choice,'Save'), ok=saveChanges(); elseif strcmp(choice,'Cancel'), ok=false; end
    end
    function newProject()
        if ~leave(), return; end
        try, candidate=fp.new_project_dialog(); if ~isempty(candidate), p=candidate; refresh(); end
        catch ME, uialert(fig,ME.message,'New project'); end
    end
    function openProject()
        if ~leave(), return; end
        [f,d]=uigetfile('*.mat','Open project.mat'); if isequal(f,0), return; end
        try, p=fp.load_project(fullfile(d,f)); refresh(); catch ME, uialert(fig,ME.message,'Open project'); end
    end
    function viewSession()
        if ~saveChanges(), return; end
        try, fiber_photometry_video_sync_multiroi(fullfile(p.Root,'project.mat')); catch ME, uialert(fig,ME.message,'Viewer'); end
    end
    function analyze()
        if ~saveChanges(), return; end
        try
            result=fp_analyze_project(fullfile(p.Root,'project.mat'));
            status.Text=['Results: ' result.OutputFolder];
        catch ME, uialert(fig,ME.message,'Analysis'); end
    end
    function settingsDialog()
        if isempty(p), return; end
        s=p.Settings;
        prompts={'Pre-time (<0, s)','Post-time (>0, s)','Baseline start (s)','Baseline end (s, exclusive)', ...
            'AUC start (s)','AUC end (s)','Output rate (Hz)','Low-pass cutoff (0=off, Hz)', ...
            'Analysis mode: ratio / 470 / 410','Normalization: dff_percent / baseline_subtract / none', ...
            'Heatmap sort: descend / ascend','Wavelength alignment: index / interpolate470', ...
            'Require manually confirmed video sync: 1 / 0'};
        values={num2str(s.PreTime),num2str(s.PostTime),num2str(s.Baseline(1)),num2str(s.Baseline(2)), ...
            num2str(s.AUCWindow(1)),num2str(s.AUCWindow(2)),num2str(s.OutputFs),num2str(s.LowpassHz), ...
            s.SignalMode,s.Normalization,s.SortOrder,s.WavelengthAlignment,num2str(s.RequireConfirmedSync)};
        a=inputdlg(prompts,'Saved analysis settings',[1 80],values); if isempty(a), return; end
        try
            s.PreTime=str2double(a{1}); s.PostTime=str2double(a{2}); s.Baseline=[str2double(a{3}) str2double(a{4})];
            s.AUCWindow=[str2double(a{5}) str2double(a{6})]; s.OutputFs=str2double(a{7}); s.LowpassHz=str2double(a{8});
            s.SignalMode=strtrim(a{9}); s.Normalization=strtrim(a{10}); s.SortOrder=strtrim(a{11}); s.WavelengthAlignment=strtrim(a{12});
            flag=str2double(a{13}); assert(ismember(flag,[0 1]),'Sync requirement must be 0 or 1.'); s.RequireConfirmedSync=logical(flag);
            candidate=p; candidate.Settings=s;
            fp.validate_project(candidate); p=candidate; markDirty();
        catch ME, uialert(fig,ME.message,'Settings'); end
    end
    function closeManager()
        if leave(), delete(fig); end
    end
end

