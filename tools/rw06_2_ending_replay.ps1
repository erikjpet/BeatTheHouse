[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('clean', 'cheat', 'heist')]
    [string]$Ending,
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$Seed = '',
    [ValidateRange(1, 2)]
    [int]$Repeat = 2,
    [ValidateRange(30, 300)]
    [int]$TimeoutSeconds = 120,
    [string]$EvidenceRoot = '',
    [switch]$BridgeTransportContract,
    [switch]$BridgeStatusContract,
    [switch]$SemanticScrollContract
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Worktree = Split-Path -Parent $PSScriptRoot
$SessionTool = Join-Path $PSScriptRoot 'agent_playtest_session.ps1'
$ReplayPolicyTool = Join-Path $PSScriptRoot 'rw06_2_replay_policies.ps1'
$GodotBin = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$Schema = 'beat_the_house.agent_public_observation'
$SchemaVersion = 1
$BridgeCallRoot = Join-Path $Worktree '.tmp\rw06_2\bridge_calls'
$FixedSeeds = @{
    clean = 'RW06-CLEAN-ROUTE-01'
    cheat = 'RW06-CHEAT-ROUTE-01'
    heist = 'PLAYTEST-CATALOG-01'
}
$ExpectedOutcomes = @{
    clean = @('players_card')
    cheat = @('showdown_survived')
    heist = @('heist_clean_sweep', 'heist_out_hot', 'heist_somebody_got_pinched')
}
$GrandCasinoChipReserve = 50

if (-not (Test-Path -LiteralPath $SessionTool)) {
    throw "Production-input launcher is missing: $SessionTool"
}
if (-not (Test-Path -LiteralPath $ReplayPolicyTool)) {
    throw "Replay policy helper is missing: $ReplayPolicyTool"
}
. $ReplayPolicyTool
if (-not (Test-Path -LiteralPath $GodotBin)) {
    throw "Pinned Godot binary is missing: $GodotBin"
}
if ([string]::IsNullOrWhiteSpace($Seed)) {
    $Seed = $FixedSeeds[$Ending]
}
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $Worktree ".tmp\rw06_2\$Ending"
}

$env:GODOT_BIN = $GodotBin
$script:PowerShellExe = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$script:Session = ''
$script:RunRoot = ''
$script:TranscriptPath = ''
$script:MoneyCurvePath = ''
$script:LastResult = $null
$script:LastObservation = $null
$script:ActionCount = 0
$script:TraceOrdinal = 0
$script:LastMoneySignature = ''
$script:MidpointSaved = $false
$script:OwnedSessionPid = 0
$script:OwnedSessionStartUtcTicks = 0L
$script:OwnedSessionExecutablePath = ''
$script:SessionRoot = ''
$script:GrandFareRecoveryActive = $false
$script:GrandFareAcceptedOfferKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$script:GrandFareAcceptedLenderIds = New-Object 'System.Collections.Generic.HashSet[string]'
$script:GrandFareResolvedCashEventKeys = New-Object 'System.Collections.Generic.HashSet[string]'
$script:GrandFareRecoveryVisitedNodes = New-Object 'System.Collections.Generic.HashSet[string]'


function Get-Value {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string[]]$Path,
        [AllowNull()]$Default = $null
    )
    $current = $InputObject
    foreach ($segment in $Path) {
        if ($null -ceq $current) { return $Default }
        if ($current -is [System.Collections.IDictionary]) {
            $matchingKeys = @($current.Keys | Where-Object { [string]$_ -ceq $segment })
            if ($matchingKeys.Count -ceq 0) { return $Default }
            if ($matchingKeys.Count -cne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $current[$matchingKeys[0]]
        }
        else {
            $properties = @($current.PSObject.Properties | Where-Object { $_.Name -ceq $segment })
            if ($properties.Count -ceq 0) { return $Default }
            if ($properties.Count -cne 1) { throw "Ambiguous exact property '$segment'." }
            $current = $properties[0].Value
        }
    }
    if ($null -ceq $current) { return $Default }
    return $current
}


function Get-Array {
    param([AllowNull()]$Value)
    if ($null -ceq $Value) { return @() }
    return @($Value)
}


function ConvertTo-BridgeBase64Token {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw 'Bridge command tokens cannot encode blank public identities.'
    }
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
}


function Get-RenderedHudInteger {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('bankroll', 'chips', 'heat_level')][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $witnessName = if ($Name -ceq 'heat_level') { 'heat_rendered' } else { "${Name}_rendered" }
    $witness = Get-Value $script:LastObservation @('status_hud', $witnessName) $null
    $value = Get-Value $script:LastObservation @('status_hud', $Name) $null
    if ($witness -isnot [bool] -or -not [bool]$witness -or
        ($value -isnot [int32] -and $value -isnot [int64]) -or [long]$value -lt 0 -or
        [long]$value -gt [int]::MaxValue) {
        throw "$Context has no exact fully rendered HUD $Name integer."
    }
    return [int]$value
}


function Test-PublicTerminalSurface {
    $screen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    if ($screen -cnotin @('VICTORY', 'FAILURE')) { return $false }
    $visible = Get-Value $script:LastObservation @('screen', 'run_report_visible') $null
    if ($visible -isnot [bool] -or -not [bool]$visible) {
        throw "Terminal screen '$screen' has no exact rendered RunReport witness."
    }
    return $true
}


function Assert-ReplayPauseOwnership {
    param(
        [AllowNull()]$Snapshot,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $owners = @(Get-Array (Get-Value $Snapshot @('pause_owners') @()))
    if ('agent_replay' -cnotin $owners -or
        -not [bool](Get-Value $Snapshot @('application_paused') $false) -or
        -not [bool](Get-Value $Snapshot @('simulation_paused') $false) -or
        -not [bool](Get-Value $Snapshot @('environment_canvas_paused') $false) -or
        -not [bool](Get-Value $Snapshot @('game_canvas_paused') $false)) {
        throw "Deterministic action-boundary pause ownership was absent $Context."
    }
}


function New-AnchoredSessionRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Session,
        [string]$DateSegment = (Get-Date -Format 'yyyy-MM-dd')
    )
    if ($Session -notmatch '^[A-Za-z0-9_-]+$' -or $DateSegment -notmatch '^\d{4}-\d{2}-\d{2}$') {
        throw 'Cannot create an anchored session root from unsafe path segments.'
    }
    return [IO.Path]::GetFullPath((Join-Path $Worktree ".tmp\agent_playtest\$DateSegment\$Session"))
}


function ConvertFrom-BridgeOutput {
    param([Parameter(Mandatory = $true)][string]$Text)
    $trimmed = $Text.Trim()
    $opening = $trimmed.IndexOf('{')
    if ($opening -lt 0) {
        throw "Bridge returned no JSON object: $trimmed"
    }
    $json = $trimmed.Substring($opening)
    try {
        return $json | ConvertFrom-Json
    }
    catch {
        throw "Bridge returned malformed JSON: $($_.Exception.Message)"
    }
}


function Invoke-SessionTool {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Parameters
    )
    [void](New-Item -ItemType Directory -Path $BridgeCallRoot -Force)
    $effectiveParameters = @{}
    foreach ($key in $Parameters.Keys) {
        $effectiveParameters[$key] = $Parameters[$key]
    }
    if (-not [string]::IsNullOrWhiteSpace($script:SessionRoot) -and -not $effectiveParameters.ContainsKey('SessionRoot')) {
        $effectiveParameters['SessionRoot'] = $script:SessionRoot
    }
    $bridgeToken = "$PID-$([Guid]::NewGuid().ToString('N'))"
    if ($bridgeToken -notmatch '^[0-9]+-[a-f0-9]{32}$') {
        throw 'Could not create a safe unique bridge-call token.'
    }
    $stdoutPath = Join-Path $BridgeCallRoot "$bridgeToken.stdout.tmp"
    $stderrPath = Join-Path $BridgeCallRoot "$bridgeToken.stderr.tmp"
    $parametersJson = $effectiveParameters | ConvertTo-Json -Compress
    $escapedSessionTool = $SessionTool.Replace("'", "''")
    $escapedParametersJson = $parametersJson.Replace("'", "''")
    $bootstrap = @"
`$ErrorActionPreference = 'Stop'
`$ProgressPreference = 'SilentlyContinue'
`$utf8 = New-Object Text.UTF8Encoding(`$false)
`$OutputEncoding = `$utf8
[Console]::OutputEncoding = `$utf8
`$sessionTool = '$escapedSessionTool'
`$parameterObject = '$escapedParametersJson' | ConvertFrom-Json
`$bridgeParameters = @{}
foreach (`$property in `$parameterObject.PSObject.Properties) {
    `$bridgeParameters[`$property.Name] = `$property.Value
}
& `$sessionTool @bridgeParameters
"@
    $encodedBootstrap = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
    $declaredTimeout = 15
    if ($effectiveParameters.ContainsKey('TimeoutSeconds')) {
        $parsedTimeout = 0
        if ([int]::TryParse([string]$effectiveParameters['TimeoutSeconds'], [ref]$parsedTimeout)) {
            $declaredTimeout = [Math]::Max(1, $parsedTimeout)
        }
    }
    $deadline = (Get-Date).AddSeconds([Math]::Max(15, $declaredTimeout + 15))
    $bridgeProcess = $null
    try {
        $bridgeProcess = Start-Process -FilePath $script:PowerShellExe -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-OutputFormat', 'Text',
            '-EncodedCommand', $encodedBootstrap
        ) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -PassThru
        while (-not $bridgeProcess.HasExited -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 50
            $bridgeProcess.Refresh()
        }
        if (-not $bridgeProcess.HasExited) {
            Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue
            throw "agent_playtest_session bridge PID $($bridgeProcess.Id) exceeded its bounded call timeout."
        }
        # HasExited is the only wait condition. This zero-duration finalization
        # makes Start-Process expose ExitCode reliably on Windows PowerShell.
        $bridgeProcess.WaitForExit()
        $bridgeProcess.Refresh()
        $bridgeExitCode = $bridgeProcess.ExitCode
        $stdoutValue = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw -Encoding utf8 } else { '' }
        $stderrValue = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw -Encoding utf8 } else { '' }
        $stdout = if ($null -ceq $stdoutValue) { '' } else { [string]$stdoutValue }
        $stderr = if ($null -ceq $stderrValue) { '' } else { [string]$stderrValue }
        $mergedOutput = @($stdout.Trim(), $stderr.Trim()) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $mergedOutput = $mergedOutput -join [Environment]::NewLine
        # Some Windows PowerShell/Start-Process builds leave ExitCode unset
        # when both native streams are redirected. In that case the strict
        # stderr/stdout/JSON checks below are the authoritative result.
        if ($null -cne $bridgeExitCode -and [int]$bridgeExitCode -cne 0) {
            throw "agent_playtest_session failed with exit code $bridgeExitCode. $mergedOutput"
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            throw "agent_playtest_session emitted stderr despite exit 0. $mergedOutput"
        }
        if ([string]::IsNullOrWhiteSpace($stdout)) {
            throw 'agent_playtest_session returned no stdout.'
        }
        return $stdout
    }
    finally {
        if ($null -cne $bridgeProcess) {
            $bridgeProcess.Dispose()
        }
        Remove-Item -LiteralPath $stdoutPath -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrPath -ErrorAction SilentlyContinue
    }
}


function Get-OwnedBridgeCaptureResidue {
    $ownedPattern = "^$([regex]::Escape([string]$PID))-[a-f0-9]{32}\.(?:stdout|stderr)\.tmp$"
    return @(Get-ChildItem -LiteralPath $BridgeCallRoot -File -Filter "$PID-*.tmp" -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -match $ownedPattern
    })
}


function Remove-OwnedBridgeCaptureResidue {
    # The start-only bridge can release its own capture path before Windows
    # releases a copy inherited by the live Godot child. Once that child has
    # exited, bounded retries must remove every capture owned by this runner.
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        $residue = @(Get-OwnedBridgeCaptureResidue)
        if ($residue.Count -ceq 0) { return }
        foreach ($file in $residue) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
        }
        if (@(Get-OwnedBridgeCaptureResidue).Count -ceq 0) { return }
        Start-Sleep -Milliseconds 50
    }
    $paths = @(Get-OwnedBridgeCaptureResidue | ForEach-Object { $_.FullName })
    throw "Bridge capture cleanup remained locked after the host exited: $($paths -join ' | ')"
}


function Assert-NoForbiddenObservationKey {
    param(
        [AllowNull()]$Value,
        [string]$Path = 'observable'
    )
    if ($null -ceq $Value) { return }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            $name = [string]$property.Name
            if ($name -iin @(
                'run_state', 'narrative_flags', 'shoe', 'shoe_order', 'shoe_cards',
                'edge_schedule', 'trigger_context', 'scenario_layout_audit',
                'crew_heist_state', 'crew_heist_private_capsule', 'private_capsule',
                'rng_state', 'hidden_dealer_card', 'dealer_hole_card',
                'debt_items', 'debt_text', 'impact_summary', 'consequence_summary',
                'requires_confirm', 'loan_terms', 'demo_objective', 'objective_guidance',
                'next_objective', 'run_status', 'run_text'
            )) {
                throw "Private key escaped into the public observation at $Path.$name"
            }
            Assert-NoForbiddenObservationKey -Value $property.Value -Path "$Path.$name"
        }
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            Assert-NoForbiddenObservationKey -Value $Value[$key] -Path "$Path.$key"
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $index = 0
        foreach ($item in $Value) {
            Assert-NoForbiddenObservationKey -Value $item -Path "$Path[$index]"
            $index++
        }
    }
}


function Assert-HealthyResult {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Command
    )
    if (-not [bool](Get-Value $Result @('accepted') $false)) {
        $reason = [string](Get-Value $Result @('reason') 'no reason supplied')
        throw "Production input was rejected for '$Command': $reason"
    }
    Assert-ReplayPauseOwnership -Snapshot (Get-Value $Result @('replay_pause_before') $null) -Context "before '$Command'"
    Assert-ReplayPauseOwnership -Snapshot (Get-Value $Result @('look', 'replay_pause') $null) -Context "after '$Command'"
    $alerts = @(Get-Array (Get-Value $Result @('log_alerts') @()))
    if ($alerts.Count -gt 0) {
        throw "Godot emitted a warning/error after '$Command': $($alerts -join ' | ')"
    }
    $pngError = [string](Get-Value $Result @('look', 'png_error') '')
    if (-not [string]::IsNullOrWhiteSpace($pngError)) {
        throw "Screenshot capture failed after '$Command': $pngError"
    }
    $observation = Get-Value $Result @('look', 'observable') $null
    if ($null -ceq $observation) {
        throw "No public observation followed '$Command'."
    }
    if ([string](Get-Value $observation @('schema') '') -cne $Schema -or
        [int](Get-Value $observation @('schema_version') 0) -cne $SchemaVersion) {
        throw "Unexpected public observation schema after '$Command'."
    }
    if ([string](Get-Value $observation @('privacy', 'policy') '') -cne 'strict_allowlist') {
        throw "The bridge did not declare the strict public allowlist after '$Command'."
    }
    $trace = Get-Value $Result @('trace') $null
    if ($null -ceq $trace -or [string](Get-Value $trace @('command') '') -cne $Command -or
        -not [bool](Get-Value $trace @('input_emitted') $false)) {
        throw "The bridge did not return an authenticated public transition trace for '$Command'."
    }
    Assert-NoForbiddenObservationKey -Value $observation
    $gameId = [string](Get-Value $observation @('game', 'game_id') '')
    $holeVisible = [bool](Get-Value $observation @('game', 'dealer_hole_visible') $false)
    $dealerCards = @(Get-Array (Get-Value $observation @('game', 'dealer_cards') @()))
    if ($gameId -ceq 'blackjack' -and -not $holeVisible -and $dealerCards.Count -cne 0) {
        throw "Blackjack dealer cards escaped before the public reveal after '$Command'."
    }
}


function New-CanonicalRecord {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $observation = Get-Value $Result @('look', 'observable') $null
    $checkpoint = Get-Value $observation @('checkpoint') $null
    $game = Get-Value $observation @('game') $null
    $event = Get-Value $observation @('event_popup') $null
    $talk = Get-Value $observation @('talk') $null
    $feedback = Get-Value $observation @('feedback') $null
    $report = Get-Value $observation @('screen', 'run_report', 'outcome') $null
    $transition = Get-Value $Result @('trace') $null
    return [ordered]@{
        ordinal = $script:TraceOrdinal
        intent = $Intent
        command = [string](Get-Value $Result @('command') '')
        checkpoint = [ordered]@{
            screen = [string](Get-Value $checkpoint @('screen') '')
            location_id = [string](Get-Value $checkpoint @('location_id') '')
            location_archetype = [string](Get-Value $checkpoint @('location_archetype') '')
            bankroll = [int](Get-Value $checkpoint @('bankroll') 0)
            chips = [int](Get-Value $checkpoint @('chips') 0)
            heat = [int](Get-Value $checkpoint @('heat') 0)
        }
        game = [ordered]@{
            id = [string](Get-Value $game @('game_id') '')
            phase = [string](Get-Value $game @('phase') '')
            outcome = [string](Get-Value $game @('outcome_message') '')
            selected_stake = [int](Get-Value $game @('selected_stake') 0)
            player_hands = @(Get-Array (Get-Value $game @('player_hands') @()))
            dealer_up_card = Get-Value $game @('dealer_up_card') ([ordered]@{})
            dealer_hole_visible = [bool](Get-Value $game @('dealer_hole_visible') $false)
            dealer_cards = @(Get-Array (Get-Value $game @('dealer_cards') @()))
            boss_hand_number = [int](Get-Value $game @('boss_hand_number') 0)
            boss_tell = [string](Get-Value $game @('boss_tell') '')
        }
        event = [ordered]@{
            id = [string](Get-Value $event @('event_id') '')
            choices = @(Get-Array (Get-Value $event @('choice_ids') @()))
        }
        talk = [ordered]@{
            id = [string](Get-Value $talk @('event_id') '')
            choices = @(Get-Array (Get-Value $talk @('choice_ids') @()))
        }
        feedback = [ordered]@{
            object_id = [string](Get-Value $feedback @('object_id') '')
            text = [string](Get-Value $feedback @('text') '')
            bankroll_delta = [int](Get-Value $feedback @('bankroll_delta') 0)
            suspicion_delta = [int](Get-Value $feedback @('suspicion_delta') 0)
        }
        transition = [ordered]@{
            before_fingerprint = [string](Get-Value $transition @('before_fingerprint') '')
            after_fingerprint = [string](Get-Value $transition @('after_fingerprint') '')
            public_state_changed = [bool](Get-Value $transition @('public_state_changed') $false)
            screen_changed = [bool](Get-Value $transition @('screen_changed') $false)
            location_changed = [bool](Get-Value $transition @('location_changed') $false)
            modal_changed = [bool](Get-Value $transition @('modal_changed') $false)
            economy_changed = [bool](Get-Value $transition @('economy_changed') $false)
            heat_changed = [bool](Get-Value $transition @('heat_changed') $false)
            clock_changed = [bool](Get-Value $transition @('clock_changed') $false)
            objective_changed = [bool](Get-Value $transition @('objective_changed') $false)
        }
        terminal = [ordered]@{
            key = [string](Get-Value $report @('key') '')
            won = [bool](Get-Value $report @('won') $false)
        }
    }
}


function Write-ActionEvidence {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $script:TraceOrdinal++
    $script:ActionCount++
    $record = New-CanonicalRecord -Result $Result -Intent $Intent
    Add-Content -LiteralPath $script:TranscriptPath -Value ($record | ConvertTo-Json -Depth 40 -Compress) -Encoding utf8

    $checkpoint = $record.checkpoint
    $moneySignature = "$($checkpoint.bankroll)|$($checkpoint.chips)|$($checkpoint.heat)"
    if ($moneySignature -cne $script:LastMoneySignature) {
        $money = [ordered]@{
            action = $script:ActionCount
            intent = $Intent
            bankroll = $checkpoint.bankroll
            chips = $checkpoint.chips
            heat = $checkpoint.heat
        }
        Add-Content -LiteralPath $script:MoneyCurvePath -Value ($money | ConvertTo-Json -Compress) -Encoding utf8
        $script:LastMoneySignature = $moneySignature
    }
}


function Invoke-BridgeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$Intent,
        [switch]$ObservationOnly
    )
    $output = Invoke-SessionTool -Parameters @{
        Session = $script:Session
        Command = $Command
        TimeoutSeconds = $TimeoutSeconds
    }
    $result = ConvertFrom-BridgeOutput -Text $output
    Assert-HealthyResult -Result $result -Command $Command
    $script:LastResult = $result
    $script:LastObservation = Get-Value $result @('look', 'observable') $null
    if (-not $ObservationOnly) {
        Write-ActionEvidence -Result $result -Intent $Intent
    }
    return $result
}


function Start-BridgeSession {
    param([switch]$SkipInitialLook)
    if ([string]::IsNullOrWhiteSpace($script:SessionRoot)) {
        throw "Session '$($script:Session)' has no anchored absolute session root."
    }
    $output = Invoke-SessionTool -Parameters @{
        Session = $script:Session
        Start = $true
        TimeoutSeconds = $TimeoutSeconds
    }
    $ready = ConvertFrom-BridgeOutput -Text $output
    Assert-ReplayPauseOwnership -Snapshot (Get-Value $ready @('replay_pause') $null) -Context "at session '$($script:Session)' ready"
    $status = Get-SessionStatus
    if (-not [bool](Get-Value $status @('running') $false)) {
        throw "Session '$($script:Session)' did not publish a running owned-process identity after start."
    }
    if (-not $SkipInitialLook) {
        $null = Invoke-BridgeCommand -Command 'look' -Intent 'observe the current player surface' -ObservationOnly
    }
}


function Get-SessionStatus {
    $output = Invoke-SessionTool -Parameters @{ Session = $script:Session }
    $status = ConvertFrom-BridgeOutput -Text $output
    if ([string](Get-Value $status @('session') '') -cne $script:Session) {
        throw "Session status returned the wrong owner id for '$($script:Session)'."
    }
    $reportedRoot = [string](Get-Value $status @('folder') '')
    if ([string]::IsNullOrWhiteSpace($reportedRoot) -or
        -not ([IO.Path]::GetFullPath($reportedRoot)).Equals([IO.Path]::GetFullPath($script:SessionRoot), [StringComparison]::OrdinalIgnoreCase)) {
        throw "Session status escaped the anchored root for '$($script:Session)'."
    }
    if ([bool](Get-Value $status @('running') $false)) {
        $ownedPid = [int](Get-Value $status @('pid') 0)
        $ownedStartUtcTicks = [long](Get-Value $status @('start_utc_ticks') 0L)
        $ownedExecutablePath = [string](Get-Value $status @('executable_path') '')
        if ($ownedPid -le 0 -or $ownedStartUtcTicks -le 0 -or [string]::IsNullOrWhiteSpace($ownedExecutablePath)) {
            throw "Running session '$($script:Session)' did not publish a complete owned-process identity."
        }
        if (-not ([IO.Path]::GetFullPath($ownedExecutablePath)).Equals([IO.Path]::GetFullPath($GodotBin), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Running session '$($script:Session)' reported an unexpected executable path."
        }
        $script:OwnedSessionPid = $ownedPid
        $script:OwnedSessionStartUtcTicks = $ownedStartUtcTicks
        $script:OwnedSessionExecutablePath = $ownedExecutablePath
    }
    return $status
}


function Get-ExactOwnedSessionProcess {
    if ($script:OwnedSessionPid -le 0 -or $script:OwnedSessionStartUtcTicks -le 0 -or
        [string]::IsNullOrWhiteSpace($script:OwnedSessionExecutablePath)) {
        return $null
    }
    $process = Get-Process -Id $script:OwnedSessionPid -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    try {
        $actualStartUtcTicks = [long]$process.StartTime.ToUniversalTime().Ticks
        $actualExecutablePath = [IO.Path]::GetFullPath([string]$process.Path)
        $expectedExecutablePath = [IO.Path]::GetFullPath($script:OwnedSessionExecutablePath)
        if ($actualStartUtcTicks -cne $script:OwnedSessionStartUtcTicks -or
            -not $actualExecutablePath.Equals($expectedExecutablePath, [StringComparison]::OrdinalIgnoreCase)) {
            return $null
        }
        return $process
    }
    catch {
        return $null
    }
}


function Stop-ExactOwnedSessionProcess {
    $process = Get-ExactOwnedSessionProcess
    if (-not $process) { return $false }
    # PID reuse is not ownership. The exact start-time/path tuple above must
    # still match before this runner may force-stop its own Godot host.
    Stop-Process -Id $script:OwnedSessionPid -Force -ErrorAction Stop
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-ExactOwnedSessionProcess)) {
            return $true
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Exact owned Godot PID $($script:OwnedSessionPid) remained alive after bounded force-stop."
}


function Assert-NoPostExitLogAlerts {
    if (Get-ExactOwnedSessionProcess) {
        throw "Cannot perform the final log rescan while session '$($script:Session)' is still running."
    }
    $alerts = @()
    foreach ($logName in @('godot.stdout.log', 'godot.stderr.log')) {
        $logPath = Join-Path $script:SessionRoot $logName
        if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
            $alerts += "$logName`: missing after process exit"
            continue
        }
        $alerts += @(Get-Content -LiteralPath $logPath -Encoding utf8 | Where-Object {
            $_ -match 'SCRIPT ERROR|(^|\s)ERROR[: ]|(^|\s)WARNING[: ]'
        } | ForEach-Object { "$logName`: $_" })
    }
    if ($alerts.Count -gt 0) {
        throw "Godot logs contained warning/error output after confirmed process exit: $($alerts -join ' | ')"
    }
}


function Stop-BridgeSessionSafely {
    param([switch]$BestEffort)
    $gracefulFailure = $null
    $logFailure = $null
    try {
        $status = Get-SessionStatus
        if ([bool](Get-Value $status @('running') $false)) {
            $null = Invoke-BridgeCommand -Command 'quit' -Intent 'close the playtest host' -ObservationOnly
            Wait-ForSessionExit
        }
    }
    catch {
        $gracefulFailure = $_
    }

    $forced = Stop-ExactOwnedSessionProcess
    if (Get-ExactOwnedSessionProcess) {
        throw "Session '$($script:Session)' retained its exact owned Godot process after cleanup."
    }
    try {
        Assert-NoPostExitLogAlerts
    }
    catch {
        $logFailure = $_
    }
    Remove-OwnedBridgeCaptureResidue

    if ($null -cne $gracefulFailure -or $null -cne $logFailure) {
        $details = @()
        if ($null -cne $gracefulFailure) { $details += "graceful=$($gracefulFailure.Exception.Message)" }
        if ($null -cne $logFailure) { $details += "post_exit_logs=$($logFailure.Exception.Message)" }
        $message = "Session '$($script:Session)' cleanup forced=$forced failed qualification: $($details -join '; ')"
        if ($BestEffort) {
            Write-Warning $message
            return
        }
        throw $message
    }
}


function Wait-ForSessionExit {
    $graceSeconds = [Math]::Min(10, [Math]::Max(1, $TimeoutSeconds))
    $deadline = (Get-Date).AddSeconds($graceSeconds)
    while ((Get-Date) -lt $deadline) {
        $status = Get-SessionStatus
        if (-not [bool](Get-Value $status @('running') $false) -and -not (Get-ExactOwnedSessionProcess)) {
            return
        }
        Start-Sleep -Milliseconds 100
    }
    throw "Session '$($script:Session)' did not exit within its bounded $graceSeconds-second graceful-close window."
}


function Refresh-Look {
    $null = Invoke-BridgeCommand -Command 'look' -Intent 'observe the current player surface' -ObservationOnly
}


function Get-Buttons {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'buttons') @()))
}


function Find-Button {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [switch]$Contains
    )
    $matches = @()
    foreach ($button in Get-Buttons) {
        $buttonText = [string](Get-Value $button @('text') '')
        if (($Contains -and $buttonText.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) -or
            (-not $Contains -and $buttonText -ceq $Text)) {
            $matches += $button
        }
    }
    if ($matches.Count -gt 1) {
        throw "Visible button lookup is ambiguous for '$Text'."
    }
    if ($matches.Count -ceq 0) { return $null }
    return $matches[0]
}


function Select-UniqueFullyVisibleButton {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Buttons,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $matches = @($Buttons | Where-Object {
        [string](Get-Value $_ @('text') '') -ceq $Text
    })
    if ($matches.Count -gt 1) {
        throw "Fully visible button lookup is ambiguous for '$Text'."
    }
    if ($matches.Count -ceq 0) { return $null }
    $button = $matches[0]
    $fullyVisible = Get-Value $button @('fully_visible') $null
    if ($fullyVisible -isnot [bool]) {
        throw "Public button '$Text' has no unambiguous fully_visible signal."
    }
    if (-not [bool]$fullyVisible) { return $null }
    return $button
}


function Select-UniquePublicTutorialDialogButton {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Buttons,
        [Parameter(Mandatory = $true)][ValidateSet('ok', 'cancel')][string]$Role
    )
    $expectedId = "tutorial_skip_dialog:$Role"
    $matches = @($Buttons | Where-Object {
        [string](Get-Value $_ @('surface_id') '') -ceq 'tutorial_skip_dialog' -and
        [string](Get-Value $_ @('dialog_role') '') -ceq $Role -and
        [string](Get-Value $_ @('id') '') -ceq $expectedId
    })
    if ($matches.Count -cne 1) {
        throw "Expected exactly one rendered tutorial confirmation '$Role' control at '$expectedId'; found $($matches.Count)."
    }
    $button = $matches[0]
    foreach ($signal in @('enabled', 'fully_visible', 'dialog_rendered')) {
        $value = Get-Value $button @($signal) $null
        if ($value -isnot [bool]) {
            throw "Tutorial confirmation '$Role' control has no unambiguous $signal signal."
        }
        if (-not [bool]$value) {
            throw "Tutorial confirmation '$Role' control is not publicly enabled, fully visible, and rendered."
        }
    }
    return $button
}


function Get-PublicScrollSurfaces {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'scroll_surfaces') @()))
}


function Select-UniquePublicVerticalScrollSurface {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Surfaces,
        [Parameter(Mandatory = $true)][string]$SurfaceId,
        [Parameter(Mandatory = $true)][ValidateSet('up', 'down')][string]$Direction
    )
    if ($SurfaceId -cne 'run_menu') {
        throw "Unsupported public scroll surface '$SurfaceId'."
    }
    $matches = @($Surfaces | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq $SurfaceId
    })
    if ($matches.Count -cne 1) {
        throw "Expected exactly one public '$SurfaceId' scroll surface; found $($matches.Count)."
    }
    $surface = $matches[0]
    $rendered = Get-Value $surface @('rendered') $null
    if ([string](Get-Value $surface @('axis') '') -cne 'vertical' -or
        $rendered -isnot [bool] -or -not [bool]$rendered) {
        throw "Public '$SurfaceId' scroll surface is not a rendered vertical control."
    }
    $capability = "can_scroll_$Direction"
    $canScroll = Get-Value $surface @($capability) $null
    if ($canScroll -isnot [bool] -or -not [bool]$canScroll) {
        throw "Public '$SurfaceId' scroll surface cannot scroll $Direction."
    }
    return $surface
}


function Reveal-ButtonByVerticalScroll {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][ValidateSet('up', 'down')][string]$Direction,
        [ValidateRange(1, 16)][int]$MaximumScrolls = 12
    )
    for ($attempt = 0; $attempt -le $MaximumScrolls; $attempt++) {
        $button = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text $Text
        if ($null -cne $button) { return $button }
        if ($attempt -ceq $MaximumScrolls) { break }
        $surface = Select-UniquePublicVerticalScrollSurface `
            -Surfaces @(Get-PublicScrollSurfaces) `
            -SurfaceId 'run_menu' `
            -Direction $Direction
        $surfaceId = [string](Get-Value $surface @('id') '')
        $null = Invoke-BridgeCommand `
            -Command "scroll_surface $surfaceId $Direction" `
            -Intent "scroll the visible run menu $Direction toward $Text"
        Wait-Frames -Frames 2
    }
    throw "Required run-menu button '$Text' did not become visible within $MaximumScrolls public scroll inputs."
}


function Click-RunMenuButton {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][ValidateSet('up', 'down')][string]$RevealDirection
    )
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'run_menu_visible') $false)) {
        throw "Cannot click run-menu button '$Text' while the public run menu is closed."
    }
    $null = Reveal-ButtonByVerticalScroll -Text $Text -Direction $RevealDirection
    return Click-Button -Text $Text -Intent $Intent
}


function Click-Button {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Intent,
        [switch]$Contains
    )
    $button = Find-Button -Text $Text -Contains:$Contains
    if ($null -ceq $button) {
        throw "Required visible button was not found: $Text"
    }
    $id = [string](Get-Value $button @('id') '')
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw "Visible button '$Text' has no stable public id."
    }
    return Invoke-BridgeCommand -Command "click_button $id" -Intent $Intent
}


function Click-TutorialConfirmationButton {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('ok', 'cancel')][string]$Role,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $button = Select-UniquePublicTutorialDialogButton -Buttons @(Get-Buttons) -Role $Role
    $id = [string](Get-Value $button @('id') '')
    $expectedId = "tutorial_skip_dialog:$Role"
    if ([string]::IsNullOrWhiteSpace($id) -or $id -cne $expectedId) {
        throw "Tutorial confirmation '$Role' control has no exact stable public id."
    }
    return Invoke-BridgeCommand -Command "click_button $id" -Intent $Intent
}


function Select-ExactRenderedCanvasObject {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Objects,
        [Parameter(Mandatory = $true)][string]$SemanticId
    )
    $matches = @($Objects | Where-Object {
        $id = Get-Value $_ @('semantic_id') $null
        $id -is [string] -and [string]$id -ceq $SemanticId
    })
    if ($matches.Count -gt 1) {
        throw "Canvas object '$SemanticId' is ambiguous."
    }
    if ($matches.Count -ceq 0) { return $null }
    $rendered = Get-Value $matches[0] @('rendered') $null
    $enabled = Get-Value $matches[0] @('enabled') $null
    if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
        throw "Canvas object '$SemanticId' has no exact rendered/enabled witnesses."
    }
    if (-not [bool]$rendered -or -not [bool]$enabled) { return $null }
    return $matches[0]
}


function Find-CanvasObject {
    param([Parameter(Mandatory = $true)][string]$SemanticId)
    return Select-ExactRenderedCanvasObject `
        -Objects @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @())) `
        -SemanticId $SemanticId
}


function Get-RoomActions {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'room_actions') @()))
}


function Open-SemanticObject {
    param(
        [Parameter(Mandatory = $true)][string]$SemanticId,
        [Parameter(Mandatory = $true)][string]$Intent,
        [string[]]$PreferredActions = @()
    )
    if ($null -ceq (Find-CanvasObject -SemanticId $SemanticId)) {
        throw "Required semantic object is not visible and enabled: $SemanticId"
    }
    $null = Invoke-BridgeCommand -Command "click_object $SemanticId" -Intent "focus $SemanticId"
    $enabled = @(Get-RoomActions | Where-Object {
        $enabledValue = Get-Value $_ @('enabled') $null
        $renderedValue = Get-Value $_ @('rendered') $null
        if ($enabledValue -isnot [bool] -or $renderedValue -isnot [bool]) {
            throw "Semantic object '$SemanticId' exposed a room action without exact rendered/enabled witnesses."
        }
        [bool]$enabledValue -and [bool]$renderedValue
    })
    if ($enabled.Count -ceq 0) {
        throw "Semantic object '$SemanticId' exposed no enabled player action."
    }
    $selected = $null
    foreach ($preferred in $PreferredActions) {
        $matches = @($enabled | Where-Object {
            ([string](Get-Value $_ @('id') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('action') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('action_id') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('emit_object_id') '') -ceq $preferred) -or
            ([string](Get-Value $_ @('label') '') -ceq $preferred)
        })
        if ($matches.Count -ceq 1) {
            $selected = $matches[0]
            break
        }
        if ($matches.Count -gt 1) {
            throw "Action '$preferred' is ambiguous on '$SemanticId'."
        }
    }
    if ($null -ceq $selected -and $enabled.Count -ceq 1) {
        $selected = $enabled[0]
    }
    if ($null -ceq $selected) {
        $labels = @($enabled | ForEach-Object { [string](Get-Value $_ @('label') '') }) -join ', '
        throw "Semantic object '$SemanticId' needs an explicit action. Visible actions: $labels"
    }
    return Invoke-RoomActionRow -Row $selected -Intent $Intent
}


function Select-FirstRenderedCanvasObjectByPrefix {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Objects,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    $eligible = @()
    $seen = @{}
    foreach ($object in $Objects) {
        $semanticId = Get-Value $object @('semantic_id') $null
        if ($semanticId -isnot [string] -or -not ([string]$semanticId).StartsWith($Prefix, [StringComparison]::Ordinal)) {
            continue
        }
        if ($seen.ContainsKey([string]$semanticId)) {
            throw "Canvas prefix '$Prefix' exposes duplicate semantic id '$semanticId'."
        }
        $seen[[string]$semanticId] = $true
        $rendered = Get-Value $object @('rendered') $null
        $enabled = Get-Value $object @('enabled') $null
        if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
            throw "Canvas object '$semanticId' has no exact rendered/enabled witnesses."
        }
        if ([bool]$rendered -and [bool]$enabled) { $eligible += $object }
    }
    if ($eligible.Count -ceq 0) { return $null }
    return $eligible | Sort-Object -Property @{ Expression = { [string](Get-Value $_ @('semantic_id') '') } } -CaseSensitive | Select-Object -First 1
}


function Find-CanvasObjectByPrefix {
    param([Parameter(Mandatory = $true)][string]$Prefix)
    return Select-FirstRenderedCanvasObjectByPrefix `
        -Objects @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @())) `
        -Prefix $Prefix
}


function Get-EventChoiceRoomAction {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$ChoiceId
    )
    $expected = "event_response:$EventId`:$ChoiceId"
    $matches = @(Get-RoomActions | Where-Object {
        ([string](Get-Value $_ @('emit_object_id') '') -ceq $expected) -or
        ([string](Get-Value $_ @('id') '') -ceq $expected) -or
        ([string](Get-Value $_ @('action') '') -ceq $expected) -or
        ([string](Get-Value $_ @('action_id') '') -ceq $expected)
    })
    if ($matches.Count -gt 1) {
        throw "Event choice '$EventId/$ChoiceId' exposed more than one room action."
    }
    if ($matches.Count -ceq 0) { return $null }
    return $matches[0]
}


function Assert-ExactRenderedRoomActionBinding {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$SelectedObjectId,
        [Parameter(Mandatory = $true)][int]$Index,
        [Parameter(Mandatory = $true)][ValidateSet('id', 'action', 'action_id', 'emit_object_id', 'label')][string]$IdentityKey,
        [Parameter(Mandatory = $true)][string]$IdentityValue
    )
    $matches = @($Rows | Where-Object {
        [string](Get-Value $_ @('selected_object_id') '') -ceq $SelectedObjectId -and
            [string](Get-Value $_ @($IdentityKey) '') -ceq $IdentityValue
    })
    if ($matches.Count -cne 1) {
        throw "Room action '$SelectedObjectId/$IdentityValue' is missing or ambiguous."
    }
    $liveIndex = Get-Value $matches[0] @('index') $null
    $liveEnabled = Get-Value $matches[0] @('enabled') $null
    $liveRendered = Get-Value $matches[0] @('rendered') $null
    if (($liveIndex -isnot [int32] -and $liveIndex -isnot [int64]) -or [long]$liveIndex -ne $Index) {
        throw "Room action '$SelectedObjectId/$IdentityValue' changed row order."
    }
    if ($liveEnabled -isnot [bool] -or $liveRendered -isnot [bool] -or
        -not [bool]$liveEnabled -or -not [bool]$liveRendered) {
        throw "Room action '$SelectedObjectId/$IdentityValue' is disabled, clipped, or lacks exact witnesses."
    }
    return $matches[0]
}


function Invoke-RoomActionRow {
    param(
        [Parameter(Mandatory = $true)]$Row,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $enabled = Get-Value $Row @('enabled') $null
    $rendered = Get-Value $Row @('rendered') $null
    if ($enabled -isnot [bool] -or $rendered -isnot [bool]) {
        throw 'Required room action has no exact rendered/enabled witnesses.'
    }
    if (-not [bool]$rendered) {
        throw 'Required room action is clipped or not fully rendered.'
    }
    if (-not [bool]$enabled) {
        $reason = [string](Get-Value $Row @('disabled_reason') 'no public reason supplied')
        throw "Required room action is disabled: $reason"
    }
    $selectedObjectId = Get-Value $Row @('selected_object_id') $null
    $indexValue = Get-Value $Row @('index') $null
    if ($selectedObjectId -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$selectedObjectId) -or
        ($indexValue -isnot [int32] -and $indexValue -isnot [int64]) -or [long]$indexValue -lt 0 -or
        [long]$indexValue -gt [int]::MaxValue) {
        throw 'Visible room action has no stable selected-object identity and integral row index.'
    }
    $identityKey = ''
    $identityValue = ''
    foreach ($candidateKey in @('id', 'action', 'action_id', 'emit_object_id', 'label')) {
        $candidateValue = Get-Value $Row @($candidateKey) $null
        if ($candidateValue -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$candidateValue)) {
            $identityKey = $candidateKey
            $identityValue = [string]$candidateValue
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($identityValue)) {
        throw 'Visible room action has no stable public action id or label.'
    }
    $null = Assert-ExactRenderedRoomActionBinding `
        -Rows @(Get-RoomActions) `
        -SelectedObjectId ([string]$selectedObjectId) `
        -Index ([int]$indexValue) `
        -IdentityKey $identityKey `
        -IdentityValue $identityValue
    $objectToken = ConvertTo-BridgeBase64Token -Value ([string]$selectedObjectId)
    $identityToken = ConvertTo-BridgeBase64Token -Value $identityValue
    return Invoke-BridgeCommand `
        -Command "click_action room $([int]$indexValue) $objectToken $identityKey $identityToken" `
        -Intent $Intent
}


function Select-EventObject {
    param([Parameter(Mandatory = $true)][string]$EventId)
    $semanticId = "event:$EventId"
    if ($null -ceq (Find-CanvasObject -SemanticId $semanticId)) {
        throw "Required player-facing event object is not visible: $EventId"
    }
    $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent "focus the visible $EventId event"
}


function Invoke-EventObjectChoice {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$ChoiceId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    Select-EventObject -EventId $EventId
    if ($ChoiceId -cin @(Get-VisibleChoiceIds)) {
        $null = Choose-VisibleChoice -ChoiceId $ChoiceId -Intent $Intent
        Wait-Frames -Frames 10
        return
    }
    $row = Get-EventChoiceRoomAction -EventId $EventId -ChoiceId $ChoiceId
    if ($null -cne $row) {
        $null = Invoke-RoomActionRow -Row $row -Intent $Intent
        Wait-Frames -Frames 10
        if ($ChoiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $ChoiceId -Intent $Intent
            Wait-Frames -Frames 10
        }
        return
    }
    $opening = @(Get-RoomActions | Where-Object {
        [bool](Get-Value $_ @('enabled') $false) -and
        [string](Get-Value $_ @('label') '') -cin @('Open', 'Talk', 'Answer', 'Respond', 'Inspect', 'Approach')
    })
    if ($opening.Count -ceq 0 -and @(Get-RoomActions).Count -ceq 1) {
        $opening = @(Get-RoomActions)
    }
    if ($opening.Count -cne 1) {
        $labels = @(Get-RoomActions | ForEach-Object { [string](Get-Value $_ @('label') '') }) -join ', '
        throw "Event '$EventId' does not expose the requested '$ChoiceId' response or one opening action. Visible actions: $labels"
    }
    $null = Invoke-RoomActionRow -Row $opening[0] -Intent "open the visible $EventId choice surface"
    Wait-Frames -Frames 8
    $null = Choose-VisibleChoice -ChoiceId $ChoiceId -Intent $Intent
    Wait-Frames -Frames 10
}


function Test-EventObjectChoiceEnabled {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$ChoiceId
    )
    Select-EventObject -EventId $EventId
    $row = Get-EventChoiceRoomAction -EventId $EventId -ChoiceId $ChoiceId
    if ($null -cne $row) {
        return [bool](Get-Value $row @('enabled') $false)
    }
    $eventChoices = @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))
    foreach ($choice in $eventChoices) {
        if ([string](Get-Value $choice @('id') '') -ceq $ChoiceId) {
            return -not [bool](Get-Value $choice @('disabled') $false) -and [bool](Get-Value $choice @('enabled') $true)
        }
    }
    return $false
}


function Get-VisibleChoiceIds {
    $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
    if ($eventVisible) {
        return @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choice_ids') @()))
    }
    $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
    if ($talkVisible) {
        return @(Get-Array (Get-Value $script:LastObservation @('talk', 'choice_ids') @()))
    }
    return @()
}


function Get-PublicTalkChoices {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'talk_choices') @()))
}


function Get-VisibleTutorialGuideAcknowledgment {
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    $talkRenderValid = Get-Value $script:LastObservation @('talk', 'render_valid') $null
    if ($talkVisible -isnot [bool] -or -not [bool]$talkVisible -or
        $talkRenderValid -isnot [bool] -or -not [bool]$talkRenderValid) {
        return $null
    }
    $eventId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
    if (-not $eventId.StartsWith('tutorial_guide:', [StringComparison]::Ordinal)) {
        return $null
    }
    $choiceIds = @(Get-VisibleChoiceIds)
    if ($choiceIds.Count -cne 1 -or [string]$choiceIds[0] -cne 'continue') {
        return $null
    }
    $rendered = @(Get-PublicTalkChoices | Where-Object {
        $enabled = Get-Value $_ @('enabled') $null
        [string](Get-Value $_ @('id') '') -ceq 'continue' -and
            $enabled -is [bool] -and [bool]$enabled
    })
    if ($rendered.Count -cne 1) {
        return $null
    }
    return $rendered[0]
}


function Assert-VisibleTalkChoiceConfirmation {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$RenderedTalkChoices,
        [Parameter(Mandatory = $true)][string]$ChoiceId,
        [Parameter(Mandatory = $true)][string]$ExpectedEventId,
        [Parameter(Mandatory = $true)][string]$OriginalLabel
    )
    $eventVisible = Get-Value $Observation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $Observation @('talk', 'visible') $null
    $talkRenderValid = Get-Value $Observation @('talk', 'render_valid') $null
    $eventId = Get-Value $Observation @('talk', 'event_id') $null
    if ($eventVisible -isnot [bool] -or [bool]$eventVisible -or
        $talkVisible -isnot [bool] -or -not [bool]$talkVisible -or
        $talkRenderValid -isnot [bool] -or -not [bool]$talkRenderValid -or
        $eventId -isnot [string] -or [string]$eventId -cne $ExpectedEventId) {
        throw "Choice '$ChoiceId' crossed to another rendered modal instead of arming in place."
    }
    $matches = @($RenderedTalkChoices | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq $ChoiceId
    })
    if ($matches.Count -cne 1) {
        throw "Choice '$ChoiceId' did not retain one exact rendered TalkDock binding while arming."
    }
    $enabled = Get-Value $matches[0] @('enabled') $null
    $label = Get-Value $matches[0] @('label') $null
    $expectedConfirmLabel = "Confirm: $OriginalLabel"
    if ($enabled -isnot [bool] -or -not [bool]$enabled -or
        $label -isnot [string] -or [string]$label -cne $expectedConfirmLabel) {
        throw "Choice '$ChoiceId' remained visible without the exact confirmation label '$expectedConfirmLabel'."
    }
    return $true
}


function Choose-VisibleChoice {
    param(
        [Parameter(Mandatory = $true)][string]$ChoiceId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $choices = @(Get-VisibleChoiceIds)
    if ($ChoiceId -cnotin $choices) {
        throw "Required player-facing choice '$ChoiceId' is not visible. Visible: $($choices -join ', ')"
    }
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool] -or ([bool]$eventVisible -ceq [bool]$talkVisible)) {
        throw "Choice '$ChoiceId' does not belong to exactly one rendered choice surface."
    }
    $surface = if ([bool]$eventVisible) { 'event_popup' } else { 'talk' }
    $eventId = [string](Get-Value $script:LastObservation @($surface, 'event_id') '')
    if ([string]::IsNullOrWhiteSpace($eventId)) {
        throw "Choice '$ChoiceId' has no exact rendered event binding."
    }
    $renderedChoices = if ($surface -ceq 'talk') {
        @(Get-PublicTalkChoices)
    }
    else {
        @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))
    }
    $matches = @($renderedChoices | Where-Object { [string](Get-Value $_ @('id') '') -ceq $ChoiceId })
    if ($matches.Count -cne 1) {
        throw "Visible $surface choice '$ChoiceId' has no unique rendered button binding."
    }
    $enabled = Get-Value $matches[0] @('enabled') $null
    if ($enabled -isnot [bool] -or -not [bool]$enabled) {
        throw "Visible $surface choice '$ChoiceId' is disabled or clipped."
    }
    $label = [string](Get-Value $matches[0] @('label') '')
    if ([string]::IsNullOrWhiteSpace($label)) { throw "Choice '$ChoiceId' has no rendered label." }
    $result = Invoke-BridgeCommand -Command "click_choice $ChoiceId" -Intent $Intent

    # TalkDock visibly arms consequential choices on the first press by changing
    # the rendered label to "Confirm: ...". Follow that production two-press
    # interaction only when the same choice remains visible and exactly one
    # confirmation control is now on screen.
    if ($surface -ceq 'talk' -and @(Get-VisibleChoiceIds) -ccontains $ChoiceId) {
        $null = Assert-VisibleTalkChoiceConfirmation `
            -Observation $script:LastObservation `
            -RenderedTalkChoices @(Get-PublicTalkChoices) `
            -ChoiceId $ChoiceId `
            -ExpectedEventId $eventId `
            -OriginalLabel $label
        $result = Invoke-BridgeCommand -Command "click_choice $ChoiceId" -Intent "$Intent (confirm the visibly armed choice)"
    }
    return $result
}


function Get-GameActions {
    return @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'game_surface_actions') @()))
}


function Find-GameAction {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [int]$Index = [int]::MinValue
    )
    $matches = @(Get-GameActions | Where-Object {
        [string](Get-Value $_ @('action') '') -ceq $Action -and
        [bool](Get-Value $_ @('enabled') $false) -and
        ($Index -ceq [int]::MinValue -or [int](Get-Value $_ @('index') 0) -ceq $Index)
    })
    if ($matches.Count -ceq 0) { return $null }
    if ($Index -ceq [int]::MinValue -and $matches.Count -gt 1) {
        return $matches | Sort-Object { [int](Get-Value $_ @('index') 0) } | Select-Object -First 1
    }
    if ($matches.Count -gt 1) {
        throw "Game action '$Action' index $Index is ambiguous."
    }
    return $matches[0]
}


function Invoke-GameAction {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][string]$Intent,
        [int]$Index = [int]::MinValue
    )
    $row = Find-GameAction -Action $Action -Index $Index
    if ($null -ceq $row) {
        throw "Required enabled game action is not visible: $Action"
    }
    $resolvedIndex = [int](Get-Value $row @('index') 0)
    return Invoke-BridgeCommand -Command "click_action $Action $resolvedIndex" -Intent $Intent
}


function Wait-Frames {
    param(
        [ValidateRange(1, 3600)][int]$Frames = 30,
        [string]$Intent = 'wait for the visible presentation to settle'
    )
    $null = Invoke-BridgeCommand -Command "wait $Frames" -Intent $Intent -ObservationOnly
}


function Clear-VisibleCoach {
    for ($attempt = 0; $attempt -lt 4; $attempt++) {
        $coachVisible = [bool](Get-Value $script:LastResult @('look', 'coach', 'visible') $false)
        if (-not $coachVisible) { return }
        $tutorialAcknowledgment = Get-VisibleTutorialGuideAcknowledgment
        if ($null -cne $tutorialAcknowledgment) {
            $label = [string](Get-Value $tutorialAcknowledgment @('label') 'Continue')
            $null = Choose-VisibleChoice -ChoiceId 'continue' -Intent "follow Pal's visible tutorial guidance: $label"
            Wait-Frames -Frames 8
            continue
        }
        $dismissLabel = [string](Get-Value $script:LastResult @('look', 'coach', 'dismiss_label') '')
        $button = $null
        if (-not [string]::IsNullOrWhiteSpace($dismissLabel)) {
            $button = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text $dismissLabel
        }
        if ($null -ceq $button) {
            $button = Select-UniqueFullyVisibleButton -Buttons @(Get-Buttons) -Text 'Skip tip'
        }
        if ($null -ceq $button) {
            throw "A visible coach card blocks the route without a fully visible public dismiss control."
        }
        $id = [string](Get-Value $button @('id') '')
        $null = Invoke-BridgeCommand -Command "click_button $id" -Intent 'dismiss the visible guidance card'
        Wait-Frames -Frames 8
    }
    if ([bool](Get-Value $script:LastResult @('look', 'coach', 'visible') $false)) {
        throw "The visible coach card did not clear after four player dismissals."
    }
}


function Start-NormalSeededRun {
    $screen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    if ($screen -cne 'START') {
        throw "A fresh isolated profile did not open on the start screen."
    }

    $primary = [string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '')
    if ($primary -ceq 'CONTINUE') {
        throw "The qualifying session is not fresh; CONTINUE was already present."
    }
    if ($primary -cne 'PLAY') {
        throw "The fresh start screen did not expose PLAY. Found '$primary'."
    }

    $null = Click-Button -Text 'PLAY' -Intent 'start the mandatory first-night lesson on the fresh profile'
    Wait-Frames -Frames 30
    $lessonScreen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    $lessonHasRun = Get-Value $script:LastObservation @('screen', 'has_run') $null
    if ($lessonHasRun -isnot [bool] -or -not [bool]$lessonHasRun -or
        $lessonScreen -cin @('START', 'VICTORY', 'FAILURE')) {
        throw "PLAY did not visibly enter a live first-night lesson (screen='$lessonScreen', has_run=$lessonHasRun)."
    }
    Clear-VisibleCoach

    $null = Click-Button -Text 'Menu' -Intent 'open the run menu to use the player-facing lesson skip'
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'run_menu_visible') $false)) {
        throw 'The live first-night lesson did not render its run menu.'
    }
    $null = Click-RunMenuButton -Text 'Skip Lessons' -RevealDirection down -Intent 'request the player-facing lesson skip'
    $null = Click-TutorialConfirmationButton -Role ok -Intent 'confirm the lesson skip and return to the main menu'
    Wait-Frames -Frames 30

    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START' -or
        [bool](Get-Value $script:LastObservation @('screen', 'has_run') $true)) {
        throw "Skipping the mandatory lesson did not return to the start screen."
    }
    $postSkipPrimary = [string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '')
    if ($postSkipPrimary -ceq 'CONTINUE' -or $postSkipPrimary -cne 'PLAY') {
        throw "Lesson skip returned an unsafe start-menu primary action '$postSkipPrimary'."
    }
    $null = Click-Button -Text 'RUN SETUP' -Intent 'open the visible seeded-run setup' -Contains
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'start_menu', 'run_config_visible') $false)) {
        throw 'RUN SETUP did not render the seeded-run configuration panel.'
    }
    $null = Invoke-BridgeCommand -Command "set_field seed $Seed" -Intent "type route seed $Seed into the visible seed field"
    $visibleSeed = [string](Get-Value $script:LastObservation @('screen', 'start_menu', 'seed_text') '')
    if ($visibleSeed -cne $Seed) {
        throw "The semantic seed entry was not preserved as exact visible public evidence (found '$visibleSeed')."
    }
    $null = Click-Button -Text 'START NEW RUN' -Intent 'start the normal seeded run through the visible setup'
    Wait-Frames -Frames 45
    Clear-VisibleCoach

    $seededHasRun = Get-Value $script:LastObservation @('screen', 'has_run') $null
    if ($seededHasRun -isnot [bool] -or -not [bool]$seededHasRun) {
        throw "START NEW RUN did not produce a live run."
    }
    $seededScreen = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    if ($seededScreen -cin @('START', 'VICTORY', 'FAILURE')) {
        throw "The seeded run opened an invalid visible screen '$seededScreen'."
    }
}


function Wait-ForTravelToSettle {
    for ($attempt = 0; $attempt -lt 16; $attempt++) {
        if (-not [bool](Get-Value $script:LastObservation @('screen', 'travel_transition_active') $false)) {
            return
        }
        Wait-Frames -Frames 30
    }
    throw "The visible travel transition did not settle."
}


function Reveal-WorldMapLeaveByPublicRefocus {
    $objects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $leaveMatches = @($objects | Where-Object {
        $id = Get-Value $_ @('semantic_id') $null
        $id -is [string] -and [string]$id -ceq 'travel:leave'
    })
    if ($leaveMatches.Count -cne 1) {
        throw 'The room does not expose one exact public Leave object.'
    }
    $leaveEnabled = Get-Value $leaveMatches[0] @('enabled') $null
    $leaveRendered = Get-Value $leaveMatches[0] @('rendered') $null
    if ($leaveEnabled -isnot [bool] -or $leaveRendered -isnot [bool]) {
        throw 'The public Leave object has no exact enabled/rendered witnesses.'
    }
    if (-not [bool]$leaveEnabled) {
        throw 'The public Leave object is disabled.'
    }
    if ([bool]$leaveRendered) { return }

    $selectedId = [string](Get-Value $script:LastObservation @('environment', 'selected_object_id') '')
    $candidates = @($objects | Where-Object {
        $semanticId = Get-Value $_ @('semantic_id') $null
        $enabled = Get-Value $_ @('enabled') $null
        $rendered = Get-Value $_ @('rendered') $null
        $semanticId -is [string] -and [string]$semanticId -cmatch '^[a-z0-9_.:-]+$' -and
            [string]$semanticId -cne 'travel:leave' -and [string]$semanticId -cne $selectedId -and
            $enabled -is [bool] -and [bool]$enabled -and
            $rendered -is [bool] -and [bool]$rendered
    } | Sort-Object { [string](Get-Value $_ @('semantic_id') '') } -CaseSensitive | Select-Object -First 12)
    foreach ($candidate in $candidates) {
        $semanticId = [string](Get-Value $candidate @('semantic_id') '')
        $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent 'move the visible room focus so its card no longer covers Leave'
        Wait-Frames -Frames 6
        if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
            throw 'A single room-focus click unexpectedly opened a blocking modal while uncovering Leave.'
        }
        $liveLeave = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()) | Where-Object {
            [string](Get-Value $_ @('semantic_id') '') -ceq 'travel:leave'
        })
        if ($liveLeave.Count -cne 1) {
            throw 'The public Leave object changed identity while uncovering it.'
        }
        $liveEnabled = Get-Value $liveLeave[0] @('enabled') $null
        $liveRendered = Get-Value $liveLeave[0] @('rendered') $null
        if ($liveEnabled -isnot [bool] -or $liveRendered -isnot [bool]) {
            throw 'The public Leave object lost its exact witnesses while uncovering it.'
        }
        if ([bool]$liveEnabled -and [bool]$liveRendered) { return }
    }
    throw 'No bounded real room-focus click made the public Leave target fully visible.'
}


function Open-WorldMap {
    if ([bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        return
    }
    Clear-VisibleCoach
    Reveal-WorldMapLeaveByPublicRefocus
    $null = Open-SemanticObject -SemanticId 'travel:leave' -PreferredActions @('Open Map') -Intent 'open the visible city map'
    Wait-Frames -Frames 8
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        throw "The world map did not become visible."
    }
}


function Get-MapNodes {
    return @(Get-Array (Get-Value $script:LastObservation @('screen', 'world_map', 'nodes') @()))
}


function Find-MapNode {
    param([Parameter(Mandatory = $true)][string]$NodeId)
    foreach ($node in Get-MapNodes) {
        if ([string](Get-Value $node @('id') '') -ceq $NodeId) { return $node }
    }
    return $null
}


function Assert-DeltaQueenBeachRouteInvariant {
    $archetypeId = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
    if ($archetypeId -cne 'delta_queen') { return }
    Open-WorldMap
    try {
        $null = Assert-DeltaQueenBeachPublicRoute -ArchetypeId $archetypeId -MapNodes @(Get-MapNodes)
    }
    finally {
        Close-WorldMap
    }
}


function Travel-ToNode {
    param(
        [Parameter(Mandatory = $true)][string]$NodeId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    Open-WorldMap
    $node = Find-MapNode -NodeId $NodeId
    if ($null -ceq $node) {
        throw "World-map destination is not player-visible: $NodeId"
    }
    if (-not [bool](Get-Value $node @('travel_enabled') $false)) {
        $reason = [string](Get-Value $node @('travel_disabled_reason') 'route unavailable')
        throw "World-map destination '$NodeId' is not travel-enabled: $reason"
    }
    $null = Invoke-BridgeCommand -Command "click_map $NodeId" -Intent "select $NodeId on the visible city map"
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'world_map_confirm_enabled') $false)) {
        throw "Selecting '$NodeId' did not enable the visible Travel control."
    }
    $null = Click-Button -Text 'Travel' -Intent $Intent
    Wait-ForTravelToSettle
    Wait-Frames -Frames 12
    $arrived = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
    if ($arrived -cne $NodeId) {
        throw "Travel to '$NodeId' resolved at '$arrived'."
    }
    Clear-VisibleCoach
    Assert-DeltaQueenBeachRouteInvariant
}


function Close-WorldMap {
    if (-not [bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) { return }
    $null = Click-Button -Text 'Close' -Intent 'close the visible city map'
    Wait-Frames -Frames 6
    if ([bool](Get-Value $script:LastObservation @('screen', 'world_map_overlay_visible') $false)) {
        throw 'The visible city map did not close.'
    }
}


function Get-MapEdges {
    return @(Get-Array (Get-Value $script:LastObservation @('screen', 'world_map', 'edges') @()))
}


function Get-PublicGraphDistance {
    param(
        [Parameter(Mandatory = $true)][string]$From,
        [Parameter(Mandatory = $true)][string]$To
    )
    if ($From -ceq $To) { return 0 }
    $adjacency = @{}
    foreach ($edge in Get-MapEdges) {
        if (-not [bool](Get-Value $edge @('enabled') $true)) { continue }
        $a = [string](Get-Value $edge @('a') '')
        $b = [string](Get-Value $edge @('b') '')
        if ([string]::IsNullOrWhiteSpace($a) -or [string]::IsNullOrWhiteSpace($b)) { continue }
        if (-not $adjacency.ContainsKey($a)) { $adjacency[$a] = @() }
        if (-not $adjacency.ContainsKey($b)) { $adjacency[$b] = @() }
        $adjacency[$a] = @($adjacency[$a]) + $b
        $adjacency[$b] = @($adjacency[$b]) + $a
    }
    $queue = New-Object 'System.Collections.Generic.Queue[object]'
    $queue.Enqueue(@($From, 0))
    $seen = @{$From = $true}
    while ($queue.Count -gt 0) {
        $entry = @($queue.Dequeue())
        $node = [string]$entry[0]
        $distance = [int]$entry[1]
        foreach ($neighborValue in @($adjacency[$node])) {
            $neighbor = [string]$neighborValue
            if ($neighbor -ceq $To) { return $distance + 1 }
            if ($seen.ContainsKey($neighbor)) { continue }
            $seen[$neighbor] = $true
            $queue.Enqueue(@($neighbor, $distance + 1))
        }
    }
    return [int]::MaxValue
}


function Navigate-ToNode {
    param(
        [Parameter(Mandatory = $true)][string]$NodeId,
        [Parameter(Mandatory = $true)][string]$Intent,
        [ValidateRange(1, 24)][int]$MaxLegs = 14
    )
    for ($leg = 0; $leg -lt $MaxLegs; $leg++) {
        $current = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        if ($current -ceq $NodeId) { return }
        Open-WorldMap
        $target = Find-MapNode -NodeId $NodeId
        if ($null -ceq $target) {
            throw "World-map destination is not player-visible: $NodeId"
        }
        if ([bool](Get-Value $target @('travel_enabled') $false)) {
            Travel-ToNode -NodeId $NodeId -Intent $Intent
            continue
        }
        $enabled = @(Get-MapNodes | Where-Object {
            [bool](Get-Value $_ @('travel_enabled') $false) -and
            [string](Get-Value $_ @('id') '') -cne $current
        })
        if ($enabled.Count -ceq 0) {
            $reason = [string](Get-Value $target @('travel_disabled_reason') 'no public route is enabled')
            throw "No visible next map leg can reach '$NodeId': $reason"
        }
        $ranked = @($enabled | ForEach-Object {
            $candidateId = [string](Get-Value $_ @('id') '')
            [pscustomobject]@{
                node = $_
                distance = Get-PublicGraphDistance -From $candidateId -To $NodeId
                cost = [int](Get-Value $_ @('cost') 0)
                id = $candidateId
            }
        } | Sort-Object distance, cost, id)
        if ($ranked.Count -ceq 0 -or [int]$ranked[0].distance -ceq [int]::MaxValue) {
            throw "The public map graph has no visible path from '$current' to '$NodeId'."
        }
        $nextId = [string]$ranked[0].id
        Travel-ToNode -NodeId $nextId -Intent "$Intent (public route leg $($leg + 1) via $nextId)"
    }
    throw "The public map route did not reach '$NodeId' within $MaxLegs legs."
}


function Get-DeliveryTargetNodeId {
    Open-WorldMap
    $targets = @(Get-MapNodes | Where-Object {
        [bool](Get-Value $_ @('delivery_target') $false) -and
        [string](Get-Value $_ @('delivery_target_status') 'pending') -cne 'delivered'
    })
    $targetId = ''
    if ($targets.Count -gt 1) {
        Close-WorldMap
        throw 'The public delivery overlay exposed more than one active target for a single-stop route.'
    }
    if ($targets.Count -ceq 1) {
        $targetId = [string](Get-Value $targets[0] @('id') '')
    }
    Close-WorldMap
    return $targetId
}


function Get-FirstEnabledVisibleChoiceId {
    $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
    if ($eventVisible) {
        $choices = @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))
        foreach ($preferred in @('continue', 'acknowledge', 'move_on', 'keep_moving', 'leave', 'pocket', 'done')) {
            foreach ($choice in $choices) {
                $id = [string](Get-Value $choice @('id') '')
                $enabledProperty = $choice.PSObject.Properties['enabled']
                $enabled = -not [bool](Get-Value $choice @('disabled') $false) -and
                    ($null -ceq $enabledProperty -or [bool]$enabledProperty.Value)
                if ($enabled -and $id -ceq $preferred) { return $id }
            }
        }
        foreach ($choice in $choices) {
            $id = [string](Get-Value $choice @('id') '')
            $enabledProperty = $choice.PSObject.Properties['enabled']
            $enabled = -not [bool](Get-Value $choice @('disabled') $false) -and
                ($null -ceq $enabledProperty -or [bool]$enabledProperty.Value)
            if ($enabled -and -not [string]::IsNullOrWhiteSpace($id)) { return $id }
        }
        return ''
    }
    $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
    if ($talkVisible) {
        $choices = @(Get-PublicTalkChoices | Where-Object {
            [bool](Get-Value $_ @('enabled') $false) -and
            -not [string]::IsNullOrWhiteSpace([string](Get-Value $_ @('id') ''))
        })
        foreach ($preferred in @('continue', 'acknowledge', 'move_on', 'keep_moving', 'leave', 'done')) {
            if (@($choices | Where-Object { [string](Get-Value $_ @('id') '') -ceq $preferred }).Count -ceq 1) {
                return $preferred
            }
        }
        if ($choices.Count -gt 0) { return [string](Get-Value $choices[0] @('id') '') }
    }
    return ''
}


function Resolve-VisibleBlockingPresentation {
    param([Parameter(Mandatory = $true)][string]$Context)
    :presentation for ($attempt = 0; $attempt -lt 12; $attempt++) {
        Clear-VisibleCoach
        $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
        $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
        if (-not $eventVisible -and -not $talkVisible) { return }

        $choiceId = Get-FirstEnabledVisibleChoiceId
        if (-not [string]::IsNullOrWhiteSpace($choiceId)) {
            $surfaceId = if ($eventVisible) {
                [string](Get-Value $script:LastObservation @('event_popup', 'event_id') 'event')
            }
            else {
                [string](Get-Value $script:LastObservation @('talk', 'event_id') 'talk')
            }
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent "$Context`: resolve the visible $surfaceId beat with $choiceId"
            Wait-Frames -Frames 10
            continue
        }

        # Presentation-only cards and item toasts can own the overlay briefly
        # without publishing a choice. A player can only wait for that rendered
        # window or use its explicit close control.
        foreach ($label in @('Close', 'Back', 'OK')) {
            if ($null -cne (Find-Button -Text $label)) {
                $null = Click-Button -Text $label -Intent "$Context`: close the visible presentation card"
                Wait-Frames -Frames 8
                continue presentation
            }
        }
        Wait-Frames -Frames 210 -Intent "$Context`: wait for the visible presentation-only beat"
        if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
            throw "$Context is blocked by a visible choice surface with no enabled public response."
        }
        return
    }
    throw "$Context did not clear its visible blocking presentation within twelve public responses."
}


function Complete-PublicDelivery {
    param(
        [Parameter(Mandatory = $true)][string]$Intent,
        [ValidateSet('', 'main', 'cage')][string]$GrandRoom = ''
    )
    Wait-Frames -Frames 8
    Resolve-VisibleBlockingPresentation -Context $Intent
    $pickup = Find-CanvasObjectByPrefix -Prefix 'delivery:pickup:'
    if ($null -cne $pickup) {
        $pickupId = [string](Get-Value $pickup @('semantic_id') '')
        $null = Open-SemanticObject -SemanticId $pickupId -Intent "${Intent}: take the visible package"
        Wait-Frames -Frames 10
    }

    $targetSeen = $false
    for ($step = 0; $step -lt 24; $step++) {
        if (Test-PublicTerminalSurface) { return }
        Resolve-VisibleBlockingPresentation -Context $Intent
        $targetId = Get-DeliveryTargetNodeId
        if ([string]::IsNullOrWhiteSpace($targetId)) {
            if ($targetSeen) { return }
            throw "$Intent exposed no active target on the player-visible map."
        }
        $targetSeen = $true

        $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        if ($currentNodeId -cne $targetId) {
            Navigate-ToNode -NodeId $targetId -Intent "${Intent}: follow the marked real-map route"
            Wait-Frames -Frames 10
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($GrandRoom) -and $targetId -ceq 'grand_casino') {
            Enter-GrandRoom -Room $GrandRoom
            Resolve-VisibleBlockingPresentation -Context $Intent
        }

        $handoff = Find-CanvasObjectByPrefix -Prefix 'delivery:handoff:'
        if ($null -ceq $handoff) {
            $handoff = Find-CanvasObject -SemanticId 'crew::package_handoff'
        }
        if ($null -cne $handoff) {
            $handoffId = [string](Get-Value $handoff @('semantic_id') '')
            $null = Open-SemanticObject -SemanticId $handoffId -Intent "${Intent}: make the visible handoff"
            Wait-Frames -Frames 12
            Resolve-VisibleBlockingPresentation -Context $Intent
            $remainingTarget = Get-DeliveryTargetNodeId
            if ([string]::IsNullOrWhiteSpace($remainingTarget)) { return }
            if ($remainingTarget -ceq $targetId -and
                ($null -cne (Find-CanvasObjectByPrefix -Prefix 'delivery:handoff:') -or
                 $null -cne (Find-CanvasObject -SemanticId 'crew::package_handoff'))) {
                throw "$Intent left the same visible handoff and map marker active after the handoff click."
            }
            continue
        }
        if ($null -cne (Find-Button -Text 'Hold Sightline')) {
            $null = Click-Button -Text 'Hold Sightline' -Intent "${Intent}: hold the marked sightline"
            Wait-Frames -Frames 8
            continue
        }
        if ($null -cne (Find-Button -Text 'Send Signal')) {
            $null = Click-Button -Text 'Send Signal' -Intent "${Intent}: send the visible route signal"
            Wait-Frames -Frames 8
            continue
        }

        # The Punchline map node opens on its exterior. Its marked contact is a
        # real person inside the casino, so follow the visible room door before
        # declaring the handoff missing.
        if ($null -cne (Find-CanvasObject -SemanticId 'environment_layer:casino')) {
            $null = Open-SemanticObject -SemanticId 'environment_layer:casino' -PreferredActions @('Enter Casino', 'Enter Room', 'Enter', 'Open') -Intent "${Intent}: enter the marked contact's visible casino room"
            Wait-Frames -Frames 12
            continue
        }
        throw "$Intent reached its marked target but exposed no public hold, signal, or handoff action."
    }
    throw "$Intent did not resolve through the visible delivery controls within twenty-four route actions."
}


function Open-EventObject {
    param(
        [Parameter(Mandatory = $true)][string]$EventId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    $null = Open-SemanticObject -SemanticId "event:$EventId" -PreferredActions @('Open', 'Answer', 'Respond', 'Talk', 'Inspect') -Intent $Intent
    Wait-Frames -Frames 8
    if (-not [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -and
        -not [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw "Opening event '$EventId' did not expose a visible choice surface."
    }
}


function Accept-GrandCasinoInviteIfVisible {
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:grand_casino_invite')) { return $false }
    Invoke-EventObjectChoice -EventId 'grand_casino_invite' -ChoiceId 'accept_invite' -Intent 'accept the visible invitation to the Grand Casino'
    Wait-Frames -Frames 15
    return $true
}


function Get-PublicGrandFareRequirement {
    Open-WorldMap
    $grand = @(Get-MapNodes | Where-Object {
        [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
    })
    if ($grand.Count -cne 1) {
        throw "Grand fare recovery requires exactly one player-visible Grand Casino route; found $($grand.Count)."
    }
    $nodeId = Get-Value $grand[0] @('id') $null
    $cost = Get-Value $grand[0] @('cost') $null
    if ($nodeId -isnot [string] -or [string]$nodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'The player-visible Grand Casino route has no stable public node id.'
    }
    if (($cost -isnot [int32] -and $cost -isnot [int64]) -or [long]$cost -lt 0) {
        throw 'The player-visible Grand Casino route has no non-negative integral fare.'
    }
    $requiredCashLong = [long]$cost + [long]$GrandCasinoChipReserve
    if ($requiredCashLong -gt [int]::MaxValue) {
        throw 'The published Grand fare plus chip reserve exceeds the supported public integer range.'
    }
    return [pscustomobject][ordered]@{
        node = $grand[0]
        node_id = [string]$nodeId
        fare = [int]$cost
        required_cash = [int]$requiredCashLong
    }
}


function Restore-EnvironmentSurfaceAfterTravelResult {
    $screen = Get-Value $script:LastObservation @('screen', 'screen') $null
    if ($screen -isnot [string]) {
        throw 'Grand fare recovery lost its exact public screen identity.'
    }
    if ([string]$screen -ceq 'ENVIRONMENT') { return }
    if ([string]$screen -cne 'RESULT') {
        throw "Grand fare recovery cannot normalize unexpected public screen '$screen'."
    }

    # Travel leaves an informational Result state layered over the destination
    # room. Some room-action rows can be geometrically covered by that panel.
    # A real player can open and close the map to return to the ordinary room
    # surface without changing simulation state, so do the same through public
    # controls before clicking a lender or cash-event action.
    Open-WorldMap
    Close-WorldMap
    $restoredScreen = Get-Value $script:LastObservation @('screen', 'screen') $null
    if ($restoredScreen -isnot [string] -or [string]$restoredScreen -cne 'ENVIRONMENT') {
        throw 'The public map round trip did not restore the ordinary room surface after travel.'
    }
}


function Wait-ForFullyRenderedFundingTalk {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedEventId,
        [ValidateRange(1, 64)][int]$MaximumPolls = 48,
        [ValidateRange(1, 16)][int]$MaximumOpenPolls = 6
    )

    $talkOpened = $false
    for ($poll = 0; $poll -lt $MaximumPolls; $poll++) {
        $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
        $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
        if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
            throw 'Funding wait lost its boolean public modal visibility signals.'
        }
        if ([bool]$eventVisible) {
            throw 'Funding wait encountered an unrelated visible event popup.'
        }
        if ([bool]$talkVisible) {
            $talkOpened = $true
            $eventId = Get-Value $script:LastObservation @('talk', 'event_id') $null
            if ($eventId -isnot [string] -or [string]$eventId -cne $ExpectedEventId) {
                throw "Funding wait opened unexpected TalkDock '$eventId'."
            }
            $choiceIds = @(Get-Array (Get-Value $script:LastObservation @('talk', 'choice_ids') @()))
            if ($choiceIds.Count -cne 2 -or $choiceIds[0] -isnot [string] -or [string]$choiceIds[0] -cne 'accept' -or
                $choiceIds[1] -isnot [string] -or [string]$choiceIds[1] -cne 'decline') {
                throw 'Funding wait observed a changed or unauthenticated TalkDock choice set.'
            }
            $expanded = Get-Value $script:LastObservation @('talk', 'expanded') $null
            $renderValid = Get-Value $script:LastObservation @('talk', 'render_valid') $null
            $bodyComplete = Get-Value $script:LastObservation @('talk', 'body_complete') $null
            $typewriterActive = Get-Value $script:LastObservation @('talk', 'typewriter_active') $null
            if ($renderValid -is [bool] -and [bool]$renderValid -and
                $expanded -is [bool] -and [bool]$expanded -and
                $bodyComplete -is [bool] -and [bool]$bodyComplete -and
                $typewriterActive -is [bool] -and -not [bool]$typewriterActive) {
                return
            }
        }
        elseif (-not $talkOpened -and $poll + 1 -ge $MaximumOpenPolls) {
            throw "The advertised lender action did not open TalkDock '$ExpectedEventId' within $MaximumOpenPolls bounded public observations."
        }
        Wait-Frames -Frames 4 -Intent 'wait for the visible lender terms to finish rendering'
    }
    throw "Funding TalkDock '$ExpectedEventId' did not become fully rendered within the bounded wait."
}


function Invoke-CleanScoutingCashOpportunity {
    if ($Ending -cne 'clean') { return $false }
    if ($script:GrandFareRecoveryActive) {
        throw 'Clean scouting cash collection cannot overlap Grand fare recovery.'
    }

    # The fixed route naturally passes the Motel before its invitation. Taking
    # a visibly positive cash event while already there avoids paying a second
    # round-trip fare later and keeps the route independent of the 75% family
    # phone event. Reuse the same strict public-result policy as fare recovery.
    $script:GrandFareRecoveryActive = $true
    try {
        return Invoke-GrandFarePublicCashEvent
    }
    finally {
        $script:GrandFareRecoveryActive = $false
    }
}


function Invoke-GrandFarePublicFundingOffer {
    if (-not $script:GrandFareRecoveryActive) {
        throw 'Public lender funding is permitted only inside Grand fare recovery.'
    }
    Restore-EnvironmentSurfaceAfterTravelResult
    Close-WorldMap
    if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
        [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw 'Grand fare funding refuses to act through another visible modal.'
    }

    $canvasObjects = @(Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @()))
    $lenders = @($canvasObjects | Where-Object {
        $semanticProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'semantic_id')
        $semanticProperties.Count -ceq 1 -and $semanticProperties[0].Value -is [string] -and
            ([string]$semanticProperties[0].Value).StartsWith('lender:', [StringComparison]::Ordinal)
    })
    if ($lenders.Count -ceq 0) { return $false }

    $worldNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
    if ($worldNodeId -isnot [string] -or [string]$worldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Grand fare funding cannot bind the visible offer to one public world node.'
    }
    foreach ($lender in $lenders) {
        $semanticId = [string](Get-Value $lender @('semantic_id') '')
        $rendered = Get-Value $lender @('rendered') $null
        $enabled = Get-Value $lender @('enabled') $null
        if ($rendered -isnot [bool] -or $enabled -isnot [bool]) {
            throw "Funding lender object '$semanticId' lost its exact rendered/enabled witnesses."
        }
    }
    $unusedEnabledLenders = @($lenders | Where-Object {
        $semanticId = [string](Get-Value $_ @('semantic_id') '')
        $lenderId = $semanticId.Substring('lender:'.Length)
        $offerKey = "$worldNodeId|$semanticId"
        $rendered = Get-Value $_ @('rendered') $null
        $enabled = Get-Value $_ @('enabled') $null
        $rendered -is [bool] -and [bool]$rendered -and
            $enabled -is [bool] -and [bool]$enabled -and
            -not $script:GrandFareAcceptedOfferKeys.Contains($offerKey) -and
            -not $script:GrandFareAcceptedLenderIds.Contains($lenderId)
    })
    if ($unusedEnabledLenders.Count -ceq 0) {
        return $false
    }
    $objectSelection = Select-GrandFareFundingObject `
        -CanvasObjects $canvasObjects `
        -WorldNodeId ([string]$worldNodeId) `
        -AcceptedOfferKeys @($script:GrandFareAcceptedOfferKeys) `
        -AcceptedLenderIds @($script:GrandFareAcceptedLenderIds)
    $preflightDebtIndicator = Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null
    if (-not (Test-GrandFareFundingPreflight `
        -Selection $objectSelection `
        -DebtIndicator $preflightDebtIndicator `
        -AcceptedLenderIds @($script:GrandFareAcceptedLenderIds))) {
        return $false
    }
    $semanticId = [string]$objectSelection.semantic_id
    $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent 'focus the one visible lender offering Grand fare recovery'

    $selection = Select-GrandFareFundingObjectAction `
        -Selection $objectSelection `
        -RoomActions @(Get-RoomActions)
    $null = Invoke-RoomActionRow `
        -Row $selection.action `
        -Intent "open $($selection.lender_label)'s exact public Grand fare terms"
    $expectedTalkEventId = "lender_conversation:borrow:$($selection.lender_id)"
    Wait-ForFullyRenderedFundingTalk -ExpectedEventId $expectedTalkEventId

    $offer = Select-GrandFareFundingTalkOffer `
        -Selection $selection `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -TalkChoices @(Get-PublicTalkChoices)
    $beforeBankroll = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
    $beforeBankrollRendered = Get-Value $script:LastObservation @('status_hud', 'bankroll_rendered') $null
    if ($beforeBankrollRendered -isnot [bool] -or -not [bool]$beforeBankrollRendered -or
        ($beforeBankroll -isnot [int32] -and $beforeBankroll -isnot [int64])) {
        throw 'Grand fare funding cannot verify the pre-offer fully rendered HUD bankroll.'
    }
    $beforeDebtIndicator = Get-Value $script:LastObservation @('status_hud', 'debt_indicator') $null
    $null = Get-GrandFarePublicDebtCount -DebtIndicator $beforeDebtIndicator -Context 'Pre-acceptance HUD'

    $null = Invoke-BridgeCommand -Command 'click_choice accept' -Intent 'arm the visibly disclosed Grand fare funding offer'
    $null = Assert-GrandFareFundingConfirmation `
        -Offer $offer `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -TalkChoices @(Get-PublicTalkChoices)
    $null = Invoke-BridgeCommand -Command 'click_choice accept' -Intent 'confirm the visibly armed Grand fare funding offer'
    Wait-Frames -Frames 10
    $null = Assert-GrandFareFundingResult `
        -Offer $offer `
        -BeforeBankroll ([int]$beforeBankroll) `
        -BeforeDebtIndicator $beforeDebtIndicator `
        -AfterObservation $script:LastObservation
    $null = $script:GrandFareAcceptedOfferKeys.Add([string]$selection.offer_key)
    $null = $script:GrandFareAcceptedLenderIds.Add([string]$selection.lender_id)
    return $true
}


function Invoke-GrandFarePublicCashEvent {
    if (-not $script:GrandFareRecoveryActive) {
        throw 'Public cash events are permitted only inside Grand fare recovery.'
    }
    Restore-EnvironmentSurfaceAfterTravelResult
    Close-WorldMap
    if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
        [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw 'Grand fare cash recovery refuses to act through another visible modal.'
    }

    $allowedSemanticIds = @(
        'event:back_alley_offer',
        'event:scenario_wedding_overflow_hallway'
    )
    # Do not call this collection $matches: PowerShell variable names are
    # case-insensitive, so the automatic regex variable $Matches would replace
    # it when the public world-node id is validated below.
    $eventObjects = @((Get-Array (Get-Value $script:LastResult @('look', 'clickable', 'canvas_objects') @())) | Where-Object {
        $semanticProperties = @(Get-Rw062ExactPublicPropertyMatches -InputObject $_ -Name 'semantic_id')
        $semanticProperties.Count -ceq 1 -and $semanticProperties[0].Value -is [string] -and
            [string]$semanticProperties[0].Value -cin $allowedSemanticIds
    })
    if ($eventObjects.Count -ceq 0) { return $false }
    if ($eventObjects.Count -cne 1) {
        throw "Grand fare cash recovery found $($eventObjects.Count) allowlisted public event objects instead of one."
    }
    $enabled = Get-Value $eventObjects[0] @('enabled') $null
    if ($enabled -isnot [bool] -or -not [bool]$enabled) {
        throw 'The allowlisted Grand fare cash event is disabled or has no boolean public enabled state.'
    }
    $semanticId = [string](Get-Value $eventObjects[0] @('semantic_id') '')
    $eventId = $semanticId.Substring('event:'.Length)
    $worldNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
    if ($worldNodeId -isnot [string] -or [string]$worldNodeId -cnotmatch '^[a-z0-9_]+$') {
        throw 'Grand fare cash recovery cannot bind the visible event to one public world node.'
    }

    $null = Invoke-BridgeCommand -Command "click_object $semanticId" -Intent "focus the visible $eventId cash recovery event"
    $event = Select-GrandFareCashEventChoice `
        -EventId $eventId `
        -EventObject $eventObjects[0] `
        -RoomActions @(Get-RoomActions) `
        -Talk (Get-Value $script:LastObservation @('talk') $null) `
        -WorldNodeId ([string]$worldNodeId) `
        -ResolvedEventKeys @($script:GrandFareResolvedCashEventKeys)
    $beforeBankroll = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
    $beforeBankrollRendered = Get-Value $script:LastObservation @('status_hud', 'bankroll_rendered') $null
    $beforeHeat = Get-Value $script:LastObservation @('status_hud', 'heat_level') $null
    $beforeHeatRendered = Get-Value $script:LastObservation @('status_hud', 'heat_rendered') $null
    if ($beforeBankrollRendered -isnot [bool] -or -not [bool]$beforeBankrollRendered -or
        $beforeHeatRendered -isnot [bool] -or -not [bool]$beforeHeatRendered -or
        ($beforeBankroll -isnot [int32] -and $beforeBankroll -isnot [int64]) -or
        ($beforeHeat -isnot [int32] -and $beforeHeat -isnot [int64])) {
        throw 'Grand fare cash recovery cannot verify the pre-event fully rendered HUD bankroll and heat.'
    }
    $beforeFeedback = Get-Value $script:LastObservation @('feedback') $null
    if ($null -ceq $beforeFeedback) {
        throw 'Grand fare cash recovery cannot verify the pre-event public feedback surface.'
    }
    # This one rendered room-action click is the complete public interaction:
    # Foundation.activate_event_choice_action selects and confirms the inline
    # choice in its callback. No hidden confirmation or impact metadata is read.
    $null = Invoke-RoomActionRow -Row $event.action -Intent "take the exact visibly described $($event.choice_id) cash response"
    Wait-Frames -Frames 10
    $null = Assert-GrandFareCashEventResult `
        -Event $event `
        -BeforeBankroll ([int]$beforeBankroll) `
        -BeforeHeat ([int]$beforeHeat) `
        -BeforeFeedback $beforeFeedback `
        -AfterObservation $script:LastObservation
    $null = $script:GrandFareResolvedCashEventKeys.Add([string]$event.event_key)
    return $true
}


function Recover-CleanGrandFareAtCurrentStop {
    param([ValidateRange(1, 1000)][int]$RequiredCash)
    if ($Ending -cne 'clean') {
        throw 'Clean Grand fare recovery cannot run for another ending.'
    }
    if ($script:GrandFareRecoveryActive) {
        throw 'Clean Grand fare recovery cannot be nested.'
    }

    # Once the invited Grand card is public, keep the affordability diagnosis
    # anchored to that exact stop. Travelling elsewhere changes the published
    # fare and can spend more than a generated offer returns; Slot play is a
    # lucky outcome, not qualifying deterministic liquidity. Consume only the
    # current room's authenticated lender/event, then either proceed or report
    # the exact public shortfall for rw06_3.
    $script:GrandFareRecoveryActive = $true
    try {
        Close-WorldMap
        $null = Invoke-GrandFarePublicFundingOffer
        $null = Invoke-GrandFarePublicCashEvent
        $requirement = Get-PublicGrandFareRequirement
        $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
        if ($cash -isnot [int32] -and $cash -isnot [int64]) {
            throw 'Clean Grand fare recovery lost its integral public bankroll signal.'
        }
        Close-WorldMap
        if ([int]$cash -ge [int]$requirement.required_cash) { return }
        $shortfall = [int]$requirement.required_cash - [int]$cash
        throw "Clean Grand entry remains unaffordable after deterministic current-stop liquidity: cash=`$$cash, fare=`$$($requirement.fare), chip_reserve=`$$GrandCasinoChipReserve, required=`$$($requirement.required_cash), initial_required=`$$RequiredCash, shortfall=`$$shortfall."
    }
    finally {
        $script:GrandFareRecoveryActive = $false
    }
}


function Get-GrandFareRecoveryNodePreference {
    param([Parameter(Mandatory = $true)][string]$ArchetypeId)
    # Prefer venues whose authored public lender pool is distinct from the
    # Crew-only invitation room. Returning to the Motel can expose a family or
    # friend offer; visiting another Crew-only casino cannot add a second
    # authenticated lender after the Kitty Cat Crew note was accepted.
    if ($ArchetypeId -ceq 'motel') { return 0 }
    if ($ArchetypeId -ceq 'back_alley') { return 1 }
    if ($ArchetypeId -ceq 'corner_store') { return 3 }
    if ($ArchetypeId -ceq 'small_underground_casino') { return 2 }
    if ($ArchetypeId -ceq 'delta_queen') { return 4 }
    if ($ArchetypeId -ceq 'bar') { return 5 }
    if ($ArchetypeId -ceq 'gas_station_casino') { return 6 }
    return 20
}


function Recover-GrandFareThroughPublicFunding {
    param(
        [ValidateRange(1, 1000)][int]$RequiredCash,
        [ValidateRange(1, 12)][int]$MaximumFundingStops = 6
    )
    if ($script:GrandFareRecoveryActive) {
        throw 'Grand fare recovery cannot be nested.'
    }
    $script:GrandFareRecoveryActive = $true
    try {
        $initialRequirement = Get-PublicGrandFareRequirement
        if ([int]$initialRequirement.required_cash -cne $RequiredCash) {
            throw "Grand fare recovery received stale public math: expected `$$RequiredCash, now `$$($initialRequirement.required_cash)."
        }
        Close-WorldMap

        for ($stop = 0; $stop -lt $MaximumFundingStops; $stop++) {
            $currentNodeId = Get-Value $script:LastObservation @('environment', 'world_node_id') $null
            if ($currentNodeId -isnot [string] -or [string]$currentNodeId -cnotmatch '^[a-z0-9_]+$') {
                throw 'Grand fare recovery lost its stable public world-node id.'
            }
            $null = $script:GrandFareRecoveryVisitedNodes.Add([string]$currentNodeId)

            $null = Invoke-GrandFarePublicFundingOffer
            $requirement = Get-PublicGrandFareRequirement
            $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
            if ($cash -isnot [int32] -and $cash -isnot [int64]) {
                throw 'Grand fare recovery lost its integral public bankroll signal.'
            }
            if ([int]$cash -ge [int]$requirement.required_cash) {
                Close-WorldMap
                return
            }
            Close-WorldMap

            $null = Invoke-GrandFarePublicCashEvent
            $requirement = Get-PublicGrandFareRequirement
            $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
            if ($cash -isnot [int32] -and $cash -isnot [int64]) {
                throw 'Grand fare recovery lost its integral public bankroll signal after a cash event.'
            }
            if ([int]$cash -ge [int]$requirement.required_cash) {
                Close-WorldMap
                return
            }

            $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
            $candidates = @(Get-MapNodes | Where-Object {
                $id = [string](Get-Value $_ @('id') '')
                $state = [string](Get-Value $_ @('state') '')
                $archetype = [string](Get-Value $_ @('archetype_id') '')
                $id -cmatch '^[a-z0-9_]+$' -and
                    $id -cne $currentNodeId -and
                    $archetype -cne 'grand_casino' -and
                    $state -cin @('visited', 'revealed') -and
                    [bool](Get-Value $_ @('travel_enabled') $false) -and
                    (-not $script:GrandFareRecoveryVisitedNodes.Contains($id))
            } | Sort-Object `
                @{ Expression = { Get-GrandFareRecoveryNodePreference -ArchetypeId ([string](Get-Value $_ @('archetype_id') '')) } }, `
                @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, `
                @{ Expression = { [string](Get-Value $_ @('id') '') } })
            if ($candidates.Count -ceq 0) {
                Close-WorldMap
                break
            }
            $nextNodeId = [string](Get-Value $candidates[0] @('id') '')
            Travel-ToNode -NodeId $nextNodeId -Intent "visit $nextNodeId for another bounded public Grand fare option"
        }

        $requirement = Get-PublicGrandFareRequirement
        $cash = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
        if ($cash -isnot [int32] -and $cash -isnot [int64]) {
            throw 'Grand fare recovery lost its integral public bankroll before slot fallback.'
        }
        if ([int]$cash -ge [int]$requirement.required_cash) {
            Close-WorldMap
            return
        }
        Close-WorldMap

        if ($null -ceq (Find-CanvasObject -SemanticId 'game:slot')) {
            Open-WorldMap
            $currentNodeId = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
            $slotStops = @(Get-MapNodes | Where-Object {
                $id = [string](Get-Value $_ @('id') '')
                $archetype = [string](Get-Value $_ @('archetype_id') '')
                [bool](Get-Value $_ @('travel_enabled') $false) -and
                    [string](Get-Value $_ @('state') '') -ceq 'visited' -and
                    $id -cne $currentNodeId -and
                    $archetype -cin @('kitty_cat_lounge', 'bar', 'gas_station_casino')
            } | Sort-Object @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
            if ($slotStops.Count -ceq 0) {
                Close-WorldMap
                throw 'Bounded Grand fare recovery exhausted public offers and exposes no visited slot room.'
            }
            $slotNodeId = [string](Get-Value $slotStops[0] @('id') '')
            Travel-ToNode -NodeId $slotNodeId -Intent 'return to the nearest visited public slot for loss-stopped Grand fare fallback'
        }
        $requirement = Get-PublicGrandFareRequirement
        Close-WorldMap
        Earn-GrandFareThroughVisibleSlot -RequiredCash ([int]$requirement.required_cash)
    }
    finally {
        $script:GrandFareRecoveryActive = $false
    }
}


function Enter-VisibleSlotForGrandFare {
    Close-WorldMap
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME') {
        if ([string](Get-Value $script:LastObservation @('game', 'game_id') '') -ceq 'slot') { return }
        Leave-GameSurface
    }
    if ($null -ceq (Find-CanvasObject -SemanticId 'game:slot')) {
        throw 'The invited Grand route is short of cash, but this room exposes no visible slot for bounded fare recovery.'
    }
    $null = Open-SemanticObject -SemanticId 'game:slot' -PreferredActions @('Enter', 'Play') -Intent 'use the visible slot to earn the displayed Grand Casino fare shortfall'
    Wait-Frames -Frames 12
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME' -or
        [string](Get-Value $script:LastObservation @('game', 'game_id') '') -cne 'slot') {
        throw 'The visible slot did not open its public game surface for Grand fare recovery.'
    }
}


function Resolve-GrandFareMachineJamIfVisible {
    $eventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $talkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($eventVisible -isnot [bool] -or $talkVisible -isnot [bool]) {
        throw 'Grand fare recovery requires boolean public modal visibility signals.'
    }
    if (-not [bool]$eventVisible -and -not [bool]$talkVisible) {
        return $false
    }

    $choiceId = Select-GrandFareMachineJamChoice `
        -EventPopup (Get-Value $script:LastObservation @('event_popup') $null) `
        -Talk (Get-Value $script:LastObservation @('talk') $null)
    $null = Choose-VisibleChoice `
        -ChoiceId $choiceId `
        -Intent 'resolve the exact fully rendered machine_jam with its visible de-escalation choice'
    Wait-Frames -Frames 10 -Intent 'wait for the confirmed public machine_jam choice to resolve'

    $postEventVisible = Get-Value $script:LastObservation @('event_popup', 'visible') $null
    $postTalkVisible = Get-Value $script:LastObservation @('talk', 'visible') $null
    if ($postEventVisible -isnot [bool] -or $postTalkVisible -isnot [bool]) {
        throw 'The public modal visibility schema disappeared after the machine_jam confirmation.'
    }
    if ([bool]$postEventVisible -or [bool]$postTalkVisible) {
        throw 'The allowlisted machine_jam modal remained visible or chained into another modal after confirmation.'
    }
    return $true
}


function Wait-ForVisibleSlotActionBoundary {
    for ($step = 0; $step -lt 24; $step++) {
        if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME' -or
            [string](Get-Value $script:LastObservation @('game', 'game_id') '') -cne 'slot') {
            throw 'Grand fare recovery left the visible slot surface unexpectedly.'
        }
        if (Resolve-GrandFareMachineJamIfVisible) {
            continue
        }

        if ($null -cne (Find-GameAction -Action 'slot_handpay_acknowledge')) {
            $null = Invoke-GameAction -Action 'slot_handpay_acknowledge' -Intent 'acknowledge the visible sealed slot payout'
            Wait-Frames -Frames 20
            continue
        }
        $bonusActions = @(Get-GameActions | Where-Object {
            [bool](Get-Value $_ @('enabled') $false) -and
            ([string](Get-Value $_ @('action') '')).StartsWith('slot_bonus_', [StringComparison]::Ordinal)
        } | Sort-Object @{ Expression = { [string](Get-Value $_ @('action') '') } }, @{ Expression = { [int](Get-Value $_ @('index') 0) } })
        if ($bonusActions.Count -gt 0) {
            $bonusAction = [string](Get-Value $bonusActions[0] @('action') '')
            $bonusIndex = [int](Get-Value $bonusActions[0] @('index') 0)
            $null = Invoke-GameAction -Action $bonusAction -Index $bonusIndex -Intent "take the first deterministic visible slot bonus control $bonusAction"
            Wait-Frames -Frames 20
            continue
        }
        if ($null -cne (Find-GameAction -Action 'slot_spin')) { return }
        Wait-Frames -Frames 30 -Intent 'wait for the visible slot result to finish presenting'
    }
    throw 'The visible slot did not return to a legal Spin boundary within twelve seconds.'
}


function Earn-GrandFareThroughVisibleSlot {
    param(
        [ValidateRange(1, 1000)][int]$RequiredCash,
        [ValidateRange(1, 12)][int]$MaximumSpins = 6,
        [ValidateRange(1, 6)][int]$MaximumLosses = 3
    )
    Enter-VisibleSlotForGrandFare
    $startingCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
    $losses = 0
    for ($spin = 0; $spin -lt $MaximumSpins; $spin++) {
        Wait-ForVisibleSlotActionBoundary
        $beforeCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
        if ($beforeCash -ge $RequiredCash) {
            Leave-GameSurface
            return
        }
        if ($null -ceq (Find-GameAction -Action 'slot_spin')) {
            throw "The visible slot exposes no legal Spin while Grand fare recovery is short (`$$beforeCash of `$$RequiredCash)."
        }
        $null = Invoke-GameAction -Action 'slot_spin' -Intent "spin the visible slot at its rendered stake for Grand fare recovery ($($spin + 1)/$MaximumSpins)"
        Wait-Frames -Frames 30 -Intent 'watch the visible slot result begin resolving'
        Wait-ForVisibleSlotActionBoundary
        $afterCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
        if ($afterCash -lt $beforeCash) { $losses++ }
        if ($afterCash -ge $RequiredCash) {
            Leave-GameSurface
            return
        }
        if ($losses -ge $MaximumLosses) {
            Leave-GameSurface
            throw "Grand fare slot fallback loss-stopped after $losses losing spins: start=`$$startingCash, end=`$$afterCash, required=`$$RequiredCash."
        }
    }
    $endingCash = [int](Get-Value $script:LastObservation @('status_hud', 'bankroll') 0)
    Leave-GameSurface
    throw "Grand fare slot fallback exhausted $MaximumSpins spins without reaching the public target: start=`$$startingCash, end=`$$endingCash, required=`$$RequiredCash, losses=$losses."
}


function Reach-GrandCasino {
    $visitedByRunner = New-Object 'System.Collections.Generic.HashSet[string]'
    for ($step = 0; $step -lt 24; $step++) {
        $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
        if ($archetype -cin @('grand_casino', 'grand_casino_cage', 'grand_casino_high_limit')) { return }

        $null = Invoke-CleanScoutingCashOpportunity
        if (Accept-GrandCasinoInviteIfVisible) { continue }
        Open-WorldMap
        $nodes = @(Get-MapNodes)
        $grand = @($nodes | Where-Object {
            [string](Get-Value $_ @('archetype_id') '') -ceq 'grand_casino'
        })
        if ($grand.Count -gt 1) {
            throw "The visible city map exposes more than one Grand Casino route."
        }
        if ($grand.Count -ceq 1) {
            $costValue = Get-Value $grand[0] @('cost') $null
            if (($costValue -isnot [int32] -and $costValue -isnot [int64]) -or [long]$costValue -lt 0) {
                throw 'The visible Grand Casino card has no non-negative integral route fare.'
            }
            $cost = [int]$costValue
            $requiredCashLong = [long]$cost + [long]$GrandCasinoChipReserve
            if ($requiredCashLong -gt [int]::MaxValue) {
                throw 'The visible Grand fare plus chip reserve exceeds the supported public integer range.'
            }
            $requiredCash = [int]$requiredCashLong
            $cashValue = Get-Value $script:LastObservation @('status_hud', 'bankroll') $null
            if ($cashValue -isnot [int32] -and $cashValue -isnot [int64]) {
                throw 'The clean replay cannot verify its public bankroll before Grand travel.'
            }
            $cash = [int]$cashValue
            if ($cash -lt $requiredCash) {
                Close-WorldMap
                if ($Ending -ceq 'clean') {
                    Recover-CleanGrandFareAtCurrentStop -RequiredCash $requiredCash
                }
                else {
                    Recover-GrandFareThroughPublicFunding -RequiredCash $requiredCash
                }
                continue
            }
            if ([bool](Get-Value $grand[0] @('travel_enabled') $false)) {
                Travel-ToNode -NodeId ([string](Get-Value $grand[0] @('id') '')) -Intent 'travel to the Grand Casino through the visible city map with its chip reserve intact'
                continue
            }
            $reason = [string](Get-Value $grand[0] @('travel_disabled_reason') 'The route is unavailable.')
            if ($reason -cmatch 'Not enough bankroll') {
                if ($cost -le $cash) {
                    throw "The Grand card claims insufficient bankroll but publishes cash=$cash and route_cost=$cost."
                }
            }
            throw "The invited Grand Casino route is visible but unavailable: $reason"
        }

        $candidates = @($nodes | Where-Object {
            $id = [string](Get-Value $_ @('id') '')
            $kind = [string](Get-Value $_ @('kind') '')
            $tier = [int](Get-Value $_ @('tier') 0)
            $state = [string](Get-Value $_ @('state') '')
            [bool](Get-Value $_ @('travel_enabled') $false) -and
            $kind -ceq 'casino' -and $id -cne '' -and
            (-not $visitedByRunner.Contains($id)) -and
            ($tier -ge 2 -or $state -cne 'visited')
        } | Sort-Object @{ Expression = { -[int](Get-Value $_ @('tier') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
        if ($candidates.Count -ceq 0) {
            $candidates = @($nodes | Where-Object {
                $id = [string](Get-Value $_ @('id') '')
                [bool](Get-Value $_ @('travel_enabled') $false) -and $id -cne '' -and
                (-not $visitedByRunner.Contains($id))
            } | Sort-Object { [int](Get-Value $_ @('cost') 0) })
        }
        if ($candidates.Count -ceq 0) {
            throw "No visible unvisited route can advance the Grand Casino invitation."
        }
        $target = [string](Get-Value $candidates[0] @('id') '')
        $null = $visitedByRunner.Add($target)
        Travel-ToNode -NodeId $target -Intent "travel to $target to scout a natural route toward the Grand Casino"
    }
    throw "The visible world route did not reach the Grand Casino within 24 travel decisions."
}


function Enter-GrandRoom {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('main', 'cage')][string]$Room
    )
    $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
    if ($Room -ceq 'cage' -and $archetype -ceq 'grand_casino_cage') { return }
    if ($Room -ceq 'main' -and $archetype -ceq 'grand_casino') { return }
    $semantic = if ($Room -ceq 'cage') { 'travel:grand_casino_cage' } else { 'travel:grand_casino' }
    $null = Open-SemanticObject -SemanticId $semantic -PreferredActions @('Enter Room', 'Travel', 'Enter') -Intent "walk through the real Grand Casino door to $Room"
    Wait-ForTravelToSettle
    Wait-Frames -Frames 12
    $expected = if ($Room -ceq 'cage') { 'grand_casino_cage' } else { 'grand_casino' }
    if ([string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -cne $expected) {
        throw "The real Grand Casino door did not reach '$expected'."
    }
}


function Open-CageCounter {
    Enter-GrandRoom -Room cage
    $null = Open-SemanticObject -SemanticId 'casino_fixture:cage_counter' -PreferredActions @('Talk', 'Open', 'Inspect') -Intent 'speak with Linda at the real Cage counter'
    Wait-Frames -Frames 8
    if (-not [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
        throw "Linda's Cage counter did not expose its visible dialogue choices."
    }
}


function Ensure-GrandCasinoChips {
    param([ValidateRange(0, 200)][int]$Minimum = 50)
    $chips = Get-RenderedHudInteger -Name chips -Context 'Grand Casino chip check'
    if ($chips -ge $Minimum) { return }
    Open-CageCounter
    $null = Choose-VisibleChoice -ChoiceId 'open_chips' -Intent 'open Linda''s visible chips and cashout menu'
    $maximumChipPurchases = 8 # 8 x the smallest $25 exchange covers the validated $200 ceiling.
    for ($purchase = 0; $purchase -lt $maximumChipPurchases; $purchase++) {
        $beforeChips = Get-RenderedHudInteger -Name chips -Context 'Pre-purchase Grand Casino chip check'
        if ($beforeChips -ge $Minimum) { break }
        $enabledChoices = @(Get-PublicTalkChoices | Where-Object {
            [bool](Get-Value $_ @('enabled') $false)
        } | ForEach-Object {
            [string](Get-Value $_ @('id') '')
        })
        if ('cage_buy_50' -cin $enabledChoices) {
            $null = Choose-VisibleChoice -ChoiceId 'cage_buy_50' -Intent 'exchange visible cash for 50 Grand Casino chips'
        }
        elseif ('cage_buy_25' -cin $enabledChoices) {
            $null = Choose-VisibleChoice -ChoiceId 'cage_buy_25' -Intent 'exchange visible cash for 25 Grand Casino chips'
        }
        else {
            throw "Linda exposes no affordable chip purchase while the route needs $Minimum chips."
        }
        $afterChips = Get-RenderedHudInteger -Name chips -Context 'Post-purchase Grand Casino chip check'
        if ($afterChips -le $beforeChips) {
            throw "Linda's visible chip exchange made no public chip progress ($beforeChips -> $afterChips)."
        }
    }
    $chips = Get-RenderedHudInteger -Name chips -Context 'Final Grand Casino chip check'
    if ($chips -lt $Minimum) {
        throw "Grand Casino chip exchange did not reach $Minimum within $maximumChipPurchases bounded purchases (found $chips)."
    }
    $null = Choose-VisibleChoice -ChoiceId 'back_main' -Intent 'return to Linda''s main counter choices'
    $null = Choose-VisibleChoice -ChoiceId 'leave_counter' -Intent 'step away from Linda''s counter'
    Wait-Frames -Frames 8
}


function Enter-BlackjackTable {
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME' -and
        [string](Get-Value $script:LastObservation @('game', 'game_id') '') -ceq 'blackjack') {
        # Save -> relaunch -> Continue restores the locked Rourke table directly.
        # Preserve any live Blackjack surface before attempting room navigation.
        return
    }
    Enter-GrandRoom -Room main
    $null = Open-SemanticObject -SemanticId 'game:blackjack' -PreferredActions @('Enter', 'Play') -Intent 'sit at the visible blackjack table'
    Wait-Frames -Frames 12
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME' -or
        [string](Get-Value $script:LastObservation @('game', 'game_id') '') -cne 'blackjack') {
        throw "The visible blackjack table did not open the blackjack surface."
    }
}


function Leave-GameSurface {
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'GAME') { return }
    $back = Find-GameAction -Action 'surface_back'
    if ($null -ceq $back) { $back = Find-GameAction -Action 'leave_game' }
    if ($null -ceq $back) {
        throw "The active game surface exposes no visible leave action."
    }
    $action = [string](Get-Value $back @('action') '')
    $index = [int](Get-Value $back @('index') 0)
    $null = Invoke-BridgeCommand -Command "click_action $action $index" -Intent 'leave the game through its visible back control'
    Wait-Frames -Frames 10
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -ceq 'GAME') {
        throw "The visible game back control did not return to the room."
    }
}


function Get-ActiveBlackjackTotal {
    $activeIndex = [int](Get-Value $script:LastObservation @('game', 'active_hand_index') 0)
    $hands = @(Get-Array (Get-Value $script:LastObservation @('game', 'player_hands') @()))
    if ($activeIndex -lt 0 -or $activeIndex -ge $hands.Count) {
        if ($hands.Count -ceq 1) { return [int](Get-Value $hands[0] @('total') 0) }
        throw "Blackjack decision has no public active player hand."
    }
    return [int](Get-Value $hands[$activeIndex] @('total') 0)
}


function Invoke-PublicBlackjackDecision {
    $total = Get-ActiveBlackjackTotal
    $canHit = [bool](Get-Value $script:LastObservation @('game', 'can_hit') $false)
    $canStand = [bool](Get-Value $script:LastObservation @('game', 'can_stand') $false)
    if ($total -lt 17 -and $canHit -and $null -cne (Find-GameAction -Action 'blackjack_hit')) {
        $null = Invoke-GameAction -Action 'blackjack_hit' -Intent "hit the public $total blackjack hand"
        return
    }
    if ($canStand -and $null -cne (Find-GameAction -Action 'blackjack_stand')) {
        $null = Invoke-GameAction -Action 'blackjack_stand' -Intent "stand on the public $total blackjack hand"
        return
    }
    if ($canHit -and $null -cne (Find-GameAction -Action 'blackjack_hit')) {
        $null = Invoke-GameAction -Action 'blackjack_hit' -Intent "take the only visible legal hit on the public $total hand"
        return
    }
    throw "Blackjack decision phase exposes neither a public hit nor stand."
}


function Invoke-PublicBossCalloutIfShown {
    $tell = [string](Get-Value $script:LastObservation @('game', 'boss_tell') '')
    if ([string]::IsNullOrWhiteSpace($tell)) { return }

    # Rourke renders the tell while the wager is staged, but the matching
    # callout is intentionally disabled until Deal. The public policy therefore
    # validates the tell now and either defers or returns its exact post-deal row.
    $selection = Select-CheatReplayBossCalloutAction `
        -Game (Get-Value $script:LastObservation @('game') $null) `
        -SurfaceActions @(Get-GameActions)
    if ([string]$selection.stage -cne 'call') { return }

    $index = [int]$selection.index
    $label = [string](Get-Value (Get-Array (Get-Value $script:LastObservation @('game', 'boss_callouts') @()))[$index] @('label') '')
    $null = Invoke-GameAction -Action 'blackjack_boss_callout' -Index $index -Intent "call Rourke's publicly rendered $tell tell with $label"
    Wait-Frames -Frames 4
    $used = Get-Value $script:LastObservation @('game', 'boss_callout_used') $null
    if ($used -isnot [bool] -or -not [bool]$used) {
        throw "Rourke's rendered callout did not produce an exact public used witness."
    }
}


function Invoke-VisibleCheatIfAvailable {
    $openedWindow = $false
    for ($transition = 0; $transition -lt 3; $transition++) {
        $selection = Select-CheatReplayBlackjackCheatAction `
            -Game (Get-Value $script:LastObservation @('game') $null) `
            -SurfaceActions @(Get-GameActions)
        switch ([string]$selection.stage) {
            'wait_for_deal' { return $false }
            'complete' { return $false }
            'open_window' {
                if ($openedWindow) {
                    throw 'The rendered Distraction control did not open its public Peek window.'
                }
                $null = Invoke-GameAction -Action 'blackjack_distraction' -Index ([int]$selection.index) -Intent "open the rendered lookaway window for the published peek_hole_card cheat"
                Wait-Frames -Frames 4
                $windowOpen = Get-Value $script:LastObservation @('game', 'peek_window_open') $null
                if ($windowOpen -isnot [bool] -or -not [bool]$windowOpen) {
                    throw 'The rendered Distraction control did not expose an exact open Peek-window witness.'
                }
                $openedWindow = $true
                continue
            }
            'peek' {
                $null = Invoke-GameAction -Action 'blackjack_peek' -Index ([int]$selection.index) -Intent "use the rendered Peek control authorized by published cheat id peek_hole_card"
                Wait-Frames -Frames 4
                $holeVisible = Get-Value $script:LastObservation @('game', 'dealer_hole_visible') $null
                if ($holeVisible -isnot [bool] -or -not [bool]$holeVisible) {
                    throw "The published 'peek_hole_card' cheat did not produce an exact visible-hole-card witness."
                }
                return $true
            }
            default { throw "Unknown public Blackjack cheat-policy stage '$($selection.stage)'." }
        }
    }
    throw "The published 'peek_hole_card' sequence did not finish within three public transitions."
}


function Ensure-BlackjackStakeRange {
    param(
        [ValidateRange(1, 500)][int]$Minimum = 8,
        [ValidateRange(1, 500)][int]$Maximum = 30
    )
    $stake = [int](Get-Value $script:LastObservation @('game', 'selected_stake') 0)
    if ($stake -ge $Minimum -and $stake -le $Maximum) { return }
    if ($stake -gt $Maximum) {
        $clearAction = @('blackjack_clear_bet', 'surface_stake_down') | Where-Object {
            $null -cne (Find-GameAction -Action $_)
        } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace([string]$clearAction)) {
            throw "The visible blackjack stake is $stake, above the heist ceiling $Maximum, and exposes no clear control."
        }
        $null = Invoke-GameAction -Action ([string]$clearAction) -Intent 'clear the visible blackjack wager before setting a boring heist stake'
        Wait-Frames -Frames 6
    }
    for ($chip = 0; $chip -lt 40; $chip++) {
        $stake = [int](Get-Value $script:LastObservation @('game', 'selected_stake') 0)
        if ($stake -ge $Minimum -and $stake -le $Maximum) { return }
        if ($stake -gt $Maximum) {
            throw "The visible blackjack wager jumped above the heist ceiling ($stake > $Maximum)."
        }
        $placeAction = @('blackjack_wager_place_gesture', 'blackjack_chip', 'surface_stake_up') | Where-Object {
            $null -cne (Find-GameAction -Action $_)
        } | Select-Object -First 1
        if ([string]::IsNullOrWhiteSpace([string]$placeAction)) {
            throw "The blackjack surface exposes no production wager control below the heist minimum $Minimum."
        }
        $null = Invoke-GameAction -Action ([string]$placeAction) -Intent 'place one visible blackjack chip for a boring heist stake'
        Wait-Frames -Frames 4
    }
    throw "The visible blackjack wager could not be set inside $Minimum-$Maximum within 40 chip placements."
}


function Play-OneBlackjackRound {
    param(
        [switch]$UseVisibleCheat,
        [switch]$UseHeistStake
    )
    Enter-BlackjackTable
    if ($UseHeistStake) {
        Ensure-BlackjackStakeRange -Minimum 8 -Maximum 30
    }
    $beforeHand = [int](Get-Value $script:LastObservation @('game', 'boss_hand_number') 0)
    $roundStarted = [string](Get-Value $script:LastObservation @('game', 'phase') '') -cne 'betting'

    for ($step = 0; $step -lt 36; $step++) {
        if (Test-PublicTerminalSurface) { return }
        $eventVisible = [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false)
        $talkVisible = [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)
        if ($eventVisible -or $talkVisible) {
            throw "A modal interrupted blackjack; the route must resolve it explicitly. Choices: $((Get-VisibleChoiceIds) -join ', ')"
        }

        $bossHandNow = [int](Get-Value $script:LastObservation @('game', 'boss_hand_number') 0)
        $outcomeNow = [string](Get-Value $script:LastObservation @('game', 'outcome_message') '')
        $phaseNow = [string](Get-Value $script:LastObservation @('game', 'phase') '')
        if (($bossHandNow -gt $beforeHand) -or
            ($roundStarted -and -not [string]::IsNullOrWhiteSpace($outcomeNow) -and $phaseNow -ceq 'betting')) {
            return
        }

        Invoke-PublicBossCalloutIfShown
        $phase = [string](Get-Value $script:LastObservation @('game', 'phase') '')
        $peekApplied = $false
        if ($UseVisibleCheat) {
            $peekApplied = Invoke-VisibleCheatIfAvailable
            if ($peekApplied -isnot [bool]) {
                throw 'Visible Peek did not return an exact public applied-state witness.'
            }
        }
        if ([bool]$peekApplied) {
            $postPeek = Select-CheatReplayPostPeekTransition `
                -Game (Get-Value $script:LastObservation @('game') $null) `
                -StatusHud (Get-Value $script:LastObservation @('status_hud') $null) `
                -SurfaceActions @(Get-GameActions)
            if ([string]$postPeek.stage -ceq 'leave_for_showdown') {
                return
            }
            if ([string]$postPeek.stage -cne 'continue_hand') {
                throw "Unknown public post-Peek transition '$($postPeek.stage)'."
            }
            $phase = [string](Get-Value $script:LastObservation @('game', 'phase') '')
        }
        if ($null -cne (Find-GameAction -Action 'blackjack_settle')) {
            $null = Invoke-GameAction -Action 'blackjack_settle' -Intent 'settle the publicly completed blackjack hand'
            Wait-Frames -Frames 12
            return
        }
        if ($phase -ceq 'decision' -or
            [bool](Get-Value $script:LastObservation @('game', 'can_hit') $false) -or
            [bool](Get-Value $script:LastObservation @('game', 'can_stand') $false)) {
            Invoke-PublicBlackjackDecision
            Wait-Frames -Frames 24
            continue
        }
        if ($null -cne (Find-GameAction -Action 'blackjack_deal')) {
            $null = Invoke-GameAction -Action 'blackjack_deal' -Intent 'deal the next blackjack hand at the visible wager'
			$roundStarted = $true
            Wait-Frames -Frames 30
            continue
        }
        Wait-Frames -Frames 20
    }
    throw "Blackjack did not visibly settle within 36 public decision steps."
}


function Get-PersistenceCheckpoint {
    $hud = Get-Value $script:LastObservation @('status_hud') $null
    $game = Get-Value $script:LastObservation @('game') $null
    return [ordered]@{
        location_id = [string](Get-Value $script:LastObservation @('environment', 'id') '')
        location_archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
        world_node_id = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        bankroll = Get-RenderedHudInteger -Name bankroll -Context 'Persistence checkpoint'
        chips = Get-RenderedHudInteger -Name chips -Context 'Persistence checkpoint'
        heat = Get-RenderedHudInteger -Name heat_level -Context 'Persistence checkpoint'
        game_id = [string](Get-Value $game @('game_id') '')
        game_phase = [string](Get-Value $game @('phase') '')
        boss_hand_number = [int](Get-Value $game @('boss_hand_number') 0)
        boss_player_stack = [int](Get-Value $game @('boss_player_stack') 0)
        boss_rourke_stack = [int](Get-Value $game @('boss_rourke_stack') 0)
    }
}


function Assert-ExplicitSaveAcknowledgmentObservation {
    param(
        [Parameter(Mandatory = $true)]$Observation,
        [Parameter(Mandatory = $true)][string]$Milestone
    )
    $hasSave = Get-Value $Observation @('screen', 'run_menu', 'has_save') $null
    $saveTextVisible = Get-Value $Observation @('status_hud', 'save_text_visible') $null
    $saveText = Get-Value $Observation @('status_hud', 'save_text') $null
    $separator = " $([char]0x00B7) "
    $acknowledgment = 'Saved to Resume Slot.'
    $expectedVisibleText = "Autosave On$separator$acknowledgment"
    if ($hasSave -isnot [bool] -or -not [bool]$hasSave -or
        $saveTextVisible -isnot [bool] -or -not [bool]$saveTextVisible -or
        $saveText -isnot [string] -or [string]$saveText -cne $expectedVisibleText) {
        throw "The explicit Save at $Milestone did not render the exact success acknowledgment '$acknowledgment' (found '$saveText', visible=$saveTextVisible, has_save=$hasSave)."
    }
    return $true
}


function Assert-ExplicitSaveAcknowledged {
    param([Parameter(Mandatory = $true)][string]$Milestone)
    return Assert-ExplicitSaveAcknowledgmentObservation -Observation $script:LastObservation -Milestone $Milestone
}


function Assert-SaveRelaunchContinue {
    param([Parameter(Mandatory = $true)][string]$Milestone)
    $before = Get-PersistenceCheckpoint
    $beforeJson = $before | ConvertTo-Json -Depth 10 -Compress
    $null = Click-Button -Text 'Menu' -Intent "open the run menu at the $Milestone persistence checkpoint"
    $null = Click-RunMenuButton -Text 'Save' -RevealDirection up -Intent "save the run through the visible run menu at $Milestone"
    Assert-ExplicitSaveAcknowledged -Milestone $Milestone
    $null = Click-RunMenuButton -Text 'Main Menu' -RevealDirection down -Intent 'return to the main menu after the explicit save'
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START') {
        throw "Main Menu did not return to the start screen after saving."
    }
    $null = Invoke-BridgeCommand -Command 'quit' -Intent 'quit the saved production host before relaunch' -ObservationOnly
    Wait-ForSessionExit
    Assert-NoPostExitLogAlerts
    Remove-OwnedBridgeCaptureResidue
    Start-BridgeSession
    if ([string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '') -cne 'CONTINUE') {
        throw "Relaunch after $Milestone did not expose CONTINUE."
    }
    $null = Click-Button -Text 'CONTINUE' -Intent "continue the saved $Milestone run after a full relaunch"
    Wait-Frames -Frames 45
    Clear-VisibleCoach
    $after = Get-PersistenceCheckpoint
    $afterJson = $after | ConvertTo-Json -Depth 10 -Compress
    if ($afterJson -cne $beforeJson) {
        $before | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
        $after | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
        throw "Public persistence checkpoint changed across Save -> relaunch -> Continue at $Milestone."
    }
    Assert-DeltaQueenBeachRouteInvariant
    $script:MidpointSaved = $true
}


function Assert-TerminalOutcome {
    $screenName = [string](Get-Value $script:LastObservation @('screen', 'screen') '')
    $runReportVisible = Get-Value $script:LastObservation @('screen', 'run_report_visible') $null
    $outcome = [string](Get-Value $script:LastObservation @('screen', 'run_report', 'outcome', 'key') '')
    $won = Get-Value $script:LastObservation @('screen', 'run_report', 'outcome', 'won') $null
    if ($screenName -cne 'VICTORY' -or $runReportVisible -isnot [bool] -or -not [bool]$runReportVisible) {
        throw "Ending '$Ending' did not render the public VICTORY RunReport surface (screen='$screenName', visible=$runReportVisible)."
    }
    if ($won -isnot [bool] -or -not [bool]$won -or $outcome -cnotin $ExpectedOutcomes[$Ending]) {
        throw "Ending '$Ending' produced unexpected public outcome '$outcome' (won=$won)."
    }
    if (-not $script:MidpointSaved) {
        throw "Ending '$Ending' reached terminal state without the required Save -> relaunch -> Continue checkpoint."
    }
    if ($script:ActionCount -gt 350) {
        throw "Ending '$Ending' exceeded the 350-action normal-route ceiling ($($script:ActionCount))."
    }
    return $outcome
}


function Write-FinalPublicCheckpoint {
    # A terminal wait/look is observation-only and therefore is not written by
    # Write-ActionEvidence. Take one final authenticated public observation and
    # persist its outcome and visible economy explicitly into both hash streams.
    $result = Invoke-BridgeCommand -Command 'look' -Intent 'capture the final public terminal checkpoint' -ObservationOnly
    $outcome = Assert-TerminalOutcome
    $observation = Get-Value $result @('look', 'observable') $null
    $publicFingerprint = [string](Get-Value $result @('trace', 'after_fingerprint') '')
    $checkpointFingerprint = [string](Get-Value $observation @('checkpoint_fingerprint') '')
    $observedSeed = [string](Get-Value $observation @('screen', 'run_report', 'seed') '')
    if ($publicFingerprint -notmatch '^[a-f0-9]{64}$' -or $checkpointFingerprint -notmatch '^[a-f0-9]{64}$') {
        throw 'Final terminal observation did not publish complete authenticated public fingerprints.'
    }
    if ($observedSeed -cne $Seed) {
        throw "Terminal run report seed '$observedSeed' did not exactly match requested fixed seed '$Seed'."
    }
    $final = [ordered]@{
        schema_version = 1
        record_kind = 'final_public_checkpoint'
        observed_seed = $observedSeed
        outcome_key = [string]$outcome
        won = $true
        public_fingerprint = $publicFingerprint
        checkpoint_fingerprint = $checkpointFingerprint
        bankroll = Get-RenderedHudInteger -Name bankroll -Context 'Final terminal checkpoint'
        chips = Get-RenderedHudInteger -Name chips -Context 'Final terminal checkpoint'
        heat = Get-RenderedHudInteger -Name heat_level -Context 'Final terminal checkpoint'
    }
    $finalJson = $final | ConvertTo-Json -Compress
    Add-Content -LiteralPath $script:TranscriptPath -Value $finalJson -Encoding utf8
    Add-Content -LiteralPath $script:MoneyCurvePath -Value $finalJson -Encoding utf8
    $finalPath = Join-Path $script:RunRoot 'final_public_checkpoint.json'
    $final | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $finalPath -Encoding utf8
    return [pscustomobject]$final
}


function Visit-CageAndClaimReadyPlayersCard {
    Leave-GameSurface
    Open-CageCounter
    $null = Choose-VisibleChoice -ChoiceId 'open_card' -Intent "open Linda's visible Players Card review"

    $claimMatches = @(Get-PublicTalkChoices | Where-Object {
        [string](Get-Value $_ @('id') '') -ceq 'cage_claim_card'
    })
    if ($claimMatches.Count -cne 1) {
        throw "Linda's visible Players Card review has no unique claim control."
    }
    $claimEnabled = Get-Value $claimMatches[0] @('enabled') $null
    if ($claimEnabled -isnot [bool]) {
        throw "Linda's visible Players Card claim has no exact enabled witness."
    }
    if (-not [bool]$claimEnabled) {
        $null = Choose-VisibleChoice -ChoiceId 'back_main' -Intent 'return from Linda''s visible card-progress review'
        $null = Choose-VisibleChoice -ChoiceId 'leave_counter' -Intent 'step away from Linda until the visible card claim is ready'
        Wait-Frames -Frames 8
        return ''
    }

    $null = Choose-VisibleChoice -ChoiceId 'cage_claim_card' -Intent "ask Linda to issue the visibly enabled Players Card tier"
    Wait-Frames -Frames 12

    $choices = @(Get-VisibleChoiceIds)
    $recognitionChoices = @($choices | Where-Object {
        @('thank_linda', 'take_silver', 'accept_gold_card') -ccontains [string]$_
    })
    if ($recognitionChoices.Count -cne 1) {
        throw "Players Card claim did not expose exactly one visible tier-recognition choice."
    }
    $recognitionChoice = [string]$recognitionChoices[0]
    if ($recognitionChoice -ceq 'thank_linda') {
        $null = Choose-VisibleChoice -ChoiceId 'thank_linda' -Intent 'accept Linda''s Bronze recognition'
        Wait-Frames -Frames 10
        return 'bronze'
    }
    if ($recognitionChoice -ceq 'take_silver') {
        $null = Choose-VisibleChoice -ChoiceId 'take_silver' -Intent 'accept Linda''s Silver recognition and High Limit access'
        Wait-Frames -Frames 10
        return 'silver'
    }
    if ($recognitionChoice -ceq 'accept_gold_card') {
        $null = Choose-VisibleChoice -ChoiceId 'accept_gold_card' -Intent 'accept the Gold Players Card and clean Grand Casino ending'
        Wait-Frames -Frames 45
        return 'gold'
    }
    throw "Linda exposed unknown Players Card recognition '$recognitionChoice'."
}


function Invoke-CleanEndingRoute {
    Reach-GrandCasino
    Ensure-GrandCasinoChips -Minimum 50
    Enter-GrandRoom -Room main
    $claimedTiers = @()

    for ($round = 0; $round -lt 80; $round++) {
        Play-OneBlackjackRound
        $tier = Visit-CageAndClaimReadyPlayersCard
        if (-not [string]::IsNullOrEmpty($tier)) {
            $expectedTier = @('bronze', 'silver', 'gold')[$claimedTiers.Count]
            if ($tier -cne $expectedTier) {
                throw "Visible Players Card recognition arrived out of order: expected '$expectedTier', found '$tier'."
            }
            $claimedTiers += $tier
            if ($tier -ceq 'gold') {
                $null = Assert-TerminalOutcome
                return
            }
            if ($tier -ceq 'silver' -and -not $script:MidpointSaved) {
                Assert-SaveRelaunchContinue -Milestone 'Silver Players Card'
            }
        }
        Enter-GrandRoom -Room main
    }
    throw "Clean route did not finish all three Players Card tiers within 80 settled blackjack rounds."
}


function Resolve-ShowdownChoiceSurface {
    $choices = @(Get-VisibleChoiceIds)
    $choiceIntents = @{
        enter_back_room = "follow Rourke into the visible back-room sequence"
        face_rourke = 'take the chair after the visible clean pat-down'
    }
    foreach ($choice in @('enter_back_room', 'face_rourke')) {
        if ($choices -ccontains $choice) {
            $intent = $choiceIntents[$choice]
            $null = Choose-VisibleChoice -ChoiceId $choice -Intent $intent
            Wait-Frames -Frames 12
            return $true
        }
    }

    $interrogationChoices = @($choices | Where-Object {
        [string]$_ -cin @('hold_steady', 'talk_down', 'take_the_edge')
    })
    if ($interrogationChoices.Count -gt 0) {
        $choice = Select-CheatReplayShowdownInterrogationChoice -EventPopup (Get-Value $script:LastObservation @('event_popup') $null)
        $null = Choose-VisibleChoice -ChoiceId $choice -Intent 'take the exact visible edge against Rourke during interrogation'
        Wait-Frames -Frames 12
        return $true
    }

    $walkChoices = @($choices | Where-Object {
        [string]$_ -ceq 'keep_everything' -or
            ([string]$_).StartsWith('trash_item__', [StringComparison]::Ordinal) -or
            ([string]$_).StartsWith('hand_to_crew__', [StringComparison]::Ordinal)
    })
    if ($walkChoices.Count -gt 0) {
        $choice = Select-CheatReplayShowdownWalkChoice -EventPopup (Get-Value $script:LastObservation @('event_popup') $null)
        $intent = if ($choice -ceq 'keep_everything') {
            'keep the publicly verified non-classified inventory during Rourke''s walk'
        } elseif ($choice.StartsWith('hand_to_crew__', [StringComparison]::Ordinal)) {
            "hand the one publicly identified classified item to the Crew before Rourke's search"
        } else {
            "trash the one publicly identified classified item before Rourke's search"
        }
        $null = Choose-VisibleChoice -ChoiceId $choice -Intent $intent
        Wait-Frames -Frames 12
        return $true
    }
    return $false
}


function Invoke-CheatEndingRoute {
    Reach-GrandCasino
    Ensure-GrandCasinoChips -Minimum 50
    Enter-GrandRoom -Room main

    $showdownCallOpened = $false
    for ($round = 0; $round -lt 60; $round++) {
        Play-OneBlackjackRound -UseVisibleCheat
        if (Test-PublicTerminalSurface) {
            throw 'Visible cheating ended the run before Rourke exposed the showdown route.'
        }
        Leave-GameSurface
        if ($null -cne (Find-CanvasObject -SemanticId 'event:the_house_calls')) {
            Open-EventObject -EventId 'the_house_calls' -Intent "answer Rourke's visible back-room call"
            $showdownCallOpened = $true
            break
        }
    }
    if (-not $showdownCallOpened) {
        throw "Visible cheating did not naturally trigger Rourke's showdown within 60 settled hands."
    }
    for ($beat = 0; $beat -lt 12; $beat++) {
        if ([bool](Get-Value $script:LastObservation @('game', 'boss_duel_active') $false)) { break }
        if (-not (Resolve-ShowdownChoiceSurface)) {
            Wait-Frames -Frames 12
            if (-not [bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -and
                -not [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
                throw "Rourke's showdown stopped before the duel became publicly active."
            }
        }
    }
    if (-not [bool](Get-Value $script:LastObservation @('game', 'boss_duel_active') $false)) {
        throw "Rourke's five-hand duel never became publicly active."
    }
    if ([int](Get-Value $script:LastObservation @('game', 'boss_hand_number') 0) -cne 1 -or
        -not [bool](Get-Value $script:LastObservation @('game', 'can_deal') $false)) {
        throw "Rourke's duel is not visibly waiting before hand one at the required persistence checkpoint."
    }
    Assert-SaveRelaunchContinue -Milestone 'Rourke duel before hand one'

    for ($hand = 0; $hand -lt 8; $hand++) {
        if (Test-PublicTerminalSurface) { break }
        if ([bool](Get-Value $script:LastObservation @('event_popup', 'visible') $false) -or
            [bool](Get-Value $script:LastObservation @('talk', 'visible') $false)) {
            if (-not (Resolve-ShowdownChoiceSurface)) {
                throw "Unexpected choice interrupted Rourke's duel: $((Get-VisibleChoiceIds) -join ', ')"
            }
            continue
        }
        Play-OneBlackjackRound
    }
    for ($beat = 0; $beat -lt 12 -and -not (Test-PublicTerminalSurface); $beat++) {
        if (Resolve-ShowdownChoiceSurface) { continue }
        $endingAction = @('ending.ack', 'showdown_exit', 'surface_back') | Where-Object { $null -cne (Find-GameAction -Action $_) } | Select-Object -First 1
        if (-not [string]::IsNullOrWhiteSpace([string]$endingAction)) {
            $null = Invoke-GameAction -Action ([string]$endingAction) -Intent 'acknowledge the visible Rourke duel outcome'
        }
        else {
            Wait-Frames -Frames 20
        }
    }
    Wait-Frames -Frames 30
    $null = Assert-TerminalOutcome
}


function Find-WorldNodeIdByArchetype {
    param([Parameter(Mandatory = $true)][string]$ArchetypeId)
    Open-WorldMap
    $matches = @(Get-MapNodes | Where-Object {
        [string](Get-Value $_ @('archetype_id') '') -ceq $ArchetypeId
    } | Sort-Object @{ Expression = { if ([string](Get-Value $_ @('id') '') -ceq $ArchetypeId) { 0 } else { 1 } } }, @{ Expression = { [string](Get-Value $_ @('id') '') } })
    $nodeId = ''
    if ($matches.Count -gt 0) {
        $nodeId = [string](Get-Value $matches[0] @('id') '')
    }
    Close-WorldMap
    return $nodeId
}


function Navigate-ToArchetype {
    param(
        [Parameter(Mandatory = $true)][string]$ArchetypeId,
        [Parameter(Mandatory = $true)][string]$Intent
    )
    if ([string](Get-Value $script:LastObservation @('environment', 'archetype_id') '') -ceq $ArchetypeId) { return }
    $nodeId = Find-WorldNodeIdByArchetype -ArchetypeId $ArchetypeId
    if ([string]::IsNullOrWhiteSpace($nodeId)) {
        throw "The public map contains no visible $ArchetypeId venue."
    }
    Navigate-ToNode -NodeId $nodeId -Intent $Intent
}


function Establish-CrewMarker {
    $candidateArchetypes = @('back_alley', 'corner_store', 'motel', 'bar', 'gas_station_casino')
    $accepted = $false
    foreach ($archetype in $candidateArchetypes) {
        $nodeId = Find-WorldNodeIdByArchetype -ArchetypeId $archetype
        if ([string]::IsNullOrWhiteSpace($nodeId)) { continue }
        Navigate-ToNode -NodeId $nodeId -Intent "visit $archetype to find the Crew's visible lender"
        if ($null -ceq (Find-CanvasObject -SemanticId 'lender:the_crew')) { continue }
        $null = Open-SemanticObject -SemanticId 'lender:the_crew' -PreferredActions @('Borrow', 'Talk', 'Ask', 'Open') -Intent 'ask the visible Crew lender for terms'
        Wait-Frames -Frames 8
        $null = Choose-VisibleChoice -ChoiceId 'accept' -Intent 'accept the visible Crew favor terms and marker'
        Wait-Frames -Frames 12
        $accepted = $true
        break
    }
    if (-not $accepted) {
        throw "The normal seeded run exposed no player-visible Crew lender across the public lender route."
    }

    # The public lender terms create a two-favor marker. Clear both favors now
    # so the long heist route cannot be interrupted later by a second overdue
    # Crew call.
    $favorsCompleted = 0
    for ($boundary = 0; $boundary -lt 28; $boundary++) {
        $eventId = [string](Get-Value $script:LastObservation @('event_popup', 'event_id') '')
        $talkId = [string](Get-Value $script:LastObservation @('talk', 'event_id') '')
        if (($eventId -ceq 'crew_favor_delivery' -or $talkId -ceq 'crew_favor_delivery') -and
            'run_package' -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId 'run_package' -Intent "honor the Crew's visible favor $($favorsCompleted + 1) of 2"
            Wait-Frames -Frames 10
            Complete-PublicDelivery -Intent "complete Crew favor $($favorsCompleted + 1) of 2"
            $favorsCompleted++
            if ($favorsCompleted -ge 2) { return }
            continue
        }
        if ($null -cne (Find-CanvasObject -SemanticId 'event:crew_favor_delivery')) {
            Invoke-EventObjectChoice -EventId 'crew_favor_delivery' -ChoiceId 'run_package' -Intent "honor the Crew's visible favor $($favorsCompleted + 1) of 2"
            Complete-PublicDelivery -Intent "complete Crew favor $($favorsCompleted + 1) of 2"
            $favorsCompleted++
            if ($favorsCompleted -ge 2) { return }
            continue
        }
        if ($null -cne (Find-CanvasObject -SemanticId 'event:parking_lot_tip')) {
            Invoke-EventObjectChoice -EventId 'parking_lot_tip' -ChoiceId 'follow_tip' -Intent 'follow the visible underground route tip while the Crew calls in its favor'
            continue
        }
        Open-WorldMap
        $current = [string](Get-Value $script:LastObservation @('environment', 'world_node_id') '')
        $next = @(Get-MapNodes | Where-Object {
            [bool](Get-Value $_ @('travel_enabled') $false) -and
            [string](Get-Value $_ @('id') '') -cne $current
        } | Sort-Object @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } } | Select-Object -First 1)
        if ($next.Count -ceq 0) {
            Close-WorldMap
            throw "The Crew favor did not surface and the public map exposed no ordinary action boundary."
        }
        $nextId = [string](Get-Value $next[0] @('id') '')
        Travel-ToNode -NodeId $nextId -Intent "take an ordinary public route boundary while waiting for the Crew favor"
    }
    throw "The accepted Crew marker did not surface and clear both visible favors within twenty-eight ordinary boundaries."
}


function Ensure-PunchlineCasinoDiscovered {
    $smallNode = Find-WorldNodeIdByArchetype -ArchetypeId 'small_underground_casino'
    if ([string]::IsNullOrWhiteSpace($smallNode)) {
        $tipFound = $false
        $searchArchetypes = @('back_alley', 'corner_store', 'gas_station_casino', 'motel', 'bar')
        foreach ($archetype in $searchArchetypes) {
            $nodeId = Find-WorldNodeIdByArchetype -ArchetypeId $archetype
            if ([string]::IsNullOrWhiteSpace($nodeId)) { continue }
            Navigate-ToNode -NodeId $nodeId -Intent "look for the visible route into the Punchline from $archetype"
            if ($null -ceq (Find-CanvasObject -SemanticId 'event:parking_lot_tip')) { continue }
            Invoke-EventObjectChoice -EventId 'parking_lot_tip' -ChoiceId 'follow_tip' -Intent 'follow the visible underground route tip'
            $tipFound = $true
            break
        }
        if (-not $tipFound) {
            throw 'No ordinary public venue exposed the Parking Lot Tip needed to discover the Punchline.'
        }
        $smallNode = Find-WorldNodeIdByArchetype -ArchetypeId 'small_underground_casino'
    }
    if ([string]::IsNullOrWhiteSpace($smallNode)) {
        throw 'Following the Parking Lot Tip did not expose the Punchline on the public map.'
    }
    Navigate-ToNode -NodeId $smallNode -Intent 'travel through the real map to the Punchline'
    if ($null -cne (Find-CanvasObject -SemanticId 'event:side_door')) {
        Invoke-EventObjectChoice -EventId 'side_door' -ChoiceId 'punchline_password' -Intent 'use the visible password at the Punchline side door'
        Wait-Frames -Frames 12
    }
    elseif ($null -cne (Find-CanvasObject -SemanticId 'environment_layer:casino')) {
        $null = Open-SemanticObject -SemanticId 'environment_layer:casino' -PreferredActions @('Enter Casino', 'Enter Room', 'Enter', 'Open') -Intent 'return through the discovered Punchline casino door'
        Wait-Frames -Frames 12
    }
}


function Find-BishopSurfaceAtGrand {
    Reach-GrandCasino
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        foreach ($eventId in @('recruitment_bishop', 'crew_contact_bishop')) {
            if ($null -cne (Find-CanvasObject -SemanticId "event:$eventId")) { return $eventId }
        }
        $archetype = [string](Get-Value $script:LastObservation @('environment', 'archetype_id') '')
        if ($archetype -ceq 'grand_casino') {
            Enter-GrandRoom -Room cage
        }
        else {
            Enter-GrandRoom -Room main
        }
    }
    throw "Bishop did not rotate onto either player-accessible Grand Casino room within twenty real door transitions."
}


function Recruit-Bishop {
    $surface = Find-BishopSurfaceAtGrand
    if ($surface -ceq 'crew_contact_bishop') { return }
    if ('wait_for_bishop' -cin @(Get-VisibleChoiceIds)) {
        $null = Choose-VisibleChoice -ChoiceId 'wait_for_bishop' -Intent "wait through Bishop's visible first appointment beat"
    }
    else {
        Invoke-EventObjectChoice -EventId 'recruitment_bishop' -ChoiceId 'wait_for_bishop' -Intent "wait through Bishop's visible first appointment beat"
    }
    Wait-Frames -Frames 10
    if ('work_with_bishop' -cin @(Get-VisibleChoiceIds)) {
        $null = Choose-VisibleChoice -ChoiceId 'work_with_bishop' -Intent 'keep the visible appointment and recruit Bishop'
    }
    else {
        Invoke-EventObjectChoice -EventId 'recruitment_bishop' -ChoiceId 'work_with_bishop' -Intent 'keep the visible appointment and recruit Bishop'
    }
    Wait-Frames -Frames 12
}


function Start-BishopContactJob {
    param([Parameter(Mandatory = $true)][string[]]$Preference)
    $surface = Find-BishopSurfaceAtGrand
    if ($surface -ceq 'recruitment_bishop') {
        Recruit-Bishop
        $surface = Find-BishopSurfaceAtGrand
    }
    Select-EventObject -EventId 'crew_contact_bishop'
    foreach ($choiceId in $Preference) {
        if ($choiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent "accept Bishop's visible $choiceId job"
            Wait-Frames -Frames 10
            return $choiceId
        }
        $row = Get-EventChoiceRoomAction -EventId 'crew_contact_bishop' -ChoiceId $choiceId
        if ($null -cne $row -and [bool](Get-Value $row @('enabled') $false)) {
            $null = Invoke-RoomActionRow -Row $row -Intent "accept Bishop's visible $choiceId job"
            Wait-Frames -Frames 10
            return $choiceId
        }
    }
    $visible = @(Get-RoomActions | ForEach-Object { [string](Get-Value $_ @('emit_object_id') '') }) -join ', '
    throw "Bishop exposed none of the requested public jobs: $($Preference -join ', '). Visible actions: $visible"
}


function Enter-PunchlineBackRoom {
    param([switch]$AllowUnavailable)
    Ensure-PunchlineCasinoDiscovered
    if ($null -cne (Find-CanvasObject -SemanticId 'event:crew_planning_table')) { return $true }
    $layer = Find-CanvasObject -SemanticId 'environment_layer:back_room'
    if ($null -ceq $layer -and $null -cne (Find-CanvasObject -SemanticId 'environment_layer:casino')) {
        $null = Open-SemanticObject -SemanticId 'environment_layer:casino' -PreferredActions @('Enter Casino', 'Enter Room', 'Enter', 'Open') -Intent 'enter the discovered Punchline casino before the back-room door'
        Wait-Frames -Frames 12
        $layer = Find-CanvasObject -SemanticId 'environment_layer:back_room'
    }
    if ($null -ceq $layer) {
        if ($AllowUnavailable) { return $false }
        throw 'The visible Punchline route did not expose its Made-standing back room.'
    }
    $null = Open-SemanticObject -SemanticId 'environment_layer:back_room' -PreferredActions @('Enter Back Room', 'Enter Room', 'Enter', 'Open') -Intent 'enter the real Punchline back room'
    Wait-Frames -Frames 12
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_planning_table')) {
        if ($AllowUnavailable) { return $false }
        throw 'The back-room door did not reach the visible Crew planning table.'
    }
    return $true
}


function Close-VisibleChoiceSurface {
    foreach ($choiceId in @('leave', 'leave_counter', 'keep_moving')) {
        if ($choiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent 'leave the visible choice surface without changing the route'
            Wait-Frames -Frames 8
            return
        }
    }
}


function Test-CountPlanLive {
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_planning_table')) { return $false }
    $live = Test-EventObjectChoiceEnabled -EventId 'crew_planning_table' -ChoiceId 'lock_the_count'
    Close-VisibleChoiceSurface
    return $live
}


function Start-BishopBoardJob {
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_job_board')) {
        throw 'The real Punchline back room exposes no visible Job Board.'
    }
    Select-EventObject -EventId 'crew_job_board'
    foreach ($choiceId in @('accept_bishop_cage_packet', 'accept_bishop_camera_window')) {
        if ($choiceId -cin @(Get-VisibleChoiceIds)) {
            $null = Choose-VisibleChoice -ChoiceId $choiceId -Intent "take Bishop's visible Job Board work"
            Wait-Frames -Frames 10
            return $choiceId
        }
        $row = Get-EventChoiceRoomAction -EventId 'crew_job_board' -ChoiceId $choiceId
        if ($null -cne $row -and [bool](Get-Value $row @('enabled') $false)) {
            $null = Invoke-RoomActionRow -Row $row -Intent "take Bishop's visible Job Board work"
            Wait-Frames -Frames 10
            return $choiceId
        }
    }
    throw "The visible Job Board offered no Bishop work while his Inner Circle route remained locked."
}


function Promote-BishopToInnerCircle {
    # Recruitment starts Bishop at Associate (30). Five successful Camera
    # Windows reach Made (60) without relying on any private trust readout.
    for ($job = 1; $job -le 5; $job++) {
        $accepted = Start-BishopContactJob -Preference @('job_bishop_camera_window')
        Complete-PublicDelivery -Intent "complete Bishop Camera Window $job"
    }
    if (-not (Enter-PunchlineBackRoom -AllowUnavailable)) {
        throw 'Five successful public Camera Window jobs did not unlock the Made-standing Punchline back room.'
    }

    for ($job = 1; $job -le 7; $job++) {
        if (Test-CountPlanLive) { return }
        $accepted = Start-BishopBoardJob
        $grandRoom = if ($accepted -ceq 'accept_bishop_cage_packet') { 'cage' } else { '' }
        Complete-PublicDelivery -Intent "complete Bishop back-room job $job ($accepted)" -GrandRoom $grandRoom
        $null = Enter-PunchlineBackRoom
    }
    if (-not (Test-CountPlanLive)) {
        throw "Bishop's public work did not make The Count visibly live within the bounded Associate-to-Inner-Circle route."
    }
}


function Leave-GrandForDistinctVisit {
    Leave-GameSurface
    if ([string](Get-Value $script:LastObservation @('environment', 'world_node_id') '') -cne 'grand_casino') { return }
    Open-WorldMap
    $candidate = @(Get-MapNodes | Where-Object {
        [bool](Get-Value $_ @('travel_enabled') $false) -and
        [string](Get-Value $_ @('id') '') -cne 'grand_casino' -and
        [string](Get-Value $_ @('archetype_id') '') -cnotin @('grand_casino', 'grand_casino_cage', 'grand_casino_high_limit')
    } | Sort-Object @{ Expression = { [int](Get-Value $_ @('cost') 0) } }, @{ Expression = { [string](Get-Value $_ @('id') '') } } | Select-Object -First 1)
    if ($candidate.Count -ceq 0) {
        Close-WorldMap
        throw 'The Grand Casino exposes no public map leg for a distinct identity visit.'
    }
    $nodeId = [string](Get-Value $candidate[0] @('id') '')
    Travel-ToNode -NodeId $nodeId -Intent 'leave the Grand Casino between distinct identity sessions'
}


function Complete-CountIdentitySessions {
    Reach-GrandCasino
    Ensure-GrandCasinoChips -Minimum 125
    Enter-GrandRoom -Room main
    for ($session = 1; $session -le 3; $session++) {
        if ([int](Get-Value $script:LastObservation @('status_hud', 'heat_level') 0) -gt 35) {
            throw "The Count identity route exceeded its public heat ceiling before session $session."
        }
        Play-OneBlackjackRound -UseHeistStake
        Leave-GameSurface
        if ($session -lt 3) {
            Leave-GrandForDistinctVisit
            Reach-GrandCasino
            Enter-GrandRoom -Room main
        }
    }
}


function Get-PlanningTableProjection {
    Select-EventObject -EventId 'crew_planning_table'
    $rows = @()
    foreach ($row in Get-RoomActions) {
        $emitId = [string](Get-Value $row @('emit_object_id') '')
        if (-not $emitId.StartsWith('event_response:crew_planning_table:', [StringComparison]::Ordinal)) { continue }
        $rows += [pscustomobject][ordered]@{
            choice_id = $emitId.Substring('event_response:crew_planning_table:'.Length)
            label = [string](Get-Value $row @('label') '')
            enabled = [bool](Get-Value $row @('enabled') $false)
            disabled_reason = [string](Get-Value $row @('disabled_reason') '')
        }
    }
    if ($rows.Count -ceq 0) {
        foreach ($choice in @(Get-Array (Get-Value $script:LastObservation @('event_popup', 'choices') @()))) {
            $rows += [pscustomobject][ordered]@{
                choice_id = [string](Get-Value $choice @('id') '')
                label = [string](Get-Value $choice @('label') '')
                enabled = -not [bool](Get-Value $choice @('disabled') $false) -and [bool](Get-Value $choice @('enabled') $true)
                disabled_reason = [string](Get-Value $choice @('disabled_reason') '')
            }
        }
    }
    return @($rows | Sort-Object choice_id)
}


function Assert-HeistSaveRelaunchContinue {
    $beforeProjection = @(Get-PlanningTableProjection)
    $before = [ordered]@{
        checkpoint = Get-PersistenceCheckpoint
        planning_choices = $beforeProjection
    }
    $beforeJson = $before | ConvertTo-Json -Depth 20 -Compress
    Close-VisibleChoiceSurface
    $null = Click-Button -Text 'Menu' -Intent 'open the run menu at the completed heist setup checkpoint'
    $null = Click-RunMenuButton -Text 'Save' -RevealDirection up -Intent 'save The Count after all visible setup chairs are filled'
    Assert-ExplicitSaveAcknowledged -Milestone 'The Count completed setup'
    $null = Click-RunMenuButton -Text 'Main Menu' -RevealDirection down -Intent 'return to the main menu after saving The Count setup'
    if ([string](Get-Value $script:LastObservation @('screen', 'screen') '') -cne 'START') {
        throw 'Main Menu did not visibly return The Count checkpoint to START before relaunch.'
    }
    $null = Invoke-BridgeCommand -Command 'quit' -Intent 'quit the saved heist host before relaunch' -ObservationOnly
    Wait-ForSessionExit
    Assert-NoPostExitLogAlerts
    Remove-OwnedBridgeCaptureResidue
    Start-BridgeSession
    if ([string](Get-Value $script:LastObservation @('screen', 'start_menu', 'primary_action_text') '') -cne 'CONTINUE') {
        throw 'Relaunch after The Count setup did not expose CONTINUE.'
    }
    $null = Click-Button -Text 'CONTINUE' -Intent 'continue The Count from the full relaunch checkpoint'
    Wait-Frames -Frames 45
    Clear-VisibleCoach
    if ($null -ceq (Find-CanvasObject -SemanticId 'event:crew_planning_table')) {
        throw 'Continue did not restore the real Punchline planning-table room.'
    }
    $afterProjection = @(Get-PlanningTableProjection)
    $after = [ordered]@{
        checkpoint = Get-PersistenceCheckpoint
        planning_choices = $afterProjection
    }
    $afterJson = $after | ConvertTo-Json -Depth 20 -Compress
    if ($afterJson -cne $beforeJson) {
        $before | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_before.json') -Encoding utf8
        $after | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'checkpoint_after.json') -Encoding utf8
        throw 'Public heist plan/setup state changed across Save -> relaunch -> Continue.'
    }
    Close-VisibleChoiceSurface
    $script:MidpointSaved = $true
}


function Invoke-HeistEndingRoute {
    Establish-CrewMarker
    Ensure-PunchlineCasinoDiscovered
    Reach-GrandCasino
    Recruit-Bishop
    Promote-BishopToInnerCircle

    if (-not (Test-CountPlanLive)) {
        throw 'The Count is not visibly live after Bishop reaches Inner Circle and Audit Night is on the public route.'
    }
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'lock_the_count' -Intent 'lock Bishop''s visible Count plan at the real planning table'
    Close-VisibleChoiceSurface

    Complete-CountIdentitySessions
    $null = Enter-PunchlineBackRoom
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'count_schedule' -Intent 'start the visible Cage schedule watch'
    Close-VisibleChoiceSurface
    Complete-PublicDelivery -Intent 'complete The Count schedule hold at the Cage' -GrandRoom cage

    $null = Enter-PunchlineBackRoom
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'count_cart' -Intent 'start the visible swap-cart route'
    Close-VisibleChoiceSurface
    Complete-PublicDelivery -Intent 'move The Count swap cart to Grand Casino Main' -GrandRoom main

    $null = Enter-PunchlineBackRoom
    if (-not (Test-EventObjectChoiceEnabled -EventId 'crew_planning_table' -ChoiceId 'begin_play')) {
        throw 'All public Count setup beats completed, but Begin the Play remains disabled.'
    }
    Close-VisibleChoiceSurface
    Assert-HeistSaveRelaunchContinue
    Invoke-EventObjectChoice -EventId 'crew_planning_table' -ChoiceId 'begin_play' -Intent 'begin The Count from the visible completed setup'
    Close-VisibleChoiceSurface

    Reach-GrandCasino
    Enter-GrandRoom -Room main
    $decisions = @('go_hold', 'distraction_sit', 'exit_dock')
    for ($round = 0; $round -lt $decisions.Count; $round++) {
        $choiceId = $decisions[$round]
        if ($null -ceq (Find-CanvasObject -SemanticId 'event:heist_live_table')) {
            throw "The Count live-table event is missing before round $($round + 1)."
        }
        Invoke-EventObjectChoice -EventId 'heist_live_table' -ChoiceId $choiceId -Intent "take the visible Count decision $choiceId before live round $($round + 1)"
        Close-VisibleChoiceSurface
        Play-OneBlackjackRound -UseHeistStake
        Leave-GameSurface
    }
    Invoke-EventObjectChoice -EventId 'heist_live_table' -ChoiceId 'begin_getaway' -Intent 'take the visible dock exit after all three Count rounds'
    Close-VisibleChoiceSurface
    Complete-PublicDelivery -Intent 'complete The Count dock getaway to its marked destination'
    Wait-Frames -Frames 30
    $null = Assert-TerminalOutcome
}


function Invoke-SelectedEndingRoute {
    switch ($Ending) {
        'clean' { Invoke-CleanEndingRoute }
        'cheat' { Invoke-CheatEndingRoute }
        'heist' { Invoke-HeistEndingRoute }
        default { throw "Unsupported ending '$Ending'." }
    }
}


function Invoke-BridgeTransportRegression {
    $invocationStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "rw062-bridge-$PID-$nonce"
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session
    $script:RunRoot = Join-Path $EvidenceRoot "bridge-$invocationStamp-$PID"
    [void](New-Item -ItemType Directory -Path $script:RunRoot -Force)
    $script:TranscriptPath = Join-Path $script:RunRoot 'public_trace.ndjson'
    $script:MoneyCurvePath = Join-Path $script:RunRoot 'money_curve.ndjson'
    $script:LastResult = $null
    $script:LastObservation = $null
    $script:ActionCount = 0
    $script:TraceOrdinal = 0
    $script:LastMoneySignature = ''
    $script:MidpointSaved = $false
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''

    $lookResult = $null
    $waitResult = $null
    $quitResult = $null
    $relaunchLookResult = $null
    $relaunchQuitResult = $null
    $status = $null
    $firstOwnedPid = 0
    $firstOwnedStartUtcTicks = 0L
    $secondOwnedPid = 0
    $secondOwnedStartUtcTicks = 0L
    $failure = $null
    try {
        Start-BridgeSession
        $lookResult = $script:LastResult
        if ([string](Get-Value $lookResult @('command') '') -cne 'look') {
            throw 'Bridge transport regression did not receive its initial look result.'
        }
        $waitResult = Invoke-BridgeCommand -Command 'wait 1' -Intent 'exercise a second atomically published command' -ObservationOnly
        $quitResult = Invoke-BridgeCommand -Command 'quit' -Intent 'close the bridge transport regression host' -ObservationOnly
        $firstOwnedPid = $script:OwnedSessionPid
        $firstOwnedStartUtcTicks = $script:OwnedSessionStartUtcTicks
        Wait-ForSessionExit
        Assert-NoPostExitLogAlerts
        Remove-OwnedBridgeCaptureResidue
        if (Get-ExactOwnedSessionProcess) {
            throw 'Bridge transport regression retained its first exact owned Godot process after quit.'
        }

        # Recreate a hostile stale cursor, then relaunch the same session. Start
        # must atomically reset it before any command is allowed to inspect the
        # newly truncated process logs.
        $firstStatus = Get-SessionStatus
        $sessionFolder = [string](Get-Value $firstStatus @('folder') '')
        if ([string]::IsNullOrWhiteSpace($sessionFolder) -or -not (Test-Path -LiteralPath $sessionFolder -PathType Container)) {
            throw 'Bridge transport regression could not resolve its session evidence folder.'
        }
        $logCursorPath = Join-Path $sessionFolder 'log_cursor.json'
        @{ stdout = 999999; stderr = 999999 } | ConvertTo-Json | Set-Content -LiteralPath $logCursorPath -Encoding utf8
        Start-BridgeSession -SkipInitialLook
        $secondOwnedPid = $script:OwnedSessionPid
        $secondOwnedStartUtcTicks = $script:OwnedSessionStartUtcTicks
        $resetCursor = Get-Content -Raw -LiteralPath $logCursorPath -Encoding utf8 | ConvertFrom-Json
        if ([int]$resetCursor.stdout -cne 0 -or [int]$resetCursor.stderr -cne 0) {
            throw 'Same-session relaunch did not reset the new process log cursor before its first command.'
        }
        $relaunchLookResult = Invoke-BridgeCommand -Command 'look' -Intent 'exercise the same-session relaunch after atomic log-cursor reset' -ObservationOnly
        $relaunchQuitResult = Invoke-BridgeCommand -Command 'quit' -Intent 'close the relaunched bridge transport host' -ObservationOnly
        Wait-ForSessionExit
        Assert-NoPostExitLogAlerts
        Remove-OwnedBridgeCaptureResidue
        $status = Get-SessionStatus
        if ([bool](Get-Value $status @('running') $true)) {
            throw 'Bridge transport regression left its Godot session running.'
        }
        if (Get-ExactOwnedSessionProcess) {
            throw 'Bridge transport regression retained its relaunched exact owned Godot process after quit.'
        }
        Remove-OwnedBridgeCaptureResidue
        $sessionTempResidue = @(Get-ChildItem -LiteralPath $sessionFolder -Recurse -File -Filter '*.tmp' -ErrorAction SilentlyContinue)
        $bridgeTempResidue = @(Get-ChildItem -LiteralPath $BridgeCallRoot -File -Filter '*.tmp' -ErrorAction SilentlyContinue)
        if ($sessionTempResidue.Count -gt 0 -or $bridgeTempResidue.Count -gt 0) {
            throw 'Bridge transport regression left temporary command or capture files behind.'
        }
    }
    catch {
        $failure = $_
    }
    finally {
        if ($null -cne $failure) {
            Stop-BridgeSessionSafely -BestEffort
        }
    }

    $summary = [ordered]@{
        schema_version = 1
        check_id = 'rw06_2_bridge_transport_contract'
        passed = ($null -ceq $failure)
        session = $script:Session
        evidence_root = $script:RunRoot
        session_folder = [string](Get-Value $status @('folder') '')
        owned_processes = @(
            [ordered]@{ pid = $firstOwnedPid; start_utc_ticks = $firstOwnedStartUtcTicks; residue = $false }
            [ordered]@{ pid = $secondOwnedPid; start_utc_ticks = $secondOwnedStartUtcTicks; residue = $false }
        )
        commands = @(
            [ordered]@{ command = [string](Get-Value $lookResult @('command') ''); accepted = [bool](Get-Value $lookResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $waitResult @('command') ''); accepted = [bool](Get-Value $waitResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $quitResult @('command') ''); accepted = [bool](Get-Value $quitResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $relaunchLookResult @('command') ''); accepted = [bool](Get-Value $relaunchLookResult @('accepted') $false) }
            [ordered]@{ command = [string](Get-Value $relaunchQuitResult @('command') ''); accepted = [bool](Get-Value $relaunchQuitResult @('accepted') $false) }
        )
        failure = if ($null -ceq $failure) { '' } else { [string]$failure.Exception.Message }
    }
    $summaryPath = Join-Path $script:RunRoot 'summary.json'
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8
    if ($null -cne $failure) {
        throw $failure
    }
    return [pscustomobject]$summary
}


function Invoke-BridgeStatusRegression {
    $invocationStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "rw062-status-$PID-$nonce"
    # Prove commands remain anchored to the exact supplied folder even when its
    # date segment differs from today's wall clock.
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session -DateSegment '1999-12-31'
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''
    $statusRoot = Join-Path $EvidenceRoot "status-$invocationStamp-$PID"
    [void](New-Item -ItemType Directory -Path $statusRoot -Force)
    $status = Get-SessionStatus
    if ([bool](Get-Value $status @('running') $true)) {
        throw 'No-Godot bridge status regression unexpectedly found a running session.'
    }
    if ([string](Get-Value $status @('session') '') -cne $script:Session) {
        throw 'No-Godot bridge status regression returned the wrong session id.'
    }
    if (-not ([IO.Path]::GetFullPath([string](Get-Value $status @('folder') ''))).Equals($script:SessionRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'No-Godot bridge status regression did not preserve its cross-date absolute session root.'
    }
    Remove-OwnedBridgeCaptureResidue
    $bridgeTempResidue = @(Get-ChildItem -LiteralPath $BridgeCallRoot -File -Filter '*.tmp' -ErrorAction SilentlyContinue)
    if ($bridgeTempResidue.Count -gt 0) {
        throw 'No-Godot bridge status regression left capture files behind.'
    }
    $summary = [ordered]@{
        schema_version = 1
        check_id = 'rw06_2_bridge_status_contract'
        passed = $true
        session = $script:Session
        running = $false
        session_folder = [string](Get-Value $status @('folder') '')
        evidence_root = $statusRoot
    }
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $statusRoot 'summary.json') -Encoding utf8
    return [pscustomobject]$summary
}


function Invoke-SemanticScrollRegression {
    $failures = [Collections.Generic.List[string]]::new()
    $validButton = [pscustomobject][ordered]@{
        id = '/root/RunMenu/SkipLessons'
        text = 'Skip Lessons'
        enabled = $true
        fully_visible = $true
    }
    try {
        $selectedButton = Select-UniqueFullyVisibleButton -Buttons @($validButton) -Text 'Skip Lessons'
        if ([string](Get-Value $selectedButton @('id') '') -cne '/root/RunMenu/SkipLessons') {
            $failures.Add('Valid fully visible public button selection returned the wrong button.')
        }
    }
    catch {
        $failures.Add("Valid fully visible public button selection threw: $($_.Exception.Message)")
    }

    $buttonHostileFixtures = @(
        [pscustomobject]@{ label = 'target-missing'; buttons = @(); expect_throw = $false },
        [pscustomobject]@{ label = 'fully-visible-false'; buttons = @([pscustomobject]@{ id = '/root/partial'; text = 'Skip Lessons'; enabled = $true; fully_visible = $false }); expect_throw = $false },
        [pscustomobject]@{ label = 'fully-visible-absent'; buttons = @([pscustomobject]@{ id = '/root/absent'; text = 'Skip Lessons'; enabled = $true }); expect_throw = $true },
        [pscustomobject]@{ label = 'fully-visible-non-boolean'; buttons = @([pscustomobject]@{ id = '/root/nonbool'; text = 'Skip Lessons'; enabled = $true; fully_visible = 'true' }); expect_throw = $true },
        [pscustomobject]@{ label = 'fully-visible-property-case'; buttons = @([pscustomobject]@{ id = '/root/case'; text = 'Skip Lessons'; enabled = $true; Fully_Visible = $true }); expect_throw = $true },
        [pscustomobject]@{ label = 'ambiguous-buttons'; buttons = @($validButton, $validButton); expect_throw = $true }
    )
    foreach ($fixture in $buttonHostileFixtures) {
        $selected = $null
        $threw = $false
        try {
            $selected = Select-UniqueFullyVisibleButton -Buttons @($fixture.buttons) -Text 'Skip Lessons'
        }
        catch {
            $threw = $true
        }
        if ([bool]$fixture.expect_throw -cne $threw -or (-not $threw -and $null -cne $selected)) {
            $failures.Add("Hostile fully-visible fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validDialogOk = [pscustomobject][ordered]@{
        id = 'tutorial_skip_dialog:ok'
        text = 'OK'
        enabled = $true
        fully_visible = $true
        surface_id = 'tutorial_skip_dialog'
        dialog_role = 'ok'
        dialog_rendered = $true
    }
    $validDialogCancel = [pscustomobject][ordered]@{
        id = 'tutorial_skip_dialog:cancel'
        text = 'Cancel'
        enabled = $true
        fully_visible = $true
        surface_id = 'tutorial_skip_dialog'
        dialog_role = 'cancel'
        dialog_rendered = $true
    }
    foreach ($validDialogFixture in @(
        [pscustomobject]@{ role = 'ok'; expected_id = 'tutorial_skip_dialog:ok'; buttons = @($validDialogOk, $validDialogCancel) },
        [pscustomobject]@{ role = 'cancel'; expected_id = 'tutorial_skip_dialog:cancel'; buttons = @($validDialogOk, $validDialogCancel) }
    )) {
        try {
            $selectedDialogButton = Select-UniquePublicTutorialDialogButton `
                -Buttons @($validDialogFixture.buttons) `
                -Role ([string]$validDialogFixture.role)
            if ([string](Get-Value $selectedDialogButton @('id') '') -cne [string]$validDialogFixture.expected_id) {
                $failures.Add("Valid tutorial confirmation '$($validDialogFixture.role)' selection returned the wrong stable id.")
            }
        }
        catch {
            $failures.Add("Valid tutorial confirmation '$($validDialogFixture.role)' selection threw: $($_.Exception.Message)")
        }
    }

    $dialogHostileFixtures = @(
        [pscustomobject]@{ label = 'hidden-dialog'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $false }) },
        [pscustomobject]@{ label = 'disabled-button'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $false; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'clipped-button'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $false; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'ambiguous-dialog'; role = 'ok'; buttons = @($validDialogOk, $validDialogOk) },
        [pscustomobject]@{ label = 'wrong-stable-id'; role = 'ok'; buttons = @([pscustomobject]@{ id = '/root/internal/ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'missing-rendered-signal'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok' }) },
        [pscustomobject]@{ label = 'non-boolean-enabled-signal'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = 'true'; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; dialog_rendered = $true }) },
        [pscustomobject]@{ label = 'rendered-property-case'; role = 'ok'; buttons = @([pscustomobject]@{ id = 'tutorial_skip_dialog:ok'; text = 'OK'; enabled = $true; fully_visible = $true; surface_id = 'tutorial_skip_dialog'; dialog_role = 'ok'; Dialog_Rendered = $true }) }
    )
    foreach ($fixture in $dialogHostileFixtures) {
        $threw = $false
        try {
            $null = Select-UniquePublicTutorialDialogButton `
                -Buttons @($fixture.buttons) `
                -Role ([string]$fixture.role)
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile tutorial-confirmation fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validDown = [pscustomobject][ordered]@{
        id = 'run_menu'
        axis = 'vertical'
        rendered = $true
        can_scroll_up = $false
        can_scroll_down = $true
    }
    $validUp = [pscustomobject][ordered]@{
        id = 'run_menu'
        axis = 'vertical'
        rendered = $true
        can_scroll_up = $true
        can_scroll_down = $false
    }
    try {
        $selectedDown = Select-UniquePublicVerticalScrollSurface -Surfaces @($validDown) -SurfaceId 'run_menu' -Direction down
        if ([string](Get-Value $selectedDown @('id') '') -cne 'run_menu') {
            $failures.Add('Valid downward public scroll selection returned the wrong surface.')
        }
        $selectedUp = Select-UniquePublicVerticalScrollSurface -Surfaces @($validUp) -SurfaceId 'run_menu' -Direction up
        if ([string](Get-Value $selectedUp @('id') '') -cne 'run_menu') {
            $failures.Add('Valid upward public scroll selection returned the wrong surface.')
        }
    }
    catch {
        $failures.Add("Valid public scroll selection threw: $($_.Exception.Message)")
    }

    $hostileFixtures = @(
        [pscustomobject]@{ label = 'missing'; surfaces = @(); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'duplicate'; surfaces = @($validDown, $validDown); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'unsupported-id'; surfaces = @($validDown); surface_id = 'journal'; direction = 'down' },
        [pscustomobject]@{ label = 'not-rendered'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = $false; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'rendered-non-boolean'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = 'true'; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'wrong-axis'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'horizontal'; rendered = $true; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'blocked-direction'; surfaces = @($validUp); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'direction-non-boolean'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = $true; can_scroll_down = 'true' }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'direction-property-case'; surfaces = @([pscustomobject]@{ id = 'run_menu'; axis = 'vertical'; rendered = $true; Can_Scroll_Down = $true }); surface_id = 'run_menu'; direction = 'down' },
        [pscustomobject]@{ label = 'blank-public-id'; surfaces = @([pscustomobject]@{ id = ''; axis = 'vertical'; rendered = $true; can_scroll_down = $true }); surface_id = 'run_menu'; direction = 'down' }
    )
    foreach ($fixture in $hostileFixtures) {
        $threw = $false
        try {
            $null = Select-UniquePublicVerticalScrollSurface `
                -Surfaces @($fixture.surfaces) `
                -SurfaceId ([string]$fixture.surface_id) `
                -Direction ([string]$fixture.direction)
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile semantic-scroll fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validConfirmationObservation = [pscustomobject]@{
        event_popup = [pscustomobject]@{ visible = $false }
        talk = [pscustomobject]@{ visible = $true; render_valid = $true; event_id = 'lender_conversation:borrow:the_crew' }
    }
    $validConfirmationChoices = @(
        [pscustomobject]@{ id = 'accept'; label = 'Confirm: Accept Offer'; enabled = $true },
        [pscustomobject]@{ id = 'decline'; label = 'Not Now'; enabled = $true }
    )
    try {
        $null = Assert-VisibleTalkChoiceConfirmation -Observation $validConfirmationObservation -RenderedTalkChoices $validConfirmationChoices -ChoiceId 'accept' -ExpectedEventId 'lender_conversation:borrow:the_crew' -OriginalLabel 'Accept Offer'
    }
    catch {
        $failures.Add("Valid TalkDock confirmation fixture threw: $($_.Exception.Message)")
    }
    $confirmationHostileFixtures = @(
        [pscustomobject]@{
            label = 'same-choice-id-chained-event-modal'
            observation = [pscustomobject]@{ event_popup = [pscustomobject]@{ visible = $true }; talk = [pscustomobject]@{ visible = $false; render_valid = $true; event_id = 'lender_conversation:borrow:the_crew' } }
            choices = $validConfirmationChoices
        },
        [pscustomobject]@{
            label = 'changed-talk-event-id'
            observation = [pscustomobject]@{ event_popup = [pscustomobject]@{ visible = $false }; talk = [pscustomobject]@{ visible = $true; render_valid = $true; event_id = 'lender_conversation:borrow:brother_in_law' } }
            choices = $validConfirmationChoices
        },
        [pscustomobject]@{
            label = 'talk-visible-non-boolean'
            observation = [pscustomobject]@{ event_popup = [pscustomobject]@{ visible = $false }; talk = [pscustomobject]@{ visible = 'true'; render_valid = $true; event_id = 'lender_conversation:borrow:the_crew' } }
            choices = $validConfirmationChoices
        },
        [pscustomobject]@{
            label = 'confirmation-label-case'
            observation = $validConfirmationObservation
            choices = @([pscustomobject]@{ id = 'accept'; label = 'Confirm: accept offer'; enabled = $true }, $validConfirmationChoices[1])
        },
        [pscustomobject]@{
            label = 'confirmation-property-case'
            observation = $validConfirmationObservation
            choices = @([pscustomobject]@{ Id = 'accept'; label = 'Confirm: Accept Offer'; enabled = $true }, $validConfirmationChoices[1])
        }
    )
    foreach ($fixture in $confirmationHostileFixtures) {
        $threw = $false
        try {
            $null = Assert-VisibleTalkChoiceConfirmation -Observation $fixture.observation -RenderedTalkChoices @($fixture.choices) -ChoiceId 'accept' -ExpectedEventId 'lender_conversation:borrow:the_crew' -OriginalLabel 'Accept Offer'
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile TalkDock confirmation fixture '$($fixture.label)' did not fail closed.")
        }
    }

    $validCanvasObject = [pscustomobject]@{
        semantic_id = 'event:back_alley_offer'
        enabled = $true
        rendered = $true
    }
    try {
        $selectedCanvasObject = Select-ExactRenderedCanvasObject -Objects @($validCanvasObject) -SemanticId 'event:back_alley_offer'
        if ($null -ceq $selectedCanvasObject) {
            $failures.Add('Valid exact rendered canvas object was rejected.')
        }
        $prefixObjects = @(
            [pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = $true },
            [pscustomobject]@{ semantic_id = 'lender:street_lender'; enabled = $true; rendered = $true }
        )
        $selectedPrefixObject = Select-FirstRenderedCanvasObjectByPrefix -Objects $prefixObjects -Prefix 'lender:'
        if ([string](Get-Value $selectedPrefixObject @('semantic_id') '') -cne 'lender:street_lender') {
            $failures.Add('Valid rendered canvas prefix selection did not use exact ordinal identity.')
        }
    }
    catch {
        $failures.Add("Valid rendered canvas object fixture threw: $($_.Exception.Message)")
    }
    $canvasObjectHostileFixtures = @(
        [pscustomobject]@{ label = 'exact-clipped'; mode = 'exact'; objects = @([pscustomobject]@{ semantic_id = 'event:back_alley_offer'; enabled = $true; rendered = $false }); expect_null = $true },
        [pscustomobject]@{ label = 'exact-rendered-missing'; mode = 'exact'; objects = @([pscustomobject]@{ semantic_id = 'event:back_alley_offer'; enabled = $true }); expect_null = $false },
        [pscustomobject]@{ label = 'exact-enabled-string'; mode = 'exact'; objects = @([pscustomobject]@{ semantic_id = 'event:back_alley_offer'; enabled = 'true'; rendered = $true }); expect_null = $false },
        [pscustomobject]@{ label = 'exact-duplicate'; mode = 'exact'; objects = @($validCanvasObject, $validCanvasObject); expect_null = $false },
        [pscustomobject]@{ label = 'prefix-rendered-string'; mode = 'prefix'; objects = @([pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = 'true' }); expect_null = $false },
        [pscustomobject]@{ label = 'prefix-duplicate'; mode = 'prefix'; objects = @([pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = $true }, [pscustomobject]@{ semantic_id = 'lender:the_crew'; enabled = $true; rendered = $true }); expect_null = $false }
    )
    foreach ($fixture in $canvasObjectHostileFixtures) {
        $threw = $false
        $selected = $null
        try {
            $selected = if ([string]$fixture.mode -ceq 'exact') {
                Select-ExactRenderedCanvasObject -Objects @($fixture.objects) -SemanticId 'event:back_alley_offer'
            }
            else {
                Select-FirstRenderedCanvasObjectByPrefix -Objects @($fixture.objects) -Prefix 'lender:'
            }
        }
        catch {
            $threw = $true
        }
        $expectedNull = [bool]$fixture.expect_null
        if (($expectedNull -and ($threw -or $null -cne $selected)) -or (-not $expectedNull -and -not $threw)) {
            $failures.Add("Hostile canvas-object fixture '$($fixture.label)' did not fail closed.")
        }
    }

    function New-RoomActionRegressionRow {
        return [pscustomobject][ordered]@{
            id = ''
            action = ''
            action_id = ''
            emit_object_id = 'event_response:back_alley_offer:take_cash'
            label = 'Take the cash'
            selected_object_id = 'event:back_alley_offer'
            index = 0
            enabled = $true
            rendered = $true
        }
    }
    try {
        $null = Assert-ExactRenderedRoomActionBinding `
            -Rows @((New-RoomActionRegressionRow)) `
            -SelectedObjectId 'event:back_alley_offer' `
            -Index 0 `
            -IdentityKey 'emit_object_id' `
            -IdentityValue 'event_response:back_alley_offer:take_cash'
    }
    catch {
        $failures.Add("Valid exact room-action binding threw: $($_.Exception.Message)")
    }
    $roomActionHostileFixtures = @(
        [pscustomobject]@{ label = 'duplicate'; mutate = { param($row) @($row, (New-RoomActionRegressionRow)) } },
        [pscustomobject]@{ label = 'reordered'; mutate = { param($row) $row.index = 1; @($row) } },
        [pscustomobject]@{ label = 'clipped'; mutate = { param($row) $row.rendered = $false; @($row) } },
        [pscustomobject]@{ label = 'stale-selection'; mutate = { param($row) $row.selected_object_id = 'event:other'; @($row) } },
        [pscustomobject]@{ label = 'enabled-string'; mutate = { param($row) $row.enabled = 'true'; @($row) } },
        [pscustomobject]@{ label = 'rendered-missing'; mutate = { param($row) $row.PSObject.Properties.Remove('rendered'); @($row) } }
    )
    foreach ($fixture in $roomActionHostileFixtures) {
        $row = New-RoomActionRegressionRow
        $mutator = $fixture.mutate
        $rows = @(& $mutator $row)
        $threw = $false
        try {
            $null = Assert-ExactRenderedRoomActionBinding `
                -Rows $rows `
                -SelectedObjectId 'event:back_alley_offer' `
                -Index 0 `
                -IdentityKey 'emit_object_id' `
                -IdentityValue 'event_response:back_alley_offer:take_cash'
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile room-action fixture '$($fixture.label)' did not fail closed.")
        }
    }

    function New-SaveAcknowledgmentRegressionObservation {
        $separator = " $([char]0x00B7) "
        return [pscustomobject]@{
            screen = [pscustomobject]@{ run_menu = [pscustomobject]@{ has_save = $true } }
            status_hud = [pscustomobject]@{
                save_text_visible = $true
                save_text = "Autosave On${separator}Saved to Resume Slot."
            }
        }
    }
    try {
        $null = Assert-ExplicitSaveAcknowledgmentObservation -Observation (New-SaveAcknowledgmentRegressionObservation) -Milestone 'fixture'
    }
    catch {
        $failures.Add("Valid exact save acknowledgment fixture threw: $($_.Exception.Message)")
    }
    $saveHostileFixtures = @(
        [pscustomobject]@{ label = 'has-save-string'; mutate = { param($observation) $observation.screen.run_menu.has_save = 'true' } },
        [pscustomobject]@{ label = 'has-save-number'; mutate = { param($observation) $observation.screen.run_menu.has_save = 1 } },
        [pscustomobject]@{ label = 'visible-string'; mutate = { param($observation) $observation.status_hud.save_text_visible = 'true' } },
        [pscustomobject]@{ label = 'visible-missing'; mutate = { param($observation) $observation.status_hud.PSObject.Properties.Remove('save_text_visible') } },
        [pscustomobject]@{ label = 'text-case'; mutate = { param($observation) $observation.status_hud.save_text = $observation.status_hud.save_text.Replace('Saved', 'saved') } }
    )
    foreach ($fixture in $saveHostileFixtures) {
        $observation = New-SaveAcknowledgmentRegressionObservation
        $mutator = $fixture.mutate
        $null = & $mutator $observation
        $threw = $false
        try {
            $null = Assert-ExplicitSaveAcknowledgmentObservation -Observation $observation -Milestone 'fixture'
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile save-acknowledgment fixture '$($fixture.label)' did not fail closed.")
        }
    }

    function New-TerminalRegressionObservation {
        return [pscustomobject]@{
            screen = [pscustomobject]@{
                screen = 'VICTORY'
                run_report_visible = $true
                run_report = [pscustomobject]@{
                    outcome = [pscustomobject]@{ key = 'players_card'; won = $true }
                }
            }
        }
    }
    $priorObservation = $script:LastObservation
    $priorMidpointSaved = $script:MidpointSaved
    $priorActionCount = $script:ActionCount
    try {
        $script:LastObservation = New-TerminalRegressionObservation
        $script:MidpointSaved = $true
        $script:ActionCount = 0
        if (-not (Test-PublicTerminalSurface) -or (Assert-TerminalOutcome) -cne 'players_card') {
            $failures.Add('Valid exact terminal fixture was rejected.')
        }
    }
    catch {
        $failures.Add("Valid exact terminal fixture threw: $($_.Exception.Message)")
    }
    $terminalHostileFixtures = @(
        [pscustomobject]@{ label = 'screen-case'; mutate = { param($observation) $observation.screen.screen = 'victory' } },
        [pscustomobject]@{ label = 'visible-string'; mutate = { param($observation) $observation.screen.run_report_visible = 'true' } },
        [pscustomobject]@{ label = 'won-number'; mutate = { param($observation) $observation.screen.run_report.outcome.won = 1 } },
        [pscustomobject]@{ label = 'outcome-case'; mutate = { param($observation) $observation.screen.run_report.outcome.key = 'Players_Card' } }
    )
    foreach ($fixture in $terminalHostileFixtures) {
        $script:LastObservation = New-TerminalRegressionObservation
        $mutator = $fixture.mutate
        $null = & $mutator $script:LastObservation
        $threw = $false
        try {
            $null = Assert-TerminalOutcome
        }
        catch {
            $threw = $true
        }
        if (-not $threw) {
            $failures.Add("Hostile terminal fixture '$($fixture.label)' did not fail closed.")
        }
    }
    $script:LastObservation = $priorObservation
    $script:MidpointSaved = $priorMidpointSaved
    $script:ActionCount = $priorActionCount

    $reportPath = Join-Path $Worktree '.tmp\rw06_2\semantic_scroll_contract.json'
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force)
    $summary = [ordered]@{
        schema_version = 1
        check_id = 'rw06_2_semantic_scroll_contract'
        passed = ($failures.Count -ceq 0)
        valid_button_fixtures = 1
        hostile_button_fixtures = $buttonHostileFixtures.Count
        valid_dialog_fixtures = 2
        hostile_dialog_fixtures = $dialogHostileFixtures.Count
        valid_fixtures = 2
        hostile_fixtures = $hostileFixtures.Count
        valid_confirmation_fixtures = 1
        hostile_confirmation_fixtures = $confirmationHostileFixtures.Count
        valid_canvas_object_fixtures = 2
        hostile_canvas_object_fixtures = $canvasObjectHostileFixtures.Count
        valid_room_action_fixtures = 1
        hostile_room_action_fixtures = $roomActionHostileFixtures.Count
        valid_save_acknowledgment_fixtures = 1
        hostile_save_acknowledgment_fixtures = $saveHostileFixtures.Count
        valid_terminal_fixtures = 1
        hostile_terminal_fixtures = $terminalHostileFixtures.Count
        failures = @($failures)
        report = $reportPath
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
    if ($failures.Count -gt 0) {
        throw "RW06_2_SEMANTIC_SCROLL_CONTRACT FAIL ($($failures.Count) failure(s)); report: $reportPath"
    }
    return [pscustomobject]$summary
}


if ($SemanticScrollContract) {
    Invoke-SemanticScrollRegression | ConvertTo-Json -Depth 8
    exit 0
}


if ($BridgeStatusContract) {
    Invoke-BridgeStatusRegression | ConvertTo-Json -Depth 5
    exit 0
}


if ($BridgeTransportContract) {
    Invoke-BridgeTransportRegression | ConvertTo-Json -Depth 10
    exit 0
}


$invocationStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$invocationRoot = Join-Path $EvidenceRoot "$invocationStamp-$PID"
New-Item -ItemType Directory -Force -Path $invocationRoot | Out-Null
$runSummaries = @()
$referenceTranscriptHash = ''
$referenceMoneyHash = ''
$referenceFinalCheckpointJson = ''

for ($iteration = 1; $iteration -le $Repeat; $iteration++) {
    $nonce = [Guid]::NewGuid().ToString('N').Substring(0, 10)
    $script:Session = "rw062-$Ending-$PID-$iteration-$nonce"
    $script:SessionRoot = New-AnchoredSessionRoot -Session $script:Session
    $script:RunRoot = Join-Path $invocationRoot ("run-{0:D2}" -f $iteration)
    New-Item -ItemType Directory -Force -Path $script:RunRoot | Out-Null
    $script:TranscriptPath = Join-Path $script:RunRoot 'public_trace.ndjson'
    $script:MoneyCurvePath = Join-Path $script:RunRoot 'money_curve.ndjson'
    $script:LastResult = $null
    $script:LastObservation = $null
    $script:ActionCount = 0
    $script:TraceOrdinal = 0
    $script:LastMoneySignature = ''
    $script:MidpointSaved = $false
    $script:OwnedSessionPid = 0
    $script:OwnedSessionStartUtcTicks = 0L
    $script:OwnedSessionExecutablePath = ''
    $script:GrandFareRecoveryActive = $false
    $script:GrandFareAcceptedOfferKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareAcceptedLenderIds = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareResolvedCashEventKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:GrandFareRecoveryVisitedNodes = New-Object 'System.Collections.Generic.HashSet[string]'
    $passed = $false
    $failureMessage = ''
    $finalPublicCheckpoint = $null
    try {
        Start-BridgeSession
        Start-NormalSeededRun
        Invoke-SelectedEndingRoute
        $outcome = Assert-TerminalOutcome
        $finalPublicCheckpoint = Write-FinalPublicCheckpoint
        $passed = $true
    }
    catch {
        $failureMessage = $_.Exception.Message
        throw
    }
    finally {
        if ($passed) {
            Stop-BridgeSessionSafely
        }
        else {
            Stop-BridgeSessionSafely -BestEffort
        }
        $transcriptHash = if (Test-Path -LiteralPath $script:TranscriptPath) { (Get-FileHash -LiteralPath $script:TranscriptPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $moneyHash = if (Test-Path -LiteralPath $script:MoneyCurvePath) { (Get-FileHash -LiteralPath $script:MoneyCurvePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { '' }
        $runSummary = [ordered]@{
            iteration = $iteration
            ending = $Ending
            seed = $Seed
            session = $script:Session
            passed = $passed
            outcome = if ($null -cne $finalPublicCheckpoint) { [string]$finalPublicCheckpoint.outcome_key } else { '' }
            observed_terminal_seed = if ($null -cne $finalPublicCheckpoint) { [string]$finalPublicCheckpoint.observed_seed } else { '' }
            action_count = $script:ActionCount
            midpoint_save_relaunch_continue = $script:MidpointSaved
            transcript = $script:TranscriptPath
            transcript_sha256 = $transcriptHash
            money_curve = $script:MoneyCurvePath
            money_curve_sha256 = $moneyHash
            final_public_checkpoint = $finalPublicCheckpoint
            failure = $failureMessage
        }
        $runSummary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $script:RunRoot 'summary.json') -Encoding utf8
        $runSummaries += [pscustomobject]$runSummary
    }

    $currentTranscriptHash = [string]$runSummaries[$runSummaries.Count - 1].transcript_sha256
    $currentMoneyHash = [string]$runSummaries[$runSummaries.Count - 1].money_curve_sha256
    $currentFinalCheckpointJson = $runSummaries[$runSummaries.Count - 1].final_public_checkpoint | ConvertTo-Json -Depth 10 -Compress
    if ($iteration -ceq 1) {
        $referenceTranscriptHash = $currentTranscriptHash
        $referenceMoneyHash = $currentMoneyHash
        $referenceFinalCheckpointJson = $currentFinalCheckpointJson
    }
    elseif ($currentTranscriptHash -cne $referenceTranscriptHash -or
        $currentMoneyHash -cne $referenceMoneyHash -or
        $currentFinalCheckpointJson -cne $referenceFinalCheckpointJson) {
        throw "Deterministic replay mismatch for '$Ending': repeat $iteration differs from repeat 1."
    }
}

$deterministic = $Repeat -ceq 2 -and
    @($runSummaries | Select-Object -ExpandProperty transcript_sha256 -Unique).Count -ceq 1 -and
    @($runSummaries | Select-Object -ExpandProperty money_curve_sha256 -Unique).Count -ceq 1 -and
    @($runSummaries | ForEach-Object { $_.final_public_checkpoint | ConvertTo-Json -Depth 10 -Compress } | Select-Object -Unique).Count -ceq 1
$releaseQualifying = $Repeat -ceq 2 -and $runSummaries.Count -ceq 2 -and $deterministic -and
    @($runSummaries | Where-Object { -not $_.passed }).Count -ceq 0
$finalSummary = [ordered]@{
    schema_version = 1
    check_id = 'rw06_2_ending_replay'
    ending = $Ending
    seed = $Seed
    observed_terminal_seeds = @($runSummaries | Select-Object -ExpandProperty observed_terminal_seed)
    repeat = $Repeat
    deterministic = $deterministic
    release_qualifying = $releaseQualifying
    qualification = if ($releaseQualifying) { 'two_identical_repeats' } else { 'non_qualifying_development_run' }
    public_observation_schema = $Schema
    public_observation_schema_version = $SchemaVersion
    evidence_root = $invocationRoot
    runs = $runSummaries
}
$summaryPath = Join-Path $invocationRoot 'summary.json'
$finalSummary | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$finalSummary | ConvertTo-Json -Depth 30
