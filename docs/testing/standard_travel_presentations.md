# Standard travel presentations

Historical review media: MP4 names and `review_artifacts/` references below identify external feature-review deliverables from the source branch, not files shipped in main. Their recorded hashes remain custody evidence. See `travel_main_integration.md` for the integrated source and qualification.

**Historical revision, superseded on November 11, 2026.** The current contract
is [Destination travel exteriors](travel_destination_exteriors.md): fifteen
destination-specific settings, a 12-second timeline, actual textured vehicle and
building doors, and visible outdoor arrivals. The 8.8-second generic-street
description, open-arrival fade, test counts, 11.7-second movies and hashes below
record the earlier revision only. The four `Standard_*.mp4` files have since been
replaced; use the current document for their filenames and capture coverage.

Implemented on `feature/back-alley-bar-travel-poc` only. Extends the approved
Back Alley -> Bar proof of concept to all four existing routine world-travel
modes: walk, bus, taxi, and night_cab. No main merge, push, NEXT deployment,
incident variation, or gameplay adjustment is included.

## Common structure

There is one `TravelCinematicOverlay` for layout, text styles, title/details,
caption, progress, Skip, receipt scrolling, Continue, focus, accessibility,
input ownership, and completion. Every mode reuses the same Control instances.
A future UI change is made once in this overlay.

`TravelPresentationCatalog` supplies route-neutral mode profiles: assets,
captions, actual frozen venue names, vehicle geometry, and doorway/open arrival.
It is the place to change mode-specific copy or destination entrance mappings.
Malformed/missing vehicle contracts fail closed to the static committed receipt.

`TravelArrivalTimeline.sample(seconds, mode, profile)` is the shared pure
choreography contract. Every mode lasts 8.8 seconds and uses the same continuously
advancing camera, with foreground distance at 1.08 times background distance.
Neither scenery layer independently stops or clamps. All actors use the
background world coordinate frame; the foreground alone uses parallax.

`TravelVehicleView` is the shared optional vehicle renderer. Bus, taxi, and night
cab use their own PNG and measured source/door/wheel contract. Actual textured
wheel pixels rotate by distance divided by physical radius, while body bob adds
restrained suspension movement. Wheels freeze at the stop. The old
`bus_driving_sprite.gd` is a compatibility wrapper, not a second implementation.

All modes reuse `CharacterAppearanceSnapshot` and `CharacterAvatarView`.
The original generated walking character is not restored. Appearance, accessory,
and persistence limits remain as documented in `player_character_presentation.md`:
the game has no saved player customization or general wearable slots, so current
travel uses the canonical default model. Explicit actual character/equipment
snapshots are supported without inventing equipped state.

## Choreography and destination compatibility

- Walk: a visible uninterrupted pedestrian transit, then approach and arrival.
  No vehicle is drawn.
- Bus: approved stop/open/drop-off/close/departure/approach sequence, now usable
  for any eligible world route rather than only Back Alley -> Bar.
- Taxi: distinct yellow taxi, rear-door drop-off, slower animated departure,
  pedestrian approach, and arrival.
- Night cab: distinct dark neon cab with the same common arrival structure.
  Canonical night_cab is a distance-based game mode, not a time-of-day decision.
  Lighting uses the frozen departure clock independently of transport identity.

For vehicles, approach ends at 1.8 seconds, the door opens through 2.2, drop-off
runs 2.2-3.1, the door closes by 3.4, and departure eases over 3.4-6.0. The player
waits until the vehicle leaves, approaches during 6.0-7.9, and arrives during
7.9-8.5, followed by a short hold and the receipt.

The reusable city kit is generic transit framing, not a claim to reproduce each
venue's facade. Title, captions, receipt, and Continue use actual installed venue
names. The real destination remains rendered behind the scene and is revealed
after acknowledgment. Plausible doorway venues use the shared entrance anchor.
Back Alley, Beach, Riverboat Casino/dock, and unknown destinations use an open
curb anchor and fade, with no masonry-door opening cue.

## Authoritative travel and persistence

The existing WorldMap canonical mode and synchronous `_travel_to` settlement
remain authoritative. Presentation does not quote fare, apply effects, move,
advance game time, or consume RNG. Watching and skipping settle identically.
Continue only acknowledges the matching frozen journey once.

Receipt schema v2 adds bounded actual origin/destination labels and allows
distinct genuine world-node journeys. Existing v1 Back Alley -> Bar receipts
remain supported. Unknown future schemas or visual keys retain static summaries.
Loaded pending receipts do not replay animation or gameplay.

The host freezes world-travel eligibility before canonicalization can turn a
Door/Inside local action into a distance-derived walking mode. Local doors,
Grand interior rooms, same-node moves, and meta Begin transitions are excluded.
Existing triggered route risks retain accurate static receipts and their
existing event/terminal flow. No incident variants are implemented.

Input/simulation ownership, queued events, autosave while the receipt is pending,
static reload, historical-journey labeling, and teardown semantics are unchanged.

## Replaceable placeholders

Shared source layers and viewport remain the approved 2:1 street/foreground kit:
1280x720 design, 1152x370 stage at (64,142), lower street crop with overscan.
Target final replacement scenery is 2048x1024; generated native files are
1774x887. All generated PNG bytes and alpha are preserved without image editing.

- Bus: existing `back_alley_bar/bus_arrival.png`, contract
  `data/art/travel_back_alley_bar.json`.
- Taxi: `standard/taxi.png`, 1774x887 RGBA.
- Night cab: `standard/night_cab.png`, 1774x887 RGBA.
- Car source/door/two-wheel contracts:
  `data/art/travel_standard_vehicles.json`.
- Exact generation prompts, dimensions, anchors, and checksums:
  `assets/art/travel/standard/generation.md`.
- Shared registry: `data/art/art_manifest.json`.

Replace each vehicle PNG and its measured contract together. No scene-specific
UI or gameplay edits are required.

## Verification, November 11, 2026

Pinned Godot 4.6 stable (`89cea1439`), all launched through the repository's
guarded E: QA runner with explicit storage, 12% CPU / 2 GiB Jobs, bounded time,
and clean reconciliation:

- Receipt/save checks: 231; generic receipt matrix/save checks: 1504.
  Runs `standard-receipts-20261111-06`, `standard-receipts-20261111-07`.
- Legacy timeline: 80; standard timeline: 114.
  Runs `standard-timeline-legacy-20261111-02`,
  `standard-timeline-focused-20261111-01`.
- Legacy overlay: 389; standard overlay: 542, including common UI instance reuse,
  all-mode skip/fallbacks, actual source windows, appearances, malformed
  composition contracts, and open/dock arrivals.
  Runs `standard-final-legacy-overlay-20261111-01`,
  `standard-overlay-matrix-20261111-02`.
- Production-host all-mode integration: 631. Watch, skip, reduced motion,
  missing art, forced-Web atomic return, one settlement, RNG/state equivalence,
  actual labels, rejected repeats/routes, real host autosave, static pending
  reload, and real Motel Room -> Motel local-door exclusion.
  Run `standard-final-host-20261111-01`.
- Existing Back Alley -> Bar production-host integration: 89.
  Run `standard-legacy-host-20261111-01`.
- Shared layered vehicle compatibility: 278. No-pointer animation liveness: PASS.
  Runs `standard-final-bus-layer-20261111-01`,
  `standard-final-liveness-20261111-01`.
- Each of four native Movie Maker captures: 350 checks passed, including every
  rendered frame preserving settled gameplay. Actual drop-off, departure,
  pedestrian approach, and entry/open arrival PNGs visually inspected.
  Runs `standard-walk-native-20261111-01`,
  `standard-bus-native-20261111-01`,
  `standard-taxi-native-20261111-01`,
  `standard-night-cab-native-20261111-01`.
- All four encoded MP4s pass complete decoding and metadata probes.
- Scoped static/code/asset review found no blocking issue. `git diff --check`
  passed before commit.

Evidence is under `E:\CodexQA\BTH\runs\<run-id>\evidence`. All runtime saves
are throwaway profiles; no shared player save or other release workspace is used.

The full game regression suite and an exported browser runtime were not run.
The Web check uses the supported forced-Web return-contract switch on source,
not a deployed browser build.

## Actual playback deliverables

All files are under `review_artifacts/`: 11.7 seconds each, 1280x720, 30 fps,
silent fast-start H.264/yuv420p. These are recordings of the production Main host,
real enabled generated routes, normal synchronous transaction, and shared
overlay. No mocked movie scene or synthetic map/route was used.

- `Standard_Walk_Travel.mp4`: Low Tide Bar -> Back Alley, 30 game minutes,
  no fare. Seed `STANDARD-TRAVEL-apartment-0`, legal setup Apartment -> Bar.
  SHA-256 `0da8f74c8d30cbaeb9f1606202ed646ef275a24867ae36bec0af90151251394a`.
- `Standard_Bus_Travel.mp4`: Back Alley -> Neon Store, 24 game minutes, $3.
  Seed `STANDARD-TRAVEL-back_alley-0`.
  SHA-256 `764422d0beab403609dd78962916863fa273802de1993b70789ed2acaa2871dc`.
- `Standard_Taxi_Travel.mp4`: Back Alley -> Sunset Gas Casino, 54 game minutes, $7.
  Same seed, ordinary enabled route.
  SHA-256 `8c1c41a1b4b77f7ef7232b9d523fed9a89f96fbfa59b9462e0b592f6446074d5`.
- `Standard_Night_Cab_Travel.mp4`: Vacancy Motel -> Low Tide Bar, 72 game
  minutes, $8. Same seed, legal setup through Gas Station Casino -> Motel.
  SHA-256 `c4e9954a0f88c1449c231ce7f549b4fc534badfccf34b77a74d0c48292ec0a14`.

Capture entry point:
`standard_travel_integration_check.gd -- --capture-standard --capture-mode=MODE`,
with Godot Movie Maker flags and a fresh guarded run ID. MODE is walk, bus,
taxi, or night_cab. The harness replays verified recipes, checks actual
availability/mode, and falls back to bounded legal-route discovery if needed.
