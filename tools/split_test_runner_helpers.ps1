$script:SplitTestRunnerOmitBeginMarker = "# SPLIT_RUNNER_OMIT_BEGIN"
$script:SplitTestRunnerOmitEndMarker = "# SPLIT_RUNNER_OMIT_END"
$script:FoundationSplitRunnerSuites = @(
    "smoke",
    "contracts",
    "games",
    "systems",
    "slot",
    "slots",
    "slot_acceptance",
    "blackjack",
    "roulette",
    "baccarat",
    "craps",
    "video_poker",
    "bar_dice",
    "crew_poker",
    "pull_tabs",
    "scratch_tickets",
    "coin_pusher",
    "audit",
    "all"
)

function Get-SplitTestRunnerOmitBeginMarker {
    return $script:SplitTestRunnerOmitBeginMarker
}

function Get-SplitTestRunnerOmitEndMarker {
    return $script:SplitTestRunnerOmitEndMarker
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

function Test-FoundationSplitRunnerPreparationRequired {
    param(
        [string]$Suite,
        [string]$FoundationSuite
    )

    if ($Suite -cne $Suite.Trim().ToLowerInvariant()) {
        throw "Suite must be normalized before split-runner selection: '$Suite'."
    }
    if ($FoundationSuite -cne $FoundationSuite.Trim().ToLowerInvariant()) {
        throw "FoundationSuite must be normalized before split-runner selection: '$FoundationSuite'."
    }
    if (@("smoke", "contract", "audit", "full") -notcontains $Suite) {
        throw "Unknown normalized Suite '$Suite'."
    }
    if (-not [string]::IsNullOrEmpty($FoundationSuite)) {
        if ($FoundationSuite -eq "ui") {
            return $false
        }
        if ($script:FoundationSplitRunnerSuites -notcontains $FoundationSuite) {
            throw "Unknown normalized FoundationSuite '$FoundationSuite'."
        }
        return $true
    }
    return @("smoke", "contract", "full") -contains $Suite
}

function Get-SplitTestRunnerBytes {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $text = [string]::Join("`r`n", $Lines) + "`r`n"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    return [byte[]]$encoding.GetBytes($text)
}

function Get-SplitTestRunnerSemanticSha256 {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $text = [string]::Join("`n", $Lines)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    return Get-SplitTestRunnerByteSha256 -Bytes ([byte[]]$encoding.GetBytes($text))
}

function Get-SplitTestRunnerByteSha256 {
    param([byte[]]$Bytes)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Test-SplitTestRunnerBytesEqual {
    param(
        [byte[]]$Left,
        [byte[]]$Right
    )

    if ($Left.Length -ne $Right.Length) {
        return $false
    }
    for ($index = 0; $index -lt $Left.Length; $index += 1) {
        if ($Left[$index] -ne $Right[$index]) {
            return $false
        }
    }
    return $true
}

function Set-SplitTestRunnerFile {
    param(
        [string]$DestinationPath,
        [string]$ResourcePath,
        [byte[]]$IntendedBytes
    )

    $fullPath = [System.IO.Path]::GetFullPath($DestinationPath)
    $parentPath = Split-Path -Parent $fullPath
    if ([string]::IsNullOrWhiteSpace($parentPath)) {
        throw "Split-runner destination has no parent directory: $DestinationPath"
    }
    [System.IO.Directory]::CreateDirectory($parentPath) | Out-Null

    $wrote = $true
    if ([System.IO.File]::Exists($fullPath)) {
        $existingBytes = [System.IO.File]::ReadAllBytes($fullPath)
        if (Test-SplitTestRunnerBytesEqual -Left $existingBytes -Right $IntendedBytes) {
            $wrote = $false
        }
    }
    if ($wrote) {
        [System.IO.File]::WriteAllBytes($fullPath, $IntendedBytes)
    }

    $verifiedBytes = [System.IO.File]::ReadAllBytes($fullPath)
    if (-not (Test-SplitTestRunnerBytesEqual -Left $verifiedBytes -Right $IntendedBytes)) {
        throw "Split-runner reread did not match the intended bytes: $fullPath"
    }
    $fileInfo = [System.IO.FileInfo]$fullPath
    $fileInfo.Refresh()
    return [pscustomobject]@{
        Path = $fullPath
        ResourcePath = $ResourcePath
        Sha256 = Get-SplitTestRunnerByteSha256 -Bytes $verifiedBytes
        Length = [long]$fileInfo.Length
        LastWriteTimeUtc = [DateTime]$fileInfo.LastWriteTimeUtc
        Wrote = $wrote
    }
}

function Get-VerifiedSplitTestRunnerResourcePath {
    param(
        [AllowNull()]
        [object]$PreparedState,
        [string]$ExpectedPath,
        [string]$ExpectedResourcePath,
        [byte[]]$IntendedBytes
    )

    if ($null -eq $PreparedState) {
        throw "Split runner was not prepared before use."
    }
    $fullExpectedPath = [System.IO.Path]::GetFullPath($ExpectedPath)
    if ([string]$PreparedState.Path -cne $fullExpectedPath) {
        throw "Prepared split-runner path drifted from '$fullExpectedPath'."
    }
    if ([string]$PreparedState.ResourcePath -cne $ExpectedResourcePath) {
        throw "Prepared split-runner resource path drifted from '$ExpectedResourcePath'."
    }

    $intendedHash = Get-SplitTestRunnerByteSha256 -Bytes $IntendedBytes
    if ([long]$PreparedState.Length -ne [long]$IntendedBytes.Length -or [string]$PreparedState.Sha256 -cne $intendedHash) {
        throw "Split-runner sources changed after preparation."
    }
    if (-not [System.IO.File]::Exists($fullExpectedPath)) {
        throw "Prepared split-runner output is missing: $fullExpectedPath"
    }

    $actualBytes = [System.IO.File]::ReadAllBytes($fullExpectedPath)
    $actualHash = Get-SplitTestRunnerByteSha256 -Bytes $actualBytes
    if ($actualBytes.Length -ne [long]$PreparedState.Length -or $actualHash -cne [string]$PreparedState.Sha256 -or -not (Test-SplitTestRunnerBytesEqual -Left $actualBytes -Right $IntendedBytes)) {
        throw "Prepared split-runner output changed after preparation: $fullExpectedPath"
    }
    $fileInfo = [System.IO.FileInfo]$fullExpectedPath
    $fileInfo.Refresh()
    if ($fileInfo.LastWriteTimeUtc.Ticks -ne ([DateTime]$PreparedState.LastWriteTimeUtc).Ticks) {
        throw "Prepared split-runner timestamp changed after preparation: $fullExpectedPath"
    }
    return $ExpectedResourcePath
}
