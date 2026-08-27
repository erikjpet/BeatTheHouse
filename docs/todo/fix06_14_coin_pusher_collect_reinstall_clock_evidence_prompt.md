Status: IN PROGRESS / INTEGRATION REVIEW PENDING
Board row: `fix06_14` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_14: Coin Pusher COLLECT/reinstall production-clock evidence

Work from exact current `main` only after `fix06_13` lands or parks with its
retained shipped-Web evidence. This row owns the production-clock/evidence
synchronization contradiction exposed by the locked Coin Pusher Web harness. It
does not own the shipped-Web performance optimization or its locked caps.

## Retained evidence

The accepted baseline reproduction
`.tmp/fix06_13_reproduction_a5853676/web_coin_pusher_reproduction.json`, the
first post-fix result
`.tmp/fix06_13_first_postfix_ecaecdc2/web_coin_pusher_first_actual.json`, and
iteration 2 all begin normal idle with exactly 300 bodies and legitimately move
to 296 through the live production solver. Iteration 3 preserves the same
motion at exact head `d899b18f883b3339b574cff78058ac46fff729cd`.

The iteration-3 locked report is
`.tmp/fix06_13_iteration3_d899b18f/web_coin_pusher_first_actual.json`, SHA-256
`FAD397C558C5E57208EA203BE5044F3E00544CD3DA883B415A66BDF0CE8F5587`.
Its summary SHA-256 is
`9DB812313AD99FA8E8B15D06FC4D94C1DC307C03C4424F580B706096506D5A8F`.
COLLECT begins from the required conserved 300-origin fixture as 299 active
bodies plus one tray body. The accepted action empties that seeded tray, but
new legitimate physical exits occur during the locked 60-frame observation
window and leave two new tray bodies. A fresh reinstall likewise advances to
296 before the harness records its identity.

## Required work

1. Reproduce the exact contradiction without changing the locked harness.
2. Attribute the production clock from reinstall/action acceptance through the
   identity and after-state capture boundaries.
3. Implement the smallest synchronization correction that makes the evidence
   observe the intended boundary while preserving every simulation tick and
   every legitimate post-action outcome.
4. Independently review the classification and the correction, then run the
   full Coin Pusher evidence and normal landing gates.

## Locked boundaries

- Do not stop, delay, delete or auto-collect legitimate coin motion to satisfy
  an assertion.
- Do not weaken, filter or edit the locked fix06_9/fix06_13 harness, fixture,
  sample lengths, liveness requirements or caps.
- No gameplay, RNG, payout, odds, wager, economy, geometry, tuning, schema or
  migration change.
- Preserve all red and green results and exact build identity.
