# Four current core review gaps

The complete current bodies of four files are reviewed and retained: 943 lines, 50 methods and 18 constants. Independent peer review passed 85 checks with no blockers. No obsolete removal candidate or supported production fix was found. Four recorded body-review gaps are closed with the associated evidence commit below; the whole deprecated-code audit remains Open. The [JSON report](deprecated_code_audit_continuation_021.json) pins the source and evidence.

| Current file | Methods | Constants | Disposition |
| --- | ---: | ---: | --- |
| keys.gd | 0 | 4 | All constants are used through KeysScript aliases in live result and persistence paths. Retain. |
| run_money_flow_archive.gd | 9 | 1 | Compaction, saved prefix custody and report/UI summaries are active. Retain. |
| run_terminal_evaluator.gd | 23 | 2 | Detailed diagnostics and terminal-only decisions have distinct consumers. Retain. |
| storage_numeric_json.gd | 18 | 11 | Current save and UI storage need its numeric and marker compatibility. Retain. |

The terminal evaluator's 21 unchanged historical methods and two current paid-asset/liquidity deltas were read in full. Foundation uses the terminal-only apply boundary; metrics, seed audits and sweeps use detailed diagnostics. Every method is reachable through the explicit call graph. The conditioned Side Door helper is also active: it supplies the current player/room context that the generic choice scan lacks, allowing a recoverable club room to remain live. Nested travel_changes remains an accepted compatibility API even though current authored event choices do not use that nested spelling; zero occurrences do not establish obsolescence.

The money archive preserves the distinction between an unknown historical prefix and later known rows. It is consumed by story compaction, save/schema and reporting paths. Its current recorded DTO inputs justify retention; arbitrary Object stringification purity is not established or needed for this disposition. All four Keys constants have actual consumers through preload aliases. Earlier historical alias removals are preserved; no keys were restored or removed here.

Numeric storage's parse and stringify are separate active public roots. The source review covers exact-number restoration, signed zero, marker collisions, engine-owned JSON structure/grammar and bounded local limb/power/cache helpers. Six existing focused test sources and 555 numerical vectors were inspected as source controls. Those vectors were not executed in this phase, and no new native numerical or functional PASS is claimed.

The three unchanged read-only source contracts for health hot paths, correctness and IoResult/Keys passed. No new native Job, source instrumentation, production edit or performance measurement occurred. All 1,247 expected source hashes remain at fd2c64d5; the 200-record runtime inventory is unchanged.

Task BTH061-AUDIT-CORE-DELTA-COVERAGE-021 is Complete with associated evidence commit `92483c02f246f70e6bb8e01739e3df0da8b584ce`. The umbrella's recorded core body dispositions move from 61 reviewed / 34 unreviewed (33 remaining and 1 unknown) to 65 reviewed / 30 unreviewed (30 remaining and 0 unknown). This does not requalify the previous 61 reviews. Three broader recorded areas and the original aggregate acceptance remain Open.

Evidence-only graph, span and purity-wording corrections are retained with their earlier receipts. The final peer review binds the corrected versions. No excluded diagnostic, callback experiment or partial was accessed or executed; paused implementation, portrait behavior, prototypes and the unpublished 1f24 test are preserved. No files were cleared. Prior Crew delivery/NEXT requirements and all aggregate guards remain unchanged.

Precommit current/all reconciliation reports zero findings in this worker scope. Outside findings remain reported: 190 current / 806 total, including 135 outside runtime errors. Outside records were not changed.
