# Agent Prompt — 0.5 Slice 1: Grand Casino Spatial Split (Three Rooms)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Immediate-mode canvas
rendering; per-game modules under `scripts/games/` talk to the host
`scripts/ui/foundation_main.gd` via dictionary commands; content is
data-driven from `data/*.json`; UI logic lives in extracted controllers and
pure view models (decomposition pattern — do not grow foundation_main
beyond thin wiring). This file is self-contained; the binding design
contract is `docs/plans/0.5_grand_casino_rework_plan.md` (owner-locked) —
read it first; this slice implements its section 1.

## Task

Split the Grand Casino into THREE connected rooms while keeping ONE world
map node:

1. **Main Floor** (`grand_casino` archetype evolves into this, preserving
   the archetype id for save/route compatibility): machine games —
   slots, video poker, pull tabs — plus bar dice at the casino bar.
   Contains authored spots for: the Cage window (interactable stub this
   slice; real window is slice 2), the host desk, the high-limit door,
   and a back-room door that is VISIBLE BUT LOCKED (opened only by the
   showdown in later slices).
2. **High-Limit Room** (new archetype, e.g. `grand_casino_high_limit`):
   table games only — blackjack, baccarat, roulette — at boss-tier
   configs: raise `economic_profile.stake_floor`/`stake_ceiling` and add
   data-driven table-rule variants where the game configs support them
   (verify what `data/games/games.json` + archetype game config
   overrides actually support; do not invent engine features for this
   slice — higher stakes floors are the minimum bar). NO video poker
   here (machines live on the main floor).
3. **Back Room** (new archetype, e.g. `grand_casino_back_room`): boss
   environment shell — authored layout and mood only this slice; no
   entry path for the player yet.

## Requirements

- **One world-map node.** The map shows a single Grand Casino;
  `WorldMap.build` includes all non-home archetypes automatically
  (`scripts/core/world_map.gd:39-91`), so the two new archetypes must be
  EXCLUDED from world-map node generation (add a data-driven flag, e.g.
  `"map_hidden": true` or kind-based exclusion, handled in `world_map.gd`
  — verify how the meta pawn/home rooms avoid the run map and prefer the
  same mechanism).
- **In-environment room travel**: door objects on the main floor and
  high-limit room swap `current_environment` between the casino rooms
  WITHOUT world-map travel — reuse the cheapest existing seam (the run
  travel pipeline with zero-cost local routes, or direct
  `set_environment` swaps like the meta room transitions) — state your
  choice and why. Room moves cost a small data-tuned number of clock
  minutes and are actions (action-boundary rules apply).
- **Shared casino state**: heat, attention flags, evidence, endgame
  state, entry bankroll, and games-played counters are casino-wide
  across all three rooms. Audit every `grand_casino` archetype-id check
  in `scripts/core/run_state.gd` (endgame state machine, clean-route
  counters, heat routing — see the canonical contract in
  `docs/plans/grand_casino_endgame_design.md`) and route them through a
  single helper (e.g. `is_grand_casino_environment()`) that matches all
  three archetypes. Canonical ids/flags must not change.
- **High-limit access gate stub**: the high-limit door checks a gate —
  this slice implements the cash buy-in path (data-tuned amount) plus a
  hook for card-tier access (`grand_casino_high_limit_access` flag) that
  slice 5 will drive. Locked door shows the requirement plainly.
- Invite gate, travel routes, and the boss objective all keep working
  exactly as today.

## Hard rules

- Determinism: seeded streams at action boundaries only; no wall-clock.
- Zero-copy per-frame; idle-animation liveness untouched.
- Save compatibility: a 0.4 save inside the old grand_casino loads into
  the Main Floor cleanly.
- Style: tab indentation, typed GDScript, sparse constraint comments;
  reports under `.tmp/` only. Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Foundation tests: room swap preserves heat/attention/evidence/
   counters; endgame state machine transitions still pass with play
   split across rooms; high-limit door blocks without buy-in and admits
   with it; back room is unreachable; world map has exactly one Grand
   Casino node across seeds.
2. Clean-route and showdown-route runs still complete (existing endgame
   tests green).
3. Visual QA + manual smoke: walk all three-room layout, play a game in
   each open room, verify stake floors differ.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report the room/data map, the travel seam chosen, and gate
results. On an unfixable gate failure: stop at last green commit, report
verbatim.
