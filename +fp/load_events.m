function T=load_events(p,sessionID)
file=fp.event_file(p,sessionID);
if isfile(file)
    T=readtable(file,TextType='string');
else
    T=table(strings(0,1),zeros(0,1),'VariableNames',{'Behavior','Time_signal_s'});
end
T=T(:,{'Behavior','Time_signal_s'});
end
