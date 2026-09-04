param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$GodotPath = "",
    [string]$OutputDirectory = "",
    [ValidateRange(30, 600)]
    [int]$CaptureTimeoutSeconds = 180,
    [switch]$KeepHistoricalArchive
)

$ErrorActionPreference = "Stop"
$generator = Join-Path $PSScriptRoot "integ06_1_generate_v051_fixtures.ps1"
$resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $resolvedRoot "scripts/tests/fixtures/integ06_1/mid_0_6"
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
$temporaryPlanRoot = Join-Path ([IO.Path]::GetTempPath()) ("bth-integ06-1-mid06-plans-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $temporaryPlanRoot, $resolvedOutput | Out-Null

$captures = @(
    [ordered]@{
        milestone = "pre_game_depth"
        commit = "31e434c412ba8bdeda03bee86db1f8b4d899c962"
        fixture_id = "mid06_pre_game_depth_slot"
        seed = "INTEG06-1-MID06-PRE-GAME-001"
        case = [ordered]@{
            fixture_id = "mid06_pre_game_depth_slot"
            seed = "INTEG06-1-MID06-PRE-GAME-001"
            travel_path = @("gas_station_casino")
            expected_archetype = "gas_station_casino"
            enter_game = "slot"
        }
    }
    [ordered]@{
        milestone = "pre_environment_depth"
        commit = "5a2b1e1a6782a13308585e1a974adeeb86be0647"
        fixture_id = "mid06_pre_environment_depth_bar_dice"
        seed = "INTEG06-1-MID06-PRE-ENV-001"
        case = [ordered]@{
            fixture_id = "mid06_pre_environment_depth_bar_dice"
            seed = "INTEG06-1-MID06-PRE-ENV-001"
            travel_path = @("motel", "bar")
            expected_archetype = "bar"
            enter_game = "bar_dice"
        }
    }
    [ordered]@{
        milestone = "pre_world_depth"
        commit = "f1ebe9a729253e4ee3d4d99702a019d9328edbaf"
        fixture_id = "mid06_pre_world_depth_crew_debt"
        seed = "INTEG06-1-MID06-PRE-WORLD-001"
        case = [ordered]@{
            fixture_id = "mid06_pre_world_depth_crew_debt"
            seed = "INTEG06-1-MID06-PRE-WORLD-001"
            steps = @(
                [ordered]@{ type = "travel"; target = "gas_station_casino" }
                [ordered]@{ type = "travel"; target = "corner_store" }
                [ordered]@{ type = "lender"; lender_id = "the_crew" }
                [ordered]@{ type = "travel"; target = "gas_station_casino" }
                [ordered]@{ type = "travel"; target = "motel" }
                [ordered]@{ type = "travel"; target = "small_underground_casino" }
            )
            expected_archetype = "small_underground_casino"
            expected_lender_debt = "the_crew"
            enter_game = "blackjack"
        }
    }
)

try {
    foreach ($capture in $captures) {
        $plan = [ordered]@{
            schema = "beat_the_house.integ06_1_historical_capture_plan"
            version = 1
            historical_commit = [string]$capture.commit
            capture_milestone = [string]$capture.milestone
            cases = @($capture.case)
        }
        $planPath = Join-Path $temporaryPlanRoot ("$($capture.milestone).json")
        $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
        & $generator `
            -ProjectRoot $resolvedRoot `
            -GodotPath $GodotPath `
            -HistoricalCommit ([string]$capture.commit) `
            -CaptureClass mid_0_6 `
            -CaptureMilestone ([string]$capture.milestone) `
            -PlanPath $planPath `
            -OutputDirectory $resolvedOutput `
            -CaptureTimeoutSeconds $CaptureTimeoutSeconds `
            -KeepHistoricalArchive:$KeepHistoricalArchive
        if ($LASTEXITCODE -ne 0) {
            throw "Historical capture failed for $($capture.milestone) at $($capture.commit)."
        }
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryPlanRoot) {
        Remove-Item -LiteralPath $temporaryPlanRoot -Recurse -Force
    }
}

$provenanceFiles = @(Get-ChildItem -LiteralPath $resolvedOutput -Filter "*.provenance.json" -File)
if ($provenanceFiles.Count -ne $captures.Count) {
    throw "Expected $($captures.Count) mid-0.6 provenance sidecars, found $($provenanceFiles.Count)."
}
Write-Host "INTEG06_1_MID06_FIXTURES PASS captures=$($captures.Count) output=$resolvedOutput custody_preserved=$([bool]$KeepHistoricalArchive)"
