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

## 2026-09-23 fourth current-main exploratory probe (non-qualifying)

Product base `d7d09f6a`; pushed replay tip `e52cd0f8`. Exactly one additional
`-Ending clean -Repeat 1` run was made under the serialized Godot lease. The
full-visibility policy worked: two wheel steps brought all 52 pixels and the
label of **Skip Lessons** inside the run-menu viewport. The semantic click then
reported acceptance and visibly hovered the button, but no confirmation opened,
so the replay stopped fail-closed after seven counted actions.

Repository-native UI route helpers emit a matching `pressed = false` wheel
event before later input; the replay bridge emitted only the press. This is a
narrow harness input-lifecycle finding, not a product placement, ending,
goal-clarity, or economy finding. The bridge now mirrors that production-input
pattern by publishing the matching wheel release immediately after its press.
The source contract accepts the exact sequence and rejects five hostile
press-only, reordered, still-pressed, intervening-input, and mismatched-release
fixtures. A later serialized live probe must prove the correction.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-main-d7d09f6a-probe4/20260923-105053-444-27868/run-01/summary.json`
  (SHA-256 `E83AE7119BECECA09CE852F8C266DCBD2EB21B55DCD8A9463E057381019A844B`).
- Public trace, seven counted actions:
  `.tmp/rw06_2/exploratory/clean-main-d7d09f6a-probe4/20260923-105053-444-27868/run-01/public_trace.ndjson`
  (SHA-256 `B713C906EF6EDEC0EC2FE93E74D29792EA55125ED3A8F0E3F8C1A82C789B9378`).
- Post-click screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-27868-1-c4483ceed7/0013.png`
  (SHA-256 `AF462BFC76B7871F60881B8AE867536AC08714C6701C118F6C3EB8A9A5D05243`).
- The exact owned process exited and zero Godot processes remained. Its stderr
  preserved the generic engine warning `ObjectDB instances leaked at exit`
  (SHA-256 `7E8F5DEB3BF520C8ABB23951DEAFB0669C320CEBB4CEB6668C755C617C5FD7D3`).

## 2026-09-23 fifth current-main exploratory probe (non-qualifying)

Current-main documentation base `01a5dc32`; pushed replay tip `8d3fe210`.
Exactly one additional `-Ending clean -Repeat 1` run was made under the
serialized Godot lease. The full-visibility and matching wheel-release
corrections both worked. The route clicked the fully rendered **Skip Lessons**
control, and the screenshot visibly shows the **Skip the lessons?** confirmation
with enabled **OK** and **Cancel** controls. The replay stopped fail-closed after
seven counted actions because those two native `ConfirmationDialog` controls
were absent from the bridge's public button list.

Godot stores the dialog buttons as internal children, while the bridge's normal
tree walk intentionally visits only public children. This is a harness
reachability finding, not a product placement, ending, goal-clarity, or economy
finding. The bridge now adds a narrow whitelist for only the rendered and
enabled `tutorial_skip_dialog` OK/Cancel controls, gives them exact stable ids,
and preserves full-visibility checks. The route selects the exact dialog role
rather than generic `OK` text. Engine-free contracts accept only the two exact
controls and reject hidden, disabled, clipped, ambiguous, wrong-id, missing-
signal, and non-boolean fixtures. A later serialized probe must prove the
correction; no additional engine run was consumed.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-main-01a5dc32-probe5/20260923-110216-836-21584/run-01/summary.json`
  (SHA-256 `E0FD3B4623BB0DC43CA5D3C7B09C7C7BD6B3EBFC7807E6A741EB0450FCA9038A`).
- Public trace, seven counted actions:
  `.tmp/rw06_2/exploratory/clean-main-01a5dc32-probe5/20260923-110216-836-21584/run-01/public_trace.ndjson`
  (SHA-256 `97DFB87747EFB35FE1DE3A30B1D3CFF0EC9B38D3A2455A157438E9F4AD48B077`).
- Visible confirmation screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-21584-1-8686b09441/0013.png`
  (SHA-256 `C48696B1846D386C57306C7DC17AE5E2EED994956C7576B455F73442535CC70D`).
- Public result behind that screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-21584-1-8686b09441/0013.result.json`
  (SHA-256 `87FA77EE669F3D104EF95ED0DEEA7A776B81FBDE357B760689095D85526FF81E`).
- The exact owned process exited, stderr was empty (SHA-256
  `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`),
  and zero Godot processes remained before the lease was released.

## 2026-09-23 sixth current-tip exploratory probe (non-qualifying)

Pushed replay tip `104e4f62`. Exactly one additional `-Ending clean -Repeat 1`
run was made under the serialized Godot lease. The narrow internal-control
whitelist worked: the bridge published exactly the rendered, enabled
`tutorial_skip_dialog:ok|cancel` controls and the route selected the exact OK
role. The click command was accepted, but the dialog remained visible and the
public run stayed active in the Apartment after another 30 frames, so the run
stopped fail-closed after eight counted actions.

The OK button's rendered rectangle is in its embedded `ConfirmationDialog`
Window/Viewport coordinate space, but the generic mouse helper injected that
position into the application root Viewport. This is another narrow harness
input-routing blocker, not product placement, ending logic, goal clarity, or
economy evidence. The bridge now records the exact Viewport of each visible
button, verifies that exactly one recorded Viewport still matches the live
button, clips in that Viewport's coordinate space, and sends the same real
motion/press/release sequence through it. Ordinary root buttons retain the root
Viewport. Engine-free fixtures accept root and dialog Viewports and reject
null, wrong, and ambiguous candidates. A later serialized probe must prove the
correction.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-tip-104e4f62-probe6/20260923-112542-759-25648/run-01/summary.json`
  (SHA-256 `8CD5D6AD84C47E7B1844994222D1722B08F8FA4300FBC99F5283491413E86D4C`).
- Public trace, eight counted actions:
  `.tmp/rw06_2/exploratory/clean-tip-104e4f62-probe6/20260923-112542-759-25648/run-01/public_trace.ndjson`
  (SHA-256 `4FAD80C8F41E23913D31DB9BB53F263B6C4DD09B77893EA8DFBFE8BB72AF1310`).
- Accepted exact-OK screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-25648-1-7c24f98e36/0014.png`
  (SHA-256 `C0F337CE97E25673335783635EEE02D99E3CBA71AABD1404D8B6EC848FFD9771`).
- Public result for that screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-25648-1-7c24f98e36/0014.result.json`
  (SHA-256 `A7CD12BDFB0A6E075791427665BC5E574CA9ED2C9546ECE163988ECE08D5B55E`).
- The exact owned process exited without force and zero Godot processes
  remained before the lease was released. Its stderr preserves the generic
  engine warning `ObjectDB instances leaked at exit` (SHA-256
  `7E8F5DEB3BF520C8ABB23951DEAFB0669C320CEBB4CEB6668C755C617C5FD7D3`).

## 2026-09-23 seventh current-tip exploratory probe (non-qualifying)

Pushed replay tip `7af48369`; viewport-routing implementation `48cc7dc7`.
Exactly one additional `-Ending clean -Repeat 1` run was made under the
serialized Godot lease. The strict dialog identity and child-Window Viewport
route were both accepted, but the resulting public trace was identical to the
sixth probe: the confirmation remained visible, the tutorial run stayed active,
and the route stopped fail-closed after eight counted actions.

The live result disproved direct `push_input(..., true)` into the child Window
as the physical path for this embedded dialog. Godot composites and routes the
embedded Window through its parent Viewport. The correction now keeps the
exact dialog/button identity, translates the dialog-local point by
`Window.position`, and injects the unchanged real motion/press/release sequence
through the root embedder. Ordinary root controls retain their original point
and Viewport. Engine-free fixtures accept the exact root and translated dialog
routes and reject null, identity-mismatched, ambiguous, non-embedded, nested,
and untranslated-offset cases. This remains a harness input-routing blocker,
not product placement, ending logic, goal-clarity, or economy evidence. A later
serialized probe must prove the embedder correction.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-tip-7af48369-probe7/20260923-113929-307-21240/run-01/summary.json`
  (SHA-256 `CC9EDA352A82F91B183D28E2EB10E827A8DF56A56AC6D71EB48BC1A14EA212F3`).
- Public trace, eight counted actions:
  `.tmp/rw06_2/exploratory/clean-tip-7af48369-probe7/20260923-113929-307-21240/run-01/public_trace.ndjson`
  (SHA-256 `4FAD80C8F41E23913D31DB9BB53F263B6C4DD09B77893EA8DFBFE8BB72AF1310`).
- Accepted exact-OK screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-21240-1-9d2a6b8c18/0014.png`
  (SHA-256 `C8EBA0C1FE548D24F33D99248261182248E1ED1FA61D974EA69B6A5559082B14`).
- Public result for that screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-21240-1-9d2a6b8c18/0014.result.json`
  (SHA-256 `6F76ECF7E53322BFBD67E1C464483DE32801FD627D245B991FFDAF7E38E57496`).
- The exact owned process exited without force and zero Godot processes
  remained before the lease was released. Its stderr preserves the generic
  engine warning `ObjectDB instances leaked at exit` (SHA-256
  `7E8F5DEB3BF520C8ABB23951DEAFB0669C320CEBB4CEB6668C755C617C5FD7D3`).

## 2026-09-23 embedder correction compile launch (no gameplay probe)

Pushed replay tip `f643859d`; embedder implementation `54080a15`. The one
authorized launch exited before `ready.json` and before any gameplay action
because GDScript could not infer the type returned by
`dialog.get_parent_viewport()`. No route summary, screenshot, public trace, or
product conclusion was produced. The narrow fix explicitly annotates that
value as `Viewport`, and the source contract now requires the annotation before
another engine lease can be requested.

Evidence:

- Session:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-14848-1-0bb7d82feb/`.
- Parser stderr:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-14848-1-0bb7d82feb/godot.stderr.log`
  (SHA-256 `AF295127E0E014B1D6E36E00FBF2A3B3A50F8278D481AF6D6B0014A1A42B20E0`).
- The exact owned process exited without force and zero Godot processes
  remained before the lease was released.

## 2026-09-23 outer-launcher timeout (no gameplay probe)

Pushed replay tip `4c3b9555`; embedder annotation implementation `e4059ee6`.
The authorized launcher was mistakenly given a five-second outer shell timeout.
That parent was terminated before the engine's normal nine-second readiness
publication, so the replay driver never issued PLAY and the requested evidence
root contains no summary, public trace, or money curve. The one leased launch
was not repeated. After `ready.json` appeared, the exact owned session accepted
one graceful `quit` command with no log alert; both Godot processes exited and
the process census returned zero. This is an orchestration-only interruption,
not placement, ending logic, goal-clarity, or economy evidence.

The next launch must keep the same outer shell call alive with a long host
timeout and use a yielding wait on that still-running call. The runner's
`-TimeoutSeconds` value is only its per-bridge-command bound and is not a safe
outer process timeout. An engine-free invocation check using that exact
long-timeout/yielding parent pattern stayed attached for 7.016 seconds
(`2026-09-23T17:02:19.8831044Z` through
`2026-09-23T17:02:26.8991189Z`) and passed, exceeding the prior five-second
failure boundary without starting Godot.

Evidence:

- Session:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-16680-1-99d3462b38/`.
- Readiness record, published after the outer caller had ended:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-16680-1-99d3462b38/ready.json`
  (SHA-256 `80A742862239F59C560A6F9F983DCF4ED2C4B00849DFBF526DB8242D3059C078`).
- Graceful quit result:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-16680-1-99d3462b38/0001.result.json`
  (SHA-256 `4BD08DBB174B78F2184AB0EDD7C7BF149FBF664F2187ED26D0F75785D74EBB1B`).
- Engine stdout contains only the normal engine/renderer banner (SHA-256
  `FA2EA26AAADBCE94053905A7C805C47D0DE5FF59CD1009A25DEE2FB8B8762CC4`);
  stderr is empty (SHA-256
  `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`).

## 2026-09-23 parent-viewport runtime launch (no gameplay conclusion)

Pushed replay tip `7e522069`. The corrected long-timeout/yielding outer caller
remained attached for the full 293-second failure/cleanup cycle. The replay
again reached the rendered confirmation after seven counted actions, then its
first attempt to resolve the embedded dialog's physical route raised a runtime
error: `ConfirmationDialog` has no `get_parent_viewport()` method. No OK click
was issued and the route never left the tutorial, so this is a harness runtime
API blocker rather than placement, ending logic, goal-clarity, or economy
evidence.

The session's bounded error path issued one graceful `quit`; the exact owned
process exited without force and the process census returned zero. The
engine-free correction now requires the dialog's direct parent to be the
production application node, obtains the embedder with that parent node's
`get_viewport()`, and still requires the result to equal the application root
viewport. It preserves the exact recorded/live dialog viewport, embedded-only,
role/button/id, and translated-position checks. Two valid and eight hostile
route fixtures cover missing/wrong parents as well as null, wrong, ambiguous,
non-embedded, nested, and untranslated routes.

Evidence:

- Run summary:
  `.tmp/rw06_2/exploratory/clean-tip-7e522069-probe10/20260923-120631-649-9868/run-01/summary.json`
  (SHA-256 `205B6BE06FF7BB85FD276D0BB39866114C47031394023F963B04877228751A03`).
- Public trace, seven counted actions:
  `.tmp/rw06_2/exploratory/clean-tip-7e522069-probe10/20260923-120631-649-9868/run-01/public_trace.ndjson`
  (SHA-256 `B713C906EF6EDEC0EC2FE93E74D29792EA55125ED3A8F0E3F8C1A82C789B9378`).
- Error log:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-9868-1-6e64059196/godot.stderr.log`
  (SHA-256 `71B8317D9CA43A2736710BB5B5BA341D52DD0A5D9B214689303D4655A78E17F3`).
- Failure screenshot:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-9868-1-6e64059196/0014.png`
  (SHA-256 `3F786AEC9BFC04C9A8019048D25B2469E827C8513DE0BCC8FDBA04F76C888EA8`).
- Graceful quit result:
  `.tmp/agent_playtest/2026-09-23/rw062-clean-9868-1-6e64059196/0015.result.json`
  (SHA-256 `D2DFA9CC4F8D99557AE76AE7002619E4CB2E45DF291675A11974573DBFF97878`).

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
