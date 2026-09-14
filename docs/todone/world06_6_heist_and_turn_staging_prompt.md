Status: DONE — accepted by the exact-tree Family 2 closeout on 2026-09-03
Board row: `world06_6` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_6: Heist Phases and the Turn Confrontation

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped heist and Turn systems, not a redesign of either. Read
`scripts/core/crew_heist_model.gd` (`config`, `plan`, `empty_state`, `begin`,
`normalize_state`, `setup_complete` and the rest),
`scripts/core/crew_turn_model.gd` (`empty_state`, `normalize_state`,
`eligible_members`, `resolve`, `witnessed_count`, `active_member`),
`data/crew/heist.json`, the archived `crew06_8_heist_prompt.md` and
`crew06_9_the_turn_prompt.md`, the full heist section of
`docs/plans/0.6_living_world_roadmap.md`, the `world06_1` adapter contract, and
the `world06_2` chase verb contract.

Read the board's Discovery & Decision Log entries for `crew06_8` before you
plan. That row was returned four times for exactly the failure modes this row
can repeat: fixture-only progress, decisions exposed at the wrong boundary,
generic rounds accepted for specific requirements, and hidden-system language
leaking into player-facing copy and serialized keys.

## Why this rework exists

The heist is 0.6's finale and the Turn is its best idea. Both landed correct and
both are experienced as choice lists at a planning table. Plan A's dock versus
corridor decision, Plan B's cage and interview beat, the clean walk, the hot
chase and the unmarked confrontation are all places and moments that currently
resolve as text options.

## Board and dependencies

Follow the active board protocol. Claim `world06_6`. `world06_1` must be landed
and reviewed, base on the accepted `world06_2` head for chase verbs, and require
`crew06_10` for the poker tell clue channel. You own the heist and Turn surfaces
and their tests exclusively. You may not change traitor resolution, grievance
weighting, clue emission rules or any outcome ladder.

## 1. Hidden-state discipline comes first

- Nothing in a sequence definition, scene state, actor state, serialized key,
  capture, log line, test fixture or player-facing string may reveal or allow
  inference of the traitor, the grievance weights or the resolution state before
  the Turn's own contract discloses it.
- Use the neutral storage and addressing scheme from `world06_1`. Run its leak
  test against every surface this row adds, and extend it with heist-specific
  cases.
- The three landed clue channels — poker tell misfire, itinerary lie, light
  envelope — must keep emitting honestly at their landed rates and must now be
  observable in a staged scene without becoming easier or harder to read than the
  contract allows.
- If staging a beat would require exposing hidden state, the beat is wrong.
  Redesign the beat.

## 2. Plan A — The Count, staged

- Preserve the action-boundary phase window, the interleaving of decisions at
  authored round boundaries rather than all at the planning table, the functional
  dock versus corridor consequences, the heat-spike corridor loss, and the
  requirement that progress comes from real distinct sessions of real table play.
- Stage each phase as a place: the planning table, the floor, the count, the dock
  or the corridor, the exit. Decisions happen where and when they happen.
- Consume the real production truths the landed row requires — normalized action
  kinds, game-specific settled fields, actual session counts. A fixture-shaped
  shortcut fails this row exactly as it failed `crew06_8`.

## 3. Plan B — The Whale Game, staged

- Preserve the authoritative Grand Casino chip flow scoring, the required mixed
  craps and card invitational rounds, the consumption of actual finite
  `crew06_7` play state as lifelines, the Rourke-attention outcome path, and the
  compressed cage and interview beat before a clean walk or hot chase.
- Stage the invitational as an occasion with the right people at the right
  tables, the cage as a place with a person who checks, and the interview as a
  scene with a real exit condition.
- Component and vouch progress must come from the real item and training
  producers used by shipped code, never from fixture-era flags.

## 4. Exits and the confrontation

- A clean walk keeps zero pursuit across later action boundaries — not merely at
  the moment of exit. A hot exit uses the `world06_2` chase verbs rather than a
  second chase implementation.
- The unmarked confrontation becomes a scene: who is there, what is said, what
  the player can do, and what each choice costs. The hedge option keeps its
  landed contract.
- Both plan-specific betrayal beats and both mechanical failure beats must be
  staged distinctly and must each be reachable.
- The outcome ladder for both plans stays exactly as landed. Produce a
  before-and-after table proving it.

## 5. Persistence and composition

- Every consequence fires exactly once across save, exit, travel, revisit,
  abort and expiry. Aborting mid-heist must be clean and honest.
- Empty and non-heist boundary syncs must remain true no-ops. The recorded
  regression here was a boundary sync rebuilding every world-map node while
  hunting for a transient event; cleanup scans may run only when a persisted
  registration marker proves this heist actually mounted.
- Heist sequences must compose with scenario sequences, sweeps, travelers and
  ordinary events at the nodes they touch, with no lost base functionality.
- The `crew_heist` victory route and the act-seam extension keep their contracts.

## 6. Tests and acceptance

- Both plans played end to end in production shape: planning, every phase, every
  decision boundary, both exits, and both outcome ladders, with the ladder table
  from section 4 asserted.
- Tests must reject early or wrong-game progress, fixture-only component flags,
  and any path where a generic round satisfies a specific requirement.
- The full hidden-state leak audit across every new surface, capture and
  serialized key, including the extended heist cases.
- All three clue channels emitting at their landed rates in staged scenes, with
  the poker channel exercised against the landed `crew06_10` implementation.
- Confrontation, hedge, both betrayal beats and both mechanical failure beats
  played and asserted.
- Clean-walk zero-pursuit across later boundaries; hot-chase through the shared
  `world06_2` verbs.
- Exactly-once assertions across save, reload, revisit, abort and expiry.
- Crew-ignoring and non-heist runs proven to be true no-ops, with the boundary
  sync assertion in place.
- 10-seed determinism, native/Web parity, performance with the idle liveness
  counter-gate, accessibility for every new interaction.
- Visual QA: planning table, each phase of both plans, dock, corridor, cage,
  interview, clean walk, hot chase, confrontation, hedge, each betrayal beat,
  reduced motion, small screen.

Run project validation, all relevant foundation suites, the full Rourke duel and
Players Card route regressions, 10-seed determinism, native/Web parity,
performance, accessibility and visual QA. Archive only with exact evidence, the
ladder-preservation table, and a passing hidden-state audit. A leak is an
automatic rejection regardless of the rest of the row's quality.
