# integ06_1 final-candidate execution ledger

Status: **PREPARED — execute only after the shared Godot gate is released**

This ledger orders the remaining integration qualification so every result is
bound to one candidate tree and retained with its source identity. A zero exit
code is required for every executable step. Warnings, missing reports, absent
expected markers, timeouts, reruns on a changed tree, and manually edited
generated artifacts are failures.

## 2026-09-04 provisional pre-env checkpoint

Do not mistake the short checkpoint below for final execution. Frozen
`origin/main` at `49841960750a873707e79dbf6b5c7836041fcbf5` passed both
migration classes and the Crew binding reproduction. A determinism-harness-only
repair was committed as `d27b2deed37666d6853d879d70948d8e6fdfbd35` on
`codex/integ06-final-run`; on that exact tree, two independent 10-seed runs each
passed 560 checkpoints with combined hash `4043921713` and clean stderr. The
v0.5.1 matrix then passed 37/37 and the mid-0.6 matrix passed 3/3 again on the
same candidate.

The focused composition and real delivery proof both stop at the same first
env-owned product failure: `jazz_club_guest_legend_task_0` overlaps
`jazz_club_guest_legend_guest_legend` in normal and expanded-small layouts, so
scenario semantics cannot finalize for departure. Do not run the exhaustive
producer until env06_8 lands; it currently derives 50 required rows across
eight eligible archetypes and would repeat the same rejected production entry.
The native/Web terminal producer remains intentionally unrun.

Before final execution, use a fresh output directory and replace the two
placeholders below with the final env-inclusive candidate and perf06 profile:

```powershell
$head = (git rev-parse HEAD).Trim()
$profilePath = '<final perf06_1 profile path>'
$evidenceProfile = '<final perf06_1 evidence profile id>'
```

Then run this ledger from section 0 without reusing
`.tmp/integ06_1/candidate_d27b2dee`. On the observed host, budget approximately
15 minutes for Contracts, 1--4 hours for the 50-row composition producer and
its seed discovery, and up to 3 hours for fresh Web-native compilation,
Windows/Web exports, two native repetitions, and Web terminal shards. The
accelerated three-hour stability probe and full post-land gate are separate
required steps; these estimates are scheduling guidance, not relaxed timeouts.

## 0. Candidate custody

Run from the repository root with no other Godot process using this project.

```powershell
$candidate = (Resolve-Path .).Path
$godot = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$evidence = Join-Path $candidate '.tmp\integ06_1\final_candidate'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$head = (git rev-parse HEAD).Trim()
git status --short
git show -s --format=fuller $head
Get-FileHash project.godot,export_presets.cfg -Algorithm SHA256
```

Record `$head`, the branch, `git status --short`, the Godot executable SHA-256,
and the project/export-preset hashes in the final report. The qualification is
invalid if tracked files change except during the explicit generator-consistency
step; those changes must be reviewed, committed, and the entire ledger restarted
from the new HEAD.

## 1. Static and generated-content consistency

Run project validation first, then every environment package author/signer and
its executable contract. A clean candidate must remain clean after the authors;
that is the proof that checked-in packages and dossiers came from their checked-in
sources.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate_project.ps1

& $godot --headless --path . --script res://tools/env06_7_package_a_generate.gd
& $godot --headless --path . --script res://tools/env06_7_package_a_check.gd
& $godot --headless --path . --script res://tools/env06_7_package_b_sign.gd
& $godot --headless --path . --script res://scripts/tests/foundation/env06_7_package_b_contract.gd
& $godot --headless --path . --script res://tools/env06_7_package_c_author.gd
& $godot --headless --path . --script res://scripts/tests/foundation/env06_7_package_c_contract.gd
& $godot --headless --path . --script res://tools/env06_7_package_d_author.gd
& $godot --headless --path . --script res://scripts/tests/foundation/env06_7_package_d_contract.gd
& $godot --headless --path . --script res://tools/env06_7_package_e_author.gd
& $godot --headless --path . --script res://scripts/tests/foundation/env06_7_package_e_contract.gd

git diff --exit-code -- data/environments/scenario_sequences docs/plans/env06_7_package_*_sequence_dossiers.json
```

The package-E contract is the focused production normal, expanded-small,
reduced-motion, hit-overlay, obstruction, lifecycle, and save/restore gate for
the Delta Queen and Grand Casino fixes. The Crew production placements must
also be green in the supported Contracts runner in section 2; an ad hoc layout
probe is diagnostic only.

## 2. Supported Foundation qualification

Use `tools/check_godot.ps1`, which generates the marker-aware Foundation split
runner in `.tmp/generated_tests`. The previous Contracts attempt reached the
default 300-second hard limit, so this final run uses a stated 900-second bound.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_godot.ps1 `
  -Suite Smoke -FoundationSuite Contracts -RequireGodot -NoImport `
  -TimeoutSec 900 -ReportDir .tmp\integ06_1\final_candidate\contracts `
  -VerboseStages
```

Require the final report to show zero failures for `content`,
`crew_recruitment_contract`, and every other registered Contracts check. Preserve
the summary, stage reports, stdout, and stderr. After all integration work lands
on main, run the complete supported post-land gate with import enabled:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check_godot.ps1 `
  -PostLand -ExpectedMain $head -ReportDir .tmp\integ06_1\final_candidate\post_land
```

Do not run `check_core_content.gd`, `check_delivery_runs.gd`, or any other source
fragment from the generated Foundation inheritance chain directly. Those files
do not contain the complete runner and their results are invalid setup evidence.
Direct standalone `extends SceneTree` contracts named elsewhere in this ledger
are valid entry points.

Run the player-facing Crew Play binding reproduction after the shared
Foundation host repair. It must enter Blackjack through `FoundationMain`, retain
`current_environment.active_game_id=blackjack`, expose `crew_play:spotter`, and
exit 0. Before that repair it intentionally exits 1 and prints the exact missing-
binding evidence.

```powershell
& $godot --headless --path . --script `
  res://tools/integ06_1_crew_play_entry_repro.gd
```

## 3. Save migration matrices

Run the provenance-bound v0.5.1 admission matrix. It must retain the exact
`fixtures=37 provenance=verified source=FoundationMain round_trip=stable`
verdict.

```powershell
& $godot --headless --path . --script res://scripts/tests/foundation/integ06_1_v051_migration_smoke.gd `
  *> .tmp\integ06_1\final_candidate\v051_migration.log
```

No owner-authored pre-depth mid-0.6 save inventory was found after the exhaustive
recovery pass documented in
`docs/plans/integ06_1_mid06_fixture_capture_plan.md`. The approved constructive
path used historical production FoundationMain and SaveService code at three
exact pre-depth development boundaries. Those genuine public-action captures,
their provenance sidecars, and portable custody manifests are now checked in.
Regenerate them only when auditing custody itself:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\integ06_1_generate_mid06_fixtures.ps1 `
  -OutputDirectory scripts\tests\fixtures\integ06_1\mid_0_6 `
  -CaptureTimeoutSeconds 180 `
  -KeepHistoricalArchive
```

Admit that fixture class with the provenance-aware current verifier on the final
candidate:

```powershell
& $godot --headless --audio-driver Dummy --path . --script `
  res://scripts/tests/foundation/integ06_1_v051_migration_smoke.gd -- `
  --fixture-class=mid_0_6
```

## 4. Maximal composition and deterministic subsystem traces

Run the existing production composition probe, then independent-process
determinism. Preserve every JSON report.

```powershell
& $godot --headless --path . --script res://tools/wave_b_composition_probe.gd -- `
  --seed=WAVE-B-COMPOSITION-08 `
  --out=res://.tmp/integ06_1/final_candidate/maximal_bar_punchline/report.json

powershell -NoProfile -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 `
  -SeedCount 10 -SeedPrefix INTEG06-1-FINAL -RequireGodot
Copy-Item .tmp\foundation_determinism_probe\run_a.json $evidence
Copy-Item .tmp\foundation_determinism_probe\run_b.json $evidence
```

The current composition harness proves one maximal Bar route plus Punchline L1,
L2, and L3, including mid-active SaveService recovery, revisit, replay, and
abandonment cleanup. The exhaustive producer now derives its eligible set from
the production archetype/scenario catalogs, discovers targets through the
production Crew event selector, and shards five lifecycle orders across all
eligible archetypes and all Punchline layers. Run it on the exact clean
candidate. `$profilePath` and `$evidenceProfile` must identify the final declared
`perf06_1` execution profile; do not substitute an unrelated file merely to
satisfy the provenance check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools\integ06_1_composition_matrix.ps1 `
  -CandidateCommit $head `
  -ProfilePath $profilePath `
  -EvidenceProfile $evidenceProfile `
  -OutDir .tmp\integ06_1\final_candidate\composition_matrix `
  -RequireGodot
```

Require every derived row and the aggregate manifest to pass. Until that
command produces retained exact-candidate evidence, the larger matrix remains
**NOT PROVEN**.

## 5. Native stability soak

Run the existing opt-in three-hour accelerated native stability probe. It
samples saves every 23 actions and asserts bounded memory, resources, nodes,
serialized state, history, story log, and Pinball session cache.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\foundation_soak_probe.ps1 `
  -SimMinutes 180 -ActionsPerSample 28 -SeedPrefix INTEG06-1-FINAL-SOAK -RequireGodot

$godotUser = Join-Path $env:APPDATA 'Godot\app_userdata\Beat the House'
Copy-Item (Join-Path $godotUser 'foundation_soak_probe_report.json') $evidence
Copy-Item (Join-Path $godotUser 'foundation_soak_probe_samples.jsonl') $evidence
```

This is a retained-state/performance soak, not a full-run terminal or browser
soak. It rotates runs every 160 actions and does not establish a crew-ignoring
control, every victory/failure route, exact native/Web outcome parity, or final
profile recording.

## 6. Existing native/Web and terminal support gates

The scenario-sequence parity tool is valid and expensive. It creates fresh
Windows and Web exports, runs two independent processes on each platform, and
requires exact semantic hashes, but covers only `corner_store_delivery_day`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\scenario_sequence_parity_performance.ps1 `
  -GodotPath $godot -RequireGodot -Browser chrome -Cpu 4 -TimeoutMs 600000 `
  -OutDir .tmp\integ06_1\final_candidate\scenario_parity
```

The supported Foundation Contracts report must also retain its terminal route,
five representative failure reasons, and profile-recording checks. A larger
conditioned balance simulation can supplement those contracts, but it is
explicitly nonbinding because its legacy scenarios select a Grand Casino start,
entry bankroll/invitation, and synthetic collection loadout:

```powershell
& $godot --headless --path . --script res://tools/endgame_metrics_probe.gd -- `
  --seeds-per-scenario=30 --seed-prefix=INTEG06-1-FINAL-ENDGAME `
  --max-actions=88 `
  --output=res://.tmp/integ06_1/final_candidate/endgame/report.json `
  --report=res://.tmp/integ06_1/final_candidate/endgame/report.md
```

Neither older command is an exact native/Web full-run composition soak. The new
strict producer embeds the production-core action driver in fresh Windows and
Web release exports, but replaces the conditioned balance scenarios with a
binding policy-only catalog. Every case starts a standard production challenge;
the binding mode disables caller-selected collection state and rejects casino
teleports, bankroll overrides, invitations, or collection modifiers before the
run starts. It performs SaveService round trips every seven actions, persists
every terminal result through ProfileInventory, repeats each native shard
independently, compares exact semantic hashes with Web, and requires all three
victory routes, at least two failure routes, and a Crew-ignoring control:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools\integ06_1_terminal_soak_contract_test.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools\integ06_1_terminal_soak.ps1 `
  -CandidateCommit $head `
  -ProfilePath $profilePath `
  -EvidenceProfile $evidenceProfile `
  -OutDir .tmp\integ06_1\final_candidate\terminal_soak `
  -RequireGodot
```

Each shard records its authority-setup audit. The producer refuses an existing
output directory, dirty tracked source,
mismatched candidate commit/tree, or mismatched profile/tool hashes. It reports
allocation counters unavailable instead of zero and delegates frame-trajectory
measurement explicitly to the exact-candidate `perf06_1` manifest. The terminal
contract rejects missing, duplicated, unexpected, or misindexed cases rather
than trusting only a total count. Each native, repeated-native, and Web cohort
must contain the exact nine-case catalog and exact shard custody. Every cohort
must also retain concrete witnesses for Crew, Crew jobs, Crew heists, Numbers,
deliveries, scenarios, Police Sweep, travelers, and Coin Pusher. Post-warmup
retained growth is fail-closed at eight nodes, eight resources, and 32 objects,
with zero orphan growth and a 1,500,000-byte state ceiling. This
acceptance item remains **NOT PROVEN** until the command itself runs green; the
producer commit is not runtime evidence.

## 7. Evidence manifest and handoff rule

After the candidate passes every available gate without source changes, hash all
retained artifacts and bind them to the exact commit:

```powershell
Get-ChildItem $evidence -File -Recurse | Get-FileHash -Algorithm SHA256 | `
  Sort-Object Path | Format-Table -AutoSize
git status --short
git rev-parse HEAD
```

`integ06_1` can move to DONE only when the three explicit **NOT PROVEN** items
above have real, reproducible evidence: provenance-bound mid-0.6 development-
boundary save admission,
the every-eligible-node composition/ordering matrix, and complete native/Web
terminal soaks with victory/failure/profile coverage. Until then, preserve the
passing partial evidence, keep the row TODO, and hand the exact remaining gap to
the release root without converting absence of evidence into a waiver.
