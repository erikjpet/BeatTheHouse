$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$builder = Join-Path $PSScriptRoot "playtest06_owner_build.ps1"
$exporter = Join-Path $PSScriptRoot "export_itch.ps1"
$webSmoke = Join-Path $PSScriptRoot "web_perf_smoke.ps1"
$exportModeContract = Join-Path $PSScriptRoot "web_perf_export_mode_contract_test.ps1"
$failures = [Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Invoke-PowerShellCapture {
    param([string[]]$Arguments)
    $prior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = @(& powershell @Arguments 2>&1 | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    return [pscustomobject]@{ exit_code = $exitCode; output = ($lines -join "`n") }
}

foreach ($path in @($builder, $exporter, $webSmoke, $exportModeContract)) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) "$([IO.Path]::GetFileName($path)) has PowerShell parse errors."
}

$builderText = Get-Content -LiteralPath $builder -Raw
Assert-True (($builderText | Select-String -Pattern 'export_itch\.ps1"\) -Target windows -NoPackage' -AllMatches).Matches.Count -eq 1) "Owner builder must invoke exactly one no-package Windows export."
Assert-True (($builderText | Select-String -Pattern 'web_perf_smoke\.ps1"\).*?-Plan distribution_fresh_start.*?-NoPackageFreshExport' -AllMatches).Matches.Count -eq 1) "Owner builder must request exactly one fresh, no-package Web export through the distribution smoke."
Assert-True (-not ($builderText | Select-String -Pattern 'web_perf_smoke\.ps1"\).*?-SkipExport')) "Owner builder must not skip the required distribution fresh export."
Assert-True (($builderText | Select-String -Pattern '--untracked-files=all' -AllMatches).Matches.Count -eq 2) "Owner builder must reject nonignored untracked files before and after custody production."
$webSmokeText = Get-Content -LiteralPath $webSmoke -Raw
Assert-True (($webSmokeText | Select-String -Pattern '--untracked-files=all' -AllMatches).Matches.Count -eq 2) "Web smoke must reject nonignored untracked files before and after execution."
Assert-True (-not $builderText.Contains("--untracked-files=no")) "Owner builder must not hide untracked files."
Assert-True (-not $webSmokeText.Contains("--untracked-files=no")) "Web smoke must not hide untracked files."
foreach ($forbidden in @("Compress-Archive", "butler push", "git tag", "GitHub Release")) {
    Assert-True (-not $builderText.Contains($forbidden)) "Owner builder contains forbidden release operation '$forbidden'."
}
foreach ($required in @("CandidateCommit", "owner_build_manifest.json", "builds/windows", "builds/web", "smoke_passed", "toolchain_lock_sha256", "export_presets_sha256", "Get-BuildFiles")) {
    Assert-True ($builderText.Contains($required)) "Owner builder is missing custody marker '$required'."
}

$head = (& git -C $root rev-parse HEAD).Trim()
$parent = (& git -C $root rev-parse HEAD^).Trim()
$result = Invoke-PowerShellCapture @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $builder, "-CandidateCommit", $parent, "-RequireGodot")
Assert-True ($result.exit_code -ne 0 -and $result.output.Contains("does not equal CandidateCommit")) "Owner builder did not reject a non-HEAD candidate before export."

$result = Invoke-PowerShellCapture @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $exporter, "-Target", "windows", "-NoPackage", "-Push", "-ItchTarget", "example/game")
Assert-True ($result.exit_code -ne 0 -and $result.output.Contains("cannot be combined with -Push")) "NoPackage accepted an upload request."

$modeResult = Invoke-PowerShellCapture @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $exportModeContract)
Assert-True ($modeResult.exit_code -eq 0) "Web fresh-export mode contract failed: $($modeResult.output)"

$initialStatus = @(& git -C $root status --short --untracked-files=all)
if ($initialStatus.Count -eq 0) {
    $probeRelative = ".playtest06_untracked_probe_$([guid]::NewGuid().ToString('N'))"
    $probePath = Join-Path $root $probeRelative
    try {
        [IO.File]::WriteAllText($probePath, "playtest06 hostile untracked-file probe")
        $result = Invoke-PowerShellCapture @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $builder, "-CandidateCommit", $head, "-RequireGodot")
        Assert-True ($result.exit_code -ne 0 -and $result.output.Contains("nonignored untracked files")) "Owner builder did not reject a nonignored untracked file before engine discovery/export."
    } finally {
        if (Test-Path -LiteralPath $probePath) { Remove-Item -LiteralPath $probePath -Force }
    }
} else {
    Assert-True $false "Untracked-file hostile test requires an otherwise clean candidate."
}

if ($failures.Count -gt 0) {
    Write-Host "playtest06 owner build contract: FAIL ($($failures.Count))" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Host "playtest06 owner build contract: PASS no_package=windows+web_fresh exact_head=required untracked=all hashes=all_outputs smokes=windows+web"
