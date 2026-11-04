# Runtime cleanup verification status

Stable objective: `BTH-RUNTIME-CLEANUP-001`. Status: **Open**.

Direct Grand and Crew owner reviews, relayed on November 4, confirm **Unknown
process closure** for Crew Alley019 and Grand ordinary07/08 and Rourke13/25.
Grand's historical gameplay actions and checkpoint/export results completed, but
the final Job exit/release fields are absent. Its last samples reported eleven or
twelve active processes at historical timestamps. Those samples establish neither
current running nor clean closure. Crew's complete Chromium closure is also
unknown because the final Job-drain receipt is missing; its recorded set contains
thirteen distinct IDs across samples and twelve in the last sample. Exact owner
sources, timestamps and hashes remain in the cleanup owner's local evidence.

The five runtime inventory records therefore use `state: unknown` and unknown
current identity. They must not be presented as running, cleanly closed or safe
cleanup targets. Existing historical process queries were read as evidence and
were never replayed.

The five remaining historical outcomes are unchanged from
[the per-run follow-up](runtime_cleanup_followup_2026_11_04.md). No confirmed
currently abandoned task-owned target was established. No process or browser was
stopped, no save/profile changed, and no intended preview or NEXT service altered.
The prior certificate-warning tab's automatic cleanup remains separately uncertain.

Canonical delivery was unverified in the source worker's historical readback.
At 01:10 UTC on November 4, `main` resolved
to `75b491df2410b90a65c72160bd433a37389099f7`. Exact-ref readback returned Not Found
for `tools/check_bth_task_ledger.py` and the follow-up document, while the existing
release plan was readable at that same commit. The workflow owner reports local
integration and passing integration tests while publication was in progress.
That timestamped readback does not describe later publication outcomes. Verify
the actual published commit separately; local commits and tests do not establish
a published canonical workflow.

The prepared metadata update refreshes the existing cleanup objective and readable
row, retains every task/batch and coverage-area ID, and refreshes the original
runtime snapshot to eleven explicit records. Five historical process-closure
states and the separate warning-tab outcome remain Unknown. The checker must
continue to return a nonzero result for the unresolved evidence. No tooling batch
or parent objective is closed by this metadata update.

The [initial sixteen-record snapshot](../todo/bth_runtime_inventory_initial_20261104.json)
preserves the prior evidence and original record identities. The refreshed
snapshot unions earlier evidence paths with the new review references and retains
the original process/activity observations and uncertain warning-tab receipt time.
Optional `closure_review` metadata records the later review with
`currently_running: null` and `cleanly_closed: null`; it is not a cleanup receipt
or proof of present identity, and the v1 checker does not use it to close an item.

Before closing the delivery batch, verify the actual published commit and read
back the checker, required-runtime policy, structured/readable stable task entries
and follow-up document. Preserve the existing owner integration and all open
cleanup outcomes. The checker must retain its nonzero result for unknown identity,
incomplete coverage and missing cleanup evidence. The full cleanup objective
remains open even after its tooling batch is delivered.
