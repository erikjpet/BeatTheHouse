# Kitty Cat Lounge background canonical import metadata

This review-only proposal contains exactly one positive addition:
`assets/art/environments/kitty_cat_lounge/background.png.import`.
The absolute artifact folder, all four destinations, wrong-main artifact folder
and source target were absent at preflight; every existing ancestor was an
ordinary non-reparse directory. Nothing is applied during preparation.

The full-settings own W2 donor is974bytes, SHA256
`7ecc922f12cf6d819ede3fed493b8bece7a15c43ed523f12d67a3217ef30a54a`, UID `uid://7p2xudakw8lc`.
The actual packed remap is198bytes and is separately authenticated; it is not
the donor copied by the patch. Authority is the immutable W2 source7b manifest
SHA5855381f... and PCK SHAa84ed267..., including actual bounded payload bytes,
CTEX SHA256/MD5/length, raw PNG SHA256/MD5 and exact MD5 record.

The verifier also authenticates the complete1605-entry UID cache/map and actual
224-class-name/path cache/map. Real class-map canonical JSON is15071bytes with
SHA256 `1813424138ef329623c64c769891af4bbb2ba8b329330fb2fb19026cb503addc`.
Selected PCK payload MD5 is checked against the directory record after bounds
checks; source settings stay full, not exported minimal settings.

Current Kitty has30 room payload files:29PNG (27animations+background+counter)
and full room JSON. The global index is separate, making31. Room-only seal is
`017faffa1f02256046add9e21c2aae3358e2b9508eec15cbac942050f449cfb2`;
including index gives
`56e801e814a04f99a9f2b069b1923eea36462ed1ae4952222c6d4f39a0a360e1`.
Both use sorted path+space+SHA256 joined by LF without a trailing LF.
All27 motion entries default to low-detail inclusion. Creation-time hashes are
provenance; the immediate before/after pair freezes the current source bytes.

The stdlib verifier prints JSON only. It makes no directories, files, child,
engine, profile or network calls. Root must use the existing guarded worker
with fresh explicit E workspace/profile/temp/evidence/output,4GiB expected plus
20GiB reserve,12%CPU/2GiB caps, assignment-before-resume, kill-on-close and
closed-zero verification. No C fallback or existing saves.

Before separately reviewed apply:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/kitty-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before
```

Before requires the background sidecar ABSENT and snapshots every prior file
under `assets/art/environments/kitty_cat_lounge/`, all29PNG, full room JSON
and global index. Retain stdout as that run's `evidence/worker.log`.

Root MUST externally authenticate the exact immediate before Job command,
artifact hashes, successful closed capped receipt, storage manifest/claim and
stdout hash before apply. The verifier checks prior E proof location/schema/
identity/content; it cannot authenticate that external Job. Copied or manually
authored JSON is not authenticated evidence.

After independent artifact review and the qualified before check, root may
apply `canonical-source.patch` through normal apply_patch. Its sole Add File
target is absolute to the exact D art worktree, independent of working directory.
Use another fresh guarded Job afterward:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/kitty-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode after --before-proof E:/CodexQA/BTH/runs/<before-run-id>/evidence/worker.log
```

After admits exactly one donor-identical background sidecar and requires every
prior Kitty-prefix file, all29PNG/fullJSON/index byte-identical. Keep art
integration outside this metadata pair. This is a file-content proof for that
scope, not other rooms, the whole repository, metadata or permissions.
No verifier/QA/engine is executed or source patch applied during preparation.
Metadata identity grants no art/native/browser/TEST approval.
