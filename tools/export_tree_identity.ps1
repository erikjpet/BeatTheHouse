function Get-ExportTreeIdentityFromRows {
    param($Rows, [string]$PathPrefix = "")
    $normalized = @()
    foreach ($row in @($Rows)) {
        $path = ([string]$row.path).Replace('\', '/')
        if ($PathPrefix) {
            $prefix = $PathPrefix.Replace('\', '/').TrimEnd('/') + "/"
            if (-not $path.StartsWith($prefix, [StringComparison]::Ordinal)) { throw "Export identity row '$path' is outside '$prefix'." }
            $path = $path.Substring($prefix.Length)
        }
        if ([string]::IsNullOrWhiteSpace($path) -or $path.StartsWith("/") -or $path.Contains("../")) { throw "Export identity row has an invalid relative path: '$path'." }
        $sha256 = ([string]$row.sha256).ToLowerInvariant()
        if ($sha256 -cnotmatch '^[0-9a-f]{64}$') { throw "Export identity row '$path' has an invalid SHA-256." }
        $normalized += [ordered]@{ path = $path; bytes = [int64]$row.bytes; sha256 = $sha256 }
    }
    $normalized = @($normalized | Sort-Object { [string]$_.path })
    $canonical = @($normalized | ForEach-Object { "{0}`t{1}`t{2}" -f [string]$_.path, [int64]$_.bytes, [string]$_.sha256 }) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $aggregate = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical)))).Replace("-", "").ToLowerInvariant() }
    finally { $sha.Dispose() }
    return [ordered]@{ aggregate_sha256 = $aggregate; file_count = $normalized.Count; files = $normalized }
}

function Get-ExportTreeIdentityFromDirectory {
    param([string]$Directory)
    $root = [IO.Path]::GetFullPath($Directory).TrimEnd([char[]]@('\', '/'))
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Export identity directory is missing: $root" }
    $rows = @(Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
            bytes = [int64]$_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
    return Get-ExportTreeIdentityFromRows -Rows $rows
}
