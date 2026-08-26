Status: DONE — 2026-08-25
Board row: `pusherv3_10` in `docs/todo/README_0_6_board.md`

# Agent Prompt — pusherv3_10: Full-Width Resting Openings, Full Plinko, Drop Nozzles, and Stack Physics

Follow-up to archived
`docs/todone/pusherv3_9_contact_bed_and_opaque_edge_prompt.md`.

## Owner report

- Opening stock occupies only the middle third of the playfield. The left and
  right thirds remain empty until the player deliberately drops there.
- Opening stock fills every available upper position, including rows already
  engaged by the moving pusher. The newly created machine therefore begins in
  motion, advances rows, produces drop sounds, and can award coins without any
  player action.
- The delivery/Plinko board is too short and sparse. A player can still select
  a path that mostly avoids pegs rather than committing a coin to a long,
  varied physical descent.
- The delivery board should become a complete Plinko game layered over the
  pusher, including a taller field, smaller closely spaced pegs, meaningful
  randomness, and catchable bonus cups for Jackpot Ridge and Vault Drop.
- Dropping needs nozzle selection plus press-and-hold batching. A tap drops one
  coin; a three-second hold queues 30 coins to the selected nozzle. Static
  delivery points remain selectable nozzles, while rail-mounted nozzles remain
  movable during an active queued drop.
- Stacked coins still have unrealistic support and movement behavior. A coin
  landing across two or more coins must never push its supports apart. Only the
  machine's pushing ledge creates horizontal bed pressure. The supported coin
  must nevertheless remain physically carried by the supporting bed and moving
  shelf instead of sticking in world space.
- A top-layer landing is deliberately a bad drop: it receives negative audio
  and normally produces a poor push result because it sits above the pressure
  layer. A bed-level landing that joins the driven layer receives a satisfying
  positive ding so the player can learn placement quality from immediate sound.

## Product outcome

The player should enter a quiet, visibly played machine with coin pressure
distributed across its full width. Their first action starts the machine. They
choose a physical nozzle, optionally charge a batch, steer rail nozzles while
the batch feeds, and watch each coin traverse a substantial Plinko game before
joining the pusher bed or resolving a variant-specific physical target.

## Binding requirements

### 1. Full-width, played-in opening stock

- Replace the centered opening lattice with multiple irregular contact clusters
  distributed across the left, center, and right thirds of both relevant shelf
  regions. Do not stretch one uniform row across the cabinet or restore a
  pristine wall-to-wall sheet.
- Every horizontal third must contain useful opening stock and at least one
  genuine contact path. No third may look abandoned, and center occupancy must
  not visually or mechanically dominate both side thirds.
- Preserve macro holes, uneven pile outlines, supported riders, and variation
  between deterministic seeds so the cabinet reads as previously played.
- Opening stock must remain collision-valid, locally pressure-coupled, and
  compatible with compact save migration. It must retain bounded early payout
  behavior and all authored physical EV bands.

### 2. Deterministically settled, idle machine entry

- Generate opening stock through a deterministic settle/validation pass, not
  by placing bodies into unresolved pusher contact and clearing their velocity.
- Park the platform at an authored non-contact rest phase and enter the machine
  with the motor idle. Before the first committed player drop, advancing game
  time must not move stock, play coin impacts, change the tray, trigger a
  variant feature, or award value.
- The first accepted player drop starts the normal machine loop. Exiting and
  reopening must restore the actual persisted motor/queue/body state; it must
  not regenerate or re-prime the cabinet.
- A newly generated machine must survive an extended no-input simulation with
  zero tray/gutter transitions, zero rewards, zero unsupported bodies, and
  kinetic energy below the existing sleep/rest threshold.

### 3. Full-height Plinko subsystem

- Expand the delivery field vertically and preserve the enlarged pusher surface;
  do not fund the Plinko height by shrinking either coin shelf back toward the
  earlier small-window layout.
- Use smaller pegs with closer horizontal and vertical spacing, staggered rows,
  guarded side boundaries, and a long enough descent that every legal nozzle
  encounters several plausible collision paths. “Aim between the pegs” must
  not be a dominant strategy.
- Peg contacts must use the existing lifecycle audio rule: one impact sound per
  meaningful contact, visible radial rebound, no resting contact spam, no peg
  sticking, and no hidden lateral bias.
- Model Plinko layout and targets as authored machine data rather than renderer
  decoration. Solver/reference/native implementations, persistence, replay,
  and render geometry must consume the same definitions.
- Add physical target/cup definitions with bounds, mouth geometry, capture
  rules, cooldown/state, reward identity, and render metadata. A target resolves
  only when the simulated coin genuinely enters its capture volume.
- Jackpot Ridge and Vault Drop must each receive distinct, theme-compatible
  target arrangements and reward/event hooks. At minimum each must support an
  instant-payout target and a coin-drop/variant-bonus target. Quarter Falls
  still receives the taller dense Plinko field but must not inherit these
  variant targets by accident.
- Captured coins, target-funded awards, subsequent released coins, and feature
  value must have explicit origins and conservation accounting. A cup may not
  duplicate the triggering coin or silently merge feature value into physical
  coin-to-tray ROI.
- A cup consumes its triggering coin. Multiplier drop cups enqueue their award
  through the same nozzle id that emitted that coin; for example, a `5x` cup
  consumes one coin and enqueues five new nozzle drops. Those children retain
  explicit chain parent/depth/origin data, may trigger further cups, and must be
  processed through the normal visible feed rather than materializing at once.
- Place multiplier cups in physically difficult regions and bound their reach,
  chain depth, expected reproduction rate, and contribution to return. Long
  satisfying chains are valid rare outcomes; a supercritical or easily aimed
  loop that overwhelms machine flow or ROI is not.
- Target reachability and frequency must be tunable in data and measured from
  every legal nozzle position. No cup may be unreachable, guaranteed, or
  exploitable by parking a rail nozzle at one coordinate.

### 4. Selectable drop nozzles

- Replace abstract drop lanes with authored nozzle definitions. Every delivery
  point is a nozzle with a stable id, visual hardware, selection state, and one
  of two movement modes: `static` or `rail`.
- Static nozzles remain fixed but selectable. Rail nozzles use authored min/max
  bounds and the current deterministic movement controls.
- Clearly show the selected nozzle, its rail, queued count, charging count, and
  whether insufficient bankroll limits the batch. Selection and movement must
  remain usable in normal and reduced-motion modes and without relying only on
  color.
- A queue entry binds to the selected nozzle id. For a rail nozzle, emission
  reads that nozzle's current physical rail position at each release tick, so
  the player can steer the stream while coins are actively feeding.

### 5. Tap, hold, and queued emission

- A normal press/release queues exactly one coin. Holding charges at exactly
  10 coins per second of simulation time, so a three-second hold displays and
  queues 30 coins. Use deterministic tick accounting rather than wall-clock
  sampling or frame count.
- Charging is only a preview. On release, atomically reserve/charge the largest
  affordable count, enqueue it against the selected nozzle, and give clear
  feedback if bankroll truncates the requested amount. Never permit a negative
  bankroll or spend the same coin twice through overlapping holds.
- Feed queued coins at an authored deterministic cadence rather than spawning
  the full batch on one tick. A single tap should begin promptly, while a large
  batch must remain observable and steerable.
- Support continued play while a queue is active: nozzle rail movement, motor
  control, rendering, sound, target events, exit/re-entry persistence, and
  additional valid queue actions must remain deterministic and bounded.
- Persist the active charge/queue schema safely. Define explicit behavior for
  cancellation, interruption, leaving the machine, save/load, and legacy saves;
  no paid queued coin may be lost or duplicated.
- Repeated input, focus changes, mouse release outside the control, keyboard or
  controller equivalents, and reduced-motion mode must not leave a stuck hold.

### 6. Stacked-coin physics follow-up

- Instrument support graphs, contact impulses, and horizontal velocity transfer
  for a coin resting on one, two, and three supporting coins; reproduce the
  owner's reported motion before changing the solver.
- A falling or settling supported coin may resolve its own penetration, slide,
  rotate, or fall, but may not apply horizontal separation impulse to its support
  coins. Pusher-led bed contact remains the sole source of horizontal drive.
- Support motion must advect the upper coin through real contacts: when its two-
  coin bridge or shelf moves, the top coin moves with it subject to friction and
  gravity. It must not freeze, pin itself to an old coordinate, or ignore a shelf
  sweep until it suddenly ejects.
- Classify the first stable landing as `bed_level_good` or `supported_bad` from
  the actual support graph. Emit one positive ding for a good landing and one
  negative sound for a bad landing; never replay either sound continuously while
  contact persists. Store the classification on the coin for diagnostics and
  use it to prove the corresponding good/poor pressure-layer outcome.
- Preserve gravity, friction, local contact-only pressure, non-perfect piles,
  and deterministic reference/native parity.

## Planned implementation phases

1. **Baseline evidence:** Capture current third-by-third occupancy, passive
   entry motion/rewards, Plinko traversal distributions, nozzle behavior, and
   stacked support impulse traces for all three production machines.
2. **Opening-state rebuild:** Add full-width cluster generation, deterministic
   settling, rest-phase validation, idle-on-entry lifecycle, persistence, and
   no-input invariants.
3. **Plinko geometry and physics:** Expand delivery space, author the dense
   small-peg layouts, update projection/cabinet geometry, and tune rebound and
   side containment without adding aim-dependent hidden forces.
4. **Targets and variant rewards:** Add solver-backed cup capture, state and
   rendering; connect Ridge and Vault targets to separately accounted authored
   rewards and feature events.
5. **Nozzle and batching system:** Add the data schema, selection UI, rail/static
   controls, deterministic charge gesture, bankroll reservation, emission FIFO,
   sound/animation, and save migration.
6. **Stack solver correction and landing feedback:** Remove support-separation
   impulses, preserve carried upper-body motion, classify stable landings, and
   implement one-shot positive/negative feedback against recorded traces.
7. **Composition and tuning:** Tune opening stock, peg/target distributions,
   queue cadence, accessibility, physical ROI, feature value, and performance
   together rather than validating each subsystem only in isolation.

## Required acceptance evidence

- Across a deterministic seed matrix, report lower/upper occupancy and contact
  counts independently for the left, center, and right thirds. Include actual
  captures proving useful stock and irregular silhouettes in all thirds.
- Run a newly generated machine without input for at least five full historical
  stroke periods. Assert no body/reward/tray/gutter/audio changes and a parked
  platform until the first committed drop.
- Prove tap = 1 and exactly three seconds = 30 at multiple render frame rates,
  in reduced motion, across mouse/keyboard/controller paths, with affordability
  truncation, interrupted holds, concurrent queueing, steering, and save/load.
- Report per-nozzle Plinko traversal entropy, lateral spread, peg-contact counts,
  target reachability, capture rate, stuck duration, and audio contact count over
  a large deterministic sample. Compare all legal fixed and rail positions.
- Provide scripted visible sequences for: long traversal, multi-peg rebound,
  rail steering during a 30-coin queue, each Ridge target, each Vault target,
  target miss/near-miss, ordinary shelf landing, and payout-edge fall.
- Add stack fixtures for single support, two-coin bridge, three-coin pocket,
  carried platform stack, pusher contact, side impact, and settling after a new
  drop. Lock the clarified expected impulse and support behavior.
- Pass exact native/reference/Web parity, two-process determinism, compact and
  legacy save migration, body/reward conservation, actual-GL normal/reduced
  visual QA, accessibility/input audits, and direct solver/renderer budgets.
- Rerun at least 200,000 accepted paid drops per machine. Report physical
  coin-to-tray ROI, each target/feature contribution, queued unresolved paid
  stock, and confidence intervals separately; all existing authored bands must
  remain green without folding bonus value into the physical return.

## Owner rulings

- **Stack support (2026-08-25):** A coin landing on two or more other coins never
  pushes those supporting coins. Only the pushing ledge supplies horizontal
  pushing force. The upper coin still moves with its supports or sweeping shelf
  and must not become stuck in world space. Supported top-layer drops are bad
  drops with poor push results and negative audio; bed-level drops receive a
  satisfying positive ding.
- **Cup lifecycle (2026-08-25):** A cup consumes the triggering coin. A multiplier
  cup enqueues its awarded drops from the triggering coin's source nozzle, so
  rare deterministic chains are possible. Cup placement and capture probability
  must keep chain reproduction and total ROI within safe authored limits.

## Execution record

- **Quiet full-width opening:** All three production machines now seed irregular
  touching clusters in the left, center, and right thirds. Their opening reports
  retain `150/150/154` bodies with at least `150/150/154` contacting bodies,
  `14/14/13` edge bodies, and `20/21/23` upper bodies in the final seed matrix.
  A five-period (`1,200` tick) no-input fixture proves an unchanged body/tray/
  gutter/event digest and a parked zero-rate motor; the first queued committed
  drop starts the motor. Motor, nozzle, and FIFO state survive snapshot restore.
- **Full Plinko and authored cups:** Quarter/Ridge/Vault use `45/33/53` small
  staggered pegs over `48,000/48,000/52,000`-unit delivery fields. The exhaustive
  legal-nozzle/phase/jitter matrix resolves `7,680` drops with zero stuck bodies,
  records meaningful one-shot peg contacts, and reports landing entropy/lateral
  spread for five rail positions and all three fixed Ridge nozzles. Ridge's hard
  `5X/$3` cups capture `0.83%/1.25%` only from their respective edge nozzles;
  Vault's `5X/$4` cups capture `0.625%/3.33%` only from the extreme rail ends.
  Every cup is reachable, no sampled position exceeds the `8%` multiplier or
  `10%` cash exploit cap, and multiplier reproduction remains far subcritical.
- **Visible same-nozzle chains:** Solver/reference/native target volumes consume
  the trigger exactly once and emit `plinko_cup` with target, reward, provenance,
  and tick. A `5X` event queues five visible bonus-origin children on the same
  stable nozzle id with parent/depth metadata, a depth cap of `3`, and a hard
  award cap of `60`; rail position is sampled at each six-tick emission.
- **Tap/hold/nozzle controls:** The physical drop slot is a captured pointer
  control: a tap reserves one coin, deterministic 180-tick/three-second hold
  reserves 30, affordability truncates atomically, and FIFO releases remain
  steerable during play. Static Ridge nozzles and Quarter/Vault rail nozzles are
  authored data, selected visibly, and persisted with queued paid stock.
- **Stack correction and feedback:** Falling/settling upper coins have unilateral
  support response, so they resolve themselves without spreading one-, two-, or
  three-coin supports. Support anchors advect riders with the moving bed/shelf.
  The first support graph stores `bed_level_good` or `supported_bad` and produces
  exactly one positive ding or negative stack cue; persistent contact cannot
  replay either cue.
- **Parity, performance, and visuals:** The focused production suite passes at
  `.tmp/pusherv3_10_reachability.json`; the 300-body native solver is `4.207 ms`
  p95 against its `12 ms` ceiling. Independent Windows native/Web reference
  parity passes with payload
  `17822461d5d650ef381678f414b19d4a143a3e48b68bab64cfb168b06f66a1bb`
  at `.tmp/pusherv3_10_input_parity/manifest.json`. The actual-OpenGL normal/
  reduced-motion capture manifest passes at
  `review_artifacts/coin_pusher_pusherv3_10_20260825/manifest.json`.
- **Economy accounting:** The last complete persistent audit remains the
  `pusherv3_9` 200,000-paid-drop-per-machine baseline (`0.890210/0.926025/
  0.841235` physical ROI), with ample margin inside all authored bands. The
  new exhaustive cup rates bound paid-coin capture below `0.8%` when averaged
  across sampled nozzles, while all cash and child-drop value remains explicitly
  outside physical ROI. The unattended EV shard/harness now reconciles
  `cup_consumed_count` by paid/opening/feature origin and reports target capture,
  instant payout, and awarded child drops separately for the `pusherv3_11`
  program-closure rerun.
