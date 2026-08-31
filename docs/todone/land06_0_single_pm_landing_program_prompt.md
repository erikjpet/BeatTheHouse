Status: LAUNCHER — supersedes `depth06_0`, `game06_0`, `world06_0` and `cross06_0` as the single execution authority for 0.6

# Orchestration Prompt — Single Project Manager Landing Program for 0.6

Copy everything below this line into ONE primary Codex agent. That agent is the
sole project manager for the remainder of 0.6. It must employ sub-agents for all
implementation and review; it is not permitted to implement the program alone.

---

You are the single project manager for finishing 0.6 in
`D:\Projects\Beat-The-House` and landing every completed task onto `main`, one
at a time. Three previous program integrators (`depth06_0`, `cross06_0`, and the
never-launched `game06_0` / `world06_0`) are stood down. Their branches, their
work and their evidence are yours to recover, validate and land. Nothing they
produced may be silently discarded.

Your success condition is not activity. It is: every defined 0.6 task finished,
validated on the exact tree, and merged to `main`, with `main` green after each
landing.

## 1. Prime directive

**One row at a time, fully validated, merged to `main`, then the next.**

No batching. No landing two rows in one merge. No "land now, validate later". No
row is complete until it is on `main` and `main` passes its gates at that exact
head. If a landing breaks `main`, fixing it is your only task until it is fixed.

You are the single writer to `main`. No sub-agent merges to `main`, ever.

## 2. Authority and constraints

- You may create local branches and isolated Git worktrees, assign work to
  sub-agents, commit, merge, resolve conflicts, and merge accepted work into
  `main` locally.
- **Never push, never open a pull request, never tag, never publish, never
  modify remote state.** The owner performs all release activity.
- **No release activity of any kind**: no version bump, no packaging, no final
  balance tuning. `release06_1` stays parked and is not in your scope.
- The owner has authorized committing the 0.6 program documentation described in
  section 4.1. Every other untracked or ignored path in the primary working tree
  — `.tmp/`, `.tools/`, `review_artifacts/`, editor state, build output — is
  owner property. Record it at preflight, never stage it, and never use reset,
  clean or checkout commands that could discard it.
- Do not change RTP, EV, payout tables, odds, or any landed economic contract
  value. Depth work changes presentation and interaction only. A row that
  believes it needs a math change files a finding instead.
- Two rows are blocked on owner decisions (section 6). Never guess them.

## 3. What you are taking over — verify all of this yourself

State at handoff. Heads move; re-derive every one before relying on it.

| Branch | Head | Contains |
| --- | --- | --- |
| `main` | `2ad159fb` | `pusherv3_10` closed; `fix06_3` scratch alignment landed |
| `codex/cross-completion-integration` | `8a4d29be` | cross program ledger, `polish06_0` merged as `dba53fb5` |
| `codex/cross-remediation` | `3e5c0378` | `fix06_4` **finished and PM-verified**, see 3.1; 50 ahead of `main`, 5 behind |
| `codex/cross-meta` | `d7052142` | `meta06_1` implementation, 3 commits, 11 product files |
| `codex/cross-balance` | `1c0dec3b` | `balance06_1` — **finalized and PM-verified**, see 3.2 |
| `codex/cross-board` | `114271b0` | `board06_1` board split into dated companion logs |
| `codex/cross-polish` | `be14c1ce` | `polish06_0` accepted, no findings |
| `codex/cross-pusher-audit` | `554773c6` | `pusherv3_11` static audit start only |
| `codex/depth-program-integration` | `7dd770ad` | depth ledger and board deltas |
| `codex/depth-env-runtime-2` | `a5ae1d8f` | **`env06_6` static implementation independently accepted** |
| `codex/depth-env-runtime-5` | `fc0b8085` | active `env06_6` remediation, 18 commits ahead |
| `codex/depth-env-runtime-3`, `-4` | — | catalog and lifecycle remediation lines |

There are roughly forty registered worktrees, most of them stale from waves that
closed weeks ago. Inventory them; do not delete anything until section 11.

### 3.1 `fix06_4` is finished — collect, review, land

**No external worker is live.** The `fix06_4` agent has reported and stopped.
`codex/cross-remediation` is final at exact head `3e5c0378`
(`fix(test): keep surface harness aligned`), working tree clean,
`git diff --check` passing, with no merge, push, board edit or deletion
performed. Do not re-derive its work; collect it.

It reproduced the defect conclusively on the unfixed head, closed the
native-build detour, and grew the row beyond the four-line fix. Its final commit
touches exactly three files — `scripts/tests/foundation/check_core_content.gd`,
`tools/validate_project.ps1`, `tools/foundation_systems_shards_test.ps1` — and
the branch contains:

- the missing `surface_add_exact_hover_hit` on the double;
- three further reachable gaps it found — `draw_arc` absent, `surface_hovered_index`
  absent, and `surface_add_invisible_hit` not mirroring the canvas's
  `expand_touch_hit` parameter;
- a source-driven guard that fails when a game module calls a surface or draw
  method the harness lacks, relocated into static validation after the first
  placement cost the focused Blackjack gate 0.424s against its immutable
  17.790s budget. It reported that overrun as a finding rather than raising the
  cap, which is the behavior this program requires everywhere.

Two questions this row could have left open are already answered, with evidence.
Confirm each claim rather than reopening it:

- **Expectation integrity.** The `expand_touch_hit` correction changes what tests
  observe, and `exact` is asserted at
  `scripts/tests/foundation/check_lenders_release_saves.gd:4790` and
  `scripts/tests/foundation/check_slots_surfaces.gd:1480` and `:1505`. The agent
  reports **no expectations were edited** in either file and the complete
  Contract body executed with zero assertion failures, including Blackjack exact
  control rectangles and Slot pinball exact cell/rail geometry. So the
  hit-geometry coverage was real, not decorative, and there is no separate
  expectation-change finding.
- **Native fallback is closed.** The same file tree completed a native-backed
  Foundation Contract stage in 213.643s with every assertion green and zero
  stderr. The remaining red is wall-time, not fallback execution. Do not reopen
  this hypothesis without new evidence naming it.

What genuinely remains open on this row is the marginal Contract timing in
section 5, and the agent's own disclosure that **the final scoped commit received
self-review and validation but no independent agent review after the task was
narrowed.** Your loop's step 4 is therefore mandatory here, not a formality — it
touches shared test infrastructure every subsequent row depends on.

Two limits to carry forward rather than rediscover. The static parity guard
recognizes calls through the `surface` identifier and literal
`surface.call/has_method("surface_*")` forms; **arbitrary aliases and computed
method names are not statically discoverable**, so the guard narrows this defect
class without eliminating it — Families 1 and 2 should not assume total coverage.
And canvas methods no game module currently calls — `surface_action_is_blocked`,
`surface_animation_liveness_active`, `surface_draw_guidance_border`,
`surface_play_audio_cue`, `surface_presentation_time_msec`,
`surface_realtime_state_refresh_enabled`, `surface_realtime_ui_status`,
`surface_runtime_status`, `surface_start_audio_loop`, `surface_stop_audio_loop`,
`surface_transition_animation_active` — stay documented findings and are
`game06_1`'s inheritance, not this row's.

### 3.1.1 The native plugin is required for honest gate runs

The coin-pusher native library is **generated and git-ignored**. It is not in any
checkout you make. Contract, pusher and performance gates behave differently
without it, and a missing plugin is silently a different measurement, not an
error you will notice.

Before your first gate run, establish and record how you are supplying it:
either build it via `tools/build_native_solver.ps1` once, deliberately, and
record the hash, or copy the one the `fix06_4` agent measured against —
`addons/coin_pusher_native/bin/coin_pusher_native.windows.template_debug.x86_64.nothreads.dll`,
SHA-256 `3CC7567AF1BB4B77AB1C88BB3D1D4AB3CCB7A81B51AB619E1C5E24FE66FBCB79`.

Record which build every timing figure was taken against. A previous agent burned
hours on a native rebuild chasing a defect that was never native. Build it once,
on purpose, and never as a diagnostic reflex.

Never commit the DLL, the `.os` objects, `.sconsign.dblite`, `.tools/native_solver/`
or `addons/coin_pusher_native/`. They are ignored build products and remain so.

### 3.2 `balance06_1` is finished and verified — do not redo it

`codex/cross-balance` is finalized at exact head `1c0dec3b`, base `3d4a41da`,
two commits, working tree clean. It has been independently verified: scope is
`tools/` plus `docs/plans/` only, with zero files under `scripts/`, `data/`,
`native/` or `assets/`; the harness is genuinely opt-in and is referenced by
nothing in `scripts/` or the default runners; and the report marks every
unreached section NOT STARTED rather than estimating.

Its honest coverage is: a runnable opt-in prototype harness (1,238 lines plus a
parameterized launcher covering all eight playstyles) and a partial report with
a complete, hash-manifested evidence archive. Multi-seed distributions, complete
terminal-run evidence, the 600k-drop pusher EV measurement, ranked findings and
proposals are NOT STARTED. Only one seed per playstyle was measured, and all
eight runs were still active when censored at 208 actions, so the report asserts
no balance conclusion. That is correct behavior, not a deficiency to correct on
its behalf.

It needs exactly two things from you: an independent review by an agent that did
not author it, and its gates on the exact head. Its own contracts-suite evidence
is red for the `SurfaceHarness` defect and was correctly routed to `fix06_4`
rather than patched or rerun — **so its gates cannot complete until Wave 0 step 2
lands.** Sequence it accordingly.

One decision is yours: the branch commits 4.3 MB of evidence, 3.5 MB of which is
three raw measurement JSONs (`determinism_first.json` and
`cross_economy_audit_repeat.json` at 1.5 MB each, `smoke_retry2.json` at 0.5 MB)
holding `n=1` point samples the full audit will supersede. Git history is
permanent. Landing the report, handoff, README, `SHA256SUMS.txt` and the small
validation logs while gzipping or omitting the three large files is defensible —
the manifest already proves what was measured and the originals remain in
`.tmp/`. Decide deliberately and record the reason; do not reopen the row for it.

The remaining scope of `balance06_1` — the full multi-seed audit — is not
abandoned. Schedule it as a follow-on row after Families 1 and 2 land, when the
economy it is meant to measure actually exists.

## 4. Preflight

1. Report absolute repository path, current branch, exact `main` HEAD,
   upstream state, every tracked modification, every untracked path, every
   registered worktree, and every `codex/*` branch with its head and age.
2. Record the practical runtime of every validation and test command you will
   depend on. You will run them dozens of times; knowing their real cost is the
   difference between a plan and a wish.
3. Create `codex/land06-integration` from the exact current `main`. Stage every
   landing there first, then merge to `main`.
4. Establish a landing ledger — branch, worktree, owner, base, dependencies,
   status, reviewer, findings, evidence, accepted head, merge commit, post-land
   `main` gate result, cleanup — and keep it current. It is the only place the
   program's state lives.

### 4.1 First commit: the program documentation

The 0.6 program contracts exist only as untracked files in the primary working
tree — roughly 36 files under `docs/todo/` and `docs/plans/`, including every
`game06_*` and `world06_*` contract, the two family launchers, the cross-cutting
launcher, `docs/plans/0.6_remaining_work_program.md`,
`docs/todo/README_0_6_remaining_program.md`, and the modified board. Two
previous integrators correctly refused to stage them as protected owner state,
which is why Families 1 and 2 could never launch.

The owner has authorized committing exactly those files. Commit them first, as
`land06_0: commit the 0.6 remaining work program contracts`, with nothing else in
the commit. Verify afterwards that every prompt referenced by any launcher or
board row now exists in git. Do not stage `.tmp`, `.tools`, `review_artifacts`,
build output or editor state alongside them.

## 5. Known truths you do not need to rediscover

- **The contract-suite red.** `foundation_contracts` fails inside
  `_check_blackjack_surface_contract` because `SurfaceHarness`
  (`scripts/tests/foundation/check_core_content.gd:139`) lacks
  `surface_add_exact_hover_hit`, which `scripts/games/blackjack.gd:2939` calls and
  `scripts/ui/game_surface_canvas.gd:699` defines. It arrived with commit
  `43767b42`. The "native fallback" hypothesis recorded in the cross ledger is
  unsupported. This blocks every suite run until landed, so it lands first.
- **The test double drifts from the canvas.** The gap above is a class of defect,
  not an instance. Families 1 and 2 add pointer verbs and actors to every
  surface, which will produce more of them. A guard that fails when a game module
  calls a surface method the double lacks is worth more than any single fix.
- **`env06_6` static implementation is already independently accepted** at
  `a5ae1d8f`. Formal acceptance was withheld pending serialized full, audit,
  determinism, native/Web parity, performance and 21-image visual gates plus
  independent visual review. Finish those gates; do not rebuild the row.
- **`polish06_0` is finished and accepted** with no findings. Land it, do not
  redo it. Its outputs are PARKED and stay parked.
- **The Contract suite's time budget is inside the machine's noise band.** The
  budget is a recorded baseline of 153.594s times a 1.5 multiplier = 230.391s,
  applied to the `foundation_contracts` stage. A byte-identical tree produced
  213.643s on one run and 231.531s on another — 1.39x and 1.507x, straddling the
  cap — on a host running parallel agents and native compiles. Treat a marginal
  timing red as a measurement question, not a code regression: run the stage
  repeatedly on an idle host and report **every** result, never only the passing
  one. If the median sits near the cap, the baseline is stale — 0.6 has added 55
  scenarios plus the crew systems, craps, poker and the pusher, all with contract
  checks. Re-baselining with a recorded date, host and method is a legitimate,
  owner-visible decision. Silently raising a cap, or rerunning until green, is
  not, and either one forfeits the guard permanently.
- **Two open defects are inherited, not yours to absorb silently:** the marginal
  Contract timing above, and a stale delivery full-state UI golden exposed by the
  under-budget run. Route each as its own row with its evidence.
- **The idle-liveness regression pattern has recurred four times** in this
  project. An idle draw cost of 0.000 is a failure, not a pass, and the
  counter-gate in `scripts/ui/performance_liveness_guard.gd` is mandatory
  wherever a surface is touched.

## 6. Owner decisions outstanding — never guess

- **`fix06_3` Phase 5:** how Crossword Corner reconciles its printed art with its
  mechanics. Everything else in that row is landed. Hold Phase 5.
- **Anything a row discovers that changes locked design.** Design objections
  become owner decisions recorded in the roadmap. An agent never redirects locked
  design on its own reading. Surface it and continue with the rest of the row.

## 7. Landing order

Follow this order. Within a wave, rows may proceed in parallel on their own
branches, but they still land to `main` strictly one at a time.

**Wave 0 — make the tree workable**
1. The documentation commit (section 4.1).
2. `fix06_4` — the harness parity fix, final at `3e5c0378` on
   `codex/cross-remediation`. Land the three-file payload per section 3.1 and the
   entangled-branch rule in step 6 of the landing loop; do not merge the branch.
   Nothing downstream can be validated until suites run clean, `balance06_1`
   included.
3. `board06_1` — the board split, from `codex/cross-board`.

**Wave 1 — work already done, sitting on branches**
4. `polish06_0` (accepted at `be14c1ce`).
5. `meta06_1` (implementation at `d7052142`; needs independent review and gates).
6. `balance06_1` (finalized at `1c0dec3b`; needs independent review and gates
   only — see 3.2, and note its gates require step 2 to have landed).
7. `pusherv3_11` (the V3 closure audit; the audit still has to be genuinely run).

**Wave 2 — the depth program**
8. `env06_6` — finish the withheld gates, integrate the remediation branches.
9. `env06_7`, `craps06_3`, `crew06_10` — parallel implementation, sequential
   landing.
10. `depth06_1` — independent gate, owned by an agent that implemented none of it.

**Wave 3 — Family 1, game depth parity** (`game06_1` first; it depends on
`craps06_3`), then `game06_2` through `game06_7`, then the `game06_8` gate.

**Wave 4 — Family 2, crew and world depth** (`world06_1` first; it depends on
`env06_6`), then `world06_2` through `world06_6`, then the `world06_7` gate.
Waves 3 and 4 may overlap — they own different files — except `world06_5`, which
needs `game06_1`'s actor vocabulary and builds its sweep half first otherwise.

**Wave 5 — cross-cutting completion**
`audio06_1`, then `integ06_1` and `perf06_1` in parallel, then `teach06_2`.

**Wave 6 — close out**
`playtest06_2` to re-scope the playtest gate, then `playtest06_1` itself, which
ends the board with the owner handoff. `voice06_1` and `release06_1` stay parked.

Each row's binding contract is its own prompt in `docs/todo/`. Read it in full
before assigning it. Do not weaken a contract to fit available time.

## 8. The landing loop — run this for every row

1. **Claim** the row on the board and in the ledger.
2. **Assign** it to a sub-agent in its own worktree, based on the exact current
   `main` (or the accepted head of its dependency). State its file ownership,
   forbidden shared files, required tests, and required commits.
3. **Self-review**: the implementer stops editing and produces a handoff with
   exact base and head, commit list with purposes, a checklist mapping every
   contract requirement to file, symbol, test and capture, `git diff --check`,
   a full diff review for debug code, stubs, dead paths, generated files,
   hardcoded shortcuts, privacy leaks, non-deterministic time or randomness,
   duplicated consequences and save hazards, plus test, determinism, parity,
   performance, visual and accessibility evidence with exact commands and
   results. "No known risks" must be stated, not omitted.
4. **Independent review** by a sub-agent that did not author the branch, which
   checks the diff, correctness, state ownership, migrations, idempotency,
   cleanup, determinism, platform behavior, tests for false positives and
   weakened assertions, and actual player-facing behavior rather than state
   flags. Verdict is exactly one of `ACCEPT <exact-head>` or
   `REJECT <exact-head>` with actionable findings. Findings are P0 (data loss,
   security, hidden-state leak, unshippable), P1 (incorrect or missing required
   behavior), P2 (material quality gap) or P3 (polish). P0/P1/P2 require a fix or
   a written owner-approved exception. You cannot waive them. Acceptance is void
   once the head changes.
5. **Gates on the exact accepted head**: project validation, the relevant
   foundation suites, 10-seed determinism, native/Web parity, performance with
   the mandatory idle-liveness counter-gate, accessibility, save and migration,
   and visual QA — plus whatever the row's own contract adds.
6. **Land**: merge to `main` with `git merge --no-ff`, preserving logical
   commits. Never squash a clean row branch into one commit.

   **Entangled branches are the exception.** Several inherited branches carry
   another row's commits, a program ledger, reverted merges and revert pairs, and
   several are *behind* `main`. Merging one of those would drag unrelated history
   onto `main` and could conflict with or revert newer work. For any such branch:
   verify the merge base and what `main` has gained since; rebase the row onto
   current `main`, or extract the row's net change and apply it as its own
   coherent commit set; and prove equivalence by diffing the result against the
   accepted head for the row's owned files only. Record in the ledger which
   method you used, the accepted head it derives from, and the exact files. The
   original branch stays intact and undeleted as the provenance record.

   `codex/cross-remediation` is the worked example: merge base `a0d2b6ff`, 50
   commits ahead, 5 commits behind `main`, carrying `polish06_0` and the cross
   ledger. Its actual `fix06_4` payload against current `main` is three files —
   `scripts/tests/foundation/check_core_content.gd`, `tools/validate_project.ps1`,
   `tools/foundation_systems_shards_test.ps1`. Land that, not the branch.
7. **Post-land verification**: re-run the row's gates plus a smoke pass on `main`
   at the new head. A red here reopens the row immediately; do not proceed.
8. **Record**: accepted head, merge commit, gate results, and cleanup status in
   the ledger, and update the board row to DONE with its evidence.
9. **Next row.** Only now.

## 9. Sub-agent discipline

- You employ sub-agents for all implementation, all review and all audit work.
  You coordinate, validate, land and report. If you find yourself writing product
  code, you have stopped doing your job.
- One accountable owner per branch. Never let two agents change branches in the
  same worktree. Never let two agents edit the same file.
- Keep every slot busy: while a row is in review, its implementer starts the next
  row's audit or reviews someone else's branch.
- Reviewers must sample the actual build, not read reports.
- If an agent stalls, reassign its bounded remaining work without discarding its
  commits. The previous program lost roughly thirteen agent-hours to a worker
  that retried test suites instead of building its harness, and hours more to one
  chasing an unsupported hypothesis. Check that a worker's activity matches its
  contract, not merely that it is busy.
- If a test is flaky, diagnose and fix the determinism. Never rerun until lucky,
  never loosen a threshold, never refresh a golden to make a red disappear.

## 10. Standing engineering rules, inherited by every row

- Determinism seeded from run RNG; everything ticks at action boundaries, never
  wall-clock time.
- Every consequence fires exactly once across save, reload, travel, revisit,
  abort and expiry.
- Hidden state is absolute: no Turn, traitor, grievance, rigged-draw or
  unrevealed-ticket information may leak through scene data, serialized keys,
  captures, audio, logs or fixtures. A leak is an automatic P0.
- A crew-ignoring run must remain a true no-op.
- Nothing new runs per frame that can run at a boundary; no per-frame deep copies.
- A sequence replaces a choice list. Staging a room and then presenting the same
  four choices has converted nothing.
- Rules and math are preserved; depth changes presentation and interaction.
- Voice obeys the Voice Bible register split and brevity rule.

## 11. Cleanup

Only after a branch's work is landed on `main` and verified there: remove its
worktree with `git worktree remove` against the verified registered path. Never
recursively delete a computed path. Keep branches unless the owner asks
otherwise.

The forty-odd stale worktrees from closed waves are a separate, final task. At
the end of the program, list them with their branch, head, and whether that head
is reachable from `main`. Remove only those that are clean and fully reachable.
Report the rest for the owner to decide. Never remove a worktree holding
unreachable commits.

## 12. Reporting

Report at every landing, every rejected review, every reopened row, and every
blocker. Each report leads with: rows landed on `main` out of the total, the row
in flight, the next dependency, unresolved findings, and outstanding owner
decisions.

Never describe a row as complete before it is merged to `main` and `main` is
green at that head. Never report a percentage based on claims; report it based on
landings.

A genuine blocker includes three attempted safe approaches, exact evidence, the
affected rows, the preserved branch heads, and the smallest owner decision that
would unblock it. Hard work, merge conflicts, long test runs and review findings
are not blockers.

## 13. Definition of done

Every row in the 0.6 board's active tables is DONE and landed on `main`, except:
`fix06_3` Phase 5 and anything else genuinely awaiting an owner decision;
`voice06_1` and `release06_1`, which remain parked; and `playtest06_1`, which is
the terminus and hands off to the owner's playtest.

Your final response leads with the outcome and includes: the starting and final
`main` commits, every row with its merge commit and reviewer, the complete gate
table, every audit's findings and where each was routed, outstanding owner
decisions, retained worktrees and branches with their reachability, and explicit
confirmation that no remote state was modified, no release activity was
performed, and no owner file was staged or discarded.
