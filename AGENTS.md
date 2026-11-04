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
