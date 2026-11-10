# Repository agent rules

- Idle-animation liveness is release-gated. Never optimize environment or game
  rendering by disabling canvas processing, removing autonomous redraws, tying
  redraws to mouse/hover/selection input, or suppressing animation while a
  placement overlay is open.
- Optimize the work performed by a scheduled frame (caches, dirty regions,
  retained layers, and measured cadence), while preserving no-input animation
  scheduling for environments, placement tools, and game surfaces.
- After changing canvas scheduling or performance code, run the focused check:
  `godot --headless --path . --script res://scripts/tests/animation_liveness_without_pointer_check.gd`.

## Requested-work continuity

- Before implementing requested Beat the House work, add or reconcile its stable
  named ID in `docs/todo/bth_task_ledger.json` and the existing named ledger in
  `docs/plans/0.6.1_stability_release_plan.md`. Preserve prior IDs and evidence.
- Retain the full requested parent objective, source and acceptance separately
  from bounded implementation batches. A completed batch never closes its parent.
- For each open item record the actual owner/task reference, status and evidence,
  associated commits/deployment (explicitly empty when absent), concrete next
  action and factual blocker. Refresh observations from actual task state;
  do not invent intentional holds, user decisions or missing-save dependencies.
- At a checkpoint and before reporting completion, update both ledger views and
  run the manual reconciliation command in `docs/todo/bth_task_ledger_checks.md`
  with the relevant owner/runtime snapshots. Resolve findings in your assigned
  scope and report remaining findings explicitly. Never mark an item Complete
  without an associated commit and its required acceptance/delivery evidence.
- The user operates the reconciliation checks. These rules do not authorize a
  coordinator, recurring watcher, task messaging, automatic reassignment, process
  termination, portrait-mode application updates or any additional permissions.

- New Beat the House QA campaigns/workspaces and launcher adapters must use
  `tools/bth_qa_storage.py` before their first directory/write/subprocess and
  immediately before child creation. Default to the approved `E:\CodexQA\BTH`
  root; require explicit workspace, profile, temp, evidence and declared output
  paths on the admitted non-C volume. No C: fallback is allowed.
- Use `tools/bth_qa_guarded_run.py` for a new guard-aware bounded worker, or call
  the same planning/preparation/launch gates from its existing capped-Job adapter.
  Keep assignment-before-resume, resource caps and cleanup/reconciliation intact.
  An environment-only wrapper does not qualify a legacy launcher that recalculates
  or hardcodes its own C: paths. Do not migrate active profiles or old saves.
- Reserve at least the configured storage budget plus headroom before launch
  (defaults: 4 GiB expected writes plus 20 GiB reserve). Record the manifest and
  launch gate in QA evidence. If validation fails, stop that launch with its exact
  path/capacity error; do not select another drive or change security settings.
