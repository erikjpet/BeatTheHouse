param(
    [string]$Out = ".tmp/perf06_1/allocation_call_root_audit.json",
    [string[]]$ProducerRoot = @(),
    [string]$CandidateCommit = ""
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$candidate = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw "Could not resolve candidate commit." }
if (-not [string]::IsNullOrWhiteSpace($CandidateCommit)) {
    $requestedCandidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($requestedCandidate)) { throw "CandidateCommit does not resolve to a commit." }
    if ($requestedCandidate -cne $candidate) { throw "Allocation call-root audit HEAD '$candidate' does not match CandidateCommit '$requestedCandidate'." }
}

$rootSpecs = [Collections.Generic.List[object]]::new()
@(
    @{ id="foundation_snapshot"; path="scripts/ui/foundation_main.gd"; function="current_game_view_snapshot" },
    @{ id="environment_runtime"; path="scripts/ui/foundation_main.gd"; function="_advance_environment_game_runtime" },
    @{ id="surface_automation"; path="scripts/ui/foundation_main.gd"; function="_advance_game_surface_automation" },
    @{ id="surface_realtime"; path="scripts/ui/foundation_main.gd"; function="_advance_game_surface_realtime_state" },
    @{ id="layout"; path="scripts/ui/foundation_main.gd"; function="_apply_run_screen_layout" },
    @{ id="autosave_flush"; path="scripts/ui/foundation_main.gd"; function="_flush_pending_autosave_if_ready" },
    @{ id="coin_pusher_native_step"; path="scripts/games/coin_pusher/coin_pusher_live_session.gd"; function="_step_traced_ticks" }
) | ForEach-Object { $rootSpecs.Add([pscustomobject]$_) }

foreach ($encoded in $ProducerRoot) {
    $parts = $encoded.Split("|", 3)
    if ($parts.Count -ne 3 -or [string]::IsNullOrWhiteSpace($parts[1]) -or [string]::IsNullOrWhiteSpace($parts[2])) {
        throw "ProducerRoot must use id|repo-relative-path|function: $encoded"
    }
    $rootSpecs.Add([pscustomobject]@{ id=$parts[0]; path=$parts[1]; function=$parts[2] })
}

function Get-GdFunctionBody([string]$Text, [string]$FunctionName) {
    $escaped = [regex]::Escape($FunctionName)
    $match = [regex]::Match($Text, "(?ms)^(?:static\s+)?func\s+$escaped\s*\([^\r\n]*\).*?(?=^(?:static\s+)?func\s+|\z)")
    if (-not $match.Success) { return $null }
    return $match.Value
}

$forbidden = [ordered]@{
    deep_copy = '\.duplicate\(true\)'
    json_codec = 'JSON\.(stringify|parse)'
    frame_delay = '(create_timer|delay_msec|sleep)\s*\('
    callable_creation = 'Callable\s*\('
}
$rows = [Collections.Generic.List[object]]::new()
$failures = [Collections.Generic.List[string]]::new()
foreach ($spec in $rootSpecs) {
    $path = [IO.Path]::GetFullPath((Join-Path $root ([string]$spec.path)))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing call-root source: $($spec.path)"); continue }
    $text = Get-Content -LiteralPath $path -Raw
    $body = Get-GdFunctionBody $text ([string]$spec.function)
    if ($null -eq $body) { $failures.Add("Missing call-root function $($spec.function) in $($spec.path)."); continue }
    $findings = [Collections.Generic.List[string]]::new()
    foreach ($entry in $forbidden.GetEnumerator()) {
        if ([regex]::IsMatch($body, [string]$entry.Value)) { $findings.Add([string]$entry.Key) }
    }
    if ($findings.Count -ne 0) { $failures.Add("Call root '$($spec.id)' has forbidden steady-frame construct(s): $($findings -join ', ').") }
    $bytes = [Text.Encoding]::UTF8.GetBytes($body.Replace("`r`n", "`n"))
    $stream = [IO.MemoryStream]::new($bytes)
    try { $bodyHash = (Get-FileHash -InputStream $stream -Algorithm SHA256).Hash.ToLowerInvariant() } finally { $stream.Dispose() }
    $rows.Add([pscustomobject]@{
        id = [string]$spec.id
        source_path = [string]$spec.path
        function = [string]$spec.function
        source_sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        function_sha256 = $bodyHash
        findings = @($findings)
        passed = ($findings.Count -eq 0)
    })
}

$report = [ordered]@{
    schema = "beat_the_house.perf06_allocation_call_root_audit/v1"
    scope = "direct_root_source"
    candidate_commit = $candidate
    forbidden_patterns = $forbidden
    roots = @($rows)
    failures = @($failures)
    passed = ($failures.Count -eq 0)
}
$outPath = if ([IO.Path]::IsPathRooted($Out)) { [IO.Path]::GetFullPath($Out) } else { [IO.Path]::GetFullPath((Join-Path $root $Out)) }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outPath -Encoding utf8
if ($failures.Count -ne 0) { Write-Error "PERF06 ALLOCATION CALL-ROOT AUDIT FAIL failures=$($failures.Count) report=$outPath"; exit 1 }
Write-Host "PERF06 ALLOCATION CALL-ROOT AUDIT PASS roots=$($rows.Count) report=$outPath"
