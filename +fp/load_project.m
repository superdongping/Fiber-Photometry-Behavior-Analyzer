function p = load_project(file)
if isstruct(file), p=file; fp.validate_project(p); return; end
if isfolder(file), file=fullfile(file,'project.mat'); end
v=load(file,'project');
assert(isfield(v,'project'),'Not an FP project.');
p=v.project;
p.Root=fileparts(char(file)); % project can be moved; sources retain absolute paths.
fp.validate_project(p);
end
