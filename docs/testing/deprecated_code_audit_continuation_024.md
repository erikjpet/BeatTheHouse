# Deprecated-code audit continuation 024

Four complete current core bodies are reviewed: AttributeBadges, CharacterOfferModel, EnvironmentHours and EnvironmentInstance, totaling 2,884 lines, 143 methods and 26 constants. Independent source review passed 1,248 checks. Recorded core coverage advances from 69 to 73 of 95; 22 core and three broader areas remain. This does not requalify the prior 69 or close the whole audit.

One obsolete candidate is confirmed: `EnvironmentInstance._numbers_layout_entries`, its sole append and comments (11 lines / 605 bytes). Historical commit `a6e3e2de8f76d789f2fe5cab4fcf898d8a9ac65f` explicitly retired the constructor to unconditional `[]`. RunState owns conditional Numbers book/Silas presence, and the instance consumes that runtime manifest. Independent review qualified the exact inverse, unchanged serialization and all other 1,246 source files.

The candidate is preserved and **not applied**. The current scope says: “The current user direction stops cleanup/removal and preserves existing files.” See [continuation 010](deprecated_code_audit_continuation_010.md). Its owned temporary edit was restored byte-for-byte before any commit or publication. All 1,247 source files match the original `d69d0897acdc1143affbabf04d0f5e36de33615b6bac77a771f962b95f68ae0c` manifest. No production code was removed in this phase.

The existing full engine-free slot-authority contract passes before and on the preserved candidate: 21 maps, 18 archetypes, 55 scenarios, four families and 767 active snapshots. Both 107,486-byte reports are byte-identical, SHA256 `e7b441efb721c84e2e0ee0321f4758d45cbcb55c0d774a4ca1e75d699568baef`. Its v2 branch validates authored data and returns before legacy GDScript source assertions; it does not execute the target. No native or player-path result is claimed.

All other reviewed code is retained. Venue access, offer sessions and scenario lifetime have distinct contracts. The badge world-map helper is a live warmup dependency; offer convenience/prepared APIs retain supported consumers. Three transient instance members and layer-copy cost remain unqualified leads.

`BTH061-AUDIT-VENUE-CHARACTER-COVERAGE-024` remains Open until its actual evidence commit is associated. `BTH061-AUDIT-NUMBERS-LAYOUT-STUB-024` records the preserved finding and scope restriction. Numeric tasks 022/023 stay exactly unchanged and Open pending separately assigned NEXT verification. Runtime inventory remains 213, with no new native jobs. Paused rows, portraits, excluded diagnostics, original files and the untracked prototype remain preserved. No files were cleared or deployment machinery operated.

Exact receipts, preserved candidate and limits are in [the machine-readable report](deprecated_code_audit_continuation_024.json). The whole audit and aggregate validation acceptance remain Open.

Manual reconciliation reports 39 historical findings in this audit scope: 38 age flags on 19 old runtime records and the preexisting 005 stale blocker. No phase024 consistency finding remains; broader backlog findings are preserved.
