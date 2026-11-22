# Beat the House 0.6.1 - landing plan

Written: 2026-11-19
Against: `origin/main` at `89403f389a5807e050a450cd27b1bd93b3a4a41e`, which is
also the build NEXT serves today.
Follows: `docs/todo/BTH_0.6.1_closeout_plan.md` (finished; CLOSE-01 to CLOSE-06
all executed on 2026-11-11).
Status: **LAND-01 to LAND-06 approved by the owner on 2026-11-19.** The worker
does all of them, including the browser work. LAND-07 and LAND-08 are owner
steps and are not part of the worker's run.
Worker prompt: `docs/todo/BTH_0.6.1_land01_06_pm_prompt.md`.

This file changes nothing by itself. It is the complete list of what is left
before 0.6.1 can be tagged, who does each part, and what moves to 0.6.2.
Every open ledger entry has a disposition in Appendix A or B.

---

## 0. Short version

- **The closeout plan is done, but its candidate is stale.** `8724a23f` was
  frozen, gated (Smoke 11/11) and packaged on 11-11. Since then 154 commits
  have landed on `main`: Crew, Blackjack, Roulette, Slot, Baccarat and
  stash-routing fixes from QA, plus the owner-requested travel cinematics. A
  second candidate (RC2) is needed.
- **Most of the 95 open ledger entries are not unfinished work.**
  28 are waiting for a NEXT delivery that has already happened. 37 are item,
  scenario, audit or performance entries that belong in 0.6.2. 9 are
  bookkeeping or "not reproducible" closures.
- **The real remaining work is small:** 21 entries, in three work orders:
  - finish the save/Continue money checks (four games and three named flows)
    on both Windows and Web;
  - one browser pass over fixes that were only checked natively, including
    travel cinematics;
  - the travel-slowdown check.

  Add two small loose ends, then RC2, your playtest, and release.

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

## 2. Facts as of 2026-11-19 (do not re-derive)

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

## 4. Work orders

**The worker does all of LAND-01 to LAND-06, including every browser step.**
The owner is needed only to start the run, to answer if the worker stops and
asks (section 5), and for LAND-07 and LAND-08.

Order:

1. LAND-01, alone.
2. LAND-02 and LAND-03 (native half), side by side.
3. LAND-04 and LAND-05 (browser), once LAND-02 is on NEXT.
4. LAND-03W (Web half), once LAND-03's native fixes are on NEXT.
5. LAND-06.
6. The owner's LAND-07 and LAND-08.

### LAND-01 - Reconcile the ledger with what is true today (worker)

**Why.** About 70 open entries are open only on paper. Until they are closed
or moved, nobody can see what actually stands between `main` and a release.

**How.**

1. **"Close - delivered" (Appendix A).**
   - For each entry, check that every commit it names is an ancestor of
     `89403f389` (`git merge-base --is-ancestor`). If so, close it as
     "delivered on NEXT `89403f389`; prior verification retained".
   - If a named commit is **not** on `main`, do not close the entry. List it
     in the receipt; LAND-02 step 3 decides what happens to it.
2. **"Close - not reproducible":** record "not reproducible on the current
   build; reopen on recurrence", citing the release bar.
3. **"Close - admin":** record the stated reason.
4. **"0.6.2":** set "open, no work authorized, owner decision 2026-11-19", and
   add the entry to the 0.6.2 queue record (`FEAT-062-RECORD`, which then
   closes). Entries marked D1/D2 move only if the owner said yes. Otherwise
   they stay open, unassigned, and do not block release.
5. **Historical entries:** apply Appendix B.
6. **Register three new IDs:**
   - `BTH-BLACKJACK-INSURANCE-CONTROL-001` (`0f661d3b3`);
   - `BTH-GRAND-PRESTIGE-HEAT-ARRIVAL-001` (`89403f389`);
   - `BTH-QA-GRAND-LEGAL-CAUGHT-FEEDBACK-001` (`c667c0eb7`).
7. **Commit once.** Update both ledger views in one commit:
   `docs/todo/bth_task_ledger.json` and the table in
   `docs/plans/0.6.1_stability_release_plan.md`. Run the checks in
   `docs/todo/bth_task_ledger_checks.md`.

**Rules.** No product code or test changes. Do not reopen investigations;
this is reconciliation only.

**Done when** every open entry, current and historical, is in exactly one of
these: LAND-02 to LAND-08, 0.6.2, or closed. The receipt
(`docs/testing/LAND-01_ledger_reconciliation_<date>.md`) gives the count per
bucket and lists any commit that is not on `main`.

### LAND-02 - Two loose ends (worker)

1. **Land the caught-feedback wording fix.**
   - Bring only `c667c0eb7` onto `main`: the `blackjack.gd` change and
     `scripts/tests/blackjack_ordinary_caught_feedback_check.gd`. Do not
     bring `19388e732`.
   - Run the check. It must pass, as recorded: 23 cases / 46 checks.
2. **Add a regression check for `89403f389`** (`BTH-GRAND-PRESTIGE-HEAT-ARRIVAL-001`).
   - Cases:
     - The first arrival at the Grand Casino from elsewhere, with prestige
       active, applies the recognition heat relief once, after carried
       arrival heat is merged.
     - A second arrival does not apply it again.
     - Same-location travel, other destinations and runs without prestige
       are unchanged.
     - Save and cold Continue after arrival do not apply it again.
     - Full-travel rollback restores pre-travel heat.
   - If a case fails, that is a product defect. Fix it narrowly, or stop and
     report if a narrow fix is not possible.
3. **Commits LAND-01 found missing from `main`:**
   - land one only if it fixes something a player can see, is small, and
     already has a passing focused check;
   - everything else moves to 0.6.2.

**Rules.** No change to heat amounts, detection, payouts or odds.

**Done when** both changes are on `main`, NEXT has promoted them, and both
checks pass.

### LAND-03 - Finish the save/Continue money checks (worker: native half)

**Why.** This is the only open area that touches the release bar directly:
money settling exactly once across Save and Continue. On 11-11 and 11-15,
six games passed. Four passed only a narrower version of the check, and Crew
Poker plus two named flows were not reached.

| Case | Ledger IDs | What to prove |
| --- | --- | --- |
| Baccarat, paid hand not yet resolved | `BTH061-006`, `BTH061-RC-ACCEPTANCE-COVERAGE-001` | Save → close the process → Continue → finish; one settlement |
| Roulette, bets Confirmed and not yet spun | `BTH061-006`, `BTH061-ROULETTE-SEALED-PENDING-001` | Same; no "sealed action" left pending after Continue |
| Video Poker, cards held before Draw | `BTH061-006` | Same; held cards and wager restored |
| Bar Dice, cup in Reveal | `BTH061-006`, `BTH061-BAR-DICE-REVEAL-RESTORE-001`, `BTH-BARDICE-WARM-PROGRESSION-001` | Same, warm and cold. Dismiss any open event popup first; an open popup pauses the tumble (lesson from CLOSE-03). |
| Crew Poker, saved on the flop or later | `BTH061-006` | Preflop already passed natively (11-15, 8/8); add one later street |
| Expired Jazz Club Crew handoff | `BTH061-CREW-EXPIRED-HANDOFF` | The missed delivery freezes as designed; no money or package duplicated |
| Meta item choice offered at the showdown | `BTH061-AUDIT-SHOWDOWN-META-CHOICE-FIX-031` | The offered items are usable; the choice persists across Save/Continue |

**How.**

1. For each case:
   - enter through normal controls and make a paid action;
   - Save while it is unfinished;
   - fully close the process, then Continue and finish;
   - record cash, chips, inventory and settlement count before and after.
2. **Both platforms (owner decision D3, 2026-11-19).** Every case must pass
   on the Windows build *and* on the Web build. The native half is here; the
   Web half is LAND-03W, below.
3. **Reaching the hard cases** (Crew, expired handoff, Meta choice):
   - Use a known seed, route, or a profile built by normal play.
   - Not allowed: forced state, edited saves, or debug switches.
   - Time box: at most 3 fresh attempts or 2 hours of play per case. If a
     case is still not reached, stop and ask the owner, with the route log of
     what was tried. "Not reached" does not close a case; only the owner can
     accept it.
4. **Routes.** For every case that passes natively, record:
   - seed and run options;
   - the shortest normal-control sequence from New Run to the save point;
   - the expected cash, chips and inventory at the save point.

   LAND-03W replays these in the browser, and they let anyone reproduce the
   case later.
5. A failure is a new finding with its own ID and shortest repro. Money or
   progress loss is a release blocker: fix it narrowly here, with a
   regression check, before the Web half runs.

**Done when** every row has passed natively (or failed and been fixed), the
fixes are on NEXT, and the routes are recorded. Proof:
`docs/testing/LAND-03_save_continue_<date>.md`.

### LAND-03W - The same cases in the browser (worker)

**Why.** The owner wants these checks completed for 0.6.1 on Web too, not
inferred from native runs. A Web save lives in browser storage, and Continue
follows a page reload; a native run does not exercise either.

**When.** Once LAND-03's native half is done and its fixes are on NEXT.

**How.** Use `http://localhost:8088/p/beat-the-house/play/dev/` with a fresh,
disposable browser profile and normal controls. For each case, follow its
route recorded in LAND-03:

1. reach the save point and make the paid action;
2. Save while it is unfinished;
3. reload the page (and, once per game, close and reopen the tab instead);
4. Continue and finish;
5. record cash, chips, inventory and settlement count before and after, a
   screenshot at each step, and the console log.

The LAND-03 time box applies. A case that cannot be reached in the browser
goes to the owner; it is not closed.

**Done when** every row passes on Web, or has failed and been fixed and
rechecked on both platforms. Proof:
`docs/testing/LAND-03W_web_save_continue_<date>.md`.

### LAND-04 - One browser pass on NEXT (worker)

**Why.** About ten delivered fixes and the travel cinematics were verified
natively and over HTTP, but never started in a browser.

**Where and when.** `http://localhost:8088/p/beat-the-house/play/dev/`, after
LAND-02 has landed. Record the served commit. Use a fresh, disposable profile,
normal controls, and watch the console throughout.

| Check | Ledger IDs |
| --- | --- |
| Startup; menu reads `0.6.0 (<commit>)`; new run; no page or console errors | (all) |
| Menu travel plays the cinematic (~8 s) and the room loads by itself. In-room travel has no cinematic. Skip works. Save right after arrival, reload, Continue: same room, fare charged once. | travel cinematics (`BTH-TRAVEL-CINEMATIC-001`, browser part) |
| Baccarat: after a rejected timed minimum, controls still work | `BTH-BACCARAT-AUTO-MIN-SELECTION-001` |
| Slot: after an unfunded spin, bet controls still work | `BTH-SLOT-UNFUNDED-SELECTION-001` |
| Blackjack: first draft kept after an overdue table cadence | `BTH-BLACKJACK-FIRST-DRAFT-001` |
| Blackjack: risk notice refreshes after an unfunded draft change | `BTH-BLACKJACK-DRAFT-RISK-NOTICE-001` |
| Blackjack: Insurance control shows only when offered; caught-ordinary wording | `BTH-BLACKJACK-INSURANCE-CONTROL-001`, `BTH-QA-GRAND-LEGAL-CAUGHT-FEEDBACK-001` |
| Roulette: still editable when marker repayment leaves a remembered draft unfunded | `BTH-ROULETTE-REPAID-DRAFT-001` |
| A fresh practice room does not show the previous result | `BTH-FEAT-PRACTICE-FEEDBACK-001` |
| Accepting a Crew package at a cabinet keeps the room | `BTH-NEXT-QA-CREW-ROOM-HOST-001` |
| Crew offer → accept → back to the game in progress, then the same after a reload | `BTH-GAME-RETURN-001` |
| Daily Challenge starts; record the date and seed shown | `FEAT-03` |
| Coin Pusher: about one minute of nozzle drag on each of the three cabinets; coins keep moving, no growing stutter. Quarter Falls shows the Drop price and Hold total. | `BTH-PERF-20261104-001`, `-003`, `BTH-COINPUSHER-DROP-PRICE-001` (glance) |
| Video Poker: 20 hands with hints on; watch for `DataCloneError` / out-of-memory page errors | `BTH-PERF-20261104-002` |
| Only if reached naturally: Bringer Show arrival, Gold review re-talk, tutorial Bronze collect, Sal pending offer | historical browser-acceptance entries (Appendix B) |

**22 November 2026 scoped Web checkpoint.** Actual approved LAN NEXT
e2b16ffbff7cc72a57a2664b5f25872aec10e8c9 has two closed, zero-owned
browser receipts. [Consolidated observations and hashes](../testing/LAND-04_browser_pass_2026-11-22.md)
record Practice refresh, Daily hidden-seed opening, one natural taxi/arrival
reload, Insurance007 loss, unfunded Slot draft editing and free pusher controls.
These are scoped passes; winning Insurance, caught D5, complete cabinet/Hold
coverage and the remaining rows stay Open. LAND-05 has no qualified sustained
sample set or currently viable40-trip scope under the existing guard.

**Outcomes.**

- Each row gets pass or fail, with a screenshot and the console log.
- A failure becomes a new finding with its own ID. Fix release-bar failures
  narrowly, with a regression check; small safe fixes are fine too; anything
  else goes to 0.6.2 with a reason.
- If out-of-memory page errors appear in normal Video Poker play, that is a
  release blocker.
- If they do not appear, close `-002`'s historical outliers as not reproduced.

**Done when** every row has a result. Proof:
`docs/testing/LAND-04_browser_pass_<date>.md`, with a summary and hashes only.

### LAND-05 - Travel slowdown (worker)

**Why.** `BTH-TEST-TRAVEL-PERF-001`: travel was reported getting slow on NEXT
and TEST. A partial native fix (`7ce76838c`) landed; it was never checked in a
browser.

**How.**

1. In the LAND-04 session, time 10 menu trips early in a run, and 10 more
   after about 40 minutes or 30+ trips.
2. Measure from the click to a playable room, minus the fixed 8 s cinematic.
   Note frame pacing in the room after arrival.
3. **If late trips are clearly slower** (median at least 1.5× the early
   median), the slowdown is reproduced.
   - The worker investigates. The existing lead is inactive-room projection
     compile cost.
   - It ships a narrow fix with before/after numbers and the liveness check.
   - If no narrow fix exists, the owner decides: ship with a known issue, or
     wait.
4. **If not reproduced:** close with the numbers. The owner confirms the feel
   during the playtest.

**Rules.** Never gain speed by suppressing redraws or animation (AGENTS.md).
Run the liveness check after any scheduling change.

### LAND-06 - Freeze RC2 and package (worker)

**After** LAND-01 to LAND-05, including LAND-03W. This repeats CLOSE-05
exactly.

1. **Version.** If D4 = yes, the last commit before the freeze sets
   `RELEASE_VERSION := "0.6.1"` in `scripts/core/build_identity.gd`, and
   changes nothing else.
2. **Freeze.** Freeze `main` and record the commit and tree as RC2. Make a
   clean detached checkout under `E:\CodexQA\BTH\workspaces\`.
3. **Gates, run on the frozen commit:**
   - `tools/check_godot.ps1 -Suite Smoke`: 11/11 stages pass.
   - `godot --headless --path <checkout> --script res://scripts/tests/animation_liveness_without_pointer_check.gd`
   - `python -B -m unittest discover -s tools/tests -p test_*.py -v`, and
     the same command with `-s tools`.
   - The LAND-02 and LAND-03 focused checks.
4. **Packages.**
   - Build Windows and Web with the unchanged `tools/export_itch.ps1`, then
     run the PCK and archive audits.
   - Launch the Windows exe once: 300 headless frames, no `SCRIPT ERROR`.
   - Web: start the RC2 immutable NEXT link in the browser with a fresh
     profile; no page or console errors.
5. **Handoff.**
   - Record SHA-256 of both zips.
   - Write `docs/testing/LAND-06_rc2_<date>.md`.
   - Write an owner playtest handoff: immutable NEXT link, zip paths, hashes,
     and anything still open (ideally nothing).

**Rules.** No check is loosened, skipped or deleted. Keep first-failure
evidence. No tag, rename or upload.

**Done when** all gates pass on the frozen commit and the packages and hashes
are handed over.

### LAND-07 - Owner playtest and triage

**Owner:**

- Play RC2, from the NEXT link or the Windows zip:
  - a new profile through the first night;
  - one full run to an ending;
  - plenty of travel;
  - Save, quit and Continue mid-game a few times.
- Report anything you notice. A sentence and a screenshot are enough.

**Worker triage:**

- A release-bar issue gets fixed; RC3 then repeats LAND-06.
- Anything else goes to 0.6.2, unless it is a trivial text fix.

### LAND-08 - Release

- **Version:** if D4 = no, tell the worker to set it to 0.6.1; it rebuilds
  the packages and reruns the launch checks.
- **Drafts (worker, not posted):** release notes and devlog, from
  `docs/todo/release06_1_publish_copy_template.md`, the devlog template and
  the changelog.
- **Owner:**
  - tag `v0.6.1` on the RC commit;
  - create the GitHub release with the two zips;
  - upload to itch.
- **Known leftovers (C1):** these still say 0.6.0, as the owner decided:
  - Windows file properties;
  - Android/iOS presets;
  - the project setting;
  - the internal `0.6.0-dev+…` build identity.

---

## 5. What the owner does, in order

1. **D1 to D5 are answered** (2026-11-19; table below).
2. **Start the worker** with the one-line launch text:
   `Execute D:\Projects\Beat-The-House\docs\todo\BTH_0.6.1_land01_06_pm_prompt.md`.
   Starting it authorizes the commits and normal `main` pushes these work
   orders describe; it does not authorize any tag, release, upload or force
   push.
3. **Only if the worker stops and asks**, answer it. It stops only for these:
   - a save/Continue case it could not reach (keep trying, or accept it as not
     reached);
   - a release-bar bug with no narrow fix;
   - a travel slowdown with no narrow fix;
   - a storage gate refusing a launch.
4. **Playtest RC2** when the worker hands it over, and report (LAND-07).
5. **Tag, publish, upload** (LAND-08).

Answered by the owner on 2026-11-19.

| # | In plain words | Owner answer | What it means for the run |
| --- | --- | --- | --- |
| D1 | Push the Whale Game investigation and the Count heist timing measurement to 0.6.2. They are reports only and ship nothing. | **Yes** | 4 entries leave the 0.6.1 list |
| D2 | Push what is left of the code-cleanup audit and of the whole-game performance audit to 0.6.2. Fixes they already landed still ship. | **Yes** | 20 entries leave the 0.6.1 list |
| D3 | Accept native Windows runs alone as proof for the save/Continue money checks? | **No: complete them on Web too, for 0.6.1** | The worker runs the native half (LAND-03), then plays the same cases in the browser (LAND-03W). "Not reached" closes nothing without the owner. |
| - | Let the worker use a browser for this run, so it does everything itself? | **Yes** | The inherited browser restriction is lifted for LAND-01 to LAND-06; disposable profile on NEXT at localhost only. No checkpoints. |
| D4 | The worker changes the menu version to 0.6.1 right before the RC2 freeze, so the build you playtest is the build that ships. | **Yes** | One-line change in `scripts/core/build_identity.gd` at freeze |
| D5 | Include the Blackjack wording fix from a local branch: legal play that gets caught says "Your play draws scrutiny; heat rises." instead of "Caught cheating; heat spikes." | **Yes** | It ships in 0.6.1 |

---

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
- **Evidence:** raw evidence stays under `E:\CodexQA\BTH`. Commit a summary
  and a hash list only (C6).
- **Ledger:** one update per work order, in both ledger views.
- **Commits:** commits and normal pushes to `main` are for these work orders
  only. Not allowed:
  - force pushes, tags, releases, renames, itch or butler uploads;
  - touching active player profiles or saves;
  - touching the NEXT pipeline's guards and pins;
  - changing security settings.
- **Branches:** do not merge `codex/environment-art-layers` or any
  `test/grand-*` branch.
- **Browser:** allowed for this run only, on NEXT at localhost, with a fresh
  disposable profile and normal controls. Never the owner's browser, profiles
  or saves; never script changes to game state inside the page; never bypass
  TLS or security settings.

---

## Appendix A - every open current ledger entry (95)

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

## Appendix B - historical-group entries (130 open)

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
