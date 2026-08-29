# env06_7 Package D / crew06_10 Exact Seam Manifest

Base authority: frozen env06_6 head `855a296126e8b4747b78fbe89cb5a2d02daf61f5`.
Package D owns room duties, room actors, layer routes, and room aftermath only.
Crew06_10 owns hands, betting, settlement, tells, opponents, and all private
poker state. Neither side may mutate the other's state or inspect hidden cards.

## Debt-court boundary

- Crew06_10 publishes the existing public `game_result` fact only after the
  current hand is at a safe paused boundary. Exact predicate consumed by
  `punchline_debt_court`:
  `{"game_id":"crew_draw_poker","action_id":"room_duty_boundary"}`.
- Package D does not infer the hand, pot, debt, cards, or pause state. The fact
  advances only the room graph into its contested physical aftermath. Replayed
  fact or command receipts must not repeat room operations.
- The environment publishes no poker result. Its public projection is limited
  to scenario id, phase/status, resolved outcome, and semantic room operations.
  Crew06_10 may resume only at its own safe hand/session boundary.

## Raid-jitters boundary

- Package D and Crew06_10 independently consume the same authenticated public
  `sweep_changed` fact. Package D never forwards, rewrites, or manufactures it.
- `active=true` may pause Crew06_10 at its next safe hand boundary while Package
  D performs hide/clear/seal duties. Package D owns carts, bins, the L3 screen,
  lookout, routes, reopened layout, and `altered_floor_reopened` / `night_aborted`
  aftermaths. Crew06_10 owns pause/resume/abort and settlement exactly once.
- The assembly-owned combined fixture must prove that
  `altered_floor_reopened` permits a Crew06_10 resume and `night_aborted`
  permits an abort without another settlement. No Package D definition reads
  a deck, hand, pot, wager, tell, member policy, or private receipt journal.

## Integration owner request

The env06_7 assembly owner owns the combined dossiers and cross-seam fixture.
It must bind the public scenario projection to Crew06_10 without adding a
second room state machine, and must provide the Punchline extension handler and
renderer registered as `punchline_clubs`. Package D intentionally does not edit
those shared files.
