Status: IN PROGRESS / FINAL DOC REVIEW PENDING
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

## Current-main qualification closeout — 2026-08-27

Exact candidate `dba07c1a5c675e07cb9a3dc2956889d67086df2a` consumed one
fresh-export Chrome 151 CPU-4 qualification on `DESKTOP-1950ULQ`; no same-head
rerun occurred. A setup-only first invocation failed before export and browser
because `GODOT_BIN` was absent. The measured invocation used canonical Godot
4.6 SHA-256
`FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE`,
port 18117, export aggregate
`E0C3B16FAA466C12B15007C894E781EE7927E70AE13B9D03F0D4AFC4E1085CD4`
and generated Web native
`31D60D25AD00969A9F7DD115AD7B5E4DC8F1CC4795514DF309A2526F1452C8FB`.

All eight scenarios completed. Every row-owned exact fixture, full-channel
conservation, COLLECT action-acceptance/terminal accounting, reduced-motion
schema, production draw, solver-liveness and scheduler assertion passed. Idle
recorded 15,971ms of exact production scheduler demand and 16 redraws; reduced
motion recorded zero scheduler time/redraws while preserving 120 real draws.
The summary contains exactly 20 failures, all readiness/frame/draw/resolve
performance reds retained for `fix06_13`; this row changed no cap and did not
rerun.

The same exact head also passed canonical Godot 4.6 native validation, import,
GDScript load and focused Foundation Coin Pusher in
48.214/17.835/24.644/164.306s. Every stage had zero failures and no stderr
issue, using the ignored Windows native DLL SHA-256
`1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5`.
The gate summary at
`.tmp/fix06_14_dba07c1a_coin_pusher_gate/summary.json` has SHA-256
`E3F66C060752BC43FBB08798252E3269AD7C303C1C5909E7294C267A116A229A`.

The wrapper wrote its complete report and summary before outer orchestration
remained alive until 904s because `serve_web.ps1` left Python PID 39916 on port
18117. The PM stopped only that exact PID and verified the process/listener
clear. This lifecycle issue is routed without changing the consumed head as
`fix06_16`; it must close before the next locked `fix06_13` run. Exact hashes
and every timing are preserved in the canonical ledger and dated work log.

fix06_14 is row-owned green but remains IN PROGRESS until this documentation
head receives independent review, lands on `main`, and passes proportionate
post-land verification.
