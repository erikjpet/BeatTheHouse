# env06_7 Package C assembly seam

Package C owns the immutable package id `env06_7_bars_road` and extension id
`bars_road`. It contains exactly Bar (7) and Jazz Club (4).

The shared runtime already reserves this package/extension pair. The assembly
owner must preserve it in the shared package order and dispatch registry and
must integrate the package without replacing shared catalog or runtime files.

Package C's unique implementation paths are:

- `data/environments/scenario_sequences/env06_7_bars_road.json`
- `scripts/core/scenario_handlers/bars_road.gd`
- `scripts/ui/scenario_renderers/bars_road.gd`
- `scripts/tests/foundation/env06_7_package_c_contract.gd`
- `docs/plans/env06_7_package_c_sequence_dossiers.json`

Assembly owns the shared catalog/index, pixel canvas, cross-catalog uniqueness
report, contact sheets, and cross-seam fixtures. Package C never edits game or
audio authority; its scenarios consume authenticated public facts and emit
existing semantic presentation cues only.

## Immutable first-rejection remediation handoff

- Exact product head: `cb684cc2cd5778dcabe00fcf4a21c6c1b6b5f05d`
- Preserved branch: `codex/env06_7-pkg-c`
- Frozen dependency base: `855a2961` (the package remains held for an accepted
  env06_6 successor and must be integrated by three-way net-payload application)
- Declared shared-catalog intake position: C, after A then B
- Product payload: the eight package-local paths reported by
  `git diff --name-only 855a2961..cb684cc2`; no shared catalog/index/loader,
  combined dossier, cross-seam fixture, pixel canvas, runtime/schema, board,
  crew/world model, gate artifact, or owner file is part of the payload

Exact-head evidence recorded on 2026-08-27:

- authoring verifier: `ENV06_7_PACKAGE_C_AUTHOR_OK scenarios=11 pairs=55`
  (5.845 seconds)
- executable package matrix:
  `ENV06_7_PACKAGE_C_CONTRACT_OK scenarios=11 signatures=11`
  (72.701 seconds)
- project validation: PASS (59.669 seconds wall; validator stage 59.333 seconds)
- `git diff --check 855a2961..cb684cc2`: clean

This handoff records evidence only. It does not claim independent review, Gate
Service acceptance, dependency acceptance, or landing. Raster captures and
contact-sheet assembly remain assembly-owner work.
