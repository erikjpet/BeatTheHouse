# Agent Prompt - CRITICAL: Meta Home Lag, Phantom Starting Items, and Wrong Top Bar

Priority: **CRITICAL — playtest blocker for the 0.4 release. Execute after
(or independently of, if on another machine than) the idle-animation
liveness prompt; both outrank everything else in the queue.**

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Owner playtest of the walkable meta home
(docs/todone/CRITICAL_meta_home_must_be_walkable_environment_prompt.md)
found three defects:

1. **Major lag when opening the home environment.**
2. **A large number of bag items are present in the room that the player
   never earned.** A fresh player must start with ZERO items and ZERO bags
   — only the starter container (the empty spawn bag defined by
   `starter_container_id`, meta_collection_service.gd:567-568,622) and
   nothing else. Everything in the collection is earned from runs.
3. **The home uses the standard in-run top info bar.** The meta home (and
   pawn shop / meta map) must use a distinct meta top bar containing ONLY:
   the player's **gold balance** and the **price of the next home tier**
   (at max tier — house — show gold only). No run bankroll, heat, day
   clock, or other in-run fields.

## Part 1 — Root-cause the phantom items (do this first; it may explain the lag)

Determine which of these is happening and state it in the execution record:

- (a) The room's prop population draws from the collection DEFINITIONS
  (data/collections/collections.json itemdefs/bag_defs — 28 items + 5 bag
  tiers × 2 collections) instead of the player's OWNED instances/bags from
  `MetaCollectionService` (`owned_instances` / `unopened_bags`). A fresh
  store is empty (verified: grant paths exist only via drops/trade-up;
  defaults seed only the starter container) — so if a fresh player sees
  items, the renderer is reading the wrong source.
- (b) Something grants bags/instances outside the sanctioned paths
  (drop service misfiring on daily/challenge runs, a test/demo fixture
  leaking into the default store, or the store file on this machine was
  polluted by earlier testing). Check both the code paths AND what a
  brand-new `user://meta_collection.json` contains after first launch.
- (c) Both.

Fix at the source. Then add the guard: a foundation check that a fresh
profile/meta store renders the home with zero item/bag props and exactly
the starter container present, and that `owned_instances`,
`unopened_bags`, gold, and housing tier are all at documented defaults.

## Part 2 — Fix the open lag

1. Measure first: instrument the home-open path and record where the time
   goes (room/archetype generation, per-prop texture rasterization, view
   model construction, store deep-copies). Suspects in likely order: the
   phantom catalog from Part 1 multiplying prop count; per-open (or
   per-frame) `ImageTexture` rasterization of item icons without a cache
   (IconSpriteRenderer.texture() creates a new texture each call — cache
   by (icon, size, accent) like the badge/glyph work does); full
   environment regeneration on every open instead of caching the built
   room until housing tier or contents change.
2. Fix so that opening the home is not perceptibly slower than entering an
   in-run room. Budget it: add the home-open scenario to the performance
   probe with a budget consistent with in-run room entry, so this cannot
   silently regress (the same lesson as the idle-animation guard: perf
   defects that are not gated recur).
3. Zero per-frame allocations once open; idle discipline matches in-run
   rooms (coordinate with the idle-animation liveness prompt if it has
   landed — the home obeys BOTH gates: animates its ambient channels AND
   stays within budgets).

## Part 3 — Meta top bar

1. Build a distinct meta-mode top bar used by the home, pawn shop, and
   meta map: **gold balance** and **next home tier price** (label + cost
   from the housing config in collections.json; at `house` tier show gold
   only). Nothing else.
2. Route it through the same bar infrastructure as the in-run bar (one
   bar system, two data modes — do not fork the bar rendering), and make
   the mode switch part of entering/leaving meta mode so a run never shows
   the meta bar and vice versa.
3. Scene-compile coverage: meta screens expose the meta bar with exactly
   the two fields (gold, next-tier price or gold-only at max), and in-run
   screens still expose the standard bar unchanged.

## Verification

1. Manual: fresh profile (move aside `user://meta_collection.json`) →
   open home: instant, empty of items, starter bag present, meta bar shows
   gold 0 and "Motel Room — 60" (or current config price); earn a bag in a
   run → it appears at home; buy up to house → bar shows gold only.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
   and `-FoundationSuite systems -TimeoutSec 300` (with the new fresh-store
   and meta-bar checks wired in).
4. `tools\foundation_performance_probe.ps1 -RequireGodot` — including the
   new home-open budget.
5. Note in the execution record that the built 0.4.0 packages remain STALE
   (repackage happens at pre-publish per QUEUE.md); do not re-export here.
6. Archive to docs/todone/ with the execution record (root cause of the
   phantom items, lag measurements before/after, guard proof); update
   QUEUE.md and commit per the queue lifecycle.

## Hard constraints

1. Keep all owner-binding meta rules intact (homeless carry rule,
   daily/challenge isolation, pawn-only gold faucet, trade-up gating).
2. No band-aid hiding of props — fix the data source; the store must be
   provably empty for fresh players, not just rendered empty.
3. Do not weaken any existing budget or check; add the new ones.
4. Match house style: tabs, typed GDScript, sparse constraint comments.
