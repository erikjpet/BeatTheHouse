# Deprecated-code audit continuation 026

Two ritual contract bugs are corrected locally in `fbd95aae983f6e99c4431b31d830f550bd993e3d`. The same ordinary public DTO test runs 181 checks: 44 failures before, zero after. Thirty complete observations remain byte-identical; exactly 14 targeted observations change. Original fixture state/projection hashes, five valid boundary IDs, six prior invalid cases, legacy/missing anchor behavior and both existing game-definition error records remain unchanged.

The four production-line changes preserve empty dot atoms in Runtime/Schema identifier checks and prefer canonical `anchor_id`, then legacy `anchor`, then previous state for positions. The new maintained regression uses only public Schema.validate_definition and Runtime.configure with ordinary authored dictionaries. It never issues commands or calls host/checkpoint/restore/callback/private-key paths. The currently authored Bar Dice/Showdown definitions have preexisting schema errors; those are retained, not treated as healthy controls or silently repaired.

The room-publication numeric finding was a false positive for its scoped integer fields. Public generated-room checks pass38/38, rejecting both type-only changes consistently with full validation. Five primitive controls confirm scalar1==1.0 is true while flat and nested dictionary integer/float comparisons are false. The earlier conditional hypothesis conflated those operators. RoomPresentationPublication is retained unchanged; counter/all-cache/player behavior is not certified.

Two further complete core bodies are reviewed: CollectionDropService and CollectionItemResolver, 1,174 lines, 58 methods, 35 constants and nine fields. All102declaration hashes and retention dispositions are independently checked. Recorded coverage is79/95core, with16core and three broader areas remaining. Prior complete-body evidence plus the exact qualified ritual delta is reused without counting those edited files as new areas.

A conditional terminal meta persistence/retry lead is tracked separately. Flags are set before meta saving, with no local failure retry; independent checkpoint and later meta saves complicate actual loss/recovery. No runtime loss, duplication or Continue bug is demonstrated, and no collection/item/scenario feature code was changed.

Five serial owned Jobs are preserved, including the publication-test R3 parser stop. Its explicit Boolean annotation repair is test-only, and R4passes38checks. All five Jobs closed0 under unchanged180seconds/12%CPU/2GiB, assigned-before-execution, kill-on-close and no-breakaway. Runtime inventory is213to218 with the original213records unchanged. Source count1248 and tested manifest`0407d40006a4e2ddff84a461814d717a7798e95d9facb2bc03fd95796c1e794d` include only two changed production files and one new test.

The two corrective tasks remain Open for required NEXT. The bounded181-check child has actual local source commit association. Collection coverage and scoped publication retention are Complete with actual evidence commit `711c3b7dea800d5efd5ec00ed80b323a2a784281` associated. The conditional terminal meta lead remains Open with source evidence only. The whole audit and aggregate acceptance remain Open. Paused rows, earlier numeric NEXT tasks, prototype, portraits, excluded diagnostics, originals and denied-publication status remain preserved. No cleanup, publication retry, import, build or export was performed.

[Exact source, original failures, native guard evidence and limits](deprecated_code_audit_continuation_026.json).

Manual reconciliation records 109 older audit findings (108 age flags and the preexisting005stale blocker), with no phase026 consistency error. Earlier observations remain unchanged.
