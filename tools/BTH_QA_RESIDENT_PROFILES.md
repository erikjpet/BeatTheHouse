# Supported resident QA profile admission

Fresh `plan_layout` remains unchanged. Do not substitute an old profile into a
fresh Layout, copy a profile into a new leaf, or create an unused-profile manifest.

The explicit `plan_resident_layout` API supports an existing closed QA campaign:

```python
layout = storage.plan_resident_layout(
    root=r"E:\CodexQA\BTH", workspace=existing_qa_workspace, run_id=fresh_case_id,
    profile=existing_qa_workspace / "qa-resident-profiles" / campaign_id,
    custody=existing_qa_workspace / "evidence" / (campaign_id + "-custody.json"),
    campaign_id=campaign_id, origin=known_loopback_origin, expected_commit=pinned_commit)
layout = storage.prepare_layout(layout)
env = storage.child_environment(layout, parent_env)
storage.check_launch(layout, cwd=layout.workspace, env=env,
                     extra_write_paths=declared_output_directories)
```

The resident schema records the actual profile. It requires matching CLEAN_CLOSED
custody, completed/closed browser state, prior owned Job zero, pinned build/origin,
and stable directory identity. Only QA metadata JSON is read/hashed; profile
contents, keys and saves are neither read nor copied. Every ancestor remains
subject to non-C, root, reparse, resolution and 24 GiB default capacity checks.

Preparation holds an exclusive process-owned Windows named mutex and never
creates or writes inside the profile. Revalidation occurs under the acquired
lease before any directories are written, and again at every child launch gate.
The one nesting exception is the explicitly receipt-bound profile inside its
existing QA workspace; other overlaps remain rejected.

## Storage-aware launcher integration is required

Keep the lease-owning launcher alive for the full capped-Job session. Use the
admitted actual profile and environment; an environment-only legacy shim is not
sufficient. Keep custody unchanged through the final child-creation gate; after
the last profile worker is assigned, mark that case in progress before resuming
it. Do not create additional children after changing the baseline custody.
Keep assignment-before-resume, existing CPU/memory/time limits and cleanup.

After closing the browser and draining the owned Job, record actual zero owned
processes and clean closure. Only then call:

```python
storage.release_resident_layout(layout, active_owned_processes=actual_job_active)
```

If cleanup, custody or identity is uncertain, preserve receipts and stop. Do not
relabel history, replay an action, force a stale profile through admission, change
drives/security settings, or migrate a profile. A released prepared layout is not
a reusable admission; a new guarded session needs a fresh run ID and lease.

`bth_qa_guarded_run` still defaults to fresh profiles. A resident-aware capped
adapter must implement the lifecycle above; this API is not a browser launcher
and does not itself authorize gameplay retries.

## Receipt contract and preserved recovery policies

Ordinary admission requires integer zero browser exit and active-process counts,
explicit false timeout, an empty cleanup-error list, three explicit true context
closure/completion flags, and no in-flight action or error. Missing closure proof,
boolean values substituted for numeric zero, and failed cleanup remain blocked.

The three `bth_qa_*_inspection.py` modules preserve existing, exact frozen R17
campaign policies. Each is limited to one named predecessor/successor, build,
profile, origin and evidence fingerprint set. They are not general retry rules.
Their presence does not authorize running a recovery or resuming gameplay.
Ordinary resident admission after a recovery still requires its matching archived
observation review. No profile or save contents are read or migrated.

`bth_qa_atomic_receipt.atomic_json` is for launcher-owned admitted QA JSON paths,
not game saves. It installs bounded JSON through an exclusive pending file,
bounded sharing retries, and atomic replacement. Persistent access denial and
read-only targets are not bypassed. Failed pending files remain diagnostic evidence.

## Validation

Run the synthetic helper suite through the guarded worker:

```powershell
python -B tools/bth_qa_guarded_run.py run `
  --workspace E:/CodexQA/BTH/workspaces/your-existing-checkout `
  --run-id unique-storage-tests --timeout 120 `
  -- <absolute-python-executable> -B -m unittest discover `
     -s tools/tests -p 'test_bth_qa*.py' -v
```

Tests cover fresh admission, resident metadata/identity drift, acquire-time races,
exclusive mutex ownership, typed closure proof, bounded JSON reads, receipt
replacement/retry bounds and exact frozen policy scope/fingerprint rejection.
These tests use synthetic metadata and engineering temp directories; they do not
prove current retained-campaign evidence or gameplay behavior. See the
[2026-11-10 finalization record](../docs/testing/qa_storage_finalization_20261110.md)
for the integrated verification result.
