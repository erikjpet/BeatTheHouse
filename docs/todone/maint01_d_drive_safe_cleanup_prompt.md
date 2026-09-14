Status: DONE — superseded and completed by the 2026-09-14 two-branch custody consolidation

# Agent Prompt — Maintenance 01: Safe D: Drive Cleanup (no work lost)

Copy everything below this line into the agent.

---

You are a maintenance agent on a Windows 10 machine. The `D:` drive (≈223 GB)
keeps running out of space. It holds the **Beat The House** Godot project, many
git worktrees created by other agents, and a few unrelated folders.

**Goal:** free as much space as possible by deleting **only information that is
provably redundant**. After you finish, every commit, every uncommitted change,
every piece of evidence a document points to, and every file that exists
nowhere else must still exist. If you cannot prove an item is redundant, **do
not delete it** — report it for the owner instead.

This prompt is self-contained. Read it fully before running anything.

## Hard safety rules

1. **Inventory and plan first, delete second.** Nothing is deleted until
   `D:\Projects\Beat-The-House-cleanup-archive\cleanup_manifest_<YYYY-MM-DD>.json`
   exists. The manifest lists every deletion candidate with:
   - full path;
   - size;
   - category (section 3);
   - the specific proof that it is redundant.
2. **One path at a time, never wildcards.** Delete exact manifest paths only. No
   `rm -rf *`, no glob deletes, no `git clean`, no `Remove-Item` on a parent
   folder to get at a child.
3. **Never touch:**
   - anything outside `D:\` (C: is out of scope);
   - `D:\$RECYCLE.BIN`, `D:\System Volume Information`, `D:\Recovery` (report
     sizes only; emptying the Recycle Bin is the owner's call);
   - `D:\OllamaModels`, `D:\Card-Chest`, and every non-Beat-The-House project in
     `D:\Projects`: `cs2-dash`, `pokemon-vendor-shop`, `great_lakes_road_trip`,
     `vendor_backend`, the loose `.py` / `.bat` / `.dll` files in the
     `D:\Projects` root. Report their sizes only;
   - the main checkout's `.tools\` folder (protected local toolchain);
   - any git **commit**. No `git reflog expire`, no `git gc --prune=now`, no
     `git filter-*`, no rewriting history;
   - `docs/`, `data/`, `scripts/`, `scenes/`, `assets/`, `tools/` in any checkout
     (tracked source), and `builds\windows` / `builds\web` in the main checkout
     (the current owner build named in `docs/plans/0.6_playtest_handoff.md`).
4. **No commits, no pushes, no merges, no stashes, no resets, no checkouts** in
   any repository. Deleting a local branch is allowed only under section 3 C.
5. **Other agents are working right now.** Before deleting anything under a
   worktree, confirm no process is using it:
   `Get-Process | Where-Object { $_.Path -like '<path>*' }` for `godot*`, `node`,
   `git`, `python`, `powershell`, `code`. Also check that no file in it was
   written in the last 72 hours (`LastWriteTime`). If either check hits, the
   worktree is **active**: skip it.
6. **Archive before removing anything that is not already in `main`.** See
   section 3 C. Archive location:
   `D:\Projects\Beat-The-House-cleanup-archive\`, which already exists from an
   earlier pass: `patches\`, `untracked\`, `archive/*` branches. Never delete
   the archive.
7. **Stop on surprise.** If a proof step returns something unexpected, record it
   and skip that item. Examples: a worktree has unique commits you didn't
   expect, a patch fails to verify, a path is referenced in a doc. Do not
   improvise a workaround.

## 1. Known state (verify — do not trust)

An earlier pass on 2026-09-12 already:

- removed 26 merged worktrees;
- deleted 33 merged/patch-equivalent local branches;
- created `archive/env06-review-519fe930`, `archive/env06-review-966bc69f`,
  `archive/env06-review-9c4120fe`, `archive/world-9eb-audit` branches to keep
  unmerged detached commits reachable;
- saved uncommitted diffs to `D:\Projects\Beat-The-House-cleanup-archive\patches\`
  (`Beat-The-House-env06_8`, `baseline-single-plane`, `perf-baseline-67ab`,
  `game-closeout-retention-only`) and untracked files to `...\untracked\`.

The pass left these behind:

- **Leftover unregistered folders**
  `D:\Projects\Beat-The-House-worktrees\main-closeout06-land` and
  `...\audio-final-closeout` (≈2.8 GB). Git already unregistered them after a
  "Filename too long" failure. Both were clean (no uncommitted changes) and
  their commits are in `main`.
- **Merged worktrees with leftover uncommitted/untracked files:** `feat06-1`,
  `playtest06-final-custody`, `baseline-single-plane`, `perf-baseline-67ab`,
  `D:\Projects\Beat-The-House-env06_8`, and
  `D:\Projects\Beat-The-House\.tmp\owner_build_candidate`.
- **Unmerged worktrees from 2026-09-03/04 closeout attempts:**
  `closeout06-final`, `depth-closeout`, `env06-review-*` ×3, `game-closeout`,
  `game-closeout-accel`, `game-closeout-ledger-perf`,
  `game-closeout-prefix-base`, `game-closeout-retention-only`,
  `integ-composition-soak`, `teach06-closeout`,
  `D:\Projects\Beat-The-House-world-9eb-audit`,
  `D:\Projects\Beat-The-House-world-closeout`.
- **Active — minimum keep set (you may find more with rule 5):**
  - main checkout `D:\Projects\Beat-The-House`;
  - `agent-playtest` (its `.tmp` evidence is referenced by
    `docs/plans/agent_playtest/`);
  - `backroom-poker-tweaks`, `game-prop-art`, `playtest-fixes`, `fix06-32`,
    `perf06-finish`.

Re-derive all of this with the commands in section 2 before acting.

## 2. Inventory (read-only)

Main repo: `D:\Projects\Beat-The-House`. Use `git -C` against it. Enable long
paths per command with `git -c core.longpaths=true …`; do not change global git
config.

1. `Get-PSDrive D` — record free space before.
2. Top-level sizes of every folder in `D:\` and `D:\Projects`. For large trees,
   use `robocopy <dir> NUL /L /S /NJH /NFL /NDL /BYTES` or
   `Get-ChildItem -Recurse -File | Measure-Object Length -Sum`. `du` is too slow
   on this drive; run size scans in parallel or in the background.
3. `git worktree list --porcelain`. For every worktree record:
   - branch or detached HEAD, and last commit date;
   - `git merge-base --is-ancestor <HEAD> main`;
   - unique patches `git cherry main <HEAD> | grep '^+'` count;
   - `git status --porcelain --untracked-files=all` counts (modified / untracked);
   - ignored content size split into `.godot\`, `.tmp\`, `builds\`,
     `node_modules\`, `__pycache__\`, other;
   - active? (rule 5).
4. Folders under `D:\Projects\Beat-The-House-worktrees\` and
   `D:\Projects\Beat-The-House-*` that are **not** registered worktrees.
5. `git branch --format` for all local branches with merged / patch-equivalent /
   unique status and whether a worktree has them checked out.
6. **Reference index:** collect every path string mentioned in tracked files of
   the main checkout's `docs/`, plus every `.md` under `docs/todo` and
   `docs/plans` (tracked or not). Any file or folder on disk that one of them
   points to (e.g. `.tmp/bug_investigation_b9bd8fcb/`,
   `D:\Projects\Beat-The-House-worktrees\agent-playtest\.tmp\agent_playtest\...`)
   is **referenced evidence** and must be kept.
7. Main checkout local artifacts: run the repo's own read-only report,
   `powershell -File D:\Projects\Beat-The-House\tools\manage_local_artifacts.ps1 -Report`.
   Its retention policy says development artifacts stay local and cleanup needs
   a verified export. **Do not run its `-Clean` mode.**

## 3. Deletion categories and required proof

Anything that fits no category below is **report-only**.

### A. Removed-worktree leftovers

Folders that are no longer registered worktrees.

- **Proof:** absent from `git worktree list`; no `.git` file inside pointing to a
  live `.git/worktrees/<name>` entry; the folder name matches a worktree whose
  branch/HEAD is in `main` (ancestor or zero unique patches, from
  `git log --all` / reflog); no referenced evidence inside (index from 2.6);
  not active.
- **Delete with:** `cmd /c rmdir /s /q "\\?\<full path>"` (handles long paths).

### B. Merged, clean, inactive worktrees

- **Proof:** HEAD is an ancestor of `main`, or has zero unique patches;
  `git status --porcelain --untracked-files=all` is empty; not active; no
  referenced evidence inside.
- **Delete with:** `git -c core.longpaths=true worktree remove <path>` (no
  `--force`). If files remain after "Filename too long", finish with category
  A's command, then `git worktree prune`.
- Then delete its branch with `git branch -d <branch>`. Use `-D` only with
  zero-unique-patch proof, and never for a branch in the keep set.

### C. Worktrees whose only non-redundant content can be archived first

Two sub-cases:

- **C1:** merged HEAD, but with uncommitted changes or untracked non-ignored
  files.
- **C2:** unmerged HEAD with unique commits, clean status.

Required before removal:

1. **Commits:** a named ref must point at HEAD (its branch, or create
   `archive/<worktree-name>`). Verify: `git rev-parse <ref>` equals HEAD.
2. **Uncommitted tracked changes:**
   - `git -C <wt> diff HEAD --binary > archive\patches\<name>.patch`, plus
     `<name>.base.txt` holding the HEAD hash.
   - **Verify without touching any index or worktree:** set
     `$env:GIT_INDEX_FILE` to a temp file, run `git read-tree <base>`, run
     `git apply --cached --check <patch>`, then remove the temp index file.
     The check must pass.
   - If a patch already exists from the earlier pass, verify it still matches
     (`git diff HEAD --binary` output identical by hash).
3. **Untracked, non-ignored files** (`git ls-files --others --exclude-standard`):
   copy each to `archive\untracked\<name>\<relative path>`. Verify by SHA-256
   hash per file.
4. **Ignored content inside the worktree** (`.tmp\` etc.): keep anything in the
   reference index. Anything else is only deletable if it fits category D;
   otherwise **the whole worktree is report-only**.
5. Remove with `git -c core.longpaths=true worktree remove --force <path>`, only
   after steps 1–4 are verified and logged, then `git worktree prune`.
6. Branch refs **stay** for C2. For C1, delete the branch only if its HEAD is in
   `main`.

### D. Regenerable caches

- **Candidates:**
  - `.godot\` import caches in **inactive** worktrees (not the main checkout,
    not active worktrees);
  - `__pycache__\`;
  - duplicate `node_modules\` / Playwright packages **inside removed or inactive
    worktrees** (never the main checkout's `.tmp\l02_playwright`, which tools
    reference);
  - Godot export temp folders.
- **Proof:** the path is gitignored (`git check-ignore`), is a known generated
  cache type, is not in the reference index, and the worktree is inactive.

### E. Byte-identical duplicates

- **Candidates:** e.g. `D:\Projects\Beat-The-House-Jazz-Club-Exporter.zip` vs the
  `D:\Projects\Beat-The-House-Jazz-Club-Exporter` folder, or duplicate zips in
  `builds\itch`.
- **Proof:** for a zip vs folder, every archive entry exists in the folder with
  an identical SHA-256 and the folder has no missing entries. For file vs file,
  identical SHA-256 and size. Keep the copy in the more canonical location and
  delete the other.
- Old release zips with **no** identical copy elsewhere (e.g. `v0.2…`,
  `v0.3.2…`, `pre-item-release.zip`) are **report-only**: they are the only
  copy of a shipped build.

### Report-only (never delete)

- The main checkout's `.tmp\` (1,300+ entries). Report the largest subfolders,
  which are referenced and which unreferenced, and the
  `manage_local_artifacts.ps1 -Report` output, so the owner can decide.
- Anything in active worktrees.
- Evidence referenced by any doc.
- Old release zips without a duplicate.
- Recycle Bin size, non-project folders.
- Any item whose proof failed or was ambiguous.

## 4. Execute

1. Write the manifest (rule 1) and a human-readable plan section in the report
   (section 5) **before** the first deletion.
2. Process categories in this order: A → B → D → E → C (archive-dependent last).
3. For each item:
   - re-run rule 5's active check immediately before deleting;
   - delete;
   - confirm the path is gone;
   - append a line to `cleanup-archive\removal_log_<date>.txt`: timestamp,
     path, bytes freed, category, proof summary.
4. Finish with `git -c core.longpaths=true worktree prune` and a normal `git gc`.
   Default settings only: no `--prune=now`, no `--aggressive`. Skip `gc` if any
   other agent's git process is running.
5. Post-checks (all must pass):
   - Every ref that existed before still exists, except branches you deleted
     under B/C1 with proof. Compare with the `git for-each-ref` output captured
     before starting.
   - `git -C D:\Projects\Beat-The-House status` shows the same modified and
     untracked set as before you started (you changed nothing in it except the
     report file and this prompt).
   - Every worktree in the keep set still passes `git status` without errors.
   - Every patch in `archive\patches\` still passes the temp-index
     `apply --check`.
   - `Get-PSDrive D` free space recorded after.

## 5. Report

Write `D:\Projects\Beat-The-House\docs\plans\maintenance\d_drive_cleanup_<YYYY-MM-DD>.md`:

1. **Header:** date, free space before/after, total freed.
2. **Deleted:** a table of path, category, size, proof. Group by category.
3. **Archived:** refs created, patches, untracked copies, with verification
   results.
4. **Kept because active:** each worktree with the reason (process, recent write,
   uncommitted work, keep set).
5. **Report-only — owner decisions:** biggest remaining space users with sizes,
   and what deleting each would lose. Include the main `.tmp` breakdown, old
   release zips, the Recycle Bin, non-project folders, and the unmerged
   worktrees you couldn't archive cleanly.
6. **Skipped on surprise:** every item where a proof step failed, and what
   happened.
7. **Post-check results.**

## 6. Completion

Append an execution record to the bottom of this file
(`D:\Projects\Beat-The-House\docs\todone\maint01_d_drive_safe_cleanup_prompt.md`):
date, GB freed, counts per category, report path, owner decisions needed.
Change `Status: READY` to `Status: DONE`. If a post-check fails, set
`Status: BLOCKED`, paste the failing output, and stop deleting immediately.
