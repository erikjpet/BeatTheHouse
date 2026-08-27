param(
    [string]$GodotPath = "",
    [Parameter(Mandatory = $true)]
    [string]$OutDir,
    [string]$SourceHead = "",
    [string]$SourceTree = "",
    [string]$BuildIdentity = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot runtime not found; pass -GodotPath or set GODOT_BIN."
}

$output = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
$rootPath = [IO.Path]::GetFullPath($root)
if (-not $output.StartsWith($rootPath + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Output must remain inside the project: $output"
}
if (Test-Path -LiteralPath $output) {
    throw "Refusing to overwrite retained static-cache evidence: $output"
}
New-Item -ItemType Directory -Path $output | Out-Null

if (-not $SourceHead) { $SourceHead = (& git -C $root rev-parse HEAD).Trim() }
if (-not $SourceTree) { $SourceTree = (& git -C $root write-tree).Trim() }
if (-not $BuildIdentity) {
    $godotHash = (Get-FileHash -LiteralPath $GodotPath -Algorithm SHA256).Hash
    $BuildIdentity = "godot-4.6-stable:$godotHash"
}
$rootWithSlash = $rootPath.TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
$rootUri = [Uri]$rootWithSlash
$reportUri = [Uri](Join-Path $output "report.json")
$reportRelative = [Uri]::UnescapeDataString($rootUri.MakeRelativeUri($reportUri).ToString())
$reportResource = "res://$reportRelative"

& $GodotPath --path $root --script res://tools/coin_pusher_static_cache_contract.gd -- `
    "--report=$reportResource" `
    "--source-head=$SourceHead" `
    "--source-tree=$SourceTree" `
    "--build-identity=$BuildIdentity"
if ($LASTEXITCODE -ne 0) {
    throw "Static-cache contract failed with exit code $LASTEXITCODE; retained output: $output"
}

$report = Get-Content -LiteralPath (Join-Path $output "report.json") -Raw | ConvertFrom-Json
if (-not $report.passed) { throw "Static-cache report is red: $output" }
[ordered]@{
    schema = "coin_pusher_static_cache_contract_manifest_v1"
    passed = $true
    source_head = $SourceHead
    source_tree = $SourceTree
    build_identity = $BuildIdentity
    report_sha256 = (Get-FileHash -LiteralPath (Join-Path $output "report.json") -Algorithm SHA256).Hash
    pixel_pair_count = @($report.observations.pixel_pairs).Count
    exact_pixel_pair_count = @($report.observations.pixel_pairs | Where-Object { $_.exact_match }).Count
    visually_equivalent_pixel_pair_count = @($report.observations.pixel_pairs | Where-Object { $_.visually_equivalent }).Count
    reproduction_command = "tools/coin_pusher_static_cache_contract.ps1"
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output "manifest.json") -Encoding UTF8

Write-Host "COIN_PUSHER_STATIC_CACHE_CONTRACT_WRAPPER PASS manifest=$(Join-Path $output 'manifest.json')"
