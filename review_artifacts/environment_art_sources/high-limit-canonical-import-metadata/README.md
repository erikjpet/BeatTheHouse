# High Limit canonical import metadata

Review-only artifact for `BTH-ENV-SPATIAL-HL-001`. Nothing is applied by this
folder. The patch adds exactly nine absent High Limit PNG import sidecars:
background, two table fronts, sign pulse and five lamps. It changes no PNG,
JSON, game code, profile or save.

Full-settings donors are copied byte-for-byte from retained W2 source for TEST
commit `7b284648642a896e534c8bfd53c8e7abbc55108d`. `provenance.json` binds all
nine High Limit UIDs/remaps to that build's actual immutable PCK, its complete
1605-entry UID map, compiled texture payload SHA/MD5, source PNGs and import MD5
records. Packed minimal import records are authenticated including their final
NUL; they are not the patch donors. No public Grand or helper UIDs are reused.

The observed original21-file High Limit seal is
`69c7023d0dae2468f73dc4c836d055d29592443c42cb72060901ef1390c97c93`.
Its JSON SHA is `3c2accd38cf268b33853bd3894e53b4def84e2bbf10f240a20de38ccb868fdd2`;
the global index SHA is `11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24`.
These are creation-time observations, not permanent pins on separately approved
future artwork or the proposed five decorative lamp Ys124→8.

The stdlib verifier is read-only: no file writes, project-code imports, children,
network or engine launch. Root must run each invocation through the existing
`tools/bth_qa_guarded_run.py`, using its explicit Python executable, a fresh E
run ID, default4GiB expected writes plus20GiB reserve,12% CPU and2GiB memory.
Use the admitted workspace
`E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLTRIAL-20261116`.

Before the separately reviewed metadata application, the guarded worker arguments
are:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/high-limit-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before
```

Retain its complete JSON stdout in that run's `evidence/worker.log`. Before mode
requires all nine targets absent and captures ten direct PNG/High-Limit-JSON
hashes. It also captures all19 room PNGs, both JSON/index hashes, and every prior
file under the exact High Limit art prefix.

Root may apply the separately reviewed `canonical-source.patch` only after that
check passes. This artifact never applies it. Run after in another fresh guarded
E job, supplying the immediate before stdout:

```text
<explicit-Python> -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/high-limit-canonical-import-metadata/verify_patch_inputs.py --source-root D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode after --before-proof E:/CodexQA/BTH/runs/<before-run-id>/evidence/worker.log
```

After mode requires exact donor bytes in all nine sidecars, exactly those nine
additions under the room prefix, unchanged prior files, and identical PNG/JSON
snapshots across the pair. Keep artwork integration separate from this pair.
Metadata equivalence does not approve art, native behavior or TEST delivery.
