Status: DONE — 2026-08-25
Board row: `pusherv3_5` in `docs/todo/README_0_6_board.md`

## Execution Record

- **Completed:** 2026-08-25
- **Completion/implementation commits:** `1d198ca1` (physics, renderer, tests,
  and capture implementation); closure/evidence commit archives this record.
- **Verification:** focused `coin_pusher` contract PASS
  (`.tmp/test_reports/pusherv3_5_focus_4/summary.json`); exhaustive Full/all
  regression PASS (`.tmp/test_reports/pusherv3_5_full/summary.json`); Windows
  native-v3/Web GDScript-v3 exact parity PASS
  (`.tmp/coin_pusher_pusherv3_5_input_parity/manifest.json`, payload
  `543b8cb493ac62d4ea6377ce5d3cefca6868d46cf3a13984741de98f6a51a198`);
  10-seed/two-process determinism PASS (510 checkpoints, combined hash
  `757996288`); 200,000 accepted drops per machine EV PASS
  (`.tmp/coin_pusher_pusherv3_5_ev/manifest.json`): Quarter Falls `0.824610`,
  Jackpot Ridge `0.995265` physical / `0.996130` credited, Vault Drop
  `0.852880`; all-machine normal/reduced-motion pile/tray/gutter GL capture
  PASS (`.tmp/coin_pusher_pusherv3_5_visual_gl_2/manifest.json`); cabinet feel
  and 300-body draw capture PASS
  (`.tmp/coin_pusher_pusherv3_5_cabinet_gl/manifest.json`, draw p95 `2.656 ms`);
  foundation performance and visual-QA probes PASS; focused 300-body native
  solver tick p95 `3.479 ms`.
- **Deviations:** No gameplay, reward, or geometry deviation. The first visual
  invocation intentionally failed closed because Godot's dummy headless driver
  cannot provide framebuffer pixels; the required real OpenGL rerun passed.
  The first EV wrapper aggregation received unavailable Windows child exit
  codes (`-2`) despite all 24 child reports and success markers passing; the
  harness's documented `-AggregateOnly` path revalidated those exact reports
  and produced the passing manifest without rerunning or changing simulation.

# Agent Prompt — pusherv3_5: Physical Piles, Contact Pressure, Visible Exits

Follow-up to archived `docs/todone/pusherv3_4_variations_integration_prompt.md`.

## Owner report

1. Rapid drops at one location form implausible perfect columns. Upper coins may
   fail to travel with their platform-rooted support or pop sideways. Add small,
   deterministic, unbiased landing variance so impacts form irregular piles.
2. Coins appear to transmit force across visible gaps and whole rows move from
   a local push. Force may propagate only through physically touching contacts;
   the renderer must depict the same contact radius as the solver.
3. Tray payouts disappear at the lip. Bodies must visibly fall from the shelf
   and arrive in the tray before becoming collectible. Gutter exits must use the
   same honest terminal-fall model.

## Binding requirements

- Keep the 60 Hz fixed-point reference solver and native production solver
  bit-exact. Variance must derive deterministically from physical state/body ID,
  remain symmetric/zero-mean, and never act as a payout scalar.
- Track a real support root/chain for stacked bodies. Waking a body must not
  sever valid platform inheritance; movement stops only when contact is lost.
- Rebuild contact candidates during iterative constraint solving so pressure
  advances through newly touching neighbors, but never across positive gaps.
  Do not synchronize velocities or wake a full row without a contact chain.
- Match displayed coin size to its authored world radius at every depth. Keep
  one ordered batched draw and retain 300/600-body budgets.
- Add a deterministic `tray_fall`/`gutter_fall` terminal phase. A falling exit
  remains in authoritative body state and rendering, cannot collide back onto
  the shelf, and enters the appropriate ledger only upon reaching its terminal
  floor. Collect remains disabled until tray landing.
- Persist/migrate all new state safely and preserve conservation, feature-body
  semantics, Ridge credit timing, Vault fragments, and town integrations.

## Required evidence

- Focused contracts: repeated same-location drops disperse but remain unbiased;
  multi-level platform stacks inherit carry; no lateral pop; separated bodies
  do not transmit force; touching chains do; local pushes do not move unrelated
  rows; renderer/solver contact footprints agree across depth.
- Visible normal/reduced-motion captures for shelf departure, mid-fall, tray
  landing, gutter fall, and rapid-drop pile formation on all machines.
- Exact Windows native/Web reference parity, two-process determinism, migration,
  conservation, feature integration, 300/600-body performance, ≥200k accepted
  drops per machine EV, visual QA, and every supported full regression suite.
