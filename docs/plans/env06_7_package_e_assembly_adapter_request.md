# env06_7 Package E — Assembly Adapter Request

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
