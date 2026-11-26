param(
    [Parameter(Mandatory)][string]$CandidateManifest,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/export_tree_identity.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Read-ReleasePlatform($Candidate, [string]$CandidateRoot, [string]$Platform) {
    $registration = $Candidate.platforms.$Platform
    $relativeRoot = "builds/staging/$($Candidate.candidate_key)"
    if ($registration.platform -cne $Platform -or $registration.staging_root -cne "$relativeRoot/$Platform" -or
        $registration.pck_audit -cne "$relativeRoot/audits/${Platform}_pck_manifest.json") {
        throw "The candidate must contain an audited $Platform export."
    }

    $stage = Join-Path $CandidateRoot $Platform
    $claimed = Get-ExportTreeIdentityFromRows -Rows $registration.files
    $actual = Get-ExportTreeIdentityFromDirectory -Directory $stage
    if ($claimed.aggregate_sha256 -cne $registration.export_identity_sha256 -or
        $actual.aggregate_sha256 -cne $registration.export_identity_sha256) {
        throw "The $Platform export differs from its registered file inventory."
    }

    $manifest = Get-Content -LiteralPath (Join-Path $stage 'build_manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.schema -cne 'beat_the_house.build_manifest/v1' -or $manifest.platform -cne $Platform -or
        $manifest.source_dirty -isnot [bool] -or $manifest.source_dirty -or
        $manifest.release_version -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
        throw "The $Platform build manifest has no clean release identity."
    }
    foreach ($field in @('source_commit', 'source_tree', 'build_version', 'dirty_state_digest', 'export_presets_sha256')) {
        if ([string]$manifest.$field -cne [string]$Candidate.$field) {
            throw "The $Platform build manifest has a different $field."
        }
    }

    $native = @($actual.files | Where-Object { $_.path -ceq $manifest.native_library_path })
    if ($native.Count -ne 1 -or $native[0].path -cnotmatch '\.template_release\.' -or
        $native[0].sha256 -cne $manifest.native_library_sha256 -or
        $native[0].sha256 -cne $registration.native_library_sha256) {
        throw "The $Platform native release library differs from its manifest."
    }

    $containers = @(if ($Platform -ceq 'windows') {
        $actual.files | Where-Object { $_.path -match '\.exe$' }
    } else {
        $actual.files | Where-Object { $_.path -ceq 'index.pck' }
    })
    if ($containers.Count -ne 1 -or $containers[0].path.Contains('/')) {
        throw "Expected one $Platform package container at the export root."
    }
    $container = $containers[0]
    $auditPath = Join-Path $CandidateRoot "audits/${Platform}_pck_manifest.json"
    $audit = Get-Content -LiteralPath $auditPath -Raw | ConvertFrom-Json
    if ($audit.schema -cne 'beat_the_house.pck_manifest_audit/v1' -or $audit.passed -isnot [bool] -or
        -not $audit.passed -or $audit.package -cne $container.path -or
        $audit.package_sha256 -cne $container.sha256 -or $audit.package_bytes -ne $container.bytes) {
        throw "The $Platform package does not match its passing PCK audit."
    }

    $version = [string]$manifest.release_version
    if ($Platform -ceq 'windows') {
        $versions = (Get-Item -LiteralPath (Join-Path $stage $container.path)).VersionInfo
        foreach ($property in @('FileVersion', 'ProductVersion')) {
            if (([string]$versions.$property).Trim() -cnotin @($version, "$version.0")) {
                throw "Windows $property must match release $version."
            }
        }
    }

    return [pscustomobject]@{
        platform = $Platform
        version = $version
        stage = $stage
        files = $actual.files
        executable = if ($Platform -ceq 'windows') { $container.path } else { '' }
    }
}

function Write-ReleaseArchive($Plan, [string]$ArchivePath) {
    $files = @{}
    $stream = [IO.File]::Open($ArchivePath, [IO.FileMode]::CreateNew)
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($row in $Plan.files) {
                $entry = if ($row.path -ceq $Plan.executable) { "BeatTheHouse-$($Plan.version).exe" } else { $row.path }
                $files.Add($entry, $row)
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $zip, (Join-Path $Plan.stage $row.path), $entry, [IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }

    $zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($entry in $zip.Entries) {
            $row = $files[$entry.FullName]
            if ($null -eq $row -or $entry.Length -ne $row.bytes) { throw "Unexpected archive entry: $($entry.FullName)" }
            $entryStream = $entry.Open()
            try { $hash = (Get-FileHash -InputStream $entryStream -Algorithm SHA256).Hash.ToLowerInvariant() }
            finally { $entryStream.Dispose() }
            if ($hash -cne $row.sha256) { throw "Archive entry differs from the audited export: $($entry.FullName)" }
            $files.Remove($entry.FullName)
        }
        if ($files.Count -ne 0) { throw 'The archive is missing audited export files.' }
    } finally { $zip.Dispose() }
}

$candidatePath = (Resolve-Path -LiteralPath $CandidateManifest).ProviderPath
$candidateRoot = Split-Path -Parent $candidatePath
$candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
if ($candidate.schema -cne 'beat_the_house.candidate_manifest/v1' -or
    $candidate.source_dirty -isnot [bool] -or $candidate.source_dirty -or
    $candidate.source_commit -cnotmatch '^[0-9a-f]{40}$' -or $candidate.source_tree -cnotmatch '^[0-9a-f]{40}$' -or
    $candidate.export_presets_sha256 -cnotmatch '^[0-9a-f]{64}$' -or $candidate.dirty_state_digest -cnotmatch '^[0-9a-f]{64}$' -or
    $candidate.candidate_key -cne (Split-Path -Leaf $candidateRoot)) {
    throw 'Provide a clean registered candidate manifest.'
}

$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$output = $output.TrimEnd([char[]]@('\', '/'))
if ((Test-Path -LiteralPath $output) -or $output.StartsWith("$candidateRoot\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Release output must be a new directory outside the candidate: $output"
}

$windows = Read-ReleasePlatform $candidate $candidateRoot 'windows'
$web = Read-ReleasePlatform $candidate $candidateRoot 'web'
if ($windows.version -cne $web.version) { throw 'Windows and Web must use the same release version.' }

$parent = Split-Path -Parent $output
$staging = Join-Path $parent ('.release-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($staging)
$packages = @()
try {
    foreach ($plan in @($windows, $web)) {
        $name = "BeatTheHouse-$($plan.version)-$($plan.platform).zip"
        $packages += $name
        Write-ReleaseArchive $plan (Join-Path $staging $name)
    }
    [IO.Directory]::Move($staging, $output)
} finally {
    if (Test-Path -LiteralPath $staging -PathType Container) {
        foreach ($name in $packages) {
            $file = Join-Path $staging $name
            if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file }
        }
        Remove-Item -LiteralPath $staging
    }
}

foreach ($name in $packages) { Write-Host (Join-Path $output $name) }
