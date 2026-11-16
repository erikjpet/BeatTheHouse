# Fixed delivered Grand Back Room TEST baseline

`grand_back_room_spatial_delivered_baseline.py` authenticates only the retained
Grand Back Room export `e07ca9280f4eebc531ef83dd50a79d76ec51ad23`, tree
`53f6647622e8b61a8fb50f3494887acd9e5fcd57`, from the immutable E: GBRBUILD stage.
It accepts no baseline argument and does not read current site pointers, current
D: art inventory, browser profiles or player saves. It has no network calls,
children, file writes, cleanup or moves. Imported validators disable bytecode.

Authority is the actual delivery index
`docs/testing/grand_back_room_spatial_test_delivery_20261116.json`, SHA-256
`a4076f22c2e7966fbe47173def682a8661a1d955075d2b4cf2c9a13efdea13ce`,
plus independently recomputed qualification and retained closed Job evidence.
The delivery index is an index, not a replacement for those checks.

## Authentication chain

- Exact stage manifest `00e1251b4e4580429fb57a764831ab8a7d7ad224f81a06b671c75415e467a215`
  and PCK `be8602a091e96f3f24cc146a5e611d47f493f10c06459bbb302cb701e04bd037`.
- Frozen GBR build approval `56c5aa87...` and separate native/art review
  `dda141ca...`. The unchanged GBR release qualifier authenticates all thirteen
  actual native phase receipts, current source identity/dependencies and the
  reviewed exact21-file package `e20695c6...`.
- Recursive actual High Limit certificate `c4855fca...`, then the frozen Grand
  and 7b qualification. This inherits the unchanged HL native-five authority
  boundary; it does not invent a fresh review of the earlier HL setup phases.
- Recomputed strict GBR PCK proof `56ba00e01a163e694078edfe84188f8ed9d424c05787660c8e1c51e09b58e602`:
  exactly eleven changed resources (nine GBR textures, the single-field GBR
  JSON resource and embedded identity), 2107 resources, 1605 UID bindings,
  equal UID/class cache bytes and all SCN/GDC/other-room/doorway bytes preserved.
- Full421 raw source and400 compiled texture linkage from the immutable source
  clone; native/export original-code bridge is separately **760 files**. The
  code count must not be relabelled as the full source or archive inventory.
- All fifteen exact build phases, five indexed evidence hashes per phase,
  actual full config `8b830135...`, exact helper/Python bindings, closed capped
  Jobs, assignment before execution, storage manifest/claim custody and default
  4 GiB writes plus20 GiB reserve. Retained archive bytes are rehashed.
- Actual publisher, before and served commands/receipts; thirteen immutable
  default-TLS streams (twelve payloads plus manifest), exact local manifest
  inventory and embedded identity. Served proof is
  `99d8bd4a4523b55ab289398e585cc19ef24e5ac1d0d038c3e7bb9d423d2c8d6c`.
- NEXT `6bfbecfb959b28a3148a1bafb44e85e0bee6ed0d` preservation applies only
  to nested lane observation clocks `2026-11-16T13:27:16.269168+00:00` through
  `2026-11-16T13:40:38.417290+00:00`. Enclosing worker clocks are different.
  Current NEXT is neither read nor asserted; browser acceptance remains NOT_RUN.

The certificate exposes all20 observed room seals and12 doorway seals. A later
room-specific policy must explicitly derive its protected set; this loader does
not guess the next room or authorize its art/build/publication. Partial selected
source archive scope, full commit/tree, selection digest, archive digest and
actual unchanged attribute-byte policy remain explicit. It makes no full-repo
archive or all20-room acceptance claim.

## Guarded execution owned by root

The source author has AST-parsed these files only. No helper/test/certificate
execution is claimed by the source handoff. Frozen prior modules are unchanged.

Run the worker with the exact qualified Python310 executable (SHA-256
`3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3`):

```text
C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/grand_back_room_spatial_delivered_baseline.py
```

Root must launch that command through maintained `bth_qa_guarded_run.py` in a
fresh admitted E: campaign with explicit workspace/profile/temp/evidence/output
paths, default4+20 GiB capacity, CPU1200/2 GiB Job caps, assignment before resume,
kill-on-close and closed/zero-active receipt. The guard supplies
`BTH_QA_EVIDENCE_DIR` and its prepared storage-manifest; the worker reconstructs
and validates Layout before printing JSON. The caller owns stdout evidence.
There are no CLI arguments and no direct unguarded invocation fallback.
A rejection prints structured `BASELINE_CERTIFICATE_REJECTED`, qualified false,
fallback false, and exits1. Success produces a canonical certificate fingerprint;
no future fingerprint is predeclared here.

The focused test command, also root-guarded, is:

```text
C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe -B D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/tests/test_grand_back_room_spatial_delivered_baseline.py
```

There are38 test methods. Fixtures use actual fixed metadata; pure declaration
comparison is explicitly not authentication. Tests cover wrong schema/source,
manifest/PCK/package/stage/maps, partial provenance,421/400 inventories,760 code
scope, strict/cache/UID changes, nested historical clocks, fifteen actual build
receipts, wrong hashes/PIDs/config, three publication Jobs, borrowed commands,
missing claims, caps/capacity/active-process changes, defaultTLS and missing own
admission. One full read-only `load_certificate()` test recomputes the entire
recursive chain; it can take longer than pure contracts. No test creates children
or files, and mocks alter only this new module's aliases, never frozen modules.
Root must record actual count/exit/Job closure; AST parsing is not a test pass.
