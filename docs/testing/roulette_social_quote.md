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

## NEXT publication and remaining acceptance

Fix `226e25833dc8e863f940011fee6cb275cdd73097` and qualification commit
`8bdfdbedb98e37eaf781952439df3877b80b6c46` were pushed to main. The existing
watcher promoted the latter at `2026-11-03T23:55:59Z`, with no watcher error.
At `23:56:36Z` its served identity was independently verified:

- source `8bdfdbedb98e37eaf781952439df3877b80b6c46`, tree
  `32951690e68d97a856a832b2c503e2acdde0ad84`;
- version `0.6.0-dev+8bdfdbedb98e`; actual NEXT redirect, current pointer,
  `next.json`, `BUILD.json`, manifest, REF/VERSION and archive provenance agree;
- all six game payload HEAD requests returned 200 with provenance sizes and
  correct WASM MIME; downloaded PCK SHA-256
  `13850d0682398cb4b834067d65d22fe842814a7e654ebe865de6db6682d06902`
  matches export provenance;
- archive SHA-256
  `8d8478e13af1ad07b16fd2e6a7f9bf24097a2fc0a2247618c05b3c2ce798c4a1`.

Receipt: task-10 `evidence/next-8bdfdbedb98e37eaf781952439df3877b80b6c46-release.json`.
These are pipeline and documented local HTTP asset checks, not Web play.

Normal permitted browser navigation to the existing LAN HTTPS NEXT entry at
`https://192.168.0.36:8443/p/beat-the-house/play/dev/` stopped before the game
loaded with **NET::ERR_CERT_AUTHORITY_INVALID** / Privacy error. At
`2026-11-03T23:56:53.908Z`, captured warning/error console logs were empty;
that is not a clean application-startup result because the application never
loaded. No warning was bypassed, trust setting changed or alternate browser/
route used for gameplay. The temporary owned tab was closed. Receipt:
`evidence/roulette-social-next-browser-blocked.json`.

At that observation the task remained **Open**: native quote/staging qualification and deployed
artifact identity pass, while permitted Web startup and actual deployed
quote/staging acceptance remain unverified. Stable, itch and hosting audience
were unchanged.

## Authorized localhost Web acceptance, 2026-11-04

The owner separately authorized the documented, independently intended
`http://localhost:8088` testing route for fresh practice quote/staging/Clear only.
This is local Web acceptance, not acceptance of the LAN HTTPS route. No security
warning was bypassed and no certificate/trust configuration changed.

The actual browser loaded immutable source
`adb75dbe7f97e2b96279fbf401f7d7b8913072b3`, tree
`fb2a52392fac32fc927ad0071a38fa744e85fb37`, showing version
`0.6.0-dev+adb75dbe7f97`. Served BUILD/manifest/PCK HEAD agree, and ancestry
contains fix `226e25833dc8e863f940011fee6cb275cdd73097`. Roulette and its
721-check regression have exactly the tested fix's blobs. The earlier complete
asset/provenance receipts remain attributed to their original exact builds.

In the thread's fresh localhost browser session, the start menu showed PLAY
without Continue. The normal Game Library controls were used: seed
`QUOTE-001-089`, bankroll76, Min9, Max200, Security Boss, overrides `{}`.
A bounded source-planning probe found this exposed seed; no patron, table or
runtime state was injected into the browser. It generated Grand Casino /
Midnight 00 with Trent and Nix. Nix naturally held a5-chip column wager.

Actual rendered UI at1280x720, completed `2026-11-04T00:37:24.085Z`:

1. Focus Nix: card reads `PATRON 5 CHIPS 2 TO 1`, `WITH 9 CHIPS` and
   `FADE 9 CHIPS`; draft BET0, cash$76, chip wallet0, `NO SPINS YET`.
2. Click FADE exactly once: draft BET9 with one9-chip player stack; cash$76,
   chip wallet0 and `NO SPINS YET` remain unchanged.
3. Click Clear exactly once: draft BET0 and the player stack is removed;
   cash$76, chip wallet0 and `NO SPINS YET` remain unchanged.

No Spin control was used in this acceptance, no spin resolved or wager was
funded, and no Save was selected. Practice autosaving is explicitly suppressed
by the existing `dev_game_test_mode` branch. No existing player profile/save was
inspected or imported. Captured browser warning/error logs were empty, and the
temporary owned tab was closed. Normal action clock advances are ephemeral
practice state, not saved progression.

Task-10 evidence:

- `evidence/roulette-local-adb-served-identity.json`;
- `evidence/roulette-local-adb-web-acceptance.json`;
- `evidence/roulette-local-adb-{fresh-menu,practice-inputs,nix-quote,nix-staged,nix-cleared}.jpg`;
- `evidence/roulette-local-adb-evidence-hashes.json`;
- source-planning `evidence/roulette-seed-plan-r2.{json,log}` (5%CPU/2GiB,
  exit0, no timeout, zero owned processes; this is not browser acceptance).

Preflight is separate: default PRACTICE generated Sal/Milo, so no draft was
staged there. One exploratory Sit Out selection armed CONFIRM but was never
confirmed; `NO SPINS YET` remained, and that session was discarded at BET0.
The successful Nix acceptance above touched only focus, one FADE and Clear.
Earlier seed-planning setup/launcher failures are retained, not counted as passes.

**UX-ROULETTE-SOCIAL-QUOTE-001 is Complete for its fix, native721 qualification,
exact NEXT delivery and authorized localhost Web quote/staging/Clear acceptance.**
This does not replay the original River Queen cash save: the actual Web case
uses generated Grand Casino chips, while native coverage separately verifies
both cash and chips. LAN HTTPS certificate repair/acceptance remains separately
Open; localhost success neither repairs nor qualifies that route. No product,
portrait, viewport, touch or focus implementation changed in this closeout.
