function fig=fiber_photometry_project(projectFile)
% Local project manager. Launch this entry point in MATLAB R2024a or newer.
repairs=[];
if nargin<1, p=[]; else, [p,repairs]=fp.load_project(projectFile); end
fig=uifigure('Name','Fiber Photometry Behavior Analyzer V1.2','Position',[80 80 1400 850]);
root=uigridlayout(fig,[4 1]); root.RowHeight={48,36,'1x',32};
toolbar=uigridlayout(root,[1 6]); toolbar.Layout.Row=1;
uibutton(toolbar,'Text','New project','ButtonPushedFcn',@(~,~)newProject());
uibutton(toolbar,'Text','Open project','ButtonPushedFcn',@(~,~)openProject());
uibutton(toolbar,'Text','Save configuration','ButtonPushedFcn',@(~,~)saveChanges());
uibutton(toolbar,'Text','View video + ROIs','ButtonPushedFcn',@(~,~)viewSession());
uibutton(toolbar,'Text','Run group analysis','ButtonPushedFcn',@(~,~)analyze());
uibutton(toolbar,'Text','Analysis settings','ButtonPushedFcn',@(~,~)analyze());
info=uilabel(root,'Text','Create or open a project. Raw recordings remain in their source folder.'); info.Layout.Row=2;
tabs=uitabgroup(root); tabs.Layout.Row=3;
tab=uitab(tabs,'Title','Sessions (same mouse may have multiple conditions)');
g=uigridlayout(tab,[3 1]); g.RowHeight={34,24,'1x'};
selection=uigridlayout(g,[1 6]); selection.Layout.Row=1; selection.Padding=[0 0 0 0];
selection.ColumnWidth={110,110,220,120,120,140};
uibutton(selection,'Text','Check all','Tag','CheckAll','ButtonPushedFcn',@(~,~)selectSessions('all'));
uibutton(selection,'Text','Uncheck all','Tag','UncheckAll','ButtonPushedFcn',@(~,~)selectSessions('none'));
groupDD=uidropdown(selection,'Items',{'Choose group'},'Tag','SelectionGroup');
uibutton(selection,'Text','Check group','Tag','CheckGroup','ButtonPushedFcn',@(~,~)selectSessions('group'));
uibutton(selection,'Text','Uncheck group','Tag','UncheckGroup','ButtonPushedFcn',@(~,~)selectSessions('ungroup'));
uibutton(selection,'Text','Only this group','Tag','OnlyGroup','ButtonPushedFcn',@(~,~)selectSessions('only'));
hint=uilabel(g,'Text','Plots combine the same Group + Label + ROI + behavior. Label is the condition, not a mouse ID.');hint.Layout.Row=2;
st=uitable(g,'CellEditCallback',@(~,~)sessionEdited(),'Tag','SessionsTable'); st.Layout.Row=3;
tab=uitab(tabs,'Title','Animal groups'); g=uigridlayout(tab,[1 1]);
at=uitable(g,'ColumnEditable',[false true],'ColumnSortable',[true true], ...
    'CellEditCallback',@(~,~)sessionEdited(),'Tag','AnimalGroupsTable');
tab=uitab(tabs,'Title','ROI names'); g=uigridlayout(tab,[1 1]);
rt=uitable(g,'ColumnEditable',[false true],'CellEditCallback',@(~,~)markDirty());
tab=uitab(tabs,'Title','Behavior types'); g=uigridlayout(tab,[2 1]); g.RowHeight={36,'1x'};
uilabel(g,'Text','Name keys 1-9; blank disables a key. Existing tags retain their original names. Save configuration, then reopen the viewer.');
bt=uitable(g,'ColumnEditable',[false true],'CellEditCallback',@(~,~)markDirty(),'Tag','BehaviorTypesTable');
status=uilabel(root,'Text','Local only; GitHub push requires your later approval.'); status.Layout.Row=4;
dirty=false; analysisApp=[]; fig.CloseRequestFcn=@(~,~)closeManager();
refresh();

    function refresh()
        if isempty(p), return; end
        info.Text=sprintf('%s | %s | %d animals / %d groups / %d ROIs / %d sessions | %s', ...
            p.Name,p.BehaviorTask,numel(p.Animals),numel(p.Groups),numel(p.ROIs),numel(p.Sessions),strjoin(p.Behaviors,', '));
        at.Data=struct2table(p.Animals); at.ColumnName={'AnimalID','Group'};
        st.Data=struct2table(p.Sessions); updateSessionGroups();
        st.ColumnName=st.Data.Properties.VariableNames;
        st.ColumnEditable=~ismember(st.Data.Properties.VariableNames,{'ID','Group'});
        st.ColumnSortable=true(1,width(st.Data));
        rt.Data=struct2table(p.ROIs); rt.ColumnName={'CSV ROI ID','ROI name'};
        bt.Data=table((1:9)',string(fp.behavior_slots(p))','VariableNames',{'Key','Name'});
        bt.ColumnName={'Shortcut (1-9)','Behavior name'};
        groupDD.Items=cellstr(string(p.Groups));
        dirty=~isempty(repairs);
        if dirty
            status.Text=sprintf('Repaired %d imported ID/condition fields in memory. Review and Save configuration to keep them.',numel(repairs));
        end
    end
    function markDirty(), dirty=true; status.Text='Configuration changed; save before using it.'; end
    function updateSessionGroups()
        t=st.Data; a=at.Data; group=strings(height(t),1);
        for n=1:height(t)
            match=find(string(a.ID)==string(t.AnimalID(n)),1);
            if ~isempty(match), group(n)=string(a.Group(match)); end
        end
        t.Group=group; st.Data=movevars(t,'Group','After','AnimalID');
    end
    function sessionEdited()
        updateSessionGroups(); markDirty();
    end
    function selectSessions(action)
        if isempty(p), return; end
        updateSessionGroups(); st.Data=fp.select_sessions(st.Data,action,groupDD.Value); markDirty();
        status.Text=sprintf('%d / %d sessions checked. Save configuration to keep selection.',sum(st.Data.Include),height(st.Data));
    end
    function ok=saveChanges()
        ok=false; if isempty(p), return; end
        if ~dirty
            [p,repairs]=fp.load_project(fullfile(p.Root,'project.mat')); refresh();
            if ~dirty, ok=true; return; end
        end
        try
            candidate=p;
            candidate.Sessions=table2struct(removevars(st.Data,'Group')); candidate.Animals=table2struct(at.Data); candidate.ROIs=table2struct(rt.Data);
            candidate=fp.set_behavior_slots(candidate,bt.Data.Name);
            latest=fp.load_project(fullfile(p.Root,'project.mat'));
            % Analysis window can independently save defaults while this manager is open.
            if isequaln(candidate.Settings,p.Settings), candidate.Settings=latest.Settings; end
            for k=1:numel(candidate.Sessions)
                % Merge independent viewer sync edits if these cells were not changed here.
                id=candidate.Sessions(k).ID; z=find(strcmp({latest.Sessions.ID},id));
                original=find(strcmp({p.Sessions.ID},id),1);
                if isempty(z), continue; end
                for field={'VideoOffset_s','SyncConfirmed'}
                    name=field{1};
                    if ~isempty(original) && isequal(candidate.Sessions(k).(name),p.Sessions(original).(name))
                        candidate.Sessions(k).(name)=latest.Sessions(z).(name);
                    end
                end
            end
            if ~isempty(repairs)
                backup=fullfile(p.Root,['backup_import_repair_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); mkdir(backup);
                for name={'project.mat','project.json','sessions.csv','animals.csv'}
                    src=fullfile(p.Root,name{1}); if isfile(src),copyfile(src,fullfile(backup,name{1}));end
                end
                writetable(struct2table(repairs),fullfile(backup,'repairs.csv'));
            end
            fp.save_project(candidate); p=candidate; repairs=[]; dirty=false; ok=true;
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
        try, candidate=fp.new_project_dialog(); if ~isempty(candidate), p=candidate; repairs=[]; refresh(); end
        catch ME, uialert(fig,ME.message,'New project'); end
    end
    function openProject()
        if ~leave(), return; end
        [f,d]=uigetfile('*.mat','Open project.mat'); if isequal(f,0), return; end
        try, [p,repairs]=fp.load_project(fullfile(d,f)); refresh(); catch ME, uialert(fig,ME.message,'Open project'); end
    end
    function viewSession()
        if ~saveChanges(), return; end
        try, fiber_photometry_video_sync_multiroi(fullfile(p.Root,'project.mat')); catch ME, uialert(fig,ME.message,'Viewer'); end
    end
    function analyze()
        if ~saveChanges(), return; end
        try
            if ~isempty(analysisApp) && isvalid(analysisApp.Figure) && strcmp(analysisApp.ProjectRoot,p.Root)
                figure(analysisApp.Figure); return;
            end
            analysisApp=fp_group_analysis_gui(fullfile(p.Root,'project.mat'));
            status.Text='Adjust parameters in the analysis window, then click Plot.';
        catch ME, uialert(fig,ME.message,'Analysis'); end
    end
    function closeManager()
        if leave(), delete(fig); end
    end
end

