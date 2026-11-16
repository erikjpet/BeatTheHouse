# High Limit release v2: retained archive write boundary

New files only. The v1 builder757/profile4aec/served10dc and the actual v1
campaign are retained unchanged. No execution or qualification is claimed here.

The v1 extract launch stopped before storage preparation or child creation:
`source_inputs/source.tar` was already a regular file, but `write_paths()`
declared that read-only input as a writable output for every outer phase. The
maintained storage guard correctly rejected it with `not_directory`.

The new `high_limit_spatial_test_build_v2.py` declares these positive outputs:

| Phase | Additional writable scope |
| --- | --- |
| source-identity/tree/baseline-tree/select | None beyond the normal run evidence |
| archive | The fresh absent source tar only |
| extract | The fresh absent qa_source directory only |
| Remaining project phases | qa_source and its stage parent, as in v1 |

Archive nonoverwrite and fresh extraction checks remain mandatory. Extract
still rehashes the retained tar against its closed archive receipt and verifies
all selected Git blobs/modes, archive and extracted membership and bytes before
import. The actual source bytes are never substituted. No tar output is declared
for extract or any project phase. Unknown output phases fail.

All authority and receipt bindings use the new chain explicitly:

- `high_limit_spatial_test_build_v2.py` imports the new release profile, captures
  its own v2 filename/hash, and emits v2 phase/input schemas. Its actual worker
  command names the v2 entrypoint; v1 command receipts cannot be borrowed.
- `high_limit_spatial_test_release_profile_v2.py` authenticates only the actual
  v2 build helper and v2 input schema when closing build verification.
- `verify_high_limit_spatial_test_served_v2.py` imports the new release profile,
  hashes the new filenames and accepts only its own snapshot-before entrypoint
  and v2 served schema. Before-Job command/storage/claim/Python/source custody
  remains mandatory; there is no v1 fallback.

The existing approval e25 explicitly names the v1 helper chain. It is retained
and cannot authorize this v2 chain. Root must create a separate real build
approval wrapper referencing the same actual independent native/art GO871,
actual delivered Grand certificate c355 and native a9/edcf receipts, with actual
v2 helper references in `release_policy.profile`, `build_entrypoint` and
`served_entrypoint`. The new profile checks each reference against its exact
D tools path and current bytes before baseline/native qualification. Do not
hash the approval into itself or invent a new art review. The wrapper's source
identity remains native a9/edcf; the actual committed export source is supplied
separately to the builder and authenticated through the source/compiled bridge.

Root must commit the actual v2 files before creating a fresh selected source
archive in a new campaign/workspace. All fifteen phases start with new run IDs;
no old phase receipt is relabeled/replayed and no existing tar is overwritten.

The strict421 raw/400 CTEX/2107 PCK/1605 UID/cache/class/GDC/SCN source gate,
exact nine HL PNGs and five integer Ys, delivered Grand/Bar/other rooms,
engine/native/template/WebGL/persistence pins, default TLS and NEXT evidence
are unchanged. Every launch still uses maintained planning/preparation and
immediate launch validation, assignment before resume,12% CPU,2GiB,kill-on-close,
zero-active reconciliation and4GiB expected writes plus20GiB reserve.
No cleanup or new move/rename behavior has been added. The two existing owned
QA artifact preservation renames are retained byte-for-byte; root must prove
ownership, bytes, admitted destinations, absence/noalias/nooverwrite and afterSHA
before executing them. Profiles, saves and preexisting/unknown files are excluded.

`tools/tests/test_high_limit_spatial_test_release_v2.py` contains the original
30 release contracts adapted to the v2 filenames plus10 focused regressions.
The real retained-archive regression reads
`E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD-20261116/source_inputs/source.tar`
(228444160 bytes, SHA312495500ecf1c9827ff5108b9b1150acd7e42e895473898754ad254bdcaea87).
It invokes actual read-only `plan_layout`/`validate_layout`, requires v1's
extract outputs to reject that file, requires v2's correct outputs to admit the
same workspace at the unchanged4+20GiB budget, then proves archive bytes/stat
unchanged and no run directory created. It calls no prepare/launch operation.
Other regressions cover exact v2 worker command closure, explicit versions,
positive per-phase outputs, rejection of v1 approval/served/build receipts,
and missing/wrong v2 authority references. Synthetic fixtures are not release
proof. Parent must execute tests in its admitted capped Job; none were run by
the source author. No helper, E artifact, engine, network or QA job was executed
as part of this code-only repair.
