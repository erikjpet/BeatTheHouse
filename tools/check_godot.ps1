param(
    [ValidateSet("Smoke", "Contract", "Audit", "Full")]
    [string]$Suite = "Smoke",
    [switch]$RequireGodot,
    [int]$TimeoutSec = 0,
    [switch]$KeepGoing,
    [string]$ReportDir = "",
    [switch]$NoImport,
    [switch]$VerboseStages,
    [switch]$ExhaustiveParse,
    [string]$FoundationSuite = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$suiteKey = $Suite.ToLowerInvariant()
$foundationSuiteKey = $FoundationSuite.Trim().ToLowerInvariant()
$validFoundationSuites = @(
    "",
    "smoke",
    "contracts",
    "contract",
    "games",
    "systems",
    "ui",
    "slot",
    "slots",
    "slot_acceptance",
    "blackjack",
    "roulette",
    "baccarat",
    "video_poker",
    "bar_dice",
    "pull_tabs",
    "audit",
    "all",
    "full"
)
if ($validFoundationSuites -notcontains $foundationSuiteKey) {
    throw "Unknown FoundationSuite '$FoundationSuite'."
}
if ($foundationSuiteKey -eq "contract") {
    $foundationSuiteKey = "contracts"
}
elseif ($foundationSuiteKey -eq "full") {
    $foundationSuiteKey = "all"
}

function Get-ProjectRelativePath {
    param([string]$Path)
    $rootPath = [System.IO.Path]::GetFullPath($root)
    if (-not $rootPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootPath += [System.IO.Path]::DirectorySeparatorChar
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootUri = [System.Uri]$rootPath
    $pathUri = [System.Uri]$fullPath
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()) -replace "\\", "/"
}

function Use-ConsoleGodot {
    param([string]$Path)
    if (-not $Path) {
        return $null
    }
    if ($Path.EndsWith("_console.exe")) {
        return $Path
    }
    $candidate = $Path -replace "\.exe$", "_console.exe"
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }
    return $Path
}

function Find-Godot {
    if ($env:GODOT_BIN) {
        return Use-ConsoleGodot $env:GODOT_BIN
    }
    $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $localGodot) {
        $localGodot = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($localGodot) {
        return Use-ConsoleGodot $localGodot.FullName
    }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        return Use-ConsoleGodot $command.Source
    }
    return $null
}

function Get-GodotProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like "*Godot*" })
}

function Stop-NewGodotProcesses {
    param([int[]]$ExistingPids)
    foreach ($process in Get-GodotProcesses) {
        if ($ExistingPids -notcontains $process.Id) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Join-ProcessArguments {
    param([string[]]$Arguments)
    $quoted = @()
    foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            $quoted += '"' + ($argument -replace '"', '\"') + '"'
        }
        else {
            $quoted += $argument
        }
    }
    return ($quoted -join " ")
}

function Get-StageTimeout {
    param([string]$Name)
    if ($TimeoutSec -gt 0) {
        return $TimeoutSec
    }
    if ($Name -eq "foundation_slot_acceptance") {
        return 900
    }
    if ($Name -eq "foundation_slot") {
        return 300
    }
    switch ($suiteKey) {
        "smoke" {
            if ($Name -eq "ui_scene_compile") { return 180 }
            return 120
        }
        "contract" { return 300 }
        "audit" { return 900 }
        "full" { return 1800 }
        default { return 180 }
    }
}

function Convert-ReportResourcePath {
    param([string]$FileName)
    $fullPath = Join-Path $script:ReportRoot $FileName
    return "res://" + (Get-ProjectRelativePath $fullPath)
}

if ([string]::IsNullOrWhiteSpace($ReportDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ReportDir = Join-Path $root (".tmp\test_reports\{0}_{1}" -f $stamp, $suiteKey)
}
elseif (-not [System.IO.Path]::IsPathRooted($ReportDir)) {
    $ReportDir = Join-Path $root $ReportDir
}
$script:ReportRoot = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Force -Path $script:ReportRoot | Out-Null

$script:StageResults = New-Object System.Collections.Generic.List[object]

function Invoke-ProcessStage {
    param(
        [string]$Name,
        [string]$FilePath,
        [string[]]$Arguments,
        [int]$StageTimeoutSec = 0
    )
    $timeout = if ($StageTimeoutSec -gt 0) { $StageTimeoutSec } else { Get-StageTimeout $Name }
    $safeName = ($Name -replace "[^A-Za-z0-9_.-]", "_")
    $stdout = Join-Path $script:ReportRoot ($safeName + ".stdout.txt")
    $stderr = Join-Path $script:ReportRoot ($safeName + ".stderr.txt")
    $beforePids = @(Get-GodotProcesses | ForEach-Object { $_.Id })
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    $exitCode = 1
    $errorText = ""
    if ($VerboseStages) {
        Write-Host "STAGE START $Name"
    }
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $FilePath
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        if ($null -ne $startInfo.ArgumentList) {
            foreach ($argument in $Arguments) {
                [void]$startInfo.ArgumentList.Add($argument)
            }
        }
        else {
            $startInfo.Arguments = Join-ProcessArguments -Arguments $Arguments
        }
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($timeout * 1000)) {
            $timedOut = $true
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            Stop-NewGodotProcesses -ExistingPids $beforePids
            $process.WaitForExit()
            $exitCode = 124
        }
        else {
            $process.Refresh()
            $exitCode = if ($null -eq $process.ExitCode) { 0 } else { [int]$process.ExitCode }
        }
        $stdoutTask.Wait(5000) | Out-Null
        $stderrTask.Wait(5000) | Out-Null
        [System.IO.File]::WriteAllText($stdout, $stdoutTask.Result)
        [System.IO.File]::WriteAllText($stderr, $stderrTask.Result)
    }
    catch {
        $errorText = $_.Exception.Message
        $exitCode = 1
    }
    $sw.Stop()
    $result = [ordered]@{
        name = $Name
        command = $FilePath
        arguments = $Arguments
        exit_code = $exitCode
        timed_out = $timedOut
        duration_msec = [int]$sw.ElapsedMilliseconds
        stdout = $stdout
        stderr = $stderr
        error = $errorText
    }
    $script:StageResults.Add([pscustomobject]$result)
    $status = if ($exitCode -eq 0) { "PASS" } elseif ($timedOut) { "TIMEOUT" } else { "FAIL" }
    Write-Host ("{0,-28} {1,7} {2,8}ms" -f $Name, $status, [int]$sw.ElapsedMilliseconds)
    if ($exitCode -ne 0 -and -not $KeepGoing) {
        Write-TestSummary
        exit $exitCode
    }
    return $exitCode -eq 0
}

function Write-TestSummary {
    $failed = @($script:StageResults | Where-Object { $_.exit_code -ne 0 })
    $stages = @()
    foreach ($stage in $script:StageResults) {
        $stages += [ordered]@{
            name = $stage.name
            command = $stage.command
            arguments = @($stage.arguments)
            exit_code = $stage.exit_code
            timed_out = $stage.timed_out
            duration_msec = $stage.duration_msec
            stdout = $stage.stdout
            stderr = $stage.stderr
            error = $stage.error
        }
    }
    $summary = @{
        tool = "check_godot"
        suite = $Suite
        passed = ($failed.Count -eq 0)
        failure_count = $failed.Count
        report_dir = $script:ReportRoot
        stages = $stages
    }
    $summaryPath = Join-Path $script:ReportRoot "summary.json"
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath
    Write-Host "Report: $summaryPath"
}

function Invoke-GodotScript {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$UserArgs = @(),
        [int]$StageTimeoutSec = 0
    )
    $args = @("--headless", "--path", $root, "--script", $ScriptPath)
    if ($UserArgs.Count -gt 0) {
        $args += "--"
        $args += $UserArgs
    }
    Invoke-ProcessStage -Name $Name -FilePath $script:Godot -Arguments $args -StageTimeoutSec $StageTimeoutSec | Out-Null
}

function Invoke-GodotImport {
    Invoke-ProcessStage -Name "godot_import" -FilePath $script:Godot -Arguments @("--headless", "--path", $root, "--import") -StageTimeoutSec 180 | Out-Null
}

function Invoke-GDScriptLoadCheck {
    $report = Convert-ReportResourcePath "gdscript_load_check.json"
    Invoke-GodotScript -Name "gdscript_load_check" -ScriptPath "res://tools/gdscript_load_check.gd" -UserArgs @("--roots=res://scripts,res://tools", "--report=$report") -StageTimeoutSec 180
}

function Invoke-FoundationSuite {
    param([string]$FoundationSuite, [int]$StageTimeoutSec = 0)
    $report = Convert-ReportResourcePath ("foundation_{0}.json" -f $FoundationSuite)
    Invoke-GodotScript -Name ("foundation_{0}" -f $FoundationSuite) -ScriptPath "res://scripts/tests/foundation_check.gd" -UserArgs @("--suite=$FoundationSuite", "--report=$report") -StageTimeoutSec $StageTimeoutSec
}

function Invoke-ExhaustiveParse {
    $scripts = @(Get-ChildItem -LiteralPath (Join-Path $root "scripts") -Filter "*.gd" -Recurse -File) + @(Get-ChildItem -LiteralPath (Join-Path $root "tools") -Filter "*.gd" -Recurse -File)
    foreach ($script in $scripts) {
        $resourcePath = "res://" + (Get-ProjectRelativePath $script.FullName)
        $stageName = "parse_" + (($resourcePath -replace "^res://", "") -replace "[\\/]", "_")
        Invoke-ProcessStage -Name $stageName -FilePath $script:Godot -Arguments @("--headless", "--path", $root, "--check-only", "--script", $resourcePath) -StageTimeoutSec 90 | Out-Null
    }
}

$powerShellExe = (Get-Command powershell -ErrorAction Stop).Source
Invoke-ProcessStage -Name "validate_project" -FilePath $powerShellExe -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "validate_project.ps1"), "-Quiet") -StageTimeoutSec 120 | Out-Null

$script:Godot = Find-Godot
if (-not $script:Godot) {
    if ($RequireGodot) {
        throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
    }
    Write-Warning "Godot was not found, so engine-level checks were skipped."
    Write-TestSummary
    exit 0
}

if (-not $NoImport) {
    Invoke-GodotImport
}

Invoke-GDScriptLoadCheck

if ($ExhaustiveParse -or $suiteKey -eq "full") {
    Invoke-ExhaustiveParse
}

if (-not [string]::IsNullOrWhiteSpace($foundationSuiteKey)) {
    if ($foundationSuiteKey -eq "ui") {
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath "res://scripts/tests/ui_scene_compile_check.gd" -StageTimeoutSec (Get-StageTimeout "ui_scene_compile")
    }
    else {
        Invoke-FoundationSuite -FoundationSuite $foundationSuiteKey -StageTimeoutSec (Get-StageTimeout ("foundation_{0}" -f $foundationSuiteKey))
    }
    Write-TestSummary
    $failedStages = @($script:StageResults | Where-Object { $_.exit_code -ne 0 })
    if ($failedStages.Count -gt 0) {
        exit 1
    }
    exit 0
}

switch ($suiteKey) {
    "smoke" {
        Invoke-FoundationSuite -FoundationSuite "smoke" -StageTimeoutSec 180
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath "res://scripts/tests/ui_scene_compile_check.gd" -StageTimeoutSec 240
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
    }
    "contract" {
        Invoke-FoundationSuite -FoundationSuite "contracts" -StageTimeoutSec 360
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath "res://scripts/tests/ui_scene_compile_check.gd" -StageTimeoutSec 240
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
    }
    "audit" {
        Invoke-GodotScript -Name "slot_machine_deep_audit" -ScriptPath "res://tools/slot_machine_deep_audit.gd" -UserArgs @("10000") -StageTimeoutSec 900
        Invoke-GodotScript -Name "roulette_rule_audit" -ScriptPath "res://tools/roulette_rule_audit.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
    }
    "full" {
        Invoke-FoundationSuite -FoundationSuite "all" -StageTimeoutSec (Get-StageTimeout "foundation_all")
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath "res://scripts/tests/ui_scene_compile_check.gd" -StageTimeoutSec 300
        Invoke-GodotScript -Name "slot_machine_deep_audit" -ScriptPath "res://tools/slot_machine_deep_audit.gd" -UserArgs @("10000") -StageTimeoutSec 900
        Invoke-GodotScript -Name "roulette_rule_audit" -ScriptPath "res://tools/roulette_rule_audit.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
    }
}

Write-TestSummary
$failedStages = @($script:StageResults | Where-Object { $_.exit_code -ne 0 })
if ($failedStages.Count -gt 0) {
    exit 1
}
Write-Host "Beat the House Godot checks passed. Suite=$Suite"
