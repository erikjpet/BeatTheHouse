# fix06_32 — Unreviewed game-rework verification

Date: 2026-09-11

Base: `origin/main` `c570f2ce`

Verification branch: `codex/fix06_32`

Result: VERIFIED, with the missing native Coin Pusher runtime called out below. No payout, RTP, odds, wager, economy, or release value changed.

## 1. Craps wager table

The production catalog now contains one documentation row for each of the 40 player-reachable Street Craps wagers. The audit enumerates the allowed list rather than a second hand-maintained subset, exercises production placement and settlement helpers, and records at least 1,000,000 physical rolls per row. All 40 rows passed the larger of the existing 0.35 percentage-point floor and a four-standard-error sampling band. Differences below are measured minus documented RTP; they are sampling differences, not payout disagreements.

| Bet | Documented edge | Documented RTP | Measured RTP | Δ pp | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `pass_line` | 1.414% | 98.586% | 98.6503% | +0.0643 | PASS |
| `dont_pass` | 1.364% | 98.636% | 98.5366% | -0.0994 | PASS |
| `come` | 1.414% | 98.586% | 98.4676% | -0.1184 | PASS |
| `dont_come` | 1.364% | 98.636% | 98.6536% | +0.0176 | PASS |
| `field` | 2.778% | 97.222% | 97.3065% | +0.0845 | PASS |
| `pass_odds` | 0.000% | 100.000% | 99.9824% | -0.0176 | PASS |
| `dont_pass_odds` | 0.000% | 100.000% | 100.1039% | +0.1039 | PASS |
| `place_4` | 6.667% | 93.333% | 92.8154% | -0.5176 | PASS |
| `place_5` | 4.000% | 96.000% | 96.3310% | +0.3310 | PASS |
| `place_6` | 1.515% | 98.485% | 98.3321% | -0.1529 | PASS |
| `place_8` | 1.515% | 98.485% | 98.3802% | -0.1048 | PASS |
| `place_9` | 4.000% | 96.000% | 96.3439% | +0.3439 | PASS |
| `place_10` | 6.667% | 93.333% | 93.0837% | -0.2493 | PASS |
| `buy_4` | 1.667% | 98.333% | 98.2990% | -0.0340 | PASS |
| `buy_5` | 2.000% | 98.000% | 97.8532% | -0.1468 | PASS |
| `buy_6` | 2.273% | 97.727% | 97.7878% | +0.0608 | PASS |
| `buy_8` | 2.273% | 97.727% | 97.3813% | -0.3457 | PASS |
| `buy_9` | 2.000% | 98.000% | 98.0120% | +0.0120 | PASS |
| `buy_10` | 1.667% | 98.333% | 98.2187% | -0.1143 | PASS |
| `lay_4` | 3.333% | 96.667% | 96.8538% | +0.1868 | PASS |
| `lay_5` | 4.000% | 96.000% | 96.1502% | +0.1502 | PASS |
| `lay_6` | 4.545% | 95.455% | 95.3437% | -0.1113 | PASS |
| `lay_8` | 4.545% | 95.455% | 95.2256% | -0.2294 | PASS |
| `lay_9` | 4.000% | 96.000% | 96.0193% | +0.0193 | PASS |
| `lay_10` | 3.333% | 96.667% | 96.6290% | -0.0380 | PASS |
| `big_6` | 9.091% | 90.909% | 90.6890% | -0.2200 | PASS |
| `big_8` | 9.091% | 90.909% | 91.2266% | +0.3176 | PASS |
| `hard_4` | 11.111% | 88.889% | 89.3736% | +0.4846 | PASS |
| `hard_6` | 9.091% | 90.909% | 90.9801% | +0.0711 | PASS |
| `hard_8` | 9.091% | 90.909% | 90.2341% | -0.6749 | PASS |
| `hard_10` | 11.111% | 88.889% | 89.4606% | +0.5716 | PASS |
| `any_seven` | 16.667% | 83.333% | 83.4610% | +0.1280 | PASS |
| `any_craps` | 11.111% | 88.889% | 89.0616% | +0.1726 | PASS |
| `horn` | 12.778% | 87.222% | 86.7567% | -0.4653 | PASS |
| `ce` | 11.111% | 88.889% | 89.1728% | +0.2838 | PASS |
| `world` | 13.333% | 86.667% | 86.8454% | +0.1784 | PASS |
| `snake_eyes` | 13.889% | 86.111% | 86.0746% | -0.0364 | PASS |
| `ace_deuce` | 11.111% | 88.889% | 88.9072% | +0.0182 | PASS |
| `yo` | 11.111% | 88.889% | 88.7648% | -0.1242 | PASS |
| `boxcars` | 13.889% | 86.111% | 85.5352% | -0.5758 | PASS |

### Derivations against the shipped table

- Pass is the exact even-money line return `488/495 = 98.586%`; Don't Pass is its inverse with 12 pushing, `1953/1980 = 98.636%`. Come and Don't Come use those same production races after their initial roll.
- Field returns 30 on 2, 40 on 12, and 20 on 3/4/9/10/11 for a $10 stake: weighted return `350/(36×10) = 97.222%`.
- Pass Odds pay exact 2:1, 3:2, or 6:5; Don't Odds lay exact 1:2, 2:3, or 5:6. Every point-specific race therefore returns 100%.
- Place 4/10: three number ways versus six sevens, with $84 returned on $30, `(3/9)×(84/30)=93.333%`. Place 5/9: `(4/10)×(72/30)=96%`. Place 6/8: `(5/11)×(65/30)=98.485%`.
- Buy vig is charged only on a win and rounded up from 5% of the $20 stake. Buy 4/10 return $59 on a win, `(3/9)×(59/20)=98.333%`; Buy 5/9 return $49, `(4/10)×(49/20)=98%`; Buy 6/8 return $43, `(5/11)×(43/20)=97.727%`.
- Lay vig is charged only on a win and rounded up from 5% of the gross win. Lay 4/10 return $29, `(6/9)×(29/20)=96.667%`; Lay 5/9 floor the 2:3 win to $13 then return $32, `(6/10)×(32/20)=96%`; Lay 6/8 floor the 5:6 win to $16 then return $35, `(6/11)×(35/20)=95.455%`.
- Big 6/8 pay even money in a five-way number versus six-way seven race: `(5/11)×(20/10)=90.909%`.
- Hard 4/10 have one winning hard combination versus two easy combinations and six sevens, returning $80: `(1/9)×(80/10)=88.889%`. Hard 6/8 have one hard versus four easy and six sevens, returning $100: `(1/11)×(100/10)=90.909%`.
- Any Seven: six combinations return $50, `(6/36)×(50/10)=83.333%`. Any Craps: four combinations return $80, `(4/36)×(80/10)=88.889%`.
- Horn High 12 allocates the $10 as 2/2/2/4; outcome-weighted returns are `62+64+64+124=314`, so `314/(36×10)=87.222%`. C&E returns $80 on two elevens and $40 on four craps combinations: `(160+160)/(36×10)=88.889%`. World returns $62 on 2/12, $32 on 3/11, and pushes $10 on seven: `312/(36×10)=86.667%`.
- Snake Eyes and Boxcars each have one combination returning $310: `310/(36×10)=86.111%`. Ace Deuce and Yo each have two combinations returning $160: `(2×160)/(36×10)=88.889%`.

Disagreements: none. The production payout entries agree with all derived targets, so no owner ruling and no money change were needed. The hostile fixture changing Hard 4 profit from 7:1 to 70:1 failed as required. Core/Street Pass used the same rules engine and produced byte-identical 98.832918% measured RTP in the parity row. The fair/biased setting check also passed: the authored bias moved seven probability from 16.7172% to 14.1710%, a 2.5462-point reduction inside its documented band.

Primary evidence: `.tmp/craps/rtp_audit.json` (SHA-256 `650027344BEE3EDFC3C3BEFB267D3DB49616CE16E94E8F6DB675FB8E460A503D`) and `.tmp/craps_rtp_contract_fda373f2226b474db47baf8a01f32cbe/report.json` (hostile failure, SHA-256 `79E0DD447A2F1F26CD0340D23DCEEC1809C220BE89544FB2AF985E4DA6290B3C`).

## 2. Permanent gates and broken-fixture proof

`tools/check_godot.ps1` now runs the following deterministic headless gates in both Audit and Full, through one maintained helper. `tools/validate_project.ps1` pins every registration so none can silently disappear.

- `craps_extensive_playtest`
- `craps_rtp_audit`
- `crew_holdem_gameplay_audit`
- `crew_holdem_dynamic_table_audit`
- `crew_holdem_production_host_audit`
- `slot_autoplay_cadence_probe`
- `slot_foreground_autoplay_performance_probe`
- `blackjack_counter_surveillance_probe`

The screenshot-producing `craps_review_capture` is deliberately not a deterministic pass/fail suite gate. The seven short gates each returned nonzero against a purpose-broken copied fixture. The long RTP gate has its separate wrong-payout fixture described above. The final short hostile matrix is `.tmp/fix06_32_gate_contract_206e64d5a02b40009219e0a87eb0ab9e/report.json`, SHA-256 `73B2BAABFEA9B62E0DA03E8E09D0B1694E5D616CD04D85303491B893223C81D4`.

## 3. Hold'em production-host verification

The new production-host audit drives the real MainScene action boundary twice for each of three pinned seeds, including an uninterrupted replay and a save/reload replay. Every seed reached preflop, flop, turn, and river; opponent hole cards remained hidden; custom whole-dollar no-limit raises were accepted; chips were conserved; and the canonical hand/outcome signature was identical across reload.

- `FIX06-32-HOLDEM-A`: signature `2b4d7b3b011136e2501d63d75f04d6af11c9c9ce8d64678b14b8d63e2388c9a1`; button advanced 1→2 across the second hand.
- `FIX06-32-HOLDEM-B`: signature `2062adceac7dd25f393d849c505aad8911c7309b7c8cd6f491d567006d9b10d5`.
- `FIX06-32-HOLDEM-C`: signature `4cc0fb380ff992c508a5156002794fc6be36c706b6f135701ac6f8a30c7f5ac3`; called river showdown, Crew Rook won.

Hand arithmetic checked by hand for seed C: $3 opening blinds plus action contributions `[0,2,1,0,0,0,0,0,2,2,0,2,5,6,3]` equals the recorded $26 pot. Each ledger checkpoint matched the running sum; Crew Rook received the pot, the player's payout was $0, and total table chips remained 240 before and after. Seeds A and B similarly reconcile to $8 and $9 pots.

Save/Continue was exercised both mid-hand and between hands. The migration runner freshly loaded and round-tripped all 37 v0.5.1 fixtures and all 3 mid-0.6 fixtures through FoundationMain. `crew_draw_poker.gd` is the live Hold'em module with a compatibility-stable historical ID/path, not dead code or a shim. Player-facing career and run-report labels now say `Back-Room Hold'em`; persisted identifiers remain unchanged for custody.

Primary evidence: `.tmp/crew_holdem/production_host_audit.json` (SHA-256 `FB325C4E4824AB1404CCA5CDDD97108B18ADFE79423EDF1ADBB49B289A73C270`), `.tmp/fix06_32_v051_migration_stdout.txt` (`F208F3067379E9425922344DE586B1131B5E1A2AC91222E7BCDB3F32FF24268A`), and `.tmp/fix06_32_mid06_migration_stdout.txt` (`84134E513298A4DC1518FCA6D1275BDF928F3A35F4240954F98C084B699FDA40`).

## 4. Scenario exception decision

The recursive content scan found ten non-empty shipped `owner_exceptions` arrays, all using the established `world_connection` exception. No content consumes the new `choice_or_failure` or `material_outcomes` bypasses added in `3f31bf10`, and no owner approval names such a consumer. The two unused bypass paths were therefore reverted: every reachable scenario again requires at least three outcomes, at least three aftermaths, and at least two material axes. Permanent hostile cases prove that adding signed choice/material exception rows cannot bypass those absolute floors. The decision is recorded in `docs/todo/README_0_6_discovery_decision_log_2026-08-26.md`.

## 5. Short regression checks

- Coin Pusher: focused existing foundation assertions passed the 150-body inert/full-width opening, drop cadence, two paid FIFO queues persisted and resumed exactly once (5+7 reservations became exactly 12 accepted inserts), one-shot cup consumption, all three heavy-prize goal loops, and irregular supported-stack/reference parity. A production fixture then loaded and stepped the shipped cap of 160 bodies at 60 Hz without exceeding the authored ceiling. This isolated worktree has no native extension, so the maintained native-only 300-body performance gate could not be independently rerun here; the full focused shard correctly reported the missing backend instead of passing on fallback. This is an evidence-environment limitation, not a product relaxation.
- Blackjack: commit `9971aa2b` changed surveillance state, wager-pattern evidence, and count feedback. Diff inspection found no changed payout constant, payout multiplier, main/side settlement delta formula, or RTP configuration. The standalone surveillance probe passed: accurate flat betting remains invisible while a sustained count-shaped wager ramp becomes detectable. The broader generated Foundation blackjack shard exceeded its five-minute local wrapper and was stopped, so no green is claimed for that auxiliary run; Audit retains the deterministic surveillance gate.
- Slot: the production slot surface reported `animation_liveness_active=true`, 49 `surface_animation_redraw_count` ticks in 120 idle frames against the maintained floor of 8, 73 draw samples, 3.134 ms draw p95 against the 5 ms animated-idle budget, and zero full-snapshot rebuilds. A 0.000/frozen result would fail.
- Venue placement: `28568d12` added an authored game spot and Street Craps identity in `data/environments/archetypes.json`, and made base `scenario_game_modifiers` durable in `scripts/core/environment_instance.gd`. Those are exactly fix06_31-owned surfaces. This row made no change to either file. fix06_31 must preserve the Back Alley game spot and the durable base Street Craps modifier while replacing placement/grounding behavior.

Focused evidence: `.tmp/fix06_32_coin_pusher.json` (the native-backend limitation report, SHA-256 `09C9389730689351AA68D855CC6BB081793444261DFCC643A34B8852FAEFF81D`), `.tmp/fix06_32_surface_regression.json` (shipped cap and slot liveness, `329C655F5590DF35306F4A066BD136BEC8044BFD2FEDBFCF8936C13D990241BE`), and the permanent suite probes.

## 6. Routed onward

1. fix06_31 must explicitly regression-check the Back Alley `game_spots` placement and preservation of venue-level `scenario_game_modifiers`; fix06_32 did not touch its files.
2. A machine with the project native Coin Pusher extension installed should rerun the native-only 300-body performance/parity gate. No fallback result is presented as native evidence.
3. The generated all-blackjack Foundation shard's local five-minute no-verdict is retained as an auxiliary harness/runtime observation. It does not replace the green standalone gate and does not justify any budget change.

## 7. Final validation

Implementation head `6a4362b099717bb4b9fc2a7c700008ee0fbab08b` passed the required terminal gates with the pinned Godot 4.6 engine and no warning relaxation:

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1` — PASS in 98.2 seconds immediately before the terminal Audit sequence.
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -Suite Audit -RequireGodot` — PASS, all 16 stages, zero nonzero exits, zero timeouts, and zero stderr issues. The stage times in milliseconds were: validation 88,655; import 18,087; load check 37,214; Craps extensive 12,776; Hold'em gameplay 23,530; Hold'em dynamic table 11,205; Hold'em production host 16,207; slot cadence 12,142; slot foreground performance 12,603; Blackjack surveillance 4,353; Craps RTP 201,895; scenario multiseed 253,219; pinball physics 24,465; 10,000-spin slot 188,879; roulette rules 20,407; roulette audio 4,816.

Accepted Audit evidence: `.tmp/test_reports/20260912_033907_audit/summary.json`, SHA-256 `74E19AA061ABFFB161566BF5F7F0C76D3FDDF88AC9B65190EDA67141EEC2D2C3`; captured console output `.tmp/fix06_32_audit_reordered13_stdout.txt`, SHA-256 `58EBDE6ED6B401E160FE4DAFD8EDC8FD57777B42BA9A51EF6DBD7AF94201D297`. The final RTP and production-host reports retained their deterministic hashes `650027344BEE3EDFC3C3BEFB267D3DB49616CE16E94E8F6DB675FB8E460A503D` and `FB325C4E4824AB1404CCA5CDDD97108B18ADFE79423EDF1ADBB49B289A73C270`.

Several prior strict attempts failed closed on an intermittent Godot `ObjectDB instances leaked at exit` warning after otherwise-passing async probe assertions. No warning was filtered, retried inside a stage, or downgraded. Reordering the newly wired fast game probes ahead of the long RTP matrix made those failures cheap while preserving identical coverage. The accepted run was executed with no competing Godot process and every stage produced empty stderr.

Evidence remains under `.tmp/`; `.tmp`, `.tools`, `review_artifacts`, and `builds` were not staged. No release activity occurred.
