# Agent Prompt — Bag Opening: Counter-Strike-Style Reveal Reel

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Immediate-mode canvas
rendering; UI via extracted components + pure view models (foundation_main
gains wiring only); the meta collection system lives in
`scripts/core/meta_collection_service.gd` +
`scripts/core/collection_item_resolver.gd`; seeded RNG via `RngStream`
forks. This file is a self-contained work order. It adds a CS-case-style
animated reveal to bag opening. Audit the current code first; code reality
wins over any drifted references.

## What exists (the seam you build on)

- Bag opening today: `open_meta_bag(instance_id)` →
  `_open_selected_meta_bag(...)` (`scripts/ui/foundation_main.gd` ~:9796,
  :10011) → `meta_collection_service.open_bag(instance_id)`, which returns
  `{item: {...}}`. **The winning item is ALREADY ROLLED and GRANTED by
  `open_bag` from the seeded resolver** (`collection_item_resolver`
  `roll_instance` / `_roll_weighted_collection_tier`). The current reveal
  is just a text line (`_collection_reveal_text`). This task replaces that
  instant text reveal with an animated reel that reveals the SAME item.
- The bag's full possible contents: `collection_item_resolver`
  `bag_item_definitions(collection_id, tier)` returns every item
  definition the bag can produce.
- Rarity tiers (ascending): `blue`, `purple`, `pink`, `red`, `gold`
  (`collection_item_resolver.gd:13`). Per-tier colors live in
  `scripts/ui/visual_style.gd`; ensure all five have a distinct, legible
  OUTLINE color (add/confirm pink/red/gold accents if missing).
- Item art: items carry an icon/asset key; reuse the existing item-icon
  rendering used elsewhere in the meta/collection UI.

## The feature — a bag-opening reveal reel

Model it on the Counter-Strike case-opening screen.

### 1. The reel

- A horizontal reel of item "cards" that scrolls fast left→right (or
  right→left — pick one, be consistent), decelerating to a stop.
- A STATIC vertical marker line down the center of the reel indicates the
  landing slot — whatever card rests under the marker when the reel stops
  is the reveal.
- Each card shows: the item's image, boxed with an OUTLINE in that item's
  RARITY color (blue/purple/pink/red/gold). Higher rarities read as more
  vivid.
- The reel is populated with a long sequence of cards drawn from the
  bag's possible items (weighted to look natural — mostly common, rarer
  ones sprinkled), and the card at the landing position IS the
  predetermined winning item from `open_bag`.

### 2. Determinism (critical — the reel never decides the outcome)

- The winning item is `result.item` from `open_bag`, which is already
  rolled and granted by the seeded resolver. The reel is PURE
  PRESENTATION: it must always land on that exact item and must never
  re-roll or alter it.
- The filler cards and their order may be generated from a named seeded
  fork for reproducibility, but the landing slot is pinned to the
  committed item regardless. The determinism probe must stay
  self-consistent.
- Because `open_bag` already grants the item and consumes the bag, no new
  persistence is required: if the app is closed mid-spin, the item is
  already in the collection; on reload simply show it (no dangling reel,
  no double-grant). Verify and state this.

### 3. The contents showcase (below the reel)

- Below the reel, display a showcase of ALL items the container can
  produce (`bag_item_definitions` for the bag's collection + tier): each
  item's image boxed in its rarity-color outline, grouped or ordered by
  rarity so the player sees exactly what was possible. This is visible
  when the reveal opens (and may remain during/after the spin).

### 4. Flow + reduce-motion

- Opening a bag: call `open_bag` (commits the item), then play the reel
  reveal to the committed item, then present the won item prominently
  (name, rarity, and it is now in the collection). Preserve any existing
  post-open state/selection (`selected_meta_item_key`) and the collection
  reveal messaging.
- Reduce-motion: SKIP the spin entirely — show the contents showcase and
  the won item directly, no animation. The result is identical.
- A skip/click-to-finish control ends the spin early and snaps to the
  reveal (never changes the item).

### 5. Component shape

- Build as an extracted component (`BagOpenReel` + a pure view model)
  following the RunInventoryScreen/report precedent: the component owns
  its rendering and animation; the host passes the committed item + the
  possible-contents list + rarity colors via an explicit view model.
  foundation_main gains only thin wiring; the old instant-text path is
  replaced (no dead parallel reveal).

## Hard rules (binding)

- The reel is cosmetic: it never rolls, re-rolls, or changes the granted
  item; outcomes come only from `open_bag`'s seeded roll.
- Zero-copy per-frame: the reel animates from a PRECOMPUTED card sequence
  and eased position (built once when the reveal opens); no per-frame
  dictionary building, no per-frame `duplicate(true)`. Animation advances
  by canvas elapsed time.
- Idle-animation liveness untouched; reduce-motion fully supported.
- Determinism probe self-consistent; save/profile compatibility unchanged
  (no new persisted state).
- Match existing style: tabs, typed GDScript, sparse comments; rarity
  colors from the shared visual contract; `.tmp/` reports only. Suite
  timeout = max(300s, ceil(recorded baseline × 1.5)).

## QA / Tests (extend the meta/collection suites)

1. The reel ALWAYS lands on the item `open_bag` returned, across many
   seeds and both scroll to completion and skip-to-finish; no re-roll,
   no double-grant.
2. Determinism: the committed item is unchanged by the presence/absence
   of the reel and by reduce-motion; probe stays self-consistent.
3. Rarity mapping: each of the five tiers renders its distinct outline
   color on both reel cards and the showcase.
4. Contents showcase lists exactly `bag_item_definitions` for the bag,
   grouped by rarity, nothing missing or extra.
5. Reduce-motion path shows the same won item with no animation.
6. Zero-copy: no snapshot/dictionary allocation per frame during the spin
   (counter/spy assertion).
7. Save mid-spin (simulated close) → item present once in the collection
   on reload; no reel residue.
8. Small-screen: reel + marker + showcase fit and read at both sizes.
9. FEEL ACCEPTANCE (manual, report in words): open several bags of
   different tiers — the spin builds tension, lands cleanly on the marker,
   rarity colors pop, and the contents showcase makes the odds legible.

## Gates (all must pass)

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering UI + collections/meta
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot` (the reveal
  surface stays within a budgeted allocation)
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_mouse_playtest.ps1` (strict single run)

## On completion

Only after every gate passes AND you have confirmed the feature works
end-to-end (manual feel-acceptance done):

1. Commit the work in logical units (component + view model; reel
   animation; contents showcase; flow wiring + old-path removal).
2. ARCHIVE this prompt file by moving it to `docs/todone/` with
   `git mv docs/todo/bag_opening_reel_prompt.md docs/todone/` in the
   final commit — do NOT delete it. Append a short execution record to
   the bottom of the archived file (date, implementing commit hashes,
   gate results, any deviations).
3. PUSH to the remote.
4. Report: the component API, how the reel is pinned to the committed
   item, the reduce-motion path, the feel-acceptance in your own words,
   and every gate result.

On an unfixable gate failure: stop at the last green commit, do NOT push
or archive, and report the failure output verbatim.

---

## Execution record

Date: 2026-07-22

Implementing commits:
- `509d6eae` Add bag opening reel component
- `847c3b0c` Wire bag reel into meta bag opening
- `2c052d95` Repair systems gate state boundaries
- `a0ad87f5` Cover bag reel pinning and UI flow
- Archive record: the commit containing this section

Gate results:
- `tools/validate_project.ps1` — PASS
- `tools/check_godot.ps1 -FoundationSuite ui -TimeoutSec 300` — PASS (`20260722_193158_smoke`)
- `tools/check_godot.ps1 -FoundationSuite systems -TimeoutSec 300` — PASS (`20260722_193040_smoke`)
- `.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe --headless --path . --script res://scripts/tests/collection_meta_check.gd` — PASS
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` — PASS, 10 seeds, 326 checkpoints, combined hash `439730414`
- `tools/foundation_performance_probe.ps1 -RequireGodot` — PASS
- `tools/foundation_visual_qa.ps1` — PASS
- `tools/foundation_mouse_playtest.ps1` — PASS, 60 input events, visible-control victory and recovery/debt pressure verified

Manual feel/readability acceptance:
- Exercised the reel view model and component across all five rarity tiers. The component opens with a long precomputed horizontal sequence, decelerates under a static center marker, highlights the committed landing card, supports click/Skip snap-to-finish, and shows the won item plus the full contents showcase below.
- Reduce-motion opens directly on the same committed result with no animation.
- The five rarity outlines are distinct and readable in standard and high-contrast palettes: blue, purple, pink, red, and gold.

Deviation from prompt text:
- The prompt said `bag_item_definitions(collection_id, tier)` returns every item definition a bag can produce. Current code reality uses that method for bag definitions; the exact possible item contents used by `open_bag` come from `bag_item_options_for_bag(bagdef_id)`. The implementation uses `bag_item_options_for_bag` so the showcase matches the actual committed resolver seam.
