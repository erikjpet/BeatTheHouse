Status: PARKED - do not claim until fixes and balance tuning are complete
Board row: `cleanup06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** -
- **Completion commits:** -
- **Exact input head:** -
- **Removed/archived/reconciled inventory:** -
- **Protected owner paths verified:** -
- **Verification:** -
- **Deviations:** -

# Agent Prompt - 0.6 cleanup06_1: Post-Playtest Cleanup and Reconciliation

Copy everything below this line into the agent only after the board coordinator
has changed this row from `PARKED` to `TODO`.

---

You are working in `D:\Projects\Beat-The-House`. This row removes only proven
leftovers from the complete post-playtest source, then reconciles current
documentation with what will ship. It is not a refactor, redesign, content
pass, voice pass, balance pass or release task.

Read in full:

- `docs/plans/0.6_post_playtest_program.md`;
- `docs/plans/dead_code_audit_report.md` as historical methodology, not current
  deletion authority;
- the roadmap, active board and its companion decision/work logs;
- the remaining-work program and all program closure reports;
- `triage06_1`, every post-playtest `fix06_*`, and `balance06_2` execution
  records;
- `.gitignore`, current tracked/untracked status and every applicable
  `AGENTS.md`.

## Claim gate

Follow the active board protocol. Do not self-unpark. Claim only if the row is
`TODO`, `balance06_2` is DONE, every `BLOCK_0.6` fix is DONE, and every other
playtest finding is explicitly closed or owner-deferred. Record the exact clean
input commit. If product work is still landing, stop; cleanup against a moving
tree produces false dead-code claims.

The primary integrator alone edits/splits the active board, archives task
prompts and merges branches. Coordinate board/log reconciliation through that
integrator rather than becoming a concurrent board writer.

## Absolute owner-property rule

`.tmp/`, `.tools/`, ignored paths and the owner's untracked directories are
deliberately kept in this project. Do not delete, move, rename, inspect beyond
what validation requires, stage, commit or repurpose them. This rule supersedes
historical cleanup advice that describes generated local directories as safe
to purge.

Before any deletion, record the exact tracked status and untracked path names
without reading unrelated owner contents. At completion, prove those paths and
the original worktree's tracked state are unchanged. Never run `git clean`, a
recursive wildcard deletion, or a command whose resolved target is a workspace
root or owner directory.

## 1. Produce a current inventory before editing

Create `docs/plans/0.6_post_playtest_cleanup_report.md` and classify candidates:

| Class | Required proof |
| --- | --- |
| Superseded code/system leftover | Replacement and all live callers identified; no scene, preload, class, reflection, dynamic path, test/tool or data consumer remains. |
| Unreferenced asset | No scene/script/data/manifest/generator/runtime path consumes it; import and generated-source policy understood. |
| Stale fixture/tool | Owning behavior no longer exists or a live canonical replacement covers it; no wrapper, suite, CI, prompt or reproducibility record calls it. |
| Orphaned documentation | Current operational claim is false or unowned; historical value and board/archive policy assessed. |
| Review artifact | Tracked artifact is redundant and explicitly safe to retire; ignored/untracked artifacts are protected owner property. |
| Suspect/live | Evidence is incomplete, loading is dynamic, or the item is historical/project memory. Keep it and explain. |

Trace both filenames and symbols across scripts, scenes, resources, data,
manifests, generators, project/export configuration, test wrappers and docs.
Godot resource paths and content `module_path` values are dynamic references;
zero static code hits do not prove deadness. For data keys, follow the runtime
state seeding and consumer path, including renamed keys. For tools, find direct
commands in plans and archived execution evidence, not only wrappers.

The historical dead-code report is a lead list only. Re-prove every candidate
on the exact input head; never execute an old deletion recommendation because
it was once true.

## 2. Remove in narrow, reversible classes

Use one logical commit for each accepted class, such as superseded code, assets,
fixtures/tools, or documentation reconciliation. Before each deletion:

1. list the exact tracked paths;
2. record inbound-reference searches and the replacement owner;
3. identify the focused gate and a negative check that would expose accidental
   removal of a live path;
4. inspect generated/import/manifests atomically so regeneration cannot restore
   a ghost or leave a broken reference;
5. confirm no active or parked prompt still owns or requires the path.

Delete implementation and its tracked companions only when the proof is
complete. Do not delete tests merely because they are large, merge live systems
as `cleanup`, refactor monoliths, rename APIs, redesign data, change rules,
retune values or remove compatibility/migration code still needed by supported
0.5 saves and mid-0.6 development saves.

When evidence is uncertain, keep the item under `Suspect/live` in the report.
Keeping a questionable file is a correct cleanup outcome; guessing is not.

## 3. Documentation reconciliation

After code/asset/fixture cleanup is final, compare the exact tree against:

- `docs/plans/0.6_living_world_roadmap.md` and owner decisions;
- `docs/todo/README_0_6_board.md` plus companion Discovery/Decision and Work
  logs;
- all current 0.6 plans and closure/audit reports;
- README and CHANGELOG statements that describe current behavior.

Reconcile current-state claims to what actually shipped. Preserve distinctions
among `implemented`, `verified`, `owner-accepted`, `deferred`, `superseded` and
`historical`. Do not rewrite an owner decision, erase a failed/rejected path,
convert historical evidence into current evidence, or mark 0.6 released.

Archive active task prompts only through the board protocol; never delete them.
The primary integrator performs board/log structural edits and prompt moves
after accepting this branch. Provide exact requested board/log changes in the
handoff so they can be applied in a quiet window.

Plans that remain useful as design history stay in place with a clear
historical/superseded header when needed. A documentation file is not orphaned
merely because its task is complete.

## 4. Validation after each class and on the final head

Start from a recorded green baseline appropriate to the candidate class. After
each commit, run its focused ownership gates. On the final head run:

- `tools/validate_project.ps1`;
- exhaustive script/resource load and content/contract suites;
- every supported Foundation system and UI suite;
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`;
- `tools/foundation_visual_qa.ps1` when any tracked asset, manifest, scene or
  presentation fixture changed;
- save/migration, native/Web parity and performance/liveness gates affected by
  removed paths;
- reference scans proving each deleted path/symbol is gone and no manifest,
  generator, wrapper or active doc still calls it.

Never weaken an assertion, budget, liveness floor, deterministic check or test
to justify removal. Suite timeout is max(300 seconds, baseline x 1.5).

## 5. Required report and handoff

For every candidate, the cleanup report records classification, exact evidence,
decision, commit (if removed), focused gate and result. Include totals for
tracked files/lines/bytes removed by class; do not claim ignored owner disk
space as a project cleanup result.

Before review, stop editing and provide:

- exact base/head/status and logical commit purposes;
- requirement-to-file/check mapping;
- `git diff --check`, diff stat and deleted-path audit;
- full diff review for accidental feature, rules, tuning, voice, version or
  release changes;
- complete validation evidence;
- explicit proof that `.tmp`, `.tools`, ignored and untracked owner paths were
  not deleted, moved, staged or modified;
- exact board/log/archive changes for the primary integrator;
- known risks and kept-suspect list.

After independent acceptance, the primary integrator completes board protocol
and may unpark `voice06_1` only when the owner also declares the remaining
strings final. Do not start voice or release work.
