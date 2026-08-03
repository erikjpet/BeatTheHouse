# Agent Prompt — Reconcile Current Worktree and Restore Green Gates

# Execution record — 2026-08-03

- Preserved base: `d83020843f9e2053ab00dbfecbfb4ba173d540d5` on `agent/v05-pre-rework-baseline`.
- Working branch: `agent/v05-pre-human-playtest-rework`.
- Implementation commit: `5389fba8` (`fix integration gate regressions`).
- Report: `docs/plans/v05_integration_gate_recovery.md`.
- Restored the four currently failing Pal semantic contracts; the Crew contract was already green.
- Repaired deterministic reserved-overlay fixture placement without weakening the Sal overlap assertion.
- PASS: `git diff --check`, validation, Smoke, FoundationSuite `systems`, `scratch_tickets`, `ui`, and `all`.
- Evidence: `.tmp/test_reports/20260803_115040_smoke/`, `20260803_115332_smoke/`, `20260803_115505_smoke/`, `20260803_115625_smoke/`, and `20260803_115956_smoke/`.
- No branch was pushed.

---

Last reconciled: 2026-08-03
Release target: 0.5.0
Status: OPEN / MUST LAND BEFORE FINAL TUTORIAL AND PERFORMANCE CLOSURE

## Objective

Preserve, understand, repair, verify, and land the current uncommitted work in
`D:\Projects\Beat-The-House` without losing user-owned changes. The result must
be a clean, reviewable integration baseline for final tutorial and performance
work. This is not permission to discard, rewrite wholesale, or silently omit
any existing change.

## Starting state

Before the queue documentation update, `main` matched `origin/main` at
`2b8cb664` and the worktree contained 36 modified tracked files plus the
untracked `docs/plans/tutorial_first_time_player_review.md` (approximately
1,993 additions and 282 deletions). Treat the live status and diff as
authoritative if the tree changes after this prompt was written.

The work spans tutorial/dialogue presentation and travel, Scratch Tickets and
save compaction, Grand Casino invitation flow, SFX/UI behavior, and their tests
and performance probes.

## Known red gates

The latest recorded Smoke run passes project validation, Godot import, and
GDScript loading, then fails UI scene compilation because Sal's pawn-shop
fixtures overlap:

- `meta_sal_shelf:0` overlaps `meta_sal_shelf:4`;
- `meta_pawn_counter:sell` overlaps `meta_sal:talk`.

An earlier systems run identifies five tutorial binding regressions:

1. Pal's parking tip lost the later-use explanation.
2. Pal's Crew warning lost the last-place-you-turn meaning.
3. Pal's lookaway lesson lost the easiest-cheat and spill-a-drink explanation.
4. Pal's Peek lesson lost the consequences of getting caught.
5. Pal's invitation lesson lost its environment-scan/accept instructions.

The independent 2026-08-03 Web playtest also found a main-thread blocking
warning during launch. Track and reproduce it under the performance prompt;
do not claim it caused the tutorial soft-lock without evidence.

## Required work

### A. Preserve and classify

1. Record status, diff stat, and commit before editing.
2. Review every changed file and group it by concern: tutorial, Scratch
   Tickets/save compaction, invitation/world state, UI/SFX, tests/tools, docs.
3. Identify incomplete call sites and overlapping edits.
4. Never revert user-owned work. Repair demonstrated defects in place and
   document the reason.

### B. Repair current red gates

1. Fix Sal's authored layout at the source while preserving distinct,
   reachable fixtures. Do not weaken the overlap assertion.
2. Restore the five tutorial semantic contracts while retaining valid voice
   and readability improvements.
3. Re-run narrow UI-scene and systems checks after each repair.
4. Treat new errors, leaks, clipped controls, and unreachable interactions as
   defects to root-cause.

### C. Verify integration boundaries

1. Confirm Scratch Ticket receipts and portable piles round-trip through
   save/load and legacy mask-heavy saves without changing outcomes.
2. Confirm invitation spawning is unique, persistent, and isolated correctly.
3. Confirm tutorial-only behavior never contaminates normal runs.
4. Confirm TalkDock/overlay geometry does not break non-tutorial input.
5. Confirm SFX/prewarm and snapshot changes do not reintroduce hitches or
   frozen idle animation.

### D. Produce reviewable commits

After applicable gates pass, split work into logical commits by concern. Stage
explicitly by file/hunk. Do not mix unrelated tutorial, Scratch Ticket,
performance, and release-document changes merely because they share one tree.

## Required gates

- `git diff --check`
- `tools\validate_project.ps1`
- `tools\check_godot.ps1 -Smoke -TimeoutSec 300`
- FoundationSuite `systems`, `scratch_tickets`, and `ui`
- every other FoundationSuite affected by the final diff
- focused tutorial route/isolation and Scratch Ticket save/interaction checks

Use measured longer timeouts where required; never reduce coverage to finish.

## Deliverable

Create `docs/plans/v05_integration_gate_recovery.md` with starting/final Git
state, change inventory, each root cause/fix, compatibility findings, fresh
gate evidence, commit hashes, and work deferred to later prompts.

## Completion and archive

Complete only when the intended integration is committed logically, required
gates are green, and no user-owned change is lost. Prepend an execution record
and move this file to `docs/todone/`. Do not push without user authorization.
