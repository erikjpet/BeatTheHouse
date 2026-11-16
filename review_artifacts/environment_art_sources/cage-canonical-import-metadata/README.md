# Cage sign canonical import metadata

Review-only proposal: exactly one positive addition,
`assets/art/environments/grand_casino_cage/anim/cage_sign_pulse.png.import`.
The target, this artifact folder and all four artifact destinations were absent
at preparation. All existing destination ancestors were checked as ordinary
non-reparse directories. No source patch, PNG/JSON edit, engine, profile, save,
E write or prior-artifact change is performed by these files.

The full-settings donor is copied byte-for-byte from qualified W2 for TEST
commit `7b284648642a896e534c8bfd53c8e7abbc55108d`: SHA256
`c01de65224414a44c9155409991088f1b7cc620ebdc1ef253632ac961ee50812`,
996 bytes, own UID `uid://cnxu3ydc07y0l`.
Provenance and the stdlib verifier authenticate the immutable7b manifest/PCK,
all1605 UID mappings, the complete224-class-name/path cache and its UID closure,
the actual selected packed minimal import including trailing NUL, CTEX
SHA256/MD5/length, source PNG SHA256/MD5 and exact source/destination MD5 record.

Current Cage has23 room files:22PNG plus fullroom JSON. Adding the global index
makes24 logical source files. There are20 native motion entries,16 low-detail
entries and20 distinct animation PNGs, including the sole sign pulse.
The observed24-file space/LF/no-final-LF seal is
`5931da4fadda624928f8f7369aec0edeced899763dbaaaea890a9a2a912c815c`.
Creation-time hashes are provenance; only an immediate before/after pair freezes
current art bytes.

The verifier prints JSON only and imports stdlib only. It creates no directory,
file, child, profile or engine. Root runs it through the existing guarded worker
with fresh explicit E workspace/profile/temp/evidence/output paths, default4GiB
expected writes plus20GiB reserve,12% CPU/2GiB cap, assignment before resume,
kill-on-close and zero-active closure. No C fallback.

Before the separately reviewed apply:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/cage-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before
```

Before requires the sole target ABSENT. It snapshots every prior file under
`assets/art/environments/grand_casino_cage/`, all22 raw PNGs, the full room JSON
and global index. Retain stdout as the before run's `evidence/worker.log`.

Root MUST externally authenticate that before Job's exact command and artifact
hashes, successful closed capped receipt, storage manifest/claim and stdout hash.
The verifier checks the supplied E proof's location, schema, identities and
contents; it does not authenticate the Job itself. Copied or manually authored
JSON is not authenticated evidence.

After independent artifact review and a qualified before check, root may apply
`canonical-source.patch` using the normal apply_patch API. This is the custom
apply_patch format. Its sole Add File target is the absolute D art-worktree
sidecar path, so application does not depend on current working directory.
Then use another fresh guarded E Job:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/cage-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode after --before-proof E:/CodexQA/BTH/runs/<before-run-id>/evidence/worker.log
```

After requires exactly the one donor-identical addition and byte-identical prior
Cage-prefix files,22PNG/fullJSON/index snapshots. Keep art integration outside
this pair. This covers those file contents, not other rooms, the whole repository,
directory metadata or permissions. Metadata identity grants no art, native,
browser or TEST approval. No verifier/QA execution or source apply was done
while preparing this artifact.
