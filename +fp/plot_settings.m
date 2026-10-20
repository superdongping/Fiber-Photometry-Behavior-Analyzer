function s=plot_settings(s)
% Backward-compatible display defaults; no project file is changed here.
defaults=struct('HeatmapRowLabels','detailed','CurveYLim',[], ...
    'ShowIndividualTraces',true,'ConditionGrouping','separate');
for field=fieldnames(defaults)'
    name=field{1}; if ~isfield(s,name), s.(name)=defaults.(name); end
end
end
