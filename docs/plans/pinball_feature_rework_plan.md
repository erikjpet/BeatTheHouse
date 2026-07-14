# Pinball Feature Event — Complete Rework Plan

Status: **IMPLEMENTED for the unreleased 0.4.0 candidate.** Section 1 describes
the removed pre-rework dictionary runtime. The live feature is under
`scripts/games/slots/pinball/`; `slot_pinball_table.gd` was deleted as planned.
Date: 2026-07-01
Reference feel target: **Ballionaire** (roguelike plinko) — fast drops, readable boards,
trigger-chain satisfaction, item-driven builds. Blended with a **licensed pinball slot
feature** structure (locks → multiball → jackpot ladder) and a **skill-shot launch**.

---

## 1. Why a clean rebuild (not a fix)

The current implementation (`scripts/games/slots/slot_family_pinball.gd` +
`slot_pinball_table.gd`) is a dictionary-state physics sim pumped through the
turn-based game-state pipeline. The game-wide slowdown during the feature is
structural, not a tuning bug:

- **Per-tick deep copies of everything.** Each 60Hz auto-tick runs
  `read_machine` → `duplicate(true)` of the whole machine dict — including the
  live `pinball_session` (100+ element dicts, spatial bins, event log,
  trajectory array) and a `history` array of up to 24 entries that each hold
  their *own* copies of trajectories and event logs. Then `write_machine`/
  `normalize` deep-copies it all back. `_advance_pinball_ball` adds a dozen
  more `_copy_dict`/`_copy_array`/`duplicate(true)` passes per tick, and
  `slot_presentation.surface_state` copies the session again every render frame.
- **O(history) growth.** Trajectory/event trimming exists but the copies are
  taken *before* trimming, and history entries embed full per-step trajectories,
  so allocation cost grows with session length.
- **Everything is Variant dictionaries.** Balls, elements, and vectors are
  Dictionary/Variant, so even the pure math path (collision, damping, substeps)
  pays boxing, hashing, and string-key lookup on every access.
- **Table object re-instantiated constantly.** `TableScript.new()` per step,
  per query (`_has_active_ball`), per sync.
- **Sim clock is hostage to the action pipeline.** Ticks arrive as
  `slot_bonus_tick` surface actions with catch-up budgets (`LIVE_TICK_BUDGET`),
  so physics pacing degrades exactly when frame time degrades — a feedback loop.

Conclusion: keep the *concepts* that work (deterministic fixed-dt plinko sim,
normalized 0..1 board space, element vocabulary, layout-as-data, item hooks,
headless probes) and rebuild the runtime, state boundary, boards, and feel from
scratch.

---

## 2. Product goals

1. **Ballionaire-round feel.** A feature round should play like a Ballionaire
   drop: ball in play within ~1s of the bonus opening, each ball's playout
   3–8 seconds, constant visible cause→effect (peg streaks, bumper pops,
   trigger lights), and a payout tally that climbs live.
2. **Lifelike, quick physics.** Proper gravity/restitution plinko fall with
   pinball verticality: bumpers, kickers, launchers, and flipper zones that can
   throw the ball back UP the board for streaks and second chances.
3. **Slot-feature structure.** The bonus reads like a branded pinball slot
   machine feature: skill shot → mode qualification → ball locks → multiball →
   jackpot → super jackpot ladder, with lit inserts telegraphing state.
4. **Skill matters, bounded.** Timed launch (meter), aim, and mid-flight nudges
   let a good player (or an item-boosted one) reliably reach high-pay areas —
   but inside an auditable math envelope (cap + RTP budget).
5. **Items are the roguelike layer.** Existing 6 pinball items plug into
   first-class sim hooks; new items modify the *board itself* (Ballionaire
   style), not just payouts.
6. **Never slows the game.** Hard perf gates: feature tick + render must fit
   the existing probe budgets on the min-spec target with zero GC pressure.

---

## 3. New architecture

### 3.1 Module layout

```
scripts/games/slots/pinball/
  pinball_sim.gd          # persistent fixed-dt physics core (the only hot loop)
  pinball_board.gd        # board compiler: layout JSON/dict -> immutable typed arrays
  pinball_boards.gd       # the 3 board definitions (data only)
  pinball_sequencer.gd    # feature state machine (skill shot, locks, multiball, jackpots)
  pinball_items.gd        # item hook registry + effect application
  pinball_feature.gd      # thin adapter: slot family API <-> sim runtime
  pinball_view.gd         # read-only render view + interpolation for the renderer
data/games/pinball_boards.json   # optional: boards as content data (stretch)
```

`slot_family_pinball.gd` shrinks to: outcome table / grid / payout logic
(unchanged responsibilities) + delegation to `pinball_feature.gd` for the bonus.
`slot_pinball_table.gd` is deleted.

### 3.2 The state boundary (the actual perf fix)

**Live sim state never enters the machine dictionary.**

- `PinballSim` is a long-lived object held in a runtime cache
  (`PinballFeature.session_for(machine_id)`), created when the feature opens,
  freed when it completes. The surface/auto-tick path passes a reference; no
  copies.
- The machine dict stores only a compact, serializable summary written at
  **ball-end boundaries** (not per tick): `{seed, board_id, balls_remaining,
  total_awarded, sequencer_snapshot, input_log}` — a few hundred bytes.
- Save/load mid-ball: the sim is deterministic (fixed dt + seeded RNG + logged
  inputs), so a mid-ball save resumes by fast-forward replaying `input_log`
  headlessly (milliseconds), or — simpler v1 — the ball is settled to its
  deterministic outcome on save and the summary stored. Decide in Phase 2;
  default to settle-on-save.
- Presentation/renderer read through `PinballView`, which exposes packed arrays
  by reference (positions, radii, lit flags) — zero copies per frame.

### 3.3 Sim core data model (zero-allocation hot loop)

- Fixed dt **1/120s**, accumulator driven by real frame delta from the surface
  clock; render interpolates between last two sim states. Physics pacing is
  therefore independent of the action pipeline — `slot_bonus_tick` disappears;
  the surface runtime calls `sim.advance(delta_msec, input)` directly once per
  frame.
- Balls: parallel packed arrays (`PackedVector2Array pos/prev_pos/vel`,
  `PackedFloat32Array radius`, `PackedInt32Array flags/age/stuck`), fixed max
  (12), free-list indices. No per-ball dictionaries.
- Board: compiled once by `pinball_board.gd` into immutable typed arrays —
  peg positions/radii, bumper table (pos, radius, kick, cooldown), sensor
  table, rect table, and a **static spatial hash** (`PackedInt32Array` cell →
  element index spans). Built at feature open, never mutated per tick (item
  layout mods recompile once).
- Events: fixed-size ring buffer of small structs
  (`{tick, type_id, element_index, ball_index, award, pos}`); presentation
  drains it each frame into transient juice cues; nothing accumulates.
- Trajectory recording: **removed entirely.** The renderer draws live balls;
  ghost trails come from the renderer keeping its own tiny ring of recent
  positions. Headless probes read the event buffer + final totals.
- RNG: one dedicated seeded `RngStream` owned by the sim; every random pull is
  logged-count-verifiable for determinism tests.

### 3.4 Physics spec (feel targets)

Phase 0 reconciled these targets against
`docs/plans/pinball_feel_reference.md`. Physics constants are necessary but not
sufficient: Ballionaire-like feel also requires first-payout latency, visible
event density, and live tally cadence targets.

| Parameter | Target | Notes |
|---|---|---|
| Feature-open to launch-ready | <= 1.0s | Player should be in the drop almost immediately |
| Launch to first visible payout/event | <= 0.75s median, <= 1.0s p90 | The first bonk/payout must arrive quickly |
| Untouched fall | 1.3-1.6s | Top-to-bottom with no meaningful contacts |
| Normal single-ball playout | 3.0-8.0s | Contacts, upward kicks, portals, and flippers extend play |
| Visible event density | 2-5 events/s normal, 6-12 events/s for <= 2s chain bursts | Keeps trigger chains satisfying but readable |
| Live tally cadence | Event floater <= 100ms; drain-to-bank tally 0.4-1.2s; count-up >= 20 increments/s capped at 1.2s | Score must climb live without delaying the next ball |
| Gravity | 2.8-3.4 board-heights/s^2 | Fast Ballionaire-style fall; full drop ~1.4s if untouched |
| Ball radius | 0.012–0.014 | Board space is 0..1 |
| Peg restitution | 0.50-0.62 | Crisp plinko clatter, no floatiness |
| Bumper kick | 2.1-3.0 speed units + directional | Cooldown 6-8 ticks, must visibly launch upward |
| Wall restitution | 0.35-0.45 | Deadens edge play without sticky side walls |
| Max speed | ~9 units/s | With substep count 1–4 by speed (swept circle CCD vs pegs) |
| Tangential bias | small deterministic per-peg side bias + ball spin term | Produces lifelike streaks, kills pixel-perfect symmetry |
| Nudge impulse | 0.4-0.6 lateral, tiny lift | Instant, applied to all live balls; about 3 comfortable nudges/ball before tilt warning |
| Flipper zones | timed arc impulse (120-180ms prompt window) | Simplified flippers: fixed rescue positions above outlanes; a well-timed press converts a drain into an up-board relaunch |

Spin (angular term) is new: collisions transfer tangential velocity into a
scalar spin that biases subsequent bounces — cheap (1 float/ball) and the
single biggest "lifelike" upgrade over the current sim.

Stuck handling stays (rescue kick then force-drain) but on typed state.

### 3.5 Determinism & audit surface

- `sim.run_headless(seed, board, input_script) -> result` reproduces any round.
- Rewrite `tools/slot_pinball_physics_audit.gd` against the new core: N-seed
  sweep asserting drain rate, average ticks per ball, award distribution vs
  cap, zero stuck-forever balls.
- Rewrite `tools/slot_pinball_performance_probe.gd` budgets: sim tick
  ≤ 150µs avg @ 4 live balls, surface_state ≤ 300µs, zero allocations per tick
  (assert via `Performance.OBJECT_COUNT` delta in the probe).

---

## 4. Board & sequence design

Three boards, mapped to the existing three feature modes so trigger plumbing
(`em_bumper_drop`, `lane_multiball`, `video_feature`) is unchanged. Shared
element vocabulary (the "board grammar"):

**Element vocabulary:** peg, pop bumper, slingshot (angled kicker), drop target
(disappears when hit, bank completion = award/light), standup target, rollover
lane, lock gate, saucer/kickout hole, launcher/kicker (up-board impulse),
spinner (award per pass-through tick), portal pair, splitter, multiplier gate,
pocket row (bottom pay slots), jackpot cup, drain (bottom-outer + outlanes),
flipper rescue zones, skill-shot lane.

### Board A — "Bumper Alley" (mode `em_bumper_drop`, low volatility, 1–3 balls)

EM-era feel: peg pyramid over twin pop bumpers, pocket row bottom.

- Geometry: 7-row peg pyramid; 2 pop bumpers mid-board; 2 slingshots above
  the pocket row; skill-shot saucer top-right reachable only from a sweet-spot
  launch; pocket row `10 / 16 / SAFE 24 / 16 / 10` + two outlane drains;
  1 flipper rescue zone above each outlane.
- Sequences:
  - **Skill Shot:** sweet-spot launch (meter) rides the right rail into the
    saucer → instant award (8× pocket base) + lights **Double Pockets** for
    that ball.
  - **Bumper Streak:** 4 bumper/slingshot hits on one ball without touching a
    peg row below the bumpers → +1x ball multiplier (max 3x), insert lit.
  - **Alley Loop:** pocket→launcher kickout→bumper→pocket within timer →
    fixed combo bonus.
- Role: the common, quick feature. Whole event 8–20s.

### Board B — "Lock & Cascade" (mode `lane_multiball`, medium volatility, 3–5 balls)

The multiball board — closest to a modern pinball slot feature.

- Geometry: 9-row denser peg field; 3 pop bumpers in triangle; **2 lock gates**
  (left/right mid-board); splitter sensor top-center; multiplier gate (+1x,
  max 4x) center-low; portal (bottom-right → top-left re-entry); pocket row
  `14 / 20 / 28 / 20 / 14`; jackpot cup between pockets 3 and 4 (narrow).
- Sequences:
  - **Locks → Multiball:** landing a ball in a lock gate *holds it visibly on
    the board* (not just a counter). Third lock releases all held balls +1
    bonus ball = 3–4 ball multiball with all awards ×2 while ≥2 balls live.
  - **Cascade:** splitter during multiball spawns an extra ball (respecting max
    live cap 8).
  - **Jackpot:** during multiball, jackpot cup pays jackpot (stake-scaled),
    relights after both lock gates are re-hit.
  - **Portal Combo:** portal→bumper→multiplier gate inside timer → +1x that
    persists rest of feature.
- Role: the mid-tier "big feature." 20–40s.

### Board C — "Jackpot Works" (mode `video_feature`, high volatility, 3–5 balls)

The wizard-mode board; ladder structure like a licensed video slot pinball
bonus.

- Geometry: 10-row peg lab; 4 bumpers; **A-B-C drop-target bank** upper-center;
  2 up-launchers low-left/low-right that fire the ball back to the top; portal
  right edge; spinner lane left edge; multiplier gate (max 5x); pocket row
  `12 / 18 / 24 / 18 / 12`; **SUPER lane** (wide, center-right, only opens —
  gate sprite retracts — while Super Jackpot is lit); **RISK cup** top-right
  (hard to reach, 6× jackpot, reachable mainly via launcher timing or nudge).
- Sequence ladder (each stage lights inserts and re-arms):
  1. **Qualify:** complete A-B-C target bank → Super Jackpot lit, SUPER lane
     opens for 1 ball-life.
  2. **Super Jackpot:** ball into SUPER lane while lit → big award (≈2.8×
     stake × scale), bank resets.
  3. **Lock ×2 → Multiball:** launchers double as locks; 2 locks → 3-ball
     multiball; every bumper/target during multiball pays mini-jackpots.
  4. **Wizard:** complete the bank *during* multiball → **Jackpot Works**
     mode: 5 seconds where every element pays double and the RISK cup is
     magnetized (widened capture radius). This is the aspirational moment.
- Role: rare, high-ceiling. 30–60s.

### Sequencer implementation

`pinball_sequencer.gd` is a plain state machine fed by sim events (typed enum,
not string compare): per-board rule table
`{trigger: element/event pattern, condition: lights/locks state, effect:
award/light/gate/spawn/multiplier, reset}`. All awards route through one
`award(amount, source)` function that applies multipliers, item modifiers, and
the session cap — one choke point for math audit.

---

## 5. Skill systems

1. **Launch skill shot (timing).** A visible plunger meter oscillates
   (~1.1s period, eased so the sweet spot passes quickly). Player presses
   launch; sampled power = meter position (replaces today's fake
   `sweet_spot=82` snapshot that ignores timing). Ratings: `sweet` (±3) rides
   the skill-shot rail; `good` (±8) clean launch; `wild` (±20+) adds spread.
   Aim (launch x-position + angle) stays as drag/arrow input pre-launch.
2. **Nudges (trajectory control).** Left/right/up nudge with instant impulse;
   tilt meter fills per nudge and decays; exceeding it tilts = all balls
   drained, sequence lights preserved (not awards-in-flight). Nudge budget is
   the roguelike lever: base ~3 comfortable nudges/ball; `tilt_dampener`
   extends; new items can add nudge strength or refunds.
3. **Flipper rescue (timing).** When a ball enters an outlane approach zone, a
   flipper prompt window opens (~150ms). A timed press fires the flipper
   impulse, throwing the ball back up-board. Misses drain normally. This is
   the mid-play timing skill the current build lacks.
4. **Skill ceiling / math bound.** Perfect play targets: +15–25% average
   feature return over baseline, always inside `session_cap`. Verified by
   headless probes running a "perfect-play policy" vs "random policy" across
   1000 seeds; the delta is a tuned, asserted number.

---

## 6. Items

### 6.1 Existing items → new hooks

| Item | Current effect | New-sim hook |
|---|---|---|
| `drain_cleaner` | once/feature, bad drain pays floor | Sequencer `on_ball_drained`: if feature total below floor%, top up (unchanged math, cleaner hook) |
| `jackpot_magnet` | jackpot progress +1, richer jackpot zone | Sequencer: charges add ladder progress on target/cup hits; +award% on jackpot-class awards; visually widens jackpot cup capture radius slightly |
| `splitter_token` | first splitter +1 ball | Board compile: splitter element `spawn_count += extra` for first N triggers |
| `return_spring` | once, slow low ball springs up | Sim `on_low_energy_low_board`: replaced by an auto-fired launcher impulse with its own VFX (reads as a board device, not teleport) |
| `tilt_dampener` | forgiving nudges | Tilt meter gain ×(1−percent); also slows decay threshold warning |
| `bumper_battery` | first bumper hits pop harder + pay | Bumper table: first N hits get kick×% and flat award% of stake, distinct spark VFX |

### 6.2 New item proposals (Ballionaire-style board modifiers)

Board-mod (permanent class, `slot_pack` group):
- **Rubber Pegs** — all peg restitution +15%: livelier board, more streaks.
- **Magnet Cup** — jackpot/RISK cups gain a weak attraction field (bends
  nearby trajectories toward them).
- **Ghost Peg** — one random peg per ball phases out for 2s when first hit,
  opening a lane (telegraphed shimmer).
- **Extra Ball Token** — +1 ball budget per feature (price accordingly; direct
  EV item, cap still binds).
- **Sticky Flippers** — flipper rescue window +60%; a caught ball can be held
  briefly and aimed (tap again to release).
- **Plunger Tuner** — skill-shot sweet zone width ×2 on the launch meter.
- **Lock Jammer** (contraband) — first lock gate counts double toward
  multiball; small suspicion gain per use, matching the cheat/contraband
  economy.
- **Weighted Ball** (contraband) — nudges move the ball ~40% more but tilt
  meter gains 20% more; risk/reward trajectory control.

Implementation: `pinball_items.gd` registry maps `slot_pinball_*` effect keys →
{board-compile modifier | sim hook | sequencer hook}. New items = data + one
registry entry; no sim-core edits.

---

## 7. Math & economy

- Keep the existing outer envelope: feature triggers from the outcome table
  (`bonus` classification), `session_cap` (stake × mode multiplier × scale),
  `feature_scale` from bonus/math variants, award trim rate — these numbers are
  already tuned against the slot RTP; the rework changes *how* awards are
  earned, not the budget.
- All element awards defined as **basis points of stake** at board-definition
  time (replaces the current absolute-award + `_scaled_layout` rescale chain —
  one less transform to audit).
- Ladder awards (jackpot/super/wizard) are the volatility carriers; pocket-row
  values are the floor. Target distribution per board asserted by the math
  probe: median, p90, p99, cap-hit rate.
- `preview_feature_award` reimplemented as an honest headless run of the real
  sim with a scripted policy (removes `_preview_input_score`'s synthetic
  scoring, which currently invents value from input counts).

---

## 8. Presentation & juice

- Renderer keeps the current pixel-canvas API but reads `PinballView`
  (interpolated positions, lit-insert bitfield, event drain) — no dict copies.
- Juice mapping (event → effect): peg hit = 1-frame flash + tick sfx pitch-up
  on streaks; bumper = radial spark + kick sfx; lock = ball visibly parked in
  gate; multiball start = flash + music layer; jackpot = full-board flash +
  count-up; nudge = whole-board 2px shake; tilt warning = red vignette pulse;
  tilt = slam + lights out. Ball gets a short motion-trail ghost (renderer-side
  ring buffer).
- Award tally counts up live in the header; per-hit floaters at the element.
- Existing audio cue ids (`pinball_plunger_charge`, `pinball_cup_hit`,
  `pinball_jackpot_lane`, …) are kept and driven from the event drain.

---

## 9. Build phases

**Phase 0 — Ballionaire research capture.**
Before writing sim code, research Ballionaire specifically (store page, gameplay
videos, reviews, design writeups/interviews) and write
`docs/plans/pinball_feel_reference.md` capturing: drop pacing (seconds per ball,
time-to-first-payout), trigger density (visible events per second), how it
telegraphs item/trigger interactions, bounce feel (restitution/gravity
impression), camera/board proportions, payout tally presentation, and what
makes chain reactions satisfying. Extract concrete numeric feel targets and
reconcile them against §3.4 — where they disagree, update §3.4. Every feel
decision in Phases 1–6 must cite this doc.

**Phase 1 — Sim core (isolated).**
`pinball_sim.gd` + `pinball_board.gd` with Board A only; headless test tool
(`tools/pinball_sim_probe.gd`): determinism (same seed+inputs = same result),
perf (tick budget, zero-alloc), drain-rate sanity. No game integration yet.

**Phase 2 — Runtime integration.**
`pinball_feature.gd` adapter + runtime session cache; delete per-tick session
round-tripping from `slot_family_pinball.gd`; surface pumps `sim.advance()`;
machine dict reduced to the compact summary; save/load = settle-on-save.
Renderer switched to `PinballView`. Old `slot_pinball_table.gd` deleted.
Perf probe must pass with wide margin here — this is the gate.

**Phase 3 — Sequencer + Boards B/C.**
`pinball_sequencer.gd`, lock/multiball/jackpot ladders, all three boards,
insert lights, combo timers. Math probe distributions asserted.

**Phase 4 — Skill layer.**
Real timed launch meter, nudge/tilt rework, flipper rescue zones.
Perfect-vs-random policy probe pins the skill edge.

**Phase 5 — Items.**
`pinball_items.gd` registry; port the 6 existing items; add 3–4 new items
(suggest: Rubber Pegs, Extra Ball Token, Plunger Tuner, Lock Jammer);
art + items.json entries.

**Phase 6 — Juice + polish.**
Event-driven VFX/SFX, trails, tally, tilt drama; update
`foundation_check.gd` expectations, `slot_pinball_physics_audit.gd`,
`slot_cabinet_visual_qa.gd`; refresh branding screenshots.

Each phase leaves the game shippable (Phase 2 onward the feature is playable
end-to-end on Board A).

---

## 10. What is kept vs deleted

Kept: outcome table / grid / payout / nudge-tease logic in
`slot_family_pinball.gd`; feature trigger plumbing; three mode ids; bet/cap/
scale math; audio cue ids; items.json entries (hooks re-pointed); pixel canvas
renderer surface API.

Deleted: `slot_pinball_table.gd` (dict sim, spatial-bin dicts, trajectory
recorder); per-tick `pinball_session` round-tripping and `history` trajectory
snapshots in `slot_family_pinball.gd`; `slot_bonus_tick` catch-up budget
machinery; `_preview_input_score` synthetic preview; guided-assist remnants.

## 11. Risks / open questions

- **Mid-ball save/load:** settle-on-save is simplest but a player quitting
  mid-multiball loses the spectacle (not the money). Input-replay resume is
  the better v2. Decision needed in Phase 2.
- **Flipper fidelity:** timed impulse zones vs real rotating flipper bodies.
  Plan says impulse zones (cheap, deterministic, fits plinko frame); revisit
  only if feel tests demand true flippers.
- **GDScript ceiling:** if the packed-array sim still misses budget at 8 balls
  (unlikely — the current sim's cost is copies, not math), fallback is a
  C# module or server-physics offload; keep the sim API narrow so the core is
  swappable.
- **RTP retune:** boards with a real skill edge shift average feature return;
  the trim-rate / outcome-table weights may need a compensating pass in
  Phase 4 (probe-driven).
