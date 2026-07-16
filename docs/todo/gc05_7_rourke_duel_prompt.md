# Agent Prompt — 0.5 Slice 7: The Rourke Duel — Playable Boss Finale + Outcome Ladder

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Per-game modules under
`scripts/games/` (blackjack.gd already ships a count-challenge skill
system); seeded RNG only; boss endgame contract in
`docs/plans/grand_casino_endgame_design.md` (ids binding). This file is
self-contained; the design contract is
`docs/plans/0.5_grand_casino_rework_plan.md` section 7 (phase 4 +
outcomes) — read both first. Requires slices 1-6 landed; consumes
slice 6's `grand_casino_duel_terms`. This is the LARGEST slice — a
first-class gameplay element, owner-designated.

## Task

### 1. The Back Room becomes playable

Slice 1's back-room shell becomes the boss environment: the player is
taken there when the showdown reaches phase 4. Travel/cashout locked
while active (existing `grand_casino_showdown_active` semantics).

### 2. Heads-up blackjack against Rourke (owner-locked game choice)

Build the duel as a BOSS VARIANT of the blackjack module — no new game
module; a data-driven boss configuration plus a boss layer:
- **Rourke deals and plays across the table** — rendered character,
  authored dialogue barks tied to game states (his reads, his
  needling), reusing the table-character pipeline.
- **Count-challenge foundation**: the duel builds on blackjack's
  existing count-challenge/skill-cheat infrastructure — the count, the
  skill timings, and the player's cheat toolkit all function here.
- **Rourke cheats too**: authored dealer-side edges (data-driven set —
  e.g. deck stacking on a seeded schedule, a hole-card swap tell) that
  the player can CATCH AND CALL OUT via a challenge action; a correct
  call strips the edge and swings momentum; a false accusation costs.
- **The player's skill-cheats are available** — but detection
  sensitivity here is the toughest in the game, scaled by
  `duel_terms` (phase 2 handicaps, phase 3 performance).
- **Stakes structure**: chip-stack duel — starting stacks, forced
  antes, and win condition (take Rourke's stack / survive N hands
  above a floor — pick the cleanest, justify) all from `duel_terms`
  *(tunable data)*. Deterministic seeded forks for every draw.

### 3. The outcome ladder (owner-locked)

Replace the slice 6 stand-in resolution entirely. Duel result + margin
maps to exactly three endings:
1. **Walk out clean** — decisive win: the player may exit AND cash out
   at the Cage; run ends as victory,
   `demo_victory_route = "pit_boss_showdown"` (id preserved).
2. **Shown the door** — narrow result: allowed to LEAVE but the Cage is
   closed to them — the run ends SUCCESSFULLY with chips UNCASHED.
   Record a distinct sub-route (`demo_victory_route =
   "pit_boss_showdown"` preserved for compatibility + new flag
   `grand_casino_walked_with_chips = true` and the uncashed chip amount)
   — slice 8 converts those chips to a meta item. Score treats uncashed
   chips at reduced value *(tunable)*.
3. **Taken out back** — loss: `fail_run("casino_taken_out_back", ...)`
   (id preserved).
Margin thresholds live in `duel_terms`/objective data. Record the
ladder outcome in the existing showdown margin/outcome flags for the
end screen.

### 4. Crew handoff return

Phase 1's crew-held item returns on outcomes 1-2; on outcome 3 it is
lost with the run (slice 8 may revisit).

## Hard rules

- Determinism: the entire duel runs on named seeded forks
  (`grand_casino_duel` + attempt index); replays of a seed are
  identical. No wall-clock in simulation.
- Zero-copy per-frame; surface snapshots follow the allocation-free
  idle contract; idle liveness untouched. The duel surface must pass
  the performance probe — add it as a measured surface with a budget.
- Canonical ids preserved; every new flag serializes; save mid-duel
  restores the hand state faithfully (blackjack session state already
  serializes — extend, don't fork).
- Style: tabs, typed GDScript, sparse comments; barks per
  `docs/plans/content_style_guide.md`; `.tmp/` reports. Suite timeout =
  max(300s, baseline×1.5).

## QA / Tests (extensive — boss finale)

1. Duel determinism: same seed + same choices → identical hands, edges,
   and outcome across replays and across save/load mid-duel.
2. Rourke edge schedule fires per seed; correct call-out strips the
   edge; false call costs as authored.
3. Ladder mapping: scripted margins produce each of the three endings;
   chips-kept ending records amount + flag and ends the run as a
   success; cashout lockout enforced in ending 2.
4. duel_terms consumption: pat-down handicaps and interrogation
   performance visibly change starting conditions (assert on stacks/
   sensitivity).
5. Crew item return matrix across the three outcomes.
6. Full-route integration: heat-route run end-to-end through all seven
   phases (invite → floor → trigger → walk → pat-down → interrogation →
   duel) for each ending; clean route regression untouched.
7. Perf probe green with the duel surface budgeted; strict mouse
   playtest run passes.
8. Manual playtest: win decisively, scrape the door ending, and lose —
   each must FEEL like the plan's fantasy (report impressions).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` (games suites matter here)
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- `tools/foundation_mouse_playtest.ps1` (strict single run)

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report the duel ruleset chosen, edge/call-out design, ladder
thresholds, perf numbers, and gate results. On an unfixable gate
failure: stop at last green commit, report verbatim.
