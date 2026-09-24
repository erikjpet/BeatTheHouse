param(
    [string]$GodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe',
    [string]$EvidenceRoot = '',
    [string]$ExpectedCommit = '',
    [string]$ExpectedTree = '',
    [string]$CounterpartRoot = '',
    [string]$ExpectedCounterpartCommit = '',
    [string]$ExpectedCounterpartTree = '',
    [string]$ExpectedLauncherSha256 = '',
    [string]$ExpectedLauncherGitBlob = '',
    [string]$ExpectedGuardSha256 = '',
    [string]$ExpectedGuardGitBlob = '',
    [string]$ExpectedFullContractSha256 = '',
    [string]$ExpectedFullContractGitBlob = '',
    [string]$ExpectedGodotSha256 = 'FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE',
    [string]$ExpectedGodotVersion = '4.6.stable.official',
    [ValidateSet('Red', 'Green')]
    [string]$ExpectedOutcome = '',
    [int]$LeaseWaitTimeoutSec = 900,
    [int]$ProcessTimeoutSec = 180,
    [switch]$AuthorizeGreen,
    [switch]$ValidateOnly,
    [switch]$ProcessProbeChild,
    [switch]$ProcessProbeTreeRoot,
    [switch]$ProcessProbeTreeIntermediate,
    [string]$ProbePidDirectory = '',
    [string]$ProbePidPrefix = '',
    [int]$ProbeLeafSleepMsec = 0,
    [switch]$ProbeTreeWaitLeaf,
    [int]$ProbeExitCode = 0,
    [int]$ProbeSleepMsec = 0,
    [int]$ProbeVolumeBytes = 0,
    [string]$ProbeEcho = '',
    [string]$ProbeTrailing = '',
    [string]$ProbeEmpty = '__unset__'
)

$ErrorActionPreference = 'Stop'

if ($ProcessProbeTreeRoot -or $ProcessProbeTreeIntermediate) {
    if ([string]::IsNullOrWhiteSpace($ProbePidDirectory) -or -not (Test-Path -LiteralPath $ProbePidDirectory -PathType Container)) {
        throw 'Three-level process probe requires an existing PID directory.'
    }
    if ($ProbePidPrefix -cnotmatch '^[a-z0-9-]+$') { throw 'Three-level process probe prefix is malformed.' }
    $probePowerShell = Join-Path $PSHOME 'powershell.exe'
    $probeStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $probeStartInfo.FileName = $probePowerShell
    $probeStartInfo.UseShellExecute = $false
    $probeStartInfo.CreateNoWindow = $true
    if ($ProcessProbeTreeRoot) {
        [System.IO.File]::WriteAllText((Join-Path $ProbePidDirectory ($ProbePidPrefix + '-root.pid')), [string]$PID)
        $treeArguments = @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
            '-ProcessProbeTreeIntermediate', '-ProbePidDirectory', $ProbePidDirectory,
            '-ProbePidPrefix', $ProbePidPrefix, '-ProbeLeafSleepMsec', [string]$ProbeLeafSleepMsec
        )
        if ($ProbeTreeWaitLeaf) { $treeArguments += '-ProbeTreeWaitLeaf' }
        $probeStartInfo.Arguments = (@($treeArguments) | ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }) -join ' '
        $intermediate = [System.Diagnostics.Process]::Start($probeStartInfo)
        [System.IO.File]::WriteAllText((Join-Path $ProbePidDirectory ($ProbePidPrefix + '-root-child.pid')), [string]$intermediate.Id)
        if ($ProbeTreeWaitLeaf -and -not $intermediate.WaitForExit(15000)) { exit 3 }
        exit 0
    }
    [System.IO.File]::WriteAllText((Join-Path $ProbePidDirectory ($ProbePidPrefix + '-intermediate.pid')), [string]$PID)
    $leafArguments = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
        '-ProcessProbeChild', '-ProbeSleepMsec', [string]$ProbeLeafSleepMsec, '-ProbeExitCode', '0'
    )
    $probeStartInfo.Arguments = (@($leafArguments) | ForEach-Object { '"' + ([string]$_).Replace('"', '\"') + '"' }) -join ' '
    $leaf = [System.Diagnostics.Process]::Start($probeStartInfo)
    [System.IO.File]::WriteAllText((Join-Path $ProbePidDirectory ($ProbePidPrefix + '-leaf.pid')), [string]$leaf.Id)
    if ($ProbeTreeWaitLeaf -and -not $leaf.WaitForExit(15000)) { exit 3 }
    exit 0
}

if ($ProcessProbeChild) {
    if ($ProbeSleepMsec -gt 0) {
        Start-Sleep -Milliseconds $ProbeSleepMsec
    }
    $probePayload = [ordered]@{
        echo = $ProbeEcho
        trailing = $ProbeTrailing
        empty = $ProbeEmpty
    } | ConvertTo-Json -Compress
    [Console]::Out.WriteLine('RW06_6_PROCESS_PROBE_STDOUT ' + $probePayload)
    [Console]::Error.WriteLine('RW06_6_PROCESS_PROBE_STDERR ' + $probePayload)
    if ($ProbeVolumeBytes -gt 0) {
        [Console]::Out.Write(('O' * $ProbeVolumeBytes))
        [Console]::Error.Write(('E' * $ProbeVolumeBytes))
        [Console]::Out.WriteLine('RW06_6_PROCESS_PROBE_STDOUT_END')
        [Console]::Error.WriteLine('RW06_6_PROCESS_PROBE_STDERR_END')
    }
    exit $ProbeExitCode
}

$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$canonicalGodotPath = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
$canonicalGodotSha256 = 'FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE'
$canonicalGodotVersion = '4.6.stable.official'
$canonicalLeaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
$leaseRoot = [System.IO.Path]::GetFullPath($canonicalLeaseRoot)
$exclusiveLeasePath = Join-Path $leaseRoot 'EXCLUSIVE.lease'
$launchMutexName = 'Global\BeatTheHouse-Q009-GodotLaunch'
$guardRelativePath = 'scripts/tests/fixtures/rw06_6_pull_tab_glimmer_source_guard.gd'
$guardScriptPath = 'res://scripts/tests/fixtures/rw06_6_pull_tab_glimmer_source_guard.gd'
$fullContractRelativePath = 'scripts/tests/rw06_6_pull_tab_glimmer_contract.gd'
$fullContractScriptPath = 'res://scripts/tests/rw06_6_pull_tab_glimmer_contract.gd'
$productRelativePath = 'scripts/games/pull_tabs.gd'
$foundationRelativePath = 'scripts/tests/foundation/check_table_games.gd'
$launcherRelativePath = 'tools/rw06_6_pull_tab_glimmer_contract.ps1'
$splitRunnerHelperRelativePath = 'tools/split_test_runner_helpers.ps1'
$foundationSplitSourceRelativePaths = @(
    'scripts/tests/foundation/check_core_content.gd',
    'scripts/tests/foundation/check_slots_surfaces.gd',
    'scripts/tests/foundation/check_table_games.gd',
    'scripts/tests/foundation/check_items_events_world.gd',
    'scripts/tests/foundation/check_delivery_runs.gd',
    'scripts/tests/foundation/check_lenders_release_saves.gd',
    'scripts/tests/foundation/check_scratch_tickets.gd',
    'scripts/tests/foundation/check_cage_environment_rework.gd',
    'scripts/tests/foundation/check_coin_pusher.gd'
)
$preFeatureBaseCommit = 'c4f5874a466ec01f09ee706d946425a3e0044dd0'
$canonicalRepoRoot = 'D:\Projects\Beat-The-House'
$ownerQuestionsRelativePath = 'docs/todo/rw06_owner_questions.md'
$ownerQuestionsPath = 'D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md'
$projectCacheRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot'))
$globalClassCachePath = Join-Path $projectCacheRoot 'global_script_class_cache.cfg'
$uidCachePath = Join-Path $projectCacheRoot 'uid_cache.bin'
$importedRoot = Join-Path $projectCacheRoot 'imported'
$approvedEvidenceParent = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp\rw06_6\evidence'))
$nativeExitSentinel = [int]::MinValue
$script:rw06RetainedArtifactReceipts = $null
$script:rw06ActiveOwnedJobs = [System.Collections.Generic.List[object]]::new()


function Assert-LauncherContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}


function Test-ExactHexIdentity {
    param([string]$Value, [int]$Length)
    return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -cmatch ('^[0-9A-Fa-f]{' + $Length + '}$')
}


function Get-CanonicalGodotIdentity {
    param(
        [string]$RequestedPath,
        [string]$RequiredSha256,
        [string]$RequiredVersion
    )
    if ($RequestedPath -cne $canonicalGodotPath) {
        throw "GodotPath must be the exact canonical console path: $canonicalGodotPath"
    }
    if ($RequiredSha256 -cne $canonicalGodotSha256 -or $RequiredVersion -cne $canonicalGodotVersion) {
        throw 'Expected Godot SHA-256/version must equal the release-pinned canonical engine identity.'
    }
    $resolved = [System.IO.Path]::GetFullPath($RequestedPath)
    if ($resolved -cne $canonicalGodotPath -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw 'Canonical Godot 4.6 console is unavailable or was supplied through an alias.'
    }
    $guard = [System.IO.FileStream]::new($resolved, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $readback = Read-NormalFilePinned -Path $resolved
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($resolved)
        if ([string]$readback.sha256 -cne $RequiredSha256 -or [string]$versionInfo.ProductVersion -cne $RequiredVersion) {
            throw 'Canonical Godot executable SHA-256 or product version drifted.'
        }
        return [ordered]@{
            canonical_path = $canonicalGodotPath
            requested_path = $RequestedPath
            resolved_path = $resolved
            sha256 = [string]$readback.sha256
            product_version = [string]$versionInfo.ProductVersion
            file_version = [string]$versionInfo.FileVersion
            company_name = [string]$versionInfo.CompanyName
            length = [long]$readback.length
            last_write_utc = [string]$readback.identity.last_write_utc
            native_identity = $readback.identity
            launch_receipt = [ordered]@{
                path = $resolved
                sha256 = [string]$readback.sha256
                identity = $readback.identity
            }
            reparse_point = $false
            accepted = $true
        }
    }
    finally {
        $guard.Dispose()
    }
}


function Initialize-Rw06NativeFileIdentityType {
    if ($null -ne ('Rw06FileIdentityNative' -as [type])) { return }
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public sealed class Rw06DirectoryGuardIdentityReceipt {
    public string Path { get; private set; }
    public string NativeKey { get; private set; }
    public long CreationTicks { get; private set; }
    public bool IsDirectory { get; private set; }
    public bool ReparsePoint { get; private set; }

    internal Rw06DirectoryGuardIdentityReceipt(string path, string nativeKey, long creationTicks, bool isDirectory, bool reparsePoint) {
        Path = path;
        NativeKey = nativeKey;
        CreationTicks = creationTicks;
        IsDirectory = isDirectory;
        ReparsePoint = reparsePoint;
    }
}

public sealed class Rw06DirectoryGuardRenameReceipt {
    public string SourcePath { get; private set; }
    public string DestinationPath { get; private set; }
    public string NativeKey { get; private set; }
    public long CreationTicks { get; private set; }
    public bool SameHandle { get; private set; }
    public bool NoReplace { get; private set; }
    public bool OriginalAbsent { get; private set; }
    public bool DestinationIdentityVerified { get; private set; }
    public string RenamedUtc { get; private set; }

    internal Rw06DirectoryGuardRenameReceipt(
        string sourcePath,
        string destinationPath,
        string nativeKey,
        long creationTicks,
        bool originalAbsent,
        bool destinationIdentityVerified
    ) {
        SourcePath = sourcePath;
        DestinationPath = destinationPath;
        NativeKey = nativeKey;
        CreationTicks = creationTicks;
        SameHandle = true;
        NoReplace = true;
        OriginalAbsent = originalAbsent;
        DestinationIdentityVerified = destinationIdentityVerified;
        RenamedUtc = DateTime.UtcNow.ToString("o");
    }
}

public sealed class Rw06DirectoryGuardCloseReceipt {
    public string Contract { get; private set; }
    public string Path { get; private set; }
    public string Disposition { get; private set; }
    public string NativeKey { get; private set; }
    public long CreationTicks { get; private set; }
    public bool CloseAttempted { get; private set; }
    public bool NativeCloseSucceeded { get; private set; }
    public bool ReportedSuccess { get; private set; }
    public int Win32Error { get; private set; }
    public bool ForcedReportedFailure { get; private set; }
    public string ClosedUtc { get; private set; }

    internal Rw06DirectoryGuardCloseReceipt(
        string path,
        string disposition,
        string nativeKey,
        long creationTicks,
        bool nativeCloseSucceeded,
        bool reportedSuccess,
        int win32Error,
        bool forcedReportedFailure
    ) {
        Contract = "rw06_6_directory_guard_checked_close_v1";
        Path = path;
        Disposition = disposition;
        NativeKey = nativeKey;
        CreationTicks = creationTicks;
        CloseAttempted = true;
        NativeCloseSucceeded = nativeCloseSucceeded;
        ReportedSuccess = reportedSuccess;
        Win32Error = win32Error;
        ForcedReportedFailure = forcedReportedFailure;
        ClosedUtc = DateTime.UtcNow.ToString("o");
    }
}

public sealed class Rw06ExclusiveDirectoryGuardReceipt {
    internal readonly object SyncRoot = new object();
    internal SafeFileHandle GuardHandle;
    public string Path { get; internal set; }
    public string CurrentPath { get; internal set; }
    public string CreationNativeKey { get; internal set; }
    public long CreationTicks { get; internal set; }
    public string CustodyNativeKey { get; internal set; }
    public long CustodyCreationTicks { get; internal set; }
    public bool CreatedExclusive { get; internal set; }
    public bool ReplacementProbeRejected { get; internal set; }
    public bool RenamedThroughGuard { get; internal set; }
    public bool DeleteDispositionSet { get; internal set; }
    public bool CloseAttempted { get; internal set; }
    public bool NativeCloseSucceeded { get; internal set; }
    public bool CloseReportedSuccess { get; internal set; }
    public int CloseWin32Error { get; internal set; }
    public bool ForcedCloseReportedFailure { get; internal set; }
    public Rw06DirectoryGuardCloseReceipt CloseReceipt { get; internal set; }

    public bool GuardLive {
        get {
            lock (SyncRoot) {
                return !CloseAttempted && GuardHandle != null && !GuardHandle.IsClosed && !GuardHandle.IsInvalid;
            }
        }
    }

    internal Rw06ExclusiveDirectoryGuardReceipt(SafeFileHandle guardHandle, string path) {
        GuardHandle = guardHandle;
        Path = path;
        CurrentPath = path;
        CreationNativeKey = "";
        CustodyNativeKey = "";
        CreatedExclusive = true;
    }
}

public static class Rw06FileIdentityNative {
    [StructLayout(LayoutKind.Sequential)]
    private struct FILETIME {
        public uint Low;
        public uint High;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct BY_HANDLE_FILE_INFORMATION {
        public uint FileAttributes;
        public FILETIME CreationTime;
        public FILETIME LastAccessTime;
        public FILETIME LastWriteTime;
        public uint VolumeSerialNumber;
        public uint FileSizeHigh;
        public uint FileSizeLow;
        public uint NumberOfLinks;
        public uint FileIndexHigh;
        public uint FileIndexLow;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct UNICODE_STRING {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct OBJECT_ATTRIBUTES {
        public int Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public uint Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IO_STATUS_BLOCK {
        public IntPtr Status;
        public IntPtr Information;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        IntPtr securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandle(
        SafeFileHandle handle,
        out BY_HANDLE_FILE_INFORMATION info
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("ntdll.dll")]
    private static extern int NtCreateFile(
        out IntPtr fileHandle,
        uint desiredAccess,
        ref OBJECT_ATTRIBUTES objectAttributes,
        out IO_STATUS_BLOCK ioStatusBlock,
        IntPtr allocationSize,
        uint fileAttributes,
        uint shareAccess,
        uint createDisposition,
        uint createOptions,
        IntPtr eaBuffer,
        uint eaLength
    );

    [DllImport("ntdll.dll")]
    private static extern uint RtlNtStatusToDosError(int status);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool MoveFileExW(string existingFileName, string newFileName, uint flags);

    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_DISPOSITION_INFO {
        [MarshalAs(UnmanagedType.Bool)]
        public bool DeleteFile;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_DISPOSITION_INFO_EX {
        public uint Flags;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct FILE_BASIC_INFO {
        public long CreationTime;
        public long LastAccessTime;
        public long LastWriteTime;
        public long ChangeTime;
        public uint FileAttributes;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetFileInformationByHandle(
        SafeFileHandle handle,
        int fileInformationClass,
        ref FILE_DISPOSITION_INFO fileInformation,
        uint bufferSize
    );

    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    private static extern bool SetFileRenameInformationByHandle(
        SafeFileHandle handle,
        int fileInformationClass,
        IntPtr fileInformation,
        uint bufferSize
    );

    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    private static extern bool SetExtendedFileDispositionByHandle(
        SafeFileHandle handle,
        int fileInformationClass,
        ref FILE_DISPOSITION_INFO_EX fileInformation,
        uint bufferSize
    );

    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    private static extern bool SetBasicFileInformationByHandle(
        SafeFileHandle handle,
        int fileInformationClass,
        ref FILE_BASIC_INFO fileInformation,
        uint bufferSize
    );

    private sealed class OwnedEntry : IDisposable {
        public string RelativePath;
        public string FullPath;
        public bool IsDirectory;
        public uint FileAttributes;
        public SafeFileHandle Handle;

        public void Dispose() {
            if (Handle != null) {
                Handle.Dispose();
                Handle = null;
            }
        }
    }

    private static string IdentityFromInfo(BY_HANDLE_FILE_INFORMATION info) {
        return String.Format("{0:X8}:{1:X8}{2:X8}", info.VolumeSerialNumber, info.FileIndexHigh, info.FileIndexLow);
    }

    private static long CreationTicksFromInfo(BY_HANDLE_FILE_INFORMATION info) {
        long fileTime = ((long)info.CreationTime.High << 32) | (long)info.CreationTime.Low;
        return DateTime.FromFileTimeUtc(fileTime).Ticks;
    }

    private static SafeFileHandle OpenForExactDelete(string path, bool directory, out BY_HANDLE_FILE_INFORMATION info) {
        const uint FILE_READ_ATTRIBUTES = 0x80;
        const uint FILE_WRITE_ATTRIBUTES = 0x100;
        const uint DELETE = 0x00010000;
        const uint FILE_SHARE_READ = 0x1;
        const uint OPEN_EXISTING = 3;
        const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
        const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
        uint flags = FILE_FLAG_OPEN_REPARSE_POINT | (directory ? FILE_FLAG_BACKUP_SEMANTICS : 0);
        SafeFileHandle handle = CreateFileW(
            path,
            FILE_READ_ATTRIBUTES | FILE_WRITE_ATTRIBUTES | DELETE,
            FILE_SHARE_READ,
            IntPtr.Zero,
            OPEN_EXISTING,
            flags,
            IntPtr.Zero
        );
        if (handle.IsInvalid) {
            handle.Dispose();
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not exclusively open exact owned deletion entry: " + path);
        }
        if (!GetFileInformationByHandle(handle, out info)) {
            int error = Marshal.GetLastWin32Error();
            handle.Dispose();
            throw new Win32Exception(error, "Could not inspect exact owned deletion entry: " + path);
        }
        return handle;
    }

    private static void SetDeleteDispositionByHandle(SafeFileHandle handle, uint fileAttributes, string fullPath) {
        const uint FILE_ATTRIBUTE_READONLY = 0x1;
        if ((fileAttributes & FILE_ATTRIBUTE_READONLY) != 0) {
            FILE_BASIC_INFO basic = new FILE_BASIC_INFO {
                CreationTime = 0,
                LastAccessTime = 0,
                LastWriteTime = 0,
                ChangeTime = 0,
                FileAttributes = fileAttributes & ~FILE_ATTRIBUTE_READONLY
            };
            if (!SetBasicFileInformationByHandle(
                handle,
                0,
                ref basic,
                (uint)Marshal.SizeOf(typeof(FILE_BASIC_INFO))
            )) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not clear read-only state on exact owned entry: " + fullPath);
            }
        }
        const uint FILE_DISPOSITION_FLAG_DELETE = 0x1;
        const uint FILE_DISPOSITION_FLAG_POSIX_SEMANTICS = 0x2;
        const uint FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE = 0x10;
        FILE_DISPOSITION_INFO_EX extendedDisposition = new FILE_DISPOSITION_INFO_EX {
            Flags = FILE_DISPOSITION_FLAG_DELETE | FILE_DISPOSITION_FLAG_POSIX_SEMANTICS | FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE
        };
        if (SetExtendedFileDispositionByHandle(
            handle,
            21,
            ref extendedDisposition,
            (uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO_EX))
        )) {
            return;
        }
        FILE_DISPOSITION_INFO disposition = new FILE_DISPOSITION_INFO { DeleteFile = true };
        if (!SetFileInformationByHandle(
            handle,
            4,
            ref disposition,
            (uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO))
        )) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not mark exact owned entry for handle-bound deletion: " + fullPath);
        }
    }

    private static void MarkDeleteByHandle(OwnedEntry entry) {
        SetDeleteDispositionByHandle(entry.Handle, entry.FileAttributes, entry.FullPath);
        entry.Dispose();
        if (File.Exists(entry.FullPath) || Directory.Exists(entry.FullPath)) {
            throw new IOException("Handle-bound deletion did not remove exact owned entry: " + entry.FullPath);
        }
    }

    private static string[] EnumerateTreeNoReparse(string rootPath) {
        List<string> paths = new List<string>();
        Stack<string> pending = new Stack<string>();
        pending.Push(rootPath);
        while (pending.Count > 0) {
            string directory = pending.Pop();
            foreach (string child in Directory.GetFileSystemEntries(directory)) {
                FileAttributes attributes = File.GetAttributes(child);
                if ((attributes & FileAttributes.ReparsePoint) != 0) {
                    throw new IOException("Exact owned deletion tree contains a reparse point: " + child);
                }
                paths.Add(child);
                if ((attributes & FileAttributes.Directory) != 0) {
                    pending.Push(child);
                }
            }
        }
        return paths.ToArray();
    }

    public static string GetIdentity(string path, bool directory) {
        const uint FILE_READ_ATTRIBUTES = 0x80;
        const uint FILE_SHARE_READ = 0x1;
        const uint FILE_SHARE_WRITE = 0x2;
        const uint FILE_SHARE_DELETE = 0x4;
        const uint OPEN_EXISTING = 3;
        const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
        const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
        uint flags = FILE_FLAG_OPEN_REPARSE_POINT | (directory ? FILE_FLAG_BACKUP_SEMANTICS : 0);
        using (SafeFileHandle handle = CreateFileW(
            path,
            FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            IntPtr.Zero,
            OPEN_EXISTING,
            flags,
            IntPtr.Zero
        )) {
            if (handle.IsInvalid) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open filesystem entry for exact identity.");
            }
            BY_HANDLE_FILE_INFORMATION info;
            if (!GetFileInformationByHandle(handle, out info)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read exact filesystem identity.");
            }
            return IdentityFromInfo(info);
        }
    }

    private static SafeFileHandle RequireLiveDirectoryGuardNoLock(Rw06ExclusiveDirectoryGuardReceipt receipt) {
        if (receipt == null || receipt.CloseAttempted || receipt.GuardHandle == null || receipt.GuardHandle.IsClosed || receipt.GuardHandle.IsInvalid) {
            throw new IOException("The exact owned directory creation/custody handle is not live.");
        }
        return receipt.GuardHandle;
    }

    private static Rw06DirectoryGuardIdentityReceipt ReadDirectoryGuardIdentityNoLock(Rw06ExclusiveDirectoryGuardReceipt receipt) {
        const uint FILE_ATTRIBUTE_DIRECTORY = 0x10;
        const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
        SafeFileHandle handle = RequireLiveDirectoryGuardNoLock(receipt);
        BY_HANDLE_FILE_INFORMATION info;
        if (!GetFileInformationByHandle(handle, out info)) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not inspect the exact owned directory creation/custody handle.");
        }
        return new Rw06DirectoryGuardIdentityReceipt(
            receipt.CurrentPath,
            IdentityFromInfo(info),
            CreationTicksFromInfo(info),
            (info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0,
            (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0
        );
    }

    public static Rw06DirectoryGuardIdentityReceipt AssertDirectoryGuardIdentity(
        Rw06ExclusiveDirectoryGuardReceipt receipt,
        string expectedIdentity,
        long expectedCreationTicks,
        string expectedPath
    ) {
        lock (receipt.SyncRoot) {
            string fullExpectedPath = Path.GetFullPath(expectedPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string fullCurrentPath = Path.GetFullPath(receipt.CurrentPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (!String.Equals(fullExpectedPath, fullCurrentPath, StringComparison.Ordinal)) {
                throw new IOException("The exact owned directory guard path changed unexpectedly.");
            }
            Rw06DirectoryGuardIdentityReceipt identity = ReadDirectoryGuardIdentityNoLock(receipt);
            if (!identity.IsDirectory || identity.ReparsePoint || identity.NativeKey != expectedIdentity || identity.CreationTicks != expectedCreationTicks) {
                throw new IOException("The exact owned directory creation/custody handle identity or type changed.");
            }
            string pathIdentity = GetIdentity(fullExpectedPath, true);
            if (pathIdentity != expectedIdentity) {
                throw new IOException("The guarded directory path no longer resolves to the exact creation handle identity.");
            }
            return identity;
        }
    }

    public static Rw06DirectoryGuardCloseReceipt CloseDirectoryGuardChecked(
        Rw06ExclusiveDirectoryGuardReceipt receipt,
        string disposition,
        bool forceReportedFailure
    ) {
        if (receipt == null) { throw new ArgumentNullException("receipt"); }
        lock (receipt.SyncRoot) {
            if (receipt.CloseAttempted) {
                throw new InvalidOperationException("The exact owned directory custody handle already has one checked-close attempt.");
            }
            Rw06DirectoryGuardIdentityReceipt identity = ReadDirectoryGuardIdentityNoLock(receipt);
            receipt.CloseAttempted = true;
            bool nativeCloseSucceeded = false;
            int closeError = 0;
            bool addRef = false;
            Exception releaseFailure = null;
            SafeFileHandle handle = receipt.GuardHandle;
            try {
                handle.DangerousAddRef(ref addRef);
                IntPtr rawHandle = handle.DangerousGetHandle();
                nativeCloseSucceeded = CloseHandle(rawHandle);
                closeError = nativeCloseSucceeded ? 0 : Marshal.GetLastWin32Error();
                if (nativeCloseSucceeded) {
                    handle.SetHandleAsInvalid();
                }
            }
            catch (Exception closeFailure) {
                closeError = 6;
                releaseFailure = closeFailure;
            }
            finally {
                if (addRef) {
                    try { handle.DangerousRelease(); }
                    catch (Exception dangerousReleaseFailure) { releaseFailure = dangerousReleaseFailure; }
                }
            }
            if (nativeCloseSucceeded) {
                handle.Dispose();
            }
            bool reportedSuccess = nativeCloseSucceeded && releaseFailure == null && !forceReportedFailure;
            int reportedError = forceReportedFailure && closeError == 0 ? 31 : closeError;
            receipt.NativeCloseSucceeded = nativeCloseSucceeded;
            receipt.CloseReportedSuccess = reportedSuccess;
            receipt.CloseWin32Error = reportedError;
            receipt.ForcedCloseReportedFailure = forceReportedFailure;
            receipt.CloseReceipt = new Rw06DirectoryGuardCloseReceipt(
                receipt.CurrentPath,
                disposition,
                identity.NativeKey,
                identity.CreationTicks,
                nativeCloseSucceeded,
                reportedSuccess,
                reportedError,
                forceReportedFailure
            );
            if (!reportedSuccess) {
                Exception failure = releaseFailure == null
                    ? (Exception)new Win32Exception(reportedError, "Checked close of the exact owned directory custody handle did not report success.")
                    : (Exception)new IOException("Checked close of the exact owned directory custody handle failed during handle release.", releaseFailure);
                failure.Data["directory_guard_close_receipt"] = receipt.CloseReceipt;
                failure.Data["directory_guard_owner"] = receipt;
                throw failure;
            }
            return receipt.CloseReceipt;
        }
    }

    public static Rw06DirectoryGuardRenameReceipt RenameDirectoryGuardExact(
        Rw06ExclusiveDirectoryGuardReceipt receipt,
        string sourcePath,
        string destinationPath,
        string expectedIdentity,
        long expectedCreationTicks
    ) {
        if (receipt == null) { throw new ArgumentNullException("receipt"); }
        lock (receipt.SyncRoot) {
            string fullSource = Path.GetFullPath(sourcePath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string fullDestination = Path.GetFullPath(destinationPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (!String.Equals(Path.GetDirectoryName(fullSource), Path.GetDirectoryName(fullDestination), StringComparison.Ordinal)) {
                throw new IOException("Exact owned directory quarantine must be a same-parent rename.");
            }
            if (!String.Equals(Path.GetFullPath(receipt.CurrentPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar), fullSource, StringComparison.Ordinal)) {
                throw new IOException("Exact owned directory guard is not bound to the requested quarantine source.");
            }
            if (File.Exists(fullDestination) || Directory.Exists(fullDestination)) {
                throw new IOException("Exact owned directory quarantine destination already exists.");
            }
            Rw06DirectoryGuardIdentityReceipt before = ReadDirectoryGuardIdentityNoLock(receipt);
            if (!before.IsDirectory || before.ReparsePoint || before.NativeKey != expectedIdentity || before.CreationTicks != expectedCreationTicks) {
                throw new IOException("Exact owned directory identity changed before handle-based quarantine.");
            }
            byte[] destinationBytes = System.Text.Encoding.Unicode.GetBytes(fullDestination);
            int rootDirectoryOffset = IntPtr.Size == 8 ? 8 : 4;
            int fileNameLengthOffset = rootDirectoryOffset + IntPtr.Size;
            int fileNameOffset = fileNameLengthOffset + 4;
            int bufferSize = checked(fileNameOffset + destinationBytes.Length);
            IntPtr buffer = Marshal.AllocHGlobal(bufferSize);
            try {
                byte[] zeros = new byte[bufferSize];
                Marshal.Copy(zeros, 0, buffer, bufferSize);
                Marshal.WriteInt32(buffer, 0, 0);
                Marshal.WriteIntPtr(buffer, rootDirectoryOffset, IntPtr.Zero);
                Marshal.WriteInt32(buffer, fileNameLengthOffset, destinationBytes.Length);
                Marshal.Copy(destinationBytes, 0, new IntPtr(buffer.ToInt64() + fileNameOffset), destinationBytes.Length);
                if (!SetFileRenameInformationByHandle(RequireLiveDirectoryGuardNoLock(receipt), 3, buffer, (uint)bufferSize)) {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "The exact owned directory handle could not perform its no-replace quarantine rename.");
                }
            }
            finally {
                Marshal.FreeHGlobal(buffer);
            }
            receipt.CurrentPath = fullDestination;
            receipt.RenamedThroughGuard = true;
            Rw06DirectoryGuardIdentityReceipt after = ReadDirectoryGuardIdentityNoLock(receipt);
            bool originalAbsent = !File.Exists(fullSource) && !Directory.Exists(fullSource);
            bool destinationPresent = Directory.Exists(fullDestination);
            bool destinationIdentityVerified = destinationPresent && GetIdentity(fullDestination, true) == expectedIdentity;
            if (!originalAbsent || !destinationIdentityVerified || after.NativeKey != expectedIdentity || after.CreationTicks != expectedCreationTicks || !after.IsDirectory || after.ReparsePoint) {
                throw new IOException("Handle-based exact owned directory quarantine did not retain one exact identity.");
            }
            return new Rw06DirectoryGuardRenameReceipt(
                fullSource,
                fullDestination,
                after.NativeKey,
                after.CreationTicks,
                originalAbsent,
                destinationIdentityVerified
            );
        }
    }

    public static Rw06ExclusiveDirectoryGuardReceipt CreateDirectoryIdentityGuardExclusive(
        string path,
        bool forceReplacementProbe,
        bool forceFailureAfterNativeReturn,
        bool forceCheckedCloseReportedFailure
    ) {
        const uint FILE_READ_ATTRIBUTES = 0x80;
        const uint DELETE = 0x00010000;
        const uint SYNCHRONIZE = 0x00100000;
        const uint FILE_SHARE_READ = 0x1;
        const uint FILE_SHARE_WRITE = 0x2;
        const uint FILE_ATTRIBUTE_NORMAL = 0x80;
        const uint FILE_CREATE = 2;
        const uint FILE_DIRECTORY_FILE = 0x1;
        const uint FILE_SYNCHRONOUS_IO_NONALERT = 0x20;
        const uint OBJ_CASE_INSENSITIVE = 0x40;
        const uint FILE_ATTRIBUTE_DIRECTORY = 0x10;
        const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
        const long FILE_CREATED = 2;

        string fullPath = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string nativePath = @"\??\" + fullPath;
        IntPtr unicodeBuffer = IntPtr.Zero;
        IntPtr unicodePointer = IntPtr.Zero;
        SafeFileHandle creationHandle = null;
        Rw06ExclusiveDirectoryGuardReceipt owner = null;
        try {
            int byteLength = checked(nativePath.Length * 2);
            if (byteLength > UInt16.MaxValue - 2) {
                throw new PathTooLongException("Exclusive directory path exceeds UNICODE_STRING bounds.");
            }
            unicodeBuffer = Marshal.StringToHGlobalUni(nativePath);
            UNICODE_STRING unicode = new UNICODE_STRING {
                Length = checked((ushort)byteLength),
                MaximumLength = checked((ushort)(byteLength + 2)),
                Buffer = unicodeBuffer
            };
            unicodePointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UNICODE_STRING)));
            Marshal.StructureToPtr(unicode, unicodePointer, false);
            OBJECT_ATTRIBUTES attributes = new OBJECT_ATTRIBUTES {
                Length = Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES)),
                RootDirectory = IntPtr.Zero,
                ObjectName = unicodePointer,
                Attributes = OBJ_CASE_INSENSITIVE,
                SecurityDescriptor = IntPtr.Zero,
                SecurityQualityOfService = IntPtr.Zero
            };
            IO_STATUS_BLOCK io;
            IntPtr rawHandle;
            int status = NtCreateFile(
                out rawHandle,
                FILE_READ_ATTRIBUTES | DELETE | SYNCHRONIZE,
                ref attributes,
                out io,
                IntPtr.Zero,
                FILE_ATTRIBUTE_NORMAL,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
                FILE_CREATE,
                FILE_DIRECTORY_FILE | FILE_SYNCHRONOUS_IO_NONALERT,
                IntPtr.Zero,
                0
            );
            if (status < 0) {
                throw new Win32Exception(checked((int)RtlNtStatusToDosError(status)), "Could not atomically create the exclusive cache root.");
            }
            creationHandle = new SafeFileHandle(rawHandle, true);
            if (creationHandle.IsInvalid) {
                throw new IOException("Native cache-root creation did not return a newly created directory handle.");
            }
            owner = new Rw06ExclusiveDirectoryGuardReceipt(creationHandle, fullPath);
            creationHandle = null;
            if (io.Information.ToInt64() != FILE_CREATED) {
                throw new IOException("Native cache-root creation did not return FILE_CREATED for the new directory handle.");
            }
            BY_HANDLE_FILE_INFORMATION creationInfo;
            if (!GetFileInformationByHandle(owner.GuardHandle, out creationInfo)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not capture the atomic cache-root creation-handle identity.");
            }
            if ((creationInfo.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0 || (creationInfo.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
                throw new IOException("Atomically created cache root is not a normal directory.");
            }
            string creationIdentity = IdentityFromInfo(creationInfo);
            long creationTicks = CreationTicksFromInfo(creationInfo);
            owner.CreationNativeKey = creationIdentity;
            owner.CreationTicks = creationTicks;
            if (forceFailureAfterNativeReturn) {
                throw new IOException("Forced failure after native cache-root creation returned its owned handle.");
            }
            // One DELETE-capable handle is both atomic creation authority and
            // continuous custody. It never shares DELETE, so no foreign handle
            // can rename or replace this path while custody is live.
            BY_HANDLE_FILE_INFORMATION custodyInfo;
            if (!GetFileInformationByHandle(owner.GuardHandle, out custodyInfo)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not recapture the single creation/custody handle identity.");
            }
            string custodyIdentity = IdentityFromInfo(custodyInfo);
            long custodyCreationTicks = CreationTicksFromInfo(custodyInfo);
            if (custodyIdentity != creationIdentity || custodyCreationTicks != creationTicks) {
                throw new IOException("Continuous-custody handle does not match the atomic creation handle.");
            }
            owner.CustodyNativeKey = custodyIdentity;
            owner.CustodyCreationTicks = custodyCreationTicks;
            bool replacementProbeRejected = false;
            if (forceReplacementProbe) {
                string probePath = fullPath + ".rw06-create-probe";
                if (File.Exists(probePath) || Directory.Exists(probePath)) {
                    throw new IOException("Exclusive cache-root replacement probe destination already exists.");
                }
                if (MoveFileExW(fullPath, probePath, 0)) {
                    MoveFileExW(probePath, fullPath, 0);
                    throw new IOException("Exclusive cache-root guard unexpectedly allowed replacement before first host capture.");
                }
                int moveError = Marshal.GetLastWin32Error();
                if (moveError != 32) {
                    throw new Win32Exception(moveError, "Exclusive cache-root replacement probe failed for a reason other than sharing violation.");
                }
                replacementProbeRejected = true;
            }
            owner.ReplacementProbeRejected = replacementProbeRejected;
            return owner;
        }
        catch (Exception primaryFailure) {
            if (owner != null && owner.GuardLive) {
                try {
                    Rw06DirectoryGuardCloseReceipt closeReceipt = CloseDirectoryGuardChecked(
                        owner,
                        "native_create_failure_closed",
                        forceCheckedCloseReportedFailure
                    );
                    primaryFailure.Data["directory_guard_owner"] = owner;
                    primaryFailure.Data["directory_guard_close_receipt"] = closeReceipt;
                }
                catch (Exception closeFailure) {
                    primaryFailure.Data["directory_guard_owner"] = owner;
                    if (owner.CloseReceipt != null) {
                        primaryFailure.Data["directory_guard_close_receipt"] = owner.CloseReceipt;
                    }
                    throw new AggregateException(
                        "Atomic cache-root creation failed and its checked custody-handle close also failed.",
                        primaryFailure,
                        closeFailure
                    );
                }
            }
            throw;
        }
        finally {
            if (creationHandle != null && !creationHandle.IsInvalid) {
                throw new IOException("Native creation handle was not transferred to its checked owner receipt.");
            }
            if (unicodePointer != IntPtr.Zero) { Marshal.FreeHGlobal(unicodePointer); }
            if (unicodeBuffer != IntPtr.Zero) { Marshal.FreeHGlobal(unicodeBuffer); }
        }
    }

    public static void DeleteEntryExact(
        string path,
        string expectedIdentity,
        long expectedCreationTicks,
        bool expectedDirectory,
        bool rejectReparse
    ) {
        string fullPath = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        BY_HANDLE_FILE_INFORMATION info;
        SafeFileHandle handle = OpenForExactDelete(fullPath, expectedDirectory, out info);
        OwnedEntry entry = new OwnedEntry {
            RelativePath = Path.GetFileName(fullPath),
            FullPath = fullPath,
            IsDirectory = expectedDirectory,
            FileAttributes = info.FileAttributes,
            Handle = handle
        };
        try {
            const uint FILE_ATTRIBUTE_DIRECTORY = 0x10;
            const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
            bool actualDirectory = (info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
            if (actualDirectory != expectedDirectory ||
                (rejectReparse && (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) ||
                IdentityFromInfo(info) != expectedIdentity ||
                CreationTicksFromInfo(info) != expectedCreationTicks) {
                throw new IOException("Exact owned entry identity/type changed before handle-bound deletion: " + fullPath);
            }
            MarkDeleteByHandle(entry);
        }
        finally {
            entry.Dispose();
        }
    }

    public static void DeleteTreeExact(
        string rootPath,
        string expectedRootIdentity,
        long expectedRootCreationTicks,
        string[] relativePaths,
        string[] expectedIdentities,
        long[] expectedCreationTicks,
        bool[] expectedDirectories
    ) {
        if (relativePaths == null || expectedIdentities == null || expectedCreationTicks == null || expectedDirectories == null ||
            relativePaths.Length != expectedIdentities.Length || relativePaths.Length != expectedCreationTicks.Length || relativePaths.Length != expectedDirectories.Length) {
            throw new ArgumentException("Exact owned deletion manifest arrays are malformed.");
        }
        string fullRoot = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        Dictionary<string, int> expected = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (int index = 0; index < relativePaths.Length; index++) {
            string relative = relativePaths[index].Replace('/', Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (String.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative) || expected.ContainsKey(relative)) {
                throw new ArgumentException("Exact owned deletion manifest has an invalid or duplicate relative path.");
            }
            string candidate = Path.GetFullPath(Path.Combine(fullRoot, relative));
            if (!candidate.StartsWith(fullRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) {
                throw new ArgumentException("Exact owned deletion manifest path escaped its root.");
            }
            expected.Add(relative, index);
        }

        List<OwnedEntry> opened = new List<OwnedEntry>();
        OwnedEntry root = null;
        try {
            BY_HANDLE_FILE_INFORMATION rootInfo;
            SafeFileHandle rootHandle = OpenForExactDelete(fullRoot, true, out rootInfo);
            root = new OwnedEntry { RelativePath = "", FullPath = fullRoot, IsDirectory = true, FileAttributes = rootInfo.FileAttributes, Handle = rootHandle };
            const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
            if ((rootInfo.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
                IdentityFromInfo(rootInfo) != expectedRootIdentity ||
                CreationTicksFromInfo(rootInfo) != expectedRootCreationTicks) {
                throw new IOException("Quarantined deletion root identity changed before handle ownership.");
            }

            string[] actualPaths = EnumerateTreeNoReparse(fullRoot);
            if (actualPaths.Length != expected.Count) {
                throw new IOException("Quarantined deletion tree gained or lost entries before handle ownership.");
            }
            Array.Sort(actualPaths, StringComparer.OrdinalIgnoreCase);
            foreach (string actualPath in actualPaths) {
                string relative = actualPath.Substring(fullRoot.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                int manifestIndex;
                if (!expected.TryGetValue(relative, out manifestIndex)) {
                    throw new IOException("Quarantined deletion tree contains an unowned entry: " + relative);
                }
                FileAttributes attributes = File.GetAttributes(actualPath);
                bool isDirectory = (attributes & FileAttributes.Directory) != 0;
                if ((attributes & FileAttributes.ReparsePoint) != 0 || isDirectory != expectedDirectories[manifestIndex]) {
                    throw new IOException("Quarantined deletion entry type/reparse state changed: " + relative);
                }
                BY_HANDLE_FILE_INFORMATION info;
                SafeFileHandle handle = OpenForExactDelete(actualPath, isDirectory, out info);
                OwnedEntry entry = new OwnedEntry { RelativePath = relative, FullPath = actualPath, IsDirectory = isDirectory, FileAttributes = info.FileAttributes, Handle = handle };
                opened.Add(entry);
                if ((info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
                    IdentityFromInfo(info) != expectedIdentities[manifestIndex] ||
                    CreationTicksFromInfo(info) != expectedCreationTicks[manifestIndex]) {
                    throw new IOException("Quarantined deletion entry was replaced before exact handle ownership: " + relative);
                }
            }

            string[] finalPaths = EnumerateTreeNoReparse(fullRoot);
            if (finalPaths.Length != expected.Count) {
                throw new IOException("Quarantined deletion tree changed after exact handles were acquired.");
            }
            foreach (string finalPath in finalPaths) {
                string relative = finalPath.Substring(fullRoot.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                if (!expected.ContainsKey(relative)) {
                    throw new IOException("Quarantined deletion tree gained an unowned entry after exact handles were acquired: " + relative);
                }
            }

            List<OwnedEntry> files = opened.FindAll(delegate(OwnedEntry entry) { return !entry.IsDirectory; });
            foreach (OwnedEntry file in files) {
                MarkDeleteByHandle(file);
            }
            List<OwnedEntry> directories = opened.FindAll(delegate(OwnedEntry entry) { return entry.IsDirectory; });
            directories.Sort(delegate(OwnedEntry left, OwnedEntry right) {
                int depthCompare = right.RelativePath.Length.CompareTo(left.RelativePath.Length);
                return depthCompare != 0 ? depthCompare : StringComparer.OrdinalIgnoreCase.Compare(right.RelativePath, left.RelativePath);
            });
            foreach (OwnedEntry directory in directories) {
                MarkDeleteByHandle(directory);
            }
            MarkDeleteByHandle(root);
            root = null;
        }
        finally {
            foreach (OwnedEntry entry in opened) {
                entry.Dispose();
            }
            if (root != null) {
                root.Dispose();
            }
        }
    }

    public static Rw06DirectoryGuardCloseReceipt DeleteTreeExactThroughGuard(
        Rw06ExclusiveDirectoryGuardReceipt receipt,
        string rootPath,
        string expectedRootIdentity,
        long expectedRootCreationTicks,
        string[] relativePaths,
        string[] expectedIdentities,
        long[] expectedCreationTicks,
        bool[] expectedDirectories,
        bool forceCheckedCloseReportedFailure
    ) {
        if (receipt == null) { throw new ArgumentNullException("receipt"); }
        if (relativePaths == null || expectedIdentities == null || expectedCreationTicks == null || expectedDirectories == null ||
            relativePaths.Length != expectedIdentities.Length || relativePaths.Length != expectedCreationTicks.Length || relativePaths.Length != expectedDirectories.Length) {
            throw new ArgumentException("Guarded exact owned deletion manifest arrays are malformed.");
        }
        lock (receipt.SyncRoot) {
            string fullRoot = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string currentPath = Path.GetFullPath(receipt.CurrentPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (!String.Equals(fullRoot, currentPath, StringComparison.Ordinal) || !receipt.RenamedThroughGuard) {
                throw new IOException("Guarded exact owned tree was not quarantined through its creation handle.");
            }
            Rw06DirectoryGuardIdentityReceipt rootIdentity = ReadDirectoryGuardIdentityNoLock(receipt);
            if (!rootIdentity.IsDirectory || rootIdentity.ReparsePoint || rootIdentity.NativeKey != expectedRootIdentity || rootIdentity.CreationTicks != expectedRootCreationTicks) {
                throw new IOException("Guarded quarantined deletion root identity changed before exact child ownership.");
            }

            Dictionary<string, int> expected = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            for (int index = 0; index < relativePaths.Length; index++) {
                string relative = relativePaths[index].Replace('/', Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                if (String.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative) || expected.ContainsKey(relative)) {
                    throw new ArgumentException("Guarded exact owned deletion manifest has an invalid or duplicate relative path.");
                }
                string candidate = Path.GetFullPath(Path.Combine(fullRoot, relative));
                if (!candidate.StartsWith(fullRoot + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)) {
                    throw new ArgumentException("Guarded exact owned deletion manifest path escaped its root.");
                }
                expected.Add(relative, index);
            }

            List<OwnedEntry> opened = new List<OwnedEntry>();
            try {
                string[] actualPaths = EnumerateTreeNoReparse(fullRoot);
                if (actualPaths.Length != expected.Count) {
                    throw new IOException("Guarded quarantined deletion tree gained or lost entries before child handle ownership.");
                }
                Array.Sort(actualPaths, StringComparer.OrdinalIgnoreCase);
                foreach (string actualPath in actualPaths) {
                    string relative = actualPath.Substring(fullRoot.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                    int manifestIndex;
                    if (!expected.TryGetValue(relative, out manifestIndex)) {
                        throw new IOException("Guarded quarantined deletion tree contains an unowned entry: " + relative);
                    }
                    FileAttributes attributes = File.GetAttributes(actualPath);
                    bool isDirectory = (attributes & FileAttributes.Directory) != 0;
                    if ((attributes & FileAttributes.ReparsePoint) != 0 || isDirectory != expectedDirectories[manifestIndex]) {
                        throw new IOException("Guarded quarantined deletion entry type/reparse state changed: " + relative);
                    }
                    BY_HANDLE_FILE_INFORMATION info;
                    SafeFileHandle handle = OpenForExactDelete(actualPath, isDirectory, out info);
                    OwnedEntry entry = new OwnedEntry { RelativePath = relative, FullPath = actualPath, IsDirectory = isDirectory, FileAttributes = info.FileAttributes, Handle = handle };
                    opened.Add(entry);
                    if ((info.FileAttributes & 0x400) != 0 || IdentityFromInfo(info) != expectedIdentities[manifestIndex] || CreationTicksFromInfo(info) != expectedCreationTicks[manifestIndex]) {
                        throw new IOException("Guarded quarantined deletion entry was replaced before exact handle ownership: " + relative);
                    }
                }

                string[] finalPaths = EnumerateTreeNoReparse(fullRoot);
                if (finalPaths.Length != expected.Count) {
                    throw new IOException("Guarded quarantined deletion tree changed after exact child handles were acquired.");
                }
                foreach (string finalPath in finalPaths) {
                    string relative = finalPath.Substring(fullRoot.Length).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                    if (!expected.ContainsKey(relative)) {
                        throw new IOException("Guarded quarantined deletion tree gained an unowned entry after exact handles were acquired: " + relative);
                    }
                }

                List<OwnedEntry> files = opened.FindAll(delegate(OwnedEntry entry) { return !entry.IsDirectory; });
                foreach (OwnedEntry file in files) { MarkDeleteByHandle(file); }
                List<OwnedEntry> directories = opened.FindAll(delegate(OwnedEntry entry) { return entry.IsDirectory; });
                directories.Sort(delegate(OwnedEntry left, OwnedEntry right) {
                    int depthCompare = right.RelativePath.Length.CompareTo(left.RelativePath.Length);
                    return depthCompare != 0 ? depthCompare : StringComparer.OrdinalIgnoreCase.Compare(right.RelativePath, left.RelativePath);
                });
                foreach (OwnedEntry directory in directories) { MarkDeleteByHandle(directory); }

                BY_HANDLE_FILE_INFORMATION finalRootInfo;
                SafeFileHandle rootHandle = RequireLiveDirectoryGuardNoLock(receipt);
                if (!GetFileInformationByHandle(rootHandle, out finalRootInfo) || IdentityFromInfo(finalRootInfo) != expectedRootIdentity || CreationTicksFromInfo(finalRootInfo) != expectedRootCreationTicks) {
                    throw new IOException("Guarded quarantine root changed before root delete disposition.");
                }
                SetDeleteDispositionByHandle(rootHandle, finalRootInfo.FileAttributes, fullRoot);
                receipt.DeleteDispositionSet = true;
                Rw06DirectoryGuardCloseReceipt closeReceipt = CloseDirectoryGuardChecked(
                    receipt,
                    "deleted_closed",
                    forceCheckedCloseReportedFailure
                );
                if (File.Exists(fullRoot) || Directory.Exists(fullRoot)) {
                    throw new IOException("Guarded exact owned tree remained after delete disposition and checked close.");
                }
                return closeReceipt;
            }
            finally {
                foreach (OwnedEntry entry in opened) { entry.Dispose(); }
            }
        }
    }
}
'@
}


function Initialize-Rw06NativeJobType {
    if ($null -ne ('Rw06OwnedJobProcessNative' -as [type])) { return }
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

public sealed class Rw06OwnedJobProcessNative : IDisposable {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct STARTUPINFO {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint dwProcessId;
        public uint dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SECURITY_ATTRIBUTES {
        public int nLength;
        public IntPtr lpSecurityDescriptor;
        [MarshalAs(UnmanagedType.Bool)]
        public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IO_COUNTERS {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct FILETIME {
        public uint Low;
        public uint High;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct BY_HANDLE_FILE_INFORMATION {
        public uint FileAttributes;
        public FILETIME CreationTime;
        public FILETIME LastAccessTime;
        public FILETIME LastWriteTime;
        public uint VolumeSerialNumber;
        public uint FileSizeHigh;
        public uint FileSizeLow;
        public uint NumberOfLinks;
        public uint FileIndexHigh;
        public uint FileIndexLow;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateJobObjectW(IntPtr attributes, string name);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool QueryInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length, out uint returnedLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateJobObject(IntPtr job, uint exitCode);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcessW(
        string applicationName,
        StringBuilder commandLine,
        IntPtr processAttributes,
        IntPtr threadAttributes,
        [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
        uint creationFlags,
        IntPtr environment,
        string currentDirectory,
        ref STARTUPINFO startupInfo,
        out PROCESS_INFORMATION processInformation
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint ResumeThread(IntPtr thread);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetProcessTimes(IntPtr process, out FILETIME creation, out FILETIME exit, out FILETIME kernel, out FILETIME user);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool QueryFullProcessImageNameW(IntPtr process, uint flags, StringBuilder executableName, ref uint size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFileW(
        string fileName,
        uint desiredAccess,
        uint shareMode,
        ref SECURITY_ATTRIBUTES securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandle(IntPtr handle, out BY_HANDLE_FILE_INFORMATION info);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool MoveFileExW(string existingFileName, string newFileName, uint flags);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetStdHandle(int standardHandle);

    private const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000;
    private const uint CREATE_SUSPENDED = 0x00000004;
    private const uint CREATE_NO_WINDOW = 0x08000000;
    private const uint STARTF_USESTDHANDLES = 0x00000100;
    private const uint GENERIC_READ = 0x80000000;
    private const uint GENERIC_WRITE = 0x40000000;
    private const uint FILE_READ_ATTRIBUTES = 0x00000080;
    private const uint FILE_SHARE_READ = 0x00000001;
    private const uint FILE_SHARE_WRITE = 0x00000002;
    private const uint FILE_SHARE_DELETE = 0x00000004;
    private const uint CREATE_NEW = 1;
    private const uint OPEN_EXISTING = 3;
    private const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;
    private const uint FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
    private const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
    private const uint FILE_ATTRIBUTE_DIRECTORY = 0x00000010;
    private const uint FILE_ATTRIBUTE_REPARSE_POINT = 0x00000400;
    private const uint WAIT_OBJECT_0 = 0;
    private const uint WAIT_TIMEOUT = 258;
    private static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    private IntPtr _jobHandle;
    private IntPtr _processHandle;
    private IntPtr _threadHandle;
    private bool _disposed;

    public int ProcessId { get; private set; }
    public long StartUtcTicks { get; private set; }
    public string ProcessName { get; private set; }
    public string JobInstanceId { get; private set; }
    public bool SuspendedCreate { get; private set; }
    public bool AssignedBeforeResume { get; private set; }
    public bool ResumedAfterAssign { get; private set; }
    public bool KillOnJobClose { get; private set; }
    public bool BreakawayDisabled { get; private set; }
    public int[] InitialMembership { get; private set; }
    public string ExecutablePath { get; private set; }
    public string ExecutableNativeKey { get; private set; }
    public long ExecutableCreationTicks { get; private set; }
    public string ExecutableSha256 { get; private set; }
    public string MappedImagePath { get; private set; }
    public string MappedImageNativeKey { get; private set; }
    public long MappedImageCreationTicks { get; private set; }
    public string MappedImageSha256 { get; private set; }
    public bool ExecutableHandleOpened { get; private set; }
    public bool ExecutableIdentityVerified { get; private set; }
    public bool ExecutableSha256Verified { get; private set; }
    public bool ExecutableAncestorChainPinned { get; private set; }
    public bool ExecutableHeldThroughCreate { get; private set; }
    public bool MappedImagePathVerified { get; private set; }
    public bool MappedImageIdentityVerified { get; private set; }
    public bool MappedImageSha256Verified { get; private set; }
    public bool ExecutableHeldThroughResume { get; private set; }
    public bool ExecutableSwapProbeRejected { get; private set; }

    private Rw06OwnedJobProcessNative() {
        JobInstanceId = Guid.NewGuid().ToString("N");
        ProcessName = "";
        InitialMembership = new int[0];
        ExecutablePath = "";
        ExecutableNativeKey = "";
        ExecutableSha256 = "";
        MappedImagePath = "";
        MappedImageNativeKey = "";
        MappedImageSha256 = "";
    }

    private static long FileTimeToUtcTicks(FILETIME value) {
        long raw = ((long)value.High << 32) | (long)value.Low;
        return DateTime.FromFileTimeUtc(raw).Ticks;
    }

    private static string IdentityFromInfo(BY_HANDLE_FILE_INFORMATION info) {
        return String.Format("{0:X8}:{1:X8}{2:X8}", info.VolumeSerialNumber, info.FileIndexHigh, info.FileIndexLow);
    }

    private static BY_HANDLE_FILE_INFORMATION ReadHandleIdentity(IntPtr handle, string context) {
        BY_HANDLE_FILE_INFORMATION info;
        if (!GetFileInformationByHandle(handle, out info)) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read " + context + " handle identity.");
        }
        return info;
    }

    private static string HashPinnedHandle(IntPtr handle) {
        SafeFileHandle safe = new SafeFileHandle(handle, false);
        try {
            using (FileStream stream = new FileStream(safe, FileAccess.Read, 65536, false)) {
                stream.Position = 0;
                using (SHA256 sha = SHA256.Create()) {
                    return BitConverter.ToString(sha.ComputeHash(stream)).Replace("-", "");
                }
            }
        }
        finally {
            safe.Dispose();
        }
    }

    private static IntPtr OpenPinnedExecutable(string path, out BY_HANDLE_FILE_INFORMATION info, out string sha256) {
        SECURITY_ATTRIBUTES attributes = new SECURITY_ATTRIBUTES();
        attributes.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES));
        attributes.lpSecurityDescriptor = IntPtr.Zero;
        attributes.bInheritHandle = false;
        IntPtr handle = CreateFileW(
            path,
            GENERIC_READ | FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ,
            ref attributes,
            OPEN_EXISTING,
            FILE_FLAG_OPEN_REPARSE_POINT,
            IntPtr.Zero
        );
        if (handle == INVALID_HANDLE_VALUE) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not pin executable against write/delete replacement: " + path);
        }
        try {
            info = ReadHandleIdentity(handle, "executable");
            if ((info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0 || (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
                throw new IOException("Pinned executable is a directory or reparse point: " + path);
            }
            sha256 = HashPinnedHandle(handle);
            return handle;
        }
        catch {
            CloseHandle(handle);
            throw;
        }
    }

    private static List<IntPtr> PinExecutableAncestorChain(string executable) {
        List<string> paths = new List<string>();
        string root = Path.GetPathRoot(executable).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string cursor = Path.GetDirectoryName(executable);
        while (!String.IsNullOrWhiteSpace(cursor) && !String.Equals(cursor.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar), root, StringComparison.OrdinalIgnoreCase)) {
            paths.Add(cursor);
            cursor = Path.GetDirectoryName(cursor);
        }
        paths.Reverse();
        List<IntPtr> handles = new List<IntPtr>();
        try {
            foreach (string path in paths) {
                SECURITY_ATTRIBUTES attributes = new SECURITY_ATTRIBUTES();
                attributes.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES));
                attributes.lpSecurityDescriptor = IntPtr.Zero;
                attributes.bInheritHandle = false;
                IntPtr handle = CreateFileW(
                    path,
                    FILE_READ_ATTRIBUTES,
                    FILE_SHARE_READ | FILE_SHARE_WRITE,
                    ref attributes,
                    OPEN_EXISTING,
                    FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS,
                    IntPtr.Zero
                );
                if (handle == INVALID_HANDLE_VALUE) {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not pin executable ancestor directory: " + path);
                }
                BY_HANDLE_FILE_INFORMATION info = ReadHandleIdentity(handle, "executable ancestor");
                if ((info.FileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0 || (info.FileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
                    CloseHandle(handle);
                    throw new IOException("Executable ancestor is not a normal directory: " + path);
                }
                handles.Add(handle);
            }
            return handles;
        }
        catch {
            foreach (IntPtr handle in handles) { CloseHandle(handle); }
            throw;
        }
    }

    private static void ClosePinnedHandles(List<IntPtr> handles) {
        if (handles == null) { return; }
        foreach (IntPtr handle in handles) {
            if (handle != IntPtr.Zero && handle != INVALID_HANDLE_VALUE) { CloseHandle(handle); }
        }
        handles.Clear();
    }

    private static string QueryMappedImagePath(IntPtr process) {
        StringBuilder buffer = new StringBuilder(32768);
        uint length = (uint)buffer.Capacity;
        if (!QueryFullProcessImageNameW(process, 0, buffer, ref length)) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not query suspended process mapped image path.");
        }
        return Path.GetFullPath(buffer.ToString());
    }

    private static IntPtr CreateInheritedOutput(string path) {
        SECURITY_ATTRIBUTES attributes = new SECURITY_ATTRIBUTES();
        attributes.nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES));
        attributes.lpSecurityDescriptor = IntPtr.Zero;
        attributes.bInheritHandle = true;
        IntPtr handle = CreateFileW(
            path,
            GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            ref attributes,
            File.Exists(path) ? OPEN_EXISTING : CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL,
            IntPtr.Zero
        );
        if (handle == INVALID_HANDLE_VALUE) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open exact redirected output: " + path);
        }
        return handle;
    }

    private static string QuoteExecutable(string value) {
        return "\"" + value.Replace("\"", "\\\"") + "\"";
    }

    private static int[] QueryMembership(IntPtr job) {
        const int JobObjectBasicProcessIdList = 3;
        int capacity = 4096;
        while (capacity <= 1048576) {
            IntPtr buffer = Marshal.AllocHGlobal(capacity);
            try {
                uint returned;
                if (QueryInformationJobObject(job, JobObjectBasicProcessIdList, buffer, (uint)capacity, out returned)) {
                    uint count = (uint)Marshal.ReadInt32(buffer, 4);
                    List<int> values = new List<int>();
                    long offset = 8;
                    for (uint index = 0; index < count; index++) {
                        long raw = IntPtr.Size == 8
                            ? Marshal.ReadInt64(buffer, (int)(offset + (long)index * IntPtr.Size))
                            : Marshal.ReadInt32(buffer, (int)(offset + (long)index * IntPtr.Size));
                        if (raw > 0 && raw <= Int32.MaxValue) {
                            values.Add((int)raw);
                        }
                    }
                    return values.ToArray();
                }
                int error = Marshal.GetLastWin32Error();
                if (error != 24 && error != 122) {
                    throw new Win32Exception(error, "Could not query exact job membership.");
                }
            }
            finally {
                Marshal.FreeHGlobal(buffer);
            }
            capacity *= 2;
        }
        throw new IOException("Exact job membership exceeded its bounded query buffer.");
    }

    private static void ConfigureKillOnClose(IntPtr job) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr buffer = Marshal.AllocHGlobal(size);
        try {
            Marshal.StructureToPtr(limits, buffer, false);
            if (!SetInformationJobObject(job, 9, buffer, (uint)size)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not set KILL_ON_JOB_CLOSE on exact job.");
            }
        }
        finally {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static void CloseIfValid(ref IntPtr handle) {
        if (handle != IntPtr.Zero && handle != INVALID_HANDLE_VALUE) {
            CloseHandle(handle);
            handle = IntPtr.Zero;
        }
    }

    public static Rw06OwnedJobProcessNative Start(
        string executable,
        string expectedExecutableNativeKey,
        long expectedExecutableCreationTicks,
        string expectedExecutableSha256,
        string arguments,
        string workingDirectory,
        string stdoutPath,
        string stderrPath,
        bool forceExecutableSwapProbe,
        bool forceFailureAfterAssignBeforeResume,
        bool forceFailureAfterResume
    ) {
        Rw06OwnedJobProcessNative owned = new Rw06OwnedJobProcessNative();
        IntPtr stdoutHandle = IntPtr.Zero;
        IntPtr stderrHandle = IntPtr.Zero;
        IntPtr executableHandle = IntPtr.Zero;
        List<IntPtr> ancestorHandles = null;
        try {
            executable = Path.GetFullPath(executable);
            if (String.IsNullOrWhiteSpace(expectedExecutableNativeKey) || expectedExecutableCreationTicks <= 0 || String.IsNullOrWhiteSpace(expectedExecutableSha256)) {
                throw new ArgumentException("Exact executable native identity, creation ticks, and SHA-256 are required.");
            }
            ancestorHandles = PinExecutableAncestorChain(executable);
            owned.ExecutableAncestorChainPinned = true;
            BY_HANDLE_FILE_INFORMATION executableInfo;
            string executableSha256;
            executableHandle = OpenPinnedExecutable(executable, out executableInfo, out executableSha256);
            owned.ExecutableHandleOpened = true;
            owned.ExecutablePath = executable;
            owned.ExecutableNativeKey = IdentityFromInfo(executableInfo);
            owned.ExecutableCreationTicks = FileTimeToUtcTicks(executableInfo.CreationTime);
            owned.ExecutableSha256 = executableSha256;
            if (!String.Equals(owned.ExecutableNativeKey, expectedExecutableNativeKey, StringComparison.Ordinal) || owned.ExecutableCreationTicks != expectedExecutableCreationTicks) {
                throw new IOException("Pinned executable native identity does not match the sealed launch receipt.");
            }
            owned.ExecutableIdentityVerified = true;
            if (!String.Equals(owned.ExecutableSha256, expectedExecutableSha256, StringComparison.OrdinalIgnoreCase)) {
                throw new IOException("Pinned executable SHA-256 does not match the sealed launch receipt.");
            }
            owned.ExecutableSha256Verified = true;
            if (forceExecutableSwapProbe) {
                string probePath = executable + ".rw06-pin-probe";
                if (File.Exists(probePath) || Directory.Exists(probePath)) {
                    throw new IOException("Executable swap hostile destination already exists.");
                }
                if (MoveFileExW(executable, probePath, 0)) {
                    MoveFileExW(probePath, executable, 0);
                    throw new IOException("Pinned executable unexpectedly allowed a hostile rename.");
                }
                int swapError = Marshal.GetLastWin32Error();
                if (swapError != 32) {
                    throw new Win32Exception(swapError, "Pinned executable swap hostile failed for a reason other than sharing violation.");
                }
                owned.ExecutableSwapProbeRejected = true;
            }

            owned._jobHandle = CreateJobObjectW(IntPtr.Zero, null);
            if (owned._jobHandle == IntPtr.Zero) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not create exact job object.");
            }
            ConfigureKillOnClose(owned._jobHandle);
            owned.KillOnJobClose = true;
            owned.BreakawayDisabled = true;

            stdoutHandle = CreateInheritedOutput(stdoutPath);
            stderrHandle = CreateInheritedOutput(stderrPath);
            STARTUPINFO startup = new STARTUPINFO();
            startup.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            startup.dwFlags = STARTF_USESTDHANDLES;
            startup.hStdInput = GetStdHandle(-10);
            startup.hStdOutput = stdoutHandle;
            startup.hStdError = stderrHandle;
            PROCESS_INFORMATION info;
            string command = QuoteExecutable(executable);
            if (!String.IsNullOrWhiteSpace(arguments)) {
                command += " " + arguments;
            }
            StringBuilder mutableCommand = new StringBuilder(command);
            if (!CreateProcessW(
                executable,
                mutableCommand,
                IntPtr.Zero,
                IntPtr.Zero,
                true,
                CREATE_SUSPENDED | CREATE_NO_WINDOW,
                IntPtr.Zero,
                workingDirectory,
                ref startup,
                out info
            )) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not create exact suspended process: " + executable);
            }
            owned._processHandle = info.hProcess;
            owned._threadHandle = info.hThread;
            owned.ExecutableHeldThroughCreate = true;
            owned.ProcessId = checked((int)info.dwProcessId);
            owned.ProcessName = Path.GetFileNameWithoutExtension(executable);
            owned.SuspendedCreate = true;
            FILETIME creation;
            FILETIME exit;
            FILETIME kernel;
            FILETIME user;
            if (!GetProcessTimes(owned._processHandle, out creation, out exit, out kernel, out user)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not capture exact suspended root creation time.");
            }
            owned.StartUtcTicks = FileTimeToUtcTicks(creation);
            if (!AssignProcessToJobObject(owned._jobHandle, owned._processHandle)) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not atomically assign suspended process to exact job.");
            }
            owned.AssignedBeforeResume = true;
            owned.InitialMembership = QueryMembership(owned._jobHandle);
            if (owned.InitialMembership.Length != 1 || owned.InitialMembership[0] != owned.ProcessId) {
                throw new IOException("Exact job did not contain only its suspended root before resume.");
            }
            string mappedImagePath = QueryMappedImagePath(owned._processHandle);
            owned.MappedImagePath = mappedImagePath;
            if (!String.Equals(mappedImagePath, executable, StringComparison.OrdinalIgnoreCase)) {
                throw new IOException("Suspended process mapped image path differs from the pinned executable path.");
            }
            owned.MappedImagePathVerified = true;
            BY_HANDLE_FILE_INFORMATION mappedInfo;
            string mappedSha256;
            IntPtr mappedHandle = OpenPinnedExecutable(mappedImagePath, out mappedInfo, out mappedSha256);
            try {
                owned.MappedImageNativeKey = IdentityFromInfo(mappedInfo);
                owned.MappedImageCreationTicks = FileTimeToUtcTicks(mappedInfo.CreationTime);
                owned.MappedImageSha256 = mappedSha256;
            }
            finally {
                CloseHandle(mappedHandle);
            }
            if (!String.Equals(owned.MappedImageNativeKey, owned.ExecutableNativeKey, StringComparison.Ordinal) || owned.MappedImageCreationTicks != owned.ExecutableCreationTicks) {
                throw new IOException("Suspended process mapped image native identity differs from the pinned executable.");
            }
            owned.MappedImageIdentityVerified = true;
            if (!String.Equals(owned.MappedImageSha256, owned.ExecutableSha256, StringComparison.OrdinalIgnoreCase)) {
                throw new IOException("Suspended process mapped image SHA-256 differs from the pinned executable.");
            }
            owned.MappedImageSha256Verified = true;
            BY_HANDLE_FILE_INFORMATION executableInfoBeforeResume = ReadHandleIdentity(executableHandle, "pre-resume executable");
            if (!String.Equals(IdentityFromInfo(executableInfoBeforeResume), owned.ExecutableNativeKey, StringComparison.Ordinal) ||
                FileTimeToUtcTicks(executableInfoBeforeResume.CreationTime) != owned.ExecutableCreationTicks ||
                !String.Equals(HashPinnedHandle(executableHandle), owned.ExecutableSha256, StringComparison.OrdinalIgnoreCase)) {
                throw new IOException("Pinned executable identity or bytes changed before resume.");
            }
            if (forceFailureAfterAssignBeforeResume) {
                throw new InvalidOperationException("Forced post-assign/pre-resume job setup failure for hostile validation.");
            }
            uint priorSuspend = ResumeThread(owned._threadHandle);
            if (priorSuspend == 0xFFFFFFFF) {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not resume exact job-bound process.");
            }
            owned.ResumedAfterAssign = true;
            owned.ExecutableHeldThroughResume = true;
            CloseIfValid(ref owned._threadHandle);
            if (forceFailureAfterResume) {
                throw new InvalidOperationException("Forced post-resume job setup failure for hostile validation.");
            }
            CloseIfValid(ref stdoutHandle);
            CloseIfValid(ref stderrHandle);
            CloseIfValid(ref executableHandle);
            ClosePinnedHandles(ancestorHandles);
            return owned;
        }
        catch (Exception failure) {
            int[] before = new int[0];
            int[] after = new int[0];
            try {
                if (owned._jobHandle != IntPtr.Zero) {
                    before = QueryMembership(owned._jobHandle);
                    TerminateJobObject(owned._jobHandle, 125);
                    DateTime deadline = DateTime.UtcNow.AddSeconds(5);
                    do {
                        after = QueryMembership(owned._jobHandle);
                        if (after.Length == 0) { break; }
                        Thread.Sleep(10);
                    } while (DateTime.UtcNow < deadline);
                }
            }
            catch {
                after = new int[] { -1 };
            }
            if (owned._processHandle != IntPtr.Zero && !owned.AssignedBeforeResume) {
                try {
                    TerminateProcess(owned._processHandle, 125);
                    WaitForSingleObject(owned._processHandle, 5000);
                }
                catch { }
            }
            failure.Data["owned_process_id"] = owned.ProcessId;
            failure.Data["owned_process_start_ticks"] = owned.StartUtcTicks;
            failure.Data["owned_process_name"] = owned.ProcessName;
            failure.Data["owned_job_instance_id"] = owned.JobInstanceId;
            failure.Data["owned_job_suspended_create"] = owned.SuspendedCreate;
            failure.Data["owned_job_assigned_before_resume"] = owned.AssignedBeforeResume;
            failure.Data["owned_job_resumed_after_assign"] = owned.ResumedAfterAssign;
            failure.Data["owned_job_kill_on_close"] = owned.KillOnJobClose;
            failure.Data["owned_job_breakaway_disabled"] = owned.BreakawayDisabled;
            failure.Data["owned_job_initial_membership"] = owned.InitialMembership;
            failure.Data["owned_job_members_before_cleanup"] = before;
            failure.Data["owned_job_members_after_cleanup"] = after;
            failure.Data["owned_executable_path"] = owned.ExecutablePath;
            failure.Data["owned_executable_native_key"] = owned.ExecutableNativeKey;
            failure.Data["owned_executable_creation_ticks"] = owned.ExecutableCreationTicks;
            failure.Data["owned_executable_sha256"] = owned.ExecutableSha256;
            failure.Data["owned_mapped_image_path"] = owned.MappedImagePath;
            failure.Data["owned_mapped_image_native_key"] = owned.MappedImageNativeKey;
            failure.Data["owned_mapped_image_creation_ticks"] = owned.MappedImageCreationTicks;
            failure.Data["owned_mapped_image_sha256"] = owned.MappedImageSha256;
            failure.Data["owned_executable_handle_opened"] = owned.ExecutableHandleOpened;
            failure.Data["owned_executable_identity_verified"] = owned.ExecutableIdentityVerified;
            failure.Data["owned_executable_sha256_verified"] = owned.ExecutableSha256Verified;
            failure.Data["owned_executable_ancestor_chain_pinned"] = owned.ExecutableAncestorChainPinned;
            failure.Data["owned_executable_held_through_create"] = owned.ExecutableHeldThroughCreate;
            failure.Data["owned_mapped_image_path_verified"] = owned.MappedImagePathVerified;
            failure.Data["owned_mapped_image_identity_verified"] = owned.MappedImageIdentityVerified;
            failure.Data["owned_mapped_image_sha256_verified"] = owned.MappedImageSha256Verified;
            failure.Data["owned_executable_held_through_resume"] = owned.ExecutableHeldThroughResume;
            failure.Data["owned_executable_swap_probe_rejected"] = owned.ExecutableSwapProbeRejected;
            CloseIfValid(ref stdoutHandle);
            CloseIfValid(ref stderrHandle);
            CloseIfValid(ref executableHandle);
            ClosePinnedHandles(ancestorHandles);
            owned.Dispose();
            throw;
        }
    }

    public int[] GetActiveProcessIds() {
        if (_disposed || _jobHandle == IntPtr.Zero) { return new int[0]; }
        return QueryMembership(_jobHandle);
    }

    public bool WaitForRootExit(int milliseconds) {
        if (_disposed || _processHandle == IntPtr.Zero) { return true; }
        uint result = WaitForSingleObject(_processHandle, checked((uint)Math.Max(0, milliseconds)));
        if (result == WAIT_OBJECT_0) { return true; }
        if (result == WAIT_TIMEOUT) { return false; }
        throw new Win32Exception(Marshal.GetLastWin32Error(), "Exact root wait failed.");
    }

    public bool WaitForJobEmpty(int milliseconds) {
        DateTime deadline = DateTime.UtcNow.AddMilliseconds(Math.Max(0, milliseconds));
        do {
            if (GetActiveProcessIds().Length == 0) { return true; }
            Thread.Sleep(10);
        } while (DateTime.UtcNow < deadline);
        return GetActiveProcessIds().Length == 0;
    }

    public int GetRootExitCode() {
        if (!WaitForRootExit(0)) {
            throw new InvalidOperationException("Exact root exit code requested before root exit.");
        }
        uint value;
        if (!GetExitCodeProcess(_processHandle, out value)) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read exact root native exit code.");
        }
        return unchecked((int)value);
    }

    public int[] TerminateAndWait(int exitCode, int milliseconds) {
        if (_disposed || _jobHandle == IntPtr.Zero) { return new int[0]; }
        int[] before = GetActiveProcessIds();
        if (before.Length > 0 && !TerminateJobObject(_jobHandle, unchecked((uint)exitCode))) {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not terminate exact owned job.");
        }
        if (!WaitForJobEmpty(milliseconds)) {
            throw new IOException("Exact owned job retained members after termination.");
        }
        return before;
    }

    public void Dispose() {
        if (_disposed) { return; }
        try {
            if (_jobHandle != IntPtr.Zero) {
                try {
                    int[] active = QueryMembership(_jobHandle);
                    if (active.Length > 0) {
                        TerminateJobObject(_jobHandle, 125);
                        DateTime deadline = DateTime.UtcNow.AddSeconds(5);
                        while (DateTime.UtcNow < deadline && QueryMembership(_jobHandle).Length > 0) {
                            Thread.Sleep(10);
                        }
                    }
                }
                catch { }
            }
        }
        finally {
            CloseIfValid(ref _threadHandle);
            CloseIfValid(ref _processHandle);
            CloseIfValid(ref _jobHandle);
            _disposed = true;
        }
    }
}
'@
}


function Get-FileSystemEntryIdentity {
    param([string]$Path, [switch]$AllowReparse)
    $resolved = [System.IO.Path]::GetFullPath($Path)
    try { $item = Get-Item -LiteralPath $resolved -Force -ErrorAction Stop }
    catch { throw "Filesystem identity target is absent or unreadable: $resolved" }
    $isReparse = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
    if ($isReparse -and -not $AllowReparse) {
        throw "Filesystem identity target is a reparse point: $resolved"
    }
    Initialize-Rw06NativeFileIdentityType
    $isDirectory = (($item.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0)
    $nativeKey = [Rw06FileIdentityNative]::GetIdentity($resolved, $isDirectory)
    return [ordered]@{
        path = $resolved
        native_key = $nativeKey
        is_directory = $isDirectory
        creation_utc = $item.CreationTimeUtc.ToString('o')
        creation_ticks = [long]$item.CreationTimeUtc.Ticks
        last_write_utc = $item.LastWriteTimeUtc.ToString('o')
        last_write_ticks = [long]$item.LastWriteTimeUtc.Ticks
        length = if ($isDirectory) { [long]0 } else { [long]$item.Length }
        attributes = [string]$item.Attributes
        reparse_point = $isReparse
        key = ('{0}|{1}|{2}' -f $nativeKey, [long]$item.CreationTimeUtc.Ticks, $(if ($isDirectory) { 'directory' } else { 'file' }))
    }
}


function Test-FileSystemEntryIdentityShape {
    param($Identity)
    if ($null -eq $Identity) { return $false }
    foreach ($key in @('path', 'native_key', 'is_directory', 'creation_ticks', 'key')) {
        if (-not $Identity.Contains($key)) { return $false }
    }
    return (
        -not [string]::IsNullOrWhiteSpace([string]$Identity.path) `
        -and [string]$Identity.native_key -cmatch '^[0-9A-F]{8}:[0-9A-F]{16}$' `
        -and [long]$Identity.creation_ticks -gt 0 `
        -and -not [string]::IsNullOrWhiteSpace([string]$Identity.key)
    )
}


function Test-FileSystemEntryMatchesIdentity {
    param($ExpectedIdentity)
    if (-not (Test-FileSystemEntryIdentityShape -Identity $ExpectedIdentity)) { return $false }
    try {
        $allowReparse = $ExpectedIdentity.Contains('reparse_point') -and [bool]$ExpectedIdentity.reparse_point
        $current = Get-FileSystemEntryIdentity -Path ([string]$ExpectedIdentity.path) -AllowReparse:$allowReparse
        return (
            [string]$current.native_key -ceq [string]$ExpectedIdentity.native_key `
            -and [bool]$current.is_directory -eq [bool]$ExpectedIdentity.is_directory `
            -and [long]$current.creation_ticks -eq [long]$ExpectedIdentity.creation_ticks `
            -and [bool]$current.reparse_point -eq [bool]$ExpectedIdentity.reparse_point `
            -and [string]$current.key -ceq [string]$ExpectedIdentity.key
        )
    }
    catch {
        return $false
    }
}


function Read-NormalFilePinned {
    param(
        [string]$Path,
        $ExpectedIdentity = $null,
        [switch]$IncludeText
    )
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $stream = [System.IO.FileStream]::new(
        $resolved,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    try {
        $identityBefore = Get-FileSystemEntryIdentity -Path $resolved
        if ([bool]$identityBefore.is_directory -or [bool]$identityBefore.reparse_point) {
            throw "Pinned read requires a normal file: $resolved"
        }
        if ($null -ne $ExpectedIdentity -and -not (Test-FileSystemObjectsShareIdentity -Left $ExpectedIdentity -Right $identityBefore)) {
            throw "Pinned read opened a replacement file: $resolved"
        }
        $length = [long]$stream.Length
        $stream.Position = 0
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try { $sha256 = [System.BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '') }
        finally { $hasher.Dispose() }
        $bytes = $null
        $text = ''
        if ($IncludeText) {
            if ($length -gt [int]::MaxValue) { throw "Pinned text read exceeds the bounded evidence size: $resolved" }
            $bytes = [byte[]]::new([int]$length)
            $stream.Position = 0
            $offset = 0
            while ($offset -lt $bytes.Length) {
                $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
                if ($read -le 0) { throw "Pinned evidence read ended early: $resolved" }
                $offset += $read
            }
            $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        }
        $identityAfter = Get-FileSystemEntryIdentity -Path $resolved
        if (-not (Test-FileSystemObjectsShareIdentity -Left $identityBefore -Right $identityAfter)) {
            throw "Pinned evidence identity changed while its bytes were hashed: $resolved"
        }
        return [ordered]@{
            path = $resolved
            identity = $identityBefore
            length = $length
            sha256 = $sha256
            text = $text
        }
    }
    finally {
        $stream.Dispose()
    }
}


function Register-RetainedArtifactReceipt {
    param($EvidenceReceipt, $Receipt)
    if ($null -eq $script:rw06RetainedArtifactReceipts) { return $Receipt }
    if ($null -eq $Receipt -or -not $Receipt.Contains('path') -or -not $Receipt.Contains('relative_path') -or -not $Receipt.Contains('identity')) {
        throw 'Retained-artifact registration requires an exact path/relative-path/native-identity receipt.'
    }
    $resolved = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path ([string]$Receipt.path)
    $expectedRelative = $resolved.Substring(([string]$EvidenceReceipt.root).Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
    if ([string]$Receipt.relative_path -cne $expectedRelative) { throw 'Retained-artifact receipt path and relative path disagree.' }
    if (@($script:rw06RetainedArtifactReceipts | Where-Object { [string]$_.relative_path -ceq $expectedRelative }).Count -ne 0) {
        throw "Retained-artifact path was registered twice: $expectedRelative"
    }
    [void]$script:rw06RetainedArtifactReceipts.Add($Receipt)
    return $Receipt
}


function Assert-RetainedArtifactReceiptStable {
    param($EvidenceReceipt, $Receipt, [switch]$AllowReservedFile)
    $resolved = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path ([string]$Receipt.path)
    if (-not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $Receipt.identity)) {
        throw "Retained artifact identity changed: $([string]$Receipt.relative_path)"
    }
    if ([string]$Receipt.entry_type -ceq 'directory') {
        if (-not [bool]$Receipt.identity.is_directory) { throw 'Retained directory receipt has a file identity.' }
        return $true
    }
    if ([string]$Receipt.entry_type -cne 'file' -or [bool]$Receipt.identity.is_directory) {
        throw 'Retained artifact receipt has an invalid entry type.'
    }
    if (-not [bool]$Receipt.finalized) {
        if (-not $AllowReservedFile -or $null -eq $Receipt.guard_stream) { throw "Retained file is not finalized: $([string]$Receipt.relative_path)" }
        return $true
    }
    $readback = Read-NormalFilePinned -Path $resolved -ExpectedIdentity $Receipt.identity
    if ([long]$readback.length -ne [long]$Receipt.length -or [string]$readback.sha256 -cne [string]$Receipt.sha256) {
        throw "Retained artifact bytes changed: $([string]$Receipt.relative_path)"
    }
    return $true
}


function Assert-AllRetainedArtifactReceiptsStable {
    param($EvidenceReceipt, [switch]$AllowReservedFiles)
    if ($null -eq $script:rw06RetainedArtifactReceipts) { throw 'Retained-artifact registry is not active.' }
    foreach ($receipt in @($script:rw06RetainedArtifactReceipts)) {
        [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $EvidenceReceipt -Receipt $receipt -AllowReservedFile:$AllowReservedFiles)
    }
    return $true
}


function Remove-ExactOwnedFile {
    param(
        [string]$Path,
        $ExpectedIdentity,
        [string]$ExpectedSha256 = ''
    )
    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-FileSystemEntryIdentityShape -Identity $ExpectedIdentity) -or [bool]$ExpectedIdentity.is_directory -or [bool]$ExpectedIdentity.reparse_point) {
        throw 'Exact owned file cleanup requires a normal-file native identity receipt.'
    }
    if ([string]$ExpectedIdentity.path -cne $resolved) {
        throw 'Exact owned file cleanup path does not equal its native identity receipt.'
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Exact owned file disappeared before handle-bound cleanup: $resolved"
    }
    if (-not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $ExpectedIdentity)) {
        throw "Exact owned file was replaced before handle-bound cleanup: $resolved"
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256)) {
        if (-not (Test-ExactHexIdentity -Value $ExpectedSha256 -Length 64) -or (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash -cne $ExpectedSha256) {
            throw "Exact owned file bytes changed before handle-bound cleanup: $resolved"
        }
    }
    Initialize-Rw06NativeFileIdentityType
    [Rw06FileIdentityNative]::DeleteEntryExact(
        $resolved,
        [string]$ExpectedIdentity.native_key,
        [long]$ExpectedIdentity.creation_ticks,
        $false,
        $true
    )
    if (Test-Path -LiteralPath $resolved) {
        throw "Handle-bound exact owned file cleanup did not remove its identity: $resolved"
    }
    return [ordered]@{
        removed = $true
        path = $resolved
        identity = $ExpectedIdentity
        sha256 = $ExpectedSha256
        handle_bound = $true
    }
}


function Remove-ExactOwnedReparseEntry {
    param([string]$Path, $ExpectedIdentity)
    $resolved = [System.IO.Path]::GetFullPath($Path)
    if (
        -not (Test-FileSystemEntryIdentityShape -Identity $ExpectedIdentity) `
        -or -not [bool]$ExpectedIdentity.reparse_point `
        -or [string]$ExpectedIdentity.path -cne $resolved `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $ExpectedIdentity)
    ) { throw 'Exact reparse cleanup requires the same captured native reparse-object identity.' }
    Initialize-Rw06NativeFileIdentityType
    [Rw06FileIdentityNative]::DeleteEntryExact(
        $resolved,
        [string]$ExpectedIdentity.native_key,
        [long]$ExpectedIdentity.creation_ticks,
        [bool]$ExpectedIdentity.is_directory,
        $false
    )
    try { [void](Get-Item -LiteralPath $resolved -Force -ErrorAction Stop); throw 'Handle-bound exact reparse cleanup left the captured path present.' }
    catch [System.Management.Automation.ItemNotFoundException] {}
    return [ordered]@{ removed = $true; path = $resolved; identity = $ExpectedIdentity; handle_bound = $true }
}


function Assert-PathContainedByRoot {
    param([string]$Root, [string]$Path, [switch]$AllowRoot)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ($AllowRoot -and $resolvedPath -ceq $resolvedRoot) { return $resolvedPath }
    if (-not $resolvedPath.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escaped its approved root: $resolvedPath"
    }
    return $resolvedPath
}


function Assert-NormalDirectoryChain {
    param([string]$Root, [string]$DirectoryPath)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedDirectory = Assert-PathContainedByRoot -Root $resolvedRoot -Path $DirectoryPath -AllowRoot
    foreach ($path in @($resolvedRoot, $resolvedDirectory)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            throw "Required directory is unavailable: $path"
        }
    }
    $relative = $resolvedDirectory.Substring($resolvedRoot.Length).TrimStart([char[]]@([char]'\', [char]'/'))
    $cursor = $resolvedRoot
    $parts = if ([string]::IsNullOrWhiteSpace($relative)) { @() } else { @($relative -split '[\\/]') }
    foreach ($part in $parts) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Directory chain contains a non-directory or reparse point: $cursor"
        }
    }
    $rootItem = Get-Item -LiteralPath $resolvedRoot -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Approved root is a reparse point: $resolvedRoot"
    }
    return $resolvedDirectory
}


function Ensure-NormalDirectoryPath {
    param([string]$Root, [string]$DirectoryPath)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedDirectory = Assert-PathContainedByRoot -Root $resolvedRoot -Path $DirectoryPath -AllowRoot
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Directory creation root is unavailable: $resolvedRoot"
    }
    $rootItem = Get-Item -LiteralPath $resolvedRoot -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Directory creation root is a reparse point: $resolvedRoot"
    }
    $relative = $resolvedDirectory.Substring($resolvedRoot.Length).TrimStart([char[]]@([char]'\', [char]'/'))
    $cursor = $resolvedRoot
    foreach ($part in @($relative -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor)) {
            [void][System.IO.Directory]::CreateDirectory($cursor)
        }
        $item = Get-Item -LiteralPath $cursor -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Created directory chain contains a non-directory or reparse point: $cursor"
        }
    }
    return $resolvedDirectory
}


function New-ValidateOnlySelftestRoot {
    param([string]$RequiredNamePrefix)
    if (-not $ValidateOnly) {
        throw 'ValidateOnly self-test roots may only be created by -ValidateOnly.'
    }
    if ($RequiredNamePrefix -cnotin @('lease-selftest-', 'launcher-selftest-')) {
        throw 'ValidateOnly self-test root prefix is not an exact approved prefix.'
    }
    $selftestParent = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp\rw06_6')).TrimEnd([char[]]@([char]'\', [char]'/'))
    [void](Assert-NormalDirectoryChain -Root $selftestParent -DirectoryPath $selftestParent)
    $nonce = [guid]::NewGuid().ToString('N')
    $resolved = Join-Path $selftestParent ($RequiredNamePrefix + $nonce)
    $temporaryRoot = Join-Path $selftestParent ('.rw06_6-selftest-claim-' + $nonce)
    if ((Test-Path -LiteralPath $resolved) -or (Test-Path -LiteralPath $temporaryRoot)) {
        throw 'Fresh ValidateOnly self-test destination or temporary claim root unexpectedly exists.'
    }
    $claimName = '.rw06_6-validateonly-owner.json'
    $temporaryClaimPath = Join-Path $temporaryRoot $claimName
    $preMoveRootIdentity = $null
    $preMoveClaimIdentity = $null
    $claimSha256 = ''
    $ownerIdentity = Get-ProcessIdentityRecord -Process (Get-Process -Id $PID -ErrorAction Stop)
    if (-not (Test-ExactLeaseOwnerIdentityShape -Identity $ownerIdentity) -or -not (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $ownerIdentity)) {
        throw 'ValidateOnly self-test root creation requires the exact live launcher process identity.'
    }
    try {
        [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
        [void](Assert-NormalDirectoryChain -Root $selftestParent -DirectoryPath $temporaryRoot)
        $preMoveRootIdentity = Get-FileSystemEntryIdentity -Path $temporaryRoot
        $claimPayload = [ordered]@{
            contract = 'rw06_6_validateonly_selftest_owner_v1'
            nonce = $nonce
            required_name_prefix = $RequiredNamePrefix
            root = $resolved
            root_native_key = [string]$preMoveRootIdentity.native_key
            root_creation_ticks = [long]$preMoveRootIdentity.creation_ticks
            owner_pid = [int]$ownerIdentity.pid
            owner_name = [string]$ownerIdentity.name
            owner_start_utc = [string]$ownerIdentity.start_utc
            owner_start_ticks = [long]$ownerIdentity.start_ticks
            owner_key = [string]$ownerIdentity.key
            owner_executable_path = [string]$ownerIdentity.executable_path
            owner_executable_sha256 = [string]$ownerIdentity.executable_sha256
            owner_executable_native_key = [string]$ownerIdentity.executable_identity.native_key
            owner_executable_creation_ticks = [long]$ownerIdentity.executable_identity.creation_ticks
            created_utc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json -Depth 5
        $claimBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($claimPayload + "`n")
        $claimStream = [System.IO.FileStream]::new($temporaryClaimPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $claimStream.Write($claimBytes, 0, $claimBytes.Length)
            $claimStream.Flush($true)
        }
        finally {
            $claimStream.Dispose()
        }
        $preMoveClaimIdentity = Get-FileSystemEntryIdentity -Path $temporaryClaimPath
        $claimSha256 = (Get-FileHash -LiteralPath $temporaryClaimPath -Algorithm SHA256).Hash
        [System.IO.Directory]::Move($temporaryRoot, $resolved)
    }
    catch {
        # Without a complete post-move ownership receipt, preserve the object for
        # forensic recovery.  In particular, never path-delete a raced root.
        throw
    }
    $claimPath = Join-Path $resolved $claimName
    $rootIdentity = Get-FileSystemEntryIdentity -Path $resolved
    $claimIdentity = Get-FileSystemEntryIdentity -Path $claimPath
    if (
        -not (Test-FileSystemObjectsShareIdentity -Left $preMoveRootIdentity -Right $rootIdentity) `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $preMoveClaimIdentity -Right $claimIdentity) `
        -or (Get-FileHash -LiteralPath $claimPath -Algorithm SHA256).Hash -cne $claimSha256
    ) {
        throw 'ValidateOnly self-test root or owner claim identity changed across its atomic move; retaining every object.'
    }
    return [ordered]@{
        contract = 'rw06_6_validateonly_selftest_owner_v1'
        path = $resolved
        approved_parent = $selftestParent
        required_name_prefix = $RequiredNamePrefix
        nonce = $nonce
        claim_path = $claimPath
        claim_sha256 = $claimSha256
        owner_identity = $ownerIdentity
        pre_move_root_identity = $preMoveRootIdentity
        pre_move_claim_identity = $preMoveClaimIdentity
        root_identity = $rootIdentity
        claim_identity = $claimIdentity
        post_move_identity_verified = $true
        atomically_owned = $true
    }
}


function Remove-ExactValidateOnlySelftestRoot {
    param($Receipt)
    if (-not $ValidateOnly) {
        throw 'ValidateOnly self-test roots may only be removed by -ValidateOnly.'
    }
    $requiredReceiptFields = @(
        'contract', 'path', 'approved_parent', 'required_name_prefix', 'nonce',
        'claim_path', 'claim_sha256', 'owner_identity', 'pre_move_root_identity',
        'pre_move_claim_identity', 'root_identity', 'claim_identity',
        'post_move_identity_verified', 'atomically_owned'
    )
    if ($null -eq $Receipt) { throw 'ValidateOnly cleanup requires a sealed ownership receipt.' }
    foreach ($field in $requiredReceiptFields) {
        if (-not $Receipt.Contains($field)) { throw "ValidateOnly ownership receipt lacks field: $field" }
    }
    if (
        [string]$Receipt.contract -cne 'rw06_6_validateonly_selftest_owner_v1' `
        -or -not [bool]$Receipt.atomically_owned `
        -or -not [bool]$Receipt.post_move_identity_verified
    ) {
        throw 'ValidateOnly cleanup ownership receipt is absent or unsealed.'
    }
    $RequiredNamePrefix = [string]$Receipt.required_name_prefix
    if ($RequiredNamePrefix -cnotin @('lease-selftest-', 'launcher-selftest-')) {
        throw 'ValidateOnly cleanup receipt prefix is not an exact approved prefix.'
    }
    $nonce = [string]$Receipt.nonce
    if ($nonce -cnotmatch '^[0-9a-f]{32}$') {
        throw 'ValidateOnly cleanup receipt nonce is malformed.'
    }
    $selftestParent = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp\rw06_6')).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ([string]$Receipt.approved_parent -cne $selftestParent) {
        throw 'ValidateOnly cleanup receipt approved parent changed.'
    }
    $resolved = [System.IO.Path]::GetFullPath([string]$Receipt.path).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ([System.IO.Path]::GetDirectoryName($resolved) -cne $selftestParent) {
        throw 'ValidateOnly cleanup target is not a direct child of the exact .tmp/rw06_6 parent.'
    }
    if ([System.IO.Path]::GetFileName($resolved) -cne ($RequiredNamePrefix + $nonce)) {
        throw 'ValidateOnly cleanup target does not exactly bind its approved prefix and nonce.'
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw 'ValidateOnly exact self-test root disappeared before owned cleanup.'
    }
    [void](Assert-NormalDirectoryChain -Root $selftestParent -DirectoryPath $resolved)
    $claimPath = [System.IO.Path]::GetFullPath([string]$Receipt.claim_path)
    if ($claimPath -cne (Join-Path $resolved '.rw06_6-validateonly-owner.json')) {
        throw 'ValidateOnly cleanup claim path is not exact.'
    }
    if (
        [string]$Receipt.root_identity.path -cne $resolved `
        -or [string]$Receipt.claim_identity.path -cne $claimPath `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $Receipt.root_identity) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $Receipt.claim_identity) `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $Receipt.pre_move_root_identity -Right $Receipt.root_identity) `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $Receipt.pre_move_claim_identity -Right $Receipt.claim_identity)
    ) {
        throw 'ValidateOnly cleanup root or owner-claim native identity changed.'
    }
    if (
        -not (Test-ExactHexIdentity -Value ([string]$Receipt.claim_sha256) -Length 64) `
        -or (Get-FileHash -LiteralPath $claimPath -Algorithm SHA256).Hash -cne [string]$Receipt.claim_sha256
    ) {
        throw 'ValidateOnly cleanup owner-claim bytes changed.'
    }
    if (
        -not (Test-ExactLeaseOwnerIdentityShape -Identity $Receipt.owner_identity) `
        -or [int]$Receipt.owner_identity.pid -ne [int]$PID `
        -or -not (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $Receipt.owner_identity)
    ) {
        throw 'ValidateOnly cleanup owner is not this exact live launcher process.'
    }
    try { $claim = [System.IO.File]::ReadAllText($claimPath) | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'ValidateOnly cleanup owner claim is not strict JSON.' }
    $expectedClaimFields = @(
        'contract', 'nonce', 'required_name_prefix', 'root', 'root_native_key',
        'root_creation_ticks', 'owner_pid', 'owner_name', 'owner_start_utc',
        'owner_start_ticks', 'owner_key', 'owner_executable_path',
        'owner_executable_sha256', 'owner_executable_native_key',
        'owner_executable_creation_ticks', 'created_utc'
    )
    $claimFields = @($claim.PSObject.Properties | ForEach-Object { [string]$_.Name })
    if ($claimFields.Count -ne $expectedClaimFields.Count -or @($expectedClaimFields | Where-Object { $claimFields -cnotcontains $_ }).Count -ne 0) {
        throw 'ValidateOnly cleanup owner claim schema changed.'
    }
    $createdUtc = [datetime]::MinValue
    if (
        [string]$claim.contract -cne 'rw06_6_validateonly_selftest_owner_v1' `
        -or [string]$claim.nonce -cne $nonce `
        -or [string]$claim.required_name_prefix -cne $RequiredNamePrefix `
        -or [string]$claim.root -cne $resolved `
        -or [string]$claim.root_native_key -cne [string]$Receipt.root_identity.native_key `
        -or [long]$claim.root_creation_ticks -ne [long]$Receipt.root_identity.creation_ticks `
        -or [int]$claim.owner_pid -ne [int]$Receipt.owner_identity.pid `
        -or [string]$claim.owner_name -cne [string]$Receipt.owner_identity.name `
        -or [string]$claim.owner_start_utc -cne [string]$Receipt.owner_identity.start_utc `
        -or [long]$claim.owner_start_ticks -ne [long]$Receipt.owner_identity.start_ticks `
        -or [string]$claim.owner_key -cne [string]$Receipt.owner_identity.key `
        -or [string]$claim.owner_executable_path -cne [string]$Receipt.owner_identity.executable_path `
        -or [string]$claim.owner_executable_sha256 -cne [string]$Receipt.owner_identity.executable_sha256 `
        -or [string]$claim.owner_executable_native_key -cne [string]$Receipt.owner_identity.executable_identity.native_key `
        -or [long]$claim.owner_executable_creation_ticks -ne [long]$Receipt.owner_identity.executable_identity.creation_ticks `
        -or -not [datetime]::TryParse([string]$claim.created_utc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$createdUtc) `
        -or $createdUtc.ToUniversalTime().Ticks -lt [long]$Receipt.owner_identity.start_ticks `
        -or $createdUtc.ToUniversalTime() -gt [DateTime]::UtcNow.AddMinutes(1)
    ) {
        throw 'ValidateOnly cleanup owner claim does not match its sealed receipt.'
    }
    $quarantine = Join-Path $selftestParent ('.rw06_6-selftest-quarantine-' + [guid]::NewGuid().ToString('N'))
    $cleanupReceipt = Remove-ExactOwnedDirectoryTree -OwnedPath $resolved -QuarantinePath $quarantine -ExpectedRootIdentity $Receipt.root_identity
    if (-not [bool]$cleanupReceipt.handle_bound -or -not [bool]$cleanupReceipt.quarantine_absent) {
        throw "ValidateOnly handle-bound self-test cleanup failed: $resolved"
    }
}


function Get-ValidateOnlyFixtureResidueInventory {
    $selftestParent = [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.tmp\rw06_6')).TrimEnd([char[]]@([char]'\', [char]'/'))
    [void](Assert-NormalDirectoryChain -Root $selftestParent -DirectoryPath $selftestParent)
    $records = [System.Collections.Generic.List[object]]::new()
    $knownPrefixes = @(
        'launcher-selftest-',
        'lease-selftest-',
        'evidence-selftest-parent-',
        'cache-provenance-selftest-',
        '.rw06_6-selftest-'
    )
    foreach ($item in @(Get-ChildItem -LiteralPath $selftestParent -Force -ErrorAction Stop | Sort-Object Name)) {
        $name = [string]$item.Name
        # Recovery receipts are durable forensic evidence, not runnable fixture
        # roots.  They are deliberately retained and excluded from this gate.
        if (-not $item.PSIsContainer -and $name -cmatch '^recovery-receipt-.+-(?:pre|result)\.json$') { continue }
        $knownPrefix = @($knownPrefixes | Where-Object { $name.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        $unknownSelftest = $name.IndexOf('selftest', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        $unknownFixture = $name.IndexOf('fixture', [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        if (-not $knownPrefix -and -not $unknownSelftest -and -not $unknownFixture) { continue }
        $allowReparse = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        $records.Add([ordered]@{
            name = $name
            path = [string]$item.FullName
            known_prefix = [bool]$knownPrefix
            unknown_selftest_name = [bool](-not $knownPrefix -and $unknownSelftest)
            unknown_fixture_name = [bool](-not $knownPrefix -and $unknownFixture)
            is_directory = [bool]$item.PSIsContainer
            reparse_point = [bool]$allowReparse
            identity = Get-FileSystemEntryIdentity -Path $item.FullName -AllowReparse:$allowReparse
        })
    }
    return @($records)
}


function Assert-ValidateOnlyFixtureRootClean {
    param([string]$Context)
    $residue = @(Get-ValidateOnlyFixtureResidueInventory)
    if ($residue.Count -ne 0) {
        # No prefix/path deletion is authorized here.  A historical object may
        # be recovered only by a separate forensic flow whose pre-existing
        # claim and receipt bind its exact owner PID/start/nonce/root identity,
        # complete inventory, and proven-dead owner.  Unverifiable objects are
        # preserved and block ValidateOnly.
        $claimBearing = @($residue | Where-Object {
            [bool]$_.is_directory -and (Test-Path -LiteralPath (Join-Path ([string]$_.path) '.rw06_6-validateonly-owner.json') -PathType Leaf)
        })
        # A root-local claim is necessary but never sufficient historical
        # recovery authority.  No current inventory or newly written ledger may
        # confer ownership; an independently pre-existing external receipt must
        # also bind the exact claim identity/hash, root identity, full no-reparse
        # tree inventory, and exact owner death before recovery is possible.
        $recoverable = @()
        $unproven = @($residue)
        Write-Host ("RW06_6_FIXTURE_OWNERSHIP_INVENTORY recoverable={0} unproven={1} claim_bearing={2}" -f $recoverable.Count, $unproven.Count, $claimBearing.Count)
        $names = @($unproven | ForEach-Object { [string]$_.name }) -join ','
        throw "$Context requires zero fixture residue; preserving $($unproven.Count) unproven object(s), recoverable=0: $names"
    }
    return [ordered]@{
        residue_count = 0
        recovery_policy = 'exact_preexisting_claim_receipt_dead_owner_only'
        recovery_receipts_preserved = $true
    }
}


function Initialize-OwnedEvidenceRoot {
    param(
        [string]$RequestedRoot,
        [string]$ApprovedParent,
        [string]$CandidateCommit,
        [string]$CandidateTree,
        [string]$Role,
        [switch]$ForceDestinationRaceForTest,
        [switch]$ForcePostMoveCopiedClaimReplacementForTest
    )
    $resolvedParent = Ensure-NormalDirectoryPath -Root $projectRoot -DirectoryPath $ApprovedParent
    $resolvedRoot = [System.IO.Path]::GetFullPath($RequestedRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ([System.IO.Path]::GetDirectoryName($resolvedRoot) -cne $resolvedParent) {
        throw 'EvidenceRoot must be a direct child of the approved candidate-local evidence parent.'
    }
    if (Test-Path -LiteralPath $resolvedRoot) {
        throw "EvidenceRoot must be fresh and absent: $resolvedRoot"
    }
    $nonce = [guid]::NewGuid().ToString('N')
    $temporaryRoot = Join-Path $resolvedParent ('.rw06_6-claim-' + $nonce)
    if (Test-Path -LiteralPath $temporaryRoot) {
        throw 'Fresh evidence-root claim path unexpectedly exists.'
    }
    $claimName = '.rw06_6-evidence-owner.json'
    $claimPath = Join-Path $temporaryRoot $claimName
    $preMoveRootIdentity = $null
    $preMoveClaimIdentity = $null
    $claimSha256 = ''
    try {
        [void][System.IO.Directory]::CreateDirectory($temporaryRoot)
        [void](Assert-NormalDirectoryChain -Root $resolvedParent -DirectoryPath $temporaryRoot)
        $claimPayload = [ordered]@{
            contract = 'rw06_6_pull_tab_glimmer'
            nonce = $nonce
            owner_pid = [int]$PID
            requested_root = $resolvedRoot
            candidate_commit = $CandidateCommit
            candidate_tree = $CandidateTree
            role = $Role
            created_utc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json -Depth 4
        $claimBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($claimPayload + "`n")
        $stream = [System.IO.FileStream]::new($claimPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $stream.Write($claimBytes, 0, $claimBytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }
        $preMoveRootIdentity = Get-FileSystemEntryIdentity -Path $temporaryRoot
        $preMoveClaimIdentity = Get-FileSystemEntryIdentity -Path $claimPath
        $claimSha256 = (Get-FileHash -LiteralPath $claimPath -Algorithm SHA256).Hash
        if ($ForceDestinationRaceForTest) {
            [void][System.IO.Directory]::CreateDirectory($resolvedRoot)
            [System.IO.File]::WriteAllText((Join-Path $resolvedRoot 'foreign-race.txt'), "foreign`n")
        }
        [System.IO.Directory]::Move($temporaryRoot, $resolvedRoot)
        if ($ForcePostMoveCopiedClaimReplacementForTest) {
            $ownedOriginal = $resolvedRoot + '.owned-original'
            if (Test-Path -LiteralPath $ownedOriginal) {
                throw 'Forced post-move evidence replacement original already exists.'
            }
            [System.IO.Directory]::Move($resolvedRoot, $ownedOriginal)
            [void][System.IO.Directory]::CreateDirectory($resolvedRoot)
            [System.IO.File]::Copy((Join-Path $ownedOriginal $claimName), (Join-Path $resolvedRoot $claimName), $false)
        }
    }
    catch {
        # A failed atomic move may mean either our exact temporary claim or a
        # raced replacement is now at this path. Preserve it for forensic
        # evidence; never path-delete an identity that is no longer proven.
        throw
    }
    $finalClaimPath = Join-Path $resolvedRoot $claimName
    $rootIdentity = Get-FileSystemEntryIdentity -Path $resolvedRoot
    $claimIdentity = Get-FileSystemEntryIdentity -Path $finalClaimPath
    if (
        -not (Test-FileSystemObjectsShareIdentity -Left $preMoveRootIdentity -Right $rootIdentity) `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $preMoveClaimIdentity -Right $claimIdentity) `
        -or (Get-FileHash -LiteralPath $finalClaimPath -Algorithm SHA256).Hash -cne $claimSha256
    ) {
        throw 'EvidenceRoot or copied owner claim identity changed across its atomic move; retaining every object.'
    }
    return [ordered]@{
        root = $resolvedRoot
        approved_parent = $resolvedParent
        nonce = $nonce
        claim_path = $finalClaimPath
        claim_sha256 = $claimSha256
        pre_move_root_identity = $preMoveRootIdentity
        pre_move_claim_identity = $preMoveClaimIdentity
        root_identity = $rootIdentity
        claim_identity = $claimIdentity
        post_move_identity_verified = $true
        atomically_owned = $true
    }
}


function Assert-OwnedEvidenceRoot {
    param($Receipt)
    if ($null -eq $Receipt -or -not [bool]$Receipt.atomically_owned -or -not [bool]$Receipt.post_move_identity_verified) {
        throw 'EvidenceRoot ownership receipt is absent or unsealed.'
    }
    [void](Assert-NormalDirectoryChain -Root ([string]$Receipt.approved_parent) -DirectoryPath ([string]$Receipt.root))
    if (-not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $Receipt.root_identity)) {
        throw 'EvidenceRoot directory identity changed after atomic ownership.'
    }
    if (-not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $Receipt.claim_identity)) {
        throw 'EvidenceRoot ownership claim identity changed.'
    }
    if (
        -not (Test-FileSystemObjectsShareIdentity -Left $Receipt.pre_move_root_identity -Right $Receipt.root_identity) `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $Receipt.pre_move_claim_identity -Right $Receipt.claim_identity)
    ) {
        throw 'EvidenceRoot pre-move and post-move native identities no longer agree.'
    }
    $claimSha = (Get-FileHash -LiteralPath ([string]$Receipt.claim_path) -Algorithm SHA256).Hash
    if ($claimSha -cne [string]$Receipt.claim_sha256) {
        throw 'EvidenceRoot ownership claim bytes changed.'
    }
    return $true
}


function New-OwnedEvidenceSubdirectory {
    param($EvidenceReceipt, [string]$DestinationPath, [switch]$ForcePostMoveReplacementForTest)
    [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt)
    if ($null -ne $script:rw06RetainedArtifactReceipts) {
        [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $EvidenceReceipt -AllowReservedFiles)
    }
    $resolvedDestination = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path $DestinationPath
    $parent = [System.IO.Path]::GetDirectoryName($resolvedDestination)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Evidence subdirectory parent must already have an ownership receipt: $parent"
    }
    [void](Assert-NormalDirectoryChain -Root ([string]$EvidenceReceipt.root) -DirectoryPath $parent)
    if (Test-Path -LiteralPath $resolvedDestination) {
        throw "Evidence subdirectory already exists: $resolvedDestination"
    }
    $temporary = Join-Path $parent ('.rw06_6-dir-' + [guid]::NewGuid().ToString('N'))
    $preMoveIdentity = $null
    try {
        [void][System.IO.Directory]::CreateDirectory($temporary)
        $preMoveIdentity = Get-FileSystemEntryIdentity -Path $temporary
        [System.IO.Directory]::Move($temporary, $resolvedDestination)
        if ($ForcePostMoveReplacementForTest) {
            $ownedOriginal = $resolvedDestination + '.owned-original'
            if (Test-Path -LiteralPath $ownedOriginal) { throw 'Forced evidence-subdirectory original already exists.' }
            [System.IO.Directory]::Move($resolvedDestination, $ownedOriginal)
            [void][System.IO.Directory]::CreateDirectory($resolvedDestination)
        }
    }
    catch {
        # Preserve a failed temporary directory instead of risking deletion of
        # a path replacement introduced during the atomic-move race.
        throw
    }
    [void](Assert-NormalDirectoryChain -Root ([string]$EvidenceReceipt.root) -DirectoryPath $resolvedDestination)
    $postMoveIdentity = Get-FileSystemEntryIdentity -Path $resolvedDestination
    if (-not (Test-FileSystemObjectsShareIdentity -Left $preMoveIdentity -Right $postMoveIdentity)) {
        throw 'Evidence subdirectory identity changed across its atomic move; retaining both objects.'
    }
    $receipt = [ordered]@{
        path = $resolvedDestination
        relative_path = $resolvedDestination.Substring(([string]$EvidenceReceipt.root).Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
        entry_type = 'directory'
        reparse_point = $false
        length = [long]0
        sha256 = ''
        pre_move_identity = $preMoveIdentity
        identity = $postMoveIdentity
        finalized = $true
        guard_stream = $null
        post_move_identity_verified = $true
    }
    return Register-RetainedArtifactReceipt -EvidenceReceipt $EvidenceReceipt -Receipt $receipt
}


function Write-AtomicSealedBytes {
    param(
        $EvidenceReceipt,
        [string]$DestinationPath,
        [byte[]]$Bytes,
        [switch]$ForcePostMoveReplacementForTest
    )
    [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt)
    if ($null -ne $script:rw06RetainedArtifactReceipts) {
        [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $EvidenceReceipt -AllowReservedFiles)
    }
    $resolvedDestination = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path $DestinationPath
    $parent = [System.IO.Path]::GetDirectoryName($resolvedDestination)
    [void](Assert-NormalDirectoryChain -Root ([string]$EvidenceReceipt.root) -DirectoryPath $parent)
    if (Test-Path -LiteralPath $resolvedDestination) {
        throw "Atomic evidence destination already exists: $resolvedDestination"
    }
    $temporary = Join-Path $parent ('.rw06_6-write-' + [guid]::NewGuid().ToString('N'))
    $preMoveIdentity = $null
    try {
        $stream = [System.IO.FileStream]::new($temporary, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        try {
            $stream.Write($Bytes, 0, $Bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }
        $preMoveIdentity = Get-FileSystemEntryIdentity -Path $temporary
        [System.IO.File]::Move($temporary, $resolvedDestination)
        if ($ForcePostMoveReplacementForTest) {
            $ownedOriginal = $resolvedDestination + '.owned-original'
            if (Test-Path -LiteralPath $ownedOriginal) { throw 'Forced atomic-evidence original already exists.' }
            [System.IO.File]::Move($resolvedDestination, $ownedOriginal)
            [System.IO.File]::Copy($ownedOriginal, $resolvedDestination, $false)
        }
    }
    catch {
        # CreateNew + same-directory Move is no-overwrite. If the destination
        # or temporary path raced, preserve both rather than delete by path.
        throw
    }
    $expectedSha = [System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::Create().ComputeHash($Bytes)).Replace('-', '')
    $readback = Read-NormalFilePinned -Path $resolvedDestination -ExpectedIdentity $preMoveIdentity
    $postMoveIdentity = $readback.identity
    $actualSha = [string]$readback.sha256
    if (
        [long]$readback.length -ne $Bytes.Length `
        -or $actualSha -cne $expectedSha `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $preMoveIdentity -Right $postMoveIdentity)
    ) {
        throw "Atomic evidence readback seal failed: $resolvedDestination"
    }
    $receipt = [ordered]@{
        path = $resolvedDestination
        relative_path = $resolvedDestination.Substring(([string]$EvidenceReceipt.root).Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
        entry_type = 'file'
        reparse_point = $false
        length = [long]$readback.length
        sha256 = $actualSha
        pre_move_identity = $preMoveIdentity
        identity = $postMoveIdentity
        finalized = $true
        guard_stream = $null
        atomic_no_overwrite = $true
        post_move_identity_verified = $true
        readback_verified = $true
    }
    return Register-RetainedArtifactReceipt -EvidenceReceipt $EvidenceReceipt -Receipt $receipt
}


function Write-AtomicSealedText {
    param($EvidenceReceipt, [string]$DestinationPath, [string]$Text, [switch]$ForcePostMoveReplacementForTest)
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    return Write-AtomicSealedBytes -EvidenceReceipt $EvidenceReceipt -DestinationPath $DestinationPath -Bytes $bytes -ForcePostMoveReplacementForTest:$ForcePostMoveReplacementForTest
}


function New-OwnedEvidenceDirectoryChain {
    param($EvidenceReceipt, [string]$DestinationPath)
    $root = [System.IO.Path]::GetFullPath([string]$EvidenceReceipt.root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolved = Assert-PathContainedByRoot -Root $root -Path $DestinationPath
    $relative = $resolved.Substring($root.Length).TrimStart([char[]]@([char]'\', [char]'/'))
    $cursor = $root
    $receipts = [System.Collections.Generic.List[object]]::new()
    foreach ($segment in @($relative.Split([char[]]@([char]'\', [char]'/'), [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $segment
        if (Test-Path -LiteralPath $cursor -PathType Container) {
            $existing = @($script:rw06RetainedArtifactReceipts | Where-Object { [string]$_.path -ceq [System.IO.Path]::GetFullPath($cursor) })
            if ($existing.Count -ne 1 -or [string]$existing[0].entry_type -cne 'directory') {
                throw "Evidence directory chain encountered an unreceipted directory: $cursor"
            }
            [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $EvidenceReceipt -Receipt $existing[0])
            continue
        }
        [void]$receipts.Add((New-OwnedEvidenceSubdirectory -EvidenceReceipt $EvidenceReceipt -DestinationPath $cursor))
    }
    return @($receipts)
}


function New-OwnedEvidenceFileReservation {
    param($EvidenceReceipt, [string]$DestinationPath)
    [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt)
    if ($null -ne $script:rw06RetainedArtifactReceipts) {
        [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $EvidenceReceipt -AllowReservedFiles)
    }
    $resolved = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path $DestinationPath
    $parent = [System.IO.Path]::GetDirectoryName($resolved)
    [void](Assert-NormalDirectoryChain -Root ([string]$EvidenceReceipt.root) -DirectoryPath $parent)
    if (Test-Path -LiteralPath $resolved) { throw "Evidence file reservation must be fresh: $resolved" }
    $creator = [System.IO.FileStream]::new($resolved, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try { $creator.Flush($true) } finally { $creator.Dispose() }
    $identity = Get-FileSystemEntryIdentity -Path $resolved
    $guard = $null
    try {
        # Allow the owned writer but deny delete/rename until the exact output is
        # finalized, so a path swap cannot be hidden by restoring equal bytes.
        $guard = [System.IO.FileStream]::new($resolved, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $guardIdentity = Get-FileSystemEntryIdentity -Path $resolved
        if (-not (Test-FileSystemObjectsShareIdentity -Left $identity -Right $guardIdentity)) {
            throw "Evidence reservation changed before its guard handle opened: $resolved"
        }
        $receipt = [ordered]@{
            path = $resolved
            relative_path = $resolved.Substring(([string]$EvidenceReceipt.root).Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
            entry_type = 'file'
            reparse_point = $false
            length = [long]-1
            sha256 = ''
            identity = $identity
            finalized = $false
            guard_stream = $guard
            atomic_no_overwrite = $true
            post_move_identity_verified = $true
            readback_verified = $false
        }
        [void](Register-RetainedArtifactReceipt -EvidenceReceipt $EvidenceReceipt -Receipt $receipt)
        return $receipt
    }
    catch {
        if ($null -ne $guard) { $guard.Dispose() }
        throw
    }
}


function Complete-OwnedEvidenceFileReservation {
    param($EvidenceReceipt, $Receipt, [switch]$IncludeText)
    if ($null -eq $Receipt -or [bool]$Receipt.finalized -or $null -eq $Receipt.guard_stream) {
        throw 'Evidence output reservation is absent, already finalized, or lacks its guard handle.'
    }
    $guard = $Receipt.guard_stream
    try {
        $identity = Get-FileSystemEntryIdentity -Path ([string]$Receipt.path)
        if (-not (Test-FileSystemObjectsShareIdentity -Left $Receipt.identity -Right $identity)) {
            throw "Evidence output identity changed while guarded: $([string]$Receipt.path)"
        }
        $guard.Flush()
        $length = [long]$guard.Length
        $guard.Position = 0
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try { $sha256 = [System.BitConverter]::ToString($hasher.ComputeHash($guard)).Replace('-', '') }
        finally { $hasher.Dispose() }
        $text = ''
        if ($IncludeText) {
            if ($length -gt [int]::MaxValue) { throw 'Evidence output exceeds the bounded text-read size.' }
            $bytes = [byte[]]::new([int]$length)
            $guard.Position = 0
            $offset = 0
            while ($offset -lt $bytes.Length) {
                $read = $guard.Read($bytes, $offset, $bytes.Length - $offset)
                if ($read -le 0) { throw 'Evidence output guard read ended early.' }
                $offset += $read
            }
            $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        }
        $Receipt.length = $length
        $Receipt.sha256 = $sha256
        $Receipt.finalized = $true
        $Receipt.readback_verified = $true
        return [ordered]@{ receipt = $Receipt; text = $text }
    }
    finally {
        $guard.Dispose()
        $Receipt.guard_stream = $null
    }
}


function Test-FocusedLaunchCapacity {
    param(
        [bool]$ExclusivePresent,
        [int]$LiveFocusedLeaseCount,
        [int]$LiveGodotProcessCount
    )
    return (-not $ExclusivePresent) -and $LiveFocusedLeaseCount -lt 2 -and ($LiveGodotProcessCount + 2) -le 4
}


function Test-ReservedLaunchCapacity {
    param(
        [bool]$ExclusivePresent,
        [int]$LiveFocusedLeaseCount,
        [int]$LiveGodotProcessCount
    )
    return (-not $ExclusivePresent) -and $LiveFocusedLeaseCount -le 2 -and ($LiveGodotProcessCount + 2) -le 4
}


function Assert-ExactCandidateIdentity {
    param(
        [string]$RequiredCommit,
        [string]$RequiredTree,
        [string]$ActualCommit,
        [string]$ActualTree
    )
    if ([string]::IsNullOrWhiteSpace($RequiredCommit) -or [string]::IsNullOrWhiteSpace($RequiredTree)) {
        throw 'ExpectedCommit and ExpectedTree are both required for every evidence run.'
    }
    if ($ActualCommit -ne $RequiredCommit.Trim()) {
        throw "Candidate commit mismatch: expected $RequiredCommit, found $ActualCommit."
    }
    if ($ActualTree -ne $RequiredTree.Trim()) {
        throw "Candidate tree mismatch: expected $RequiredTree, found $ActualTree."
    }
}


function Assert-CleanExactCandidate {
    param(
        [string]$Root,
        [string]$RequiredCommit,
        [string]$RequiredTree
    )
    $dirty = @(& git -C $Root status --porcelain)
    $statusExitCode = $LASTEXITCODE
    if ($statusExitCode -ne 0 -or $dirty.Count -ne 0) {
        throw 'RW06_6 evidence requires a clean committed candidate tree.'
    }
    $actualCommit = (& git -C $Root rev-parse HEAD).Trim()
    $commitExitCode = $LASTEXITCODE
    $actualTree = (& git -C $Root rev-parse 'HEAD^{tree}').Trim()
    $treeExitCode = $LASTEXITCODE
    if (
        $commitExitCode -ne 0 `
        -or $treeExitCode -ne 0 `
        -or [string]::IsNullOrWhiteSpace($actualCommit) `
        -or [string]::IsNullOrWhiteSpace($actualTree)
    ) {
        throw 'Could not resolve the exact candidate commit/tree.'
    }
    Assert-ExactCandidateIdentity $RequiredCommit $RequiredTree $actualCommit $actualTree
    return [ordered]@{ commit = $actualCommit; tree = $actualTree }
}


function Get-LiveGodotProcesses {
    return @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')
    })
}


function Assert-NormalLeaseRoot {
    param([string]$Root = $leaseRoot, [switch]$RequireCanonical)
    $resolved = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ($RequireCanonical -and $resolved -cne $canonicalLeaseRoot) {
        throw 'Lease root is not the exact canonical Q-009 path.'
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Lease root is unavailable: $resolved"
    }
    $item = Get-Item -LiteralPath $resolved -Force
    if (-not $item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Lease root is not a normal directory: $resolved"
    }
    $parent = [System.IO.Path]::GetDirectoryName($resolved)
    [void](Assert-NormalDirectoryChain -Root $parent -DirectoryPath $resolved)
    return Get-FileSystemEntryIdentity -Path $resolved
}


function Get-StrictLeaseEntryRecords {
    param([string]$Root = $leaseRoot, [switch]$RequireCanonical)
    [void](Assert-NormalLeaseRoot -Root $Root -RequireCanonical:$RequireCanonical)
    $resolved = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @(Get-ChildItem -LiteralPath $resolved -Force -ErrorAction Stop | Sort-Object Name)) {
        if (-not $item.Name.EndsWith('.lease', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Unexpected object exists in the strict Q-009 lease root: $($item.FullName)"
        }
        if ($item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Lease-like object is not a normal file: $($item.FullName)"
        }
        $readback = Read-NormalFilePinned -Path $item.FullName -IncludeText
        $records.Add([ordered]@{
            name = [string]$item.Name
            path = [string]$item.FullName
            identity = $readback.identity
            sha256 = [string]$readback.sha256
            fields = ConvertFrom-LeaseText -Text ([string]$readback.text)
            is_exclusive = [string]::Equals([string]$item.Name, 'EXCLUSIVE.lease', [System.StringComparison]::OrdinalIgnoreCase)
        })
    }
    return @($records)
}


function ConvertFrom-ExactLeaseOwnerFields {
    param([System.Collections.IDictionary]$Fields)
    $required = @(
        'schema', 'pid', 'owner_name', 'owner_start_utc', 'owner_start_ticks', 'owner_key',
        'owner_executable_path', 'owner_executable_sha256', 'owner_executable_native_key',
        'owner_executable_creation_ticks', 'worktree', 'candidate_commit', 'candidate_tree',
        'lease_nonce', 'started_utc'
    )
    if ($Fields.Count -ne $required.Count) { throw 'Lease metadata has missing or unexpected fields.' }
    foreach ($key in $required) {
        if (-not $Fields.Contains($key)) { throw "Lease metadata is missing exact field: $key" }
    }
    if ([string]$Fields['schema'] -cne 'rw06-q009-lease-v2') { throw 'Lease schema is not rw06-q009-lease-v2.' }
    $pidValue = 0
    $startTicks = [long]0
    $exeCreationTicks = [long]0
    $parsedStart = [datetime]::MinValue
    $parsedLeaseStart = [datetime]::MinValue
    if (
        -not [int]::TryParse([string]$Fields['pid'], [ref]$pidValue) `
        -or $pidValue -le 0 `
        -or -not [long]::TryParse([string]$Fields['owner_start_ticks'], [ref]$startTicks) `
        -or $startTicks -le 0 `
        -or -not [long]::TryParse([string]$Fields['owner_executable_creation_ticks'], [ref]$exeCreationTicks) `
        -or $exeCreationTicks -le 0 `
        -or -not [datetime]::TryParse([string]$Fields['owner_start_utc'], [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedStart) `
        -or -not [datetime]::TryParse([string]$Fields['started_utc'], [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedLeaseStart)
    ) { throw 'Lease metadata has malformed exact numeric/time identity.' }
    $name = [string]$Fields['owner_name']
    $key = [string]$Fields['owner_key']
    if ($key -cne ('{0}|{1}|{2}' -f $pidValue, $startTicks, $name) -or $parsedStart.ToUniversalTime().Ticks -ne $startTicks) {
        throw 'Lease owner PID/start/name/key identity is internally inconsistent.'
    }
    if (-not (Test-ExactHexIdentity -Value ([string]$Fields['owner_executable_sha256']) -Length 64)) {
        throw 'Lease owner executable SHA-256 is malformed.'
    }
    if (-not (Test-ExactHexIdentity -Value ([string]$Fields['candidate_commit']) -Length 40) -or -not (Test-ExactHexIdentity -Value ([string]$Fields['candidate_tree']) -Length 40)) {
        throw 'Lease candidate commit/tree identity is malformed.'
    }
    if ([string]$Fields['lease_nonce'] -cnotmatch '^[0-9a-f]{32}$') { throw 'Lease nonce is malformed.' }
    $executablePath = [System.IO.Path]::GetFullPath([string]$Fields['owner_executable_path'])
    $executableIdentity = [ordered]@{
        path = $executablePath
        native_key = [string]$Fields['owner_executable_native_key']
        is_directory = $false
        creation_ticks = $exeCreationTicks
        key = ('{0}|{1}|file' -f [string]$Fields['owner_executable_native_key'], $exeCreationTicks)
        reparse_point = $false
    }
    $identity = [ordered]@{
        pid = $pidValue
        name = $name
        start_utc = $parsedStart.ToUniversalTime().ToString('o')
        start_ticks = $startTicks
        key = $key
        executable_path = $executablePath
        executable_sha256 = ([string]$Fields['owner_executable_sha256']).ToUpperInvariant()
        executable_identity = $executableIdentity
    }
    if (-not (Test-ExactLeaseOwnerIdentityShape -Identity $identity)) { throw 'Lease owner exact identity shape is invalid.' }
    return $identity
}


function Clear-StaleGodotLeases {
    param([string]$Root = $leaseRoot, [switch]$AllowNonCanonicalForTest)
    if ($AllowNonCanonicalForTest -and -not $ValidateOnly) {
        throw 'Noncanonical lease-root cleanup is restricted to ValidateOnly hostiles.'
    }
    foreach ($record in @(Get-StrictLeaseEntryRecords -Root $Root -RequireCanonical:(-not $AllowNonCanonicalForTest))) {
        $ownerIdentity = ConvertFrom-ExactLeaseOwnerFields -Fields $record.fields
        $liveness = Get-ExactLeaseOwnerLiveness -ExpectedIdentity $ownerIdentity
        if ($liveness -ceq 'Live') { continue }
        if ($liveness -cne 'Dead') { throw 'Lease owner liveness was not positively classified.' }
        [void](Remove-ExactOwnedFile -Path ([string]$record.path) -ExpectedIdentity $record.identity -ExpectedSha256 ([string]$record.sha256))
    }
}


function Get-ProcessIdentityRecord {
    param([System.Diagnostics.Process]$Process)
    $startUtc = $Process.StartTime.ToUniversalTime()
    $executablePath = [System.IO.Path]::GetFullPath([string]$Process.MainModule.FileName)
    $guard = [System.IO.FileStream]::new($executablePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $readback = Read-NormalFilePinned -Path $executablePath
        return [ordered]@{
            pid = [int]$Process.Id
            name = [string]$Process.ProcessName
            start_utc = $startUtc.ToString('o')
            start_ticks = [long]$startUtc.Ticks
            key = ('{0}|{1}|{2}' -f $Process.Id, $startUtc.Ticks, $Process.ProcessName)
            executable_path = $executablePath
            executable_sha256 = [string]$readback.sha256
            executable_identity = $readback.identity
        }
    }
    finally {
        $guard.Dispose()
    }
}


function Test-LiveProcessMatchesIdentity {
    param([object]$ExpectedIdentity)
    if ($null -eq $ExpectedIdentity -or [int]$ExpectedIdentity.pid -le 0 -or [string]::IsNullOrWhiteSpace([string]$ExpectedIdentity.key)) {
        return $false
    }
    $live = Get-Process -Id ([int]$ExpectedIdentity.pid) -ErrorAction SilentlyContinue
    if ($null -eq $live) { return $false }
    try {
        $liveIdentity = Get-ProcessIdentityRecord -Process $live
        return [string]$liveIdentity.key -ceq [string]$ExpectedIdentity.key
    }
    catch {
        return $false
    }
}


function Test-ProcessIdentityProofShape {
    param([AllowNull()][object]$Identity)
    if ($null -eq $Identity) { return $false }
    try {
        $pidValue = [int]$Identity.pid
        $nameValue = [string]$Identity.name
        $startTicks = [long]$Identity.start_ticks
        $keyValue = [string]$Identity.key
        $parsedStart = [datetime]::MinValue
        if (
            $pidValue -le 0 `
            -or [string]::IsNullOrWhiteSpace($nameValue) `
            -or $startTicks -le 0 `
            -or [string]::IsNullOrWhiteSpace([string]$Identity.start_utc) `
            -or -not [datetime]::TryParse(
                [string]$Identity.start_utc,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$parsedStart
            )
        ) {
            return $false
        }
        $expectedKey = ('{0}|{1}|{2}' -f $pidValue, $startTicks, $nameValue)
        return (
            [long]$parsedStart.ToUniversalTime().Ticks -eq $startTicks `
            -and $keyValue -ceq $expectedKey
        )
    }
    catch {
        return $false
    }
}


function Test-ExactLeaseOwnerIdentityShape {
    param([AllowNull()][object]$Identity)
    if (-not (Test-ProcessIdentityProofShape -Identity $Identity)) { return $false }
    try {
        return (
            -not [string]::IsNullOrWhiteSpace([string]$Identity.executable_path) `
            -and (Test-ExactHexIdentity -Value ([string]$Identity.executable_sha256) -Length 64) `
            -and (Test-FileSystemEntryIdentityShape -Identity $Identity.executable_identity) `
            -and -not [bool]$Identity.executable_identity.is_directory `
            -and -not [bool]$Identity.executable_identity.reparse_point
        )
    }
    catch { return $false }
}


function Test-LiveProcessMatchesExactLeaseOwner {
    param([object]$ExpectedIdentity)
    return (Get-ExactLeaseOwnerLiveness -ExpectedIdentity $ExpectedIdentity) -ceq 'Live'
}


function Get-ExactLeaseOwnerLiveness {
    param([object]$ExpectedIdentity)
    if (-not (Test-ExactLeaseOwnerIdentityShape -Identity $ExpectedIdentity)) {
        throw 'Exact lease owner identity is malformed and therefore unverifiable.'
    }
    try {
        $live = [System.Diagnostics.Process]::GetProcessById([int]$ExpectedIdentity.pid)
    }
    catch [System.ArgumentException] {
        return 'Dead'
    }
    catch {
        throw "Exact lease owner PID query is unverifiable: $($_.Exception.Message)"
    }
    try {
        $actual = Get-ProcessIdentityRecord -Process $live
        if ([string]$actual.key -cne [string]$ExpectedIdentity.key) { return 'Dead' }
        if (
            [string]$actual.executable_path -cne [string]$ExpectedIdentity.executable_path `
            -or [string]$actual.executable_sha256 -cne [string]$ExpectedIdentity.executable_sha256 `
            -or -not (Test-FileSystemObjectsShareIdentity -Left $actual.executable_identity -Right $ExpectedIdentity.executable_identity)
        ) { throw 'Live lease owner PID/start/name matched but executable identity did not; preserving the lease as unverifiable.' }
        return 'Live'
    }
    catch {
        throw "Exact lease owner metadata verification is unverifiable: $($_.Exception.Message)"
    }
}


function Get-OwnedProcessStartProofFromException {
    param([System.Exception]$Exception)
    $missing = [ordered]@{
        started = $false
        process_id = 0
        process_identity = $null
        provenance = 'none'
        job_instance_id = ''
        job_suspended_create = $false
        job_assigned_before_resume = $false
        job_resumed_after_assign = $false
        job_kill_on_close = $false
        job_breakaway_disabled = $false
        job_initial_membership = @()
        job_cleanup_proven = $false
        job_members_before_cleanup = @()
        job_members_after_cleanup = @()
        executable_handle_opened = $false
        executable_identity_verified = $false
        executable_sha256_verified = $false
        executable_ancestor_chain_pinned = $false
        executable_held_through_create = $false
        mapped_image_path_verified = $false
        mapped_image_identity_verified = $false
        mapped_image_sha256_verified = $false
        executable_held_through_resume = $false
        executable_swap_probe_rejected = $false
    }
    if (
        $null -eq $Exception `
        -or -not $Exception.Data.Contains('owned_process_id') `
        -or -not $Exception.Data.Contains('owned_process_identity')
    ) {
        return $missing
    }
    $rawPid = $Exception.Data['owned_process_id']
    $identity = $Exception.Data['owned_process_identity']
    if (
        -not ($rawPid -is [int]) `
        -or -not (Test-ProcessIdentityProofShape -Identity $identity) `
        -or [int]$rawPid -ne [int]$identity.pid
    ) {
        return $missing
    }
    return [ordered]@{
        started = $true
        process_id = [int]$rawPid
        process_identity = $identity
        provenance = 'start_setup_exception'
        job_instance_id = if ($Exception.Data.Contains('owned_job_instance_id')) { [string]$Exception.Data['owned_job_instance_id'] } else { '' }
        job_suspended_create = ($Exception.Data.Contains('owned_job_suspended_create') -and [bool]$Exception.Data['owned_job_suspended_create'])
        job_assigned_before_resume = ($Exception.Data.Contains('owned_job_assigned_before_resume') -and [bool]$Exception.Data['owned_job_assigned_before_resume'])
        job_resumed_after_assign = ($Exception.Data.Contains('owned_job_resumed_after_assign') -and [bool]$Exception.Data['owned_job_resumed_after_assign'])
        job_kill_on_close = ($Exception.Data.Contains('owned_job_kill_on_close') -and [bool]$Exception.Data['owned_job_kill_on_close'])
        job_breakaway_disabled = ($Exception.Data.Contains('owned_job_breakaway_disabled') -and [bool]$Exception.Data['owned_job_breakaway_disabled'])
        job_initial_membership = if ($Exception.Data.Contains('owned_job_initial_membership')) { @($Exception.Data['owned_job_initial_membership']) } else { @() }
        job_cleanup_proven = ($Exception.Data.Contains('owned_job_cleanup_proven') -and [bool]$Exception.Data['owned_job_cleanup_proven'])
        job_members_before_cleanup = if ($Exception.Data.Contains('owned_job_members_before_cleanup')) { @($Exception.Data['owned_job_members_before_cleanup']) } else { @() }
        job_members_after_cleanup = if ($Exception.Data.Contains('owned_job_members_after_cleanup')) { @($Exception.Data['owned_job_members_after_cleanup']) } else { @() }
        executable_handle_opened = ($Exception.Data.Contains('owned_executable_handle_opened') -and [bool]$Exception.Data['owned_executable_handle_opened'])
        executable_identity_verified = ($Exception.Data.Contains('owned_executable_identity_verified') -and [bool]$Exception.Data['owned_executable_identity_verified'])
        executable_sha256_verified = ($Exception.Data.Contains('owned_executable_sha256_verified') -and [bool]$Exception.Data['owned_executable_sha256_verified'])
        executable_ancestor_chain_pinned = ($Exception.Data.Contains('owned_executable_ancestor_chain_pinned') -and [bool]$Exception.Data['owned_executable_ancestor_chain_pinned'])
        executable_held_through_create = ($Exception.Data.Contains('owned_executable_held_through_create') -and [bool]$Exception.Data['owned_executable_held_through_create'])
        mapped_image_path_verified = ($Exception.Data.Contains('owned_mapped_image_path_verified') -and [bool]$Exception.Data['owned_mapped_image_path_verified'])
        mapped_image_identity_verified = ($Exception.Data.Contains('owned_mapped_image_identity_verified') -and [bool]$Exception.Data['owned_mapped_image_identity_verified'])
        mapped_image_sha256_verified = ($Exception.Data.Contains('owned_mapped_image_sha256_verified') -and [bool]$Exception.Data['owned_mapped_image_sha256_verified'])
        executable_held_through_resume = ($Exception.Data.Contains('owned_executable_held_through_resume') -and [bool]$Exception.Data['owned_executable_held_through_resume'])
        executable_swap_probe_rejected = ($Exception.Data.Contains('owned_executable_swap_probe_rejected') -and [bool]$Exception.Data['owned_executable_swap_probe_rejected'])
    }
}


function Test-CimCreationMatchesProcessStartTicks {
    param(
        [long]$CreationTicks,
        [long]$ProcessStartTicks
    )
    if ($CreationTicks -le 0 -or $ProcessStartTicks -le 0) { return $false }
    # Win32_Process.CreationDate is microsecond-truncated, while
    # Process.StartTime retains 100 ns ticks. Compare the exact representable
    # CIM value instead of allowing a time window that PID reuse could cross.
    $cimRepresentableStartTicks = $ProcessStartTicks - ($ProcessStartTicks % 10)
    return $CreationTicks -eq $cimRepresentableStartTicks
}


# Snapshot/PID-tree inference and Stop-Process cleanup were removed. Native
# job membership and the retained job handle are the sole child authority.
function ConvertTo-WindowsCommandLineArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value.IndexOf([char]0) -ge 0 -or $Value.Contains("`r") -or $Value.Contains("`n")) {
        throw 'Native arguments may not contain NUL or newline characters.'
    }
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append([char]34)
    $backslashCount = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashCount += 1
            continue
        }
        if ($character -eq [char]34) {
            if ($backslashCount -gt 0) {
                [void]$builder.Append([char]92, $backslashCount * 2)
            }
            [void]$builder.Append([char]92)
            [void]$builder.Append([char]34)
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append([char]92, $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append([char]92, $backslashCount * 2)
    }
    [void]$builder.Append([char]34)
    return $builder.ToString()
}


function Join-ProcessArguments {
    param([string[]]$Arguments)
    return ((@($Arguments) | ForEach-Object { ConvertTo-WindowsCommandLineArgument -Value ([string]$_) }) -join ' ')
}


function Get-StrictNativeExitCode {
    param([object]$RawValue)
    if (-not ($RawValue -is [int])) {
        $typeName = if ($null -eq $RawValue) { 'null' } else { $RawValue.GetType().FullName }
        throw "Process exited without a System.Int32 native exit code (found $typeName)."
    }
    return [int]$RawValue
}


function New-OwnedCreationState {
    param([string]$Path, [string]$Nonce = '')
    return [ordered]@{
        path = if ([string]::IsNullOrWhiteSpace($Path)) { '' } else { [System.IO.Path]::GetFullPath($Path) }
        nonce = if ([string]::IsNullOrWhiteSpace($Nonce)) { [guid]::NewGuid().ToString('N') } else { $Nonce }
        absent_before_exclusive_creation = $false
        root_created_exclusively = $false
        root_creation_utc = ''
        root_identity_at_creation = $null
        root_identity_at_custody = $null
        root_custody_continuous = $false
        root_creation_replacement_probe_rejected = $false
        observed = $false
        creator_bound = $false
        creator_process_identity = $null
        creator_job_custody = $null
        creator_claim = $null
        captured_utc = ''
        entry_identity = $null
        claim_path = ''
        claim_identity = $null
        claim_sha256 = ''
        request_path = ''
        request_identity = $null
        request_sha256 = ''
        ack_path = ''
        ack_identity = $null
        ack_sha256 = ''
        handshake_acknowledged = $false
        root_identity_at_handshake = $null
        root_guard_owner = $null
        custody_transition = 'uncreated'
        custody_release_receipt = $null
        custody_release_count = 0
        quarantine_path = ''
        quarantine_identity = $null
        quarantine_rename_receipt = $null
        replacement_detected = $false
    }
}


function ConvertTo-DirectoryGuardCloseEvidence {
    param($CloseReceipt)
    if ($null -eq $CloseReceipt) { return $null }
    return [ordered]@{
        contract = [string]$CloseReceipt.Contract
        path = [string]$CloseReceipt.Path
        disposition = [string]$CloseReceipt.Disposition
        native_key = [string]$CloseReceipt.NativeKey
        creation_ticks = [long]$CloseReceipt.CreationTicks
        close_attempted = [bool]$CloseReceipt.CloseAttempted
        native_close_succeeded = [bool]$CloseReceipt.NativeCloseSucceeded
        reported_success = [bool]$CloseReceipt.ReportedSuccess
        win32_error = [int]$CloseReceipt.Win32Error
        forced_reported_failure = [bool]$CloseReceipt.ForcedReportedFailure
        closed_utc = [string]$CloseReceipt.ClosedUtc
    }
}


function Close-OwnedCacheGuardChecked {
    param(
        $State,
        [ValidateSet('deleted_closed', 'preserved_closed', 'test_closed')]
        [string]$Disposition,
        [switch]$ForceReportedFailureForTest
    )
    if ($null -eq $State -or $null -eq $State.root_guard_owner) {
        throw 'Checked cache-custody close requires one transferred native owner receipt.'
    }
    if ([int]$State.custody_release_count -ne 0 -or $null -ne $State.custody_release_receipt) {
        throw 'Checked cache-custody close rejected a double release or double transfer.'
    }
    $owner = $State.root_guard_owner
    try {
        $nativeClose = [Rw06FileIdentityNative]::CloseDirectoryGuardChecked(
            $owner,
            $Disposition,
            [bool]$ForceReportedFailureForTest
        )
        $State.custody_release_receipt = ConvertTo-DirectoryGuardCloseEvidence -CloseReceipt $nativeClose
        $State.custody_release_count = 1
        $State.custody_transition = $Disposition
        return $State.custody_release_receipt
    }
    catch {
        if ($null -ne $owner.CloseReceipt) {
            $State.custody_release_receipt = ConvertTo-DirectoryGuardCloseEvidence -CloseReceipt $owner.CloseReceipt
            $State.custody_release_count = 1
            if ([bool]$owner.NativeCloseSucceeded) {
                $State.custody_transition = $Disposition + '_reported_failure'
            }
            else {
                $State.custody_transition = $Disposition + '_native_failure'
            }
        }
        $_.Exception.Data['owned_creation_state'] = $State
        throw
    }
}


function Initialize-ExclusiveOwnedCacheRoot {
    param(
        $State,
        [switch]$ForceReplacementBeforeFirstCaptureForTest,
        [switch]$ForceHostFailureAfterOwnerTransferForTest,
        [switch]$ForceNativeFailureAfterHandleCreateForTest,
        [switch]$ForceNativeFailureCheckedCloseReportedFailureForTest
    )
    if ($null -eq $State -or [string]::IsNullOrWhiteSpace([string]$State.path)) {
        throw 'Exclusive cache-root creation requires a configured ownership state.'
    }
    $resolved = [System.IO.Path]::GetFullPath([string]$State.path)
    $parent = [System.IO.Path]::GetDirectoryName($resolved)
    [void](Assert-NormalDirectoryChain -Root $parent -DirectoryPath $parent)
    if (Test-Path -LiteralPath $resolved) {
        throw 'Exclusive cache-root creation requires an absent destination.'
    }
    $State.absent_before_exclusive_creation = $true
    Initialize-Rw06NativeFileIdentityType
    try {
        $created = [Rw06FileIdentityNative]::CreateDirectoryIdentityGuardExclusive(
            $resolved,
            [bool]$ForceReplacementBeforeFirstCaptureForTest,
            [bool]$ForceNativeFailureAfterHandleCreateForTest,
            [bool]$ForceNativeFailureCheckedCloseReportedFailureForTest
        )
        $State.root_guard_owner = $created
        try {
            if ($ForceHostFailureAfterOwnerTransferForTest) {
                throw 'Forced host failure after the native cache-root owner transferred into state.'
            }
            $creationIdentity = [ordered]@{
                path = $resolved
                native_key = [string]$created.CreationNativeKey
                is_directory = $true
                creation_ticks = [long]$created.CreationTicks
                reparse_point = $false
                key = ('{0}|{1}|directory' -f [string]$created.CreationNativeKey, [long]$created.CreationTicks)
            }
            $custodyIdentity = [ordered]@{
                path = $resolved
                native_key = [string]$created.CustodyNativeKey
                is_directory = $true
                creation_ticks = [long]$created.CustodyCreationTicks
                reparse_point = $false
                key = ('{0}|{1}|directory' -f [string]$created.CustodyNativeKey, [long]$created.CustodyCreationTicks)
            }
            $State.root_created_exclusively = [bool]$created.CreatedExclusive
            $State.root_creation_utc = [DateTime]::UtcNow.ToString('o')
            $State.root_identity_at_creation = $creationIdentity
            $State.root_identity_at_custody = $custodyIdentity
            $State.root_custody_continuous = (
                [bool]$created.GuardLive `
                -and (Test-FileSystemObjectsShareIdentity -Left $creationIdentity -Right $custodyIdentity)
            )
            $State.root_creation_replacement_probe_rejected = [bool]$created.ReplacementProbeRejected
            $State.custody_transition = 'host_owned'
            [void]([Rw06FileIdentityNative]::AssertDirectoryGuardIdentity(
                $created,
                [string]$creationIdentity.native_key,
                [long]$creationIdentity.creation_ticks,
                $resolved
            ))
            if (
                -not [bool]$State.root_created_exclusively `
                -or -not [bool]$State.root_custody_continuous `
                -or -not [bool]$created.GuardLive `
                -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $creationIdentity) `
                -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $custodyIdentity)
            ) {
                throw 'Atomic cache-root creation did not retain its one exact native directory handle.'
            }
            if ($ForceReplacementBeforeFirstCaptureForTest -and -not [bool]$State.root_creation_replacement_probe_rejected) {
                throw 'Atomic cache-root guard did not reject replacement before first host capture.'
            }
            return $State
        }
        catch {
            $_.Exception.Data['owned_creation_state'] = $State
            throw
        }
    }
    catch {
        if ($null -eq $State.root_guard_owner -and $_.Exception.Data.Contains('directory_guard_owner')) {
            $State.root_guard_owner = $_.Exception.Data['directory_guard_owner']
        }
        if ($null -ne $State.root_guard_owner -and $null -ne $State.root_guard_owner.CloseReceipt) {
            $State.custody_release_receipt = ConvertTo-DirectoryGuardCloseEvidence -CloseReceipt $State.root_guard_owner.CloseReceipt
            $State.custody_release_count = 1
            $State.custody_transition = if ([bool]$State.root_guard_owner.NativeCloseSucceeded) { 'native_create_failure_closed' } else { 'native_create_failure_close_failed' }
        }
        $_.Exception.Data['owned_creation_state'] = $State
        throw
    }
}


function Update-OwnedCreationState {
    param(
        $State,
        $RootProcessIdentity,
        [datetime]$RootExitTimeUtc = [datetime]::MinValue
    )
    throw 'Temporal process-lifetime cache adoption is forbidden; use a creator-process-written claim.'
}


function Complete-OwnedCacheCreationHandshake {
    param(
        $State,
        $Started,
        [string]$ExpectedCommit,
        [string]$ExpectedTree,
        [int]$TimeoutSec = 15
    )
    if (
        $null -eq $State `
        -or -not [bool]$State.absent_before_exclusive_creation `
        -or -not [bool]$State.root_created_exclusively `
        -or -not [bool]$State.root_custody_continuous `
        -or -not (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_creation) `
        -or -not (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_custody) `
        -or $null -eq $State.root_guard_owner `
        -or -not [bool]$State.root_guard_owner.GuardLive `
        -or [string]$State.custody_transition -cne 'host_owned' `
        -or $null -eq $Started
    ) {
        throw 'Cache-creator handshake requires an atomically created pinned root and a live exact job.'
    }
    [void]([Rw06FileIdentityNative]::AssertDirectoryGuardIdentity(
        $State.root_guard_owner,
        [string]$State.root_identity_at_creation.native_key,
        [long]$State.root_identity_at_creation.creation_ticks,
        [string]$State.path
    ))
    $requestPath = Join-Path ([string]$State.path) '.rw06_6-cache-request.json'
    $ackPath = Join-Path ([string]$State.path) '.rw06_6-cache-ack.json'
    $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Max(1, $TimeoutSec))
    while (-not (Test-Path -LiteralPath $requestPath -PathType Leaf) -and [DateTime]::UtcNow -lt $deadline) {
        if (@($Started.native_job.GetActiveProcessIds()).Count -eq 0) { break }
        Start-Sleep -Milliseconds 10
    }
    if (-not (Test-Path -LiteralPath $requestPath -PathType Leaf)) {
        throw 'Exclusive cache creator did not publish its handshake request while job-bound.'
    }
    if (@($Started.native_job.GetActiveProcessIds()) -notcontains [int]$Started.process_id) {
        throw 'Cache creator exited before its directory identity could be acknowledged.'
    }
    $rootIdentity = Get-FileSystemEntryIdentity -Path ([string]$State.path)
    if (-not [bool]$rootIdentity.is_directory -or [bool]$rootIdentity.reparse_point) { throw 'Cache creator produced a non-normal cache root.' }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $rootIdentity -Right $State.root_identity_at_creation)) {
        throw 'Cache root changed between exclusive native creation and the live creator handshake.'
    }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $rootIdentity -Right $State.root_identity_at_custody)) {
        throw 'Cache root changed between continuous custody acquisition and the live creator handshake.'
    }
    $rootCreatedUtc = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$State.root_creation_utc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$rootCreatedUtc)) {
        throw 'Exclusive cache-root creation timestamp is malformed.'
    }
    $processStartUtc = [datetime]::new([long]$Started.process_identity.start_ticks, [DateTimeKind]::Utc)
    if ($rootCreatedUtc.ToUniversalTime() -lt $processStartUtc.AddSeconds(-5) -or $rootCreatedUtc.ToUniversalTime() -gt $processStartUtc.AddSeconds(1)) {
        throw 'Exclusive cache root was not handed directly to the exact creator process.'
    }
    $State.root_identity_at_handshake = $rootIdentity
    $requestReadback = Read-NormalFilePinned -Path $requestPath -IncludeText
    try { $request = [string]$requestReadback.text | ConvertFrom-Json }
    catch { throw 'Cache creator request is invalid JSON.' }
    $requestProperties = @($request.PSObject.Properties.Name | Sort-Object)
    $expectedRequestProperties = @('cache_path', 'candidate_commit', 'candidate_tree', 'contract', 'created_utc', 'creator_pid', 'nonce') | Sort-Object
    if ($requestProperties.Count -ne $expectedRequestProperties.Count) { throw 'Cache creator request field set is not exact.' }
    for ($index = 0; $index -lt $expectedRequestProperties.Count; $index += 1) {
        if ([string]$requestProperties[$index] -cne [string]$expectedRequestProperties[$index]) { throw 'Cache creator request field set changed.' }
    }
    $requestPid = 0
    $requestCreatedUtc = [datetime]::MinValue
    if (
        [string]$request.contract -cne 'rw06_6_cache_owner_request_v2' `
        -or [string]$request.nonce -cne [string]$State.nonce `
        -or -not [int]::TryParse([string]$request.creator_pid, [ref]$requestPid) `
        -or $requestPid -ne [int]$Started.process_id `
        -or [string]$request.candidate_commit -cne $ExpectedCommit `
        -or [string]$request.candidate_tree -cne $ExpectedTree `
        -or [System.IO.Path]::GetFullPath([string]$request.cache_path) -cne [string]$State.path `
        -or -not [datetime]::TryParse([string]$request.created_utc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$requestCreatedUtc) `
        -or $requestCreatedUtc.ToUniversalTime().Ticks -lt [long]$Started.process_identity.start_ticks `
        -or $requestCreatedUtc.ToUniversalTime() -gt [DateTime]::UtcNow.AddMinutes(1)
    ) { throw 'Cache creator request does not bind its exact live PID/nonce/candidate/path/time.' }
    if (Test-Path -LiteralPath $ackPath) { throw 'Cache handshake acknowledgment path was not fresh.' }
    $ack = [ordered]@{
        contract = 'rw06_6_cache_owner_ack_v2'
        nonce = [string]$State.nonce
        creator_pid = [int]$Started.process_id
        candidate_commit = $ExpectedCommit
        candidate_tree = $ExpectedTree
        cache_path = [string]$State.path
        cache_native_key = [string]$rootIdentity.native_key
        cache_creation_ticks = [string][long]$rootIdentity.creation_ticks
        creator_job_instance_id = [string]$Started.job_custody.job_instance_id
        request_sha256 = [string]$requestReadback.sha256
        acknowledged_utc = [DateTime]::UtcNow.ToString('o')
    }
    $ackBytes = [System.Text.UTF8Encoding]::new($false).GetBytes((($ack | ConvertTo-Json -Depth 5 -Compress) + "`n"))
    $ackStream = [System.IO.FileStream]::new($ackPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    try { $ackStream.Write($ackBytes, 0, $ackBytes.Length); $ackStream.Flush($true) }
    finally { $ackStream.Dispose() }
    $ackReadback = Read-NormalFilePinned -Path $ackPath -IncludeText
    $State.request_path = $requestPath
    $State.request_identity = $requestReadback.identity
    $State.request_sha256 = [string]$requestReadback.sha256
    $State.ack_path = $ackPath
    $State.ack_identity = $ackReadback.identity
    $State.ack_sha256 = [string]$ackReadback.sha256
    $State.handshake_acknowledged = $true
    $State.custody_transition = 'handshake_acknowledged'
    return $State
}


function Bind-OwnedCreationStateFromCreatorClaim {
    param(
        $State,
        [object]$CreatorProcessIdentity,
        $CreatorJobCustody,
        [string]$ExpectedCommit,
        [string]$ExpectedTree
    )
    if ($null -eq $State -or -not [bool]$State.absent_before_exclusive_creation -or -not [bool]$State.root_created_exclusively -or -not [bool]$State.handshake_acknowledged -or $null -eq $State.root_guard_owner -or -not [bool]$State.root_guard_owner.GuardLive -or [string]$State.custody_transition -cne 'handshake_acknowledged' -or [string]$State.nonce -cnotmatch '^[0-9a-f]{32}$') {
        throw 'Creator-bound cache state is absent, malformed, or lacked exclusive native creation.'
    }
    if (
        -not (Test-ExactLeaseOwnerIdentityShape -Identity $CreatorProcessIdentity) `
        -or [string]$CreatorProcessIdentity.name -notin @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64') `
        -or [string]$CreatorProcessIdentity.executable_path -cne $canonicalGodotPath `
        -or [string]$CreatorProcessIdentity.executable_sha256 -cne $canonicalGodotSha256 `
        -or -not (Test-NativeJobCustodyReceipt -Receipt $CreatorJobCustody -RootIdentity $CreatorProcessIdentity)
    ) { throw 'Cache creator is not the exact canonical job-bound Godot process.' }
    if (-not (Test-Path -LiteralPath ([string]$State.path) -PathType Container)) { throw 'Creator process did not produce the dedicated cache directory.' }
    $cacheIdentity = Get-FileSystemEntryIdentity -Path ([string]$State.path)
    if (-not (Test-FileSystemObjectsShareIdentity -Left $cacheIdentity -Right $State.root_identity_at_handshake)) {
        throw 'Cache root identity changed after the live creator handshake.'
    }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $cacheIdentity -Right $State.root_identity_at_creation)) {
        throw 'Cache root identity changed after exclusive native creation.'
    }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $cacheIdentity -Right $State.root_identity_at_custody)) {
        throw 'Cache root identity changed after continuous custody acquisition.'
    }
    foreach ($handshakeFile in @(
        [ordered]@{ path = [string]$State.request_path; identity = $State.request_identity; sha256 = [string]$State.request_sha256; label = 'request' },
        [ordered]@{ path = [string]$State.ack_path; identity = $State.ack_identity; sha256 = [string]$State.ack_sha256; label = 'acknowledgment' }
    )) {
        $handshakeReadback = Read-NormalFilePinned -Path ([string]$handshakeFile.path) -ExpectedIdentity $handshakeFile.identity
        if ([string]$handshakeReadback.sha256 -cne [string]$handshakeFile.sha256) { throw "Cache handshake $([string]$handshakeFile.label) bytes changed." }
    }
    $claimPath = Join-Path ([string]$State.path) '.rw06_6-cache-owner.json'
    if (-not (Test-Path -LiteralPath $claimPath -PathType Leaf)) { throw 'Creator process did not produce its cache ownership claim.' }
    $claimReadback = Read-NormalFilePinned -Path $claimPath -IncludeText
    try { $claim = [string]$claimReadback.text | ConvertFrom-Json }
    catch { throw 'Creator-process cache claim is invalid JSON.' }
    $propertyNames = @($claim.PSObject.Properties.Name | Sort-Object)
    $expectedProperties = @('ack_sha256', 'cache_creation_ticks', 'cache_native_key', 'cache_path', 'candidate_commit', 'candidate_tree', 'contract', 'created_utc', 'creator_job_instance_id', 'creator_pid', 'nonce', 'request_sha256') | Sort-Object
    if ($propertyNames.Count -ne $expectedProperties.Count) { throw 'Creator-process cache claim has missing or unexpected fields.' }
    for ($index = 0; $index -lt $expectedProperties.Count; $index += 1) {
        if ([string]$propertyNames[$index] -cne [string]$expectedProperties[$index]) { throw 'Creator-process cache claim field set is not exact.' }
    }
    $claimPid = 0
    $createdUtc = [datetime]::MinValue
    if (
        -not [int]::TryParse([string]$claim.creator_pid, [ref]$claimPid) `
        -or $claimPid -ne [int]$CreatorProcessIdentity.pid `
        -or [string]$claim.contract -cne 'rw06_6_cache_owner_v2' `
        -or [string]$claim.nonce -cne [string]$State.nonce `
        -or [string]$claim.candidate_commit -cne $ExpectedCommit `
        -or [string]$claim.candidate_tree -cne $ExpectedTree `
        -or [System.IO.Path]::GetFullPath([string]$claim.cache_path) -cne [string]$State.path `
        -or [string]$claim.cache_native_key -cne [string]$State.root_identity_at_handshake.native_key `
        -or [string]$claim.cache_creation_ticks -cne [string][long]$State.root_identity_at_handshake.creation_ticks `
        -or [string]$claim.creator_job_instance_id -cne [string]$CreatorJobCustody.job_instance_id `
        -or [string]$claim.request_sha256 -cne [string]$State.request_sha256 `
        -or [string]$claim.ack_sha256 -cne [string]$State.ack_sha256 `
        -or -not [datetime]::TryParse([string]$claim.created_utc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$createdUtc) `
        -or $createdUtc.ToUniversalTime().Ticks -lt [long]$CreatorProcessIdentity.start_ticks `
        -or $createdUtc.ToUniversalTime() -gt [DateTime]::UtcNow.AddMinutes(1)
    ) { throw 'Creator-process cache claim does not bind its nonce/PID/candidate/path/time exactly.' }
    $State.observed = $true
    $State.creator_bound = $true
    $State.creator_process_identity = $CreatorProcessIdentity
    $State.creator_job_custody = $CreatorJobCustody
    $State.creator_claim = [ordered]@{
        contract = [string]$claim.contract
        nonce = [string]$claim.nonce
        creator_pid = $claimPid
        candidate_commit = [string]$claim.candidate_commit
        candidate_tree = [string]$claim.candidate_tree
        cache_path = [System.IO.Path]::GetFullPath([string]$claim.cache_path)
        cache_native_key = [string]$claim.cache_native_key
        cache_creation_ticks = [string]$claim.cache_creation_ticks
        creator_job_instance_id = [string]$claim.creator_job_instance_id
        request_sha256 = [string]$claim.request_sha256
        ack_sha256 = [string]$claim.ack_sha256
        created_utc = $createdUtc.ToUniversalTime().ToString('o')
    }
    $State.captured_utc = [DateTime]::UtcNow.ToString('o')
    $State.entry_identity = $cacheIdentity
    $State.claim_path = $claimPath
    $State.claim_identity = $claimReadback.identity
    $State.claim_sha256 = [string]$claimReadback.sha256
    $State.custody_transition = 'creator_bound'
    return $State
}


function Assert-OwnedCreationStateStable {
    param($State)
    if (-not (Test-OwnedCreationStateProof -State $State)) { throw 'Creator-bound cache proof is absent or malformed.' }
    [void]([Rw06FileIdentityNative]::AssertDirectoryGuardIdentity(
        $State.root_guard_owner,
        [string]$State.entry_identity.native_key,
        [long]$State.entry_identity.creation_ticks,
        [string]$State.path
    ))
    if (
        -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.entry_identity) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.root_identity_at_creation) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.root_identity_at_custody) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.root_identity_at_handshake) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.request_identity) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.ack_identity) `
        -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $State.claim_identity)
    ) {
        $State.replacement_detected = $true
        throw 'Creator-bound cache directory, handshake, or claim identity was replaced.'
    }
    foreach ($sealedFile in @(
        [ordered]@{ path = [string]$State.request_path; identity = $State.request_identity; sha256 = [string]$State.request_sha256 },
        [ordered]@{ path = [string]$State.ack_path; identity = $State.ack_identity; sha256 = [string]$State.ack_sha256 },
        [ordered]@{ path = [string]$State.claim_path; identity = $State.claim_identity; sha256 = [string]$State.claim_sha256 }
    )) {
        $readback = Read-NormalFilePinned -Path ([string]$sealedFile.path) -ExpectedIdentity $sealedFile.identity
        if ([string]$readback.sha256 -cne [string]$sealedFile.sha256) {
            $State.replacement_detected = $true
            throw 'Creator-bound cache handshake/claim bytes changed.'
        }
    }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $State.root_identity_at_handshake)) {
        $State.replacement_detected = $true
        throw 'Creator-bound cache root no longer matches its live handshake identity.'
    }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $State.root_identity_at_creation)) {
        $State.replacement_detected = $true
        throw 'Creator-bound cache root no longer matches its exclusive native creation identity.'
    }
    if (-not (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $State.root_identity_at_custody)) {
        $State.replacement_detected = $true
        throw 'Creator-bound cache root no longer matches its continuous-custody identity.'
    }
    return $true
}


function Test-OwnedCreationStateProof {
    param($State)
    if ($null -eq $State) { return $false }
    return (
        [bool]$State.absent_before_exclusive_creation `
        -and [bool]$State.root_created_exclusively `
        -and [bool]$State.root_custody_continuous `
        -and [bool]$State.observed `
        -and [bool]$State.creator_bound `
        -and [bool]$State.handshake_acknowledged `
        -and -not [bool]$State.replacement_detected `
        -and (Test-ExactLeaseOwnerIdentityShape -Identity $State.creator_process_identity) `
        -and (Test-NativeJobCustodyReceipt -Receipt $State.creator_job_custody -RootIdentity $State.creator_process_identity) `
        -and $null -ne $State.creator_claim `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.entry_identity) `
        -and [bool]$State.entry_identity.is_directory `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_creation) `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_custody) `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_handshake) `
        -and (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $State.root_identity_at_creation) `
        -and (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $State.root_identity_at_custody) `
        -and (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $State.root_identity_at_handshake) `
        -and $null -ne $State.root_guard_owner `
        -and [bool]$State.root_guard_owner.GuardLive `
        -and [string]$State.custody_transition -ceq 'creator_bound' `
        -and [int]$State.custody_release_count -eq 0 `
        -and $null -eq $State.custody_release_receipt `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.request_identity) `
        -and (Test-ExactHexIdentity -Value ([string]$State.request_sha256) -Length 64) `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.ack_identity) `
        -and (Test-ExactHexIdentity -Value ([string]$State.ack_sha256) -Length 64) `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.claim_identity) `
        -and -not [bool]$State.claim_identity.is_directory `
        -and (Test-ExactHexIdentity -Value ([string]$State.claim_sha256) -Length 64)
    )
}


function Get-OwnedCreationEvidenceSummary {
    param($State)
    if ($null -eq $State -or [string]::IsNullOrWhiteSpace([string]$State.path)) { return $null }
    $creationCustodyMatch = (
        (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_creation) `
        -and (Test-FileSystemEntryIdentityShape -Identity $State.root_identity_at_custody) `
        -and (Test-FileSystemObjectsShareIdentity -Left $State.root_identity_at_creation -Right $State.root_identity_at_custody)
    )
    $guardLive = ($null -ne $State.root_guard_owner -and [bool]$State.root_guard_owner.GuardLive)
    return [ordered]@{
        contract = 'rw06_6_cache_creation_custody_v1'
        path = [string]$State.path
        nonce = [string]$State.nonce
        absent_before_exclusive_creation = [bool]$State.absent_before_exclusive_creation
        root_created_exclusively = [bool]$State.root_created_exclusively
        root_creation_utc = [string]$State.root_creation_utc
        atomic_creation_handle_identity = $State.root_identity_at_creation
        continuous_custody_handle_identity = $State.root_identity_at_custody
        single_creation_custody_handle = $true
        creation_custody_identity_match = [bool]$creationCustodyMatch
        continuous_custody_established = [bool]$State.root_custody_continuous
        custody_guard_live_at_capture = [bool]$guardLive
        custody_transition = [string]$State.custody_transition
        custody_release_receipt = $State.custody_release_receipt
        custody_release_count = [int]$State.custody_release_count
        quarantine_path = [string]$State.quarantine_path
        quarantine_identity = $State.quarantine_identity
        quarantine_rename_receipt = $State.quarantine_rename_receipt
        replacement_probe_rejected = [bool]$State.root_creation_replacement_probe_rejected
        handshake_acknowledged = [bool]$State.handshake_acknowledged
        root_handshake_identity = $State.root_identity_at_handshake
        creator_bound = [bool]$State.creator_bound
        creator_claim_captured_utc = [string]$State.captured_utc
        bound_entry_identity = $State.entry_identity
        creator_process_identity = $State.creator_process_identity
        creator_job_custody = $State.creator_job_custody
        creator_claim = $State.creator_claim
        request_receipt = [ordered]@{
            identity = $State.request_identity
            sha256 = [string]$State.request_sha256
        }
        acknowledgment_receipt = [ordered]@{
            identity = $State.ack_identity
            sha256 = [string]$State.ack_sha256
        }
        claim_receipt = [ordered]@{
            identity = $State.claim_identity
            sha256 = [string]$State.claim_sha256
        }
        exact_proof_valid_at_capture = [bool](Test-OwnedCreationStateProof -State $State)
    }
}


function New-ValidateOnlySyntheticOwnedCacheState {
    param([string]$Path, [switch]$ForceReplacementBeforeFirstCaptureForTest)
    if (-not $ValidateOnly) { throw 'Synthetic cache ownership is restricted to ValidateOnly.' }
    $state = New-OwnedCreationState -Path $Path
    if (Test-Path -LiteralPath $Path) { throw 'Synthetic cache fixture path must be absent.' }
    $state = Initialize-ExclusiveOwnedCacheRoot -State $state -ForceReplacementBeforeFirstCaptureForTest:$ForceReplacementBeforeFirstCaptureForTest
    $creatorStart = [DateTime]::UtcNow
    $creatorPid = 424242
    $creatorName = 'Godot_v4.6-stable_win64_console'
    $creatorIdentity = [ordered]@{
        pid = $creatorPid
        name = $creatorName
        start_utc = $creatorStart.ToString('o')
        start_ticks = [long]$creatorStart.Ticks
        key = ('{0}|{1}|{2}' -f $creatorPid, $creatorStart.Ticks, $creatorName)
        executable_path = $canonicalGodotPath
        executable_sha256 = $canonicalGodotSha256
        executable_identity = Get-FileSystemEntryIdentity -Path $canonicalGodotPath
    }
    $jobCustody = [ordered]@{
        job_instance_id = [guid]::NewGuid().ToString('N')
        suspended_create = $true
        assigned_before_resume = $true
        resumed_after_assign = $true
        kill_on_job_close = $true
        breakaway_disabled = $true
        initial_membership = @($creatorPid)
        executable_handle_opened = $true
        executable_identity_verified = $true
        executable_sha256_verified = $true
        executable_ancestor_chain_pinned = $true
        executable_held_through_create = $true
        mapped_image_path = $canonicalGodotPath
        mapped_image_native_key = [string]$creatorIdentity.executable_identity.native_key
        mapped_image_creation_ticks = [long]$creatorIdentity.executable_identity.creation_ticks
        mapped_image_sha256 = $canonicalGodotSha256
        mapped_image_path_verified = $true
        mapped_image_identity_verified = $true
        mapped_image_sha256_verified = $true
        executable_held_through_resume = $true
        executable_swap_probe_rejected = $false
    }
    $state.entry_identity = Get-FileSystemEntryIdentity -Path $Path
    $state.root_identity_at_handshake = $state.entry_identity
    $requestPath = Join-Path $Path '.rw06_6-cache-request.json'
    [System.IO.File]::WriteAllText($requestPath, "{`"synthetic`":true}`n", [System.Text.UTF8Encoding]::new($false))
    $requestReadback = Read-NormalFilePinned -Path $requestPath
    $ackPath = Join-Path $Path '.rw06_6-cache-ack.json'
    [System.IO.File]::WriteAllText($ackPath, "{`"synthetic`":true}`n", [System.Text.UTF8Encoding]::new($false))
    $ackReadback = Read-NormalFilePinned -Path $ackPath
    $claimPath = Join-Path $Path '.rw06_6-cache-owner.json'
    $claim = [ordered]@{
        contract = 'rw06_6_cache_owner_v2'
        nonce = [string]$state.nonce
        creator_pid = $creatorPid
        candidate_commit = ('1' * 40)
        candidate_tree = ('2' * 40)
        cache_path = [System.IO.Path]::GetFullPath($Path)
        cache_native_key = [string]$state.entry_identity.native_key
        cache_creation_ticks = [string][long]$state.entry_identity.creation_ticks
        creator_job_instance_id = [string]$jobCustody.job_instance_id
        request_sha256 = [string]$requestReadback.sha256
        ack_sha256 = [string]$ackReadback.sha256
        created_utc = [DateTime]::UtcNow.ToString('o')
    }
    [System.IO.File]::WriteAllText($claimPath, (($claim | ConvertTo-Json -Compress) + "`n"), [System.Text.UTF8Encoding]::new($false))
    $state.observed = $true
    $state.creator_bound = $true
    $state.handshake_acknowledged = $true
    $state.creator_process_identity = $creatorIdentity
    $state.creator_job_custody = $jobCustody
    $state.creator_claim = $claim
    $state.captured_utc = [DateTime]::UtcNow.ToString('o')
    $state.request_path = $requestPath
    $state.request_identity = $requestReadback.identity
    $state.request_sha256 = [string]$requestReadback.sha256
    $state.ack_path = $ackPath
    $state.ack_identity = $ackReadback.identity
    $state.ack_sha256 = [string]$ackReadback.sha256
    $state.claim_path = $claimPath
    $claimReadback = Read-NormalFilePinned -Path $claimPath
    $state.claim_identity = $claimReadback.identity
    $state.claim_sha256 = [string]$claimReadback.sha256
    $state.custody_transition = 'creator_bound'
    return $state
}


# The obsolete ProcessStartInfo/PID-snapshot runner was removed. The native
# suspended-create job implementation below is the sole process authority.
function New-NativeOwnedProcessIdentity {
    param($NativeJob)
    $startUtc = [datetime]::new([long]$NativeJob.StartUtcTicks, [DateTimeKind]::Utc)
    $executableIdentity = [ordered]@{
        path = [string]$NativeJob.ExecutablePath
        native_key = [string]$NativeJob.ExecutableNativeKey
        is_directory = $false
        creation_ticks = [long]$NativeJob.ExecutableCreationTicks
        reparse_point = $false
        key = ('{0}|{1}|file' -f [string]$NativeJob.ExecutableNativeKey, [long]$NativeJob.ExecutableCreationTicks)
    }
    return [ordered]@{
        pid = [int]$NativeJob.ProcessId
        name = [string]$NativeJob.ProcessName
        start_utc = $startUtc.ToString('o')
        start_ticks = [long]$NativeJob.StartUtcTicks
        key = ('{0}|{1}|{2}' -f [int]$NativeJob.ProcessId, [long]$NativeJob.StartUtcTicks, [string]$NativeJob.ProcessName)
        executable_path = [string]$NativeJob.ExecutablePath
        executable_sha256 = [string]$NativeJob.ExecutableSha256
        executable_identity = $executableIdentity
    }
}


function Get-NativeJobCustodyReceipt {
    param($NativeJob)
    return [ordered]@{
        job_instance_id = [string]$NativeJob.JobInstanceId
        suspended_create = [bool]$NativeJob.SuspendedCreate
        assigned_before_resume = [bool]$NativeJob.AssignedBeforeResume
        resumed_after_assign = [bool]$NativeJob.ResumedAfterAssign
        kill_on_job_close = [bool]$NativeJob.KillOnJobClose
        breakaway_disabled = [bool]$NativeJob.BreakawayDisabled
        initial_membership = @($NativeJob.InitialMembership | ForEach-Object { [int]$_ })
        executable_handle_opened = [bool]$NativeJob.ExecutableHandleOpened
        executable_identity_verified = [bool]$NativeJob.ExecutableIdentityVerified
        executable_sha256_verified = [bool]$NativeJob.ExecutableSha256Verified
        executable_ancestor_chain_pinned = [bool]$NativeJob.ExecutableAncestorChainPinned
        executable_held_through_create = [bool]$NativeJob.ExecutableHeldThroughCreate
        mapped_image_path = [string]$NativeJob.MappedImagePath
        mapped_image_native_key = [string]$NativeJob.MappedImageNativeKey
        mapped_image_creation_ticks = [long]$NativeJob.MappedImageCreationTicks
        mapped_image_sha256 = [string]$NativeJob.MappedImageSha256
        mapped_image_path_verified = [bool]$NativeJob.MappedImagePathVerified
        mapped_image_identity_verified = [bool]$NativeJob.MappedImageIdentityVerified
        mapped_image_sha256_verified = [bool]$NativeJob.MappedImageSha256Verified
        executable_held_through_resume = [bool]$NativeJob.ExecutableHeldThroughResume
        executable_swap_probe_rejected = [bool]$NativeJob.ExecutableSwapProbeRejected
    }
}


function Test-NativeJobCustodyReceipt {
    param($Receipt, [object]$RootIdentity)
    if ($null -eq $Receipt -or -not (Test-ProcessIdentityProofShape -Identity $RootIdentity)) { return $false }
    return (
        [string]$Receipt.job_instance_id -cmatch '^[0-9a-f]{32}$' `
        -and [bool]$Receipt.suspended_create `
        -and [bool]$Receipt.assigned_before_resume `
        -and [bool]$Receipt.resumed_after_assign `
        -and [bool]$Receipt.kill_on_job_close `
        -and [bool]$Receipt.breakaway_disabled `
        -and [bool]$Receipt.executable_handle_opened `
        -and [bool]$Receipt.executable_identity_verified `
        -and [bool]$Receipt.executable_sha256_verified `
        -and [bool]$Receipt.executable_ancestor_chain_pinned `
        -and [bool]$Receipt.executable_held_through_create `
        -and [bool]$Receipt.mapped_image_path_verified `
        -and [bool]$Receipt.mapped_image_identity_verified `
        -and [bool]$Receipt.mapped_image_sha256_verified `
        -and [bool]$Receipt.executable_held_through_resume `
        -and [string]::Equals([string]$Receipt.mapped_image_path, [string]$RootIdentity.executable_path, [System.StringComparison]::OrdinalIgnoreCase) `
        -and [string]$Receipt.mapped_image_native_key -ceq [string]$RootIdentity.executable_identity.native_key `
        -and [long]$Receipt.mapped_image_creation_ticks -eq [long]$RootIdentity.executable_identity.creation_ticks `
        -and [string]$Receipt.mapped_image_sha256 -ceq [string]$RootIdentity.executable_sha256 `
        -and @($Receipt.initial_membership).Count -eq 1 `
        -and [int]$Receipt.initial_membership[0] -eq [int]$RootIdentity.pid
    )
}


function Add-LiveNativeJobMemberIdentities {
    param($NativeJob, [object]$RootIdentity, [System.Collections.Generic.List[object]]$RetainedRecords)
    if ($null -eq $NativeJob -or $null -eq $RetainedRecords) { return }
    $known = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($record in @($RetainedRecords)) { [void]$known.Add([string]$record.key) }
    foreach ($memberPid in @($NativeJob.GetActiveProcessIds())) {
        if ([int]$memberPid -eq [int]$RootIdentity.pid) { continue }
        $process = Get-Process -Id ([int]$memberPid) -ErrorAction SilentlyContinue
        if ($null -eq $process) { continue }
        try {
            $identity = Get-ProcessIdentityRecord -Process $process
            if ($known.Add([string]$identity.key)) { [void]$RetainedRecords.Add($identity) }
        }
        catch {
            # Exact job membership remains authoritative if a descriptive read races exit.
        }
    }
}


# The native owner creates the root suspended, assigns it to a KILL_ON_JOB_CLOSE
# job with breakaway disabled, captures handle-derived identity, then resumes it.
function Start-RedirectedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath,
        [ValidateSet('Godot', 'Exact')]
        [string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @(),
        [int]$TimeoutSec,
        [string]$OwnedCreationPath = '',
        $OwnedCreationState = $null,
        $ExpectedExecutableReceipt = $null,
        $StdoutReceipt = $null,
        $StderrReceipt = $null,
        [switch]$ForceExecutableSwapProbeForTest,
        [switch]$ForceSecondPumpFailureForTest,
        [switch]$ForceNativeFailureAfterAssignBeforeResumeForTest,
        [switch]$ForceWrapperFailureAfterNativeReturnForTest,
        [int]$ForceWrapperFailureDelayMsecForTest = 0
    )
    $nativeJob = $null
    $processId = 0
    $processStartTime = [datetime]::MinValue
    $processIdentity = $null
    $retainedDescendantRecords = [System.Collections.Generic.List[object]]::new()
    $ownedCreationState = if ($null -ne $OwnedCreationState) { $OwnedCreationState } else { New-OwnedCreationState -Path $OwnedCreationPath }
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $executableIdentity = $null
    $executableSha256 = ''
    $resolvedExecutable = ''
    try {
        $outputPairs = @(
            [ordered]@{ path = $StdoutPath; receipt = $StdoutReceipt },
            [ordered]@{ path = $StderrPath; receipt = $StderrReceipt }
        )
        foreach ($outputPair in $outputPairs) {
            $outputPath = [string]$outputPair.path
            $resolvedOutput = [System.IO.Path]::GetFullPath($outputPath)
            $outputParent = [System.IO.Path]::GetDirectoryName($resolvedOutput)
            [void](Assert-NormalDirectoryChain -Root $outputParent -DirectoryPath $outputParent)
            if ($null -ne $outputPair.receipt) {
                if ([string]$outputPair.receipt.path -cne $resolvedOutput -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $outputPair.receipt.identity)) {
                    throw "Redirected output reservation identity changed: $resolvedOutput"
                }
            }
            elseif (Test-Path -LiteralPath $resolvedOutput) { throw "Redirected output must be fresh: $resolvedOutput" }
        }
        $resolvedExecutable = [System.IO.Path]::GetFullPath($FilePath)
        if ($null -ne $ExpectedExecutableReceipt) {
            if ([string]$ExpectedExecutableReceipt.path -cne $resolvedExecutable) { throw 'Executable receipt path does not match requested executable.' }
            $executableReadback = Read-NormalFilePinned -Path $resolvedExecutable -ExpectedIdentity $ExpectedExecutableReceipt.identity
            if ([string]$executableReadback.sha256 -cne [string]$ExpectedExecutableReceipt.sha256) { throw 'Executable receipt bytes changed before native pin.' }
        }
        else {
            $executableReadback = Read-NormalFilePinned -Path $resolvedExecutable
        }
        $executableIdentity = $executableReadback.identity
        $executableSha256 = [string]$executableReadback.sha256
        Initialize-Rw06NativeJobType
        $nativeJob = [Rw06OwnedJobProcessNative]::Start(
            $resolvedExecutable,
            [string]$executableIdentity.native_key,
            [long]$executableIdentity.creation_ticks,
            $executableSha256,
            (Join-ProcessArguments -Arguments $Arguments),
            $projectRoot,
            [System.IO.Path]::GetFullPath($StdoutPath),
            [System.IO.Path]::GetFullPath($StderrPath),
            [bool]$ForceExecutableSwapProbeForTest,
            [bool]$ForceNativeFailureAfterAssignBeforeResumeForTest,
            [bool]$ForceSecondPumpFailureForTest
        )
        $processId = [int]$nativeJob.ProcessId
        $processStartTime = [datetime]::new([long]$nativeJob.StartUtcTicks, [DateTimeKind]::Utc).ToLocalTime()
        $processIdentity = New-NativeOwnedProcessIdentity -NativeJob $nativeJob
        $jobCustody = Get-NativeJobCustodyReceipt -NativeJob $nativeJob
        if (-not (Test-NativeJobCustodyReceipt -Receipt $jobCustody -RootIdentity $processIdentity)) {
            throw 'Native suspended-create/job-assignment custody receipt is malformed.'
        }
        if ($ForceWrapperFailureAfterNativeReturnForTest) {
            if ($ForceWrapperFailureDelayMsecForTest -gt 0) { Start-Sleep -Milliseconds $ForceWrapperFailureDelayMsecForTest }
            throw 'Forced post-native-return wrapper setup failure for hostile validation.'
        }
        $startedRecord = [pscustomobject]@{
            native_job = $nativeJob
            process_id = $processId
            process_start_time = $processStartTime
            process_identity = $processIdentity
            job_custody = $jobCustody
            retained_descendant_records = $retainedDescendantRecords
            stopwatch = $stopwatch
            deadline_utc = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
            file_path = $resolvedExecutable
            arguments = @($Arguments)
            owned_creation_state = $ownedCreationState
        }
        [void]$script:rw06ActiveOwnedJobs.Add($startedRecord)
        return $startedRecord
    }
    catch {
        $startException = $_.Exception
        $jobMembersBeforeCleanup = @()
        $jobMembersAfterCleanup = @()
        $jobInstanceId = ''
        $jobSuspendedCreate = $false
        $jobAssignedBeforeResume = $false
        $jobResumedAfterAssign = $false
        $jobKillOnClose = $false
        $jobBreakawayDisabled = $false
        $jobInitialMembership = @()
        $jobCleanupEvidenceAvailable = $false
        # A compiled method failure is wrapped by PowerShell. Walk the exact
        # exception chain so the native PID/start/job receipt is not discarded
        # merely because it lives on the inner exception.
        $nativeFailureDataSource = $null
        $exceptionCursor = $startException
        for ($exceptionDepth = 0; $exceptionDepth -lt 16 -and $null -ne $exceptionCursor; $exceptionDepth += 1) {
            if (
                $exceptionCursor.Data.Contains('owned_process_id') `
                -and $exceptionCursor.Data.Contains('owned_process_start_ticks') `
                -and $exceptionCursor.Data.Contains('owned_process_name')
            ) {
                $nativeFailureDataSource = $exceptionCursor
                break
            }
            $nextException = $exceptionCursor.InnerException
            if ($null -eq $nextException -or [object]::ReferenceEquals($nextException, $exceptionCursor)) { break }
            $exceptionCursor = $nextException
        }
        if ($null -eq $processIdentity -and $null -ne $nativeFailureDataSource) {
            $nativePid = [int]$nativeFailureDataSource.Data['owned_process_id']
            $nativeTicks = [long]$nativeFailureDataSource.Data['owned_process_start_ticks']
            $nativeName = [string]$nativeFailureDataSource.Data['owned_process_name']
            $nativeExecutablePath = if ($nativeFailureDataSource.Data.Contains('owned_executable_path')) { [string]$nativeFailureDataSource.Data['owned_executable_path'] } else { $resolvedExecutable }
            $nativeExecutableSha256 = if ($nativeFailureDataSource.Data.Contains('owned_executable_sha256')) { [string]$nativeFailureDataSource.Data['owned_executable_sha256'] } else { $executableSha256 }
            $nativeExecutableKey = if ($nativeFailureDataSource.Data.Contains('owned_executable_native_key')) { [string]$nativeFailureDataSource.Data['owned_executable_native_key'] } else { [string]$executableIdentity.native_key }
            $nativeExecutableCreationTicks = if ($nativeFailureDataSource.Data.Contains('owned_executable_creation_ticks')) { [long]$nativeFailureDataSource.Data['owned_executable_creation_ticks'] } else { [long]$executableIdentity.creation_ticks }
            if ($nativePid -gt 0 -and $nativeTicks -gt 0 -and -not [string]::IsNullOrWhiteSpace($nativeName) -and (Test-ExactHexIdentity -Value $nativeExecutableSha256 -Length 64) -and $nativeExecutableKey -cmatch '^[0-9A-F]{8}:[0-9A-F]{16}$' -and $nativeExecutableCreationTicks -gt 0) {
                $processId = $nativePid
                $processIdentity = [ordered]@{
                    pid = $nativePid
                    name = $nativeName
                    start_utc = [datetime]::new($nativeTicks, [DateTimeKind]::Utc).ToString('o')
                    start_ticks = $nativeTicks
                    key = ('{0}|{1}|{2}' -f $nativePid, $nativeTicks, $nativeName)
                    executable_path = $nativeExecutablePath
                    executable_sha256 = $nativeExecutableSha256
                    executable_identity = [ordered]@{
                        path = $nativeExecutablePath
                        native_key = $nativeExecutableKey
                        is_directory = $false
                        creation_ticks = $nativeExecutableCreationTicks
                        reparse_point = $false
                        key = ('{0}|{1}|file' -f $nativeExecutableKey, $nativeExecutableCreationTicks)
                    }
                }
            }
            if ($nativeFailureDataSource.Data.Contains('owned_job_instance_id')) { $jobInstanceId = [string]$nativeFailureDataSource.Data['owned_job_instance_id'] }
            if ($nativeFailureDataSource.Data.Contains('owned_job_suspended_create')) { $jobSuspendedCreate = [bool]$nativeFailureDataSource.Data['owned_job_suspended_create'] }
            if ($nativeFailureDataSource.Data.Contains('owned_job_assigned_before_resume')) { $jobAssignedBeforeResume = [bool]$nativeFailureDataSource.Data['owned_job_assigned_before_resume'] }
            if ($nativeFailureDataSource.Data.Contains('owned_job_resumed_after_assign')) { $jobResumedAfterAssign = [bool]$nativeFailureDataSource.Data['owned_job_resumed_after_assign'] }
            if ($nativeFailureDataSource.Data.Contains('owned_job_kill_on_close')) { $jobKillOnClose = [bool]$nativeFailureDataSource.Data['owned_job_kill_on_close'] }
            if ($nativeFailureDataSource.Data.Contains('owned_job_breakaway_disabled')) { $jobBreakawayDisabled = [bool]$nativeFailureDataSource.Data['owned_job_breakaway_disabled'] }
            if ($nativeFailureDataSource.Data.Contains('owned_job_initial_membership')) { $jobInitialMembership = @($nativeFailureDataSource.Data['owned_job_initial_membership']) }
            if ($nativeFailureDataSource.Data.Contains('owned_job_members_before_cleanup')) { $jobMembersBeforeCleanup = @($nativeFailureDataSource.Data['owned_job_members_before_cleanup']) }
            if ($nativeFailureDataSource.Data.Contains('owned_job_members_after_cleanup')) {
                $jobMembersAfterCleanup = @($nativeFailureDataSource.Data['owned_job_members_after_cleanup'])
                $jobCleanupEvidenceAvailable = $true
            }
        }
        if ($null -ne $nativeJob) {
            try {
                $jobInstanceId = [string]$nativeJob.JobInstanceId
                $jobSuspendedCreate = [bool]$nativeJob.SuspendedCreate
                $jobAssignedBeforeResume = [bool]$nativeJob.AssignedBeforeResume
                $jobResumedAfterAssign = [bool]$nativeJob.ResumedAfterAssign
                $jobKillOnClose = [bool]$nativeJob.KillOnJobClose
                $jobBreakawayDisabled = [bool]$nativeJob.BreakawayDisabled
                $jobInitialMembership = @($nativeJob.InitialMembership)
                $jobMembersBeforeCleanup = @($nativeJob.GetActiveProcessIds())
                [void]$nativeJob.TerminateAndWait(125, 5000)
                $jobMembersAfterCleanup = @($nativeJob.GetActiveProcessIds())
                $jobCleanupEvidenceAvailable = $true
            }
            finally {
                $nativeJob.Dispose()
            }
        }
        if ($processId -gt 0) { $startException.Data['owned_process_id'] = [int]$processId }
        if (Test-ProcessIdentityProofShape -Identity $processIdentity) { $startException.Data['owned_process_identity'] = $processIdentity }
        $startException.Data['owned_job_instance_id'] = $jobInstanceId
        $startException.Data['owned_job_suspended_create'] = $jobSuspendedCreate
        $startException.Data['owned_job_assigned_before_resume'] = $jobAssignedBeforeResume
        $startException.Data['owned_job_resumed_after_assign'] = $jobResumedAfterAssign
        $startException.Data['owned_job_kill_on_close'] = $jobKillOnClose
        $startException.Data['owned_job_breakaway_disabled'] = $jobBreakawayDisabled
        $startException.Data['owned_job_initial_membership'] = @($jobInitialMembership)
        $startException.Data['owned_job_members_before_cleanup'] = @($jobMembersBeforeCleanup)
        $startException.Data['owned_job_members_after_cleanup'] = @($jobMembersAfterCleanup)
        $startException.Data['owned_job_cleanup_proven'] = (
            $jobCleanupEvidenceAvailable `
            -and $processId -gt 0 `
            -and $jobAssignedBeforeResume `
            -and $jobMembersAfterCleanup.Count -eq 0
        )
        if ($null -ne $nativeFailureDataSource) {
            foreach ($nativeCustodyKey in @(
                'owned_executable_path', 'owned_executable_native_key', 'owned_executable_creation_ticks', 'owned_executable_sha256',
                'owned_mapped_image_path', 'owned_mapped_image_native_key', 'owned_mapped_image_creation_ticks', 'owned_mapped_image_sha256',
                'owned_executable_handle_opened', 'owned_executable_identity_verified', 'owned_executable_sha256_verified',
                'owned_executable_ancestor_chain_pinned', 'owned_executable_held_through_create',
                'owned_mapped_image_path_verified', 'owned_mapped_image_identity_verified', 'owned_mapped_image_sha256_verified',
                'owned_executable_held_through_resume', 'owned_executable_swap_probe_rejected'
            )) {
                if ($nativeFailureDataSource.Data.Contains($nativeCustodyKey)) {
                    $startException.Data[$nativeCustodyKey] = $nativeFailureDataSource.Data[$nativeCustodyKey]
                }
            }
        }
        $startException.Data['owned_creation_state'] = $ownedCreationState
        $stopwatch.Stop()
        throw
    }
}


# The exact retained job handle is the sole termination authority for every
# descendant.
function Complete-RedirectedProcess {
    param(
        [pscustomobject]$Started,
        [int]$TimeoutSec,
        [ValidateSet('Godot', 'Exact')]
        [string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @()
    )
    $nativeJob = $Started.native_job
    $processId = [int]$Started.process_id
    $timedOut = $false
    $nativeObserved = $false
    $nativeExitCode = [int]$nativeExitSentinel
    $effectiveExitCode = 125
    $errorText = ''
    $jobMembersBeforeTermination = @()
    $jobMembersAfterTermination = @()
    $jobEmpty = $false
    try {
        while ([DateTime]::UtcNow -lt $Started.deadline_utc) {
            Add-LiveNativeJobMemberIdentities -NativeJob $nativeJob -RootIdentity $Started.process_identity -RetainedRecords $Started.retained_descendant_records
            if ($nativeJob.WaitForRootExit(0) -and @($nativeJob.GetActiveProcessIds()).Count -eq 0) {
                $jobEmpty = $true
                break
            }
            Start-Sleep -Milliseconds 25
        }
        if (-not $jobEmpty) {
            $timedOut = $true
            $jobMembersBeforeTermination = @($nativeJob.GetActiveProcessIds())
            [void]$nativeJob.TerminateAndWait(124, 5000)
            $jobMembersAfterTermination = @($nativeJob.GetActiveProcessIds())
            $jobEmpty = ($jobMembersAfterTermination.Count -eq 0)
        }
        if (-not $nativeJob.WaitForRootExit(5000)) {
            throw 'Exact job cleanup did not produce a completed retained root handle.'
        }
        $nativeExitCode = Get-StrictNativeExitCode -RawValue $nativeJob.GetRootExitCode()
        $nativeObserved = $true
        if (-not $jobEmpty -or @($nativeJob.GetActiveProcessIds()).Count -ne 0) {
            throw 'Exact owned job was not empty after bounded completion.'
        }
        $effectiveExitCode = if ($timedOut) { 124 } else { $nativeExitCode }
    }
    catch {
        $errorText = $_.Exception.Message
        $effectiveExitCode = if ($timedOut) { 124 } else { 125 }
        try {
            $jobMembersBeforeTermination = @($nativeJob.GetActiveProcessIds())
            [void]$nativeJob.TerminateAndWait(125, 5000)
            $jobMembersAfterTermination = @($nativeJob.GetActiveProcessIds())
            $jobEmpty = ($jobMembersAfterTermination.Count -eq 0)
        }
        catch {}
    }
    finally {
        $Started.stopwatch.Stop()
        if ($jobEmpty -and @($nativeJob.GetActiveProcessIds()).Count -eq 0) {
            try { $nativeJob.Dispose() } catch {}
            [void]$script:rw06ActiveOwnedJobs.Remove($Started)
        }
    }
    return [ordered]@{
        process_started = $true
        process_start_provenance = 'native_suspended_job'
        native_exit_code = [int]$nativeExitCode
        native_exit_observed = $nativeObserved
        native_exit_type = if ($nativeObserved) { 'System.Int32' } else { '' }
        effective_exit_code = [int]$effectiveExitCode
        timed_out = $timedOut
        elapsed_seconds = [Math]::Round($Started.stopwatch.Elapsed.TotalSeconds, 3)
        process_id = $processId
        started_utc = $Started.process_identity.start_utc
        process_identity = $Started.process_identity
        job_custody = $Started.job_custody
        job_members_before_termination = @($jobMembersBeforeTermination)
        job_members_after_termination = @($jobMembersAfterTermination)
        job_empty = [bool]$jobEmpty
        retained_descendant_identities = @($Started.retained_descendant_records)
        owned_creation = $Started.owned_creation_state
        error = $errorText
    }
}


function Stop-AllActiveOwnedJobsExact {
    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($started in @($script:rw06ActiveOwnedJobs)) {
        try {
            $job = $started.native_job
            $before = @($job.GetActiveProcessIds())
            if ($before.Count -gt 0) { [void]$job.TerminateAndWait(125, 5000) }
            $after = @($job.GetActiveProcessIds())
            if ($after.Count -ne 0) { throw ('Exact owned job retained members: ' + ($after -join ',')) }
            $job.Dispose()
            [void]$script:rw06ActiveOwnedJobs.Remove($started)
        }
        catch { [void]$failures.Add($_.Exception.Message) }
    }
    return [ordered]@{
        empty = ($failures.Count -eq 0 -and $script:rw06ActiveOwnedJobs.Count -eq 0)
        failures = @($failures)
        remaining_job_count = $script:rw06ActiveOwnedJobs.Count
    }
}


function Get-DiagnosticLines {
    param([string]$Text)
    $patterns = @(
        '(?im)^.*SCRIPT ERROR.*$',
        '(?im)^\s*ERROR(?:\s|:).*$',
        '(?im)^\s*WARNING(?:\s|:).*$',
        '(?im)^.*ObjectDB.*(?:leak|still alive|instance).*$',
        '(?im)^\s*Orphan StringName:.*$',
        '(?im)^\s*StringName:.*\bunclaimed string names?\b.*$'
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($Text, $pattern)) {
            $line = $match.Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($line) -and -not $lines.Contains($line)) {
                $lines.Add($line)
            }
        }
    }
    return @($lines)
}


function Get-UnexpectedRedDiagnostics {
    param([string[]]$Diagnostics)
    return @($Diagnostics | Where-Object { $_ -notmatch '^ERROR:\s+RW06_6_PRODUCT_RED:' })
}


function Resolve-GuardDisposition {
    param(
        [int]$NativeExitCode,
        [bool]$NativeExitObserved,
        [int]$EffectiveExitCode,
        [bool]$TimedOut,
        [string]$RunnerError,
        [bool]$ProductRedMarkerSeen,
        [bool]$GuardPassMarkerSeen,
        [bool]$InfraFailureMarkerSeen,
        [bool]$FullPassMarkerSeen,
        [int]$UnexpectedDiagnosticCount
    )
    if (
        -not $NativeExitObserved `
        -or $TimedOut `
        -or -not [string]::IsNullOrWhiteSpace($RunnerError) `
        -or $InfraFailureMarkerSeen `
        -or $FullPassMarkerSeen `
        -or $UnexpectedDiagnosticCount -gt 0
    ) {
        return 'invalid'
    }
    if ($ProductRedMarkerSeen -and -not $GuardPassMarkerSeen -and $NativeExitCode -eq 10 -and $EffectiveExitCode -eq 10) {
        return 'valid_red'
    }
    if ($GuardPassMarkerSeen -and -not $ProductRedMarkerSeen -and $NativeExitCode -eq 0 -and $EffectiveExitCode -eq 0) {
        return 'green_handoff'
    }
    return 'invalid'
}


function Test-PhaseMarkerContract {
    param(
        [ValidateSet('Registry', 'Full')]
        [string]$Phase,
        [bool]$ProductRedMarkerSeen,
        [bool]$GuardPassMarkerSeen,
        [bool]$InfraFailureMarkerSeen,
        [bool]$FullPassMarkerSeen
    )
    if ($ProductRedMarkerSeen -or $GuardPassMarkerSeen -or $InfraFailureMarkerSeen) {
        return $false
    }
    if ($Phase -eq 'Registry') {
        return -not $FullPassMarkerSeen
    }
    return $FullPassMarkerSeen
}


function Get-RegistryBootstrapArguments {
    param([string]$Root)
    return @(
        '--headless', '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy', '--path', $Root,
        '--recovery-mode', '--import'
    )
}


function New-Rw06CacheOwnerScript {
    param([string]$DestinationPath, $EvidenceReceipt)
    $source = @'
extends SceneTree

func _fail(message: String) -> void:
	printerr("RW06_6_CACHE_OWNER_FAILURE " + message)
	quit(2)

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode().to_upper()

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 8:
		_fail("argument_count")
		return
	var values: Dictionary = {}
	var index := 0
	while index < args.size():
		var key := String(args[index])
		var value := String(args[index + 1])
		if values.has(key):
			_fail("duplicate_argument")
			return
		values[key] = value
		index += 2
	for required in ["--rw06-cache-root", "--rw06-owner-nonce", "--rw06-candidate-commit", "--rw06-candidate-tree"]:
		if not values.has(required):
			_fail("missing_argument")
			return
	var cache_path := String(values["--rw06-cache-root"])
	var nonce := String(values["--rw06-owner-nonce"])
	var candidate_commit := String(values["--rw06-candidate-commit"])
	var candidate_tree := String(values["--rw06-candidate-tree"])
	if nonce.length() != 32 or candidate_commit.length() != 40 or candidate_tree.length() != 40:
		_fail("identity_shape")
		return
	if not DirAccess.dir_exists_absolute(cache_path):
		_fail("cache_root_not_precreated")
		return
	var request_path := cache_path.path_join(".rw06_6-cache-request.json")
	var ack_path := cache_path.path_join(".rw06_6-cache-ack.json")
	var claim_path := cache_path.path_join(".rw06_6-cache-owner.json")
	if FileAccess.file_exists(request_path) or FileAccess.file_exists(ack_path) or FileAccess.file_exists(claim_path):
		_fail("handshake_preexisting")
		return
	var request_temporary_path := request_path + ".tmp-" + nonce
	if FileAccess.file_exists(request_temporary_path):
		_fail("request_temporary_preexisting")
		return
	var request := {
		"contract": "rw06_6_cache_owner_request_v2",
		"nonce": nonce,
		"creator_pid": OS.get_process_id(),
		"candidate_commit": candidate_commit,
		"candidate_tree": candidate_tree,
		"cache_path": cache_path,
		"created_utc": Time.get_datetime_string_from_system(true, false) + "Z",
	}
	var output := FileAccess.open(request_temporary_path, FileAccess.WRITE)
	if output == null:
		_fail("request_temporary_open")
		return
	output.store_string(JSON.stringify(request) + "\n")
	output.flush()
	output = null
	var cache_directory := DirAccess.open(cache_path)
	if cache_directory == null:
		_fail("cache_open")
		return
	var rename_error := cache_directory.rename(request_temporary_path.get_file(), request_path.get_file())
	if rename_error != OK:
		_fail("request_rename_%d" % rename_error)
		return
	var request_sha256 := _sha256(FileAccess.get_file_as_bytes(request_path))
	if request_sha256.length() != 64:
		_fail("request_hash")
		return
	var deadline := Time.get_ticks_msec() + 15000
	while not FileAccess.file_exists(ack_path) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
	if not FileAccess.file_exists(ack_path):
		_fail("ack_timeout")
		return
	var ack_bytes := FileAccess.get_file_as_bytes(ack_path)
	var ack_sha256 := _sha256(ack_bytes)
	var parsed_ack: Variant = JSON.parse_string(ack_bytes.get_string_from_utf8())
	if typeof(parsed_ack) != TYPE_DICTIONARY:
		_fail("ack_json")
		return
	var ack: Dictionary = parsed_ack
	var ack_keys := ["contract", "nonce", "creator_pid", "candidate_commit", "candidate_tree", "cache_path", "cache_native_key", "cache_creation_ticks", "creator_job_instance_id", "request_sha256", "acknowledged_utc"]
	if ack.size() != ack_keys.size():
		_fail("ack_fields")
		return
	for key in ack_keys:
		if not ack.has(key):
			_fail("ack_missing_" + key)
			return
	if String(ack["contract"]) != "rw06_6_cache_owner_ack_v2" or String(ack["nonce"]) != nonce or int(ack["creator_pid"]) != OS.get_process_id() or String(ack["candidate_commit"]) != candidate_commit or String(ack["candidate_tree"]) != candidate_tree or String(ack["cache_path"]) != cache_path or String(ack["request_sha256"]) != request_sha256:
		_fail("ack_binding")
		return
	var claim := {
		"contract": "rw06_6_cache_owner_v2",
		"nonce": nonce,
		"creator_pid": OS.get_process_id(),
		"candidate_commit": candidate_commit,
		"candidate_tree": candidate_tree,
		"cache_path": cache_path,
		"cache_native_key": String(ack["cache_native_key"]),
		"cache_creation_ticks": String(ack["cache_creation_ticks"]),
		"creator_job_instance_id": String(ack["creator_job_instance_id"]),
		"request_sha256": request_sha256,
		"ack_sha256": ack_sha256,
		"created_utc": Time.get_datetime_string_from_system(true, false) + "Z",
	}
	var temporary_path := claim_path + ".tmp-" + nonce
	if FileAccess.file_exists(temporary_path):
		_fail("claim_temporary_preexisting")
		return
	output = FileAccess.open(temporary_path, FileAccess.WRITE)
	if output == null:
		_fail("claim_temporary_open")
		return
	output.store_string(JSON.stringify(claim) + "\n")
	output.flush()
	output = null
	rename_error = cache_directory.rename(temporary_path.get_file(), claim_path.get_file())
	if rename_error != OK:
		_fail("claim_rename_%d" % rename_error)
		return
	print("RW06_6_CACHE_OWNER_PASS nonce=" + nonce + " pid=" + str(OS.get_process_id()))
	quit(0)
'@
    $seal = Write-AtomicSealedText -EvidenceReceipt $EvidenceReceipt -DestinationPath $DestinationPath -Text ($source + "`n")
    return [ordered]@{
        path = $DestinationPath
        resource_path = ConvertTo-ProjectResourcePath -Root $projectRoot -Path $DestinationPath
        sha256 = [string]$seal.sha256
        identity = $seal.identity
        pre_move_identity = $seal.pre_move_identity
        post_move_identity_verified = [bool]$seal.post_move_identity_verified
        receipt = $seal
        builtins_only = (
            -not [regex]::IsMatch($source, '(?im)^\s*(?!#).*\b(?:preload|load|ResourceLoader)\s*\(') `
            -and -not [regex]::IsMatch($source, '(?im)^\s*(?:extends|class_name|var|const|func)\b[^\r\n]*(?:RunState|GameModule|ContentLibrary|RngStream|PullTabsGame)')
        )
    }
}


function Get-CacheOwnerArguments {
    param([string]$Root, [string]$ScriptPath, [string]$Nonce, [string]$Commit, [string]$Tree)
    return @(
        '--headless', '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy', '--path', $Root,
        '--script', $ScriptPath, '--',
        '--rw06-cache-root', $projectCacheRoot,
        '--rw06-owner-nonce', $Nonce,
        '--rw06-candidate-commit', $Commit,
        '--rw06-candidate-tree', $Tree
    )
}


function Test-CacheOwnerArguments {
    param([string[]]$Arguments, [string]$Root, [string]$ScriptPath, [string]$Nonce, [string]$Commit, [string]$Tree, [string]$GodotLogPath = '')
    $expected = @(Get-CacheOwnerArguments -Root $Root -ScriptPath $ScriptPath -Nonce $Nonce -Commit $Commit -Tree $Tree)
    if (-not [string]::IsNullOrWhiteSpace($GodotLogPath)) { $expected = @('--log-file', $GodotLogPath) + $expected }
    if ($Arguments.Count -ne $expected.Count) { return $false }
    for ($index = 0; $index -lt $expected.Count; $index += 1) {
        if ([string]$Arguments[$index] -cne [string]$expected[$index]) { return $false }
    }
    return $true
}


function Test-RegistryBootstrapArguments {
    param(
        [string[]]$Arguments,
        [string]$Root,
        [string]$GodotLogPath = ''
    )
    $expected = @(Get-RegistryBootstrapArguments -Root $Root)
    if (-not [string]::IsNullOrWhiteSpace($GodotLogPath)) {
        $expected = @('--log-file', $GodotLogPath) + $expected
    }
    if ($Arguments.Count -ne $expected.Count) { return $false }
    for ($index = 0; $index -lt $expected.Count; $index += 1) {
        if ([string]$Arguments[$index] -cne [string]$expected[$index]) { return $false }
    }
    return $true
}


function Get-FullContractArguments {
    param(
        [string]$Root,
        [string]$ScriptPath
    )
    return @(
        '--headless', '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy', '--path', $Root,
        '--script', $ScriptPath
    )
}


function Test-FullContractArguments {
    param(
        [string[]]$Arguments,
        [string]$Root,
        [string]$ScriptPath,
        [string]$GodotLogPath = ''
    )
    $expected = @(Get-FullContractArguments -Root $Root -ScriptPath $ScriptPath)
    if (-not [string]::IsNullOrWhiteSpace($GodotLogPath)) {
        $expected = @('--log-file', $GodotLogPath) + $expected
    }
    if ($Arguments.Count -ne $expected.Count) { return $false }
    for ($index = 0; $index -lt $expected.Count; $index += 1) {
        if ([string]$Arguments[$index] -cne [string]$expected[$index]) { return $false }
    }
    return $true
}


function ConvertTo-ProjectResourcePath {
    param([string]$Root, [string]$Path)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedPath = Assert-PathContainedByRoot -Root $resolvedRoot -Path $Path
    return 'res://' + $resolvedPath.Substring($resolvedRoot.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
}


function New-Rw06FoundationRunner {
    param(
        [string]$Root,
        [string]$Commit,
        [string]$DestinationPath,
        $EvidenceReceipt
    )
    $sourceFiles = [System.Collections.Generic.List[object]]::new()
    $sourceGuards = [System.Collections.Generic.List[System.IO.FileStream]]::new()
    $allSourcePaths = @($splitRunnerHelperRelativePath) + @($foundationSplitSourceRelativePaths)
    try {
        foreach ($relativePath in $allSourcePaths) {
            $fullSourcePath = Join-Path $Root ($relativePath.Replace('/', '\'))
            $guard = [System.IO.FileStream]::new($fullSourcePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            [void]$sourceGuards.Add($guard)
            [void]$sourceFiles.Add((Get-TrackedFileIdentity -Root $Root -Commit $Commit -RelativePath $relativePath))
        }
        # The helper and every source it reads remain non-write/non-delete shared
        # from verified tracked identity through dot-source and composition.
        $helperPath = Join-Path $Root ($splitRunnerHelperRelativePath.Replace('/', '\'))
        . $helperPath
        $lines = @(Get-SplitTestRunnerLines -ProjectRoot $Root -SourceRelativePaths $foundationSplitSourceRelativePaths)
        $composition = Test-SplitTestRunnerComposition -Lines $lines -RequiredSymbols @('_foundation_run_suite', '_check_pull_tabs_surface_contract')
        if (-not [bool]$composition.valid) {
            throw 'Adjacent Foundation split-runner composition failed: ' + (@($composition.errors) -join ' | ')
        }
    }
    finally {
        foreach ($guard in $sourceGuards) { $guard.Dispose() }
    }
    $text = [string]::Join("`r`n", $lines) + "`r`n"
    $seal = Write-AtomicSealedText -EvidenceReceipt $EvidenceReceipt -DestinationPath $DestinationPath -Text $text
    return [ordered]@{
        path = $DestinationPath
        resource_path = ConvertTo-ProjectResourcePath -Root $Root -Path $DestinationPath
        sha256 = [string]$seal.sha256
        length = [long]$seal.length
        git_blob = (& git -C $Root hash-object --no-filters -- $DestinationPath).Trim()
        composition_valid = $true
        required_symbols = @('_foundation_run_suite', '_check_pull_tabs_surface_contract')
        sources = @($sourceFiles)
        atomic_no_overwrite = [bool]$seal.atomic_no_overwrite
        readback_verified = [bool]$seal.readback_verified
        receipt = $seal
    }
}


function Get-AdjacentFoundationArguments {
    param([string]$Root, [string]$ScriptPath, [string]$ReportResourcePath)
    return @(
        '--headless', '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy', '--path', $Root,
        '--script', $ScriptPath, '--',
        '--suite=pull_tabs', ('--report=' + $ReportResourcePath)
    )
}


function Test-AdjacentFoundationArguments {
    param(
        [string[]]$Arguments,
        [string]$Root,
        [string]$ScriptPath,
        [string]$ReportResourcePath,
        [string]$GodotLogPath = ''
    )
    $expected = @(Get-AdjacentFoundationArguments -Root $Root -ScriptPath $ScriptPath -ReportResourcePath $ReportResourcePath)
    if (-not [string]::IsNullOrWhiteSpace($GodotLogPath)) {
        $expected = @('--log-file', $GodotLogPath) + $expected
    }
    if ($Arguments.Count -ne $expected.Count) { return $false }
    for ($index = 0; $index -lt $expected.Count; $index += 1) {
        if ([string]$Arguments[$index] -cne [string]$expected[$index]) { return $false }
    }
    return $true
}


function Test-AdjacentFoundationReport {
    param($Report)
    if ($null -eq $Report) { return $false }
    foreach ($requiredProperty in @('tool', 'suite', 'passed', 'failure_count', 'failures', 'requested_check_ids', 'skipped', 'executed_check_ids', 'registered_check_ids', 'checks', 'last_started_check')) {
        if ($null -eq $Report.PSObject.Properties[$requiredProperty]) { return $false }
    }
    if (
        -not ($Report.tool -is [string]) `
        -or -not ($Report.suite -is [string]) `
        -or -not ($Report.passed -is [bool]) `
        -or -not ($Report.failure_count -is [int]) `
        -or -not ($Report.failures -is [System.Array]) `
        -or -not ($Report.requested_check_ids -is [System.Array]) `
        -or -not ($Report.skipped -is [System.Array]) `
        -or -not ($Report.executed_check_ids -is [System.Array]) `
        -or -not ($Report.registered_check_ids -is [System.Array]) `
        -or -not ($Report.checks -is [System.Array]) `
        -or -not ($Report.last_started_check -is [string])
    ) { return $false }
    $executed = @($Report.executed_check_ids | ForEach-Object { [string]$_ })
    $registered = @($Report.registered_check_ids | ForEach-Object { [string]$_ })
    $checks = @($Report.checks)
    if (
        [string]$Report.tool -cne 'foundation_check' `
        -or [string]$Report.suite -cne 'pull_tabs' `
        -or -not [bool]$Report.passed `
        -or [int]$Report.failure_count -ne 0 `
        -or @($Report.failures).Count -ne 0 `
        -or @($Report.requested_check_ids).Count -ne 0 `
        -or @($Report.skipped).Count -ne 0 `
        -or $executed.Count -ne 2 `
        -or $registered.Count -ne 2 `
        -or $checks.Count -ne 2
    ) { return $false }
    if ($executed[0] -cne 'content' -or $executed[1] -cne 'pull_tabs_game_suite') { return $false }
    if ($registered[0] -cne 'content' -or $registered[1] -cne 'pull_tabs_game_suite') { return $false }
    for ($index = 0; $index -lt $checks.Count; $index += 1) {
        $check = $checks[$index]
        if (
            $null -eq $check `
            -or $null -eq $check.PSObject.Properties['id'] `
            -or $null -eq $check.PSObject.Properties['passed'] `
            -or $null -eq $check.PSObject.Properties['failure_count'] `
            -or $null -eq $check.PSObject.Properties['failures'] `
            -or -not ($check.id -is [string]) `
            -or -not ($check.passed -is [bool]) `
            -or -not ($check.failure_count -is [int]) `
            -or -not ($check.failures -is [System.Array]) `
            -or [string]$check.id -cne $executed[$index] `
            -or -not [bool]$check.passed `
            -or [int]$check.failure_count -ne 0 `
            -or @($check.failures).Count -ne 0
        ) {
            return $false
        }
    }
    return [string]$Report.last_started_check -ceq 'pull_tabs_game_suite'
}


function Test-AdjacentPhaseMarkerContract {
    param(
        [bool]$ProductRedMarkerSeen,
        [bool]$GuardPassMarkerSeen,
        [bool]$InfraFailureMarkerSeen,
        [bool]$FullPassMarkerSeen,
        [bool]$FoundationPassMarkerSeen,
        [bool]$FoundationPullTabsDoneMarkerSeen,
        [int]$FoundationDoneCount
    )
    return (
        -not $ProductRedMarkerSeen `
        -and -not $GuardPassMarkerSeen `
        -and -not $InfraFailureMarkerSeen `
        -and -not $FullPassMarkerSeen `
        -and $FoundationPassMarkerSeen `
        -and $FoundationPullTabsDoneMarkerSeen `
        -and $FoundationDoneCount -eq 2
    )
}


function Get-RegistryLifecycleEvidence {
    param(
        [AllowEmptyString()][string]$StdoutText = '',
        [AllowEmptyString()][string]$StderrText = '',
        [AllowEmptyString()][string]$GodotLogText = ''
    )
    $allPhaseText = [string]::Join("`n", @($StdoutText, $StderrText, $GodotLogText))
    return [ordered]@{
        first_scan_done = [regex]::IsMatch($allPhaseText, '(?m)^\[ DONE \]\s+first_scan_filesystem\s*$')
        update_scripts_classes_done = [regex]::IsMatch($allPhaseText, '(?m)^\[ DONE \]\s+update_scripts_classes\s*$')
        reimport_done_count = [regex]::Matches($allPhaseText, '(?m)^\[ DONE \]\s+reimport\s*$').Count
        main_scene_loaded = $allPhaseText.Contains('Loading resource: res://scenes/main.tscn')
        foundation_main_loaded = $allPhaseText.Contains('Loading resource: res://scripts/ui/foundation_main.gd')
    }
}


function Test-RegistryLifecycleContract {
    param($Lifecycle)
    if ($null -eq $Lifecycle) { return $false }
    return (
        [bool]$Lifecycle.first_scan_done `
        -and [bool]$Lifecycle.update_scripts_classes_done `
        -and [int]$Lifecycle.reimport_done_count -ge 1 `
        -and -not [bool]$Lifecycle.main_scene_loaded `
        -and -not [bool]$Lifecycle.foundation_main_loaded
    )
}


function Get-ProjectSectionEntries {
    param(
        [string]$Text,
        [string]$SectionName
    )
    $escapedSection = [regex]::Escape($SectionName)
    $matches = [regex]::Matches($Text, '(?ms)^\[' + $escapedSection + '\]\s*\r?\n(?<body>.*?)(?=^\[|\z)')
    if ($matches.Count -gt 1) {
        throw "Project file contains duplicate [$SectionName] sections."
    }
    if ($matches.Count -eq 0) { return @() }
    return @($matches[0].Groups['body'].Value -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith(';')
    })
}


function Get-RecoveryBootstrapDependencyCensusSha256 {
    param($Census)
    $hashPayload = [ordered]@{
        inventory_mode = [string]$Census.inventory_mode
        inventory_file_count = [int]$Census.inventory_file_count
        tracked_file_count = [int]$Census.tracked_file_count
        untracked_file_count = [int]$Census.untracked_file_count
        ignored_file_count = [int]$Census.ignored_file_count
        unclassified_file_count = [int]$Census.unclassified_file_count
        gd_script_count = [int]$Census.gd_script_count
        project_file_present = [bool]$Census.project_file_present
        inventory_entries = @($Census.inventory_entries)
        reparse_paths = @($Census.reparse_paths)
        addon_paths = @($Census.addon_paths)
        plugin_config_paths = @($Census.plugin_config_paths)
        gdextension_paths = @($Census.gdextension_paths)
        native_extension_paths = @($Census.native_extension_paths)
        tool_script_paths = @($Census.tool_script_paths)
        autoload_entries = @($Census.autoload_entries)
        editor_plugin_entries = @($Census.editor_plugin_entries)
        clean = [bool]$Census.clean
    }
    return Get-StringSha256 -Value (($hashPayload | ConvertTo-Json -Depth 6 -Compress))
}


function Get-RecoveryBootstrapDependencyCensus {
    param(
        [string]$Root,
        [ValidateSet('EngineVisible')]
        [string]$InventoryMode = 'EngineVisible'
    )
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Recovery-bootstrap dependency census root is unavailable: $resolvedRoot"
    }
    $rootItem = Get-Item -LiteralPath $resolvedRoot -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Recovery-bootstrap dependency census root is a reparse point: $resolvedRoot"
    }

    $trackedPaths = @(& git -C $resolvedRoot ls-files -- | ForEach-Object { ([string]$_).Replace('\', '/') })
    if ($LASTEXITCODE -ne 0 -or $trackedPaths.Count -eq 0) {
        throw 'Could not enumerate tracked files for the recovery-bootstrap dependency census.'
    }
    $untrackedPaths = @(& git -C $resolvedRoot ls-files --others --exclude-standard -- | ForEach-Object { ([string]$_).Replace('\', '/') })
    if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate untracked engine-visible inputs.' }
    $ignoredPaths = @(& git -C $resolvedRoot ls-files --others --ignored --exclude-standard -- | ForEach-Object { ([string]$_).Replace('\', '/') })
    if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate ignored engine-visible inputs.' }
    $trackedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $untrackedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ignoredSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $trackedPaths) { [void]$trackedSet.Add([string]$path) }
    foreach ($path in $untrackedPaths) { [void]$untrackedSet.Add([string]$path) }
    foreach ($path in $ignoredPaths) { [void]$ignoredSet.Add([string]$path) }

    $fileItems = [System.Collections.Generic.List[object]]::new()
    $directoryPaths = [System.Collections.Generic.List[string]]::new()
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($resolvedRoot)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
            $relativePath = $item.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
            if ($relativePath -match '(?i)^\.git(?:/|$)' -or $relativePath -match '(?i)^\.godot(?:/|$)') { continue }
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Recovery-bootstrap engine-visible inventory contains a reparse point: $relativePath"
            }
            if ($item.PSIsContainer) {
                $directoryPaths.Add($relativePath)
                $stack.Push($item.FullName)
            }
            else {
                $fileItems.Add($item)
            }
        }
    }
    if ($fileItems.Count -eq 0) {
        throw 'Recovery-bootstrap engine-visible inventory is empty.'
    }

    $inventoryEntries = [System.Collections.Generic.List[object]]::new()
    $inventoryPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @($fileItems | Sort-Object FullName)) {
        $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
        $classification = if ($trackedSet.Contains($relativePath)) { 'tracked' } elseif ($ignoredSet.Contains($relativePath)) { 'ignored' } elseif ($untrackedSet.Contains($relativePath)) { 'untracked' } else { 'unclassified' }
        $beforeLength = [long]$file.Length
        $beforeWriteTicks = [long]$file.LastWriteTimeUtc.Ticks
        $sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        $after = Get-Item -LiteralPath $file.FullName -Force
        if (($after.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or [long]$after.Length -ne $beforeLength -or [long]$after.LastWriteTimeUtc.Ticks -ne $beforeWriteTicks) {
            throw "Engine-visible input changed or became a reparse point during census: $relativePath"
        }
        $inventoryPaths.Add($relativePath)
        $inventoryEntries.Add([ordered]@{
            path = $relativePath
            classification = $classification
            length = $beforeLength
            last_write_ticks = $beforeWriteTicks
            sha256 = $sha256
        })
    }

    $addonPaths = @(@($inventoryPaths | Where-Object { $_ -match '(?i)^addons(?:/|$)' }) + @($directoryPaths | Where-Object { $_ -match '(?i)^addons(?:/|$)' }) | Sort-Object -Unique)
    $pluginConfigPaths = @($inventoryPaths | Where-Object { $_ -match '(?i)(^|/)plugin\.cfg$' })
    $gdextensionPaths = @($inventoryPaths | Where-Object { $_ -match '(?i)\.gdextension$' })
    $nativeExtensionPaths = @($inventoryPaths | Where-Object { $_ -match '(?i)\.(?:dll|so|dylib)$' })
    $gdScriptPaths = @($inventoryPaths | Where-Object { $_ -match '(?i)\.gd$' })
    $toolScriptPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($relativePath in $gdScriptPaths) {
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot ($relativePath.Replace('/', '\'))))
        if (-not $fullPath.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Inventoried script escaped the census root: $relativePath"
        }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            throw "Inventoried script is absent from the census root: $relativePath"
        }
        $scriptItem = Get-Item -LiteralPath $fullPath -Force
        if (($scriptItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Inventoried script is a reparse point: $relativePath"
        }
        $source = [System.IO.File]::ReadAllText($fullPath)
        if ([regex]::IsMatch($source, '(?im)^(?:\uFEFF)?\s*@tool\s*(?:#.*)?$')) {
            $toolScriptPaths.Add([string]$relativePath)
        }
    }

    $projectPath = Join-Path $resolvedRoot 'project.godot'
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
        throw 'Recovery-bootstrap dependency census could not find project.godot.'
    }
    $projectText = [System.IO.File]::ReadAllText($projectPath)
    $autoloadEntries = @(Get-ProjectSectionEntries -Text $projectText -SectionName 'autoload')
    $editorPluginEntries = @(Get-ProjectSectionEntries -Text $projectText -SectionName 'editor_plugins')
    $clean = (
        $addonPaths.Count -eq 0 `
        -and $pluginConfigPaths.Count -eq 0 `
        -and $gdextensionPaths.Count -eq 0 `
        -and $nativeExtensionPaths.Count -eq 0 `
        -and $toolScriptPaths.Count -eq 0 `
        -and $autoloadEntries.Count -eq 0 `
        -and $editorPluginEntries.Count -eq 0 `
        -and @($inventoryEntries | Where-Object { [string]$_.classification -ceq 'unclassified' }).Count -eq 0
    )
    $census = [ordered]@{
        inventory_mode = $InventoryMode
        inventory_file_count = $inventoryPaths.Count
        tracked_file_count = @($inventoryEntries | Where-Object { [string]$_.classification -ceq 'tracked' }).Count
        untracked_file_count = @($inventoryEntries | Where-Object { [string]$_.classification -ceq 'untracked' }).Count
        ignored_file_count = @($inventoryEntries | Where-Object { [string]$_.classification -ceq 'ignored' }).Count
        unclassified_file_count = @($inventoryEntries | Where-Object { [string]$_.classification -ceq 'unclassified' }).Count
        gd_script_count = $gdScriptPaths.Count
        project_file_present = $true
        inventory_entries = @($inventoryEntries)
        reparse_paths = @()
        addon_paths = @($addonPaths)
        plugin_config_paths = @($pluginConfigPaths)
        gdextension_paths = @($gdextensionPaths)
        native_extension_paths = @($nativeExtensionPaths)
        tool_script_paths = @($toolScriptPaths)
        autoload_entries = @($autoloadEntries)
        editor_plugin_entries = @($editorPluginEntries)
        clean = $clean
    }
    $census.sha256 = Get-RecoveryBootstrapDependencyCensusSha256 -Census $census
    return $census
}


function Test-RecoveryBootstrapDependencyCensus {
    param($Census)
    if ($null -eq $Census) { return $false }
    foreach ($requiredKey in @(
        'inventory_mode', 'inventory_file_count', 'tracked_file_count',
        'untracked_file_count', 'ignored_file_count', 'unclassified_file_count',
        'gd_script_count', 'project_file_present', 'inventory_entries', 'reparse_paths',
        'addon_paths', 'plugin_config_paths', 'gdextension_paths',
        'native_extension_paths', 'tool_script_paths', 'autoload_entries', 'editor_plugin_entries',
        'clean', 'sha256'
    )) {
        if (-not $Census.Contains($requiredKey)) { return $false }
    }
    if ([string]$Census.inventory_mode -cne 'EngineVisible') { return $false }
    if ([string]$Census.sha256 -cne (Get-RecoveryBootstrapDependencyCensusSha256 -Census $Census)) { return $false }
    return (
        [int]$Census.inventory_file_count -gt 0 `
        -and (([int]$Census.tracked_file_count + [int]$Census.untracked_file_count + [int]$Census.ignored_file_count + [int]$Census.unclassified_file_count) -eq [int]$Census.inventory_file_count) `
        -and [int]$Census.unclassified_file_count -eq 0 `
        -and [int]$Census.gd_script_count -gt 0 `
        -and [bool]$Census.project_file_present `
        -and $Census.inventory_entries.Count -eq [int]$Census.inventory_file_count `
        -and $Census.reparse_paths.Count -eq 0 `
        -and $Census.addon_paths.Count -eq 0 `
        -and $Census.plugin_config_paths.Count -eq 0 `
        -and $Census.gdextension_paths.Count -eq 0 `
        -and $Census.native_extension_paths.Count -eq 0 `
        -and $Census.tool_script_paths.Count -eq 0 `
        -and $Census.autoload_entries.Count -eq 0 `
        -and $Census.editor_plugin_entries.Count -eq 0 `
        -and [bool]$Census.clean `
        -and -not [string]::IsNullOrWhiteSpace([string]$Census.sha256)
    )
}


function Test-Q016ApprovalText {
    param([string]$Text)
    $sectionMatches = [regex]::Matches($Text, '(?ims)^### Q-016\b(?<body>.*?)(?=^### |\z)')
    if ($sectionMatches.Count -ne 1) { return $false }
    $body = $sectionMatches[0].Groups['body'].Value
    return $body -match '(?im)^Status:\s*ANSWERED\s*$' -and $body -match '(?im)^Answer:\s*(?:\r?\n\s*)?A(?:\.|\s|$)'
}


function Get-StringSha256 {
    param([string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}


function Get-Q016ApprovalSnapshot {
    if (-not (Test-Path -LiteralPath $ownerQuestionsPath -PathType Leaf)) {
        throw 'Canonical owner-question file is unavailable; Q-016 cannot be verified.'
    }
    $text = [System.IO.File]::ReadAllText($ownerQuestionsPath)
    $sectionMatches = [regex]::Matches($text, '(?ims)^### Q-016\b(?<section>.*?)(?=^### |\z)')
    if ($sectionMatches.Count -ne 1) {
        throw "Canonical owner-question file must contain exactly one Q-016 section; found $($sectionMatches.Count)."
    }
    $section = '### Q-016' + $sectionMatches[0].Groups['section'].Value
    & git -C $canonicalRepoRoot diff --quiet origin/main -- $ownerQuestionsRelativePath
    if ($LASTEXITCODE -ne 0) {
        throw 'Q-016 owner-question state is not byte-identical to canonical origin/main.'
    }
    $originMainCommit = (& git -C $canonicalRepoRoot rev-parse origin/main).Trim()
    $originBlobSpec = 'origin/main:{0}' -f $ownerQuestionsRelativePath
    $originBlob = (& git -C $canonicalRepoRoot rev-parse $originBlobSpec).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originMainCommit) -or [string]::IsNullOrWhiteSpace($originBlob)) {
        throw 'Could not bind Q-016 to canonical origin/main identity.'
    }
    return [ordered]@{
        answered_a = [bool](Test-Q016ApprovalText -Text $text)
        section_sha256 = Get-StringSha256 -Value $section
        file_sha256 = (Get-FileHash -LiteralPath $ownerQuestionsPath -Algorithm SHA256).Hash
        origin_main_commit = $originMainCommit
        origin_main_blob = $originBlob
        on_origin_main = $true
    }
}


function Assert-Q016ApprovalSnapshot {
    param([string]$ExpectedSectionSha256)
    $snapshot = Get-Q016ApprovalSnapshot
    if (-not $snapshot.answered_a) {
        throw 'Q-016 is not canonically ANSWERED A; no rw06_6 Godot phase is authorized.'
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSectionSha256) -and $snapshot.section_sha256 -ne $ExpectedSectionSha256) {
        throw 'Q-016 changed after authorization was captured; refusing engine launch.'
    }
    return $snapshot
}


function ConvertFrom-LeaseText {
    param([string]$Text)
    $fields = @{}
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [regex]::Split($Text, '\r?\n')) { [void]$lines.Add($line) }
    while ($lines.Count -gt 0 -and [string]::IsNullOrEmpty($lines[$lines.Count - 1])) { $lines.RemoveAt($lines.Count - 1) }
    foreach ($line in $lines) {
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { throw 'Lease file contains a malformed non-field line.' }
        $key = $line.Substring(0, $separator)
        if ($key -cnotmatch '^[a-z_][a-z0-9_]*$' -or $fields.ContainsKey($key)) {
            throw 'Lease file contains an invalid or duplicate field name.'
        }
        $fields[$key] = $line.Substring($separator + 1)
    }
    return $fields
}


function Read-LeaseFields {
    param([string]$Path)
    $readback = Read-NormalFilePinned -Path $Path -IncludeText
    return ConvertFrom-LeaseText -Text ([string]$readback.text)
}


function Assert-OwnedLease {
    param(
        $Receipt,
        [string]$Root,
        [string]$Commit,
        [string]$Tree
    )
    if ($null -eq $Receipt -or -not [bool]$Receipt.atomically_owned -or -not [bool]$Receipt.post_move_identity_verified) {
        throw 'The owned Q-009 lease receipt is absent or malformed.'
    }
    $Path = [string]$Receipt.path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'The owned Q-009 reservation disappeared before launch.'
    }
    $readback = Read-NormalFilePinned -Path $Path -ExpectedIdentity $Receipt.file_identity -IncludeText
    if (
        -not (Test-FileSystemObjectsShareIdentity -Left $Receipt.pre_move_file_identity -Right $Receipt.file_identity) `
        -or [string]$readback.sha256 -cne [string]$Receipt.sha256
    ) { throw 'The owned Q-009 lease file identity or bytes changed.' }
    $fields = ConvertFrom-LeaseText -Text ([string]$readback.text)
    $ownerIdentity = ConvertFrom-ExactLeaseOwnerFields -Fields $fields
    if (
        [string]$ownerIdentity.key -cne [string]$Receipt.owner_identity.key `
        -or -not (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $ownerIdentity)
    ) {
        throw 'The owned Q-009 lease owner PID/start/name/key/executable identity is not this live launcher.'
    }
    if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$fields['worktree']), [System.IO.Path]::GetFullPath($Root), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The owned Q-009 lease worktree does not match the candidate.'
    }
    if ([string]$fields['candidate_commit'] -ne $Commit -or [string]$fields['candidate_tree'] -ne $Tree) {
        throw 'The owned Q-009 lease identity does not match the exact candidate.'
    }
    if ([string]$fields['lease_nonce'] -cne [string]$Receipt.nonce) {
        throw 'The owned Q-009 lease nonce changed.'
    }
    return $true
}


function Assert-NoLivePeerLeaseForWorktree {
    param([object[]]$LeaseRecords, [string]$Root, $OwnedLeaseReceipt = $null)
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
    foreach ($record in @($LeaseRecords)) {
        if ([bool]$record.is_exclusive) { continue }
        $ownerIdentity = ConvertFrom-ExactLeaseOwnerFields -Fields $record.fields
        $liveness = Get-ExactLeaseOwnerLiveness -ExpectedIdentity $ownerIdentity
        if ($liveness -cne 'Live') { throw 'Dead or unverifiable leases must be resolved before same-worktree peer admission.' }
        $recordWorktree = [System.IO.Path]::GetFullPath([string]$record.fields['worktree'])
        if (-not [string]::Equals($recordWorktree, $resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $isOwned = $null -ne $OwnedLeaseReceipt -and (Test-FileSystemObjectsShareIdentity -Left $record.identity -Right $OwnedLeaseReceipt.file_identity)
        if (-not $isOwned) { throw 'A live peer Q-009 lease already reserves this exact candidate worktree.' }
    }
    return $true
}


function New-OwnedLeaseFile {
    param(
        [string]$Path,
        [string]$Root,
        [string]$Commit,
        [string]$Tree,
        [object]$OwnerIdentity,
        [string]$Nonce = '',
        [switch]$ForceWriteFailureForTest,
        [switch]$ForcePartialReplacementForTest,
        [switch]$ForcePostMoveReplacementForTest
    )
    [void](Assert-NormalLeaseRoot -Root ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($Path))))
    if (-not (Test-ExactLeaseOwnerIdentityShape -Identity $OwnerIdentity) -or -not (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $OwnerIdentity)) {
        throw 'Lease creation requires the exact live PID/start/name/key/executable owner identity.'
    }
    if (-not (Test-ExactHexIdentity -Value $Commit -Length 40) -or -not (Test-ExactHexIdentity -Value $Tree -Length 40)) {
        throw 'Lease creation requires exact candidate commit/tree identities.'
    }
    if ([string]::IsNullOrWhiteSpace($Nonce)) { $Nonce = [guid]::NewGuid().ToString('N') }
    if ($Nonce -cnotmatch '^[0-9a-f]{32}$') { throw 'Lease creation nonce is malformed.' }
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $leaseDirectory = [System.IO.Path]::GetDirectoryName($resolvedPath)
    $temporaryPath = Join-Path $leaseDirectory ('.rw06_6-lease-' + $Nonce + '.tmp')
    if ((Test-Path -LiteralPath $resolvedPath) -or (Test-Path -LiteralPath $temporaryPath)) {
        throw 'Lease destination or atomic temporary path already exists.'
    }
    $Text = @(
        'schema=rw06-q009-lease-v2',
        ('pid=' + [string][int]$OwnerIdentity.pid),
        ('owner_name=' + [string]$OwnerIdentity.name),
        ('owner_start_utc=' + [string]$OwnerIdentity.start_utc),
        ('owner_start_ticks=' + [string][long]$OwnerIdentity.start_ticks),
        ('owner_key=' + [string]$OwnerIdentity.key),
        ('owner_executable_path=' + [string]$OwnerIdentity.executable_path),
        ('owner_executable_sha256=' + [string]$OwnerIdentity.executable_sha256),
        ('owner_executable_native_key=' + [string]$OwnerIdentity.executable_identity.native_key),
        ('owner_executable_creation_ticks=' + [string][long]$OwnerIdentity.executable_identity.creation_ticks),
        ('worktree=' + [System.IO.Path]::GetFullPath($Root)),
        ('candidate_commit=' + $Commit.ToLowerInvariant()),
        ('candidate_tree=' + $Tree.ToLowerInvariant()),
        ('lease_nonce=' + $Nonce),
        ('started_utc=' + [DateTime]::UtcNow.ToString('o'))
    ) -join "`n"
    $Text += "`n"
    $stream = $null
    $created = $false
    $moved = $false
    $preMoveIdentity = $null
    try {
        $stream = [System.IO.FileStream]::new($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        $created = $true
        $preMoveIdentity = Get-FileSystemEntryIdentity -Path $temporaryPath
        if ($ForceWriteFailureForTest) {
            throw 'Forced lease write failure for hostile validation.'
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null
        if ($ForcePartialReplacementForTest) {
            [System.IO.File]::Move($temporaryPath, ($temporaryPath + '.owned-original'))
            [System.IO.File]::WriteAllText($temporaryPath, "foreign-partial`n")
            throw 'Forced partial lease replacement for hostile validation.'
        }
        [System.IO.File]::Move($temporaryPath, $resolvedPath)
        $moved = $true
        if ($ForcePostMoveReplacementForTest) {
            [System.IO.File]::Move($resolvedPath, ($resolvedPath + '.owned-original'))
            [System.IO.File]::WriteAllText($resolvedPath, $Text)
        }
        $postMoveIdentity = Get-FileSystemEntryIdentity -Path $resolvedPath
        $sha256 = (Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256).Hash
        if (-not (Test-FileSystemObjectsShareIdentity -Left $preMoveIdentity -Right $postMoveIdentity)) {
            throw 'Lease file identity changed across its atomic move; retaining every object.'
        }
        return [ordered]@{
            path = $resolvedPath
            nonce = $Nonce
            owner_identity = $OwnerIdentity
            candidate_commit = $Commit.ToLowerInvariant()
            candidate_tree = $Tree.ToLowerInvariant()
            pre_move_file_identity = $preMoveIdentity
            file_identity = $postMoveIdentity
            sha256 = $sha256
            atomically_owned = $true
            post_move_identity_verified = $true
        }
    }
    catch {
        if ($null -ne $stream) {
            try { $stream.Dispose() } catch {}
        }
        if ($created -and -not $moved -and $null -ne $preMoveIdentity -and (Test-Path -LiteralPath $temporaryPath -PathType Leaf)) {
            try {
                if (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $preMoveIdentity) {
                    [void](Remove-ExactOwnedFile -Path $temporaryPath -ExpectedIdentity $preMoveIdentity)
                }
            }
            catch {
                # A replacement is deliberately retained. The original failure remains authoritative.
            }
        }
        throw
    }
}


function Remove-OwnedLeaseFile {
    param(
        $Receipt,
        [string]$Root,
        [string]$Commit,
        [string]$Tree,
        [string]$LeaseDirectory = $leaseRoot,
        [switch]$AllowNonCanonicalLeaseRootForTest
    )
    if ($null -eq $Receipt -or -not [bool]$Receipt.atomically_owned -or -not (Test-FileSystemEntryIdentityShape -Identity $Receipt.file_identity)) {
        throw 'Owned lease cleanup requires its sealed creation receipt.'
    }
    if ($AllowNonCanonicalLeaseRootForTest -and -not $ValidateOnly) {
        throw 'Noncanonical owned-lease cleanup is restricted to ValidateOnly hostiles.'
    }
    $resolvedLeaseDirectory = [System.IO.Path]::GetFullPath($LeaseDirectory).TrimEnd([char[]]@([char]'\', [char]'/'))
    [void](Assert-NormalLeaseRoot -Root $resolvedLeaseDirectory -RequireCanonical:(-not $AllowNonCanonicalLeaseRootForTest))
    if ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath([string]$Receipt.path)) -cne $resolvedLeaseDirectory) {
        throw 'Owned lease receipt does not belong to the exact cleanup directory.'
    }
    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @(Get-ChildItem -LiteralPath $resolvedLeaseDirectory -Force -ErrorAction Stop)) {
        if ($item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Lease cleanup encountered an unverifiable object: $($item.FullName)"
        }
        $identity = Get-FileSystemEntryIdentity -Path $item.FullName
        if (Test-FileSystemObjectsShareIdentity -Left $identity -Right $Receipt.file_identity) {
            [void]$matches.Add([ordered]@{ path = [string]$item.FullName; identity = $identity })
        }
    }
    if ($matches.Count -ne 1) {
        throw "Exact owned lease identity was found at $($matches.Count) paths; preserving every lease-root object."
    }
    $match = $matches[0]
    $readback = Read-NormalFilePinned -Path ([string]$match.path) -ExpectedIdentity $match.identity -IncludeText
    if ([string]$readback.sha256 -cne [string]$Receipt.sha256) { throw 'Relocated exact owned lease bytes changed.' }
    $fields = ConvertFrom-LeaseText -Text ([string]$readback.text)
    $ownerIdentity = ConvertFrom-ExactLeaseOwnerFields -Fields $fields
    if (
        (Get-ExactLeaseOwnerLiveness -ExpectedIdentity $ownerIdentity) -cne 'Live' `
        -or [string]$ownerIdentity.key -cne [string]$Receipt.owner_identity.key `
        -or -not [string]::Equals([System.IO.Path]::GetFullPath([string]$fields['worktree']), [System.IO.Path]::GetFullPath($Root), [System.StringComparison]::OrdinalIgnoreCase) `
        -or [string]$fields['candidate_commit'] -cne $Commit `
        -or [string]$fields['candidate_tree'] -cne $Tree `
        -or [string]$fields['lease_nonce'] -cne [string]$Receipt.nonce
    ) { throw 'Relocated exact owned lease metadata no longer binds this live launcher/candidate.' }
    $removal = Remove-ExactOwnedFile -Path ([string]$match.path) -ExpectedIdentity $match.identity -ExpectedSha256 ([string]$Receipt.sha256)
    $removal['original_path_replacement_preserved'] = (Test-Path -LiteralPath ([string]$Receipt.path))
    $removal['located_path'] = [string]$match.path
    return $removal
}


function Test-OwnedLeaseIdentityPresent {
    param($Receipt, [string]$LeaseDirectory = $leaseRoot, [switch]$AllowNonCanonicalLeaseRootForTest)
    if ($null -eq $Receipt -or -not (Test-FileSystemEntryIdentityShape -Identity $Receipt.file_identity)) { return $false }
    if ($AllowNonCanonicalLeaseRootForTest -and -not $ValidateOnly) { throw 'Noncanonical lease identity search is restricted to ValidateOnly hostiles.' }
    $resolvedLeaseDirectory = [System.IO.Path]::GetFullPath($LeaseDirectory).TrimEnd([char[]]@([char]'\', [char]'/'))
    [void](Assert-NormalLeaseRoot -Root $resolvedLeaseDirectory -RequireCanonical:(-not $AllowNonCanonicalLeaseRootForTest))
    foreach ($item in @(Get-ChildItem -LiteralPath $resolvedLeaseDirectory -Force -ErrorAction Stop)) {
        if ($item.PSIsContainer -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $identity = Get-FileSystemEntryIdentity -Path $item.FullName
        if (Test-FileSystemObjectsShareIdentity -Left $identity -Right $Receipt.file_identity) { return $true }
    }
    return $false
}


function Restore-ProcessEnvironmentSafely {
    param(
        [System.Collections.IDictionary]$Snapshot,
        [switch]$ForceFailureForTest
    )
    try {
        if ($ForceFailureForTest) {
            throw 'Forced environment restoration failure for hostile validation.'
        }
        foreach ($entry in $Snapshot.GetEnumerator()) {
            if ($null -eq $entry.Value) {
                [Environment]::SetEnvironmentVariable([string]$entry.Key, $null, 'Process')
            }
            else {
                [Environment]::SetEnvironmentVariable([string]$entry.Key, [string]$entry.Value, 'Process')
            }
        }
        return [ordered]@{ succeeded = $true; error = '' }
    }
    catch {
        return [ordered]@{ succeeded = $false; error = $_.Exception.Message }
    }
}


function Invoke-GodotPhase {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$Root,
        [string]$RequiredCommit,
        [string]$RequiredTree,
        $OwnedLeaseReceipt,
        [string]$Q016SectionSha256,
        [string]$PhaseEvidenceRoot,
        $EvidenceReceipt,
        $CounterpartAdmissionReceipt,
        [string]$RequiredGodotSha256,
        [string]$RequiredGodotVersion,
        [int]$TimeoutSec,
        $OwnedCreationState = $null,
        [object[]]$RequiredInputReceipts = @(),
        [object[]]$TrackedInputReceipts = @(),
        [string]$AdditionalOutputPath = ''
    )
    $phaseDirectoryReceipt = New-OwnedEvidenceSubdirectory -EvidenceReceipt $EvidenceReceipt -DestinationPath $PhaseEvidenceRoot
    $stdoutPath = Join-Path $PhaseEvidenceRoot 'stdout.log'
    $stderrPath = Join-Path $PhaseEvidenceRoot 'stderr.log'
    $godotLogPath = Join-Path $PhaseEvidenceRoot 'godot.log'
    $stdoutReservation = New-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -DestinationPath $stdoutPath
    $stderrReservation = New-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -DestinationPath $stderrPath
    $godotLogReservation = New-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -DestinationPath $godotLogPath
    $additionalOutputReservation = $null
    if (-not [string]::IsNullOrWhiteSpace($AdditionalOutputPath)) {
        $additionalOutputReservation = New-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -DestinationPath $AdditionalOutputPath
    }
    $phaseArguments = @('--log-file', $godotLogPath) + @($Arguments)
    $started = $null
    $baselineGodotRecords = @()
    $baselineGodotIdentityKeys = @()
    $startError = ''
    $preLaunchDependencyCensus = [ordered]@{}
    $ownedCreationProof = if ($null -ne $OwnedCreationState) { $OwnedCreationState } else { New-OwnedCreationState -Path '' }
    $startProof = [ordered]@{
        started = $false
        process_id = 0
        process_identity = $null
        provenance = 'none'
    }
    $mutex = [System.Threading.Mutex]::new($false, $launchMutexName)
    $mutexOwned = $false
    try {
        $mutexOwned = $mutex.WaitOne(5000)
        if (-not $mutexOwned) {
            throw 'Could not acquire the Q-009 launch lock for final identity and capacity checks.'
        }
        # This is intentionally the first candidate operation after acquiring
        # the launch lock for every phase.
        [void](Assert-CleanExactCandidate $Root $RequiredCommit $RequiredTree)
        [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $Q016SectionSha256)
        [void](Assert-CounterpartAdmissionReceiptStable -Receipt $CounterpartAdmissionReceipt)
        [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $EvidenceReceipt -Receipt $phaseDirectoryReceipt)
        foreach ($requiredInput in @($RequiredInputReceipts)) {
            [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $EvidenceReceipt -Receipt $requiredInput)
        }
        foreach ($trackedInput in @($TrackedInputReceipts)) {
            [void](Assert-TrackedFileIdentityStable -Root $Root -Commit $RequiredCommit -Receipt $trackedInput)
        }
        [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $EvidenceReceipt -AllowReservedFiles)
        $phaseGodotIdentity = Get-CanonicalGodotIdentity -RequestedPath $GodotPath -RequiredSha256 $RequiredGodotSha256 -RequiredVersion $RequiredGodotVersion
        Clear-StaleGodotLeases
        $leaseRecords = @(Get-StrictLeaseEntryRecords -Root $leaseRoot -RequireCanonical)
        [void](Assert-NoLivePeerLeaseForWorktree -LeaseRecords $leaseRecords -Root $Root -OwnedLeaseReceipt $OwnedLeaseReceipt)
        $exclusiveRecords = @($leaseRecords | Where-Object { [bool]$_.is_exclusive })
        $focusedReservations = @($leaseRecords | Where-Object { -not [bool]$_.is_exclusive })
        $preLaunchGodotProcesses = @(Get-LiveGodotProcesses)
        $unleasedGodotRecords = @(Get-NewUnownedGodotRecords -BaselineKeys @())
        [void](Assert-OwnedLease -Receipt $OwnedLeaseReceipt -Root $Root -Commit $RequiredCommit -Tree $RequiredTree)
        if (
            $exclusiveRecords.Count -ne 1 `
            -or -not (Test-FileSystemObjectsShareIdentity -Left $exclusiveRecords[0].identity -Right $OwnedLeaseReceipt.file_identity)
        ) { throw 'The sole Q-009 EXCLUSIVE.lease is not this exact launcher reservation.' }
        if ($focusedReservations.Count -ne 0) { throw 'A focused lease remained while the rw06_6 exclusive reservation was active.' }
        if ($unleasedGodotRecords.Count -gt 0) { throw 'An unleased Godot process exists; refusing rw06_6 launch.' }
        if ($preLaunchGodotProcesses.Count -ne 0) { throw 'Serialized rw06_6 launch requires zero pre-existing Godot processes.' }
        $baselineGodotRecords = @(Get-LiveGodotIdentityRecords)
        $baselineGodotIdentityKeys = @($baselineGodotRecords | ForEach-Object { [string]$_.key })
        if ($Name -in @('cache_ownership', 'global_class_registration')) {
            $preLaunchDependencyCensus = Get-RecoveryBootstrapDependencyCensus -Root $Root -InventoryMode EngineVisible
            if (-not (Test-RecoveryBootstrapDependencyCensus -Census $preLaunchDependencyCensus)) {
                throw 'Recovery-mode registry launch-lock dependency census rejected an engine-visible tracked, ignored, untracked, executable, addon, plugin, @tool, autoload, editor-plugin, or reparse hazard.'
            }
            if ($Name -eq 'cache_ownership') {
                Assert-ProjectCacheAbsent -Context 'RW06_6 cache-owner launch-lock preflight'
                $ownedCreationProof = Initialize-ExclusiveOwnedCacheRoot -State $ownedCreationProof
                $started = Start-RedirectedProcess -FilePath $GodotPath -Arguments $phaseArguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys -TimeoutSec $TimeoutSec -OwnedCreationPath $projectCacheRoot -OwnedCreationState $ownedCreationProof -ExpectedExecutableReceipt $phaseGodotIdentity.launch_receipt -StdoutReceipt $stdoutReservation -StderrReceipt $stderrReservation
            }
            else {
                [void](Assert-OwnedCreationStateStable -State $ownedCreationProof)
                $started = Start-RedirectedProcess -FilePath $GodotPath -Arguments $phaseArguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys -TimeoutSec $TimeoutSec -OwnedCreationState $ownedCreationProof -ExpectedExecutableReceipt $phaseGodotIdentity.launch_receipt -StdoutReceipt $stdoutReservation -StderrReceipt $stderrReservation
            }
        }
        else {
            if ($null -ne $OwnedCreationState) {
                [void](Assert-OwnedCreationStateStable -State $ownedCreationProof)
                $started = Start-RedirectedProcess -FilePath $GodotPath -Arguments $phaseArguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys -TimeoutSec $TimeoutSec -OwnedCreationState $ownedCreationProof -ExpectedExecutableReceipt $phaseGodotIdentity.launch_receipt -StdoutReceipt $stdoutReservation -StderrReceipt $stderrReservation
            }
            else {
                $started = Start-RedirectedProcess -FilePath $GodotPath -Arguments $phaseArguments -StdoutPath $stdoutPath -StderrPath $stderrPath -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys -TimeoutSec $TimeoutSec -ExpectedExecutableReceipt $phaseGodotIdentity.launch_receipt -StdoutReceipt $stdoutReservation -StderrReceipt $stderrReservation
            }
        }
        if ($Name -eq 'cache_ownership' -and $null -ne $started) {
            $ownedCreationProof = Complete-OwnedCacheCreationHandshake -State $ownedCreationProof -Started $started -ExpectedCommit $RequiredCommit -ExpectedTree $RequiredTree -TimeoutSec ([Math]::Min(15, $TimeoutSec))
            $started.owned_creation_state = $ownedCreationProof
        }
    }
    catch {
        $startError = $_.Exception.Message
        $startProof = Get-OwnedProcessStartProofFromException -Exception $_.Exception
        if ($_.Exception.Data.Contains('owned_creation_state')) {
            $ownedCreationProof = $_.Exception.Data['owned_creation_state']
        }
    }
    finally {
        if ($mutexOwned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }

    if ($null -eq $started) {
        [System.IO.File]::AppendAllText($stderrPath, $startError + [Environment]::NewLine)
        $processResult = [ordered]@{
            process_started = [bool]$startProof.started
            process_start_provenance = [string]$startProof.provenance
            native_exit_code = [int]$nativeExitSentinel
            native_exit_observed = $false
            native_exit_type = ''
            effective_exit_code = 125
            timed_out = $false
            elapsed_seconds = 0.0
            process_id = [int]$startProof.process_id
            started_utc = if ([bool]$startProof.started) { [string]$startProof.process_identity.start_utc } else { '' }
            process_identity = $startProof.process_identity
            retained_descendant_identities = @()
            job_custody = $null
            job_empty = [bool]$startProof.job_cleanup_proven
            owned_creation = $ownedCreationProof
            error = $startError
        }
    }
    else {
        $processResult = Complete-RedirectedProcess -Started $started -TimeoutSec $TimeoutSec -ProcessKind Godot -BaselineGodotIdentityKeys $baselineGodotIdentityKeys
        if (-not [string]::IsNullOrWhiteSpace($startError)) {
            if ([string]::IsNullOrWhiteSpace([string]$processResult.error)) { $processResult.error = $startError }
            else { $processResult.error = $startError + ' | ' + [string]$processResult.error }
            $processResult.effective_exit_code = 125
        }
    }
    if ($null -ne $OwnedCreationState -and $Name -ne 'cache_ownership') {
        [void](Assert-OwnedCreationStateStable -State $ownedCreationProof)
    }

    $ownedResidualPids = @()
    if (-not [bool]$processResult.job_empty) {
        if ($null -ne $started) { $ownedResidualPids = @($processResult.job_members_after_termination) }
        elseif ([bool]$startProof.started) { $ownedResidualPids = @($startProof.job_members_after_cleanup) }
        $residualError = 'Exact job was not proven empty after completion/setup failure: ' + ($ownedResidualPids -join ',')
        if ([string]::IsNullOrWhiteSpace([string]$processResult.error)) { $processResult.error = $residualError }
        else { $processResult.error = [string]$processResult.error + ' | ' + $residualError }
        $processResult.effective_exit_code = 125
    }

    $stdoutFinal = Complete-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -Receipt $stdoutReservation -IncludeText
    $stderrFinal = Complete-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -Receipt $stderrReservation -IncludeText
    $godotLogFinal = Complete-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -Receipt $godotLogReservation -IncludeText
    $additionalOutputFinal = $null
    if ($null -ne $additionalOutputReservation) {
        $additionalOutputFinal = Complete-OwnedEvidenceFileReservation -EvidenceReceipt $EvidenceReceipt -Receipt $additionalOutputReservation -IncludeText
    }
    $stdoutText = [string]$stdoutFinal.text
    $stderrText = [string]$stderrFinal.text
    $godotLogText = [string]$godotLogFinal.text
    $combinedText = "`n--- stdout.log ---`n$stdoutText`n--- stderr.log ---`n$stderrText`n--- godot.log ---`n$godotLogText"
    $diagnostics = @(Get-DiagnosticLines -Text $combinedText)
    $registryLifecycle = Get-RegistryLifecycleEvidence -StdoutText $stdoutText -StderrText $stderrText -GodotLogText $godotLogText
    $hashes = [ordered]@{
        'stdout.log' = [string]$stdoutReservation.sha256
        'stderr.log' = [string]$stderrReservation.sha256
        'godot.log' = [string]$godotLogReservation.sha256
    }
    $ownedCreationEvidenceSummary = Get-OwnedCreationEvidenceSummary -State $processResult.owned_creation
    return [ordered]@{
        name = $Name
        command = $GodotPath
        arguments = $phaseArguments
        process_started = [bool]$processResult.process_started
        process_start_provenance = [string]$processResult.process_start_provenance
        native_exit_code = $processResult.native_exit_code
        native_exit_observed = [bool]$processResult.native_exit_observed
        native_exit_type = $processResult.native_exit_type
        effective_exit_code = [int]$processResult.effective_exit_code
        timed_out = [bool]$processResult.timed_out
        elapsed_seconds = $processResult.elapsed_seconds
        process_id = $processResult.process_id
        started_utc = $processResult.started_utc
        process_identity = $processResult.process_identity
        retained_descendant_identities = @($processResult.retained_descendant_identities)
        job_custody = $processResult.job_custody
        job_empty = [bool]$processResult.job_empty
        launcher_error = $processResult.error
        baseline_godot = @($baselineGodotRecords)
        owned_residual_process_ids = @($ownedResidualPids)
        product_red_marker = $combinedText.Contains('RW06_6_PRODUCT_RED')
        guard_pass_marker = $combinedText.Contains('RW06_6_GUARD_PASS')
        infra_failure_marker = $combinedText.Contains('RW06_6_GUARD_INFRA_FAILURE')
        cache_owner_pass_marker = $combinedText.Contains('RW06_6_CACHE_OWNER_PASS')
        full_pass_marker = $combinedText.Contains('RW06_6_PULL_TAB_GLIMMER PASS')
        foundation_pass_marker = [regex]::IsMatch($combinedText, '(?m)^Foundation Godot checks passed\. suite=pull_tabs checks=2 report=.+$')
        foundation_pull_tabs_done_marker = [regex]::IsMatch($combinedText, '(?m)^FOUNDATION_CHECK_DONE id=pull_tabs_game_suite duration_msec=\d+ failures=0\s*$')
        foundation_done_count = [regex]::Matches($combinedText, '(?m)^FOUNDATION_CHECK_DONE id=(?:content|pull_tabs_game_suite) duration_msec=\d+ failures=0\s*$').Count
        diagnostics_clean = ($diagnostics.Count -eq 0)
        diagnostics = $diagnostics
        registry_lifecycle = $registryLifecycle
        prelaunch_dependency_census = $preLaunchDependencyCensus
        cache_creation_custody = $ownedCreationEvidenceSummary
        # Internal runtime transport only. This raw state can contain a live
        # SafeFileHandle and is stripped from every phase before evidence seal.
        owned_creation = $processResult.owned_creation
        godot_identity = $phaseGodotIdentity
        evidence_root = $PhaseEvidenceRoot
        evidence_directory_receipt = $phaseDirectoryReceipt
        output_receipts = @($stdoutReservation, $stderrReservation, $godotLogReservation)
        stdout_text = $stdoutText
        stderr_text = $stderrText
        godot_log_text = $godotLogText
        additional_output_receipt = $additionalOutputReservation
        additional_output_text = if ($null -eq $additionalOutputFinal) { '' } else { [string]$additionalOutputFinal.text }
        sha256 = $hashes
    }
}


function Test-FileSystemObjectsShareIdentity {
    param($Left, $Right)
    return (
        (Test-FileSystemEntryIdentityShape -Identity $Left) `
        -and (Test-FileSystemEntryIdentityShape -Identity $Right) `
        -and [string]$Left.native_key -ceq [string]$Right.native_key `
        -and [bool]$Left.is_directory -eq [bool]$Right.is_directory `
        -and [long]$Left.creation_ticks -eq [long]$Right.creation_ticks
    )
}


function Get-ExactOwnedTreeManifest {
    param([string]$RootPath)
    $resolvedRoot = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([char[]]@([char]'\', [char]'/'))
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Exact owned tree root is unavailable: $resolvedRoot"
    }
    $rootIdentity = Get-FileSystemEntryIdentity -Path $resolvedRoot
    if (-not [bool]$rootIdentity.is_directory) { throw 'Exact owned tree root is not a directory.' }
    $entries = [System.Collections.Generic.List[object]]::new()
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($resolvedRoot)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop | Sort-Object FullName)) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Exact owned tree contains a reparse point: $($item.FullName)"
            }
            $identity = Get-FileSystemEntryIdentity -Path $item.FullName
            $relativePath = $item.FullName.Substring($resolvedRoot.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
            $entries.Add([ordered]@{
                path = $relativePath
                native_key = [string]$identity.native_key
                creation_ticks = [long]$identity.creation_ticks
                is_directory = [bool]$identity.is_directory
            })
            if ($item.PSIsContainer) { $stack.Push($item.FullName) }
        }
    }
    $orderedEntries = @($entries | Sort-Object path)
    $payload = [ordered]@{
        root_native_key = [string]$rootIdentity.native_key
        root_creation_ticks = [long]$rootIdentity.creation_ticks
        entries = $orderedEntries
    }
    return [ordered]@{
        root_identity = $rootIdentity
        entries = $orderedEntries
        sha256 = Get-StringSha256 -Value (($payload | ConvertTo-Json -Depth 6 -Compress))
    }
}


function Remove-ExactOwnedDirectoryTree {
    param(
        [string]$OwnedPath,
        [string]$QuarantinePath,
        $ExpectedRootIdentity,
        [switch]$ForceQuarantineReplacementForTest
    )
    $resolvedOwned = [System.IO.Path]::GetFullPath($OwnedPath).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedQuarantine = [System.IO.Path]::GetFullPath($QuarantinePath).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ([System.IO.Path]::GetDirectoryName($resolvedOwned) -cne [System.IO.Path]::GetDirectoryName($resolvedQuarantine)) {
        throw 'Exact owned tree quarantine must be a same-directory atomic rename.'
    }
    if (-not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $ExpectedRootIdentity)) {
        throw 'Exact owned tree root was replaced before quarantine.'
    }
    if (Test-Path -LiteralPath $resolvedQuarantine) {
        throw "Exact owned tree quarantine destination already exists: $resolvedQuarantine"
    }
    $manifest = Get-ExactOwnedTreeManifest -RootPath $resolvedOwned
    if (-not (Test-FileSystemObjectsShareIdentity -Left $ExpectedRootIdentity -Right $manifest.root_identity)) {
        throw 'Exact owned tree root changed while its deletion manifest was captured.'
    }
    [System.IO.Directory]::Move($resolvedOwned, $resolvedQuarantine)
    $quarantineIdentity = Get-FileSystemEntryIdentity -Path $resolvedQuarantine
    if (-not (Test-FileSystemObjectsShareIdentity -Left $ExpectedRootIdentity -Right $quarantineIdentity)) {
        throw 'Atomically quarantined tree is not the exact owned root; refusing deletion.'
    }
    if ($ForceQuarantineReplacementForTest) {
        $forcedOriginalPath = $resolvedQuarantine + '.forced-owned-original'
        if (Test-Path -LiteralPath $forcedOriginalPath) {
            throw 'Forced quarantine-race original path unexpectedly exists.'
        }
        [System.IO.Directory]::Move($resolvedQuarantine, $forcedOriginalPath)
        [void][System.IO.Directory]::CreateDirectory($resolvedQuarantine)
        [System.IO.File]::WriteAllText((Join-Path $resolvedQuarantine 'foreign-replacement.txt'), "foreign`n")
    }
    Initialize-Rw06NativeFileIdentityType
    $relativePaths = [string[]]@($manifest.entries | ForEach-Object { [string]$_.path })
    $nativeKeys = [string[]]@($manifest.entries | ForEach-Object { [string]$_.native_key })
    $creationTicks = [long[]]@($manifest.entries | ForEach-Object { [long]$_.creation_ticks })
    $directories = [bool[]]@($manifest.entries | ForEach-Object { [bool]$_.is_directory })
    [Rw06FileIdentityNative]::DeleteTreeExact(
        $resolvedQuarantine,
        [string]$quarantineIdentity.native_key,
        [long]$quarantineIdentity.creation_ticks,
        $relativePaths,
        $nativeKeys,
        $creationTicks,
        $directories
    )
    if (Test-Path -LiteralPath $resolvedOwned) {
        throw 'A new object appeared at the original exact owned tree path during cleanup.'
    }
    if (Test-Path -LiteralPath $resolvedQuarantine) {
        throw 'Handle-bound exact owned tree quarantine remained after deletion.'
    }
    return [ordered]@{
        removed = $true
        original_path_absent = $true
        quarantine_path = $resolvedQuarantine
        quarantine_absent = $true
        root_identity = $quarantineIdentity
        manifest_sha256 = [string]$manifest.sha256
        entry_count = @($manifest.entries).Count
        handle_bound = $true
    }
}


function Remove-ExactOwnedDirectoryTreeThroughCreationGuard {
    param(
        $State,
        [string]$QuarantinePath,
        [switch]$ForceQuarantineDestinationPrecreationForTest,
        [switch]$ForceCheckedCloseReportedFailureForTest
    )
    if ($null -eq $State -or $null -eq $State.root_guard_owner -or -not [bool]$State.root_guard_owner.GuardLive) {
        throw 'Guarded exact owned cache cleanup requires its one live creation/custody owner.'
    }
    if ([string]$State.custody_transition -cne 'creator_bound' -or [int]$State.custody_release_count -ne 0) {
        throw 'Guarded exact owned cache cleanup rejected an invalid custody transition or prior release.'
    }
    $resolvedOwned = [System.IO.Path]::GetFullPath([string]$State.path).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedQuarantine = [System.IO.Path]::GetFullPath($QuarantinePath).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ([System.IO.Path]::GetDirectoryName($resolvedOwned) -cne [System.IO.Path]::GetDirectoryName($resolvedQuarantine)) {
        throw 'Guarded exact owned cache quarantine must be a same-directory atomic rename.'
    }
    if (Test-Path -LiteralPath $resolvedQuarantine) {
        throw "Guarded exact owned cache quarantine destination already exists: $resolvedQuarantine"
    }
    [void]([Rw06FileIdentityNative]::AssertDirectoryGuardIdentity(
        $State.root_guard_owner,
        [string]$State.entry_identity.native_key,
        [long]$State.entry_identity.creation_ticks,
        $resolvedOwned
    ))
    $manifest = Get-ExactOwnedTreeManifest -RootPath $resolvedOwned
    if (-not (Test-FileSystemObjectsShareIdentity -Left $State.entry_identity -Right $manifest.root_identity)) {
        throw 'Guarded exact owned cache root changed while its final deletion manifest was captured.'
    }
    if ($ForceQuarantineDestinationPrecreationForTest) {
        [void][System.IO.Directory]::CreateDirectory($resolvedQuarantine)
        [System.IO.File]::WriteAllText((Join-Path $resolvedQuarantine 'foreign-destination.txt'), "foreign`n")
    }
    try {
        $nativeRename = [Rw06FileIdentityNative]::RenameDirectoryGuardExact(
            $State.root_guard_owner,
            $resolvedOwned,
            $resolvedQuarantine,
            [string]$State.entry_identity.native_key,
            [long]$State.entry_identity.creation_ticks
        )
        $State.quarantine_path = $resolvedQuarantine
        $State.quarantine_identity = [ordered]@{
            path = $resolvedQuarantine
            native_key = [string]$nativeRename.NativeKey
            is_directory = $true
            creation_ticks = [long]$nativeRename.CreationTicks
            reparse_point = $false
            key = ('{0}|{1}|directory' -f [string]$nativeRename.NativeKey, [long]$nativeRename.CreationTicks)
        }
        $State.quarantine_rename_receipt = [ordered]@{
            source_path = [string]$nativeRename.SourcePath
            destination_path = [string]$nativeRename.DestinationPath
            native_key = [string]$nativeRename.NativeKey
            creation_ticks = [long]$nativeRename.CreationTicks
            same_creation_custody_handle = [bool]$nativeRename.SameHandle
            no_replace = [bool]$nativeRename.NoReplace
            original_absent = [bool]$nativeRename.OriginalAbsent
            destination_identity_verified = [bool]$nativeRename.DestinationIdentityVerified
            renamed_utc = [string]$nativeRename.RenamedUtc
        }
        $State.custody_transition = 'quarantined'
        $relativePaths = [string[]]@($manifest.entries | ForEach-Object { [string]$_.path })
        $nativeKeys = [string[]]@($manifest.entries | ForEach-Object { [string]$_.native_key })
        $creationTicks = [long[]]@($manifest.entries | ForEach-Object { [long]$_.creation_ticks })
        $directories = [bool[]]@($manifest.entries | ForEach-Object { [bool]$_.is_directory })
        $nativeClose = [Rw06FileIdentityNative]::DeleteTreeExactThroughGuard(
            $State.root_guard_owner,
            $resolvedQuarantine,
            [string]$State.quarantine_identity.native_key,
            [long]$State.quarantine_identity.creation_ticks,
            $relativePaths,
            $nativeKeys,
            $creationTicks,
            $directories,
            [bool]$ForceCheckedCloseReportedFailureForTest
        )
        $State.custody_release_receipt = ConvertTo-DirectoryGuardCloseEvidence -CloseReceipt $nativeClose
        $State.custody_release_count = 1
        $State.custody_transition = 'deleted_closed'
    }
    catch {
        $owner = $State.root_guard_owner
        if ([bool]$owner.RenamedThroughGuard -and [string]::IsNullOrWhiteSpace([string]$State.quarantine_path)) {
            $State.quarantine_path = [string]$owner.CurrentPath
            $State.quarantine_identity = [ordered]@{
                path = [string]$owner.CurrentPath
                native_key = [string]$owner.CreationNativeKey
                is_directory = $true
                creation_ticks = [long]$owner.CreationTicks
                reparse_point = $false
                key = ('{0}|{1}|directory' -f [string]$owner.CreationNativeKey, [long]$owner.CreationTicks)
            }
            $State.custody_transition = 'quarantined'
        }
        if ($null -ne $owner.CloseReceipt -and [int]$State.custody_release_count -eq 0) {
            $State.custody_release_receipt = ConvertTo-DirectoryGuardCloseEvidence -CloseReceipt $owner.CloseReceipt
            $State.custody_release_count = 1
            $State.custody_transition = if ([bool]$owner.NativeCloseSucceeded) { 'deleted_closed_reported_failure' } else { 'deleted_close_native_failure' }
        }
        $_.Exception.Data['owned_creation_state'] = $State
        throw
    }
    if (Test-Path -LiteralPath $resolvedOwned) {
        throw 'A new object appeared at the original guarded cache path during cleanup.'
    }
    if (Test-Path -LiteralPath $resolvedQuarantine) {
        throw 'Guarded exact owned cache quarantine remained after deletion and checked close.'
    }
    return [ordered]@{
        removed = $true
        original_path_absent = $true
        quarantine_path = $resolvedQuarantine
        quarantine_absent = $true
        root_identity = $State.quarantine_identity
        rename_receipt = $State.quarantine_rename_receipt
        close_receipt = $State.custody_release_receipt
        manifest_sha256 = [string]$manifest.sha256
        entry_count = @($manifest.entries).Count
        handle_bound = $true
        same_creation_custody_handle = $true
    }
}


function Remove-DedicatedProjectCache {
    param(
        [string]$Root,
        [string]$CacheRoot,
        $OwnedCreationProof,
        [switch]$ForceQuarantineDestinationPrecreationForTest,
        [switch]$ForceCheckedCloseReportedFailureForTest
    )
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedCache = [System.IO.Path]::GetFullPath($CacheRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    $expectedCache = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot '.godot')).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ($resolvedCache -ne $expectedCache -or -not $resolvedCache.StartsWith($resolvedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove unexpected cache path: $resolvedCache"
    }
    if (-not (Test-Path -LiteralPath $resolvedCache)) {
        return [ordered]@{ removed = $false; absent = $true; quarantine_path = ''; identity_verified = $false }
    }
    if (-not (Test-OwnedCreationStateProof -State $OwnedCreationProof)) {
        throw 'Refusing to remove a cache without an exact owned creation/claim proof.'
    }
    [void](Assert-OwnedCreationStateStable -State $OwnedCreationProof)
    if ([string]$OwnedCreationProof.entry_identity.path -cne $resolvedCache) {
        throw 'Owned cache proof path does not equal the dedicated project cache path.'
    }
    if (-not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $OwnedCreationProof.entry_identity) -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $OwnedCreationProof.claim_identity)) {
        throw 'Refusing to remove a cache whose exact directory or claim identity was replaced.'
    }
    $claimReadback = Read-NormalFilePinned -Path ([string]$OwnedCreationProof.claim_path) -ExpectedIdentity $OwnedCreationProof.claim_identity
    if ([string]$claimReadback.sha256 -cne [string]$OwnedCreationProof.claim_sha256) {
        throw 'Refusing to remove a cache whose ownership claim bytes changed.'
    }
    $quarantinePath = Join-Path $resolvedRoot ('.rw06_6-cache-quarantine-' + [string]$OwnedCreationProof.nonce)
    $deleteReceipt = Remove-ExactOwnedDirectoryTreeThroughCreationGuard -State $OwnedCreationProof -QuarantinePath $quarantinePath -ForceQuarantineDestinationPrecreationForTest:$ForceQuarantineDestinationPrecreationForTest -ForceCheckedCloseReportedFailureForTest:$ForceCheckedCloseReportedFailureForTest
    return [ordered]@{
        removed = [bool]$deleteReceipt.removed
        absent = -not (Test-Path -LiteralPath $resolvedCache)
        quarantine_path = $quarantinePath
        quarantine_absent = -not (Test-Path -LiteralPath $quarantinePath)
        identity_verified = [bool]$deleteReceipt.handle_bound
        cache_identity = $deleteReceipt.root_identity
        claim_identity = $OwnedCreationProof.claim_identity
        tree_manifest_sha256 = [string]$deleteReceipt.manifest_sha256
        deleted_entry_count = [int]$deleteReceipt.entry_count
        handle_bound = [bool]$deleteReceipt.handle_bound
        same_creation_custody_handle = [bool]$deleteReceipt.same_creation_custody_handle
        rename_receipt = $deleteReceipt.rename_receipt
        custody_release_receipt = $deleteReceipt.close_receipt
    }
}


function Assert-ProjectCacheAbsent {
    param([string]$Context)
    if (Test-Path -LiteralPath $projectCacheRoot) {
        throw "$Context requires candidate-local .godot, class, UID, and imported artifacts to be absent."
    }
}


function Assert-ProjectCacheIgnored {
    foreach ($probe in @('.godot/global_script_class_cache.cfg', '.godot/uid_cache.bin', '.godot/imported/rw06_6-probe.ctex')) {
        & git -C $projectRoot check-ignore -q -- $probe
        if ($LASTEXITCODE -ne 0) {
            throw "Candidate-local registry artifact is not git-ignored: $probe"
        }
    }
}


function Assert-RequiredGlobalClassEntries {
    param([string]$CachePath)
    $cacheText = [System.IO.File]::ReadAllText($CachePath)
    $requiredEntries = [ordered]@{
        RunState = 'res://scripts/core/run_state.gd'
        ContentLibrary = 'res://scripts/core/content_library.gd'
        GameModule = 'res://scripts/core/game_module.gd'
        RngStream = 'res://scripts/core/rng_stream.gd'
        PullTabsGame = 'res://scripts/games/pull_tabs.gd'
    }
    foreach ($className in $requiredEntries.Keys) {
        $escapedClass = [regex]::Escape([string]$className)
        $escapedPath = [regex]::Escape([string]$requiredEntries[$className])
        $pattern = '(?s)"class"\s*:\s*&?"' + $escapedClass + '".{0,1200}?"path"\s*:\s*"' + $escapedPath + '"'
        if (-not [regex]::IsMatch($cacheText, $pattern)) {
            throw "Global class cache lacks exact class/path entry: $className -> $($requiredEntries[$className])"
        }
    }
}


function Write-ImportedArtifactManifest {
    param([string]$DestinationPath, $EvidenceReceipt)
    if (-not (Test-Path -LiteralPath $importedRoot -PathType Container)) {
        throw 'Godot registry import produced no canonical .godot/imported directory.'
    }
    $importedItem = Get-Item -LiteralPath $importedRoot -Force
    if (($importedItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Godot registry import produced a reparse-point imported directory.'
    }
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($file in (Get-ChildItem -LiteralPath $importedRoot -File -Recurse -Force | Sort-Object FullName)) {
        $relativePath = $file.FullName.Substring($projectCacheRoot.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
        $entries.Add([ordered]@{
            path = $relativePath
            length = [long]$file.Length
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        })
    }
    if ($entries.Count -eq 0) {
        throw 'Godot registry import produced an empty canonical imported-artifact census.'
    }
    $manifest = [ordered]@{
        root = '.godot/imported'
        count = $entries.Count
        files = @($entries)
    }
    $seal = Write-AtomicSealedText -EvidenceReceipt $EvidenceReceipt -DestinationPath $DestinationPath -Text (($manifest | ConvertTo-Json -Depth 6) + "`n")
    return [ordered]@{
        count = $entries.Count
        path = $DestinationPath
        sha256 = [string]$seal.sha256
        atomic_no_overwrite = [bool]$seal.atomic_no_overwrite
        readback_verified = [bool]$seal.readback_verified
        identity = $seal.identity
    }
}


function Get-RetainedArtifactEntries {
    param($EvidenceReceipt, [string[]]$ExcludeRelativePaths = @())
    [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt)
    $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $ExcludeRelativePaths) { [void]$excluded.Add(([string]$path).Replace('\', '/')) }
    $entries = [System.Collections.Generic.List[object]]::new()
    $root = [System.IO.Path]::GetFullPath([string]$EvidenceReceipt.root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop | Sort-Object FullName)) {
            $relativePath = $item.FullName.Substring($root.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
            if ($excluded.Contains($relativePath)) { continue }
            $isReparse = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
            $isDirectory = (($item.Attributes -band [System.IO.FileAttributes]::Directory) -ne 0)
            $identity = Get-FileSystemEntryIdentity -Path $item.FullName -AllowReparse:$isReparse
            $entryType = if ($isReparse) {
                if ($isDirectory) { 'reparse_directory' } else { 'reparse_file' }
            }
            elseif ($isDirectory) { 'directory' }
            else { 'file' }
            $entries.Add([ordered]@{
                path = $relativePath
                entry_type = $entryType
                reparse_point = [bool]$isReparse
                length = if ($isDirectory) { [long]0 } else { [long]$item.Length }
                sha256 = if ($isDirectory -or $isReparse) { '' } else { (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash }
                identity = $identity
            })
            # Reparse directories are objects in the exact tree, never traversal roots.
            if ($isDirectory -and -not $isReparse) { $stack.Push($item.FullName) }
        }
    }
    return @($entries | Sort-Object path)
}


function Test-ExactRetainedArtifactSet {
    param($EvidenceReceipt, [string[]]$ExpectedRelativePaths)
    [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt)
    $actual = @(Get-RetainedArtifactEntries -EvidenceReceipt $EvidenceReceipt | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
    $expected = @($ExpectedRelativePaths | ForEach-Object { ([string]$_).Replace('\', '/') } | Sort-Object -Unique)
    if ($actual.Count -ne $expected.Count) { return $false }
    for ($index = 0; $index -lt $expected.Count; $index += 1) {
        if ($actual[$index] -cne $expected[$index]) { return $false }
    }
    return $true
}


function Test-RetainedArtifactIntegrity {
    param(
        $EvidenceReceipt,
        [object[]]$ExpectedEntries,
        [string[]]$ExpectedRelativePaths
    )
    [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt)
    if (-not (Test-ExactRetainedArtifactSet -EvidenceReceipt $EvidenceReceipt -ExpectedRelativePaths $ExpectedRelativePaths)) {
        return $false
    }
    if ($ExpectedEntries.Count -ne $ExpectedRelativePaths.Count) { return $false }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $ExpectedEntries) {
        if ($null -eq $entry) { return $false }
        foreach ($requiredKey in @('path', 'entry_type', 'reparse_point', 'length', 'sha256', 'identity')) {
            if (-not $entry.Contains($requiredKey)) { return $false }
        }
        $relativePath = ([string]$entry.path).Replace('\', '/')
        if ([string]::IsNullOrWhiteSpace($relativePath) -or -not $seen.Add($relativePath)) { return $false }
        $fullPath = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path (Join-Path ([string]$EvidenceReceipt.root) ($relativePath.Replace('/', '\')))
        try { $identity = Get-FileSystemEntryIdentity -Path $fullPath } catch { return $false }
        $isReparse = [bool]$identity.reparse_point
        $isDirectory = [bool]$identity.is_directory
        # Reparse objects are enumerated into the exact set rather than hidden by
        # a -File filter, but they are never valid retained evidence.
        if ($isReparse -or [bool]$entry.reparse_point) { return $false }
        $actualType = if ($isDirectory) { 'directory' } else { 'file' }
        if ([string]$entry.entry_type -cne $actualType -or -not (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $entry.identity)) { return $false }
        if (-not $isDirectory) {
            try { $readback = Read-NormalFilePinned -Path $fullPath -ExpectedIdentity $entry.identity }
            catch { return $false }
            if ([long]$readback.length -ne [long]$entry.length -or [string]$readback.sha256 -cne [string]$entry.sha256) { return $false }
        }
        if ($isDirectory -and ([long]$entry.length -ne 0 -or -not [string]::IsNullOrEmpty([string]$entry.sha256))) { return $false }
    }
    foreach ($path in $ExpectedRelativePaths) {
        if (-not $seen.Contains(([string]$path).Replace('\', '/'))) { return $false }
    }
    return $true
}


function Get-RetainedArtifactEntriesFromReceipts {
    param([string[]]$ExcludeRelativePaths = @())
    if ($null -eq $script:rw06RetainedArtifactReceipts) { throw 'Retained-artifact registry is not active.' }
    $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $ExcludeRelativePaths) { [void]$excluded.Add(([string]$path).Replace('\', '/')) }
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($receipt in @($script:rw06RetainedArtifactReceipts)) {
        $relativePath = ([string]$receipt.relative_path).Replace('\', '/')
        if ($excluded.Contains($relativePath)) { continue }
        if (-not [bool]$receipt.finalized) { throw "Retained artifact remained unfinalized: $relativePath" }
        $entries.Add([ordered]@{
            path = $relativePath
            entry_type = [string]$receipt.entry_type
            reparse_point = $false
            length = [long]$receipt.length
            sha256 = [string]$receipt.sha256
            identity = $receipt.identity
        })
    }
    return @($entries | Sort-Object path)
}


function Register-PreviouslyUnseenOwnedEvidenceEntries {
    param($EvidenceReceipt)
    [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $EvidenceReceipt)
    $root = [System.IO.Path]::GetFullPath([string]$EvidenceReceipt.root).TrimEnd([char[]]@([char]'\', [char]'/'))
    $known = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($receipt in @($script:rw06RetainedArtifactReceipts)) { [void]$known.Add([System.IO.Path]::GetFullPath([string]$receipt.path)) }
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($root)
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop | Sort-Object FullName)) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Unreceipted evidence entry is a reparse point: $($item.FullName)" }
            $fullPath = [System.IO.Path]::GetFullPath($item.FullName)
            if ($item.PSIsContainer) { $stack.Push($fullPath) }
            if ($known.Contains($fullPath)) { continue }
            $relativePath = $fullPath.Substring($root.Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
            if ($item.PSIsContainer) {
                $identity = Get-FileSystemEntryIdentity -Path $fullPath
                $receipt = [ordered]@{
                    path = $fullPath; relative_path = $relativePath; entry_type = 'directory'; reparse_point = $false
                    length = [long]0; sha256 = ''; identity = $identity; finalized = $true; guard_stream = $null
                    post_move_identity_verified = $true; readback_verified = $true
                }
            }
            else {
                $readback = Read-NormalFilePinned -Path $fullPath
                $receipt = [ordered]@{
                    path = $fullPath; relative_path = $relativePath; entry_type = 'file'; reparse_point = $false
                    length = [long]$readback.length; sha256 = [string]$readback.sha256; identity = $readback.identity
                    finalized = $true; guard_stream = $null; post_move_identity_verified = $true; readback_verified = $true
                }
            }
            [void](Register-RetainedArtifactReceipt -EvidenceReceipt $EvidenceReceipt -Receipt $receipt)
            [void]$known.Add($fullPath)
        }
    }
    [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $EvidenceReceipt)
    return $true
}


function Move-RetainedArtifactReceiptAtomic {
    param($EvidenceReceipt, $Receipt, [string]$DestinationPath)
    [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $EvidenceReceipt -Receipt $Receipt)
    $source = [System.IO.Path]::GetFullPath([string]$Receipt.path)
    $destination = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path $DestinationPath
    if ([System.IO.Path]::GetDirectoryName($source) -cne [System.IO.Path]::GetDirectoryName($destination)) {
        throw 'Terminal artifact publication must be a same-directory atomic rename.'
    }
    if (Test-Path -LiteralPath $destination) { throw "Terminal publication destination already exists: $destination" }
    [System.IO.File]::Move($source, $destination)
    $movedIdentity = Get-FileSystemEntryIdentity -Path $destination
    if (-not (Test-FileSystemObjectsShareIdentity -Left $Receipt.identity -Right $movedIdentity)) {
        throw 'Terminal artifact identity changed across publication rename.'
    }
    $Receipt.path = $destination
    $Receipt.relative_path = $destination.Substring(([string]$EvidenceReceipt.root).Length).TrimStart([char[]]@([char]'\', [char]'/')).Replace('\', '/')
    $Receipt.identity = $movedIdentity
    [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $EvidenceReceipt -Receipt $Receipt)
    return $Receipt
}


function Remove-ExactLateBoundSeals {
    param($EvidenceReceipt, [object[]]$Seals)
    $errors = [System.Collections.Generic.List[string]]::new()
    try { [void](Assert-OwnedEvidenceRoot -Receipt $EvidenceReceipt) }
    catch {
        [void]$errors.Add(('Late-bound invalidation lacks its exact owned evidence root: ' + $_.Exception.Message))
        return @($errors)
    }
    foreach ($seal in @($Seals | Where-Object { $null -ne $_ } | Select-Object -Last 999 | Sort-Object { [string]$_.relative_path } -Descending)) {
        try {
            foreach ($requiredField in @('path', 'relative_path', 'identity', 'sha256', 'post_move_identity_verified', 'atomic_no_overwrite')) {
                if (-not $seal.Contains($requiredField)) { throw "Late-bound seal lacks field: $requiredField" }
            }
            if (-not [bool]$seal.post_move_identity_verified -or -not [bool]$seal.atomic_no_overwrite) {
                throw 'Late-bound seal lacks an atomic post-move ownership proof.'
            }
            $resolvedSealPath = Assert-PathContainedByRoot -Root ([string]$EvidenceReceipt.root) -Path ([string]$seal.path)
            $expectedSealPath = [System.IO.Path]::GetFullPath((Join-Path ([string]$EvidenceReceipt.root) ([string]$seal.relative_path).Replace('/', '\')))
            if ($resolvedSealPath -cne $expectedSealPath) {
                throw 'Late-bound seal absolute and relative paths do not agree.'
            }
            if (Test-Path -LiteralPath $resolvedSealPath) {
                [void](Remove-ExactOwnedFile -Path $resolvedSealPath -ExpectedIdentity $seal.identity -ExpectedSha256 ([string]$seal.sha256))
            }
        }
        catch { [void]$errors.Add($_.Exception.Message) }
    }
    return @($errors)
}


function Get-TrackedFileIdentity {
    param(
        [string]$Root,
        [string]$Commit,
        [string]$RelativePath
    )
    $fullPath = Join-Path $Root ($RelativePath.Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Required harness/product file is missing: $RelativePath"
    }
    $guard = [System.IO.FileStream]::new($fullPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $readback = Read-NormalFilePinned -Path $fullPath
        $treeSpec = '{0}:{1}' -f $Commit, $RelativePath
        $blob = (& git -C $Root rev-parse $treeSpec).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($blob)) {
            throw "Could not bind tracked blob identity for $RelativePath"
        }
        $workingBlob = (& git -C $Root hash-object -- $RelativePath).Trim()
        if ($LASTEXITCODE -ne 0 -or $workingBlob -cne $blob) {
            throw "Working bytes do not match the committed blob for $RelativePath"
        }
        return [ordered]@{
            path = $RelativePath
            full_path = [System.IO.Path]::GetFullPath($fullPath)
            git_blob = $blob
            working_git_blob = $workingBlob
            length = [long]$readback.length
            sha256 = [string]$readback.sha256
            identity = $readback.identity
        }
    }
    finally {
        $guard.Dispose()
    }
}


function Assert-TrackedFileIdentityStable {
    param([string]$Root, [string]$Commit, $Receipt)
    if ($null -eq $Receipt -or -not $Receipt.Contains('path') -or -not $Receipt.Contains('identity')) {
        throw 'Tracked input receipt is absent or lacks its native identity.'
    }
    $current = Get-TrackedFileIdentity -Root $Root -Commit $Commit -RelativePath ([string]$Receipt.path)
    if (
        [string]$current.git_blob -cne [string]$Receipt.git_blob `
        -or [string]$current.sha256 -cne [string]$Receipt.sha256 `
        -or [long]$current.length -ne [long]$Receipt.length `
        -or -not (Test-FileSystemObjectsShareIdentity -Left $current.identity -Right $Receipt.identity)
    ) { throw "Tracked input identity changed: $([string]$Receipt.path)" }
    return $true
}


function Test-FileIdentityMatchesExplicitExpectation {
    param($Identity, [string]$ExpectedSha256, [string]$ExpectedGitBlob)
    return (
        $null -ne $Identity `
        -and (Test-ExactHexIdentity -Value $ExpectedSha256 -Length 64) `
        -and (Test-ExactHexIdentity -Value $ExpectedGitBlob -Length 40) `
        -and [string]$Identity.sha256 -ceq $ExpectedSha256.ToUpperInvariant() `
        -and [string]$Identity.git_blob -ceq $ExpectedGitBlob.ToLowerInvariant() `
        -and [string]$Identity.working_git_blob -ceq [string]$Identity.git_blob
    )
}


function Test-CounterpartRelationshipRecords {
    param(
        [ValidateSet('Red', 'Green')][string]$CurrentRole,
        $CurrentFiles,
        $CounterpartFiles,
        $ExpectedHarness,
        [string]$BaseProductBlob,
        [string]$BaseFoundationBlob
    )
    if ($null -eq $CurrentFiles -or $null -eq $CounterpartFiles -or $null -eq $ExpectedHarness) { return $false }
    foreach ($name in @('launcher', 'guard', 'full_contract')) {
        if (-not $CurrentFiles.Contains($name) -or -not $CounterpartFiles.Contains($name) -or -not $ExpectedHarness.Contains($name)) { return $false }
        $expected = $ExpectedHarness[$name]
        if (
            -not (Test-FileIdentityMatchesExplicitExpectation -Identity $CurrentFiles[$name] -ExpectedSha256 ([string]$expected.sha256) -ExpectedGitBlob ([string]$expected.git_blob)) `
            -or -not (Test-FileIdentityMatchesExplicitExpectation -Identity $CounterpartFiles[$name] -ExpectedSha256 ([string]$expected.sha256) -ExpectedGitBlob ([string]$expected.git_blob))
        ) { return $false }
    }
    foreach ($name in @('product', 'foundation')) {
        if (-not $CurrentFiles.Contains($name) -or -not $CounterpartFiles.Contains($name)) { return $false }
    }
    $redFiles = if ($CurrentRole -eq 'Red') { $CurrentFiles } else { $CounterpartFiles }
    $greenFiles = if ($CurrentRole -eq 'Green') { $CurrentFiles } else { $CounterpartFiles }
    return (
        [string]$redFiles.product.git_blob -ceq $BaseProductBlob `
        -and [string]$redFiles.foundation.git_blob -ceq $BaseFoundationBlob `
        -and [string]$greenFiles.product.git_blob -cne $BaseProductBlob `
        -and [string]$greenFiles.foundation.git_blob -cne $BaseFoundationBlob `
        -and [string]$redFiles.product.git_blob -cne [string]$greenFiles.product.git_blob `
        -and [string]$redFiles.foundation.git_blob -cne [string]$greenFiles.foundation.git_blob
    )
}


function New-CounterpartAdmissionReceipt {
    param(
        [ValidateSet('Red', 'Green')][string]$CurrentRole,
        [string]$CurrentRoot,
        [string]$CurrentCommit,
        [string]$CurrentTree,
        [string]$OtherRoot,
        [string]$RequiredOtherCommit,
        [string]$RequiredOtherTree,
        [string]$LauncherSha256,
        [string]$LauncherGitBlob,
        [string]$GuardSha256,
        [string]$GuardGitBlob,
        [string]$FullContractSha256,
        [string]$FullContractGitBlob
    )
    foreach ($value in @($RequiredOtherCommit, $RequiredOtherTree, $LauncherSha256, $LauncherGitBlob, $GuardSha256, $GuardGitBlob, $FullContractSha256, $FullContractGitBlob)) {
        if ([string]::IsNullOrWhiteSpace([string]$value)) {
            throw 'Counterpart commit/tree and explicit shared harness SHA/blob identities are required before any lease or engine phase.'
        }
    }
    if (-not (Test-ExactHexIdentity -Value $RequiredOtherCommit -Length 40) -or -not (Test-ExactHexIdentity -Value $RequiredOtherTree -Length 40)) {
        throw 'Counterpart commit/tree identities must be exact 40-character Git object IDs.'
    }
    $resolvedCurrentRoot = [System.IO.Path]::GetFullPath($CurrentRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    $resolvedOtherRoot = [System.IO.Path]::GetFullPath($OtherRoot).TrimEnd([char[]]@([char]'\', [char]'/'))
    if ($resolvedOtherRoot -eq $resolvedCurrentRoot -or -not (Test-Path -LiteralPath $resolvedOtherRoot -PathType Container)) {
        throw 'CounterpartRoot must name a distinct available worktree.'
    }
    $otherItem = Get-Item -LiteralPath $resolvedOtherRoot -Force
    if (($otherItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'CounterpartRoot may not be a reparse point.'
    }
    $otherIdentity = Assert-CleanExactCandidate -Root $resolvedOtherRoot -RequiredCommit $RequiredOtherCommit -RequiredTree $RequiredOtherTree
    $currentFiles = [ordered]@{
        launcher = Get-TrackedFileIdentity -Root $resolvedCurrentRoot -Commit $CurrentCommit -RelativePath $launcherRelativePath
        guard = Get-TrackedFileIdentity -Root $resolvedCurrentRoot -Commit $CurrentCommit -RelativePath $guardRelativePath
        full_contract = Get-TrackedFileIdentity -Root $resolvedCurrentRoot -Commit $CurrentCommit -RelativePath $fullContractRelativePath
        product = Get-TrackedFileIdentity -Root $resolvedCurrentRoot -Commit $CurrentCommit -RelativePath $productRelativePath
        foundation = Get-TrackedFileIdentity -Root $resolvedCurrentRoot -Commit $CurrentCommit -RelativePath $foundationRelativePath
    }
    $otherFiles = [ordered]@{
        launcher = Get-TrackedFileIdentity -Root $resolvedOtherRoot -Commit ([string]$otherIdentity.commit) -RelativePath $launcherRelativePath
        guard = Get-TrackedFileIdentity -Root $resolvedOtherRoot -Commit ([string]$otherIdentity.commit) -RelativePath $guardRelativePath
        full_contract = Get-TrackedFileIdentity -Root $resolvedOtherRoot -Commit ([string]$otherIdentity.commit) -RelativePath $fullContractRelativePath
        product = Get-TrackedFileIdentity -Root $resolvedOtherRoot -Commit ([string]$otherIdentity.commit) -RelativePath $productRelativePath
        foundation = Get-TrackedFileIdentity -Root $resolvedOtherRoot -Commit ([string]$otherIdentity.commit) -RelativePath $foundationRelativePath
    }
    $expectedHarness = [ordered]@{
        launcher = [ordered]@{ sha256 = $LauncherSha256.ToUpperInvariant(); git_blob = $LauncherGitBlob.ToLowerInvariant() }
        guard = [ordered]@{ sha256 = $GuardSha256.ToUpperInvariant(); git_blob = $GuardGitBlob.ToLowerInvariant() }
        full_contract = [ordered]@{ sha256 = $FullContractSha256.ToUpperInvariant(); git_blob = $FullContractGitBlob.ToLowerInvariant() }
    }
    $baseProductBlob = (& git -C $resolvedCurrentRoot rev-parse ("{0}:{1}" -f $preFeatureBaseCommit, $productRelativePath)).Trim()
    $baseProductExit = $LASTEXITCODE
    $baseFoundationBlob = (& git -C $resolvedCurrentRoot rev-parse ("{0}:{1}" -f $preFeatureBaseCommit, $foundationRelativePath)).Trim()
    $baseFoundationExit = $LASTEXITCODE
    if ($baseProductExit -ne 0 -or $baseFoundationExit -ne 0 -or -not (Test-ExactHexIdentity -Value $baseProductBlob -Length 40) -or -not (Test-ExactHexIdentity -Value $baseFoundationBlob -Length 40)) {
        throw 'Could not resolve the canonical pre-feature product/foundation blobs.'
    }
    if (-not (Test-CounterpartRelationshipRecords -CurrentRole $CurrentRole -CurrentFiles $currentFiles -CounterpartFiles $otherFiles -ExpectedHarness $expectedHarness -BaseProductBlob $baseProductBlob -BaseFoundationBlob $baseFoundationBlob)) {
        throw 'Red/Green counterpart harness identity or pre-feature-vs-feature product relationship failed closed.'
    }
    $receipt = [ordered]@{
        accepted = $true
        current_role = $CurrentRole
        current = [ordered]@{ root = $resolvedCurrentRoot; commit = $CurrentCommit; tree = $CurrentTree; files = $currentFiles }
        counterpart_role = if ($CurrentRole -eq 'Green') { 'Red' } else { 'Green' }
        counterpart = [ordered]@{ root = $resolvedOtherRoot; commit = [string]$otherIdentity.commit; tree = [string]$otherIdentity.tree; files = $otherFiles }
        expected_shared_harness = $expectedHarness
        pre_feature = [ordered]@{ commit = $preFeatureBaseCommit; product_blob = $baseProductBlob; foundation_blob = $baseFoundationBlob }
        relationship = [ordered]@{
            shared_launcher_guard_contract_byte_identical = $true
            red_product_is_pre_feature = $true
            red_foundation_is_pre_feature = $true
            green_product_differs = $true
            green_foundation_differs = $true
        }
    }
    $receipt.receipt_sha256 = Get-StringSha256 -Value (($receipt | ConvertTo-Json -Depth 12 -Compress))
    return $receipt
}


function Assert-CounterpartAdmissionReceiptStable {
    param($Receipt)
    if ($null -eq $Receipt -or -not [bool]$Receipt.accepted -or -not (Test-ExactHexIdentity -Value ([string]$Receipt.receipt_sha256) -Length 64)) {
        throw 'Counterpart admission receipt is absent or malformed.'
    }
    $hashPayload = [ordered]@{}
    foreach ($entry in $Receipt.GetEnumerator()) {
        if ([string]$entry.Key -cne 'receipt_sha256') { $hashPayload[$entry.Key] = $entry.Value }
    }
    if ((Get-StringSha256 -Value (($hashPayload | ConvertTo-Json -Depth 12 -Compress))) -cne [string]$Receipt.receipt_sha256) {
        throw 'Counterpart admission receipt hash changed.'
    }
    foreach ($sideName in @('current', 'counterpart')) {
        $side = $Receipt[$sideName]
        [void](Assert-CleanExactCandidate -Root ([string]$side.root) -RequiredCommit ([string]$side.commit) -RequiredTree ([string]$side.tree))
        foreach ($fileName in @('launcher', 'guard', 'full_contract', 'product', 'foundation')) {
            $expected = $side.files[$fileName]
            $actual = Get-TrackedFileIdentity -Root ([string]$side.root) -Commit ([string]$side.commit) -RelativePath ([string]$expected.path)
            if ([string]$actual.sha256 -cne [string]$expected.sha256 -or [string]$actual.git_blob -cne [string]$expected.git_blob) {
                throw "Counterpart admission file drifted after sealing: $sideName/$fileName"
            }
        }
    }
    return $true
}


function Get-LiveGodotIdentityRecords {
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-LiveGodotProcesses)) {
        try {
            $records.Add((Get-ProcessIdentityRecord -Process $process))
        }
        catch {
            throw "Could not bind live Godot process identity for PID $($process.Id)."
        }
    }
    return @($records)
}


function Get-LiveFocusedLeaseOwnerIdentities {
    $owners = [System.Collections.Generic.List[object]]::new()
    foreach ($record in @(Get-StrictLeaseEntryRecords -Root $leaseRoot -RequireCanonical)) {
        $identity = ConvertFrom-ExactLeaseOwnerFields -Fields $record.fields
        if (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $identity) {
            [void]$owners.Add($identity)
        }
    }
    return @($owners)
}


function Test-ProcessHasExactLeaseAncestor {
    param([object]$ProcessIdentity, [object[]]$LeaseOwnerIdentities)
    if (-not (Test-ProcessIdentityProofShape -Identity $ProcessIdentity) -or $LeaseOwnerIdentities.Count -eq 0) { return $false }
    $cimTable = @{}
    foreach ($entry in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) { $cimTable[[int]$entry.ProcessId] = $entry }
    $cursor = $ProcessIdentity
    for ($depth = 0; $depth -lt 32; $depth += 1) {
        foreach ($owner in $LeaseOwnerIdentities) {
            if (
                [string]$cursor.key -ceq [string]$owner.key `
                -and (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $owner)
            ) { return $true }
        }
        if (-not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $cursor) -or -not $cimTable.ContainsKey([int]$cursor.pid)) { return $false }
        $cim = $cimTable[[int]$cursor.pid]
        $creationUtc = ([datetime]$cim.CreationDate).ToUniversalTime()
        if (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks ([long]$creationUtc.Ticks) -ProcessStartTicks ([long]$cursor.start_ticks))) { return $false }
        $parentPid = [int]$cim.ParentProcessId
        if ($parentPid -le 0 -or $parentPid -eq [int]$cursor.pid) { return $false }
        $parentProcess = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
        if ($null -eq $parentProcess) { return $false }
        try { $parentIdentity = Get-ProcessIdentityRecord -Process $parentProcess }
        catch { return $false }
        if ([long]$parentIdentity.start_ticks -gt [long]$cursor.start_ticks) { return $false }
        $cursor = $parentIdentity
    }
    return $false
}


function Get-NewUnownedGodotRecords {
    param([string[]]$BaselineKeys)
    $leaseOwnerIdentities = @(Get-LiveFocusedLeaseOwnerIdentities)
    return @(Get-LiveGodotIdentityRecords | Where-Object {
        $record = $_
        $BaselineKeys -notcontains [string]$record.key -and -not (Test-ProcessHasExactLeaseAncestor -ProcessIdentity $record -LeaseOwnerIdentities $leaseOwnerIdentities)
    })
}


if ($ValidateOnly) {
    $initialFixtureGate = Assert-ValidateOnlyFixtureRootClean -Context 'ValidateOnly startup'
    $unknownFixtureHostilePath = Join-Path $projectRoot ('.tmp\rw06_6\fixture-repair-static-hostile-' + [guid]::NewGuid().ToString('N'))
    [void][System.IO.Directory]::CreateDirectory($unknownFixtureHostilePath)
    $unknownFixtureHostileIdentity = Get-FileSystemEntryIdentity -Path $unknownFixtureHostilePath
    try {
        $unknownFixtureInventory = @(Get-ValidateOnlyFixtureResidueInventory)
        $unknownFixtureGateRejected = $false
        try { [void](Assert-ValidateOnlyFixtureRootClean -Context 'ValidateOnly unknown fixture hostile') }
        catch { $unknownFixtureGateRejected = $_.Exception.Message -match 'requires zero fixture residue' }
        Assert-LauncherContract (
            $unknownFixtureInventory.Count -eq 1 `
            -and [bool]$unknownFixtureInventory[0].unknown_fixture_name `
            -and $unknownFixtureGateRejected `
            -and (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $unknownFixtureHostileIdentity)
        ) 'ValidateOnly fixture gate hid, adopted, or deleted an unknown fixture-named root.'
    }
    finally {
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $unknownFixtureHostilePath -QuarantinePath ($unknownFixtureHostilePath + '.delete') -ExpectedRootIdentity $unknownFixtureHostileIdentity)
    }
    Assert-LauncherContract ($leaseRoot -ceq $canonicalLeaseRoot) 'Q-009 launcher did not resolve the exact canonical lease root.'
    $canonicalGodotProbe = Get-CanonicalGodotIdentity -RequestedPath $canonicalGodotPath -RequiredSha256 $canonicalGodotSha256 -RequiredVersion $canonicalGodotVersion
    Assert-LauncherContract ([bool]$canonicalGodotProbe.accepted -and [string]$canonicalGodotProbe.sha256 -ceq $canonicalGodotSha256 -and [string]$canonicalGodotProbe.product_version -ceq $canonicalGodotVersion) 'Canonical Godot binary identity probe did not bind exact path/SHA/version.'
    foreach ($godotHostile in @(
        [ordered]@{ path = ($canonicalGodotPath.Replace('\Godot_v4.6-stable_win64_console.exe', '\.\Godot_v4.6-stable_win64_console.exe')); sha = $canonicalGodotSha256; version = $canonicalGodotVersion; label = 'path alias' },
        [ordered]@{ path = $canonicalGodotPath; sha = ('0' * 64); version = $canonicalGodotVersion; label = 'wrong SHA' },
        [ordered]@{ path = $canonicalGodotPath; sha = $canonicalGodotSha256; version = '4.6.stable.alias'; label = 'wrong version' }
    )) {
        $rejected = $false
        try { [void](Get-CanonicalGodotIdentity -RequestedPath ([string]$godotHostile.path) -RequiredSha256 ([string]$godotHostile.sha) -RequiredVersion ([string]$godotHostile.version)) } catch { $rejected = $true }
        Assert-LauncherContract $rejected "Canonical Godot identity accepted $([string]$godotHostile.label)."
    }
    Assert-LauncherContract (Test-FocusedLaunchCapacity $false 0 0) 'Q-009 capacity rejected an empty machine.'
    Assert-LauncherContract (Test-FocusedLaunchCapacity $false 1 2) 'Q-009 capacity rejected the second focused console/child pair.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $true 0 0)) 'Q-009 capacity ignored EXCLUSIVE.lease.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $false 2 0)) 'Q-009 capacity allowed a third focused pair.'
    Assert-LauncherContract (-not (Test-FocusedLaunchCapacity $false 1 3)) 'Q-009 capacity allowed current processes plus two to exceed four.'
    Assert-LauncherContract (Test-ReservedLaunchCapacity $false 2 2) 'Q-009 reserved capacity rejected the valid ceiling.'
    Assert-LauncherContract (-not (Test-ReservedLaunchCapacity $true 1 0)) 'Q-009 reserved capacity ignored EXCLUSIVE.lease.'
    Assert-LauncherContract (-not (Test-ReservedLaunchCapacity $false 3 0)) 'Q-009 reserved capacity allowed more than two focused reservations.'
    Assert-LauncherContract (-not (Test-ReservedLaunchCapacity $false 2 3)) 'Q-009 reserved capacity allowed more than four projected processes.'
    $selfProcess = Get-Process -Id $PID
    $selfIdentity = Get-ProcessIdentityRecord -Process $selfProcess
    Assert-LauncherContract (Test-LiveProcessMatchesIdentity -ExpectedIdentity $selfIdentity) 'PID/start-time/name identity matcher rejected the current process.'
    $wrongNameIdentity = [ordered]@{
        pid = [int]$selfIdentity.pid
        name = [string]$selfIdentity.name + '-wrong'
        start_utc = [string]$selfIdentity.start_utc
        start_ticks = [long]$selfIdentity.start_ticks
        key = ('{0}|{1}|{2}-wrong' -f $selfIdentity.pid, $selfIdentity.start_ticks, $selfIdentity.name)
    }
    Assert-LauncherContract (-not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $wrongNameIdentity)) 'PID/start-time/name identity matcher accepted a wrong process name.'
    $wrongStartIdentity = [ordered]@{
        pid = [int]$selfIdentity.pid
        name = [string]$selfIdentity.name
        start_utc = $selfProcess.StartTime.AddSeconds(-1).ToUniversalTime().ToString('o')
        start_ticks = [long]$selfProcess.StartTime.AddSeconds(-1).ToUniversalTime().Ticks
        key = ('{0}|{1}|{2}' -f $selfIdentity.pid, $selfProcess.StartTime.AddSeconds(-1).ToUniversalTime().Ticks, $selfIdentity.name)
    }
    Assert-LauncherContract (-not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $wrongStartIdentity)) 'PID/start-time/name identity matcher accepted a reused-process timestamp.'
    Assert-LauncherContract ([string]$selfIdentity.key -eq ('{0}|{1}|{2}' -f $PID, $selfProcess.StartTime.ToUniversalTime().Ticks, $selfProcess.ProcessName)) 'Process identity key is not PID + UTC start ticks + name.'
    Assert-LauncherContract (Test-ProcessIdentityProofShape -Identity $selfIdentity) 'Exact process identity proof validator rejected a real PID/start/name identity.'
    $validStartException = [System.InvalidOperationException]::new('valid exact start proof')
    $validStartException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $validStartException.Data['owned_process_identity'] = $selfIdentity
    $validStartProof = Get-OwnedProcessStartProofFromException -Exception $validStartException
    Assert-LauncherContract ([bool]$validStartProof.started -and [int]$validStartProof.process_id -eq [int]$selfIdentity.pid -and [string]$validStartProof.process_identity.key -ceq [string]$selfIdentity.key) 'Exact process start proof was not recovered from an exception.'
    $pidOnlyStartException = [System.InvalidOperationException]::new('pid only is not exact proof')
    $pidOnlyStartException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $pidOnlyStartProof = Get-OwnedProcessStartProofFromException -Exception $pidOnlyStartException
    Assert-LauncherContract (-not [bool]$pidOnlyStartProof.started) 'PID-only exception metadata was accepted as exact process-start proof.'
    $malformedStartException = [System.InvalidOperationException]::new('malformed identity is not exact proof')
    $malformedIdentity = [ordered]@{}
    foreach ($entry in $selfIdentity.GetEnumerator()) { $malformedIdentity[$entry.Key] = $entry.Value }
    $malformedIdentity.key = [string]$malformedIdentity.key + '|wrong'
    $malformedStartException.Data['owned_process_id'] = [int]$selfIdentity.pid
    $malformedStartException.Data['owned_process_identity'] = $malformedIdentity
    $malformedStartProof = Get-OwnedProcessStartProofFromException -Exception $malformedStartException
    Assert-LauncherContract (-not [bool]$malformedStartProof.started) 'Malformed identity metadata was accepted as exact process-start proof.'

    Assert-LauncherContract (Test-CimCreationMatchesProcessStartTicks -CreationTicks 150 -ProcessStartTicks 159) 'CIM/process start comparison rejected exact microsecond truncation.'
    Assert-LauncherContract (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks 140 -ProcessStartTicks 159)) 'CIM/process start comparison accepted a predecessor timestamp one microsecond away.'
    Assert-LauncherContract (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks 1000000 -ProcessStartTicks 1099999)) 'CIM/process start comparison accepted a replacement 99,999 ticks inside the former 10 ms tolerance.'

    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 10 -NativeExitObserved $true -EffectiveExitCode 10 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'valid_red') 'Guard classifier rejected a deliberate clean RED.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 0 -NativeExitObserved $true -EffectiveExitCode 0 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $false -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'green_handoff') 'Guard classifier rejected a clean GREEN handoff.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 2 -NativeExitObserved $true -EffectiveExitCode 2 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $true -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'invalid') 'Guard classifier accepted an infrastructure failure.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 10 -NativeExitObserved $true -EffectiveExitCode 10 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 1) -eq 'invalid') 'Guard classifier accepted a parser/import diagnostic.'
    $orphanDiagnostics = @(Get-DiagnosticLines -Text "Orphan StringName: Node (static: 3, total: 4)`nStringName: 1 unclaimed string names at exit.`n")
    Assert-LauncherContract ($orphanDiagnostics.Count -eq 2) 'Diagnostic classifier did not fail closed on both registry StringName orphan forms.'
    Assert-LauncherContract ($orphanDiagnostics -contains 'Orphan StringName: Node (static: 3, total: 4)') 'Diagnostic classifier missed the Orphan StringName form.'
    Assert-LauncherContract ($orphanDiagnostics -contains 'StringName: 1 unclaimed string names at exit.') 'Diagnostic classifier missed the unclaimed StringName form.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode 0 -NativeExitObserved $true -EffectiveExitCode 0 -TimedOut $false -RunnerError '' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'invalid') 'Guard classifier accepted mixed RED/GREEN markers.'
    Assert-LauncherContract ((Resolve-GuardDisposition -NativeExitCode $nativeExitSentinel -NativeExitObserved $false -EffectiveExitCode 125 -TimedOut $false -RunnerError 'missing exit' -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -UnexpectedDiagnosticCount 0) -eq 'invalid') 'Guard classifier accepted an unobserved native exit.'
    Assert-LauncherContract (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false) 'Registry marker classifier rejected a marker-free phase.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false)) 'Registry marker classifier accepted PRODUCT_RED.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false)) 'Registry marker classifier accepted GUARD_PASS.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $true -FullPassMarkerSeen $false)) 'Registry marker classifier accepted GUARD_INFRA_FAILURE.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true)) 'Registry marker classifier accepted the full-contract PASS marker.'
    Assert-LauncherContract (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true) 'Full marker classifier rejected its sole expected PASS marker.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false)) 'Full marker classifier accepted a missing PASS marker.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $true -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true)) 'Full marker classifier accepted PRODUCT_RED alongside PASS.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $true -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true)) 'Full marker classifier accepted GUARD_PASS alongside PASS.'
    Assert-LauncherContract (-not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $true -FullPassMarkerSeen $true)) 'Full marker classifier accepted GUARD_INFRA_FAILURE alongside PASS.'

    $registryArgumentProbe = @(Get-RegistryBootstrapArguments -Root $projectRoot)
    $registryLogProbe = Join-Path $projectRoot '.tmp\rw06_6\registry-bootstrap-probe.log'
    Assert-LauncherContract (Test-RegistryBootstrapArguments -Arguments $registryArgumentProbe -Root $projectRoot) 'Registry bootstrap argument contract rejected exact recovery import arguments.'
    Assert-LauncherContract (Test-RegistryBootstrapArguments -Arguments (@('--log-file', $registryLogProbe) + $registryArgumentProbe) -Root $projectRoot -GodotLogPath $registryLogProbe) 'Registry bootstrap argument contract rejected the exact logged recovery import arguments.'
    $reorderedRegistryArguments = @($registryArgumentProbe)
    $reorderedRegistryArguments[0] = '--verbose'
    $reorderedRegistryArguments[1] = '--headless'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments $reorderedRegistryArguments -Root $projectRoot)) 'Registry bootstrap argument contract accepted reordered headless/verbose flags.'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments @($registryArgumentProbe | Where-Object { $_ -cne '--headless' }) -Root $projectRoot)) 'Registry bootstrap argument contract accepted missing headless mode.'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments @($registryArgumentProbe | Where-Object { $_ -cne '--recovery-mode' }) -Root $projectRoot)) 'Registry bootstrap argument contract accepted missing recovery mode.'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments @($registryArgumentProbe | Where-Object { $_ -cne '--verbose' }) -Root $projectRoot)) 'Registry bootstrap argument contract accepted missing verbose diagnostics.'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments @($registryArgumentProbe | Where-Object { $_ -cne '--import' }) -Root $projectRoot)) 'Registry bootstrap argument contract accepted missing import mode.'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments ($registryArgumentProbe + @('--quiet')) -Root $projectRoot)) 'Registry bootstrap argument contract accepted quiet diagnostic suppression.'
    Assert-LauncherContract (-not (Test-RegistryBootstrapArguments -Arguments @('--headless', '--verbose', '--path', $projectRoot, '--editor', '--quit') -Root $projectRoot)) 'Registry bootstrap argument contract accepted the known-leaking immediate editor-quit path.'

    $fullArgumentProbe = @(Get-FullContractArguments -Root $projectRoot -ScriptPath $fullContractScriptPath)
    $fullLogProbe = Join-Path $projectRoot '.tmp\rw06_6\full-contract-probe.log'
    Assert-LauncherContract (Test-FullContractArguments -Arguments $fullArgumentProbe -Root $projectRoot -ScriptPath $fullContractScriptPath) 'Full-contract argument contract rejected exact normal headless arguments.'
    Assert-LauncherContract (Test-FullContractArguments -Arguments (@('--log-file', $fullLogProbe) + $fullArgumentProbe) -Root $projectRoot -ScriptPath $fullContractScriptPath -GodotLogPath $fullLogProbe) 'Full-contract argument contract rejected exact logged normal headless arguments.'
    Assert-LauncherContract (-not (Test-FullContractArguments -Arguments ($fullArgumentProbe + @('--recovery-mode')) -Root $projectRoot -ScriptPath $fullContractScriptPath)) 'Full-contract argument contract accepted recovery mode.'
    Assert-LauncherContract (-not (Test-FullContractArguments -Arguments ($fullArgumentProbe + @('--import')) -Root $projectRoot -ScriptPath $fullContractScriptPath)) 'Full-contract argument contract accepted import mode.'
    Assert-LauncherContract (-not (Test-FullContractArguments -Arguments ($fullArgumentProbe + @('--quiet')) -Root $projectRoot -ScriptPath $fullContractScriptPath)) 'Full-contract argument contract accepted quiet diagnostic suppression.'

    $adjacentScriptProbe = 'res://.tmp/rw06_6/evidence/fixture/generated/foundation_check_split_runner.gd'
    $adjacentReportProbe = 'res://.tmp/rw06_6/evidence/fixture/04-foundation-pull-tabs/foundation-pull-tabs-report.json'
    $adjacentLogProbe = Join-Path $projectRoot '.tmp\rw06_6\adjacent-probe.log'
    $adjacentArgumentProbe = @(Get-AdjacentFoundationArguments -Root $projectRoot -ScriptPath $adjacentScriptProbe -ReportResourcePath $adjacentReportProbe)
    Assert-LauncherContract (Test-AdjacentFoundationArguments -Arguments $adjacentArgumentProbe -Root $projectRoot -ScriptPath $adjacentScriptProbe -ReportResourcePath $adjacentReportProbe) 'Adjacent Foundation argument contract rejected exact production pull-tabs arguments.'
    Assert-LauncherContract (Test-AdjacentFoundationArguments -Arguments (@('--log-file', $adjacentLogProbe) + $adjacentArgumentProbe) -Root $projectRoot -ScriptPath $adjacentScriptProbe -ReportResourcePath $adjacentReportProbe -GodotLogPath $adjacentLogProbe) 'Adjacent Foundation argument contract rejected exact logged arguments.'
    Assert-LauncherContract (-not (Test-AdjacentFoundationArguments -Arguments ($adjacentArgumentProbe + @('--quiet')) -Root $projectRoot -ScriptPath $adjacentScriptProbe -ReportResourcePath $adjacentReportProbe)) 'Adjacent Foundation argument contract accepted diagnostic suppression.'
    $validAdjacentReport = [pscustomobject]@{
        tool = 'foundation_check'; suite = 'pull_tabs'; passed = $true; failure_count = 0; failures = @(); requested_check_ids = @(); skipped = @();
        executed_check_ids = @('content', 'pull_tabs_game_suite'); registered_check_ids = @('content', 'pull_tabs_game_suite'); last_started_check = 'pull_tabs_game_suite';
        checks = @(
            [pscustomobject]@{ id = 'content'; passed = $true; failure_count = 0; failures = @() },
            [pscustomobject]@{ id = 'pull_tabs_game_suite'; passed = $true; failure_count = 0; failures = @() }
        )
    }
    Assert-LauncherContract (Test-AdjacentFoundationReport -Report $validAdjacentReport) 'Adjacent Foundation report contract rejected the exact two-check production receipt.'
    $hostileAdjacentReport = ($validAdjacentReport | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $hostileAdjacentReport.executed_check_ids = @('content')
    Assert-LauncherContract (-not (Test-AdjacentFoundationReport -Report $hostileAdjacentReport)) 'Adjacent Foundation report contract accepted omission of pull_tabs_game_suite.'
    $hostileAdjacentTypes = ($validAdjacentReport | ConvertTo-Json -Depth 8) | ConvertFrom-Json
    $hostileAdjacentTypes.passed = 'true'
    $hostileAdjacentTypes.failure_count = '0'
    Assert-LauncherContract (-not (Test-AdjacentFoundationReport -Report $hostileAdjacentTypes)) 'Adjacent Foundation report contract accepted string-coerced pass/count fields.'
    Assert-LauncherContract (Test-AdjacentPhaseMarkerContract -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -FoundationPassMarkerSeen $true -FoundationPullTabsDoneMarkerSeen $true -FoundationDoneCount 2) 'Adjacent Foundation marker contract rejected exact PASS/DONE markers.'
    Assert-LauncherContract (-not (Test-AdjacentPhaseMarkerContract -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $true -FoundationPassMarkerSeen $true -FoundationPullTabsDoneMarkerSeen $true -FoundationDoneCount 2)) 'Adjacent Foundation marker contract accepted the wrong full-contract marker.'
    Assert-LauncherContract (-not (Test-AdjacentPhaseMarkerContract -ProductRedMarkerSeen $false -GuardPassMarkerSeen $false -InfraFailureMarkerSeen $false -FullPassMarkerSeen $false -FoundationPassMarkerSeen $true -FoundationPullTabsDoneMarkerSeen $true -FoundationDoneCount 1)) 'Adjacent Foundation marker contract accepted a missing content/pull-tabs DONE marker.'

    $validRegistryLifecycle = Get-RegistryLifecycleEvidence `
        -StdoutText "[ DONE ] first_scan_filesystem`n" `
        -StderrText "[ DONE ] update_scripts_classes`n" `
        -GodotLogText "[ DONE ] reimport`n"
    Assert-LauncherContract (Test-RegistryLifecycleContract -Lifecycle $validRegistryLifecycle) 'Registry lifecycle contract rejected a complete recovery import.'
    foreach ($missingDoneMarker in @('first_scan_done', 'update_scripts_classes_done')) {
        $hostileLifecycle = [ordered]@{}
        foreach ($entry in $validRegistryLifecycle.GetEnumerator()) { $hostileLifecycle[$entry.Key] = $entry.Value }
        $hostileLifecycle[$missingDoneMarker] = $false
        Assert-LauncherContract (-not (Test-RegistryLifecycleContract -Lifecycle $hostileLifecycle)) "Registry lifecycle contract accepted missing $missingDoneMarker."
    }
    $missingReimportLifecycle = [ordered]@{}
    foreach ($entry in $validRegistryLifecycle.GetEnumerator()) { $missingReimportLifecycle[$entry.Key] = $entry.Value }
    $missingReimportLifecycle.reimport_done_count = 0
    Assert-LauncherContract (-not (Test-RegistryLifecycleContract -Lifecycle $missingReimportLifecycle)) 'Registry lifecycle contract accepted a missing reimport DONE marker.'
    $stdoutMainSceneLifecycle = Get-RegistryLifecycleEvidence `
        -StdoutText "Loading resource: res://scenes/main.tscn`n" `
        -StderrText "[ DONE ] update_scripts_classes`n" `
        -GodotLogText "[ DONE ] first_scan_filesystem`n[ DONE ] reimport`n"
    Assert-LauncherContract ([bool]$stdoutMainSceneLifecycle.main_scene_loaded -and -not [bool]$stdoutMainSceneLifecycle.foundation_main_loaded) 'Registry lifecycle extraction missed a forbidden main-scene load present solely in stdout.'
    Assert-LauncherContract (-not (Test-RegistryLifecycleContract -Lifecycle $stdoutMainSceneLifecycle)) 'Registry lifecycle contract accepted a forbidden main-scene load present solely in stdout.'
    $stderrFoundationLifecycle = Get-RegistryLifecycleEvidence `
        -StdoutText "[ DONE ] first_scan_filesystem`n" `
        -StderrText "Loading resource: res://scripts/ui/foundation_main.gd`n" `
        -GodotLogText "[ DONE ] update_scripts_classes`n[ DONE ] reimport`n"
    Assert-LauncherContract ([bool]$stderrFoundationLifecycle.foundation_main_loaded -and -not [bool]$stderrFoundationLifecycle.main_scene_loaded) 'Registry lifecycle extraction missed a forbidden foundation-main load present solely in stderr.'
    Assert-LauncherContract (-not (Test-RegistryLifecycleContract -Lifecycle $stderrFoundationLifecycle)) 'Registry lifecycle contract accepted a forbidden foundation-main load present solely in stderr.'

    $recoveryDependencyCensusProbe = Get-RecoveryBootstrapDependencyCensus -Root $projectRoot -InventoryMode EngineVisible
    Assert-LauncherContract (Test-RecoveryBootstrapDependencyCensus -Census $recoveryDependencyCensusProbe) 'Current candidate has an engine-visible tracked, ignored, untracked, executable, addon, editor-plugin, GDExtension, @tool, autoload, or reparse hazard suppressed by recovery mode.'
    Assert-LauncherContract ([string]$recoveryDependencyCensusProbe.inventory_mode -ceq 'EngineVisible' -and [int]$recoveryDependencyCensusProbe.tracked_file_count -gt 100 -and [int]$recoveryDependencyCensusProbe.gd_script_count -gt 100 -and [int]$recoveryDependencyCensusProbe.inventory_file_count -ge [int]$recoveryDependencyCensusProbe.tracked_file_count) 'Recovery dependency census did not substantively scan the complete engine-visible candidate tree.'

    $dependencyFixtureRoot = Join-Path $projectRoot ('.tmp\rw06_6\recovery-dependency-selftest-' + [guid]::NewGuid().ToString('N'))
    $dependencyFields = @('addon_paths', 'plugin_config_paths', 'gdextension_paths', 'native_extension_paths', 'tool_script_paths', 'autoload_entries', 'editor_plugin_entries')
    $dependencyFixtureRootIdentity = $null
    try {
        New-Item -ItemType Directory -Path $dependencyFixtureRoot | Out-Null
        $dependencyFixtureRootIdentity = Get-FileSystemEntryIdentity -Path $dependencyFixtureRoot
        foreach ($fixtureName in @('clean', 'untracked_clean_script', 'addons', 'ignored_addon', 'plugin_cfg', 'gdextension', 'native_extension', 'tool_script', 'autoload', 'editor_plugins')) {
            $fixtureRoot = Join-Path $dependencyFixtureRoot $fixtureName
            $fixtureScripts = Join-Path $fixtureRoot 'scripts'
            New-Item -ItemType Directory -Force -Path $fixtureScripts | Out-Null
            $fixtureProjectText = "[application]`nconfig/name=`"rw06_6 recovery census fixture`"`n"
            [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'project.godot'), $fixtureProjectText)
            [System.IO.File]::WriteAllText((Join-Path $fixtureScripts 'clean.gd'), "extends Node`n")
            [System.IO.File]::WriteAllText((Join-Path $fixtureRoot '.gitignore'), "ignored-evidence/`n")
            & git -C $fixtureRoot init -q
            if ($LASTEXITCODE -ne 0) { throw "Could not initialize dependency hostile fixture: $fixtureName" }
            & git -C $fixtureRoot config core.autocrlf false
            if ($LASTEXITCODE -ne 0) { throw "Could not configure exact-byte dependency hostile fixture: $fixtureName" }
            & git -C $fixtureRoot add -- project.godot scripts/clean.gd .gitignore
            if ($LASTEXITCODE -ne 0) { throw "Could not stage dependency hostile fixture baseline: $fixtureName" }

            $expectedDependencyField = ''
            switch ($fixtureName) {
                'untracked_clean_script' {
                    [System.IO.File]::WriteAllText((Join-Path $fixtureScripts 'ordinary_untracked.gd'), "extends Node`n")
                }
                'addons' {
                    $addonFixture = Join-Path $fixtureRoot 'addons\probe'
                    New-Item -ItemType Directory -Force -Path $addonFixture | Out-Null
                    [System.IO.File]::WriteAllText((Join-Path $addonFixture 'marker.txt'), "probe`n")
                    $expectedDependencyField = 'addon_paths'
                }
                'ignored_addon' {
                    [System.IO.File]::AppendAllText((Join-Path $fixtureRoot '.gitignore'), "addons/coin_pusher_native/`n")
                    $addonFixture = Join-Path $fixtureRoot 'addons\coin_pusher_native'
                    New-Item -ItemType Directory -Force -Path $addonFixture | Out-Null
                    [System.IO.File]::WriteAllText((Join-Path $addonFixture 'coin_pusher_native.gdextension'), "[configuration]`nentry_symbol=`"probe`"`n")
                    $expectedDependencyField = 'addon_paths'
                }
                'plugin_cfg' {
                    [System.IO.File]::WriteAllText((Join-Path $fixtureRoot 'plugin.cfg'), "[plugin]`nname=`"probe`"`n")
                    $expectedDependencyField = 'plugin_config_paths'
                }
                'gdextension' {
                    $nativeFixture = Join-Path $fixtureRoot 'native'
                    New-Item -ItemType Directory -Force -Path $nativeFixture | Out-Null
                    [System.IO.File]::WriteAllText((Join-Path $nativeFixture 'probe.gdextension'), "[configuration]`nentry_symbol=`"probe`"`n")
                    $expectedDependencyField = 'gdextension_paths'
                }
                'native_extension' {
                    $nativeFixture = Join-Path $fixtureRoot 'native'
                    New-Item -ItemType Directory -Force -Path $nativeFixture | Out-Null
                    [System.IO.File]::WriteAllBytes((Join-Path $nativeFixture 'probe.dll'), [byte[]](1, 2, 3, 4))
                    $expectedDependencyField = 'native_extension_paths'
                }
                'tool_script' {
                    [System.IO.File]::WriteAllText((Join-Path $fixtureScripts 'tool_probe.gd'), "@tool`nextends Node`n", [System.Text.UTF8Encoding]::new($true))
                    $expectedDependencyField = 'tool_script_paths'
                }
                'autoload' {
                    [System.IO.File]::AppendAllText((Join-Path $fixtureRoot 'project.godot'), "`n[autoload]`nProbe=`"*res://scripts/clean.gd`"`n")
                    $expectedDependencyField = 'autoload_entries'
                }
                'editor_plugins' {
                    [System.IO.File]::AppendAllText((Join-Path $fixtureRoot 'project.godot'), "`n[editor_plugins]`nenabled=PackedStringArray(`"probe`")`n")
                    $expectedDependencyField = 'editor_plugin_entries'
                }
            }

            $fixtureCensus = Get-RecoveryBootstrapDependencyCensus -Root $fixtureRoot -InventoryMode EngineVisible
            if ($fixtureName -in @('clean', 'untracked_clean_script')) {
                Assert-LauncherContract (Test-RecoveryBootstrapDependencyCensus -Census $fixtureCensus) 'Recovery dependency census rejected a clean disposable project fixture.'
                foreach ($dependencyField in $dependencyFields) {
                    Assert-LauncherContract ($fixtureCensus[$dependencyField].Count -eq 0) "Clean recovery dependency fixture unexpectedly populated $dependencyField."
                }
                if ($fixtureName -eq 'untracked_clean_script') {
                    Assert-LauncherContract ([int]$fixtureCensus.untracked_file_count -eq 1 -and @($fixtureCensus.inventory_entries | Where-Object { [string]$_.path -ceq 'scripts/ordinary_untracked.gd' -and [string]$_.classification -ceq 'untracked' }).Count -eq 1) 'Engine-visible census omitted or misclassified a safe untracked script.'
                }
            }
            else {
                Assert-LauncherContract (-not (Test-RecoveryBootstrapDependencyCensus -Census $fixtureCensus)) "Recovery dependency census accepted the $fixtureName disposable project fixture."
                Assert-LauncherContract (-not [string]::IsNullOrWhiteSpace($expectedDependencyField) -and $fixtureCensus[$expectedDependencyField].Count -gt 0) "Recovery dependency census did not detect $fixtureName in its exact field."
                foreach ($dependencyField in $dependencyFields | Where-Object { $_ -cne $expectedDependencyField }) {
                    if ($fixtureName -eq 'ignored_addon' -and $dependencyField -eq 'gdextension_paths') { continue }
                    Assert-LauncherContract ($fixtureCensus[$dependencyField].Count -eq 0) "Recovery dependency fixture $fixtureName also populated unrelated $dependencyField."
                }
                if ($fixtureName -eq 'ignored_addon') {
                    Assert-LauncherContract ([int]$fixtureCensus.ignored_file_count -ge 1 -and @($fixtureCensus.inventory_entries | Where-Object { [string]$_.path -ceq 'addons/coin_pusher_native/coin_pusher_native.gdextension' -and [string]$_.classification -ceq 'ignored' }).Count -eq 1) 'Engine-visible census missed the ignored /addons/coin_pusher_native executable input.'
                }
            }
        }

        $reparseFixtureRoot = Join-Path $dependencyFixtureRoot 'reparse'
        $reparseScripts = Join-Path $reparseFixtureRoot 'scripts'
        $reparseTarget = Join-Path $dependencyFixtureRoot 'reparse-target'
        New-Item -ItemType Directory -Force -Path $reparseScripts, $reparseTarget | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $reparseFixtureRoot 'project.godot'), "[application]`nconfig/name=`"reparse probe`"`n")
        [System.IO.File]::WriteAllText((Join-Path $reparseScripts 'clean.gd'), "extends Node`n")
        [System.IO.File]::WriteAllText((Join-Path $reparseFixtureRoot '.gitignore'), "probe-link/`n")
        & git -C $reparseFixtureRoot init -q
        if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the reparse dependency hostile fixture.' }
        & git -C $reparseFixtureRoot config core.autocrlf false
        if ($LASTEXITCODE -ne 0) { throw 'Could not configure the reparse dependency hostile fixture.' }
        & git -C $reparseFixtureRoot add -- project.godot scripts/clean.gd .gitignore
        if ($LASTEXITCODE -ne 0) { throw 'Could not stage the reparse dependency hostile fixture baseline.' }
        $reparseLink = Join-Path $reparseFixtureRoot 'probe-link'
        [void](New-Item -ItemType Junction -Path $reparseLink -Target $reparseTarget)
        $reparseLinkIdentity = Get-FileSystemEntryIdentity -Path $reparseLink -AllowReparse
        $reparseRejected = $false
        try { [void](Get-RecoveryBootstrapDependencyCensus -Root $reparseFixtureRoot -InventoryMode EngineVisible) } catch { $reparseRejected = $_.Exception.Message -match 'reparse point' }
        Assert-LauncherContract $reparseRejected 'Engine-visible census accepted a reparse-capable ignored/untracked input.'
        [void](Remove-ExactOwnedReparseEntry -Path $reparseLink -ExpectedIdentity $reparseLinkIdentity)
    }
    finally {
        if ($null -ne $dependencyFixtureRootIdentity -and (Test-Path -LiteralPath $dependencyFixtureRoot -PathType Container)) {
            [void](Remove-ExactOwnedDirectoryTree -OwnedPath $dependencyFixtureRoot -QuarantinePath ($dependencyFixtureRoot + '.delete') -ExpectedRootIdentity $dependencyFixtureRootIdentity)
        }
    }

    $sharedExpectation = [ordered]@{
        launcher = [ordered]@{ sha256 = ('A' * 64); git_blob = ('a' * 40) }
        guard = [ordered]@{ sha256 = ('B' * 64); git_blob = ('b' * 40) }
        full_contract = [ordered]@{ sha256 = ('C' * 64); git_blob = ('c' * 40) }
    }
    $baseProductProbe = '1111111111111111111111111111111111111111'
    $baseFoundationProbe = '2222222222222222222222222222222222222222'
    $newProductProbe = '3333333333333333333333333333333333333333'
    $newFoundationProbe = '4444444444444444444444444444444444444444'
    $redRelationshipFiles = [ordered]@{
        launcher = [ordered]@{ sha256 = ('A' * 64); git_blob = ('a' * 40); working_git_blob = ('a' * 40) }
        guard = [ordered]@{ sha256 = ('B' * 64); git_blob = ('b' * 40); working_git_blob = ('b' * 40) }
        full_contract = [ordered]@{ sha256 = ('C' * 64); git_blob = ('c' * 40); working_git_blob = ('c' * 40) }
        product = [ordered]@{ git_blob = $baseProductProbe }
        foundation = [ordered]@{ git_blob = $baseFoundationProbe }
    }
    $greenRelationshipFiles = [ordered]@{
        launcher = [ordered]@{ sha256 = ('A' * 64); git_blob = ('a' * 40); working_git_blob = ('a' * 40) }
        guard = [ordered]@{ sha256 = ('B' * 64); git_blob = ('b' * 40); working_git_blob = ('b' * 40) }
        full_contract = [ordered]@{ sha256 = ('C' * 64); git_blob = ('c' * 40); working_git_blob = ('c' * 40) }
        product = [ordered]@{ git_blob = $newProductProbe }
        foundation = [ordered]@{ git_blob = $newFoundationProbe }
    }
    Assert-LauncherContract (Test-CounterpartRelationshipRecords -CurrentRole Green -CurrentFiles $greenRelationshipFiles -CounterpartFiles $redRelationshipFiles -ExpectedHarness $sharedExpectation -BaseProductBlob $baseProductProbe -BaseFoundationBlob $baseFoundationProbe) 'Counterpart admission rejected byte-identical harnesses with exact pre-feature Red and feature Green products.'
    $hostileRedHarness = [ordered]@{}
    foreach ($entry in $redRelationshipFiles.GetEnumerator()) {
        $clone = [ordered]@{}
        foreach ($field in $entry.Value.GetEnumerator()) { $clone[$field.Key] = $field.Value }
        $hostileRedHarness[$entry.Key] = $clone
    }
    $hostileRedHarness.launcher.sha256 = ('D' * 64)
    Assert-LauncherContract (-not (Test-CounterpartRelationshipRecords -CurrentRole Green -CurrentFiles $greenRelationshipFiles -CounterpartFiles $hostileRedHarness -ExpectedHarness $sharedExpectation -BaseProductBlob $baseProductProbe -BaseFoundationBlob $baseFoundationProbe)) 'Counterpart admission accepted different Red launcher bytes.'
    $hostileRedProduct = [ordered]@{}
    foreach ($entry in $redRelationshipFiles.GetEnumerator()) {
        $clone = [ordered]@{}
        foreach ($field in $entry.Value.GetEnumerator()) { $clone[$field.Key] = $field.Value }
        $hostileRedProduct[$entry.Key] = $clone
    }
    $hostileRedProduct.product.git_blob = $newProductProbe
    Assert-LauncherContract (-not (Test-CounterpartRelationshipRecords -CurrentRole Green -CurrentFiles $greenRelationshipFiles -CounterpartFiles $hostileRedProduct -ExpectedHarness $sharedExpectation -BaseProductBlob $baseProductProbe -BaseFoundationBlob $baseFoundationProbe)) 'Counterpart admission accepted a Red product that was not the exact pre-feature blob.'
    $hostileGreenProduct = [ordered]@{}
    foreach ($entry in $greenRelationshipFiles.GetEnumerator()) {
        $clone = [ordered]@{}
        foreach ($field in $entry.Value.GetEnumerator()) { $clone[$field.Key] = $field.Value }
        $hostileGreenProduct[$entry.Key] = $clone
    }
    $hostileGreenProduct.foundation.git_blob = $baseFoundationProbe
    Assert-LauncherContract (-not (Test-CounterpartRelationshipRecords -CurrentRole Green -CurrentFiles $hostileGreenProduct -CounterpartFiles $redRelationshipFiles -ExpectedHarness $sharedExpectation -BaseProductBlob $baseProductProbe -BaseFoundationBlob $baseFoundationProbe)) 'Counterpart admission accepted a Green foundation blob identical to pre-feature Red.'

    $evidenceSelftestParent = Join-Path $projectRoot ('.tmp\rw06_6\evidence-selftest-parent-' + [guid]::NewGuid().ToString('N'))
    $evidenceSelftestRoot = Join-Path $evidenceSelftestParent 'owned-evidence'
    $evidenceSelftestReceipt = $null
    $evidenceSelftestParentIdentity = $null
    try {
        [void](Ensure-NormalDirectoryPath -Root $projectRoot -DirectoryPath $evidenceSelftestParent)
        $evidenceSelftestParentIdentity = Get-FileSystemEntryIdentity -Path $evidenceSelftestParent
        $evidenceSelftestReceipt = Initialize-OwnedEvidenceRoot -RequestedRoot $evidenceSelftestRoot -ApprovedParent $evidenceSelftestParent -CandidateCommit ('1' * 40) -CandidateTree ('2' * 40) -Role Green
        Assert-LauncherContract ([bool](Assert-OwnedEvidenceRoot -Receipt $evidenceSelftestReceipt)) 'Atomic evidence-root ownership receipt did not survive immediate readback.'
        $atomicProbePath = Join-Path $evidenceSelftestRoot 'atomic-probe.json'
        $atomicProbeSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $atomicProbePath -Text "{`"probe`":true}`n"
        Assert-LauncherContract ([bool]$atomicProbeSeal.atomic_no_overwrite -and [bool]$atomicProbeSeal.readback_verified -and (Test-ExactHexIdentity -Value ([string]$atomicProbeSeal.sha256) -Length 64)) 'Atomic evidence write did not produce a sealed readback receipt.'
        $overwriteRejected = $false
        try { [void](Write-AtomicSealedText -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $atomicProbePath -Text "overwrite`n") } catch { $overwriteRejected = $_.Exception.Message -match 'already exists' }
        Assert-LauncherContract $overwriteRejected 'Atomic evidence writer overwrote a preexisting/raced destination.'

        $generatedProbeRoot = Join-Path $evidenceSelftestRoot 'generated'
        [void](New-OwnedEvidenceSubdirectory -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $generatedProbeRoot)
        $generatedProbe = New-Rw06FoundationRunner -Root $projectRoot -Commit ((& git -C $projectRoot rev-parse HEAD).Trim()) -DestinationPath (Join-Path $generatedProbeRoot 'foundation_check_split_runner.gd') -EvidenceReceipt $evidenceSelftestReceipt
        $generatedProbeSource = [System.IO.File]::ReadAllText([string]$generatedProbe.path)
        Assert-LauncherContract ([bool]$generatedProbe.composition_valid -and $generatedProbeSource.Contains('func _check_pull_tabs_surface_contract') -and @($generatedProbe.sources | Where-Object { [string]$_.path -ceq $foundationRelativePath }).Count -eq 1) 'Adjacent runner evidence did not actually compose the modified check_table_games.gd shard.'

        $preexistingRejected = $false
        try { [void](Initialize-OwnedEvidenceRoot -RequestedRoot $evidenceSelftestRoot -ApprovedParent $evidenceSelftestParent -CandidateCommit ('1' * 40) -CandidateTree ('2' * 40) -Role Green) } catch { $preexistingRejected = $_.Exception.Message -match 'fresh and absent' }
        Assert-LauncherContract $preexistingRejected 'EvidenceRoot admission accepted a preexisting destination.'
        $racedEvidenceRoot = Join-Path $evidenceSelftestParent 'raced-evidence'
        $destinationRaceRejected = $false
        try {
            [void](Initialize-OwnedEvidenceRoot -RequestedRoot $racedEvidenceRoot -ApprovedParent $evidenceSelftestParent -CandidateCommit ('1' * 40) -CandidateTree ('2' * 40) -Role Green -ForceDestinationRaceForTest)
        }
        catch {
            $destinationRaceRejected = $true
        }
        Assert-LauncherContract ($destinationRaceRejected -and (Test-Path -LiteralPath (Join-Path $racedEvidenceRoot 'foreign-race.txt') -PathType Leaf)) 'EvidenceRoot atomic claim overwrote or removed a destination created during the final move race.'
        $copiedClaimRoot = Join-Path $evidenceSelftestParent 'copied-claim-evidence'
        $copiedClaimRejected = $false
        try {
            [void](Initialize-OwnedEvidenceRoot -RequestedRoot $copiedClaimRoot -ApprovedParent $evidenceSelftestParent -CandidateCommit ('1' * 40) -CandidateTree ('2' * 40) -Role Green -ForcePostMoveCopiedClaimReplacementForTest)
        }
        catch { $copiedClaimRejected = $_.Exception.Message -match 'identity changed' }
        Assert-LauncherContract (
            $copiedClaimRejected `
            -and (Test-Path -LiteralPath (Join-Path $copiedClaimRoot '.rw06_6-evidence-owner.json') -PathType Leaf) `
            -and (Test-Path -LiteralPath ($copiedClaimRoot + '.owned-original') -PathType Container)
        ) 'EvidenceRoot admitted or deleted a copied-claim replacement after atomic move.'
        $escapeRejected = $false
        try { [void](Initialize-OwnedEvidenceRoot -RequestedRoot (Join-Path $projectRoot '.tmp\rw06_6\escaped-evidence') -ApprovedParent $evidenceSelftestParent -CandidateCommit ('1' * 40) -CandidateTree ('2' * 40) -Role Green) } catch { $escapeRejected = $_.Exception.Message -match 'direct child' }
        Assert-LauncherContract $escapeRejected 'EvidenceRoot admission accepted a path outside its approved direct parent.'
        $evidenceReparseTarget = Join-Path $evidenceSelftestParent 'reparse-target'
        $evidenceReparseParent = Join-Path $evidenceSelftestParent 'reparse-parent'
        New-Item -ItemType Directory -Path $evidenceReparseTarget | Out-Null
        [void](New-Item -ItemType Junction -Path $evidenceReparseParent -Target $evidenceReparseTarget)
        $evidenceReparseIdentity = Get-FileSystemEntryIdentity -Path $evidenceReparseParent -AllowReparse
        $reparseEvidenceRejected = $false
        try { [void](Initialize-OwnedEvidenceRoot -RequestedRoot (Join-Path $evidenceReparseParent 'owned') -ApprovedParent $evidenceReparseParent -CandidateCommit ('1' * 40) -CandidateTree ('2' * 40) -Role Green) } catch { $reparseEvidenceRejected = $_.Exception.Message -match 'reparse point' }
        Assert-LauncherContract $reparseEvidenceRejected 'EvidenceRoot admission accepted a reparse-point approved parent.'
        [void](Remove-ExactOwnedReparseEntry -Path $evidenceReparseParent -ExpectedIdentity $evidenceReparseIdentity)
        $replacedSubdirectory = Join-Path $evidenceSelftestRoot 'replaced-directory'
        $subdirectoryReplacementRejected = $false
        try { [void](New-OwnedEvidenceSubdirectory -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $replacedSubdirectory -ForcePostMoveReplacementForTest) }
        catch { $subdirectoryReplacementRejected = $_.Exception.Message -match 'identity changed' }
        Assert-LauncherContract (
            $subdirectoryReplacementRejected `
            -and (Test-Path -LiteralPath $replacedSubdirectory -PathType Container) `
            -and (Test-Path -LiteralPath ($replacedSubdirectory + '.owned-original') -PathType Container)
        ) 'Evidence subdirectory admitted or deleted a post-move replacement.'
        $replacedAtomicPath = Join-Path $evidenceSelftestRoot 'copied-seal.json'
        $atomicReplacementRejected = $false
        try { [void](Write-AtomicSealedText -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $replacedAtomicPath -Text "{`"same_bytes`":true}`n" -ForcePostMoveReplacementForTest) }
        catch { $atomicReplacementRejected = $_.Exception.Message -match 'readback seal failed' }
        Assert-LauncherContract (
            $atomicReplacementRejected `
            -and (Test-Path -LiteralPath $replacedAtomicPath -PathType Leaf) `
            -and (Test-Path -LiteralPath ($replacedAtomicPath + '.owned-original') -PathType Leaf)
        ) 'Atomic evidence file admitted or deleted an identical-byte copied replacement.'
        $lateOwnedPath = Join-Path $evidenceSelftestRoot 'late-owned-cleanup.json'
        $lateOwnedSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $lateOwnedPath -Text "{`"late_owned`":true}`n"
        $lateOwnedErrors = @(Remove-ExactLateBoundSeals -EvidenceReceipt $evidenceSelftestReceipt -Seals @($lateOwnedSeal))
        Assert-LauncherContract ($lateOwnedErrors.Count -eq 0 -and -not (Test-Path -LiteralPath $lateOwnedPath)) 'Terminal invalidation could not exact-remove an unchanged late-owned seal.'
        $lateReplacementPath = Join-Path $evidenceSelftestRoot 'late-replacement.json'
        $lateReplacementSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceSelftestReceipt -DestinationPath $lateReplacementPath -Text "{`"late_replacement`":true}`n"
        $lateReplacementOriginal = $lateReplacementPath + '.owned-original'
        [System.IO.File]::Move($lateReplacementPath, $lateReplacementOriginal)
        [System.IO.File]::Copy($lateReplacementOriginal, $lateReplacementPath, $false)
        $lateReplacementErrors = @(Remove-ExactLateBoundSeals -EvidenceReceipt $evidenceSelftestReceipt -Seals @($lateReplacementSeal))
        Assert-LauncherContract (
            $lateReplacementErrors.Count -eq 1 `
            -and (Test-Path -LiteralPath $lateReplacementPath -PathType Leaf) `
            -and (Test-Path -LiteralPath $lateReplacementOriginal -PathType Leaf)
        ) 'Terminal invalidation deleted or accepted an identical-byte replacement instead of retaining both objects.'
        $retainedReparsePath = Join-Path $evidenceSelftestRoot 'retained-reparse'
        [void](New-Item -ItemType Junction -Path $retainedReparsePath -Target $evidenceReparseTarget)
        $retainedReparseIdentity = Get-FileSystemEntryIdentity -Path $retainedReparsePath -AllowReparse
        $reparseTreeEntries = @(Get-RetainedArtifactEntries -EvidenceReceipt $evidenceSelftestReceipt)
        $reparseTreePaths = @($reparseTreeEntries | ForEach-Object { [string]$_.path })
        Assert-LauncherContract (
            @($reparseTreeEntries | Where-Object { [string]$_.path -ceq 'retained-reparse' -and [bool]$_.reparse_point }).Count -eq 1 `
            -and -not (Test-RetainedArtifactIntegrity -EvidenceReceipt $evidenceSelftestReceipt -ExpectedEntries $reparseTreeEntries -ExpectedRelativePaths $reparseTreePaths)
        ) 'Whole-tree retained-artifact census hid or accepted a reparse object.'
        [void](Remove-ExactOwnedReparseEntry -Path $retainedReparsePath -ExpectedIdentity $retainedReparseIdentity)
        $retainedProbeEntries = @(Get-RetainedArtifactEntries -EvidenceReceipt $evidenceSelftestReceipt)
        Assert-LauncherContract (
            $retainedProbeEntries.Count -ge 3 `
            -and @($retainedProbeEntries | Where-Object { [string]$_.path -ceq 'atomic-probe.json' -and [string]$_.entry_type -ceq 'file' }).Count -eq 1 `
            -and @($retainedProbeEntries | Where-Object { [string]$_.entry_type -ceq 'directory' }).Count -ge 2
        ) 'Retained-artifact census omitted an owned file or empty directory.'
        $retainedProbePaths = @($retainedProbeEntries | ForEach-Object { [string]$_.path })
        Assert-LauncherContract (Test-RetainedArtifactIntegrity -EvidenceReceipt $evidenceSelftestReceipt -ExpectedEntries $retainedProbeEntries -ExpectedRelativePaths $retainedProbePaths) 'Retained-artifact integrity validator rejected an exact owned census.'
        [System.IO.File]::AppendAllText($atomicProbePath, "mutated-after-census`n")
        Assert-LauncherContract (-not (Test-RetainedArtifactIntegrity -EvidenceReceipt $evidenceSelftestReceipt -ExpectedEntries $retainedProbeEntries -ExpectedRelativePaths $retainedProbePaths)) 'Retained-artifact integrity validator accepted bytes mutated after the sealed census.'
    }
    finally {
        if ($null -ne $evidenceSelftestParentIdentity -and (Test-Path -LiteralPath $evidenceSelftestParent -PathType Container)) {
            [void](Remove-ExactOwnedDirectoryTree -OwnedPath $evidenceSelftestParent -QuarantinePath ($evidenceSelftestParent + '.delete') -ExpectedRootIdentity $evidenceSelftestParentIdentity)
        }
    }

    $cacheSelftestRoot = Join-Path $projectRoot ('.tmp\rw06_6\cache-provenance-selftest-' + [guid]::NewGuid().ToString('N'))
    $cacheSelftestRootIdentity = $null
    try {
        New-Item -ItemType Directory -Path $cacheSelftestRoot | Out-Null
        $cacheSelftestRootIdentity = Get-FileSystemEntryIdentity -Path $cacheSelftestRoot
        $cacheSelftestPath = Join-Path $cacheSelftestRoot '.godot'
        $temporalAdoptionRejected = $false
        try { Update-OwnedCreationState -State (New-OwnedCreationState -Path $cacheSelftestPath) -RootProcessIdentity $selfIdentity }
        catch { $temporalAdoptionRejected = $_.Exception.Message -match 'forbidden' }
        Assert-LauncherContract $temporalAdoptionRejected 'Launcher-authored temporal cache adoption was not rejected.'

        [void][System.IO.Directory]::CreateDirectory($cacheSelftestPath)
        $foreignPreexistingIdentity = Get-FileSystemEntryIdentity -Path $cacheSelftestPath
        $foreignPreexistingFile = Join-Path $cacheSelftestPath 'foreign-preexisting.txt'
        [System.IO.File]::WriteAllText($foreignPreexistingFile, "foreign-preexisting`n")
        $foreignPreexistingState = New-OwnedCreationState -Path $cacheSelftestPath
        $foreignCreationRejected = $false
        try { [void](Initialize-ExclusiveOwnedCacheRoot -State $foreignPreexistingState) }
        catch { $foreignCreationRejected = $_.Exception.Message -match 'absent destination' }
        $foreignCleanupRejected = $false
        try { [void](Remove-DedicatedProjectCache -Root $cacheSelftestRoot -CacheRoot $cacheSelftestPath -OwnedCreationProof $foreignPreexistingState) }
        catch { $foreignCleanupRejected = $_.Exception.Message -match 'without an exact owned creation/claim proof' }
        Assert-LauncherContract (
            $foreignCreationRejected `
            -and $foreignCleanupRejected `
            -and (Test-Path -LiteralPath $foreignPreexistingFile -PathType Leaf)
        ) 'A raced foreign cache root was adopted or deleted after exclusive creation failed.'
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $cacheSelftestPath -QuarantinePath (Join-Path $cacheSelftestRoot '.foreign-preexisting-delete') -ExpectedRootIdentity $foreignPreexistingIdentity)

        $creatorFailureState = New-OwnedCreationState -Path $cacheSelftestPath
        $creatorFailureState = Initialize-ExclusiveOwnedCacheRoot -State $creatorFailureState
        $creatorFailureFile = Join-Path $cacheSelftestPath 'creator-failed-before-request.txt'
        [System.IO.File]::WriteAllText($creatorFailureFile, "creator-failed`n")
        $creatorFailureCleanupRejected = $false
        try { [void](Remove-DedicatedProjectCache -Root $cacheSelftestRoot -CacheRoot $cacheSelftestPath -OwnedCreationProof $creatorFailureState) }
        catch { $creatorFailureCleanupRejected = $_.Exception.Message -match 'without an exact owned creation/claim proof' }
        Assert-LauncherContract ($creatorFailureCleanupRejected -and (Test-Path -LiteralPath $creatorFailureFile -PathType Leaf)) 'Cache cleanup deleted a native-created root after creator handshake/claim failure.'
        $creatorFailureGuard = $creatorFailureState.root_guard_handle
        $creatorFailureGuard.Dispose()
        $creatorFailureState.root_guard_handle = $null
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $cacheSelftestPath -QuarantinePath (Join-Path $cacheSelftestRoot '.creator-failure-delete') -ExpectedRootIdentity $creatorFailureState.root_identity_at_creation)

        $cacheState = New-ValidateOnlySyntheticOwnedCacheState -Path $cacheSelftestPath -ForceReplacementBeforeFirstCaptureForTest
        $readOnlyCacheProbe = Join-Path $cacheSelftestPath 'readonly-owned.bin'
        [System.IO.File]::WriteAllText($readOnlyCacheProbe, "owned-readonly`n")
        [System.IO.File]::SetAttributes($readOnlyCacheProbe, [System.IO.FileAttributes]::ReadOnly)
        Assert-LauncherContract ((Test-OwnedCreationStateProof -State $cacheState) -and [bool]$cacheState.root_creation_replacement_probe_rejected) 'Creator-bound cache proof rejected an exact atomic native-root/job fixture or its pre-capture replacement hostile.'
        $cacheRemovalProbe = Remove-DedicatedProjectCache -Root $cacheSelftestRoot -CacheRoot $cacheSelftestPath -OwnedCreationProof $cacheState
        Assert-LauncherContract ([bool]$cacheRemovalProbe.removed -and [bool]$cacheRemovalProbe.identity_verified -and -not (Test-Path -LiteralPath $cacheSelftestPath)) 'Exact owned cache did not quarantine and clean safely.'

        $replacementState = New-ValidateOnlySyntheticOwnedCacheState -Path $cacheSelftestPath
        $ownedMovedAside = Join-Path $cacheSelftestRoot '.godot-owned-original'
        $guardedReplacementBlocked = $false
        try { [System.IO.Directory]::Move($cacheSelftestPath, $ownedMovedAside) }
        catch { $guardedReplacementBlocked = $true }
        Assert-LauncherContract ($guardedReplacementBlocked -and (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $replacementState.root_identity_at_creation)) 'Pinned cache root allowed replacement before cleanup authorization.'
        $replacementState.root_guard_handle.Dispose()
        $replacementState.root_guard_handle = $null
        [System.IO.Directory]::Move($cacheSelftestPath, $ownedMovedAside)
        New-Item -ItemType Directory -Path $cacheSelftestPath | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $cacheSelftestPath 'foreign.txt'), "foreign`n")
        $replacementRejected = $false
        try { [void](Remove-DedicatedProjectCache -Root $cacheSelftestRoot -CacheRoot $cacheSelftestPath -OwnedCreationProof $replacementState) } catch { $replacementRejected = $true }
        Assert-LauncherContract ($replacementRejected -and (Test-Path -LiteralPath (Join-Path $cacheSelftestPath 'foreign.txt') -PathType Leaf) -and (Test-Path -LiteralPath $ownedMovedAside -PathType Container)) 'Cache cleanup deleted or accepted a swapped/replaced cache after root custody ended.'
        $foreignCacheIdentity = Get-FileSystemEntryIdentity -Path $cacheSelftestPath
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $cacheSelftestPath -QuarantinePath (Join-Path $cacheSelftestRoot '.foreign-cache-delete') -ExpectedRootIdentity $foreignCacheIdentity)
        $ownedMovedAsideIdentity = Get-FileSystemEntryIdentity -Path $ownedMovedAside
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $ownedMovedAside -QuarantinePath (Join-Path $cacheSelftestRoot '.owned-original-delete') -ExpectedRootIdentity $ownedMovedAsideIdentity)

        $quarantineRaceState = New-ValidateOnlySyntheticOwnedCacheState -Path $cacheSelftestPath
        $forcedRaceQuarantine = Join-Path $cacheSelftestRoot ('.rw06_6-cache-quarantine-' + [string]$quarantineRaceState.nonce)
        $forcedRaceOriginal = $forcedRaceQuarantine + '.forced-owned-original'
        $quarantineRaceRejected = $false
        try {
            [void](Remove-DedicatedProjectCache -Root $cacheSelftestRoot -CacheRoot $cacheSelftestPath -OwnedCreationProof $quarantineRaceState -ForceQuarantineReplacementForTest)
        }
        catch {
            $quarantineRaceRejected = $_.Exception.Message -match 'identity changed|replaced|unowned'
        }
        Assert-LauncherContract (
            $quarantineRaceRejected `
            -and (Test-Path -LiteralPath (Join-Path $forcedRaceQuarantine 'foreign-replacement.txt') -PathType Leaf) `
            -and (Test-Path -LiteralPath $forcedRaceOriginal -PathType Container) `
            -and -not (Test-Path -LiteralPath $cacheSelftestPath)
        ) 'Handle-bound cache cleanup deleted a quarantine replacement or failed to retain the exact owned original after the forced check-to-delete race.'
        $raceForeignIdentity = Get-FileSystemEntryIdentity -Path $forcedRaceQuarantine
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $forcedRaceQuarantine -QuarantinePath (Join-Path $cacheSelftestRoot '.race-foreign-delete') -ExpectedRootIdentity $raceForeignIdentity)
        $raceOriginalIdentity = Get-FileSystemEntryIdentity -Path $forcedRaceOriginal
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $forcedRaceOriginal -QuarantinePath (Join-Path $cacheSelftestRoot '.race-original-delete') -ExpectedRootIdentity $raceOriginalIdentity)

        $reparseProjectRoot = Join-Path $cacheSelftestRoot 'reparse-project'
        $reparseTargetPath = Join-Path $cacheSelftestRoot 'reparse-target'
        New-Item -ItemType Directory -Path $reparseProjectRoot, $reparseTargetPath | Out-Null
        $reparseProjectIdentity = Get-FileSystemEntryIdentity -Path $reparseProjectRoot
        $reparseTargetIdentity = Get-FileSystemEntryIdentity -Path $reparseTargetPath
        $reparseCachePath = Join-Path $reparseProjectRoot '.godot'
        $reparseCacheState = New-ValidateOnlySyntheticOwnedCacheState -Path $reparseCachePath
        $cacheJunction = Join-Path $reparseCachePath 'foreign-link'
        [void](New-Item -ItemType Junction -Path $cacheJunction -Target $reparseTargetPath)
        $cacheJunctionIdentity = Get-FileSystemEntryIdentity -Path $cacheJunction -AllowReparse
        $reparseCacheRejected = $false
        try { [void](Remove-DedicatedProjectCache -Root $reparseProjectRoot -CacheRoot $reparseCachePath -OwnedCreationProof $reparseCacheState) } catch { $reparseCacheRejected = $_.Exception.Message -match 'reparse point' }
        Assert-LauncherContract ($reparseCacheRejected -and (Test-Path -LiteralPath $cacheJunction)) 'Cache cleanup accepted or followed a reparse-point payload.'
        [void](Remove-ExactOwnedReparseEntry -Path $cacheJunction -ExpectedIdentity $cacheJunctionIdentity)
        [void](Remove-DedicatedProjectCache -Root $reparseProjectRoot -CacheRoot $reparseCachePath -OwnedCreationProof $reparseCacheState)
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $reparseProjectRoot -QuarantinePath (Join-Path $cacheSelftestRoot '.reparse-project-delete') -ExpectedRootIdentity $reparseProjectIdentity)
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $reparseTargetPath -QuarantinePath (Join-Path $cacheSelftestRoot '.reparse-target-delete') -ExpectedRootIdentity $reparseTargetIdentity)
    }
    finally {
        if ($null -ne $cacheSelftestRootIdentity -and (Test-Path -LiteralPath $cacheSelftestRoot -PathType Container)) {
            $cacheFixtureResiduals = @(Get-ChildItem -LiteralPath $cacheSelftestRoot -Force -ErrorAction Stop)
            if ($cacheFixtureResiduals.Count -ne 0) {
                throw ('ValidateOnly cache fixture cleanup retained unexpected nonempty residue: ' + (@($cacheFixtureResiduals | ForEach-Object { [string]$_.Name }) -join ','))
            }
            [void](Remove-ExactOwnedDirectoryTree -OwnedPath $cacheSelftestRoot -QuarantinePath ($cacheSelftestRoot + '.delete') -ExpectedRootIdentity $cacheSelftestRootIdentity)
        }
    }

    Assert-LauncherContract (Test-Q016ApprovalText "### Q-016`nStatus: ANSWERED`nAnswer:`nA`n") 'Q-016 parser rejected a multiline ANSWERED A.'
    Assert-LauncherContract (-not (Test-Q016ApprovalText "### Q-016`nStatus: OPEN`nAnswer:`n")) 'Q-016 parser accepted OPEN.'
    Assert-LauncherContract (-not (Test-Q016ApprovalText "### Q-016`nStatus: ANSWERED`nAnswer: B. Refactor.`n")) 'Q-016 parser accepted option B.'
    Assert-LauncherContract (-not (Test-Q016ApprovalText "### Q-016`nStatus: ANSWERED`nAnswer: A`n### Q-016`nStatus: ANSWERED`nAnswer: A`n")) 'Q-016 parser accepted duplicate Q-016 sections.'

    $leaseProbeReceipt = $null
    $leaseProbeRoot = ''
    try {
        $leaseProbeReceipt = New-ValidateOnlySelftestRoot -RequiredNamePrefix 'lease-selftest-'
        $leaseProbeRoot = [string]$leaseProbeReceipt.path
        $forgedLeaseProbeReceipt = [ordered]@{}
        foreach ($entry in $leaseProbeReceipt.GetEnumerator()) { $forgedLeaseProbeReceipt[$entry.Key] = $entry.Value }
        $forgedLeaseProbeReceipt['nonce'] = ('0' * 32)
        $forgedReceiptRejected = $false
        try { Remove-ExactValidateOnlySelftestRoot -Receipt $forgedLeaseProbeReceipt }
        catch { $forgedReceiptRejected = $true }
        Assert-LauncherContract (
            $forgedReceiptRejected `
            -and (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $leaseProbeReceipt.root_identity) `
            -and (Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $leaseProbeReceipt.claim_identity)
        ) 'ValidateOnly self-test cleanup accepted an unsealed nonce replacement or altered its owned root.'
        $leaseProbeCommit = ('1' * 40)
        $leaseProbeTree = ('2' * 40)
        $leaseFixtureRoot = Join-Path $leaseProbeRoot 'lease-files'
        [void][System.IO.Directory]::CreateDirectory($leaseFixtureRoot)
        $partialLeasePath = Join-Path $leaseFixtureRoot 'forced-partial.lease'
        $forcedLeaseFailure = $false
        try {
            [void](New-OwnedLeaseFile -Path $partialLeasePath -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N')) -ForceWriteFailureForTest)
        }
        catch {
            $forcedLeaseFailure = $true
        }
        Assert-LauncherContract $forcedLeaseFailure 'Lease hostile probe did not execute its forced post-CreateNew failure.'
        Assert-LauncherContract (-not (Test-Path -LiteralPath $partialLeasePath)) 'Lease hostile probe left an unowned partial reservation.'

        $normalLeasePath = Join-Path $leaseFixtureRoot 'normal.lease'
        $normalLeaseReceipt = New-OwnedLeaseFile -Path $normalLeasePath -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N'))
        Assert-LauncherContract ([bool](Assert-OwnedLease -Receipt $normalLeaseReceipt -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree)) 'Exact PID/start/name/key/executable lease proof rejected its live owner.'
        $reusedOwnerFields = Read-LeaseFields -Path $normalLeasePath
        $reusedOwnerFields['owner_start_ticks'] = [string]([long]$selfIdentity.start_ticks - 1)
        $reusedOwnerFields['owner_start_utc'] = [datetime]::new(([long]$selfIdentity.start_ticks - 1), [DateTimeKind]::Utc).ToString('o')
        $reusedOwnerFields['owner_key'] = ('{0}|{1}|{2}' -f $PID, ([long]$selfIdentity.start_ticks - 1), [string]$selfIdentity.name)
        $reusedOwnerIdentity = ConvertFrom-ExactLeaseOwnerFields -Fields $reusedOwnerFields
        Assert-LauncherContract (-not (Test-LiveProcessMatchesExactLeaseOwner -ExpectedIdentity $reusedOwnerIdentity)) 'Lease ownership accepted a PID-reuse timestamp with matching PID/name/executable.'
        $relocatedNormalLeasePath = Join-Path $leaseFixtureRoot 'renamed-owned.lease'
        [System.IO.File]::Move($normalLeasePath, $relocatedNormalLeasePath)
        [System.IO.File]::WriteAllText($normalLeasePath, "foreign-original-path`n")
        $normalPathReplacementIdentity = Get-FileSystemEntryIdentity -Path $normalLeasePath
        $renamedRemoval = Remove-OwnedLeaseFile -Receipt $normalLeaseReceipt -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -LeaseDirectory $leaseFixtureRoot -AllowNonCanonicalLeaseRootForTest
        Assert-LauncherContract (
            [bool]$renamedRemoval.removed `
            -and [bool]$renamedRemoval.original_path_replacement_preserved `
            -and [string]$renamedRemoval.located_path -ceq $relocatedNormalLeasePath `
            -and (Test-Path -LiteralPath $normalLeasePath -PathType Leaf) `
            -and -not (Test-Path -LiteralPath $relocatedNormalLeasePath)
        ) 'Renamed exact owned lease cleanup did not find its identity or preserve the original-path replacement.'
        [void](Remove-ExactOwnedFile -Path $normalLeasePath -ExpectedIdentity $normalPathReplacementIdentity)

        $lowerExclusivePath = Join-Path $leaseFixtureRoot 'exclusive.lease'
        $lowerExclusiveReceipt = New-OwnedLeaseFile -Path $lowerExclusivePath -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N'))
        $lowerExclusiveRecords = @(Get-StrictLeaseEntryRecords -Root $leaseFixtureRoot)
        Assert-LauncherContract ($lowerExclusiveRecords.Count -eq 1 -and [bool]$lowerExclusiveRecords[0].is_exclusive) 'Strict lease enumeration did not recognize lowercase exclusive.lease case-insensitively.'
        [void](Remove-OwnedLeaseFile -Receipt $lowerExclusiveReceipt -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -LeaseDirectory $leaseFixtureRoot -AllowNonCanonicalLeaseRootForTest)

        $peerOneReceipt = New-OwnedLeaseFile -Path (Join-Path $leaseFixtureRoot 'peer-one.lease') -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N'))
        $peerTwoReceipt = New-OwnedLeaseFile -Path (Join-Path $leaseFixtureRoot 'peer-two.lease') -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N'))
        $sameWorktreePeerRejected = $false
        try { [void](Assert-NoLivePeerLeaseForWorktree -LeaseRecords @(Get-StrictLeaseEntryRecords -Root $leaseFixtureRoot) -Root $projectRoot -OwnedLeaseReceipt $peerOneReceipt) }
        catch { $sameWorktreePeerRejected = $_.Exception.Message -match 'already reserves this exact candidate worktree' }
        Assert-LauncherContract $sameWorktreePeerRejected 'A second live lease was admitted for the exact same worktree.'
        [void](Remove-OwnedLeaseFile -Receipt $peerOneReceipt -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -LeaseDirectory $leaseFixtureRoot -AllowNonCanonicalLeaseRootForTest)
        [void](Remove-OwnedLeaseFile -Receipt $peerTwoReceipt -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -LeaseDirectory $leaseFixtureRoot -AllowNonCanonicalLeaseRootForTest)

        $deadLeasePath = Join-Path $leaseFixtureRoot 'dead-owner.lease'
        $deadLeaseReceipt = New-OwnedLeaseFile -Path $deadLeasePath -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N'))
        $deadLines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in [System.IO.File]::ReadAllLines($deadLeasePath)) {
            if ($line.StartsWith('owner_start_ticks=', [System.StringComparison]::Ordinal)) { [void]$deadLines.Add('owner_start_ticks=' + [string]([long]$selfIdentity.start_ticks - 1)); continue }
            if ($line.StartsWith('owner_start_utc=', [System.StringComparison]::Ordinal)) { [void]$deadLines.Add('owner_start_utc=' + [datetime]::new(([long]$selfIdentity.start_ticks - 1), [DateTimeKind]::Utc).ToString('o')); continue }
            if ($line.StartsWith('owner_key=', [System.StringComparison]::Ordinal)) { [void]$deadLines.Add(('owner_key={0}|{1}|{2}' -f $PID, ([long]$selfIdentity.start_ticks - 1), [string]$selfIdentity.name)); continue }
            [void]$deadLines.Add($line)
        }
        [System.IO.File]::WriteAllText($deadLeasePath, (($deadLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
        [void](Clear-StaleGodotLeases -Root $leaseFixtureRoot -AllowNonCanonicalForTest)
        Assert-LauncherContract (-not (Test-Path -LiteralPath $deadLeasePath)) 'A positively dead exact lease was not cleared.'

        $malformedLeasePath = Join-Path $leaseFixtureRoot 'malformed.lease'
        [System.IO.File]::WriteAllText($malformedLeasePath, "schema=broken`nnot-a-field`n")
        $malformedLeaseIdentity = Get-FileSystemEntryIdentity -Path $malformedLeasePath
        $malformedLeasePreserved = $false
        try { [void](Clear-StaleGodotLeases -Root $leaseFixtureRoot -AllowNonCanonicalForTest) }
        catch { $malformedLeasePreserved = Test-FileSystemEntryMatchesIdentity -ExpectedIdentity $malformedLeaseIdentity }
        Assert-LauncherContract $malformedLeasePreserved 'Malformed stale lease metadata was deleted instead of preserved as unverifiable.'
        [void](Remove-ExactOwnedFile -Path $malformedLeasePath -ExpectedIdentity $malformedLeaseIdentity)

        $lockedLeasePath = Join-Path $leaseFixtureRoot 'locked-unverifiable.lease'
        [System.IO.File]::WriteAllText($lockedLeasePath, "locked`n")
        $lockedLeaseIdentity = Get-FileSystemEntryIdentity -Path $lockedLeasePath
        $lockedLeaseStream = [System.IO.FileStream]::new($lockedLeasePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        try {
            $lockedLeasePreserved = $false
            try { [void](Clear-StaleGodotLeases -Root $leaseFixtureRoot -AllowNonCanonicalForTest) }
            catch { $lockedLeasePreserved = Test-Path -LiteralPath $lockedLeasePath -PathType Leaf }
            Assert-LauncherContract $lockedLeasePreserved 'Unreadable lease hash/metadata was deleted instead of preserved as unverifiable.'
        }
        finally { $lockedLeaseStream.Dispose() }
        [void](Remove-ExactOwnedFile -Path $lockedLeasePath -ExpectedIdentity $lockedLeaseIdentity)

        $partialReplacementPath = Join-Path $leaseFixtureRoot 'partial-replacement.lease'
        $partialReplacementRejected = $false
        try {
            [void](New-OwnedLeaseFile -Path $partialReplacementPath -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N')) -ForcePartialReplacementForTest)
        }
        catch { $partialReplacementRejected = $true }
        $partialTemporaryReplacement = @(Get-ChildItem -LiteralPath $leaseFixtureRoot -Force | Where-Object { $_.Name -like '.rw06_6-lease-*.tmp' })
        $partialOwnedOriginal = @(Get-ChildItem -LiteralPath $leaseFixtureRoot -Force | Where-Object { $_.Name -like '.rw06_6-lease-*.tmp.owned-original' })
        Assert-LauncherContract ($partialReplacementRejected -and $partialTemporaryReplacement.Count -eq 1 -and $partialOwnedOriginal.Count -eq 1) 'Lease partial-write cleanup deleted or accepted a path replacement instead of retaining both objects.'
        foreach ($partialObject in @($partialTemporaryReplacement + $partialOwnedOriginal)) {
            $partialObjectIdentity = Get-FileSystemEntryIdentity -Path $partialObject.FullName
            [void](Remove-ExactOwnedFile -Path $partialObject.FullName -ExpectedIdentity $partialObjectIdentity)
        }

        $postMoveReplacementPath = Join-Path $leaseFixtureRoot 'post-move-replacement.lease'
        $postMoveReplacementRejected = $false
        try {
            [void](New-OwnedLeaseFile -Path $postMoveReplacementPath -Root $projectRoot -Commit $leaseProbeCommit -Tree $leaseProbeTree -OwnerIdentity $selfIdentity -Nonce ([guid]::NewGuid().ToString('N')) -ForcePostMoveReplacementForTest)
        }
        catch { $postMoveReplacementRejected = $_.Exception.Message -match 'identity changed' }
        Assert-LauncherContract (
            $postMoveReplacementRejected `
            -and (Test-Path -LiteralPath $postMoveReplacementPath -PathType Leaf) `
            -and (Test-Path -LiteralPath ($postMoveReplacementPath + '.owned-original') -PathType Leaf)
        ) 'Lease post-move copied replacement was accepted or either object was deleted.'
        foreach ($postMoveObjectPath in @($postMoveReplacementPath, ($postMoveReplacementPath + '.owned-original'))) {
            $postMoveObjectIdentity = Get-FileSystemEntryIdentity -Path $postMoveObjectPath
            [void](Remove-ExactOwnedFile -Path $postMoveObjectPath -ExpectedIdentity $postMoveObjectIdentity)
        }

        $leaseLikeDirectory = Join-Path $leaseFixtureRoot 'directory.lease'
        [void][System.IO.Directory]::CreateDirectory($leaseLikeDirectory)
        $leaseLikeDirectoryIdentity = Get-FileSystemEntryIdentity -Path $leaseLikeDirectory
        $directoryLeaseRejected = $false
        try { [void](Get-StrictLeaseEntryRecords -Root $leaseFixtureRoot) } catch { $directoryLeaseRejected = $_.Exception.Message -match 'normal file' }
        Assert-LauncherContract $directoryLeaseRejected 'Strict lease enumeration hid or accepted a .lease directory.'
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $leaseLikeDirectory -QuarantinePath ($leaseLikeDirectory + '.delete') -ExpectedRootIdentity $leaseLikeDirectoryIdentity)

        $leaseLinkTarget = Join-Path $leaseProbeRoot 'link-target'
        [void][System.IO.Directory]::CreateDirectory($leaseLinkTarget)
        $leaseLinkTargetIdentity = Get-FileSystemEntryIdentity -Path $leaseLinkTarget
        $leaseLikeJunction = Join-Path $leaseFixtureRoot 'junction.lease'
        [void](New-Item -ItemType Junction -Path $leaseLikeJunction -Target $leaseLinkTarget)
        $leaseLikeJunctionIdentity = Get-FileSystemEntryIdentity -Path $leaseLikeJunction -AllowReparse
        $junctionLeaseRejected = $false
        try { [void](Get-StrictLeaseEntryRecords -Root $leaseFixtureRoot) } catch { $junctionLeaseRejected = $_.Exception.Message -match 'normal file' }
        Assert-LauncherContract $junctionLeaseRejected 'Strict lease enumeration hid or accepted a .lease reparse object.'
        [void](Remove-ExactOwnedReparseEntry -Path $leaseLikeJunction -ExpectedIdentity $leaseLikeJunctionIdentity)
        [void](Remove-ExactOwnedDirectoryTree -OwnedPath $leaseLinkTarget -QuarantinePath ($leaseLinkTarget + '.delete') -ExpectedRootIdentity $leaseLinkTargetIdentity)
    }
    finally {
        if ($null -ne $leaseProbeReceipt) {
            Remove-ExactValidateOnlySelftestRoot -Receipt $leaseProbeReceipt
        }
    }

    $environmentProbeName = 'RW06_6_ENV_RESTORE_PROBE'
    $environmentProbeOriginal = [Environment]::GetEnvironmentVariable($environmentProbeName, 'Process')
    try {
        [Environment]::SetEnvironmentVariable($environmentProbeName, 'mutated', 'Process')
        $environmentProbeSnapshot = [ordered]@{ $environmentProbeName = $environmentProbeOriginal }
        $environmentProbeResult = Restore-ProcessEnvironmentSafely -Snapshot $environmentProbeSnapshot
        Assert-LauncherContract ([bool]$environmentProbeResult.succeeded) 'Environment restoration helper rejected a valid snapshot.'
        Assert-LauncherContract ([Environment]::GetEnvironmentVariable($environmentProbeName, 'Process') -eq $environmentProbeOriginal) 'Environment restoration helper did not restore the exact prior value.'
        $environmentFailureProbe = Restore-ProcessEnvironmentSafely -Snapshot $environmentProbeSnapshot -ForceFailureForTest
        Assert-LauncherContract (-not [bool]$environmentFailureProbe.succeeded -and -not [string]::IsNullOrWhiteSpace([string]$environmentFailureProbe.error)) 'Environment restoration helper did not contain a forced failure.'
    }
    finally {
        [Environment]::SetEnvironmentVariable($environmentProbeName, $environmentProbeOriginal, 'Process')
    }

    $guardPath = Join-Path $projectRoot ($guardRelativePath.Replace('/', '\'))
    $fullContractPath = Join-Path $projectRoot ($fullContractRelativePath.Replace('/', '\'))
    $guardSource = [System.IO.File]::ReadAllText($guardPath)
    $fullContractSource = [System.IO.File]::ReadAllText($fullContractPath)
    Assert-LauncherContract (-not $guardPath.EndsWith('_contract.gd', [System.StringComparison]::OrdinalIgnoreCase)) 'Zero-preload guard would be auto-discovered as a root contract.'
    Assert-LauncherContract (-not [regex]::IsMatch($guardSource, '(?im)^\s*(?!#).*\b(?:preload|load|ResourceLoader)\s*\(')) 'Zero-preload guard contains a project resource load.'
    Assert-LauncherContract (-not [regex]::IsMatch($guardSource, '(?im)^\s*(?:extends|class_name|var|const|func)\b[^\r\n]*(?:RunState|GameModule|ContentLibrary|RngStream|PullTabsGame)')) 'Zero-preload guard has an executable project-global dependency.'
    Assert-LauncherContract (-not $guardSource.Contains('push_error')) 'Deliberate product RED must be print-only.'
    $fileCheckIndex = $guardSource.IndexOf('FileAccess.file_exists(PULL_TABS_SCRIPT_PATH)')
    $readIndex = $guardSource.IndexOf('FileAccess.get_file_as_string(PULL_TABS_SCRIPT_PATH)')
    $redIndex = $guardSource.IndexOf('RW06_6_PRODUCT_RED')
    $passIndex = $guardSource.IndexOf('RW06_6_GUARD_PASS')
    Assert-LauncherContract ($fileCheckIndex -ge 0 -and $fileCheckIndex -lt $readIndex -and $readIndex -lt $redIndex -and $redIndex -lt $passIndex) 'Guard source order is not fixture-check, read, PRODUCT_RED, GUARD_PASS.'
    Assert-LauncherContract ($guardSource.Contains('quit(10)') -and $guardSource.Contains('quit(2)') -and $guardSource.Contains('quit(0)')) 'Guard lacks distinct product-red, infrastructure, and pass native exits.'
    Assert-LauncherContract ($fullContractSource.Contains('const PullTabsScript := preload("res://scripts/games/pull_tabs.gd")')) 'Full root contract no longer exercises the production pull-tabs script.'
    Assert-LauncherContract ($fullContractSource.Contains('RW06_6_PULL_TAB_GLIMMER PASS')) 'Full root contract lost its PASS marker.'
    Assert-LauncherContract (-not [regex]::IsMatch($fullContractSource, '(?im)^\s*var\s+[A-Za-z_][A-Za-z0-9_]*\s*:=\s*game\.surface_action_command\s*\(')) 'Full root contract still relies on unsafe dynamic surface-action type inference.'

    $launcherSource = [System.IO.File]::ReadAllText($PSCommandPath)
    Assert-LauncherContract (-not [regex]::IsMatch($launcherSource, '(?im)^\s*Start-Process\b')) 'Launcher still invokes Start-Process.'
    Assert-LauncherContract (-not [regex]::IsMatch($launcherSource, '\.WaitForExit\(\s*\)')) 'Launcher contains an unbounded parameterless WaitForExit.'
    $launcherTokens = $null
    $launcherParseErrors = $null
    $launcherAst = [System.Management.Automation.Language.Parser]::ParseInput($launcherSource, [ref]$launcherTokens, [ref]$launcherParseErrors)
    Assert-LauncherContract ($launcherParseErrors.Count -eq 0) 'Launcher could not parse its own source for scoped static validation.'
    $validateOnlyAsts = @($launcherAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] `
            -and $node.Clauses.Count -eq 1 `
            -and $node.Clauses[0].Item1.Extent.Text.Trim() -ceq '$ValidateOnly'
    }, $true))
    Assert-LauncherContract ($validateOnlyAsts.Count -eq 1) 'Launcher must contain exactly one ValidateOnly statement AST.'
    $validateOnlyExtent = $validateOnlyAsts[0].Extent
    $runtimeLauncherSource = $launcherSource.Substring(0, $validateOnlyExtent.StartOffset) + $launcherSource.Substring($validateOnlyExtent.EndOffset)
    Assert-LauncherContract (-not $runtimeLauncherSource.Contains('Launcher source contract is missing:')) 'Runtime source-check region includes its own ValidateOnly checklist.'
    foreach ($required in @(
        'System.Diagnostics.ProcessStartInfo',
        'System.IO.FileStream',
        'ConvertTo-WindowsCommandLineArgument',
        'Get-StrictNativeExitCode',
        'Get-OwnedProcessStartProofFromException',
        'Test-CimCreationMatchesProcessStartTicks',
        "owned_process_identity",
        'process_start_provenance',
        'registration_process_identity',
        'Get-RegistryBootstrapArguments',
        'Test-RegistryBootstrapArguments',
        "'--recovery-mode', '--import'",
        'Get-RegistryLifecycleEvidence',
        'Test-RegistryLifecycleContract',
        'Get-RecoveryBootstrapDependencyCensus',
        'Test-RecoveryBootstrapDependencyCensus',
        'New-CounterpartAdmissionReceipt',
        'Assert-CounterpartAdmissionReceiptStable',
        'Get-CanonicalGodotIdentity',
        'Initialize-OwnedEvidenceRoot',
        'Write-AtomicSealedText',
        'Get-RetainedArtifactEntries',
        'Test-ExactRetainedArtifactSet',
        'Test-RetainedArtifactIntegrity',
        'completion-receipt.json',
        'RW06_6_COMPLETION_RECEIPT_SHA256',
        'Test-OwnedCreationStateProof',
        'DeleteTreeExact',
        'SetExtendedFileDispositionByHandle',
        'FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE',
        'Remove-ExactOwnedDirectoryTree',
        'New-Rw06FoundationRunner',
        'Get-AdjacentFoundationArguments',
        'Test-AdjacentFoundationArguments',
        'Test-AdjacentFoundationReport',
        'Test-AdjacentPhaseMarkerContract',
        'Get-FullContractArguments',
        'Test-FullContractArguments',
        'first_scan_done',
        'update_scripts_classes_done',
        'reimport_done_count',
        'main_scene_loaded',
        'foundation_main_loaded',
        'Assert-CleanExactCandidate',
        'Assert-Q016ApprovalSnapshot',
        'Assert-OwnedLease',
        'exclusiveLeaseReady',
        '$unleasedGodotRecords = @(Get-NewUnownedGodotRecords -BaselineKeys @())',
        'retained_descendant_records',
        'Test-PhaseMarkerContract -Phase Registry',
        'Test-PhaseMarkerContract -Phase Full',
        'Restore-ProcessEnvironmentSafely -Snapshot $oldEnvironment',
        'Remove-DedicatedProjectCache',
        'Write-ImportedArtifactManifest'
    )) {
        Assert-LauncherContract ($runtimeLauncherSource.Contains($required)) "Launcher runtime contract is missing: $required"
    }
    foreach ($requiredNativeRepair in @(
        'CreateJobObjectW',
        'JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE',
        'CREATE_SUSPENDED',
        'NtCreateFile',
        'FILE_CREATE',
        'CreateDirectoryIdentityGuardExclusive',
        'AssignProcessToJobObject',
        'ResumeThread',
        'QueryInformationJobObject',
        'TerminateJobObject',
        'ForceWrapperFailureAfterNativeReturnForTest',
        'Get-StrictLeaseEntryRecords',
        'ConvertFrom-ExactLeaseOwnerFields',
        'Remove-ExactOwnedFile',
        'DeleteEntryExact',
        'Test-ProcessHasExactLeaseAncestor',
        'Bind-OwnedCreationStateFromCreatorClaim',
        'Initialize-ExclusiveOwnedCacheRoot',
        'root_identity_at_creation',
        'root_identity_at_custody',
        'Get-OwnedCreationEvidenceSummary',
        'rw06_6_cache_creation_custody_v1',
        'rw06_6_serialized_final_census_v1',
        'RW06_6_CACHE_OWNER_PASS',
        'creator_job_custody',
        'Get-ValidateOnlyFixtureResidueInventory',
        'Assert-ValidateOnlyFixtureRootClean',
        'Read-NormalFilePinned',
        'New-OwnedEvidenceFileReservation',
        'Complete-OwnedEvidenceFileReservation',
        'Assert-AllRetainedArtifactReceiptsStable',
        'Get-ExactLeaseOwnerLiveness',
        'Assert-NoLivePeerLeaseForWorktree',
        'Stop-AllActiveOwnedJobsExact',
        'entry_type',
        'reparse_point',
        'Get-RetainedArtifactEntriesFromReceipts',
        'Move-RetainedArtifactReceiptAtomic',
        'Remove-ExactLateBoundSeals',
        'valid_only_with_matching_completion_receipt_and_whole_tree_readback'
    )) {
        Assert-LauncherContract ($runtimeLauncherSource.Contains($requiredNativeRepair)) "Launcher repaired runtime contract is missing: $requiredNativeRepair"
    }
    $activeStartDefinitions = @($launcherAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Start-RedirectedProcess' }, $true))
    $activeCompleteDefinitions = @($launcherAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Complete-RedirectedProcess' }, $true))
    Assert-LauncherContract ($activeStartDefinitions.Count -eq 1 -and $activeCompleteDefinitions.Count -eq 1) 'Launcher must expose exactly one active native-job Start/Complete implementation.'
    $legacySnapshotDefinitions = @($launcherAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -like '*LegacySnapshotRedirectedProcess*' }, $true))
    Assert-LauncherContract ($legacySnapshotDefinitions.Count -eq 0) 'Launcher retained a callable legacy snapshot/PID Start/Complete implementation.'
    Assert-LauncherContract ([regex]::Matches($runtimeLauncherSource, [regex]::Escape("'--recovery-mode', '--import'")).Count -eq 1) 'Launcher runtime must contain exactly one recovery-import argument pair.'
    Assert-LauncherContract (-not $runtimeLauncherSource.Contains("'--editor'")) 'Launcher runtime contains the known-leaking editor bootstrap mode.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$importArguments = @(Get-RegistryBootstrapArguments -Root $projectRoot)')) 'Runtime registry phase does not consume the exact recovery-import argument builder.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$fullArguments = @(Get-FullContractArguments -Root $projectRoot -ScriptPath $fullContractScriptPath)')) 'Runtime full phase does not consume the exact normal argument builder.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$registryArgumentsExact = Test-RegistryBootstrapArguments')) 'Runtime registry acceptance does not revalidate exact recorded arguments.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$registryLifecycle = Get-RegistryLifecycleEvidence -StdoutText $stdoutText -StderrText $stderrText -GodotLogText $godotLogText')) 'Runtime registry lifecycle extraction does not consume stdout, stderr, and Godot log together.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$registryLifecyclePassed = Test-RegistryLifecycleContract')) 'Runtime registry acceptance does not require lifecycle DONE markers and forbidden-load absence.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$preLaunchDependencyCensus = Get-RecoveryBootstrapDependencyCensus -Root $Root -InventoryMode EngineVisible')) 'Runtime recovery dependency census is not bound under the launch mutex to the complete engine-visible candidate tree.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$counterpartReceipt = New-CounterpartAdmissionReceipt')) 'Runtime does not seal explicit Red/Green counterpart admission before the lease.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('[void](Assert-CounterpartAdmissionReceiptStable -Receipt $CounterpartAdmissionReceipt)')) 'Runtime launch lock does not revalidate the counterpart receipt.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$godotIdentity = Get-CanonicalGodotIdentity -RequestedPath $GodotPath')) 'Runtime does not bind the canonical Godot path/SHA/version before lease or engine.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$evidenceReceipt = Initialize-OwnedEvidenceRoot')) 'Runtime does not atomically own a fresh approved EvidenceRoot.'
    $exclusiveCacheCreationIndex = $runtimeLauncherSource.IndexOf('$ownedCreationProof = Initialize-ExclusiveOwnedCacheRoot -State $ownedCreationProof')
    $cacheCreatorStartIndex = $runtimeLauncherSource.IndexOf('$started = Start-RedirectedProcess', [Math]::Max(0, $exclusiveCacheCreationIndex))
    $cacheHandshakeIndex = $runtimeLauncherSource.IndexOf('$ownedCreationProof = Complete-OwnedCacheCreationHandshake', [Math]::Max(0, $cacheCreatorStartIndex))
    Assert-LauncherContract (
        $exclusiveCacheCreationIndex -ge 0 `
        -and $cacheCreatorStartIndex -gt $exclusiveCacheCreationIndex `
        -and $cacheHandshakeIndex -gt $cacheCreatorStartIndex `
        -and -not $runtimeLauncherSource.Contains('DirAccess.make_dir_absolute(cache_path)')
    ) 'Runtime cache root is not atomically native-created and continuously guarded before its exact creator/job handshake.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$cacheRemovalReceipt = Remove-DedicatedProjectCache -Root $projectRoot -CacheRoot $projectCacheRoot -OwnedCreationProof $cacheCreationProof')) 'Runtime cache cleanup is not bound to the exact owned creation proof.'
    Assert-LauncherContract (-not $runtimeLauncherSource.Contains('Remove-Item -LiteralPath $quarantinePath -Recurse')) 'Runtime cache cleanup still performs a path-based recursive quarantine deletion.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains("Invoke-GodotPhase -Name 'foundation_pull_tabs_adjacent'")) 'Runtime does not execute the Green-only adjacent Foundation pull-tabs phase.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$summarySeal = Write-AtomicSealedText') -and $runtimeLauncherSource.Contains('$artifactManifestSeal = Write-AtomicSealedText')) 'Runtime summary/artifact manifest are not atomically sealed.'
    $terminalStartIndex = $runtimeLauncherSource.LastIndexOf('$artifactManifestSeal = [ordered]@{}')
    Assert-LauncherContract ($terminalStartIndex -ge 0) 'Runtime terminal-staging region is absent.'
    $terminalSource = $runtimeLauncherSource.Substring($terminalStartIndex)
    $pendingManifestIndex = $terminalSource.IndexOf('$artifactManifestSeal = Write-AtomicSealedText')
    $pendingCompletionIndex = $terminalSource.IndexOf('$completionReceiptSeal = Write-AtomicSealedText')
    $stagedIntegrityIndex = $terminalSource.IndexOf('$stagedEntries = @(Get-RetainedArtifactEntriesFromReceipts)')
    $publicManifestIndex = $terminalSource.IndexOf('$artifactManifestSeal = Move-RetainedArtifactReceiptAtomic')
    $preCompletionIntegrityIndex = $terminalSource.IndexOf('$preCompletionEntries = @(Get-RetainedArtifactEntriesFromReceipts)')
    $completionPublishIndex = $terminalSource.IndexOf('$completionReceiptSeal = Move-RetainedArtifactReceiptAtomic')
    $finalIntegrityIndex = $terminalSource.IndexOf('$finalEntries = @(Get-RetainedArtifactEntriesFromReceipts)')
    Assert-LauncherContract (
        $pendingManifestIndex -ge 0 `
        -and $pendingCompletionIndex -gt $pendingManifestIndex `
        -and $stagedIntegrityIndex -gt $pendingCompletionIndex `
        -and $publicManifestIndex -gt $stagedIntegrityIndex `
        -and $preCompletionIntegrityIndex -gt $publicManifestIndex `
        -and $completionPublishIndex -gt $preCompletionIntegrityIndex `
        -and $finalIntegrityIndex -gt $completionPublishIndex
    ) 'Runtime terminal evidence is not hidden-staged, receipt-read twice, completion-published last, and finally revalidated.'
    Assert-LauncherContract ($runtimeLauncherSource.Contains('$fullArgumentsExact = Test-FullContractArguments')) 'Runtime full acceptance does not revalidate exact normal recorded arguments.'
    $counterpartAdmissionIndex = $runtimeLauncherSource.IndexOf('$counterpartReceipt = New-CounterpartAdmissionReceipt')
    $leaseLoopIndex = $runtimeLauncherSource.IndexOf('while (-not $leaseOwned)')
    Assert-LauncherContract ($counterpartAdmissionIndex -ge 0 -and $leaseLoopIndex -gt $counterpartAdmissionIndex) 'Counterpart admission is not fail-closed before lease acquisition.'
    Assert-LauncherContract (
        $runtimeLauncherSource.Contains('$leasePath = $exclusiveLeasePath') `
        -and $runtimeLauncherSource.Contains('while (-not $exclusiveLeaseReady)') `
        -and $runtimeLauncherSource.Contains('$focusedLeaseRecords.Count -eq 0 -and $liveGodotRecords.Count -eq 0') `
        -and $runtimeLauncherSource.Contains("throw 'The sole Q-009 EXCLUSIVE.lease is not this exact launcher reservation.'")
    ) 'Runtime rw06_6 phases are not serialized behind their exact sole EXCLUSIVE.lease identity.'
    $environmentRestoreIndex = $runtimeLauncherSource.IndexOf('$environmentRestoreResult = Restore-ProcessEnvironmentSafely -Snapshot $oldEnvironment')
    $leaseCleanupIndex = $runtimeLauncherSource.LastIndexOf('$ownedLeaseRemovalReceipt = Remove-OwnedLeaseFile')
    Assert-LauncherContract ($environmentRestoreIndex -ge 0 -and $leaseCleanupIndex -gt $environmentRestoreIndex) 'Environment restoration is not contained ahead of exact lease cleanup.'
    $serializedCensusSealIndex = $runtimeLauncherSource.LastIndexOf('$serializedFinalCensusSeal = Write-AtomicSealedText')
    Assert-LauncherContract (
        $serializedCensusSealIndex -gt $environmentRestoreIndex `
        -and $leaseCleanupIndex -gt $serializedCensusSealIndex `
        -and $terminalStartIndex -gt $leaseCleanupIndex `
        -and $runtimeLauncherSource.Contains("captured_while_owned_exclusive_live = [bool]`$leaseOwned") `
        -and $runtimeLauncherSource.Contains("if (-not `$serializedFinalCensusPassed -or `$null -eq `$serializedFinalCensusSeal -or -not [bool]`$serializedFinalCensusSeal.finalized)") `
        -and $runtimeLauncherSource.Contains("Assert-RetainedArtifactReceiptStable -EvidenceReceipt `$evidenceReceipt -Receipt `$serializedFinalCensusSeal") `
        -and $runtimeLauncherSource.Contains("`$phase.Remove('owned_creation')")
    ) 'Serialized final census/raw-state sanitization/EXCLUSIVE release/terminal-publication order is not fail closed.'
    $outerJobCleanupIndex = $runtimeLauncherSource.LastIndexOf('$ownedJobCleanupReceipt = Stop-AllActiveOwnedJobsExact')
    $cacheCleanupIndex = $runtimeLauncherSource.IndexOf('$cacheRemovalReceipt = Remove-DedicatedProjectCache', [Math]::Max(0, $outerJobCleanupIndex))
    Assert-LauncherContract (
        $outerJobCleanupIndex -ge 0 `
        -and $cacheCleanupIndex -gt $outerJobCleanupIndex `
        -and $leaseCleanupIndex -gt $outerJobCleanupIndex `
        -and $runtimeLauncherSource.Contains("if (-not `$ownedJobsEmpty) { throw 'Preserving cache because exact owned job emptiness was not proven.' }") `
        -and $runtimeLauncherSource.Contains("if (-not `$ownedJobsEmpty) { throw 'Preserving exclusive lease because exact owned job emptiness was not proven.' }")
    ) 'Runtime cache/lease cleanup is not gated after the exact outer owned-job empty proof.'

    $malformedRejected = $false
    try { [void](Get-StrictNativeExitCode -RawValue $null) } catch { $malformedRejected = $true }
    Assert-LauncherContract $malformedRejected 'Strict native-exit validator accepted null.'
    $malformedRejected = $false
    try { [void](Get-StrictNativeExitCode -RawValue '0') } catch { $malformedRejected = $true }
    Assert-LauncherContract $malformedRejected 'Strict native-exit validator accepted a string exit.'

    $probeReceipt = $null
    $probeRoot = ''
    try {
        $probeReceipt = New-ValidateOnlySelftestRoot -RequiredNamePrefix 'launcher-selftest-'
        $probeRoot = [string]$probeReceipt.path
        $powerShellExe = Join-Path $PSHOME 'powershell.exe'
        Assert-LauncherContract (Test-Path -LiteralPath $powerShellExe -PathType Leaf) 'Windows PowerShell 5.1 process probe executable is unavailable.'
        $powerShellExecutableReadback = Read-NormalFilePinned -Path $powerShellExe
        $powerShellExecutableReceipt = [ordered]@{
            path = [System.IO.Path]::GetFullPath($powerShellExe)
            identity = $powerShellExecutableReadback.identity
            sha256 = [string]$powerShellExecutableReadback.sha256
        }
        $staleExecutablePath = Join-Path $probeRoot 'stale-executable-copy.exe'
        $staleExecutableOriginalPath = $staleExecutablePath + '.owned-original'
        [System.IO.File]::Copy($powerShellExe, $staleExecutablePath, $false)
        $staleExecutableReadback = Read-NormalFilePinned -Path $staleExecutablePath
        $staleExecutableReceipt = [ordered]@{ path = $staleExecutablePath; identity = $staleExecutableReadback.identity; sha256 = [string]$staleExecutableReadback.sha256 }
        [System.IO.File]::Move($staleExecutablePath, $staleExecutableOriginalPath)
        [System.IO.File]::Copy($staleExecutableOriginalPath, $staleExecutablePath, $false)
        $staleExecutableRejected = $false
        try {
            [void](Start-RedirectedProcess -FilePath $staleExecutablePath -Arguments @('-NoProfile', '-ProcessProbeChild') -StdoutPath (Join-Path $probeRoot 'stale-executable.stdout.log') -StderrPath (Join-Path $probeRoot 'stale-executable.stderr.log') -ProcessKind Exact -TimeoutSec 10 -ExpectedExecutableReceipt $staleExecutableReceipt)
        }
        catch { $staleExecutableRejected = $_.Exception.Message -match 'replacement file|receipt bytes changed' }
        Assert-LauncherContract (
            $staleExecutableRejected `
            -and (Test-Path -LiteralPath $staleExecutablePath -PathType Leaf) `
            -and (Test-Path -LiteralPath $staleExecutableOriginalPath -PathType Leaf)
        ) 'Executable launch admitted or deleted an identical-byte replacement under a stale native receipt.'

        $pinProbeStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '0') -StdoutPath (Join-Path $probeRoot 'native-pin.stdout.log') -StderrPath (Join-Path $probeRoot 'native-pin.stderr.log') -ProcessKind Exact -TimeoutSec 10 -ExpectedExecutableReceipt $powerShellExecutableReceipt -ForceExecutableSwapProbeForTest
        $pinProbeResult = Complete-RedirectedProcess -Started $pinProbeStarted -TimeoutSec 10 -ProcessKind Exact
        Assert-LauncherContract (
            $pinProbeResult.native_exit_observed `
            -and $pinProbeResult.native_exit_code -eq 0 `
            -and [bool]$pinProbeResult.job_empty `
            -and [bool]$pinProbeResult.job_custody.executable_swap_probe_rejected `
            -and (Test-NativeJobCustodyReceipt -Receipt $pinProbeResult.job_custody -RootIdentity $pinProbeResult.process_identity)
        ) 'Native executable custody did not reject a rename between pin and suspended CreateProcess or failed mapped-image verification.'
        $godotBeforeKeys = @(Get-LiveGodotIdentityRecords | ForEach-Object { [string]$_.key })
        $quoteEcho = 'space "quoted" value'
        $quoteTrailing = 'C:\path with space\'
        $zeroStdout = Join-Path $probeRoot 'zero.stdout.log'
        $zeroStderr = Join-Path $probeRoot 'zero.stderr.log'
        $zeroStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '0', '-ProbeEcho', $quoteEcho, '-ProbeTrailing', $quoteTrailing, '-ProbeEmpty', '') -StdoutPath $zeroStdout -StderrPath $zeroStderr -ProcessKind Exact -TimeoutSec 10
        $zeroResult = Complete-RedirectedProcess -Started $zeroStarted -TimeoutSec 10 -ProcessKind Exact
        $zeroOut = [System.IO.File]::ReadAllText($zeroStdout)
        $zeroErr = [System.IO.File]::ReadAllText($zeroStderr)
        Assert-LauncherContract (-not $zeroResult.timed_out -and $zeroResult.native_exit_observed -and $zeroResult.native_exit_code -eq 0 -and $zeroResult.native_exit_type -eq 'System.Int32' -and $zeroResult.effective_exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($zeroResult.error)) 'Direct-process zero probe did not return a clean integer zero.'
        Assert-LauncherContract ($zeroOut.Contains('RW06_6_PROCESS_PROBE_STDOUT') -and $zeroErr.Contains('RW06_6_PROCESS_PROBE_STDERR')) 'Direct-process zero probe did not drain both streams.'
        Assert-LauncherContract ($zeroOut.Contains('"echo":"space \"quoted\" value"') -and $zeroOut.Contains('"trailing":"C:\\path with space\\"') -and $zeroOut.Contains('"empty":""')) 'PS5.1 fallback quoting changed spaces, an embedded quote, trailing slash, or empty argument.'

    foreach ($treeProcessKind in @('Exact', 'Godot')) {
        $kindLabel = $treeProcessKind.ToLowerInvariant()
        $normalPrefix = $kindLabel + '-normal'
        $normalStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
            '-ProcessProbeTreeRoot', '-ProbePidDirectory', $probeRoot, '-ProbePidPrefix', $normalPrefix,
            '-ProbeLeafSleepMsec', '100', '-ProbeTreeWaitLeaf'
        ) -StdoutPath (Join-Path $probeRoot ($normalPrefix + '.stdout.log')) -StderrPath (Join-Path $probeRoot ($normalPrefix + '.stderr.log')) -ProcessKind $treeProcessKind -TimeoutSec 10
        $normalResult = Complete-RedirectedProcess -Started $normalStarted -TimeoutSec 10 -ProcessKind $treeProcessKind
        Assert-LauncherContract (
            -not $normalResult.timed_out `
            -and $normalResult.native_exit_observed `
            -and $normalResult.native_exit_code -eq 0 `
            -and [bool]$normalResult.job_empty `
            -and (Test-NativeJobCustodyReceipt -Receipt $normalResult.job_custody -RootIdentity $normalResult.process_identity) `
            -and (Test-Path -LiteralPath (Join-Path $probeRoot ($normalPrefix + '-intermediate.pid')) -PathType Leaf) `
            -and (Test-Path -LiteralPath (Join-Path $probeRoot ($normalPrefix + '-leaf.pid')) -PathType Leaf)
        ) "Three-level $treeProcessKind normal job probe failed suspended custody or empty completion."

        $timeoutPrefix = $kindLabel + '-timeout'
        $timeoutTreeStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
            '-ProcessProbeTreeRoot', '-ProbePidDirectory', $probeRoot, '-ProbePidPrefix', $timeoutPrefix,
            '-ProbeLeafSleepMsec', '10000'
        ) -StdoutPath (Join-Path $probeRoot ($timeoutPrefix + '.stdout.log')) -StderrPath (Join-Path $probeRoot ($timeoutPrefix + '.stderr.log')) -ProcessKind $treeProcessKind -TimeoutSec 1
        $leafPidPath = Join-Path $probeRoot ($timeoutPrefix + '-leaf.pid')
        $leafDeadline = [DateTime]::UtcNow.AddSeconds(3)
        while (-not (Test-Path -LiteralPath $leafPidPath -PathType Leaf) -and [DateTime]::UtcNow -lt $leafDeadline) { Start-Sleep -Milliseconds 10 }
        Assert-LauncherContract (Test-Path -LiteralPath $leafPidPath -PathType Leaf) "Three-level $treeProcessKind timeout probe did not reach its long leaf."
        $timeoutLeafPid = [int][System.IO.File]::ReadAllText($leafPidPath)
        $timeoutLeafProcess = Get-Process -Id $timeoutLeafPid -ErrorAction SilentlyContinue
        Assert-LauncherContract ($null -ne $timeoutLeafProcess) "Three-level $treeProcessKind timeout leaf was not live before exact job termination."
        $timeoutLeafIdentity = Get-ProcessIdentityRecord -Process $timeoutLeafProcess
        $timeoutTreeResult = Complete-RedirectedProcess -Started $timeoutTreeStarted -TimeoutSec 1 -ProcessKind $treeProcessKind
        Assert-LauncherContract (
            $timeoutTreeResult.timed_out `
            -and $timeoutTreeResult.effective_exit_code -eq 124 `
            -and [bool]$timeoutTreeResult.job_empty `
            -and @($timeoutTreeResult.job_members_before_termination).Count -ge 1 `
            -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $timeoutLeafIdentity)
        ) "Three-level $treeProcessKind timeout did not terminate its exact surviving leaf job."

        $reusePrefix = $kindLabel + '-reused-intermediate'
        $reuseStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
            '-ProcessProbeTreeRoot', '-ProbePidDirectory', $probeRoot, '-ProbePidPrefix', $reusePrefix,
            '-ProbeLeafSleepMsec', '10000'
        ) -StdoutPath (Join-Path $probeRoot ($reusePrefix + '.stdout.log')) -StderrPath (Join-Path $probeRoot ($reusePrefix + '.stderr.log')) -ProcessKind $treeProcessKind -TimeoutSec 1
        $reuseIntermediatePath = Join-Path $probeRoot ($reusePrefix + '-intermediate.pid')
        $reuseLeafPath = Join-Path $probeRoot ($reusePrefix + '-leaf.pid')
        $reuseDeadline = [DateTime]::UtcNow.AddSeconds(3)
        while ((-not (Test-Path -LiteralPath $reuseIntermediatePath -PathType Leaf) -or -not (Test-Path -LiteralPath $reuseLeafPath -PathType Leaf)) -and [DateTime]::UtcNow -lt $reuseDeadline) { Start-Sleep -Milliseconds 10 }
        Assert-LauncherContract ((Test-Path -LiteralPath $reuseIntermediatePath -PathType Leaf) -and (Test-Path -LiteralPath $reuseLeafPath -PathType Leaf)) "Three-level $treeProcessKind reused-intermediate probe did not establish its short intermediate and long leaf."
        $reuseLeafPid = [int][System.IO.File]::ReadAllText($reuseLeafPath)
        $reuseLeafProcess = Get-Process -Id $reuseLeafPid -ErrorAction SilentlyContinue
        Assert-LauncherContract ($null -ne $reuseLeafProcess) "Three-level $treeProcessKind reused-intermediate long leaf was not live."
        $reuseLeafIdentity = Get-ProcessIdentityRecord -Process $reuseLeafProcess
        # A second independently retained job is a hostile same-executable
        # replacement.  Cleanup of the first job must not use PID/name/ancestry
        # heuristics that could terminate this replacement.
        $replacementStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath (Join-Path $probeRoot ($reusePrefix + '.replacement.stdout.log')) -StderrPath (Join-Path $probeRoot ($reusePrefix + '.replacement.stderr.log')) -ProcessKind $treeProcessKind -TimeoutSec 10
        $replacementCompleted = $false
        try {
            $reuseResult = Complete-RedirectedProcess -Started $reuseStarted -TimeoutSec 1 -ProcessKind $treeProcessKind
            Assert-LauncherContract (
                $reuseResult.timed_out `
                -and [bool]$reuseResult.job_empty `
                -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $reuseLeafIdentity) `
                -and (Test-LiveProcessMatchesIdentity -ExpectedIdentity $replacementStarted.process_identity) `
                -and (@($replacementStarted.native_job.GetActiveProcessIds()) -contains [int]$replacementStarted.process_id)
            ) "Three-level $treeProcessKind job cleanup killed an unrelated same-executable replacement or retained its owned leaf."
            $replacementResult = Complete-RedirectedProcess -Started $replacementStarted -TimeoutSec 1 -ProcessKind $treeProcessKind
            $replacementCompleted = $true
            Assert-LauncherContract ($replacementResult.timed_out -and [bool]$replacementResult.job_empty -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $replacementResult.process_identity)) "Independent $treeProcessKind replacement job did not clean itself exactly."
        }
        finally {
            if (-not $replacementCompleted) { [void](Complete-RedirectedProcess -Started $replacementStarted -TimeoutSec 1 -ProcessKind $treeProcessKind) }
        }

        $setupPrefix = $kindLabel + '-post-native-return'
        $setupRejected = $false
        $setupProof = $null
        try {
            [void](Start-RedirectedProcess -FilePath $powerShellExe -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
                '-ProcessProbeTreeRoot', '-ProbePidDirectory', $probeRoot, '-ProbePidPrefix', $setupPrefix,
                '-ProbeLeafSleepMsec', '10000'
            ) -StdoutPath (Join-Path $probeRoot ($setupPrefix + '.stdout.log')) -StderrPath (Join-Path $probeRoot ($setupPrefix + '.stderr.log')) -ProcessKind $treeProcessKind -TimeoutSec 10 -ForceWrapperFailureAfterNativeReturnForTest -ForceWrapperFailureDelayMsecForTest 500)
        }
        catch { $setupRejected = $true; $setupProof = Get-OwnedProcessStartProofFromException -Exception $_.Exception }
        Assert-LauncherContract (
            $setupRejected `
            -and [bool]$setupProof.started `
            -and (Test-ExactLeaseOwnerIdentityShape -Identity $setupProof.process_identity) `
            -and [string]$setupProof.job_instance_id -cmatch '^[0-9a-f]{32}$' `
            -and [bool]$setupProof.job_suspended_create `
            -and [bool]$setupProof.job_assigned_before_resume `
            -and [bool]$setupProof.job_resumed_after_assign `
            -and [bool]$setupProof.job_kill_on_close `
            -and [bool]$setupProof.job_breakaway_disabled `
            -and @($setupProof.job_initial_membership).Count -eq 1 `
            -and [int]$setupProof.job_initial_membership[0] -eq [int]$setupProof.process_id `
            -and [bool]$setupProof.job_cleanup_proven `
            -and @($setupProof.job_members_before_cleanup).Count -ge 1 `
            -and @($setupProof.job_members_after_cleanup).Count -eq 0 `
            -and [bool]$setupProof.executable_handle_opened `
            -and [bool]$setupProof.executable_identity_verified `
            -and [bool]$setupProof.executable_sha256_verified `
            -and [bool]$setupProof.executable_ancestor_chain_pinned `
            -and [bool]$setupProof.executable_held_through_create `
            -and [bool]$setupProof.mapped_image_path_verified `
            -and [bool]$setupProof.mapped_image_identity_verified `
            -and [bool]$setupProof.mapped_image_sha256_verified `
            -and [bool]$setupProof.executable_held_through_resume
        ) "Three-level $treeProcessKind forced post-native-return setup failure lacked exact empty-job proof."
    }

    $pumpFailureStdout = Join-Path $probeRoot 'pump-failure.stdout.log'
    $pumpFailureStderr = Join-Path $probeRoot 'pump-failure.stderr.log'
    $pumpFailureObserved = $false
    $pumpFailurePid = 0
    $pumpFailureProof = [ordered]@{ started = $false; process_id = 0; process_identity = $null; provenance = 'none' }
    try {
        [void](Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath $pumpFailureStdout -StderrPath $pumpFailureStderr -ProcessKind Exact -TimeoutSec 15 -ForceSecondPumpFailureForTest)
    }
    catch {
        $pumpFailureObserved = $true
        $pumpFailureProof = Get-OwnedProcessStartProofFromException -Exception $_.Exception
        $pumpFailurePid = [int]$pumpFailureProof.process_id
    }
    Assert-LauncherContract (
        $pumpFailureObserved `
        -and [bool]$pumpFailureProof.started `
        -and $pumpFailurePid -gt 0 `
        -and (Test-ExactLeaseOwnerIdentityShape -Identity $pumpFailureProof.process_identity) `
        -and [string]$pumpFailureProof.provenance -ceq 'start_setup_exception' `
        -and [string]$pumpFailureProof.job_instance_id -cmatch '^[0-9a-f]{32}$' `
        -and [bool]$pumpFailureProof.job_suspended_create `
        -and [bool]$pumpFailureProof.job_assigned_before_resume `
        -and [bool]$pumpFailureProof.job_resumed_after_assign `
        -and [bool]$pumpFailureProof.job_kill_on_close `
        -and [bool]$pumpFailureProof.job_breakaway_disabled `
        -and @($pumpFailureProof.job_initial_membership).Count -eq 1 `
        -and [int]$pumpFailureProof.job_initial_membership[0] -eq $pumpFailurePid `
        -and [bool]$pumpFailureProof.job_cleanup_proven `
        -and @($pumpFailureProof.job_members_before_cleanup).Count -ge 1 `
        -and @($pumpFailureProof.job_members_after_cleanup).Count -eq 0 `
        -and [bool]$pumpFailureProof.executable_handle_opened `
        -and [bool]$pumpFailureProof.executable_identity_verified `
        -and [bool]$pumpFailureProof.executable_sha256_verified `
        -and [bool]$pumpFailureProof.executable_ancestor_chain_pinned `
        -and [bool]$pumpFailureProof.executable_held_through_create `
        -and [bool]$pumpFailureProof.mapped_image_path_verified `
        -and [bool]$pumpFailureProof.mapped_image_identity_verified `
        -and [bool]$pumpFailureProof.mapped_image_sha256_verified `
        -and [bool]$pumpFailureProof.executable_held_through_resume `
        -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $pumpFailureProof.process_identity)
    ) 'Post-resume native setup hostile probe did not preserve exact identity and empty-job cleanup proof.'

    $preResumeObserved = $false
    $preResumeProof = $null
    try {
        [void](Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath (Join-Path $probeRoot 'pre-resume.stdout.log') -StderrPath (Join-Path $probeRoot 'pre-resume.stderr.log') -ProcessKind Godot -TimeoutSec 15 -ExpectedExecutableReceipt $powerShellExecutableReceipt -ForceNativeFailureAfterAssignBeforeResumeForTest)
    }
    catch { $preResumeObserved = $true; $preResumeProof = Get-OwnedProcessStartProofFromException -Exception $_.Exception }
    Assert-LauncherContract (
        $preResumeObserved `
        -and [bool]$preResumeProof.started `
        -and (Test-ExactLeaseOwnerIdentityShape -Identity $preResumeProof.process_identity) `
        -and [string]$preResumeProof.job_instance_id -cmatch '^[0-9a-f]{32}$' `
        -and [bool]$preResumeProof.job_suspended_create `
        -and [bool]$preResumeProof.job_assigned_before_resume `
        -and -not [bool]$preResumeProof.job_resumed_after_assign `
        -and [bool]$preResumeProof.job_kill_on_close `
        -and [bool]$preResumeProof.job_breakaway_disabled `
        -and @($preResumeProof.job_initial_membership).Count -eq 1 `
        -and [int]$preResumeProof.job_initial_membership[0] -eq [int]$preResumeProof.process_id `
        -and [bool]$preResumeProof.job_cleanup_proven `
        -and @($preResumeProof.job_members_before_cleanup).Count -eq 1 `
        -and @($preResumeProof.job_members_after_cleanup).Count -eq 0 `
        -and [bool]$preResumeProof.executable_handle_opened `
        -and [bool]$preResumeProof.executable_identity_verified `
        -and [bool]$preResumeProof.executable_sha256_verified `
        -and [bool]$preResumeProof.executable_ancestor_chain_pinned `
        -and [bool]$preResumeProof.executable_held_through_create `
        -and [bool]$preResumeProof.mapped_image_path_verified `
        -and [bool]$preResumeProof.mapped_image_identity_verified `
        -and [bool]$preResumeProof.mapped_image_sha256_verified `
        -and -not [bool]$preResumeProof.executable_held_through_resume `
        -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $preResumeProof.process_identity)
    ) 'Post-assign/pre-resume hostile did not prove its suspended root was job-bound and exactly terminated.'

    $volumeBytes = 262144
    $exitStdout = Join-Path $probeRoot 'exit.stdout.log'
    $exitStderr = Join-Path $probeRoot 'exit.stderr.log'
    $probeStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeExitCode', '37', '-ProbeVolumeBytes', "$volumeBytes") -StdoutPath $exitStdout -StderrPath $exitStderr -ProcessKind Exact -TimeoutSec 15
    $probeResult = Complete-RedirectedProcess -Started $probeStarted -TimeoutSec 15 -ProcessKind Exact
    Assert-LauncherContract (-not $probeResult.timed_out -and $probeResult.native_exit_observed -and $probeResult.native_exit_code -eq 37 -and $probeResult.native_exit_type -eq 'System.Int32' -and $probeResult.effective_exit_code -eq 37 -and [string]::IsNullOrWhiteSpace($probeResult.error)) 'Direct-process nonzero probe did not return integer 37.'
    Assert-LauncherContract ((Get-Item -LiteralPath $exitStdout).Length -ge $volumeBytes -and (Get-Item -LiteralPath $exitStderr).Length -ge $volumeBytes) 'High-volume dual-pipe probe did not capture at least 256 KiB on each stream.'
    Assert-LauncherContract ([System.IO.File]::ReadAllText($exitStdout).Contains('RW06_6_PROCESS_PROBE_STDOUT_END') -and [System.IO.File]::ReadAllText($exitStderr).Contains('RW06_6_PROCESS_PROBE_STDERR_END')) 'High-volume dual-pipe probe did not drain both streams to their end markers.'

    $timeoutStdout = Join-Path $probeRoot 'timeout.stdout.log'
    $timeoutStderr = Join-Path $probeRoot 'timeout.stderr.log'
    $timeoutStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000', '-ProbeExitCode', '0') -StdoutPath $timeoutStdout -StderrPath $timeoutStderr -ProcessKind Exact -TimeoutSec 1
    $timeoutIdentity = $timeoutStarted.process_identity
    $timeoutResult = Complete-RedirectedProcess -Started $timeoutStarted -TimeoutSec 1 -ProcessKind Exact
    Assert-LauncherContract ($timeoutResult.timed_out -and $timeoutResult.effective_exit_code -eq 124 -and [bool]$timeoutResult.job_empty -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $timeoutIdentity)) 'Direct-process timeout probe did not return 124 with exact empty-job cleanup.'

    Assert-LauncherContract ($script:rw06ActiveOwnedJobs.Count -eq 0) 'Active-job registry was not empty before outer-finally hostiles.'
    $outerSetupStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath (Join-Path $probeRoot 'outer-setup.stdout.log') -StderrPath (Join-Path $probeRoot 'outer-setup.stderr.log') -ProcessKind Exact -TimeoutSec 15 -ExpectedExecutableReceipt $powerShellExecutableReceipt
    $outerSetupIdentity = $outerSetupStarted.process_identity
    $outerSetupFailureObserved = $false
    $outerSetupCleanup = $null
    try { throw 'Forced phase setup failure after exact native Start.' }
    catch { $outerSetupFailureObserved = $true }
    finally { $outerSetupCleanup = Stop-AllActiveOwnedJobsExact }
    Assert-LauncherContract (
        $outerSetupFailureObserved `
        -and [bool]$outerSetupCleanup.empty `
        -and $outerSetupCleanup.remaining_job_count -eq 0 `
        -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $outerSetupIdentity)
    ) 'Outer-finally cleanup did not prove exact job emptiness after a post-Start setup failure.'

    $outerCompletionStarted = Start-RedirectedProcess -FilePath $powerShellExe -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-ProcessProbeChild', '-ProbeSleepMsec', '10000') -StdoutPath (Join-Path $probeRoot 'outer-completion.stdout.log') -StderrPath (Join-Path $probeRoot 'outer-completion.stderr.log') -ProcessKind Exact -TimeoutSec 15 -ExpectedExecutableReceipt $powerShellExecutableReceipt
    $outerCompletionIdentity = $outerCompletionStarted.process_identity
    $outerCompletionFailureObserved = $false
    $outerCompletionCleanup = $null
    try { [void](Complete-RedirectedProcess -Started $outerCompletionStarted -TimeoutSec 15 -ProcessKind 'ForcedInvalidCompletionKind') }
    catch { $outerCompletionFailureObserved = $true }
    finally { $outerCompletionCleanup = Stop-AllActiveOwnedJobsExact }
    Assert-LauncherContract (
        $outerCompletionFailureObserved `
        -and [bool]$outerCompletionCleanup.empty `
        -and $outerCompletionCleanup.remaining_job_count -eq 0 `
        -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $outerCompletionIdentity)
    ) 'Outer-finally cleanup did not prove exact job emptiness after completion invocation failed.'
        Assert-LauncherContract (@(Get-NewUnownedGodotRecords -BaselineKeys $godotBeforeKeys).Count -eq 0) 'ValidateOnly observed a new unowned Godot process.'
    }
    finally {
        if ($null -ne $probeReceipt) {
            Remove-ExactValidateOnlySelftestRoot -Receipt $probeReceipt
        }
    }
    $finalFixtureGate = Assert-ValidateOnlyFixtureRootClean -Context 'ValidateOnly terminal census'
    Write-Host ("rw06_6 Q-009/multiphase launcher static and hostile contracts passed; fixture_residue={0} recovery_policy={1}." -f $finalFixtureGate.residue_count, $finalFixtureGate.recovery_policy)
    exit 0
}


$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
    $EvidenceRoot = Join-Path $approvedEvidenceParent ("contract-$stamp-$PID")
}
$evidenceReceipt = Initialize-OwnedEvidenceRoot -RequestedRoot $EvidenceRoot -ApprovedParent $approvedEvidenceParent -CandidateCommit $ExpectedCommit -CandidateTree $ExpectedTree -Role $ExpectedOutcome
$EvidenceRoot = [string]$evidenceReceipt.root
$script:rw06RetainedArtifactReceipts = [System.Collections.Generic.List[object]]::new()
$ownerClaimReadback = Read-NormalFilePinned -Path ([string]$evidenceReceipt.claim_path) -ExpectedIdentity $evidenceReceipt.claim_identity
$ownerClaimReceipt = [ordered]@{
    path = [string]$evidenceReceipt.claim_path
    relative_path = [System.IO.Path]::GetFileName([string]$evidenceReceipt.claim_path)
    entry_type = 'file'
    reparse_point = $false
    length = [long]$ownerClaimReadback.length
    sha256 = [string]$ownerClaimReadback.sha256
    identity = $evidenceReceipt.claim_identity
    finalized = $true
    guard_stream = $null
    atomic_no_overwrite = $true
    post_move_identity_verified = $true
    readback_verified = $true
}
[void](Register-RetainedArtifactReceipt -EvidenceReceipt $evidenceReceipt -Receipt $ownerClaimReceipt)
$summaryPath = Join-Path $EvidenceRoot 'summary.json'
$summaryShaPath = Join-Path $EvidenceRoot 'summary.sha256'
$artifactManifestPath = Join-Path $EvidenceRoot 'artifact-manifest.json'
$artifactManifestShaPath = Join-Path $EvidenceRoot 'artifact-manifest.sha256'
$completionReceiptPath = Join-Path $EvidenceRoot 'completion-receipt.json'
$phases = [System.Collections.Generic.List[object]]::new()
$skippedPhases = [System.Collections.Generic.List[object]]::new()
$overallExitCode = 1
$outcome = 'invalid'
$launcherError = ''
$candidateCommit = ''
$candidateTree = ''
$leaseNonce = [guid]::NewGuid().ToString('N')
$leasePath = $exclusiveLeasePath
$leaseOwned = $false
$exclusiveLeaseReady = $false
$leaseReceipt = $null
$ownedLeaseRemoved = $false
$ownedLeaseRemovalReceipt = [ordered]@{}
$serializedFinalCensusPassed = $false
$cacheAbsentInitially = $false
$cacheCleanupAuthorized = $false
$cacheCleanupSucceeded = $false
$ownedJobsEmpty = $false
$ownedJobCleanupReceipt = [ordered]@{ empty = $false; failures = @(); remaining_job_count = 0 }
$environmentRestorationSucceeded = $false
$guardCacheAbsent = $false
$registrationPhaseStarted = $false
$registrationProcessIdentity = $null
$cacheCreationProof = $null
$cacheRemovalReceipt = [ordered]@{}
$counterpartReceipt = [ordered]@{ accepted = $false }
$godotIdentity = [ordered]@{ accepted = $false }
$q016Snapshot = [ordered]@{
    answered_a = $false
    section_sha256 = ''
    file_sha256 = ''
    origin_main_commit = ''
    origin_main_blob = ''
    on_origin_main = $false
}
$harnessFiles = [ordered]@{}
$baselineGodotRecords = @()
$baselineGodotKeys = @()
$cacheSummary = [ordered]@{
    preexisting = $false
    absent_before_guard = $false
    absent_after_guard = $false
    registration_allowed = $false
    registration_started = $false
    registration_process_identity = $null
    created = $false
    global_class_cache_sha256 = ''
    uid_cache_sha256 = ''
    imported_manifest = [ordered]@{ count = 0; path = ''; sha256 = '' }
    creation_custody = $null
    cleanup_authorized = $false
    cleanup_receipt = [ordered]@{}
    removed_after_evidence = $false
}
$registryBootstrapSummary = [ordered]@{
    mode = 'recovery_import'
    required_arguments = @()
    arguments_exact = $false
    diagnostic_suppression_absent = $false
    preflight_dependency_census = [ordered]@{}
    dependency_census = [ordered]@{}
    dependency_census_validated = $false
    lifecycle = [ordered]@{
        first_scan_done = $false
        update_scripts_classes_done = $false
        reimport_done_count = 0
        main_scene_loaded = $false
        foundation_main_loaded = $false
    }
    lifecycle_contract_passed = $false
    class_cache_validated = $false
    uid_cache_validated = $false
    imported_manifest_validated = $false
    accepted = $false
}
$cacheOwnerSummary = [ordered]@{
    mode = 'builtins_only_godot_cache_owner'
    script = [ordered]@{}
    required_arguments = @()
    arguments_exact = $false
    marker_passed = $false
    creator_process_identity = $null
    creator_job_custody = $null
    creator_claim_bound = $false
    creation_custody = $null
    accepted = $false
}
$fullContractSummary = [ordered]@{
    mode = 'normal_headless_script'
    required_arguments = @()
    arguments_exact = $false
    recovery_mode_absent = $false
    import_mode_absent = $false
    diagnostic_suppression_absent = $false
    accepted = $false
}
$adjacentFoundationSummary = [ordered]@{
    mode = 'foundation_pull_tabs_suite'
    required_arguments = @()
    arguments_exact = $false
    runner = [ordered]@{}
    report = [ordered]@{}
    marker_contract_passed = $false
    diagnostics_clean = $false
    accepted = $false
    status = 'not_run'
}
$oldEnvironment = [ordered]@{
    APPDATA = [Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'Process')
    XDG_DATA_HOME = [Environment]::GetEnvironmentVariable('XDG_DATA_HOME', 'Process')
    XDG_CACHE_HOME = [Environment]::GetEnvironmentVariable('XDG_CACHE_HOME', 'Process')
    XDG_CONFIG_HOME = [Environment]::GetEnvironmentVariable('XDG_CONFIG_HOME', 'Process')
}
$startedUtc = [DateTime]::UtcNow
$postStatus = @('preflight-not-complete')
$postCommit = ''
$postTree = ''
$identityStable = $false
$newUnownedGodot = @()
$postGodotRecords = @()
$postLeases = @()
$postFocusedLeases = @()
$serializedFinalCensus = [ordered]@{}
$serializedFinalCensusSeal = [ordered]@{}

try {
    if ([string]::IsNullOrWhiteSpace($ExpectedOutcome)) { throw 'ExpectedOutcome Red or Green is required.' }
    if ($ExpectedOutcome -eq 'Green' -and -not $AuthorizeGreen) { throw 'ExpectedOutcome Green also requires -AuthorizeGreen.' }
    if ($ExpectedOutcome -eq 'Red' -and $AuthorizeGreen) { throw '-AuthorizeGreen is invalid for ExpectedOutcome Red.' }
    $godotIdentity = Get-CanonicalGodotIdentity -RequestedPath $GodotPath -RequiredSha256 $ExpectedGodotSha256 -RequiredVersion $ExpectedGodotVersion
    if ($ProcessTimeoutSec -lt 1) { throw 'ProcessTimeoutSec must be positive.' }
    if ($LeaseWaitTimeoutSec -lt 1) { throw 'LeaseWaitTimeoutSec must be positive.' }
    Assert-LauncherContract ($leaseRoot -ceq $canonicalLeaseRoot) 'Q-009 launcher did not resolve the exact canonical lease root.'
    Assert-LauncherContract ($projectCacheRoot -eq [System.IO.Path]::GetFullPath((Join-Path $projectRoot '.godot'))) 'Dedicated cache root resolution failed.'

    # Q-016 is a pre-lease gate for every rw06_6 engine phase, including RED.
    $q016Snapshot = Get-Q016ApprovalSnapshot
    if (-not $q016Snapshot.answered_a) {
        throw 'Q-016 is not canonically ANSWERED A; no rw06_6 Godot phase is authorized.'
    }
    Assert-ProjectCacheAbsent -Context 'RW06_6 preflight'
    Assert-ProjectCacheIgnored
    $cacheAbsentInitially = $true
    $cacheSummary.absent_before_guard = $true

    $candidateIdentity = Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree
    $candidateCommit = [string]$candidateIdentity.commit
    $candidateTree = [string]$candidateIdentity.tree
    $harnessFiles.launcher = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $launcherRelativePath
    $harnessFiles.guard = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $guardRelativePath
    $harnessFiles.full_contract = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $fullContractRelativePath
    $harnessFiles.product = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $productRelativePath
    $harnessFiles.foundation = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $foundationRelativePath
    $harnessFiles.split_runner_helper = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath $splitRunnerHelperRelativePath
    $harnessFiles.project = Get-TrackedFileIdentity -Root $projectRoot -Commit $candidateCommit -RelativePath 'project.godot'
    $counterpartReceipt = New-CounterpartAdmissionReceipt -CurrentRole $ExpectedOutcome -CurrentRoot $projectRoot -CurrentCommit $candidateCommit -CurrentTree $candidateTree -OtherRoot $CounterpartRoot -RequiredOtherCommit $ExpectedCounterpartCommit -RequiredOtherTree $ExpectedCounterpartTree -LauncherSha256 $ExpectedLauncherSha256 -LauncherGitBlob $ExpectedLauncherGitBlob -GuardSha256 $ExpectedGuardSha256 -GuardGitBlob $ExpectedGuardGitBlob -FullContractSha256 $ExpectedFullContractSha256 -FullContractGitBlob $ExpectedFullContractGitBlob
    $registryBootstrapSummary.preflight_dependency_census = Get-RecoveryBootstrapDependencyCensus -Root $projectRoot -InventoryMode EngineVisible
    if (-not (Test-RecoveryBootstrapDependencyCensus -Census $registryBootstrapSummary.preflight_dependency_census)) {
        throw 'Recovery-mode registry bootstrap would suppress an engine-visible tracked, ignored, untracked, executable, addon, editor-plugin, GDExtension, @tool, or autoload dependency.'
    }

    $profileRoot = Join-Path $EvidenceRoot 'profile'
    [void](New-OwnedEvidenceSubdirectory -EvidenceReceipt $evidenceReceipt -DestinationPath $profileRoot)
    $appData = Join-Path $profileRoot 'AppData\Roaming'
    $localAppData = Join-Path $profileRoot 'AppData\Local'
    $xdgData = Join-Path $profileRoot 'xdg\data'
    $xdgCache = Join-Path $profileRoot 'xdg\cache'
    $xdgConfig = Join-Path $profileRoot 'xdg\config'
    @($appData, $localAppData, $xdgData, $xdgCache, $xdgConfig) | ForEach-Object {
        [void](New-OwnedEvidenceDirectoryChain -EvidenceReceipt $evidenceReceipt -DestinationPath $_)
    }

    $generatedRoot = Join-Path $EvidenceRoot 'generated'
    [void](New-OwnedEvidenceSubdirectory -EvidenceReceipt $evidenceReceipt -DestinationPath $generatedRoot)
    $cacheOwnerScriptPath = Join-Path $generatedRoot 'rw06_6_cache_owner.gd'
    $cacheOwnerSummary.script = New-Rw06CacheOwnerScript -DestinationPath $cacheOwnerScriptPath -EvidenceReceipt $evidenceReceipt
    if (-not [bool]$cacheOwnerSummary.script.builtins_only) { throw 'Generated cache-owner phase gained a project-global dependency.' }

    [void](Assert-NormalLeaseRoot -Root $leaseRoot -RequireCanonical)
    $launcherOwnerIdentity = Get-ProcessIdentityRecord -Process (Get-Process -Id $PID)
    if (-not (Test-ExactLeaseOwnerIdentityShape -Identity $launcherOwnerIdentity)) { throw 'Launcher process could not establish exact lease-owner identity.' }
    $baselineGodotRecords = @(Get-LiveGodotIdentityRecords)
    $baselineGodotKeys = @($baselineGodotRecords | ForEach-Object { [string]$_.key })
    $leaseDeadline = [DateTime]::UtcNow.AddSeconds($LeaseWaitTimeoutSec)
    while (-not $leaseOwned) {
        if ([DateTime]::UtcNow -ge $leaseDeadline) { throw 'Timed out waiting to claim Q-009 EXCLUSIVE.lease.' }
        $mutex = [System.Threading.Mutex]::new($false, $launchMutexName)
        $mutexOwned = $false
        try {
            $mutexOwned = $mutex.WaitOne(5000)
            if (-not $mutexOwned) { continue }
            [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
            [void](Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree)
            [void](Assert-CounterpartAdmissionReceiptStable -Receipt $counterpartReceipt)
            [void](Get-CanonicalGodotIdentity -RequestedPath $GodotPath -RequiredSha256 $ExpectedGodotSha256 -RequiredVersion $ExpectedGodotVersion)
            Clear-StaleGodotLeases
            $leaseRecords = @(Get-StrictLeaseEntryRecords -Root $leaseRoot -RequireCanonical)
            [void](Assert-NoLivePeerLeaseForWorktree -LeaseRecords $leaseRecords -Root $projectRoot)
            $exclusiveRecords = @($leaseRecords | Where-Object { [bool]$_.is_exclusive })
            $unleasedGodotCount = @(Get-NewUnownedGodotRecords -BaselineKeys @()).Count
            if ($unleasedGodotCount -gt 0) {
                throw 'An unleased Godot process exists; refusing rw06_6 lease acquisition.'
            }
            if ($exclusiveRecords.Count -eq 0) {
                $leaseReceipt = New-OwnedLeaseFile -Path $leasePath -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree -OwnerIdentity $launcherOwnerIdentity -Nonce $leaseNonce
                $leaseOwned = $true
            }
        }
        finally {
            if ($mutexOwned) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
        if (-not $leaseOwned) { Start-Sleep -Seconds 2 }
    }

    while (-not $exclusiveLeaseReady) {
        if ([DateTime]::UtcNow -ge $leaseDeadline) { throw 'Timed out waiting for every peer lease and Godot process to drain behind EXCLUSIVE.lease.' }
        $mutex = [System.Threading.Mutex]::new($false, $launchMutexName)
        $mutexOwned = $false
        try {
            $mutexOwned = $mutex.WaitOne(5000)
            if (-not $mutexOwned) { continue }
            [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
            [void](Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree)
            [void](Assert-CounterpartAdmissionReceiptStable -Receipt $counterpartReceipt)
            Clear-StaleGodotLeases
            $leaseRecords = @(Get-StrictLeaseEntryRecords -Root $leaseRoot -RequireCanonical)
            [void](Assert-OwnedLease -Receipt $leaseReceipt -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree)
            $exclusiveRecords = @($leaseRecords | Where-Object { [bool]$_.is_exclusive })
            $focusedLeaseRecords = @($leaseRecords | Where-Object { -not [bool]$_.is_exclusive })
            if (
                $exclusiveRecords.Count -ne 1 `
                -or -not (Test-FileSystemObjectsShareIdentity -Left $exclusiveRecords[0].identity -Right $leaseReceipt.file_identity)
            ) { throw 'EXCLUSIVE.lease identity changed while waiting for serialized readiness.' }
            $liveGodotRecords = @(Get-LiveGodotIdentityRecords)
            $unleasedGodotRecords = @(Get-NewUnownedGodotRecords -BaselineKeys @())
            if ($unleasedGodotRecords.Count -gt 0) { throw 'An unleased Godot process appeared while waiting behind EXCLUSIVE.lease.' }
            if ($focusedLeaseRecords.Count -eq 0 -and $liveGodotRecords.Count -eq 0) {
                $exclusiveLeaseReady = $true
            }
        }
        finally {
            if ($mutexOwned) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
        if (-not $exclusiveLeaseReady) { Start-Sleep -Seconds 2 }
    }

    [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
    [void](Assert-CleanExactCandidate $projectRoot $ExpectedCommit $ExpectedTree)
    [void](Assert-CounterpartAdmissionReceiptStable -Receipt $counterpartReceipt)
    [void](Assert-OwnedLease -Receipt $leaseReceipt -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree)
    $env:APPDATA = $appData
    $env:LOCALAPPDATA = $localAppData
    $env:XDG_DATA_HOME = $xdgData
    $env:XDG_CACHE_HOME = $xdgCache
    $env:XDG_CONFIG_HOME = $xdgConfig

    $guardArguments = @(
        '--headless', '--verbose', '--disable-crash-handler',
        '--audio-driver', 'Dummy', '--path', $projectRoot,
        '--script', $guardScriptPath
    )
    $guardPhase = Invoke-GodotPhase -Name 'source_guard' -Arguments $guardArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeaseReceipt $leaseReceipt -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot (Join-Path $EvidenceRoot '01-source-guard') -EvidenceReceipt $evidenceReceipt -CounterpartAdmissionReceipt $counterpartReceipt -RequiredGodotSha256 $ExpectedGodotSha256 -RequiredGodotVersion $ExpectedGodotVersion -TimeoutSec $ProcessTimeoutSec -TrackedInputReceipts @($harnessFiles.guard)
    [void]$phases.Add($guardPhase)
    $unexpectedRedDiagnostics = @(Get-UnexpectedRedDiagnostics -Diagnostics @($guardPhase.diagnostics))
    $disposition = Resolve-GuardDisposition -NativeExitCode ([int]$guardPhase.native_exit_code) -NativeExitObserved ([bool]$guardPhase.native_exit_observed) -EffectiveExitCode ([int]$guardPhase.effective_exit_code) -TimedOut ([bool]$guardPhase.timed_out) -RunnerError ([string]$guardPhase.launcher_error) -ProductRedMarkerSeen ([bool]$guardPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$guardPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$guardPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$guardPhase.full_pass_marker) -UnexpectedDiagnosticCount $unexpectedRedDiagnostics.Count

    $guardCacheAbsent = -not (Test-Path -LiteralPath $projectCacheRoot)
    $cacheSummary.absent_after_guard = $guardCacheAbsent
    if (-not $guardCacheAbsent) {
        throw 'Zero-preload source guard created or borrowed .godot/global-class/UID/imported state; evidence is invalid.'
    }

    if ($ExpectedOutcome -eq 'Red' -and $disposition -eq 'valid_red') {
        $outcome = 'valid_red'
        $overallExitCode = 0
        [void]$skippedPhases.Add([ordered]@{ name = 'cache_ownership'; reason = 'ExpectedOutcome Red stops after exact guard native exit 10.' })
        [void]$skippedPhases.Add([ordered]@{ name = 'global_class_registration'; reason = 'ExpectedOutcome Red stops after exact guard native exit 10.' })
        [void]$skippedPhases.Add([ordered]@{ name = 'full_contract'; reason = 'ExpectedOutcome Red stops before registry/full contract.' })
        [void]$skippedPhases.Add([ordered]@{ name = 'foundation_pull_tabs_adjacent'; reason = 'ExpectedOutcome Red stops before the Green-only adjacent Foundation phase.' })
        $adjacentFoundationSummary.status = 'skipped_red'
    }
    elseif ($ExpectedOutcome -eq 'Green' -and $disposition -eq 'green_handoff') {
        [void](Assert-Q016ApprovalSnapshot -ExpectedSectionSha256 $q016Snapshot.section_sha256)
        $cacheSummary.registration_allowed = $true
        Assert-ProjectCacheAbsent -Context 'RW06_6 pre-import handoff'
        $cacheCreationProof = New-OwnedCreationState -Path $projectCacheRoot
        $cacheOwnerArguments = @(Get-CacheOwnerArguments -Root $projectRoot -ScriptPath ([string]$cacheOwnerSummary.script.resource_path) -Nonce ([string]$cacheCreationProof.nonce) -Commit $candidateCommit -Tree $candidateTree)
        $cacheOwnerSummary.required_arguments = @($cacheOwnerArguments)
        $cacheOwnerEvidenceRoot = Join-Path $EvidenceRoot '02-cache-ownership'
        $cacheOwnerPhase = Invoke-GodotPhase -Name 'cache_ownership' -Arguments $cacheOwnerArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeaseReceipt $leaseReceipt -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot $cacheOwnerEvidenceRoot -EvidenceReceipt $evidenceReceipt -CounterpartAdmissionReceipt $counterpartReceipt -RequiredGodotSha256 $ExpectedGodotSha256 -RequiredGodotVersion $ExpectedGodotVersion -TimeoutSec $ProcessTimeoutSec -OwnedCreationState $cacheCreationProof -RequiredInputReceipts @($cacheOwnerSummary.script.receipt)
        [void]$phases.Add($cacheOwnerPhase)
        $cacheOwnerLogPath = Join-Path $cacheOwnerEvidenceRoot 'godot.log'
        $cacheOwnerSummary.arguments_exact = Test-CacheOwnerArguments -Arguments @($cacheOwnerPhase.arguments) -Root $projectRoot -ScriptPath ([string]$cacheOwnerSummary.script.resource_path) -Nonce ([string]$cacheCreationProof.nonce) -Commit $candidateCommit -Tree $candidateTree -GodotLogPath $cacheOwnerLogPath
        $cacheOwnerSummary.marker_passed = (
            [bool]$cacheOwnerPhase.cache_owner_pass_marker `
            -and [regex]::IsMatch(
                [string]$cacheOwnerPhase.stdout_text,
                ('(?m)^RW06_6_CACHE_OWNER_PASS nonce=' + [regex]::Escape([string]$cacheCreationProof.nonce) + ' pid=' + [string][int]$cacheOwnerPhase.process_id + '\s*$')
            )
        )
        if (
            -not $cacheOwnerPhase.native_exit_observed `
            -or $cacheOwnerPhase.native_exit_code -ne 0 `
            -or $cacheOwnerPhase.effective_exit_code -ne 0 `
            -or $cacheOwnerPhase.timed_out `
            -or -not [string]::IsNullOrWhiteSpace([string]$cacheOwnerPhase.launcher_error) `
            -or -not [bool]$cacheOwnerPhase.job_empty `
            -or -not [bool]$cacheOwnerPhase.diagnostics_clean `
            -or -not [bool]$cacheOwnerSummary.arguments_exact `
            -or -not [bool]$cacheOwnerSummary.marker_passed `
            -or [bool]$cacheOwnerPhase.product_red_marker `
            -or [bool]$cacheOwnerPhase.guard_pass_marker `
            -or [bool]$cacheOwnerPhase.infra_failure_marker `
            -or [bool]$cacheOwnerPhase.full_pass_marker
        ) { throw 'Built-ins-only Godot cache-owner phase failed closed.' }
        $cacheCreationProof = Bind-OwnedCreationStateFromCreatorClaim -State $cacheCreationProof -CreatorProcessIdentity $cacheOwnerPhase.process_identity -CreatorJobCustody $cacheOwnerPhase.job_custody -ExpectedCommit $candidateCommit -ExpectedTree $candidateTree
        [void](Assert-OwnedCreationStateStable -State $cacheCreationProof)
        $cacheOwnerPhase.cache_creation_custody = Get-OwnedCreationEvidenceSummary -State $cacheCreationProof
        $cacheOwnerSummary.creator_process_identity = $cacheOwnerPhase.process_identity
        $cacheOwnerSummary.creator_job_custody = $cacheOwnerPhase.job_custody
        $cacheOwnerSummary.creator_claim_bound = $true
        $cacheOwnerSummary.creation_custody = $cacheOwnerPhase.cache_creation_custody
        $cacheOwnerSummary.accepted = $true
        $cacheSummary.created = $true
        $cacheSummary.creation_custody = $cacheOwnerPhase.cache_creation_custody

        $importArguments = @(Get-RegistryBootstrapArguments -Root $projectRoot)
        $registryBootstrapSummary.required_arguments = @($importArguments)
        $importEvidenceRoot = Join-Path $EvidenceRoot '03-global-class-registration'
        $importPhase = Invoke-GodotPhase -Name 'global_class_registration' -Arguments $importArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeaseReceipt $leaseReceipt -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot $importEvidenceRoot -EvidenceReceipt $evidenceReceipt -CounterpartAdmissionReceipt $counterpartReceipt -RequiredGodotSha256 $ExpectedGodotSha256 -RequiredGodotVersion $ExpectedGodotVersion -TimeoutSec $ProcessTimeoutSec -OwnedCreationState $cacheCreationProof -TrackedInputReceipts @($harnessFiles.project)
        [void]$phases.Add($importPhase)
        $registryLogPath = Join-Path $importEvidenceRoot 'godot.log'
        $registryArgumentsExact = Test-RegistryBootstrapArguments -Arguments @($importPhase.arguments) -Root $projectRoot -GodotLogPath $registryLogPath
        $registryLifecyclePassed = Test-RegistryLifecycleContract -Lifecycle $importPhase.registry_lifecycle
        $registryBootstrapSummary.dependency_census = $importPhase.prelaunch_dependency_census
        $registryBootstrapSummary.dependency_census_validated = Test-RecoveryBootstrapDependencyCensus -Census $registryBootstrapSummary.dependency_census
        $registryBootstrapSummary.arguments_exact = $registryArgumentsExact
        $registryBootstrapSummary.diagnostic_suppression_absent = (
            @($importPhase.arguments | Where-Object { [string]$_ -ceq '--verbose' }).Count -eq 1 `
            -and @($importPhase.arguments | Where-Object { [string]$_ -ceq '--quiet' }).Count -eq 0
        )
        $registryBootstrapSummary.lifecycle = $importPhase.registry_lifecycle
        $registryBootstrapSummary.lifecycle_contract_passed = $registryLifecyclePassed
        $registrationPhaseStarted = (
            [bool]$importPhase.process_started `
            -and (Test-ProcessIdentityProofShape -Identity $importPhase.process_identity) `
            -and [int]$importPhase.process_id -eq [int]$importPhase.process_identity.pid
        )
        if ($registrationPhaseStarted) {
            $registrationProcessIdentity = $importPhase.process_identity
        }
        $cacheCreationProof = $importPhase.owned_creation
        [void](Assert-OwnedCreationStateStable -State $cacheCreationProof)
        $cacheSummary.registration_started = $registrationPhaseStarted
        $cacheSummary.registration_process_identity = $registrationProcessIdentity
        $cacheSummary.creation_custody = Get-OwnedCreationEvidenceSummary -State $cacheCreationProof
        $cacheCleanupAuthorized = $cacheAbsentInitially -and [bool]$cacheOwnerSummary.accepted -and (Test-OwnedCreationStateProof -State $cacheCreationProof)
        $cacheSummary.cleanup_authorized = $cacheCleanupAuthorized
        if (
            -not $importPhase.native_exit_observed `
            -or $importPhase.native_exit_code -ne 0 `
            -or $importPhase.effective_exit_code -ne 0 `
            -or $importPhase.timed_out `
            -or -not [string]::IsNullOrWhiteSpace([string]$importPhase.launcher_error) `
            -or -not [bool]$importPhase.job_empty `
            -or -not $registryArgumentsExact `
            -or -not $registryBootstrapSummary.diagnostic_suppression_absent `
            -or -not $registryBootstrapSummary.dependency_census_validated `
            -or -not $registryLifecyclePassed `
            -or -not (Test-OwnedCreationStateProof -State $cacheCreationProof) `
            -or -not (Test-PhaseMarkerContract -Phase Registry -ProductRedMarkerSeen ([bool]$importPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$importPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$importPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$importPhase.full_pass_marker)) `
            -or -not $importPhase.diagnostics_clean
        ) {
            throw 'Explicit Godot recovery-mode --import global-class registration failed closed.'
        }
        if (-not (Test-Path -LiteralPath $globalClassCachePath -PathType Leaf) -or (Get-Item -LiteralPath $globalClassCachePath).Length -le 0) {
            throw 'Explicit Godot recovery-mode --import did not produce a nonempty global script class cache.'
        }
        if (-not (Test-Path -LiteralPath $uidCachePath -PathType Leaf) -or (Get-Item -LiteralPath $uidCachePath).Length -le 0) {
            throw 'Explicit Godot recovery-mode --import did not produce a nonempty UID cache.'
        }
        $registryBootstrapSummary.uid_cache_validated = $true
        $cacheItem = Get-Item -LiteralPath $projectCacheRoot -Force
        if (($cacheItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Explicit Godot --import produced a reparse-point .godot cache.'
        }
        Assert-RequiredGlobalClassEntries -CachePath $globalClassCachePath
        $registryBootstrapSummary.class_cache_validated = $true
        $cacheSummary.created = $true
        $cacheSummary.global_class_cache_sha256 = (Get-FileHash -LiteralPath $globalClassCachePath -Algorithm SHA256).Hash
        $cacheSummary.uid_cache_sha256 = (Get-FileHash -LiteralPath $uidCachePath -Algorithm SHA256).Hash
        $cacheSummary.imported_manifest = Write-ImportedArtifactManifest -DestinationPath (Join-Path $importEvidenceRoot 'imported-artifacts.json') -EvidenceReceipt $evidenceReceipt
        $registryBootstrapSummary.imported_manifest_validated = ([int]$cacheSummary.imported_manifest.count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$cacheSummary.imported_manifest.sha256))
        if (-not $registryBootstrapSummary.imported_manifest_validated) {
            throw 'Recovery-mode registry bootstrap did not produce a nonempty hashed import manifest.'
        }
        $registryBootstrapSummary.accepted = $true

        $fullArguments = @(Get-FullContractArguments -Root $projectRoot -ScriptPath $fullContractScriptPath)
        $fullContractSummary.required_arguments = @($fullArguments)
        $fullEvidenceRoot = Join-Path $EvidenceRoot '04-full-contract'
        $fullPhase = Invoke-GodotPhase -Name 'full_contract' -Arguments $fullArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeaseReceipt $leaseReceipt -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot $fullEvidenceRoot -EvidenceReceipt $evidenceReceipt -CounterpartAdmissionReceipt $counterpartReceipt -RequiredGodotSha256 $ExpectedGodotSha256 -RequiredGodotVersion $ExpectedGodotVersion -TimeoutSec $ProcessTimeoutSec -OwnedCreationState $cacheCreationProof -TrackedInputReceipts @($harnessFiles.full_contract)
        [void]$phases.Add($fullPhase)
        $fullLogPath = Join-Path $fullEvidenceRoot 'godot.log'
        $fullArgumentsExact = Test-FullContractArguments -Arguments @($fullPhase.arguments) -Root $projectRoot -ScriptPath $fullContractScriptPath -GodotLogPath $fullLogPath
        $fullContractSummary.arguments_exact = $fullArgumentsExact
        $fullContractSummary.recovery_mode_absent = (@($fullPhase.arguments | Where-Object { [string]$_ -ceq '--recovery-mode' }).Count -eq 0)
        $fullContractSummary.import_mode_absent = (@($fullPhase.arguments | Where-Object { [string]$_ -ceq '--import' }).Count -eq 0)
        $fullContractSummary.diagnostic_suppression_absent = (
            @($fullPhase.arguments | Where-Object { [string]$_ -ceq '--verbose' }).Count -eq 1 `
            -and @($fullPhase.arguments | Where-Object { [string]$_ -ceq '--quiet' }).Count -eq 0
        )
        if (
            -not $fullPhase.native_exit_observed `
            -or $fullPhase.native_exit_code -ne 0 `
            -or $fullPhase.effective_exit_code -ne 0 `
            -or $fullPhase.timed_out `
            -or -not [string]::IsNullOrWhiteSpace([string]$fullPhase.launcher_error) `
            -or -not [bool]$fullPhase.job_empty `
            -or -not $fullArgumentsExact `
            -or -not $fullContractSummary.recovery_mode_absent `
            -or -not $fullContractSummary.import_mode_absent `
            -or -not $fullContractSummary.diagnostic_suppression_absent `
            -or -not (Test-PhaseMarkerContract -Phase Full -ProductRedMarkerSeen ([bool]$fullPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$fullPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$fullPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$fullPhase.full_pass_marker)) `
            -or -not $fullPhase.diagnostics_clean
        ) {
            throw 'Full RW06_6 contract failed GREEN acceptance.'
        }
        $fullContractSummary.accepted = $true

        $generatedRunnerPath = Join-Path $generatedRoot 'foundation_check_split_runner.gd'
        $adjacentFoundationSummary.runner = New-Rw06FoundationRunner -Root $projectRoot -Commit $candidateCommit -DestinationPath $generatedRunnerPath -EvidenceReceipt $evidenceReceipt
        $adjacentEvidenceRoot = Join-Path $EvidenceRoot '05-foundation-pull-tabs'
        $adjacentReportPath = Join-Path $adjacentEvidenceRoot 'foundation-pull-tabs-report.json'
        $adjacentReportResourcePath = ConvertTo-ProjectResourcePath -Root $projectRoot -Path $adjacentReportPath
        $adjacentArguments = @(Get-AdjacentFoundationArguments -Root $projectRoot -ScriptPath ([string]$adjacentFoundationSummary.runner.resource_path) -ReportResourcePath $adjacentReportResourcePath)
        $adjacentFoundationSummary.required_arguments = @($adjacentArguments)
        $adjacentPhase = Invoke-GodotPhase -Name 'foundation_pull_tabs_adjacent' -Arguments $adjacentArguments -Root $projectRoot -RequiredCommit $ExpectedCommit -RequiredTree $ExpectedTree -OwnedLeaseReceipt $leaseReceipt -Q016SectionSha256 $q016Snapshot.section_sha256 -PhaseEvidenceRoot $adjacentEvidenceRoot -EvidenceReceipt $evidenceReceipt -CounterpartAdmissionReceipt $counterpartReceipt -RequiredGodotSha256 $ExpectedGodotSha256 -RequiredGodotVersion $ExpectedGodotVersion -TimeoutSec $ProcessTimeoutSec -OwnedCreationState $cacheCreationProof -RequiredInputReceipts @($adjacentFoundationSummary.runner.receipt) -TrackedInputReceipts @($adjacentFoundationSummary.runner.sources) -AdditionalOutputPath $adjacentReportPath
        [void]$phases.Add($adjacentPhase)
        $adjacentLogPath = Join-Path $adjacentEvidenceRoot 'godot.log'
        $adjacentArgumentsExact = Test-AdjacentFoundationArguments -Arguments @($adjacentPhase.arguments) -Root $projectRoot -ScriptPath ([string]$adjacentFoundationSummary.runner.resource_path) -ReportResourcePath $adjacentReportResourcePath -GodotLogPath $adjacentLogPath
        $adjacentFoundationSummary.arguments_exact = $adjacentArgumentsExact
        $adjacentFoundationSummary.marker_contract_passed = Test-AdjacentPhaseMarkerContract -ProductRedMarkerSeen ([bool]$adjacentPhase.product_red_marker) -GuardPassMarkerSeen ([bool]$adjacentPhase.guard_pass_marker) -InfraFailureMarkerSeen ([bool]$adjacentPhase.infra_failure_marker) -FullPassMarkerSeen ([bool]$adjacentPhase.full_pass_marker) -FoundationPassMarkerSeen ([bool]$adjacentPhase.foundation_pass_marker) -FoundationPullTabsDoneMarkerSeen ([bool]$adjacentPhase.foundation_pull_tabs_done_marker) -FoundationDoneCount ([int]$adjacentPhase.foundation_done_count)
        $adjacentFoundationSummary.diagnostics_clean = [bool]$adjacentPhase.diagnostics_clean
        $adjacentReportText = [string]$adjacentPhase.additional_output_text
        try { $adjacentReport = $adjacentReportText | ConvertFrom-Json }
        catch { throw 'Adjacent Foundation pull-tabs report is invalid JSON.' }
        $adjacentReportValid = Test-AdjacentFoundationReport -Report $adjacentReport
        $adjacentFoundationSummary.report = [ordered]@{
            path = $adjacentReportPath
            resource_path = $adjacentReportResourcePath
            sha256 = [string]$adjacentPhase.additional_output_receipt.sha256
            length = [long]$adjacentPhase.additional_output_receipt.length
            identity = $adjacentPhase.additional_output_receipt.identity
            schema_validated = $adjacentReportValid
            executed_check_ids = @($adjacentReport.executed_check_ids)
            registered_check_ids = @($adjacentReport.registered_check_ids)
        }
        if (
            -not $adjacentPhase.native_exit_observed `
            -or $adjacentPhase.native_exit_code -ne 0 `
            -or $adjacentPhase.effective_exit_code -ne 0 `
            -or $adjacentPhase.timed_out `
            -or -not [string]::IsNullOrWhiteSpace([string]$adjacentPhase.launcher_error) `
            -or -not [bool]$adjacentPhase.job_empty `
            -or -not $adjacentArgumentsExact `
            -or -not [bool]$adjacentFoundationSummary.marker_contract_passed `
            -or -not [bool]$adjacentPhase.diagnostics_clean `
            -or -not $adjacentReportValid
        ) {
            throw 'Adjacent production Foundation pull-tabs shard failed GREEN acceptance.'
        }
        $adjacentFoundationSummary.accepted = $true
        $adjacentFoundationSummary.status = 'passed'
        $outcome = 'green_pass'
        $overallExitCode = 0
    }
    else {
        throw "Source guard disposition '$disposition' did not match ExpectedOutcome $ExpectedOutcome."
    }
}
catch {
    $launcherError = $_.Exception.Message
    $outcome = 'invalid'
    $overallExitCode = 1
}
finally {
    try {
        $ownedJobCleanupReceipt = Stop-AllActiveOwnedJobsExact
        $ownedJobsEmpty = [bool]$ownedJobCleanupReceipt.empty
        if (-not $ownedJobsEmpty) {
            throw ('Owned job cleanup was not proven empty: ' + (@($ownedJobCleanupReceipt.failures) -join ' | '))
        }
    }
    catch {
        $ownedJobsEmpty = $false
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
        else { $launcherError += ' | Residual process custody: ' + $_.Exception.Message }
        $outcome = 'invalid'
        $overallExitCode = 1
    }
    try {
        if (-not $ownedJobsEmpty) { throw 'Preserving cache because exact owned job emptiness was not proven.' }
        if (Test-Path -LiteralPath $projectCacheRoot) {
            $cacheSummary.created = $true
            if ([string]::IsNullOrWhiteSpace([string]$cacheSummary.global_class_cache_sha256) -and (Test-Path -LiteralPath $globalClassCachePath -PathType Leaf)) {
                $cacheSummary.global_class_cache_sha256 = (Get-FileHash -LiteralPath $globalClassCachePath -Algorithm SHA256).Hash
            }
            if ([string]::IsNullOrWhiteSpace([string]$cacheSummary.uid_cache_sha256) -and (Test-Path -LiteralPath $uidCachePath -PathType Leaf)) {
                $cacheSummary.uid_cache_sha256 = (Get-FileHash -LiteralPath $uidCachePath -Algorithm SHA256).Hash
            }
            # Only the separate built-ins-only Godot cache-owner phase is
            # authorized to create this cache.  Require its exact native-job,
            # process, nonce, claim, and file-ID proof and refuse replacement.
            if (
                $cacheAbsentInitially `
                -and [bool]$cacheOwnerSummary.accepted `
                -and [bool]$cacheOwnerSummary.creator_claim_bound `
                -and (Test-OwnedCreationStateProof -State $cacheCreationProof)
            ) {
                $cacheCleanupAuthorized = $true
                $cacheSummary.cleanup_authorized = $true
            }
            if (-not $cacheCleanupAuthorized) {
                throw 'A pre-existing or unowned .godot cache appeared; refusing destructive cleanup.'
            }
            $cacheRemovalReceipt = Remove-DedicatedProjectCache -Root $projectRoot -CacheRoot $projectCacheRoot -OwnedCreationProof $cacheCreationProof
            $cacheSummary.cleanup_receipt = $cacheRemovalReceipt
        }
        $cacheCleanupSucceeded = -not (Test-Path -LiteralPath $projectCacheRoot)
        $cacheSummary.removed_after_evidence = $cacheCleanupSucceeded
    }
    catch {
        $cacheCleanupSucceeded = $false
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
        else { $launcherError += ' | Cache cleanup: ' + $_.Exception.Message }
        $outcome = 'invalid'
        $overallExitCode = 1
    }
    try {
        $environmentRestoreResult = Restore-ProcessEnvironmentSafely -Snapshot $oldEnvironment
        $environmentRestorationSucceeded = [bool]$environmentRestoreResult.succeeded
        if (-not $environmentRestorationSucceeded) {
            throw [string]$environmentRestoreResult.error
        }
    }
    catch {
        $environmentRestorationSucceeded = $false
        $environmentRestoreError = $_.Exception.Message
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $environmentRestoreError }
        else { $launcherError += ' | Environment restoration: ' + $environmentRestoreError }
        $outcome = 'invalid'
        $overallExitCode = 1
    }
}

$finalCensusMutex = [System.Threading.Mutex]::new($false, $launchMutexName)
$finalCensusMutexOwned = $false
try {
    $finalCensusMutexOwned = $finalCensusMutex.WaitOne(5000)
    if (-not $finalCensusMutexOwned) { throw 'Could not acquire the Q-009 launch lock for the serialized final census.' }
    if ($leaseOwned) {
        [void](Assert-OwnedLease -Receipt $leaseReceipt -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree)
    }
    $postLeases = @(Get-StrictLeaseEntryRecords -Root $leaseRoot -RequireCanonical)
    $postFocusedLeases = @($postLeases | Where-Object { -not [bool]$_.is_exclusive })
    if ($leaseOwned) {
        $postExclusiveLeases = @($postLeases | Where-Object { [bool]$_.is_exclusive })
        if (
            $postExclusiveLeases.Count -ne 1 `
            -or -not (Test-FileSystemObjectsShareIdentity -Left $postExclusiveLeases[0].identity -Right $leaseReceipt.file_identity) `
            -or $postFocusedLeases.Count -ne 0
        ) { throw 'Serialized final census did not retain the sole exact owned EXCLUSIVE.lease.' }
    }
    $postGodotRecords = @(Get-LiveGodotIdentityRecords)
    $newUnownedGodot = @(Get-NewUnownedGodotRecords -BaselineKeys $baselineGodotKeys)
    $postStatus = @(& git -C $projectRoot status --porcelain)
    $postCommit = (& git -C $projectRoot rev-parse HEAD).Trim()
    $postTree = (& git -C $projectRoot rev-parse 'HEAD^{tree}').Trim()
    $identityStable = ($postStatus.Count -eq 0 -and $postCommit -eq $ExpectedCommit.Trim() -and $postTree -eq $ExpectedTree.Trim())
    $serializedFinalCensusPassed = (
        $leaseOwned `
        -and $identityStable `
        -and $ownedJobsEmpty `
        -and $postGodotRecords.Count -eq 0 `
        -and $newUnownedGodot.Count -eq 0 `
        -and $postFocusedLeases.Count -eq 0 `
        -and $cacheCleanupSucceeded `
        -and $environmentRestorationSucceeded
    )
    $serializedFinalCensus = [ordered]@{
        contract = 'rw06_6_serialized_final_census_v1'
        captured_utc = [DateTime]::UtcNow.ToString('o')
        captured_under_q009_mutex = [bool]$finalCensusMutexOwned
        captured_while_owned_exclusive_live = [bool]$leaseOwned
        owned_exclusive_release_pending = [bool]$leaseOwned
        candidate_commit = $postCommit
        candidate_tree = $postTree
        candidate_status = @($postStatus)
        candidate_identity_stable = [bool]$identityStable
        owned_exclusive = [ordered]@{
            path = if ($null -eq $leaseReceipt) { '' } else { [string]$leaseReceipt.path }
            identity = if ($null -eq $leaseReceipt) { $null } else { $leaseReceipt.file_identity }
            sha256 = if ($null -eq $leaseReceipt) { '' } else { [string]$leaseReceipt.sha256 }
            nonce = if ($null -eq $leaseReceipt) { '' } else { [string]$leaseReceipt.nonce }
        }
        leases = @($postLeases | ForEach-Object {
            [ordered]@{
                name = [string]$_.name
                path = [string]$_.path
                identity = $_.identity
                sha256 = [string]$_.sha256
                is_exclusive = [bool]$_.is_exclusive
                fields = $_.fields
            }
        })
        focused_lease_count = [int]$postFocusedLeases.Count
        live_godot = @($postGodotRecords)
        new_unowned_godot = @($newUnownedGodot)
        owned_jobs_empty = [bool]$ownedJobsEmpty
        owned_job_cleanup = $ownedJobCleanupReceipt
        environment_restored = [bool]$environmentRestorationSucceeded
        project_cache_absent = [bool]$cacheCleanupSucceeded
        cache_cleanup_receipt = $cacheRemovalReceipt
        passed = [bool]$serializedFinalCensusPassed
    }
    $serializedFinalCensusSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceReceipt -DestinationPath (Join-Path $EvidenceRoot 'serialized-final-census.json') -Text (($serializedFinalCensus | ConvertTo-Json -Depth 12) + "`n")
}
catch {
    if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
    else { $launcherError += ' | Serialized final census: ' + $_.Exception.Message }
    $serializedFinalCensusPassed = $false
}
finally {
    try {
        if (-not $ownedJobsEmpty) { throw 'Preserving exclusive lease because exact owned job emptiness was not proven.' }
        if ($leaseOwned) {
            if (-not $serializedFinalCensusPassed -or $null -eq $serializedFinalCensusSeal -or -not [bool]$serializedFinalCensusSeal.finalized) {
                throw 'Preserving exclusive lease because the serialized final census was not successfully sealed.'
            }
            [void](Assert-RetainedArtifactReceiptStable -EvidenceReceipt $evidenceReceipt -Receipt $serializedFinalCensusSeal)
            if (Test-OwnedLeaseIdentityPresent -Receipt $leaseReceipt) {
                $ownedLeaseRemovalReceipt = Remove-OwnedLeaseFile -Receipt $leaseReceipt -Root $projectRoot -Commit $candidateCommit -Tree $candidateTree
            }
        }
        $ownedLeaseRemoved = (-not $leaseOwned -or -not (Test-OwnedLeaseIdentityPresent -Receipt $leaseReceipt))
    }
    catch {
        $ownedLeaseRemoved = $false
        if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $_.Exception.Message }
        else { $launcherError += ' | Lease cleanup: ' + $_.Exception.Message }
    }
    if ($finalCensusMutexOwned) { $finalCensusMutex.ReleaseMutex() }
    $finalCensusMutex.Dispose()
}
if (-not $serializedFinalCensusPassed -or -not $ownedLeaseRemoved) {
    $outcome = 'invalid'
    $overallExitCode = 1
}

# Raw phase transport can carry the live cache custody SafeFileHandle. Every
# retained phase already has a handle-free capture; remove raw state before any
# terminal JSON is constructed, including failure evidence.
foreach ($phase in @($phases)) {
    if ($phase -is [System.Collections.IDictionary] -and $phase.Contains('owned_creation')) {
        $phase.Remove('owned_creation')
    }
}

if (-not ($phases | Where-Object { $_.name -eq 'cache_ownership' })) {
    if (-not ($skippedPhases | Where-Object { $_.name -eq 'cache_ownership' })) {
        [void]$skippedPhases.Add([ordered]@{ name = 'cache_ownership'; reason = 'Earlier preflight or source-guard failure.' })
    }
}
if (-not ($phases | Where-Object { $_.name -eq 'global_class_registration' })) {
    if (-not ($skippedPhases | Where-Object { $_.name -eq 'global_class_registration' })) {
        [void]$skippedPhases.Add([ordered]@{ name = 'global_class_registration'; reason = 'Earlier preflight or source-guard failure.' })
    }
}
if (-not ($phases | Where-Object { $_.name -eq 'full_contract' })) {
    if (-not ($skippedPhases | Where-Object { $_.name -eq 'full_contract' })) {
        [void]$skippedPhases.Add([ordered]@{ name = 'full_contract'; reason = 'Earlier preflight, guard, or registry failure.' })
    }
}
if (-not ($phases | Where-Object { $_.name -eq 'foundation_pull_tabs_adjacent' })) {
    if (-not ($skippedPhases | Where-Object { $_.name -eq 'foundation_pull_tabs_adjacent' })) {
        [void]$skippedPhases.Add([ordered]@{ name = 'foundation_pull_tabs_adjacent'; reason = 'Earlier preflight, guard, registry, or full-contract failure.' })
    }
    if ([string]$adjacentFoundationSummary.status -ceq 'not_run') { $adjacentFoundationSummary.status = 'skipped_invalid' }
}

$artifactManifestSeal = [ordered]@{}
$artifactManifestShaSeal = [ordered]@{}
$summarySeal = [ordered]@{}
$summaryShaSeal = [ordered]@{}
$completionReceiptSeal = [ordered]@{}
$lateBoundSeals = [System.Collections.Generic.List[object]]::new()
$terminalSealValidated = $false
try {
    [void](Assert-OwnedEvidenceRoot -Receipt $evidenceReceipt)
    # Profile/runtime files have engine-selected names. Capture them exactly
    # once after all jobs are proven empty and before terminal staging.
    [void](Register-PreviouslyUnseenOwnedEvidenceEntries -EvidenceReceipt $evidenceReceipt)
    $lateBoundRelativePaths = @('artifact-manifest.json', 'artifact-manifest.sha256', 'summary.json', 'summary.sha256', 'completion-receipt.json')
    [void](Assert-AllRetainedArtifactReceiptsStable -EvidenceReceipt $evidenceReceipt)
    $manifestEntries = @(Get-RetainedArtifactEntriesFromReceipts)
    if (@($manifestEntries | Where-Object { [bool]$_.reparse_point }).Count -gt 0) {
        throw 'Retained evidence contains a reparse object; exact final-tree sealing refuses it.'
    }
    $retainedPaths = @(@($manifestEntries | ForEach-Object { [string]$_.path }) + @('artifact-manifest.json', 'artifact-manifest.sha256', 'summary.json', 'summary.sha256', 'completion-receipt.json') | Sort-Object -Unique)
    $artifactManifest = [ordered]@{
        contract = 'rw06_6_pull_tab_glimmer_retained_artifacts'
        terminal_status = 'valid_only_with_matching_completion_receipt_and_whole_tree_readback'
        candidate_commit = $candidateCommit
        candidate_tree = $candidateTree
        evidence_root = $EvidenceRoot
        evidence_root_identity = $evidenceReceipt.root_identity
        owner_claim_sha256 = [string]$evidenceReceipt.claim_sha256
        counterpart_receipt_sha256 = [string]$counterpartReceipt.receipt_sha256
        entry_count = $manifestEntries.Count
        entries = $manifestEntries
        late_bound_atomic_files = $lateBoundRelativePaths
        exact_retained_paths = $retainedPaths
    }
    $artifactManifestPendingPath = Join-Path $EvidenceRoot '.pending-artifact-manifest.json'
    $artifactManifestShaPendingPath = Join-Path $EvidenceRoot '.pending-artifact-manifest.sha256'
    $summaryPendingPath = Join-Path $EvidenceRoot '.pending-summary.json'
    $summaryShaPendingPath = Join-Path $EvidenceRoot '.pending-summary.sha256'
    $completionReceiptPendingPath = Join-Path $EvidenceRoot '.pending-completion-receipt.json'
    $artifactManifestSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceReceipt -DestinationPath $artifactManifestPendingPath -Text (($artifactManifest | ConvertTo-Json -Depth 12) + "`n")
    [void]$lateBoundSeals.Add($artifactManifestSeal)
    $artifactManifestShaSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceReceipt -DestinationPath $artifactManifestShaPendingPath -Text (([string]$artifactManifestSeal.sha256) + '  artifact-manifest.json' + "`n")
    [void]$lateBoundSeals.Add($artifactManifestShaSeal)

    $summary = [ordered]@{
        contract = 'rw06_6_pull_tab_glimmer'
        terminal_status = 'valid_only_with_matching_completion_receipt_and_whole_tree_readback'
        expected_outcome = $ExpectedOutcome
        candidate_commit = $candidateCommit
        candidate_tree = $candidateTree
        outcome = $outcome
        exit_code = [int]$overallExitCode
        launcher_error = $launcherError
        green_authorization_switch = [bool]$AuthorizeGreen
        q016 = $q016Snapshot
        godot = $godotIdentity
        counterpart_admission = $counterpartReceipt
        evidence_ownership = $evidenceReceipt
        retained_artifact_manifest = [ordered]@{
            manifest_path = 'artifact-manifest.json'
            manifest_sha256 = [string]$artifactManifestSeal.sha256
            hash_path = 'artifact-manifest.sha256'
            hash_sha256 = [string]$artifactManifestShaSeal.sha256
            exact_path_count = $retainedPaths.Count
            completion_receipt_required = $true
            completion_receipt_path = 'completion-receipt.json'
        }
        started_utc = $startedUtc.ToString('o')
        completed_utc = [DateTime]::UtcNow.ToString('o')
        evidence_root = $EvidenceRoot
        phases = @($phases)
        skipped_phases = @($skippedPhases)
        files = $harnessFiles
        cache = $cacheSummary
        cache_ownership = $cacheOwnerSummary
        registry_bootstrap = $registryBootstrapSummary
        full_contract_execution = $fullContractSummary
        adjacent_foundation_execution = $adjacentFoundationSummary
        serialized_final_census = [ordered]@{
            payload = $serializedFinalCensus
            path = [string]$serializedFinalCensusSeal.relative_path
            sha256 = [string]$serializedFinalCensusSeal.sha256
            identity = $serializedFinalCensusSeal.identity
        }
        final = [ordered]@{
            clean_tree = ($postStatus.Count -eq 0)
            commit = $postCommit
            tree = $postTree
            identity_stable = $identityStable
            baseline_godot = @($baselineGodotRecords)
            live_godot = @($postGodotRecords)
            new_unowned_godot = @($newUnownedGodot)
            owned_jobs_empty = $ownedJobsEmpty
            owned_job_cleanup = $ownedJobCleanupReceipt
            serialized_final_census_passed = [bool]$serializedFinalCensusPassed
            lease_count_at_serialized_census = $postLeases.Count
            focused_lease_count_at_serialized_census = $postFocusedLeases.Count
            census_included_owned_exclusive = [bool]$leaseOwned
            owned_lease_removed = [bool]$ownedLeaseRemoved
            owned_lease_removal_receipt = $ownedLeaseRemovalReceipt
            environment_restored = $environmentRestorationSucceeded
            project_cache_absent = -not (Test-Path -LiteralPath $projectCacheRoot)
        }
    }
    $summarySeal = Write-AtomicSealedText -EvidenceReceipt $evidenceReceipt -DestinationPath $summaryPendingPath -Text (($summary | ConvertTo-Json -Depth 14) + "`n")
    [void]$lateBoundSeals.Add($summarySeal)
    $summaryShaSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceReceipt -DestinationPath $summaryShaPendingPath -Text (([string]$summarySeal.sha256) + '  summary.json' + "`n")
    [void]$lateBoundSeals.Add($summaryShaSeal)
    $completionReceipt = [ordered]@{
        contract = 'rw06_6_pull_tab_glimmer_evidence_complete'
        candidate_commit = $candidateCommit
        candidate_tree = $candidateTree
        expected_outcome = $ExpectedOutcome
        outcome = $outcome
        exit_code = [int]$overallExitCode
        evidence_root = $EvidenceRoot
        evidence_root_native_key = [string]$evidenceReceipt.root_identity.native_key
        artifact_manifest_sha256 = [string]$artifactManifestSeal.sha256
        summary_sha256 = [string]$summarySeal.sha256
        exact_retained_paths_sha256 = Get-StringSha256 -Value (($retainedPaths | ConvertTo-Json -Compress))
        sealed_utc = [DateTime]::UtcNow.ToString('o')
    }
    $completionReceiptSeal = Write-AtomicSealedText -EvidenceReceipt $evidenceReceipt -DestinationPath $completionReceiptPendingPath -Text (($completionReceipt | ConvertTo-Json -Depth 6) + "`n")
    [void]$lateBoundSeals.Add($completionReceiptSeal)

    # Every terminal artifact first exists only under an unmistakably invalid
    # pending name.  Validate the entire receipt-derived tree before any public
    # artifact can be mistaken for completed evidence.
    $stagedEntries = @(Get-RetainedArtifactEntriesFromReceipts)
    $stagedPaths = @($stagedEntries | ForEach-Object { [string]$_.path })
    if (-not (Test-RetainedArtifactIntegrity -EvidenceReceipt $evidenceReceipt -ExpectedEntries $stagedEntries -ExpectedRelativePaths $stagedPaths)) {
        throw 'Pending terminal whole-tree readback found an added, removed, replaced, reparse, length, or hash mismatch.'
    }

    $artifactManifestSeal = Move-RetainedArtifactReceiptAtomic -EvidenceReceipt $evidenceReceipt -Receipt $artifactManifestSeal -DestinationPath $artifactManifestPath
    $artifactManifestShaSeal = Move-RetainedArtifactReceiptAtomic -EvidenceReceipt $evidenceReceipt -Receipt $artifactManifestShaSeal -DestinationPath $artifactManifestShaPath
    $summarySeal = Move-RetainedArtifactReceiptAtomic -EvidenceReceipt $evidenceReceipt -Receipt $summarySeal -DestinationPath $summaryPath
    $summaryShaSeal = Move-RetainedArtifactReceiptAtomic -EvidenceReceipt $evidenceReceipt -Receipt $summaryShaSeal -DestinationPath $summaryShaPath

    # Completion remains hidden while the public manifest/summary and the exact
    # pending completion bytes receive a second complete receipt-bound readback.
    $preCompletionEntries = @(Get-RetainedArtifactEntriesFromReceipts)
    $preCompletionPaths = @($preCompletionEntries | ForEach-Object { [string]$_.path })
    if (-not (Test-RetainedArtifactIntegrity -EvidenceReceipt $evidenceReceipt -ExpectedEntries $preCompletionEntries -ExpectedRelativePaths $preCompletionPaths)) {
        throw 'Public terminal artifacts drifted before completion publication.'
    }
    $completionReceiptSeal = Move-RetainedArtifactReceiptAtomic -EvidenceReceipt $evidenceReceipt -Receipt $completionReceiptSeal -DestinationPath $completionReceiptPath
    $finalEntries = @(Get-RetainedArtifactEntriesFromReceipts)
    if (-not (Test-RetainedArtifactIntegrity -EvidenceReceipt $evidenceReceipt -ExpectedEntries $finalEntries -ExpectedRelativePaths $retainedPaths)) {
        throw 'Published terminal whole-tree readback found an added, removed, replaced, reparse, length, or hash mismatch.'
    }
    $terminalSealValidated = $true
}
catch {
    $sealError = $_.Exception.Message
    if ([string]::IsNullOrWhiteSpace($launcherError)) { $launcherError = $sealError }
    else { $launcherError += ' | Evidence sealing: ' + $sealError }
    $outcome = 'invalid'
    $overallExitCode = 1
    $invalidationErrors = @(Remove-ExactLateBoundSeals -EvidenceReceipt $evidenceReceipt -Seals @($lateBoundSeals))
    if ($invalidationErrors.Count -gt 0) {
        $launcherError += ' | Terminal invalidation retained replaced/tampered late seals: ' + ($invalidationErrors -join ' || ')
    }
    $artifactManifestSeal = [ordered]@{}
    $artifactManifestShaSeal = [ordered]@{}
    $summarySeal = [ordered]@{}
    $summaryShaSeal = [ordered]@{}
    $completionReceiptSeal = [ordered]@{}
    $terminalSealValidated = $false
}
Write-Host ("RW06_6 outcome={0} exit={1} phases={2} evidence={3}" -f $outcome, $overallExitCode, $phases.Count, $EvidenceRoot)
if ($terminalSealValidated -and -not [string]::IsNullOrWhiteSpace([string]$summarySeal.sha256)) {
    Write-Host ("RW06_6_SUMMARY_SHA256 {0}" -f [string]$summarySeal.sha256)
}
if ($terminalSealValidated -and -not [string]::IsNullOrWhiteSpace([string]$artifactManifestSeal.sha256)) {
    Write-Host ("RW06_6_ARTIFACT_MANIFEST_SHA256 {0}" -f [string]$artifactManifestSeal.sha256)
}
if ($terminalSealValidated -and -not [string]::IsNullOrWhiteSpace([string]$completionReceiptSeal.sha256)) {
    Write-Host ("RW06_6_COMPLETION_RECEIPT_SHA256 {0}" -f [string]$completionReceiptSeal.sha256)
}
if (-not [string]::IsNullOrWhiteSpace($launcherError)) {
    Write-Host ("RW06_6 launcher error: {0}" -f $launcherError)
}
exit $overallExitCode
