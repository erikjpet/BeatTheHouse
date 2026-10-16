# Extensive playtest bug report — 2026-10-16

## Executive summary

The original playtest found release-blocking layout and validation failures plus several gameplay and performance defects. **All eleven tracked findings in this report are now resolved in the current working tree.** The complete release validator, all-content census, all 55 scenario-layout cases, game contracts, migration checks, and no-pointer animation gate pass after the fixes.

The broad game systems remain stable. Every individual gambling game completed its production-path checks, the 180-minute simulated soak showed no broad memory leak, autonomous animation remained live without pointer input, terminal runs did not incorrectly resume, and Slot autoplay stayed inside its frame budget with no visual snapshot fallbacks.

This report deliberately separates unique gameplay defects from cascaded assertions and stale test artifacts. For example, 120 scenario-finalization failures reduce to eight placement defects, while 140 Bar Dice contract assertions reduce to one stale test adapter; the production Bar Dice game still settles correctly.

## Resolution update

| Finding | Status | Fix and verification |
| --- | --- | --- |
| BTH-PT-001 | Resolved | Re-authored the eight blocking scenario layouts and their small-screen routes. All 55 scenario-layout cases pass, including Delta Queen small-screen reachability. |
| BTH-PT-002 | Resolved | Repositioned the Grand Casino and Kitty Cat Lounge base objects. The complete content census and derived UI scene checks report no remaining overlap. |
| BTH-PT-003 | Resolved | Re-authored the Pawn Shop shelf rows so spawned fixtures retain separate interaction rectangles. |
| BTH-PT-004 | Resolved | Corrected the Grand Casino cage placement/capacity path. Bishop's primary and fallback recruitment contracts pass. |
| BTH-PT-005 | Resolved | Restored routed-actor midpoint draw and hit coverage on the public canvas path. |
| BTH-PT-006 | Resolved | Reordered the Back Alley route anchors into a monotonic lane. The grounding contract passes. |
| BTH-PT-007 | Resolved | Reused a bounded, shallow detached Bar Dice candidate for trusted settlement instead of repeatedly deep-copying the full late-run history. The repeated probe measured 11.429 ms average and 11.897 ms p95/max against the 12.000 ms budget; animation scheduling remains live. |
| BTH-PT-008 | Resolved | Synchronized slot capacities, reviewed migration recipes, supported placement fields, and generated layout/ledger artifacts. Fresh conversion, byte-idempotence, both reviewed-ledger checks, and the full project validator pass. |
| BTH-PT-009 | Resolved | Updated every isolated Bar Dice adapter to forward the prepared claim used by production. The full Bar Dice contract passes, including 3,000 tiered rounds, actions, and save/load. |
| BTH-PT-010 | Resolved | Reviewed the intended serialization changes and refreshed only the affected deterministic baselines. Repeated-reprieve, scenario uniqueness (1,485 pairs), and crew snapshot checks pass. |
| BTH-PT-011 | Resolved | Changed performance seeds and assertions to require generated game-bearing environments and a casino Slot preview. The performance matrix now fails closed if it falls back to practice-only coverage and passes with zero warnings. |

Final independent verification on 2026-10-16: the repository validator passed in 307.9 seconds; the full games/content census passed in 298.7 seconds with zero failures; and the required animation-liveness-without-pointer check passed.

## Test basis and limitations

- Tested revision: `fade41b46cf0cb044c393b64db8ae8ca1a7d625b` (`fade41b4 Save manual environment slot placements`).
- The working tree already contained uncommitted changes. Results therefore describe the user's current working repository, not a clean checkout of `main`.
- This was a multi-hour, headless, deterministic production-flow playtest. It exercised real scenes, generation, travel, scenario finalization, saves, game hosts, animation cadence, and long-run state. It does not replace subjective visual review on every supported display and input device.
- 514 GDScript files parsed and loaded with zero parse/load failures.
- All 65 standalone checks were executed after the umbrella runner reached its one-hour orchestration limit.
- All 24 unified foundation groups ran: 19 passed; the five failed groups are explained below.
- Eleven game-specific suites ran: ten passed directly; Bar Dice's isolated suite was invalidated by a stale adapter, then verified against the production host.
- Release audits included 10,000 Slot spins, 100 tutorial seeds, 48 pinball seeds, eight scenario-finalization seed groups, and terminal-run resume coverage.
- A 180-minute simulated soak exercised 504 actions, 160 revisits, 21 save/load cycles, Slot autoplay, and pinball-cache stress.

## Confirmed player-facing defects

### BTH-PT-001 — Scenario objects block mandatory room access

- **Severity:** P1 / release blocker
- **Confidence:** Confirmed across the full environment contracts and eight independent scenario seed groups.
- **Impact:** Affected rooms can reject arrival/finalization, make required interactions unreachable, and break downstream delivery, crew, and heist flows. This is the source of many apparently unrelated failures.
- **Affected layouts:**

| Scenario | Blocking object | Observed impact |
| --- | --- | --- |
| `corner_store_delivery_day` | `scenario::sealed_pallet` | Blocks the mandatory lane across arrival/outcome/cleanup branches. |
| `delta_queen_fog_delay` | Expanded fog-delay layout | No reachable small-screen route; `safe_exit` is unreachable. |
| `gas_station_tour_bus_stop` | Restroom queue | Blocks the mandatory lane. |
| `grand_casino_audit_night` | Audit barrier | Blocks arrival and both clean-route/showdown finalization. |
| `kitty_cat_lounge_buyout` | Buyout ropes | Blocks arrival and Velvet's primary recruitment path. |
| `kitty_cat_lounge_slow_night` | Closed-section ropes | Blocks arrival and Velvet's fallback recruitment path. |
| `motel_stakeout` | Laundry trolley | Blocks arrival and multi-stop delivery progression. |
| `motel_wedding_overflow` | Garment rack | Blocks arrival, revisit, and next-cycle room entry. |

- **Reproduction:** Generate each named scenario, perform the normal room-arrival/finalization step at 1280×720 and the expanded small-screen layout, then validate reachability from the player access lane. The listed object intersects the mandatory route or leaves the required interaction unreachable.
- **Likely ownership:** Scenario-authored rectangles/anchors in environment placement data, plus small-screen expansion rules for Delta Queen.

### BTH-PT-002 — Base environment objects overlap and create ambiguous visuals/hit targets

- **Severity:** P2
- **Confidence:** Confirmed by production-order layout checks.
- **Impact:** Objects visually cover each other and can compete for selection. These are base-layout collisions, not the intentionally permitted overlap between scenario objects and occupied base slots.
- **Grand Casino:** The host desk overlaps both `staff:grand_casino_host` and `event:the_house_calls`.
- **Kitty Cat Lounge:** Fifteen overlaps involve Dot, merchant/host, the Grand Casino invitation, rowdy regular, house drink, Jackpot Magnet, Bar Dice, Video Poker, Leave, and the side door. Particularly risky pairs are Bar Dice/Video Poker and Leave/side door because both sides are interactive.
- **Reproduction:** Generate the affected base environment in production order and compare the final interaction rectangles rather than only checking slot ownership.

### BTH-PT-003 — Sal's Pawn Shop shelf fixtures overlap

- **Severity:** P2
- **Confidence:** Confirmed by the fully derived run-menu/game-flow scene check.
- **Impact:** Seven shelf pairs intersect, which can make items look merged and produce ambiguous selection regions in the Pawn Shop/meta-home flow.
- **Evidence:** Intersections were reported for shelf pairs 0/1, 0/2, 0/3, 1/2, 1/3, 5/4, and 2/3; the largest measured intersection was about 792 px².
- **Reproduction:** Open the Pawn Shop from the production run-menu flow and evaluate the authored `meta_sal_shelf` rectangles after layout scaling.

### BTH-PT-004 — Bishop's fallback recruitment placement is unavailable

- **Severity:** P2
- **Confidence:** Confirmed production-path contract failure; the failing path currently returns no useful installation diagnostic.
- **Impact:** The configured fallback meeting at `grand_casino_cage` is not exposed, so Bishop can lose a documented recruitment route even when the primary Grand Casino route exists.
- **Reproduction:** Start the marked recruitment fixture, enter Grand Casino, enter `grand_casino_cage`, finalize base semantics, and query Bishop's generated fallback placement. Room generation completes far enough to return an empty error array, but the fallback is absent.
- **Follow-up:** Improve the failed-finalization diagnostic while fixing the placement; the empty error array currently obscures the exact rejected semantic.

### BTH-PT-005 — Routed actor is not drawn/hittable at the authored-lane midpoint

- **Severity:** P2
- **Confidence:** Confirmed by the public, non-reduced-motion canvas contract.
- **Impact:** An actor routed through a valid authored lane can be visually absent or unselectable at its expected midpoint.
- **Reproduction:** Use the normal public canvas, non-reduced motion, advance the routed actor to the authored-lane midpoint, then compare draw coverage and hit testing at that point. Both expected signals were absent.

### BTH-PT-006 — Back Alley actor route backtracks at both ends

- **Severity:** P2
- **Confidence:** Confirmed by the grounding contract.
- **Impact:** Movement visibly doubles back instead of following a monotonic authored-lane slice.
- **Observed route:** `(350,308) → (350,318) → (450,318) → (580,318) → (580,307)`.
- **Reproduction:** Generate the Back Alley actor route and inspect the ordered path. The first and last vertical segments reverse the lane direction.

### BTH-PT-007 — Late-run Bar Dice settlement exceeds the frame-time budget

- **Severity:** P2 performance
- **Confidence:** Confirmed on the real Bar Dice scene and production sealed-action host.
- **Impact:** Late-run Bar Dice actions can produce a noticeable hitch as histories grow.
- **Measured state:** story history 240, environment history 256, heat history 480.
- **Measured result:** 12 successful settlements; average 12.204 ms, p95/max 14.170 ms against a 12.000 ms budget.
- **Important distinction:** The core Bar Dice practice resolver remained fast (0.638 ms average, 0.696 ms p95). The regression is in the full production settlement/host path, not dice calculation or autonomous redraw.
- **Fix constraint:** Preserve no-input animation scheduling and visual cadence; optimize the work performed during settlement.

## Content pipeline and release-gate defects

### BTH-PT-008 — Environment placement data no longer agrees with its validator/schema

- **Severity:** P1 release blocker; not independently confirmed as a runtime player defect
- **Impact:** The repository validator and reviewed-recipe regeneration fail, so placement changes cannot be reliably certified or regenerated.
- **Observed drift:**

  - Back Alley reports an unexpected `behind_counter_person` capacity.
  - Small Underground Casino back room reports an unexpected `behind_counter_person` capacity.
  - Grand Casino reports two `behind_counter_person` slots where one is expected.
  - Shared event-person capacity expected by the reviewed conversion is missing.
  - The generated environment scenario-layout breakdown is stale or absent.
  - `bar/bar_payday_rush` uses `slot_layers`, which the validator currently rejects as unsupported.

- **Resolution requirement:** Decide whether the manual placement format or the validator is authoritative, update the other side, regenerate the breakdown, and rerun the fresh-conversion/idempotence proof.

### BTH-PT-009 — Bar Dice's isolated contract adapter is stale

- **Severity:** P1 test/release-gate integrity; not a production gameplay failure
- **Impact:** The foundation suite emits 140 misleading failures, hiding real regressions and preventing a trustworthy release signal.
- **Cause:** The isolated helper forwards `_sealed_action_host_delivery` but drops the prepared in-place candidate introduced by the sealed-action host optimization. Production supplies both values.
- **Evidence:** The isolated suite failed resolution/outcome/cheat/press-offer assertions, while the dedicated production-scene probe completed all 12 settlements successfully. Only the late-run timing budget failed.
- **Resolution requirement:** Update the helper to mirror the production host interface, then reassess any remaining Bar Dice assertions.

### BTH-PT-010 — Deterministic golden snapshots are stale

- **Severity:** P2 test maintenance
- **Impact:** Valid structural checks are obscured by checksum noise.
- **Observed drift:** Repeated-reprieve Blackjack fixture hash, scenario uniqueness/memo baseline, and crew-ignoring RunState/current/world snapshot byte counts and hashes.
- **Evidence of likely baseline drift:** Scenario uniqueness still produced the expected 1,485 pairs with no semantic failures/warnings; crew deltas were consistent byte growth across both seeds and boundaries.
- **Resolution requirement:** Review the serialized field additions, then deliberately refresh accepted goldens only after confirming the new fields are intended.

### BTH-PT-011 — Performance seed setup falls back to practice fixtures

- **Severity:** P2 test coverage
- **Impact:** The main performance matrix can pass without measuring generated in-run game rooms.
- **Observed behavior:** All eight `EXTENSIVE-PLAYTEST-20261016-*` seeds generated no games, so the probe used practice fixtures. Slot preview also reported a boss room kind rather than a casino-like room.
- **Resolution requirement:** Use seeds/route setup guaranteed to reach real game-bearing environments and fail the probe if that coverage is not achieved.

## Retest outcomes after the P1 layout fix

- **Crew Heist Plan A exit derivation:** Passed after the Grand Casino route/layout repair. No independent heist-logic defect remained.
- **World-node scenario revisit equality:** Passed after the Motel route/layout repair. The mismatch was cascading from the blocked arrival.

## Lower-priority diagnostics

- The dedicated Video Poker draw probe teardown now drains deferred refresh work and frees its instance cleanly. It passes without resumed-coroutine, ObjectDB-leak, or retained-resource warnings.
- Two incomplete UI inheritance-layer scripts fail when launched directly because their descendant fixture method is not present. The fully derived scene is the valid target; do not count the two base-script failures as player bugs.
- The earlier full umbrella run was stopped by the external one-hour command budget, not by an internal test failure or deadlock. The runner's existing suite/standalone selectors provided the continuation path; all remaining 15 checks passed directly. The current release validator also completes cleanly in 307.9 seconds.

## Systems that passed

- Blackjack, Roulette, Baccarat, Craps, Video Poker, Crew Poker, Pull Tabs, Scratch Tickets, Slots, Coin Pusher, and production-host Bar Dice all completed functional game resolution.
- Blackjack's production count-host probe completed 48 claims in 41.86 ms against a 250 ms budget. Its idle canvas produced 13 autonomous redraws, above the liveness floor of eight.
- Foreground Slot autoplay passed: 20 unique animation IDs, 84 redraws, zero full-snapshot fallbacks, 2.788 ms draw p95, 10.782 ms next-frame p95, and 15.791 ms resolve p95.
- The 10,000-spin Slot audit passed.
- Coin Pusher's 300-body native solver stayed under budget at 3.621 ms p95.
- All 15 animated surfaces maintained autonomous redraw without mouse input or selection changes.
- Terminal-run resume passed: a concluded run was not offered as a resumable in-progress run.
- Profile-history load and run-history transactions passed.
- The 180-minute soak completed with zero orphan nodes, one-object growth, zero node growth, and only 31,620 bytes of retained-memory growth; memory plateaued rather than trending upward.
- Extreme-state recovery passed with 2,000 collection items and 10,000 corrupt run entries; history was safely compacted to bounded sizes.
- Tutorial guardrail recovery, 100 tutorial seeds, 48 pinball seeds, Roulette rules/audio, Dave's bus encounter, guest/legend action hosts, library launchers, and whale safe-exit checks passed.

## Evidence index

Raw logs and machine-readable summaries are under `.tmp/playtest_2026-10-16/`:

- `full/` — full-suite orchestration, parser, validator, and standalone logs.
- `foundation_all/foundation_all.json` — all 24 unified foundation groups and assertion text.
- `game_suites/summary.json` — per-game execution result and duration.
- `performance/foundation_performance.json` — cross-game timing and redraw matrix.
- `performance/dedicated/` — foreground Slot, Blackjack, Video Poker, profile/history, and late-run Bar Dice probes.
- `performance/soak/` — 180-minute soak and extreme-state reports.
- `release_audits/` — terminal resume, tutorial, pinball, Slot, Roulette, grounding, and multi-seed finalization.
- `ui_liveness/` — launcher, scene-flow, and no-pointer animation-liveness checks.

## Completed fix order

1. Fixed the eight mandatory-route blockers and passed environment/readability plus multi-seed finalization.
2. Re-ran Crew Heist Plan A and revisit equality, confirming both earlier failures were cascades.
3. Reconciled placement data with the validator/schema and regenerated the reviewed layout and migration artifacts.
4. Fixed the base/Pawn Shop overlaps, Bishop fallback placement, routed-actor coverage, and Back Alley route ordering.
5. Optimized the full Bar Dice production settlement path while preserving autonomous animation.
6. Repaired the Bar Dice adapters, generated-game performance coverage, deterministic goldens, and Video Poker probe teardown.
