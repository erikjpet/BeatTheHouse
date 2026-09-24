# rw06_2 Crew heist ending route — first-pass replay

Status: **IMPLEMENTED; QUALIFYING LIVE RUN PENDING rw06_1/rw06_5**
Implementation base: `origin/main` at `7da3e5dab59b`
Canonical terminal route: `crew_heist`
Preferred launch plan: **The Count (Plan A)**
Fixed replay seed: `PLAYTEST-CATALOG-01`

`tools/rw06_2_ending_replay.ps1 -Ending heist` now encodes the full first-pass
route: public Crew marker and both favor deliveries, Punchline discovery, Bishop's
two-beat recruitment and visible job ladder, three distinct Grand identity
visits, real Cage/main-room setup travel, the three live-table decisions, and a
real getaway delivery. It performs a specialized public planning-table Save →
process exit → relaunch → Continue checkpoint and accepts all three authored
Crew win rungs. Natural reachability and the twice-identical/fresh-seed passes
remain to be proved after the shared gameplay work lands.

Q-011 is a required getaway invariant, not an optional recovery detour. The
dock exit delivers the player to Delta Queen, whose production destination
list must then expose one visible, free Beach route on the fresh arrival, every
revisit, and after Save -> relaunch -> Continue. Only the exact transient boat
travel lock may disable Beach; the replay fails closed if metadata exists but
the real selectable destination does not.

## Player intent

Earn a real Crew relationship, bring Bishop to Inner Circle, unlock The Count
through Audit Night, perform every setup task through visible world actions,
play the three-round table sequence, and deliver the getaway package. Avoid
grievances so the hidden Turn system has no reason to interrupt the launch
route.

## Why Plan A is the preferred route

Plan A uses blackjack, three Grand Casino identity sessions, two visible setup
deliveries/holds, three live-table rounds, and a delivery-style getaway. Plan B
requires two deliberate whale losses totaling $60, a specific item, craps
training, $120 conspicuous spending across two visits, five mixed High Limit
games, and a cage interview. Plan B remains a supported product path, but Plan A
is the narrower candidate for a 150–350 action release replay.

## Source-derived route

1. Start a normal seeded run and accept a visible two-favor Crew marker. Retained
   natural route evidence uses the Crew lender at Corner Store and ordinary
   favor deliveries; clear both visible deliveries before the long heist arc so
   a second overdue call cannot interrupt it. The merged build must confirm the
   exact first contact.
2. Discover the Punchline through Parking Lot Tip and Side Door, then do ordinary
   visible Crew work until Made standing unlocks the back room. Do not abandon
   jobs, make false accusations, or create other grievances.
3. Reach the Grand Casino and meet/recruit Bishop through his visible two-beat
   appointment (**Wait by window**, then **Keep appointment**). Recruitment
   promotes Bishop to Associate (30 trust).
4. Raise Bishop from Associate to Inner Circle (90) through visible Bishop jobs
   and/or back-room poker. Known jobs are Camera Window (+6 trust, +$30) at
   Associate and Cage Packet (+7 trust, +$40) at Made. Repeated job availability,
   deadlines, member presence, and action count require live verification.
5. Naturally encounter Grand Casino Audit Night. `PLAYTEST-CATALOG-01` is the
   first seed to verify because retained catalog notes assigned
   `grand_casino_audit_night`, but only diagnostic prevalidated travel produced
   that historical note.
6. At the Punchline Planning Table, verify The Count is visibly live because
   Bishop is Inner Circle and Audit Night is known. Lock **The Count**. Do not
   confront a member or change seats when the route has no grievance evidence.
7. Complete identity setup: on three distinct Grand Casino visit sessions,
   settle one blackjack wager of $8–30 and keep the heat peak <= 35.
8. From the Planning Table, start **Watch the schedule**. Reach the Cage and hold
   for two visible actions before its deadline/attention cap.
9. Return to the Planning Table, start **Move the swap cart**, carry the package
   to Grand Casino Main, and complete the visible handoff.
10. Optional corridor exit: complete the Debt Court/Knuckles Associate marker if
    it occurs naturally. The replay may instead use the always-available dock
    exit; do not add this detour only to improve the outcome rung.
11. **Required persistence checkpoint:** after all setup chairs are visibly
    filled but before **Begin the Play**, Save, return to Main Menu, quit,
    relaunch the same isolated session, and Continue. Confirm the locked plan,
    Bishop relationship, completed setup, current room, bankroll, and heat from
    public UI only.
12. Choose **Begin the Play** and go to the designated Grand blackjack table.
    Settle three $8–30 rounds, interleaving the visible decisions:
    - round 0: `early` or `hold`;
    - round 1: `sit` or `dump`;
    - round 2: dock, or corridor only when the visible marker unlocked it.
13. Keep heat controlled, then choose **Take the exit**. The dock getaway target
    is Delta Queen; the corridor target is the Cage. Complete the real delivery/
    travel handoff through visible controls. On the dock path, verify the real
    Delta Queen destination list exposes the Q-011 Beach route; do not inject or
    manually unlock it for the replay.
14. Confirm an ended run and a visible Crew heist outcome (`clean_sweep`,
    `out_hot`, or `somebody_got_pinched`). All three are canonical Crew wins;
    runtime route is `crew_heist`.

## Intended replay decisions

- Prefer Camera Window/Cage Packet work based on visible member/contact and job
  copy; never set trust or complete jobs directly.
- Keep zero grievances. Do not use planning-table Turn choices when no public
  contradiction exists.
- Use the dock exit unless corridor is visibly unlocked. Prefer the safest
  visible play decisions after the seed's first interactive run establishes
  their public tradeoffs.
- Branch only on observable relationship rank, plan/setup copy, map targets,
  game actions, heat, and result text. Never read the private heist capsule or
  hidden Turn member.
- If The Count cannot be made naturally reachable within the target run length,
  investigate Plan B and product arc issues. Do not inject Audit Night or Bishop
  trust, and do not silently redefine completion.

## Experience log skeleton

| Beat | Player-visible goal | Money/heat checkpoint | What could break the arc |
|---|---|---|---|
| Marker | Learn how Crew work begins | favor income should fund travel | lender/favor loop feels disconnected from heist |
| Made | Open the Punchline back room | jobs should be net-positive | 11+ favors become a dead stretch |
| Bishop | Recruit the required specialist | trust 30 -> 90 | member presence/jobs are too rare or opaque |
| Hook | Recognize Audit Night as an opportunity | retain Grand travel/wager funds | hook is seed-rare or not surfaced as plan progress |
| Setup | Fill three concrete chairs | three bets $8–30; heat <= 35 | visit-session rule or deadlines are unclear |
| Save/Continue | Trust the long route persists | same plan/setup state | package/task state disappears or duplicates |
| Play | Execute the plan under pressure | three table rounds, bounded heat | decision beat fails to appear between settlements |
| Getaway | Read and finish the route | target shown on map | package target/travel lock is ambiguous |
| Outcome | Understand the outcome rung | terminal report visible | success rung looks like ordinary job completion |

## Acceptance checklist

- [x] Rebase/re-read Crew, world hook, and heist logic on the accepted rw06_0 `origin/main`.
- [ ] Prove a natural Audit Night seed; reject diagnostic-only reachability.
- [ ] Measure the full marker -> Bishop 90 path and keep it within 150–350 player
      actions, or file the dead stretch as an arc blocker.
- [ ] Record exact contact, planning-table, setup, game, and delivery semantic IDs.
- [ ] Prove the same seed and public decision policy reaches the same Crew win
      twice without private-state inspection.
- [ ] Complete one additional fresh-seed interactive heist run.
- [ ] Add actual action count, transcript/evidence paths,
      money curve, next-goal notes, and arc-breaker findings.
