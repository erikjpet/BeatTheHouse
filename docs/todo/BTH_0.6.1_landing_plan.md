# Beat the House 0.6.1 - landing plan

> **2026-11-23: Superseded.** The owner replaced LAND-01 through LAND-08 with
> the [fast release process](BTH_0.6.1_fast_release_prompt.md). D3 (native
> and Web checks per Save/Continue case) was reversed by Erik on 2026-11-23.

## 0. Short version

Feature freeze immediately. Ship already-landed features as-is. Confirm each
new fix once with its focused check, plus required liveness when applicable.
Coverage-only rows do not block. The release bar in section 3 stays in force.
There is one final check on the frozen RC2, not per-fix NEXT or Web acceptance.

---

## 1. What moves to 0.6.2

### 1a. Already set aside (owner decisions 2026-11-11 and 2026-11-12)

| Item | Ledger IDs |
| --- | --- |
| Full item-effect reassessment, including Lucky Penny and Ledger Pencil | `FEAT-01`, `BTH-15`, `BTH-17`, `LEDGER022` (and their factual-help children) |
| Scenario polish (owner states scope first) | `BTH-11`, `BTH062-SCENARIO-POLISH` |
| Voice and copy pass on all 0.6 text (owner, by hand) | `FEAT-08` |
| Local in-game Daily Challenge leaderboard | `BTH062-DAILY-LEADERBOARD` |
| The Whale Game and the Crew trust arc | `BTH062-WHALE-TRUST-ARC` |
| Native input-retention measurement (C4) | `BTH061-RC-NATIVE-RETENTION-001` |
| P2 coverage rows (C4): Coin Pusher persistence, varied-seed batches, Windows/Web readability, performance baselines and improvements, audio/resource retention | `BTH061-003`, `-004`, `-008`, `-009`, `-010`, `-011` |

### 1b. Moved 2026-11-19 (owner: item and scenario work goes to 0.6.2)

| Item | Ledger IDs | Note |
| --- | --- | --- |
| Turn both item packs on by default | `FEAT-11`, `BTH-FEAT-PACK-MERCHANT-001` | This also retires the open merchant-pool question; no decision needed for 0.6.1. With the packs off, nobody sees the three souvenirs/gear with unfixed effects (FEAT-01 A/B). |
| Gas Casino storm-shelter scenery disappearing after an event response | `BTH061-CLOSE06-SCENARIO-CONTINUE-001` | Classified as the scenario's authored one-turn expiry; fresh Continue passes. Changing it is scenario-content work. |
| FEAT-09 leftovers | `FEAT-09` (remainder) | Both scenario fixes (Wedding, Bringer arrival) are already on `main` and on NEXT; they ship in 0.6.1. Only the souvenir reward exactly-once acceptance moves, with the item packs. |
| Scenario characters walking instead of snapping | FEAT-05 (no ledger ID) | Needs its own design pass. |
| Distinct room art; two props with no visual | FEAT-06; local branch `codex/environment-art-layers` (231 commits, not on `main`) | Art. Do not merge that branch for 0.6.1. |

### 1c. Recommended to move as well (needs owner yes: D1, D2)

| Item | Ledger IDs | Why it can move |
| --- | --- | --- |
| Whale private investigation and Count route measurement, with their two observations | `FEAT-02`, `FEAT-07`, `BTH-FEAT-COUNT-ACCESS-GUIDE-001`, `BTH-FEAT-NOOP-GOLDEN-001` | They ship nothing; they only feed the 0.6.2 Whale/trust-arc decision. Both are stuck on a native-app access approval. |
| Remainder of the obsolete-code audit (already paused by owner) | `BTH061-AUDIT-001` and 12 children (Appendix A) | Code hygiene with no open player-facing defect. Children whose fixes already landed are closed in LAND-01 and ship. |
| Remainder of the whole-game performance audit | `BTH-PERF-20261104` (parent) and `-004` to `-008` | Same treatment as the C4 performance rows. The three concrete children (`-001`, `-002`, `-003`) are checked in LAND-04. |
| Agent runtime-process cleanup bookkeeping | `BTH-RUNTIME-CLEANUP-001` | QA tooling, not the game. |

### 1d. Not in 0.6.1 at all (platform, people, art or "not wanted")

Tutorial five-player human gate (TUT-N17); online leaderboards and
achievements; Steam inventory/market; Android and iOS builds; Act 2; trailer.
QOL-06 to QOL-10 (owner: not wanted now). The deferred qualification campaigns:
binding cross-economy audit, low-end performance matrix, music soaks B/C, and
the full 11-game campaign beyond the AUD061-17 subset. Version stamps other
than the menu (C1). Collection sort/filter (`FEAT-04`) is closed as not wanted.

---

## 2. Historical facts as of 2026-11-19 (not current gates)

- `origin/main` = `89403f389`. NEXT `CURRENT` = `89403f389`;
  `http://localhost:8088/p/beat-the-house/play/dev/` redirects to it. Every
  fix on `main` is on NEXT.
- **The NEXT blockers in the ledger are stale.** The 11-04 disk-reserve block
  needed 13.96 GB free on D:. D: now has 31 GB free. The later "cold-import
  qualification" and "publisher refuses immutable build" holds (11-04 to
  11-12) are superseded too: NEXT has promoted every `main` commit through
  `89403f389`.
- E: has 46 GB free. That is enough for QA (4 + 20 GiB reserve) and packaging
  (8 + 20 GiB), with little spare. Do not delete evidence to make room.
- **Travel cinematics** (`f35ba137b`, 11-12) were requested by the owner and
  stay in 0.6.1. They were qualified natively and over HTTP only; browser
  startup, gameplay and save isolation were never run.
- **Two 11-18 commits are not in the ledger:**
  - `0f661d3b3`: Blackjack Insurance control. Has a geometry check.
  - `89403f389`: Grand Casino prestige heat relief on first arrival. Changes
    `run_state.gd` and has **no test**.
- **One fix exists only locally:** branch
  `fix/grand-ordinary-caught-feedback-20261116`, commit `c667c0eb7`. It is a
  2-line text change in `scripts/games/blackjack.gd` plus a focused check.
  Today, legal play that gets caught reads "Caught cheating; heat spikes." Its
  parent is local-only commit `19388e732` (QA storage gate), which `main` has
  since superseded with a newer version. That parent must not come along.
- **The worker may use a browser for this run** (owner, 2026-11-19). This
  lifts the "inherited browser-control restriction" recorded in the 11-15 and
  11-16 QA notes; the same worker played NEXT in a browser for CLOSE-06 on
  11-11. Use only a fresh, disposable browser profile on NEXT at
  `http://localhost:8088/p/beat-the-house/play/dev/`. Never use the owner's
  own browser, profiles or saves.
- **Do not use `D:\Projects\Beat-The-House` for this plan.** That checkout is a
  detached HEAD, 803 commits behind `main`, with untracked QA tools. Work from
  a fresh clean checkout on E:.

---

## 3. The release bar

From `docs/plans/0.6.1_stability_release_plan.md`, "Release decision":

0.6.1 ships when none of the following remain:

- a confirmed crash;
- lost or duplicated money or progress;
- broken required progression;
- a critical save incompatibility.

Every other reproduced finding has a fix or a written disposition. Planned
coverage is not a pass. A historical failure that does not reproduce on the
current build is not a current defect. It is closed "not reproducible; reopen
on recurrence", as AUD061-12 was.

---

## 4. Worker steps

1. Rewrite and link the process documents. Keep liveness and QA storage intact.
2. Reconcile the objective and batch ledger and readable plan table; preserve
   evidence, close committed fixes and coverage-only rows, and label 0.6.2
   deferrals. Run the ledger reconciliation commands and tools unit tests.
3. Finish reproduced release-bar defects with one focused check each. Reuse
   recorded focused/liveness checks for the e8445ed8 travel fix; no timing study.
4. Update the changelog, then commit only the 0.6.1 version bump and freeze
   that SHA as RC2 in a clean detached checkout.
5. Run one frozen final check: Smoke 11/11, liveness, both Python discovery
   suites, both unchanged exports and package audits, the Windows 300-frame
   launch, and one short real play/Save/Continue pass each on Windows and NEXT.
6. Push a one-page handoff with results, ZIP paths, SHA-256s and known issues.

See the [fast release worker prompt](BTH_0.6.1_fast_release_prompt.md) for
the commands, release-bar failure handling, and exact manual pass.

## 5. Owner handoff

Review the worker's brief handoff and the exact RC2 packages. Tagging,
publishing the GitHub release and uploading to itch remain owner actions.

## 6. Rules for whoever executes this (self-contained)

- **`AGENTS.md` wins over this file.**
- **Animation liveness is release-gated.**
  - Never optimize by disabling canvas processing, removing autonomous
    redraws, or tying redraws to input.
  - After any scheduling or performance change, run the liveness check.
- **QA storage:**
  - every new run uses `tools/bth_qa_storage.py` and
    `tools/bth_qa_guarded_run.py`, with root `E:\CodexQA\BTH`;
  - give explicit workspace, profile, temp, evidence and output paths, all
    on E:; no C: fallback;
  - reserve 4 GiB of expected writes plus 20 GiB (8 + 20 for packaging);
  - on a storage failure, stop with the exact error. Do not pick another
    drive or delete evidence.
- **Do not change:** payouts, odds, RTP/EV, heat amounts or detection; item
  effects, prices or text; scenario content (items and scenarios are 0.6.2).
- **Product versus test:**
  - Fix the product when the product is wrong.
  - Change a test only when it encodes behavior that was deliberately
    replaced, and say what replaced it.
  - Never delete or skip a check.
- **Findings:** reproduce before fixing. A failure is a new finding with its
  own ID and the shortest reproduction.
- **Evidence:** raw evidence stays under `E:\CodexQA\BTH`. The RC2 handoff contains the final summary and package hashes. Do not add per-fix release evidence gates.
- **Ledger:** record each requested item once in both ledger views.
- **Commits:** commits and normal pushes to `main` are for this release process
  only. Not allowed:
  - force pushes, tags, releases, renames, itch or butler uploads;
  - touching active player profiles or saves;
  - touching the NEXT pipeline's guards and pins;
  - changing security settings.
- **Branches:** do not merge `codex/environment-art-layers` or any
  `test/grand-*` branch.
- **Browser:** allowed for this run only, during the frozen final check on NEXT, with a fresh
  disposable profile and normal controls. Never the owner's browser, profiles
  or saves; never script changes to game state inside the page; never bypass
  TLS or security settings.

---

## Appendix A - historical snapshot of 95 then-open current entries

Counts:

| Bucket | Entries | Of which |
| --- | ---: | --- |
| 0.6.2 | 37 | 13 already decided, 24 on D1/D2 |
| Close - delivered | 28 | |
| Close - not reproducible | 4 | |
| Close - admin | 5 | |
| LAND-03 | 8 | |
| LAND-04 | 12 | |
| LAND-05 | 1 | |

| ID | Disposition |
| --- | --- |
| AUD061-EXECUTION | Close - admin: 18/18 processed; open findings live under their own IDs |
| BTH-09 | Close - not reproducible |
| BTH-11 | 0.6.2 (decided) |
| BTH-15 | 0.6.2 (decided) |
| BTH-17 | 0.6.2 (decided) |
| BTH-BACCARAT-AUTO-MIN-SELECTION-001 | LAND-04 |
| BTH-BARDICE-JOURNAL-CURRENCY-001 | Close - delivered |
| BTH-BARDICE-WARM-PROGRESSION-001 | LAND-03 (Bar Dice row) |
| BTH-BLACKJACK-DRAFT-RISK-NOTICE-001 | LAND-04 |
| BTH-BLACKJACK-FIRST-DRAFT-001 | LAND-04 |
| BTH-COINPUSHER-DROP-PRICE-001 | Close - delivered (glanced in LAND-04) |
| BTH-FEAT-COUNT-ACCESS-GUIDE-001 | 0.6.2 (D1) |
| BTH-FEAT-NOOP-GOLDEN-001 | 0.6.2 (D1) |
| BTH-FEAT-PACK-MERCHANT-001 | 0.6.2 (decided 11-19) |
| BTH-FEAT-PRACTICE-FEEDBACK-001 | LAND-04 |
| BTH-GAME-RETURN-001 | LAND-04 |
| BTH-GAS-SCRATCHER-EXIT-001 | Close - not reproducible |
| BTH-JOURNAL-ROULETTE-CURRENCY-001 | Close - delivered |
| BTH-LAN-TLS-TRUST-001 | Close - admin: strict HTTPS startup passes; no trust change needed |
| BTH-NEXT-DISK-RESERVE-001 | Close - delivered: D: has 31 GB free; NEXT `CURRENT` = `main` |
| BTH-NEXT-QA-CREW-ROOM-HOST-001 | LAND-04 |
| BTH-NEXT-QA-GENERAL-SIDEBAR-001 | Close - admin: exploratory QA ends at the RC2 freeze; its findings are registered |
| BTH-PERF-20261104 | 0.6.2 (D2), after LAND-04 settles -001/-002/-003 |
| BTH-PERF-20261104-001 | LAND-04 |
| BTH-PERF-20261104-002 | LAND-04 |
| BTH-PERF-20261104-003 | LAND-04 |
| BTH-PERF-20261104-004 | 0.6.2 (D2) |
| BTH-PERF-20261104-005 | 0.6.2 (D2) |
| BTH-PERF-20261104-006 | 0.6.2 (D2) |
| BTH-PERF-20261104-007 | 0.6.2 (D2) |
| BTH-PERF-20261104-008 | 0.6.2 (D2); reopen if the menu-text glitch is seen in LAND-04 or LAND-07 |
| BTH-ROULETTE-REPAID-DRAFT-001 | LAND-04 |
| BTH-RUNTIME-CLEANUP-001 | 0.6.2 (D2) |
| BTH-SCENARIO-ARRIVAL-002 | Close - delivered |
| BTH-SCENARIO-WEDDING-001 | Close - delivered |
| BTH-SLOT-UNFUNDED-SELECTION-001 | LAND-04 |
| BTH-TEST-TRAVEL-PERF-001 | LAND-05 |
| BTH-TODO-RELIABILITY-001 | Close - delivered |
| BTH-TRAVEL-CLOSING-FALLBACK-R11-1067 | Close - delivered |
| BTH061-006 | LAND-03 |
| BTH061-AUDIT-001 | 0.6.2 (D2) |
| BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005 | 0.6.2 (D2) |
| BTH061-AUDIT-CODEC-SIGNED-ZERO-022 | Close - delivered |
| BTH061-AUDIT-CONTENT-TIMEOUT-006 | 0.6.2 (D2) |
| BTH061-AUDIT-COVERAGE-PUBLICATION-024 | Close - delivered (if the evidence is on `main`) |
| BTH061-AUDIT-CREW-BASELINE-004 | Close - delivered |
| BTH061-AUDIT-CREW-INITIAL-REPUTATION-020 | Close - delivered |
| BTH061-AUDIT-DELIVERY-PRECOMMIT-OWNER-032 | 0.6.2 (D2) |
| BTH061-AUDIT-DUEL-CALLOUT-RECEIPT-022 | Close - delivered |
| BTH061-AUDIT-DUEL-SURFACE-ROLLBACK-009 | Close - delivered |
| BTH061-AUDIT-FINISH-PUBLISH-20261106 | Close - delivered (if the push happened) |
| BTH061-AUDIT-GENERATOR-INNER-ROLLBACK-030 | 0.6.2 (D2) |
| BTH061-AUDIT-INDEPENDENT-001 | 0.6.2 (D2) |
| BTH061-AUDIT-INTERRUPT-BASELINE-004 | 0.6.2 (D2) |
| BTH061-AUDIT-LAYER-DEFINITION-013 | Close - delivered |
| BTH061-AUDIT-MEMO-CALLBACK-CHECK-018 | 0.6.2 (D2) |
| BTH061-AUDIT-MEMO-TYPE-SAFETY-014 | 0.6.2 (D2); the typed-collision fix already shipped |
| BTH061-AUDIT-MENU-SAVE-SNAPSHOT-028 | Close - delivered |
| BTH061-AUDIT-NUMBERS-LAYOUT-STUB-024 | 0.6.2 (D2) |
| BTH061-AUDIT-PERSISTENCE-PROJECTION-013 | 0.6.2 (D2) |
| BTH061-AUDIT-PLACEMENT-SHADOWED-BRANCH-030 | 0.6.2 (D2) |
| BTH061-AUDIT-PROJECTION-NUMERIC-IDENTITY-023 | Close - delivered |
| BTH061-AUDIT-RITUAL-ANCHOR-ARGUMENT-025 | Close - delivered (status says "committed local": check ancestry; LAND-02 step 3 if missing) |
| BTH061-AUDIT-RITUAL-ID-GRAMMAR-025 | Close - delivered (same check) |
| BTH061-AUDIT-RUNTIME-OWNED-COPY-019 | 0.6.2 (D2) |
| BTH061-AUDIT-SCHEMA-VALIDATION-014 | Close - delivered if on `main` and RC2 Smoke is green; otherwise 0.6.2 |
| BTH061-AUDIT-SEQUENCE-BASELINE-008 | Close - delivered |
| BTH061-AUDIT-SHOWDOWN-META-CHOICE-FIX-031 | LAND-03 |
| BTH061-BAR-DICE-COVER-DISPLAY-001 | Close - delivered (CLOSE-02) |
| BTH061-BAR-DICE-REVEAL-RESTORE-001 | LAND-03 (Bar Dice row) |
| BTH061-CLOSE06-SCENARIO-CONTINUE-001 | 0.6.2 (decided 11-19) |
| BTH061-CREW-EXPIRED-HANDOFF | LAND-03 |
| BTH061-PULLTABS-SAVE-001 | Close - not reproducible |
| BTH061-RC-ACCEPTANCE-COVERAGE-001 | LAND-03 (parent) |
| BTH061-RC-NATIVE-RETENTION-001 | 0.6.2 (decided, C4) |
| BTH061-ROULETTE-SEALED-PENDING-001 | LAND-03 (Roulette row); original cause stays unattributed |
| BTH061-VAULTDROP-SAVE-001 | Close - not reproducible |
| BTH062-DAILY-LEADERBOARD | 0.6.2 (decided) |
| BTH062-SCENARIO-POLISH | 0.6.2 (decided) |
| BTH062-WHALE-TRUST-ARC | 0.6.2 (decided) |
| CLOSE-06 | LAND-03 (closes with LAND-03, LAND-03W and LAND-04) |
| CLOSEOUT-061 | Close - admin: superseded by this plan |
| FEAT-01 | 0.6.2 (decided) |
| FEAT-02 | 0.6.2 (D1) |
| FEAT-03 | LAND-04 |
| FEAT-04 | Close - delivered (closed as not wanted) |
| FEAT-062-RECORD | Close - delivered, after adding this plan's 0.6.2 moves |
| FEAT-07 | 0.6.2 (D1) |
| FEAT-08 | 0.6.2 (decided) |
| FEAT-09 | Close - delivered (both fixes on NEXT); souvenir acceptance goes to 0.6.2 with FEAT-11 |
| FEAT-10 | Close - delivered (rechecked, not reproduced) |
| FEAT-11 | 0.6.2 (decided 11-19) |
| FEAT-QUEUE | Close - admin: every child is dispositioned |
| FEAT-STALE | Close - delivered |
| LEDGER022 | 0.6.2 (decided) |

## Appendix B - historical snapshot of 130 then-open historical entries

Apply these rules in order. List every entry and its rule in the LAND-01
receipt. Leave none unassigned.

1. **Close as "historical; prior result retained; superseded by RC2
   qualification".** Applies when the status starts with one of these and the
   prior scoped result is a pass or a fix:
   - `OPEN_COMMIT_ASSOCIATION_REQUIRED`
   - `OPEN_LEGACY_STATUS_AND_COMMIT_RECONCILIATION`
   - `OPEN_COMMIT_OR_ORIGINAL_ACCEPTANCE_RECONCILIATION`
   - `HISTORICALLY_DELIVERED_COMMIT_ASSOCIATION_OPEN`
   - `OPEN_ORIGINAL_TITLE…`
   - `KNOWN_UNRECORDED_DATA_LIMIT`

   Do not hunt for old commits.
2. **Close as "historical attribution; no current defect".** Applies to
   `OPEN_RECONCILIATION_REQUIRED` entries. Exception:
   `COUNT-MONEYFLOW-001` and `CREW-PLANNING-OVERFLOW` close only after
   checking that their display fix is on `main`.
3. **Browser acceptance still pending.** Applies to
   `PENDING_ORIGINAL_ACCEPTANCE_NOT_SILENTLY_WAIVED`,
   `OPEN_ORIGINAL_ACCEPTANCE`, `DEPLOYED_A746_…_BROWSER_ACCEPTANCE_PENDING`,
   `OPEN_BROWSER_COVERAGE_NATIVE_PROOF_SEPARATE` and `…_OWNER_WEB_UNRUN`.
   - Check in LAND-04 if reached naturally: Gold review re-talk, Practice
     Crew layer, tutorial Bronze collect, Sal pending offer, Crew stake-loss
     note.
   - Otherwise close as "superseded by RC2 browser pass and owner playtest".
4. **Phone and touch entries go to 0.6.2:** physical phone, emulated touch,
   portrait overflow, mobile UI assets. Exception: the owner plays on a phone
   during LAND-07; then close any that the owner sees working.
5. **`DEFERRED_PAST_0_6_1_OWNER_DECISION_C4` goes to 0.6.2** (section 1a).
6. **Anything else:**
   - It is in LAND-03 if it is about Save/Continue money settlement (for
     example the `FROZEN_RC_*` coverage rows).
   - Otherwise it is closed with a one-line reason, or moved to 0.6.2 if it
     describes a defect that still reproduces.
