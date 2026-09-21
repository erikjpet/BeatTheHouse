function Invoke-Health06StaticSourceRules {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $lines = @(Get-Content -LiteralPath $path)
        $source = $lines -join "`n"

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $line = $lines[$index]
            if ($line -match 'store_string\s*\(') {
                $end = [Math]::Min($lines.Count - 1, $index + 3)
                $window = ($lines[$index..$end] -join "`n")
                if ($window -notmatch 'get_error\s*\(') {
                    $errors.Add("[unchecked-store-string] ${path}:$($index + 1) has no get_error() check within three lines.")
                }
            }
            if ($line -match 'remove_absolute\s*\([^\)]*primary[^\)]*\)') {
                $errors.Add("[primary-remove-before-rename] ${path}:$($index + 1) removes a primary path instead of installing through validated rename.")
            }
        }

        $typedMembers = @{}
        foreach ($match in [regex]::Matches($source, '(?m)^\s*(?:static\s+)?var\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?<type>String|int|float|bool)\b')) {
            $typedMembers[$match.Groups['name'].Value] = $match.Groups['type'].Value
        }
        foreach ($functionMatch in [regex]::Matches($source, '(?ms)^\s*(?:static\s+)?func\s+from_dict\s*\([^\)]*\).*?(?=^\s*(?:static\s+)?func\s+|\z)')) {
            $body = $functionMatch.Value
            foreach ($memberName in $typedMembers.Keys) {
                $assignmentPattern = '(?m)^\s*' + [regex]::Escape($memberName) + '\s*=\s*data\.get\s*\('
                if ($body -match $assignmentPattern) {
                    $errors.Add("[raw-typed-from-dict] $path assigns data.get() directly to typed member $memberName in from_dict().")
                }
            }
        }

        if ($source -match '(?m)^\s*var\s+_loaded\b' -and $source -match 'JSON\.parse(?:_string)?\s*\(') {
            $errors.Add("[instance-loaded-json] $path combines an instance _loaded flag with JSON parsing.")
        }

        foreach ($cacheMatch in [regex]::Matches($source, '(?m)^(?:static\s+)?var\s+(?<name>[A-Za-z_][A-Za-z0-9_]*cache[A-Za-z0-9_]*)\s*(?::\s*Dictionary)?\s*(?::?=)\s*\{\}')) {
            $cacheName = $cacheMatch.Groups['name'].Value
            $escapedCache = [regex]::Escape($cacheName)
            $resetCount = [regex]::Matches($source, '(?m)' + $escapedCache + '\s*=\s*\{\}').Count
            $keyedWrites = $source -match ($escapedCache + '\s*\[') -or $source -match ($escapedCache + '\.merge\s*\(')
            $bounded = -not $keyedWrites `
                -or $source -match '(?m)^\s*const\s+[A-Za-z0-9_]*(?:CACHE[A-Za-z0-9_]*(?:MAX|CAPACITY|LIMIT)|(?:MAX|CAPACITY|LIMIT)[A-Za-z0-9_]*CACHE)[A-Za-z0-9_]*\b' `
                -or $resetCount -gt 1 `
                -or $source -match ($escapedCache + '\.clear\s*\(') `
                -or $source -match '(?m)^\s*(?:static\s+)?var\s+_[A-Za-z0-9_]*(?:valid|ready)\b' `
                -or $source -match '(?m)^\s*const\s+[A-Za-z0-9_]*(?:KEYS|IDS|TYPES|PATHS|SCRIPTS|DEFINITIONS|CATALOG)\s*:?='
            if (-not $bounded) {
                $errors.Add("[unbounded-cache] $path cache $cacheName has no entry budget, reset, validity flag, or finite authored vocabulary.")
            }
        }

        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -notmatch '^\s*(?:static\s+)?func\s+(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*\(') { continue }
            $functionName = $Matches.name
            $commentIndex = $index - 1
            $docLines = New-Object System.Collections.Generic.List[string]
            while ($commentIndex -ge 0 -and $lines[$commentIndex] -match '^\s*##\s?(?<text>.*)$') {
                $docLines.Insert(0, $Matches.text)
                $commentIndex--
            }
            if ($docLines.Count -gt 0) {
                $docText = ($docLines -join ' ').ToLowerInvariant()
                $humanName = ($functionName.TrimStart('_') -replace '_', ' ').ToLowerInvariant()
                if (-not $docText.Contains($functionName.ToLowerInvariant()) -and -not $docText.Contains($humanName)) {
                    $errors.Add("[orphan-doc-comment] ${path}:$($index + 1) doc block does not name $functionName.")
                }
            }
        }

        $debugMatches = @([regex]::Matches($source, '(?ms)^\s*(?:static\s+)?func\s+[A-Za-z0-9_]*debug_snapshot[A-Za-z0-9_]*\s*\([^\)]*\).*?(?=^\s*(?:static\s+)?func\s+|\z)'))
        if ($debugMatches.Count -gt 0) {
            $debugText = ($debugMatches | ForEach-Object { $_.Value }) -join "`n"
            foreach ($counterMatch in [regex]::Matches($source, '(?m)^\s*(?:static\s+)?var\s+(?<name>[A-Za-z_][A-Za-z0-9_]*(?:count|counter)[A-Za-z0-9_]*)\b[^\n]*')) {
                $counterName = $counterMatch.Groups['name'].Value
                if ($debugText -notmatch ('\b' + [regex]::Escape($counterName) + '\b')) { continue }
                $afterDeclaration = $source.Substring($counterMatch.Index + $counterMatch.Length)
                $livePattern = '\b' + [regex]::Escape($counterName) + '\s*(?:\+=|-=|=\s*[^=])'
                if ($afterDeclaration -notmatch $livePattern) {
                    $errors.Add("[dead-debug-counter] $path reports $counterName but never changes it after declaration.")
                }
            }
        }
    }
    return $errors
}
