param(
    [int]$SeedsPerPlaystyle,
    [int]$SeedStart,
    [int]$MaxActions,
    [string]$SeedPrefix,
    [string]$Playstyle,
    [string]$BuildRef,
    [string]$Output,
    [string]$ExitRecord
)

$ErrorActionPreference = "Stop"
$started = Get-Date
try {
    & (Join-Path $PSScriptRoot "cross_economy_audit.ps1") -SeedsPerPlaystyle $SeedsPerPlaystyle -SeedStart $SeedStart -MaxActions $MaxActions -SeedPrefix $SeedPrefix -Playstyle $Playstyle -BuildRef $BuildRef -Output $Output
    $record = [ordered]@{
        schema = "balance06_1_distribution_shard_exit_v1"
        exit_code = 0
        playstyle = $Playstyle
        build_ref = $BuildRef
        started_at_utc = $started.ToUniversalTime().ToString("o")
        ended_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    }
    $record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ExitRecord -Encoding utf8
    exit 0
}
catch {
    $record = [ordered]@{
        schema = "balance06_1_distribution_shard_exit_v1"
        exit_code = 1
        playstyle = $Playstyle
        build_ref = $BuildRef
        error = $_.Exception.Message
        started_at_utc = $started.ToUniversalTime().ToString("o")
        ended_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    }
    $record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ExitRecord -Encoding utf8
    Write-Error $_
    exit 1
}
