param()

$ErrorActionPreference = "Stop"
$sourcePath = Join-Path $PSScriptRoot "serve_web.ps1"
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw "Local Web wrapper has a PowerShell parse error." }
$guards = @($ast.EndBlock.Statements | Where-Object {
    $_ -is [System.Management.Automation.Language.IfStatementAst] -and
    $_.Extent.Text.Contains('Refusing to serve a directory outside the workspace:')
})
if ($guards.Count -ne 1) { throw "Expected exactly one workspace containment guard." }
$guard = [scriptblock]::Create($guards[0].Extent.Text)

# Execute only the real path guard, without starting Python, a listener or a browser.
$cases = @(
    @{ name = "workspace itself"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace'; accepted = $true },
    @{ name = "child"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace\builds\web'; accepted = $true },
    @{ name = "nested child with spaces"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace\builds\web build\nested'; accepted = $true },
    @{ name = "case insensitive child"; root = 'C:\cleanup workspace'; path = 'c:\CLEANUP WORKSPACE\builds'; accepted = $true },
    @{ name = "normalized child"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace\builds\..\web'; accepted = $true },
    @{ name = "root trailing separator"; root = 'C:\cleanup workspace\'; path = 'C:\cleanup workspace\builds'; accepted = $true },
    @{ name = "drive root itself"; root = 'C:\'; path = 'C:\'; accepted = $true },
    @{ name = "drive root child"; root = 'C:\'; path = 'C:\builds\web'; accepted = $true },
    @{ name = "prefixed sibling"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace-backup\web'; accepted = $false },
    @{ name = "prefixed dotted sibling"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace.tmp\web'; accepted = $false },
    @{ name = "prefixed numbered sibling"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace2\web'; accepted = $false },
    @{ name = "parent escape"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace\..\other\web'; accepted = $false },
    @{ name = "normalized prefix escape"; root = 'C:\cleanup workspace'; path = 'C:\cleanup workspace\..\cleanup workspace-backup\web'; accepted = $false },
    @{ name = "parent"; root = 'C:\cleanup workspace'; path = 'C:\'; accepted = $false },
    @{ name = "other drive"; root = 'C:\cleanup workspace'; path = 'D:\cleanup workspace\web'; accepted = $false },
    @{ name = "UNC descendant"; root = '\\host\share\workspace'; path = '\\host\share\workspace\web'; accepted = $true },
    @{ name = "UNC prefixed sibling"; root = '\\host\share\workspace'; path = '\\host\share\workspace-backup\web'; accepted = $false }
)
foreach ($case in $cases) {
    $workspaceRoot = [System.IO.Path]::GetFullPath($case.root)
    $webDir = [System.IO.Path]::GetFullPath($case.path)
    $accepted = $true
    try { & $guard }
    catch {
        if ($_.Exception.Message -cne "Refusing to serve a directory outside the workspace: $webDir") { throw }
        $accepted = $false
    }
    if ($accepted -ne $case.accepted) { throw "Workspace path case failed: $($case.name)" }
}
Write-Output "SERVE_WEB_PATH_CONTRACT PASS cases=$($cases.Count) no_server_started=true"
