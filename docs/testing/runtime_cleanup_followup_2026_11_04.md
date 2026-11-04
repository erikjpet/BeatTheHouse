# Historical cleanup follow-through

Stable objective: `BTH-RUNTIME-CLEANUP-001`. Status: **Open**.

The source cleanup worker reports reviewing all ten historical gaps remaining
after the first audit using existing lifecycle receipts and task history. Five
have matching historical cleanup or known-owned-set absence reports. Five still
lack sufficient closure evidence. None establishes a currently running abandoned
instance, and no instance was stopped by this metadata integration.

| Historical run | Follow-up outcome |
| --- | --- |
| General160 | Matching report accounts for all 12 captured owned IDs as absent. |
| General183 | Matching interruption report accounts for all 10 captured owned IDs as absent. |
| General210 | Matching interruption report accounts for all 11 captured owned IDs as absent. |
| Debug runtime-resolution | Exact-run reconnection report matches the final 13-ID sample and records none remaining. |
| Debug runtime-rourke-explore-kg | Exact-run recovery report after the final sample records zero remaining owned processes; normal completion is unproven. |
| Crew Alley019 | Open: matching owner release report found, but its filtered inventory does not independently cover Chromium descendants. |
| Grand ordinary07 | Open: historical check covers three of twelve captured IDs; the full owned set is unproven. |
| Grand ordinary08 | Open: full captured set returned zero matches, but suppressed process errors prevent distinguishing absence from access or other failures. |
| Grand Rourke13 | Open: full captured set returned zero matches with the same suppressed-error limit. |
| Grand Rourke25 | Open: full captured set reported zero matches with the same suppressed-error limit. |

These are historical observations only. They do not establish normal browser
exit, all unrecorded descendants, current process identity, or current desktop-wide
absence. The prior denied certificate-warning tab cleanup also remains uncertain.
No historical process command was replayed, and no alternative desktop inspection
route was used. Active testing, retained profiles and saves, shared preview and
NEXT services were preserved.

The source audit reported 1,839 lifecycle receipts, including 1,823 with a recorded
zero-process release. Its follow-up reports eleven of the sixteen incomplete
final receipts having matching historical reconciliation evidence, including
these five additions. Five historical closure gaps remain open. Detailed local
evidence retains each run identity, receipt path/hash, source turn or command ID,
timestamp and limitation. This integration did not independently repeat that
receipt audit.

This follow-up changes only runtime documentation and snapshot metadata. The
existing manual checker, required-runtime policy, report-output safety and
readable-ledger drift checks remain in place. The active snapshot contains eleven
explicit records. The [initial sixteen-record snapshot](../todo/bth_runtime_inventory_initial_20261104.json)
retains the original evidence and the five historically reconciled records;
surviving records retain their earlier evidence paths alongside new review
references. Receipt and process/activity observation timestamps were preserved;
later owner-review timestamps are separate metadata. No background watcher,
recurring task or cleanup action is introduced.

The source worker reported 63 focused tests in its branch; the integrated checker
baseline is the separate 62-test suite documented in the earlier audit. Metadata
validation checks the actual snapshot schema, five Unknown closure states,
preserved provenance/timestamps and the expected nonzero reconciliation result.
Source patch: `dc800d1256a5c9337b85d43ec6f9bb521f9be553`. The implementation commit
and local checks do not close this objective or prove canonical publication.
