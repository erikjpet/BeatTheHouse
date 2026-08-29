# env06_7 A-E current-main integration

Status: **WIP UNREVIEWED / WARDEN GATE PENDING**

This candidate starts at exact current main
`b091bc43330dd1df472c868b3246032c47570e9b` and semantically replays, in its
original A-through-E commit order, the frozen integrated candidate
`6d6bfd6d003b4699fff59934e26e1f6fe5f55ceb`.

The package order remains:

1. `env06_7_shops_streets`
2. `env06_7_roadside_shelter`
3. `env06_7_bars_road`
4. `env06_7_punchline_clubs`
5. `env06_7_queen_public`

The Game 2 post-land recovery changes 13 paths relative to the prior A-E
integration base. None intersects the 329-path frozen A-E payload, so all 13
Game 2 recovery paths remain byte-identical to `b091bc43`.

Static replay verification also proves that every frozen A-E payload path is
byte-identical to `6d6bfd6d` except this integration note, whose base and
evidence statements are intentionally refreshed for the new parent.

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

The combined candidate passed static project validation, catalog/order,
55-identity and 55-signature uniqueness, committed evidence-hash, Game 2
byte-preservation, frozen-payload parity, JSON, and diff checks. Godot
author/contract and applicable integrated verification belong to the Warden's
serialized slot.
