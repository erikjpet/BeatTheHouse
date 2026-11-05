# Deprecated-code audit continuation 022

Four remaining core files now have complete current-body and consumer dispositions: `grand_casino_duel_model.gd`, `run_state_schema.gd`, `run_save_codec.gd`, and `save_service.gd`. The original review covers 1,540 lines, 79 methods, 48 constants, 73 schema fields and 12 state fields; independent review checked 131 conditions. All declarations remain active or necessary compatibility. No removal is justified.

The duel review found that a clipped callout settled the correct chips but returned/logged the requested amount. The two-line repair follows the existing `apply_hand` convention and reports actual player-stack movement. The same regression script ran 119 checks: four receipt failures before the fix, zero afterward. All settlement, conservation, input ownership, RNG, schedule, terminal and repeat controls pass. Source commit: `c9449ddd52ca28c1d986661b9f09f61937cafc6c`. Independent native review checked 45 conditions on the initial candidate and 46 on the final merged source. Final merged-source native checks also pass 119/0 at `40d4ac78e7ee695b08e0e6e1eb5904e0152c397e`; the tested source is published on main at that exact merge. The task remains Open for separately assigned NEXT verification.

Two Codec comparison defects are reproduced with ordinary synthetic DTOs through public encode/pack/unpack/decode APIs: same-ID environment reuse loses negative-zero bits, and a seeded supplied integer restores as the catalog's numerically equal float. The maintained original 24 checks pass in both functional baselines. Expanded compatibility controls and bounded cost remain under review before adopting a Codec repair. No player-save, RunState schema, mounted-room or UI incidence is claimed.

| Owned native job | Actual result | Disposition |
| --- | --- | --- |
| Duel old source | 119 checks, 4 receipt failures | Qualified reproduction |
| Codec signed zero | 32 checks, 1 new failure | Qualified reproduction |
| Codec scalar type R1 | Private test parse error | Preserved; excluded from functional evidence |
| Codec scalar type R2 | 29 checks, 1 new failure | Explicit-Boolean test correction; qualified reproduction |
| Duel candidate R2 | Same 119 checks, 0 failures | Scoped repair passes |
| Duel merged source R3 | Same 119 checks, 0 failures | Final source independently qualified and published |

All six jobs ran serially through unchanged `run_stage006.py`: 180 seconds, 12% aggregate CPU, 2 GiB, assignment before execution, kill-on-close and no breakaway. Each owned Job closed with zero processes; runtime inventory 200 -> 206 preserves every earlier record. All three functional unchanged-source baselines closed before the first repair. Failed parser artifacts remain preserved.

The remaining recorded core body gaps decrease from 30 to 26; 69 of 95 core areas now have recorded reviewed dispositions. This phase does not requalify the prior 65. Including three broader gaps, 29 recorded areas remain. The umbrella, compatibility and aggregate validation acceptance stay Open.

Main advanced with Coin Pusher commit `eebb8aa13957ea3ef705095cb1b7589a0592a646` before publication. Its two disjoint files were integrated at `40d4ac78e7ee695b08e0e6e1eb5904e0152c397e`; all unfinished audit files were preserved. Fresh merged-source admission and the same duel regression run passed: 119 checks, zero failures, exit 0, exact resource guards and closure 0. Independent final review passed, and the normal push was verified at exact remote main `40d4ac78e7ee695b08e0e6e1eb5904e0152c397e`. The Codec source remains unchanged.

Stable IDs are `BTH061-AUDIT-STORAGE-DUEL-COVERAGE-022`, `BTH061-AUDIT-DUEL-CALLOUT-RECEIPT-022`, and `BTH061-AUDIT-CODEC-SIGNED-ZERO-022`. The body-review child remains Open until its evidence commit is associated. No task is closed by this draft. Manual reconciliation currently reports one preexisting stale audit blocker: task005's historical machine-global-census observation crossed its age limit. Its original evidence is preserved; fresh unchanged qualification remains required. Outside-runtime errors are retained and do not become new observations here. Paused item/scenario objectives, portraits, excluded diagnostics and partials, all guards, personal saves and the untracked memo prototype remain untouched. No files were cleared and no NEXT machinery was operated.

Exact source pins, receipts, limits and subsequent commit associations are in [the machine-readable record](deprecated_code_audit_continuation_022.json).
