function [p,changes]=repair_import_metadata(p)
% Repair only recognizable legacy discovery errors, in memory; no file writes.
changes=struct('SessionID',{},'Field',{},'Previous',{},'Corrected',{});
for k=1:numel(p.Sessions)
    s=p.Sessions(k); info=fp.recording_identity(s.CSV,p.Groups);
    if ~isempty(s.Video)
        videoInfo=fp.recording_identity(s.Video,p.Groups);
        if ~strcmp(info.AnimalID,videoInfo.AnimalID), continue; end
    end
    match=find(strcmp({p.Animals.ID},info.AnimalID));
    if ~isscalar(match), continue; end
    if ismember(string(info.GroupHint),string(p.Groups)) && ~strcmp(p.Animals(match).Group,info.GroupHint), continue; end
    if ~ismember(string(s.AnimalID),string({p.Animals.ID})) && ...
            ~isempty(regexp(s.AnimalID,'^\d{14}$','once'))
        changes(end+1)=entry(s.ID,'AnimalID',s.AnimalID,info.AnimalID); %#ok<AGROW>
        p.Sessions(k).AnimalID=info.AnimalID;
    end
    % Do not relabel a known but contradictory animal identity.
    if ~strcmp(p.Sessions(k).AnimalID,info.AnimalID), continue; end
    wrongLabel=strcmp(s.Label,info.AnimalFolder)||strcmp(s.Label,info.AnimalID)|| ...
        ~isempty(regexp(s.Label,'^\d{14}$','once'));
    if wrongLabel && ~isempty(info.Label) && ~strcmp(s.Label,info.Label)
        changes(end+1)=entry(s.ID,'Label',s.Label,info.Label); %#ok<AGROW>
        p.Sessions(k).Label=info.Label;
    end
end
end
function c=entry(id,field,old,value)
c=struct('SessionID',id,'Field',field,'Previous',old,'Corrected',value);
end
