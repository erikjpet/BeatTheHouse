# Coin Pusher V3 — The Real Machine (binding design contract)

Status: **OWNER-APPROVED design, execution pending** (2026-08-17).
**Amendment 6.1 (2026-08-17): geometry orientation ruling.** The
pusherv3_1 agent correctly caught that the original geometry labeled
FACE_MIN_Y/FACE_MAX_Y backwards for this coordinate system (+y runs
REARWARD: tray at low y, back plate at high y). Ruling: the axis and
all coordinate conventions are KEPT; the face constants are renamed
and re-derived below (the relabeling also exposed a plate/stroke flaw
that would have emptied the platform top every cycle, violating the
persistent-top-stock requirement). Sections 3.1-3.4 below are the
corrected, binding versions. The agent's stop-and-ask was exactly the
required behavior.
Supersedes the simulation sections of
`docs/plans/0.6_coin_pusher_simulation_plan.md` and the follow-on
tasks `pusher06_0/1/2/3/4`. Owner decisions in this document are
round-6 locks from a direct design session; nothing here is open to
reinterpretation. A worker agent reading this document has the
mechanics ALREADY DESIGNED — implement them as specified, log genuine
contradictions with code reality on the board, and do not substitute
a different machine model.

---

## 1. Why V2 is rejected (verified against code, with references)

The V2 solver (`scripts/games/coin_pusher/coin_pusher_solver.gd`) is
a real fixed-point discrete-body core — and the MACHINE built on it
is not a coin pusher:

1. **Turn-based batch.** One press simulates `ACTION_TICKS = 48`
   ticks (0.8 s) then freezes. The visible shelf motion is wall-clock
   cosmetic (`surface_realtime_state_patch`), disconnected from the
   physics that acts. A coin pusher never stops.
2. **Two phantom blades, no pusher.** `_pusher_face_y()` returns a
   line; `_hot_apply_pushers()` clamps/impulses bodies caught in a
   thin band on the forward stroke only. There is no platform top, no
   riding coins, no deposit on retract. The defining transport
   mechanism of the machine does not exist.
3. **Timing is a scalar.** Drop phase becomes `phase_accuracy`, a
   push-strength modifier. In a real machine timing decides WHERE the
   coin physically lands relative to the platform and the mass.
4. **Lane grid.** Bodies never had lanes (continuous x/y/z), but the
   input and UI impose a 5-lane grid. Rejected.
5. **Contact solver defects** (cause of the owner-observed "pile goes
   crazy then crystallizes into even rows"):
   - separation along cardinal axes with Chebyshev overlap
     (`_hot_resolve_collisions`) — an attractor into an axis-aligned
     lattice;
   - `overlap * 5` velocity injection, no restitution, one pass
     (`MAX_COLLISION_PASSES = 1`) — energy chain reactions;
   - single-nearest support + `lean > 620 -> topple`
     (`_hot_resolve_supports`) — coins may not nestle into gaps, so
     natural packing is actively destroyed;
   - `_pressurize_full_pile` — teleports a payout when the pile is
     full. Physics fraud; delete.
6. **Replay-trace presentation.** The packed 14-frame trace subsystem
   exists only to replay the frozen 0.8 s burst. A live machine
   renders live state; the whole subsystem is deleted.
7. **Console UI.** Buttons beside an abstract box. The owner requires
   a full alive cabinet at slot-renderer parity.

## 2. What survives from V2 (do not rebuild)

- Fixed-point integer state (`FP = 1000`), 60 Hz fixed tick, no
  floats in outcome-affecting state; cross-platform export-parity
  harness (rebuilt to input-trace replay, section 9).
- Gravity/drag constants as starting values; sleeping concept.
- Nudge/alarm/tell-ladder DATA and consequences (re-timed, 5.3):
  hidden tolerance 6-9 + security band deltas, four-rung tell ladder,
  hard alarm = heat 22 + staff-watch floor 12 + machine locked for
  the night, **no forced exit** (owner decision 23).
- Variation sub-game logic (Ridge pucks/multipliers/locks/jams, Vault
  fragments/progressive/cells) as consumers of physical events.
- Cheat items: `cold_quarters` (heavier coin mass), `coin_return_shim`
  (gutter recovery), `weighted_keyring` (stronger nudge), the Mags
  dampener hook, `xray_glasses` (vault peek).
- Pile-state-in-node-snapshot persistence concept (new schema,
  section 8), pusher-pile rumor facts, scenario tolerance modifiers,
  EV-emergent principle (measured, tuned via machine geometry, never
  imposed).

## 3. The machine — mechanics specification

### 3.1 Anatomy (one assembly, two levels)

A real basic pusher has ONE reciprocating flat-topped platform. Its
TOP SURFACE is the upper coin level; the FIXED DECK in front of it is
the lower level. Owner's words, binding: "the top level coins should
always be moving on the pusher, not 2 rows of sweeping arms."

Fixed-point geometry (existing scale kept; all constants live in the
machine definition data, section 7 — these are the default machine's
values):

Axis convention (binding): **+y runs REARWARD** — the tray is at low
y (the player side), the back plate at high y. "Extended" = the face
at its LOWEST y (pushed forward toward the tray); "retracted" = the
face at its HIGHEST y (pulled back toward the plate).

```
WIDTH            = 100000        # x: 0 .. WIDTH
COIN_RADIUS      = 4300          # ~11.6 coin diameters across
COIN_HEIGHT      = 1700
TRAY_LIP_Y       = 6000          # deck front edge; y below this = tray fall
DECK_Z           = 0             # fixed deck floor
PLATFORM_TOP_Z   = 3600          # platform top surface (~2 coins high)
FACE_EXTENDED_Y  = 28000         # face at maximum FORWARD travel (toward tray)
FACE_RETRACTED_Y = 46000         # face at maximum REARWARD travel
                                 # stroke = 18000 (~2.1 coin diameters)
BACK_PLATE_Y     = 63000         # fixed plate, spans full width
                                 # plate - retracted face = 17000 (~2 rows
                                 # of top stock persist at full retraction)
BACK_PLATE_GAP   = 400           # plate bottom = PLATFORM_TOP_Z + 400
                                 # platform slides under; coins cannot
DROP_Y           = 40000         # release depth, inside the face sweep
DROP_Z           = 14000         # release height (free fall from here)
GUTTER_X         = 3000          # side gutters: x < 3000 or > 97000
STROKE_PERIOD    = 240 ticks     # 4.0 s full cycle at 60 Hz
```

The platform FACE collider spans z = 0 up past the platform top: a
full-height wall. Nothing slips beneath the pusher — deck coins in
its path are pushed, always.

The platform is a kinematic block: front face at `face_y(phase)`,
body extending rearward past the back plate, top at PLATFORM_TOP_Z,
full width. The deck is fixed floor from TRAY_LIP_Y to under the
platform. Side walls at x = 0 / WIDTH above the gutter mouths.

### 3.2 Pusher kinematics + skill stop

- `face_y(phase) = FACE_EXTENDED_Y + (FACE_RETRACTED_Y -
  FACE_EXTENDED_Y) * (1000 - costab[phase]) / 2000` where `costab` is
  a precomputed 240-entry integer cosine table (values -1000..1000).
  Phase 0 = fully extended; the half-cycle apex = fully retracted.
  The table is a compile-time constant, so it is deterministic on
  every platform. The forward (pushing) stroke is face_y DECREASING.
- The motor advances `phase = (phase + rate) % STROKE_PERIOD` every
  tick; nominal `rate = 1`.
- **Skill stop (owner-locked: free, costless, part of the machine):**
  a toggle. On engage, `rate` ramps 1 -> 0 linearly over 24 ticks
  (smooth deceleration, no snap); the platform holds. On release,
  ramps 0 -> 1 over 24 ticks and the cycle continues from the held
  phase. No heat, no tell interaction, no cost, always available.
  Coins fed while stopped accumulate against the stationary face;
  release delivers one large physical push. This is the intended
  strategy, not an exploit.

### 3.3 The ratchet transport cycle (the engine of the machine)

This is what makes it a coin pusher. All of it is emergent from the
contact rules in section 4 — no scripted coin movement:

1. A coin landing ON the platform top RIDES it (the platform is its
   support; carry rule 4.7) — carried rearward on retract, forward on
   the push stroke.
2. On the retract stroke, riding coins are blocked by the fixed BACK
   PLATE (they cannot pass rearward under it: gap 400 < coin height
   1700). The platform keeps sliding back beneath them — blocked
   coins advance forward RELATIVE to the platform.
3. The walk off the platform is COLLECTIVE: each new coin joining the
   queue at the plate pushes the top stock forward through coin-coin
   contact. When the retracting face passes beneath a front coin of
   the queue (face_y exceeds the coin's y), that coin loses support
   and deposits onto the deck IN FRONT of the face. With this
   geometry ~1 queued row triggers a deposit while ~2 rows always
   remain riding — the owner-required persistent, visibly moving top
   stock. All of this must EMERGE from carry + plate + contacts; no
   scripted walk.
4. On the forward stroke, the platform FACE shoves the mass of coins
   sitting on the deck toward the tray lip. Friction (4.4) makes the
   mass move as a body — rows push rows.
5. Coins pushed past TRAY_LIP_Y fall to the TRAY (3.6). Coins
   escaping past the side gutter mouths are LOST (house).

### 3.4 The landing skill (owner-locked core mechanic)

`DROP_Y = 40000` sits inside the face sweep (28000..46000):

- Face forward of the drop point (`face_y < DROP_Y - radius`, most of
  the cycle): the platform covers the landing point, so the coin
  lands on the PLATFORM TOP — it rides and joins the top stock (slow
  value).
- Face retracted behind the drop point (`face_y > DROP_Y + radius`,
  the ~20% apex dwell of the cosine cycle): exposed deck — the coin
  free-falls to DECK level and lands FLAT in the face's path, and the
  next forward stroke drives it straight into the row — the strong
  play, timed to the retraction apex.
- The pile itself may occupy the zone — the coin lands ON the pile
  (adds height, may topple, may nestle per 4.6).

Timing is therefore a pure physical consequence. There is NO
phase-accuracy scalar, NO clean-window constant, NO push-strength
bonus. Delete them.

### 3.5 Entry apparatus (per-machine, data-driven)

The apparatus is defined in machine data (section 7), never
hardcoded:

- **Quarter Falls (default):** a coin slot on a horizontal rail. The
  player slides the carriage continuously (free, no cost, no world
  time) across `x in [8000, 92000]`; DROP releases one coin in free
  fall from (carriage_x, DROP_Y, DROP_Z). Between DROP_Z and the
  landing zone sit **3 fixed pegs** (cylinders r=1200) at data-given
  positions (default: x = 30000/50000/70000, z = 9000) that the coin
  can clip and deflect off — pure collision, plus a seeded release
  jitter of +/-300 on x so identical inputs still vary
  deterministically per RNG stream.
- **Jackpot Ridge:** 3 fixed entry holes (x = 25000/50000/75000)
  feeding a **full plinko board**: 5 rows of offset pegs between
  z = 20000 and z = 8000. The player picks a hole; the board decides
  the rest.
- **Third machine:** apparatus designed later; the schema must allow
  arbitrary peg arrays, rails, hole sets, and release heights.

### 3.6 Tray & collection (owner-locked)

- A physical tray bin spans the cabinet front below TRAY_LIP_Y. A
  body crossing the lip transitions out of the sim into the tray
  ledger: `{kind, value}` appended; rendered as a visible heap sized
  by count.
- **Money is credited ONLY on collection.** A COLLECT interaction
  (free, no world time) transfers tray value to bankroll and prize
  riders to inventory, with a story-log entry. Tray contents persist
  across exit/re-entry indefinitely.

### 3.7 Idle model (owner-locked)

- While the player is AT the machine the motor strokes continuously —
  alive, always moving. A settled pile riding a stroking platform
  produces no net change (carried-sleep, 4.8): motion without
  stimulus changes nothing, which is exactly real behavior.
- Insert a coin = stimulus -> cascade -> settle.
- On EXIT: any in-flight physics is run to settlement (bounded, 5.2),
  then the machine freezes at its settled arrangement. Nothing
  simulates while absent. Visit 1 and visit 80 behave identically:
  restore settled state, resume stroking from the stored phase.

## 4. Physics specification (the contact solver rebuild)

### 4.1 Body model (kept)

`{id, kind, x, y, z, vx, vy, vz, radius, height, mass, sleeping,
sleep_ticks, rest_state, meta}` — continuous fixed-point integers.
Coins, pucks, fragments, and prize riders are all bodies; pegs,
walls, the back plate, the deck, and the platform are
static/kinematic colliders.

### 4.2 Time

Fixed 60 Hz tick, advanced by a real-time accumulator while the
surface is open (max 4 catch-up ticks per frame; the sim may lag
under load but NEVER skips ticks). All player inputs (drop, chute
move, skill stop, nudge, collect) are quantized to the tick at which
they apply. Determinism contract: settled snapshot + tick-stamped
input trace + RNG stream -> bit-identical end state (section 9).

### 4.3 Broadphase — spatial hash, O(n*k), no n^2 pool

2D hash on (x/CELL, y/CELL), CELL = 10000, open addressing; z handled
in the narrow phase. Neighbor query = 3x3 cells. Candidate pool sized
`ceiling * 32` (a fixed-radius disc has a bounded contact count — the
V2 `n^2 * 2` pool is deleted). `HARD_BODY_CEILING = 600` is a safety
ceiling ONLY: the machine geometry holds roughly 250 settled coins,
so realistic play cannot approach it. If an insert would exceed the
ceiling the SLOT REFUSES the coin (returned, uncharged, diegetic jam
message). **A simulated coin is never deleted** (owner-locked).

### 4.4 Narrowphase + contact resolution (replaces V2 wholesale)

For each coin pair with `dx*dx + dy*dy < (r1+r2)^2` and overlapping
z-bands:

```
d      = isqrt(dx*dx + dy*dy)           # integer Newton sqrt, deterministic
nx, ny = dx*FP/d, dy*FP/d               # RADIAL normal (never axis-aligned)
pen    = (r1+r2) - d                    # EUCLIDEAN overlap
# positional correction (Baumgarte-lite): resolves, never explodes
corr   = max(0, pen - SLOP) * BETA / FP # SLOP=60, BETA=600 (0.6)
# move each body corr/2 along +/-n, weighted by inverse mass
# velocity impulse
vrel_n = (v2 - v1) dot n
if vrel_n < 0:
    j  = -(FP + E) * vrel_n / (invm1 + invm2)   # E=100 (restitution 0.1)
    apply +/- j*n
    # Coulomb friction on the tangent
    jt = clamp(-vrel_t / (invm1+invm2), -MU*j/FP, +MU*j/FP)  # MU=500
    apply +/- jt*t
```

Coin vs static (walls, plate, pegs, faces): same math with infinite
mass; E=0 for plate/walls, E=250 for pegs (they should bounce a
little). Coin vs deck/platform-top: vertical support handled in
4.6/4.7; horizontal friction MU_DECK=700, MU_PLATFORM=800.

### 4.5 Iteration and ordering (deterministic convergence)

`SOLVER_PASSES = 6` Gauss-Seidel passes per tick over the contact
set, pairs processed in ascending `(low_id, high_id)` order. Fixed
pass count, fixed order -> deterministic. Residual penetration after
6 passes carries and is corrected next tick by BETA (this converges;
V2's single pass with velocity injection diverged).

### 4.6 Support & stability — the nestle rule (replaces lean/topple)

A body's support set = every body/surface whose top is within
`[z - 400, z + 400]` of its base and whose horizontal center distance
is < `(r1 + r2) * 0.9`. Stability:

- **Stable** if EITHER (a) one support with horizontal offset
  < COIN_RADIUS/2, OR (b) the support set BRACKETS the body's center
  on the x axis AND the y axis (a support with dx <= +margin and one
  with dx >= -margin; same for dy; margin = 800).
- A stable body rests: z snaps to the highest support top, vz = 0.
  THIS IS NESTLING — a coin sits happily in the pocket between two or
  three coins. The V2 single-support `lean > 620 -> topple` rule is
  deleted; it is the direct cause of the crystallization/collapse the
  owner observed.
- **Unstable** (no bracket, single support too off-center): the body
  slides — apply lateral acceleration away from the support centroid
  (magnitude GRAVITY/2) and let the contact solver find where it
  goes. No teleports, no scripted topple velocity.
- Impact events for audio/presentation are emitted from real state
  transitions (falling -> resting, with fall height and stack depth).

### 4.7 Platform carry + back plate (the ratchet, mechanically)

- A body whose support is the PLATFORM TOP receives the platform's
  per-tick delta-y as a position delta (kinematic carry), capped by
  friction: if the required delta exceeds the MU_PLATFORM-derived
  slip limit the body slips (an abrupt skill-stop release shoving a
  heavy top stock therefore behaves realistically).
- The BACK PLATE is a static wall for coins at any z above its bottom
  edge. A carried coin pressed against it during retract stops; the
  platform slides on beneath it (carry delta suppressed by the wall
  contact) — the ratchet walk of 3.3 emerges from exactly these two
  rules. No special-case "ratchet code" may be written.
- The platform FRONT FACE is a kinematic wall for deck-level bodies;
  on the forward stroke its delta transfers through contacts into the
  mass (4.4 does the rest).

### 4.8 Sleeping, islands, carried-sleep

- Sleep: |vx|+|vy|+|vz| < 90 for 8 consecutive ticks -> sleeping.
  Wake on contact from an awake body, on platform-face approach
  within one coin radius, on nudge, on an entry landing nearby.
- Islands: contact-connected components; only islands containing an
  awake body are solved.
- **Carried-sleep:** bodies riding the platform with no relative slip
  and no awake contacts are advanced by the platform delta WITHOUT
  entering the solver. A fully settled machine costs near zero per
  tick while visibly alive — this is the 3.7 idle model's perf
  foundation and the idle-liveness gate's evidence.

### 4.9 Invariants (tested, section 9)

- **No energy gain:** total kinetic energy after a tick <= total
  before + work done by platform/gravity/inputs (assert in debug).
- **Settle guarantee:** with no inputs and the motor stopped, any
  state reaches all-sleeping within 1200 ticks (20 s). With the motor
  running, it reaches carried-sleep steady state within 1200 ticks.
- **Conservation:** coins only leave the sim via tray, gutter, or a
  refused insert. Counts reconcile every tick.

## 5. Machine lifecycle & world integration

### 5.1 While present

Continuous sim per 4.2. World-time pricing (owner-locked): **coin
insert = one game action** at standard action pricing (like a slot
spin). Chute movement, skill stop, tray collection: free, no world
time. Nudge keeps its existing action/heat semantics.

### 5.2 Exit settle + snapshot

On leaving the surface: run the sim (motor on) to carried-sleep
steady state (bounded 1200 ticks, chunked across frames if needed;
inputs locked during settle-out). Then write the snapshot (section 8)
and freeze. Nothing simulates while absent (owner-locked: no stimulus
means no motion; absence stores the machine, it does not run it).

### 5.3 Alarm/nudge/tell in continuous time

Nudge = an impulse to all bodies (magnitude per force x direction,
from existing data) + tolerance cost as shipped. Tell-ladder rungs
and the hidden tolerance work unchanged; rung decay converts from
"per action" to a fixed tick interval (data: 600 ticks per decay).
Hard alarm: the machine locks for the night — motor stops, slot
refuses, cabinet goes dark; heat 22; staff-watch floor 12; **the
player is never ejected**. Skill stop has NO tell/heat interaction
(owner-locked).

### 5.4 Town integration (kept, re-verified)

Scenario tolerance deltas, swept-window loosening, pusher-pile rumor
facts (now including "the tray is loaded" as a fact class), Graveyard
Shift lax alarms, Trucker Convoy busy machine — all preserved against
the new state fields.

### 5.5 Economy

`drop_cost`, `coin_value`, prize tables per machine data. EV is
EMERGENT: measured by harness (>= 200k simulated coin drops with a
scripted input policy), tuned ONLY via machine geometry (stroke
length, lip width, gutter mouths, apparatus spread) into the
documented band. Never a payout multiplier applied to physics
results. (Ridge's multiplier applies to the TRAY-VALUE CREDITING of
coins that physically fell while armed — it scales the ledger; it
never moves coins.)

## 6. Presentation — the alive cabinet (slot-renderer parity)

New `scripts/games/coin_pusher/coin_pusher_renderer.gd`, modeled on
`scripts/games/slots/slot_renderer.gd` (floor, cabinet, topper,
glass, game). Required components:

1. **Cabinet catalog** per variation (like slot `cabinet_variant_id`):
   identity, marquee title, material palette, topper style. Quarter
   Falls: warm carnival brass/red. Jackpot Ridge: purple/gold with a
   plinko backboard. Vault Drop: steel/teal vault styling.
2. **Full cabinet drawn:** floor shadow, body, side panels,
   marquee/topper with the variation name, backglass area (Vault
   meter / Ridge multiplier lamps / prize showcase live here), glass
   with a glare overlay, coin slot + RAIL with a physically drawn
   sliding carriage, peg field / plinko board as drawn pins matching
   the sim colliders exactly, platform block with a shaded front face
   and visible top surface, back plate, deck, tray lip, TRAY BIN with
   a visible coin heap that grows, side gutter mouths, and the SKILL
   STOP as a big physical button (lit while engaged). Controls are
   cabinet hardware, not console buttons.
3. **Live rendering from sim state** every frame, interpolating
   between the last two ticks. The packed trace subsystem and
   `coin_pusher_packed_trace_reader.gd` are DELETED.
4. **Projection that shows stacking** (V2's 5.3 px/layer hid it):
   - depth scale: rear width factor 0.78
   - coin: ellipse rx 17 px, ry 12 px, rim highlight + seeded
     per-coin rotation variant (4 rotation frames), NOT one glyph
   - **z layer offset ~= 11 px per COIN_HEIGHT** (about 65% of ry — a
     stacked coin is unmistakably raised, with a small drop shadow)
   - the platform top drawn as a distinct lit surface so "riding"
     reads at a glance
   - airborne coins get a motion shadow on the surface below
5. **Audio hooks** from physics events through the existing bus:
   coin impacts scaled by fall height/stack depth, mass slide under
   the face, a motor loop whose pitch tracks stroke speed (winding
   down smoothly on skill stop), tray cascade scaled by coins fallen,
   gutter swallow, plate clink on ratchet blocks, tell chirps, alarm.
6. Idle attract = the live stroking machine itself; it must satisfy
   the liveness counter within the animated idle budget.

## 7. Machine definition schema (data, per machine)

In `data/games/games.json` under `coin_pusher_machine`:

```
{
  "machine_id": "quarter_falls",
  "geometry": { WIDTH, TRAY_LIP_Y, FACE_EXTENDED_Y, FACE_RETRACTED_Y,
                BACK_PLATE_Y, PLATFORM_TOP_Z, DROP_Y, DROP_Z,
                GUTTER_X, deck_polygon (optional non-rect shapes) },
  "stroke":   { period_ticks, ramp_ticks, profile: "cosine" },
  "apparatus":{ type: "rail_slot" | "hole_set",
                rail: { x_min, x_max, speed_per_tick },
                holes: [x, ...],
                pegs: [{x, z, r}, ...],
                release_jitter: 300 },
  "coins":    { radius, height, mass, value, drop_cost },
  "ceiling":  600,
  "cabinet":  { identity, marquee, palette, topper_style },
  "economy":  { documented_ev_band: [lo, hi] },
  "sub_game": { ... existing ridge/vault configs ... }
}
```

Playfield shape and apparatus are fully per-machine (owner-locked).
Nothing about a specific cabinet may be hardcoded in the solver or
the renderer.

## 8. Persistence (owner-locked: settled state only)

Schema `coin_pusher_settled_v3` per machine per node, written only at
exit-settle:

- platform phase, skill-stop state (always released on exit),
  carriage x
- bodies: kind + (x, y, z) quantized to 100 units (<= 2 bytes/axis
  packed), meta for pucks/fragments/riders
- tray ledger (kinds + values), sub-game state, alarm/tell persistent
  fields, night-lock flag
- ~250 coins ~= 2 KB. No velocities (settled = zero), no history, no
  per-action snapshots.

Migration: V2 machine states cannot be meaningfully converted (the
geometry changed); reseed a settled opening pile at first entry via a
deterministic settling run consistent with section 4, CARRY OVER
tray_value and sub-game state, and log the migration once.

## 9. Testing & gates

1. **Determinism by input trace:** settled snapshot + tick-stamped
   inputs + RNG stream reproduce the exact end state (canonical
   digest) across runs, processes, and Windows-vs-Web export (the
   parity runner is rebuilt from action-batch to input-trace replay).
2. **Behavior contracts** (each a targeted headless test):
   ratchet walk (a coin placed on the platform reaches the face edge
   and falls within N cycles); face push moves a 3-row mass; landing
   skill (same drop x, two phases -> deck landing vs platform
   landing); nestle (a coin dropped into a 2-coin pocket rests
   between them — THE regression test for the crystallization bug);
   no-lattice (a 300-coin settle produces no axis-aligned rows: the
   nearest-neighbor angle histogram must not spike at 0/90 degrees);
   skill-stop bank-and-release (5 banked coins push at least as far
   as the sum of individual pushes); tray fall + collect credits
   exactly; gutter loss; ceiling refusal (coin returned, never
   deleted); energy invariant; settle guarantee; conservation
   reconciliation.
3. **Perf:** frame p95 <= 16.0 ms and surface draw p95 <= 5.0 ms with
   300 coins mid-cascade on the `gl_compatibility` target; a settled
   machine idles within the animated-idle budget WITH its liveness
   counter.
4. **Feel captures** (acceptance, judged as a player): a drop lands
   beside the row and the row advances; a drop lands on the platform
   and ratchets over >= 3 cycles; a stack topples into a pocket; a
   skill-stop bank + big release; the tray heap grows and is
   collected. Bar: a person shown the capture without context calls
   it a coin pusher.
5. Standard gates: `tools/validate_project.ps1`, all foundation
   suites, the determinism probe, visual QA, the performance probe.

## 10. Execution stages

| Stage | Prompt | Scope |
| --- | --- | --- |
| 1 | `pusherv3_1_physics_machine_prompt.md` | Section 4 solver rebuild + section 3 machine mechanics, headless; behavior contracts green |
| 2 | `pusherv3_2_live_loop_prompt.md` | 3.5-3.7 + 5: continuous loop, apparatus framework, skill stop, tray/collect, exit-settle + section 8 persistence, delete the trace subsystem |
| 3 | `pusherv3_3_cabinet_prompt.md` | Section 6 full cabinet renderer + audio + projection |
| 4 | `pusherv3_4_variations_integration_prompt.md` | Ridge plinko + pucks and Vault fragments on the new machine, 5.3-5.5 integration re-wiring, EV harness, migration, feel captures, board closure |

Supersessions recorded on the board: `pusher06_0/1/2/3/4` are closed
as superseded by this contract.
