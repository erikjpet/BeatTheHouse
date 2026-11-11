# AUD061-17 — Frozen candidate release coverage

Specification: docs/todo/BTH_0.6.1_audit_work_orders.md.
Registered before checks on main; registration and AUD061-11's post-delivery receipt were retained in Git checkpoint c854295b35a0af3781d8df282a37fbce74daf959. The approved E checkout was temporarily detached at **fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc**, tree **2d49cb17f83379715435a2576473c5cba52728ff**, for every new check below. Tracked source was clean before and after; only unrelated untracked Microsoft/ remained. Main e1f78f0c and the checkpoint were then restored without conflict. The checkpoint and original E run evidence are retained.

Disposition: **FAILED — required release qualification remains incomplete.** This order records tests and separately diagnosed follow-ups. No production code, item/scenario content, migration or runtime version check was added.

## Required gates

| Gate | Actual exact-candidate checks | Result and limit |
| --- | --- | --- |
| BTH061-005, money/items | Craps refunds63/0, working stakes16/0; Blackjack reveal133/0 in each cash/default run; Money Flow save33/0 + separate-process read12/0; clean cash-out39/0; chip liquidity62/0; Count synthetic70/0; duplicate item-purchase101/0; Numbers109/0 + cold58/0 | These 856 assertion checks include the two Count failures below. Financial math, once-only payout, refunds, duplicates and the named current-build save controls pass; not complete normal-run coverage of every item-use/cancel/travel combination. |
| BTH061-005, Count exact restore | prospective write20 checks /1 failure; separate read7 /1, “official restore preserves full ending/receipts/RNG state” | Failed reference comparison. Recorded first40 differences are layout/map/audio floats. A read-only selected-leaf probe proves actual0.14883720930232558 vs ordinary-JSON expected0.14883720930232600, delta4.16333634234434e-16. Cash855, chips41, RNG793604881, ended status and seed match. Actual archived720 payout and duplicate callback assertions pass. Evidence supports a lossy expectation/oracle discrepancy; no money-loss claim. New BTH061-RC-COUNT-EXPECTATION-001. |
| BTH061-006, all eleven games | Reuses same frozen-commit AUD061-11 producer85/0 and process-cold44/1, plus actual normal-run three-play Video Poker unfinished and settled Web reload/Continue | All eleven source load/reentry and account checks were attempted, but not all paid/pending/settled cases were reached. Scratch strict owned-state comparison still fails; complete rendered matrix is not supplied. Gate remains open. |
| BTH061-007, closing/interruption | public closing/travel generated-campaign check65/0 + separate cold18/0; terminal Continue contract PASS; Rourke phased interruption PASS in correct non-distribution source fault-test mode | Supported scoped controls pass; these are not all normal gameplay routes or every dialog/delivery/crew interruption. |
| BTH061-007, Riverboat | unchanged riverboat_closing_departure_check:19 checks /10 failures | Minimal callback fixture overrides _ready without building TalkDock. Current production callback rejects null/mismatched TalkDock before invoking checked turns. Positive unit cases therefore never enter the handler. This is a diagnosed stale fixture contract, not proof of a player docking bug; normal mounted Riverboat ride/closing acceptance is still needed. New BTH061-RC-RIVERBOAT-FIXTURE-001. |
| BTH061-007, Bar Dice interruption | Reuses frozen AUD061-11 warm72/0 and cold44/1 | Cold restored exact cup and ante; one Call reached cash108/round1. Health Inspector popup is visible, transition active, closing false when passive-tumble assertion fails. After test scene teardown the primary remains cash94/Reveal/round0. No normal response or guarded player exit was attempted. Keep interrupted-save behavior unqualified under BTH061-RC-BARDICE-COLD-001. |
| BTH061-012, version/package target | current source observer2 checks /2 failures: project stamp0.6.0, source display0.6.0; old packaging runtime contract prints PASS because it still asserts0.6.0 | Old contract success cannot qualify0.6.1. AUD061-04's unchanged pipeline pins prevent the required version/project/preset/exporter edits. No final0.6.1 Windows package was built; qualified Windows native artifact is also absent in this QA clone. New BTH061-RC-PACKAGING-001 tracks the final-package gate, linked to AUD061-04. |
| BTH061-012, source/Web artifacts | filtered exact-Git source archive and two private Web PCK exports below; actual immutable NEXT fcfe assets and startup already verified | Scoped package checks pass. These are not official release uploads and do not satisfy the blocked Windows/version/final full-gate requirements. Cross-version save compatibility is not a gate and was not attempted. |

Native model controls use fresh current-build synthetic state. Existing unmodified tests may contain old-shape primitive controls and emit migration messages from incomplete synthetic DTOs; no historical player file, old-build upgrade fixture, active profile, installation key or cross-version migration was copied or added.

## Setup corrections and retained failures

The first money worker omitted explicit output paths for some older checks, an explicit Count mode, and used an obsolete Numbers private-root convention. Those results are setup failures, not financial defects. One cash-out process reached its required output write with an empty path; its exact owned PID/command was stopped and the suite reconciled to zero processes. Its failed output remains retained. Corrected checks receive a declared E evidence output, explicit synthetic/prospective modes and a Numbers adapter that changes only storage admission to the current prepared manifest. No behavior assertion is removed.

The first Rourke attempt ran with distribution semantics while setting Store.debug_force_write_failure. AUD061-16 correctly makes that flag ineffective in distribution builds, so its failed-save expectation was invalid. The repeat explicitly uses BTH_DISTRIBUTION_BUILD=0, retains the same admitted E storage and all assertions, and passes terminal parity, shared reveal/read gate, report routing, terminal Main Menu/cold Continue, failed Save/retry, scene teardown and pending-save recovery. No shipping fault gate was weakened.

The public closing/travel adapter similarly replaces only its older sibling-directory assumption with exact current manifest paths and E containment. The original body/financial/arrival assertions are inherited unchanged. No old captured Blackjack refund or terminal-bag bundle was supplied; those original-data branches are not counted as covered.

## Two exact RC exports (AUD061-12 follow-through)

Commands, each in a fresh guarded E runtime profile:
Godot --headless --path <frozen workspace> --export-pack Web <evidence>/rc-web.pck --verbose.
Workspace import/export caches are retained; these are full warm-workspace exports, not two new cold imports. Both exit0, no timeout, active processes0, same12% CPU /2 GiB Job and unchanged storage reserve.

- A:47,240,548 bytes; SHA256 ddb2f680e0aa7652ac076ad413741f8ae9d911b042be92f59bee1efcc1a47358.
- B:47,240,548 bytes; SHA256 be493554fde336256249728bac7733a1254a56de255dab16e18c71f6722d4330.
- Each has1,165 files. tools/audit_pck_manifest.py's actual parser/allowlist passes, and all payload MD5s are independently recomputed and verified.
- Identical file sets. The only changed payload is .godot/global_script_class_cache.cfg:218 classes on both sides, identical class-to-all-fields map, zero changed classes; list order differs. The other1,164 payloads match exactly. The packages are not claimed byte-identical.
- No development-only prefix, profile/save/key runtime artifact or undeclared QA root is accepted by the added audit. Full manifests/cache bytes/comparison are retained; PCKs stay under E runs and were not committed or deployed.

This meets the exact-candidate two-export/manifest-comparison step. Original historical allocation/stack-overflow cause remains not reproduced and open; no GC, asset, renderer, exporter, guard, cap or reserve workaround was invented. Actual manifest-bound NEXT is checked independently; private packs are not substitutes for it.

## Source package

Initial raw git archive also included the already tracked historical .tmp/release_readiness_0_5_0.md. The strict runtime-root audit rejected that artifact; it is retained. A new source-only package uses exact fcfe Git objects with pathspec "." and ":(exclude).tmp", leaving source/history unchanged.

Private source package:
E:/CodexQA/BTH/runs/aud061-aud17-source-package-20261111/evidence/BeatTheHouse-source-fcfe0204.zip
621,079,950 bytes; SHA256 **20408b6db1d15d76afd5b9e915f1cb9b54af30eb28967e7181587e8ced8e70c3**.
ZIP commit comment equals fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc,6,608 entries, forbidden runtime roots0. Intentional tracked source test/docs/evidence are included (107 fixture entries); this is not a runnable distribution or an upload. No untracked QA profiles, caches or keys are included. Final Windows/Web/source release set and release checksums remain unqualified.

## Optional coverage, explicitly bounded

| Optional area | Covered | Not covered |
| --- | --- | --- |
| -003 Coin Pusher | Current Quarter Falls ordinary Web4 drops; native module24 reserved /18 emitted /6 pending, compaction and save boundaries in retained earlier orders | All three cabinets, feature item/tray collection across all exits, actual Windows close during paid native simulation |
| -004 normal-input seed batches | One fresh Daily normal run: quoted taxi7, three-play VP unfinished Save/reload/Continue and one three-unit no-pay settlement, second settled reload | No completed3–5 seed Clean/Rourke/Crew/Count batches or Crew-ignoring route control; catalog/module tests are not route completion |
| -008 interaction/readability | Actual1280x720 Web menus, map, room cards, Bar Dice/Pusher/Video Poker and Save/Continue; financial labels reviewed; native actual-draw observers retained | Full shipped Windows/phone matrix. The Grand Casino Bar Dice RET clipping is an open new finding |
| -011 audio/resources | Existing frozen Smoke Roulette audio audit passes; several rendered room/game changes and page reloads close with zero owned processes | Audible quality, repeated bonus/mute/focus/restart workload and measured allocator plateau; input-retention native probe refuses an unqualified backend |
| -009/-010 measurements | Frozen Smoke performance still has10 inherited error categories; three-variant source hint slices and source input invariants retained | No comparable shipped-native/Web versus official v0.6.0 measurement; no performance regression or optimization completion claimed. No optimization was attempted |

## Baseline and overall result

Fresh Python unittest discovery: **180 tests, OK**, same180/0 as baseline.
Full frozen candidate Smoke retained from AUD061-05: **4 pass /7 fail**, same eleven stage outcomes and no new normalized ERROR category; content25/runtime16 and performance10 inherited categories. No production change occurred between that run and these exact-source checks. Frozen no-pointer animation liveness passes.

Money assertion rows total856 checks /2 failures (Count reference comparisons); closing public travel83/0 plus Riverboat unit19/10; Rourke/terminal protocols pass after setup correction. Required source version2/2 fails. These distinct protocols are not combined into a misleading all-tests-pass total. Required -005/-006/-007/-012 gates remain unqualified or failed, so the candidate is not ready to tag.

## NEXT

Behavioral qualification remains bound to immutable fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc. That exact build's ten assets/startup, strict HTTPS and actual normal flow were verified in AUD061-05/11; its immutable URL remains available. Existing watcher additionally promoted report-only descendant e1f78f0c9504ee0e292bcf8cce2cb9e5564ae1ec with ten asset checks and clean fresh Daily startup. These report builds are not relabelled as repeats of all fcfe behavior checks.

This order's finished results/ledger association will be pushed through that same watcher. Post-push identity/startup is recorded separately below; no tag, release, hand upload, pipeline restart, guard change, deletion of retained evidence or profile migration was performed.

## Ledger reconciliation before report push

The documented fixed reference-time command in docs/todo/bth_task_ledger_checks.md was run with current owner/runtime inputs and --group current. Result:1,682 inherited findings; compared canonically to AUD061-11 final1,683, zero added and one resolved by actual current-owner assignment. The eight newly registered RC findings and current audit/batch rows add no reconciliation finding. Reconciliation remains globally failing on inherited work; it is not reported as a clean ledger. Raw command/result and delta are retained with this order.
