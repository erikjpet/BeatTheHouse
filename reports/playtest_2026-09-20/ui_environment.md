# Beat the House — UI / Environment Playtest Report

Date: 2026-09-20  
Tester: `/root/ui_environment`  
Scope: environment canvases, routes, object hit authority, labels, HUD/title/header presentation, scenario overlays, Bar Dice surface layering, and Grand Casino subrooms.  
Change policy: diagnostic only; no product source or data was modified.

## Executive summary

The fresh deterministic 18-room survey exposed **16 direct base-room interaction-hitbox collisions**, plus **9 margin-only layout warnings**. Current-date production-session evidence for Bar Dead Tuesday adds **4 distinct direct scenario/base hitbox collisions**, bringing the observed direct conflict set to **20**. These conflicts are not cosmetic only: the canvas resolves an overlap by z/order and current selection, so the same screen coordinate can refer to more than one actionable object.

Four additional presentation/control defects were confirmed:

1. The Bar Dead Tuesday scenario audit reports zero normal and small-screen overlaps despite the production canvas reporting nine footprint overlaps and four true hitbox intersections.
2. Bar Dice draws patrons, wager badges, opponent cup rows, and dealer status into the same fixed regions. The issue remains across entry, roll, and idle frames.
3. Environment object labels silently drop suffixes instead of using an ellipsis or wrapping.
4. The shipped Grand Casino High-Limit title plate bitmap is itself clipped (`GRAND CASINO HIGH LIMI`).

The fresh survey covered all 18 environment archetypes available to the tool. Nine rooms had at least one direct hit conflict. Apartment, Back Alley, Beach, Delta Queen, Grand Casino Back Room, Kitty Cat Lounge, Motel Room, Pawn Shop, and Small Underground Casino had no direct hit intersections in this deterministic pass. Kitty Cat Lounge had one spacing-only warning, not a hit collision.

## Evidence and method

Fresh evidence was generated with the production app and production environment canvas using `tools/environment_layout_screenshots.gd`, seed `LAYOUT-SURVEY-QA`. The run completed normally with `LAYOUT_SURVEY_DONE 18 environments`.

- Fresh artifact root: `.tmp/playtest_2026-09-20/ui_environment/fresh_layout`
- Machine-readable report: `.tmp/playtest_2026-09-20/ui_environment/fresh_layout/layout_report.json`
- Report SHA-256: `A0C2642DB4B49F815B5A75F90D6E0ED9F70A57E568F35F96B07BE6F3569F69E7`
- Grand Casino screenshot SHA-256: `E81642EC4DDE898D2661A6F8DE66B0116CA3502BBCEED4239D43511C693F855B`
- Corner Store screenshot SHA-256: `2B535C7A3D5A16CBE20EB198593AAC7C3A1DC58B61FD64BE454159EEF7817CD3`
- Gas Station Casino screenshot SHA-256: `7007BD0FBB59983B37C76DE8479626DCE12B1193ACBD47178579C89CC6217016`

The canvas report's `overlap_count` uses footprints grown by 8 pixels (`scripts/ui/pixel_scene_canvas.gd:3388-3435`). I separately intersected the reported `interaction_rect` values. Therefore the confirmed direct-conflict count below excludes objects that only violate the desired spacing margin.

Current-date production-session evidence was also inspected at `.tmp/agent_playtest_24h_ui`. It is corroborating evidence because it predates this assignment, but it was recorded on the same date and uses production interaction commands. Bar Dice is shown in `0012.png`, `0013.png`, and `0014.png`; Bar Dead Tuesday is shown in `0016.png` and `0017.png`.

## Root-cause themes

### A. Shipping developer-placement data bypasses collision recovery

`scripts/core/environment_instance.gd:668-715` merges project/user developer placement slots and treats them as exact, free placements. At lines 703-708 they are marked `manually_placed`; line 715 only invokes collision recovery when `not manually_placed`. The checked-in file `data/environments/developer_placement_overrides.json` ships exact placements for Corner Store, Gas Station Casino, House, Motel, Bar, and Apartment. Several of those exact coordinates overlap.

This means the issue is not just contaminated local state: the project override file contains the same records as the current user override file.

### B. Exhausted automatic placement silently keeps a collision

For generated/non-manual objects, `scripts/core/environment_instance.gd:715-723` tries supported alternatives only while it can find a noncolliding candidate. If every supported candidate collides, `selected` remains the original colliding rectangle. Lines 724-736 then store it with empty `placement_errors` and `placement_fallback_ids`. Bar, Jazz Club, and parts of Grand Casino demonstrate this path.

### C. Some archetypes author two route categories into the same slot

Grand Casino High-Limit and Cage define both local casino-door spots and generic travel spots at the same coordinates (`data/environments/archetypes.json:3978-3993` and `4378-4389`). Those independent categories become separate controls with overlapping hit authority.

### D. Scenario validation deliberately suppresses all overlap accounting in any developer-placement room

`scripts/core/scenario_layout_resolver.gd:824-847` skips ambiguous scenario/base hit checks for developer-placed rooms. More decisively, `_overlap_count` returns zero immediately when any developer placement exists (`scripts/core/scenario_layout_resolver.gd:1620-1643`). Since Bar has checked-in project overrides, the production audit cannot report its real overlaps.

## Confirmed direct base-room interaction conflicts

All reproduction steps in UIE-001 through UIE-016 are: run the deterministic environment layout survey, open the named PNG, then inspect the matching pair in `layout_report.json`. Expected: actionable objects have nonintersecting hit regions and distinct visual authority. Actual: the reported interaction rectangles intersect by the listed area.

### UIE-001 — Bar ticket redeemer and slot share hit authority

- Severity: High
- Room/evidence: `bar.png`; `game_hook:pull_tabs:ticket_redeemer` ↔ `game:slot`
- Direct intersection: **2,436 px²**
- Root cause: Bar authored slots are dense (`data/environments/placement_surfaces.json:41`). The ticket redeemer is automatically moved but the non-manual recovery path accepts the colliding selection after no supported alternative succeeds (`environment_instance.gd:715-736`).
- Fix options: add a valid nonoverlapping behind-counter candidate; move one authored slot; or make unresolved collision a placement error instead of silently accepting it.

### UIE-002 — Corner Store Odds Notebook and Trunk overlap

- Severity: High
- Evidence: `corner_store.png`; `item:odds_notebook` ↔ `item:trunk`
- Direct intersection: **3,360 px²**
- Root cause: the shipped category override for `item_spots:1` places an item at `[189,144]` (`developer_placement_overrides.json:87`); manual placement bypasses collision recovery and lands on the trunk.
- Fix options: move the notebook/trunk; validate checked-in overrides; reject promotion of overlapping developer placements.

### UIE-003 — Corner Store Late Shift Discount and merchant overlap

- Severity: High
- Evidence: `corner_store.png`; `event:late_shift_discount` ↔ `shopkeeper:merchant`
- Direct intersection: **2,304 px²**
- Root cause: `event_spots:1` and the merchant have conflicting checked-in developer coordinates (`developer_placement_overrides.json:75`, `113`), and manual coordinates bypass recovery.
- Fix options: separate the event and cashier counter person; reserve the merchant footprint; gate project overrides with direct-hit validation.

### UIE-004 — Corner Store Late Shift Discount and Cashier Tip overlap

- Severity: Medium
- Evidence: `corner_store.png`; `event:late_shift_discount` ↔ `service:cashier_tip`
- Direct intersection: **228 px²**
- Root cause: the exact event override is accepted without testing later/generated service authority (`environment_instance.gd:703-715`).
- Fix options: move the event; create a dedicated late-shift service slot; rerun collision packing after all manual and generated entries are assembled.

### UIE-005 — Corner Store merchant and Cashier Tip overlap

- Severity: High
- Evidence: `corner_store.png`; `shopkeeper:merchant` ↔ `service:cashier_tip`
- Direct intersection: **525 px²**
- Root cause: the merchant's checked-in exact override (`developer_placement_overrides.json:113`) does not reserve space against the generated service.
- Fix options: merge Cashier Tip into the merchant action panel; move its prop; or enforce a project-override collision gate.

### UIE-006 — Gas Station Pull Tabs and Scratch Tickets overlap

- Severity: High
- Evidence: `gas_station_casino.png`; `game:pull_tabs` ↔ `game:scratch_tickets`
- Direct intersection: **994 px²**
- Root cause: checked-in exact positions `[430,126]` and `[526,127]` are closer than the two 110×72 game controls can support (`developer_placement_overrides.json:161-168`).
- Fix options: increase horizontal separation; reduce only the art footprint while preserving 44-pixel minimum targets; fail override promotion on intersection.

### UIE-007 — Gas Station drink and numbers book overlap

- Severity: High
- Evidence: `gas_station_casino.png`; `service:house_drink` ↔ `numbers:book`
- Direct intersection: **378 px²**
- Root cause: checked-in exact positions `[170,186]` and `[71,183]` bypass collision recovery (`developer_placement_overrides.json:173-180`).
- Fix options: move either counter service; combine them into a shared clerk surface; validate direct hit rectangles before shipping.

### UIE-008 — Gas Station Parking Lot Tip and Side Door overlap

- Severity: Medium
- Evidence: `gas_station_casino.png`; `event:parking_lot_tip` ↔ `event:side_door`
- Direct intersection: **63 px²**
- Root cause: category overrides for successive event slots are placed at `[693,344]` and `[792,345]` (`developer_placement_overrides.json:127-134`); category overrides take precedence over object overrides at `environment_instance.gd:699-705`.
- Fix options: move the side door to its dedicated doorway slot; treat doors as reserved; prevent category overrides from silently superseding a safer object-specific coordinate.

### UIE-009 — Grand Casino slot bank controls overlap

- Severity: Medium
- Evidence: `grand_casino.png`; `game:slot` ↔ `game:slot:2`
- Direct intersection: **144 px²**
- Root cause: authored slot coordinates are only 126 pixels apart (`placement_surfaces.json:381-383`) while support correction produces 110-pixel controls plus intended spacing; the fallback path stores a collision without an error.
- Fix options: widen the bank spacing; render one bank control for multiple cabinets; surface exhausted placement as a generation error.

### UIE-010 — Grand Casino Back Room route overlaps Blackjack

- Severity: Critical
- Evidence: `grand_casino.png`; `travel:grand_casino_back_room` ↔ `game:blackjack`
- Direct intersection: **128 px²**
- Impact: a navigation control and a wagering game claim the same pointer area.
- Root cause: route `[0,176]` and blackjack `[120,176]` are adjacent authored slots (`placement_surfaces.json:385-387`); support correction and final sizes still intersect, but the resolver records no placement error.
- Fix options: reserve a route rail; move blackjack; make route/game intersections fatal in content validation.

### UIE-011 — Grand Casino Craps overlaps ticket redeemer

- Severity: High
- Evidence: `grand_casino.png`; `game:craps` ↔ `game_hook:pull_tabs:ticket_redeemer`
- Direct intersection: **170 px²**
- Root cause: dense authored positions (`placement_surfaces.json:385-386`) exhaust available compatible surfaces and the unresolved collision is stored as valid.
- Fix options: relocate redeemer to a cashier/fixture zone; add another supported floor surface; report/fail exhausted collision placement.

### UIE-012 — Grand Casino Cage Main Floor and Leave routes overlap

- Severity: Critical
- Evidence: `grand_casino_cage.png`; `travel:grand_casino` ↔ `travel:leave`
- Direct intersection: **1,044 px²**
- Root cause: Cage authors the local casino door and generic travel spot at the same `[824,350]` coordinate (`archetypes.json:4378-4389`).
- Fix options: remove redundant Leave in this subroom; give each route a unique slot; display a single route selector when destinations share a doorway.

### UIE-013 — Grand Casino High-Limit Cage and Leave routes almost completely overlap

- Severity: Critical
- Evidence: `grand_casino_high_limit.png`; `travel:grand_casino_cage` ↔ `travel:leave`
- Direct intersection: **5,824 px²**
- Impact: the two orange arrows are drawn nearly on top of one another, making mouse authority and destination legibility unreliable.
- Root cause: High-Limit room authors `casino_door_spots[1]` and `travel_spots[0]` both at `[808,350]` (`archetypes.json:3978-3993`).
- Fix options: remove redundant Leave; split door positions; render a single doorway with explicit destination choices.

### UIE-014 — House Storage Spot and Trunk overlap

- Severity: High
- Evidence: `house.png`; `home_storage:place` ↔ `home_container:trunk_01`
- Direct intersection: **810 px²**
- Root cause: exact project overrides `[320,293]` and `[231,297]` conflict (`developer_placement_overrides.json:219-230`) and manual placements bypass collision recovery.
- Fix options: move the controls; represent Storage Spot as a panel action on the trunk; validate project overrides.

### UIE-015 — Jazz Club Cello Round and ticket redeemer overlap

- Severity: Medium
- Evidence: `jazz_club.png`; `service:jazz_cello_round` ↔ `game_hook:pull_tabs:ticket_redeemer`
- Direct intersection: **252 px²**
- Root cause: dense authored service/wall placements (`placement_surfaces.json:131-132`) leave no valid alternative; the automatic path silently accepts a collision (`environment_instance.gd:715-736`).
- Fix options: move the redeemer to the bar; add a dedicated supported wall slot; fail unresolved placement.

### UIE-016 — Motel Parking Lot Tip and Malik Stone overlap

- Severity: High
- Evidence: `motel.png`; `event:parking_lot_tip` ↔ `lender:motel_friend`
- Direct intersection: **936 px²**
- Root cause: exact project overrides `[33,345]` and `[115,357]` conflict (`developer_placement_overrides.json:235-254`) and bypass recovery.
- Fix options: move lender/tip; sequence one through dialogue instead of separate floor props; validate promoted overrides.

## Confirmed direct scenario conflicts (current-date production session)

Reproduction used the current-date session sequence recorded in `.tmp/agent_playtest_24h_ui`: start a run, leave, travel to Bar, enter/exit Bar Dice, open the Bar Dead Tuesday task. `0016.result.json` and `0017.result.json` identify scenario `bar_dead_tuesday`. The production room canvas reports nine footprint overlaps; four are direct interaction intersections.

### UIE-017 — Bar Rowdy Regular and Bar Dice overlap under Dead Tuesday

- Severity: Critical
- Evidence: `.tmp/agent_playtest_24h_ui/0016.png`; `event:rowdy_regular` ↔ `game:bar_dice`
- Direct intersection: **3,920 px²**
- Root cause: checked-in developer override moves Bar Dice to `[65,146]`, while the base Rowdy Regular remains at `[77,178]` (`developer_placement_overrides.json` Bar section; `placement_surfaces.json:41`). Project developer placement is accepted as authoritative.
- Fix options: move Bar Dice back to a machine zone; reserve its footprint against base events; reject intersecting project overrides.

### UIE-018 — Coin Pusher and Dead Tuesday Patron Zone overlap

- Severity: High
- Evidence: `0016.png`; `game:coin_pusher` ↔ `scenario::bar_dead_tuesday_patron_zone`
- Direct intersection: **1,152 px²**
- Root cause: scenario slot `bar_dead_tuesday_patron_zone:[300,266]` conflicts with active base controls (`placement_surfaces.json:42`); Bar's developer-placement status suppresses normal scenario collision enforcement.
- Fix options: provide a scenario fallback slot; reserve all current base hitboxes during scenario layout; never suppress scenario/base validation for project overrides.

### UIE-019 — Pull Tabs and Dead Tuesday task control overlap

- Severity: Critical
- Evidence: `0016.png`; `game:pull_tabs` ↔ `scenario::bar_dead_tuesday_task_0`
- Direct intersection: **2,916 px²**
- Root cause: the scenario task is authored at `[316,188]` while Pull Tabs occupies the same central band (`placement_surfaces.json:41-42`); developer-room suppression allows the collision.
- Fix options: place the task in a dedicated wall slot; relocate base machine while scenario is active; enforce scenario/base interaction disjointness.

### UIE-020 — Leave and Dead Tuesday Safe Exit overlap

- Severity: Critical
- Evidence: `0016.png`/`0017.png`; `travel:leave` ↔ `scenario::bar_dead_tuesday_safe_exit`
- Direct intersection: **94 px²**
- Root cause: both controls target the right exit rail, and checked-in Bar route overrides make the whole room developer-placed. The scenario resolver therefore skips the ambiguous route check.
- Fix options: reuse one exit authority instead of drawing two; offset the scenario marker; keep route-vs-route intersections fatal even in developer placement mode.

## Additional confirmed defects

### UIE-021 — Scenario layout audit falsely reports a clean room

- Severity: Critical
- Frequency: 100% in the captured Bar Dead Tuesday state
- Evidence: `0016.result.json` reports `room_canvas.object_layout.overlap_count=9`, while `scenario_layout_audit.normal_overlap_count=0`, `small_screen_overlap_count=0`, `collision_adjustment_count=0`, and `valid=true`.
- Root cause: `_overlap_count` returns zero for the entire room when any developer placement exists (`scenario_layout_resolver.gd:1620-1643`). Related validation loops also skip developer-placed targets/rooms (`824-847`). Checked-in project overrides therefore disable safety gates in ordinary production content, not merely an editor preview.
- Fix options: distinguish temporary user freeform edits from shipped project data; always calculate and report overlaps even if nonfatal; make route and actionable control collisions nonwaivable.

### UIE-022 — Bar Dice fixed patron chrome overlaps opponent cups and dealer readout

- Severity: High
- Frequency: reproduced in three consecutive current-date frames: entry (`0012.png`), after roll (`0013.png`), and idle (`0014.png`)
- Steps: enter Bar Dice at Roadside Bar; inspect the four patrons and three `RAIL CUPS` rows; roll once and wait.
- Expected: patron names/tells/wager badges, opponent dice rows, and dealer attention readout occupy separate readable regions.
- Actual: left patron chrome and wager affordances overprint `RAIL CUPS` and opponent rows; right patron chrome/wager UI collides visually with dealer meters/readout. Text and neon panels remain layered through roll and idle.
- Root cause: all geometry is fixed and drawn in one pass. Patron bases are `(94,84)`, `(236,70)`, `(660,70)`, `(808,84)` and opponent rows start at `(76,150)`, `(76,202)`, `(76,254)` (`scripts/games/bar_dice.gd:64-80`). Patrons and dealer are drawn before dice rows (`552-564`). Patron wager badges start at `pos + (-40,88)` and extend further for WITH/FADE controls (`scripts/games/table_game_visuals.gd:265-299`). Opponent panels are 164×48 at the fixed row origins (`bar_dice.gd:3191-3208`). No collision/layout phase relates these structures; `_bar_dice_layout_snapshot` only publishes text panels and broad patron safe rectangles (`3475-3500`).
- Fix options: allocate explicit nonoverlapping columns for patrons/opponents/dealer; move wager controls to the console; add a layout contract that intersects all fixed surface regions and fails on collision.

### UIE-023 — Object labels silently truncate without ellipsis

- Severity: Medium
- Evidence: fresh `gas_station_casino.png` shows `Gas Station Casino Numbers B`; current-date `0017.png` shows `Bar Dead Tu`. The full identities remain different from the visible labels.
- Expected: long labels wrap, scale, or show an ellipsis/tooltip so the truncation is perceptible.
- Actual: trailing characters disappear, creating ambiguous names.
- Root cause: object label width is hard-capped at 126 pixels (`pixel_scene_canvas.gd:92`, `5059-5068`). `_fit_draw_text` removes one trailing character at a time until the text fits and returns the bare prefix with no ellipsis (`3878-3896`); `_draw_object_label` renders it directly (`5336-5352`).
- Fix options: reserve ellipsis width; expose full tooltip/accessibility text; allow a two-line label for long route/source names.

### UIE-024 — Grand Casino High-Limit title plate asset is clipped

- Severity: Medium
- Frequency: 100%
- Evidence: fresh `grand_casino_high_limit.png` and source asset `assets/art/ui/environment_titles/grand_casino_high_limit.png` both end at `GRAND CASINO HIGH LIMI`.
- Root cause: the bitmap itself contains clipped text. `EnvironmentHeader` uses title art by default (`scripts/ui/environment_header.gd:28-37`) and the High-Limit config does not opt into text mode (`data/ui/environment_ui.json`). The texture widget preserves aspect rather than generating accessible visible text (`environment_header.gd:87-101`).
- Fix options: regenerate the asset with adequate right padding; use `title_mode:text` for long titles; add asset-content bounds visual QA.

### UIE-025 — Corner Store resolved label still covers another actionable object

- Severity: Low
- Evidence: fresh report: `corner_store.canvas_object_layout.label_layout.resolved_object_overlap_count=1`; the resolved label for `event:late_shift_discount` intersects `service:cashier_tip` by 15 px².
- Root cause: the label resolver removes label-label collisions but cannot fully satisfy the crowded manual object layout; it accepts one label-object collision. The underlying checked-in placements already overlap.
- Fix options: resolve the object positions first; permit another label row; hide labels until focus when density exceeds the layout budget.

## Margin-only diagnostics (not counted as direct hit conflicts)

The following footprint pairs violate the desired 8-pixel spacing but have zero direct interaction-rectangle area. They should remain layout warnings, not be presented as confirmed hit ambiguity:

- Corner Store: `event:call_brother_in_law` ↔ `event:late_shift_discount`
- Corner Store: `event:call_brother_in_law` ↔ `shopkeeper:merchant`
- Corner Store: `item:neon_players_charm` ↔ `item:odds_notebook`
- Grand Casino: `game:slot` ↔ `event:comped_suite_offer`
- Grand Casino: `game:slot:2` ↔ `event:comped_suite_offer`
- Grand Casino: `game:slot:3` ↔ `event:chain06_cass_first_contact`
- Grand Casino: `game:video_poker` ↔ `event:chain06_cass_first_contact`
- Grand Casino: `game:blackjack` ↔ `travel:grand_casino_high_limit`
- Kitty Cat Lounge: `service:kitty_burlesque_show` ↔ `event:grand_casino_invite`

Dead Tuesday also has five footprint-only scenario warnings (ticket redeemer/bartender, numbers/bartender, pull-tabs/bartender, pull-tabs/patron-zone, bartender/task). They are visually crowded but do not add to the direct hit-conflict count.

## Coverage matrix

| Environment | Objects | Direct hit conflicts | Margin-only warnings | Result |
|---|---:|---:|---:|---|
| Apartment | 5 | 0 | 0 | Pass |
| Back Alley | 10 | 0 | 0 | Pass |
| Bar | 9 | 1 | 0 | Fail |
| Beach | 4 | 0 | 0 | Pass |
| Corner Store | 14 | 4 | 3 | Fail |
| Delta Queen | 11 | 0 | 0 | Pass |
| Gas Station Casino | 9 | 3 | 0 | Fail |
| Grand Casino | 17 | 3 | 5 | Fail |
| Grand Casino Back Room | 3 | 0 | 0 | Pass |
| Grand Casino Cage | 4 | 1 | 0 | Fail |
| Grand Casino High-Limit | 7 | 1 | 0 | Fail |
| House | 5 | 1 | 0 | Fail |
| Jazz Club | 12 | 1 | 0 | Fail |
| Kitty Cat Lounge | 14 | 0 | 1 | Pass with spacing warning |
| Motel | 9 | 1 | 0 | Fail |
| Motel Room | 5 | 0 | 0 | Pass |
| Pawn Shop | 11 | 0 | 0 | Pass |
| Small Underground Casino | 5 | 0 | 0 | Pass |

## UI interaction and overlay pass list

- Standard 16:9 HUD/top bar remained on-canvas across all 18 fresh room captures.
- Environment labels were moved to avoid label-label collisions in all 18 rooms (`resolved_label_overlap_count=0`). Corner Store retained one label-object collision.
- Grand Casino Back Room, Cage, and High-Limit all rendered; no room failed to load.
- The High-Limit and Cage route controls rendered but failed unique hit authority as documented.
- Production Bar Dice entry, roll, wait, and return all executed. The surface remained operable despite the layered readability defect.
- Current-date inventory and map overlays opened/closed in the archived production sequence without a recorded blocking failure.
- Small-screen scenario safety cannot be trusted from the reported audit in developer-placement rooms because UIE-021 forces both counts to zero. No fresh independent small-screen image matrix was run during this subtask due the shared single-Godot runtime gate; historical screenshots were not promoted to fresh confirmation.

## Recommended triage order

1. Fix UIE-021 first so automated and runtime audits expose real collisions instead of returning false zeroes.
2. Fix route-vs-route/game conflicts UIE-010, UIE-012, UIE-013, UIE-017, UIE-019, and UIE-020 because they create destination/action ambiguity.
3. Validate and clean the checked-in developer placement file, covering UIE-002 through UIE-008, UIE-014, and UIE-016.
4. Make automatic placement failure explicit, covering UIE-001, UIE-009, UIE-011, and UIE-015.
5. Re-layout Bar Dice (UIE-022), then address label/title legibility (UIE-023 through UIE-025).

## Count reconciliation

An interim note incorrectly said the fresh base survey had 19 direct conflicts. The audited number is **16 direct base-room intersections**. The current-date Dead Tuesday state adds **4 distinct direct scenario intersections**, for **20 direct intersections across all evidence in this report**. The fresh base footprint diagnostic reports 25 pairs total; nine of those are spacing-only and are listed separately above.
