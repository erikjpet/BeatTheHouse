# Agent Prompt — Cage Rework: Full Room, Silhouette Linda, ATM Debt, and Gift Shop

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike targeting Web/itch.io and Windows at 1280×720. This is an extensive
rework of landed Grand Casino systems, not a greenfield feature.

Read these files completely before editing:

1. `docs/plans/0.5_cage_environment_rework_plan.md` — the binding specification
   for this task.
2. `docs/plans/0.5_grand_casino_rework_plan.md` — binding except where the Cage
   rework plan explicitly supersedes its old "Cage is not a room/modal window"
   decision.
3. `docs/plans/grand_casino_endgame_design.md` — canonical endgame IDs, flags,
   and route meanings must survive unchanged.
4. `docs/plans/content_style_guide.md` — binding player-facing copy rules.

Do not reinterpret the locked economy or progression rules. If code and this
prompt disagree, preserve unrelated landed behavior but implement this prompt's
explicit Cage, debt, and Players Card changes.

## Outcome

Replace the Main Floor Cage modal with a complete fourth Grand Casino
sub-environment. It must look and behave like a real casino cashout room with
new art, barred teller windows, a living faceless Linda silhouette, a casino ATM,
and a compact gift shop. The player walks into the room and approaches three
separate physical fixtures; the room must not feel like one large menu.

Migrate all existing Linda and Players Card behavior into this environment,
remove the obsolete modal path, implement debt-first chip cashout, implement a
$50-step/$500-cap ATM whose balance compounds 5% at every in-game 3:00 AM, and
make every Players Card tier a sequential claim from Linda while debt-free.

## Before editing: audit and migration map

Locate the landed code rather than guessing. At minimum inspect:

- `scripts/ui/cage_window.gd`;
- `scripts/ui/cage_window_view_model.gd`;
- all Cage construction, signals, overlay blocking, snapshots, tutorial state,
  and action handlers in `scripts/ui/foundation_main.gd`;
- chip buy/cashout, Players Card derivation/benefits/dialogue, Grand Casino room
  state, game clock, debt, and serialization in `scripts/core/run_state.gd`;
- `scripts/core/run_generator.gd` and the existing internal casino-room seam;
- `scripts/ui/environment_interaction_controller.gd` and associated view models;
- the Grand Casino entries in `data/environments/archetypes.json`;
- Linda dialogue in `data/dialogue/dialogues.json`;
- `high_roller_cashout`, `the_house_calls`, and pat-down classifications in
  `data/events/events.json`;
- lender/debt data and repayment paths;
- `data/tutorial/lessons.json` Cage tutorial steps;
- item catalog purchase/classification seams;
- run report/HUD/journal view models;
- existing Grand Casino foundation, save, determinism, UI, and tutorial tests.

Before the first implementation edit, write a concise migration map in your
working notes/report with these columns:

| Landed behavior | Current owner/file | New owner/surface | Preserved IDs/flags | Test coverage |
| --------------- | ------------------ | ----------------- | ------------------- | ------------- |

Include the old Cage modal, chip purchase, chip cashout, Bronze/Silver award,
Gold review, comps, Linda look-away, Linda ambient dialogue, tutorial anchors,
room storage, and save/load. Identify every old assumption that says the Cage is
Main-Floor-only or a modal.

Run the relevant baseline suites and record timings before changing code. Use a
suite timeout of `max(300 seconds, ceil(recorded tools/check_godot.ps1 baseline ×
1.5))`. Put generated reports only under `.tmp/`.

## Locked behavior — do not ask again

### Linda

- Linda remains the named host and teller. Do not introduce another Cage NPC.
- Keep her complete landed system: chip exchange, Players Card status and tier
  awards, Gold review, comps/promotions, warm scenes, and one-time look-away.
- Render her as a dark, featureless, secretive silhouette behind bars. Her face,
  eyes, and skin are never visible.
- Interaction with her uses the existing dialogue/talk menu system.

### ATM debt

- Borrowed money is real bankroll cash usable anywhere.
- Loans come in $50 increments, up to $500 of balance before new borrowing.
- There is no initial fee: borrowing $100 adds $100 cash and $100 debt.
- Every crossed in-game 3:00 AM boundary adds 5% interest.
- Integer rounding is house-favorable: `ceil(old_balance × 1.05)`.
- Interest may raise debt above $500; $500 limits new credit and does not cap or
  forgive interest.

### Linda's cashout

Linda automatically takes casino ATM debt from redeemed chip value before paying
cash. Do not hard-block the cashout action merely because debt exists.

At the landed 1:1 rate:

- debt $150 + 200 redeemed chips → debt $0, chips -200, bankroll +$50;
- debt $150 + 100 redeemed chips → debt $50, chips -100, bankroll +$0.

The second case is a successful partial debt payment. Direct cash repayment is
also available at the ATM.

### Players Card

- Linda is the only place that awards Bronze, Silver, or Gold.
- Reaching a threshold marks the next tier ready; it does not award it.
- The exact next-tier requirements and live progress must be clear in Linda's
  interaction.
- Debt above zero blocks every tier claim.
- Progression does not stack or backfill. The player must hold Bronze before any
  Silver progress counts and hold Silver before any Gold progress counts.
- Once a tier is ready, extra play is not banked for the following tier. Claiming
  from Linda begins a fresh next-tier progress segment.

### Gift shop

- It contains 3–4 items only.
- Every offer is non-contraband and non-surveillance under the authoritative
  showdown pat-down classification.
- Prices and payment use Grand Casino chips.
- Debt never disables gift-shop purchases.

## Implementation contract

### A. Add the fourth Grand Casino room

1. Add a canonical Cage archetype to the same room family as Main Floor,
   High-Limit Room, and Back Room. Extend only the room sets and normalization
   paths that genuinely represent all casino rooms.
2. Do not blindly add the Cage to Rourke patrol sets, duel-only sets, table-game
   sets, or access-gated sets. Explicitly test those distinctions.
3. Add Main Floor → Cage and Cage → Main Floor doors via the existing
   `local_casino_room` travel implementation. Preserve normal internal travel
   time, transition, turn/clock advancement, autosave, and world-map ownership.
4. The Cage is freely accessible whenever the Main Floor is accessible. It has
   no Silver requirement or cash bribe.
5. Casino chips, debt, Players Card state, evidence, heat/attention, room memory,
   and endgame state remain shared and authoritative across room swaps.
6. Give the Cage its own room description, moods, art key, generated layout,
   fixture declarations, focus rectangles, and return-door placement.

### B. Build new environment art

Create new repo-native/immediate-mode pixel art consistent with the landed Grand
Casino style. Do not solve this by using the Main Floor background, a full-screen
menu, or an external untracked asset.

The room composition must show:

- barred teller windows spanning a cash counter;
- pass-through trays, ledgers/cash details, queue rails, and casino lighting;
- Linda moving behind the barred windows as a silhouette;
- a readable ATM fixture separated from the counter;
- a small locked-glass gift display showing remaining stock;
- a readable Main Floor return door.

All service locations need distinct navigation/focus zones and hover/selection
feedback. Validate 1280×720, supported small-screen scale, keyboard navigation,
mouse targeting, reduced motion, and color/readability requirements.

### C. Replace the old Cage modal with three spatial fixtures

Create three stable fixture/action surfaces using established environment
interaction patterns:

1. **Cashout Counter** — Linda dialogue, chip purchase/cashout, card status,
   card claims, comps, and promotions.
2. **Casino ATM** — borrow, view balance/next interest, and repay from cash.
3. **Gift Shop** — inspect stock and purchase with chips.

Focused controls may open using the project's normal interaction panel pattern,
but there must not be one monolithic Cage overlay. The room remains visually
present and the three objects remain separate authored interactions.

Delete `CageWindow` construction, preloads, signals, modal blockers, overlay
snapshot fields, and dead UI after all behavior has moved. Remove
`ui.cage_window_open` as a live requirement. Keep legacy identifiers only as
explicit compatibility aliases for old tutorials/saves/tests during migration;
aliases must route into the new room/fixtures and must not instantiate the old
window.

### D. Implement Linda's simulation and visual identity

1. Add several authored silhouette positions behind the counter plus facing and
   movement cadence state.
2. Choose state transitions only at meaningful action boundaries with a named
   `RngStream` fork. Copy Rourke's determinism discipline where applicable, but
   do not make Linda a Rourke patrol participant.
3. Serialize pose, facing, action countdown/index, and fork state needed for
   exact continuation.
4. Reopening dialogue, room refreshes, resize, redraw, or save/load must not
   consume RNG or change her logical pose.
5. Visual interpolation/idle animation may move between logical poses, driven
   from cached state snapshots and the existing liveness system. Respect reduced
   motion. Never use wall-clock state to make simulation decisions.
6. Add an automated visual-state assertion that all Linda render/dialogue models
   use the silhouette representation with no portrait face fields or facial
   layers. Manually inspect all poses.
7. Preserve Linda's name and warm voice. Adjust only enough copy to support the
   private, secretive presentation and follow the content style guide.

### E. Migrate the complete Linda interaction

The Cashout Counter must expose, through Linda's dialogue/menu flow:

- bankroll, Grand Casino chips, exchange rate, and casino ATM debt;
- chip purchase options;
- debt-first cashout and a precise preview of debt paid/cash received;
- current awarded Players Card tier;
- exact requirements and progress for the next immediate tier;
- claim action or its specific block reason;
- earned tier benefits;
- drink comps, suite rest, and look-away status/actions;
- ambient and tier dialogue scenes;
- the canonical Gold review.

Migrate the landed mechanics; do not duplicate their business rules inside the
view. Preserve every canonical flag and one-time benefit unless the sequential
claim contract explicitly requires a new state representation.

### F. Make Players Card progression sequential and claim-based

Refactor the current cumulative derived-tier behavior into an explicit awarded
tier plus active-segment progress.

Required state concepts:

- `awarded_tier`: none, bronze, silver, or gold;
- `next_tier`: the immediate successor only;
- progress baseline/counters for the segment that began when `awarded_tier` was
  granted;
- `ready_to_claim` for the immediate next tier;
- permanent eligibility/ineligibility and reason;
- one-time benefit grants/dialogue completion.

Required behavior:

1. On initial Grand Casino entry, only Bronze requirements accumulate.
2. When Bronze requirements are met, freeze Bronze progress at ready. Additional
   games or winnings do not count toward Silver.
3. Linda may award Bronze only when debt is zero and all existing clean/heat/
   evidence conditions pass. Award benefits/dialogue once, then start a fresh
   Silver segment.
4. Repeat the same flow for Silver. Only play after Silver is awarded counts
   toward Gold.
5. Gold readiness leads to Linda's canonical Gold review. Do not end the run or
   mint the meta Players Card before the debt-free Linda claim resolves.
6. Debt may be acquired or accrue after readiness. Readiness stays pending but
   claim is disabled until debt returns to zero.
7. Clearing debt immediately re-evaluates the counter. Do not require another
   game to expose the pending claim.
8. Preserve total Grand Casino games/net-winnings statistics separately for
   scoring, reporting, showdown facts, and other landed logic.
9. Preserve permanent card ineligibility from cheating. Debt is temporary and
   must not set permanent evidence/ineligibility flags.
10. Preserve carried/prestige Players Card semantics. Explicitly define and test
    the active starting tier/baseline for those runs rather than silently
    resetting earned prestige.

Linda's UI must display each relevant requirement independently, e.g. games
`2/3`, tier-segment net winnings `$9/$15`, and heat `18/30`, plus plain status
copy such as "Silver ready — settle your $53 marker before Linda can issue it."

### G. Implement the ATM as the house marker

Use data-authored defaults:

- `loan_increment = 50`;
- `loan_cap = 500`;
- `origination_fee = 0`;
- `daily_interest_rate = 0.05`;
- `interest_minute_of_day = 180` (3:00 AM).

The ATM view model/panel shows:

- current debt;
- available $50 increments that fit under the cap;
- cash received and resulting balance before confirmation;
- next 3:00 AM interest time;
- projected next balance using the exact rounding rule;
- partial cash repayment and Pay in Full;
- plain disabled reasons.

Borrowing is atomic: validate first, then add the same amount to bankroll and
debt, log it, advance the appropriate action/clock boundary, autosave, and
refresh. Invalid increments, nonpositive amounts, and draws that exceed the cap
mutate nothing.

Use one authoritative casino marker. Expose `grand_casino_atm_debt` as the
stable balance name in state snapshots/save/reporting. If integrating it as a
normalized debt entry so existing open-debt systems see it, provide accessors
and invariants that prevent a duplicate integer field and array entry from
diverging or being counted twice.

The marker:

- persists outside the casino for the rest of the run;
- appears in debt summaries, journal, HUD where relevant, and the run report;
- counts once as open debt in the showdown's existing open-debt calculation;
- has no turn deadline, collector event, default state, collateral, forced
  payment, or conversion into another lender;
- does not fail the run on its own.

### H. Accrue 5% at each 3:00 AM boundary

The existing clock is authoritative and expressed in absolute minutes. Add a
focused, testable clock-boundary hook; do not tie interest to UI openings,
environment turns alone, midnight day rollover alone, or real time.

For every boundary at absolute minute `180 + (1440 × day_index)` crossed by a
positive clock advance:

```text
if debt > 0:
    old_balance = debt
    new_balance = ceil(old_balance * 1.05)
    interest_added = new_balance - old_balance
```

Process all crossed boundaries in order when a single travel/service/sleep jump
spans several days. A balance may change between boundaries only through the
defined chronological mutations. Save an accrual watermark/boundary index so:

- loading never accrues;
- replaying the same absolute minute never accrues;
- a legacy save initializes safely without retroactively charging its history;
- the next newly crossed 3:00 AM charges exactly once;
- deterministic probes see identical balances and logs.

Each charge logs old balance, rate, added interest, and new balance. Surface a
concise notification at the next safe UI boundary without interrupting another
blocking decision. Do not silently lose notifications when several boundaries
are crossed.

Required exact examples include:

- $0 remains $0;
- $200 becomes $210;
- $50 becomes $53 under ceiling-to-dollar rounding;
- $500 becomes $525 and remains valid debt although above the borrowing cap;
- $200 becomes $210, then $221 across two boundaries (`ceil(210 × 1.05)`);
- save immediately after accrual, reload, and advance short of the next 3:00 AM:
  no second charge.

### I. Make cashout automatically settle debt first

Put the arithmetic in one pure/testable model or run-state method and reuse it
for preview and mutation. The preview and committed result must never disagree.

For requested chips and current exchange rate:

```text
gross_value  = requested_chips * exchange_rate
debt_paid    = min(gross_value, grand_casino_atm_debt)
cash_paid    = gross_value - debt_paid
debt_after   = grand_casino_atm_debt - debt_paid
chips_after  = grand_casino_chips - requested_chips
cash_after   = bankroll + cash_paid
```

Return structured fields for all amounts, not only message copy. Apply the
entire state transition atomically. A result with `cash_paid == 0` and
`debt_paid > 0` is successful. Preserve existing hard lockouts from the active
Rourke duel or being shown the door.

After settlement:

- update open-debt/economy state exactly once;
- re-evaluate Linda's pending card claim;
- advance time/turns using the landed Cage action convention;
- log chips redeemed, gross value, debt paid, remaining debt, and cash paid;
- autosave and refresh counter, ATM, HUD, and report snapshots.

Direct ATM repayment debits only bankroll and supports any whole-dollar partial
amount from $1 through the available balance, plus Pay in Full. It never consumes
chips or adds a fee.

### J. Implement the chip-priced non-contraband gift shop

1. Add data-authored stock count bounds of 3 and 4 and a curated candidate pool.
2. At generation time, filter candidates through the same authoritative item
   classification the showdown pat-down uses. Exclude contraband and
   surveillance. Do not rely only on a manually copied list.
3. If filtering leaves fewer than three valid offers, fail validation with a
   useful content error rather than filling with forbidden or duplicate items.
4. Generate stock/prices from a named seeded fork once per documented shop
   lifecycle. Save generated offers and sold state. Panel open, redraw, room
   travel, and save/load cannot reroll them.
5. Display 3–4 compact items in the locked-glass case and focused shop panel.
6. Price and debit in Grand Casino chips only. Show current chips and exact
   affordability.
7. Keep purchases available at any casino ATM debt balance.
8. Route successful purchases through standard item acquisition, capacity,
   duplication, effects, story log, clock, and autosave behavior.
9. A failed purchase changes neither chips nor stock. A successful purchase
   removes/marks only that offer and updates the physical display.

### K. Save compatibility, tutorial, and cleanup

Persist and normalize:

- the Cage room in `grand_casino_room_states`;
- ATM debt and the 3:00 AM accrual watermark;
- Linda pose/movement state;
- shop stock/prices/sold state;
- awarded card tier, active-segment progress baseline/counters, readiness, and
  one-time claims.

Legacy saves:

- default casino ATM debt to zero;
- initialize the accrual watermark at the loaded clock without retroactive
  interest;
- retain already awarded Bronze/Silver/Gold tiers and benefits;
- convert existing pending Gold review into a pending Linda claim;
- derive a conservative active-tier segment without granting an unearned later
  tier from old cumulative excess;
- close any obsolete Cage modal state and leave the new room reachable;
- never duplicate chips, cash, comps, tier rewards, or shop stock.

Rewrite the Grand Casino tutorial so it physically directs the player into the
Cage, focuses the counter, buys chips, leaves for the required game, returns,
settles/cashes out, and completes Linda's card claim. Replace old
`ui.cage_window_open` predicates and obsolete modal close steps with stable room,
fixture, and dialogue/action anchors. Preserve tutorial gating and keyboard/mouse
playability.

Delete dead modal files only after all references and compatibility needs are
resolved. `rg` must show no live `CageWindow`, `_cage_window_is_open`, or old
overlay blocker path. Update comments and the upstream Grand Casino plan lines
that would otherwise falsely describe the shipped post-rework architecture, but
do not rewrite unrelated history.

## Required tests

Write focused failures before or alongside each slice, then keep them green.

### Room and visual state

1. Cage is a fourth valid stored Grand Casino room.
2. Main Floor ↔ Cage travel uses the existing local-room seam and preserves all
   shared casino state.
3. Cage is freely accessible and is not accidentally a Rourke patrol/duel room.
4. Exactly three primary service fixtures exist with stable focus/action IDs.
5. Linda silhouette pose sequences match for the same seed/actions and survive
   save/load.
6. Linda's render models contain no facial presentation.

### ATM and interest

7. $50 increments credit equal cash/debt; invalid amounts mutate nothing.
8. Borrowing to exactly $500 works; a further $50 fails.
9. Interest can increase $500 to $525 and no new credit is offered.
10. Crossing 2:59→3:00 charges once; 3:00→3:01 does not charge again.
11. A large clock jump charges every crossed 3:00 AM in order.
12. Ceiling rounding and compounding match all examples in section H.
13. Borrowing just after 3:00 AM waits until the following 3:00 AM.
14. Save/load at and around the boundary cannot skip or duplicate a charge.
15. Legacy saves begin with zero ATM debt and no retroactive interest.

### Debt settlement

16. Debt 150/chips 200/rate 1 → debt 0, chips 0, cash +50.
17. Debt 150/chips 100/rate 1 → debt 50, chips 0, cash +0, success.
18. Debt 0 preserves landed cashout behavior.
19. Non-1 exchange rate uses gross cash value consistently.
20. Partial/full cash repayment works and cannot overdraw bankroll.
21. Failed duel/door lockout cashouts mutate nothing.
22. Across borrow → interest → play/spend → repay/cashout, assert every currency
    delta and no duplicated/destroyed value beyond the explicit interest charge.

### Players Card

23. Unranked play can prepare Bronze only; no Silver progress exists before
    Bronze claim.
24. Bronze readiness freezes while extra play occurs; Linda claim starts Silver
    progress at zero.
25. The same non-stacking rule holds from Silver to Gold.
26. Debt blocks Bronze, Silver, and Gold claims without destroying readiness.
27. Clearing debt via cash or debt-first chip cashout enables the claim
    immediately.
28. Bronze/Silver benefits and dialogue grant exactly once at Linda.
29. Exact next-tier requirements and progress appear in the view model.
30. Cheat evidence remains permanently ineligible; casino debt remains a
    temporary block only.
31. Carried/prestige card runs initialize at the correct sequential tier.
32. The clean route completes only through Linda's canonical
    `high_roller_cashout`; route flags, card mint, victory, and save/load survive.
33. Showdown behavior and canonical IDs remain unchanged except that casino ATM
    debt counts as one existing open debt.

### Gift shop and migration

34. Every seed produces exactly 3–4 distinct stock entries.
35. Across many seeds, no authoritative contraband or surveillance item appears.
36. Purchases debit chips, never bankroll, and work while debt is positive.
37. Stock/sold state survives room travel and save/load without reroll.
38. Standard inventory/capacity/duplicate behavior is preserved.
39. Old Cage modal code is unreachable/removed and modal overlay invariants no
    longer include it.
40. Migrated tutorial completes with keyboard and mouse through the room.

## Verification gates

Run and report all applicable gates. Discover the exact supported suite names
from the repository rather than inventing flags.

- `tools/validate_project.ps1`
- every supported `tools/check_godot.ps1 -FoundationSuite ...` covering core
  systems, lenders/save compatibility, Grand Casino, UI, tutorials, items,
  collections/meta, and report/HUD flows
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_performance_probe.ps1 -RequireGodot`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- `tools/foundation_mouse_playtest.ps1` as one strict run

Also perform a manual smoke at 1280×720 and supported small-screen scale:

1. enter the Cage from the Main Floor;
2. inspect all new art and Linda's movement;
3. borrow $200 and verify bankroll/debt;
4. advance across 3:00 AM and verify debt becomes $210 exactly once;
5. buy a gift-shop item with chips while indebted;
6. reach a card threshold and verify Linda blocks the claim;
7. cash out fewer chips than the debt and verify a successful partial payment;
8. earn/redeem enough chips to clear the remainder and receive only the excess
   cash;
9. claim Bronze, verify Silver starts from zero, then repeat through Gold;
10. complete the clean victory and separately smoke the showdown route;
11. save/load before and after an interest boundary and inspect the run report.

Capture visual QA for the empty/normal shop, indebted ATM/counter, pending
debt-blocked tier, debt-free claim, reduced motion, and small-screen states.

## Completion discipline

Keep unrelated working-tree changes intact. Commit in reviewable logical units:

1. red tests/state contract;
2. Cage environment and art;
3. Linda migration and old modal removal;
4. sequential Players Card claims;
5. ATM, 3:00 AM interest, and reporting;
6. debt-first cashout;
7. gift shop, tutorial, polish, and final evidence.

Do not delete this prompt. After implementation and every required gate is green,
prepend the execution record required by `docs/todone/RULES.md`, then move this
file with `git mv` into `docs/todone/` in the final evidence commit.

On completion, report:

- the migration map;
- new/changed canonical IDs and compatibility aliases;
- data tunables and final values;
- save migration behavior;
- automated and manual gate results with elapsed times;
- visual QA artifact paths;
- commits by slice;
- any deviation from this prompt and why.

If a required gate cannot be fixed without changing a locked owner decision,
stop at the last green commit and report the failure verbatim. Do not silently
weaken a test, change the economy, restore the old modal, or bypass the gate.
