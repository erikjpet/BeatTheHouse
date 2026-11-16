# Kitty assembly adapter v3 — optional receipt-field correction

This is a new source-only adapter version, not another image generation or a
geometry revision. The one raw image, v2 stage plane,120 protected source accents,
6064 body-and-shadow base pixels, full8native-pixel material buffers, all donors,
counter,27motions/fullJSON/index,476+floor and directory-only write gates are
unchanged.

## Actual v2 test stop

Run BTH-ENV-SPATIAL-KITTYTRIAL-20261116-v2-tests01, Job9432, exited1 with zero
active processes. Its source fixture setup raised KeyError:'log_error' before
the geometry class ran. The test framework reports exactly4 tests executed plus
one setUpClass error. It does NOT report27 executed tests or a candidate.

Job SHA:00b90157b7b738884f55cc6c85bb67a8155d2756c79c87a280872bf55a4714c7
Log SHA:18869bb3521f4d52c3a27f4cd15d35b9704b3201bb5527d038129902f8bc8b38

The maintained Job writer omits optional log_error unless log draining raises.
The exact retained rawdecode Job6764 has no such key. V2 incorrectly indexed it
as mandatory inside failed_decode_provenance. V3 uses not job.get("log_error"),
matching maintained qualification semantics: absent/None is not an error;
nonempty drain-error data is still rejected. All other closure/cap/hash checks
remain intact, and rawdecode01 remains a failed phase after its exact PNG write.

Original recipe aed90e6c…656a and27test file2012744c…a4c3, their failed evidence,
old988/3be version and532decoder remain immutable. No old run ID is retried.

## Scope and evidence

V3 retains all27 v2 test method bodies unchanged and adds3 actual-receipt
regressions: absent optional field accepted, explicitNone accepted and nonempty
error rejected. Its source report records the actual4-test/setup-error history.
It separately pins both preserved v2 source files.

Geometry still comes from proposal506914a8…e3d9:
native deck corners(206,392),(998,392),(1004,456),(188,456), original maximum
window[188,390,816,86], fascia456..476. Source-preserving curtain/frame checks,
all6064 full17×17material neighborhoods,16944norm2x clusters/67776pixels,
raw donor strips and original controls retain their v2 contracts. Refer to the
unchanged v2 README for their detailed derivation.

All outputs use new v3 names: kitty-spatial-r1-assembled-v3,
kitty-spatial-r1-assembly-v3.json and kitty-spatial-r1-pixel-provenance-v3.json.
The prepared E workspace must still contain only raw_source before assembly.
No deletion, cleanup, overwrite, move, alternate drive or occupied-ID retry exists.

## Root commands

Run exactly this30-method test file in a NEW guarded capped Job:

~~~powershell
& 'C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe' -B 'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/test_assemble_kitty_spatial_candidate_v3.py'
~~~

Only after independent source review and passing guarded tests, root may execute
this worker through the maintained4GiB+20GiB storage/12%CPU/2GiB Job wrapper:

~~~powershell
& 'C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe' -B 'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/assemble_kitty_spatial_candidate_v3.py' --source-root 'D:/Projects/Beat-The-House/.tmp/environment-art-layers' --workspace 'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116'
~~~

These are worker arguments, not an uncapped launch authorization. Author performed
AST parsing and read-only receipt inspection only; no imports/tests/E job or
candidate assembly. Fresh guarded test success and assembly/actual-pixel review
are still pending. No native, art, browser, full-cycle, save/revisit or TEST
approval follows from this adapter fix.
