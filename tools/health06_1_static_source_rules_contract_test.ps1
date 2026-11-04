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

$styleSafe = @'
extends RefCounted
const ExampleScript := preload("res://example.gd")
const ExampleScene := preload("res://example.tscn")
# A delimiter in a comment is not a string: """
const Ordinary := '""" # ordinary string'
const Escaped := "\"\"\""
const JavaScript := """(function(base64) {
    const source = atob(base64);
const FakeAlias := preload("res://not_gdscript.gd")
    return source; // escaped delimiter: \"""
})"""
const Multiline := '''
    This indentation is string content.
const FakeSceneAlias := preload("res://not_gdscript.tscn")
    '''
func valid() -> void:
	pass
'@
$styleSafe = $styleSafe.Replace("`r`n", "`n").Replace("`r", "`n")
foreach ($styleSource in @($styleSafe, $styleSafe.Replace("`n", "`r`n"))) {
    $styleErrors = @(Get-GdScriptStyleSourceIssues -Source $styleSource -PathLabel 'style_safe.gd')
    $styleScan = Get-GdScriptStyleScanText $styleSource
    if ($styleErrors.Count -ne 0 -or $styleScan.Length -ne $styleSource.Length -or
        ([regex]::Matches($styleScan, '\r|\n')).Count -ne ([regex]::Matches($styleSource, '\r|\n')).Count) {
        throw "GDScript style scan rejected multiline content or changed source coordinates: $($styleErrors -join '; ')"
    }
}

$styleHostileCases = @(
    @{ Source = "func actual() -> void:`n    pass"; Expected = 'GDScript indentation must use tabs: style_hostile.gd:2' },
    @{ Source = '    const Text := """payload"""'; Expected = 'GDScript indentation must use tabs: style_hostile.gd:1' },
    @{ Source = "    # Actual space-indented GDScript comment"; Expected = 'GDScript indentation must use tabs: style_hostile.gd:1' },
    @{ Source = "# ignored delimiter: `"`"`"`nconst Wrong := preload(`"res://example.gd`")"; Expected = 'Preload constant must end in Script: style_hostile.gd:2 (Wrong)' },
    @{ Source = ('const Text := ''"""''' + "`nconst Wrong := preload(`"res://example.tscn`")"); Expected = 'Preload constant must end in Scene: style_hostile.gd:2 (Wrong)' },
    @{ Source = ($styleSafe + "`nconst Wrong := preload(`"res://example.gd`")"); Expected = 'Preload constant must end in Script: style_hostile.gd:18 (Wrong)' },
    @{ Source = ($styleSafe + "`n    pass"); Expected = 'GDScript indentation must use tabs: style_hostile.gd:18' }
)
foreach ($styleCase in $styleHostileCases) {
    $styleErrors = @(Get-GdScriptStyleSourceIssues -Source $styleCase.Source -PathLabel 'style_hostile.gd')
    if ($styleErrors.Count -ne 1 -or $styleErrors[0] -cne $styleCase.Expected) {
        throw "GDScript style hostile fixture escaped its exact rule/location: expected '$($styleCase.Expected)', got '$($styleErrors -join '; ')'."
    }
}
$codecStyleErrors = @(Get-GdScriptStyleSourceIssues -Source (Get-Content -LiteralPath (Join-Path $root 'scripts/core/run_save_codec.gd') -Raw) -PathLabel 'scripts/core/run_save_codec.gd')
if ($codecStyleErrors.Count -ne 0) {
    throw "Embedded JavaScript in the save codec caused GDScript style errors: $($codecStyleErrors -join '; ')"
}

$validator = Get-Content -LiteralPath (Join-Path $PSScriptRoot "validate_project.ps1") -Raw
if (-not $validator.Contains("Invoke-Health06StaticSourceRules") -or -not $validator.Contains("Get-GdScriptStyleSourceIssues -Source")) {
    Write-Error "validate_project.ps1 does not invoke the permanent health06_1 source rules."
    exit 1
}

if (-not $Quiet) { Write-Host "health06_1 static source rules contract passed." }
