Status: TODO
Board row: `pusherv3_4` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — pusherv3_4: Variations, Integration, Closure

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. **Binding design
contract:** `docs/plans/coin_pusher_v3_machine_rework_plan.md` —
sections 3.5, 5.3–5.5, 7, 8, 9. This stage puts the other machines on
the new physics, re-wires the town/economy integrations, and closes
the coin pusher rebuild.

## Board protocol

1. Claim row `pusherv3_4` per board protocol. If not `TODO`, stop.
2. Log discoveries/deviations tagged `[pusherv3_4]`; owner questions
   to Owner Questions.
3. Blocked: row → `BLOCKED` + reason, log, stop.
4. Completion: row → `DONE` + note; Execution Record; archive;
   Work Log entry closing the V3 rebuild.

## Dependencies

`pusherv3_1/2/3` DONE (verify by code).

## Task

### 0. Amendment 6.2 — rear-fed visible delivery surface

- Replace the rejected direct-to-lower-deck landing window. Every machine
  releases at the rear delivery board and every inserted coin's first support
  must be the moving upper platform or stock supported by it, at every stroke
  phase. Only the carry + back-plate ratchet may later deposit it to the deck.
- The delivery area is a real, data-defined cabinet surface, not hidden
  simulation or decorative pins: show its bounds, entry hardware, the live
  falling coin, shadow, every solver peg contact/bounce, and the final landing.
  Renderer pins and trajectories must use the exact public solver geometry.
- Timing still changes the upper-row/gap/stack landing topology. It never acts
  as a scalar and never rewards or punishes timing by skipping a level.
- Add behavior and player-eye capture contracts proving all-phase upper
  landing, no direct deck bypass, a visible real peg bounce, and continuous
  readable descent for Quarter Falls, Ridge, and Vault.

### 1. Jackpot Ridge on the real machine (plan 3.5, 5.5)

- Machine definition: `hole_set` apparatus (3 holes at
  x = 25000/50000/75000) over a full 5-row offset plinko board
  (pegs in data, colliders in sim, pins drawn on the cabinet
  backboard route). Purple/gold cabinet identity.
- Pucks are physical bodies on the deck (mass ≈ 3× coin), seeded
  from sub-game data; multiplier/lock/jam logic consumes PHYSICAL
  exit and position events only. A jammed lane is a puck physically
  sitting in a hole mouth — remove it by pushing it out. Ridge's
  multiplier scales tray-value crediting of coins that fell while
  armed (plan 5.5) — it never moves a coin.
- A physically banked lock puck preserves the currently armed multiplier
  against expiry for one complete 240-tick stroke cycle. It does not stop,
  slow, or otherwise steer the motor/platform physics.
- Ridge Run (three multipliers banked within one stroke cycle) sets
  `rate = 2` for its bonus cycles — a physically faster motor, with
  the motor-pitch audio following.

### 2. Vault Drop on the real machine (plan 5.5)

- Key fragments as physical bodies; banking = physically crossing
  the tray lip. Vault round, RESET odds, town-fed progressive, and
  xray peek all preserved against the new state; the meter and vault
  door live on the cabinet backglass (stage 3 reserved the space).
- Apparatus per its definition (rail_slot with its own peg layout
  until the third machine's design arrives; the schema fields for a
  future custom apparatus stay open — owner will design it later).

### 3. Integration re-wiring (plan 5.3–5.4)

- Nudge in continuous time: impulse to all bodies per force ×
  direction data; tolerance, tell ladder (600-tick rung decay), hard
  alarm night-lock (motor stops, cabinet dark, slot refuses — player
  never ejected). Skill stop stays outside the tell system entirely.
- Cheat items against the new state: cold_quarters (mass), shim
  (gutter recovery re-implemented as a physical return: the coin
  re-enters at the gutter mouth), weighted_keyring, Mags dampener,
  xray.
- Town: scenario tolerance deltas, swept-window, Graveyard/Convoy
  effects, pusher-pile rumor facts + the new "tray is loaded" fact
  class, alarm reputation incident.
- The `fix06_1` interactability class guard must cover every new
  cabinet interaction.

### 4. Economy + EV harness (plan 5.5, 9)

- ≥200k-drop scripted-policy harness per machine; report measured EV
  bands; tune ONLY machine geometry/apparatus to the documented
  bands; document every tuned value. No payout multipliers on
  physics.
- Vault Drop's physical coin-to-tray EV band is `[0.72, 0.94]`, measured
  separately from its meter-dependent vault-round option value.

### 5. Closure

- Migration verified across all three machines (plan 8).
- Full feel-capture set per machine (plan 9.4).
- Board: mark the V3 section complete; confirm the superseded
  pusher06_* rows stay closed; hand the playtest seeds for all three
  machines to the playtest06_1 evidence pool.

## Hard rules

- Three machines must play as three machines — apparatus, geometry,
  cabinet, and sub-game all differ by DATA; any variation-specific
  branch in solver or renderer code is a defect.
- Sub-games consume physics; they never steer it.
- Determinism (input-trace + parity), budgets, no-coin-deletion,
  idle liveness: all stage-1/2/3 gates re-run green on the final
  tree.
- Style: tabs, typed GDScript; `.tmp/` reports; suite timeout =
  max(300s, baseline×1.5).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the input-trace export-parity runner (Windows + Web)
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: both machines' definitions, the physical puck/fragment
behavior evidence, integration re-wiring results, measured EV bands
with tuning notes, migration proof, the per-machine feel captures,
and your honest verdict on whether the family now reads as three
real machines. On an unfixable gate failure: stop at the last green
commit, set `BLOCKED`, report verbatim.
