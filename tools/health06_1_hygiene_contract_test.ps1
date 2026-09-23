param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

function Get-ParameterCount {
    param([string]$Signature)
    $open = $Signature.IndexOf("(")
    $close = $Signature.LastIndexOf(")")
    if ($open -lt 0 -or $close -le $open) { return 0 }
    $parameters = $Signature.Substring($open + 1, $close - $open - 1)
    $depth = 0
    $count = 0
    $hasContent = $false
    foreach ($character in $parameters.ToCharArray()) {
        if ($character -in @("(", "[", "{")) { $depth++ }
        elseif ($character -in @(")", "]", "}")) { $depth-- }
        elseif ($character -eq "," -and $depth -eq 0) { $count++ }
        if (-not [char]::IsWhiteSpace($character)) { $hasContent = $true }
    }
    if ($hasContent) { $count++ }
    return $count
}

# CH-30: each live top-ten high-arity API must use a typed options object.
$topTen = @(
    @{ Path = "scripts/games/slots/slot_resolver.gd"; Name = "_spin_result" },
    @{ Path = "scripts/core/scenario_layout_resolver.gd"; Name = "_authority_record" },
    @{ Path = "scripts/games/blackjack.gd"; Name = "_blackjack_last_result_payload" },
    @{ Path = "scripts/games/slots/slot_renderer.gd"; Name = "_draw_buffalo_main_board_overlay" },
    @{ Path = "scripts/games/video_poker_renderer.gd"; Name = "_draw_hand_panel" },
    @{ Path = "scripts/core/run_state.gd"; Name = "world_sequence_command" },
    @{ Path = "scripts/core/scenario_sequence_runtime.gd"; Name = "command" },
    @{ Path = "scripts/games/bar_dice.gd"; Name = "_draw_dice_row" },
    @{ Path = "scripts/games/slots/slot_resolver.gd"; Name = "resolve_spin" },
    @{ Path = "scripts/games/video_poker.gd"; Name = "_outcome_message" }
)
foreach ($target in $topTen) {
    $source = Get-Content -LiteralPath (Join-Path $root $target.Path) -Raw
    $pattern = "(?m)^\s*(?:static\s+)?func\s+" + [regex]::Escape($target.Name) + "\s*\([^\r\n]*\)\s*(?:->[^:\r\n]+)?\s*:"
    $match = [regex]::Match($source, $pattern)
    if (-not $match.Success) {
        Add-Failure "CH-30 target signature missing: $($target.Path)::$($target.Name)"
        continue
    }
    if ((Get-ParameterCount $match.Value) -gt 5 -or $match.Value -notmatch "Options") {
        Add-Failure "CH-30 target still uses an untyped/high-arity signature: $($target.Path)::$($target.Name)"
    }
}

# CH-31: public transaction contracts use the established one-line comment style.
$transactionPath = Join-Path $root "scripts/core/scenario_host_transaction.gd"
$transactionLines = Get-Content -LiteralPath $transactionPath
for ($index = 0; $index -lt $transactionLines.Count; $index++) {
    if ($transactionLines[$index] -match '^\s*(?:static\s+)?func\s+(?<name>[A-Za-z][A-Za-z0-9_]*)\s*\(') {
        $previous = $index - 1
        while ($previous -ge 0 -and [string]::IsNullOrWhiteSpace($transactionLines[$previous])) { $previous-- }
        if ($previous -lt 0 -or $transactionLines[$previous].TrimStart() -notmatch '^#') {
            Add-Failure "CH-31 public transaction function lacks a preceding contract comment: $($Matches.name)"
        }
    }
}

# CH-32/33: archive manifests prove moves (rather than deletion) and destinations.
$toolManifestPath = Join-Path $root "tools/archive/health06_1_row_tools_manifest.json"
if (-not (Test-Path -LiteralPath $toolManifestPath)) {
    Add-Failure "CH-32 tool archive manifest is missing."
} else {
    $toolManifest = Get-Content -LiteralPath $toolManifestPath -Raw | ConvertFrom-Json
    if (@($toolManifest.moves).Count -ne 81) { Add-Failure "CH-32 manifest must contain exactly 81 moves." }
    foreach ($move in @($toolManifest.moves)) {
        if (Test-Path -LiteralPath (Join-Path $root $move.source)) { Add-Failure "CH-32 source was not moved: $($move.source)" }
        if (-not (Test-Path -LiteralPath (Join-Path $root $move.destination))) { Add-Failure "CH-32 destination is missing: $($move.destination)" }
    }

    # RP-002: a GDScript archive move must carry its stable Godot UID with it.
    # Keeping this relation in the move manifest prevents a later archive sweep
    # from recreating the same stale top-level UID identities.
    $gdMoves = @($toolManifest.moves | Where-Object { [string]$_.source -like "*.gd" })
    $uidMoves = if ($null -eq $toolManifest.companion_moves) { @() } else { @($toolManifest.companion_moves) }
    if ($uidMoves.Count -ne $gdMoves.Count) {
        Add-Failure "RP-002 manifest must pair every archived GDScript move with one UID companion move (GDScripts=$($gdMoves.Count), companions=$($uidMoves.Count))."
    } else {
        $seenUids = @{}
        foreach ($move in $gdMoves) {
            $expectedSource = "$($move.source).uid"
            $expectedDestination = "$($move.destination).uid"
            $companions = @($uidMoves | Where-Object {
                [string]$_.source -eq $expectedSource -and [string]$_.destination -eq $expectedDestination
            })
            if ($companions.Count -ne 1) {
                Add-Failure "RP-002 UID companion mapping is missing or ambiguous: $expectedSource -> $expectedDestination"
                continue
            }

            $companion = $companions[0]
            $sourcePath = Join-Path $root $companion.source
            $destinationPath = Join-Path $root $companion.destination
            if (Test-Path -LiteralPath $sourcePath) { Add-Failure "RP-002 UID source was not moved: $($companion.source)" }
            if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
                Add-Failure "RP-002 UID destination is missing: $($companion.destination)"
                continue
            }

            $uidRawText = Get-Content -LiteralPath $destinationPath -Raw
            $canonicalUidText = $uidRawText.Replace("`r`n", "`n").Replace("`r", "`n")
            if ($canonicalUidText -notmatch '^uid://[a-z0-9]+\n\z') {
                Add-Failure "RP-002 UID companion is malformed: $($companion.destination)"
                continue
            }
            $uidText = $canonicalUidText.Substring(0, $canonicalUidText.Length - 1)
            if ($seenUids.ContainsKey($uidText)) {
                Add-Failure "RP-002 duplicate archived GDScript UID '$uidText': $($seenUids[$uidText]), $($companion.destination)"
            } else {
                $seenUids[$uidText] = $companion.destination
            }

            $uidSha = [Security.Cryptography.SHA256]::Create()
            try {
                # The manifest records canonical LF text. Hashing raw checkout
                # bytes makes the same UID drift only because Git wrote CRLF.
                $canonicalBytes = [Text.Encoding]::UTF8.GetBytes($canonicalUidText)
                $actualHash = ([BitConverter]::ToString($uidSha.ComputeHash($canonicalBytes))).Replace("-", "").ToLowerInvariant()
            }
            finally { $uidSha.Dispose() }
            if ($actualHash -ne ([string]$companion.sha256).ToLowerInvariant()) {
                Add-Failure "RP-002 UID companion hash drifted: $($companion.destination)"
            }
        }

        $expectedTrackedUids = @($uidMoves | ForEach-Object { ([string]$_.destination).Replace('\', '/') } | Sort-Object -Unique)
        $actualTrackedUids = @(git -C $root ls-files "*.uid" 2>$null | ForEach-Object { ([string]$_).Trim().Replace('\', '/') } | Where-Object { $_ } | Sort-Object -Unique)
        $uidSetDifference = @(Compare-Object -ReferenceObject $expectedTrackedUids -DifferenceObject $actualTrackedUids)
        if ($uidSetDifference.Count -ne 0) {
            Add-Failure "RP-002 tracked UID set must exactly match reviewed archive companions: $($uidSetDifference | Out-String)"
        }
    }

    $gitIgnore = Get-Content -LiteralPath (Join-Path $root ".gitignore")
    if ($gitIgnore -notcontains '!tools/archive/**/*.gd.uid') {
        Add-Failure "RP-002 archived GDScript UID companions are still excluded from source control."
    }

    $validatorSource = Get-Content -LiteralPath (Join-Path $root "tools/validate_project.ps1") -Raw
    foreach ($requiredValidatorToken in @('$reviewedArchivedUidPaths', 'health06_1_row_tools_manifest.json', '$isReviewedArchivedUid', 'Generated Godot metadata must not be git-tracked')) {
        if (-not $validatorSource.Contains($requiredValidatorToken)) {
            Add-Failure "RP-002 repository validator does not admit only reviewed archive UID companions: $requiredValidatorToken"
        }
    }
}

$docsManifestPath = Join-Path $root "docs/archive/health06_1_docs_manifest.json"
if (-not (Test-Path -LiteralPath $docsManifestPath)) {
    Add-Failure "CH-33 documentation archive manifest is missing."
} else {
    $docsManifest = Get-Content -LiteralPath $docsManifestPath -Raw | ConvertFrom-Json
    if (@($docsManifest.moves).Count -lt 1) { Add-Failure "CH-33 documentation archive manifest is empty." }
    $expectedArchivePaths = [Collections.Generic.List[string]]::new()
    $seenArchivePaths = @{}
    foreach ($move in @($docsManifest.moves)) {
        $source = ([string]$move.source).Replace('\', '/').TrimStart('/')
        $destination = ([string]$move.destination).Replace('\', '/').TrimStart('/')
        if ($source -like '*.import' -or $destination -like '*.import') {
            Add-Failure "CH-33 documentation archive manifest must not claim ignored Godot import-cache files: $($move.destination)"
            continue
        }
        if ($destination -notmatch '^docs/archive/.+' -or $destination -ceq 'docs/archive/health06_1_docs_manifest.json') {
            Add-Failure "CH-33 documentation archive destination escapes the reviewed artifact set: $destination"
            continue
        }
        if ($seenArchivePaths.ContainsKey($destination)) {
            Add-Failure "CH-33 documentation archive destination is duplicated: $destination"
            continue
        }
        $seenArchivePaths[$destination] = $true
        [void]$expectedArchivePaths.Add($destination)
        if (Test-Path -LiteralPath (Join-Path $root $move.source)) { Add-Failure "CH-33 source was not moved: $($move.source)" }
        if (-not (Test-Path -LiteralPath (Join-Path $root $move.destination))) { Add-Failure "CH-33 destination is missing: $($move.destination)" }
    }
    $actualArchivePaths = @(
        git -C $root ls-files -- "docs/archive" 2>$null |
            ForEach-Object { ([string]$_).Trim().Replace('\', '/') } |
            Where-Object { $_ -and $_ -cne 'docs/archive/health06_1_docs_manifest.json' } |
            Sort-Object -Unique
    )
    $archiveSetDifference = @(Compare-Object -ReferenceObject @($expectedArchivePaths | Sort-Object -Unique) -DifferenceObject $actualArchivePaths)
    if ($archiveSetDifference.Count -ne 0) {
        Add-Failure "CH-33 manifest must exactly cover tracked docs/archive artifacts: $($archiveSetDifference | Out-String)"
    }
}

# CH-34/35: the custody decision is recorded and retention is opt-in/destructive only with confirmation.
$ledger = Get-Content -LiteralPath (Join-Path $root "docs/todo/health06_1_code_health_remediation_prompt.md") -Raw
if ($ledger -notmatch 'CH-34 branding custody decision') { Add-Failure "CH-34 branding custody decision memo is missing from the ledger." }
$retentionPath = Join-Path $root "tools/rotate_tmp_runs.ps1"
if (-not (Test-Path -LiteralPath $retentionPath)) {
    Add-Failure "CH-35 retention tool is missing."
} else {
    $retention = Get-Content -LiteralPath $retentionPath -Raw
    foreach ($required in @('SupportsShouldProcess', '[ValidateRange(1, 1000)]', '$Keep', 'ShouldProcess')) {
        if (-not $retention.Contains($required)) { Add-Failure "CH-35 retention tool lacks safety contract: $required" }
    }
}

# CH-36: repository style is explicit, enforced by validation, and production preloads use type suffixes.
$lintPath = Join-Path $root ".gdlintrc"
if (-not (Test-Path -LiteralPath $lintPath)) { Add-Failure "CH-36 .gdlintrc is missing." }
$validator = Get-Content -LiteralPath (Join-Path $root "tools/validate_project.ps1") -Raw
if ($validator -notmatch 'health06_1 gdlint') { Add-Failure "CH-36 gdlint is not wired into validate_project.ps1." }
foreach ($file in Get-ChildItem (Join-Path $root "scripts/core"),(Join-Path $root "scripts/games"),(Join-Path $root "scripts/ui") -Recurse -Filter "*.gd" -File) {
    $lineNumber = 0
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
        $lineNumber++
        if ($line -match '^const\s+(?<name>[A-Za-z0-9_]+)\s*(?::?=)\s*preload\("(?<path>[^"]+)"\)') {
            $constantName = $Matches.name
            $resourcePath = $Matches.path
            $suffix = if ($resourcePath.EndsWith(".gd")) { "Script" } elseif ($resourcePath.EndsWith(".tscn")) { "Scene" } else { "" }
            if ($suffix -and -not $constantName.EndsWith($suffix)) {
                Add-Failure "CH-36 preload constant lacks $suffix suffix: $($file.FullName):$lineNumber ($constantName)"
            }
        }
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Error $failure }
    exit 1
}

if (-not $Quiet) { Write-Host "health06_1 hygiene contract passed." }
