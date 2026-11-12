# CLOSE-06 - rendered acceptance on exact NEXT

Run date: 2026-11-11 through 2026-11-12 UTC.
Build: a6ce512640cbd98019a6b9a4c5b5081278ba78bb, tree8846b3457d48daafd2ae37279bade6cd42f3d38e.
Immutable NEXT: http://localhost:8088/p/beat-the-house/play/dev/a6ce512640cbd98019a6b9a4c5b5081278ba78bb/
Ten served identity/asset checks: PASS (cl061-a6-next-identity).

Result: execution finished, with one new visible finding and coverage still open.
Three named flows: 1 PASS / 2 NOT REACHED.
Eleven games: 6 paid-state/floor-bed passes, 4 narrower restore/settlement qualifications, 1 NOT REACHED.
A narrower qualification is not a pass for a paid, unresolved checkpoint that was never reached.

## Before and after; fidelity and counts

Before: the first worker recorded BTH061-RC-ACCEPTANCE-COVERAGE-001 open;
the named Crew/Jazz/Meta rendered flows and full eleven-game paid unfinished
matrix were not qualified. After: six fresh, storage-admitted E: browser
campaigns used the immutable served build and ordinary pointer, keyboard,
travel, dialogue, purchase, Save, page reload and Continue controls.
There were 233 control batches and 239 screenshots:
A39/40, B29/30, C21/22, D51/52, E48/49, F45/46 (batches/screenshots).
Every campaign finished normally with worker exit0, zero page errors,
zero console errors/warnings, cleanup errors0 and active children0.

No game API, scene override, state/clock/heat/standing injection, save editing,
profile migration or reused historical profile was used. Normal Run Setup
seed and Home choices were used. The exact paid/generated cases below are
campaigns, not practice rooms. Browser FS observations were read-only copies
of these owned profiles' actual primary save. The unchanged production
RunSaveCodec decoded those observations in separate native readers; those
readers did not create gameplay state or substitute for rendered interaction.
Full account/RNG and durable ticket/machine comparisons were exact, without
rounding or tolerances. Screenshots can show a still-moving hand after the
save barrier has already committed its final result; the decoded saved file
is authoritative for the narrower claims below.

CLOSE-06 changed no production code or tests. Baseline Smoke was4/11 stages
passing and7 failing; CLOSE-01 brought it to11/11. The loader went826 to831,
with0 errors and the existing exclusions retained. CLOSE-05 records the
final candidate's complete Smoke/liveness/Python rerun rather than treating
these browser cases as that gate.

## Three flows

| Flow | Result | Actual controls and evidence |
| --- | --- | --- |
| Crew offer -> accept -> return (BTH-GAME-RETURN-001) | PASS | A027 real Mags package offer overlays active Pull Tabs with a paid $3 winner still unredeemed; A028 normal confirmation; A029 returns to same game/winner. Cash162/chips0 unchanged, pile_of_pull_tabs retained, crew_package added, RNG1770357125 unchanged. Nell subsequently redeems that winner once. |
| Expired Jazz Club Crew handoff | NOT REACHED | C reached the actual Jazz room normally but had no Jazz package. A's generated package targeted Alley; D's targeted Motel23:00-23:30. Those are not Jazz coverage. F borrowed for2 deliveries, tried actual paid Slot actions, and inspected Package: requests only where Crew is present, with no Crew in that Gas room. No expired Jazz handoff control was reached. |
| Choosing an offered Meta item at showdown | NOT REACHED | E reached Grand Main Floor, Cage and High-Limit through the real invitation and cash buy-in. Heat remained below the70 staff-attention/95 forced-showdown thresholds. Fresh campaign loadouts had no equipped/carried Meta instances; no showdown item offer was presented or clicked. Reaching Grand is not a pass for this choice. |

## Eleven games

Wallets are cash/chips. Inventory is the actual item-ID list; a ticket pile
remaining after a losing scratch is expected and is not an extra payout.

| Game | Result against requested checkpoint | Wallet/inventory before -> checkpoint -> finish; once-only check |
| --- | --- | --- |
| Blackjack | PASS | D028 82/0, [roadside_map]. Real Deal27 ->55/0; D029 Save, reload/Continue and real reentry D031 retain55, inventory and RNG51389658. Stand -> natural final110/0; D033/D034 settled Save/Continue exact110, same inventory/RNG286569033, one55 return. |
| Craps | PASS, working bets | E024 68/50, [roadside_map]. Pass Line5, natural4 sets point4 ->68/45 with working pass5. E026/E027 Save/reload/Continue/reentry retain full checkpoint, RNG1847208678. Natural10 then7-out clears the bet, chips45. Separate Eye in the Sky Press on event adds15 cash ->83; E031/E032 settled83/45, same inventory/RNG893702950. No repeated stake/payment. |
| Pull Tabs | PASS, ticket in tray | A018 163/0, []; Buy1 ->162 and tray#010. A021-A025 Save/reload/Continue/reentry preserve same tray/pile/RNG63610128. Collect and AutoOpen ->$3 winner, then real Crew offer/return. Nell redeems exactly1 for3 ->165; repeat disabled. A033/A034 settled165/0, [], RNG1770357125 exact. |
| Scratch Tickets | PASS, unopened and partly opened | B004 93/0, []; real stocked Crossword15 ->78, pile_of_scratch_tickets. Unopened lift/tray saved/reloaded/Continued and collected. Normal drag exposes K I S J C N; B010/B011 Save/reload/Continue/reentry retain those6 letters and complete authoritative piles exactly, RNG1697019555. CLEAR ALL ->No Win, normal click files once. B013/B014 retain78/0, [pile_of_scratch_tickets], exact full piles/RNG; one filed loser, no active ticket, tray, winner or queued payout. |
| Slot | PASS, autoplay | B016 78/0, [pile_of_scratch_tickets]. Auto and Save while on: B018 cash76/spin1; another natural paid spin before page reload makes actual persisted B019 cash74/spin2. Continue/reentry resumes Auto; normal toggle stops at4 losing spins, coin_in8/out0 ->70. B021/B022 settled70/0, same inventory/RNG531710505, spin_count4/Auto false, no fifth debit. The intervening legitimate spin is not a restore loss. |
| Coin Pusher | PASS, supported floor-save bed | F019 47/0, []; real Drop1 ->46. Inside Save explicitly refuses and directs Resume ->Leave machine ->save from floor. Used that normal path F021, with coins on the bed. Reload/Continue/reentry F022 preserve the complete canonical machine/settled bodies exactly. Natural movement observed, Collect0 disabled. F024/F025 final floor Save/Continue46/0, [], RNG2104775536 exact; action_count1/total_cost1/total_payout0/drop_queue0/paid_drop_pending false. This does not claim an inside-machine save or native retention measurement. |
| Bar Dice | Narrower qualification; paid unresolved NOT REACHED | C normal Apartment ->Bar,165/0,[]. Ante22, cover, natural shakes, Settle/Slam/Lift ->pre-Call checkpoint is unfunded165. Save/reload/Continue/reentry retain it. Call funds and settles on one boundary, natural loss22 ->143. C016/C017 settled Save/Continue143/0, [], RNG1979461521 exact. No invented paid pre-Call state. |
| Video Poker | Held-card qualification; paid unresolved NOT REACHED | D018 18/0,[roadside_map]. Deal6 creates an unfunded active hand; held indices0/2. D019/D021 Save/reload/Continue/reentry preserve identical held cards/session/18 cash/RNG703209585. Draw charges6 and settles No Pay ->12. D022/D023 settled12, same inventory/RNG51389658 exact. Held-card restore passed; no claim of an earlier debit. |
| Roulette | Save-drain settlement qualification; unresolved paid file NOT REACHED | D037 160/0,[roadside_map]. Queued27 Red saved/restored. Confirm later shows133 during the paid read/payout window D042. Completed manual Save D043 already contains final187 for18 red; Continue D044 shows that same result, not another payment. D045/D046 settled187, same inventory/RNG1638000044 exact. Visually unfinished is not an unresolved saved financial transaction. |
| Baccarat | Save-drain hand qualification; unresolved paid file NOT REACHED | E039 23/145,[roadside_map]. Real110 Player wager/Deal then immediate Menu+Save while first cards move; screenshot041 still shows145. Decoded completed primary save041 already contains255 and final Player7/Banker3. Continue/reentry042 shows same result, one net110. E043/E044 settled23/255, inventory unchanged/RNG509283739 exact. Do not attribute another110 payment to Continue. |
| Crew Draw Poker | NOT REACHED | F normal Gas Parking Tip ->Punchline, two8-dollar drinks, real Side Door Follow the nod ->Hidden Casino. Actual Crew Back Room card F014 says Rook keeps it for made company or people he escorts. This fresh campaign had neither; no hand, paid street or settlement was reached. Gate wallet57/0, inventory[]. |

Bar Dice, Video Poker, Roulette and Baccarat retain their financial semantics.
CLOSE-06 does not change when they fund/commit or weaken a check to turn those
narrower observations into the requested unresolved paid-state passes.
The complete matrix remains open in BTH061-RC-ACCEPTANCE-COVERAGE-001/BTH061-006.

## New finding - BTH061-CLOSE06-SCENARIO-CONTINUE-001

OPEN: Gas Casino storm-shelter props/people disappear after Continue or a
normal event response. Exact NEXTa6ce512640cb, normal seedCLOSE061-NORMAL-A.

1. B003 initial afternoon storm shelter has rain shutters, shelter power
   panel, generator, safe-zone floor tape, family, sheltering drivers/supplies.
2. Buy stocked Crossword row4, normal Save ->page reload ->Continue.
   B006 still says Road flooded / Door stays open but those scenario visuals
   are absent. The78 cash and owned ticket are intact.
3. A016/A023 independently reproduce the Continue loss later in the evening.
4. F003/F004/F005 additionally show the same loss immediately after normal
   Parking Lot Tip ->Follow the tip, before any Save or reload.
5. Bar Fight and Grand convention rooms retained their scenario visuals in
   the exercised Continue paths; do not generalize this finding to every room.

Registered in both ledger views before any repair. Per the owner's CLOSE-06
rule, no fix was attempted here. Reproduction includes raw screenshots and
packed primary-save observations. No account/ticket loss was found in these
specific checkpoints. A separate product investigation is still required.

## Additional rendered CLOSE-03 evidence

F reached Delta Queen normally from the Lounge, used Walk the Deck, waited
through closing and used the real Dorian Pike Take the hint control.
F039 ->F040 departure map ->F041 free40-minute Gas walk ->F042 arrival.
Cash68/chips0/inventory[]/RNG522324453 unchanged. Remaining ride beats were0
before/after; native30/0 covers one/two-beat callbacks. Ordinary elapsed clock
time between screenshots is not callback turn evidence. See the single
CLOSE-03 proof for the precise native/rendered distinction.

## Remaining work for owner playtest

Recheck the Gas storm shelter after event and Continue; get a Jazz-addressed
package to the expired handoff; choose a genuinely offered owned Meta item
at showdown; enter Crew poker with real made status/Rook escort and save
mid-street. The four narrower save boundaries above remain clearly scoped.
Raw screenshots, profiles, storage/job/launch records and decoded saves stay
on E:. No raw evidence was added to Git.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: cl061-c06-a, cl061-c06-b, cl061-c06-c, cl061-c06-d, cl061-c06-e, cl061-c06-f, cl061-d-card-observe, cl061-e-table-observe, cl061-f-save-observe, cl061-c06-final-notes, cl061-f-account-proof, cl061-a6-next-identity.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\cl061-s06-proof\evidence\raw-evidence-index.json | 61d879e461bf568e1767049c83d6ccbc9445ed93475188c0cf613ce12a05f5b9 |
| E:\CodexQA\BTH\runs\cl061-c06-final-notes\evidence\campaign-counts.json | cd6440b010387a6e7c95cde06e4550ad5d208997e19ccda413bad59dfa63bf69 |
| E:\CodexQA\BTH\runs\cl061-c06-final-notes\evidence\acceptance-notes.json | 72b3234f199515a96c71715fbbdf633d81b4ac8e2e70b0afe63f185d885567a7 |
| E:\CodexQA\BTH\runs\cl061-f-account-proof\evidence\acceptance-notes.json | f8a66aee8726bf2583f8489f4c0135a403ccc0ae63ca334769151f05ca26eeef |
| E:\CodexQA\BTH\runs\cl061-c06-a\evidence\result.json | d7637aee65f82736ed292cae680502caef641972668ca71d28a6936f03c9fe1e |
| E:\CodexQA\BTH\runs\cl061-c06-b\evidence\result.json | 6fd6a23e11f120b9996be41725935e9717607bf9907998e9ba33a9f5c2fe5595 |
| E:\CodexQA\BTH\runs\cl061-c06-c\evidence\result.json | 11962dc7312d184b7438b09dca47bb34170ff7d8e997ec10893c27a0514c8dcb |
| E:\CodexQA\BTH\runs\cl061-c06-d\evidence\042-roulette-confirm-result.json | 19a464a81944c3e899a0cac5b838bf05e31c380fb617200926ec771ae87ce5bd |
| E:\CodexQA\BTH\runs\cl061-c06-d\evidence\result.json | 8064304d1eaa71c3db5dd1bed0ac8920fc76575d743cb1eebba7322b59189a82 |
| E:\CodexQA\BTH\runs\cl061-c06-e\evidence\result.json | 63fd8aa67089c606a355cac2d77189bc12c8683a8a2993ca6bd14ab53d07c500 |
| E:\CodexQA\BTH\runs\cl061-c06-f\evidence\result.json | b38c79b1e2839525a9ef4d0e8c63921fb1b9d4ea7077d8550d0773d32392d78a |
| E:\CodexQA\BTH\runs\cl061-c06-f\evidence\014-crew-back-room-gate.png | 0cadefee64515010a709efc04d2a2d164d940459a1461c2b473acead1edc3d43 |
| E:\CodexQA\BTH\runs\cl061-c06-f\evidence\039-delta-after-closing-action.png | c4f52763a6410a827027c4c9e3091cbbd141c92f99cb8493be1b762f9520e1d6 |
| E:\CodexQA\BTH\runs\cl061-c06-f\evidence\040-delta-take-closing-hint.png | e223d7646263d8a4d64e5d05fb541e99c7757614e5406c8a74dcb5f2dfd3b8b1 |
| E:\CodexQA\BTH\runs\cl061-c06-f\evidence\042-delta-closing-departure-arrived.png | 7fa0effe648306fb2feed18489ab206956d4d3fb0cbc1688f7b67f979c7e7e4b |
