function labels=review_session_labels(p,indices,blind)
% Group is looked up by animal ID, never by the session's row position.
labels=cell(1,numel(indices));
for k=1:numel(indices)
    r=p.Sessions(indices(k)); condition=r.Label;
    if blind
        for g=1:numel(p.Groups)
            condition=regexprep(condition,regexptranslate('escape',p.Groups{g}),'[hidden]','ignorecase');
        end
        labels{k}=sprintf('%s | %s | %s',r.ID,r.AnimalID,condition);
    else
        animal=find(strcmp({p.Animals.ID},r.AnimalID),1);
        if isempty(animal), group='Unassigned'; else, group=p.Animals(animal).Group; end
        labels{k}=sprintf('%s | %s | %s | Group: %s',r.ID,r.AnimalID,condition,group);
    end
end
end
