function p=create_project(root,config,dataRoot)
% config: Name,BehaviorTask,Behaviors,Groups,Animals(ID,Group),ROIs(SourceID,Name).
assert(~isfile(fullfile(root,'project.mat')),'A project already exists here.');
p=config; p.Version=1; p.Root=char(root); p.DataRoot=char(dataRoot);
if ~isfield(p,'Settings'), p.Settings=fp.defaults(); end
p.Created=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
p.Sessions=struct('ID',{},'AnimalID',{},'Label',{},'CSV',{},'Video',{}, ...
    'Include',{},'VideoOffset_s',{},'SyncConfirmed',{});
records=fp.find_recordings(dataRoot);
for k=1:numel(records)
    token=records(k).AnimalID;
    known=ismember(string(token),string({p.Animals.ID}));
    p.Sessions(end+1)=struct('ID',sprintf('S%03d',k),'AnimalID',token, ...
        'Label',records(k).Label,'CSV',records(k).CSV,'Video',records(k).Video, ...
        'Include',known && isfile(records(k).Video),'VideoOffset_s',0,'SyncConfirmed',false); %#ok<AGROW>
end
assert(~isempty(p.Sessions),'No sample-format recordings found in source folder.');
fp.save_project(p);
end
