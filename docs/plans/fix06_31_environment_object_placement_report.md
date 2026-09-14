# Fix 06.31 — Environment Object Placement and Grounding

Status: **COMPLETE / EXACT-HEAD GATES GREEN**
Baseline product head: `c570f2ce6fafa4212292f8b129ca08f2e9e1e954`
Claim commit: `e56f00b8`
Audit dates: 2026-09-10 through 2026-09-11

## Player-visible finding

The defect is systemic. People are not merely a few pixels high: the current
resolver treats wall, window and mirror bands as generic free space. The
production-host captures show hosts, drivers, guards, clerks and patrons with
their feet on bottle mirrors, windows and empty wall space. Loose props also
appear without a physical supporting surface, while wall fixtures receive floor
shadows.

The before audit found **95 distinct person-placement root causes** across the
12 scenario-bearing archetypes. Those roots produce **163 directly captured
floating scenario-person instances** in the arrival states alone. Across every
authored phase and aftermath receipt, the audit classified 1,437 located
records: 228 `FLOATING`, 237 `WRONG_SURFACE`, 114 `SEMANTIC_MISMATCH`, and 858
preliminarily `OK`. These are before-fix counts; zero is required at closure.

## Evidence and method

The maintained `tools/environment_layout_screenshots.gd` now has a
`--fix06-31-audit` mode. It boots `res://scenes/main.tscn`, starts a real run,
pins each selected scenario, reaches its authored room through the shared
production generation/travel/finalization boundary, refreshes the production
canvas, and captures the live viewport. It selects and records semantic
identities rather than relying on render order.

Ignored machine evidence is under `.tmp/fix06_31/before/`:

- `grounding_audit_before.json`: all 1,437 located phase/aftermath receipts,
  including source anchor/zone, class, rect, contact point and verdict.
- `floating_people_inventory_before.json`: the 95 deduplicated person-placement
  roots and every scenario/state receipt that uses each root.
- `base/`: 21 clean and 21 annotated baseline-room captures (18 archetypes plus
  all three Punchline layers).
- `states/`: 55 clean and 55 annotated production-host arrival captures.
- `floating_people/`: 163 cropped live instances whose production rect ends
  above the room's provisional ground-contact line.

The annotated captures draw the room contact line in green, production object
rects in yellow and their base/foot contact in pink. They are diagnostic output,
not a production overlay.

## Before inventory by room

| Room | Floating receipts | Wrong-surface receipts | Person root causes | Why it is bad |
| --- | ---: | ---: | ---: | --- |
| Punchline / underground layers | 33 | 30 | 15 | Low-ceiling anchors and generic background/center zones put actors above tables and on the wall. |
| Delta Queen | 42 | 18 | 12 | Window-band anchors are treated as floor; board-wide fallback can also cross the brass rail into river space. |
| Bar | 25 | 27 | 12 | The background zone is the bottle mirror. Wake host and league captain placements make the failure especially visible. |
| Kitty Cat Lounge | 19 | 19 | 11 | Stage/bar/table relationships are not represented, so people and loose items share wall anchors. |
| Jazz Club | 14 | 17 | 9 | Stage, audience floor and bar are physically distinct but the resolver sees one board. |
| Beach | 3 | 21 | 9 | Sky, surf, sand and boardwalk are not encoded; vendors and the lost child can resolve over water/sky. |
| Gas Station Casino | 27 | 23 | 8 | Top anchors put drivers and clerks in the highway window/canopy band. |
| Motel | 14 | 29 | 6 | Desk, bedspread and floor are not distinguished; top anchors place staff in wall/window space. |
| Corner Store | 7 | 28 | 5 | The July base composition remains the strongest, but scenario actors still use surface-blind zones. |
| Grand Casino family | 20 | 12 | 4 | Slot wall, tables, ropes, pit floor and doors are not separate placement surfaces. |
| Back Alley | 19 | 4 | 3 | Brick wall and pavement are one free-placement area. |
| Pawn Shop | 5 | 9 | 1 | Display walls, glass case/counter and customer floor are not differentiated. |

Counts above are receipt counts, so repeated phase operations using one broken
anchor are intentionally visible. The root-cause inventory deduplicates those
repetitions.

## Root causes confirmed

1. Zone-only resolution uses the raw rectangle center. `background` therefore
   means wall center, not floor beside the back wall.
2. Collision recovery searches the full board, including walls, windows and
   voids; nearest free space can be physically impossible.
3. Base-layout fallback rows at approximately y=86/146/180 are mostly wall.
4. Event slots are content-blind, allowing person props and paper/wall props to
   occupy the same indexed coordinate.
5. Shadows are unconditional, so wall-mounted objects and already-floating
   people receive a false floor shadow.

The audit also confirmed the renderer is procedural in gameplay. External room
PNGs are enabled only for the main-menu canvas; production room truth is the
`PixelSceneCanvas._draw_<room>()` geometry and the captures above.

## Baseline gates

| Gate | Baseline result |
| --- | --- |
| `tools/validate_project.ps1` | PASS, 95.3 s |
| Scenario room multiseed finalization | PASS, 8 seed families × 55 scenarios = 440/440 in 253.6 s |
| Frozen scenario object/action census | PASS, 1,108 object ops and 673 actions |
| Frozen barriers | PASS, 25 objects across 39 placements (`obstacle=7`, `barrier=18`, `blockade=0`) |
| Full foundation determinism probe | **BASELINE RED**: all ten seeds reach stale Hold'em commands; `call` is outside the ordered turn or `deal` lacks table authorization. First-process hash `3073825705`, 525 checkpoints. This is a test-driver compatibility defect, not a placement result; the final gate must be repaired without weakening deterministic assertions. |

## PM recount comparison

The PM's narrower scan counted 302 actor and 806 scene placement operations.
The independent recursive scan found 404 actor and 1,033 scene operations that
carry location metadata. The difference is filtering, not content drift: the
broader count includes pose/behavior/state/remove receipts that retain an
anchor or zone as well as spawn/move receipts. The implementation audit keeps
the broader set so no state can inherit a bad physical relationship; the frozen
1,108/673 content census remains unchanged.

## Surface judgements to encode

- **Delta Queen:** feet/base may use the deck between the wall base and brass
  rail. The rail is a barrier/edge; the animated lines from approximately y=352
  downward are river void. Nobody may be displaced across the rail into it.
- **Bar:** the wall ends at y=244. The bottle mirror is not standable. Staff can
  be occluded behind the bar counter; regulars use stools/rail or the floor;
  pool players use the floor around the pool table.
- **Beach:** y<78 is sky, y=78–180 is surf/void, y=180–300 is sand, and the
  drawn boardwalk band is separately walkable. The tide-slot kiosk is a floor
  fixture on its drawn platform.
- **Gas station:** window/canopy and support columns are not floor. Staff use the
  cage/counter; customers and drivers use the forecourt/store-floor band.
- **Homes and motel:** the floor, bedspread and furniture tops are separate.
  Surface items may use the latter two; people may not.
- **Corner Store:** preserve the owner-approved July base locations unless a
  captured person-class object proves a minimal correction necessary.

These provisional judgements are used only to identify the before defect. Phase
C moves them into authored per-room surface maps checked against clean captures.

## Phase C — authored surface maps

`data/environments/placement_surfaces.json` now contains 21 unique maps: every
one of the 18 archetypes plus the Punchline's public club, hidden casino and
back-room layers. Every map explicitly contains floor bands/contact range,
counters or support lines, seats, wall bounds/exclusions, ceiling, doorways and
voids. The schema remains additive and does not change saved-run data.

The complete checked overlay set is committed under
`docs/plans/evidence/fix06_31/surface_maps/`. Green outlines show standable
floor/stage bands, blue lines show support surfaces, purple outlines show
doorways, red outlines show voids, yellow outlines show live object rects and
pink dots mark their current contact point. The Delta Queen overlay visibly
separates the narrow deck from the brass rail and river; the Beach overlay
separates surf from sand/boardwalk.

## Before capture index

Every scenario has a matching pair:

`D:\Projects\Beat-The-House\.tmp\fix06_31\before\states\<scenario>_arrival_clean.png`
`D:\Projects\Beat-The-House\.tmp\fix06_31\before\states\<scenario>_arrival_annotated.png`

Every baseline room/layer has a matching pair under
`D:\Projects\Beat-The-House\.tmp\fix06_31\before\base\`. Cropped floating
instances are under `D:\Projects\Beat-The-House\.tmp\fix06_31\before\floating_people\`.

The after audit and side-by-side closure index will be appended only after the
engine/data pass and all permanent gates are green.

## Implemented placement authority

Every live object now receives one of the ten placement classes through
`EnvironmentPlacement.classify()`. Base composition, scenario composition,
delivery handoffs, rendering and audit code use that same classifier and the
same 21 cached room/layer surface maps. Grounded candidates are generated from
physical supports rather than board-wide free space: feet and fixture bases use
walkable bands; clerks use counters; seated people use seats; items use support
lines; signs use wall bands; hanging props use ceiling bands; and travel uses
drawn doorways.

Collision recovery now searches only class-valid candidates and fails closed
with the room, identity and class when capacity is impossible. Base layouts are
re-derived when their grounding signature changes, including restored saves,
without a save-schema change or RNG draw. Content-aware class overrides prevent
person events from taking wall slots and wall fixtures from taking floor slots.
The renderer uses class-aware contact shadows and counter occlusion metadata;
wall-mounted and hanging objects no longer receive floor shadows.

## Capacity cases and decisions

- **Gas Station Casino:** the window/canopy remains non-walkable. The cage is a
  counter support, and the drawn lower lottery desk is separately mapped so a
  scenario night clerk and rotating staff can coexist without placing either
  in the highway window. The machine row remains a machine/item support, not a
  place for people to stand.
- **Kitty Cat Lounge:** the stage, champagne bar, table tops and far-right booth
  are distinct supports. Audience/group actors use the floor or stage; booth
  actors use the booth; paper/signage uses the wall. This resolves the amateur
  and slow-night arrival capacities without hiding content.
- **Grand Casino:** machine controls attach to the machine/wall bank; table
  games use rail/felt supports; rotating hosts use the physical
  floor; travel is biased to the correct pit, cage and high-limit openings; and
  the drawn cocktail-service point carries `Buy a Drink`. The deeper floor
  contact range keeps the host desk clear of table controls. Audit, convention
  and gala arrivals all fit in normal and expanded layouts.
- **Jazz Club:** the waiting audience is a grounded group rather than a single
  floating person, while music services retain stage affinity.
- **Motel wedding overflow:** the room-key tray uses the authored service lane
  instead of the foreground walk lane. The signed package was re-sealed after
  this placement-only edit.
- **Corner Store:** the owner-approved July base composition was not changed.

No object, action, route, reward or scenario branch was removed to create
capacity. The scenario census remains 1,108 objects / 673 actions and the
barrier census remains 25 objects / 39 placements.

## Permanent proofs added

- The static grounding checker validates all 21 maps, 18 archetypes, ten
  classes, support geometry, class overrides and authored placement-class
  values, and rejects RNG or wall-clock use in the classifier.
- The focused grounding contract forces a floor collision, resolves a
  zone-only person, proves person-event and wall-sign slot separation, and
  compares hidden-state placement candidates byte-for-byte.
- The production multiseed harness now walks reachable phases and branches via
  real sequence commands/facts, checks aftermath, reentry and cleanup states,
  validates normal/expanded geometry, and checks route start, endpoint and
  reduced-motion endpoint grounding. Geometry-equivalent public states share a
  cached proof; every path remains counted.
- Historical Continue coverage now requires a current grounding signature with
  no placement errors or fallback slots. All 37 `v0_5_1` fixtures and all three
  `mid_0_6` fixtures pass current FoundationMain load/save/load.
- The stale draw-poker determinism driver was updated in isolated commits to
  authorize a three-resident current Hold'em table and follow only live legal
  actions. The old probe could not reach a valid deal because its two-resident
  fixture triggered production candidate expansion and could randomly seat no
  associate. The final paired ten-seed reports are byte-identical at 642
  checkpoints with combined hash `871972474` and report SHA-256
  `742D1BAB7DFC7E28F749190B43B50180419530A1C94EAB56FDD9727D6619BF41`.

## Owner correction and final implementation

The owner's correction rejected the first generic constraint-solver direction.
That solver was preserved at `ff1e5e0f` and then removed from the shipping path.
The final engine keeps authored placements unchanged when they are valid, uses
only bounded local offsets as a safety net, and falls back to authored per-class
room slots. There is no board-wide placement search, capacity reservation pass,
or capacity-impossible hard failure.

The corrected classifier reclassified shopkeepers, merchants, lenders, named
characters, Silas and person-prop vocabulary as people. On that corrected
authority the initial after attempt honestly reported 39 `FLOATING` and 183
`WRONG_SURFACE` records out of 932; those findings drove the deliberate
room-by-room data pass. No test was weakened, no golden was refreshed, and no
object was deleted or hidden to create room.

The one permitted composition comparison was recorded before the owner stopped
profiling: the Phase A full multiseed run was 253.6 seconds, while the corrected
authored capture's composition measurement was approximately 77.1 seconds.
No further profiling or performance run was started.

## Final after evidence

The final windowed production-host run is under
`.tmp/fix06_31/final_after/`. Its machine-readable audit records 1,022 rendered
objects: 1,022 `OK`, zero `FLOATING`, zero `WRONG_SURFACE`, zero floating-person
roots and zero capture failures. It covers all 55 scenario arrivals and 21 base
rooms/layers. All thirteen committed contact sheets were visually inspected;
characters meet their floor, counter, seat or stage supports, props rest on
physical surfaces, mounted objects remain on walls, and exits remain readable.

The side-by-side clean and annotated index is committed at
`docs/plans/evidence/fix06_31/contact_sheets/manifest.json`. It contains 13
sheets, 21 base-room rows and 55 scenario rows. The before capture remains under
`.tmp/fix06_31/before/`; generated machine output is intentionally not staged.

## Final exact-head gates

| Gate | Final result |
| --- | --- |
| Static project and grounding validation | PASS; 21 maps, 18 archetypes, 10 classes |
| Focused grounding contract | PASS; authored-first bounded fallback, person classification, class slots and hidden-state neutrality |
| Runtime multiseed finalization | PASS; 8 families × 55 scenarios = 440/440 |
| Reachable state/layout census | PASS; 17,984 reachable states, 3,768 distinct layouts |
| Normal/expanded controls, routes and census | PASS; labels, hit authority, walk lanes, route/reduced-motion endpoints and object census preserved |
| Production-host visual audit | PASS; 1,022/1,022 `OK`, zero floating/wrong-surface/failures |
| Scenario content census | unchanged: 1,108 object ops, 673 actions |
| Barrier census | unchanged: 25 objects, 39 placements |
| Historical Continue fixtures | PASS; 37 v0.5.1 and 3 mid-0.6 fixtures re-derive current grounded layouts without a schema bump |
| Determinism | PASS; paired 10-seed, 642-checkpoint reports byte-identical; RNG assertions unchanged |
| `tools/check_godot.ps1 -Suite Audit` | PASS; all stages, including the 440-case gate and deep game audits |
| `tools/validate_project.ps1` | PASS on the exact branch head |

There were no changes to money, RNG, RTP, payouts, odds, save schema, migration,
game mechanics or apparent game behavior. Corner Store's approved base
composition remains unchanged; only audited scenario placement data was
corrected where necessary.
