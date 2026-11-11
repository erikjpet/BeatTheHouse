# Beat the House 0.6.1 audit — final execution report

All **18 scoped orders have an execution disposition: 14 done, 1 not reproduced, 1 blocked, 2 failed qualification**. This does not qualify a release. The existing NEXT pipeline is flowing; no tag, official release, manual build upload, stable/itch publication or alternate deployment path was created.

Specification: [unchanged audit work orders](../todo/BTH_0.6.1_audit_work_orders.md), first committed unchanged as ca2302b6bbe36f9b2d6b2af7fbcd8728de9ab968. Up-to-date initial main was **06e5492116b2f4aac78ffbc3d41ed15be64833a9**. The owner's original detached D checkout and its dirty placement/storage work remain untouched; this work used the separately admitted E checkout.

The frozen proposed **testing candidate is fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc**, tree 2d49cb17f83379715435a2576473c5cba52728ff. AUD061-11 and17 runtime checks used that identity. Later NEXT revisions contain only audit documentation, evidence and ledger receipts; they are not relabeled as a fresh full-candidate gameplay pass.

## All scoped orders

A test entry such as 129/0 means 129 assertions, 0 failures; these are scoped checks, not whole-game coverage. Smoke baseline was **4 stages pass /7 fail /11 total**, with25 content and16 runtime findings. Frozen-candidate Smoke also reports 4/7, with no new normalized functional error category. All completed implementation orders retain their own before/after outputs, Smoke comparisons and exact delivered-build receipts. Full SHA and deployed tree/archive details are in the linked proofs and ledger; short SHAs below are unambiguous commit references.

| Order | Status | Implementation/report commit(s) | Proof | Focused results vs before/baseline | NEXT |
| --- | --- | --- | --- | --- | --- |
| AUD061-02 | done |1996d6be |[Leave after failed save](AUD061-02_leave_without_saving_2026-11-10.md) |Exit20+14+14/0; durability129/0; native failure/Cancel/Leave and Web actual FS failure |Verified 18af19ac; startup and changed Web flow |
| AUD061-01 | done |1996d6be |[Stale rollback](AUD061-01_stale_rollback_2026-11-10.md) |Durability129/0; actual stale primary/backup rollback obstacles removed in Web |Verified 18af19ac |
| AUD061-09 | done |901c1d65 |[Async retry](AUD061-09_retry_after_async_failure_2026-11-10.md) |17/7 before→17/0; real worker race leaves newer99 vs old100; Web actual FS recovery |Verified 93f3df02 |
| AUD061-10 | done |7f0e61f1 |[Crew bankroll](AUD061-10_crew_bankroll_2026-11-10.md) |11/3→13/0; authoritative payout/cost and no false fail_run event |Verified bcd22342; native property check, Web startup |
| QOL-02 | done |3e11f59a,134b4202 |[Autosave warning](QOL-02_autosave_warning_2026-11-10.md) |17/8→31/0; interim failed trays retained; Web hover/touch/retry/recovery |Verified ed245d03 |
| QOL-03 | done |384c7a84 |[Error wording](QOL-03_player_error_wording_2026-11-10.md) |54/23→54/0;21/21 support-log detail retained |Verified 49f0b293; ordinary Web startup/play; rare fault copy natively |
| QOL-04 | done |2bcea35c |[Whole-number display](QOL-04_whole_number_display_2026-11-10.md) |80/3→88/0;11 Practice displays/save-reentry; native24 dice checks |Verified d258f3dc; normal Web labels/reload; no all-eleven qualification claim |
| QOL-05 | done |25822cff |[Support diagnostics](QOL-05_support_diagnostics_2026-11-10.md) |42 privacy+14 modal/0;4 actual Web clipboard captures |Verified d389abcf; native folder-open dispatch checked with stub |
| AUD061-16 | done |12216a7d |[Distribution fault gates](AUD061-16_distribution_fault_gates_2026-11-10.md) |58/15→58/0;129 durability/0; shipping/source fault semantics separate |Verified e05ceb6b |
| AUD061-14 | done |bc1ee0c9,7a2c0f82 |[Store failures](AUD061-14_ignored_store_failures_2026-11-11.md) |29/11→41/0; FS17/0; result19/0; Web9690 apartment purchase recovered/persisted |Verified 71e456a3 |
| AUD061-08 | done |138880bb |[Background flush](AUD061-08_background_save_flush_2026-11-11.md) |65/13→77/0; Node30/0; Web minimized real Sleep flush/reload; stale-cache failure retained |Verified facf757e; visibility-hidden path; not mobile/kill/pagehide-all qualification |
| AUD061-15 item2 | done |5676a610 |[Wrong-sized install key](AUD061-15_wrong_sized_install_key_2026-11-11.md) |45/35→45/0;0/1/31/33/64-byte quarantine/new-key controls |Verified 3b36a9c3; native only fault, Web startup |
| QOL-01 | done |b0cb51df,adacdc04,412cd9a3 |[Saved-run replacement](QOL-01_saved_run_replacement_2026-11-11.md) |Real native Tab check83/5→83/0;5 routes; actual Web default Keep/Tab/Enter/cancel/replace |Verified 054ab4a0; Web double-Tab defect found and fixed before completion |
| AUD061-12 | not reproduced |7b4de496; exact-RC follow-through97099e56 |[Export investigation](AUD061-12_web_export_investigation_2026-11-11.md) |160 isolation assertions/0;7 initial full private exports+2 exact-RC exports all exit0; no original causal reproduction |Verified bdaa9b33 and later normal promotions; historical cause remains open |
| AUD061-04 | blocked |94734e74 assessment; no version implementation |[Version qualification conflict](AUD061-04_version_qualification_block_2026-11-11.md) |2/2 requested stamps fail;6 guarded-object predicate checks establish required edits conflict with current exact pins |Assessment delivered with fcfe; version fix not applicable/delivered |
| AUD061-05 | done |6c6a3571; candidatefcfe0204 |[Changelog/candidate](AUD061-05_changelog_candidate_2026-11-11.md) |970 log rows/448 runtime rows reviewed;40 grouped player-facing bullets; existing one-shot cold-import qualification consumed normally |Verified exact fcfe0204 startup/assets; footer still0.6.0-dev |
| AUD061-11 | failed |45b175ec; ledger e1f78f0c |[Candidate acceptance](AUD061-11_candidate_acceptance_2026-11-11.md) |1,674 usable assertions /2 cold failures; terminal391/0; normal Web3-play VP twice Save/reload; strict HTTPS pass; native retention refuses unavailable backend |Frozen fcfe runtime tested; report exact e1f78f0c startup/assets verified |
| AUD061-17 | failed |97099e56; ledger 15a3077f |[Release coverage](AUD061-17_release_coverage_2026-11-11.md) |Money856/2 oracle failures; public closing83/0; Riverboat19/10 fixture failures; Rourke/terminal PASS; version2/2 fail; Python180/0; private packs/source scoped audits PASS |Frozen fcfe tested; report 15a3077f startup/assets verified |

Python final180 tests/0 failures matches baseline180/0. No-input animation liveness passed after the affected changes and on the final frozen candidate; autonomous scheduling remains enabled. Ledger reconciliation has **1,682 inherited findings, zero added and one resolved** vs the preceding1,683-finding receipt. It is not a globally clean ledger. Exact commands, raw failures, corrected setup attempts, process caps, launch gates and cleanup receipts are retained under each proof.

## 1. NEXT pipeline

The existing watcher promoted the coverage report/ledger revision **15a3077f7dec4209d601d83a3f5c76780c9966e2**, tree **c987e790a287a89bdb4827e80ee16a26797b333d**, at 2026-11-11T14:34:32Z, with no error. Its exact bound archive SHA256 is **111febf4134c3cc3e1971f6dd9a3fed603f433f1bf9f463e4c381a8408897517**. Canonical next.json, staged manifests, default NEXT redirect and 10 served assets pass. A fresh isolated browser starts the ordinary unmodified build and enters Daily Challenge at 68 cash; page errors0, console warnings/errors0, all 4 PCK/WebAssembly requests200, worker exit0 and owned processes0. Screenshot footer is0.6.0-dev+15a3077f7dec. See the AUD061-17 proof and retained raw receipts.

The final conclusion is an evidence-only descendant of this delivered report. Its exact final current-main/NEXT identity and fresh startup are verified in the supplemental receipt named at the end of this document; this avoids an endless commit-containing-its-own-SHA loop.

The original allocation/stack-overflow failures at the 49% progress marker remain historically unresolved, but they are not currently blocking the pipeline. The last printed resource marker is emitted after that resource is written; attributing the crash to that small parity scene would be unsupported. Historical allocation and later stack-overflow attempts are separate failures. Same capped historical/current reproductions did not fail. All9 full private exports in this investigation pass under unchanged 2GiB limits. The two frozen-RC PCKs have 1,165 files each and all payload MD5s verified; only the 218-class global cache list order differs, with identical class/all-field maps and 1,164 identical remaining payloads. They are not byte-identical.

Current promotion reserve is admitted by the existing watcher. No retained evidence, player profile or build was deleted to free space. Pipeline guards, native/exporter pins, CPU/memory caps, security settings and stable audience were preserved.

## 2. Blocked qualification

AUD061-04's prescribed project/export-preset and exporter literal updates conflict with the existing qualified source objects. The read-only counterfactual checks produce:

> Guarded native, addon, engine/template or unchanged exporter inputs changed; native reuse refused.

> Web exporter/policy objects differ from the exact reviewed finding009 set.

These are current predicate evaluations, not fabricated failed build attempts. The owner explicitly prohibited changing those guards/pins and instructed stopping an incompatible order. No partial display-only substitute was implemented. Required next step is a separately reviewed/admitted 0.6.1 project, platform preset and exporter-input qualification through the existing pipeline. Project/menu still report0.6.0/0.6.0-dev; Windows stamp0.6.0.0, Android code9/name0.6.0, iOS0.6.0 and export literal0.6.0-dev remain.

Final0.6.1 Windows/Web/source packages, official release checksums and the remaining acceptance gates are unqualified. No qualified Windows native artifact was copied into this QA clone merely to obtain a pass. Cross-version save preservation, migration, upgrade fixtures and runtime version checks remain excluded by the owner.

## 3. Eight separately registered findings

See [full reproductions, context and limits](AUD061_RC_findings_2026-11-11.md). Each has a separate objective and batch, and remains open.

1. **BTH061-RC-BARDICE-COLD-001:** cold44/1 fails the passive-tumble expectation while a Health Inspector popup is visible and transition active. Live cash108/round1; teardown leaves saved94/Reveal/round0. The test did not answer the popup or perform normal guarded exit. Interrupted-save qualification remains open; this is not proof an ordinary close loses progress.
2. **BTH061-RC-SCRATCH-STATE-001:** cold44/1 fails strict owned-state equality; account/RNG/inventory and public reentry checks pass. Read-only saved-state comparison found no primary-file leaf differences. In-memory discrepancy is not yet isolated; no ticket-value loss established.
3. **BTH061-RC-BARDICE-COVER-CLIP-001:** actual1280×720 Web Grand Casino cover display clips the right edge of RET. The separate native94-check draw contract passes; the actual layout defect remains.
4. **BTH061-RC-ACCEPTANCE-COVERAGE-001:** complete rendered Crew-return/Meta/Jazz acceptance and all eleven paid/pending/settled continuation cases are not supplied. Module/source pass counts do not close this gap.
5. **BTH061-RC-NATIVE-RETENTION-001:** exact QA clone refuses measurement because the real native solver is unavailable. No alternate solver, copied unqualified plugin or false allocator-plateau claim was used.
6. **BTH061-RC-COUNT-EXPECTATION-001:** prospective Count write20/1 and separate read7/1 fail exact restore comparison. Selected actual height retains64/430 exactly; ordinary-JSON expectation rounds it by4.16e-16. Cash855/chips41/RNG/status/seed match and once-only720 payout checks pass. Diagnose/fix the expectation oracle before alleging financial loss.
7. **BTH061-RC-RIVERBOAT-FIXTURE-001:** unchanged callback test19/10 uses a minimal host without mounted TalkDock. Current guard correctly rejects null/mismatched dialogue before checked-turn stub. Preserve production guard and qualify actual mounted closing/ride behavior.
8. **BTH061-RC-PACKAGING-001:** required 0.6.1 source stamps fail2/2; final Windows/version/release-set qualification is missing. Old packaging check PASS asserts 0.6.0 and cannot qualify0.6.1.

No acceptance finding was silently fixed or weakened. Optional coverage003/004/008/011 remains partial;009/010 lacks a comparable shipped-build measurement. There are no completed new 3–5-seed route batches, full Windows/phone layout pass, audible quality pass, sustained native memory measurement or all-cabinet paid closing matrix.

## 4. Departures and corrections

- Root AGENTS.md storage/liveness requirements take precedence over older report/fixture conventions. All new QA uses maintained D storage/guard planning, explicit E workspace/profile/temp/evidence/output paths,4 GiB expected writes +20 GiB headroom, capped 12% CPU/2 GiB inherited kill-on-close Jobs, assignment before execution and immediate child gates. Final owned process counts are 0. No C fallback, old-profile move or save-preservation work.
- Older terminal, Numbers and closing fixtures assume obsolete directory names. Evidence-local adapters only strengthen admission to the actual prepared E manifest and declared containment; original behavior assertions remain. Terminal final391/0 has unique raw outputs per fresh process. Earlier invalid setup/output/mode attempts and timeouts are retained and excluded from product totals.
- Rourke's first source fault-switch test was incorrectly run with shipping fault gates active. It passes unchanged assertions in explicit non-distribution source-QA mode. Shipping immunity remains intact. Count modes use current synthetic/prospective state only.
- Real Web checks exposed incomplete first attempts in QOL-02, AUD061-08 and QOL-01; scoped follow-up commits corrected them, with failed attempts retained. An AUD061-15 evidence update accidentally removed plan rows locally;28ece77b restored the exact prior plan blob before the next push. No history rewrite or production effect.
- Raw Windows evidence is preserved byte-for-byte using evidence-local attributes; original artifacts remain under E runs. A formatting-only check reports a raw worker log's trailing blank line; authored Markdown/ledger formatting passes. No raw output was trimmed to force a clean check.
- AUD061-04 stopped at the explicit guard conflict; no guard relaxation, bypass build or substitute version design. Changelog is unreleased; historical release text/README release links remain0.6.0.
- The existing pipeline's documented one-shot cold-import qualification was used only for the changed root CHANGELOG input; it was consumed normally. No new deployment mechanism or watcher was created.
- No item/scenario content, Appendix B, AUD061-03, STR-01–10 or QOL-06–10 work was started. Only the specifically resumed acceptance tasks had their old pause records reconciled; unrelated holds remain.
- Documentation-only evidence commits advance the default NEXT identity after fcfe. The frozen qualification source stays explicit; new revisions receive identity/startup checks and do not inherit a fabricated all-tests pass.

## 5. Proposed candidate and owner release gate

Proposed **testing candidate: fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc**. Its immutable [NEXT build](http://localhost:8088/p/beat-the-house/play/dev/fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc/) was actually tested and remains available. The default NEXT points to the final documentation descendant whose exact identity is recorded in the supplemental delivery receipt, not to a relabeled release candidate.

Before owner tagging: admit and deliver the required 0.6.1 version inputs, resolve/qualify the eight findings and missing rendered/platform coverage, build and audit the final Windows/Web/source set and checksums, and rerun required gates on the resulting single clean candidate. Baseline Smoke/ledger debt must remain visible; no release readiness is claimed here.

This conclusion is committed/pushed through main as a finished evidence-only result. Its own final push identity, tree, watcher promotion, served assets and clean startup are recorded without a self-referential commit loop in:
**E:/CodexQA/BTH/runs/aud061-final-delivery-receipt-20261111/evidence/final-delivery.md**.
The receipt is written only after observing the final deployed revision; absence of that receipt means final conclusion delivery is unverified.

## Commit identity index

- AUD061-02: 1996d6bec0725081c5f873d32ab26ad93eb22e18, 18af19ac2878855e18588b8a618ff58cb2002290.
- AUD061-01: 1996d6bec0725081c5f873d32ab26ad93eb22e18, 18af19ac2878855e18588b8a618ff58cb2002290.
- AUD061-09: 901c1d65cd44d10e709afe4f82b470ddc5db1eab, 93f3df02d8fabeb3a05faacca6c366d21331c33c.
- AUD061-10: 7f0e61f1240146ad4e22911a528b99ddc0b85a47, bcd22342148d2ee12a5b95bd2649b39ca83d7635.
- QOL-02: 3e11f59a1096a7e4e7749d877dadd9bc743f7819, 134b42024e58d26213abe8a642860cf4bbaeeaa0, ed245d0327462ed7a0ee5b51fc0335a224091509.
- QOL-03: 384c7a84869861f0f61b52099aacef376f8e3504, 49f0b2931b14ac139273b4ec54166fa709f7c21a.
- QOL-04: 2bcea35cc68076235d51e88f4887abd66bad2c51, d258f3dc14866f2e8bfd9ee35e3e707507acea95.
- QOL-05: 25822cff6d0f7debb2f9db688515a77f4655cc49, d389abcf59c682ba02d378ec4c7ff4d94f20de25.
- AUD061-16: 12216a7d489ebd96b49af047d0586d4818b1cf66, e05ceb6bd64f3ddec44804752aaa32d88600c622.
- AUD061-14: bc1ee0c9d1e4c8c161c64aa3da95ee08a0ffc4d6, 7a2c0f82b076c2b38047b496f01950cbf0ece41d, 71e456a36d079e2aa8c4d8a95d22b325a673973b.
- AUD061-08: 30ac66e48f7abe0d5ddfcdc2f8d97a2dbd940c84, 9d7d9c4a2c09f9ba6063160f25c93e86770c0c9f, d45f5c02d76767ac149e667cb54ef66a4d625539, 138880bbed6999aa21264b72acdace61036535af, facf757e9520800f4212266e42b4dedc6f3ad32b.
- AUD061-15: 5676a6102b7b9d7a90a59f4d74c4285b3c4e2ccc, 3b36a9c3957fe4b4484d8584d16e971fc743ef93.
- QOL-01: b0cb51dfaf2cea0cf2cb61c42d693cca4b57b434, adacdc0414a3c41db59cd5708e814ea766175891, 412cd9a3690fcd678b54a44c9ae191da5fdac1fe, 054ab4a0d63cf1399180ebbc087097484637ece1.
- AUD061-12: 7b4de496596f4a47ef114d11b0e103cf25b88001, bdaa9b337d3fae076a9ee623051acc2af2e6a7d9, 97099e563b22ecc450f4e17852d51bb6cd9b3ad2, 15a3077f7dec4209d601d83a3f5c76780c9966e2.
- AUD061-04: 94734e74fed1c64cc938a51a49d721285e1cde99.
- AUD061-05: 6c6a3571740ac0ae20ebf9809e15d9b3ea0c3e29, fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc.
- AUD061-11: fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc, 45b175ec3b971ae85d1217b1124099f8d9562bdd.
- AUD061-17: fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc, 97099e563b22ecc450f4e17852d51bb6cd9b3ad2, 15a3077f7dec4209d601d83a3f5c76780c9966e2.
