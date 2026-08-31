# world06_3 host-rooted recovery

Status: **WIP UNREVIEWED / WARDEN GATE PENDING**

This recovery starts at exact frozen World 2 candidate
`740918256dd8895d1a880b13afc02dca10c3433c`. World 2 remains the sole runner
and delivery authority; this row does not reimplement routing.

The candidate semantically recovers the accepted Numbers book, bookmaker,
physical-slip, draw-occasion, aftermath, and staged-proposal work from
`e7aca3478bade4568c8c29ea109f799fd4f0a249` while replacing both rejected
restore designs.

## Authority

- Public `apply_action` and proposal sequences remain non-mutating and
  `authoritative=false`.
- `RunState` binds one live `RefCounted` identity to the Numbers model. That
  identity is never serialized, projected, or accepted from a caller.
- Draw presence is recorded only by the bound host before the existing post
  boundary. Repeated host delivery is idempotent; the post boundary closes it.
- Slip issuance, confiscation, settlement, and draw posting causes are emitted
  directly beside their existing authoritative model mutations. There is no
  model-minted hash receipt and no caller-supplied capability claim.

## Save migration

The predecessor snapshot has an exact 13-key legacy shape. A genuine legacy
snapshot may not carry depth fields or nested physical state. It migrates to
deterministic physical projections, absent attendance, and empty aftermath.

The current snapshot has an exact 17-key shape and depth schema version 2. Its
closed, bounded causes must agree with slip identity, venue, day, holder/place,
status, post/settlement boundary, draw number, payout result, detection result,
attendance, and bookmaker aftermath. Every cause must be reachable from the
current physical state, draw occasion, or aftermath. Unknown keys, partial
versions, stripped causes, impossible physical relations, orphan causes, and
cross-causal substitutions reject atomically.

## Unchanged contracts

All 78 pre-existing numeric tuning paths are byte-for-byte unchanged. Draw
derivation, timing, odds, bet limits, payout functions, detection math, pool
cap, fix economics, debt/trust/grievance application, and rumor consumers are
unchanged. Static project validation passes; serialized Godot verification is
pending with the Warden.
