# Beat the House manual task reconciliation

The user operates these checks and acts on their results. The checker reads files and reports gaps. It does not assign work, message workers, restart tasks, schedule checks, change task states, fetch Git history or publish anything.

## Run it

From a checkout containing these files, with Python 3.10 or later:

```powershell
$taskCheckAt = python -c "import json; print(json.load(open('docs/todo/bth_task_reconciliation_20261104.json', encoding='utf-8-sig'))['checked_at'])"
python tools/check_bth_task_ledger.py --owners docs/todo/bth_task_owner_snapshot.json --runtimes docs/todo/bth_runtime_inventory_20261104.json --group current --now $taskCheckAt
python tools/check_bth_task_ledger.py --owners docs/todo/bth_task_owner_snapshot.json --runtimes docs/todo/bth_runtime_inventory_20261104.json --group all --now $taskCheckAt --format json --output task-reconciliation.json
python -m unittest discover -s tools/tests -v
```

Exit `0` means no reconciliation errors; warnings can remain. Exit `1` means actionable ledger/ownership/evidence findings, not a crashed checker. Exit `2` means invalid input or a file-access failure. The current snapshot deliberately reports known gaps; it is not a claim that the entire backlog is qualified.

`--verify-git` additionally runs read-only local `git cat-file` checks for associated full commit SHAs. It does not fetch. A shallow or stale local checkout can lack a real historical commit, so inspect that finding rather than treating it as proof that the commit never existed.

`--now` accepts a timezone-qualified ISO timestamp; the commands above use the fixed `checked_at` saved in the committed example report, not the current clock. Keep that report with the same recorded ledger, owner and runtime snapshots for reproducible results. Omit `--now` for a present-time check and refresh the snapshots before relying on their freshness. `--max-owner-age-hours` defaults to 24 and applies freshness checks to owner/blocker observations and supplied runtime evidence. `--no-markdown` explicitly skips the readable-index drift check; the ordinary commands above keep it enabled. Report output must not resolve to an input file; both CLIs reject such writes, including existing link aliases.

The ledger policy `runtime_cleanup_required: true` makes a missing `--runtimes` input an error. [bth_runtime_inventory_20261104.json](bth_runtime_inventory_20261104.json) contains the sanitized known-task runtime records, with scope limits and unknown launch identities retained. Runtime findings cover the entire supplied inventory even when `--group` selects only current ledger objectives. The report exposes runtime dispositions and keeps `cleanup_authorized` false; it never inspects the host or executes cleanup. See [runtime cleanup reconciliation](../testing/runtime_cleanup_reconciliation.md) for the schema and standalone CLI.

## Full objectives and batches

The structured ledger is [bth_task_ledger.json](bth_task_ledger.json). The [existing stability list](../plans/0.6.1_stability_release_plan.md#named-playtest-task-ledger) remains its readable index. Update both when task status, owner, parent, associated commits or IDs change; the checker flags divergence instead of silently importing one over the other.

Each objective retains the full requested outcome, its source, scope confirmation and required acceptance. Implementation batches have their own IDs, parent ID, bounded scope, commits and evidence. A batch's Complete state never closes its parent.

The deprecated audit illustrates the distinction:

- `BTH061-AUDIT-001` is the full audit objective and remains Open.
- `BTH061-AUDIT-001-BATCH-001` is the completed removal batch at `6a784623bdedd6b253d41ef42110adbfd4d67a12`, with its recorded NEXT verification.
- [bth_audit_scope_inventory.json](bth_audit_scope_inventory.json) preserves the observed 95-core-file inventory, 127-file UI/game scan, candidate list and remaining areas. A scan, unchanged blob, removal count or deployment does not establish semantic review of the whole requested scope.

Closing the full audit requires explicit current coverage/dispositions, classification of remaining callers/dispatch/compatibility candidates, named follow-ups for inherited failures, tested removal commits and relevant NEXT acceptance. The checker rejects a Complete parent with remaining coverage, open required acceptance or only completed batches. Unit tests reproduce the first-batch-as-full-objective error.

## What every open item records

- Stable ID and name, full objective/source, and parent links.
- Owner and the owner's current task reference. A role label without a task reference remains a visible assignment gap.
- Status, evidence with its actual scope, associated commits and deployment state. Empty commit/deployment fields are explicit for unimplemented work; a completed item requires a full associated commit SHA.
- A concrete next action and a factual blocker, or explicit none. Missing scope and unobserved acceptance remain gaps, not invented user decisions.

The report includes `findings` and `open_work`. The latter retains every selected open objective/batch, its next action, blocker, observed owner state, acceptance/coverage progress, commits/deployment and completed batches. This keeps the unfinished full audit visible even when its first batch passed.

## Owner and blocker observations

[bth_task_owner_snapshot.json](bth_task_owner_snapshot.json) is a timestamped, read-only snapshot, not a live heartbeat. Refresh it from actual task status before relying on old observations. Record `active`, `idle`, `ended` or `not_found` faithfully; a final-answer message inside an active turn is not evidence that the task ended. Missing snapshot entries are unknown, not proof that an owner stopped.

The checker flags open work with missing references, missing observations, idle/ended/missing owner tasks or stale observations. It also flags unsupported/stale blockers. The user decides whether to resume, reassign, investigate or update the record; the checker takes no such action.

## Current user direction

There are **zero intentional holds**. BTH-11 scenario work, BTH-15 Lucky Penny and BTH-17 Ledger Pencil are active items. Prepared proposals or genuinely unresolved implementation choices are recorded as such; they do not create a blanket requirement for another user selection. Actual security approvals, unavailable eligible test conditions and missing evidence remain specific factual dependencies, not intentional holds.

Erik's original personal incident saves are gone and will not be provided. Their exact-save checks are unavailable, not pending user actions. Use retained captured fixtures/tester profiles, documented equivalent-state warm/cold reconstruction and independent acceptance where feasible. Distinguish those evidence classes from a direct exact-personal-save check. Preserve recorded earlier failures and retained agent-owned saves; no item closes merely because an original personal save is unavailable.

No portrait-mode application updates are authorized by this tracking work. Historical portrait/touch observations and checks of the fixed-layout app remain evidence; they are not new portrait-layout implementation requests. The checker examines planned application changes rather than treating any mention of a phone viewport as forbidden work.

## Snapshot findings and limits

The committed example report, [bth_task_reconciliation_20261104.json](bth_task_reconciliation_20261104.json), records its check time and the recorded owner, ledger and runtime snapshots. It exposes observed ownership gaps when present, unresolved scope provenance and runtime identity/receipt evidence gaps. Those are follow-up items for the operator; they have not been disguised as passing tests or intentional holds. Lucky Penny and Ledger Pencil have an active implementation owner recorded in the current task snapshot.

The recovered all-55 scenario plan and LEDGER022 QA report retain their own scope and provenance; neither proves full implementation of a parent objective. Lucky Penny (`BTH-15`) and Ledger Pencil (`BTH-17`) require their full effect-and-description reworks. LEDGER022 retains the concrete Roulette-loss mismatch and the bounded factual-help repair. Recover the original Ledger redesign direction separately; related QA evidence does not establish the full original mechanic or acceptance. Actual mechanic choices remain implementation work without a new user-selection hold.

No file-based checker can prove a human supplied truthful evidence. It validates the recorded relationships, closure gates, freshness and readable-index consistency. Full SHA format alone does not prove a fix; optional local Git verification proves commit existence only. Deployment and behavior acceptance require their own recorded evidence.
