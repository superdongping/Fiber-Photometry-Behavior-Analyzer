function [p,repairs] = load_project(file)
if isstruct(file)
    [p,repairs]=fp.repair_import_metadata(file); fp.validate_project(p); return;
end
if isfolder(file), file=fullfile(file,'project.mat'); end
v=load(file,'project');
assert(isfield(v,'project'),'Not an FP project.');
p=v.project;
p.Root=fileparts(char(file)); % project can be moved; sources retain absolute paths.
[p,repairs]=fp.repair_import_metadata(p);
fp.validate_project(p);
end
