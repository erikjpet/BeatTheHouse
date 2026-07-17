param(
    [int]$SamplesPerType = 50000
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$packPath = Join-Path $root "data\games\scratch_tickets.json"
$reportRoot = Join-Path $root ".tmp\scratch_tickets"
$reportPath = Join-Path $reportRoot "rtp_audit.json"
$ticketTypes = Get-Content -LiteralPath $packPath -Raw | ConvertFrom-Json
$modulus = 2147483647L
$multiplier = 48271L

function Get-TextSeed {
    param([string]$Text)
    [long]$hashValue = 2166136261L
    foreach ($character in $Text.ToCharArray()) {
        $hashValue = $hashValue -bxor [int][char]$character
        $hashValue = ($hashValue * 16777619L) -band 0x7fffffffL
    }
    return [Math]::Max(1L, $hashValue)
}

function New-PenaltyLookup {
    param(
        [int]$CellCount,
        [int]$ChancePercent,
        [int]$Minimum,
        [int]$Maximum,
        [int]$Slots = 10000
    )
    [double[]]$probabilities = @(1.0)
    $amountCount = [Math]::Max(1, $Maximum - $Minimum + 1)
    $hitProbability = [Math]::Max(0.0, [Math]::Min(1.0, $ChancePercent / 100.0))
    $amountProbability = $hitProbability / $amountCount
    for ($cell = 0; $cell -lt $CellCount; $cell++) {
        [double[]]$next = New-Object double[] ($probabilities.Count + $Maximum)
        for ($total = 0; $total -lt $probabilities.Count; $total++) {
            $next[$total] += $probabilities[$total] * (1.0 - $hitProbability)
            for ($amount = $Minimum; $amount -le $Maximum; $amount++) {
                $next[$total + $amount] += $probabilities[$total] * $amountProbability
            }
        }
        $probabilities = $next
    }
    [int[]]$lookup = New-Object int[] $Slots
    $penalty = 0
    $cumulative = 0.0
    for ($slot = 0; $slot -lt $Slots; $slot++) {
        $target = ($slot + 0.5) / $Slots
        while ($penalty -lt $probabilities.Count - 1 -and $target -gt $cumulative + $probabilities[$penalty]) {
            $cumulative += $probabilities[$penalty]
            $penalty++
        }
        $lookup[$slot] = $penalty
    }
    return ,$lookup
}

$rows = New-Object System.Collections.Generic.List[object]
$failures = New-Object System.Collections.Generic.List[string]
foreach ($ticketType in $ticketTypes) {
    $typeId = [string]$ticketType.id
    $price = [int]$ticketType.price
    $table = @($ticketType.prize_table)
    $totalWeight = ($table | Measure-Object -Property weight -Sum).Sum
    [long]$state = Get-TextSeed "SCRATCH-AUDIT:$typeId"
    [long]$totalReturn = 0
    [long]$totalCost = [long]$price * $SamplesPerType
    $isShock = [string]$ticketType.gimmick.type -eq "shock_penalty"
    $losingLookup = $null
    $winningLookup = $null
    if ($isShock) {
        $cellCount = [int]$ticketType.grid.columns * [int]$ticketType.grid.rows
        $chance = [int]$ticketType.gimmick.penalty_chance_percent
        $minimum = [int]$ticketType.gimmick.penalty_amount[0]
        $maximum = [int]$ticketType.gimmick.penalty_amount[1]
        $losingLookup = New-PenaltyLookup $cellCount $chance $minimum $maximum
        $winningLookup = New-PenaltyLookup ([Math]::Max(0, $cellCount - 3)) $chance $minimum $maximum
    }
    for ($sample = 0; $sample -lt $SamplesPerType; $sample++) {
        $state = ($state * $multiplier) % $modulus
        $roll = 1 + ($state % $totalWeight)
        $cursor = 0
        $payout = 0
        $winning = $false
        foreach ($entry in $table) {
            $cursor += [int]$entry.weight
            if ($roll -le $cursor) {
                $payout = if ($null -ne $entry.audit_return) { [int]$entry.audit_return } else { [int]$entry.payout }
                $winning = -not [string]::IsNullOrWhiteSpace([string]$entry.winning_symbol)
                break
            }
        }
        $penalty = 0
        if ($isShock) {
            $state = ($state * $multiplier) % $modulus
            $lookup = if ($winning) { $winningLookup } else { $losingLookup }
            $penalty = $lookup[[int]($state % $lookup.Count)]
        }
        $totalReturn += $payout - $penalty
    }
    $rtp = [double]$totalReturn / [Math]::Max(1L, $totalCost)
    $minimumBand = [double]$ticketType.rtp_band[0]
    $maximumBand = [double]$ticketType.rtp_band[1]
    $passed = $rtp -ge $minimumBand -and $rtp -le $maximumBand
    $row = [ordered]@{
        type_id = $typeId
        display_name = [string]$ticketType.display_name
        samples = $SamplesPerType
        rtp = $rtp
        band = @($minimumBand, $maximumBand)
        passed = $passed
    }
    $rows.Add([pscustomobject]$row)
    "SCRATCH_RTP type={0} samples={1} rtp={2:N5} band=[{3:N3}, {4:N3}] passed={5}" -f $typeId, $SamplesPerType, $rtp, $minimumBand, $maximumBand, $passed
    if (-not $passed) {
        $failures.Add("$typeId RTP $rtp missed [$minimumBand, $maximumBand].")
    }
}

New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$report = [ordered]@{
    tool = "scratch_tickets_rtp_audit"
    samples_per_type = $SamplesPerType
    passed = $failures.Count -eq 0
    rows = @($rows.ToArray())
    failures = @($failures.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding utf8
"Report: $reportPath"
if ($failures.Count -gt 0) {
    throw ($failures -join [Environment]::NewLine)
}
