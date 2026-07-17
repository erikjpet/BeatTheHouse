# Agent Prompt — Pawn Ticket System: Verify the Full Spec Landed, Close Any Gaps

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Run logic in
`scripts/core/run_state.gd` + `scripts/core/run_action_service.gd`; UI via
extracted components; content in `data/*.json`. This file is
self-contained. Suite timeout = max(300s, ceil(recorded baseline in
tools/check_godot.ps1 × 1.5)).

## Background

The run-side Sal's Pawn Shop shipped during 0.4 polish (tier-1 archetype
with a discounted item shop pool and the `sals_pawn_counter` lender —
verified present). What was SPECCED alongside it has never been verified
against the shipped code. The original spec, restated in full (this is
the contract to audit against):

1. **Discounted shop**: pawn-shop item offers price below typical via
   `economic_profile.shop_price_multiplier` (~0.85, floor 1) applied at
   offer build.
2. **Multi-item, player-selected pawning**: a Pawn Counter flow listing
   every sellable inventory item with a deterministic loan quote
   (sale_price × the lender's `loan_to_sale_price_multiplier`, clamped
   by the debt profile). The player chooses WHICH items to pawn, any
   number of them, one ticket each — replacing the old auto-pick of the
   first sellable item.
3. **Ticket ledger with selective redemption**: a Redeem view listing
   every active pawn ticket (item, buy-back price, turns remaining);
   the player redeems the SPECIFIC ticket they choose. Buy-back =
   principal + fee (`redemption_fee_rate` ~0.25 in
   `data/debt/lenders.json` debt profile, min $1, ceil). The
   `pawn_receipt_sleeve` grace-turn item still extends deadlines.
4. **Forfeit shelf**: an expired ticket forfeits the item to Sal, who
   then SELLS it on the pawn-shop shelf at retail (`price_max`, no
   discount) for the rest of the run; buying it back removes it from
   the forfeited list. Run-persistent, save/load safe, injected at
   entry/refresh from RunState (not baked into the generated
   environment instance).
5. **Debt panel line** for pawn tickets shows the buy-back amount.

## Task

### Phase 1 — Audit (evidence first)

For each numbered spec item: find it in the shipped code (cite
file/function) or mark it MISSING/PARTIAL. Check tests too — coverage
may exist without UI, or UI without tests. Produce the audit table
before writing any fix. If everything shipped: report the table, run
the gates, delete this prompt, done — do not invent work.

### Phase 2 — Close the gaps (only what the audit found)

Implement missing/partial items to the spec above. Established
patterns to follow: RunInventoryScreen-style extracted component for
the counter/ledger UI; deterministic quotes (no RNG); tickets as
per-item debt entries (`debt_kind == "pawn"` with per-item ids — the
settle path already returns collateral); forfeited-item injection at
environment entry/refresh. Sal's counter hook in OTHER environments
uses the same flow (one code path).

## Hard rules

- Zero-copy per-frame: counter/ledger lists build on open/change only.
- Determinism: quotes, fees, forfeit prices contain no RNG; probe stays
  self-consistent.
- Meta gold economy and run cash economy stay fully separate (the meta
  pawn shop's gold counter is a different system — do not touch it).
- Do not rebalance lenders/items beyond the spec. Idle liveness
  untouched. Style: tabs, typed GDScript, sparse comments; `.tmp/`
  reports only.
- SCHEDULING GUARD: if the gc05 Grand Casino queue is still running on
  this machine (gc05_*_prompt.md files present in docs/todo), do NOT
  start — this task shares run_state/run_action_service with it. Report
  and stop instead.

## QA / Tests (for whatever Phase 2 implements; regression for the rest)

1. Multi-pawn: three distinct items → three tickets, correct
   principals/fees, bankroll credited with principals only.
2. Selective redemption: redeem the middle of three tickets → exactly
   that item returns, exact payoff charged, others intact.
3. Fee math: payoff == principal + max(1, ceil(principal × rate)).
4. Grace: pawn_receipt_sleeve extends ticket deadlines.
5. Forfeit shelf: expire → shelf at price_max → buy back → removed;
   save/load round-trips tickets + forfeited list.
6. Discount bounds on pawn-shop offers; non-multiplier archetypes
   unchanged.
7. Manual smoke: pawn two items, leave, return, redeem one, let one
   forfeit, buy it back at retail.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit (audit; fixes as logical units), delete this prompt file in the
final commit, push, and report the audit table (spec item → shipped
evidence or gap → action taken) and every gate result. On an unfixable
gate failure: stop at the last green commit and report verbatim.
