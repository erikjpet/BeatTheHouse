param(
    [ValidateRange(1, 512)]
    [int]$SeedsPerPlaystyle = 64,
    [ValidateRange(8, 512)]
    [int]$MaxActions = 208,
    [ValidateRange(1, 8)]
    [int]$WorkerCount = 4,
    [string]$SeedPrefix = "BALANCE06-1-FINAL",
    [string]$OutDir = "",
    [string]$RuntimeSourceRoot = "",
    [string]$ResumeFrom = "",
    [ValidateSet("FINAL", "DIAGNOSTIC")]
    [string]$RunMode = "FINAL",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$reportSchema = "cross_economy_audit_v1"
$identitySchema = "balance06_1_distribution_shard_identity_v3"
$exitSchema = "balance06_1_distribution_shard_exit_v3"
$finalSeedsPerPlaystyle = 64
$finalMaxActions = 208
$styles = @(
    "control_crew_ignoring", "pure_gambler", "crew_maximizer",
    "numbers_specialist", "coin_pusher_grinder", "cheater",
    "heist_rusher", "mixed_opportunist"
)

function Get-ObjectValue([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-Sha256Text([string]$Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    return ([Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
}

function Write-JsonFile([object]$Value, [string]$Path, [int]$Depth = 20) {
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding utf8
}

function Add-ManifestFailures([string]$Label, [string]$Root, [string]$ManifestPath, [Collections.Generic.List[string]]$Failures) {
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        $Failures.Add("$Label manifest is missing: $ManifestPath")
        return
    }
    try { $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json }
    catch {
        $Failures.Add("$Label manifest is not valid JSON: $($_.Exception.Message)")
        return
    }
    foreach ($entry in @(Get-ObjectValue $manifest "entries")) {
        if ($null -eq $entry) { continue }
        $relativePath = [string](Get-ObjectValue $entry "path")
        $expectedSha = [string](Get-ObjectValue $entry "sha256")
        $expectedBytes = [int64](Get-ObjectValue $entry "bytes")
        $absolutePath = Join-Path $Root $relativePath.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            $Failures.Add("$Label file is missing: $relativePath")
            continue
        }
        $actualBytes = (Get-Item -LiteralPath $absolutePath).Length
        $actualSha = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualBytes -ne $expectedBytes -or $actualSha -cne $expectedSha) {
            $Failures.Add("$Label file identity mismatch: $relativePath")
        }
    }
}

function Get-IdentityFailures([object]$Record, [object]$Expected, [string]$Label) {
    $result = [Collections.Generic.List[string]]::new()
    foreach ($key in @(
        "run_mode", "exact_head", "exact_tree", "input_manifest_sha256", "policy_blob",
        "plugin_identity_sha256", "runtime_artifact_manifest_sha256", "report_schema",
        "godot_console_sha256", "godot_worker_sha256"
    )) {
        $actual = [string](Get-ObjectValue $Record $key)
        $wanted = [string](Get-ObjectValue $Expected $key)
        if ($actual -cne $wanted) { $result.Add("$Label identity mismatch for ${key}: expected '$wanted', got '$actual'.") }
    }
    return @($result)
}

function Get-RunModeFailures([string]$Mode, [int]$SeedCount, [int]$ActionCount) {
    $result = [Collections.Generic.List[string]]::new()
    if ($Mode -eq "FINAL") {
        if ($SeedCount -ne $finalSeedsPerPlaystyle) {
            $result.Add("FINAL requires exactly $finalSeedsPerPlaystyle seeds for each of the eight fixed playstyles; got $SeedCount.")
        }
        if ($ActionCount -ne $finalMaxActions) {
            $result.Add("FINAL requires exactly $finalMaxActions actions; got $ActionCount.")
        }
    }
    return @($result)
}

function Get-RunArtifactContract([string]$Mode, [bool]$Passed) {
    if ($Mode -eq "FINAL") {
        return [pscustomobject]@{
            summary_schema = "balance06_1_cross_economy_distribution_v3"
            manifest_schema = "balance06_1_cross_economy_custody_v2"
            manifest_name = "custody_manifest.json"
            qualifies_for_final = $Passed
        }
    }
    return [pscustomobject]@{
        summary_schema = "balance06_1_cross_economy_diagnostic_v1"
        manifest_schema = "balance06_1_cross_economy_diagnostic_manifest_v1"
        manifest_name = "diagnostic_manifest.json"
        qualifies_for_final = $false
    }
}

function Get-OpportunityCounter([object]$Run, [string]$System, [string]$Counter) {
    $opportunities = Get-ObjectValue $Run "opportunities"
    $row = Get-ObjectValue $opportunities $System
    $value = Get-ObjectValue $row $Counter
    if ($null -eq $value) { return 0 }
    return [int]$value
}

function Get-LedgerLabels([object[]]$Runs) {
    $labels = [Collections.Generic.List[string]]::new()
    foreach ($run in $Runs) {
        foreach ($entry in @(Get-ObjectValue $run "ledger")) {
            if ($null -ne $entry) { $labels.Add([string](Get-ObjectValue $entry "label")) }
        }
    }
    return @($labels)
}

function Get-SpecialistCoverageFailures([string]$Style, [object[]]$Runs) {
    $result = [Collections.Generic.List[string]]::new()
    $hasQualifiedRun = $false
    switch ($Style) {
        { $_ -in @("control_crew_ignoring", "pure_gambler", "cheater") } {
            foreach ($run in $Runs) {
                $runLabels = @(Get-LedgerLabels @($run))
                if ((Get-OpportunityCounter $run "games" "accepted") -gt 0 -and
                    (Get-OpportunityCounter $run "games" "settled") -gt 0 -and
                    @($runLabels | Where-Object { $_.StartsWith("game:", [StringComparison]::Ordinal) }).Count -gt 0) {
                    $hasQualifiedRun = $true; break
                }
            }
            if (-not $hasQualifiedRun) {
                $result.Add("$Style has no accepted and settled production game evidence.")
            }
        }
        "crew_maximizer" {
            foreach ($run in $Runs) {
                $runLabels = @(Get-LedgerLabels @($run))
                $hasAccept = $runLabels -contains "crew_job_accept"
                $hasSettlement = @($runLabels | Where-Object { $_ -match '^crew_job:.+(:collection|:stake_repay|:stake_play|_work)$' }).Count -gt 0
                if ((Get-OpportunityCounter $run "jobs" "accepted") -gt 0 -and
                    (Get-OpportunityCounter $run "jobs" "settled") -gt 0 -and $hasAccept -and $hasSettlement) {
                    $hasQualifiedRun = $true; break
                }
            }
            if (-not $hasQualifiedRun) {
                $result.Add("crew_maximizer has no real crew job accepted-and-settled evidence.")
            }
        }
        "numbers_specialist" {
            foreach ($run in $Runs) {
                $runLabels = @(Get-LedgerLabels @($run))
                $hasSelection = @($runLabels | Where-Object { $_.StartsWith("numbers_", [StringComparison]::Ordinal) }).Count -gt 0
                $hasSettlement = @($runLabels | Where-Object {
                    $_.StartsWith("numbers_", [StringComparison]::Ordinal) -and
                    -not $_.EndsWith("_begin", [StringComparison]::Ordinal) -and
                    -not $_.EndsWith("_wait", [StringComparison]::Ordinal) -and
                    -not $_.EndsWith("_travel", [StringComparison]::Ordinal)
                }).Count -gt 0
                if ((Get-OpportunityCounter $run "numbers" "accepted") -gt 0 -and
                    (Get-OpportunityCounter $run "numbers" "settled") -gt 0 -and $hasSelection -and $hasSettlement) {
                    $hasQualifiedRun = $true; break
                }
            }
            if (-not $hasQualifiedRun) {
                $result.Add("numbers_specialist has no real Numbers selection-and-settlement evidence.")
            }
        }
        "coin_pusher_grinder" {
            foreach ($run in $Runs) {
                $runLabels = @(Get-LedgerLabels @($run))
                if ([bool](Get-ObjectValue $run "pusher_machine_reached") -and
                    $runLabels -contains "coin_pusher_drop" -and
                    (Get-OpportunityCounter $run "pusher_machines" "accepted") -gt 0 -and
                    (Get-OpportunityCounter $run "pusher_machines" "settled") -gt 0) {
                    $hasQualifiedRun = $true; break
                }
            }
            if (-not $hasQualifiedRun) {
                $result.Add("coin_pusher_grinder has no reached cabinet with an accepted production drop.")
            }
        }
        "heist_rusher" {
			$observedPlans = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($run in $Runs) {
				$styleState = Get-ObjectValue $run "style_state"
				$planId = if ($null -ne $styleState) { [string](Get-ObjectValue $styleState "heist_plan_id") } else { "" }
				if ($planId) { [void]$observedPlans.Add($planId) }
                $runLabels = @(Get-LedgerLabels @($run))
                $hasProgress = @($runLabels | Where-Object {
					$_.StartsWith("heist_lock:", [StringComparison]::Ordinal) -or $_.StartsWith("heist_schedule", [StringComparison]::Ordinal) -or
                    $_.StartsWith("heist_swap_cart", [StringComparison]::Ordinal) -or
                    $_.StartsWith("heist_live_", [StringComparison]::Ordinal) -or
                    $_.StartsWith("heist_getaway", [StringComparison]::Ordinal)
                }).Count -gt 0
                if ((Get-OpportunityCounter $run "heists" "accepted") -gt 0 -and
                    (Get-OpportunityCounter $run "heists" "settled") -gt 0 -and $hasProgress) {
                    $hasQualifiedRun = $true; break
                }
            }
            if (-not $hasQualifiedRun) {
                $result.Add("heist_rusher has no production heist progress evidence.")
            }
			if ($Runs.Count -ge 8 -and (-not $observedPlans.Contains("the_count") -or -not $observedPlans.Contains("the_whale"))) {
				$result.Add("heist_rusher did not cover both production heist plans.")
			}
        }
    }
    return @($result)
}

function Get-Distribution([double[]]$Values) {
    if ($Values.Count -eq 0) { return [ordered]@{ n = 0 } }
    $sorted = @($Values | Sort-Object)
    $mean = ($sorted | Measure-Object -Average).Average
    $sumSquares = 0.0
    foreach ($value in $sorted) { $sumSquares += [math]::Pow($value - $mean, 2) }
    $sd = [math]::Sqrt($sumSquares / [math]::Max(1, $sorted.Count - 1))
    $margin = 1.96 * $sd / [math]::Sqrt($sorted.Count)
    function Percentile([double]$Fraction) {
        $position = $Fraction * ($sorted.Count - 1)
        $low = [math]::Floor($position)
        $high = [math]::Ceiling($position)
        if ($low -eq $high) { return $sorted[$low] }
        return $sorted[$low] + (($position - $low) * ($sorted[$high] - $sorted[$low]))
    }
    return [ordered]@{
        n = $sorted.Count; min = $sorted[0]; p05 = (Percentile 0.05)
        p25 = (Percentile 0.25); median = (Percentile 0.5); p75 = (Percentile 0.75)
        p95 = (Percentile 0.95); max = $sorted[-1]; mean = $mean
        sample_standard_deviation = $sd; mean_ci95_lower = $mean - $margin
        mean_ci95_upper = $mean + $margin
    }
}

if ($SelfTest) {
    $expected = [ordered]@{
        run_mode = "FINAL"; exact_head = "head-a"; exact_tree = "tree-a"; input_manifest_sha256 = "input-a"
        policy_blob = "policy-a"; plugin_identity_sha256 = "plugin-a"
        runtime_artifact_manifest_sha256 = "runtime-a"; report_schema = $reportSchema
        godot_console_sha256 = "console-a"; godot_worker_sha256 = "worker-a"
    }
    $mixed = [ordered]@{
        run_mode = "FINAL"; exact_head = "head-a"; exact_tree = "tree-a"; input_manifest_sha256 = "input-b"
        policy_blob = "policy-a"; plugin_identity_sha256 = "plugin-a"
        runtime_artifact_manifest_sha256 = "runtime-a"; report_schema = $reportSchema
        godot_console_sha256 = "console-a"; godot_worker_sha256 = "worker-a"
    }
    $mixedFailures = @(Get-IdentityFailures $mixed $expected "self-test")
    if ($mixedFailures.Count -eq 0 -or -not (($mixedFailures -join " ") -match "input_manifest_sha256")) {
        throw "Self-test failed: a mixed input manifest was accepted."
    }
    $changedEngine = [ordered]@{}
    foreach ($key in $expected.Keys) { $changedEngine[$key] = $expected[$key] }
    $changedEngine.godot_console_sha256 = "console-changed"
    $engineFailures = @(Get-IdentityFailures $changedEngine $expected "resume self-test")
    if ($engineFailures.Count -eq 0 -or -not (($engineFailures -join " ") -match "godot_console_sha256")) {
        throw "Self-test failed: a changed Godot console was accepted for resume."
    }
    $reducedFinalFailures = @(Get-RunModeFailures "FINAL" 1 8)
    if ($reducedFinalFailures.Count -ne 2 -or -not (($reducedFinalFailures -join " ") -match "exactly 64") -or -not (($reducedFinalFailures -join " ") -match "exactly 208")) {
        throw "Self-test failed: reduced FINAL counts were accepted."
    }
    if (@(Get-RunModeFailures "DIAGNOSTIC" 1 8).Count -ne 0) {
        throw "Self-test failed: explicitly diagnostic reduced counts were rejected."
    }
    $diagnosticArtifacts = Get-RunArtifactContract "DIAGNOSTIC" $true
    if ($diagnosticArtifacts.qualifies_for_final -or $diagnosticArtifacts.manifest_name -ceq "custody_manifest.json" -or $diagnosticArtifacts.manifest_schema -match "custody") {
        throw "Self-test failed: a reduced diagnostic could emit FINAL custody."
    }
    $zeroOpportunity = [ordered]@{ accepted = 0; settled = 0 }
    $zeroRun = [pscustomobject]@{
        pusher_machine_reached = $false
        ledger = @()
        opportunities = [pscustomobject]@{ pusher_machines = [pscustomobject]$zeroOpportunity }
    }
    $coverageFailures = @(Get-SpecialistCoverageFailures "coin_pusher_grinder" @($zeroRun))
    if ($coverageFailures.Count -eq 0) { throw "Self-test failed: zero specialist evidence was accepted." }
    $qualifiedRun = [pscustomobject]@{
        pusher_machine_reached = $true
        ledger = @([pscustomobject]@{ label = "coin_pusher_drop" })
        opportunities = [pscustomobject]@{ pusher_machines = [pscustomobject]@{ accepted = 1; settled = 1 } }
    }
    if (@(Get-SpecialistCoverageFailures "coin_pusher_grinder" @($qualifiedRun)).Count -ne 0) {
        throw "Self-test failed: complete specialist evidence was rejected."
    }
    Write-Host "CROSS_ECONOMY_SHARDS_SELF_TEST_PASS mixed_manifest_rejected=true changed_engine_resume_rejected=true reduced_final_rejected=true diagnostic_counts_separate=true zero_specialist_rejected=true"
    exit 0
}

$runModeFailures = @(Get-RunModeFailures $RunMode $SeedsPerPlaystyle $MaxActions)
if ($runModeFailures.Count -ne 0) { throw ($runModeFailures -join " | ") }
if ($RunMode -eq "DIAGNOSTIC" -and -not $PSBoundParameters.ContainsKey("SeedPrefix")) {
    $SeedPrefix = "BALANCE06-1-DIAGNOSTIC"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $RuntimeSourceRoot) { $RuntimeSourceRoot = $projectRoot }
$RuntimeSourceRoot = [IO.Path]::GetFullPath($RuntimeSourceRoot)
if (-not (Test-Path -LiteralPath $RuntimeSourceRoot -PathType Container)) {
    throw "RuntimeSourceRoot does not exist: $RuntimeSourceRoot"
}
if (-not $OutDir) {
    $OutDir = Join-Path $projectRoot ".tmp\balance06_1_follow_on\distribution_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
}
$OutDir = [IO.Path]::GetFullPath($OutDir)
if ($ResumeFrom) {
    $ResumeFrom = [IO.Path]::GetFullPath($ResumeFrom)
    if (-not (Test-Path -LiteralPath $ResumeFrom -PathType Container)) { throw "ResumeFrom does not exist: $ResumeFrom" }
    if ($ResumeFrom -ceq $OutDir) { throw "ResumeFrom and OutDir must differ so prior evidence is never overwritten." }
}
$startedAt = Get-Date
$startedAtUtc = $startedAt.ToUniversalTime().ToString("o")
$resumeArgument = if ($ResumeFrom) { " -ResumeFrom '$ResumeFrom'" } else { "" }
$invocationCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File tools/cross_economy_audit_shards.ps1 -RunMode $RunMode -SeedsPerPlaystyle $SeedsPerPlaystyle -MaxActions $MaxActions -WorkerCount $WorkerCount -SeedPrefix '$SeedPrefix' -RuntimeSourceRoot '$RuntimeSourceRoot' -OutDir '$OutDir'$resumeArgument"
$rootPrefix = [IO.Path]::GetFullPath($projectRoot)
if (-not $rootPrefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $rootPrefix += [IO.Path]::DirectorySeparatorChar }
if (-not $OutDir.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutDir must remain inside the project worktree."
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
if (Get-ChildItem -LiteralPath $OutDir -Force | Select-Object -First 1) {
    throw "OutDir must be new and empty; evidence is never overwritten."
}

$dirty = @(git -C $projectRoot status --porcelain --untracked-files=no)
if ($dirty.Count -ne 0) { throw "Tracked tree must be clean before freezing a distribution." }
$head = (git -C $projectRoot rev-parse HEAD).Trim()
$tree = (git -C $projectRoot rev-parse "HEAD^{tree}").Trim()
$godot = $env:GODOT_BIN
if (-not $godot) { $godot = "D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe" }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot console executable not found: $godot" }
$godot = [IO.Path]::GetFullPath($godot)
$godotWorker = [IO.Path]::GetFullPath($godot)
if ($godotWorker.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
    $godotWorker = $godotWorker.Substring(0, $godotWorker.Length - "_console.exe".Length) + ".exe"
}
if (-not (Test-Path -LiteralPath $godotWorker -PathType Leaf)) { throw "Godot worker executable not found: $godotWorker" }
$godotConsoleSha = (Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant()
$godotWorkerSha = (Get-FileHash -LiteralPath $godotWorker -Algorithm SHA256).Hash.ToLowerInvariant()

# Freeze the exact commit once. Every worker gets an independently expanded
# copy; no tracked source path is linked back to the mutable caller worktree.
$archivePath = Join-Path $OutDir "frozen_source_$head.zip"
$archivePathspec = @("project.godot", "icon.svg", "tools", "scripts", "scenes", "data", "assets", "branding", "native")
& git -C $projectRoot archive --format=zip --output=$archivePath $head -- @archivePathspec
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archivePath -PathType Leaf)) { throw "Could not archive frozen commit $head." }
$archiveSha = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$snapshotRoot = Join-Path $OutDir "frozen_source_manifest_root"
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
& tar.exe -xf $archivePath -C $snapshotRoot
if ($LASTEXITCODE -ne 0) { throw "Could not expand frozen source manifest archive." }

$gitEntries = [Collections.Generic.List[object]]::new()
$trackedByPath = @{}
foreach ($line in @(git -C $projectRoot -c core.quotepath=false ls-tree -r --full-tree $head -- @archivePathspec)) {
    if ($line -notmatch '^(?<mode>[0-9]+) (?<type>[^ ]+) (?<blob>[0-9a-f]+)\t(?<path>.+)$') { throw "Could not parse git tree entry: $line" }
    if ($Matches.type -ne "blob") { throw "Unsupported non-blob tracked entry: $($Matches.path)" }
    $path = $Matches.path.Replace("\", "/")
    $absolute = Join-Path $snapshotRoot $path.Replace("/", "\")
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) { throw "Frozen archive omitted tracked input: $path" }
    $entry = [ordered]@{
        path = $path; mode = $Matches.mode; git_blob = $Matches.blob
        bytes = (Get-Item -LiteralPath $absolute).Length
        sha256 = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $gitEntries.Add($entry)
    $trackedByPath[$path] = $entry
}

$requiredExact = @(
    "tools/cross_economy_audit.gd", "tools/cross_economy_audit.ps1",
    "tools/cross_economy_audit_shards.ps1", "tools/cross_economy_audit_shard_worker.ps1",
    "tools/endgame_metrics_probe.gd", "scripts/core/run_state.gd", "scripts/core/rng_stream.gd",
    "scripts/core/world_map.gd", "scripts/core/environment_instance.gd"
)
foreach ($path in $requiredExact) { if (-not $trackedByPath.ContainsKey($path)) { throw "Comprehensive input manifest is missing required input: $path" } }
foreach ($prefix in @("scripts/core/", "scripts/games/", "data/games/", "data/crew/", "data/environments/", "data/environments/scenario_sequences/", "data/town/", "data/travel/", "native/coin_pusher/")) {
    if (@($gitEntries | Where-Object { [string]$_.path -like "$prefix*" }).Count -eq 0) { throw "Comprehensive input manifest is missing required group: $prefix" }
}

$inputCanonical = (@($gitEntries | Sort-Object path | ForEach-Object { "$($_.path)|$($_.mode)|$($_.git_blob)|$($_.bytes)|$($_.sha256)" }) -join "`n")
$inputHash = Get-Sha256Text $inputCanonical
$trackedManifest = [ordered]@{
    schema = "balance06_1_tracked_input_manifest_v2"; exact_head = $head; exact_tree = $tree
    canonical_sha256 = $inputHash; entry_count = $gitEntries.Count; entries = @($gitEntries)
}
$trackedManifestPath = Join-Path $OutDir "tracked_input_manifest.json"
Write-JsonFile $trackedManifest $trackedManifestPath 8
$trackedManifestFileSha = (Get-FileHash -LiteralPath $trackedManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$policyBlob = [string]$trackedByPath["tools/cross_economy_audit.gd"].git_blob

# Capture only generated import/cache artifacts needed by the frozen source.
# Their target paths, byte counts, and hashes are sealed before workers start.
$runtimeSourceByTarget = @{}
function Add-RuntimeSource([string]$TargetPath, [string]$SourcePath) {
    $normalized = $TargetPath.Replace("\", "/")
    if (-not $runtimeSourceByTarget.ContainsKey($normalized)) { $runtimeSourceByTarget[$normalized] = $SourcePath }
}
function Add-ExtensionRuntime([string]$DescriptorTarget, [string]$DescriptorSource) {
    $normalizedDescriptor = $DescriptorTarget.Replace("\", "/")
    if (-not (Test-Path -LiteralPath $DescriptorSource -PathType Leaf)) {
        throw "Native extension descriptor is missing: $normalizedDescriptor"
    }
    if (-not $trackedByPath.ContainsKey($normalizedDescriptor)) {
        Add-RuntimeSource $normalizedDescriptor $DescriptorSource
    }
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $DescriptorSource -Raw), 'res://([^"\r\n]+\.(?:dll|so|dylib|wasm))')) {
        $target = $match.Groups[1].Value.Replace("\", "/")
        if (-not $trackedByPath.ContainsKey($target)) {
            $source = Join-Path $RuntimeSourceRoot $target.Replace("/", "\")
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
                # A generated descriptor lists every export platform. This
                # Windows qualification requires its Windows DLLs; Web/Unix
                # artifacts may correctly be absent from the local toolchain.
                if ($target.EndsWith(".dll", [StringComparison]::OrdinalIgnoreCase)) {
                    throw "Native extension binary is missing: $target"
                }
                continue
            }
            Add-RuntimeSource $target $source
        }
    }
}
$assetRoot = Join-Path $RuntimeSourceRoot "assets"
if (Test-Path -LiteralPath $assetRoot -PathType Container) {
    foreach ($manifest in Get-ChildItem -LiteralPath $assetRoot -Recurse -Filter "*.import" -File) {
        $relativeManifest = $manifest.FullName.Substring($RuntimeSourceRoot.Length).TrimStart("\", "/").Replace("\", "/")
        $manifestText = Get-Content -LiteralPath $manifest.FullName -Raw
        $generatedArtifacts = [Collections.Generic.List[object]]::new()
        $completeImport = $true
        foreach ($match in [regex]::Matches($manifestText, 'res://\.godot/imported/([^"\r\n]+)')) {
            $artifactName = $match.Groups[1].Value
            $artifactSource = Join-Path $RuntimeSourceRoot ".godot\imported\$artifactName"
            if (-not (Test-Path -LiteralPath $artifactSource -PathType Leaf)) {
                # A mutable development cache can contain a stale .import
                # manifest after its generated artifact was cleaned. Do not
                # freeze half of that pair; the isolated worker will rebuild it
                # from the exact tracked source instead.
                $completeImport = $false
                break
            }
            $generatedArtifacts.Add([ordered]@{ target = ".godot/imported/$artifactName"; source = $artifactSource })
            $md5Source = [IO.Path]::ChangeExtension($artifactSource, ".md5")
            if (Test-Path -LiteralPath $md5Source -PathType Leaf) {
                $generatedArtifacts.Add([ordered]@{ target = ".godot/imported/$([IO.Path]::GetFileName($md5Source))"; source = $md5Source })
            }
        }
        if ($completeImport) {
            if (-not $trackedByPath.ContainsKey($relativeManifest)) { Add-RuntimeSource $relativeManifest $manifest.FullName }
            foreach ($artifact in $generatedArtifacts) { Add-RuntimeSource $artifact.target $artifact.source }
        }
    }
}
foreach ($cacheFile in @("global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg")) {
    $cacheSource = Join-Path $RuntimeSourceRoot ".godot\$cacheFile"
    if (Test-Path -LiteralPath $cacheSource -PathType Leaf) { Add-RuntimeSource ".godot/$cacheFile" $cacheSource }
}
# Generated extension descriptors are intentionally ignored by Git, but the
# frozen workers must load the same native backend as the source worktree.
$extensionListSource = Join-Path $RuntimeSourceRoot ".godot\extension_list.cfg"
if (Test-Path -LiteralPath $extensionListSource -PathType Leaf) {
    foreach ($extensionLine in @(Get-Content -LiteralPath $extensionListSource)) {
        $descriptorTarget = $extensionLine.Trim()
        if (-not $descriptorTarget) { continue }
        if (-not $descriptorTarget.StartsWith("res://", [StringComparison]::Ordinal)) {
            throw "Unsupported native extension path in extension_list.cfg: $descriptorTarget"
        }
        $descriptorTarget = $descriptorTarget.Substring("res://".Length).Replace("\", "/")
        Add-ExtensionRuntime $descriptorTarget (Join-Path $RuntimeSourceRoot $descriptorTarget.Replace("/", "\"))
    }
}
foreach ($extension in Get-ChildItem -LiteralPath $snapshotRoot -Recurse -Filter "*.gdextension" -File) {
    $descriptorTarget = $extension.FullName.Substring($snapshotRoot.Length).TrimStart("\", "/").Replace("\", "/")
    Add-ExtensionRuntime $descriptorTarget $extension.FullName
}

$runtimeFreezeRoot = Join-Path $OutDir "frozen_runtime_artifacts"
New-Item -ItemType Directory -Path $runtimeFreezeRoot -Force | Out-Null
$runtimeEntries = [Collections.Generic.List[object]]::new()
foreach ($target in @($runtimeSourceByTarget.Keys | Sort-Object)) {
    $source = $runtimeSourceByTarget[$target]
    $destination = Join-Path $runtimeFreezeRoot $target.Replace("/", "\")
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $runtimeEntries.Add([ordered]@{
        path = $target; bytes = (Get-Item -LiteralPath $destination).Length
        sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}
$runtimeCanonical = (@($runtimeEntries | ForEach-Object { "$($_.path)|$($_.bytes)|$($_.sha256)" }) -join "`n")
$runtimeHash = Get-Sha256Text $runtimeCanonical
$runtimeManifest = [ordered]@{
    schema = "balance06_1_runtime_artifact_manifest_v2"; canonical_sha256 = $runtimeHash
    entry_count = $runtimeEntries.Count; entries = @($runtimeEntries)
}
$nativeDescriptorEntries = @($runtimeEntries | Where-Object { [string]$_.path -like "addons/coin_pusher_native/*.gdextension" })
$nativeWindowsEntries = @($runtimeEntries | Where-Object { [string]$_.path -like "addons/coin_pusher_native/bin/*.dll" })
if ($nativeDescriptorEntries.Count -ne 1 -or $nativeWindowsEntries.Count -lt 1) {
    throw "Frozen audit runtime must contain the registered Coin Pusher extension descriptor and at least one Windows library."
}
$runtimeManifestPath = Join-Path $OutDir "runtime_artifact_manifest.json"
Write-JsonFile $runtimeManifest $runtimeManifestPath 8
$runtimeManifestFileSha = (Get-FileHash -LiteralPath $runtimeManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

$pluginLines = [Collections.Generic.List[string]]::new()
foreach ($entry in @($gitEntries | Where-Object { [string]$_.path -like "native/coin_pusher/*" } | Sort-Object path)) {
    $pluginLines.Add("tracked|$($entry.path)|$($entry.git_blob)|$($entry.sha256)")
}
foreach ($entry in @($runtimeEntries | Where-Object { [string]$_.path -match '\.(dll|so|dylib)$' } | Sort-Object path)) {
    $pluginLines.Add("runtime|$($entry.path)|$($entry.sha256)")
}
if ($pluginLines.Count -eq 0) { throw "Native plugin identity contains no tracked source or runtime binary." }
$pluginHash = Get-Sha256Text (@($pluginLines) -join "`n")

$identity = [ordered]@{
    schema = $identitySchema; run_mode = $RunMode; exact_head = $head; exact_tree = $tree
    input_manifest_sha256 = $inputHash; tracked_manifest_file_sha256 = $trackedManifestFileSha
    policy_blob = $policyBlob; plugin_identity_sha256 = $pluginHash; plugin_material = @($pluginLines)
    runtime_artifact_manifest_sha256 = $runtimeHash; runtime_manifest_file_sha256 = $runtimeManifestFileSha
    report_schema = $reportSchema; frozen_archive_sha256 = $archiveSha
    godot_console_sha256 = $godotConsoleSha; godot_worker_sha256 = $godotWorkerSha
}
$identityManifestPath = Join-Path $OutDir "shard_identity_manifest.json"
Write-JsonFile $identity $identityManifestPath 8
$identityManifestSha = (Get-FileHash -LiteralPath $identityManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

$jobs = [Collections.Generic.List[object]]::new()
$shardProjectsRoot = Join-Path $OutDir "w"
New-Item -ItemType Directory -Path $shardProjectsRoot -Force | Out-Null
foreach ($style in $styles) {
    $privateRoot = Join-Path $shardProjectsRoot $style
    New-Item -ItemType Directory -Path $privateRoot | Out-Null
    & tar.exe -xf $archivePath -C $privateRoot
    if ($LASTEXITCODE -ne 0) { throw "Could not expand frozen source for $style." }
    foreach ($entry in $runtimeEntries) {
        $relative = [string]$entry.path
        $source = Join-Path $runtimeFreezeRoot $relative.Replace("/", "\")
        $destination = Join-Path $privateRoot $relative.Replace("/", "\")
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
    $custodyRoot = Join-Path $privateRoot ".custody"
    New-Item -ItemType Directory -Path $custodyRoot -Force | Out-Null
    $privateTrackedManifest = Join-Path $custodyRoot "tracked_input_manifest.json"
    $privateRuntimeManifest = Join-Path $custodyRoot "runtime_artifact_manifest.json"
    $privateIdentityManifest = Join-Path $custodyRoot "shard_identity_manifest.json"
    Copy-Item -LiteralPath $trackedManifestPath -Destination $privateTrackedManifest
    Copy-Item -LiteralPath $runtimeManifestPath -Destination $privateRuntimeManifest
    Copy-Item -LiteralPath $identityManifestPath -Destination $privateIdentityManifest
    $jobs.Add([pscustomobject]@{
        Style = $style; ProjectRoot = $privateRoot
        Json = Join-Path $privateRoot "$style.json"; ExitRecord = Join-Path $privateRoot "$style.exit.json"
        TrackedManifest = $privateTrackedManifest; RuntimeManifest = $privateRuntimeManifest; IdentityManifest = $privateIdentityManifest
        Stdout = Join-Path $OutDir "$style.stdout.txt"; Stderr = Join-Path $OutDir "$style.stderr.txt"
        Process = $null; ProcessExitCode = $null; DurationSec = 0.0; Started = $null
        Reused = $false; ResumeSource = ""
    })
}

# Resume into a new custody directory only. A prior successful shard is copied
# only when its complete identity and report hash bind to this exact freeze;
# missing or previously failed shards are run normally below.
$resumedStyles = [Collections.Generic.List[string]]::new()
if ($ResumeFrom) {
    $priorIdentityPath = Join-Path $ResumeFrom "shard_identity_manifest.json"
    if (-not (Test-Path -LiteralPath $priorIdentityPath -PathType Leaf)) { throw "Resume source has no shard identity manifest: $priorIdentityPath" }
    try { $priorIdentity = Get-Content -LiteralPath $priorIdentityPath -Raw | ConvertFrom-Json }
    catch { throw "Resume source identity manifest is malformed: $($_.Exception.Message)" }
    $identityFailures = @(Get-IdentityFailures $priorIdentity ([pscustomobject]$identity) "resume source")
    if ($identityFailures.Count -ne 0 -or (Get-FileHash -LiteralPath $priorIdentityPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $identityManifestSha) {
        throw "Resume source does not match the exact frozen identity: $($identityFailures -join ' | ')"
    }
    foreach ($job in $jobs) {
        $priorProjectRoot = Join-Path (Join-Path $ResumeFrom "w") $job.Style
        $priorJson = Join-Path $priorProjectRoot "$($job.Style).json"
        $priorExit = Join-Path $priorProjectRoot "$($job.Style).exit.json"
        if (-not (Test-Path -LiteralPath $priorJson -PathType Leaf) -or -not (Test-Path -LiteralPath $priorExit -PathType Leaf)) { continue }
        try { $priorExitRecord = Get-Content -LiteralPath $priorExit -Raw | ConvertFrom-Json }
        catch { throw "Resume shard exit record is malformed for $($job.Style): $($_.Exception.Message)" }
        $resumeFailures = @(Get-IdentityFailures $priorExitRecord ([pscustomobject]$identity) "resume $($job.Style)")
        $priorReportSha = (Get-FileHash -LiteralPath $priorJson -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($resumeFailures.Count -ne 0 -or [string](Get-ObjectValue $priorExitRecord "schema") -cne $exitSchema -or
            [int](Get-ObjectValue $priorExitRecord "exit_code") -ne 0 -or [string](Get-ObjectValue $priorExitRecord "playstyle") -cne $job.Style -or
            [string](Get-ObjectValue $priorExitRecord "seed_prefix") -cne $SeedPrefix -or [int](Get-ObjectValue $priorExitRecord "seed_start") -ne 1 -or
            [int](Get-ObjectValue $priorExitRecord "seed_count") -ne $SeedsPerPlaystyle -or [int](Get-ObjectValue $priorExitRecord "max_actions") -ne $MaxActions -or
            [string](Get-ObjectValue $priorExitRecord "identity_manifest_sha256") -cne $identityManifestSha -or
            [string](Get-ObjectValue $priorExitRecord "report_sha256") -cne $priorReportSha -or @(Get-ObjectValue $priorExitRecord "validation_failures").Count -ne 0) {
            throw "Resume shard failed exact identity/run/hash validation: $($job.Style)"
        }
        Copy-Item -LiteralPath $priorJson -Destination $job.Json
        Copy-Item -LiteralPath $priorExit -Destination $job.ExitRecord
        foreach ($pair in @(@((Join-Path $ResumeFrom "$($job.Style).stdout.txt"), $job.Stdout), @((Join-Path $ResumeFrom "$($job.Style).stderr.txt"), $job.Stderr))) {
            if (Test-Path -LiteralPath $pair[0] -PathType Leaf) { Copy-Item -LiteralPath $pair[0] -Destination $pair[1] }
        }
        $job.ProcessExitCode = 0; $job.Reused = $true; $job.ResumeSource = $priorJson
        $resumedStyles.Add($job.Style)
    }
}

$pending = [Collections.Generic.Queue[object]]::new()
foreach ($job in $jobs) { if (-not $job.Reused) { $pending.Enqueue($job) } }
$running = [Collections.Generic.List[object]]::new()
while ($pending.Count -gt 0 -or $running.Count -gt 0) {
    for ($index = $running.Count - 1; $index -ge 0; $index--) {
        $job = $running[$index]
        if ($job.Process.HasExited) {
            $job.Process.WaitForExit(); $job.Process.Refresh()
            $job.ProcessExitCode = [int]$job.Process.ExitCode
            $job.DurationSec = ((Get-Date) - $job.Started).TotalSeconds
            $job.Process.Dispose(); $running.RemoveAt($index)
            Write-Host "BALANCE_SHARD_DONE style=$($job.Style) exit=$($job.ProcessExitCode) duration_sec=$([math]::Round($job.DurationSec, 3))"
        }
    }
    while ($pending.Count -gt 0 -and $running.Count -lt $WorkerCount) {
        $job = $pending.Dequeue()
        $args = @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $job.ProjectRoot "tools\cross_economy_audit_shard_worker.ps1"),
            "-SeedsPerPlaystyle", "$SeedsPerPlaystyle", "-SeedStart", "1", "-MaxActions", "$MaxActions",
            "-SeedPrefix", $SeedPrefix, "-Playstyle", $job.Style, "-BuildRef", $head,
            "-Output", "res://$($job.Style).json", "-ExitRecord", $job.ExitRecord,
            "-IdentityManifest", $job.IdentityManifest, "-IdentityManifestSha256", $identityManifestSha,
            "-TrackedManifest", $job.TrackedManifest, "-RuntimeManifest", $job.RuntimeManifest,
            "-ExpectedRunMode", $RunMode, "-ExpectedHead", $head, "-ExpectedTree", $tree, "-ExpectedInputManifestSha256", $inputHash,
            "-ExpectedPolicyBlob", $policyBlob, "-ExpectedPluginIdentitySha256", $pluginHash,
            "-ExpectedRuntimeManifestSha256", $runtimeHash, "-ExpectedReportSchema", $reportSchema,
            "-GodotConsolePath", $godot, "-ExpectedGodotConsoleSha256", $godotConsoleSha,
            "-GodotWorkerPath", $godotWorker, "-ExpectedGodotWorkerSha256", $godotWorkerSha
        )
        $job.Started = Get-Date
        $job.Process = Start-Process -FilePath (Get-Command powershell.exe).Source -ArgumentList $args -WorkingDirectory $job.ProjectRoot -WindowStyle Hidden -RedirectStandardOutput $job.Stdout -RedirectStandardError $job.Stderr -PassThru
        $running.Add($job)
        Write-Host "BALANCE_SHARD_START style=$($job.Style)"
    }
    if ($running.Count -gt 0) { Start-Sleep -Milliseconds 500 }
}

$failures = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
$allRuns = [Collections.Generic.List[object]]::new()
$shardIndex = [Collections.Generic.List[object]]::new()
$styleSummaries = [ordered]@{}
$expectedIdentity = [pscustomobject]$identity

if ((git -C $projectRoot rev-parse HEAD).Trim() -cne $head -or (git -C $projectRoot rev-parse "HEAD^{tree}").Trim() -cne $tree) {
    $failures.Add("Caller source identity changed while shards were running.")
}
if (@(git -C $projectRoot status --porcelain --untracked-files=no).Count -ne 0) { $failures.Add("Caller tracked worktree changed while shards were running.") }
if (-not (Test-Path -LiteralPath $godot -PathType Leaf) -or (Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant() -cne $godotConsoleSha) { $failures.Add("Configured Godot console changed while shards were running.") }
if (-not (Test-Path -LiteralPath $godotWorker -PathType Leaf) -or (Get-FileHash -LiteralPath $godotWorker -Algorithm SHA256).Hash.ToLowerInvariant() -cne $godotWorkerSha) { $failures.Add("Configured Godot worker changed while shards were running.") }
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $archiveSha) { $failures.Add("Frozen source archive changed while shards were running.") }
Add-ManifestFailures "frozen tracked source" $snapshotRoot $trackedManifestPath $failures
Add-ManifestFailures "frozen runtime artifact" $runtimeFreezeRoot $runtimeManifestPath $failures
if ((Get-FileHash -LiteralPath $trackedManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $trackedManifestFileSha) { $failures.Add("Tracked input manifest file changed while shards were running.") }
if ((Get-FileHash -LiteralPath $runtimeManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $runtimeManifestFileSha) { $failures.Add("Runtime artifact manifest file changed while shards were running.") }
if ((Get-FileHash -LiteralPath $identityManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $identityManifestSha) { $failures.Add("Shard identity manifest file changed while shards were running.") }

foreach ($job in $jobs) {
    Add-ManifestFailures "$($job.Style) tracked source (orchestrator post-run)" $job.ProjectRoot $job.TrackedManifest $failures
    Add-ManifestFailures "$($job.Style) runtime artifact (orchestrator post-run)" $job.ProjectRoot $job.RuntimeManifest $failures
    if (-not (Test-Path -LiteralPath $job.TrackedManifest -PathType Leaf) -or (Get-FileHash -LiteralPath $job.TrackedManifest -Algorithm SHA256).Hash.ToLowerInvariant() -cne $trackedManifestFileSha) { $failures.Add("$($job.Style) tracked manifest file mismatch.") }
    if (-not (Test-Path -LiteralPath $job.RuntimeManifest -PathType Leaf) -or (Get-FileHash -LiteralPath $job.RuntimeManifest -Algorithm SHA256).Hash.ToLowerInvariant() -cne $runtimeManifestFileSha) { $failures.Add("$($job.Style) runtime manifest file mismatch.") }
    if (-not (Test-Path -LiteralPath $job.IdentityManifest -PathType Leaf) -or (Get-FileHash -LiteralPath $job.IdentityManifest -Algorithm SHA256).Hash.ToLowerInvariant() -cne $identityManifestSha) { $failures.Add("$($job.Style) identity manifest file mismatch.") }
    if ($job.ProcessExitCode -ne 0) { $failures.Add("Shard process failed: $($job.Style) exit=$($job.ProcessExitCode).") }
    if (Test-Path -LiteralPath $job.Stderr -PathType Leaf) {
        $stderrText = Get-Content -LiteralPath $job.Stderr -Raw
        if ($stderrText -match 'Error loading GDExtension|GDExtension dynamic library not found|Error loading extension') {
            $failures.Add("Shard did not load the frozen native extension: $($job.Style).")
        }
    }
    $exitRecord = $null
    if (-not (Test-Path -LiteralPath $job.ExitRecord -PathType Leaf)) { $failures.Add("Missing shard exit record: $($job.Style).") }
    else {
        try { $exitRecord = Get-Content -LiteralPath $job.ExitRecord -Raw | ConvertFrom-Json }
        catch { $failures.Add("Invalid shard exit record for $($job.Style): $($_.Exception.Message)") }
    }
    if ($null -ne $exitRecord) {
        if ([string](Get-ObjectValue $exitRecord "schema") -cne $exitSchema) { $failures.Add("Shard exit schema mismatch: $($job.Style).") }
        foreach ($failure in @(Get-IdentityFailures $exitRecord $expectedIdentity "$($job.Style) exit")) { $failures.Add($failure) }
        if ([int](Get-ObjectValue $exitRecord "exit_code") -ne $job.ProcessExitCode) { $failures.Add("Shard process/record exit mismatch: $($job.Style).") }
        if ([string](Get-ObjectValue $exitRecord "playstyle") -cne $job.Style -or [string](Get-ObjectValue $exitRecord "seed_prefix") -cne $SeedPrefix -or
            [int](Get-ObjectValue $exitRecord "seed_start") -ne 1 -or [int](Get-ObjectValue $exitRecord "seed_count") -ne $SeedsPerPlaystyle -or
            [int](Get-ObjectValue $exitRecord "max_actions") -ne $MaxActions -or [string](Get-ObjectValue $exitRecord "identity_manifest_sha256") -cne $identityManifestSha -or
            [string](Get-ObjectValue $exitRecord "tracked_manifest_file_sha256") -cne $trackedManifestFileSha -or
            [string](Get-ObjectValue $exitRecord "runtime_manifest_file_sha256") -cne $runtimeManifestFileSha) {
            $failures.Add("Shard exit run contract mismatch: $($job.Style).")
        }
        foreach ($failure in @(Get-ObjectValue $exitRecord "validation_failures")) { if ($failure) { $failures.Add("$($job.Style) worker: $failure") } }
    }

    if (-not (Test-Path -LiteralPath $job.Json -PathType Leaf)) {
        $failures.Add("Missing shard report: $($job.Style).")
        continue
    }
    try { $report = Get-Content -LiteralPath $job.Json -Raw | ConvertFrom-Json }
    catch {
        $failures.Add("Invalid shard report for $($job.Style): $($_.Exception.Message)")
        continue
    }
    $reportSha = (Get-FileHash -LiteralPath $job.Json -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($null -ne $exitRecord -and [string](Get-ObjectValue $exitRecord "report_sha256") -cne $reportSha) { $failures.Add("Shard report/exit hash mismatch: $($job.Style).") }
    if ([string](Get-ObjectValue $report "tool") -cne $reportSchema -or [string](Get-ObjectValue $report "build_ref") -cne $head -or
        [string](Get-ObjectValue $report "playstyle_filter") -cne $job.Style -or [string](Get-ObjectValue $report "seed_prefix") -cne $SeedPrefix -or
        [int](Get-ObjectValue $report "seed_start") -ne 1 -or [int](Get-ObjectValue $report "seeds_per_playstyle") -ne $SeedsPerPlaystyle -or
        [int](Get-ObjectValue $report "max_actions") -ne $MaxActions -or [int](Get-ObjectValue $report "run_count") -ne $SeedsPerPlaystyle) {
        $failures.Add("Shard report provenance/style/seed/count mismatch: $($job.Style).")
    }
    if (-not [bool](Get-ObjectValue $report "passed")) { $failures.Add("Shard report did not pass: $($job.Style).") }
    foreach ($failure in @(Get-ObjectValue $report "failures")) { if ($failure) { $failures.Add("$($job.Style) report: $failure") } }
    foreach ($warning in @(Get-ObjectValue $report "warnings")) { if ($warning) { $warnings.Add("$($job.Style) report: $warning"); $failures.Add("$($job.Style) emitted a warning: $warning") } }

    $runs = @((Get-ObjectValue $report "runs") | Where-Object { $null -ne $_ })
    $expectedShardSeeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    for ($i = 1; $i -le $SeedsPerPlaystyle; $i++) { [void]$expectedShardSeeds.Add("$SeedPrefix-$($job.Style)-$('{0:D3}' -f $i)") }
    $actualShardSeeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($run in $runs) {
        $allRuns.Add($run)
        if ([string](Get-ObjectValue $run "playstyle") -cne $job.Style) { $failures.Add("Per-run playstyle mismatch in $($job.Style).") }
        $seed = [string](Get-ObjectValue $run "seed")
        if (-not $actualShardSeeds.Add($seed)) { $failures.Add("Duplicate run seed in $($job.Style): $seed") }
    }
    if ($runs.Count -ne $SeedsPerPlaystyle -or -not $actualShardSeeds.SetEquals($expectedShardSeeds)) { $failures.Add("Per-run seed/count coverage mismatch: $($job.Style).") }
    foreach ($failure in @(Get-SpecialistCoverageFailures $job.Style $runs)) { $failures.Add($failure) }
    $aggregate = Get-ObjectValue $report "aggregate"
    $aggregatePlaystyles = @(Get-ObjectValue $aggregate "playstyles")
    if ($aggregatePlaystyles.Count -ne 1 -or [string](Get-ObjectValue $aggregatePlaystyles[0] "playstyle") -cne $job.Style) {
        $failures.Add("Shard aggregate style mismatch: $($job.Style).")
    } else { $styleSummaries[$job.Style] = $aggregatePlaystyles[0] }
    $shardIndex.Add([ordered]@{
        style = $job.Style; seed_start = 1; seed_count = $SeedsPerPlaystyle
        process_exit_code = $job.ProcessExitCode; duration_sec = $job.DurationSec
        reused = $job.Reused; resume_source = $job.ResumeSource
        bytes = (Get-Item -LiteralPath $job.Json).Length; sha256 = $reportSha
        path = $job.Json; exit_record = $job.ExitRecord
        run_mode = $RunMode; exact_head = $head; exact_tree = $tree; input_manifest_sha256 = $inputHash
        policy_blob = $policyBlob; plugin_identity_sha256 = $pluginHash
        runtime_artifact_manifest_sha256 = $runtimeHash; report_schema = $reportSchema
        godot_console_sha256 = $godotConsoleSha; godot_worker_sha256 = $godotWorkerSha
    })
}

$expectedSeeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($style in $styles) { for ($i = 1; $i -le $SeedsPerPlaystyle; $i++) { [void]$expectedSeeds.Add("$SeedPrefix-$style-$('{0:D3}' -f $i)") } }
$actualSeeds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($run in $allRuns) { if (-not $actualSeeds.Add([string](Get-ObjectValue $run "seed"))) { $failures.Add("Duplicate aggregate run seed: $([string](Get-ObjectValue $run 'seed'))") } }
if (-not $actualSeeds.SetEquals($expectedSeeds)) { $failures.Add("Aggregate distribution seed coverage has a gap or unexpected seed.") }

$numericKeys = @("final_bankroll", "liquid_cash", "inventory_value", "debt_balance", "debt_principal", "debt_interest", "net_position", "actions", "final_heat", "peak_heat", "peak_debt", "bankroll_reconciliation_delta")
$overall = [ordered]@{}
foreach ($key in $numericKeys) { $overall[$key] = Get-Distribution @($allRuns | ForEach-Object { [double](Get-ObjectValue $_ $key) }) }
$terminalCauses = [ordered]@{}
$victoryRoutes = [ordered]@{}
$opportunities = [ordered]@{}
foreach ($run in $allRuns) {
    $cause = if ([bool](Get-ObjectValue $run "censored")) { [string](Get-ObjectValue $run "stopped_reason") } elseif ([bool](Get-ObjectValue $run "won")) { "victory" } elseif ([string](Get-ObjectValue $run "failure_reason")) { [string](Get-ObjectValue $run "failure_reason") } else { "terminal_other" }
    $terminalCauses[$cause] = [int]$terminalCauses[$cause] + 1
    $routeValue = [string](Get-ObjectValue $run "victory_route")
    $route = if ($routeValue) { $routeValue } else { "none" }
    $victoryRoutes[$route] = [int]$victoryRoutes[$route] + 1
    $runOpportunities = Get-ObjectValue $run "opportunities"
    if ($null -eq $runOpportunities) { continue }
    foreach ($systemProperty in $runOpportunities.PSObject.Properties) {
        if (-not $opportunities.Contains($systemProperty.Name)) { $opportunities[$systemProperty.Name] = [ordered]@{} }
        foreach ($counterProperty in $systemProperty.Value.PSObject.Properties) {
            $opportunities[$systemProperty.Name][$counterProperty.Name] = [int]$opportunities[$systemProperty.Name][$counterProperty.Name] + [int]$counterProperty.Value
        }
    }
}

$passed = $failures.Count -eq 0
$completedAt = Get-Date
$completedAtUtc = $completedAt.ToUniversalTime().ToString("o")
$elapsedSeconds = ($completedAt - $startedAt).TotalSeconds
$artifactContract = Get-RunArtifactContract $RunMode $passed
$summary = [ordered]@{
    schema = $artifactContract.summary_schema; passed = $passed; run_mode = $RunMode; qualifies_for_final = $artifactContract.qualifies_for_final
    exact_head = $head; exact_tree = $tree; input_manifest_sha256 = $inputHash
    policy_blob = $policyBlob; plugin_identity_sha256 = $pluginHash
    runtime_artifact_manifest_sha256 = $runtimeHash; report_schema = $reportSchema
    godot_console_sha256 = $godotConsoleSha; godot_worker_sha256 = $godotWorkerSha
    seed_prefix = $SeedPrefix; seeds_per_playstyle = $SeedsPerPlaystyle; max_actions = $MaxActions
    run_count = $allRuns.Count; expected_run_count = $styles.Count * $SeedsPerPlaystyle
    warnings = @($warnings); failures = @($failures); overall = $overall
    terminal_causes = $terminalCauses; victory_routes = $victoryRoutes
    opportunity_denominators = $opportunities; playstyles = $styleSummaries
    shards = $shardIndex; elapsed_seconds = $elapsedSeconds
}
$summaryPath = Join-Path $OutDir "aggregate_summary.json"
Write-JsonFile $summary $summaryPath 30
$custody = [ordered]@{
    schema = $artifactContract.manifest_schema
    passed = $passed; run_mode = $RunMode; qualifies_for_final = $artifactContract.qualifies_for_final
    exact_head = $head; exact_tree = $tree; generated_at_utc = $completedAtUtc
    command = $invocationCommand; working_directory = [IO.Path]::GetFullPath($projectRoot)
    runtime_source_root = $RuntimeSourceRoot
    resume_from = $ResumeFrom; resumed_styles = @($resumedStyles)
    started_at_utc = $startedAtUtc; completed_at_utc = $completedAtUtc; elapsed_seconds = $elapsedSeconds
    frozen_archive = [ordered]@{ path = $archivePath; bytes = (Get-Item -LiteralPath $archivePath).Length; sha256 = $archiveSha }
    engine_path = $godot; engine_sha256 = $godotConsoleSha
    worker_path = $godotWorker; worker_sha256 = $godotWorkerSha
    os = [Environment]::OSVersion.VersionString; processor_count = [Environment]::ProcessorCount; worker_count = $WorkerCount
    input_manifest_sha256 = $inputHash; tracked_manifest_file_sha256 = $trackedManifestFileSha
    policy_blob = $policyBlob; plugin_identity_sha256 = $pluginHash
    runtime_artifact_manifest_sha256 = $runtimeHash; runtime_manifest_file_sha256 = $runtimeManifestFileSha
    identity_manifest_sha256 = $identityManifestSha; report_schema = $reportSchema
    failure_ledger = @($failures); warning_ledger = @($warnings)
    aggregate_summary = [ordered]@{ path = $summaryPath; bytes = (Get-Item -LiteralPath $summaryPath).Length; sha256 = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    shards = $shardIndex
}
$custodyPath = Join-Path $OutDir $artifactContract.manifest_name
Write-JsonFile $custody $custodyPath 20
if (-not $passed) { throw "Cross-economy shard distribution rejected with $($failures.Count) failure(s); see $summaryPath" }
if ($RunMode -eq "FINAL") {
    Write-Host "CROSS_ECONOMY_SHARDS_PASS runs=$($allRuns.Count) output=$summaryPath"
} else {
    Write-Host "CROSS_ECONOMY_DIAGNOSTIC_PASS qualifies_for_final=false runs=$($allRuns.Count) output=$summaryPath"
}
