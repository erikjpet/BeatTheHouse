param([string]$Root = "")

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}

$failures = New-Object System.Collections.Generic.List[string]
$surfacePath = Join-Path $Root "data/environments/placement_surfaces.json"
$archetypePath = Join-Path $Root "data/environments/archetypes.json"
$classifierPath = Join-Path $Root "scripts/core/environment_placement.gd"
$scenarioRoot = Join-Path $Root "data/environments/scenario_sequences"

function Get-Values {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Array]) { return @($Value) }
    return @($Value)
}

function Test-Number {
    param([AllowNull()][object]$Value)
    return $null -ne $Value -and $Value -is [ValueType]
}

function Test-RectArray {
    param([string]$Label, [AllowNull()][object]$Value, [double]$BoardWidth, [double]$BoardHeight)
    $parts = @(Get-Values $Value)
    if ($parts.Count -ne 4 -or -not (Test-Number $parts[0]) -or -not (Test-Number $parts[1]) -or -not (Test-Number $parts[2]) -or -not (Test-Number $parts[3])) {
        $failures.Add("$Label must be a numeric [x,y,w,h] rectangle.")
        return
    }
    $x = [double]$parts[0]; $y = [double]$parts[1]; $w = [double]$parts[2]; $h = [double]$parts[3]
    if ($x -lt 0 -or $y -lt 0 -or $w -le 0 -or $h -le 0 -or $x + $w -gt $BoardWidth -or $y + $h -gt $BoardHeight) {
        $failures.Add("$Label leaves the ${BoardWidth}x${BoardHeight} environment board.")
    }
}

if (-not (Test-Path -LiteralPath $surfacePath) -or -not (Test-Path -LiteralPath $archetypePath) -or -not (Test-Path -LiteralPath $classifierPath)) {
    throw "Environment grounding checker is missing its surface map, archetype source, or classifier."
}

$surfaceRoot = Get-Content -LiteralPath $surfacePath -Raw | ConvertFrom-Json
$archetypeRoot = Get-Content -LiteralPath $archetypePath -Raw | ConvertFrom-Json
$archetypes = @(Get-Values $archetypeRoot)
$classifier = Get-Content -LiteralPath $classifierPath -Raw
$board = @(Get-Values $surfaceRoot.board_size)
if ([int]$surfaceRoot.schema_version -ne 1 -or $board.Count -ne 2) {
    $failures.Add("placement_surfaces.json must use schema_version 1 and a two-number board_size.")
    $board = @(900, 430)
}
$boardWidth = [double]$board[0]; $boardHeight = [double]$board[1]

$requiredClasses = @(
    "standing_person", "behind_counter_person", "seated_person", "group",
    "floor_fixture", "ground_marker", "surface_item", "wall_mounted",
    "hanging", "doorway"
)
foreach ($placementClass in $requiredClasses) {
    if (-not $classifier.Contains('"' + $placementClass + '"')) {
        $failures.Add("EnvironmentPlacement classifier is missing class: $placementClass")
    }
}
if ($classifier -match '\b(randf|randi|randomize|Time\.)\b') {
    $failures.Add("EnvironmentPlacement must be a pure function without RNG or wall-clock input.")
}

$mapsById = @{}
foreach ($map in @(Get-Values $surfaceRoot.maps)) {
    $mapId = [string]$map.id
    if ([string]::IsNullOrWhiteSpace($mapId)) {
        $failures.Add("Every placement surface map requires an id.")
        continue
    }
    if ($mapsById.ContainsKey($mapId)) {
        $failures.Add("Duplicate placement surface map id: $mapId")
        continue
    }
    $mapsById[$mapId] = $map
    foreach ($requiredField in @("floor", "counters", "seats", "wall", "ceiling", "doorways", "void")) {
        if ($null -eq $map.PSObject.Properties[$requiredField]) {
            $failures.Add("surface map $mapId is missing $requiredField.")
        }
    }
    foreach ($band in @(Get-Values $map.floor.bands)) { Test-RectArray "surface map $mapId floor band" $band $boardWidth $boardHeight }
    foreach ($band in @(Get-Values $map.floor.stage_bands)) { Test-RectArray "surface map $mapId stage band" $band $boardWidth $boardHeight }
    $contacts = @(Get-Values $map.floor.contact_y)
    if ($contacts.Count -ne 2 -or [double]$contacts[0] -gt [double]$contacts[1]) {
        $failures.Add("surface map $mapId floor.contact_y must be an ordered pair.")
    }
    foreach ($counter in @(Get-Values $map.counters)) {
        if ([string]::IsNullOrWhiteSpace([string]$counter.id) -or [double]$counter.x0 -lt 0 -or [double]$counter.x1 -gt $boardWidth -or [double]$counter.x0 -ge [double]$counter.x1 -or [double]$counter.top_y -lt 0 -or [double]$counter.top_y -gt $boardHeight -or [double]$counter.front_y -lt [double]$counter.top_y -or [double]$counter.front_y -gt $boardHeight) {
            $failures.Add("surface map $mapId has an invalid named counter.")
        }
        foreach ($counterClass in @(Get-Values $counter.classes)) {
            if ($requiredClasses -notcontains [string]$counterClass) {
                $failures.Add("surface map $mapId counter $($counter.id) has unknown class $counterClass.")
            }
        }
    }
    foreach ($seat in @(Get-Values $map.seats)) {
        $point = @(Get-Values $seat.point)
        if ([string]::IsNullOrWhiteSpace([string]$seat.id) -or $point.Count -ne 2 -or [double]$point[0] -lt 0 -or [double]$point[0] -gt $boardWidth -or [double]$point[1] -lt 0 -or [double]$point[1] -gt $boardHeight) {
            $failures.Add("surface map $mapId has an invalid named seat.")
        }
    }
    Test-RectArray "surface map $mapId wall.bounds" $map.wall.bounds $boardWidth $boardHeight
    Test-RectArray "surface map $mapId ceiling.bounds" $map.ceiling.bounds $boardWidth $boardHeight
    foreach ($entry in @(Get-Values $map.wall.exclusions)) { Test-RectArray "surface map $mapId wall exclusion $($entry.id)" $entry.bounds $boardWidth $boardHeight }
    foreach ($entry in @(Get-Values $map.doorways)) { Test-RectArray "surface map $mapId doorway $($entry.id)" $entry.bounds $boardWidth $boardHeight }
    foreach ($entry in @(Get-Values $map.void)) { Test-RectArray "surface map $mapId void $($entry.id)" $entry.bounds $boardWidth $boardHeight }

    foreach ($reservationField in @("scenario_reserved_rects", "scenario_reserved_surface_rects", "scenario_reserved_wall_rects", "scenario_reserved_clear_rects")) {
        $reservationProperty = $map.PSObject.Properties[$reservationField]
        if ($null -eq $reservationProperty) { continue }
        foreach ($reservedRect in @(Get-Values $reservationProperty.Value)) {
            Test-RectArray "surface map $mapId $reservationField" $reservedRect $boardWidth $boardHeight
        }
    }

    $slotProperty = $map.PSObject.Properties["object_slot_positions"]
    if ($null -ne $slotProperty) {
        foreach ($slot in @($slotProperty.Value.PSObject.Properties)) {
            $point = @(Get-Values $slot.Value)
            if ([string]::IsNullOrWhiteSpace([string]$slot.Name) -or $point.Count -ne 2 -or -not (Test-Number $point[0]) -or -not (Test-Number $point[1]) -or [double]$point[0] -lt 0 -or [double]$point[0] -ge $boardWidth -or [double]$point[1] -lt 0 -or [double]$point[1] -ge $boardHeight) {
                $failures.Add("surface map $mapId object slot $($slot.Name) must be a board-space [x,y] point.")
            }
        }
    }

    $namedSurfaceIds = @("floor", "stage", "wall", "ceiling")
    $namedSurfaceIds += @((Get-Values $map.counters) | ForEach-Object { [string]$_.id })
    $namedSurfaceIds += @((Get-Values $map.seats) | ForEach-Object { [string]$_.id })
    $namedSurfaceIds += @((Get-Values $map.doorways) | ForEach-Object { [string]$_.id })
    foreach ($reservationField in @("scenario_reserved_surfaces", "scenario_reserved_behind_counter_surfaces")) {
        $reservationProperty = $map.PSObject.Properties[$reservationField]
        if ($null -eq $reservationProperty) { continue }
        foreach ($surfaceId in @(Get-Values $reservationProperty.Value)) {
            if ($namedSurfaceIds -notcontains [string]$surfaceId) {
                $failures.Add("surface map $mapId $reservationField names unknown support $surfaceId.")
            }
        }
    }

    $overrideRoot = $map.PSObject.Properties["class_overrides"]
    $overrides = if ($null -eq $overrideRoot) { @() } else { @($overrideRoot.Value.PSObject.Properties) }
    foreach ($override in $overrides) {
        $overrideClass = [string]$override.Value
        if ([string]::IsNullOrWhiteSpace([string]$override.Name) -or $requiredClasses -notcontains $overrideClass) {
            $failures.Add("surface map $mapId has invalid class override $($override.Name)=$overrideClass.")
            continue
        }
        $hasSupport = switch ($overrideClass) {
            { $_ -in @("standing_person", "group", "floor_fixture", "ground_marker") } { @(Get-Values $map.floor.bands).Count -gt 0; break }
            { $_ -in @("behind_counter_person", "surface_item") } { @(Get-Values $map.counters).Count -gt 0; break }
            "seated_person" { @(Get-Values $map.seats).Count -gt 0; break }
            "wall_mounted" { @(Get-Values $map.wall.bounds).Count -eq 4; break }
            "hanging" { @(Get-Values $map.ceiling.bounds).Count -eq 4; break }
            "doorway" { @(Get-Values $map.doorways).Count -gt 0; break }
            default { $false }
        }
        if (-not $hasSupport) {
            $failures.Add("surface map $mapId override $($override.Name) has no authored support for $overrideClass.")
        }
    }
}

foreach ($archetype in $archetypes) {
    $archetypeId = [string]$archetype.id
    if (-not $mapsById.ContainsKey($archetypeId)) {
        $failures.Add("Environment archetype $archetypeId has no placement surface map.")
    }
    $anchorProperties = @()
    if ($null -ne $archetype.semantic_anchors) { $anchorProperties = @($archetype.semantic_anchors.PSObject.Properties) }
    foreach ($anchorProperty in $anchorProperties) {
        $position = @(Get-Values $anchorProperty.Value.position)
        if ($position.Count -ne 2 -or -not (Test-Number $position[0]) -or -not (Test-Number $position[1]) -or [double]$position[0] -lt 0 -or [double]$position[0] -gt $boardWidth -or [double]$position[1] -lt 0 -or [double]$position[1] -gt $boardHeight) {
            $failures.Add("environment $archetypeId anchor $($anchorProperty.Name) has no board-space position.")
        }
        if ($null -ne $anchorProperty.Value.placement_class -and $requiredClasses -notcontains [string]$anchorProperty.Value.placement_class) {
            $failures.Add("environment $archetypeId anchor $($anchorProperty.Name) has unknown placement_class $($anchorProperty.Value.placement_class).")
        }
    }
    $zoneProperties = @()
    if ($null -ne $archetype.semantic_zones) { $zoneProperties = @($archetype.semantic_zones.PSObject.Properties) }
    foreach ($zoneProperty in $zoneProperties) {
        Test-RectArray "environment $archetypeId zone $($zoneProperty.Name)" $zoneProperty.Value.bounds $boardWidth $boardHeight
    }
    $layoutProperties = @()
    if ($null -ne $archetype.layout) { $layoutProperties = @($archetype.layout.PSObject.Properties | Where-Object { $_.Name.EndsWith("_spots") }) }
    foreach ($layoutProperty in $layoutProperties) {
        if ($layoutProperty.Value -isnot [System.Collections.IEnumerable] -or $layoutProperty.Value -is [string]) { continue }
        foreach ($spot in @(Get-Values $layoutProperty.Value)) {
            if ($null -eq $spot) { continue }
            $point = @(Get-Values $spot)
            if ($point.Count -ne 2 -or -not (Test-Number $point[0]) -or -not (Test-Number $point[1]) -or [double]$point[0] -lt 0 -or [double]$point[0] -gt $boardWidth -or [double]$point[1] -lt 0 -or [double]$point[1] -gt $boardHeight) {
                $failures.Add("environment $archetypeId $($layoutProperty.Name) contains a non-board-space spot.")
            }
        }
    }
}

foreach ($layerMap in @("small_underground_casino:club", "small_underground_casino:casino", "small_underground_casino:back_room")) {
    if (-not $mapsById.ContainsKey($layerMap)) {
        $failures.Add("Punchline layer has no placement surface map: $layerMap")
    }
}

function Test-PlacementClasses {
    param([AllowNull()][object]$Value, [string]$Path)
    if ($null -eq $Value) { return }
    if ($Value -is [System.Array]) {
        for ($index = 0; $index -lt $Value.Count; $index++) { Test-PlacementClasses $Value[$index] "$Path[$index]" }
        return
    }
    if ($Value -isnot [pscustomobject]) { return }
    $placementProperty = $Value.PSObject.Properties["placement_class"]
    if ($null -ne $placementProperty -and $requiredClasses -notcontains [string]$placementProperty.Value) {
        $failures.Add("$Path has unknown placement_class $($placementProperty.Value).")
    }
    foreach ($property in $Value.PSObject.Properties) { Test-PlacementClasses $property.Value "$Path.$($property.Name)" }
}

foreach ($scenarioFile in @(Get-ChildItem -LiteralPath $scenarioRoot -Filter "*.json" -File)) {
    Test-PlacementClasses (Get-Content -LiteralPath $scenarioFile.FullName -Raw | ConvertFrom-Json) $scenarioFile.Name
}

if ($failures.Count -gt 0) {
    throw ("Environment grounding static check failed:`n - " + ($failures -join "`n - "))
}

Write-Output "Environment grounding static check passed: $($mapsById.Count) maps, $($archetypes.Count) archetypes, $($requiredClasses.Count) classes."
