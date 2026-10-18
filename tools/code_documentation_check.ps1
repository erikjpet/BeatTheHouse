param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$errors = [System.Collections.Generic.List[string]]::new()

function Add-DocumentationError([string]$message) {
    $errors.Add($message)
}

function Relative-Path([string]$fullPath) {
    return $fullPath.Substring($repoRoot.Length + 1).Replace("\", "/")
}

function Header-Comment-Index([string[]]$lines, [int]$functionIndex) {
    $index = $functionIndex - 1
    while ($index -ge 0) {
        $trimmed = $lines[$index].Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith("@")) {
            $index -= 1
            continue
        }
        break
    }
    if ($index -ge 0 -and $lines[$index] -match '^\s*#') {
        return $index
    }
    return -1
}

$productionRoots = @(
    (Join-Path $repoRoot "scripts/core"),
    (Join-Path $repoRoot "scripts/ui"),
    (Join-Path $repoRoot "scripts/games")
)
$productionFiles = @(
    foreach ($root in $productionRoots) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.gd"
    }
)

$functionCount = 0
$functionHeaderCount = 0
$staleHeaderPattern = '(?i)\b(TODO|FIXME|XXX|HACK)\b|later phases? add|phase\s+\d+.*\bonly\b|current build lacks|temporary workaround|placeholder implementation'
$pathPattern = '(?:res://)?(?:scripts|data|docs|tools)/[A-Za-z0-9_./-]+\.(?:gd|json|md|ps1|py)'

foreach ($file in $productionFiles) {
    $relative = Relative-Path $file.FullName
    $lines = [string[]](Get-Content -LiteralPath $file.FullName)
    $headerWindow = $lines | Select-Object -First 30
    if (-not ($headerWindow -match '^\s*#')) {
        Add-DocumentationError "$relative has no purpose/ownership comment in its first 30 lines."
    }

    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex += 1) {
        $line = $lines[$lineIndex]
        if ($line -match '^\s*(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*\(') {
            $functionName = $Matches[1]
            $functionCount += 1
            $headerIndex = Header-Comment-Index $lines $lineIndex
            if ($headerIndex -ge 0) {
                $functionHeaderCount += 1
                $commentStart = $headerIndex
                while ($commentStart -gt 0 -and $lines[$commentStart - 1] -match '^\s*#') {
                    $commentStart -= 1
                }
                $commentText = ($lines[$commentStart..$headerIndex] -join " ")
                if ($commentText -match $staleHeaderPattern) {
                    Add-DocumentationError "${relative}:$($lineIndex + 1) has a stale/debt marker in the header for $functionName."
                }
            }
        }

        if ($line.TrimStart().StartsWith("#")) {
            foreach ($match in [regex]::Matches($line, $pathPattern)) {
                $referencedPath = $match.Value.Replace("res://", "") -replace '[`.,;:)]+$', ''
                if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $referencedPath) -PathType Leaf)) {
                    Add-DocumentationError "${relative}:$($lineIndex + 1) references missing file $referencedPath."
                }
            }
        }
    }
}

$gameModulePath = Join-Path $repoRoot "scripts/core/game_module.gd"
$gameModuleLines = [string[]](Get-Content -LiteralPath $gameModulePath)
for ($lineIndex = 0; $lineIndex -lt $gameModuleLines.Count; $lineIndex += 1) {
    if ($gameModuleLines[$lineIndex] -notmatch '^\s*(?:static\s+)?func\s+([A-Za-z0-9_]+)\s*\(') {
        continue
    }
    $functionName = $Matches[1]
    if (-not $functionName.StartsWith("_") -and (Header-Comment-Index $gameModuleLines $lineIndex) -lt 0) {
        Add-DocumentationError "scripts/core/game_module.gd:$($lineIndex + 1) public contract $functionName has no header comment."
    }
}

$activeCommentFiles = @()
$activeCommentFiles += Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts") -Recurse -File -Filter "*.gd"
$activeCommentFiles += Get-ChildItem -LiteralPath (Join-Path $repoRoot "tools") -Recurse -File | Where-Object {
    $_.Extension -in @(".gd", ".ps1", ".py") -and $_.FullName -notmatch '[\\/]archive[\\/]'
}
$activeCommentFiles += Get-ChildItem -LiteralPath (Join-Path $repoRoot "native") -Recurse -File | Where-Object {
    $_.Extension -in @(".cpp", ".h")
}
$debtMarkerPattern = '(?i)\b(TODO|FIXME|XXX|HACK)\b'
foreach ($file in $activeCommentFiles) {
    $relative = Relative-Path $file.FullName
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber += 1
        $trimmed = $line.TrimStart()
        $isComment = $trimmed.StartsWith("#") -or $trimmed.StartsWith("//") -or $trimmed.StartsWith("/*") -or $trimmed.StartsWith("*")
        if ($isComment -and $line -match $debtMarkerPattern) {
            Add-DocumentationError "${relative}:$lineNumber contains unresolved documentation marker $($Matches[1])."
        }
    }
}

$coreCount = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts/core") -Recurse -File -Filter "*.gd").Count
$uiCount = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts/ui") -Recurse -File -Filter "*.gd").Count
$gameCount = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "scripts/games") -Recurse -File -Filter "*.gd").Count
$codeReferencePath = Join-Path $repoRoot "docs/code_reference.md"
$codeReference = Get-Content -LiteralPath $codeReferencePath -Raw
foreach ($expectedRow in @(
    "``scripts/core/`` | $coreCount",
    "``scripts/ui/`` | $uiCount",
    "``scripts/games/`` | $gameCount"
)) {
    if (-not $codeReference.Contains($expectedRow)) {
        Add-DocumentationError "docs/code_reference.md is missing current inventory row '$expectedRow'."
    }
}

foreach ($entryPath in @("README.md", "docs/README.md")) {
    $entryText = Get-Content -LiteralPath (Join-Path $repoRoot $entryPath) -Raw
    if (-not $entryText.Contains("docs/code_reference.md") -and -not $entryText.Contains("code_reference.md")) {
        Add-DocumentationError "$entryPath does not link to docs/code_reference.md."
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "PASS: audited $($productionFiles.Count) production modules, $functionCount production functions, $functionHeaderCount function-header comments, and $($activeCommentFiles.Count) active code files for stale comment markers."
