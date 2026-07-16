# Agent Prompt — 0.5 Slice 2: Chips Economy + the Cage Window (Linda)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Data-driven content in
`data/*.json`; run logic in `scripts/core/run_state.gd`; UI via extracted
controllers + pure view models (foundation_main gains wiring only). This
file is self-contained; the binding design contract is
`docs/plans/0.5_grand_casino_rework_plan.md` section 2 — read it first.
Requires slice 1 (three casino rooms) already landed; re-verify its actual
code, code reality wins.

## Task

### 1. Chips currency (Grand Casino scope)

- Add `grand_casino_chips: int` to RunState (typed field, serialized,
  reset per run). Inside the Grand Casino rooms, TABLE games (blackjack,
  baccarat, roulette) charge wagers from and pay winnings to CHIPS.
  Machines (slots, video poker, pull tabs) and bar dice keep paying cash
  exactly as everywhere else.
- Buy-in: converting bankroll→chips happens at the table (automatic
  top-up prompt when chips are short) and at the Cage. Conversion is
  1:1, no fee *(tunable data)*.
- Find the money seam precisely: `GameModule.apply_result()` /
  `empty_result_deltas` route `bankroll_delta` — add a chips routing
  path that is ONLY active for table-game results inside Grand Casino
  archetypes (use slice 1's `is_grand_casino_environment()` helper +
  game family). Every other environment and game is byte-identical.
- Score interaction: chip buy-ins must not double-count
  `record_score_spending`; chips↔cash conversions are transfers, not
  spending. Cover with a test.
- HUD: while in the casino, show the chip balance alongside bankroll
  (reuse the existing HUD status line idioms; no new chrome).
- Clean-route criteria: `grand_casino_net_winnings` must now count
  chips + cash gained since entry (the canonical formula in
  `docs/plans/grand_casino_endgame_design.md` updates from pure
  bankroll delta — update that doc's field meaning in this slice's
  commit).

### 2. The Cage window

- The Main Floor cage interactable (stubbed in slice 1) opens a modal
  window component (`CageWindow` + pure view model, RunInventoryScreen
  extraction pattern) — one screen, efficient, no scrolling:
  - **Linda**, the cage host, present as a portrait + one contextual
    dialogue line (talk-dock portrait pipeline reuse; Linda is a named
    recurring character — her full dialogue arc arrives in slice 5).
  - Chip balance + Cash Out action (chips → bankroll).
  - Players Card status block: tier/progress placeholder this slice
    (slice 5 fills it), review-ready state, and the dirty-money /
    blocked-review state made VISIBLE (the existing
    `grand_casino_attention_high_roller_review` routing now shows its
    reason here instead of being implied).
  - Promotions/comps list (empty-state ready; slice 5 populates).
- The clean-route Players Card review (`high_roller_cashout` — id
  preserved) becomes a Cage window action when ready, replacing its
  current event-surface presentation. Same state transitions, same
  flags, same victory route.

## Hard rules

- Determinism unchanged (conversions are arithmetic; no new RNG).
- Zero-copy per-frame: window view model built on open/state-change
  only. Idle liveness untouched.
- Save compat: chips serialize; canonical endgame ids/flags unchanged;
  a mid-casino save restores chips and window availability.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports only.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Table game in casino pays chips, machine pays cash, same games
   outside the casino pay cash (regression).
2. Buy-in/cash-out round trip conserves total money; score spending
   counted once; save/load round-trips chips.
3. Clean-route victory still achievable end-to-end through the Cage
   review path (drive the full sequence in a test).
4. Blocked review (heat/evidence) shows the routed-to-Rourke state in
   the window and still transitions per the state machine.
5. Visual QA + manual smoke: buy in, win at blackjack, cash out, read
   every window section.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report the money-seam implementation, window component API, and
gate results. On an unfixable gate failure: stop at last green commit,
report verbatim.
