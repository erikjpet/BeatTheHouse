# Bar V4 canonical metadata patch

Review-only source artifact. Nothing in this directory applies the patch or activates TEST.

`canonical-source.patch` contains exactly 25 absent UID sidecars and three one-line root header edits. The 20 PNG import sidecars retain the exact baseline UID and import settings; the five script UID sidecars restore the same immutable baseline bindings. Original source scene files are retained, adding only the native-supported `unique_id` attribute. No ResourceSaver-generated scene replaces an original file.

`uid-cache-check.patch` separately tightens the existing build adapter: it compares the complete 1,605-entry UID mapping against the retained baseline, including when cache serialization bytes differ. The strict PCK change allowlist is unchanged.

`provenance.json` records every affected path, expected prior absence/hash, exact proposed hash, unchanged image/script source hashes, native discovery evidence and the full baseline UID map. Run `verify_patch_inputs.py --source-root <art-worktree> --mode before` before application and `--mode after` afterward. These commands only read files. Apply the two patch documents only after review, then force-add the 25 ignored sidecars when committing the scoped canonical metadata change.

The approved Bar PNG stays `a870d3652a72d3ebb5067fe9e46b412f3c2a5b938a40e4c3b2cf72e0be7a2408`; its 19-payload seal stays `e001ad4d76344f0bb2e0542a21fa3f4936656c8c2a63ace475a6294cb9ca723e`. UID sidecars and scene metadata are outside that art payload seal.

Native probe29 remains FAILED because its whole-bundle comparison failed. Its native text saver did emit the three `unique_id` headers and retain all three root IDs; this is syntax-discovery evidence only. Fresh guarded import/export and the unchanged strict PCK comparison must establish acceptance. The failed first build remains retained.
