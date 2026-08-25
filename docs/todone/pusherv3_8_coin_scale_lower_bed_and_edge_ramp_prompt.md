Status: DONE — 2026-08-25
Board row: `pusherv3_8` in `docs/todo/README_0_6_board.md`

# Agent Prompt — pusherv3_8: Coin Scale, Lower Bed, and Edge Ramp

Follow-up to archived
`docs/todone/pusherv3_7_played_in_opening_stock_prompt.md`.

## Owner report

- Coins in current captures are substantially larger than the earlier cabinet
  presentation and make the bed read like oversized tokens.
- The stationary lower playfield only holds roughly two coin depths before the
  payout cliff. It must become longer than the moving upper shelf by extending
  the lower bed, not by shortening the upper shelf.
- The payout cliff has no real-machine edge resistance. Coins should build
  tension at a slight uphill edge plate before tipping into the win chute.

## Real-machine basis

- `JPH05237264A` describes the payout edge as an upward-inclined edge plate and
  states that its inclination determines how strongly coins are prevented from
  falling and therefore controls payout.
- `GB2444324A` describes coins riding up an upward formation, building into
  angled layers, and then passing a step-down portion. It also identifies this
  buildup as intentional machine presentation.
- The Cromptons Monopoly 8 Player Pusher service manual instructs operators to
  spread and settle the prime so coins build up at the win-chute edge.
- `GB2226766A` documents the conventional two-tier layout: a reciprocating
  upper surface deposits onto a stationary lower play area, where coins
  accumulate before eventually crossing the leading payout edge.

## Binding requirements

- Restore the earlier 17 px apparent coin radius by reducing the authored
  physical coin dimensions so collision spacing, piles, and rendering agree.
  Restore the matching pre-expansion 40x32 texture frame and 17x12 flat ellipse;
  the temporary 68 px atlas must not compress the smaller coin into a circle.
- Increase the number and distribution of opening coins to make sensible use
  of the added physical capacity without returning to overlapping perfect
  sheets or an opening payout surge.
- Extend the stationary lower shelf until it is longer than the upper shelf at
  full extension. Preserve the upper shelf's prior physical depth and stroke;
  move the upper assembly and drop field rearward instead of stealing space
  from it.
- Add an authored upward payout-edge plate with a finite run and rise. Solver
  support height and gravity must follow the incline, producing downhill
  resistance and a genuine pressure buildup before the existing visible fall.
  Render the ramp and raised cliff explicitly.
- Keep reference/native stepping exact, deterministic persistence and
  conservation, contact-only pressure, visible exits, bounded early payouts,
  EV bands, accessibility, and performance ceilings.

## Required evidence

- Contracts for restored coin projection/contact size, lower-bed versus upper-
  shelf lengths, unchanged upper depth/stroke, ramp profile and downhill
  resistance, edge accumulation before release, visible ramp-height fall, and
  collision-valid higher-capacity opening stock.
- Exact native/Web parity, determinism, all-machine normal/reduced-motion
  actual-GL captures, visual QA, performance, EV, and supported full regression.

## Execution record

- **Coin scale and flat presentation:** Authored coins now use radius `2350`
  and height `950`, which project to the earlier approximately 17 px contact
  radius. The renderer restores the exact pre-expansion `40x32` texture frame
  and `17x12` flat ellipse. The temporary `68x32` frame was the cause of the
  severe upright-circle regression because it horizontally compressed the
  smaller ellipse when mapped to the coin quad. A renderer signature contract
  now locks the frame size and flat projected proportions.
- **Larger physical bed:** The stationary lower bed is `39000` units deep,
  longer than the preserved `35000`-unit upper shelf. The upper shelf and its
  `18000`-unit stroke were not shortened; the upper assembly, delivery board,
  and entry field moved rearward to create the added lower-shelf capacity.
- **Real edge behavior:** The payout edge is a visible `6500`-unit run with a
  `2500`-unit rise. Reference and native solvers use its authored support
  height and resolve gravity downhill along the incline, so static friction can
  hold an edge prime until real contact pressure drives coins uphill and over.
  This follows the inclined payout plates described by JPH05237264A and
  GB2444324A, the conventional two-tier bed in GB2226766A, and the Cromptons
  operator procedure for spreading and settling an edge prime.
- **Played-in opening:** Quarter Falls and Jackpot Ridge seed `150` coins;
  Vault Drop seeds `154`. Fifteen staggered rows, deterministic lateral scuff,
  collision-valid gaps, and localized supported upper coins use the smaller
  coin capacity without recreating perfect sheets. Across four seeds per
  machine, passive and first-five payouts were all zero, the ramp retained at
  least `18/19/18` edge coins, and at least `14/14/18` elevated coins remained.
- **Physics and parity:** The peg-crown escape force prevents exact-on-peg
  pinning and is included as explicit work in both energy ledgers. Focused
  physics validation and all 24 foundation checks pass with zero failures; the
  300-body native solver measures `3.275 ms` p95 against its `12 ms` ceiling.
  Exact Windows native/Web reference parity passes with payload
  `f34de8c63458e5a488abba91f6f21d92d242d12861426868ca9ff14f4e51d488`.
  Two-process determinism passes 10 seeds and 510 identical checkpoints with
  combined hash `2349118360`.
- **Visual and economy proof:** The final actual-GL manifest passes all three
  machines and all nine required scenes per machine in normal and reduced
  motion at `.tmp/pusherv3_8_flat_coin_visual/manifest.json`. The complete
  24-shard EV audit accepted 200,000 plays per machine and passes all invariant,
  coverage, backend, and economy gates at
  `.tmp/pusherv3_8_ev_flat_final/manifest.json`: Quarter Falls physical ROI is
  `0.886985`, Jackpot Ridge physical/credited ROI is `0.926895/0.927515`, and
  Vault Drop physical ROI is `0.840435`.
- **Regression scope:** Direct project validation, exhaustive script loading,
  the focused coin-pusher suite, refreshed 24-check foundation suite, and
  direct UI-scene compilation pass. The earlier Full preset run exposed stale
  generated environment hashes, which were refreshed and then passed in the
  direct foundation/UI reruns. Its remaining tutorial guardrail/guided-run
  failures reproduce on unchanged `main` and are unrelated to coin-pusher
  code; no tutorial/Blackjack behavior or assertion was weakened in this task.
