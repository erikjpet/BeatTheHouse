# Hidden spatial V3 stop and V4 source handoff — 2026-11-16

Task: `BTH-ENV-SPATIAL-HIDDEN-001`. Sidebar owner:
`/root/high_limit_source_trial`; parent owns review, commits and runtime grants.

## Observed V3 outcome

Source commit `4010535f41e157820d3c06b44cb3d956a1b5946a`, tree
`1870e5be6208e7a0befbc831deb52319792ebc05`; run prefix
`BTH-ENV-SPATIAL-HIDNATIVE-20261116-v3`; isolated QA workspace
`E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HIDDENTRIAL2-20261116`.
The original `.../BTH-ENV-SPATIAL-HIDDENTRIAL-20261116` baseline, candidate,
source auxiliary files and prior failed V2 QA copy remain retained read-only.

V3 reached 18 qualified closed PASS phases: all 13 core phases, followed by
current-rm, full-composite, full-composite-rm, source-paint and glint-focus.
Phase 19, glint-source-paint, stopped in the adapter after the original engine
worker completed successfully. No later phase was launched. Counter-replay,
floor-wrap, long-wrap, thin-wrap, the three work batches, effective-hits,
placement and acceptance-summary are ten NOT_RUN phases in this cohort.

The frozen V3 runner's `REPORT_NAMES` entry requested
`hidden_source_paint.json`. The actual byte-pinned original observer
`envart_hidden_glint_source_paint_r2.gd`, SHA
`d272f6711e50dd1e18ea5585d9ee138752750bc57d870aefba6eb456c0596571`,
writes `hidden_glint_source_paint.json` at its line 73. The wrapper exited 1
because its requested file did not exist. Its exact diagnostic was
`[Errno 2] No such file or directory` for that expected report under the phase's
evidence directory. The existing actual report was never renamed, copied to an
alias, relabelled, overwritten or retrospectively turned into a phase PASS.

Evidence root:
`E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-HIDNATIVE-20261116-v3-glint-source-paint/evidence/`.

| Retained evidence | SHA-256 |
| --- | --- |
| `job.json` | `8083f68cb92a07e191ed83d6e6a7277f5a0048199dbe979250f699eebefcef89` |
| `worker.log` | `0ced1c869f973b7e5a8cf7fb5707fc46fed15cbb03cc0bfacf154f476efc768f` |
| `hidden_glint_source_paint.json` | `cf91728fa15ac0e693324754a9ac206d65947146fede36a502a9f92997a8ff3d` |
| `storage-manifest.json` | `9cbc05949b6d7ed4d5375cf74afbf1a53c3d6faf3bb18fc029982fe4aacf623d` |
| `launch-claim.json` | `a23b35cf7be28b87e116c2b7c187335eba8f4c7dd5797245e33c44b2e496db27` |
| `trial-inputs.json` | `46b82cadfcf06b245d4209b19107f965d7085bff30406b05d5d97d2cbffebd1c` |

Original engine Job PID 38420 has exit_code 0, active_at_release 0,
assigned_before_execution true, timed_out false, error null and no cleanup
errors. CPU rate is 1200 (12%), memory cap 2147483648 bytes, kill-on-close true,
breakaway false. The log records `HIDDEN_PAINT_MASK_RESULT` with four contexts
and no findings. The actual report contains geometry_equal true for all four
contexts and 12/20/20/19 objects: 71 typed body/adornment pairs referencing 142
PNG files. These facts do not qualify the stopped adapter phase.

`phase-result.json` is absent from this phase's evidence directory. That absence
is preserved. No following phase receipt, final native/art approval, branch art
activation, TEST delivery, browser acceptance or old-profile migration follows
from this cohort. All raw evidence and source clocks are retained.

## Valid bounded capture

The earlier core capture is a qualified standalone preview source under the
same V3 source identity. Its report is
`E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-HIDNATIVE-20261116-v3-capture/evidence/capture/animation_capture.json`,
SHA `8c4e8d769ac038b7c67612ad32e17828b168749d62a1b700a95d41a69243e0f2`.
Closed Job PID 34072 has SHA
`f67594f7574d8f1f7b54ec9f984f55748dac1972ce7210928cfcfa4867d0fdbc`.
It contains 152 actual frames, clocks 12.2439980000003 through
32.3817246666669, spanning 20.1377266666667 seconds. All ten string-light cores
observed every frame index 0..31. Full-app frames are 1280×720 actual production
UI; board900 frames are diagnostic clones; board2x frames are actual native
1800×860 art-renderer output without live objects. Parent's separately reviewed
bounded APNG workflow can consume this immutable V3 capture with that scope.
It does not establish all-29 acceptance or a full longest floor cycle.

## V4 code-only correction

V3 authorities remain unchanged:

- profile `6f9a986268bd2dc9e453258de64dab6905347b7ef92189455cba3d63467d8d81`;
- runner `744c7760283029c943f6cd313f5e24a32e3d8c6f2046faf1c683881ef6125674`;
- tests `21ac824d81a214cd6bf92c3468f99193eb722e5a4cc417aec290b2b6352897b2`.

New V4 source files:

| File under `tools/` | SHA-256 |
| --- | --- |
| `hidden_spatial_native_profile_v4.py` | `5363ea2df478aec1bb59481964d923d4b325ab82b77f37e78be37b0c4671ac57` |
| `hidden_spatial_native_trial_v4.py` | `39d04ea4f79edef9bd6c4257c150a0f3a5f56db8fc1fd4df8221ac0d67d2db29` |
| `test_hidden_spatial_native_trial_v4.py` | `8eff7ed618fafd6a5566822a9c504cf7d63278b45c220e50eca54e4e16544803` |

The functional adapter correction is the single glint-source-paint report
filename. The new exact QA workspace is
`E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HIDDENTRIAL3-20261116`, with fresh
future prefix `BTH-ENV-SPATIAL-HIDNATIVE-20261116-v4`. The retained input workspace
stays the original HIDDENTRIAL root, with baseline 4c43..., candidate 508b...,
assembly proof ad79..., static review 09af... and exact sentinel de859... .
No V3 receipt/profile is imported into the new campaign and no old QA tree is
migrated. Source commit/tree for V4 must be supplied by root after qualification.

All original 19 GDScript observers, cases, assertions, counts, motion/geometry,
literal source transports and report contracts are unchanged. The 35 prior
focused tests are preserved except version imports/history and the explicit new
QA-workspace expectation. Five new tests authenticate all 18 report mappings
against actual byte-pinned original `FileAccess.WRITE` literals (including the
capture subdirectory), reject wrong/missing/extra report aliases, inspect the
actual cf917... report's 71-pair/142-PNG schema and preserve the V3 stop facts.

Author validation is AST/syntax compilation and source-diff inspection only.
Forty focused tests are supplied, not executed by the author. Independent review,
root's fresh guarded test run, scoped commit and a new explicit runtime grant
remain required. V4 has no runtime or E-write execution in this handoff. Private
owns the engine slot until parent schedules the new Hidden campaign.
