# Observer contract preflight V2

This is a read-only gate for actual archived report contracts, before another
native campaign spends its runtime slot. It creates no directory, output file,
profile, child or engine. Run it only inside the parent's existing bounded
`bth_qa_guarded_run` Job; the parent's admitted evidence captures stdout.
There is no new launcher, fallback, source repair or engine admission here.

`preflight_case(spec, validator)` accepts the exact existing room function. It
authenticates pinned report/producer/Job/log/provenance/code bytes, actual WRITE
filename, actual schema presence (including deliberately absent schemas), unique
`--path`/`--script` and resolved producer, closed capped Job and strict clean log.
It calls the **unmodified full room validator first**, then checks declared
serialized header values and JSON shape, and rechecks every input byte.
No room's scenario/count/motion predicates are copied into this generic module.

`positive_then_controls(spec, validator, controls)` first passes that authentic
positive, then applies explicit single-path/value changes to in-memory copies.
The same validator and supplemental rules must reject each negative. No-op
controls stop. No modified JSON becomes an archive or a native observation.
The focused test class authenticates all real positives in setup before any
negative runs, so an unrelated bad fixture cannot make negative tests pass.

## First catalog scope

`review_artifacts/environment_art_sources/environment-spatial-observer-preflight/catalog.json`
contains17 pinned direct-engine positives:

- PrivateV3 current contexts, motion, lifecycle, Lucky and capture. Four original
  reports have no `schema`; Lucky has `bth.private_spatial_acceptance/v1`.
  Current BaseN4047 gives8184 checks. Its original producer GDs and current native
  type probe/phase/prepared records remain pinned; this does not rerun all21
  native cohort qualifiers or release approval.
- Kitty original contexts/motion:2N+734 with N7215,93/186 typed occurrences and
  native27/55 checks. All five original GDs and the parent's actual75-unit/135-
  parity qualification/receipts are pinned provenance. A fresh native capture is
  not created or inferred from those prerequisites.
- Delta original six-context/motion positives through the unchanged V2 policy.
  No failed V1 composite or67 unit fixtures stand in for new V2 native clock proof.
- Cage original Base and motion positives, with actualN7393 and actual filenames.
  Fresh candidate acceptance is not inferred from retained Base evidence.
- Hidden original R2 work3, effective hits, placement and strong-thin246 through
  the unchanged reviewed completionV2 functions. Strong-thin binds the rawbb4
  manifest plus the7192 Godot-serialized witness; it is not the51-check V4 law.

Unproduced fresh cases remain explicit. The root's newly produced HiddenV2
strong-thin observation is recorded outside this first catalog: its outer Job is
a Python continuation worker and its own controller remains the authority for
nested producer provenance. This helper does not pretend that Job is a direct
`--script` engine Job or requalify the whole continuation cohort.

## JSON and native proof

A JSON position such as `"(0.5, 0.5)"` is a string, never a native `Vector2` paint
target. Even a recorded native witness's `"Vector2"` type name is JSON text; the
pinned producer's actual type guard and existing room validator remain authority.
This preflight never reconstructs coordinates or promotes a JSON declaration into
a native value. It never compares raw Python manifest floats to rounded Godot
JSON as native identity. Exact same-representation witnesses belong to their
unchanged room validator; no epsilon, rounding or data substitution is added.

## One bounded preflight per next room

Use canonical Python310 and pass the actual reviewed catalog SHA256. For example,
inside a fresh parent-owned capped file-only Job:

```powershell
& 'C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe' -B `
 'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/environment_spatial_observer_preflight_v2.py' `
 --catalog=D:/Projects/Beat-The-House/.tmp/environment-art-layers/review_artifacts/environment_art_sources/environment-spatial-observer-preflight/catalog.json `
 --catalog-sha256=$ReviewedCatalogSha --room=delta `
 --case=delta-original-contexts --case=delta-original-motion
```

The explicit subset can return `REQUESTED_ARCHIVE_POSITIVES_PASS` while listing
fresh cases as unproved. Omitting `--case` requests the entire room catalog;
pending cases produce `INCOMPLETE_SCOPE`/exit2. Actual failures stop with exit1;
there is no guessed filename, sibling schema, mock report or alternate validator.
Neither result grants native/engine/art/TEST approval. The parent separately
qualifies the bounded preflight Job/log and decides the next authorized action.

Tests: parent guarded execution of
`tools/test_environment_spatial_observer_preflight_v2.py`. Source authors performed
AST/compile review only. This helper does not replace any frozen051/650 storage,
source, UID, runtime, cohort or release gate.

## Preserved V1 failure and narrow V2 change

Executed V1 and catalog are preserved in commit
30ad92faa06f753c4f18fa9d023c656c3e3dc493, tree
3915bf5148a383d9df4dffafcb63298529ee2615. The failure record is
docs/testing/environment_spatial_observer_preflight_test_stop_20261116.json,
SHA976ff14028e0fc68f4774ec25a03b2ad5a544b057dd34fd7018b7de44c312cb9.
Actual run BTH-ENV-SPATIAL-OBSERVER-PREFLIGHT-20261116-tests01 had
Job39596 exit1/active0, JobSHA3140e040f300edb98f000aba6bc706eccfaefbec5a6611051ce48cc164c8be4c
and logSHAa089cb5894717156e81f1609f05810a585170c66cf304d90efba7e1e4fd74d1b.
All17 actual positives passed setup;22 tests ran in7.888s with two failed
negative subcases. The inherited650 qualified_job alias does not reject
kill_on_close false or breakaway_allowed true. This was a generic gate omission;
no historical producer, room validator or archive positive is relabeled failed.

V2 adds exactly two typed predicates after existing qualified_job:
limits.kill_on_close is True and limits.breakaway_allowed is False. Missing
fields, nulls, numeric0/1, strings and containers cannot replace those booleans.
Frozen650/051 and all room validators remain byte-identical. Existing22 test
method bodies remain unchanged; only their gate import targets V2. Two focused
methods add missing/wrong-type regressions, for24 methods total. Shared setup
still proves all17 actual positives before any negative control.

The existing catalog47bc3bd41c5713a46925034fbea3875acff62e18a882175fb04c96ed20433345
is reused unchanged. V1 source/tests/README, catalog and failed Job/log remain
immutable. V2 author performed AST/compile-only and byte/AST reversal checks;
fresh guarded24 tests and any subset CLI qualification are root-owned gates.
