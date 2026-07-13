# Agent Prompt — Docs Truth Pass: Make Every Document Match the 0.4 Codebase

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. This file is
fully self-contained.

**Release framing (owner-stated, authoritative):** 0.4.0 has NOT been
released. A release candidate was built and tested, game-breaking bugs
were found, and development continued. Everything landed since — including
the current polish/perf/stability queue — is part of the 0.4.0 release,
not post-release deviation. The docs must tell that story accurately:
0.4.0 is in final development, pending final playtest, bugfixes, and
manual publish steps.

This prompt runs LAST in the pre-0.4 queue, after all code tasks have
landed, so document the tree as it actually is when you run.

## The task

### 1. Root docs

- `README.md`: verify every claim in the intro and the "Current
  Implementation" table against the current code (main scene, versions,
  targets, systems list, win condition, content counts if stated). Update
  the release-status language to the framing above. Remove or fix
  anything stale.
- `CHANGELOG.md`: update the 0.4.0 section to include the full polish
  line that landed since the first RC (gameplay gating, pawn shop run
  environment, time-system fixes, performance/stability hardening,
  architecture cleanups — summarize from `git log` since the last 0.3.3
  tag/commit, do not guess). Keep the status line honest: packaged
  evidence pending final gate battery and manual publish.

### 2. docs/plans — prune and mark

For each of the ~25 files in `docs/plans/`:

- Historical release checklists and boards for shipped versions
  (0.2, 0.3, 0.3.1, 0.3.2, 0.3.3) — add a one-line `HISTORICAL —
  superseded, kept for reference` header if missing; do not rewrite them.
- Plans whose work has shipped — mark `SHIPPED` with the landing summary
  at top (verify against code before marking).
- Plans that are still live design references (act_two_seam,
  content_style_guide, grand_casino_endgame_design, world_map_design,
  music docs, pinball docs, cheating plan) — verify their factual claims
  still match the code; fix drifted file paths/line references or mark
  the specific sections stale. Do not delete live design work.
- `0.4_release_checklist.md`, `0.4_devlog_post.md`, `0.4_publish_copy.md`
  — refresh to match the final 0.4 content (these feed the itch page and
  devlog; they must describe what actually ships, including the polish
  queue outcomes).

### 3. docs/todo and docs/todone

- Delete `docs/todo/QUEUE.md` and `docs/todo/RULES.md`: the owner
  deprecated the queue/claim ceremony on 2026-07-12; prompt files are now
  fully self-contained and launch prompts name files directly. If other
  prompt files still sit in `docs/todo/` when you run, leave them — they
  are pending work, not docs.
- `docs/todone/` is the historical archive — leave contents as-is, but if
  it has a RULES.md describing the dead ceremony, add a one-line
  deprecation note at the top rather than deleting history.

### 4. Efficiency pass

- Fix broken intra-repo links and file references you encounter in the
  docs you touch.
- Kill duplicated stale sections (e.g. two docs claiming to be the
  current release path). One source of truth per topic; the loser gets a
  pointer or a HISTORICAL mark.

## Hard rules (binding)

- Docs only: zero changes to `scripts/`, `data/`, `assets/`,
  `project.godot`, or `export_presets.cfg`.
- Truth over tidiness: never delete information that is the only record
  of why something happened; mark it historical instead.
- Every factual claim you write must be verified against the current
  tree (run the commands, read the code) — this is a truth pass, not a
  copy-edit.
- Reports under `.tmp/` (gitignored) only.

## Verification

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
  still passes (some validation includes docs/README checks — if a truth
  fix conflicts with a validator expectation, the validator's expectation
  list is part of the truth pass and may be updated to match reality;
  say so explicitly in the report).
- A link check over the docs you touched (manual or scripted) — no
  dangling intra-repo references.

## On completion

When verification passes: commit the work with a clear message, delete
this prompt file in the same commit so it cannot be executed twice, push,
and report: files updated, files marked HISTORICAL/SHIPPED, files
deleted, claims corrected (the interesting ones), and the validator
result. If verification fails and you cannot fix it, stop, do not commit,
and report the failure output verbatim.
