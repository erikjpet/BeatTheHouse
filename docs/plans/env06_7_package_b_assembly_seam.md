# env06_7 Package B assembly seam

Package B owns the immutable package id `env06_7_roadside_shelter` and extension
id `roadside_shelter`. It contains exactly Motel (4), Gas-Station Casino (5),
and Beach (3).

The assembly owner must add this exact package/extension pair to the shared
scenario catalog dispatch and package order. Package B does not edit those
shared indexes. Its unique implementation paths are:

- `data/environments/scenario_sequences/env06_7_roadside_shelter.json`
- `scripts/core/scenario_handlers/roadside_shelter.gd`
- `scripts/ui/scenario_renderers/roadside_shelter.gd`
- `scripts/tests/foundation/env06_7_package_b_contract.gd`
- `docs/plans/env06_7_package_b_sequence_dossiers.json`

Assembly must preserve the package id, handler/renderer id, scenario ids,
authoring evidence, stable semantic identities, and sequence signatures. It may
not merge Package B by replacing the shared catalog or env06_6 runtime files.
