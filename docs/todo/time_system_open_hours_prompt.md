# Agent Prompt — Time System: Opening Hours, Closing-Time Eviction, Open Revisit Travel

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). The game clock exists but is ignorable: nothing
gates on it. This task makes time a real system: venues keep realistic
opening hours, closing time evicts the player (with grace), and travel opens
up so any visited location is reachable again for a distance-correlated
price.

## What already exists (build on it, do not duplicate)

- **Clock:** `RunState.game_clock_minutes` (run_state.gd:78,111), day
  rollover (`_advance_home_day_rollovers`, :592), 12-hour AM/PM display
  already implemented (`clock_display_text`, :265-272), and
  `advance_game_clock_minutes` (:278). Audit every call site of
  `advance_game_clock_minutes` first — the clock only matters if actions,
  game rounds, and travel all advance it with sane, data-tuned costs
  (travel must scale with distance blocks).
- **Travel:** `scripts/core/world_map.gd` has `visited_path`, distance
  bands `near/local/far/remote` with cost multipliers 1.0/1.35/1.75/2.25
  (:16-27), per-route `distance_blocks` from node geometry (:103,825), and
  separate new/old candidate lists (:381-383).
- **Environments:** `data/environments/archetypes.json` — archetype list:
  corner_store, back_alley, motel, bar, gas_station_casino,
  small_underground_casino, jazz_club, kitty_cat_lounge, delta_queen,
  grand_casino, motel_room, apartment, house.

## 1. Opening hours (data-driven)

Add `open_hours` to each archetype in archetypes.json:
`{"open_minute": <0-1439>, "close_minute": <0-1439>}` with wrap-around
semantics (close < open means the venue closes after midnight). Omitted or
null = open 24 hours. Owner-specified and proposed hours:

| Archetype | Hours | Source |
| --- | --- | --- |
| corner_store | 6 AM – 1 AM | owner |
| bar | 11 AM – 3 AM | owner |
| small_underground_casino | 24h | owner |
| kitty_cat_lounge | 1 PM – 5 AM | owner |
| back_alley | 24h | owner |
| motel | 24h | owner |
| grand_casino | 24h | owner |
| gas_station_casino | 24h | proposed (gas stations do not close) |
| jazz_club | 5 PM – 3 AM | proposed |
| delta_queen | 9 AM – 3 AM | proposed (riverboat boarding hours) |
| motel_room / apartment / house | 24h | homes are always accessible |

Proposed rows are data — trivially owner-tunable later. Add a shared helper
(`environment_open_at(archetype, minute_of_day) -> bool`) with the wrap
logic in ONE place (core layer, pure function); UI and travel both call it.

## 2. Closing-time eviction

Evaluate **only at action boundaries** (never per-frame, never wall-clock —
the determinism probe must keep hash-matching):

1. When an action completes and the clock now sits at/past closing time for
   the current environment, enter `closing_time` state: show a clear
   message ("<Venue> is closing."), and grant **grace**: the player may
   finish the current bet/round if one is mid-resolution (blackjack hand,
   roulette spin+payout, pinball bonus — the round runs to its natural end)
   and then perform **at most one more action**.
2. After grace is spent, all environment interactions except opening the
   world map are blocked (reuse the existing action-block/disabled-reason
   pathways so fuzz suites see a legal state, not a stuck one) and the
   world map opens for forced travel.
3. Edge cases that MUST be handled: closing during a triggered/talk event
   (event resolves first, counts as the grace action), closing while the
   world map is already open (no-op — traveling anyway), attempting to
   re-enter a closed venue from the map (blocked with an "opens at <time>"
   reason), and save/load mid-grace (state round-trips; SB.3-style
   idempotence for the new fields).
4. Arrival at a venue that closes within a few minutes of arrival is
   allowed (they let you in until close); eviction then follows normally.

## 3. Travel opens up: revisits always available

1. Every node with `state == visited` is a legal travel destination from
   anywhere, whenever the player can afford it (and it is open — see below).
   Extend the world map candidate logic (world_map.gd:381-383) so revisit
   candidates are not limited to adjacency; compute their cost from the
   full path/geometry distance (`distance_blocks` × the existing band
   multipliers). Price correlates with distance — farther = costlier.
2. Closed destinations remain visible on the map but disabled with the
   "opens at <time>" reason. Because back_alley, motel, underground casino,
   grand_casino, gas_station, and homes are 24h, at least one destination is
   always open.
3. **No-stuck guarantee (hard requirement):** forced eviction with an empty
   bankroll must never soft-lock. Add a zero-cost "walk" fallback: the
   nearest 24h venue (or the player's home) is always reachable for free at
   eviction time — walking takes proportionally more clock minutes instead
   of money. Extend the stuck-state sweep inventory with this scenario
   (broke player evicted at close) so it stays covered.
4. Travel advances the clock by a per-block minute cost (data constant) —
   arriving somewhere far costs real night hours.

## 4. UI

- The clock display exists; surface it wherever travel decisions happen
  (world map header) if not already there.
- Venue cards/map nodes show open/closed and closing-soon (within ~1 hour)
  status. Plain text is fine now; note the queued attribute-glyph system
  (docs/todo/attribute_glyph_system_prompt.md) will replace text badges —
  route status text through one small helper so the glyph swap is one-site.

## Hard constraints

1. All eviction/hours checks happen at action boundaries; per-frame paths
   stay zero-copy (see CLAUDE.md).
2. New RunState fields (grace state, eviction flags) get normalized
   defaults on load; old saves without them behave as before.
3. Determinism: hours evaluation is a pure function of clock + data; no
   wall-clock, no unseeded randomness anywhere in this task.
4. Do not weaken existing suites; extend: (a) open/closed wrap-around unit
   coverage (1 AM close, 24h, midnight boundaries), (b) eviction grace
   (round finishes + exactly one action), (c) revisit travel costing by
   distance, (d) broke-eviction walk fallback in the stuck sweep, (e)
   closed-venue entry block reason.
5. Match house style: tab indentation, typed GDScript, sparse comments
   stating constraints only.

## Coordination note

This task touches `run_state.gd`, `world_map.gd`, `foundation_main.gd`, and
`archetypes.json` — files that currently carry other in-flight work (see
QUEUE.md). Do not start while those entries are claimed; when you do start,
pull first and build on the landed state.

## Verification gates (run at the end, not iteratively)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` and
   `-FoundationSuite ui`.
3. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` —
   hash match with the clock/eviction active.
4. `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100` —
   includes the broke-eviction scenario, 0 stuck.
5. Move this prompt to docs/todone/ with an execution record per RULES;
   update QUEUE.md. Commit locally; do NOT push.
