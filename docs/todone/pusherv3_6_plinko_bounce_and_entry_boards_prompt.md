Status: DONE — 2026-08-25
Board row: `pusherv3_6` in `docs/todo/README_0_6_board.md`

# Agent Prompt — pusherv3_6: Plinko Bounce and Entry Boards

Follow-up to archived `docs/todone/pusherv3_5_contact_piles_and_visible_exits_prompt.md`.

## Owner report

1. A coin resting or scraping on one peg can replay the hit sound dozens of
   times instead of producing one impact sound per physical collision.
2. Peg contacts read as sliding: the coin remains trapped against the pin and
   only moves after slipping around it rather than visibly rebounding.
3. The entry fields are not balanced by machine identity. Jackpot Ridge is
   overfilled, Vault Drop is underfilled, and drop variance relies too heavily
   on avoiding an exactly centered release.

## Binding requirements

- Model a peg contact as a lifecycle with separation hysteresis. Emit one peg
  impact on collision entry at meaningful incoming speed; do not retrigger a
  sustained/resting contact. A coin that physically separates and later hits
  again may create another impact.
- Give incoming coins a visible, energy-conserving radial rebound. Suppress
  low-speed micro-bounces after impact without converting the primary contact
  into a slide or pin balance.
- Author distinct, non-overlapping staggered peg fields for Quarter Falls,
  Jackpot Ridge, and Vault Drop. Reduce the impossible Ridge density, add
  useful Vault coverage, and keep every release lane capable of reaching the
  platform.
- Add small deterministic, unbiased release-position and release-velocity
  variance so centered drops remain physical and divergent. Variance may
  change collision paths, never directly scale payout or select outcomes.
- Keep the 60 Hz fixed-point reference solver and native production solver
  bit-exact. Preserve state migration, conservation, payout semantics, visual
  projection, performance ceilings, and accessibility behavior.

## Required evidence

- Focused contracts for one audible event per sustained peg contact, visible
  upward rebound, true separation before a repeat event, bounded quiet
  settling, non-overlapping authored fields, and varied paths/landing positions
  across deterministic seed samples for every machine and entry type.
- Exact Windows native/Web reference parity, two-process determinism,
  migration, conservation, 300/600-body performance, at least 200,000 accepted
  drops per machine EV, visual QA, all-machine normal/reduced-motion delivery
  captures, and the supported full regression suite.

## Execution record

- **Implementation:** `d5bbcf7d`. Peg overlap is now a contact lifecycle with
  separation hysteresis, impact-speed gating, and one event per collision
  entry. Primary impacts rebound radially at higher restitution while quiet
  low-speed contacts settle without event chatter. Release x-position and
  lateral velocity receive independent deterministic unbiased variance; exact
  peg-aligned input remains legal.
- **Entry boards:** Quarter Falls uses a balanced 7-pin two-row field, Jackpot
  Ridge uses an open 7-pin two-row field instead of its former 22-pin wall,
  and Vault Drop uses a staggered 10-pin three-row field instead of four sparse
  pins. Authored spacing prevents one coin from overlapping two pins at once.
- **Reference/native proof:** Windows native-v3/Web GDScript-v3 input parity
  passed at `.tmp/coin_pusher_pusherv3_6_input_parity_2/manifest.json` with
  payload `26461e56d2b26b832c0d7fdd03a8a95a00932ab2cb2f579807c898b827039ffc`.
  Ten-seed two-process determinism passed 510 identical checkpoints with
  combined hash `281025980`.
- **Physics/contracts:** Final focused Coin Pusher suite passed with zero
  failures at `.tmp/test_reports/pusherv3_6_focus_final/summary.json`. It
  covers one event per sustained contact, positive crown rebound, separation
  before legitimate repeat impacts, bounded settling, non-overlapping boards,
  and divergent collision/landing signatures across 16 deterministic seeds
  for every machine entry target. The supported full suite passed at
  `.tmp/test_reports/pusherv3_6_full/summary.json` before the final
  presentation-only peg draw-call reduction; focused contracts and visual QA
  were rerun after that reduction.
- **Presentation:** Final actual-GL plan 9.4 feel capture passed all 24 scenes at
  `.tmp/coin_pusher_pusherv3_6_feel_gl_final/manifest.json`; all-machine
  normal/reduced-motion delivery capture passed at
  `.tmp/coin_pusher_pusherv3_6_delivery_gl_final/manifest.json`; foundation
  visual QA passed. The final 300-body cabinet capture kept zero full
  snapshots and measured renderer p95 `2.769 ms` at
  `.tmp/coin_pusher_pusherv3_6_cabinet_gl_3/manifest.json`.
- **Economy:** Exact 24-shard aggregate EV passed 200,000 accepted drops per
  machine at `.tmp/coin_pusher_pusherv3_6_ev/manifest.json`: Quarter Falls
  physical ROI `0.828750`, Jackpot Ridge physical ROI `0.996415` (credited
  `0.997200`), and Vault Drop physical ROI `0.789175`.
- **Measurement deviation:** Direct production ceilings pass comfortably
  (native solver p95 about `3.871 ms` versus `12 ms`; renderer p95 `2.769 ms`
  versus `5 ms`; synchronous actions `10.7–14 ms` versus `16 ms`). The shared
  broad probe's 60-sample host `process_frame` phase remained scheduler-noisy,
  fluctuating just over `16 ms` for skill-release/collect despite those direct
  costs passing. No gameplay behavior, budget, or assertion was weakened to
  manufacture a green wall-clock sample.
