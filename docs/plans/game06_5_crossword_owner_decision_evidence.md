# game06_5 Crossword Corner owner-decision evidence

Status: **RESOLVED / HISTORICAL EVIDENCE**

The owner resolved this packet on 2026-09-02 by selecting a polished, denser
interlocking layout with compatible word changes. The accepted implementation
is on remote `main` at `996a98b6`; this packet remains only as provenance for
the earlier decision boundary.

Decision required: choose how Crossword Corner reconciles the shipped printed
background with the shipped mechanical puzzle. The printed word cells and the
mechanical procedural layout describe different puzzles; rect alignment cannot
make them agree.

This packet does not select, rank or recommend an option. Historical documents
contain recommendations for different options; neither recommendation is an
owner verdict and neither is carried into this evidence.

## 1. Exact source and head inventory

Captured from the local repository on 2026-08-27. Every implementation must
revalidate these identities against the then-current Integrator state.

| Classification | Exact commit | Tree | Consequence |
| --- | --- | --- | --- |
| current local `main` used by this packet | `6d8755394c6374ef66364f035e67827fb6e6bf6e` | `bf40316ef8bdc0b6f2ef3709e981a2d6b9b324dc` | contains the accepted frozen game ritual contract and the earlier Scratch alignment work; a later main must be used if the ref advances |
| Scratch alignment implementation in current ancestry | `ef523652a5b1d6582c958bce3316ef26e2e03bb1` | `a316e0091f606d1bf1f03f53d6b2c611e23ae863` | completed independent alignment/migration/guard work but did not resolve the Crossword art/mechanics choice |
| current game06_5 partial WIP | `8efd58bc0053e3fdf587e8ca005f9236c289bb4f` | `8674f27f8a96bd7c4f175285bd9dc42121e9a44f` | clean `UNREVIEWED-BLOCKED`; adds only a partial Scratch counter projection/transaction metadata; no Pull Tabs, art work or acceptance tests |
| frozen game ritual contract | `a2760d816c781e711ff0923c296f97b786662453` | `1df3d9b767d7490acdffb291ce5220c0b409127e` | contract source accepted through the `6d875539` merge |
| rejected game06_1 product runtime | `932287ba0e049f1110cb748f02cb09047d3b42f5` | `9a33aebef2d37fc0093e6cca43bbc01fbc3710a0` | rejected after its second review; forbidden as a game06_5 implementation base |

There is no independently rejected game06_5 implementation head in the current
record. `8efd58bc` is blocked/unreviewed, not rejected or accepted. It may be
replayed only after the owner decision and an accepted game06_1 product
successor exist; its status cannot be upgraded by this packet.

`ef523652` changed nine tracked paths: Scratch regions/data, mask, region model,
Scratch module, focused/UI tests, shared action view model and the alignment
audit. Its current-main presence proves neither Phase 5 completion nor Crossword
acceptance. The board and its source prompt still classify Phase 5 as open.

## 2. Current immutable evidence

### Printed-art boundary

- asset: `assets/art/scratch_tickets/layers/crossword_corner_background_pro.png`
- dimensions: `1556 x 1011`
- byte length: `2,563,171`
- SHA-256:
  `9308d67d7e2dfb3ee6c4bfeecde05b333df67d66cbc9f23280fb331c47c3dbd9`
- region source record: 45 Crossword regions, status
  `measured_procedural`

The printed background is the fixed byte identity for Options A and C. Option B
is the only existing option that opens this asset for repainting.

### Mechanical/RTP boundary

Current Crossword definition:

| Field | Current value |
| --- | --- |
| price | `$15` |
| mechanic | `crossword` |
| generation | `procedural_unique_v1` |
| unique puzzle cycle | `13,860` |
| revealed letter count | `18` |
| layout slots | seven authored across/down slots |
| award ladder | 3 words `$15`; 4 `$30`; 5 `$75`; 6 `$250`; 7 `$1,500` |
| prize weights | `5500, 1450, 1250, 950, 650, 200` per 10,000 |
| configured RTP band | `[3.75, 4.20]` |
| recorded seeded measurement | `3.89031` in `docs/plans/0.5_performance_audit.md` |
| current focused measurement | 100,000 samples per type in `_check_scratch_rtp()` |

The nominal prize-table weighted return is `3.953333...` times price; the
recorded seeded implementation measurement is the executable baseline. The
price, payouts, stock rules, mask, reveal count, deterministic selection,
purchase/redemption and save behavior do not change merely because an option is
selected. Any option consequence below names the narrower boundary it opens.

Current baseline hashes:

| Path | SHA-256 |
| --- | --- |
| `data/games/scratch_tickets.json` | `bf77f7815d273b7a77b4fbf37310d82bbeedf902197550442d1bc3f63b2408d5` |
| `data/games/scratch_ticket_regions.json` | `dfdca9a3c04f47ebda600706314cca8f34ff2f81238f99e327fd0ed62cb561f9` |
| `scripts/games/scratch_tickets.gd` | `b93b2133acddc2fe596c9c8415ef4ee832578295f8bc76ba9554fed94f24ec5c` |
| `scripts/games/scratch_ticket_region_model.gd` | `4328a0f9e7589469747fa7a2591b7f341ea74cc60ef79211aab8f6e4dcce2c72` |
| `scripts/tests/foundation/check_scratch_tickets.gd` | `69e7f0ce9756c5e873914786a07935d8ef7d32cbd062545f8749a592ec4510d5` |
| `tools/scratch_ticket_alignment_audit.py` | `0a0061258aadef1deadde5fd7e9bd354df42dcf8ad69ea79c964dafafd83898c` |

These hashes are evidence, not permanent baselines. An option-specific manifest
must explain every changed hash and prove every path outside its authorized
boundary remains semantically unchanged.

### Unchanged six-ticket boundary

All three options preserve the mechanics, RTP, prize/stock rules and authored
art of:

- `two_fer`
- `lucky_7s`
- `tic_tac_gold`
- `bonus_bingo`
- `high_roller_holdem`
- `golden_vault`

The completed geometry, contain-fit frame, icon/foil bounds, v8-to-v9 partial
progress migration and regression guards for those six are retained. A
Crossword decision does not authorize changes to Pull Tabs, game ritual
runtime, shared visual/runtime code, economy, tuning or any other game.

## 3. Option A: retain printed art; rebuild the mechanical puzzle

Owner statement being executed: read the printed grid out of the existing art
and rebuild Crossword entries/word content to match it. Keep the art. The
puzzle content/probability profile changes and RTP must be re-established.

### Authorized consequence

- The Crossword mechanical layout, word catalog/generation and tests may change
  to describe the printed grid exactly.
- The background asset must remain byte-identical at SHA-256 `9308d67d...dbd9`.
- Mechanical probability/RTP scope is opened only as a consequence of matching
  the printed puzzle. This option alone does not authorize a price, payout,
  stock, heat, economy or other-ticket change.
- If the printed topology cannot realize the existing prize ladder and an
  implementation proposes price/payout/band changes, that is a new owner
  decision, not an implied part of Option A.

### Executable acceptance consequences

1. Assert the background hash remains exactly `9308d67d...dbd9` and dimensions
   remain `1556 x 1011`.
2. Produce a machine-readable printed-grid transcription with cell coordinates,
   orientation, word and source pixels; hash it.
3. Generate each mechanical layout from that transcription and assert every
   printed active cell maps one-to-one to a mechanical cell, every word maps to
   the same cells, and no mechanical active cell lacks a printed counterpart.
4. Run `python tools/scratch_ticket_alignment_audit.py --verify`; all seven
   tickets must pass the locked `<=1.0 px` centre and `<=5%` size limits.
5. Run the focused Scratch suite. Its procedural uniqueness, exact 18-letter
   bank, word-completion, prize-selection, migration, save/load, reveal and
   money assertions must be rewritten only where the selected printed topology
   requires it; all unrelated assertions remain.
6. Run at least the existing 100,000-sample deterministic RTP measurement and
   the program's full probability gate. Record old/new measurements, sample
   count, seed, confidence/tolerance and exact candidate head.
7. Assert the six non-Crossword definitions and mechanics are byte/semantic
   identical to the intake base.
8. Capture printed art, foil, revealed cells, completed/incomplete words and
   every payout rung on native and Web; visual words must equal mechanical words.
9. Run native/Web parity, save/migration, accessibility, performance, Smoke and
   full gates on one immutable head.

Acceptance output must explicitly say whether the achieved return remains in
the current `[3.75, 4.20]` band. A result outside it stops for a new owner
decision; it is not repaired by changing the band in the implementation lane.

## 4. Option B: retain mechanics; repaint the Crossword background

Owner statement being executed: keep the current mechanical grid, procedural
word system and economics; repaint only the Crossword background so its printed
grid/content matches those mechanics at the quality of the other six tickets.

### Authorized consequence

- `crossword_corner_background_pro.png` changes, and its source-art hash plus
  measured region records/overlays change with it.
- Current Crossword mechanics, price, payouts, weights, 13,860-puzzle cycle,
  18-letter bank, achieved RTP and stock/economy behavior remain unchanged.
- No other ticket art is opened. Renderer changes are not implied; if the new
  art cannot pass through the existing contain-fit/region/foil path, stop and
  report the mismatch rather than widening scope.

### Executable acceptance consequences

1. Record the new art SHA-256, dimensions, source file and generation/design
   provenance. The old hash must appear in the before/after manifest.
2. Recompute `source_art.crossword_corner.sha256` and all 45 measured region
   records from the final asset; no hand-edited stale hash is accepted.
3. Assert `scripts/games/scratch_tickets.gd` mechanics, Crossword definition,
   price, weights, payouts, puzzle cycle and letter-bank count are semantic
   equivalents of the intake base.
4. For a fixed deterministic seed corpus, compare pre/post mechanic results,
   layouts, words, banks, payouts, masks after equivalent input and save blobs;
   require byte-identical canonical results.
5. Run `scratch_ticket_alignment_audit.py --verify` and the focused suite with
   `<=1.0 px` centre, `<=5%` size, full foil coverage and no residue.
6. Re-run the 100,000-sample and full probability gates. The current RTP band
   and result distribution remain unchanged; art cannot alter RNG consumption.
7. Obtain independent visual acceptance against the other six ticket assets at
   1x native and Web, including blank, partial, complete winner/loser, small
   screen, reduced motion and colorblind views.
8. Assert all six non-Crossword art hashes and all seven prize/economy
   definitions are unchanged.
9. Run native/Web parity, save/migration, accessibility, performance, Smoke and
   full gates on one immutable head.

Any required mechanics/RTP change rejects the candidate as an execution of
Option B; it does not silently convert the work into Option A.

## 5. Option C: ship the six aligned tickets; hold Crossword

Owner statement being executed: retain the completed six-ticket alignment and
do not ship Crossword Corner in the active 0.6 offering.

### Authorized consequence

- Crossword art and mechanics remain preserved and unchanged; the release/game
  offering excludes new Crossword stock or selection.
- The six listed ticket families remain active with their current mechanics,
  economics and aligned art.
- Holding is not deletion. Crossword definitions, art and historical save data
  remain recoverable for a later owner decision.

The existing option does not specify the treatment of a save already holding
or stocking Crossword. Before implementation, the owner record must select one
executable migration consequence: continue supporting already-owned tickets
without creating new stock, or remove them through an explicit deterministic
refund/migration. An agent may not invent that sub-policy.

### Executable acceptance consequences

1. Assert the Crossword art, mechanic source, definition, regions and test
   fixtures remain byte/semantic identical to the intake identities except for
   the narrowly recorded availability mechanism.
2. Across the complete deterministic stock-selection domain used by the game,
   assert zero new ordinary/practice Crossword tickets are offered, generated
   or purchased after the hold boundary.
3. Execute the owner-selected historical-save migration: either prove existing
   tickets retain exact reveal/outcome/redemption behavior with no new supply,
   or prove exact one-time refund/removal conservation and receipt replay safety.
4. Assert the other six remain selectable and their stock weights,
   probabilities, payouts, RTP and art are unchanged.
5. Run the alignment verifier with the explicit six-ticket acceptance mode;
   it must name Crossword as `HELD`, not `PASS`, `DELETED` or silently skipped.
6. Run focused Scratch tests for the six active families plus hold/migration
   negatives proving direct ID, restored save, stale UI and deterministic stock
   paths cannot create a new Crossword purchase.
7. Remove Crossword from player-facing active catalogs, help/selection and
   release claims consistently while retaining its deferred data/art history.
8. Capture all six active ticket families and the absence of Crossword from
   every purchase/stock surface on native and Web.
9. Run native/Web parity, save/migration, accessibility, performance, Smoke and
   full gates on one immutable head.

Any edit to Crossword art, puzzle topology, word catalog, price, payouts or RTP
rejects the candidate as an execution of Option C.

## 6. Common acceptance and handoff

Regardless of option:

- create a new named implementation branch from exact current accepted main;
- consume only an accepted game06_1 product successor; rejected `932287ba` is
  forbidden;
- replay relevant `8efd58bc` work by three-way semantic application, never
  wholesale replacement, and review it independently because it is unreviewed;
- preserve the chosen option and its exact owner decision ID in the candidate;
- stop editing before review and record commit, tree, base, dependency heads,
  changed paths, hashes and clean status;
- run `git diff --check`, ownership/diff-stat audit and full semantic review;
- retain all red runs and reruns; do not weaken tests, budgets, bands or samples;
- obtain independent correctness/economy and visual/accessibility review;
- invalidate acceptance if the head, tree, art, export or native binary changes;
- let the Integrator perform all merges and post-land gates.

Expected evidence artifacts:

```text
owner_decision.json
input_identity.json
option_scope_diff.txt
mechanics_manifest.json
art_hash_manifest.json
alignment_verify.json
focused_scratch.json
rtp_probability.json
save_migration.json
native_web_parity.json
accessibility_performance.json
native/web capture manifests and contact sheets
full_gate_summary.json
candidate_handoff.json
```

No implementation may begin from this packet alone. It becomes actionable only
when the owner records exactly A, B or C and, for C, the historical-save policy.
