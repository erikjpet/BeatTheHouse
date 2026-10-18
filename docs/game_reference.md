# 0.6 Game Reference

Updated 2026-10-08 from the feature-complete 0.6 source. This is the maintained
reference for the playable game roster and every script under `scripts/games/`.
It supersedes mechanic summaries in dated gate reports; those reports remain
valid evidence for the source boundary they recorded.

The production catalog contains exactly 11 games, all marked
`full_simulation` in `data/games/games.json`. Every game extends the shared
`GameModule` host contract, owns deterministic state, and exposes a real game
surface rather than a result-only placeholder. No gameplay outcome depends on
pointer movement: idle, deal, dispense, wheel, reel, table, and cabinet
animations continue on their scheduled presentation ticks.

## Playable games

| Catalog ID | Player-facing game | Production module | 0.6 behavior |
| --- | --- | --- | --- |
| `scratch_tickets` | Scratch Tickets | `scripts/games/scratch_tickets.gd` | Seven ticket identities with fixed-at-purchase outcomes, free-form scratching, win/dud filing, discard, collection discovery, counter redemption, and a physical vending cabinet. Each purchased ticket uses a 1.5-second lift/pick/lower dispense with machine audio, lands in the output tray, and enters the play area when the tray is selected. |
| `pull_tabs` | Pull Tabs | `scripts/games/pull_tabs.gd` | Counter-sold finite deals with persistent ticket rows/windows, fixed contents, redemption through venue staff, detector and item interactions, suspicious-cashout follow-up, and a rare eligible-ticket glimmer that never changes odds or outcomes. |
| `slot` | Slots | `scripts/games/slot.gd` | Deterministically generated Pinball and Buffalo machines across three formats, fixed `$2/$5/$10/$15/$20` bets, autoplay, reel-shift nudge, family features, jackpots, persisted bonus state, and stuck-state recovery coverage. |
| `bar_dice` | Bar Dice | `scripts/games/bar_dice.gd` | Ship, Captain, Crew with five dice and up to three shakes, 6-5-4 locking, cargo scoring, patrons, carryover pots, wager cover, and skill-timed loaded-toss/palmed-swap actions. The 1280x720 surface uses fixed non-overlapping patron, rules, paytable, timer, dice, and action regions. |
| `blackjack` | Blackjack | `scripts/games/blackjack.gd` | Finite-shoe blackjack with hit, stand, split, double, surrender, insurance/side bets, patrons and dealer automation, count challenge, hole-card peek, surveillance response, and the five-hand Rourke duel host. |
| `baccarat` | Baccarat | `scripts/games/baccarat.gd` | Mini-baccarat/Punto Banco with Player, Banker, Tie, and pair bets; mandatory third-card rules; commission; finite shoe state; squeeze reveal; shoe reading; and edge sorting. |
| `craps` | Craps | `scripts/games/craps.gd` | Casino and street tables with 40 reachable wager types, point/on-off state, working and hopping bets, take-down and pass-dice flows, interruption/refund state, dice setting/switching, derived house edges, and million-roll verification. |
| `roulette` | Roulette | `scripts/games/roulette.gd` | Deterministic wheel/ball resolution, inside and outside chip placement, recent history, payout choreography, wheel-bias reading, and timed past posting. |
| `crew_draw_poker` | Back-Room Hold'em | `scripts/games/crew_draw_poker.gd` | Six-handed no-limit Texas Hold'em with blinds, four betting streets, shared community cards, side-pot conservation, dealer/card/chip choreography, five poker nights, and seven persistent Crew opponents. Opponents act automatically at readable, irregular intervals. Confidence, worry, scared, neutral, and pushy tells reflect both hand pressure and personality but can be masked or false; the player can also project a tell. Folded player cards leave only through the dealer/muck animation and are then hidden. |
| `video_poker` | Video Poker | `scripts/games/video_poker.gd` | Three authored cabinets: 9/6 Jacks or Better (one hand), Double Deuces/Deuces Wild (two hands), and Triple Double Bonus/Double Double Bonus (three hands). Supports 1-5 coins, cabinet denominations/paytables, hold/draw, max-coin royal treatment, bounded double-up, recommendations, and the mark-holds/holdout action. |
| `coin_pusher` | Quarter Falls | `scripts/games/coin_pusher.gd` | Three deterministic cabinets—Quarter Falls, Jackpot Ridge, and The Vault Drop—with live shelves/trays, carriage and nozzle controls, cups, heavy prizes, cabinet-specific goals/actions, persisted bodies and rewards, advantage nudges, alarms/Heat, conservation checks, and native/Web solver parity. |

`crew_draw_poker` is an internal compatibility ID, not the current ruleset name.
It remains in saves and code so 0.6 state does not need a risky schema rename.
Current player-facing documentation must call the game Back-Room Hold'em or
Crew Hold'em and must not describe the retired five-card draw flow.

## Catalog actions

These are the run-level entries declared by `data/games/games.json`. Surface
buttons expand them into the detailed actions described above.

| Game | Legal catalog actions | Advantage or cheat actions |
| --- | --- | --- |
| Scratch Tickets | `buy_scratch_ticket` | None |
| Pull Tabs | `buy_tab` | `tab_detector_scan` |
| Slots | `spin` | `nudge` |
| Bar Dice | `roll` | `loaded_toss`, `palmed_swap` |
| Blackjack | `play_basic` | `peek_hole_card`, `count_cards` |
| Baccarat | `deal_baccarat` | `read_baccarat_shoe`, `edge_sort` |
| Craps | `roll_craps`, `take_down_craps_bet`, `pass_craps_dice` | `dice_setting`, `dice_switching` |
| Roulette | `spin_roulette` | `read_wheel_bias`, `past_post` |
| Back-Room Hold'em | `deal` | No catalog cheat; reading opponents and projecting tells happen on the surface |
| Video Poker | `draw` | `mark_holds` |
| Coin Pusher | `drop_quarter` | `nudge_machine` (tap, shove, or slam toward left, right, or front) |

## Complete game-script inventory

This inventory accounts for all 47 GDScript files under `scripts/games/`: 11
production modules and 36 supporting simulation, presentation, and verification
files.

### Shared presentation and Scratch Ticket support

| Path | Responsibility |
| --- | --- |
| `scripts/games/playing_card_renderer.gd` | Shared card face, back, rank, and suit drawing used by card games and ticket art. |
| `scripts/games/table_game_visuals.gd` | Shared room/table/dealer/patron/chip presentation and autonomous character poses for table games. |
| `scripts/games/scratch_ticket_background_renderer.gd` | Ticket paper, panel, and authored-region backgrounds. |
| `scripts/games/scratch_ticket_icon_renderer.gd` | Ticket symbols, numbers, cards, and mechanic-specific iconography. |
| `scripts/games/scratch_ticket_foil_renderer.gd` | Latex/foil layer rendering. |
| `scripts/games/scratch_ticket_mask.gd` | Scratch-mask mutation, interpolation, completion, and data coercion. |
| `scripts/games/scratch_ticket_region_model.gd` | Authored ticket-region normalization and geometry. |
| `scripts/games/scratch_ticket_machine_renderer.gd` | Detailed lottery/trading-card-style cabinet, lift shelf, stock glass, console, tray, waste basket, lights, and 1.5-second dispense animation. |
| `scripts/games/video_poker_renderer.gd` | Three-cabinet video-poker glass, paytable, cards, holds, controls, ritual state, and result presentation. |

### Slot support

| Path | Responsibility |
| --- | --- |
| `scripts/games/slots/slot_catalog.gd` | Formats, families, math/cabinet/bonus variants, symbols, and content lookup. |
| `scripts/games/slots/slot_definition_cache.gd` | Immutable content-derived definitions shared by matching cabinets. |
| `scripts/games/slots/slot_machine_generator.gd` | Deterministic cabinet generation from run and environment RNG. |
| `scripts/games/slots/slot_machine_state.gd` | Canonical persistent machine schema, fixed bet ladder, selected bet, and active bonus state. |
| `scripts/games/slots/slot_resolver.gd` | Spin/nudge resolution, payout attribution, economy changes, feature opening/steps, and animation plans. |
| `scripts/games/slots/slot_family_pinball.gd` | Pinball reel rules, payouts, and feature-runtime adapter. |
| `scripts/games/slots/slot_family_buffalo.gd` | Buffalo ways, free games, Hold and Spin, wheel/monster paths, Gold Buffalo conversion, meters, and jackpots. |
| `scripts/games/slots/slot_presentation.gd` | Normalized surface-state projection. |
| `scripts/games/slots/slot_renderer.gd` | Procedural cabinet, reels, feature board, meters, and celebration drawing. |
| `scripts/games/slots/slot_rng_math.gd` | Stateless deterministic weighted picks and reel/grid math. |
| `scripts/games/slots/pinball/pinball_board.gd` | Compiled pinball board model. |
| `scripts/games/slots/pinball/pinball_boards.gd` | Authored board definitions and compiler entry. |
| `scripts/games/slots/pinball/pinball_feature.gd` | Feature lifecycle and slot-family bridge. |
| `scripts/games/slots/pinball/pinball_items.gd` | Pinball item hooks and modifiers. |
| `scripts/games/slots/pinball/pinball_sequencer.gd` | Feature event ordering and presentation sequence. |
| `scripts/games/slots/pinball/pinball_sim.gd` | Deterministic pinball feature simulation. |

### Craps support

| Path | Responsibility |
| --- | --- |
| `scripts/games/craps/craps_rules.gd` | Table rules, wager validation, roll resolution, odds, payoffs, and refund behavior. |
| `scripts/games/craps/craps_surface_view_model.gd` | Player-safe table and wager presentation model. |

### Coin Pusher support

| Path | Responsibility |
| --- | --- |
| `scripts/games/coin_pusher/coin_pusher_live_session.gd` | Live cabinet session, bounded scheduling, snapshot publication, and settle handling. |
| `scripts/games/coin_pusher/coin_pusher_renderer.gd` | Cabinet/body projection, retained layers, live-body batches, and visual effects. |
| `scripts/games/coin_pusher/coin_pusher_solver.gd` | Authoritative deterministic fixed-point body solver. |
| `scripts/games/coin_pusher/coin_pusher_solver_api.gd` | Stable native/fallback solver facade. |
| `scripts/games/coin_pusher/coin_pusher_static_cache_canvas.gd` | Retained static cabinet layer. |
| `scripts/games/coin_pusher/coin_pusher_hardware_cache_canvas.gd` | Retained hardware/apparatus layer. |
| `scripts/games/coin_pusher/jackpot_ridge.gd` | Jackpot Ridge goals, apparatus, and variation behavior. |
| `scripts/games/coin_pusher/vault_drop.gd` | The Vault Drop goals, door/vault actions, and variation behavior. |
| `scripts/games/coin_pusher/coin_pusher_export_parity_runner.gd` | Native/Web parity-runner entry point; it is verification support, not a playable module. |

## Game data inventory

| Path | Responsibility |
| --- | --- |
| `data/games/games.json` | Eleven production definitions, module paths, catalog actions, game tuning, and machine variations. |
| `data/games/scratch_tickets.json` | The seven ticket identities, mechanics, weighted prizes, art tuning, and RTP bands. |
| `data/games/scratch_ticket_regions.json` | Ticket scratch/print region geometry. |
| `data/games/bar_dice_game_ritual_v1.json` | Bar Dice phase and surface ritual contract. |
| `data/games/showdown_duel_game_ritual_v1.json` | Rourke duel game ritual. |
| `data/games/showdown_duel_ritual_v1.json` | Rourke walk, pat-down, interrogation, and duel sequence. |
| `data/games/rituals/craps06_3_environment_bindings.json` | Casino/street/interruption Craps environment bindings. |
| `data/games/rituals/craps06_3_sequences.json` | Craps table and dice ritual sequences. |
| `data/games/rituals/crew06_10_poker_nights.json` | Five Crew poker-night contexts and their table framing. |

## Release boundary

The 0.6 feature set above is complete in source. The remaining release-authoring
task is the manual 75-context environment slot-placement pass, its exported
schema-3 report, promotion of the approved coordinates, and focused
post-promotion validation. That placement task can move where game objects
appear in rooms; it does not change this game roster or the mechanics documented
here. Final packaging and publication remain explicit owner actions.
