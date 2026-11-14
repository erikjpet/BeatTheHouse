# Gas R12 source backup

NON-ACTIVE WORK IN PROGRESS. Not passed, not enabled, not approved for TEST deployment.

This backup protects the substantial reference-driven pixel/material work while the exact runtime audit continues. It does not modify active manifests/assets. Parent .gdignore prevents editor import, and every current export preset excludes review_artifacts.

Exact R12 package SHA256: 1e9a88be562db041248d4561619d0110d0b267310f42be25acd362bfae64b560. All16 sealed payload files are retained byte-exact. Archive SHA256: 7f63d6b1b622b35c78bb648e7aaa75f93e9615c857b6f6f07edae9da9dcb8f01.

The archive includes all16 exact historical R7 inputs, R9 background, frozen original native material source, corrected R12 trial payload, public hash snapshots and the deterministic Pillow assembly recipe. Private Library IDs are omitted from metadata only. The original seal and original/copy recipe hashes are retained; pixel operations are unchanged.

To reproduce, use a new admitted E: QA workspace and the repository storage/launch gates. Arrange the archived R7 inputs and R9 background under the historical packages names expected by the recipe; the archived R7 input seal retains complete required structure with private reference metadata redacted. The pixel operations use R7 payloads, R9 background and frozen original image only. Adjust historical input/tool-root paths for the new admitted workspace, then run the recipe with its storage-manifest environment. Generated payload identities must equal the R12 public snapshot. Output descriptive provenance may differ after metadata redaction/path substitution. Do not execute the recipe in production or activate its output without the latest full exact audit.
