# BTH061-FIRST-LESSON-CHOICE-001 native qualification

Base remote main: `89403f389a5807e050a450cd27b1bd93b3a4a41e`. This isolated intake contains the first-run Lesson choice only. The task stays Open; there is no main push or NEXT acceptance.

Godot 4.6 stable ran under the maintained E: storage guard and capped Job (12% aggregate CPU, 2 GiB memory, 90 seconds per job). All jobs ended with zero owned processes. Fresh disposable QA roots were used; no owner profile or protected save was read or changed.

| Run ID | Actual result |
| --- | --- |
| `lesson-choice-branch-lesson-20261119-03` | Start Lesson / Back / no reward / Replay cancel: 18/18. |
| `lesson-choice-branch-skip-20261119-01` | Skip / ordinary run / same-process new host Continue / Replay cancel: 22/22. |
| `lesson-choice-replacement-20261119-01` | Saved-run replacement and input focus: 85/85. |
| `lesson-choice-resume-20261119-01` | Existing tutorial Resume: 19/19. |
| `lesson-choice-corner-20261119-01` | Authored Corner Shop path: pass. |
| `lesson-choice-map-20261119-01` | Authored tutorial map layout: pass. |
| `lesson-choice-full-process-cold-20261119-03` | Two sequential Godot processes in one guarded disposable root: Skip and Save 5/5; fresh-process Continue 7/7. Exact typed seed, cash, time, room and inventory match. |

Preserved attempts: branch `-01` test parse error from an inferred seed type; branch `-02` timed out before project import because class registration was absent. A normal guarded import then passed. Full-process cold `-01` and `-02` exposed test JSON parsing of integer `100`/`720` as floats; the test now restores these two expected fields to integer type before the unchanged exact comparison. The product values and other facts matched. `lesson-choice-distribution-20261119-01` failed before gameplay because the old distribution fixture expects `user://` paths while the required guarded QA environment sets direct isolated persistence paths; this fixture is not a pass and no product conclusion is drawn from it.

Actual browser mouse and touch activation of the three choices remains unqualified. Native keyboard focus traversal and default Enter/Back were covered by the saved-run regression; first-choice branch signals and its input callback were exercised, but a rendered browser input pass is still needed. The user-operated ledger reconciliation was not run. Before promotion, reconcile this scoped patch with any later CRT/Main change, run the remaining input check, and verify exact NEXT after a tested commit.

Local native receipts: `E:\CodexQA\BTH\runs\lesson-choice-*\evidence\job.json` and `worker.log`. Source hash handoff: `E:\CodexQA\BTH\workspaces\lesson-first-choice-89403-20261119\review_artifacts\BTH061-first-lesson-choice-native-handoff-20261119.json`.

## Combined CRT integration

Rebased tutorial commit onto served CRT `b9e935c0f16fba81ed14c6a8d5666d5c60ff7056` in an isolated checkout. Guarded Godot 4.6 native jobs passed Start Lesson/Back 18/18, Skip/ordinary run 22/22, saved-run replacement 85/85, tutorial Resume 19/19, and two-process cold Save/Continue 12/12: **156/156**. The adjacent CRT production-host regression passed **634/634**. All bounded jobs released zero owned processes. The first cold command failed before child launch because a bare Python name was unavailable inside the guard; its exact pinned-interpreter retry passed. These results are source/native qualification, not a deployed Web claim.
