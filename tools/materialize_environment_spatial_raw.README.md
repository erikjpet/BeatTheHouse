# Exact generated raw PNG byte materializer

This is one file-only worker, not a launcher or campaign framework. Root must
run it once inside the maintained parent-prepared E Layout/launch claim and
authenticate the eventual closed Job: assigned before resume, CPU1200,2GiB,
kill-on-close true, breakaway false, no timeout/errors/truncated log, exit0 and
active0. The pending Job visible inside the worker cannot attest those final
facts; its receipt explicitly leaves their qualification to root.

Only the new module, focused tests and this README are authored. There is no
actual GBR R3 descriptor, guessed generated hash or placeholder art approval.
Root authors the descriptor only after Bar reports the ONE generated result's
actual identity. No new generation or retry is performed by this tool.

## Descriptor

Pass an explicit ordinary D descriptor file plus its full SHA256. It must be
inside one immediate named folder under
D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/.
All B64/prompt/provenance files must be distinct ordinary siblings of that
descriptor, not arbitrary source paths. No linked/reparse/stream paths.

Exact descriptor keys:

- schema: bth.environment_spatial_raw_descriptor/v1; room: one actual room ID.
- base64: path, sha256, bytes, data_url_sha256, encoding.
  Encoding is ASCII_BASE64_ONE_LINE_LF. Retain the actual canonical base64 plus
  one terminal LF; the returned data URL is data:image/png;base64, plus that
  line without LF. Both identities are independently checked.
- png: sha256, bytes, width, height, bit_depth, color_type, compression, filter,
  interlace, chunks. The actual ordered chunks each have kind, bytes and
  payload_sha256. Declare every chunk, including ancillary metadata/caBX.
- prompt and provenance: each has path, sha256 and bytes for actual preserved
  nonempty files. They are byte-bound evidence, not inputs to execute.
- original_controls: exact relative-path→SHA map for EVERY original room PNG
  plus data/art/environments/ROOM.json and data/art/environments/index.json.
  The original background is mandatory. Foreign room files, backslashes,
  traversal and stream paths are rejected. Source namespace is fixed D art
  worktree; controls never authorize source writes.
- output: workspace, png, receipt. Workspace is an immediate BTH-named child
  of E:/CodexQA/BTH/workspaces. The two relative outputs are named direct
  raw_source/*.png and raw_source/*.json files in that same workspace.

Descriptor exact hash binds every field; duplicate JSON keys/nonfinite numbers
stop. PNG is bounded32MiB, B64 is bounded48MiB, dimensions at most8192 each.
Full original file SHA, actual IHDR and complete ordered chunk payloads/CRCs
must agree. No chunk is stripped, rewritten, filtered or re-encoded. There is
no pixel decode, resize, palette conversion, optimization or caBX rewriting.
This proves exact transport/PNG structure, not art quality or pixel semantics.

## Parent invocation and outputs

Use canonical Python310 and the absolute D module, with explicit flags:

  --descriptor ABSOLUTE_D_DESCRIPTOR --descriptor-sha256 ACTUAL_DESCRIPTOR_SHA
  --workspace ADMITTED_E_WORKSPACE --raw-directory ADMITTED_E_WORKSPACE/raw_source

No sample hash/descriptor is supplied. Root declares the raw_source parent
directory as an output in its guarded launch, alongside the prepared evidence.
The current pending Job command, manifest, launch claim, cwd and E profile/temp/
home/evidence environment must bind this exact worker. Fixed storage/guard/
command helpers and prior Apartment0f55/House1300/Kitty532 decoders are hash-pinned.
The worker creates no parent workspace/profile/temp/evidence directory.

All reads and complete B64/PNG validation precede the single directory/write.
Immediately before mkdir, validate_layout sees the workspace DIRECTORY parent.
Immediately before exclusive PNG xb and receipt x, it sees raw_source DIRECTORY.
The completed PNG is NEVER passed as a directory after its creation. Input/
room controls/helper hashes and exact output bytes are rechecked before and
after receipt creation. The receipt is not standalone success authority:
the outer closed capped Job and unchanged custody must also qualify.

If raw_source, PNG or receipt already exists, the worker inspects existing
bounded regular bytes read-only and STOPS, even when their SHA is exact.
Nonregular/oversize outputs get metadata-only observation. It never recreates,
overwrites, retries, cleans up, deletes, moves or resumes a partial run. If any
post-write check fails, all outputs remain as evidence and the outer Job fails.
Root may independently inspect/preserve existing bytes; this worker cannot
convert that into an automatic retry. There is no network, child, C fallback,
Library operation, art integration, candidate approval or publishing.

## Preserved lessons and validation

Kitty532 had already written the correct PNG before a receipt gate incorrectly
treated it as a directory. That failed Job/log and existing PNG stay preserved;
the old decoder is never retried. Apartment0f55 and House1300 established the
parent-directory-only correction. This new worker leaves all three byte-exact
and applies their write law without depending on repeated historical execution.

Tests use synthetic in-memory PNG/B64 descriptors and bounded read-only source
checks; they are not generated room sources or approval records. They cover
whole/chunk hash and CRC separation, caBX/unknown-chunk retention, trailing bytes,
IHDR/B64/data URL identity, namespace/output/control rejection, strict JSON,
directory-only gates and read-only observation of existing exact bytes.
Author validation is AST/compile-only. Root separately runs guarded tests,
reviews the actual per-raw descriptor/inputs and admits the one materialization.
