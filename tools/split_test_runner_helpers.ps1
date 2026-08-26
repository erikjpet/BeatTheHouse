$script:SplitTestRunnerOmitBeginMarker = "# SPLIT_RUNNER_OMIT_BEGIN"
$script:SplitTestRunnerOmitEndMarker = "# SPLIT_RUNNER_OMIT_END"

function Get-SplitTestRunnerOmitBeginMarker {
    return $script:SplitTestRunnerOmitBeginMarker
}

function Get-SplitTestRunnerOmitEndMarker {
    return $script:SplitTestRunnerOmitEndMarker
}

function Get-FoundationFocusedRunnerResourcePath {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$FoundationSuite
    )

    if ($FoundationSuite -ceq "blackjack") {
        return "res://scripts/tests/foundation/check_lenders_release_saves.gd"
    }
    return ""
}

function Remove-SplitTestRunnerOmittedBlocks {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines,
        [string]$SourceLabel,
        [bool]$OmitMarkedBlocks
    )

    $result = New-Object System.Collections.Generic.List[string]
    $insideOmittedBlock = $false
    foreach ($line in $Lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq $script:SplitTestRunnerOmitBeginMarker) {
            if ($insideOmittedBlock) {
                throw "Nested split-runner omit marker in ${SourceLabel}."
            }
            $insideOmittedBlock = $true
            if (-not $OmitMarkedBlocks) {
                $result.Add($line)
            }
            continue
        }
        if ($trimmed -eq $script:SplitTestRunnerOmitEndMarker) {
            if (-not $insideOmittedBlock) {
                throw "Unmatched split-runner omit end marker in ${SourceLabel}."
            }
            $insideOmittedBlock = $false
            if (-not $OmitMarkedBlocks) {
                $result.Add($line)
            }
            continue
        }
        if (-not $insideOmittedBlock -or -not $OmitMarkedBlocks) {
            $result.Add($line)
        }
    }
    if ($insideOmittedBlock) {
        throw "Unclosed split-runner omit begin marker in ${SourceLabel}."
    }
    return $result.ToArray()
}

function Get-SplitTestRunnerLines {
    param(
        [string]$ProjectRoot,
        [string[]]$SourceRelativePaths
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $sourceIndex = 0
    $omitMarkedBlocks = $SourceRelativePaths.Count -gt 1
    foreach ($relativePath in $SourceRelativePaths) {
        $source = Join-Path $ProjectRoot $relativePath
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Split test source not found: $relativePath"
        }
        if ($sourceIndex -gt 0) {
            $lines.Add("")
            $lines.Add("# --- split source: $relativePath ---")
        }
        $sourceLines = [System.IO.File]::ReadAllLines($source)
        $fileLines = @(Remove-SplitTestRunnerOmittedBlocks -Lines $sourceLines -SourceLabel $relativePath -OmitMarkedBlocks $omitMarkedBlocks)
        $lineIndex = 0
        foreach ($line in $fileLines) {
            if ($sourceIndex -gt 0 -and $lineIndex -eq 0 -and ($line -match '^extends\s+' -or $line -match '^class_name\s+')) {
                $lineIndex += 1
                continue
            }
            $lines.Add($line)
            $lineIndex += 1
        }
        $sourceIndex += 1
    }
    return $lines.ToArray()
}
