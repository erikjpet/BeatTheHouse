# Beat the House — Games and Performance Playtest Report

**Date:** 2026-09-20  
**Candidate:** `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`  
**Role:** senior games/performance playtester  
**Scope:** all eleven playable game modules, common item/cheat hooks, game-surface generation, resolve-path performance, sustained animation paths, deterministic practice fixtures, and stuck-state guards. No source fixes were made.

## Executive summary

All eleven game modules loaded and completed their current automated gameplay contracts. The current performance probe also passed every frame and resolve-path budget. Earlier local reports of slow Blackjack, Baccarat, and Roulette resolves did **not** reproduce on this candidate and are not filed as bugs.

Two severe readability failures were reproduced in two consecutive production Bar Dice frames. They are best treated as two exact sub-overlaps within the already-known broad UI finding **UIE-022**, rather than inflated into a second duplicate bug family:

1. the three Rail Cups panels cover the left-side patrons' names, tells, and bodies;
2. the shared dealer attention/danger/read-window widgets cover the right-center patron Iris.

Both are deterministic geometry defects, not transient animation artifacts. The current layout test passes because it checks only text panels against patron safe rectangles and patrons against one another; it does not include the Rail Cups panels or dealer-status widgets in collision validation.

The full functional suite exceeded its aggregate historical wall-time allowance (276.188 s against a 220.425 s allowance), but every shard exited successfully and the dedicated player-frame probe was green. This is recorded as a harness-duration anomaly, not a player-facing performance bug.

## Confirmed findings

### UIE-022-A — Bar Dice Rail Cups panels obscure the left patron rail

**Severity:** Major / P2  
**Frequency:** 2/2 consecutive production frames  
**Area:** Bar Dice, in-game table readability  
**Evidence:** `.tmp/agent_playtest_24h_ui/0013.png`, `.tmp/agent_playtest_24h_ui/0014.png`

**Reproduction**

1. Enter a Bar Dice table with the normal four-patron production layout.
2. Advance to a hand in which opponent cup rows are visible.
3. Inspect the left rail around the first patron and the Rail Cups panel stack.

**Expected:** Opponent dice, patron identity, body-language tell, and character art each occupy readable, non-overlapping regions.

**Actual:** The Rail Cups stack is painted across the left patron rail. Patron names/tells are clipped or hidden behind the three opaque dice panels, and parts of the character presentation are visually disconnected from their labels.

**Measured geometry:** The first opponent panel is `Rect2(68, 136, 164, 48)`. Patron 0's declared safe region is `Rect2(44, 30, 142, 158)`. Their intersection is `118 × 48 = 5,664` design-space pixels. The next two opponent rows continue down the same x-range, so the obstruction persists through the remaining left-side identity/tell rows.

**Root cause:** `scripts/games/bar_dice.gd:70-80` hard-codes opponent row origins at x=76 while placing the first patron at x=94. `_draw_opponent_dice_rows()` constructs 164×48 panels beginning eight pixels left of those origins (`scripts/games/bar_dice.gd:3191-3208`). Patron safe rectangles are independently derived as 142×158 regions around the hard-coded patron positions (`scripts/games/bar_dice.gd:3495-3500`). No layout solver or collision check relates these two systems. Draw order makes the defect destructive: patrons are drawn first and dice rows later (`scripts/games/bar_dice.gd:552-565`), so the opaque row panels cover the patron content.

**Why existing tests missed it:** `scripts/tests/foundation/check_table_games.gd:7444-7467` validates `text_panel_rects` against `patron_safe_rects` and patron-safe rectangles against each other. Rail Cups rectangles are not exported into either tested collection.

**Fix options (for a later implementation agent):**

- Move opponent rows to a dedicated rail lane that does not intersect any patron safe rectangle.
- Shift the left patron positions right/up and reserve the full Rail Cups stack before seating patrons.
- Preferably expose opponent-panel rectangles as layout metadata and add a general pairwise collision assertion against patron safe rectangles. This prevents the same failure from returning when row count or scaling changes.

### UIE-022-B — Bar Dice dealer-status widgets cover Iris, the right-center patron

**Severity:** Major / P2  
**Frequency:** 2/2 consecutive production frames  
**Area:** Bar Dice, attention/tell readability  
**Evidence:** `.tmp/agent_playtest_24h_ui/0013.png`, `.tmp/agent_playtest_24h_ui/0014.png`

**Reproduction**

1. Enter the same Bar Dice production table.
2. Observe the dealer attention meter, danger/gaze meter, and `calls cargo`/read-window panel at center-right.
3. Compare those widgets with Iris's sprite, name, and tell.

**Expected:** Dealer attention information and the neighboring patron presentation are simultaneously legible.

**Actual:** The fixed dealer widgets run through Iris's sprite and text. In both observed frames, meter captions and Iris's name/tell are layered into one unreadable block.

**Measured geometry:** Iris uses patron position `(660, 70)`, giving declared safe region `Rect2(610, 16, 142, 158)`. The shared dealer renderer places widgets at `Rect2(566, 92, 118, 9)`, `Rect2(566, 116, 118, 6)`, and `Rect2(566, 130, 122, 22)`. Those three intersections occupy 666, 444, and 1,716 design-space pixels respectively, or **2,826 pixels total** inside Iris's safe region.

**Root cause:** Bar Dice uses the shared fixed-coordinate `draw_dealer_station()` without adapting its right-side widget lane to Bar Dice's custom patrons. The station always writes its meters/panel from x=566 through x=688 (`scripts/games/table_game_visuals.gd:139-178`), while Bar Dice fixes the third patron around x=660 (`scripts/games/bar_dice.gd:75-80`). As with UIE-022-A, these rectangles are absent from the collision metadata used by the test.

**Fix options (for a later implementation agent):**

- Supply Bar Dice-specific status-widget bounds that fit inside the central dealer station.
- Move Iris to a genuinely free right rail position and recompute patron safe rectangles from the final layout.
- Make the shared dealer renderer return/export its occupied rectangles, then validate them against each game's patron-safe regions.

## Functional coverage

The serialized `foundation_games` run completed all four shards with exit code 0, ten checks passing, zero functional failures, and no stderr findings. Coverage included content validation, game surfaces, table environment entry, module contracts, activation guards, cross-game integration, Slot smoke coverage, and Coin Pusher coverage.

| Game | Exercised coverage | Result |
|---|---|---|
| Scratch Tickets | stock/generation, purchase, pointer scratch path, reveal/settlement, resolve budget | Pass |
| Pull Tabs | stock/generation, buy/reveal, settlement, file/state hooks, resolve budget | Pass |
| Slot / Pinball / Buffalo | cabinet generation, spin, autoplay, family/format fixtures, persisted machine state, preview, resolve budget | Pass |
| Coin Pusher | generation, live native-physics sequence, full 150-body cap, ceiling refusal, solver timing, collect path | Pass |
| Bar Dice | generation, wager/actions, tumble input guard, opponent rows, practice fixture, resolve budget | Functional pass; visual failures UIE-022-A/B |
| Craps | street and full-table surfaces, wager pages, roll/settlement paths, practice and generated fixtures, resolve budget | Pass |
| Blackjack | wager/action authority, hit/stand/split/double, side bets, count/peek surfaces, resolve budget | Pass |
| Baccarat | wager/commission, read/edge-sort surfaces, settlement, resolve budget | Pass |
| Roulette | inside/outside betting, spin/settlement, past-post surface, resolve budget | Pass |
| Video Poker | bet/deal, holds/draw, double-up, mark-holds surface, resolve budget | Pass |
| Back-Room Hold'em (`crew_draw_poker`) | actor-present fixture, deal/actions/showdown, authority/persistence contract, resolve budget | Pass |

The current game-surface coverage map recorded all eleven IDs: Baccarat 1, Bar Dice 1, Blackjack 1, Coin Pusher 1, Craps 3, Crew Draw Poker 1, Pull Tabs 1, Roulette 1, Scratch Tickets 1, Slot 1, and Video Poker 1.

## Performance results

The current dedicated probe used 8 seeded runs, 120 sampled frames per surface, and 48 resolve samples per game. It exercised all eleven surfaces, all ten discrete resolve paths (Coin Pusher is measured through its live active-sequence path), Slot autoplay, Scratch pointer input, casino Slot preview, Coin Pusher full-cap/refusal/native-solver paths, and Grand Casino living-floor rendering.

| Resolve path | Average ms | P95 ms | Maximum ms | Budget avg / P95 / max ms | Result |
|---|---:|---:|---:|---:|---|
| Pull Tabs | 0.883 | 1.361 | 1.510 | 1.5 / 2.5 / 4.0 | Pass |
| Scratch Tickets | 1.301 | 3.578 | 5.374 | 3.0 / 5.0 / 6.0 | Pass |
| Slot | 0.743 | 1.613 | 2.087 | 6.0 / 8.0 / 10.0 | Pass |
| Bar Dice | 0.660 | 0.811 | 0.869 | 1.5 / 3.0 / 4.0 | Pass |
| Craps | 1.262 | 1.401 | 1.407 | 4.5 / 5.5 / 7.0 | Pass |
| Blackjack | 3.708 | 4.043 | 5.568 | 4.5 / 5.5 / 7.0 | Pass |
| Baccarat | 0.827 | 0.973 | 1.137 | 1.25 / 1.75 / 3.0 | Pass |
| Roulette | 1.475 | 1.549 | 1.623 | 2.0 / 3.0 / 4.0 | Pass |
| Back-Room Hold'em | 2.011 | 2.071 | 2.168 | 4.5 / 5.5 / 7.0 | Pass |
| Video Poker | 1.031 | 1.081 | 1.220 | 2.5 / 4.5 / 5.0 | Pass |

All player-frame observations remained within the probe's 16.6 ms low-end frame budget. No current performance slowdown was confirmed.

### Non-bug warnings and anomalies

- **Six seeded environments had no game.** All six selected Back Alley variants whose scenario data intentionally omit a `game_id` (`Cruiser Parked`, `Fence Night`, or `Nothing Moving`). Only `Street Craps` adds an exclusive Craps opportunity. This warning identifies random performance-coverage sparsity, not a generation failure.
- **Slot practice room kind was `boss`, not `casino`.** The launcher deliberately builds its practice room from the Grand Casino archetype, and that production archetype is explicitly `kind: "boss"` in `data/environments/archetypes.json`. The Slot object and preview were present, so the probe warning is a stale expectation.
- **Aggregate suite duration:** 276.188 s versus 220.425 s allowed. Individual functional shards still passed: games content 236.295 s, activation 159.132 s, surfaces 127.342 s, and math/runtime 156.514 s. Because the dedicated runtime probe is green and no player path exceeded budget, this is retained as test-infrastructure telemetry only.
- **Old resolve spikes did not reproduce.** A prior ancestor report showed Blackjack, Baccarat, and Roulette budget misses. The table above is the fresh current-candidate result; filing the old values would be a false positive.

## Determinism, persistence, invalid input, and stuck-state assessment

- Practice fixtures use deterministic per-game seeds and all module contracts accepted their generated state on this candidate.
- Game action authority/activation guards and animation input guards passed. In particular, Bar Dice blocks dice actions during tumble and Coin Pusher rejects actions above its body ceiling.
- Cross-game integration and game-state persistence contracts passed in the functional shards; no game-specific corrupt-load or stuck-state symptom was observed in this assignment.
- No invalid action in the exercised contracts bypassed wager/action authority or left the active surface unable to proceed.
- The fresh custom screenshot probe itself hung during full production-main startup and was terminated after 64 seconds. This is not filed as a game defect: it was a temporary diagnostic script outside shipped/tested paths, and the established production capture plus geometry proof already reproduced the UI issue.

## Evidence index

- Functional summary: `.tmp/playtest_2026-09-20/games_performance/foundation_games/summary.json`
- Functional game report: `.tmp/playtest_2026-09-20/games_performance/foundation_games/foundation_games.json`
- Current performance report: `.tmp/playtest_2026-09-20/games_performance/performance_current.json`
- Production Bar Dice frame A: `.tmp/agent_playtest_24h_ui/0013.png`
- Production Bar Dice frame B: `.tmp/agent_playtest_24h_ui/0014.png`

## Final disposition

**Confirmed:** two concrete Bar Dice overlap manifestations, reported as UIE-022-A and UIE-022-B under the existing UIE-022 family.  
**Performance bugs confirmed:** none.  
**Functional game-rule bugs confirmed in this assignment:** none.  
**Recommended next action:** fix the shared layout occupancy contract first, then add collision assertions for opponent panels and dealer-status widgets so both manifestations are covered by regression tests.
