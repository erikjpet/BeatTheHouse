# Incremental code cleanup, 2026-10-21

Input: fresh `origin/main` at
`4d4eb062f3fb3fa547dd61e66c4e3dd9888e4ac8` (3,691 tracked files).
This is an ongoing file-by-file audit; unreviewed files are not certified clean.
Historical cleanup reports are leads, not deletion evidence. Existing saves,
generated media, native contracts, content and historical evidence are retained.

The concurrent Web freeze investigation covers `foundation_main.gd`,
`run_state.gd`, `environment_instance.gd` and physical/semantic finalization.
Changes there require coordination; this cleanup starts outside those paths.

## Batch 1: PCK directory search (deferred after qualification failure)

`tools/audit_pck_manifest.py` previously collected every `GDPC` offset in a list
and then parsed the list backwards. Search backwards directly, returning the
same last valid directory without retaining all candidate offsets. The public
function signature, validation, report shape and rejection message are unchanged.
No game code, package allowlist, save contract or native code changed. No runtime
speed claim is made. The attempted change was committed as `16d73614`.

Caller: `tools/export_itch.ps1` invokes the auditor after export; the packaging
contract invokes its Python regression. Both remain intact. There are no removed
symbols or files.

Verification:

- `tools/audit_pck_manifest_contract_test.py`: PASS, retaining audio allowlist and
  near-match rejections. Added PCK v2/v3 standalone, embedded, multiple-directory,
  invalid trailing signature and malformed-input cases.
- `tools/fixsweep06_1_packaging_contract_test.ps1`: PASS.
- Independent comparison with `4d4eb062` over 753 deterministic synthetic inputs:
  identical returned directory dictionaries or rejection type/message, including
  every byte truncation of the two generated valid fixtures.
- `git diff --check`: PASS.

The existing NEXT exporter also pins this auditor as a guarded native-reuse
input. Its attempt at `16d73614` failed qualification at 02:40:08 UTC and retained
the last good `4d4eb062` NEXT. Restore the exact qualified auditor source; retain
the useful directory-selection regressions. The reverse-search cleanup is
deferred until a separately reviewed build qualification permits it. No guard,
pipeline, native pin or watcher configuration is changed.

These are tool/fixture checks, not deployed gameplay evidence. Publication and
the broader coverage inventory are recorded as subsequent batches progress.
