# Four-agent playtest bug sweep

**Date:** 2026-09-12  
**Commit tested:** `56de66598a2bcdbc3f171f090b48c361daf35563` (`main`, detached)  
**Playtest worktree:** `D:\Projects\Beat-The-House-worktrees\agent-playtest`  
**Harness:** `tools/agent_playtest_session.gd`, `tools/agent_playtest_session.ps1`  
**Validation:** PASS — `tools/validate_project.ps1` reported “Beat the House foundation architecture validation passed.”  
**Actions played:** A 275 (`pt_a`–`pt_a4`); B 454 (`pt_b`–`pt_b9`); C 465 (`pt_c`–`pt_c9`, excluding one unprocessed command); D 402 (`pt_d`–`pt_d9`). Total: 1,596 completed actions across 31 isolated sessions.  
**Seeds:** A — `AGENTPT-A-01`, `AGENTPT-A-02-FRESH`, `AGENTPT-A-03-FRESH`, `AGENTPT-A-04-FRESH`; B — `AGENTPT-B-01` through `AGENTPT-B-09` plus per-session fresh/game suffixes; C — `PLAYTEST06-1-FASTPATH-009`, then `PLAYTEST06-2-FRESH-021` through `PLAYTEST06-9-FRESH-109`; D — `AGENTPT-D-01` through `AGENTPT-D-09-FRESH` (the five-action `pt_d5` startup retry did not reach seed entry).

## Summary

- **Game bugs:** 31 total: 2 Blocker, 12 Major, 17 Minor, 0 Polish.
- **Statuses:** 30 confirmed, 1 intermittent, 0 harness-classified game findings, 5 not bugs.
- **Look first — BUG-01:** abandoning/restarting can create a save-persistent nameless room with no exit.
- **Look first — BUG-02:** Quarter Falls can spend more than 90 seconds settling and never honor Leave.
- **Look first — BUG-03:** the first practice Pull Tabs purchase charges twice.
- **Look first — BUG-08/09:** Numbers Book purchases change money without updating the screen, and Silas can charge repeatedly.
- **Look first — BUG-11:** Video Poker wager controls deal a new hand and carry held positions forward.
- **Look first — BUG-27/31:** Blackjack labels a real loss as a push, and Vic's loan conceals the debt terms.

No product code, game data, or tests were changed. The [BUG-01–23 fix prompt](D:/Projects/Beat-The-House/docs/todo/playtest_fixes01_agent_sweep_2026-09-12_prompt.md) covers the first sweep, and the [BUG-24–31 continuation prompt](D:/Projects/Beat-The-House/docs/todo/playtest_fixes02_continuation_2026-09-12_prompt.md) covers the added findings.

An additional serialized pass (`pt_b9`, `pt_c9`, `pt_d9`) completed 75 visible-input actions without finding a distinct BUG-32. It added Scratch Ticket claim setup, merchant selling/keyboard reachability, Debt Spiral through day two, repeated sleep, Payment Calendar, lodging renewal double-click, and relaunch/Continue coverage; host memory pressure then ended two sessions without game errors, so those exits were classified as environment-only.

## Decision table

| ID | Severity | Status | Where | Bug (two sentences) | Recommended fix | Owner: confirm? | Owner: fix choice |
|---|---|---|---|---|---|---|---|
| BUG-01 | Blocker | CONFIRMED | New-run lifecycle | After an abandon/restart sequence, a new run opened in a blank “Current venue” with only Silas Crow. Save/Continue preserved the room with no exit, route, or game. | Reject an empty generated environment and rebuild the run atomically. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-02 | Blocker | CONFIRMED | Quarter Falls | Leave can remain on the coin-pusher surface for more than 90 seconds and may make the app appear hung. It should finish settlement within a fixed bound and return to the room. | Guarantee finalization at the settle tick cap and show progress. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-03 | Major | CONFIRMED | Pull Tabs | The first $2 practice ticket reduced bankroll by $4 while reporting a $2 cost. One purchase should charge exactly its displayed price. | Give one layer sole ownership of the ticket cost. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-04 | Major | CONFIRMED | Craps | Selecting a $5 chip emits an unknown `blackjack_chip` error and can leave the command stuck. Craps should use valid profile cues and remain responsive. | Replace the raw cue IDs with Craps manifest event classes. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-05 | Major | CONFIRMED | Tutorial + modal menus | Tutorial dialogue remains layered over Settings, Inventory, and Run Menu, where its choice cannot be used. Opening a modal should suspend or safely relocate the tutorial dialogue. | Suspend and restore the tutorial talk dock around modal ownership. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-06 | Major | CONFIRMED | First-night tutorial | After dismissing Pal’s dialogue, the target stayed highlighted but its instruction bubble disappeared. The instruction should remain readable until the required action. | Convert acknowledged dialogue guidance to pointer presentation. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-07 | Major | CONFIRMED | Numbers Book tutorial | Pal’s Pointer covered slip controls and its visible Skip tip activated the control underneath. A tutorial overlay must consume input before native popups. | Put a full-screen input shield above the native controls. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-08 | Major | CONFIRMED | Numbers Book slips | Writing slips reduced internal bankroll while the wallet and Result stayed unchanged. Each wager should immediately confirm and refresh the visible money state. | Publish slip resolution through the canonical result pipeline. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-09 | Major | CONFIRMED | Silas route tip | Silas’s one-time $12 tip remained enabled and charged twice while the wallet stayed stale. A one-time purchase should become unavailable and visibly report each charge. | Enforce idempotency in the model and refresh the canonical result. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-10 | Major | CONFIRMED | Punchline back room | Vic Mercer was enabled in state but absent from the room and could not be clicked. An enabled character should be rendered inside a valid hit area. | Reconcile the drawable layout with the authoritative hit registry. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-11 | Major | CONFIRMED | Video Poker | Changing denomination or lowering the bet dealt a new hand and copied old held positions. Wager controls should not deal, and a new hand should start with no holds. | Sanitize settled-hand state on wager-only commands. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-12 | Major | CONFIRMED | Corner Store items | Double-clicking Ledger Pencil bought it while the panel continued to show Instant Coffee and its Buy button. The purchased target and post-purchase display should agree. | Render the completed purchase result before applying any affinity focus. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-27 | Major | CONFIRMED | Blackjack | A losing $11 hand produced the prominent headline “PUSH +0,” while the lower summary and bankroll correctly showed the loss. The headline should report the actual round outcome. | Separate the semantic round net/headline from the settlement-transfer delta. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-31 | Major | CONFIRMED | Vic Mercer loan | Vic's loan offer hid its principal, repayment total, interest, and deadline before confirmation. Accepting visibly reported only +$25 while silently creating $28 debt due in three turns. | Show exact loan terms in the offer, confirmation, and result. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-13 | Minor | CONFIRMED | Practice games | A fresh practice game displayed a bankroll gain carried from the prior reset. New practice sessions should start without a stale gain badge. | Reset the structured HUD wallet delta at practice launch. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-14 | Minor | CONFIRMED | Dave travel results | Dave’s result text said “Came through .” with the location missing. The line should use a real previous location or a fallback sentence. | Use a placeholder-free fallback when no prior node exists. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-15 | Minor | CONFIRMED | Counter Phone | “Make the call” emits an unknown `phone_call` SFX error. The event should resolve with a cue supported by `crew_world`. | Add `phone_call` to the profile manifest with its visual counterpart. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-16 | Minor | INTERMITTENT | Counter Phone loan | After the call and loan, Result still described the prior Cashier Tip while bankroll had risen. The phone and loan outcome should replace the old result immediately. | Route the loan choice through the canonical acknowledgement result. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-17 | Minor | CONFIRMED | Game detail cards | Pull Tabs and Blackjack showed an internal travel-cue identifier as their Risk text. Risk copy should be local to the selected game and player-facing. | Stop injecting the global latest suspicion cue into every game card. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-18 | Minor | CONFIRMED | Travel Result panel | Travel summaries at Sunset Gas Casino and The Punchline clipped at the right edge. The full result should wrap or be width-aware. | Wrap the feedback label inside its fixed panel. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-19 | Minor | CONFIRMED | Run Setup | Run Setup accepted a seed but the first-night run silently used `FIRST-NIGHT-ACE-17`. The screen should warn that the required tutorial owns the seed. | Disable the seed field during the mandatory lesson and explain why. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-20 | Minor | CONFIRMED | Roulette | Rim labels extend outside the wheel and cover the venue description. Labels should stay inside the wheel’s visual region. | Move number labels inward and clip them to the wheel region. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-21 | Minor | CONFIRMED | Back-Room Poker | At the $4 minimum, enabled decrement buttons accepted clicks but did nothing. Boundary controls should be disabled or explain the limit. | Disable and restyle decrement hits at the minimum. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-22 | Minor | CONFIRMED | Inventory | Instant Coffee says its effect is spent when used, but it is a passive item with no Use control. Its behavior text should describe how its effect actually works. | Base behavior copy on active/passive capability, not `class` alone. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-23 | Minor | CONFIRMED | Settings | Keyboard focus escaped the Settings modal to a dimmed control underneath. Focus should remain trapped inside the active modal. | Add modal focus neighbors and restore prior focus on close. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-24 | Minor | CONFIRMED | Baccarat | The LEAVE control overlaps the top-right hand explainer during deal and result states. Both controls should remain readable and separately clickable. | Supply a non-overlapping Baccarat back-control rectangle. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-25 | Minor | CONFIRMED | Dave's Last Stop | The “Sit in the silence” consequence preview clips after “Keep Alley in mind. S,” hiding most of the response. The full preview should wrap or resize. | Wrap the inline detail and size its card dynamically. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-26 | Minor | CONFIRMED | Back Alley scenario | Selecting “Resolve the contested lot” repeats the same instruction twice in its detail panel. The prompt should appear only once. | Suppress the action summary when it duplicates the short description. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-28 | Minor | CONFIRMED | Bar Dice | The bottom guidance line clips after “SETTLE compares what y” at 1280×720. The full control guidance should remain visible. | Wrap, fit, or shorten the prompt inside the console bounds. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-29 | Minor | CONFIRMED | Roulette | After a completed wager, CLEAR removed the retained layout but left REBET disabled. REBET should restore the previous round's cleared layout. | Refresh the session rebet cache from settled bets and avoid stale empty shadowing. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |
| BUG-30 | Minor | CONFIRMED | Counter Phone | The family-loan dialogue nameplate displays “Unknown” instead of the authored “Unknown Caller.” Chained events should preserve the full speaker name. | Hydrate the target event's speaker before enqueue/display. | ☐ Yes ☐ No ☐ Not a bug | ☐ A ☐ B ☐ C ☐ Defer |

## Bug details

### BUG-01: New run can start in a permanent empty room

- **Reported by pt_d2:** “Seed `AGENTPT-D-02-FRESH` starts in a blank “Current venue” containing only Silas Crow, with no game, Leave control, or route. Save/Main Menu/Continue preserves the softlock, and the end report identifies the location as “Unknown room.””
- **Verification:** CONFIRMED. The player-input sequence was tutorial skip → abandon → New Run → Main Menu → start the typed seed; actions 23–25 showed only `numbers:silas`, actions 35–38 preserved it through Save/Continue, and the abandoned report still said Unknown room. [Evidence PNG](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d2/0051.png), [state after start](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d2/0025.result.json).
- **Likely cause:** `foundation_main.gd:785-870` calls `generator.next_environment(run_state)` but ignores the returned environment and does not fail or retry if `current_environment` remains empty; confidence medium-high. The stale Silas object indicates presentation is allowed to continue after that failed boundary.
- **A — Recommended (M, medium risk):** make new-run creation transactional, validate a nonempty environment with at least one safe exit, and retry/fail back to setup before autosave.
- **B (S, medium risk):** check only for an empty environment after generation and display an error; safer but leaves the generator lifecycle defect unresolved.
- **C (M, high risk):** recreate the `RunGenerator` for every run; broader state isolation, but it may change deterministic generation.

### BUG-02: Quarter Falls exit settlement does not finish

- **Reported by pt_b:** “After dropping a quarter, using the slam nudge, leaving Quarter Falls, and opening the Run Menu, the next Main Menu action timed out while the game process was not responding; this happened once. The menu should remain responsive and return to the main screen after coin-pusher play.”
- **Reported by pt_a2:** “The visible Leave control in Quarter Falls accepted repeated clicks but kept the player on the Vault Drop game surface. Leave should return the player to the Game Library or previous screen.”
- **Reported by pt_c3:** “Clicking The Vault Drop’s visible LEAVE button twice showed its BACK hover state but left the player trapped on the game surface. The LEAVE button should return to the Corner Store on the first click.”
- **Verification:** CONFIRMED in two fresh replacement sessions. `pt_a2` actions 33–41 remained on the surface for 96 seconds, while `pt_c3` reproduced the no-exit state; a lighter root smoke did not trigger it. [A evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a2/0041.result.json), [C evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c3/0025.png).
- **Likely cause:** `foundation_main.gd:1023-1078` waits for chunked exit settlement; `coin_pusher.gd:862-899` removes the job only when `done`, while a recovered shim can clear completion again. Confidence medium-high.
- **A — Recommended (M, medium risk):** force a final stable projection and exit at `MAX_SETTLE_TICKS`, with an on-screen Leaving status.
- **B (S, high risk):** skip exit settlement entirely; responsive, but may drop legitimately falling coins.
- **C (L, medium risk):** move settlement to a bounded background simulation and leave the visible surface immediately.

### BUG-03: First Pull Tabs purchase charges twice

- **Reported by pt_b:** “On the first Pull Tabs purchase, a $2 Moonlight Jars ticket reduced the fresh $100000 bankroll to $99996 even though the result reported only a $2 cost. The purchase should have reduced the balance by $2, as a later $1 ticket correctly did.”
- **Verification:** CONFIRMED with the same seed and trace in `verify_b01`: bankroll moved 100000 → 99996, while result delta was -2 and two chips were created. [Original evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b/0019.result.json).
- **Likely cause:** `foundation_main.gd:11733-11772` funds the Grand Casino wager before resolution, then `pull_tabs.gd:844-940` returns another `bankroll_delta = -price`. Confidence high.
- **A — Recommended (S, low risk):** make Pull Tabs return a net delta that excludes any pre-funded cost.
- **B (M, medium risk):** move all practice ticket purchasing into the shared wager currency pipeline.

### BUG-04: Craps denomination uses an invalid SFX cue

- **Reported by pt_b:** “Selecting the $5 chip in Craps produced an error for an unknown `blackjack_chip` sound event on the craps table and left the session command hanging; this reproduced after a restart. The Craps chip control should select the denomination without a script error or stuck command.”
- **Verification:** CONFIRMED in `verify_b02` with the same seed and seven-command trace. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b/0101.result.json).
- **Likely cause:** `craps.gd:408-423` emits `blackjack_chip` and `roulette_chip_sweep`, while the `craps_table` profile in `surface_sfx_manifest.json` exposes `chip_place`/`chip_collect`; `sfx_player.gd:1917` rejects the mismatch. Confidence high.
- **A — Recommended (S, low risk):** emit the profile’s `chip_place` and `chip_collect` event classes.
- **B (M, medium risk):** add cross-game aliases to the manifest; compatible, but preserves misleading module names.

### BUG-05: Tutorial dialogue remains above modal menus

- **Reported by pt_d:** “Pal’s tutorial dialogue remains layered above Settings, Inventory, and Run Menu. In Inventory, its visible choice is unusable until the menu closes.”
- **Verification:** CONFIRMED by the visible overlap and blocked choice in actions 11–14, with the same behavior across three modal owners. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d/0013.png).
- **Likely cause:** `foundation_main.gd:6564-6578` and `15740-15764` move modals forward and call `_sync_coach_focus_visibility`, but `19839-19849` disables only the coach focus visual, not the tutorial talk dock/dialogue. Confidence high.
- **A — Recommended (M, low risk):** suspend tutorial dialogue while a modal owns input, then restore it on close.
- **B (S, medium risk):** hide the talk dock visually while modals are open; simple, but must preserve focus and queued dialogue correctly.

### BUG-06: First-night target loses its instruction

- **Reported by pt_a:** “After Pal's opening choice was dismissed in the Apartment and Corner Store, the highlighted tutorial target remained but the coach instruction bubble was not drawn. The coach instruction should remain visible and readable while directing a new player to the highlighted object.”
- **Verification:** CONFIRMED in `verify_a`; the snapshot said the coach was visible with “Pick up the highlighted X-ray Glasses,” but the PNG had only the highlight. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a/0020.png).
- **Likely cause:** `coach_overlay.gd:583-610` hides the panel whenever delivery remains `dialogue`; after acknowledgement, the lesson remains active but no visible instruction path replaces it. Confidence high.
- **A — Recommended (S, low risk):** after dialogue acknowledgement, present the same active lesson as a pointer until completion.
- **B (M, medium risk):** keep the dialogue delivery open until the anchored action, which is clearer but more intrusive.

### BUG-07: Tutorial overlay clicks through to Numbers controls

- **Reported by pt_c:** “In the Numbers Book, Pal’s Pointer covered the slip controls and clicking its visible “Skip tip” button opened or closed the underlying Straight/Box menu. The button should dismiss the tip without activating covered controls.”
- **Verification:** CONFIRMED from the captured open native popup directly beneath the pointer after the skip click. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0056.png).
- **Likely cause:** `coach_overlay.gd:535-610` stops input only in its panel rectangle; the native `OptionButton` popup/focus chain can receive the same input beneath the overlay. Confidence medium-high.
- **A — Recommended (M, medium risk):** use a topmost full-screen input shield while coach actions are shown, forwarding only allowed tutorial actions.
- **B (S, medium risk):** reposition the coach away from every native control; less robust across scale and localization.

### BUG-08: Numbers slips do not update visible money

- **Reported by pt_c:** “Writing two $1 numbers slips reduced the internal bankroll from $121 to $119, but the modal gave no confirmation and the visible wallet and Result remained at the previous $121 state. Each slip should visibly confirm the wager and update the wallet and Result immediately.”
- **Verification:** CONFIRMED by action-state deltas and the unchanged wallet/result in the same automatic look. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0062.result.json).
- **Likely cause:** `foundation_main.gd:18533-18558` mutates/autosaves and rerenders the Numbers surface but never publishes the outcome into the canonical recent-result acknowledgement used by the HUD. Confidence high.
- **A — Recommended (M, low risk):** resolve slips through the standard result pipeline and refresh the structured HUD.
- **B (S, medium risk):** manually update wallet and message fields in the Numbers handler; smaller but duplicates result logic.

### BUG-09: Silas tip can be bought repeatedly

- **Reported by pt_c:** “Silas Crow’s $12 quiet-route tip could be bought twice because the same purchase button remained active, dropping the internal bankroll from $111 to $87 while the screen still showed $111. A one-time route tip should disable after purchase and visibly show the charge.”
- **Verification:** CONFIRMED again by `pt_d2` actions 32–33 and 40–48, in addition to the original two charges. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0078.result.json).
- **Likely cause:** `numbers_model.gd:448-455` charges before setting an already-true knowledge flag and has no duplicate guard; `foundation_main.gd:18468-18473` keeps building an enabled button, and `18533-18558` misses canonical HUD acknowledgement. Confidence high.
- **A — Recommended (M, low risk):** reject repeat purchase in the model, disable/hide the button in the view, and publish the first result canonically.
- **B (S, medium risk):** guard only in the UI; fast, but non-UI callers remain unsafe.

### BUG-10: Vic Mercer is not visible or hittable

- **Reported by pt_c:** “In The Punchline back room, enabled interactive Vic Mercer was absent from the rendered room and selecting him twice reported that his hit area was not hittable. Vic should be visible and selectable within the screen.”
- **Verification:** CONFIRMED: the observable model lists Vic as enabled/interactive, while two exact visible-input attempts found no rendered hit authority and the PNG has no Vic. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0115.result.json).
- **Likely cause:** `environment_interaction_view_model.gd:141-203,470-503` accepts the normalized character rect, but `pixel_scene_canvas.gd:2490-2533,2777-2830` does not produce a matching drawable/hit entry. Confidence medium.
- **A — Recommended (M, medium risk):** validate every interactive layout record against both draw and hit registries, with a safe fallback placement.
- **B (S, high risk):** move Vic’s authored rect; likely fixes this room but not the systemic mismatch.

### BUG-11: Video Poker wager controls deal and retain holds

- **Reported by pt_a3:** “Changing the denomination or lowering the bet after a Video Poker result immediately dealt a new hand and copied the previous hand's held-card positions onto the new cards. Those controls should adjust the next wager without dealing, and every new hand should begin with no cards held.”
- **Verification:** CONFIRMED across repeated denomination/bet changes in actions 18–21. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a3/0021.result.json).
- **Likely cause:** `video_poker.gd:806-840` normalizes and preserves `hand_active`/`holds` for bet commands, while only the explicit deal path clears holds; `foundation_main.gd:3203-3210` retains that surface state. Confidence high.
- **A — Recommended (S, low risk):** make wager-only commands update only denomination/bet and clear settled-hand transient fields.
- **B (M, medium risk):** model betting and dealing as explicit separate surface states; cleaner, but broader.

### BUG-12: Double-click purchase leaves the wrong item card

- **Reported by pt_d:** “Double-clicking Ledger Pencil while Instant Coffee is inspected purchases the pencil for $14. The screen incorrectly keeps showing Instant Coffee’s card and Buy button after the transaction.”
- **Verification:** CONFIRMED from the visible $14 transaction and unchanged Instant Coffee panel after an exact Ledger Pencil double-click. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d/0030.png).
- **Likely cause:** `foundation_main.gd:13190-13214` selects and applies an item within one double-click route; `_apply_item_offer_after_input_guard` at `5536-5555` clears selection and applies post-purchase affinity without first stabilizing the purchased-result projection. Confidence medium.
- **A — Recommended (M, medium risk):** show the purchased item’s result and remove/disable its offer before any affinity refocus.
- **B (S, low risk):** require explicit Buy after selection, eliminating double-click purchase; changes interaction design.

### BUG-13: Practice launch retains an old wallet delta

- **Reported by pt_b:** “Starting a fresh practice game repeatedly showed a green bankroll gain from the previous practice reset, such as `$100000 +15` on the Bar Dice entry screen. A new practice session should start at $100000 without presenting the reset as winnings in the newly opened game.”
- **Verification:** CONFIRMED in `verify_b03`; a new Slot practice session showed bankroll 100000 with a stale `+5` badge. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b/0043.png).
- **Likely cause:** normal run startup resets the wallet delta at `foundation_main.gd:785-794`, but the Games library launcher at `16840-16885` creates a practice state without calling `foundation_hud_bar.gd:56-64`. Confidence high.
- **A — Recommended (S, low risk):** call `structured_hud.reset_wallet_delta()` before rendering each practice launch.

### BUG-14: Dave result omits his prior location

- **Reported by pt_c:** “Dave’s Last Stop and Second Truth results both displayed “Came through .” with the location missing. The sentence should include the location Dave came through.”
- **Verification:** CONFIRMED in both result records at action 25. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0025.result.json).
- **Likely cause:** `characters.json:967-969` requires `{previous_name}`, but `town_network.gd:289-323` supplies a blank previous node for itinerary index zero and blindly replaces it. Confidence high.
- **A — Recommended (S, low risk):** choose a placeholder-free fallback line when `previous_node_id` is empty.
- **B (S, low risk):** seed Dave with an explicit origin; more authored flavor, but a design/content choice.

### BUG-15: Counter Phone uses an unsupported SFX cue

- **Reported by pt_c:** “Making the Counter Phone’s brother-in-law call logged `ERROR: Unknown surface SFX event class phone_call for profile crew_world` with a script backtrace. The phone call should resolve without a game error.”
- **Reported by pt_d:** “Double-clicking “Make the call” continues the event but emits an unknown `phone_call` surface-SFX error. The stack reaches `sfx_player.gd:1917` through event-choice resolution.”
- **Verification:** CONFIRMED in `verify_c1` and independently by D. [C log](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/godot.stderr.log), [D result](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d/0038.result.json).
- **Likely cause:** `events.json:2609-2641` emits `phone_call`; the `crew_world` profile in `surface_sfx_manifest.json` omits that class, so `sfx_player.gd:1917` errors. Confidence high.
- **A — Recommended (S, low risk):** add a `phone_call` mapping and matching visual-event contract to `crew_world`.
- **B (S, low risk):** replace it with an existing generic cue; less work, less distinct feedback.

### BUG-16: Phone loan leaves the prior result on screen

- **Reported by pt_c:** “After the Counter Phone event and family loan, the visible Result panel remained on “Used Cashier Tip. $-4” even though the bankroll rose from $91 to $121. The panel should immediately show the phone and loan outcome.”
- **Verification:** INTERMITTENT. The original screenshot/state proves the stale result and $91 → $121 transition, but two root replays reached the call/loan branch without completing the final choice because the first-tutorial transition delayed/replaced its button. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c/0048.png).
- **Likely cause:** the event/loan choice mutates bankroll through its dialogue path without replacing `last_hook_result`, leaving the Cashier Tip acknowledgement authoritative. Confidence medium-high.
- **A — Recommended (M, medium risk):** publish the loan outcome through the same canonical result/acknowledgement path as other money actions.
- **B (S, medium risk):** directly clear the stale hook result and set the loan message; smaller, but duplicates presentation policy.

### BUG-17: Game cards show an internal travel risk identifier

- **Reported by pt_a:** “The Pull Tabs and Blackjack detail cards displayed internal-looking travel labels as their Risk text instead of information about the selected game. Each game's Risk text should describe that game in player-facing terms.”
- **Reported by pt_c2:** “The Pull Tabs panel displayed the internal-sounding risk text “Gas Station Casino Confirm Travel notices you,” even after travel had completed. The risk line should identify the actual in-room observer or use natural player-facing wording.”
- **Verification:** CONFIRMED independently in two seeds and two games. [A evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a/0068.png), [C evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c2/0048.png).
- **Likely cause:** `environment_interaction_controller.gd:113` injects global `_risk_cue_text()` into each object; `foundation_main.gd:15233-15250,17886-17903` turns raw suspicion IDs into title-cased labels. Confidence high.
- **A — Recommended (S, low risk):** use game-local risk copy on game cards and render travel suspicion separately.
- **B (M, low risk):** add authored player-facing copy for every suspicion cue, useful elsewhere but broader.

### BUG-18: Travel Result text clips

- **Reported by pt_a:** “After traveling to Sunset Gas Casino and The Punchline, the Result panel truncated each travel summary at the right edge. The full result should wrap or fit inside the panel.”
- **Verification:** CONFIRMED at both destinations; the visible sentence runs beyond the fixed feedback panel. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a/0065.png).
- **Likely cause:** `foundation_main.gd:94-96,14994-15015` uses a 340×46 single-line label and truncates only by character count, not rendered width. Confidence high.
- **A — Recommended (S, low risk):** enable wrapping and let the panel grow to two lines.
- **B (S, low risk):** ellipsize by measured pixel width with the full text in a tooltip; more compact, less immediately readable.

### BUG-19: Mandatory tutorial silently replaces the typed seed

- **Reported by pt_a:** “Run Setup accepted AGENTPT-A-01, but the active run identified itself as FIRST-NIGHT-ACE-17 after starting. The new run should use the entered seed or clearly warn that the first lesson will replace it.”
- **Verification:** CONFIRMED in `verify_a`; typed `AGENTPT-A-01` became status seed `FIRST-NIGHT-ACE-17`. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a/0141.png).
- **Likely cause:** `_on_start_pressed` at `foundation_main.gd:15472-15481` calls `start_tutorial_run` for fresh profiles, and `15515-15524` hardcodes the tutorial seed. Confidence high.
- **A — Recommended (S, low risk):** disable the seed field during the required first-night lesson and label the deterministic seed; this is a small UX/design decision.
- **B (M, medium risk):** honor the typed seed in the tutorial challenge; preserves user expectation but may weaken deterministic lesson scripting.

### BUG-20: Roulette labels overlap venue text

- **Reported by pt_a4:** “During Roulette spins and results, the numbered rim labels extend outside the wheel and cover the table's venue description. The labels should remain within the wheel area without obscuring other Roulette information.”
- **Verification:** CONFIRMED during spin and result states at actions 18 and 21. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_a4/0018.png).
- **Likely cause:** `roulette.gd:2674-2719` draws labels at `WHEEL_RADIUS + 17` with no clipping. Confidence high.
- **A — Recommended (S, low risk):** move labels inward and clip drawing to the wheel rectangle.

### BUG-21: Minimum raise controls remain enabled

- **Reported by pt_b2:** “At the $4 minimum in Back-Room Poker's Choose Raise panel, both enabled decrement buttons accepted clicks but left the amount unchanged with no feedback. Those controls should be disabled at the boundary or explain why the raise cannot be reduced.”
- **Verification:** CONFIRMED in `verify_b2`; `-1` and `-5` repeatedly left the target at $4 and stayed enabled. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b2/0031.result.json).
- **Likely cause:** `crew_draw_poker.gd:333-345` clamps at the minimum but reports the action handled; its renderer at `2284-2308` always draws/registers decrement hits. Confidence high.
- **A — Recommended (S, low risk):** disable decrement buttons/hits at minimum and give them disabled styling.
- **B (S, low risk):** leave them enabled but show “Minimum raise”; more feedback, still a dead control.

### BUG-22: Passive Instant Coffee is described as usable

- **Reported by pt_c4:** “Purchased Instant Coffee is labeled “Consumable — its effect is spent when used,” but its Actions section has no Use control and the top control remains “Use Item: Empty.” The item should provide a clear way to consume it.”
- **Verification:** CONFIRMED as a copy/contract defect. `items.json` deliberately places Instant Coffee in `universal_passive_items` with no `active_item`, so the absence of Use is correct but the displayed promise is not. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c4/0021.png).
- **Likely cause:** `run_action_service.gd:516-527` maps every `class = consumable` item to “spent when used,” while active capability is separately determined; Instant Coffee at `items.json:64-84` is passive. Confidence high.
- **A — Recommended (S, low risk):** make behavior summary say passive when `active_item` is false, regardless of class.
- **B (M, medium risk):** turn Instant Coffee into a true active consumable; this changes item design and is the owner’s call.

### BUG-23: Settings does not trap keyboard focus

- **Reported by pt_d:** “Keyboard focus escapes the Settings modal while tabbing. The underlying dimmed “Use Item: Empty” button receives a visible focus ring.”
- **Verification:** CONFIRMED from the focused underlying HUD button while Settings remained visible. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d/0068.png).
- **Likely cause:** settings is shown at `foundation_main.gd:15740-15764`, but no focus-neighbor loop or underlying focus-mode suspension is installed. Confidence high.
- **A — Recommended (S, low risk):** trap Tab/Shift-Tab within Settings and restore the previous owner on close.
- **B (M, low risk):** temporarily disable focus on the entire underlying screen; stronger modal isolation, more state to restore.

### BUG-24: Baccarat LEAVE overlaps the hand explainer

- **Observed in pt_b3:** the visual review of an otherwise rejected retained-wager report exposed the LEAVE control drawn through the top-right hand explainer during both deal and result states.
- **Verification:** CONFIRMED in two captured states. [Deal evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b3/0013.png), [result evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b3/0025.png).
- **Likely cause:** `game_surface_canvas.gd:1944-1961` defaults the back control to `Rect2(776, 22, 86, 34)`, while `baccarat.gd:3266-3278` draws the explainer in `Rect2(684, 14, 192, 58)`; the rectangles overlap. Confidence high.
- **A — Recommended (S, low risk):** have Baccarat supply a non-overlapping `surface_back_rect`.
- **B (M, low risk):** make the shared surface automatically reserve the back-control region when laying out game content; more systemic, but broader.

### BUG-25: Dave consequence preview is clipped

- **Reported by pt_c5:** “At Corner Store, Dave’s Last Stop’s ‘Sit in the silence’ consequence preview is clipped after ‘Keep Alley in mind. S,’ hiding most of the response text. The panel should wrap or resize so the full consequence preview is readable.”
- **Verification:** CONFIRMED. The structured detail contains the full response through “Bus knew the turns better than the driver,” while the image shows only the clipped prefix. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c5/0063.png).
- **Likely cause:** `pixel_scene_canvas.gd:3812-3824,3923-3947` reserves a fixed-height detail row, and `2637-2652` renders it with the single-line truncating helper at `3737-3755`. Confidence high.
- **A — Recommended (M, low risk):** wrap the inline detail and size its card/detail region to the resulting line count.
- **B (S, low risk):** shorten this authored response to fit; fixes one case but leaves other long consequences vulnerable.

### BUG-26: Scenario instruction appears twice

- **Reported by pt_d4:** “In Back Alley, the ‘Resolve the contested lot’ panel repeats the same instruction twice whenever selected. The instruction should appear only once above the action button.”
- **Verification:** CONFIRMED; the automatic snapshot also contains the same sentence in two selected-info lines. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d4/0021.png).
- **Likely cause:** `scenario_semantic_view_model.gd:235,244` copies the interaction prompt into both `short_description` and `action_summary`; `pixel_scene_canvas.gd:3594-3627` renders both. Confidence high.
- **A — Recommended (S, low risk):** omit the action-summary line when it equals the short description.
- **B (S, low risk):** stop populating one of the two fields for scenario objects; simpler, but may remove useful distinct summaries elsewhere.

### BUG-27: Blackjack loss headline says PUSH

- **Reported by pt_b5:** “After I stood on 10 against the dealer and lost $11 to dealer 17, the Blackjack table’s prominent result banner said ‘PUSH +0’ while its lower summary correctly said ‘H1 10 loses to 17 (-11)’ and the bankroll remained down $11. A losing hand should be labeled as a loss with -$11, not as a push with zero.”
- **Verification:** CONFIRMED. The result records `main_delta = -11` and a losing hand, but `last_result.bankroll_delta = 0`, which drives the incorrect headline. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b5/0026.png).
- **Likely cause:** `blackjack.gd:2208-2210` records only the settlement transfer after the wager was already debited, while `8046-8068` and `3820-3842` treat that zero transfer as the semantic round result. Confidence high.
- **A — Recommended (S, medium risk):** preserve a separate semantic round-net field and build the headline from it, leaving settlement accounting unchanged.
- **B (M, medium risk):** redefine the result delta everywhere as full round net; cleaner, but touches more consumers and needs accounting regression tests.

### BUG-28: Bar Dice guidance clips at 1280×720

- **Reported by pt_b6:** “During a Bar Dice hand at 1280×720, the guidance line along the bottom is cut off after ‘SETTLE compares what y,’ leaving the rest of the instruction unreadable. The full control guidance should remain visible within the game panel.”
- **Verification:** CONFIRMED at the required playtest resolution. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b6/0019.png).
- **Likely cause:** `bar_dice.gd:2568` supplies a long prompt and `3313-3314` draws a 74-character prefix at x=452 without measuring, fitting, or wrapping to the remaining width. Confidence high.
- **A — Recommended (S, low risk):** fit or wrap the guidance within the console rectangle.
- **B (S, low risk):** replace it with shorter copy; fastest, but localization or future text can regress it.

### BUG-29: Roulette REBET loses the settled layout

- **Reported by pt_b7:** “After a completed Roulette wager, pressing CLEAR removed the retained layout but left REBET disabled, and the same behavior occurred after a second completed wager. REBET should restore the previous round’s layout once the current chips have been cleared.”
- **Verification:** CONFIRMED across two completed wagers in the same fresh session. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_b7/0013.png).
- **Likely cause:** `roulette.gd:3529-3530` updates table `last_bets`, but session normalization at `3455-3471` preserves an explicit pre-settlement empty `roulette_rebet` that shadows it in the UI at `357-369,510`; CLEAR itself does not erase rebet at `2226-2233`. Confidence high.
- **A — Recommended (S, low risk):** refresh `roulette_rebet` from the settled layout and do not let a stale explicit empty array shadow `table.last_bets`.
- **B (M, low risk):** make one model field the sole authority for current bets and rebet history; broader cleanup with fewer synchronization paths.

### BUG-30: Chained phone event loses “Caller” name

- **Reported by pt_c7:** “After choosing Make the call at Corner Store’s Counter Phone, the family-loan dialogue nameplate reads only ‘Unknown,’ leaving out ‘Caller’ from the speaker name. The nameplate should display the full ‘Unknown Caller’ label.”
- **Verification:** CONFIRMED. `events.json:2682-2699` authors the speaker as “Unknown Caller,” while the real chained path renders “Unknown.” [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_c7/0021.png).
- **Likely cause:** `event_module.gd:568-596` enqueues the chained target with only hook overrides, bypassing the speaker hydration used by `foundation_main.gd:4382-4394`; `talk_dock.gd:1125-1133` then falls back to “Unknown.” Confidence high.
- **A — Recommended (M, low risk):** hydrate the chained target event's authored speaker and entry overrides before enqueue.
- **B (S, medium risk):** special-case the talk dock fallback for this event; narrow and fragile.

### BUG-31: Vic loan hides its terms

- **Reported by pt_d7:** “Vic Mercer’s loan offer and confirmation display no principal, repayment balance, interest rate, or deadline. Confirming gives $25 while silently creating a $28 debt due in three turns, with the visible Result reporting only +$25 / Heat +1.”
- **Verification:** CONFIRMED. The choice and confirmation expose only generic dialogue, while the post-action state contains a $28 balance, three-turn deadline, and 10% rate. [Evidence](D:/Projects/Beat-The-House-worktrees/agent-playtest/.tmp/agent_playtest/2026-09-12/pt_d7/0020.png).
- **Likely cause:** `foundation_main.gd:13745-13811` builds a generic borrow consequence despite exact terms in `lenders.json:17-46`; `_refresh_talk_dock` at `4630-4643` then replaces the option summary with a randomized voice line. Confidence high.
- **A — Recommended (S/M, low risk):** include principal, total repayment, rate, and deadline in the offer/confirmation, preserve them beside the voice line, and mention the created debt in Result.
- **B (M, medium risk):** add a reusable structured loan-terms panel for every lender; more consistent, but a broader UI change.
- **Design note:** the fix discloses existing mechanics; changing the 10%/three-turn terms themselves remains an owner balance decision.

## Not bugs / known issues

- **pt_a-02 — NOT A BUG:** “The Counter Phone and Parking Lot Tip detail cards drew their flavor text through the action button and lower card edge. The full flavor text should fit inside the card without overlapping the action button.” Inspection of `pt_a/0050.png` showed the inline detail row below the button and inside the translucent card; `pixel_scene_canvas.gd:2577-2640,3894-3945,4231-4255` explicitly reserves that area.
- **pt_b3-01 — NOT A BUG:** leaving and re-entering Baccarat retained a working Player Pair wager and the timed table dealt again. Continuous timed Baccarat deliberately retains working bets (`check_table_games.gd:2518,2697-2700`; `baccarat.gd:539-567`) and visibly offers Sit Out; the separate overlap exposed by its screenshots is BUG-24.
- **pt_b4-01 — NOT A BUG:** Slot autoplay continued after LEAVE. Background autoplay is an explicit tested feature (`compile_run_menu_and_game_flows.gd:2642-2688`), and the room card visibly reported `AUTO` status.
- **pt_d3-01 — NOT A BUG:** Slot autoplay continued while a debt-collection TalkDock was open. The simulation contract intentionally keeps autonomous systems moving during natural dialogue (`foundation_main.gd:12189-12200`); pausing it would be a design change.
- **pt_d6-01 — NOT A BUG:** Load restored the state after later actions instead of the moment of a prior manual Save. The game intentionally has one Resume Slot and autosaves it after actions (`foundation_main.gd:6306-6388,6586-6598,17059-17085`), matching the visible “Save overwrites this slot; Load replaces this run” copy.
- Placeholder/shared object glyphs, provisional Punchline art, and unjudged balance/voice remain the known limitations from `docs/plans/0.6_playtest_handoff.md`; agents were instructed not to report them.

## Harness issues

The reusable harness passed its full visible-input smoke: menu → typed seeded run → Apartment/Corner Store → object → Quarter Falls round → Save → quit/relaunch → Continue restored the room, game, machine state, and $79 bankroll. A separate empty session correctly showed PLAY instead of CONTINUE, proving persistence isolation.

Harness defects found and fixed before/during the sweep:

- Windows PowerShell 5 did not support `utf8NoBOM`; switched command/result writing to supported UTF-8.
- Command-number formatting could receive a non-integer aggregate; cast before `{0:D4}`.
- Post-click inspection accessed buttons that freed themselves; snapshot stable properties before input.
- Game-action parsing mishandled labels containing spaces and optional indexes; resolved against the rendered action catalog.
- Relaunch numbering initially restarted at 1; now resumes after the highest command file.
- Clicking the app close box exits before a result can be written; all formal sessions use `quit`.
- Nested isolated persistence paths were not created before the game tried to save settings/profile data; the harness now creates their parent directories at boot. A live Settings toggle/Apply check wrote a valid isolated `settings.json` with no alerts.
- Reported hit rectangles could extend outside clipped ancestors; clickable/button/text-field geometry is now intersected with the viewport and every clipping ancestor before targeting.
- During concurrent large captures, result files could be observed while still empty or partially written. The wrapper now waits for a nonempty, parseable JSON document instead of trusting file existence; the `pt_d5` startup pass was retried and the live large-result check passed.
- During the final `pt_b9`/`pt_c9`/`pt_d9` pass, free physical memory fell below 250 MB while unrelated Godot workers were active. Two playtest sessions disappeared with empty stderr and one PowerShell capture raised `System.OutOfMemoryException`; the same player actions succeeded after relaunch, so these were treated as host-resource failures, concurrency was reduced, and all new launches were stopped when free memory remained unsafe.
- Four Godot pairs could not reliably start simultaneously on this host; with four agent slots including the coordinator, three sessions ran concurrently and the fourth began as soon as one slot/process freed. No save paths were shared.

No reported game finding was classified as a harness error.

The original full project validation passed before playtesting. After the continuation, the harness compiled and ran in a live session, its PowerShell wrapper parsed cleanly, the environment-grounding check passed (21 maps, 18 archetypes, 10 classes), and the foundation shard suite passed; two additional full-wrapper invocations produced no failure output but exceeded two- and five-minute command limits, so they are recorded as timeouts rather than fresh full passes.

## Coverage

- **A / new player (275 actions):** main menu, Run Setup and typed seeds, mandatory first-night tutorial, settings, early rooms/objects, games, travel, save/Continue; fresh replacements covered Quarter Falls exit, Video Poker, and Roulette.
- **B / games (454 actions):** Games library plus in-run play across slots, blackjack, baccarat, roulette, Video Poker, Craps, street Craps, Bar Dice, Pull Tabs, scratch tickets, all coin-pusher machines, Back-Room Hold’em, and showdown; continuation sessions added timed Baccarat/re-entry, off-screen Slot autoplay, Blackjack settlement headlines, Bar Dice guidance, Roulette rebet, Pull Tabs redemption, Quarter Falls settlement, and a fresh Scratch Ticket buy/reveal/file path.
- **C / world and story (465 actions):** travel/map, shops, events, Dave, Counter Phone/family loan, Numbers Book/Silas, lenders, Crew paths, and The Punchline through its back room; continuation sessions added Dave consequence previews, rent lead-up through day seven, chained phone-event identity, debt tutorial, merchant purchases/selling with keyboard navigation, inventory, underground-route leads, and relaunch/Continue.
- **D / long run and edges (402 actions):** rapid/double clicks, modal/settings focus, purchases, save/menu paths, event audio, reduced-motion checks, tutorial skip, abandon/restart, Save/Continue, and terminal report persistence; continuation sessions added autoplay under dialogue, Back Alley scenario presentation, autosave/load behavior, Vic's loan contract, street-shooter state, route travel, The Punchline open-mic actions, and Debt Spiral through day two with lodging renewal double-click verified as a single charge.
- **Blind spots:** no agent completed an organic multi-night Grand Casino victory or a natural bankruptcy/debt terminal run; end-report coverage used Abandon. Mid-animation saves were sampled but not exhaustively repeated for every game, and controller/touch input was not tested.

All screenshots, JSON snapshots, notes, commands, and logs remain under `D:\Projects\Beat-The-House-worktrees\agent-playtest\.tmp\agent_playtest\2026-09-12\`. The only worktree source additions are the two reusable harness files named in the header.
