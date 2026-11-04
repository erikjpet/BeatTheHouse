# No exporter, browser, game, fixture cleanup or external publication is invoked.
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "export_itch_helpers.ps1")
$tool = Join-Path $PSScriptRoot "web_gl_handles.mjs"
$script:seen = [Collections.Generic.List[object]]::new()
$script:mockExit = 0
function Assert-Contract([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Invoke-TypedConsoleProcess { param([string]$FilePath,[string[]]$ArgumentList) $script:seen.Add(@($ArgumentList)); return [int]$script:mockExit }
Invoke-WebGlHandlesStage -Platform windows -Mode apply -Stage "unresolved-windows" -ToolPath "missing-tool"
Assert-Contract ($script:seen.Count -eq 0) "Windows must not resolve or invoke Web policy."
Invoke-WebGlHandlesStage -Platform web -Mode apply -Stage "owned/stage" -OwnedRoot "owned" -ToolPath $tool
Assert-Contract (($script:seen[0] -join '|') -eq "$tool|apply|--stage|owned/stage|--owned-root|owned") "Fresh Web must apply to owned stage."
foreach ($route in @('SkipExport','registered','packaging')) {
    Invoke-WebGlHandlesStage -Platform web -Mode verify -Stage "immutable/$route" -ToolPath $tool
    $argsSeen = $script:seen[$script:seen.Count - 1]
    Assert-Contract (($argsSeen -join '|') -eq "$tool|verify|--stage|immutable/$route") "$route must verify without mutation."
}
$script:mockExit = 7
$script:trace = [Collections.Generic.List[string]]::new()
$rejected = $false
try {
    Invoke-WebExportPipeline -ExportAction { return [int]0 } -AuditAction {
        $script:trace.Add('audit')
        Invoke-WebGlHandlesStage -Platform web -Mode apply -Stage "owned/stage" -OwnedRoot "owned" -ToolPath $tool
    } -CustodyAction { $script:trace.Add('custody') } -RegistrationAction { $script:trace.Add('registration') }
}
catch { $rejected = $_.Exception.Message -like '*Web GL handle policy rejected apply with exit 7*' }
Assert-Contract $rejected "Audit-side policy nonzero must throw."
Assert-Contract (($script:trace -join '|') -eq 'audit') "Failed mitigation must prevent custody and registration."
$exporter = Get-Content -LiteralPath (Join-Path $PSScriptRoot "export_itch.ps1") -Raw
Assert-Contract ($exporter.Contains('Invoke-WebGlHandlesStage -Platform $platform -Mode verify -Stage $registeredAttempt.final_stage')) "Registered path must verify before continue."
Assert-Contract ($exporter.Contains('Invoke-WebGlHandlesStage -Platform $required -Mode verify -Stage $stage')) "Packaging must reverify current policy."
Assert-Contract ($exporter.Contains('if ($SkipExport) {') -and $exporter.Contains('-Platform web -Mode verify -Stage $stage')) "SkipExport needs immutable verification."
$applyIndex = $exporter.IndexOf('-Platform web -Mode apply')
$auditIndex = $exporter.IndexOf('        Assert-CleanDistributionOutput $stage')
Assert-Contract ($applyIndex -ge 0 -and $auditIndex -ge 0 -and $applyIndex -lt $auditIndex) "Fresh apply must precede audit/custody."
$registered = $exporter.Substring($exporter.IndexOf('if ($null -ne $registeredPlatform)'), $exporter.IndexOf('    $attempt = Initialize-CandidatePlatformAttempt') - $exporter.IndexOf('if ($null -ne $registeredPlatform)'))
Assert-Contract ($registered.IndexOf('Invoke-WebGlHandlesStage') -lt $registered.IndexOf('continue')) "Registered continue must not bypass verification."
Write-Host "WEB GL HANDLE EXPORT CONTRACT PASS"
