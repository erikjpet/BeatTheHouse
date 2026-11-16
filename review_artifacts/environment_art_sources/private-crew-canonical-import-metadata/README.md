# Private Crew canonical background import metadata

Task BTH-ENV-SPATIAL-PRIVATE-001. Review only; source sidecar is absent and unapplied.

This proposes exactly one full978-byte W2 donor sidecar for `assets/art/environments/punchline_back_room/background.png.import`. It preserves UID `uid://cnx5mvyx76m4p`, authenticated against the actual immutable7b PCK, compiled CTEX and full1605-entry UID map. It creates no replay or counter metadata. All seven native/default-low animations and full room JSON/index stay unchanged.

`canonical-source.patch` contains an absolute Add File target in the art worktree. Only root applies it after independent review. The stdlib verifier prints JSON only, writes nothing and starts no child. Root runs each check through fresh admitted E storage and capped Job, retaining stdout and its exact closed receipt.

Before (explicit Python310, under guard):

```text
C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/private-crew-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before
```

After root applies the exact patch, run the same verifier with `--mode after --before-proof E:/CodexQA/BTH/runs/<closed-before-run>/evidence/worker.log`. The after check admits only the one sidecar addition and requires the paired8 PNGs, full JSON/index and every prior Private-prefix file unchanged. Snapshot hashes are paired observations, not permanent pins against later authorized art.

Provenance contains the exact PCK/manifest/cache/UID/source/CTEX/MD5 bindings and creation-time10-file inventory (9room+index). Root must independently bind the before stdout to its closed guarded producer; an arbitrary matching JSON file is insufficient.

No patch application, E write, QA/runtime, profile/save change, art activation or TEST delivery was performed by this artifact author. This metadata does not approve candidate art or native release.
