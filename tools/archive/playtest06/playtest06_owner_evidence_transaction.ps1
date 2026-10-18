function Invoke-Playtest06OwnerEvidenceTransaction {
    param(
        [Parameter(Mandatory = $true)][string]$TempBase,
        [Parameter(Mandatory = $true)][string[]]$TargetPaths,
        [Parameter(Mandatory = $true)][scriptblock]$Produce,
        [Parameter(Mandatory = $true)][scriptblock]$Validate
    )
    $base = [IO.Path]::GetFullPath($TempBase).TrimEnd([char[]]@('\', '/'))
    $targets = @($TargetPaths | ForEach-Object { [IO.Path]::GetFullPath($_) })
    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) { throw "Owner build evidence is immutable; refusing to overwrite $target." }
    }
    $invocationRoot = Join-Path $base ([guid]::NewGuid().ToString("N"))
    $stagingRoot = Join-Path $invocationRoot "evidence"
    $createdTargets = [Collections.Generic.List[string]]::new()
    try {
        New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
        $payload = & $Produce $stagingRoot
        & $Validate $payload
        $mappings = @($payload.mappings)
        if ($mappings.Count -ne $targets.Count) { throw "Evidence transaction did not stage exactly $($targets.Count) retained files." }
        $mappedTargets = @{}
        foreach ($mapping in $mappings) {
            $source = [IO.Path]::GetFullPath([string]$mapping.source)
            $target = [IO.Path]::GetFullPath([string]$mapping.target)
            if (-not $source.StartsWith($stagingRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Evidence transaction source escaped its invocation staging directory." }
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Staged owner evidence is missing: $source" }
            if ($targets -cnotcontains $target) { throw "Evidence transaction declared an unexpected target: $target" }
            if ($mappedTargets.ContainsKey($target)) { throw "Evidence transaction declared duplicate target: $target" }
            $mappedTargets[$target] = $true
        }
        foreach ($target in $targets) {
            if (-not $mappedTargets.ContainsKey($target)) { throw "Evidence transaction omitted target: $target" }
        }
        foreach ($mapping in $mappings) {
            $source = [IO.Path]::GetFullPath([string]$mapping.source)
            $target = [IO.Path]::GetFullPath([string]$mapping.target)
            if (Test-Path -LiteralPath $target) { throw "Owner build evidence appeared during publication; refusing to overwrite $target." }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Move-Item -LiteralPath $source -Destination $target -ErrorAction Stop
            $createdTargets.Add($target)
        }
        return $payload
    }
    catch {
        foreach ($created in $createdTargets) {
            if (Test-Path -LiteralPath $created -PathType Leaf) { Remove-Item -LiteralPath $created -Force -ErrorAction SilentlyContinue }
        }
        throw
    }
    finally {
        if (Test-Path -LiteralPath $invocationRoot) {
            $resolved = [IO.Path]::GetFullPath($invocationRoot)
            if (-not $resolved.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove evidence staging outside its invocation-owned root." }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
