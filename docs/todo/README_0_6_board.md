# 0.6 Active Task Board — The Living Town & The Crew

Created: 2026-08-13 · Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` (v4, owner-approved).
This board is the **single source of truth for 0.6 execution state**.
The roadmap is the single source of truth for **design intent**. When
code reality disagrees with either, code reality wins — record the
disagreement in the linked Discovery & Decision Log companion.

## What 0.6 is (direction, for any agent landing here cold)

0.5 shipped the complete game loop. 0.6 makes the world alive and adds
the flagship Crew path: (1) a **Tonight system** — every environment
seeds a "what's happening here tonight" scenario with phases; (2) a
**connected town** — run-level weather/calendar/happenings, a Police
Sweep that walks the map, rumors that truthfully describe other nodes,
traveling NPCs; (3) the **Crew path** — trust ladder over the 7 crew
characters, the Punchline 3-layer venue (comedy club / hidden casino /
crew back room), Streets delivery gameplay, the Numbers lottery racket
with two rig routes, coordinated plays, and a 2-plan Grand Casino heist
finale with the hidden-betrayal Turn system; (4) **new games** — craps
(+ street craps), a 3-variation coin pusher family, back-room poker;
(5) NPC storyline chains; (6) content depth. Everything is within-run,
seeded, deterministic, Act 1 only, and optional to the player.

## Board protocol (BINDING for every agent)

1. **Claim before work.** Edit this file: set your task's row Status to
   `IN_PROGRESS`, fill Agent and Started, append one Work Log line.
   Commit that claim (with your normal first commit or alone) so
   parallel agents see it. If the row is already `IN_PROGRESS` or
   `DONE`, do not double-claim — pick other `TODO` work whose Depends
   On rows are all `DONE`.
2. **Check dependencies by code, not by table.** A `DONE` row means the
   prompt's agent verified it; still re-verify the actual landed APIs
   you consume before building on them.
3. **While working.** Scope-affecting discoveries, deviations from the
   roadmap, and decisions you had to make go in the dated
   [Discovery & Decision Log companion](README_0_6_discovery_decision_log_2026-08-26.md)
   (task-id-tagged, one bullet each). Questions
   only the owner can answer: log them under Owner Questions and pick
   compatible work that doesn't depend on the answer; do not guess on
   owner-locked design.
4. **If blocked.** Set Status `BLOCKED`, put a one-line reason in
   Notes, log it, and stop or switch tasks.
5. **On completion.** All gates green → set Status `DONE`, fill
   Finished, put a one-line verification summary in Notes, fill the
   Execution Record at the top of your prompt file, **move the prompt
   file to `docs/todone/`** (never delete), and append a line to the dated
   [Work Log companion](README_0_6_work_log_2026-08-26.md) naming any rows
   your completion unblocks.
6. **Never** weaken a test, budget, liveness floor, or deterministic
   assertion to go green; never sweep-stage unrelated files; archive,
   don't delete.

Status values: `TODO` · `IN_PROGRESS` · `BLOCKED` · `DONE`

## Task table

Waves gate on dependencies, not on ceremony: any `TODO` task whose
Depends On rows are all `DONE` is claimable, regardless of wave labels.
Wave C games are intentionally parallel-friendly.

### Wave A — Engines

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| env06_1 | `../todone/env06_1_scenario_engine_prompt.md` | DONE | — | env06_2/3/4, town06_2/3, craps06_2, push06_1 | PM:Codex/sub:1 | 2026-08-13 | 2026-08-14 | PM verified scope/design, all gates, determinism, visual QA, and coexistence PASS. |
| town06_1 | `../todone/town06_1_town_state_prompt.md` | DONE | — | town06_2/3, push06_2, streets06_1 | PM:Codex/sub:2 | 2026-08-13 | 2026-08-14 | PM verified scope/design, all gates, determinism, visual QA, and coexistence PASS. |
| crew06_1 | `../todone/crew06_1_trust_core_prompt.md` | DONE | — | streets06_1, crew06_2/3/5/6/7/8/9 | PM:Codex/sub:3 | 2026-08-13 | 2026-08-14 | PM verified lender compatibility, hidden-state design, all gates, determinism, and coexistence PASS. |

### Wave B — World content

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| env06_2 | `../todone/env06_2_tier1_scenarios_prompt.md` | DONE | env06_1 | crew06_5 | PM:Codex/sub:1 | 2026-08-14 | 2026-08-14 | PM verified all 17 scenarios/events, tutorial neutrality, real-selector reachability, full integrated gates, determinism, and zero-overlap visual QA PASS. |
| env06_3 | `../todone/env06_3_tier2_scenarios_prompt.md` | DONE | env06_1, env06_4 | crew06_5, crew06_8 | PM:Codex/sub:4 | 2026-08-14 | 2026-08-14 | PM verified 25 scenarios, production route contracts, all integrated gates, determinism, and 14/14 zero-overlap visual captures PASS. |
| env06_4 | `../todone/env06_4_punchline_rework_prompt.md` | DONE | env06_1 | env06_3, crew06_2, crew06_6 | PM:Codex/sub:2 | 2026-08-14 | 2026-08-14 | PM verified scope/design, L2 compatibility and migration, systems/UI/determinism/visual gates, and three-layer zero-overlap smoke PASS. |
| town06_2 | `../todone/town06_2_rumors_travelers_prompt.md` | DONE | env06_1, town06_1 | town06_3, crew06_3, crew06_9, chain06_1 | PM:Codex/sub:3 | 2026-08-14 | 2026-08-14 | PM verified truth traces, heard tier, itineraries, reputation propagation, save compatibility, and combined systems/UI/determinism/visual gates PASS. |
| town06_3 | `../todone/town06_3_police_sweep_prompt.md` | DONE | town06_1, town06_2 | streets06_1 (full), crew06_3 (full) | PM:Codex/sub:5 | 2026-08-14 | 2026-08-14 | PM verified hidden deterministic track, costed encounters, wake/pressure, save/UI contracts, full integrated gates, and Wave B composition PASS. |

### Wave C — Games

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| craps06_1 | `../todone/craps06_1_craps_core_prompt.md` | DONE | — | craps06_2, crew06_8 | PM:Codex/sub:1 | 2026-08-14 | 2026-08-16 | PM verified full rules/chips/save/cheat scope, million-roll RTP, exact-tree full matrix, 10-seed determinism, and focused/canonical visual QA PASS. |
| craps06_2 | `../todone/craps06_2_street_craps_prompt.md` | DONE | craps06_1, env06_1 | — | PM:Codex/sub:5 | 2026-08-14 | 2026-08-16 | PM verified shared rules, cash-only teaching/dispersal/training, save/UI, RTP parity, exact-tree full matrix, determinism, and focused/canonical visual QA PASS. |
| push06_1 | `../todone/push06_1_pusher_core_prompt.md` | DONE | env06_1 | push06_2 | PM:Codex/sub:2 | 2026-08-14 | 2026-08-16 | PM verified action-boundary pile/nudge/alarm/persistence/economy, exact-tree full matrix, determinism, and focused/canonical visual QA PASS; simulation model is superseded by rework06_2. |
| push06_2 | `../todone/push06_2_pusher_variations_prompt.md` | DONE | push06_1, town06_1 | — | PM:Codex/sub:6 | 2026-08-14 | 2026-08-16 | PM verified Ridge/Vault mechanics, persistence, seeded reachability, EV, exact-tree full matrix, determinism, and visual QA PASS; simulation model is superseded by rework06_2. |
| streets06_1 | `../todone/streets06_1_streets_framework_prompt.md` | DONE | town06_1, crew06_1 | crew06_3/6/8 | PM:Codex/sub:3 | 2026-08-14 | 2026-08-14 | PM verified scope/design, systems/UI, 10-seed determinism, and package/multi-stop/Hold visual QA on the integrated tree. |
| crew06_2 | `../todone/crew06_2_backroom_poker_prompt.md` | DONE | crew06_1, env06_4 | crew06_9 | PM:Codex/sub:4 | 2026-08-14 | 2026-08-16 | PM verified deterministic policies, hidden tells, showdown-gated learning, trust/caps/save, exact-tree full matrix, determinism, and focused/canonical visual QA PASS. |
| crew06_3 | `../todone/crew06_3_numbers_prompt.md` | DONE | crew06_1, streets06_1, town06_2 | crew06_9 (grievance src) | PM:Codex/sub:7 | 2026-08-14 | 2026-08-16 | PM verified slips/routes/fix/past-post/leak/economy, exact-tree full matrix, determinism, and 12/12 Numbers visual coverage PASS; rework06_1 must re-point delivery consumers onto the real-map API before Wave D. |

### Reworks — owner-rejected systems (round-5, 2026-08-14)

Two Wave C deliverables were built to spec, played, and **rejected on
design grounds**. The specs were wrong, not the execution: both
prompts told the agents to abstract away the thing that makes the
system good. The roadmap sections are rewritten; these rows replace
the implementations. Wave C cannot close until both are DONE.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| rework06_1 | `../todone/rework06_1_map_delivery_prompt.md` | DONE | town06_1/2/3, crew06_1 (all DONE) | crew06_3 re-point, crew06_6, crew06_8 | PM:Codex/sub:8 | 2026-08-16 | 2026-08-16 | PM verified synthetic-board deletion, real-node targets and ordinary-travel routing, all four modes, Numbers re-pointing, migration, exact crew-favor behavior, full 235-stage matrix, 10-seed determinism, and zero-warning visual QA. |
| rework06_2 | `../todone/rework06_2_coin_pusher_simulation_prompt.md` | DONE | env06_1, town06_1 (DONE) | Wave C closure, pusher06_2/3/4 | PM:Codex/sub:9 | 2026-08-16 | 2026-08-17 | PM verified the 60 Hz fixed-point discrete-body solver, physical variation mechanics, persistence, exact Windows/Web replay parity, 10-seed determinism, EV, all six feel captures, zero-warning visual QA, and shipped-cap performance. All systems assertions were green; same-load baseline-equivalent wrapper timing was accepted per the owner rule. |

### Coin pusher depth (staged; continues AFTER rework06_2 is accepted)

Design contract: `docs/plans/0.6_coin_pusher_simulation_plan.md`.
Written in answer to the owner's question about a full physics/3D
rebuild. **Read that plan's "Status correction" section first:**
`rework06_2` already delivers the solver, so `pusher06_0` and
`pusher06_1` are largely absorbed and must not be re-run against
existing work. Verify by code, claim only what is genuinely missing.

The plan's headline judgment for the owner: a 3D rebuild is a
project-level commitment (this repo has zero `Node3D`, zero 3D
assets, and a `mobile`/`gl_compatibility` renderer) and is **not**
what produces the feel — authoritative simulation plus layered audio
is. The snapshot boundary (`body_views`) keeps 3D available later as
a *rendering* project rather than a gameplay rewrite.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pusher06_2 | `../todone/pusher06_2_presentation_audio_prompt.md` | DONE | rework06_2 accepted | pusher06_3 | PM:Codex/sub:pusher-depth | 2026-08-17 | 2026-08-17 | PM verified the 160/150 dense snapshot-authoritative render/audio pass, unchanged deterministic outcomes, sub-16 ms shipped-cap actions, exact 200-action Windows/Web native parity, clean exports, seven player-readable feel captures, and the complete green prompt gate matrix. |

### Concurrent track — parallel-safe, no dependency on the pusher or crew waves

These were scoped specifically to run alongside the coin pusher and
Wave D/E work without contention. **File ownership is binding and
stated in each prompt** — `events.json` in particular is shared, and
`env06_5` may only add `scenario_`-prefixed events.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| teach06_1 | `../todone/teach06_1_onboarding_prompt.md` | DONE | — (owns `data/tutorial/lessons.json` + coach) | playtest quality | PM:Codex/sub:teach-audit | 2026-08-16 | 2026-08-16 | Seven once-only public-surface lessons; final double-notify, non-consuming handoff, clickable pointer-safe placement, guided-prefix, secrecy, UI, determinism, and 75-state visual acceptance pass. |
| env06_5 | `../todone/env06_5_scenario_backlog_prompt.md` | DONE | env06_1/2/3 (DONE) | playtest variety | PM:Codex/sub:env-audit | 2026-08-16 | 2026-08-17 | All 13 complete backlog scenarios accepted: exact 55-scenario catalog, 13 scenario-owned events, 20-seed full/launch reach, phases/save-load/layer/tutorial checks, systems/UI assertions, determinism, three-venue smoke, and zero-warning visual QA. |
| fix06_2 | `../todone/fix06_2_street_craps_activation_mutation_prompt.md` | DONE | — (defect in landed craps06_2) | env06_5 acceptance | PM:Codex/sub:activation-guard | 2026-08-17 | 2026-08-17 | PM verified the generic observational activation repair across Street/Grand Craps, all generated games and seven passive hooks, portable tickets/autosave/staffing, and cold saved-Slot checkpoints; focused suites plus clean Systems/UI/determinism/75-state visual gates all PASS without waivers. |


### Coin pusher V3 — The Real Machine (owner round-6 design, 2026-08-17)

Binding design contract: `docs/plans/coin_pusher_v3_machine_rework_plan.md`.
The owner reviewed V2 in play and in a direct design session rejected the
MACHINE MODEL (turn-based batches, twin blade shelves, lane grid,
timing-as-scalar, contact-solver lattice/energy defects, replay-trace
presentation, console UI). The contract specifies the replacement machine
completely — one reciprocating platform with riding coins and ratchet
transport, landing-position skill, free skill stop, continuous operation,
physical tray with collection, settled-state-only persistence, per-machine
data-driven apparatus and geometry, full alive cabinet at slot parity.
Workers implement the contract; they do not redesign it. Strictly serial:
each stage builds on the last.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pusherv3_1 | `../todone/pusherv3_1_physics_machine_prompt.md` | DONE | rework06_2 (landed) | pusherv3_2 | PM:Codex | 2026-08-17 | 2026-08-17 | Owner ruled complete after PM verification of Amendment 6.1 behavior, native 300-body performance, exact Windows/Web parity, determinism, and all pusher-owning gates; integrated at `a6e36d2f`. |
| pusherv3_2 | `../todone/pusherv3_2_live_loop_prompt.md` | DONE | pusherv3_1 | pusherv3_3 | PM:Codex/sub:pusher-live | 2026-08-17 | 2026-08-18 | PM verified continuous 60 Hz loop, deterministic trace, tray-only collection, compact persistence/migration, motor-on exit settle, continuous rail drag, exact Windows/Web parity, performance, and all combined gates. |
| pusherv3_3 | `../todone/pusherv3_3_cabinet_prompt.md` | DONE | pusherv3_2 | pusherv3_4 | PM:Codex/sub:pusher-cabinet | 2026-08-18 | 2026-08-18 | PM verified the data-driven slot-parity cabinet, batched stacked projection, physical audio map, integrated 9/9 feel contract, determinism, visual QA, and all combined suites/performance budgets. |
| pusherv3_4 | `../todone/pusherv3_4_variations_integration_prompt.md` | DONE | pusherv3_3 | coin pusher closure | Codex | 2026-08-18 | 2026-08-24 | Verified variation/integration closure plus real-weight deterministic gravity/impact thuds and a playfield-dominant cabinet; full suites, performance, visual/capture, exact Windows/Web parity, determinism, and 200k-per-machine EV gates pass. |
| pusherv3_5 | `../todone/pusherv3_5_contact_piles_and_visible_exits_prompt.md` | DONE | pusherv3_4 | physical pile/contact/exit correction | Codex | 2026-08-25 | 2026-08-25 | Irregular carried piles, contact-only local pressure, contact-matched rendering, and visible shelf-to-tray/gutter falls pass exact native/Web parity, full regression, visual, performance, determinism, and 200k-per-machine EV gates. |
| pusherv3_6 | `../todone/pusherv3_6_plinko_bounce_and_entry_boards_prompt.md` | DONE | pusherv3_5 | plinko bounce/contact/layout correction | Codex | 2026-08-25 | 2026-08-25 | Contact-lifecycle audio gating, visible radial rebounds, unbiased release-angle variance, and distinct 7/7/10-pin entry boards pass exact parity, focused/full regression, visual, determinism, EV, and direct performance gates. |
| pusherv3_7 | `../todone/pusherv3_7_played_in_opening_stock_prompt.md` | DONE | pusherv3_6 | played-in opening stock and bounded early payouts | Codex | 2026-08-25 | 2026-08-25 | Deterministic 54/54/56-coin played-in beds, supported feature pieces, and bounded first-five-play payouts pass exact parity, full regression, visual, determinism, EV, and direct performance gates. |
| pusherv3_8 | `../todone/pusherv3_8_coin_scale_lower_bed_and_edge_ramp_prompt.md` | DONE | pusherv3_7 | prior coin scale, extended lower bed, physical payout ramp | Codex | 2026-08-25 | 2026-08-25 | Original 40x32 flat coin artwork, smaller matching physics, extended lower bed, researched edge ramp, played-in stock, exact parity/determinism, visual, performance, and 200k-per-machine EV gates pass. |
| pusherv3_9 | `../todone/pusherv3_9_contact_bed_and_opaque_edge_prompt.md` | DONE | pusherv3_8 | touching opening bed and solid payout-edge occlusion | Codex | 2026-08-25 | 2026-08-25 | All opening stock belongs to real contact clusters; a shallow physical incline and opaque foreground apron now hold and occlude the edge prime until coins visibly clear the shelf. Focused/full regression, parity, determinism, visual, performance, and 200k-per-machine EV gates pass. |
| pusherv3_10 | `../todone/pusherv3_10_opening_plinko_nozzles_and_stack_physics_prompt.md` | DONE | pusherv3_9 | full-width settled openings, full Plinko subsystem, nozzle queues, clarified stack physics | Codex | 2026-08-25 | 2026-08-25 | Quiet full-width openings, five-position dense-Plinko traversal metrics, rare reachable Ridge/Vault cups, same-nozzle bounded chains, tap/hold FIFO nozzles, unilateral carried stack supports, exact native/Web parity, actual-GL QA, and native performance pass. |

### Owner-requested depth rework — living games and real environment sequences (2026-08-25)

The shipped Craps, back-room poker, and Tonight variants satisfy their original
contracts but do not yet satisfy the owner's experiential bar. In particular,
scenario overlays mostly alter data/presentation and resolve a one-shot event;
they do not reliably transform the room or give the player a unique multi-step
task. These rows supersede no stable ids or verified rules. They deepen the
runtime and convert every existing variation. Completion is all-or-nothing at
`depth06_1`.

Parallel execution launcher:
`docs/todo/depth06_0_parallel_orchestration_prompt.md`. Give that prompt to one
primary integrator; it requires isolated worktrees, sub-agent implementation
and review, preserved logical commits, staged merges, and final exact-tree
acceptance. It is an orchestration prompt, not an additional completion row.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| env06_6 | `env06_6_dynamic_scenario_runtime_prompt.md` | IN_PROGRESS — PIECE 1 ACCEPTED / LANDING HELD ON PERF-RED MAIN | env06_1/2/3/5 (DONE); Smoke-green main | env06_6b | PM:Codex/sub:runtime-owner; dedicated Integrator | 2026-08-25 | — | Piece 1 accepted exact `855a2961`, priority ahead of env06_7. Hash correction landed at main `a62f4884`, but exact post-land Smoke is red only in `foundation_performance_probe`; do not merge env until main is green. Branch implementation remains active. |
| env06_6b | `env06_6_dynamic_scenario_runtime_prompt.md` (remaining-runtime follow-on) | TODO — PRIORITY 1 AFTER PIECE 1 | env06_6 landed on Smoke-green main | env06_7, craps06_3, crew06_10, world06_1 landing | parallel former-PM runtime lane; dedicated Integrator | — | — | Exactly the remaining 11 commits after `855a2961`, reopened against then-current main. Must close lifecycle transaction atomicity and sealed-catalog alias resolution plus every genuine red-gate failure; no hardening, sealing expansion, or improvements. Schedule immediately after piece 1 and do not let this known-gap interval linger. |
| env06_7 | `env06_7_all_variations_sequence_rework_prompt.md` | IN_PROGRESS — C SECOND-REJECTED / OWNER DECISION; E ACTIVE | accepted env06_6b plus ordered real catalog authority for landing | depth06_1 | Squads A-E + ordered assembly; all branches preserved | 2026-08-27 | — | A product `db8abbd1` and D product `8c2fc885` remain handed off and dependency-held. C exact product `cb684cc2`/handoff `4aee8b9c` is frozen after SECOND rejection: decisions remain commands on one generic task rather than distinct spaces/routes; aftermaths remain generic; proof does not establish complete snapshots, hidden-state parity, production composition, injection matrix, input traversal, performance, or actual raster evidence. No third ordinary cycle. Owner must choose same-scope spatial redesign with exceptional re-review, explicit contract/package-boundary reshape, or content closure/cut. E remains active; B waits on real ordered assembly authority. A→B→C order unchanged. |
| craps06_3 | `craps06_3_craps_depth_rework_prompt.md` | BLOCKED — CORE SECOND REJECTION / OWNER DECISION; ENV FIRST REMEDIATION | craps06_1/2; env06_6b for landing; owner-frozen game ritual contract | depth06_1 | frozen core squad + `codex/craps06_3-env-integration`; dedicated Integrator | 2026-08-27 | — | Core exact `e8cc589e`/handoff `8ad3dd11` frozen after SECOND rejection; no third ordinary cycle. P1: real UI still returns to `aiming_throw` and skips offered phase for non-pointer modes; five sequences remain unconsumed declarations; dense capture truncates 8 bets to 5 and omits complete accounting. P2: manifest still assigns implementation to Integrator and Web parity is absent. Owner must choose same-scope completion with exceptional review, explicit row/contract split retaining the improved tactile slice while naming all open successor scope, or requirement reduction/cut. Env `37353057` continues its separate first-remediation cycle only. |
| crew06_10 | `crew06_10_backroom_poker_depth_rework_prompt.md` | IN_PROGRESS — WIP PARKED FOR GAME ROTATION | crew06_2/5/6/9; env06_6b for landing; owner-frozen game ritual contract | depth06_1 | Squad CREW06_10 — `codex/crew06_10-impl` | 2026-08-27 | — | Clean UNREVIEWED `678c3e27`; focused depth PASS (10 seeds/5 profiles/conservation/receipts/interruption/save), validation 66.046s PASS, load 30.437s PASS. Legacy crew timing fixed; remaining crew suite red is inherited env route/lifecycle. Slot rotated to game06_1. |
| depth06_1 | `depth06_1_games_and_scenarios_release_gate_prompt.md` | TODO | env06_7, craps06_3, crew06_10 | depth-program closure | — | — | — | Independent exact-tree audit; cannot pass with an omitted/reward-only variation or static-panel game experience. |

### Wave D — Crew depth

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| crew06_5 | `../todone/crew06_5_recruitment_prompt.md` | DONE | crew06_1, env06_2, env06_3 | crew06_6/7/8 | PM:Codex/sub:crew-recruitment | 2026-08-17 | 2026-08-17 | PM verified all seven primary/fallback recruitment paths, diegetic signposting, rank services, seeded presence, save/ignored-run compatibility, lender behavior, authored voices, and clean Contract/Systems/UI/determinism/75-state visual gates. |
| crew06_6 | `../todone/crew06_6_layer3_jobs_prompt.md` | DONE | crew06_1, env06_4, streets06_1, crew06_5 | crew06_8 | PM:Codex/sub:crew-jobs | 2026-08-17 | 2026-08-17 | PM verified furnished L3, seeded residency, 12 launch jobs across five kinds/all seven members, services, shared Practice Rig progress, save compatibility, and combined Contracts/Systems/UI/determinism/visual gates PASS. |
| crew06_7 | `../todone/crew06_7_coordinated_plays_prompt.md` | DONE | crew06_1, crew06_5 | crew06_8 | PM:Codex/sub:crew-plays | 2026-08-17 | 2026-08-17 | PM verified five explicit coordinated plays, context/presence/rank gates, bounded windows/costs/detection, game seams, save compatibility, sustained heat pressure, and combined release gates PASS. |
| crew06_8 | `../todone/crew06_8_heist_prompt.md` | DONE | crew06_5/6/7, craps06_1, streets06_1, env06_3 | crew06_9 | PM:Codex/sub:crew-heist | 2026-08-17 | 2026-08-18 | PM verified both production heist plans, real delivery/save-load, outcome and abort boundaries, exact shipped-route seams, and final combined gates. |
| crew06_9 | `../todone/crew06_9_the_turn_prompt.md` | DONE | crew06_8, crew06_2, town06_2, crew06_3 | release06_1 | PM:Codex/sub:crew-turn | 2026-08-18 | 2026-08-18 | PM verified seeded grievance-weighted resolution, honest hidden clues, confrontation/hedge outcomes, both mechanical failure beats, opaque save/privacy discipline, compatibility, and all combined gates. |

### Wave E — Narrative + playtest handoff

**This wave does NOT ship anything.** Its terminus is a stable,
complete-enough build handed to the owner for extensive playtest.
0.6 is expected to be roughly 50% done at that moment; the polish and
cleanup pass that follows the owner's playtest is the second half of
the release, and it is where release activity finally happens.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| chain06_1 | `../todone/chain06_1_character_chains_prompt.md` | DONE | town06_2, env06_2, env06_3 | playtest06_1 | PM:Codex/sub:character-chains | 2026-08-17 | 2026-08-17 | PM verified six chains/21 beats, all three Cass endings, deterministic anchors, prefix safety, bounded effects, actionable icon projection, save compatibility, and combined release gates PASS. |
| content06_1 | `../todone/content06_1_items_events_expansion_prompt.md` | DONE | env06_2, env06_3, crew06_6 | playtest06_1 | PM:Codex/sub:content-depth | 2026-08-17 | 2026-08-18 | Owner selected within-run-only souvenir presentation; PM verified all compatible content, real consumers, economy-audit restraint, and combined gates. |
| playtest06_1 | `playtest06_1_playtest_readiness_prompt.md` | TODO | ALL other rows DONE (except parked) | owner playtest | | | | Verification, playability sweep, honest handoff report, local build. No version bump, no tag, no packaging, no publish, no final balance tuning. |

### Parked until after the owner's playtest

These are polish-wave tasks. They are deliberately NOT claimable now:
their inputs are the strings, numbers, and direction decisions that
the owner's playtest is expected to change.

| ID | Prompt | Status | Depends on | Notes |
| --- | --- | --- | --- | --- |
| voice06_1 | `voice06_1_voice_pass_prompt.md` | PARKED | post-playtest final content | A full register pass must read final strings. Running it before the playtest burns effort on copy that is about to be rewritten. |
| release06_1 | `release06_1_ship_prompt.md` | PARKED | post-polish | The only task that performs release activity (version, balance, packaging, tag, publish, owner gates). Unpark when the owner declares the polish pass complete. |

### Defects (owner-reported / PM-found; claimable like any row)

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fix06_7 | `../todone/fix06_7_coin_pusher_v3_intro_copy_prompt.md` | DONE | V3 machine contract landed | accurate Coin Pusher player-facing copy | `/root/program_row_inventory` | 2026-08-26 | 2026-08-26 | Independently accepted by `/root/fix07_final_review` at source `62dba2e3` and integration `bb3be7fd`, then landed at main `040f9fe2`. Recursive proof found exactly 36 authorized persisted-copy leaves and zero unauthorized changes; visual matrix passed 8/8 and focused Coin Pusher passed. Post-land Contract was functionally green but timing-only red at 258.562s, retained and routed to `fix06_5` with the cap unchanged. |
| fix06_1 | `../todone/fix06_1_dead_event_interactions_prompt.md` | DONE | env06_2, env06_3 (landed) | crew06_5+ inherit the class guard | Codex | 2026-08-14 | 2026-08-14 | Generic synthesized-speaker fix; 99-event audit shifted only 3 beach events; permanent generated-environment guard, systems/UI/all, determinism, and visual QA PASS. |
| fix06_3 | `scratch_ticket_art_alignment_rca_and_fix_prompt.md` | BLOCKED | — (analysed 2026-08-11, deferred from 0.5 to 0.6) | game06_5 inherits a clean surface | Codex | 2026-08-25 | — | Six-ticket alignment, exact v8→v9 partial-progress migration, regenerated overlays, and GPU visual capture are complete; Phase 5 is blocked on the owner's Crossword Corner art/mechanics choice. |
| fix06_5 | `../todone/fix06_5_contract_timing_measurement_prompt.md` | DONE | — | reliable Contract timing guard | PM:Codex/sub:fix05_measurement | 2026-08-26 | 2026-08-26 | INCONCLUSIVE result accepted at `c4e364f7`, staged at `87fa674e`, landed at main `4ade3ac3`, and post-land PASS by `/root/fix05_rereview`. Attempt 01 is noneligible and explicitly operator-observed/raw-unverifiable; attempts 02–05 were eligible timing-only reds at 252.197/247.542/240.187/245.767s with 16/16 checks green on `native_v3`. No five-eligible-run median, stale-baseline candidate, baseline/cap change or product/test/tool change exists. Raw evidence worktrees are retained. |
| fix06_6 | `../todone/fix06_6_delivery_full_state_golden_closure_prompt.md` | DONE | `fix06_4` landed | — | PM:Codex/sub:preflight_inventory | 2026-08-26 | 2026-08-26 | Documentation-only closure accepted by Feynman (`/root/fix06_collect_impl`) at `b323f841`, landed at `fe0c76d9`, and post-land accepted on the identical tree after static validation passed in 77.967s. Historical proof classified the two-hash red as authored Coin Pusher persisted-state fixture drift already remediated in accepted `fix06_4`; no code, test, golden, product, capture or runtime gate changed, and owner work remained untouched. |
| fix06_9 | `fix06_9_coin_pusher_web_performance_evidence_prompt.md` | PARKED | pusherv3_11 finding | fix06_13 | Codex | 2026-08-26 | — | Evidence path independently accepted at `f6a06d5f`, pre-land qualification PASS, and landed unchanged at main `112cb02d`. COLLECT and reduced motion reinstall exact 300-origin fixtures; console policy permits only the known autoplay warning and rejects hostile/unclassified warnings. The first actual shipped-Web red at `54e6398a` remains preserved, so this row is not DONE and its prompt is not archived; it awaits product-performance row `fix06_13`. No cap was changed and no result was hidden. |
| fix06_13 | `fix06_13_coin_pusher_shipped_web_performance_prompt.md` | PARKED | accepted fix06_9 evidence remediation | fix06_9, pusherv3_11 closure | `/root/fix06_13_web_perf` | 2026-08-27 | — | Off-main implementation `7ec148e4d9a6096627fa26e1afee508e5b1c0b25` and exact review/docs head `718af3da7176abfaec9f9dbc10884454298a9872` were independently accepted, but nothing from that branch is accepted on or transplanted to `main`. Its retained locked run at `c914546f` remained red. Dependencies `fix06_14` and `fix06_16` are now DONE on main at `616b5a76` / `53f6ed2d`; the lifecycle blocker is cleared and this row may now unpark. Next: semantic integration onto current main, current-main gates, fresh independent exact-head review, then exactly one new locked shipped-Web run. Every red and hash remains retained on `codex/land06-fix06_13` and under its ignored evidence paths. |
| fix06_14 | `fix06_14_coin_pusher_collect_reinstall_clock_evidence_prompt.md` | DONE | fix06_13 shipped-Web evidence | fix06_9 evidence closure | `/root/fix06_14_clock` | 2026-08-27 | 2026-08-27 | Landed by merge `616b5a76` with parents current main `7cd6a5cb` and accepted integration/docs `5917baf2`; owner WIP remained untouched. The first disposable-checkout post-land gate retained an environmental disk-full red after validation passed 51.033s: import failed in 43.037s with exit 127 and 74 stderr issues while D: had 270,336 bytes free. Evidence was moved before removing only the disposable worktree, restoring 1,054,285,824 bytes free. On the identical exact main and native DLL, the single corrected retry passed validation/import/load/focused Coin Pusher in 47.832/17.645/23.346/164.588s with zero failures. `fix06_14` is landed and post-land green; separately routed `fix06_16` is now DONE at `53f6ed2d`, so `fix06_13` may unpark to semantic current-main integration. |
| fix06_16 | `fix06_16_web_perf_server_orphan_cleanup_prompt.md` | DONE | fix06_14 exact-head qualification | fix06_13 unparked locked run | `/root/fix06_16_impl`; PM:Codex landing | 2026-08-27 | 2026-08-27 | `/root/fix06_16_review` ACCEPT `b38f3e35`; landed by merge `53f6ed2d` with parents `f0637b8c` / `b38f3e35`. Exact-main non-Web lifecycle and static validation passed; lifecycle stdout `A31FFEB9...2EDE82`, lifecycle stderr plus validation stdout/stderr all empty `E3B0C442...B855`; zero residual processes. All rejected heads/findings remain retained. No browser/Web timing/export ran. `fix06_13` may now unpark to semantic current-main integration. |

### Archived rows — superseded or false premise

These rows remain part of the execution record but are not live or claimable.
Nothing in this archive is deleted; the notes preserve why each row retired.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pusher06_0 | SUPERSEDED | OPTIONAL | rework06_2 accepted | — | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| pusher06_1 | SUPERSEDED | REFERENCE | rework06_2 accepted | — | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| pusher06_3 | SUPERSEDED | TODO | pusher06_2 | pusher06_4 | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| pusher06_4 | SUPERSEDED | TODO | pusher06_1/2/3 landed | coin pusher closure | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| art06_1 | `art06_1_punchline_layers_prompt.md` | CLOSED — FALSE PREMISE | env06_4 (DONE) | — | owner-side finding | 2026-08-16 | 2026-08-16 | **Stop work; do not build a renderer seam.** No environment renders from a raster — every venue is procedurally drawn via `pixel_scene_canvas.gd`'s `scene_type` dispatch, and `visual_context.asset_path` is metadata the canvas never consumes. `_draw_punchline_club()` and `_draw_punchline_back_room()` already exist, are dispatched, and are at detail parity with `_draw_bar`/`_draw_underground`. The objective was already met before the row was authored. New PNGs kept as metadata-only. |

### Family 1 — Game depth parity (owner scope decision, 2026-08-25)

The owner's depth standard applies to the whole game, not to craps, poker and
the coin pusher alone. `data/games/games.json` ships eleven games; eight of them
plus the Grand Casino duel still resolve as control panels. Launcher:
`game06_0_game_depth_orchestration_prompt.md` (PM copies it into one primary
integrator, which employs sub-agents). Program design:
`docs/plans/0.6_remaining_work_program.md`.

Shared-file hazard: `table_game_visuals.gd` and `game_surface_canvas.gd` serve
every table game. `game06_1` lands the ritual vocabulary once so the content
rows can run in parallel without colliding in both files.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| game06_1 | `game06_1_table_machine_ritual_runtime_prompt.md` | RE-REVIEW QUEUED — FIRST-REJECTION REMEDIATION | accepted frozen contract `a2760d81`; red main blocks landing only | game06_2..7 | Squad GAME06_1; dedicated Integrator | 2026-08-27 | — | Immutable clean remediation `932287ba`; frozen contract/fixtures/tool untouched. Full authenticated RitualCommand/fingerprint, closed result/rejection/fact/operation-result/receipt/cache records/taxonomy, per-handler op/fact allowlists with hostile cross-handler negatives, and authenticated closed restore hostile matrix implemented. Focused hostile closure, vocabulary 72/7, validation 51.1s, load 25.2s/250 scripts, and integrated surface contracts zero-failure PASS. Exact head queued for independent re-review. |
| game06_2 | `game06_2_blackjack_depth_prompt.md` | BLOCKED — CLEAN PARK BEHIND REJECTED RUNTIME | accepted game06_1 product successor | game06_7 | Squad BLACKJACK; `codex/game06_2-impl` | 2026-08-27 | — | Clean `UNREVIEWED-BLOCKED` head `2def171d`, based on rejected `44fefe5f`; one row-local `blackjack.gd` ritual-projection slice only. No further build or gates after the runtime rejection. Squad rotated back to game06_1 remediation. |
| game06_3 | `game06_3_baccarat_roulette_depth_prompt.md` | IN_PROGRESS — ROULETTE WIP GREEN / BACCARAT ACTIVE | accepted frozen contract `a2760d81`; accepted game06_1 product successor for integration | depth parity | Squad BACCARAT-ROULETTE; `codex/game06_3-impl` | 2026-08-27 | — | Clean UNREVIEWED `c0d2b75e`, based directly on frozen contract `a2760d81`; rejected runtime absent from ancestry. Roulette depth PASS: exact remove-one stack correction, pointer target and stake-down keyboard/controller binding, ritual/accounting/actor/object/energy projection and row-local manifest. Baccarat logical group active. |
| game06_4 | `game06_4_machine_games_depth_prompt.md` | TODO | game06_1 | depth parity | — | — | — | Cabinet, credits, handle, hand-pay. Per-frame deep copies forbidden — slot watchdog precedent. |
| game06_5 | `game06_5_counter_games_depth_prompt.md` | TODO | game06_1 | depth parity | — | — | — | Clerk, rack, counter transaction; preserves mask/foil/region renderers; disposes of the open art-alignment defect. |
| game06_6 | `game06_6_bar_dice_depth_prompt.md` | TODO | game06_1, craps06_3 | depth parity | — | — | — | Street register game; reuses craps06_2 dispersal/teaching seams. |
| game06_7 | `game06_7_showdown_duel_depth_prompt.md` | TODO | game06_1, game06_2 | depth parity | — | — | — | Rourke duel staging; both endings; outcome ladder preserved exactly. |
| game06_8 | `game06_8_games_depth_release_gate_prompt.md` | TODO | game06_2..7, depth06_1 | Family 1 closure | — | — | — | Independent exact-tree audit. Cannot pass with a control-panel game or a pointer-only verb. |

### Family 2 — Crew and world surface depth (owner scope decision, 2026-08-25)

The flagship pillar is still a text menu: streets, Numbers, jobs, plays, sweep
encounters, heist phases and the Turn all resolve through `EventModule` choice
actions while the environments around them become rooms. Launcher:
`world06_0_crew_world_depth_orchestration_prompt.md`.

Hidden-state discipline is absolute across this family. A Turn or heist leak is
an automatic P0 and blocks the program.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| world06_1 | `world06_1_crew_sequence_adapter_prompt.md` | BLOCKED — OPTION A EXACT-STATE OWNER DECISION / CLEAN PARK | sealed DeliveryRunModel checkpoint; env06_6b/green main only for landing | world06_2..6 | parallel former-PM lane; dedicated Integrator | 2026-08-27 | — | Clean test-only `UNREVIEWED-BLOCKED` WIP `9d6ff952` preserves authentic/transplant/fingerprint/owner/resolution/receipt/malformed/save-load/replay negative scaffolding with no production edit and no guessed timing. Legitimate mounted expiry/abandon cannot currently be represented: failure consequences set `world_applied=true` before the adapter emits the authoritative neutral receipt. Decide whether to authorize a non-persisting adapter receipt prepare/preview before owner apply, transfer neutral-receipt authority into the model with explicit contract/migration redesign, or retain ordering and park expiry/abandon unsupported. No workaround or boolean synthesis. |
| world06_2 | `world06_2_streets_sequences_prompt.md` | RE-REVIEW QUEUED — FIRST-REJECTION SUCCESSOR | world06_1 for receipt bridge/integration/landing | world06_6 | Codex/lane:world06_2; dedicated Integrator | 2026-08-27 | — | Rejected `b4b2f9f8` preserved; clean/frozen successor `e4f4194f` with proof `94e64cc3`. Delta is exactly delivery model + focused contract. It requires authoritative arrival/current-position/carried handoff without self-arrival; exact carried/stashed ditch and stash node+place found; sealed route/adjacency/node cover; closed authenticated chained receipts with conflict/forgery/malformed restore rejection. Hostile proof GREEN 0.4s (independent 0.366s), model check GREEN 0.5s, diff-check clean. Economy/RNG/tuning unchanged, no receipt bridge. Exact re-review queued; integration/landing stay held on world06_1. |
| world06_3 | `world06_3_numbers_depth_prompt.md` | TODO | world06_1, world06_2 | — | — | — | — | Book as a place, slips as objects, the draw as an occasion, both rig routes staged. |
| world06_4 | `world06_4_backroom_jobs_recruitment_prompt.md` | TODO | world06_1 | — | — | — | — | L3 occupancy, job board, all 13 jobs, seven recruitment encounters. `stake_horse` and `collection` need real sequences. |
| world06_5 | `world06_5_plays_and_sweep_encounters_prompt.md` | TODO | world06_1, game06_1 | — | — | — | — | Five plays as table presence; sweep encounters as street moments. Chip Dump funding = shipped model A. |
| world06_6 | `world06_6_heist_and_turn_staging_prompt.md` | TODO | world06_1, world06_2, crew06_10 | world06_7 | — | — | — | Both plans staged, both exits, the confrontation. Read the crew06_8 log entries before planning. |
| world06_7 | `world06_7_crew_world_depth_release_gate_prompt.md` | TODO | world06_2..6 | Family 2 closure | — | — | — | Independent audit; the hidden-information audit is the blocking one. |

### Family 3 — Cross-cutting completion (2026-08-25)

Work the board never covered: the update being visible between runs, the
combined economy, teaching what 0.6 became, the sound of the reworked surfaces,
whether a real 0.5 save survives all of 0.6 at once, whether it still runs on
Web and low-end, whether the playtest gate still describes the thing being
playtested, and what the second half of 0.6 is. Launcher:
`cross06_0_cross_cutting_orchestration_prompt.md`.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| meta06_1 | `../todone/meta06_1_career_run_report_surfacing_prompt.md` | DONE | — | — | prior implementer; `/root/landing_coordinator` | 2026-08-26 | 2026-08-27 | Accepted source `27dc4be0`; Review Pool accepted exact integration and main merge `12e127c9`. Contract 16/16 and Foundation all 24/24 were functionally green; timing-only wrapper reds were retained unchanged. UI reproduced the byte-identical inherited env06_6/P1 inactive-delivery digest red on clean parent `ff2d4e14`, proving no meta-caused digest change. |
| balance06_1 | `../todone/balance06_1_cross_system_economy_audit_prompt.md` | DONE | — | `balance06_1-follow-on` after Families 1/2 | PM:Codex/sub:cross-balance | 2026-08-25 | 2026-08-26 | Partial scope accepted and landed at `7c748f5b`: opt-in eight-playstyle harness, honest report and hash-manifested evidence archive; exact-tree Systems, smoke, determinism and full Smoke are green. Contract is functionally green but timing-red and routed to `fix06_5`. Full distributions, 600k pusher EV, findings and proposals remain the separately ordered follow-on. |
| board06_1 | `../todone/board06_1_board_hygiene_prompt.md` | DONE | — | — | PM:Codex/sub:board-hygiene | 2026-08-25 | 2026-08-26 | Board split landed at `70eaaf80`: 170/170 decisions and 124/124 historical work entries preserved, indexes/links verified, superseded rows archived, owner questions reconciled, and post-land native-backed Smoke PASS. |
| pusherv3_11 | `pusherv3_11_pusher_program_closure_audit_prompt.md` | BLOCKED | pusherv3_10; current-main fix06_13 closure; fix06_8 tooling proof | pusher closure | preserved audit branch; dedicated Integrator | 2026-08-27 | — | Claim-only `8541f643` remains rejected and IN PROGRESS; EV/determinism/parity/lifecycle/performance/broad-suite/visual evidence is pending. `fix06_13` remains off main and shipped-Web red. Owner resolved fix06_8 as tooling-only proof; no physics change is authorized. |
| fix06_8 | `fix06_8_coin_pusher_upper_row_join_evidence_prompt.md` | EVIDENCE COMPLETE — MOVEMENT NOT DEMONSTRATED | unchanged production pusher physics and geometry | fix06_24; pusherv3_11 | evidence `1f0595af`; standing evidence squad | 2026-08-27 | 2026-08-27 | Exactly one fixed production trace, no rerun/search: manifest SHA-256 `AFA40DF4…C1DF8`, native DLL `56B26FF9…165A`. Idle, baseline, twelve priming drops, tracked paid drop, support/ticks/phase/final-root and strip checks passed. Quarter/Ridge/Vault each had zero qualified adjacent pre-existing platform coin, so movement was not demonstrated. No physics change; classified and escalated separately as fix06_24. |
| fix06_21 | `fix06_21_main_smoke_hash_and_post_land_gate_prompt.md` | BLOCKED — LANDED / POST-LAND PERF RED / NOT DONE | owner-authorized stale-content proof | Smoke hash health; env06_6 landing after green main | correction source `e3f6e94a`; Integrator merge `a62f4884` | 2026-08-27 | — | Two-hash payload landed alone. Exact merge passes validation/import/load/foundation_smoke/UI/Dave/audio and is content-identical to source, but `foundation_performance_probe` is red. Per owner rule this row is landed but cannot be DONE against red main. Process correction split to fix06_22; performance health routed fix06_23. |
| fix06_22 | `fix06_22_fail_closed_post_land_verification_prompt.md` | ACCEPTED EXACT / LANDING HELD ON PERF-RED MAIN | exact current main `a62f4884`; fix06_23 green performance Smoke | reliable DONE eligibility | accepted `557af45b`; dedicated Integrator | 2026-08-27 | — | Integrator ACCEPT exact `557af45b`. Independent NoImport and byte-identical duplicate-path hostile runs exit1/eligible=false in 0.8s; canonical descriptor target/hash bound; validation PASS 50.7s; two tool files only. Landing waits on green main, then exact-current-main PostLand is mandatory before DONE. |
| fix06_23 | `fix06_23_main_performance_health_evidence_prompt.md` | BLOCKED — EXACT MAIN 3/3 RED / OWNER DECISION | exact main `a62f4884`; unchanged budgets/tests | Smoke-green main; env06_6 landing | evidence preserved by Integrator; next diagnosis squad | 2026-08-27 | — | Bounded exact-main series 3/3 red: run1 pusher drop frame/draw, skill-stop draw and completeness; run2 exit1 with retained stderr; run3 baccarat p95, pusher skill-stop synchronous and completeness. Earlier identical-tree greens prove volatility, not health. Decide whether to authorize unchanged-limit performance diagnosis/remediation, define a different binding host-eligibility policy, or keep main red; no budget/test/product change is presently authorized. |
| fix06_24 | `fix06_24_coin_pusher_adjacent_coin_movement_defect_prompt.md` | BLOCKED — PRODUCT-PHYSICS DEFECT / OWNER DECISION | exact fix06_8 evidence `1f0595af` | pusherv3_11 | evidence squad; owner authorization required | 2026-08-27 | — | Owner decision: authorize a separate product-physics remediation that makes a fixed production control/nozzle trace land with platform-rooted first support strictly adjacent to qualified pre-existing platform-rooted coin(s) and move those exact neighbors over a phase-matched full stroke; or explicitly revise/cut the Plan 9.4 upper-row-join requirement. No rerun/search or physics/geometry/nozzle/transport/contact/neighboring-stock change is authorized by this classification. |
| audio06_1 | `audio06_1_surface_sfx_pass_prompt.md` | TODO | Families 1 and 2 rituals landed | — | — | — | — | The SFX manifest holds one profile (the pusher). Music stays external; this row writes the handoff delta. |
| integ06_1 | `integ06_1_composition_migration_soak_prompt.md` | TODO | Families 1 and 2 merged | playtest06_2 | — | — | — | 0.5→0.6 migration matrix, maximal-node composition, full-run soaks on both platforms. |
| perf06_1 | `perf06_1_performance_platform_pass_prompt.md` | TODO | Families 1 and 2 merged | playtest06_2 | — | — | — | First project-wide pass since the pusher physics and the scenario runtime. Idle 0.000 without a liveness counter is a failure. |
| teach06_2 | `teach06_2_teaching_pass_two_prompt.md` | TODO | depth06_1, game06_8, world06_7 | — | — | — | — | Audit all 63 lessons for staleness, then teach the systems that have none. |
| playtest06_2 | `playtest06_2_playtest_gate_refresh_prompt.md` | TODO | integ06_1, perf06_1 | owner playtest | — | — | — | Amends `playtest06_1` in place: real dependency list, named seeds, playtest script, finding-capture format. |
| polish06_0 | `../todone/polish06_0_post_playtest_program_prompt.md` | DONE | — | the parked second half | PM:Codex/sub:polish-program | 2026-08-26 | 2026-08-26 | Planning program landed at `cabf2fea` with 11 source-identical documents and full native-backed Smoke PASS. Every output remains PARKED and non-claimable until the owner explicitly opens the polish pass; no polish or release activity was performed. |

### The owner playtest is the terminus of this board

Superseded plan note: the playtest was originally a mid-wave
checkpoint before shipping. It is now the **end state of the entire
board** (owner decision 2026-08-14). Agent work stops when
`playtest06_1` hands off.

What happens then is the owner's, not an agent's:

- The owner plays extensively and forms their own judgment on feel,
  balance, direction, and what went askew during development.
- Their findings become `fix06_*` rows and, where the design itself
  changes, **owner decisions recorded in the roadmap** — an agent
  never redirects locked design on its own reading of a playtest note.
- The polish and cleanup pass that follows is the second half of 0.6.
  `voice06_1` and `release06_1` unpark there, in that order.

## Owner Questions (current verdicts; do not guess)

- **fix06_3 — Crossword Corner art/mechanics reconciliation: OPEN
  (2026-08-25).** Choose whether to (a) keep the shipped printed art and rebuild
  the mechanical puzzle/word list to match it, with an RTP re-check; (b) keep
  the shipped mechanics and repaint only the Crossword Corner background at the
  quality of the other six tickets; or (c) ship the other six aligned and hold
  Crossword Corner. Codex recommends **(b)** because it preserves the authored
  odds, payouts, and puzzle behavior and confines the remaining work to the one
  asset whose printed geometry/content is inconsistent.

- **pusherv3_10 — stacked support sentence and Plinko cup lifecycle: ANSWERED
  (2026-08-25).** Only the pushing ledge supplies horizontal push force; a coin
  landing across supports never spreads them, but it remains carried by their
  motion. Supported landings are bad drops with negative audio; bed-level
  landings receive a positive ding. Cups consume their triggering coin, and
  multiplier cups enqueue children from that coin's source nozzle. Hard-to-reach
  placement and bounded reproduction must protect flow and ROI.

- **pusherv3_4 — Jackpot Ridge lock puck target: ANSWERED (2026-08-18).** The superseded variation
  design says a lock puck will “freeze a shelf one cycle.” The binding V3
  machine explicitly removes the two-shelf model and has one continuously
  reciprocating platform; V3 preserves Ridge multiplier/lock/jam logic but
  redefines only jams and Ridge Run, leaving the lock target undefined. What
  should a physically banked lock puck lock for one cycle on the V3 machine?
  Owner ruling: a banked lock puck preserves the currently armed multiplier
  against expiry for one full 240-tick stroke. It never stops or steers the
  physical motor/platform.

- **pusherv3_4 — Vault Drop physical EV band: ANSWERED (2026-08-18).** Stage 4 requires a physical
  >=200k-drop harness for every machine and permits geometry/apparatus tuning
  only into each documented band. Quarter Falls documents `[0.72, 0.94]` and
  Jackpot Ridge `[0.70, 1.08]`; Vault Drop documents only the separate
  meter-dependent vault-cell option values and has no physical coin-drop EV
  target. What physical coin-drop EV band should the Vault machine use? The
  harness must report tray return separately from vault-round option value, so
  the cell table is not a substitute target. Owner ruling: `[0.72, 0.94]` for
  physical coin-to-tray EV, reported separately from vault option value.

- **content06_1 — souvenir collections persistence: ANSWERED (2026-08-18).** The prompt asks for
  scenario souvenirs to receive collections-shelf integration, but roadmap
  owner decision #1 makes the Players Card the only cross-run system in 0.6.
  The shipped `data/collections/collections.json` is explicitly meta/cross-run
  and its generic contracts fix two collections with 14-item tiers. Should
  souvenir “collections integration” mean only the within-run inventory/item
  shelf and sale surfaces, or is an explicit roadmap amendment authorizing new
  cross-run souvenir collection progress intended? Owner ruling: within-run
  inventory/item shelf and sale presentation only; no new cross-run souvenir
  progress in 0.6.

- **pusherv3_1 — platform stroke orientation: ANSWERED (Amendment 6.1,
  2026-08-17).** Ruling: keep the axis (+y = rearward) and all coordinate
  conventions; the LABELS were wrong. The contract is amended — constants
  renamed to `FACE_EXTENDED_Y` / `FACE_RETRACTED_Y` to kill the ambiguity
  permanently, and re-derived: extended 28000, retracted 46000, plate moved to
  63000. The relabel exposed a second latent flaw: with the plate at 52000 and
  retraction at 48000 the platform top held only 4000 units (< 1 coin), so the
  entire top stock would deposit every cycle, violating the owner's
  persistent-riding-coins requirement. New numbers give ~2 rows always riding,
  ~1 queued row per deposit, an ~20% apex-dwell deck-landing window, and a
  full-height face collider so nothing slips beneath the pusher. Sections
  3.1-3.4 of the contract are the corrected binding versions. Do not derive
  from any earlier copy. Amendment 6.2 later supersedes only the deck-landing
  window: entries are now rear-fed onto the upper platform at every phase.

- **crew06_7 — Chip Dump funding authority: ANSWERED BY IMPLEMENTATION
  (2026-08-26).** Shipped `data/crew/plays.json` unambiguously implements model
  A: the `chip_dump` play moves 40 of the player's cash to chips, charges a fee
  of 6, and declares direction `cash_to_chips`. Its authored intent says
  detection preserves laundering risk and never creates value. No separate
  owner ruling or data change is required.

## Logs and history

The board protocol and live task state stay in this file. Historical logs
are split into dated companions so agents can locate a row without loading
the entire execution history:

- [Discovery & Decision Log - through 2026-08-26](README_0_6_discovery_decision_log_2026-08-26.md)
- [Work Log - through 2026-08-26](README_0_6_work_log_2026-08-26.md)

Every agent must still read this board and its binding protocol in full.
Append scope discoveries and decisions to the discovery companion, and
append claim/block/completion/unblock entries to the work companion.
