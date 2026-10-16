function file=event_file(p, sessionID)
assert(~isempty(regexp(char(sessionID),'^[A-Za-z0-9_-]+$','once')),'Unsafe session ID.');
file=fullfile(p.Root,'events',[char(sessionID) '_events.csv']);
end
