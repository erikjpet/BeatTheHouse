# Feat 06.1 — Scratch Scalper Ticket Trade

Status: **COMPLETE / ROW-LOCAL GATES GREEN**
Claim commit: `600a0fba`
Implementation commits: `ddf7c4dc`, `b7edb89b`
Completed: 2026-09-12

## Player result

When Vince is present beside a scratch-ticket machine, a player carrying an
untouched ticket can now offer it to him. The choice says before confirmation
that the ticket might have been a winner. Vince consumes one untouched ticket,
reduces heat at the current location by **8 points**, and has a declared **33%**
chance to hand over a low-tier within-run item. Both the reward and no-reward
outcomes name what happened on screen.

The trade is limited to one ticket per `scalper_visit_token`. That token and the
consumed ticket state are saved, so save/load, revisit, travel, abort, or expiry
cannot repeat the heat change or item grant. Queued tickets are selected before
the ticket on the machine. A table ticket is eligible only while no cell has any
coverage removed and `result_ready` is false.

## Shipped numbers and deterministic boundaries

| Decision | Shipped value | Interpretation |
| --- | ---: | --- |
| Heat reduction | 8 | Eight integer points on the 0–100 meter, applied through the ordinary per-location suspicion result path. |
| Item chance | 33% | One run-RNG roll at the accepted dialogue action boundary. A fixed 10,000-draw sample returned 3,280 rewards (**32.8%**). |
| Restock-arrival chance | 20% | One deterministic roll per eligible restock boundary from `scratch-restock-scalper-arrival:<machine>:<minute>`. |
| Gift limit | 1 per encounter | Persisted against the existing visit token; no queue or time reset can bypass it. |
| Transit cap | 8 people | Stable object-id order; overflow arrivals settle immediately and overflow departures leave immediately. |

A scalper who arrives at a restock boundary does **not** intercept that boundary:
the stock lands first, and Vince intercepts only later boundaries while present.
This follows the requested default and avoids silently taking stock the player
never had a chance to see. Existing already-present interception, the 30% visit
chance, the exact 50/50 knowledge split, prices, odds, payouts, RTP, and restock
quantities are unchanged. Tutorial and practice suppression applies to both the
trade and restock arrival.

## Low-tier item rule

“Low tier” is a checked-in item-data rule, not a meta-collection tier. The pool
contains ordinary items whose `sellable` flag is true, whose class is
`permanent` or `temporary`, whose `price_min` and `price_max` are positive, and
whose integer `sale_price` is from 1 through 8 inclusive. The ids are sorted
before the seeded draw. Challenge-disabled and already-owned items are excluded
at action time; no collection progress is granted.

The resulting base pool is:

`card_counters_notes`, `cheap_sunglasses`, `creased_luck_card`,
`freds_poker_hat`, `ledger_pencil`, `lucky_bar_napkin`, `lucky_keychain`,
`payment_calendar`, `payout_pamphlet`, `pocket_watch`, `roadside_map`,
`scratch_pad`, `side_bet_chart`.

These read as cheap paper goods, personal trinkets, notes, and pocket objects a
street reseller could plausibly carry. Consumables, containers, scenario
souvenirs, and collection-only rewards do not enter the pool.

## Hidden information and exactly-once proof

The informed and oblivious dialogue definitions contain byte-identical trade
choice data. A paired observer test changes only
`scalper_knows_schedule`; eligibility, displayed terms, consumed ticket,
message, reward id, and all result deltas remain identical. The post-trade
conversation note is also identical. Tests cover queue preference, active-ticket
fallback, any partial scratch, no ticket, practice, tutorial, repeat attempts,
old-save defaults, save/reload, and deterministic replay.

## People arriving and leaving

Mid-visit person-list changes now reuse the canvas actor `route_points` and
`route_stage` vocabulary. The canvas reads the room's authored doorways and
floor bands, chooses the nearest doorway, and stages a doorway/floor/settled
polyline at the existing 82 px/s speed and 0.75–8.0 second bounds. Arrivals are
non-interactive until settled; departures become non-interactive immediately.
Logical game state remains immediate, room entry and reload settle people, and
reduced motion preserves the same semantic state without transit.

The canvas-only overlay never changes the settled records inspected by placement,
label, hit, lane, or finalization authority. The permanent test verifies input
records remain byte-identical, transit hit rectangles are empty, room entry does
not parade existing people, reduced motion settles, reload settles, departures
are removed, and ten simultaneous arrivals animate the deterministic first eight.

Rendered evidence is retained locally in
`review_artifacts/feat06_1/arrival_start.png`, `arrival_mid.png`,
`arrival_settled.png`, `departure_start.png`, `departure_mid.png`, and
`departure_gone.png`.

## Performance evidence

The same rendered gas-station room was sampled for 240 frames per phase on an
NVIDIA GeForce RTX 4070 Ti using Godot 4.6 Compatibility rendering:

| Phase | Average frame | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Room idle | 0.674 ms | 0.736 ms | 2.374 ms |
| One active transit | 0.715 ms | 1.881 ms | 2.869 ms |

Average measured transit cost was **+0.042 ms/frame**. Idle liveness recorded
13 redraws during its 240-frame sample, so the transit does not manufacture the
required nonzero idle signal. Per-frame route reads no longer deep-copy route
arrays or stages; completion is capped and allocates only at state boundaries.
The retained raw report is `review_artifacts/feat06_1/report.json`.

## Verification

- Project validation: PASS (97.281 s during implementation; repeated at closeout).
- Production/tool script load: PASS, 338 scripts, zero failures.
- Scratch-ticket registered check only: PASS, one check, zero failures, 2.650 s.
- Scenario finalization: PASS, 8 seed families × 55 scenarios = 440/440;
  17,984 reachable states and 3,768 distinct layouts; normal, expanded-small,
  routes, and object census preserved.
- Foundation determinism: PASS twice, 10 seeds and 642 checkpoints per run,
  identical combined hash `1742659726`.
- Seeded reward measurement: 3,280/10,000 = 32.8% against declared 33%.

The canonical scratch wrapper also registers the broad `content` check before
the scratch row. That broader portion returned 19 current layout/content
assertions and made the wrapper exceed its narrow 19.024-second allowance; none
were changed or suppressed here. The separately selected registered
`scratch_tickets_game_suite` completed with zero failures. This is recorded as a
runner-composition deviation, not represented as a green canonical wrapper.

## Possible tuning after playtest

The 20% restock-arrival rate was unspecified by the owner and is the number most
worth observing in playtest: combined with the existing 30% visit encounter, it
may make Vince feel too frequent in long machine sessions. It was not adjusted
without evidence. The one-per-encounter protection should remain even if either
chance changes.

