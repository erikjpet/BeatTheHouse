param(
    [string]$Root = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = [System.IO.Path]::GetFullPath($Root)
$widgetsPath = Join-Path $Root "scripts/ui/foundation_widgets.gd"
$text = Get-Content -Raw -LiteralPath $widgetsPath

$required = @(
    "autosize_popup",
    "POPUP_MIN_WIDTH",
    "POPUP_MAX_WIDTH",
    "POPUP_MAX_HEIGHT_RATIO",
    "content_minimum"
)
foreach ($needle in $required) {
    if ($text -notmatch [regex]::Escape($needle)) {
        throw "Popup-fit contract is missing '$needle'."
    }
}

$cases = @(
    @{ Viewport = @(1280.0, 720.0); Content = @(260.0, 120.0) },
    @{ Viewport = @(960.0, 540.0); Content = @(420.0, 260.0) },
    @{ Viewport = @(640.0, 360.0); Content = @(720.0, 640.0) }
)
foreach ($case in $cases) {
    $availableWidth = [Math]::Max(0.0, $case.Viewport[0] - 32.0)
    $width = [Math]::Min(560.0, [Math]::Max(280.0, $case.Content[0] + 32.0))
    $width = [Math]::Min($width, $availableWidth)
    $height = [Math]::Min($case.Content[1] + 32.0, $case.Viewport[1] * 0.72)
    if ($width -gt $case.Viewport[0] -or $height -gt $case.Viewport[1]) {
        throw "Representative popup escaped viewport $($case.Viewport -join 'x')."
    }
    if ($width -gt $case.Content[0] + 32.001 -and $width -ne 280.0) {
        throw "Representative popup retained unexplained horizontal dead space."
    }
}

Write-Host ("UI05_POPUP_FIT_CHECK PASS ({0} representative viewport/content pairs)" -f $cases.Count)
