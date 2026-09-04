param(
    [int]$SeedsPerPlaystyle,
    [int]$SeedStart,
    [int]$MaxActions,
    [string]$SeedPrefix,
    [string]$Playstyle,
    [string]$BuildRef,
    [string]$Output,
    [string]$ExitRecord,
    [string]$IdentityManifest,
    [string]$IdentityManifestSha256,
    [string]$TrackedManifest,
    [string]$RuntimeManifest,
    [string]$ExpectedHead,
    [string]$ExpectedTree,
    [string]$ExpectedInputManifestSha256,
    [string]$ExpectedPolicyBlob,
    [string]$ExpectedPluginIdentitySha256,
    [string]$ExpectedRuntimeManifestSha256,
    [string]$ExpectedReportSchema
)

$ErrorActionPreference = "Stop"
$started = Get-Date
$projectRoot = Split-Path -Parent $PSScriptRoot
$validationFailures = [Collections.Generic.List[string]]::new()

function Get-ObjectValue([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Add-ManifestFailures([string]$Label, [string]$Root, [string]$ManifestPath, [Collections.Generic.List[string]]$Failures) {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        $Failures.Add("$Label manifest is missing: $ManifestPath")
        return
    }
    try { $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json }
    catch {
        $Failures.Add("$Label manifest is not valid JSON: $($_.Exception.Message)")
        return
    }
    foreach ($entry in @(Get-ObjectValue $manifest "entries")) {
        if ($null -eq $entry) { continue }
        $relativePath = [string](Get-ObjectValue $entry "path")
        $expectedSha = [string](Get-ObjectValue $entry "sha256")
        $expectedBytes = [int64](Get-ObjectValue $entry "bytes")
        $absolutePath = Join-Path $Root $relativePath.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            $Failures.Add("$Label file is missing: $relativePath")
            continue
        }
        $actualBytes = (Get-Item -LiteralPath $absolutePath).Length
        $actualSha = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualBytes -ne $expectedBytes -or $actualSha -cne $expectedSha) {
            $Failures.Add("$Label file identity mismatch: $relativePath")
        }
    }
}

function Add-IdentityFailures([object]$Identity, [Collections.Generic.List[string]]$Failures) {
    $expected = [ordered]@{
        schema = "balance06_1_distribution_shard_identity_v2"
        exact_head = $ExpectedHead
        exact_tree = $ExpectedTree
        input_manifest_sha256 = $ExpectedInputManifestSha256
        policy_blob = $ExpectedPolicyBlob
        plugin_identity_sha256 = $ExpectedPluginIdentitySha256
        runtime_artifact_manifest_sha256 = $ExpectedRuntimeManifestSha256
        report_schema = $ExpectedReportSchema
    }
    foreach ($key in $expected.Keys) {
        $actual = [string](Get-ObjectValue $Identity $key)
        if ($actual -cne [string]$expected[$key]) {
            $Failures.Add("Shard identity mismatch for ${key}: expected '$($expected[$key])', got '$actual'.")
        }
    }
}

function Resolve-OutputPath([string]$Path) {
    if ($Path.StartsWith("res://")) { return Join-Path $projectRoot $Path.Substring(6).Replace("/", "\") }
    return [IO.Path]::GetFullPath($Path)
}

try {
    if ((Get-FileHash -LiteralPath $IdentityManifest -Algorithm SHA256).Hash.ToLowerInvariant() -cne $IdentityManifestSha256) {
        $validationFailures.Add("Shard identity manifest file hash mismatch.")
    }
    $identity = Get-Content -LiteralPath $IdentityManifest -Raw | ConvertFrom-Json
    Add-IdentityFailures $identity $validationFailures
    $trackedManifestFileSha = (Get-FileHash -LiteralPath $TrackedManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    $runtimeManifestFileSha = (Get-FileHash -LiteralPath $RuntimeManifest -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($trackedManifestFileSha -cne [string](Get-ObjectValue $identity "tracked_manifest_file_sha256")) {
        $validationFailures.Add("Tracked input manifest file hash mismatch.")
    }
    if ($runtimeManifestFileSha -cne [string](Get-ObjectValue $identity "runtime_manifest_file_sha256")) {
        $validationFailures.Add("Runtime artifact manifest file hash mismatch.")
    }
    $trackedManifestValue = Get-Content -LiteralPath $TrackedManifest -Raw | ConvertFrom-Json
    $runtimeManifestValue = Get-Content -LiteralPath $RuntimeManifest -Raw | ConvertFrom-Json
    if ([string](Get-ObjectValue $trackedManifestValue "canonical_sha256") -cne $ExpectedInputManifestSha256) {
        $validationFailures.Add("Tracked input manifest canonical identity mismatch.")
    }
    if ([string](Get-ObjectValue $runtimeManifestValue "canonical_sha256") -cne $ExpectedRuntimeManifestSha256) {
        $validationFailures.Add("Runtime artifact manifest canonical identity mismatch.")
    }
    Add-ManifestFailures "tracked source (pre-run)" $projectRoot $TrackedManifest $validationFailures
    Add-ManifestFailures "runtime artifact (pre-run)" $projectRoot $RuntimeManifest $validationFailures
    if ($validationFailures.Count -ne 0) { throw ($validationFailures -join " | ") }

    & (Join-Path $PSScriptRoot "cross_economy_audit.ps1") `
        -SeedsPerPlaystyle $SeedsPerPlaystyle -SeedStart $SeedStart `
        -MaxActions $MaxActions -SeedPrefix $SeedPrefix -Playstyle $Playstyle `
        -BuildRef $BuildRef -Output $Output
    if ($LASTEXITCODE -ne 0) { throw "Audit wrapper returned exit code $LASTEXITCODE." }

    Add-ManifestFailures "tracked source (post-run)" $projectRoot $TrackedManifest $validationFailures
    Add-ManifestFailures "runtime artifact (post-run)" $projectRoot $RuntimeManifest $validationFailures
    if ($validationFailures.Count -ne 0) { throw ($validationFailures -join " | ") }

    $reportPath = Resolve-OutputPath $Output
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw "Shard report was not written: $reportPath" }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ([string](Get-ObjectValue $report "tool") -cne $ExpectedReportSchema) { throw "Shard report schema/tool mismatch." }
    if ([string](Get-ObjectValue $report "build_ref") -cne $ExpectedHead) { throw "Shard report head mismatch." }
    if ([string](Get-ObjectValue $report "playstyle_filter") -cne $Playstyle) { throw "Shard report playstyle mismatch." }
    if ([int](Get-ObjectValue $report "seed_start") -ne $SeedStart -or [int](Get-ObjectValue $report "run_count") -ne $SeedsPerPlaystyle) {
        throw "Shard report seed range/count mismatch."
    }

    $record = [ordered]@{
        schema = "balance06_1_distribution_shard_exit_v2"
        exit_code = 0
        playstyle = $Playstyle
        seed_prefix = $SeedPrefix
        seed_start = $SeedStart
        seed_count = $SeedsPerPlaystyle
        max_actions = $MaxActions
        build_ref = $BuildRef
        exact_head = $ExpectedHead
        exact_tree = $ExpectedTree
        input_manifest_sha256 = $ExpectedInputManifestSha256
        policy_blob = $ExpectedPolicyBlob
        plugin_identity_sha256 = $ExpectedPluginIdentitySha256
        runtime_artifact_manifest_sha256 = $ExpectedRuntimeManifestSha256
        report_schema = $ExpectedReportSchema
        identity_manifest_sha256 = $IdentityManifestSha256
        tracked_manifest_file_sha256 = $trackedManifestFileSha
        runtime_manifest_file_sha256 = $runtimeManifestFileSha
        report_sha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
        validation_failures = @()
        started_at_utc = $started.ToUniversalTime().ToString("o")
        ended_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ExitRecord -Encoding utf8
    exit 0
}
catch {
    if ($validationFailures.Count -eq 0) { $validationFailures.Add($_.Exception.Message) }
    $record = [ordered]@{
        schema = "balance06_1_distribution_shard_exit_v2"
        exit_code = 1
        playstyle = $Playstyle
        seed_prefix = $SeedPrefix
        seed_start = $SeedStart
        seed_count = $SeedsPerPlaystyle
        max_actions = $MaxActions
        build_ref = $BuildRef
        exact_head = $ExpectedHead
        exact_tree = $ExpectedTree
        input_manifest_sha256 = $ExpectedInputManifestSha256
        policy_blob = $ExpectedPolicyBlob
        plugin_identity_sha256 = $ExpectedPluginIdentitySha256
        runtime_artifact_manifest_sha256 = $ExpectedRuntimeManifestSha256
        report_schema = $ExpectedReportSchema
        identity_manifest_sha256 = $IdentityManifestSha256
        tracked_manifest_file_sha256 = if (Test-Path -LiteralPath $TrackedManifest -PathType Leaf) { (Get-FileHash -LiteralPath $TrackedManifest -Algorithm SHA256).Hash.ToLowerInvariant() } else { "missing" }
        runtime_manifest_file_sha256 = if (Test-Path -LiteralPath $RuntimeManifest -PathType Leaf) { (Get-FileHash -LiteralPath $RuntimeManifest -Algorithm SHA256).Hash.ToLowerInvariant() } else { "missing" }
        validation_failures = @($validationFailures)
        error = $_.Exception.Message
        started_at_utc = $started.ToUniversalTime().ToString("o")
        ended_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ExitRecord -Encoding utf8
    Write-Error $_
    exit 1
}
