param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $PSScriptRoot "validate_project.ps1"
$tokens = $null
$parseErrors = $null
$validatorAst = [Management.Automation.Language.Parser]::ParseFile($validatorPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw "Validator PowerShell syntax is invalid." }

# Exercise the exact production functions without launching the full validator.
foreach ($functionName in @("Test-JsonObjectRoot", "ConvertFrom-ProjectJsonDocument")) {
    $definitions = @($validatorAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $functionName
    }, $true))
    if ($definitions.Count -ne 1) { throw "Expected one validator function $functionName." }
    Invoke-Expression $definitions[0].Extent.Text
}

function Assert-RootFixtures {
    $fixtures = @(
        @{ Source = '[]'; Array = $true; Object = $false; Count = 0 },
        @{ Source = '[{"schema_version":1}]'; Array = $true; Object = $false; Count = 1 },
        @{ Source = '[{},{}]'; Array = $true; Object = $false; Count = 2 },
        @{ Source = '[null]'; Array = $true; Object = $false; Count = 1 },
        @{ Source = '[[1,2]]'; Array = $true; Object = $false; Count = 1 },
        @{ Source = '[7]'; Array = $true; Object = $false; Count = 1 },
        @{ Source = '{"schema_version":1}'; Array = $false; Object = $true },
        @{ Source = 'null'; Array = $false; Object = $false },
        @{ Source = '"[]"'; Array = $false; Object = $false },
        @{ Source = '7'; Array = $false; Object = $false },
        @{ Source = 'true'; Array = $false; Object = $false }
    )
    foreach ($fixture in $fixtures) {
        $parsed = ConvertFrom-ProjectJsonDocument $fixture.Source
        if (($parsed -is [Array]) -ne $fixture.Array -or (Test-JsonObjectRoot $parsed) -ne $fixture.Object) {
            throw "JSON root identity drifted for $($fixture.Source)."
        }
        if ($fixture.Array -and $parsed.Count -ne $fixture.Count) {
            throw "JSON root array count drifted for $($fixture.Source)."
        }
    }
    $nested = ConvertFrom-ProjectJsonDocument '[[1,2]]'
    if ($nested[0] -isnot [Array] -or $nested[0].Count -ne 2) { throw "Nested JSON array was flattened." }
    $singleton = ConvertFrom-ProjectJsonDocument '[{"schema_version":1}]'
    if (-not (Test-JsonObjectRoot $singleton[0]) -or $singleton[0].schema_version -ne 1) { throw "Singleton array payload drifted." }
    $nullEntry = ConvertFrom-ProjectJsonDocument '[null]'
    if ($null -ne $nullEntry[0]) { throw "JSON null array member drifted." }
    foreach ($hostile in @('1,"injected":2', '{"missing":', '[invalid]')) {
        $rejected = $false
        try { $null = ConvertFrom-ProjectJsonDocument $hostile }
        catch { $rejected = $true }
        if (-not $rejected) { throw "Malformed original JSON escaped validation: $hostile" }
    }
}

Assert-RootFixtures
# Simulate the Windows PowerShell 5 cmdlet surface so the compatibility branch
# proves the same empty/singleton/nested-array and malformed-document contracts.
& {
    $script:legacyParseCallCount = 0
    function ConvertFrom-Json {
        param([string]$InputObject)
        $script:legacyParseCallCount++
        Microsoft.PowerShell.Utility\ConvertFrom-Json -InputObject $InputObject
    }
    Assert-RootFixtures
    if ($script:legacyParseCallCount -lt 20) { throw "Legacy parser compatibility branch was not exercised." }
}

$rootPolicies = @{}
foreach ($policyName in @('objectJsonFiles', 'objectJsonDirectories')) {
    $assignments = @($validatorAst.FindAll({
        param($node)
        $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq ('$' + $policyName)
    }, $true))
    if ($assignments.Count -ne 1) { throw "Expected one exact JSON policy $policyName." }
    $rootPolicies[$policyName] = @($assignments[0].Right.FindAll({
        param($node)
        $node -is [Management.Automation.Language.StringConstantExpressionAst]
    }, $true) | ForEach-Object Value)
}
$legacyPath = 'data/environments/scenario_sequence_compatibility/grand_casino_gala_night_v1.json'
if ($rootPolicies.objectJsonFiles -notcontains $legacyPath -or
    $rootPolicies.objectJsonFiles -contains 'data/collections/collections.json' -or
    $rootPolicies.objectJsonDirectories -contains 'data/environments/scenario_sequence_compatibility/') {
    throw "JSON object policy must classify only the exact legacy scenario document and preserve the collection array contract."
}
$scenarioEngine = Get-Content -LiteralPath (Join-Path $root 'scripts/core/scenario_engine.gd') -Raw
if (-not $scenarioEngine.Contains('LEGACY_GALA_TERMINAL_PATH := "res://' + $legacyPath + '"')) {
    throw "Legacy scenario object allowlist entry lost its exact loader authority."
}

$fileCount = 0
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'data') -Filter '*.json' -File -Recurse) {
    $fileCount++
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    $parsed = ConvertFrom-ProjectJsonDocument (Get-Content -LiteralPath $file.FullName -Raw)
    $requiresObject = $rootPolicies.objectJsonFiles -contains $relative
    foreach ($directory in $rootPolicies.objectJsonDirectories) {
        if ($relative.StartsWith($directory, [StringComparison]::OrdinalIgnoreCase)) { $requiresObject = $true }
    }
    if ($requiresObject) {
        if (-not (Test-JsonObjectRoot $parsed)) { throw "Expected exact object root: $relative" }
    } elseif ($parsed -isnot [Array]) {
        throw "Expected exact array root: $relative"
    }
}
if (-not $Quiet) { Write-Host "Validator JSON root contract passed (both parser branches; $fileCount data documents)." }
