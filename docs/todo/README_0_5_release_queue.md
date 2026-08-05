# Beat the House 0.5 Pre-Release Completion Queue

Last reconciled: 2026-08-05
Authoritative audit: `docs/plans/0.5_pre_release_audit.md`

## Current verdict

**0.5.0 is substantially implemented but is not feature-complete under its own
prompts and is not release-approved.**

The large 0.5 systems, pre-human tutorial route, Web/audio performance work,
and runtime-storage root fix are present. Two deliberately split feature
prompts remain open, the committed tree has Systems/UI regressions, the script
load gate can report false green, and the current worktree contains uncommitted
owner changes. Human tutorial acceptance, owner decisions, exact-source RC
approval, packaging, publication, and `v0.5.0` are also pending.

Current identity:

- committed `main`: `58519d4a08add056dd63ba3734c99addca130cdb`;
- `main` is five commits ahead of `origin/main` at this reconciliation;
- working tree is dirty with the in-progress narration/audio-bus rollout;
- no `v0.5.0` tag exists;
- generic files under `builds/` are not approved 0.5 artifacts.

## Binding execution order

### 0. Reconcile the current user-owned worktree

Status: **OPEN**

- [ ] Finish and verify the narration/audio-bus work already present, or record
  an explicit owner decision to defer it from 0.5.
- [ ] Commit included work in intentional units. Do not discard or sweep-stage
  unrelated files.
- [ ] Establish one clean committed source identity before candidate gates.

### 1. Restore release-gate truth and fix committed regressions

Status: **OPEN / P0**
Binding prompt: `docs/todo/v05_release_gate_truth_and_regression_prompt.md`

- [ ] Make GDScript/direct-load and generated-runner coverage honest; a parse
  error may not yield a PASS report.
- [ ] Fix the three clean-HEAD travel/content Systems failures.
- [ ] Fix off-tree inventory focus, leaked resource/error output, and the
  bag-reel anchor warning.
- [ ] Fix the reproducible world-map focus snap at the state-machine seam.
- [ ] Reconcile the tutorial dealer-reprieve line and contract in the current
  narration tree.
- [ ] Archive only after clean Systems/UI and strict stderr evidence.

### 2. Complete the promised inventory redesign

Status: **OPEN**
Binding prompt: `docs/todo/tutorial_inventory_rework_prompt.md`

- [ ] Deliver the shared item-card/view-model contract for run inventory and
  meta storage, responsive card/detail presentation, badges/affinity/stack,
  and source-level risk exclusion.
- [ ] Reconcile the full item-description voice pass with the narration rollout
  rather than rewriting or reverting it independently.
- [ ] Capture desktop/small-screen evidence and archive after all gates pass.

### 3. Complete meaningful destination decisions

Status: **PARTIAL / OPEN**
Binding prompt: `docs/todo/tutorial_meaningful_decisions_prompt.md`

- [x] Tutorial Gas Casino versus Underground fork exists and rejoins safely.
- [ ] Make whole-run destinations expose honest offer/forfeit tradeoffs.
- [ ] Back the visible differences with deterministic route/environment/event
  data, not flavor text over equivalent destinations.
- [ ] Prove both tutorial branches and representative normal-run decisions.

### 4. Refresh final performance and fidelity evidence

Status: **HISTORICAL GATES GREEN; EXACT FINAL SOURCE PENDING**
Binding prompt: `docs/todo/performance_cleanup_final_audit_prompt.md`

- [x] Historical native, Web, liveness, 180-minute soak, Scratch RTP, Grand
  Casino, and slot runtime/storage root-fix budgets are green.
- [ ] After steps 0-3, rerun every binding performance, soak, determinism, Web,
  strict-input, visual, save/migration, and storage gate on the exact source.
- [ ] Archive the performance prompt with the final-source execution record.

### 5. Complete the human tutorial gate

Status: **TUT-N01-N16/N18-N25 PASS; TUT-N17 OPEN**
Binding prompt: `docs/todo/tutorial_first_time_player_completion_prompt.md`

- [ ] Test five cold players, including at least two without Blackjack
  knowledge.
- [ ] Require 5/5 unassisted completion and at least 80% aggregate core-concept
  comprehension; record route, interventions, misses, and observations.
- [ ] Fix any discovered blocker through a new scoped defect prompt, rerun
  affected automation, and repeat invalidated human trials.
- [ ] Archive only when TUT-N17 genuinely passes.

### 6. Build and approve one exact release candidate

Status: **BLOCKED BY STEPS 0-5 AND OWNER DECISIONS**
Binding prompt: `docs/todo/v05_final_release_candidate_approval_prompt.md`

- [ ] Run the complete matrix on one clean commit, not a historical report or
  dirty tree.
- [ ] Refresh and inspect all player-facing captures.
- [ ] Complete owner Web/Windows hands-on play and approve or reject the exact
  hash.
- [ ] Record the collection `draft: true` decision, limitations, publish copy,
  screenshots, safety framing, and supported platforms.

### 7. Package and publish 0.5.0

Status: **OWNER-CONTROLLED / NOT STARTED**
Binding checklist: `docs/todo/v05_owner_packaging_and_publish_checklist.md`

- [ ] Build and verify Web/Windows packages from the approved commit.
- [ ] Record names, sizes, SHA-256 hashes, tool versions, and packaged-artifact
  playtests.
- [ ] With explicit owner authorization, upload/publish itch and GitHub.
- [ ] Create and push annotated `v0.5.0` at the exact published source.
- [ ] Reconcile README, CHANGELOG, release checklist, URLs, and hashes.

## Definition of 0.5 complete

- [ ] All active implementation/regression prompts are archived with evidence.
- [ ] The final exact-source matrix is green with clean classified stderr and
  unchanged budgets/liveness floors.
- [ ] TUT-N17 and owner Web/Windows hands-on play pass.
- [ ] The collection decision and every accepted limitation are recorded.
- [ ] Verified Web/Windows artifacts are published.
- [ ] `v0.5.0` points to the exact published source and public records agree.

## Working rules

- Historical reports prove only the hash they tested.
- Never weaken a test, budget, liveness floor, deterministic assertion, or
  human gate to declare release readiness.
- Never overwrite, revert, or indiscriminately stage user-owned work.
- Archive completed prompts; do not delete them.
- Any post-approval code change invalidates the candidate and reruns affected
  gates and artifact builds.
