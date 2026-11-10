# Video Poker rendered timing follow-up, 10 November 2026

BTH-PERF-20261104-002 and the whole-game performance parent remain **Open**. This diagnostic run made no product changes or publication.

## Accepted scope

The preserved timing-instrumented rendered FoundationMain export passes the unchanged **50 ms strategy-slice gate** on three cold pointer Deals: **3.010, 3.020 and 3.045 ms**. The production Video Poker source is byte-identical to NEXT e410e05c (SHA-256 `ac367c3b96ffb068fca63183163b082a0586ef88bdd5b65fc6fb6a01f83bc3c9`). This is an actual rendered host/game test with a synthetic pre-Deal run/cabinet fixture, not an unchanged deployed-PCK test.

First Hold painted in **67.185 ms**, with **zero advice completions before that paint**. Pointer Hold while advice was pending changed holds to [0]; all three advice jobs completed and all three pointer Draws settled. The Chromium trace and four screenshots are retained in `E:\CodexQA\BTH\runs\vp-hint-rendered-logical-trace12-20261110\evidence`. The 12% aggregate CPU Job exited 0, did not time out and drained to zero owned processes.

## Limits and comparison

- The same fixed harness/export at the old **5% aggregate CPU cap** stopped at its **100-second guard** after scene-added, before the fixture became ready. Its timing gate was not executed. Cleanup drained to zero. This demonstrates a material startup difference in this pair, not the cause of the old minimal-harness outliers.
- Historical **188-344 ms** minimal-harness outliers remain **unattributed**. Their evidence is preserved; the threshold was not raised and no sample was discarded.
- Other browser/full-host work still produced **52-222 ms** long tasks. The passing gate concerns advice slices, not every frame, input-to-paint latency or whole-game performance.
- Exact NEXT e410 identity, served PCK/native custody and menu startup were verified by the retained earlier receipt. **Exact deployed gameplay/performance remains unexecuted here.** The engine explicitly rejects command-line scene overrides, so that test-only route was stopped without changing its configuration.

## Harness and evidence custody

Earlier manifest, installed-Chrome launch and pointer-letterbox setup failures are retained and classified in the [JSON record](video_poker_hint_timing_followup_20261110.json). They are not gameplay failures or passes. The final runner uses the already successful pinned Chromium/Playwright pair and the project's logical 1280x720 viewport, records pointer geometry and uses ordinary pointer input after setup.

The [archived final diagnostic](video_poker_hint_timing_followup_20261110.cjs) is the exact final runner used for the accepted 12% run and failed 5% comparison. Every run used guarded synthetic E-drive profile/temp/evidence storage, assignment before execution, aggregate CPU/memory caps and kill-on-close Jobs. All eight Jobs have owned-zero cleanup receipts. No original save or personal browser profile was touched.

No broader or repeated experiments are scheduled. The remaining work is exact deployed ordinary gameplay/performance qualification and targeted attribution of the retained historical outliers, preserving the whole-game objective.

## Metadata validation

The manual ledger reconciliation ran with the current owner snapshot and the eight-Job scoped runtime inventory. It checked 161 objectives and nine batches, returned exit 1 with **48 retained findings**, and reported **no finding for BTH-PERF-20261104-002**. Findings concern unchanged other task/owner gaps and incomplete runtime coverage; the scoped inventory is deliberately not a full host census. The matching JSON records the exact command, report hash and counts. This is not a clean whole-ledger pass.

The archived runner passes `node --check`; all metadata-validation Jobs drained to zero. `git diff --check` passes. No new product tests were required for this evidence-only commit.

## Integration checkpoint

The final integration retains the exact e410 delivery receipt and resolves the shared ledger/index entries without closing pending acceptance. Pending performance work remains owned by project task `BTH-PERF-VIDEO-HINT-20261110`; the diagnostic worker has ended.

After conflict resolution, all 180 tooling unit tests and the archived runner syntax check pass; successful guarded Jobs drain to zero. The current-scope reconciliation with local Git verification reports 53 retained findings, including five historical commits absent from the local object database, and no finding for this Video Poker item. The all-scope report retains 669 findings. These are metadata checks, not a full-game qualification. Reports and failed initial executable-path resolution are preserved under the `vp-doc-integration-*` E-drive run IDs.
