Status: DONE — 2026-08-25
Board row: `pusherv3_9` in `docs/todo/README_0_6_board.md`

# Agent Prompt — pusherv3_9: Contact Bed and Opaque Payout Edge

Follow-up to archived
`docs/todone/pusherv3_8_coin_scale_lower_bed_and_edge_ramp_prompt.md`.

## Owner report

- The smaller flat coins remain visibly separated in the opening state rather
  than touching and transmitting pressure through a real coin bed.
- The payout edge reads as a magic line. Coins remain visible beneath it before
  collection instead of building behind a physical shelf edge and emerging
  only after clearing the lip.

## Binding requirements

- Seed irregular, staggered opening clusters whose neighboring coins are in
  genuine near-contact within collision tolerance. Preserve useful macro gaps
  and pile variation, but eliminate repeated empty space between every coin.
- Keep pressure contact-only: separated clusters must not transmit force until
  contact, while touching clusters must transmit local pressure rather than
  moving as a global row.
- Use a slight payout incline compatible with flat-disc edge contact so the
  edge prime remains mechanically connected to the lower bed.
- Render an opaque, solid payout-edge apron in the foreground after the coin
  batch. A coin behind the ledge must be occluded; it becomes visible below the
  apron only as its physical terminal fall clears the shelf.
- Preserve the restored 40x32 flat-coin artwork, visible terminal falls,
  deterministic persistence, exact native/reference parity, bounded opening
  payouts, EV, accessibility, and performance.

## Required evidence

- Opening contact-density and local pressure contracts, ledge face geometry
  and foreground-order contracts, focused physics regression, exact parity,
  determinism, and updated actual-render captures for all three machines.

## Execution record

- **Touching played-in stock:** Opening generation now uses compact staggered
  clusters with tiny deterministic scuffs instead of sparse samples from wide
  lanes. All `150/150/154` opening coins are within the real collision contact
  tolerance in the four-seed machine matrix, while varied row lengths preserve
  irregular side gaps and localized piles rather than a perfect full sheet.
- **Contact-only pressure and safe openings:** The connected layout still uses
  the existing local collision graph; separated clusters do not inherit global
  row motion. Quarter Falls, Jackpot Ridge, and Vault Drop retained at least
  `8/9/9` edge coins and `15/14/18` elevated coins. Maximum passive payouts were
  `0/0/1`, and maximum first-five totals were `1/0/2`, so contact does not create
  an opening avalanche.
- **Physical, opaque payout edge:** The solver-backed payout plate remains
  `6500` units long but now has a contact-compatible `900`-unit rise. A solid
  `3000`-unit-deep foreground apron is rendered after the coin batch. Coins are
  occluded while behind the shelf face and become visible below it only when
  their existing terminal-fall path physically clears the apron.
- **Physics, parity, and determinism:** Focused physics validation and the full
  24-check foundation suite pass. The 300-body native solver measures `3.197`
  ms p95 against its `12` ms ceiling. Exact native/Web parity passes with payload
  `c1b1a7f22226ce72d0d32fb5ffba012bcb8048db8183535089094f45f22887bc`.
  Two-process determinism passes 10 seeds and 510 checkpoints with combined hash
  `331122666`.
- **Visual and economy proof:** The actual-GL capture manifest passes every
  required normal/reduced-motion scene for all three machines at
  `.tmp/pusherv3_9_visual_2/manifest.json`. Review images are in
  `review_artifacts/coin_pusher_pusherv3_9_contact_edge_20260825/`. The complete
  24-shard EV audit accepted 200,000 plays per machine and passes at
  `.tmp/pusherv3_9_ev/manifest.json`: Quarter Falls physical ROI is `0.890210`,
  Jackpot Ridge physical/credited ROI is `0.926025/0.926405`, and Vault Drop
  physical ROI is `0.841235`; all conservation and authored-band gates pass.
- **Regression compatibility:** The deterministic Crew-ignored fixture was
  refreshed only for the intentional serialized opening-layout change; byte
  sizes and unrelated environment payloads remain stable. Project validation,
  exhaustive script loading, and the rerun foundation suite pass in
  `.tmp/test_reports/pusherv3_9_foundation_all_2/`.
