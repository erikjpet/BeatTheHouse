Status: IN_PROGRESS — composition/soak and migration lanes are independently active
Board row: `integ06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 integ06_1: Composition, Migration and Soak Umbrella

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This row proves that the pieces
of 0.6 work together, which no row so far has been responsible for. Read
`scripts/core/save_service.gd`, `scripts/core/run_save_codec.gd`,
`scripts/core/run_state.gd`, `scripts/core/profile_inventory.gd`,
`scripts/tests/foundation/check_lenders_release_saves.gd`,
`scripts/tests/foundation/crew_ignored_golden_probe.gd`, and every 0.6 row's
migration note in the board and its companion log.

## Why this row exists

Every subsystem migrated its own 0.5 saves and proved its own composition at its
own seam. `depth06_1` composes one node at one moment. Nobody has proven that a
real mid-0.5 save survives all of 0.6 at once, or that a full run with every
system active reaches a terminal state without orphaned state, double-fired
consequences or determinism drift.

This is the class of bug that only appears when everything is on, which is
exactly the condition the owner's playtest will run in.

## Board and dependencies

Follow the active board protocol. Claim `integ06_1`. This row requires Families 1
and 2 to be merged; running it earlier produces a report about a build that no
longer exists. You own the integration harness and its tests. You do not fix
product code — findings route as `fix06_*` rows or back to the owning row.

## 1. The migration matrix

- Collect or construct genuine mid-0.5 saves covering the states a real player
  could be in: mid-run at each environment archetype, mid-game at each surface,
  mid-debt at each lender rung, mid-tutorial, mid-scratch-ticket, at the Grand
  Casino, with and without the invite flag, and at each victory route's
  threshold. Say how each was obtained; a save hand-written to look plausible is
  not evidence.
- Load every one on the current build. Assert: no data loss, no crash, no silent
  reset, no lost counter, correct schema version, and a legal, playable state.
- Assert the specific migrations each 0.6 row promised, including the
  `small_underground_casino` to three-layer Punchline migration, the delivery
  re-pointing from `rework06_1`, the coin pusher compact persistence and its V3
  successors, and every scenario snapshot migration.
- Repeat for mid-0.6 saves taken before each depth program, since players of the
  owner's own builds will have them.
- Round-trip every migrated save: save again, reload, and confirm stability.

## 2. Composition at shared nodes

- Construct the maximal node: an environment scenario sequence running, a crew
  sequence mounted, an event available, a service open, a traveler present, the
  Police Sweep arriving, a game in progress, and a save and load in the middle.
- Run it at every archetype that can host all of those, and at the Punchline
  across all three layers.
- Assert: correct precedence, no lost base functionality, ordinary travel and
  ordinary events still work, safe exits from every combination, no orphaned
  actor, object or hit-region state, and no consequence firing twice.
- Include the abandonment cases: leave mid-everything, travel away, come back,
  and let things expire in every order you can construct.

## 3. Full-run soak

- Play complete seeded runs to terminal with every system active, on native and
  Web, across a documented seed set. Include a crew-ignoring control run.
- Assert determinism: the same seed produces the same run, and native and Web
  agree exactly on outcome traces.
- Assert stability over the length of a real run: no growth in state that should
  be bounded, no accumulating orphaned snapshots, no degradation in frame cost
  from start to terminal.
- Reach every victory route and a representative set of failure routes, and
  assert each terminal state records correctly through to the profile.
- Sample save and load at many points during each soak rather than only at
  boundaries, because that is where the real player saves.

## 4. Discipline

- Every claim reproducible from a stated command, seed and build.
- The harness lives with the other test harnesses, does not slow the default
  suites, and long runs are opt-in.
- Do not fix product code in this branch. If you find a P0, report it
  immediately rather than at the end — the other programs may still be running
  and can absorb the fix at its source.
- Determinism problems are diagnosed, never worked around by rerunning or
  loosening a threshold.

## 5. Deliverable

A report under `docs/plans/` containing: the save inventory with provenance; the
migration matrix with per-save verdicts; the composition matrix with per-
combination verdicts; the soak results including determinism, parity, stability
and terminal coverage; and every finding with severity, evidence and where it was
routed.

Deliver the harness committed and runnable so `playtest06_2` and `release06_1`
can re-run it.

This row remains TODO or BLOCKED if any genuine 0.5 save fails to load, if any
consequence can double-fire in any composition, if determinism or native/Web
parity fails on any seed, or if a full run cannot reach terminal with every
system active. Archive with the report path and exact commands on the board.
