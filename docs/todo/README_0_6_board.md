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
| pusher06_0 | `pusher06_0_physics_lab_prompt.md` | OPTIONAL | rework06_2 accepted | — | | | | Measurement/hardening only: coin cap, frame/solver/render p95, pathology counts, Windows-vs-Web parity, adversarial + long-run. Claim ONLY if rework06_2 did not measure these rigorously. |
| pusher06_1 | `pusher06_1_solver_core_prompt.md` | REFERENCE | rework06_2 accepted | — | | | | Substance delivered by rework06_2. Use as an acceptance checklist against the landed solver — especially the authority rule (what crosses the tray edge is what pays; no steered outcomes) and emergent-RTP-by-machine-tuning. |
| pusher06_2 | `pusher06_2_presentation_audio_prompt.md` | IN_PROGRESS | rework06_2 accepted | pusher06_3 | PM:Codex/sub:pusher-depth | 2026-08-17 | | PM-orchestrated isolated execution from the accepted rework integration tree; density/presentation/audio only, with snapshot authority, unchanged outcomes, performance, and player-readable feel captures independently verified by PM. |
| pusher06_3 | `pusher06_3_variations_prompt.md` | TODO | pusher06_2 | pusher06_4 | | | | Prove Ridge and Vault are genuinely different machines on the new solver, with physical pucks/fragments. Distinctness is the acceptance bar. |
| pusher06_4 | `pusher06_4_environment_integration_prompt.md` | TODO | pusher06_1/2/3 landed | coin pusher closure | | | | Venue presence, persistence at run scale with measured save-size, rumor/sweep/scenario/reputation wiring, class guard. |

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
| fix06_2 | `fix06_2_street_craps_activation_mutation_prompt.md` | IN_PROGRESS | — (defect in landed craps06_2) | env06_5 acceptance | PM:Codex/sub:activation-guard | 2026-08-17 | | Reopened after the stronger cold-state guard proved the prior closeout exempted presentation hooks and non-default generated fixtures; seven passive Grand Casino dealer-day writes reproduced. Root repair and integrated gates remain required. |

### Wave D — Crew depth

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| crew06_5 | `crew06_5_recruitment_prompt.md` | IN_PROGRESS | crew06_1, env06_2, env06_3 | crew06_6/7/8 | PM:Codex/sub:crew-recruitment | 2026-08-17 | | PM-orchestrated isolated execution; subagent owns implementation only, PM owns board, integration, design-fidelity review, verification, archival, and push. |
| crew06_6 | `crew06_6_layer3_jobs_prompt.md` | TODO | crew06_1, env06_4, streets06_1, crew06_5 | crew06_8 | | | | |
| crew06_7 | `crew06_7_coordinated_plays_prompt.md` | TODO | crew06_1, crew06_5 | crew06_8 | | | | |
| crew06_8 | `crew06_8_heist_prompt.md` | TODO | crew06_5/6/7, craps06_1, streets06_1, env06_3 | crew06_9 | | | | |
| crew06_9 | `crew06_9_the_turn_prompt.md` | TODO | crew06_8, crew06_2, town06_2, crew06_3 | release06_1 | | | | |

### Wave E — Narrative + playtest handoff

**This wave does NOT ship anything.** Its terminus is a stable,
complete-enough build handed to the owner for extensive playtest.
0.6 is expected to be roughly 50% done at that moment; the polish and
cleanup pass that follows the owner's playtest is the second half of
the release, and it is where release activity finally happens.

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| chain06_1 | `chain06_1_character_chains_prompt.md` | TODO | town06_2, env06_2, env06_3 | playtest06_1 | | | | |
| content06_1 | `content06_1_items_events_expansion_prompt.md` | TODO | env06_2, env06_3, crew06_6 | playtest06_1 | | | | |
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

*(empty)*

## Discovery & Decision Log

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

## Work Log

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
