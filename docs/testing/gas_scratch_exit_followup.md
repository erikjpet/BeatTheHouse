# BTH-GAS-SCRATCHER-EXIT-001 — Gas Casino objects after Scratchers

Owner: task-14. Status: Open; investigation only, no fix commit or acceptance.

The reported failure is that Gas Casino objects disappear after leaving
Scratchers. Original failure clock/control state and save identity are not
established. The separate unavailable Day 1 16:30 / $117 state remains BTH-09;
this investigation will not substitute a different campaign as its original.

The named queue and current assignments were checked before selecting this
task. Its previous owner is assigned to BTH-VIDEO-POKER-OPENING-COLD-001; Broad QA
is continuing the independent R04 gameplay track, the nudge worker is reviewing
its private budget validator, and the audit worker owns tutorial/validator
qualification. No active worker owns this implementation. Item and scenario
development remain outside scope. No original save, profile or key is accessed.

Starting source: `79ace22c2e508134c3ab4c5698b14426688ab6f6`.

## Preserved prior evidence

`2026-10-23/task-2/evidence/gas-scenario-87a-r3.json` and `.log` record ten passing
private native checks. The room was usable before/after a noon Scratchers exit.
The diagnostic then directly changed the fixture clock to 02:30 and 04:00;
the authored Graveyard scenario was absent during its gap while authority and
ten room controls remained valid, then became available again. These clock edits
do not prove a normal action crossing that boundary or explain the reported
disappearance. The existing scratch-scalper runtime-membership fix is separately
documented in `scratch_scalper_runtime_compatibility.md`; it does not attribute
this original empty-room report.

The prior diagnostic's historical checkout identifies source
`87a06b9a4acbe86b0f761d2cd0ab929f5584b716`; its worktree cleanliness was not
verified. Diagnostic SHA-256 is
`91918d42d87d5310fd152c2781291c85567ab38222d8028c7234b9468ea1f628`.
The runner receipt and log hashes are respectively
`5b0ac1b3a7c94a5b1f45489c59e7853ea37cd7c00e1dca4b3a155dcb5ea823a0`
and `52c644c73a61165a2055dc0ab129eeaede2fd192e2279651e7b7d7b5b3890b45`.
The diagnostic freezes host processing and continuous clock, asserts only a
positive control count, and performs no paid action, Save/Continue or Leave
click. Personal Context retrieval was unavailable; no additional original
incident detail was recovered.

## Current source boundary

Buy and File advance action/simulation turns, but do not advance
`game_clock_minutes`; Collect and Scratch All also do not advance that clock.
Continuous host time can refresh a venue cycle while the machine is open.
Back then clears the game binding, queues a room publication check and rebuilds
room presentation. The existing late-scalper test deliberately excludes a restock
intersection and freezes continuous time. The new independent fixture will use
ordinary host Buy/Collect/Scratch/File controls and briefly enable the real host
clock while inside the machine, recording the observed crossing rather than
directly changing the installed run clock.

Next: trace the actual Scratchers Back/time/publication path, reconstruct a
bounded independent case using normal actions, and distinguish legitimate
content availability from a rejected or stale room projection. Preserve the
item as Open unless a fix commit and its required acceptance support closure.
