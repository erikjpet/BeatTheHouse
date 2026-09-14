param(
    [string]$ProfileId = "reproducible_low_end_cpu1",
    [string]$Out = ".tmp/perf06_1/profiles/reproducible_low_end_cpu1.json",
    [ValidateSet("physical", "reproducible_whole_matrix_throttle")][string]$Method = "reproducible_whole_matrix_throttle",
    [string]$NativeProcessorAffinityHex = "0x1",
    [ValidateSet("Idle", "BelowNormal")][string]$NativePriorityClass = "BelowNormal",
    [ValidateRange(1, 20)][int]$WebCpuThrottleRate = 4
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$outPath = if ([IO.Path]::IsPathRooted($Out)) { [IO.Path]::GetFullPath($Out) } else { [IO.Path]::GetFullPath((Join-Path $root $Out)) }
$tmpRoot = [IO.Path]::GetFullPath((Join-Path $root ".tmp"))
if (-not $outPath.StartsWith($tmpRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Host profiles must be written below .tmp." }
if (Test-Path -LiteralPath $outPath) { throw "Refusing to overwrite immutable host profile: $outPath" }

function Get-TextSha256([string]$Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$os = Get-CimInstance Win32_OperatingSystem
$gpus = @(Get-CimInstance Win32_VideoController | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.DriverVersion)" })
$hardware = [ordered]@{
    os_build = [string]$os.BuildNumber
    cpu = [string]$cpu.Name
    physical_cores = [int]$cpu.NumberOfCores
    logical_cores = [int]$cpu.NumberOfLogicalProcessors
    ram_bytes = [int64]$os.TotalVisibleMemorySize * 1024
    gpu = ($gpus -join ";")
}
$powerPlan = ((powercfg /getactivescheme) -join " ").Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($powerPlan)) { throw "Could not capture active Windows power plan." }
$profile = [ordered]@{
    schema = "beat_the_house.perf06_low_end_profile/v1"
    profile_id = $ProfileId
    method = $Method
    computer_name = [string]$env:COMPUTERNAME
    resolution = "1280x720"
    renderer = "compatibility"
    power_plan = $powerPlan
    native_processor_affinity_hex = $NativeProcessorAffinityHex
    native_priority_class = $NativePriorityClass
    web_cpu_throttle_rate = $WebCpuThrottleRate
    web_browser = "chrome"
    web_device_scale_factor = 1.0
    web_launch_flags = @(
        "--disable-background-timer-throttling",
        "--disable-renderer-backgrounding",
        "--disable-backgrounding-occluded-windows"
    )
    hardware_fingerprint_sha256 = Get-TextSha256 ($hardware | ConvertTo-Json -Compress)
    hardware = $hardware
    captured_utc = [DateTime]::UtcNow.ToString("o")
}
$directory = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$profile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outPath -Encoding utf8
Write-Host "PERF06 HOST PROFILE CAPTURED path=$outPath sha256=$((Get-FileHash -LiteralPath $outPath -Algorithm SHA256).Hash.ToLowerInvariant())"
