# 0.6 Active Task Board — The Living Town & The Crew

Created: 2026-08-13 · Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` (v4, owner-approved).
This board is the **single source of truth for 0.6 execution state**.
The roadmap is the single source of truth for **design intent**. When
code reality disagrees with either, code reality wins — record the
disagreement in the linked Discovery & Decision Log companion.

## Current-state audit — 2026-09-02

The final closeout began from GitHub `main` at
`a89bc6f76ccf4d10286029fbeaf41cd91220009c`. Coin Pusher's final
implementation commit `6af645b56108a758df2cb0264bbbb10ecd3b624e` passes the locked
fresh-export Web run, native live-batch parity, Windows/Web input parity,
focused foundation contract, cache equivalence, and project validation. The
closeout commits are now part of remote `main`; `fix06_13` and `pusherv3_11`
are archived as `DONE`, and only human playtest remains for the Coin Pusher
program.

Use these distinctions when choosing work:

- `DONE` means the prompt is accepted, archived under `docs/todone/`, and its
  required implementation/evidence is present on remote `main`. A pushed branch
  is still `IN_PROGRESS`; branch existence is never completion evidence.
- `IN_PROGRESS` may now mean implementation is already on `main` but the
  prompt's independent acceptance/closeout is still missing. Do not rebuild
  those rows; audit and close what landed.
- `TODO` with prestage means documentation or harness preparation landed, not
  that the actual row ran.
- `PARKED` remains intentionally unavailable until its named owner/playtest
  dependency opens it.

The complete file-by-file reconciliation and recommended execution order are
in `docs/plans/0.6_todo_state_audit_2026-08-31.md`.

Family 2 is now closed on the exact-tree remediation
`57b01ed40cf9fdabf2de016d9df6ef2e8db42019`. The release-gate report is
`docs/plans/world06_7_final_closeout.md`; all seven `world06_*` prompts are
archived. Hidden Crew state is sealed in an always-present fixed-width capsule,
all focused world contracts and project validation are green, and independent
detached security review passed. Human experience validation remains in the
later program playtest rather than as unfinished Family 2 implementation.

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
| pusherv3_10 | `../todone/pusherv3_10_opening_plinko_nozzles_and_stack_physics_prompt.md` | DONE | pusherv3_9 | complete three-cabinet Coin Pusher experience | Codex | 2026-08-25 | 2026-09-01 | Recovered and finalized: shuffled full-width settled openings, two bonus-token cups per cabinet, persistent weighted-object goals/restocking, repeatable Vault cycles, exact native/Web parity, actual-GL visual QA, and a green 600k-drop economy audit. |

### Owner-requested depth rework — living games and real environment sequences (2026-08-25)

The original depth audit found that shipped Craps, back-room poker, and Tonight
variants did not satisfy the owner's experiential bar. Recovered implementations
now deepen those surfaces on `main`, but completion remains all-or-nothing at
`depth06_1`; the audit must judge the current result rather than repeat the old
implementation plan.

Parallel execution launcher:
`docs/todone/depth06_0_parallel_orchestration_prompt.md`. That historical
launcher has completed its recovery/landing role; do not relaunch it. The
remaining work is acceptance and closeout of the landed tree.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| env06_6 | `../todone/env06_6_dynamic_scenario_runtime_prompt.md` | DONE | env06_1/2/3/5 (DONE) | env06_7, craps06_3, crew06_10 | recovery landing; Codex | 2026-08-25 | 2026-08-31 | Recovered runtime and post-land work accepted: full hostile contract and project validation green; exact two-native/two-Web semantic parity at SHA `bc70e7d…`; locked timing budgets met; determinism, audit, and visual evidence reconciled. |
| env06_7 | `../todone/env06_7_all_variations_sequence_rework_prompt.md` | DONE | env06_6 | depth06_1 | recovery landing; Codex | 2026-08-28 | 2026-08-31 | Recovered A-E rollout accepted without rebuilding: 55 scenarios, 1,485 pairs with zero failures and 27 approved warnings, 683 captures, 14 contact sheets, and the 55-row audit complete. |
| craps06_3 | `../todone/craps06_3_craps_depth_rework_prompt.md` | DONE | craps06_1/2, env06_6 | depth06_1 | recovery landing; Codex closeout | 2026-08-28 | 2026-09-03 | Recovered `7d230a63` depth accepted without rebuilding: five casino/street profiles, tactile phases, bet correction, committed environment responses, million-decision RTP/fairness, focused Foundation, hostile authority, actual-GL visual/liveness/reduced-motion, and 55-scenario audit pass. |
| crew06_10 | `../todone/crew06_10_backroom_poker_depth_rework_prompt.md` | DONE | crew06_2/5/6/9, env06_6 | depth06_1 | recovery landing; Codex closeout | 2026-08-28 | 2026-09-03 | Recovered `0d4529ac`/`040c0603`/`f1ebe9a7` without rebuilding: ordered betting, seven distinct policies, five production nights, hostile fail-closed authority, focused Foundation, actual-GL visual, and 55-scenario audits pass. Missing authentic host roots remain safely unavailable rather than caller-mintable. |
| depth06_1 | `../todone/depth06_1_games_and_scenarios_release_gate_prompt.md` | DONE | env06_7, craps06_3, crew06_10 | depth-program closure | recovery landing; Codex closeout | 2026-08-29 | 2026-09-03 | Independent current-tree audit accepted: all 55 ids/1,485 pairs, deterministic two-per-archetype sample, complete lifecycle/visual dossiers, tactile Craps, ordered Poker, two-pass 10-seed determinism, and depth-owned platform/performance evidence pass. Non-quiescent Coin-Pusher-only broad timing red is retained and routed outside this row. |

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
| env06_8 | `env06_8_environment_readability_and_object_presentation_prompt.md` | IN_PROGRESS | env06_6/7 (DONE) | playtest quality; world06_7 hidden-info audit | `/root` | 2026-09-03 | — | **Owner-reported playtest regression.** Scenario scene objects/actors have no `icon_key` and no case in either `foundation_main.gd` dispatch table, so they show empty panels and dead-end on "Inspect this first."; 768/1108 objects carry no `zone_id` so placement is fallback rather than composed; 355/673 actions have no handler, 1 `event_bridge`, 0 item grants, and transition prose is generated template text. Owner ruling: decorative objects stay and become **inspectable** flavor that shows what has been happening and hints at effect on the player. Review: `env06_8_review_prompt.md`. Supersedes `fix06_25`. Parallel-safe with the active closeouts; owns scenario data + `environment_interaction_controller.gd` only. |
| fix06_7 | `../todone/fix06_7_coin_pusher_v3_intro_copy_prompt.md` | DONE | V3 machine contract landed | accurate Coin Pusher player-facing copy | `/root/program_row_inventory` | 2026-08-26 | 2026-08-26 | Independently accepted by `/root/fix07_final_review` at source `62dba2e3` and integration `bb3be7fd`, then landed at main `040f9fe2`. Recursive proof found exactly 36 authorized persisted-copy leaves and zero unauthorized changes; visual matrix passed 8/8 and focused Coin Pusher passed. Post-land Contract was functionally green but timing-only red at 258.562s, retained and routed to `fix06_5` with the cap unchanged. |
| fix06_1 | `../todone/fix06_1_dead_event_interactions_prompt.md` | DONE | env06_2, env06_3 (landed) | crew06_5+ inherit the class guard | Codex | 2026-08-14 | 2026-08-14 | Generic synthesized-speaker fix; 99-event audit shifted only 3 beach events; permanent generated-environment guard, systems/UI/all, determinism, and visual QA PASS. |
| fix06_3 | `../todone/scratch_ticket_art_alignment_rca_and_fix_prompt.md` | DONE | — (analysed 2026-08-11, deferred from 0.5 to 0.6) | game06_5 inherits a clean surface | Codex | 2026-09-02 | 2026-09-02 | Owner chose a denser Crossword redesign. Seven-ticket alignment is complete on main `996a98b6`; Crossword has one connected seven-word/22-cell grid with eight intersections, active stock, v10→v11 migration, regenerated overlays, GPU three-state review, and green all-140 focused contracts. |
| fix06_5 | `../todone/fix06_5_contract_timing_measurement_prompt.md` | DONE | — | reliable Contract timing guard | PM:Codex/sub:fix05_measurement | 2026-08-26 | 2026-08-26 | INCONCLUSIVE result accepted at `c4e364f7`, staged at `87fa674e`, landed at main `4ade3ac3`, and post-land PASS by `/root/fix05_rereview`. Attempt 01 is noneligible and explicitly operator-observed/raw-unverifiable; attempts 02–05 were eligible timing-only reds at 252.197/247.542/240.187/245.767s with 16/16 checks green on `native_v3`. No five-eligible-run median, stale-baseline candidate, baseline/cap change or product/test/tool change exists. Raw evidence worktrees are retained. |
| fix06_6 | `../todone/fix06_6_delivery_full_state_golden_closure_prompt.md` | DONE | `fix06_4` landed | — | PM:Codex/sub:preflight_inventory | 2026-08-26 | 2026-08-26 | Documentation-only closure accepted by Feynman (`/root/fix06_collect_impl`) at `b323f841`, landed at `fe0c76d9`, and post-land accepted on the identical tree after static validation passed in 77.967s. Historical proof classified the two-hash red as authored Coin Pusher persisted-state fixture drift already remediated in accepted `fix06_4`; no code, test, golden, product, capture or runtime gate changed, and owner work remained untouched. |
| fix06_8 | `../todone/fix06_8_coin_pusher_upper_row_join_evidence_prompt.md` | DONE | owner option 1 fixed production trace | pusherv3_11 | Codex | 2026-09-01 | 2026-09-01 | Fixed production nozzle/control trace passes idle, paid-drop, platform-root, adjacency, named-neighbor advance, exact-tick and actual-GL proof for all three cabinets. |
| fix06_9 | `../todone/fix06_9_coin_pusher_web_performance_evidence_prompt.md` | DONE | landed evidence path | fix06_13 formal closeout | Codex | 2026-08-26 | 2026-09-01 | Maintained exact-300 shipped-Web plan, identity, action/draw/liveness and conservation evidence accepted. Its retained red correctly routed product work to `fix06_13`; the later locked run is green. |
| fix06_13 | `../todone/fix06_13_coin_pusher_shipped_web_performance_prompt.md` | DONE | accepted fix06_9 evidence remediation | pusherv3_11 closure | recovery landing; Codex closeout | 2026-08-27 | 2026-09-02 | Final implementation `6af645b5` removes the native live kernel's per-tick call-context copy. Exact-head focused foundation, native live-batch, Windows/Web input parity, all 24 cache equivalence pairs, and locked fresh-export Chrome 152 CPU4 pass; ready 18.554s and every unchanged cap is green. Owner-directed single-session self-review substitution is recorded without claiming independence or waiving a technical requirement. |
| fix06_14 | `../todone/fix06_14_coin_pusher_collect_reinstall_clock_evidence_prompt.md` | DONE | fix06_13 shipped-Web evidence | fix06_9 evidence closure | `/root/fix06_14_clock` | 2026-08-27 | 2026-08-27 | Archived after accepted landing `616b5a76` and exact-main post-land verification. |
| fix06_16 | `../todone/fix06_16_web_perf_server_orphan_cleanup_prompt.md` | DONE | fix06_14 exact-head qualification | fix06_13 unparked locked run | `/root/fix06_16_impl`; PM:Codex landing | 2026-08-27 | 2026-08-27 | Archived after accepted landing `53f6ed2d` and exact-main lifecycle/static verification. |

### Archived rows — superseded or false premise

These rows remain part of the execution record but are not live or claimable.
Nothing in this archive is deleted; the notes preserve why each row retired.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pusher06_0 | `../todone/pusher06_0_physics_lab_prompt.md` | SUPERSEDED | rework06_2 accepted | — | | | | Archived; superseded by the V3 machine rework. |
| pusher06_1 | `../todone/pusher06_1_solver_core_prompt.md` | SUPERSEDED | rework06_2 accepted | — | | | | Archived; superseded by the V3 machine rework. |
| pusher06_3 | `../todone/pusher06_3_variations_prompt.md` | SUPERSEDED | pusher06_2 | pusher06_4 | | | | Archived; superseded by the V3 machine rework. |
| pusher06_4 | `../todone/pusher06_4_environment_integration_prompt.md` | SUPERSEDED | pusher06_1/2/3 landed | coin pusher closure | | | | Archived; superseded by the V3 machine rework. |
| art06_1 | `../todone/art06_1_punchline_layers_prompt.md` | CLOSED — FALSE PREMISE | env06_4 (DONE) | — | owner-side finding | 2026-08-16 | 2026-08-16 | Archived. Procedural Punchline renderers already satisfied the objective; the rejected raster-runtime branch remains historical. |

### Family 1 — Game depth parity (owner scope decision, 2026-08-25)

The owner's depth standard applies to the whole game, not to craps, poker and
the coin pusher alone. `data/games/games.json` ships eleven games; eight of them
plus the Grand Casino duel were targeted by the depth recovery. Historical
launcher: `../todone/game06_0_game_depth_orchestration_prompt.md`. Its product
payloads are now on `main`; do not relaunch or rebuild them. Program design:
`docs/plans/0.6_remaining_work_program.md`.

Shared-file hazard: `table_game_visuals.gd` and `game_surface_canvas.gd` serve
every table game. `game06_1` lands the ritual vocabulary once so the content
rows can run in parallel without colliding in both files.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| game06_1 | `../todone/game06_1_table_machine_ritual_runtime_prompt.md` | DONE | contract specification authored before implementation | game06_2..7 | recovery landing; `/root/game_closeout` | 2026-08-28 | 2026-09-03 | Landed runtime `5a2b1e1a` accepted without rebuild. Vocabulary/runtime hostile matrices, 132 negatives, seven neutrality targets, ten deterministic traces, project/load gates and all consuming row contracts pass; see `docs/plans/game06_1_final_closeout.md`. |
| game06_2 | `../todone/game06_2_blackjack_depth_prompt.md` | DONE | game06_1 | game06_7 | recovery landing; `/root/game_closeout` | 2026-08-28 | 2026-09-03 | Recovered depth and bounded replay authority are accepted. Exact 120-case/1,000-hand audit, accounting, persistence, hostility, selection/confirmation, and aggregate game gates pass on `af48b531`; only owner playtest remains. |
| game06_3 | `../todone/game06_3_baccarat_roulette_depth_prompt.md` | DONE | game06_1 | depth parity | recovery landing; Codex closeout | 2026-08-29 | 2026-09-02 | Full sealed Roulette/Baccarat depth at `21247535`; focused contracts/rules/RTP, exact accounting, 10-seed determinism, native/Web parity, row-local performance, accessibility, and visual QA passed. Only program-level human playtest remains. |
| game06_4 | `../todone/game06_4_machine_games_depth_prompt.md` | DONE | game06_1 | depth parity | recovery landing; Codex closeout | 2026-08-29 | 2026-09-02 | Recovered machine depth at `e874d6bc`; final gate/fairness remediation at `bd77ac54`. Slot/Video Poker contracts, RTP, exact wagers, lifecycle, 10-seed determinism, native/Web outcome+bonus parity, performance/liveness, accessibility, and visual evidence passed. Only program-level human playtest remains. |
| game06_5 | `../todone/game06_5_counter_games_depth_prompt.md` | DONE | game06_1 | depth parity | recovery landing; Codex closeout | 2026-09-02 | 2026-09-02 | Counter ritual depth landed at `ed47a1bd`; final Crossword reconciliation landed on main at `996a98b6`. Exact-trunk Scratch and Pull Tabs focused contracts passed, the 140-puzzle cycle is fully checked, alignment is 0px/0%, and the 24-machine Pull Tabs seed audit passed. |
| game06_6 | `../todone/game06_6_bar_dice_depth_prompt.md` | DONE | game06_1, craps06_3 | depth parity | recovery landing; Codex closeout | 2026-08-29 | 2026-09-02 | Recovered Bar Dice depth at `d98de544`; seven-phase sealed ritual, exact wagers, lifecycle, 10-seed determinism, native/Web parity, performance, accessibility, and visual evidence passed. The Craps-only environment seam remains safely fail-closed and its prompt-authorized finding is recorded. |
| game06_7 | `../todone/game06_7_showdown_duel_depth_prompt.md` | DONE | game06_1, game06_2 | depth parity | recovery landing; Codex closeout | 2026-08-29 | 2026-09-02 | Recovered Showdown depth at `a6e7be91`; durable Rourke save/revisit fix at `45e87257`. Nine-phase ladder/routes, Blackjack dependency, 10-seed determinism, native/Web parity, performance, accessibility, and visual evidence passed. Only program-level human playtest remains. |
| game06_8 | `../todone/game06_8_games_depth_release_gate_prompt.md` | DONE | game06_2..7, depth06_1 | Family 1 closure | `/root/game_closeout` | 2026-09-03 | 2026-09-03 | All 11 shipped game ids plus Showdown are accounted for. Exact 10-check games aggregate, Blackjack statistical audit, Crew depth replay, project/import/load, row math, persistence, native/Web, accessibility, and visual evidence pass on `af48b531`; only owner playtest remains. |

### Family 2 — Crew and world surface depth (owner scope decision, 2026-08-25)

The original audit found the flagship pillar was still a text menu: streets,
Numbers, jobs, plays, sweep encounters, heist phases and the Turn were targeted
by the recovery. Historical
launcher: `../todone/world06_0_crew_world_depth_orchestration_prompt.md`. Its
product payloads are now on `main`; do not relaunch or rebuild them.

Hidden-state discipline is absolute across this family. A Turn or heist leak is
an automatic P0 and blocks the program.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| world06_1 | `../todone/world06_1_crew_sequence_adapter_prompt.md` | DONE | env06_6 runtime | world06_2..6 | recovery landing; Codex closeout | 2026-08-28 | 2026-09-03 | Host-sealed adapter `95c6aaf5`; production delivery proof and hostile authority matrix pass at Family 2 remediation `57b01ed4`. |
| world06_2 | `../todone/world06_2_streets_sequences_prompt.md` | DONE | world06_1 | world06_6 | recovery landing; Codex closeout | 2026-08-28 | 2026-09-03 | Delivery depth/no-op payload `e46ae808`/`a244eb6a`; pickup, handoff, save/revisit, replay, expiry, and public-sequence proof pass. |
| world06_3 | `../todone/world06_3_numbers_depth_prompt.md` | DONE | world06_1, world06_2 | — | recovery landing; Codex closeout | 2026-08-29 | 2026-09-03 | Numbers depth `7425fb53`; authored math, both rig-route authority boundaries, migration, and hidden-state contracts pass unchanged. |
| world06_4 | `../todone/world06_4_backroom_jobs_recruitment_prompt.md` | DONE | world06_1 | — | recovery landing; Codex closeout | 2026-08-29 | 2026-09-03 | Jobs/recruitment `d94977b9`/`334674fb`; all 13 jobs/five kinds, seven members, host-rooted aftermath, save/load, and privacy pass. |
| world06_5 | `../todone/world06_5_plays_and_sweep_encounters_prompt.md` | DONE | world06_1, game06_1 | — | recovery landing; Codex closeout | 2026-08-29 | 2026-09-03 | Plays/sweeps `418d6e7f`/`9f89b615`; five plays, 13 game surfaces, five sweep rungs, ten seeds, costs, replay safety, and authority gates pass. |
| world06_6 | `../todone/world06_6_heist_and_turn_staging_prompt.md` | DONE | world06_1, world06_2, crew06_10 | world06_7 | recovery landing; Codex closeout | 2026-08-29 | 2026-09-03 | Heist `4822d288`/`613f5013`; both plans, four exits/failure beats, real Blackjack host flow, confrontation, migration, and privacy pass at `57b01ed4`. |
| world06_7 | `../todone/world06_7_crew_world_depth_release_gate_prompt.md` | DONE | world06_2..6 | Family 2 closure | independent depth reviewer; Codex closeout | 2026-09-03 | 2026-09-03 | Exact-tree Family 2 gate accepted. Report: `docs/plans/world06_7_final_closeout.md`; remediation `57b01ed4`; project validation and focused contracts green. |

### Family 3 — Cross-cutting completion (2026-08-25)

Work the board never covered: the update being visible between runs, the
combined economy, teaching what 0.6 became, the sound of the reworked surfaces,
whether a real 0.5 save survives all of 0.6 at once, whether it still runs on
Web and low-end, whether the playtest gate still describes the thing being
playtested, and what the second half of 0.6 is. Historical launcher:
`../todone/cross06_0_cross_cutting_orchestration_prompt.md`; the actual rows
below remain independently actionable.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| meta06_1 | `../todone/meta06_1_career_run_report_surfacing_prompt.md` | DONE | — | — | prior implementer; `/root/landing_coordinator` | 2026-08-26 | 2026-08-27 | Accepted source `27dc4be0`; Review Pool accepted exact integration and main merge `12e127c9`. Contract 16/16 and Foundation all 24/24 were functionally green; timing-only wrapper reds were retained unchanged. UI reproduced the byte-identical inherited env06_6/P1 inactive-delivery digest red on clean parent `ff2d4e14`, proving no meta-caused digest change. |
| balance06_1 | `../todone/balance06_1_cross_system_economy_audit_prompt.md` | DONE | — | `balance06_1-follow-on` after Families 1/2 | PM:Codex/sub:cross-balance | 2026-08-25 | 2026-08-26 | Partial scope accepted at `7c748f5b`. Follow-on custody was independently accepted and landed at `6dbf8bd5`: FINAL is fixed to eight playstyles × 64 seeds × 208 actions, reduced runs are non-qualifying diagnostics, engine/worker identity is sealed through resume and aggregation, and pusher custody requires exactly 200k accepted drops per machine. The binding final-tree distributions, 600k pusher EV, findings and proposals remain pending env/integration source freeze. |
| board06_1 | `../todone/board06_1_board_hygiene_prompt.md` | DONE | — | — | PM:Codex/sub:board-hygiene | 2026-08-25 | 2026-08-26 | Board split landed at `70eaaf80`: 170/170 decisions and 124/124 historical work entries preserved, indexes/links verified, superseded rows archived, owner questions reconciled, and post-land native-backed Smoke PASS. |
| pusherv3_11 | `../todone/pusherv3_11_pusher_program_closure_audit_prompt.md` | DONE | pusherv3_10, fix06_8, fix06_13 | pusher closure | prior review pool; Codex closeout | 2026-08-27 | 2026-09-02 | All contract, Pillar 4, machine-goal, owner-ruling, economy, determinism, conservation, persistence, lifecycle, visual, parity, and shipped-performance pillars pass. Formal closeout is recorded in `docs/plans/coin_pusher_v3_program_closure_audit.md`; no product blocker remains before human playtest. |
| audio06_1 | `../todone/audio06_1_surface_sfx_pass_prompt.md` | DONE | Families 1 and 2 rituals landed | — | PM:Codex/root; `/root/world_closeout` | 2026-09-03 | 2026-09-03 | Recovered and hardened the shared surface route across 13 bounded profiles and 80 events. Exact integrated audit, native/Web determinism, hidden-state, hostile-authority, mixer, budget, focused Foundation, validation/import/load, and fail-closed clean-cache checks pass. Music stays external. |
| integ06_1 | `integ06_1_composition_migration_soak_prompt.md` | TODO | Families 1 and 2 merged | playtest06_2 | — | — | — | Only save-inventory prestage landed at `6e3973f3`; the 0.5→0.6 migration matrix, maximal composition, and native/Web soaks have not run. |
| perf06_1 | `perf06_1_performance_platform_pass_prompt.md` | IN_PROGRESS | Families 1 and 2 merged | playtest06_2 | `/root/perf_closeout` | 2026-09-03 | — | Recovered aggregate/platform work now has immutable Windows/Web evidence, phase-local draw/liveness/allocation rows, exact host capture and a verified reproducible whole-matrix low-end launcher. Static contracts and focused load pass; the binding full matrix waits for landed integ06_1/env06_8 and a quiesced exact candidate. No final verdict is claimed. |
| teach06_2 | `../todone/teach06_2_teaching_pass_two_prompt.md` | DONE | depth06_1, game06_8, world06_7 | — | `/root/teach_closeout` | 2026-09-04 | 2026-09-04 | Recovered the landed tutorial, repaired all four stale tips, and added the three missing just-in-time lessons. Final catalog is 56 guided plus ten contextual; content/coach/onboarding gates, two 100-seed audits, isolation, deterministic hashes, pointer placement, reduced motion, secrecy, and Crew-ignore checks pass. TUT-N17 stays owner-human only. |
| playtest06_2 | `playtest06_2_playtest_gate_refresh_prompt.md` | TODO | integ06_1, perf06_1, teach06_2 | owner playtest | — | — | — | Intake prestage landed at `569e5b23`; named seeds, current dependency rewrite, playtest script, and seed verification have not run. |
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

- **fix06_3 — Crossword Corner art/mechanics reconciliation: ANSWERED
  (2026-09-02).** Preserve the polished newspaper/city/book art direction, but
  replace the sparse disconnected puzzle with a denser genuinely interlocking
  layout, updating the word pool as needed. The shipped result uses seven
  connected words, 22 active cells, eight shared-letter intersections, the
  existing 18-letter reveal and unchanged prize table, with procedural grid
  paint sourced from the same geometry as foil, lettering, and hit testing.

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
