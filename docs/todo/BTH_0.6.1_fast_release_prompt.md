# Beat the House 0.6.1 - fast release (worker prompt)

Erik replaced LAND-01 through LAND-08 on 2026-11-23. Normal commits and pushes
to `erikjpet/BeatTheHouse` main are authorized. Do not tag, create a GitHub
release, upload to itch, force-push, or rewrite history.

> I don't want all of these checks to run so much testing. I just want fixes to
> be put in place, quickly confirmed to work, then move on. The rules in place
> are way too strict and repeat way too much testing. We should run a single
> final check after all implementation is finished on the frozen code.

This supersedes D3, the LAND-03/03W/04/05 work orders, per-fix NEXT/Web and
independent acceptance, and the testing and item/scenario pauses as they
affect 0.6.1 closure. Item and scenario features stay in 0.6.2.

## Rules

1. Feature freeze now. Only bug fixes land until 0.6.1 is tagged (apart from
   the release bookkeeping below). The landed CRT console, music/sounds,
   first-run Lesson/Skip and scanlines ship as they are.
2. A fix is complete when it is on main and the focused check passed, plus
   animation liveness when canvas scheduling or performance is affected.
   No per-fix NEXT promotion check, browser pass, independent review,
   screenshots, route logs or hash receipts.
3. Coverage alone is not unfinished 0.6.1 work. Close as “covered by the RC2
   final check” (a disposition, not a historical test pass) or move genuinely
   new testing scope to 0.6.2.
4. Release bar: no confirmed crash, lost or duplicated money or progress,
   broken required progression, or critical save incompatibility. Only a
   reproduced defect against this bar blocks release.
5. One final check on the frozen commit. Do not re-test already-landed fixes
   before it; reuse their recorded focused results.
6. Keep the AGENTS.md animation-liveness and QA storage rules, including
   `tools/bth_qa_storage.py` and `tools/bth_qa_guarded_run.py`. Never loosen,
   skip or delete an existing automated check to make a gate pass.

## 1. Rewrite the process docs (one commit)

- Shorten Requested-work continuity in AGENTS.md: one stable ledger ID,
  status and commits; complete means fix committed and focused check passed.
  Batches may close a parent when the parent's fix is done. No additional
  acceptance, deployment or evidence requirements. Preserve liveness and
  QA-storage rules unchanged.
- Put a supersession banner on `BTH_0.6.1_landing_plan.md`; replace sections
  0, 4 and 5 with this process. Leave sections 1 (0.6.2 moves) and 3 (release
  bar) unchanged. Record D3 as reversed by Erik on 2026-11-23.
- Add only a supersession banner and link to this prompt at the top of
  `BTH_0.6.1_land01_06_pm_prompt.md`.
- Update the stability release plan header and save this prompt.

## 2. Reconcile the ledger (one commit)

Update every open objective and batch in `bth_task_ledger.json` and the
stability release plan table. Close a confirmed main fix, set
`deployment.required` false with “owner 2026-11-23: per-fix deployment
acceptance dropped; covered by RC2 final check”, and retain evidence.
Close coverage-only/not-observed rows (including LAND-03/03W/04/05 coverage,
BTH061-005/-006/-007, Save/Continue matrix and historical browser acceptances)
as “covered by RC2 final check”, or move genuinely new testing scope to 0.6.2.
Keep reproduced unfixed defects open for Step 3. Items already deferred in
landing plan section 1 stay open, labeled 0.6.2 and non-blocking. Add owner
2026-11-23 resumption history to the pause policies: no 0.6.1 closure block,
item/scenario features still wait for 0.6.2.

Run the commands in `bth_task_ledger_checks.md`, including
`python -m unittest discover -s tools/tests -v`. Fix data rather than the
checker unless it hard-codes a requirement explicitly removed above; in that
case, change the smallest necessary check, update its test and disclose the
change. Include closed, moved to 0.6.2, and still-open counts in the commit.

## 3. Finish reproduced defects

List the open reproduced release-bar defects. For each, make one narrow fix,
add or extend one focused check, run it and commit. If a narrow fix is not
possible, ask Erik with a three-line summary whether to ship as a known issue
or wait. Fix non-blockers only if small and safe, otherwise defer to 0.6.2
with the reason. Confirm recorded focused and liveness checks for `e8445ed8`
(inactive-room projection reuse); no separate travel-timing study.

## 4. Freeze RC2

Update the 0.6.1 CHANGELOG.md heading from “Unreleased stability candidate”
and add any player-visible fixes from Step 3. Then make the last pre-freeze
commit set only `RELEASE_VERSION := "0.6.1"` in
`scripts/core/build_identity.gd` (D4 yes). Record that SHA as RC2 and use a
clean detached checkout per the QA storage rules.

## 5. Run the single frozen final check

- `tools/check_godot.ps1 -Suite Smoke`: all 11 stages.
- `godot --headless --path <checkout> --script res://scripts/tests/animation_liveness_without_pointer_check.gd`.
- `python -B -m unittest discover -s tools/tests -p test_*.py -v`, and the
  same command with `-s tools`.
- Build Windows and Web using unchanged `tools/export_itch.ps1`, run PCK and
  archive audits, and launch the Windows EXE for 300 headless frames with no
  `SCRIPT ERROR`.

One short pass (about 15 minutes) on each of Windows EXE and RC2 Web on NEXT
(using a fresh disposable browser profile): verify `0.6.1 (<commit>)`; start
a run; travel twice with cinematic and room load; play paid rounds in two
different games; Save mid-game, fully close the EXE or tab, Continue and
verify the same room, cash/chips/items and no duplicate settlement. No crash
or console/page errors.

A failure against the release bar: fix narrowly, re-freeze and rerun Step 5
once. Document other issues for 0.6.2 and continue.

## 6. Hand off

Write and push a one-page `docs/testing/RC2_final_check_<date>.md` with the RC2
commit, gate results, manual results, ZIP paths and SHA-256s, and known issues.
Report in at most five lines: RC2 commit, pass/fail, ZIP hashes, known issues
and, if successful, “ready for you to tag v0.6.1, publish the GitHub release
and upload to itch.”

Do not start new QA campaigns, coverage matrices or per-fix browser sessions;
reopen closed investigations or re-verify landed fixes before RC2; merge
`codex/environment-art-layers`; or tag, release, upload or force push.
