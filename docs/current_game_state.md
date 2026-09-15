# Current Game State

Last product verification: 2026-09-15 against product head `7c23d6aa`.

Status: **PLAYABLE 0.6 DEVELOPMENT SOURCE / NOT RELEASE-CLEARED.**

Project and export metadata still identify `0.5.1`, the latest published
release. That is intentional: the parked `release06_1` task owns the eventual
0.6 version, package, tag, and publication boundary.

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
| Items | 88 | `data/items/items.json` |
| Content groups | 16 | `data/content_groups/groups.json` |
| Events | 159 | `data/events/events.json` |
| Services | 18 | `data/services/services.json` |
| Lenders | 5 | `data/debt/lenders.json` |
| Travel route templates | 12 | `data/travel/routes.json` |
| Authored challenges | 8 | `data/challenges/challenges.json` |
| Dialogues | 32 | `data/dialogue/dialogues.json` |
| Character identities | 46 | `data/characters/characters.json` |
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
| Scratch Tickets | Seven ticket identities, fixed-at-purchase results, layered background/icon/foil rendering, interpolated scratching, piles, discard, and collection-print payoff |
| Pull Tabs | Finite deals, ticket windows, persistent deal state, detector scan, and item interactions |
| Slots | Generated Pinball/Buffalo machines, fixed bet ladder, nudge, autoplay, family features, jackpots, and stuck-state coverage |
| Bar Dice | Ship, Captain, Crew with patrons, pots, cargo scoring, and timed loaded-toss/palmed-swap actions |
| Blackjack | Shoe state, hit/stand/split/double/surrender, side bets, counting, hole-card peek, surveillance, and the Rourke duel host |
| Baccarat | Player/Banker/Tie and pair bets, commission, squeeze/shoe state, shoe reading, and edge sorting |
| Craps | Casino and street tables, 40 reachable wager types, interruption/refund state, derived edges, and million-roll verification |
| Roulette | Inside/outside chip placement, full wheel resolution, recent history, wheel reading, and past-post timing |
| Crew Hold'em | Six-handed no-limit Hold'em, dealer choreography, conserved pots, hidden-card authority, five nights, and seven persistent opponents |
| Video Poker | Multiple rule sets, denomination/coin ladder, hold/draw, recommendation support, mark-holds, and bounded double-up |
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
- The Coin Pusher native GDExtension is present, identity-checked, and parity
  tested; Web uses its supported fallback path.
- Native/Web SFX use the shared 22.05 kHz contract and thirteen surface
  profiles. Adaptive music supports synchronized stems, fills, outcome
  stingers, tempo changes, and Web-prepared assets.
- Primary targets are Windows and Web/itch.io. Android and iOS presets exist
  but remain blocked on external signing/team credentials.

## Verification state

Green on the verified product head:

- project/static validation;
- exhaustive core/game/UI GDScript loading;
- all nine Smoke stages, including UI scene compilation and performance smoke;
- focused Blackjack, Baccarat, Roulette, Craps, Bar Dice, Video Poker, and slot
  contract suites;
- surface-audio, float-PCM, adaptive-tempo, jazz choreography, and outcome
  audits;
- native Coin Pusher runtime identity, deterministic parity, and smoke;
- performance-smoke budgets (worst observed frame p95 6.908 ms; worst observed
  game resolve p95 3.305 ms).

Red on the same current tree:

- the broad Contract suite. Static validation and GDScript loading pass first,
  then scenario/content shards report label and hit-authority overlap in normal
  or expanded small-screen layouts, colliding actor route endpoints, missing
  generated room inventory, and placement-dependent fixture expectations.

This is a room/scenario composition blocker. It is not evidence that the game
catalog, native extension, or basic player path is absent or broken, and it is
not waived by the green Smoke result.

## Remaining release sequence

1. Approve and implement a room-construction/placement design that supports the
   expanded object inventory without overlapping labels, actions, or routes.
2. Return the broad Contract suite to green and refresh any intentionally
   changed layout evidence.
3. Run the binding performance/platform qualification on a quiescent witnessed
   host.
4. Refresh the full owner playtest gate and resolve owner-directed balance,
   polish, voice, and cleanup work.
5. Let `release06_1` own version stamping, final packages, hashes, tag, release
   notes, and publication.
