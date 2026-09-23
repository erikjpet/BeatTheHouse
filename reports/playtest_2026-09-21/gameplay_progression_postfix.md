# Beat the House — Post-Fix Gameplay, Rules, Progression, and Economy Playtest Report

**Test date:** 2026-09-21  
**Audited revision:** `b7c51bf4749422c434e9689b02852084d66ac192` (`b7c51bf4 Remediate code health audit findings`)  
**Comparison revision:** `4384378a` (revision covered by the 2026-09-20 extended playtest report)  
**Test area:** all 11 game modules; action authority; RNG ownership; wagers and payouts; rejection/retry/rollback; services, lenders, debt, items, progression, crew, and scenario state  
**Product fixes made:** none

## Executive summary

This post-fix sweep found five remaining, independently supportable product defect families in gameplay/progression scope. Two runtime-confirmed High severity transaction defects remain in the remediation for BTH-043: paid services reject at valid affordability thresholds, while lender and zero-price service actions can cross a terminal boundary on live state and still apply their rewards. These two findings block closure of the economy/action atomicity work.

Three player-facing defects also remain from the prior text sweep. Shared recovery paths can still call non-Blackjack games “Blackjack”; Grand Casino chip settlements can retain cash-authored text in persistent game surfaces; and several reachable one-action timers still say “1 actions.” The first two are Medium severity; the last is Low.

The fresh Smoke run passed every executable Godot stage. Content/runtime smoke, compilation of all 459 loaded scripts, UI scene compilation, game launchers, the Dave Bus encounter, Roulette audio, and the performance smoke probe all completed successfully. The wrapper's separate repository validation stage timed out after 120 seconds with empty output. A broader all-games attempt was blocked by a Windows path-length/import-copy exception in the sharded test harness before it could execute the requested game regressions. These two harness outcomes are documented separately and are not counted as product bugs.

No new independently supportable rules, payout, wager, or RNG ownership defect was identified in Blackjack, Baccarat, Craps, Slots, Scratch Tickets, Coin Pusher, or Crew Draw Poker. A new continuous-allocation risk was found in render paths for Bar Dice, Video Poker, and Buffalo Slots, but it is deliberately not counted as a bug without comparative profiling.

### Finding summary

| ID | Severity | Confidence | Status | Summary |
| --- | --- | --- | --- | --- |
| GP-PF-001 | P1 / High | Runtime confirmed, 2/2 repetitions with passing boundary controls | New regression | All 12 paid services can reject after being displayed as enabled when bankroll is between the price and one less than twice the price. |
| GP-PF-002 | P1 / High | Runtime confirmed, lender and service variants, 2/2 each with passing no-debt controls | Remediation gap | Lenders and ordinary zero-price services advance a fallible boundary on live state, then apply rewards and report success after that boundary has already failed the run. |
| GP-PF-003 | P2 / Medium | High | Prior bug partially fixed | Shared cancel and delivery-mismatch paths still display Blackjack-specific wording for other games. |
| GP-PF-004 | P2 / Medium | High | Prior bug partially fixed | Grand Casino chip results are corrected only in the transient result; embedded and persisted game summaries can still say cash, bankroll, or dollars. |
| GP-PF-005 | P3 / Low | High | Prior bug partially fixed | Reachable courier, crew-job, and shift timers still render “1 actions.” |

### Release recommendation

Do not mark BTH-043 complete and do not ship the current transaction remediation without addressing GP-PF-001 and GP-PF-002. Their shared risk is loss of trust in the game's economy: actions shown as valid either cannot be purchased or can mutate a run after a terminal boundary. GP-PF-003 and GP-PF-004 should also be fixed before a player-facing release because they misidentify the active game or the account that changed.

## Test method and limitations

The sweep combined:

1. A fresh serialized Godot Smoke run with isolated application data.
2. An attempted sharded gameplay/foundation suite.
3. Direct post-fix source tracing of action authority, transaction candidates, rollback publication, result routing, save state, and presentation consumers.
4. A source matrix for all 11 registered game modules, covering authority/retry roots, RNG ownership, wager entry points, and payout/result application.
5. Direct comparison with the 2026-09-20 defects most relevant to gameplay and progression.
6. Inspection of newly added regression coverage to identify false-positive test designs and untested branches.

The two High findings were first established through deterministic production control flow and were then confirmed with a focused 18-case production-path probe. The probe ran two repetitions of the affected thresholds and terminal boundaries, with underfunded, fully funded, lender no-debt, and free-service no-debt controls. It compared complete `to_save_snapshot()` JSON before and after every action and stored SHA-256 identities. Runtime ownership was then released to the queued reliability tester with zero Godot processes.

### Runtime evidence

Smoke evidence: `.tmp/playtest_2026-09-21/gp/smoke/summary.json`

| Stage | Result | Duration |
| --- | ---: | ---: |
| Godot import | Pass | 19.040 s |
| GDScript load check | Pass; 459 scripts, 0 failures | 29.110 s |
| Foundation smoke content | Pass | 40.008 s |
| Foundation smoke runtime | Pass | 56.567 s |
| UI scene compile | Pass | 86.292 s |
| Game library launchers | Pass | 16.188 s |
| Dave Bus encounter | Pass | 32.737 s |
| Roulette audio audit | Pass | 4.945 s |
| Foundation performance smoke | Pass | 43.645 s |
| Repository validation wrapper | Timeout; no stdout/stderr assertion | 120.097 s |

The attempted all-games suite is recorded at `.tmp/playtest_2026-09-21/gameplay_progression_postfix/foundation_games/summary.json`. Import and the 459-script load check passed. The sharded foundation runner then failed while copying a generated `.ctex` into a deeply nested shard path. The exception named `gas_station_trucker_convoy__gas_station_trucker_convoy_departure_board.png-253456aa4b8335d37fee1e4b2403a00a.ctex`. This occurred in harness project construction, before a game assertion was reported, and is not evidence that the asset is missing from the product build.

Focused transaction evidence: `.tmp/playtest_2026-09-21/gp/transaction_atomicity_probe_result.json`

| Probe family | Cases | Result |
| --- | ---: | --- |
| Paid service below price, bankroll 13 | 2 | Correctly disabled; rejection preserved the complete snapshot |
| Paid service at/near price, bankroll 14, 16, 27 | 6 | Defect reproduced 6/6: option enabled, action rejected, complete snapshot unchanged |
| Paid service passing boundary, bankroll 28 | 2 | Correctly succeeded; price, flag, story, and active status assertions passed |
| Motel Friend lender, no debt/terminal boundary | 4 | Both controls passed; both terminal cases returned success on a failed Heat-100 run, published reward/debt, and changed the snapshot |
| Listen to Jazz, no debt/terminal boundary | 4 | Both controls passed; both terminal cases returned success on a failed run, then cooled Heat to 99 and changed the snapshot |

## Detailed findings

## GP-PF-001 — Paid services double-count their price during transaction revalidation

**Severity:** P1 / High  
**Type:** economy, interaction availability, transaction regression  
**Affected content:** all 12 services with a positive cost  
**Confidence:** Runtime confirmed in both repetitions; deterministic root cause identified

### Player impact

A service is shown as enabled and affordable. Activating it then fails with “The paid service changed before the transaction could commit.” The player's state rolls back, but the service cannot be used near the intended price threshold. Every positive-price service is affected for a predictable range of bankroll values.

The affected definitions and authored prices are:

| Service | Price |
| --- | ---: |
| `cashier_tip` | 4 |
| `house_drink` | 8 |
| `punchline_two_drink_minimum` | 8 |
| `jazz_sax_round` | 8 |
| `jazz_cello_round` | 8 |
| `jazz_drummer_round` | 8 |
| `jazz_band_tip_jar` | 6 |
| `kitty_champagne` | 18 |
| `kitty_burlesque_show` | 28 |
| `riverboat_deck_walk` | 10 |
| `punchline_cover_charge` | 14 |
| `punchline_private_table` | 24 |

For a service costing `C`, an otherwise valid player with starting bankroll `B` is vulnerable whenever `C <= B < 2C`. The precise upper bound varies only if another authored availability condition becomes relevant.

### Deterministic reproduction

1. Enter an environment exposing `punchline_cover_charge`.
2. Ensure its single-use flag is unset, there is no boundary failure, and bankroll is 16.
3. Inspect the hook. It is enabled because the $14 cost is no greater than the $16 bankroll.
4. Activate the hook.
5. Observe rejection with the “paid service changed” message. Bankroll remains 16 and the paid flag remains unset.
6. Repeat at bankroll 14 and 27. Repeat at 13 as the disabled control and at 28 as the successful boundary control.

The focused probe reproduced all three vulnerable sampled bankrolls in both repetitions: 14, 16, and 27 were enabled and then rejected. Each rejection preserved the complete snapshot, confirming that this is an availability/success regression rather than a partial commit. Bankroll 13 was correctly disabled and unchanged; bankroll 28 succeeded with the expected price, flag, story, and active state in both repetitions.

### Expected

Every otherwise valid bankroll at or above 14 can buy the $14 service. Exactly 14 is deducted once, the effect/flag/story record is applied once, and the action boundary advances once.

### Actual

The transaction reserves $14, leaving candidate bankroll 2 for the $16 example. It then asks the candidate whether the same $14 service is affordable. That second affordability check fails and cancels the transaction.

### Root cause

`scripts/core/run_action_service.gd:1004-1006` routes positive-price services through `_commit_money_transaction()`. The helper correctly creates a detached candidate and reserves the quoted price at `run_action_service.gd:1025-1030`. After advancing the boundary, it creates a new service against that candidate and calls `hook_option()` at `run_action_service.gd:1041-1044`.

The ordinary availability predicate at `scripts/core/run_state.gd:10624-10632` compares the full service cost with the already-reduced candidate bankroll. The Jazz-specific predicate has the same behavior at `scripts/core/run_action_service.gd:1970-1973`. The reserved price is therefore counted twice: once when subtracted and again when availability is revalidated.

The new BTH-043 regression does not protect the happy path. `scripts/tests/foundation/fixsweep06_1_regressions.gd:168-175` checks cover-charge bankrolls 20–22, all inside the broken range for a $14 price. `_bth043_assert_atomic()` at lines 216–219 treats any state-clean rejection as a passing outcome. It never requires an affordable no-debt control to succeed. Consequently, all service cases can reject and the test remains green.

### Fix options

1. Treat the price as escrow during post-boundary revalidation. Revalidate location, flags, single-use status, alcohol limits, and quote identity without applying the affordability predicate against post-reservation funds.
2. Add a reservation-aware argument to `service_hook_status()` and the Jazz status helper so the affordability calculation can add the reserved quote back exactly once.
3. Defer the price subtraction until after revalidation, but retain the detached candidate and verify affordability immediately before publication.

Option 1 is the safest fit for the existing transaction design because it preserves the intended “reserve before boundary” invariant while separating price escrow from non-economic availability.

### Required regression

For every positive-price service, test bankrolls `C-1`, `C`, `C+1`, `2C-1`, and `2C`, with no debt and with debt clocks at 0/1/2. Require:

- `C-1` is disabled before activation.
- Every value at or above `C` succeeds unless a deliberately injected boundary invalidates the action.
- Exactly `C` is removed once.
- Service flags, inventory, Heat/drunk/luck deltas, scenario facts, and story rows are committed once.
- Any rejected boundary restores a complete production save snapshot.

## GP-PF-002 — Zero-price hooks can apply rewards after their boundary ends the run

**Severity:** P1 / High  
**Type:** action atomicity, terminal-state integrity, debt/economy  
**Affected families:** five lender definitions; ordinary zero-cost services; related chip-shop, pawn, and portable-ticket flows require the same terminal matrix  
**Confidence:** Runtime confirmed for lender and zero-cost service variants in both repetitions

### Player impact

A lender or service action can advance an action boundary that makes debt come due and fails the run, then still apply cash, debt, flags, Heat relief, inventory, and story changes to the already failed state. The API reports the hook as successful. This can produce contradictory outcomes such as a police-capture failure followed by cooling text, or a failed run gaining a new loan and positive bankroll.

### Deterministic reproduction fixture

1. Start an active run in a valid Motel Friend environment.
2. Set local Heat to 96.
3. Add a separate `street_lender` forced-repayment note with one action remaining and enough balance to remain due.
4. Confirm `motel_friend` is enabled and the player does not already owe that lender.
5. Invoke `use_hook("lender", "motel_friend")`.
6. The action boundary makes the Street Lender note due, adds four Heat, and reaches Heat 100.
7. Inspect run status, response status, bankroll, debt list, flags, scenario facts, and story log after the call.

An equivalent service fixture uses `listen_to_jazz`: the debt boundary raises Heat to terminal before the service's cooling delta and service story are applied.

Both fixtures reproduced in both repetitions:

- Motel Friend returned `ok: true` even though the boundary left `run_status = failed` at Heat 100. The lender reward/debt was published, two story rows were appended, and the complete snapshot differed. Final bankroll was 60 because the forced $20 payment and new $20 loan masked one another in the balance while debt/history still changed.
- Listen to Jazz returned `ok: true` after the same terminal boundary. Forced repayment reduced bankroll from 60 to 40; the already failed run was then cooled from Heat 100 to 99 and received two story rows. The complete snapshot differed.
- The ordinary no-debt Motel Friend and Listen to Jazz controls succeeded and satisfied their cash/debt/story and Heat/story invariants in both repetitions. This rules out an invalid environment or content fixture as the cause.

### Expected

The action is one atomic unit. Either:

- the full lender/service transaction, boundary, and result commit under one defined ordering and the resulting state remains valid; or
- terminal boundary evaluation cancels the action, leaving no lender cash, new debt, trust, service effect, flag, scenario fact, stock change, or success response.

### Actual, confirmed at runtime and explained by production control flow

Lenders receive a transaction price of zero because price is read only for `kind == "service"`. Zero-cost actions bypass the detached transaction helper at `scripts/core/run_action_service.gd:1004-1007`. `_advance_hook_clock()` mutates the live `RunState`. If that boundary returns `ok: true` but terminal evaluation changes the run to failed, execution continues at `run_action_service.gd:1011-1015`: it applies the prebuilt result, publishes the scenario result, and returns `_service_success(result)`.

The forced-repayment path at `scripts/core/run_state.gd:12080-12098` can add four Heat during that boundary. `GameModule.apply_result()` captures that the run was already failed at `scripts/core/game_module.gd:913-922`; its rejection logic only covers a failure newly caused by money settlement. It then continues through debt, item, flag, and story application at `game_module.gd:995-1027`. The caller ignores the returned application result in any case.

### Related exposed branches

The same policy gap exists beyond `use_hook()`:

- Grand Casino chip gift-shop flow advances the live boundary, applies the item, auto-selects it, and marks stock sold at `scripts/core/run_action_service.gd:368-375`.
- Ordinary pawn flow advances the live boundary and then applies its result at `run_action_service.gd:660-664`.
- Portable-ticket surrender snapshots for explicit boundary errors, but an `ok` boundary that becomes terminal is not rejected before cash-out application at `run_action_service.gd:611-653`.

These are not counted as separate bugs without execution because they share one transaction-policy root and may have additional gates. They must be included in the fix's acceptance matrix.

### Root cause

The remediation equates “money transaction” with “positive cash price.” In this game, a zero-price action is still a transaction whenever it couples a fallible time/debt boundary to a reward or irreversible mutation. The detached candidate helper is therefore bypassed precisely for lenders and free services, even though those actions can change the economy substantially.

A second defense is missing in `GameModule.apply_result()`: callers may submit a non-terminal settlement to a run that is already terminal, and callers ignore its structured result. That makes the final result path permissive even after the boundary has invalidated the action.

### Fix options

1. Route every boundary-bearing item, service, and lender action through one detached candidate transaction, including price zero.
2. On the candidate, advance the boundary, evaluate terminal state, revalidate non-economic availability, apply the result, evaluate terminal state again, then publish exactly once.
3. Make `GameModule.apply_result()` reject non-terminal settlement into an already terminal run and require every caller to handle the returned status before reporting success.
4. Apply the same candidate-publication primitive to chip shop, pawn, and portable-ticket flows rather than maintaining independent rollback recipes.

### Required regression

Run lender, zero-cost service, chip gift, pawn, and ticket-cashout cases where the boundary:

- succeeds normally;
- returns an explicit injected error;
- reaches Heat 100;
- reaches bankroll-zero failure when applicable;
- reaches closing-time travel or another terminal transition.

For every rejected case, compare the complete production save snapshot byte-for-byte. For every accepted case, assert that clock, debt, reward, stock, trust, story, and scenario effects occur exactly once and that the response status agrees with the final run status.

## GP-PF-003 — Shared recovery text still identifies other games as Blackjack

**Severity:** P2 / Medium  
**Type:** player-facing text, shared action recovery  
**Affected games:** Baccarat, Roulette, Slots, Video Poker, and potentially any future provider using the shared sealed-action host  
**Confidence:** High

### Player impact

When cancelling a pending non-Blackjack action or failing a shared delivery/action identity check, the game can tell the player that a Blackjack action was cancelled or that a Blackjack replay failed. The message misidentifies the active game during an already confusing recovery state and makes save/retry behavior appear corrupt.

### Reproduction

1. Stage a pending sealed delivery for Baccarat, Roulette, Slot, or Video Poker.
2. Invoke the shared cancel command.
3. Observe `Pending Blackjack action cancelled...` in the player-visible command/status surface.
4. Separately fixture a delivery whose sealed action ID differs from the requested action ID for any non-Blackjack provider.
5. Observe `Blackjack replay failed closed...`.

### Root cause

The broad rejection mapper was correctly centralized at `scripts/ui/sealed_action_host.gd:303-316` and `scripts/ui/player_text.gd:18-56`, but two shared branches bypass it:

- `scripts/ui/sealed_action_host.gd:360-372` hard-codes the Blackjack cancel message. Baccarat, Roulette, Slot, and Video Poker declare retry/cancel contracts at `baccarat.gd:111-112`, `roulette.gd:145-146`, `slot.gd:101-102`, and `video_poker.gd:340-341`.
- `scripts/ui/foundation_main.gd:11320-11324` hard-codes the Blackjack replay mismatch message for a check shared by all authority providers.

Foundation displays the cancel response at `foundation_main.gd:1736-1737`. The existing regression at `scripts/tests/fixsweep06_1_player_text_contract.gd:43-51` tests only the rejection mapper; it never stages a provider's pending delivery and exercises shared cancel/retry/mismatch commands.

### Fix options

- Route cancel, retry, stale delivery, and mismatch output through `PlayerText`, passing a neutral “sealed action” term or the active provider's display name.
- Store a presentation-safe provider label with the pending delivery instead of inferring Blackjack from the first implementation.
- Add a table-driven recovery test for every authority provider, not only unit tests for the copy mapper.

## GP-PF-004 — Grand Casino chip settlements retain cash wording in persistent surfaces

**Severity:** P2 / Medium  
**Type:** payout presentation, currency routing, persistent game state  
**Affected games/surfaces:** Roulette, Bar Dice, Video Poker, Pull Tabs; all Grand Casino chip games should be tested  
**Confidence:** High

### Player impact

A Grand Casino wager correctly changes chips, but the embedded game panel can continue to say `Bankroll`, `CASH`, or show dollar-denominated result copy. The transient toast may be corrected while the durable table/machine result remains wrong, including after animation completion or save/load. This makes it unclear whether cash or chips actually changed.

### Root cause

`scripts/core/run_state.gd:4719-4749` correctly routes proposed bankroll delta into chips for Grand Casino chip games. `scripts/core/game_module.gd:859-884,906-909` then rewrites the top-level returned result. Game modules, however, persist their authored summary before that post-routing rewrite, and embedded views later read the stale game-state copy.

Examples:

- Roulette authors `Bankroll %+d` at `scripts/games/roulette.gd:3675-3685`, stores it at lines 922–939, and projects it at lines 420–423 and 556–559.
- Bar Dice authors cash/pot text at `scripts/games/bar_dice.gd:2967-2978`, persists it at lines 978–1026, projects it at lines 510–514, and has a separate hard-coded settled HUD at lines 3442–3446.
- Video Poker authors `Bankroll %+d` at `scripts/games/video_poker.gd:3166-3173`, persists it at lines 1280–1306, and projects it at lines 671–676. Its renderer labels wager capacity `CASH` at `scripts/games/video_poker_renderer.gd:438-444`.
- Pull Tabs is a Grand Casino chip game (`scripts/core/run_state.gd:126-127`) but labels its balance `CASH` at `scripts/games/pull_tabs.gd:355-376,3652-3653`.

There is also a zero-delta hole. `GameModule` returns before rewriting text when both routed deltas are zero (`game_module.gd:860-863`). Video Poker's ordinary 1x-pay rows can produce a push, yet the authored message remains `Bankroll +0` (`video_poker.gd:208-221,1219-1226,3166-3171`). The current player-text test covers only a nonzero `+12` transient result.

### Fix options

1. Establish authoritative settlement currency before modules author and persist their summary.
2. Store structured settlement fields in game state and format them only at the presentation boundary.
3. If compatibility requires stored English text, update both the returned result and every persisted result copy after routing.
4. Replace generic `CASH`/dollar labels on capacity meters with a context-sensitive account label.

### Required regression

For Roulette, Bar Dice, Video Poker, Pull Tabs, Baccarat, Blackjack, and Craps, capture both the transient toast and the embedded result surface after win, loss, and zero-net/push at the Grand Casino. Repeat after save/load and in any legal cash venue. Force a Video Poker 1x-pay push. Test cash 0/chips 100 and cash 100/chips 0 to make an incorrectly sourced capacity meter obvious.

## GP-PF-005 — Remaining one-action timers use plural grammar

**Severity:** P3 / Low  
**Type:** player-facing text, grammar  
**Confidence:** High

### Player impact

Several progression/status surfaces display “1 actions” at the most urgent timer boundary. The original BTH-058 sites were repaired, but the same family remains reachable in courier, crew-job, and shift-rookie presentation.

### Remaining sites

- `scripts/ui/foundation_main.gd:18863-18873`: `Courier: 1 actions`.
- `scripts/ui/foundation_main.gd:18934-18941`: `Courier target · 1 actions · ...`.
- `scripts/core/crew_run_facade.gd:1655-1659,1673-1679`: expiry may equal one and is always formatted as `actions`.
- `scripts/core/run_state.gd:6939-6944,11957-11962`: shift timer can decrement through one and is always formatted as `actions`.

### Root cause and fix

The new `PlayerText.count_text()` helper was adopted at the originally reported Scratch Tickets, Pull Tabs, Baccarat, career, crew, and action sites, but the migration did not cover all count-bearing presentation consumers. Route every remaining user-visible integer/count noun pair through the shared helper. Add rendered consumer tests at exactly zero, one, two, and a large count; helper-only tests are insufficient.

## Unconfirmed performance watch — Per-frame `RefCounted` wrapper allocation

This item is not included in the defect count.

Commit `b7c51bf4` added `scripts/core/function_options.gd`. Its `*.from()` factories allocate a new `RefCounted` wrapper and store a dictionary. Several calls occur in draw paths:

- Bar Dice: player row at `scripts/games/bar_dice.gd:3139-3144` and one wrapper per visible opponent at lines 3202–3224.
- Multi-hand Video Poker: one wrapper per rendered hand at `scripts/games/video_poker_renderer.gd:280-296`.
- Buffalo Slots: overlay wrapper at `scripts/games/slots/slot_renderer.gd:597-602`.

The allocation source is certain; a player-visible regression is not. Compare HEAD against `65bda04a` or `4384378a` for ten-minute sessions of maximum-opponent Bar Dice, three-play Video Poker flip animation, and Buffalo feature animation. Record frame p50/p95/p99, missed frames, allocations per frame, live `RefCounted` count, and garbage-collection spikes. Count this as a product bug only if repeated profiles show a meaningful hitch or frame-time regression.

## Follow-up adversarial API/lifecycle audit

A second static-only pass reviewed ignored `IoResult` returns, terminal mutation ordering, deferred callbacks after navigation, and save/load generation boundaries. It did not produce another independently supportable defect beyond the five already counted.

### Ignored result-application return watch

`GameModule.apply_result()` now returns a structured result and can return `terminal_settlement_rejected` after changing the bankroll/chip account (`scripts/core/game_module.gd:887-922`). Many callers still discard that result, including the sealed host at `scripts/ui/sealed_action_host.gd:1181-1188`, the direct game host at `scripts/ui/foundation_main.gd:11483-11487`, and multiple item/event/action service paths.

This is part of the confirmed GP-PF-002 mechanism when a live boundary has already made the run terminal: `failed_before_money` suppresses the rejection, later deltas are applied, and the hook caller reports success. It was not counted again as a separate API bug. Outside that confirmed path, source inspection did not establish a distinct reachable game action that both receives a rejected `apply_result()` status and escapes existing all-in deferral, receipt consumption, candidate terminal evaluation, or rollback. The fixing team should still make result handling mandatory because a fallible function whose status is routinely ignored invites recurrence.

### Deferred navigation callbacks

The highest-risk long callback chain—the embedded game refresh—carries generation, run, game, environment, result, canvas, and surface-session identities through every awaited frame (`scripts/ui/foundation_main.gd:9794-9919,11597-11662`). Chunked game exit similarly captures run/game identities and rechecks after every yield (`foundation_main.gd:1130-1166`). These protections are credible.

Scenario-sequence and event-choice activation use short `call_deferred()` hops without equivalent identity tokens (`foundation_main.gd:13201-13221,13878-13896`). A second scenario/event action is locked while pending, but the flags are not lifecycle generations. No normal player input route was proven to replace the run between scheduling and same-idle execution, so this remains a validation target rather than a counted defect. A future regression should schedule each callback, force screen/run replacement before flush, and require a no-op against the replacement run.

### Save/load boundaries

`SaveService` serializes asynchronous generations, waits before synchronous save/load/delete, validates the temporary and installed generations, and retains a loadable backup through `DurableStore` (`scripts/core/save_service.gd:44-142,188-224`; `scripts/core/durable_store.gd:17-81`). Foundation coalesces dirty generations and retries failed asynchronous saves (`foundation_main.gd:5712-5845`). No additional source-supported save corruption or stale-generation overwrite was found. The repository-validation and long-path shard failures observed in this sweep are harness concerns, not evidence against these production save boundaries.

## Prior defect disposition

| Prior finding | Post-fix disposition | Evidence and remaining work |
| --- | --- | --- |
| GP-01 / BTH-027 — Corner Store tutorial loses Coffee action focus | Likely fixed in source | `foundation_main.gd:15635-15678` refreshes the coach before reconciling focus, and `tutorial_corner_shop_order_check.gd:81-99` asserts visible selected info and Coffee action geometry. Run wrong-order mouse/controller/large-text/save-load paths before final closure. |
| GP-02 — scenario integer queue corruption | Rescinded as originally reported; production transport protected | `run_save_codec.gd:215-227,284-303,402-419` preserves exact scenario integers. Raw JSON supplied directly to `RunState.from_dict()` remains outside production SaveService transport. |
| EXT-GAME-001 / BTH-042 — rejected Blackjack result leaks story row and retry duplicates | Likely fixed; high static confidence | `sealed_action_host.gd:583-606` publishes pending state then re-forks a transaction-owned candidate. `run_state.gd:526-534,11354-11382` detaches append-only histories. `game06_2_depth_contract.gd:753-792` now checks rejection equality, retry-vs-clean full snapshot, and exactly one final story row. Packaged runtime confirmation remains. |
| XPE-01 / BTH-043 — failed item/service boundary partially commits | Original cash-item symptom addressed; closure blocked | Positive-price item and service paths now use detached candidates, but GP-PF-001 breaks affordable service success and GP-PF-002 leaves zero-price/lender branches non-atomic. |
| EXT-PERF-001 / BTH-044 — mutable producer context causes semantic inventory drift | Likely fixed in source | `run_state.gd:2737-2750,2826-2827` separates sealed producer context from mutable live projection. Re-run original Numbers/Silas/delivery seed through revisit and save/load. |
| EXT-PERF-002 / BTH-045 — Coin Pusher compact rollback has incomplete fallback | Fix present; focused runtime not completed in this sweep | `fixsweep06_1_regressions.gd` verifies the complete fallback structure. All-games execution was blocked by harness path-copy failure. |
| EXT-TXT-001 / BTH-055 — Blackjack wording leaks to other games | Partially fixed; still open as GP-PF-003 | Rejection mapper is neutral, shared cancel/mismatch branches are not. |
| EXT-TXT-002 / BTH-056 — cash text shown for chip settlement | Partially fixed; still open as GP-PF-004 | Transient top-level result is rewritten; persisted/embedded summaries and zero-net paths remain wrong. |
| EXT-TXT-003 / BTH-057 — 24-hour outcome time | Fixed in source | Outcome/report/HUD share `PlayerText.format_game_clock()` with midnight, noon, 13:00, and rollover fixtures. |
| EXT-TXT-004 / BTH-058 — pluralization and sentence joining | Partially fixed; still open as GP-PF-005 | Originally cited game sites are fixed; courier/job/shift consumers remain. |

## Eleven-game coverage matrix

| Module | Authority / rollback reviewed | RNG / wager / payout reviewed | Result |
| --- | --- | --- | --- |
| Blackjack | Sealed contract, resolve, pending publication, detached candidate, rejection/retry | `RngStream`, wager entry, receipt-gated application | BTH-042 root appears fixed; no new rules defect found |
| Baccarat | Sealed contract and retry/cancel | Context resolve, wager and payout | GP-PF-003 applies; natural-hand sentence bug fixed |
| Roulette | Sealed contract and retry/cancel | Wager, result summary, routed payout | GP-PF-003 and GP-PF-004 apply |
| Craps | Direct resolve and wager path | Injected `RngStream`, Street cash vs casino chips | No new independently supportable defect found |
| Slots (Pinball/Buffalo) | Sealed contract, compact rollback, retry/cancel | Resolve/wager, nested option objects | GP-PF-003 applies; allocation watch unconfirmed |
| Video Poker | Sealed contract, retry/cancel | Multi-hand resolve, wager, 1x push rows | GP-PF-003 and GP-PF-004 apply; allocation watch unconfirmed |
| Bar Dice | Sealed contract and resolve | Wager, pot/rake payout, stored result summary | GP-PF-004 applies; allocation watch unconfirmed |
| Scratch Tickets | Direct resolve | Injected/forked `RngStream`, wager/payout | Original grammar site fixed; no new rules defect found |
| Pull Tabs | Direct resolve | Wager/payout and Grand Casino currency classification | GP-PF-004 applies; original plural site fixed |
| Coin Pusher | Compact rollback | Wager/resolve and solver RNG ownership | No new independently supportable defect found |
| Crew Draw Poker | Direct resolve | Wager/payout and injected RNG | No new independently supportable defect found |

A repository-wide search found no direct `randf()`, `randi()`, or `randomize()` calls in the 11 game modules. Random decisions are owned by injected/forked `RngStream` instances. This is a source ownership result, not a substitute for deterministic replay of every branch.

## Cross-system acceptance matrix for the fixing team

The following matrix is recommended because the remaining faults cross game, economy, terminal, save, and presentation boundaries.

| Area | Controls | Failure boundaries | Required invariant |
| --- | --- | --- | --- |
| Paid services | Every price at `C-1`, `C`, `C+1`, `2C-1`, `2C` | Explicit boundary rejection; debt clocks 0/1/2; Heat 100 | Valid affordable controls succeed; rejection restores full snapshot |
| Lenders/free services | Every lender and all six zero-price services | Heat terminal, bankroll terminal, closing terminal, injected error | Boundary and reward publish once or not at all; response matches state |
| Items/chip shop/pawn/tickets | Cash item, chip gift, pawn, portable ticket | Same terminal/error matrix | Price/reward/stock/story remain atomic |
| Sealed games | All authority providers | Reject, cancel, retry, stale delivery, action mismatch | Correct/neutral provider name; no leaked history; retry equals clean control |
| Casino currency | Seven Grand Casino chip-game IDs | Win, loss, push, save/load re-entry | Toast, embedded panel, balance meter, and persisted summary identify chips |
| Save/reload | Transaction before/after boundary and pending delivery | Reload at each checkpoint | Exact state identity and deterministic continuation |
| RNG | Same seed/action stream across all 11 games | Retry, reject, save/load, animation interruption | No extra draw consumption; result and receipt parity |
| Progression timers | Courier, crew job, shift rookie | 0, 1, 2, 101 remaining | Correct singular/plural and no timer underflow |

## Evidence index

- Smoke summary: `.tmp/playtest_2026-09-21/gp/smoke/summary.json`
- Smoke stage logs: `.tmp/playtest_2026-09-21/gp/smoke/`
- Focused transaction probe source: `.tmp/playtest_2026-09-21/gp/transaction_atomicity_probe.gd`
- Focused transaction probe results: `.tmp/playtest_2026-09-21/gp/transaction_atomicity_probe_result.json`
- Attempted all-games summary: `.tmp/playtest_2026-09-21/gameplay_progression_postfix/foundation_games/summary.json`
- Gameplay static audit: `.tmp/playtest_2026-09-21/game_static/static_postfix_audit.md`
- Progression/economy static audit: `.tmp/playtest_2026-09-21/progression_static/postfix_static_audit.md`
- Prior extended report: `reports/playtest_2026-09-20/Beat_the_House_Extended_Playtest_Bug_Report_2026-09-20.md`

## Final assessment

The post-fix build is healthier than the 2026-09-20 revision: it imports, loads, compiles, launches the smoke game surfaces, passes runtime smoke, and shows credible source fixes for the Blackjack history leak, tutorial focus ordering, scenario integer transport, semantic producer-context drift, 12-hour clocks, and several text defects.

It is not yet transaction-safe. Runtime confirmation shows that the paid-service happy path is broken for common bankroll values and that reward-bearing zero-price actions remain outside the atomic transaction model. Those are release-blocking defects in ordinary progression/economy play. The most effective remediation is one shared detached action transaction for every fallible boundary, independent of whether the quoted price is zero, followed by structured presentation derived from the final routed settlement rather than pre-routing English strings.
