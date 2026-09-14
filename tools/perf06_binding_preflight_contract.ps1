function Get-Perf06BindingPorts {
    return @(
        18141,
        18619, 18620, 18621, 18622, 18623,
        18730, 18731, 18732, 18733, 18734, 18735
    )
}

function Assert-Perf06CleanWorktree {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

    $resolvedRoot = [IO.Path]::GetFullPath($RepositoryRoot)
    $status = @(& git -C $resolvedRoot status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect the binding worktree: $resolvedRoot"
    }
    if ($status.Count -eq 0) {
        return
    }

    $categories = [Collections.Generic.List[string]]::new()
    if (@($status | Where-Object { $_.StartsWith("?? ") }).Count -gt 0) {
        $categories.Add("nonignored untracked files")
    }
    if (@($status | Where-Object { -not $_.StartsWith("?? ") }).Count -gt 0) {
        $categories.Add("tracked/index changes")
    }
    $preview = @($status | Select-Object -First 8) -join "; "
    throw "Binding worktree is not exact-source clean ($($categories -join ' and ')): $preview"
}

function Assert-Perf06BindingPortsAvailable {
    param([Parameter(Mandatory = $true)][int[]]$Ports)

    $requiredPorts = @($Ports | Sort-Object -Unique)
    if ($requiredPorts.Count -eq 0 -or @($requiredPorts | Where-Object { $_ -lt 1 -or $_ -gt 65535 }).Count -gt 0) {
        throw "Binding port contract contains an empty or invalid port set."
    }

    try {
        $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object { $requiredPorts -contains [int]$_.LocalPort })
    }
    catch {
        throw "Could not inspect binding ports fail-closed: $($_.Exception.Message)"
    }
    if ($listeners.Count -eq 0) {
        return
    }

    $owners = @($listeners | Sort-Object LocalPort, OwningProcess | ForEach-Object {
        $process = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        $name = if ($null -ne $process) { [string]$process.ProcessName } else { "unknown" }
        "port=$($_.LocalPort) pid=$($_.OwningProcess) process=$name"
    })
    throw "Binding run requires every reserved port to be free: $($owners -join '; ')"
}
