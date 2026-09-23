# rw06_2 clean ending route — first-pass replay

Status: **IMPLEMENTED; QUALIFYING LIVE RUN PENDING rw06_1/rw06_5**
Implementation base: `origin/main` at `7da3e5dab59b`
Canonical terminal route: `high_roller_cashout`
Fixed replay seed: `RW06-CLEAN-ROUTE-01`

`tools/rw06_2_ending_replay.ps1 -Ending clean` now encodes this route through
the production-input bridge. It fails closed on non-public observation fields,
requires a real Cage/main-room door traversal, performs Save → process exit →
relaunch → Continue after Silver, and accepts only the public `players_card`
win. The qualifying twice-identical run and fresh-seed experience pass remain
open until the shared gameplay work lands.

## Player intent

Reach the Grand Casino, earn Bronze, Silver, and Gold Players Card tiers without
cheating or exceeding 30 heat, then claim the Gold review from Linda at the
Cage. Preserve enough cash for the $70 Grand Casino trip and enough chips to
finish all nine qualifying games.

## Source-derived route

1. Start a normal seeded run. Complete any mandatory first-night/tutorial
   presentation through its visible controls.
2. Visit two distinct tier-1 casino nodes, or visit the Punchline, so tier-2
   casinos become discoverable.
3. Reach Kitty Cat Lounge or Delta Queen. Accept the visible High Roller
   Invitation event. Do not buy or carry cheat/surveillance items.
4. Keep at least $70 available for Grand Casino travel; travel there through the
   visible map.
5. Establish the entry bankroll and buy/use chips only through visible venue
   controls. Avoid ATM debt, cheat actions, and risky-evidence actions.
6. Bronze segment: settle at least 1 game, finish the segment at least $5 net
   positive, and keep segment heat at or below 30. Travel to the Cage and claim
   the ready Bronze tier from Linda.
7. Silver segment: from the Bronze reset point, settle at least 3 games, finish
   at least $15 net positive, and keep segment heat at or below 30. Claim Silver
   from Linda. Silver grants 10 chips, a drink comp, a suite rest, and High Limit
   access.
8. **Required persistence checkpoint:** after the visible Silver claim, open the
   run menu, Save, return to Main Menu, quit, relaunch the same isolated session,
   and Continue. Confirm the room, card tier, bankroll/chips, heat, and next Gold
   objective from public UI only.
9. Gold segment: from the Silver reset point, settle at least 5 games, finish at
   least $30 net positive, and keep segment heat at or below 30. Return to the
   Cage and claim the Gold review.
10. Confirm the terminal report shows an ended run and the clean/Players Card
    outcome. Canonical runtime route is `high_roller_cashout`.

The implementation currently treats the three tiers as sequential segments.
The route therefore needs at least 9 settled games and +$50 aggregate Grand
Casino net winnings, not merely 5 games and +$30 overall.

## Intended replay decisions

- Use the lowest-variance visible legal game/wager sequence that the verified
  seed makes profitable; do not encode state edits, debug actions, save edits,
  or a hidden-card oracle.
- Claim each card tier immediately when the HUD/Cage visibly says it is ready.
- Leave or rest only when the visible heat/objective state says it is safe and
  doing so does not invalidate the segment.
- Treat any permanent Players Card ineligibility, heat over 30, unexpected ATM
  debt, or missing Linda claim as an immediate replay failure.

## Experience log skeleton

| Beat | Player-visible goal | Money/heat checkpoint | What could break the arc |
|---|---|---|---|
| Invitation | Find a way into the Grand | cash must still cover $70 | invite is too obscure; early purchases make fare impossible |
| Arrival | Understand the clean lane | entry bankroll, chips, heat 0-ish | objective copy hides sequential tier rules |
| Bronze | Win one meaningful game | segment >= +$5, heat <= 30 | player does not know to visit Linda |
| Silver | Prove consistency | segment >= +$15 over 3 games | low bankroll, variance, or repetitive play |
| Save/Continue | Trust persistence | same public state after Continue | card tier or room state appears lost |
| Gold | Finish the long clean climb | segment >= +$30 over 5 games | nine-total-game requirement feels like a surprise |
| Cashout | Deliberately take the ending | terminal report visible | Gold is ready but no obvious claim action |

## Acceptance checklist

- [x] Rebase/re-read route logic on the accepted rw06_0 `origin/main`.
- [ ] Verify the seed naturally exposes two tier-1 nodes, a tier-2 invite, and an
      affordable path to Grand Casino.
- [ ] Record exact semantic object/action IDs and visible labels.
- [ ] Find one legal deterministic wager sequence that clears all three segments
      twice identically without altering RTP or game math.
- [ ] Complete one additional fresh-seed interactive clean run.
- [ ] Add actual action count, transcript/evidence paths,
      money curve, next-goal notes, and arc-breaker findings.
