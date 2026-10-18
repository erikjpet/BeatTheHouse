$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $root "scripts/core/run_state_schema.gd"
$runStatePath = Join-Path $root "scripts/core/run_state.gd"
$settingsPath = Join-Path $root "scripts/core/user_settings.gd"
$profilePath = Join-Path $root "scripts/core/profile_inventory.gd"
$metaPath = Join-Path $root "scripts/core/meta_collection_service.gd"
$failures = [System.Collections.Generic.List[string]]::new()

function Expect-Contract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { $script:failures.Add($Message) }
}

Expect-Contract (Test-Path -LiteralPath $schemaPath) "CH-28: RunStateSchema is missing."
$schema = if (Test-Path -LiteralPath $schemaPath) { Get-Content -LiteralPath $schemaPath -Raw } else { "" }
$runState = Get-Content -LiteralPath $runStatePath -Raw
$settings = Get-Content -LiteralPath $settingsPath -Raw
$profile = Get-Content -LiteralPath $profilePath -Raw
$meta = Get-Content -LiteralPath $metaPath -Raw

Expect-Contract ($schema.Contains("const FIELDS")) "CH-28: the RunState field table is not declarative."
Expect-Contract ($schema.Contains("static func serialize(")) "CH-28: RunStateSchema does not own serialization."
Expect-Contract ($schema.Contains("static func restore(")) "CH-28: RunStateSchema does not drive restoration."
Expect-Contract ($runState.Contains("RunStateSchemaScript.serialize(self)")) "CH-28: RunState.to_dict is not schema-driven."
Expect-Contract ($runState.Contains("RunStateSchemaScript.restore(self, data)")) "CH-28: RunState.from_dict is not schema-driven."
Expect-Contract ($settings.Contains("const STORAGE_KEYS")) "CH-28: UserSettings has no declared storage-key set."
Expect-Contract ($profile.Contains("const PROFILE_STORAGE_KEYS")) "CH-28: ProfileInventory has no declared storage-key set."
Expect-Contract ($meta.Contains("const STORE_STORAGE_KEYS")) "CH-28: meta collection store has no declared storage-key set."

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "health06_1 serialization source contract passed."
