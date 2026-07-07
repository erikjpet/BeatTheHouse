## Execution Record

- Completion date: 2026-07-06.
- Implementing commit hash(es): shipped in `c9a719d` ("log #3.3", version
  stamped 0.3.3) — starting home locations (apartment/motel_room/house),
  containers, world map travel, and home/container art all landed there.
- Verification gates: no per-prompt gate run was recorded; the work shipped
  as part of the owner's manual 0.3.3 release. Known outstanding red gate at
  archive time: `ui_scene_compile` crash (exit -1) disclosed in
  playtest_root_fix_agent_prompt.md's execution record.
- Deviations: executed piecemeal across multiple sessions without a formal
  claim, then released directly by the owner (devlog #3.3) rather than
  through the queue lifecycle. This record was reconstructed by the PM
  during 2026-07-06 queue maintenance.

# Agent Prompt — "Home" Environment System (Apartment / Motel Room / House), Containers, Rent, and Game Clock

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4 GDScript casino roguelike (Windows; local Godot at `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`). You are implementing a new **home environment system**. Today a new run drops the player into a random start shop (archetypes flagged `is_start` in `data/environments/archetypes.json`, picked in `RunGenerator._start_archetypes` at scripts/core/run_generator.gd:196 and used by the world-map builder in scripts/core/world_map.gd:~580/709). Instead, every run must begin in the player's **home**, and homes come in selectable/randomized types.

Design for modularity first: home types are **data-defined**, and adding a fourth type later must require only a new data block + scene art, no new branching logic. The three initial types are `apartment`, `motel_room`, and `house`.

## 1. Home type framework

- Add a `kind: "home"` archetype family in `data/environments/archetypes.json` (existing kinds: `shop`, `casino`). Each home archetype carries a `home_profile` block that fully describes its rules, e.g.:
  - `starting_cash: [min, max]` (inclusive roll, seeded RNG)
  - `starting_items: <count>` (random items granted to the player's belongings)
  - `starting_containers: [...]` (containers spawned in the home, each optionally with `contains_random_items: <count>`)
  - `tenure: { type: "stay" | "rent", ... }` — see §4 (motel uses a prepaid stay; apartment/house use rent cycles)
- The generation path must flow through the existing pipeline: `EnvironmentInstance.from_archetype(...)` + `ensure_generated_layout(...)` + `run_state.set_environment(...)` — do not invent a parallel environment loader. The world map must place the home as the run's start node (replace the `is_start` shop start; decide whether home archetypes take over the `is_start` flag or a new `is_home_start` flag — keep whichever reads cleaner, but the old random-shop start must be gone).
- Travel: leaving home leads into the normal world (the same first-hop targets shops/casinos get today). The home remains a revisitable world node while the player still has tenure (see §4).
- **Acts**: there is currently no act construct in the code (Act 1 was a content milestone, not a runtime state). Implement a single entry point — e.g. `RunState.begin_act(act_index)` or a host-level `return_home_for_new_act()` — that re-homes the player (spawns them back at their home node, or generates a new home if the previous one was lost). Wire run start through it as act 1, and leave the act-transition trigger itself as a documented TODO hook; do not invent act progression rules.

## 2. Main-menu selection (mirrors content groups)

The start screen already has a run-configuration affordance: the gear button + content-group panel built in `_build_content_group_controls` (scripts/ui/foundation_main.gd:~2491–2601, state in `selected_content_group_ids`, persisted via UserSettings). Add a **Home type** selector alongside it:

- Options: `Random` (default) + one entry per home archetype, discovered dynamically from the loaded archetype list (never hardcode the three ids in the UI).
- Persist the choice like content groups do (scripts/core/user_settings.gd), and honor it in the run-start path (`start_foundation_run` / `_on_start_pressed` at foundation_main.gd:~7823). `Random` = seeded pick from available home archetypes so runs stay deterministic per seed.

## 3. The three initial home types (exact specs)

All random rolls use the run's seeded RNG (via `run_state.create_rng()` — determinism per seed is a project invariant).

**Motel room** (`motel_room`)
- Player spawns **inside the room**, which is a sub-environment of the motel: the room is its own small environment whose exit leads into the existing `motel` archetype environment (reuse the motel scene/archetype as the "lobby" hop; onward travel happens from the motel, and re-entering the room is a travel/door object inside the motel). Model the room↔motel link through the existing travel/world-node system rather than a new nesting concept — this is the first "sub environment", so keep the linkage data-driven (`parent_archetype: "motel"` or similar) for future rooms.
- Starting state: 3-day prepaid stay remaining; 1 random item as the player's belongings; cash rolled $60–$140; an **empty backpack container** (5 slots) placed in the room.

**Apartment** (`apartment`)
- Spawns in a new apartment scene. 2 random items; cash $120–$170; an empty **backpack** container present.
- Rent: due every **7 days**. The player has **3 days overdue grace**; if rent is still unpaid after the grace window, the player is **evicted**: the home node and *everything stored in it* (containers and their contents) is permanently lost, and the run continues homeless (act re-home per §1 can grant a new home later). Rent amount: data-driven in `home_profile` (pick a sensible default and mark it for tuning).

**House** (`house`)
- Spawns in a new house scene. 3 random items; a **trunk** container (10 slots) that itself contains 1 additional random item; cash $20–$80.
- Rent: first payment due in **3 days**, costs **$150**; once paid, no rent is due for another **30 days** (i.e. long-cycle rent, same eviction rules as apartment for nonpayment: 3-day grace then eviction).

Starting cash **replaces** the current fixed 100 bankroll for these runs; starting items go into the run inventory (`RunState.inventory`, scripts/core/run_state.gd:86, granted via the existing add-item path at run_state.gd:~2037).

## 4. Tenure, rent, and the day cycle

- Implement stay/rent as run-state clocks following the existing debt-clock pattern (`_advance_debt_clocks`, run_state.gd:2957) but driven by the **game clock day rollover** (§6), not action turns.
- The home environment must surface tenure as interactables/HUD: a "Pay Rent" object in the home (enabled when rent is due/overdue, pays from bankroll via the normal spend path), visible days-remaining / overdue status in the home scene and ideally on the top bar while overdue.
- Eviction and motel-stay expiry share one code path: `lose_home()` removes the world node's home access, destroys stored containers/items, sets a narrative flag, and shows a clear consequence message. For the motel, decide a minimal renewal affordance (e.g. pay per extra night at the motel counter) or let the stay simply expire — pick one, implement it data-driven, and note the decision in your summary.

## 5. Container ("bag") item system

New item category: **containers**. Initial tiers, purchasable in shops later in the game (add them to appropriate archetype `item_pool`s and `data/items/` definitions with prices scaling by tier):

| id | capacity |
|---|---|
| `bag` | 3 |
| `backpack` | 5 |
| `suitcase` | 7 |
| `trunk` | 10 |

Rules:
- A purchased container becomes a normal inventory item; **placing** it happens at home: while in the home environment the player can place a container, which converts it into a home fixture object (interactable) with its own storage.
- Placed containers expose a **transfer UI**: move items from run inventory into the container and back, respecting capacity. Follow the existing popup/panel idioms in foundation_main.gd (e.g. the run-inventory popup) rather than inventing a new UI framework; interaction goes through the home environment's interactable objects (the same object/focus/double-click system rooms already use — see `_make_interactable_object` and the object-type spot system).
- Stored items are **not** in the run inventory: their passive effects must not apply while stashed (verify against `RunState` item-effect summation, run_state.gd:~2060), and they are lost on eviction.
- Persist container placement + contents in the environment/world-node data so revisits and save/load round-trip them (`run_state.to_dict()`/`from_dict()` and the world map's stored environments in run_generator.gd:~96–104).

## 6. Game clock (new time system)

- Add a persistent **game clock**: 1 in-game hour passes every **15 real seconds** (so a day = 6 real minutes). Display it in the top HUD bar (where bankroll/heat/drink live in foundation_main.gd's top bar) as `H AM/PM` (e.g. `3 PM`); include the day number in the home/tenure displays.
- The clock ticks only during active play: environment and game-surface screens. It pauses on the start menu, pause/settings menus, and blocking popups. Drive it from the host `_process` with an accumulator — do not add per-frame allocations (project invariant: per-frame paths stay zero-copy; see the slot-watchdog regression history).
- Persist clock state (total elapsed in-game minutes + derived day) in `RunState` save data; day rollovers fire the tenure clocks in §4. Keep the existing turn-based `simulation_msec` / `advance_environment_turns` machinery untouched — the wall-clock is a new parallel system, and nothing deterministic (RNG, event cadence) may consume it. Rent consequences triggered by the clock must still resolve through normal, save-safe state mutations.
- Start each run at a fixed, data-driven start time (e.g. 8 AM day 1) so runs with the same seed still look identical at start.

## 7. Scenes, layout, and art

- New `scene_type` drawings are needed in scripts/ui/pixel_scene_canvas.gd for `apartment`, `house`, and the motel **room interior** (the motel exterior scene already exists). Follow the existing hand-drawn immediate-mode style (`_draw_scene_*` functions, board space 900×430) — simple readable rooms are fine (bed/couch, shelf, door, window).
- Author `layout` spot lists for each home archetype using the **semantic placement philosophy** (docs/plans/environment_semantic_layout_prompt.md): items on shelves/surfaces, containers on the floor/against walls, the rent-payment object at a door/counter, travel on the exit door. Respect the collision rule — objects need `(w1+w2)/2 + 16` center separation horizontally or the vertical equivalent, or the layout engine silently relocates them (footprint sizes and the rule are documented in that prompt).
- Verify layouts with the existing survey tool: `tools/environment_layout_screenshots.gd` (run windowed, not headless; it writes per-environment PNGs + `layout_report.json` with resolved centers — every resolved center must equal your authored spot). Extend the tool if needed so it can also capture the new home archetypes (it iterates `library.environment_archetypes`, so data-driven homes should appear automatically).

## 8. Constraints and verification

- **Do not extensively run the built-in QA suites** (`scripts/tests/foundation_check.gd` / `ui_scene_compile_check.gd` are huge). Verify by code reasoning, the layout survey tool, and one targeted compile/smoke pass at the end. Where an existing QA assertion hard-codes the old start flow (e.g. visual QA's "shop-first start" coverage — `_start_room_has_shop_offers` in tools/foundation_visual_qa.gd expects the first room to be a shop), update those assertions to the new home-first contract as part of this feature, and say so in your summary.
- Save/load must round-trip everything new (home node, tenure clocks, containers + contents, game clock). Old saves without home data must load without crashing (default: no home, clock at day 1).
- Determinism: same seed + same home-type selection ⇒ identical starting state. The only nondeterministic input is real-time clock progression during play.
- Match code style: tabs, typed GDScript, comments only for non-obvious constraints. Data lives in JSON under `data/`, not in code constants, wherever a designer might tune it.
- Deliverable summary: what was added where (files/systems), the decisions you made on the flagged open points (motel renewal, rent default for apartment, act-hook shape, clock pause rules), and how each home type's spawn state was verified (a survey screenshot of each home scene plus a seeded run-start check of cash/items/containers).
