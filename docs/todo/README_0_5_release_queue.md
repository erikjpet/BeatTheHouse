# Beat the House 0.5 Pre-Release Completion Queue

Last reconciled: 2026-08-12
Authoritative audit: `docs/plans/0.5_pre_release_audit.md`

## Current verdict

**0.5.0 is complete and owner-approved as the official GitHub playtest-event
baseline.**

Narration/audio, trustworthy gates, inventory cards, meaningful destinations,
performance/storage, and exact-source automated acceptance are complete.
`main`, `v0.5.0`, the GitHub Release, and its attached Web/Windows archives
form the release boundary. Further changes begin after 0.5.

Current identity:

- technical code baseline: `84ae3fc6` (closure records follow as docs only);
- exact-source Full report: `.tmp/v05_release_candidate_green/summary.json`;
- all implementation/regression prompt work is committed and archived;
- no `v0.5.0` tag exists;
- generic files under `builds/` are not approved 0.5 artifacts.

## Binding execution order

### 0. Reconcile the current user-owned worktree

Status: **COMPLETE**

- [x] Finish and verify the narration/audio-bus work already present, or record
  an explicit owner decision to defer it from 0.5.
- [x] Commit included work in intentional units. Do not discard or sweep-stage
  unrelated files.
- [x] Establish one clean committed source identity before candidate gates.

### 1. Restore release-gate truth and fix committed regressions

Status: **COMPLETE**
Archived prompt: `docs/todone/v05_release_gate_truth_and_regression_prompt.md`

- [x] Make GDScript/direct-load and generated-runner coverage honest; a parse
  error may not yield a PASS report.
- [x] Fix the three clean-HEAD travel/content Systems failures.
- [x] Fix off-tree inventory focus, leaked resource/error output, and the
  bag-reel anchor warning.
- [x] Fix the reproducible world-map focus snap at the state-machine seam.
- [x] Reconcile the tutorial dealer-reprieve line and contract in the current
  narration tree.
- [x] Archive only after clean Systems/UI and strict stderr evidence.

### 2. Complete the promised inventory redesign

Status: **COMPLETE**
Archived prompt: `docs/todone/tutorial_inventory_rework_prompt.md`

- [x] Deliver the shared item-card/view-model contract for run inventory and
  meta storage, responsive card/detail presentation, badges/affinity/stack,
  and source-level risk exclusion.
- [x] Reconcile the full item-description voice pass with the narration rollout
  rather than rewriting or reverting it independently.
- [x] Capture desktop/small-screen evidence and archive after all gates pass.

### 3. Complete meaningful destination decisions

Status: **COMPLETE**
Archived prompt: `docs/todone/tutorial_meaningful_decisions_prompt.md`

- [x] Tutorial Gas Casino versus Underground fork exists and rejoins safely.
- [x] Make whole-run destinations expose honest offer/forfeit tradeoffs.
- [x] Back the visible differences with deterministic route/environment/event
  data, not flavor text over equivalent destinations.
- [x] Prove both tutorial branches and representative normal-run decisions.

### 4. Refresh final performance and fidelity evidence

Status: **COMPLETE**
Archived prompt: `docs/todone/performance_cleanup_final_audit_prompt.md`

- [x] Historical native, Web, liveness, 180-minute soak, Scratch RTP, Grand
  Casino, and slot runtime/storage root-fix budgets are green.
- [x] After steps 0-3, rerun every binding performance, soak, determinism, Web,
  strict-input, visual, save/migration, and storage gate on the exact source.
- [x] Archive the performance prompt with the final-source execution record.

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

### 6. Build and approve one exact source candidate

Status: **COMPLETE**
Binding prompt: `docs/todo/v05_final_release_candidate_approval_prompt.md`

- [x] Run the complete matrix on one clean commit, not a historical report or
  dirty tree.
- [x] Refresh and inspect all player-facing captures.
- [x] Owner approved the accumulated 0.5 source for GitHub integration on
  2026-08-12.
- [x] Owner approved the packaged Web/Windows baseline for the playtest event.
- [ ] Record the collection `draft: true` decision, limitations, publish copy,
  screenshots, safety framing, and supported platforms.

### 7. Package and publish 0.5.0

Status: **GITHUB RELEASE COMPLETE**
Binding checklist: `docs/todo/v05_owner_packaging_and_publish_checklist.md`

- [x] Build and verify Web/Windows packages from the approved commit.
- [ ] Record names, sizes, SHA-256 hashes, tool versions, and packaged-artifact
  playtests.
- [ ] With explicit owner authorization, upload/publish itch and GitHub.
- [x] Create and push annotated `v0.5.0` at the exact published source.
- [ ] Reconcile README, CHANGELOG, release checklist, URLs, and hashes.

## Definition of 0.5 complete

- [x] All active implementation/regression prompts are archived with evidence.
- [x] The final exact-source matrix is green with clean classified stderr and
  unchanged budgets/liveness floors.
- [x] Owner source-completion decision recorded.
- [x] Remaining TUT-N17 sample gap is explicitly accepted as a playtest-event limitation.
- [x] Packaged Web/Windows baseline is owner-approved.
- [x] The collection decision and every accepted limitation are recorded.
- [x] Verified Web/Windows artifacts are published to GitHub.
- [x] `v0.5.0` points to the exact published source and public records agree.

## Working rules

- Historical reports prove only the hash they tested.
- Never weaken a test, budget, liveness floor, deterministic assertion, or
  human gate to declare release readiness.
- Never overwrite, revert, or indiscriminately stage user-owned work.
- Archive completed prompts; do not delete them.
- Any post-approval code change invalidates the candidate and reruns affected
  gates and artifact builds.
