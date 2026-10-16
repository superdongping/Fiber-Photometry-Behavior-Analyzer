function slots=behavior_slots(p)
% Fixed keyboard assignments; older projects inherit their existing label order.
slots=repmat({''},1,9);
if isfield(p,'BehaviorSlots')
    values=cellstr(string(p.BehaviorSlots));
else
    values=cellstr(string(p.Behaviors));
end
n=min(9,numel(values)); slots(1:n)=values(1:n);
end
