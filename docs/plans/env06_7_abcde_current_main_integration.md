# env06_7 A-E current-main integration

Status: **WIP UNREVIEWED / WARDEN GATE PENDING**

This candidate starts at exact current main
`d47feee3b7dde54a7cde4ec979a05f3f9209e175` and semantically replays the
frozen ordered Package A-E candidate
`241ac555bebe2ae7ee928d5f84a382d7056d1599`.

The package order remains:

1. `env06_7_shops_streets`
2. `env06_7_roadside_shelter`
3. `env06_7_bars_road`
4. `env06_7_punchline_clubs`
5. `env06_7_queen_public`

The Game 2 landing changes 21 paths relative to the prior integration base.
None intersects the 328-path A-E payload, so its `run_state`, Foundation,
Blackjack, tutorial, and presentation bytes remain exactly those of current
main.

## Package C serialized-gate remediation

The Warden's Package C author run succeeded with 11 scenarios and 55 pairs, but
proved the checked-in author outputs were stale. This integration consumes the
exact generated `env06_7_bars_road.json` and dossier outputs, including their
canonical signatures and spatial dossiers. It also invokes
`EnvironmentInstance.from_archetype` dynamically through the preloaded Script
resource in the Package C contract so headless `--script` parsing does not
depend on the global-class cache resolving that external static member first.
No product runtime, catalog authority, test assertion, golden, or budget is
weakened.

## Pending gate

The combined candidate is frozen only after static catalog/order, unique-ID,
evidence-hash, Game 2 byte-preservation, JSON, and diff checks pass. Godot
author/contract and applicable integrated verification belong to the Warden's
serialized slot.
