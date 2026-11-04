# Coin Pusher visible Drop and Hold terms

`BTH-COINPUSHER-DROP-PRICE-001` is **Complete for its local fix/test/commit scope**, associated with exact implementation commit `62490ab186657cbfff49839589863e851eef7bcd`. Local native qualification passes **228 producer + 35 fresh-process cold assertions**, plus the separate no-pointer animation check. Deployment is outside this local fix/test/commit scope. [Structured receipt](coin_pusher_drop_price_20261104.json).

The original R07 warm886/cold887 observation on `f3058b6daab820e9d747c4c4aabc2d983e9ae32e` showed Quarter Falls / Vault Drop with $54 and no visible Drop/Hold cost. It made no paid input. A disposable native baseline reproduced the omission with two expected failures and zero paid inputs; the original R07 profile was not accessed.

The fix exposes canonical `_drop_cost()` and the affordable held count/total in the existing control geometry. Quarter Falls, Jackpot Ridge and Vault Drop share this price. Hold retains its 60-drop gesture limit and affordability rule; existing queue entries are already paid. Display examples are `DROP/HOLD $3`, `HOLD 3 $9`, `NEED $3` and `PAID 3; DROP $3`. Transaction, queue/solver, RNG, clock and save behavior are unchanged.

Qualification uses the exact pinned native DLLs/config recovered from the provenance-verified public artifact; each fixture asserts native availability. The initial mismatched developer configuration was rejected before runtime, rather than accepting a fallback. All six actual owned Job receipts and pinned identities are retained in the structured receipt.

| Evidence | Result | Scope |
| --- | --- | --- |
| Native baseline | 2 expected omission failures; exit 1 | Vault Drop, $54, unit price $1; zero paid inputs |
| Initial producer | 228 pass; exit 0 | Same final product hashes |
| Initial cold diagnostic | 35 checks, 6 comparison failures; exit 1 | Equal numeric prices had JSON float/int dictionary types; failure retained |
| Qualified producer | 228 pass; exit 0 | All variants; canonical/default/nondefault prices, affordability, cap60, cancel, paid queue, actual tap/Hold accounting, merged action patches, renderer/font/cache and official Save |
| Qualified fresh-process cold | 35 pass; exit 0 | Six idle/prepayment variant/cost fixtures; full durable state guard retained; no in-flight or paid-queue cold claim |
| No-pointer animation | PASS; exit 0 | Existing focused liveness script |

The diagnostic correction is test-only: normalize both complete dictionaries through `_persistent` before equality. The durable full-state guard was not weakened, and game/renderer bytes did not change. Qualified test SHA-256 is `3ab75d704acfa86f1977b3cb4dc48b627ac2e47a167ffb9c8dd6d5ec57a4f51f`; exact source and job hashes are in the JSON receipt.

The actual renderer draw callback and real Canvas font fitter measured labels inside the existing `Rect2(538,391,76,9)` at fitted font 6, height 9; the original `Rect2(540,352,72,48)` Drop hit region remains unchanged. This is native rendered-command/font evidence, not screenshot/pixel, OS-pointer or deployed Web qualification. Source review approved coherent count/price publication on successful/refused release and preservation of context-free action quotes until realtime refresh.

Each owned job was assigned before execution with a 5% aggregate CPU cap, 2 GiB Job memory limit, kill-on-close and no breakaway. All six ended with `active_at_release=0`, including the expected baseline and diagnostic failure. Private disposable fixture saves/references remain local; no saves, keys or profile contents are included here. The scoped item/scenario pause, fixed 16:9/touch/focus behavior and storage reserve are preserved.

All six scoped local acceptance criteria are accepted with implementation commit `62490ab186657cbfff49839589863e851eef7bcd`, independent source review and the qualification receipts above. No deployment or original-save qualification is inferred.

Manual ledger reconciliation completed with the current owner/runtime snapshots: current group exit 1, 57 existing errors across 20 tasks; all group exit 1, 523 existing errors across 160 tasks. This objective and all six new runtime records have zero findings. Unrelated backlog/runtime gaps remain recorded; neither check is a global pass. Local reports: `task-6/evidence/pusher-price-ledger-current.json` and `pusher-price-ledger-all.json`.

After associating the exact implementation SHA and completing the six local acceptances, both manual checks were rerun: current exit 1 (57 unrelated errors/20 tasks), all exit 1 (523 unrelated errors/160 tasks). Quarter Falls, Roulette and all six new runtime records have zero findings in both reports. Evidence: `task-6/evidence/pusher-price-ledger-committed-current.json` and `pusher-price-ledger-committed-all.json`.

A later authorized main/NEXT publication request extends the full objective, which is now Open for delivery verification. The completed local scope above remains accepted. See [shared release follow-through](quarter_roulette_publication_20261104.md); publication and deployed identity/assets/startup are not established by this local receipt.
