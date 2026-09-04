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
        seed = "INTEG06-1-MID06-PRE-GAME-009"
        case = [ordered]@{
            fixture_id = "mid06_pre_game_depth_slot"
            seed = "INTEG06-1-MID06-PRE-GAME-009"
            travel_path = @("gas_station_casino")
            expected_archetype = "gas_station_casino"
            enter_game = "slot"
            surface_steps = @(
                [ordered]@{ type = "click"; action = "slot_spin"; index = 0; confirm = $true; wait_msec = 50 }
            )
            expected_surface_state = "slot_after_spin"
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
            surface_steps = @(
                [ordered]@{ type = "click"; action = "bar_dice_roll"; index = 0; confirm = $true; wait_msec = 50 }
                [ordered]@{ type = "click"; action = "bar_dice_resolve"; index = 0; confirm = $true; wait_msec = 50 }
            )
            expected_surface_state = "bar_dice_after_round"
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
            surface_steps = @(
                [ordered]@{ type = "click"; action = "blackjack_chip"; index = 0; confirm = $true; wait_msec = 50 }
                [ordered]@{ type = "click"; action = "blackjack_deal"; index = 0; confirm = $true; wait_msec = 50 }
                [ordered]@{ type = "click"; action = "blackjack_stand"; index = 0; confirm = $true; wait_msec = 50 }
            )
            expected_surface_state = "blackjack_after_hand"
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
    $combinedCases = @($captures | ForEach-Object {
        $combinedCase = [ordered]@{ capture_milestone = [string]$_.milestone }
        foreach ($key in $_.case.Keys) { $combinedCase[$key] = $_.case[$key] }
        $combinedCase
    })
    $combinedPlan = [ordered]@{
        schema = "beat_the_house.integ06_1_historical_capture_plan"
        version = 1
        capture_class = "mid_0_6"
        historical_release = "mid-0.6-development-boundary"
        cases = $combinedCases
    }
    $combinedPlan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $resolvedOutput "capture_plan.json") -Encoding utf8
}
finally {
    if (Test-Path -LiteralPath $temporaryPlanRoot) {
        # Preserve the capture plans with the retained historical archives so
        # custody can be audited without depending on regenerated temporary
        # input. Closeout policy forbids destructive cleanup.
        Write-Host "INTEG06_1_MID06_PLAN_CUSTODY=$temporaryPlanRoot"
    }
}

$provenanceFiles = @(Get-ChildItem -LiteralPath $resolvedOutput -Filter "*.provenance.json" -File)
if ($provenanceFiles.Count -ne $captures.Count) {
    throw "Expected $($captures.Count) mid-0.6 provenance sidecars, found $($provenanceFiles.Count)."
}
Write-Host "INTEG06_1_MID06_FIXTURES PASS captures=$($captures.Count) output=$resolvedOutput custody_preserved=$([bool]$KeepHistoricalArchive)"
