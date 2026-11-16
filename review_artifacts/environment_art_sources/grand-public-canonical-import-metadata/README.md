# Grand public canonical import metadata

Review-only proposal: `canonical-source.patch` adds exactly nine absent PNG
import sidecars. It does not apply them or alter art, JSON, scenes or scripts.
Every full-settings donor comes from the retained source workspace of qualified
Bar TEST source `7b284648642a896e534c8bfd53c8e7abbc55108d`. Its actual PCK,
manifest, nine compiled texture payloads and all 1,605 UID bindings authenticate
the proposal; see `provenance.json` for exact paths, hashes and decimal UIDs.

The original Grand manifest observation is SHA256 `5cc2d0c568552a88557f0f0eee89655bc86a5e73c535e822e09b267901044bcd`,
with 16 native animation entries and seven web low-detail entries. This proposal
does not freeze future approved art or JSON to those original bytes. The planned
single-field art-anchor change `casino_light_0.rect[0]: 250 -> 245` and future
PNG candidate hashes require separate approval and the strict Grand build profile.

`verify_patch_inputs.py` is a read-only stdlib verifier: no writes, children,
network or project-code imports. Launch it only through the existing admitted
`bth_qa_guarded_run.py`, using a fresh run ID and E evidence. With `--mode before`,
it checks all nine targets are absent and prints a current PNG/Grand-JSON hash
snapshot. Retain that complete JSON stdout in the guarded run's `worker.log`
or another admitted E proof file. Apply the separately reviewed metadata patch
only after its before check passes. With `--mode after --before-proof <E-proof>`,
the verifier checks exact donor sidecar bytes and requires the current nine PNGs
and Grand JSON to equal that immediate before snapshot. It never applies a patch.

Arguments for each guarded worker are `--source-root
D:/Projects/Beat-The-House/.tmp/environment-art-layers --mode before`, or the
same source root with `--mode after --before-proof <absolute-E-before-proof>`.
Run the pair around metadata application, before integrating another art change.
Do not call metadata equivalence art approval or TEST delivery.
