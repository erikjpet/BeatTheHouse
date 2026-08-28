# env06_7 Package A — Implementation Handoff

Base: `855a2961`. Package definition:
`data/environments/scenario_sequences/env06_7_shops_streets.json`.

Each row is a runtime sequence, not a legacy choice substitution. All generated
rows have arrival, physical work, and terminal aftermath phases; two command
boundaries; ignore, refuse, interruption, success, and failure paths; partial
resume plus terminal/expired revisit policies; exactly-once authored receipts;
semantic touch targets bound to the physical task objects; reduced-motion,
small-screen, revisit, and hit-overlay capture ids; and a unique calculated
mechanic signature. Delivery Day is the frozen env06_6 reference implementation.

| Scenario | Physical progression | Material terminal identities | World seam |
| --- | --- | --- | --- |
| `corner_store_delivery_day` | inspect manifest → shift cartons → stock verification | repaired shelves / broken cooler / refused return / abandoned manifest | event, service, travel, sweep |
| `corner_store_lotto_fever` | mark queue place → verify disputed number | celebration layout / angry queue / sold-out counter | economy stock |
| `corner_store_aftermath` | trace boarded-glass evidence → recover or flag object | quiet recovery / police hold / watched aisle | security evidence |
| `corner_store_dead_shift` | isolate breaker → restore circuit or preserve darkness | lit service / private darkness / flicker lockout | rumor and surveillance |
| `corner_store_inventory_night` | compare shelf tags → recount or quarantine | reopened sections / quarantined section / closed aisles | economy inventory |
| `back_alley_street_craps` | read chalk ring → shoot → answer lookout | continuing / relocated / dispersed ring | public craps fact |
| `back_alley_cruiser_parked` | map sightline → move cover or divert patrol | departed cruiser / diverted patrol / watched route | public sweep pressure |
| `back_alley_fence_night` | inspect marks → authenticate or broker lot | verified stall / brokered exit / buyer-controlled lot | fence economy |
| `back_alley_nothing_moving` | compare three traces → follow or erase trail | follow exit / erased rumor exit / empty alley | rumor and route |
| `pawn_shop_estate_lot_day` | stage estate cart → match provenance or return lot | displayed / returned / quarantined lot | provenance economy |
| `pawn_shop_serial_check_day` | copy serial → trace record or withdraw object | disclosed hold / withdrawn stock / waiting hold | security inventory |
| `pawn_shop_sals_mood` | finish shop task → read Sal's route or close shutters | reopened counter / closed shutters / private appraisal | appraisal service |

Cheap exact check:

`Godot --headless --path <worktree> --script res://tools/env06_7_package_a_check.gd`

The check loads the production overlay catalog, requires the exact 12-id
inventory, validates all eleven newly authored schema-v2 definitions, verifies
at least two semantic changes and two command boundaries per id, and rejects
duplicate exact or normalized signatures.

Latest cheap evidence: `PASS ids=12 exact_signatures=12
normalized_signatures=12`; generation plus the independent exact check completed
in 5.6 seconds. `git diff --check` passed. Expensive project gates and visual
captures remain Integrator-owned; no shared gate, golden, budget, or owner
artifact was changed by this package.

## Assembly handoff

The assembly owner should consume this package file without giving Package A
ownership of the shared catalog/index, renderer, cross-seam fixtures, or master
reports. Street Craps consumes only the accepted game's public facts; Cruiser
Parked consumes only public sweep pressure. Any combined composition fixture
remains assembly-owned under `ffc6bbd`.
