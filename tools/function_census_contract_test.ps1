param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$censusPath = Join-Path $PSScriptRoot "function_census.ps1"
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($censusPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) {
    throw "BTH061-AUDIT-VALIDATOR-001: function census does not parse."
}

# Load the actual parser functions and their classification configuration
# without running the CLI's full census or writing its generated reports.
$definitions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
foreach ($statement in $ast.EndBlock.Statements) {
    $text = $statement.Extent.Text
    if ($text -match '^\$(productionRoots|classes|excludedCallNames)\s*=' -or $text.StartsWith('foreach ($name in @(')) {
        Invoke-Expression $text
    }
}
foreach ($definition in $definitions) {
    Invoke-Expression $definition.Extent.Text
}

if (@(Get-CallsFromBody -BodyLines @()).Count -ne 0 -or @(Get-CallsFromBody -BodyLines $null).Count -ne 0) {
    throw "BTH061-AUDIT-VALIDATOR-001: empty function bodies must have no calls."
}
$calls = @(Get-CallsFromBody -BodyLines @("zeta(); alpha()", "alpha(); max(1, 2)"))
if (($calls -join ",") -ne "alpha,zeta") {
    throw "BTH061-AUDIT-VALIDATOR-001: nonempty call extraction lost its sorted/deduplicated names or builtin exclusion."
}

$root = Join-Path (Split-Path -Parent $PSScriptRoot) ".tmp/function_census/contract_fixture"
$fixturePath = Join-Path $root "scripts/ui/body_spans.gd"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fixturePath) | Out-Null
# No trailing newline: the last valid inline function must have an empty slice.
$fixture = @(
    "extends RefCounted",
    "",
    "func _ready() -> void:",
    "`tfirst_helper()",
    "func first_helper() -> void:",
    "`tsecond_helper()",
    "static func adjacent_inline() -> void: pass",
    "func second_helper() -> void:",
    "`tdynamic_target()",
    "func eof_inline() -> void: pass"
)
[System.IO.File]::WriteAllText($fixturePath, ($fixture -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
$records = @(Get-FunctionRecordsForFile -File (Get-Item -LiteralPath $fixturePath))
if ($records.Count -ne 5 -or ($records.name -join ",") -ne "_ready,first_helper,adjacent_inline,second_helper,eof_inline") {
    throw "BTH061-AUDIT-VALIDATOR-001: adjacent/EOF inline bodies changed the function inventory."
}
$expectedSpans = @("3:4:2", "5:6:2", "7:7:1", "8:9:2", "10:10:1")
$expectedCalls = @("first_helper", "second_helper", "", "dynamic_target", "")
for ($index = 0; $index -lt $records.Count; $index++) {
    $record = $records[$index]
    $span = "{0}:{1}:{2}" -f $record.start_line, $record.end_line, $record.line_count
    if ($span -ne $expectedSpans[$index] -or ($record.calls -join ",") -ne $expectedCalls[$index]) {
        throw "BTH061-AUDIT-VALIDATOR-001: function body span/call attribution changed for $($record.name)."
    }
    if (-not $record.shipping -or $record.source_group -ne "ui") {
        throw "BTH061-AUDIT-VALIDATOR-001: fixture source classification changed."
    }
}
if (-not $records[2].static -or $records[2].kind -ne "static" -or $records[4].static) {
    throw "BTH061-AUDIT-VALIDATOR-001: inline declaration kind changed."
}
foreach ($index in @(0, 1, 3)) {
    if (($records[$index].classes -join ",") -ne "STARTUP") {
        throw "BTH061-AUDIT-VALIDATOR-001: startup reachability did not propagate through the actual helper bodies."
    }
}
foreach ($index in @(2, 4)) {
    if (($records[$index].classes -join ",") -ne "UNCLASSIFIED") {
        throw "BTH061-AUDIT-VALIDATOR-001: an empty slice borrowed the neighboring function's calls/classes."
    }
}
if (-not $Quiet) {
    Write-Host "Function census empty-body and attribution contract passed ($($PSVersionTable.PSVersion))."
}
