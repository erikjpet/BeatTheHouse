# Beat the House 0.5 pre-release completion queue

Last reconciled: 2026-08-03

## Current verdict

**0.5.0 is feature-complete, but it is not release-ready.**

The committed feature queue has drained into `docs/todone/`, but release
closure is blocked by an unverified local integration workset, first-time
player tutorial follow-up, and the retained-memory soak failure documented in
`docs/plans/0.5_performance_audit.md`.

Current repository state at this reconciliation:

- `main` matches `origin/main` at `2b8cb664`.
- Before this queue-only documentation update, the working tree contained 36
  modified tracked files and one untracked document, totaling approximately
  1,993 additions and 282 deletions.
- The local work spans tutorial/dialogue presentation, tutorial travel and
  progression, Scratch Tickets interaction and save compaction, Grand Casino
  invitation flow, SFX/UI behavior, and their tests and performance probes.
- The newest recorded smoke run passes project validation, Godot import, and
  GDScript loading, but fails UI scene compilation because Sal's authored
  pawn-shop fixtures overlap.
- An earlier systems run against this workset also reports five tutorial
  dialogue-contract regressions.
- The full retained-state soak remains over budget at 279,116.400 bytes per
  sample against a 262,144-byte limit.
- There is no `v0.5.0` tag and no final release package recorded under
  `builds/`.

The historical source-prep evidence in
`docs/plans/0.5_release_checklist.md` remains useful for the committed
baseline, but it does not make the current uncommitted worktree release-ready.
This queue is the current source of truth for remaining 0.5 work.

## Execution order

### 1. Preserve and reconcile the current worktree

Status: **IN PROGRESS / NOT GREEN**

Binding prompt:
`docs/todo/current_worktree_integration_gate_recovery_prompt.md`

- [ ] Treat every existing modification and the untracked
  `docs/plans/tutorial_first_time_player_review.md` as user-owned work; do not
  revert, overwrite, or stage it indiscriminately.
- [ ] Inventory the work by concern and split it into reviewable logical
  commits only after the relevant gates pass.
- [ ] Fix the current UI scene compilation failure: overlapping Sal's
  pawn-shop fixtures (`meta_sal_shelf:0`/`:4` and
  `meta_pawn_counter:sell`/`meta_sal:talk`).
- [ ] Restore the five tutorial binding requirements reported by the systems
  suite without undoing the intended writing/tutorial improvements:
  - Pal's parking tip must explain its later use.
  - Pal's Crew warning must retain the required last-place-you-turn meaning.
  - Pal's lookaway lesson must identify the easiest cheat and the real
    spill-a-drink control.
  - Pal's Peek lesson must state the consequences of getting caught.
  - Pal's invitation lesson must retain the environment-scan and acceptance
    instructions.
- [ ] Re-run `tools/validate_project.ps1`, Smoke, and the affected systems/UI
  suites until they pass without `ERROR:`/`SCRIPT ERROR:` output or new leak
  warnings.
- [ ] Run `git diff --check` and review the final diff for accidental scope,
  generated artifacts, debug output, and user-owned changes before committing.

Do not push this integration work merely because it loads. It must first be
green and separated into understandable commits.

### 2. Complete the tutorial as a first-time-player experience

Status: **P0 REAL-INTERFACE SOFT-LOCK; SECOND AUDIT RECEIVED**

Binding prompt:
`docs/todo/tutorial_first_time_player_completion_prompt.md`

The committed scripted tutorial satisfies the 20 requirements in
`docs/plans/tutorial_verification.md`, but the later novice review in
`docs/plans/tutorial_first_time_player_review.md` finds it mechanically
complete and still incomplete for a genuinely new player.

The second independent audit used a fresh Web debug export at 1280x720, actual
UI, real pointer clicks, a clean browser origin, and an existing-profile Replay
Lessons entry. Both entry paths soft-lock in the opening flow. They start in
Motel Room, run deprecated Dealer's Advice tips, omit the forced X-ray Glasses,
and eventually point an inert highlight at empty space while the real door is
offscreen. Overlay lifecycle is also broken across Run Menu and main-menu
return. Every later tutorial scene is therefore unproven through the real
interface, regardless of the older scripted verification.

Do not mark the tutorial complete until both full routes and Replay Lessons
pass through the real interface with real mouse input and no state injection,
skip-based bypass, dead click, misleading highlight, or stale overlay.

Known work already identified by the first-time-player review:

#### P0 - required before tutorial completion

- [ ] TUT-N01: make every tutorial speaker name, line, and response fully
  readable at 1280x720; eliminate blank nameplates, clipping, and off-screen
  controls.
- [ ] TUT-N02: keep dialogue and portraits from covering the highlighted
  object or game control; every instruction and target must be usable at the
  same time.
- [ ] TUT-N03: teach the first-minute mental model: the run goal, failure
  conditions, Bankroll, Heat, Drunk, time, Inventory, active items, and the
  purpose of the guided first night.
- [ ] TUT-N04: teach Blackjack basics before testing Blackjack, including 21,
  busting, dealer comparison, card values, Hit, Stand, and when a wager locks.
- [ ] TUT-N05: guarantee Heat comprehension on both perfect and mistake
  routes, with exact risks and recovery/avoidance guidance.
- [ ] TUT-N06: clear, collapse, or expire stale result messages at travel,
  game, and guided-conversation context boundaries.
- [ ] TUT-N07: repair and expand the ending, standardize Players Card tier
  terminology, recap the learned systems, and clearly hand the player into a
  normal run.

#### P1 - required comprehension improvements

- [ ] TUT-N08: state actual item effects and clearly label passive, active,
  equipped, consumable, and permanent behavior.
- [ ] TUT-N09: teach money and debt with visible numbers: price, remaining
  bankroll, loan amount/source, repayment rule, and debt-first cashout.
- [ ] TUT-N10: make the pull-tab/X-ray route a visible procedure with stack,
  distance, total cost, and Buy/Collect/Peel/File/Redeem steps.
- [ ] TUT-N11: explain cheating resources, the information gained, count
  values and benefit, miss penalties, and the consequences of getting caught.
- [ ] TUT-N12: show concrete Bronze progress and a clear return-to-Linda state.
- [ ] TUT-N13: split Linda's cash/chips/shop/debt lesson into digestible steps,
  show the exact comp reward, and require inspection of one chip-priced offer.

#### P2 - polish and resilience

- [ ] TUT-N14: make blocked actions explain the current required action and
  keep its target highlighted.
- [ ] TUT-N15: clarify travel cost, elapsed time, open/closed state, and the
  optional recommended route.
- [ ] TUT-N16: reduce repeated guidance during multi-step interactions.
- [ ] TUT-N17: complete a true novice usability gate: at least five cold
  testers, including at least two without Blackjack knowledge, with 5/5
  completion without intervention and at least 80% core-concept comprehension.

#### Second-audit findings and binding acceptance

- [x] Receive and incorporate the second agent's real-interface audit.
- [x] De-duplicate its findings against TUT-N01 through TUT-N17 and assign new
  findings TUT-N18 through TUT-N25 in the binding tutorial prompt.
- [ ] Fix New Run and Replay Lessons so both enter Apartment and reach Pal,
  never the deprecated Dealer's Advice/tip-first chain.
- [ ] Restore the X-ray starting item and storage/inventory flow.
- [ ] Keep camera focus, rendered target, highlight transform, and real hit
  region synchronized; visible highlights must be purely visual and clickable
  through to their actual target.
- [ ] Fix overlay suspension/cleanup across Inventory, Run Menu, map, other
  modals, scene changes, and main-menu return.
- [ ] Make skip/recovery advance safely rather than loop backward.
- [ ] Raise scene-label and secondary-object-text contrast for Web at 1280x720.
- [ ] Complete the binding real-interface visual acceptance matrix in the
  tutorial prompt for Apartment, travel/store, both routes, Blackjack,
  invitation, Grand Casino/Bronze, ending, and every modal transition.
- [ ] Re-run scripted routes, isolation, save/load, determinism, stuck-state,
  visual capture, strict input, real-interface mouse, and novice-comprehension
  gates on the final implementation. Scripted success alone cannot close the
  tutorial.

### 3. Close the final performance and cleanup audit

Status: **BLOCKED BY FULL RETAINED-STATE SOAK**

Binding prompt:
`docs/todo/performance_cleanup_final_audit_prompt.md`

- [ ] Root-cause and fix the retained static-memory slope without weakening
  the 262,144-byte/sample limit or changing deterministic simulation.
- [ ] Confirm that the current Scratch Ticket receipt/mask compaction work is
  correct, backward-compatible, and actually improves long-session retained
  memory rather than merely serialized size.
- [ ] Repeat the full 180-minute/504-action retained soak after the final
  tutorial and integration changes; a short diagnostic soak is not sufficient.
- [ ] Re-run all gates required by the active audit prompt: project validation,
  every supported FoundationSuite, native performance and liveness, soak,
  determinism, throttled web, strict mouse batch, and visual QA.
- [ ] Update `docs/plans/0.5_performance_audit.md` with final before/after
  evidence and a truthful release verdict.
- [ ] Archive the prompt to `docs/todone/` with an execution record only after
  every binding gate passes.

### 4. Build and approve the final release candidate

Status: **PENDING STEPS 1-3**

Binding prompt:
`docs/todo/v05_final_release_candidate_approval_prompt.md`

- [ ] Run the complete release gate matrix on the exact commit intended for
  release, not on an earlier committed baseline or a dirty worktree.
- [ ] Refresh tutorial, Sal's shelf, Scratch Tickets, Grand Casino, and other
  affected visual evidence after the final UI changes.
- [ ] Complete the owner's final hands-on playtest across Web and Windows,
  including a fresh-profile tutorial and a normal run after tutorial
  completion.
- [ ] Confirm there are no stutters, hangs, frozen idle animation, clipped or
  occluded tutorial instructions, stale result messages, soft-locks, save/load
  regressions, or normal-run contamination.
- [ ] Decide whether the collection schema ships with `draft: true`; either
  record owner acceptance as a release limitation or request and verify the
  schema-finalization change.
- [ ] Review and approve the final publish copy, screenshots, changelog, known
  limitations, and safety framing.

### 5. Package and publish 0.5.0

Status: **OWNER RELEASE ACTIONS; NOT STARTED**

Binding owner checklist:
`docs/todo/v05_owner_packaging_and_publish_checklist.md`

- [ ] Produce final Web and Windows packages from the approved release commit
  and record filenames, sizes, and SHA-256 hashes.
- [ ] Smoke-test the packaged artifacts rather than only the editor/source
  build.
- [ ] Upload the Web build to the itch `html` channel and the Windows build to
  the `windows` channel with user version `0.5.0`.
- [ ] Publish the approved itch/GitHub release copy and artifacts.
- [ ] Create and push `v0.5.0` only after playtest, packaging, upload, and
  artifact verification are complete.
- [ ] Record the final release evidence and update README/CHANGELOG language
  from development status to the published state.

## Definition of 0.5 complete

0.5 is complete only when all of the following are true:

- [ ] The worktree is clean and the intended release commit is on the remote.
- [ ] The second tutorial audit has been incorporated and every accepted
  tutorial blocker has evidence of resolution.
- [ ] Scripted tutorial, simulated-player, strict input, and cold-player
  comprehension gates are green.
- [ ] The retained-memory soak and every other final performance gate pass.
- [ ] The owner has approved the final hands-on Web and Windows playtest.
- [ ] The collection `draft` decision and all accepted limitations are
  documented.
- [ ] Final packages are verified and published.
- [ ] The `v0.5.0` tag points to the exact published source commit.

## Already completed and archived

The former SFX rework, video-poker machine rework, writing voice pass,
edge-state/feature polish, meta-home UI pass, trailer work, playtest polish,
Cage rework, and the rest of the feature queue are archived under
`docs/todone/`. They are not active tasks. If final integration or testing
finds a regression in archived work, create a new follow-up task; do not edit
or reactivate the archived prompt.

## Working rules

- Never delete completed prompts; archive them with an execution record after
  verified completion.
- Never weaken a test, budget, liveness floor, or deterministic assertion just
  to make a release gate green.
- Never overwrite or revert user-owned dirty-worktree changes.
- Stage explicitly by file and concern. Do not mix unrelated fixes into a
  release commit.
- Historical reports describe the source they tested. Re-run their gates after
  later integration instead of treating old evidence as proof for new source.
