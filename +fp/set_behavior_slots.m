function p=set_behavior_slots(p,names)
slots=cellstr(strtrim(string(names(:))));
assert(numel(slots)==9,'Define exactly nine behavior slots; unused names may be blank.');
active=slots(~cellfun(@isempty,slots));
assert(~isempty(active),'Define at least one behavior.');
assert(numel(unique(string(active)))==numel(active),'Behavior names must be unique.');
% Existing annotations retain their labels and remain available to analysis.
used=strings(0,1);
for k=1:numel(p.Sessions)
    e=fp.load_events(p,p.Sessions(k).ID);
    used=[used;string(e.Behavior)]; %#ok<AGROW>
end
p.BehaviorSlots=slots';
p.Behaviors=cellstr(unique([string(active(:));used],'stable'))';
end
