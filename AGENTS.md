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

- Record each requested item once with a stable ID, status and associated
  commits in the machine ledger and its readable plan index.
- An item is Complete when its fix is committed to main and its focused check
  passes. Batches may close the parent when the parent's fix is done.
- Do not add acceptance, deployment or evidence requirements beyond this.
  Keep existing evidence and follow the liveness and QA storage rules.

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
