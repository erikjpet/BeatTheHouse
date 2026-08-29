# env06_7 Package A — Implementation Ownership

- Squad: `ENV06_7-A`
- Branch: `codex/env06_7-pkg-a`
- Frozen runtime base: `855a2961`
- Accepted checklist: `849aa8c` (Package A and common)
- Binding ownership matrix: `ffc6bbd`
- Scope: Corner Store (5), Back Alley (4), and Pawn Shop (3)

## Exclusive files

- `data/environments/scenario_sequences/env06_7_shops_streets.json`
- `docs/plans/env06_7_package_a_ownership.md`
- Package-local dossiers, focused fixtures, and evidence with unique Package A
  names added by this squad.

## Exclusions

This squad does not edit the main board, scenario catalog/index, shared scenario
runtime, `pixel_scene_canvas.gd`, cross-seam fixtures, game modules, crew/world
models, or shared test/probe registries. Required shared integration changes are
handed to the env06_7 assembly owner as bounded manifests.
