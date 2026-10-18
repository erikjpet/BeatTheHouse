$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))

function Assert-FeaturePcmContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$musicPath = Join-Path $root "scripts/ui/procedural_music_player.gd"
$bridgePath = Join-Path $root "scripts/ui/web_audio_bridge.gd"
$buildIdentityPath = Join-Path $root "scripts/core/build_identity.gd"
$focusedPath = Join-Path $root "scripts/tests/postfix06_2_reliability_contract.gd"
$overlayPath = Join-Path $root "scripts/ui/perf_telemetry_overlay.gd"
$foundationSoakPath = Join-Path $root "tools/foundation_soak_probe.gd"
$runnerPath = Join-Path $root "tools/postfix06_2_feature_pcm_runtime.ps1"
$checkPath = Join-Path $root "tools/check_godot.ps1"
foreach ($path in @($musicPath, $bridgePath, $buildIdentityPath, $focusedPath, $overlayPath, $foundationSoakPath, $runnerPath, $checkPath)) {
    Assert-FeaturePcmContract (Test-Path -LiteralPath $path -PathType Leaf) "Required RP-006 contract input is missing: $path"
}

$music = Get-Content -LiteralPath $musicPath -Raw
$bridge = Get-Content -LiteralPath $bridgePath -Raw
$buildIdentity = Get-Content -LiteralPath $buildIdentityPath -Raw
$focused = Get-Content -LiteralPath $focusedPath -Raw
$overlay = Get-Content -LiteralPath $overlayPath -Raw
$foundationSoak = Get-Content -LiteralPath $foundationSoakPath -Raw
$runner = Get-Content -LiteralPath $runnerPath -Raw
$check = Get-Content -LiteralPath $checkPath -Raw
$runnerTokens = $null
$runnerParseErrors = $null
$runnerAst = [Management.Automation.Language.Parser]::ParseInput($runner, [ref]$runnerTokens, [ref]$runnerParseErrors)
Assert-FeaturePcmContract (@($runnerParseErrors).Count -eq 0) "The Windows/Web runner does not parse cleanly."

Assert-FeaturePcmContract ($music -match 'PCM_CACHE_DEFAULT_BUDGET_BYTES\s*:=\s*64\s*\*\s*1024\s*\*\s*1024') "The production PCM budget changed from 64 MiB."
Assert-FeaturePcmContract ($music -match '(?s)func _recalculate_pcm_cache_key_bytes.*?_feature_stem_cache') "Feature PCM is absent from shared byte accounting."
Assert-FeaturePcmContract ($music -match '_pcm_cache_entry_raw_bytes' -and $music -match '_pcm_cache_entry_encoded_bytes') "Shared PCM accounting does not expose raw and encoded retained-byte subtotals."
Assert-FeaturePcmContract ($music -match '(?s)func _pcm_variant_retained_bytes.*?PCM_BASE64_META.*?to_utf8_buffer\(\)\.size\(\)') "Shared PCM accounting does not count UTF-8 bytes retained in PCM_BASE64_META."
Assert-FeaturePcmContract ($music -match '(?s)func pcm_cache_policy_snapshot.*?"bytes".*?"raw_bytes".*?"encoded_bytes".*?entry_raw_bytes.*?entry_encoded_bytes') "PCM policy evidence does not expose raw/encoded/total cache and entry subtotals."
Assert-FeaturePcmContract ($music -match '(?s)func _all_pcm_cache_keys.*?_feature_stem_cache') "Feature PCM is absent from shared eviction/cleanup discovery."
Assert-FeaturePcmContract ($music -match '(?s)func clear_run_scoped_caches.*?stop_feature_music\(\).*?_evict_pcm_cache_key') "Run cleanup does not stop and evict inactive feature PCM."
Assert-FeaturePcmContract ($music -match '(?s)func _exit_tree.*?_feature_stem_cache\.clear\(\).*?_pcm_cache_entry_bytes\.clear\(\)') "Tree teardown does not clear feature PCM and its accounting."
Assert-FeaturePcmContract ($music -match 'delivery_cache_key\s*:=\s*"feature_delivery:%d:%s"\s*%\s*\[AMBIENT_VERSION, style\]') "Delivered feature PCM is not deduplicated by physical style."
Assert-FeaturePcmContract ($music -match '_pending_feature_cache_key' -and $music -match '(?s)func _pcm_cache_protected_keys.*?_pending_feature_cache_key') "Pending feature PCM is not protected through its playback handoff."
Assert-FeaturePcmContract ($music -match 'func _play_feature_stem_set\(stem_set: Dictionary, resume_position: float\) -> bool:') "Feature stem playback does not return a success result."
Assert-FeaturePcmContract ($music -match '(?s)func _play_feature_stem_set.*?return false.*?native_handoff_count.*?return web_played.*?return native_handoff_count > 0') "Feature stem playback does not distinguish invalid, native, and Web handoff success."
Assert-FeaturePcmContract ($music -match '(?s)func _enforce_pcm_cache_budget.*?set_shared_pcm_budget.*?combined_pcm_bytes.*?_evict_pcm_cache_key') "The production player does not enforce one combined native/base64/Web-decoded PCM budget."
Assert-FeaturePcmContract ($music -match '(?s)func pcm_cache_policy_snapshot.*?web_decoded_bytes.*?combined_bytes.*?combined_within_budget') "PCM policy evidence does not expose and enforce the combined retained-byte total."

Assert-FeaturePcmContract ($bridge -match '(?s)func _validated_actual_pcm_stats.*?count.*?bytes.*?budget_bytes.*?keys') "Web decoded-PCM diagnostics are not validated as a complete JS result shape."
Assert-FeaturePcmContract ($bridge -match '(?s)func _actual_pcm_stats.*?_validated_actual_pcm_stats' -and $bridge -notmatch '(?s)func _actual_pcm_stats.*?stats\["actual"\]\s*=\s*true') "Web decoded-PCM diagnostics can still be marked actual without rigorous validation."
Assert-FeaturePcmContract ($bridge -match '"registered_pcm_keys"\s*:') "Web decoded-PCM debug evidence does not expose the actual key set."
Assert-FeaturePcmContract ($bridge -match 'setPcmBudget:\s*function' -and $bridge -match 'func set_shared_pcm_budget' -and $bridge -match 'func shared_pcm_policy_snapshot') "The Web bridge cannot receive the native/base64 owner total and enforce the remaining shared budget."
Assert-FeaturePcmContract ($bridge -match 'shared_pcm_owner_bytes' -and $bridge -match 'combined_pcm_bytes' -and $bridge -match 'combined_pcm_budget_bytes') "Web diagnostics do not report the single cross-cache PCM budget."
Assert-FeaturePcmContract ($buildIdentity -match '(?s)func telemetry_identity.*?manifest_is_valid\(value\).*?export_sha256.*?value\.get\("export_identity_sha256".*?if export_sha256\.is_empty\(\).*?runtime_export_sha256.*?runtime_options\.get\("bth_perf_export_sha256".*?runtime_export_sha256\.length\(\) == 64.*?runtime_export_sha256\.is_valid_hex_number\(false\).*?export_sha256 = runtime_export_sha256\.to_lower\(\)') "A valid embedded manifest cannot receive a validated 64-hex independently computed export-tree identity when that non-circular field is absent."

Assert-FeaturePcmContract ($focused -match 'for boundary_index in range\(3\)' -and $focused -match 'for index in range\(32\)') "Focused RP-006 coverage no longer crosses three boundaries with more than 24 requests."
Assert-FeaturePcmContract ($focused -match 'retained_entries == 2' -and $focused -match 'retained_bytes <= budget_bytes') "Focused RP-006 coverage no longer proves deduplication and the byte budget."
Assert-FeaturePcmContract ($focused -match 'clear_run_scoped_caches' -and $focused -match 'feature PCM survived run-scoped cache cleanup') "Focused RP-006 coverage no longer proves run cleanup."

Assert-FeaturePcmContract ($overlay -match 'FEATURE_PCM_SOAK_BOUNDARIES\s*:=\s*3') "Packaged runtime feature PCM coverage has fewer than three boundaries."
Assert-FeaturePcmContract ($overlay -match 'FEATURE_PCM_SOAK_REQUESTS_PER_BOUNDARY\s*:=\s*32') "Packaged runtime feature PCM coverage has no >24-key boundary."
Assert-FeaturePcmContract ($overlay -match 'FEATURE_PCM_SOAK_MIN_DISTINCT_CONTEXTS\s*:=\s*25') "Packaged runtime feature PCM coverage no longer enforces more than 24 distinct contexts."
Assert-FeaturePcmContract ($overlay -match 'plan_id == "feature_pcm_cache"' -and $overlay -match 'feature_pcm_cache_soak_contract') "The exported runtime cannot select or report the feature PCM plan."
Assert-FeaturePcmContract ($overlay -match '(?s)func _feature_pcm_cache_soak_contract.*?_feature_stem_set_for_input.*?_play_feature_stem_set.*?pcm_cache_policy_snapshot.*?clear_run_scoped_caches') "The exported runtime plan does not use the production feature load/play/account/cleanup path."
Assert-FeaturePcmContract ($overlay -match 'successful_load_count' -and $overlay -match 'successful_play_count' -and $overlay -match 'successful_load_count == FEATURE_PCM_SOAK_REQUESTS_PER_BOUNDARY' -and $overlay -match 'successful_play_count == FEATURE_PCM_SOAK_REQUESTS_PER_BOUNDARY') "The packaged runtime does not require 32 successful production loads and plays per boundary."
Assert-FeaturePcmContract ($overlay -match 'production_entry_bytes_positive') "The packaged runtime does not explicitly prove positive production entry accounting."
Assert-FeaturePcmContract ($overlay -match 'boundary_context_keys\s*:\s*Array\s*=\s*boundary_contexts\.keys\(\)' -and $overlay -match 'all_context_keys\s*:\s*Array\s*=\s*all_contexts\.keys\(\)' -and $overlay -match '"context_keys"\s*:\s*boundary_context_keys' -and $overlay -match '"context_keys"\s*:\s*all_context_keys') "The packaged runtime report does not expose the actual sorted contextual request identities."
Assert-FeaturePcmContract ($overlay -match '(?s)func _feature_pcm_cache_soak_contract.*?WebAudioBridgeScript\.debug_stats\(\).*?pcm_diagnostics_actual') "The exported runtime plan does not retain actual Web decoded-PCM evidence."
Assert-FeaturePcmContract ($overlay -match 'web_pcm_plateau_keys' -and $overlay -match 'web_pcm_plateau_count' -and $overlay -match 'web_pcm_plateau_bytes' -and $overlay -match 'web_pcm_plateau_unchanged') "The Web runtime does not prove the decoded key/count/byte set plateaus after both styles load."
Assert-FeaturePcmContract ($overlay -match 'combined_pcm_bytes' -and $overlay -match 'combined_pcm_budget_bytes' -and $overlay -match 'combined_pcm_within_budget') "The packaged runtime does not record and enforce the combined native/base64/Web-decoded PCM total."
Assert-FeaturePcmContract ($overlay -match 'FEATURE_PCM_MEMORY_PLATEAU_ALLOWANCE_BYTES' -and $overlay -match '"memory_stability"' -and $overlay -match 'memory_stability_passed' -and $overlay -match 'post_probe_cleanup_bytes' -and $overlay -match 'passed = passed and memory_stability_passed') "Repeated-boundary and post-probe memory stability are not an enforced, reported fixed-plateau condition."
Assert-FeaturePcmContract ($overlay -match 'FEATURE_PCM_MEMORY_WARMUP_BOUNDARIES\s*:=\s*2' -and $overlay -match 'cleanup_memory_samples\[FEATURE_PCM_MEMORY_WARMUP_BOUNDARIES - 1\]' -and $overlay -notmatch 'memory_plateau_reference\s*:=\s*cleanup_memory_samples\[0\]') "The memory oracle does not use the second completed boundary as its allocator-warm plateau reference."
Assert-FeaturePcmContract ($overlay -match '"warmup_boundary_count"\s*:\s*FEATURE_PCM_MEMORY_WARMUP_BOUNDARIES' -and $overlay -match '"plateau_reference_boundary_index"\s*:\s*FEATURE_PCM_MEMORY_WARMUP_BOUNDARIES - 1' -and $overlay -match '"memory_phase"') "Memory evidence does not identify both warm-up boundaries and the enforced plateau phase."
Assert-FeaturePcmContract ($overlay -notmatch '(?s)func _feature_pcm_cache_soak_contract.*?debug_configure_pcm_cache_budget') "The packaged soak changes the production cache budget."

Assert-FeaturePcmContract ($foundationSoak -match 'FEATURE_PCM_BOUNDARY_COUNT\s*:=\s*3') "The 180-minute foundation soak no longer crosses three feature-music run boundaries."
Assert-FeaturePcmContract ($foundationSoak -match 'FEATURE_PCM_REQUESTS_PER_BOUNDARY\s*:=\s*32' -and $foundationSoak -match 'FEATURE_PCM_MIN_DISTINCT_CONTEXTS\s*:=\s*25') "The 180-minute foundation soak no longer exercises more than 24 contextual feature requests per boundary."
Assert-FeaturePcmContract ($foundationSoak -match 'FEATURE_PCM_EXPECTED_BUDGET_BYTES\s*:=\s*64\s*\*\s*1024\s*\*\s*1024') "The foundation feature soak changed the production 64 MiB PCM budget oracle."
Assert-FeaturePcmContract ($foundationSoak -match '(?s)await _prewarm_runtime_caches\(\).*?await _exercise_feature_pcm_boundaries\(\).*?for _prewarm_index in range\(SLOT_AUTOPLAY_PREWARM_BLOCKS\)') "Every foundation soak does not unconditionally execute feature music before its long-session workload."
Assert-FeaturePcmContract ($foundationSoak -match '(?s)func _exercise_feature_pcm_boundaries.*?_feature_stem_set_for_input.*?_play_feature_stem_set.*?pcm_cache_policy_snapshot.*?start_foundation_run.*?_feature_pcm_accounting') "The foundation feature soak does not use the production feature load/play, accounting, and run-boundary cleanup paths."
Assert-FeaturePcmContract ($foundationSoak -match 'successful_load_count' -and $foundationSoak -match 'successful_play_count' -and $foundationSoak -match 'distinct_context_count' -and $foundationSoak -match 'cleanup_to_baseline_count' -and $foundationSoak -match 'cleanup_evicted_key_count') "The foundation report no longer retains feature load/play/context/cleanup counters."
Assert-FeaturePcmContract ($foundationSoak -match '(?s)FEATURE_PCM_REQUESTS_PER_BOUNDARY.*?context_key.*?boundary_contexts\[context_key\]\s*=\s*true') "The foundation soak does not prove distinct contextual request identities."
Assert-FeaturePcmContract ($foundationSoak -match '(?s)func _feature_pcm_policy_within_budget.*?raw_bytes.*?encoded_bytes.*?combined_bytes.*?web_decoded_bytes.*?combined_budget_bytes.*?combined_within_budget') "The foundation soak does not reconcile the shared native/base64/Web-decoded PCM accounting."
Assert-FeaturePcmContract ($foundationSoak -match '(?s)func _feature_pcm_cleanup_matches_baseline.*?feature_entry_count.*?feature_bytes' -and $foundationSoak -match '(?s)func _feature_pcm_cleanup_matches_baseline.*?baseline\.get\("feature_entry_count"' -and $foundationSoak -match '(?s)func _feature_pcm_cleanup_matches_baseline.*?for physical_key_value in physical_keys') "The foundation soak does not require feature entries and bytes to return to their pre-soak baseline after a production run boundary."
Assert-FeaturePcmContract ($foundationSoak -notmatch 'debug_configure_pcm_cache_budget') "The foundation feature soak changes the production PCM budget."
Assert-FeaturePcmContract ($foundationSoak -match '"seed_prefix"\s*:\s*seed_prefix' -and $foundationSoak -match '"feature_pcm"\s*:\s*feature_pcm_evidence\.duplicate\(true\)') "The foundation JSON report omits seed-prefix or feature-PCM provenance."
Assert-FeaturePcmContract ($foundationSoak -match 'FOUNDATION_SOAK_OVERALL.*seed_prefix=%s.*feature_boundaries=%d.*feature_contexts=%d.*feature_loads=%d.*feature_plays=%d.*feature_cleanups=%d') "The foundation console summary omits exact feature and seed counters."

Assert-FeaturePcmContract ($runner -match 'Resolve-CandidateManifestPath' -and $runner -match 'Get-ExportTreeIdentityFromDirectory') "The Windows/Web runner is not bound to a registered candidate identity."
Assert-FeaturePcmContract ($runner -match 'Get-CurrentSourceIdentity' -and $runner -match 'dirty_state_digest' -and $runner -match 'source worktree changed during feature PCM qualification') "The runner does not bind a dirty-tree candidate to the exact live source before and after qualification."
Assert-FeaturePcmContract ($runner -match 'candidateManifestSha256Before' -and $runner -match 'candidateManifestSha256After' -and $runner -match 'Candidate manifest changed during feature PCM qualification') "The runner does not pre-hash and recheck the candidate manifest."
Assert-FeaturePcmContract ($runner -match 'Resolve-StageRoot -Candidate \$candidate -Platform windows' -and $runner -match 'Resolve-StageRoot -Candidate \$candidate -Platform web') "The runner does not qualify both registered Windows and Web artifacts."
Assert-FeaturePcmContract ($runner -match 'Report\.build_identity\.build_version' -and $runner -match 'Candidate\.build_version') "The runner does not compare the runtime build version with the candidate manifest."
Assert-FeaturePcmContract ($runner -match 'Report\.build_identity\.export_sha256\s+-ceq\s+\$ExportIdentity' -and $runner -match 'Runtime export identity did not match the staged candidate') "The runner does not bind runtime telemetry to the exact staged export tree identity."
Assert-FeaturePcmContract ($runner -match '--bth_perf_export_sha256=\$\(\$windowsStage\.Identity\.aggregate_sha256\)' -and $runner -match 'bth_perf_export_sha256=\$\(\$webStage\.Identity\.aggregate_sha256\)') "The runner does not pass each independently computed staged export identity into its runtime telemetry."
Assert-FeaturePcmContract ($runner -match '\$expectedPcmBudgetBytes\s*=\s*64MB' -and $runner -match 'changed the declared 64 MiB PCM budget') "The runner does not preserve the declared PCM budget."
Assert-FeaturePcmContract ($runner -match 'requests_per_boundary -eq 32' -and $runner -match 'distinct_context_count' -and $runner -match 'reportedAllContextKeys') "The runner does not reject an insufficient or duplicate-key soak."
Assert-FeaturePcmContract ($runner -match '\$expectedBoundaryIndices\s*=\s*@\(0,\s*1,\s*2\)' -and $runner -match '\$boundaryIndices.*?Sort-Object' -and $runner -match '\$boundaryIndices\s+-join\s+","' -and $runner -match '0,1,2' -and $runner -match 'exact unique indices 0,1,2') "The runner does not require the exact unique boundary indices 0,1,2."
Assert-FeaturePcmContract ($runner -match 'function Get-ExpectedFeatureContextKeys' -and $runner -match '\$boundary\.context_keys' -and $runner -match '\$evidence\.context_keys' -and $runner -match 'contextual request identity array did not match') "The runner does not independently validate the actual per-boundary and aggregate contextual request identities."
Assert-FeaturePcmContract ($runner -match 'successful_load_count' -and $runner -match 'successful_play_count' -and $runner -match 'production_entry_bytes_positive') "The runner does not reject incomplete production load/play/accounting evidence."
Assert-FeaturePcmContract ($runner -match '\$featureRawBytes\s*=\s*\[int64\]\$boundary\.populated\.feature_accounting\.raw_bytes' -and $runner -match '\$featureEncodedBytes\s*=\s*\[int64\]\$boundary\.populated\.feature_accounting\.encoded_bytes' -and $runner -match '\$featureTotalBytes\s*=\s*\[int64\]\$boundary\.populated\.feature_accounting\.bytes' -and $runner -match '\$featureRawBytes\s+-gt\s+0' -and $runner -match '\$featureTotalBytes\s+-eq\s*\(\$featureRawBytes\s*\+\s*\$featureEncodedBytes\)' -and $runner -match 'raw/encoded feature accounting did not reconcile') "The runner does not require positive raw bytes and reconcile the enforced feature total on both platforms."
Assert-FeaturePcmContract ($runner -match '(?s)if\s*\(\$Platform\s+-eq\s+"windows"\).*?\$featureEncodedBytes\s+-eq\s+0.*?native feature accounting unexpectedly retained Web base64 metadata') "The runner does not require zero base64 metadata bytes for native Windows delivery."
Assert-FeaturePcmContract ($runner -match '(?s)if\s*\(\$Platform\s+-eq\s+"windows"\).*?else\s*\{.*?\$featureEncodedBytes\s+-gt\s+0.*?Web feature accounting omitted retained base64 metadata') "The runner does not require positive retained base64 metadata bytes for Web delivery."
Assert-FeaturePcmContract ($runner -match 'cache_raw_bytes' -and $runner -match 'cache_encoded_bytes' -and $runner -match 'shared raw/encoded cache accounting did not reconcile') "The runner does not reconcile shared raw plus encoded bytes to the enforced cache total."
Assert-FeaturePcmContract ($runner -match 'memory_stability\.passed' -and $runner -match 'plateau_allowance_bytes -eq 16MB' -and $runner -match 'memory_plateau_ok' -and $runner -match 'post_probe_cleanup_bytes') "The runner does not enforce the reported repeated-boundary and post-probe fixed memory plateau."
Assert-FeaturePcmContract ($runner -match '\$memorySamples\[1\]' -and $runner -match 'warmup_boundary_count -eq 2' -and $runner -match 'plateau_reference_boundary_index -eq 1' -and $runner -notmatch '\$memorySamples\[0\].*plateau_reference') "The runner does not independently bind the plateau reference to the second warm-up sample."
Assert-FeaturePcmContract ($runner -match 'pcm_diagnostics_actual' -and $runner -match 'Web bridge did not return to its pre-soak PCM baseline') "The runner does not validate actual Web bridge cleanup."
Assert-FeaturePcmContract ($runner -match 'web_pcm_plateau_unchanged' -and $runner -match 'web_pcm_plateau_keys' -and $runner -match 'registered_pcm_keys') "The runner does not reject Web decoded-key growth or churn after both styles load."
Assert-FeaturePcmContract ($runner -match 'combined_pcm_bytes' -and $runner -match 'combined_pcm_budget_bytes' -and $runner -match 'combined_pcm_within_budget' -and $runner -match 'combined native/base64/Web-decoded PCM budget') "The runner does not independently reject a combined cross-cache PCM budget overflow."
Assert-FeaturePcmContract ($runner -match '(?s)function Test-ExactJsonBoolean.*?\.GetType\(\)\s+-eq\s+\[bool\].*?-eq\s+\$Expected') "The report validator does not require an actual JSON Boolean with the expected value."
foreach ($strictBooleanUse in @(
    'Test-ExactJsonBoolean -Value $Report.passed -Expected $true',
    'Test-ExactJsonBoolean -Value $evidence.passed -Expected $true',
    'Test-ExactJsonBoolean -Value $evidence.memory_stability.passed -Expected $true',
    'Test-ExactJsonBoolean -Value $boundary.passed -Expected $true',
    'Test-ExactJsonBoolean -Value $boundary.production_entry_bytes_positive -Expected $true',
    'Test-ExactJsonBoolean -Value $boundary.memory_plateau_ok -Expected $true',
    'Test-ExactJsonBoolean -Value $boundary.memory_plateau_enforced -Expected $false',
    'Test-ExactJsonBoolean -Value $boundary.memory_plateau_enforced -Expected $true',
    'Test-ExactJsonBoolean -Value $baseline.pcm_diagnostics_actual -Expected $true',
    'Test-ExactJsonBoolean -Value $populatedBridge.pcm_diagnostics_actual -Expected $true',
    'Test-ExactJsonBoolean -Value $boundary.web_pcm_plateau_unchanged -Expected $true',
    'Test-ExactJsonBoolean -Value $clearedBridge.pcm_diagnostics_actual -Expected $true'
)) {
    Assert-FeaturePcmContract ($runner.Contains($strictBooleanUse)) "The report validator does not strictly validate: $strictBooleanUse"
}
Assert-FeaturePcmContract ($runner -notmatch '\[bool\]\$(evidence|boundary|baseline|populatedBridge|clearedBridge|Report)\.') "The report validator still coercively casts a JSON value to Boolean."
Assert-FeaturePcmContract ($runner -match 'Start-OwnedWebServer' -and $runner -match 'Stop-OwnedWebServer' -and $runner -match 'archive/l02/l02_web_perf_probe\.mjs') "The Web runtime path does not use the maintained owned-server/browser probe."
Assert-FeaturePcmContract ($runner -match 'Wait-ForProjectRuntimeSlot' -and $runner -match 'Get-CimInstance Win32_Process') "The runner can race an existing project Godot/runtime process."
Assert-FeaturePcmContract (([regex]::Matches($runner, '\$null\s*=\s*Wait-ForProjectRuntimeSlot')).Count -ge 2) "The runner does not recheck the project runtime slot before both native and Web phases."
Assert-FeaturePcmContract ($runner -match 'Enter-FeaturePcmWorkspaceMutex' -and $runner -match 'Exit-FeaturePcmWorkspaceMutex' -and $runner -match 'Local\\BeatTheHouse_CheckGodot_') "The Windows/Web run does not hold the shared workspace mutex."
$nativeStart = $runner.IndexOf('$nativeProcess = Start-Process')
$nativeEvents = $runner.IndexOf('$nativeProcess.EnableRaisingEvents = $true')
$nativeWait = $runner.IndexOf('$nativeProcess.WaitForExit($TimeoutMs)')
$nativeClassifier = $runner.IndexOf('Get-NativeRuntimeLogIssues -Paths @($nativeStdout, $nativeStderr, $nativeLog)')
$nativeExitCheck = $runner.IndexOf('if ($nativeExitCode -ne 0)')
$webSlot = $runner.IndexOf('$null = Wait-ForProjectRuntimeSlot', $nativeWait + 1)
$webStart = $runner.IndexOf('$server = Start-OwnedWebServer')
Assert-FeaturePcmContract ($nativeStart -ge 0 -and $nativeWait -gt $nativeStart -and $webSlot -gt $nativeWait -and $webStart -gt $webSlot) "The runner does not prove native WaitForExit before the Web slot check and server launch."
Assert-FeaturePcmContract ($nativeEvents -gt $nativeStart -and $nativeEvents -lt $nativeWait) "The redirected native process does not enable exit events before its timed WaitForExit call."
Assert-FeaturePcmContract ($nativeClassifier -gt $nativeWait -and $nativeExitCheck -gt $nativeClassifier -and $webSlot -gt $nativeExitCheck) "The runner does not classify native stdout, stderr, and explicit engine log after the wait and before accepting the process exit."
$mutexEnter = $runner.IndexOf('$workspaceMutexLease = Enter-FeaturePcmWorkspaceMutex')
$mutexRelease = $runner.LastIndexOf('Exit-FeaturePcmWorkspaceMutex -Lease $workspaceMutexLease')
Assert-FeaturePcmContract ($mutexEnter -ge 0 -and $mutexEnter -lt $nativeStart -and $mutexRelease -gt $webStart) "The runner does not hold the shared workspace mutex across the complete native-plus-Web sequence."
$tryStatements = @($runnerAst.FindAll({ param($node) $node -is [Management.Automation.Language.TryStatementAst] }, $true))
$mutexOwnerTry = @($tryStatements | Where-Object {
    $null -ne $_.Finally -and
    $_.Body.Extent.Text.Contains('$workspaceMutexLease = Enter-FeaturePcmWorkspaceMutex') -and
    $_.Finally.Extent.Text.Contains('Exit-FeaturePcmWorkspaceMutex -Lease $workspaceMutexLease')
})
Assert-FeaturePcmContract ($mutexOwnerTry.Count -eq 1) "The shared workspace mutex is not released by the finally block that owns the full qualification sequence."
$nativeOwnerTry = @($tryStatements | Where-Object {
    $null -ne $_.Finally -and
    $_.Body.Extent.Text.Contains('$nativeProcess = Start-Process') -and
    $_.Body.Extent.Text.Contains('$nativeProcess.WaitForExit($TimeoutMs)') -and
    $_.Finally.Extent.Text.Contains('Stop-Process -Id $nativeProcess.Id -Force') -and
    $_.Finally.Extent.Text.Contains('$nativeProcess.WaitForExit()') -and
    $_.Finally.Extent.Text.Contains('$nativeProcess.Dispose()')
})
Assert-FeaturePcmContract ($nativeOwnerTry.Count -eq 1) "The native process is not lifetime-owned by a finally block that kills, waits for exit, and disposes it before mutex release."
Assert-FeaturePcmContract ($runner -match '(?s)if \(-not \$nativeProcess\.WaitForExit\(\$TimeoutMs\)\).*?Stop-Process -Id \$nativeProcess\.Id -Force.*?\$nativeProcess\.WaitForExit\(\).*?throw "Windows feature PCM runtime timed out') "The native timeout path does not kill and wait for the process before unwinding."
Assert-FeaturePcmContract ($runner -match 'Get-NativeRuntimeLogIssues' -and $runner -match 'nativeLog' -and $runner -match '--log-file' -and $runner -match 'unexpected engine/script warning/error') "The runner does not classify native stdout/stderr/explicit-log diagnostics."
Assert-FeaturePcmContract ($runner -match '(?s)\$nativeArguments\s*=\s*@\(.*?"--verbose".*?"--log-file".*?"--"' -and $runner -match '\$leakedInstances\.Count -gt 0 -and \$nonZeroOrUnclassified\.Count -eq 0') "The native runner does not request verbose leak evidence before classifying the zero-reference ObjectDB warning."
$webEvaluationPosition = $runner.IndexOf('$webEvaluation = Test-FeaturePcmReport')
$windowsRehashPosition = $runner.IndexOf('$windowsAfter = Get-ExportTreeIdentityFromDirectory')
$webRehashPosition = $runner.IndexOf('$webAfter = Get-ExportTreeIdentityFromDirectory')
$manifestRehashPosition = $runner.IndexOf('$candidateManifestSha256After = (Get-FileHash')
$sourceRehashPosition = $runner.IndexOf('$sourceAfter = Get-CurrentSourceIdentity')
Assert-FeaturePcmContract ($webEvaluationPosition -ge 0 -and $windowsRehashPosition -gt $webEvaluationPosition -and $webRehashPosition -gt $windowsRehashPosition -and $manifestRehashPosition -gt $webRehashPosition -and $sourceRehashPosition -gt $manifestRehashPosition) "The runner does not rehash both final stage trees, the manifest, and source after Web runtime qualification."
Assert-FeaturePcmContract ($runner -notmatch 'debug_configure_pcm_cache_budget' -and $runner -notmatch 'Skip.*Budget') "The runtime qualifier weakens or bypasses the cache budget."
Assert-FeaturePcmContract ($check -match 'feature_pcm_runtime\s*=\s*"postfix06_2_feature_pcm_runtime_contract_test\.ps1"') "The maintained Audit/Full gate does not run the RP-006 packaged-runtime contract."

if ($args -notcontains "-Quiet") {
    Write-Host "postfix06_2 feature PCM runtime contract passed."
}
