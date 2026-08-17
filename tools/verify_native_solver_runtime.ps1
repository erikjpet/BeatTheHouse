param(
    [string]$GodotPath = "",
    [switch]$RequireWebTemplate
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -LiteralPath (Join-Path $root "native/coin_pusher/toolchain.lock.json") -Raw | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = [string]$env:BTH_GODOT_PATH
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $commonGit = (& git -C $root rev-parse --path-format=absolute --git-common-dir).Trim()
    if ($LASTEXITCODE -eq 0) {
        $commonRoot = Split-Path -Parent $commonGit
        $candidate = Join-Path $commonRoot ".tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe"
        if (Test-Path -LiteralPath $candidate) {
            $GodotPath = $candidate
        }
    }
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot runtime is missing. Pass -GodotPath or set BTH_GODOT_PATH."
}
$godotVersion = (& $GodotPath --version).Trim()
if ($LASTEXITCODE -ne 0) {
    throw "Could not execute the locked Godot runtime."
}
$expectedGodotVersion = ([string]$lock.godot.version).Replace('-', '.').Replace('4.6.stable', '4.6.stable.official') + "." + ([string]$lock.godot.commit).Substring(0, 9)
if ($godotVersion -cne $expectedGodotVersion) {
    throw "Godot runtime identity drift: expected $expectedGodotVersion, got $godotVersion"
}

if ($RequireWebTemplate) {
    $templatePath = Join-Path $env:APPDATA "Godot/export_templates/$(([string]$lock.godot.version).Replace('-', '.'))/$([string]$lock.web.template)"
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Locked Godot Web GDExtension export template is missing: $templatePath"
    }
    $templateSha = (Get-FileHash -LiteralPath $templatePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($templateSha -cne [string]$lock.web.template_sha256) {
        throw "Godot Web GDExtension export-template hash drift: expected $($lock.web.template_sha256), got $templateSha"
    }
    Write-Host "Godot runtime and locked Web GDExtension export template verified." -ForegroundColor Green
}
else {
    Write-Host "Godot runtime identity verified." -ForegroundColor Green
}
