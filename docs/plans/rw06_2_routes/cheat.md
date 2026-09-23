# rw06_2 Pit Boss ending route — first-pass replay

Status: **IMPLEMENTED; QUALIFYING LIVE RUN PENDING rw06_1/rw06_5**  
Implementation base: `origin/main` at `7da3e5dab59b`  
Canonical terminal route: `pit_boss_showdown`  
Fixed replay seed: `RW06-CHEAT-ROUTE-01`

`tools/rw06_2_ending_replay.ps1 -Ending cheat` now encodes this route through
the production-input bridge. It branches only on public choices, blackjack
cards/actions, Rourke's rendered tell, and public objective state; it performs
Save → process exit → relaunch → Continue before duel hand one and accepts only
the public `showdown_survived` win. The qualifying twice-identical run and
fresh-seed experience pass remain open until the shared gameplay work lands.

## Player intent

Enter the Grand Casino, make Rourke call the player into the back room, survive
the pat-down and interrogation, then finish the fixed-ante blackjack duel at or
above its successful margin. This route should feel knowingly dangerous, not
like an accidental clean-route failure.

## Source-derived route

1. Follow the same natural world path as the clean route: discover tier 2,
   accept the High Roller Invitation, retain the $70 travel fare, and enter the
   Grand Casino through the visible map.
2. Carry no classified contraband or surveillance gear into the showdown. In
   particular avoid `marked_cards`, `foil_sleeve`, `weighted_keyring`,
   `xray_glasses`, `tab_detector`, and `tarot_card`.
3. Use one verified visible cheat and build at least $30 Grand Casino net
   winnings to trigger the `dirty_money` lane, or deliberately raise heat to a
   verified showdown threshold. Current thresholds are 70 with staff attention
   and 95 forced. Prefer dirty money if the live route exposes it clearly and
   reproducibly.
4. Open `the_house_calls` and choose the visible equivalent of **Follow Rourke**.
5. During the walk, prefer **Keep Everything** only because the replay must have
   no classified items. If a route-acquired classified item cannot be avoided,
   visibly trash exactly the risky item before the pat-down.
6. Pass the pat-down. A watched cheat plus any contraband, or three contraband
   items, is an immediate terminal failure; surveillance items are serious.
7. Choose **Take Chair** and answer the three interrogation beats from visible
   evidence. Default to `hold_steady` for a clean record; use `talk_down` only
   when the visible relationship strength supports it. Avoid `take_the_edge`
   unless live evidence proves it is necessary because it adds watched-cheat
   evidence.
8. **Required persistence checkpoint:** once the showdown is visibly active and
   before the first duel hand, Save, return to Main Menu, quit, relaunch the same
   isolated session, and Continue. Confirm the back-room phase, public duel
   margin/hand count, bankroll/chips, heat, and available actions.
9. Play up to five fixed-ante blackjack hands with ordinary visible decisions.
   Call Rourke's edge only when the surface visibly exposes an actual tell
   (`deck_stack` or `hole_swap`); a correct call swings +18 and a false call -6.
10. Finish with duel margin >= -60. `walk_out_clean` (>= 12) and
    `shown_the_door` (>= -60) are both canonical Pit Boss wins; below -60 is
    `casino_taken_out_back` failure.
11. Confirm the terminal report visibly identifies a survived showdown/house
    outcome and an ended run. Runtime route is `pit_boss_showdown`.

## Intended replay decisions

- Select the showdown trigger only from public heat, objective, action, and
  result copy. Never inspect hidden flags, dealer cards, or the save file.
- Carry zero classified gear so pat-down behavior is deterministic and legible.
- Use ordinary blackjack basic strategy from the rendered cards. The replay may
  branch on public hand totals/actions, but never on hidden deck state.
- Call an edge only when the player-facing surface publishes it.
- Fail immediately if the clean route becomes ready instead, Rourke does not
  appear after the published trigger, the pat-down classifies unexpected gear,
  or the terminal outcome is the failure route.

## Experience log skeleton

| Beat | Player-visible goal | Money/heat checkpoint | What could break the arc |
|---|---|---|---|
| Invitation | Reach the watched floor | preserve $70 fare | same early economy risk as clean route |
| Provocation | Make Rourke notice on purpose | net >= +$30 with cheat, or heat threshold | trigger reason is invisible or fires too early |
| Escort | Understand that this is the alternate ending | inventory should be safe | surprise pat-down failure from an innocuous-looking item |
| Save/Continue | Trust the confrontation persists | same showdown phase/margin | event resumes at wrong beat or loses duel state |
| Interrogation | Read the social stakes | visible strength/copy only | choices do not explain consequences |
| Duel | Survive five tense hands | margin must stay >= -60 | tell/callout is unreadable; game surface stalls |
| Outcome | See that shown-the-door still counts as a win | terminal report visible | report copy makes success look like failure |

## Acceptance checklist

- [x] Rebase/re-read route and showdown data on the accepted rw06_0 `origin/main`.
- [ ] Verify one natural seed, an affordable world route, and the safest visible
      dirty-money or heat trigger.
- [ ] Record exact event choices and blackjack surface actions.
- [ ] Prove the same seed and public decision policy ends in the same successful
      outcome twice.
- [ ] Complete one additional fresh-seed interactive Pit Boss run.
- [ ] Add actual action count, transcript/evidence paths,
      money curve, next-goal notes, and arc-breaker findings.
