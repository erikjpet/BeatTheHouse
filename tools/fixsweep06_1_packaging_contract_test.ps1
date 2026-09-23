$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$failures = [Collections.Generic.List[string]]::new()

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Get-ExportPresetRecords([string[]]$Lines) {
    $records = [Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match '^\[preset\.(?<index>\d+)\]$') {
            $current = [ordered]@{
                Index = [int]$Matches.index
                Name = $null
                Platform = $null
                Runnable = $null
                CustomFeatures = $null
            }
            $records.Add([pscustomobject]$current)
            continue
        }
        if ($line -match '^\[preset\.\d+\.options\]$') {
            $current = $null
            continue
        }
        if ($null -eq $current -or $line -notmatch '^(?<key>[a-z_]+)=(?<value>.*)$') { continue }

        $value = $Matches.value.Trim()
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        switch ($Matches.key) {
            'name' { $records[$records.Count - 1].Name = $value }
            'platform' { $records[$records.Count - 1].Platform = $value }
            'runnable' { $records[$records.Count - 1].Runnable = $value }
            'custom_features' { $records[$records.Count - 1].CustomFeatures = $value }
        }
    }
    return @($records)
}

$project = Get-Content -LiteralPath (Join-Path $root "project.godot") -Raw
$presets = Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw
$exportTool = Get-Content -LiteralPath (Join-Path $root "tools/export_itch.ps1") -Raw
$main = Get-Content -LiteralPath (Join-Path $root "scripts/ui/foundation_main.gd") -Raw
$telemetry = Get-Content -LiteralPath (Join-Path $root "scripts/ui/perf_telemetry_overlay.gd") -Raw
$solver = Get-Content -LiteralPath (Join-Path $root "scripts/games/coin_pusher/coin_pusher_solver.gd") -Raw
$helperPath = Join-Path $root "tools/export_itch_helpers.ps1"

# RP-009: parse every preset rather than searching two known mobile blocks.
# Every runnable export is a distribution build, including unsigned/credential-
# blocked Android and iOS presets, so identity and persistence fail closed.
$presetLines = @(Get-Content -LiteralPath (Join-Path $root "export_presets.cfg"))
$presetRecords = @(Get-ExportPresetRecords -Lines $presetLines)
$presetHeaderCount = @($presetLines | Where-Object { $_ -match '^\[preset\.\d+\]$' }).Count
Assert-True ($presetRecords.Count -eq $presetHeaderCount -and $presetRecords.Count -gt 0) "RP-009: every export preset must be parsed by the identity contract."
$presetIndexes = @($presetRecords | ForEach-Object { $_.Index } | Sort-Object -Unique)
Assert-True ($presetIndexes.Count -eq $presetRecords.Count) "RP-009: export preset indexes must be unique."
foreach ($preset in $presetRecords) {
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$preset.Name)) "RP-009: preset $($preset.Index) has no parsed name."
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$preset.Platform)) "RP-009: preset $($preset.Index) has no parsed platform."
    Assert-True ([string]$preset.Runnable -in @('true', 'false')) "RP-009: preset '$($preset.Name)' has no parsed runnable flag."
    Assert-True ($null -ne $preset.CustomFeatures) "RP-009: preset '$($preset.Name)' has no parsed custom_features field."
    if ([string]$preset.Runnable -eq 'true') {
        $featureTokens = @(([string]$preset.CustomFeatures).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Assert-True ($featureTokens -contains 'distribution_build') "RP-009: runnable preset '$($preset.Name)' ($($preset.Platform)) lacks distribution_build identity/isolation."
    }
}

Assert-True ($project -match 'config/version="0\.5\.1"') "D3 violation: project.godot release stamp changed."
$identityPath = Join-Path $root "scripts/core/build_identity.gd"
Assert-True (Test-Path -LiteralPath $identityPath -PathType Leaf) "BTH-033: manifest-backed runtime build identity is missing."
if (Test-Path -LiteralPath $identityPath -PathType Leaf) {
    $identity = Get-Content -LiteralPath $identityPath -Raw
    foreach ($field in @("build_version", "source_commit", "source_tree", "dirty_state_digest", "engine_sha256", "export_presets_sha256", "platform", "native_library_sha256")) {
        Assert-True ($identity.Contains($field)) "BTH-033: runtime manifest contract omits '$field'."
    }
}
Assert-True ($main.Contains("BuildIdentityScript.display_version")) "BTH-033: the player-visible menu still reads the immutable project release stamp directly."
Assert-True ($telemetry.Contains("BuildIdentityScript.telemetry_identity")) "BTH-033: performance telemetry still trusts caller-provided source identity."
foreach ($token in @("0.6.0-dev+", "dirty_state_digest", "engine_sha256", "export_presets_sha256", "native_library_sha256", "build_manifest.json")) {
    Assert-True ($exportTool.Contains($token)) "BTH-033: export custody tool is missing '$token'."
}
Assert-True ($presets -notmatch 'application/(file|product)_version="0\.5\.1"') "BTH-033: Windows development export metadata still claims 0.5.1."

foreach ($token in @("builds/staging", "source_tree", "candidate_manifest", "Verify-ArchiveAgainstStaging", "Move-SupersededBuildArtifacts")) {
    Assert-True ($exportTool.Contains($token)) "BTH-034: immutable cross-platform staging/custody contract is missing '$token'."
}
Assert-True ($exportTool.Contains('Target = "all"')) "BTH-034: the default packaging route does not build one bound Windows/Web candidate."
Assert-True ($exportTool -match '\$dirtyShort\s*=\s*\$dirtyDigest\.Substring\(0,\s*12\)' -and $exportTool -match 'source_dirty_short\s*=\s*\$dirtyShort') "BTH-034: immutable candidate names do not derive a short dirty-state identity."
Assert-True ($exportTool -match 'candidate_key\s*=\s*"\$\(\$buildVersion\)_\$\(\$tree\.Substring\(0,12\)\)_\$dirtyShort"') "BTH-034: staging identity can collide across distinct dirty source states."
Assert-True (([regex]::Matches($exportTool, '\$\(\$identity\.source_dirty_short\)')).Count -ge 3) "BTH-034: candidate manifest/archive names can collide across dirty source states."

foreach ($pattern in @("reports/*", "reports/**", "native/*", "native/**", "**/*.log", "**/*.pem", "**/*.key")) {
    Assert-True ($presets.Contains($pattern)) "BTH-040: export exclusions omit '$pattern'."
}
$auditPath = Join-Path $root "tools/audit_pck_manifest.py"
Assert-True (Test-Path -LiteralPath $auditPath -PathType Leaf) "BTH-040: post-export PCK manifest audit is missing."
Assert-True ($exportTool.Contains("audit_pck_manifest.py")) "BTH-040: export flow does not invoke the packed-resource audit."
$auditContractPath = Join-Path $root "tools/audit_pck_manifest_contract_test.py"
Assert-True (Test-Path -LiteralPath $auditContractPath -PathType Leaf) "RP-011: packed-resource allowlist regression is missing."
if (Test-Path -LiteralPath $auditContractPath -PathType Leaf) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    Assert-True ($null -ne $python) "RP-011: Python is unavailable for the packed-resource allowlist regression."
    if ($null -ne $python) {
        & $python.Source $auditContractPath
        Assert-True ($LASTEXITCODE -eq 0) "RP-011: packed-resource custom-audio allowlist regression failed."
    }
}

Assert-True (-not (Test-Path -LiteralPath (Join-Path $root "builds/itch/BeatTheHouse.exe"))) "BTH-041: loose itch executable remains outside quarantine."
$quarantinedLoose = @(Get-ChildItem -LiteralPath (Join-Path $root "builds/quarantine") -Filter "BeatTheHouse.exe" -File -Recurse -ErrorAction SilentlyContinue)
Assert-True ($quarantinedLoose.Count -ge 1) "BTH-041: loose itch executable has no reversible quarantine copy."
Assert-True ($solver.Contains("native_extension_required")) "BTH-041: distribution Coin Pusher still silently falls back without its native extension."
Assert-True ($exportTool.Contains("unexpected executable-looking artifact")) "BTH-041: upload-directory preflight does not reject unowned executables."

# RP-010/RP-012 are exercised without building native code or starting Godot.
# The fixtures prove that package selection is an exact platform/target/arch/
# threading tuple and that noisy child output cannot contaminate an exit code.
Assert-True (Test-Path -LiteralPath $helperPath -PathType Leaf) "RP-010/RP-012: pure export helper contract is missing."
if (Test-Path -LiteralPath $helperPath -PathType Leaf) {
    . $helperPath
    $fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ("bth-packaging-contract-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    try {
        $debugDll = Join-Path $fixtureRoot "coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll"
        $releaseDll = Join-Path $fixtureRoot "coin_pusher_native_v3_10.windows.template_release.x86_64.nothreads.dll"
        $releaseWasm = Join-Path $fixtureRoot "coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm"
        $wrongArchitectureDll = Join-Path $fixtureRoot "coin_pusher_native_v3_10.windows.template_release.x86_32.nothreads.dll"
        $wrongThreadingDll = Join-Path $fixtureRoot "coin_pusher_native_v3_10.windows.template_release.x86_64.threads.dll"
        foreach ($path in @($debugDll, $releaseDll, $releaseWasm, $wrongArchitectureDll, $wrongThreadingDll)) {
            [IO.File]::WriteAllBytes($path, [byte[]]@(0))
        }

        $selected = Get-NativeSourceLibrary -Directory $fixtureRoot -Platform "windows" -Target "template_release" -Architecture "x86_64" -Threading "nothreads"
        Assert-True ($selected.Name -eq (Split-Path -Leaf $releaseDll)) "RP-010: release selection did not enforce the exact target/architecture/threading tuple amid valid decoys."

        $duplicateDll = Join-Path $fixtureRoot "coin_pusher_native_duplicate.windows.template_release.x86_64.nothreads.dll"
        [IO.File]::WriteAllBytes($duplicateDll, [byte[]]@(0))
        $duplicateRejected = $false
        try {
            $null = Get-NativeSourceLibrary -Directory $fixtureRoot -Platform "windows" -Target "template_release" -Architecture "x86_64" -Threading "nothreads"
        }
        catch { $duplicateRejected = $true }
        Assert-True $duplicateRejected "RP-010: ambiguous exact native-library tuples are not rejected."
        Remove-Item -LiteralPath $duplicateDll -Force

        $childScript = Join-Path $fixtureRoot "noisy_child.ps1"
        [IO.File]::WriteAllText($childScript, @'
[Console]::Out.WriteLine("fixture stdout")
[Console]::Error.WriteLine("fixture stderr")
exit ([int]$args[0])
'@, [Text.UTF8Encoding]::new($false))
        $powerShellHost = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $successResult = @(Invoke-TypedConsoleProcess -FilePath $powerShellHost -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $childScript, "0"))
        Assert-True ($successResult.Count -eq 1 -and $successResult[0] -is [int] -and $successResult[0] -eq 0) "RP-012: noisy success did not return exactly one typed Int32 exit code."
        $failureResult = @(Invoke-TypedConsoleProcess -FilePath $powerShellHost -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $childScript, "7"))
        Assert-True ($failureResult.Count -eq 1 -and $failureResult[0] -is [int] -and $failureResult[0] -eq 7) "RP-012: noisy failure did not preserve its typed nonzero exit code."

        # Exercise the same maintained Web orchestration seam used by
        # export_itch.ps1, not just its child-process helper. A noisy success
        # must traverse audit -> custody -> candidate registration in order;
        # a noisy nonzero exit must reach none of those downstream stages.
        $pipelineCommand = Get-Command Invoke-WebExportPipeline -CommandType Function -ErrorAction SilentlyContinue
        Assert-True ($null -ne $pipelineCommand) "RP-012: maintained Web audit/custody/registration pipeline seam is missing."
        if ($null -ne $pipelineCommand) {
            $successPipelineRoot = Join-Path $fixtureRoot "pipeline_success"
            New-Item -ItemType Directory -Path $successPipelineRoot | Out-Null
            $successTrace = [Collections.Generic.List[string]]::new()
            $successAudit = Join-Path $successPipelineRoot "web_pck_audit.json"
            $successCustody = Join-Path $successPipelineRoot "web_custody.json"
            $successRegistration = Join-Path $successPipelineRoot "candidate_manifest.json"
            Invoke-WebExportPipeline `
                -ExportAction { Invoke-TypedConsoleProcess -FilePath $powerShellHost -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $childScript, "0") } `
                -AuditAction {
                    [void]$successTrace.Add("audit")
                    [IO.File]::WriteAllText($successAudit, '{"passed":true}', [Text.UTF8Encoding]::new($false))
                } `
                -CustodyAction {
                    if (-not (Test-Path -LiteralPath $successAudit -PathType Leaf)) { throw "Fixture custody ran before audit." }
                    [void]$successTrace.Add("custody")
                    [IO.File]::WriteAllText($successCustody, '{"audit_bound":true}', [Text.UTF8Encoding]::new($false))
                } `
                -RegistrationAction {
                    if (-not (Test-Path -LiteralPath $successCustody -PathType Leaf)) { throw "Fixture registration ran before custody." }
                    [void]$successTrace.Add("registration")
                    [IO.File]::WriteAllText($successRegistration, '{"platform":"web"}', [Text.UTF8Encoding]::new($false))
                }
            Assert-True (($successTrace -join ",") -ceq "audit,custody,registration") "RP-012: noisy-success Web pipeline did not traverse audit, custody, and registration exactly once in order."
            Assert-True ((Test-Path -LiteralPath $successAudit -PathType Leaf) -and (Test-Path -LiteralPath $successCustody -PathType Leaf) -and (Test-Path -LiteralPath $successRegistration -PathType Leaf)) "RP-012: noisy-success Web pipeline did not produce all downstream fixture artifacts."

            $failurePipelineRoot = Join-Path $fixtureRoot "pipeline_failure"
            New-Item -ItemType Directory -Path $failurePipelineRoot | Out-Null
            $failureTrace = [Collections.Generic.List[string]]::new()
            $failureRejected = $false
            $failureMessage = ""
            try {
                Invoke-WebExportPipeline `
                    -ExportAction { Invoke-TypedConsoleProcess -FilePath $powerShellHost -ArgumentList @("-NoProfile", "-NonInteractive", "-File", $childScript, "7") } `
                    -AuditAction { [void]$failureTrace.Add("audit"); [IO.File]::WriteAllText((Join-Path $failurePipelineRoot "web_pck_audit.json"), '{}') } `
                    -CustodyAction { [void]$failureTrace.Add("custody"); [IO.File]::WriteAllText((Join-Path $failurePipelineRoot "web_custody.json"), '{}') } `
                    -RegistrationAction { [void]$failureTrace.Add("registration"); [IO.File]::WriteAllText((Join-Path $failurePipelineRoot "candidate_manifest.json"), '{}') }
            }
            catch {
                $failureRejected = $true
                $failureMessage = $_.Exception.Message
            }
            Assert-True ($failureRejected -and $failureMessage -match 'exit 7') "RP-012: noisy-failure Web pipeline did not stop with the child's nonzero exit code."
            Assert-True ($failureTrace.Count -eq 0 -and @(Get-ChildItem -LiteralPath $failurePipelineRoot -File -ErrorAction SilentlyContinue).Count -eq 0) "RP-012: noisy-failure Web pipeline reached audit, custody, or registration."
        }

        # A failed export must not strand the source-identity-keyed candidate.
        # Recover the unregistered partial output without deleting it, publish a
        # fresh attempt transactionally, then prove a registered candidate is
        # reused byte-for-byte instead of being overwritten.
        $attemptCommand = Get-Command Initialize-CandidatePlatformAttempt -CommandType Function -ErrorAction SilentlyContinue
        $publishCommand = Get-Command Complete-CandidatePlatformAttempt -CommandType Function -ErrorAction SilentlyContinue
        Assert-True ($null -ne $attemptCommand -and $null -ne $publishCommand) "Packaging retry: transactional candidate-attempt helpers are missing."
        if ($null -ne $attemptCommand -and $null -ne $publishCommand) {
            $retryFixtureRoot = Join-Path $fixtureRoot "same_source_retry"
            $candidateRoot = Join-Path $retryFixtureRoot "builds/staging/source-key"
            $workRoot = Join-Path $retryFixtureRoot "builds/staging/.work/source-key/windows"
            $finalStage = Join-Path $candidateRoot "windows"
            $finalAudit = Join-Path $candidateRoot "audits/windows_pck_manifest.json"
            New-Item -ItemType Directory -Path $finalStage -Force | Out-Null
            New-Item -ItemType Directory -Path (Split-Path -Parent $finalAudit) -Force | Out-Null
            [IO.File]::WriteAllText((Join-Path $finalStage "partial.bin"), "partial-export-evidence", [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($finalAudit, '{"partial":true}', [Text.UTF8Encoding]::new($false))

            $attempt = Initialize-CandidatePlatformAttempt -CandidateRoot $candidateRoot -WorkRoot $workRoot -Platform "windows" -FinalAuditPath $finalAudit
            Assert-True (-not $attempt.reuse_registered -and $attempt.publish_required) "Packaging retry: an unregistered partial candidate was treated as immutable success."
            Assert-True (-not (Test-Path -LiteralPath $finalStage)) "Packaging retry: the unregistered partial stage still blocks the final immutable path."
            Assert-True ((Test-Path -LiteralPath $attempt.recovered_stage -PathType Container) -and (Get-Content -LiteralPath (Join-Path $attempt.recovered_stage "partial.bin") -Raw) -ceq "partial-export-evidence") "Packaging retry: partial stage evidence was deleted or corrupted instead of being reversibly recovered."
            Assert-True ((Test-Path -LiteralPath $attempt.recovered_audit -PathType Leaf) -and (Get-Content -LiteralPath $attempt.recovered_audit -Raw) -ceq '{"partial":true}') "Packaging retry: partial audit evidence was not recovered with its stage."

            [IO.File]::WriteAllText((Join-Path $attempt.attempt_stage "BeatTheHouse.exe"), "complete-export", [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($attempt.attempt_audit, '{"passed":true}', [Text.UTF8Encoding]::new($false))
            Complete-CandidatePlatformAttempt -Attempt $attempt | Out-Null
            Assert-True ((Test-Path -LiteralPath (Join-Path $finalStage "BeatTheHouse.exe") -PathType Leaf) -and (Test-Path -LiteralPath $finalAudit -PathType Leaf)) "Packaging retry: a complete retry was not promoted with its audit."

            $registeredHash = (Get-FileHash -LiteralPath (Join-Path $finalStage "BeatTheHouse.exe") -Algorithm SHA256).Hash
            $registered = [pscustomobject]@{ platform = "windows"; staging_root = "builds/staging/source-key/windows" }
            $reuse = Initialize-CandidatePlatformAttempt -CandidateRoot $candidateRoot -WorkRoot $workRoot -Platform "windows" -FinalAuditPath $finalAudit -RegisteredPlatform $registered
            $afterReuseHash = (Get-FileHash -LiteralPath (Join-Path $finalStage "BeatTheHouse.exe") -Algorithm SHA256).Hash
            Assert-True ($reuse.reuse_registered -and -not $reuse.publish_required -and $registeredHash -ceq $afterReuseHash) "Packaging retry: a registered immutable candidate was modified instead of reused."
        }
    }
    finally {
        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
        if ($resolvedFixture.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedFixture -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

foreach ($token in @("-Platform `$platform", "-Target `$nativeTarget", "-Architecture `$nativeArchitecture", '-Threading "nothreads"', "Invoke-TypedConsoleProcess", "Invoke-WebExportPipeline", "-AuditAction", "-CustodyAction", "-RegistrationAction", "Initialize-CandidatePlatformAttempt", "Complete-CandidatePlatformAttempt")) {
    Assert-True ($exportTool.Contains($token)) "RP-010/RP-012: export flow is missing '$token'."
}

if ($failures.Count -gt 0) {
    Write-Host "FIXSWEEP06_1_PACKAGING_CONTRACT FAIL ($($failures.Count))" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Host "FIXSWEEP06_1_PACKAGING_CONTRACT PASS" -ForegroundColor Green
