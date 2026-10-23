# Cage room access regression

The reported Web NEXT symptom was entering “the cage” and seeing “Room
unavailable.” The player's venue, source build, and save were not captured.
This investigation therefore uses a labeled synthetic run, not the player's
state. The catalog has one walkable Cage destination: `grand_casino_cage`,
offered from the Grand Casino Main Floor and High-Limit Room. Scenario count
cages and the Crew's Cage interview are props/beats rather than other Cage
room destinations.

## Reproduction and cause

On source `6137ae7c32e683f4c3805f5abacd8e2c054fb1c1`, start seed
`CAGE-ACCESS-REPRO`, prepare the Grand Casino through the production generator,
and set Rook trust to the existing Marker threshold (10). Select the offered
Cage door and confirm through FoundationMain's normal travel APIs.

`CrewRecruitmentModel.apply_to_environment` adds `recruitment_bishop` because
the Crew path has begun and the Cage is his authored fallback meeting place.
The Cage placement map had an empty `event_slots` bank. Generation returned
success despite this precise placement error:

```
environment layout grand_casino_cage has no free compatible authored
event.standing_person slot for event:recruitment_bishop
```

The renderer correctly rejected the incomplete slot envelope; no interactions
were published and the room-publication safeguard entered recovery. With no
Crew progression, the same route was populated and did not trigger recovery.

## Correction

- Author Bishop's exact standing-person event slot beside the Cage window.
  Preserve his recruitment conditions, stock, counter, ATM, Linda and exits.
- Authenticate cached room archetype/node identity before reusing it. Accept
  unambiguous older self-named subroom nodes, then restore the shared Grand node.
  Reject a mismatched cached room without overwriting its contents.
- Require physical manifest/slot authority before reporting interior arrival
  success, including rooms without a scenario. Require the Cage's authored
  destination list, counter, ATM and Main Floor exit. Preserve specific failure
  diagnostics and the existing travel rollback.

## Focused checks

Run with the pinned Godot 4.6 runtime, Dummy audio and a disposable user root:

```
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/cage_room_access_contract.gd
godot --headless --audio-driver Dummy --path . --script res://scripts/tests/cage_room_access_contract.gd -- --cold
```

The first process checks Main Floor → Cage → Main Floor → card-eligible
High-Limit → Cage, populated strict-authority room objects, stable gift stock,
the existing cash/card and Rourke locks, unknown/cross-room identifiers,
inconsistent saved exit definitions, legacy subroom node identity, damaged
binding rejection, and normal Save. A separate process uses normal Continue,
checks cash/chips/RNG/clock/stock/Crew progression, and exits to Main Floor.
The fixture root is `user://cage_room_access_contract`; it never reads a live
player profile. Native passing output is `CAGE_ROOM_ACCESS_CONTRACT PASS`.

Runtime evidence is kept outside the repository in this task's `evidence/`
directory. The task-owned runner uses the maintained private Windows Job
helpers, a 5% aggregate CPU hard cap, 2 GiB job memory, a finite deadline,
Dummy audio, and zero owned processes at release. Engine startup emits a
sandbox certificate-store diagnostic; the checks make no TLS requests or
security-setting changes.

These checks establish this reproducible Grand Casino defect. They do not
attribute an unseen player save to it or certify unrelated gameplay.
