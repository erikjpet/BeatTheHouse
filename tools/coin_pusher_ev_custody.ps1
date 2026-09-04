param(
    [ValidateRange(1, 64)]
    [int]$ShardsPerMachine = 8,
    [string]$OutDir = "",
    [string]$RuntimeSourceRoot = "",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$acceptedPerMachine = 200000
$expectedTotalAccepted = 600000
$machines = @("quarter_falls", "jackpot_ridge", "vault_drop")
$custodySchema = "coin_pusher_ev_custody_v1"
$harnessSchema = "coin_pusher_v3_physical_ev_harness_v2"
$shardSchema = "coin_pusher_v3_physical_ev_shard_v2"
$archivePathspecs = @("project.godot", "icon.svg", "tools", "scripts", "scenes", "data", "assets", "branding", "native")
$knownLongExcludedPath = "docs/plans/evidence/balance06_1/validation/foundation_systems_retry1/user_data/systems_events_saves/Godot/app_userdata/Beat the House/saves/foundation_check_grand_casino_showdown_pending.json"
$projectRoot = Split-Path -Parent $PSScriptRoot

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

function Test-ArchivePathSelected([string]$Path) {
    $normalized = $Path.Replace("\", "/").TrimStart("./")
    if ($normalized -in @("project.godot", "icon.svg")) { return $true }
    foreach ($root in @("tools", "scripts", "scenes", "data", "assets", "branding", "native")) {
        if ($normalized.StartsWith("$root/", [StringComparison]::Ordinal)) { return $true }
    }
    return $false
}

function Get-IdentityFailures([object]$Actual, [object]$Expected, [string]$Label) {
    $failures = [Collections.Generic.List[string]]::new()
    foreach ($key in @(
        "exact_head", "exact_tree", "tracked_input_sha256", "policy_source_sha256",
        "runtime_manifest_sha256", "plugin_identity_sha256", "engine_sha256", "worker_sha256"
    )) {
        $actualValue = [string](Get-ObjectValue $Actual $key)
        $expectedValue = [string](Get-ObjectValue $Expected $key)
        if ($actualValue -cne $expectedValue) {
            $failures.Add("$Label identity mismatch for ${key}: expected '$expectedValue', got '$actualValue'.")
        }
    }
    return @($failures)
}

function Add-FileManifestFailures([string]$Label, [string]$Root, [object]$Manifest, [Collections.Generic.List[string]]$Failures) {
    foreach ($entry in @(Get-ObjectValue $Manifest "entries")) {
        if ($null -eq $entry) { continue }
        $relative = [string](Get-ObjectValue $entry "path")
        $path = Join-Path $Root $relative.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $Failures.Add("$Label file is missing: $relative")
            continue
        }
        $actualBytes = (Get-Item -LiteralPath $path).Length
        $actualSha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualBytes -ne [int64](Get-ObjectValue $entry "bytes") -or $actualSha -cne [string](Get-ObjectValue $entry "sha256")) {
            $Failures.Add("$Label file identity changed: $relative")
        }
    }
}

function Get-EvidenceContractFailures([object]$Manifest, [int]$ExpectedShards, [object]$ExpectedEngine) {
    $failures = [Collections.Generic.List[string]]::new()
    if ($null -eq $Manifest) { return @("Harness manifest is missing.") }
    if ([string](Get-ObjectValue $Manifest "schema") -cne $harnessSchema) { $failures.Add("Harness schema is missing or incompatible.") }
    if (-not [bool](Get-ObjectValue $Manifest "passed")) { $failures.Add("Harness did not pass.") }
    if (@(Get-ObjectValue $Manifest "process_failures").Count -ne 0) { $failures.Add("Harness preserved one or more process failures.") }
    if ([string](Get-ObjectValue $Manifest "scheduler_failure")) { $failures.Add("Harness preserved a scheduler failure.") }
    if ([string](Get-ObjectValue $Manifest "aggregation_failure")) { $failures.Add("Harness preserved an aggregation failure.") }

    $runner = Get-ObjectValue $Manifest "runner_provenance"
    $engine = Get-ObjectValue $runner "engine"
    if ([string](Get-ObjectValue $engine "configured_sha256") -cne [string](Get-ObjectValue $ExpectedEngine "engine_sha256") -or
        [string](Get-ObjectValue $engine "worker_sha256") -cne [string](Get-ObjectValue $ExpectedEngine "worker_sha256")) {
        $failures.Add("Harness engine provenance does not match custody.")
    }

    $machineRows = @((Get-ObjectValue $Manifest "machines") | Where-Object { $null -ne $_ })
    $ids = @($machineRows | ForEach-Object { [string](Get-ObjectValue $_ "machine_id") } | Sort-Object)
    if ($machineRows.Count -ne $machines.Count -or ($ids -join "|") -cne (@($machines | Sort-Object) -join "|")) {
        $failures.Add("Harness is missing a required machine or contains an unexpected machine.")
    }
    $total = 0L
    foreach ($machine in $machines) {
        $rows = @($machineRows | Where-Object { [string](Get-ObjectValue $_ "machine_id") -ceq $machine })
        if ($rows.Count -ne 1) { continue }
        $row = $rows[0]
        $accepted = [int64](Get-ObjectValue $row "accepted_player_inserts")
        $total += $accepted
        if ($accepted -ne $acceptedPerMachine -or -not [bool](Get-ObjectValue $row "passed")) {
            $failures.Add("$machine did not pass with exactly $acceptedPerMachine accepted inserts.")
        }
        $assertions = Get-ObjectValue $row "assertions"
        if ($null -eq $assertions -or -not [bool](Get-ObjectValue $assertions "accepted_exact") -or
            -not [bool](Get-ObjectValue $assertions "every_shard_passed")) {
            $failures.Add("$machine is missing its exact-count/every-shard assertions.")
        }
        $shardReports = @((Get-ObjectValue $row "shard_reports") | Where-Object { $_ })
        if ($shardReports.Count -ne $ExpectedShards) { $failures.Add("$machine has an incomplete shard index.") }
        $policyHashes = @((Get-ObjectValue $row "policy_sha256") | Where-Object { [string]$_ -match '^[0-9a-fA-F]{64}$' } | Sort-Object -Unique)
        $geometryHashes = @((Get-ObjectValue $row "geometry_sha256") | Where-Object { [string]$_ -match '^[0-9a-fA-F]{64}$' } | Sort-Object -Unique)
        if ($policyHashes.Count -ne 1) { $failures.Add("$machine has missing or mixed policy evidence.") }
        if ($geometryHashes.Count -ne 1) { $failures.Add("$machine has missing or mixed geometry evidence.") }
    }
    if ($total -ne $expectedTotalAccepted) { $failures.Add("Harness total is not exactly $expectedTotalAccepted accepted inserts.") }
    return @($failures)
}

if ($SelfTest) {
    $hashA = "a" * 64
    $hashB = "b" * 64
    $expectedIdentity = [pscustomobject]@{
        exact_head = "head"; exact_tree = "tree"; tracked_input_sha256 = $hashA
        policy_source_sha256 = $hashA; runtime_manifest_sha256 = $hashA
        plugin_identity_sha256 = $hashA; engine_sha256 = $hashA; worker_sha256 = $hashA
    }
    $changedIdentity = [pscustomobject]@{
        exact_head = "head"; exact_tree = "tree"; tracked_input_sha256 = $hashB
        policy_source_sha256 = $hashA; runtime_manifest_sha256 = $hashA
        plugin_identity_sha256 = $hashA; engine_sha256 = $hashA; worker_sha256 = $hashA
    }
    if (@(Get-IdentityFailures $changedIdentity $expectedIdentity "self-test").Count -eq 0) {
        throw "Self-test failed: changed input identity was accepted."
    }
    $machineRows = foreach ($machine in $machines) {
        [pscustomobject]@{
            machine_id = $machine; accepted_player_inserts = $acceptedPerMachine; passed = $true
            assertions = [pscustomobject]@{ accepted_exact = $true; every_shard_passed = $true }
            shard_reports = @(1..$ShardsPerMachine | ForEach-Object { "shard_$_.json" })
            policy_sha256 = @($hashA); geometry_sha256 = @($hashA)
        }
    }
    $validManifest = [pscustomobject]@{
        schema = $harnessSchema; passed = $true; process_failures = @()
        scheduler_failure = ""; aggregation_failure = ""
        runner_provenance = [pscustomobject]@{ engine = [pscustomobject]@{ configured_sha256 = $hashA; worker_sha256 = $hashA } }
        machines = @($machineRows)
    }
    if (@(Get-EvidenceContractFailures $validManifest $ShardsPerMachine $expectedIdentity).Count -ne 0) {
        throw "Self-test failed: complete evidence was rejected."
    }
    $mixedManifest = $validManifest | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $mixedManifest.machines[0].policy_sha256 = @($hashA, $hashB)
    if (@(Get-EvidenceContractFailures $mixedManifest $ShardsPerMachine $expectedIdentity).Count -eq 0) {
        throw "Self-test failed: mixed policy evidence was accepted."
    }
    $missingManifest = $validManifest | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $missingManifest.machines = @($missingManifest.machines | Where-Object machine_id -ne "vault_drop")
    if (@(Get-EvidenceContractFailures $missingManifest $ShardsPerMachine $expectedIdentity).Count -eq 0) {
        throw "Self-test failed: missing machine evidence was accepted."
    }
    if (Test-ArchivePathSelected $knownLongExcludedPath) { throw "Self-test failed: known long documentation evidence path was selected." }
    $tarCommand = Get-Command tar.exe -ErrorAction Stop
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ("bth_evc_" + [guid]::NewGuid().ToString("N"))
    $testArchive = Join-Path $testRoot "s.tar"
    $testExtract = Join-Path $testRoot "x"
    try {
        New-Item -ItemType Directory -Path $testExtract -Force | Out-Null
        & git -C $projectRoot archive --format=tar --output=$testArchive HEAD -- @archivePathspecs
        if ($LASTEXITCODE -ne 0) { throw "Self-test failed: executable-input git archive could not be created." }
        $listing = @(& $tarCommand.Source -tf $testArchive)
        if ($LASTEXITCODE -ne 0) { throw "Self-test failed: executable-input archive could not be listed." }
        if ($listing -contains $knownLongExcludedPath -or @($listing | Where-Object { -not (Test-ArchivePathSelected $_) }).Count -ne 0) {
            throw "Self-test failed: archive contains a path outside the executable-input allowlist."
        }
        & $tarCommand.Source -xf $testArchive -C $testExtract
        if ($LASTEXITCODE -ne 0) { throw "Self-test failed: executable-input archive could not be extracted with tar.exe." }
        foreach ($required in @(
            "project.godot", "icon.svg", "tools/coin_pusher_ev_custody.ps1", "tools/coin_pusher_ev_harness.ps1",
            "tools/coin_pusher_ev_shard.gd", "scripts/core/rng_stream.gd", "scripts/games/coin_pusher.gd",
            "data/games/games.json", "data/economy/content06_1_audit.json"
        )) {
            $extracted = Join-Path $testExtract $required.Replace("/", "\")
            if (-not (Test-Path -LiteralPath $extracted -PathType Leaf)) { throw "Self-test failed: archive omitted required input $required." }
            $expectedBlob = (git -C $projectRoot rev-parse "HEAD:$required").Trim()
            $actualBlob = (git -C $projectRoot hash-object -- $extracted).Trim()
            if ($actualBlob -cne $expectedBlob) { throw "Self-test failed: extracted input hash mismatch for $required." }
        }
    }
    finally {
        if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    }
    Write-Host "COIN_PUSHER_EV_CUSTODY_SELF_TEST_PASS changed_identity_rejected=true mixed_policy_rejected=true missing_machine_rejected=true long_docs_excluded=true tar_extract_verified=true"
    exit 0
}

if (-not $RuntimeSourceRoot) { $RuntimeSourceRoot = $projectRoot }
$RuntimeSourceRoot = [IO.Path]::GetFullPath($RuntimeSourceRoot)
if (-not $OutDir) { $OutDir = Join-Path $projectRoot ".tmp\evc\$(Get-Date -Format 'yyyyMMdd_HHmmss')" }
$OutDir = [IO.Path]::GetFullPath($OutDir)
$projectPrefix = [IO.Path]::GetFullPath($projectRoot)
if (-not $projectPrefix.EndsWith([IO.Path]::DirectorySeparatorChar)) { $projectPrefix += [IO.Path]::DirectorySeparatorChar }
if (-not $OutDir.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "OutDir must remain inside the caller worktree." }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
if (Get-ChildItem -LiteralPath $OutDir -Force | Select-Object -First 1) { throw "OutDir must be new and empty; custody evidence is never overwritten." }

$failures = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
$head = ""; $tree = ""; $trackedHash = ""; $policyHash = ""; $runtimeHash = ""; $pluginHash = ""
$enginePath = ""; $engineHash = ""; $workerPath = ""; $workerHash = ""; $archivePath = ""; $archiveHash = ""
$trackedManifestFileHash = ""; $runtimeManifestFileHash = ""
$trackedManifest = $null; $runtimeManifest = $null; $harnessManifest = $null; $harnessExitCode = -999
$rawEvidence = [Collections.Generic.List[object]]::new()
$rawRoot = ""; $harnessStdout = ""; $harnessStderr = ""
$startedAt = Get-Date

try {
    $dirty = @(git -C $projectRoot status --porcelain)
    if ($dirty.Count -ne 0) { throw "Caller worktree must be clean before freezing exact EV custody." }
    $head = (git -C $projectRoot rev-parse HEAD).Trim()
    $tree = (git -C $projectRoot rev-parse "HEAD^{tree}").Trim()

    $tarCommand = Get-Command tar.exe -ErrorAction Stop
    $archivePath = Join-Path $OutDir "s.tar"
    & git -C $projectRoot archive --format=tar --output=$archivePath $head -- @archivePathspecs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archivePath -PathType Leaf)) { throw "Could not archive exact HEAD $head." }
    $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $frozenRoot = Join-Path $OutDir "p"
    New-Item -ItemType Directory -Path $frozenRoot -Force | Out-Null
    & $tarCommand.Source -xf $archivePath -C $frozenRoot
    if ($LASTEXITCODE -ne 0) { throw "Could not extract the executable-input archive with tar.exe." }

    $trackedEntries = [Collections.Generic.List[object]]::new()
    $trackedByPath = @{}
    foreach ($line in @(git -C $projectRoot -c core.quotepath=false ls-tree -r --full-tree $head -- @archivePathspecs)) {
        if ($line -notmatch '^(?<mode>[0-9]+) (?<type>[^ ]+) (?<blob>[0-9a-f]+)\t(?<path>.+)$') { throw "Could not parse git tree entry: $line" }
        if ($Matches.type -ne "blob") { throw "Unsupported non-blob tracked entry: $($Matches.path)" }
        $relative = $Matches.path.Replace("\", "/")
        $path = Join-Path $frozenRoot $relative.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Frozen archive omitted tracked file: $relative" }
        $entry = [ordered]@{
            path = $relative; mode = $Matches.mode; git_blob = $Matches.blob
            bytes = (Get-Item -LiteralPath $path).Length
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        $trackedEntries.Add($entry); $trackedByPath[$relative] = $entry
    }
    foreach ($entry in $trackedEntries) {
        if (-not (Test-ArchivePathSelected ([string]$entry.path)) -or [string]$entry.path -like "docs/*") {
            throw "Executable input archive included a disallowed path: $($entry.path)"
        }
    }
    foreach ($required in @(
        "tools/coin_pusher_ev_custody.ps1", "tools/coin_pusher_ev_harness.ps1", "tools/coin_pusher_ev_shard.gd",
        "scripts/games/coin_pusher.gd", "scripts/games/coin_pusher/coin_pusher_solver.gd",
        "scripts/games/coin_pusher/coin_pusher_solver_api.gd", "scripts/games/coin_pusher/coin_pusher_live_session.gd",
        "scripts/core/content_library.gd", "scripts/core/run_state.gd", "scripts/core/rng_stream.gd",
        "scripts/core/game_module.gd", "data/games/games.json", "data/economy/content06_1_audit.json",
        "project.godot", "icon.svg"
    )) { if (-not $trackedByPath.ContainsKey($required)) { throw "Tracked EV input is missing: $required" } }
    foreach ($prefix in @("tools/", "scripts/", "scenes/", "data/", "data/economy/", "data/games/", "assets/", "branding/", "native/coin_pusher/")) {
        if (@($trackedEntries | Where-Object { [string]$_.path -like "$prefix*" }).Count -eq 0) { throw "Executable input archive is missing required group: $prefix" }
    }

    $trackedCanonical = (@($trackedEntries | Sort-Object path | ForEach-Object { "$($_.path)|$($_.mode)|$($_.git_blob)|$($_.bytes)|$($_.sha256)" }) -join "`n")
    $trackedHash = Get-Sha256Text $trackedCanonical
    $trackedManifest = [ordered]@{
        schema = "coin_pusher_ev_tracked_input_manifest_v1"; exact_head = $head; exact_tree = $tree
        canonical_sha256 = $trackedHash; entry_count = $trackedEntries.Count; entries = @($trackedEntries)
    }
    $trackedManifestPath = Join-Path $OutDir "t.json"
    Write-JsonFile $trackedManifest $trackedManifestPath 8
    $trackedManifestFileHash = (Get-FileHash -LiteralPath $trackedManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()

    $policyEntries = @($trackedEntries | Where-Object {
        [string]$_.path -in @(
            "project.godot", "tools/coin_pusher_ev_custody.ps1", "tools/coin_pusher_ev_harness.ps1",
            "tools/coin_pusher_ev_shard.gd", "scripts/games/coin_pusher.gd", "scripts/core/rng_stream.gd",
            "scripts/core/content_library.gd", "scripts/core/game_module.gd", "scripts/core/item_effect.gd"
        ) -or [string]$_.path -like "scripts/games/coin_pusher/*" -or
        [string]$_.path -like "data/games/*" -or [string]$_.path -like "data/economy/*" -or
        [string]$_.path -like "native/coin_pusher/*"
    } | Sort-Object path)
    $policyCanonical = (@($policyEntries | ForEach-Object { "$($_.path)|$($_.git_blob)|$($_.sha256)" }) -join "`n")
    $policyHash = Get-Sha256Text $policyCanonical

    $runtimeSources = @{}
    function Add-RuntimeSource([string]$Target, [string]$Source) {
        $normalized = $Target.Replace("\", "/")
        if (-not $runtimeSources.ContainsKey($normalized)) { $runtimeSources[$normalized] = $Source }
    }
    $nativeTargets = @(
        "addons/coin_pusher_native/coin_pusher_native.gdextension",
        "addons/coin_pusher_native/coin_pusher_native.gdextension.uid",
        "addons/coin_pusher_native/bin/coin_pusher_native.windows.template_debug.x86_64.nothreads.dll",
        "addons/coin_pusher_native/bin/coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll"
    )
    foreach ($target in $nativeTargets) {
        $source = Join-Path $RuntimeSourceRoot $target.Replace("/", "\")
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required ignored native runtime asset is missing: $source" }
        Add-RuntimeSource $target $source
    }
    foreach ($cache in @("global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg")) {
        $source = Join-Path $RuntimeSourceRoot ".godot\$cache"
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required ignored Godot runtime cache is missing: $source" }
        Add-RuntimeSource ".godot/$cache" $source
    }
    $assetRoot = Join-Path $RuntimeSourceRoot "assets"
    if (Test-Path -LiteralPath $assetRoot -PathType Container) {
        foreach ($importManifest in Get-ChildItem -LiteralPath $assetRoot -Recurse -Filter "*.import" -File) {
            $relativeManifest = $importManifest.FullName.Substring($RuntimeSourceRoot.Length).TrimStart("\", "/").Replace("\", "/")
            if (-not $trackedByPath.ContainsKey($relativeManifest)) { Add-RuntimeSource $relativeManifest $importManifest.FullName }
            foreach ($match in [regex]::Matches((Get-Content -LiteralPath $importManifest.FullName -Raw), 'res://\.godot/imported/([^"\r\n]+)')) {
                $name = $match.Groups[1].Value
                $source = Join-Path $RuntimeSourceRoot ".godot\imported\$name"
                if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Required ignored import artifact is missing: $source" }
                Add-RuntimeSource ".godot/imported/$name" $source
                $md5 = [IO.Path]::ChangeExtension($source, ".md5")
                if (Test-Path -LiteralPath $md5 -PathType Leaf) { Add-RuntimeSource ".godot/imported/$([IO.Path]::GetFileName($md5))" $md5 }
            }
        }
    }

    $runtimeEntries = [Collections.Generic.List[object]]::new()
    foreach ($target in @($runtimeSources.Keys | Sort-Object)) {
        if ($trackedByPath.ContainsKey($target)) { throw "Ignored runtime staging attempted to overwrite tracked source: $target" }
        $source = $runtimeSources[$target]
        $destination = Join-Path $frozenRoot $target.Replace("/", "\")
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
        schema = "coin_pusher_ev_runtime_manifest_v1"; source_root = $RuntimeSourceRoot
        canonical_sha256 = $runtimeHash; entry_count = $runtimeEntries.Count; entries = @($runtimeEntries)
    }
    $runtimeManifestPath = Join-Path $OutDir "r.json"
    Write-JsonFile $runtimeManifest $runtimeManifestPath 8
    $runtimeManifestFileHash = (Get-FileHash -LiteralPath $runtimeManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $pluginEntries = @($runtimeEntries | Where-Object { [string]$_.path -like "addons/coin_pusher_native/*" } | Sort-Object path)
    if ($pluginEntries.Count -ne $nativeTargets.Count) { throw "Native plugin manifest is incomplete." }
    $pluginHash = Get-Sha256Text (@($pluginEntries | ForEach-Object { "$($_.path)|$($_.bytes)|$($_.sha256)" }) -join "`n")

    $enginePath = $env:GODOT_BIN
    if (-not $enginePath) { $enginePath = "D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe" }
    if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) { throw "Godot console executable is missing: $enginePath" }
    $enginePath = [IO.Path]::GetFullPath($enginePath)
    $workerPath = $enginePath
    if ($workerPath.EndsWith("_console.exe", [StringComparison]::OrdinalIgnoreCase)) {
        $workerPath = $workerPath.Substring(0, $workerPath.Length - "_console.exe".Length) + ".exe"
    }
    if (-not (Test-Path -LiteralPath $workerPath -PathType Leaf)) { throw "Godot worker executable is missing: $workerPath" }
    $engineHash = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $workerHash = (Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash.ToLowerInvariant()

    Add-FileManifestFailures "tracked source (pre-run)" $frozenRoot $trackedManifest $failures
    Add-FileManifestFailures "runtime input (pre-run)" $frozenRoot $runtimeManifest $failures
    if ((git -C $projectRoot rev-parse HEAD).Trim() -cne $head -or (git -C $projectRoot rev-parse "HEAD^{tree}").Trim() -cne $tree -or @(git -C $projectRoot status --porcelain).Count -ne 0) {
        $failures.Add("Caller HEAD/tree/worktree changed before the EV run.")
    }
    if ($failures.Count -ne 0) { throw "Pre-run custody verification failed." }

    $rawRoot = Join-Path $frozenRoot ".tmp\e"
    $harnessStdout = Join-Path $OutDir "h.out"
    $harnessStderr = Join-Path $OutDir "h.err"
    $previousGodotBin = $env:GODOT_BIN
    try {
        $env:GODOT_BIN = $enginePath
        $arguments = @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $frozenRoot "tools\coin_pusher_ev_harness.ps1"),
            "-AcceptedPerMachine", "$acceptedPerMachine", "-ShardsPerMachine", "$ShardsPerMachine",
            "-Throttle", "1", "-OutDir", $rawRoot
        )
        $process = Start-Process -FilePath (Get-Command powershell.exe).Source -ArgumentList $arguments -WorkingDirectory $frozenRoot -WindowStyle Hidden -RedirectStandardOutput $harnessStdout -RedirectStandardError $harnessStderr -PassThru
        $process.WaitForExit(); $process.Refresh(); $harnessExitCode = [int]$process.ExitCode; $process.Dispose()
    }
    finally {
        [Environment]::SetEnvironmentVariable("GODOT_BIN", $previousGodotBin, [EnvironmentVariableTarget]::Process)
    }
    if ($harnessExitCode -ne 0) { $failures.Add("EV harness exited with code $harnessExitCode; raw failure artifacts were retained.") }
    foreach ($artifact in @($harnessStdout, $harnessStderr)) {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { $failures.Add("Missing harness process artifact: $artifact") }
    }

    Add-FileManifestFailures "tracked source (post-run)" $frozenRoot $trackedManifest $failures
    Add-FileManifestFailures "runtime input (post-run)" $frozenRoot $runtimeManifest $failures
    if ((git -C $projectRoot rev-parse HEAD).Trim() -cne $head -or (git -C $projectRoot rev-parse "HEAD^{tree}").Trim() -cne $tree -or @(git -C $projectRoot status --porcelain).Count -ne 0) {
        $failures.Add("Caller HEAD/tree/worktree changed during the EV run.")
    }
    if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $archiveHash) { $failures.Add("Frozen git archive changed during the EV run.") }
    if ((Get-FileHash -LiteralPath $trackedManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $trackedManifestFileHash) { $failures.Add("Tracked input manifest changed during the EV run.") }
    if ((Get-FileHash -LiteralPath $runtimeManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $runtimeManifestFileHash) { $failures.Add("Runtime manifest changed during the EV run.") }
    if ((Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $engineHash -or
        (Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $workerHash) { $failures.Add("Engine identity changed during the EV run.") }

    $rawManifestPath = Join-Path $rawRoot "manifest.json"
    if (-not (Test-Path -LiteralPath $rawManifestPath -PathType Leaf)) { $failures.Add("EV harness manifest is missing.") }
    else {
        try { $harnessManifest = Get-Content -LiteralPath $rawManifestPath -Raw | ConvertFrom-Json }
        catch { $failures.Add("EV harness manifest is malformed: $($_.Exception.Message)") }
    }
    $expectedEngine = [pscustomobject]@{ engine_sha256 = $engineHash; worker_sha256 = $workerHash }
    foreach ($failure in @(Get-EvidenceContractFailures $harnessManifest $ShardsPerMachine $expectedEngine)) { $failures.Add($failure) }

    if ($null -ne $harnessManifest) {
        $machineRows = @((Get-ObjectValue $harnessManifest "machines") | Where-Object { $null -ne $_ })
        $baseAccepted = [math]::Floor($acceptedPerMachine / $ShardsPerMachine)
        $remainder = $acceptedPerMachine % $ShardsPerMachine
        foreach ($machine in $machines) {
            $machineRow = @($machineRows | Where-Object { [string](Get-ObjectValue $_ "machine_id") -ceq $machine } | Select-Object -First 1)
            $hashIndex = if ($machineRow.Count -eq 1) { Get-ObjectValue $machineRow[0] "shard_report_sha256" } else { $null }
            $expectedPolicyHash = if ($machineRow.Count -eq 1) { [string](@(Get-ObjectValue $machineRow[0] "policy_sha256")[0]) } else { "" }
            $expectedGeometryHash = if ($machineRow.Count -eq 1) { [string](@(Get-ObjectValue $machineRow[0] "geometry_sha256")[0]) } else { "" }
            for ($shard = 0; $shard -lt $ShardsPerMachine; $shard++) {
                $stem = "${machine}_shard_$('{0:D2}' -f $shard)"
                $json = Join-Path $rawRoot "$stem.json"
                $stdout = Join-Path $rawRoot "$stem.stdout.txt"
                $stderr = Join-Path $rawRoot "$stem.stderr.txt"
                foreach ($artifact in @($json, $stdout, $stderr)) {
                    if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { $failures.Add("Missing raw shard artifact: $artifact") }
                }
                if (-not (Test-Path -LiteralPath $json -PathType Leaf)) { continue }
                try { $shardReport = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json }
                catch { $failures.Add("Malformed raw shard report ${stem}: $($_.Exception.Message)"); continue }
                $expectedAccepted = $baseAccepted + $(if ($shard -lt $remainder) { 1 } else { 0 })
                if ([string](Get-ObjectValue $shardReport "schema") -cne $shardSchema -or
                    [string](Get-ObjectValue $shardReport "machine_id") -cne $machine -or
                    [int](Get-ObjectValue $shardReport "shard_index") -ne $shard -or
                    [int64](Get-ObjectValue $shardReport "accepted_target") -ne $expectedAccepted -or
                    [int64](Get-ObjectValue $shardReport "accepted_player_inserts") -ne $expectedAccepted -or
                    -not [bool](Get-ObjectValue $shardReport "passed")) {
                    $failures.Add("Raw shard identity/count/pass mismatch: $stem")
                }
                if ([string](Get-ObjectValue $shardReport "policy_sha256") -cne $expectedPolicyHash -or
                    [string](Get-ObjectValue $shardReport "geometry_sha256") -cne $expectedGeometryHash) {
                    $failures.Add("Raw shard policy/geometry evidence is missing or mixed: $stem")
                }
                $runnerEngine = Get-ObjectValue (Get-ObjectValue $shardReport "runner_provenance") "engine"
                if ([string](Get-ObjectValue $runnerEngine "configured_sha256") -cne $engineHash -or [string](Get-ObjectValue $runnerEngine "worker_sha256") -cne $workerHash) {
                    $failures.Add("Raw shard engine provenance mismatch: $stem")
                }
                $indexedHash = [string](Get-ObjectValue $hashIndex "$stem.json")
                $actualHash = (Get-FileHash -LiteralPath $json -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($indexedHash -cne $actualHash) { $failures.Add("Raw shard hash/index mismatch: $stem") }
            }
        }
    }
}
catch {
    $failures.Add($_.Exception.ToString())
}

# Index every artifact that exists even when setup, scheduling, or aggregation
# failed. Evidence is retained in place and never repaired or overwritten.
$rawArtifacts = @()
if ($rawRoot -and (Test-Path -LiteralPath $rawRoot -PathType Container)) {
    $rawArtifacts += @(Get-ChildItem -LiteralPath $rawRoot -Recurse -File -ErrorAction SilentlyContinue)
}
foreach ($path in @($harnessStdout, $harnessStderr)) {
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) { $rawArtifacts += Get-Item -LiteralPath $path }
}
foreach ($artifact in $rawArtifacts) {
    $rawEvidence.Add([ordered]@{
        path = $artifact.FullName; bytes = $artifact.Length
        sha256 = (Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    })
}

$identity = [ordered]@{
    exact_head = $head; exact_tree = $tree; tracked_input_sha256 = $trackedHash
    policy_source_sha256 = $policyHash; runtime_manifest_sha256 = $runtimeHash
    plugin_identity_sha256 = $pluginHash; engine_sha256 = $engineHash; worker_sha256 = $workerHash
}
$passed = $failures.Count -eq 0 -and $harnessExitCode -eq 0
$custody = [ordered]@{
    schema = $custodySchema; passed = $passed; generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    command = "tools/coin_pusher_ev_harness.ps1 -AcceptedPerMachine 200000 -ShardsPerMachine $ShardsPerMachine -Throttle 1"
    identity = $identity
    exact_head = $head; exact_tree = $tree
    tracked_input_sha256 = $trackedHash; tracked_manifest_file_sha256 = $trackedManifestFileHash
    policy_source_sha256 = $policyHash
    runtime_manifest_sha256 = $runtimeHash; runtime_manifest_file_sha256 = $runtimeManifestFileHash
    plugin_identity_sha256 = $pluginHash
    engine = [ordered]@{ path = $enginePath; sha256 = $engineHash; worker_path = $workerPath; worker_sha256 = $workerHash }
    frozen_archive = [ordered]@{ path = $archivePath; sha256 = $archiveHash }
    accepted_per_machine = $acceptedPerMachine; required_machines = $machines; expected_total_accepted = $expectedTotalAccepted
    shards_per_machine = $ShardsPerMachine; harness_exit_code = $harnessExitCode
    tracked_manifest = $trackedManifest; runtime_manifest = $runtimeManifest
    harness_manifest = $harnessManifest; raw_evidence = @($rawEvidence)
    failure_ledger = @($failures); warning_ledger = @($warnings)
    elapsed_seconds = ((Get-Date) - $startedAt).TotalSeconds
}
$custodyPath = Join-Path $OutDir "custody_manifest.json"
Write-JsonFile $custody $custodyPath 30
if (-not $passed) { throw "Coin Pusher EV custody rejected with $($failures.Count) failure(s); evidence retained at $custodyPath" }
Write-Host "COIN_PUSHER_EV_CUSTODY_PASS accepted=$expectedTotalAccepted output=$custodyPath"
