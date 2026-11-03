# UX-ROULETTE-SOCIAL-QUOTE-001

Fix commit: `226e25833dc8e863f940011fee6cb275cdd73097`.
The named stability task ledger retains this ID and its acceptance status.

## Confirmed failure

Broad's actual Web evidence on source
`72945567dda09bff4feb236e44885a7850211a19` shows Nix advertising a $5 column
wager beside WITH/FADE at River Queen / Velvet Zero. One ordinary FADE click
staged $9 under the real outside minimum. Cash remained $76; there was no spin,
funding, settlement or refund. Normal Clear removed the draft before saving.

The named report and before/after screenshots are preserved privately, with
matching before/copy/after SHA-256 hashes and unchanged originals. The report
hash is `da86b49b9ecfdafa927f3e1ab75c60b4e531ce2f8cfbe9b021d8b9d37fd6d016`.
Task-10 custody receipt: `evidence/roulette-social-quote-custody.json`.
No player save/profile was opened, imported, edited or committed.

The unfixed native source `3fd56aebde05182a02a6babf096ae8b7fe430f7f` reproduced
the same inputs using a synthetic fresh table and normal surface-command API:
patron 5, missing effective-player quote, staged FADE 9, complete run/table/
wallet/RNG unchanged. Its bounded baseline exited 1 with exactly one expected
quote failure among five checks. That is a native production-API reproduction
of the preserved Web inputs, not replay of the original QA save.

## Change

The patron's cosmetic wager remains accurate. WITH and FADE now disclose the
validated player increment separately, for example `WITH $9` and `FADE $9`
above a separately identified `PATRON $5` wager. Each action's quote uses the
same read-only proposal as its staging command, including remaining bankroll,
existing draft bets, table maximum, outside minimum, inside minimum and room
ceiling validation. Unavailable actions do not register an actionable hit.

The proposal preserves the existing target, additive stake calculation and
social alignment. It publishes a candidate only after validation; successful
commands still own Undo and staging. Quotations never advance RNG, fund a bet
or mutate the patron/table. Full, realtime and in-place projections suppress
quotes during unresolved spin/payout/result presentation and challenges,
including a handled lock rejection or first past-post arm. This avoids a new
channel disclosing the already-settled hidden wallet before result reveal.

The focused card remains clear of Leave; larger social buttons display complete
cash/chip amounts instead of the previous thirteen-character truncation.
No payout, table rule, spin/auto timing, native solver or save schema changed.

## Focused verification

`scripts/tests/roulette_social_quote_check.gd` passes **721 checks**, exit 0,
with no script/check failures. Scope:

- both WITH/FADE and cash/chips; patron 5 / effective player 9, equal/above
  minimum, bankroll/table clipping, room/inside-minimum rejection;
- canonical targets and additive increments, existing draft capacity, exact
  rendered labels/currency/font fit, button hits and separation from Leave;
- quotation/command proposals preserve complete run/table and input UI;
  ordinary Clear/Undo preserve wallets, patron state and RNG;
- synthetic pending-result boundaries across all three projection channels,
  handled rejection and legitimate first past-post arming remain quote-hidden;
- an ordinary unmodified generated Foundation host opens Roulette, focuses a
  patron, stages exactly the displayed FADE increment, then Clears. It retains
  zero spins, empty authoritative table settlement and unchanged money/RNG.

All cases use fresh synthetic tables or unmodified generated practice content;
none spins, funds a wager, accesses the original profile or claims Web gameplay.
The generated-host case selected Sal's actual 15-unit patron wager and staged
the quoted 15. The exact Nix 5-to-9 case is the synthetic reported-input case.

Command: pinned Godot `--headless --path source --script
res://scripts/tests/roulette_social_quote_check.gd`, via task-10's maintained
`run_owned.py --timeout 120 roulette-social-final` with
`BTH_NATIVE_PRIVATE_CASE=roulette-social-quote`. Baseline adds `-- --baseline`.
Evidence: `evidence/roulette-social-{baseline,final}.{json,log}`.
The runner uses private persistence, 5% CPU/2 GiB limits, explicit deadlines and
owned Job cleanup; both receipts retain zero active owned processes at release.
Certificate-store startup diagnostics remain in native logs. Intermediate type
inference and host-feedback test-assumption failures are retained locally and
corrected; they are not passing acceptance receipts.

Source review independently checked the shared proposal, alias safety,
minimum/capacity/additive behavior and all result-reveal guards. A normal import
was completed after reusing the exact source import/native support. Only the
scoped files are staged; private evidence and generated support remain excluded.

NEXT artifact identity and permitted browser acceptance are recorded separately
after publication. Native checks alone do not establish deployed Web acceptance.
