# Produces manifest-bound development exports. Packaging always reads an
# immutable commit/tree-keyed staging root; it never packages legacy loose
# output and never deletes opaque artifacts under builds/.

param(
    [ValidateSet("all", "web", "windows")]
    [string]$Target = "all",
    [switch]$Debug,
    [switch]$SkipExport,
    [switch]$NoPackage,
    [switch]$Push,
    [switch]$DryRun,
    [switch]$QuarantineLegacyOnly,
    [string]$ItchTarget = "",
    [string]$Channel = ""
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
. (Join-Path $PSScriptRoot "export_tree_identity.ps1")
. (Join-Path $PSScriptRoot "export_itch_helpers.ps1")

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSha256([string]$Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Test-PathInside([string]$Path, [string]$Directory, [switch]$AllowEqual) {
    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    $fullDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd([char[]]@('\', '/'))
    if ($AllowEqual -and $fullPath.Equals($fullDirectory, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $fullPath.StartsWith($fullDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-Godot {
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN -PathType Leaf)) { return [IO.Path]::GetFullPath($env:GODOT_BIN) }
    $local = Get-ChildItem -LiteralPath (Join-Path $root ".tools") -Filter "Godot*_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($local) { return $local.FullName }
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    throw "Godot was not found. Run tools/install_godot.ps1 or set GODOT_BIN."
}

function Get-ProjectVersion {
    $line = Get-Content -LiteralPath (Join-Path $root "project.godot") | Where-Object { $_ -match '^config/version=' } | Select-Object -First 1
    if ($line -match '^config/version="([^"]+)"') { return $Matches[1] }
    throw "Could not read application/config version from project.godot."
}

function Get-SourceIdentity {
    $commit = (& git -C $root rev-parse HEAD).Trim().ToLowerInvariant()
    $tree = (& git -C $root rev-parse 'HEAD^{tree}').Trim().ToLowerInvariant()
    if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$' -or $tree -notmatch '^[0-9a-f]{40}$') { throw "Could not resolve source commit/tree identity." }
    $status = @(& git -C $root status --porcelain=v1 --untracked-files=all) -join "`n"
    $diffIdentity = ((& git -C $root diff --binary HEAD | & git -C $root hash-object --stdin).Trim()).ToLowerInvariant()
    $untrackedRows = @()
    foreach ($relative in @(& git -C $root ls-files --others --exclude-standard)) {
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) { $untrackedRows += "$($relative.Replace('\','/'))`t$(Get-Sha256 $path)" }
    }
    $dirtyCanonical = "$status`n$diffIdentity`n$(@($untrackedRows | Sort-Object) -join "`n")"
    $dirty = -not [string]::IsNullOrWhiteSpace($status)
    $dirtyDigest = Get-StringSha256 $dirtyCanonical
    $short = $commit.Substring(0, 12)
    $dirtyShort = $dirtyDigest.Substring(0, 12)
    $buildVersion = "0.6.0-dev+$short"
    return [ordered]@{
        source_commit = $commit
        source_tree = $tree
        source_short_commit = $short
        source_dirty = $dirty
        dirty_state_digest = $dirtyDigest
        source_dirty_short = $dirtyShort
        build_version = $buildVersion
        candidate_key = "$($buildVersion)_$($tree.Substring(0,12))_$dirtyShort"
    }
}

function Get-ExportPresetCustomFeatures([string]$PresetName) {
    $activeName = ""
    foreach ($line in Get-Content -LiteralPath (Join-Path $root "export_presets.cfg")) {
        if ($line -match '^name="([^"]+)"$') { $activeName = $Matches[1]; continue }
        if ($activeName -eq $PresetName -and $line -match '^custom_features="([^"]*)"$') {
            return @($Matches[1].Split(',', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() })
        }
    }
    throw "Could not read custom features for export preset '$PresetName'."
}

function Get-ExportPresetOption([string]$PresetName, [string]$OptionName) {
    $activeName = ""
    $escaped = [Text.RegularExpressions.Regex]::Escape($OptionName)
    foreach ($line in Get-Content -LiteralPath (Join-Path $root "export_presets.cfg")) {
        if ($line -match '^name="([^"]+)"$') { $activeName = $Matches[1]; continue }
        if ($activeName -eq $PresetName -and $line -match "^$escaped=(.+)$") { return $Matches[1] }
    }
    throw "Could not read option '$OptionName' for export preset '$PresetName'."
}

function Assert-CleanDistributionOutput([string]$Directory) {
    $forbiddenNames = @("profile_inventory.json", "meta_collection.json", "settings.json", "autosave.json", "autosave.json.bak")
    $forbiddenExtensions = @(".key", ".log", ".pem", ".pfx", ".ps1", ".py")
    $leaks = @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Force | Where-Object {
        $relative = $_.FullName.Substring($Directory.Length).TrimStart([char[]]@('\','/')).Replace('\','/').ToLowerInvariant()
        $forbiddenNames -contains $_.Name -or $forbiddenExtensions -contains $_.Extension.ToLowerInvariant() -or $relative.StartsWith("reports/") -or $relative.StartsWith("native/") -or $relative.StartsWith("scripts/tests/") -or $relative.StartsWith("tools/")
    })
    if ($leaks.Count -gt 0) { throw "Refusing development-only or persistent content in distribution output: $(@($leaks.FullName) -join ', ')" }
}

function Assert-NativeSolverExport([string]$Directory, [string]$ExportTarget) {
    $extension = if ($ExportTarget -eq "web") { ".wasm" } else { ".dll" }
    $native = @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Force | Where-Object { $_.Name -like "coin_pusher_native*$extension" -and $_.Name -like "*.nothreads$extension" })
    if ($native.Count -ne 1) { throw "Expected exactly one exported Coin Pusher native $ExportTarget library, found $($native.Count). Refusing a distribution without its required native extension." }
    return $native[0]
}

function Invoke-WebExportWithLockedTemplate([string]$GodotPath, [string]$ExportFlag, [string]$PresetName, [string]$OutputPath) {
    $lock = Get-Content -LiteralPath (Join-Path $root "native/coin_pusher/toolchain.lock.json") -Raw | ConvertFrom-Json
    $templatePath = Join-Path $env:APPDATA "Godot/export_templates/$(([string]$lock.godot.version).Replace('-', '.'))/$([string]$lock.web.template)"
    $presetPath = Join-Path $root "export_presets.cfg"
    $originalBytes = [IO.File]::ReadAllBytes($presetPath)
    $presetText = [Text.Encoding]::UTF8.GetString($originalBytes)
    $pattern = '(?ms)(\[preset\.3\.options\]\s*.*?^custom_template/release=)"[^"]*"'
    if ($presetText -notmatch $pattern) { throw "Could not locate Web release-template option." }
    $patched = [Text.RegularExpressions.Regex]::Replace($presetText, $pattern, ('$1"' + $templatePath.Replace('\','/') + '"'), 1)
    try {
        [IO.File]::WriteAllText($presetPath, $patched, [Text.UTF8Encoding]::new($false))
        return [int](Invoke-TypedConsoleProcess -FilePath $GodotPath -ArgumentList @("--headless", "--path", $root, $ExportFlag, $PresetName, $OutputPath))
    }
    finally { [IO.File]::WriteAllBytes($presetPath, $originalBytes) }
}

function Invoke-WithEmbeddedManifest($Manifest, [scriptblock]$Action) {
    $path = Join-Path $root "build_manifest.json"
    $existed = Test-Path -LiteralPath $path -PathType Leaf
    $prior = if ($existed) { [IO.File]::ReadAllBytes($path) } else { $null }
    try {
        [IO.File]::WriteAllText($path, ($Manifest | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
        & $Action
    }
    finally {
        if ($existed) { [IO.File]::WriteAllBytes($path, $prior) }
        elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

function Get-RelativeFiles([string]$Directory) {
    return @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($Directory.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
            bytes = [int64]$_.Length
            sha256 = Get-Sha256 $_.FullName
        }
    })
}

function Invoke-PckAudit([string]$PackagePath, [string]$ReportPath) {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) { throw "Python is required for the post-export PCK manifest audit." }
    & $python.Source (Join-Path $PSScriptRoot "audit_pck_manifest.py") $PackagePath --out $ReportPath
    if ($LASTEXITCODE -ne 0) { throw "Post-export PCK manifest audit rejected $PackagePath." }
}

function Write-CandidateManifest([string]$CandidateRoot, $Identity, [hashtable]$Platforms) {
    $path = Join-Path $CandidateRoot "candidate_manifest.json"
    $manifest = [ordered]@{
        schema = "beat_the_house.candidate_manifest/v1"
        build_version = $Identity.build_version
        source_commit = $Identity.source_commit
        source_tree = $Identity.source_tree
        source_dirty = $Identity.source_dirty
        dirty_state_digest = $Identity.dirty_state_digest
        candidate_key = $Identity.candidate_key
        export_presets_sha256 = Get-Sha256 (Join-Path $root "export_presets.cfg")
        platforms = $Platforms
    }
    [IO.File]::WriteAllText($path, ($manifest | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    return $path
}

function Read-CandidateManifest([string]$CandidateRoot, $Identity) {
    $path = Join-Path $CandidateRoot "candidate_manifest.json"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Candidate manifest is missing: $path" }
    $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ([string]$value.source_commit -cne [string]$Identity.source_commit -or [string]$value.source_tree -cne [string]$Identity.source_tree -or [string]$value.dirty_state_digest -cne [string]$Identity.dirty_state_digest) { throw "Candidate manifest does not match the current commit/tree/dirty digest." }
    return $value
}

function Verify-ArchiveAgainstStaging([string]$ArchivePath, [string]$StagingDirectory) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $expected = @{}
    foreach ($file in Get-RelativeFiles $StagingDirectory) { $expected[[string]$file.path] = [string]$file.sha256 }
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $actual = @{}
        foreach ($entry in $archive.Entries) {
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "").ToLowerInvariant() }
            finally { $sha.Dispose(); $stream.Dispose() }
            $actual[$entry.FullName.Replace('\','/')] = $hash
        }
        if ($actual.Count -ne $expected.Count) { throw "Archive entry count $($actual.Count) does not match staging file count $($expected.Count)." }
        foreach ($path in $expected.Keys) {
            if (-not $actual.ContainsKey($path) -or $actual[$path] -cne $expected[$path]) { throw "Archive payload does not match staged file: $path" }
        }
    }
    finally { $archive.Dispose() }
}

function Move-ToQuarantine([string]$Path, [string]$QuarantineRoot, [Collections.Generic.List[object]]$Rows) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $full = [IO.Path]::GetFullPath($Path)
    $buildsRoot = [IO.Path]::GetFullPath((Join-Path $root "builds"))
    if (-not (Test-PathInside $full $buildsRoot)) { throw "Refusing to quarantine path outside builds/: $full" }
    $relative = $full.Substring($buildsRoot.Length).TrimStart([char[]]@('\','/'))
    if ($relative.Replace('\','/').StartsWith("quarantine/")) { throw "Refusing to re-quarantine $relative" }
    $destination = Join-Path $QuarantineRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    $files = if (Test-Path -LiteralPath $full -PathType Container) { @(Get-ChildItem -LiteralPath $full -File -Recurse -Force) } else { @(Get-Item -LiteralPath $full -Force) }
    [void]$Rows.Add([ordered]@{ source = "builds/$($relative.Replace('\','/'))"; destination = $destination.Substring($root.Length).TrimStart([char[]]@('\','/')).Replace('\','/'); file_count = $files.Count; bytes = [int64](($files | Measure-Object Length -Sum).Sum) })
    Move-Item -LiteralPath $full -Destination $destination
}

function Move-SupersededBuildArtifacts([string[]]$OwnedItchNames = @()) {
    $stamp = [datetime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    $quarantineRoot = Join-Path $root "builds/quarantine/$stamp"
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($legacyRoot in @("builds/windows", "builds/web")) {
        $path = Join-Path $root $legacyRoot
        if ((Test-Path -LiteralPath $path -PathType Container) -and @(Get-ChildItem -LiteralPath $path -Force).Count -gt 0) { Move-ToQuarantine $path $quarantineRoot $rows }
    }
    $buildsRoot = Join-Path $root "builds"
    foreach ($legacyDirectory in @(Get-ChildItem -LiteralPath $buildsRoot -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($legacyDirectory.Name -in @("itch", "quarantine", "staging")) { continue }
        Move-ToQuarantine $legacyDirectory.FullName $quarantineRoot $rows
    }
    $itch = Join-Path $root "builds/itch"
    if (Test-Path -LiteralPath $itch -PathType Container) {
        foreach ($item in @(Get-ChildItem -LiteralPath $itch -Force)) {
            if ($item.Name -eq "images" -or $OwnedItchNames -contains $item.Name) { continue }
            Move-ToQuarantine $item.FullName $quarantineRoot $rows
        }
    }
    if ($rows.Count -gt 0) {
        New-Item -ItemType Directory -Force -Path $quarantineRoot | Out-Null
        $record = [ordered]@{ schema = "beat_the_house.build_quarantine/v1"; moved_at_utc = [datetime]::UtcNow.ToString("o"); reason = "unbound or superseded distribution artifact"; entries = $rows }
        [IO.File]::WriteAllText((Join-Path $quarantineRoot "quarantine_manifest.json"), ($record | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    }
    return $rows
}

function Assert-UploadDirectoryOwned([string]$Directory, [string[]]$OwnedNames) {
    foreach ($item in @(Get-ChildItem -LiteralPath $Directory -Force -ErrorAction SilentlyContinue)) {
        if ($item.Name -eq "images" -or $OwnedNames -contains $item.Name) { continue }
        if (-not $item.PSIsContainer -and $item.Extension.ToLowerInvariant() -in @(".exe", ".dll", ".pck", ".aab", ".html")) { throw "Distribution directory contains an unexpected executable-looking artifact: $($item.FullName)" }
        throw "Distribution directory contains an unowned package artifact: $($item.FullName)"
    }
}

if ($QuarantineLegacyOnly) {
    $moved = @(Move-SupersededBuildArtifacts)
    Write-Host "BUILD QUARANTINE PASS moved=$($moved.Count)"
    return
}
if ($NoPackage -and $Push) { throw "-NoPackage cannot be combined with -Push." }
if ($Push -and -not $ItchTarget) { throw "-Push requires -ItchTarget user/game-slug." }

$identity = Get-SourceIdentity
$projectVersion = Get-ProjectVersion
if ($identity.build_version -ceq $projectVersion) { throw "Refusing to package development source with immutable published identity $projectVersion." }
if ($projectVersion -eq "0.5.1" -and $identity.build_version -notlike "0.6.0-dev+*") { throw "Published 0.5.1 source requires its immutable release record; this tool only creates 0.6 development identities." }
$godot = Resolve-Godot
$engineHash = Get-Sha256 $godot
$presetHash = Get-Sha256 (Join-Path $root "export_presets.cfg")
$candidateRoot = Join-Path $root "builds/staging/$($identity.candidate_key)"
$candidateWorkRoot = Join-Path $root "builds/staging/.work/$($identity.candidate_key)"
New-Item -ItemType Directory -Force -Path $candidateRoot | Out-Null
$targets = if ($Target -eq "all") { @("windows", "web") } else { @($Target) }
$platforms = @{}
$existingCandidate = Join-Path $candidateRoot "candidate_manifest.json"
if (Test-Path -LiteralPath $existingCandidate) {
    $priorCandidate = Read-CandidateManifest $candidateRoot $identity
    foreach ($property in $priorCandidate.platforms.PSObject.Properties) { $platforms[$property.Name] = $property.Value }
}

foreach ($platform in $targets) {
    $preset = if ($platform -eq "web") { "Web" } else { "Windows Steam" }
    if ((Get-ExportPresetCustomFeatures $preset) -notcontains "distribution_build") { throw "Export preset '$preset' must include distribution_build." }
    if ($platform -eq "web" -and (Get-ExportPresetOption $preset "variant/extensions_support") -cne "true") { throw "Web export must enable extensions_support." }
    $stage = Join-Path $candidateRoot $platform
    $auditPath = Join-Path $candidateRoot "audits/$($platform)_pck_manifest.json"
    $stageRelative = $stage.Substring($root.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
    $auditRelative = $auditPath.Substring($root.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
    $registeredPlatform = if ($platforms.ContainsKey($platform)) { $platforms[$platform] } else { $null }
    if ($null -ne $registeredPlatform) {
        if ([string]$registeredPlatform.staging_root -cne $stageRelative -or [string]$registeredPlatform.pck_audit -cne $auditRelative) {
            throw "Registered $platform candidate paths do not match the immutable candidate root."
        }
        $registeredAttempt = Initialize-CandidatePlatformAttempt `
            -CandidateRoot $candidateRoot `
            -WorkRoot (Join-Path $candidateWorkRoot $platform) `
            -Platform $platform `
            -FinalAuditPath $auditPath `
            -RegisteredPlatform $registeredPlatform
        $registeredIdentity = Get-ExportTreeIdentityFromDirectory $registeredAttempt.final_stage
        if ([string]$registeredIdentity.aggregate_sha256 -cne [string]$registeredPlatform.export_identity_sha256) {
            throw "$platform staging tree changed after candidate registration."
        }
        Write-Host "Reusing registered immutable $platform candidate: $($registeredAttempt.final_stage)"
        continue
    }

    $attempt = Initialize-CandidatePlatformAttempt `
        -CandidateRoot $candidateRoot `
        -WorkRoot (Join-Path $candidateWorkRoot $platform) `
        -Platform $platform `
        -FinalAuditPath $auditPath `
        -UseExistingStage:$SkipExport
    $stage = [string]$attempt.attempt_stage
    $exeName = "BeatTheHouse-$($identity.build_version)-windows-$($identity.source_short_commit)-$($identity.source_dirty_short).exe"
    $outFile = if ($platform -eq "web") { Join-Path $stage "index.html" } else { Join-Path $stage $exeName }
    $pipelineState = @{}
    $auditAction = {
        if (-not (Test-Path -LiteralPath $outFile -PathType Leaf)) {
            if ($SkipExport) { throw "-SkipExport requires candidate output at $outFile" }
            throw "Export output is missing: $outFile"
        }
        if (-not $SkipExport) {
            [IO.File]::WriteAllText((Join-Path $stage "build_manifest.json"), ($buildManifest | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
        }
        Assert-CleanDistributionOutput $stage
        $pipelineState.native_output = Assert-NativeSolverExport $stage $platform
        $pckPath = if ($platform -eq "web") { Join-Path $stage "index.pck" } else { $outFile }
        $pipelineState.audit_path = [string]$attempt.attempt_audit
        Invoke-PckAudit $pckPath $pipelineState.audit_path
    }
    $custodyAction = {
        $treeIdentity = Get-ExportTreeIdentityFromDirectory $stage
        $pipelineState.platform_record = [ordered]@{
            platform = $platform
            staging_root = $stageRelative
            export_identity_sha256 = [string]$treeIdentity.aggregate_sha256
            native_library_sha256 = Get-Sha256 $pipelineState.native_output.FullName
            pck_audit = $auditRelative
            files = Get-RelativeFiles $stage
        }
    }
    $registrationAction = {
        Complete-CandidatePlatformAttempt -Attempt $attempt | Out-Null
        $platforms[$platform] = $pipelineState.platform_record
        Write-CandidateManifest $candidateRoot $identity $platforms | Out-Null
    }
    $downstreamComplete = $false
    if (-not $SkipExport) {
        $nativePlatform = if ($platform -eq "web") { "Web" } else { "Windows" }
        $nativeTarget = if ($Debug) { "template_debug" } else { "template_release" }
        $nativeArchitecture = if ($platform -eq "web") { "wasm32" } else { "x86_64" }
        & (Join-Path $PSScriptRoot "build_native_solver.ps1") -Platform $nativePlatform -Target $nativeTarget -GodotPath $godot
        if ($LASTEXITCODE -ne 0) { throw "Native Coin Pusher solver build/preflight failed." }
        $nativeSource = Get-NativeSourceLibrary -Directory (Join-Path $root "addons/coin_pusher_native/bin") -Platform $platform -Target $nativeTarget -Architecture $nativeArchitecture -Threading "nothreads"
        $buildManifest = [ordered]@{
            schema = "beat_the_house.build_manifest/v1"
            build_version = $identity.build_version
            release_version = $projectVersion
            source_commit = $identity.source_commit
            source_tree = $identity.source_tree
            source_dirty = $identity.source_dirty
            dirty_state_digest = $identity.dirty_state_digest
            engine_sha256 = $engineHash
            export_presets_sha256 = $presetHash
            platform = $platform
            native_library_path = $nativeSource.Name
            native_library_sha256 = Get-Sha256 $nativeSource.FullName
        }
        $flag = if ($Debug) { "--export-debug" } else { "--export-release" }
        if ($platform -eq "web" -and -not $Debug) {
            Invoke-WebExportPipeline `
                -ExportAction { Invoke-WithEmbeddedManifest $buildManifest { Invoke-WebExportWithLockedTemplate $godot $flag $preset $outFile } } `
                -AuditAction $auditAction `
                -CustodyAction $custodyAction `
                -RegistrationAction $registrationAction
            $downstreamComplete = $true
        }
        else {
            Invoke-WithEmbeddedManifest $buildManifest {
                & $godot --headless --path $root $flag $preset $outFile
                if ($LASTEXITCODE -ne 0) { throw "Godot $platform export failed with exit $LASTEXITCODE." }
            }
        }
    }
    if (-not $downstreamComplete) {
        & $auditAction
        & $custodyAction
        & $registrationAction
    }
}

if ($NoPackage) {
    Write-Host "Manifest-bound development export ready: $candidateRoot (no package or upload created)." -ForegroundColor Green
    return
}
$candidate = Read-CandidateManifest $candidateRoot $identity
foreach ($required in @("windows", "web")) {
    $entry = $candidate.platforms.$required
    if ($null -eq $entry) { throw "Packaging requires the same candidate's Windows and Web exports; missing $required." }
    $stage = Join-Path $root ([string]$entry.staging_root)
    $actual = Get-ExportTreeIdentityFromDirectory $stage
    if ([string]$actual.aggregate_sha256 -cne [string]$entry.export_identity_sha256) { throw "$required staging tree changed after candidate registration." }
}

$distDir = Join-Path $root "builds/itch"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$manifestName = "BeatTheHouse-$($identity.build_version)-$($identity.source_short_commit)-$($identity.source_dirty_short).manifest.json"
$archiveNames = @(
    "BeatTheHouse-$($identity.build_version)-windows-$($identity.source_short_commit)-$($identity.source_dirty_short).zip",
    "BeatTheHouse-$($identity.build_version)-web-$($identity.source_short_commit)-$($identity.source_dirty_short).zip"
)
$ownedNames = @($manifestName) + $archiveNames
foreach ($ownedName in $ownedNames) {
    if (Test-Path -LiteralPath (Join-Path $distDir $ownedName)) { throw "Immutable upload artifact already exists; refusing overwrite: $ownedName" }
}
Move-SupersededBuildArtifacts -OwnedItchNames $ownedNames | Out-Null
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
Assert-UploadDirectoryOwned $distDir $ownedNames
Copy-Item -LiteralPath (Join-Path $candidateRoot "candidate_manifest.json") -Destination (Join-Path $distDir $manifestName)
foreach ($platform in @("windows", "web")) {
    $stage = Join-Path $root ([string]$candidate.platforms.$platform.staging_root)
    $archiveIndex = if ($platform -eq "windows") { 0 } else { 1 }
    $archiveName = $archiveNames[$archiveIndex]
    $archive = Join-Path $distDir $archiveName
    if (Test-Path -LiteralPath $archive) { throw "Refusing to overwrite existing named candidate archive: $archive" }
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive
    Verify-ArchiveAgainstStaging $archive $stage
    Write-Host "Verified archive: $archive SHA256=$(Get-Sha256 $archive)"
}
Assert-UploadDirectoryOwned $distDir $ownedNames

if ($Push) {
    foreach ($platform in $targets) {
        $pushChannel = if ($Channel) { $Channel } elseif ($platform -eq "web") { "html" } else { "windows" }
        $stage = Join-Path $root ([string]$candidate.platforms.$platform.staging_root)
        $pushTarget = "$ItchTarget`:$pushChannel"
        $args = @("push", "--userversion", $identity.build_version, $stage, $pushTarget)
        if ($DryRun) { Write-Host "butler $($args -join ' ')"; continue }
        if (-not (Get-Command butler -ErrorAction SilentlyContinue)) { throw "butler not found." }
        & butler @args
        if ($LASTEXITCODE -ne 0) { throw "butler push failed for $platform." }
    }
}
else { Write-Host "Bound Windows/Web candidate archives ready in $distDir" -ForegroundColor Green }
