# game06_8 exact per-game gate inventory

Date: 2026-09-03
Frozen game product commit: `73b7a9523116712be266240397b3901e17476f4a`
Frozen game product tree: `8964fc29e38d7c3b2d5704ae089952a56a4cdbf4`

This is the executable inventory for the Family 1 gate. It accounts for every
id in `data/games/games.json` and the Grand Casino Rourke duel/showdown surface.
It does not replace row evidence: it names the exact focused authority,
math/determinism, persistence/consumer, visual/platform, and aggregate consumer
that must bind each shipped surface before `game06_8` closes.

| Shipped surface | Row authority / lifecycle gate | Math, determinism, and persistence gates | Visual, platform, performance, accessibility | Exact-tree disposition |
| --- | --- | --- | --- | --- |
| `scratch_tickets` | `check_scratch_tickets.gd`; Counter Games acceptance in archived `game06_5` | `scratch_tickets_rtp_audit.ps1`; issue/scratch/reveal/file/redeem/repeat and partial-ticket restore fixtures | `scratch_ticket_redesign_capture.gd`, alignment audit, Foundation visual/performance/accessibility suites | Binding row evidence PASS; aggregate rerun pending |
| `pull_tabs` | Pull Tab sections of `check_slots_surfaces.gd` and archived `game06_5` decision | `pull_tabs_seed_audit.gd`; seeded deal, ordered-window, file/redeem/repeat and stock persistence | Counter surface captures plus Foundation visual/performance/accessibility suites | Binding row evidence PASS; aggregate rerun pending |
| `slot` | `game06_4_machine_ritual_contract.gd`; Slot sections of `check_slots_surfaces.gd` | 10,000-spin family matrices, feature/acknowledgement, save/revisit and two-run determinism | machine native/Web probe, Slot cabinet visual QA, Foundation liveness/accessibility | PASS/DONE via `game06_4`; aggregate rerun pending |
| `bar_dice` | `game06_6_bar_dice_contract.gd` | 1,000 rounds per opponent profile; pot selection, conservation, interruption, save/revisit and ten-seed isolation | Bar Dice native/Web probe, table capture, Foundation liveness/accessibility | PASS/DONE via `game06_6`; aggregate rerun pending |
| `blackjack` | `game06_2_depth_contract.gd`; `game06_2_repeated_reprieve_contract.gd` | `blackjack_seed_audit.gd`; exact split/double/insurance/surrender accounting, 10-seed neighbour isolation, hostile replay, historical 128-entry save/load convergence | table captures, terminal/count/heat probes, Foundation liveness/accessibility; shared machine/platform gate where applicable | Focused PASS; final exact 1,000-hand audit running; aggregate rerun pending |
| `baccarat` | `game06_3_depth_contract.gd`; Baccarat sections of `check_table_games.gd` | `baccarat_seed_audit.gd`; 400-hand advancing shoe, third-card/commission conservation, save/revisit and ten-seed isolation | `game06_3` native/Web probe, visual matrices, Foundation liveness/accessibility | PASS/DONE via `game06_3`; aggregate rerun pending |
| `craps` | `craps06_3_depth_contract.gd`; `craps06_3_environment_integration_contract.gd` | `craps_rtp_audit.gd`; million-roll wager matrix, core/street parity, point/working-bet/interruption persistence | native and street table captures, Foundation liveness/accessibility | PASS/DONE through depth spine; aggregate rerun pending |
| `roulette` | `game06_3_depth_contract.gd`; Roulette sections of `check_table_games.gd` | `roulette_rule_audit.gd`, `roulette_seed_audit.gd`; 157 targets, ten sealed spins, trajectory/save isolation | `game06_3` native/Web probe, visual matrices, Foundation liveness/accessibility | PASS/DONE via `game06_3`; aggregate rerun pending |
| `crew_poker` | `crew06_10_depth_contract.gd`; `crew06_10_scenario_registration_contract.gd`; Crew play/heist/Turn contracts | friendly capped-stake pot conservation, public-state policy, ordered scenarios, interruption and save/revisit | Crew Poker visual capture/seed audit, Foundation liveness/accessibility | Depth lane repair pending integration, then exact-root rerun |
| `video_poker` | `game06_4_machine_ritual_contract.gd`; Video Poker sections of `check_slots_surfaces.gd` | variant paytable and 10,000-round audits, hold/draw/double, save/revisit and two-run determinism | machine native/Web probe, 15-state real-renderer proof, Foundation liveness/accessibility | PASS/DONE via `game06_4`; aggregate rerun pending |
| `coin_pusher` | `check_coin_pusher.gd`; accepted V3 program contracts | 600,000-drop EV, conservation, queue/replay/save/migration and deterministic physics contracts | native/Web input parity, live batch, static cache, cabinet/physics captures, liveness/accessibility | PASS/DONE; do not reopen; aggregate rerun pending |
| Rourke duel / Grand Casino showdown | `game06_7_showdown_duel_contract.gd` consuming the Blackjack host | five-hand ladder, boundary margins, route separation, private-state isolation, exact saved dealt hand and ten-seed determinism | 19-state native/Web semantic parity, visual matrix, Foundation liveness/accessibility | PASS/DONE via `game06_7`; aggregate rerun pending |

## Shared exact-tree gates

The per-game rows become one release-gate result only when all of these run on
the same integrated root after the focused owners are green:

1. `tools/game_ritual_vocabulary_contract_test.ps1` and
   `game_ritual_runtime_contract.gd` for closed declarations, hostile input,
   semantic equivalence, and neutral consumers.
2. Every row-specific contract named above, including the repaired
   `crew06_10_depth_contract.gd` and current `game06_2_depth_contract.gd`.
3. `check_table_games.gd`, `check_slots_surfaces.gd`, `check_scratch_tickets.gd`,
   and `check_coin_pusher.gd` through the clean `FoundationSuite games`
   aggregate. The current inherited parser gap in `check_slots_surfaces.gd`
   must be repaired before this can be called green.
4. The exact 1,000-hand Blackjack statistical audit at frozen product commit
   `73b7a952`, with its report hash and payout edge recorded.
5. The unchanged accepted native/Web, deterministic, performance/liveness,
   accessibility, and real-renderer artifact hashes recorded by each row report;
   rerun only where the exact integrated changes touch those product inputs.

No missing polish outside a row prompt is silently promoted to a blocker. No
missing required gate is waived. Owner-only tactile/readability judgment remains
for `playtest06_1` after the automated ledger is complete.
