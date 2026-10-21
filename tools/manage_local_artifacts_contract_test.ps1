$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$temporaryParent = [IO.Path]::GetFullPath((Join-Path $repoRoot ".tmp"))
$fixtureName = "manage_local_artifacts_contract_" + [guid]::NewGuid().ToString("N")
$fixtureRoot = Join-Path $temporaryParent $fixtureName
$toolSource = Join-Path $PSScriptRoot "manage_local_artifacts.ps1"
$shellPath = (Get-Process -Id $PID).Path

function Assert-ArtifactContract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-FixtureHash([string]$Path) {
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hash.ComputeHash([IO.File]::ReadAllBytes($Path))).Replace("-", "").ToLowerInvariant()
    }
    finally { $hash.Dispose() }
}

function New-ArtifactFixture([string]$Name) {
    $parent = Join-Path $fixtureRoot $Name
    $repository = Join-Path $parent "repo"
    New-Item -ItemType Directory -Path (Join-Path $repository "tools") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repository ".tmp") -Force | Out-Null
    $scriptPath = Join-Path $repository "tools/manage_local_artifacts.ps1"
    Copy-Item -LiteralPath $toolSource -Destination $scriptPath
    [IO.File]::WriteAllText((Join-Path $repository ".gitignore"), ".tmp/`n")
    $sourcePath = Join-Path $repository ".tmp/owned.txt"
    [IO.File]::WriteAllText($sourcePath, "owned disposable fixture`n")
    & git -C $repository init -q
    if ($LASTEXITCODE -ne 0) { throw "Could not initialize the owned fixture repository." }
    Assert-ArtifactContract ((Get-FixtureHash $scriptPath) -eq (Get-FixtureHash $toolSource)) "Fixture script differs from the actual tool."
    return [pscustomobject]@{ Parent = $parent; Repo = $repository; Tool = $scriptPath; Source = $sourcePath; Hash = Get-FixtureHash $sourcePath }
}

function Write-FixtureManifest($Fixture, [string]$Destination) {
    $manifest = [ordered]@{
        schema_version = 1
        repository_root = $Fixture.Repo
        destination_root = $Destination
        files = @([ordered]@{ path = ".tmp/owned.txt"; size = (Get-Item -LiteralPath $Fixture.Source).Length; sha256 = $Fixture.Hash })
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $Destination "artifact_manifest.json") -Encoding utf8
}

function Invoke-FixtureTool($Fixture, [string[]]$ToolArguments) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & $shellPath -NoProfile -NonInteractive -File $Fixture.Tool @ToolArguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = ($output | Out-String) }
}

try {
    $equal = New-ArtifactFixture "equal"
    Write-FixtureManifest $equal $equal.Repo
    $result = Invoke-FixtureTool $equal @("-Clean", "-Destination", $equal.Repo, "-IAmSure")
    Assert-ArtifactContract ($result.ExitCode -ne 0 -and $result.Output.Contains("export destination cannot contain the repository")) "Clean accepted the source repository as its own export: $($result.Output)"
    Assert-ArtifactContract (Test-Path -LiteralPath $equal.Source) "Equal-root rejection removed the only source copy."

    $ancestor = New-ArtifactFixture "ancestor"
    Write-FixtureManifest $ancestor $ancestor.Parent
    $result = Invoke-FixtureTool $ancestor @("-Clean", "-Destination", $ancestor.Parent, "-IAmSure")
    Assert-ArtifactContract ($result.ExitCode -ne 0 -and $result.Output.Contains("export destination cannot contain the repository")) "Clean accepted an ancestor as its export: $($result.Output)"
    Assert-ArtifactContract (Test-Path -LiteralPath $ancestor.Source) "Ancestor rejection removed source data."

    foreach ($kind in @("sibling", "nested")) {
        $fixture = New-ArtifactFixture $kind
        $destination = if ($kind -eq "sibling") { Join-Path $fixture.Parent "archive" } else { Join-Path $fixture.Repo ".tmp/archive" }
        $result = Invoke-FixtureTool $fixture @("-Export", $destination, "-IncludePath", ".tmp/owned.txt")
        Assert-ArtifactContract ($result.ExitCode -eq 0) "Legitimate $kind export failed: $($result.Output)"
        $copy = Join-Path $destination ".tmp/owned.txt"
        Assert-ArtifactContract ((Test-Path -LiteralPath $fixture.Source) -and (Get-FixtureHash $copy) -eq $fixture.Hash) "Export did not retain source and verified copy."
        if ($kind -eq "sibling") {
            $result = Invoke-FixtureTool $fixture @("-Clean", "-Destination", $destination)
            Assert-ArtifactContract ($result.ExitCode -ne 0 -and (Test-Path -LiteralPath $fixture.Source)) "Clean bypassed the existing explicit-confirmation guard."
        }
        $result = Invoke-FixtureTool $fixture @("-Clean", "-Destination", $destination, "-IAmSure")
        Assert-ArtifactContract ($result.ExitCode -eq 0 -and -not (Test-Path -LiteralPath $fixture.Source)) "Verified $kind cleanup failed: $($result.Output)"
        Assert-ArtifactContract ((Test-Path -LiteralPath $copy) -and (Get-FixtureHash $copy) -eq $fixture.Hash) "Cleanup changed the verified export copy."
    }
    Write-Host "MANAGE_LOCAL_ARTIFACTS_CONTRACT PASS cases=4 child_invocations=7"
}
finally {
    $resolved = [IO.Path]::GetFullPath($fixtureRoot)
    $expected = [IO.Path]::GetFullPath((Join-Path $temporaryParent $fixtureName))
    $prefix = $temporaryParent.TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
    if ($resolved -ne $expected -or -not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or $fixtureName -notmatch '^manage_local_artifacts_contract_[0-9a-f]{32}$') {
        throw "Refusing fixture cleanup outside the exact owned temporary root: $resolved"
    }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
