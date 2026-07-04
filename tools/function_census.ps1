param(
    [string]$OutputJson = "",
    [string]$OutputMarkdown = "",
    [switch]$Check,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Join-Path $root "docs/plans/0.3.2_function_census.json"
}
if ([string]::IsNullOrWhiteSpace($OutputMarkdown)) {
    $OutputMarkdown = Join-Path $root "docs/plans/0.3.2_function_census.md"
}

$productionRoots = @("scripts/core", "scripts/games", "scripts/ui")
$nonShippingRoots = @("scripts/tests", "tools")
$classes = @("PER-FRAME", "PER-ACTION", "STARTUP", "SAVE-LOAD")
$classDescriptions = [ordered]@{
    "PER-FRAME" = "Reachable from _process/_physics_process/_draw/_input/_gui_input, draw_surface, _draw_* helpers, *_per_frame, *_needs_auto_tick, or *_runtime_needs_tick inside the same file call graph."
    "PER-ACTION" = "Reachable from mechanically named resolve/apply_result/action-command/activation/confirmation/use/buy/sell/travel dispatch functions inside the same file call graph."
    "STARTUP" = "Reachable from _ready, setup/initialize/build/load-style functions, and ContentLibrary load paths inside the same file call graph."
    "SAVE-LOAD" = "Reachable from to_dict/from_dict/normalize/save/load/serialize/deserialize-style functions inside the same file call graph."
    "UNCLASSIFIED" = "No mechanical signal found. Sweep tasks must manually classify these functions instead of skipping them."
}
$limitations = @(
    "Parser is textual and assumes function declarations begin with optional whitespace, optional static, then func.",
    "Line spans run until the line before the next function declaration in the same file; nested/local functions are not modeled.",
    "Call tracing is same-file and name-based. Dynamic dispatch through call/callv/signals, methods on other classes, string action ids, and engine callbacks beyond the seed names are not resolved.",
    "Classification is intentionally conservative for sweep planning. A hot-class signal means review is required, not proof that the function is expensive."
)

$excludedCallNames = @{}
foreach ($name in @(
    "if", "elif", "else", "for", "while", "match", "return", "await", "assert",
    "print", "push_error", "push_warning", "range", "len", "str", "int", "float",
    "bool", "Array", "Dictionary", "Vector2", "Vector3", "Rect2", "Color", "NodePath",
    "Callable", "Signal", "String", "StringName", "PackedStringArray", "PackedInt32Array",
    "PackedFloat32Array", "PackedVector2Array", "PackedByteArray", "preload", "load",
    "sin", "cos", "tan", "abs", "absf", "min", "max", "mini", "maxi", "minf", "maxf",
    "clamp", "clampi", "clampf", "lerp", "lerpf", "fmod", "fposmod", "pow", "sqrt",
    "ceil", "floor", "round", "is_instance_valid", "typeof"
)) {
    $excludedCallNames[$name] = $true
}

function Get-ProjectRelativePath {
    param([string]$Path)
    $rootPath = [System.IO.Path]::GetFullPath($root)
    if (-not $rootPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootPath += [System.IO.Path]::DirectorySeparatorChar
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootUri = [System.Uri]$rootPath
    $pathUri = [System.Uri]$fullPath
    return ([System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()) -replace "\\", "/")
}

function Get-GdFiles {
    param([string[]]$Roots)
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($relativeRoot in $Roots) {
        $absoluteRoot = Join-Path $root $relativeRoot
        if (-not (Test-Path -LiteralPath $absoluteRoot)) {
            continue
        }
        foreach ($file in Get-ChildItem -LiteralPath $absoluteRoot -Filter "*.gd" -File -Recurse) {
            $result.Add($file)
        }
    }
    return @($result | Sort-Object FullName)
}

function Test-ProductionPath {
    param([string]$RelativePath)
    foreach ($productionRoot in $productionRoots) {
        if ($RelativePath.StartsWith($productionRoot + "/")) {
            return $true
        }
    }
    return $false
}

function Get-SourceGroup {
    param([string]$RelativePath)
    if ($RelativePath.StartsWith("scripts/core/")) { return "core" }
    if ($RelativePath.StartsWith("scripts/games/")) { return "games" }
    if ($RelativePath.StartsWith("scripts/ui/")) { return "ui" }
    if ($RelativePath.StartsWith("scripts/tests/")) { return "tests" }
    if ($RelativePath.StartsWith("tools/")) { return "tools" }
    return "other"
}

function Get-SeedClasses {
    param([string]$FunctionName, [string]$RelativePath)
    $signals = New-Object System.Collections.Generic.List[string]
    if (
        $FunctionName -in @("_process", "_physics_process", "_draw", "_input", "_gui_input", "draw_surface") -or
        $FunctionName -like "_draw_*" -or
        $FunctionName -like "*_per_frame" -or
        $FunctionName -like "*_needs_auto_tick" -or
        $FunctionName -like "*_runtime_needs_tick"
    ) {
        $signals.Add("PER-FRAME")
    }
    if (
        $FunctionName -match '(^|_)resolve($|_)' -or
        $FunctionName -match 'apply_result' -or
        $FunctionName -match 'surface_.*action' -or
        $FunctionName -match 'action_command$' -or
        $FunctionName -match '^_on_.*action' -or
        $FunctionName -match '^_apply_.*command' -or
        $FunctionName -match '^_activate_' -or
        $FunctionName -match '^activate_' -or
        $FunctionName -match '^_confirm_' -or
        $FunctionName -match '^confirm_' -or
        $FunctionName -match '^_use_' -or
        $FunctionName -match '^use_' -or
        $FunctionName -match '^_purchase_' -or
        $FunctionName -match '^purchase_' -or
        $FunctionName -match '^_buy_' -or
        $FunctionName -match '^buy_' -or
        $FunctionName -match '^_sell_' -or
        $FunctionName -match '^sell_' -or
        $FunctionName -match '^_collect_' -or
        $FunctionName -match '^collect_' -or
        $FunctionName -match 'travel'
    ) {
        $signals.Add("PER-ACTION")
    }
    if (
        $FunctionName -eq "_ready" -or
        $FunctionName -match '^_?initialize' -or
        $FunctionName -match '^_?setup' -or
        $FunctionName -match '^_?build' -or
        $FunctionName -match '^_?load' -or
        ($RelativePath -eq "scripts/core/content_library.gd" -and $FunctionName -match 'load|pack|index|validate')
    ) {
        $signals.Add("STARTUP")
    }
    if (
        $FunctionName -match '(^|_)to_dict$' -or
        $FunctionName -match '(^|_)from_dict$' -or
        $FunctionName -match 'normalize' -or
        $FunctionName -match 'serializ' -or
        $FunctionName -match 'deserializ' -or
        $FunctionName -match '(^|_)save' -or
        $FunctionName -match '(^|_)load'
    ) {
        $signals.Add("SAVE-LOAD")
    }
    return @($signals | Sort-Object -Unique)
}

function Get-CallsFromBody {
    param([string[]]$BodyLines)
    $calls = New-Object System.Collections.Generic.List[string]
    $body = [string]::Join("`n", $BodyLines)
    foreach ($match in [regex]::Matches($body, '(?<![\w])([A-Za-z_][A-Za-z0-9_]*)\s*\(')) {
        $callName = [string]$match.Groups[1].Value
        if ($excludedCallNames.ContainsKey($callName)) {
            continue
        }
        if (-not $calls.Contains($callName)) {
            $calls.Add($callName)
        }
    }
    return @($calls | Sort-Object)
}

function Convert-ClassSetToArray {
    param([hashtable]$Set)
    $result = @()
    foreach ($className in $classes) {
        if ($Set.ContainsKey($className)) {
            $result += $className
        }
    }
    if ($result.Count -eq 0) {
        return @("UNCLASSIFIED")
    }
    return $result
}

function Get-FunctionRecordsForFile {
    param([System.IO.FileInfo]$File)
    $relativePath = Get-ProjectRelativePath $File.FullName
    $shipping = Test-ProductionPath $relativePath
    $sourceGroup = Get-SourceGroup $relativePath
    $lines = @(Get-Content -LiteralPath $File.FullName)
    $declarations = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = [string]$lines[$index]
        $match = [regex]::Match($line, '^(\s*)(static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
        if (-not $match.Success) {
            continue
        }
        $declarations.Add([pscustomobject]@{
            Index = $index
            Line = $index + 1
            Name = [string]$match.Groups[3].Value
            Static = -not [string]::IsNullOrWhiteSpace([string]$match.Groups[2].Value)
        })
    }

    $records = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $declarations.Count; $i++) {
        $declaration = $declarations[$i]
        $startIndex = [int]$declaration.Index
        $endIndex = if ($i + 1 -lt $declarations.Count) { [int]$declarations[$i + 1].Index - 1 } else { $lines.Count - 1 }
        $bodyStart = [Math]::Min($startIndex + 1, $lines.Count)
        $bodyEnd = [Math]::Max($bodyStart - 1, $endIndex)
        $bodyLines = if ($bodyEnd -ge $bodyStart) { @($lines[$bodyStart..$bodyEnd]) } else { @() }
        $seedSet = @{}
        foreach ($seedClass in (Get-SeedClasses -FunctionName ([string]$declaration.Name) -RelativePath $relativePath)) {
            $seedSet[$seedClass] = $true
        }
        $records.Add([pscustomobject]@{
            file = $relativePath
            source_group = $sourceGroup
            shipping = $shipping
            name = [string]$declaration.Name
            start_line = [int]$declaration.Line
            end_line = $endIndex + 1
            line_count = ($endIndex - $startIndex + 1)
            static = [bool]$declaration.Static
            kind = if ([bool]$declaration.Static) { "static" } else { "instance" }
            calls = @(Get-CallsFromBody -BodyLines $bodyLines)
            class_set = $seedSet
            classes = @()
        })
    }

    $byName = @{}
    for ($i = 0; $i -lt $records.Count; $i++) {
        $name = [string]$records[$i].name
        if (-not $byName.ContainsKey($name)) {
            $byName[$name] = New-Object System.Collections.Generic.List[int]
        }
        $byName[$name].Add($i)
    }

    $changed = $true
    while ($changed) {
        $changed = $false
        for ($i = 0; $i -lt $records.Count; $i++) {
            $record = $records[$i]
            if ($record.class_set.Count -eq 0) {
                continue
            }
            foreach ($callName in $record.calls) {
                if (-not $byName.ContainsKey($callName)) {
                    continue
                }
                foreach ($targetIndex in $byName[$callName]) {
                    $target = $records[$targetIndex]
                    foreach ($className in $record.class_set.Keys) {
                        if (-not $target.class_set.ContainsKey($className)) {
                            $target.class_set[$className] = $true
                            $changed = $true
                        }
                    }
                }
            }
        }
    }

    foreach ($record in $records) {
        $record.classes = @(Convert-ClassSetToArray -Set $record.class_set)
    }
    return $records.ToArray()
}

function New-Census {
    $allFiles = @(Get-GdFiles -Roots ($productionRoots + $nonShippingRoots))
    $allFunctions = New-Object System.Collections.Generic.List[object]
    foreach ($file in $allFiles) {
        foreach ($record in (Get-FunctionRecordsForFile -File $file)) {
            $allFunctions.Add($record)
        }
    }

    $fileSummaries = New-Object System.Collections.Generic.List[object]
    $paths = @($allFiles | ForEach-Object { Get-ProjectRelativePath $_.FullName } | Sort-Object)
    foreach ($relativePath in $paths) {
        $functionsForFile = @($allFunctions | Where-Object { $_.file -eq $relativePath })
        $counts = [ordered]@{
            total = $functionsForFile.Count
            "PER-FRAME" = 0
            "PER-ACTION" = 0
            "STARTUP" = 0
            "SAVE-LOAD" = 0
            "UNCLASSIFIED" = 0
        }
        foreach ($functionRecord in $functionsForFile) {
            foreach ($className in $functionRecord.classes) {
                $counts[$className] = [int]$counts[$className] + 1
            }
        }
        $fileSummaries.Add([pscustomobject]@{
            file = $relativePath
            source_group = Get-SourceGroup $relativePath
            shipping = Test-ProductionPath $relativePath
            function_count = $functionsForFile.Count
            class_counts = [pscustomobject]$counts
        })
    }

    $summaryCounts = [ordered]@{
        files_total = $paths.Count
        files_shipping = @($fileSummaries | Where-Object { $_.shipping }).Count
        files_non_shipping = @($fileSummaries | Where-Object { -not $_.shipping }).Count
        functions_total = $allFunctions.Count
        functions_shipping = @($allFunctions | Where-Object { $_.shipping }).Count
        functions_non_shipping = @($allFunctions | Where-Object { -not $_.shipping }).Count
        "PER-FRAME" = @($allFunctions | Where-Object { $_.classes -contains "PER-FRAME" }).Count
        "PER-ACTION" = @($allFunctions | Where-Object { $_.classes -contains "PER-ACTION" }).Count
        "STARTUP" = @($allFunctions | Where-Object { $_.classes -contains "STARTUP" }).Count
        "SAVE-LOAD" = @($allFunctions | Where-Object { $_.classes -contains "SAVE-LOAD" }).Count
        "UNCLASSIFIED" = @($allFunctions | Where-Object { $_.classes -contains "UNCLASSIFIED" }).Count
    }

    $cleanFunctions = @($allFunctions | Sort-Object file, start_line | ForEach-Object {
        [pscustomobject]@{
            file = $_.file
            source_group = $_.source_group
            shipping = $_.shipping
            name = $_.name
            start_line = $_.start_line
            end_line = $_.end_line
            line_count = $_.line_count
            static = $_.static
            kind = $_.kind
            classes = @($_.classes)
            calls = @($_.calls)
        }
    })

    return [pscustomobject]@{
        schema_version = 1
        generator = "tools/function_census.ps1"
        roots = [pscustomobject]@{
            production = $productionRoots
            non_shipping = $nonShippingRoots
        }
        classification_descriptions = [pscustomobject]$classDescriptions
        limitations = $limitations
        summary = [pscustomobject]$summaryCounts
        files = @($fileSummaries | Sort-Object file)
        functions = $cleanFunctions
    }
}

function Write-CensusMarkdown {
    param([object]$Census, [string]$Path)
    $lines = New-Object System.Collections.Generic.List[string]
    $summary = $Census.summary
    $bt = [char]96
    $lines.Add("# Beat the House 0.3.2 Function Census")
    $lines.Add("")
    $lines.Add("Generated by $($bt)tools/function_census.ps1$($bt). This file is deterministic and is checked by $($bt)tools/validate_project.ps1$($bt).")
    $lines.Add("")
    $lines.Add("## Method")
    $lines.Add("")
    $lines.Add("The census scans production GDScript under $($bt)scripts/core$($bt), $($bt)scripts/games$($bt), and $($bt)scripts/ui$($bt); it also lists $($bt)scripts/tests$($bt) and $($bt)tools$($bt) GDScript as non-shipping so fixture/tool functions are visible but exempt from shipping-cost review.")
    $lines.Add("")
    $lines.Add("Classification is same-file textual call-graph reachability from mechanical seed names:")
    foreach ($className in ($classDescriptions.Keys | Sort-Object)) {
        $lines.Add("- $($bt)$className$($bt): $($classDescriptions[$className])")
    }
    $lines.Add("")
    $lines.Add("Limitations:")
    foreach ($limitation in $limitations) {
        $lines.Add("- $limitation")
    }
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add("| Metric | Count |")
    $lines.Add("| --- | ---: |")
    foreach ($property in $summary.PSObject.Properties) {
        $lines.Add("| $($bt)$($property.Name)$($bt) | $($property.Value) |")
    }
    $lines.Add("")
    $lines.Add("## Counts Per File")
    $lines.Add("")
    $lines.Add("| File | Shipping | Total | PER-FRAME | PER-ACTION | STARTUP | SAVE-LOAD | UNCLASSIFIED |")
    $lines.Add("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    foreach ($fileSummary in $Census.files) {
        $counts = $fileSummary.class_counts
        $lines.Add("| $($bt)$($fileSummary.file)$($bt) | $($fileSummary.shipping) | $($counts.total) | $($counts.'PER-FRAME') | $($counts.'PER-ACTION') | $($counts.STARTUP) | $($counts.'SAVE-LOAD') | $($counts.UNCLASSIFIED) |")
    }
    foreach ($listClass in @("PER-FRAME", "PER-ACTION", "UNCLASSIFIED")) {
        $lines.Add("")
        $lines.Add("## $listClass Functions")
        $lines.Add("")
        $items = @($Census.functions | Where-Object { $_.classes -contains $listClass } | Sort-Object file, start_line)
        if ($items.Count -eq 0) {
            $lines.Add("_None._")
            continue
        }
        $lines.Add("| File | Function | Lines | Line Count | Kind | Shipping | Classes |")
        $lines.Add("| --- | --- | ---: | ---: | --- | --- | --- |")
        foreach ($item in $items) {
            $classText = [string]::Join(", ", @($item.classes))
            $lines.Add("| $($bt)$($item.file)$($bt) | $($bt)$($item.name)$($bt) | $($item.start_line)-$($item.end_line) | $($item.line_count) | $($item.kind) | $($item.shipping) | $classText |")
        }
    }
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $lines -Encoding utf8
}

function Write-CensusJson {
    param([object]$Census, [string]$Path)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $json = $Census | ConvertTo-Json -Depth 16
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

function Compare-FileText {
    param([string]$ExpectedPath, [string]$ActualPath)
    if (-not (Test-Path -LiteralPath $ExpectedPath)) {
        throw "Missing census output: $(Get-ProjectRelativePath $ExpectedPath)"
    }
    if (-not (Test-Path -LiteralPath $ActualPath)) {
        throw "Generator did not produce comparison file: $ActualPath"
    }
    $expected = [System.IO.File]::ReadAllText($ExpectedPath)
    $actual = [System.IO.File]::ReadAllText($ActualPath)
    if ($expected -ne $actual) {
        throw "Function census is stale: $(Get-ProjectRelativePath $ExpectedPath). Run tools/function_census.ps1 and commit the updated outputs."
    }
}

if ($Check) {
    $tempDir = Join-Path $root ".tmp/function_census_check"
    if (-not (Test-Path -LiteralPath $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }
    $tempJson = Join-Path $tempDir "0.3.2_function_census.json"
    $tempMarkdown = Join-Path $tempDir "0.3.2_function_census.md"
    $census = New-Census
    Write-CensusJson -Census $census -Path $tempJson
    Write-CensusMarkdown -Census $census -Path $tempMarkdown
    Compare-FileText -ExpectedPath $OutputJson -ActualPath $tempJson
    Compare-FileText -ExpectedPath $OutputMarkdown -ActualPath $tempMarkdown
    if (-not $Quiet) {
        Write-Host "Function census freshness check passed."
    }
    exit 0
}

$census = New-Census
Write-CensusJson -Census $census -Path $OutputJson
Write-CensusMarkdown -Census $census -Path $OutputMarkdown
if (-not $Quiet) {
    Write-Host ("Function census wrote {0} functions across {1} files." -f $census.summary.functions_total, $census.summary.files_total)
    Write-Host ("JSON: {0}" -f (Get-ProjectRelativePath $OutputJson))
    Write-Host ("Markdown: {0}" -f (Get-ProjectRelativePath $OutputMarkdown))
}
