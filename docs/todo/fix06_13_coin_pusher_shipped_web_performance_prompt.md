Status: TODO
Board row: `fix06_13` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_13: Coin Pusher shipped-Web performance defect

Work in `D:\Projects\Beat-The-House` from the exact current `main` after the
accepted `fix06_9` evidence payload lands. This is the product-performance row
routed from the first honest shipped-cap Web measurement. Read the current
landing contract, `fix06_9` prompt and evidence handoff, the V3 machine plan,
the native performance probe, the Web probe/telemetry path, renderer, live
session and solver API before editing.

## Retained first red — do not replace or hide it

The first actual run measured source `54e6398a151d0e9a095ebba5ae99d17a7d99f5e9`
on `DESKTOP-1950ULQ`, Chrome `151.0.7922.174`, headless, 1280x720 at DPR 1,
CPU throttle 4, cold profile, fresh Web export, single-threaded Web native
solver. Export aggregate SHA-256 was
`0EB384022F02D3889EBD2B022F959E3F4223310B901BF21A101501934D29E2F6`.
The raw report is retained at
`.tmp/fix06_9_runtime_54e6398a/web_coin_pusher_first_actual.json` (SHA-256
`F0E0E9B5D3644F7F46EF2AF765130150BA65966A7585FBBE875B7347E389F715`)
and its summary alongside it (SHA-256
`C37473DAE93DF456E0DACC25E65AB6C3A3F2CD3757CBC2E3454E8D315C7AAC88`).

Every completed shipped-Web scenario was materially red:

| Scenario | frame p95 | locked cap | draw p95 | locked cap | sync resolve | locked cap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| settled idle | 144.142 ms | 16.000 ms | 53.865 ms | 5.000 ms | — | — |
| DROP | 144.035 ms | 22.000 ms | 54.550 ms | 7.000 ms | 68.300 ms | 16.000 ms |
| carriage/hole | 142.143 ms | 22.000 ms | 52.380 ms | 7.000 ms | 45.390 ms | 16.000 ms |
| skill stop | 145.250 ms | 22.000 ms | 52.400 ms | 7.000 ms | 91.355 ms | 16.000 ms |
| skill release | 142.577 ms | 22.000 ms | 53.080 ms | 7.000 ms | 54.985 ms | 16.000 ms |

Web ready was also 20,536 ms against 20,000 ms. COLLECT and reduced-motion did
not execute because `fix06_9` had two evidence defects; those are remediated in
the evidence row and do not invalidate the completed scenarios above. The same
tree's maintained native 300-body probe was green, including native backend
identity, so this is a shipped-Web-specific product/performance defect, not
permission to weaken the gate.

## Required work

1. Reproduce once with the accepted fail-closed `fix06_9` harness on an
   otherwise idle host, preserving every result and exact export identity.
2. Profile the real exported Quarter Falls cabinet at the exact 300-origin
   fixture. Attribute frame, surface-draw and synchronous-action costs across
   renderer, live-session stepping, Web native boundary and host refresh.
3. Implement the smallest product optimization that clears the locked limits
   without changing visible semantics, simulation results or evidence fidelity.
4. Prove normal and reduced-motion simulation liveness, all five accepted action
   windows, exact fixture conservation, fresh-export identity and native/Web
   input-trace parity.
5. Run validation, focused Coin Pusher, native performance nonregression, fresh
   Web shipped-cap evidence, 10-seed determinism, exact parity, Contract and
   Smoke. Preserve the first post-fix result even if red.

## Locked boundaries

- Do not raise, scale, reinterpret or waive the 16/5 idle, 22/7 active or 16 ms
  synchronous-action caps. Do not rerun until green or discard slow results.
- No RTP, EV, payout, odds, wager math, RNG stream, machine geometry/tuning,
  economy, schema, migration, gameplay, solver-outcome or accessibility change.
- Do not reduce the 300-origin fixture, sample lengths, action coverage,
  liveness requirements, browser CPU throttle or fresh-export requirement.
- Do not hide work with reduced motion, skip rendering, cache stale state, use
  a synthetic canvas, or bypass the real production action/cabinet path.
- If a compliant fix requires a locked-design or tuning choice, park this row
  with the exact decision needed and continue the landing program.

Commit logically, self-review the complete diff, obtain independent
implementation and evidence review, and land only after exact-head and
post-land gates are green.
