# V1.2 validation

Environment: Windows, MATLAB R2024a Update 8. Release keeps project schema version 1.

Run from the repository root:

```matlab
addpath('tests');
test_import_selection;
run_tests;
test_review_delete_save;
```

`test_import_selection` generates synthetic nested batch/sensor/animal/timestamp recordings and verifies:

- Ancestor animal IDs and separate Encoding/Retrieval labels.
- Legacy timestamp/mouse-label repairs, custom-label preservation, and manifest precedence.
- Four animals in one group produce one group result per ROI/condition. Combining conditions retains four animals with eight trials, averaging within each animal first.
- Check/uncheck all, check/uncheck group, and only-group selection work on reordered tables without changing other fields.
- Saving repaired metadata creates a configuration backup and preserves event files.
- Analysis-window grouping controls and plots work with the saved configuration.

The existing suites cover equal animal weighting, SEM, event QC, missing data, four viewer display modes, playback/timer cleanup, and event delete/save shortcuts. A separate local check used real NPR data to verify repaired labels, separate/combined groups, and unchanged original projects/events. Private recordings, projects, results and screenshots are not distributed.

Plain NPR phase names are normalized; treatment-qualified labels (for example post-HFD NPR) remain distinct. The explicit combine option pools conditions selected by the user; it is not an inference that experimental conditions are interchangeable. Tests establish software behavior, not biological validity or absolute synchronization.
