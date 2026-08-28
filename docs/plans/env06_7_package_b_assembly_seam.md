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
- `tools/env06_7_package_b_generate.mjs`
- `tools/env06_7_package_b_sign.gd`

## Required production authority

Frozen head `855a2961` has no semantic zones for `motel`,
`gas_station_casino`, or `beach`. The env06_6 runtime therefore correctly fails
closed when Package B attempts a physical spawn or move without an independently
proven target. Package B does not prescribe, synthesize, or patch that geometry.
Its contract composes each archetype through the production `ContentLibrary` and
`EnvironmentInstance`, seals it with `EnvironmentSemanticInventory`, and accepts
only declared identities present in that exact sealed inventory. Missing targets,
an unsealed instance, or an empty authority digest are package failures.

Package B declares only these `base::zone:*` identities. Its focused contract
proves all twelve initializations, every phase save normalization, four command
aftermaths per scenario, fact-driven interruption aftermath, exact command
receipt replay/conflict rejection, and queued fact deduplication/conflict
rejection against that production inventory. Assembly must run the same contract
after supplying the real geometry; no package-local synthetic inventory is
acceptance evidence.

Assembly must preserve the package id, handler/renderer id, scenario ids,
authoring evidence, stable semantic identities, and sequence signatures. It may
not merge Package B by replacing the shared catalog or env06_6 runtime files.
