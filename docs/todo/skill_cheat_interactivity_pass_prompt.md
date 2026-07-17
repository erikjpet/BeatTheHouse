# Agent Prompt — Skill-Cheat Interactivity Pass (All Games Audit + Upgrades)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Per-game modules under
`scripts/games/`; skill-cheat design history in
`docs/plans/skill_based_cheating_methods_plan.md`; the store copy promises
"every game has a skill-based cheat." This file is self-contained. Suite
timeout = max(300s, ceil(recorded baseline in tools/check_godot.ps1 × 1.5)).

## Owner verdicts (locked — these frame the whole task)

- **Blackjack is the ONLY cheat with a solid baseline** (the
  count-challenge system). It is the quality bar. Keep it; do not
  rework it.
- **Pull tabs is EXEMPT**: it needs no distinct skill cheat — item-based
  cheating (its item interactions) is its intended cheat surface.
  Verify those items work; add nothing.
- Every OTHER implemented cheat gets audited and, where it is passive or
  one-click, upgraded with ADDITIONAL INTERACTIVITY. This is an
  interactivity pass, not a redesign: keep each cheat's identity,
  cost/heat model, and data hooks; raise the moment-to-moment skill.

## Task

### 1. Audit (report before touching code)

For each game — blackjack, roulette (past-post), baccarat (edge-sort),
video poker (holdout swap), bar dice (controlled roll), slots (reel
nudge), pull tabs (item-driven) — document in a table: what the cheat
actually does today in code (cite file/function), its input model
(passive click vs timed/skill), how alcohol/contraband/items modify it,
its heat/consequence wiring, and test coverage. Flag anything the store
copy claims that does not exist. The audit table goes in your final
report AND in the commit message of the audit commit.

### 2. Interactivity upgrades (per audit findings)

Where a cheat resolves as a single passive click, add a skill element
following the count-challenge pattern's shape (player input under
pressure, readable feedback, fail states that sting):
- **Timing** (e.g. past-post: place the late chip in a shrinking window
  timed to the wheel settle; nudge: stop a moving indicator on the
  target stop),
- **Memory/read** (e.g. edge-sort: identify the marked-back card from a
  brief look; holdout: track which card you palmed across a shuffle
  animation),
- **Precision under degradation**: alcohol widens/blurs/shifts the
  input (the modifier data already exists — wire it into the new
  interactions), contraband sharpens it.
Choose the mechanic that fits each game's fiction; keep scope
proportionate — one good interactive beat per cheat, not a minigame
suite. All windows/timings are data-tuned. Success/failure probabilities
must remain deterministic given the same seed and the same player
inputs; timing inputs resolve against simulation-time windows evaluated
at action boundaries (the count-challenge precedent shows the pattern —
study how it keeps skill input deterministic before designing).

### 3. Consistency layer

- Uniform cheat affordance: every cheat action telegraphs risk the same
  way (heat preview, watched-status relevance — now spatial where the
  pit boss system applies).
- Failure feedback: a failed skill input has a distinct, readable
  consequence beat (not just a heat number).
- The duel (Grand Casino boss, if landed) consumes blackjack's system —
  do not break its hooks; run its tests.

## Hard rules

- Determinism: same seed + same inputs = same outcome, everywhere; no
  wall-clock in simulation; skill windows in simulation time.
- Zero-copy per-frame; idle-animation liveness untouched; canvas
  interactions follow the surface-command pattern.
- Data-driven tuning; no balance changes outside the cheats themselves;
  blackjack untouched except consistency-layer affordances.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports only.

## QA / Tests

1. Per-game: deterministic outcome tests (seed + scripted inputs →
   fixed result), alcohol/contraband modifier effects on the new
   interactions, heat/consequence wiring, failure-path feedback.
2. Pull tabs: item-driven cheat items verified working; no new cheat
   surface added (regression that none appeared).
3. Blackjack + duel (if present) regression suites green untouched.
4. Store-copy truth: after this pass, the audit table's "exists in
   code" column must make the description honest; report any remaining
   gap explicitly instead of papering over it.
5. Manual playtest: perform each upgraded cheat sober and drunk; each
   must feel like a skill moment, not a coin flip.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` (games suites especially)
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_mouse_playtest.ps1` (strict single run)

## On completion

Commit in logical units (audit; per-game upgrades; consistency layer),
delete this prompt file in the final commit, push, and report the audit
table, each upgrade shipped, and every gate result. On an unfixable gate
failure: stop at the last green commit and report verbatim.
