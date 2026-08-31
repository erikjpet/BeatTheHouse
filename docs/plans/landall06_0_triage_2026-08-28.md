# landall06_0 landing triage — 2026-08-28

Base: green `main` at `00ee744fa6269e8a7eb34f67b2659f32d55febaa`.

Scope: all 101 non-`salvage/*` local branches with at least one commit ahead of
that base and a tip commit in the preceding 48 hours. The 62 `salvage/*`
branches are preservation refs and were excluded as directed. This is the
published landing plan; classifications describe what may be integrated, not a
claim that any row is complete.

## Fixed integration order and true tips

1. `env06_6`: **PARTIAL**. Extract the accepted payload ending at exact
   `855a2961`. `codex/land06-env06_6-final` continues to `b7da64ae`,
   `codex/land06-env06_6-855-current` stages that rejected continuation, and
   `codex/env06_6b-smoke-remediation` continues to second-rejected
   `e297ca8f` plus an idle marker. Those are later chronologically but not later
   accepted tips. Park their V/R/S remainder.
2. `env06_7`: **PARTIAL**, fixed package order A → B → C → D → E. Review and
   extract each package's coherent payload from `codex/env06_7-pkg-a` through
   `-pkg-e`; never merge the parallel branch histories wholesale. Package C's
   second-rejected spatial/evidence remainder is parked. The true assembly
   record is `codex/env06_7-assembly-ordered` because it records the required
   ordering and the later B/E spatial seam; `codex/env06_7-assembly` is
   superseded. Assembly is not itself a sixth package landing.
3. `craps06_3`: **PARTIAL**. `codex/craps06_3-impl` is the core product source;
   `codex/craps06_3-env-integration` is a parallel environment-integration
   variant, not a successor. Extract only independently green coherent slices;
   park ritual-completion and environment-authority/assembly remainder.
4. `crew06_10`: **PARTIAL**. The product tip is
   `codex/crew06_10-first-remediation` (`33999772`), which succeeds the
   implementation. `codex/crew06_10-product-handoff` is documentation cut from
   an earlier product state, and `-integration-replay-manifest` is custody
   documentation; neither supersedes the remediation product tree.
5. `world06_1` through `world06_6`: **PARTIAL**, in numeric order. Product tips
   are `codex/world06_1`, `codex/world06_2`,
   `codex/world06_3-remediation`, `codex/world06_4-remediation`,
   `codex/world06_5-remediation`, and `codex/world06_6`. For rows 3–5 the
   remediation branch replaces the same-number implementation branch. Every
   accepted slice must satisfy the already-landed hostile-authority checklist;
   authoritative receipt/restore/route remainders stay parked.
6. `game06_1` through `game06_7`: **PARTIAL**, in numeric order. Contract and
   product sources are kept distinct. Use `codex/game06_1-validator-closure`
   only for the remaining contract closure and review the product slice from
   `codex/game06_1-impl`; use `codex/game06_2-remediation`,
   `codex/game06_3-impl`, `codex/game06_4-first-review-remediation`,
   `codex/game06_5-impl`, `codex/game06_6-contract-only`, and
   `codex/game06_7-contract-only` as the later same-row sources. Decision and
   replay-manifest branches do not replace product.
7. Cross-cutting prestage rows are **LANDABLE** only as independently reviewed
   docs/scaffolding and remain last: `codex/audio06_1-prestage`,
   `codex/integ06_1-prestage`, `codex/perf06_1-prestage`,
   `codex/teach06_2-prestage`, `codex/playtest06_2-prestage`,
   `codex/depth06_1-prestage`, `codex/game06_8-release-intake-prestage`, and
   `codex/world06_7-intake-prestage`. They cannot close their program rows.

## Branch classification

### PARTIAL

These branches contain or point at a coherent candidate slice, but merging the
whole branch would also import rejected, unresolved, duplicated, or entangled
history:

- `codex/land06-env06_6-final`, `codex/land06-env06_6-855-current`,
  `codex/env06_6b-smoke-remediation`
- `codex/env06_7-pkg-a`, `codex/env06_7-pkg-b`, `codex/env06_7-pkg-c`,
  `codex/env06_7-pkg-d`, `codex/env06_7-pkg-e`,
  `codex/env06_7-assembly-ordered`
- `codex/craps06_3-impl`, `codex/craps06_3-env-integration`
- `codex/crew06_10-impl`, `codex/crew06_10-first-remediation`,
  `codex/crew06_10-product-handoff`
- `codex/world06_1`, `codex/world06_2`, `codex/world06_3`,
  `codex/world06_3-remediation`, `codex/world06_4`,
  `codex/world06_4-remediation`, `codex/world06_5`,
  `codex/world06_5-remediation`, `codex/world06_6`
- `codex/game06_1-impl`, `codex/game06_1-validator-closure`,
  `codex/game06_2-impl`, `codex/game06_2-contract-only`,
  `codex/game06_2-remediation`, `codex/game06_3-impl`,
  `codex/game06_4-impl`, `codex/game06_4-first-review-remediation`,
  `codex/game06_5-impl`, `codex/game06_6-contract-only`,
  `codex/game06_7-contract-only`

### LANDABLE

These are coherent docs/checklist/prestage payloads which can be reviewed and
gated without resolving a product choice. Already-absorbed checklist patches
are classified SUPERSEDED below instead of being landed twice.

- `codex/audio06_1-prestage`, `codex/integ06_1-prestage`,
  `codex/perf06_1-prestage`, `codex/teach06_2-prestage`,
  `codex/playtest06_2-prestage`, `codex/depth06_1-prestage`,
  `codex/game06_8-release-intake-prestage`,
  `codex/world06_7-intake-prestage`
- `codex/crew06_10-integration-replay-manifest`

### BLOCKED — parked, never gating other landable slices

- `codex/env06_6b-save-byte-owner-decision` and
  `codex/env06_6b-second-rejection-owner-decision`: select a complete
  availability/rollback/save triple `V?-R?-S?`, including the exception and
  authority details required by the packet.
- `codex/env06_7-c-second-rejection-decision`: choose A same-scope spatial
  closure, B split spatial authority/evidence follow-ons, or C accept the
  generic-target and assembly-evidence exceptions.
- `codex/craps06_3-second-rejection-decision`: choose A exceptional same-scope
  closure, B split ritual completion from environment authority/assembly, or C
  explicitly reduce the named requirements.
- `codex/world06_1-receipt-timing-owner-decision`: choose A1 non-persisting
  prepare/preview, A2 a named alternate single-authority pre-apply mechanism,
  or A3 an explicit ordering/receipt change.
- `codex/world06_2-second-rejection-decision`: choose A host-rooted closure, B
  proposal-only partial plus `world06_2b`, or C the named compatibility
  exception.
- `codex/world06_3-second-rejection-decision`: choose A bounded fail-closed
  restore closure, B non-authoritative partial plus `world06_3b`, or C the
  stripped-record restore exception.
- `codex/game06_1-second-rejection-decision`: choose A single-authority
  redesign, B retain the closed partial plus `game06_1b`, or C the named
  alternate-authority exception.
- `codex/game06_2-owner-decision-evidence`: choose A sole Blackjack authority,
  B retain presentation/records plus `game06_2b`, or C the named resolver
  exception.
- `codex/game06_3-second-rejection-decision`: choose A Baccarat completion, B
  retain Roulette plus `game06_3b`, or C explicitly reduce Baccarat scope.
- `codex/game06_4-authority-decision` and `codex/game06_4-authority-axes`:
  select wagering authority W0/W1/W2, hand-pay authority H0/H1/H2, and Slot
  acknowledgement scope.
- `codex/game06_5-crossword-decision-evidence`: choose A rebuild mechanics to
  printed art, B repaint art to retained mechanics/RTP, or C hold Crossword
  with an explicit historical-save policy.
- `codex/fix06_13-current-main-integration`,
  `codex/fix06_13-inline-leak-remediation`, and
  `codex/fix06_13-second-rejection-owner-decision`: PARKED by standing option C.
  `fix06_9` and `pusherv3_11` stay parked with it.
- `codex/fix06_24-owner-decision`: choose A bounded adjacent-upper-stock
  physics remediation or B explicitly revise/cut Plan 9.4 and reconcile its
  dependent claims.

### SUPERSEDED

The following branch tips are replaced by a later same-row source, already
absorbed on `main`, historical integration/review scaffolding, or unrelated
pre-program work. They remain preserved and are not merged:

- `codex/depth-env-runtime-4`, `codex/cross-completion-integration`,
  `codex/cross-balance`, `codex/cross-remediation`,
  `codex/backup-land06-docs-amended-20ee5d29`,
  `codex/land06-integration`, `codex/land06-pusherv3_11`,
  `codex/fix06_21-copy-proof`, `codex/land06-fix06_9`,
  `codex/land06-fix06_10`, `codex/fix06_7-stale-pusher-copy`,
  `codex/land06-fix06_10-integration`, `codex/env06_6-07probe`,
  `codex/land06-env06_6-orderprobe`, `codex/fix06_5-timing-predeclaration`,
  `codex/land06-fix06_11`, `codex/land06-fix06_10-final-integration`,
  `codex/land06-env06_6-reconcile`, `codex/fix06_15-route`,
  `codex/land06-fix06_13`, `codex/land06-fix06_14`,
  `codex/land06-fix06_17-scratch-timing-route`,
  `codex/land06-fix06_13-current-main`, `codex/fix06_18-route`
- `codex/review-craps06_3-checklist`,
  `codex/review-env06_7-package-checklists`,
  `codex/review-crew06_10-checklist`,
  `codex/world06_1-adapter-contract`,
  `codex/review-cross-row-ownership-matrix`,
  `codex/game06_1-contract-remediation`, `codex/env06_7-assembly`,
  `codex/main-health-inactive-delivery-triage`, `codex/land06-fix06_8`,
  `codex/fix06_21-main-smoke-health`
- `codex/game06_6-dependency-replay-manifest`,
  `codex/game06_6-dependency-replay-manifest-r2`,
  `codex/game06_7-dependency-replay-manifest`
- `codex/pusherv3_11-replay-prestage`, `codex/fix06_9-closure-replay-intake`,
  `codex/balance06_1-follow-on-prompt`, `codex/owner-decision-index`, and
  `codex/program06-board` are reporting/custody aggregations superseded for
  landing by this triage and the exact source branches it identifies.

## Gate and reporting policy

Every landing receives source/ancestry review, hostile authority/privacy and
exactly-once review where applicable, row-focused gates, the mandatory
functional PostLand gate, and a `--no-ff` merge or an explicit net-payload
extraction when history is entangled. Performance runs after each five
landings on a quiesced host and before any playtest build. A red `main` reopens
only the responsible row and takes priority. No golden, test, or budget may be
weakened to obtain green.
