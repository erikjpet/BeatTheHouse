param(
    [string]$Zip = "builds/itch/BeatTheHouse-web.zip",
    [string]$WebDir = "builds/web",
    [string]$Out = ".tmp/lb3_payload_report.json"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$zipPath = Join-Path $root $Zip
$webPath = Join-Path $root $WebDir
$outPath = Join-Path $root $Out

if (-not (Test-Path -LiteralPath $zipPath)) {
    throw "Web zip not found: $zipPath"
}
if (-not (Test-Path -LiteralPath $webPath)) {
    throw "Web build directory not found: $webPath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Add-Size {
    param(
        [hashtable]$Table,
        [string]$Key,
        [int64]$Compressed,
        [int64]$Uncompressed
    )
    if (-not $Table.ContainsKey($Key)) {
        $Table[$Key] = [ordered]@{
            compressed_bytes = [int64]0
            uncompressed_bytes = [int64]0
            files = 0
        }
    }
    $Table[$Key].compressed_bytes += $Compressed
    $Table[$Key].uncompressed_bytes += $Uncompressed
    $Table[$Key].files += 1
}

function Category-For {
    param([string]$Name)
    $lower = $Name.Replace('\', '/').ToLowerInvariant()
    if ($lower -like "*.wasm") { return "engine_wasm" }
    if ($lower -like "*.pck") { return "game_pck" }
    if ($lower -like "*.js") { return "loader_js" }
    if ($lower -like "*.html") { return "html" }
    if ($lower -match '\.(wav|ogg|mp3)$') { return "audio" }
    if ($lower -match '\.(png|jpg|jpeg|webp|svg)$') { return "images" }
    if ($lower -match '\.(json)$') { return "json" }
    if ($lower -match '(^|/)docs/' -or $lower -match '(^|/)tools/' -or $lower -match '(^|/)\.tmp/' -or $lower -match '(^|/)scripts/tests/') { return "should_be_excluded" }
    return "other"
}

function Export-Exclude-State {
    $presetPath = Join-Path $root "export_presets.cfg"
    $lines = Get-Content -LiteralPath $presetPath
    $inWeb = $false
    $exclude = ""
    foreach ($line in $lines) {
        if ($line -match '^\[preset\.\d+\]') {
            $inWeb = $false
        }
        if ($line -eq 'name="Web"') {
            $inWeb = $true
        }
        if ($inWeb -and $line -match '^exclude_filter="([^"]*)"') {
            $exclude = $Matches[1]
            break
        }
    }
    $required = @("builds/*", ".tmp/*", "docs/*", "tools/*", "scripts/tests/*")
    $states = [ordered]@{}
    foreach ($entry in $required) {
        $states[$entry] = $exclude -like "*$entry*"
    }
    return [ordered]@{
        exclude_filter = $exclude
        required_exclusions = $states
    }
}

$categories = @{}
$entries = @()
$zipFile = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    foreach ($entry in $zipFile.Entries) {
        if ($entry.FullName.EndsWith("/")) {
            continue
        }
        $category = Category-For $entry.FullName
        Add-Size $categories $category $entry.CompressedLength $entry.Length
        $entries += [ordered]@{
            name = $entry.FullName
            category = $category
            compressed_bytes = $entry.CompressedLength
            uncompressed_bytes = $entry.Length
        }
    }
}
finally {
    $zipFile.Dispose()
}

$buildFiles = @()
foreach ($file in Get-ChildItem -LiteralPath $webPath -File) {
    $buildFiles += [ordered]@{
        name = $file.Name
        bytes = $file.Length
        category = Category-For $file.Name
    }
}

$report = [ordered]@{
    zip = [ordered]@{
        path = $zipPath
        bytes = (Get-Item -LiteralPath $zipPath).Length
        sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    }
    web_dir = [ordered]@{
        path = $webPath
        files = $buildFiles
    }
    zip_categories = $categories
    largest_zip_entries = @($entries | Sort-Object -Property uncompressed_bytes -Descending | Select-Object -First 20)
    export_exclusions = Export-Exclude-State
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$json = $report | ConvertTo-Json -Depth 8
$json | Set-Content -LiteralPath $outPath -Encoding utf8
Write-Host "LB3 payload report written to $outPath"
Write-Host ("LB3_PAYLOAD_REPORT " + ($report | ConvertTo-Json -Depth 8 -Compress))
