param(
    [string]$CandidateManifest = "",
    [string]$OutDir = ".tmp/postfix06_2/feature_pcm_runtime",
    [ValidateSet("chrome", "firefox")][string]$Browser = "chrome",
    [int]$Port = 18942,
    [int]$TimeoutMs = 600000
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "export_tree_identity.ps1")
. (Join-Path $PSScriptRoot "web_server_lifecycle.ps1")

$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd([char[]]@('\', '/'))
$stagingRoot = [IO.Path]::GetFullPath((Join-Path $root "builds/staging")).TrimEnd([char[]]@('\', '/'))
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp")).TrimEnd([char[]]@('\', '/'))
$expectedPcmBudgetBytes = 64MB

function Test-PathInside {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Directory)
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    $fullDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd([char[]]@('\', '/'))
    return $fullPath.StartsWith($fullDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-FeatureCondition {
    param([bool]$Condition, [string]$Message, [Collections.Generic.List[string]]$Failures)
    if (-not $Condition) { $Failures.Add($Message) }
}

function Test-ExactJsonBoolean {
    param($Value, [bool]$Expected)
    return $null -ne $Value -and $Value.GetType() -eq [bool] -and $Value -eq $Expected
}

function Get-ExpectedFeatureContextKeys {
    param([ValidateRange(0, 2)][int]$BoundaryIndex)
    $keys = [Collections.Generic.List[string]]::new()
    for ($requestIndex = 0; $requestIndex -lt 32; $requestIndex++) {
        $requestToken = $requestIndex.ToString("00", [Globalization.CultureInfo]::InvariantCulture)
        $cuePrefix = if (($requestIndex % 2) -eq 0) { "buffalo" } else { "pinball" }
        $cueId = "${cuePrefix}_feature_${BoundaryIndex}_${requestToken}"
        $paletteId = "feature_pcm_soak_${BoundaryIndex}_${requestToken}"
        $bpm = (70.0 + $requestIndex).ToString("F2", [Globalization.CultureInfo]::InvariantCulture)
        $keys.Add("$cueId|$paletteId|$bpm")
    }
    return @($keys | Sort-Object)
}

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string]$Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-CurrentSourceIdentity {
    $commit = (& git -C $root rev-parse HEAD).Trim().ToLowerInvariant()
    $tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim().ToLowerInvariant()
    if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$' -or $tree -notmatch '^[0-9a-f]{40}$') { throw "Could not resolve current source commit/tree identity." }
    $status = @(& git -C $root status --porcelain=v1 --untracked-files=all) -join "`n"
    $diffIdentity = ((& git -C $root diff --binary HEAD | & git -C $root hash-object --stdin).Trim()).ToLowerInvariant()
    $untrackedRows = @()
    foreach ($relative in @(& git -C $root ls-files --others --exclude-standard)) {
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            $untrackedRows += "$($relative.Replace('\','/'))`t$hash"
        }
    }
    $dirtyCanonical = "$status`n$diffIdentity`n$(@($untrackedRows | Sort-Object) -join "`n")"
    return [pscustomobject]@{
        source_commit = $commit
        source_tree = $tree
        dirty_state_digest = Get-StringSha256 -Value $dirtyCanonical
    }
}

function Enter-FeaturePcmWorkspaceMutex {
    param([int]$TimeoutSec = 120)
    $rootBytes = [Text.Encoding]::UTF8.GetBytes(([IO.Path]::GetFullPath($root)).ToLowerInvariant())
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($rootBytes))).Replace("-", "").Substring(0, 24) }
    finally { $sha.Dispose() }
    # This is deliberately the same workspace mutex used by check_godot and
    # the shard launcher: the packaged Windows+Web sequence owns one slot.
    $name = "Local\BeatTheHouse_CheckGodot_$hash"
    $mutex = [Threading.Mutex]::new($false, $name)
    $acquired = $false
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSec)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) {
        $mutex.Dispose()
        throw "Timed out waiting for the shared Beat the House workspace test mutex."
    }
    return [pscustomobject]@{ acquired = $true; mutex = $mutex; name = $name }
}

function Exit-FeaturePcmWorkspaceMutex {
    param($Lease)
    if ($null -eq $Lease -or -not [bool]$Lease.acquired -or $null -eq $Lease.mutex) { return }
    try { $Lease.mutex.ReleaseMutex() } catch { }
    try { $Lease.mutex.Dispose() } catch { }
    $Lease.acquired = $false
    $Lease.mutex = $null
}

function Resolve-CandidateManifestPath {
    param([string]$RequestedPath)
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $resolved = if ([IO.Path]::IsPathRooted($RequestedPath)) { [IO.Path]::GetFullPath($RequestedPath) } else { [IO.Path]::GetFullPath((Join-Path $root $RequestedPath)) }
        if (-not (Test-PathInside -Path $resolved -Directory $stagingRoot)) { throw "CandidateManifest must resolve below builds/staging." }
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Candidate manifest is missing: $resolved" }
        return $resolved
    }
    $candidates = @(Get-ChildItem -LiteralPath $stagingRoot -Filter "candidate_manifest.json" -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)
    foreach ($candidateFile in $candidates) {
        try {
            $candidateValue = Get-Content -LiteralPath $candidateFile.FullName -Raw | ConvertFrom-Json
            $completeCandidate = $null -ne $candidateValue.platforms.windows -and $null -ne $candidateValue.platforms.web
            $matchingSource = [string]$candidateValue.source_commit -ceq [string]$script:sourceBefore.source_commit -and [string]$candidateValue.source_tree -ceq [string]$script:sourceBefore.source_tree -and [string]$candidateValue.dirty_state_digest -ceq [string]$script:sourceBefore.dirty_state_digest
            if ($completeCandidate -and $matchingSource) {
                return $candidateFile.FullName
            }
        }
        catch { }
    }
    throw "No complete manifest-bound Windows/Web candidate exists below builds/staging. Run tools/export_itch.ps1 first."
}

function Resolve-StageRoot {
    param($Candidate, [ValidateSet("windows", "web")][string]$Platform)
    $entry = $Candidate.platforms.$Platform
    if ($null -eq $entry) { throw "Candidate manifest has no $Platform platform entry." }
    $relative = [string]$entry.staging_root
    $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not (Test-PathInside -Path $path -Directory $stagingRoot)) { throw "Candidate $Platform staging root escapes builds/staging: $relative" }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "Candidate $Platform staging root is missing: $path" }
    $identity = Get-ExportTreeIdentityFromDirectory -Directory $path
    if ([string]$identity.aggregate_sha256 -cne [string]$entry.export_identity_sha256) { throw "Candidate $Platform staging tree no longer matches its registered export identity." }
    return [pscustomobject]@{ Path = $path; Entry = $entry; Identity = $identity }
}

function Wait-ForWebServer {
    param([string]$Url, [int]$TimeoutSec)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) { return }
        }
        catch { Start-Sleep -Milliseconds 250 }
    }
    throw "Timed out waiting for Web candidate server at $Url."
}

function Wait-ForProjectRuntimeSlot {
    param([int]$TimeoutSec = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        $conflicts = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
            $name = [string]$_.Name
            $commandLine = [string]$_.CommandLine
            $executablePath = [string]$_.ExecutablePath
            ($name -like "Godot*.exe" -or $name -like "BeatTheHouse*.exe") -and
                ($commandLine.IndexOf($root, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $executablePath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase))
        })
        if ($conflicts.Count -eq 0) { return }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "Timed out waiting for the existing Beat the House Godot/runtime process slot (PIDs $(@($conflicts.ProcessId) -join ', '))."
}

function Get-NativeRuntimeLogIssues {
    param([Parameter(Mandatory = $true)][string[]]$Paths)
    $lines = @()
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $lines += @(Get-Content -LiteralPath $path -ErrorAction Stop)
        }
    }
    $issues = @($lines | Where-Object { [string]$_ -match '^\s*(SCRIPT ERROR|ERROR|WARNING):' })
    $objectDbWarning = 'WARNING: ObjectDB instances leaked at exit (run with --verbose for details).'
    if ($issues -contains $objectDbWarning) {
        $leakedInstances = @($lines | Where-Object { [string]$_ -match '^Leaked instance:' })
        $nonZeroOrUnclassified = @($leakedInstances | Where-Object { [string]$_ -notmatch ' - Reference count: 0\s*$' })
        if ($leakedInstances.Count -gt 0 -and $nonZeroOrUnclassified.Count -eq 0) {
            $issues = @($issues | Where-Object { [string]$_ -cne $objectDbWarning })
        }
    }
    return @($issues | Sort-Object -Unique)
}

function Test-FeaturePcmReport {
    param($Report, [ValidateSet("windows", "web")][string]$Platform, $Candidate, [string]$ExportIdentity)
    $failures = [Collections.Generic.List[string]]::new()
    Assert-FeatureCondition (Test-ExactJsonBoolean -Value $Report.passed -Expected $true) "Runtime report did not contain a strict successful Boolean result." $failures
    Assert-FeatureCondition ([string]$Report.plan -ceq "feature_pcm_cache") "Runtime report did not execute the feature_pcm_cache plan." $failures
    Assert-FeatureCondition ([string]$Report.platform -ceq $Platform) "Runtime report platform '$($Report.platform)' did not match $Platform." $failures
    Assert-FeatureCondition ([string]$Report.build_identity.identity_source -ceq "embedded_manifest") "Runtime did not read the embedded distribution identity." $failures
    Assert-FeatureCondition ([string]$Report.build_identity.source_commit -ceq [string]$Candidate.source_commit) "Runtime source commit did not match the candidate manifest." $failures
    Assert-FeatureCondition ([string]$Report.build_identity.source_tree -ceq [string]$Candidate.source_tree) "Runtime source tree did not match the candidate manifest." $failures
    Assert-FeatureCondition ([string]$Report.build_identity.dirty_state_digest -ceq [string]$Candidate.dirty_state_digest) "Runtime dirty-state digest did not match the candidate manifest." $failures
    Assert-FeatureCondition ([string]$Report.build_identity.build_version -ceq [string]$Candidate.build_version) "Runtime build version did not match the candidate manifest." $failures
    Assert-FeatureCondition ([string]$Report.build_identity.platform -ceq $Platform) "Embedded build platform did not match $Platform." $failures
    Assert-FeatureCondition (-not [string]::IsNullOrWhiteSpace($ExportIdentity) -and [string]$Report.build_identity.export_sha256 -ceq $ExportIdentity) "Runtime export identity did not match the staged candidate export tree." $failures

    $events = @($Report.events | Where-Object { [string]$_.id -ceq "feature_pcm_cache_soak_contract" })
    Assert-FeatureCondition ($events.Count -eq 1) "Feature PCM soak event did not run exactly once." $failures
    if ($events.Count -eq 1) {
        $evidence = $events[0].data
        Assert-FeatureCondition ([string]$evidence.schema -ceq "beat_the_house.feature_pcm_cache_soak/v1") "Feature PCM soak schema is missing or changed." $failures
        Assert-FeatureCondition (Test-ExactJsonBoolean -Value $evidence.passed -Expected $true) "Feature PCM soak reported failure or a non-Boolean pass value." $failures
        Assert-FeatureCondition ([string]$evidence.platform -ceq $Platform) "Feature PCM event platform did not match $Platform." $failures
        Assert-FeatureCondition ([int]$evidence.boundary_count -eq 3) "Feature PCM soak did not report exactly three run boundaries." $failures
        Assert-FeatureCondition ([int]$evidence.requests_per_boundary -eq 32) "Feature PCM soak did not report exactly 32 distinct requests per boundary." $failures
        Assert-FeatureCondition ([int]$evidence.distinct_context_count -eq [int]$evidence.request_count) "Feature PCM soak reused a contextual request identity." $failures
        $expectedAllContextKeys = @(0..2 | ForEach-Object { Get-ExpectedFeatureContextKeys -BoundaryIndex $_ } | Sort-Object)
        $reportedAllContextKeys = @($evidence.context_keys | ForEach-Object { [string]$_ } | Sort-Object)
        Assert-FeatureCondition ($reportedAllContextKeys.Count -eq $expectedAllContextKeys.Count -and ($reportedAllContextKeys -join "`n") -ceq ($expectedAllContextKeys -join "`n")) "Aggregate contextual request identity array did not match the deterministic 96-request workload." $failures
        Assert-FeatureCondition (@($evidence.physical_cache_keys).Count -eq 2) "Feature requests did not deduplicate to the two delivered physical styles." $failures
        Assert-FeatureCondition (Test-ExactJsonBoolean -Value $evidence.memory_stability.passed -Expected $true) "Feature PCM repeated-boundary memory did not remain on its fixed plateau or returned a non-Boolean pass value." $failures
        $memorySamples = @($evidence.memory_stability.cleanup_samples_bytes | ForEach-Object { [int64]$_ })
        Assert-FeatureCondition ($memorySamples.Count -eq [int]$evidence.boundary_count) "Feature PCM memory plateau samples are incomplete." $failures
        Assert-FeatureCondition ([int]$evidence.memory_stability.warmup_boundary_count -eq 2 -and [int]$evidence.memory_stability.plateau_reference_boundary_index -eq 1) "Feature PCM memory evidence changed its two-boundary allocator warm-up." $failures
        $independentPlateauReference = if ($memorySamples.Count -ge 2) { [int64]$memorySamples[1] } else { 0 }
        Assert-FeatureCondition ([int64]$evidence.memory_stability.plateau_reference_bytes -eq $independentPlateauReference -and $independentPlateauReference -gt 0 -and [int64]$evidence.memory_stability.plateau_allowance_bytes -eq 16MB) "Feature PCM memory plateau does not use the second warm-up sample or changed its fixed allowance." $failures
        for ($memoryIndex = 0; $memoryIndex -lt $memorySamples.Count; $memoryIndex++) {
            Assert-FeatureCondition ($memorySamples[$memoryIndex] -gt 0) "Feature PCM memory sample $memoryIndex was unavailable." $failures
            if ($memoryIndex -ge 2) {
                Assert-FeatureCondition ($memorySamples[$memoryIndex] -le ($independentPlateauReference + 16MB)) "Feature PCM validation sample $memoryIndex exceeded the second-boundary fixed plateau." $failures
            }
        }
        Assert-FeatureCondition ([int64]$evidence.memory_stability.maximum_cleanup_bytes -le ([int64]$evidence.memory_stability.plateau_reference_bytes + 16MB)) "Feature PCM cleanup memory exceeded the independently checked fixed plateau." $failures
        Assert-FeatureCondition ([int64]$evidence.memory_stability.post_probe_cleanup_bytes -gt 0 -and [int64]$evidence.memory_stability.post_probe_cleanup_bytes -le ([int64]$evidence.memory_stability.plateau_reference_bytes + 16MB)) "Feature PCM post-probe cleanup did not return to the fixed memory plateau." $failures
        $boundaries = @($evidence.boundaries)
        Assert-FeatureCondition ($boundaries.Count -eq [int]$evidence.boundary_count) "Feature PCM boundary evidence count is incomplete." $failures
        $expectedBoundaryIndices = @(0, 1, 2)
        $boundaryIndices = @($boundaries | ForEach-Object { [int]$_.index } | Sort-Object)
        Assert-FeatureCondition ($boundaryIndices.Count -eq $expectedBoundaryIndices.Count -and ($boundaryIndices -join ",") -ceq "0,1,2") "Feature PCM evidence did not contain the exact unique indices 0,1,2." $failures
        foreach ($boundary in $boundaries) {
            $label = "boundary $([int]$boundary.index)"
            Assert-FeatureCondition (Test-ExactJsonBoolean -Value $boundary.passed -Expected $true) "$label failed its runtime assertions or returned a non-Boolean pass value." $failures
            Assert-FeatureCondition ([int]$boundary.request_count -gt 24 -and [int]$boundary.distinct_context_count -eq [int]$boundary.request_count) "$label did not exercise more than 24 unique contextual keys." $failures
            $expectedBoundaryContextKeys = @(Get-ExpectedFeatureContextKeys -BoundaryIndex ([int]$boundary.index))
            $reportedBoundaryContextKeys = @($boundary.context_keys | ForEach-Object { [string]$_ } | Sort-Object)
            Assert-FeatureCondition ($reportedBoundaryContextKeys.Count -eq [int]$boundary.request_count -and ($reportedBoundaryContextKeys -join "`n") -ceq ($expectedBoundaryContextKeys -join "`n")) "$label contextual request identity array did not match its deterministic 32-request workload." $failures
            Assert-FeatureCondition ([int]$boundary.successful_load_count -eq [int]$boundary.request_count -and [int]$boundary.successful_play_count -eq [int]$boundary.request_count) "$label did not complete every production load/play handoff." $failures
            Assert-FeatureCondition (Test-ExactJsonBoolean -Value $boundary.production_entry_bytes_positive -Expected $true) "$label observed a non-positive production cache entry or returned a non-Boolean assertion." $failures
            Assert-FeatureCondition (Test-ExactJsonBoolean -Value $boundary.memory_plateau_ok -Expected $true) "$label exceeded the fixed repeated-boundary memory plateau or returned a non-Boolean assertion." $failures
            if ([int]$boundary.index -lt 2) {
                $expectedMemoryPhase = if ([int]$boundary.index -eq 0) { "warmup_initial" } else { "warmup_plateau_reference" }
                Assert-FeatureCondition ((Test-ExactJsonBoolean -Value $boundary.memory_plateau_enforced -Expected $false) -and [string]$boundary.memory_phase -ceq $expectedMemoryPhase) "$label was not labelled as an unenforced allocator warm-up sample with a strict Boolean assertion." $failures
            }
            else {
                Assert-FeatureCondition ((Test-ExactJsonBoolean -Value $boundary.memory_plateau_enforced -Expected $true) -and [string]$boundary.memory_phase -ceq "plateau_validation") "$label did not enforce the fixed post-warm-up plateau with a strict Boolean assertion." $failures
            }
            Assert-FeatureCondition (@($boundary.physical_cache_keys).Count -eq 2) "$label did not deduplicate to two physical cache keys." $failures
            Assert-FeatureCondition ([int]$boundary.populated.feature_entry_count -eq 2) "$label retained an unexpected number of feature packs." $failures
            Assert-FeatureCondition ([int]$boundary.populated.feature_accounting.key_count -eq 2 -and [int64]$boundary.populated.feature_accounting.bytes -gt 0) "$label feature packs were absent from shared byte accounting." $failures
            $featureRawBytes = [int64]$boundary.populated.feature_accounting.raw_bytes
            $featureEncodedBytes = [int64]$boundary.populated.feature_accounting.encoded_bytes
            $featureTotalBytes = [int64]$boundary.populated.feature_accounting.bytes
            Assert-FeatureCondition ($featureRawBytes -gt 0 -and $featureTotalBytes -eq ($featureRawBytes + $featureEncodedBytes)) "$label raw/encoded feature accounting did not reconcile to its enforced total." $failures
            if ($Platform -eq "windows") {
                Assert-FeatureCondition ($featureEncodedBytes -eq 0) "$label native feature accounting unexpectedly retained Web base64 metadata." $failures
            }
            else {
                Assert-FeatureCondition ($featureEncodedBytes -gt 0) "$label Web feature accounting omitted retained base64 metadata." $failures
            }
            Assert-FeatureCondition ([int64]$boundary.populated.cache_bytes -eq ([int64]$boundary.populated.cache_raw_bytes + [int64]$boundary.populated.cache_encoded_bytes)) "$label shared raw/encoded cache accounting did not reconcile to its enforced total." $failures
            Assert-FeatureCondition ([int64]$boundary.populated.cache_budget_bytes -eq $expectedPcmBudgetBytes) "$label changed the declared 64 MiB PCM budget." $failures
            Assert-FeatureCondition ([int64]$boundary.populated.cache_bytes -le [int64]$boundary.populated.cache_budget_bytes) "$label exceeded the shared PCM budget." $failures
            Assert-FeatureCondition ([int64]$boundary.populated.combined_pcm_budget_bytes -eq $expectedPcmBudgetBytes) "$label changed the combined native/base64/Web-decoded PCM budget." $failures
            Assert-FeatureCondition (Test-ExactJsonBoolean -Value $boundary.populated.combined_pcm_within_budget -Expected $true) "$label exceeded the combined native/base64/Web-decoded PCM budget or returned a non-Boolean assertion." $failures
            Assert-FeatureCondition ([int64]$boundary.populated.combined_pcm_bytes -eq ([int64]$boundary.populated.cache_bytes + [int64]$boundary.populated.web_decoded_bytes) -and [int64]$boundary.populated.combined_pcm_bytes -le $expectedPcmBudgetBytes) "$label combined native/base64/Web-decoded PCM accounting did not reconcile within budget." $failures
            Assert-FeatureCondition ([int]$boundary.cleared.feature_entry_count -eq 0 -and [int]$boundary.cleared.feature_accounting.key_count -eq 0 -and [int64]$boundary.cleared.feature_accounting.bytes -eq 0) "$label retained feature entries after run cleanup." $failures
            Assert-FeatureCondition ([int64]$boundary.cleared.cache_bytes -eq 0) "$label shared cache telemetry did not return to its empty probe baseline." $failures
            Assert-FeatureCondition ([int64]$boundary.cleared.cache_raw_bytes -eq 0 -and [int64]$boundary.cleared.cache_encoded_bytes -eq 0) "$label shared raw/encoded telemetry did not return to zero." $failures
            Assert-FeatureCondition ([int64]$boundary.cleared.combined_pcm_budget_bytes -eq $expectedPcmBudgetBytes -and (Test-ExactJsonBoolean -Value $boundary.cleared.combined_pcm_within_budget -Expected $true)) "$label cleanup did not retain the combined PCM ceiling with a strict within-budget result." $failures
            Assert-FeatureCondition ([int64]$boundary.cleared.combined_pcm_bytes -eq ([int64]$boundary.cleared.cache_bytes + [int64]$boundary.cleared.web_decoded_bytes)) "$label cleanup combined PCM accounting did not reconcile." $failures
            if ($Platform -eq "web") {
                $baseline = $evidence.web_bridge_baseline
                $populatedBridge = $boundary.populated.web_bridge
                $clearedBridge = $boundary.cleared.web_bridge
                Assert-FeatureCondition (Test-ExactJsonBoolean -Value $baseline.pcm_diagnostics_actual -Expected $true) "$label Web bridge baseline was not an actual decoded-PCM snapshot with a strict Boolean assertion." $failures
                Assert-FeatureCondition (Test-ExactJsonBoolean -Value $populatedBridge.pcm_diagnostics_actual -Expected $true) "$label Web bridge did not report actual decoded-PCM diagnostics with a strict Boolean assertion." $failures
                Assert-FeatureCondition (Test-ExactJsonBoolean -Value $boundary.web_pcm_plateau_unchanged -Expected $true) "$label Web decoded PCM grew or churned after both styles loaded, or returned a non-Boolean assertion." $failures
                Assert-FeatureCondition ([int]$boundary.web_pcm_plateau_count -eq @($boundary.web_pcm_plateau_keys).Count -and [int]$boundary.web_pcm_plateau_count -eq [int]$populatedBridge.registered_pcm_count -and [int64]$boundary.web_pcm_plateau_bytes -eq [int64]$populatedBridge.registered_pcm_bytes) "$label Web decoded key/count/byte plateau evidence did not reconcile." $failures
                Assert-FeatureCondition ((@($boundary.web_pcm_plateau_keys | Sort-Object) -join "`n") -ceq (@($populatedBridge.registered_pcm_keys | Sort-Object) -join "`n")) "$label Web decoded PCM key set changed after the two physical styles loaded." $failures
                Assert-FeatureCondition ([int64]$populatedBridge.pcm_budget_bytes -eq ($expectedPcmBudgetBytes - [int64]$boundary.populated.cache_bytes)) "$label Web decoded-PCM budget was not the remainder of the single shared ceiling." $failures
                Assert-FeatureCondition ([int64]$populatedBridge.registered_pcm_bytes -gt [int64]$baseline.registered_pcm_bytes) "$label did not activate feature PCM in the Web bridge." $failures
                Assert-FeatureCondition ([int64]$populatedBridge.registered_pcm_bytes -le [int64]$populatedBridge.pcm_budget_bytes) "$label exceeded the Web decoded-PCM budget." $failures
                Assert-FeatureCondition ([int64]$populatedBridge.combined_pcm_bytes -eq [int64]$boundary.populated.combined_pcm_bytes -and [int64]$populatedBridge.combined_pcm_budget_bytes -eq $expectedPcmBudgetBytes -and (Test-ExactJsonBoolean -Value $populatedBridge.combined_pcm_within_budget -Expected $true)) "$label Web diagnostics disagreed with the combined native/base64/Web-decoded PCM budget." $failures
                Assert-FeatureCondition (Test-ExactJsonBoolean -Value $clearedBridge.pcm_diagnostics_actual -Expected $true) "$label Web cleanup did not report actual decoded-PCM diagnostics with a strict Boolean assertion." $failures
                Assert-FeatureCondition ([int]$clearedBridge.registered_pcm_count -eq [int]$baseline.registered_pcm_count -and [int64]$clearedBridge.registered_pcm_bytes -eq [int64]$baseline.registered_pcm_bytes) "$label Web bridge did not return to its pre-soak PCM baseline." $failures
                Assert-FeatureCondition ((@($clearedBridge.registered_pcm_keys | Sort-Object) -join "`n") -ceq (@($baseline.registered_pcm_keys | Sort-Object) -join "`n")) "$label Web bridge cleanup did not restore the pre-soak decoded key set." $failures
            }
        }
    }
    return [pscustomobject]@{
        passed = $failures.Count -eq 0
        platform = $Platform
        export_identity_sha256 = $ExportIdentity
        failures = @($failures)
    }
}

if ($TimeoutMs -lt 1000) { throw "TimeoutMs must be at least 1000." }
$workspaceMutexLease = $null
try {
$workspaceMutexLease = Enter-FeaturePcmWorkspaceMutex
$script:sourceBefore = Get-CurrentSourceIdentity
$candidateManifestPath = Resolve-CandidateManifestPath -RequestedPath $CandidateManifest
$candidateManifestSha256Before = (Get-FileHash -LiteralPath $candidateManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$candidate = Get-Content -LiteralPath $candidateManifestPath -Raw | ConvertFrom-Json
if ([string]$candidate.schema -cne "beat_the_house.candidate_manifest/v1") { throw "Candidate manifest schema is invalid." }
foreach ($field in @("source_commit", "source_tree", "dirty_state_digest", "build_version")) {
    if ([string]::IsNullOrWhiteSpace([string]$candidate.$field)) { throw "Candidate manifest is missing '$field'." }
}
$candidateMatchesSource = [string]$candidate.source_commit -ceq [string]$script:sourceBefore.source_commit -and [string]$candidate.source_tree -ceq [string]$script:sourceBefore.source_tree -and [string]$candidate.dirty_state_digest -ceq [string]$script:sourceBefore.dirty_state_digest
if (-not $candidateMatchesSource) {
    throw "Candidate manifest does not match the current commit/tree/dirty-state identity. Rebuild the Windows/Web candidate before qualification."
}
$windowsStage = Resolve-StageRoot -Candidate $candidate -Platform windows
$webStage = Resolve-StageRoot -Candidate $candidate -Platform web
$out = if ([IO.Path]::IsPathRooted($OutDir)) { [IO.Path]::GetFullPath($OutDir) } else { [IO.Path]::GetFullPath((Join-Path $root $OutDir)) }
if (-not (Test-PathInside -Path $out -Directory $tmpRoot)) { throw "OutDir must resolve below .tmp." }
if (Test-Path -LiteralPath $out) { throw "Refusing to overwrite feature PCM runtime evidence: $out" }
New-Item -ItemType Directory -Path $out | Out-Null

$windowsExecutables = @(Get-ChildItem -LiteralPath $windowsStage.Path -Filter "*.exe" -File -Recurse)
if ($windowsExecutables.Count -ne 1) { throw "Expected exactly one Windows candidate executable, found $($windowsExecutables.Count)." }
$nativeReportPath = Join-Path $out "windows.runtime.json"
$nativeStdout = Join-Path $out "windows.stdout.txt"
$nativeStderr = Join-Path $out "windows.stderr.txt"
$nativeLog = Join-Path $out "windows.godot.log"
$nativeProfile = Join-Path $out "windows_profile"
$nativeArguments = @(
    "--headless", "--rendering-method", "gl_compatibility", "--verbose", "--log-file", $nativeLog, "--",
    "--bth_perf=1", "--bth_perf_plan=feature_pcm_cache", "--bth_perf_auto_quit=1",
    "--bth_perf_report=$nativeReportPath", "--bth_perf_export_sha256=$($windowsStage.Identity.aggregate_sha256)",
    "--bth_perf_evidence_profile=postfix06_2_feature_pcm_windows"
)
$null = Wait-ForProjectRuntimeSlot
$priorDistributionRoot = $env:BTH_DISTRIBUTION_DATA_ROOT
$nativeProcess = $null
$nativeExitCode = $null
try {
    try {
        $env:BTH_DISTRIBUTION_DATA_ROOT = $nativeProfile.Replace('\', '/')
        $nativeProcess = Start-Process -FilePath $windowsExecutables[0].FullName -ArgumentList $nativeArguments -RedirectStandardOutput $nativeStdout -RedirectStandardError $nativeStderr -PassThru -WindowStyle Hidden
        $nativeProcess.EnableRaisingEvents = $true
    }
    finally { $env:BTH_DISTRIBUTION_DATA_ROOT = $priorDistributionRoot }
    if (-not $nativeProcess.WaitForExit($TimeoutMs)) {
        Stop-Process -Id $nativeProcess.Id -Force -ErrorAction SilentlyContinue
        $nativeProcess.WaitForExit()
        throw "Windows feature PCM runtime timed out after $TimeoutMs ms."
    }
    $nativeProcess.Refresh()
    $nativeExitCode = $nativeProcess.ExitCode
}
finally {
    if ($null -ne $nativeProcess) {
        if (-not $nativeProcess.HasExited) {
            Stop-Process -Id $nativeProcess.Id -Force -ErrorAction SilentlyContinue
            $nativeProcess.WaitForExit()
        }
        $nativeProcess.Dispose()
    }
}
$nativeIssues = @(Get-NativeRuntimeLogIssues -Paths @($nativeStdout, $nativeStderr, $nativeLog))
if ($nativeExitCode -ne 0) {
    $nativeIssueSuffix = if ($nativeIssues.Count -gt 0) { " Diagnostics: $($nativeIssues -join ' | ')" } else { "" }
    throw "Windows feature PCM runtime exited $nativeExitCode.$nativeIssueSuffix"
}
if (-not (Test-Path -LiteralPath $nativeReportPath -PathType Leaf)) { throw "Windows feature PCM runtime emitted no report." }
if (-not (Test-Path -LiteralPath $nativeLog -PathType Leaf)) { throw "Windows feature PCM runtime emitted no explicit engine log." }
$nativeReport = Get-Content -LiteralPath $nativeReportPath -Raw | ConvertFrom-Json
$nativeEvaluation = Test-FeaturePcmReport -Report $nativeReport -Platform windows -Candidate $candidate -ExportIdentity ([string]$windowsStage.Identity.aggregate_sha256)
if ($nativeIssues.Count -gt 0) {
    $nativeFailures = [Collections.Generic.List[string]]::new()
    foreach ($failure in @($nativeEvaluation.failures)) { $nativeFailures.Add([string]$failure) }
    foreach ($issue in $nativeIssues) { $nativeFailures.Add("Windows runtime emitted an unexpected engine/script warning/error: $issue") }
    $nativeEvaluation = [pscustomobject]@{ passed = $false; platform = "windows"; export_identity_sha256 = [string]$windowsStage.Identity.aggregate_sha256; failures = @($nativeFailures) }
}

$null = Wait-ForProjectRuntimeSlot
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) { throw "Node.js was not found on PATH." }
$browserReportPath = Join-Path $out "web.browser.json"
$serverStdout = Join-Path $out "web_server.stdout.txt"
$serverStderr = Join-Path $out "web_server.stderr.txt"
$serverOwnership = Join-Path $out ("web_server.ownership.{0}.json" -f [guid]::NewGuid().ToString("N"))
$browserProfile = Join-Path $out "web_profile"
$server = $null
try {
    $server = Start-OwnedWebServer -ServeScript (Join-Path $PSScriptRoot "serve_web.ps1") -ServerScript (Join-Path $PSScriptRoot "serve_web_server.py") -ServeRoot $webStage.Path -Port $Port -OwnershipFile $serverOwnership -StandardOutput $serverStdout -StandardError $serverStderr
    Wait-ForWebServer -Url "http://127.0.0.1:$Port/" -TimeoutSec 30
    Assert-OwnedWebServerListener -Launch $server
    $url = "http://127.0.0.1:$Port/?bth_perf=1&bth_perf_plan=feature_pcm_cache&bth_perf_auto_quit=1&bth_perf_export_sha256=$($webStage.Identity.aggregate_sha256)&bth_perf_evidence_profile=postfix06_2_feature_pcm_web"
    $probeArguments = @(
        (Join-Path $PSScriptRoot "archive/l02/l02_web_perf_probe.mjs"),
        "--browser=$Browser", "--headless=true", "--cpu=1", "--timeout-ms=$TimeoutMs",
        "--url=$url", "--out=$browserReportPath", "--profile=$browserProfile", "--cold-cache=true"
    )
    & $node.Source @probeArguments
    if ($LASTEXITCODE -ne 0) { throw "Web feature PCM browser probe failed with exit code $LASTEXITCODE." }
}
finally {
    if ($null -ne $server) { Stop-OwnedWebServer -Launch $server }
}
if (-not (Test-Path -LiteralPath $browserReportPath -PathType Leaf)) { throw "Web feature PCM browser probe emitted no report." }
$browserEnvelope = Get-Content -LiteralPath $browserReportPath -Raw | ConvertFrom-Json
$webFailures = [Collections.Generic.List[string]]::new()
Assert-FeatureCondition (@($browserEnvelope.page_errors).Count -eq 0) "Web browser captured a page error." $webFailures
Assert-FeatureCondition (@($browserEnvelope.request_failures).Count -eq 0) "Web browser captured a failed request." $webFailures
Assert-FeatureCondition (@($browserEnvelope.failed_responses).Count -eq 0) "Web browser captured an HTTP failure response." $webFailures
$unexpectedConsole = @($browserEnvelope.startup_console | Where-Object { [string]$_.classification -notin @("expected_audio_autoplay_warning") })
Assert-FeatureCondition ($unexpectedConsole.Count -eq 0) "Web browser captured an unexpected warning/error." $webFailures
$webEvaluation = Test-FeaturePcmReport -Report $browserEnvelope.report -Platform web -Candidate $candidate -ExportIdentity ([string]$webStage.Identity.aggregate_sha256)
foreach ($failure in @($webEvaluation.failures)) { $webFailures.Add([string]$failure) }
$webEvaluation = [pscustomobject]@{ passed = $webFailures.Count -eq 0; platform = "web"; export_identity_sha256 = [string]$webStage.Identity.aggregate_sha256; failures = @($webFailures) }

$windowsAfter = Get-ExportTreeIdentityFromDirectory -Directory $windowsStage.Path
$webAfter = Get-ExportTreeIdentityFromDirectory -Directory $webStage.Path
if ([string]$windowsAfter.aggregate_sha256 -cne [string]$windowsStage.Identity.aggregate_sha256 -or [string]$webAfter.aggregate_sha256 -cne [string]$webStage.Identity.aggregate_sha256) { throw "A registered candidate staging tree changed during feature PCM qualification." }
$candidateManifestSha256After = (Get-FileHash -LiteralPath $candidateManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($candidateManifestSha256After -cne $candidateManifestSha256Before) { throw "Candidate manifest changed during feature PCM qualification." }
$sourceAfter = Get-CurrentSourceIdentity
$sourceStayedFixed = [string]$sourceAfter.source_commit -ceq [string]$script:sourceBefore.source_commit -and [string]$sourceAfter.source_tree -ceq [string]$script:sourceBefore.source_tree -and [string]$sourceAfter.dirty_state_digest -ceq [string]$script:sourceBefore.dirty_state_digest
if (-not $sourceStayedFixed) {
    throw "The source worktree changed during feature PCM qualification."
}
$allFailures = @($nativeEvaluation.failures) + @($webEvaluation.failures)
$summary = [ordered]@{
    schema = "beat_the_house.postfix06_2_feature_pcm_runtime/v1"
    passed = $allFailures.Count -eq 0
    candidate_manifest = $candidateManifestPath
    candidate_manifest_sha256 = $candidateManifestSha256Before
    source_commit = [string]$candidate.source_commit
    source_tree = [string]$candidate.source_tree
    dirty_state_digest = [string]$candidate.dirty_state_digest
    build_version = [string]$candidate.build_version
    windows = $nativeEvaluation
    web = $webEvaluation
    failures = $allFailures
}
$summaryPath = Join-Path $out "summary.json"
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryPath -Encoding utf8
if ($allFailures.Count -gt 0) {
    throw "Feature PCM runtime qualification failed: $($allFailures -join ' | ')"
}
Write-Host "POSTFIX06_2 FEATURE PCM RUNTIME PASS boundaries=3 requests_per_boundary=32 platforms=windows,web summary=$summaryPath"
}
finally {
    Exit-FeaturePcmWorkspaceMutex -Lease $workspaceMutexLease
}
