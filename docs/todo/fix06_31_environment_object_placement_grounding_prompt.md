Status: TODO — owner-reported presentation defect; claimable now
Priority: P1 — people float in mid-air in most rooms; every room reads as broken
Board row: `fix06_31` in `docs/todo/README_0_6_board.md` (Defects table)
Opened: 2026-09-10 from owner direction; evidence measured by the PM on `main` at `c570f2ce`

## Execution Record

_Fill in on completion: date, commit hashes, gate results, deviations._

# Agent Prompt — fix06_31: Environment Object Placement — Ground Every Person, Put Every Object Where It Belongs

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are working in `D:\Projects\Beat-The-House` on `main` at `c570f2ce` or later.
This prompt is complete on its own. Read all of it before you change anything.

## 0. Authority — what the owner asked for

The owner's direction, verbatim:

> "please identify instances of environment objects that showcase people that
> are floating in the air. this should never happen. if they are at a bar, place
> them by the bar, in a store place them on the floor etc, do not just place
> them in the middle of the air randomly. we need to do a better job of placing
> environment objects. please do a complete audit of every scenerio and where
> objects are palced within. do a pass that places them intuitively and
> logically among the environment in locations that actually make sense based
> on the structure of t environment how the background art is formatted and how
> other objects are placed."

This gives you three jobs, in this order:

1. **Find every floating person.** Produce a complete inventory of every place a
   person is drawn in the air: standing on a wall, hovering in front of a window,
   hanging over a bottle mirror, standing on a counter, standing in the river.
   "Never" means zero, in every room, every scenario, every phase, every seed.
2. **Audit every object in every scenario.** Not only people. Every item, prop,
   fixture, sign, door and actor gets checked against the art it sits on.
3. **Re-place everything so the room makes sense.** An object goes where it
   would physically be, given the drawn room and the other objects around it.
   Then make sure the engine cannot put it back in the air: the fix must hold
   for rotating content, collision displacement and new content authored later.

A row that re-authors coordinates and leaves the placement engine able to float
the next person does not close. The fix has two halves, **data and engine**,
and you must do both.

## 1. What correct placement means

This is the bar. Every judgement you make, and every rule you encode, comes
from this section.

### 1.1 The one-sentence rule

**Every object sits where it would physically be in the drawn room, rests on or
attaches to something the art actually draws, and reads naturally next to the
objects around it.**

### 1.2 Placement classes

Every rendered object belongs to exactly one placement class. The class decides
what it is allowed to rest on:

| Class | Examples | Must rest on / attach to | Never |
| --- | --- | --- | --- |
| `standing_person` | patrons, runners, guards, hosts, scenario actors, event people (`rowdy_patron`, `pit_boss`, `casino_host`), lenders, Silas, drivers | **feet** on a walkable surface: floor, deck, stage, sand, pavement | feet on a wall, window, mirror, counter top, shelf, sky, water, or empty air |
| `behind_counter_person` | bartender, clerk, cashier, cage teller, shopkeeper, dealer at their table | standing behind a drawn counter, bar, cage or table, cut off by it, with the counter top as the visual base line and x inside the counter's span | standing *on* the counter; behind a counter the art does not draw |
| `seated_person` | stool regulars, booth guests, card players, audience | a drawn stool, booth, chair or table edge | sitting on nothing |
| `group` | "The Crew", "Sheltering drivers", crowd objects | the floor, as `standing_person`, across its full footprint | as `standing_person` |
| `floor_fixture` | furniture, tables, barriers, ropes, carts, crates, luggage, machines, vehicles, lecterns, equipment | its base on the floor | wall band; overlapping a drawn wall fixture it is not part of |
| `ground_marker` | chalk lanes, tape lines, spills, route marks | flat on the floor | wall or air |
| `surface_item` | goods, tickets, trays, drinks, ledgers, watches, cards, notes lying down | a drawn counter, shelf, table, cooler, display case or bedspread: bottom edge on its top line, x inside its span | floating over the wall; loose in mid-air above a surface |
| `wall_mounted` | signs, notices, calendars, screens, clocks, cameras, dartboards, posters, menus, scoreboards | fully inside the wall band on a plausible mount point, clear of windows or doors it is not part of | the floor; a floor shadow |
| `hanging` | string lights, banners, speakers on rigging | the ceiling band | the floor |
| `doorway` | travel, exits, side doors, gangways, `exit`-role props | a drawn door, opening, gangway or room edge | the middle of a wall with no opening; the floor with no door |

Games, services and game hooks keep the rules from the July placement pass (see
§1.4); they are `floor_fixture`, `surface_item` or `wall_mounted` depending on
what they draw.

### 1.3 Semantic placement: "by the bar, on the floor"

Being grounded is necessary but not sufficient. The object must also be in the
**right** grounded place:

- **Role decides location.** Bartenders stand behind the bar. Clerks stand at the
  register. Dealers stand at their table. Musicians stand on the stage. Guards
  and bouncers stand at the door they guard. Drinkers stand at the bar rail or
  sit on stools. Card players sit at tables. Shoppers stand in the aisle. Drivers
  stand near vehicles or the window. Waiting people form lines on the floor.
- **The authored description is the placement spec.** 0.6 scenario objects carry
  descriptions that narrate where they are. For example, "a mourning regular
  waits at the right-hand end of the joined tables"; "the wake host watches from
  the back wall, keeping the center aisle clear". **Placement must make the
  description true.** "Watches from the back wall" means *standing on the floor
  at the back of the room, by the wall*. It does not mean drawn on the wall at
  y=82. Read every `description` and every `description_variants` entry of every
  object you place. When a description names a relationship ("beside the tray",
  "at the door", "behind the tables"), satisfy it spatially in every phase where
  that variant can show. Change a description only when no placement in the room
  could make it true, and record that as a deviation.
- **Relative placement across objects and phases.** Objects that belong together
  are placed together: a tray by the regular who receives it, a rope at the door
  it closes, a ledger on the table where it is counted. When a phase `move`s an
  object, its new position must also make sense, and so must the objects that
  relate to it.
- **Rotating content still reads.** Base event, item and lender slots are
  index-based, so different content lands in the same slot on different seeds.
  Each slot must be valid for **every** piece of content that can land there
  (see §4.5).
- **Depth reads.** The rooms are first-person. The floor recedes from the bottom
  of the board up to the base of the wall. Where two grounded objects overlap
  visually, the one whose feet or base is lower on the board is nearer and draws
  in front. If you need a second row of people, put the back row's feet near the
  wall base, not up the wall. Scale them down if the renderer supports it cleanly
  (§4.7).

### 1.4 Reference exemplar: Corner Store

The owner hand-approved the Corner Store base layout on 2026-07-05: items in rows
on the shelf unit; tip, shopkeeper and one event slot along the register counter;
drink service on the coolers; events and lenders on floor anchors; travel on the
exit. That is the bar for "intuitive". Treat its `layout` block in
`data/environments/archetypes.json` as the reference and do not move those spots
unless your audit proves a person floats there. If it does, record the finding,
fix it minimally, and call it out in the report.

The July pass (`docs/todone/environment_semantic_layout_prompt.md`) placed base
spots for the other rooms with the same philosophy: games on their table or
cabinet art, hooks beside their parent, items on retail surfaces, services where
the service happens, lenders at the edges, travel at doors, events at generic
narrative anchors. It pre-dates 0.6. It never considered people's feet, and 0.6
then added hundreds of scenario objects placed by free space. Keep its intent,
correct its people, and extend it to everything 0.6 added.

## 2. Measured evidence (PM, static, pre-collision; verify and extend it, do not trust it)

A static scan of `data/environments/scenario_sequences/*.json` (5 packages, 55
scenarios, 376 phases) against `data/environments/archetypes.json` resolved each
placement op's authored center the same way `ScenarioLayoutResolver._resolve_center`
does. It took `bounds` or the default 72×80 actor / 48×48 prop, and measured the
bottom edge of the resulting rect. In every procedural room the wall is drawn
from y=0 down to roughly y=244–246, and the floor starts below that.

| Measure | Count |
| --- | --- |
| Actor placement ops (spawn/move/replace carrying a location) | 302 |
| … placed by `zone_id` only (resolves to the zone **center**) | 190 |
| … of those, `zone_id: "background"` | 68 |
| **Actors whose feet (rect bottom) sit above y=250 before any collision displacement** | **132 (44%)** |
| … whose feet sit above y=200 | 116 |
| Scene-object placement ops | 806 |
| … zone-only | 489 |
| … bottom above y=240 (many are legitimately wall-mounted and need classification) | 260 |
| … with an **empty `role`** (unclassifiable without authoring) | 409 |

These are **lower bounds**. Runtime collision displacement (§3, mechanism 2)
moves more objects, including objects that were authored correctly.

Anchor names show placement by free space rather than meaning:
`package_b_gas_top_mid (420,40)`, `package_b_gas_top_right (650,40)`,
`package_b_motel_top_left (100,40)`, `package_b_motel_service_top_right (550,40)`,
`package_b_beach_top_mid (350,70)`, `grand_scenario_top_400 (400,70)`,
`delta_secondary_top (380,70)`, `env06_8_convention_clerk (550,50)`,
`env06_8_union_delegate (50,50)`, `env06_8_darts_captain (450,65)`,
`env06_8_rent_host_clear (100,60)`, and more with `_top_`, `_clear` and
`_work_N` suffixes. Each of those carries a person: a tour bus driver, a desk
clerk, a union delegate, a league captain, a landlord.

Concrete cases:

- **Bar, The Wake:** "Wake host" is `zone_id: "background"`. The zone is
  `[32,32,836,100]`, so the host is centered at (450,82), a 72×80 figure standing
  in front of the bottle mirror with feet at y=122. Its own description says it
  "watches from the back wall". Fix it so that sentence is true: feet on the
  floor, near the back wall.
- **Bar, Darts League Night:** "League captain" at `env06_8_darts_captain
  (450,65)`, feet at y=105.
- **Gas station, Tour Bus Stop / Trucker Convoy / Road Crew Payday / Graveyard
  Shift:** drivers, clerks and crew at y=40 anchors, feet at y=80.
- **Delta Queen, Engine Trouble:** "Engine mate" at `delta_secondary_top
  (380,70)` and "Guard" at `env06_8_engine_guard_clear (500,80)`, in front of the
  windows.
- **Motel, Conventioneers / Weekly Rates / Stakeout / Wedding Overflow:** desk
  clerk, landlord, observers and runner all at y=40–82.
- **Beach, Festival Weekend:** "Lost child" and "Stall vendor" at y=70 anchors.

Base-layout spots that can hold a person, centered above y=200. Some are
correct: a clerk behind a counter is fine. Each needs a judgement:

`back_alley` event_spots[0] (304,92), [1] (706,92), shopkeeper (450,90) ·
`motel` event_spots[0] (86,170), [1] (430,154), shopkeeper (736,162),
numbers_silas (440,60) · `bar` event_spots[1] (486,92), numbers_silas (300,80),
numbers (780,100) · `gas_station_casino` event_spots[1] (244,106), [2] (820,92) ·
`small_underground_casino` and all three layers: numbers_silas (250,80); casino
layer event_spots[0] (84,86), [1] (410,96); back_room event_spots[5] (305,92) ·
`jazz_club` event_spots[0] (84,112), shopkeeper (642,124) · `kitty_cat_lounge`
event_spots[0] (92,100), [2] (820,72), [3] (250,112) · `delta_queen`
event_spots[0] (86,86), [1] (500,92), shopkeeper (820,90) · `grand_casino`
event_spots[0] (80,126), [1] (770,92).

Older captures showed the same pattern on the base layer: an event person
("Rowdy Regular") and a named character object standing in front of the Delta
Queen's windows, and loose items (pocket watch, luck card) hovering at the top
of the Kitty Cat Lounge wall instead of resting on the bar.

## 3. Why it happens: five mechanisms, all in code you own

Read each one yourself before changing it.

1. **Zone-only placement resolves to the zone center.**
   `scripts/core/scenario_layout_resolver.gd:1461` `_resolve_center()` returns
   `zone_rect.get_center()` for a zone. A `background` zone is a wall strip, so
   its center is on the wall. `center`, `left` and `right` zones span wall and
   floor, and their centers sit near the wall base. 190 actor ops and 489 prop
   ops depend on this.
2. **Collision displacement ignores the room.**
   `_resolve_visual()` (`:467`) calls `_collision_safe_rect()` (`:1147`) when
   the authored rect collides. That tries `COLLISION_OFFSETS` (`:24`), including
   pure vertical moves of ±52 and ±104 px. Then it tries
   `_bounded_collision_candidates()` (`:1255`) and `_fine_collision_candidates()`
   (`:1275`): a grid over the **entire board**, sorted only by distance. A person
   who collides on the floor gets moved up the wall if the wall is the nearest
   free space. Nothing in the resolver knows where the floor is.
3. **The base-layout fallback grid is mostly wall.**
   `scripts/core/environment_instance.gd:855` `_first_available_object_rect()`
   and `:1061` `_first_noncolliding_object_rect()` fall back to
   `_fallback_grid_object_rects()` (`:1086`). Its candidate rows at normalized
   y=0.20 and 0.34 (≈86 px and ≈146 px) are wall. `_fallback_object_rect()`
   (`:913`) puts events at y≈0.42 (≈180 px), shopkeepers at 0.34 and services
   at 0.30: wall again. Any spot list that runs short, or any collision, sends
   people up the wall.
4. **Event slots are index-based and content-blind.** The first event drawn in a
   run takes `event_spots[0]`, and so on. A slot placed on the wall for a paper
   notice gets a `rowdy_patron` on another seed. The prop comes from
   `scripts/ui/pixel_scene_canvas.gd:4739` `_fallback_event_prop()`. People props
   in that vocabulary include `clerk_counter`, `clerk_talk`, `pit_boss`,
   `casino_host` and `rowdy_patron`.
5. **Every object gets a floor shadow.** `pixel_scene_canvas.gd:4123`
   `_draw_object_shadow()` draws a floor shadow at 78% of the rect's height for
   every object, wall-mounted ones included. A floating person gets a shadow on
   the wall, which makes the error more obvious. A correctly wall-mounted sign
   gets one too, which makes it look like it is floating.

Also in scope, because they draw people:

- `pixel_scene_canvas.gd:1633` `_draw_familiar_characters()`: hard-coded named
  characters per room, drawn **foot-anchored** by `_draw_named_character(id,
  foot, …)` (`:1705`).
- `:1740` Grand Casino living characters, plus `_rourke_scene_foot()` (`:1802`)
  and `_rival_scene_foot()` (`:1820`), which are already foot-anchored.
- `SCENARIO_CROWD_POINTS` (`:103`), the ambient crowd silhouettes.
- `_draw_scenario_actor()` (`:2005`), which draws a scenario actor filling its
  rect with the body ending about 8 px above `rect.end.y`. **That is where its
  feet are.**
- Streets delivery handoff placement:
  `scripts/ui/environment_interaction_controller.gd:1146` `_delivery_available_rect()`.

The foot-anchored helpers above are the pattern to follow. People should be
positioned by their feet, not their centers.

## 4. Architecture orientation (the parts you touch)

- **Board.** Every room is a 900×430 board (`scripts/core/art_contracts.gd`
  `ENVIRONMENT_BOARD_SIZE`), scaled to fit. Small-screen mode expands every hit
  rect to `ENVIRONMENT_OBJECT_HIT_SIZE` 104×76 around its center.
- **Art.** In gameplay, every room's background is **procedural**, drawn by
  `PixelSceneCanvas._draw()` (`pixel_scene_canvas.gd:661`), one `_draw_<room>()`
  per room with literal board coordinates. The `visual_context.asset_path` PNGs
  in `assets/art/environments/` are only set on the **main-menu** canvas
  (`scripts/ui/foundation_main.gd:8114–8115` is the only writer of
  `use_external_background`). Verify this yourself. Your ground truth is the
  `_draw_<room>()` code **and** a production-host capture of that room. If a room
  renders a PNG in play anywhere, that PNG is its truth.
- **Rooms.** 18 archetypes in `data/environments/archetypes.json`: `corner_store`,
  `back_alley`, `motel`, `bar`, `gas_station_casino`, `small_underground_casino`
  (three `layers`: `club`, `casino`, `back_room`, each with its own `layout` and
  its own art key), `jazz_club`, `kitty_cat_lounge`, `delta_queen`, `beach`,
  `pawn_shop`, `grand_casino`, `grand_casino_high_limit`, `grand_casino_back_room`,
  `grand_casino_cage`, `motel_room`, `apartment`, `house`. Some share art
  (`grand_casino` ×3). Placement is still per archetype.
- **Base placement.** Each archetype's `layout` holds per-type spot lists
  (`game_spots`, `event_spots`, `item_spots`, `service_spots`, `lender_spots`,
  `travel_spots`, `shopkeeper_spots`, `game_hook_spots`, `numbers_spots`,
  `numbers_silas_spots`, `layer_spots`, `pawn_counter_spots`, `casino_*_spots`,
  `home_*_spots`). Each `[x,y]` is an object **center**.
  `EnvironmentInstance.ensure_generated_layout()` (`environment_instance.gd:517`)
  resolves them into `layout.object_rects`.
- **Scenario placement.** 55 scenarios in 5 signed packages under
  `data/environments/scenario_sequences/`. Each phase has `scene_ops` and
  `actor_ops` that place objects by `anchor_id` (per-archetype
  `semantic_anchors`, `position` = center), by `zone_id` (per-archetype
  `semantic_zones`, `bounds`), or by `layout:<type>:<index>`. Actors may have a
  `route_id`: the renderer lerps in a straight line from start to endpoint, and
  reduced-motion shows the endpoint. `ScenarioLayoutResolver.resolve()` seals the
  result into a layout authority with a digest.
- **Existing guarantees that must stay green** (from `env06_8`, `fix06_27` and
  `fix06_28`, all independently accepted):
  - `WALK_LANE := Rect2(16,378,868,36)` (`scenario_layout_resolver.gd:22`): no
    obstacle, barrier or blockade may intersect it, in normal or expanded layout.
  - Reachability from the lane into the room.
  - The reserved TalkDock overlay rect.
  - Labels are text-safe and non-overlapping in normal and expanded layouts. A
    label sits 19 px above its rect, or below the rect when the top is under
    y=16 (`_label_rect`, `:1427`).
  - Hit authority is unambiguous in both layouts.
  - Actor routes are unobstructed and their endpoints stage inside the board.
  - Seeded room events never land on authored label rects.
  - `tools/scenario_room_multiseed_finalization.gd` passes 8 seed families × 55
    scenarios = 440/440 in both layouts (it runs in the `Audit`/`Full` suites of
    `tools/check_godot.ps1`).
  - Object and action counts never regress. **Record them at your baseline.**
- **Persistence.** Saved runs carry layout state: `layout.object_rects`,
  `scenario_layout_authority`, the layout digests and
  `scenario_sequence_base_layout_object_rects` (`scripts/core/run_state.gd`
  around `:2594–2865`). `run_state.gd:~2002` compares a cached sequence's
  `sequence_signature` with the source.

## 5. The work, in phases

Commit at the end of each phase, and at least every 30 minutes, on a branch.
Keep `main` green.

### Phase A — Baseline (no edits)

1. Record the exact head, and run `powershell -ExecutionPolicy Bypass -File
   tools/validate_project.ps1`.
2. Run the multiseed finalization gate and record 440/440, object-op count,
   action count, barrier-class count and placement count.
3. Run the determinism probe (`tools/foundation_determinism_probe.ps1`) and
   record its digests. Placement changes may legitimately move layout digests.
   You must be able to prove that **only** layout moved.
4. Confirm or correct every number in §2 by code. Report the differences.

### Phase B — Audit harness and the full audit (the owner's first two asks)

Build **one** audit tool. Extend `tools/environment_layout_screenshots.gd` or
`tools/scenario_sequence_probe_main.tscn` (`--mode=visual`) rather than writing a
third parallel harness. It must drive the **production host**:
`start_new` → travel → `scenario_finalize_installed_environment` with the
1280×720 layout context, using `scripts/tests/foundation/harness_production_fidelity.gd`.

**Harness rule (six false-result incidents in this program):** any harness that
travels must finalize on arrival exactly as the host does. It must select
objects by exact semantic identity, never by type or render order.

Coverage, every combination:

- **Rooms:** every archetype and every Punchline layer.
- **States:** the baseline room with no scenario; each of the 55 scenarios at
  every reachable phase, including each aftermath branch, the cleanup state and
  the revisit state. Advance phases by real actions, not by poking state.
- **Seeds:** at least the 8 `fix06_27` seed families, so rotating
  event/item/lender content is covered.
- **Layouts:** normal and expanded small-screen. Include the reduced-motion
  endpoint, and route start and endpoint for every routed actor.

For every rendered thing, record: room, state, seed, layout, identity, source
(base type, scenario op receipt, or drawn character), label, placement class,
draw rect, contact point (feet / base / mount), the surface it lands on (§Phase
C), whether it was collision-displaced (resolver `collision_adjusted`, or
base fallback away from its authored spot), and a verdict: `OK`, `FLOATING`,
`WRONG_SURFACE`, `SEMANTIC_MISMATCH` (grounded but in the wrong place for its
role or description), `OVERLAPS_ART` (covers a drawn fixture it is not part
of), or `DISPLACED` (moved by collision from a correct authored place).

Deliverables, in this order:

1. **The floating-people inventory.** Every `FLOATING` or `WRONG_SURFACE`
   person-class instance, deduplicated to root cause (the anchor, zone, spot or
   mechanism responsible), with a cropped capture of each.
2. **The full object audit.** Every object, every verdict, as a machine-readable
   report plus a human summary per room.
3. **Contact sheets** per room-state: one clean and one annotated with surface
   overlays, contact-point markers and verdict colors.

Machine output and captures go in `.tmp/fix06_31/` (never staged). The human
report is committed as `docs/plans/fix06_31_environment_object_placement_report.md`.
Commit the tool and the report before you start fixing. The report is the "before".

### Phase C — Surface maps: make the art machine-readable

For every room (every archetype and every layer art key), author a
**placement surface map** in data, derived from that room's `_draw_<room>()`
code and checked against a clean capture. Add it additively beside the room's
`layout` (e.g. `placement_surfaces`). Name the fields after inspecting how
`content_library.gd` and `validate_project.ps1` read archetypes.

- `floor`: the walkable region as a polygon or bands, including the wall-base
  line (the far edge of the floor). Stage, deck and sand count as walkable where
  the art draws them walkable.
- `counters`: named surface lines `{x0, x1, top_y, front_y}` for bars, counters,
  cages, display cases, coolers and tables. They serve as rest lines for
  `surface_item`, cut lines for `behind_counter_person`, and occluders.
- `seats`: named stool, booth and chair points for `seated_person`.
- `wall`: the mountable band, with windows, mirrors and doors listed as named
  sub-rects so wall-mounted objects avoid what they are not part of.
- `ceiling`: the `hanging` band.
- `doorways`: drawn doors, openings, gangways and room edges.
- `void`: regions nothing may stand in: sky, water, river, surf, mirror glass.

Record per-room judgement calls in the report, with the reason:

- **Delta Queen:** `_draw_delta_queen()` (`pixel_scene_canvas.gd:1188`) draws
  the wall and windows at 0–246, tables at 170–262, slot cabinets at 132–256, a
  brass rail across the full width at 278–328, and river lines from y≈352. Decide
  which bands are deck and which are river. No person stands in the river.
- **Bar:** `_draw_bar()` (`:1048`) draws the wall at 0–244, the bottle mirror at
  (54–552, 52–182), the bar counter `Rect2(38,178,548,56)` (top 178), stools at
  x 106–548 on y 230–290, the pool table `Rect2(598,188,224,76)`, and the video
  poker cabinet `Rect2(768,144,86,112)`. So: the bartender goes behind the
  counter; regulars sit on stools or stand at the rail; pool players stand
  around the table; the floor starts at 244.
- **Beach:** sand vs. surf vs. sky. **Gas station:** forecourt vs. store floor
  vs. window. **Back alley:** ground vs. brick wall. **Homes:** floor vs. bed
  vs. furniture tops.

Add a debug overlay mode to the audit tool that draws the surface map over the
room. Commit every map together with its overlay capture.

### Phase D — Placement classes and one classifier

Implement **one** classifier, a single function used by the resolver, the base
generator, the renderer and the audit. It maps every object to a §1.2 class from
its `semantic_kind`, `role`, `icon_key` / prop (`_fallback_event_prop`
vocabulary), base object type, and the named-character role.

Where the heuristic is wrong or silent (409 scene ops have an empty `role`),
add an explicit authored `placement_class` to the op or anchor. **Every object
must classify explicitly or deterministically. Never default a person to
"center".**

Encode §1.2 and §1.3 as a **static checker** over the data: every anchor, zone
use and spot, checked against its room's surface map for the classes that can
land there. Wire it into `tools/validate_project.ps1` following that script's
existing JSON-check pattern. It is expected to fail loudly on current data. That
failure list is your Phase F to-do list.

### Phase E — Make the engine class-aware so it cannot float anything again

1. **Contact-point anchoring.** For grounded classes, position by feet or base.
   A person's rect is derived from where the feet touch the surface, not from a
   center. Add this as an explicit anchor property (for example `contact:
   "feet" | "base" | "surface" | "mount" | "center"`, default `center` for
   compatibility) or derive it from the class. Either way, migrate every
   people-carrying anchor explicitly so nothing silently changes meaning.
2. **Zone resolution by class.** For zone-only placement, resolve to a valid
   contact point for the object's class *inside that zone*: the zone ∩ floor for
   people and fixtures, a counter line in the zone for items, the wall band for
   wall-mounted objects. Never the raw zone center for a grounded class. If a zone
   contains no valid surface for the class, that is a **content error**, caught
   by the Phase D checker and fixed in Phase F.
3. **Collision displacement by class.** Restrict `_collision_safe_rect()`
   candidates, including `COLLISION_OFFSETS` and both grid searches, to the
   class's valid region. Grounded classes slide along the floor, horizontal first,
   then in depth within the floor. Surface items slide along their counter or to
   another counter. Wall-mounted objects stay in the wall band. If no valid
   candidate exists, fail closed with a specific error that names the room, object
   and class. **Never fall through to an arbitrary board position.** Keep the
   `fix06_27` fine-grid LRU behaviour (no per-refresh rebuilds).
4. **Base fallback by class.** Replace the wall-heavy fallback in
   `_fallback_grid_object_rects()` / `_fallback_object_rect()` with class-aware
   candidates drawn from the surface map. Every spot list must be long enough for
   the archetype's maximum counts, so the fallback is a safety net, not a
   routine path. The audit must show **zero** base objects resolving through the
   fallback in normal play.
5. **Content-aware event (and lender) slots.** Give each spot a slot class, and
   give each event a placement class derived from its prop or visual key. Assign
   deterministically: same inputs, same order, **no new RNG draws**, so content
   that is a person only lands in a person slot and a notice only lands in a
   wall or counter slot. Prove with the determinism probe that run RNG streams
   are untouched.
6. **Delivery handoff.** `_delivery_available_rect()` follows the same rules.
7. **Renderer.** Make `_draw_object_shadow()` class-aware: people get a foot
   shadow at the feet, fixtures a base shadow, surface items a contact shadow on
   the surface line, wall-mounted and hanging objects none. For
   `behind_counter_person`, the counter must visually occlude the lower body.
   Either clip the figure at the counter's `top_y`, or redraw the counter's front
   strip over it. **Precompute everything at layout or snapshot time; nothing per
   frame.** If you add depth scaling for back-row people, it is a layout-time size
   only, and small-screen hit rects still expand to 104×76.
8. **Drawn characters.** Audit `_draw_familiar_characters()`, the Grand Casino
   living-floor characters, `_rourke_scene_foot()`, `_rival_scene_foot()`,
   `SCENARIO_CROWD_POINTS` and the jazz players against the surface map. Fix any
   that float. Also check they do not stand inside an interactable object's rect,
   where two people would render on top of each other.

### Phase F — The re-authoring pass (the owner's third ask)

Room by room, worst first. Take the order from your Phase B inventory; expect the
bar, gas station, motel, Delta Queen and beach near the top. For each room:

1. Re-place **base spots**, keeping every July intent that is still right.
2. Re-place **semantic anchors**. Split any anchor shared between a person and a
   wall prop. Replace free-space anchors (`*_top_*`, `*_clear`, `*_work_N` used
   only to dodge collisions) with anchors named after what they are
   (`bar_rail_left`, `back_wall_floor_center`, `register_counter`,
   `stage_front`).
3. Convert zone-only placements of people and fixtures to explicit anchors
   wherever the description names a relationship.
4. Walk every phase of every scenario in the room. Check that each `move` lands
   somewhere sensible, that routes run floor to floor, and that each description
   variant is spatially true in the phases where it shows.
5. Re-run the audit for that room: zero `FLOATING` / `WRONG_SURFACE`, zero
   unexplained `SEMANTIC_MISMATCH`, zero `DISPLACED` from a correct place.

**Changing data inside a signed package** (`scene_ops` / `actor_ops` /
`declared_targets`) requires re-signing it. Use `tools/env06_8_resign_package.gd`
(`-- res://data/environments/scenario_sequences/<package>.json`), then run schema
validation. Adding or renaming anchors also changes each scenario's
`declared_targets.anchors` and the sealed semantic inventory. Run
`scripts/tests/foundation/environment_semantic_inventory_contract.gd`. **Prefer
moving an existing archetype anchor's position** when that alone fixes every
scenario that uses it; that needs no package edit.

**Capacity.** The floor band is limited by the wall base above and `WALK_LANE`
below. A crowded phase may have more people than one row holds with 104×76
expanded hit rects and non-overlapping labels. The answer is **never** to float
someone. In order of preference:

1. Use the room's real furniture: people behind counters, on stools, at
   tables, on the stage.
2. Use a back row, with feet near the wall base, and depth-scale it if you built
   that.
3. Stage the phase so fewer people are simultaneously present, where the
   scenario's own ops allow it without deleting any object.

**Deleting or hiding objects to make space is forbidden:** object counts do not
regress. If a phase genuinely cannot fit, record it with numbers and log it as an
owner question. Do not guess.

### Phase G — Permanent gates

1. **Static grounding check** in `tools/validate_project.ps1` (Phase D), green.
2. **Runtime grounding sweep:** the Phase B tool in pass/fail mode over all rooms
   × all states × 8 seed families × both layouts. It requires zero `FLOATING`,
   zero `WRONG_SURFACE`, zero base-fallback resolutions and zero class-invalid
   displacements. Register it in the `Audit`/`Full` suites of
   `tools/check_godot.ps1` next to `scenario_room_multiseed_finalization`, and add
   a `Require-Text` for it in `validate_project.ps1` the way that gate is required.
   **Do not add it to Smoke/contracts.** That stage ran 227.8 s against a
   230.4 s budget at `fix06_30`, and a budget increase needs owner sign-off.
3. **A small focused contract** proving the mechanisms stay fixed: a forced
   collision on the floor slides along the floor; a zone-only person resolves to
   feet on the floor; a person event never takes a wall slot; a wall sign never
   takes a floor slot. It must fit inside the existing contracts budget, or go in
   Audit.

## 6. Save/Continue, determinism, hidden state

- **Continue must work.** Saves carry resolved layout rects and layout authority
  digests (§4 Persistence). Before changing placement, load the fixtures in
  `scripts/tests/fixtures/integ06_1/v0_5_1/` and `mid_0_6/`, plus a save made
  mid-scenario on your baseline head. Answer: does a restored room re-derive
  placement from source, or keep the saved rects? Does a moved anchor trip a
  trusted-digest or `sequence_signature` mismatch? The desired outcome is that
  a restored room shows the **new** grounded placement. **No save-schema bump and
  no migration without the owner.** If one is unavoidable, stop, record the exact
  question under Owner Questions on the board, and pick up compatible work.
- **Determinism.** Placement is a pure function of room, content and seed. No new
  RNG draws, no wall-clock. The determinism probe may change **layout digests
  only**. Prove that and record the before/after.
- **Hidden state is absolute.** Placement must not depend on hidden state. A
  traitor, rigged draw, grievance weight or unrevealed ticket must never move,
  scale, reorder or re-slot anything. Identical seeds that differ only in hidden
  state must produce identical placement. A leak is an automatic P0.
- **The crew-ignoring run remains a true no-op.**

## 7. Acceptance

This row closes when a person can walk into any room, in any scenario and phase,
and nothing is standing in the air.

1. The Phase B floating-people inventory exists, and every entry is resolved with
   its root cause named.
2. The runtime grounding sweep passes: all rooms, all layers, baseline plus 55
   scenarios, every reachable phase, 8 seed families, normal and expanded
   layouts, reduced-motion endpoints and route endpoints. Zero `FLOATING`, zero
   `WRONG_SURFACE`, zero base-fallback resolutions, zero class-invalid
   displacements.
3. Every §1.3 role relationship holds, and every placed object's description is
   spatially true in the phases where it shows. Deviations are listed with
   reasons.
4. Every room has a committed surface map with an overlay capture.
5. The engine is class-aware in all five §3 mechanisms. Each has a focused
   proof, and none can place a grounded object in the wall band or void.
6. Before/after contact sheets for every room-state, clean and annotated. The
   report puts them side by side.
7. The `fix06_27` 440/440 multiseed gate, walk-lane, reachability, TalkDock,
   label and hit-authority guarantees are all green. Object, action and barrier
   counts are ≥ baseline.
8. The Corner Store reference is unchanged, or any change is justified by an
   audited floating person.
9. Save/Continue from the fixtures and from a mid-scenario baseline save works,
   with the §6 question answered.
10. The determinism probe changes layout digests only; RNG is untouched.
11. Hidden-state paired-observer placement is identical.
12. The idle-liveness counter-gate passes for the environment canvas, with no new
    per-frame allocation.
13. `tools/validate_project.ps1` is green on the exact head, and the `Audit`
    suite is green.
14. No change to money, RNG, RTP, payouts, odds, save schema or migration.

## 8. Hard limits

- **Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.** Relaxing the resolver's fail-closed errors so an object "fits" is
  weakening. So is widening the floor polygon to take a person who is on the
  wall. So is deleting an object. A budget crossing needs owner sign-off.
- **Never refresh a golden** without proving the content legitimately changed. A
  layout digest that moved because an anchor moved is legitimate; record which.
- **Do not change** game rules, payouts, odds, RTP, wager math, save schema,
  migration, scenario handlers, objective logic or action consequences. This
  row moves things and teaches the engine where things may stand. Nothing else.
- **Delete nothing:** no branch, worktree, stash, object, anchor that content
  still references, or prompt file. No `gc`, `reset --hard`, or `clean`.
- **Never stage owner property:** `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`.
- **Leave no diagnostics in the tree.** The overlay mode is a tool option, off
  in production.
- **No release activity:** no version bump, tag, packaging or publish.
- Do not port the stale `env06_8` contact-sheet harnesses from
  `codex/closeout06-final`; they call contract functions that no longer exist.

## 9. Standards every row inherits

- **Idle draw cost of 0.000 is a failure, not a pass.** Four recorded
  regressions froze idle room animation. The counter-gate in
  `scripts/ui/performance_liveness_guard.gd` is mandatory, and this row touches
  the renderer.
- **No per-frame deep copies.** The slot bonus watchdog once cost 32.6 ms/frame.
  Surface-map lookups, classifications and occlusion data are computed at layout
  or snapshot time and cached.
- **Action boundaries, never wall-clock.** Everything is seeded from run RNG.
- **Exactly once.** Consequences fire once across save, reload, travel, revisit,
  abort and expiry. Placement changes must not re-fire anything.
- **Native/Web parity.** Rooms place identically on both.
- Tab-indented, typed GDScript; sparse comments that state constraints, not
  narration; match the surrounding code.
- Cheap validation: `tools/validate_project.ps1`. Slow, targeted:
  `tools/check_godot.ps1 -Suite <Smoke|Contract|Audit|Full>
  [-FoundationSuite <name>]`. Godot: `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`.
  Captures run windowed (not `--headless`) where a tool reads the viewport.

## 10. Board protocol and completion

1. **Claim:** in `docs/todo/README_0_6_board.md`, set row `fix06_31` to
   `IN_PROGRESS`, fill Agent and Started, and append one line to
   `docs/todo/README_0_6_work_log_2026-08-26.md`. Commit the claim.
2. **While working:** log discoveries, deviations and decisions as `fix06_31`
   bullets in `docs/todo/README_0_6_discovery_decision_log_2026-08-26.md`. Log
   owner-only questions under Owner Questions on the board and continue with
   compatible work. Never guess on owner-locked design.
3. **If blocked:** set `BLOCKED`, give a one-line reason in Notes, log it, and
   stop or switch.
4. **On completion,** only after every gate is green and you have confirmed in a
   production-host capture that no room shows a floating person:
   - Commit in logical units: tool; surface maps; classifier and checker; engine;
     content per room; gates.
   - Fill in the Execution Record at the top of this file (date, commit hashes,
     gate results, deviations).
   - Set the row to `DONE` with a one-line verification summary.
   - `git mv` this file to `docs/todone/`. Archive it; do not delete it.
   - Append a Work Log line.
   - Merge to `main` with `main` green, and push so `origin/main` is in sync.
   - If another agent is concurrently active on `main`, work in an isolated
     worktree/branch and hold the merge.
   - On any gate failure, stop at the last green commit, do not archive or push
     `main`, and report verbatim.

## 11. Reporting

Report at the end of each phase. Lead with what a player now sees that they
didn't before. Give counts: floating people found, fixed, and remaining (must
be 0 at close). Name the rooms that were worst and why. List every judgement
call on a surface map. Give the capacity cases and how each was solved. State
anything still uncertain, with its exact question, and the `main`/`origin` sync
state. The final report links the before/after contact sheets for every room.
