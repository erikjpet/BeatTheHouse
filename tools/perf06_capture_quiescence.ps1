param(
    [Parameter(Mandatory = $true)][ValidateSet("before", "after")][string]$Stage,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$WorkerWitness,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DirectorWitness,
    [Parameter(Mandatory = $true)][string]$CandidateCommit,
    [Parameter(Mandatory = $true)][string]$Out,
    [ValidateRange(3, 3)][int]$SampleCount = 3,
    [ValidateRange(250, 5000)][int]$SampleIntervalMs = 1000,
    [switch]$RequireNoQualificationProcesses
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$candidate = (& git -C $root rev-parse "$CandidateCommit^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($candidate)) { throw "CandidateCommit does not resolve." }
if ((& git -C $root rev-parse HEAD).Trim() -cne $candidate) { throw "Quiescence custody must bind the checked-out candidate." }
$outPath = if ([IO.Path]::IsPathRooted($Out)) { [IO.Path]::GetFullPath($Out) } else { [IO.Path]::GetFullPath((Join-Path $root $Out)) }
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $outPath.StartsWith($tmpRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Quiescence evidence must resolve below .tmp." }
if (Test-Path -LiteralPath $outPath) { throw "Refusing to overwrite immutable quiescence evidence: $outPath" }

$inventory = @(Get-Process -ErrorAction SilentlyContinue | Sort-Object ProcessName, Id | Select-Object ProcessName, Id, CPU, WorkingSet64)
$busy = @($inventory | Where-Object { $_.ProcessName -in @("Godot_v4.6-stable_win64", "Godot_v4.6-stable_win64_console", "BeatTheHouse", "chrome") })
if ($RequireNoQualificationProcesses -and $busy.Count -ne 0) { throw "Qualification host is not quiescent: $($busy.ProcessName -join ', ')" }

$samples = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $SampleCount; $index++) {
    $processors = @(Get-CimInstance Win32_Processor)
    $os = Get-CimInstance Win32_OperatingSystem
    $cpuPercent = [double](($processors | Measure-Object -Property LoadPercentage -Average).Average)
    $samples.Add([pscustomobject][ordered]@{
        ordinal = $index + 1
        captured_utc = [DateTime]::UtcNow.ToString("o")
        cpu_load_percent = $cpuPercent
        memory_total_bytes = [int64]$os.TotalVisibleMemorySize * 1024
        memory_available_bytes = [int64]$os.FreePhysicalMemory * 1024
    })
    if ($index + 1 -lt $SampleCount) { Start-Sleep -Milliseconds $SampleIntervalMs }
}

$record = [ordered]@{
    schema = "beat_the_house.perf06_quiescence/v1"
    tool_source_sha256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    stage = $Stage
    candidate_commit = $candidate
    candidate_tree = (& git -C $root rev-parse "HEAD^{tree}").Trim()
    worker_witness = $WorkerWitness
    director_witness = $DirectorWitness
    host_id = [string]$env:COMPUTERNAME
    sample_count = $samples.Count
    idle_cpu_memory_samples = @($samples)
    process_inventory = $inventory
    qualification_process_count = $busy.Count
    passed = $busy.Count -eq 0
}
$directory = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding utf8
Write-Host "PERF06 QUIESCENCE CAPTURED stage=$Stage samples=$($samples.Count) processes=$($inventory.Count) path=$outPath"
