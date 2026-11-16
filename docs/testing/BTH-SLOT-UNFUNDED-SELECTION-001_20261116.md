# Slot MIN after an unfunded Spin

Tracking ID: BTH-SLOT-UNFUNDED-SELECTION-001. Visible sidebar owner 6afa5080-2f00-8191-804a-d401aa98a020. Recorded 2026-11-16T04:14:23.420250+00:00.

## Result and scope

Fixed and tested in the isolated current-main candidate qualified on68f5592955412316dbfd41b829eb816c14494aad, then integrated onto77efc4281d380e2241c33c9d55d4505bc01e4873. The intervening commit changes only Crew documentation; the qualified runtime bytes are unchanged. The scoped fix is now on main and verified as the exact served NEXT build. Browser startup and rendered Web behavior remain unverified. The broader continuous general-QA and ending request remains Open separately.

The retained normal SIDEBAR-GAMES-20261116-H campaign reached the beach through actual routes, the restored receipt Continue button and two offered10-cost deck walks. Its actual canvas MAX20/Spin naturally lost20, leaving8. After cold Continue and normal reveal, an actual20 Spin was refused without cash/RNG change, but the displayed enabled MIN2 then stayed20. Modal was empty and the deferred gate false. Canvas action/index was slot_bet/0. A labeled detached diagnostic returned pending_delivery: That action is still being delivered. Please wait.

Original producer sidebar-beach-slot-max-H-20261116-01 and every failed diagnostic remain untouched under E:/CodexQA/BTH/runs. The failure was reproduced again on actual main68f5592 in sidebar-slot-min-main-baseline-20261116-01:16 checks, one decisive MIN assertion failure, exit1, clean engine log, owned0. Source3cecec33 discovery and current-main reproduction are separate evidence classes.

## Root cause and correction

Player dispatch asked the sealed host to stage a Spin delivery before ordinary stake validation rejected its cost. That valid but unfunded delivery then prevented subsequent bet intents. Repeated waiting or a correct MIN hit could not clear it.

Slot now declares its two manual Spin action aliases for a player-input funding preflight. Foundation queries the module's real wager cost and the existing pure canonical funding preview before it asks the sealed host to create a delivery. An unfunded player request displays the ordinary bankroll message and returns with no pending delivery. The existing authoritative funding/receipt checks still run on accepted resolution.

The correction preserves private uncommitted staging, which the existing legacy producer deliberately uses, and its recovery/replay/tamper checks. It does not cancel arbitrary pending deliveries or weaken seals. Canonical funding preview retains cash/chip exchange rules; module cost retains zero-cost/free-spin semantics. Free control/Auto behavior is exercised by the legacy cases; naturally generated active bonus play was not sampled by this fix batch.

Scoped files: Slot's declaration, Foundation's player-action adapter and five added regression lines in the existing legacy check. Every prior test assertion remains. No canvas scheduling, autonomous redraw, economy, RNG, authored scenario/item, user save/profile, browser, shared runtime or unrelated work changed.

## Focused verification

Four qualified runs total215 checks:19 faithful ordinary H player-path checks,16 later exact cold checks,136 synthetic legacy warm/rejection checks and44 synthetic legacy cold checks. The original unchanged legacy suite also passed134 before its narrow new assertion; that overlapping run is retained and is not added to215.

The fixed actual canvas path rejects20 at cash8 with clock934/turn1 and RNG493541604 unchanged, selects MIN2, then accepts exactly one normal2 Spin. It naturally loses2, leaving6 and RNG896547101, spin count2. Later cold Continue retains6, selected2, exactly two paid rounds and last stake2. Another real MAX/refused Spin/MIN cycle remains usable, preserves wallet/RNG/action turns and leaves a valid empty pending ledger.

Legacy warm covers preserved old pending intents, paused exact-all-in shape, nonempty prior settlement, canceled replay and six altered/out-of-scope authority controls. Cold copies retain the authentic synthetic warm fixtures and all four private companion directories, source hashes unchanged. All new native Jobs close0 owned processes.

| Run | Class | Checks / failures | Exit | Owned | Log SHA256 |
| --- | --- | --- | --- | --- | --- |
| sidebar-slot-min-baseline-prep-20261116-01 | import/setup | - | 0 | 0 | 798b85bf41c3ad00080d89b23205ed74638afa4125852ce899e553490f4f0783 |
| sidebar-slot-min-main-baseline-20261116-01 | original failure | 16 / 1 | 1 | 0 | f668875e0281858fb47bfbb11bc05da98efd81f8a43d74a6a002d28a35d81aa3 |
| sidebar-slot-min-fixed-20261116-01 | qualified | 19 / 0 | 0 | 0 | 97dd760514ae20e9159897202da66bb0a20a0b058707f37db4b502b9dca9a92d |
| native-private-bth32-slot-min-warm-20261116-01 | original failure | 8 / 1 | 1 | 0 | 60982b16370e3042b9521a74ec6d0bfe247c8f6874ebb7f795ee90437bf85982 |
| native-private-bth32-slot-min-warm-20261116-02 | retained overlapping evidence | 134 / 0 | 0 | 0 | 758f11c79ee2df0fb8491ee55a1a6e97f648d4d92317db3e954b588e9ce91082 |
| native-private-bth32-slot-min-warm-20261116-03 | qualified | 136 / 0 | 0 | 0 | e7e6f9945495d66b1c68ce8409cb0c3b7dc6869fa7b822dfdf24886da5227e5f |
| sidebar-slot-min-fixed-cold-20261116-01 | qualified | 16 / 0 | 0 | 0 | 97fd10783171ba80b1d44578d4cb4806503a526c176365e7cc69c6d45c61be96 |
| native-private-bth32-slot-min-cold-20261116-01 | qualified | 44 / 0 | 0 | 0 | d682c70e3d03473e47d98950013a62199c66356f7a65546a4bb3c4844aa55c24 |

Code SHA256 at qualification:
- scripts/games/slot.gd: 8b33b3f2d13381e9a734a6f2e05bd8cf066c13f26a67f08d5dc8cbd6afcb6d3b
- scripts/ui/foundation_main.gd: 35e8b89271fc5b835a744484f4b809162a853ea5e76a2a53af245aebd19cfa4c
- scripts/tests/slot_autoplay_legacy_pending_recovery_check.gd: 6970ea48e9ffcc2089f91f58cf0417b9c42f580254125917fbf418162a8a23fa

Exact commands, Job limits, assignment-before-execution, storage gates/manifests and custody are beside worker.log in each evidence directory. All use admitted E: storage,4GiB writes plus20GiB reserve,12% CPU/2GiB Jobs and bounded cleanup. The retained private fixtures/keys/capsules are not Git deliverables. Fidelity is actual source-native canvas geometry and mouse event handlers; native, synthetic, HTTP and rendered/Web evidence remain distinct.

Operational diagnostics are retained: shared-metadata worktree creation stopped at root_escape before Git ran; an independent checkout then succeeded without changing the shared HEAD/index. The first legacy launch stopped before fixture creation because its required BTH_TARGET_OUTPUT was undeclared; the rerun supplied an explicit guarded E: path. A patch-position assertion stopped before source writes and was corrected by scoping the edit to the intended function. No guard, root or security setting was relaxed.

## Delivery

Main1240cebdd15ee294e8997b46d20819762d691923/tree07fa7f46fc250247b26134b19350b155e2641904 was pushed, built by the existing watcher and promoted2026-11-16T04:29:59Z. Source tests do not establish Web startup. Stable/itch/audience changes are outside this fix.

Main advanced with Crew ending evidence during the initial commit attempt. That guarded attempt stopped before staging; the next isolated attempt preserved the newer Crew ledger/report and kept the same three qualified code hashes. No shared index or checkout was changed.

Scoped runtime/test fix committed and pushed to main1240cebdd15ee294e8997b46d20819762d691923/tree07fa7f46fc250247b26134b19350b155e2641904. Remote main equality was verified. Initial main push was rejected by automatic approval review; the original action had not executed. Trusted user history then verified the general instruction to push completed work to main and the separate art-only TEST branch scope. One retry succeeded without changing the guarded action. Evidence: E:/CodexQA/BTH/runs/sidebar-slot-min-push-20261116-01/evidence/push.json. Existing watcher detected the exact commit at2026-11-16T04:24:59Z; its build is currently in progress with no reported error. No duplicate watcher or substitute build was launched.

## Verified NEXT receipt

Observed2026-11-16T04:31:04.024243+00:00. Exact main1240cebdd15ee294e8997b46d20819762d691923/tree07fa7f46fc250247b26134b19350b155e2641904, version0.6.0-dev+1240cebdd15e, was detected04:24:59Z, built04:29:51Z and promoted04:29:59Z. Watcher26256/guardian25112 remained the existing enabled10% CPU/2GiB chain; no duplicate/manual build, stable/itch/audience or trust setting changed.

Trusted HTTPS at https://192.168.0.36:8443/p/beat-the-house/play/ confirmed the NEXT pointer and dev entry, then immutable BUILD.json, build_manifest.json, REF, VERSION and HTML. The small files match staged SHA256s; manifest source/tree are clean and exact. The changed PCK returned200 and was fully streamed: 124982296 bytes, SHA2567b2594d515f5932cd3df129ed16ce9c1641e16d8ef233fe07f822e6c2a59c1af, matching the exact pipeline stage. Archive SHA256c5c8c1ccfec0feddedd4c67abae7a492c6dbc6a7f0316b9f754ad91298fdc853. Engine JS/WASM and native WASM returned200 with staged lengths/MIME; their authoritative stage/build-manifest tuple was retained rather than repeating a complete asset download sweep. Native input source is unchanged; the pipeline's fresh native output hash is recorded in the receipt.

Exact evidence E:/CodexQA/BTH/runs/sidebar-slot-min-next-served-20261116-01/evidence/next-receipt.json and job.json: exit0, owned0, TLS verified. Current native focused behavior receipts remain215 checks on identical qualified source bytes. No exact-build browser startup receipt was available; the retained site verification.json belongs to an older build. No browser was controlled here, and inherited browser-control restrictions were retained. HTTP/source/native verification does not establish Web startup or rendered play. This tracked fix remains Open for that acceptance; the broader continuous general QA remains independently Open.

Checkpoint reconciliation: both assigned IDs have zero findings after supplying the exact deployed commit field. The wider current ledger still reports117 inherited ownership/scope/runtime-evidence findings across73 other tasks; they are outside this fix and are not reported as resolved. Scoped evidence inventories68 closed native Jobs (60 general exploration including retained diagnostics,8 Slot import/reproduction/regression); other workers/watcher are outside this incomplete inventory. Evidence E:/CodexQA/BTH/runs/sidebar-slot-general-delivery-record-20261116-02/evidence/checkpoint.json. Earlier checker118 was this same117 plus the now-corrected missing field, not a new game defect.

Latest exact served descendant: main3cbeefa7210a0785e894357be17f3729fd247c7e/tree0d3bdebfc6a6f3a340743ebb93996229aa90431f, promoted2026-11-16T04:52:09Z and verified by trusted HTTPS04:52:11Z. The intermediate155975c6 documentation build completed but was superseded and was not claimed as promoted. New Crew changes affect only its report and ledger views; the qualified Slot/runtime bytes are unchanged. Exact BUILD/manifest/REF/VERSION/HTML match staged hashes; engine/native/PCK HEAD metadata matches the new stage. The original1240 full PCK stream and215 focused native checks are reused at their own identities. No redundant complete asset download or native rerun was done for documentation-only descendants. E:/CodexQA/BTH/runs/sidebar-slot-next-descendant-20261116-01/evidence/next-receipt.json. Startup/rendered Web acceptance remains unverified and the tracked fix remains Open for it.

Current shared runtime delivery: eb05632b738ab91dc21d717b80ee78ae84fbb204/tree efc2d51c5e508edf9f73f9f69ed75a4e5bfa9d87, promoted2026-11-16T06:06:23Z and exact HTTPS verified06:07:35Z. Slot qualified215-check bytes remain unchanged; this runtime build adds the separate Baccarat correction. The full changed PCK124982648 bytes/SHA2564afad55dab348ec05225d32aab08e61930cd7f4b0c49c6d9bbf27c9c7d194ae4 matches stage. Evidence E:\CodexQA\BTH\runs\sidebar-baccarat-auto-min-next-served-20261116-01\evidence\next-receipt.json. Web startup/rendered acceptance remains open.

Latest exact served documentation descendant43f2ffca0659fdad581a785b28cd8b705698b6de/tree ff22613534cf963fe6495150e618f75f124cc7f3, promoted2026-11-16T06:33:26Z, HTTPS verified06:35:39Z. Committed diff from qualified eb05632 is documentation only; metadata/small hashes and staged engine/native/PCK HEAD tuple match. Original full eb05632 changed PCK evidence is reused at its own identity. E:\CodexQA\BTH\runs\sidebar-baccarat-delivery-docs-next-20261116-01\evidence\next-receipt.json. Browser startup/rendered Web acceptance remains Open.

Current exact served documentation descendant1268ffab41c975b355cb4f3a016d008ef6af0a14/tree2444467bcd218aa169c744ff1087f964386803a6: qualified runtime source unchanged. Trusted HTTPS metadata/small hashes and staged asset HEAD tuple verified; the full eb05632 runtime PCK receipt is reused at its own identity. E:\CodexQA\BTH\runs\sidebar-marker-next-docs-20261116-01\evidence\next-receipt.json. Exact Web startup remains blocked by the retained browser-control restriction.
