param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$rulesPath = Join-Path $PSScriptRoot "health06_1_static_source_rules.ps1"
if (-not (Test-Path -LiteralPath $rulesPath)) {
    Write-Error "health06_1 static source rules helper is missing."
    exit 1
}
. $rulesPath

$fixtureRoot = Join-Path $root ".tmp/health06_1/phase11/static_rule_fixtures"
New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$hostile = @'
extends RefCounted

var _loaded := false
var total: int = 0
var orphan_count := 0
var sample_cache: Dictionary = {}


func from_dict(data: Dictionary) -> void:
	total = data.get("total", "bad")
	sample_cache[str(total)] = total


func save(primary_path: String, file: FileAccess) -> void:
	file.store_string("payload")
	DirAccess.remove_absolute(primary_path)


## Describes a different_function contract.
func actual_function() -> void:
	pass


func debug_snapshot() -> Dictionary:
	return {"orphan_count": orphan_count}


func parse(text: String) -> void:
	JSON.parse_string(text)
'@
$safe = @'
extends RefCounted

const CACHE_MAX_ENTRIES := 4
var total: int = 0
var sample_cache: Dictionary = {}


func from_dict(data: Dictionary) -> void:
	total = int(data.get("total", 0))


func save(file: FileAccess) -> void:
	file.store_string("payload")
	var write_error := file.get_error()
	if write_error != OK:
		return
'@
[IO.File]::WriteAllText((Join-Path $fixtureRoot "hostile.gd"), $hostile, $utf8)
[IO.File]::WriteAllText((Join-Path $fixtureRoot "safe.gd"), $safe, $utf8)

$hostileErrors = @(Invoke-Health06StaticSourceRules -Paths @((Join-Path $fixtureRoot "hostile.gd")))
$expectedRules = @("unchecked-store-string", "primary-remove-before-rename", "raw-typed-from-dict", "instance-loaded-json", "unbounded-cache", "orphan-doc-comment", "dead-debug-counter")
foreach ($rule in $expectedRules) {
    if (-not ($hostileErrors -match "\[$rule\]")) {
        Write-Error "Static source hostile fixture did not trigger $rule."
        exit 1
    }
}
$safeErrors = @(Invoke-Health06StaticSourceRules -Paths @((Join-Path $fixtureRoot "safe.gd")))
if ($safeErrors.Count -ne 0) {
    Write-Error "Static source safe fixture was rejected: $($safeErrors -join '; ')"
    exit 1
}

$validator = Get-Content -LiteralPath (Join-Path $PSScriptRoot "validate_project.ps1") -Raw
if (-not $validator.Contains("Invoke-Health06StaticSourceRules")) {
    Write-Error "validate_project.ps1 does not invoke the permanent health06_1 source rules."
    exit 1
}

if (-not $Quiet) { Write-Host "health06_1 static source rules contract passed." }
