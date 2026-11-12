# Beat the House unfinished-features queue — owner handoff, acceptance still open

Date:2026-11-12. This queue is **not finished**. Source fixes and several
rendered checks are complete, but delivery, the pack decision and heist play
acceptance remain open. No pending item is labelled Complete in the ledger.

The earlier0.6.1 closeout was delivered before this queue began; its frozen
candidate/packages are preserved. See [the prior owner closeout](BTH_0.6.1_owner_playtest_closeout_2026-11-11.md).

The supplied audit is committed unchanged at98088acb, SHA-256
`280578df8283159701e6853636e10dc6a34e92fddf1df74d6c5992bbb4a955e1`.
Its first-publication ordering mistake is recorded below. Work uses the
isolated E QA clone; the original dirty D checkout is preserved.

## Every index item

Commits are source/proof then paired ledger unless indicated. NEXT remains
[served070fc937](http://localhost:8088/p/beat-the-house/play/dev/070fc937ad69de8d152b0dddae769f5206704821/).
The newer report/code commits are delivery-pending; existing behavior observed
on070 is identified separately.

| Item | Status | Commits | Proof / NEXT result |
| --- | --- | --- | --- |
| FEAT-01 | Moved to0.6.2; no effect work authorized | da53957d /8d40250f, plus schema bookkeeping in this checkpoint | [Future queue](FEAT-062_queue_record_2026-11-12.md); record pending delivery |
| FEAT-02 | Investigated partially; Whale normal play NOT REACHED | f853fa69 /1f70b2e4 | [Combined report](FEAT-02_FEAT-07_private_heist_investigation_2026-11-12.md); native app access pending; no enablement on main |
| FEAT-03 | Source fixed and checked; NEXT acceptance open | a875a68f /964d6df4 | [Daily seed](FEAT-03_daily_local_calendar_seed_2026-11-12.md); new scheme not yet served |
| FEAT-04 | Closed as not wanted by owner; documentation delivery open | f12f8fa1 /fd8bb158; hold b4e0a00f /cbcb6784 | [Disposition](FEAT-04_collection_controls_not_wanted_2026-11-12.md); no collection controls built |
| FEAT-05 | Out of scope; scenario walking remains paused | — | Unchanged audit; no work |
| FEAT-06 | Out of scope; art required | — | Unchanged audit; no art/placement work |
| FEAT-07 | Investigated partially; full Count measurement NOT REACHED | f853fa69 /1f70b2e4 | [Combined report](FEAT-02_FEAT-07_private_heist_investigation_2026-11-12.md);48 batches /86 inputs on070, no full-route pass |
| FEAT-08 | Moved to0.6.2; owner by hand | da53957d /8d40250f, plus checkpoint schema bookkeeping | [Future queue](FEAT-062_queue_record_2026-11-12.md); no worker copy pass |
| FEAT-09 | Wedding visible acceptance passed; Arrival source fixed; delivery/Arrival Web acceptance open | Wedding3f08a8e8 /babc66ea; Arrival9ebce330 /2495b47e | [Wedding](BTH-SCENARIO-WEDDING-001_visible_completion_2026-11-12.md), [Arrival](BTH-SCENARIO-ARRIVAL-002_layer_arrival_order_2026-11-12.md); Wedding on070, new Arrival behavior pending |
| FEAT-10 | Three older bugs not reproduced in stated current samples; documentation delivery open | c4653b3e /bc75a739 | [Rendered rechecks](FEAT-10_older_bug_rechecks_2026-11-12.md);070, original-seed limits retained |
| FEAT-11 | Stopped before edits: reproduced specification conflict |81cae8af /d95c817d | [Pack preflight](FEAT-11_pack_defaults_preflight_2026-11-12.md); defaults unchanged; merchant decision pending |
| QOL-06 to QOL-10 | Out of scope / not wanted now | — | Existing records retained; no plans or implementation |
| Section6 | Out of scope: owner/platform/human work | — | No accounts, platform calls, signing, human test, Act2, art or publishing work |
| Section7 | Out of scope: deferred campaigns | — | No economy, broad performance/platform, long audio or full named campaign started |
| Section8 | Closed as stale in source where supported; documentation delivery open | e52741c9 /7c0d0b17; hold da990b9c /87611c65 | [Closures](FEAT-STALE_plan_closures_2026-11-12.md); nine rooms rendered on070; limits below |
| Section9 record | Five open future decisions recorded; no work authorized | da53957d /8d40250f, plus checkpoint schema bookkeeping | [Future queue](FEAT-062_queue_record_2026-11-12.md); no future objective Complete |

##1. Whale and Count investigation

Private branch `local/feat-02-07-investigation-20261112` contains only the
two approved release-gate edits at8cf74d0c4407161b8c04c3012b386304e5a7bab9.
That commit is not an ancestor of main and was never pushed/merged. Main
still exposes only The Count. No item, trust, pacing, scenario or math change
was shipped from the investigation. Nonpublic resolution data was not collected.

Whale's public authored prerequisites include its Whale/Gala opportunity,
Velvet's Inner Circle standing and vouch/rig/name setup. Those are static
observations. The native source window was launched, but Computer Use timed
out awaiting app access before the first gameplay input. Thus its actual
observed stop is a tool-access boundary, not a confirmed gameplay blocker.
Its ending and the later authored phases remain unplayed.

A separate Web-export attempt failed because the guarded fresh AppData lacked
the pinned template. Automatic approval review rejected the proposed exact
E-template copy as a prohibited build workaround before execution. That action
was not retried or routed around. Native source play requires no template.

The Count received a genuine fresh-profile browser attempt on070/seed0002.
Normal opening: Back Alley -> Pawn -> Corner -> Gas -> Motel -> Bar -> Lounge
-> Grand. Cash100 ->73 after fares, then123 after the normal invitation.
Grand travel was free. Day1 Audit / Read the shift succeeded at cash123,
chips0, Heat11. The normal10-dollar Punchline trip left113; Try the word
entered Casino. The private door then required made company or Rook's escort.

The ordinary Crew offer added70 (cash183), and after a real layer revisit a
normal delivery was accepted for Lounge, Day2 13:00-13:30. The map showed
Lounge closed until13:00. The18-minute session ended before that handoff.
There were zero page/console errors and final owned active0.

| Count segment | Input batches | Individual inputs |
| --- | ---: | ---: |
| Run setup / seed |2|11|
| Opening / invitation |19|30|
| Audit roster |2|4|
| Punchline access |5|8|
| Private door / Crew offer |7|10|
| Ordinary layer revisit |6|10|
| Delivery / route |4|8|
| Package/lookout attempts |3|5|
| Total applied |48|86|

This is83 clicks, two keys and one text entry. It is not the game's
authoritative gameplay-action count and cannot replace389 bridge /164
gameplay actions from the historical full run. A later wait command did not
complete and is excluded. No successful lookout result was confirmed.

Not reached: Planning Table, pre-lock Save/Continue, schedule, cart, the three
Hold -> Sit -> Dock hands, getaway or terminal report. The current ending
walkthrough omits the private-door access prerequisite; its mismatch is
registered separately without weakening the valid guard.

A fresh resident Count campaign was also attempted using existing storage,
custody and capped-Job APIs at the same CPU/memory/time limits. It served only
the already-deployed070 payload through a read-only loopback QA origin.
Both bootstraps failed before gameplay (no initial page, then navigation
ERR_ABORTED); neither profile was resumed or migrated, both are unclean,
and both owned Jobs ended active0. The supervisor's mistaken interpretation
of drain()'s return is retained as a harness error. This is not a gameplay pass
or a NEXT delivery workaround.

Remaining work: obtain native app access and perform the real fresh Whale
attempt; establish and replay Count's legitimate access route in a qualifying
campaign; measure all required beats and persistence; explain the older golden
mismatch. Reserve1-2 working days for that play/analysis, with low confidence.
Remedial engineering cannot be estimated before the unplayed phases are reached.
Recommendation: retain Count-only shipping and keep Whale/trust restoration
for the owner decision after actual play. There is no evidence here to remove
any required heist beat, alter wagers or make a pacing change.

The private information contract passes. Direct ambient/world no-op checks and
same-seed twins pass, but the older saved golden reports61 differences on
private8cf, main2495 and the post-hoc pre-feature070 control. Its cause remains
open; no fixture was refreshed. Existing synthetic Count accounting passes70/70.
These checks do not certify a rendered heist ending.

##2. Pack defaults: current behavior and exposure

Neither flag has changed. In production ContentLibrary, enabling both defaults
adds18 sellable items to ordinary merchant pools:13 souvenirs and five bench
outputs. The nonsellable Crew package is excluded. This contradicts the
specified route-only/shop-unchanged acceptance, so the item stopped before edit.
Owner decision is pending: allow narrow merchant exclusions plus the defaults,
or retain the old defaults for further review. No saved choice is overridden.

With packs off, the qualified native Mags catalog still offered all five recipes.
The rendered fresh default-off Count attempt also accepted a normal delivery and
showed carried Package controls/marked target. It did not complete a handoff or
inspect an exact inventory ID. Scenario souvenir acquisition with packs off is
still unverified: the earlier detached reward/craft fixtures failed authority
setup, and the rendered free Wedding branch granted no souvenir. Those are
not reported as reward failures or passes.

If defaults are later enabled, they expose the parked claims on Wedding Ribbon
Favor and Rent-Party Hat Pin (+1 luck not applied on scene grant), and Mags'
Lined Sleeve (Slot bonus ignored). The owner was informed; no effect, price or
text repair was attempted. No newly default-enabled item is claimed in this run.

##3. Findings from play/checks outside the static audit

| ID | Reproduction / disposition |
| --- | --- |
| BTH-FEAT-PRACTICE-FEEDBACK-001 | Environment Library: act in Motel Service Wing, then spawn a different fresh room/seed; the previous Result acknowledgement remains. Also observed Lobby Jammed -> Stakeout. No financial loss observed; open, no fix. |
| BTH-FEAT-PACK-MERCHANT-001 | Load production library with current flags, then with the two groups enabled; ordinary pool gains18 entries. Reproduced specification conflict; owner decision pending. |
| BTH-FEAT-COUNT-ACCESS-GUIDE-001 | Fresh0002, normal invitation and Audit knowledge, Punchline/Try the word, Crew Back Room: door requires Made/escort, also after the ordinary Crew offer. Public walkthrough omits this gate. No claim that all legitimate access routes are impossible; open for route/guide reconciliation. |
| BTH-FEAT-NOOP-GOLDEN-001 | Existing saved-golden comparison reports61 differences on pre-feature070, main2495 and private8cf; direct no-op/twin checks pass. Pre-existing test discrepancy, cause unresolved; no golden rewrite. |

The previously open `BTH061-CLOSE06-SCENARIO-CONTINUE-001` and deferred
closeout coverage/retention rows are not closed or silently reworked here.
BTH-11 and the item-effect findings remain open under their owner decisions.

##4. The recorded0.6.2 queue

| ID | Item | Owner / authorization |
| --- | --- | --- |
| FEAT-01 | All-item reassessment, parts A-E, including BTH-15/BTH-17/LEDGER022 | Owner first, then worker; no work authorized |
| BTH062-SCENARIO-POLISH | BTH-11 scope/polish | Owner states scope first; existing pause retained |
| FEAT-08 | All0.6 voice/copy work | Owner by hand; no worker work |
| BTH062-DAILY-LEADERBOARD | Local in-game Daily leaderboard | Needs design; no online work |
| BTH062-WHALE-TRUST-ARC | Whale and Crew trust arc | Owner after completed investigation; no enablement/restoration |

All five are open in both ledger views. The schema allows only current/historical
groups, so0.6.2 is recorded in status/text with the explicit user no-work policy.
Their task reference identifies this decision/recording conversation, not a
future implementation assignment. No future objective is Complete.

##5. Verification, delivery, limits and departures

The only new product edits are Daily's full-local-date hashed seed and the
layer-arrival transaction flush/rollback. Runtime diff is five files including
three test files; no item/scenario data, pinned project/export file, builder,
version, odds, payout, RTP or EV change is present.

| Check | Before / baseline | After / scope |
| --- | --- | --- |
| Smoke | Initial E setup9/11, loader831; Daily10/11, loader832 | Arrival candidate11/11 exit0, loader833/0 failures |
| Daily focused |14 pass /4 fail |18/18, full local year/date, legacy in-progress seed retained |
| Bringer focused |21 pass /4 fail | Original25/25; extended57/57 with Continue, completion, refusal, revisit and rejected-arrival rollback |
| Animation liveness | Existing no-input requirement retained | PASS after Daily and Arrival; no animation/scheduling suppression |
| Wedding existing controls | Existing fix already served | Native56/56 plus rollback29/29; rendered success, Save/Continue, departure/revisit on070 |
| Python in candidate validation | Three maintained suites |10 +25 +10 all pass |
| Count accounting | Existing synthetic control |70/70; no historical payout replay |
| Private information / direct no-op | Existing checks unchanged | PASS; saved-golden comparison remains61 differences as above |

Initial baseline failures were QA setup/host gating, not evidence of new product
failures: one omitted native descriptor was restored from the exact qualified
E package; isolated native perf then passed. Daily's full run recorded a cache
tree mutation guard failure; the unchanged isolated validator retry passed with
zero observed cache changes. Neither earlier red run is relabelled green.
The later full candidate Smoke genuinely passes all11 stages. No check was
deleted, skipped, loosened or updated merely to get green.

Wedding's normal path completed Secure -> Save/reload/Continue -> Recover ->
Steady -> Leave him smiling -> Deliver. Cash stayed52 and inventory0, then a
normal10-dollar deck walk left42; Beach/Delta revisit retained42 and no new item.
The first navigation attempt did not reach Deliver and remains labelled that way.
This chosen branch grants no souvenir; positive souvenir acquisition is not proved.

Section8 rendered all nine named rooms; three Motel aftermaths were reached.
`stakeout_interrupted` was not reached (the tried exit selected refusal), so
no four-of-four aftermath claim is made. BUG-10/34/37 were not reproduced only
in the recorded1280x720 current samples; the September seeds were not replayed,
and practice at noon is not an active-night travel proof.

NEXT's existing watcher refuses the new import inputs with:
`Asset/importer/settings inputs changed; cold-import qualification required`.
The exact unchanged classifier inventories contain1420 rows before/after and
differ only at the required root README.md closure note. The earlier claim
that the Crossword CSV caused this hold was wrong: docs/ is excluded. Dated
errata are in the proofs. No classifier, pin, cap, reserve, template, security
setting or audience was changed.

The previous request for114aa355 was prepared on E but not submitted. The
publication checkpoint supersedes that exact target; a fresh E request/receipt
will identify the pushed head. No D operational request file is written without
the owner-selected one-file exception/submission. New Daily/Arrival behavior
has not been claimed as verified on NEXT.

Reconciliation uses the documented historical owner/runtime snapshots and its
explicit reference time. After correcting assigned metadata, it reports1681
inherited errors/0 warnings and zero findings for this queue or the two resumed
scenario IDs. This is a scoped historical-snapshot reconciliation, not a new
whole-machine runtime census. Initial unsupported kind/group labels were caught
and corrected to the existing schema; the checker was not changed. Only the two
explicit scenario exceptions were removed from the active pause list, with
original IDs/history retained; the broader pause remains.

Other departures/limits:
- The first local audit commit2b8b0a6b was excluded by the initial temporary
  upstream/forkpoint integration, so registration reached main first. The exact
  audit was restored append-only at98088acb before product work. No published
  history was rewritten or force-pushed. This violates the requested first
  published ordering and is acknowledged.
- New raw captures were minimized where an over-broad CSV/formatting diagnostic
  included irrelevant static fields. Original hashes/failure status and the
  minimization receipts are retained; no historical committed evidence was removed.
- The0.6.2 raw-index appendix was added with its paired ledger commit; current
  metadata corrections are append-only. No false completion state was introduced.
- AGENTS.md was read and followed for ledger continuity, storage and liveness.
  No substantive conflict with the owner-authorized scope required departing
  from AGENTS.md. The owner table overrides the audit's older implementation text.

## Owner playtest / resumption checklist

Once NEXT qualification promotes the public head, verify the exact identity,
Daily's fresh-start date behavior and the Bringer return case. Recheck that a
return before accepting the first rope does not fail the later task, while a
real return during work_1 still applies its authored pressure. Continue/revisit
must not replay settlement. Then finish Whale and Count normal-control play.

The other visible change candidates remain unshipped: pack defaults need the
merchant decision. Keep the three parked item claims, practice Result carryover,
the stale Count guide and golden discrepancy on the open-findings list.
Do not enable Whale, change effects or begin the0.6.2 queue.

## Evidence retention

Each task proof above contains external raw paths and SHA-256 indexes. All new
raw logs, manifests, screenshots, launch receipts and QA profiles stay under
E:\CodexQA\BTH and are excluded from commits. The failed resident profiles are
unclean and were not reused. Prior committed evidence and closeout packages
were preserved. The following checkpoint index covers the final metadata/test
scope observations; later publication/request receipts remain external until
the next delivery checkpoint.

<!-- CURRENT_REPORT_END -->

## Historical intake record

The following is the earlier intake/progress record. Its pending statements are
historical; the current status and limits above govern this handoff.

# Unfinished-features queue — execution report (in progress)

## Intake and governing scope

Starting delivered closeout: d8c215142436d8881fb5edae4d06cf86f96ca9b5,
NEXT current with no pipeline error. The completed closeout receipt remains at
E:\CodexQA\BTH\runs\cl061-final-handoff\evidence\final-handoff.json.
Its acceptance findings remain separate and open as previously recorded.

The supplied audit was missing. Saved exactly as supplied and committed first:
2b8b0a6b77219dfdbc93dc7c4d772d6702c0e010.
Audit SHA256:280578df8283159701e6853636e10dc6a34e92fddf1df74d6c5992bbb4a955e1.
Read the entire audit, then AGENTS.md. The owner decisions at section0 override
older recommendations below. AGENTS.md controls storage and animation liveness;
no disagreement requiring a departure has been found.

Implementation workspace is a fresh E clone, leaving the closeout candidate,
its packages, previous QA profiles/saves and original D checkout edits intact.
Guarded setup reserves8GiB for toolchain/build copies plus unchanged20GiB
headroom. Ordinary bounded QA retains4GiB expected writes,20GiB reserve,
12% CPU and2GiB memory, assignment before execution and owned cleanup.

Nine authorized objective IDs and their bounded batches are registered in both
ledger views before implementation. The global item/scenario pause remains.
Only FEAT11 defaults and the two named FEAT09 scenario rows are exceptions.
All item effects/prices/text, math, out-of-scope features and pipeline settings
remain outside authorization. Private Whale enablement will use a separate
never-pushed branch; only its public-behavior report can reach main.

## Before / baseline

No product implementation has started. A fresh full Smoke baseline is pending
completion of the isolated tooling copy. No stale-plan room entry has been
closed without current running-game evidence.

## NEXT

Intake/registration delivery pending. Existing watcher only; no guard/pin/cap/
reserve/template/audience or security change, no tags/uploads/manual builds.

## Work remaining

Follow section8, FEAT03, FEAT11, FEAT10, FEAT09, combined FEAT02/07, then section9.
The final version of this report will contain the full index disposition table
and the requested combined investigation, exposure report, new findings,
0.6.2 queue and departures.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-preflight, uf061-spec-first-commit, uf061-bootstrap-repair.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-intake-record\evidence\raw-evidence-index.json | 9de3821c588e6bc93df95b4db68eb081316ba83b676e4c8370bd24f1dea2be82 |
| E:\CodexQA\BTH\runs\uf061-bootstrap-repair\evidence\classification.json | ec6764ec952dafa171f6cd8b2836a8569d0ca2c0ea1424130e4a93815335ea34 |

## Intake integration correction

The audit was the first local commit2b8b0a6b. During the first required
pull/rebase, the fresh shared clone's temporary upstream ref incorrectly included
that unpublished local commit. Rebase consequently excluded it as former-upstream
and published the registration alone at4a5096afea7e4154b8a7887f857c4e1731680fea.
The unchanged audit was restored append-only at98088acb76824a726a311ce0f9f300b1ab445f35.
No published history was rewritten or force-pushed. This is a departure from
the intended audit-first published ordering and is retained in the final report.
The supplied file bytes/hash are unchanged, and a structural comparison confirms
zero unrelated ledger objective/batch rows changed. Only the nine registered
objectives and nine batches were added; line-ending/JSON formatting accounts for
the larger textual diff.

A plain-dictionary QA environment key initially failed the duplicate-key launch
guard before cloning. The original failed manifest is retained; the adapter
corrected the key's case and used a new E run ID with identical caps/reserve.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-integration-correction, uf061-bootstrap-repair.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-intake-correct-ledger\evidence\raw-evidence-index.json | 4127293787c2902b49825d49abd4ca175086f6253af71c9ab71b9cd1cbf31d43 |
| E:\CodexQA\BTH\runs\uf061-integration-correction\evidence\integration-correction.json | 0f58200477a8d2aae96f341126fbb7791857d55a66e1d4090b14fb97132c29fc |
| E:\CodexQA\BTH\runs\uf061-bootstrap-repair\evidence\classification.json | ec6764ec952dafa171f6cd8b2836a8569d0ca2c0ea1424130e4a93815335ea34 |

## Qualification diagnosis correction, 2026-11-12

The initial CSV attribution was an unverified inference and was wrong. Exact current Git input rows, using the unchanged classifier exclusions, show only `README.md` differs from served 070fc937; both inventories contain 1420 rows. The required FEAT-04 README closure note is included by that classifier. Files under `docs/`, including the Crossword CSV, are excluded. The refusal itself and pending delivery remain factual; no pipeline rule was changed. Exact raw receipt: `E:\CodexQA\BTH\runs\uf061-next-exact-input-diff\evidence\exact-import-input-diff.json`, SHA-256 `7ded8ae92d9a8676ce5b96e88ef3c76d76e99466b2b25429a89ecb000b96625c`.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-final-test-count-evidence, uf061-final-reconciliation, uf061-final-reconciliation2, uf061-final-reconciliation3, uf061-ledger-kind-correction, uf061-future-queue-schema-correction, uf061-reconciliation-owned-metadata-corrections, uf061-final-reconciliation4, uf061-scoped-reconciliation-counts, uf061-report-commit-and-scope-inventory, uf061-resident-failure-proof-addendum.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-owner-progress-report\evidence\raw-evidence-index.json | 682d471efbd89561a5881fadb9aca29aa63349d59d8ad29673f7d41926482c52 |
| E:\CodexQA\BTH\runs\uf061-ledger-kind-correction\evidence\schema-correction.json | 0d2593cb097eea782fbbab6ae17fe6359c993d51778b1d81dbedcd796a3e906e |
| E:\CodexQA\BTH\runs\uf061-reconciliation-owned-metadata-corrections\evidence\owned-corrections.json | 1d96cd3dc240722e6ed0b261e9d617ab17f82e6d638f450bcf99d14578f090b9 |
| E:\CodexQA\BTH\runs\uf061-final-reconciliation3\evidence\reconciliation.json | 5b9de30644da3e29e48af2aac7f57ae6e396b63d2e9ff6f651a3a85311869c84 |
| E:\CodexQA\BTH\runs\uf061-final-reconciliation4\evidence\reconciliation.json | 58dfc8ad056de982f8ec8865131782cd13d52985086849b80f9541134fd7a86f |
