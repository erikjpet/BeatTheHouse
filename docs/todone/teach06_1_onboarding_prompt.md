Status: DONE
Board row: `teach06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-16 by Codex
- **Completion/implementation commits:** `4ce50464` (board claim), `fb5bc53b` (lesson catalog and public coach context), `206fdcb2` (contextual pacing and real UI seams), `de0f901f` (generic non-consuming lifecycle, clickable pointer-safe placement, and permanent regression fixture)
- **Verification:** `tools/validate_project.ps1` PASS; focused foundation smoke coach/onboarding checks 0 failures; systems suite assertions 0; UI suite PASS; determinism PASS at 10 seeds / 590 checkpoints (`3483570349`); canonical visual QA PASS at 75 states / 0 warnings; guided 56-lesson parsed prefix exact and canonical SHA-256 `8a028210242d1190492e8b4ec78432e894d632c802a6f55c9e1b0b77aacbb415`; 19-phrase discovery audit 0 hits; delivery, coin-pusher, and Numbers smoke captures recorded under `.tmp/teach06_1/`.
- **Deviations:** No required public system was unavailable. The systems wrapper exceeded the stored wall-time budget on the branch (50.095s) and untouched main (51.283s) with zero assertion failures; no gate, budget, or waiver was changed. Contextual tips required a generic lifecycle/pointer correction after canonical QA reproduced stale advice over real controls; the permanent fixture now proves non-consumption, queue handoff, one clickable dismiss receiver, and deterministic avoidance of public interaction geometry. Discovery-gated systems remain unmentioned.

# Agent Prompt — teach06_1: Onboarding for 0.6 Systems

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. The shipped tutorial/coach system lives in
`data/tutorial/lessons.json` (56 lessons) with the coach surfaces in
`scripts/ui/coach_overlay.gd` and `scripts/ui/coach_view_model.gd`.
Binding design contract: `docs/plans/0.6_living_world_roadmap.md`.
Voice: `docs/plans/0.5_voice_bible.md` +
`docs/plans/0.6_voice_bible_world_register.md`.

## Why this task exists

Every shipped lesson teaches 0.5 content: xray glasses, the corner
store, the gas-station machine, blackjack, the underground. **Zero
lessons cover anything 0.6 added.** A player — including the owner's
own playtest — will meet delivery jobs, the Numbers racket, crew
trust, three coin pusher variations, craps, and the Punchline's
hidden layers with no teaching at all.

That matters more than usual right now: the next milestone is an
owner playtest whose purpose is design feedback. Confusion caused by
missing onboarding will look like design failure and pollute the
signal. Your job is to make the new systems *legible*, not easy.

## Board protocol

1. Before work: set row `teach06_1` to `IN_PROGRESS` with agent +
   date in `docs/todo/README_0_6_board.md`, append a Work Log line,
   commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[teach06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Concurrency

This task runs alongside the coin pusher and crew waves. **File
ownership is strict:** you own `data/tutorial/lessons.json` and the
coach scripts. You do not edit `data/events.json`, `data/items.json`,
`data/crew/*`, `data/games/games.json`, or any game module. If a
system you must teach is still landing, teach what has landed and log
the gap rather than blocking.

## Task

### 1. Teach the new systems in play, not in a wall of text

Extend the existing lesson/coach idioms — same data shape, same
surfaces, same diegetic register. For each system below, the bar is a
player understanding **what it is, what it costs, and what to do
next**, delivered at the moment they first meet it:

- **Delivery runs** (the real-map courier layer): that a job names
  real destinations, that the deadline counts actions, that carried
  cargo is contraband, and that the route choice is the gameplay.
- **The Numbers**: buying a slip, the daily draw, and — without
  spoiling the hidden routes — that the town talks about numbers.
  **Do not teach past-posting or the crew fix.** Those are
  discovery-gated by owner decision; teaching them destroys the
  design. Teach only the honest surface.
- **Crew trust**: that the crew is a path, not just a lender; that
  jobs build standing; that standing opens rooms.
- **Coin pushers**: lane aim, drop timing against the shelf cycle,
  what a nudge does, and that the machine warns before it bites (the
  tell ladder). The alarm's consequence should be understood *before*
  a player trips it by accident.
- **Craps**: the pass line and the point flow only — enough to place
  one bet with intent. Street craps at the back alley is the natural
  first teacher; use it if the scenario is reachable.
- **The Punchline layers**: that some venues have more inside them,
  without naming what. Discovery must stay discovery.
- **Scenarios and the town**: one light beat teaching that venues
  differ by night and that rumors are worth listening to.

### 2. Respect what is deliberately hidden

Several 0.6 systems are owner-locked as discoverable: past-posting,
the crew fix, the Turn's entire mechanism, and the Punchline's lower
layers. **Teaching any of them is a defect, not a feature.** When in
doubt, teach the surface and stay silent about the secret.

### 3. Delivery mechanism

- Prefer contextual just-in-time beats over a front-loaded tutorial
  run. The shipped guided tutorial stays as-is: do not lengthen it,
  do not re-sequence it, and do not change its pinned scenario or
  environment fixtures.
- New lessons trigger on first genuine encounter with a system,
  fire once, are skippable, and never block play.
- Keep the existing determinism discipline: triggers are
  flag/action-boundary driven, never wall-clock.

## Hard rules

- The shipped tutorial's behavior and fixtures are untouched — prove
  it with the existing tutorial regression.
- No new UI chrome; reuse coach surfaces.
- Nothing that reveals a discovery-gated system.
- Voice register per both bibles; brevity rule applies.
- Style: tabs, typed GDScript where touched; `.tmp/` reports; suite
  timeout = max(300s, baseline×1.5).

## QA / Tests

1. Existing tutorial regression byte-identical (fixtures + sequence).
2. Each new lesson fires on first encounter, once, and is skippable.
3. A run that never meets a system never sees its lesson.
4. Discovery audit: no lesson string names past-posting, the crew
   fix, the Turn, or the Punchline's hidden layers.
5. Content check green over lessons.json.
6. Manual smoke with captures to `.tmp/` for at least delivery, a
   pusher, and the Numbers.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: lessons added per system, trigger conditions, the discovery
audit result, systems you could not teach because they had not landed
yet, and gate results. On an unfixable gate failure: stop at the last
green commit, set `BLOCKED`, report verbatim.
