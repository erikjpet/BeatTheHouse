# env06_7 Package E — Assembly Adapter Request

Historical note: the ordered recovery at
`env06_7_package_e_ordered_recovery.md` supplies this bounded seam on top of
Packages A→B→C→D. This request remains as provenance for the original blocker.

Status: requested from the env06_7 Assembly owner; Package E does not claim
these shared/runtime paths.

Package E publishes the immutable envelope
`data/environments/scenario_sequences/env06_7_queen_public.json` with the
frozen dispatch identities required by `ScenarioExtensionDispatch`:

- package: `env06_7_queen_public`
- handler: `queen_public`
- renderer: `queen_public`

The accepted env06_6 head `855a2961` allowlists those identities but does not
contain their adapter files. Assembly must provide the bounded adapters at:

- `scripts/core/scenario_handlers/queen_public.gd`
- `scripts/ui/scenario_renderers/queen_public.gd`

They must preserve the env06_6 semantic-v1 command/render contract, add no
travel, game, crew, money, or hidden-audit authority, and expose only the
public semantic operations authored by Package E. The renderer must not reveal
future audit route, cheat result, game result, or unrevealed branch state.

Assembly also owns registering this package in shared catalog/index probes and
the combined Grand Casino audit fixture. Package E supplies definitions and a
focused fixture only; it will not edit the dispatch, catalog loader, pixel
canvas, shared scenario suite, craps module, or game ritual runtime.

## Production-composition blocker found by the package audit

The package-local production composition audit at WIP `68e569d5` loads the real
ContentLibrary, generates deterministic Delta Queen and Grand Casino instances,
and seals each instance through EnvironmentSemanticInventory. It found that
neither production environment currently publishes any semantic zones. Package
E therefore cannot replace its former synthetic target inventory with a
production-proven spatial host until assembly supplies bounded `queen_public`
zones or anchors for the package's independently interactable route stations.

The same audit found that Grand Casino's existing internal layout objects
`travel:grand_casino_high_limit`, `travel:grand_casino_back_room`, and
`travel:grand_casino_cage` are rejected by authoritative base-record production
because their room routes are not catalog-backed. Assembly must either
catalog-prove those existing internal routes or provide the sanctioned
Grand-Casino composition seam that excludes them without weakening ordinary
production validation.

These are shared assembly requirements. Package E will not add synthetic
inventory, edit the shared archetypes/catalog/loader, or claim a production
composition pass before the assembly-owned seam exists.
