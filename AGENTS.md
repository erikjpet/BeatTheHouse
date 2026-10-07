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
