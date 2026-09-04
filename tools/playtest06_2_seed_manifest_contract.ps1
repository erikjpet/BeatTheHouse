param(
    [string]$ManifestPath = "tools/playtest06_2_candidate_seeds.json",
    [switch]$RequireFinal,
    [string]$ExpectedTestedCommit = ""
)

$ErrorActionPreference = "Stop"

function Add-Failure {
    param([string]$Message)
    $script:Failures.Add($Message)
}

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Require-Text {
    param($Value, [string]$Path)
    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        Add-Failure "$Path must be non-empty."
        return $false
    }
    return $true
}

function Test-Sha256Text {
    param($Value)
    return [string]$Value -cmatch '^[0-9a-f]{64}$'
}

function Test-CommitText {
    param($Value)
    return [string]$Value -cmatch '^[0-9a-f]{40}$'
}

function Invoke-GitCapture {
    param([string[]]$Arguments)
    $priorErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $lines = @(& git -C $script:Root @Arguments 2>$null | ForEach-Object { [string]$_ })
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorErrorPreference
    }
    return [pscustomobject]@{ exit_code = $exitCode; output = ($lines -join "`n") }
}

function Get-CommitTree {
    param([string]$Commit, [string]$Label)
    if (-not (Test-CommitText $Commit)) {
        Add-Failure "$Label must be a full lowercase Git commit id."
        return ""
    }
    $commitResult = Invoke-GitCapture @("cat-file", "-e", "$Commit`^{commit}")
    if ($commitResult.exit_code -ne 0) {
        Add-Failure "$Label does not resolve to a commit in this repository."
        return ""
    }
    $treeResult = Invoke-GitCapture @("rev-parse", "$Commit`^{tree}")
    $tree = ([string]$treeResult.output).Trim()
    if ($treeResult.exit_code -ne 0 -or -not (Test-CommitText $tree)) {
        Add-Failure "$Label does not resolve to an exact tree."
        return ""
    }
    return $tree
}

function Add-UniqueCatalogValue {
    param([hashtable]$Set, [string]$Value, [string]$Label)
    $clean = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) {
        Add-Failure "$Label contains an empty id."
    } elseif ($Set.ContainsKey($clean)) {
        Add-Failure "$Label contains duplicate id '$clean'."
    } else {
        $Set[$clean] = $true
    }
}

function Test-ExactSet {
    param($Expected, $Actual, [string]$Label)
    $expectedSet = @{}
    $actualSet = @{}
    foreach ($value in @(As-Array $Expected)) {
        $clean = [string]$value
        if ([string]::IsNullOrWhiteSpace($clean)) {
            Add-Failure "$Label expected set contains an empty id."
        } elseif ($expectedSet.ContainsKey($clean)) {
            Add-Failure "$Label expected set contains duplicate id '$clean'."
        } else {
            $expectedSet[$clean] = $true
        }
    }
    foreach ($value in @(As-Array $Actual)) {
        $clean = [string]$value
        if ([string]::IsNullOrWhiteSpace($clean)) {
            Add-Failure "$Label actual set contains an empty id."
        } elseif ($actualSet.ContainsKey($clean)) {
            Add-Failure "$Label actual set contains duplicate id '$clean'."
        } else {
            $actualSet[$clean] = $true
        }
    }
    foreach ($id in $expectedSet.Keys) {
        if (-not $actualSet.ContainsKey($id)) { Add-Failure "$Label is missing '$id'." }
    }
    foreach ($id in $actualSet.Keys) {
        if (-not $expectedSet.ContainsKey($id)) { Add-Failure "$Label contains unexpected '$id'." }
    }
}

function Test-StrictDate {
    param($Value, [string]$Label)
    $text = [string]$Value
    $parsed = [datetime]::MinValue
    $valid = [datetime]::TryParseExact(
        $text,
        "yyyy-MM-dd",
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )
    if (-not $valid) {
        Add-Failure "$Label must be an ISO yyyy-MM-dd date."
        return
    }
    if ($parsed.Date -gt [datetime]::UtcNow.Date) { Add-Failure "$Label cannot be in the future." }
}

function Test-NoShortcutToken {
    param($Value, [string]$Label)
    $normalized = ([string]$Value).ToUpperInvariant().Replace("-", "_").Replace(" ", "_")
    foreach ($shortcut in $script:ValidShortcuts) {
        if ($normalized.Contains($shortcut)) {
            Add-Failure "$Label contains forbidden shortcut token '$shortcut'."
        }
    }
}

function Get-GitBlobBytes {
    param([string]$BlobId, [string]$Label)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "git"
    $escapedRoot = $script:Root.Replace('"', '\"')
    $startInfo.Arguments = "-C `"$escapedRoot`" cat-file blob $BlobId"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $memory = New-Object System.IO.MemoryStream
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $process.WaitForExit()
    [void]$stderrTask.Wait(5000)
    if ($process.ExitCode -ne 0) {
        Add-Failure "$Label could not read its committed HEAD blob: $($stderrTask.Result.Trim())"
        return $null
    }
    return ,([byte[]]$memory.ToArray())
}

function Get-Sha256Bytes {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Test-ExactBytes {
    param([byte[]]$Expected, [byte[]]$Actual)
    if ($Expected.Length -ne $Actual.Length) { return $false }
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        if ($Expected[$index] -ne $Actual[$index]) { return $false }
    }
    return $true
}

function ConvertFrom-Utf8JsonBytes {
    param([byte[]]$Bytes, [string]$Label)
    try {
        $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $utf8.GetString($Bytes).TrimStart([char]0xFEFF)
        return $text | ConvertFrom-Json
    } catch {
        Add-Failure "$Label is not valid UTF-8 JSON."
        return $null
    }
}

function Resolve-CommittedRepoFile {
    param([string]$Path, [string]$Label, [string]$RequiredPrefix = "")
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Add-Failure "$Label.path must be non-empty."
        return $null
    }
    if ([IO.Path]::IsPathRooted($Path)) {
        Add-Failure "$Label.path must be repository-relative."
        return $null
    }
    try {
        $candidate = [IO.Path]::GetFullPath((Join-Path $script:Root $Path))
    } catch {
        Add-Failure "$Label.path is invalid: $Path"
        return $null
    }
    $rootPrefix = $script:Root.TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Add-Failure "$Label.path must remain inside the repository: $Path"
        return $null
    }
    $gitPath = $candidate.Substring($script:Root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
    if (-not [string]::IsNullOrWhiteSpace($RequiredPrefix)) {
        $cleanPrefix = $RequiredPrefix.Trim('/').Replace('\', '/') + "/"
        if (-not $gitPath.StartsWith($cleanPrefix, [StringComparison]::Ordinal)) {
            Add-Failure "$Label.path must remain under $RequiredPrefix`: $Path"
            return $null
        }
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        Add-Failure "$Label.path does not exist: $Path"
        return $null
    }
    $blobResult = Invoke-GitCapture @("rev-parse", "--verify", "HEAD:$gitPath")
    $blobId = ([string]$blobResult.output).Trim()
    if ($blobResult.exit_code -ne 0 -or -not (Test-CommitText $blobId)) {
        Add-Failure "$Label.path must be Git-tracked and committed at HEAD: $gitPath"
        return $null
    }
    $indexResult = Invoke-GitCapture @("rev-parse", "--verify", ":$gitPath")
    $indexBlobId = ([string]$indexResult.output).Trim()
    if ($indexResult.exit_code -ne 0 -or -not (Test-CommitText $indexBlobId)) {
        Add-Failure "$Label.path must resolve to a file blob in the Git index: $gitPath"
        return $null
    }
    if ($indexBlobId -cne $blobId) {
        Add-Failure "$Label.path Git index blob does not exactly match the committed HEAD blob: $gitPath"
        return $null
    }
    $typeResult = Invoke-GitCapture @("cat-file", "-t", $blobId)
    $blobType = ([string]$typeResult.output).Trim()
    if ($typeResult.exit_code -ne 0 -or $blobType -cne "blob") {
        Add-Failure "$Label.path does not resolve to a committed file blob at HEAD: $gitPath"
        return $null
    }
    [byte[]]$committedBytes = Get-GitBlobBytes $blobId $Label
    if ($null -eq $committedBytes) { return $null }
    [byte[]]$workingBytes = [IO.File]::ReadAllBytes($candidate)
    if (-not (Test-ExactBytes $committedBytes $workingBytes)) {
        Add-Failure "$Label.path working-tree bytes do not exactly match the committed HEAD blob: $gitPath"
        return $null
    }
    return [pscustomobject]@{
        full_path = $candidate
        git_path = $gitPath
        blob_id = $blobId
        bytes = $committedBytes
        sha256 = Get-Sha256Bytes $committedBytes
    }
}

function Resolve-CommittedEvidence {
    param([string]$Path, [string]$Label)
    return Resolve-CommittedRepoFile $Path $Label $script:EvidenceRootRelative
}

function New-CoverageSets {
    return @{
        coverage_slots = @{}
        archetype_ids = @{}
        layer_ids = @{}
        game_ids = @{}
        pusher_machine_ids = @{}
        scenario_ids = @{}
        scenario_branch_ids = @{}
    }
}

function Add-CoverageValues {
    param([hashtable]$Target, $Coverage)
    foreach ($field in $Target.Keys) {
        foreach ($value in @(As-Array $Coverage.$field)) {
            $clean = ([string]$value).Trim()
            if (-not [string]::IsNullOrWhiteSpace($clean)) { $Target[$field][$clean] = $true }
        }
    }
}

$Failures = [Collections.Generic.List[string]]::new()
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EvidenceRootRelative = "docs/plans/evidence/playtest06_2"
$EvidenceRoot = [IO.Path]::GetFullPath((Join-Path $Root $EvidenceRootRelative))
$CanonicalFinalManifestRelative = "$EvidenceRootRelative/final_seed_manifest.json"
$ValidShortcuts = @(
    "PREVALIDATED_TRAVEL",
    "DEBUG_ACTION",
    "DIRECT_STATE_EDIT",
    "SAVE_EDIT",
    "TELEPORT",
    "BANKROLL_OVERRIDE",
    "INVITATION_INJECTION",
    "SYNTHETIC_COLLECTION_PROGRESS"
)
$validStages = @("PRESTAGE", "FINAL")
$validStatuses = @("CANDIDATE", "VERIFIED", "BLOCKED")
$validAuthorities = @("PRODUCTION_PUBLIC_ACTIONS", "HEADLESS_PRODUCTION_ACTIONS", "DIAGNOSTIC_PREVALIDATED_TRAVEL")
$validPlatforms = @("WINDOWS_NATIVE", "WEB_CHROME", "WINDOWS_NATIVE_AND_WEB_CHROME")
$validSessionPlatforms = @("WINDOWS_NATIVE", "WEB_CHROME")
$validEvidenceKinds = @("OWNER_SESSION_REPORT", "SCREENSHOT", "VIDEO", "RUNTIME_TRACE", "SAVE_ROUNDTRIP_REPORT")
$requiredSlots = @(
    "ARCHETYPES",
    "PUNCHLINE-LAYERS",
    "SCENARIO-REPRESENTATIVE",
    "SCENARIO-BRANCHES",
    "GAMES",
    "PUSHER-MACHINES",
    "CREW-RECRUIT",
    "HEIST-PLAN-A",
    "HEIST-PLAN-B",
    "TURN-FIRES",
    "TURN-NO-FIRE",
    "CASS-END-1",
    "CASS-END-2",
    "CASS-END-3",
    "VICTORY-ROUTE-1",
    "VICTORY-ROUTE-2",
    "VICTORY-CREW",
    "CREW-IGNORING",
    "NUMBERS-ROUTES",
    "SWEEP",
    "DELIVERY",
    "SAVE-BOUNDARIES",
    "COMPOSITION-MAX",
    "FULL-RUN-CONTROLS"
)

$resolvedManifest = if ([IO.Path]::IsPathRooted($ManifestPath)) {
    [IO.Path]::GetFullPath($ManifestPath)
} else {
    [IO.Path]::GetFullPath((Join-Path $Root $ManifestPath))
}
if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) { throw "Seed manifest not found: $resolvedManifest" }
try { $manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json }
catch { throw "Seed manifest is not valid JSON: $($_.Exception.Message)" }

if ([string]$manifest.stage -eq "FINAL") {
    $canonicalFinalManifest = [IO.Path]::GetFullPath((Join-Path $Root $CanonicalFinalManifestRelative))
    if ($resolvedManifest -cne $canonicalFinalManifest) {
        Add-Failure "FINAL manifest must use canonical path $CanonicalFinalManifestRelative."
    } else {
        $committedManifest = Resolve-CommittedRepoFile $CanonicalFinalManifestRelative "FINAL manifest" $EvidenceRootRelative
        if ($null -ne $committedManifest) {
            $manifest = ConvertFrom-Utf8JsonBytes ([byte[]]$committedManifest.bytes) "FINAL manifest"
        }
    }
}

function Get-ExpectedCoverageOutcomeType {
    param([string]$Field, [string]$Id)
    switch ($Field) {
        "archetype_ids" { return "ARCHETYPE_ENTERED" }
        "layer_ids" { return "LAYER_ENTERED" }
        "game_ids" { return "GAME_ENTRY_ACTION_SETTLEMENT_EXIT" }
        "pusher_machine_ids" { return "PUSHER_DEFINING_GOAL_COMPLETED" }
        "scenario_ids" { return "SCENARIO_ENTERED" }
        "scenario_branch_ids" { return "SCENARIO_BRANCH_AFTERMATH_OBSERVED" }
        "coverage_slots" {
            if ($Id -like "HEIST-PLAN-*") { return "HEIST_TERMINAL_OR_ABORT" }
            if ($Id -like "TURN-*") { return "TURN_OUTCOME_OBSERVED" }
            if ($Id -like "CASS-END-*") { return "CASS_ENDING_OBSERVED" }
            if ($Id -like "VICTORY-*") { return "TERMINAL_PROFILE_HANDOFF" }
            if ($Id -eq "SAVE-BOUNDARIES") { return "SAVE_ROUNDTRIP" }
            if ($Id -eq "FULL-RUN-CONTROLS") { return "FULL_RUN_TERMINAL" }
            if ($Id -eq "PUSHER-MACHINES") { return "PUSHER_DEFINING_GOAL_COMPLETED" }
            if ($Id -eq "GAMES") { return "GAME_ENTRY_ACTION_SETTLEMENT_EXIT" }
            if ($Id -eq "SCENARIO-BRANCHES") { return "SCENARIO_BRANCH_AFTERMATH_OBSERVED" }
            return "ROUTE_REQUIREMENT_OBSERVED"
        }
    }
    return ""
}

function Test-OwnerBuildPlatform {
    param($PlatformRecord, [string]$Label, [string]$ExpectedPlatform, [string]$RequiredRoot, [string]$RequiredNativeSuffix)
    if ($null -eq $PlatformRecord) {
        Add-Failure "$Label is missing."
        return
    }
    if ([string]$PlatformRecord.platform -cne $ExpectedPlatform) { Add-Failure "$Label.platform must be $ExpectedPlatform." }
    if ($PlatformRecord.smoke_passed -isnot [bool] -or -not [bool]$PlatformRecord.smoke_passed) { Add-Failure "$Label.smoke_passed must be true." }
    if ([string]$PlatformRecord.output_root -cne $RequiredRoot) { Add-Failure "$Label.output_root must be $RequiredRoot." }
    $smokePath = [string]$PlatformRecord.smoke_evidence.path
    if (-not (Test-Sha256Text $PlatformRecord.smoke_evidence.sha256)) { Add-Failure "$Label.smoke_evidence.sha256 must be a lowercase SHA-256." }
    $smokeEvidence = Resolve-CommittedEvidence $smokePath "$Label.smoke_evidence"
    $smoke = $null
    if ($null -ne $smokeEvidence -and [string]$smokeEvidence.sha256 -cne [string]$PlatformRecord.smoke_evidence.sha256) {
        Add-Failure "$Label.smoke_evidence SHA-256 does not match its committed HEAD blob."
    } elseif ($null -ne $smokeEvidence) {
        $smoke = ConvertFrom-Utf8JsonBytes ([byte[]]$smokeEvidence.bytes) "$Label.smoke_evidence"
    }
    $files = @(As-Array $PlatformRecord.files)
    if ($files.Count -eq 0) { Add-Failure "$Label.files must contain every local build output." }
    $paths = @{}
    $foundNative = $false
    foreach ($file in $files) {
        $path = [string]$file.path
        $fileLabel = "$Label.files[$path]"
        if ([IO.Path]::IsPathRooted($path) -or -not $path.StartsWith("$RequiredRoot/", [StringComparison]::Ordinal)) {
            Add-Failure "$fileLabel must be repository-relative under $RequiredRoot."
            continue
        }
        if ($paths.ContainsKey($path)) { Add-Failure "$Label contains duplicate build output '$path'." } else { $paths[$path] = $true }
        if (-not (Test-Sha256Text $file.sha256)) { Add-Failure "$fileLabel.sha256 must be a lowercase SHA-256." }
        if ([int64]$file.bytes -lt 1) { Add-Failure "$fileLabel.bytes must be positive." }
        $full = [IO.Path]::GetFullPath((Join-Path $script:Root $path))
        $rootPrefix = [IO.Path]::GetFullPath((Join-Path $script:Root $RequiredRoot)).TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
        if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Add-Failure "$fileLabel local build output is missing."
            continue
        }
        $info = Get-Item -LiteralPath $full
        if ([int64]$info.Length -ne [int64]$file.bytes) { Add-Failure "$fileLabel byte length does not match the local build." }
        $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -cne [string]$file.sha256) { Add-Failure "$fileLabel SHA-256 does not match the local build." }
        if ($path.EndsWith($RequiredNativeSuffix, [StringComparison]::OrdinalIgnoreCase) -and ([IO.Path]::GetFileName($path) -like "coin_pusher_native*")) { $foundNative = $true }
    }
    $actualRoot = [IO.Path]::GetFullPath((Join-Path $script:Root $RequiredRoot))
    $actualPaths = @()
    if (Test-Path -LiteralPath $actualRoot -PathType Container) {
        $actualPaths = @(Get-ChildItem -LiteralPath $actualRoot -File -Recurse | ForEach-Object {
            $_.FullName.Substring($script:Root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
        })
    }
    Test-ExactSet @($paths.Keys) $actualPaths "$Label declared versus local build outputs"
    if (-not $foundNative) { Add-Failure "$Label is missing the locked Coin Pusher native solver output ($RequiredNativeSuffix)." }
    $buildPrefix = $RequiredRoot.TrimEnd('/') + "/"
    $canonicalRows = @($files | Sort-Object { [string]$_.path } | ForEach-Object { "{0}`t{1}`t{2}" -f ([string]$_.path).Substring($buildPrefix.Length), [int64]$_.bytes, [string]$_.sha256 })
    $exportIdentity = Get-Sha256Bytes ([Text.Encoding]::UTF8.GetBytes(($canonicalRows -join "`n")))
    if ([string]$PlatformRecord.export_identity_sha256 -cne $exportIdentity) { Add-Failure "$Label.export_identity_sha256 does not match the complete build output set." }
    if ($null -ne $smoke) {
        if ([string]$smoke.schema -cne "beat_the_house.playtest06_owner_build_smoke/v1") { Add-Failure "$Label.smoke_evidence has the wrong schema." }
        if ([string]$smoke.candidate_commit -cne $script:ExpectedTestedCommit -or [string]$smoke.candidate_tree -cne $script:expectedTree) { Add-Failure "$Label.smoke_evidence candidate identity does not match the tested candidate." }
        if ([string]$smoke.platform -cne $ExpectedPlatform) { Add-Failure "$Label.smoke_evidence platform does not match $ExpectedPlatform." }
        if ($smoke.passed -isnot [bool] -or -not [bool]$smoke.passed) { Add-Failure "$Label.smoke_evidence passed must be true." }
        if ([string]$smoke.export_identity_sha256 -cne $exportIdentity) { Add-Failure "$Label.smoke_evidence export identity does not match the complete build output set." }
    }
}

if ([int]$manifest.schema_version -ne 2) { Add-Failure "schema_version must be 2." }
if ($validStages -notcontains [string]$manifest.stage) { Add-Failure "stage must be PRESTAGE or FINAL." }
if ([string]$manifest.stage -eq "FINAL" -and -not $RequireFinal) {
    Add-Failure "A FINAL manifest must be invoked with -RequireFinal and -ExpectedTestedCommit."
}
if ($RequireFinal -and [string]$manifest.stage -ne "FINAL") { Add-Failure "-RequireFinal requires stage FINAL." }
if ($RequireFinal -and -not (Test-CommitText $ExpectedTestedCommit)) {
    Add-Failure "-RequireFinal requires -ExpectedTestedCommit as a full lowercase Git commit id."
}
$expectedTree = ""
if ($RequireFinal -and (Test-CommitText $ExpectedTestedCommit)) {
    $expectedTree = Get-CommitTree $ExpectedTestedCommit "ExpectedTestedCommit"
}

$candidateCommit = [string]$manifest.candidate_base_commit
$candidateTree = [string]$manifest.candidate_base_tree
$actualCandidateTree = Get-CommitTree $candidateCommit "candidate_base_commit"
if (-not (Test-CommitText $candidateTree)) {
    Add-Failure "candidate_base_tree must be a full lowercase Git tree id."
} elseif ($actualCandidateTree -and $candidateTree -cne $actualCandidateTree) {
    Add-Failure "candidate_base_tree does not match candidate_base_commit."
}
if ($RequireFinal -and $expectedTree) {
    $worktreeDiff = Invoke-GitCapture @("diff", "--quiet")
    if ($worktreeDiff.exit_code -ne 0) { Add-Failure "FINAL requires a clean tracked working tree." }
    $indexDiff = Invoke-GitCapture @("diff", "--cached", "--quiet")
    if ($indexDiff.exit_code -ne 0) { Add-Failure "FINAL requires a clean Git index." }
    if ($candidateCommit -cne $ExpectedTestedCommit) { Add-Failure "FINAL candidate_base_commit does not equal ExpectedTestedCommit." }
    if ($candidateTree -cne $expectedTree) { Add-Failure "FINAL candidate_base_tree does not equal ExpectedTestedCommit's tree." }
    $ancestor = Invoke-GitCapture @("merge-base", "--is-ancestor", $candidateCommit, "HEAD")
    if ($ancestor.exit_code -ne 0) {
        Add-Failure "FINAL candidate_base_commit must be an ancestor of the custody HEAD."
    } else {
        $allowedExactDeltas = @(
            "docs/plans/playtest06_2_playtest_script.md",
            "docs/plans/playtest06_2_findings_capture.md",
            "docs/plans/0.6_playtest_handoff.md",
            "docs/todo/playtest06_1_playtest_readiness_prompt.md",
            "docs/todo/playtest06_2_playtest_gate_refresh_prompt.md",
            "docs/todo/README_0_6_board.md",
            "docs/todo/README_0_6_work_log_2026-08-26.md",
            "docs/todone/playtest06_2_playtest_gate_refresh_prompt.md"
        )
        $deltaResult = Invoke-GitCapture @("diff", "--name-only", $candidateCommit, "HEAD", "--")
        if ($deltaResult.exit_code -ne 0) {
            Add-Failure "FINAL could not enumerate candidate-to-custody deltas."
        } else {
            foreach ($deltaPath in @(([string]$deltaResult.output -split "`n") | Where-Object { $_ })) {
                $allowed = $deltaPath.StartsWith("$EvidenceRootRelative/", [StringComparison]::Ordinal) -or $allowedExactDeltas -ccontains $deltaPath
                if (-not $allowed) {
                    Add-Failure "FINAL candidate-to-custody delta is outside declared playtest evidence/docs: $deltaPath"
                }
            }
        }
    }
}
Require-Text $manifest.purpose "purpose" | Out-Null

$gameCatalog = Get-Content -LiteralPath (Join-Path $Root "data/games/games.json") -Raw | ConvertFrom-Json
$archetypeCatalog = Get-Content -LiteralPath (Join-Path $Root "data/environments/archetypes.json") -Raw | ConvertFrom-Json
$scenarioCatalog = Get-Content -LiteralPath (Join-Path $Root "data/environments/scenarios.json") -Raw | ConvertFrom-Json
$scenarioFiles = Get-ChildItem -LiteralPath (Join-Path $Root "data/environments/scenario_sequences") -Filter "*.json" -File

$knownGameSet = @{}
foreach ($definition in @($gameCatalog)) { Add-UniqueCatalogValue $knownGameSet ([string]$definition.id) "game catalog" }
$knownGames = @($knownGameSet.Keys | Sort-Object)
$knownArchetypeSet = @{}
$knownLayerSet = @{}
foreach ($definition in @($archetypeCatalog)) {
    $archetypeId = [string]$definition.id
    Add-UniqueCatalogValue $knownArchetypeSet $archetypeId "archetype catalog"
    if ($definition.PSObject.Properties.Name -contains "layers" -and $null -ne $definition.layers) {
        foreach ($layer in $definition.layers.PSObject.Properties) {
            Add-UniqueCatalogValue $knownLayerSet ("${archetypeId}::$($layer.Name)") "environment layer catalog"
        }
    }
}
$knownArchetypes = @($knownArchetypeSet.Keys | Sort-Object)
$knownLayers = @($knownLayerSet.Keys | Sort-Object)
$requiredPunchlineLayers = @(
    "small_underground_casino::club",
    "small_underground_casino::casino",
    "small_underground_casino::back_room"
)
foreach ($layerId in $requiredPunchlineLayers) {
    if (-not $knownLayerSet.ContainsKey($layerId)) { Add-Failure "required Punchline layer '$layerId' is missing from the archetype catalog." }
}

$knownScenarioSet = @{}
$scenarioPoolById = @{}
$scenarioPools = @{}
foreach ($pool in $scenarioCatalog.PSObject.Properties) {
    $poolId = [string]$pool.Name
    $scenarioPools[$poolId] = @()
    foreach ($definition in @(As-Array $pool.Value)) {
        $scenarioId = [string]$definition.id
        Add-UniqueCatalogValue $knownScenarioSet $scenarioId "scenario catalog"
        if (-not [string]::IsNullOrWhiteSpace($scenarioId)) {
            $scenarioPoolById[$scenarioId] = $poolId
            $scenarioPools[$poolId] = @($scenarioPools[$poolId]) + $scenarioId
        }
    }
}
$knownScenarios = @($knownScenarioSet.Keys | Sort-Object)

$sequenceScenarioSet = @{}
$knownScenarioBranchSet = @{}
$branchesByScenario = @{}
foreach ($scenarioFile in $scenarioFiles) {
    $package = Get-Content -LiteralPath $scenarioFile.FullName -Raw | ConvertFrom-Json
    foreach ($scenario in @(As-Array $package.scenarios)) {
        $scenarioId = [string]$scenario.scenario_id
        Add-UniqueCatalogValue $sequenceScenarioSet $scenarioId "scenario sequence catalog"
        $branchesByScenario[$scenarioId] = @()
        if ($scenario.sequence.PSObject.Properties.Name -contains "phase_graph" -and $null -ne $scenario.sequence.phase_graph) {
            foreach ($phase in @(As-Array $scenario.sequence.phase_graph.phases)) {
                foreach ($branch in @(As-Array $phase.branches)) {
                    $branchId = [string]$branch.id
                    Add-UniqueCatalogValue $knownScenarioBranchSet $branchId "scenario branch catalog"
                    if (-not [string]::IsNullOrWhiteSpace($branchId)) {
                        $branchesByScenario[$scenarioId] = @($branchesByScenario[$scenarioId]) + $branchId
                    }
                }
            }
        }
        if (@($branchesByScenario[$scenarioId]).Count -eq 0) {
            Add-Failure "scenario '$scenarioId' has no authored phase-graph branches."
        }
    }
}
$knownScenarioBranches = @($knownScenarioBranchSet.Keys | Sort-Object)
foreach ($scenarioId in $knownScenarios) {
    if (-not $sequenceScenarioSet.ContainsKey($scenarioId)) { Add-Failure "scenario '$scenarioId' has no scenario-sequence package." }
}
foreach ($scenarioId in $sequenceScenarioSet.Keys) {
    if (-not $knownScenarioSet.ContainsKey($scenarioId)) { Add-Failure "scenario sequence '$scenarioId' is absent from scenarios.json." }
}
$knownPusherMachines = @("quarter_falls", "jackpot_ridge", "vault_drop")

$representativeScenarioTargets = @(As-Array $manifest.coverage_policy.representative_scenario_ids)
$materialBranchTargets = @(As-Array $manifest.coverage_policy.material_scenario_branch_ids)
foreach ($scenarioId in $representativeScenarioTargets) {
    if (-not $knownScenarioSet.ContainsKey([string]$scenarioId)) { Add-Failure "coverage_policy references unknown scenario '$scenarioId'." }
}
foreach ($branchId in $materialBranchTargets) {
    if (-not $knownScenarioBranchSet.ContainsKey([string]$branchId)) { Add-Failure "coverage_policy references unknown scenario branch '$branchId'." }
}
if ($RequireFinal) {
    if ($representativeScenarioTargets.Count -eq 0) { Add-Failure "FINAL requires a non-empty representative_scenario_ids policy." }
    foreach ($poolId in $scenarioPools.Keys) {
        $covered = @($scenarioPools[$poolId] | Where-Object { $representativeScenarioTargets -contains $_ })
        if ($covered.Count -eq 0) { Add-Failure "FINAL representative scenarios do not cover scenario pool '$poolId'." }
    }
    $expectedBranches = @()
    foreach ($scenarioId in $representativeScenarioTargets) {
        $expectedBranches += @(As-Array $branchesByScenario[[string]$scenarioId])
    }
    Test-ExactSet $expectedBranches $materialBranchTargets "coverage_policy material scenario branches"
}

$ownerBuildManifestHash = ""
if ($RequireFinal) {
    if ($null -eq $manifest.owner_build_evidence) {
        Add-Failure "FINAL requires owner_build_evidence."
    } else {
        $ownerBuildPath = [string]$manifest.owner_build_evidence.path
        if ($ownerBuildPath -cne "$EvidenceRootRelative/owner_build_manifest.json") {
            Add-Failure "FINAL owner_build_evidence.path must be $EvidenceRootRelative/owner_build_manifest.json."
        }
        if (-not (Test-Sha256Text $manifest.owner_build_evidence.sha256)) {
            Add-Failure "FINAL owner_build_evidence.sha256 must be a lowercase SHA-256."
        }
        $committedBuild = Resolve-CommittedEvidence $ownerBuildPath "owner_build_evidence"
        if ($null -ne $committedBuild) {
            $ownerBuildManifestHash = [string]$committedBuild.sha256
            if ($ownerBuildManifestHash -cne [string]$manifest.owner_build_evidence.sha256) {
                Add-Failure "owner_build_evidence SHA-256 does not match its committed HEAD blob."
            }
            $ownerBuild = ConvertFrom-Utf8JsonBytes ([byte[]]$committedBuild.bytes) "owner_build_evidence"
            if ($null -ne $ownerBuild) {
                if ([string]$ownerBuild.schema -cne "beat_the_house.playtest06_owner_build/v1") { Add-Failure "owner_build_evidence has the wrong schema." }
                if ([string]$ownerBuild.candidate_commit -cne $ExpectedTestedCommit) { Add-Failure "owner_build_evidence candidate_commit does not match ExpectedTestedCommit." }
                if ([string]$ownerBuild.candidate_tree -cne $expectedTree) { Add-Failure "owner_build_evidence candidate_tree does not match ExpectedTestedCommit's tree." }
                foreach ($field in @("builder_script_sha256", "godot_sha256", "toolchain_lock_sha256", "export_presets_sha256")) {
                    if (-not (Test-Sha256Text $ownerBuild.$field)) { Add-Failure "owner_build_evidence.$field must be a lowercase SHA-256." }
                }
                foreach ($field in @("distribution_artifact", "archive_created", "upload_performed")) {
                    if ($ownerBuild.$field -isnot [bool] -or [bool]$ownerBuild.$field) { Add-Failure "owner_build_evidence.$field must be false." }
                }
                foreach ($input in @(
                    @{ path = "tools/playtest06_owner_build.ps1"; hash = [string]$ownerBuild.builder_script_sha256; label = "builder_script_sha256" },
                    @{ path = "native/coin_pusher/toolchain.lock.json"; hash = [string]$ownerBuild.toolchain_lock_sha256; label = "toolchain_lock_sha256" },
                    @{ path = "export_presets.cfg"; hash = [string]$ownerBuild.export_presets_sha256; label = "export_presets_sha256" }
                )) {
                    $inputPath = Join-Path $Root $input.path
                    if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
                        Add-Failure "owner_build_evidence input is missing: $($input.path)"
                    } elseif ((Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $input.hash) {
                        Add-Failure "owner_build_evidence.$($input.label) does not match $($input.path)."
                    }
                }
                $requiredOwnerTools = @(
                    "tools/playtest06_owner_build.ps1",
                    "tools/export_itch.ps1",
                    "tools/build_native_solver.ps1",
                    "tools/verify_native_solver_runtime.ps1",
                    "tools/web_perf_smoke.ps1",
                    "tools/web_perf_export_mode.ps1",
                    "tools/l02_web_perf_probe.mjs",
                    "tools/serve_web.ps1"
                )
                $actualOwnerTools = @()
                $ownerToolPaths = @{}
                foreach ($toolEntry in @(As-Array $ownerBuild.tool_hashes)) {
                    $toolPath = [string]$toolEntry.path
                    $actualOwnerTools += $toolPath
                    if ($ownerToolPaths.ContainsKey($toolPath)) { Add-Failure "owner_build_evidence.tool_hashes contains duplicate '$toolPath'." } else { $ownerToolPaths[$toolPath] = $true }
                    if ([IO.Path]::IsPathRooted($toolPath) -or -not $toolPath.StartsWith("tools/", [StringComparison]::Ordinal)) {
                        Add-Failure "owner_build_evidence.tool_hashes path must be repository-relative under tools/: $toolPath"
                        continue
                    }
                    if (-not (Test-Sha256Text $toolEntry.sha256)) { Add-Failure "owner_build_evidence.tool_hashes[$toolPath].sha256 must be a lowercase SHA-256."; continue }
                    $toolFullPath = Join-Path $Root $toolPath
                    if (-not (Test-Path -LiteralPath $toolFullPath -PathType Leaf)) {
                        Add-Failure "owner_build_evidence.tool_hashes file is missing: $toolPath"
                    } elseif ((Get-FileHash -LiteralPath $toolFullPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$toolEntry.sha256) {
                        Add-Failure "owner_build_evidence.tool_hashes[$toolPath] does not match the local tool."
                    }
                }
                Test-ExactSet $requiredOwnerTools $actualOwnerTools "owner_build_evidence required tool hashes"
                $lockPath = Join-Path $Root "native/coin_pusher/toolchain.lock.json"
                if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
                    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
                    if (-not (Test-Sha256Text $ownerBuild.web_template_sha256)) {
                        Add-Failure "owner_build_evidence.web_template_sha256 must be a lowercase SHA-256."
                    } elseif ([string]$ownerBuild.web_template_sha256 -cne [string]$lock.web.template_sha256) {
                        Add-Failure "owner_build_evidence.web_template_sha256 does not match the locked Web template identity."
                    }
                }
                $godotPath = [string]$ownerBuild.godot_path
                if (-not [IO.Path]::IsPathRooted($godotPath) -or -not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
                    Add-Failure "owner_build_evidence.godot_path must identify the local engine used for the build."
                } elseif ((Get-FileHash -LiteralPath $godotPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$ownerBuild.godot_sha256) {
                    Add-Failure "owner_build_evidence.godot_sha256 does not match the local engine binary."
                }
                Test-OwnerBuildPlatform $ownerBuild.windows "owner_build_evidence.windows" "WINDOWS_NATIVE" "builds/windows" ".dll"
                Test-OwnerBuildPlatform $ownerBuild.web "owner_build_evidence.web" "WEB_CHROME" "builds/web" ".wasm"
            }
        }
    }
}

$seedIds = @{}
$seedValues = @{}
$verifiedCoverage = New-CoverageSets
$verifiedPlatforms = @{}
$seeds = @(As-Array $manifest.seeds)
if ($seeds.Count -eq 0) { Add-Failure "seeds must contain at least one record." }

foreach ($seed in $seeds) {
    $id = [string]$seed.id
    $value = [string]$seed.seed
    Require-Text $id "seeds[].id" | Out-Null
    Require-Text $value "seeds[$id].seed" | Out-Null
    Require-Text $seed.purpose "seeds[$id].purpose" | Out-Null
    Require-Text $seed.source_evidence "seeds[$id].source_evidence" | Out-Null
    Require-Text $seed.pending_verification "seeds[$id].pending_verification" | Out-Null
    if ($seedIds.ContainsKey($id)) { Add-Failure "Duplicate seed id '$id'." } else { $seedIds[$id] = $true }
    if ($seedValues.ContainsKey($value)) { Add-Failure "Duplicate seed value '$value'." } else { $seedValues[$value] = $true }
    if ($validStatuses -notcontains [string]$seed.status) { Add-Failure "seeds[$id].status is invalid." }
    if ([string]$manifest.stage -eq "PRESTAGE" -and [string]$seed.status -eq "VERIFIED") {
        Add-Failure "PRESTAGE cannot contain VERIFIED seed '$id'."
    }
    if ($validAuthorities -notcontains [string]$seed.route_authority) { Add-Failure "seeds[$id].route_authority is invalid." }
    if ($seed.PSObject.Properties.Name -notcontains "route_shortcuts") { Add-Failure "seeds[$id].route_shortcuts must be explicit, even when empty." }
    foreach ($shortcut in @(As-Array $seed.route_shortcuts)) {
        if ($ValidShortcuts -notcontains [string]$shortcut) { Add-Failure "seeds[$id] references unknown route shortcut '$shortcut'." }
    }
    if (($seed.owner_playtest_eligible -isnot [bool])) {
        Add-Failure "seeds[$id].owner_playtest_eligible must be a JSON boolean."
    } elseif ([bool]$seed.owner_playtest_eligible -and [string]$seed.route_authority -ne "PRODUCTION_PUBLIC_ACTIONS") {
        Add-Failure "seeds[$id] cannot be owner-playtest eligible without PRODUCTION_PUBLIC_ACTIONS authority."
    }

    foreach ($slot in @(As-Array $seed.coverage_slots)) {
        if ($requiredSlots -notcontains [string]$slot) { Add-Failure "seeds[$id] references unknown coverage slot '$slot'." }
    }
    foreach ($archetypeId in @(As-Array $seed.archetype_ids)) {
        if (-not $knownArchetypeSet.ContainsKey([string]$archetypeId)) { Add-Failure "seeds[$id] references unknown archetype '$archetypeId'." }
    }
    foreach ($layerId in @(As-Array $seed.layer_ids)) {
        if (-not $knownLayerSet.ContainsKey([string]$layerId)) { Add-Failure "seeds[$id] references unknown environment layer '$layerId'." }
    }
    foreach ($gameId in @(As-Array $seed.game_ids)) {
        if (-not $knownGameSet.ContainsKey([string]$gameId)) { Add-Failure "seeds[$id] references unknown game '$gameId'." }
    }
    foreach ($machineId in @(As-Array $seed.pusher_machine_ids)) {
        if ($knownPusherMachines -notcontains [string]$machineId) { Add-Failure "seeds[$id] references unknown pusher machine '$machineId'." }
    }
    foreach ($scenarioId in @(As-Array $seed.scenario_ids)) {
        if (-not $knownScenarioSet.ContainsKey([string]$scenarioId)) { Add-Failure "seeds[$id] references unknown scenario '$scenarioId'." }
    }
    foreach ($branchId in @(As-Array $seed.scenario_branch_ids)) {
        if (-not $knownScenarioBranchSet.ContainsKey([string]$branchId)) { Add-Failure "seeds[$id] references unknown scenario branch '$branchId'." }
    }

    if ([string]$seed.status -ne "VERIFIED") { continue }
    if ([string]$seed.route_authority -ne "PRODUCTION_PUBLIC_ACTIONS") {
        Add-Failure "seeds[$id] VERIFIED owner coverage must use PRODUCTION_PUBLIC_ACTIONS."
    }
    if (@(As-Array $seed.route_shortcuts).Count -gt 0) {
        Add-Failure "seeds[$id] VERIFIED owner coverage cannot use debug, injection, edit, teleport, override, or prevalidated-travel shortcuts."
    }
    if ($seed.owner_playtest_eligible -isnot [bool] -or -not [bool]$seed.owner_playtest_eligible) {
        Add-Failure "seeds[$id] VERIFIED must be owner-playtest eligible."
    }
    foreach ($field in @("tested_commit", "tested_tree", "platform", "setup", "expected", "actual", "verification_date")) {
        Require-Text $seed.$field "seeds[$id].$field" | Out-Null
    }
    if ($validPlatforms -notcontains [string]$seed.platform) { Add-Failure "seeds[$id].platform is not an allowed owner platform." }
    Test-StrictDate $seed.verification_date "seeds[$id].verification_date"
    foreach ($field in @("setup", "expected", "actual")) { Test-NoShortcutToken $seed.$field "seeds[$id].$field" }

    $seedTree = Get-CommitTree ([string]$seed.tested_commit) "seeds[$id].tested_commit"
    if (-not (Test-CommitText $seed.tested_tree)) {
        Add-Failure "seeds[$id].tested_tree must be a full lowercase Git tree id."
    } elseif ($seedTree -and [string]$seed.tested_tree -cne $seedTree) {
        Add-Failure "seeds[$id].tested_tree does not match tested_commit."
    }
    if ($RequireFinal -and $expectedTree) {
        if ([string]$seed.tested_commit -cne $ExpectedTestedCommit) { Add-Failure "seeds[$id] was not verified at ExpectedTestedCommit." }
        if ([string]$seed.tested_tree -cne $expectedTree) { Add-Failure "seeds[$id] was not verified at ExpectedTestedCommit's exact tree." }
    }

    $routeSteps = @(As-Array $seed.route_steps)
    if ($routeSteps.Count -eq 0) { Add-Failure "seeds[$id].route_steps must contain public owner actions." }
    $routeStepIds = @{}
    foreach ($step in $routeSteps) {
        $stepId = [string]$step.action_id
        Require-Text $stepId "seeds[$id].route_steps[].action_id" | Out-Null
        Require-Text $step.instruction "seeds[$id].route_steps[$stepId].instruction" | Out-Null
        Require-Text $step.expected_visible_result "seeds[$id].route_steps[$stepId].expected_visible_result" | Out-Null
        if ([string]$step.authority -cne "PUBLIC_UI_ACTION") { Add-Failure "seeds[$id].route_steps[$stepId].authority must be PUBLIC_UI_ACTION." }
        if ($routeStepIds.ContainsKey($stepId)) { Add-Failure "seeds[$id] has duplicate route action '$stepId'." } else { $routeStepIds[$stepId] = $true }
        Test-NoShortcutToken $stepId "seeds[$id].route_steps[$stepId].action_id"
        Test-NoShortcutToken $step.instruction "seeds[$id].route_steps[$stepId].instruction"
    }

    $observedCoverage = New-CoverageSets
    $ownerSessionCount = 0
    $seedSessionPlatforms = @{}
    $evidenceRows = @(As-Array $seed.evidence)
    if ($evidenceRows.Count -eq 0) { Add-Failure "seeds[$id].evidence must contain retained hashed artifacts." }
    $evidencePaths = @{}
    $resolvedEvidenceByPath = @{}
    $evidenceKindByPath = @{}
    $runtimeEventsByPath = @{}
    foreach ($evidence in $evidenceRows) {
        $kind = [string]$evidence.kind
        $path = [string]$evidence.path
        $label = "seeds[$id].evidence[$path]"
        if ($validEvidenceKinds -notcontains $kind) { Add-Failure "$label.kind is not allowed." }
        if (-not (Test-Sha256Text $evidence.sha256)) { Add-Failure "$label.sha256 must be a lowercase SHA-256." }
        $committedEvidence = Resolve-CommittedEvidence $path $label
        if ($evidencePaths.ContainsKey($path)) { Add-Failure "seeds[$id] contains duplicate evidence path '$path'." } else { $evidencePaths[$path] = $true }
        if ($null -eq $committedEvidence) { continue }
        if ([string]$committedEvidence.sha256 -cne [string]$evidence.sha256) { Add-Failure "$label SHA-256 does not match the committed HEAD blob." }
        $resolvedEvidenceByPath[$path] = $committedEvidence
        $evidenceKindByPath[$path] = $kind
        if ($kind -eq "RUNTIME_TRACE") {
            $trace = ConvertFrom-Utf8JsonBytes ([byte[]]$committedEvidence.bytes) "$label RUNTIME_TRACE"
            if ($null -ne $trace) {
                if ([string]$trace.schema -cne "beat_the_house.playtest06_runtime_trace/v1") { Add-Failure "$label has the wrong runtime-trace schema." }
                if ([string]$trace.candidate_commit -cne [string]$seed.tested_commit -or [string]$trace.candidate_tree -cne [string]$seed.tested_tree) { Add-Failure "$label runtime trace candidate identity does not match the seed." }
                if ([string]$trace.seed_id -cne $id -or [string]$trace.seed -cne $value) { Add-Failure "$label runtime trace seed identity does not match the manifest." }
                if ($validSessionPlatforms -notcontains [string]$trace.platform) { Add-Failure "$label runtime trace platform must identify one actual platform." }
                if ([string]$trace.owner_build_manifest_sha256 -cne $ownerBuildManifestHash) { Add-Failure "$label runtime trace does not bind the owner build manifest." }
                $eventSet = @{}
                foreach ($event in @(As-Array $trace.events)) {
                    $eventId = [string]$event.event_id
                    Require-Text $eventId "$label.events[].event_id" | Out-Null
                    Require-Text $event.action_id "$label.events[$eventId].action_id" | Out-Null
                    Require-Text $event.coverage_field "$label.events[$eventId].coverage_field" | Out-Null
                    Require-Text $event.coverage_id "$label.events[$eventId].coverage_id" | Out-Null
                    Require-Text $event.outcome_type "$label.events[$eventId].outcome_type" | Out-Null
                    Require-Text $event.visible_result "$label.events[$eventId].visible_result" | Out-Null
                    $traceActionIndex = -1
                    if (-not [int]::TryParse([string]$event.action_index, [ref]$traceActionIndex) -or $traceActionIndex -lt 0) { Add-Failure "$label.events[$eventId].action_index must be a nonnegative integer." }
                    if ($eventSet.ContainsKey($eventId)) { Add-Failure "$label contains duplicate runtime event '$eventId'." } else { $eventSet[$eventId] = $event }
                }
                if ($eventSet.Count -eq 0) { Add-Failure "$label must contain runtime events." }
                $runtimeEventsByPath[$path] = $eventSet
            }
        }
    }
    foreach ($evidence in $evidenceRows) {
        $kind = [string]$evidence.kind
        $path = [string]$evidence.path
        $label = "seeds[$id].evidence[$path]"
        if ($kind -ne "OWNER_SESSION_REPORT") { continue }
        if (-not $resolvedEvidenceByPath.ContainsKey($path)) { continue }
        $committedEvidence = $resolvedEvidenceByPath[$path]
        $ownerSessionCount += 1
        $session = ConvertFrom-Utf8JsonBytes ([byte[]]$committedEvidence.bytes) "$label OWNER_SESSION_REPORT"
        if ($null -eq $session) { continue }
        if ([string]$session.schema -cne "beat_the_house.playtest06_owner_route/v1") { Add-Failure "$label has the wrong owner-session schema." }
        if ([string]$session.candidate_commit -cne [string]$seed.tested_commit) { Add-Failure "$label candidate_commit does not match the seed." }
        if ([string]$session.candidate_tree -cne [string]$seed.tested_tree) { Add-Failure "$label candidate_tree does not match the seed." }
        if ([string]$session.seed_id -cne $id -or [string]$session.seed -cne $value) { Add-Failure "$label seed identity does not match the manifest." }
        if ($validSessionPlatforms -notcontains [string]$session.platform) { Add-Failure "$label platform must identify one actual platform." }
        if ([string]$seed.platform -ne "WINDOWS_NATIVE_AND_WEB_CHROME" -and [string]$session.platform -cne [string]$seed.platform) { Add-Failure "$label platform does not match the manifest." }
        if ([string]$session.owner_build_manifest_sha256 -cne $ownerBuildManifestHash) { Add-Failure "$label does not bind the owner build manifest." }
        $seedSessionPlatforms[[string]$session.platform] = $true
        if ([string]$session.route_authority -cne "PRODUCTION_PUBLIC_ACTIONS") { Add-Failure "$label route_authority must be PRODUCTION_PUBLIC_ACTIONS." }
        if (@(As-Array $session.route_shortcuts).Count -gt 0) { Add-Failure "$label records forbidden route shortcuts." }
        if ($session.completed -isnot [bool] -or -not [bool]$session.completed) { Add-Failure "$label must record completed=true." }
        if ($session.soft_lock -isnot [bool] -or [bool]$session.soft_lock) { Add-Failure "$label must record soft_lock=false." }
        if ([int]$session.dead_interaction_count -ne 0) { Add-Failure "$label must record zero dead interactions." }
        if ([string]$session.verification_date -cne [string]$seed.verification_date) { Add-Failure "$label verification_date does not match the manifest." }
        $publicActions = @(As-Array $session.public_actions)
        if ($publicActions.Count -eq 0) { Add-Failure "$label must retain public_actions." }
        $sessionActionIds = @{}
        foreach ($action in $publicActions) {
            $actionId = [string]$action.action_id
            Require-Text $actionId "$label.public_actions[].action_id" | Out-Null
            Require-Text $action.instruction "$label.public_actions[$actionId].instruction" | Out-Null
            Require-Text $action.visible_result "$label.public_actions[$actionId].visible_result" | Out-Null
            if ([string]$action.authority -cne "PUBLIC_UI_ACTION") { Add-Failure "$label.public_actions[$actionId].authority must be PUBLIC_UI_ACTION." }
            Test-NoShortcutToken $actionId "$label.public_actions[$actionId].action_id"
            Test-NoShortcutToken $action.instruction "$label.public_actions[$actionId].instruction"
            $sessionActionIds[$actionId] = $true
        }
        foreach ($stepId in $routeStepIds.Keys) {
            if (-not $sessionActionIds.ContainsKey($stepId)) { Add-Failure "$label is missing manifest route action '$stepId'." }
        }
        $sessionObservedCoverage = New-CoverageSets
        if ($null -eq $session.observed_coverage) {
            Add-Failure "$label must contain observed_coverage."
        } else {
            Add-CoverageValues $sessionObservedCoverage $session.observed_coverage
            Add-CoverageValues $observedCoverage $session.observed_coverage
        }
        $witnessCoverage = New-CoverageSets
        $witnesses = @(As-Array $session.coverage_witnesses)
        if ($witnesses.Count -eq 0) { Add-Failure "$label must contain typed coverage_witnesses." }
        foreach ($witness in $witnesses) {
            $field = [string]$witness.coverage_field
            $coverageId = [string]$witness.coverage_id
            $witnessLabel = "$label.coverage_witnesses[$field/$coverageId]"
            if (-not $witnessCoverage.ContainsKey($field)) {
                Add-Failure "$witnessLabel coverage_field is invalid."
                continue
            }
            if ([string]::IsNullOrWhiteSpace($coverageId)) { Add-Failure "$witnessLabel coverage_id must be non-empty."; continue }
            $actionIndex = -1
            if (-not [int]::TryParse([string]$witness.action_index, [ref]$actionIndex) -or $actionIndex -lt 0 -or $actionIndex -ge $publicActions.Count) {
                Add-Failure "$witnessLabel action_index must reference a retained public action."
            }
            $expectedOutcome = Get-ExpectedCoverageOutcomeType $field $coverageId
            if ([string]$witness.outcome_type -cne $expectedOutcome) { Add-Failure "$witnessLabel outcome_type must be $expectedOutcome." }
            Require-Text $witness.visible_result "$witnessLabel.visible_result" | Out-Null
            $runtimePath = [string]$witness.runtime_evidence_path
            $runtimeEventId = [string]$witness.runtime_event_id
            if (-not $evidenceKindByPath.ContainsKey($runtimePath) -or [string]$evidenceKindByPath[$runtimePath] -cne "RUNTIME_TRACE") {
                Add-Failure "$witnessLabel must reference a retained RUNTIME_TRACE."
            } elseif (-not $runtimeEventsByPath.ContainsKey($runtimePath) -or -not $runtimeEventsByPath[$runtimePath].ContainsKey($runtimeEventId)) {
                Add-Failure "$witnessLabel runtime_event_id is absent from its retained runtime trace."
            } else {
                $runtimeEvent = $runtimeEventsByPath[$runtimePath][$runtimeEventId]
                if ([int]$runtimeEvent.action_index -ne $actionIndex) { Add-Failure "$witnessLabel action_index does not match its runtime event." }
                if ([string]$runtimeEvent.coverage_field -cne $field) { Add-Failure "$witnessLabel coverage_field does not match its runtime event." }
                if ([string]$runtimeEvent.coverage_id -cne $coverageId) { Add-Failure "$witnessLabel coverage_id does not match its runtime event." }
                if ([string]$runtimeEvent.outcome_type -cne [string]$witness.outcome_type) { Add-Failure "$witnessLabel outcome_type does not match its runtime event." }
                if ([string]$runtimeEvent.visible_result -cne [string]$witness.visible_result) { Add-Failure "$witnessLabel visible_result does not match its runtime event." }
                if ($actionIndex -ge 0 -and $actionIndex -lt $publicActions.Count) {
                    $publicAction = $publicActions[$actionIndex]
                    if ([string]$runtimeEvent.action_id -cne [string]$publicAction.action_id) { Add-Failure "$witnessLabel runtime event action_id does not match its indexed public action." }
                    if ([string]$runtimeEvent.visible_result -cne [string]$publicAction.visible_result) { Add-Failure "$witnessLabel runtime event visible_result does not match its indexed public action." }
                    if ([string]$witness.visible_result -cne [string]$publicAction.visible_result) { Add-Failure "$witnessLabel visible_result does not match its indexed public action." }
                }
            }
            $witnessCoverage[$field][$coverageId] = $true
        }
        foreach ($field in $sessionObservedCoverage.Keys) {
            Test-ExactSet @($sessionObservedCoverage[$field].Keys) @($witnessCoverage[$field].Keys) "$label $field observed coverage versus typed witnesses"
        }
        if ($sessionObservedCoverage.coverage_slots.ContainsKey("FULL-RUN-CONTROLS")) {
            $verifiedPlatforms[[string]$session.platform] = $true
        }
    }
    if ($ownerSessionCount -eq 0) { Add-Failure "seeds[$id] VERIFIED requires at least one OWNER_SESSION_REPORT." }
    if ([string]$seed.platform -eq "WINDOWS_NATIVE_AND_WEB_CHROME") {
        foreach ($platform in $validSessionPlatforms) {
            if (-not $seedSessionPlatforms.ContainsKey($platform)) { Add-Failure "seeds[$id] combined-platform claim is missing a separate $platform owner session report." }
        }
    }

    foreach ($field in $observedCoverage.Keys) {
        $manifestValues = @(As-Array $seed.$field)
        $observedValues = @($observedCoverage[$field].Keys)
        Test-ExactSet $manifestValues $observedValues "seeds[$id] $field versus retained owner evidence"
        foreach ($item in $observedValues) { $verifiedCoverage[$field][$item] = $true }
    }
}

if ($RequireFinal) {
    foreach ($slot in $requiredSlots) {
        if (-not $verifiedCoverage.coverage_slots.ContainsKey($slot)) { Add-Failure "FINAL verified coverage is missing slot '$slot'." }
    }
    foreach ($id in $knownArchetypes) {
        if (-not $verifiedCoverage.archetype_ids.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing archetype '$id'." }
    }
    foreach ($id in $knownLayers) {
        if (-not $verifiedCoverage.layer_ids.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing environment layer '$id'." }
    }
    foreach ($id in $knownGames) {
        if (-not $verifiedCoverage.game_ids.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing game '$id'." }
    }
    foreach ($id in $knownPusherMachines) {
        if (-not $verifiedCoverage.pusher_machine_ids.ContainsKey($id)) { Add-Failure "FINAL verified coverage is missing pusher machine '$id'." }
    }
    foreach ($id in $representativeScenarioTargets) {
        if (-not $verifiedCoverage.scenario_ids.ContainsKey([string]$id)) { Add-Failure "FINAL verified coverage is missing representative scenario '$id'." }
    }
    foreach ($id in $materialBranchTargets) {
        if (-not $verifiedCoverage.scenario_branch_ids.ContainsKey([string]$id)) { Add-Failure "FINAL verified coverage is missing scenario aftermath branch '$id'." }
    }
    foreach ($platform in @("WINDOWS_NATIVE", "WEB_CHROME")) {
        if (-not $verifiedPlatforms.ContainsKey($platform)) { Add-Failure "FINAL FULL-RUN-CONTROLS evidence is missing platform '$platform'." }
    }
}

if ($Failures.Count -gt 0) {
    Write-Host "playtest06_2 seed manifest: FAIL ($($Failures.Count))" -ForegroundColor Red
    foreach ($failure in $Failures) { Write-Host " - $failure" }
    exit 1
}

$candidateCount = @($seeds | Where-Object { [string]$_.status -eq "CANDIDATE" }).Count
$verifiedCount = @($seeds | Where-Object { [string]$_.status -eq "VERIFIED" }).Count
$blockedCount = @($seeds | Where-Object { [string]$_.status -eq "BLOCKED" }).Count
Write-Host "playtest06_2 seed manifest: PASS stage=$($manifest.stage) seeds=$($seeds.Count) candidates=$candidateCount verified=$verifiedCount blocked=$blockedCount"
Write-Host "catalog: archetypes=$($knownArchetypes.Count) layers=$($knownLayers.Count) games=$($knownGames.Count) scenarios=$($knownScenarios.Count) scenario_branches=$($knownScenarioBranches.Count) pusher_machines=$($knownPusherMachines.Count)"
if ([string]$manifest.stage -eq "PRESTAGE") {
    Write-Host "PRESTAGE ONLY: this pass validates structure and candidate provenance fields; it does not prove owner-route reachability."
}
