# Bar Dice Reveal cold restoration — R17-B1330

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
