# Baccarat deal presentation

The reported Web failure was an immediate completed hand instead of sequential
Player/Banker dealing. Source baseline: `7508210fdb04d5267f4bb260801563131ed72ab0`.
No affected player save or pinned browser build was captured.
The shared wallet contract is supplied by main commit
`5401462aaf1550b4d1a5883cb35d5813a3f66586` and was integrated before publication.

Baccarat authored `resolved_at_msec` against the simulation/surface clock, but
its deal and payout channels omitted `clock_source`. GameSurfaceCanvas therefore
compared the timestamp against engine uptime. Time spent loading or in paused
menus can make the ceremony appear finished immediately; the opposite clock
offset can stall it. Both full snapshots and realtime patches now explicitly
use the surface clock. An active deal with no visible events also stays empty
instead of falling through to the final hand.

The existing 4200 ms ceremony and finite-shoe/tableau logic are retained. The
road board, commission and patron reactions wait for the reveal. Successful
deals opt into the shared host's `hold_money_for_presentation` result contract;
full/realtime surfaces expose `money_presentation_pending = deal_active`.
Accounting remains sealed at action acceptance. Presentation does not draw,
settle, consume RNG, or replay receipts.
Normal table entry after scene exit or Continue marks its already-paid hand's
presentation complete, matching the shared host's transient wallet-hold policy.
The completion marker lives only in the module; the save schema is unchanged.

## Focused verification

`scripts/tests/baccarat_deal_presentation_check.gd` requires a fresh isolated
`BTH_DISTRIBUTION_DATA_ROOT`. It uses synthetic finite shoes with the authentic
sealed host and the production GameSurfaceCanvas. It checks natural hands,
both third cards, Player-only and Banker-only draws; event boundaries; divergent
engine/surface clocks; delayed result/road/commission; the shared hold opt-in;
conservation, RNG ownership, cached delivery replay, repeated deals, SaveService
save/load, restored clock projection, and completed presentation on normal table
reentry. Integrated checks also sample the shared host's masked wallet/net and
release at the final-card boundary.

Run it with the pinned Godot and private persistence paths:

```text
godot --headless --path . --script res://scripts/tests/baccarat_deal_presentation_check.gd
godot --headless --path . --script res://scripts/tests/animation_liveness_without_pointer_check.gd
```

Both passed under the maintained Windows Job helpers, with a 5% aggregate CPU
cap, 2 GiB memory limit, assignment before execution, and zero owned processes
at release. The baseline source failed the clock/card visibility and early-road
checks. Early test-harness failures (a dictionary replay marker, a missing
host-owned clock field, and JSON numeric types) were corrected without changing
production accounting or persistence. The headless sandbox emitted a Windows
certificate-store read warning; these local checks made no network requests.

## Web evidence boundary

A sandboxed, muted headless Chrome session used an explicit fresh task profile
and the immutable deployed `7508210f` URL on trusted localhost. It reached the
Godot loading screen, but did not reach the menu within its 160-second bound.
The private Job was drained with zero processes remaining. No personal browser,
save, TLS exception or security-warning bypass was used. This is an attempted
Web startup check, not visual Baccarat gameplay qualification. Natural/third-card
animation and interruption on the served Web build remain unverified until a
usable isolated Web session is available.
