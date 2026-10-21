# Incremental code cleanup, 2026-10-21

Input: fresh `origin/main` at
`4d4eb062f3fb3fa547dd61e66c4e3dd9888e4ac8` (3,691 tracked files).
This is an ongoing file-by-file audit; unreviewed files are not certified clean.
Historical cleanup reports are leads, not deletion evidence. Existing saves,
generated media, native contracts, content and historical evidence are retained.

The concurrent Web freeze investigation covers `foundation_main.gd`,
`run_state.gd`, `environment_instance.gd` and physical/semantic finalization.
Changes there require coordination; this cleanup starts outside those paths.

## Batch 1: PCK directory search (deferred after qualification failure)

`tools/audit_pck_manifest.py` previously collected every `GDPC` offset in a list
and then parsed the list backwards. Search backwards directly, returning the
same last valid directory without retaining all candidate offsets. The public
function signature, validation, report shape and rejection message are unchanged.
No game code, package allowlist, save contract or native code changed. No runtime
speed claim is made. The attempted change was committed as `16d73614`.

Caller: `tools/export_itch.ps1` invokes the auditor after export; the packaging
contract invokes its Python regression. Both remain intact. There are no removed
symbols or files.

Verification:

- `tools/audit_pck_manifest_contract_test.py`: PASS, retaining audio allowlist and
  near-match rejections. Added PCK v2/v3 standalone, embedded, multiple-directory,
  invalid trailing signature and malformed-input cases.
- `tools/fixsweep06_1_packaging_contract_test.ps1`: PASS.
- Independent comparison with `4d4eb062` over 753 deterministic synthetic inputs:
  identical returned directory dictionaries or rejection type/message, including
  every byte truncation of the two generated valid fixtures.
- `git diff --check`: PASS.

The existing NEXT exporter also pins this auditor as a guarded native-reuse
input. Its attempt at `16d73614` failed qualification at 02:40:08 UTC and retained
the last good `4d4eb062` NEXT. Restore the exact qualified auditor source; retain
the useful directory-selection regressions. The reverse-search cleanup is
deferred until a separately reviewed build qualification permits it. No guard,
pipeline, native pin or watcher configuration is changed.

These are tool/fixture checks, not deployed gameplay evidence. Publication and
the broader coverage inventory are recorded as subsequent batches progress.

## Batch 2: unused generator imports

Remove unused `typing.Iterable` from the legacy scratch-art generator and unused
`random` from the trailer-card generator. Python AST name-use inspection covered
all 34 tracked Python files. Both removed bindings have no reads, string lookup,
star-export consumer or annotation use in their modules. Neither module exports
an import API; their commands still use the same main functions. The scratch
generator's live seeded `random` import is retained. No output assets are
regenerated, and all generator functions/content remain unchanged.

Verification: parse both sources and compare their full AST to the baseline
after removing only those exact import aliases; identical. This is a source
equivalence check; it makes no image-rendering or speed claim.

## Batch 3: redundant distance-label helper

`AttributeBadges._distance_value_text` returned its argument for all four named
distances and the fallback. Its only caller, `for_route`, already trims and
lowercases the input. Pass that normalized value directly and remove the private
identity helper. Keep every public badge API, glyph, tooltip and input policy.
The reference audit covered scripts, tools, scenes, resources, JSON content and
project configuration, including quoted method references; no scene, signal,
registry, serialization or editor consumer names this helper. It is not an engine
callback, and this module does not construct dynamic names for its helpers.

Pinned Godot 4.6 native comparison against the unchanged `7680b2f0` implementation
passed all 50 route combinations: known/custom/empty/whitespace/non-ASCII
distance strings and five risk classes. Full badge dictionaries were equal and
the source route remained unchanged. Both registries validated. The disposable
probe only renamed the baseline class to load both implementations together.
The muted, headless run took 0.453 seconds under a private 5% CPU/512 MiB Job;
output: `CLEANUP_BADGE_EQUIVALENCE PASS cases=50`. Job accounting was zero after
owned cleanup. No browser, listener or player save was accessed. This is native
projection evidence, not a visual Web playtest or a latency measurement.

## Batch 4: read-only badge input copies

`for_route`, `for_event_choice`, `for_service` and `for_lender` only read their
input dictionaries. Stop recursively duplicating those complete inputs, plus
the explicit route-risk dictionary, before extracting badge values. This follows
the existing `for_item` ownership policy. Keep the defensive copies in helpers
that append to debt/travel arrays and the newly built output dictionaries;
caller-owned data never becomes a mutable output.

Native comparison with the preceding implementation passed 325 cases covering
all 12 authored routes, 18 services, five lenders, 277 nested event choices,
12 empty/adversarial nested fixtures and one explicit risk override. Complete
badge arrays matched; source dictionaries remained unchanged both after the
call and after editing returned badges. Output:
`CLEANUP_BADGE_COPIES PASS cases=325` (0.391 seconds, private 5% CPU/512 MiB).
The required `animation_liveness_without_pointer_check.gd` also passed in 5.953
seconds under a private 12% CPU/2 GiB Job. Both Jobs reached zero naturally with
reader EOF and no forced cleanup. No actual gameplay, RNG, cash, heat, clock,
save, rendering schedule, or native behavior changed. The removed copy calls
are source evidence; no player-latency improvement is claimed.

## Batch 5: one game-script cache insertion path

Use `GameModuleRegistry.cache_script` for successful dynamic loads as well as
prewarmed scripts, removing the second copy of the capacity/clear/insert logic.
The public path is still trimmed and validated; null loads are still ignored.
Hits and replacements do not evict a full 32-entry cache, and a miss clears it
before retaining the new script, exactly as before. Module construction and
`setup` retain their existing type check and copy boundary.

The focused native cache check passed full-cache hit/replacement/miss, invalid
path, null script, non-game type and successful setup cases in 3.907 seconds.
The complementary Web startup source contract passed. No cache size, eviction
policy, public method or module definition changed. No speed claim is made.

`health06_1_hot_paths_contract_test.ps1` has an independent baseline failure:
CH-14 expects at least three `rng.shuffled` sites in `EnvironmentInstance`.
Running the same check in the untouched `4d4eb062` main checkout reproduces the
same failure. Leave both the assertion and the concurrently investigated
environment implementation unchanged. This failure is not counted as a pass.

## Batch 6: shared badge tooltip and panel style

The world-map controller duplicated the badge row's tooltip fallback and panel
style builders exactly. Expose those two existing row helpers as `tooltip_text`
and `cell_style`, and call them from both consumers. The world-map already
depends on `AttributeBadgeRow`; no new dependency or cyclic load is introduced.
The removed names were private helpers with only the replaced local call sites.
Scripts, scenes, resources, content, tests and tools contain no other references,
including signal/Callable strings. All existing public methods remain available.

Native comparison passed 107 cases covering every glyph's label/description
fallback, explicit/overlapping/empty tooltip text, all style colors/margins/borders,
and both contrast palettes. Each call still creates an independent mutable style.
The baseline adapters were loaded from disposable class-renamed copies only.
The check took 0.391 seconds under a private 12% CPU/2 GiB Job, which closed
naturally with no force, reader EOF and zero active processes. No control sizing,
tooltip wording, selection behavior or drawing schedule changed.

## Batch 7: load-check compile failures

`tools/gdscript_load_check.gd` treated every non-null result of `load` as a
success. Godot can retain a `GDScript` resource after a parser/compiler failure,
so the old checker emitted `passed:true`, zero failures and exit 0 alongside
real parser errors. The broad audit exposed this directly; those attempts are
not counted as passing evidence.

Require a Script resource that can instantiate, or a valid abstract script.
`Script.can_instantiate` and `Script.is_abstract` are present in the pinned 4.6
API. This only changes the checker: valid game code and supported abstract
classes remain accepted, while invalid scripts are included in the failure
array and produce exit 1.

Bounded native CLI regressions used disposable roots, not committed broken
scripts. A two-line `extends RefCounted` / `func broken(:` file produced exactly
one checked file, one `Failed to compile script` failure, `passed:false` and
exit 1. A separate root containing an ordinary RefCounted script plus an
`@abstract` class produced two checked files, no failures, `passed:true` and
exit 0. The expected parser diagnostic was retained in the negative-case
receipt. Both private 5% CPU/512 MiB Jobs closed naturally with zero processes.

The strengthened checker then passed all 214 production modules with no parser
or compiler diagnostics. Test fragments that require the split Foundation
runner are not certified by direct standalone loading; no fragment was deleted
or made less strict to obtain a pass.

## Batch 9: share card-copy coercion

Blackjack and Baccarat each repeated the inherited `GameModule._dictionary_array`
implementation in `_card_array`. Delegate to that existing conversion boundary,
retaining both method names, accepted variants, dictionary filtering and recursive
copy isolation. CardShoe's similarly named helper deliberately borrows dictionary
entries and is not interchangeable. No RNG draw, card order, normalization field,
settlement, payout or save format changes.

Reviewed CardShoe, PlayingCardRenderer and TableGameVisuals completely, including
shuffle/draw ownership, malformed card-code fallback, low-detail drawing, chip
selection and animation math. Retain those implementations. The two large game
files received targeted card-copy and caller review (hand normalization, draw,
settlement, discard/burn and presentation); this does not claim their thousands
of unrelated lines have completed semantic review. Neither wrapper is removed,
so scene, string dispatch, test and module interfaces remain available.

Verification on pinned Godot 4.6:

- Native comparison with the preceding game implementations: 3,312 equal results
  across malformed/typed input, repeated cards, hand normalization and every
  array in three authored v0.5.1 fixture saves. Nested metadata and repeated-card
  mutation checks preserved isolation. The first sandboxed run also emitted a
  Windows certificate-store access error; a normal-host rerun passed cleanly.
- Existing `blackjack_win_payout_settlement_probe.gd`: PASS, including a retained
  saved presentation timestamp, exactly-once winning payout and payout animation
  start/end boundaries.
- Existing Baccarat seed audit: 400 hands, 10 authoritative host commits and
  1,000 surface-state calls, `ok: true`, zero failures, native exit 0. An initial
  12-hand shortcut failed its unchanged statistical-rate bounds; rerun with the
  original 400-hand sample and seed passed. Its summary lacks a literal `PASS`
  token, so the private generic wrapper rejected that token check; independently
  validate the tool's structured report, clean engine output and exit instead.
- All native Jobs drained naturally with reader EOF, no forced termination and
  zero active processes. No user save/profile was read. No performance gain or
  visual Web playtest is claimed.

## Batch 8: coverage inventory and current source census

`incremental_cleanup_inventory.tsv` accounts for all 3,691 paths at the input
commit, with each original Git blob and byte count. No baseline path is omitted
or counted twice. The two new audit documents are additional reporting files,
so the resulting repository has 3,693 tracked paths. `docs/code_reference.md`
now reports the actual 214 modules (89 core, 78 UI, 47 game) and 11,421 production
functions. Both code and game documentation checks pass; no assertion was
changed to accommodate the census.

The TSV's blob and byte columns identify the immutable input snapshot; its line
column describes the screened text after cleanup. `-` marks non-text entries,
avoiding trailing empty fields. No media byte count is presented as lines of code.

### Review depth and evidence key

The levels distinguish what was actually done. `source-review` means targeted
code/contract review for that file, including changed helpers and their callers;
it does not claim every line of a large file was manually reread. `static-screen`
means whole-file structural/reference screening. `role-classification` means
the asset, generated evidence or UID role was established and retained; binary
contents were not rewritten. A `reviewed` row is not a claim of semantic
exhaustiveness or a proof that no future cleanup is possible.

| Level | Paths |
| --- | ---: |
| Targeted source/contract review | 79 |
| Static screening | 1,340 |
| Media/evidence/UID classification | 2,272 |
| Total baseline paths | 3,691 |

| Disposition | Paths |
| --- | ---: |
| No change | 2,339 |
| Reviewed by screening | 1,328 |
| Fixed | 11 |
| Deferred | 12 |
| Known baseline check issue | 1 |

The categories are 731 other authored files, 498 authored documents, 582 media
or metadata files, 1,658 historical evidence files, 11 first-party native files,
97 intentional fixtures, 82 historical tool files and 32 retained UID sidecars.
No tracked vendor tree was rewritten; installed third-party tools remain outside
the authored cleanup scope.

Evidence codes in the TSV:

- `S1`: structural/symbol/reference screen. Python AST checks covered all 34
  Python files; all 155 PowerShell and 11 JavaScript modules parsed, and all 231
  tracked JSON files parsed. Production GDScript load coverage is 214 files.
  Function-name occurrence and duplicate-body results are leads, not deletion
  proof; string dispatch, registry identity, lifecycle and persistence contracts
  must still be resolved for a candidate.
- `D1`: document role/reference screening; keep historical plans and decisions.
- `A1`: runtime or branding media/metadata; retain authored assets and their
  data/manifest/resource loading contracts, including generated audio/import
  settings. No binary rewrite or filename-only orphan deletion.
- `E1`: retained generated/historical execution evidence, not abandoned product
  implementation. `F1`: intentional source-only test fixture.
- `H1`: archived tool with historical source/reproducibility meaning.
- `U1`: retained script UID; no orphan-UID deletion based on mere age.
- `M:*`: the named targeted source/contract review. `C:*`: fixed by the named
  commit or batch in this report.
- `O1`, `N1`, `P1`, `B1`: the explicit deferrals/issues below.

### Explicit deferrals and retained candidates

- `O1`: seven runtime/finalization files overlap the Web-freeze investigation:
  `foundation_main`, `run_state`, `environment_instance`, `scenario_layout_resolver`,
  `environment_object_manifest`, `environment_semantic_inventory` and
  `environment_base_semantic_records`. Source screening is complete; edits are
  deferred to coordinated ownership. In particular, the sole newly found
  single-occurrence private function, `ScenarioLayoutResolver._substantially_overlaps`,
  and its `COLLISION_RATIO` constant remain intact. Proposed next step: finish
  dispatch/serialization/editor-reference proof with the finalization owner,
  then remove only that island with placement/semantic compatibility checks.
- `N1`: the four native core/header/render/step implementation files remain
  unchanged. Registered Godot methods, array layouts, solver ordering, SIMD and
  fixed-point semantics are native contracts. A proposed native cleanup needs
  separate exact compiler/runtime qualification; this pass does not imply a
  native build or measured solver improvement.
- `P1`: the tested PCK reverse scan requires separate exporter/native-reuse
  qualification. Its original source is restored exactly; the current pipeline
  remains qualified. Do not relax its guard to ship this cleanup.
- `B1`: the unchanged CH-14 shuffle-count source assertion fails on baseline as
  recorded in batch 5. Keep the test and environment code; reconcile it with
  the environment owner after verifying actual shuffle/RNG behavior.
- Shared canonicalization/bounded-copy helpers in Bar Dice and Grand Casino
  projections are deliberately retained. A shared codec proposal must prove
  unchanged fingerprints and supported old-save behavior for both authorities.
  Identical text alone does not establish interchangeable trust boundaries.
- Fourteen currently single-occurrence exported `Keys` constants remain public
  vocabulary. They are not deleted on a zero-caller search. The twelve scenario
  handler/renderer adapters also remain: their separate paths and extension IDs
  are validated allowlist identities, even where the forwarding bodies match.

No save/migration, RNG, payout, clock/heat, content-pack, native, engine/template,
exporter or audience input was changed. No tracked files, tests, owner caches,
ignored evidence, browser profiles or saves were removed. No latency or memory
benchmark result is claimed. Broader semantic review of screened-only files is
not represented as complete by this inventory.

## Release receipts

`16d73614` was refused by the unchanged qualification guard; previous NEXT was
retained. Restoration `42c0a0c1` was automatically promoted at 02:43:16 UTC.
Unused-import commit `7680b2f0370e1b2718bfa122898122f4ebb91fbf`, tree
`3538a2875a02120e755faa60cf6b15cc27bad552`, was promoted at 02:45:21 UTC.
At 02:46:15 UTC trusted LAN HTTPS metadata, NEXT redirect and nine payloads
(engine/native WASM, PCK and metadata/entry files) matched the promoted archive;
all required WASM MIME types were `application/wasm`. Archive SHA-256:
`0d589238c46094fc5d2ca392b458b337397fb95dc6f802ebe42bdf54cd9fa27b`.
Stable remained `0.6.0`; audience, itch and watcher configuration were unchanged.

The runtime cleanup group (`2f205b9f`, `5751d748`, `e47b341b`) was pushed together
after both the performance and storage owners released their finite holds.
The existing watcher promoted `e47b341bc45fd599ec36fcb55e9323bd05f4e3b9`, tree
`01fdd9de5a3ed9af9ea1e10015c4f8ba42efa649`, at 03:09:36 UTC. At 03:11:08 UTC,
trusted LAN HTTPS identity/redirect and nine archive-matched payloads passed;
archive SHA-256 was
`2c67bd4388f843d220ac18a8dbc15511f17081ddc43402e6e83b6d4f1a203f9e`.
All recorded build PIDs were independently absent at 03:11:12 UTC. The Web
performance owner received this exact receipt; its guarded trace did not run,
so this is deployed HTTP/provenance plus native behavior evidence, not visual
Web playtesting. Final tool/report publication is recorded in the task receipt.
