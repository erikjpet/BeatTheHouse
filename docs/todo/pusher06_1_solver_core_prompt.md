Status: SUPERSEDED — do not claim. The V3 machine rework
(docs/plans/coin_pusher_v3_machine_rework_plan.md, owner round-6 design session
2026-08-17) replaces this work. See the pusherv3_* rows on the board.
Board row: `pusher06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — pusher06_1: Authoritative Solver + Quarter Falls

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. Binding design contracts:
`docs/plans/0.6_coin_pusher_simulation_plan.md` (sections 2–4) and
the Coin Pusher section of `docs/plans/0.6_living_world_roadmap.md`.

## What this task is

Promote `pusher06_0`'s proven solver into the real game, replacing
the rejected coarse pile model (`lanes[].cells[].height` +
`edge_hang` boolean in `scripts/games/coin_pusher.gd`), and make
Quarter Falls play on it.

**The simulation is authoritative.** What physically crosses the
payout edge is what pays. There is no reconciliation layer, no
outcome table the physics is steered toward, and no seeded result the
coins merely animate toward. If you find yourself writing code that
decides a payout and then makes the coins agree, you have misread
this prompt — that is the exact defect the owner rejected.

## Board protocol

1. Before work: set row `pusher06_1` to `IN_PROGRESS` with agent +
   date in `docs/todo/README_0_6_board.md`, append a Work Log line,
   commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[pusher06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log naming
   `pusher06_2` unblocked.

## Dependencies

`pusher06_0` DONE with a **GO or Partial GO** verdict. Build to the
coin cap that verdict proved, not a hoped-for one. If the verdict was
NO-GO, do not claim this row — it is an owner decision.

## Task

### 1. Land the solver as the pile

- Move the proven solver into the game as the coin pusher's state.
  Delete the height-grid model, its edge-hang boolean, and every
  consumer that reasons in stack heights.
- Pile state is the set of real coins. Persist it in the node
  snapshot (world-map revisit contract): the physical arrangement the
  player built is there on return, and scenario reset flags may still
  replace it. Serialize compactly — coin state is fixed-point, so
  quantize deliberately and prove round-trip exactness.
- Keep the existing schema-version discipline; migrate old
  height-grid snapshots to a freshly seeded physical pile and log the
  migration (do not attempt to reconstruct a fake pile from heights).

### 2. Drops and the pusher

- Drop-lane aim and drop timing against the sweep cycle are the core
  skill and must be legible on screen (real position, real cycle
  phase — no "timing window" abstraction over an invisible cycle).
- A dropped coin is a real coin entering the field. Where it lands,
  what it disturbs, and whether anything falls are solver outcomes.
- Payout is read from the **tray sensor**: coins that physically
  crossed the lower ledge into the tray. Gutter losses are coins that
  physically went into the gutters. Record outcomes only after
  deterministic settle detection.

### 3. Carry the kept systems onto real coins

These shipped correctly and must survive with their contracts intact
(verify the landed behavior by code — code reality wins):

- **Nudge system**: force (tap/shove/slam) × direction × timing.
  A nudge is now a real impulse to the cabinet that shoves and
  topples actual coins. Well-timed, well-aimed nudges drop edge
  hangers cleanly; that skill expression must survive on real
  physics.
- **Hidden alarm tolerance** per node, modified by venue security,
  scenario overrides, and the swept-window; the **tell ladder**
  (cabinet rock, chirp, attendant glance) escalating before the line.
- **The alarm contract, unchanged**: a hard alarm locks that machine
  for the night, lands a significant heat spike, writes node memory
  (staff watch you next visit), and **never forces the player out of
  the environment** (owner decision 23) — other games in the venue
  stay playable and the heat flows through existing heat systems.
  Smash-and-grab stays a viable strategy: a slam produces a genuinely
  big physical drop before the alarm bites.
- **Cheat items** as real physical properties where possible:
  `cold_quarters` (denser/heavier coins), `coin_return_shim` (gutter
  recovery), `weighted_keyring` (heavier nudge within tolerance), the
  Mags dampener hook (tolerance band).
- Economy/heat integration, venue placement, scenario access effects
  (Graveyard Shift lax alarms, Trucker Convoy busy machine), and
  pusher-pile rumor facts.

### 4. Quarter Falls identity

Quarter Falls is the pure pusher. Its bonus layer is **prize riders**:
physical objects (chip stacks, a watch, a ticket roll,
scenario-seeded real inventory items) simulated *alongside* the coins
with their own mass/footprint, pushed and falling with the pile. A
prize that reaches the tray enters inventory. Skill is reading the
physical pile and choosing where to feed.

### 5. Economy honesty

Because the sim is authoritative, RTP is an *emergent* property.
Measure it, do not impose it:

- Run a large seeded harness and report the actual long-run coin EV
  band per machine configuration.
- Tune the **machine** (geometry, sweep throw, gutter width, drop
  cost, coin value, spawn seeding) to bring EV into the documented
  design band — never a post-hoc payout multiplier on simulated
  results.
- Document the final tuning and the measured band in data.

## Hard rules

- Authoritative simulation. No reconciliation, no steered outcomes.
- No re-abstraction of the pile under performance pressure: lower the
  coin cap and report the number (plan section 2).
- Determinism absolute: identical seed + inputs reproduce the exact
  pile, coin for coin, Windows and Web.
- Budgets: surface draw p95 ≤ 5.0 ms, animated idle within its budget
  **with the liveness counter**, frame p95 ≤ 16.0 ms.
- Alarm contract unchanged; no forced exit.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism: scripted 200-action session reproduces the exact
   final pile across runs, processes, and Windows vs Web.
2. Physics behaviors, each targeted: stacking, leaning, toppling,
   upper→lower fall, tray payout, gutter loss, cascade from a single
   landing, nudge-induced collapse.
3. Authority proof: a test that asserts payout equals tray sensor
   contents — with a deliberately introduced steering path failing
   the test (prove the guard works in both directions).
4. Nudge/alarm matrix: clean-drop windows, tolerance depletion per
   force, tell ladder order, hard alarm = lockdown + heat + node
   memory with the **player still in the environment**.
5. Prize riders ride, fall, and land in inventory.
6. Pile persistence across leave/revisit; scenario reset replaces it;
   save/load round-trips exact coin state; old-snapshot migration.
7. EV harness within the documented band, achieved by machine tuning.
8. Perf at the shipped cap; idle liveness green.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: solver integration shape, snapshot format and size, the
authority guard, kept-system verification, measured EV band and how
it was tuned, perf numbers at the shipped cap, and gate results. On
an unfixable gate failure: stop at the last green commit, set
`BLOCKED`, report verbatim.
