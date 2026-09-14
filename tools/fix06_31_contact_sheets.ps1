param(
    [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
    [string]$BeforeDir = "",
    [string]$AfterDir = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($BeforeDir)) {
    $BeforeDir = Join-Path $Root ".tmp/fix06_31/before"
}
if ([string]::IsNullOrWhiteSpace($AfterDir)) {
    $AfterDir = Join-Path $Root ".tmp/fix06_31/after"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $Root "docs/plans/evidence/fix06_31/contact_sheets"
}

$roomPrefixes = [ordered]@{
    "back_alley" = "back_alley_"
    "bar" = "bar_"
    "beach" = "beach_"
    "corner_store" = "corner_store_"
    "delta_queen" = "delta_queen_"
    "gas_station_casino" = "gas_station_"
    "grand_casino" = "grand_casino_"
    "jazz_club" = "jazz_club_"
    "kitty_cat_lounge" = "kitty_cat_lounge_"
    "motel" = "motel_"
    "pawn_shop" = "pawn_shop_"
    "small_underground_casino" = "punchline_"
}

function New-ComparisonSheet {
    param(
        [Parameter(Mandatory = $true)][array]$Rows,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $thumbWidth = 320
    $thumbHeight = 180
    $labelHeight = 28
    $sheet = [System.Drawing.Bitmap]::new($thumbWidth * 4, ($thumbHeight + $labelHeight) * $Rows.Count)
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    $graphics.Clear([System.Drawing.Color]::FromArgb(18, 20, 26))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $font = [System.Drawing.Font]::new([System.Drawing.FontFamily]::GenericSansSerif, 11, [System.Drawing.FontStyle]::Bold)
    $brush = [System.Drawing.Brushes]::White
    $headers = @("BEFORE CLEAN", "AFTER CLEAN", "BEFORE ANNOTATED", "AFTER ANNOTATED")
    try {
        for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
            $row = $Rows[$rowIndex]
            $top = $rowIndex * ($thumbHeight + $labelHeight)
            for ($columnIndex = 0; $columnIndex -lt 4; $columnIndex++) {
                $sourcePath = [string]$row.Images[$columnIndex]
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                    throw "Missing comparison capture: $sourcePath"
                }
                $source = [System.Drawing.Image]::FromFile($sourcePath)
                try {
                    $graphics.DrawImage($source, $columnIndex * $thumbWidth, $top, $thumbWidth, $thumbHeight)
                }
                finally {
                    $source.Dispose()
                }
                $caption = if ($columnIndex -eq 0) { "$($row.Label) | $($headers[$columnIndex])" } else { $headers[$columnIndex] }
                $graphics.DrawString($caption, $font, $brush, ($columnIndex * $thumbWidth) + 5, $top + $thumbHeight + 4)
            }
        }
        $parent = Split-Path -Parent $Destination
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        $sheet.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $font.Dispose()
        $graphics.Dispose()
        $sheet.Dispose()
    }
}

[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$manifest = [ordered]@{
    schema = "fix06_31_contact_sheets/v1"
    columns = @("before_clean", "after_clean", "before_annotated", "after_annotated")
    sheets = @()
}

$baseRows = @()
$baseFiles = Get-ChildItem -LiteralPath (Join-Path $BeforeDir "base") -File -Filter "*.png" |
    Where-Object { $_.BaseName -notlike "*_annotated" } |
    Sort-Object BaseName
foreach ($file in $baseFiles) {
    $id = $file.BaseName
    $baseRows += [pscustomobject]@{
        Label = $id
        Images = @(
            $file.FullName,
            (Join-Path $AfterDir "base/$id.png"),
            (Join-Path $BeforeDir "base/${id}_annotated.png"),
            (Join-Path $AfterDir "base/${id}_annotated.png")
        )
    }
}
$baseDestination = Join-Path $OutputDir "base_rooms_before_after.png"
New-ComparisonSheet -Rows $baseRows -Destination $baseDestination
$manifest.sheets += [ordered]@{ id = "base_rooms"; rows = $baseRows.Count; file = "base_rooms_before_after.png"; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $baseDestination).Hash.ToLowerInvariant() }

$scenarioFiles = Get-ChildItem -LiteralPath (Join-Path $BeforeDir "states") -File -Filter "*_arrival_clean.png" | Sort-Object BaseName
$covered = @{}
foreach ($entry in $roomPrefixes.GetEnumerator()) {
    $roomId = [string]$entry.Key
    $prefix = [string]$entry.Value
    $rows = @()
    foreach ($file in $scenarioFiles | Where-Object { $_.BaseName.StartsWith($prefix, [System.StringComparison]::Ordinal) }) {
        $scenarioId = $file.BaseName.Substring(0, $file.BaseName.Length - "_arrival_clean".Length)
        $covered[$scenarioId] = $true
        $rows += [pscustomobject]@{
            Label = $scenarioId
            Images = @(
                $file.FullName,
                (Join-Path $AfterDir "states/${scenarioId}_arrival_clean.png"),
                (Join-Path $BeforeDir "states/${scenarioId}_arrival_annotated.png"),
                (Join-Path $AfterDir "states/${scenarioId}_arrival_annotated.png")
            )
        }
    }
    if ($rows.Count -eq 0) {
        throw "No scenario captures matched room prefix $roomId ($prefix)."
    }
    $destination = Join-Path $OutputDir "${roomId}_states_before_after.png"
    New-ComparisonSheet -Rows $rows -Destination $destination
    $manifest.sheets += [ordered]@{ id = $roomId; rows = $rows.Count; file = "${roomId}_states_before_after.png"; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash.ToLowerInvariant() }
}

$uncovered = @($scenarioFiles | ForEach-Object { $_.BaseName.Substring(0, $_.BaseName.Length - "_arrival_clean".Length) } | Where-Object { -not $covered.ContainsKey($_) })
if ($uncovered.Count -gt 0) {
    throw "Scenario captures were not assigned to a room sheet: $($uncovered -join ', ')"
}

$manifestPath = Join-Path $OutputDir "manifest.json"
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
Write-Output "FIX06_31_CONTACT_SHEETS_OK sheets=$($manifest.sheets.Count) base_rows=$($baseRows.Count) scenario_rows=$($covered.Count) output=$OutputDir"
