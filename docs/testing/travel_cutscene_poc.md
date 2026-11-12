# Back Alley to Bar travel prototype

Historical review media: MP4 names and `review_artifacts/` references below identify external feature-review deliverables from the source branch, not files shipped in main. Their recorded hashes remain custody evidence. See `travel_main_integration.md` for the integrated source and qualification.

**Historical first slice, superseded on November 11, 2026.** Current behavior and
replacement contracts are in [Destination travel exteriors](travel_destination_exteriors.md).
The single-route 8.8-second scope, generic street, old door cue and fallback
limitations below are not the current implementation. The original prototype
movie is retained as history, not one of the sixteen current review recordings.

This file records the approved first slice. The subsequent four-mode shared
implementation is documented in [standard_travel_presentations.md](standard_travel_presentations.md).

Branch-only proof of concept based on `Beat_the_House_Travel_Cutscene_Proposal.docx`
(9 November 2026). This revision is on `feature/back-alley-bar-travel-poc` only.
No merge, main/NEXT release, or deployment is included.

## Current scope

- One typical 8.8-second bus-arrival scene for successful Back Alley -> Bar bus
  journeys. Other actual travel methods retain an accurate static receipt.
- Both scenery layers move continuously for the entire scene. One master clock
  drives the background; the foreground samples the same curve at 1.08 times its
  distance. There are no independent layer stops or clamps.
- The bus stops, opens its door, and drops the player at the curb. It then drives
  away over 2.6 seconds with easing, rotating textured wheels, and body suspension
  movement. The player waits until the bus has left, walks to the door, and enters.
- The player uses the existing procedural game character painter, not a generated
  character bitmap. No portrait, inventory-screen, or character-creator work.
- No variants, additional penalties, detours, discounts, or gameplay consequences.
  Existing route-risk resolution remains authoritative and unchanged.

## Sequence and motion contract

1. 0.0-1.8 seconds: bus approaches.
2. 1.8-2.2: bus stops and opens its passenger door.
3. 2.2-3.1: player steps from the doorway onto the curb.
4. 3.1-3.4: bus door closes.
5. 3.4-6.0: bus accelerates away while player waits.
6. 6.0-7.9: player walks to the bar door.
7. 7.9-8.5: door opens and player enters.
8. 8.5-8.8: arrival, followed by the readable committed receipt.

`TravelArrivalTimeline.sample` is pure and owns all motion. Camera drift remains
nonzero even during the stop and arrival hold. Normalized source windows are
0.72 wide; background ends at x=0.22, foreground at x=0.2376, inside overscan.
Actors and the bar door use the background's world frame. The foreground alone
uses the parallax rate. All actor and foreground drawing is clipped to the stage.

`BusDrivingSprite` reuses the bus PNG. It samples the actual tire/rim pixels into
rotating circular wheel layers, keeps wheel positions planted as the body bobs,
and draws a door cue. Wheel angle is driven by actual world distance / wheel
radius and freezes while stopped. It owns no RNG or autonomous clock. The JSON
contract keeps replaceable source, doorway, and wheel geometry separate from code.

## Shared player presentation

`CharacterAppearanceSnapshot` detaches and validates identity/model/equipment
inputs. `CharacterAvatarView` is a transparent reusable Control suitable for a
future inventory consumer. The torso, arms, head, face, silhouette, and accessory
primitives call the same `TableGameVisuals._draw_table_character` used by room
actors and table patrons. The full-body view adds legs and an explicit walk
clock. Existing NPC default draw commands remain unchanged.

The current game has 45 authored character definitions, all supported by the
snapshot adapter. It has no saved player appearance/creation model or general
wearable-equipment slots. Therefore production travel currently uses the shared
painter's canonical default player model. It does not borrow an NPC identity or
infer worn glasses from inventory ownership. Only the actual carried, valid
`active_item_id` is consulted; unsupported visuals are reported by ID.

`from_character(definition, explicit_equipment_definitions)` supports an actual
model and explicit glasses/cap/rings inputs, including the current sunglasses
and poker-hat catalog aliases. A future creator/equipment owner must supply its
real saved selection. This is a reusable rendering seam, not a new equipment or
player-customization system. The canonical painter is front-facing; no new
side/rear directional character art is invented. See
`docs/testing/player_character_presentation.md` for the API and support limits.

## Authority and lifecycle

`FoundationMain._travel_to` still commits synchronously. Fare, clock, destination,
travel count, heat/sobriety, and existing risk settle through the original path.
The legacy `travel_transition_active` flag is clear on return. The presentation
only receives frozen receipt and appearance snapshots, never settlement authority.

A post-commit `travel_presentation_active` owner blocks player travel/actions,
pauses simulation, and holds queued dialogue/events. The destination renders and
is validated behind the opaque cinematic so normal asynchronous autosave can
continue while the scene or receipt is open. No animation await enters the
transaction. The immutable journey receipt is included in normal and optimized
save snapshots, restoration, and rollback.

Skip is immediate and jumps to the receipt. Continue acknowledges only the
matching journey ID and is latched once. Neither can charge, advance time, move,
reroll, or replay travel. Reduced motion, missing layers, unknown presentation
keys, non-bus modes, and loaded pending receipts use static summaries. A receipt
from another destination/count is labeled a previous journey. Teardown releases
UI ownership without silently acknowledging a saved receipt. Existing terminal
outcomes keep their normal flow.

The receipt remains scrollable, scales with existing accessibility settings, and
owns keyboard/controller focus. The tutorial coach is suppressed non-destructively
so it cannot draw above the scene or intercept Skip/Continue. Autosave stays
asynchronous; in-memory commit does not promise a disk generation is durable.

## Replaceable art contract

Registered under `travel_presentations` in `data/art/art_manifest.json`:

- Design canvas: 1280x720; stage: 1152x370 at (64,142).
- Intended replacement scenery: 2048x1024, 2:1. The generated source PNGs are the
  generator's native 1774x887, also exactly 2:1, preserved without image editing.
- `street_strip.png`: opaque street/background.
- `foreground_strip.png`: RGBA curb/reflections/edge posts with a transparent center.
- `bus_arrival.png`: RGBA bus; tight source Rect2(13,216,1749,517).
- `data/art/travel_back_alley_bar.json`: bus source, doorway, and wheel contracts.
- The generated `player_walk_strip.png` from the earlier review is removed. It
  is not loaded or used. Generated actor provenance is retained as history in
  `assets/art/travel/back_alley_bar/bus_walk_generation.md`.
- Receipt/UI, progress, door cues, and day/night tint remain code-owned layers.

Replace scenery with matching 2:1 layers, and update bus source/door/wheel geometry
when replacing bus art. No resolver or gameplay change is needed. Source venue
references were the actual Back Alley and Bar art: deep purple/black, restrained
cyan/magenta/yellow, chunky geometric pixel detail.

## Generation prompts

Built-in image generation was used for the scenery files and new actor layers. The exact returned PNG bytes
were saved, preserving foreground alpha. No API/CLI fallback was used.

### Street

Use case: stylized-concept
Asset type: one opaque PNG background layer for a 2D side-scrolling game travel animation. Target canvas is exactly 2048 x 1024 pixels, aspect ratio 2:1.
Primary request: A continuous street-level SIDE VIEW environment connecting a back alley on the LEFT to a modest neighborhood bar exterior on the RIGHT. Make a single wide uninterrupted scene that can pan horizontally behind a 1120 x 448 viewport.
Style: very simple dark neon lo-fi PIXEL ART, crisp chunky rectangular pixels, flat geometric silhouettes, deliberately low detail, limited deep purple/black palette and a few sharp cyan, magenta and yellow accents. Straight blocky brickwork, hard pixel edges, no smooth painterly rendering. Inspired by a small old-school game in which outlines are thin cyan/magenta rectangles, bricks are large deep purple horizontal blocks, with tiny yellow warm lights. Not realism, not cinematic illustration, no lush detail.
Composition: street-side elevation, camera perpendicular to building facades. The left half is deep-purple brick service passage and closed service doorway, a little cyan/magenta light. The right third is the bar's simple brick entrance, one closed dark door outlined in warm yellow and one modest warm amber window. Architecture continues naturally between them. Top two thirds are dark buildings/wall with quiet visual detail. Bottom third is unobstructed dark wet pavement with a few sparse broken cyan and magenta pixel reflections. Walk path stays clear. No foreground posts or tall objects blocking the view because foreground will be a separate layer.
Lighting: nighttime, very dark purple-black base, restrained neon, tiny warm bar glow.
Constraints: fully opaque image, no transparency, full bleed, no borders, no people, no humanlike shapes, no animals, no vehicles, no readable words, no lettering, no sign text, no logos, no UI, no captions. Do not include a sprite sheet, variants, panels or separators. Produce only this single background image.

### Foreground

Use case: stylized-concept
Asset type: ONE transparent PNG foreground parallax layer for a dark neon 2D pixel-art side-scrolling street scene. Target canvas is exactly 2048 x 1024 pixels, aspect ratio 2:1, transparent RGBA.
Primary request: sparse street-level foreground silhouettes ONLY, to composite in front of a purple brick alley and modest bar. This is an overlay layer, not a full scene. The top 75 percent and almost all of the center must be fully TRANSPARENT. Include only a low dark-near-black purple curb and sparse broken wet-paving pixel glints confined to the bottom 10 to 15 percent, plus a short blocky black edge post at the extreme left and another at the extreme right rising no more than 30 percent of image height. The image must have genuine empty alpha, not a drawn checkerboard.
Style/medium: extremely simple lo-fi PIXEL ART, crisp chunky rectangular pixel shapes, flat geometric silhouettes, dark purple-black with a few restrained cyan and magenta reflections. Sparse, low detail, no realism, no smooth painterly rendering.
Composition: side-view street-level game overlay, aligned horizontal pavement, low sparse accents, transparent open field so all background architecture remains visible. The center needs to stay transparent down to at least 90 percent of canvas height. Keep the edge posts small, simple and unconnected. No rail across the scene.
Constraints: transparent background everywhere except the described foreground shapes. No buildings, walls, sky, midground, ground filling the whole frame, checkerboard, solid colored background, scene variants, panels, people, animals, vehicles, readable words, lettering, sign text, UI, logos, watermark, or extra objects. Produce only this one foreground layer.

## Verification (11 November 2026)

All runtimes use pinned Godot 4.6 stable (`89cea1439`) through
`tools/bth_qa_guarded_run.py`, fresh E: run IDs, admitted storage, 12% CPU / 2 GiB
Jobs, bounded time, and process reconciliation. Successful jobs exit 0, have no
timeout or cleanup errors, and drain owned processes.

- `travel_journey_receipt_check.gd`: 207 checks, including production save/load
  and optimized snapshot APIs. Run: `travel-canonical-final-receipt-20261111-01`.
- `travel_arrival_timeline_check.gd`: 80 checks. Dense 1 ms samples confirm both
  layers move throughout, preserve the 1.08 ratio, stay in overscan, and have no
  boundary snaps. Covers slowed departure, physical distance-driven wheels,
  stopped wheels/bob, exit/wait/walk/entry order, finite values, and purity.
  Run: `travel-shared-motion-test-20261111-01`.
- `bus_driving_sprite_check.gd`: 290 rendered checks. Actual OpenGL wheel phases
  differ while the body stays identical for wheel-only changes; stopped frames
  are stable; body bob moves independently; no pixels escape stage clipping.
  Run: `travel-bus-sprite-render-20261111-01`.
- `character_avatar_view_check.gd`: 364 assertions across all 45 characters,
  explicit accessories, active-slot validity, legacy walk compatibility,
  immutability, RNG purity, sizes, and deterministic walking.
  Run: `travel-avatar-check-20261111-05`.
- Existing table painter fidelity: 720 comparisons + 9 roulette checks. Existing
  environment character idle variety passed. Runs:
  `travel-avatar-fidelity-20261111-02`, `travel-avatar-idles-20261111-01`.
- `travel_cinematic_overlay_check.gd`: 389 checks, actual background/foreground
  source rectangles over 177 samples, every skip phase, canonical appearance
  injection, actor/wheel poses, static fallbacks, accessibility, focus, scrolling,
  interruption, and once-only completion.
  Run: `travel-canonical-final-overlay-20261111-01`.
- `travel_poc_integration_check.gd`: 89 checks on the production Main host.
  Watch/skip/reduced-motion/missing-art/forced-Web-atomic flows have equivalent
  money, time, location, counters, heat/sobriety, RNG, and queues. Includes actual
  appearance snapshot, blocked repeats, failed-install rollback, normal host
  autosave while presentation owns input, pending-receipt reload, and teardown.
  Run: `travel-canonical-integration-20261111-01`.
- Existing no-pointer animation liveness passed.
  Run: `travel-canonical-liveness-20261111-01`.
- Native no-input playback recorded from the production host, route, transaction,
  and overlay, using Godot Movie Maker. Approach, dropoff, driving, walk, door
  entry, and receipt frames visually inspected. Run:
  `travel-canonical-native-20261111-01`.

All evidence resides under `E:\CodexQA\BTH\runs\<run-id>\evidence`.
The integration capture flag `-- --capture-travel` records this same live path;
there is no separate mocked movie scene. It searches a bounded deterministic
world set for a real enabled route, rather than inserting or bypassing a route.
All saves/profiles are throwaway QA data, not shared player saves.

The full game regression suite and an exported browser/Web runtime were not run.
The Web check covers the supported forced-Web atomic return contract on source,
not a deployed browser build. No main merge, push, NEXT deployment, shared-player
profile, or interaction with other release work is part of this revision.

## Review movie

`review_artifacts/Back_Alley_to_Bar_Travel_Prototype.mp4`

- Actual Godot playback, 11.7 seconds, 1280x720 at 30 fps, H.264/yuv420p,
  silent, fast-start MP4. Includes the 8.8-second scene, receipt, and arrival.
- Actual seeded trip: Bus ticket, 24 game minutes, $3 fare. Receipt and gameplay
  state are committed before the animation, with no mutation during playback.
- Complete MP4 decode passed. Probe/encode/decode runs:
  `travel-canonical-encode-20261111-01`,
  `travel-canonical-media-probe-20261111-01`,
  `travel-canonical-media-decode-20261111-01`.
- Size: 1,580,010 bytes. SHA-256:
  `874a60b6debf9949e75297d9950589abd6780914e85a278fdec9c6e570546fcc`.
