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

function Get-BlackjackFocusedSplitTestRunnerLines {
    param(
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $extendsIndexes = @()
    $initIndexes = @()
    $suiteDeclarationIndexes = @()
    $failureReportAnchorIndexes = @()
    $suiteCallIndexes = @()
    for ($index = 0; $index -lt $Lines.Count; $index += 1) {
        if ($Lines[$index] -ceq "extends SceneTree") {
            $extendsIndexes += $index
        }
        if ($Lines[$index] -match '^func _init\(\) -> void:$') {
            $initIndexes += $index
        }
        if ($Lines[$index] -match '^func _foundation_run_suite\(') {
            $suiteDeclarationIndexes += $index
        }
        if ($Lines[$index] -ceq "`tvar failures: Array = []" -and $index + 1 -lt $Lines.Count -and $Lines[$index + 1] -ceq "`tvar report := _foundation_report(_foundation_active_suite)") {
            $failureReportAnchorIndexes += ($index + 1)
        }
        if ($Lines[$index] -ceq "`t_foundation_run_suite(_foundation_active_suite, content_library, fixture_library, failures, report)") {
            $suiteCallIndexes += $index
        }
    }
    if ($extendsIndexes.Count -ne 1) {
        throw "Focused Foundation runner requires exactly one 'extends SceneTree' anchor; found $($extendsIndexes.Count)."
    }
    if ($initIndexes.Count -ne 1) {
        throw "Focused Foundation runner requires exactly one Core _init anchor; found $($initIndexes.Count)."
    }
    if ($suiteDeclarationIndexes.Count -ne 1) {
        throw "Focused Foundation runner requires exactly one _foundation_run_suite declaration; found $($suiteDeclarationIndexes.Count)."
    }
    if ($failureReportAnchorIndexes.Count -ne 1) {
        throw "Focused Foundation runner requires exactly one Core failures/report anchor; found $($failureReportAnchorIndexes.Count)."
    }
    if ($suiteCallIndexes.Count -ne 1) {
        throw "Focused Foundation runner requires exactly one Core _foundation_run_suite call anchor; found $($suiteCallIndexes.Count)."
    }
    $initEndIndex = $Lines.Count - 1
    for ($index = $initIndexes[0] + 1; $index -lt $Lines.Count; $index += 1) {
        if ($Lines[$index] -match '^func\s+') {
            $initEndIndex = $index - 1
            break
        }
    }
    if ($failureReportAnchorIndexes[0] -le $initIndexes[0] -or $failureReportAnchorIndexes[0] -gt $initEndIndex -or $suiteCallIndexes[0] -le $failureReportAnchorIndexes[0] -or $suiteCallIndexes[0] -gt $initEndIndex) {
        throw "Focused Foundation runner Core failures/report and suite-call anchors are not ordered inside _init."
    }

    $sourceText = [string]::Join("`n", $Lines)
    $generatedSymbols = @(
        "FOUNDATION_GENERATED_FOCUSED_SUITE",
        "_foundation_generated_focused_stub_call_count",
        "_foundation_generated_focused_failures_ref",
        "_foundation_generated_focused_fatal_stub",
        "scope_failure"
    )
    foreach ($symbol in $generatedSymbols) {
        if ([regex]::IsMatch($sourceText, "(?<![A-Za-z0-9_])$([regex]::Escape($symbol))(?![A-Za-z0-9_])")) {
            throw "Focused Foundation runner generated symbol collides with source token '$symbol'."
        }
    }

    $stubSignatures = @(
        "func _check_delivery_framework(library: ContentLibrary, failures: Array) -> void:",
        "func _delivery_complete_all_targets(run_state: RunState) -> bool:",
        "func _check_scratch_tickets_surface_contract(game: GameModule, failures: Array) -> void:",
        "func _check_cage_environment_rework(_library: ContentLibrary, failures: Array) -> void:",
        "func _check_coin_pusher_contract(library: ContentLibrary, failures: Array) -> void:"
    )
    foreach ($signature in $stubSignatures) {
        if ($Lines -ccontains $signature) {
            throw "Focused Foundation runner source already declares injected stub: $signature"
        }
    }

    $result = New-Object System.Collections.Generic.List[string]
    for ($index = 0; $index -lt $Lines.Count; $index += 1) {
        $result.Add($Lines[$index])
        if ($index -eq $extendsIndexes[0]) {
            $result.Add('const FOUNDATION_GENERATED_FOCUSED_SUITE := "blackjack"')
            $result.Add("var _foundation_generated_focused_stub_call_count := 0")
            $result.Add("var _foundation_generated_focused_failures_ref: Array = []")
        }
        if ($index -eq $failureReportAnchorIndexes[0]) {
            $result.Add("`tif _foundation_active_suite != FOUNDATION_GENERATED_FOCUSED_SUITE:")
            $result.Add("`t`tvar scope_failure := `"Generated focused Foundation runner only accepts suite=%s; received suite=%s.`" % [FOUNDATION_GENERATED_FOCUSED_SUITE, _foundation_active_suite]")
            $result.Add("`t`tfailures.append(scope_failure)")
            $result.Add("`t`treport[`"failure_count`"] = failures.size()")
            $result.Add("`t`treport[`"failures`"] = failures.duplicate()")
            $result.Add("`t`treport[`"passed`"] = false")
            $result.Add("`t`t_foundation_write_report(str(options.get(`"report`", FOUNDATION_DEFAULT_REPORT_PATH)), report)")
            $result.Add("`t`tpush_error(scope_failure)")
            $result.Add("`t`tquit(1)")
            $result.Add("`t`treturn")
            $result.Add("`t_foundation_generated_focused_failures_ref = failures")
        }
        if ($index -eq $suiteCallIndexes[0]) {
            $result.Add("`tif _foundation_generated_focused_stub_call_count != 0:")
            $result.Add("`t`tfailures.append(`"Generated focused Foundation runner reached %d omitted-source fatal stub(s).`" % _foundation_generated_focused_stub_call_count)")
        }
    }

    $result.Add("")
    $result.Add("")
    $result.Add("func _foundation_generated_focused_fatal_stub(symbol: String) -> void:")
    $result.Add("`t_foundation_generated_focused_stub_call_count += 1")
    $result.Add("`tvar failure := `"Generated focused Foundation runner reached omitted source symbol: %s.`" % symbol")
    $result.Add("`t_foundation_generated_focused_failures_ref.append(failure)")
    $result.Add("`tpush_error(failure)")
    $result.Add("")
    $result.Add("")
    $result.Add($stubSignatures[0])
    $result.Add("`t_foundation_generated_focused_fatal_stub(`"_check_delivery_framework`")")
    $result.Add("")
    $result.Add("")
    $result.Add($stubSignatures[1])
    $result.Add("`t_foundation_generated_focused_fatal_stub(`"_delivery_complete_all_targets`")")
    $result.Add("`treturn false")
    $result.Add("")
    $result.Add("")
    $result.Add($stubSignatures[2])
    $result.Add("`t_foundation_generated_focused_fatal_stub(`"_check_scratch_tickets_surface_contract`")")
    $result.Add("")
    $result.Add("")
    $result.Add($stubSignatures[3])
    $result.Add("`t_foundation_generated_focused_fatal_stub(`"_check_cage_environment_rework`")")
    $result.Add("")
    $result.Add("")
    $result.Add($stubSignatures[4])
    $result.Add("`t_foundation_generated_focused_fatal_stub(`"_check_coin_pusher_contract`")")
    return $result.ToArray()
}

function Get-FoundationSplitRunnerPreparationKind {
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
            return "none"
        }
        if ($script:FoundationSplitRunnerSuites -notcontains $FoundationSuite) {
            throw "Unknown normalized FoundationSuite '$FoundationSuite'."
        }
        if ($FoundationSuite -eq "blackjack") {
            return "blackjack"
        }
        return "full"
    }
    if (@("smoke", "contract", "full") -contains $Suite) {
        return "full"
    }
    return "none"
}

function Test-FoundationSplitRunnerPreparationRequired {
    param(
        [string]$Suite,
        [string]$FoundationSuite
    )

    return (Get-FoundationSplitRunnerPreparationKind -Suite $Suite -FoundationSuite $FoundationSuite) -cne "none"
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
