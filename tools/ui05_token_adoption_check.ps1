param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)

$tokenizedFiles = @(
    "scripts/ui/foundation_widgets.gd",
    "scripts/ui/foundation_hud_bar.gd",
    "scripts/ui/foundation_hud_view_model.gd",
    "scripts/ui/environment_header.gd",
    "scripts/ui/cheat_dock.gd",
    "scripts/ui/segmented_meter.gd",
    "scripts/ui/talk_dock.gd"
)
$violations = [System.Collections.Generic.List[string]]::new()
$patterns = @(
    @{ Name = "raw hex color"; Regex = 'Color\(\s*["'']#' },
    @{ Name = "raw theme spacing"; Regex = 'add_theme_constant_override\([^,]+,\s*[0-9]+' },
    @{ Name = "raw font size"; Regex = '(set_control_font_size|FoundationWidgets\.(label|muted_label)|_label)\([^`r`n,]+,\s*[0-9]+' },
    @{ Name = "raw control size"; Regex = '(custom_minimum_size|size)\s*=\s*Vector2\(\s*[0-9]+' }
)

foreach ($relativePath in $tokenizedFiles) {
    $path = Join-Path $Root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $violations.Add("${relativePath}: missing tokenized UI file")
        continue
    }
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $path) {
        $lineNumber += 1
        foreach ($pattern in $patterns) {
            if ($line -match $pattern.Regex) {
                $violations.Add(("{0}:{1}: {2}: {3}" -f $relativePath, $lineNumber, $pattern.Name, $line.Trim()))
            }
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host ("UI05_TOKEN_ADOPTION_CHECK PASS ({0} tokenized component files)" -f $tokenizedFiles.Count)
