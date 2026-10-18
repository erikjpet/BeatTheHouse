$ErrorActionPreference = "Stop"

function Get-NativeSourceLibrary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,
        [Parameter(Mandatory)]
        [ValidateSet("windows", "web")]
        [string]$Platform,
        [Parameter(Mandatory)]
        [ValidateSet("template_debug", "template_release")]
        [string]$Target,
        [Parameter(Mandatory)]
        [ValidateSet("x86_64", "wasm32")]
        [string]$Architecture,
        [Parameter(Mandatory)]
        [ValidateSet("nothreads", "threads")]
        [string]$Threading
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Native-library directory does not exist: $Directory"
    }
    $extension = if ($Platform -eq "web") { ".wasm" } else { ".dll" }
    $expectedSuffix = ".$Platform.$Target.$Architecture.$Threading$extension"
    $native = @(Get-ChildItem -LiteralPath $Directory -File -Recurse -Force | Where-Object {
        $_.Name.StartsWith("coin_pusher_native_", [StringComparison]::OrdinalIgnoreCase) -and
            $_.Name.EndsWith($expectedSuffix, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($native.Count -ne 1) {
        $tuple = "$Platform/$Target/$Architecture/$Threading"
        throw "Expected exactly one native library for tuple $tuple in $Directory; found $($native.Count)."
    }
    return $native[0]
}

function Invoke-TypedConsoleProcess {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    $previousErrorAction = $ErrorActionPreference
    try {
        # Windows PowerShell promotes native stderr to NativeCommandError when
        # Stop is active. Consume both streams for operator visibility while
        # keeping the success stream reserved for the typed exit code.
        $ErrorActionPreference = "Continue"
        & $FilePath @ArgumentList 2>&1 | ForEach-Object { Write-Host ([string]$_) }
        [int]$exitCode = $LASTEXITCODE
        return $exitCode
    }
    finally { $ErrorActionPreference = $previousErrorAction }
}

function Invoke-WebExportPipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ExportAction,
        [Parameter(Mandatory)]
        [scriptblock]$AuditAction,
        [Parameter(Mandatory)]
        [scriptblock]$CustodyAction,
        [Parameter(Mandatory)]
        [scriptblock]$RegistrationAction
    )

    $exportResult = @(& $ExportAction)
    if ($exportResult.Count -ne 1 -or $exportResult[0] -isnot [int]) {
        throw "Web export action must return exactly one typed Int32 exit code."
    }
    [int]$exitCode = $exportResult[0]
    if ($exitCode -ne 0) {
        throw "Godot web export failed with exit $exitCode."
    }

    & $AuditAction
    & $CustodyAction
    & $RegistrationAction
}

function Test-ExportPathInside {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Directory,
        [switch]$AllowEqual
    )

    $fullPath = [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\', '/'))
    $fullDirectory = [IO.Path]::GetFullPath($Directory).TrimEnd([char[]]@('\', '/'))
    if ($AllowEqual -and $fullPath.Equals($fullDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $fullPath.StartsWith($fullDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Initialize-CandidatePlatformAttempt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CandidateRoot,
        [Parameter(Mandatory)]
        [string]$WorkRoot,
        [Parameter(Mandatory)]
        [ValidateSet("windows", "web")]
        [string]$Platform,
        [Parameter(Mandatory)]
        [string]$FinalAuditPath,
        [AllowNull()]
        [object]$RegisteredPlatform = $null,
        [switch]$UseExistingStage
    )

    $candidate = [IO.Path]::GetFullPath($CandidateRoot).TrimEnd([char[]]@('\', '/'))
    $work = [IO.Path]::GetFullPath($WorkRoot).TrimEnd([char[]]@('\', '/'))
    if ($candidate.Equals($work, [StringComparison]::OrdinalIgnoreCase) -or
        (Test-ExportPathInside -Path $work -Directory $candidate) -or
        (Test-ExportPathInside -Path $candidate -Directory $work)) {
        throw "Candidate and retry-work roots must be separate directory trees."
    }

    $finalStage = [IO.Path]::GetFullPath((Join-Path $candidate $Platform))
    $finalAudit = [IO.Path]::GetFullPath($FinalAuditPath)
    if (-not (Test-ExportPathInside -Path $finalStage -Directory $candidate) -or
        -not (Test-ExportPathInside -Path $finalAudit -Directory $candidate)) {
        throw "Candidate platform and audit paths must remain inside the candidate root."
    }

    if ($null -ne $RegisteredPlatform) {
        if (-not (Test-Path -LiteralPath $finalStage -PathType Container)) {
            throw "Registered immutable candidate stage is missing: $finalStage"
        }
        if (-not (Test-Path -LiteralPath $finalAudit -PathType Leaf)) {
            throw "Registered immutable candidate audit is missing: $finalAudit"
        }
        return [pscustomobject][ordered]@{
            reuse_registered = $true
            publish_required = $false
            stage_already_final = $true
            final_stage = $finalStage
            final_audit = $finalAudit
            attempt_stage = $finalStage
            attempt_audit = $finalAudit
            recovered_stage = $null
            recovered_audit = $null
        }
    }

    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $recoveredStage = $null
    $recoveredAudit = $null
    if ($UseExistingStage) {
        if (-not (Test-Path -LiteralPath $finalStage -PathType Container) -or
            @(Get-ChildItem -LiteralPath $finalStage -Force).Count -eq 0) {
            throw "Existing candidate output is required for -SkipExport: $finalStage"
        }
    }
    else {
        $hasStage = Test-Path -LiteralPath $finalStage
        $hasAudit = Test-Path -LiteralPath $finalAudit
        if ($hasStage -or $hasAudit) {
            $recoveryRoot = Join-Path $work ("recovered/{0}_{1}" -f [datetime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"), [guid]::NewGuid().ToString("N"))
            New-Item -ItemType Directory -Force -Path $recoveryRoot | Out-Null
            if ($hasStage) {
                $recoveredStage = Join-Path $recoveryRoot "stage"
                Move-Item -LiteralPath $finalStage -Destination $recoveredStage
            }
            if ($hasAudit) {
                $auditRecoveryRoot = Join-Path $recoveryRoot "audit"
                New-Item -ItemType Directory -Force -Path $auditRecoveryRoot | Out-Null
                $recoveredAudit = Join-Path $auditRecoveryRoot (Split-Path -Leaf $finalAudit)
                Move-Item -LiteralPath $finalAudit -Destination $recoveredAudit
            }
        }
    }

    if ($UseExistingStage -and (Test-Path -LiteralPath $finalAudit)) {
        $auditRecoveryRoot = Join-Path $work ("recovered/{0}_{1}/audit" -f [datetime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ"), [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $auditRecoveryRoot | Out-Null
        $recoveredAudit = Join-Path $auditRecoveryRoot (Split-Path -Leaf $finalAudit)
        Move-Item -LiteralPath $finalAudit -Destination $recoveredAudit
    }

    $attemptRoot = Join-Path $work ("active/{0}" -f [guid]::NewGuid().ToString("N"))
    $attemptStage = if ($UseExistingStage) { $finalStage } else { Join-Path $attemptRoot "stage" }
    $attemptAudit = Join-Path $attemptRoot "audit.json"
    New-Item -ItemType Directory -Force -Path $attemptRoot | Out-Null
    if (-not $UseExistingStage) {
        New-Item -ItemType Directory -Force -Path $attemptStage | Out-Null
    }

    return [pscustomobject][ordered]@{
        reuse_registered = $false
        publish_required = $true
        stage_already_final = [bool]$UseExistingStage
        final_stage = $finalStage
        final_audit = $finalAudit
        attempt_stage = $attemptStage
        attempt_audit = $attemptAudit
        recovered_stage = $recoveredStage
        recovered_audit = $recoveredAudit
    }
}

function Complete-CandidatePlatformAttempt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Attempt
    )

    if ([bool]$Attempt.reuse_registered) {
        return $Attempt
    }

    $attemptStage = [IO.Path]::GetFullPath([string]$Attempt.attempt_stage)
    $attemptAudit = [IO.Path]::GetFullPath([string]$Attempt.attempt_audit)
    $finalStage = [IO.Path]::GetFullPath([string]$Attempt.final_stage)
    $finalAudit = [IO.Path]::GetFullPath([string]$Attempt.final_audit)
    if (-not (Test-Path -LiteralPath $attemptStage -PathType Container) -or
        @(Get-ChildItem -LiteralPath $attemptStage -Force).Count -eq 0) {
        throw "Candidate attempt has no export payload: $attemptStage"
    }
    if (-not (Test-Path -LiteralPath $attemptAudit -PathType Leaf)) {
        throw "Candidate attempt audit is missing: $attemptAudit"
    }
    if (Test-Path -LiteralPath $finalAudit) {
        throw "Refusing to overwrite an existing candidate audit: $finalAudit"
    }

    if (-not [bool]$Attempt.stage_already_final) {
        if (Test-Path -LiteralPath $finalStage) {
            throw "Refusing to overwrite an existing candidate stage: $finalStage"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $finalStage) | Out-Null
        Move-Item -LiteralPath $attemptStage -Destination $finalStage
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $finalAudit) | Out-Null
    Move-Item -LiteralPath $attemptAudit -Destination $finalAudit
    return $Attempt
}
