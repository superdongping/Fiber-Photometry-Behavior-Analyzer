# Fiber Photometry Behavior Analyzer V1.1

Current application release: **1.1.0**. See [CHANGELOG.md](CHANGELOG.md). The repository now uses a stable name; the V1.0 tag/release and upstream archive remain available.

A MATLAB desktop workflow for synchronized behavioral video review, multi-ROI fiber photometry annotation, and animal-level group traces and heatmaps.

**Start here:** [one-page instructions](docs/INSTRUCTIONS.md) | [printable one-page PDF](docs/INSTRUCTIONS.pdf)

## Requirements and launch

- Developed and tested on Windows with **MATLAB R2024a**.
- **Signal Processing Toolbox** is required for the default Butterworth low-pass filter and optional peak detection. There is no silent replacement if the toolbox is missing. Use a low-pass cutoff of 0 for unfiltered group analysis and disable Low-pass in the viewer if needed.
- A video format readable by MATLAB `VideoReader`; AVI was used during validation.

Download or clone this repository, open its root folder in MATLAB, then run:

```matlab
launch_analyzer
```

`launch_review` remains a compatible entry point. Add only the repository root to the MATLAB path; **do not use `addpath(genpath(...))`**, which also adds historical code and test artifacts.

## Workflow

1. **New project:** enter a project name, behavioral task, behavior labels, groups, animal counts/IDs, and source ROI IDs plus display names. Choose the recording directory and a separate project parent directory.
2. Review **Sessions**, **Animal groups**, and **ROI names**. Sessions shows the Group matched by AnimalID; click column headers to sort. Conditions are session labels, not animal groups. Encoding/Retrieval labels are analyzed separately. Check IDs, paths, labels and Include flags; include only the intended records.
3. In **Behavior types**, assign unique names to keys **1-9**; blank slots are disabled. Click **Save configuration** before opening the viewer. Existing projects inherit their previous label order. Changing definitions preserves existing annotation names rather than reclassifying old events.
4. Open **View video + ROIs**. Select ratio, 470, 410, or 470+410. In dual-channel mode, 470 is green on the left Y-axis and 410 blue on the right; each axis scales independently. Ratio is gray. All ROIs share one video clock.
5. Calibrate **Video offset**, then check **Sync checked**. Use **1-9** to select a behavior and **T** to tag it. Events are shared across ROIs. The right-hand Event/Behavior/Time table pauses and jumps on row selection; double-click Behavior/Time to edit. **D** deletes selected events; **S** saves this session. Read-only Event cells also accept direct D/S. The viewer defaults to **Blind review (hide group)**; uncheck it to display group information.
6. **Run group analysis** or **Analysis settings** opens a separate parameter window. Set windows, baseline, filtering, signal mode, AUC and animal/trial plot unit, then click **Plot**. Plot uses the current parameters and closes only figures from that window's previous run. Historical result folders remain. **Save parameters as project defaults** is a separate explicit action.

Save events and close an existing viewer before changing behavior definitions or replacing application code. Reopen the project manager after updating code.

## Keyboard controls

Click the video or a trace to enable review shortcuts. Controls retain their normal keyboard behavior during editing or Tab navigation.

| Key | Action |
| --- | --- |
| Space | Play / pause |
| Left / Right | Back / forward 1 second |
| Ctrl+Left / Ctrl+Right | Back / forward 5 seconds |
| Up / Down | Faster / slower by one preset |
| 1-9, including numeric keypad | Select the corresponding named behavior |
| T | Tag selected behavior onset at the displayed frame; key repeat is suppressed |
| D | Delete selected events; no selection is a no-op; key repeat is suppressed |
| S | Save current-session events without changing playback state; key repeat is suppressed |

Select cells in the read-only **Event** column for direct D/S access. When selecting/editing Behavior or Time, click the video/trace to re-enable review shortcuts. Ctrl/Alt-modified D/S are not intercepted. Deletion remains unsaved until S or Save events; chronological Event numbers are recalculated after edits.

Speed presets: **0.25, 0.5, 1, 1.25, 1.5, 2, 2.5, 3x**; a new viewer starts at **1x**. `+`, `-`, and `=` do not control speed. Playback rate never rescales saved event times.

## Input files and saved projects

The application reads exported CSV and video files; it does **not** decode proprietary Inper databases. The original conversion utility is not part of this release.

Recording discovery supports an existing `_conversion/records.json` manifest, or recursively finds `*(Camera).csv` and a matching AVI without `(Camera)` in its filename. Without a manifest, use this structure:

```text
recordings/
  Encoding/
    01 #Mouse01/
      recording(Camera).csv
      recording.avi
```

The animal folder supplies the ID (a `#ID` token when present); its parent supplies the condition label. A normal CSV contains `Time`, `ROI-1_sig_410`, `ROI-1_sig_470`, and corresponding pairs for additional ROIs. `Time` accepts the exported TimeSpan format, such as `0:00:00:01.0500000`. Columns are matched by full source ROI ID; missing ROIs produce an error.

If a neighboring `<stem>_metadata.json` has a valid `detailed_csv` path, the reader prefers that detailed CSV and uses its independent `Time_410_s` and `Time_470_s` columns, preserving all available samples. A shared-Time CSV cannot recover independent wavelength exposure times. Input paths in manifests and sidecars must still resolve on the current computer.

For extra category/recording directory levels (for example batch/sensor/animal/recording), review and correct AnimalID, Group, Label and Include before opening the viewer. Discovery does not infer biological grouping and can mistake recording-folder timestamps for IDs. Use consistent condition labels such as Encoding/Retrieval; the analysis keeps conditions separate. Do not infer that every nonempty recording is a valid behavioral session.

Projects save `project.mat`, readable `project.json`, animal/session CSVs, per-session event CSVs in `events/`, and analyses in `results/`. Events use original signal seconds. Sources remain read-only. Store projects and recordings outside this repository. Session source paths are absolute and may need updating after moving data.

## Synchronization and scientific conventions

- `videoTime = signalTime - VideoOffset_s`. Zero is an initial value, not proof of synchronization. Confirm the offset against observable events before group analysis; confirmation is required by default. Only a constant offset is modeled; clock drift and interrupted recordings need separate handling.
- The signal origin is the first valid exposure across both wavelengths. Ratio defaults to legacy sample-index pairing. Optional `interpolate470` aligns 470 to 410 timestamps; neither method extrapolates across missing edges or large gaps.
- Default group analysis: 470/410 ratio, fourth-order Butterworth zero-phase 5 Hz low-pass, event window [-5,+5] seconds, baseline [-3,0) seconds, 20 Hz output grid, and signed baseline-subtracted AUC over [0,5] seconds. Settings are editable. Group event normalization uses `100*(F-F0)/F0`; raw-channel modes and alternative normalization must be interpreted in their selected units.
- Viewer display switches do not silently change saved group-analysis settings. Missing values and large gaps are retained, with exclusion reasons in QC.
- Trials are averaged **within each animal** before equal-weight animal means and SEM. Sessions of the same animal and condition are combined within that animal. A single animal has undefined SEM (`NaN`). Optional trial plots pool accepted events for display and descriptive SEM; trials from one animal are nested and are not independent biological replicates. Animal-level CSV outputs are retained. The program does not perform automatic hypothesis tests.
- Heatmaps contain one row per selected animal/trial unit, sorted by signed baseline-subtracted AUC (descending by default). Detailed labels retain animal/session/E-event identity; endpoints mode shows only 1 and the accepted row count. E2 means chronological event 2 across all behaviors in that session, independent of heatmap AUC row number; QC does not compress event numbers. Save events and Plot again after editing tags. Display clipping does not truncate data.
- Each ROI and condition gets a square trace figure and a square heatmap figure, faceted by behavior. Curve Y limits are shared across the current Plot call; enter both Curve Y min/max to override them. Gray individual traces can be hidden without changing mean/SEM or accepted trials.

## Outputs

Each timestamped analysis includes PNG/FIG group traces and heatmaps; `group_mean_SEM.csv`; `animal_mean_traces.csv`; `animal_summary_AUC.csv`; sorted `*_heatmap_rows.csv`; `trial_QC.csv`; all accepted trials in `analysis_results.mat`; and project/input provenance snapshots. Trial display exports include unit identity and N_animals/N_trials; plot_display_settings.json records display settings and the applied shared curve limits. These results are generated locally and excluded from Git by default.

## Validation

Run the self-contained synthetic regression suite from the repository root:

```matlab
addpath('tests');
run_tests
test_review_delete_save
```

The suite generates its own CSVs/videos under ignored `tests/artifacts/`, and checks animal weighting with unequal trial counts, SEM, missing-data/edge QC, ROI mapping, four display modes, saved events, and timer cleanup. It needs MATLAB graphics/video support; filter checks require Signal Processing Toolbox. Development also exercised number/T shortcuts, all speed presets, dual axes and row-click navigation with real recordings locally. Real recordings and those private test projects are not distributed. Tests do not establish biological validity or absolute synchronization.

## Version history and provenance

V1.1 continues V1.0 and extends the synchronization and event-analysis workflow in [SongLabDLC / Fiber photometry V4_3](https://github.com/superdongping/SongLabDLC/tree/main/Fiber%20photometry%20V4_3), particularly `fiber_photometry_video_sync_v4_6.m` and `fiber_photometry_behavior_analysis_combined_sorted_V1_3.m`.

The complete seven-file upstream directory is preserved byte for byte in [archive/SongLabDLC_Fiber_photometry_V4_3](archive/SongLabDLC_Fiber_photometry_V4_3), pinned to commit `ae3acb63b449573e144cf834eba5a9c959695c6a`. [Archive documentation](archive/README.md) explains provenance; [source_manifest.json](archive/source_manifest.json) records Git blob hashes and SHA-256 values. This is a historical snapshot, not an import of the old repository's full Git history. The original SongLabDLC directory is retained.

No license is assigned by this release; no additional licensing terms are inferred for the archived files.
