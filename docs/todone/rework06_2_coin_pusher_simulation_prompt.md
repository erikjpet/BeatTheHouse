Status: DONE
Board row: `rework06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-17
- **Completion/implementation commits:** `8be3efab`, `6109e81a`, `6cf0a1e8`, `e4e35428`, `85a928c6`, `53f4d5bd`, `56b13ce0`, `c820b67e`, `e516facb`
- **Verification:** PM scope/design review complete. Coin Pusher and Baccarat focused suites, the complete UI matrix, determinism twice (10 seeds, 590 checkpoints, hash `3543536704`), canonical visual QA (zero warnings), shipped-cap performance at 48 bodies, EV harnesses, all six feel captures, and exact 200-action Windows/Web export parity passed. Systems assertions and stderr checks were all green; final wall time was baseline-equivalent under the same load (`45.549s` versus `45.377s`) and was accepted under the owner's environmental-timing rule.
- **Deviations:** The accepted simulation cap is 48. The owner-confirmed density/presentation gap belongs to `pusher06_2`, not this solver rework. No assertion, budget, liveness floor, or deterministic check was weakened.

# Agent Prompt — 0.6 rework06_2: Real Coin Pusher Simulation (replaces the coarse pile model)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — read the
**Coin Pusher** section of Pillar 4 in full, including the superseded
design note, before anything else.

## Why this task exists

`push06_1`/`push06_2` shipped the pile as an abstraction: per-lane
cells holding an integer `height` plus an `edge_hang` boolean
(`scripts/games/coin_pusher.gd`, `lanes[].cells[].height`). It was
built exactly to the old spec. The owner played it and rejected it:
**it is not a coin pusher, it is a game loosely based on one.**

The requirement is now a real machine: individual coins, coins
stacking on each other, gravity, falls between levels, and a unique
bonus sub-game per variation. This is a **simulation rewrite**, not a
tuning pass. Do not preserve the height-grid because it exists.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `rework06_2` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[rework06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Dependencies

`env06_1`, `town06_1` DONE. The existing `push06_1`/`push06_2` work
lives on the Wave C integration branch; you replace its simulation
core and keep the parts listed under "Keep" below. Verify by code.

## Task

### 1. The coin simulation (the heart of this task)

Replace the height-grid with a **discrete-coin simulation**:

- **Individual coins.** Each coin is its own object with position,
  and rest/settling state. No aggregate stack counters standing in
  for coins. The number of coins on the field is a real number of
  real coins.
- **Stacking.** Coins rest on the field and on each other. Piles
  build unevenly, lean, and topple. A coin landing on a leaning stack
  disturbs it. Overhangs form naturally at the ledge because coins
  are physically there — not because a boolean says so.
- **Levels and gravity.** The cabinet has tiers. Coins pushed off the
  **upper shelf fall onto the lower field**, landing among and
  disturbing the coins already there. Coins pushed off the lower
  field fall into the **tray** (payout) or the **side gutters**
  (loss). Falls cascade: one landing can shift or topple others.
- **The pusher.** A shelf sweeps forward and back on a physical
  cycle, bulldozing what is in front of it. Timing a drop against
  that cycle is the core skill and must be legible on screen.
- **Emergent state.** The pile is the *result* of play, not a seeded
  abstraction. It persists in the node snapshot: the physical
  arrangement the player built is there on revisit (scenario reset
  flags may still replace it).

### 2. Determinism and performance are engineering constraints, not excuses

- **Determinism is absolute** (project hard rule). Implement a
  **fixed-timestep, seeded, integer or fixed-point solver the game
  owns.** Do not use an off-the-shelf floating-point physics engine
  whose results can drift across platforms/frame rates. Identical
  seed + identical input sequence must reproduce the identical final
  pile, coin for coin, on Windows and Web.
- **Performance is a budgeting problem to solve**, not a reason to
  abstract the pile away: cap coins per cabinet (tune to a real
  machine's feel), sleep settled coins and wake them only on
  disturbance, step the solver only while the machine is active, and
  budget the render like the other game surfaces. Idle attract state
  must animate and satisfy the liveness counter-gate (a 0.000 idle
  number without its counter is an automatic FAIL — this project's
  recurring regression).
- If you cannot hit budget at your first coin cap, lower the cap and
  report the number. Do not re-abstract the simulation.

### 3. Per-variation bonus sub-games (unique systems, not shared logic)

Each variation keeps its identity and gains a **distinct sub-game
that affects bonus payout**. They must be genuinely different
mechanics — a player should describe them as three different machines:

- **Quarter Falls** — the pure pusher. Its bonus layer is the
  **prize riders**: physical objects sitting *in* the pile (chip
  stacks, a watch, a ticket roll, scenario-seeded real inventory
  items) that are pushed and fall with the coins because they are
  simulated alongside them. Skill = reading the physical pile.
- **Jackpot Ridge** — **feature pucks** in the pile: multipliers,
  shelf locks, dud jams. They are physical objects that must be
  *pushed off* to bank them, so the sub-game is a sequencing/physics
  puzzle: which puck to work loose first, and what the pile does when
  you do. Ridge Run cascade on three multipliers banked in a cycle.
- **The Vault Drop** — **key fragments** in the pile bank toward a
  vault round: a pick-and-reveal bonus behind a door on the
  playfield, paying from a **town-fed progressive meter** (TownState
  driven, growing on action boundaries, faster in crowded scenarios).
  Vault cells hold cash, items, fragment refunds, and a RESET cell;
  odds documented in data and honest. `xray_glasses` peeks one cell.

### 4. Keep (do not rebuild)

These landed correctly and the owner did not reject them — carry them
onto the new core:

- The **universal nudge system**: force (tap/shove/slam) × direction ×
  timing, hidden per-node alarm tolerance modified by venue security,
  scenario overrides, and the swept-window; the **tell ladder** (rock,
  chirp, attendant glance); clean-drop skill windows. Nudges now act
  on **real coins** — a nudge shifts and topples the physical pile,
  which is what makes the mechanic honest.
- The **alarm contract**: hard alarm locks that machine for the night,
  lands a significant heat spike, writes node memory (staff watch
  you) — and **never forces the player out of the environment**
  (owner decision 23). Smash-and-grab stays a viable strategy.
- Cheat items: `cold_quarters` (denser/heavier coins — now a real
  physical property), `coin_return_shim` (gutter recovery),
  `weighted_keyring` (heavier nudge within tolerance), the Mags
  dampener hook, `xray_glasses` for the vault.
- Placement/distribution across tier-1 venues, scenario access
  effects (Graveyard Shift lax alarms, Trucker Convoy busy machine),
  pusher-pile rumor facts, and pile persistence in node snapshots.

### 5. Feel verification (this is an acceptance requirement, not QA garnish)

Capture evidence that a person would call a coin pusher: a drop
landing on a pile and disturbing it; a stack toppling; coins falling
from the upper shelf onto the lower field; a nudge shifting a real
pile; an edge hanger falling to the tray; the gutter eating a greedy
shot. Save captures to `.tmp/` and reference them in your report. If
the captures do not look like a coin pusher, the task is not done.

## Hard rules

- No abstraction of the pile back into stack counters, under any
  performance pressure. Lower the coin cap instead and report it.
- Determinism proven cross-platform (Windows + Web export), not just
  in one process.
- The three variations must not share one sub-game with different
  numbers.
- Alarm contract unchanged (no forced exit).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism: a scripted 200-action session reproduces the exact
   final pile (coin count and arrangement) across runs and across
   Windows/Web exports.
2. Physics behaviors, each with a targeted test: stacking, leaning,
   toppling, upper→lower fall, tray payout, gutter loss, cascade from
   a single landing, nudge-induced collapse.
3. Nudge/alarm matrix intact: clean-drop windows, tolerance depletion
   per force, tell ladder order, hard alarm = lockdown + heat + node
   memory with the **player still in the environment** and other
   games playable.
4. Per-variation sub-games: prize riders ride and land; puck
   sequencing (arm/lock/jam/clear) and Ridge Run trigger; fragments
   bank, vault round pays, RESET honest, xray peek truthful; meter
   grows only on boundaries and faster under a crowded fixture.
5. Pile persistence across leave/revisit; scenario reset replaces it;
   save/load round-trips exact coin state.
6. Perf: frame budget met at the shipped coin cap; idle attract
   animates with liveness counter green.
7. EV harness per variation within documented bands.
8. Feel captures per section 5.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: solver design (timestep, fixed-point scheme, coin cap,
sleeping strategy), the three sub-games, determinism evidence
including Web, perf numbers, EV bands, and the feel captures. On an
unfixable gate failure: stop at the last green commit, set `BLOCKED`,
report verbatim.
