function p=new_project_dialog()
p=[];
answer=inputdlg({'Project name','Behavior task (e.g. NPR)','Behavior labels, separated by commas','Number of groups','Number of ROIs'}, ...
    'New fiber photometry project',[1 65],{'My_FP_Project','NPR','Behavior1,Behavior2','2','2'});
if isempty(answer), return; end
nGroups=str2double(answer{4}); nROIs=str2double(answer{5});
assert(isfinite(nGroups) && nGroups>=1 && nGroups==fix(nGroups),'Invalid group count.');
assert(isfinite(nROIs) && nROIs>=1 && nROIs==fix(nROIs),'Invalid ROI count.');
config=struct('Name',strtrim(answer{1}),'BehaviorTask',strtrim(answer{2}), ...
    'Behaviors',{splitList(answer{3})},'Groups',{{}},'Animals',[],'ROIs',[]);
for k=1:nGroups
    a=inputdlg({'Group name','Animal count','Animal IDs, comma-separated (match #16 etc.)'}, ...
        sprintf('Group %d/%d',k,nGroups),[1 70],{sprintf('Group%d',k),'',''});
    if isempty(a), return; end
    ids=splitList(a{3}); count=str2double(a{2});
    assert(isfinite(count) && count>=1 && count==numel(ids),'Animal count does not match ID list.');
    config.Groups{end+1}=strtrim(a{1});
    for j=1:numel(ids)
        config.Animals=[config.Animals struct('ID',ids{j},'Group',strtrim(a{1}))]; %#ok<AGROW>
    end
end
for k=1:nROIs
    a=inputdlg({'CSV source ROI ID','Display/anatomical name'},sprintf('ROI %d',k),[1 65],{sprintf('ROI-%d',k),sprintf('ROI-%d',k)});
    if isempty(a), return; end
    config.ROIs=[config.ROIs struct('SourceID',strtrim(a{1}),'Name',strtrim(a{2}))]; %#ok<AGROW>
end
sourceDefault=fileparts(fileparts(fileparts(mfilename('fullpath'))));
while true
    source=uigetdir(sourceDefault,'Select DATA: Inper Output or NPR E / NPR R (not FP_MultiROI_Review)');
    if isequal(source,0), return; end
    try, fp.find_recordings(source); break;
    catch ME, uiwait(errordlg(ME.message,'Select recording DATA folder')); end
end
parent=uigetdir(source,'Select parent folder for the NEW analysis project');
if isequal(parent,0), return; end
root=fullfile(parent,matlab.lang.makeValidName(config.Name));
p=fp.create_project(root,config,source);
end

function values=splitList(text)
values=cellstr(strtrim(split(string(text),{',','，',';','；'})));
values=values(~cellfun('isempty',values));
end
