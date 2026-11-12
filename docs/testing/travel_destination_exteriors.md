# Eight-second layered travel and grounded doorway entry

Historical review media: MP4 names and `review_artifacts/` references below identify external feature-review deliverables from the source branch, not files shipped in main. Their recorded hashes remain custody evidence. See `travel_main_integration.md` for the integrated source and qualification.

Current branch-only revision, November 12, 2026, on
`feature/back-alley-bar-travel-poc`. No push, main merge, NEXT release or
deployment is included. This supersedes the previous separate ground-plane
cleanup, ten-second layered review, and earlier 12-second/generic-street prototypes.

## Shared structure

All fifteen destinations have two replaceable images: an RGBA main containing
the facade/destination, entrance/path and extended clear arrival ground painted
together; and a separate opaque far-city/background visible through real sky
and gaps. There is no separate road strip, stretched facade, foreground ground
band or prop mask. Walking, bus, taxi and night cab use the same close crop.

The map still selects actual modes. `night_cab` is distance-based, not selected
by time of day. Lighting follows frozen departure time. Catalog previews do
not create routes, prices, incidents, locks or consequences.

- `travel_presentation_catalog.gd`: assets, measured geometry, framing, static
  scene scale, frozen labels and mode profiles.
- `travel_cinematic_overlay.gd`: one shared title/details, hidden narration,
  progress, Skip, receipt, Continue, accessibility, focus and input ownership.
- `travel_arrival_timeline.gd`: pure choreography, no RunState or RNG access.
- `travel_scene_cutout.gdshader`: non-destructive PNG alpha compositing.
- `travel_vehicle_view.gd`: measured source-textured wheels and passenger doors.
  `bus_driving_sprite.gd` remains a compatibility wrapper.
- `travel_entrance_view.gd`: measured source-textured back/front entrance around
  the canonical avatar, including portal clipping.
- `foundation_main.gd`: unchanged settlement and frame-staged destination prep.
- `data/art/art_manifest.json`: registry; small art contracts own measurements.

## Framing and replaceable geometry

The 1280x720 design uses a 1152x500 stage at `(64,116)`. Every mode uses source
width **0.80**, bottom **1.0**, height `0.80 * actual_aspect * 500 / 1152`
(capped at 0.95). Current 2:1 mains have height 0.694444, top 0.305556. Landmarks may
extend beyond this intentionally close pan; entrance/sign/path remain readable.

One continuously advancing camera drives main and actors even during stops
and door pauses. Main camera ends at U=0.18. Far backdrop moves at **35%** of
main speed, never independently stopping. Its crop uses its actual aspect and
measured/default top. `layer_window_snapshot()` exposes `main` and `backdrop`;
legacy `foreground`/`background` aliases refer to those same windows.

Far backdrop draws first. A retained AtlasTexture/TextureRect draws the main
above it and below vehicle/entrance/avatar. Nothing broadly masks feet/wheels.
Exact generated PNG bytes stay untouched. The cutout shader makes alpha <=2/255
clear and paint >=0.80 opaque for main/entrances; vehicles use 0.95. Other soft
edge/shadow coverage stays transparent. This is compositing, not raster editing.

Exterior coordinates are full-image UVs. `texture`, `reference_size`, threshold,
inside/path endpoint, road baseline, arrival kind and door polygon describe
actual pixels. Layered scenes require `layered_scene=true`, `backdrop_texture`;
optional `backdrop_reference_size` records native differences. Container versions
1 and 2 are supported. `road_y_uv` is clear foot/wheel ground, usually 0.947-0.95,
not a requirement for public asphalt. Outdoors `inside_uv` is a farther visible
endpoint. Optional `approach_waypoint_uv` follows a garden/courtyard bend.

Door arrivals require measured finite simple leaf polygons, hinge side and
`hinged`/`double_hinged` geometry. Vehicle door/panel/hinge/wheel UVs instead
refer to the tight `source_px` rectangle within actual `reference_size` (bus
calls it `bus_source_px`). Never mix these coordinate spaces. Missing/invalid
required art fails closed to the committed static receipt.

## Vehicles, avatar and choreography

Detailed pixel-art vehicle native sizes and measured tight crops:
- Bus, 1774x887: `[16,196,1743,555]`.
- Taxi, 2172x724: `[132,22,1908,701]`.
- Night cab, 1774x887: `[15,166,1745,627]`.

Bus folds two source-textured leaves; car rear passenger doors swing around
their measured hinges. Glass/handles/trim remain on the panels. Closed vehicles
retain their original texture. Wheels rotate from world distance/radius and
stop at the stop; restrained suspension shares motion. Bus wheel discs exclude
irregular alpha edges. No PNG is cut up or repainted at runtime.

Base vehicle widths are bus 0.48/car 0.34 world U, multiplied by one static
door-derived scene scale clamped 1.0-1.4. Indoor avatar height is
`min(0.20 * scene_scale, measured_leaf_height * 0.82)`; outdoors it remains 0.20.
This fitted height is established before the scene starts and leaves headroom
for all supported canonical model scales, not just the default. Timeline scale
stays **1.0 throughout exit, approach and door entry**. There is no exit growth
or door-entry shrink. Only outdoor walk-away recedes to 0.58. Door leaves and
portal clipping occlude normal-sized entry, not an alpha disappearance.

Actual `CharacterAppearanceSnapshot`/`CharacterAvatarView` reuse
`TableGameVisuals._draw_table_character` including back-facing walk/idle. There
is no generated player. RunState has no persisted player-creator model or general
wearable slots, so production uses the canonical default player. Supplied
snapshot limits are in [player_character_presentation.md](player_character_presentation.md).
No creator, inventory UI, equipment or save fields are added.

Eight-second shared timeline:
- 0.0-1.45 approach/stop; 1.45-1.80 open actual passenger door.
- 1.80-2.50 step out; 2.50-2.75 close passenger door.
- 2.75-4.45 accelerate away with wheel/suspension animation. Player approaches
  as soon as rear clears its curb point by 0.02 world U.
- Clearance-6.15 measured threshold approach. Walk transits 0.0-3.30 first.
- 6.15-6.65 open building door; 6.65-7.25 enter; 7.25-7.90 close leaf in front
  of actor; 7.90-8.0 brief hold then receipt.

Path segments receive time proportional to length. Back Alley, Beach and Delta
Queen instead walk away along passage, sand or gangway 6.15-7.90, face away and
remain visible through the hold. Progress measures physical traveled distance
through transport/drop-off/approach/entry; pauses while waiting/opening. Final 2%
of door arrivals tracks actual closure. It is not elapsed-time or load progress.

Delta Queen has a measured boarding-clearance rectangle at source pixels
`[1320,533,92,59]`, with its floor at y592 matching the authored far foot
anchor. This is the existing painted boat opening, not an added door or room.
Catalog derives a far perspective scale of about 0.272717 from 82% of its height.
A ground-Y projection derives the near-gangway scale (about 0.656): the player
recedes continuously while approaching from the quay, then shrinks gradually
along the bridge to fit the actual opening. Exit, curb wait and sideways
transit keep full size; no scale jump occurs at the gangway boundary. Other
open/passage arrivals retain their authored default 0.58 far scale.

Walking uses the comfortable 1.10 base cadence with deterministic bounded
cadence variation (within 6% of that base) and amplitude 0.88-1.0, rather than an
identical short loop. Integrated phase remains continuous across beats/turns
and freezes while stopped; actual motion time remains separately available.
Travel supplies an opt-in locomotion snapshot to the shared avatar: 0.18s start
blend and 0.20s stopping followthrough. The final outdoor stop settles within
the remaining 0.10s, retaining the eight-second duration. Arms interpolate to
the actual idle pose through the existing painter's gesture blend; legs and
hip settle smoothly too. An independent idle clock avoids switching clock
sources at a pose boundary. Empty-snapshot legacy drawing is unchanged, and
`TableGameVisuals` itself is untouched. The canonical renderer faces back
on each genuine negative-Y/depthward path segment and entry, but remains
front-facing during horizontal sideways transit and stepping toward the viewer.
Direction follows the active authored segment, including a bend in a driveway.

Vehicle suspension is reduced from 1.5 to at most 1.15 logical pixels, restoring
noticeable motion after the superseded 0.45 setting was largely subpixel. It uses
a weighted sum of differently phased time-based waves under the moving envelope,
not wheel angle or radius. It stops completely while parked and uses no RNG.
Wheel rotation still comes from actual distance divided by measured radius.
At the production 500px stage, measured body displacement peaks 1.315px; actual
GPU roof pixels move bus 1px, taxi 1px and night cab 2px with fixed ground wheels.

Door entry uses the actual leaf's bottom as the inside foot endpoint. The prior
forced `threshold.y - 0.055 * scene_scale` lift is removed. Feet traverse only
the shallow measured doorstep-to-sill rise, never halfway up the door. The same
fitted character height is used for vehicle exit, approach and entry.

## Doorway interior graphics

All twelve indoor destinations have distinct opaque room glimpses under
`assets/art/travel/doorways/<id>.png`, mapped by `doorway_texture` and actual
`doorway_reference_size` in their existing exterior contracts. The back entrance
layer draws this art inside the measured polygon, behind the player and actual
source-textured door leaf. A center-X/bottom-Y aspect-preserving cover crop keeps
the interior floor aligned to the sill without stretching or aperture spill.
Closed doors retain the original exterior pixels. Required missing/mismatched
art falls back to the committed receipt. Direct renderer callers retain the
optional-color fallback for old contracts; current indoor profiles require art.

- Bar: bottles/counter/stools; Store: shelves/fridge; Gas Casino: converted
  station slot room; Punchline: comedy stage/microphone/tables, no casino.
- House: modest living room; Apartment: communal stairs/mail cubbies;
  Motel: reception/key cubbies; Motel Room: guest bed and lamp.
- Pawn: glass cases/shelves/instruments; Jazz: supper tables and music stage;
  Grand: elegant casino foyer; Kitty Cat: pink/gold lounge.

Nine are native 1024x1536 RGB, Pawn is 1086x1448, and the Grand/Kitty pair is
1536x1024. All are opaque exact
generated PNG bytes, without raster editing. Actual dimensions control runtime
cover crop. Full prompts/hashes are in the three `*_doorways_generation.md`
files beside the PNGs. Back Alley, Beach and Delta Queen have no invented door
or interior asset. These glimpses do not add gameplay rooms or layout claims.

## Vehicle cabin graphics

Bus, taxi and night cab also have distinct opaque images in
`assets/art/travel/vehicle_interiors/`, not a flat gray cabin or step fill:

- Bus: native 1024x1536 RGB, amber cabin lamps, yellow/teal rails, plum seat
  backs and three ribbed entrance steps.
- Taxi: native 1254x1254 RGB, warm rear bench, headrest, door trim and rubber
  footwell. Night cab: native 1254x1254 RGB, quilted plum leather, cyan/magenta
  ambient trim and carpeted footwell.

The bus contract uses `bus_interior_texture`/`bus_interior_reference_size`;
cars use `interior_texture`/`interior_reference_size`. Catalog normalizes both
to the latter pair. Overlay requires the actual loaded size to match metadata;
missing/mismatched production cabins fall back to the committed receipt.

`TravelVehicleView.configure` accepts an optional sixth Texture2D. It draws the
image only while opening, center-X/bottom-Y cover-cropped within the measured
passenger aperture. Actual folding/hinged source-textured leaves remain above
the cabin; floor and steps are textured too. Closed sprites are unchanged.
Older four/five-argument direct callers retain their color fallback, which is
not used by current production profiles. All three PNGs are exact generated
opaque RGB bytes; full prompts/hashes are in `vehicle_interiors/generation.md`.

## Destination inventory and provenance

Each ID has `assets/art/travel/exteriors/<id>.png` and matching
`assets/art/travel/backdrops/<id>.png`:
- Urban: corner_store, bar, gas_station_casino, small_underground_casino,
 pawn_shop. Street shops, GAS pumps/forecourt and Punchline comedy frontage.
- Residential/music: apartment, house, motel, motel_room, jazz_club. Walkup
 courtyard, garden/driveway, motel courtyard and music frontage.
- Landmark/outdoor: back_alley, beach, delta_queen, grand_casino,
 kitty_cat_lounge. Passage, coast, waterfront/quay, fountain forecourt and lounge.

Each has distinct corresponding far surroundings. `punchline_club` aliases
`small_underground_casino`, not a sixteenth exterior. DELTA QUEEN and GAS signs
match public names. Already frozen receipt strings remain historical.

Mains: 1774x887 RGBA. Opaque RGB backdrops: Back Alley 1774x886,
Punchline 1773x887, others 1774x887. 2048x1024 is a preferred replacement target,
not a claim about actual bytes. Contracts are
`data/art/travel_exteriors_{urban,residential_music,landmark_outdoor}.json`.
Matching `*_generation.md` files beside exteriors record prompts, exact hashes,
alpha findings and measured geometry. Vehicles use
`assets/art/travel/vehicle_detail_generation.md`. All PNGs are exact built-in
image-generation bytes without client-side crop, resize, recolor or recompression.

Old ground-material atlas and generic street/foreground strips remain historical
assets, not current scenery. Replace paired art and measured metadata together;
verify clear ground, alpha gaps, entrance, road and path on actual pixels.
Reimport guarded and inspect drop-off, approach, open/enter/closed door and
outdoor walk-away in every affected mode. UI remains shared.

## Travel authority and preparation

Main still synchronously generates/settles once: fare, clock, destination,
count, heat, sobriety and route risk. Detached receipt/appearance snapshots
follow. Watch, Skip and Continue cannot charge, move, reroll or settle again.
Continue is journey-ID latched; input, simulation and queued events unchanged.

Destination presentation is spread over six process frames behind the overlay:
room catalog, header/panels, environment model, canvas publication, overlays/music,
publication check, starting after first overlay draw opportunity. Run/environment/
journey/signature latches reject stale work; changed signatures restart prep.
Matching canvas publishes once and is reused at Continue. Autosave waits for
publication. Early Skip/Continue drains unfinished stages. Cancellation clears
prep without acknowledging. Replaced runs/new journeys reject stale callbacks.
Pending receipt reload is static. This is **main-thread frame-staged rendering
preparation, not threaded loading**; synchronous generation remains unchanged.

Schema v2/legacy v1, reduced motion, missing art and unknown future schemas keep
static summaries. Triggered risks keep existing accurate receipt/event/terminal
flows. Local Door/Inside, Grand interior, same-node and meta Begin are excluded.
No incident variations or gameplay changes.

## Verification and review media

Use pinned Godot 4.6 stable 89cea1439 and `tools/bth_qa_guarded_run.py` with fresh
E: paths, 12% CPU, 2 GiB Jobs and cleanup. Final focused checks on this revision:

- Six baselines: **29,616 passed** (arrival timeline 89, standard timeline 432,
  cinematic overlay 852, native standard overlay 27,414, standard integration 711,
  prototype integration 118). State suites cover global/stored RNG, skip,
  repeated input, save/reload and once-only settlement.
- Smooth locomotion: **137 pure + 222 actual GPU checks passed**. Millisecond
  sampling confirms bounded gait variance, no phase reversals/RNG, and gradual
  Delta scaling. The worst primitive change across a 20-microsecond start/stop
  boundary is 0.00226px; 24 rendered boundary pairs change at most one ROI pixel.
  Actual fixed-wheel roof comparisons verify visible suspension for all three
  vehicles. Tallest Delta cap/head clears the opening by 4.46px, soles on sill.
- Eight-second acceptance: **61 pure + 542 native checks passed**, covering
  direction, no-RNG suspension, comfortable gait clocks, and painted head/cap/
  feet bounds for all 12 indoor destinations, four methods and model scales
  0.75/1.0/1.25.
- Character renderer: **502 passed**; receipt compatibility: **231 + 1,504 passed**.
- The native standard-overlay total above includes shader opacity, tiny alpha
  residue, RGB preservation and soft edges. Unchanged doorway graphics retain
  the preceding **76 pure + 137 GPU checks**, including **8,447
  exact interior pixel samples**, zero aperture spill, unchanged closed doors,
  missing-art static fallback and outdoor exclusion. All 12 opening screenshots
  were visually inspected; reviewed files hash-match final evidence.
- Unchanged vehicle cabins retain **30 pure + 109 GPU checks**. Independently verified
  126,094 source RGB samples across isolated and actual production-material
  variants, including textured steps/floor, with zero mismatches or aperture
  spill. Closed sprites are pixel-identical and missing-cabin fallback passes.
  Actual bus/taxi/night-cab openings were also inspected before the player
  appears in the final natural recording.
- Legacy door GPU 365 and bus/wheel GPU 290 checks from the preceding revision
  remain valid for the unchanged vehicle renderer. New suspension is covered
  by the fresh locomotion GPU proof and natural playback.
- Destination preparation: **125 headless**, **129 native natural-watch**,
  all passed. Native watch drew 7,919 frames; four journeys naturally reached
  receipt. Six distinct preparation stages, one canvas publication, early drain,
  repeated Continue, stale generation, cancellation and static reload passed.
- Idle animation liveness: **headless passed**, including placement overlay,
  table characters and low-detail cadence without pointer input. Native GPU
  motion/preparation and the captures also advanced without input.
- Independent read-only review found no remaining substantive defect.
- Separate legal-route matrix: **60,750 assertions passed** over 16 real
  enabled-route fixtures, covering all 15 destinations and all four actual
  methods. Watch/skip/reduced-motion/missing-art, pending reload, once-only
  receipt, RNG and queues retain strict comparisons. Evidence:
  `smooth-integration-20261112-01-destination_travel_integration_check/evidence/destination_travel_report.json`.

Gated fixtures use disclosed progressed throwaway QA state, not fresh starts:
$2,000 bankroll, game clock 1080, four archived environments, existing
underground-tip/Grand-invite flags and discovery of existing map nodes through
the real world API. Beach is reached through Delta Queen and two actual
`riverboat_deck_walk` services, consuming the existing departure lock. No edge,
method, price, risk result or environment installation is replaced.

Final native timing under the 12% CPU cap: preparation ready 241.823-428.940 ms;
Continue call 6.313-10.172 ms; Continue-to-next-render 11.491-17.644 ms.
Gameplay generation/settlement remains synchronous, measured 336.526-2468.638 ms.
Peak post-preparation watch interval was 199.277 ms. These numbers do not prove
hitch-free playback or threaded loading. All listed final verification runs
exited 0, with no active owned process or cleanup error at release.

Evidence roots use `E:/CodexQA/BTH/runs/smooth-<group>-20261112-01-<suite>`;
the corrected native standard-overlay run is `smooth-overlay-gpu-20261112-02`.
The final summary binds all 17 passing QA runs (93,819 reported checks plus
liveness) and 23 media jobs to 128 unchanged local source/art/import/helper
fingerprints. Each guarded run retains storage admission and Job receipts.

Requested review: **Back Alley, Delta Queen, Grand Casino**, each walk/bus/taxi/night cab,
actual production Godot playback. Four chapters per group, 8-second animations
plus 1-second holds. Harness selection:
`travel_catalog_preview.gd -- --review-destinations=back_alley,delta_queen,grand_casino
--review-modes=walk,bus,taxi,night_cab`. Each scene says VISUAL PREVIEW ONLY;
unavailable combinations are synthetic, not journeys. Separate production Main
legal-route tests retain strict state/RNG/queue/receipt/reload coverage for all 15.

All twelve natural preview cases passed **6,942 assertions** (2,314 per
destination group). Each local final MP4 passed full decode, exact frame/time/
chapter metadata, all sixteen decoded visual samples and unchanged source/art
fingerprints. Each is 36 seconds, 1,080 frames, 1280x720 at 30 fps, H.264/yuv420p,
TV range and silent, with four correctly ordered chapters. Files are below 19 MiB:

- `review_artifacts/Smooth_Back_Alley_Four_Modes.mp4`: 8,673,451 bytes.
  SHA-256 `847bcebd61e6b651420aa1c3d9b82bd9848b5866dbed830a6606d933e19181bd`.
- `review_artifacts/Smooth_Delta_Queen_Four_Modes.mp4`: 11,358,466 bytes.
  SHA-256 `83a6d2ab6c0bcd053e62ab50ee06743f2ef8e445a7528dc421fc09ce0f710775`.
- `review_artifacts/Smooth_Grand_Casino_Four_Modes.mp4`: 11,271,150 bytes.
  SHA-256 `4c351ea279712d6ff97cb0bbc338f88c8b488e79436aa74d75e0cf92215864fa`.

Reproducibility: `smooth-review-20261112-01-workflow/evidence/`
contains `{bar,house,delta_queen}_delivery.json` plus `source_fingerprints.json`.
Natural Movie Maker runs are the corresponding `-<destination>-native` run
directories; trim/encode/decode/probe/sample jobs have distinct guarded run IDs.
No manual pose advancement or mock playback is used in final MP4s.

The prior `Layered_*_Four_Modes.mp4` and `Cabin_Interior_*_Four_Modes.mp4`
files remain unchanged historical media. They predate current locomotion and
Delta perspective. Earlier pre-cabin eight-second previews are superseded too.

Previous `All_60_Travel_Previews.mp4` and `_Compact.mp4` are retained unchanged
**historical ground-plane media, not current evidence**. SHA-256 respectively:
`26017b378efc46ab7e63b1ae1140832938d55e3ec169c7749b4348659564558f` and
`47ab0057fceb2cbd8704dfeaebb899d67383efb38d2694ed32582e5275941203`.
Earlier sixteen individual clips and 12-second prototypes are historical too.

Exported Web/WASM/browser and full aggregate game regression are not included
in this focused revision. Forced-Web source checks execute in native Godot,
not a browser. Native timing does not establish universally hitch-free playback.
