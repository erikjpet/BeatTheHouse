## Execution Record

Completion date: 2026-07-07

Commit hash(es): not committed in this run. The shared workspace already had
unrelated dirty work, including pre-existing edits in `data/environments/archetypes.json`
and multiple docs/todo moves, so this task was left as local changes for the
owner to partition safely.

Verification gates:
- `.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe --path . --script res://tools/environment_layout_screenshots.gd -- --out=D:\Projects\Beat-The-House\.tmp\layout_survey_semantic_final` -> `LAYOUT_SURVEY_DONE 14 environments`.
- Parsed `.tmp\layout_survey_semantic_final\layout_report.json` -> `NO_OVERLAPS`.
- Parsed mapped object centers against authored layout spots -> `NO_FALLBACK_BUMPS_FOR_MAPPED_OBJECTS`.
- `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1` -> `Beat the House foundation architecture validation passed.`

Implementation summary:
- Bar: added a second pull-tab hook spot on the bar service counter so the ticket redeemer no longer falls into the Leave exit while the dialogue clerk remains at the approved service-end anchor.
- Gas Station Casino: added a second pull-tab hook spot along the lower service counter, keeping the dialogue clerk near the register/cage and the redeemer away from the Leave exit.
- Jazz Club: added a second pull-tab hook spot on the bar/stage-side service area so the ticket redeemer is no longer bumped into the entrance/Leave object.
- Other environments were verified by the final survey with no authored-spot fallback bumps or overlap corrections required.

Deviations:
- `docs/todo/QUEUE.md` still marked this prompt blocked because beach work had once touched archetypes/routes. That blocker is obsolete in the current tree (`docs/todone/beach_environment_prompt.md` exists), and the owner explicitly requested finishing this prompt.
# Agent Prompt — Semantic Placement of Environment Objects (All Archetypes)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4 GDScript casino roguelike (Windows, local Godot at `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`). Your task is to reposition every interactable object in every environment so it sits **where that object would physically be in the scene** — on, next to, or logically attached to the background art that represents it — instead of the current arbitrary grid positions.

## The placement philosophy (follow this in every room)

Each environment scene is hand-drawn immediate-mode art with props at fixed coordinates. Objects must be placed so the clickable object and the drawn art tell one story:

- **Games go on their machine/table art.** The pull-tabs game belongs on the drawn PULL TABS machine, the slot game on a drawn slot cabinet, blackjack/roulette/baccarat on the drawn felt tables, bar dice on the bar counter. If a scene draws multiple decorative cabinets, put the clickable game on one of them.
- **Game hooks attach to their parent.** The pull-tab ticket redeemer goes beside the pull-tab machine or at the bar/cage where a clerk would redeem tickets — never floating in open floor.
- **Items go on retail surfaces.** Shelves, counters, display cases, a bedspread in the motel — wherever the scene's "goods" surface is. Cluster them like stocked merchandise (rows), not scattered.
- **Shopkeeper stands behind their counter.** Merchants belong behind the register/counter art, facing the room.
- **Services go where the service happens.** Drinks at the bar taps/coolers/bottle art, a stage show at the stage, a deck walk at the deck railing, musician tips at each musician's feet.
- **Lenders lurk at the edges.** Pawn counters, back corners, shadowy tables — the periphery, not center stage.
- **Travel goes at doors/exits.** The Leave object belongs on the drawn door, archway, gangway, or exit sign side of the room.
- **Events go where their fiction happens.** Events rotate per run, so event *slots* should sit at generic narrative anchors: near the entrance/side door, at the payphone or counter, next to patron silhouettes, in the parking-lot/back-of-room area. Spread them so any event drawn there reads naturally.
- **Prestige goes somewhere prominent but out of the way** — a high sign, back wall, VIP corner.

The **Corner Store** archetype has already been laid out this way and approved by the owner — treat its `layout` block in `data/environments/archetypes.json` as the reference example and **do not modify it**. Items sit in rows on the shelf unit, cashier tip / shopkeeper / an event slot sit left-to-right along the register counter, the drink service sits on the coolers, events and lenders occupy the open floor anchors, travel stays on the exit.

## Where placement lives (mechanics you must respect)

- **Authored spots**: `data/environments/archetypes.json` → each archetype's `layout` object holds per-type spot lists: `game_spots`, `event_spots`, `item_spots`, `shopkeeper_spots`, `game_hook_spots`, `travel_spots`, `service_spots`, `lender_spots`, `prestige_spots`. Each spot is `[x, y]` = the object's **center** in board space **900 × 430** (x: 0 left → 900 right; y: 0 top → 430 floor). The file is `json.dumps(indent=2)`-formatted; edit it programmatically so the diff stays clean.
- **Slots are index-based, not content-based.** Whatever event/item/lender is drawn first each run occupies spot `[0]`, and so on. Games map by the order of the environment's `game_ids` (verify per archetype in the survey report — see below). So you are placing "event slot 2", not "rowdy_regular".
- **Resolution order** (`scripts/core/environment_instance.gd::ensure_generated_layout`): games → events → items → shopkeeper → travel → services → lenders → game hooks, each taking its authored spot unless it **collides**, in which case it silently falls back to a generic grid slot — which destroys your layout without erroring.
- **Collision rule** (`_rects_overlap_with_layout_gap`): both rects are padded 8px on every side. Two objects stay put only if their centers are at least `(width_a + width_b) / 2 + 16` apart horizontally **or** `(height_a + height_b) / 2 + 16` apart vertically. Exact-boundary spacing is float-fragile — leave 2–4px of slack.
- **Object footprint sizes** (from `foundation_main.gd::_normalized_interaction_rect`): game 118×72, event 100×64, item 90×54, shopkeeper 108×70, game_hook 104×58, travel 118×64, service 96×54, lender 102×58, prestige 112×58. Practical center-to-center minimums: item↔item 107, game↔game 135, most mixed pairs 105–125.
- Keep every spot list at least as long as the max count that archetype can generate (`game_count`, `event_count`, `item_count`, pool sizes); add 1 spare spot for events/items where floor space allows, positioned so the spare also reads sensibly.

## Where the scene art lives (how you find the landmarks)

Every room's background is drawn in `scripts/ui/pixel_scene_canvas.gd` — one `_draw_scene_*` function per `scene_type`, with all props at literal board coordinates. **Read the draw function for each scene and inventory its landmarks before placing anything.** Examples already identified: the bar scene draws its counter and machines around y≈192; the jazz club draws a PULL TABS machine + neon at roughly x 596–840 / y 160–200 and three musicians at x 178/322/466; the kitty cat lounge draws a house wheel at (704, 274); the delta queen draws two decorative slot cabinets at `Rect2(626,132,76,124)` and `Rect2(724,132,76,124)`; the gas station draws a row of slot cabinets starting near x≈122 at y 122; the grand casino draws a slot wall at y≈124. Confirm these and find the rest (doors, bars, stages, counters, tables, phones, coolers) by reading the code — do not guess from screenshots alone.

Where a scene draws a *decorative* machine that matches a real game (e.g. the gas station's painted slot cabinets vs. the clickable slot game), place the clickable game **on** the decoration so they merge visually.

## Verification loop (required after every batch of edits)

A survey tool already exists: `tools/environment_layout_screenshots.gd`. Run it windowed (it cannot run headless — it reads the viewport texture):

```
.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe --path . --script res://tools/environment_layout_screenshots.gd -- "--out=<absolute output dir>"
```

It boots the real app, forces all 10 archetypes, and writes one PNG per environment plus `layout_report.json` containing every resolved object center. After each run:

1. **Check for fallback bumps**: every object's resolved center in `layout_report.json` must equal your authored spot. Any mismatch means the collision rule relocated it — fix the spacing and re-run. Zero tolerance: a bumped object is a failed placement.
2. **Look at the PNGs** and judge each room against the philosophy above: does every object sit on/next to its art? Are labels readable (labels render ~35px above the object's top edge — don't tuck objects so high that labels clip, y-centers above ~55 risk clipped labels)?
3. Iterate until all 9 remaining archetypes (corner_store excluded) pass both checks.

## Scope and constraints

- Edit **only** the `layout` blocks in `data/environments/archetypes.json` (all archetypes except `corner_store`) — do not touch scene art, generation logic, pools, or counts.
- Do not reorder or rename spot fields; keep `prioritize_service_spots` flags as-is (jazz_club uses it so its six services claim spots before items).
- The board margin clamp is 16px — keep object rects inside x 16–884, y 16–414; a 118-wide object's center can't exceed x≈825.
- Check `scripts/tests/foundation_check.gd` for assertions that pin any current spot coordinates (e.g. overlap/containment QA like `r100_environment_no_overlap`); if a test hard-codes old positions, update the test to the new intended layout. Do not run the full QA suite repeatedly — the survey tool plus one final targeted check is enough.
- Deliverable: updated `archetypes.json`, a final survey run with all environments clean (no bumps), and a short per-room summary of what went where and which landmark it's anchored to.

## Per-room intent notes (owner's direction, from the approved corner-store session)

- **back_alley / motel** (shops): items belong on the folding table / bedspread art; shopkeeper behind their counter; lenders and events split between the alley shadows / parking area and doorways; drink service near the bottle art.
- **bar**: three games spread along the bar counter and machine art (pull tabs on the PULL TABS art); ticket redeemer at the bar's service end; drink at the taps; events at the side door and among patron tables.
- **gas_station_casino**: clickable games merged onto the painted cabinet row; redeemer at the register cage; drink at the coolers; events at the parking-lot window and side door.
- **small_underground_casino**: games on the felt tables/cabinet; drink near the bottles; lenders in the guarded back corners; travel on the exit; events near the door and patrons.
- **jazz_club**: pull tabs on the PULL TABS machine at the bar; redeemer beside it; the three musician-round services at their musicians; tip jar and "stay for the set" at the stage tables; shopkeeper and item at the bar counter; travel at the entrance.
- **kitty_cat_lounge**: roulette near the house-wheel art if it reads as the wheel, otherwise on a table; champagne/burlesque services at the stage side; lenders at the periphery; events at the side door and floor.
- **delta_queen**: table games on the drawn tables; video poker/slot on the cabinet pair; deck-walk service at the deck railing (bottom band); travel at the gangway.
- **grand_casino**: six games across the slot wall and the two pit tables; drink service by the chandelier bar, **not** inside the GRAND sign; event and leave at the ropes/exit.
