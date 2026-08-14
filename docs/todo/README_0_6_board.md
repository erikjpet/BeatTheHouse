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
| craps06_1 | `craps06_1_craps_core_prompt.md` | IN_PROGRESS | — | craps06_2, crew06_8 | PM:Codex/sub:1 | 2026-08-14 | | PM-orchestrated Wave C Stage 1 execution. |
| craps06_2 | `craps06_2_street_craps_prompt.md` | TODO | craps06_1, env06_1 | — | | | | |
| push06_1 | `push06_1_pusher_core_prompt.md` | IN_PROGRESS | env06_1 | push06_2 | PM:Codex/sub:2 | 2026-08-14 | | PM-orchestrated Wave C Stage 1 execution. |
| push06_2 | `push06_2_pusher_variations_prompt.md` | TODO | push06_1, town06_1 | — | | | | |
| streets06_1 | `streets06_1_streets_framework_prompt.md` | DONE | town06_1, crew06_1 | crew06_3/6/8 | PM:Codex/sub:3 | 2026-08-14 | 2026-08-14 | PM verified scope/design, systems/UI, 10-seed determinism, and package/multi-stop/Hold visual QA on the integrated tree. |
| crew06_2 | `crew06_2_backroom_poker_prompt.md` | IN_PROGRESS | crew06_1, env06_4 | crew06_9 | PM:Codex/sub:4 | 2026-08-14 | | PM-orchestrated Wave C Stage 1 execution; queued for first available subagent slot. |
| crew06_3 | `crew06_3_numbers_prompt.md` | IN_PROGRESS | crew06_1, streets06_1, town06_2 | crew06_9 (grievance src) | PM:Codex/sub:7 | 2026-08-14 | | PM-orchestrated Wave C Stage 2 execution after integrated Streets acceptance. |

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
- 2026-08-14 [push06_1] Quarter Falls joins the existing default Slot Pack so
  content validation can trace its registration. Cold Quarters and Coin-Return
  Shim are accepted only with tests that consume their authored effect keys on
  real drop/gutter actions; their shipped 3/3 fallback tunings remain unchanged
  for legacy or disabled-content saves.
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
