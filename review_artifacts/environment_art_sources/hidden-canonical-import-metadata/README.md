# Hidden canonical import metadata

This review-only artifact contains exactly two positive sidecar additions:
Hidden background and the manifest's sole right foreground,
`counters/punchline_right_table.png`. Both targets were absent when prepared.
No sidecars are applied by this artifact. No PNG, JSON, runtime, profile, save or
prior artifact was changed.

Full-settings donors are copied byte-for-byte from qualified W2 for TEST commit
`7b284648642a896e534c8bfd53c8e7abbc55108d`. Provenance and the stdlib verifier
bind the immutable7b manifest/PCK, all1605 UID mappings, actual selected packed
minimal import payloads (including trailing NUL), CTEX SHA256/MD5/length, source
PNG SHA256/MD5 and exact source/destination MD5 records. These are Hidden UIDs,
not values copied from another room.

Observed original30-file seal is
`4c43fd48d180010a801f511c885d44b983c67c2fbb7fb4eac25c94fbdab027ff`.
There are28 room PNGs:26 distinct animation PNGs, background and one foreground.
The31 motion entries all default to low-detail inclusion. Full Hidden JSON and
global index hashes are recorded. Creation-time source hashes are provenance;
only an immediate before/after pair freezes current art bytes.

The verifier prints JSON only and imports stdlib only. It creates no directory,
file, child, profile or engine. Root runs it through the existing guarded worker
with fresh explicit E workspace/profile/temp/evidence/output paths, default4GiB
expected writes plus20GiB reserve,12% CPU/2GiB cap, assignment before resume,
kill-on-close and zero-active closure. No C fallback.

Before the separately reviewed apply:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/hidden-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before
```

Before requires both target sidecars ABSENT. It snapshots every prior file under
`assets/art/environments/small_underground_casino/`, all28 raw PNGs, the full room
JSON and global index. Retain stdout as the before run's `evidence/worker.log`.

Root MUST externally authenticate that before Job's exact command and artifact
hashes, successful closed capped receipt, storage manifest/claim and stdout hash.
The verifier checks the supplied E proof's location, schema, identities and
contents; it does not authenticate the Job itself. A copied or manually authored
JSON file is not authenticated evidence.

After independent artifact review and a qualified before check, root may apply
`canonical-source.patch` using the normal apply_patch API. It is the custom
apply_patch format, not a Git unified diff. Then use another fresh guarded E Job:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/hidden-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode after --before-proof E:/CodexQA/BTH/runs/<before-run-id>/evidence/worker.log
```

After requires exactly the two donor-identical additions, every prior Hidden
prefix file unchanged, and identical28PNG/fullJSON/index snapshots. Keep art
integration outside this pair. The proof covers those file contents, not other
rooms, whole-repository contents, directory metadata or permissions. Metadata
identity grants no art, native, browser or TEST approval.
