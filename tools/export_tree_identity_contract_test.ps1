$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "export_tree_identity.ps1")
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot ".tmp/export_tree_identity_contract"))
$temp = Join-Path $allowedRoot ([guid]::NewGuid().ToString("N"))
$failures = [Collections.Generic.List[string]]::new()
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { $script:failures.Add($Message) } }

try {
    $webRoot = Join-Path $temp "builds/web"
    New-Item -ItemType Directory -Path (Join-Path $webRoot "nested") -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $webRoot "index.html"), [Text.Encoding]::UTF8.GetBytes("<html>identity</html>"))
    [IO.File]::WriteAllBytes((Join-Path $webRoot "nested/runtime.wasm"), [byte[]](0, 1, 2, 253, 254, 255))

    $webImplementation = Get-ExportTreeIdentityFromDirectory -Directory $webRoot
    $ownerRows = @(Get-ChildItem -LiteralPath $webRoot -File -Recurse | ForEach-Object {
        [ordered]@{
            path = "builds/web/" + $_.FullName.Substring($webRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
            bytes = [int64]$_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
    $ownerImplementation = Get-ExportTreeIdentityFromRows -Rows $ownerRows -PathPrefix "builds/web"
    Assert-True ([string]$webImplementation.aggregate_sha256 -ceq [string]$ownerImplementation.aggregate_sha256) "Directory/Web and row/owner implementations produced different aggregate identities."
    Assert-True (($webImplementation.files | Where-Object { [string]$_.sha256 -cnotmatch '^[0-9a-f]{64}$' }).Count -eq 0) "Web identity did not canonicalize per-file hashes to lowercase."
    Assert-True (($ownerImplementation.files | Where-Object { [string]$_.sha256 -cnotmatch '^[0-9a-f]{64}$' }).Count -eq 0) "Owner identity did not canonicalize per-file hashes to lowercase."
    Assert-True ([string]$webImplementation.aggregate_sha256 -cmatch '^[0-9a-f]{64}$') "Aggregate identity was not lowercase SHA-256."
    if ($failures.Count -gt 0) {
        Write-Host "export tree identity contract: FAIL ($($failures.Count))" -ForegroundColor Red
        foreach ($failure in $failures) { Write-Host " - $failure" }
        exit 1
    }
    Write-Host "export tree identity contract: PASS owner_rows=web_directory lowercase=files+aggregate"
}
finally {
    if (Test-Path -LiteralPath $temp) {
        $resolved = [IO.Path]::GetFullPath($temp)
        if (-not $resolved.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to remove export identity output outside its dedicated root." }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
