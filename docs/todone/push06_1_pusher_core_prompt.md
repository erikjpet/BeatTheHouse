Status: DONE
Board row: `push06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-14
- **Completion/implementation commits:** `7e445f3a..67237a63`; integrated by `1147b11b`; reduced-motion proofs `fac1a038`, `6cc0b7f3`
- **Verification:** PM line-by-line scope/design review; project validation; dedicated Coin Pusher, systems, and full UI suites; 10-seed determinism (430 checkpoints, hash `4169024088`); canonical visual QA; and five-image focused pile/tell/reduced-motion/alarm/room smoke all PASS on the integrated tree.
- **Deviations:** None. The core ships Quarter Falls only; the additional two authored variations remain owned by `push06_2`.

# Agent Prompt — 0.6 push06_1: Coin Pusher Core + Nudge System + Quarter Falls

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Games live under
`scripts/games/` registered in `data/games/games.json`. Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 4 "Coin
Pusher", including **round-4 decision 23: a hard alarm does NOT force
the player out** — it locks the machine for the night and lands a
significant heat spike that flows through existing heat systems
(floor-staff warnings, pit pressure, sweep interplay), which may
organically force departure. Slot/pinball history warning: per-frame
deep-copies have burned this project repeatedly — the pile sim must be
coarse, seeded, and budgeted. This prompt is self-contained for rules
and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `push06_1`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[push06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log: push06_2
   unblocked.

## Dependencies

`env06_1` DONE (alarm tolerance band arrives via scenario security
overrides; pile persistence rides node snapshots). Verify by code.

## Task

### 1. Pusher framework

- New game family module (`scripts/games/coin_pusher.gd` + data
  entries): a **deterministic, coarse pile model** — discretized
  lanes/cells with stack heights and edge-hang states, not free
  physics. Seeded initial piles per node; every drop/shelf/nudge
  outcome derives from run RNG + pile state. Shelf oscillation is
  turn-stepped (per drop), not wall-clock.
- Drop-lane aim + drop timing against the shelf cycle; payout tray;
  side gutters. All tuning in `data/games/games.json`.
- **Pile persistence**: pile state serializes into the node's
  environment snapshot (world-map revisit contract); scenario
  mutations may reset/replace piles ("someone else played it") via a
  documented data flag. Register a pusher-pile rumor fact with
  town06_2's registry if landed (else log the deferred wiring).

### 2. Universal nudge system (round-3/4 locked design)

- Nudge verb on every variation: choose force (`tap/shove/slam`) ×
  direction (`left/right/front`) × timing vs the shelf phase.
- Hidden per-machine alarm tolerance: seeded per node, modified by
  venue security band and tonight's scenario override (Graveyard
  Shift lax; Serial-Check adjacency strict; swept-window +1 band).
- **Tell ladder** before the line: machine rock animation, audible
  chirp, attendant-glance suspicion tick — readable escalation so the
  line is walkable on purpose.
- Well-timed, well-aimed nudges at the right shelf phase drop edge
  hangers **cleanly** — the skill expression; mistimed nudges waste
  tolerance for little.
- **Hard alarm**: machine locks down for the night (session on that
  machine ends; other machines/games in the venue stay available) +
  significant heat spike (data-tuned) + node memory flag (staff watch
  you: suspicion floor raised at this venue for the run). **No forced
  exit** — escalation happens only through the existing
  heat-threshold systems. Write a reputation incident via town06_2's
  writer API if landed.
- Slam-and-grab must be a real strategy: a slam produces a big drop
  before/with the alarm — tune so the greedy play is coherent.

### 3. Quarter Falls (variation 1)

- Timing/topology identity: two oscillating shelves, lanes with
  approach angles, readable overhangs and edge hangers.
- **Prize riders**: items riding the pile (chip stacks, ticket rolls,
  scenario-seeded real inventory items — data-driven rarity), pushed
  forward physically with the pile.
- Cheat items: `cold_quarters` (denser drops — stronger push),
  `coin_return_shim` (recover a gutter loss, limited uses).
- Placement: tier-1 venues (`gas_station_casino`, `corner_store`,
  `bar`) via game pools; availability seeded per node.

## Hard rules

- Determinism: identical seed + input sequence → identical pile
  evolution, drops, and alarm outcomes (probe-integrated).
- Perf: pile model updates on player actions only; rendering budgeted
  like a game surface; **idle liveness green with the machine
  animating its idle attract state** (never a frozen 0.000 — the 4x
  idle-animation regression pattern is the known trap).
- Save compat: pile + lockdown + node-memory states serialize;
  schema-versioned.
- Voice: machine/attendant strings in street register.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism: scripted 200-action session reproduces exactly across
   two runs on one seed.
2. Nudge matrix: clean-drop windows work; tolerance depletes per
   force; tell ladder fires in order; hard alarm = lockdown + heat +
   memory flag, **player remains in the environment** with other
   games playable.
3. Scenario/security/swept-window tolerance modifiers apply.
4. Pile persists across leave/revisit; scenario reset flag replaces
   it; save/load round-trips.
5. Prize rider reaches the tray and lands in inventory.
6. Payout/economy harness: long-run coin EV within documented band.
7. Visual QA + manual smoke; screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: pile model shape, nudge/alarm tuning, persistence fields, EV
band, and gate results. On an unfixable gate failure: stop at last
green commit, set `BLOCKED`, report verbatim.
