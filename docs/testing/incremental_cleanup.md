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
