# Grand Casino Endgame Design Lock

Status: **IMPLEMENTED for 0.5.0 (in development).** This document is the
authoritative description of the shipped Grand Casino rework. The canonical
ids and save-compatible state names below are binding. The earlier 0.4
single-room and single-roll finale contracts are explicitly superseded at the
end of this document.

The implementation sources are `data/environments/archetypes.json`,
`data/events/events.json`, `data/collections/collections.json`,
`scripts/core/run_state.gd`, `scripts/core/grand_casino_showdown_model.gd`,
`scripts/core/grand_casino_duel_model.gd`, and
`scripts/core/meta_collection_service.gd`.

## Narrative Contract

The Grand Casino is Act 1's boss destination. The honest route asks the player
to sustain low-heat winning, climb Linda's Bronze/Silver/Gold Players Card
ladder, and deliberately claim Gold at the Cage. The cheat route asks the
player to read a living floor, act while Rourke is elsewhere, survive the walk
and pat-down, answer three run-specific questions, and play a five-hand
heads-up blackjack duel against him.

Both routes are terminal Act 1 outcomes. A Gold-card victory records a door
into Act 2, but 0.5 does not make Act 2 playable.

## Canonical IDs

These values must never be renamed. They are used by saves, reports, events,
tests, and meta rewards.

| Purpose | Canonical value |
| --- | --- |
| Grand Casino archetype / Main Floor | `grand_casino` |
| High-Limit Room archetype | `grand_casino_high_limit` |
| Back Room archetype | `grand_casino_back_room` |
| Grand Casino objective id | `grand_casino_demo_bankroll` |
| Showdown event id | `the_house_calls` |
| Players Card event id | `high_roller_cashout` |
| Showdown failure reason | `casino_taken_out_back` |
| Clean victory route | `high_roller_cashout` |
| Heat victory route | `pit_boss_showdown` |

`the_house_calls` remains the complete four-phase Rourke encounter. The event
id is not a label for a separate legacy check. `high_roller_cashout` is both
the Cage review event id and the clean route stored in `demo_victory_route`.

The duel's outcome ladder has its own canonical ids:

| Outcome | Canonical value | Terminal meaning |
| --- | --- | --- |
| Walk out clean | `walk_out_clean` | Showdown-route victory; the Cage cashes the rack. |
| Shown the door | `shown_the_door` | Showdown-route victory with uncashed chips kept as a meta item. |
| Taken out back | `taken_out_back` | Failure through `casino_taken_out_back`. |

## Four-Room Casino

The casino is one stateful venue split into four walkable sub-environments:

| Room | Contents | Access |
| --- | --- | --- |
| Main Floor (`grand_casino`) | Slots, video poker, pull tabs, bar dice, Linda's host desk, and room doors. | World-map arrival. |
| High-Limit Room (`grand_casino_high_limit`) | Boss-config blackjack, baccarat, and roulette tables. | Silver Players Card or a $60 cash buy-in. |
| Back Room (`grand_casino_back_room`) | The Rourke heads-up blackjack duel. | Only while the showdown duel is active. |
| Cage (`grand_casino_cage`) | Linda's service counter, the Grand Casino ATM, and a chip-priced gift case. | Freely accessible from the Main Floor. |

Room movement takes five in-world minutes and is not world-map travel. Heat,
attention, evidence, chips, card progress, staff memory, and showdown state are
shared across all four rooms. The Cage is a physical fourth room and does not
open a modal window.

## Chips and the Cage

Every Grand Casino game uses `grand_casino_chips` for payouts. Wagers consume
the chip rack first and seamlessly cover any shortage from bankroll cash;
outside the Grand Casino those same games remain cash-only. Chip purchase and
cash-out are 1:1 transfers, so neither operation changes Grand Casino net winnings. The clean
objective always measures:

```text
(bankroll + grand_casino_chips) - grand_casino_entry_bankroll
```

Linda's tier chip bonuses increase the rack and the remembered entry baseline
by the same amount, so comps cannot manufacture objective profit.

Linda's Cage counter is the single service point for buying chips, settling
casino ATM marker debt before cashing excess chips to bankroll, reading exact
next-tier progress, claiming drink and suite comps, and completing the
deliberate sequential Players Card claims. The Cage ATM issues $50 marker
increments and accrues 5% interest (rounded up) at each crossed 3:00 AM. During
a showdown the counter is locked. After `shown_the_door`, cash-out remains
permanently denied for that ending.

## Objective and Players Card Ladder

The following values are current data, repeated on all four room archetypes:

| Field | Value | Meaning |
| --- | ---: | --- |
| `high_roller_net_winnings` | 30 | Gold net-winnings target. |
| `high_roller_min_grand_casino_games` | 5 | Gold settled-game target. |
| `high_roller_max_heat` | 30 | Clean-route heat ceiling. |
| `players_card_bronze_min_games` | 1 | Bronze settled-game target. |
| `players_card_bronze_net_winnings` | 5 | Bronze net target. |
| `players_card_bronze_max_heat` | 30 | Bronze heat ceiling. |
| `players_card_bronze_chip_bonus` | 5 | Comped chips, baseline-neutral. |
| `players_card_bronze_drink_comps` | 1 | Claimable drink comp. |
| `players_card_silver_min_games` | 3 | Silver settled-game target. |
| `players_card_silver_net_winnings` | 15 | Silver net target. |
| `players_card_silver_max_heat` | 30 | Silver heat ceiling. |
| `players_card_silver_chip_bonus` | 10 | Comped chips, baseline-neutral. |
| `players_card_silver_drink_comps` | 1 | Additional drink comp. |
| `players_card_silver_suite_rests` | 1 | Four-hour suite rest. |
| `players_card_gold_min_games` | 5 | Gold settled-game target. |
| `players_card_gold_net_winnings` | 30 | Gold net target. |
| `players_card_gold_max_heat` | 30 | Gold heat ceiling. |
| `players_card_look_away_max_heat_gain` | 5 | Largest one-shot gain Linda can forgive. |
| `showdown_heat_threshold` | 70 | Attention plus heat calls Rourke. |
| `forced_showdown_heat_threshold` | 95 | Heat alone calls Rourke. |

A settled Grand Casino wager counts once when a successful game result has a
nonzero stake or stake cost. UI navigation, bet placement, holds, clears,
undo, and other surface-only actions do not count.

Tier progression is monotonic while eligible:

- Bronze opens Linda dialogue and grants five baseline-neutral chips plus one
  drink comp.
- Silver opens the High-Limit Room, grants ten baseline-neutral chips, one
  drink comp, one suite rest, and arms Linda's one-shot low-heat look-away.
- Gold exposes `high_roller_cashout` at the Cage. It does not auto-win.

Any Grand Casino result authored as `action_kind == "cheat"`, or an active
item explicitly used as a cheating tool, permanently makes the run ineligible
for every Players Card tier. A watched cheat is the severe subset. Later clean
play cannot restore eligibility or Silver access.

## Linda, Staff, and Casino Memory

Linda is the permanent Cage host and clean-route counterpart to Rourke. Her
dialogue announces Bronze and Silver, the Cage presents progress and comps,
and her Gold review ends the clean route. Her look-away may forgive one heat
gain of five or less while the player remains eligible.

Blackjack, baccarat, roulette, and bartender roles have seeded rosters. On an
in-run day rollover each role independently follows the data-authored 50%
rotation chance. Rourke and Linda never rotate. Re-entry cues surface pending
reviews, Rourke pressure, remembered cheat evidence, high heat, or simple
recognition. Staffing, memory, and room states round-trip through saves.

## Living Rourke and Rival Cheaters

Rourke occupies exactly one room and authored spot at a time. His state changes
only at action boundaries. Recent room heat decays to 80% at each evaluation;
every three eligible actions he moves at most one room toward the hottest room,
subject to a two-heat inertia margin. His position and facing are visible, and
`pit_boss_watch_status()` is spatial: he watches only the player's room.

Each casino visit has one to three seeded rival cheaters on the Main and
High-Limit floors. Their action-boundary heat can pull Rourke away. A 12%
seeded escort opportunity can take a rival to the Back Room, leaving Rourke
off the public floor for four actions. Rare tier-2 cameos establish prior
Rourke history. No movement, rotation, escort, or rival draw uses wall-clock or
engine-global randomness.

Staff attention is the aggregate of these concrete sources:

| Source key | Source |
| --- | --- |
| `rourke_watch` | Rourke is active, present, and watching in the player's room. |
| `watched_cheat` | Persistent watched-cheat evidence. |
| `pit_boss_sweep` | The player acted natural during the sweep. |
| `eye_in_the_sky` | An unresolved camera event or pressing onward. |
| `watched_risky` | A risky action resolved while spatially watched. |
| `host` | The player accepted the watched suite offer. |
| `high_roller_review` | Profit is ready but heat/evidence blocks clean review. |
| `forced_heat` | Heat reached the forced threshold. |

At heat 70, an active source routes the run to `the_house_calls`. Heat 95
forces the route even without another source. Grand Casino heat routing runs
before generic police capture; non-Grand environments retain normal capture.

## Endgame State Machine

`narrative_flags["grand_casino_endgame_state"]` uses only:

- `pre-grand`
- `grand-incomplete`
- `high-roller-ready`
- `showdown-pending`
- `showdown-active`
- `victory`
- `failure`

Important transitions are:

| From | Trigger | To / effect |
| --- | --- | --- |
| `pre-grand` | Enter any Grand Casino room. | `grand-incomplete`; initialize entry value and shared room state. |
| `grand-incomplete` | Gold criteria met while eligible. | `high-roller-ready`; expose the Cage review without ending the run. |
| `grand-incomplete` | Heat+attention, forced heat, or dirty profit. | `showdown-pending`; set `the_house_calls_pending`. |
| `high-roller-ready` | Complete Linda's Cage review. | `victory` through `high_roller_cashout`. |
| `high-roller-ready` | Cheat or cross a blocker before review. | `showdown-pending`. |
| `showdown-pending` | Answer Rourke's call. | `showdown-active`, phase `walk`. |
| `showdown-active` | `walk_out_clean` or `shown_the_door`. | `victory` through `pit_boss_showdown`. |
| `showdown-active` | Blatant pat-down or `taken_out_back`. | `failure` through `casino_taken_out_back`. |

Leaving the casino without a pending finale clears the temporary clean-review
surface but preserves durable games, evidence, tier, memory, and attention for
re-entry. A pending or active showdown owns the terminal path and cannot be
converted into a generic police-capture result.

## Rourke Showdown

The showdown is saveable at every phase. Every random choice uses a named
`RngStream` fork keyed by attempt, hand, or action boundary.

### Phase 1: Walk

The player gets exactly one choice: keep everything, trash one run-inventory
item, or hand one item to the Crew when the run established Crew ties. Trash
uses a 15% deterministic seen chance and adds four heat when seen. A Crew
handoff is removed during the encounter and returned on either successful
duel ending; failure loses it.

### Phase 2: Pat-Down

The search classifies actual carried ids:

- Contraband: `marked_cards`, `foil_sleeve`, `weighted_keyring`.
- Surveillance: `xray_glasses`, `tab_detector`, `tarot_card`.

| Tier | Rule | Result |
| --- | --- | --- |
| Clean | No classified items. | No penalty. |
| Minor | One contraband item. | Classified items confiscated. |
| Serious | Surveillance present or at least two contraband items. | Confiscation, 18-stack handicap, and +5 forced ante. |
| Blatant | At least three contraband items, or watched cheat plus contraband. | Immediate `casino_taken_out_back` failure. |

### Phase 3: Interrogation

Three evidence beats are selected from the real run ledger: watched/ordinary
cheats, attention, debt, drink, cameos, card status, clean games, Linda
standing, Crew ties, heat, winnings, and games played. Each answer is saved.

- `hold_steady` leans on clean play and held-item support.
- `talk_down` leans on Linda/Crew support and is weakened by drink/debt.
- `take_the_edge` offers the largest pressure modifier but creates watched
  cheat evidence.

The averaged answers, prior events, heat, evidence, debt/drink state, social
support, and pat-down tier produce explicit starting stacks, forced ante,
Rourke aggression, and Rourke cheat level. The duel is not a hidden success
roll.

### Phase 4: Heads-Up Blackjack Duel

The duel is a boss-configured use of the existing blackjack module. It lasts
at most five hands with a base ante of 20. The base stack is 100; Rourke gains
five starting chips per aggression level. Rourke's edge chance is 10% plus 20%
per cheat level. Correctly calling the visible edge swings 18 chips; a false
call costs six. Player cheat detection starts at 55%, adds five per aggression
and five per cheat level, and being caught costs 18 chips.

The duel ends early if either stack reaches zero. Otherwise the margin after
five hands determines the ladder:

| Margin | Outcome |
| ---: | --- |
| `>= 12` | `walk_out_clean` |
| `>= -60` and `< 12` | `shown_the_door` |
| `< -60` | `taken_out_back` |

`walk_out_clean` cashes chips and ends in showdown-route victory.
`shown_the_door` ends in showdown-route victory but preserves only 50% of the
uncashed rack's face value in score and mints the full rack as a meta item.
`taken_out_back` fails the run with the canonical failure reason.

## Meta Rewards and Prestige

A clean Gold victory mints one unique `Grand Casino Players Card` collection
instance (`itemdef_id` 9500). Its run stamp includes the seed, score, day,
highest tier, and route. It is pinned at condition 0.08 in the critical band,
does not normally decay, cannot be repaired, and is destroyed forever if
carried into a failed run.

Carrying a Players Card starts a prestige run. On Grand Casino entry it lowers
heat by 10, tightens every clean tier's heat ceiling by five, and raises the
meta collection drop tier by one step. The card remains on success and is
reported as destroyed on failure.

`shown_the_door` mints one stackable `Grand Casino Chips` collection instance
(`itemdef_id` 9501) with face value equal to the uncashed rack. It is not
loadout-eligible. Sal's meta-home pawn counter fences it for 60% of face value
in gold.

The run report presents minted cards, retained/destroyed prestige cards, and
uncashed chip stacks from terminal state. Meta settlement is idempotent.

## Act 2 Seam

Only a Gold-card clean victory sets `act_two_seam_ready = true`. It logs one
`act_two_seam` story entry and the run report adds exactly one line:

> The Gold card opens doors beyond this city.

The run still ends as the Act 1 `high_roller_cashout` victory. The flag and
copy do not promise a playable transition or new screen in 0.5.

## Persistence Contract

All shared room, chips, living-floor, staff, tier, showdown phase, duel, and
outcome state is serialized through typed `RunState` fields or
`narrative_flags`. The central flags include:

- Objective: `grand_casino_entry_bankroll`, `grand_casino_games_played`,
  `grand_casino_net_winnings`, `grand_casino_max_heat`.
- Card: `grand_casino_players_card_tier`,
  `grand_casino_players_card_highest_tier`,
  `grand_casino_players_card_ineligible`, tier benefit flags, comp counts, and
  Linda look-away flags.
- Attention/evidence: `grand_casino_cheat_evidence`,
  `grand_casino_watched_cheat_evidence`, `grand_casino_staff_attention`, and
  `grand_casino_staff_attention_sources` plus the concrete attention flags.
- Showdown: `grand_casino_showdown_pending`,
  `grand_casino_showdown_active`, `grand_casino_showdown_step`, walk/pat-down/
  interrogation state, `grand_casino_duel_terms`, `grand_casino_duel_state`,
  `grand_casino_duel_outcome`, and `grand_casino_showdown_margin`.
- Compatibility: `demo_finale_ready`, `demo_finale_pending`,
  `demo_finale_event_id`, `demo_finale_completed`, and
  `the_house_calls_pending`.

Mid-showdown loads resume the saved phase. The retained
`legacy_phase_4` migration exists only to upgrade slice-boundary saves into the
playable duel; no current event path authors that phase.

## Superseded 0.4 Contracts

The following historical designs are not current behavior and must not be
reintroduced:

- One `grand_casino` boss room containing both machines and public tables.
- A fixed alternating watch cycle unrelated to Rourke's spatial room state.
- An abstract clean cashout event away from Linda's physical Cage counter.
- A single deterministic `showdown_roll` checked against a synthesized
  `showdown_success_chance`.
- A binary pass/fail showdown without `walk_out_clean`, `shown_the_door`, and
  `taken_out_back`.
- Silent item/evidence modifier math in place of the visible walk, pat-down,
  interrogation, and duel terms.
- Treating Players Cards as transient flags with no meta item, fragility, or
  prestige carry-in.

The canonical ids and broad state names from the 0.4 design remain binding;
the shipped 0.5 mechanics in this document supersede the old implementation
instructions and formulas.
