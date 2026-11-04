# CARD-INTEREST-DISPLAY-001 — recovered fix and acceptance

Status: Complete within the original Card-page display scope. Reconciliation
owner: task-14. No new product code or financial action was needed.

Associated fix: `ab57f8fa01a0b08e62b7c9049433ffaeffeaadd8`, accepted tree
`cade02b6b9e7060d68fe724e242aad969713bea0`. Its exact NEXT release was promoted on
2026-10-30 at 05:12:54 UTC and accepted at 05:31:27 UTC. The restored named ledger
had lost this association despite the retained release evidence and prior
closed task record.

## Original finding and repair

The named finding at `2026-10-27/task-2/CARD-INTEREST-DISPLAY-001.txt` records
build `197310ac6f57eec52eaf3012117b2bdb9828d0db`: Linda's already-open blocked
Gold Card page still displayed $49 after normal clock interest made the actual
marker $52. Both payment methods already used the correct authoritative amount;
no financial repair, refund or payment replay was requested.

The fix refreshes the existing active Cage service page when its integer marker
changes. It retains the conversation, claim eligibility and accounting. A closed
page stays closed. It does not refresh unrelated live game reveals or alter
clock progression, interest rules, balances or Players Card qualification.

## Retained acceptance

Primary receipts remain in `2026-10-23/task-2/evidence/`:

- `parallel-three-fixes-release-receipt.json` and
  `parallel-three-next-identity.json`: clean exact-ab57 source/tree, served NEXT
  identity/assets and owner native/Web qualification.
- `parallel-card-open-e-result.json`: 28 passing native checks.
- `parallel-card-closed-final-result.json`: 27 passing native checks.
- `parallel-card-cold-final-result.json`: 6 passing separate-process checks.
- `parallel-card-web-a/07-Card-passive-190s.png`,
  `parallel-card-web-cold/01-continued-visible.png` and
  `parallel-card-web-accounting.json`: ordinary passive clock progression from
  22:30 to 03:15 changes the existing body and disabled Claim reason from $49 to
  $52. One $3 interest charge, cash $123, chips 155, inventory, history and RNG
  persist through fresh-browser cold Continue.

The Card-specific native total is **61**; 380 belongs to the entire three-fix
batch. Passing native/browser jobs record normal exits and zero owned processes.
An independent reviewer inspected the settled warm and cold screenshots and
accepted the original scope. The 03:00 screenshot catches ordinary text
transition; acceptance does not promise atomic zero-frame text replacement.

## Current-source and ownership reconciliation

Current worker assignments were checked: the former implementation worker owns
Video Poker opening-hand persistence, Broad QA owns its R04 gameplay track, and
the other active workers own performance, budget-validator and audit work. No
active worker owns this Card implementation. The older task13 ownership snapshot
also lists it unassigned, but that snapshot is not treated as a live census.

The fix is an ancestor of current main. Its LF-normalized guarded refresh block
remains identical (SHA-256
`4cb7404289e90662914bb8071dc5f6f8855c65a3c287d4c0cc8bfaf2a8602a08`), and the
focused regression retains Git blob
`ba8cfa31c14ca34c49a49fb3174e6a77b4730562`. The receipts qualify the exact
historical build and inputs; they are not presented as a fresh whole-app pass
on the later source. No original profile, save or authority key was accessed or
copied during this reconciliation.

Task-14 `evidence/card-interest-reconciliation.json` records source ancestry,
unchanged guarded code/test identity and the recovered 61-check/real-Web scope.
The final `outcome-card-interest.json` will record the metadata publication's
actual NEXT identity and startup result. Stable, itch and hosting audience remain
unchanged. The original bug requires no further product change; this commit
restores its durable task association and acceptance record.
