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
    if ($text -match '^\$(productionRoots|nonShippingRoots|classes|classDescriptions|limitations|excludedCallNames)\s*=' -or $text.StartsWith('foreach ($name in @(')) {
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

# BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: exercise the actual complete
# generator on a fresh tiny project, including zero-function/non-shipping files.
& {
    $root = Join-Path $root ('grouping-' + [Guid]::NewGuid().ToString('N'))
    $fixtureSources = [ordered]@{
        'scripts/core/empty.gd' = @('extends RefCounted')
        'scripts/games/multi.gd' = @(
            'extends RefCounted',
            'func _process(delta: float) -> void:', "`thelper()",
            'func resolve() -> void:', "`thelper()",
            'func setup() -> void:', "`thelper()",
            'func from_dict(data: Dictionary) -> void:', "`thelper()",
            'func helper() -> void: pass',
            'func unused() -> void: pass'
        )
        'scripts/tests/one.gd' = @('extends RefCounted', 'func resolve_fixture() -> void: pass')
        'tools/one.gd' = @('extends RefCounted', 'func _ready() -> void: pass')
    }
    foreach ($relativePath in $fixtureSources.Keys) {
        $path = Join-Path $root $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, ($fixtureSources[$relativePath] -join "`n"), (New-Object Text.UTF8Encoding($false)))
    }
    $census = New-Census
    if ($census.schema_version -ne 1 -or $census.generator -cne 'tools/function_census.ps1' -or
            $census.summary.files_total -ne 4 -or $census.summary.files_shipping -ne 2 -or
            $census.summary.files_non_shipping -ne 2 -or $census.summary.functions_total -ne 8 -or
            $census.summary.functions_shipping -ne 6 -or $census.summary.functions_non_shipping -ne 2) {
        throw 'BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: real fixture census lost its complete file/function/shipping inventory.'
    }
    $expectedClassCounts = [ordered]@{'PER-FRAME'=2; 'PER-ACTION'=3; 'STARTUP'=3; 'SAVE-LOAD'=2; 'UNCLASSIFIED'=1}
    foreach ($className in $expectedClassCounts.Keys) {
        if ($census.summary.$className -ne $expectedClassCounts[$className]) {
            throw "BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: real fixture changed $className reachability counts."
        }
    }
    if (($census.files.file -join ',') -cne 'scripts/core/empty.gd,scripts/games/multi.gd,scripts/tests/one.gd,tools/one.gd' -or
            $census.files[0].function_count -ne 0 -or $census.files[0].class_counts.total -ne 0 -or
            $census.files[2].shipping -or $census.files[2].source_group -cne 'tests' -or
            $census.files[3].shipping -or $census.files[3].source_group -cne 'tools') {
        throw 'BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: empty-file row, sorted paths or non-shipping groups changed.'
    }
    $helper = @($census.functions | Where-Object { $_.file -ceq 'scripts/games/multi.gd' -and $_.name -ceq 'helper' })
    if ($helper.Count -ne 1 -or ($helper[0].classes -join ',') -cne 'PER-FRAME,PER-ACTION,STARTUP,SAVE-LOAD') {
        throw 'BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: shared helper lost a complete ordered class set.'
    }
}

# Path aliases that cannot coexist as ordinary Windows files are supplied only
# at the internal already-parsed-record boundary. The oracle deliberately uses
# the previous PowerShell -eq filter, not a guessed filename comparer.
& {
    function New-CensusGroupingRecord {
        param([string]$Path, [string]$Name, [int]$Line, [string[]]$Classes, [string[]]$Calls = @(), [bool]$Static = $false)
        return [pscustomobject]@{
            file=$Path; source_group=(Get-SourceGroup $Path); shipping=(Test-ProductionPath $Path)
            name=$Name; start_line=$Line; end_line=($Line+1); line_count=2
            static=$Static; kind=$(if ($Static) {'static'} else {'instance'})
            classes=@($Classes); calls=@($Calls)
        }
    }
    $upper = 'scripts/ui/Case.gd'
    $lower = 'SCRIPTS/UI/case.gd'
    $composed = 'scripts/ui/caf' + [char]0x00e9 + '.gd'
    $decomposed = 'scripts/ui/cafe' + [char]0x0301 + '.gd'
    $softPlain = 'scripts/ui/softname.gd'
    $softHyphen = 'scripts/ui/soft' + [char]0x00ad + 'name.gd'
    $capitalI = 'scripts/ui/I.gd'
    $smallI = 'scripts/ui/i.gd'
    $dottedI = 'scripts/ui/' + [char]0x0130 + '.gd'
    $dotlessI = 'scripts/ui/' + [char]0x0131 + '.gd'
    $fixtureFiles = @(
        [pscustomobject]@{FullName='tools/last.gd'; Records=@((New-CensusGroupingRecord 'tools/last.gd' 'zeta' 9 @('UNCLASSIFIED') @('alpha','zeta') $true))},
        [pscustomobject]@{FullName='scripts/core/empty.gd'; Records=@()},
        [pscustomobject]@{FullName=$upper; Records=@((New-CensusGroupingRecord $upper 'first' 3 @('STARTUP')), (New-CensusGroupingRecord $upper 'second' 8 @('PER-FRAME','PER-ACTION') @('first')))},
        [pscustomobject]@{FullName=$lower; Records=@((New-CensusGroupingRecord $lower 'lower' 2 @('SAVE-LOAD')))},
        [pscustomobject]@{FullName=$composed; Records=@((New-CensusGroupingRecord $composed 'composed' 4 @('SAVE-LOAD')))},
        [pscustomobject]@{FullName=$decomposed; Records=@((New-CensusGroupingRecord $decomposed 'decomposed' 6 @('STARTUP')))},
        [pscustomobject]@{FullName=$softPlain; Records=@((New-CensusGroupingRecord $softPlain 'plain' 4 @('PER-FRAME')))},
        [pscustomobject]@{FullName=$softHyphen; Records=@((New-CensusGroupingRecord $softHyphen 'soft' 6 @('PER-ACTION')))},
        [pscustomobject]@{FullName=$capitalI; Records=@((New-CensusGroupingRecord $capitalI 'capital' 2 @('UNCLASSIFIED')))},
        [pscustomobject]@{FullName=$smallI; Records=@((New-CensusGroupingRecord $smallI 'small' 3 @('SAVE-LOAD')))},
        [pscustomobject]@{FullName=$dottedI; Records=@((New-CensusGroupingRecord $dottedI 'dotted' 4 @('PER-ACTION')))},
        [pscustomobject]@{FullName=$dotlessI; Records=@((New-CensusGroupingRecord $dotlessI 'dotless' 5 @('PER-FRAME')))},
        [pscustomobject]@{FullName='scripts/games/one.gd'; Records=@((New-CensusGroupingRecord 'scripts/games/one.gd' 'single' 2 @('PER-FRAME','PER-ACTION','STARTUP','SAVE-LOAD')))}
    )
    # Preserve exact duplicate file entries and their duplicate function records.
    $fixtureFiles += $fixtureFiles[2]
    function Get-GdFiles { param([string[]]$Roots); return $fixtureFiles }
    function Get-ProjectRelativePath { param([string]$Path); return $Path }
    function Get-FunctionRecordsForFile { param([object]$File); return @($File.Records) }
    $priorCulture = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
        foreach ($cultureName in @('', 'tr-TR')) {
            [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo($cultureName)
            $before = $fixtureFiles | ConvertTo-Json -Depth 16
            $allRecords = @($fixtureFiles | ForEach-Object { $_.Records })
            $paths = @($fixtureFiles | ForEach-Object { $_.FullName } | Sort-Object)
            $expectedFiles = @(
                foreach ($relativePath in $paths) {
                    $bucket = @($allRecords | Where-Object { $_.file -eq $relativePath })
                    $counts = [ordered]@{total=$bucket.Count}
                    foreach ($className in (@($classes) + @('UNCLASSIFIED'))) {
                        $counts[$className] = @($bucket | Where-Object { $_.classes -contains $className }).Count
                    }
                    [pscustomobject]@{
                        file=$relativePath; source_group=(Get-SourceGroup $relativePath); shipping=(Test-ProductionPath $relativePath)
                        function_count=$bucket.Count; class_counts=[pscustomobject]$counts
                    }
                }
            )
            $summary = [ordered]@{
                files_total=$paths.Count
                files_shipping=@($expectedFiles | Where-Object { $_.shipping }).Count
                files_non_shipping=@($expectedFiles | Where-Object { -not $_.shipping }).Count
                functions_total=$allRecords.Count
                functions_shipping=@($allRecords | Where-Object { $_.shipping }).Count
                functions_non_shipping=@($allRecords | Where-Object { -not $_.shipping }).Count
            }
            foreach ($className in (@($classes) + @('UNCLASSIFIED'))) {
                $summary[$className] = @($allRecords | Where-Object { $_.classes -contains $className }).Count
            }
            $expected = [pscustomobject]@{
                schema_version=1; generator='tools/function_census.ps1'
                roots=[pscustomobject]@{production=$productionRoots; non_shipping=$nonShippingRoots}
                classification_descriptions=[pscustomobject]$classDescriptions; limitations=$limitations
                summary=[pscustomobject]$summary
                files=@($expectedFiles | Sort-Object file)
                functions=@($allRecords | Sort-Object file,start_line)
            }
            $actual = New-Census
            if (($actual | ConvertTo-Json -Depth 16) -cne ($expected | ConvertTo-Json -Depth 16)) {
                throw "BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: complete grouping output differs from the original -eq filter under culture '$cultureName'."
            }
            if (($fixtureFiles | ConvertTo-Json -Depth 16) -cne $before) {
                throw 'BTH061-AUDIT-AGGREGATE-TIME-BUDGET-005: census mutated parsed source records.'
            }
        }
    }
    finally {
        [Threading.Thread]::CurrentThread.CurrentCulture = $priorCulture
    }
}

if (-not $Quiet) {
    Write-Host "Function census parser, attribution and grouping contracts passed ($($PSVersionTable.PSVersion))."
}
