function T=event_display_table(events,compactTime)
T=fp.order_events(events);
T=addvars(T,"E"+string((1:height(T))'),'Before',1,'NewVariableNames','Event');
if nargin>1 && compactTime
    T.Time_signal_s=string(compose('%.1f',T.Time_signal_s));
end
end
