function app=fp_group_analysis_gui(projectFile,varargin)
% Per-run parameters; changing controls does not overwrite project defaults.
ip=inputParser; addParameter(ip,'Visible','on'); parse(ip,varargin{:});
p=fp.load_project(projectFile); s=fp.plot_settings(p.Settings); figures=gobjects(0); result=[]; busy=false;
fig=uifigure('Name',['Group analysis | ' p.Name],'Position',[100 80 820 620],'Visible',ip.Results.Visible,'Tag','FPGroupAnalysis');
root=uigridlayout(fig,[5 1]); root.RowHeight={26,'1x',32,32,40}; root.RowSpacing=6;
uilabel(root,'Text',['Group analysis | ' p.Name],'FontWeight','bold');
body=uigridlayout(root,[1 2]); body.Layout.Row=2; body.Padding=[0 0 0 0]; body.ColumnSpacing=8;
left=uipanel(body,'Title','Signal / event alignment');
right=uipanel(body,'Title','Plot display');
analysis=uigridlayout(left,[14 2]); analysis.ColumnWidth={180,'1x'};
analysis.RowHeight=repmat({24},1,14); analysis.RowSpacing=3; analysis.Padding=[8 8 8 8];
display=uigridlayout(right,[13 2]); display.ColumnWidth={180,'1x'};
display.RowHeight=repmat({24},1,13); display.RowSpacing=3; display.Padding=[8 8 8 8];
grid=analysis;
c=struct;
numeric('PreTime','Pre-time (<0, s)',s.PreTime);
numeric('PostTime','Post-time (>0, s)',s.PostTime);
numeric('BaselineStart','Baseline start (s)',s.Baseline(1));
numeric('BaselineEnd','Baseline end (exclusive, s)',s.Baseline(2));
numeric('AUCStart','AUC start (s)',s.AUCWindow(1));
numeric('AUCEnd','AUC end (s)',s.AUCWindow(2));
numeric('OutputFs','Output sample rate (Hz)',s.OutputFs);
numeric('LowpassHz','Low-pass cutoff (0 = off, Hz)',s.LowpassHz);
numeric('FilterOrder','Butterworth filter order',s.FilterOrder);
dropdown('SignalMode','Signal mode',{'ratio','470','410'},s.SignalMode);
dropdown('Normalization','Normalization',{'dff_percent','baseline_subtract','none'},s.Normalization);
dropdown('WavelengthAlignment','Wavelength alignment',{'index','interpolate470'},s.WavelengthAlignment);
numeric('MaxGapFactor','Gap threshold (x median dt)',s.MaxGapFactor);
label('Require confirmed video sync');
c.RequireConfirmedSync=uicheckbox(grid,'Text','Required','Value',s.RequireConfirmedSync,'Tag','RequireConfirmedSync','FontSize',11);
grid=display;
dropdown('ConditionGrouping','Conditions: separate/combine',{'separate','combine'},s.ConditionGrouping);
c.ConditionGrouping.Tooltip='Separate: one plot per condition. Combine: pool checked sessions within each group and animal, including different phases. Original labels remain in the project snapshot.';
dropdown('PlotUnit','Average and heatmap rows',{'animal','trial'},'animal');
dropdown('HeatmapRowLabels','Heatmap Y labels',{'detailed','endpoints'},s.HeatmapRowLabels);
c.HeatmapRowLabels.Tooltip='Detailed: animal / session / event identity and sorted trial row. Endpoints: only 1 and total rows N.';
dropdown('SortOrder','Heatmap AUC sort',{'descend','ascend'},s.SortOrder);
numeric('PercentileLow','Heatmap percentile: low',s.HeatmapPercentiles(1));
numeric('PercentileHigh','Heatmap percentile: high',s.HeatmapPercentiles(2));
label('Heatmap limits (blank = auto)');
c.HeatmapCLim=uieditfield(grid,'text','Value',strtrim(num2str(s.HeatmapCLim)),'Tag','HeatmapCLim','FontSize',11);
label('Gray individual traces');
c.ShowIndividualTraces=uicheckbox(grid,'Text','Show','Value',s.ShowIndividualTraces,'Tag','ShowIndividualTraces','FontSize',11);
c.ShowIndividualTraces.Tooltip='Animal mode: each animal mean; trial mode: each accepted trial. Group mean and SEM calculations are unchanged.';
label('Curve Y min (blank = auto)');
c.CurveYMin=uieditfield(grid,'text','Tag','CurveYMin','FontSize',11);
label('Curve Y max (blank = auto)');
c.CurveYMax=uieditfield(grid,'text','Tag','CurveYMax','FontSize',11);
if ~isempty(s.CurveYLim)
    c.CurveYMin.Value=num2str(s.CurveYLim(1)); c.CurveYMax.Value=num2str(s.CurveYLim(2));
end
tip=uilabel(grid,'Text',sprintf(['All ROI/behavior curves share one Y range. Set both limits or leave both blank.\n' ...
    'Endpoints show sorted row numbers 1 and N; identity remains in the row CSV.']), ...
    'WordWrap','on','FontSize',11); tip.Layout.Row=[11 13]; tip.Layout.Column=[1 2];
note=uilabel(root,'Text','Animal: average within each mouse first. Trial: descriptive SEM across trials nested in animals.', ...
    'WordWrap','on','FontSize',11); note.Layout.Row=3;
buttons=uigridlayout(root,[1 2]); buttons.Layout.Row=4; buttons.Padding=[0 0 0 0];
plotButton=uibutton(buttons,'Text','Plot','Tag','PlotAnalysis','ButtonPushedFcn',@(~,~)plotNow());
saveButton=uibutton(buttons,'Text','Save parameters as project defaults','ButtonPushedFcn',@(~,~)saveDefaults());
status=uilabel(root,'Text','Set parameters, then Plot. Previous figures from this window are replaced; files are kept.', ...
    'WordWrap','on','FontSize',11); status.Layout.Row=5;
fig.CloseRequestFcn=@(~,~)closeWindow(); fig.DeleteFcn=@(~,~)clearFigures();
app=struct('Figure',fig,'Controls',c,'PlotButton',plotButton,'Plot',@plotNow, ...
    'GetState',@getState,'ReadSettings',@readSettings,'ProjectRoot',p.Root);
    function label(text), uilabel(grid,'Text',text,'FontSize',11); end
    function numeric(name,text,value)
        label(text); c.(name)=uieditfield(grid,'numeric','Value',value,'Tag',name,'FontSize',11);
    end
    function dropdown(name,text,items,value)
        label(text); c.(name)=uidropdown(grid,'Items',items,'Value',value,'Tag',name,'FontSize',11);
    end
    function candidate=readSettings()
        candidate=s;
        for name={'PreTime','PostTime','OutputFs','LowpassHz','FilterOrder','MaxGapFactor', ...
                'SignalMode','Normalization','SortOrder','WavelengthAlignment','RequireConfirmedSync', ...
                'HeatmapRowLabels','ShowIndividualTraces','ConditionGrouping'}
            candidate.(name{1})=c.(name{1}).Value;
        end
        candidate.Baseline=[c.BaselineStart.Value c.BaselineEnd.Value];
        candidate.AUCWindow=[c.AUCStart.Value c.AUCEnd.Value];
        candidate.HeatmapPercentiles=[c.PercentileLow.Value c.PercentileHigh.Value];
        lo=strtrim(c.CurveYMin.Value); hi=strtrim(c.CurveYMax.Value);
        assert(isempty(lo)==isempty(hi),'Set both curve Y limits, or leave both blank for shared automatic scaling.');
        if isempty(lo), candidate.CurveYLim=[];
        else, candidate.CurveYLim=[str2double(lo) str2double(hi)]; end
        text=strtrim(c.HeatmapCLim.Value);
        if isempty(text), candidate.HeatmapCLim=[];
        else
            values=split(string(regexprep(text,'[,;\[\]]',' ')));
            values=values(strlength(values)>0); candidate.HeatmapCLim=str2double(values)';
            assert(numel(candidate.HeatmapCLim)==2,'Heatmap fixed limits need two numbers.');
        end
        check=p; check.Settings=candidate; fp.validate_project(check);
    end
    function plotNow()
        if busy, return; end
        try
            settings=readSettings(); latest=fp.load_project(fullfile(p.Root,'project.mat'));
            latest.Settings=settings; fp.validate_project(latest);
            busy=true; plotButton.Enable='off'; saveButton.Enable='off';
            cleanup=onCleanup(@finish); %#ok<NASGU>
            clearFigures(); status.Text='Analyzing and plotting...'; drawnow;
            result=fp_analyze_project(latest,PlotUnit=c.PlotUnit.Value,Visible=ip.Results.Visible);
            figures=result.Figures;
            status.Text=sprintf('%d accepted ROI-trials | %s | %s',numel(result.Trials),c.PlotUnit.Value,result.OutputFolder);
        catch ME
            status.Text=['Analysis error: ' ME.message];
            if strcmp(fig.Visible,'on'), uialert(fig,ME.message,'Analysis'); end
        end
    end
    function finish()
        busy=false;
        if isvalid(fig), plotButton.Enable='on'; saveButton.Enable='on'; end
    end
    function saveDefaults()
        try
            settings=readSettings(); latest=fp.load_project(fullfile(p.Root,'project.mat'));
            latest.Settings=settings; fp.save_project(latest); s=settings;
            status.Text='Project defaults saved. Plotting unit applies to this analysis window only.';
        catch ME, uialert(fig,ME.message,'Settings'); end
    end
    function state=getState()
        state=struct('Result',result,'Figures',figures(isgraphics(figures)),'Busy',busy,'Status',status.Text);
    end
    function clearFigures()
        delete(figures(isgraphics(figures))); figures=gobjects(0);
    end
    function closeWindow()
        if busy, return; end
        clearFigures(); delete(fig);
    end
end
