# Post-fix 0.6 claim-audit playtest

**Status:** COMPLETE — owner/fix-worker review requested  
**Date:** 2026-09-13  
**Code under test:** `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes`  
**Base HEAD:** `56de66598a2bcdbc3f171f090b48c361daf35563`  
**Uncommitted fix diff fingerprint at start:** `45add38e02d9de93e2ecae3f2092f32714ab5431`  
**Branch:** `codex/agent-playtest-fixes` (uncommitted; no staged files)  
**Purpose:** independently replay BUG-01–31 after their fix tasks, then test player-facing 0.6 commit claims and hunt for additional defects.

## Outcome summary

- Original BUG-01–31: **21 PASS, 9 FAIL, 1 UNVERIFIED**. The 31 fixes are not all complete.
- New findings: **6 confirmed** — BUG-32 through BUG-37 (5 Major, 1 Minor).
- Combined visible-input coverage: **1,714 commands across 28 isolated/relaunched sessions**.
- Fixed worktree stayed on the same HEAD and uncommitted diff throughout the sweep.

## Verification lanes

| Lane | Initial session | Assigned verification |
|---|---|---|
| B — games | `verify31_b1` | BUG-02, 03, 04, 11, 13, 20, 21, 24, 27, 28, 29 |
| C — world/story | `verify31_c1` | BUG-08, 09, 10, 12, 14, 15, 16, 17, 18, 22, 25, 26, 30, 31 |
| D — lifecycle/UI | `verify31_d1` | BUG-01, 05, 06, 07, 19, 23 and visible Save/Continue |

Each lane uses fresh isolated persistence and visible harness input. A lane exits at its first failed claim and is relaunched in a fresh session; once its assigned fixes pass, it moves to claim-driven 0.6 exploration.

## Commit-derived 0.6 claim register

| Priority | Commit(s) | Claim to verify through visible play | Primary oracle |
|---:|---|---|---|
| 1 | `ddf7c4dc`, `b7edb89b`, `56de6659` | Vince trades exactly one untouched scratch ticket per persisted encounter for visible local Heat −8 and a deterministic 33% low-tier item chance. | One ticket consumed; exact Heat/result; no repeat after Save/Continue or revisit. |
| 2 | `d7f11a3e`, `1766b565`, authored-placement chain through `2104c773` | All live objects across 21 rooms/layers and 55 scenario arrivals are grounded on class-valid supports and remain readable/hittable. | No floating/sunken/mis-supported object; every labeled interaction and safe exit is reachable. |
| 3 | `2649d455`, `55a194a1`, `19718c1a`, `5f185f2c` | Back-Room Poker is four-street Texas Hold'em with exact no-limit raises, hidden information, side pots, moving button, Save/Continue, and correct reporting identity. | Pot/contribution conservation, legal custom raise bounds, one payout, stable reload. |
| 4 | `9971aa2b`, `138cd8d3` | Blackjack counter surveillance ignores accurate flat betting but reacts to mature count-shaped ramps and missed pulses only at settlement. | Exact Heat/evidence timing and cap; no false positive on 16+ flat hands. |
| 5 | `f41d6db8`, `7e2707ff` | All Coin Pusher cabinets keep three-per-second cadence and persist/collect deterministic item prizes exactly once. | Stable tray item through reload; one cash/item grant; no duplicate collect. |
| 6 | `651f2a9f`, `4360b380` | Sustained Slot autoplay preserves complete distinct reel cycles, feature cadence, responsiveness, and one settlement per spin. | No early/duplicate/frozen spin; exact bankroll; responsive controls and nonzero liveness. |
| 7 | `c97aa8b0`, `541f4568`, `28568d12`, `f8a1fe35` | Casino/Street Craps expose and correctly settle their broad wager sets, shooter/pass-dice/take-down behavior, currency isolation, and interruption refunds. | Exact stake/payout/refund once; point/working state survives reload. |
| 8 | `463ebe0c`, `9f1b4a24`, `fa08d703`, `2104c773` | Authored scenario phases visibly transform rooms, coexist with rotating content, persist after Save/Continue/revisit, and retain a safe exit. | Correct aftermath objects/copy, no replacement/collision/replay/dead end. |
| 9 | `28568d12`, `f8a1fe35` | Back Alley and Grand Casino expose the correct Craps variants; Tier-2 Kitty/Delta routes appear immediately and survive the travel-card cap. | Correct game is enterable; enabled Tier-2 route appears without an unrelated trip. |
| 10 | `3f31bf10` | Natural `FIRST-NIGHT-ACE-17` play reaches Punchline L1→L2→L3 after 11 ordinary Crew favors and survives save/revisit/departure. | Clear lock/progress, furnished/hittable L3, stable same-layer restore and departure. |
| 11 | `8a880cc0` through `00c52ce6` | Authored/freeform placements stay live; repeated clicks cycle overlapping objects and activate the selected target without duplicate travel. | Lower overlaps remain reachable; one click produces one intended action. |
| 12 | `3695d64a`, `fcb28d23` | Debt Spiral debt, Motel prepaid days/home loss, rent grace/eviction, bankruptcy, and terminal persistence occur at their claimed boundaries. | Each boundary fires once with readable state/result and stable Continue. |
| 13 | `cf4e64ad`, `89d44ac3`, `9a490379` | v0.5.1 and mid-0.6 saves admit and round-trip debt/game/event state without replaying effects. | Same room/state/balance/result after Continue; no repeated charge/reward/event. |
| 14 | `d94977b9`, `334674fb`, `45e08213` | Seven Crew recruitment routes and 13 jobs are staged with exact-once rewards/trust/grievance/expiry/aftermath. | Visible member/job ownership and distinct persisted aftermath without replay. |
| 15 | `4822d288`, `613f5013` | Both heists and the Turn are naturally playable staged finales with real setup requirements and exact-once terminal outcomes. | No skipped/repeated phase; distinct exits/failures; one payout/ending. |
| 16 | `48807695`, `6279395e`, `4f91777b`, `1253e3b1` | Scenario souvenirs enter run inventory, carry effects, persist/sell, and do not unlock cross-run collection progress. | Exact acquisition/effect once, stable Continue/sale, absent from new-run meta progress. |

## BUG-01–31 verification

BUG-10 is not presumed fixed: the fix report explicitly left its placement path to another owner.

| Bug | Result | Independent player evidence | Notes |
|---|---|---|---|
| BUG-01 | PASS | `verify31_d4/0003.png`, `0004.png`, `0055.png` through `0057.png` | Fresh and resumed runs both restore a playable Apartment with Leave/Corner Store route, $80, and prior result state. |
| BUG-02 | PASS | `verify31_b1/0153.png`, `0154.png` | Vault Drop drop/move/slam/nudge/tap route left the machine in 0.9 seconds. |
| BUG-03 | PASS | `verify31_b1/0046.png`, `0047.png` | One $2 Pull Tabs purchase moved bankroll 100000→99998 exactly once. |
| BUG-04 | PASS | `verify31_b1/0008.png` through `0014.png` | Craps denomination, Pass Line, and throw stayed responsive; exact −$5 and clean logs. |
| BUG-05 | PASS | `verify31_d4/0008.png`, `0012.png`, `0014.png`, `0015.png`, `0018.png`, `0027.png` | Settings, Inventory, and Run Menu hide active tutorial Talk and restore it on close/resume. |
| BUG-06 | PASS | `verify31_d4/0035.png` through `0039.png` | Dialogue acknowledgement retains the highlighted coach target until legitimate pickup. |
| BUG-07 | **FAIL — regression** | `verify31_d1/0010.png` through `0012.png` | The new full-screen coach `_input` shield consumes the tutorial TalkDock's own “Pick them up” and “Hide” controls because they are outside the coach panel/anchor rectangles. Harness accepted both real clicks, but Pal's event and choices remained unchanged. |
| BUG-08 | **FAIL — incomplete fix** | `verify31_c5/0044.png` | A $1 Numbers slip updates internal bankroll to $87 and the Result to `Corner Store takes the slip. $-1`, but the visible wallet remains stale at $88 with the prior `+30` pulse. |
| BUG-09 | **FAIL — incomplete fix** | `verify31_c6/0102.png` | Silas charges exactly once, rejects retry, and disables the option, but visible wallet remains stale at $50/+45 while canonical bankroll is $38 and Result reports −$12. |
| BUG-10 | **FAIL — unresolved** | `verify31_c4/0104.png` | Vic Mercer is visibly rendered and semantically enabled at The Punchline, but his exact rendered hit authority is not hittable; activation opens no interaction panel. |
| BUG-11 | PASS | `verify31_b1/0058.png`, `0061.png` | BET+ after draw clears cards/holds and returns to Deal at the new wager. |
| BUG-12 | **FAIL — still reproduces** | `verify31_c1/0016.png` | Double-clicking Ledger Pencil while Instant Coffee is inspected buys the pencil for $14 and reports that purchase, but the visible selected card remains Instant Coffee with its Buy button. |
| BUG-13 | PASS | `verify31_b1/0018.png` | Fresh practice reset to $100000 without the prior Craps delta. |
| BUG-14 | PASS | `verify31_c5` | Dave's first-stop fallback contains no blank location. |
| BUG-15 | PASS | `verify31_c5` | Counter Phone action completes with no unsupported-SFX log alert. |
| BUG-16 | PASS | `verify31_c5` | Phone/loan outcome replaces stale feedback through the canonical Result path. |
| BUG-17 | PASS | `verify31_c6/0035.png`, `0083.png` | Blackjack and Pull Tabs show distinct game-local player-facing Risk copy. |
| BUG-18 | PASS | `verify31_c5` | Long Dave result text wraps fully in the visible Result panel. |
| BUG-23 | **FAIL — incomplete fix** | `verify31_d2/0024.png` through `0026.png` | Focus stays inside Settings, but Tab selects the off-screen Text Size control without scrolling it into view; Enter opens its Small/Normal/Large popup below the viewport, partly covering the fixed footer. |
| BUG-19 | **FAIL — incomplete fix** | `verify31_d3/0003.png` through `0005.png` | The mandatory First Night seed field is disabled, but the setup screen has no fixed-seed status or explanation; focus/hover produces no tooltip, so the replacement remains unexplained. |
| BUG-20 | PASS | `verify31_b1/0028.png`, `0029.png` | Roulette rim labels stay within the wheel during spin/result. |
| BUG-21 | PASS | `verify31_b1/0039.png` | Minimum decrement controls are muted and absent from the action registry; increments remain usable. |
| BUG-22 | PASS | `verify31_c5` | Instant Coffee reads `Passive — works while carried and does not use the active-item slot`. |
| BUG-24 | PASS | `verify31_b1/0018.png` | Baccarat LEAVE and hand explainer are visibly separated and clickable. |
| BUG-25 | PASS | `verify31_c5` | Dave's long consequence preview wraps fully without colliding with its action. |
| BUG-26 | **UNVERIFIED — route not reproducible** | `verify31_c8/0006.png`, `0008.png`, `0021.png` | A faithful replay of the original `pt_d4` command sequence diverged before Wet Alley: accepted seed typing left the generated seed unchanged, then accepted Menu input did not expose Skip Lessons. The original `scenario::goods_lot` path was therefore not reached, so this is neither a pass nor a reproduced failure. |
| BUG-27 | PASS | `verify31_b1/0102.png` | A settled $11 bust shows `HOUSE TAKES $-11`, not `PUSH +0`. |
| BUG-28 | PASS | `verify31_b1/0124.png`, `0126.png` | Active and settled Bar Dice guidance fits inside the console. |
| BUG-29 | PASS | `verify31_b1/0029.png` through `0031.png` | CLEAR preserves enabled REBET; REBET restores the exact $1-on-17 layout. |
| BUG-31 | **FAIL — incomplete fix** | `verify31_c2/0078.png` | Lucky's “Accept Offer” confirmation contains only generic voice and “Confirm: Accept Offer”; the claimed $45 principal, two-favor repayment, 0% interest, and two-turn deadline are absent from the actual confirmation path. |
| BUG-30 | **FAIL — still reproduces** | `verify31_c3/0036.png` | The real chained family-loan dialogue nameplate still renders “Unknown,” not the authored “Unknown Caller,” despite the chain-hydration regression test passing. |

Fresh verification is complete: 21 PASS, 9 FAIL, and BUG-26 UNVERIFIED because its original scenario route could not be reproduced through the same visible-input sequence.

## New findings

### BUG-32 — Blackjack count pulse after HIT reuses a resolved icon ID and cannot be clicked

**Severity:** Major  
**Area:** Blackjack counter-surveillance/count-card interaction  
**Result:** FAIL — deterministic fresh reproduction

With seed `CLAIM06-B2-FLAT-FINAL`, the player clicked all eight opening count pulses correctly (`correct_hits=8`, `misses=0`, and `recorded_delta=target_delta=+2` in `claim06_b2/0175.result.json`). A legal HIT then drew a King (count value −1). The challenge target correctly changed to +1, but the new pulse reused the already-resolved ID `blackjack:count:1121148:8`; the visible −1 marker over the King had no registered `blackjack_count_icon` action and only SETTLE remained available (`0176.result.json`, `0176.png`). The player therefore cannot record the newly exposed card despite perfect prior input, allowing the surveillance system to penalize accurate play. Logs remained clean.

The implementation makes this collision plausible: `_sync_count_challenge_icons()` derives `serial` from persisted `icon_serial`, while resolved IDs are challenge-ID-plus-serial; card tracking also prefers the rank/suit/deck identity key over the source-position key. The player-facing failure is independently established by the visible/action-registry evidence above; this code observation is diagnostic context, not the oracle.

### BUG-33 — Run Content home choice is overwritten by the profile home

**Severity:** Major  
**Area:** Run Setup / home selection  
**Result:** CONFIRMED — reproduced twice

The player selected `Standard Run` and `Home: Motel Room`; the Run Content drawer and returned setup both retained that choice (`claim06_d2/0062.png`, `0063.png`). `START NEW RUN` nevertheless opened at `BACK ALLEY` with no Motel Room home/tenure objects (`0064.png`), matching an earlier reproduction at `0054`–`0058`. This directly contradicts the control's tooltip, `Choose the home this run starts in.`

Likely cause (high confidence): `_challenge_with_home_selection()` writes `home_archetype_id=motel_room`, but `start_foundation_run()` then calls `_challenge_with_meta_home_for_run()` for a standard run; that function blindly overwrites every matching modifier with `normal_run_start_modifiers()`, including the profile's Back Alley home (`scripts/ui/foundation_main.gd:9187`, `15693`).

### BUG-34 — Gas Station Casino Numbers Book label is clipped

**Severity:** Minor  
**Area:** Sunset Gas Casino environment presentation  
**Result:** CONFIRMED — reproduced in two consecutive room views

The authored object label renders as `Gas Station Casino Numbers B` instead of the complete `Gas Station Casino Numbers Book` in the normal room view (`claim06_c1/0028.png`). It remained clipped after exact-clicking another object and redrawing the room (`0029.png`), although the semantic target itself remained present and hittable. The label is composed in `scripts/ui/environment_interaction_controller.gd:1226`; its presentation bounds do not accommodate the venue-derived length.

### BUG-35 — Pinball bonus waits for an impossible zero-ball LAUNCH before settling

**Severity:** Major  
**Area:** Slots / Pinball feature completion  
**Result:** CONFIRMED — deterministic reproduction

After the fourth and final bonus ball drained, the live Pinball screen showed `LEFT 0  LIVE 0` but remained active, incomplete, and still offered LAUNCH (`claim06_b4/0049.png`; `0049.result.json`). Clicking that impossible zero-ball LAUNCH was accepted and only then closed the feature and reported its $22 total (`0050.png`); bankroll conservation remained correct at $100012. The real-time simulator can drain the last ball between player actions, but completion in `pinball_feature.gd` is evaluated inside the next action step (`scripts/games/slots/pinball/pinball_feature.gd:202`–`254`), so no automatic settlement occurs at the visible drain boundary.

### BUG-36 — Casino Craps take-down refunds a cash-funded wager as chips

**Severity:** Major  
**Area:** Casino Craps / currency isolation  
**Result:** CONFIRMED — persisted across a refresh

With bankroll $100000 and chips 0, the player staged $15 of Casino Craps bets and established point 6, leaving bankroll $99985. Taking down the live $5 Place 6 removed the wager and reported `5 returned`, but bankroll stayed $99985 while the Chips header changed from 0 to 5 (`claim06_b5/0020.png`, `0021.png`). `_resolve_take_down()` emits the refund without a currency on the casino branch and only tags `currency="cash"` for Street Craps (`scripts/games/craps.gd:758`–`811`), so the generic result application credits the wrong wallet.

### BUG-37 — Both newly unlocked Tier-2 destinations reject enabled Travel

**Severity:** Major  
**Area:** World map / scenario destination installation  
**Result:** CONFIRMED — two Tier-2 destinations

After Bar then Sunset Gas Casino satisfied the Tier-2 threshold, Lounge and Riverboat both appeared immediately and retained the prior safe routes (`claim06_c2/0074.png`). Each destination preview was open, affordable, and exposed an enabled Travel button, but mouse, Enter, and exact-coordinate activation left the player at Sunset Gas Casino (`0077`–`0088`). The resulting diagnostics identify the blocking cause: destination scenario labels overlap `base::travel:leave`—`kitty_cat_lounge_bachelorette_storm_missing_guest_marker` for Lounge and `delta_queen_wedding_charter_best_man_table` for Riverboat—so scenario layout validation (`scripts/core/scenario_layout_resolver.gd:715`) rejects/rolls back both trips despite presenting them as valid routes.

## Recommended fix queue for new findings

| Bug | Recommended fix | Size | Risk |
|---|---|---:|---:|
| BUG-32 | Give every newly exposed Blackjack card a source-position-aware tracked key and a persisted monotonic icon serial, then assert a post-HIT pulse is separately clickable after every prior pulse is resolved. | M | Medium |
| BUG-33 | Treat the player's explicit Run Content home as authoritative and apply the meta-profile home only when the selection is Random/absent; cover Standard Run setup through the real start button. | S | Low |
| BUG-34 | Fit venue-derived Numbers Book labels by wrapping/shortening them or allocating width from measured text, with a 1280×720 Gas Station snapshot assertion. | S | Low |
| BUG-35 | Settle Pinball immediately when the real-time simulation drains the final ball, remove/disable LAUNCH at zero balls, and preserve one payout across wait/action boundaries. | M | Medium |
| BUG-36 | Persist each working bet's funding currency and refund to that exact wallet on take-down/interruption; do not infer refund currency from casino versus street venue. | M | High |
| BUG-37 | Reserve the base safe-exit label/rect during scenario placement and reject/reposition conflicting scenario objects before exposing the route as enabled; cover both seeded Tier-2 arrivals through visible Travel. | M | Medium |

## 0.6 claim results

| Claim | Result | Evidence / limitation |
|---|---|---|
| Back-Room Texas Hold'em (`2649d455`, `55a194a1`, `19718c1a`, `5f185f2c`) | PARTIAL PASS | `claim06_b1` completed five practice hands: Hold'em identity, moving button/blinds, hidden holes, all requested raise controls, four streets, one payout, and contribution conservation (`0052.png`: $72 = player $69 + Bishop $1 + Rook $2). Side-pot and real-run Save/Continue remain unverified because BUG-07 also made the real-run “Good to know” tutorial choice inert across mouse and keyboard activation (`0094`–`0099`). |
| Vince scratch-scalper (`ddf7c4dc`, `b7edb89b`, `56de6659`) | NOT REACHED | `claim06_d1` used deterministic seed `RUN-20260913-758339-002`, acquired one untouched High Roller ticket (`0086`, `0088`), and checked Back Alley, Bar, Gas Station Casino, and Kitty Cat Lounge through `0094`; Vince never appeared, so the mechanic claim remains unverified rather than failed. |
| Blackjack counter surveillance (`9971aa2b`, `138cd8d3`) | **FAIL** | `claim06_b2/0175.result.json` proves all eight opening pulses were clicked accurately (`correct_hits=8`, `misses=0`, `recorded_delta=target_delta=+2`). After a legal HIT exposed a King, `0176.result.json`/`0176.png` show target +1 but recorded +2: the new −1 pulse reused resolved ID `blackjack:count:1121148:8` and registered no clickable count action. Accurate play can therefore be scored as a miss. |
| Debt Spiral / home loss (`3695d64a`, `fcb28d23`) | **PARTIAL FAIL** | `claim06_d2` visibly confirmed $80 due in two turns at 20%, overdue timing after two real actions (`0018`), exactly one readable zero-bankroll terminal report (`0044`), and a stable Continue→Replay boundary without duplication (`0045`–`0047`). Motel tenure/loss could not be tested because the public Run Content choice was ignored: Motel Room remained selected in `0062`/`0063`, but the run spawned in Back Alley (`0064`), BUG-33. |
| Coin Pusher cadence/prizes (`f41d6db8`, `7e2707ff`) | PARTIAL PASS | `claim06_b3` completed 101 visible commands across Jackpot Ridge, Quarter Falls, and The Vault Drop. Drops were accepted/charged exactly once, visibly spawned, and queued-nozzle feedback remained responsive; item prizes retained stable item/label/icon/asset identities. No tray award occurred, so Save/Continue and exact-once prize collection were not reached, and serialized one-item input could not directly measure sustained ~3/sec queue throughput. |
| Environment grounding/authored placement (`d7f11a3e`, `1766b565`, through `2104c773`) | **FAIL — partial coverage** | `claim06_c1/0028.png` and `0029.png` reproducibly show the Sunset Gas Casino's authored `Gas Station Casino Numbers Book` label clipped to `Gas Station Casino Numbers B` (BUG-34). Apartment, Corner Store, and the traversed Gas Station objects remained grounded/hittable; the lane stopped at the first distinct mismatch, so the other priority rooms remain pending. |
| Punchline L1→L2→L3 / overlap cycling (`3f31bf10`, `8a880cc0`…`00c52ce6`) | NOT REACHED | `claim06_d3` naturally followed fixed First Night through both Corner Store item purchases, but known BUG-07 made Pal's rendered `Good to know` warning inert under every visible workaround (`0024.png`–`0031.png`). No ordinary favor, Punchline layer, overlap cycle, save/revisit, or departure boundary could be reached; known BUG-12 also recurred but was ignored as instructed. |
| Slot cadence/features (`651f2a9f`, `4360b380`) | **FAIL — partial coverage** | `claim06_b4` completed 22 base spins across three Pinball configurations plus four feature balls with exact bankroll conservation and responsive manual/autoplay/leave controls. After the last ball drained, `0049.png` still showed an active feature and enabled LAUNCH at `LEFT 0 LIVE 0`; an extra zero-ball launch was required to settle (`0050.png`), BUG-35. Broader families/reduce-motion stopped at this first mismatch. |
| Casino/Street Craps (`c97aa8b0`, `541f4568`, `28568d12`, `f8a1fe35`) | **FAIL — partial coverage** | `claim06_b5` exercised all four Casino Craps bet pages, denomination, undo, Pass Line, Place 6, Any Seven, point establishment, Pass Odds staging, working-bet selection, and take-down. A cash-funded $5 Place 6 refund went to chips instead of bankroll (`0020.png`, `0021.png`), BUG-36. Street Craps and later persistence/interruption boundaries moved to a fresh replacement. |
| Tier-2 Kitty/Delta routes and Craps variants (`28568d12`, `f8a1fe35`) | **FAIL — partial coverage** | `claim06_c2` proved Lounge and Riverboat appear immediately after the second distinct Tier-1 casino and survive the route-card set (`0074.png`), but neither enabled Travel action departs (`0077`–`0088`). Both destination installs fail their scenario label-vs-exit layout audit and roll back, BUG-37; downstream Grand Casino/Street Craps access was not reached in this lane. |
| Authored scenario phases/persistence (`463ebe0c`, `9f1b4a24`, `fa08d703`, `2104c773`) | PASS — exercised branch | `claim06_d5` resolved `back_alley_cruiser_parked` through visible play. Its transformation coexisted with baseline content, layout audit/z-order were valid, scenario exit was reachable, Heat/event receipt persisted across Save→full quit→Continue with identical layout digest (`0032`, `0045`, `0051`, `0053`–`0054`), and safe-exit cleanup produced the recorded aftermath exactly once (`0056`). |
| Scenario souvenirs (`48807695`, `6279395e`, `4f91777b`, `1253e3b1`) | NOT REACHED | The completed `claim06_d5` scenario branch awarded no souvenir, so inventory/effect/persistence/sale and cross-run collection boundaries remain unexercised. |
| Crew recruitment/jobs (`d94977b9`, `334674fb`, `45e08213`) | PARTIAL PASS | `claim06_c3` reached Switch naturally: refusal persisted without resolving recruitment, acceptance removed the recruitment event, and revisit replaced it with owned `crew_contact_switch` exactly once (`0033`–`0037`, `0045`–`0053`, `0063`). Job execution, reward, trust/grievance, and expiry boundaries were not reached. |

## Coverage and constraints

The earlier read-only commit audit was performed independently by all three lanes. Gameplay launched only after host memory recovered above 50 GB free; prior low-memory process exits are not part of this sweep and are not treated as game crashes.

One stale harness PowerShell wrapper from the already-finished `verify31_d3` quit command failed to terminate and grew to roughly 42 GB working set. The coordinator verified its exact command line, confirmed the associated game session was already gone, terminated only that stale wrapper, and restored safe memory; this is a harness/process-cleanup issue, not a game crash or game bug.

Street Craps remained unreachable in `claim06_b6` because same-session Continue restored the known BUG-07 tutorial stack. Vince's scratch trade, Hold'em side pots/real-run persistence, old-save compatibility, full Motel tenure/home loss, job lifecycle, heists/the Turn, scenario souvenirs, and controller/touch input remain blind spots.
