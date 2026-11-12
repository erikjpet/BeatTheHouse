# Shared character presentation

`CharacterAppearanceSnapshot` is a pure adapter, and `CharacterAvatarView` is a
transparent reusable Control. Travel takes a detached snapshot before showing
the view. The renderer never reads a run, equipment inventory, catalog, random
generator, or wall clock during animation.

## Current support and limits

The real character definitions are `data/characters/characters.json`. Their
`model` contains skin, hair, jacket and accent colors, silhouette, and scale.
Room actors use those same fields in `PixelSceneCanvas`, and the avatar calls
the exact `TableGameVisuals._draw_table_character` body/arms/head painter. It
adds simple full-body legs, with an explicitly supplied walking clock. No
generated bitmap or second body painter is involved. Canonical NPC defaults
remain unchanged; accessories, walking arms and shadow suppression are opt-in.
Walking arms require an explicitly supplied `walk_stride` key in the shared
painter's style; a legacy `pose = "walk"` alone keeps its original resting arms.

**CurrentRunState has no player-creation model, player appearance persistence,
or equipped wearable slots.** `from_run` therefore uses the shared painter's
canonical default model, without borrowing an NPC identity or generating one.
Only a carried valid `active_item_id` is considered. It must satisfy the existing
action service rule: `class == "active"` or `effect.active_item == true`.
Passive owned sunglasses are not interpreted as worn. No inventory-screen UI,
equipment logic, save schema or player customization is implemented here.

The current catalog has no active equipped item with a supported wearable
visual. For example, the selected tab detector remains explicitly recorded in
`unsupported_visual_ids`; it is not silently replaced by glasses. Future
equipment owners can supply actual selected item definitions explicitly to
`from_character`. Existing `environment_prop` values `glasses`, `cap` and
`rings` layer independently with the authored silhouette. Unknown item visuals
are reported by ID. This is a rendering capability, not proof of equipped state.
The actual catalog aliases `sunglasses` (Cheap Sunglasses) and `poker_hat`
(Fred's Poker Hat) map to the shared glasses and cap primitives respectively.
They still require explicit equipment inputs and do not become worn from
ownership or from an invalid active-slot selection.

## Consumer API

- `CharacterAppearanceSnapshot.from_run(run, library) -> Dictionary`: accepts
  the current run and loaded ContentLibrary, or equivalent dictionaries. Reads
  the loaded items array directly without populating catalog caches.
- `CharacterAppearanceSnapshot.from_character(definition,
  explicit_equipment_definitions = []) -> Dictionary`: accepts an actual
  character definition, actor member, or model dictionary. Preserves supplied
  identity, colors, silhouette and bounded authored scale. Equipment is explicit.
- `CharacterAvatarView.set_appearance(snapshot)`: normalizes and deeply detaches
  input. `snapshot()` returns a fresh detached copy for tests or another view.
- `set_pose(pose, clock)`: caller owns time. `walk`, `walking` and `enter` animate
  stride. `idle` and `arrive` use restrained idle movement. Repeated inputs are
  deterministic. Changing the pose never changes identity or equipment.
- `size`/`custom_minimum_size`: nominal size 112 by 120, proportionally fitted.
  Set both properties when requesting smaller bounds; keep the 112:120 aspect
  ratio for a tight fit, or allow transparent padding in a different ratio.
  `foot_position()` is `(size.x * 0.5, size.y)`. Position the Control by
  subtracting that local anchor from the desired world foot. Parent transforms
  and modulate can handle scene zoom, direction and fading. No opaque background.

Colors are bounded opaque HTML colors; invalid/non-finite inputs use canonical
defaults. Scale is clamped to the existing model range 0.75–1.25, then mapped to
the room actor scale range 0.90–1.08. Unknown silhouettes use `coat`.

## Focused checks

Run `scripts/tests/character_avatar_view_check.gd`,
`scripts/tests/table_character_fidelity_check.gd`, and
`scripts/tests/environment_character_idle_variety_check.gd` using the pinned
Godot engine through `tools/bth_qa_guarded_run.py`. Every launch needs a fresh
E: run ID, explicit workspace/log paths, a 12% CPU cap and 2 GiB Job limit.
The new test covers the real catalog, exact shared painter commands, simultaneous
glasses/cap/rings, legacy defaults, malformed inputs, active-item validation,
no inferred owned wearables, snapshot detachment, run/catalog/RNG purity,
caller-clock determinism, responsive sizes, and visible stride command changes.
These command-level checks do not replace visual review of the integrated scene.

### Verified November 11, 2026

Pinned Godot 4.6 stable (`89cea1439`) passed:

- `character_avatar_view_check`: 364 assertions, all 45 catalog characters,
  including actual Cheap Sunglasses and Fred's Poker Hat definitions and strict
  opt-in walking-arm regression coverage.
  Evidence run: `E:\CodexQA\BTH\runs\travel-avatar-check-20261111-05`.
- `table_character_fidelity_check`: 720 draw comparisons plus 9 roulette checks.
  Evidence run: `E:\CodexQA\BTH\runs\travel-avatar-fidelity-20261111-02`.
- `environment_character_idle_variety_check`: PASS.
  Evidence run: `E:\CodexQA\BTH\runs\travel-avatar-idles-20261111-01`.

Each run's `evidence/job.json` records the storage and child launch gates,
assignment before execution, 12% CPU/2 GiB limits, exit code 0, no timeout or
cleanup errors, and zero active processes at release. Logs and storage manifests
are alongside those receipts. No merge, commit, push, NEXT or deployment occurred.
