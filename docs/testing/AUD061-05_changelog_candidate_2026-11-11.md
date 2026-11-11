# AUD061-05 — Changelog and proposed candidate

Started from cf4a5ffdf975f6f3f404af770951664fa48638fd. Specification: docs/todo/BTH_0.6.1_audit_work_orders.md.

Before: CHANGELOG.md had only three 0.6.1 bullets. The full and runtime-filtered git log v0.6.0..HEAD are retained in evidence/AUD061-05_20261111. The existing pre-release tag does not identify this candidate.

Change: replaced only the unreleased 0.6.1 section with player-facing groups covering saves/exit, each game, Crew/events/endings, tutorial/travel and interface/performance. Historical 0.6.0 content is byte-for-text unchanged. Reviewed actual commit subjects across the complete range, including the last audit fixes; grouped internal refactors by their observable effects. No item/scenario content changed.

Code freeze: runtime changes are frozen after 412cd9a3690fcd678b54a44c9ae191da5fdac1fe. Later changes so far are reports, evidence and ledger updates. AUD061-04 is explicitly blocked by the unchanged pipeline qualification pins; this is a proposed candidate for testing, not a release approval. README release links remain v0.6.0. The owner explicitly forbids tags, overriding the report's RC-tag instruction; no tag or release was created.

After: the retained review JSON records the actual history and bullet counts and the unchanged historical section. This is a documentation-only order. Latest runtime Smoke remains 4 pass / 7 fail across 11 stages, matching the baseline functional failures with no new error category; final candidate checks are assigned to AUD061-11/17. No runtime check is claimed to have been rerun for this text edit.

NEXT: pending the normal watcher. Root CHANGELOG.md is an import-classified input, so the existing exact-input cold-import request will be prepared for the final candidate commit and consumed by the existing capped watcher. No guard, reserve, memory cap, exporter pin or deployment path changes are authorized or made.

Proposed candidate SHA: pending the code-plus-ledger commits. Final SHA, exact assets and startup will be recorded after delivery. AUD061-11/17 must qualify that exact identity; AUD061-12's two final-candidate private exports remain to run there.

## Exact candidate and delivery

Changelog commit: 6c6a3571740ac0ae20ebf9809e15d9b3ea0c3e29.
Proposed frozen candidate: fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc.
Tree: 2d49cb17f83379715435a2576473c5cba52728ff.
Normal pull --rebase: up to date; push bdaa9b33..fcfe0204 succeeded.

Existing watcher consumed the exact CHANGELOG.md-only cold-import request and promoted this SHA. Archive SHA256: 95dfd86c6ca9ce73682045f517720511176e786f0b1619a5e543c8177c30aa0f. All ten expected assets passed (eight body hashes and two unchanged engine HEAD/MIME/length checks with their pinned identities). Rendered startup and ordinary Daily Challenge passed, page errors 0 / console errors 0 / worker exit 0 / owned processes 0. Reviewed startup and House screenshots; footer actually reads 0.6.0-dev+fcfe0204d4d0, preserving the AUD061-04 block. The fresh primary was 100312 bytes, SHA256 4ab56e0b869b2287235b4b57d039899cd63a8427c6d3c29f32c05f6086ecb45b, with no rollback or temp residue. This startup is not claimed as the remaining game acceptance.

Full candidate Smoke was rerun: 4 pass / 7 fail, identical baseline stage outcomes, content 25 / runtime 16 failures, no new normalized ERROR category; performance 10 inherited categories. Reconciliation: 1683 inherited errors across 52 tasks; AUD061/QOL findings 0. All receipts are retained. No release/tag/upload was made. This candidate is available for acceptance testing; version qualification and other release gates remain open.
