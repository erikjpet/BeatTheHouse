param(
    [string]$GodotPath = "",
    [Parameter(Mandatory = $true)]
    [string]$ExpectedDllSha256,
    [bool]$ExpectLiveBatch = $true,
    [string]$OutDir = ".tmp/coin_pusher_native_abi_contract"
)

$ErrorActionPreference = "Stop"
$ExpectedDllSha256 = $ExpectedDllSha256.ToUpperInvariant()
if ($ExpectedDllSha256 -notmatch '^[0-9A-F]{64}$') { throw "ExpectedDllSha256 must be exactly 64 hexadecimal characters." }
$root = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot console not found; pass -GodotPath or set GODOT_BIN."
}
$descriptor = Join-Path $root "addons/coin_pusher_native/coin_pusher_native.gdextension"
$descriptorHashBefore = (Get-FileHash -LiteralPath $descriptor -Algorithm SHA256).Hash
$descriptorText = Get-Content -LiteralPath $descriptor -Raw
$match = [regex]::Match($descriptorText, 'windows\.debug\.x86_64\s*=\s*"res://([^\"]+)"')
if (-not $match.Success) { throw "Native descriptor omitted windows.debug.x86_64." }
$relativeDll = $match.Groups[1].Value -replace '/', [IO.Path]::DirectorySeparatorChar
$dll = [IO.Path]::GetFullPath((Join-Path $root $relativeDll))
if ([IO.Path]::GetFileName($dll) -ne "coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll") {
    throw "Native descriptor selected an unaccepted alias/fallback: $dll"
}
if (-not (Test-Path -LiteralPath $dll -PathType Leaf)) { throw "Descriptor-selected native DLL is missing: $dll" }
$actualHash = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
if ($actualHash -ne $ExpectedDllSha256.ToUpperInvariant()) {
    throw "Descriptor-selected native DLL hash $actualHash did not match expected $ExpectedDllSha256."
}
$output = [IO.Path]::GetFullPath((Join-Path $root $OutDir))
if (Test-Path -LiteralPath $output) { throw "Refusing to overwrite native ABI evidence: $output" }
New-Item -ItemType Directory -Path $output | Out-Null
$stdout = Join-Path $output "stdout.txt"
$stderr = Join-Path $output "stderr.txt"
$expectArgument = if ($ExpectLiveBatch) { "--expect-live-batch=true" } else { "--expect-live-batch=false" }
$process = Start-Process -FilePath $GodotPath -ArgumentList @("--headless", "--path", $root, "--script", "res://tools/coin_pusher_native_abi_contract.gd", "--", $expectArgument) -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
$stdoutText = Get-Content -LiteralPath $stdout -Raw
if ($process.ExitCode -ne 0 -or $stdoutText -notmatch 'COIN_PUSHER_NATIVE_ABI_CONTRACT PASS') {
    throw "Descriptor-bound native ABI contract failed with exit $($process.ExitCode); retained output: $output"
}
$postDescriptorHash = (Get-FileHash -LiteralPath $descriptor -Algorithm SHA256).Hash
$postDllHash = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
if ($postDescriptorHash -ne $descriptorHashBefore) { throw "Native descriptor changed during the authenticated load." }
if ($postDllHash -ne $actualHash) { throw "Descriptor-selected native DLL changed during the authenticated load." }
[ordered]@{
    schema = "coin_pusher_native_abi_contract_v1"
    passed = $true
    source_head = (& git -C $root rev-parse HEAD).Trim()
    descriptor = $descriptor
    descriptor_sha256 = $descriptorHashBefore
    descriptor_sha256_after = $postDescriptorHash
    dll = $dll
    dll_sha256 = $actualHash
    dll_sha256_after = $postDllHash
    expect_live_batch = $ExpectLiveBatch
    stdout_sha256 = (Get-FileHash -LiteralPath $stdout -Algorithm SHA256).Hash
    stderr_sha256 = (Get-FileHash -LiteralPath $stderr -Algorithm SHA256).Hash
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output "manifest.json") -Encoding UTF8
Write-Host "COIN_PUSHER_NATIVE_ABI_CONTRACT_WRAPPER PASS dll_sha256=$actualHash"
