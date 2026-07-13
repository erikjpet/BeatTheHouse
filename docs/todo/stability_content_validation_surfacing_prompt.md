# Agent Prompt — Surface Content-Validation Errors at Runtime Boot

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. Content is data-driven from `data/*.json`, loaded and
validated by `scripts/core/content_library.gd`. This file is fully
self-contained.

## The problem (verified)

`ContentLibrary` populates `validation_errors`
(`content_library.gd:31,109,220`) with precise, high-quality messages
(duplicate ids, dangling references, malformed counts, missing fields).
But grep shows the ONLY consumers are test files
(`foundation_check.gd:502` etc.). At runtime, a broken data edit loads
silently: the game continues with defaults and the author finds out via a
weird in-game behavior instead of an error message. The release pipeline
catches this via tests, but every dev-loop iteration between test runs
flies blind.

## The task

1. At library load in the real boot path (find where `foundation_main.gd`
   constructs/initializes the `ContentLibrary`), check
   `validation_errors`:
   - In debug builds (`OS.is_debug_build()`): print every error via
     `push_error`, and show a visible one-line banner/message on the start
     screen ("Content validation: N errors — see console") using the
     existing status/message affordances. Do not build new UI chrome.
   - In release builds: print via `push_warning` only; never block play
     (the shipped data has already passed gates; tolerance is correct).
2. Add a count to the existing library stats/debug output if one exists
   (`content_library.gd:596` already exposes a
   `validation_errors` size in a stats dict — wire that through rather
   than duplicating).
3. Do not change any validation rules themselves; surfacing only.

## Hard rules (binding)

- Zero gameplay change; zero behavior change in release builds beyond
  console warnings.
- No per-frame work: this is a boot-time check, run once.
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA / Tests

1. Foundation test: a library constructed with a known-bad injected pack
   reports errors AND the boot-surfacing path flags them (assert the
   banner/message state in debug mode).
2. Clean data: current `data/*.json` must produce zero validation errors —
   if any real errors surface, FIX the data (that is in scope and is the
   point) and list each fix in your report.
3. Manual: temporarily break a data file locally, boot, confirm the debug
   banner and console errors; revert the break.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the changes, any real data errors found and fixed, test additions,
and each gate result. If a gate fails and you cannot fix it, stop, do not
commit, and report the failure output verbatim.
