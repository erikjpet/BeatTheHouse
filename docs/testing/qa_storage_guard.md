# Future QA storage admission

Stable ID: `BTH-QA-STORAGE-GUARD-001`.

New QA work uses the existing approved `E:\CodexQA\BTH` storage root. The main
repository and maintained Job helpers may remain on D:, and installed executables
may be read from C:. Writable workspace, browser profile, temp, evidence, native
state and declared export paths must be admitted beneath the chosen non-C root.
Fresh admission never moves, copies, deletes or reuses an existing profile or save.
The explicit resident API can bind an existing closed QA profile without migrating
or inspecting its contents; see [resident admission](../../tools/BTH_QA_RESIDENT_PROFILES.md). No Windows environment, certificate, ACL, service or unrelated app setting
is changed.

## Admission and ownership

`tools/bth_qa_storage.py` plans the layout without writes. It rejects C:, relative
or drive-relative paths, network/device paths, traversal, reparse ancestors,
resolved aliases and writable paths outside the selected root. The workspace is
separate from the fresh run's profile/temp/evidence/state directories. Declared
additional writable paths must belong to that workspace or that run, not another
campaign under the shared root.

Every planned path is checked against real current free space on its existing
ancestor. The default requirement is **24 GiB free**: 4 GiB expected writes plus
20 GiB reserve. Declare a larger expected-write budget for a heavier import/export
or capture. No fallback volume is attempted. Any selected non-C volume below the configured
requirement is rejected.

Preparation creates only new run directories and an exclusive ownership manifest.
It can create an absent, empty workspace; it never populates or migrates a source
tree. An existing explicitly selected source workspace is retained. An occupied
run ID, altered manifest or missing prepared directory blocks launch. A failed
preparation retains its partial new directories and requires a fresh run ID.

Space and paths are rechecked after preparation and immediately before each owned
child is created. The manifest token, SHA-256 and observed free bytes are recorded
in launch evidence. A prepared run is single-use: an exclusive launch claim, log
and pending receipt are reserved before any Job or child is created. Occupied
evidence or a competing launch blocks execution, and failure retains its claim.
This is a preflight budget, not a disk quota or a filesystem security sandbox.
Concurrent growth or arbitrary hardcoded child writes are not prevented by an
environment variable. Worker/adapters must consume the admitted paths.

## Using the entrypoint

From a checkout containing these tools:

```powershell
python -B tools/bth_qa_guarded_run.py check `
  --workspace E:\CodexQA\BTH\StorageGuard\workspaces\new-qa-001 `
  --run-id new-qa-001
```

`check` is read-only. `prepare` creates the new layout and manifest without a
worker. Provision a fresh source workspace through the existing authorized
worktree workflow; relative `.godot` imports and `builds` exports then stay with
that E: workspace. Do not wrap an old C: launcher and assume its own path
calculations are overridden.

`run` prepares a fresh run and starts one explicit guard-aware command after `--`:

```powershell
python -B tools/bth_qa_guarded_run.py run `
  --workspace E:\CodexQA\BTH\StorageGuard\workspaces\new-qa-001 `
  --run-id new-qa-run-001 --timeout 120 `
  -- <existing-executable> <guard-aware-worker-arguments>
```

Use `--write-path` for an additional export/log/download destination. It is
validated before preparation and again before launch. Increase
`--expected-write-gib` for the actual workload; `--reserve-gib` controls retained
headroom. Invalid targets return exit 2 and a structured error with the target,
required bytes and available bytes when applicable. Worker/cleanup failures return
exit 1. Success requires worker exit 0 and zero owned processes at release.
Known writable command flags (`--user-data-dir`, `--disk-cache-dir`, `--log-file`,
`--output`, `--output-dir`, `--path`) are admitted too. Profile and workspace flags
must match the exact layout; read-only executable and source arguments may remain
on C:/D:. Unknown flags or paths hardcoded inside a worker remain the adapter's
responsibility.

The reference runner uses the maintained D: `CpuCappedJob` and `SuspendedWorker`:
12% aggregate CPU, 2 GiB aggregate memory, no breakaway, assignment before resume,
bounded timeout and kill-on-close cleanup. Its captured log is bounded to 16 MiB.
It does not create a public server or attach to existing processes.

## Existing adapter integration

Use these calls in every new adapter, before its first mkdir/write/helper process:

```python
layout = plan_layout(root=approved_root, workspace=source, run_id=unique_run_id)
validate_layout(layout, extra_write_paths=declared_outputs)
layout = prepare_layout(layout)
env = child_environment(layout, parent_env)
# Immediately before each existing owned/suspended child constructor:
check_launch(layout, cwd=layout.workspace, env=env,
             extra_write_paths=declared_outputs)
```

Use the prepared layout's actual paths in the adapter. `child_environment` returns
a new mapping for this child only. It overrides temp, appdata/localappdata, Windows
home fallbacks, XDG caches, Python bytecode, explicit BTH native state/save paths,
`BTH_QA_PROFILE_DIR` and `BTH_WEB_EVIDENCE_DIR`. It does not modify the caller's
environment or force a gameplay distribution mode.

A browser adapter must pass `BTH_QA_PROFILE_DIR` as its explicit private profile
directory and use admitted cache/download paths. Existing browser binaries may
remain read-only C:/D: inputs; select their executable/cache location explicitly
when the redirected child home would otherwise change discovery. Never use the
user's default browser profile or silently import a retained campaign.

Historical C: launchers and active E: campaigns are not retrofitted by this change.
New versions must adopt the gates and path mapping before they are qualified.

## Verification

```powershell
python -B -m unittest discover -s tools/tests -p 'test_bth_qa*.py'
```

The tests cover C: output rejection, low-space D:, admitted E:, real-path aliases,
reparse points, scope/overlap, occupied paths, manifest tampering, budget rechecks,
child-only environment overrides and both launch gates. A scoped writable E:
smoke is recorded separately after the completed implementation passes review.
