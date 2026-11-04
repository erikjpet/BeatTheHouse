# Roulette journal currency

`BTH-JOURNAL-ROULETTE-CURRENCY-001` is **Complete for its local fix/test/commit scope**, associated with exact implementation commit `61e77b909b0ca2cb496df54066ba13ffb68ea755`. Local qualification passes **334 producer + 35 unpaid-draft cold + 75 final cold assertions**, with a separate **16-check consumed-wager** pass (460 total). [Structured receipt](roulette_journal_currency_20261104.json). Deployment is outside this local task.

The original R07 Lounge observation on `f3058b6daab820e9d747c4c4aabc2d983e9ae32e` retained one unpaid $14 draft across cold at $33, then naturally lost $14 once to $19; the new journal row lacked currency. The fix baseline used a disposable generated cash table, naturally landed 4, and reproduced the same metadata omission with 29 checks and exactly two expected failures. It did not replay the original natural36 outcome or access the R07 save.

The six product lines add action-time `currency` and `currency_delta` to spin/sit-out, late-chip and wheel-read story producers. `currency_delta` is the current action net, including explicit zero. Wallets, staged draft, settlement/debit, wheel/grade, RNG, authority seals and legacy unknown history remain unchanged; shared Journal SHA-256 is `a426e4451a112d279e7c7f9fa4a47f2ae0e0426c9ebefbad8d9d07fa87744d45`. Independent source/test review approved the scope.

| Evidence | Result | Fidelity |
| --- | --- | --- |
| Baseline | 29 checks, 2 expected omission failures | Native generated cash loss33 to19, natural4, net -14 |
| Initial producer diagnostic | 182 checks, 14 harness failures | Test confused nominal delivery stake14 with total wager28 / free-action cost0; event receipt selector corrected |
| Second producer diagnostic | 331 checks, 1 harness failure | Omitted earned Rourke rival escort event; final exact guards check one action, one invitation and one escort. Metadata/accounting/authority already passed |
| Final producer | 334 pass | Six normal and six auxiliary cash/chip cases, including loss/win/paid-zero, timed reads, security charge and perfect late chips; guards and official Save |
| Unpaid-draft fresh process | 35 pass | Official load preserves draft/cash33, normal two-input sealed Host settles14 once to19, then official Save |
| Final fresh process | 75 pass | Thirteen saved states, full protected wallets/table/RNG/clocks/history/journal, consumed layouts, legacy rows and read-only repeats |
| Adjacent consumed-wager | 16 pass | Full Foundation warm Save/Continue, sit-out, rebet/undo and one guard; no original legacy fixture |

Both diagnostic failures and exact test/source hashes remain in the receipt; only harness expectations/selection changed between runs. Final product SHA-256 is `cb4de4f65f44eba538e7cf466a90d15485c1d95d4a9bbe1af1c7e5db5ab0451c`; final test SHA-256 is `846e9166b604dc119692a497612d66b56a1089d3a013c8d6a44e541d2177697b`. Qualified checks use bounded uncommitted model seed selection and real sealed Host actions without forcing wheel results or timing grades. Negative/miss late-chip grades, renderer/Web/OS-pointer and deployed acceptance are outside this matrix.

All 7 actual nonce-bound owned Jobs are recorded, assigned before execution under a 5% aggregate CPU cap and 2 GiB memory limit, with kill-on-close/no breakaway. Each ended with zero owned processes, including baseline and diagnostic failures. Private fixture saves/references remain local; no save contents or keys are included. Preserve fixed16:9/touch/focus, idle animation, item/scenario pause and the existing storage gate.

All four local acceptance criteria are accepted with the exact implementation SHA, independent review and these tests. No deployed or original-save acceptance is inferred.

Manual reconciliation with current owner/runtime snapshots: current exit 1 (57 unrelated errors across 20 tasks); all exit 1 (523 unrelated errors across 160 tasks). Quarter Falls, Roulette and all seven new Roulette runtime records have zero findings in both. No broad cleanup was performed. Local reports: `task-6/evidence/roulette-currency-ledger-current.json` and `roulette-currency-ledger-all.json`.
