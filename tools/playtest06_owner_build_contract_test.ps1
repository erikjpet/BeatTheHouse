$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$builder = Join-Path $PSScriptRoot "playtest06_owner_build.ps1"
$exporter = Join-Path $PSScriptRoot "export_itch.ps1"
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

foreach ($path in @($builder, $exporter)) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    Assert-True ($errors.Count -eq 0) "$([IO.Path]::GetFileName($path)) has PowerShell parse errors."
}

$builderText = Get-Content -LiteralPath $builder -Raw
Assert-True (($builderText | Select-String -Pattern 'export_itch\.ps1"\) -Target windows -NoPackage' -AllMatches).Matches.Count -eq 1) "Owner builder must invoke exactly one no-package Windows export."
Assert-True (($builderText | Select-String -Pattern 'export_itch\.ps1"\) -Target web -NoPackage' -AllMatches).Matches.Count -eq 1) "Owner builder must invoke exactly one no-package Web export."
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

if ($failures.Count -gt 0) {
    Write-Host "playtest06 owner build contract: FAIL ($($failures.Count))" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host " - $failure" }
    exit 1
}
Write-Host "playtest06 owner build contract: PASS no_package=2 exact_head=required hashes=all_outputs smokes=windows+web"
