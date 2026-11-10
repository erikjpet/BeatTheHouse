# Meta showdown choice closeout, 10 November 2026

## Result

The narrow local correction for `BTH061-AUDIT-SHOWDOWN-META-CHOICE-FIX-031` passes **52 warm and 5 separate-process cold assertions**, with no failures. Base source is `2e3b88103d010562788793c17efbcc2f4c91c39b`. Integration and NEXT verification remain pending. The broader item and scenario redesigns remain paused.

## Cause and correction

The walk menu converted a carried Meta Dictionary into its entire text representation, while the action owner required `inventory.has(String)` and String-only removal. Fixing only the token could not fix canonical owner rejection. Crew handoff also retained only a String, which would lose instance/effect identity on return.

- Event choices now use the canonical run-item ID and existing instance-specific label.
- The menu and owner share available-carried eligibility. Reserved, locked and collateral entries stay with their existing owners. A live portable-ticket marker, which cannot be removed, is not offered or falsely accepted.
- Trash removes the selected carried entry and invalidates passive effects. Other same-definition collection instances stay carried.
- Crew escrow retains the complete Dictionary through Save/Continue and restores it exactly once. Existing ordinary String-only handoff saves retain their return path. Failure clears the escrow without returning or duplicating the item.

Persistent collection ownership, item definitions/effects, ordinary pat-down classifications, economy, trash RNG tuning and unrelated item/scenario behavior are unchanged. No save schema/version changes or migration are needed because existing narrative-flag storage retains the additional escrow entry.

## Evidence

A bounded authored-event baseline on unchanged source reached the walk with actual normal Meta producers: 42 controls ran, with 8 failures isolating the offered/canonical Meta rejection and live-ticket false acceptance. Ordinary String action and state setup controls passed. The retained baseline check predates the final storage-number comparison and nonzero passive-effect assertion.

The final check covers canonical offered/direct Meta actions, distinct same-definition instances, nonzero passive effect removal, deterministic trash, repeated/stale/Dictionary-text rejection, all five existing reservation/lock forms, missing Crew eligibility, ticket markers, ordinary String trash/legacy Crew return, lossless escrow, SaveService load, failure cleanup and exactly-once return. Persistent collection ownership is unchanged. Complete instance comparisons retain full float precision through the existing storage numeric JSON contract, allowing its ordinary integer-to-float Variant restoration.

Native commands, each inside the storage-aware capped worker:

```text
godot --headless --path <isolated-worktree> --script res://scripts/tests/showdown_meta_inventory_check.gd
godot --headless --path <isolated-worktree> --script res://scripts/tests/showdown_meta_inventory_check.gd -- --cold
```

Fresh synthetic Save/authority companions were copied and hashed before the first separate-process cold load. No original player state was accessed. All workspace/profile/temp/persistence/evidence writes were admitted on the approved E: root with the unchanged 4 GiB expected-write + 20 GiB reserve. The 8% aggregate CPU/2 GiB kill-on-close Job was assigned before execution, with no breakaway; all owned processes drained to zero, with no timeout or cleanup error.

All 11 available native source/build/toolchain files match the accepted local runtime candidate. Godot is `4.6.stable.official.89cea1439`; the debug plugin SHA-256 is `184bfde4d9697b397f347dc9ab35b8915f59a7d3ca54c8849c7c59914d53f17b`. The JSON companion records exact source/test/log/manifest/custody hashes and commands. `git diff --check` passes. Standalone gdlint is not installed; no full aggregate suite was run.

## Limits

This is explicit authored base-room integration with normal Meta producers, not full journey/scenario selection, original-player reproduction, rendered pointer play or Web acceptance. Return/failure controls exercise the existing state-owner settlement helpers, not a newly played Blackjack duel. Initial wrong-threshold fixture failures, an unresolved Python launcher and an overly strict JSON numeric comparison are preserved as harness diagnostics, not product failures. NEXT identity, served assets and changed behavior must still be verified after integration.
