# BTH-NUMBERS-PURCHASE-JOURNAL-001

Numbers purchases were absent from Run Journal even when ticket and wallet
custody were correct. Original Broad finding `QA-OBS-R05-NUMBERS-JOURNAL-001`
was observed on `f876fe41cb8df993d79de4cd02b21f34b7c21dbf`:
`E:/CodexQA/BTH/Broad/r05-20261104/evidence/qa-r05-numbers-journal-observation-849.json`.
Its SHA256 remains
`e302355e129ed31905dd5853a86b8592fac8c0d1074bd15b6ee9b4bfc3c46682`.
The recorded purchase was one Corner Store Draw2 `000 Straight` stake1,
cash31 to30; cold observations retained that slip and cash30. The full journal
tail stopped at Family Loan/Debt Changed descriptions and omitted the purchase.
Those loan descriptions are not evidence of a second transaction and are not
changed by this fix. The original profile was never read, copied, changed or
replaced, and the purchase was never replayed or refunded; only the supplied
observation and screenshots were inspected.

## Cause and correction

The sole UI purchase handler `_confirm_numbers_slip` calls
`RunState.numbers_buy_slip`, publishes feedback and autosaves. The RunState
method issued the slip, debited cash and synchronized the inventory marker,
but did not call `log_story`. Neither feedback publication nor
`change_bankroll` adds that missing purchase row.

The correction adds one success-only `numbers_slip_purchase` row after those
existing operations. It records the existing cash debit explicitly as
`currency: cash`, `currency_delta: -stake` and its `bankroll_delta` alias.
Public fields identify the slip, normalized digits/play type, stake, draw,
venue and purchase message. It does not copy hidden detection, past-post,
physical authority or future result fields into history. `slip_id` is separate
from generic source `id`, so money summaries group purchases consistently.

This is an open purchase, not a resolved `game_action`. Existing generic
journal readers display its message, venue and `Bankroll -1`; existing money
archive readers count one cash leg. No reader, UI, ticket model, validation,
economy, RNG, clock, payout, save schema or migration changes were needed.
Another valid purchase still buys another ticket and debits another stake.
Rejected purchases return before logging. Old paid slips remain without
invented historical purchase rows. Item/scenario work remains paused, and the
fixed16:9 viewport/touch/focus behavior is untouched.

## Reproduction and qualification

An isolated source checkout uses the exact observed public base `f876fe41`.
The minimal native probe `numbers_purchase_baseline.gd` calls production
RunState APIs with explicitly synthetic Corner Store/Draw2/funding inputs.
Before the fix it accepts one open `000 Straight` stake1, cash31 to30 and
chips25 unchanged, but adds zero story rows. Its sole failed assertion is the
missing purchase receipt. This is not the original R05 profile or a GUI/Web
route replay.

The focused production API regression passes **159 assertions**:

| Stage | Assertions | Evidence |
| --- | ---: | --- |
| Producer/rejection/Save |105|Reported Corner Store Draw2 purchase; Box normalization; second valid intent creates a distinct ticket; ten invalid/closed/insufficient/no-book requests preserve the full run fingerprint; public field whitelist; one journal/archive cash leg; official Save and fresh official load of three states |
| Independent cold process |54|Officially loads reported, multiple-purchase and legacy states; full guarded Numbers/history/inventory/debt/wallet/root RNG/clocks equal producer loads; repeated readers do not charge, add rows or mutate the full run |

Cold reported state is cash30/chips25, one slip and one `Bankroll -1` row.
The legitimate two-purchase Box case is cash27/chips25 with two distinct slips
and two `Bankroll -2` rows. The explicitly synthetic legacy shape has cash29,
one already-paid slip and zero purchase rows before and after Save/cold.
Same-process rejection and read checks fingerprint the complete RunState.
Persistence checks retain all guarded fields and normalize only JSON numeric
representation for the first codec comparison; independent cold references
then compare exact post-codec values. Hidden draws are not inspected or
overridden to select an outcome.

Both final jobs exit0, without timeout, with zero owned processes after cleanup,
under the maintained5% CPU/2GiB kill-on-close runner. The baseline job exits1
for the expected missing-row assertion, without timeout or leftover processes.
The native sandbox's certificate-store diagnostic is retained in logs and no
trust setting changed. Cache preparation reuses only exact public deployed
import/class files. This is not fresh import qualification. A full-disk clone
attempt was recovered by deleting only this new checkout's incomplete branding
and review-artifact copies and using a sparse runtime checkout; no old task,
evidence, user profile or source checkout was removed.

```text
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/numbers_purchase_journal_check.gd
godot --headless --path . --audio-driver Dummy --script res://scripts/tests/numbers_purchase_journal_check.gd -- --cold
```

The two stages share a fresh explicit disposable `BTH_WORLD_REENTRY_ROOT`
and contained save/settings roots, supplied by the maintained owned runner.
`BTH_TARGET_OUTPUT` records the structured result. Evidence lives under
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/`:
`numbers-journal-baseline-result.json`,
`numbers-journal-final-producer-result.json`,
`numbers-journal-final-cold-result.json`, their matching Job/log receipts,
`numbers-native-cache-bootstrap.json` and
`numbers-journal-combined-receipt.json`.

Implementation: `eb4e66bb86f1aff99e74734aa3afd65fb5d25a3a` on isolated branch
`fix/numbers-purchase-journal-20261104`, based on public `f876fe41`.
Independent source/test review and final159-result identity audit found no
blocking findings. No full suite, rendered Host, OS-pointer, original-profile,
main-menu Continue or Web Numbers-purchase gameplay acceptance is claimed.

## Authorized NEXT acceptance

A later delegation authorized isolated publication and NEXT verification if
permitted, keeping separate denied fixes excluded. One normal push succeeded
from `f876fe41` to `5e04e409546ecc9c8c3d04087bddacbd316c818c`, tree
`133e8a31132199ebff7ec61715a860d80e93a676`. Its outgoing scope was exactly
the Numbers RunState correction, focused test and these two tracking documents.
The older denied Slot, Craps and Bar Dice checkouts remained clean and unchanged.
No prior denied operation was retried.

The existing120-second watcher observed that exact main at14:32:55UTC,
completed its qualified-native Web export/PCK audit, and promoted it at
**2026-11-04 14:34:02UTC**. No extra watcher or manual substitute build ran.
Exact served identity passed at14:34:21UTC:

- NEXT JSON, current pointer, generated LAN redirect, BUILD, manifest and
  provenance match that SHA/tree and version `0.6.0-dev+5e04e409546e`.
- Six required assets return200 with provenance lengths; all three WASM
  responses use `application/wasm`.
- Served PCK SHA256 is
  `c03ce5d92673069df7c1541787d2fa7c2b8fe918ec2b349aa94699c831248f3d`,
  matching provenance. Archive SHA256 is
  `bb6ba4127aff1d65160fd1bffc453e14f56ecf98da2372758e2361f764b6e90e`.

A fresh sandboxed disposable browser reached the correct-version main menu on
the exact immutable URL, visually inspected in the startup screenshot. All
four engine/PCK/native downloads return200; page errors and console errors are
empty. One expected pre-gesture AudioContext warning is retained. Browser and
context closure completed; the5% CPU/2GiB owned Job exited0, without timeout or
error and with zero processes at release. The check uses documented localhost
HTTP plus the generated LAN redirect; it does not claim direct LAN TLS testing
or changed-behavior Web play. Existing159 native API/official Save/cold assertions
remain the scoped changed-behavior qualification for the identical committed
product diff. No original R05 profile was accessed or paid outcome replayed.

Exact release/startup receipts and screenshot use prefix
`next-5e04e409546ecc9c8c3d04087bddacbd316c818c-`; the browser Job/log use
`web-next-5e04e409-final`. Publication and observed watcher states are in
`numbers-journal-publication-attempt.json` and `numbers-next-observations.jsonl`.
The existing plan/ledger records Complete with implementation commit associated
and the scoped native plus NEXT acceptance above. A later documentation-only
closeout commit records this already-observed acceptance; it is not substituted
for the verified product identity. Any subsequent exact NEXT observations are
recorded separately in the combined local receipt. Stable, itch, hosting audience,
trust settings, item/scenario work and fixed16:9/touch/focus behavior are unchanged.
