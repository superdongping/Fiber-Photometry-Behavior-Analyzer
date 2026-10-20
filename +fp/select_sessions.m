function T=select_sessions(T,action,group)
% Change Include only. Table row order may have been changed by sorting.
if nargin<3,group='';end
switch action
    case 'all', T.Include(:)=true;
    case 'none', T.Include(:)=false;
    case 'group', T.Include(string(T.Group)==string(group))=true;
    case 'ungroup', T.Include(string(T.Group)==string(group))=false;
    case 'only', T.Include=string(T.Group)==string(group);
    otherwise, error('FP:Selection','Unknown selection action.');
end
end
