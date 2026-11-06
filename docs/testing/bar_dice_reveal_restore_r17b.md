# Bar Dice Reveal restoration, post-Call save and shutdown

## Qualified continuation

Current source and focused checks are committed as `753d6eb5d832695901fad640af3c6b557efbdc48`. All three named items remain
Open: main publication succeeded, but the existing automated NEXT publisher failed before promotion on both44ea andCBC. The original accepted-ante fix remains associated with
`eba4663b52b6152eff814231c76ce093bf7d4afa`; its earlier release receipts are retained.

| ID | Current outcome |
|---|---|
| BTH061-BAR-DICE-REVEAL-RESTORE-001 | Accepted cup restored; one legitimate post-Call Menu Save/cold Continue qualified; fix/diagnostic commit associated; NEXT publisher blocked. |
| BTH061-BAR-DICE-SHUTDOWN-001 | Causal final-frame autosave ownership defect corrected; successful/failed-write teardown checks clean; commit associated; NEXT publisher blocked. |
| BTH061-BAR-DICE-COVER-DISPLAY-001 | Wrong values not reproduced. Actual native text and high-density Web capture show6/6/0. No display patch justified; diagnostic commit associated; NEXT publisher blocked. |

The companion JSON preserves every command, source identity, original
observation, failed process and closure. Its `continuation_20261106` records
the current findings; the older narrative below is explicitly historical.

### Post-Call Save/Continue

The single new seed `BTH061-BAR-DICE-POSTCALL-QUAL-002` used a fresh private
catalog fixture. Warm86/0 assertions saved an unfunded Reveal, then the pre-fix
process suffered the retained shutdown crash. It did not Call and is not a clean
runtime pass. Fresh cold60/0 restored Reveal6 under floor10 with exact dice/cash/RNG.
Its one Lift/Call charged6 once, naturally settled to88, recorded one round and
one game-action row, cleared the pin/delivery and used normal Menu Save from GAME.
No natural event appeared; no event was forced or answered.

Separate read-only cold Continue30/0 preserved exact account/root RNG,
table/result/dice/clock/story and one round/action. Another read-only Continue
on the new exit barrier also passed30/0. No prior unsaved Call was replayed.
Initial Reveal ledger validation stays strict. Post-settlement checks permit
only valid completed/delivery-free ledger retirement after a normal checkpoint
change; they cannot excuse an open cup, pin or pending delivery.

### Native shutdown cause and correction

A bounded address-only debugger captured22 frames. Local PE/RTTI/instruction
mapping and exact Godot4.6 source identify late WorkerThreadPool task cleanup
releasing a GDScriptInstance after the language singleton was deleted. The
main-thread fault is `ntdll!RtlEnterCriticalSection+0xD`, writing0x1b0. No addon
ownership is inferred from this stack. See the private receipt indexed in JSON,
the [instance destructor](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/modules/gdscript/gdscript.cpp)
and [worker cleanup](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/core/object/worker_thread_pool.cpp).

The weak-reference probe established ownership: in frame605 the early wait saw
taskID-1, completed generation4 and pending dirty generation5. After `queue_free`,
the Host still processed and started task2. At `tree_exiting`, after its old exit
hook, task2 was in flight. Two frames later the Host was gone while service/task
survived. That run passed84 assertions then crashed. A fresh unchanged-product
control joining only that same known service preserved84/0 and exited cleanly.

The seven-line production fix in `FoundationMain._exit_tree` waits on its current
owned SaveService generation after existing cleanup and reports a real failure
through generic error logging. The immutable snapshot is released while the
script runtime exists. It starts no new Save, sweeps no global tasks, changes no
counters and disables no processing. No engine/toolchain change was made.

Candidate checks all have actual native exit0/owned0:

- Observational race84/0: no test-side extra drain, tree-exit taskID-1 and no
  surviving service after Host destruction.
- Explicit `require_host_drain` regression86/0 asserts reclamation, success and
  release. Historical observe/drain modes remain available.
- Original uninstrumented warm83/0 now exits cleanly on the former crash route.
- Failed-write lifecycle28/0 retains `ERR_CANT_CREATE`/false outcome, clears the
  task and preserves exact prior primary bytes, before any test-cleanup join.
  Its generic production error log is expected fault-injection evidence.
- Existing newly paid outcome read-only Continue30/0 remains exact on the barrier.

Host physical source SHA256:
`b043774574980bf2535324ff46b42e0f483c630e7992967036a08d5d0b8a8072`.
The Bar Dice implementation and its funding/payout/authority rules are unchanged.

Failed diagnostic attempts remain failed: initial debug setup stopped before
fixture execution (CPU0/stdout0); a later real-engine control timed out180s with
no result or AV; a child-only heap setting reproduced83/0 plus the actual crash;
the bounded collector's priming correction exposed the callers. No exit was
suppressed. Failed-write fixture26/1 incorrectly required a text error field the
async API does not propagate and freed before normal UI readiness; corrected
fixture28/0 uses the ready UI and actual numeric error contract. Production
prewarm/error transport were not altered.

### Cover/risk disposition

Fresh Practice94/0 traces authority, module, host, retained Canvas and actual
normal draw text6/6/0 in unfunded phases. The new catalog warm saved Reveal and
fresh cold floor10 case also record actual6/6/0. The warm witness is a retained
actual draw; the cold witness is a fresh-process draw before its only Call.

The original1280×720 PNG digits remain ambiguous even at image-viewer zoom;
their apparent zeros did not establish a wrong-value error. Those originals
were not edited. A cold Web check reopened only the task-owned never-called
profile on exact `7d4b121fe8448d9a66ce6366218b470533424ed7`, without import,
Save, Lift/Call, wager or event choice. Fixed CSS1280×720/DPR2 produced an actual
2560×1440 canvas backing and PNG. Root and two independent reviewers clearly read
**COV $6 / RISK $6 / RET $0**, wallet94/ante6 and the same visible cup dice.
The browser closed cleanly without a public error. This is a fresh high-density
capture, not an upscale of the old PNG and not a portrait/layout application change.

The conditional investigation therefore needs no product display patch. Closure
will associate its own diagnostic/evidence commit and required delivery, retain
the old readability limit and avoid categorical reinterpretation of old pixels.
No legibility redesign is included.

### Delivery and limits

Both task views preserve283 unique IDs: all prior282 plus the named shutdown
batch. All41 completed owned jobs ended with zero remaining processes, using
actual3% native/12% Web CPU and2GiB limits assigned before execution, kill-on-close
and no breakaway. Resource closure never converts failed runtimes into passes.

The qualified source is committed as `753d6eb5d832695901fad640af3c6b557efbdc48`; authorized main publication and exact NEXT remain pending at this checkpoint. Earlier
exact build/asset/startup and Web Menu Save/cold Continue receipts retain their
original identities. The exit barrier alone does not establish browser unload
or IndexedDB durability. Native fixtures use explicit engineering clocks and
renderer callback inputs, not OS-pointer or original-player proof. The new
post-Call qualification is one no-event route; the earlier Health Inspector
blocked cases and unsaved88 outcomes remain historical failures, not replayed.

Original tester profiles/saves/keys/actions and both denied document reads
remain untouched. Original forensic attribution remains limited. Raw saves,
authority contents, bundles and dumps are not committed. The existing watcher,
private audience, stable and itch channels were not changed.

Manual reconciliation at 2026-11-06T05:39:12.182449Z: **0 findings for these three items**, with **357 findings across 45 other IDs** retained. Their aging observations and work states were not changed.

### Publication recovery checkpoint

Main `44ea53510d2d282b35089f6b2bf0482822b7bd2a` contains the qualified fix. Its export and1166-file PCK audit passed, but the existing installer failed at its local QA read grant before promotion; NEXT retained7d. The original helper stderr was not retained, so its precise cause is unknown.

One exact retry of the existing unmodified helper succeeded: exit0, Verifiedtrue,18items, fixed QA ReadAndExecute only, owner/protection/other rules preserved. This did not promote NEXT. The installed immutable44ea/provenance remain preserved; the original ephemeral ZIP was already removed, and a normal timestamped rebuild cannot replace that archive hash. This evidence-only checkpoint gives the existing watcher a fresh main SHA. No manual export, pointer write, pipeline edit or watcher restart was used. All3 IDs remain Open until actual descendant identity/assets/startup and final reconciliation pass.

### Final publisher blocker

Published main is `cbc90bd417c862fa4fc8ce2f586a40185b93d4a7`, tree `1232882f2ecf0acc829c9fc518f1b0990d6a262c`, containing tested fix `753d6eb5d832695901fad640af3c6b557efbdc48`. Its new export and1166-file PCK audit passed, then the same existing automated QA read-grant command returned1 at2026-11-06T06:04:09Z before promotion. NEXT still serves7d. The helper stderr was not retained, so the underlying reason remains unknown; the earlier exact44ea manual helper retry proved RX18items only and did not promote NEXT.

Exact current served identity/startup was not qualified; no Job42 was launched. All41 task-owned Jobs remain ended with0owned processes. All283 task IDs and failed/runtime/old-pixel evidence remain preserved. No third immediate metadata push, manual substitute export, immutable replacement, pointer write or watcher/infrastructure change was attempted. This final evidence checkpoint is local; the tested code is already on main. Existing publisher owner must diagnose the automated grant failure and recover normal promotion, then exact identity/assets/startup and final reconciliation can close these3 items.

Final manual reconciliation at 2026-11-06T06:07:35.107467Z: **0 findings for these3 IDs**, **413 findings across 47 other IDs** preserved. Local Git association verification enabled.

## Historical checkpoint through 7d

The following preserved narrative describes the earlier checkpoint and its
then-open limitations. The qualified continuation above supersedes its current
status statements without deleting the observations or failed results.


**BTH061-BAR-DICE-REVEAL-RESTORE-001 remains Open.** The confirmed accepted-ante defect is fixed in `eba4663b52b6152eff814231c76ce093bf7d4afa` and deployed through `1adcf4f9980f0f14c2d46d4c31b30a024c688982` to NEXT. Exact served assets, startup and an isolated browser Menu Save/cold Reveal check passed. Full native process and post-Call final-save acceptance remain open.

## Original observation and protected evidence

The permitted report is `C:/Users/theep/Documents/Codex/2026-10-26/task/qa-r17b-1330-result.json`, SHA256 `5da6a64292481211104a0faf93a4277490947da413df6cb7960ecab826e64654`. Observed source was `ac877121d68561c818f39fe3c81b892e8a13b932`, tree `42aa5865e8e64e32d6c2cdf22440a76a3ae5334d`. The companion JSON retains the report and original image references.

At wallet $94 and ante $6, Roll Cup/Take Cover opened an unfunded cup. Shake Save 1328 at 02:15 cold-restored 1329 with the same dice, ante $6 and cover $6. The two remaining Shakes, Settle and Slam Cup reached Reveal. Save 1329 recorded 05:30; the later save-ready image showed 05:45 after Resume. Cold 1330 returned Agree Wager, default ante $20 and cover $0, retaining wallet $94. No Call, new hand, refund, payout or explicit Save followed the reset; no funded money loss is claimed. Bar hours were 11:00–03:00.

The original resident profile, save, authority key and actions were never read, copied or opened. The separately denied ac877 manifest read was never retried or bypassed, and its original launcher was not run. A direct read of the new build's `BUILD.json` also returned OS AccessDenied and was not retried or fetched through another path. The independently prepared normal game asset `build_manifest.json` is a different document; its public request succeeded and matched the pipeline receipt.

## Confirmed independent mechanism and narrow fix

One predeclared catalog fixture (`BTH061-BAR-DICE-VENUE-TERMS-001`) used production WorldMap/RunGenerator with Bar Wake, Payday, clear weather and no happenings. It produced wallet $94, floor $6 and ante ladder 6/10/20/40/46. Clock inputs 23:00 and Day 2 05:30 were deliberate engineering setup, not natural elapsed play or the original player state. No seed or outcome search was used.

Official Save/Continue retired the venue scenario, changing floor 6 to 10 and ceiling 46 to 60 while retaining the exact accepted cup and valid bound/checkpoint ledger. Baseline cold checks recorded 30 assertions with one real failure: canonical Reveal, dice, money and root RNG matched, but the rendered UI reset to Agree Wager because fresh-limit validation rejected the accepted $6 cup under the new $10 floor. This confirms a responsible production mechanism matching the report. It does not establish the original scenario/day type or raw rejection branch.

The Bar Dice fix records the agreed ante only after current fresh admission. It honors that exact stake for the actual RunState's validated canonical accepted cup, including raw phase, dice, shake/rung indices, binding and version. Valid legacy cups without a pin use the exact retained rung; a malformed present pin cannot use the legacy fallback. Borrowed environment ledgers and forged UI state are rejected. The pin clears after settlement, new selection or unfundable recovery. Fresh wager limits, capacity/funding, cold checkpoint validation and delivery replay protections remain in force. No time, RNG, rendering schedule or payout authority was rebased.

## Tests, failures and acceptance limits

- Clean focused native checks: accepted ante **21/0**, existing surface restore **26/0**, pending recovery **14/0**, unaffordable ante **17/0**.
- The synthetic Practice warm Save/Continue control passed **72/0**. It is distinct from the catalog fixture and original player route.
- Legacy and new-format cold cups restored actual Reveal at $6 under the new $10 floor with exact dice, cash and RNG. One Lift/Call charged $6 once, settled one round to $88, removed the pin, and exact delivery replay duplicated no debit, result, history or RNG.
- The legacy cold run retained **45 checks / 1 failure** when Menu was attempted before result animation expired. The new-format cold run retained **45 / 1** when a normal Health Inspector prompt paused the animation and prevented final Menu Save. No prompt choice, new paid input or Save followed.
- The read-only settled follow-up retained **19 / 1**: its expectation of automatic outcome Save was wrong. Storage still held the prior accepted $94 Reveal, zero rounds and zero game actions. The unsaved $88 outcome is not claimed persisted, and this does not establish a second save defect.
- Both baseline and candidate catalog warm runs reached **83 assertions / 0 assertion failures**, then crashed with native **0xC0000005 / signal 11** during final shutdown. These are failed runtime qualifications. Prewarm join did not resolve the crash; the 28-frame unsymbolized traces provide no demonstrated ownership correction. No forced exit, suppressed status or speculative engine/native fix was used.
- Earlier parser, JSON numeric-comparison guards and probes of an intentionally zero legacy cost API remain recorded. Corrected checks use normalized JSON comparison and the actual sealed stake provider. All failed fixtures and process receipts are retained in the companion JSON.

Required remaining work is a legitimate new independent post-Call prompt/choice, normal Menu Save and fresh Continue, without replaying either previous unsaved Call, plus a supported disposition of the baseline/candidate native shutdown crash. Neither gap is waiting for the original user save or permission. The full objective is not Complete.

## Main and exact NEXT verification

GitHub main was observed at `1adcf4f9980f0f14c2d46d4c31b30a024c688982`. The existing watcher deployed it at **2026-11-06T03:17:02Z**, tree `6c47a4721f222e2b1cc3020fa7982983906229ec`, source dirty false. Standard served manifest, PCK and native WASM hashes match the staged pipeline receipt; the immutable PCK audit passed. The title image showed `Version 0.6.0-dev+1adcf4f9980f`. The private audience and existing watcher were unchanged; no stable/itch/mirror upload was requested.

The task's independent retained Reveal fixture was officially converted from its custom save slot to `foundation_ui_autosave`; the preparation job passed **36/0**, with zero game inputs and no Host Continue in that preparation job. It generated new default companion settings/meta/profile and byte-copied only its own authority companion. Original tester data was not used. Raw saves, authority contents and the bundle remain private and are not committed.

In a fresh isolated browser profile, a create-only HTML adapter preloaded those five integrity-checked independent files before engine start. Official JS/PCK/WASM bytes were unchanged. Normal Continue and Bar Dice entry showed **Reveal, ante $6, wallet $94, pot $24 and cup dice 6/4/2/5/2** after closing time. The operator reviewed the card and Reveal PNGs, opened the normal Menu and selected Save. The full acknowledgement PNG returned to the same Reveal at **06:45** before browser close.

A second cold launch used the same private browser profile, the official HTML and **no fixture import**. Normal Continue loaded **06:45**; cabinet entry at **08:15** still showed Reveal with ante $6, wallet $94, pot $24 and the same visible dice. No Lift, Call, wager, ante change or event choice was made in either Web job. Both completed, closed and exited zero with no public errors or remaining owned processes. This is deployed engineering-fixture behavior acceptance, not original-player forensic proof or post-Call settlement-save acceptance.

Evidence: companion `bar_dice_reveal_restore_r17b.json`; task-local `evidence/bar-dice-served-1ad.json`; E evidence root `E:/CodexQA/BTH/Task14Independent/20261106/bar-dice-reveal`, including `web-startup-1ad-1`, `web-reveal-1ad-1/create` and `/cold`. Their exact screenshot hashes and Job receipts are recorded in JSON.

All **20** task-owned Bar Dice Jobs ended with `active_at_release=0`: 17 native and 3 Web. Actual limits were 3% CPU/2 GiB for native and 12%/2 GiB for Web, assigned before execution with kill-on-close and no breakaway. Job closure does not turn failed native exits into clean passes. Both named task lists preserve all 281 existing unique IDs; this item retains the fix commit and Open acceptance gaps.

Manual task reconciliation at 2026-11-06T03:55:38.423861Z: **0 findings for this task**; **332 findings across 43 other task IDs** remain visible in the referenced output. No other task state or ownership was changed.

## Open cover/risk display follow-up

**BTH061-BAR-DICE-COVER-DISPLAY-001** is registered Open in both task lists, with no fix commit. Both Web Reveal PNGs also show **COV $0 / RISK $0 / RET $0**. Read-only source review at `dff23f66e6ecf60a31b5b4c65b7509dc8e0df883` expects cover6/risk6/returned0 for ante6 in Reveal; this is not intentional unfunded normalization in the reviewed producer/projection code. The actual field-loss boundary is not established. No speculative patch, lost-custody claim, debit claim or further gameplay input is justified. The next action is a narrow independent nonfinancial surface-field reconstruction. The parent remains Open.

The documentation-only checkpoint `dff23f66e6ecf60a31b5b4c65b7509dc8e0df883` deployed at 04:02:27Z; exact source/tree, navigation and fresh title startup passed with zero inputs/imports. Its final startup Job exited0/owned0, bringing this investigation to **21 ended Jobs (17 native, 4 Web)**. The earlier twenty-job checkpoint remains historical. Exact final receipts are in the task-local outcome/served files referenced in JSON. All **282 unique IDs** now retain the prior281 plus this named follow-up.
