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
| Targeted source/contract review | 95 |
| Static screening | 1,324 |
| Media/evidence/UID classification | 2,272 |
| Total baseline paths | 3,691 |

| Disposition | Paths |
| --- | ---: |
| No change | 2,349 |
| Reviewed by screening | 1,312 |
| Fixed | 18 |
| Deferred | 12 |
| Unresolved baseline check issue | 0 |

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
- `B1`: the original CH-14 source-location mismatch recorded in batch 5 was
  resolved in batch 12. Runtime environment/RNG code and the three-shuffle
  requirement are preserved; new checks explicitly guard all three sites and
  the resolver delegation.
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

## Batch 10: return already-owned poker patterns

`CrewPokerModel.pattern` and `surface_pattern` iterate `patterns()`, which already
recursively duplicates the cache. Return the selected owned dictionary directly
instead of recursively duplicating it a second time. Retain the public cache
reader, copy boundary, exact member/state matching, condition order, frequency
math and RNG draw count. No observation packing, saved counter, poker evaluation,
NPC policy or content changes.

Native comparison with the preceding model passed 2,389 lookup, surface-pattern
and observation cases across all seven authored members and fourteen patterns,
unknown/whitespace identities, five hand shapes, seven actions, three leak
levels and three seeds. Selected dictionaries and post-call RNG snapshots were
identical. Mutating returned patterns left the cache unchanged, including two
nested-metadata checks. Observation recording, packed save projections and
empty legacy projections stayed identical. The required autonomous-animation
liveness check also passed; both muted capped Jobs drained naturally with EOF
and zero remaining processes. These are behavior/copy-ownership checks, not
a measured performance improvement or a visual Web playtest.

The source review also covered CharacterRoster, ScenarioExtensionDispatch,
Craps06EnvironmentBinding, RunStateSchema, CharacterChainModel and TutorialFlow
in full. Their deterministic stream derivation, adapter allowlists, authenticated
receipt/account/fact matching, historical input keys, story/layout reconciliation
and tutorial save migration are retained. Duplicate-looking authority copies and
legacy recovery paths are not treated as dead code. No edits to those files.

## Batch 11: owned duel projections and evidence filtering

`GrandCasinoDuelModel.current_edge` already owns a recursive schedule copy.
Return its selected dictionary without copying it again. In the Showdown model,
evaluate the read-only evidence condition before copying an accepted definition;
rejected definitions need no recursive copy. All returned edge/evidence records
remain independent of caller state and authored definitions. Preserve every
condition, candidate order, RNG call, selected count and action transition.

Both pure model files were reviewed in full. A native comparison with the prior
implementations passed 1,000 cases: malformed schedules, clamped hand indices,
nested return-value mutation, all 13 authored evidence definitions plus generic
condition fixtures, 64 fact combinations, negative/zero/oversized selection
counts, null RNG and two seeded RNGs. Outputs and RNG snapshots matched. Actual
initialize/call-out/apply-hand transitions also matched through terminal states.
The required autonomous animation check passed. Both muted capped Jobs reached
EOF and zero active processes naturally. No measured performance result claimed.

EnvironmentEventResolver was also reviewed in full, retaining its required-ID
selection, unique-class priorities/tie order, exact selection envelope and final
injected-RNG shuffle. It explains the CH-14 source-location mismatch: two full
shuffle sites remain in EnvironmentInstance and the third lives in this resolver.
No environment/resolver runtime source was changed.

## Batch 12: reconcile the CH-14 source-location contract

The baseline source contract counted three full shuffles inside
EnvironmentInstance even though event selection already delegates to
EnvironmentEventResolver. Count across those two audited sources, preserving
the minimum of three. Also require the exact pool shuffle, selected-candidate
shuffle and resolver delegation; retain the existing resolver-shuffle and
shallow-copy checks. No runtime source, RNG sequence, validation threshold or
other source-contract assertion is removed or weakened.

Verification used an exact source-copy fixture with all existing checks intact:
the canonical tree passed; individually replacing the pool shuffle, selected
shuffle, resolver shuffle or resolver delegation was rejected with its specific
diagnostic. Existing shallow-RNG-copy and drawn-card-isolation violations were
also rejected. All six negative cases failed closed, and runtime source bytes
remained unchanged. This is source-contract diagnostic evidence, not a new
gameplay or performance claim.

## Batch 13: one durable result ownership boundary

`DurableStore._result` deep-copied its payload immediately before passing it
inside `extra` to `IoResult.ok` or `failed`; both already recursively copy the
complete extra dictionary. Remove that first copy. Keep the IoResult ownership
boundary, result schema, error/outcome values, validation, installed-byte proofs,
primary/backup rotation and every rollback transition unchanged.

The full DurableStore and IoResult implementations and result consumers were
reviewed. Native comparison with the prior DurableStore passed 84 results across
success/failure codes, all outcomes, empty/typed/nested data and three authored
v0.5.1 save fixtures. Both success and failure retained nested payload isolation.
A disposable probe initially needed an explicit bool annotation; its corrected
version passed without changing runtime code or validation.

The existing `health06_1_durable_store_contract.gd` passed unchanged: write/rename
failures, all four transaction faults, byte-identical primary/backup recovery,
same-length valid/invalid primary proof checks, synthetic profile/meta/settings
and run-save recovery/trust, malformed-settings preservation, developer-placement
write failure and distribution-root rejection. It ran with private APPDATA and
test-owned paths; no player profile/save or shipped placement file was written.
The required no-pointer animation check also passed. All Jobs drained naturally
with EOF, no forced termination and zero processes; independent host census
confirmed closure. No measured performance gain is claimed.

UserSettings and the durability contract were reviewed in full. Keep recognized
schema-less migration, invalid-file preservation, strict known-value shapes,
accessibility/window/audio behavior and environment capture/restore unchanged.
Publication remains paused by the parent for the shared CS2 disk reserve.

## Batch 14: share the distribution path join

`PersistencePaths.directory_path` repeated the exact `file_path` implementation.
Delegate to that existing join policy, keeping both public methods and parameter
names. Development fallback, environment override validation, distribution/Web
epochs, root normalization and the single leading-slash trim are unchanged.
SaveService remains the directory caller; profile, settings, meta and placement
file callers keep their existing interfaces.

Native comparison with the prior module passed 1,728 root/flag/path/name cases:
empty/invalid/relative/user/absolute/UNC roots, slash and backslash normalization,
distribution flag spellings, development fallbacks and unusual names. Root and
feature decisions also matched. The pure probe performed no filesystem writes.
The unchanged durability contract passed root rejection and actual isolated run
save/backup/recovery paths with this implementation. No save location, migration
or audience policy was changed. No performance gain is claimed.

## Batch 15: snapshot run-game tallies once

`ProfileInventory._record_lifetime_stats` copied a run's complete game-tally
dictionary for its keys, then copied it again for every nonempty game ID. Retain
one detached dictionary and use it for keys and values. Keep key traversal and
trimming, numeric coercion/clamping, cumulative counters, output ownership,
legacy/forward-compatible fields, compact history and daily/terminal policies.
The public record method and FoundationMain's terminal caller remain unchanged.

The complete 745-line profile implementation was reviewed. Native comparison
with its predecessor passed 800 aggregation/public-result cases across synthetic
schema 0/1/4/5 profiles, unknown nested counters/fields, malformed/empty/mixed-key
game maps and 32-game maps. Repeated public terminal results preserved full
profile state, daily summaries, returned-data isolation and the 20-row history
cap. Known counter totals were also asserted independently. No live profile was
read or written. The required liveness gate passed; both Jobs closed naturally
with EOF/Job0 and an independent process census confirmed closure.

The existing profile-history performance probe was read and retained, including
its bound/forward-field assertions and 0.65 ms p95 gate. It was not run for this
aggregation-only change; no timing claim or relaxed benchmark threshold.

## Batch 16: borrow read-only career row inputs

CareerStatsViewModel copied nested dictionaries immediately before projecting
them into fresh scalar display fields. Use a private dictionary view at those
five read-only sites. Retain the outer daily/lifetime snapshots before profile
callbacks, along with all labels, ordering, history limits and malformed-input
defaults. The complete module and its profile callers were reviewed.

Native comparison with the prior module passed 43 cases: null and schema
0/1/4/5 profiles, empty/populated/malformed histories and challenges, direct row
limits, and output mutation isolation. A profile callback that mutates lifetime
and daily data confirmed that the retained outer snapshots preserve the prior
display. The required liveness check and documentation/source census passed.
Both muted capped Jobs drained naturally with EOF and zero active processes;
independent host census found both owned processes absent. No timing claim.

The report timeline, player text, widget constructors, UI art cache, segmented
meter and heat overlay were also read in full. Their seeking/resize behavior,
formatting, callbacks, accessibility metadata, asset fallbacks, animation and
reduced-motion policies remain unchanged. Inventory now records 102 targeted
source/contract reviews; the remaining static screens are not semantic signoff.
This batch remains local while the parent's publication/export pause applies.

## Batch 17: clip raster loops to their image

IconSpriteRenderer tested image bounds for every rectangle/circle pixel,
including every off-image coordinate. Intersect the iteration bounds once;
preserve ascending write order, circle inclusion math, line interpolation,
colors, glyph data and canvas drawing. Public texture/image factories and the
badge/canvas callers retain their interfaces. No scheduling or cache changes.

Native comparison with the prior renderer passed 7,444 exact RGBA8 image cases:
6,048 rectangles, 756 circles, 20 lines and 620 variants of all 31 authored
glyphs. Cases include negative/zero dimensions and radii, off-image coordinates,
three image shapes, five glyph sizes, two frame modes and two accents. Authored
sprite dictionaries remained unchanged. The required no-pointer animation gate
passed. Both capped muted Jobs closed naturally with EOF/Job0 and no forced
cleanup; independent host census confirmed both owned processes absent. This
proves pixel equivalence and eliminated off-image iterations, not a timing gain.

VisualStyle, both pure music decision helpers, InventoryContainerCatalog and
the Bar Dice/Craps/Scratch Ticket prop painters were also reviewed in full.
Palette accessibility, cue ordering/deadlines, stage and fill priorities,
catalog copy boundaries/capacity validation and full/low-detail prop visuals
were retained. In particular, music recipe normalization is repeated through
public methods; bypassing it requires a separate compatibility argument and is
not slipped into this raster cleanup. Targeted coverage is now 110 files.
Publication remains paused for the parent's shared capacity dependency.

## Batch 18: prepare reel visual weights once

BagOpenReelViewModel rebuilt the same tier weights, deep-copying every option,
for each of its 46 filler selections. Build cumulative weights once per reel.
The picker retains its two-argument entrypoint through an optional prepared
array and still returns an isolated selected definition. Preserve option order,
exact tier weights, seed text/hash, one RNG draw per filler, the 47-card sequence
and committed landing at index 38. Reward creation/service source is unchanged.

Native comparison with the prior model passed 8,192 weighted selections with
identical RNG snapshots, including prepared/default calls, empty/malformed/
shared inputs and authored bag contents. Another 108 complete models matched,
including all ten authored bags, seed fallbacks, reduced motion and input/output
isolation. The existing focused five-tier committed-item contract was extracted
verbatim into a private entrypoint: consume/grant once, landing identity,
showcase contents, reduced motion and save/reload exactly-one-instance all
passed with private test paths. The entrypoint initially mixed indentation;
correcting that disposable wrapper required no assertion or production change.

The liveness and documentation/source census checks passed. All four owned
processes (including the initial parse refusal) closed naturally with EOF/Job0;
independent host census confirmed absence. No measured speed gain is claimed.

The complete reel surface, CollectionItemResolver, cage counter projection,
environment header, collection browser, distortion overlay, item popup and
remaining two prop painters were reviewed. Their reward/instance semantics,
definition validation/cache isolation, callback snapshots, UI signals, reduced
motion, resize and visual-only boundaries remain intact. Hidden header options
remain required by its configured-option snapshot test; they were not treated
as dead simply because the compact presentation hides them. Coverage is now
120 targeted source/contract reviews. This commit remains local under the
parent's publication/export pause.

## Batch 19: inspect journal array presence without copying

RunJournalViewModel recursively copied inventory/debt arrays only to ask whether
they were empty. Use a type-checked presence helper at four such sites. Retain
all category precedence, terminal synthesis, callback ordering and copies passed
through label callbacks; those copies preserve an actual mutation boundary.

Native comparison with the prior module passed 27,648 category cases spanning
18 entry types, three heat deltas and eight shapes for each of three arrays,
including packed arrays. Another 147 complete rows/public lists matched through
active/ended/failed runs, with history unchanged. Two callback-mutation cases
independently required both gained-item labels after the source array was
cleared; the retained label snapshot passed. Liveness and source census passed;
both Jobs drained naturally with EOF/Job0 and independent process absence.
No timing result or history/save migration change is claimed.

CareerStatsScreen, CoachViewModel and FoundationHudViewModel were also read in
full. Preserve model ownership and ledger geometry, advisory input compatibility,
anchor variants and overlap ordering, exact versus quarter-hour clock policy,
objective/card/heat guidance and save-status presentation. Coverage reaches 124
targeted reviews; remaining static screens still require semantic review. Local
publication remains paused by the parent.

## Batch 20: inspect consequence presence without copying

The consequence visibility predicate copied each candidate delta array solely
to test nonemptiness. Inspect its type and size instead. Preserve all early
exclusions, scalar/ended detection, eight array keys, two dictionary keys and
message/type fallbacks. Other card-building and callback snapshots are intact.

Native comparison with the prior module passed 4,074 visibility cases and 42
complete consequence snapshots. Inputs remained unchanged. Independent checks
preserved empty-result suppression even with a message, game-enter suppression
even when ended, nonempty ordinary arrays and rejection of packed arrays as
array deltas. The required liveness gate passed. Both capped muted Jobs drained
naturally with EOF/Job0; independent host census confirmed closure. No timing,
save, gameplay or presentation semantics change is claimed.

The complete consequence module and existing UI05 design-system test were read.
The latter retains clock-item precision, widget cache identities, compact header
configuration, popup bounds, integrated actions and animated portrait contracts;
its assertions were not edited. Coverage now includes 126 targeted reviews.
Publication remains paused; independent source review continues.

## Batch 21: remove the unused HUD candidate adapter

Remove FoundationHudViewModel's private static `_candidate` helper. The complete
module contains only its definition. Known script/class clients use other
public methods; the run-UI registry loads this script by identity rather than
dispatching this helper. Tracked scene/resource signals, quoted method dispatch,
content/editor registries, subclasses and reflection consumers were checked.
The RefCounted helper is not an engine lifecycle hook, export or serialized
field. Keep class name, UID, public methods and all HUD policies unchanged.

The existing unmodified UI05 design-system test passed with the removal,
covering actual widgets, ordinary/Pocket Watch clock precision, retained status
icons, compact header configuration, popup bounds, integrated actions and
animated/reduced-motion portraits. The documentation census passed at 214
production modules and 11,423 functions. Its capped muted Job closed naturally
with EOF/Job0, and independent host census confirmed absence. This is dead-code
removal, with no runtime speed claim. Coverage remains 126 targeted reviews;
the already-reviewed HUD module is now classified fixed. Publication is paused.

## Batch 22: remove discarded ritual host serialization

`restore_snapshot` serialized the entire host before validation and after a
successful restore, compared the strings, then executed only `pass`. Remove
that discarded work and its otherwise unused private helper. The serializer's
canonical helper is pure. All actual snapshot shape/identity/fingerprint,
checkpoint/tail, trusted-ledger and runtime validation remains byte-for-byte
unchanged, as do state publication assignments and response construction.
This removes a no-op; it does not replace or weaken an integrity check.

Native baseline comparison passed 27 accepted/rejected restore cases over
different histories, with identical responses and state. The complete existing
ritual contract passed unchanged: malformed definitions, exactly-once/conflicting
intents, phase/RNG authority, hostile proposals, 32-round compaction, stale intents,
retained-tail replay, trusted-ledger refusal, resigned tampered snapshots,
reflection and layout neutrality. A source comparison also required that only
the discarded local/branch/helper were deleted. Liveness and source census passed.
Both private capped Jobs drained naturally with EOF/Job0 and independent process
absence. The initial prelaunch census preserved two October 19 playtest processes;
the admitted run required no new native owner. No browser, export or timing claim.

The full host and contract, Bar Dice ritual projection, collection-drop service,
surface-audio manifest, SaveService and scenario catalog were reviewed. Retain
authority and presentation separation, grant/RNG/idempotence policies, public-only
audio/voice rules, async save generation/byte proofs, old-save acceptance and
strict package/overlay validation. Coverage now records 133 targeted reviews.
Publication/export remains paused for the parent's capacity dependency.

## Batch 23: copy only the selected scenario overlay

`overlay_for` copied the complete overlays dictionary, then copied its selected
entry again. Reuse the existing read-only lookup and copy only the selected
entry. Keep the public detached-result contract, default catalog behavior,
whitespace lookup, malformed-input fallback and all package validation intact.
Update the internal fast-path comment to describe its remaining ownership
boundary accurately. No package, sequence, save-codec or content data changes.

Native baseline comparison passed 217 lookups, all 55 authored overlaid
definitions and nested mutation isolation, including malformed and typed
synthetic catalogs. The unchanged five-night Punchline registration contract
passed through its production game consumers. A separate comparison used the
unchanged save codec with current versus prior catalog dependency: three
tracked v0.5.1 saves decoded and re-encoded identically. All 55 seeded scenario
definitions also encoded/decoded identically, including exact int64 values and
byte-identical packed storage. No player save was read or written.

Liveness and source census passed. Four capped muted Jobs drained naturally
with EOF/Job0 and independent process absence. This removes whole-catalog copy
work; no measured runtime gain is claimed. RunSaveCodec and the registration
test were reviewed in full. CharacterOfferModel was also read in full and
retained: its eligibility callbacks, separate cycle RNG, nested save snapshot,
claim/wait/travel ownership and atomic candidate publication are outside this
cleanup. Targeted coverage reaches 136 reviews. Publication/export stays paused
until the retention owner confirms actual watcher activation and capacity.

## Batch 24: retain one detached heist plan per projection

`plan` selects an entry from an already deep-copied configuration. Return that
owned entry directly. `begin` and `plan_surface` now retain one plan lookup per
call, while rejecting unknown plan IDs before touching the lazy cache. Keep
public nested ownership, normalization, phases, hidden boundaries, release plan
selection and authored payout rules unchanged. No content or tuning changes.

Native comparison passed 160 baseline cases covering invalid IDs, lazy cache
state, known/unknown plan lookup, schema versions, restored phases, setup,
tombstones, payouts and nested mutation isolation. The existing heist surface
helper assertions passed unchanged in a private entrypoint, including phase,
decision, evidence, hostile proposal, public leak and payout ladder checks.
Liveness and source census passed. Both capped muted Jobs drained naturally
with EOF/Job0; independent 05:12:36 UTC census confirmed both PIDs absent.
No runtime speed gain is claimed.

The full heist model, both surface/authored-semantics contracts and CrewStateModel
were reviewed. The authored-semantics contract was read, not executed in this
batch; its governing SHA and hidden-field checks remain unchanged. CrewStateModel
retains proposal-only authority and private grievance boundaries. Targeted
coverage reaches 140 reviews. The retention owner confirmed actual watcher
activation and capacity admission at 05:08:55 UTC; publication can resume through
the existing capped watcher.

## Batch 25: remove the repeated item-domain membership check

`applies` already returns true when the supplied domain list contains the item
domain. Its final repeated membership check can only return false. Return false
directly, retaining global, exact-context, game and security alias precedence.
Remove three orphan comments left by earlier helper migrations. Keep virtual
method calls, modifier merging, input/result ownership and direct deltas intact.

Native comparison passed 1,536 contexts over eight domains, malformed/typed
domain-list shapes and three action kinds. Applicability, modifiers, complete
results and unchanged inputs matched the prior implementation. The existing
HEALTH06_1 correctness contract ran unchanged through the private inherited
entrypoint and passed package bounds, modifier conflict, clock and route checks.
Liveness and source census also passed; capped muted Jobs drained naturally.
This removes a redundant search, without a measured performance claim.

Twelve additional full source/contract reviews cover ItemEffect, Crew turn/play/
recruitment, their relevant contracts, duel ritual projection, terminal recovery,
delivery facade, environment placement and TownNetwork. Preserve opaque legacy
Crew saves and RNG weighting, proposal-only methods, authorization and cargo
rollback, Punchline recovery, exact slot geometry, rumor truth and seeded town
behavior. Coverage reaches 152 targeted reviews; this remains an ongoing semantic
audit. Native closure evidence is retained in the task receipt.

## Batch 26: copy only selected Crew recruitment definitions

Retain one internal immutable configuration/member-row view for member lookup
and recruitment/contact event ID lists. Public `config` and selected member
definitions still return deep copies; ID lists remain fresh ordered arrays.
Previously each query copied the complete configuration and all member rows
before selecting its result. Placement, eligibility, normalization, state
mutation, seeded presence/RNG and proposal-only authority remain unchanged.

Native baseline comparison passed 94 queries across authored and synthetic
malformed/typed member collections, duplicate IDs, unknown/whitespace IDs and
public path projections. Nested result/config mutation could not affect caches;
event/contact ordering matched. The complete existing WORLD06_4 recruitment
model contract passed unchanged through an inherited private entrypoint,
covering exact seeded primary/fallback binding, hostile proposals, trusted
contact state, persistence and hidden-field boundaries. Liveness and source
census passed (214 modules, 11,424 functions).

The first check caught a nonexistent helper in the uncommitted candidate. Only
that verified owned process was stopped, and its failed receipt was retained.
The corrected check and liveness Jobs drained naturally with EOF/Job0. No
failed candidate was committed. One additional full contract review brings
targeted coverage to 153. No measured performance gain is claimed.

## Batch 27: remove unreachable duplicate person classification

The early `person_object` condition includes actor, scenario actor, lender,
Numbers Silas and shopkeeper types, and returns on every branch. Remove three
later branches for those same types: they cannot execute. Preserve the earlier
classification policy exactly, including its precedence over exit tokens. Do
not activate the differing rules stranded in those dead branches.

A source proof required exactly the 14-line deletion with every remaining byte
of normalized source unchanged. Native comparison matched 8,624 synthetic
contexts and 23,333 dictionaries from authored `data/` JSON files. Three existing
semantic grounding fixture expectations also passed unchanged, and inputs were
not mutated. No private editor/profile/save data was accessed. Liveness and
source census passed. Capped muted Jobs closed naturally with EOF/Job0 and
independent owned-process absence. No geometry, cache, slot support, scene,
resource, finalization, public function or serialized field changed. Coverage
remains 153 targeted reviews; the previously reviewed placement file is now fixed.

## Batch 28: normalize the cargo projection input once

`cargo` normalized state and passed it to `physical_projection`, which normalized
it again. Delegate the input directly to the existing public projection and use
its empty-result rejection. Keep the normalizer, physical projection, closed
cargo output, save migrations, command journal and all host mutation paths
unchanged. No validation is bypassed or moved into an unchecked public API.

Native baseline comparison passed 596 valid/malformed states across all four
delivery modes, schemas 1/2/3, cargo states, terminal status and confiscation.
It also decoded six tracked v0.5.1/mid-0.6 saves and checked their delivery
projections (these fixtures have neutral delivery state). Synthetic legacy
states cover active migrated cargo. Cargo bytes, normalization and input/output
isolation matched the prior implementation. The full existing WORLD06_2 depth
contract passed unchanged through an inherited private entrypoint, including
ordered handoff, remote/wrong-target rejection, stash/retrieve, hold/pursuit,
tampered receipts, terminal paths and the 64-command journal bound.

Liveness and source census passed; capped muted Jobs closed naturally. Five
additional full reviews cover DeliveryRunModel and its contract, PoliceSweepModel,
TownState and ScenarioHostTransaction. Retain clocks, actual legacy migrations,
private sweep intel, RNG leases, canonical/CAS validation, account conservation,
bounded facts and host authorization. Coverage reaches 158 targeted reviews.
No measured performance gain is claimed. Publication follows existing capacity
admission and the coordinated runtime workflow.

## Batch 29: advance the sweep path queue with a cursor

Use an index into the append-only BFS queue instead of repeatedly removing its
front element. Visit order, sorted neighbors, first-discovered predecessors,
reconstructed paths and every reroute decision remain the same. This changes
only the private path helper; schedule generation, RNG, current/past segments,
host capabilities, intel and snapshots retain their existing behavior.

Native comparison covered all 64 undirected four-node graphs, including ties,
cycles, disconnected nodes, empty and unknown endpoints: 2,304 paths matched.
Another 768 public reroutes across three seeds matched complete results and
snapshots, with input/result isolation. The full existing WORLD06_5 sweep model
contract passed unchanged through an inherited private entrypoint: five costed
rungs, forged capability rejection, private intel, legacy restore, revisit,
wake expiry and ten-seed determinism. Liveness and source census passed, with
natural EOF/Job0 closure and independent process absence. No runtime speed
measurement is claimed. Coverage reaches 159 targeted reviews.

The completed cargo and queue commits remain local while D free space is below
the existing pre-export capacity floor. The retention owner received the exact
floor shortfall and dependency handoff. Source review continues without exports
or changes to resource guards.

## Batch 30: retain the music selector's owned stem dictionaries

Both weighted selection and retained compatibility selection already return a
deeply detached stem dictionary. Pass that owned value into the result instead
of immediately copying it again. Keep the picker, weighting, seed strings,
compatibility rules, recipe progression and metadata construction unchanged.

Native baseline comparison matched 2,304 complete projections across all three
authored tracks, three synthetic/malformed configurations, six heat levels,
four seeds and sixteen successive phrases. Input bytes stayed unchanged;
mutating returned stems did not affect the manifest or selected-variant metadata.
Recipe bytes matched, and the existing jazz section/contrast expectations passed
in the focused probe. This does not claim the entire Foundation music suite ran.
Required animation liveness and the source census passed. Both capped muted Jobs
closed naturally with EOF/Job0 and independent process absence. No runtime speed
measurement is claimed.

Full reviews of modal focus, the music selector and scenario semantic presentation
bring coverage to 162 targeted source/contract reviews. Modal gesture ownership,
signal reentrancy and accessibility behavior remain intact. Scenario authority,
action provenance and resolved overlay policy remain unchanged. Three tested
commits are preserved locally pending existing export-capacity admission; source
review continues.

## Batch 31: reuse the prepared trade-selection lookup

The collection-item model already builds an integer-keyed trade-position lookup
for state markers. Reuse its membership for trade button labels, enabled state
and disabled reasons instead of converting and scanning the same selected-ID
array again for each item. Keep public selection normalization, ordering,
five-item limits, trade eligibility, quotes and all service mutations unchanged.

Baseline native comparison matched 240 complete public models across five modes,
twelve selections and four selected keys, plus twelve direct helper models.
The fixture uses 168 instances from the actual collection definitions, bags,
special items, unknown definitions, duplicates, numeric coercions, mixed tiers,
over-limit and invalid IDs. Action payload mutations did not affect service
state. An initial private fixture used `null`, which both unchanged baseline and
current integer coercion reject with runtime errors; that run was rejected by
the runner and retained separately. Successful evidence covers supported ID
values, not acceptance of `null`. Production validation and tracked tests were
not changed.

Required liveness and the source census passed; the capped Jobs closed naturally
with independent process absence. Six full UI reviews raise coverage to 168.
Retain settings draft/cancel and accessibility metadata, modal search/focus,
storage and pawn identities, legacy host aliases, dynamic signal wiring, and
autonomous heat feedback. No measured speed gain is claimed. Publication remains
subject to the existing capacity floor; independent source work continues.

## Batch 32: share identical slot matrix coercion

The strip and grid normalizers contain identical code after renaming local
variables. A narrow source proof verifies that delegating `_strip_array` to
unchanged `_grid_array` is the only state-code change. Both method identities
remain available. Native comparison passed 24 helper values and 668 full state
normalizations, including 20 slot machines decoded from six tracked old saves.
Complete state bytes and nested input/output isolation matched. The state schema,
unknown fields, bets, active bonuses, RNG and storage paths are unchanged.
Required liveness and source census passed; capped muted Jobs closed naturally
with independent process absence. No measured speed gain is claimed.

Another 28 complete source reviews raise coverage to 196. Preserve immutable
slot-definition views, generation/RNG draw order, bonus state and old save fields;
pinball award caps, hook idempotency and fixed board geometry; measured scratch
regions, continuous masks and progress migration; Coin Pusher native/fallback
facade identities, physical conservation, progressive payouts and stroke-cycle
anchoring; Craps odds, vig and whole-chip rounding; video-poker reveal/hit targets;
and Blackjack's exact v3 ledger, recovery, replay and journal validation, plus
terminal-report resource release, reward locks and action signals. The duplicate
slot coercion is the only production change in this group; all other reviewed
files remain unchanged. The native probe and publication had first yielded before
launch while the user's Minecraft client was active, and resumed only after the
ordinary process guard was clear. No user process was changed. Remaining
static-screen and role-classification rows still do not imply full semantic
review. Heavy checks and publication will recheck the existing process guard;
source review continues meanwhile.

## Batch 33: report game labels

The terminal report looked up one game's display label by deep-copying the
entire game catalog, then copying the selected game again. Borrow the
type-checked catalog for that lookup and retain the selected-record copy.
Malformed catalog fallbacks, labels, money aggregation and public interfaces
stay identical. A capped muted comparison passed 612 source labels across six
catalog shapes, 30 complete money-row models and six complete reports decoded
from the authored 0.5.1/mid-0.6 saves. All inputs remained byte-identical.
Required no-pointer animation liveness passed. Both Jobs exited naturally with
empty process sets, EOF and independent process absence; no timing gain is
claimed. This source-only batch leaves NEXT pinned while the independent
performance worker prepares its finite trace.

Eight further full reviews raise substantive coverage from 196 to 204. Preserve
travel visibility, delivery next hops, opening hours, fares and the free closing
walk; report terminal ledgers, timeline reconstruction and reward gates; closed
environment object projections, physical identities and fixed bindings;
Foundation action host dispatch, stake economy and owned public results;
tutorial frontier/recovery, live anchors, dialogue and rollback lifecycles;
Coin Pusher fixed-tick backlog, native scratch ownership, feeder input order and
v1-v3 snapshots; world-sequence mount ownership, sealed commands, rehydration,
tombstones and terminal receipts; and game-ritual replay, commitment conservation,
causal receipts and rejection of raw authority. Only the report lookup changes.
The remaining screened/classified rows still require semantic review.

## Batch 34: meta-home scalar summaries

Two read-only snapshot reducers deep-copied each full instance/container record
to read only its instance ID or capacity. Use type-checked dictionary views for
these scalar reads; preserve integer coercion, positive-ID filtering,
deduplication, order, housing rules and zero-clamped capacities. Comparison with
the prior controller passed 216 carried-ID cases, seven capacity cases and 24
complete public home summaries using the real in-memory collection service.
Nested input bytes and service state stayed identical. Required liveness and
the source census passed; both muted 5% CPU/512 MiB Jobs closed naturally and
their recorded processes were independently absent. No speedup is claimed.

Five additional complete reviews raise substantive coverage to 209. Preserve
meta-home physical bindings, revision-cache behavior, free travel and shelf
quotes; inventory modal focus, selection keys, filters, sorting, ticket summaries
and action signals; the WebAudio PCM/ADPCM, active-voice LRU, explicit gesture
unlock, mix and node-release contracts; pinball's 120 Hz collision/RNG order,
tilt, flippers, bounded awards, event ring and transaction rollback; and the
inventory surface's selection reconciliation, paging, retained pools, card and
physical layouts. The inventory filtering duplicate-copy candidate is prepared
separately and is not claimed fixed by this batch.

## Batch 35: inventory filtering ownership

The filter receives deeply owned container and slot records from
`JsonCoerce._dictionary_array`, then immediately deep-copied each a second
time. Retain the already-owned records while keeping the separate item copies
that isolate flat rows from container items. All 480 complete model comparisons
passed across eight filters, three sorts, four queries and five empty, loose,
container and malformed-input shapes. Input models remained byte-identical;
mutating nested output slots did not affect flat rows or source inputs.
Required animation liveness passed; the two muted capped Jobs closed naturally,
and both recorded processes were independently absent. No measured speed gain
is claimed. Three separately tested commits remain local while the independent
worker runs its finite functional offer/note pair against unchanged NEXT.

The complete slot-presentation review brings substantive coverage to 210.
Preserve immutable reel definitions, bounded realtime patches, exact spin/reveal
identity, nudge timing, atomic pinball takeover, Buffalo replay and audio cues.
The two unused local bindings identified there remain a separate cleanup
candidate; no slot presentation code changes in this batch.

## Batch 36: reuse container geometry within one layout pass

Physical inventory layout normalized and copied the full container slots and
rebuilt its catalog rectangles/presentation for every visible slot. Prepare
that geometry once per container within the same synchronous layout pass.
The cache is local to that call; no persisted, inter-frame or authoritative
state is added. All 60 complete public layout snapshots matched the prior
surface across three sizes, two small-screen modes, physical/grouped cards and
five empty, single/multiple-container and malformed-slot models. Hit rectangles,
icons, selection, focus and paging were exact; source inputs were unchanged.
Instrumented normalization calls in those layout passes fell from 246 to 60.
That is a deterministic work-count reduction, not a measured timing speedup.
Required no-pointer liveness passed; Jobs closed naturally and all three
recorded test/observation processes were independently absent.

Three further full reviews bring substantive coverage to 213. Preserve map
camera drag/zoom, route clipping, replay, visibility and bounded texture caches;
the Grand Casino weak-host facade, live versus preview ownership, chip funding,
Players Card/showdown rules, seeded staffing and room save compaction; and
Numbers host capabilities, proposal-only actions, clocks, draw/settlement pool
caps, detection/leak/fix rules, depth custody and strict legacy restoration.
The duplicate Casino staffing loop remains a separate prepared candidate.

The map review reproduced a separate existing behavior issue: with a current
marker eligible for motion and camera bounds already settled, `_process`
returns before its pulse redraw branch. An unchanged-production observation
saw zero idle draws over 15 frames; an explicit redraw produced one draw,
confirming the observer was live. Record this as an issue, not a cleanup fix.
Proposed follow-up: restore a bounded autonomous marker cadence after settling,
preserve reduced-motion and map/hit geometry, and add a focused map liveness
check alongside the existing route-visibility checks. No map animation behavior
was changed here. The observation's initial process-creation transport error
was resolved by a fresh negative process/receipt check before its one retry.

## Batch 37: share deterministic Grand Casino staffing generation

`GrandCasinoRunFacade._grand_casino_staffing_for_day` repeated the assignment
generation loop already implemented by `_grand_casino_staffing_for_previous_day`.
Delegate that loop to the existing helper with the same clamped target day,
configuration and chance. All methods remain available. Both current-day and
previous-day evaluations, RNG stream keys, draw order, roster fallback, rotation
cues and detached results are retained. This removes fourteen duplicate lines;
it makes no speed claim.

The exact-source check proved the two prior loops identical modulo their day-bound
expression, the helper unchanged, and every other production byte unchanged.
Native comparison passed 336 complete staffing projections over four seeds, seven
day bounds, six roster/chance configurations and two retained-state modes.
Complete run save/RNG bytes and nested input isolation remained identical.
The comparison and required no-pointer animation check naturally closed with
exit0, reader EOF and Job0. Independent 07:11:56 UTC census found all recorded
process identities absent. An initial private baseline class had an incorrect
self return annotation; its failed log and bounded forced-cleanup receipt remain
preserved. Correcting only that private annotation allowed the unchanged checks
to pass; no production validation or tracked test was changed.

Full source review also retained `ScenarioOperationRegistry` unchanged: closed
handler inputs, cycle/depth/value bounds, atomic replay receipts, live target
ownership, priority/duplicate conflict handling, public tombstones and cleanup
authority are active contracts. Its callers include schema/runtime composition,
environment inventories, public semantic projection and authored contract tests.
Current baseline coverage is 214 targeted source/contract reviews, 1,205 static
screens and 2,272 role classifications. These levels do not claim exhaustive
semantic completion of the remaining authored files.

## Batch 38: remove two unread slot presentation locals

Remove unused local `feature_family` in `realtime_state_patch` and unused local
`mode` in `_pinball_feature_scene`. Their primitive dictionary lookups/string
conversions produced values that neither function read. The exact-source proof
confirms these two deletions are the entire production change. No method, field,
resource identity, saved key, animation channel or public result is removed.

The existing Godot load checker passed the single changed script with zero
failures. It naturally closed in the muted 5%/512MiB Job with exit0, reader EOF,
Job0 and no forced cleanup; independent process absence is recorded privately.
No elapsed-time improvement is claimed for removing these unread bindings.

The inventory now includes all 3,698 tracked paths: the 3,691 original baseline
paths plus the two audit reports and five recovery-helper/document additions
published by the preservation owner. Original-path blob/byte columns retain
their input identities; added rows identify their Git blobs at `784d4df4`.
Classification/screening of new rows does not certify a full semantic review.

Further full reviews retained TalkDock input/confirmation and tween ownership,
SealedActionHost transaction/replay authority, DeveloperPlacementStore durable
rollback/catalog-drift recovery and PinballFeature live clocks/save rehydration.
The unchanged EventModule has a diagnostic issue: at lines 505-565 the old
`pre_hooks` interval is effectively zero and `advance_turn` includes pre-hooks.
The performance owner received this finding; production timing/gameplay code is
unchanged. The settled map-marker redraw issue remains a separate proposal.

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

Card-copy and Crew-pattern commits `82ab54ea` and `81e93c04` were pushed after
the finite performance hold released. NEXT promoted
`81e93c0413ad8bc899215c79d0f6cacbf4ac4ef5`, tree
`123ae4351d9b9894d2dedab1f6b58e1efcadd6e9`, at 03:49:52 UTC. Trusted LAN HTTPS
at 03:50:42 matched all 15 archive files (including JS/worklets/icons), redirect
and WASM MIME types. Archive SHA-256:
`ac958f54950965092972a10117f123af80b0670ab5d6341109222286aac622ef`.
Independent 03:50:41 census found the build root/export Godot absent. Stable
remained 0.6.0; no browser/gameplay launch is claimed by this HTTP check.

After actual retention activation and capacity admission, fourteen separately
tested commits from `4257158e` through batch24 were pushed as a fast-forward.
NEXT promoted `54ff1dc5a5cc7fad8dec77935b84f2c7fcb9f98f`, tree
`6f05d5f9f0f4ca22028b2985e74da9a409c3546c`, at 05:16:03 UTC. Trusted HTTPS
at 05:16:27 matched all 15 archive files, redirect and WASM MIME types. Archive
SHA-256: `8890b968a437d013c28dd49b623d4d43c1329f21bd15205f5a65eb304421f7fc`.
The build root and all new Godot processes were independently absent. Existing
historical playtests remained untouched. The retention hook completed without
error (zero eligible/reduced sources). Stable remained 0.6.0. This is exact
deployed identity/assets plus the preceding native behavior checks; the
performance owner received the identity for its separate guarded Web trace.

Batches 25–27 were published as three separate commits after native closure and
a fresh no-Web-owner check. NEXT promoted
`4a0f0bfe16031841790346fe586c69af24ec2852`, tree
`e80a8dcc658c0c7f726255bb85c3bc74cf8dd7a8`, at 05:32:09 UTC. All 15 served
files matched the archive over trusted HTTPS at 05:32:49; redirect, WASM MIME
types and stable 0.6.0 passed. Archive SHA-256:
`974f20b68db14deb1bff63e349dd737eed4fec2d096ed2b1f3cfe45d8a57bfbe`.
Independent 05:32:47 census confirmed the build root and new Godot processes
absent. The existing retention hook completed with no error or reduction;
both source attempts were protected. Exact receipts went to performance and
retention owners. No browser/gameplay measurement is claimed by this release.

Batches 28-32 were published as five separate tested commits once capacity and
the ordinary process guard admitted publication. NEXT promoted
`3c1eba46610956b0b93dc50b40bd19a0bb1bb4bc`, tree
`b5602a66d8cc786e7af1360119fa865f3bcdef83`. Independent 06:15:15 UTC census
confirmed root 32228, observed import processes 44140/43628 and all new Godot
processes absent. Trusted HTTPS at 06:15:16 matched all 15 archive files, redirect
and WASM MIME types; stable remained 0.6.0. Archive SHA-256:
`0ac597f011d0b6a2e462ae14d53d6760bc13984c9cf056b40feadc156a1200d1`.
The existing automatic retention hook completed without error. Exact identity,
archive and actual closure receipts were handed to the performance worker for
its separate finite trace; no visual Web gameplay or latency result is claimed
by the cleanup worker's asset verification.

Batches 33-35 were pushed as three separately tested commits. NEXT promoted
`1d8c5cf932d29b798f86957494c2e23aecd6786d`, tree
`147338bc634af387bb984355a7bea353cfaf6298`, at 06:52:32 UTC. Independent
06:53:20 UTC census found root 16756, observed import processes 48632/30556
and all new Godot processes absent. Trusted HTTPS at 06:53:26 matched all 15
archive files, redirect and WASM MIME types; stable remained 0.6.0. Archive
SHA-256: `c41fef5093099550be5dd762261e88486df514c0e91a14503e396aeefd9799c5`.
The existing retention hook completed without error. Exact receipts went to
the performance and retention owners. The untested geometry candidate was
excluded from that push; its later proof is recorded separately above.

Batches 36-37 rebased cleanly over the preservation owner's helper/document
commits and were published separately as `ae64271f` and `784d4df4`. NEXT promoted
`784d4df4c4dd6b37ebc97dd04af0d71959f2ecda`, tree
`4fcbcbc055fc78e1bcb6c20a27090237bf848a39`, at 07:22:41 UTC. Independent
07:23:42 UTC census found root 24476 and all new Godot processes absent; the two
historical processes remained untouched. Trusted HTTPS at 07:23:43 matched all
15 archive files, redirect and WASM MIME types. Archive SHA-256:
`bc2163e817b6b66cbdfe586d0aad54ba5c18d90b14f8f5ba1143e15535479d4f`.
Stable remained 0.6.0 and the existing retention hook completed without error.
Exact receipts went to the performance and fresh-player browser owners. The
later two-local slot cleanup was excluded from this publication.
