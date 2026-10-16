function blocked=review_shortcut_blocked(object)
% Native controls retain space/arrows/+/- for editing and normal keyboard navigation.
blocked=false;
while ~isempty(object) && isvalid(object)
    name=string(class(object));
    if startsWith(name,'matlab.ui.control.') && ~contains(name,'UIAxes')
        blocked=true; return;
    end
    if ~isprop(object,'Parent'), return; end
    object=object.Parent;
end
end
