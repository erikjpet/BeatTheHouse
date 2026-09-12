$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot "craps_rtp_audit.gd") -Raw
foreach ($required in @(
    "const MINIMUM_ROLLS_PER_BET := 1000000",
    '_audit_variant_bets(rolls_per_bet, run_state, rows)',
    'Player-reachable %s bet %s has no house-edge documentation.',
    'Player-reachable %s bet %s has no measured RTP implementation.',
    'CrapsRulesScript._settle_proposition_bets',
    'CrapsRulesScript.buy_profit',
    'CrapsRulesScript.lay_profit'
)) {
    if (-not $source.Contains($required)) { throw "Craps RTP audit is missing required fail-closed seam: $required" }
}

$godot = [string]$env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($godot)) {
    $common = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    $godot = Join-Path (Split-Path -Parent $common) ".tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot 4.6 stable is required for the Craps RTP hostile fixture." }

$stamp = [Guid]::NewGuid().ToString("N")
$out = Join-Path $root ".tmp\craps_rtp_contract_$stamp"
New-Item -ItemType Directory -Path $out | Out-Null
$fixture = Join-Path $out "wrong_hard_4_payout.json"
$report = Join-Path $out "report.json"
$games = Get-Content -LiteralPath (Join-Path $root "data\games\games.json") -Raw | ConvertFrom-Json
$craps = @($games | Where-Object { [string]$_.id -ceq "craps" })
if ($craps.Count -ne 1) { throw "Expected exactly one Craps definition." }
$craps[0].craps_config.rules.hardway_payouts.'4'.numerator = 70
$craps[0] | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $fixture -Encoding utf8

$oldFixture = $env:BTH_CRAPS_RTP_FIXTURE_PATH
$oldRolls = $env:BTH_CRAPS_RTP_FIXTURE_ROLLS
$oldReport = $env:BTH_CRAPS_RTP_REPORT_PATH
try {
    $env:BTH_CRAPS_RTP_FIXTURE_PATH = $fixture
    $env:BTH_CRAPS_RTP_FIXTURE_ROLLS = "10000"
    $env:BTH_CRAPS_RTP_REPORT_PATH = $report
    & $godot --headless --path $root --script res://tools/craps_rtp_audit.gd *> (Join-Path $out "stdout.txt")
    $exitCode = $LASTEXITCODE
}
finally {
    $env:BTH_CRAPS_RTP_FIXTURE_PATH = $oldFixture
    $env:BTH_CRAPS_RTP_FIXTURE_ROLLS = $oldRolls
    $env:BTH_CRAPS_RTP_REPORT_PATH = $oldReport
}
if ($exitCode -eq 0) { throw "Craps RTP audit accepted a seeded 70:1 Hard 4 payout against 7:1 documentation." }
if (-not (Test-Path -LiteralPath $report -PathType Leaf)) { throw "Craps RTP hostile fixture emitted no report." }
$result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$hardFour = @($result.rows | Where-Object { [string]$_.bet_id -ceq "hard_4" })
if ($hardFour.Count -ne 1 -or [bool]$hardFour[0].passed) { throw "Craps RTP hostile fixture did not reject Hard 4 specifically." }
if (@($result.rows).Count -ne 40) { throw "Craps RTP hostile fixture did not measure all 40 reachable wager types." }
Write-Host "CRAPS RTP AUDIT CONTRACT PASS broken=hard_4 rows=40 report=$report"
