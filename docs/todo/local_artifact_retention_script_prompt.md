# Agent Prompt — Local Artifact Retention Script (Non-Destructive by Default)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. This file is
fully self-contained.

## Background (verified)

Gitignored local directories have grown large: `.tmp/` ~4.1 GB (probe
reports, QA screenshots, staging copies of old script versions), `.tools/`
~3.4 GB (local toolchain), `builds/` ~342 MB (export artifacts).

**Owner decision (authoritative): NOTHING is to be deleted now.** These
are test evidence and reference material, kept locally until they are
exported/backed up elsewhere as part of the release action. This task
builds the tooling for that future action — it must not remove anything
when it lands.

## The task

Create `tools/manage_local_artifacts.ps1` with three modes:

1. **`-Report` (default when no flag given):** walk `.tmp/`, `builds/`,
   and `.tmp`-style clutter anywhere else gitignored, and print a
   size-sorted inventory grouped by category (probe reports, visual QA
   output, mouse-batch logs, staging file copies, export artifacts,
   unknown). Read-only, always safe.
2. **`-Export <destination>`:** copy (never move) the inventory to a
   destination folder with the repo-relative structure preserved and a
   manifest file (paths, sizes, SHA256, capture date). Verifies the copy
   (hash check) and prints a summary. Source files remain untouched.
3. **`-Clean`:** deletes ONLY items that a prior `-Export` manifest in the
   destination confirms were exported with matching hashes, and requires
   an additional explicit `-IAmSure` flag. Without both the manifest
   check and `-IAmSure`, it refuses and explains. `.tools/` is NEVER
   touched by `-Clean` (it is the local toolchain, not artifacts).

Also:

- Document the retention policy at the top of the script and in a short
  section added to the README's development notes (or the closest
  existing dev-docs location): artifacts are kept locally through
  development, exported at release, cleaned only after verified export.
- PowerShell 5.1-compatible (no PS7-only syntax), matching the repo's
  existing `tools/*.ps1` conventions.

## Hard rules (binding)

- **This task must not delete or move a single existing file when it
  lands.** `-Clean` exists but must never be run as part of this task's
  QA beyond the sandbox test below.
- No changes to `scripts/`, `data/`, or game code. Tooling + docs only.
- `.gitignore` must already cover everything the script manages; verify
  and report (do not un-ignore anything).
- Reports under `.tmp/` (gitignored) only.

## QA (all required)

1. `-Report` runs against the real tree and its totals roughly match
   `Get-ChildItem` measurements; include the output in your report.
2. Sandbox round-trip: create a small fake artifact tree under
   `.tmp/retention_selftest/`, `-Export` it to a scratch destination,
   verify manifest + hashes, `-Clean -IAmSure` removes ONLY the exported
   selftest files, and refuses without the manifest or without
   `-IAmSure`. The selftest must never touch real artifacts — prove it by
   re-running `-Report` and comparing totals (only the selftest delta may
   differ).
3. Static check: the script contains no code path that deletes outside
   the manifest-verified set.

## Verification gates

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- The sandbox round-trip above, documented in the report.

## On completion

When verification passes: commit the script + docs with a clear message,
delete this prompt file in the same commit so it cannot be executed
twice, push, and report the inventory summary, the sandbox test results,
and the validator result. If verification fails and you cannot fix it,
stop, do not commit, and report the failure output verbatim.
