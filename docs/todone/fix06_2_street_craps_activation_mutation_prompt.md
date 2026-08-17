Status: DONE
Board row: `fix06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-17 by Codex
- **Completion/implementation commits:** `4a4201b7`, `314b2d04`, `0572377b`, `30993c92`
- **Verification:** Exact activation diff captured; focused Craps suite PASS; generated-placement activation guard PASS with hostile fixture; UI suite PASS including unchanged M1.6; systems assertions 0; 10-seed determinism PASS (590 checkpoints, hash `3567232055`); canonical visual QA PASS (75 states, zero warnings).
- **Deviations:** Grand Casino Craps was not implicated. The systems wrapper's unchanged 43.712s stored wall budget remained exceeded, but the quiet 52.277s result was baseline-equivalent to the already accepted rework control at 51.780s (+0.96%); no assertion or budget was changed, under the existing owner environmental-only timing rule.

# Agent Prompt — fix06_2: Street Craps Mutates RunState on Activation

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. This is a **shipped defect in landed code**, found
by `env06_5`'s UI gate — not a defect in `env06_5`.

## The defect

`scripts/tests/ui_scene/compile_components_and_main_flow.gd:3646`
asserts a binding UI contract:

> `M1.6 selected info-card game activation mutated serialized RunState.`

The contract: clicking an info-card action button to **open** a game
must not mutate serialized `RunState`. Opening a game is navigation,
not play. The surrounding assertions (focus at 3506, hover at 3543,
clear-focus at 3562) enforce the same rule for the other interaction
verbs — this is a deliberate, longstanding invariant.

Street Craps violates it: activating it from the info card mutates
serialized state before the player does anything.

`env06_5` exposed this because its back-alley backlog scenario makes
the Street Craps activation path reachable in the UI test. The
scenario is correct; the game is not.

## Why this matters beyond the test

Mutating on open breaks save/restore honesty and determinism
guarantees: a player who opens a game and walks away has silently
changed their run. Every other game in this project respects the
invariant. This one must too.

## Board protocol

1. Before work: set row `fix06_2` to `IN_PROGRESS` with agent + date
   in `docs/todo/README_0_6_board.md`, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[fix06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line noting
   that `env06_5` acceptance is unblocked.

## Task

1. **Reproduce first.** Drive the failing assertion and capture the
   exact mutation: which keys of serialized `RunState` change on
   activation, and from what call path. Record it in the board log —
   the diff is the diagnosis.
2. **Find the root cause in Street Craps' activation path.** Likely
   candidates (verify, do not assume): eager environment-state
   generation, scenario/game-state seeding on open, training-progress
   or dispersal bookkeeping firing at activation instead of at play,
   or an RNG stream advanced during surface construction.
3. **Fix generically.** Move the mutation to the first genuine player
   action, or make activation compute its view without writing state.
   Do not special-case the test, do not gate on "is this a test", and
   do not relax the assertion. Street Craps must obey the same
   invariant as every other game.
4. **Check the sibling.** `craps06_1` (the Grand Casino table) shares
   a rules core with Street Craps. Verify it does not have the same
   defect on its own activation path; if it does, fix both under this
   row and say so.
5. **Guard it.** If the existing M1.6 coverage does not exercise
   every game's activation path, extend it so a future game cannot
   reintroduce this class silently. Prove the guard fails when the
   mutation is reintroduced via fixture.

## Hard rules

- Never weaken or skip the M1.6 assertions.
- Street Craps' shipped gameplay, RTP parity with the core rules,
  cash-only routing, teaching beats, dispersal/settlement rule, and
  training-progress grants must all survive unchanged — regression
  them explicitly.
- Determinism: the fix must not change seeded outcomes for a player
  who opens and then plays; prove identical play sequences still
  reproduce.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. The failing M1.6 assertion passes; the mutation diff is empty.
2. Street Craps gameplay regression: rules, RTP parity, cash routing,
   dispersal, training grants unchanged.
3. `craps06_1` activation checked (and fixed if implicated).
4. Save/load: open a game, save, reload — state identical to
   never having opened it.
5. Determinism probe unchanged.
6. Class guard extended and proven in both directions.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: the mutation diff, the root cause, the generic fix, whether
`craps06_1` was implicated, the guard you added, and gate results.
Then notify that `env06_5` acceptance can resume. On an unfixable
gate failure: stop at the last green commit, set `BLOCKED`, report
verbatim.
