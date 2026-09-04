# playtest06_2 Final Evidence and Owner-Build Custody

Status: **TOOLING READY — do not run until env06_8, integ06_1, the balance
follow-on, and perf06_1 share one frozen product candidate**

This is test and handoff custody, not release work. It performs no version bump,
tag, distribution packaging, upload, or publish operation.

## Freeze and build

From a clean worktree whose HEAD is the exact product candidate:

```powershell
$candidate = (git rev-parse HEAD).Trim()
$tree = (git rev-parse "$candidate`^{tree}").Trim()
git status --short

powershell -NoProfile -ExecutionPolicy Bypass -File tools/playtest06_owner_build.ps1 `
  -CandidateCommit $candidate -RequireGodot
```

Required local outputs are `builds/windows/BeatTheHouse.exe` and the complete
`builds/web` directory. Required retained evidence is
`docs/plans/evidence/playtest06_2/owner_build_manifest.json` plus the adjacent
Windows and Chrome smoke reports. Commit those three files without committing
the ignored local build directories.

The owner command refuses tracked, staged, or nonignored untracked files before
and after the run. Its Web smoke performs the required fresh distribution export
itself with `-NoPackageFreshExport`; `-SkipExport` is not valid for this custody
path. Both smoke reports bind the candidate commit/tree, actual platform, pass
result, and aggregate export identity.

## Route evidence

Every verified named seed needs, per actual platform used:

- one committed `beat_the_house.playtest06_runtime_trace/v1` JSON artifact;
- one committed `beat_the_house.playtest06_owner_route/v1` JSON report;
- the exact candidate commit/tree, seed id/value, actual platform, and committed
  owner-build-manifest SHA-256 in both files;
- ordered public actions, zero dead interactions, no soft lock, and a typed
  coverage witness for every claimed id;
- a witness action index, visible result, required outcome type, runtime trace
  path, and runtime event id.

The referenced runtime event must repeat the witness action index, coverage
field/id, outcome type, and visible result, and its action id and visible result
must match that indexed public action. FINAL parses both smoke reports, rehashes
every owner-build tool and local export file, and verifies the locked Web
template identity; opaque or substituted JSON blobs do not qualify.

`FULL-RUN-CONTROLS` needs separate Windows and Chrome reports. A coverage string
without its action-indexed runtime event is rejected. Scenario representatives
must cover every live pool, and every authored phase-graph branch of each chosen
scenario must have its own aftermath witness.

Place the final manifest at the only qualifying path:
`docs/plans/evidence/playtest06_2/final_seed_manifest.json`. Commit all evidence
and the manifest, leaving product source unchanged from `$candidate`.

## Final consumers

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/playtest06_owner_build_contract_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/playtest06_2_seed_manifest_contract_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/playtest06_2_seed_manifest_contract.ps1 `
  -ManifestPath docs/plans/evidence/playtest06_2/final_seed_manifest.json `
  -RequireFinal -ExpectedTestedCommit $candidate
```

FINAL reads the committed manifest and committed evidence blobs. It also hashes
the live local build outputs and rejects any replacement, missing file, staged
mutation, uncommitted mutation, non-ancestor candidate, or product change after
testing. The playtest handoff may cite a pass only while those checks remain
green.
