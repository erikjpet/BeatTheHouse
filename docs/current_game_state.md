# Current Game State

Current release handoff: 2026-10-08 against the feature-complete 0.6 source on
`main`. The downloadable `v0.6.0-pre.5` candidate predates the final game and
performance refinements described here.

Status: **FEATURE-COMPLETE 0.6 SOURCE / OWNER PLACEMENT PASS PENDING.**

Project and export metadata identify `0.6.0`. Version `0.5.1` remains the
latest stable release; `v0.6.0-pre.5` is the latest downloadable Windows
testing prerelease. The manual placement procedure, post-promotion validation,
final packages, and owner publication remain separate from feature completion.

## Player experience

Beat the House is a deterministic single-player casino roguelike. A run begins
in a generated low-stakes location and advances through gambling, purchases,
items, services, debt, alcohol, Heat, travel, room scenarios, and character
relationships. The player is trying to remain solvent and reach one of the
Grand Casino's Act 1 endings; failure can come from bankruptcy, being stranded,
police capture, losing the back-room showdown, or abandoning the run.

The game has no real-money wagering, cash prizes, gambling monetization, or
live casino/store credentials.

## Current content inventory

Counts below come directly from the production JSON packs.

| Content | Count | Source |
| --- | ---: | --- |
| Environment archetypes | 18 | `data/environments/archetypes.json` |
| Games | 11 | `data/games/games.json` |
| Items | 89 | `data/items/items.json` |
| Content groups | 16 | `data/content_groups/groups.json` |
| Events | 159 | `data/events/events.json` |
| Services | 18 | `data/services/services.json` |
| Lenders | 5 | `data/debt/lenders.json` |
| Travel route templates | 12 | `data/travel/routes.json` |
| Authored challenges | 8 | `data/challenges/challenges.json` |
| Dialogues | 32 | `data/dialogue/dialogues.json` |
| Character identities | 45 | `data/characters/characters.json` |
| Character pools | 3 | `data/characters/pools.json` |
| Tutorial lessons | 66 | `data/tutorial/lessons.json` |
| Scenario sequences | 55 | `data/environments/scenario_sequences/*.json` |
| Collection definition packs | 1 | `data/collections/collections.json` |
| Collections / collectible entries | 2 / 28 | `data/collections/collections.json` |
| Music manifest tracks | 3 | `data/audio/music_manifest.json` |

## Games

All eleven catalog entries use the shared `GameModule` host contract and have
real surface interaction rather than placeholder result buttons.

| Game | Current implemented depth |
| --- | --- |
| Scratch Tickets | Seven ticket identities, fixed-at-purchase results, layered ticket art, interpolated scratching, piles/discard/collection payoff, and a physical vending cabinet with a 1.5-second lift-shelf dispense into a clickable output tray |
| Pull Tabs | Finite deals, ticket windows, persistent deal state, detector scan, and item interactions |
| Slots | Generated Pinball/Buffalo machines, fixed bet ladder, nudge, autoplay, family features, jackpots, and stuck-state coverage |
| Bar Dice | Ship, Captain, Crew with patrons, pots, cargo scoring, timed loaded-toss/palmed-swap actions, and a fixed non-overlapping 1280x720 table/control layout |
| Blackjack | Shoe state, hit/stand/split/double/surrender, side bets, counting, hole-card peek, surveillance, and the Rourke duel host |
| Baccarat | Player/Banker/Tie and pair bets, commission, squeeze/shoe state, shoe reading, and edge sorting |
| Craps | Casino and street play, 40 reachable wager types, interruption/refund state, derived edges, million-roll verification, and a dedicated chalk-circle alley object instead of a casino table in Street Craps environments |
| Roulette | Inside/outside chip placement, full wheel resolution, recent history, wheel reading, and past-post timing |
| Crew Hold'em | Six-handed no-limit Hold'em, automatic paced opponent turns, personality-shaped but fallible tells, player-projected tells, dealer/muck fold cleanup, conserved pots, hidden-card authority, five nights, and seven persistent opponents |
| Video Poker | Three authored Jacks or Better/Deuces Wild/Double Double Bonus cabinets, one to three hands, denomination/coin ladder, hold/draw, recommendation support, mark-holds, and bounded double-up |
| Coin Pusher | Three deterministic native/Web-parity cabinets with physical trays, nozzles, cups, heavy objects, goals, persistence, and conservation checks |

## World, scenarios, and progression

- The seeded `WorldMap` persists node discovery, visits, stored room state,
  scouting, costs, risk, locks, and route consequences.
- The 55 Tonight scenarios span bars/road, Queen/public venues, roadside
  shelters, shops/streets, and underground/lounge locations. They author room
  objects, actors, objectives, phases, actions, cleanup, and aftermath.
- The Crew campaign carries trust, debt/favor, deliveries, Numbers, jobs,
  recruitment, coordinated plays, Police Sweep responses, two heist plans, and
  the Turn confrontation through save/revisit boundaries.
- The Grand Casino has a Main Floor, High-Limit Room, Back Room, and walkable
  Cage. The clean ending climbs Linda's Players Card ladder; the cheat ending
  survives Rourke's walk, pat-down, interrogation, and five-hand duel.
- Meta progression includes local collection bags/items, condition, housing,
  loadouts, trade-ups, pawn sale, run history/stats, and unique Gold Players
  Cards. The browser groups entries by collection and exposes tier/float detail;
  dedicated player sort/filter controls and Steam Inventory/community-market
  integration remain deferred.
- The guided first night and contextual teaching catalog cover the current
  world and game systems. The five-person cold-player requirement remains a
  human-only acceptance gate.

## Presentation and platform state

- Main scene: `res://scenes/main.tscn`; host:
  `res://scripts/ui/foundation_main.gd`.
- Native and Web use the same deterministic simulation contracts.
- Environment and game surfaces retain autonomous no-input animation scheduling;
  redraw work is cached/bounded without depending on mouse movement, hover, or
  selection.
- The persistent **Object labels and borders** setting controls subtle
  selected/hovered room labels and outlines without changing hit testing or
  interaction availability.
- The Coin Pusher native GDExtension is present, identity-checked, and parity
  tested; Web uses its supported fallback path.
- Native/Web SFX use the shared 22.05 kHz contract and thirteen surface
  profiles. Adaptive music supports synchronized stems, fills, outcome
  stingers, tempo changes, and Web-prepared assets.
- Primary targets are Windows and Web/itch.io. Android and iOS presets exist
  but remain blocked on external signing/team credentials.

## Verification state

The feature-complete source includes the established prerelease placement
baseline plus the subsequent game-flow, animation-liveness, event-latency, and
surface-performance work. `v0.6.0-pre.5` remains the last published test
package, so its exact evidence is preserved separately from the newer source:

- Hold'em opponents now act automatically after readable, variable thinking
  intervals; their five tell emotions mix hand pressure with personality and
  intentional ambiguity, and folded player cards clear through the muck flow;
- Scratch Tickets now use a detailed vending surface with a timed physical
  lift/pick/lower dispense, machine audio, and tray-to-play interaction;
- Bar Dice uses fixed, non-overlapping regions for its patrons, dice, rules,
  paytable, timer, and controls;
- environment, placement, and game animations continue without pointer input,
  including while placement overlays are open;
- event activation and common object-loading, dragging, slot-move, and
  post-action paths use bounded caches and deferred work to reduce visible
  stalls without suppressing animation;
- the final source-hygiene pass removed 105 unreferenced production functions,
  13 unused tool helpers, one unreachable menu implementation, and three stale
  UID sidecars while preserving live save migrations and compatibility paths;

- the placement panel has a visible minimize control, and minimizing removes
  the entire large panel from hit testing so covered room objects and slots can
  be selected;
- the fixed, scrollbar-free placement panel uses consistent control/type sizing,
  four single-family filters plus **All**, and **Behind**/**Standard**/**Front**
  draw-layer controls for the selected slot;
- a small restore button brings back all panel controls, with F2 retained as a
  keyboard-parity shortcut;
- F1 toggles slot placement mode itself and synchronizes the live Settings
  preference and checkbox;
- the minimized state survives context advances and resets when placement mode
  is exited;

- dead and unreachable positions have been removed and misleading claimant
  labels repaired;
- every one of the 55 scenario layouts now has collision-free initial geometry;
- marker details appear on selection or hover, keeping crowded layouts legible;
- each nonempty family requires deliberate review before a base layout can be
  saved, and **Save & Load Next Missing** advances directly through unfinished
  contexts;
- packaged builds hide **Save to Project** and retain the portable schema-3
  export path;
- the returned-report workflow verifies source provenance, all-layout coverage,
  and placement-authority hashes before import.
- Environment Library practice sessions ignore closing-time and normal
  run-terminal exits, and validation warnings do not block a malformed or
  obstructed room from loading for repair.

The established placement baseline includes:

- 21 source maps validate with four closed slot families and no dangling
  mapping, duplicate map-local ID, duplicate exact rectangle, or provable
  fixed/exit orphan;
- the audited raw/template census is 521 positions (179 fixed, 98 event, 211
  scenario-source, 33 exit), yielding 368 reachable shared positions plus 604
  exact scenario positions for 972 unique manual entries;
- 20 reachable base layouts plus 55 exact scenario layouts produce the complete
  75-context owner checklist; the raw Punchline parent remains source-only;
- 55 exact scenario layouts contain 604 independently movable scenario slots;
- an independent deep sweep generated 1,200 layouts (16 seeds per context)
  with zero binding failures or occupied hit-rectangle intersections;
- the permanent static regression validates 4,627 live physical bindings plus
  825 attached/nonphysical bindings over 767 reachable snapshots and rejects
  nonphysical fallbacks, overflow,
  duplicate occupancy, missing authority, or overlap;
- migration refresh, fresh legacy conversion, both migration ledgers, scenario
  generation, save/export coverage, Environment Library launch, and both
  placement editors pass their focused checks.
- the Motel retains one conditional `exit.motel_room` reserve because active
  motel-room ownership can create a real return doorway beside the ordinary
  leave exit; the runtime manifest test binds that doorway explicitly.
- the Grand Casino high-limit room, back room, and Cage retain their real
  world-map Leave exits even though manifest-only generation does not synthesize
  those UI-owned controls.
- hidden-casino game capacity is now two floor-fixture positions, so Blackjack
  can no longer fall through to the Numbers Book; variable Kitty games and
  Punchline games/lenders remain pooled rather than ID-positioned.
- Pull Tabs retains a physical machine in the Bar, Gas Station Casino, Jazz
  Club, and Grand Casino while help/redemption stays attached to existing
  staff; the Gas Station again exposes all three selected machine positions.

The old room-composition failures are closed by the scenario-local layout
authority and post-migration cleanup. The remaining room work is artistic:
the owner will position the audited slots and return the complete schema-3
report for promotion into committed coordinates.

## Remaining release sequence

1. Complete the 75-context pass in **Settings > Environment Library**, using
   **Load Next Missing**, the SAVED/TODO labels, and the exact scenario layer
   selection. Base contexts edit room-shared positions; exact scenarios open
   on their local Scenario tab with shared positions locked by default.
2. Export `BeatTheHouse_environment_slot_placement_changes.json` from the
   packaged build and provide it for promotion into project authority. The
   self-contained report includes all effective positions, 75-layout coverage,
   build/source identity, and placement-authority hashes.
3. Re-run the placement/runtime gates after promoting those artistic
   coordinates.
4. Produce and launch-check the final Windows/Web artifacts, then publish only
   after explicit owner approval.
