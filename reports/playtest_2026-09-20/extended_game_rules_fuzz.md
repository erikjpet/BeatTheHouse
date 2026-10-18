# Beat the House — Extended Game Rules and Statistical Fuzz Report

**Date:** 2026-09-20  
**Build:** `0.5.1`, Godot `4.6.stable`, candidate `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`  
**Scope owner:** extended game-rules/fuzz playtester  
**Disposition:** investigation and documentation only; no product source or data was changed

## Executive summary

This extended pass found **one new reproducible gameplay-state defect**: a rejected Blackjack action can append a completed game-result record to the live story history before the transaction crosses its fallible environment-turn boundary. Retrying the still-pending action commits the same record a second time. Player money, chips, RNG, and turn count are correctly single-applied; the corruption is isolated to history and any downstream analytics or progression readers that consume that duplicated history.

The defect reproduced in three consecutive diagnostic runs and was reduced to one exact snapshot difference: the rejected/retried run contains two identical `game_action` story entries while the clean single-delivery control contains one. The rejected response itself reports `blackjack_host_committed=false`, so this is an atomicity violation rather than an ambiguous successful result.

No additional math, rules, generation, interaction, or stuck-state defects were confirmed. High-volume coverage included 3.5 million Scratch Ticket outcomes, more than 40 million Craps rolls, 60,000 Slot outcomes, 2,000 Baccarat hands, 200 Roulette tables/spins, 19,200 Slot feature-state fuzz cases, and 3,600 cross-game wait-state cases. A real Pinball jackpot feature was also driven from reveal through takeover and authoritative launch.

Three red diagnostics were deliberately excluded from the product bug count: two stale/brittle test assumptions, and headless screenshot cleanup errors after a Video Poker proof had already completed its functional assertions. One oversized Blackjack statistical job reached its explicit 30-minute harness cap without an error; it is treated as an incomplete workload, not a game failure, and was replaced with a bounded rerun.

## Confirmed finding

### EXT-GAME-001 — Rejected Blackjack transaction leaks a completed story record and retry duplicates it

**Severity:** P2 / Medium  
**Frequency:** 3/3 focused reproductions  
**Area:** Blackjack sealed action authority, transaction rollback, history/analytics integrity  
**Player-visible risk:** duplicated result/history entries after a recoverable action-boundary rejection; downstream statistics, achievements, progression, or run summaries may count one hand twice even though the bankroll settles once

#### Reproduction

1. Create a deterministic Blackjack authority fixture with a `$5` `play_basic` action.
2. Enable the existing debug failure injection for the environment-turn boundary.
3. Record the live `story_log`; it is empty.
4. Resolve the action through `FoundationMain._sealed_action_host_resolve_intent()`.
5. Observe the returned rejection: `ok=false`, `blackjack_host_committed=false`, `error_code=forced_turn_rejection`.
6. Inspect the live run before any retry. It already contains the completed Blackjack `game_action` record.
7. Use the normal canvas-facing `blackjack_retry_pending` command and replay the exact pending delivery.
8. Compare the final save snapshot with a clean control that executes the same delivery once.

#### Expected

A transaction rejected before publication must leave all player-observable and persisted run state unchanged, apart from the durable pending-delivery record intentionally retained for retry. The successful retry should create exactly one story entry, matching the clean control.

#### Actual

- Before rejected resolve: `story_log.size() == 0`.
- Immediately after rejected resolve: `story_log.size() == 1` and contains the full completed result (`game_id=blackjack`, `action_id=play_basic`, `bankroll_delta=5`, `outcome_bankroll_delta=5`).
- After the native retry: `story_log.size() == 2`.
- Clean single-delivery control: `story_log.size() == 1`.
- The retry response is byte-for-byte canonically equal to the clean response.
- Bankroll, chips, RNG, environment-turn state, and the rest of the serialized run match the clean control. The sole final snapshot difference is `$.story_log size 2 != 1`.

This isolation is important: normal economy assertions can pass while persisted history is already corrupt.

#### Root cause

The sealed host applies result side effects before it crosses the environment-turn boundary that can still reject the overall action. In `scripts/ui/foundation_main.gd`, `GameModule.apply_result(proposed_candidate, ...)` runs at line 2579; only afterward does the host call `_sealed_action_host_advance_environment_turn(proposed_candidate)` and return an uncommitted rejection if that boundary fails.

`GameModule.apply_result()` appends story entries through `RunState.log_story()` (`scripts/core/game_module.gd:981`; `scripts/core/run_state.gd:13504-13508`). The optimized candidate machinery intentionally uses shallow/read-only aliases for much of the transaction graph and depends on copy-on-write guarantees. The focused failure proves that the story append escapes that proposal boundary in this rejection path. Because publication never occurs, there is no rollback or compensating removal. The retry then correctly applies the result again, producing the duplicate.

The unsafe ordering is therefore the directly verified causal boundary: a state-mutating apply occurs before the final fallible step, while the candidate/alias contract does not fully contain every apply-time mutation.

#### Recommended fix options

1. Make the transaction candidate fully own every collection that any `GameModule.apply_result()` path can mutate, including story/profile/crew/reputation histories, before calling `apply_result()`.
2. Prefer staging result-driven history and analytics writes as deltas and publish them only after the environment-turn boundary succeeds.
3. Alternatively, move the final fallible environment-turn validation before irreversible result application, provided all action/environment semantics remain deterministic.
4. Add a regression that snapshots the entire live `RunState` immediately before a forced boundary rejection and asserts exact equality afterward except for the explicitly permitted pending-delivery ledger.
5. Extend the existing retry contract to compare the complete final save snapshot—not just bankroll, RNG, and response payload—and specifically assert one story record.

#### Evidence

- `.tmp/playtest_extended/game_rules_fuzz/game06_2_depth_repro2.stdout.log`
- `.tmp/playtest_extended/game_rules_fuzz/game06_2_depth_repro2.stderr.log`
- `.tmp/playtest_extended/game_rules_fuzz/game06_2_retry_diag2.stdout.log`
- `.tmp/playtest_extended/game_rules_fuzz/game06_2_retry_diag3.stdout.log`
- `.tmp/playtest_extended/game_rules_fuzz/game06_2_retry_diagnostic.gd`

## Test inventory and results

### Blackjack

- Depth/authority suite exercised exact-key replay, save/load, wager funding, turn boundaries, count settlement, and rejection/retry behavior. It exposed EXT-GAME-001.
- Manual count-settlement presentation passed with four icons.
- Winning-hand payout settlement passed (`payout_start=13560`, reveal duration `1560 ms`, final bankroll `$1105`).
- Terminal presentation passed (`deal_duration=1600 ms`, terminal bubble spawn `12541 ms`).
- Counter-surveillance and heat-backoff probes passed.
- Interaction runtime probe passed all functional checks; its process-exit `ObjectDB` warning is classified below as harness teardown noise.
- The original 500-seed / 10,000-payout-hand audit remained CPU-active with no stderr but reached the explicit 1,800-second cap before emitting a final report. Its bounded replacement passed: 120 generated tables, 120 clean hand resolves, 1,649 compact UI/action checks, 1,120 resolve samples, and 1,000 payout hands. Payout drift was `-32 / 5395 = -0.0059`; count, peek/ejection, and strategy-confrontation coverage all completed.

### Roulette

- Rule audit passed all **157** legal betting targets and hitboxes: 38 straight, 58 split, 12 street, 22 corner, 11 six-line, 3 trio, 3 column, 3 dozen, top line, red/black, odd/even, high/low.
- A 200-seed audit generated 200 tables, validated 200 surfaces and 200 draw paths, and resolved 200 spins with zero failures.
- All trajectories contained exactly 96 frames.
- Surface-state sampling completed 1,000 calls; past-post wait-state fuzz completed 400 seeds without a stuck state.

### Baccarat

- 2,000 deterministic hands completed with zero failures.
- Observed result rates: Banker `0.456`, Player `0.449`, Tie `0.096`.
- Ten authoritative host commits passed; flat Banker betting produced aggregate delta `-651` in this sample.
- Edge-sort memory/wait-state fuzz completed 400 seeds without a stuck state.
- The combined Roulette/Baccarat authority, replay, boundary, and persistence depth contract passed.

### Craps

- Extensive functional audit passed **204 checks**, including surface interactions and 100,000 rule settlements.
- RTP audit passed all **40** named wager families at approximately 1,000,000 rolls each: pass/don't pass, come/don't come, odds, field, place, buy, lay, Big 6/8, hardways, one-roll propositions, horn, C&E, world, and exact totals.
- Dice-setting fairness check passed (`fair_seven=0.167172`, `biased_seven=0.141710`, reduction `0.025462`).
- Street Craps and core Pass Line settlement produced exact sampled RTP parity (`0.988329`).

### Slot, Buffalo, and Pinball feature family

- Deep audit completed 10,000 spins for each of six cabinet/format combinations, **60,000 spins total**, with scripted nudges enabled. All configured RTP, hit-rate, loss-disguised-as-win, near-miss, and feature-frequency bands passed.
- Sample RTPs ranged from `0.94316` (Buffalo video) to `0.99009` (Pinball line), all inside their authored acceptance bands.
- General stuck-state sweep exercised 48 Slot/feature scenarios across 400 seeds, **19,200 scenario evaluations**, with zero stuck states.
- A real Pinball jackpot trigger was found after 13 production spins. The probe observed trigger reveal, takeover activation, a valid launch control rectangle, an emitted `slot_bonus_launch` action, a committed authority response, and launch-in-progress state. Functional result: pass.

### Video Poker

- Machine ritual contract passed sealed authority, deterministic replay, save/revisit behavior, and action-boundary checks.
- General stuck-state fuzz completed 400 seeds across holdout and double-up state transitions with zero stuck states.
- Rebuild proof completed Jacks or Better, Double Deuces, Triple Double Bonus, holdout feedback, unfinished-holdout Draw escape, and small-screen touch-control checks, then emitted `VIDEO_POKER_REBUILD_PROOF_PASS`.
- The proof's subsequent headless screenshot errors are not counted as product failures; see excluded diagnostics.

### Bar Dice

- Seven-phase, ten-seed game contract passed.
- Pot-selection probe passed five observations: `$40`, `$2`, `$10`, `$40`, and reopened `$5`; clicked index, selected index, and active stake agreed each time.
- Controlled-roll wait-state fuzz completed 400 seeds without a stuck state.
- The earlier visual report retains the known Bar Dice overlap findings UIE-022-A/B; this pass did not duplicate them as new issues.

### Scratch Tickets

The RTP sampler executed 500,000 outcomes for each of seven ticket types (**3.5 million total**). Every ticket remained within its authored acceptance band:

| Ticket | Sample RTP | Acceptance band | Result |
|---|---:|---:|---|
| Two-Fer | 3.92268 | 3.800–4.100 | Pass |
| Lucky 7s | 4.02763 | 3.850–4.200 | Pass |
| Tic-Tac-Gold | 3.99274 | 3.800–4.250 | Pass |
| Crossword Corner | 3.95442 | 3.750–4.200 | Pass |
| Bonus Bingo | 3.97311 | 3.750–4.250 | Pass |
| High Roller Hold'em | 4.11744 | 3.800–4.400 | Pass |
| Golden Vault | 3.98475 | 3.700–4.250 | Pass |

### Pull Tabs

- Reveal-and-file wait-state fuzz completed 400 seeds without a stuck state.
- Generation, stock, buy/reveal, settlement, persistence, and file-state behavior were already green in the immediately preceding all-games functional pass (`reports/playtest_2026-09-20/games_performance.md`). No contradictory result appeared in this extension.

### Coin Pusher

- Native physics, generation, body-cap refusal, persistence, collect behavior, and fallback parity were green in the preceding all-games and packaged-platform passes.
- The generalized 400-seed travel/event/closing sweeps did not produce a cross-system pusher lock. This extension found no new pusher defect.

### Back-Room Hold'em (`crew_draw_poker`)

- Actor-present generation, deal/action/showdown, authority, and persistence were green in the preceding all-games pass.
- This extension found no new Hold'em-specific defect and did not supersede that result.

## Cross-game stuck-state coverage

The generalized sweep passed all 400 seeds with `stuck=0`. In addition to 48 Slot-family scenarios, it exercised nine non-Slot waits at every seed: Blackjack count-settlement preview, Baccarat edge-sort memory, Roulette past-post, Video Poker holdout/double, Bar Dice controlled roll, Pull Tabs reveal/file, triggered-event queue, travel-lock countdown, and broke-at-closing walk fallback. This represents **3,600 non-Slot wait-state evaluations**.

No tested state lost every legal continuation, failed to expose a required action, or remained permanently blocked after its authored wait expired.

## Excluded diagnostics and harness findings

### Brittle source-shape assertion in `game06_2_depth_contract.gd`

The contract reports “Read-only compatibility core no longer proves…” because it searches production source text for an obsolete three-argument `_table_state(run_state, environment, read_only_run_state)` call. Production now has a fourth `owns_table_state` argument. Behavioral checks continue to pass. This is a test-maintenance issue, not a player-facing bug.

### Stale Blackjack repeated-reprieve fixture hash

`blackjack_repeated_reprieve_contract.gd` rejects the fixture before gameplay because its hard-coded `BLACKJACK_GAMES_SOURCE_SHA256` no longer matches the normalized current `games.json`. The fixture library returns null, leading to an empty fingerprint and `heat=-1`. This does not demonstrate a rules failure and should be repaired in the harness before reuse.

### Oversized Blackjack audit timeout

The 500-seed / 10,000-payout-hand job was intentionally capped at 1,800 seconds. It remained CPU-active, produced no engine errors, and had not emitted a final report when the harness terminated it. Because no failing assertion or hung-state signature exists, this is an incomplete workload rather than a confirmed performance or rules bug.

### Headless-only screenshot/cleanup warnings

- The Video Poker rebuild proof emitted its functional PASS marker, then attempted to save screenshots using the dummy headless renderer. The viewport texture was null, producing `save_png` errors after the gameplay checks. This is a proof-tool rendering limitation.
- Blackjack interaction and Pinball gameplay probes emitted `ObjectDB instances leaked at exit` during immediate test-process teardown. No live-session object-growth or repeated-runtime degradation was reproduced, so these are retained as teardown warnings, not product leak reports.

## Evidence index

Primary evidence directory: `.tmp/playtest_extended/game_rules_fuzz/`

- Blackjack rejection/retry: `game06_2_depth_repro2.*`, `game06_2_retry_diag2.*`, `game06_2_retry_diag3.*`
- Blackjack bounded statistical audit: `blackjack_seed_120.*`, `blackjack_seed_120.json`
- Blackjack interaction/presentation: `blackjack_interaction.*`, `blackjack_manual_count.*`, `blackjack_win_payout.*`, `blackjack_terminal.*`, `blackjack_surveillance.*`, `blackjack_heat_backoff.*`
- Roulette: `roulette_rules.*`, `roulette_seed_200.*`, `roulette_seed_200.json`
- Baccarat: `baccarat_2000.*`, `baccarat_2000.json`
- Craps: `craps_extensive.*`, `craps_rtp_1m.*`
- Slot/Pinball: `slot_deep_10000.*`, `slot_pinball_gameplay.*`
- Bar Dice: `game06_6_bar_dice.*`, `bar_dice_pot.*`
- Scratch Tickets: `scratch_rtp_500k.log`, `scratch_rtp_500k.json`
- Cross-game stuck states: `stuck_sweep_400.*`
- Video Poker: `game06_4_machine_ritual.*`, `video_poker_rebuild.*`

## Final disposition

- **New confirmed defect:** 1 — EXT-GAME-001.
- **Previously known visual findings observed but not duplicated:** UIE-022-A/B.
- **New statistical/rules failures:** 0.
- **New generation failures:** 0.
- **New stuck-state failures:** 0 across 22,800 generalized scenario evaluations.
- **Product fixes made:** none.

The most important fix target for the later bug-fixing team is transactional isolation around `GameModule.apply_result()`. Validation should use a forced late rejection and compare the complete persisted run graph, since economy-only assertions do not catch the duplicated history demonstrated here.
