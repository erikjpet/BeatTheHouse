# 0.6 Active Task Board — The Living Town & The Crew

Created: 2026-08-13 · Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` (v4, owner-approved).
This board is the **single source of truth for 0.6 execution state**.
The roadmap is the single source of truth for **design intent**. When
code reality disagrees with either, code reality wins — record the
disagreement in the Discovery & Decision Log below.

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
   roadmap, and decisions you had to make go in the Discovery &
   Decision Log (dated, task-id-tagged, one bullet each). Questions
   only the owner can answer: log them under Owner Questions and pick
   compatible work that doesn't depend on the answer; do not guess on
   owner-locked design.
4. **If blocked.** Set Status `BLOCKED`, put a one-line reason in
   Notes, log it, and stop or switch tasks.
5. **On completion.** All gates green → set Status `DONE`, fill
   Finished, put a one-line verification summary in Notes, fill the
   Execution Record at the top of your prompt file, **move the prompt
   file to `docs/todone/`** (never delete), and append a Work Log line
   naming any rows your completion unblocks.
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
| env06_1 | `env06_1_scenario_engine_prompt.md` | DONE | — | env06_2/3/4, town06_2/3, craps06_2, push06_1 | PM:Codex/sub:1 | 2026-08-13 | 2026-08-14 | PM verified scope/design, all gates, determinism, visual QA, and coexistence PASS. |
| town06_1 | `town06_1_town_state_prompt.md` | DONE | — | town06_2/3, push06_2, streets06_1 | PM:Codex/sub:2 | 2026-08-13 | 2026-08-14 | PM verified scope/design, all gates, determinism, visual QA, and coexistence PASS. |
| crew06_1 | `crew06_1_trust_core_prompt.md` | DONE | — | streets06_1, crew06_2/3/5/6/7/8/9 | PM:Codex/sub:3 | 2026-08-13 | 2026-08-14 | PM verified lender compatibility, hidden-state design, all gates, determinism, and coexistence PASS. |

### Wave B — World content

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| env06_2 | `env06_2_tier1_scenarios_prompt.md` | DONE | env06_1 | crew06_5 | PM:Codex/sub:1 | 2026-08-14 | 2026-08-14 | PM verified all 17 scenarios/events, tutorial neutrality, real-selector reachability, full integrated gates, determinism, and zero-overlap visual QA PASS. |
| env06_3 | `env06_3_tier2_scenarios_prompt.md` | DONE | env06_1, env06_4 | crew06_5, crew06_8 | PM:Codex/sub:4 | 2026-08-14 | 2026-08-14 | PM verified 25 scenarios, production route contracts, all integrated gates, determinism, and 14/14 zero-overlap visual captures PASS. |
| env06_4 | `env06_4_punchline_rework_prompt.md` | DONE | env06_1 | env06_3, crew06_2, crew06_6 | PM:Codex/sub:2 | 2026-08-14 | 2026-08-14 | PM verified scope/design, L2 compatibility and migration, systems/UI/determinism/visual gates, and three-layer zero-overlap smoke PASS. |
| town06_2 | `town06_2_rumors_travelers_prompt.md` | DONE | env06_1, town06_1 | town06_3, crew06_3, crew06_9, chain06_1 | PM:Codex/sub:3 | 2026-08-14 | 2026-08-14 | PM verified truth traces, heard tier, itineraries, reputation propagation, save compatibility, and combined systems/UI/determinism/visual gates PASS. |
| town06_3 | `town06_3_police_sweep_prompt.md` | DONE | town06_1, town06_2 | streets06_1 (full), crew06_3 (full) | PM:Codex/sub:5 | 2026-08-14 | 2026-08-14 | PM verified hidden deterministic track, costed encounters, wake/pressure, save/UI contracts, full integrated gates, and Wave B composition PASS. |

### Wave C — Games

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| craps06_1 | `craps06_1_craps_core_prompt.md` | DONE | — | craps06_2, crew06_8 | PM:Codex/sub:1 | 2026-08-14 | 2026-08-16 | PM verified full rules/chips/save/cheat scope, million-roll RTP, exact-tree full matrix, 10-seed determinism, and focused/canonical visual QA PASS. |
| craps06_2 | `craps06_2_street_craps_prompt.md` | DONE | craps06_1, env06_1 | — | PM:Codex/sub:5 | 2026-08-14 | 2026-08-16 | PM verified shared rules, cash-only teaching/dispersal/training, save/UI, RTP parity, exact-tree full matrix, determinism, and focused/canonical visual QA PASS. |
| push06_1 | `push06_1_pusher_core_prompt.md` | DONE | env06_1 | push06_2 | PM:Codex/sub:2 | 2026-08-14 | 2026-08-16 | PM verified action-boundary pile/nudge/alarm/persistence/economy, exact-tree full matrix, determinism, and focused/canonical visual QA PASS; simulation model is superseded by rework06_2. |
| push06_2 | `push06_2_pusher_variations_prompt.md` | DONE | push06_1, town06_1 | — | PM:Codex/sub:6 | 2026-08-14 | 2026-08-16 | PM verified Ridge/Vault mechanics, persistence, seeded reachability, EV, exact-tree full matrix, determinism, and visual QA PASS; simulation model is superseded by rework06_2. |
| streets06_1 | `streets06_1_streets_framework_prompt.md` | DONE | town06_1, crew06_1 | crew06_3/6/8 | PM:Codex/sub:3 | 2026-08-14 | 2026-08-14 | PM verified scope/design, systems/UI, 10-seed determinism, and package/multi-stop/Hold visual QA on the integrated tree. |
| crew06_2 | `crew06_2_backroom_poker_prompt.md` | DONE | crew06_1, env06_4 | crew06_9 | PM:Codex/sub:4 | 2026-08-14 | 2026-08-16 | PM verified deterministic policies, hidden tells, showdown-gated learning, trust/caps/save, exact-tree full matrix, determinism, and focused/canonical visual QA PASS. |
| crew06_3 | `crew06_3_numbers_prompt.md` | DONE | crew06_1, streets06_1, town06_2 | crew06_9 (grievance src) | PM:Codex/sub:7 | 2026-08-14 | 2026-08-16 | PM verified slips/routes/fix/past-post/leak/economy, exact-tree full matrix, determinism, and 12/12 Numbers visual coverage PASS; rework06_1 must re-point delivery consumers onto the real-map API before Wave D. |

### Reworks — owner-rejected systems (round-5, 2026-08-14)

Two Wave C deliverables were built to spec, played, and **rejected on
design grounds**. The specs were wrong, not the execution: both
prompts told the agents to abstract away the thing that makes the
system good. The roadmap sections are rewritten; these rows replace
the implementations. Wave C cannot close until both are DONE.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| rework06_1 | `rework06_1_map_delivery_prompt.md` | DONE | town06_1/2/3, crew06_1 (all DONE) | crew06_3 re-point, crew06_6, crew06_8 | PM:Codex/sub:8 | 2026-08-16 | 2026-08-16 | PM verified synthetic-board deletion, real-node targets and ordinary-travel routing, all four modes, Numbers re-pointing, migration, exact crew-favor behavior, full 235-stage matrix, 10-seed determinism, and zero-warning visual QA. |
| rework06_2 | `rework06_2_coin_pusher_simulation_prompt.md` | DONE | env06_1, town06_1 (DONE) | Wave C closure, pusher06_2/3/4 | PM:Codex/sub:9 | 2026-08-16 | 2026-08-17 | PM verified the 60 Hz fixed-point discrete-body solver, physical variation mechanics, persistence, exact Windows/Web replay parity, 10-seed determinism, EV, all six feel captures, zero-warning visual QA, and shipped-cap performance. All systems assertions were green; same-load baseline-equivalent wrapper timing was accepted per the owner rule. |

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
| pusher06_0 | SUPERSEDED | OPTIONAL | rework06_2 accepted | — | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| pusher06_1 | SUPERSEDED | REFERENCE | rework06_2 accepted | — | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| pusher06_2 | `pusher06_2_presentation_audio_prompt.md` | DONE | rework06_2 accepted | pusher06_3 | PM:Codex/sub:pusher-depth | 2026-08-17 | 2026-08-17 | PM verified the 160/150 dense snapshot-authoritative render/audio pass, unchanged deterministic outcomes, sub-16 ms shipped-cap actions, exact 200-action Windows/Web native parity, clean exports, seven player-readable feel captures, and the complete green prompt gate matrix. |
| pusher06_3 | SUPERSEDED | TODO | pusher06_2 | pusher06_4 | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |
| pusher06_4 | SUPERSEDED | TODO | pusher06_1/2/3 landed | coin pusher closure | | | | Superseded by the V3 machine rework (`coin_pusher_v3_machine_rework_plan.md`, owner round-6 design session 2026-08-17). Do not claim. |

### Concurrent track — parallel-safe, no dependency on the pusher or crew waves

These were scoped specifically to run alongside the coin pusher and
Wave D/E work without contention. **File ownership is binding and
stated in each prompt** — `events.json` in particular is shared, and
`env06_5` may only add `scenario_`-prefixed events.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| teach06_1 | `teach06_1_onboarding_prompt.md` | DONE | — (owns `data/tutorial/lessons.json` + coach) | playtest quality | PM:Codex/sub:teach-audit | 2026-08-16 | 2026-08-16 | Seven once-only public-surface lessons; final double-notify, non-consuming handoff, clickable pointer-safe placement, guided-prefix, secrecy, UI, determinism, and 75-state visual acceptance pass. |
| env06_5 | `env06_5_scenario_backlog_prompt.md` | DONE | env06_1/2/3 (DONE) | playtest variety | PM:Codex/sub:env-audit | 2026-08-16 | 2026-08-17 | All 13 complete backlog scenarios accepted: exact 55-scenario catalog, 13 scenario-owned events, 20-seed full/launch reach, phases/save-load/layer/tutorial checks, systems/UI assertions, determinism, three-venue smoke, and zero-warning visual QA. |
| art06_1 | `art06_1_punchline_layers_prompt.md` | CLOSED — FALSE PREMISE | env06_4 (DONE) | — | owner-side finding | 2026-08-16 | 2026-08-16 | **Stop work; do not build a renderer seam.** No environment renders from a raster — every venue is procedurally drawn via `pixel_scene_canvas.gd`'s `scene_type` dispatch, and `visual_context.asset_path` is metadata the canvas never consumes. `_draw_punchline_club()` and `_draw_punchline_back_room()` already exist, are dispatched, and are at detail parity with `_draw_bar`/`_draw_underground`. The objective was already met before the row was authored. New PNGs kept as metadata-only. |
| fix06_2 | `fix06_2_street_craps_activation_mutation_prompt.md` | DONE | — (defect in landed craps06_2) | env06_5 acceptance | PM:Codex/sub:activation-guard | 2026-08-17 | 2026-08-17 | PM verified the generic observational activation repair across Street/Grand Craps, all generated games and seven passive hooks, portable tickets/autosave/staffing, and cold saved-Slot checkpoints; focused suites plus clean Systems/UI/determinism/75-state visual gates all PASS without waivers. |


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
| pusherv3_1 | `pusherv3_1_physics_machine_prompt.md` | DONE | rework06_2 (landed) | pusherv3_2 | PM:Codex | 2026-08-17 | 2026-08-17 | Owner ruled complete after PM verification of Amendment 6.1 behavior, native 300-body performance, exact Windows/Web parity, determinism, and all pusher-owning gates; integrated at `a6e36d2f`. |
| pusherv3_2 | `pusherv3_2_live_loop_prompt.md` | IN_PROGRESS | pusherv3_1 | pusherv3_3 | PM:Codex/sub:pusher-live | 2026-08-17 | | PM-orchestrated isolated execution; continuous loop, tray/collect, apparatus, exit-settle, and settled V3 persistence. |
| pusherv3_3 | `pusherv3_3_cabinet_prompt.md` | TODO | pusherv3_2 | pusherv3_4 | | | | Full alive cabinet at slot-renderer parity + physics-driven audio + stacking-visible projection. Feel captures judged as a player. |
| pusherv3_4 | `pusherv3_4_variations_integration_prompt.md` | TODO | pusherv3_3 | coin pusher closure | | | | Ridge (3-hole plinko, physical pucks) + Vault (physical fragments) on the new machine, town/cheat/nudge re-wiring, EV harness by geometry, migration, closure. |

### Wave D — Crew depth

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| crew06_5 | `crew06_5_recruitment_prompt.md` | DONE | crew06_1, env06_2, env06_3 | crew06_6/7/8 | PM:Codex/sub:crew-recruitment | 2026-08-17 | 2026-08-17 | PM verified all seven primary/fallback recruitment paths, diegetic signposting, rank services, seeded presence, save/ignored-run compatibility, lender behavior, authored voices, and clean Contract/Systems/UI/determinism/75-state visual gates. |
| crew06_6 | `crew06_6_layer3_jobs_prompt.md` | DONE | crew06_1, env06_4, streets06_1, crew06_5 | crew06_8 | PM:Codex/sub:crew-jobs | 2026-08-17 | 2026-08-17 | PM verified furnished L3, seeded residency, 12 launch jobs across five kinds/all seven members, services, shared Practice Rig progress, save compatibility, and combined Contracts/Systems/UI/determinism/visual gates PASS. |
| crew06_7 | `crew06_7_coordinated_plays_prompt.md` | DONE | crew06_1, crew06_5 | crew06_8 | PM:Codex/sub:crew-plays | 2026-08-17 | 2026-08-17 | PM verified five explicit coordinated plays, context/presence/rank gates, bounded windows/costs/detection, game seams, save compatibility, sustained heat pressure, and combined release gates PASS. |
| crew06_8 | `crew06_8_heist_prompt.md` | IN_PROGRESS | crew06_5/6/7, craps06_1, streets06_1, env06_3 | crew06_9 | PM:Codex/sub:crew-heist | 2026-08-17 | | PM-orchestrated isolated execution; Plans A+B, real delivery API, outcome ladder, and schema-versioned act seam. |
| crew06_9 | `crew06_9_the_turn_prompt.md` | TODO | crew06_8, crew06_2, town06_2, crew06_3 | release06_1 | | | | |

### Wave E — Narrative + playtest handoff

**This wave does NOT ship anything.** Its terminus is a stable,
complete-enough build handed to the owner for extensive playtest.
0.6 is expected to be roughly 50% done at that moment; the polish and
cleanup pass that follows the owner's playtest is the second half of
the release, and it is where release activity finally happens.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| chain06_1 | `chain06_1_character_chains_prompt.md` | DONE | town06_2, env06_2, env06_3 | playtest06_1 | PM:Codex/sub:character-chains | 2026-08-17 | 2026-08-17 | PM verified six chains/21 beats, all three Cass endings, deterministic anchors, prefix safety, bounded effects, actionable icon projection, save compatibility, and combined release gates PASS. |
| content06_1 | `content06_1_items_events_expansion_prompt.md` | IN_PROGRESS | env06_2, env06_3, crew06_6 | playtest06_1 | PM:Codex/sub:content-depth | 2026-08-17 | | PM-orchestrated isolated execution; souvenirs, existing-hook crew gear, scenario/service fill, and economy audit without tuning. |
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
| fix06_1 | `fix06_1_dead_event_interactions_prompt.md` | DONE | env06_2, env06_3 (landed) | crew06_5+ inherit the class guard | Codex | 2026-08-14 | 2026-08-14 | Generic synthesized-speaker fix; 99-event audit shifted only 3 beach events; permanent generated-environment guard, systems/UI/all, determinism, and visual QA PASS. |

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

## Owner Questions (needs owner; do not guess)

- **content06_1 — souvenir collections persistence:** the prompt asks for
  scenario souvenirs to receive collections-shelf integration, but roadmap
  owner decision #1 makes the Players Card the only cross-run system in 0.6.
  The shipped `data/collections/collections.json` is explicitly meta/cross-run
  and its generic contracts fix two collections with 14-item tiers. Should
  souvenir “collections integration” mean only the within-run inventory/item
  shelf and sale surfaces, or is an explicit roadmap amendment authorizing new
  cross-run souvenir collection progress intended? Content continues on all
  compatible data/events/services/bench scope; meta registration is paused.

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
  from any earlier copy.

- **crew06_7 — Chip Dump funding authority:** the approved play requires
  money conservation and forbids free money, but the roadmap/prompt does not
  define whose funds are placed into the dump or the transfer direction.
  Before Chip Dump is implemented, choose one binding model: (A) player-funded
  temporary escrow, (B) a finite seeded per-run/member crew float, or (C) both
  as separately offered variants. Crew06_6 and the non-Chip-Dump portions of
  crew06_7 can proceed without this answer; no agent may invent the economy.

## Discovery & Decision Log

- 2026-08-17 [crew06_8] PM production-path review returned the initial heist
  slice before broad gates. The crew06_9 stub leaked hidden-system language in
  planning copy and serialized keys; Plan B's vouch/name/component progress
  depended on fixture-only flags with no shipped producer; Plan A counted each
  game action as a clean “session”; and tests bypassed EventModule, ordinary
  travel, and real game-result routing. The correction must use neutral hidden
  seam storage, consume landed scenario/component/training truths, count real
  distinct sessions, and prove planning-table → normal travel/handoff → table
  play in production. Exact payload fixtures supplement rather than replace the
  full Rourke duel and Players Card route regressions.

- 2026-08-17 [crew06_8] PM verbatim Task review returned the correction again:
  Plan A still exposed all three decisions at the planning table before table
  play instead of interleaving them at authored round boundaries; Plan B
  accepted any five generic rounds instead of the required mixed craps/card
  invitational; and its clean front-door exit always started a chase despite
  the contract reserving that chase for hot outcomes. Production tests must
  reject early/wrong-game progress and prove both clean-walk and hot-chase
  routes. Dead fixture-era Plan B component flags must be replaced by the real
  item/training producers used by code.

- 2026-08-17 [crew06_8] Roadmap-fidelity review expanded the same return: The
  Count requires an action-boundary phase window, functional dock-versus-
  corridor consequences, and heat-spike corridor loss; The Whale Game must
  score the authoritative Grand Casino chip flow, consume actual finite
  crew06_7 play state as lifelines, preserve its Rourke-attention outcome path,
  and include the compressed cage/interview beat before clean walk or hot
  chase. None may be represented by fixture-only result flags or a parallel
  heist currency.

- 2026-08-17 [pusherv3_2] PM production-lifecycle review returned the first
  live-loop implementation before broad gates: FoundationMain prepares an
  autosave after every paid DROP by calling the generic surface checkpoint,
  while Coin Pusher used that checkpoint to run up to 1200 settle ticks and
  freeze. That silently recreates the rejected action batch and leaves full
  live solver/session state serializable between checkpoints. The correction
  must separate transient live state from settled persistence and distinguish
  autosave from actual exit: post-drop motion continues, serialized machine
  state contains only `coin_pusher_settled_v3`, and real exit visibly settles
  then freezes. A production autosave-path regression is required.

- 2026-08-17 [pusherv3_2] PM line-by-line live-loop review found additional
  contract failures before integration: elapsed time above one second was
  discarded despite the never-skip rule; fresh generated machines could write
  a current-schema durable state with no valid opening settled snapshot; the
  final settle chunk could be erased before its visible projection; and the
  real-time loop never consumed physics events, leaving Quarter Falls prize
  riders and shipped gutter/shim recovery outside production. Corrections must
  preserve full backlog with four-tick frame work, save/load an exact fresh
  pile, render the final settled frame, and prove a generated rider plus shim
  through real tick/tray/collect paths.

- 2026-08-17 [pusherv3_2] Persistence-budget review found the nominal compact
  record expands to roughly 3 KB for 250 coins after JSON/base64 before
  headers, while every paid coin's default nonempty provenance routes it into
  verbose `extra_bodies`, causing unbounded long-run save growth. The row must
  measure actual representative/cap snapshots and compact default Quarter
  Falls provenance plus future meaningful multiplier provenance while
  retaining sparse body identity and support flags; budgets may not simply be
  raised.

- 2026-08-17 [pusherv3_2] Final verbatim cleanup found the obsolete packed-
  presentation trace still consumed by the performance probe, and the Stage 1
  placeholder still tells the player that controls are offline/no coin is
  accepted after Stage 2 made those controls live. Remove the packed-trace
  consumer, retain real live-motion/liveness measurement, and make the crude
  interim surface truthful; UI/visual smoke must cover the active copy.

- 2026-08-17 [crew06_8] Live-event lifecycle review found the dynamically
  registered `heist_live_table` event was append-only. Without bounded removal
  it can remain on a departed or completed table and leak a dead heist surface
  into later play. Registration must be transient, save/load-safe, and removed
  after departure, abort, or completion without mutating canonical pools; a
  production regression must prove cleanup.

- 2026-08-17 [content06_1] Code reality: the landed Mags bench seam is
  intentionally inert (`crew_mags_bench_status()` reports
  `catalog_ready: false`, and its event offers only inspection), while no
  existing data schema can atomically express the prompt-required member rank,
  bankroll, and optional component gates. PM authorizes one small generic,
  data-driven bench catalog resolver through existing result/effect deltas.
  Item IDs and effects may not be special-cased; Content owns the non-heist
  `crew_mags_bench` payload and must prove the complete gate matrix.

- 2026-08-17 [content06_1] PM verbatim-scope review found the shipped Layer 3
  job board has rotating offers through residency but only one fixed line of
  presentation copy, so the prompt's job-board flavor rotation has no landed
  data seam. PM authorizes a small generic authored-copy pool projected
  deterministically from stable run/action context at interaction boundaries.
  No per-frame or wall-clock mutation is allowed. The same review returned the
  economy artifact because it excluded heist bands; after crew06_8 integrates,
  Content must rebase and audit the landed setup/abort/payout bands without
  tuning them.

- 2026-08-17 [pusherv3_1] OWNER COMPLETION RULING accepted by the PM after
  integrating `a6e36d2f`. Amendment 6.1's solver behavior, native 300-body
  headroom, exact Windows/Web replay, 10-seed determinism, and all pusher-owned
  assertions are verified. The historical Gold Buffalo acceptance assertion
  is independently present on clean pre-V3 `HEAD`; it was neither modified nor
  waived under this row and remains visible to the final combined matrix.

- 2026-08-17 [crew06_8/content06_1] PM collision arbitration: `crew06_8` owns
  `heist_*` additions in shared events/items catalogs; `content06_1` owns every
  non-heist souvenir, service, and bench entry. Both tracks work in isolated
  worktrees, avoid whole-file reformatting, and report key-level shared-file
  changes. Crew integrates first; Content then rebases onto current main and
  reruns its complete gates. No economy tuning is authorized before playtest.

- 2026-08-17 [pusherv3_1] BLOCKING CONTRACT/CODE REALITY CONTRADICTION:
  V2 and all current tray/gutter consumers define cabinet-front travel as
  decreasing y (`y < FRONT_EDGE` pays), matching V3's `TRAY_LIP_Y=6000` and
  `BACK_PLATE_Y=52000`. V3 section 3.1/3.2 instead calls y=30000 retracted and
  y=48000 extended. A face moving to 48000 cannot shove deck bodies toward the
  6000 tray lip, and a platform retracting to 30000 cannot approach the fixed
  52000 back plate to produce the specified carry/plate ratchet. Per the
  contract, no coordinate-label swap or alternate machine was implemented.

- 2026-08-17 [pusherv3_1] Amendment 6.1 implementation decision: the faithful
  GDScript reference now passes the amended landing fork, nestle, face-push,
  collective carry/plate deposit, persistent-top-stock, no-lattice, sleep,
  ledger, ceiling, invariant, and trace contracts. Its measured 300-body
  mid-cascade tick p95 remains about 18 ms, leaving no renderer headroom under
  the binding 16 ms frame contract. The existing cross-export GDExtension seam
  will therefore be rebuilt for the same V3 state/algorithm; body count,
  collision passes, radial contacts, icons, and behavior are not reduced.

- 2026-08-17 [pusherv3_1] Integrated-gate findings: the faithful native V3
  backend measures 2.951 ms p95 at the 300-body mid-cascade contract (24
  samples; independent focused runs measured 2.521-3.850 ms). Fresh Windows
  and Web release exports replay the same 260-tick trace through `native_v3`
  with exact repeat and cross-export SHA-256
  `7fbb4b1667a2f5d09627659dd7a6908c84bc88e1a6c88f8dd9a1ea8fcc868778`.
  The strict crew-ignored full-serialization golden was mechanically
  rebaselined because it embeds every game definition and the intentional V3
  machine schema replaces the larger V2 definition; the full byte-for-byte
  assertion remains intact. The determinism probe's deleted V2 lane/nudge/
  vault sequence was replaced with physical V3 drop + skill-stop input-trace
  replay. Wall-clock solver telemetry is excluded from deterministic RunState
  checkpoints; all physical outcome state remains included.

- 2026-08-17 [pusherv3_1] Mandatory-suite blocker after Amendment 6.1:
  `slot`, Smoke, Contracts, Games, Systems, UI, focused Coin Pusher, native
  Windows/Web parity, and 10-seed determinism are green. `slot_acceptance`
  fails only `Gold Buffalo collection did not advance over 10,000 paid base
  spins.` after its stale reveal-order fixture is excluded from the diagnosis.
  `docs/plans/slot_runtime_storage_root_fix_plan.md` independently records the
  same Gold Buffalo failure on detached clean `HEAD`; it is unrelated to V3.
  Per the row's no-extra-scope and no-weakened-gate rules, Slot mechanics were
  not changed and the row remains blocked; pusherv3_2 stays unclaimed.

- 2026-08-17 [crew06_5] PM scope review returned the row for correction:
  rank/perk APIs alone do not satisfy the prompt's temporary pre-job-board
  contract. Associate work, Switch intel/reveal, and Knuckles stash/retrieve
  must be reachable through normal member contact/encounter surfaces, with
  production-path tests rather than direct API-only fixtures. Code reality
  also resolves the prompt's Mags wording drift: env06_2 shipped the authored
  Fence Night anchor as `back_alley_fence_night`, not a pawn-shop scenario.
  Crew06_5 consumes that existing primary anchor and may not invent a new
  scenario outside its placement scope.
- 2026-08-17 [crew06_5] PM arbitration on the prompt's 7x2 wording: Rook is
  the explicit exception named in Task 1. His shipped Crew-loan action is
  scenario-independent, so he cannot become unmeetable from scenario selection
  and no duplicate fallback encounter may be invented. Acceptance requires the
  real `RunActionService` loan path plus legacy Marker migration compatibility;
  the other six members require primary and fallback production placements.
  Static acceptance also rejected two real placement defects: Velvet's fallback
  must be limited to the authored Slow Night beat, and Bishop's met presence /
  contact must seed and refresh in the Grand Casino cage subroom across revisits.
- 2026-08-17 [fix06_2] An external Codex process merged and pushed the
  still-unverified repair through `91e0a6c4` as merge `9d92f49f`. It changed
  no board or prompt records. The merge is provisional integration only: the
  row remains IN_PROGRESS because the PM's focused UI fixture exposed an
  incomplete test-inheritance contract after the merge. The correction must
  land as a follow-up commit and the full integrated gate matrix still binds;
  no DONE or archival credit is inferred from the pushed merge.
- 2026-08-17 [pusher06_2] PM performance review found that the shipped-cap
  probe recorded raw solver p95 and synchronous production
  `resolve_call_ms` but gated only frames sampled after the blocking action
  returned. Historical full-cap calls were 273–383 ms, so the apparent frame
  PASS hid a player-visible stall. The existing 16.0 ms action/frame contract
  now gates raw solver p95 plus production drop and collapse-nudge resolves.
  Density (160 cap / 150 opening), samples, outcomes, trace, icons, animation,
  and audio may not be reduced to converge; implementation is addressing
  repeated whole-machine and presentation-trace deep copies at their source.
- 2026-08-17 [pusher06_2] Independent solver review rejected active-body
  pruning and async/incremental action semantics as insufficient or contract-
  breaking. The accepted optimization direction is a transactional packed SoA
  solver with deterministic flat-grid iteration and one writeback after all 48
  fixed ticks. Its dictionary solver remains the oracle: the carried 8-seed x
  10-action differential matrix must prove every action used the packed path
  and match raw state, canonical digest, exits, events, trace, and metrics after
  every action. Hostile int64/high-motion states must safely fall back; density,
  ordering, outcomes, presentation, save semantics, and the 16 ms gate remain
  unchanged.
- 2026-08-17 [pusher06_2] The packed solver's exact gate is green (80/80
  carried actions used the hot path and matched the dictionary oracle after
  every action), but it is not a performance fix: raw p95 regressed from
  246.554 ms to 272.698 ms; production drop/nudge resolves measured 319.607 /
  391.200 ms against the unchanged 16 ms limit. Draw and post-action frame p95
  remain green, confirming the synchronous solver is the blocker. Trace is off
  in the raw probe, and the packed path writes dictionaries only once at the
  end; the next root pass targets repeated 27-cell collision/support walks,
  unconditional sparse-grid rebuilds, per-tick Packed allocations, and hot-loop
  Variant/call overhead while keeping the dictionary oracle and all hard limits.
- 2026-08-17 [fix06_2] The integrated games matrix passed after the portable-
  ticket travel correction, but broader systems acceptance exposed two test-
  machinery defects: the Blackjack rotation fixture had not first persisted
  its original dealer at an action boundary, and the new seven-hook activation
  guard pushed the unchanged suite over budget through redundant cold rebuilds.
  The fixture now establishes the original dealer through production resolve;
  the guard optimization may reuse generator/cold snapshots only while retaining
  all 235 generated contexts, 11 games, seven hooks, hostile fixtures, and
  per-hook canonical before/after assertions. No budget or registration changes
  are authorized.
- 2026-08-17 [fix06_2] Runtime validation of the optimized activation guard
  exposed a test-harness aliasing fault, not 168 production mutations:
  `RunState.from_dict` can retain nested references from its input, and the
  parsed JSON graph also has parser-normalized bytes distinct from canonical
  `RunState.to_dict` bytes. Each of the seven hook fixtures now receives a deep
  copy of the parsed graph. Canonical hook outputs still compare exactly to the
  original RunState JSON, while parsed-source immutability compares exactly to
  a baseline captured immediately after parse. A hostile nested-alias fixture,
  the nonserialized-meta masking fixture, and byte-order fixture permanently
  guard all three invariants; no contexts, hooks, budgets, or registrations
  changed.
- 2026-08-17 [pusher06_2] Opt-in phase profiling isolated the packed solver's
  actual blocker at the unchanged 160-body/48-tick fixture: collision traversal
  consumes 57.72% and support traversal 20.64% of raw solver mean, versus grid
  rebuild 3.97%, writeback 0.07%, and collision-visited setup below 0.01%.
  Production drop/nudge remain 295.995/356.338 ms against the 16 ms gate. The
  next root pass therefore caches the frozen-grid candidate order once per tick
  and flattens collision/support hot loops; exact oracle order, trace, density,
  outcomes, and synchronous semantics remain binding.
- 2026-08-17 [crew06_5] The final focused Contract gate is green after two
  fixture-only corrections: exact ignored-run golden normalization now converts
  only finite integral JSON floats in the safe integer range, and the Lucky
  Numbers route fixture now uses canonical WorldMap `a`/`b` edges instead of
  discarded `from`/`to` keys. The real generated presence/contact/EventModule
  service path starts an active delivery run; all Contract assertions pass in
  190.136 s within the unchanged 230.391 s budget. The row remains IN_PROGRESS
  until the full integrated prompt matrix and PM scope/design review complete.
- 2026-08-17 [systems gate] Five test-harness-only efficiency corrections were
  independently accepted and integrated: loaded content references are reused
  under exact immutability sentinels; topology-only world-map sweeps use the
  production map-build seam; activation parsing is cached per environment while
  all seven live hook fixtures remain isolated; Town/Numbers/Police Sweep reuse
  reset/read-only fixtures under hostile reset proof; and save continuation
  reuses its already-proven independent second restore. Seed counts, contexts,
  assertions, registrations, budgets, and production code are unchanged.
- 2026-08-17 [pusher06_2] The profiled hot-path correction is statically
  accepted at `4159f393`: one deterministic frozen-grid candidate sequence per
  center is shared by flattened collision/support loops, with lazy population
  for within-tick center crossings. Exact iteration order, pair visitation,
  support ties, 48 ticks, trace, density, outcomes, and synchronous semantics
  remain unchanged; a hostile center-crossing oracle fixture covers the lazy
  path. Runtime exactness and the 16 ms performance gates remain pending.
- 2026-08-17 [systems gate] The corrected integrated systems matrix now has
  zero assertion/stderr failures, including Crew recruitment and the complete
  seven-hook activation guard, but the unchanged wall gate remains red at
  58.496 s versus 43.712 s (48.515 s internal plus about 9.98 s process
  overhead). In-check setup reuse saved roughly 2.9 s but cannot close the
  remaining wall gap. The accepted next harness direction is deterministic
  multi-process sharding of the existing systems registration: every check
  must run exactly once, aggregate failures/stderr/timeouts must remain honest,
  and no suite, seed, assertion, registration, or budget may move or change.
- 2026-08-17 [systems gate] Independent pre-runtime review returned the first
  sharded launcher for correction before integration: raw child failures must
  outrank synthesized stderr code 127; launcher/cache/report exceptions must
  still emit an honest stage summary; missing-report exit-zero children must
  retain stdout-derived `last_started_check`; hostile contracts must exercise
  those cases plus launch cleanup and mutex contention rather than inspect
  source strings; and shard processes must be prevented from racing on shared
  `.godot` cache files, not merely detect a write afterward. The unchanged
  registration, assertions, timeout, and 43.712 s wall budget still bind.
- 2026-08-17 [systems gate] The first safe live sharded run completed in
  39.554 s, but the exact mutation sentinel honestly exposed nine fixture-only
  failures. Root cause: `_fixture_library()` returned a hand-built library with
  empty derived indexes, so the first legitimate `fixture_rng` lookup lazily
  rebuilt `_indexes` after the baseline fingerprint. Commit `c376445c` now
  hydrates those indexes through the canonical production seam before taking
  the single global baseline, and proves the hydration changes indexes only;
  no sentinel field, assertion, seed, registration, or budget was exempted.
- 2026-08-17 [systems gate] Independent rerun at `c376445c` is green: the
  integrated systems stage completed in 37.260 s against the unchanged
  43.712 s budget; all 49 checks were registered, owned, and executed exactly
  once; all four raw shard exits and stderr streams were clean; and private
  shard projects were fully removed. The hardened launcher and its behavioral
  mutex, partial-child, junction-cleanup, exception, and accounting contracts
  were merged to main in `5a967b75`.
- 2026-08-17 [systems gate] Combined-main verification then exposed two
  environment-sensitive harness defects that the isolated worktree did not.
  The shard copier recursively traversed mutable `.godot/shader_cache`, so a
  disappearing Vulkan cache file could abort setup; after that was removed,
  the post-cleanup parent-cache sentinel ran through `GetNewClosure()` and
  could not resolve its script-local fingerprint helper. Commits `6696bf9e`
  and `e28c67a5` now copy only physically private `imported` data plus required
  stable root metadata, never traverse volatile cache siblings, and exercise
  the cleanup sentinel in its real scope with clean and mutation-fail-closed
  behavioral controls.
- 2026-08-17 [systems gate] Final combined-main verification at `e28c67a5`
  passed in 40.211 s against the unchanged 43.712 s budget. All 49 registered,
  requested, and executed checks are unique and canonical; all four shards
  exited zero with no stderr or timeout; private projects were removed; and no
  Godot process remained. Artifact:
  `.tmp/test_reports/20260817_pm_postmerge_systems_e28c67a5/summary.json`.
- 2026-08-17 [integrated UI] The UI gate currently stops before assertions
  because `New-SplitTestRunner` concatenates descendant implementations with a
  contiguous parent-only fallback-stub block, producing duplicate function
  declarations. The parent stubs remain necessary for standalone inheritance;
  the generic correction will mark and omit only that block in generated split
  runners, with balanced-marker and exact-once generation checks. No UI
  assertion or implementation function may be removed.
- 2026-08-17 [crew06_5/integrated UI] After the split-runner correction, the
  integrated UI suite reached its assertions and exposed a real compatibility
  regression: accepting the shipped Crew loan retires its lender entry but
  `RunActionService.use_hook()` immediately enqueues `recruitment_rook_signpost`,
  so the talk dock remains visible and the formerly empty triggered-event queue
  changes. The Wave kickoff requires the shipped Crew lender flow to remain
  behavior-identical. Crew06_5 already supplies the prompt-required diegetic
  leads through the seeded, presence-bound `recruitment_rook_leads` encounter;
  the redundant automatic post-loan enqueue must be removed while that
  contextual path and its one-hearing/save contracts remain intact.
- 2026-08-17 [crew06_5/integrated UI] Commit `4e86bbe1` removes only the
  redundant automatic post-loan Rook enqueue and permanently asserts that the
  real Crew lender action reaches Marker with no triggered/talk event left
  pending. Contextual seeded `recruitment_rook_leads` remains covered. PM reran
  the complete integrated UI gate at
  `.tmp/test_reports/20260817_042700_pm_integrated_ui_crew_fixed`: 0 failures;
  `ui_scene_compile` 58.029 s versus the unchanged 124.851 s budget, with all
  import/load/auxiliary UI stages green and no stderr issues.
- 2026-08-17 [fix06_2] Independent scope audit accepted the Street/Grand Craps,
  seven-hook cold JSON-restored guard, staff-generation, portable-ticket, and
  autosave repairs, but found one remaining activation-class defect: a saved
  Slot fixture carrying `slot_animation_resume_elapsed_msec` erases that
  durable checkpoint and writes `slot_animation_started_msec` from wall-clock
  time during passive `enter()`. Generated fixtures did not carry the checkpoint,
  so the current guard missed it. The row remains IN_PROGRESS for a transient
  resume projection plus an exact-byte cold saved-slot hostile; the field may
  not be exempted or normalized before the baseline.
- 2026-08-17 [fix06_2] Commits `b5db8c07` and `124ced15`, integrated by
  `e94658ca`, keep the durable Slot checkpoint byte-exact during passive
  `enter()`/surface projection and resume it through transient canvas time.
  New coverage includes cold JSON-restored non-default `slot:2`, real
  enter→surface→render→play parity, 0.5 drunk-time scaling, same-ID cumulative
  rebase, omitted-offset clearing, unrelated-channel isolation, and clean
  checkpoint consumption at action/save boundaries. Focused Slot is 2/2 and
  Games 10/10 with zero skips/failures/stderr; integrated systems and UI are
  green, while determinism and visual gates remain before row closeout.
- 2026-08-17 [fix06_2/integrated systems] The first post-merge run was
  functionally green 49/49 but correctly rejected for timing because an
  already-started Web native compile inflated every shard (61.518 s). With
  external build I/O stopped, the exact rerun passed in 39.895 s against the
  unchanged 43.712 s budget: 49 registered/requested/executed unique checks,
  saved-slot activation hostile green, four raw exits zero, no stderr/timeouts,
  and empty private-project cleanup. Artifact:
  `.tmp/test_reports/20260817_052921_pm_postmerge_systems_saved_slot_clean`.
- 2026-08-17 [fix06_2/crew06_5 integrated UI] A native compiler overlapped the
  first post-merge UI run, so its functional pass was retained only as
  diagnostic evidence. After the pusher lane was made quiet, the fresh
  authoritative rerun passed with 0 failures: `ui_scene_compile` 57.828 s
  against the unchanged 124.851 s budget, every stage exit 0, no timeouts, and
  no stderr issues. Artifact:
  `.tmp/test_reports/20260817_0540_postmerge_saved_slot_ui_authoritative`.
- 2026-08-17 [crew06_5 voice review] PM manually compared every new recruitment,
  presence, signposting, and contact line in `data/crew/recruitment.json` and
  `data/events/events.json` against the seven authored `characters.json` voice
  styles. The registers remain distinct and conforming: Rook low/economical,
  Switch fast/forward-looking, Mags precise/order-driven, Knuckles blunt,
  Velvet warm/polished, Bishop formal/record-minded, and Lucky bright/reckless.
  No quest-log register or hidden-system leakage was found.
- 2026-08-17 [fix06_2/crew06_5 determinism] The clean current-main 10-seed
  probe passed twice with 590 checkpoints and combined hash `3567232055`.
  `run_a.json` and `run_b.json` are byte-identical at SHA-256
  `18515D3E083837485C5821F3FC27BE4B81134AB7B89D018290CC41C55CEC13CD`;
  all seeds have matching final hashes, with zero failures or warnings.
  Artifact: `.tmp/foundation_determinism_probe/`.
- 2026-08-17 [fix06_2/crew06_5 visual QA] Current-main visual QA passed twice;
  the isolated diagnostic rerun had exit 0 and empty stderr. The final report
  contains 75 state snapshots, 117 screen-input events, and eight Coin Pusher
  captures with zero warnings, errors, or overlap failures. Both explicit
  environment/game-surface overlap assertions are true. The gate intentionally
  records headless state/geometry rather than PNGs; PM inspected representative
  normal, reduced-motion, lockdown, small-screen, scenario, shop, and machine
  snapshots. Report: `user://foundation_visual_qa_report.json`.
- 2026-08-17 [crew06_5 final scope/design review] PM walked Task sections 1–3
  and QA 1–6 against `cc82fdfe` plus `4e86bbe1`, including the board-arbitrated
  code-reality seams. All seven contacts have production primary/fallback
  reachability, Associate promotion, diegetic Rook leads, rank-gated existing
  services, and seeded action-boundary presence. Trust stays hidden, no quest
  UI/log leakage or wall-clock mutation exists, ignored runs retain the byte
  golden, save/load persists canonical crew06_1 fields, and the shipped Rook
  lender handoff reaches Marker without a duplicate pending event. No
  out-of-scope feature or owner-locked guess remains.
- 2026-08-17 [pusher06_2] Exact runtime at `4159f393` is green across the 80
  carried hot actions and all hostile/fallback twins. Raw p95 improved 43.9%
  from 283.293 to 159.000 ms, but remains 9.94x over the 16 ms gate; production
  drop/nudge are 223.999/253.298 ms while draw and frame budgets pass. Eager
  candidate priming moved the dominant cost to grid/cache construction
  (62.612 ms mean). A lazy allocation-stable cache pass is in progress, but
  profiling already shows current GDScript cannot credibly close 16 ms without
  a native packed-core seam if that pass remains over budget; no threshold,
  density, trace, ordering, or outcome change is authorized.
- 2026-08-17 [pusher06_2] The allocation-stable lazy-cache pass at `c0a7ad26`
  plus fixture correction `054698bd` remains exact across the full Coin Pusher
  contract (0 failures; 80/80 carried actions and hostile fallbacks), but its
  unchanged shipped-cap performance gate still fails: raw solver p95 is
  123.578 ms and production drop/nudge resolves are 183.537 / 205.508 ms versus
  16.0 ms. Collision, support, and 48-tick integration alone exceed budget;
  presentation draw/frame gates pass. Further GDScript tuning cannot credibly
  close the remaining 7.72x gap. The root correction therefore advances to a
  native deterministic packed core behind the existing GDScript oracle/fallback,
  with Windows and Web export compatibility, density, trace, order, outcomes,
  and synchronous action semantics unchanged.
- 2026-08-17 [pusher06_2 native hardening] Independent re-audit of `ad11f2fa`
  accepted the Git-environment hostile, non-traversing junction cleanup,
  abandoned-mutex recovery, verified-toolchain-only build path, quiet Git, and
  full environment restoration. It returned one release blocker: the committed
  Web preset still has `variant/extensions_support=false`. Web export must set
  extension support true and fail before build/export unless that exact preset
  option is enabled; a side-module filename check alone cannot prove the engine
  template can load it.
- 2026-08-17 [pusher06_2 native hardening] Corrective commit `5c06e08a` is
  independently accepted for static/provisioning scope. The sole Web preset is
  extension-capable, and exact named-preset hostiles prove export rejects false,
  missing, mixed-case, or unrelated-preset values before resolving Godot,
  building native code, or exporting. Windows/Web build, load, export, and boot
  remain runtime acceptance gates.
- 2026-08-17 [pusher06_2 native adapter] Independent static review returned the
  first native dispatch for a fail-closed contract repair. Class-name
  instantiation and a non-empty result do not prove backend identity, ABI, or
  result shape; passing authoritative state also lets an incompatible backend
  mutate before a fallback double-step. Native execution must use a deep
  candidate, validate exact backend identity/methods/result schema, and publish
  only after full acceptance. Injected stale and partial-mutating invalid
  backends must prove original state/result remain exact and fallback runs once.
- 2026-08-17 [pusher06_2 native boundary] The same review found hostile signed
  arithmetic at the public helper seam: `INT64_MIN / -1` is undefined in C++,
  and unbounded aim/nudge inputs can overflow subtraction/negation or narrow
  velocity sums before validation. Define that division edge, enforce a numeric
  envelope, reject before mutation, and cover INT64 extrema plus oversized
  nudge inputs. The fixed-positive-divisor 48-tick kernel is not implicated.
- 2026-08-17 [pusher06_2 trace audit] Presentation/audio traceability found two
  unclosed acceptance defects outside solver speed. At 1280Ã—720 the generic
  LEAVE button's x=776..862 design rect overlaps the Coin Pusher console-title
  region for Quarter Falls, Jackpot Ridge, and Vault Drop; a production layout
  assertion is missing. Reduced-motion replay also becomes inactive before the
  snapshot sync observes an active action, which can suppress terminal
  impact/tray/gutter/alarm audio. Reposition and guard the affordances, and prove
  reduced-motion actions still emit snapshot-driven audio while visuals freeze.
- 2026-08-17 [pusher06_2 kernel parity] Static comparison found native phase
  publication diverging from the GDScript oracle. Native unconditionally adds
  or normalizes both phase keys, while the reference preserves a missing or
  non-integer phase when that pusher is locked and no phase was captured. Keep
  normalized locals for geometry/trace, publish only under the reference
  conditions, and add exact locked missing/non-integer phase fixtures across
  reference, forced GDScript, and native paths.
- 2026-08-17 [pusher06_2 kernel parity] Native writeback also replaces the
  `bodies` Array, while the GDScript hot path compacts the original container in
  place. External array aliases therefore observe exits only on the fallback.
  Preserve the oracle's container-alias behavior and add a unique-ID exit
  fixture across reference, forced GDScript, and native paths.
- 2026-08-17 [pusher06_2 opening density] The trace audit found no implementation
  or assertion for the prompt's explicit "packed near the pusher, thinning
  toward the ledge" opening gradient. Current seeding splits 110 coins evenly,
  samples full shelf depth uniformly, and maximizes spacing. Dense captures do
  not prove the required distribution; deterministic depth bias plus a gradient
  test is required without reducing the 160/150 shipped density.
- 2026-08-17 [pusher06_2 native adapter] The first transactional correction is
  still rejected: deep-copying the whole state then clearing/merging it on
  success invalidates every nested body/array alias even without exits and puts
  full-cap GDScript copying back on the <=16 ms path. Publish through
  alias-equivalent in-place reconciliation (prefer a compact validated packed
  candidate/output seam), prove body and container aliases with and without
  exits, and remeasure raw plus production budgets.
- 2026-08-17 [pusher06_2 native adapter] The compact candidate/in-place
  reconciliation revision now preserves the original bodies Array, surviving
  Dictionary identities, exit compaction, unknown top-level state, and
  solver-owned publication; locked missing/text phase writes also match the
  oracle. Static acceptance still requires malformed candidate element checks
  before casts and explicit public-helper extrema/reject-before-mutation smoke.
  Candidate-body copy cost remains subject to the unchanged performance gate.
- 2026-08-17 [pusher06_2 native static acceptance] Final independent review
  ACCEPTS the corrected kernel/adapter scope: exact 48-tick order, defined
  signed arithmetic, identity/ABI/schema selection, transactional fallback,
  phase parity, live Array/Dictionary/nested-metadata aliases, ordered exits,
  mutable-only publication, full nine-key integer metrics, malformed/immutable/
  duplicate-ID hostiles, per-action carried native selection, and no production
  clock reads. `git diff --check` is clean. Candidate-copy cost remains a runtime
  performance gate. A newly built debug DLL then crashed during extension load
  before the smoke script; that build is rejected pending exact-source rebuild
  and registration/binary-compatibility isolation.
- 2026-08-17 [pusher06_2 native load] Three exact debug builds and an
  old-binding-surface control all crash identically during extension
  registration at Godot's StringName refcount-unref path, before any solver
  script/action. PE architecture/export/imports are valid and new method
  bindings are ruled out. Root-cause direction: hardened bootstrap replaced an
  unchecked cached binding tree with the lock's Godot 4.5 `godot-cpp` commit
  `e83fd...`, while the engine is Godot 4.6. Run clean scaffold controls against
  exact 4.5 and exact-engine 4.6 API/interface bindings, clearing native/
  generated caches; if 4.6 loads, correct and verify the lock rather than
  working around the ABI. Upstream has no `godot-cpp` 4.6-stable tag/branch:
  latest stable is 4.5 `e83fd...`, while Godot 4.6-stable is engine commit
  `89cea143...`. Do not pin `godot-cpp` master blindly; generate and hash-pin the
  API/interface from the exact engine or verify a specific upstream sync commit.
- 2026-08-17 [pusher06_2 4.6 binding pin] Candidate upstream commit `d7b6162`
  is technically credible but returned for truthful provenance. It is official
  `godot-cpp` master/v10 Beta, not a nonexistent 4.6-stable tag; it is post-4.6
  and also carries gated 4.7 additions. With `api_version=4.6` it selects a
  file declaring Godot 4.6.0 stable/official/single at SHA-256
  `00A3AD6DF2361ED3DF6EF9BC8717FE0F49112012EE6E87A7B4CFB34465C9BEED`.
  Record `refs/heads/master` plus immutable commit, disclose the reviewed Beta/
  post-release risk, and lock/assert the exact 4.6 API and interface provenance
  instead of fabricating a tag.
- 2026-08-17 [pusher06_2 4.6 binding pin] A higher-integrity upstream target
  supersedes the master candidate: official `godot-cpp` commit `58d1de72...`
  explicitly syncs Godot engine `89cea143...` (4.6-stable). Its extension API is
  content-equivalent to the exact runtime dump and its GDExtension interface is
  byte-identical (interface SHA-256 `34d7058f31af186d36b84567e70a9f9543da0d74f25cfe5266d4fe2d27e090f0`).
  The candidate lock now records truthful commit provenance, exact payload
  hashes, API 4.6, and bootstrap verification after clearing mixed generated
  caches. Independent provenance re-audit and a clean load test remain.
- 2026-08-17 [pusher06_2 4.6 binding pin] Independent re-audit ACCEPTS exact
  `58d1de72...` pin/provenance/hash semantics. At that commit `extension_api.json`
  is intentionally the consumed 4.6 payload (4.6.0 stable/official/single), the
  API and interface hashes match the lock, and the source commit is the official
  exact sync from engine `89cea143...`. No fabricated tag or master/Beta risk
  remains. Windows/Web runtime load and smoke are still separate required gates.
- 2026-08-17 [pusher06_2 Windows native] A fully clean exact-4.6 debug build
  linked and registered in Godot 4.6 with exit 0, proving the prior crash came
  from the 4.5 binding payload/mixed cache. Direct real-core smoke passed backend/
  ABI identity, signed-division and nudge extrema, reject-without-mutation,
  reference=forced-GDScript=native twins, +48 tick/no production clock leakage,
  duplicate-ID, and hostile fallback. The sole authoritative focused run at
  `.tmp/test_reports/20260817_063025_smoke` passed with 0 failures: validation
  41.703 s, load 21.966 s, Coin Pusher 51.734 s, all exits 0 and no stderr/
  timeouts. An earlier no-GODOT_BIN setup directory is discarded, not evidence.
- 2026-08-17 [pusher06_2 native performance] First loadable native measurement
  remains RED at the unchanged thresholds: raw full-cap p95 19.369 ms, production
  drop 104.976 ms, and production nudge 124.424 ms versus 16.000 ms. This is a
  major improvement over GDScript but not acceptance. Backend selection and
  truthful production phase timing must isolate the compact candidate-copy cost
  from the additional host/snapshot overhead; no density, tick, presentation,
  action, or threshold change is authorized. Unrelated scratch-ticket fixture
  failures in the broad probe are not Coin Pusher evidence.
- 2026-08-17 [pusher06_2 native phase profile] Opt-in production-boundary
  timing confirms real native selection and narrows the remaining work without
  blaming autosave. Raw full-cap p95 is 18.109 ms: native call p95 13.131 ms,
  adapter validation 1.889 ms, and adapter total 16.924 ms. Production drop is
  99.247 ms and nudge 102.682 ms; module resolution is 34.291/37.826 ms, of
  which trace construction alone is 15.195/16.582 ms, while the still-combined
  post-action/refresh phase is the largest block at 51.969/55.557 ms. Autosave
  preparation is only 0.008 ms. The next probe must split apply/tutorial/audio
  from embedded refresh/snapshot before any root optimization is accepted.
- 2026-08-17 [pusher06_2 native host split] The second opt-in probe confirms
  the remaining synchronous production cost is distributed, not one I/O bug:
  raw p95 18.257 ms; drop/nudge 86.509/89.304 ms; trace construction
  14.036/14.974 ms; post-action checks 19.508/22.268 ms; embedded refresh
  22.884/23.841 ms, with roughly 11 ms still outside the instrumented host
  total. Root work must account for that outer cost and preserve immediate
  action completion, exact 14-frame trace, snapshot/audio semantics, and all
  160 physical bodies; deferral or feature removal is not accepted.
- 2026-08-17 [pusher06_2 optimized native profile] Fresh exact-4.6 DLL
  `8B7F5CE8...E0E5D9` linked/loaded, direct native smoke and focused Coin Pusher
  exactness passed, but performance remains RED: raw p95 17.276 ms, production
  drop 80.586 ms, nudge 75.020 ms versus 16 ms. Draw/frame/idle are green and
  both actions preserve 14 trace frames, collapse evidence, and zero full
  snapshots. The accepted trace construction pass reduced active trace to
  6.284-7.002 ms. Remaining host roots are no-op interrupt scans
  (`enqueue_talk` 10.316-10.820 ms plus unavoidable-event 8.799-9.258 ms) and
  embedded refresh (`HUD` 14.630-15.316 ms, terminal 4.152-4.184 ms,
  snapshots 3.382-4.677 ms). Parallel root analysis is authorized; no threshold,
  trace, body, animation, audio, or immediate-completion change is authorized.
- 2026-08-17 [pusher06_2 native optimization review] The second raw/trace
  candidate was rejected before runtime: scripted subclasses of the native
  class could be misclassified as trusted; ordered-subset validation allowed
  unreported body removal/immutable drift; trace Dictionary insertion order
  differed from the reference; and nested metadata aliased across published
  frames/exits. Exact unscripted identity, exit-accounted 1:1 body validation,
  reference key order, and per-publication metadata isolation plus hostile
  regressions are required. No rejected runtime evidence will be produced.
- 2026-08-17 [pusher06_2 host root analysis] Two isolated host corrections are
  authorized from measured code paths. Interrupt handling currently deep-copies
  the full 14x160 trace twice merely to read scalar fields, then builds a dense
  surface before learning no table-approach event targets Coin Pusher. Embedded
  refresh rebuilds pressure/objectives two to three times, scans a recovery
  value the consumer never reads, performs full terminal recovery scans despite
  a valid wager, and repeats already-isolated result copies. Separate branches
  will implement only priority-identical read-only scalar selection/data-derived
  target indexing and the provably redundant P0-P3 refresh work, with parity
  tests; broad dirty-state/revision caching remains out of scope unless a fresh
  profile proves it necessary.
- 2026-08-17 [pusher06_2 interrupt fast-path review] Final cross-review returned
  the first interrupt branch: quiet actions still reached the full unavoidable-
  event pack scan, and positive-Heat/supported-table paths still scanned every
  event. The fundamental correction must publish ordered, data-derived action,
  heat, and table candidate indexes that preserve authored order and exact RNG;
  the real outer action path must prove zero full-pack visits/deep trace copies/
  unnecessary surface builds. Closing, forced-travel, unavoidable short-circuit
  order and same-length direct-content replacement invalidation also require
  behavioral coverage. The branch is not accepted or integrated.
- 2026-08-17 [pusher06_2 interrupt fast-path acceptance] After two returned
  revisions, the isolated interrupt correction is independently ACCEPTED and
  integrated through `cd2f39ef`. Ordered action/heat/table candidate indexes
  preserve authored order/RNG while the real quiet dense outer path proves zero
  candidate visits, cadence RNG create/save calls, surface construction, deep
  result snapshots, and index rebuilds. Eligible timed actions prove exact one-
  candidate/one-RNG behavior; same-length content replacement and explicit
  in-place rebuild each prove exactly one index scan. PM's sole profiling/counter
  merge conflict was corrected so counters remain outside measured helper spans.
- 2026-08-17 [pusher06_2 embedded-refresh acceptance] The isolated refresh
  correction is independently ACCEPTED and integrated through `45113784` after
  three returned test revisions. Provably dead recovery scans and duplicate
  pressure/objective work are removed; the terminal-only path skips recovery
  diagnostics only after a valid wager proves nonterminal; internal Coin Pusher
  render snapshots avoid redundant nested copies while public snapshots remain
  deep-safe; stable world-header/embedded-feedback work is skipped without
  delaying HUD, game, item, talk, music, coach, autosave, interrupt, or realtime
  animation updates. Final behavioral proofs use FoundationMain's owned canvas,
  real completed drop/nudge actions, real realtime guards/advance, explicit
  autosave-before-forced-travel order, deferred coach execution, tutorial/normal
  intervention, and required nonempty byte-equal public data before mutation.
- 2026-08-17 [pusher06_2 presentation gaps] Independent static review ACCEPTS
  all three corrections after returning float quota math and two false-positive
  tests. Opening generation uses integer-only deterministic per-shelf quotas
  (rear 35 > mid 25 > front 15; stacks 9/7/4) at exact 150/cap160 with
  authoritative body-view parity. Exact production titles auto-fit inside a
  bounded rect clear of the real LEAVE control. Reduced-motion audio establishes
  a silent first/restored baseline, keeps restored active state silent through
  terminal, emits a later action once, and syncs before frozen visual clocks/
  redraws. Focused runtime remains before merge.
- 2026-08-17 [pusher06_2 density authority] PM arbitration records the narrow
  interpretation required by the prompt's specific Task 0 over its general
  zero-outcome-change rule: the explicitly required generation-time coin-cap,
  opening-density, and opening-depth-gradient changes are authorized physical
  initial-state changes. "Unchanged outcomes" means presentation/audio may not
  steer, fabricate, reconcile, or feed back into a payout; the deterministic
  authoritative solver still decides solely from the generated pile and player
  inputs, and exactly what physically crosses the payout edge pays. This is not
  authority to alter action rules, payout classification, or solver semantics.
- 2026-08-17 [pusher06_2 presentation runtime] The isolated presentation-gap
  fresh focused gate is green with zero failures and zero stderr issues:
  validation 41.483 s, import 17.038 s, load 21.723 s, and Coin Pusher
  129.535 s. An earlier run exposed only a restored-vs-new audio fixture error;
  the corrected fixture now establishes an empty baseline and still requires
  every event in each of four genuinely live nudge lifecycles. Synthetic
  key-fragment rendering and pusher-specific supported-input/1280x720 dispatch
  coverage remain before the presentation commits are accepted.
- 2026-08-17 [pusher06_2 input scope] Code-reality audit confirms the dense
  Coin Pusher surface supports mouse and touch through `GameSurfaceCanvas` exact
  hit regions; it has no keyboard/joypad routing or focusable controls.
  Acceptance therefore covers real mouse and touch events at 1280x720 for all
  five lanes, three force choices, three directions, drop, and nudge. Adding a
  new keyboard/controller interaction model would be a design/feature expansion,
  not a missing test in this presentation row.
- 2026-08-17 [pusher06_2 presentation closeout] Final isolated presentation
  contract run is green with zero failures and zero stderr issues: validation
  42.747 s, import 16.969 s, load 21.473 s, Coin Pusher 126.478 s. Independent
  static review also accepts the added solver-null Vault key-fragment proof and
  all 13 production exact-hit targets through real mouse and touch dispatch at
  1280x720, including command mapping and deterministic-digest invariance. The
  presentation commits may now integrate after native performance is green.
- 2026-08-17 [crew06_6/crew06_7] PM pre-integration decision: after crew06_5
  is accepted, both rows may execute concurrently only in isolated worktrees.
  They will share one read-only presence seam over `crew_presence`:
  `crew_present_member_ids(environment := current_environment)` and
  `crew_member_present(member_id, environment := current_environment)`.
  Crew06_6 owns grievance-free job decline/expiry and the shared Craps
  training-progress grant seam; crew06_7 consumes those APIs and may not guess
  Chip Dump's owner-locked funding model.

- 2026-08-13 [board] Board created from roadmap v4. Rounds 1–4 owner
  decisions are all locked in the roadmap; heist ships Plans A+B; C+D
  documented for future (goal: one plan per member); pusher alarm has
  NO forced exit — heat pressure only.
- 2026-08-13 [board] Id `crew06_4` intentionally does not exist: the
  Lookout minigame was absorbed into the Streets framework as its
  "hold" mode (streets06_1). Do not hunt for a missing prompt.
- 2026-08-13 [env06_1/town06_1] PM arbitration after both agents inspected
  code: first-visit scenario selection belongs in `RunGenerator`;
  `EnvironmentInstance` only applies an already-selected overlay at generation.
  Scenario data may declare optional top-level `town_weight_tags`.
  `TownState` and its `RunState` forwarding seam expose
  `scenario_weight_multiplier(archetype_id, scenario_id, tags) -> float`, with
  `conditions.json` owning tag multipliers and all missing state/tags/modifiers
  returning `1.0`. The call occurs once per candidate at selection boundaries,
  with no per-frame work or allocation required.
- 2026-08-14 [Wave A gates] PM integrated-tree systems verification passed all
  Wave A scenario, town, crew, save, and compatibility checks, but reproduced
  six inherited gate failures: the Web SFX bank omitted `heat_gain`; watched
  `pull_tabs/tab_detector_scan` omitted four canonical watched-state/heat
  outputs; and watched `roulette/read_wheel_bias` omitted its pit-boss heat
  bonus. The gate is not waived. Root-level remediation is delegated across
  the three Wave A subagents and must pass the unchanged assertions before any
  row is marked DONE.
- 2026-08-14 [town06_1] `data/town/conditions.json` retains the repository's
  required root-array pack shape; `ContentLibrary` loads its sole schema-v1
  object as the TownState dictionary. This is a storage-shape accommodation,
  not a public API deviation.
- 2026-08-14 [Wave A gates] Root remediation completed without waivers: the
  generated Web bank now includes `heat_gain`; watched Pull Tabs and Roulette
  actions preserve canonical Pit Boss metadata; scalable menu surfaces are
  manifest-classified separately from 32px icons; Pocket Watch fills its icon
  canvas; visual QA targets current semantic menu roles; and saved Cage gift
  shelf objects participate in generation-time layout to prevent overlap.
- 2026-08-14 [env06_2/env06_4] PM arbitration: Punchline remains the single
  `small_underground_casino` archetype with a data-driven `layers` dictionary
  keyed `club`, `casino`, and `back_room`, plus `default_layer_id: "club"`.
  Scenario definitions may carry an optional top-level `layer_id`; it is
  omitted for ordinary venues and must survive scenario state normalization.
  Missing layer fields retain legacy single-layer behavior for compatibility.
- 2026-08-14 [town06_2/town06_3] PM-approved shared town-content contract:
  `TownState` owns registered rumor facts shaped as `{id, class,
  target_node_id, source_id, payload, registered_action}` and exposes RunState
  forwarding reads/writes `register_rumor_fact`, `rumor_fact`, `rumor_facts`,
  `rumors_for_venue`, `hear_rumor`, and `heard_rumor_for_node`. Extension class
  `sweep_sighting` is registered for town06_3. Heard previews remain distinct
  from `scouted`. Traveler reads are `traveler_node` / `travelers_at`;
  reputation uses `record_reputation_incident`, `local_reputation`, and
  `reputation_value`. All three systems advance through the existing
  `advance_environment_turns` action boundary, never per-frame or wall-clock.
- 2026-08-14 [env06_4] PM-approved layer runtime contract: environment
  snapshots add a schema version, `current_layer_id`, `default_layer_id`,
  layer ids/transitions/discovery, and lazily populated `layer_states`; the
  current layer remains flattened at the top level for legacy consumers.
  Generic RunGenerator/RunState seams enter layers, query access, and record
  discovery only at action boundaries. Legacy Punchline snapshots migrate to
  discovered L2 while missing L1/L3 state is seed-forked lazily. Scenario
  `layer_id` survives normalization; Grand Casino room structures stay out of
  scope. L3 remains a registered minimal shell for crew06_6.
- 2026-08-14 [env06_2] Tier-1 scenario ids use stable archetype-prefixed
  slugs; each scenario owns one `scenario_<scenario_slug>_<beat>` exclusive
  event absent from every base pool. The tutorial pins
  `corner_store_delivery_day` only if its regression proves tutorial-sensitive
  pools and sequencing unchanged. The 20-seed audit must exercise the real
  scenario selector, including the landed town-weight seam.
- 2026-08-14 [env06_2] Code reality showed a pinned scenario still applied its
  overlay, conflicting with the tutorial's controlled environment. PM approved
  generic challenge flag `scenario_pins_apply_mutations` (default `true`),
  evaluated only at generation. The tutorial sets it false: the deterministic
  scenario identity remains stored, while base/phase mutations, opportunities,
  and hooks are an identity overlay. Non-tutorial pins retain existing behavior;
  a byte-identical tutorial environment fixture is required.
- 2026-08-14 [town06_2] Code reality has only boolean/full-detail `scouted`
  flags and does not seed unvisited scenarios. PM approved a separate `heard`
  node payload exposing only its truth-traced line, plus canonical one-time
  scenario selection for non-empty-pool nodes before a scenario rumor can be
  generated; first visit consumes that stored selection without a second RNG
  draw. Empty-pool archetypes remain byte-identical. Authored themed security
  `strictness` strings also remain unchanged; traveling reputation supplies a
  separate derived `door_strictness_band` at generation.
- 2026-08-14 [env06_4] The shipped guided tutorial enters
  `small_underground_casino` expecting immediate blackjack, so PM approved a
  generic, validated challenge-data `environment_layer_overrides` map that
  selects Punchline L2 on tutorial entry without granting unrelated discovery
  or changing public map copy. Ordinary runs still enter public L1; no runtime
  tutorial/archetype special case is allowed.
- 2026-08-14 [env06_2] Scenario presentation fields were persisted but had no
  renderer, so authored palette/crowd/signage differences were invisible. PM
  approved one generic cached-snapshot consumer in `PixelSceneCanvas`: palette
  wash, density-scaled ambient silhouettes, and a width-bounded signage strip.
  It must perform no per-frame allocation/RNG/mutation/rebuild and draw nothing
  when fields are absent, preserving tutorial and empty-pool visuals.
- 2026-08-14 [env06_4] Final three-layer visual smoke found the legacy
  `Underground Casino` title plate leaking through public Punchline L1 even
  though map copy was clean. PM required the generic environment header/title
  projection and direct layer-generation display identity to consume the
  flattened current-layer values. No layer/archetype-specific UI branch is
  allowed; final systems/UI/determinism/visual gates must rerun after the fix.
- 2026-08-14 [env06_4] L1 and L3 ship with registered art-manifest slots that
  currently reuse the underground raster beneath distinct code-rendered club
  and back-room scenes. Dedicated final raster art remains an asset need; the
  L3 room is intentionally registered-but-inert until `crew06_6` furnishes it.
- 2026-08-14 [town06_2/env06_2] First-visit pre-seeding must cache the exact
  canonical selector result separately from its public rumor snapshot. This
  preserves tutorial identity-only scenario pins with suppressed mutations and
  preserves full authored mutations for ordinary pins without a second draw.
- 2026-08-14 [env06_3/town06_3] PM scenario-pressure seam: Police Sweep
  adjacency targets stable ids `back_alley_cruiser_parked` and
  `pawn_shop_serial_check_day` through the existing scenario-weight API.
  Serial-Check Day may also declare `law:pressure`; missing ids/tags remain
  inert so either branch integrates independently and Grand Casino stays out.
- 2026-08-14 [env06_3] Grand Casino scenario mutations are constrained to
  presentation, crowd, comps, and heat. Gala and Convention expose only their
  inert identity flags; Audit additionally exposes the inert
  `heist_plan_a_criteria` anchor. Invite, chips, Players Card, and showdown
  flows retain their production gates and are covered under all three nights.
- 2026-08-14 [town06_3] Sweep truth stays hidden until earned: public town
  APIs remove its happening id, flag, current node, and heading; `sweep_status`
  is capability-gated and read-only, while `report_sweep_intel_at_boundary`
  explicitly records a stale last-known marker at an action boundary.
- 2026-08-14 [town06_3] Sweep travel delays are source-owned. The production
  wait action appears only for a `police_sweep` lock; an Engine Trouble or
  other foreign lock is preserved and receives the tuned fine/debt fallback.
  Knuckles stash, Numbers pause, and Streets patrol-density seams are
  registered but inert for their owning slices.
- 2026-08-14 [Wave C] PM collision arbitration: the four Stage-1 game slices
  keep `data/games/games.json` additions isolated by stable game id. PM merges
  one reviewed branch at a time; every later branch must merge current `main`
  and retain all earlier registrations before its integrated-tree gates run.
  The existing Grand Casino result router remains the sole chips seam.
- 2026-08-14 [streets06_1/crew06_3] Streets owns and freezes the public
  multi-stop route contract at its acceptance review. Numbers consumes that
  API without a parallel route engine. Normal travel remains untouched unless
  an accepted job or route explicitly declares a Streets surface.
- 2026-08-14 [crew06_2/crew06_3] Poker is the first L3 furniture owner. The
  later Numbers desk must merge against the landed poker layout, use a distinct
  generated spot, and prove both interactables remain reachable and clear of
  overlay text at 1280×720.
- 2026-08-14 [craps06_1] The prompt's three Grand Casino table rooms map to
  `grand_casino`, `grand_casino_high_limit`, and `grand_casino_back_room`;
  the Cage remains excluded. Craps registers alongside the Back Room payload,
  while the sacred Rourke showdown must remain blackjack-only and receive an
  explicit behavior-compatibility regression.
- 2026-08-14 [craps06_1] PM rules/liveness review required pre-roll pending
  Come odds to join already-working Come odds before settlement, without
  treating a newly placed Come bet as established. Craps idle liveness must be
  a visibly moving, reduce-motion-safe surface element with a changing
  game-specific signature and zero full-snapshot refreshes, not only a generic
  redraw counter or `surface_animates_idle` declaration.
- 2026-08-14 [streets06_1/crew06_3] Streets uses full mid-run serialization
  and freezes one RunState-owned consumer surface: `streets_begin_multi_stop`,
  `streets_begin_hold`, `streets_begin_chase`, `streets_apply_action`,
  `streets_snapshot`, and `streets_has_active_run`. Numbers must consume these
  APIs unchanged; undeclared travel paths never enter a Streets board.
- 2026-08-14 [streets06_1] Route-backed Streets boards serialize an optional
  one-shot `travel_continuation` and expose only whether one is pending.
  FoundationMain consumes it after any terminal Streets outcome through the
  existing `_travel_to` pipeline, so destination, cost, risk, time, and
  generation remain owned by normal travel. Package routes opt in; Hold and
  direct fixtures omit it. Declined or invalid ordinary travel never creates a
  board.
- 2026-08-14 [streets06_1] Consumers may author
  `fast_threshold_actions`, `spot_heat_per_new_spot`, and a success-side
  `clean_speed_bonus_cash`. A speed bonus requires both a threshold-fast and
  clean resolution; spot heat writes once per distinct spotted transition and
  is hidden from snapshots. The shipped Crew favor leaves spot heat at zero so
  its legacy +22/+4 success and +9 failure contracts remain exact.
- 2026-08-14 [streets06_1] Clear-weather running crosses two cells; an
  alley or blackout traversal crosses three with exposure or seeded-hazard
  tradeoffs; adverse weather limits it to one while shrinking sight. Cruiser
  Parked adds patrol density through an authored scenario field read from route
  endpoints, without leaking scenario identity. The Streets pulse exists only
  while its overlay is open and is killed/reset on hide.
- 2026-08-14 [push06_1] Quarter Falls uses one deterministic action-boundary
  coarse-pile core. Corner Store may seed an optional zero-or-one game slot;
  no machine is forced into every node. Alarm tolerance remains hidden, and a
  hard alarm is nonterminal: it locks only that machine, writes heat/memory,
  and leaves the environment plus its other games playable.
- 2026-08-14 [push06_1] Quarter Falls uses its own default-enabled Coin Pusher
  Pack; the shipped Slot Pack remains slot-only so One Machine is
  behavior-identical. Cold Quarters and Coin-Return Shim are shared across both
  packs and are accepted only with tests that consume their authored effect keys
  on real drop/gutter actions; their shipped 3/3 fallback tunings remain
  unchanged for legacy or disabled-content saves. World-map discovery capacity
  counts only guaranteed machines: a required-free `[0, N]` pool stays optional
  and cannot perturb shipped early-route ranking, while environment generation
  still rolls its authored availability normally.
- 2026-08-14 [craps06_1] Craps die sides and line-result totals are authored
  data consumed by both resolution and RTP probes. Payout-luck coverage must
  select a deterministic natural-producing stream and assert the exact shared
  payout seam; surface animation state may not depend on process uptime.
- 2026-08-14 [push06_1] Pusher force/push maps, lane approach identity, and
  visible prize riders are framework-owned data/surface contracts. During a
  Police Sweep, the channel's recorded base tolerance plus the explicit pusher
  delta is authoritative; adding that delta to TownState's already-loosened
  visible band would double-count the same override.
- 2026-08-14 [streets06_1/crew06_3] Every accepted Streets verb consumes one
  model action. A terminal Hold signal evaluates its authored window on the
  pre-action tick, then records the action/deadline boundary without another
  patrol or sight pass. Clean resolution is historical: any earlier spotting
  prevents a later stash escape from restoring the clean-speed bonus.
- 2026-08-14 [crew06_2/crew06_3] Back-Room Poker furnishes the existing empty
  L3 shell with one stable game spot and accepts future `resident_member_ids`,
  using a seeded 2-3 member rotation until crew itineraries land. Hidden tell
  progress serializes only under neutral `p`/`m` keys; authored tell ids,
  conditions, exposure labels, and counters remain absent from public results,
  logs, and UI. Numbers must add a distinct reachable furniture spot later.
- 2026-08-14 [streets06_1] A Streets verb advances its single environment/town
  boundary before newly earned spotting or terminal effects are applied, so
  fresh heat cannot decay on the action that created it. A linked Crew job is
  protected from expiry only until the resolved board applies its world result,
  then the existing job API owns trust exactly once.
- 2026-08-14 [push06_1] The 200-action determinism session exercises exactly
  one production hard alarm, normal heat, next-night unlock, and then completes
  validated drops from sufficient up-front bankroll. It never resets heat,
  bypasses wagering, or injects mid-session cash merely to keep the probe alive.
- 2026-08-14 [crew06_2] PM scope review rejected a data-only tell-channel
  projection: authored `line`, `portrait`, and `timing` channels must each alter
  the production table presentation while keeping the learning model hidden.
  Direct/out-of-phase resolver calls must also reject atomically so an irregular
  mid-hand cash-out cannot strand the table. The correction is committed, but
  integrated acceptance remains pending a clean runtime compile and full gates.
- 2026-08-14 [crew06_3] PM scope review rejected an API-only Numbers slice as
  not player-playable. Venue slips, Silas, Lucky's route/fix entry, and the L3
  allocation step must be reachable through production interactions and visual
  QA; tests calling RunState APIs directly do not satisfy the zero-trust playable
  route or operation requirements. Hidden past-posting must remain unadvertised.
- 2026-08-14 [push06_1] Presentation entry and surface reads are serialized-
  state-pure. Pile-rumor publication belongs to generation/action boundaries;
  staff-watch, scenario-reset, and owned-shim normalization persist only when a
  real action begins (or in the canonical generated state), never while opening
  or sweeping a surface. Dedicated runtime acceptance is pending rerun.
- 2026-08-14 [craps06_1] Canonical visual acceptance remains red because the
  deterministic dice fixture is not entering the production rolling phase.
  The assertion stays binding; PM returned the slice for exact clock/state-path
  diagnosis rather than accepting a timing guess or weakening visual coverage.
- 2026-08-14 [craps06_1] Final acceptance preserved the production clock and
  corrected it to remain live while the run is paused, propagated the shared
  reduced-motion setting through the game-surface snapshot, and matched Grand
  Casino placement capacity to all seven authored objects (7/7, 4/4, and 2/2
  rooms now prove zero overlap). PM independently verified the complete bet
  surface, dice motion, idle liveness, and static reduced-motion capture.
- 2026-08-14 [craps06_2] The scenario's exclusive `game_id` correctly makes
  Street Craps playable in a seeded starting Back Alley; this exposed a UI
  victory fixture that assumed finding a game always required travel. The
  fixture now explicitly performs real travel before asserting replay timing,
  preserving both production injection and every travel/report assertion.
- 2026-08-14 [push06_1] Reduced-motion acceptance uses the real settings-apply
  boundary, because the lower-level accessibility styling helper does not
  rebuild active game snapshots. Focused and canonical proofs now require a
  frozen motion signature, zero redraws, no continuous redraw, and unchanged
  visible pile/rider/tell state.

- 2026-08-14 [fix06_1] Owner reported scenario event icons with no apparent
  action. PM headless probes (15 seeds, all archetypes + Punchline L2): 39/42
  scenario events pass the real interaction chain (`can_trigger` + `choices`);
  the 3 beach events are confirmed dead icons. Root cause: ContentLibrary
  normalization injects a default speaker with `environment_actor: true`, and
  `EventModule._environment_allows_room_actor` hard-denies kind `recovery` and
  archetype `beach`, so `can_trigger` silently fails after icon placement.
  Earlier static suspicion about Punchline L2 scope was a false alarm — layer
  flattening presents kind `casino` at runtime and all 3 L2 events verify OK.
  Remediation prompt `fix06_1` authored (generic normalization fix + permanent
  interactability class-guard test + UI click-through). The class gap that let
  this survive Wave B acceptance: no automated test walked authored
  interactable events through `can_trigger` in generated host environments.

- 2026-08-14 [board] OWNER DECISION — Wave E is no longer a ship wave. It
  terminates in an owner playtest handoff, not a release. 0.6 is expected to be
  ~50% complete at handoff; the post-playtest polish and cleanup pass is the
  second half of the update. `release06_1` is PARKED (it holds all release
  activity: version, balance, packaging, tag, publish, owner gates).
  `voice06_1` is PARKED because a register pass must read final strings and the
  playtest is expected to rewrite them. New terminal task `playtest06_1`
  authored: verification, playability sweep, honest state-of-the-update handoff
  report, local owner build — explicitly no version bump, no tag, no packaging
  for distribution, no publish copy, and no final balance tuning (the owner's
  feel notes are the intended input and pre-tuning destroys that signal).
- 2026-08-14 [fix06_1] Full catalog audit found 99 events: 32 authored-speaker
  and 67 synthesized-speaker definitions. The generic normalization correction
  changed `can_trigger` only for the three recovery-hosted beach scenario events
  (`false` to `true` with choices); every other host observation was unchanged,
  and `_environment_allows_room_actor` remains intact.
- 2026-08-14 [fix06_1] The permanent `interactable_event_class_guard` now runs
  in foundation `systems` and `all`: ten seeded base generations cover every
  archetype, every authored scenario overlay is exhausted, all Punchline layers
  are entered, authored conditional dormancy is isolated through the condition
  override diagnostic, and a broken synthesized-speaker fixture proves the
  guard fails when the defect returns.

- 2026-08-14 [board] STATE AUDIT (owner-requested). On `main`: Wave A (3),
  Wave B (5), `streets06_1`, `fix06_1` = 10 rows. Wave C's remaining six rows
  (`craps06_1`, `craps06_2`, `push06_1`, `push06_2`, `crew06_2`, `crew06_3`)
  are built on per-task branches consolidated at `codex/wave-c-integration`
  (`daca04d3`) and are **not merged to `main`** — `data/games/games.json` on
  `main` still lists only the original 8 games. Board rows for `push06_2` and
  `craps06_2` also read stale vs. actual branch work. Wave C is
  complete-but-unaccepted, not stalled: remaining work is determinism, visual
  QA, the final matrix, then merge/closure.
- 2026-08-14 [board] OWNER REJECTION — two Wave C systems fail in play and are
  being reworked, with the roadmap design sections rewritten first. (1) The
  Streets board: a synthetic `{x,y,kind}` grid disconnected from the world;
  replaced by delivery-on-the-real-map (`rework06_1`). (2) The coin pusher: an
  abstract per-lane integer height grid with an edge-hang boolean; replaced by
  a real discrete-coin simulation with stacking, gravity, multi-level falls,
  and per-variation bonus sub-games (`rework06_2`). Root cause in both cases is
  the original prompt spec, not agent execution — `streets06_1` was told to
  build a "stylized block board" and `push06_1` was told to build a "coarse
  pile model… not free physics". Craps, poker, and Numbers are not implicated;
  Numbers must re-point its route consumption onto the new delivery API.
- 2026-08-16 [Wave C acceptance] Code audit confirmed all six remaining Wave C
  slices are consolidated at `codex/wave-c-integration`; post-consolidation
  Numbers visual correction `b7d18f68` was missing and was integrated as
  `42438b5d`. The unchanged final matrix is red only on the combined tree while
  `main` passes the focused baselines: Punchline L2 canonical layout drift,
  Roulette settled-frame continuity, two unhandled Coin Pusher action bindings,
  missing `game_action` ActionResult identity, and Scratch Ticket resolve average
  1.708 ms > 1.500 ms. Acceptance repair is delegated; no assertion or budget is
  waived. Numbers' old Streets dependency remains explicitly pending rework06_1.
- 2026-08-16 [Wave C acceptance] Root repairs landed without weakening gates:
  canonical Punchline L2 data was restored while L3 now explicitly owns the
  Numbers desk at `[680,240]`; Roulette final/settled motion is continuous;
  Coin Pusher surface commands match their advertised bindings; omitted game
  action types again default to `game_action`; and Craps now has an explicit
  nonzero idle-liveness floor. The Numbers visual QA was corrected to the
  established PixelSceneCanvas schema and strengthened to exercise the real
  Crew Poker object plus DITCH/travel/stranded consequences.
- 2026-08-16 [Wave C acceptance] One isolated default performance run produced
  a non-reproducible Scratch Ticket max spike (5.395 ms > 4.000 ms). No budget
  or assertion changed. The next two PM runs passed with max 1.875/1.424 ms;
  agent runs also passed (max 1.270 ms and focused max 1.615 ms). Acceptance is
  based on the unchanged gate's repeated clean results, not a waiver.

- 2026-08-16 [pusher] Owner asked what a full physics/3D coin pusher rebuild
  would take, against an external analysis recommending 3D with "hybrid"
  physics (physics runs; the old model still decides payouts; a reconciliation
  layer resolves divergence) at 7–18 months. Assessment recorded in
  `docs/plans/0.6_coin_pusher_simulation_plan.md`. Headline judgments: (1) the
  hybrid recommendation reproduces the rejected defect — a coin that visibly
  lands in the tray while a reconciler decides otherwise is the most visible
  way a machine can lie, so the simulation must be AUTHORITATIVE; (2)
  determinism is solved by owning a small fixed-point solver, not by
  reconciling non-deterministic engine physics; (3) 3D is a project-level
  commitment here (zero `Node3D`, zero 3D assets, `mobile`/`gl_compatibility`
  renderer, 5 ms surface budget) and is not what produces the feel —
  authoritative simulation plus layered audio is. Recommended path: 2.5D
  authoritative solver behind a renderer-agnostic snapshot, which keeps 3D
  available later as a rendering project rather than a gameplay rewrite.
- 2026-08-16 [pusher] PLAN CORRECTION: the phase plan was drafted assuming the
  rebuild had not started — it had. `rework06_2` already contains a real
  fixed-point discrete-body solver (60 Hz fixed step, integer coordinates, two
  tiers with gravity/drag, spatial-hash collisions, support resolution for
  stacking, sleeping, `body_views` snapshot, `canonical_digest`, height-grid
  migration, cross-platform export parity runner) with the surface consuming
  it. `pusher06_0` is therefore demoted to optional measurement/hardening and
  `pusher06_1` to a reference acceptance checklist; only `pusher06_2` (feel and
  audio depth), `pusher06_3` (variation distinctness) and `pusher06_4` (venue
  integration and persistence at scale) are genuinely remaining. Do not restart
  or redirect `rework06_2`.

- 2026-08-16 [rework06_2] OWNER CLARIFICATION: not literal 3D. The requirement
  is **3D-logical behavior with 2D representative graphics** — coins pushing
  each other with random placement, stacked coins, coins hanging off the edge,
  all driven by a complex simulation and drawn in 2D. The landed solver already
  satisfies the logic side: bodies carry x/y/z, two floor tiers with
  `upper_to_lower` transitions, support resolution for stacking, and edge-hanger
  tracking. No architecture change needed.
- 2026-08-16 [rework06_2] STATE + VISUAL AUDIT. Branch `codex/rework06-2`:
  8 commits ahead of main plus uncommitted work and a new
  `coin_pusher_solver_api.gd`. Gates recorded green — `final_all_green`,
  `merged_all`, focused `foundation_coin_pusher` (0 failures), Windows-vs-Web
  export parity with a comparison report, and six feel captures. **Close to
  commit on correctness.** However, inspecting the captures directly: the
  simulation is genuinely running (`PHYSICAL PROOF collisions/moved/topples`
  counters are real) but the machine **does not look like a coin pusher**.
  `coin_cap` is 48 across 5 lanes, so the playfield renders as a sparse
  scatter of isolated dots; stacking is simulated but not legible; edge hangers
  are tracked but not visually readable; the lane grid dominates. The gap is
  density and rendering, not simulation. `pusher06_2` retargeted as the V2
  headline task: raise the cap toward 150–300, pack/overlap/randomize
  placement, make stacking and ledge-hang legible, then audio. Acceptance bar
  raised from "counters incremented" to "a person shown the capture calls it a
  coin pusher."

- 2026-08-16 [teach06_1] Discovery/deviation: the systems wrapper exceeded its stored wall-time budget on both the feature branch (50.095s) and untouched main (51.283s), while all assertions passed; the budget and gate were not changed or waived. Serialized owner acceptance supplied the final UI PASS, 10-seed/590-checkpoint determinism hash `3483570349`, and canonical 75-state/zero-warning visual result.
- 2026-08-16 [teach06_1] Decision: normal-run advice admits at most one contextual beat, yields without consuming the player's next action, and uses deterministic public-control geometry to keep its clickable Skip tip away from gameplay where a clear standard placement exists. Guided tutorial queue, pointer, and completion behavior remain unchanged.

- 2026-08-17 [pusher06_2 final performance] The shipped target is cap 160
  with a 150-body uneven opening pile. The authoritative post-fix probe passes
  without reductions: Drop resolve 15.798 ms, draw p95 4.249 ms, frame p95
  6.923 ms; collapse Nudge resolve 14.820 ms, draw p95 4.090 ms, frame p95
  6.922 ms; raw native p95 10.276 ms across 32/32 native samples. Both actions
  retain 14 replay frames, zero full snapshots, and physical collapse. The
  renderer/audio consume packed snapshot/event publication only; batched 2.5D
  drawing remains presentation-only, while the exact transactional native core
  retains the dictionary solver as oracle/fallback.
- 2026-08-17 [pusher06_2 export parity] Exact 200-action Windows and Web
  release replays pass 200/200 through the native backend with identical input
  `1941cd44d4352625f155fb577bfc9be1d1c562c8a3094dfcc9683ac7f0a6c992`,
  outcomes `8826fed66846ee2e1dec7ec03eb6b6571678855e12f799300cb23efb36866b9a`,
  backend `5ea048d38c166330d5f537d4f59e029eedf2819fa6dc0ec04fd791d25f7e51af`,
  and captured final frame
  `a5331a9a5610d065edf6bf337a4b5db334049b3c4fa6fbddb8a2537ed697950a`.
  The Web-only out-of-bounds crash was traced to cached packed-array writable
  pointers crossing Godot `String` operations; `9bbdd037` now owns rows in a
  native vector and scopes every primitive pointer fill, with string columns
  published through safe setters. Fresh itch packages contain exactly one
  byte-identical release native module and no saves/debug/development material.
- 2026-08-17 [pusher06_2 feel verdict] All seven required scenarios, five
  advancing 14-frame replay sheets, and five tell-ladder stages pass in
  `.tmp/pusher06_2_final_feel_captures` at 1280x720. Independent visual review
  calls the packed, overlapping, stacked field, two shelves, edge hangers,
  tray/gutters, and alarm progression unmistakably a real coin pusher. Unused
  black canvas in composite evidence sheets is non-blocking and not in-game.
- 2026-08-17 [pusher06_2 Web diagnostic] Optional global Web smoke evidence is
  preserved without waivers or unrelated edits. Grand Casino gameplay frame
  and memory scenarios pass, with cold startup 20,013 ms versus 20,000 ms;
  `l02` also reports startup 20,503 ms, Corner Store open 2,193.790 ms, and
  Blackjack idle p95 50.000 ms against their existing global budgets. These
  systems are outside this density/presentation/audio row and none of the
  binding prompt gates or coin-pusher budgets failed.

## Work Log

- 2026-08-17 [pusherv3_1] OWNER RULING (Amendment 6.1): the geometry
  contradiction was real and the stop was the correct behavior. Axis kept
  (+y rearward); FACE_MIN/MAX labels were backwards and are replaced by
  FACE_EXTENDED_Y=28000 / FACE_RETRACTED_Y=46000 with BACK_PLATE_Y=63000 —
  the re-derivation also fixed a latent flaw where the platform top emptied
  every cycle (plate-to-retracted-face gap was 4000 < one coin). Corrected
  invariants now hold: ~2 rows of top stock always riding, collective queue
  deposit at ~1 queued row, ~20% apex-dwell deck-landing skill window,
  full-height face collider. Contract sections 3.1-3.4 amended in place;
  pusherv3_1 unblocked.

- 2026-08-17 [pusherv3] OWNER DESIGN SESSION (round 6) — V2 machine model
  rejected after direct play and a full walkthrough of the code. Locked: one
  reciprocating platform whose top carries coins (ratchet transport via back
  plate, no scripted ratchet code); landing-position timing as the core skill
  (no phase scalars); free costless skill stop with smooth ramps; machine runs
  continuously while present, settles and freezes on exit, never simulates
  while absent; physical tray requiring collection before money credits;
  insert = one world action, chute/stop/collect free; contact solver rebuilt
  (radial normals, 6-pass relaxation, restitution/friction, multi-contact
  nestle rule — fixes the observed crystallize-into-rows and pile-explosion
  defects); coin ceiling is a safety net designed to be unreachable and inserts
  are refused, coins never deleted; per-machine data-driven apparatus (QF rail
  slot + 3 pegs, Ridge 3-hole plinko, third TBD) and playfield geometry;
  settled-state-only ~2 KB persistence; full alive cabinet at slot parity.
  Contract: `docs/plans/coin_pusher_v3_machine_rework_plan.md`. Prompts
  pusherv3_1..4 authored (strictly serial). pusher06_0/1/3/4 superseded;
  pusher06_2's density/audio work partially carries forward via the landed
  render improvements but its model-level assumptions are replaced.

- 2026-08-17 [fix06_2] Reproduced mutation diff and call path: info-card activation routes `activate_interactable_object()` → `enter_game()` → `_enter_game_after_input_guard()` → `CrapsGame.enter()`, which changed `narrative_flags.street_craps_guidance_seen` from absent to `true` solely while composing the first-entry message. The generated Craps table and RNG state were otherwise unchanged. Diagnosis: craps06_2 attached once-only teaching consumption to navigation instead of a successful action boundary. The Grand Casino sibling uses the same rules/table module but not the Street guidance branch and did not mutate.
- 2026-08-17 [fix06_2] PM:Codex claimed the shipped Street Craps activation-mutation defect; M1.6 remains binding, the repair must be generic across game activation, craps06_1 shares the audit scope, and env06_5 acceptance resumes only after this row lands.

- 2026-08-16 [art06_1] CLOSED — FALSE PREMISE, author's error, not the executing agent's. Verified against code: `scripts/ui/pixel_scene_canvas.gd` draws EVERY environment procedurally through a `scene_type` dispatch, and no raster-background load path exists anywhere in `scripts/ui/` — `visual_context.asset_path` is metadata the scene canvas never consumes. `_draw_punchline_club()` (~1236) and `_draw_punchline_back_room()` (~1269) already exist, are already dispatched, and sit at detail parity with shipped venues (27/22 lines vs `_draw_bar` 26, `_draw_underground` 26); the club already renders a stage, mic stand, neon, two-drink tables, patron silhouettes, and a plain side door with no gambling signifier. The reported blocker ("in-run rendering uses procedural rooms rather than registered rasters") describes the architecture working as designed for every venue in the game. The executing agent's refusal to patch the UI/module seam under this prompt's ownership rules was CORRECT and prevented an unnecessary architectural change. Root cause: env06_4's art-debt note was misleading (the reused rasters are never rendered; the code scenes were already distinct and complete), and the art06_1 prompt compounded it by assuming rasters drive environment visuals. New PNGs retained as metadata-only — strictly better pointers than the previous underground paths. Any future concern about the Punchline's look is a new scoped row against the DRAW FUNCTIONS, never a rendering-architecture change.
- 2026-08-16 [env06_5/fix06_2] env06_5's UI gate exposed a SHIPPED defect in landed `craps06_2`, not a defect in env06_5: activating Street Craps from the info card mutates serialized RunState, violating the M1.6 invariant at `compile_components_and_main_flow.gd:3646` that opening a game is navigation, not play (siblings at 3506/3543/3562 enforce the same rule for focus, hover, and clear-focus). Beyond the test, mutate-on-open breaks save/restore honesty and determinism guarantees. Remediation row `fix06_2` authored; env06_5 acceptance resumes once it lands. Reverting the prohibited scenario-weight workaround was the right call — the invariant is not negotiable.
- 2026-08-16 [teach06_1] DONE; seven public-surface lessons now teach scenarios, delivery routes, honest Numbers play, crew standing, coin pushers, craps, and unnamed venue depth at first encounter. The guided 56-lesson prefix is byte-identical, the 19-phrase discovery audit has zero hits, all gate assertions are green, and ambient advice can no longer consume or physically cover the player's next action.
- 2026-08-16 [teach06_1] Codex claimed contextual onboarding for public 0.6 surfaces; discovery-gated systems and the shipped guided tutorial remain explicitly out of scope.
- 2026-08-13 [board] Queue authored: 24 prompts across waves A–E.
- 2026-08-13 [Wave A] PM-orchestrated execution claimed for env06_1,
  town06_1, and crew06_1; three isolated subagents assigned, with the PM
  owning integration, board updates, verification, and archival.
- 2026-08-14 [Wave A] Integrated engine commits accepted provisionally after
  scope/design review; board completion remains blocked on inherited systems,
  UI-art-contract, and visual-QA failures reproduced by PM gates.
- 2026-08-14 [env06_1] DONE; deterministic first-visit scenario selection,
  phase/snapshot APIs, mutation hooks, and seed-audit tooling now unblock
  env06_2/3/4, town06_2/3, craps06_2, and push06_1.
- 2026-08-14 [town06_1] DONE; run-owned weather/calendar/happenings plus
  scenario, travel, music, economy, and ambient-status read seams now unblock
  town06_2/3, push06_2, and streets06_1.
- 2026-08-14 [crew06_1] DONE; hidden trust/rank/standing, grievance ledger,
  action-boundary jobs, and behavior-identical Crew lender retcon now unblock
  streets06_1 and crew06_2/3/5/6/7/8/9.
- 2026-08-14 [Wave A closure] PM final combined tree PASS: complete
  `foundation_all`, dedicated systems + UI, 10-seed/320-checkpoint determinism
  (`38535979`), visual QA, and headless coexistence. Wave B APIs available:
  `scenario_for_node` plus generation-time scenario overlays;
  `scenario_weight_multiplier`, TownState weather/day/happening/travel/music/
  economy reads; and Crew trust/rank/standing/grievance/job APIs. Registered
  but intentionally inert until later prompts: scenario opportunity/hook flags,
  town blackout flags/music texture consumers, Streets job payload seam, and
  Crew heist eligibility consumers. No owner decision is required. Stop before
  Wave B kickoff.
- 2026-08-14 [Wave B Stage 1] PM-orchestrated execution claimed for env06_2,
  env06_4, and town06_2; three isolated subagents assigned, with the PM owning
  integration, board updates, verification, and archival.
- 2026-08-14 [env06_2] DONE; 17 mechanically distinct tier-1 scenarios,
  exclusive events, recruitment/game hooks, phase arcs, town-weight tags, and
  visible cached presentation now land the launch cut. This completes
  crew06_5's tier-1 dependency; env06_3 remains before that row is claimable.
- 2026-08-14 [env06_4] DONE; The Punchline now exposes persisted public-club,
  hidden-casino, and crew-shell layers through generic boundary APIs while the
  shipped casino payload, tutorial entry, old saves, routes, and Grand Casino
  shortcut remain compatible. This unblocks env06_3, crew06_2, and crew06_6.
- 2026-08-14 [town06_2] DONE; truth-traced rumors and heard previews, seeded
  Dave/Cass/Silas itineraries, and edge-decayed traveling reputation now share
  one serialized action-boundary town network. This unblocks town06_3,
  crew06_3, crew06_9, and chain06_1.
- 2026-08-14 [Wave B Stage 2] PM-orchestrated execution claimed for env06_3
  and town06_3 after env06_4 and town06_2 passed independent integrated-tree
  acceptance; two isolated subagents assigned, with PM retaining board,
  integration, verification, and archival ownership.
- 2026-08-14 [env06_3] DONE; 25 mechanically distinct Tier-2/Grand Casino
  scenarios now supply layer-aware events, deterministic phase/lock behavior,
  Debt Court and Estate Lot production interactions, and the Buyout, Whale,
  Festival, Estate Lot, and Audit heist/recruitment anchors. This completes
  crew06_5's environment dependency and advances crew06_8 toward claimable.
- 2026-08-14 [town06_3] DONE; the seeded 58% Police Sweep now walks a bounded
  3–6-action dwell track for 42–72 actions, never enters Grand Casino, emits
  truth-sourced rumors and stale sightings, applies costed heat/contraband/debt
  encounters, and leaves a five-action security wake. This unblocks
  streets06_1 and the full Police Sweep scope of crew06_3.
- 2026-08-14 [Wave B closure] PM final combined tree PASS: exhaustive
  `foundation_all` plus all-script parse (`wave_b_final_full`), 10-seed / 320-
  checkpoint determinism (`1234044898`), visual QA, and one-run production
  composition. The launch catalog contains 42 scenarios: corner store 4,
  back alley 3, motel 3, bar 4, gas-station casino 3, Punchline 6, jazz club 3,
  Kitty Cat Lounge 3, Delta Queen 4, beach 3, pawn shop 3, Grand Casino 3.
  Wave C/D-facing APIs and anchors now live: first-visit `scenario_for_node`;
  truth-traced rumor registry/heard previews; traveler state; capability-gated
  `sweep_status`, boundary reporting, and `swept_window`; Punchline layer
  discovery/entry; recruitment anchors for Knuckles, Switch, Mags, Velvet, and
  Lucky; Plan A Audit and Plan B Whale/Estate flags. Registered but intentionally
  inert until their owning prompts: `street_craps`, Punchline L3, recruitment
  consumers, heist consumers, Knuckles stash, Numbers pause, and Streets patrol
  density. No owner decision is required. Stop before Wave C/D kickoff.
- 2026-08-14 [Wave C Stage 1] PM-orchestrated execution claimed for
  craps06_1, push06_1, streets06_1, and crew06_2 after verifying all Wave A/B
  rows and landed seams. Craps, pusher, and Streets take the three available
  subagent slots; poker is queued for the first released slot. PM retains
  single-writer board, integration, verification, archival, and push ownership.
- 2026-08-14 [crew06_2] The queued Stage-1 slot opened and the isolated Poker
  owner started. PM froze the first L3 furniture and neutral tell-storage seams;
  board, archival, integration, runtime grants, and push remain PM-owned.
- 2026-08-14 [streets06_1] DONE after PM integrated-tree scope/design review,
  full systems/UI gates, 10-seed determinism, and player-facing visual QA for
  package, ordered multi-stop progress, and Hold signal resolution. The frozen
  multi-stop/Hold/chase APIs now unblock crew06_3, crew06_6, and crew06_8;
  ordinary travel remains unchanged unless a consumer explicitly opts in.
- 2026-08-14 [crew06_3] Wave C Stage 2 Numbers execution claimed after PM
  accepted and archived Streets. The owner must consume the frozen multi-stop
  API unchanged and add a distinct reachable L3 desk beside Poker's reserved
  table position; PM retains board, integration, verification, and push.
- 2026-08-14 [craps06_1] DONE after integrated PM acceptance of the complete
  Craps rules/chips/save/cheat surface, million-roll RTP, systems/UI, 10-seed
  determinism, canonical visual QA, and focused table/liveness captures. The
  stable rules engine and Grand Casino surface now unblock craps06_2 and the
  Craps dependency of crew06_8.
- 2026-08-14 [craps06_2] Wave C Stage 2 Street Craps execution claimed after
  PM accepted the shared Craps rules engine and env06_1 modifier seam. The
  subagent owns implementation in isolation; PM retains board, archival,
  integration, runtime verification, and push ownership.
- 2026-08-14 [craps06_2] DONE; the scenario-only cash circle reuses the casino
  rules engine, teaches Pass/Don't, fairly refunds on sweep/heat dispersal,
  grants optional setting practice, and proves exact core RTP parity. Focused
  and canonical visuals, systems/UI, and 10-seed determinism pass.
- 2026-08-14 [push06_1] DONE; Quarter Falls now supplies the deterministic
  action-boundary pile, universal nudge/tell/alarm system, node persistence,
  prize riders, rumor/reputation seams, and machine-only lockdown. All gates
  and five focused visual states pass, unblocking push06_2.
- 2026-08-14 [push06_2] Wave C Stage 2 Pusher variations execution claimed
  after PM accepted the shared pile/nudge/alarm engine and town-state seams.
  The subagent owns isolated implementation; PM retains board, archival,
  integration, runtime verification, and push ownership.
- 2026-08-14 [fix06_1] Codex claimed the dead scenario event interaction fix;
  implementation will repair the generic normalization seam and add a permanent
  generated-environment interactability class guard plus UI click-through.
- 2026-08-14 [fix06_1] DONE; generic actor-free speaker synthesis, exhaustive
  catalog audit, beach consequence resolution, permanent icon-to-action guard,
  and generated Bonfire context-card mouse click-through passed all required
  gates. Crew06_5 and later event-bearing rows now inherit the class guard.
- 2026-08-16 [Wave C acceptance] PM resumed the consolidated tree, integrated
  the missing zero-trust Numbers visual correction, reproduced six combined-tree
  gate failures against clean `main` baselines, and delegated exact root-cause
  repair before determinism, visual QA, merge, or closure can proceed.
- 2026-08-16 [Wave C original implementation closure] Six consolidated rows
  are DONE and merged after an exact-tree full matrix, all-script parse,
  10-seed/580-checkpoint determinism (`231360296`), canonical visual QA, and
  focused 1280x720 review all passed. APIs now available downstream: shared
  Craps rules/table state plus Street Craps training/dispersal; Coin Pusher
  variation content and nudge/alarm/persistence contracts; deterministic Crew
  Poker policies, hidden tells, learning, and trust writes; and Numbers
  draw/slip/fix/past-post/leak/economy state. Two seams remain explicitly
  superseded rather than silently accepted: rework06_1 replaces synthetic
  Streets and must re-point Numbers delivery consumers; rework06_2 replaces
  the abstract pusher simulation while preserving visible features.
- 2026-08-16 [Rework Stage] PM claimed rework06_1 and rework06_2 for parallel
  isolated execution after the original Wave C merge passed post-merge
  validation. Delivery must replace the synthetic grid with normal real-map
  travel and re-point Numbers consumers; Coin Pusher must replace the height
  grid with deterministic fixed-point individual-coin simulation. PM retains
  single-writer board, integration, acceptance, archival, and push ownership.
- 2026-08-16 [rework06_1] PM accepted one delivery contract: schema-versioned
  `delivery_*` state selects reachable generatable real nodes, exposes courier
  truth through the existing map overlay, routes every move through normal
  travel, and completes handoffs inside generated venues. Numbers now consumes
  multi-stop delivery directly; crew06_6 jobs and crew06_8 getaway inherit the
  same registered API. No synthetic-board compatibility shim remains.
- 2026-08-16 [rework06_1] DONE after PM line-by-line scope/design review and
  exact integrated-tree verification: 235/235 full-matrix stages, 10-seed /
  590-checkpoint determinism (`3483570349`), 20-seed real-node property proof,
  byte-identical inactive travel, no-soft-lock regressions, and zero-warning
  visual QA. This unblocks crew06_6 delivery jobs and crew06_8 getaway routing.
- 2026-08-16 [art06_1] Codex claimed the Punchline L1/L3 final-raster art
  pass; work is confined to new assets, manifest entries, and Punchline
  `visual_context` paths, with current L3 crew furniture areas reserved.
- 2026-08-16 [art06_1] Discovery/deviation: branch and untouched-main visual
  reports have the exact same failure vectors. Scenario reports show
  `punchline_high_stakes_night=1`, `kitty_cat_lounge_amateur_night=1`, and
  `kitty_cat_lounge_buyout=1`; Punchline layer reports show `club=0`,
  `casino=1`, `back_room=0` with the inherited L2 Video Poker/Numbers Book
  overlap. Branch reports: `.tmp/art06_1_scenarios/report.json` and
  `.tmp/art06_1_layers/layout_report.json`; untouched-main reports:
  `.tmp/art06_1_baseline_scenarios/report.json` and
  `.tmp/art06_1_baseline_layers/layout_report.json`. L2/layout are outside
  art06_1 ownership and were not changed.
- 2026-08-16 [art06_1] DONE; dedicated comedy-club and crew-room-shell rasters
  now replace L1/L3 placeholder reuse while L2 remains unchanged. L1 has no
  gambling signifier; exact L3 landed/reserved footprints remain clear;
  Open Mic/Headliner presentation, full UI, and canonical visual QA pass.
  Systems assertions are zero-failure; final wall-time acceptance is serialized
  by PM because three concurrent Godot worktrees exceeded the unchanged budget.
- 2026-08-16 [concurrency correction] Root PM mirrored active `env06_5` and
  `teach06_1` execution onto the authoritative board. `art06_1` was reopened
  after independent acceptance found that its registered L1/L3 raster paths
  are not consumed by the normal in-run Punchline renderer; the prior DONE
  record is retained above as history, not accepted closure.
- 2026-08-16 [rework06_2 acceptance] Canonical performance coverage originally
  omitted Coin Pusher. PM sent the row back for a shipped-cap idle/active/raw
  solver probe and output-identical solver allocation repair. Coin Pusher now
  clears its unchanged active frame/draw budgets at 48 bodies and the exact
  200-action outcome remains `a0f59c62...`; closure is still withheld because
  the quiet combined probe produced a real Baccarat idle-draw assertion at
  5.030 ms versus 5.000 ms. No budget or assertion is being weakened. A
  render-only allocation repair is in progress before the final combined gate.
- 2026-08-16 [env06_5 acceptance] Static scope review accepted all 13 appended
  scenarios and found no hidden-system or wall-clock leakage. PM required a
  clean integrated validation tree because the original worktree contains an
  unexplained, preserved diagnostic edit. That diagnostic exposed a genuine
  UI invariant failure: focusing an existing Street Craps card rewrites
  numerically equivalent game state (JSON floats to ints). Acceptance remains
  open until the clean tree reproduces or clears the assertion.
- 2026-08-16 [teach06_1 acceptance] Production route review found one physical
  activation can notify the coach twice (guard then focus). The first repair
  could mark an intermediate normal tip seen without displaying it. PM required
  yield-without-replacement semantics on the first notification plus a real
  double-notify regression; tutorial behavior remains unchanged.
- 2026-08-17 [rework06_2] DONE. PM accepted the deterministic 60 Hz fixed-point
  discrete-body Coin Pusher at a shipped cap of 48 after exact 200-action
  Windows/Web parity, two matching 10-seed determinism runs, physical-behavior,
  persistence, EV, six-scenario feel, zero-warning visual, and full performance
  coverage. Systems assertions remained fully green and final wall time matched
  the same-load control within 0.38%, satisfying the owner's environmental-only
  timing rule. This closes Wave C and unblocks `pusher06_2`; owner-identified
  visual density and presentation work remains correctly scoped there.
- 2026-08-17 [pusher06_2] PM-orchestrated isolated execution claimed after
  `rework06_2` acceptance. The V2 headline track begins with a performance-set
  dense coin cap and player-readable 2.5D stacking/edge hangers, then snapshot-
  event-driven audio; authoritative outcomes and the accepted solver are fixed.
- 2026-08-17 [crew06_5] PM-orchestrated isolated execution claimed in parallel
  with `pusher06_2`. This recruitment slice owns seven primary/fallback paths,
  diegetic signposting, rank-gated existing perks, seeded presence, and the
  crew-ignoring regression; it unblocks the Wave D jobs/plays chain.
- 2026-08-17 [fix06_2] DONE. Street guidance is now consumed only by a
  successful Street Craps action (including dispersal), never by `enter()`.
  Street and Grand Casino Craps both remain byte-stable across activation and
  save/load; open-then-play and direct-play outcomes match at the same seed.
  The permanent generated-environment game activation guard covers every
  production module and rejects a hostile mutate-on-enter fixture. Systems and
  UI assertions, 10-seed determinism, and 75-state visual QA are green;
  systems wall time was baseline-equivalent (52.277s versus the accepted
  rework control's 51.780s) with the stored budget and assertions unchanged.
  `env06_5` acceptance is unblocked.
- 2026-08-17 [env06_5] DONE. Accepted all 13 backlog scenarios and their 13
  `scenario_`-prefixed exclusive events without modifying legacy events. The
  audit reports 55 total scenarios (42 launch + 13 backlog), every scenario
  reached in 20 seeds, no launch crowd-out, correct Punchline casino-layer and
  tutorial-neutral behavior, and all three authored phase arcs surviving
  mid-phase save/load. Inventory Night, Storm Shelter, and Captain's
  Invitational smoke captures pass with zero overlaps. The two ordinary-travel
  whole-state hashes were exactly recaptured for the authorized catalog change;
  route, cost, clock, RNG, story, heat, and travel-count fields did not shift.
- 2026-08-17 [fix06_2 reopening] The externally integrated closeout at
  `11f55f41` is superseded for this row. Its guard settled mutating room
  presentation before comparison, covered only four hooks, reused warm state,
  and did not exercise non-default generated fixture keys. The PM's stronger
  seven-hook cold-state/JSON-restored guard reproduced seven passive
  `staff_assignment_day` writes across Grand Casino Blackjack and Roulette.
  Row returned to IN_PROGRESS; no prior assertion was weakened. `env06_5`
  remains DONE on its independently verified content/audit/capture scope.
- 2026-08-17 [systems gate] Integrated deterministic sharding merged at
  `5a967b75` after independent behavioral safety review and a green 37.260 s
  run under the unchanged 43.712 s budget. All 49 systems checks retain their
  exact assertions and canonical report order while executing once across four
  isolated project/cache roots; aggregate failures, raw exits, stderr,
  timeouts, last-started diagnostics, cleanup failures, and cleanup wall time
  remain fail-closed. This removes the harness-only release-gate bottleneck;
  combined-main verification remains the final acceptance authority.
- 2026-08-17 [systems gate] Combined-main acceptance is green at `e28c67a5`:
  40.211 s / 43.712 s, 49/49 unique checks, four clean shards, zero failures,
  and complete private-project cleanup. The live reruns also removed volatile
  cache traversal (`6696bf9e`) and repaired cleanup-callback scope
  (`e28c67a5`) under behavioral fail-closed tests; no assertion, registration,
  seed, timeout, or budget changed.
- 2026-08-17 [fix06_2] PM scope audit returned the row for one final cold-save
  correction: passive Slot entry currently consumes a saved animation resume
  checkpoint and writes wall-clock-derived serialized state. An isolated agent
  is moving that projection to transient UI state and adding the missing cold
  JSON-restored hostile before the complete gate matrix reruns.
- 2026-08-17 [fix06_2] Saved Slot checkpoint activation repair integrated at
  `e94658ca` after independent semantic review. The real cold open/render path
  is now observational and visual progress resumes without wall-clock writes,
  double drunk scaling, stale offsets, or same-ID double counting. Focused
  Slot/Games gates are green with clean stderr; full integrated closeout gates
  remain intentionally pending.
- 2026-08-17 [fix06_2] Post-merge Systems is independently green in a clean
  timing window: 39.895 s / 43.712 s, 49/49 unique checks, all four shards
  clean, saved-slot hostile green, and complete cleanup. A prior 61.518 s run
  was discarded rather than waived because concurrent Web compilation
  contaminated the wall clock.
- 2026-08-17 [fix06_2/crew06_5] Post-merge UI is independently green in a clean
  timing window at
  `.tmp/test_reports/20260817_0540_postmerge_saved_slot_ui_authoritative`:
  0 failures, `ui_scene_compile` 57.828 s / 124.851 s, every stage exit 0, and
  no timeout/stderr issues. Determinism and visual gates subsequently passed.
- 2026-08-17 [crew06_5] PM completed the prompt-required manual voice review of
  all new lines against the seven authored character styles; each member keeps
  a distinct conforming register, with no tracker copy or system leakage.
- 2026-08-17 [fix06_2/crew06_5] Current-main determinism is green for all 10
  seeds and 590 checkpoints; both reports are byte-identical with combined hash
  `3567232055`, zero failures, and zero warnings. Visual QA subsequently passed.
- 2026-08-17 [pusher06_2] Native provisioning/export hardening `ad11f2fa` passed
  every re-audited hostile except the actual Web-preset capability: extension
  support remains disabled. The row stays IN_PROGRESS until the preset is
  extension-capable and export rejects that mismatch before doing work.
- 2026-08-17 [pusher06_2] `5c06e08a` closes the Web-preset hardening blocker;
  independent exact named-preset hostiles are green. The row remains
  IN_PROGRESS for the native solver and real Windows/Web runtime gates.
- 2026-08-17 [fix06_2] DONE after reopened acceptance. The cold seven-hook guard
  and saved-Slot hostile now prove passive activation is observational across
  the full game class; focused Slot/Games plus clean Systems/UI/10-seed
  determinism/75-state visual gates pass. No state field, budget, assertion, or
  feature was waived; the archived execution record preserves both reopenings.
- 2026-08-17 [crew06_5] DONE. PM completed verbatim scope, roadmap fidelity,
  lender compatibility, manual voice, Contract, Systems, UI, determinism, and
  visual reviews. Deterministic recruitment/presence and rank-service APIs now
  unblock `crew06_6`, `crew06_7`, and `crew06_8`.
- 2026-08-17 [pusher06_2] Static kernel review found the native adapter was not
  transactional or identity/schema-validated. The row remains IN_PROGRESS and
  runtime results are diagnostic until candidate-state execution and hostile
  stale/mutating backend tests close that seam without weakening fallback.
- 2026-08-17 [pusher06_2] Public native helper arithmetic also needs a
  reject-before-mutation numeric contract for signed division and aim/nudge
  extrema; hostile coverage is required before runtime acceptance.
- 2026-08-17 [pusher06_2] Closeout trace review returned overlapping LEAVE/title
  layout and missing reduced-motion action-audio coverage. The presentation and
  audio contract remains binding alongside native performance.
- 2026-08-17 [pusher06_2] Native locked-phase publication also differs from the
  reference solver; exact missing/non-integer locked-state fixtures and a
  conditional write repair are required before backend acceptance.
- 2026-08-17 [pusher06_2] Native bodies-array alias semantics and the authored
  opening depth gradient remain unproven. Both require exact regressions before
  closeout; dense appearance alone is not accepted as evidence.
- 2026-08-17 [pusher06_2] Whole-state copy/replace is not an acceptable
  transactional repair: it breaks aliases and risks the 16 ms budget. The
  corrected seam must reconcile in place and be remeasured.
- 2026-08-17 [pusher06_2] Compact in-place publication and conditional phase
  writes now satisfy static alias/parity review. Malformed output and helper
  extrema hostiles remain before the next runtime build can be accepted.
- 2026-08-17 [pusher06_2] Native kernel/adapter static scope is independently
  ACCEPTED after the complete hostile matrix. Runtime remains red/open: debug
  extension load crashed before script, and exactness plus <=16 ms performance
  have not yet passed on a loadable final binary.
- 2026-08-17 [pusher06_2] Load-crash forensics rules out gameplay/kernel and new
  binding methods; the pinned 4.5 godot-cpp tree is the leading ABI mismatch
  against Godot 4.6. Clean 4.5/4.6 scaffold discrimination is in progress.
- 2026-08-17 [pusher06_2] Exact `d7b6162` 4.6 API selection is credible, but the
  lock's fabricated tag and incomplete Beta/provenance disclosure are rejected;
  artifact hashes and truthful source ref are required before runtime evidence.
- 2026-08-17 [pusher06_2] Exact official 4.6 sync commit `58d1de72...` supersedes
  the rejected master candidate; payload provenance is independently re-auditing
  while a fully clean Windows load build runs.
- 2026-08-17 [pusher06_2] Exact 4.6 pin/provenance is independently ACCEPTED;
  clean Windows/Web runtime evidence remains before native acceptance.
- 2026-08-17 [pusher06_2] Clean Windows debug load, direct native smoke, and the
  focused exactness matrix are green on the accepted 4.6 pin. Raw/production
  <=16 ms performance and Windows release/Web acceptance remain.
- 2026-08-17 [pusher06_2] First native performance run is still red at raw
  19.369 ms / drop 104.976 ms / nudge 124.424 ms against 16 ms; root profiling
  continues without waivers. The isolated presentation-gap patch is static
  ACCEPT and now owns the focused runtime window.
- 2026-08-17 [crew06_6/crew06_7/chain06_1] PM claimed all three unblocked
  release rows for parallel isolated execution. Crew jobs owns layer 3, jobs,
  services, and the Practice Rig; coordinated plays owns the five explicit
  in-venue play windows; character chains owns six flag-driven narrative arcs.
  The PM owns integration order, shared presence seams, board closeout, and the
  complete combined acceptance matrix before any row is marked DONE.
- 2026-08-17 [crew06_6] DONE: furnished the Punchline back room, seeded 2–4
  resident rotation, present-only job offers, 12 jobs spanning all five kinds
  and seven members, Rook/Mags services, and shared Practice Rig training.
  `crew06_8` may consume the planning-table and getaway seams.
- 2026-08-17 [crew06_7] DONE: landed Spotter, Distraction, Big Player, Chip
  Dump, and Table Flood with explicit activation, visible costs, deterministic
  detection/windows, save restoration, concurrency caps, and surviving heat
  pressure. `crew06_8` may consume these coordinated-play lifelines.
- 2026-08-17 [chain06_1] DONE: landed six optional character chains with 21
  beats, three bounded Cass endings, deterministic world anchors, prefix-safe
  progression, true-rumor/gift/staff payoffs, and exact save/load behavior.
- 2026-08-17 [crew06_6/crew06_7/chain06_1] PM closeout: combined Contracts,
  Systems, UI, 10-seed determinism, and visual QA passed. The chain projection
  review additionally eliminated dormant icons and save-round-trip layout
  drift; Punchline layer screenshots are archived under
  `.tmp/crew06_release_screenshots/`.
- 2026-08-17 [pusher06_2] Root profiling kept the shipped 160-body cap,
  150-body opening pile, 48-tick action, 14-frame replay, render/audio assets,
  and all budgets fixed. Output-identical work is split between the native
  broadphase/packed-trace path and the synchronous host refresh/event/coach
  path; the Coach copy-on-write deviation is accepted for measurement only
  after the real input guard accounted for roughly 3.3-3.5 ms, and remains
  contingent on onboarding plus complete UI parity gates.
- 2026-08-17 [pusher06_2] Independent closeout review rejected a packed-trace
  optimization because raw native `body_metadata` could alias authoritative
  simulation metadata. The repair must restore nested publication isolation
  and add a hostile raw-result mutation proof before performance evidence can
  count.
- 2026-08-17 [pusher06_2] The first fused native-load diagnostic also exposed
  a real sparse-save regression: the carried eight-seed oracle left the native
  backend when legacy body defaults were no longer normalized. Sparse-only
  normalization and its internal marker must remain behavior-identical and
  non-serializing; exact current-schema piles retain the scan-free path. No
  compatibility assertion is waived.
- 2026-08-17 [pusher06_2] Sparse/native parity, packed-metadata isolation, the
  internal-marker hostile, Contracts, repaired UI, and focused Coin gates are
  green on the combined tree. The independent strict probe remains red without
  waiver at 16.439 ms Drop and 16.652 ms collapse Nudge versus 16.000 ms;
  raw native p95 is 8.938 ms, draw p95 is 4.120/4.013 ms, frame p95 is
  6.914/6.916 ms, 14 replay frames and zero full snapshots are intact. Final
  root work is limited to output-identical native result/host boundary costs.
- 2026-08-17 [pusher06_2] DONE. PM independently reran every supported prompt
  gate on the final combined tree, verified exact Windows/Web native replay,
  inspected fresh save-free packages, accepted shipped-cap performance, and
  confirmed the seven player-facing captures read as a real coin pusher.
  `pusher06_3` is unblocked; it has not been claimed or started.
- 2026-08-17 [pusherv3_1] Codex claimed the owner-approved V3 headless machine
  rebuild. Execution is strictly serial: the radial-contact/nestle solver and
  carry-plus-back-plate ratchet behavior contracts must close before the live
  loop, cabinet, or variation stages begin.
- 2026-08-17 [pusherv3_1] BLOCKED before implementation on the binding platform
  orientation contradiction: the stated retracted/extended y positions oppose
  the existing and V3 tray/back-plate axis. Stages 2-4 remain unclaimed; no
  substitute ratchet or coordinate interpretation was introduced.
- 2026-08-17 [pusherv3_1] Resumed on owner Amendment 6.1. The amended reference
  machine and behavior suite are integrated; V2 diagnostics and export replay
  are being replaced in parallel while the faithful native V3 backend closes
  the sole remaining focused gate, 300-body frame headroom.
- 2026-08-17 [pusherv3_1] Amendment 6.1 implementation gates now prove the
  native 300-body budget, exact Windows/Web input-trace parity, and a 10-seed
  two-process determinism hash. The exhaustive supported-suite matrix and
  final scope review are in progress; pusherv3_2 remains unclaimed.
- 2026-08-17 [pusherv3_1] BLOCKED at the mandatory all-suite gate after focused
  completion. Verbatim inherited failure: `Gold Buffalo collection did not
  advance over 10,000 paid base spins.` The repository's Slot storage plan
  confirms the same failure on detached clean `HEAD`; no unrelated Slot
  mechanics or test budget was changed. pusherv3_2 remains unclaimed.
- 2026-08-17 [pusherv3_1] DONE by owner completion ruling after PM integration
  and verification at `a6e36d2f`; the amended radial-contact machine, emergent
  carry/plate ratchet, persistent top stock, native performance, deterministic
  replay, and exact Windows/Web parity unblock `pusherv3_2`.
- 2026-08-17 [remainder kickoff] PM claimed `pusherv3_2`, `crew06_8`, and
  `content06_1` for three isolated parallel tracks. The pusher track remains
  strictly serial after Stage 2; the crew track remains strictly serial before
  The Turn; Content owns non-heist shared-catalog entries and produces an
  economy audit for the owner without pre-playtest tuning.
