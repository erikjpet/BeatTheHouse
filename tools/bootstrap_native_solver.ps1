param(
    [ValidateSet("Windows", "Web", "All")]
    [string]$Target = "All",
    [switch]$Force,
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $root "native/coin_pusher/toolchain.lock.json"
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
$toolRoot = Join-Path $root ".tools/native_solver"
$downloadRoot = Join-Path $toolRoot "downloads"
$pythonRoot = Join-Path $toolRoot "python"
$pythonExe = Join-Path $pythonRoot "python.exe"
$godotCppRoot = Join-Path $toolRoot "godot-cpp"
$windowsRoot = Join-Path $toolRoot "llvm-mingw-package"
$emsdkRoot = Join-Path $toolRoot "emsdk"

function Assert-NativeToolchainLock {
    param([object]$Value)
    if ([string]$Value.schema -ne "bth_native_toolchain_lock" -or [int]$Value.version -ne 1) {
        throw "Native toolchain lock schema/version is invalid."
    }
    foreach ($commit in @(
        [string]$Value.godot.commit,
        [string]$Value.godot_cpp.commit,
        [string]$Value.godot_cpp.synced_godot_commit,
        [string]$Value.windows.compiler_commit,
        [string]$Value.web.compiler_commit,
        [string]$Value.web.commit
    )) {
        if ($commit -notmatch '^[0-9a-f]{40}$') {
            throw "Native toolchain commit is not a pinned lowercase SHA-1: $commit"
        }
    }
    foreach ($sha in @(
        [string]$Value.godot_cpp.extension_api_sha256,
        [string]$Value.godot_cpp.gdextension_interface_sha256,
        [string]$Value.python.archive_sha256,
        [string]$Value.scons.wheel_sha256,
        [string]$Value.windows.archive_sha256,
        [string]$Value.web.template_sha256
    )) {
        if ($sha -notmatch '^[0-9a-f]{64}$') {
            throw "Native toolchain archive hash is not a pinned lowercase SHA-256: $sha"
        }
    }
    foreach ($urlValue in @(
        [string]$Value.godot_cpp.repository,
        [string]$Value.python.archive_url,
        [string]$Value.scons.wheel_url,
        [string]$Value.windows.archive_url,
        [string]$Value.web.repository
    )) {
        $uri = [System.Uri]$urlValue
        if ($uri.Scheme -ne "https" -or $uri.Host -notin @("github.com", "files.pythonhosted.org", "www.python.org")) {
            throw "Native toolchain URL is not on an approved HTTPS origin: $urlValue"
        }
        $leaf = [System.Uri]::UnescapeDataString(($uri.AbsolutePath -split '/')[-1])
        if ($leaf -notmatch '^[A-Za-z0-9._-]+$' -or $leaf -in @(".", "..")) {
            throw "Native toolchain URL has an unsafe leaf name: $urlValue"
        }
    }
    $reviewed = @{
        godot_version = "4.6-stable"
        godot_commit = "89cea143987d564363e15d207438530651d943ac"
        godot_cpp_repository = "https://github.com/godotengine/godot-cpp.git"
        godot_cpp_source_ref = "commit:58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74"
        godot_cpp_commit = "58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74"
        godot_cpp_api = "4.6"
        godot_cpp_synced_godot_commit = "89cea143987d564363e15d207438530651d943ac"
        godot_cpp_extension_api_sha256 = "00a3ad6df2361ed3df6ef9bc8717fe0f49112012ee6e87a7b4cfb34465c9beed"
        godot_cpp_interface_sha256 = "34d7058f31af186d36b84567e70a9f9543da0d74f25cfe5266d4fe2d27e090f0"
        python_version = "3.12.10"
        python_architecture = "amd64"
        python_archive_url = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip"
        python_archive_sha256 = "4acbed6dd1c744b0376e3b1cf57ce906f9dc9e95e68824584c8099a63025a3c3"
        scons_version = "4.10.1"
        scons_wheel_url = "https://files.pythonhosted.org/packages/ce/bf/931fb9fbb87234c32b8b1b1c15fba23472a10777c12043336675633809a7/scons-4.10.1-py3-none-any.whl"
        scons_wheel_sha256 = "bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126"
        windows_toolchain = "llvm-mingw"
        windows_version = "20260616"
        windows_compiler = "22.1.8"
        windows_compiler_commit = "ca7933e47d3a3451d81e72ac174dcb5aa28b59d1"
        windows_runtime = "ucrt"
        windows_architecture = "x86_64"
        windows_target = "x86_64-w64-windows-gnu"
        windows_archive_url = "https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/llvm-mingw-20260616-ucrt-x86_64.zip"
        windows_archive_sha256 = "b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35"
        web_toolchain = "emsdk"
        web_version = "4.0.20"
        web_compiler_commit = "6913738ec5371a88c4af5a80db0ab42bad3de681"
        web_repository = "https://github.com/emscripten-core/emsdk.git"
        web_commit = "e4fe26ef59168ff44f4c23c466e497bf60b3411e"
        web_template = "web_dlink_nothreads_release.zip"
        web_template_sha256 = "d0aaaed2f2e81b62e58d1a5de511a4b7687303e2574bec02be86276b7d2da60c"
    }
    $actual = @{
        godot_version = [string]$Value.godot.version
        godot_commit = [string]$Value.godot.commit
        godot_cpp_repository = [string]$Value.godot_cpp.repository
        godot_cpp_source_ref = [string]$Value.godot_cpp.source_ref
        godot_cpp_commit = [string]$Value.godot_cpp.commit
        godot_cpp_api = [string]$Value.godot_cpp.api_version
        godot_cpp_synced_godot_commit = [string]$Value.godot_cpp.synced_godot_commit
        godot_cpp_extension_api_sha256 = [string]$Value.godot_cpp.extension_api_sha256
        godot_cpp_interface_sha256 = [string]$Value.godot_cpp.gdextension_interface_sha256
        python_version = [string]$Value.python.version
        python_architecture = [string]$Value.python.architecture
        python_archive_url = [string]$Value.python.archive_url
        python_archive_sha256 = [string]$Value.python.archive_sha256
        scons_version = [string]$Value.scons.version
        scons_wheel_url = [string]$Value.scons.wheel_url
        scons_wheel_sha256 = [string]$Value.scons.wheel_sha256
        windows_toolchain = [string]$Value.windows.toolchain
        windows_version = [string]$Value.windows.version
        windows_compiler = [string]$Value.windows.compiler_version
        windows_compiler_commit = [string]$Value.windows.compiler_commit
        windows_runtime = [string]$Value.windows.runtime
        windows_architecture = [string]$Value.windows.architecture
        windows_target = [string]$Value.windows.target
        windows_archive_url = [string]$Value.windows.archive_url
        windows_archive_sha256 = [string]$Value.windows.archive_sha256
        web_toolchain = [string]$Value.web.toolchain
        web_version = [string]$Value.web.version
        web_compiler_commit = [string]$Value.web.compiler_commit
        web_repository = [string]$Value.web.repository
        web_commit = [string]$Value.web.commit
        web_template = [string]$Value.web.template
        web_template_sha256 = [string]$Value.web.template_sha256
    }
    foreach ($key in $reviewed.Keys) {
        if ($actual[$key] -cne $reviewed[$key]) {
            throw "Native toolchain lock field '$key' drifted: expected '$($reviewed[$key])', got '$($actual[$key])'."
        }
    }
}

function Assert-NoReparseComponents {
    param([string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $volumeRoot = [System.IO.Path]::GetPathRoot($fullPath)
    $current = $volumeRoot
    $relative = $fullPath.Substring($volumeRoot.Length)
    foreach ($part in $relative.Split([System.IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $part
        if (-not (Test-Path -LiteralPath $current)) {
            continue
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing native-tool path through a reparse point: $current"
        }
    }
}

function Assert-UnderToolRoot {
    param([string]$Path)
    $resolvedRoot = [System.IO.Path]::GetFullPath($toolRoot)
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    Assert-NoReparseComponents $resolvedRoot
    if (-not $resolvedPath.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing native-tool mutation outside $resolvedRoot`: $resolvedPath"
    }
    Assert-NoReparseComponents $resolvedPath
}

function Remove-ToolDirectory {
    param([string]$Path)
    Assert-UnderToolRoot $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $rootItem = Get-Item -LiteralPath $Path -Force
    if (-not $rootItem.PSIsContainer) {
        throw "Remove-ToolDirectory requires a directory: $Path"
    }
    $stack = [System.Collections.Generic.Stack[object]]::new()
    $postorder = [System.Collections.Generic.List[object]]::new()
    $stack.Push($rootItem)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        $postorder.Add($directory)
        foreach ($child in $directory.GetFileSystemInfos()) {
            if (($child.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                $child.Delete()
            }
            elseif ($child -is [System.IO.DirectoryInfo]) {
                $stack.Push($child)
            }
            else {
                Remove-Item -LiteralPath $child.FullName -Force
            }
        }
    }
    for ($index = $postorder.Count - 1; $index -ge 0; --$index) {
        Remove-Item -LiteralPath $postorder[$index].FullName -Force
    }
}

function Enter-NativeBootstrapMutex {
    param([string]$Name)
    $mutex = [System.Threading.Mutex]::new($false, $Name)
    $acquired = $false
    try {
        $acquired = $mutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $acquired = $true
        $script:NativeBootstrapRecoveredAbandonedMutex = $true
    }
    if (-not $acquired) {
        $mutex.Dispose()
        throw "Another native solver bootstrap is already running."
    }
    return $mutex
}

function Test-FileChecksum {
    param([string]$Path, [string]$Sha256)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    Assert-UnderToolRoot $Path
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return $actual -ceq $Sha256.ToLowerInvariant()
}

function Remove-InvalidCachedArtifact {
    param([string]$Path, [string]$Sha256)
    Assert-UnderToolRoot $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    if (Test-FileChecksum $Path $Sha256) {
        return $true
    }
    Remove-Item -LiteralPath $Path -Force
    return $false
}

function Get-VerifiedDownload {
    param([string]$Url, [string]$Path, [string]$Sha256)
    Assert-UnderToolRoot $Path
    if (Remove-InvalidCachedArtifact $Path $Sha256) {
        return
    }
    Write-Host "Downloading $(Split-Path -Leaf $Path)..."
    Invoke-WebRequest -Uri $Url -OutFile $Path
    if (-not (Test-FileChecksum $Path $Sha256)) {
        $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        Remove-Item -LiteralPath $Path -Force
        throw "Checksum mismatch for $Url`: expected $Sha256, got $actual"
    }
}

function Assert-SafeZipEntryName {
    param([string]$Name, [string]$DestinationRoot)
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.IndexOf([char]0) -ge 0) {
        throw "Archive contains an empty or NUL-bearing entry name."
    }
    $normalized = $Name.Replace('\', '/')
    if ($normalized.StartsWith('/') -or $normalized.StartsWith('//') -or $normalized -match '^[A-Za-z]:' -or $normalized.Contains(':')) {
        throw "Archive entry is rooted, drive-qualified, UNC, or ADS-qualified: $Name"
    }
    $isDirectory = $normalized.EndsWith('/')
    $parts = $normalized.TrimEnd('/').Split('/')
    if ($parts.Count -eq 0) {
        throw "Archive entry has no safe path components: $Name"
    }
    foreach ($part in $parts) {
        if ([string]::IsNullOrWhiteSpace($part) -or $part -in @('.', '..') -or $part.EndsWith('.') -or $part.EndsWith(' ')) {
            throw "Archive entry contains an unsafe or ambiguous component: $Name"
        }
        $deviceStem = ($part -split '\.')[0]
        if ($deviceStem.ToUpperInvariant() -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
            throw "Archive entry contains a reserved Windows device component: $Name"
        }
    }
    $destination = [System.IO.Path]::GetFullPath($DestinationRoot)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $destination ($normalized -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
    if (-not $candidate.StartsWith($destination + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Archive entry escapes its destination: $Name"
    }
    return @{ normalized = $normalized; directory = $isDirectory; destination = $candidate }
}

function Assert-ArchiveEntriesSafe {
    param([string]$ArchivePath, [string]$DestinationRoot)
    Assert-UnderToolRoot $ArchivePath
    Assert-UnderToolRoot $DestinationRoot
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $archive.Entries) {
            $checked = Assert-SafeZipEntryName $entry.FullName $DestinationRoot
            $key = [string]$checked.normalized
            if (-not $seen.Add($key.TrimEnd('/'))) {
                throw "Archive contains a case/separator-colliding duplicate entry: $($entry.FullName)"
            }
            $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
            $windowsAttributes = $entry.ExternalAttributes -band 0xFFFF
            if ($unixType -eq 0xA000 -or ($windowsAttributes -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Archive contains a symlink/reparse entry: $($entry.FullName)"
            }
            if ($unixType -notin @(0, 0x4000, 0x8000)) {
                throw "Archive contains a non-file/non-directory entry type: $($entry.FullName)"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

function Expand-VerifiedArchive {
    param([string]$ArchivePath, [string]$DestinationRoot)
    Assert-UnderToolRoot $ArchivePath
    Assert-UnderToolRoot $DestinationRoot
    if (Test-Path -LiteralPath $DestinationRoot) {
        throw "Verified archive destination must not already exist: $DestinationRoot"
    }
    Add-Type -AssemblyName System.IO.Compression
    $archiveStream = [System.IO.File]::Open($ArchivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($archiveStream, [System.IO.Compression.ZipArchiveMode]::Read, $true)
        try {
            $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($entry in $archive.Entries) {
                $checked = Assert-SafeZipEntryName $entry.FullName $DestinationRoot
                if (-not $seen.Add(([string]$checked.normalized).TrimEnd('/'))) {
                    throw "Archive contains a case/separator-colliding duplicate entry: $($entry.FullName)"
                }
                $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
                $windowsAttributes = $entry.ExternalAttributes -band 0xFFFF
                if ($unixType -eq 0xA000 -or ($windowsAttributes -band [int][System.IO.FileAttributes]::ReparsePoint) -ne 0 -or $unixType -notin @(0, 0x4000, 0x8000)) {
                    throw "Archive contains a link/reparse/special entry: $($entry.FullName)"
                }
            }
            New-Item -ItemType Directory -Path $DestinationRoot | Out-Null
            foreach ($entry in $archive.Entries) {
                $checked = Assert-SafeZipEntryName $entry.FullName $DestinationRoot
                $entryDestination = [string]$checked.destination
                if ([bool]$checked.directory) {
                    New-Item -ItemType Directory -Force -Path $entryDestination | Out-Null
                    continue
                }
                $parent = Split-Path -Parent $entryDestination
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
                $input = $entry.Open()
                try {
                    $output = [System.IO.File]::Open($entryDestination, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    try { $input.CopyTo($output) } finally { $output.Dispose() }
                }
                finally {
                    $input.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $archiveStream.Dispose()
    }
    Assert-UnderToolRoot $DestinationRoot
}

function Get-StreamSha256 {
    param([System.IO.Stream]$Stream)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Test-InstalledArchiveMatches {
    param([string]$ArchivePath, [string]$InstallRoot)
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        return $false
    }
    try {
        Assert-ArchiveEntriesSafe $ArchivePath $InstallRoot
        Assert-UnderToolRoot $InstallRoot
        $actualFiles = @{}
        $installPrefix = [System.IO.Path]::GetFullPath($InstallRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        foreach ($file in Get-ChildItem -LiteralPath $InstallRoot -File -Recurse -Force) {
            Assert-UnderToolRoot $file.FullName
            $relative = ([System.IO.Path]::GetFullPath($file.FullName)).Substring($installPrefix.Length).Replace('\', '/')
            $actualFiles[$relative.ToLowerInvariant()] = $file.FullName
        }
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            $expectedCount = 0
            foreach ($entry in $archive.Entries) {
                $checked = Assert-SafeZipEntryName $entry.FullName $InstallRoot
                if ([bool]$checked.directory) {
                    continue
                }
                ++$expectedCount
                $key = ([string]$checked.normalized).ToLowerInvariant()
                if (-not $actualFiles.ContainsKey($key)) {
                    return $false
                }
                $entryStream = $entry.Open()
                try { $expectedSha = Get-StreamSha256 $entryStream } finally { $entryStream.Dispose() }
                $actualSha = (Get-FileHash -LiteralPath $actualFiles[$key] -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($actualSha -cne $expectedSha) {
                    return $false
                }
            }
            return $actualFiles.Count -eq $expectedCount
        }
        finally {
            $archive.Dispose()
        }
    }
    catch {
        return $false
    }
}

function Promote-ToolDirectory {
    param([string]$StagingPath, [string]$DestinationPath)
    Assert-UnderToolRoot $StagingPath
    Assert-UnderToolRoot $DestinationPath
    $backupPath = "$DestinationPath.previous"
    Remove-ToolDirectory $backupPath
    $hadDestination = Test-Path -LiteralPath $DestinationPath
    $promoted = $false
    try {
        if ($hadDestination) {
            Move-Item -LiteralPath $DestinationPath -Destination $backupPath
        }
        Move-Item -LiteralPath $StagingPath -Destination $DestinationPath
        $promoted = $true
    }
    catch {
        if (-not (Test-Path -LiteralPath $DestinationPath) -and (Test-Path -LiteralPath $backupPath)) {
            Move-Item -LiteralPath $backupPath -Destination $DestinationPath
        }
        throw
    }
    finally {
        if ($promoted) {
            Remove-ToolDirectory $backupPath
        }
    }
}

function Install-VerifiedArchive {
    param([string]$ArchivePath, [string]$DestinationPath)
    Assert-UnderToolRoot $DestinationPath
    if (-not $Force -and (Test-InstalledArchiveMatches $ArchivePath $DestinationPath)) {
        return
    }
    $stagingPath = "$DestinationPath.staging"
    Remove-ToolDirectory $stagingPath
    try {
        Expand-VerifiedArchive $ArchivePath $stagingPath
        if (-not (Test-InstalledArchiveMatches $ArchivePath $stagingPath)) {
            throw "Staged archive install failed full provenance validation: $ArchivePath"
        }
        Promote-ToolDirectory $stagingPath $DestinationPath
    }
    finally {
        Remove-ToolDirectory $stagingPath
    }
}

function New-SelfTestZipArchive {
    param([string]$Path, [object[]]$Entries)
    Assert-UnderToolRoot $Path
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($spec in $Entries) {
                $entry = $archive.CreateEntry([string]$spec.name)
                if ($spec.ContainsKey("external_attributes")) {
                    $entry.ExternalAttributes = [int]$spec.external_attributes
                }
                if (-not ([string]$spec.name).EndsWith('/') -and -not ([string]$spec.name).EndsWith('\')) {
                    $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
                    try { $writer.Write([string]$spec.content) } finally { $writer.Dispose() }
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-NativeCommand {
    param([scriptblock]$Command, [string]$Failure)
    $output = & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Failure (exit $LASTEXITCODE)."
    }
    return @($output)
}

function Assert-ExactPythonVersion {
    param([string]$Executable, [string]$Expected)
    $output = Invoke-NativeCommand { & $Executable -c "import platform; print(platform.python_version())" } "Could not run pinned Python"
    $actual = (($output | Select-Object -First 1) -as [string]).Trim()
    if ($actual -cne $Expected) {
        throw "Python version drift: expected $Expected, got $actual"
    }
}

function Assert-ExactCompilerVersion {
    param([string[]]$Output, [string]$ExpectedVersion, [string]$ExpectedCommit, [string]$ExpectedTarget)
    $firstLine = (($Output | Select-Object -First 1) -as [string]).Trim()
    $targetLine = (($Output | Where-Object { $_ -match '^Target: ' } | Select-Object -First 1) -as [string]).Trim()
    if ($firstLine -notmatch '^clang version ([0-9]+\.[0-9]+\.[0-9]+) \(https://github\.com/llvm/llvm-project\.git ([0-9a-f]{40})\)$' `
            -or $Matches[1] -cne $ExpectedVersion `
            -or $Matches[2] -cne $ExpectedCommit) {
        throw "LLVM-MinGW compiler version drift: $firstLine"
    }
    if ($targetLine -cne "Target: $ExpectedTarget") {
        throw "LLVM-MinGW target drift: expected '$ExpectedTarget', got '$targetLine'."
    }
}

function Assert-ExactEmccVersion {
    param([string]$FirstLine, [string]$Expected, [string]$ExpectedCommit)
    if ($FirstLine -notmatch '\) ([0-9]+\.[0-9]+\.[0-9]+) \(([0-9a-f]{40})\)$' `
            -or $Matches[1] -cne $Expected `
            -or $Matches[2] -cne $ExpectedCommit) {
        throw "Emscripten version drift: $FirstLine"
    }
}

function Invoke-SafeGit {
    param([string[]]$GitArguments, [string]$Failure)
    $savedConfigEnvironment = @{}
    foreach ($entry in [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process).GetEnumerator()) {
        $name = [string]$entry.Key
        if ($name -match '^GIT_CONFIG_(COUNT|KEY_[0-9]+|VALUE_[0-9]+|PARAMETERS|SYSTEM|GLOBAL|NOSYSTEM)$') {
            $savedConfigEnvironment[$name] = [string]$entry.Value
            [System.Environment]::SetEnvironmentVariable($name, $null, [System.EnvironmentVariableTarget]::Process)
        }
    }
    $previousPrompt = $env:GIT_TERMINAL_PROMPT
    try {
        $env:GIT_CONFIG_NOSYSTEM = "1"
        $env:GIT_CONFIG_GLOBAL = "NUL"
        $env:GIT_TERMINAL_PROMPT = "0"
        return Invoke-NativeCommand { & git @GitArguments } $Failure
    }
    finally {
        foreach ($entry in [System.Environment]::GetEnvironmentVariables([System.EnvironmentVariableTarget]::Process).GetEnumerator()) {
            $name = [string]$entry.Key
            if ($name -match '^GIT_CONFIG_(COUNT|KEY_[0-9]+|VALUE_[0-9]+|PARAMETERS|SYSTEM|GLOBAL|NOSYSTEM)$') {
                [System.Environment]::SetEnvironmentVariable($name, $null, [System.EnvironmentVariableTarget]::Process)
            }
        }
        foreach ($name in $savedConfigEnvironment.Keys) {
            [System.Environment]::SetEnvironmentVariable([string]$name, [string]$savedConfigEnvironment[$name], [System.EnvironmentVariableTarget]::Process)
        }
        $env:GIT_TERMINAL_PROMPT = $previousPrompt
    }
}

function Get-SafeRepositoryConfig {
    param([string]$Repository)
    $safeRepository = $Repository.Replace('\', '/')
    return "[core]`n`trepositoryformatversion = 0`n`tfilemode = false`n`tbare = false`n`tlogallrefupdates = true`n`thooksPath = NUL`n`tfsmonitor = false`n[remote `"origin`"]`n`turl = `"$safeRepository`"`n"
}

function Write-SafeRepositoryConfig {
    param([string]$Path, [string]$Repository)
    $gitRoot = Join-Path $Path ".git"
    $configPath = Join-Path $gitRoot "config"
    Assert-UnderToolRoot $gitRoot
    if (-not (Test-Path -LiteralPath $gitRoot -PathType Container)) {
        throw "Dependency repository has no ordinary .git directory: $Path"
    }
    Assert-UnderToolRoot $configPath
    [System.IO.File]::WriteAllText($configPath, (Get-SafeRepositoryConfig $Repository), [System.Text.UTF8Encoding]::new($false))
}

function Test-PinnedRepository {
    param([string]$Repository, [string]$Commit, [string]$Path)
    try {
        Assert-UnderToolRoot $Path
        $gitRoot = Join-Path $Path ".git"
        $configPath = Join-Path $gitRoot "config"
        if (-not (Test-Path -LiteralPath $gitRoot -PathType Container) -or -not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
            return $false
        }
        Assert-UnderToolRoot $configPath
        if ([System.IO.File]::ReadAllText($configPath) -cne (Get-SafeRepositoryConfig $Repository)) {
            return $false
        }
        $actual = [string](Invoke-SafeGit @("-C", $Path, "rev-parse", "HEAD") "Could not inspect dependency commit" | Select-Object -First 1)
        if ($actual.Trim() -cne $Commit) {
            return $false
        }
        $remote = [string](Invoke-SafeGit @("-C", $Path, "remote", "get-url", "origin") "Could not inspect dependency origin" | Select-Object -First 1)
        if ($remote.Trim().Replace('\', '/') -cne $Repository.Replace('\', '/')) {
            return $false
        }
        $dirty = (Invoke-SafeGit @("-C", $Path, "status", "--porcelain=v1", "--untracked-files=all") "Could not inspect dependency cleanliness") -join "`n"
        return $dirty.Length -eq 0
    }
    catch {
        return $false
    }
}

function Sync-PinnedRepository {
    param([string]$Repository, [string]$Commit, [string]$Path)
    Assert-UnderToolRoot $Path
    if (-not $Force -and (Test-PinnedRepository $Repository $Commit $Path)) {
        return
    }
    $stagingPath = "$Path.staging"
    Remove-ToolDirectory $stagingPath
    try {
        New-Item -ItemType Directory -Path $stagingPath | Out-Null
        Invoke-SafeGit @("init", "--quiet", "--template=", $stagingPath) "Could not initialize transactional dependency repository" | Out-Null
        Write-SafeRepositoryConfig $stagingPath $Repository
        Invoke-SafeGit @("-C", $stagingPath, "fetch", "--quiet", "--no-tags", "--depth", "1", "origin", $Commit) "Could not fetch pinned commit $Commit from $Repository" | Write-Host
        Invoke-SafeGit @("-C", $stagingPath, "checkout", "--quiet", "--detach", "--force", $Commit) "Could not check out pinned commit $Commit" | Write-Host
        Invoke-SafeGit @("-C", $stagingPath, "clean", "-ffdx") "Could not clean transactional dependency checkout" | Write-Host
        if (-not (Test-PinnedRepository $Repository $Commit $stagingPath)) {
            throw "Transactional dependency checkout did not validate: $Repository@$Commit"
        }
        Promote-ToolDirectory $stagingPath $Path
    }
    finally {
        Remove-ToolDirectory $stagingPath
    }
}

function Assert-GodotCppPayloads {
    param([object]$GodotCppLock, [string]$Path)
    $payloads = @(
        @{ path = (Join-Path $Path "gdextension/extension_api.json"); sha256 = [string]$GodotCppLock.extension_api_sha256 },
        @{ path = (Join-Path $Path "gdextension/gdextension_interface.json"); sha256 = [string]$GodotCppLock.gdextension_interface_sha256 }
    )
    foreach ($payload in $payloads) {
        Assert-UnderToolRoot $payload.path
        if (-not (Test-Path -LiteralPath $payload.path -PathType Leaf)) {
            throw "Pinned godot-cpp payload is missing: $($payload.path)"
        }
        $actual = (Get-FileHash -LiteralPath $payload.path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $payload.sha256) {
            throw "Pinned godot-cpp payload hash drift: expected $($payload.sha256), got $actual for $($payload.path)"
        }
    }
}

function Invoke-BootstrapSelfTest {
    $validCopy = (ConvertFrom-Json (ConvertTo-Json $lock -Depth 10))
    Assert-NativeToolchainLock $validCopy
    $mutations = @(
        @{ path = @("godot_cpp", "commit"); value = "../moving-target" },
        @{ path = @("godot", "commit"); value = "89cea1439" },
        @{ path = @("godot", "version"); value = "4.6.1-stable" },
        @{ path = @("godot_cpp", "api_version"); value = "4.5" },
        @{ path = @("python", "version"); value = "3.12.11" },
        @{ path = @("python", "archive_url"); value = "https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-win32.zip" },
        @{ path = @("python", "archive_sha256"); value = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        @{ path = @("scons", "wheel_url"); value = "https://files.pythonhosted.org/packages/ce/bf/alternate/scons-4.10.1-py3-none-any.whl" },
        @{ path = @("scons", "wheel_sha256"); value = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
        @{ path = @("godot_cpp", "repository"); value = "https://github.com/godotengine/godot.git" },
        @{ path = @("windows", "archive_sha256"); value = "not-a-sha256" },
        @{ path = @("windows", "archive_sha256"); value = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" },
        @{ path = @("windows", "archive_url"); value = "https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/llvm-mingw-20260616-ucrt-i686.zip" },
        @{ path = @("windows", "runtime"); value = "msvcrt" },
        @{ path = @("windows", "architecture"); value = "arm64" },
        @{ path = @("windows", "archive_url"); value = "http://example.com/compiler.zip" },
        @{ path = @("windows", "archive_url"); value = "https://github.com/example/%2e%2e" },
        @{ path = @("web", "repository"); value = "https://github.com/emscripten-core/emscripten.git" },
        @{ path = @("web", "compiler_commit"); value = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        @{ path = @("web", "template_sha256"); value = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" },
        @{ path = @("web", "version"); value = "4.0.21" }
    )
    foreach ($mutation in $mutations) {
        $hostile = (ConvertFrom-Json (ConvertTo-Json $lock -Depth 10))
        $parent = $hostile.($mutation.path[0])
        $parent.($mutation.path[1]) = $mutation.value
        $rejected = $false
        try { Assert-NativeToolchainLock $hostile } catch { $rejected = $true }
        if (-not $rejected) {
            throw "Native bootstrap accepted hostile lock mutation '$($mutation.path -join '.')'."
        }
    }

    $outsideRejected = $false
    try { Assert-UnderToolRoot (Join-Path $root "native-tool-outside") } catch { $outsideRejected = $true }
    if (-not $outsideRejected) {
        throw "Native bootstrap accepted a mutation path outside its ignored tool root."
    }

    Assert-NoReparseComponents $toolRoot
    New-Item -ItemType Directory -Force -Path $toolRoot, $downloadRoot | Out-Null
    Assert-UnderToolRoot $downloadRoot
    $junctionTarget = Join-Path $toolRoot "self-test-junction-target"
    $junction = Join-Path $toolRoot "self-test-junction"
    Remove-ToolDirectory $junctionTarget
    if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force }
    New-Item -ItemType Directory -Path $junctionTarget | Out-Null
    try {
        New-Item -ItemType Junction -Path $junction -Target $junctionTarget | Out-Null
        $junctionRejected = $false
        try { Assert-UnderToolRoot (Join-Path $junction "escaped.cache") } catch { $junctionRejected = $true }
        if (-not $junctionRejected) { throw "Native bootstrap accepted a path through a junction." }
    }
    finally {
        if (Test-Path -LiteralPath $junction) { Remove-Item -LiteralPath $junction -Force }
        Remove-ToolDirectory $junctionTarget
    }

    $nestedTree = Join-Path $toolRoot "self-test-nested-reparse-tree"
    $nestedTarget = Join-Path $toolRoot "self-test-nested-reparse-target"
    Remove-ToolDirectory $nestedTree
    Remove-ToolDirectory $nestedTarget
    try {
        New-Item -ItemType Directory -Path (Join-Path $nestedTree "inner") -Force | Out-Null
        New-Item -ItemType Directory -Path $nestedTarget | Out-Null
        $outsideSentinel = Join-Path $nestedTarget "must-survive.txt"
        [System.IO.File]::WriteAllText($outsideSentinel, "outside sentinel")
        New-Item -ItemType Junction -Path (Join-Path $nestedTree "inner/escape") -Target $nestedTarget | Out-Null
        Remove-ToolDirectory $nestedTree
        if (-not (Test-Path -LiteralPath $outsideSentinel) -or (Test-Path -LiteralPath $nestedTree)) {
            throw "Safe recursive cleanup traversed a nested junction or retained the guarded tree."
        }
    }
    finally {
        Remove-ToolDirectory $nestedTree
        Remove-ToolDirectory $nestedTarget
    }

    $zipDestination = Join-Path $toolRoot "self-test-zip-destination"
    $zipEscape = Join-Path $toolRoot "self-test-zip-escape.txt"
    $hostileZip = Join-Path $downloadRoot "self-test-hostile.zip"
    $duplicateZip = Join-Path $downloadRoot "self-test-duplicate.zip"
    $symlinkZip = Join-Path $downloadRoot "self-test-symlink.zip"
    $safeZip = Join-Path $downloadRoot "self-test-safe.zip"
    foreach ($path in @($hostileZip, $duplicateZip, $symlinkZip, $safeZip, $zipEscape)) {
        if (Test-Path -LiteralPath $path) { Assert-UnderToolRoot $path; Remove-Item -LiteralPath $path -Force }
    }
    Remove-ToolDirectory $zipDestination
    try {
        foreach ($unsafeName in @('../escape', '..\escape', '/rooted', '\rooted', 'C:\drive', '\\server\share', 'safe/../escape', 'safe\..\escape', 'file:stream', 'safe/CON.txt', 'safe/trailing.')) {
            $rejected = $false
            try { Assert-SafeZipEntryName $unsafeName $zipDestination | Out-Null } catch { $rejected = $true }
            if (-not $rejected) { throw "Archive preflight accepted unsafe entry '$unsafeName'." }
        }
        New-SelfTestZipArchive $hostileZip @(
            @{ name = 'safe/partial.txt'; content = 'must never be written' },
            @{ name = '../self-test-zip-escape.txt'; content = 'escape' }
        )
        $hostileRejected = $false
        try { Expand-VerifiedArchive $hostileZip $zipDestination } catch { $hostileRejected = $true }
        if (-not $hostileRejected -or (Test-Path -LiteralPath $zipDestination) -or (Test-Path -LiteralPath $zipEscape)) {
            throw "Hostile archive caused an outside or partial write before full preflight rejection."
        }
        New-SelfTestZipArchive $duplicateZip @(
            @{ name = 'safe/Case.txt'; content = 'one' },
            @{ name = 'SAFE\case.TXT'; content = 'two' }
        )
        $duplicateRejected = $false
        try { Assert-ArchiveEntriesSafe $duplicateZip $zipDestination } catch { $duplicateRejected = $true }
        if (-not $duplicateRejected) { throw "Archive preflight accepted a case/separator-colliding duplicate." }
        $symlinkAttributes = -1610612736
        New-SelfTestZipArchive $symlinkZip @(
            @{ name = 'safe-link'; content = 'target'; external_attributes = $symlinkAttributes }
        )
        $symlinkRejected = $false
        try { Assert-ArchiveEntriesSafe $symlinkZip $zipDestination } catch { $symlinkRejected = $true }
        if (-not $symlinkRejected) { throw "Archive preflight accepted a symlink entry." }
        New-SelfTestZipArchive $safeZip @(
            @{ name = 'root/one.txt'; content = 'one' },
            @{ name = 'root/two.txt'; content = 'two' }
        )
        $savedForce = $Force
        $script:Force = $false
        try {
            Install-VerifiedArchive $safeZip $zipDestination
            if (-not (Test-InstalledArchiveMatches $safeZip $zipDestination)) {
                throw "Transactional archive install did not validate after promotion."
            }
            [System.IO.File]::WriteAllText((Join-Path $zipDestination 'root/one.txt'), 'tampered')
            if (Test-InstalledArchiveMatches $safeZip $zipDestination) {
                throw "Full archive provenance check accepted a replaced installed file."
            }
            Install-VerifiedArchive $safeZip $zipDestination
            if (-not (Test-InstalledArchiveMatches $safeZip $zipDestination) -or (Test-Path -LiteralPath "$zipDestination.staging")) {
                throw "Transactional archive repair failed or retained staging residue."
            }
        }
        finally {
            $script:Force = $savedForce
        }
    }
    finally {
        Remove-ToolDirectory $zipDestination
        foreach ($path in @($hostileZip, $duplicateZip, $symlinkZip, $safeZip, $zipEscape)) {
            if (Test-Path -LiteralPath $path) { Assert-UnderToolRoot $path; Remove-Item -LiteralPath $path -Force }
        }
    }

    $corrupt = Join-Path $downloadRoot "self-test-corrupt.cache"
    try {
        [System.IO.File]::WriteAllBytes($corrupt, [byte[]](1, 2, 3, 4))
        if (Remove-InvalidCachedArtifact $corrupt ("0" * 64)) {
            throw "Native bootstrap accepted an intentionally corrupt cached archive."
        }
        if (Test-Path -LiteralPath $corrupt) {
            throw "Native bootstrap did not delete the corrupt cached archive."
        }
    }
    finally {
        if (Test-Path -LiteralPath $corrupt) {
            Assert-UnderToolRoot $corrupt
            Remove-Item -LiteralPath $corrupt -Force
        }
    }

    $badCompilerRejected = $false
    try { Assert-ExactCompilerVersion @("clang version 22.1.80 (https://github.com/llvm/llvm-project.git ca7933e47d3a3451d81e72ac174dcb5aa28b59d1)", "Target: x86_64-w64-windows-gnu") "22.1.8" "ca7933e47d3a3451d81e72ac174dcb5aa28b59d1" "x86_64-w64-windows-gnu" } catch { $badCompilerRejected = $true }
    if (-not $badCompilerRejected) { throw "Native bootstrap accepted compiler version prefix drift." }
    $badEmccRejected = $false
    try { Assert-ExactEmccVersion "emcc (Emscripten gcc/clang-like replacement) 4.0.200 (6913738ec5371a88c4af5a80db0ab42bad3de681)" "4.0.20" "6913738ec5371a88c4af5a80db0ab42bad3de681" } catch { $badEmccRejected = $true }
    if (-not $badEmccRejected) { throw "Native bootstrap accepted Emscripten version prefix drift." }

    $cacheScratch = Join-Path $downloadRoot "self-test-offline.cache"
    try {
        [System.IO.File]::WriteAllText($cacheScratch, "offline cache proof")
        $cacheSha = (Get-FileHash -LiteralPath $cacheScratch -Algorithm SHA256).Hash.ToLowerInvariant()
        Get-VerifiedDownload "https://invalid.invalid/must-not-be-contacted.cache" $cacheScratch $cacheSha
    }
    finally {
        if (Test-Path -LiteralPath $cacheScratch) { Remove-Item -LiteralPath $cacheScratch -Force }
    }

    $repoSource = Join-Path $toolRoot "self-test-repo-source"
    $repoOrigin = Join-Path $toolRoot "self-test-repo-origin.git"
    $repoOffline = Join-Path $toolRoot "self-test-repo-origin.offline"
    $repoInstall = Join-Path $toolRoot "self-test-repository"
    foreach ($repoPath in @($repoSource, $repoOrigin, $repoOffline, $repoInstall)) { Remove-ToolDirectory $repoPath }
    try {
        New-Item -ItemType Directory -Path $repoSource | Out-Null
        Invoke-SafeGit @("init", "--quiet", "--template=", $repoSource) "Could not create self-test source repository" | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $repoSource "pinned.txt"), "pinned dependency")
        Invoke-SafeGit @("-C", $repoSource, "add", "--", "pinned.txt") "Could not stage self-test dependency" | Out-Null
        Invoke-SafeGit @("-c", "user.name=BTH Self Test", "-c", "user.email=self-test.invalid", "-C", $repoSource, "commit", "--quiet", "-m", "fixture") "Could not commit self-test dependency" | Out-Null
        $repoCommit = ([string](Invoke-SafeGit @("-C", $repoSource, "rev-parse", "HEAD") "Could not read self-test dependency commit" | Select-Object -First 1)).Trim()
        Invoke-SafeGit @("clone", "--quiet", "--bare", $repoSource, $repoOrigin) "Could not create self-test dependency origin" | Out-Null
        New-Item -ItemType Directory -Path $repoInstall | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $repoInstall "stale.partial"), "stale")
        $savedForce = $Force
        $script:Force = $false
        try { Sync-PinnedRepository $repoOrigin $repoCommit $repoInstall } finally { $script:Force = $savedForce }
        if (-not (Test-PinnedRepository $repoOrigin $repoCommit $repoInstall) -or (Test-Path -LiteralPath (Join-Path $repoInstall "stale.partial"))) {
            throw "Transactional repository recovery did not replace a stale partial root."
        }
        Move-Item -LiteralPath $repoOrigin -Destination $repoOffline
        $script:Force = $false
        try { Sync-PinnedRepository $repoOrigin $repoCommit $repoInstall } finally { $script:Force = $savedForce }
        $hostileConfigNames = @("GIT_CONFIG_COUNT", "GIT_CONFIG_KEY_0", "GIT_CONFIG_VALUE_0")
        $savedHostileConfig = @{}
        foreach ($name in $hostileConfigNames) {
            $savedHostileConfig[$name] = [System.Environment]::GetEnvironmentVariable($name, [System.EnvironmentVariableTarget]::Process)
        }
        $env:GIT_CONFIG_COUNT = "1"
        $env:GIT_CONFIG_KEY_0 = "core.hooksPath"
        $env:GIT_CONFIG_VALUE_0 = "HOSTILE-INHERITED-HOOKS"
        try {
            $isolatedHooks = ([string](Invoke-SafeGit @("-C", $repoInstall, "config", "--get", "core.hooksPath") "Could not verify Git config-count isolation" | Select-Object -First 1)).Trim()
            if ($isolatedHooks -cne "NUL") {
                throw "Inherited Git config-count injection overrode the safe hooks path: $isolatedHooks"
            }
            if ($env:GIT_CONFIG_COUNT -cne "1" -or $env:GIT_CONFIG_KEY_0 -cne "core.hooksPath" -or $env:GIT_CONFIG_VALUE_0 -cne "HOSTILE-INHERITED-HOOKS") {
                throw "Safe Git invocation did not restore the caller's config-count environment."
            }
        }
        finally {
            foreach ($name in $hostileConfigNames) {
                [System.Environment]::SetEnvironmentVariable($name, $savedHostileConfig[$name], [System.EnvironmentVariableTarget]::Process)
            }
        }
        [System.IO.File]::WriteAllText((Join-Path $repoInstall "hostile.cpp"), "#error stale dependency source")
        if (Test-PinnedRepository $repoOrigin $repoCommit $repoInstall) {
            throw "Pinned repository validation accepted an untracked build source."
        }
        Remove-Item -LiteralPath (Join-Path $repoInstall "hostile.cpp") -Force
        [System.IO.File]::AppendAllText((Join-Path $repoInstall ".git/config"), "[alias]`n`thostile = !echo hostile`n")
        if (Test-PinnedRepository $repoOrigin $repoCommit $repoInstall) {
            throw "Pinned repository validation accepted hostile local Git config."
        }
    }
    finally {
        foreach ($repoPath in @($repoSource, $repoOrigin, $repoOffline, $repoInstall)) { Remove-ToolDirectory $repoPath }
    }

    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $childOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -SelfTest 2>&1
        $childExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedErrorPreference
    }
    if ($childExitCode -eq 0 -or (($childOutput -join "`n") -notmatch 'Another native solver bootstrap is already running')) {
        throw "Native bootstrap mutex did not reject a concurrent process."
    }
    $global:LASTEXITCODE = 0
    $abandonedName = "Local\BeatTheHouse_NativeSolver_Abandoned_$PID"
    $abandonedObserver = [System.Threading.Mutex]::new($false, $abandonedName)
    $abandonSource = '$m=[System.Threading.Mutex]::new($false,"' + $abandonedName + '");$null=$m.WaitOne();[System.Environment]::Exit(0)'
    $abandonEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($abandonSource))
    $abandonProcess = Start-Process -FilePath powershell.exe -ArgumentList @("-NoProfile", "-EncodedCommand", $abandonEncoded) -WindowStyle Hidden -PassThru -Wait
    if ($abandonProcess.ExitCode -ne 0) {
        throw "Could not create abandoned-mutex recovery fixture."
    }
    $script:NativeBootstrapRecoveredAbandonedMutex = $false
    $recoveredMutex = Enter-NativeBootstrapMutex $abandonedName
    try {
        if (-not $script:NativeBootstrapRecoveredAbandonedMutex) {
            throw "Native bootstrap mutex helper did not exercise abandoned ownership recovery."
        }
    }
    finally {
        $recoveredMutex.ReleaseMutex()
        $recoveredMutex.Dispose()
        $abandonedObserver.Dispose()
    }
    Write-Host "Native bootstrap hostile lock/archive/version/repository/reparse checks passed." -ForegroundColor Green
}

$bootstrapMutex = Enter-NativeBootstrapMutex "Local\BeatTheHouse_NativeSolver_Bootstrap_v1"
try {
    Assert-NativeToolchainLock $lock
    if ($SelfTest) {
        Invoke-BootstrapSelfTest
        return
    }

    Assert-NoReparseComponents $toolRoot
    New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null
    Assert-UnderToolRoot $downloadRoot

    $pythonArchive = Join-Path $downloadRoot (Split-Path -Leaf $lock.python.archive_url)
    Get-VerifiedDownload $lock.python.archive_url $pythonArchive $lock.python.archive_sha256
    Install-VerifiedArchive $pythonArchive $pythonRoot
    Assert-ExactPythonVersion $pythonExe $lock.python.version

    $sconsWheel = Join-Path $downloadRoot "scons-$($lock.scons.version)-py3-none-any.whl"
    Get-VerifiedDownload $lock.scons.wheel_url $sconsWheel $lock.scons.wheel_sha256
    $sconsOutput = Invoke-NativeCommand { & $pythonExe -c "import sys; sys.path.insert(0, r'$sconsWheel'); import SCons; print(SCons.__version__)" } "Could not import pinned SCons"
    $sconsVersion = (($sconsOutput | Select-Object -First 1) -as [string]).Trim()
    if ($sconsVersion -cne [string]$lock.scons.version) {
        throw "SCons version drift: expected $($lock.scons.version), got $sconsVersion"
    }

    Sync-PinnedRepository $lock.godot_cpp.repository $lock.godot_cpp.commit $godotCppRoot
    Assert-GodotCppPayloads $lock.godot_cpp $godotCppRoot

    if ($Target -in @("Windows", "All")) {
        $archivePath = Join-Path $downloadRoot (Split-Path -Leaf $lock.windows.archive_url)
        Get-VerifiedDownload $lock.windows.archive_url $archivePath $lock.windows.archive_sha256
        Install-VerifiedArchive $archivePath $windowsRoot
        $windowsChildren = @(Get-ChildItem -LiteralPath $windowsRoot -Directory)
        if ($windowsChildren.Count -ne 1) {
            throw "Unexpected LLVM-MinGW archive root count: $($windowsChildren.Count)"
        }
        $windowsToolRoot = $windowsChildren[0].FullName
        Assert-UnderToolRoot $windowsToolRoot
        $compiler = Join-Path $windowsToolRoot "bin/clang++.exe"
        $compilerOutput = Invoke-NativeCommand { & $compiler --version } "Could not run pinned LLVM-MinGW compiler"
        Assert-ExactCompilerVersion $compilerOutput $lock.windows.compiler_version $lock.windows.compiler_commit $lock.windows.target
        $compilerOutput | Select-Object -First 2 | Write-Host
    }

    if ($Target -in @("Web", "All")) {
        Sync-PinnedRepository $lock.web.repository $lock.web.commit $emsdkRoot
        $emsdk = Join-Path $emsdkRoot "emsdk.bat"
        $emcc = Join-Path $emsdkRoot "upstream/emscripten/emcc.bat"
        $emccFirstLine = ""
        if (-not $Force -and (Test-Path -LiteralPath $emcc)) {
            try {
                $emccOutput = Invoke-NativeCommand { & $emcc --version } "Could not run cached Emscripten $($lock.web.version)"
                $emccFirstLine = (($emccOutput | Select-Object -First 1) -as [string]).Trim()
                Assert-ExactEmccVersion $emccFirstLine $lock.web.version $lock.web.compiler_commit
            }
            catch {
                $emccFirstLine = ""
            }
        }
        if ($emccFirstLine.Length -eq 0) {
            Invoke-NativeCommand { & $emsdk install $lock.web.version } "Could not install Emscripten $($lock.web.version)" | Write-Host
            Invoke-NativeCommand { & $emsdk activate $lock.web.version } "Could not activate Emscripten $($lock.web.version)" | Write-Host
            $emccOutput = Invoke-NativeCommand { & $emcc --version } "Could not run Emscripten $($lock.web.version)"
            $emccFirstLine = (($emccOutput | Select-Object -First 1) -as [string]).Trim()
            Assert-ExactEmccVersion $emccFirstLine $lock.web.version $lock.web.compiler_commit
        }
        Write-Host $emccFirstLine
    }

    Write-Host "Native Coin Pusher dependency toolchain ready at $toolRoot; runtime/export-template identity is verified by build/export preflight." -ForegroundColor Green
}
finally {
    $bootstrapMutex.ReleaseMutex()
    $bootstrapMutex.Dispose()
}
