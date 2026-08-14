Status: DONE
Board row: `env06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-14
- **Completion/implementation commits:** `ce6fb210`, `70886760`, `a3f03776`
- **Verification:** PM scope/design review PASS; integrated `validate_project`, Foundation systems + UI, determinism 10 seeds / 320 checkpoints (`1208374390`), and visual QA PASS. Dedicated real-selector audit reached 17/17 across 20 seeds; Fight Night save/phase, tutorial identity overlay, and 10 production-order zero-overlap screenshots PASS.
- **Deviations:** None. The generic tutorial pin-mutation switch and previously missing cached presentation renderer are board-recorded code-reality seams within prompt scope.

# Agent Prompt — 0.6 env06_2: Tier-1 Scenario Set (Launch Cut)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). This is a **content
authoring** slice on top of the env06_1 scenario engine. Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 1's
scenario catalog (★ = launch cut) is your authored spec; Pillar 1's
mutation-axis table is your toolbox. Voice: all player-facing text obeys
`docs/plans/0.5_voice_bible.md` + `docs/plans/0.6_voice_bible_world_register.md`
(house = courtesy, street = blunt; brevity rule). This prompt is
self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `env06_2`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations in the Discovery & Decision Log (tagged
   `[env06_2]`); owner-only questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line noting
   crew06_5 is closer to claimable.

## Dependencies

`env06_1` DONE (verify the landed schema/API by code — code reality
wins). `town06_1` weight-modifier seam is optional: if landed, tag
weather-sensitive scenarios; if not, leave tags for a follow-up noted
in the board log.

## Task

Author the ★ launch scenarios for the five tier-1 archetypes —
17 scenarios total in `data/environments/scenarios.json`, replacing
env06_1's placeholders:

- **corner_store (4):** Delivery Day, Lotto Fever, The Aftermath,
  Dead Shift.
- **back_alley (3):** Street Craps*, Cruiser Parked, Fence Night.
- **motel (3):** Conventioneers, The Stakeout, Weekly Rates.
- **bar (4):** The Wake, Fight Night, Payday Rush, Lock-In.
- **gas_station_casino (3):** Trucker Convoy, Tour Bus Stop,
  Graveyard Shift.

\* Street Craps here ships the **scenario shell** (dice-circle
presence, stakes, patrons, exclusive event hooks); the playable game
variant arrives in craps06_2 — leave a marked
`"game_hook": "street_craps"` seam that no-ops until it lands.

Per scenario, complete means:

1. **Mutations** across at least three axes (patrons, events,
   economy/stakes, services, security, presentation, music override),
   tuned to the roadmap's one-line description and expanded with your
   own judgment — each scenario must *play* differently, not just read
   differently.
2. **1–3 exclusive events** authored in `data/events/events.json`,
   pooled only via the scenario (never in the base archetype pool).
   Reuse existing event mechanics (choices, effects, flags) — no new
   event-engine features in this slice. Examples the roadmap names:
   the Wake's stories that open routes, Fight Night's one big swing
   bet on the bout, the Aftermath's quiet fence offer, the Stakeout's
   watch-or-leave tension.
3. **Hook flags** where the roadmap assigns them: Fight Night carries
   the Knuckles recruitment anchor; Trucker Convoy carries Switch's;
   Fence Night carries Mags'; Graveyard Shift sets the lax
   machine-alarm tolerance band and a maintenance cheat-window flag
   (consumed by push06_1 — flag only here). Recruitment anchors are
   inert flags until crew06_5.
4. **Presentation**: palette tint + crowd density + one signage line
   per scenario; music profile override where the night demands it
   (the Wake ≠ Fight Night). No new art assets — tint/density/text
   only; if a scenario truly needs art, log it as a Discovery for the
   owner rather than blocking.
5. **Phases** where the design calls for an arc (Fight Night: prefight
   → bout → aftermath; Payday Rush: surge → thinning; Lock-In: doors
   open → bolted). At most 3 phases; advancement counts per Pillar 1.

## Hard rules

- Determinism: content only — no code paths beyond data + any tiny
  generic mutation-axis gaps you must fill in the engine (log such
  gaps as Discoveries; keep them generic, never scenario-special-cased).
- Every scenario passes the env06_1 content check; extend the check
  where new referenced ids need validation.
- Voice Bible II register on every string; street venues speak blunt.
- No scenario weakens the shipped tutorial path: the tutorial's pinned
  configs must keep selecting a neutral scenario (pin via challenge
  config; prove it).
- Style: tabs, typed GDScript where code is touched; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Content check green over the full 17-scenario set.
2. Seed-audit tool output shows all 17 reachable across a 20-seed
   sweep (no starved weights).
3. Fight Night phase arc advances correctly; save/load mid-bout.
4. Tutorial runs select the pinned neutral scenario (regression).
5. Manual smoke: visit each archetype under at least 2 scenarios each;
   confirm distinct play (stakes, events, presentation) and capture
   screenshots to `.tmp/` for the board note.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: scenario list with axes used, exclusive event ids, hook flags
placed, and gate results. On an unfixable gate failure: stop at last
green commit, set `BLOCKED`, report verbatim.
