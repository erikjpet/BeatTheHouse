# Fix 06.31 — Environment Object Placement and Grounding

Status: **BEFORE AUDIT COMPLETE / IMPLEMENTATION PENDING**  
Baseline product head: `c570f2ce6fafa4212292f8b129ca08f2e9e1e954`  
Claim commit: `e56f00b8`  
Audit date: 2026-09-10

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

## Before capture index

Every scenario has a matching pair:

`D:\Projects\Beat-The-House\.tmp\fix06_31\before\states\<scenario>_arrival_clean.png`  
`D:\Projects\Beat-The-House\.tmp\fix06_31\before\states\<scenario>_arrival_annotated.png`

Every baseline room/layer has a matching pair under
`D:\Projects\Beat-The-House\.tmp\fix06_31\before\base\`. Cropped floating
instances are under `D:\Projects\Beat-The-House\.tmp\fix06_31\before\floating_people\`.

The after audit and side-by-side closure index will be appended only after the
engine/data pass and all permanent gates are green.
