Status: FINALIZE — handoff prompt for the agent holding `codex/cross-balance`

# Finalize Prompt — balance06_1, commit what exists and hand off

Copy everything below this line into the agent that owns `codex/cross-balance`.

---

Stop what you are currently doing and read this in full before your next action.

You are working in `D:\Projects\Beat-The-House-worktrees\cross-balance` on branch
`codex/cross-balance`. Your binding contract is
`docs/todo/balance06_1_cross_system_economy_audit_prompt.md`. A single project
manager agent is taking over the whole 0.6 landing effort after you, and it will
collect your branch by name. Your job now is to make what you have real,
committed and honest — not to finish the entire audit.

## 1. Where you actually are

Your branch head is `3d4a41da`, which is the Wave 1 claim commit. **You have
made zero commits since claiming the row, roughly thirteen hours ago.** Your
last file write was at 05:44 today.

You do have work on disk, uncommitted, under `.tmp/balance06_1/`:
`cross_economy_audit_repeat.json`, `determinism_first.json`,
`foundation_systems_retry1`, `smoke_retry2.json`, and `foundation_contracts_1`.

Two things follow. First, none of that is recoverable by anyone but you right
now — a `.tmp` directory is not a deliverable and the incoming PM cannot collect
it. Second, the shape of those filenames says you have been re-running and
retrying foundation suites rather than building the economy harness your
contract requires.

## 2. Suite health is not your row

The contract suite red you have been running into is a real defect, it is
already diagnosed, and it belongs to `fix06_4` on `codex/cross-remediation`, not
to you. Its cause is a missing `surface_add_exact_hover_hit` method on the
`SurfaceHarness` test double at `scripts/tests/foundation/check_core_content.gd:139`,
called from `scripts/games/blackjack.gd:2939`. Your own
`.tmp/balance06_1/foundation_contracts_1/foundation_contracts.stderr.txt` is the
evidence that identified it — that is a genuine contribution, and you should say
so in your handoff.

Do not attempt to fix it. Do not retry the suite again hoping for a pass. Stop
all suite reruns now.

## 3. What to finalize

Your contract asks for two deliverables: a committed, runnable, opt-in economy
harness, and a report under `docs/plans/`. Land whatever fraction of those
genuinely exists, and be exact about the rest.

- Move any real harness code out of `.tmp/` into the location the other test
  harnesses live in, and commit it. If what you have is a prototype, commit it
  as a prototype and label it as such — an honest partial harness is worth far
  more to the incoming PM than a clean branch with nothing on it.
- Commit the measurement artifacts you produced as evidence, in a documented
  evidence location, not `.tmp/`. If an artifact is meaningless without the run
  that produced it, say what command produced it.
- Write the report under `docs/plans/` even if it is mostly empty. Structure it
  as your contract specifies — source and constraint model, harness description,
  per-playstyle distributions, findings, proposals — and mark every section you
  did not reach as NOT STARTED. Do not summarize, estimate, extrapolate or
  reason your way to numbers you did not measure. A section marked NOT STARTED
  is correct; a fabricated distribution is a P0.
- If you produced any real economy measurement — even one playstyle, even one
  seed — record it with its exact command, seed and build so it can be
  reproduced and extended.

## 4. Do not tune anything

Your contract forbids changing product values, tuning files or content data, and
that still holds. If you found a genuine economic defect — money created from
nothing, a conservation violation, a value contradicting its documented band —
write it up as a finding with reproduction steps. Do not patch it.

## 5. Hand off

Produce a written handoff containing:

1. exact base and head commits, and `git status` proving only intended files;
2. the commit list with a one-sentence purpose each;
3. a precise map of your contract's requirements to DONE, PARTIAL or NOT
   STARTED, with no optimistic rounding;
4. the exact commands, seeds and builds behind every number you did commit;
5. what you learned that the next agent should not have to rediscover —
   including the contract-suite stderr finding and anything you learned about
   run durations, harness structure or measurement cost;
6. every artifact you are leaving behind and where it now lives;
7. an honest account of the thirteen hours: what consumed them, and what you
   would do differently. This is not a reprimand, it is the most useful thing
   you can give the incoming PM about how long this work actually takes.

Then stop. Do not merge to any integration branch, do not edit
`docs/todo/README_0_6_board.md`, do not start another row, and do not delete your
worktree or branch. Leave everything intact and reviewable.
