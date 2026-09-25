# rw06 reset consolidation status

Status: COMPLETE on 2026-09-24.

## Consolidation

- Rooms: merged `codex/rw06_1-phase0` (including its `WIP at reset` commit) and the unique `codex/rw06_1-visual-evidence` tip. The grand-authority, semantic-fixture-authority, hand-meta, and hand-other tips were already contained by the rooms trunk.
- Endings: merged `codex/rw06_2-prep`, `codex/rw06_2-heist-seed-preflight` (including both `WIP at reset` commits), corridor-fix, cheat-barred, cheat, and heist.
- Pull-tab glimmer: merged `codex/rw06_6-pull-tab-glimmer` (including its `WIP at reset` commit) and `codex/rw06_6-pull-tab-glimmer-red`.
- Owner documents: committed the pending rw06 status, questions, reset-consolidation prompt, and reset-lanes prompt on `main`.
- Forensic archives: the worktree contained only two untracked audit/contract scripts, not game implementation. They were first preserved in `WIP at reset` commit `205335ba` as required by inventory, then the worktree and branch were deleted without merging, following the prompt's explicit instruction to delete this out-of-scope branch and its no-testing rule.

## Conflict decisions

- `scripts/ui/pixel_scene_canvas.gd`: retained the endings helper for single-action availability and the rooms lane's stricter fail-closed object, action, and confirmation gates. The completed validator exposed that the first merge resolution had hidden the required explicit object/action derivation; production code was corrected in `3b2c4da7` without changing a checker or test.
- `docs/plans/rw06_2_routes/heist.md`: retained the newer consolidated step number (`15`) while keeping the corridor destination text.
- Barred-cheat replay source contract: retained the newer trunk analysis/validation blocks and the stronger immediate-terminal-or-rendered-witness assertion; the older branch side omitted those later blocks.
- Plain-cheat replay files: retained the newer trunk versions because the branch tip was an earlier copy of the same hardening already integrated in the endings trunk, followed there by later fixes.
- Heist contract conflict: retained the newer trunk version because the branch's product patch was exactly duplicated by the later integrated heist commit.
- Pull-tab add/add contract conflict: retained the later, larger glimmer-trunk file. It contains the shared red-custody behavior and replaces the red branch's older PID helpers with identity-aware process/job custody.
- `docs/todo/rw06_2p_status.md`: retained the newer 11:25 CT owner copy that withdraws the earlier Q-017A checkpoint; the prior 10:36 entry remains in its milestone history.

## State of each lane

- Rooms — Lane A 2026-09-24 20:35 CT. Works now on `main`: physical-only fixed slots and action-list overflow, true counter occlusion, reachable travel fallback, rebuilt Bar/Corner Store/Grand Casino layouts, distinct Grand private-room art, grounded hand-authored slots across every remaining public, private, and home map, separated Beach festival fixtures, Delta Queen deck groups, Jazz guest/tip contacts, and Gas Station scratch-ticket/drink supports; authored scenario classes apply consistently to late live room records. Q-021 remains OPEN at `D:\Projects\Beat-The-House\.tmp\owner_review\q008_rooms.png`. Next: continue the normal-view every-room capture, save/open `rooms_all.png`, address any visible composition misses, and obtain final approval.
- Endings — Lane B 2026-09-24 20:33 CT. Works now on `main`: the isolated normal-play route handles Linda's immediate service and off-canvas Cashout Counter through the visible room-action list, blank-room refocus, crowded-room overflow, capped-map scouting, and visible multi-leg return routes. Successful Crew packages clear exactly one favor at their transactional boundary, River Queen's dormant scenario rectangles reconcile before arrival, Grand Casino subroom returns align their scenario layout baseline before install, explicit replay waits advance real presentation before restoring deterministic pause ownership, and Linda card choices wait for a fully rendered TalkDock whose height reservation includes disabled multi-line reasons. Clean has now traversed the formerly clipped Players Card Back control twice. Ordinary blackjack decisions use the rendered active total and stand at 17+ instead of treating absent hand-row totals as zero. Next: rerun Clean with that decision fix, finish all three normal-use win confirmations, and save/open the three owner screenshots.
- Lane C part 3 — IN PROGRESS 2026-09-24 20:33 CT. Ownership transferred from Lane B for the Crew heist ending only; Lane B retains clean and cheat. Lane B's worktree is clean with no uncommitted heist changes. Plan: make the narrow Plan A / The Count route winnable through normal Crew trust, Grand Casino setup/play, and the getaway, then save/open `D:\Projects\Beat-The-House\.tmp\owner_review\ending_heist.png`. No room placement edits; implementation only, no testing.

## Confirmation and cleanup

- No Smoke, Contract, Full, focused contract, audit, or evidence-hash pass was run.
- `tools/validate_project.ps1`: the first invocation was terminated only by a 120-second command-wrapper limit; the restarted completion ran for about 165 seconds and reported one merge-resolution issue in selected-info enabled authority. That production issue was fixed and pushed. The validator was not run again, honoring the no-repeat/no-testing direction.
- Canonical Godot headless fresh-start confirmation exited `0`: the real main scene opened on the fresh `PLAY` menu, started the real tutorial run, printed `export_distribution_fresh_start_check: PASS`, and logged no script error. An initial attempt to drive the same confirmation through the playtest bridge reached ready with no errors but blocked on its headless screenshot wait; only its exact two processes were stopped before the direct fresh-start confirmation.
- `git branch -a` shows only local/remote `main` and `codex/wip-0.6-consolidated`.
- `git worktree list` shows only `D:/Projects/Beat-The-House` and `D:/Projects/Beat-The-House-worktrees/wip-0.6-consolidated`.
- `.godot_leases` has no entries. All rw06 family branches were deleted locally and from origin after their family was pushed.
