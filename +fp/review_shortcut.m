function [action,value]=review_shortcut(key,character,modifiers)
% Map MATLAB KeyData without performing an action.
action=''; value=0;
key=lower(string(key)); character=string(character); modifiers=lower(string(modifiers));
if any(ismember(modifiers,["alt","command","meta"])), return; end
control=any(ismember(modifiers,["control","ctrl"]));
if control
    if key=="leftarrow", action='step'; value=-5;
    elseif key=="rightarrow", action='step'; value=5; end
    return;
end
switch key
    case 'space', action='toggle';
    case 'leftarrow', action='step'; value=-1;
    case 'rightarrow', action='step'; value=1;
    case 'uparrow', action='speed'; value=1;
    case 'downarrow', action='speed'; value=-1;
    case 't', action='tag';
    otherwise
        token=char(key);
        if startsWith(key,'numpad'), token=extractAfter(key,'numpad'); end
        number=str2double(token);
        if isfinite(number) && ismember(number,1:9), action='behavior'; value=number; end
end
end
