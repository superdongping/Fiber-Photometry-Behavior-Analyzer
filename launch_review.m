function fig=launch_review()
% Open the review project manager without changing any recordings.
addpath(fileparts(mfilename('fullpath')));
fig=fiber_photometry_project();
end
