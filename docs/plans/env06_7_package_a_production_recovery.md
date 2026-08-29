# env06_7 Package A production recovery

Status: WIP, unreviewed, and awaiting the serialized Godot verification lane.

This candidate starts at exact main `040c0603` and recovers the net Package A
payload whose last product commit was `db8abbd1`. It preserves the accepted
Corner Store Delivery Day definition and restores the other eleven Shops and
Streets scenario definitions without rebuilding their authored mechanics.

The old package checker used a synthetic target inventory. This recovery binds
each new definition to an environment composed through `ContentLibrary`,
`EnvironmentInstance`, and `EnvironmentSemanticInventory`, then validates the
declared targets against that sealed production inventory.

Back Alley and Pawn Shop were missing semantic geometry required by their
recovered definitions. Their zones reuse the established Corner Store semantic
envelopes, and every anchor position is an existing point in the corresponding
production archetype layout. No new world coordinates, generic `work_N`
targets, or scenario mechanics were invented.

Static recovery checks parse both edited JSON files and reject whitespace
errors. No Godot command has been run in this worktree; runtime and project-gate
claims remain pending the Warden-owned verification slot.
