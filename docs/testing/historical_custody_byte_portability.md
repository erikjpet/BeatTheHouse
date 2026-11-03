# Historical custody byte portability

`OPS07-LEGACY-CUSTODY-BYTES-001` closes the byte-portability finding recorded in
[incremental cleanup Batch 254](incremental_cleanup.md#batch-254-review-exact-historical-save-provenance-and-retain-custody-portability-finding).

The three `mid_0_6/*.custody.json` inventories were checked in with a UTF-8 BOM
and LF endings, but their unchanged provenance authenticates the original BOM
and CRLF bytes. The migration smoke loader falls back to these repository files
when the original historical custody path is unavailable, and correctly rejects
the different raw SHA-256.

The repair restores only those three inventories' original line endings. Each
file now reproduces its existing `custody_inventory_sha256` exactly. Exact-path
`-text` attributes keep Git from converting their authenticated bytes during
storage or checkout. Historical saves, provenance, recorded hashes and the
loader's strict raw-byte validation are unchanged. Paths listed inside the
inventories are not traversed.

Run the focused portable check from the repository root:

```sh
python tools/test_historical_custody_bytes.py -v
```

It checks all three original hashes and BOM/CRLF forms, confirms that LF
conversion still fails the original hashes, then stages a temporary repository
with `core.autocrlf=true` and verifies both stored blobs and checkouts under
LF, CRLF and input modes. It requires no engine, historical generator, save
restore or gameplay runtime.

This qualifies the portable custody-byte boundary. It does not claim a fresh
run of the broader historical migration or gameplay acceptance suite. The
earlier failing bytes and reproduction remain attributable to the pre-repair
source revision; expected historical hashes were not changed to obtain a pass.
