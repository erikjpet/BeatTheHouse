# Runtime cleanup reconciliation

Stable objective: `BTH-RUNTIME-CLEANUP-001`.

Use the existing task ledger reconciliation together with an explicit runtime
inventory to expose abandoned or superseded task instances. This is a **manual,
read-only evidence checker**. It does not schedule a watcher, inspect the desktop,
discover processes, stop anything, close a browser, or delete a profile. A candidate
orphan remains a review item. An old launch record, idle owner, PID, port, browser
label, or old zero-resource receipt cannot by itself justify closing a current
instance.

From the repository root:

```powershell
$taskCheckAt = python -c "import json; print(json.load(open('docs/todo/bth_task_reconciliation_20261104.json', encoding='utf-8-sig'))['checked_at'])"
python tools/check_bth_task_ledger.py --ledger docs/todo/bth_task_ledger.json `
  --owners docs/todo/bth_task_owner_snapshot.json `
  --runtimes docs/todo/bth_runtime_inventory_20261104.json --group current `
  --now $taskCheckAt --format json
```

The standalone checker is also available:

```powershell
python tools/check_bth_runtime_inventory.py `
  --inventory docs/todo/bth_runtime_inventory_20261104.json `
  --owners docs/todo/bth_task_owner_snapshot.json `
  --now $taskCheckAt --format json
```

Exit codes are `0` for no error findings, `1` for open findings and `2` for invalid
input. The inventory is deliberately supplied by a permitted lifecycle collector;
the checker does not resolve paths in evidence references or verify their contents.
The `--now` examples reuse the fixed `checked_at` from the committed report with
its matching recorded ledger, owner and runtime snapshots; the variable above
does not read the current clock. Omit `--now` for a present-time check after
refreshing the permitted lifecycle evidence.
When the existing ledger policy `runtime_cleanup_required` is true, omitting
`--runtimes` is an error and returns exit 1. Without that policy, the runtime input
remains optional; the report explicitly records whether it was supplied.
Runtime findings cover the entire supplied inventory, even when the ledger's
`--group` selects only current or historical objectives. No inventory record is
silently discarded by that task-list filter. Both CLIs reject an `--output` path
that resolves to an input file, including existing link aliases.
Keep detailed local process identities, profiles and network evidence local unless
their publication is authorized. Do not manufacture nonce or start-time evidence
for older launches. Record those fields as `null` and retain the resulting gap.

## Inventory schema

`bth.runtime_inventory/v1` has `observed_at`, `scope` and `instances`. Every
timestamp must include a timezone. Observation freshness defaults to 24 hours;
observations more than five minutes in the future are invalid as current evidence.
The owner snapshot uses the existing `bth.owner_snapshot/v1` schema with each
owner's `task_ref`, `state` and `observed_at`. Owner states are `active`, `idle`,
`ended`, or `not_found`. Missing or stale owners cannot establish abandonment.

The following example describes a fictional, active, bounded test job. Identity
keys must capture the actual lifecycle identity, including process start identity
when a process ID is used. A PID alone must never serve as that key.

```json
{
  "schema": "bth.runtime_inventory/v1",
  "observed_at": "2026-11-04T12:00:00Z",
  "scope": {
    "description": "Explicit launch records from the named test workers",
    "complete": false,
    "evidence": ["local/record-index.json"]
  },
  "instances": [
    {
      "instance_id": "qa-session-001",
      "task_id": "BTH-QA-001",
      "owner_task_ref": "recorded-owner-task-id",
      "kind": "test_job",
      "ownership": "task_owned",
      "state": "active",
      "launch_identity": {
        "nonce": "recorded-launch-nonce",
        "key": "recorded-job-identity-and-start",
        "started_at": "2026-11-04T11:55:00Z",
        "evidence": ["local/launch.json"]
      },
      "current_identity": {
        "state": "match",
        "observed_at": "2026-11-04T12:00:00Z",
        "key": "recorded-job-identity-and-start",
        "evidence": ["local/owned-job-observation.json"]
      },
      "activity": {
        "state": "active",
        "observed_at": "2026-11-04T12:00:00Z",
        "lease_until": "2026-11-04T12:10:00Z",
        "evidence": ["local/owner-checkpoint.json"]
      },
      "protected": {"saves": false, "shared_resources": false},
      "cleanup": {
        "contract": {
          "success": ["local/success-unwind-test.json"],
          "failure": ["local/failure-unwind-test.json"],
          "timeout": ["local/timeout-test.json"],
          "interruption": ["local/kill-on-close-test.json"]
        },
        "receipt": null
      }
    }
  ]
}
```

Each stable `instance_id` is unique. Kinds are `game`, `browser`, `profile`,
`temporary_server`, `export`, and `test_job`. Ownership is `task_owned`, `user`,
`shared_service`, or `unknown`. Lifecycle states are `active`, `idle`, `ended`,
`superseded`, and `unknown`. Current identity states are `match`, `mismatch`,
`absent`, and `unknown`. Activity states are `active`, `idle`, and `unknown`.

Profiles are protected regardless of owner; retained tester saves are evidence,
not runtime instances to delete. `protected.saves` marks state that must be
preserved while resolving lifecycle use. `protected.shared_resources` protects a
resource used outside this run. Neither protected resource becomes an orphan
candidate. User sessions, shared site services and unknown ownership also remain
protected. A fresh active owner, activity observation or lease prevents orphan
classification.
Unknown current activity cannot establish an orphan candidate; an ended owner,
fresh matching identity and explicitly idle current-use evidence are all required.

Cleanup `contract` references must support each of the success, failure, timeout
and interruption paths. Documenting a policy is not evidence that the launcher
implements it. Reuse maintained resource-bounded launchers, attach children before
resuming them, close the exact owned browser context, drain and close the owned
job in `finally`, and retain an outcome receipt. Interruption needs the existing
job's kill-on-close guarantee and its validation, because a process may die before
Python `finally` executes. Do not weaken resource guards or terminate by process
name, port, profile path or stale PID. Missing contract evidence stays open.

A finished cleanup receipt has this shape:

```json
{
  "observed_at": "2026-11-04T12:05:00Z",
  "outcome": "verified_empty",
  "identity_nonce": "recorded-launch-nonce",
  "remaining_count": 0,
  "evidence": ["local/active-at-release-zero.json"]
}
```

Outcomes are `verified_empty`, `verified_closed`, `failed`, `pending`, `uncertain`,
and `not_attempted`. A clean receipt needs the matching nonce, a timestamp after
that launch, evidence and a zero remaining count. Its meaning is historical
cleanup for that launch. An unknown current observation remains unknown, and a
later observation of the same launch contradicts the clean receipt. An uncertain
outcome is checked before any retry. A changed start identity means a reused PID;
the present process must remain untouched.

## Reconciliation workflow

1. Inventory only known task launch records and lifecycle handles. Record scope
   limits explicitly. Respect prior inspection denials without switching routes.
2. Refresh owner state and actual use through permitted task lifecycle evidence.
   Preserve active workers, user sessions, profiles, saves and intended site
   services. A task being idle does not establish that its instance is unused.
3. Check success, failure, timeout and interrupted launches for empty/closed
   receipts. Link superseding instance IDs without reusing the original ID.
4. Review candidate orphans using their recorded owner and exact launch identity.
   Perform any independently authorized cleanup through that instance's owned
   lifecycle, then record its real outcome. The report never authorizes cleanup.
5. Keep unresolved ownership, missing receipts, uncertain outcomes and unverified
   coverage open under `BTH-RUNTIME-CLEANUP-001`. An implementation commit alone
   does not prove that all current instances were audited or cleaned.

Focused regression tests:

```powershell
python -m unittest discover -s tools/tests -v
```
