# rw06_3 balance changes

Scope: ending-route economy data only. Game rules, wager math, payout tables and
RTP are unchanged.

## Grand invitation package

Status: implemented; lightweight JSON/PowerShell checks and the combined replay
source contract pass. Focused Foundation evidence and the post-change route
measurement remain pending the accepted rw06_1 landing and an authorized engine
slot.

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

Projected effect pending the post-change replay:

- Before: `$126 - $95 fare = $31`, which is `$19` below the `$50` stake floor.
- After, on the same Kitty/Delta/Beach invitation route: the `$50` grant raises
  the checkpoint to `$176`, and the comped ride preserves all `$176` on Grand
  arrival. That is a deterministic `$126` margin above the immediate `$50`
  stake floor, subject to confirmation by the next no-retry replay.
- A player who accepts at `$1` reaches `$51` and can enter with the full stake.
  Zero bankroll remains terminal; absent an existing Rook discount, non-comp
  origins keep the positive authored fare. Ordinary global travel locks still
  apply.

This is one authored invitation package, not two independent tuning passes: the
grant supplies the promised first stake and the three-origin comp prevents that
stake from being consumed by the invitation trip. Reckless pre-invite losses,
all game variance, the `$70` base fare from other origins, and bankruptcy risk
remain intact.

The package intentionally moves its two coupled data fields together, so it is
the one documented exception to the ordinary one-change-at-a-time diagnostic
sequence. No later balance value may change until a real Clean replay measures
the combined package and the Cheat/Heist public curves exist. Accepting the
invitation awards the `$50` only once, after which it is ordinary bankroll; the
eligible-origin travel comp is repeatable under the current data model.

## Finished-route balance pass (2026-09-25)

### Clean / Players Card

- Data change: none.
- Reason: the completed normal-use Clean replay took 197 player actions, inside
  the 150–350 target. It ended debt-free with `$37`, after `$120` of Blackjack
  inflow, `$63` of event inflow, and `$37` of travel spend. Raising prices,
  reducing rewards, or extending the Players Card gates would add risk to an
  already correctly paced route; lowering them would shorten it unnecessarily.
- Measured effect of the existing invitation package: the route reached the
  Gold Players Card without a loan or a lucky recovery requirement. The `$50`
  invitation stake and eligible-origin `$0` Grand trip remain unchanged.

### Cheat / Rourke

- Grand Casino `showdown_heat_threshold`: `70 → 85` in every Grand room's
  shared objective data.
- Reason: the completed deterministic Cheat replay took 101 player actions,
  below the normal-player guideline but appropriate for an optimized fast
  route. Aligning the ordinary heat call with the existing 85-heat Pit Boss
  warning requires a normal heat-driven player to survive another visible
  pressure cycle instead of receiving Rourke's call immediately after the
  65-heat Floor Staff warning. The separate `$30` dirty-money trigger remains
  available to a profitable cheater, and the 95-heat forced call remains the
  hard ceiling, so legitimate fast finishes are preserved.
- Measured effect: pending the single allowed post-change Cheat replay.

### Prices, rewards, and lender terms

- No additional change after the finished-route measurements. Clean ended at
  197 actions and Cheat ended debt-free with `$46`; both routes already carry
  meaningful travel and bankroll pressure. Increasing prices or weakening the
  `$50` invitation reward would threaten deterministic entry, while cheaper
  prices or softer lender terms would reduce bankruptcy risk without solving
  an observed route-length problem. Heist-related prices, Crew rewards, lender
  terms, and gates remain untouched until Lane C finishes its route.

## Departure-price integrity repair (rw06_2 blocker fix)

The balance data exposed an existing travel transaction defect: the map priced
the route from the departure room, but production installed the destination and
then recomputed the charge from that new room. A comp could therefore render as
`$0` and still deduct the full fare after arrival.

This is classified as an rw06_2 arc fix, not another balance lever.
`FoundationMain` now snapshots the authoritative route status at departure and
uses that same status when constructing the arrival result. The exact focused
gate confirms real Delta-to-Grand travel preserves a `$51` bankroll, records a
`$0` route cost, and starts Grand net winnings at zero; its real Bar-to-Grand
control deducts the positive departure fare exactly once.
