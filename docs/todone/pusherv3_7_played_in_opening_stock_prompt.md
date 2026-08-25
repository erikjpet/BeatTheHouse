Status: DONE — 2026-08-25
Board row: `pusherv3_7` in `docs/todo/README_0_6_board.md`

# Agent Prompt — pusherv3_7: Played-In Opening Stock

Follow-up to archived
`docs/todone/pusherv3_6_plinko_bounce_and_entry_boards_prompt.md`.

## Owner report

The production machine still opens with stock authored for the older physics
model. Its excessive, perfectly layered population destabilizes when the new
solver begins moving, can dump a large unearned surge into the tray during the
first few plays, and then collapses into a flat field with no believable piles.
The untouched regular arrangement also fails to suggest a public machine that
other patrons have already played.

## Binding requirements

- Replace the legacy perfectly repeated opening layers with a deterministic,
  collision-valid played-in arrangement: uneven staggered surface rows,
  localized bracket-supported upper coins, useful gaps, and multiple pile
  heights without initial overlaps or unsupported bodies.
- Tune opening stock per machine against the current solver and physical
  feature population. The cabinet must look active and previously played, but
  must retain working room for paid drops and stay well below its body ceiling.
- Passive entry/motor motion must not cause an opening-stock avalanche. Across
  deterministic seeds and all three machines, the first few paid plays must
  have bounded per-play and cumulative tray payouts rather than releasing a
  large legacy-stock windfall.
- Early play must preserve a visibly irregular field with gaps and supported
  upper coins; it may evolve naturally, but it must not instantly resolve into
  an empty or uniformly flat tray/deck.
- Preserve deterministic generation, compact persistence/migration,
  conservation, exact native/reference stepping parity, EV bands,
  accessibility, presentation, and performance ceilings.

## Required evidence

- Focused contracts for machine-specific opening counts, collision-valid and
  nonuniform initial topology, passive-entry stability, bounded first-five-play
  payouts, retained early piles, and same-seed generation identity.
- Exact Windows native/Web reference parity, two-process determinism,
  300/600-body performance, at least 200,000 accepted drops per machine EV,
  visual QA, all-machine opening/early-play captures in normal and reduced
  motion, and the supported full regression suite.

## Execution record

- **Implementation:** Production cabinets now seed deterministic, irregular
  five-row beds with sparse front edges and localized bracket-supported upper
  coins. Opening stock is tuned per machine to 54 Quarter Falls coins, 54
  Jackpot Ridge coins, and 56 Vault Drop coins; the former 150-coin repeated
  layers remain available only to explicit high-body benchmark fixtures.
  Opening riders, ridge pucks, and vault fragments select distinct valid pile
  supports instead of intersecting or floating beside opening coins.
- **Opening behavior:** The final actual-production capture passed all three
  machines at
  `.tmp/coin_pusher_pusherv3_7_feel_gl_2/manifest.json`. Quarter Falls began
  with 56 total bodies and paid `0/4/0/3/0`; Jackpot Ridge began with 58 and
  paid `0/6/0/1/0`; Vault Drop began with 62 and paid `0/1/0/0/0`. All had
  zero passive entry payout and retained 14/11/18 elevated opening coins after
  five plays. Normal and reduced-motion images show uneven mounds, working
  gaps, sparse shelf edges, and supported machine-specific feature pieces.
- **Physics/contracts:** Focused validation, load, and 54/54/56 opening-state
  contracts passed with zero failures at
  `.tmp/test_reports/pusherv3_7_focus_final/summary.json`. The contract covers
  same-seed identity, zero invalid initial penetrations, passive motor
  stability, per-play payout at most six, first-five cumulative payout at most
  ten, and retained supported upper coins over four seeds per machine. The
  isolated all-foundation rerun also passed with zero failures in 193.839
  seconds at `.tmp/test_reports/pusherv3_7_foundation_rerun_2.json`.
- **Reference/native proof:** Exact Windows native-v3/Web GDScript-v3 parity
  passed at `.tmp/coin_pusher_pusherv3_7_input_parity/manifest.json` with
  payload `a56c1148bc5a6ae0087c9d6e805b824353b781faf06e48e228138e38fd1af916`.
  Ten-seed two-process determinism passed 510 byte-identical checkpoints with
  combined hash `2219188595`.
- **Economy and presentation:** Exact 24-shard EV accepted 200,000 drops per
  machine at `.tmp/coin_pusher_pusherv3_7_ev/manifest.json`: Quarter Falls
  physical/credited ROI `0.828645`, Jackpot Ridge physical ROI `0.996475` and
  credited ROI `0.998060`, and Vault Drop physical/credited ROI `0.788005`.
  Foundation visual QA and all 27 actual-GL plan 9.4 scenes passed. The
  300-body cabinet capture passed all nine scenes with zero full snapshots and
  renderer p95 `2.479 ms` at
  `.tmp/coin_pusher_pusherv3_7_cabinet_gl/manifest.json`.
- **Full regression:** The supported Full/all suite passed with zero failures
  after exhaustive parsing of 242 scripts at
  `.tmp/test_reports/pusherv3_7_full_final/summary.json`. The crew-ignored
  serialized golden was intentionally refreshed because the smaller opening
  stock reduces saved environment bytes; its regenerated checkpoints are
  deterministic and pass the exact byte/hash contract.
- **Measurement deviation:** Direct production ceilings remain comfortably
  green (solver p95 about `3.481 ms` versus `12 ms`, renderer p95 `2.479 ms`
  versus `5 ms`). The shared broad probe again sampled the host's 60-frame
  scheduling phase just over its `16 ms` wall-clock target for skill release
  and collect. No solver behavior, gameplay rule, assertion, or performance
  budget was weakened to hide that scheduler-only deviation.
