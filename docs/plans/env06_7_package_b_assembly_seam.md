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

## Remediation evidence and hold

The first-rejection remediation replaces the synthetic inventory with the
production authority consumer above and adds executable partial/terminal
reentry, every reachable branch save/load, authored expiry/cleanup, hostile
operation/fact/cleanup-content rollback, paired hidden observers, deterministic
serialization, transition liveness, and performance counters.

Package-local native and Web probes produced the same semantic SHA-256
`ed72e2846fb5e26558bf2cc9545a77e2b49e1389da7a8527a68acd6ee3bd1bf7`.
Native performed 200 serializations in 138.124 ms with a 7.798 ms maximum idle
frame. Chrome 151 at CPU x4 performed them in 413.875 ms with a 34.105 ms
maximum idle frame. The tracked manifest contains 185 actual 960x540 raster
captures and one inspected contact sheet; it records authored hit sizes, rendered
minimum hit size, keyboard/controller focus, safe-exit visibility, small-screen,
reduced-motion, and obstruction states.

The package remains held, not accepted-ready: the production-composed contract
must finish against the ordered assembly's real Motel, Gas-Station Casino, and
Beach authority. Two exact local attempts with the current dependency lineage
remained in production content loading until bounded wrapper timeouts at 124 and
184 seconds and emitted no verdict. These timeouts are retained and are not a
green claim. Assembly must rerun after the accepted env06_6 successor and real
zone authority are present.
