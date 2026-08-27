Status: PARKED - owner decision required; not claimable
Board route: `fix06_10` in `docs/todo/README_0_6_board.md`

# fix06_12 - Coin Pusher persistent-machine liveness owner decision

## Binding evidence

Accepted runner heads `861d2d40a40c27bcde7fe67c0b8e0912c38567f9` and
`745051323f90ffcd7839b5dbfab0074f5553b290` are integrated at
`ab584b0b965301e523b173d477491b19f125d1ac`. Validation, editor import and
`native_v3` smoke passed. The one exact run stopped on QF00 at 530 accepted
inserts plus 4,096 consecutive ceiling refusals, with active 600, tray 0,
gutter 80 and direct-worker peak 575,750,144 bytes. Twenty-three shards were
not started; no rerun occurred. This is liveness evidence, not an EV-band verdict.

## Owner decision

Authorize one of physics, geometry, capacity-ceiling, policy, reset, or other
design changes to restore persistent-machine accepted-insert liveness. Every
listed route changes locked Coin Pusher behavior and may change physical EV.
The PM will not choose or infer authorization.

## After an explicit ruling

Create a separately scoped implementation row that records the chosen behavior,
revalidates conservation, determinism and native parity, obtains independent
review, and then performs one newly authorized exact EV run. Do not tune to the
EV band, reset favorable piles, reduce the sample, or reuse the retained red as
a completed economics result.
