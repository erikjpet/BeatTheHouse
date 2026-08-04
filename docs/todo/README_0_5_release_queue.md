# Beat the House 0.5 pre-release completion queue

Last reconciled: 2026-08-04

## Current verdict

**0.5.0 is feature-complete and the integrated source is on `main`, but it is
not release-approved.**

Integration recovery, the agent-verifiable tutorial work, native
performance/liveness, the full retained-memory soak, Scratch Ticket compaction,
and Grand Casino Web runtime repair are complete. Release closure is now
blocked by the final broad Web performance verdict, the human-only TUT-N17
cold-player gate, owner Web/Windows playtesting, the collection `draft`
decision, packaging, publication, and tagging.

Current repository state at this reconciliation:

- The consolidated implementation checkpoint before this documentation truth
  pass is `6256d20584fa3b7b6c2100def716a8fa7900308b`. `main` is the only local
  and remote branch; the implementation worktree was clean at reconciliation.
- The former dirty integration workset landed in logical commits. Sal's fixture
  overlaps and the five tutorial dialogue contracts are fixed; the integration
  recovery report is `docs/plans/v05_integration_gate_recovery.md`.
- TUT-N01 through TUT-N16 and TUT-N18 through TUT-N25 pass scripted and
  agent-driven real-pointer coverage through both authored routes. TUT-N17 is
  still pending five human cold players; see
  `docs/plans/tutorial_completion_report.md`.
- The 180-minute/504-action soak passes with a negative retained-memory trend,
  bounded Scratch Ticket receipts, and zero retained orphans. Native budgets,
  liveness, determinism, Grand Casino Web runtime, and Scratch RTP are green.
- High-fidelity Web music/SFX parity is implemented. The safe 4/1 threaded
  worker configuration improves 4x-throttled cold ready from 26.855 seconds to
  23.776 seconds, which still misses the unchanged 20-second gate. The broad
  L0.2 Web matrix also needs a final exact-source closure run.
- There is no `v0.5.0` tag and no final release package recorded under
  `builds/`.

Historical evidence remains useful only for the commit it tested. This queue
and `docs/plans/0.5_release_checklist.md` identify the remaining gates for the
current clean `main` source.

## Execution order

### 1. Preserve and reconcile the current worktree

Status: **COMPLETE AND ARCHIVED**

Execution record:
`docs/todone/current_worktree_integration_gate_recovery_prompt.md`

- [x] Treat every existing modification and the untracked
  `docs/plans/tutorial_first_time_player_review.md` as user-owned work; do not
  revert, overwrite, or stage it indiscriminately.
- [x] Inventory the work by concern and split it into reviewable logical
  commits only after the relevant gates pass.
- [x] Fix the current UI scene compilation failure: overlapping Sal's
  pawn-shop fixtures (`meta_sal_shelf:0`/`:4` and
  `meta_pawn_counter:sell`/`meta_sal:talk`).
- [x] Restore the five tutorial binding requirements reported by the systems
  suite without undoing the intended writing/tutorial improvements:
  - Pal's parking tip must explain its later use.
  - Pal's Crew warning must retain the required last-place-you-turn meaning.
  - Pal's lookaway lesson must identify the easiest cheat and the real
    spill-a-drink control.
  - Pal's Peek lesson must state the consequences of getting caught.
  - Pal's invitation lesson must retain the environment-scan and acceptance
    instructions.
- [x] Re-run `tools/validate_project.ps1`, Smoke, and the affected systems/UI
  suites until they pass without `ERROR:`/`SCRIPT ERROR:` output or new leak
  warnings.
- [x] Run `git diff --check` and review the final diff for accidental scope,
  generated artifacts, debug output, and user-owned changes before committing.

Landed as `5389fba8` and documented by `bcbc8f0a`; the later consolidated
source is now on `main`.

### 2. Complete the tutorial as a first-time-player experience

Status: **PRE-HUMAN COMPLETE; TUT-N17 PENDING HUMAN**

Binding prompt:
`docs/todo/tutorial_first_time_player_completion_prompt.md`

The second audit's opening soft-lock, home-state leak, missing X-ray item,
highlight/hit-region drift, modal ownership, and teaching defects were repaired
in `6074ce35` and `0113eabf`. Clean-origin New Run and Replay Lessons now start
in Apartment, avoid Dealer's Advice/`tip_first_*`, and complete both Path A and
the authored Path B skip through Bronze and the normal-run handoff using the
real interface and real pointer input. The exact requirement and evidence table
is `docs/plans/tutorial_completion_report.md`.

Do not call the tutorial human-approved until TUT-N17 is performed by five cold
players. Agent automation and agent-driven real-interface play cannot complete
that requirement.

Known work already identified by the first-time-player review:

#### P0 - required before tutorial completion

- [x] TUT-N01: make every tutorial speaker name, line, and response fully
  readable at 1280x720; eliminate blank nameplates, clipping, and off-screen
  controls.
- [x] TUT-N02: keep dialogue and portraits from covering the highlighted
  object or game control; every instruction and target must be usable at the
  same time.
- [x] TUT-N03: teach the first-minute mental model: the run goal, failure
  conditions, Bankroll, Heat, Drunk, time, Inventory, active items, and the
  purpose of the guided first night.
- [x] TUT-N04: teach Blackjack basics before testing Blackjack, including 21,
  busting, dealer comparison, card values, Hit, Stand, and when a wager locks.
- [x] TUT-N05: guarantee Heat comprehension on both perfect and mistake
  routes, with exact risks and recovery/avoidance guidance.
- [x] TUT-N06: clear, collapse, or expire stale result messages at travel,
  game, and guided-conversation context boundaries.
- [x] TUT-N07: repair and expand the ending, standardize Players Card tier
  terminology, recap the learned systems, and clearly hand the player into a
  normal run.

#### P1 - required comprehension improvements

- [x] TUT-N08: state actual item effects and clearly label passive, active,
  equipped, consumable, and permanent behavior.
- [x] TUT-N09: teach money and debt with visible numbers: price, remaining
  bankroll, loan amount/source, repayment rule, and debt-first cashout.
- [x] TUT-N10: make the pull-tab/X-ray route a visible procedure with stack,
  distance, total cost, and Buy/Collect/Peel/File/Redeem steps.
- [x] TUT-N11: explain cheating resources, the information gained, count
  values and benefit, miss penalties, and the consequences of getting caught.
- [x] TUT-N12: show concrete Bronze progress and a clear return-to-Linda state.
- [x] TUT-N13: split Linda's cash/chips/shop/debt lesson into digestible steps,
  show the exact comp reward, and require inspection of one chip-priced offer.

#### P2 - polish and resilience

- [x] TUT-N14: make blocked actions explain the current required action and
  keep its target highlighted.
- [x] TUT-N15: clarify travel cost, elapsed time, open/closed state, and the
  optional recommended route.
- [x] TUT-N16: reduce repeated guidance during multi-step interactions.
- [ ] TUT-N17: complete a true novice usability gate: at least five cold
  testers, including at least two without Blackjack knowledge, with 5/5
  completion without intervention and at least 80% core-concept comprehension.

#### Second-audit findings and binding acceptance

- [x] Receive and incorporate the second agent's real-interface audit.
- [x] De-duplicate its findings against TUT-N01 through TUT-N17 and assign new
  findings TUT-N18 through TUT-N25 in the binding tutorial prompt.
- [x] Fix New Run and Replay Lessons so both enter Apartment and reach Pal,
  never the deprecated Dealer's Advice/tip-first chain.
- [x] Restore the X-ray starting item and storage/inventory flow.
- [x] Keep camera focus, rendered target, highlight transform, and real hit
  region synchronized; visible highlights must be purely visual and clickable
  through to their actual target.
- [x] Fix overlay suspension/cleanup across Inventory, Run Menu, map, other
  modals, scene changes, and main-menu return.
- [x] Make skip/recovery advance safely rather than loop backward.
- [x] Raise scene-label and secondary-object-text contrast for Web at 1280x720.
- [x] Complete the binding real-interface visual acceptance matrix in the
  tutorial prompt for Apartment, travel/store, both routes, Blackjack,
  invitation, Grand Casino/Bronze, ending, and every modal transition.
- [x] Re-run scripted routes, isolation, save/load, determinism, stuck-state,
  visual capture, strict input, real-interface mouse, and novice-comprehension
  gates on the final implementation. Scripted success alone cannot close the
  tutorial.

### 3. Close the final performance and cleanup audit

Status: **MEMORY/NATIVE/GRAND CASINO GREEN; FINAL WEB CLOSURE OPEN**

Binding prompt:
`docs/todo/performance_cleanup_final_audit_prompt.md`

- [x] Root-cause and fix the retained static-memory slope without weakening
  the 262,144-byte/sample limit or changing deterministic simulation.
- [x] Confirm that the current Scratch Ticket receipt/mask compaction work is
  correct, backward-compatible, and actually improves long-session retained
  memory rather than merely serialized size.
- [x] Repeat the full 180-minute/504-action retained soak after the final
  tutorial and integration changes; a short diagnostic soak is not sufficient.
- [ ] Re-run all gates required by the active audit prompt: project validation,
  every supported FoundationSuite, native performance and liveness, soak,
  determinism, throttled web, strict mouse batch, and visual QA.
- [x] Update `docs/plans/0.5_performance_audit.md` with final before/after
  evidence and a truthful release verdict.
- [ ] Archive the prompt to `docs/todone/` with an execution record only after
  every binding gate passes.

The remaining gate work is specifically the unchanged 20-second cold-ready
budget and a final broad L0.2 run with the high-fidelity Web audio delivery
active. Current safe 4/1 worker evidence is 23.776 seconds. Do not describe the
full Web matrix as green until both are closed; smaller/single-threaded worker
experiments were measured and rejected.

### 4. Build and approve the final release candidate

Status: **PRE-HUMAN MATERIAL PREPARED; BLOCKED BY STEP 3 AND OWNER GATES**

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

- [x] The integrated pre-human worktree is clean and its source is on the
  remote `main` branch. Final RC identity is not yet approved.
- [x] The second tutorial audit has been incorporated and every accepted
  tutorial blocker has evidence of resolution.
- [ ] Scripted tutorial, simulated-player, strict input, and cold-player
  comprehension gates are green. All except human-only TUT-N17 pass.
- [ ] The retained-memory soak passes; the final Web cold-start and broad L0.2
  performance gates remain open.
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
