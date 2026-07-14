<#
Retention policy:
- Development artifacts remain local through development.
- Release cleanup starts only after a verified copy and manifest exist.
- Clean requires both a matching export manifest and -IAmSure.
- .tools is protected local toolchain content and is never deleted.

The default mode is read-only reporting. Export copies; it never moves.
#>

[CmdletBinding()]
param(
    [switch]$Report,
    [string]$Export = "",
    [switch]$Clean,
    [string]$Destination = "",
    [switch]$IAmSure,
    [string[]]$IncludePath = @(),
    [int]$TopPerCategory = 50
)

$ErrorActionPreference = "Stop"
$script:RepoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$script:ManifestName = "artifact_manifest.json"
$script:ProtectedPrefix = ".tools/"

function Get-FullPath {
    param([string]$Path, [string]$BasePath = "")
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        $BasePath = (Get-Location).Path
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Test-PathInside {
    param([string]$Path, [string]$Directory, [switch]$AllowEqual)
    $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    $fullDirectory = [System.IO.Path]::GetFullPath($Directory).TrimEnd([char[]]@('\', '/'))
    if ($AllowEqual -and $fullPath.Equals($fullDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    $prefix = $fullDirectory + [System.IO.Path]::DirectorySeparatorChar
    return $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-RepoRelativePath {
    param([string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-PathInside -Path $fullPath -Directory $script:RepoRoot -AllowEqual)) {
        throw "Path is outside the repository: $fullPath"
    }
    if ($fullPath.Equals($script:RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ""
    }
    return $fullPath.Substring($script:RepoRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
}

function Test-GitIgnored {
    param([string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return $false
    }
    & git -C $script:RepoRoot check-ignore --quiet --no-index -- $RelativePath
    return $LASTEXITCODE -eq 0
}

function Assert-GitIgnored {
    param([string]$Path)
    $relativePath = Get-RepoRelativePath -Path $Path
    if (-not (Test-GitIgnored -RelativePath $relativePath)) {
        throw "Refusing to manage a path not covered by .gitignore: $relativePath"
    }
}

function Get-ArtifactCategory {
    param([string]$RelativePath)
    $normalized = $RelativePath.Replace('\', '/').ToLowerInvariant()
    $name = [System.IO.Path]::GetFileName($normalized)
    if ($normalized.StartsWith($script:ProtectedPrefix)) {
        return "protected toolchain"
    }
    if ($normalized.StartsWith("builds/")) {
        return "export artifacts"
    }
    if ($normalized -match "(mouse[_-]?batch|mouse[_-]?playtest|playtest[_-]?batch)") {
        return "mouse-batch logs"
    }
    if ($normalized -match "(visual[_-]?qa|screenshot|capture|visual[_-]?audit)") {
        return "visual QA output"
    }
    if ($normalized -match "(staging|baseline[_-]?head|worktree|backup|old[_-]?script|source[_-]?copy)" -or $name -match "\.(bak|old|orig|copy)$") {
        return "staging file copies"
    }
    if ($normalized -match "(probe|audit|report|check[_-]?godot|determinism|soak|stuck[_-]?state|seed[_-]?audit)") {
        return "probe reports"
    }
    return "unknown"
}

function New-InventoryEntry {
    param([System.IO.FileInfo]$File)
    $relativePath = Get-RepoRelativePath -Path $File.FullName
    return [pscustomobject][ordered]@{
        Path = $relativePath
        FullPath = $File.FullName
        Size = [int64]$File.Length
        Category = Get-ArtifactCategory -RelativePath $relativePath
        LastWriteUtc = $File.LastWriteTimeUtc.ToString("o")
    }
}

function Add-InventoryPath {
    param(
        [string]$Path,
        [hashtable]$Seen,
        [System.Collections.Generic.List[object]]$Entries,
        [string]$ExcludedDirectory = ""
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    Assert-GitIgnored -Path $Path
    $item = Get-Item -LiteralPath $Path -Force
    $files = @()
    if ($item -is [System.IO.FileInfo]) {
        $files = @($item)
    }
    else {
        $files = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction Stop)
    }
    foreach ($file in $files) {
        if (-not [string]::IsNullOrWhiteSpace($ExcludedDirectory) -and (Test-PathInside -Path $file.FullName -Directory $ExcludedDirectory -AllowEqual)) {
            continue
        }
        $key = [System.IO.Path]::GetFullPath($file.FullName).ToLowerInvariant()
        if ($Seen.ContainsKey($key)) {
            continue
        }
        $Seen[$key] = $true
        $Entries.Add((New-InventoryEntry -File $file))
    }
}

function Get-DefaultInventoryRoots {
    $relativeRoots = @(
        ".tmp",
        "builds",
        ".tools",
        "tmp",
        "user",
        "tools/__pycache__",
        "__pycache__"
    )
    $roots = @()
    foreach ($relativeRoot in $relativeRoots) {
        $fullPath = Get-FullPath -Path $relativeRoot -BasePath $script:RepoRoot
        if (Test-Path -LiteralPath $fullPath) {
            $roots += $fullPath
        }
    }
    return $roots
}

function Get-IgnoredLooseClutter {
    $paths = @()
    $ignored = @(& git -C $script:RepoRoot ls-files --others --ignored --exclude-standard)
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files could not enumerate ignored clutter."
    }
    foreach ($relativeValue in $ignored) {
        $relativePath = ([string]$relativeValue).Replace('\', '/')
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }
        if ($relativePath.StartsWith(".tmp/") -or $relativePath.StartsWith("builds/") -or $relativePath.StartsWith(".tools/") -or $relativePath.StartsWith("tmp/") -or $relativePath.StartsWith("user/") -or $relativePath.StartsWith("tools/__pycache__/") -or $relativePath.StartsWith("__pycache__/")) {
            continue
        }
        $extension = [System.IO.Path]::GetExtension($relativePath).ToLowerInvariant()
        if ($extension -notin @(".tmp", ".log", ".pyc", ".uid", ".import")) {
            continue
        }
        $paths += (Get-FullPath -Path $relativePath -BasePath $script:RepoRoot)
    }
    return $paths
}

function Get-ArtifactInventory {
    param([string[]]$ScopedPaths, [string]$ExcludedDirectory = "")
    $entries = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    if ($ScopedPaths.Count -gt 0) {
        foreach ($scopePath in $ScopedPaths) {
            $fullPath = Get-FullPath -Path $scopePath -BasePath $script:RepoRoot
            if (-not (Test-PathInside -Path $fullPath -Directory $script:RepoRoot -AllowEqual)) {
                throw "Scoped inventory path is outside the repository: $fullPath"
            }
            Add-InventoryPath -Path $fullPath -Seen $seen -Entries $entries -ExcludedDirectory $ExcludedDirectory
        }
    }
    else {
        foreach ($rootPath in Get-DefaultInventoryRoots) {
            Add-InventoryPath -Path $rootPath -Seen $seen -Entries $entries -ExcludedDirectory $ExcludedDirectory
        }
        foreach ($loosePath in Get-IgnoredLooseClutter) {
            Add-InventoryPath -Path $loosePath -Seen $seen -Entries $entries -ExcludedDirectory $ExcludedDirectory
        }
    }
    return @($entries | Sort-Object -Property Size -Descending)
}

function Format-ByteSize {
    param([int64]$Bytes)
    if ($Bytes -ge 1TB) {
        return "{0:N2} TB" -f ($Bytes / 1TB)
    }
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    if ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    return "$Bytes B"
}

function Write-InventoryReport {
    param([object[]]$Inventory)
    $totalBytes = [int64](($Inventory | Measure-Object -Property Size -Sum).Sum)
    Write-Output "Local artifact inventory (read-only)"
    Write-Output ("Repository: {0}" -f $script:RepoRoot)
    Write-Output ("Files: {0}" -f $Inventory.Count)
    Write-Output ("Total: {0} ({1} bytes)" -f (Format-ByteSize -Bytes $totalBytes), $totalBytes)
    $groups = @($Inventory | Group-Object -Property Category)
    $groupRows = @()
    foreach ($group in $groups) {
        $groupBytes = [int64](($group.Group | Measure-Object -Property Size -Sum).Sum)
        $groupRows += [pscustomobject]@{
            Category = $group.Name
            Files = $group.Count
            Bytes = $groupBytes
            Size = Format-ByteSize -Bytes $groupBytes
        }
    }
    Write-Output ""
    Write-Output "Category totals:"
    $groupRows | Sort-Object -Property Bytes -Descending | Format-Table Category, Files, Size, Bytes -AutoSize | Out-String | Write-Output
    foreach ($row in $groupRows | Sort-Object -Property Bytes -Descending) {
        Write-Output ("[{0}]" -f $row.Category)
        $categoryItems = @($Inventory | Where-Object { $_.Category -eq $row.Category } | Sort-Object -Property Size -Descending)
        if ($TopPerCategory -gt 0) {
            $categoryItems = @($categoryItems | Select-Object -First $TopPerCategory)
        }
        foreach ($entry in $categoryItems) {
            Write-Output ("{0,12}  {1}" -f (Format-ByteSize -Bytes $entry.Size), $entry.Path)
        }
        if ($TopPerCategory -gt 0 -and $row.Files -gt $TopPerCategory) {
            Write-Output ("... {0} more file(s); use -TopPerCategory 0 for the full list." -f ($row.Files - $TopPerCategory))
        }
        Write-Output ""
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Export-ArtifactInventory {
    param([object[]]$Inventory, [string]$ExportDestination)
    $destinationRoot = Get-FullPath -Path $ExportDestination
    if (Test-PathInside -Path $script:RepoRoot -Directory $destinationRoot -AllowEqual) {
        throw "Export destination cannot contain the repository."
    }
    New-Item -ItemType Directory -Force -Path $destinationRoot | Out-Null
    $manifestEntries = New-Object System.Collections.Generic.List[object]
    $copiedBytes = [int64]0
    foreach ($entry in $Inventory) {
        $destinationPath = Get-FullPath -Path $entry.Path -BasePath $destinationRoot
        if (-not (Test-PathInside -Path $destinationPath -Directory $destinationRoot)) {
            throw "Refusing export path outside destination: $($entry.Path)"
        }
        $parent = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
        $sourceHash = Get-Sha256 -Path $entry.FullPath
        Copy-Item -LiteralPath $entry.FullPath -Destination $destinationPath -Force
        $destinationHash = Get-Sha256 -Path $destinationPath
        if ($sourceHash -ne $destinationHash) {
            throw "Export verification failed for $($entry.Path)."
        }
        $manifestEntries.Add([pscustomobject][ordered]@{
            path = $entry.Path
            size = [int64]$entry.Size
            sha256 = $sourceHash
            category = $entry.Category
            source_last_write_utc = $entry.LastWriteUtc
        })
        $copiedBytes += [int64]$entry.Size
    }
    $manifest = [pscustomobject][ordered]@{
        schema_version = 1
        capture_date_utc = [DateTime]::UtcNow.ToString("o")
        repository_root = $script:RepoRoot
        destination_root = $destinationRoot
        file_count = $manifestEntries.Count
        total_bytes = $copiedBytes
        files = $manifestEntries.ToArray()
    }
    $manifestPath = Join-Path $destinationRoot $script:ManifestName
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Output ("Export verified: {0} file(s), {1}." -f $manifestEntries.Count, (Format-ByteSize -Bytes $copiedBytes))
    Write-Output ("Manifest: {0}" -f $manifestPath)
    Write-Output "Source files were copied and remain untouched."
}

function Clean-VerifiedArtifacts {
    param([string]$ExportDestination)
    if (-not $IAmSure) {
        throw "Clean refused: -IAmSure is required in addition to a verified export manifest."
    }
    if ([string]::IsNullOrWhiteSpace($ExportDestination)) {
        throw "Clean refused: -Destination must identify the prior export folder."
    }
    $destinationRoot = Get-FullPath -Path $ExportDestination
    $manifestPath = Join-Path $destinationRoot $script:ManifestName
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Clean refused: no prior export manifest exists at $manifestPath."
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $verified = New-Object System.Collections.Generic.List[object]
    $protectedCount = 0
    foreach ($manifestEntry in @($manifest.files)) {
        $relativePath = ([string]$manifestEntry.path).Replace('\', '/')
        if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath) -or $relativePath.Split('/') -contains "..") {
            throw "Clean refused: manifest contains unsafe path '$relativePath'."
        }
        if ($relativePath.ToLowerInvariant().StartsWith($script:ProtectedPrefix)) {
            $protectedCount += 1
            continue
        }
        $sourcePath = Get-FullPath -Path $relativePath -BasePath $script:RepoRoot
        if (-not (Test-PathInside -Path $sourcePath -Directory $script:RepoRoot)) {
            throw "Clean refused: manifest source is outside the repository: $relativePath"
        }
        Assert-GitIgnored -Path $sourcePath
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            continue
        }
        $exportedPath = Get-FullPath -Path $relativePath -BasePath $destinationRoot
        if (-not (Test-PathInside -Path $exportedPath -Directory $destinationRoot)) {
            throw "Clean refused: exported path escapes the destination: $relativePath"
        }
        if (-not (Test-Path -LiteralPath $exportedPath -PathType Leaf)) {
            throw "Clean refused: verified export copy is missing for $relativePath."
        }
        $expectedHash = ([string]$manifestEntry.sha256).ToLowerInvariant()
        $sourceHash = Get-Sha256 -Path $sourcePath
        $exportedHash = Get-Sha256 -Path $exportedPath
        if ($sourceHash -ne $expectedHash -or $exportedHash -ne $expectedHash) {
            throw "Clean refused: source/export hash mismatch for $relativePath."
        }
        if ([int64](Get-Item -LiteralPath $sourcePath).Length -ne [int64]$manifestEntry.size) {
            throw "Clean refused: source size mismatch for $relativePath."
        }
        $verified.Add([pscustomobject]@{
            Path = $sourcePath
            RelativePath = $relativePath
        })
    }
    foreach ($entry in $verified) {
        Remove-Item -LiteralPath $entry.Path -Force
    }
    Write-Output ("Clean completed: removed {0} manifest-verified source file(s)." -f $verified.Count)
    if ($protectedCount -gt 0) {
        Write-Output ("Protected .tools entries skipped: {0}." -f $protectedCount)
    }
    Write-Output "Export copies and manifest remain untouched."
}

$modeCount = 0
if ($Report) {
    $modeCount += 1
}
if (-not [string]::IsNullOrWhiteSpace($Export)) {
    $modeCount += 1
}
if ($Clean) {
    $modeCount += 1
}
if ($modeCount -gt 1) {
    throw "Choose exactly one mode: -Report, -Export <destination>, or -Clean."
}
if ($modeCount -eq 0) {
    $Report = $true
}

if ($Clean) {
    Clean-VerifiedArtifacts -ExportDestination $Destination
    exit 0
}

$excludedDestination = ""
if (-not [string]::IsNullOrWhiteSpace($Export)) {
    $excludedDestination = Get-FullPath -Path $Export
}
$inventory = @(Get-ArtifactInventory -ScopedPaths $IncludePath -ExcludedDirectory $excludedDestination)
if ($Report) {
    Write-InventoryReport -Inventory $inventory
    exit 0
}
Export-ArtifactInventory -Inventory $inventory -ExportDestination $Export
