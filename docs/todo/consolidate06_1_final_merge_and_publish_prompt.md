Status: QUEUED — runs only after `land06_0` reports its definition of done

# Agent Prompt — consolidate06_1: Final Consolidation, Publish, and Playtest Handoff

Copy everything below this line into one agent. Employ sub-agents for parallel
verification. Do not start until the precondition in section 0 is satisfied.

---

You are working in `D:\Projects\Beat-The-House`. Your job is to bring every piece
of completed work onto `main`, guarantee that nothing anyone has done is lost by
publishing it to GitHub, verify the result is genuinely playable, and hand the
owner a build for extensive playtesting.

This is the last agent task of 0.6 before the owner's playtest. Everything you do
is in service of one sentence: **when you are finished, no work exists only on
this machine, and `main` is the whole update.**

## 0. Precondition — do not start early

Run only after the `land06_0` project manager has reported its section 13
definition of done. Verify that yourself rather than trusting a message: read
`docs/todo/README_0_6_board.md` and confirm every active row is DONE, or is
explicitly PARKED or BLOCKED with a recorded reason.

If rows remain in flight, stop and report which ones. Do not finish another
agent's program for it, and do not start landing its rows yourself.

## 1. What "merge everything" does and does not mean

Taken literally, merging every branch would destroy `main`. There are roughly
135 local branches, including 62 preservation branches holding unreviewed
work-in-progress, rebase intermediates and reflog salvage. Merging those would
put unreviewed, unvalidated and in some cases abandoned code into the branch the
owner is about to playtest.

The guarantee the owner actually wants is: **nothing is lost, and `main` is
complete.** Those are two different mechanisms:

- **Completed, reviewed work is merged to `main`.**
- **Everything else is preserved by being pushed to the remote as a branch.**
  Pushed is safe. Merged is not the same as safe.

Never merge unreviewed work to `main` to satisfy a word in this prompt. If you
believe a preservation branch contains real completed work, that is a finding to
report, not a merge to perform.

## 2. Preflight and the current truth

Measured at the time this prompt was written; re-derive every number rather than
trusting it:

- `origin` is `https://github.com/erikjpet/BeatTheHouse.git`; `main` tracks
  `origin/main`.
- Local `main` was **60 commits ahead of and 1 commit behind** `origin/main`.
  That one behind matters — reconcile it by merging, never by force.
- **126 of 135 local branches have never been pushed.** Only nine exist on the
  remote.
- **519 commits are reachable locally but not from `origin/main`.** That number
  is the real measure of what is currently at risk on one machine.
- `.git` is roughly 722 MB. The largest unpushed blob is 7.1 MB, comfortably
  under GitHub's limits, so no history rewrite or LFS migration is needed.
- `salvage06_1` reported zero unreachable commits. Verify that still holds before
  you begin and again before you finish.

Record all of this in a consolidation ledger you keep current throughout.

## 3. Absolute constraints

- **Never force-push.** No `--force`, no `--force-with-lease`, no history
  rewrite, no rebase of anything already pushed, no deletion of any remote ref.
  If a push is rejected, fetch, understand why, and reconcile by merging.
- **Never delete anything** — no branch deletion, no worktree removal, no stash
  drop, no `gc --prune`, no `clean`. Cleanup is not part of this task.
- **No release activity.** No version bump, no release tag, no packaging, no
  publish to itch.io or any store, no changelog-as-release. This task makes the
  work safe and playable; `release06_1` remains parked and is the only task
  permitted to ship anything.
- **Owner artifacts stay untouched.** `.tmp/`, `.tools/`, `review_artifacts/`,
  editor state and build output are the owner's, are deliberately untracked, and
  are never staged, moved or removed.
- Pushing to GitHub is the one outward-facing action authorized here. Everything
  else stays local.

## 4. Phase 1 — Triage every ref

Start from `docs/plans/0.6_branch_and_work_inventory.md` produced by
`salvage06_1`, but re-derive its classifications — it was a snapshot and was
stale within hours.

For every local branch, assign exactly one disposition:

- **IN-MAIN** — every commit already reachable from `main`. Nothing to merge.
- **LAND** — completed, independently reviewed work that is not yet on `main`.
  This set should be nearly empty if `land06_0` finished; verify, do not assume.
- **PRESERVE** — unreviewed WIP, salvage branches, dangling and reflog chains.
  Pushed, never merged.
- **SUPERSEDED** — content obsolete, replaced by later work. Pushed for the
  record, never merged.

For each branch record: head, ahead/behind `main`, merge base, last activity,
owning row if any, disposition, and one concrete sentence on what it holds.
Where a disposition is genuinely ambiguous **and** the content looks valuable,
mark it UNRESOLVED and raise it in your report rather than guessing in either
direction.

The 62 `salvage/*` branches are PRESERVE by default. Most are rebase and amend
intermediates with no unique content. Do not spend the program's remaining time
triaging them one by one; that is a separate cleanup task for later. Push them
and move on.

## 5. Phase 2 — Land the LAND set

For each, one at a time, in dependency order:

1. Verify its independent review exists and names its exact head.
2. Rebase onto current `main`, or extract its net change if its history is
   entangled with other rows — several inherited branches carry other rows'
   commits, ledgers and reverted merges, and some sit behind `main`.
3. Run the row's gates on the exact head.
4. Merge to `main` with `--no-ff`.
5. Re-verify `main` is green at the new head before starting the next.

If a branch in this set lacks an independent review, it is not LAND. Reclassify
it PRESERVE and report it — do not review-and-land it yourself in a
consolidation task.

## 6. Phase 3 — Prove `main` is the whole update and is playable

Before anything is published:

- Every 0.6 board row is DONE, or PARKED or BLOCKED with a recorded reason.
  Produce that table.
- Run the full gate set on `main`'s exact head: project validation, the complete
  foundation matrix, 10-seed determinism, native/Web parity, performance with
  the mandatory idle-liveness counter-gate, accessibility, save and migration,
  and visual QA. An idle draw cost of 0.000 is a failure, not a pass.
- **Actually play it.** Launch the game and reach, on named seeds, each victory
  route including the crew heist route, the crew path from recruitment through a
  heist plan, a Police Sweep encounter, the coin pusher, craps, back-room poker,
  and a crew-ignoring control run. A gate suite passing is not evidence that the
  game is playable; someone has to hold the controls.
- Use the seed list and playtest script from `playtest06_2` if they exist. If
  they do not, say so plainly rather than inventing a substitute.
- Produce a local playtest build for the owner, and state exactly how to run it.

If `main` cannot be made green, stop and report. Do not publish a broken `main`
and do not weaken a gate, refresh a golden, or raise a budget to get past this
step.

## 7. Phase 4 — Publish to GitHub

Only after Phase 3 passes.

1. **Back up first.** Create a `git bundle` of every ref to a location outside
   the repository and verify it with `git bundle verify`. If a push goes wrong,
   this is the recovery path. Report its path and size.
2. `git fetch origin` and reconcile. Local `main` was one commit behind; merge
   that in properly and re-run a smoke gate afterwards. Never force.
3. **Push `main` first.** Verify `origin/main` matches your local head exactly
   before continuing.
4. **Push every remaining local branch**, preserving its name and namespace, so
   all 126 unpushed branches and all 519 currently-local-only commits exist on
   the remote. Push in batches, verify each batch, and never force. Expect this
   to take a while — the repository is large.
5. Optionally create one **annotated non-release tag** marking the playtest
   baseline, for example `playtest-0.6-<date>`. This is a bookmark, not a
   release: no version bump, no packaging, no publish.
6. **Verify the guarantee.** After pushing, confirm that no commit reachable from
   any local ref is missing from the remote, that every local branch has a remote
   counterpart, and that no unreachable commits exist. Report the final count of
   local-only commits — it must be zero.

If the remote rejects a push in a way that would require force or history
rewriting to resolve, **stop and report**. That is an owner decision, never
yours.

## 8. Phase 5 — Playtest handoff

Write a state-of-the-update document under `docs/plans/` containing:

- What shipped into `main` in 0.6, by system, in plain language.
- What is deliberately parked: `voice06_1`, `release06_1`, the post-playtest
  prompts `polish06_0` produced, and the remaining multi-seed scope of
  `balance06_1`.
- What is known-imperfect, with enough detail that the owner is not rediscovering
  it: `fix06_3` Phase 5 awaiting the Crossword Corner art direction; the coin
  pusher active-frame p95 budget raised from 16 ms to 22 ms, which is above the
  16.67 ms 60 fps frame time and needs an explicit owner decision; the two broken
  evidence citations, where committed documents reference untracked
  `review_artifacts/` PNGs and `.tmp/` directories; and any gate carrying a
  waiver.
- **What is deliberately absent**, stated first and plainly — production music
  above all, since the manifest holds only fixtures and its absence will
  otherwise dominate every impression.
- Where to start: the seeds and route through the content that reach the new work
  fastest.
- How findings come back: the capture format from `playtest06_2`, and the rule
  that defects become `fix06_*` rows while design objections become owner
  decisions recorded in the roadmap.

Also report, without acting on them: the untracked owner artifacts under
`review_artifacts/`, `.tmp/` and `.tools/` that are not in git and would not
survive a fresh clone, so the owner can decide whether any deserve preservation.

## 9. Terminal conditions and reporting

Stop and ask the owner only for: a `main` that cannot be made green; a push that
would require force or history rewriting; a branch whose disposition is genuinely
ambiguous and whose content looks valuable; or a decision this prompt names as
the owner's.

Everything else, proceed and record.

Your final response leads with: the `main` commit that is now published, the
number of branches pushed, the count of local-only commits remaining (which must
be zero), and whether `main` passed its gates and played.

Then include: the full disposition table, every row's final status, the landed
set with merge commits, the bundle path, the tag if you made one, the playtest
build location and how to run it, the state-of-the-update document path, all
known-imperfect items, and explicit confirmation that nothing was force-pushed,
no history was rewritten, no ref was deleted, no release activity was performed,
and no owner artifact was touched.
