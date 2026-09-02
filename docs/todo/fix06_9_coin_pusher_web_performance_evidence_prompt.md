Status: TODO
Board row: `fix06_9` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_9: shipped-cap Coin Pusher Web performance evidence

Work in `D:\Projects\Beat-The-House` on a clean branch from the exact current
`main`. Read the current landing contract, pusherv3_11 closure report, V3 plan
performance contract, `foundation_performance_probe`, `web_perf_smoke`, its
browser probe and telemetry overlay, and the current input-parity export.

The closure audit requires shipped-cap performance on native and Web, including
per-action frame/draw budgets and a nonzero idle-liveness counter. Native already
has a maintained 300-body probe. The Web parity export uses a 40-body logic trace
and cannot be reported as performance. Existing Web smoke plans do not enter
Coin Pusher.

Add the smallest maintained, fail-closed Web evidence path. Prefer a dedicated
Coin Pusher plan in the existing telemetry/Web-smoke architecture over a
parallel ad-hoc server/export stack. It must deterministically install the same
300-body production fixture used by the native probe (or prove an exactly
equivalent shipped-cap fixture), enter the real cabinet, and record at minimum:

- settled idle frame p95 and surface draw p95;
- a strictly increasing Coin Pusher liveness counter during the idle sample;
- accepted DROP, carriage/hole, skill-stop, release and COLLECT action windows;
- frame and draw p95 for every action window plus synchronous resolve timing
  where the native gate owns one;
- body count, backend/platform, fixture seed, build/source commit and exact Web
  export identity;
- normal and reduced-motion behavior without treating reduced redraw as frozen
  simulation.

Use the V3 plan's binding 300-body `gl_compatibility` limits (frame p95 ≤ 16.0
ms, surface draw p95 ≤ 5.0 ms) unless a later owner-authorized committed baseline
explicitly supersedes a specific limit. Do not import unrelated broad Web-smoke
budgets as a waiver. Never report `0.000` idle draw without nonzero liveness as
green. Preserve every first result and host/browser conditions; a marginal red
is measurement evidence, not permission to raise a cap or rerun until green.

Hard boundaries: evidence tooling only. No gameplay, solver, renderer, tuning,
RTP, EV, payout, odds, wager, RNG, schema, migration, golden or performance-cap
change. Do not weaken native performance or parity gates. If the production Web
cabinet misses a binding limit, stop and route the product performance defect
with all measurements.

Run validation, focused tool/unit coverage, native performance as a nonregression,
fresh Web export/inventory checks, the new Web plan in the supported Chrome
configuration, and exact native/Web parity. Supply and hash the ignored native
addon before native timing. Commit logically, obtain independent implementation
and evidence review, and land only the accepted net payload before pusherv3_11
continues its closure decision.
