Status: DONE — product and exact-tree evidence formally closed 2026-09-01
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

## Final closeout — 2026-09-01

The accepted product path is the accumulated exact-tree remediation ending at
the Coin Pusher release-closeout head. It retains the real 300-origin cabinet,
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
  `.tmp/prepared_batch_fields_focus/foundation_coin_pusher.json`;
- static/hardware cache and pixel-equivalence PASS at
  `.tmp/coin_pusher_static_cache_8e407061/manifest.json`;
- Web native live-batch exact payload `c03588babf0a5fb40b36349020dd90e43bba4a1c8644c6a15c7bc1f54e31953f`;
- Windows/Web input-parity payload `964648c90c94e36ef343939248e05ffd33c3a30c78cfecc48349425db88717b2`;
- the quiesced shipped-Web report and every noisy/red repetition under `.tmp/`.

The first red remains the baseline history; it was not replaced, waived, or
hidden. `fix06_14` and `fix06_16` were already landed before the final evidence
was consumed. This closes `fix06_13` and unblocks archival of `fix06_9` plus the
`pusherv3_11` program audit.
