# Beat the House 0.6.1 owner playtest handoff

Closeout begun 2026-11-11; final qualification completed 2026-11-12 UTC.
Candidate: **8724a23f6d8979863f4ed024159a0f07a1d4f0ab**.
Tree: **cea7a9402bd32b1f6092d1d2a1b501bbf9643ac2**.

**Both first-night tutorial lessons advance through normal controls. Smoke is
11/11 green, no-pointer animation liveness passes, and all 233 discovered Python
tests pass.** CLOSE-01 through CLOSE-04 and final packaging are complete. The
rendered acceptance run is finished with one new open scenery defect, explicit
narrower results and unreached cases. This is a qualified technical candidate for
owner playtesting; it is not a claim that every acceptance path passed.

Play this exact [NEXT candidate](http://localhost:8088/p/beat-the-house/play/dev/8724a23f6d8979863f4ed024159a0f07a1d4f0ab/).
The menu reads **0.6.0 (8724a23f6d89)**. Runtime fixes were first fully present in
a6ce512640cbd98019a6b9a4c5b5081278ba78bb; only proof/ledger documentation changed
between that rendered acceptance build and this candidate. Later bookkeeping
commits do not change the frozen package source or this immutable link.

## 1. Tutorial result, checked before product repairs

An empty, disposable browser profile on NEXT
4cb86ee3fd9b04733a794af2289ab8fce0132443 was played through the first night
using normal controls (49 batches, no page/console errors or warnings).

| Lesson | Result and decisive action |
| --- | --- |
| Blackjack wager | ADVANCES. Actual Deal5 debits 161 to 156; Stand14 against dealer bust23 returns 10 to 166. A real one-dollar felt chip changes wager 5 to 6 and Pal moves from Raise once to the Deal/Peek lesson. |
| Pull Tabs redemption | ADVANCES. Buy/collect/peel/file the real #012 winner, then Nell's Cash In changes 75 to 175 and Pal advances to the underground-map lesson. |

These were stale check expectations/fixtures, not tutorial product defects.
The checks now use the deliberately replaced durable wager/retained redemption
contracts. Raw run: E:\CodexQA\BTH\runs\close061-tutorial-before-web-20261111.
The final candidate also passed a fresh served menu/first-room startup; the full
first-night playthrough above retains its original build identity.

## 2. Every Smoke failure: classification, evidence and disposition

The reviewer's suggested classifications were rechecked before edits. The
baseline had 4 passing / 7 failing stages out of 11. The table includes failures
uncovered after earlier blockers were repaired, plus the final QA setup failure.
Grouped counts refer to the original failing messages, not a new test total.
All are clear in the final full candidate run. Detailed pre-change observations,
commands, intermediate failures and hashes remain in
[CLOSE-01 proof](CLOSE-01_green_smoke_2026-11-11.md) and
[CLOSE-05 proof](CLOSE-05_final_candidate_2026-11-11.md).

| Failure / original count | Classification | Evidence and change |
| --- | --- | --- |
| Blackjack wager tutorial1 | Stale expectation | Fresh NEXT felt chip5→6 advances Pal; c458224b durable wager predicate replaces input-only completion. Check false/true state and unchanged-input rejection. |
| Pull Tabs redemption tutorial1 | Stale harness | Fresh NEXT paid marked winner filed at Nell advances Pal;27368b99 requires retained receipt and environment counter. Drive real ticket lifecycle and retain duplicate/account controls. |
| Generated breakdown stale1 | Stale expectation | Generator yields identical75 contexts/607 slots; CRLF checkout differs from canonical LF. Regenerate canonical LF using the unchanged strict check; final attribute file is identical to baseline. |
| Prepared route override / scenario probe2 | Stale harness | Parent adds refresh argument; scenario check requires library and errors. Match current signatures and pass both arguments. |
| Missing object manifest5 and dependent contract6 | Stale harness | Fixture never bound mandatory sealed object authority. Bind isolated synthetic map before freeze; inspect live scenario authority separately from base projection. |
| Talk consequence4 | Stale harness | Raw synthetic room cannot resolve under current publication guard. Generate/finalize real arrival; preserve all four exact cash/Heat expectations. No value updates. |
| Damaged geometry4 | Product defect | Trusted rebuild re-signed damaged sealed rectangles. Validate retained publication before rebuild; preserve bytes/save and all original four rejection assertions. |
| Kitty layout15 / Grand host1 | Stale expectation | Authored hand placements supersede automatic16px pair spacing; actual intersections0, rendered NEXT rooms/desk distinct. Require authenticated geometry and actual hit exclusivity for hand-placed pairs; retain padded automatic packing and tamper negative. |
| Draw allocations3 source hits | Product defect | Blackjack duplicates state; Street Craps constructs geometry every draw. Use scalars/bounded exact geometry cache, keep autonomous frames. |
| Video Poker ui_state2 | Stale harness | Strict host-response boundary deliberately owns UI envelope. Validate through existing boundary, retain nested/account/producer hostile controls. |
| UI shell game tokens2 | Product defect | Game-specific recovery/feedback leaked into shell. Move identical behavior into game-owned neutral virtual methods; original lint unchanged and179+52 feedback checks pass. |
| Lender/event overlong2 | Product defect | Both approved 9-word lines become 8 words; amounts, obligations and event consequences unchanged. |
| Slot perf active/status2 | Product defect | Six practice cabinets exceed ordinary map's free authority slots. Isolate six exact practice slots behind practice flag;12 authority/cache/roundtrip/tamper checks, ordinary map unchanged. |
| Blackjack draw perf1 | Product defect | Draw loop dispatch/cache cost exceeds unchanged5ms threshold. Cache exact rim endpoints and batch native lines;157 geometry assertions and no-input liveness pass. |
| Crew perf1 | Stale harness | Renamed/cloned room retained obsolete seal. Use real finalized travel; same payload and16ms/512-key/size budgets. |
| Native perf6 | Stale harness | E clone lacked current backend. Build unchanged native source with existing toolchain/caps;160 sequences/300 timings/frame/draw checks now execute. Deferred retention measurement remains separate. |
| Run/Daily replacement UI | Stale harness | b0cb51df requires visible saved-run replacement confirmation. Press actual confirmation control; preserve seeds and challenge assertions. |
| Sal/M1.6 padded collisions | Stale expectation | Authored72×48 slots replace legacy padding; retain exhaustive actual exclusivity, strict authority and coincident negative; existing scenario-overlap policy unchanged. |
| Back Alley Jammer/Magnet159px² collision | Product defect | Live defaultfalse overrides validated fixed geometry, triggering legacy90px expansion. Authenticated join owns marker; explicitfalse regression added. |
| Static Slot/Grand/action/lender fixtures | Stale harness |387013ac live venue cycle injects unbacked events into private synthetic rooms. Declare intended static scope; check library-backed install/finalization, retain all existing interactions. |
| Health Inspector ordering | Stale harness |8107039e requires origin venue. Supply actual origin; keep exact[1,1,1,0,0] stage counts and real route assertions. |
| Inactive delivery travel hashes | Stale expectation | Untouched f00 control and candidate full room/world values identical; accepted venue retirement/hand placements supersede old projection. Refresh only full hash pins; keep all exact scalar and3 replay checks. Historical byte pins not independently reproduced. |
| Crew conversation model / appointment fixture | Stale expectation (model); stale harness (presence/window) | cd769f1881 obligations/presence/hourly offer and04b35205 appointment windows replace favor-debt/anytime model. Real Crew and separate fixture RNG; retain early no-change rejection, window opening and exact+22/+4 settlement. |
| Dialogue route fixture | Stale harness | bf63e433 lottery service belongs to actual counter; fake Corner Pull Tabs lacks slot. Use real finalized Gas/Nell, retain all dock/route/idempotency checks. |
| Preview focus fixture | Stale harness | Missing library/finalization plus wrong lender footprint. Use authored Crew group and checked static installation; exact no-mutation checks retained. |
| Continue status fixture | Stale harness | Same action fixture has no publication even before save. Fix construction, preserve original Loaded status and saved values. |
| Event/item/service UI fixtures | Stale harness | Raw installed-room dictionary swaps bypass atomic publication and retain wrong registry. Fresh supported fixture construction, checked installation/finalization; all exact economics and UI checks retained. |
| Entry-only terminal delay | Product defect | game_enter acknowledgement incorrectly waits for nonexistent hand result. Require canonical game_action; red77/1→77/0, original paid-hand cases remain. |
| Final Crew lender debt marker | Stale expectation | cd769f1881 replaces favor debt with unchanged 70 cash/2 obligations. Assert exact 1→71,0→2,debt[] and stronger rejected-transaction equality. |
| Candidate multiline API audit | Stale harness | Real Canvas inherits draw_multiline; shared test double lacks it. Implement equivalent segment-pair replay; retain API coverage audit. |
| Directly inherited content fragment loader | Stale harness | New authority helpers relied on composer-only preloads; add explicit local preloads; all 831 scripts still loaded. |
| Pawn immediate-credit5 UI warnings | Stale harness | Bare installed-room swap has no publication. Use real generated/finalized Pawn fixture; preserve exact 100-cash/credit/HUD checks. No warning filter. |
| Neutral reviewed-source bindings | Stale expectation | Game-owned neutral wrappers replace shell-specific spellings. Update 29 bindings one-for-one; retain 33 hostile mutations, all uniqueness and exact predicate attacks. |
| Late-Crew11 performance warnings / unauthorized Leave | Product defect | Sealed no-exit Delta room acquired an invented unsealed door from inspectable locked routes. Emit physical Leave only when the committed manifest owns it. Red10/1 ->50/0,20 real records, original rejection/normal exits/global-map checks preserved. |
| QA cleanup path264 characters | Stale harness | Exact launcher kept changed/ambiguous root as required. Shorter admitted E run ID clears the unchanged self-test; no launcher/security/cap/budget change. |
| CLOSE-05 clean-checkout manifest/hash and cache | Stale harness | Local Git autocrlf=false mis-hashed existing CRLF manifest; true yields pinnedf7d7a1 and canonicalSHA597af5. Own PowerShell module cache wrote inside checkout. Restore original setting and redirect QA cache to admittedEcache; preserve the owned cache and failed shadow evidence, with no test/source/pipeline changes. |

## 3. Closeout orders, commits and NEXT delivery

| Order | Status, code and ledger commits | Delivered/checked behavior |
| --- | --- | --- |
| CLOSE-01 | DONE. Code 4fe2c5095d241e2847e9b580417005a56fc55a18; ledger b7da568e, delivery ledger973f0ba2ae5fbf50f38cac3346a433c13a1e5c2c. | Smoke 11/11; rendered NEXT 973 shows six practice Slot cabinets, working natural spin and actual Back Alley entry without room recovery. Candidate8724 repeats full Smoke 11/11. |
| CLOSE-02 | DONE. Code 3a120bce2cd0273c445084f837c5f98f2b023b1c; ledger 11cb06d8; rendered proof6c6baf5a/ledger 208e5a78; finding-batch reconciliation cf0a4905. | NEXT a6 Grand Casino practice shows full CHIPS · COV6 · RISK6 · RET0 and OPP96CHIPS inside the box. Native 119/0 covers1-,3-,4-digit amounts at1280×720; larger amounts are native coverage, not a Web claim. |
| CLOSE-03 | DONE within stated native/rendered scope. Code f2e42dea380a9650d7e9d6d061cca049356723c6; ledger db9d6b2a; Count 1ed18edd616dd14a1e5f32b7fca81a6f13772732; rendered proof5b13aa71/ledger e9732422; finding batches 3c09deb1. | Exact account/float comparisons pass; NEXT a6 real Delta closing-time dialogue, Take the hint and departure map exercised. Remaining ride beats were0; native 30/0 additionally covers1/2. No claim that rendered Take the hint served an unobserved30-minute callback. |
| CLOSE-04 | DONE, owner-reduced AUD061-04. Code ceccaf561d79718b69d4fbf499cf923cb0e864d3; ledger 8d9dda72; rendered proof53b2a228/ledger 505a10bc; assessment batch 9f10bb90. | NEXT a6 and candidate 8724 display0.6.0(short commit). Changing only RELEASE_VERSION to0.6.1 changed the actual source-run menu, then was restored byte-for-byte. |
| CLOSE-06 | EXECUTION DONE; findings/coverage OPEN. Proof a8321cc8; results ledger8724a23f6d8979863f4ed024159a0f07a1d4f0ab; new-finding registration 6ee494e6, parent-view reconciliation 84fecb8b. | NEXT a6, six fresh campaigns,233 normal-control batches / 239 screenshots, all closed with0 page/console errors or warnings. One of 3 flows passes; 2 unreached. Six game checkpoints pass; 4 narrower; Crew Poker unreached. Full results below. |
| CLOSE-05 | DONE. Proof 5657590a / ledger 672b7292; frozen source 8724a23f6d8979863f4ed024159a0f07a1d4f0ab; this handoff and its paired proof/ledger commits are documentation after the freeze. | Same candidate passes final gates, is served on NEXT, and supplies both unchanged-exporter packages below. |

Each order has one maintained proof file under docs/testing. Follow-up proof and
ledger commits keep their own identities. All runtime changes are present in
candidate 8724; no test failure was deleted, skipped or loosened. The original
four damaged-geometry rejection assertions remain and now pass after restoring
publication validation.

CLOSE-03 details: Bar Dice warm 76/0, cold 52/0, settled 24/0; its account and
animation assertions are separate and the real Inspector popup is dismissed
through One Last Move. Count stores a binary-exact reference, preserving 64/430.
Riverboat is 30/0 after building the real dock, with production refusal intact.
Scratch warm 9/0/cold 5/0 diagnoses the omitted machine display mirror versus
authoritative portable piles and exact integral float/int typing; only equal
integral representations are normalized. No financial/value defect was found.

## 4. Rendered acceptance results

Evidence uses disposable profiles and normal controls, without injected game
state, money, clock, heat, standing or inventory. Saved files were read only to
identify the actual completed checkpoint and compare wallet/inventory/RNG.
## Three flows

| Flow | Result | Actual controls and evidence |
| --- | --- | --- |
| Crew offer -> accept -> return (BTH-GAME-RETURN-001) | PASS | A027 real Mags package offer overlays active Pull Tabs with a paid $3 winner still unredeemed; A028 normal confirmation; A029 returns to same game/winner. Cash 162 / chips 0 unchanged, pile_of_pull_tabs retained, crew_package added, RNG1770357125 unchanged. Nell subsequently redeems that winner once. |
| Expired Jazz Club Crew handoff | NOT REACHED | C reached the actual Jazz room normally but had no Jazz package. A's generated package targeted Alley; D's targeted Motel23:00-23:30. Those are not Jazz coverage. F borrowed for 2 deliveries, tried actual paid Slot actions, and inspected Package: requests only where Crew is present, with no Crew in that Gas room. No expired Jazz handoff control was reached. |
| Choosing an offered Meta item at showdown | NOT REACHED | E reached Grand Main Floor, Cage and High-Limit through the real invitation and cash buy-in. Heat remained below the 70 staff-attention / 95 forced-showdown thresholds. Fresh campaign loadouts had no equipped/carried Meta instances; no showdown item offer was presented or clicked. Reaching Grand is not a pass for this choice. |

## Eleven games

Wallets are cash/chips. Inventory is the actual item-ID list; a ticket pile
remaining after a losing scratch is expected and is not an extra payout.

| Game | Result against requested checkpoint | Wallet/inventory before -> checkpoint -> finish; once-only check |
| --- | --- | --- |
| Blackjack | PASS | D028 82/0, [roadside_map]. Real Deal27 ->55/0; D029 Save, reload/Continue and real reentry D031 retain55, inventory and RNG51389658. Stand -> natural final110/0; D033/D034 settled Save/Continue exact 110, same inventory/RNG286569033, one55 return. |
| Craps | PASS, working bets | E024 68/50, [roadside_map]. Pass Line5, natural4 sets point4 ->68/45 with working pass5. E026/E027 Save/reload/Continue/reentry retain full checkpoint, RNG1847208678. Natural10 then7-out clears the bet, chips45. Separate Eye in the Sky Press on event adds 15 cash ->83; E031/E032 settled83/45, same inventory/RNG893702950. No repeated stake/payment. |
| Pull Tabs | PASS, ticket in tray | A018 163/0, []; Buy1 ->162 and tray#010. A021-A025 Save/reload/Continue/reentry preserve same tray/pile/RNG63610128. Collect and AutoOpen ->$3 winner, then real Crew offer/return. Nell redeems exactly1 for 3 ->165; repeat disabled. A033/A034 settled165/0, [], RNG1770357125 exact. |
| Scratch Tickets | PASS, unopened and partly opened | B004 93/0, []; real stocked Crossword15 ->78, pile_of_scratch_tickets. Unopened lift/tray saved/reloaded/Continued and collected. Normal drag exposes K I S J C N; B010/B011 Save/reload/Continue/reentry retain those6 letters and complete authoritative piles exactly, RNG1697019555. CLEAR ALL ->No Win, normal click files once. B013/B014 retain78/0, [pile_of_scratch_tickets], exact full piles/RNG; one filed loser, no active ticket, tray, winner or queued payout. |
| Slot | PASS, autoplay | B016 78/0, [pile_of_scratch_tickets]. Auto and Save while on: B018 cash76/spin1; another natural paid spin before page reload makes actual persisted B019 cash74/spin2. Continue/reentry resumes Auto; normal toggle stops at4 losing spins, coin_in8/out0 ->70. B021/B022 settled70/0, same inventory/RNG531710505, spin_count4/Auto false, no fifth debit. The intervening legitimate spin is not a restore loss. |
| Coin Pusher | PASS, supported floor-save bed | F019 47/0, []; real Drop1 ->46. Inside Save explicitly refuses and directs Resume ->Leave machine ->save from floor. Used that normal path F021, with coins on the bed. Reload/Continue/reentry F022 preserve the complete canonical machine/settled bodies exactly. Natural movement observed, Collect0 disabled. F024/F025 final floor Save/Continue46/0, [], RNG2104775536 exact; action_count1/total_cost1/total_payout0/drop_queue0/paid_drop_pending false. This does not claim an inside-machine save or native retention measurement. |
| Bar Dice | Narrower qualification; paid unresolved NOT REACHED | C normal Apartment ->Bar,165/0,[]. Ante22, cover, natural shakes, Settle/Slam/Lift ->pre-Call checkpoint is unfunded165. Save/reload/Continue/reentry retain it. Call funds and settles on one boundary, natural loss22 ->143. C016/C017 settled Save/Continue143/0, [], RNG1979461521 exact. No invented paid pre-Call state. |
| Video Poker | Held-card qualification; paid unresolved NOT REACHED | D018 18/0,[roadside_map]. Deal6 creates an unfunded active hand; held indices0/2. D019/D021 Save/reload/Continue/reentry preserve identical held cards/session/18 cash/RNG703209585. Draw charges6 and settles No Pay ->12. D022/D023 settled12, same inventory/RNG51389658 exact. Held-card restore passed; no claim of an earlier debit. |
| Roulette | Save-drain settlement qualification; unresolved paid file NOT REACHED | D037 160/0,[roadside_map]. Queued27 Red saved/restored. Confirm later shows133 during the paid read/payout window D042. Completed manual Save D043 already contains final187 for18 red; Continue D044 shows that same result, not another payment. D045/D046 settled187, same inventory/RNG1638000044 exact. Visually unfinished is not an unresolved saved financial transaction. |
| Baccarat | Save-drain hand qualification; unresolved paid file NOT REACHED | E039 23/145,[roadside_map]. Real110 Player wager/Deal then immediate Menu+Save while first cards move; screenshot041 still shows145. Decoded completed primary save041 already contains255 and final Player7/Banker3. Continue/reentry042 shows same result, one net110. E043/E044 settled23/255, inventory unchanged/RNG509283739 exact. Do not attribute another110 payment to Continue. |
| Crew Draw Poker | NOT REACHED | F normal Gas Parking Tip ->Punchline, two 8-dollar drinks, real Side Door Follow the nod ->Hidden Casino. Actual Crew Back Room card F014 says Rook keeps it for made company or people he escorts. This fresh campaign had neither; no hand, paid street or settlement was reached. Gate wallet57/0, inventory[]. |

Bar Dice, Video Poker, Roulette and Baccarat retain their financial semantics.
CLOSE-06 does not change when they fund/commit or weaken a check to turn those
narrower observations into the requested unresolved paid-state passes.
The complete matrix remains open in BTH061-RC-ACCEPTANCE-COVERAGE-001/BTH061-006.


### New open finding: Gas shelter scenery

**BTH061-CLOSE06-SCENARIO-CONTINUE-001** is reproduced and left open per
CLOSE-06's no-inline-fix rule. With the Gas storm shelter active, props and
people disappear while the header still says Road Flooded / Door Stays Open.

Reproduce from a new campaign with the storm shelter visible: buy the stocked
Crossword ticket, Save, reload, Continue and inspect the Gas room. CampaignB
screens003 versus006 shows missing shutters, generator/power panel, tape,
family, drivers and supplies while the78-dollar wallet and paid ticket remain
intact. Independent campaignA reproduces it across Continue (016/023).
CampaignF003 ->Parking Tip ->Follow Tip ->005 also loses the scenery before any
Save/reload. It therefore also needs event-response projection investigation.
Bar Fight and Grand Convention visuals survived the exercised Continues;
this is not evidence that all scenario rooms fail.

Full reproduction, screenshots, read-only save comparisons and hashes:
[CLOSE-06 proof](CLOSE-06_rendered_acceptance_2026-11-11.md).

## 5. Final candidate checks

| Check | Before / baseline | Final candidate 8724 |
| --- | --- | --- |
| Full Smoke, unchanged11 stages |4 pass / 7 fail | **11 pass /0 fail, exit0**; cl061-r2. |
| Candidate's initial Smoke attempt |10 pass /1 fail (validator only) | QA clone's Git line-ending setting and PowerShell cache location corrected; source/checks unchanged. Same full suite then11/11, no timeouts. Failed runcl061-rc-smoke retained. |
| GDScript loader |826 loaded,2 parse failures |831 loaded,0 failures; same exclusions. |
| Content/runtime/cold assertions |25 content errors,16 runtime errors,4 damaged-geometry failures | All clear; cold projection restores 9 objects and rejects damaged authority using all original negatives. |
| No-pointer animation liveness | Already release-gated | **PASS, exit0**, cl061-rc-liveness; no animation suppression. |
| Python tools/tests |180/180 first-run baseline | **180/180 PASS**, cl061-rc-python-tools. |
| Python tools root | Additional existing test discovery scope | **53/53 PASS**, cl061-rc-python-root. These are not 53 new tests. |

Smoke performance includes 46 observations across 11 game surfaces,10 resolve
paths and 8 additional modes. Required native 160-sequence/300-timing checks
execute and pass. This Smoke uses practice contexts/run_count 0, so it does not
claim broad seeded performance coverage or the deferred native retention
measurement. No failures or warnings were reported by the final performance stage.

NEXT promoted the exact candidate at 2026-11-12T00:41:33Z. Ten served identity/
asset checks pass; archive SHA256
ca29c8d069e3fad44e2efa13f6ad20001f027e0a5b3f74f7dfe7ce0682531ed9.
Fresh browser startup inspected the menu footer and first tutorial room;
zero page/console errors/warnings, owned browser closed. Existing watcher,
audience, limits, pins and stable/itch channels remain unchanged.

The final ledger reconciliation retains the same1,681 pre-existing unrelated
errors and0 warnings as the fixed-time baseline (1,671 concern the inherited
runtime inventory). There are0 owned CLOSE/AUD061/RC metadata errors. The checker
therefore still exits1 globally; it is not a green repository-wide ledger claim.
Execution is recorded done with findings open; AUD061-EXECUTION and CLOSEOUT-061
remain open parent rows because acceptance/deferred children remain open.
No child dependency or required acceptance was deleted or waived.

The final evidence check recovered one reused index reference with its exact
original hash; all 3,579 raw hash references across 21 indexes then verified with
0 mismatches. Product/tests/packages were unaffected.

## 6. Candidate packages

| Artifact (absolute path) | Bytes | SHA-256 |
| --- | ---: | --- |
| E:\CodexQA\BTH\workspaces\close061-package\builds\itch\BeatTheHouse-0.6.0-dev+8724a23f6d89-8724a23f6d89-a51a7c919302.manifest.json | 8521 | 74d23b13b68f99b66558a832dcf9ef5a7c373fbc9d8c6303f115b57b47195764 |
| E:\CodexQA\BTH\workspaces\close061-package\builds\itch\BeatTheHouse-0.6.0-dev+8724a23f6d89-web-8724a23f6d89-a51a7c919302.zip | 41582908 | 2afc223c0f8d71437fd1410de0332adeb7f365bfb11ffb3adf91a8c3336393f8 |
| E:\CodexQA\BTH\workspaces\close061-package\builds\itch\BeatTheHouse-0.6.0-dev+8724a23f6d89-windows-8724a23f6d89-a51a7c919302.zip | 85315664 | b744f89523401838be64ea57a575d727f11edc832cc10d0b28c9c4f1f861e2db |

Both are original exporter filenames, built by tools/export_itch.ps1 from the
same clean, frozen candidate. Their manifests bind source/tree/native-library
identity and their PCK/archive audits pass. Windows was launched as the actual
exported EXE for 300 headless frames with a fresh E profile, exit0 and no script/
engine errors; that scope does not claim rendered native gameplay. Web was
extracted, served by the existing isolated local server, and opened in a fresh
browser: menu and normal Play into the first room were inspected, required
PCK/WASM requests200 and cross-origin isolation true. No page/console errors
or warnings; owned server/browser closed.

No tag, manual rename or upload was performed. Menu version remains 0.6.0 by C1.
Windows properties, Android/iOS presets, project version and internal
0.6.0-dev identity remain unchanged; aligning them later requires the separate
owner-deferred pin update.

## 7. What to look at when you play

Player-visible changes to exercise:

- Bar Dice: full chips financial/OPP line, including RET, at large amounts.
- Menu footer: one RELEASE_VERSION value and the exact short build commit.
- Continue/recovery: damaged sealed room geometry is rejected while the last
  valid save is preserved; authenticated fixed placement no longer gets legacy
  expansion (including the Back Alley Jammer/Magnet case).
- Grand practice Slots: all six distinct cabinets open; autoplay and natural
  draws remain live.
- Entering games: entry acknowledgements no longer wait for a nonexistent
  terminal hand presentation; paid-hand result pacing is retained.
- Delta Queen and locked routes: physical Leave appears only when the room
  manifest owns the exit. Ordinary exits and the global map remain available
  where authored. Try the closing-time Dorian dialogue and departure map.
- Crew lender and delivery offer: the two shortened eight-word lines retain
  the same 70 cash / two-delivery obligations and consequences.
- Blackjack ritual/chip drawings and Street Craps chalk: appearance and idle
  motion should remain intact after caching/batching. Observe without moving
  the pointer and with placement overlays open.
- Game-specific feedback/recovery moved into game modules with the same
  player messages; check Blackjack, Pull Tabs and Scratch prompts.

Every scoped finding/coverage item still open:

| ID | What remains |
| --- | --- |
| BTH061-CLOSE06-SCENARIO-CONTINUE-001 | Gas storm-shelter scenery disappears after Continue or event response. Reproduce as above. |
| BTH061-RC-ACCEPTANCE-COVERAGE-001 / BTH061-006 | Full requested paid-unresolved matrix remains incomplete: Bar Dice, Video Poker, Roulette and Baccarat have the narrower funding/save-barrier results above; Crew Poker mid-street was gated. |
| BTH-GAME-RETURN-001 | This run proves genuine Crew offer/accept/return to an active paid Pull Tabs winner. Broader historical neutral-Close/cold-repeat coverage remains open. |
| BTH061-CREW-EXPIRED-HANDOFF | Rendered expired Jazz handoff not reached; historical native proof retained. |
| BTH061-AUDIT-SHOWDOWN-META-CHOICE-FIX-031 | Offered Meta item at showdown not reached; historical native proof retained. |
| BTH-BARDICE-WARM-PROGRESSION-001 | Export half closed not reproducible/reopen on recurrence. Separate original broader warm/cold gameplay acceptance remains open. |
| BTH061-RC-NATIVE-RETENTION-001 | Deferred after 0.6.1 by C4; distinct from the passing mandatory native Smoke checks. |
| BTH061-003 /004 /008 /009 /010 /011 | Six P2/partial coverage rows remain open, deferred after 0.6.1 by C4. |

AUD061-12 and BTH-NEXT-ALLOC-001 are closed **not reproducible; reopen on
recurrence**, as is the export half above. AUD061-11 and AUD061-17 are
**done; findings open**. The historical failed qualification evidence is
retained; it is not relabelled as a passing playthrough.

All new raw manifests, logs, saves and screenshots remain under E:\CodexQA\BTH.
Per-task proof files contain external raw-evidence indexes and SHA256 hashes.
No old committed evidence was removed.

Final technical commands, successful/failed attempts and raw-evidence index: [CLOSE-05 proof](CLOSE-05_final_candidate_2026-11-11.md).
