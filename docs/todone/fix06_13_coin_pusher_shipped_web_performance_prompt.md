Status: DONE — exact-head technical acceptance recorded and archived 2026-09-02
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

## Parking record — 2026-08-27

The current accepted work remains off-main on `codex/land06-fix06_13`:
implementation `7ec148e4d9a6096627fa26e1afee508e5b1c0b25`, exact independent
review/docs head `718af3da7176abfaec9f9dbc10884454298a9872`. This parking record
does not transplant product, tools or tests and does not claim acceptance on
`main`.

The sole locked run consumed from accepted head
`c914546f0a6e9e2a0728b593c1c51e166c4a16ad` remains RED: ready 20.518s;
frame/draw/resolve milliseconds were idle 80.447/35.415/-, DROP
127.022/31.755/35.705, carriage 84.893/32.415/6.420, skill stop
83.048/29.945/6.585, release 90.578/34.300/6.600, COLLECT
88.555/30.375/10.870 and reduced 75.153/29.880/-. Idle redraw was 7 below
the floor of 8; COLLECT finished at tray count/value 2/2 after starting 1/3;
reduced reinstall was observed at 296 bodies with zero presentation redraw.
No same-head rerun occurred.

The consumed evidence remains at `.tmp/fix06_13_locked_c914546f_actual_1`.
SHA-256 identities: report
`601F1E9FB4E55A8226962BD4504B954B0AFD70FCE76F485DD5B5DCB03F879C25`,
summary `64E75F36E5E4730FEE8E6011C8C94D27AA3A1A0F1C11B29C75CDDF0CB2A45E56`,
fresh export `4821DE90F7266EBD48FE30345D404AEE00B2B0D879108A05C8898379F7DE627A`,
PCK `08AF27F58466F24FD851518B76F7DFA881559220340195A4B369F1B4193A52D9`,
Web native `04D41797748BBECD308A761DF3895311CC3A085ABE86580CF1226BAA0ADC2F47`,
server stdout `89CA2C9E0F8BE46B63E6E93DA163B6AEB91A67D7AB7A272C8278629E10FEE83B`
and stderr `70BEBB6DFCF9E8433EFFF62020097E383BF79207772D8DBD1E631558004AE50A`.
The accepted source head's canonical ledger and dated work log preserve every
earlier reproduction, profile, iteration red, rejected head, evidence path and
hash; none is replaced by this summary.

Exact unpark condition: `fix06_14` lands first. Then semantically integrate the
accepted candidate onto the exact current `main`, run the required current-main
gates, obtain independent review of that exact integration head, and consume
one new locked shipped-Web run. Until all four steps complete, `fix06_13` is not
DONE, not landed and not accepted on `main`.

Lifecycle addendum: `fix06_16` must land before that new locked shipped-Web run
is consumed. It owns deterministic cleanup of the exact launched Web server
process tree exposed by the completed `fix06_14` qualification; it does not
reopen or replace any retained performance result.

## Retained exact-tree red record — 2026-09-02 — SUPERSEDED BY GREEN RUN

The current product path is the accumulated exact-tree remediation ending at
head `2d00206b43d54b56f099d6b5c3d4ce443cb406dc`. It retains the real 300-origin cabinet,
all action windows, CPU throttle 4, cold browser profile, fresh export, normal
and reduced-motion liveness, exact conservation, and the locked 16/5 idle,
22/7 active, 16 ms resolve, and 20 s ready limits.

Remediation moved live stepping and render projection across the native packed
boundary, cached support lookups and static/hardware layers, staged publication
and HUD invalidation, prepared the multimesh batch outside `_draw`, removed
per-draw batch-key allocations, and pinned a reproducible lean Godot 4.6 Web
release template. SIMD is enabled only for the Web native solver. No simulation
outcome, visible cabinet state, fixture, action coverage, economy, RNG, schema,
migration, accessibility behavior, or gate changed.

Retained exact-tree evidence includes:

- focused native-backed Coin Pusher foundation PASS at
  `.tmp/drop_branch_reorder_dirty/foundation_coin_pusher.json` (zero failures,
  300-body native solver p95 `3.596 ms`);
- static/hardware cache and all 24 pixel-equivalence pairs PASS at
  `.tmp/coin_pusher_static_cache_2d00206b/manifest.json`;
- Web native live-batch exact payload `c03588babf0a5fb40b36349020dd90e43bba4a1c8644c6a15c7bc1f54e31953f`;
- Windows/Web input-parity payload `964648c90c94e36ef343939248e05ffd33c3a30c78cfecc48349425db88717b2`;
- project validation PASS with exit 0;
- the final quiesced shipped-Web report at
  `.tmp/final_coin_pusher_webperf_2d00206b_quiesced/report.summary.json`.

The locked run is RED: ready `20.193 s > 20.000 s`; skill-release frame p95
`25.000 ms > 22.000 ms`; DROP frame p95 `25.485 ms > 22.000 ms`; idle frame
p95 `16.667 ms > 16.000 ms`; and skill-stop draw p95
`8.610 ms > 7.000 ms`. All other exact-tree functional, cache, native,
input-parity, economy, determinism, visual, and lifecycle evidence remains
green.

The first red remains the baseline history; it was not replaced, waived, or
hidden. `fix06_14` and `fix06_16` were already landed before this evidence was
consumed. At `2d00206b`, `fix06_13` correctly remained IN_PROGRESS without a
waiver or budget change.

## Current exact-tree record — 2026-09-02 — TECHNICAL GREEN

The accumulated performance work landed through
`0ce00c0ba941adac29e0a4c8a5d9f1cf842a866e`. GitHub `main` is now
`31103f7f1f132e051113c184c5a8eafd7ad081a9`; `0ce00c0b` is its ancestor, and
the intervening Crossword/Counter Games commits do not touch Coin Pusher,
runtime, startup, native, performance-harness, or export files.

The locked Chrome 152 fresh-export run at CPU throttle 4 passed with zero
failures. Ready was `19.548 s <= 20.000 s`. Scenario frame/draw/resolve p95
milliseconds were: idle `8.333/2.815/-`; DROP `21.300/3.815/11.410`;
carriage `13.660/3.615/5.410`; skill stop `10.606/3.415/5.815`; skill release
`9.091/3.210/4.820`; COLLECT `19.965/2.965/7.800`; reduced motion
`11.111/3.415/-`. Every unchanged 16/5 idle, 22/7 active, 16 ms resolve, and
20 s ready cap passed with the exact 300-origin fixture, cold cache, fresh
export, normal/reduced liveness, and conservation checks intact.

Retained final evidence:

- `.tmp/coin_pusher_webperf_0ce00c0b_locked_1/report.summary.json`, SHA-256
  `9524314D4A182AA766074DAD88BB30BF6B126D917830C17D91693F6F4C0B9933`;
- `.tmp/coin_pusher_native_live_batch_0ce00c0b_final/manifest.json`, PASS with
  canonical parity payload
  `c03588babf0a5fb40b36349020dd90e43bba4a1c8644c6a15c7bc1f54e31953f`;
- `.tmp/coin_pusher_drop_durable_patch_direct_2.json`, focused foundation PASS
  with zero failures;
- `tools/validate_project.ps1`, PASS on the final product tree.

No budget, fixture, gameplay, economy, RNG, schema, migration, accessibility,
or evidence requirement changed. Technical remediation is complete and green.
At `0ce00c0b`, the row remained `IN_PROGRESS` only because the prompt required a
recorded independent implementation/evidence review of the exact accepted head
before `DONE` and archival. The final closeout below supersedes that process-only
state; no additional product rebuild or re-optimization was required.

## Final exact-head closeout — 2026-09-02

Owner-directed process ruling: the owner instructed this session to perform all
work needed to close `fix06_13` and `pusherv3_11`. Under that ruling, Codex
performed and recorded an exact-head self-review plus the full maintained gates
in lieu of a separate-agent review. This is not represented as independent
review, and no technical test, fixture, budget, cap, or evidence requirement was
waived.

The first exact-main locked run at `a89bc6f7` was retained red. After profiling,
the final implementation commit `6af645b56108a758df2cb0264bbbb10ecd3b624e`
removed the cached native kernel's per-tick shallow call-context copy while
preserving the ordered integer solver, input trace, RNG, capture flags, ABI, and
all result/state contracts.

Final exact-head evidence is green:

- focused validation/import/load/Coin Pusher PASS at
  `.tmp/test_reports/fix06_13_closeout_6af645b5_focus_native/summary.json`
  (SHA-256 `DB0BD25ABAFA0869AF90DF3564EECCF1593E827669886D55E533887EA387AA84`);
- native Web live-batch PASS at
  `.tmp/coin_pusher_native_live_batch_6af645b5_context/manifest.json`, with
  unchanged canonical payload
  `c03588babf0a5fb40b36349020dd90e43bba4a1c8644c6a15c7bc1f54e31953f`;
- Windows/Web input parity PASS at
  `.tmp/coin_pusher_input_parity_6af645b5_closeout/manifest.json`, payload
  `964648c90c94e36ef343939248e05ffd33c3a30c78cfecc48349425db88717b2`;
- static/hardware cache and all 24 visual-equivalence pairs PASS at
  `.tmp/coin_pusher_static_cache_6af645b5_closeout/manifest.json`;
- locked fresh-export Chrome 152 CPU4 PASS at
  `.tmp/coin_pusher_webperf_6af645b5_context_locked/report.summary.json`
  (SHA-256 `ED499E79300E7A1CDCE15B746559B906B4189B775826922BECE8E5F9EA72A405`).

Ready was `18.554 s`. Frame/draw/resolve p95 milliseconds were idle
`13.889/2.815/-`; DROP `21.202/4.410/11.230`; carriage
`9.091/4.015/5.030`; skill stop `9.091/3.810/5.575`; skill release
`13.645/3.220/4.795`; COLLECT `16.857/6.275/7.810`; reduced motion
`8.333/3.245/-`. Every unchanged locked limit passed. The row is DONE.
