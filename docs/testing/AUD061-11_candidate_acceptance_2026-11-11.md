# AUD061-11 — Frozen candidate acceptance

Specification: docs/todo/BTH_0.6.1_audit_work_orders.md.
Started from and tested proposed candidate **fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc**, tree **2d49cb17f83379715435a2576473c5cba52728ff**. HEAD stayed at that SHA during these runs. Only reports/ledgers were edited; a guarded diff over scripts, data, scenes, assets, project/export settings and the exporter returned exit 0 with no output.

Disposition: **FAILED / qualification remains open**, not a production fix. Confirmed failures and missing required coverage have separate stable findings in AUD061_RC_findings_2026-11-11.md. No speculative gameplay change was made.

## Before and scope

The report was static and some ledger statuses had already moved: BTH-GAME-RETURN-001 and BTH061-CREW-EXPIRED-HANDOFF already recorded successful recreated Web acceptance on 85d38b96. That historical evidence is preserved, not relabelled as candidate evidence. This run repeats the candidate checks below. No original personal saves/profiles or cross-version fixtures were used.

Native commands were guarded through .tmp/aud061_control.py and the retained aud061_rc_checks.py adapter: Godot 4.6 official, --headless --path <approved E workspace>, either --script res://scripts/tests/<name>.gd or its existing .tscn for Node probes. Every child received a current storage gate inside the inherited 12% CPU / 2 GiB Job, 4 GiB expected writes + 20 GiB reserve; assignment, no-breakaway, timeout and cleanup remained enabled. Exact commands, output and manifests are retained under evidence/AUD061-11_20261111.

## Candidate matrix

| Recorded acceptance | Actual candidate result | Disposition |
| --- | --- | --- |
| BTH-GAME-RETURN-001 | crew_delivery_game_return_check: 477 checks, 0 failures; all 11 game-return cases, including paid Blackjack/Roulette/Pusher callbacks and selected Save/Continue | Native repeat passes; exact candidate Web Crew offer/accept/neutral-Close/cold fixture repeat remains open |
| BTH061-CREW-EXPIRED-HANDOFF | crew_expired_handoff_check 305/0; separate-process crew_handoff_cold_continue_check 105/0 | Native repeat passes; exact candidate rendered Jazz expiry/cold flow remains open |
| SHOWDOWN-META-CHOICE-FIX-031 | showdown_meta_inventory_check 52/0 plus separate process --cold 5/0 | Native repeat passes; rendered offered Meta choice remains open |
| TERMINAL-META-PERSISTENCE-026 | 219 host assertions across six actual processes plus 172 domain assertions, all pass | Real obstruction/rollback/retry, public Abandon/Continue, acknowledgement replay, tutorial and outcome controls pass; exact corrective ancestor a3a29fdb is in served candidate |
| BTH061-006, all 11 games | New fresh same-build producer: 85/0; separate process: 44 checks / 1 failure, Scratch owned-state comparison. All 11 load/reenter and wallet/inventory/RNG checks pass. | Partial coverage, not eleven-game completion; Scratch selected purchase was sold out; Craps remained betting; not all paid/pending/settled cases were reached |
| BAR-DICE-REVEAL-RESTORE-001 | warm 72/0; cold 44/1, “Passive tumble ends without funding or rootRNG change” | Exact restored cup/ante, one committed six-unit Call, dice/account conservation and replay guard pass before animation assertion fails; investigate separately |
| BAR-DICE-COVER-DISPLAY-001 | actual native draw observer 94/0, COV/RISK/RET 6/6/0 | Values pass; current default Grand Casino Web Practice clips the RET field at 1280x720 DPR1 |
| PERF-001/003 | continuous-input and compaction checks pass; continuous source backend is gdscript_v3, maximum publication age 16ms, 24 reserved / 18 emitted / 6 pending drops and cash476 | Module invariants pass; not an exported native-runtime performance acceptance |
| PERF-003 retention | probe refuses: “Native solver unavailable; refusing a different backend measurement.” | No unqualified Windows solver copied, no fallback substituted for the requested measurement |
| PERF-002 | 3 Video Poker variants, 32 masks each / 27,430 completions per variant; maximum projection slices 3613/3650/3626us; parity checks pass | Synthetic module result; normal Web Draw sampled, strategy-hat hint performance and comparable native/Web measurement still open |
| Animation liveness | Animation liveness without pointer input: PASS | No scheduling or rendering suppression |

The usable assertion rows above total 1,674 checks with two failures (Scratch comparison and Bar Dice cold animation). Performance probes and liveness have their own outcome protocols and are not invented assertion counts. The invalid follow-on Bar Dice settled run (19 checks / 1 failure) omitted BTH_DICE_EXPECTED_FINAL_CASH and followed the failed cold stage; it is retained as a harness/input failure, not a second persistence defect.

## Terminal harness adaptation

The original unmodified host test first stopped at its historical exact-root-name assertion (3 checks / 1 failure), before exercising behavior. The first adapter then exposed one additional historical data/saves literal; its dependent stages are non-qualifying. A copied test changes only the old path guards and that path literal to the exact prepared current storage manifest, E containment and actual production save directory. All behavioral assertions remain unchanged. Path checks increase host assertions from the historical 171 to 219; domain stays 172. Both final adapter sources are retained for review. Temporary indentation/parser errors and failed setup attempts remain in evidence.

The first multi-stage adapter reused output filenames; its per-stage observation footers and errors remain in results.json/worker.txt, while named raw stdout files represent the last matching stage. The final adapter uses unique numbered stage names and retains every complete output and launch gate. Final 391/0 qualification uses those complete receipts.

## Eleven-game probe qualification

The initial probe compared typed state to ordinary JSON, used an incomplete Slot Practice room as a campaign, did not wait for Pusher readiness, and once continued after a missing run; those results are not player-defect evidence. One warm error timed out at 240s; its invalid dependent cold child was stopped by exact owned command line and reconciled to zero active processes. The next revisions add guards, preserve typed expectations, use the existing complete-room generator/full-library prerequisite for cabinets, respect real inter-press time, and capture the final official post-exit save separately. No failed assertion was skipped or disabled.

Final source is retained as harness/aud061_rc_resume.gd. Final wallets and owned data are in native output. Scratch's strict in-memory comparison fails; a read-only codec comparison of its warm expectation against the final primary after the cold observer has no value differences. A preliminary observer used the wrong envelope level and was corrected to SaveService's run_state envelope. No lost paid ticket or money is established. Keep the discrepancy and missing paid Scratch case open.

## Actual Web observations

Exact unmodified candidate HTML/PCK/engine/Web native, fresh E profile, ordinary pointer/keyboard input, 1280x720 DPR1. No injected save, game script, scene, action authority, clock or live-state override. 51 recorded actions; page errors 0, console errors/warnings 0, browser Job exit 0, active processes 0.

- Bar Dice Practice: ordinary Roll / Take Cover / two Shakes / Settle / Slam / Lift / Call. One natural loss changes cash100000 to99990. Settle controls recover. The Grand Casino CHIPS cover line clips the RET field.
- Video Poker Practice: Deal, hold the two2s, Draw. One no-pay result changes100000 to99998. This has no strategy-hat hint claim.
- Quarter Falls Practice: four physical Drop-button presses debit100000 to99996. Later no-input snapshot shows continued simulation. No whole-game leak or memory plateau is claimed.
- Normal Daily run: cash68 to61 for the quoted taxi7 /54min to generated Gas Casino. Entered Triple Double Bonus three-play Video Poker normally. Opening cards2S/AH/4D/3C/9D; held AH in all three hands.
- Normal Menu Save produced primary127128 bytes, SHA256 e60284c57ee8c1abc2ccf2cc8373bc4cdc6c0e4e5cdc624ede81422c95546fc2. Page reload, actual Continue and physical cabinet re-entry retain the same cards, holds and cash61. Reloaded primary hash is identical.
- One Draw produces three no-pay hands and cash58 (one three-unit charge). Normal Save produces134073 bytes, SHA256 7236da3e9df6b28cf7e01ad7bd8619354df44075f55199f2adbd6758c6478b2e. A second reload/Continue/re-entry retains those settled hands and cash58 with no repeat debit. These are fresh Godot runtime page reloads, not separate browser-process restarts.

The Windows controller's final results printer initially could not print an arrow character in cp1252; browser result.json and job.json independently show clean exit0. Only the ignored controller stdout encoding was corrected to UTF8.

Strict normal HTTPS was also tested at https://192.168.0.36:8443/p/beat-the-house/play/dev/fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc/: exact footer, four asset requests200, fresh Daily, no page/console errors, Job0/active0. No permanent trust, certificate validation, audience or security setting changed. The historical certificate error is not reproduced here. This does not assert approval for any permanent trust change.

## Baseline and NEXT

Full candidate Smoke: 4 pass /7 fail, same eleven stage outcomes as baseline; content25/runtime16 failures; no new normalized ERROR category; performance10 inherited categories. Liveness passes. Fresh broad Python/coverage checks are assigned to AUD061-17; the old 180 Python baseline is not relabelled as a rerun here.

NEXT promoted exact fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc, tree2d49cb17f83379715435a2576473c5cba52728ff, archive95dfd86c6ca9ce73682045f517720511176e786f0b1619a5e543c8177c30aa0f. Ten asset checks pass (eight hashes, two pinned engine HEAD checks), clean startup and observed play above. All new tests use that frozen source and immutable served build. The menu still reads0.6.0-dev+fcfe0204d4d0; AUD061-04 remains blocked. Publication of these evidence-only results must not be confused with qualifying a changed gameplay candidate.

Unverified: complete eleven-game paid/pending/settled Web matrix; candidate Crew/Jazz and offered Meta changed-behavior flows; normal strategy-hat hint attribution; comparable qualified Windows native performance and long input-retention plateau. No release or tag is authorized by these results.

## Result-report delivery

Report commit45b175ec3b971ae85d1217b1124099f8d9562bdd and associated ledgers were pushed together after pull --rebase reported up to date. Existing watcher promoted evidence-only descendant e1f78f0c9504ee0e292bcf8cce2cb9e5564ae1ec, tree45bd0dee352c033a6f1a977e96c823bdf7200038, archive947d068a7896e334e721f881119d743f2e7098d6a762e99a2c9267946c2ce6e8. Ten served-asset checks and a fresh normal Daily startup pass, page/console errors0, Job0/active0. Actual candidate behavioral qualification above remains bound to fcfe, not relabelled as tests of e1. The two served PCK audits both report1168 files.

Final reconciliation after adopting actual current acceptance ownership and recording the latest user's scoped resumption:1683 inherited errors /52 tasks, no new finding relative to pre-order reconciliation. Broader item/scenario pause IDs remain unchanged. Current strict HTTPS succeeds without any trust change; the old certificate condition is not an active block for the observed route.
