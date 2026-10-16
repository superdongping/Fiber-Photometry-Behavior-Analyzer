function validate_project(p)
assert(p.Version==1,'Unsupported project schema.');
assert(~isempty(strtrim(p.Name)) && ~isempty(p.Behaviors),'Name and behavior labels are required.');
ids=string({p.Animals.ID}); groups=string(p.Groups);
assert(~isempty(groups) && numel(unique(groups))==numel(groups) && all(strlength(strtrim(groups))>0),'Group names must be unique and nonempty.');
assert(numel(unique(ids))==numel(ids) && all(strlength(strtrim(ids))>0),'Animal IDs must be unique and nonempty.');
assert(all(ismember(string({p.Animals.Group}),groups)),'Every animal needs a defined group.');
assert(numel(unique(string(p.Behaviors)))==numel(p.Behaviors) && all(strlength(strtrim(string(p.Behaviors)))>0),'Behavior labels must be unique and nonempty.');
if isfield(p,'BehaviorSlots')
    slots=string(p.BehaviorSlots); active=slots(strlength(slots)>0);
    assert(numel(slots)==9 && ~isempty(active) && numel(unique(active))==numel(active) && all(ismember(active,string(p.Behaviors))), ...
        'Behavior slots must contain nine entries with unique, defined nonempty names.');
end
assert(~isempty(p.ROIs) && numel(unique(string({p.ROIs.SourceID})))==numel(p.ROIs),'ROI source IDs must be unique.');
assert(all(strlength(strtrim(string({p.ROIs.Name})))>0),'ROI names must not be empty.');
assert(numel(unique(string({p.ROIs.Name})))==numel(p.ROIs),'ROI names must be unique.');
assert(numel(unique(string({p.Sessions.ID})))==numel(p.Sessions),'Session IDs must be unique.');
for k=1:numel(p.Sessions)
    r=p.Sessions(k);
    assert(isfinite(r.VideoOffset_s),'Video offsets must be finite.');
    assert(~isempty(strtrim(r.Label)),'Session/condition labels must not be empty.');
    if r.Include
        assert(ismember(string(r.AnimalID),ids),'Included session %s has an unknown animal.',r.ID);
        assert(isfile(r.CSV),'Missing CSV for %s.',r.ID);
        assert(isfile(r.Video),'Missing video for %s.',r.ID);
    end
end
s=p.Settings;
assert(isfinite(s.PreTime) && isfinite(s.PostTime) && s.PreTime<0 && s.PostTime>0,'Invalid event window.');
assert(s.Baseline(1)>=s.PreTime && s.Baseline(2)<=0 && s.Baseline(1)<s.Baseline(2),'Invalid baseline window.');
assert(s.AUCWindow(1)>=s.PreTime && s.AUCWindow(2)<=s.PostTime && s.AUCWindow(1)<s.AUCWindow(2),'Invalid AUC window.');
assert(isfinite(s.OutputFs) && s.OutputFs>0 && isfinite(s.LowpassHz) && s.LowpassHz>=0,'Invalid sample rate/cutoff.');
assert(ismember(string(s.SignalMode),["ratio","470","410"]),'Invalid analysis mode.');
assert(ismember(string(s.Normalization),["dff_percent","baseline_subtract","none"]),'Invalid normalization.');
assert(ismember(string(s.WavelengthAlignment),["index","interpolate470"]),'Invalid wavelength alignment.');
assert(ismember(string(s.SortOrder),["ascend","descend"]),'Invalid AUC sorting order.');
end
