Status: DONE
Board row: `crew06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-16
- **Completion/implementation commits:** `fc0196b5`, `69af73aa`, `511091cb`, `ff254d9c`, `b260a89b`, and `842b439c`.
- **Verification:** PM line-by-line scope/design review; deterministic policy, hidden-tell, showdown-learning, trust, swing-cap, and save contracts; exact-tree full matrix; 10-seed/580-checkpoint determinism (`231360296`); canonical visual QA and four focused Poker captures all PASS.
- **Deviations:** None. The shipped Crew lender flow remains behavior-identical and tell/learning state remains hidden from player-facing surfaces.

# Agent Prompt — 0.6 crew06_2: Back-Room Poker (Crew Table + Tells)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "Crew
games" #1 and "The Turn" (the tells system is The Turn's skill gate:
players can only notice a tell being *wrong* if they learned it being
*right*). The 7 crew characters live in
`data/characters/characters.json`. This prompt is self-contained for
rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_2`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: crew06_9 tells
   seam ready.

## Dependencies

`crew06_1` (trust API) + `env06_4` (layer 3 exists as shell) DONE.
The table lives in L3; if crew06_6 hasn't furnished L3 yet, the table
is the shell's first furniture — coordinate via the board log.

## Task

### 1. The game

- Five-card draw vs 2–3 crew NPCs (whoever is in residence — read
  itineraries if landed, else a seeded rotation): ante, one draw, one
  bet round each side of the draw, table stakes at friendly amounts
  (data-tuned; this is a trust engine, not an ATM — cap session
  win/loss swing in data).
- NPC play driven by seeded, per-member policy profiles (Mags tight,
  Lucky loose, Knuckles aggressive… derive personality from the voice
  styles; document each profile in data). No cheating NPCs.
- Buy-in gated at `associate+` with any member present; playing earns
  small per-session trust with members at the table (via crew06_1
  API), win or lose; hustling them (win above a data threshold
  repeatedly) earns respect from some, grievance from none — poker
  never writes grievances.

### 2. The tells system (The Turn's skill gate)

- Each member has 1–2 **authored tells** in data
  (`data/crew/tells.json`): an observable presentation quirk bound to
  a hand-strength condition (e.g., Mags re-stacks chips on a strong
  hand; Lucky goes quiet on a bluff). Tells surface through existing
  presentation channels (portrait variant, line selection, timing
  beat) — subtle, never labeled.
- **Hidden learning model**: per member, the run tracks tell-exposure
  events (tell shown while the condition was later verifiable at
  showdown). Past a data threshold the member's tell is "learned" —
  still no UI, no journal, no counter (owner discipline rule). Learned
  state is readable via API only (`tell_learned(member_id)`), consumed
  by crew06_9's misfire clue.
- Learning must require genuine play: folds that hide showdowns don't
  teach; the threshold must be reachable in a normal crew run
  (tune + prove with a scripted-session test).

### 3. Presentation

- Table surface per game-surface conventions in L3's private register
  (low light, crew banter lines per member voice styles, Voice Bible
  II street-family warmth). Session entry/exit through an L3
  interactable.

## Hard rules

- Determinism: deck, NPC decisions, tell surfacing — all from run RNG;
  scripted sessions reproduce exactly.
- Hidden means hidden: no tell/learning surface anywhere in UI, logs,
  or save-readable plain strings players would casually see (serialize
  under neutral keys).
- Cash only, capped swings; no interaction with chips/casino economy.
- Perf/save/style rules as the other game prompts; idle liveness
  green at the table.
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Hand evaluation + pot math property tests (draw poker edge cases:
   ties, kickers, split pots).
2. NPC policy determinism: same seed → same decisions across runs.
3. Tell surfacing matches the bound condition with the authored
   frequency; never surfaces labeled.
4. Learning model: scripted N-session sequence flips
   `tell_learned` exactly at threshold; fold-heavy sessions don't
   count showdown-gated exposures.
5. Trust accrual per session via crew06_1 API; no grievance writes
   from poker under any fixture.
6. Session swing caps enforced; save/load mid-hand restores.
7. Visual QA + manual smoke; screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: policy profiles, tells data shape, learning thresholds +
reachability evidence, and gate results. On an unfixable gate failure:
stop at last green commit, set `BLOCKED`, report verbatim.
