Status: TODO — single worker agent, drives the remaining 0.6 todo list to the owner playtest

# Agent Prompt — closeout06_0: Finish the 0.6 Todo List

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are finishing 0.6 in `D:\Projects\Beat-The-House`. `main` and `origin/main`
are in sync at `1f3f81c6` and the source tree is integrated and green.

**Read `docs/plans/0.6_todo_state_audit_2026-08-31.md` first, including its
2026-09-02 addendum.** It is the authoritative statement of what is landed,
what is accepted, and what remains. This prompt tells you how to work; that
document tells you what is true.

## The single most important fact

**Most remaining rows are closeout work, not rebuild work.** Seventeen rows have
their implementation on `main` already. They are not DONE because their prompts
lack independent acceptance, visual and reachability evidence, or an explicit
closeout record — not because code is missing.

Start every one of those from the landed implementation on `main`. **Never
rebuild a row from an old branch.** Doing so duplicates work and reintroduces
risk that was already resolved.

## Order of work

Follow the audit's recommended execution order:

1. **Close the depth spine:** `env06_6`, `env06_7`, `craps06_3`, `crew06_10`,
   then run the `depth06_1` gate.
2. **Close the game rows:** `game06_1` through `game06_7` (the Crossword owner
   decision is resolved by `996a98b6`; Counter Games closed by `31103f7f`), then
   run the `game06_8` gate.
3. **Close the world rows:** `world06_1` through `world06_6`, then run the
   `world06_7` gate — hidden-information safety is its blocking concern.
4. **Perform the genuinely unbuilt rows:** the `balance06_1` follow-on,
   `audio06_1`, `integ06_1`, `perf06_1`, `teach06_2`. These are prestage-only
   today and need real work, not reconciliation.
5. **Run `playtest06_2`, then `playtest06_1`**, and hand the owner an exact
   build. That ends your program.

Coin Pusher is finished — `pusherv3_10`, `pusherv3_11`, `fix06_8`, `fix06_9` and
`fix06_13` are DONE and archived. Do not reopen them.

## The acceptance bar for a closeout row

A landed row moves to `docs/todone/` when all of these hold on the exact current
`main`:

- its prompt's requirements each map to landed code, data or tests, recorded;
- its focused suite is green on the exact head, with the command and result;
- the row's own evidence requirements are met — visual, reachability, platform
  or determinism as its prompt names them;
- exactly-once holds for every consequence it touches;
- no hidden-state leak, and nothing trusts a caller-supplied capability;
- no change to money, RNG, RTP, payouts, odds, schema or migration.

That is the whole bar. Missing polish, absent captures for things the prompt did
not require, imperfect naming and untested edge cases are **follow-on rows, not
blockers**. Record them and close the row.

If a closeout reveals a genuine defect, fix it inline within that row when it
blocks acceptance; otherwise put it on a deferred list.

## How to not stall — this program has stalled three times

- **Park, never block.** If a row needs an owner decision, record the exact
  question, take the stated default, and move to the next row. Never halt.
- **You decide.** Every question you would escalate gets a default you act on and
  report. Nothing here is irreversible; you may push to `origin`, but you perform
  no release activity, so nothing justifies stopping.
- **Defect budget: three new `fix06_*` rows for the whole program.** Past that,
  defects go on the deferred list for the post-playtest passes.
- **Two rejections on a row escalate to the owner, never a third round.**
- **Cadence: close or complete at least one row every two hours.** If you cannot,
  your next report's first line names the blocker in one sentence.
- **Never idle.** A parked row means take the next one immediately.

## Hard limits

- Never weaken a test, refresh a golden without proving the content legitimately
  changed, or raise a budget. A budget crossing 16.67 ms needs owner sign-off.
- Never perform release activity: no version bump, tag-as-release, packaging or
  publish. `release06_1` stays parked.
- Delete nothing — no branch, worktree or stash. No `gc`, `reset --hard`,
  `clean`.
- Never stage owner property: `.tmp/`, `.tools/`, `review_artifacts/`, build
  output.
- Commit work to a branch at least every 30 minutes, labeled if unreviewed.
- Keep `main` green after every merge, and keep `origin/main` in sync — it is
  current now and must stay that way.

## Standards every row inherits

- Idle draw cost of 0.000 is a failure; the liveness counter-gate in
  `scripts/ui/performance_liveness_guard.gd` is mandatory wherever a surface is
  touched. Four recorded regressions.
- No per-frame deep copies. The slot bonus watchdog cost 32.6 ms/frame.
- Action boundaries, never wall-clock. Everything seeded from run RNG.
- Hidden state is absolute — Turn, traitor, grievance, rigged draw, unrevealed
  ticket. A leak is an automatic P0.
- The crew-ignoring run stays a true no-op.
- Depth changes presentation and interaction; rules and math are preserved.

## Parked — do not start

`triage06_1`, `balance06_2`, `voice06_1`, `cleanup06_1`, `release06_1`, and the
seven `release06_1_*_template.md` companions. Their inputs come from the owner's
playtest. Tutorial TUT-N17 needs five cold-player human sessions and cannot be
done by an agent — record it as owner-dependent.

## Reporting

Report at every row closure. Lead with rows closed of the remaining set, the row
in flight, anything parked with its exact question, and `main`/`origin` sync
state. Never report a row DONE before its evidence is recorded and its prompt is
archived to `docs/todone/`.

Stop only when `playtest06_1` has handed off the owner build. If you find
yourself about to stop for any other reason, take the next row instead.
