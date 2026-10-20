# Fiber Photometry Behavior Analyzer V1.2

One-page quick start - MATLAB R2024a, Windows. Default filtering needs Signal Processing Toolbox.

1. **Launch and configure.** Run `launch_analyzer` from the repository root. Create or open a project stored outside the code folder. Enter groups, animal IDs, behaviors and source ROI IDs/display names. In Sessions, check AnimalID, Group, Label and Include; nested imports detect ancestor animal IDs. Review automatic repairs, then Save configuration. Use Check all/Uncheck all or Check group/Uncheck group/Only this group.
2. **Define behaviors.** In Behavior types, name keys **1-9**; blank slots are disabled and names must be unique. Save configuration. Old event names are preserved when definitions change. Sessions column headers support sorting.
3. **Synchronize.** Open **View video + ROIs**. Choose ratio, 470, 410 or 470+410. Green 470 uses the left Y-axis; blue 410 uses the right, independently scaled; ratio is gray. Calibrate offset, then check **Sync checked**: `video time = signal time - offset`. Zero does not prove sync; drift is not corrected. Blind review hides group info in the viewer by default.
4. **Tag, review and save.** Click video/trace to enable shortcuts. Select a behavior by number, then **T** for onset. The right table has Event/Behavior/Time. Click a row to pause and jump all ROIs/video; double-click Behavior/Time to edit. **D** deletes selected events; **S** saves this session. Read-only Event cells accept direct D/S. Time shows one decimal but saves full precision. E2 means chronological session event 2; save and replot after edits.
5. **Plot.** Run group analysis opens its own parameter window. Set windows, baseline, filtering, signal mode, AUC and animal/trial plot unit; click **Plot**. Choose separate conditions (default) or explicitly combine checked conditions. Animal is the default biological unit. Trial plots pool nested events for descriptive display, not independent biological replication. Use shared automatic or manual curve Y limits, hide/show gray individual traces, and detailed or endpoint heatmap labels. Defaults save only via **Save parameters as project defaults**.
6. **Preserve results.** Each Plot creates a timestamped results folder and replaces only that window's previous figures. Square trace/heatmap figures are separate per ROI/condition, with behavior panels. Outputs retain animal summaries, full trials, identities, QC and provenance. Historical results and raw sources remain unchanged. Confirm sync and save events before analysis.

| Shortcut | Action |
| --- | --- |
| Space | Play / pause |
| Left / Right | Back / forward 1 s |
| Ctrl+Left / Ctrl+Right | Back / forward 5 s |
| Up / Down | Faster / slower preset |
| 1-9 (also numeric keypad) | Select named behavior |
| T | Tag selected behavior onset |
| D | Delete selected events |
| S | Save current-session events |

**Keyboard and speed:** T/D/S suppress key repeat. Editable controls and Tab navigation keep native typing; click video/trace to resume shortcuts. Speeds: 0.25, 0.5, 1, 1.25, 1.5, 2, 2.5, 3x; default 1x. + / - / = do not change speed. Event times stay in original recording seconds.

**Before updating code:** Save events and close viewers, then reopen the manager/project. Keep projects/data outside the repository. Source paths and metadata detailed_csv links must remain valid after moving data. See README for format, normalization, QC and limits; CHANGELOG for V1.2 changes. V1.0 and the pinned SongLabDLC archive remain available.