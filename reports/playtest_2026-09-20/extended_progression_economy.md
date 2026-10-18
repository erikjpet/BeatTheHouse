# Extended Progression, Campaign, and Economy Playtest Report

Date: 2026-09-20  
Build: `0.5.1`, Godot `4.6.stable`, commit `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`  
Scope owner: extended progression/economy worker  
Disposition: investigation and documentation only; no product code or content was changed

## Executive summary

This extended pass confirmed **one new high-severity product defect**:

| ID | Severity | Area | Summary | Reproduction confidence |
|---|---:|---|---|---:|
| XPE-01 | P1 / High | Purchases, paid services, debt deadlines | A debt payment can occur after an affordability quote but before the quoted action cost is applied. The action still returns success and grants its item/flag even though the player can no longer afford it, then ends the run at $0. | 4/4 affected cases across two fixed seeds, plus 4/4 matched controls |

The defect was reproduced through production `RunState`, `RunActionService`, debt-clock, and result-application APIs. It is not a direct-state fixture artifact. Both affected action families were repeated with two seeds and compared against otherwise identical no-debt controls.

Broad negative coverage was also completed. The current catalog contains 55 scenarios across all 12 environment archetypes, 89 items, 18 services, 5 lenders, 13 Crew jobs, and 12 authored travel routes. A fresh scenario-sequence audit passed all 55 scenarios and all 1,485 pairwise comparisons, including 11 hostile fixture rejections, 55 dossiers, and 5 package files. One independent finalization family then completed all 55 scenario finalizations before runtime ownership was handed to the performance worker.

The targeted Systems matrix passed 23 of 26 selected contracts. The 28 assertions in the other three contracts were investigated and excluded: 15 are golden-byte drift against a baseline being edited in the shared worktree, 2 are the already documented pre-tree-ready closing-time fixture failure, and 11 are stale Jazz assertions or UI-placement duplicates. None produced a separately eligible progression defect.

## Test scope and method

The pass covered the following systems through catalog inspection, targeted production-API probes, existing contracts, seeded finalization, and root-cause tracing:

- Campaign start, tutorial handoff, world map, authored travel routes, repeated visit state, closing hours, and time advancement.
- All 55 authored scenarios and their sequence packages, hostile validation fixtures, semantic dossiers, layout/finalization paths, and route preservation.
- Crew recruitment, jobs, expiry, plays, heist state, trust, and character chains.
- Lenders, debt creation, deadlines, defaults, forced repayment, pawn interactions, and recovery pressure.
- Shop offers, inventory, active items, item effects, item builds, repair/sale paths, paid services, Jazz services, and meta-home inventory boundaries.
- Economy pressure, bankroll-zero terminal handling, Heat, recovery/loss pressure, run reports, Grand Casino objective state, and ending-related flags.
- SaveService round-trip behavior and the distinction between production save encoding and raw-JSON fixtures.

Candidate policy was strict: a failure was retained only after a second reproduction and a production-path root cause. Assertions caused by stale expected hashes, content currently being edited by another worker, pre-ready UI lifecycle calls, direct-state mutation, or missing event authorization were recorded as harness findings rather than game bugs.

Primary evidence is stored under `.tmp/playtest_extended/progression_economy/`:

- `progression_boundary_probe.json` — two-seed XPE-01 reproduction and matched controls.
- `progression_boundary_probe.gd` — minimal production-API reproduction driver.
- `progression_foundation.json` — 26-contract Systems matrix with per-check timing and failures.
- `jazz_isolated.json` — isolated confirmation used to classify the stale Jazz assertions.
- `scenario_sequence_audit.json` and `scenario_sequence_audit.md` — fresh 55-scenario audit.
- `scenario_base_seedsweep_a.json` — completed independent scenario-finalization family artifact.

## XPE-01 — Debt boundary invalidates affordability, but purchase/service still commits

**Severity:** P1 / High  
**Frequency:** 4/4 affected cases: 2/2 item purchases and 2/2 paid services; matched no-debt controls passed 4/4  
**Player impact:** unexpected run loss, inconsistent transaction results, and receipt of an item/service that was not fully paid for  
**Affected surfaces:** cash item offers and action-priced service/lender hooks that use the ordinary one-action clock boundary

### Item-purchase reproduction

1. Begin an active run with $14.
2. Make a $12 Ledger Pencil offer available.
3. Add a $30 Street Lender debt with one action remaining and the `forced_repayment` default consequence.
4. Confirm that the offer is quoted affordable at $12.
5. Buy the Pencil.

### Item-purchase expected result

The operation should be atomic. Either the $12 purchase is reserved/committed before the debt clock resolves, or the post-boundary balance should be revalidated and the purchase should be rejected or rolled back. The player must not receive a $12 item after only $10 remains available.

### Item-purchase actual result

- The API returns `ok: true`.
- The action boundary forces a $4 debt payment first, reducing bankroll from $14 to $10 and debt balance from $30 to $26.
- The previously built purchase result then applies a $12 delta.
- Bankroll reaches a negative intermediate value and is clamped to $0 by terminal handling.
- The run ends with `run_status: failed` and `failure_reason: bankroll_zero`.
- The Ledger Pencil is nevertheless added to inventory and the offer is removed.
- Debt remains overdue at $26 and local Heat rises by 4.

Both fixed seeds produced the same state. In each matched no-debt control, the purchase completed normally and the run remained active at $2.

### Paid-service reproduction

1. Begin an active run with $16 in the Punchline/underground venue context.
2. Expose the $14 `punchline_cover_charge` service.
3. Add the same $30 Street Lender debt with one action remaining and forced repayment.
4. Confirm that the service is enabled and quoted at $14.
5. Buy the cover service.

### Paid-service expected result

The service should either commit against the quoted $16 before the debt payment or fail atomically after the balance changes. Its single-use effect must not be granted when the transaction cannot be funded.

### Paid-service actual result

- The API returns `ok: true`.
- The debt boundary takes $5 first, reducing bankroll from $16 to $11 and debt balance from $30 to $25.
- The $14 service result then applies, causing bankroll-zero failure and clamping to $0.
- The single-use `punchline_headliner_cover_paid` flag is still granted.
- Debt remains overdue at $25. Heat ends at 2: the default adds 4 and the service effect removes 2.

Both fixed seeds reproduced the same result. Both no-debt controls completed normally and remained active at $2 with the service flag set.

### Root cause

The item and hook paths validate affordability against the pre-boundary balance, construct an authoritative-looking result, advance the action boundary, and only then apply the result:

- `RunActionService.buy_item_offer()` checks `run_state.bankroll < price` at `scripts/core/run_action_service.gd:237`, builds the purchase result at line 248, advances the environment at line 249, and calls `GameModule.apply_result()` at line 252.
- `RunActionService.use_hook()` builds the result at line 981, advances the hook clock at line 1001, and applies the result at line 1005.
- The action boundary reaches `_advance_global_boundary_finish()` and `_advance_debt_clocks()` at `scripts/core/run_state.gd:14111-14113`.
- A forced-repayment default deducts one third of the current bankroll at `scripts/core/run_state.gd:14630-14648`.
- `GameModule.apply_result()` then applies the stale cash delta at `scripts/core/game_module.gd:871-873`. It does not re-check affordability or stop after `change_bankroll()` marks the run failed. It continues to add inventory and flags at lines 952-964.

The result is a split transaction with three incompatible snapshots: quote against the old balance, debt payment against the boundary balance, and purchase/service application against the already reduced balance. The special Jazz `show_drummer_glasses` hook uses an apply-first snapshot-and-rollback path at `run_action_service.gd:985-1000`, demonstrating that the codebase already has a safer atomic pattern, but ordinary cash hooks do not use it.

The defect is deterministic and does not depend on RNG; the two seeds establish that it is not tied to a particular generated environment.

### Likely affected scope

Confirmed scope is limited to ordinary cash item offers and paid hooks that advance a one-action boundary before applying their result. Any boundary mutation that reduces spendable cash can trigger the ordering fault; forced repayment is the directly reproduced mechanism.

Source inspection shows a similar boundary-before-result pattern in some hosted gameplay actions, but those paths have additional wager-funding and authority rules. They were not independently reproduced in this pass and are not claimed as confirmed affected surfaces. Travel advances game-clock minutes rather than the debt action clock in the tested path, so travel is also not included in the confirmed scope.

### Fix options

1. Treat quote, cost, boundary, and reward as one transaction. Snapshot the run and environment, reserve or apply the price, advance the boundary, and restore everything if the boundary fails.
2. Alternatively, advance the boundary first and then recompute availability/affordability from live state before applying the result. If the quote is invalidated, return a clear cancellation and leave offers, inventory, flags, and story state unchanged.
3. Add a transaction helper shared by item offers and hook services so the two paths cannot drift again.
4. Stop `GameModule.apply_result()` from applying non-cash rewards after a cash delta has transitioned the run into failure, unless the result explicitly declares terminal settlement semantics.
5. Add a regression matrix for bankroll values immediately below, equal to, and above `price + forced_payment`, with debt clocks at 0, 1, and 2 actions. Assert API status, final bankroll, run status, debt balance, offer consumption, inventory, flags, Heat, and story log atomically.
6. Cover both normal services and the existing Jazz rollback special case to ensure a shared transaction helper preserves intentional behavior.

## Scenario and catalog coverage

### Catalog inventory

| Archetype | Authored scenarios |
|---|---:|
| Corner Store | 5 |
| Back Alley | 4 |
| Motel | 4 |
| Bar | 7 |
| Gas Station Casino | 5 |
| Punchline / Small Underground Casino | 8 |
| Jazz Club | 4 |
| Kitty Cat Lounge | 4 |
| Delta Queen | 5 |
| Beach | 3 |
| Pawn Shop | 3 |
| Grand Casino | 3 |
| **Total** | **55** |

Additional catalog counts were 89 items, 18 services, 5 lenders, 13 Crew jobs, and 12 authored travel routes.

### Fresh scenario-sequence audit

The fresh audit passed with:

- 55/55 expected scenarios discovered.
- 1,485/1,485 pairwise comparisons completed.
- 0 failures and 0 similarity warnings.
- 11/11 hostile fixtures rejected.
- 55 semantic dossiers generated.
- 5 package files validated.

An independent `SEEDSWEEP-A` room-finalization family then exited successfully before the next family began, establishing 55 additional finalizations under a separate seed family. Its base dump contains 466 finalized object-placement records. Expansion stopped at that point to release the serialized runtime to the dedicated six-hour performance soak; the partially started next family was not used as evidence.

## Systems matrix results

The following 23 targeted contracts passed with zero assertions:

- Run-action boundary, item effects, and item-build interactions.
- Crew layer-3 jobs, Crew plays, Crew heist, Crew turns, and character chains.
- Content depth.
- SaveService foundation round-trip.
- Economy pressure.
- Travel route and world map.
- Meta-home run boundary, fresh-store defaults, and fixture-pollution migration.
- Service hooks.
- Lender/debt behavior.
- Suspicion/security.
- Run reporting.
- M2 cross-system interaction scenario.
- Demo boss/Grand Casino objective.
- Recovery and loss pressure.

These passes do not prove every permutation correct, but they narrow XPE-01 to transaction ordering rather than general failure of debt, services, inventory, travel, or terminal-state systems.

## Excluded assertions and previously reported findings

### E-01 — Crew golden-byte drift under shared baseline edits (15 assertions)

The Crew recruitment contract's behavioral assertions were not the reported failures. All 15 failures were exact hash/byte comparisons against the `CREW-IGNORED-GOLDEN-A/B` baseline at ordinary travel, bar revisit, and save/load checkpoints. The shared worktree currently contains edits to both `crew06_5_ignored_run_baseline.json` and its provenance constant, plus other scenario-generation work. This makes the snapshot gate unsuitable for identifying a player defect during this concurrent pass. No Crew-specific state corruption or trust/job failure was exposed, and the separate Crew jobs, plays, heist, turn, and character-chain contracts passed.

Disposition: test-baseline synchronization issue; not counted as a product bug.

### E-02 — Closing-time host fixture runs before staged UI readiness (2 assertions)

The two time/open-hours assertions were identical to the earlier H-03 finding: the fixture creates `FoundationMain` and drives refresh/input routing before the staged run UI receives its ready/prewarm frames. Production closing logic independently resolves the authored room host, queues the closing dialogue, waits for acknowledgment, and then opens the map. This lifecycle mismatch had already been isolated in the first progression report.

Disposition: known harness issue; not counted again.

### E-03 — Jazz placement expectations conflict with current authored anchors (8 assertions)

The isolated Jazz rerun reproduced eight fixed-zone assertions. Comparison with `data/environments/placement_surfaces.json` showed that several expected rectangles are incompatible with the current authored positions themselves. For example, the ticket redeemer is authored at the top wall (`[600, 0]`) while the check expects its center in a lower room rectangle beginning at y=210; the generated center `(652, 29)` is consistent with the authored top-wall anchor. Other Jazz items show the same old-zone/current-anchor mismatch.

The broad UI worker separately tested actual overlap and reachability, so any real Jazz overlap belongs to that report. These fixed-zone assertions do not establish an additional progression bug.

Disposition: stale layout expectations/UI duplicate; not counted here.

### E-04 — Jazz invitation fixture resolves an event without host authorization (3 assertions)

The fixture calls `EventModule.resolve(..., "take_the_shades")` after `can_trigger()` but never enqueues that event as pending. Production event resolution requires the exact event id to be host-authorized. This is the same fixture class as the earlier H-02 dialogue failure. Because resolve is correctly rejected, the subsequent inventory and flag assertions fail as consequences.

Disposition: stale event-authorization fixture; not counted as a product bug.

### E-05 — GP-01 tutorial focus bug is a duplicate

The earlier gameplay/progression pass already confirmed that buying the Pencil before Coffee clears the Coffee selection and makes the final lesson highlight the shelf instead of the Buy action. This remains valid but is not recounted as new in XPE totals.

### E-06 — GP-02 save/load claim is rescinded

The persistence-chaos investigation showed that the previously reported integer-to-float loss occurred only when a harness passed raw JSON directly into `RunState.from_dict()`. Production `SaveService` uses a typed codec and preserves those integers. The ordinary SaveService round-trip contract passed again in this wave. GP-02 is therefore excluded from the product bug count.

## Intentional behavior reviewed

- Ignoring an offered Crew job until it expires can convert it through accepted/active/abandoned states and reduce trust. Authored design notes explicitly describe consequences after an offer is accepted; the no-cost "ignore Crew" route refers to not taking the offer. This is intentional pressure, not a bug.
- The repeat brother-in-law loan path is deliberately repeatable and carries its own nag/default story state.
- Inventory item ids are unique-set membership; duplicate acquisition attempts do not create duplicate entries by design.
- Closing-time travel selects a safe visited home/always-open fallback when the current venue closes. No invalid destination was found in the production route logic.
- Travel minutes do not normally advance the action-count debt clock. XPE-01 should not be generalized to travel without a separate reproduction.
- Similar pawn/ticket cash-out ordering uses different reward and rollback semantics. No unfunded mutation was reproduced there.

## Prioritization and regression recommendations

XPE-01 should be addressed before economy tuning. It violates atomic transaction expectations, can cause an unexpected terminal loss, and grants benefits after an underfunded operation. The fix should be validated at the shared transaction boundary rather than patched only for the two concrete examples.

Recommended release gates:

1. Re-run the eight-case `progression_boundary_probe` and require due-debt cases either to commit against reserved funds or reject without any partial mutation.
2. Add equivalent tests for every cash-priced service and item-offer path with a debt clock at one action.
3. Assert that a failed cash mutation cannot continue into inventory/flag mutation unless explicitly authorized as terminal settlement.
4. Keep the 55-scenario sequence audit and at least one independent 55-scenario finalization family as progression release gates.
5. Repair or refresh E-01 through E-04 before relying on those assertions as product signals.

No fixes were made in this pass. The only created executable artifact is the isolated playtest probe under `.tmp`; all retained recommendations are for the later bug-fixing team.
