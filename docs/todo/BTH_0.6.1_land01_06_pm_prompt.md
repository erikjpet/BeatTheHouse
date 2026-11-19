# Beat the House 0.6.1 — LAND-01 to LAND-06 (project manager prompt)

Written 2026-11-19. Approved by the owner the same day.

Owner decisions:

- D1, D2, D4 and D5 are yes.
- D3 is **no**: the save/Continue money checks must be completed on Web as
  well as Windows for 0.6.1.
- **You do all the work yourself, including every browser step.** The owner
  lifted the inherited browser-control restriction for this run (section 2).

You are the project manager worker for Beat the House 0.6.1. Your job is to
execute work orders **LAND-01 to LAND-06** of the landing plan, delegating to
sub-workers where it helps. You finish by handing the owner a qualified second
release candidate (**RC2**). LAND-07 (the owner's playtest) and LAND-08
(tagging and upload) are not yours; stop at the RC2 handoff.

This prompt is self-contained. Where it and the specification differ, this
prompt wins for authority and rules, and the specification wins for the
content of each work order.

---

## 1. Inputs

| Input | Where |
| --- | --- |
| **Specification** (binding: sections 2, 3, 4 and 6, Appendix A, Appendix B) | `D:\Projects\Beat-The-House\docs\todo\BTH_0.6.1_landing_plan.md` |
| This prompt | `D:\Projects\Beat-The-House\docs\todo\BTH_0.6.1_land01_06_pm_prompt.md` |
| Repository | `github.com/erikjpet/BeatTheHouse`, branch `main` (spec written against `89403f389a5807e050a450cd27b1bd93b3a4a41e`) |
| Ledger, both views | `docs/todo/bth_task_ledger.json`, and the table in `docs/plans/0.6.1_stability_release_plan.md`; checks in `docs/todo/bth_task_ledger_checks.md` |
| Template for LAND-06 | `docs/testing/CLOSE-05_final_candidate_2026-11-11.md` and `docs/testing/BTH_0.6.1_owner_playtest_closeout_2026-11-11.md` |
| NEXT | `http://localhost:8088/p/beat-the-house/play/dev/`; served commit at `.../dev/CURRENT` |

At the start of the run:

1. Record the SHA-256 of the specification and of this prompt.
2. Commit both files unchanged to `main`, at the same paths under
   `docs/todo/`, in your first ledger commit.

**Do not work in `D:\Projects\Beat-The-House`.** It is a detached checkout 803
commits behind `main`, with untracked QA tools that belong to other work. From
it you may only:

- read the two files above;
- fetch the one branch named in section 2.

Do not modify or delete anything there. Do all work in a clean checkout under
`E:\CodexQA\BTH\workspaces\`.

---

## 2. What the owner authorized (2026-11-19)

**Allowed**

- Execute LAND-01 to LAND-06 as specified, including LAND-03W.
- Delegate to sub-workers. Each sub-worker gets its work order and section 7
  of this prompt, verbatim.
- Commit and push (normal fast-forward) to `main` for this work. Let the
  existing NEXT watcher promote it as usual.
- Run QA and packaging under the storage gates in section 7.
- **Browser use for this run.** Drive a browser on NEXT at `localhost:8088`
  through normal game controls, as CLOSE-06 did on 11-11. This lifts the
  "inherited browser-control restriction" in the 11-15 and 11-16 QA notes,
  for LAND-03W, LAND-04, LAND-05 and the LAND-06 Web launch. Conditions:
  - use a fresh, disposable browser profile;
  - never the owner's own browser, profiles or saves;
  - never script changes to game state inside the page;
  - never bypass TLS or security settings.
- **D5:** bring commit `c667c0eb7` onto `main`, and only that commit. Fetch it
  from branch `fix/grand-ordinary-caught-feedback-20261116` in
  `D:\Projects\Beat-The-House`. Its parent `19388e732` must **not** come
  along.
- **D4:** as the last commit before the RC2 freeze, set
  `RELEASE_VERSION := "0.6.1"` in `scripts/core/build_identity.gd`. Nothing
  else in that commit.

**Not allowed**

- Tags, GitHub releases, renames, itch or butler uploads, force pushes.
- Merging any other branch, including `codex/environment-art-layers` and every
  `test/grand-*` branch.
- Changing NEXT pipeline guards, pins, reserves or templates, or any security
  or trust setting.
- Touching the owner's active profiles or saves, or asking for the owner's
  personal saves.
- Item, scenario, balance, odds, payout or economy changes.
- Starting LAND-07, LAND-08 or any 0.6.2 entry.

---

## 3. Owner decisions in force

| # | Decision | Effect on your run |
| --- | --- | --- |
| D1 | Yes: the Whale investigation and Count measurement move to 0.6.2 | `FEAT-02`, `FEAT-07`, `BTH-FEAT-COUNT-ACCESS-GUIDE-001`, `BTH-FEAT-NOOP-GOLDEN-001` move to 0.6.2 in LAND-01 |
| D2 | Yes: the leftover code-cleanup and performance audits move to 0.6.2 | The 20 entries marked D2 in Appendix A move to 0.6.2 in LAND-01 |
| D3 | **No:** LAND-03 must be completed for 0.6.1 on both Windows and Web | Run the native half (LAND-03), then the same cases in the browser (LAND-03W). A case is never closed as "not reached" without the owner. |
| D4 | Yes: the version becomes 0.6.1 just before the RC2 freeze | See section 2 |
| D5 | Yes: land the Blackjack caught-feedback wording fix | LAND-02 step 1 |
| Browser | Yes: you do every browser step yourself | See section 2; no handoffs to anyone |
| 11-19 | Item and scenario work goes to 0.6.2 | Specification section 1b |
| Standing | C1 (one display-version variable; other stamps stay 0.6.0), C3, C4, C6 (raw evidence stays out of the repo) | Unchanged |

---

## 4. Start-of-run checks (before LAND-01)

Record all of these in the LAND-01 receipt.

1. **Main.** Fetch `origin`, then record the `main` HEAD.
   - If it is not `89403f389`, list the new commits.
   - Register each new product change as LAND-01 step 6 does.
   - If a new product change has no focused check, add one under LAND-02.
2. **NEXT.** Read `.../dev/CURRENT`. Record it, and whether it equals the
   `main` HEAD.
3. **Disk.** Record free space on D: and E:.
   - QA launches reserve 4 GiB expected writes plus 20 GiB.
   - Packaging reserves 8 GiB plus 20 GiB.
   - If a gate refuses a launch, stop that launch and report the exact error.
4. **D5 commit.** Confirm `c667c0eb7` exists and touches only
   `scripts/games/blackjack.gd` (2 lines) and
   `scripts/tests/blackjack_ordinary_caught_feedback_check.gd`.
5. **Browser.** Confirm a fresh disposable browser profile can start NEXT
   through normal controls. If it cannot, record the exact reason and stop
   and ask the owner. Do not look for a workaround.

**"Close — delivered" in Appendix A** means: every commit the entry names is
an ancestor of the commit NEXT serves at the time you check.

---

## 5. Sequence

| Step | Work | Starts when | Runs with |
| --- | --- | --- | --- |
| 1 | LAND-01: ledger reconciliation | start-of-run checks recorded | alone (touches only ledger files) |
| 2 | LAND-02: loose ends | LAND-01 committed | LAND-03 |
| 2 | LAND-03: save/Continue money checks, native half | LAND-01 committed | LAND-02 |
| 3 | LAND-04: browser pass, and LAND-05: travel timing | LAND-02 is on `main` and NEXT has promoted it | LAND-03 |
| 4 | LAND-03W: the same money checks on Web | LAND-03's native half is done and its fixes are on NEXT | fixes from step 3 |
| 5 | Fixes for anything steps 3 and 4 find, then rechecks | as findings arrive | — |
| 6 | LAND-06: freeze RC2 and package | all start conditions below hold | alone |

**File ownership in step 2.**

- LAND-02 owns `scripts/games/blackjack.gd` and its new check files. It owns
  `scripts/core/run_state.gd` only if the heat-relief check finds a defect.
- LAND-03 touches only proof documents unless it finds a defect. A LAND-03
  fix that would touch a file LAND-02 has open waits until LAND-02 has landed.

**LAND-03 routes.** For every case that passes natively, record in the LAND-03
proof:

- seed and run options;
- the shortest normal-control sequence from New Run to the save point;
- the expected cash, chips and inventory at the save point.

LAND-03W replays these in the browser.

**LAND-03W.** For each case, on NEXT, with a fresh disposable profile and
normal controls:

1. follow its route to the save point and make the paid action;
2. Save while it is unfinished;
3. reload the page (once per game, close and reopen the tab instead);
4. Continue and finish;
5. record cash, chips, inventory and settlement count before and after, a
   screenshot at each step, and the console log.

It must settle exactly once. A case fixed after a Web failure is rechecked on
both platforms.

**Handling findings from LAND-03W, LAND-04 and LAND-05.**

- Give each failure its own finding ID and shortest repro.
- **Release-bar failures:** fix narrowly, with a regression check.
- **Other failures:** fix if small and safe; otherwise move to 0.6.2 with a
  reason.
- **Video Poker:** out-of-memory page errors in normal play are a release
  blocker. If they do not appear, close `BTH-PERF-20261104-002`'s historical
  outliers as not reproduced.
- **LAND-05:**
  - If the late median is at least 1.5× the early median, the slowdown is
    reproduced. Investigate (the existing lead is inactive-room projection
    compile cost) and ship a narrow fix with before/after numbers and the
    liveness check.
  - If there is no narrow fix, stop and ask the owner, with the numbers.
  - If it is not reproduced, close it with the numbers.

**Start LAND-06 only when all of these hold:**

- the LAND-01 receipt is committed;
- LAND-02 has landed;
- every LAND-03 case has passed natively and on Web (LAND-03W), or failed,
  been fixed and been rechecked on both. The only exception is a case the
  owner has explicitly accepted as not reached;
- every LAND-04 row has a result and every blocking failure is fixed;
- LAND-05 is closed or owner-decided.

**LAND-06 Web launch.** Start the RC2 immutable NEXT link in a fresh
disposable profile. There must be no page or console errors, and the menu
must read `0.6.1 (<commit>)`. A failure is a release-bar failure: fix it,
repeat LAND-06 as RC3.

**Hand-over.** When LAND-06 is done:

1. write the owner playtest handoff (section 8);
2. send the final report.

The run ends there.

---

## 6. The work orders, in one line each

The specification has the full text, acceptance and rules for each.

| Work order | Done when |
| --- | --- |
| LAND-01 | Every open ledger entry, current (Appendix A) and historical (Appendix B), is in exactly one bucket; counts and commits not on `main` are in the receipt |
| LAND-02 | `c667c0eb7` is on `main`. A heat-relief regression check for `89403f389` exists and passes, or a found defect is fixed. Missing audit commits are dispositioned. |
| LAND-03 | Baccarat, Roulette, Video Poker, Bar Dice, Crew Poker on a later street, the expired Jazz Club handoff, and the showdown Meta choice each pass natively, or fail and get fixed. Each settles exactly once across Save, close and Continue. Routes are recorded. |
| LAND-03W | The same seven cases pass on Web, with a page reload in place of a process restart, settling exactly once |
| LAND-04 | Every row of the specification's LAND-04 table has a pass or fail with screenshot and console log; failures are handled |
| LAND-05 | Early versus late travel timings recorded; closed, fixed, or owner-decided |
| LAND-06 | RC2 frozen. On the frozen commit: Smoke 11/11, liveness pass, both Python discovers pass, focused checks pass. Windows and Web packages built with the unchanged exporter, audited, launched. SHA-256 recorded. Handoff written. |

---

## 7. Rules (give this section verbatim to every sub-worker)

1. **`AGENTS.md` at the repository root wins over everything here.**
2. **Animation liveness is release-gated.**
   - Never optimize by disabling canvas processing, removing autonomous
     redraws, tying redraws to mouse, hover or selection input, or
     suppressing animation while an overlay is open.
   - After any scheduling or performance change, run:
     `godot --headless --path <checkout> --script res://scripts/tests/animation_liveness_without_pointer_check.gd`.
3. **QA storage.**
   - Every new run, workspace or launcher uses `tools/bth_qa_storage.py`
     before its first directory, write or subprocess, and again immediately
     before creating a child. Use `tools/bth_qa_guarded_run.py` for bounded
     workers.
   - The root is `E:\CodexQA\BTH`. Give explicit workspace, profile, temp,
     evidence and output paths, all on E:. No C: fallback.
   - Keep assignment-before-resume, the resource caps and cleanup.
   - Reserve 4 GiB of expected writes plus 20 GiB (8 + 20 for packaging).
     Record the manifest and launch gate in the evidence.
   - If validation fails, stop that launch with its exact error. Do not
     choose another drive, delete evidence, or change security settings.
4. **Browser** (authorized for this run only).
   - NEXT at `localhost:8088` only, a fresh disposable profile per session,
     with the profile's directory on E: under the storage gates.
   - Normal game controls only.
   - Never use the owner's browser, profiles or saves. Never script changes
     to game state inside the page. Never bypass TLS or security settings.
   - Keep the console log for every session.
5. **Do not change:** payouts, odds, RTP/EV, heat amounts, detection, item
   effects, prices or text, scenario content, or economy data.
6. **Product versus test.**
   - Fix the product when the product is wrong.
   - Change a test only when it encodes behavior that was deliberately
     replaced, and write down what replaced it.
   - Never delete, skip or loosen a check, a time budget or an assertion to
     get a pass.
7. **Findings.** Reproduce before fixing. A failure is a new finding with its
   own ID and the shortest reproduction. Historical failures that do not
   reproduce on the current build are closed "not reproducible; reopen on
   recurrence".
8. **The release bar.** 0.6.1 cannot ship with any of these:
   - a confirmed crash;
   - lost or duplicated money or progress;
   - broken required progression;
   - a critical save incompatibility.

   Every other reproduced finding gets a fix or a written disposition.
   Planned coverage is not a pass.
9. **Evidence.** Raw evidence (screenshots, console logs, saves, job
   records) stays under `E:\CodexQA\BTH`. Commit only a short proof summary
   and a hash list. Never commit job records, storage manifests or launch
   receipts in bulk.
10. **Ledger.**
    - Update both views in the same commit, once per work order or batch of
      fixes.
    - Write statuses in plain words of 12 words or fewer, for example
      "Closed — delivered on NEXT 89403f3" or "Moved to 0.6.2 — owner
      2026-11-19".
11. **Commits.**
    - One topic per commit. The message names the LAND ID and the ledger
      IDs.
    - Push normally. If a push is rejected, rebase your own commits onto the
      new `main` and retry once. Never force-push.
12. **Branches.** Do not merge or rebase onto `codex/environment-art-layers`
    or any `test/grand-*` branch.
13. **Saves.** Never ask for, depend on, or touch the owner's personal saves
    or active profiles. Use disposable profiles built by normal play.
14. **Allowed and forbidden ways to reach a game state.**
    - Allowed: known seeds, normal routes, and profiles built by normal play.
    - Forbidden: forced state, edited saves, debug switches, scripted page
      state.
15. **Time boxes.**
    - Each hard LAND-03 or LAND-03W case gets at most 3 fresh attempts or 2
      hours of play per platform, whichever comes first. Then stop that case
      and ask the owner, with the route log of what was tried. Never close a
      case as "not reached" on your own.
    - Each investigation (LAND-05, or any new finding) gets at most 4 hours.
      Then record what is known and stop that item.
16. **When the specification is out of date.** If a fact in specification
    section 2 is no longer true, follow the specification's intent, record
    the difference in your receipt, and continue.

---

## 8. Reporting

The owner wants short reports.

- **Progress notes:** at most 10 lines, only when a work order finishes or
  you need the owner. Say what is done, what is still open, and the one thing
  the owner needs to do, if any. Details go in the proof files.
- **Proof files** (summary and hashes only):
  - `docs/testing/LAND-01_ledger_reconciliation_<date>.md`
  - `docs/testing/LAND-02_loose_ends_<date>.md`
  - `docs/testing/LAND-03_save_continue_<date>.md` (with the routes)
  - `docs/testing/LAND-03W_web_save_continue_<date>.md`
  - `docs/testing/LAND-04_browser_pass_<date>.md`
  - `docs/testing/LAND-05_travel_timing_<date>.md`
  - a proof file for each fix made from a LAND-03W, LAND-04 or LAND-05
    finding
  - `docs/testing/LAND-06_rc2_<date>.md`
- **Owner playtest handoff** (`docs/testing/BTH_0.6.1_RC2_owner_playtest_<date>.md`)
  contains:
  - the immutable NEXT link for RC2 and the menu version string;
  - the Windows and Web zip paths with SHA-256;
  - a short changelog since 0.6.0, in player terms;
  - what is still open and why (ideally nothing);
  - a pointer to the 0.6.2 list;
  - a four-line playtest checklist:
    1. a new profile through the first night;
    2. one full run to an ending;
    3. plenty of travel;
    4. Save, quit and Continue mid-game a few times.

---

## 9. Stop and ask the owner only when

1. A release-bar defect needs more than a narrow fix.
2. A storage or launch gate refuses a launch.
3. Going on would need anything from the "not allowed" list in section 2.
4. LAND-05 reproduces and no narrow fix exists.
5. A LAND-03 or LAND-03W case is not reached within its time box.
6. A fresh disposable browser profile cannot start NEXT.

Otherwise keep going until the hand-over.

---

## 10. Done when

All of these hold, and the final report has been sent:

- RC2 is frozen, and every LAND-06 gate passes on the frozen commit,
  including the Web launch;
- the packages and their hashes are handed over;
- every LAND-03 case has passed on both Windows and Web;
- every LAND-04 row has a result, and LAND-05 is closed or owner-decided;
- the ledger shows no open 0.6.1 entry except rows the owner explicitly
  accepted as not reached, and the owner's LAND-07 and LAND-08.
