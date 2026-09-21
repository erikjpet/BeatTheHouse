$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "playtest06_owner_evidence_transaction.ps1")
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$testRoot = Join-Path $repoRoot ".tmp/playtest06_owner_evidence_transaction_contract/$([guid]::NewGuid().ToString('N'))"
$tempBase = Join-Path $testRoot "invocations"
$retainedRoot = Join-Path $testRoot "retained"
$targets = @("owner_build_windows_smoke.json", "owner_build_web_smoke.json", "owner_build_manifest.json") | ForEach-Object { Join-Path $retainedRoot $_ }
$buildAttempts = 0
$failures = [Collections.Generic.List[string]]::new()
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }
function Produce-Fixture([string]$StagingRoot) {
    $script:buildAttempts += 1
    $mappings = @()
    foreach ($target in $script:targets) {
        $source = Join-Path $StagingRoot ([IO.Path]::GetFileName($target))
        [ordered]@{ schema = "transaction-test"; attempt = $script:buildAttempts; complete = $true } | ConvertTo-Json | Set-Content -LiteralPath $source -Encoding utf8
        $mappings += [ordered]@{ source = $source; target = $target }
    }
    return [pscustomobject]@{ mappings = $mappings; attempt = $script:buildAttempts }
}

try {
    $lateFailure = ""
    try {
        Invoke-Playtest06OwnerEvidenceTransaction -TempBase $tempBase -TargetPaths $targets -Produce ${function:Produce-Fixture} -Validate { param($payload) throw "injected late validation failure after serialization" } | Out-Null
    } catch { $lateFailure = $_.Exception.Message }
    Assert-True ($lateFailure.Contains("injected late validation failure")) "Injected late validation failure did not trip."
    Assert-True (@($targets | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 0) "Late failure left retained evidence that would poison retry."

    $retry = Invoke-Playtest06OwnerEvidenceTransaction -TempBase $tempBase -TargetPaths $targets -Produce ${function:Produce-Fixture} -Validate {
        param($payload)
        foreach ($mapping in @($payload.mappings)) { Get-Content -LiteralPath $mapping.source -Raw | ConvertFrom-Json | Out-Null }
    }
    Assert-True ($buildAttempts -eq 2 -and [int]$retry.attempt -eq 2) "Immediate retry did not reach the evidence-producing build path."
    Assert-True (@($targets | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }).Count -eq 3) "Successful retry did not publish all three retained files."
    if ($failures.Count -gt 0) {
        Write-Host "playtest06 owner evidence transaction contract: FAIL ($($failures.Count))" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host " - $failure" }
        exit 1
    }
    Write-Host "playtest06 owner evidence transaction contract: PASS late_failure=clean retry=build_path_reached retained=3"
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot ".tmp/playtest06_owner_evidence_transaction_contract"))
        $resolved = [IO.Path]::GetFullPath($testRoot)
        if (-not $resolved.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove transaction test output outside its dedicated root." }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
