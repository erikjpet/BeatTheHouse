# env06_7 A-E current-main integration

Status: **DONE / ACCEPTED ON CURRENT MAIN CANDIDATE — 2026-08-31**

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

## Completed gate

The recovered combined candidate passed static project validation,
catalog/order, 55-identity and 55-signature uniqueness, committed evidence
hashes, Game 2 byte-preservation, frozen-payload parity, JSON, and diff checks.
All packages A through E were exercised on the integrated runtime. The final
proof contains 55 accepted scenarios, 1,485 pairwise comparisons with zero
failures and 27 approved similarity warnings, 683 PNG captures, 14 contact
sheets, and a 55-row authoring audit. The exact native/Web ENV06_6 runtime below
the rollout is also green, so this row no longer carries a deferred host gate.
