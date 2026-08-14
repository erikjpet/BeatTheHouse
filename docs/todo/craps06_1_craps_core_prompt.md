Status: TODO
Board row: `craps06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 craps06_1: Craps Core (Grand Casino Table Game)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Games are modules
under `scripts/games/` registered in `data/games/games.json` with
per-game `generate_environment_state`, seeded RNG, and result routing
through `GameModule.apply_result()`; Grand Casino table games pay in
CHIPS via the gc05_2 money seam (`is_grand_casino_environment()` +
game family). Study `scripts/games/blackjack.gd` and baccarat as the
table-game reference. Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — Pillar 4 "Craps". This is
the largest single game build of 0.6. This prompt is self-contained
for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `craps06_1` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[craps06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (craps06_2, crew06_8).

## Dependencies

None hard (Wave C). Scenario crowd-energy hooks are consumed if
env06_1 has landed; otherwise leave the seam and log it.

## Task

### 1. The game

- New module `scripts/games/craps.gd` + registration: full core
  craps. Bets: pass/don't pass (with come-out flow), come/don't come,
  free odds behind pass/come (data-tuned max odds multiple), place
  bets (4,5,6,8,9,10), field as the single side-bet concession.
  **No** hardways/props beyond field in this slice — the bet surface
  must stay readable at 1280×720.
- Multi-roll point flow with a persistent table state (point, working
  bets, odds) across rolls; the shooter is the player (NPC shooters
  are future space — leave no half-built stubs).
- Payouts at true odds for odds bets, standard for the rest; all
  numbers in `data/games/games.json` config, never hardcoded. House
  edge documented per bet in the data file comments.
- Placement: `grand_casino` game pool (all three casino rooms per the
  gc05 spatial model where table games live). Chips economy: wagers
  and payouts route through the chips path exactly like
  blackjack/baccarat (regression-prove the money seam).
- UI surface per game-surface conventions (view-model + controller,
  no per-frame rebuild): table layout, bet placement, roll history
  rail, point puck. Dice roll presentation obeys the idle-liveness
  rules (animated but budgeted).

### 2. Crowd energy (scenario seam)

- Hot-shooter streaks (consecutive point makes) raise a table-energy
  value the environment can read (music intensity nudge, patron
  lines). Consume scenario game-modifier hooks if env06_1 landed;
  otherwise expose `table_energy()` and log the deferred wiring.

### 3. Cheat line

- **Dice setting**: a skill-window mechanic (timing meter on the
  throw) that biases — never fixes — the distribution, gated by a
  practice flag (`craps_setting_trained`, granted by the Practice Rig
  in crew06_6; until then obtainable via a data-flagged item route so
  the mechanic is testable). Suspicion cost per use scales with
  security band.
- **Dice switching**: consumes `dice_calipers` + `false_bottom_cup`
  (both shipped items) through the existing skill-cheat pattern
  (blackjack count-challenge is the model): a challenge window, heat
  on detection, confiscation on failure. Loaded-dice item tier itself
  arrives via content06_1/Mags — wire the item hooks data-driven.

### 4. Fairness + RTP harness

- Extend the RTP/fairness validation harness (scratch/slot precedent)
  with a craps simulation: per-bet RTP within tolerance over a large
  seeded sample; dice-setting bias measurably bounded (document the
  bound in data).

## Hard rules

- Determinism: all rolls from the run RNG stream; identical
  seed+inputs → identical session (probe-integrated).
- Perf: table surface budgeted like other game surfaces; no per-frame
  allocations; idle liveness counter-gate green at the craps table.
- Chips seam untouched for other games (regression).
- Save compat: mid-session table state (point, working bets)
  serializes and restores exactly.
- Voice Bible II for all strings (house courtesy register at the
  Grand Casino).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Rules matrix: come-out naturals/craps, point make/seven-out,
   come-bet lifecycle, odds on/off, place-bet payouts — table-driven
   unit tests per bet type.
2. RTP harness within documented tolerance per bet over ≥1M seeded
   rolls (headless).
3. Chips: wagers/payouts in chips inside the casino; cash outside
   never touched by craps (it does not spawn outside grand_casino this
   slice).
4. Cheat: setting biases within bound; switching challenge fires per
   security band; failure costs match data.
5. Save/load mid-point restores the full table.
6. Visual QA + manual smoke: full session with every bet type,
   screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: bet surface, RTP table, cheat tuning, seams left for
craps06_2/crew06_6/crew06_8, and gate results. On an unfixable gate
failure: stop at last green commit, set `BLOCKED`, report verbatim.
