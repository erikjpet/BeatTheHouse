$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$runState = Get-Content (Join-Path $root "scripts/core/run_state.gd") -Raw
$foundation = Get-Content (Join-Path $root "scripts/ui/foundation_main.gd") -Raw
$failures = [System.Collections.Generic.List[string]]::new()
function Expect-Contract([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }

function Get-ClusterStats([string]$Source, [string]$FunctionPattern) {
    $lines = @($Source -split "`r?`n")
    $starts = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^func\s+([A-Za-z0-9_]+)\s*\(') {
            $starts.Add([pscustomobject]@{ index = $index; name = $Matches[1] })
        }
    }
    $count = 0
    $lineCount = 0
    for ($index = 0; $index -lt $starts.Count; $index++) {
        if ($starts[$index].name -notmatch $FunctionPattern) { continue }
        $end = if ($index + 1 -lt $starts.Count) { $starts[$index + 1].index } else { $lines.Count }
        $count += 1
        $lineCount += $end - $starts[$index].index
    }
    return [pscustomobject]@{ count = $count; lines = $lineCount }
}

foreach ($file in @("crew_run_facade.gd", "grand_casino_run_facade.gd", "delivery_run_facade.gd")) {
    Expect-Contract (Test-Path (Join-Path $root "scripts/core/$file")) "CH-26: missing scripts/core/$file."
}
Expect-Contract (Test-Path (Join-Path $root "scripts/ui/sealed_action_host.gd")) "CH-26: sealed action host extraction is missing."
Expect-Contract ($runState.Contains('var _crew_run_facade: RefCounted = CrewRunFacadeScript.new()')) "CH-26: RunState does not own CrewRunFacade."
Expect-Contract ($runState.Contains('var _grand_casino_run_facade: RefCounted = GrandCasinoRunFacadeScript.new()')) "CH-26: RunState does not own GrandCasinoRunFacade."
Expect-Contract ($runState.Contains('var _delivery_run_facade: RefCounted = DeliveryRunFacadeScript.new()')) "CH-26: RunState does not own DeliveryRunFacade."
Expect-Contract (-not $runState.Contains('var crew_trust_by_member: Dictionary = {}')) "CH-26: crew backing state remains directly owned by RunState."
Expect-Contract (-not $runState.Contains('var grand_casino_room_states: Dictionary = {}')) "CH-26: grand-casino backing state remains directly owned by RunState."
Expect-Contract (-not $runState.Contains('var active_delivery_run: Dictionary = {}')) "CH-26: delivery backing state remains directly owned by RunState."
Expect-Contract ($foundation.Contains('var _sealed_action_host: RefCounted')) "CH-26: Foundation does not own SealedActionHost."
Expect-Contract ($foundation.Contains('_sealed_action_host.bind(self)') -and $foundation.Contains('_sealed_action_host._sealed_action_host_surface_intent(')) "CH-26: sealed surface-intent boundary does not route through the extracted host."

$crewFacade = Get-Content (Join-Path $root "scripts/core/crew_run_facade.gd") -Raw
$grandFacade = Get-Content (Join-Path $root "scripts/core/grand_casino_run_facade.gd") -Raw
$deliveryFacade = Get-Content (Join-Path $root "scripts/core/delivery_run_facade.gd") -Raw
$sealedHost = Get-Content (Join-Path $root "scripts/ui/sealed_action_host.gd") -Raw
$runCrew = Get-ClusterStats $runState '^_?crew_'
$facadeCrew = Get-ClusterStats $crewFacade '^_?crew_'
$runGrand = Get-ClusterStats $runState '^_?grand_'
$facadeGrand = Get-ClusterStats $grandFacade '^_?grand_'
$runDelivery = Get-ClusterStats $runState '^_?delivery_'
$facadeDelivery = Get-ClusterStats $deliveryFacade '^_?delivery_'
$foundationSealed = Get-ClusterStats $foundation '^_?sealed_'
$hostSealed = Get-ClusterStats $sealedHost '^_?sealed_'
Expect-Contract ($facadeCrew.count -ge 120 -and $facadeCrew.lines -gt $runCrew.lines) "CH-26: 120 crew facade bodies were not physically extracted from RunState."
Expect-Contract ($facadeGrand.count -ge 62 -and $facadeGrand.lines -gt $runGrand.lines) "CH-26: 62 Grand Casino facade bodies were not physically extracted from RunState."
Expect-Contract ($facadeDelivery.count -ge 28 -and $facadeDelivery.lines -gt $runDelivery.lines) "CH-26: 28 delivery facade bodies were not physically extracted from RunState."
Expect-Contract ($hostSealed.count -ge 43 -and $hostSealed.lines -gt $foundationSealed.lines) "CH-26: 43 sealed-action bodies were not physically extracted from FoundationMain."

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "health06_1 god-object source contract passed."
