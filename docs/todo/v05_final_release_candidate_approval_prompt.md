# Agent Prompt — Build and Approve the Final 0.5 Release Candidate

Last reconciled: 2026-08-05
Release target: 0.5.0
Status: BLOCKED BY IMPLEMENTATION, GATE-TRUTH, TUT-N17, AND OWNER APPROVAL

## Objective

Produce one clean, fully verified 0.5.0 release-candidate commit and the
evidence required for owner approval. This task does not authorize publishing,
uploading, creating a release, or pushing a tag.

## Entry conditions

Integration recovery is complete and archived at
`docs/todone/current_worktree_integration_gate_recovery_prompt.md`. Do not
start final RC approval until every implementation/regression prompt is
complete and archived and the intended source is clean:

- `v05_release_gate_truth_and_regression_prompt.md`;
- `tutorial_inventory_rework_prompt.md`;
- `tutorial_meaningful_decisions_prompt.md`;
- `tutorial_first_time_player_completion_prompt.md`;
- `performance_cleanup_final_audit_prompt.md`.

The tutorial is agent-verifiable through TUT-N25 except for human-only
TUT-N17. Historical performance evidence closed native, memory-soak, Scratch
Ticket, Grand Casino runtime, 20-second Web cold-ready, broad L0.2, and slot
runtime/storage work, but it must be refreshed after the remaining changes.
See the current queue and audit; neither historical green nor historical red
is a substitute for the exact candidate matrix.

The intended source must be committed and clean. If an entry condition is not
satisfied, return to its owning prompt rather than manufacturing an RC verdict.

## Candidate identity and documentation

1. Record branch, full commit hash, Git status, Godot/tool versions, and any
   dependency state.
2. Confirm `project.godot` and all export presets consistently identify 0.5.0.
3. Reconcile README, CHANGELOG, publish copy, screenshots, known limitations,
   and release checklist with the exact candidate.
4. Remove/scope historical “tutorial complete” or “release-ready” language
   that is not supported by final real-interface evidence.

## Complete gate matrix

Run every supported validation/FoundationSuite and the final tutorial,
performance/liveness, 180-minute soak, determinism, stuck-state, strict input,
web performance, visual QA, collection, content, and export gates against the
exact RC commit. Record commands, versions, timings, report paths, and hashes.

Any error, unexpected leak, timeout, budget miss, stuck state, dead click,
misaligned highlight, stale overlay, clipped instruction, or nondeterministic
hash fails the candidate. Fix it under the appropriate prompt and refresh the
affected evidence; never waive it silently.

## Player-facing evidence

Refresh and inspect full-resolution captures for:

- start screen/version;
- the complete tutorial matrix from both New Run and Replay Lessons;
- Sal's shelf and every repaired interaction target;
- Scratch Ticket purchase, scratch, result, filing, piles, redemption, and
  save/load;
- Grand Casino invitation/rooms and run report;
- meta home and normal-run handoff.

Capture generation is not visual approval. Inspect every image for text fit,
contrast, focus, layering, target/hit alignment, and stale state.

## Owner hands-on approval

Prepare a manual Web/Windows script covering a fresh profile, both tutorial
routes with real mouse input, Replay Lessons, a normal run after tutorial, all
eight games, representative cheats, store/map/inventory/events/debt, Grand
Casino/Cage/card progression, run end/meta home, save/load, and sustained play.

The owner must perform or explicitly approve the final hands-on playtest.
Automation cannot check this item on the owner's behalf.

## Release decisions

- Obtain the owner's decision on collection schema `draft: true`: accepted
  limitation or verified schema-finalization change.
- Confirm all known limitations are honest and none conceals a blocker.
- Obtain approval for itch/GitHub copy, screenshots, changelog, safety framing,
  and supported platforms.

## Deliverable

Update `docs/plans/0.5_release_checklist.md` and create
`docs/plans/0.5_final_rc_evidence.md` with exact identity, complete fresh gate
matrix, visual inventory, owner playtest, collection decision, limitations,
packaging instructions, and an explicit APPROVED or REJECTED verdict.

## Completion and archive

Complete only when the exact clean commit is green, the binding tutorial
real-interface matrix passes, the owner playtest/decisions are recorded, and
the owner approves that commit for packaging. Prepend an execution record and
archive this file. Do not upload, publish, or tag under this prompt.
