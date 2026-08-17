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
$windowsRoot = Join-Path $toolRoot "llvm-mingw"
$emsdkRoot = Join-Path $toolRoot "emsdk"

function Assert-NativeToolchainLock {
    param([object]$Value)
    if ([string]$Value.schema -ne "bth_native_toolchain_lock" -or [int]$Value.version -ne 1) {
        throw "Native toolchain lock schema/version is invalid."
    }
    foreach ($commit in @(
        [string]$Value.godot.commit,
        [string]$Value.godot_cpp.commit,
        [string]$Value.windows.compiler_commit,
        [string]$Value.web.commit
    )) {
        if ($commit -notmatch '^[0-9a-f]{40}$') {
            throw "Native toolchain commit is not a pinned lowercase SHA-1: $commit"
        }
    }
    foreach ($sha in @(
        [string]$Value.python.archive_sha256,
        [string]$Value.scons.wheel_sha256,
        [string]$Value.windows.archive_sha256
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
        godot_cpp_tag = "godot-4.5-stable"
        godot_cpp_api = "4.5"
        python_version = "3.12.10"
        python_architecture = "amd64"
        scons_version = "4.10.1"
        windows_toolchain = "llvm-mingw"
        windows_version = "20260616"
        windows_compiler = "22.1.8"
        windows_compiler_commit = "ca7933e47d3a3451d81e72ac174dcb5aa28b59d1"
        windows_runtime = "ucrt"
        windows_architecture = "x86_64"
        windows_target = "x86_64-w64-windows-gnu"
        web_toolchain = "emsdk"
        web_version = "4.0.20"
        web_template = "web_dlink_nothreads_release.zip"
    }
    $actual = @{
        godot_version = [string]$Value.godot.version
        godot_commit = [string]$Value.godot.commit
        godot_cpp_tag = [string]$Value.godot_cpp.tag
        godot_cpp_api = [string]$Value.godot_cpp.api_version
        python_version = [string]$Value.python.version
        python_architecture = [string]$Value.python.architecture
        scons_version = [string]$Value.scons.version
        windows_toolchain = [string]$Value.windows.toolchain
        windows_version = [string]$Value.windows.version
        windows_compiler = [string]$Value.windows.compiler_version
        windows_compiler_commit = [string]$Value.windows.compiler_commit
        windows_runtime = [string]$Value.windows.runtime
        windows_architecture = [string]$Value.windows.architecture
        windows_target = [string]$Value.windows.target
        web_toolchain = [string]$Value.web.toolchain
        web_version = [string]$Value.web.version
        web_template = [string]$Value.web.template
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
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
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
    param([string]$FirstLine, [string]$Expected)
    if ($FirstLine -notmatch '\) ([0-9]+\.[0-9]+\.[0-9]+)$' -or $Matches[1] -cne $Expected) {
        throw "Emscripten version drift: $FirstLine"
    }
}

function Sync-PinnedRepository {
    param([string]$Repository, [string]$Commit, [string]$Path)
    Assert-UnderToolRoot $Path
    if ($Force) {
        Remove-ToolDirectory $Path
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Path ".git"))) {
        $cloneOutput = Invoke-NativeCommand { & git clone --filter=blob:none --no-checkout $Repository $Path } "Could not clone $Repository"
        $cloneOutput | Write-Host
    }
    Assert-UnderToolRoot $Path
    $remote = [string](Invoke-NativeCommand { & git -C $Path remote get-url origin } "Could not inspect repository origin" | Select-Object -First 1)
    $remote = $remote.Trim()
    if ($remote -cne $Repository) {
        throw "Pinned repository origin drift in $Path`: expected $Repository, got $remote"
    }
    $cleanOutput = Invoke-NativeCommand { & git -C $Path clean -ffdx } "Could not clean untracked dependency files"
    $cleanOutput | Write-Host
    $fetchOutput = Invoke-NativeCommand { & git -C $Path fetch --depth 1 origin $Commit } "Could not fetch pinned commit $Commit from $Repository"
    $fetchOutput | Write-Host
    $checkoutOutput = Invoke-NativeCommand { & git -C $Path checkout --detach --force $Commit } "Could not check out pinned commit $Commit in $Path"
    $checkoutOutput | Write-Host
    $cleanAgainOutput = Invoke-NativeCommand { & git -C $Path clean -ffdx } "Could not finalize clean dependency checkout"
    $cleanAgainOutput | Write-Host
    $actual = [string](Invoke-NativeCommand { & git -C $Path rev-parse HEAD } "Could not inspect dependency commit" | Select-Object -First 1)
    $actual = $actual.Trim()
    if ($actual -cne $Commit) {
        throw "Pinned repository drift in $Path`: expected $Commit, got $actual"
    }
    $dirty = (Invoke-NativeCommand { & git -C $Path status --porcelain=v1 --untracked-files=all } "Could not inspect dependency cleanliness") -join "`n"
    if ($dirty.Length -ne 0) {
        throw "Pinned repository contains build-affecting local files in $Path`: $dirty"
    }
}

function Invoke-BootstrapSelfTest {
    $validCopy = (ConvertFrom-Json (ConvertTo-Json $lock -Depth 10))
    Assert-NativeToolchainLock $validCopy
    $mutations = @(
        @{ path = @("godot_cpp", "commit"); value = "../moving-target" },
        @{ path = @("godot", "commit"); value = "89cea1439" },
        @{ path = @("godot", "version"); value = "4.6.1-stable" },
        @{ path = @("godot_cpp", "api_version"); value = "4.6" },
        @{ path = @("python", "version"); value = "3.12.11" },
        @{ path = @("windows", "archive_sha256"); value = "not-a-sha256" },
        @{ path = @("windows", "runtime"); value = "msvcrt" },
        @{ path = @("windows", "architecture"); value = "arm64" },
        @{ path = @("windows", "archive_url"); value = "http://example.com/compiler.zip" },
        @{ path = @("windows", "archive_url"); value = "https://github.com/example/%2e%2e" },
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
    try { Assert-ExactEmccVersion "emcc (Emscripten gcc/clang-like replacement) 4.0.200" "4.0.20" } catch { $badEmccRejected = $true }
    if (-not $badEmccRejected) { throw "Native bootstrap accepted Emscripten version prefix drift." }

    $repoScratch = Join-Path $toolRoot "self-test-repository"
    Remove-ToolDirectory $repoScratch
    New-Item -ItemType Directory -Path $repoScratch | Out-Null
    try {
        Invoke-NativeCommand { & git -C $repoScratch init --quiet } "Could not create self-test repository" | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $repoScratch "hostile.cpp"), "#error stale dependency source")
        Invoke-NativeCommand { & git -C $repoScratch clean -ffdx } "Could not clean self-test repository" | Out-Null
        if (Test-Path -LiteralPath (Join-Path $repoScratch "hostile.cpp")) {
            throw "Native bootstrap retained a hostile untracked dependency source."
        }
    }
    finally {
        Remove-ToolDirectory $repoScratch
    }
    Write-Host "Native bootstrap hostile lock/archive/version/repository/reparse checks passed." -ForegroundColor Green
}

$bootstrapMutex = [System.Threading.Mutex]::new($false, "Local\BeatTheHouse_NativeSolver_Bootstrap_v1")
if (-not $bootstrapMutex.WaitOne(0)) {
    $bootstrapMutex.Dispose()
    throw "Another native solver bootstrap is already running."
}
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
    Remove-ToolDirectory $pythonRoot
    New-Item -ItemType Directory -Path $pythonRoot | Out-Null
    Expand-Archive -LiteralPath $pythonArchive -DestinationPath $pythonRoot -Force
    Assert-ExactPythonVersion $pythonExe $lock.python.version

    $sconsWheel = Join-Path $downloadRoot "scons-$($lock.scons.version)-py3-none-any.whl"
    Get-VerifiedDownload $lock.scons.wheel_url $sconsWheel $lock.scons.wheel_sha256
    $sconsOutput = Invoke-NativeCommand { & $pythonExe -c "import sys; sys.path.insert(0, r'$sconsWheel'); import SCons; print(SCons.__version__)" } "Could not import pinned SCons"
    $sconsVersion = (($sconsOutput | Select-Object -First 1) -as [string]).Trim()
    if ($sconsVersion -cne [string]$lock.scons.version) {
        throw "SCons version drift: expected $($lock.scons.version), got $sconsVersion"
    }

    Sync-PinnedRepository $lock.godot_cpp.repository $lock.godot_cpp.commit $godotCppRoot

    if ($Target -in @("Windows", "All")) {
        $archivePath = Join-Path $downloadRoot (Split-Path -Leaf $lock.windows.archive_url)
        Get-VerifiedDownload $lock.windows.archive_url $archivePath $lock.windows.archive_sha256
        Remove-ToolDirectory $windowsRoot
        $extractRoot = Join-Path $toolRoot "llvm-mingw-extract"
        Remove-ToolDirectory $extractRoot
        New-Item -ItemType Directory -Path $extractRoot | Out-Null
        try {
            Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
            Assert-UnderToolRoot $extractRoot
            $inner = Get-ChildItem -LiteralPath $extractRoot -Directory | Select-Object -First 1
            if ($null -eq $inner -or -not (Test-Path -LiteralPath (Join-Path $inner.FullName "bin/clang++.exe"))) {
                throw "Unexpected LLVM-MinGW archive layout."
            }
            Assert-UnderToolRoot $inner.FullName
            Move-Item -LiteralPath $inner.FullName -Destination $windowsRoot
        }
        finally {
            Remove-ToolDirectory $extractRoot
        }
        $compiler = Join-Path $windowsRoot "bin/clang++.exe"
        $compilerOutput = Invoke-NativeCommand { & $compiler --version } "Could not run pinned LLVM-MinGW compiler"
        Assert-ExactCompilerVersion $compilerOutput $lock.windows.compiler_version $lock.windows.compiler_commit $lock.windows.target
        $compilerOutput | Select-Object -First 2 | Write-Host
    }

    if ($Target -in @("Web", "All")) {
        Sync-PinnedRepository $lock.web.repository $lock.web.commit $emsdkRoot
        $emsdk = Join-Path $emsdkRoot "emsdk.bat"
        Invoke-NativeCommand { & $emsdk install $lock.web.version } "Could not install Emscripten $($lock.web.version)" | Write-Host
        Invoke-NativeCommand { & $emsdk activate $lock.web.version } "Could not activate Emscripten $($lock.web.version)" | Write-Host
        $emcc = Join-Path $emsdkRoot "upstream/emscripten/emcc.bat"
        $emccOutput = Invoke-NativeCommand { & $emcc --version } "Could not run Emscripten $($lock.web.version)"
        $emccFirstLine = (($emccOutput | Select-Object -First 1) -as [string]).Trim()
        Assert-ExactEmccVersion $emccFirstLine $lock.web.version
        Write-Host $emccFirstLine
    }

    Write-Host "Native Coin Pusher toolchain ready at $toolRoot" -ForegroundColor Green
}
finally {
    $bootstrapMutex.ReleaseMutex()
    $bootstrapMutex.Dispose()
}
