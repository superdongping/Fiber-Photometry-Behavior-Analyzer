# Fiber Photometry Behavior Analyzer V1.0

One-page quick start - MATLAB R2024a, Windows. Default filtering needs Signal Processing Toolbox.

1. **Launch and create.** Open the repository root in MATLAB; run `launch_analyzer`. Choose **New project** and enter the behavioral task, groups, animal counts/IDs, and source ROI IDs with display names. Select the recording directory and a separate project location. Use **Open project** to resume.
2. **Check the project.** Review Sessions, Animal groups and ROI names. Include only the intended conditions (for example, analyze Encoding and Retrieval in separate projects). In **Behavior types**, name keys **1-9**; leave unused slots blank. Names must be unique. Click **Save configuration**.
3. **Open and synchronize.** Click **View video + ROIs**. Choose ratio, 470, 410, or 470+410. Dual-channel traces use green 470 on the left and blue 410 on the right, with independent scales. Set Video offset against an observable event, then check **Sync checked**. Formula: `video time = signal time - offset`. Default zero does not establish sync; clock drift is not corrected.
4. **Tag and review.** Click video/trace to enable shortcuts. Press a number to select its behavior, then **T** to tag onset at the displayed frame. All ROIs share the event. The right-hand table lists behavior/time: click either cell to pause and jump video plus signals; double-click to edit. Use **Delete selected** for removal and **Save events** regularly. Hold T once per onset; repeat is suppressed.
5. **Analyze.** Set windows, baseline, filter, signal mode and AUC in **Analysis settings**; click **Run group analysis**. Defaults: ratio, 5 Hz low-pass, [-5,+5] s window, [-3,0) s baseline, 20 Hz output, [0,5] s AUC. Confirm synchronization before analysis. Viewer display choices do not change analysis settings.
6. **Read and preserve results.** Each run creates a timestamped results folder with group traces/heatmaps, animal means/AUC, trial QC, full trials, and provenance. Trials average within animal before group mean/SEM; heatmap rows are animals, strongest signed AUC first. A single animal has undefined SEM. Raw sources are unchanged.

| Shortcut | Action |
| --- | --- |
| Space | Play / pause |
| Left / Right | Back / forward 1 s |
| Ctrl+Left / Ctrl+Right | Back / forward 5 s |
| Up / Down | Faster / slower preset |
| 1-9 (also numeric keypad) | Select predefined behavior |
| T | Tag selected behavior onset |

**Speed:** 0.25, 0.5, 1, 1.25, 1.5, 2, 2.5, 3x; default 1x. + / - / = have no speed function. Editing controls or Tab navigation disables review shortcuts; click video/trace to re-enable. Event times always use original signal seconds.

**Save before changing definitions or updating code:** Save events, close the viewer, save project configuration, and reopen the viewer. Restart the project manager after code updates. Old annotation names are preserved when definitions change. Keep projects, recordings and results outside the code repository. See README for CSV/video naming, timestamp handling, QC and limitations.
