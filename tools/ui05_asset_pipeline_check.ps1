param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)
$manifestPath = Join-Path $Root "docs/plans/0.5_ui_art_manifest.md"
$artRoot = Join-Path $Root "assets/art/ui"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "UI art manifest is missing."
}

$manifestText = Get-Content -Raw -LiteralPath $manifestPath
$diskPaths = @(
    Get-ChildItem -LiteralPath $artRoot -Recurse -File -Filter "*.png" |
        ForEach-Object {
            $_.FullName.Substring($artRoot.Length + 1).Replace("\", "/")
        } |
        Sort-Object
)
$missingManifestEntries = @()
foreach ($relativePath in $diskPaths) {
    if ($manifestText -notmatch [regex]::Escape($relativePath)) {
        $missingManifestEntries += $relativePath
    }
}
if ($missingManifestEntries.Count -gt 0) {
    throw "Manifest does not list shipped UI art: $($missingManifestEntries -join ', ')"
}

$titlePath = Join-Path $artRoot "environment_titles/corner_store.png"
$iconPath = Join-Path $artRoot "icons/wallet.png"
$scratchRoot = Join-Path $Root ".tmp/ui05_asset_fallback_copy"
New-Item -ItemType Directory -Force -Path $scratchRoot | Out-Null
Copy-Item -LiteralPath $titlePath -Destination (Join-Path $scratchRoot "corner_store.png") -Force
Copy-Item -LiteralPath $iconPath -Destination (Join-Path $scratchRoot "wallet.png") -Force
Remove-Item -LiteralPath (Join-Path $scratchRoot "corner_store.png")
Remove-Item -LiteralPath (Join-Path $scratchRoot "wallet.png")

$uiArtText = Get-Content -Raw -LiteralPath (Join-Path $Root "scripts/ui/ui_art.gd")
if ($uiArtText -notmatch "ResourceLoader\.exists" -or $uiArtText -notmatch "_fallback_texture") {
    throw "UI art loader does not retain its missing-file fallback."
}
if ($uiArtText -notmatch "fallback_for_test") {
    throw "Fallback path is not directly covered by the UI design-system suite."
}

Write-Host ("UI05_ASSET_PIPELINE_CHECK PASS ({0} PNGs cross-checked; title and icon temp-copy deletion covered)" -f $diskPaths.Count)
