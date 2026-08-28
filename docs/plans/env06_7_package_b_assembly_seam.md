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

## Required shared semantic-zone patch

Frozen head `855a2961` has no semantic zones for `motel`,
`gas_station_casino`, or `beach`. The env06_6 runtime therefore correctly fails
closed when Package B attempts a physical spawn or move without an independently
proven target. The program director authorized the assembly/shared-content owner
to add exact per-archetype geometry, or this bounded standard seven-zone map, to
each of those three archetypes:

```json
{
  "background": {"bounds": [32, 32, 836, 100]},
  "center": {"bounds": [320, 90, 320, 280]},
  "exit_lane": {"bounds": [700, 180, 168, 200]},
  "foreground": {"bounds": [32, 298, 836, 100]},
  "left": {"bounds": [32, 90, 280, 280]},
  "right": {"bounds": [620, 90, 248, 280]},
  "service_lane": {"bounds": [320, 100, 360, 160]}
}
```

Package B declares only these `base::zone:*` identities. Its focused contract
proves all twelve initializations, every phase save normalization, four command
aftermaths per scenario, fact-driven interruption aftermath, exact command
receipt replay/conflict rejection, and queued fact deduplication/conflict
rejection against that sealed inventory. Assembly must run the same contract
against the real inventory after adding the geometry.

Assembly must preserve the package id, handler/renderer id, scenario ids,
authoring evidence, stable semantic identities, and sequence signatures. It may
not merge Package B by replacing the shared catalog or env06_6 runtime files.
