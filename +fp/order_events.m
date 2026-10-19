function T=order_events(T)
% Event index = chronological row across ALL behaviors in one session.
% Equal onsets use behavior name, then stable input order for identical rows.
T=T(:,{'Behavior','Time_signal_s'});
T.Behavior=string(T.Behavior);
T=sortrows(T,{'Time_signal_s','Behavior'});
end
