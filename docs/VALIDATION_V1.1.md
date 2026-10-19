# V1.1 validation scope

The portable test suite generates synthetic recordings and annotations under ignored `tests/artifacts/`. No experimental recordings, saved projects, annotations or generated results are distributed.

`test_review_delete_save` checks D/S key mapping, modifier protection, empty/multiple selection deletion, held-key suppression, explicit save/reload at full precision, Tab/native-control protection, existing transport/speed/T behavior, saving during playback, project configuration preservation, and viewer timer cleanup. Source signal time is retained when saving; navigation is checked within one video frame. The button layout was inspected using a synthetic viewer preview.

`run_tests` checks equal animal weighting with unequal trial counts (expected G1 mean 200, SEM 100 at the synthetic response), undefined SEM for one animal, synchronization gating, recording-edge and missing-data QC, source ROI mapping, four viewer modes, video clock navigation, event persistence and timer cleanup. V1.1 expects four PNG outputs for the two-ROI/one-condition example: one trace and one heatmap per ROI.

The one-page V1.1 PDF was regenerated, confirmed to contain one page, rendered and visually inspected. The seven historical source files remain byte-identical to the pinned upstream manifest and unchanged from the V1.0 archive. The V1.0 commit/tag/release are retained.

Release preparation also compared 100 local project/annotation files before and after the work; none changed. Those private files, their identities and their paths are excluded from this repository. The standalone Inper database exporter remains a separate tool and is not bundled here.

These checks validate software behavior on the development Windows/MATLAB R2024a installation. They do not establish biological validity, video synchronization accuracy, compatibility with every MATLAB release, or statistical independence of repeated trials.
