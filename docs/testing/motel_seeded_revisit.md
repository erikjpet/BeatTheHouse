# BTH-TRAVEL-MOTEL-SEED-001: Motel revisit during the overnight scenario gap

The ordinary OPEN Motel route rejected the player's Jazz departure before
payment: `Selected scenario motel_wedding_overflow does not match the destination
node's seeded definition.` The visible quote was 3 cash / 24 minutes / Bus
ticket. The player reported Day7 around03:30, 48 cash, Heat1 and one Rubber Pegs,
after resolving Day6 Wedding Overflow and taking Silas's route tip.

Original observation: build
`3fd56aebde05182a02a6babf096ae8b7fe430f7f`,
`C:/Users/theep/Documents/Codex/2026-10-26/task/evidence/qa-BTH-TRAVEL-MOTEL-SEED-001.json`.
It records exactly one Travel confirmation and no fare debit, with a cleanly
closed resident R03 profile. Its no-charge evidence remains unchanged.

## Root cause and scoped correction

The24h scenario cycle ends at02:30 and reopens at04:00; ordinary Motel access
remains open. Production travel primes all town selections before lazily
refreshing a visited destination. Priming marked Motel's selection closed with
no scenario. Its stored Wedding room still carried the same opening-cycle stamp.
The refresh fast path used that stamp and the global phase to conclude the room
was already retired. Strict installation then correctly rejected the old room
against the now-empty seeded definition.

The closed-cycle fast path now also checks the exposed room and all other
retained layers for authored scenario state. If any remains, the existing
authenticated retirement transaction runs before installation. The current
exposed body supersedes its stored layer mirror, matching retirement's existing
ownership. Active-cycle behavior, seeded-definition validation, semantic seals,
the scenario schedule and fare/risk rules remain intact. No portrait, viewport,
touch/focus or animation scheduling changes are included.

Retirement also requires an exact scenario identity before clearing retained
legacy/runtime state. It resolves the existing missing-key legacy fallback
first. An explicit blank ID, or a missing ID with no valid fallback, rejects
without clearing/re-signing the old runtime or altering its stored history.
This closes a malformed-state control discovered during independent acceptance;
the genuine captured room retains its authored Wedding identity throughout the
authenticated retirement.

## Captured-state custody and actual native regression

The closed original222-file R03 profile was hashed, copied into private local
storage and hashed again; original bytes and custody metadata were unchanged.
Only the disposable copy was opened, with inert HTML replacing all requests;
the game engine was never loaded during read-only IndexedDB capture. Save,
backup, profile and authority companions remain local and are not committed or
uploaded. The original profile is never opened by these regressions.

The captured save's exact clock is **8853** (Day7 03:33), preserving the actual
saved checkpoint rather than changing it to the UI's approximate03:30. On source
`1fda9e8eca7a4fcddfb4606dd51b5a28152e3c49`, the relevant generator, venue-cycle
and hours code matches served NEXT
`4b5390c9243be703ae90d97a076d31f0bf8c0754`. Normal native Host Continue, Map,
Motel selection and one confirmation reproduce the exact rejection with one
install attempt. Complete serialized-run equality proves no cash, clock, RNG,
room, map or receipt change. The baseline has one intentional failing assertion:
the expected trip does not succeed.

With the correction, the same captured inputs pass **34 assertions**. One normal
Host confirmation succeeds on its first install without suppression/retry;
cash48 becomes45, clock8853 becomes8877 (03:57), Heat stays1, and no route risk
triggers. Exactly one accepted travel receipt records the3 fare. Inventory,
debt, Crew state and prior non-travel story outcomes are retained. The closed
Motel has populated strict room controls, no old scenario projection, and a
working public Leave opening Map without time or settlement. Repeated room
publication and official Save/fresh-SaveService Continue preserve the guarded
state and complete cycle history.

The regression freezes continuous clock observation, uses1280x720 and isolated
storage, and performs no player outcome, route, scenario or clock substitutions.
Persistence comparison uses complete JSON wire values for its guarded snapshot,
cycle history and machine hashes; no numeric tolerances or gameplay-field
exceptions are introduced. These are rendered native Host/API actions, not
visual Web input.

Local receipts are under
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/`:
`motel-r03-682-snapshot-custody.json`,
`motel-r03-682-capture-custody.json`,
`motel-seed-before-result.json`, and
`motel-seed-identity-final-{warm,cold}-result.json`, with matching Job receipts and logs.
The maintained local `run_motel_pair.ps1` reuses the existing bounded runner,
the captured bundle and the same isolated storage for warm and independent cold
processes. Product regression entry point:

```text
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/motel_seed_captured_travel_check.gd
```

The independent native process passes **11 assertions**, restoring45 cash,
Heat1, clock8877 and no primary Motel scenario. Every guarded value, complete
cycle history and machine fingerprint matches the warm saved expectation, with
zero recursive differences and no extra trip.

## Primed-room boundaries and rejection controls

`scripts/tests/scenario_venue_cycle_primed_check.gd` passes **85 assertions**.
This separately generated, pinned Motel fixture executes one real authenticated
Wedding command, leaves normally, and uses ordinary clock APIs on disposable
siblings. It explicitly primes the town before lazy destination refresh.

- At02:29, the same active Wedding room and accepted command remain intact.
- At02:30 and03:30, the existing authenticated room retires once and the strict
  destination join accepts no primary scenario.
- At04:00, a new cycle is selected once. Reselecting the same scenario ID is
  allowed; cycle identity and retirement history establish the distinction.
- Protected source state, paid machine state, accepted command history and
  repeated-refresh idempotence pass. Active no-primary rooms remain valid.
- The exposed current body overrides its stale stored layer mirror; retained
  scenario state on another layer prevents the closed fast path.
- A forged active-cycle seed still rejects with the exact seeded-definition
  mismatch. A forged old command fingerprint cannot be retired or re-signed;
  exact envelope/unauthenticated-entry errors remain. The complete raw serialized
  run and stored room are unchanged on rejection.
- Present-but-blank identity and missing explicit/legacy identity controls both
  retain the old runtime as input and reject with the exact identity error. Full
  raw run fingerprints remain equal, with no recursive differences. A valid
  missing-key legacy fallback remains available in the source contract.

The fixture's ordinary Day6-to-Day7 advance produces a new rival cast without
two neutral persisted defaults (`last_heat_gain` and `last_heat_action`). It uses
the existing production rival normalizer before taking negative snapshots,
matching official loaded-save shape. Both defaults are0; no existing value or
comparison field is dropped. Early setup/diagnostic failures are retained in
local receipts and are not counted as passes. Final evidence:
`evidence/motel-primed-identity-qualified-final-result.json`, `.json` Job receipt and `.log`.
This is generator-only synthetic qualification, not Host fare or Web input.

Total focused qualification: **34 captured warm + 11 captured process-cold +
85 synthetic = 130 passing assertions** on the final source. The earlier118
and124-assertion stages remain historical evidence. Independent review of the
captured driver found no original-write or scope issue; the additional malformed
identity rejection controls drove the final retirement safeguard. All qualified native jobs use
the existing5% CPU /2GiB kill-on-close containment, exit0 without timeout and
leave zero owned processes. Root-certificate-store diagnostics from the native
sandbox are retained; no network/trust change was used to obtain a test pass.

## Release status

Implementation: [`0adf3925fc3d816ea818e84a9afa41b29acf8c29`](https://github.com/erikjpet/BeatTheHouse/commit/0adf3925fc3d816ea818e84a9afa41b29acf8c29).
The stable task stays Open until exact NEXT identity/basic startup is verified.
No original-save handoff is needed: the
captured original profile and no-charge evidence are already preserved, and
tests use disposable copies only. Stable/itch and the hosting audience remain
outside this change.
