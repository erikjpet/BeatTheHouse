# Agent Prompt — Atomic Run-Save Writes with Backup Rotation and Recovery

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.4.0 to Web/itch.io and Windows desktop. 0.4.0 is still
IN DEVELOPMENT: this task is part of the 0.4.0 polish line, not a
post-release change. This file is fully self-contained.

## The problem (verified; re-verify line numbers before editing)

`SaveService.save_run` (`scripts/core/save_service.gd:17-32`) opens the
FINAL save path with `FileAccess.WRITE` and writes the JSON directly. If
the process dies mid-write — browser tab closed on itch.io, crash, power
loss — the autosave is truncated/corrupt. `load_run` (`:36-49`) then
silently returns `null` and the player's run is gone with no explanation.
Autosaves happen after every action, so the write window is hit constantly.

The correct pattern already exists in this repo:
`scripts/core/profile_inventory.gd:45-55` writes to `"%s.tmp"` then
`DirAccess.rename_absolute(temp_path, absolute_path)`. Run saves predate
that hardening and never got it.

## The task

1. **Atomic writes:** port the temp-file + rename pattern into
   `SaveService.save_run`. Match profile_inventory's approach so there is
   one idiom in the repo. Handle rename failure by reporting the error
   code up (the caller already surfaces save status text).
2. **Backup rotation:** before renaming over an existing valid save, keep
   the previous file as `<slot>.bak` (single-generation rotation is
   enough). The `.bak` must only ever contain a previously-successfully-
   written save, never a partial.
3. **Recovery on load:** if the primary save fails to parse
   (`JSON.parse_string` non-dictionary) or fails the shape check, fall
   back to `<slot>.bak`. Distinguish the three outcomes for callers:
   loaded-primary, loaded-backup, nothing-loadable.
4. **Player-facing surfacing:** when the host loads a backup or finds a
   corrupt unrecoverable save, show a clear one-line message via the
   existing status/message path in `foundation_main.gd` (find how
   Continue/load surfaces status today and extend it — do not build new
   UI). Silent data loss is the bug; silence is not acceptable in the fix.
5. **has_run:** `has_run` (`:12-13`) must count a slot as present if
   either primary or backup is loadable, so Continue does not vanish when
   only the backup survived.
6. Keep `SAVE_SCHEMA`/`SAVE_VERSION` and the legacy raw-payload acceptance
   (`_run_data_from_payload`, `_looks_like_run_state`) exactly as they
   are. No migration system — explicitly out of scope per owner decision.

## Hard rules (binding)

- Save payload content and schema stay byte-identical for the happy path;
  only the write/read mechanics and failure handling change.
- Web export caveat: `user://` on web is IndexedDB-backed; verify
  `DirAccess.rename_absolute` works there (the profile system already
  relies on it in production — confirm and cite that precedent in your
  report rather than assuming).
- Zero-copy per-frame and idle-liveness rules are unaffected but remain
  binding; autosave stays action-boundary/deferred-frame driven exactly as
  today (`_flush_pending_autosave_if_ready`).
- Match existing style: tab indentation, typed GDScript, sparse comments
  that state constraints only. Reports under `.tmp/` (gitignored) only.
- This is 0.4.0 in-development polish; do not bump versions or touch
  release packaging.

## QA / Tests (extend the foundation test suite; all required)

1. Round trip: save → load-primary returns an equivalent run state
   (existing coverage likely; keep it green).
2. Corrupt primary + valid backup → load returns the backup state and the
   outcome flag says so.
3. Corrupt primary + no backup → load returns null, outcome
   nothing-loadable, and the host shows the corrupt-save message instead
   of silently showing no Continue.
4. Truncated-file simulation: write garbage/partial JSON to the primary
   path directly, confirm recovery path.
5. Rotation correctness: two consecutive saves → `.bak` equals the first
   save, primary equals the second. A failed/partial write must never
   clobber the `.bak`.
6. `has_run` true when only backup exists.
7. Windows desktop manual smoke: save mid-run, kill the process, relaunch,
   Continue works.

## Verification gates (all must pass)

- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`
- `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`

## On completion

When every gate passes: commit the work with a clear message, delete this
prompt file in the same commit so it cannot be executed twice, push, and
report the changes, the web-rename precedent you verified, test additions,
and each gate result. If a gate fails and you cannot fix it, stop, do not
commit, and report the failure output verbatim.
