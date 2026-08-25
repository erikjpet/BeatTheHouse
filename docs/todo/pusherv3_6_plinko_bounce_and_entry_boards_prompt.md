Status: IN_PROGRESS — 2026-08-25
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
