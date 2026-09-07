# fix06_29 — Punchline Natural L3 Back-Room Route

## Status

TODO after owner playtest. This is not a blocker for the local 0.6 owner build.

## Exact scope

Exercise the exact Punchline L3 back-room route from a naturally earned made
Crew standing or Rook escort save. Use the production `FoundationMain` host,
normal progression, exact semantic-object ids, real viewport input, and only
player-visible outcomes. Do not inject rank, escort, route, environment, or
event state and do not call private handlers.

## Acceptance

- Earn one of the authored gates through normal play and persist it.
- Save/Continue, travel to the Punchline, enter the back room, revisit, and
  depart using exact rendered objects and real input.
- Prove the visible gate copy, destination, room actions, and save/revisit
  behavior without hidden-state leakage or fallback target selection.
- Record any product defect separately from harness/progression limitations.

