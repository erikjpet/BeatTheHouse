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
| env06_2 | `env06_2_tier1_scenarios_prompt.md` | IN_PROGRESS | env06_1 | crew06_5 | PM:Codex/sub:1 | 2026-08-14 | | PM-orchestrated Wave B Stage 1 execution. |
| env06_3 | `env06_3_tier2_scenarios_prompt.md` | TODO | env06_1, env06_4 | crew06_5, crew06_8 | | | | |
| env06_4 | `env06_4_punchline_rework_prompt.md` | IN_PROGRESS | env06_1 | env06_3, crew06_2, crew06_6 | PM:Codex/sub:2 | 2026-08-14 | | PM-orchestrated Wave B Stage 1 execution. |
| town06_2 | `town06_2_rumors_travelers_prompt.md` | IN_PROGRESS | env06_1, town06_1 | town06_3, crew06_3, crew06_9, chain06_1 | PM:Codex/sub:3 | 2026-08-14 | | PM-orchestrated Wave B Stage 1 execution. |
| town06_3 | `town06_3_police_sweep_prompt.md` | TODO | town06_1, town06_2 | streets06_1 (full), crew06_3 (full) | | | | |

### Wave C — Games

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| craps06_1 | `craps06_1_craps_core_prompt.md` | TODO | — | craps06_2, crew06_8 | | | | |
| craps06_2 | `craps06_2_street_craps_prompt.md` | TODO | craps06_1, env06_1 | — | | | | |
| push06_1 | `push06_1_pusher_core_prompt.md` | TODO | env06_1 | push06_2 | | | | |
| push06_2 | `push06_2_pusher_variations_prompt.md` | TODO | push06_1, town06_1 | — | | | | |
| streets06_1 | `streets06_1_streets_framework_prompt.md` | TODO | town06_1, crew06_1 | crew06_3/6/8 | | | | |
| crew06_2 | `crew06_2_backroom_poker_prompt.md` | TODO | crew06_1, env06_4 | crew06_9 | | | | |
| crew06_3 | `crew06_3_numbers_prompt.md` | TODO | crew06_1, streets06_1, town06_2 | crew06_9 (grievance src) | | | | |

### Wave D — Crew depth

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| crew06_5 | `crew06_5_recruitment_prompt.md` | TODO | crew06_1, env06_2, env06_3 | crew06_6/7/8 | | | | |
| crew06_6 | `crew06_6_layer3_jobs_prompt.md` | TODO | crew06_1, env06_4, streets06_1, crew06_5 | crew06_8 | | | | |
| crew06_7 | `crew06_7_coordinated_plays_prompt.md` | TODO | crew06_1, crew06_5 | crew06_8 | | | | |
| crew06_8 | `crew06_8_heist_prompt.md` | TODO | crew06_5/6/7, craps06_1, streets06_1, env06_3 | crew06_9 | | | | |
| crew06_9 | `crew06_9_the_turn_prompt.md` | TODO | crew06_8, crew06_2, town06_2, crew06_3 | release06_1 | | | | |

### Wave E — Narrative + ship

| ID | Prompt | Status | Depends on | Unblocks | Agent | Started | Finished | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| chain06_1 | `chain06_1_character_chains_prompt.md` | TODO | town06_2, env06_2, env06_3 | release06_1 | | | | |
| content06_1 | `content06_1_items_events_expansion_prompt.md` | TODO | env06_2, env06_3, crew06_6 | release06_1 | | | | |
| voice06_1 | `voice06_1_voice_pass_prompt.md` | TODO | all content-bearing tasks DONE | release06_1 | | | | |
| release06_1 | `release06_1_ship_prompt.md` | TODO | ALL rows DONE | — | | | | |

### Fixed checkpoint

A **human playtest round runs between Wave D completion and voice06_1 /
release06_1** (0.5 precedent). The owner triggers it; defects it finds
become new scoped prompts added to this board under a `fix06_*` prefix.

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

## Work Log

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
