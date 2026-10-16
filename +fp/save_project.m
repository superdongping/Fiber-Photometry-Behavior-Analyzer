function save_project(p)
fp.validate_project(p);
if ~isfolder(p.Root), mkdir(p.Root); end
for name = ["events","results"]
    if ~isfolder(fullfile(p.Root,name)), mkdir(fullfile(p.Root,name)); end
end
project = p; %#ok<NASGU>
tmp = [tempname(p.Root) '.mat'];
save(tmp,'project');
movefile(tmp,fullfile(p.Root,'project.mat'),'f');
fid = fopen(fullfile(p.Root,'project.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot save project JSON.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(p,PrettyPrint=true));
if ~isempty(p.Animals), writetable(struct2table(p.Animals),fullfile(p.Root,'animals.csv')); end
if ~isempty(p.Sessions), writetable(struct2table(p.Sessions),fullfile(p.Root,'sessions.csv')); end
end
