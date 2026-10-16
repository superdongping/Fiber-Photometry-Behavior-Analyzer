function recordings=find_recordings(dataRoot)
% Discover real input records; application/tests/backups are never data roots.
dataRoot=char(dataRoot);
assert(~isfile(fullfile(dataRoot,'launch_review.m')) && ~isfolder(fullfile(dataRoot,'+fp')), ...
    ['Selected the PROGRAM folder, not recordings. Choose the parent ' ...
    '2026-10-15 Inper Output folder, or its NPR E / NPR R data folder.']);
recordsFile=fullfile(dataRoot,'_conversion','records.json');
if isfile(recordsFile)
    records=jsondecode(fileread(recordsFile));
    files=string({records.csv}); videos=string({records.video});
    labels=string({records.batch}); animals=string({records.mouse});
else
    found=dir(fullfile(dataRoot,'**','*(Camera).csv'));
    paths=string(fullfile({found.folder},{found.name}));
    relative=extractAfter(paths,strlength(string(dataRoot))+1);
    relative=replace(relative,'\','/');
    keep=~contains('/'+relative,["/tests/","/_conversion/","/reference_originals/","/FP_MultiROI_Review/","/results/"]);
    % contains with multiple patterns returns true for any match.
    keep=keep & ~startsWith(lower(string({found.name})),'sample ');
    files=paths(keep); videos=strings(size(files)); labels=strings(size(files)); animals=strings(size(files));
    for k=1:numel(files)
        [folder,stem]=fileparts(files(k)); [parent,animals(k)]=fileparts(folder); [~,labels(k)]=fileparts(parent);
        candidate=fullfile(folder,erase(stem,'(Camera)')+'.avi');
        if isfile(candidate), videos(k)=candidate; end
    end
end
recordings=struct('CSV',{},'Video',{},'Label',{},'AnimalID',{});
for k=1:numel(files)
    if ~isfile(files(k)), continue; end
    token=regexp(char(animals(k)),'#[A-Za-z0-9_-]+','match','once');
    if isempty(token), token=char(animals(k)); end
    recordings(end+1)=struct('CSV',char(files(k)),'Video',char(videos(k)), ...
        'Label',char(labels(k)),'AnimalID',token); %#ok<AGROW>
end
assert(~isempty(recordings), ...
    'No recording CSVs found. Choose 2026-10-15 Inper Output or its NPR E / NPR R data folder. Program, test and backup folders are excluded.');
end
