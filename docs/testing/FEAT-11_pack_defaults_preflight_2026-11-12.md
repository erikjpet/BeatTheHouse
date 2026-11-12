# FEAT-11 — pack default preflight and specification conflict

Date: 2026-11-12. Source: `964d6df457f3ec653188e36ac549bde369919f06`.
No production file or group default has been changed for this item.

## Confirmed before state

Both groups are false by default. A running Godot probe exercised the real
ContentLibrary group selection and merchant-pool functions with explicit
off/on selections. Turning on the groups adds **18** ordinary merchant-pool
entries: all thirteen scenario souvenirs and the five Mags bench outputs.
`crew_package` is excluded because it is not sellable.

This contradicts the requested acceptance that ordinary merchant stock stay
unchanged and these items arrive only through scenario, bench or delivery
routes. The root is existing `shop_item_pool_for_challenge` behavior: every
enabled sellable group item is appended. The first implementation is stopped
before its two data edits. No alternative acquisition design has been shipped.

## What off blocks: evidence and limits

| Path | Observation with both packs explicitly off |
| --- | --- |
| Default catalog membership | Both groups absent, as reported by the audit |
| Ordinary merchant pool | All 18 route-only sellable items absent; explicit on adds them |
| Qualified Mags bench offers | All five catalog choices remain available in the running production EventModule, using explicit public rank/parts/cash prerequisites |
| Scenario souvenir / bench output | Not established: detached room fixtures failed production room-object authority; their reward failures are harness failures, not product findings |
| Crew package | Not established: job admission succeeded but this incomplete fixture did not prove a carried package; not reported as acquisition failure |

The probe ran **36 assertions: 10 passed / 26 failed**. Two failures confirm
the current off defaults; nineteen confirm the merchant-pool conflict (one
equality plus eighteen item checks). Four are invalid detached-room reward /
crafting fixtures, and one is the incomplete package fixture. These boundaries
are retained explicitly rather than converting fixture failures into game bugs.
The raw probe remains outside Git. Rendered acquisition checks remain open.

## Saved selections

Source review finds the menu selection is session-local, not a persisted profile
default. A run with no explicit content-group selection reads current defaults.
An existing run's explicit off selection survives a production RunState
serialization round-trip unchanged; the menu also retains a deliberate
nonempty off selection. No saved choice has been overridden or migrated.

## Owner decision needed / current next action

A clarification was requested after reproduction: allow a narrow exclusion of
these two intended route-only groups from merchant pools, followed by the two
default flags, or leave defaults unchanged pending review. The item is paused
at that concrete conflict while other queue work continues. The exclusions
have not been implemented. This is new finding
`BTH-FEAT-PACK-MERCHANT-001`, separate from the known item-effect findings.

The owner was informed before any shipment: Wedding Ribbon Favor and Rent-Party
Hat Pin still advertise +1 luck that scenario acquisition does not apply, and
Mags' Lined Sleeve still has a Slot bonus that Slots ignore. All effects,
prices and text remain under the existing pause and unchanged.

## Test comparison and NEXT

No executable source changed in this item, so the exact unchanged Daily/source
qualification is reused: full Smoke **10 pass / 1 fail**, baseline **9 / 2**;
all runtime/UI/performance stages pass, loader **832 / 0**, liveness PASS, and
the separate unchanged validator retry PASS with zero cache differences.
The first full Smoke cache-census failure remains retained.

NEXT still serves `070fc937ad69de8d152b0dddae769f5206704821`, while the source
head awaits the existing cold-import qualification requirement for the prior
requested audit CSV edit. No new default behavior is claimed as committed,
delivered or accepted on NEXT. No pipeline guard was changed.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-pack-off-runtime, uf061-pack-conflict-proof, uf061-pack-probe-catalog-review, uf061-daily-smoke, uf061-daily-validator-retry2.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-pack-conflict-commit\evidence\raw-evidence-index.json | 7641f15aafc175a692d8c53f3214afe674f8bb321cd26b6d079d45183c3093e7 |
| E:\CodexQA\BTH\runs\uf061-pack-off-runtime\evidence\worker.log | 9b2e9259f593974f58d9162358b677124a3c55bb6f6b67291128e8ac1b5fb6c1 |
| E:\CodexQA\BTH\runs\uf061-pack-conflict-proof\evidence\classification.json | 61cb7a29d2b0745b7b2a08f00bcf04afb5313f890deb4716a18e6119c6ec84b8 |
| E:\CodexQA\BTH\runs\uf061-pack-conflict-proof\evidence\pack_routes_probe.gd | af42701c009fce30a4965786c2f6a9866e16ce1a0b10d991084dc86fb465d426 |

## Qualification diagnosis correction, 2026-11-12

The initial CSV attribution was an unverified inference and was wrong. Exact current Git input rows, using the unchanged classifier exclusions, show only `README.md` differs from served 070fc937; both inventories contain 1420 rows. The required FEAT-04 README closure note is included by that classifier. Files under `docs/`, including the Crossword CSV, are excluded. The refusal itself and pending delivery remain factual; no pipeline rule was changed. Exact raw receipt: `E:\CodexQA\BTH\runs\uf061-next-exact-input-diff\evidence\exact-import-input-diff.json`, SHA-256 `7ded8ae92d9a8676ce5b96e88ef3c76d76e99466b2b25429a89ecb000b96625c`.
