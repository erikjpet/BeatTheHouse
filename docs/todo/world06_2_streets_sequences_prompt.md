Status: TODO
Board row: `world06_2` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_2: Streets — Deliveries, Holds and Pursuit

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped delivery and streets systems, not a redesign of their economy. Read
`scripts/core/delivery_run_model.gd` in full (`begin`, `normalize_state`,
`snapshot`, `advance_boundaries`, `note_arrival`, `complete_handoff` and the
rest), the archived `streets06_1_streets_framework_prompt.md` and
`rework06_1_map_delivery_prompt.md`, the `world06_1` adapter contract under
`docs/plans/`, `scripts/core/town_state.gd` and `police_sweep_model.gd`.

## Why this rework exists

`rework06_1` did the hard structural work: the synthetic block board is gone and
deliveries route over real map nodes with ordinary travel. What is left is that
a delivery is still experienced as travel plus a choice list. The package is a
cargo id, the pursuit is a timer, the lookout hold is a counter, and the verbs
the original design named — move, wait, duck, stash, ditch — do not act on
anything you can see.

## Board and dependencies

Follow the active board protocol. Claim `world06_2`. `world06_1` must be landed
and reviewed; build only on its accepted head. You own
`scripts/core/delivery_run_model.gd`, its surfaces and its tests exclusively.
`world06_6` bases on your accepted head for chase verbs, so keep those general.

## 1. The package is an object you are carrying

- Cargo becomes a real carried object with visible presence, a place it is kept,
  and consequences for how it is carried. The shipped `cargo_id`,
  `cargo_label`, `cargo_heat_per_travel` and hold contracts keep their meaning.
- Pickup and handoff are staged encounters with a person at a place, not a
  confirmation. Use the `world06_1` adapter so both persist and clean up like
  any other sequence.
- Multi-stop routes make each stop a distinct place with its own staging,
  ordering and failure. A stop the player has already made must read as made
  after save, travel and revisit.
- Stash and ditch act on real locations. A stashed package exists at a node,
  can be retrieved, and can be found by someone else if the design's rules say
  so. A ditched package is gone and the consequence is real.

## 2. The street reacts

- Paint the space from town state: patrols, weather, crowds, closed routes and
  the Police Sweep's current position, all read from the shipped models rather
  than a parallel copy.
- Sweep proximity must be legible before it is dangerous. The player should be
  able to make a bad decision knowingly.
- The verbs — move, wait, duck, stash, ditch — become actions on scene objects
  and positions with the `game06_1`-style equivalents for keyboard, controller
  and reduced motion where tactile input is used.
- Attention and pursuit stay the same underlying numbers with the same contracts.
  This row changes how they are seen and acted on, not what they are.

## 3. Lookout holds

- A hold is a place you stand and a thing you watch, with the shipped
  `hold_required_actions` and `hold_attention_limit` contracts preserved.
- Give the player something to actually do while holding: a sightline, a signal
  to send, a decision about when to break. Waiting must be a choice with
  tension, not a counter that decrements.
- Breaking a hold early, being spotted, and completing cleanly must each have
  distinct staged outcomes and distinct aftermath.

## 4. Pursuit and getaway

- The chase becomes a played sequence with real positions, routes, cover and
  exits, deterministic and seeded, with pursuit pressure derived from the landed
  model.
- Keep the chase verbs general enough for `world06_6` to reuse for the heist's
  hot exit. Do not build a heist-specific chase here, and do not build one that
  the heist cannot reuse.
- Escape, capture and the negotiated outcomes in between must each be reachable,
  distinct, and consistent with the landed consequence contracts.

## 5. Persistence, aftermath and honesty

- Every consequence fires exactly once across save, exit, travel, revisit and
  expiry. Abandoned runs resume or fail per an authored policy and never vanish.
- Aftermath persists at the node: a stash that is still there, a route that is
  watched now, a contact who remembers. A global flag alone is not aftermath.
- Job rewards, trust changes, grievances and street-debt consequences keep their
  landed values and their exactly-once semantics.
- Ordinary travel and ordinary node functionality must survive everywhere a
  delivery sequence can mount.

## 6. Tests and acceptance

- Every shipped job kind that routes through deliveries — `package_delivery`,
  `package_run`, `numbers_route`, `lookout_hold` — played end to end, with
  success, failure, abandonment, expiry and interruption.
- Exactly-once assertions on every reward, trust change, grievance and heat
  effect across save, reload, revisit and expiry.
- Sweep interaction: proximity, encounter, evasion and capture, with the sweep's
  own contracts unchanged.
- Stash persistence across travel, save, reload and run-terminal handling.
- 10-seed determinism for route generation, pursuit and every seeded reaction;
  no wall-clock time anywhere.
- Crew-ignoring runs remain a true no-op; extend the golden probe.
- Performance including the idle liveness counter-gate, native/Web parity, and
  accessibility for every verb.
- Visual QA: pickup, each stop, carrying under each town condition, sweep
  proximity, duck, stash, ditch, hold, break, chase, escape, capture, reduced
  motion, small screen.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA. Archive only with
exact evidence and with the reusable chase verb contract documented for
`world06_6`.
