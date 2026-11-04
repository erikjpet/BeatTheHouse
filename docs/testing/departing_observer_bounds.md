# DEPARTING_OBSERVER_CLIP — departing observer bounds

Owner: task-14. Status: Open; no fix commit or acceptance yet.

The preserved primary observation is the independent QA-VIS-020 receipt at
`2026-10-26/task/evidence/qa-vis020-independent-recheck-7cdd082e.json`, build
`7cdd082ea5e95c51cff4ebc5ad1e4a7172e5eef9`. At 1280×720, the ordinary Motel
Stakeout response **Occupant warned** began observer departures. Screenshot
`qa-batch-335-vis020-warm/03-one-warning-immediate-warm-actor-departure.png`
shows South observer clipped at the bottom edge, with its label near Leave.
Screenshot `04-warm-after-12s-no-input-departure-wait.png` shows both departing
observers gone. The earlier `3d843dfe`/`7cdd082e` repair covered settled actor
coordinates and explicitly excluded transient clipping. Original evidence remains
in place; no campaign save, profile or authority key was read or copied here.

The canonical named queue and current worker assignments were checked before
taking ownership. No other worker owned this implementation. Items and scenario
content remain outside this task. `BTH061-PULLTABS-SAVE-001` remains Open with its
original observation, existing fix commits and attribution limitation preserved.

## Current investigation

Baseline source is `474855071a618f8272fb86d2b8f03b2b678c2c3b`. The shared person
transit functions still match the historical affected build. A departure reverses
the authored entrance path and finishes at the priority exit rectangle's center,
without accounting for the moving body's size. Small-screen size selection and
slotted scaling then feed the natural-model rectangle used by the body painter.
The existing Motel test classifies departing observers and advances past their
deadline; it does not sample containment during their movement.

The focused new test reconstructs shipped Motel observer and exit geometry in a
synthetic Canvas snapshot. It uses private missing placement-overlay paths and
does not create a run, load a save, choose a scenario outcome, or change game
clock, RNG, economy or authored data. This is a renderer regression, not a replay
of the historical player's scenario.

Evidence receipts are retained under task-14 `evidence/`. The initial
`departure-bounds-red` run exited before reproduction because its shared-slot
fixture did not select the genuine observer footprints; it is a fixture failure,
not evidence of clipping. The corrected fixture selects the same shipped local
observer slots as the existing Motel binding test. `departure-bounds-red2`
reproduced four natural-model containment failures on unchanged production code:
both observers in normal and small-screen modes. North first escaped at 7.204
seconds normally and 7.0 seconds in small-screen mode; South at 2.085 and 1.8
seconds respectively. Both retained their full size. This supports the departure
endpoint/body-size mismatch.

## Scoped correction and acceptance

The production change adds a transient-only wrapper around natural-model
geometry. After all existing small-screen selection and slot scaling, it rigidly
translates an active person's displayed rectangle inside the existing 16-pixel
layout inset. It does not intersect/crop or resize that rectangle, alter a static
object, change authored routes, or modify processing, duration or disappearance.
For the reported single 72×80 observers, the largest generated hand/sway extension
is less than 10 pixels outside their rectangle; the feet shadow extends 5 pixels
below it. The inset covers these extensions without changing idle animation.

`departure-bounds-green` passed all 533 checks, including normal/small-screen and
reduced-motion variants, 128 sampled moving-actor rectangles, size, movement,
noninteractive transit, original deadlines, Leave preservation and immutable
input snapshots. `departure-semantics` passed the existing person/package test;
`departure-liveness` passed the existing no-pointer environment/placement/game
animation check. These capped native jobs exited normally with zero owned
processes remaining. The expanded `departure-bounds-painter` run passed 801
checks. Its four probes performed 128 calls through the real procedural character
painter at maximum member scale 0.7992: idle, stretch, head scratch and shoulder
roll with both gesture sides and the generated sway/bob extrema. Recorded draw
primitive extents include line widths; the separate feet-shadow allowance also
stays inside the board. These are synthetic primitive bounds, not raster pixels.

Focused test commands (Godot 4.6 stable official `89cea1439`):

```text
godot --headless --path . --script res://scripts/tests/person_departure_bounds_check.gd
godot --headless --path . --script res://scripts/tests/person_departure_semantics_check.gd
godot --headless --path . --script res://scripts/tests/animation_liveness_without_pointer_check.gd
```

The bounds test requires a fresh missing absolute `BTH_DEVELOPER_PLACEMENT_PATH`
and no `BTH_PROJECT_PLACEMENT_PATH`. Native receipts record the actual executable,
private storage, 3% aggregate CPU / 2 GiB cap, assignment before execution, timeout,
exit code and owned-process cleanup.

`departure-raster2` passed: eight offscreen native OpenGL captures, normal/small
mode at 1280×720 and 640×480, with each observer sampled 0.01 presentation seconds
before its own deadline. Representative inspected frames show the body and feet
shadow inside the room edge. The fixture uses a synthetic maximum-scale coat
character, shipped geometry and an explicitly sampled presentation clock. This
is native raster evidence, not an ordinary scenario replay, real-time timing
measurement or Web playtest. Processing stays enabled; the separate production
liveness test qualifies autonomous scheduling. The earlier `departure-raster`
receipt is a retained capture-script parse failure, corrected before this pass.
Both runs released all owned processes; no capture failure is counted as a pass.

The independent production diff review found no material blocker. Acceptance is
for the observed body/shadow edge clipping; the existing label resolver can still
permit crowding and this task does not certify zero label overlap near Leave.
The change is not a universal bounds guarantee for hypothetical oversized or
unusually narrow multi-person layouts.
