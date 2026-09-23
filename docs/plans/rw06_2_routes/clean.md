# rw06_2 clean ending route — first-pass replay

Status: **IMPLEMENTED; EXPLORATORY LIVE RUN STARTED; QUALIFYING LIVE RUN PENDING rw06_1**
Implementation base: `origin/main` at `7da3e5dab59b`
Canonical terminal route: `high_roller_cashout`
Fixed replay seed: `RW06-CLEAN-ROUTE-01`

`tools/rw06_2_ending_replay.ps1 -Ending clean` now encodes this route through
the production-input bridge. It fails closed on non-public observation fields,
requires a real Cage/main-room door traversal, performs Save → process exit →
relaunch → Continue after Silver, and accepts only the public `players_card`
win. The qualifying twice-identical run and fresh-seed experience pass remain
open until the shared gameplay work lands.

## 2026-09-23 current-main exploratory probe (non-qualifying)

Product base `6a9201e3`; pushed replay tip `e67a316d`. Exactly one
`-Ending clean -Repeat 1` run was made under the serialized Godot lease. It
accepted **PLAY**, entered the real first-night Apartment at $80 / 0 Heat, and
then stopped fail-closed after one counted action.

The screen clearly showed Pal's TalkDock instruction, the highlighted X-Ray
Glasses, and the rendered **Pick them up** choice (public id `continue`). The
replay nevertheless required a separately rendered **Skip tip** button because
the coach snapshot advertised that dismiss label. This is a replay-policy
blocker, not a product arc breaker or placement finding: the player's next step
was visible and actionable. The runner now narrowly acknowledges the single
enabled `continue` choice only when its public TalkDock event id begins with
`tutorial_guide:`, then resumes its existing fail-closed coach handling. No
ending, route economy, or goal-clarity conclusion is claimed from this probe.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-main-6a9201e3/20260923-092920-880-9772/run-01/summary.json`
  (SHA-256 `6225DC1798DEE8A4EE5772047E6256D76A2C5B099F886B8F03047E9B6E72CDC9`).
- Public trace:
  `.tmp/rw06_2/exploratory/clean-main-6a9201e3/20260923-092920-880-9772/run-01/public_trace.ndjson`
  (SHA-256 `EA0759C3A5AEBFA40CC9FFC3A16C8ADBEE2743C722162D28A7F95107032A88D1`).
- Screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-9772-1-cc8e9a2679/0003.png`
  (SHA-256 `71BA5710A6B7ACE5EB999AA88D6DA41C845D571828183510AD8016210C91D833`).
- Exact owned process exited and no Godot process survived. Its post-exit stderr
  contained the generic engine warning `ObjectDB instances leaked at exit`;
  that warning remains preserved with the session evidence rather than being
  ignored or treated as a passing run.

## 2026-09-23 second current-main exploratory probe (non-qualifying)

Product base `11c584bd`; pushed replay tip `760bdf4c`. Exactly one additional
`-Ending clean -Repeat 1` run was made under the serialized Godot lease. The
narrow tutorial-policy correction worked: the replay chose Pal's rendered
**Pick them up** action, then used the rendered **Skip tip** control. It opened
the run menu and stopped fail-closed after four counted actions because
**Skip Lessons** was below the clipped viewport. The visible run-menu scroll
bar could reach it, but the production-input bridge did not yet expose that
rendered scroll capability.

This is another replay/bridge reachability issue, not a product ending,
placement, goal-clarity, or economy finding. The bridge and route now expose
and consume only the rendered `run_menu` vertical-scroll capability, issue
real mouse-wheel input, verify movement, bound the search, and reject missing,
duplicate, hidden, wrong-axis, unsupported, and direction-blocked surfaces.
No direct scroll state is assigned. The engine-free source contract covers
seven hostile fixtures; a later serialized live run must prove this correction.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-main-11c584bd-probe2/20260923-094003-789-18960/run-01/summary.json`
  (SHA-256 `D876EF3276898B59AC33B0E9F10C8A7953184E6EA29CA352A3DFFE03E74AF344`).
- Public trace:
  `.tmp/rw06_2/exploratory/clean-main-11c584bd-probe2/20260923-094003-789-18960/run-01/public_trace.ndjson`
  (SHA-256 `7EA758E46F604730476B12327A9FB0CC201915B59DDE56DCC56F2D2CAEDF03FF`).
- Screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-18960-1-5c4bd2eceb/0008.png`
  (SHA-256 `8AAE60B91887F0416C2D4960D3A66E58E4793779EAB2ED169D10B5D6C62FDD9F`).
- The exact owned process exited, stderr was empty, and no Godot process
  survived.

## 2026-09-23 third current-main exploratory probe (non-qualifying)

Product base `006620e5`; pushed replay tip `a6c23bee`. Exactly one additional
`-Ending clean -Repeat 1` run was made under the serialized Godot lease. The
semantic wheel input succeeded and made part of the bottom button row intersect
the run-menu viewport. The bridge then published **Skip Lessons** even though
only 23 of its 52 pixels were inside the clip and its label and center remained
offscreen. The semantic click reported acceptance but did not open the visible
confirmation, so the replay stopped fail-closed after six counted actions.

This is a harness rendered-reachability finding, not a product placement,
ending, goal-clarity, or economy finding. The bridge now derives an unambiguous
`fully_visible` signal by comparing each button's full global rectangle with
its clipped visible rectangle, rechecks that signal before clicking, and lets
the route continue bounded scrolling until the named run-menu target is fully
visible. Missing, false, non-boolean, and ambiguous signals fail closed in the
engine-free hostile contract. A later serialized live probe must prove the
correction; no additional engine run was consumed.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-main-006620e5-probe3/20260923-103641-220-18380/run-01/summary.json`
  (SHA-256 `AF3293A2F0499FE1FCC9A2599E6C116C6F83B4020DC5387BD1464854B35EB6A1`).
- Public trace, six counted actions:
  `.tmp/rw06_2/exploratory/clean-main-006620e5-probe3/20260923-103641-220-18380/run-01/public_trace.ndjson`
  (SHA-256 `2483B5C1943CC4F596855198040B24A59ECE2EDDCB8D00ACD1E8D25212CC8F7C`).
- Post-click screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-18380-1-3adb39135e/0011.png`
  (SHA-256 `D0B1B49E5D95D1DE7056FF95DBFE928DEE0603A30DC57C5E904AD67DDE1C5591`).
- Exact owned process exited, stderr was empty, and zero Godot processes
  remained before the lease was released.

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
