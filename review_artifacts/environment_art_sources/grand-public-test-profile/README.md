# Strict Grand public build profile

Code-only preparation. No candidate is approved by this directory, and no archive,
runtime, build or publication was launched to prepare it.

`tools/grand_spatial_test_build.py` is a thin entrypoint over the existing guarded
phase executor. Supply its usual explicit workspace/stage/commit/tree/engine,
native, template, Git, Node and baseline inputs, plus `--approval-json` and
`--approval-sha256`. The fixed baseline is the qualified Bar source
`7b284648642a896e534c8bfd53c8e7abbc55108d`, stage
`E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/.tmp/web-release-7b284648/stage`.
The default Bar profile and its existing exception policy are retained.

The approval document must be produced after independent numeric, native and
visual candidate review. `approval-template.json` intentionally has a pending
verdict and zero hashes; the adapter rejects it before making QA directories or
creating any child. Record the actual changed PNG subset, not all nine potential
paths automatically. Its whole JSON document must be SHA256-pinned on the CLI.

The Grand profile allows only the reviewed changed subset of background, two
table fronts, sign and five lamp PNGs. It requires the sole typed manifest change
`casino_light_0.rect[0]`: integer250 to integer245; every other value and type stays
identical, including16 native/seven low-detail entries and all timing/phase data.
The derived22-file seal includes all16 animation PNGs, background, allthree
counter PNGs, Grand JSON and the unchanged global index. The host front and
remaining11 Grand PNGs stay unchanged. Bar's19-file seal stays `e001ad4d...`.

The PCK resource set stays identical. Its exact changed set is the new embedded
identity, the approved Grand JSON resource and the CTEX resources corresponding
to the actual approved changed PNGs. No UID cache, class cache, SCN, GDC, other
room, doorway or import-remap byte changes are allowed. The entire1605-entry UID
map also must match. All421raw/400compiled links are checked against actual PCK
payloads. Already-qualified engine/native/WebGL assets remain byte-identical.

Apply the separately reviewed nine-import-sidecar source patch before committing
the approved candidate. Never copy old CTEX files or patch PCK data. Keep new QA
GDScripts under the existing ignored review-artifact tree or E-only QA copies;
the tools export exclusion does not prevent their UID registration during import.

After a qualified build, invoke `tools/verify_grand_spatial_test_served.py` inside
fresh guarded workers with `snapshot-before` and `verify-after`, the same approved
source/tree/package, the local qualified stage and the pinned approval document.
The latter phase also takes the former phase's `--before-evidence` file. It uses
the existing default-TLS byte-stream verifier and independently rechecks the local
Grand PCK delta. It never publishes or opens a browser.

The maintained publisher, embedded-identity helper and isolated TEST launcher
need no room-specific change: their full64-byte package identity field accepts
the approved Grand seal. Package derivation and the exact active-room binding
remain mandatory in the build/served profile. Main and NEXT are not targets.
