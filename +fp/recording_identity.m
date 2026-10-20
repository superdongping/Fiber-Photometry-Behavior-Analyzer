function info=recording_identity(file,groups)
% Identify batch/[sensor]/animal/[timestamp]/recording without using timestamps as mice.
if nargin<2, groups={}; end
folder=fileparts(char(file)); start=folder; animalFolder=''; id='';
for depth=1:10
    [parent,name]=fileparts(folder);
    tokens=regexp(name,'#[A-Za-z0-9_-]+','match');
    if numel(tokens)==1
        animalFolder=folder; id=tokens{1}; break;
    elseif numel(tokens)>1
        break; % ambiguous identity must not be guessed
    end
    if isempty(parent)||strcmp(parent,folder), break; end
    folder=parent;
end
if isempty(animalFolder)
    [parent,name]=fileparts(start);
    if ~isempty(regexp(name,'^\d{14}$','once'))
        [~,name]=fileparts(parent); start=parent;
    end
    if ~isempty(regexp(name,'^\d{14}$','once')), name=''; end
    id=name; animalFolder=start;
end
[parent,animalName]=fileparts(animalFolder); [batchParent,label]=fileparts(parent);
groupHint='';
if ismember(string(label),string(groups)) || ~isempty(regexpi(label,'sensor|^\d+\s+(ATP|Glu|Lac)($|[^A-Za-z])','once'))
    groupHint=label; [~,label]=fileparts(batchParent);
end
% Only collapse plain NPR phase names; retain treatment qualifiers such as HFD.
phase=regexprep(label,'^\d{4}-\d{2}-\d{2}\s+','');
if ~isempty(regexpi(phase,'^(Metabolic Sensor\s+)?NPR[ _-]+(E|Encoding)$','once')), label='Encoding';
elseif ~isempty(regexpi(phase,'^(Metabolic Sensor\s+)?NPR[ _-]+(R|Retrieval)$','once')), label='Retrieval'; end
info=struct('AnimalID',id,'Label',label,'AnimalFolder',animalName,'GroupHint',groupHint);
end
