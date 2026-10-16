function [t,y,label] = process_trace(r, mode, settings)
% Same ratio + fourth-order zero-phase LP core as v4_6 / V1_3.
switch string(mode)
    case "410", t=r.t410; y=r.y410; label='410 nm (a.u.)';
    case "470", t=r.t470; y=r.y470; label='470 nm (a.u.)';
    case "ratio"
        t=r.t410;
        if strcmp(settings.WavelengthAlignment,'interpolate470')
            b=interp1(r.t470,r.y470,t,'linear',NaN);
            gap=find(diff(r.t470)>settings.MaxGapFactor*median(diff(r.t470)));
            for k=gap(:)', b(t>r.t470(k) & t<r.t470(k+1))=NaN; end
        else
            b=nan(size(t)); n=min(numel(t),numel(r.y470)); b(1:n)=r.y470(1:n);
        end
        y=b./r.y410; y(r.y410==0)=NaN; label='470 / 410 (a.u.)';
    otherwise, error('FP:Mode','Unknown signal mode.');
end
t=t(:); y=y(:); y(~isfinite(y))=NaN;
if settings.LowpassHz<=0, return; end
dt=median(diff(t)); fs=1/dt;
assert(settings.LowpassHz<fs/2,'Low-pass cutoff must be below Nyquist (%.3g Hz).',fs/2);
assert(exist('butter','file')==2 && exist('filtfilt','file')==2,'Signal Processing Toolbox required for low-pass. Set LowpassHz=0 to disable.');
[b,a]=butter(settings.FilterOrder,settings.LowpassHz/(fs/2),'low');
good=isfinite(y);
gap=[false;diff(t)>settings.MaxGapFactor*dt];
starts=find(good & ([true;~good(1:end-1)] | gap));
ends=find(good & ([~good(2:end);true] | [gap(2:end);false]));
for k=1:numel(starts)
    idx=starts(k):ends(k);
    if numel(idx)>3*(max(numel(a),numel(b))-1)
        y(idx)=filtfilt(b,a,y(idx));
    else
        y(idx)=NaN; % no inconsistent mix of filtered and unfiltered short segments
    end
end
end
