# Crew actual debt-ledger revalidation

Finding `BTH-QA-CREW-DEBT-PROBE-20261116`, owner Playtest Crew ending `6afa5073-0cb4-8191-82b0-326a14a3e029`, parent `BTH-QA-CREW-ENDING-001` remains Open. Registered before fresh native audits on sourceab7abfb7c9f898ba500dc2361db3f14640911964.

Confirmed QA harness defect: to_save_snapshot exposes singular debt array, while eleven helpers queried absent debts with empty fallback. Original emitted checks and non-debt findings remain unchanged; their debt absence/persistence qualification is withdrawn pending actual-ledger audits. No product debt loss or regression established.

Independent source review confirms `run_state.gd:15814` writes singular top-level `debt`; `debts` is absent. The former fallback always returned an empty dictionary even when a real monetary marker existed. Thus original debt-absence predicates and debt-persistence equality fields do not establish those properties. Their raw emitted totals and other actual observations remain valid as recorded, and all logs stay immutable. Current Nico creation was explicitly checked against actual run_state.debt; later persistence is now independently rechecked.

The ordinary bounded batch has been reopened for this debt-specific qualification, preserving its965e2398 proof commit and all unrelated acceptance. No loan, handoff, refusal, collection settlement or NewRun action will be replayed. Full arrays, including Collector-ineligible monetary entries, are compared; zero cases require truly empty arrays. Future reports use debt_entries to distinguish corrected observations from the old unknown proxy.

<!-- actual-debt-ledger-revalidation -->

## Corrected actual native observations

All12 fresh bounded Jobs passed10/10 each, **120/120**. Every case loaded an isolated complete three-directory copy with official cold Continue and normal Save/Continue. No loan, handoff, refusal, collection settlement or NewRun action was replayed. Each confirms singular snapshot.debt equals the complete actual RunState.debt array and that plural debts is absent. Full debt arrays are deep-copied, stably ordered, never filtered through Collector eligibility. Exact wallet/RNG/jobs/delivery/heist/duties and only bounded ordinary clock progression persist; private/room authority remains valid. Original input profiles remain unchanged.

| Case | Input checkpoint | Cash / Crew duties | Actual debt | Worker SHA-256 |
| --- | --- | --- | --- | --- |
| crew-sidebar-da01-261116 | crew-sidebar-terms-progress-20261116-01 | 162/2 | empty full array | `32f2a78f4215b366cc15df9ede106271bdf7ba6f87cd32c7024c6cc616666334` |
| crew-sidebar-da02-261116 | crew-sidebar-od10-261116 | 162/2 | empty full array | `7f1f4b6b3218d8322fe1a8251c41a85939f4a4b87928b30b02e2bb642b669855` |
| crew-sidebar-da03-261116 | crew-sidebar-od15-261116 | 177/1 | empty full array | `e9b21397ec76808c25db4bf28118dcd0eaadd2ea5078886ad5903f614cc426cf` |
| crew-sidebar-da04-261116 | crew-sidebar-od21-261116 | 192/0 | empty full array | `ba6fd59fc94ae0c1e1bf880c66fb4d5f420a820d64d6b55d9ccd82b0a239a784` |
| crew-sidebar-da05-261116 | crew-sidebar-om5-261116 | 162/2 | empty full array | `2f5b21ce44fd3d95a24ae364bf960f51e8a07a5be9708ad348c2a088aca1eb35` |
| crew-sidebar-da06-261116 | crew-sidebar-cc11-261116 | 163/2 | empty full array | `3b0f4e82906fce71b80296a17c898abd56cbacbd879894eb6756da785c7cf6a4` |
| crew-sidebar-da07-261116 | crew-sidebar-cc13-261116 | 185/2 | empty full array | `c30f63efb03f6ce4a35c019a12f2c31753600564db05f3a2075387bfc40c1252` |
| crew-sidebar-da08-261116 | crew-sidebar-cc15-261116 | 201/2 | empty full array | `39cfa230e49fe60432914282c1cb3e1a21174bd7cf83d2c29e0077121ea57f59` |
| crew-sidebar-da09-261116 | crew-sidebar-gf10-261116 | 100/0 | empty full array | `b04228dfb50a4826fe27db8e5812645200e4a1ae6d74ccc067a92e4c5bdc91b0` |
| crew-sidebar-da10-261116 | crew-sidebar-cw8-261116 | 196/2 | Nico principal20 / balance22 / active cash / four turns | `545bcfda81a0d88934eca307affd36b859a1eddce819905b63cacd1c7ad372bb` |
| crew-sidebar-da11-261116 | crew-sidebar-cw9-261116 | 187/2 | Nico principal20 / balance22 / active cash / four turns | `cd4fc91c4d51c9cb114304d4cc7cf12265ff886ddc833658014b7299035d03f8` |
| crew-sidebar-da12-261116 | crew-sidebar-cw4-261116 | 185/2 | empty full array | `5fb994db8ce98d152edea2a8afe1fe0adf3b7604a767a8c8eb6c9b0f902adf5b` |

This independently establishes actual empty ledgers at the audited post-Crew-borrow, accepted ordinary package, first/second completion, missed/refused, collection pending/friendly/pressed, NewRun and pre-Nico Court boundaries. Nico positive controls retain the real monetary note after creation and cold return. No product debt-loss bug is established. It does not retroactively turn the original bad predicates into meaningful checks or certify unaudited intermediate/historical states. Original253/111/etc totals remain raw emitted counts; debt-specific support comes from these explicit120 corrected checks. Historical Count/getaway signatures using the same bad field remain debt-unqualified outside the audited NewRun boundary.

The actual corrected verifier is retained verbatim beside each worker log as resume.gd; fixed LF-source SHA72cc74c1b75dc054f47298d4988b607bcfc0ccb936e888bcdf4ee1a05e8c7e36. Adapter CRLF copies are byte-identical to each other; only line endings differ from the source. No authored saves or original evidence was repaired or overwritten.
