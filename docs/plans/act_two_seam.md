# Act Two Seam Contract

This is the Act 1 handoff contract. It records a small, versioned payload for a
future Act 2 without adding Act 2 rooms, economy, prestige, or story content.

## Carry Forward

The only cross-act run data is `ProfileInventory.act_seam`, written when an
Act 1 Grand Casino victory reaches the terminal victory path.

The payload carries:

- `source_act`: `1`
- `target_act`: `2`
- `victory_route`: `players_card_cashout` or `showdown`
- `demo_victory_route`: the raw RunState route id used by the Grand Casino
- `final_bankroll_band`: a band, not exact cash
- `story_flags`: the run's `story_flags` dictionary, empty when no dialogue
  story flags have landed in the run
- `route_payload`: small route-specific tone markers for future interpretation

Profile lifetime stats, run history, daily streaks, and challenge completions
remain in their existing profile sections. They are not duplicated into the seam.

## Route Payloads

The two Act 1 victory routes must remain distinct:

| Route | Payload hook | Meaning |
| --- | --- | --- |
| `players_card_cashout` | `players_card_open_rooms` | The player left clean enough to be treated as valuable. |
| `showdown` | `rourke_remembers` | The player survived Rourke, but the house noticed. |

## Bankroll Bands

Act 2 receives only a band:

| Band | Final bankroll |
| --- | ---: |
| `empty_pockets` | `< 50` |
| `walking_money` | `50-149` |
| `solid_winnings` | `150-399` |
| `heavy_envelope` | `400-799` |
| `house_money` | `800+` |

## Reset

Everything not listed above resets with the run:

- Current room, world map, pending events, game states, inventory, debt, heat,
  alcohol state, clocks, RNG stream position, and temporary narrative flags.
- Failure routes write no `act_seam`.
- Act 2 does not consume this payload in this release.

## Persistence

Run saves write `act: 1` at the save envelope and RunState levels. Markerless
0.3 saves migrate to Act 1 on load.

Profiles write `act: 1` and schema version 3. Markerless old profiles normalize
with an empty `act_seam`; successful Act 1 victories replace it with the latest
cross-act payload.

## Victory Hook Copy

The victory screen uses route-specific, diegetic hooks:

- Players Card: "The Players Card opens quieter rooms. Your name is now on the list."
- Showdown: "Rourke lets the elevator close. The house will remember your face."

These are hooks only. They do not promise Act 2 content, prestige purchases, or
new meta-currency.
