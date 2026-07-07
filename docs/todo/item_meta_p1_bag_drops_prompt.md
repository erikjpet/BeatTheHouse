# Agent Prompt — Item Meta P1: Bag Drops, Single-Button Opening, Collection Browser

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). This is **Phase P1 of the item collection meta
system**. Source design: `docs/plans/item_collection_meta_system_plan.md`
(rev 2) §4–§5. **Hard dependency:** Phase P0 must be archived in
docs/todone/ (collections.json schema, `MetaCollectionService`, the 4-float
roll engine). Read P0's execution record first and build on exactly what it
landed — do not re-derive the schema.

## Scope

Three deliverables: (1) bags drop from play, (2) bags open at home with one
button + a simple reveal, (3) a basic collection browser. No backpack
loadout (P2), no meta-home scene (P3), no trade-up (P4).

## 1. Bag drops (seeded, run-boundary only)

- Drop moments, evaluated **once at run end** when the run's outcome is
  known (meta writes only at run boundaries — the SB.3/SB.5 gates must stay
  untouched inside runs):
  - Run victory: guaranteed drop.
  - Grand Casino showdown completion: guaranteed drop.
  - First-time challenge completion (ProfileInventory completion flags are
    the dedup source): one drop.
  - High-heat clean escape (finish a run with suspicion ≥ 65 without
    arrest): chance roll.
- All rolls (drop chance, collection pick, tier pick) derive from the run
  seed via a dedicated stream — two replays of the same seed+outcome drop
  identical bags. Tier odds come from each collection's `drop_table`
  (P0 data); never hardcode weights.
- **Special locations:** rare in-run bag finds. Reuse the existing
  environment-prop/event machinery: add 1–2 `landmark`-type events whose
  consequence grants a `pending_bag` marker on RunState (serialized,
  normalized); the actual `grant_bag` into `MetaCollectionService` still
  happens at run end from that marker. In-run code must never import the
  meta service — keep the boundary clean.
- On grant, surface it: the end-of-run summary lists found bags with their
  collection + tier (bags always show what they are — owner rule).

## 2. Opening pipeline (deliberately simple v1)

- A bag stored in home container storage (the shipped container system from
  0.3.3) exposes one **Open** button in the inventory/container UI.
- Pressing it: consume the bag, roll the item via P0's `roll_instance`
  (seeded from a meta RNG stream persisted in the meta save — record the
  stream state so save-scumming the reveal is not trivially possible),
  `grant_instance`, then play a **simple reveal**: staged panel showing
  item name, tier color, condition band, and float bar(s). No slot-machine
  theatrics, no near-miss presentation (compliance framing in the plan).
- The richer container-transfer mechanic is future P6 — keep the open flow
  behind one clean function boundary and do not build toward it.

## 3. Collection browser (basic)

- Reachable from the main menu (alongside the profile view): a grid/list of
  both collections — every itemdef shown, owned instances with their floats
  and condition bands, unowned as silhouettes, unopened bags listed with
  visible collection+tier. Reuse `RunInventoryScreen`'s component patterns
  (grid + detail panel, view-model builder feeding a dumb component); a new
  meta view-model, not a fork of the screen logic.
- Tier colors and float bands render through the attribute glyph registry
  (data/runtime/attribute_glyphs.json — landed with the glyph system; add
  tier glyph entries if missing rather than hardcoding colors).

## Hard constraints

1. No mid-run meta writes; no meta-service imports in run/game code.
2. All randomness seeded; no wall-clock anywhere.
3. Zero per-frame allocations in browser/reveal rendering; cache textures.
4. New RunState field (`pending_bag` markers) normalizes on load and
   round-trips SB.3-style.
5. Coverage to add: (a) same seed+outcome → identical drops, (b) run-end
   grant lands in the meta save and survives reload, (c) open consumes the
   bag exactly once (rapid-click fuzz cannot double-open), (d) browser
   view-model is read-only over the meta store, (e) end-of-run summary
   lists drops.
6. Match house style: tabs, typed GDScript, sparse constraint comments.

## Verification gates (run at the end)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\collection_meta_check.ps1` (P0's harness — extend it with the P1
   assertions above).
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` and
   `-FoundationSuite ui`.
4. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`.
5. Move this prompt to docs/todone/ with an execution record per RULES;
   update QUEUE.md. Commit locally; do NOT push.
