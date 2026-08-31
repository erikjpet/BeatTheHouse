Status: LAUNCHER
Board section: `Family 2 — Crew and world surface depth` in `docs/todo/README_0_6_board.md`

# Orchestration Prompt — Crew and World Surface Depth Program (Family 2)

Copy everything below this line into one primary Codex agent. That agent is the
program integrator and must employ sub-agents; it is not permitted to implement
the whole program alone.

---

You are the primary integrator for the crew and world surface depth program in
`D:\Projects\Beat-The-House`. Your job is to use as many sub-agents as the
current runtime safely permits, complete every task below, independently review
each implementation branch, preserve logical individual commits, merge accepted
work through an integration branch, run an exact-tree release audit, and merge
the finished program back into the branch from which you started.

Required task contracts, in dependency order:

1. `docs/todo/world06_1_crew_sequence_adapter_prompt.md`
2. `docs/todo/world06_2_streets_sequences_prompt.md`
3. `docs/todo/world06_3_numbers_depth_prompt.md`
4. `docs/todo/world06_4_backroom_jobs_recruitment_prompt.md`
5. `docs/todo/world06_5_plays_and_sweep_encounters_prompt.md`
6. `docs/todo/world06_6_heist_and_turn_staging_prompt.md`
7. `docs/todo/world06_7_crew_world_depth_release_gate_prompt.md`

The active board is `docs/todo/README_0_6_board.md`. The seven task prompts are
binding acceptance contracts. Read them completely before planning, then read
all repository `AGENTS.md` files that govern touched paths. Do not weaken or
reinterpret a task to make it fit the available time or agent count. Continue
until the full program is finished, or report a genuine blocker with exact
evidence.

## Why this program exists

The Crew path is 0.6's flagship pillar and it is still a text menu. Streets
deliveries, the Numbers book and desk, the job board, recruitment encounters,
coordinated plays, Police Sweep encounters, the heist phases and the Turn
confrontation all resolve through `EventModule` choice actions — see
`crew_heist_table_choices()`, `crew_job_accept`, `crew_rook_ride`,
`crew_practice_rig` and their siblings in `scripts/core/event_module.gd`.
`env06_6` builds the spatial, actor, objective and aftermath machinery these
systems need, and nothing schedules them onto it. The environments around the
crew are becoming rooms while the crew itself stays a list of choices.

## Authority and non-negotiable outcome

- You are explicitly authorized to create local branches and isolated Git
  worktrees, assign implementation and review work to sub-agents, commit the
  requested changes, merge accepted branches, resolve in-scope conflicts, and
  merge the fully accepted integration branch back into the starting branch.
- Do not push, open a pull request, publish a build, delete user work, or modify
  remote state unless the user separately requests it.
- Existing dirty/untracked files belong to the user. Record them at preflight,
  never copy them into worktrees, never stage them, and never use reset/clean/
  checkout commands that could discard them.
- Every crew and world interaction listed in the task contracts must finish as a
  played sequence. Partial conversion is not a valid stopping point.
- **Hidden-state discipline is absolute.** The Turn's traitor resolution, its
  clue channels and the heist's hidden seams must never be inferable from scene
  data, serialized keys, actor state, capture output or test fixtures. A
  hidden-information leak is an automatic P0 and blocks the program.

## 1. Hard dependency on env06_6

`world06_1` depends on `env06_6` being landed and reviewed. Do not start
implementation until it is DONE on the board and you have read its accepted head
and its contract document. While waiting, keep every slot busy with the
read-only audits in section 3.

## 2. Preflight and immutable baseline

1. Capture and report: absolute repository path; starting branch and exact HEAD;
   upstream/ahead/behind; tracked modifications and untracked paths; existing
   worktrees and branches matching `codex/world-*`; available agent concurrency;
   supported validation/test commands and their practical runtimes.
2. If tracked user changes overlap any required file, do not hide or overwrite
   them. Create worktrees from the exact starting HEAD and leave the original
   working tree untouched until final integration; stop only if the overlap
   makes an honest final merge impossible.
3. Create `codex/world-depth-integration` from the exact starting HEAD in an
   isolated worktree. Record its path. All accepted work merges here first.
4. If the seven task contracts and this launcher are not present in the starting
   commit, copy only their exact current contents into the integration worktree
   and commit them first as `world06_0: add crew world depth program contracts`.
5. The primary integrator is the only agent allowed to edit the active board,
   archive task prompts, merge branches, or resolve cross-branch conflicts.
6. Establish a live program ledger containing branch, worktree, owner, file
   ownership, base commit, dependencies, status, reviewer, findings, test
   evidence, accepted head, merge commit, and cleanup status.

## 3. Spawn the initial parallel audit team

Give each agent a bounded, read-only audit with a required written handoff:

- **EventModule crew seam:** every crew and world action routed through
  `scripts/core/event_module.gd`, its choice producers, its hooks, and the exact
  boundary where a sequence could replace a choice list without breaking
  ordinary events.
- **env06_6 capability map:** what the landed runtime actually offers for
  `scene_ops`, `interaction_ops`, `actor_ops`, `objectives`, `transition_ops`,
  `reentry_policy`, `expiry`, `cleanup` and `aftermath`, and which crew needs it
  cannot yet express.
- **Crew model inventory:** `delivery_run_model.gd`, `numbers_model.gd`,
  `police_sweep_model.gd`, `crew_play_model.gd`, `crew_recruitment_model.gd`,
  `crew_state_model.gd`, `crew_heist_model.gd`, `crew_turn_model.gd` — public
  API, persisted state, action-boundary contracts, and every test asserting on
  them.
- **Hidden-state map:** every place Turn or heist hidden state is stored,
  derived or could be inferred, and the exact privacy contracts `crew06_9`
  landed. This audit's output is the checklist the release gate audits against.

Audit agents cite paths and symbols, identify shared files, propose commit
boundaries, and map every prompt requirement to implementation and tests. They
do not edit code.

## 4. Branch and worktree topology

Use isolated worktrees for every concurrent implementation. Never let two agents
change branches in the same worktree. Branch families:

- `codex/world-adapter` for `world06_1`;
- `codex/world-streets` for `world06_2`;
- `codex/world-numbers` for `world06_3`;
- `codex/world-backroom` for `world06_4`;
- `codex/world-plays-sweep` for `world06_5`;
- `codex/world-heist-turn` for `world06_6`;
- `codex/world-release-remediation` only for exact-tree findings that cannot
  cleanly return to their owning branch.

Create worktrees under a verified sibling directory such as
`D:\Projects\Beat-The-House-worktrees\`. Resolve every path before creation or
cleanup. Never recursively delete a computed path; use `git worktree remove`
after verifying the registered path and only after its branch is safely merged.

## 5. Dependency-aware execution waves

### Wave 1 — the adapter

Claim `world06_1`. Assign it to one runtime worker. Its branch must include at
least these logical commits: (1) the adapter contract and validation; (2) the
`EventModule` seam and routing; (3) crew-authored sequence support with
persistence and cleanup; (4) hidden-state isolation and its tests; (5) one proof
conversion end to end with evidence.

The proof conversion should be the smallest real crew interaction, not a
fixture. If the adapter cannot express it without special-casing, the adapter is
wrong.

Do not merge Wave 1 on implementer confidence. Apply the review protocol in
sections 7 and 8. Once accepted, merge with `--no-ff` into the integration
branch, run smoke and regression gates there, update the board, and record the
integration commit. Only that accepted commit may base consumer branches.

### Wave 2 — parallel conversion

From the accepted adapter commit, start `world06_2` through `world06_6`
concurrently, one owner per branch. Ownership is by model file and is exclusive,
per the task contracts. `world06_5` also needs the `game06_1` actor vocabulary
for crew presence at tables — if Family 1's runtime has not landed, it
implements the sweep half first and the plays half after, and the ledger records
that ordering.

`world06_6` bases on the accepted `world06_2` head because it consumes chase
verbs, and requires `crew06_10` for the poker tell clue channel. Record both.

If a worker needs a change to a `world06_1` or `env06_6` file, it does not edit
it. It files a request with exact evidence; you decide whether to reopen the
owning row or grant a narrow, reviewed exception recorded in the ledger.

### Wave 3 — integrate one at a time

Each branch requires independent review and all focused gates before it is
eligible. Merge accepted branches one at a time with `--no-ff`, preserving
logical commits. After each merge run its focused tests plus crew composition,
save and UI smoke on the integration branch. If a later merge breaks an earlier
one, assign the finding to the responsible branch or an explicit cross-system
remediation commit; never mask it in the merge resolution.

### Wave 4 — independent release gate

Claim `world06_7`. Spawn at least three reviewers who owned none of the relevant
implementation: one for correctness, state, determinism and economy; one for
player-facing interaction, accessibility and pacing; and one specifically for
hidden-information leakage across every new surface, capture and serialized key.
Run the entire `world06_7` prompt on the exact integration head. Any P0/P1 or
unmet prompt checkbox blocks closure, and any hidden-state leak is a P0.

## 6. Standing rules for every worker

- A sequence replaces a choice list; it does not wrap one. A "sequence" that
  stages a room and then presents the same four choices has not converted
  anything.
- Every consequence fires exactly once. Save, exit, revisit and expiry must not
  double-fire, and abandoned objectives must resume or fail per an authored
  policy, never silently vanish.
- Everything ticks at action boundaries, never on wall-clock time. Determinism
  is seeded from run RNG.
- Ordinary travel, ordinary events and ordinary environment functionality must
  survive at every node a sequence touches. A crew-ignoring run must be a true
  no-op — `crew_ignored_golden_probe.gd` exists because that broke once already.
- Bounded effects only: no sequence may invent money, trust, heat or items
  outside the landed economy contracts.
- Voice obeys the Voice Bible register split — house courtesy, street bluntness,
  brevity throughout.

## 7. Mandatory branch self-review protocol

Before requesting review, every implementer stops editing and produces a branch
handoff containing: exact base and head commits plus `git status` proving only
intended files; the commit list with one-sentence purposes; a prompt checklist
mapping every owned requirement to file, symbol, test and capture;
`git diff --check` and a diff-stat ownership audit; a full base-to-head diff
review for debug code, TODO stubs, dead paths, generated files, hardcoded test
shortcuts, privacy leaks, non-deterministic time or randomness, duplicated
consequences and save hazards; focused tests, regression suites, determinism,
parity, performance, visual and accessibility evidence with exact commands and
results; and known risks or assumptions, where "None" must be explicit.

A branch is not reviewable with dirty tracked changes, uncommitted required
work, missing evidence, skipped prompt rows or unrelated files.

## 8. Mandatory independent review protocol

Assign a reviewer who did not author the branch. The reviewer starts from the
recorded base, reads the binding prompt sections, and independently checks the
full diff and commit boundaries; correctness, error paths, state ownership,
migrations, idempotency, cleanup, deterministic RNG and action boundaries,
Web/native behavior, performance and accessibility; tests for false positives,
missing negative cases, overfitted fixtures and weakened assertions; actual
player-facing behavior and captures rather than state flags; hidden-information
discipline; and interactions with already accepted work.

Findings are `P0` (data loss, security, hidden-state leak, unshippable), `P1`
(incorrect or missing required behavior), `P2` (material quality gap) or `P3`
(non-blocking polish). P0/P1/P2 require a fix or a written owner-approved
exception; the integrator cannot waive them. The reviewer issues exactly one of
`ACCEPT <exact-head>` with coverage and rerun evidence, or `REJECT <exact-head>`
with actionable findings. Acceptance is invalid after the head changes.

## 9. Commit and merge discipline

- Preserve individual logical commits. Do not squash a task into one commit.
- Commit messages use the task id and outcome, for example
  `world06_3: stage the numbers book as a place with a bookmaker`.
- Before every merge verify a clean integration worktree, the expected branch
  head, recorded reviewer acceptance, diff/check results and no unrelated files.
- Merge with non-interactive `git merge --no-ff`. Resolve conflicts only in the
  integration worktree, inspect every conflicted hunk, rerun both sides' focused
  tests, and never use blanket "ours" or "theirs" for product or data files.
- After each merge record accepted head, merge commit and tests in the ledger.
  A failed post-merge gate reopens the responsible task.
- Do not stage `.tmp`, review artifacts, captures outside their documented
  evidence location, editor state, or pre-existing user files.

## 10. Final merge back to the starting branch

Only after `world06_7` passes and all seven rows are DONE or archived: verify the
integration worktree is clean and complete; run `git diff --check`, project
validation, the full supported foundation matrix, 10-seed determinism,
native/Web parity, performance, accessibility, save and migration, crew and
scenario composition, and visual QA on that exact head; produce the closure
report with the full hidden-state audit attached; return to the original working
tree and confirm its tracked state has not changed since preflight; merge
`codex/world-depth-integration` with `--no-ff` without squashing or
force-updating; run a final validation; and only then remove clean registered
worktrees whose accepted heads are reachable from the final branch.

## 11. Communication and terminal conditions

Send concise progress updates at wave boundaries, after reviews, after each
merge, and whenever a gate reopens work. Include counts: interactions converted,
branches accepted and merged, unresolved findings, next dependency. Never
describe a row as complete before its independent reviewer accepts the exact
head and post-merge gates pass. If an agent stalls, reassign its bounded
remaining work without discarding valid commits. If a test is flaky, diagnose and
fix determinism; do not rerun until lucky or loosen thresholds.

A genuine blocker must include three attempted safe approaches, exact evidence,
affected prompt rows, preserved branch heads, and the smallest user decision
needed. Hard work, merge conflicts, long tests and review findings are not
blockers.

Your final response must lead with the outcome and include starting and final
branch and commits, all created branches, reviewer verdicts, merge commits, the
per-system conversion summary, the hidden-state audit result, the complete gate
table, closure-report paths, any retained worktrees or branches, and explicit
confirmation that pre-existing user files were not staged or modified.
