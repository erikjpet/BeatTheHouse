# Deprecated-code audit continuation 025

Four further current core bodies are fully reviewed: CrewDeliverySchedule, ScenarioVenueCycle, RoomPresentationPublication and GameRitualRuntime. The scope is 1,752 lines, 113 methods, 25 constants and 19 fields. Recorded core coverage advances from 73 to 77 of 95; 18 core and three broader areas remain. Prior 73 reviewed areas are not requalified here, and the whole audit stays Open.

All source is retained. Production games and UI use the ritual runtime's static canonical helpers. The instance executor/host remains maintained contract functionality; its fail-closed compatibility wrappers are not active mutation authority. Delivery appointments, shared-clock gates, one-time legacy migration and scenario-cycle retirement/attachment have current owners and consumers.

Three follow-ups remain Open:

- `BTH061-AUDIT-RITUAL-ID-GRAMMAR-025`: runtime/schema ID helpers discard empty dot atoms, contradicting the frozen grammar and PowerShell validator. This is a source-contract discrepancy, with runtime impact unqualified.
- `BTH061-AUDIT-RITUAL-ANCHOR-ARGUMENT-025`: instance position operations read `anchor`, while the frozen contract requires `anchor_id`. Current three inspected ritual definitions contain no such operation; no authored failure is demonstrated.
- `BTH061-AUDIT-PUBLICATION-NUMERIC-IDENTITY-025`: room proof reuse uses value dictionary equality while full validation requires native integer manifest fields. The conditional type-change case needs a retained nested live alias; current canonical producers normalize integers and root assignment invalidates publication. No runtime or gameplay failure is claimed.

Write-only publication metadata, broader surface/failure-return questions, ritual restore shape and hypothetical short venue closures remain explicitly unqualified leads. Cleanup remains stopped and no source changes, runtime tests, native jobs, imports, builds, exports or publication attempts occurred. The denied phase024 push was not retried or rerouted. Its commits and task status, numeric022/023 NEXT status, paused eight rows, excluded diagnostics and prototype remain exact.

The 1,247-file source manifest remains `d69d0897acdc1143affbabf04d0f5e36de33615b6bac77a771f962b95f68ae0c`; runtime inventory remains 213. The bounded body-review and metadata-inventory children are Complete with associated local evidence commit `f99792e9dc35c28db3f378a095eb4f4196c25005`. Findings, whole-audit and aggregate acceptance stay Open. [Exact receipts and limits](deprecated_code_audit_continuation_025.json).

A separate metadata-only pass inventories all 4,139 tracked paths at local HEAD104da425; every path/blob and 16,556 classification fields reconcile independently. It identifies 1,031 source-looking paths, with 809 outside the initial95core/127UI-game reference areas. These counts do not establish that those files are unreviewed, shipped, unused or obsolete. Current UI/game has129 .gd files: the old graph omitted slot_bonus_recovery.gd and web_save_durability_bridge.gd. Existing semantic evidence still needs reconciliation. Ignored/generated/outside-repo files and untracked artifacts are excluded explicitly. This evidence commit will add only two report-doc paths after that snapshot.

Manual reconciliation snapshot: 73 historical audit findings remain (72 runtime age flags plus the preexisting005stale blocker); no new phase025 consistency finding. Earlier timestamps are retained.

The committed tree now has4,141 tracked paths: the snapshot plus only two new phase025 report documents. Source files are unchanged. All three source/conditional findings remain Open; their associated commit records evidence, not a corrective implementation.
