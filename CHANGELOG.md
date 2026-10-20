# Changelog

## V1.2 — 2026-10-20

- Import nested batch/sensor/animal/timestamp recordings using ancestor animal IDs instead of timestamp folders. Infer ordinary NPR Encoding/Retrieval condition labels while retaining treatment qualifiers.
- Repair recognizable legacy timestamp IDs and mouse-folder labels in memory when opening projects; preserve custom labels and back up the original configuration when repairs are saved in the manager.
- Add Check all, Uncheck all, Check group, Uncheck group, and Only this group controls. These change Include only and support sorted tables.
- Add explicit separate/combine condition grouping for checked sessions. Animal-level results average within each mouse before group means/SEM; combining sessions does not increase animal count. Original labels remain in the analysis snapshot.
- Add synthetic nested-import, grouping, GUI selection and annotation-preservation regression tests.

Application version: 1.2.0. Project schema stays at version 1; existing projects remain compatible.


## V1.1 — 2026-10-19

- Add **D** to delete selected events and **S** to save events for the current session. Holding either key does not repeat the action. Buttons and shortcut help show the new keys.
- Keep native typing in editable controls and Tab navigation. Clicking the read-only **Event** column also enables direct D/S actions; click video/trace to use the full review keyboard.
- Include the locally reviewed analysis window: per-run parameters, animal/trial plot units, square figures per ROI and condition, optional gray individual traces, shared/manual curve Y limits, and detailed or endpoint-only heatmap row labels.
- Include session Group display/sorting, viewer blind group review, chronological Event numbering matched to heatmap identities, and the compact event sidebar with one-decimal display and full saved time precision.
- Rename the existing repository to **Fiber-Photometry-Behavior-Analyzer**. V1.0 commit/tag/release and the pinned seven-file SongLabDLC archive are retained.

Saved projects keep schema version 1. Application release version 1.1.0 is recorded in `VERSION`; project schema version is not the application version.

## V1.0 — 2026-10-16

Initial public release: multi-ROI video annotation, numbered behavior types, shared video clock, four viewer signal modes, keyboard transport/speed controls, animal-level analysis, one-page instructions, and the fixed upstream archive.
