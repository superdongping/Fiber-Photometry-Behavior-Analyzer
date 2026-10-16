function data = read_recording(file, rois)
% Name-based import; never silently substitute ROI-1 for a missing ROI.
file=char(file); selected=file; timing='Shared CSV time (legacy export)';
[folder,stem]=fileparts(file);
metaFile=fullfile(folder,[erase(stem,'(Camera)') '_metadata.json']);
if isfile(metaFile)
    meta=jsondecode(fileread(metaFile));
    if isfield(meta,'detailed_csv') && isfile(meta.detailed_csv)
        selected=meta.detailed_csv; timing='Independent wavelength timestamps from lossless detailed CSV';
    end
end
opts=detectImportOptions(selected,VariableNamingRule='preserve',TextType='string');
names=string(opts.VariableNames);
if ismember("Time",names), opts=setvartype(opts,'Time','string'); end
T=readtable(selected,opts);
names=string(T.Properties.VariableNames);
if ismember("Time_410_s",names)
    t410=double(T.Time_410_s); t470=double(T.Time_470_s);
else
    assert(ismember("Time",names),'CSV has no Time column.');
    t410=parseTime(T.Time); t470=t410;
end
first=find(isfinite(t410),1); assert(~isempty(first),'No valid time samples.');
origin=min([t410;t470],[],'omitnan'); legacyShift=t410(first)-origin;
t410=t410-origin; t470=t470-origin;
assert(all(diff(t410(isfinite(t410)))>0) && all(diff(t470(isfinite(t470)))>0),'Timestamps must be strictly increasing.');
if nargin<2 || isempty(rois)
    tokens=regexp(names,'^(ROI-\d+)_sig_(?:410|470)$','tokens','once');
    ids=unique(string(cellfun(@(x) firstToken(x),tokens,'UniformOutput',false)),'stable');
    ids=ids(strlength(ids)>0);
    rois=struct('SourceID',cellstr(ids),'Name',cellstr(ids));
end
data=struct('File',file,'ReadFile',selected,'Timing',timing,'LegacyTimeShift_s',legacyShift,'ROIs',[],'Duration',max([t410;t470],[],'omitnan'));
for k=1:numel(rois)
    id=string(rois(k).SourceID);
    assert(all(ismember(id+"_sig_"+["410","470"],names)),'Missing columns for %s in %s.',id,file);
    a=double(T.(id+"_sig_410")); b=double(T.(id+"_sig_470"));
    i=isfinite(t410); j=isfinite(t470);
    r=struct('SourceID',char(id),'Name',rois(k).Name,'t410',t410(i), ...
        'y410',a(i),'t470',t470(j),'y470',b(j));
    data.ROIs=[data.ROIs r]; %#ok<AGROW>
end
end

function token=firstToken(x)
if isempty(x), token=''; else, token=x{1}; end
end

function t=parseTime(v)
if isduration(v), t=seconds(v); return; end
if isdatetime(v), t=seconds(v-v(1)); return; end
if isnumeric(v), t=double(v); return; end
v=string(v); t=nan(size(v));
for k=1:numel(v)
    m=regexp(char(v(k)),'^(?:(\d+):)?(\d{1,2}):(\d{2}):(\d{2}(?:\.\d+)?)$','tokens','once');
    assert(~isempty(m),'Invalid TimeSpan string: %s.',v(k));
    if numel(m)==3, m=[{'0'} m]; end
    t(k)=str2double(m{1})*86400+str2double(m{2})*3600+str2double(m{3})*60+str2double(m{4});
end
end
