function config=example_project_config()
% OPTIONAL programmatic template. Replace placeholder labels/IDs before use.
% GUI: launch_review -> New project asks for these fields without editing code.
config=struct;
config.Name='My_FP_Project';
config.BehaviorTask='NPR';
config.Behaviors={'Approach','Investigation'}; % replace with your actual tag definitions
config.Groups={'YOUR_GROUP_1','YOUR_GROUP_2'};
config.Animals=struct('ID',{'#REPLACE_A','#REPLACE_B'}, ...
    'Group',{'YOUR_GROUP_1','YOUR_GROUP_2'});
config.ROIs=struct('SourceID',{'ROI-1','ROI-2'},'Name',{'YOUR_ROI_1','YOUR_ROI_2'});
config.Settings=fp.defaults();
% After editing: p=fp.create_project(newProjectFolder,config,recordingFolder);
end
