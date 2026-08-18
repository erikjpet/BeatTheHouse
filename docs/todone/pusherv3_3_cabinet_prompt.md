Status: TODO
Board row: `pusherv3_3` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-18
- **Completion/implementation commits:** `4d2cd420`, `632384f1`, `ea99129e`
- **Verification:** PM line-by-line scope/design review; combined Systems, Contracts, and UI suites PASS; two-process 10-seed/510-checkpoint determinism PASS (`3528944666`); canonical visual QA PASS; full performance probe PASS unchanged; integrated GL feel capture PASS 9/9 with 300-body draw p95 2.126 ms and zero per-coin nodes.
- **Deviations:** None. Two transient full-performance failures were investigated against a matched pre-integration control and attributed to rotating host contention; the unchanged combined tree subsequently passed all existing budgets. No code, budget, or assertion was altered for convergence.

# Agent Prompt — pusherv3_3: The Alive Cabinet (renderer + audio)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. **Binding design
contract:** `docs/plans/coin_pusher_v3_machine_rework_plan.md`
section 6 — read the whole document first for context, then build
section 6 exactly. Your parity reference is
`scripts/games/slots/slot_renderer.gd`: study how it composes floor,
cabinet body, topper, glass, and the live game before drawing
anything. The owner's requirement, verbatim: "an alive cabinet like
the slot game does… the full scope of the game implemented as
background elements, in entirety, not just buttons representing
things like drop shove etc."

## Board protocol

1. Claim row `pusherv3_3` per board protocol. If not `TODO`, stop.
2. Log discoveries/deviations tagged `[pusherv3_3]`; owner questions
   to Owner Questions.
3. Blocked: row → `BLOCKED` + reason, log, stop.
4. Completion: row → `DONE` + note; Execution Record; archive;
   Work Log: pusherv3_4 unblocked.

## Dependencies

`pusherv3_1` + `pusherv3_2` DONE (live loop and state surface —
verify by code). The stage-1 placeholder surface is what you are
replacing.

## Task

### 1. New renderer at slot parity (plan 6.1–6.2)

`scripts/games/coin_pusher/coin_pusher_renderer.gd`, consumed by
`coin_pusher.gd`'s `draw_surface`. Cabinet catalog per machine
definition (`cabinet` block): Quarter Falls carnival brass/red;
Ridge purple/gold + plinko backboard; Vault steel/teal. Every listed
component drawn: floor shadow, body, side panels, marquee with the
machine name, backglass (sub-game displays live here), glass glare,
the coin slot and RAIL with the physical sliding carriage at its true
x, pegs exactly where the sim colliders are, the platform block with
shaded front face and lit top surface, the back plate, deck, tray
lip, TRAY BIN with a coin heap that grows with the ledger, gutter
mouths, and the SKILL STOP as a physical lit button. All controls
are cabinet hardware — the abstract right-hand console is deleted;
interactions map onto the drawn hardware (carriage drag/keys, drop,
stop button, tray collect touch target), reusing the surface input
idioms other games use.

### 2. Projection that shows the pile (plan 6.4)

Implement the numbers: rear width factor 0.78; coins as ellipses
rx 17 / ry 12 with rim highlight and 4 seeded rotation frames;
**z offset ≈ 11 px per COIN_HEIGHT** so stacking is unmistakable;
depth-sorted draw; drop shadows under raised/airborne coins; the
platform top visually distinct so riding coins read at a glance.
Batched drawing — no per-coin nodes; budget per plan 9.3.

### 3. Live rendering (plan 6.3)

Render from the live solver state every frame, interpolating between
the last two ticks. No traces, no replays. Reduce-motion setting:
skip interpolation, draw tick states directly (never skip the sim).

### 4. Audio (plan 6.5)

Physics-event-driven through the existing bus/manifest systems:
impacts scaled by fall height and stack depth, mass slide, motor
loop tracking stroke rate (winding down on skill stop — this sell is
important), tray cascade scaled by count, gutter swallow, plate
clink, tell chirps, alarm. Respect existing mix and accessibility
settings. Register new entries per the audio manifest conventions.

### 5. Feel captures (plan 9.4 — acceptance)

Capture and judge as a player: landing beside the row → row
advances; landing on the platform → ratchets ≥ 3 cycles; a topple
into a pocket; skill-stop bank + release; tray heap growth +
collection; the idle machine simply stroking. Bar: a person shown
any capture without context calls it a coin pusher. If it does not
clear the bar, say so honestly instead of shipping.

## Hard rules

- Presentation only: zero solver/outcome changes (stage-1 behavior
  contracts and determinism digests must pass unchanged).
- Budgets: surface draw p95 ≤ 5.0 ms at 300 coins mid-cascade;
  settled idle within the animated-idle budget WITH liveness counter
  (the stroking motor is the liveness).
- The renderer reads only the solver's public state/views — no
  reaching into solver internals.
- Style: tabs, typed GDScript; `.tmp/` reports; suite timeout =
  max(300s, baseline×1.5).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: renderer architecture, the cabinet catalog, projection
numbers as landed, audio event map, perf at 300 coins, and the feel
captures with your honest player-eye verdict. On an unfixable gate
failure: stop at the last green commit, set `BLOCKED`, report
verbatim.
