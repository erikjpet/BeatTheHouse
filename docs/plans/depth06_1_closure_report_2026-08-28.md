# depth06_1 exact-tree closure audit

Status: **BLOCKED**

Candidate: `b7e1ee6e` (`main`, clean before audit)

## Landed dependency heads

| Dependency | Exact landed integration |
| --- | --- |
| `env06_6` | `b014ca0a` |
| `env06_7` | `6318e00d` |
| `craps06_3` | `0fdcbe48` |
| `crew06_10` | `b7e1ee6e` |

## Reproduced passing evidence

- Static architecture validation passed on the combined Craps tree and again on
  the combined Crew tree.
- `craps06_3_depth_contract.gd` passed on exact main: five executable
  `game_ritual/1` profiles.
- `craps06_3_environment_integration_contract.gd` passed on exact main: five
  materially distinct responses and nine hostile-authority rejections.
- `crew06_10_depth_contract.gd` passed on exact main: ten seeds, five profiles,
  ordered-v1 engine, seven bounded public-information policies, save/reentry,
  tell receipt, interrupt, and restore checks.
- `crew06_10_scenario_registration_contract.gd` passed on exact main: five
  authored Punchline scenarios select five poker nights and the production game
  consumes those registrations.
- The env06_7 landing record accounts for 55 ids and records green package
  A/B/C contracts plus individually isolated D/E scenario shards.

## Blocking exact-tree evidence

The required complete dossier/uniqueness audit was invoked as:

```powershell
$env:GODOT_BIN='D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
.\tools\scenario_sequence_audit.ps1 -ExpectedCount 55 -RequireGodot `
  -Output res://.tmp/depth06_1/scenario_sequence_audit.json `
  -Report res://.tmp/depth06_1/scenario_sequence_audit.md
```

Godot `4.6.stable.official.89cea1439` hard-terminated with exit code `1` after
28.7 seconds and wrote neither requested artifact. The monolithic Craps suite
likewise passed static validation, import, and GDScript load before the Godot
stage terminated; the RTP wrapper hard-terminated without producing its JSON
report. No focused Craps, Crew, or isolated env06_7 assertion failed.

This is a release-gate blocker because isolated green shards do not substitute
for the prompt's exact-tree complete audit. The following independently reviewed
evidence is also absent for this candidate:

- randomized two-per-archetype playthroughs plus all maximal compositions;
- 28 minimum unlabeled arrival/aftermath contact sheets with independent cell
  identification and exact candidate provenance;
- complete native/Web paired traces for mandatory cases;
- full accessibility/input, save/migration, performance/liveness, and visual
  review on the exact combined candidate.

## Verdict

`depth06_1` must remain blocked. Marking it complete would waive explicit
release requirements and would misreport hard-terminated gates as passing.
The next remediation owner should first make the 55-scenario audit produce a
bounded report on the combined tree, then run and independently review the
remaining exact-candidate visual/native-Web matrices.
