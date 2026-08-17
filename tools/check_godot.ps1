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
    [string]$FoundationSuite = "",
    [switch]$AllowConcurrentGodot
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
    "craps",
    "video_poker",
    "bar_dice",
    "crew_poker",
    "pull_tabs",
    "scratch_tickets",
    "coin_pusher",
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

function Get-ProjectGodotProcessDetails {
    $trimChars = [char[]]@([char]'\', [char]'/')
    $rootPath = [System.IO.Path]::GetFullPath($root).TrimEnd($trimChars)
    $toolsPath = [System.IO.Path]::GetFullPath((Join-Path $root ".tools")).TrimEnd($trimChars)
    $rootNeedle = $rootPath.Replace("/", "\").ToLowerInvariant()
    $toolsNeedle = $toolsPath.Replace("/", "\").ToLowerInvariant()
    $details = @()
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Godot*" })) {
        $commandLine = [string]$process.CommandLine
        if ([string]::IsNullOrWhiteSpace($commandLine)) {
            continue
        }
        $normalizedCommand = $commandLine.Replace("/", "\").ToLowerInvariant()
        $usesProjectPath = $normalizedCommand.Contains($rootNeedle)
        $usesProjectGodot = $normalizedCommand.Contains($toolsNeedle)
        $usesRelativePath = $normalizedCommand -match '(^|\s)--path\s+\.($|\s)'
        if ($usesProjectPath -or ($usesProjectGodot -and $usesRelativePath)) {
            $details += [pscustomobject]@{
                Id = [int]$process.ProcessId
                Name = [string]$process.Name
                CommandLine = $commandLine
            }
        }
    }
    return $details
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
    $baseline = Get-FoundationSuiteStageBaselineSec $Name
    if ($baseline -gt 0.0) {
        return [Math]::Max(300, [int][Math]::Ceiling($baseline * 1.5))
    }
    if ($Name.StartsWith("foundation_")) {
        return 300
    }
    if ($Name -eq "foundation_contracts" -and $foundationSuiteKey -eq "contracts") {
        return 300
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

function Convert-ProjectResourcePath {
    param([string]$Path)
    return "res://" + (Get-ProjectRelativePath $Path)
}

function New-SplitTestRunner {
    param(
        [string]$Name,
        [string[]]$SourceRelativePaths
    )
    $generatedRoot = Join-Path $root ".tmp\generated_tests"
    New-Item -ItemType Directory -Force -Path $generatedRoot | Out-Null
    $destination = Join-Path $generatedRoot $Name
    $lines = New-Object System.Collections.Generic.List[string]
    $sourceIndex = 0
    foreach ($relativePath in $SourceRelativePaths) {
        $source = Join-Path $root $relativePath
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Split test source not found: $relativePath"
        }
        if ($sourceIndex -gt 0) {
            $lines.Add("")
            $lines.Add("# --- split source: $relativePath ---")
        }
        $fileLines = [System.IO.File]::ReadAllLines($source)
        $lineIndex = 0
        foreach ($line in $fileLines) {
            if ($sourceIndex -gt 0 -and $lineIndex -eq 0 -and ($line -match '^extends\s+' -or $line -match '^class_name\s+')) {
                $lineIndex += 1
                continue
            }
            $lines.Add($line)
            $lineIndex += 1
        }
        $sourceIndex += 1
    }
    [System.IO.File]::WriteAllLines($destination, $lines)
    return Convert-ProjectResourcePath $destination
}

function Get-FoundationSplitRunnerPath {
    return New-SplitTestRunner -Name "foundation_check_split_runner.gd" -SourceRelativePaths @(
        "scripts/tests/foundation/check_core_content.gd",
        "scripts/tests/foundation/check_slots_surfaces.gd",
        "scripts/tests/foundation/check_table_games.gd",
        "scripts/tests/foundation/check_items_events_world.gd",
        "scripts/tests/foundation/check_delivery_runs.gd",
        "scripts/tests/foundation/check_lenders_release_saves.gd",
        "scripts/tests/foundation/check_scratch_tickets.gd",
        "scripts/tests/foundation/check_cage_environment_rework.gd",
        "scripts/tests/foundation/check_coin_pusher.gd"
    )
}

function Get-UiSceneSplitRunnerPath {
    return Convert-ProjectResourcePath (Join-Path $root "scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd")
}

function Get-ReportKeepCount {
    $keep = 30
    if (-not [string]::IsNullOrWhiteSpace($env:BTH_REPORT_KEEP)) {
        $parsed = 0
        if ([int]::TryParse($env:BTH_REPORT_KEEP, [ref]$parsed)) {
            $keep = $parsed
        }
    }
    return [Math]::Max(1, $keep)
}

function Test-PathInsideDirectory {
    param([string]$Path, [string]$Directory)
    $directoryFull = [System.IO.Path]::GetFullPath($Directory)
    if (-not $directoryFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $directoryFull += [System.IO.Path]::DirectorySeparatorChar
    }
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    return $pathFull.StartsWith($directoryFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-ReportRotation {
    if ([string]::IsNullOrWhiteSpace($script:ReportRotationRoot)) {
        return
    }
    if ($script:ReportRotationRan) {
        return
    }
    $script:ReportRotationRan = $true
    if (-not (Test-Path -LiteralPath $script:ReportRotationRoot)) {
        return
    }
    $rotationRoot = [System.IO.Path]::GetFullPath($script:ReportRotationRoot)
    $expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $root ".tmp\test_reports"))
    if ($rotationRoot -ne $expectedRoot) {
        throw "Refusing to rotate unexpected report root: $rotationRoot"
    }
    $currentPath = [System.IO.Path]::GetFullPath($script:ReportRoot)
    $keep = Get-ReportKeepCount
    $directories = @(Get-ChildItem -LiteralPath $rotationRoot -Directory | Sort-Object LastWriteTimeUtc -Descending)
    $keptSlots = [Math]::Max(0, $keep - 1)
    $oldDirectories = @($directories | Where-Object {
        [System.IO.Path]::GetFullPath($_.FullName) -ne $currentPath
    } | Select-Object -Skip $keptSlots)
    $removed = 0
    foreach ($directory in $oldDirectories) {
        $fullPath = [System.IO.Path]::GetFullPath($directory.FullName)
        if (-not (Test-PathInsideDirectory -Path $fullPath -Directory $rotationRoot)) {
            throw "Refusing to remove report directory outside rotation root: $fullPath"
        }
        if ($fullPath -eq $currentPath) {
            continue
        }
        Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop
        $removed += 1
    }
    if ($removed -gt 0) {
        Write-Host ("Report rotation: removed {0} old .tmp/test_reports directories, kept {1} newest." -f $removed, $keep)
    }
}

if ([string]::IsNullOrWhiteSpace($ReportDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:ReportRotationRoot = Join-Path $root ".tmp\test_reports"
    $script:ReportRotationRan = $false
    $ReportDir = Join-Path $script:ReportRotationRoot ("{0}_{1}" -f $stamp, $suiteKey)
}
elseif (-not [System.IO.Path]::IsPathRooted($ReportDir)) {
    $ReportDir = Join-Path $root $ReportDir
}
$script:ReportRoot = [System.IO.Path]::GetFullPath($ReportDir)
New-Item -ItemType Directory -Force -Path $script:ReportRoot | Out-Null

$script:StageResults = New-Object System.Collections.Generic.List[object]
$FoundationSuiteBudgetMultiplier = 1.5
$FoundationSuiteStageBaselinesSec = @{
    "foundation_all" = 153.768
    "foundation_systems" = 29.141
    # Expanded GC05.2 coverage and same-host Stage 1 control: .tmp/gc05_2_ui_baseline_evidence.md
    "ui_scene_compile" = 83.234
    "foundation_contracts" = 153.594
    "foundation_games" = 146.950
    "foundation_slot" = 25.535
    "foundation_slot_acceptance" = 638.945
    "foundation_audit" = 646.713
    "foundation_blackjack" = 11.860
    "foundation_roulette" = 11.031
    "foundation_baccarat" = 11.209
    "foundation_video_poker" = 85.802
    "foundation_bar_dice" = 60.646
    "foundation_pull_tabs" = 13.253
    "foundation_scratch_tickets" = 12.683
}

function Get-FoundationSuiteStageBaselineSec {
    param([string]$Name)
    if ($FoundationSuiteStageBaselinesSec.ContainsKey($Name)) {
        return [double]$FoundationSuiteStageBaselinesSec[$Name]
    }
    return 0.0
}

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
    $stderrIssues = @()
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
        $stderrIssues = @($stderrTask.Result -split "`r?`n" | Where-Object {
            $_ -match '^\s*(SCRIPT ERROR|ERROR|WARNING):'
        })
        if ($exitCode -eq 0 -and $stderrIssues.Count -gt 0) {
            $exitCode = 127
            $errorText = "Godot reported $($stderrIssues.Count) error/warning line(s) on stderr despite returning exit code 0."
        }
    }
    catch {
        $errorText = $_.Exception.Message
        $exitCode = 1
    }
    $sw.Stop()
    $durationSec = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
    $suiteTimeBaselineSec = Get-FoundationSuiteStageBaselineSec $Name
    $suiteTimeBudgetSec = if ($suiteTimeBaselineSec -gt 0.0) { [Math]::Round($suiteTimeBaselineSec * $FoundationSuiteBudgetMultiplier, 3) } else { 0.0 }
    $suiteTimeBudgetExceeded = $false
    if ($suiteTimeBudgetSec -gt 0.0 -and $sw.Elapsed.TotalSeconds -gt $suiteTimeBudgetSec) {
        $suiteTimeBudgetExceeded = $true
        $budgetError = ("Stage {0} took {1:N3}s, exceeding the S0.1 suite-time budget {2:N3}s (baseline {3:N3}s * {4:N2})." -f $Name, $sw.Elapsed.TotalSeconds, $suiteTimeBudgetSec, $suiteTimeBaselineSec, $FoundationSuiteBudgetMultiplier)
        if ([string]::IsNullOrWhiteSpace($errorText)) {
            $errorText = $budgetError
        }
        else {
            $errorText = "$errorText $budgetError"
        }
        if ($exitCode -eq 0) {
            $exitCode = 126
        }
    }
    $result = [ordered]@{
        name = $Name
        command = $FilePath
        arguments = $Arguments
        exit_code = $exitCode
        timed_out = $timedOut
        duration_msec = [int]$sw.ElapsedMilliseconds
        duration_sec = $durationSec
        suite_time_baseline_sec = $suiteTimeBaselineSec
        suite_time_budget_sec = $suiteTimeBudgetSec
        suite_time_budget_exceeded = $suiteTimeBudgetExceeded
        stderr_issue_count = $stderrIssues.Count
        stderr_issues = $stderrIssues
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
            duration_sec = $stage.duration_sec
            suite_time_baseline_sec = $stage.suite_time_baseline_sec
            suite_time_budget_sec = $stage.suite_time_budget_sec
            suite_time_budget_exceeded = $stage.suite_time_budget_exceeded
            stderr_issue_count = $stage.stderr_issue_count
            stderr_issues = @($stage.stderr_issues)
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
        suite_time_budget_multiplier = $FoundationSuiteBudgetMultiplier
        suite_time_stage_baselines_sec = $FoundationSuiteStageBaselinesSec
        stages = $stages
    }
    $summaryPath = Join-Path $script:ReportRoot "summary.json"
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath
    Write-Host "Report: $summaryPath"
    Invoke-ReportRotation
}

function Assert-NoConcurrentProjectGodot {
    if ($AllowConcurrentGodot) {
        return
    }
    $running = @(Get-ProjectGodotProcessDetails)
    if ($running.Count -eq 0) {
        return
    }
    $processLines = @()
    foreach ($process in $running) {
        $processLines += ("PID {0} {1}: {2}" -f $process.Id, $process.Name, $process.CommandLine)
    }
    $message = "Another Godot process is already running for this workspace. Stop it before running check_godot, or rerun with -AllowConcurrentGodot only when intentional. Overlapping headless Godot jobs can leave orphaned children, corrupt user:// logs, and reproduce native access-violation dialogs after aborted long gates. " + ($processLines -join " | ")
    $script:StageResults.Add([pscustomobject][ordered]@{
        name = "concurrent_godot_guard"
        command = "Get-CimInstance Win32_Process"
        arguments = @()
        exit_code = 125
        timed_out = $false
        duration_msec = 0
        stdout = ""
        stderr = ""
        error = $message
    })
    Write-Host ("{0,-28} {1,7} {2,8}ms" -f "concurrent_godot_guard", "FAIL", 0)
    Write-Warning $message
    Write-TestSummary
    exit 125
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
    Invoke-GodotScript -Name "gdscript_load_check" -ScriptPath "res://tools/gdscript_load_check.gd" -UserArgs @("--roots=res://scripts,res://tools", "--exclude=res://scripts/tests/foundation,res://scripts/tests/ui_scene", "--report=$report") -StageTimeoutSec 180
}

function Invoke-FoundationSuite {
    param([string]$FoundationSuite, [int]$StageTimeoutSec = 0)
    $report = Convert-ReportResourcePath ("foundation_{0}.json" -f $FoundationSuite)
    Invoke-GodotScript -Name ("foundation_{0}" -f $FoundationSuite) -ScriptPath (Get-FoundationSplitRunnerPath) -UserArgs @("--suite=$FoundationSuite", "--report=$report") -StageTimeoutSec $StageTimeoutSec
}

function Invoke-FoundationPerfSmoke {
    $oldRuns = $env:BTH_PERF_RUNS
    $oldFrames = $env:BTH_PERF_FRAMES
    $oldResolveSamples = $env:BTH_PERF_RESOLVE_SAMPLES
    $oldSeedPrefix = $env:BTH_PERF_SEED_PREFIX
    try {
        $env:BTH_PERF_RUNS = "0"
        # Animated surfaces redraw below the engine frame rate. Forty frames
        # yielded only ~17 draw samples, so a single scheduler spike became the
        # computed p95. Use the probe's authored 120-frame baseline; budgets are
        # unchanged, but the percentile now represents a real distribution.
        $env:BTH_PERF_FRAMES = "120"
        $env:BTH_PERF_RESOLVE_SAMPLES = "24"
        $env:BTH_PERF_SEED_PREFIX = "CHECK-GODOT-PERF"
        Invoke-GodotScript -Name "foundation_perf_smoke" -ScriptPath "res://tools/foundation_performance_probe.gd" -StageTimeoutSec 90
    }
    finally {
        $env:BTH_PERF_RUNS = $oldRuns
        $env:BTH_PERF_FRAMES = $oldFrames
        $env:BTH_PERF_RESOLVE_SAMPLES = $oldResolveSamples
        $env:BTH_PERF_SEED_PREFIX = $oldSeedPrefix
    }
}

function Invoke-ExhaustiveParse {
    $scripts = @(Get-ChildItem -LiteralPath (Join-Path $root "scripts") -Filter "*.gd" -Recurse -File) + @(Get-ChildItem -LiteralPath (Join-Path $root "tools") -Filter "*.gd" -Recurse -File)
    foreach ($script in $scripts) {
        $resourcePath = "res://" + (Get-ProjectRelativePath $script.FullName)
        # These files are compositional fragments whose base class and helpers
        # are supplied by the generated split runners. Parsing the fragments as
        # standalone SceneTrees is invalid; the runner stages below compile and
        # execute their assembled source instead.
        if ($resourcePath.StartsWith("res://scripts/tests/foundation/") -or $resourcePath.StartsWith("res://scripts/tests/ui_scene/")) {
            continue
        }
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

Assert-NoConcurrentProjectGodot

if (-not $NoImport) {
    Invoke-GodotImport
}

Invoke-GDScriptLoadCheck

if ($ExhaustiveParse -or $suiteKey -eq "full") {
    Invoke-ExhaustiveParse
}

if (-not [string]::IsNullOrWhiteSpace($foundationSuiteKey)) {
    if ($foundationSuiteKey -eq "ui") {
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath (Get-UiSceneSplitRunnerPath) -StageTimeoutSec (Get-StageTimeout "ui_scene_compile")
        Invoke-GodotScript -Name "dave_bus_encounter" -ScriptPath "res://scripts/tests/ui_scene/check_dave_bus_encounter.gd" -StageTimeoutSec 120
        Invoke-GodotScript -Name "inventory_spatial_ui" -ScriptPath "res://scripts/tests/inventory_spatial_ui_check.gd" -StageTimeoutSec 120
        Invoke-GodotScript -Name "inventory_spatial_main_integration" -ScriptPath "res://scripts/tests/inventory_spatial_main_integration_check.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "ui05_design_system" -ScriptPath "res://scripts/tests/ui05_design_system_check.gd" -StageTimeoutSec 120
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
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath (Get-UiSceneSplitRunnerPath) -StageTimeoutSec 240
        Invoke-GodotScript -Name "dave_bus_encounter" -ScriptPath "res://scripts/tests/ui_scene/check_dave_bus_encounter.gd" -StageTimeoutSec 120
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
        Invoke-FoundationPerfSmoke
    }
    "contract" {
        Invoke-FoundationSuite -FoundationSuite "contracts" -StageTimeoutSec 360
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath (Get-UiSceneSplitRunnerPath) -StageTimeoutSec 240
        Invoke-GodotScript -Name "tutorial_guardrail_stress" -ScriptPath "res://scripts/tests/tutorial_guardrail_recovery_stress_check.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "tutorial_guided_run_audit" -ScriptPath "res://tools/tutorial_seed_audit.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
    }
    "audit" {
        Invoke-GodotScript -Name "slot_pinball_physics_audit" -ScriptPath "res://tools/slot_pinball_physics_audit.gd" -UserArgs @("48") -StageTimeoutSec 240
        Invoke-GodotScript -Name "slot_machine_deep_audit" -ScriptPath "res://tools/slot_machine_deep_audit.gd" -UserArgs @("10000") -StageTimeoutSec 900
        Invoke-GodotScript -Name "roulette_rule_audit" -ScriptPath "res://tools/roulette_rule_audit.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "roulette_audio_audit" -ScriptPath "res://tools/roulette_audio_audit.gd" -StageTimeoutSec 120
    }
    "full" {
        Invoke-FoundationSuite -FoundationSuite "all" -StageTimeoutSec (Get-StageTimeout "foundation_all")
        Invoke-GodotScript -Name "ui_scene_compile" -ScriptPath (Get-UiSceneSplitRunnerPath) -StageTimeoutSec 300
        Invoke-GodotScript -Name "dave_bus_encounter" -ScriptPath "res://scripts/tests/ui_scene/check_dave_bus_encounter.gd" -StageTimeoutSec 120
        Invoke-GodotScript -Name "tutorial_guardrail_stress" -ScriptPath "res://scripts/tests/tutorial_guardrail_recovery_stress_check.gd" -StageTimeoutSec 180
        Invoke-GodotScript -Name "tutorial_guided_run_audit" -ScriptPath "res://tools/tutorial_seed_audit.gd" -StageTimeoutSec 180
        Invoke-FoundationPerfSmoke
        Invoke-GodotScript -Name "slot_pinball_physics_audit" -ScriptPath "res://tools/slot_pinball_physics_audit.gd" -UserArgs @("48") -StageTimeoutSec 240
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
