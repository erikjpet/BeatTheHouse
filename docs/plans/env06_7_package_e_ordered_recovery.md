# env06_7 Package E ordered recovery

Status: WIP, unreviewed, and awaiting the serialized Godot verification lane.

This candidate is based exactly on ordered Package A+B+C+D recovery `db2b14b`.
It recovers the accepted eight-scenario Package E payload and its 80 individual
rasters plus contact sheet through `08ff8e8a`, without using that branch as the
implementation base.

The recovery preserves the existing package catalog order and makes no catalog,
loader, dispatch-registry, or package-order edit. The already-registered
`queen_public` extension receives the same bounded pass-through handler and
shared semantic-layout renderer used by Packages A through D.

Delta Queen and Grand Casino now each publish the seven canonical semantic
zones declared by every Package E sequence: `left`, `right`, `center`,
`background`, `service_lane`, `foreground`, and `exit_lane`. Their bounds reuse
the established env06_7 assembly envelopes already present on ordered Packages
C and D. No game, travel, boss, duel, invite, audit-secret, or heist authority
is added. Grand Casino's three existing room targets remain owned by its
pre-existing archetypes and are not copied into Package E.

The focused contract composes the real `delta_queen` or `grand_casino` through
`ContentLibrary` and `EnvironmentInstance`, seals it with
`EnvironmentSemanticInventory`, and bounds all seven declared zones to the
exact production collection. It also loads the combined catalog and checks
that all eight identities are claimed once by `env06_7_queen_public`.

Evidence inventory:

- 8 scenario IDs × 10 required state suffixes = 80 PNG captures;
- 1 contact sheet, 960×2700;
- every committed SHA-256 matches the recovered manifest;
- all 81 manifest paths are repository-relative in this ordered candidate;
- the historical native/Web semantic SHA-256 remains
  `0c068a6431e1486850d6087cd713c0baec3b3cf909a8d5a6126f23d184a47683`.

No Godot command has been run in this worktree. Production composition,
signature regeneration, the focused contract, and the integrated project gate
remain pending the Warden-owned slot.
