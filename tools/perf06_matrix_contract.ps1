param(
    [Parameter(Mandatory = $true)][string]$CandidateCommit,
    [Parameter(Mandatory = $true)][string]$CompositionManifest,
    [Parameter(Mandatory = $true)][string]$TerminalManifest,
    [string[]]$SurfaceReports = @(),
    [ValidateSet("native", "web", "low_end")][string[]]$RequiredProfiles = @(),
    [string]$RequiredMatrix = "tools/perf06_required_matrix.json",
    [string]$Out = ".tmp/perf06_1/matrix_contract.json"
)

$ErrorActionPreference = "Stop"
$root = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$failures = [Collections.Generic.List[string]]::new()
$loadedReports = [Collections.Generic.List[object]]::new()
. (Join-Path $PSScriptRoot "perf06_phase_qualification_contract.ps1")

function Resolve-RepoPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $root $Path))
}

function Read-Json([string]$Path, [string]$Label) {
    $resolved = Resolve-RepoPath $Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        $failures.Add("$Label is missing: $resolved")
        return $null
    }
    try { return Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json }
    catch {
        $failures.Add("$Label is not valid JSON: $resolved ($($_.Exception.Message))")
        return $null
    }
}

function Require-Property($Object, [string]$Name, [string]$Label) {
    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        $failures.Add("$Label is missing required field '$Name'.")
        return $false
    }
    return $true
}

function Test-CommonReport($Report, [string]$Label, [string]$ExpectedSchema) {
    foreach ($field in @("candidate_commit", "candidate_tree", "tool_source_sha256", "schema", "version", "phase_samples", "retained_counters", "allocation_copy_counters", "artifacts", "failures", "passed")) {
        [void](Require-Property $Report $field $Label)
    }
    if ($null -eq $Report) { return }
    if ([string]$Report.schema -cne $ExpectedSchema) { $failures.Add("$Label schema '$($Report.schema)' is not '$ExpectedSchema'.") }
    if ([string]$Report.candidate_commit -cne $CandidateCommit) { $failures.Add("$Label candidate '$($Report.candidate_commit)' is not '$CandidateCommit'.") }
    if (-not [bool]$Report.passed) { $failures.Add("$Label did not pass.") }
    if (@($Report.failures).Count -ne 0) { $failures.Add("$Label contains $(@($Report.failures).Count) failure(s).") }
}

function Add-PhaseSamples($Report, [string]$Label) {
    if ($null -eq $Report -or -not ($Report.PSObject.Properties.Name -contains "phase_samples")) { return }
    foreach ($row in @($Report.phase_samples)) {
        if ($null -eq $row) { continue }
        $row | Add-Member -NotePropertyName _source_label -NotePropertyValue $Label -Force
        $loadedReports.Add($row)
    }
}

function Test-ArtifactHashes($Report, [string]$ManifestPath, [string]$Label) {
    if ($null -eq $Report -or -not ($Report.PSObject.Properties.Name -contains "artifacts")) { return }
    $base = Split-Path -Parent (Resolve-RepoPath $ManifestPath)
    foreach ($artifact in @($Report.artifacts)) {
        if ($null -eq $artifact) { continue }
        foreach ($field in @("path", "sha256", "size_bytes")) { [void](Require-Property $artifact $field "$Label artifact") }
        $path = [string]$artifact.path
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $base $path }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("$Label artifact is missing: $path"); continue }
        $file = Get-Item -LiteralPath $path
        if ([int64]$artifact.size_bytes -ne $file.Length) { $failures.Add("$Label artifact size mismatch: $path") }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -cne ([string]$artifact.sha256).ToLowerInvariant()) { $failures.Add("$Label artifact hash mismatch: $path") }
    }
}

function Test-PhaseRow($Row) {
    $label = "phase row from $($Row._source_label)"
    foreach ($field in @("surface_id", "phase_id", "platform", "profile", "launch_identity", "frame", "draw", "liveness", "budget_evaluation", "progress_evaluation", "allocation_copy_counters", "retained_counters", "passed")) {
        [void](Require-Property $Row $field $label)
    }
    if (-not [bool]$Row.passed) { $failures.Add("$label did not pass: $($Row.surface_id)/$($Row.phase_id)/$($Row.profile)") }
    $launch = $Row.launch_identity
    foreach ($field in @("candidate_commit", "profile_manifest_sha256", "host_id", "resolution", "renderer", "power_plan", "actual_cpu_throttle_rate", "actual_device_scale_factor", "budget_table_version", "budget_table_sha256")) {
        [void](Require-Property $launch $field "$label launch_identity")
    }
    if ([string]$launch.candidate_commit -cne $CandidateCommit) { $failures.Add("$label launch identity is from a different candidate.") }
    if ($null -ne $budgetTable) {
        if ([int]$launch.budget_table_version -ne [int]$budgetTable.version -or ([string]$launch.budget_table_sha256).ToLowerInvariant() -cne $budgetTableHash) {
            $failures.Add("$label launch identity does not bind the published budget table.")
        }
    }
    if ([string]$Row.platform -ceq "web") {
        foreach ($field in @("browser_version", "browser_flags", "viewport", "worker_mode", "export_sha256")) { [void](Require-Property $launch $field "$label Web launch_identity") }
    } else {
        foreach ($field in @("godot_sha256", "build_sha256")) { [void](Require-Property $launch $field "$label native launch_identity") }
    }
    if ([string]$Row.profile -ceq "low_end") {
        foreach ($field in @("low_end_profile_sha256", "low_end_method", "hardware_fingerprint")) { [void](Require-Property $launch $field "$label low-end launch_identity") }
        if ([string]$launch.low_end_method -notin @("physical", "reproducible_whole_matrix_throttle")) { $failures.Add("$label has invalid low-end method '$($launch.low_end_method)'.") }
        if ([string]::IsNullOrWhiteSpace([string]$launch.low_end_profile_sha256) -or [string]::IsNullOrWhiteSpace([string]$launch.hardware_fingerprint)) { $failures.Add("$label low-end identity is label-only rather than launch-bound.") }
    }
    foreach ($metricName in @("frame", "draw")) {
        $metric = $Row.$metricName
        foreach ($field in @("count", "mean_ms", "p95_ms", "max_ms")) { [void](Require-Property $metric $field "$label $metricName") }
    }
    [void](Require-Property $Row.draw "calls_mean" "$label draw")
    foreach ($field in @("counter", "floor", "measured", "zero_reason", "source", "passed")) { [void](Require-Property $Row.liveness $field "$label liveness") }
    if ([int]$Row.liveness.floor -le 0 -and [string]::IsNullOrWhiteSpace([string]$Row.liveness.zero_reason)) {
        $failures.Add("$label has no positive liveness floor or accepted zero reason.")
    }
    if (-not [bool]$Row.liveness.passed -or ([int]$Row.liveness.floor -gt 0 -and [int]$Row.liveness.measured -lt [int]$Row.liveness.floor)) {
        $failures.Add("$label did not meet its published liveness floor: measured=$($Row.liveness.measured) floor=$($Row.liveness.floor).")
    }
    $isIdle = Test-Perf06IdlePhase ([string]$Row.surface_id) ([string]$Row.phase_id)
    if ($isIdle -and ([int]$Row.liveness.floor -le 0 -or -not [string]::IsNullOrWhiteSpace([string]$Row.liveness.zero_reason))) {
        $failures.Add("$label idle phase did not retain the contract-owned positive liveness floor.")
    }
    $recomputedProgress = Get-Perf06PhaseProgressEvaluation -SurfaceId ([string]$Row.surface_id) -PhaseId ([string]$Row.phase_id) -Evidence $Row
    foreach ($field in @("applicable", "checks", "passed")) { [void](Require-Property $Row.progress_evaluation $field "$label progress_evaluation") }
    if ([bool]$Row.progress_evaluation.applicable -ne [bool]$recomputedProgress.applicable -or [bool]$Row.progress_evaluation.passed -ne [bool]$recomputedProgress.passed -or @($Row.progress_evaluation.checks).Count -ne @($recomputedProgress.checks).Count) {
        $failures.Add("$label progress evaluation does not match its retained evidence.")
    }
    if (-not $isIdle -and (-not [bool]$recomputedProgress.applicable -or -not [bool]$recomputedProgress.passed -or @($recomputedProgress.checks).Count -eq 0)) {
        $failures.Add("$label active phase has no passing retained progress evidence.")
    }
    foreach ($check in @($recomputedProgress.checks)) {
        if ([string]::IsNullOrWhiteSpace([string]$check.kind) -or -not [bool]$check.passed) { $failures.Add("$label retained progress check did not pass.") }
    }
    $budgetEvaluation = $Row.budget_evaluation
    foreach ($field in @("budget_table_version", "applicable", "checks", "passed")) { [void](Require-Property $budgetEvaluation $field "$label budget_evaluation") }
    if ([int]$budgetEvaluation.budget_table_version -ne [int]$launch.budget_table_version) { $failures.Add("$label evaluated a different budget-table version than its launch identity.") }
    foreach ($check in @($budgetEvaluation.checks)) {
        foreach ($field in @("metric", "observed", "maximum", "passed")) { [void](Require-Property $check $field "$label budget check") }
        if (-not [bool]$check.passed -or [double]$check.observed -gt [double]$check.maximum) {
            $failures.Add("$label exceeded published budget '$($check.metric)': observed=$($check.observed) maximum=$($check.maximum).")
        }
    }
    if (-not [bool]$budgetEvaluation.passed) { $failures.Add("$label did not pass its published timing-budget evaluation.") }
    if ([string]$Row.platform -ceq "native" -and $null -ne $budgetTable) {
        $surfaceId = [string]$Row.surface_id
        $phaseId = [string]$Row.phase_id
        $gameIds = @($budgetTable.native.resolve_ms.PSObject.Properties.Name) + @("coin_pusher")
        $checksByMetric = @{}
        foreach ($check in @($budgetEvaluation.checks)) { $checksByMetric[[string]$check.metric] = $check }
        if ($gameIds -ccontains $surfaceId) {
            $expectedDrawMaximum = [double]$budgetTable.native.surface_draw_p95_ms
            if ($surfaceId -ceq "coin_pusher" -and $phaseId -in @("drop", "carriage", "skill_stop", "skill_release", "collect")) {
                $expectedDrawMaximum = [double]$budgetTable.native.coin_pusher.active_draw_p95_ms
            } elseif (-not [string]::IsNullOrWhiteSpace([string]$Row.liveness.zero_reason)) {
                $expectedDrawMaximum = [double]$budgetTable.native.static_idle_surface_draw_p95_ms
            } elseif ([int]$Row.liveness.floor -gt 0 -and $budgetTable.native.animated_idle_surface_draw_p95_ms.PSObject.Properties.Name -ccontains $surfaceId) {
                $expectedDrawMaximum = [double]$budgetTable.native.animated_idle_surface_draw_p95_ms.PSObject.Properties[$surfaceId].Value
            }
            if (-not $checksByMetric.ContainsKey("draw_p95_ms") -or [double]$checksByMetric["draw_p95_ms"].maximum -ne $expectedDrawMaximum -or [double]$checksByMetric["draw_p95_ms"].observed -ne [double]$Row.draw.p95_ms) {
                $failures.Add("$label did not evaluate its exact published native draw budget.")
            }
        }
        if ($surfaceId -ceq "coin_pusher" -and $phaseId -in @("drop", "carriage", "skill_stop", "skill_release", "collect")) {
            if (-not $checksByMetric.ContainsKey("frame_p95_ms") -or [double]$checksByMetric["frame_p95_ms"].maximum -ne [double]$budgetTable.native.coin_pusher.active_frame_p95_ms -or [double]$checksByMetric["frame_p95_ms"].observed -ne [double]$Row.frame.p95_ms) {
                $failures.Add("$label did not evaluate the exact published Coin Pusher native frame budget.")
            }
            if (-not $checksByMetric.ContainsKey("resolve_call_ms") -or [double]$checksByMetric["resolve_call_ms"].maximum -ne [double]$budgetTable.native.coin_pusher.active_action_ms) {
                $failures.Add("$label did not evaluate the exact published Coin Pusher action budget.")
            }
        }
        if ($surfaceId -ceq "coin_pusher" -and $phaseId -ceq "raw_solver") {
            if (-not $checksByMetric.ContainsKey("solver_tick_p95_ms") -or [double]$checksByMetric["solver_tick_p95_ms"].maximum -ne [double]$budgetTable.native.coin_pusher.solver_tick_p95_ms) {
                $failures.Add("$label did not evaluate the exact published Coin Pusher solver budget.")
            }
        }
        if ([int]$Row.liveness.floor -gt 0) {
            $expectedFloor = [Math]::Max(1, [int][Math]::Ceiling(([double]$Row.frame.count * [double]$budgetTable.native.animated_idle_liveness_minimum_per_120_frames) / 120.0))
            if ([int]$Row.liveness.floor -ne $expectedFloor) { $failures.Add("$label replaced the published native liveness floor: recorded=$($Row.liveness.floor) expected=$expectedFloor.") }
        }
    }
    foreach ($field in @("allocations", "shallow_copies", "deep_copies", "bytes", "source", "scope", "evidence_kind", "audited_call_roots", "coverage_complete")) {
        [void](Require-Property $Row.allocation_copy_counters $field "$label allocation_copy_counters")
    }
    $allocation = $Row.allocation_copy_counters
    if (-not [bool]$allocation.coverage_complete -or @($allocation.audited_call_roots).Count -eq 0) {
        $failures.Add("$label has empty or incomplete allocation/copy instrumentation coverage.")
    }
    $requiredRoots = @()
    $phaseOverrides = $null
    if ($null -ne $matrix -and $matrix.PSObject.Properties.Name -contains "allocation_roots_by_phase" -and $matrix.allocation_roots_by_phase.PSObject.Properties.Name -contains [string]$Row.surface_id) {
        $phaseOverrides = $matrix.allocation_roots_by_phase.PSObject.Properties[[string]$Row.surface_id].Value
    }
    if ($null -ne $phaseOverrides -and $phaseOverrides.PSObject.Properties.Name -contains [string]$Row.phase_id) {
        $requiredRoots = @($phaseOverrides.PSObject.Properties[[string]$Row.phase_id].Value)
    } elseif ($null -ne $matrix -and $matrix.allocation_roots.PSObject.Properties.Name -contains [string]$Row.surface_id) {
        $requiredRoots = @($matrix.allocation_roots.PSObject.Properties[[string]$Row.surface_id].Value)
    }
    if ($requiredRoots.Count -eq 0) { $failures.Add("$label has no declared required allocation roots in the matrix contract.") }
    foreach ($requiredRoot in $requiredRoots) {
        if (@($allocation.audited_call_roots) -cnotcontains [string]$requiredRoot) { $failures.Add("$label did not audit required call root '$requiredRoot'.") }
    }
    foreach ($field in @("static_call_root_audit_path", "static_call_root_audit_sha256")) { [void](Require-Property $allocation $field "$label call-root audit") }
    $auditPath = [string]$allocation.static_call_root_audit_path
    if (-not [IO.Path]::IsPathRooted($auditPath)) { $auditPath = Join-Path $root $auditPath }
    if (-not (Test-Path -LiteralPath $auditPath -PathType Leaf)) {
        $failures.Add("$label call-root audit is missing: $auditPath")
    } else {
        $auditHash = (Get-FileHash -LiteralPath $auditPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($auditHash -cne ([string]$allocation.static_call_root_audit_sha256).ToLowerInvariant()) { $failures.Add("$label call-root audit hash mismatch.") }
        try { $audit = Get-Content -LiteralPath $auditPath -Raw | ConvertFrom-Json }
        catch { $audit = $null; $failures.Add("$label call-root audit is invalid JSON.") }
        if ($null -ne $audit) {
            if ([string]$audit.schema -cne "beat_the_house.perf06_allocation_call_root_audit/v1" -or [string]$audit.candidate_commit -cne $CandidateCommit -or -not [bool]$audit.passed -or @($audit.failures).Count -ne 0) {
                $failures.Add("$label call-root audit is not a green exact-candidate artifact.")
            }
            if ([string]$allocation.evidence_kind -ceq "static_call_graph" -and [string]$audit.scope -cne "transitive_call_graph") {
                $failures.Add("$label claims static call-graph coverage from a direct-root-only audit.")
            }
            $auditedIds = @($audit.roots | Where-Object { [bool]$_.passed } | ForEach-Object { [string]$_.id })
            foreach ($requiredRoot in $requiredRoots) {
                if ($auditedIds -cnotcontains [string]$requiredRoot) { $failures.Add("$label call-root audit does not prove '$requiredRoot'.") }
            }
            foreach ($auditRoot in @($audit.roots)) {
                $sourcePath = [string]$auditRoot.source_path
                if (-not [IO.Path]::IsPathRooted($sourcePath)) { $sourcePath = Join-Path $root $sourcePath }
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { $failures.Add("$label audited source is missing: $sourcePath"); continue }
                $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($sourceHash -cne ([string]$auditRoot.source_sha256).ToLowerInvariant()) { $failures.Add("$label audited source changed: $sourcePath") }
            }
        }
    }
    if ([string]$allocation.evidence_kind -notin @("explicit_counter", "static_call_graph")) {
        $failures.Add("$label has unsupported allocation/copy evidence kind '$($allocation.evidence_kind)'.")
    }
    if ([string]$allocation.evidence_kind -ceq "explicit_counter") {
        if (-not ($allocation.PSObject.Properties.Name -contains "sources") -or @($allocation.sources).Count -eq 0) {
            $failures.Add("$label claims explicit counters without registered sources.")
        } else {
            $sourceNames = @($allocation.sources | Where-Object { [bool]$_.audited } | ForEach-Object { [string]$_.source })
            foreach ($rootName in @($allocation.audited_call_roots)) {
                if ($sourceNames -cnotcontains [string]$rootName) { $failures.Add("$label has no explicit counter source for audited root '$rootName'.") }
            }
        }
    } else {
        foreach ($field in @("static_contract_path", "static_contract_sha256")) { [void](Require-Property $allocation $field "$label static allocation contract") }
        $contractPath = [string]$allocation.static_contract_path
        if (-not [IO.Path]::IsPathRooted($contractPath)) { $contractPath = Join-Path $root $contractPath }
        if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
            $failures.Add("$label static allocation contract is missing: $contractPath")
        } else {
            $contractHash = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($contractHash -cne ([string]$allocation.static_contract_sha256).ToLowerInvariant()) { $failures.Add("$label static allocation contract hash mismatch.") }
        }
    }
    if ([string]$allocation.scope -ceq "steady_state_frame" -and [int64]$allocation.deep_copies -gt 0) {
        $failures.Add("$label observed recurring deep copies.")
    }
}

function Import-ShardReports($Manifest, [string]$ManifestPath, [string]$Kind) {
    if ($null -eq $Manifest) { return }
    if (-not (Require-Property $Manifest "shard_reports" "$Kind manifest")) { return }
    $base = Split-Path -Parent (Resolve-RepoPath $ManifestPath)
    $expectedSchema = if ($Kind -eq "composition") { "beat_the_house.integ06_1_composition_shard/v1" } else { "beat_the_house.integ06_1_terminal_soak_shard/v1" }
    foreach ($relative in @($Manifest.shard_reports)) {
        $path = [string]$relative
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $base $path }
        $shard = Read-Json $path "$Kind shard"
        Test-CommonReport $shard "$Kind shard '$path'" $expectedSchema
        Test-ArtifactHashes $shard $path "$Kind shard '$path'"
        Add-PhaseSamples $shard "$Kind shard '$path'"
        if ($null -eq $shard) { continue }
        foreach ($field in @("shard", "platform", "profile", "active_systems", "authored_max_counts", "lifecycle_status", "semantic_trace_sha256", "save_load_points")) {
            [void](Require-Property $shard $field "$Kind shard '$path'")
        }
        if ($Kind -eq "composition") {
            if (Require-Property $shard "rows" "composition shard '$path'") {
                foreach ($compositionRow in @($shard.rows)) {
                    foreach ($field in @("archetype_id", "node_id", "scenario_id", "layer_id", "event_ids", "service_ids", "traveler_ids", "game_ids", "sweep_state", "crew_sequence_token", "order_id", "before_sha256", "after_sha256", "double_fire_count", "orphan_count")) {
                        [void](Require-Property $compositionRow $field "composition shard '$path' row")
                    }
                    if ([int]$compositionRow.double_fire_count -ne 0 -or [int]$compositionRow.orphan_count -ne 0) { $failures.Add("Composition shard '$path' retained double-fire or orphan state.") }
                }
            }
        } else {
            if (Require-Property $shard "rows" "terminal shard '$path'") {
                foreach ($terminalRow in @($shard.rows)) {
                    if (Require-Property $terminalRow "terminal" "terminal shard '$path' row") {
                        foreach ($field in @("status", "route", "failure_reason", "profile_recorded")) { [void](Require-Property $terminalRow.terminal $field "terminal shard '$path' terminal") }
                        if (-not [bool]$terminalRow.terminal.profile_recorded) { $failures.Add("Terminal shard '$path' did not record its profile.") }
                    }
                }
            }
        }
    }
}

$matrix = Read-Json $RequiredMatrix "required matrix"
$budgetTablePath = Resolve-RepoPath "tools/perf06_budget_table.json"
$budgetTable = Read-Json $budgetTablePath "published budget table"
$budgetTableHash = if ($null -ne $budgetTable) { (Get-FileHash -LiteralPath $budgetTablePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { "" }
$composition = Read-Json $CompositionManifest "composition manifest"
$terminal = Read-Json $TerminalManifest "terminal manifest"
$profilesToRequire = if ($RequiredProfiles.Count -gt 0) { @($RequiredProfiles | Sort-Object -Unique) } elseif ($null -ne $matrix) { @($matrix.required_profiles) } else { @() }
if ($null -ne $matrix) {
    foreach ($profileName in $profilesToRequire) {
        if (@($matrix.required_profiles) -cnotcontains [string]$profileName) { $failures.Add("Requested unknown matrix profile '$profileName'.") }
    }
}

Test-CommonReport $composition "composition manifest" "beat_the_house.integ06_1_composition_manifest/v1"
Test-CommonReport $terminal "terminal manifest" "beat_the_house.integ06_1_terminal_soak_manifest/v1"
Test-ArtifactHashes $composition $CompositionManifest "composition manifest"
Test-ArtifactHashes $terminal $TerminalManifest "terminal manifest"
Add-PhaseSamples $composition "composition manifest"
Add-PhaseSamples $terminal "terminal manifest"
Import-ShardReports $composition $CompositionManifest "composition"
Import-ShardReports $terminal $TerminalManifest "terminal"

if ($null -ne $composition) {
    foreach ($field in @("eligible_rows", "covered_rows", "uncovered_rows", "order_ids")) { [void](Require-Property $composition $field "composition manifest") }
    if ([int]$composition.uncovered_rows -ne 0 -or [int]$composition.covered_rows -ne [int]$composition.eligible_rows) {
        $failures.Add("Composition coverage is incomplete: eligible=$($composition.eligible_rows) covered=$($composition.covered_rows) uncovered=$($composition.uncovered_rows).")
    }
    if (@($composition.order_ids).Count -eq 0) { $failures.Add("Composition manifest has no ordering coverage.") }
}

if ($null -ne $terminal) {
    foreach ($field in @("crew_ignore_control", "victory_routes", "failure_routes", "native_web_trace_pairs")) { [void](Require-Property $terminal $field "terminal manifest") }
    if (-not [bool]$terminal.crew_ignore_control) { $failures.Add("Terminal manifest does not prove the Crew-ignoring control.") }
    if (@($terminal.victory_routes).Count -eq 0) { $failures.Add("Terminal manifest has no victory-route coverage.") }
    if (@($terminal.failure_routes).Count -eq 0) { $failures.Add("Terminal manifest has no representative failure-route coverage.") }
    if (@($terminal.native_web_trace_pairs).Count -eq 0) { $failures.Add("Terminal manifest has no native/Web same-seed trace pairs.") }
    foreach ($pair in @($terminal.native_web_trace_pairs)) {
        foreach ($field in @("seed_id", "native_repeat_sha256", "native_sha256", "web_sha256")) { [void](Require-Property $pair $field "terminal trace pair") }
        if ([string]$pair.native_sha256 -cne [string]$pair.native_repeat_sha256 -or [string]$pair.native_sha256 -cne [string]$pair.web_sha256) {
            $failures.Add("Terminal trace parity failed for seed '$($pair.seed_id)'.")
        }
    }
}

foreach ($path in $SurfaceReports) {
    $report = Read-Json $path "surface report"
    if ($null -eq $report) { continue }
    if ([string]$report.candidate_commit -cne $CandidateCommit) { $failures.Add("Surface report '$path' is from a different candidate.") }
    if (-not [bool]$report.passed -or @($report.failures).Count -ne 0) { $failures.Add("Surface report '$path' is not green.") }
    Add-PhaseSamples $report $path
    Test-ArtifactHashes $report $path "surface report '$path'"
}

foreach ($row in $loadedReports) { Test-PhaseRow $row }

$coverage = [Collections.Generic.List[object]]::new()
if ($null -ne $matrix) {
    foreach ($groupName in @("games", "systems")) {
        $group = $matrix.$groupName
        foreach ($surfaceProperty in $group.PSObject.Properties) {
            foreach ($phase in @($surfaceProperty.Value)) {
                foreach ($profile in $profilesToRequire) {
                    $matches = @($loadedReports | Where-Object { [string]$_.surface_id -ceq $surfaceProperty.Name -and [string]$_.phase_id -ceq [string]$phase -and [string]$_.profile -ceq [string]$profile })
                    $present = $matches.Count -gt 0
                    $coverage.Add([pscustomobject]@{ surface_id=$surfaceProperty.Name; phase_id=[string]$phase; profile=[string]$profile; present=$present; samples=$matches.Count })
                    if (-not $present) { $failures.Add("Missing required matrix row: $($surfaceProperty.Name)/$phase/$profile") }
                }
            }
        }
    }
}

$result = [ordered]@{
    schema = "beat_the_house.perf06_matrix_contract/v1"
    candidate_commit = $CandidateCommit
    required_matrix = (Resolve-RepoPath $RequiredMatrix)
    composition_manifest = (Resolve-RepoPath $CompositionManifest)
    terminal_manifest = (Resolve-RepoPath $TerminalManifest)
    required_profiles = $profilesToRequire
    phase_sample_count = $loadedReports.Count
    coverage = @($coverage)
    failures = @($failures)
    passed = ($failures.Count -eq 0)
}
$outPath = Resolve-RepoPath $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outPath -Encoding utf8
if ($failures.Count -ne 0) {
    Write-Error "PERF06 MATRIX CONTRACT FAIL failures=$($failures.Count) report=$outPath"
    exit 1
}
Write-Host "PERF06 MATRIX CONTRACT PASS rows=$($coverage.Count) report=$outPath"
