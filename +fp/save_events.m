function save_events(p,sessionID,T)
assert(all(ismember(string(T.Behavior),string(p.Behaviors))),'Unknown behavior label.');
assert(all(isfinite(T.Time_signal_s) & T.Time_signal_s>=0),'Event times must be finite and >= 0.');
r=p.Sessions(strcmp({p.Sessions.ID},sessionID)); assert(isscalar(r),'Unknown session.');
d=fp.read_recording(r.CSV,p.ROIs);
assert(all(T.Time_signal_s<=d.Duration),'Events outside signal recording.');
T=sortrows(T,{'Time_signal_s','Behavior'});
T.AnimalID=repmat(string(r.AnimalID),height(T),1);
T.SessionID=repmat(string(sessionID),height(T),1);
T.VideoTime_s=T.Time_signal_s-r.VideoOffset_s;
file=fp.event_file(p,sessionID);
tmp=[tempname(fileparts(file)) '.csv']; writetable(T,tmp);
movefile(tmp,file,'f');
end
