# rw06_3 balance changes

Scope: ending-route economy data only. Game rules, wager math, payout tables and
RTP are unchanged.

## Grand invitation package

Status: implemented; lightweight JSON/PowerShell checks and the combined replay
source contract pass. Focused Foundation evidence and the post-change route
measurement wait for the active rw06_1 engine lane.

- `grand_casino_invite.accept_invite` bankroll grant: absent / `$0` -> `$50`.
- `grand_casino` route comp origins: absent -> exactly
  `kitty_cat_lounge`, `delta_queen`, and `beach`.
- Player-facing effect: accepting the invitation explicitly says that the host
  comps a first `$50` stake; Grand travel is free from either normal invitation
  venue and from the Q-011 Beach detour.

Reason: Clean Probe 29 followed only deterministic, public liquidity and ended
at `$126` cash with a displayed `$95` Grand fare and a required `$50` playable
stake. The resulting `$145` entry requirement left a measured `$19` shortfall.
Twenty-four straight lowest-stake Slot losses in Probe 19 also show that a
gambling win is not an acceptable deterministic recovery requirement.

Measured effect:

- Before: `$126 - $95 fare = $31`, which is `$19` below the `$50` stake floor.
- After, on the same Kitty/Delta/Beach invitation route: the `$50` grant raises
  the checkpoint to `$176`, and the comped ride preserves all `$176` on Grand
  arrival. That is a deterministic `$126` margin above the immediate `$50`
  stake floor, subject to confirmation by the next no-retry replay.
- A player who accepts at `$1` reaches `$51` and can enter with the full stake.
  Zero bankroll remains terminal, non-comp origins keep the positive authored
  fare, and ordinary global travel locks still apply.

This is one authored invitation package, not two independent tuning passes: the
grant supplies the promised first stake and the three-origin comp prevents that
stake from being consumed by the invitation trip. Reckless pre-invite losses,
all game variance, the `$70` base fare from other origins, and bankruptcy risk
remain intact.

## Departure-price integrity repair (rw06_2 blocker fix)

The balance data exposed an existing travel transaction defect: the map priced
the route from the departure room, but production installed the destination and
then recomputed the charge from that new room. A comp could therefore render as
`$0` and still deduct the full fare after arrival.

This is classified as an rw06_2 arc fix, not another balance lever.
`FoundationMain` now snapshots the authoritative route status at departure and
uses that same status when constructing the arrival result. The regression
confirms real Delta-to-Grand travel preserves a `$51` bankroll, records a `$0`
route cost, and starts Grand net winnings at zero; a real Bar-to-Grand control
still deducts its positive departure fare exactly once.
