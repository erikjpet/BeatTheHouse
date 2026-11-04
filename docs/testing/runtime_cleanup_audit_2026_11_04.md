# Task instance cleanup audit

Stable ID: `BTH-RUNTIME-CLEANUP-001`. Status: **Open**.

The source worker's scoped audit reported reading 1,839 known task lifecycle
receipts. Of those, it reported 1,823 recording zero owned processes at release,
and six of the remaining sixteen having matching interruption reconciliation
records showing zero owned processes at their historical timestamps. Ten old
runs still lacked complete cleanup evidence. These are historical evidence gaps;
none establishes an abandoned process currently running. Integration provenance
is source patch commit `de3f27930a0ddec47f835eff64963cd7eef3417f`. This integration
reviewed that patch and tested its checker; it did not independently reread the
local receipts or inventory the current desktop.

Later [historical follow-up](runtime_cleanup_followup_2026_11_04.md) and
[owner-review verification](runtime_cleanup_verification_2026_11_04.md) retain five
Unknown historical job closures, with the separate warning-tab outcome still
uncertain. The current explicit list contains eleven records; the initial
sixteen-record snapshot is archived with its original evidence. Those later
reviews do not establish present running, clean closure or completed cleanup.

The source worker reported zero-process release receipts for General, Crew,
Grand and performance runs, including failed runs. It reported preserving task
activity, retained testing profiles, the intended site preview and NEXT watcher.
Neither this integration nor the evidence checker stops processes, closes
browsers, deletes profiles, inspects saves or changes services.

The source audit recorded a denied prior browser warning-page cleanup and an
unverified automatic turn-cleanup outcome. It also recorded a prior denied
desktop-wide process/listener inspection, with no retry or alternate inspection
route. Detailed receipt paths, timestamps, identities and denial evidence remain
local. Those source-audit statements are not new inspection results.

The manual task reconciliation checker now accepts `--runtimes` and includes
runtime findings in the same report. The runtime checker requires explicit
ownership, nonce-bound launch identity, current-use evidence and cleanup receipts.
It flags missing success/failure/timeout/interruption cleanup evidence and never
executes cleanup. Unknown identity or incomplete coverage remains open. Adding
`runtime_cleanup_required: true` to the existing ledger policies also fails when
the runtime inventory was omitted.

At source-audit time, the worker reported bounded Job cleanup and kill-on-close
guards in the launchers it examined. This change checks supplied references to
recorded evidence; it does not independently verify or alter those launchers.
No new background watcher or recurring task was created.

Validation: 62 integrated runtime, ledger and integration tests passed with
`python -m unittest discover -s tools/tests -v`. They preserve the existing 32
ledger tests and cover runtime ownership, current-use uncertainty, cleanup
contracts/receipts, protected resources and input-overwrite rejection. A scoped
runtime snapshot can correctly return open findings for unresolved evidence.
An associated implementation commit does not close the full cleanup objective.
