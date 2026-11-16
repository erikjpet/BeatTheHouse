# Grand Back Room canonical import metadata

Review-only artifact for `BTH-ENV-SPATIAL-GBR-001`. The patch adds exactly nine
currently absent import sidecars: background, two table fronts, sign and five
lamps. It does not apply itself or change PNGs, JSON, code, profiles or saves.

All full-settings donors come byte-for-byte from qualified W2 source for TEST
commit `7b284648642a896e534c8bfd53c8e7abbc55108d`. Provenance binds the actual immutable
manifest/PCK, all1605 UID mappings, the nine packed minimal import records,
compiled CTEX SHA/MD5, original PNG SHA/MD5 and source/destination MD5 records.
Packed import trailing NUL bytes are included in hashes. Room UID identities
are read from actual Grand Back Room data rather than reused from another room.

Observed original21-file seal: `065a5f98dfabb2b435bc31af76a0273921a370d1ebb9d9887ce6283c3231fbbb`.
Observed GBR JSON SHA: `bb6d6c293824bf9e6347dfba6db5df0e874469fc11e0d094b8f1bd108f45a067`.
Observed global index SHA: `11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24`.
These record creation-time source; later approved art is not permanently frozen
by them. The verifier compares a dynamic immediate before/after pair.

The stdlib verifier prints JSON only. Root must invoke it through
`tools/bth_qa_guarded_run.py` in fresh admitted E workers, retaining default4GiB
expected writes plus20GiB reserve,12% CPU,2GiB memory, assignment-before-resume,
kill-on-close and zero-active closure. No C: fallback. The verifier creates no
workspace, process, profile, download or file, and never starts an engine.

Before the separately reviewed application, guarded worker arguments are:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/grand-back-room-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before
```

Before requires all nine target sidecars absent. It snapshots every file under
the exact Grand Back Room art prefix, all19room PNGs, full GBR JSON and index.
The output must be retained as the before run's `evidence/worker.log`.

ROOT MUST authenticate that before run externally: exact verifier/provenance/
patch hashes and command, successful closed capped Job, storage manifest/claim
and stdout hash. The verifier checks E location, schema and matching contents;
it does not itself authenticate the prior Job. Do not treat a copied or manually
created JSON file as authenticated evidence.

Only after independent artifact review and a qualified before check may root
apply `canonical-source.patch`. After runs in another fresh guarded E Job:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/grand-back-room-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode after --before-proof E:/CodexQA/BTH/runs/<before-run-id>/evidence/worker.log
```

After requires exactly nine donor-identical sidecars plus the previous room file
map, unchanged19PNG/fullJSON/index bytes and matching inventories. Keep any art
assembly/integration outside this pair. This is file-content proof under the
GBR prefix plus JSON/index, not other rooms, whole-repository bytes, directory
metadata or permissions. Metadata equivalence grants no art/native/TEST approval.
