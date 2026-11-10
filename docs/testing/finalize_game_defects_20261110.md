# Finalize two confirmed game defects (2026-11-10)

Base: `c3d16523e6a149ea7f401e5fabbb2703b2758c3e` (`origin/main`). This is a
scoped correction for `BTH061-AUDIT-HOME-LOSS-PROJECTION-032` and
`BTH061-AUDIT-MEMO-TYPE-SAFETY-014`, not completion of the whole audit or the
paused item/scenario redesign objectives. Main/NEXT publication is coordinated
separately and remains required before closing either delivery objective.

## Corrections

- `RunState.lose_home()` captures whether the player occupies the active home
  before invalidating the active/lost flags. Ordinary motel expiry and rent
  eviction now clear the occupied room's container data and physical manifest,
  mark the room lost, and retain existing world-node loss semantics. No stored
  items are returned to inventory. The surrounding ordinary midnight owner
  still performs its existing reconciliation/publication transaction.
- Successful scenario-validation memo keys now hash the native typed Variant
  encoding. JSON had erased StringName/String and PackedStringArray/Array
  distinctions, allowing malformed alternatives to reuse a valid proof. Target
  authority projection, registry identity, positive-only caching and FIFO 256
  remain unchanged. Empty native encoding after recursion/depth failure means
  an uncacheable empty key, never a shared successful key.

## Focused native evidence

All final checks use the pinned Windows Godot
`4.6.stable.official.89cea1439`, an isolated E-drive workspace and fresh guarded
profiles, not personal player saves. Each capped Job has assignment before
execution, 12% aggregate CPU, 2 GiB memory, a bounded deadline, kill-on-close and
`active_at_release=0`. Complete commands, storage manifests, source hashes and
receipts are recorded in `finalize_game_defects_20261110.json`.

- Home baseline on unchanged main: `finalize-defects-home-red-20261110`, exit1.
  Normal container placement, storage and sleep reproduce stale container data,
  stale physical rows and a missing current-room lost flag after both kinds of
  midnight tenure loss.
- Memo baseline: `finalize-defects-memo-red-20261110`, exit1. Both exact cold
  unsupported-Variant 21/34 errors become `[]` after a valid warm hit, with
  `hits=3/full_runs=1` instead of revalidation.
- Final home contract: `scripts/tests/home_loss_projection_contract.gd`;
  `finalize-defects-home-delivery-20261110`, exit0. Covers normal sleep-induced
  motel expiry and rent eviction, current/stored-room cleanup, valid physical
  publication, cash/carried-item ownership, inert repeated loss, rejected lost
  storage, lost-home exclusion from travel targets, save-codec/native restore
  with Continue's trusted catalog rehydration, paid-up sleep and loss while away.
- Final normal memo contract:
  `scripts/tests/foundation/scenario_validation_memo_contract.gd`;
  `finalize-defects-memo-final-20261110`, exit0. Preserves current 1485-pair
  production authority, 55 production-load hits and FIFO 256; exact repeated valid
  hits, rejected target/registry/signature mutations, exact cold/warm/repeated
  StringName and packed-array errors, valid ordinary `Array[String]`, distinct
  int/float key identity and input ownership all pass.
- Serialization-failure negative probe:
  `scripts/tests/scenario_memo_encoding_failure_check.gd`;
  `finalize-defects-memo-cycles-final-20261110`, exit0. A cyclic no-sequence
  candidate stores no successful key; a cyclic authored sequence retains exact
  cold/warm/repeated rejection, with entries 0/hits 0/full_runs 3. Native encoder
  recursion ERROR stderr is deliberate and expected only for this standalone
  negative probe. Its final explicit PASS, closed receipt and untruncated log
  establish the bounded result, not a claim of clean ordinary stderr.
- Key-cost diagnostic:
  `scripts/tests/foundation/scenario_validation_memo_cost_diagnostic.gd`;
  `finalize-defects-memo-cost-final-20261110`, exit0. The executed scratch file
  is byte-identical to this retained diagnostic. Across 55 actual production
  definitions and 165 interleaved samples each, typed keys average 1134.45us and
  legacy JSON keys 1622.39us (ratio0.699). Thirty-two actual warm hits average
  1185.84us, with full_runs 1/hits 32/entries 1. This is capped native key-cost
  evidence, not an uncapped whole-game or Web performance claim.

Earlier attempted home restore fixtures omitted trusted catalog rehydration and
used a one-node map that made every traveler fall back to the home. Those
receipts remain failed/unqualified. The final synthetic fixture uses the normal
full WorldMap topology and town configuration. A later test incorrectly equated
map visibility with route eligibility; that failed assertion is retained, and
the final check uses the actual public travel-target API. No product authority
check was weakened to make these fixtures pass.

## Scope limits and follow-through

These are native production-API/synthetic-state checks. They do not constitute
UI Save/cold Continue, original-personal-save reproduction, rendered browser
play, full-suite acceptance or exact deployed NEXT behavior. No RNG/economy,
canvas scheduling, audiences, export scope or paused item/scenario content was
redesigned. The existing whole-audit objectives remain Open. Follow the exact
fix commit through the authorized existing main/NEXT workflow, then record the
remote source identity and actual deployment/behavior evidence separately.


## Commit and manual reconciliation

Actual tested source commit: `31bb55b88fce5890029b9470ceb7548c9ce1bad5`.
Both assigned ledger rows record local qualification and remain Open pending
main/NEXT delivery. Their historical evidence is preserved.

The required manual reconciliation was run with the historical snapshots plus
actual current parent/worker observations and this task's closed Job receipts.
It exits 1 with 899 existing/global findings across 67 tasks. Forty-five findings
associated with the memo objective are stale observations of historical task9
Jobs, not this task's new owned processes. No current owned-Job finding and no
non-runtime ledger/Markdown finding concerns either assigned row. This is not a
whole-backlog reconciliation pass; the exact command and retained report paths
are in the JSON evidence. Earlier observations were not re-dated or hidden.
