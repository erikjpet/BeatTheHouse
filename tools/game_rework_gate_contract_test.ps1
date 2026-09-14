param(
    [string]$GodotBin = $env:GODOT_BIN
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    $candidate = Join-Path $root ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
    if (Test-Path -LiteralPath $candidate) {
        $GodotBin = $candidate
    }
}
if ([string]::IsNullOrWhiteSpace($GodotBin) -or -not (Test-Path -LiteralPath $GodotBin)) {
    throw "Godot was not found. Set GODOT_BIN before running the game-rework gate contract."
}

$fixtureId = [Guid]::NewGuid().ToString("N")
$fixtureRoot = Join-Path $root (".tmp\fix06_32_gate_contract_{0}" -f $fixtureId)
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
$cases = @(
    @{
        Name = "craps_extensive_playtest"
        Source = "tools\craps_extensive_playtest.gd"
        Find = "var definition := _craps_definition()"
        Replace = "var definition: Dictionary = {}"
    },
    @{
        Name = "crew_holdem_gameplay_audit"
        Source = "tools\crew_holdem_gameplay_audit.gd"
        Find = "var seed_audit := CrewPokerVisualSeedAuditScript.audit_pinned_seed(library)"
        Replace = 'var seed_audit := {"passed": false}'
    },
    @{
        Name = "crew_holdem_dynamic_table_audit"
        Source = "tools\crew_holdem_dynamic_table_audit.gd"
        Find = 'app.call("start_game_test_session", "crew_draw_poker")'
        Replace = 'app.call("start_game_test_session", "broken_holdem_fixture")'
    },
    @{
        Name = "crew_holdem_production_host_audit"
        Source = "tools\crew_holdem_production_host_audit.gd"
        Find = 'const GAME_ID := "crew_draw_poker"'
        Replace = 'const GAME_ID := "broken_holdem_fixture"'
    },
    @{
        Name = "slot_autoplay_cadence_probe"
        Source = "tools\slot_autoplay_cadence_probe.gd"
        Find = 'machine["slot_autoplay_active"] = true'
        Replace = 'machine["slot_autoplay_active"] = false'
    },
    @{
        Name = "slot_foreground_autoplay_performance_probe"
        Source = "tools\slot_foreground_autoplay_performance_probe.gd"
        Find = 'machine["slot_autoplay_active"] = true'
        Replace = 'machine["slot_autoplay_active"] = false'
    },
    @{
        Name = "blackjack_counter_surveillance_probe"
        Source = "tools\blackjack_counter_surveillance_probe.gd"
        Find = "var bets := [5, 5, 5, 5, 10, 20, 30, 40]"
        Replace = "var bets := [5, 5, 5, 5, 5, 5, 5, 5]"
    }
)

$results = @()
foreach ($case in $cases) {
    $sourcePath = Join-Path $root $case.Source
    $source = [System.IO.File]::ReadAllText($sourcePath)
    $occurrences = ([regex]::Matches($source, [regex]::Escape($case.Find))).Count
    if ($occurrences -ne 1) {
        throw "Hostile fixture anchor for $($case.Name) occurred $occurrences times; expected exactly one."
    }
    $fixturePath = Join-Path $fixtureRoot ("{0}.gd" -f $case.Name)
    [System.IO.File]::WriteAllText($fixturePath, $source.Replace($case.Find, $case.Replace), [System.Text.UTF8Encoding]::new($false))
    $resourcePath = "res://.tmp/{0}/{1}.gd" -f (Split-Path -Leaf $fixtureRoot), $case.Name
    $stdoutPath = Join-Path $fixtureRoot ("{0}.stdout.txt" -f $case.Name)
    $stderrPath = Join-Path $fixtureRoot ("{0}.stderr.txt" -f $case.Name)
    $process = Start-Process -FilePath $GodotBin -ArgumentList @("--headless", "--path", $root, "--script", $resourcePath) -NoNewWindow -PassThru -Wait -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if ($process.ExitCode -eq 0) {
        throw "$($case.Name) stayed green with its deliberately broken fixture. Evidence: $fixtureRoot"
    }
    $results += [pscustomobject][ordered]@{
        gate = $case.Name
        broken_fixture_exit_code = $process.ExitCode
        passed = $true
    }
}

$reportPath = Join-Path $fixtureRoot "report.json"
[System.IO.File]::WriteAllText($reportPath, ($results | ConvertTo-Json -Depth 4), [System.Text.UTF8Encoding]::new($false))
Write-Host "GAME REWORK GATE CONTRACT PASS gates=$($results.Count) evidence=$fixtureRoot"
