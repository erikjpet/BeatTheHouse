# Shared Q-009 process, lease, and provenance primitives.
#
# Extracted from the independently reviewed rw06_6 launcher, then extended for
# rw06_1's retained-handle cache and strict CIM ancestry custody. Every helper
# receives its validated runtime context explicitly; this library intentionally
# has no dependency on caller-scope variables such as $PID or a lease root.
# This library does not acquire a lease or launch a process by itself.

# A process census cannot retain a descendant whose short-lived parent exits
# between samples.  Launch every qualifying child suspended, place its exact
# native handle in a private kill-on-close Job Object, and only then resume it.
# Kernel job membership therefore remains authoritative even when an
# intermediate process is already gone by the time the next census runs.
if ($null -ne ('BeatTheHouse.Q009.OwnedJobProcess' -as [type])) {
    throw 'Q-009 support refuses an ambient/reused NativeJobLauncher type before its exact source is loaded.'
}
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

namespace BeatTheHouse.Q009
{
    public sealed class OwnedJobProcess : IDisposable
    {
        internal IntPtr JobHandle;
        internal IntPtr NativeProcessHandle;
        public Process Process { get; internal set; }
        public FileStream StandardOutput { get; internal set; }
        public FileStream StandardError { get; internal set; }
        public int ProcessId { get; internal set; }
        public DateTime RootStartUtc { get; internal set; }
        public string RootProcessName { get; internal set; }
        public string LaunchedImagePath { get; internal set; }
        public DateTime LaunchLowerUtc { get; internal set; }
        public DateTime LaunchUpperUtc { get; internal set; }
        public bool JobAssigned { get; internal set; }
        public bool Resumed { get; internal set; }
        public bool JobClosed { get; private set; }

        public int[] GetActiveProcessIds()
        {
            if (JobHandle == IntPtr.Zero || JobClosed)
                throw new InvalidOperationException("Owned Job Object is not available for membership accounting.");
            const int maximumMembers = 4096;
            int pointerOffset = 8;
            int size = pointerOffset + (maximumMembers * IntPtr.Size);
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try
            {
                uint returned;
                if (!NativeMethods.QueryInformationJobObject(JobHandle, 3, buffer, (uint)size, out returned))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "QueryInformationJobObject(JobObjectBasicProcessIdList) failed.");
                uint assigned = unchecked((uint)Marshal.ReadInt32(buffer, 0));
                uint listed = unchecked((uint)Marshal.ReadInt32(buffer, 4));
                if (assigned != listed || listed > maximumMembers)
                    throw new InvalidOperationException("Owned Job Object membership list was truncated or internally inconsistent.");
                int[] result = new int[listed];
                for (int index = 0; index < listed; index++)
                {
                    long raw = IntPtr.Size == 8
                        ? Marshal.ReadInt64(buffer, pointerOffset + (index * IntPtr.Size))
                        : Marshal.ReadInt32(buffer, pointerOffset + (index * IntPtr.Size));
                    if (raw <= 0 || raw > Int32.MaxValue)
                        throw new InvalidOperationException("Owned Job Object returned an invalid process identifier.");
                    result[index] = (int)raw;
                }
                return result;
            }
            finally { Marshal.FreeHGlobal(buffer); }
        }

        public uint GetActiveProcessCount()
        {
            if (JobHandle == IntPtr.Zero || JobClosed)
                throw new InvalidOperationException("Owned Job Object is not available for active-process accounting.");
            NativeMethods.JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info;
            uint returned;
            if (!NativeMethods.QueryInformationJobObject(
                    JobHandle, 1, out info,
                    (uint)Marshal.SizeOf(typeof(NativeMethods.JOBOBJECT_BASIC_ACCOUNTING_INFORMATION)),
                    out returned))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "QueryInformationJobObject(JobObjectBasicAccountingInformation) failed.");
            return info.ActiveProcesses;
        }

        public void Terminate(uint exitCode)
        {
            if (JobHandle == IntPtr.Zero || JobClosed)
                throw new InvalidOperationException("Owned Job Object is not available for termination.");
            if (!NativeMethods.TerminateJobObject(JobHandle, exitCode))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "TerminateJobObject failed.");
        }

        public bool WaitForRootExit(int milliseconds)
        {
            if (NativeProcessHandle == IntPtr.Zero || JobClosed)
                throw new InvalidOperationException("Owned native root handle is not available for waiting.");
            uint waitResult = NativeMethods.WaitForSingleObject(NativeProcessHandle, unchecked((uint)milliseconds));
            if (waitResult == 0u) return true;
            if (waitResult == 0x00000102u) return false;
            throw new Win32Exception(Marshal.GetLastWin32Error(), "WaitForSingleObject(owned root) failed.");
        }

        public int GetExactExitCode()
        {
            if (NativeProcessHandle == IntPtr.Zero || JobClosed)
                throw new InvalidOperationException("Owned native root handle is not available for exit-code custody.");
            uint exitCode;
            if (!NativeMethods.GetExitCodeProcess(NativeProcessHandle, out exitCode))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetExitCodeProcess(owned root) failed.");
            if (exitCode == 259u)
                throw new InvalidOperationException("Owned native root was still active when its exit code was requested.");
            return unchecked((int)exitCode);
        }

        public void CloseVerifiedEmpty()
        {
            if (JobClosed) return;
            if (GetActiveProcessCount() != 0)
                throw new InvalidOperationException("Refusing to close an owned Job Object with active members.");
            if (JobHandle != IntPtr.Zero)
            {
                if (!NativeMethods.CloseHandle(JobHandle))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CloseHandle(job) failed.");
                JobHandle = IntPtr.Zero;
            }
            if (NativeProcessHandle != IntPtr.Zero)
            {
                if (!NativeMethods.CloseHandle(NativeProcessHandle))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CloseHandle(process) failed.");
                NativeProcessHandle = IntPtr.Zero;
            }
            JobClosed = true;
        }

        public void Dispose()
        {
            try { if (StandardOutput != null) StandardOutput.Dispose(); } catch { }
            try { if (StandardError != null) StandardError.Dispose(); } catch { }
            if (JobHandle != IntPtr.Zero) { NativeMethods.CloseHandle(JobHandle); JobHandle = IntPtr.Zero; }
            if (NativeProcessHandle != IntPtr.Zero) { NativeMethods.CloseHandle(NativeProcessHandle); NativeProcessHandle = IntPtr.Zero; }
            JobClosed = true;
        }
    }

    public static class NativeJobLauncher
    {
        private static uint QueryActiveProcessCount(IntPtr job)
        {
            NativeMethods.JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info;
            uint returned;
            if (!NativeMethods.QueryInformationJobObject(
                    job, 1, out info,
                    (uint)Marshal.SizeOf(typeof(NativeMethods.JOBOBJECT_BASIC_ACCOUNTING_INFORMATION)),
                    out returned))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "QueryInformationJobObject(JobObjectBasicAccountingInformation) failed during setup cleanup.");
            return info.ActiveProcesses;
        }

        private static uint QueryMembershipCount(IntPtr job)
        {
            const int maximumMembers = 4096;
            int pointerOffset = 8;
            int size = pointerOffset + (maximumMembers * IntPtr.Size);
            IntPtr buffer = Marshal.AllocHGlobal(size);
            try
            {
                uint returned;
                if (!NativeMethods.QueryInformationJobObject(job, 3, buffer, (uint)size, out returned))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "QueryInformationJobObject(JobObjectBasicProcessIdList) failed during setup cleanup.");
                uint assigned = unchecked((uint)Marshal.ReadInt32(buffer, 0));
                uint listed = unchecked((uint)Marshal.ReadInt32(buffer, 4));
                if (assigned != listed || listed > maximumMembers)
                    throw new InvalidOperationException("Owned Job Object setup-cleanup membership was truncated or inconsistent.");
                return listed;
            }
            finally { Marshal.FreeHGlobal(buffer); }
        }

        private static DateTime QueryNativeProcessStartUtc(IntPtr process)
        {
            NativeMethods.FILETIME creation, exit, kernel, user;
            if (!NativeMethods.GetProcessTimes(process, out creation, out exit, out kernel, out user))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetProcessTimes(owned root) failed before resume.");
            long fileTime = unchecked(((long)creation.dwHighDateTime << 32) | creation.dwLowDateTime);
            return DateTime.FromFileTimeUtc(fileTime);
        }

        private static string QueryNativeImagePath(IntPtr process)
        {
            StringBuilder value = new StringBuilder(32768);
            uint length = (uint)value.Capacity;
            if (!NativeMethods.QueryFullProcessImageName(process, 0u, value, ref length) || length == 0u)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "QueryFullProcessImageNameW(owned suspended root) failed.");
            return Path.GetFullPath(value.ToString(0, checked((int)length)));
        }

        public static OwnedJobProcess Start(string applicationPath, string commandLine, string workingDirectory)
        {
            return Start(applicationPath, commandLine, workingDirectory, false);
        }

        public static OwnedJobProcess Start(string applicationPath, string commandLine, string workingDirectory, bool forcePostWrapperSetupFailure)
        {
            IntPtr stdoutRead = IntPtr.Zero, stdoutWrite = IntPtr.Zero;
            IntPtr stderrRead = IntPtr.Zero, stderrWrite = IntPtr.Zero;
            IntPtr stdinHandle = IntPtr.Zero, job = IntPtr.Zero;
            NativeMethods.PROCESS_INFORMATION pi = new NativeMethods.PROCESS_INFORMATION();
            bool processCreated = false, jobAssigned = false, cleanupSucceeded = false, accountingSucceeded = false;
            int preTerminationActiveProcessCount = -1;
            int preTerminationMembershipCount = -1;
            int finalActiveProcessCount = -1;
            int finalMembershipCount = -1;
            SafeFileHandle safeStdout = null, safeStderr = null;
            FileStream managedStdout = null, managedStderr = null;
            Process managedProcess = null;
            DateTime managedRootStartUtc = DateTime.MinValue;
            string managedRootProcessName = String.Empty;
            string launchedImagePath = String.Empty;
            DateTime lowerUtc = DateTime.UtcNow;
            try
            {
                NativeMethods.SECURITY_ATTRIBUTES inheritable = new NativeMethods.SECURITY_ATTRIBUTES();
                inheritable.nLength = Marshal.SizeOf(typeof(NativeMethods.SECURITY_ATTRIBUTES));
                inheritable.bInheritHandle = true;
                if (!NativeMethods.CreatePipe(out stdoutRead, out stdoutWrite, ref inheritable, 0))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CreatePipe(stdout) failed.");
                if (!NativeMethods.SetHandleInformation(stdoutRead, 1, 0))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "SetHandleInformation(stdout) failed.");
                if (!NativeMethods.CreatePipe(out stderrRead, out stderrWrite, ref inheritable, 0))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CreatePipe(stderr) failed.");
                if (!NativeMethods.SetHandleInformation(stderrRead, 1, 0))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "SetHandleInformation(stderr) failed.");
                stdinHandle = NativeMethods.CreateFile(
                    "NUL", 0x80000000u, 0x00000001u | 0x00000002u,
                    ref inheritable, 3u, 0x00000080u, IntPtr.Zero);
                if (stdinHandle == NativeMethods.INVALID_HANDLE_VALUE)
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateFile(NUL) failed.");

                job = NativeMethods.CreateJobObject(IntPtr.Zero, null);
                if (job == IntPtr.Zero)
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateJobObject failed.");
                NativeMethods.JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = new NativeMethods.JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
                limits.BasicLimitInformation.LimitFlags = 0x00002000u;
                int limitsSize = Marshal.SizeOf(typeof(NativeMethods.JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
                IntPtr limitsBuffer = Marshal.AllocHGlobal(limitsSize);
                try
                {
                    Marshal.StructureToPtr(limits, limitsBuffer, false);
                    if (!NativeMethods.SetInformationJobObject(job, 9, limitsBuffer, (uint)limitsSize))
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "SetInformationJobObject failed.");
                }
                finally { Marshal.FreeHGlobal(limitsBuffer); }

                NativeMethods.STARTUPINFO startup = new NativeMethods.STARTUPINFO();
                startup.cb = Marshal.SizeOf(typeof(NativeMethods.STARTUPINFO));
                startup.dwFlags = 0x00000100u;
                startup.hStdInput = stdinHandle;
                startup.hStdOutput = stdoutWrite;
                startup.hStdError = stderrWrite;
                StringBuilder mutableCommandLine = new StringBuilder(commandLine);
                lowerUtc = DateTime.UtcNow;
                if (!NativeMethods.CreateProcess(
                        applicationPath, mutableCommandLine, IntPtr.Zero, IntPtr.Zero, true,
                        0x00000004u | 0x08000000u | 0x00000400u,
                        IntPtr.Zero, workingDirectory, ref startup, out pi))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateProcessW(CREATE_SUSPENDED) failed.");
                processCreated = true;
                launchedImagePath = QueryNativeImagePath(pi.hProcess);
                if (!String.Equals(Path.GetFullPath(applicationPath), launchedImagePath, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("Suspended owned root image path did not equal the pinned executable path.");
                if (!NativeMethods.AssignProcessToJobObject(job, pi.hProcess))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "AssignProcessToJobObject failed.");
                jobAssigned = true;
                NativeMethods.CloseHandle(stdoutWrite); stdoutWrite = IntPtr.Zero;
                NativeMethods.CloseHandle(stderrWrite); stderrWrite = IntPtr.Zero;
                NativeMethods.CloseHandle(stdinHandle); stdinHandle = IntPtr.Zero;

                safeStdout = new SafeFileHandle(stdoutRead, true); stdoutRead = IntPtr.Zero;
                safeStderr = new SafeFileHandle(stderrRead, true); stderrRead = IntPtr.Zero;
                // CreatePipe returns synchronous handles. FileStream still
                // provides CopyToAsync via its managed async fallback, but the
                // handle itself must not be mislabeled as overlapped I/O.
                managedStdout = new FileStream(safeStdout, FileAccess.Read, 4096, false); safeStdout = null;
                managedStderr = new FileStream(safeStderr, FileAccess.Read, 4096, false); safeStderr = null;
                managedProcess = Process.GetProcessById(unchecked((int)pi.dwProcessId));
                IntPtr managedProcessHandle = managedProcess.Handle;
                if (managedProcessHandle == IntPtr.Zero || managedProcess.Id != unchecked((int)pi.dwProcessId))
                    throw new InvalidOperationException("Managed root wrapper did not bind the suspended native PID.");
                managedRootStartUtc = managedProcess.StartTime.ToUniversalTime();
                managedRootProcessName = managedProcess.ProcessName;
                DateTime nativeRootStartUtc = QueryNativeProcessStartUtc(pi.hProcess);
                DateTime identityUpperUtc = DateTime.UtcNow;
                if (managedRootStartUtc.Ticks != nativeRootStartUtc.Ticks ||
                    nativeRootStartUtc < lowerUtc || nativeRootStartUtc > identityUpperUtc ||
                    String.IsNullOrWhiteSpace(managedRootProcessName))
                    throw new InvalidOperationException("Managed root identity did not match the exact suspended native handle.");

                if (NativeMethods.ResumeThread(pi.hThread) == UInt32.MaxValue)
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "ResumeThread failed.");
                DateTime upperUtc = DateTime.UtcNow;
                NativeMethods.CloseHandle(pi.hThread); pi.hThread = IntPtr.Zero;
                if (forcePostWrapperSetupFailure)
                {
                    Thread.Sleep(1000);
                    throw new InvalidOperationException("Forced native post-wrapper setup failure for hostile validation.");
                }

                // Transfer native and managed ownership only after every
                // wrapper is constructed. Until this point the catch/finally
                // path retains exact authority over the job, root, and pipes.
                OwnedJobProcess result = new OwnedJobProcess();
                result.JobHandle = job;
                result.NativeProcessHandle = pi.hProcess;
                result.ProcessId = unchecked((int)pi.dwProcessId);
                result.RootStartUtc = managedRootStartUtc;
                result.RootProcessName = managedRootProcessName;
                result.LaunchedImagePath = launchedImagePath;
                result.LaunchLowerUtc = lowerUtc;
                result.LaunchUpperUtc = upperUtc;
                result.JobAssigned = true;
                result.Resumed = true;
                result.StandardOutput = managedStdout;
                result.StandardError = managedStderr;
                result.Process = managedProcess;
                job = IntPtr.Zero;
                pi.hProcess = IntPtr.Zero;
                managedStdout = null;
                managedStderr = null;
                managedProcess = null;
                return result;
            }
            catch (Exception caught)
            {
                try
                {
                    if (jobAssigned && job != IntPtr.Zero)
                    {
                        preTerminationActiveProcessCount = unchecked((int)QueryActiveProcessCount(job));
                        preTerminationMembershipCount = unchecked((int)QueryMembershipCount(job));
                        bool terminated = NativeMethods.TerminateJobObject(job, 125u);
                        DateTime deadline = DateTime.UtcNow.AddSeconds(5);
                        uint active;
                        do
                        {
                            active = QueryActiveProcessCount(job);
                            if (active == 0) break;
                            Thread.Sleep(25);
                        } while (DateTime.UtcNow < deadline);
                        finalActiveProcessCount = unchecked((int)QueryActiveProcessCount(job));
                        finalMembershipCount = unchecked((int)QueryMembershipCount(job));
                        accountingSucceeded = true;
                        cleanupSucceeded = terminated && finalActiveProcessCount == 0 && finalMembershipCount == 0;
                    }
                    else if (processCreated && pi.hProcess != IntPtr.Zero)
                    {
                        bool terminated = NativeMethods.TerminateProcess(pi.hProcess, 125u);
                        uint waitResult = NativeMethods.WaitForSingleObject(pi.hProcess, 5000u);
                        cleanupSucceeded = terminated && waitResult == 0u;
                        finalActiveProcessCount = cleanupSucceeded ? 0 : -1;
                        finalMembershipCount = cleanupSucceeded ? 0 : -1;
                    }
                    else
                    {
                        cleanupSucceeded = true;
                        finalActiveProcessCount = 0;
                        finalMembershipCount = 0;
                    }
                    if (jobAssigned && processCreated && pi.hProcess != IntPtr.Zero)
                        NativeMethods.WaitForSingleObject(pi.hProcess, 5000u);
                }
                catch { cleanupSucceeded = false; }
                InvalidOperationException wrapped = new InvalidOperationException("Atomic owned-job launch failed: " + caught.Message, caught);
                wrapped.Data["native_process_created"] = processCreated;
                wrapped.Data["native_process_id"] = unchecked((int)pi.dwProcessId);
                wrapped.Data["native_launched_image_path"] = launchedImagePath ?? String.Empty;
                wrapped.Data["native_job_assigned"] = jobAssigned;
                wrapped.Data["native_job_accounting_succeeded"] = accountingSucceeded;
                wrapped.Data["native_cleanup_succeeded"] = cleanupSucceeded;
                wrapped.Data["native_job_pretermination_active_process_count"] = preTerminationActiveProcessCount;
                wrapped.Data["native_job_pretermination_membership_count"] = preTerminationMembershipCount;
                wrapped.Data["native_job_final_active_process_count"] = finalActiveProcessCount;
                wrapped.Data["native_job_final_membership_count"] = finalMembershipCount;
                throw wrapped;
            }
            finally
            {
                if (managedStdout != null) { try { managedStdout.Dispose(); } catch { } }
                if (managedStderr != null) { try { managedStderr.Dispose(); } catch { } }
                if (safeStdout != null) { try { safeStdout.Dispose(); } catch { } }
                if (safeStderr != null) { try { safeStderr.Dispose(); } catch { } }
                if (managedProcess != null) { try { managedProcess.Dispose(); } catch { } }
                if (pi.hThread != IntPtr.Zero) NativeMethods.CloseHandle(pi.hThread);
                if (pi.hProcess != IntPtr.Zero) NativeMethods.CloseHandle(pi.hProcess);
                if (stdoutRead != IntPtr.Zero) NativeMethods.CloseHandle(stdoutRead);
                if (stdoutWrite != IntPtr.Zero) NativeMethods.CloseHandle(stdoutWrite);
                if (stderrRead != IntPtr.Zero) NativeMethods.CloseHandle(stderrRead);
                if (stderrWrite != IntPtr.Zero) NativeMethods.CloseHandle(stderrWrite);
                if (stdinHandle != IntPtr.Zero && stdinHandle != NativeMethods.INVALID_HANDLE_VALUE) NativeMethods.CloseHandle(stdinHandle);
                if (job != IntPtr.Zero) NativeMethods.CloseHandle(job);
            }
        }
    }

    internal static class NativeMethods
    {
        internal static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

        [StructLayout(LayoutKind.Sequential)]
        internal struct SECURITY_ATTRIBUTES { internal int nLength; internal IntPtr lpSecurityDescriptor; [MarshalAs(UnmanagedType.Bool)] internal bool bInheritHandle; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        internal struct STARTUPINFO
        {
            internal int cb; internal string lpReserved; internal string lpDesktop; internal string lpTitle;
            internal uint dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            internal short wShowWindow, cbReserved2; internal IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct PROCESS_INFORMATION { internal IntPtr hProcess, hThread; internal uint dwProcessId, dwThreadId; }
        [StructLayout(LayoutKind.Sequential)]
        internal struct FILETIME { internal uint dwLowDateTime, dwHighDateTime; }
        [StructLayout(LayoutKind.Sequential)]
        internal struct JOBOBJECT_BASIC_LIMIT_INFORMATION
        {
            internal long PerProcessUserTimeLimit, PerJobUserTimeLimit; internal uint LimitFlags;
            internal UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize; internal uint ActiveProcessLimit;
            internal UIntPtr Affinity; internal uint PriorityClass, SchedulingClass;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct IO_COUNTERS { internal ulong ReadOperationCount, WriteOperationCount, OtherOperationCount, ReadTransferCount, WriteTransferCount, OtherTransferCount; }
        [StructLayout(LayoutKind.Sequential)]
        internal struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION
        {
            internal JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation; internal IO_COUNTERS IoInfo;
            internal UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
        }
        [StructLayout(LayoutKind.Sequential)]
        internal struct JOBOBJECT_BASIC_ACCOUNTING_INFORMATION
        {
            internal long TotalUserTime, TotalKernelTime, ThisPeriodTotalUserTime, ThisPeriodTotalKernelTime;
            internal uint TotalPageFaultCount, TotalProcesses, ActiveProcesses, TotalTerminatedProcesses;
        }

        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool CreatePipe(out IntPtr read, out IntPtr write, ref SECURITY_ATTRIBUTES attributes, uint size);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool SetHandleInformation(IntPtr handle, uint mask, uint flags);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern IntPtr CreateFile(string name, uint access, uint share, ref SECURITY_ATTRIBUTES attributes, uint creation, uint flags, IntPtr template);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        internal static extern bool CreateProcess(string applicationName, StringBuilder commandLine, IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles, uint flags, IntPtr environment, string currentDirectory, ref STARTUPINFO startup, out PROCESS_INFORMATION processInfo);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern uint ResumeThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool TerminateJobObject(IntPtr job, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool TerminateProcess(IntPtr process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool GetProcessTimes(IntPtr process, out FILETIME creation, out FILETIME exit, out FILETIME kernel, out FILETIME user);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern bool QueryFullProcessImageName(IntPtr process, uint flags, StringBuilder path, ref uint size);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool QueryInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length, out uint returned);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool QueryInformationJobObject(IntPtr job, int infoClass, out JOBOBJECT_BASIC_ACCOUNTING_INFORMATION info, uint length, out uint returned);
    }
}
'@

# Filesystem custody uses native volume/file-index identities rather than path
# strings.  Every destructive operation acquires a handle to the exact object,
# revalidates its identity/type, and marks that handle for deletion.  A path
# replacement is therefore retained and makes the caller fail closed.
$script:q009ExactFileSystemTypeInitialized=$false
if($null-ne('Q009ExactFileSystemNative' -as [type])){throw 'Q-009 support refuses an ambient/reused exact-filesystem native type before its exact source is loaded.'}
function Initialize-Q009ExactFileSystemType {
    if($script:q009ExactFileSystemTypeInitialized){
        if($null-eq('Q009ExactFileSystemNative' -as [type])){throw 'Q-009 exact-filesystem type disappeared after source-bound initialization'}
        return
    }
    if($null-ne('Q009ExactFileSystemNative' -as [type])){throw 'Q-009 exact-filesystem type appeared before source-bound initialization'}
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;

public static class Q009ExactFileSystemNative {
    [StructLayout(LayoutKind.Sequential)] private struct FILETIME { public uint Low; public uint High; }
    [StructLayout(LayoutKind.Sequential)] private struct BY_HANDLE_FILE_INFORMATION {
        public uint FileAttributes; public FILETIME CreationTime; public FILETIME LastAccessTime; public FILETIME LastWriteTime;
        public uint VolumeSerialNumber; public uint FileSizeHigh; public uint FileSizeLow; public uint NumberOfLinks;
        public uint FileIndexHigh; public uint FileIndexLow;
    }
    [StructLayout(LayoutKind.Sequential)] private struct FILE_DISPOSITION_INFO { public byte DeleteFile; }
    [StructLayout(LayoutKind.Sequential)] private struct FILE_DISPOSITION_INFO_EX { public uint Flags; }
    [StructLayout(LayoutKind.Sequential)] private struct FILE_BASIC_INFO {
        public long CreationTime; public long LastAccessTime; public long LastWriteTime; public long ChangeTime; public uint FileAttributes;
    }
    [StructLayout(LayoutKind.Sequential)] private struct FILE_STANDARD_INFO {
        public long AllocationSize; public long EndOfFile; public uint NumberOfLinks;
        public byte DeletePending;
        public byte Directory;
    }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [DllImport("kernel32.dll", EntryPoint="CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFileWRaw(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    [StructLayout(LayoutKind.Sequential)] private struct UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
    [StructLayout(LayoutKind.Sequential)] private struct OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }
    [StructLayout(LayoutKind.Sequential)] private struct IO_STATUS_BLOCK { public IntPtr Status; public IntPtr Information; }
    [DllImport("ntdll.dll")]
    private static extern uint NtCreateFile(out IntPtr fileHandle, uint desiredAccess, ref OBJECT_ATTRIBUTES objectAttributes, out IO_STATUS_BLOCK ioStatusBlock, IntPtr allocationSize, uint fileAttributes, uint shareAccess, uint createDisposition, uint createOptions, IntPtr eaBuffer, uint eaLength);
    [DllImport("ntdll.dll")]
    private static extern uint RtlNtStatusToDosError(uint status);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out BY_HANDLE_FILE_INFORMATION info);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetFileInformationByHandle(SafeFileHandle handle, int infoClass, ref FILE_DISPOSITION_INFO info, uint size);
    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    private static extern bool SetExtendedFileDispositionByHandle(SafeFileHandle handle, int infoClass, ref FILE_DISPOSITION_INFO_EX info, uint size);
    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    private static extern bool SetBasicFileInformationByHandle(SafeFileHandle handle, int infoClass, ref FILE_BASIC_INFO info, uint size);
    [DllImport("kernel32.dll", EntryPoint = "SetFileInformationByHandle", SetLastError = true)]
    private static extern bool SetFileInformationByHandleRaw(SafeFileHandle handle, int infoClass, IntPtr info, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandleEx(SafeFileHandle handle, int infoClass, out FILE_STANDARD_INFO info, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool WriteFile(SafeFileHandle handle, byte[] buffer, uint bytesToWrite, out uint bytesWritten, IntPtr overlapped);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool ReadFile(SafeFileHandle handle, byte[] buffer, uint bytesToRead, out uint bytesRead, IntPtr overlapped);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool FlushFileBuffers(SafeFileHandle handle);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetFilePointerEx(SafeFileHandle handle, long distance, out long newPosition, uint moveMethod);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandle(SafeFileHandle handle, System.Text.StringBuilder path, uint length, uint flags);

    internal enum NativeHandleState { OPEN, CLOSE_IN_PROGRESS, CLOSED_NATIVE_SUCCESS, CLOSE_FAILED_HANDLE_RETAINED, UNKNOWN }
    internal sealed class CheckedNativeHandle {
        internal IntPtr Raw;
        internal bool Acquired;
        internal NativeHandleState State;
        internal CheckedNativeHandle() { Raw=IntPtr.Zero;Acquired=false;State=NativeHandleState.UNKNOWN; }
    }
    public sealed class CacheCustodyCell {
        private readonly Dictionary<string,CheckedNativeHandle> handles = new Dictionary<string,CheckedNativeHandle>(StringComparer.Ordinal);
        public readonly string AttemptId;
        internal CacheCustodyCell(string attemptId) { AttemptId=attemptId; }
        internal void Reserve(string slot) {
            if(String.IsNullOrWhiteSpace(slot) || handles.ContainsKey(slot)) throw new InvalidOperationException("Cache custody slot cannot be reserved: "+slot);
            handles.Add(slot,new CheckedNativeHandle());
        }
        internal void CancelReservation(string slot) {
            CheckedNativeHandle value;
            if(!handles.TryGetValue(slot,out value) || value==null || value.Acquired) throw new InvalidOperationException("Only an empty custody reservation may be cancelled: "+slot);
            handles.Remove(slot);
        }
        internal void AdoptRaw(string slot, IntPtr raw) {
            CheckedNativeHandle value;
            if (raw==IntPtr.Zero || raw==new IntPtr(-1)) throw new ArgumentException("Cache custody adoption requires a valid raw native handle.");
            if (!handles.TryGetValue(slot,out value) || value==null || value.Acquired) throw new InvalidOperationException("Cache custody slot was not uniquely reserved: "+slot);
            value.Raw=raw;value.Acquired=true;value.State=NativeHandleState.OPEN;
        }
        internal CheckedNativeHandle Require(string slot) {
            CheckedNativeHandle value;
            if (!handles.TryGetValue(slot,out value) || value==null || !value.Acquired) throw new InvalidOperationException("Cache custody slot was never acquired: "+slot);
            return value;
        }
        public string StateOf(string slot) { CheckedNativeHandle value;if(!handles.TryGetValue(slot,out value))return "UNREGISTERED";return value==null||!value.Acquired?"RESERVED_NO_HANDLE":value.State.ToString(); }
        public string[] NonTerminalSlots() {
            List<string> result=new List<string>();
            foreach(KeyValuePair<string,CheckedNativeHandle> pair in handles) if(pair.Value==null||!pair.Value.Acquired||pair.Value.State!=NativeHandleState.CLOSED_NATIVE_SUCCESS) result.Add(pair.Key+":"+(pair.Value==null||!pair.Value.Acquired?"RESERVED_NO_HANDLE":pair.Value.State.ToString()));
            result.Sort(StringComparer.Ordinal); return result.ToArray();
        }
        public string[] OpenSlots() {
            List<string> result=new List<string>();foreach(KeyValuePair<string,CheckedNativeHandle> pair in handles)if(pair.Value!=null&&pair.Value.Acquired&&pair.Value.State==NativeHandleState.OPEN)result.Add(pair.Key);result.Sort(StringComparer.Ordinal);return result.ToArray();
        }
        public string[] ClosableSlots() {
            List<string> result=new List<string>();
            foreach(KeyValuePair<string,CheckedNativeHandle> pair in handles)if(pair.Value!=null&&pair.Value.Acquired&&(pair.Value.State==NativeHandleState.OPEN||pair.Value.State==NativeHandleState.CLOSE_FAILED_HANDLE_RETAINED))result.Add(pair.Key);
            result.Sort(StringComparer.Ordinal);return result.ToArray();
        }
        public string[] StateReceipts() {
            List<string> result=new List<string>();foreach(KeyValuePair<string,CheckedNativeHandle> pair in handles)result.Add(pair.Key+"="+(pair.Value==null||!pair.Value.Acquired?"RESERVED_NO_HANDLE":pair.Value.State.ToString()));result.Sort(StringComparer.Ordinal);return result.ToArray();
        }
    }

    public static CacheCustodyCell NewCacheCustodyCell(string attemptId) {
        if(String.IsNullOrWhiteSpace(attemptId)) throw new ArgumentException("Cache custody attempt id is required.");
        return new CacheCustodyCell(attemptId);
    }
    public static string[] CloseCheckedNativeHandle(CacheCustodyCell cell, string slot, string context, string hostileMode) {
        if(cell==null) throw new ArgumentNullException("cell");
        CheckedNativeHandle owner=cell.Require(slot);
        if(owner.State!=NativeHandleState.OPEN&&owner.State!=NativeHandleState.CLOSE_FAILED_HANDLE_RETAINED) throw new InvalidOperationException(context+" native handle is not closable; state="+owner.State.ToString());
        if(String.Equals(hostileMode,"before",StringComparison.Ordinal)) { owner.State=NativeHandleState.CLOSE_FAILED_HANDLE_RETAINED;throw new IOException(context+" forced pre-close failure with positively retained live handle."); }
        owner.State=NativeHandleState.CLOSE_IN_PROGRESS;
        bool nativeAttempted=false,nativeSucceeded=false;
        try {
            nativeAttempted=true;
            if(!CloseHandle(owner.Raw)) throw new Win32Exception(Marshal.GetLastWin32Error(),context+" CloseHandle failed after a native close attempt.");
            nativeSucceeded=true;
            owner.Raw=IntPtr.Zero; owner.State=NativeHandleState.CLOSED_NATIVE_SUCCESS;
        } catch(Exception failure) {
            if(nativeSucceeded) { owner.Raw=IntPtr.Zero; owner.State=NativeHandleState.CLOSED_NATIVE_SUCCESS; }
            else owner.State=nativeAttempted?NativeHandleState.UNKNOWN:NativeHandleState.CLOSE_FAILED_HANDLE_RETAINED;
            throw new IOException(context+" checked native close failed; state="+owner.State.ToString(),failure);
        }
        if(String.Equals(hostileMode,"after_success",StringComparison.Ordinal)) throw new IOException(context+" forced reporting failure after native close success.");
        if(!String.IsNullOrEmpty(hostileMode)) throw new ArgumentException(context+" unknown close hostile mode.");
        return new string[] { "CLOSED_NATIVE_SUCCESS", context, DateTime.UtcNow.ToString("o") };
    }
    private static SafeFileHandle Borrow(CacheCustodyCell cell, string slot, string context) {
        if(cell==null) throw new ArgumentNullException("cell");
        CheckedNativeHandle owner=cell.Require(slot);
        if (owner.State!=NativeHandleState.OPEN || owner.Raw==IntPtr.Zero || owner.Raw==new IntPtr(-1)) throw new InvalidOperationException(context + " checked native handle is not OPEN.");
        return new SafeFileHandle(owner.Raw,false);
    }

    private sealed class OwnedEntry : IDisposable {
        public string RelativePath; public string FullPath; public bool IsDirectory; public uint Attributes; public SafeFileHandle Handle;
        public void Dispose() { if (Handle != null) { Handle.Dispose(); Handle = null; } }
    }
    private static string NativeKey(BY_HANDLE_FILE_INFORMATION info) {
        return String.Format("{0:X8}:{1:X8}{2:X8}", info.VolumeSerialNumber, info.FileIndexHigh, info.FileIndexLow);
    }
    private static long CreationTicks(BY_HANDLE_FILE_INFORMATION info) {
        long value = ((long)info.CreationTime.High << 32) | (long)info.CreationTime.Low;
        return DateTime.FromFileTimeUtc(value).Ticks;
    }
    private static string[] Describe(BY_HANDLE_FILE_INFORMATION info) {
        return new string[] { NativeKey(info), CreationTicks(info).ToString(System.Globalization.CultureInfo.InvariantCulture), info.FileAttributes.ToString(System.Globalization.CultureInfo.InvariantCulture) };
    }
    private static long FileLength(BY_HANDLE_FILE_INFORMATION info) {
        return checked(((long)info.FileSizeHigh << 32) | (long)info.FileSizeLow);
    }
    private static string HashExactOpenFile(SafeFileHandle handle,long expectedLength) {
        long position;
        if(!SetFilePointerEx(handle,0,out position,0u)||position!=0)throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not rewind exact manifest file for hashing.");
        using(SHA256 sha=SHA256.Create()) {
            byte[] buffer=new byte[65536];long total=0;
            while(true){uint read;if(!ReadFile(handle,buffer,(uint)buffer.Length,out read,IntPtr.Zero))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not read exact manifest file for hashing.");if(read==0)break;sha.TransformBlock(buffer,0,(int)read,null,0);total+=read;}
            sha.TransformFinalBlock(new byte[0],0,0);
            if(total!=expectedLength)throw new IOException("Exact manifest file length changed during handle-bound hashing.");
            return BitConverter.ToString(sha.Hash).Replace("-","");
        }
    }
    public static string[] GetIdentity(string path, bool directory) {
        const uint READ_ATTRIBUTES = 0x80, SHARE_READ = 1, SHARE_WRITE = 2, SHARE_DELETE = 4, OPEN_EXISTING = 3;
        const uint OPEN_REPARSE = 0x00200000, BACKUP = 0x02000000;
        uint flags = OPEN_REPARSE | (directory ? BACKUP : 0);
        using (SafeFileHandle handle = CreateFileW(path, READ_ATTRIBUTES, SHARE_READ | SHARE_WRITE | SHARE_DELETE, IntPtr.Zero, OPEN_EXISTING, flags, IntPtr.Zero)) {
            if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not open exact filesystem identity: " + path);
            BY_HANDLE_FILE_INFORMATION info;
            if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read exact filesystem identity: " + path);
            return Describe(info);
        }
    }
    public static string[] CreateDirectoryNewHeld(CacheCustodyCell cell, string slot, string parentPath, string childName, string expectedParentKey, long expectedParentCreationTicks, string hostileMode) {
        if(cell==null) throw new ArgumentNullException("cell");
        string parentFull = Path.GetFullPath(parentPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (String.IsNullOrWhiteSpace(childName) || childName != Path.GetFileName(childName) || childName == "." || childName == "..") throw new ArgumentException("Exact owned directory child name must be one path leaf.");
        if(String.IsNullOrWhiteSpace(slot)) throw new ArgumentException("Exact owned directory custody slot is required.");
        string parentSlot=slot+":parent";
        cell.Reserve(slot);cell.Reserve(parentSlot);
        const uint READ_ATTRIBUTES = 0x80u, LIST_DIRECTORY = 0x1u, DELETE = 0x00010000u, SYNCHRONIZE = 0x00100000u;
        const uint SHARE_READ_WRITE = 0x1u | 0x2u, SHARE_READ_WRITE_DELETE = SHARE_READ_WRITE | 0x4u, OPEN_EXISTING = 3u, BACKUP = 0x02000000u, OPEN_REPARSE = 0x00200000u;
        IntPtr text = IntPtr.Zero, unicodePointer = IntPtr.Zero, parentRaw = IntPtr.Zero, rawHandle = IntPtr.Zero;
        bool created = false;
        string createdPath = Path.Combine(parentFull, childName);
        try {
            parentRaw=CreateFileWRaw(parentFull,READ_ATTRIBUTES|LIST_DIRECTORY|SYNCHRONIZE,SHARE_READ_WRITE_DELETE,IntPtr.Zero,OPEN_EXISTING,BACKUP|OPEN_REPARSE,IntPtr.Zero);
            if(parentRaw==IntPtr.Zero||parentRaw==new IntPtr(-1)){int error=Marshal.GetLastWin32Error();cell.CancelReservation(parentSlot);cell.CancelReservation(slot);throw new Win32Exception(error,"Could not open exact parent for atomic owned directory creation: "+parentFull);}
            cell.AdoptRaw(parentSlot,parentRaw);parentRaw=IntPtr.Zero;
            BY_HANDLE_FILE_INFORMATION parentInfo;
            using(SafeFileHandle parentBorrow=Borrow(cell,parentSlot,"Atomic owned directory parent proof")) {
                if (!GetFileInformationByHandle(parentBorrow, out parentInfo)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not inspect exact parent for atomic owned directory creation: " + parentFull);
            }
            if ((parentInfo.FileAttributes & 0x10u) == 0u || (parentInfo.FileAttributes & 0x400u) != 0u || NativeKey(parentInfo) != expectedParentKey || CreationTicks(parentInfo) != expectedParentCreationTicks) throw new IOException("Atomic owned directory parent identity/type changed before creation: " + parentFull);
            text = Marshal.StringToHGlobalUni(childName);
            UNICODE_STRING unicode = new UNICODE_STRING { Length = checked((ushort)(childName.Length * 2)), MaximumLength = checked((ushort)((childName.Length + 1) * 2)), Buffer = text };
            unicodePointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UNICODE_STRING)));
            Marshal.StructureToPtr(unicode, unicodePointer, false);
            IntPtr parentHandleValue;using(SafeFileHandle parentBorrow=Borrow(cell,parentSlot,"Atomic owned directory relative create")){parentHandleValue=parentBorrow.DangerousGetHandle();}
            OBJECT_ATTRIBUTES attributes = new OBJECT_ATTRIBUTES { Length = Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES)), RootDirectory = parentHandleValue, ObjectName = unicodePointer, Attributes = 0x40u, SecurityDescriptor = IntPtr.Zero, SecurityQualityOfService = IntPtr.Zero };
            IO_STATUS_BLOCK statusBlock;
            const uint FILE_CREATE = 2u;
            const uint DIRECTORY_FILE = 0x1u, SYNCHRONOUS_IO_NONALERT = 0x20u, OPEN_REPARSE_POINT = 0x00200000u;
            uint status = NtCreateFile(out rawHandle, READ_ATTRIBUTES | DELETE | SYNCHRONIZE, ref attributes, out statusBlock, IntPtr.Zero, 0x80u, SHARE_READ_WRITE, FILE_CREATE, DIRECTORY_FILE | SYNCHRONOUS_IO_NONALERT | OPEN_REPARSE_POINT, IntPtr.Zero, 0u);
            if (status != 0u) {cell.CancelReservation(slot);throw new Win32Exception((int)RtlNtStatusToDosError(status), "Could not atomically create exact owned directory child: " + childName);}
            created = true;
            cell.AdoptRaw(slot,rawHandle);rawHandle=IntPtr.Zero;
            if(String.Equals(hostileMode,"after_acquire",StringComparison.Ordinal)) throw new IOException("Forced directory post-acquire proof failure.");
            BY_HANDLE_FILE_INFORMATION info;
            using(SafeFileHandle createdBorrow=Borrow(cell,slot,"Atomic owned directory proof")) {
                if (!GetFileInformationByHandle(createdBorrow, out info)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read atomically created directory identity: " + childName);
            }
            if ((info.FileAttributes & 0x10u) == 0u || (info.FileAttributes & 0x400u) != 0u) throw new IOException("Atomically created directory has an invalid native type: " + childName);
            if(String.Equals(hostileMode,"after_proof",StringComparison.Ordinal)) throw new IOException("Forced directory post-proof registration failure.");
            if(!String.IsNullOrEmpty(hostileMode)) throw new ArgumentException("Unknown directory creation hostile mode.");
            CloseCheckedNativeHandle(cell,parentSlot,"Atomic owned directory parent","");
            return Describe(info);
        } catch (Exception failure) {
            if (rawHandle != IntPtr.Zero && rawHandle != new IntPtr(-1)) { cell.AdoptRaw(slot,rawHandle);rawHandle=IntPtr.Zero;created=true; }
            if (parentRaw != IntPtr.Zero && parentRaw != new IntPtr(-1)) { cell.AdoptRaw(parentSlot,parentRaw);parentRaw=IntPtr.Zero; }
            Exception parentReleaseFailure = null;
            if (cell.StateOf(parentSlot)=="OPEN") { try { CloseCheckedNativeHandle(cell,parentSlot,"Atomic owned directory parent failure",""); } catch(Exception caught) { parentReleaseFailure=caught; } }
            IOException wrapped = new IOException(created
                ? "Atomic owned directory post-create proof failed; the exact created path was preserved: " + createdPath
                : "Atomic owned directory creation failed before a directory was proved: " + createdPath,
                parentReleaseFailure == null ? failure : new AggregateException(failure, parentReleaseFailure));
            wrapped.Data["created"] = created;
            wrapped.Data["preserved_path"] = created ? createdPath : "";
            wrapped.Data["retained_handle_transferred"] = created && cell.StateOf(slot)!="CLOSED_NATIVE_SUCCESS";
            wrapped.Data["retained_handle_slot"] = created ? slot : "";
            wrapped.Data["parent_handle_release_failed"] = parentReleaseFailure != null;
            if (parentReleaseFailure != null) { wrapped.Data["parent_handle_release_error"] = parentReleaseFailure.Message; }
            throw wrapped;
        } finally {
            if (unicodePointer != IntPtr.Zero) Marshal.FreeHGlobal(unicodePointer);
            if (text != IntPtr.Zero) Marshal.FreeHGlobal(text);
        }
    }
    public static string[] CreateDirectoryNew(string parentPath, string childName, string expectedParentKey, long expectedParentCreationTicks) {
        CacheCustodyCell cell=NewCacheCustodyCell("non-retained-"+Guid.NewGuid().ToString("N"));
        string[] identity=CreateDirectoryNewHeld(cell,"directory",parentPath,childName,expectedParentKey,expectedParentCreationTicks,"");
        try {
            BY_HANDLE_FILE_INFORMATION info;
            using(SafeFileHandle borrowed=Borrow(cell,"directory","Atomic owned directory readback")){if (!GetFileInformationByHandle(borrowed, out info)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read atomically created directory identity.");}
            return Describe(info);
        } finally { if(cell.StateOf("directory")=="OPEN") CloseCheckedNativeHandle(cell,"directory","Atomic owned directory non-retained close",""); }
    }
    public static string[] GetIdentityFromHandle(CacheCustodyCell cell, string slot) {
        BY_HANDLE_FILE_INFORMATION info;
        using(SafeFileHandle borrowed=Borrow(cell,slot,"Exact identity")){if (!GetFileInformationByHandle(borrowed, out info)) throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not read exact handle identity.");}
        return Describe(info);
    }
    public static string[] GetIdentityFromSafeHandle(SafeFileHandle handle) {
        if(handle==null||handle.IsInvalid||handle.IsClosed)throw new ArgumentException("Exact safe-handle identity requires one live valid handle.");
        BY_HANDLE_FILE_INFORMATION info;
        if(!GetFileInformationByHandle(handle,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not read exact safe-handle identity.");
        return Describe(info);
    }
    public static string[] CreateFileNewHeld(CacheCustodyCell cell, string parentSlot, string slot, string childName, string expectedParentKey, long expectedParentCreationTicks, byte[] payload, bool shareRead, string hostileMode) {
        if(cell==null) throw new ArgumentNullException("cell");
        if(String.IsNullOrWhiteSpace(slot)||String.IsNullOrWhiteSpace(childName)||childName!=Path.GetFileName(childName)||childName=="."||childName=="..") throw new ArgumentException("Exact held file requires one named child and custody slot.");
        if(payload==null||payload.Length==0) throw new ArgumentException("Exact held file payload is required.");
        cell.Reserve(slot);
        IntPtr text=IntPtr.Zero,unicodePointer=IntPtr.Zero,rawHandle=IntPtr.Zero;
        try {
            BY_HANDLE_FILE_INFORMATION parentInfo;
            using(SafeFileHandle parentBorrow=Borrow(cell,parentSlot,"Exact held file parent proof")){if(!GetFileInformationByHandle(parentBorrow,out parentInfo))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect exact held file parent.");}
            if((parentInfo.FileAttributes&0x10u)==0u||(parentInfo.FileAttributes&0x400u)!=0u||NativeKey(parentInfo)!=expectedParentKey||CreationTicks(parentInfo)!=expectedParentCreationTicks)throw new IOException("Exact held file parent identity/type changed before relative create.");
            text=Marshal.StringToHGlobalUni(childName);
            UNICODE_STRING unicode=new UNICODE_STRING{Length=checked((ushort)(childName.Length*2)),MaximumLength=checked((ushort)((childName.Length+1)*2)),Buffer=text};
            unicodePointer=Marshal.AllocHGlobal(Marshal.SizeOf(typeof(UNICODE_STRING)));Marshal.StructureToPtr(unicode,unicodePointer,false);
            IntPtr parentValue;using(SafeFileHandle parentBorrow=Borrow(cell,parentSlot,"Exact held file relative create")){parentValue=parentBorrow.DangerousGetHandle();}
            OBJECT_ATTRIBUTES attributes=new OBJECT_ATTRIBUTES{Length=Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES)),RootDirectory=parentValue,ObjectName=unicodePointer,Attributes=0x40u,SecurityDescriptor=IntPtr.Zero,SecurityQualityOfService=IntPtr.Zero};
            IO_STATUS_BLOCK statusBlock;const uint FILE_CREATE=2u,NON_DIRECTORY_FILE=0x40u,SYNCHRONOUS_IO_NONALERT=0x20u,OPEN_REPARSE_POINT=0x00200000u;
            const uint READ_DATA=0x1u,WRITE_DATA=0x2u,READ_ATTRIBUTES=0x80u,DELETE=0x00010000u,SYNCHRONIZE=0x00100000u,SHARE_READ=0x1u;
            uint shareMode=shareRead?SHARE_READ:0u;
            uint status=NtCreateFile(out rawHandle,READ_DATA|WRITE_DATA|READ_ATTRIBUTES|DELETE|SYNCHRONIZE,ref attributes,out statusBlock,IntPtr.Zero,0x80u,shareMode,FILE_CREATE,NON_DIRECTORY_FILE|SYNCHRONOUS_IO_NONALERT|OPEN_REPARSE_POINT,IntPtr.Zero,0u);
            if(status!=0u){cell.CancelReservation(slot);throw new Win32Exception((int)RtlNtStatusToDosError(status),"Could not atomically create exact held file: "+childName);}
            cell.AdoptRaw(slot,rawHandle);rawHandle=IntPtr.Zero;
            if(String.Equals(hostileMode,"after_acquire",StringComparison.Ordinal))throw new IOException("Forced held-file post-acquire proof failure.");
            BY_HANDLE_FILE_INFORMATION info;uint written,read;long position;byte[] readback=new byte[payload.Length];
            using(SafeFileHandle fileBorrow=Borrow(cell,slot,"Exact held file initialize")){
                if(!GetFileInformationByHandle(fileBorrow,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect atomically created held file.");
                if((info.FileAttributes&0x10u)!=0u||(info.FileAttributes&0x400u)!=0u)throw new IOException("Atomically created held file has an invalid native type.");
                if(!WriteFile(fileBorrow,payload,(uint)payload.Length,out written,IntPtr.Zero)||written!=(uint)payload.Length)throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not write exact held-file payload.");
                if(!FlushFileBuffers(fileBorrow))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not flush exact held-file payload.");
                if(!SetFilePointerEx(fileBorrow,0,out position,0u)||position!=0)throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not rewind exact held-file payload.");
                if(!ReadFile(fileBorrow,readback,(uint)readback.Length,out read,IntPtr.Zero)||read!=(uint)readback.Length)throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not read back exact held-file payload.");
            }
            for(int i=0;i<payload.Length;i++)if(payload[i]!=readback[i])throw new IOException("Exact held-file payload readback differed.");
            if(String.Equals(hostileMode,"after_proof",StringComparison.Ordinal))throw new IOException("Forced held-file post-proof registration failure.");
            if(!String.IsNullOrEmpty(hostileMode))throw new ArgumentException("Unknown held-file creation hostile mode.");
            return Describe(info);
        } catch(Exception failure) {
            if(rawHandle!=IntPtr.Zero&&rawHandle!=new IntPtr(-1)){cell.AdoptRaw(slot,rawHandle);rawHandle=IntPtr.Zero;}
            IOException wrapped=new IOException("Exact held-file creation/proof failed; custody state="+cell.StateOf(slot),failure);
            wrapped.Data["retained_handle_slot"]=slot;wrapped.Data["retained_handle_state"]=cell.StateOf(slot);throw wrapped;
        } finally {
            if(unicodePointer!=IntPtr.Zero)Marshal.FreeHGlobal(unicodePointer);if(text!=IntPtr.Zero)Marshal.FreeHGlobal(text);
        }
    }
    public static string[] OpenDirectoryHeldExact(CacheCustodyCell cell,string slot,string path,string expectedKey,long expectedCreationTicks,string hostileMode) {
        if(cell==null)throw new ArgumentNullException("cell");
        string candidate=Path.GetFullPath(path);string pathRoot=Path.GetPathRoot(candidate);string full=String.Equals(candidate,pathRoot,StringComparison.OrdinalIgnoreCase)?pathRoot:candidate.TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);if(String.IsNullOrWhiteSpace(slot))throw new ArgumentException("Final root custody slot is required.");
        cell.Reserve(slot);IntPtr raw=IntPtr.Zero;
        try {
            const uint READ_ATTRIBUTES=0x80u,LIST_DIRECTORY=0x1u,DELETE=0x00010000u,SYNCHRONIZE=0x00100000u,SHARE_READ_WRITE=0x1u|0x2u,OPEN_EXISTING=3u,BACKUP=0x02000000u,OPEN_REPARSE=0x00200000u;
            raw=CreateFileWRaw(full,READ_ATTRIBUTES|LIST_DIRECTORY|DELETE|SYNCHRONIZE,SHARE_READ_WRITE,IntPtr.Zero,OPEN_EXISTING,BACKUP|OPEN_REPARSE,IntPtr.Zero);
            if(raw==IntPtr.Zero||raw==new IntPtr(-1)){int error=Marshal.GetLastWin32Error();cell.CancelReservation(slot);throw new Win32Exception(error,"Could not open exact final cache root.");}
            cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;
            if(String.Equals(hostileMode,"after_acquire",StringComparison.Ordinal))throw new IOException("Forced final-root post-acquire proof failure.");
            BY_HANDLE_FILE_INFORMATION info;using(SafeFileHandle borrowed=Borrow(cell,slot,"Final cache root proof")){if(!GetFileInformationByHandle(borrowed,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect final cache root handle.");}
            if((info.FileAttributes&0x10u)==0u||(info.FileAttributes&0x400u)!=0u||NativeKey(info)!=expectedKey||CreationTicks(info)!=expectedCreationTicks)throw new IOException("Final cache root handle identity/type changed.");
            if(String.Equals(hostileMode,"after_proof",StringComparison.Ordinal))throw new IOException("Forced final-root post-proof registration failure.");
            if(!String.IsNullOrEmpty(hostileMode))throw new ArgumentException("Unknown final-root hostile mode.");
            return Describe(info);
        } catch(Exception failure) {
            if(raw!=IntPtr.Zero&&raw!=new IntPtr(-1)){cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;}
            IOException wrapped=new IOException("Final cache-root acquisition/proof failed; custody state="+cell.StateOf(slot),failure);wrapped.Data["retained_handle_slot"]=slot;wrapped.Data["retained_handle_state"]=cell.StateOf(slot);throw wrapped;
        }
    }
    public static string[] OpenDirectoryReadHeldExact(CacheCustodyCell cell,string slot,string path,string expectedKey,long expectedCreationTicks,string hostileMode) {
        if(cell==null)throw new ArgumentNullException("cell");
        string candidate=Path.GetFullPath(path);string pathRoot=Path.GetPathRoot(candidate);string full=String.Equals(candidate,pathRoot,StringComparison.OrdinalIgnoreCase)?pathRoot:candidate.TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);if(String.IsNullOrWhiteSpace(slot))throw new ArgumentException("Read-only directory custody slot is required.");
        cell.Reserve(slot);IntPtr raw=IntPtr.Zero;
        try {
            // Executable ancestry is authority, never a deletion target.  The
            // handle permits only listing/identity reads and deliberately
            // omits FILE_SHARE_DELETE so rename/replacement remains blocked.
            const uint READ_ATTRIBUTES=0x80u,LIST_DIRECTORY=0x1u,SYNCHRONIZE=0x00100000u,SHARE_READ_WRITE=0x1u|0x2u,OPEN_EXISTING=3u,BACKUP=0x02000000u,OPEN_REPARSE=0x00200000u;
            raw=CreateFileWRaw(full,READ_ATTRIBUTES|LIST_DIRECTORY|SYNCHRONIZE,SHARE_READ_WRITE,IntPtr.Zero,OPEN_EXISTING,BACKUP|OPEN_REPARSE,IntPtr.Zero);
            if(raw==IntPtr.Zero||raw==new IntPtr(-1)){int error=Marshal.GetLastWin32Error();cell.CancelReservation(slot);throw new Win32Exception(error,"Could not open exact read-only directory authority.");}
            cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;
            if(String.Equals(hostileMode,"after_acquire",StringComparison.Ordinal))throw new IOException("Forced read-only directory post-acquire proof failure.");
            BY_HANDLE_FILE_INFORMATION info;using(SafeFileHandle borrowed=Borrow(cell,slot,"Read-only directory authority proof")){if(!GetFileInformationByHandle(borrowed,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect read-only directory authority handle.");}
            if((info.FileAttributes&0x10u)==0u||(info.FileAttributes&0x400u)!=0u||NativeKey(info)!=expectedKey||CreationTicks(info)!=expectedCreationTicks)throw new IOException("Read-only directory authority identity/type changed.");
            if(String.Equals(hostileMode,"after_proof",StringComparison.Ordinal))throw new IOException("Forced read-only directory post-proof registration failure.");
            if(!String.IsNullOrEmpty(hostileMode))throw new ArgumentException("Unknown read-only directory hostile mode.");
            return Describe(info);
        } catch(Exception failure) {
            if(raw!=IntPtr.Zero&&raw!=new IntPtr(-1)){cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;}
            IOException wrapped=new IOException("Read-only directory authority acquisition/proof failed; custody state="+cell.StateOf(slot),failure);wrapped.Data["retained_handle_slot"]=slot;wrapped.Data["retained_handle_state"]=cell.StateOf(slot);throw wrapped;
        }
    }
    public static string[] OpenFileHeldExact(CacheCustodyCell cell,string slot,string path,string expectedKey,long expectedCreationTicks,string hostileMode) {
        if(cell==null)throw new ArgumentNullException("cell");
        string full=Path.GetFullPath(path);if(String.IsNullOrWhiteSpace(slot))throw new ArgumentException("Exact held file custody slot is required.");
        cell.Reserve(slot);IntPtr raw=IntPtr.Zero;
        try {
            const uint READ_DATA=0x1u,READ_ATTRIBUTES=0x80u,SYNCHRONIZE=0x00100000u,SHARE_READ=0x1u,OPEN_EXISTING=3u,OPEN_REPARSE=0x00200000u;
            raw=CreateFileWRaw(full,READ_DATA|READ_ATTRIBUTES|SYNCHRONIZE,SHARE_READ,IntPtr.Zero,OPEN_EXISTING,OPEN_REPARSE,IntPtr.Zero);
            if(raw==IntPtr.Zero||raw==new IntPtr(-1)){int error=Marshal.GetLastWin32Error();cell.CancelReservation(slot);throw new Win32Exception(error,"Could not open exact held file.");}
            cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;
            if(String.Equals(hostileMode,"after_acquire",StringComparison.Ordinal))throw new IOException("Forced held-file open post-acquire proof failure.");
            BY_HANDLE_FILE_INFORMATION info;using(SafeFileHandle borrowed=Borrow(cell,slot,"Exact held file proof")){if(!GetFileInformationByHandle(borrowed,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect exact held file handle.");}
            if((info.FileAttributes&0x10u)!=0u||(info.FileAttributes&0x400u)!=0u||NativeKey(info)!=expectedKey||CreationTicks(info)!=expectedCreationTicks)throw new IOException("Exact held file handle identity/type changed.");
            if(String.Equals(hostileMode,"after_proof",StringComparison.Ordinal))throw new IOException("Forced held-file open post-proof registration failure.");
            if(!String.IsNullOrEmpty(hostileMode))throw new ArgumentException("Unknown held-file open hostile mode.");
            return Describe(info);
        } catch(Exception failure) {
            if(raw!=IntPtr.Zero&&raw!=new IntPtr(-1)){cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;}
            IOException wrapped=new IOException("Exact held-file acquisition/proof failed; custody state="+cell.StateOf(slot),failure);wrapped.Data["retained_handle_slot"]=slot;wrapped.Data["retained_handle_state"]=cell.StateOf(slot);throw wrapped;
        }
    }
    private static string NormalizeFinalPath(string value) {
        if(value.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))return @"\\"+value.Substring(8);
        if(value.StartsWith(@"\\?\",StringComparison.OrdinalIgnoreCase))return value.Substring(4);
        return value;
    }
    public static string GetFinalPathFromHeldHandle(CacheCustodyCell cell,string slot) {
        using(SafeFileHandle borrowed=Borrow(cell,slot,"Exact held final-path proof")){
            System.Text.StringBuilder path=new System.Text.StringBuilder(32768);uint length=GetFinalPathNameByHandle(borrowed,path,(uint)path.Capacity,0u);
            if(length==0u||length>=(uint)path.Capacity)throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not resolve exact held final path.");
            return Path.GetFullPath(NormalizeFinalPath(path.ToString(0,checked((int)length))));
        }
    }
    public static string GetFinalPathFromSafeHandle(SafeFileHandle handle) {
        if(handle==null||handle.IsInvalid||handle.IsClosed)throw new ArgumentException("Exact final-path proof requires one live valid safe handle.");
        System.Text.StringBuilder path=new System.Text.StringBuilder(32768);uint length=GetFinalPathNameByHandle(handle,path,(uint)path.Capacity,0u);
        if(length==0u||length>=(uint)path.Capacity)throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not resolve exact safe-handle final path.");
        return Path.GetFullPath(NormalizeFinalPath(path.ToString(0,checked((int)length))));
    }
    public static string[] DescribeHeldFile(CacheCustodyCell cell,string slot) {
        BY_HANDLE_FILE_INFORMATION info;using(SafeFileHandle borrowed=Borrow(cell,slot,"Exact held file description")){
            if(!GetFileInformationByHandle(borrowed,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect exact held file.");
            if((info.FileAttributes&0x10u)!=0u||(info.FileAttributes&0x400u)!=0u)throw new IOException("Exact held file has an invalid native type.");
            long length=FileLength(info);string hash=HashExactOpenFile(borrowed,length);
            return new string[]{NativeKey(info),CreationTicks(info).ToString(System.Globalization.CultureInfo.InvariantCulture),info.FileAttributes.ToString(System.Globalization.CultureInfo.InvariantCulture),length.ToString(System.Globalization.CultureInfo.InvariantCulture),hash};
        }
    }
    public static string[] GetHeldHandleState(CacheCustodyCell cell,string slot) {
        BY_HANDLE_FILE_INFORMATION identity;FILE_STANDARD_INFO standard;
        using(SafeFileHandle borrowed=Borrow(cell,slot,"Held-handle state")){
            if(!GetFileInformationByHandle(borrowed,out identity))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect held-handle identity.");
            if(!GetFileInformationByHandleEx(borrowed,1,out standard,(uint)Marshal.SizeOf(typeof(FILE_STANDARD_INFO))))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect held-handle standard state.");
        }
        return new string[]{NativeKey(identity),CreationTicks(identity).ToString(System.Globalization.CultureInfo.InvariantCulture),identity.FileAttributes.ToString(System.Globalization.CultureInfo.InvariantCulture),standard.DeletePending!=0?"true":"false",standard.Directory!=0?"true":"false",standard.NumberOfLinks.ToString(System.Globalization.CultureInfo.InvariantCulture)};
    }
    public static string[] MarkHeldHandleDeletePending(CacheCustodyCell cell,string slot,string context,string hostileMode) {
        if(String.Equals(hostileMode,"before",StringComparison.Ordinal))throw new IOException(context+" forced pre-disposition failure.");
        FILE_DISPOSITION_INFO disposition=new FILE_DISPOSITION_INFO{DeleteFile=1};
        using(SafeFileHandle borrowed=Borrow(cell,slot,context)){if(!SetFileInformationByHandle(borrowed,4,ref disposition,(uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO))))throw new Win32Exception(Marshal.GetLastWin32Error(),context+" basic delete disposition failed.");}
        string[] state=GetHeldHandleState(cell,slot);if(state[3]!="true")throw new IOException(context+" did not become delete-pending.");
        if(String.Equals(hostileMode,"after_success",StringComparison.Ordinal))throw new IOException(context+" forced reporting failure after delete disposition success.");
        if(!String.IsNullOrEmpty(hostileMode))throw new ArgumentException(context+" unknown disposition hostile mode.");
        return state;
    }
    public static string[] DeleteManifestChildrenExcept(CacheCustodyCell cell,string rootPath,string expectedRootKey,long expectedRootCreationTicks,string keepRelative,string keepKey,long keepCreationTicks,string[] relativePaths,string[] keys,long[] creationTicks,bool[] directories,long[] lengths,string[] hashes) {
        if(cell==null)throw new ArgumentNullException("cell");
        if(relativePaths==null||keys==null||creationTicks==null||directories==null||lengths==null||hashes==null||relativePaths.Length!=keys.Length||relativePaths.Length!=creationTicks.Length||relativePaths.Length!=directories.Length||relativePaths.Length!=lengths.Length||relativePaths.Length!=hashes.Length)throw new ArgumentException("Sentinel-pinned deletion manifest arrays are malformed.");
        string root=Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);string keep=keepRelative.Replace('/',Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
        string[] rootIdentity=GetIdentity(root,true);if(rootIdentity[0]!=expectedRootKey||Int64.Parse(rootIdentity[1],System.Globalization.CultureInfo.InvariantCulture)!=expectedRootCreationTicks)throw new IOException("Sentinel-pinned deletion root identity changed.");
        Dictionary<string,int> expected=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);int keepIndex=-1;
        for(int i=0;i<relativePaths.Length;i++){string relative=relativePaths[i].Replace('/',Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);string full=Path.GetFullPath(Path.Combine(root,relative));if(String.IsNullOrWhiteSpace(relative)||Path.IsPathRooted(relative)||expected.ContainsKey(relative)||!full.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new ArgumentException("Sentinel-pinned deletion manifest has an invalid path.");if(directories[i]?(lengths[i]!=-1||!String.IsNullOrEmpty(hashes[i])):(lengths[i]<0||hashes[i]==null||hashes[i].Length!=64))throw new ArgumentException("Sentinel-pinned deletion manifest content evidence is malformed.");expected.Add(relative,i);if(String.Equals(relative,keep,StringComparison.OrdinalIgnoreCase))keepIndex=i;}
        if(keepIndex<0||directories[keepIndex]||keys[keepIndex]!=keepKey||creationTicks[keepIndex]!=keepCreationTicks)throw new IOException("Sentinel-pinned deletion manifest omitted or changed the held sentinel.");
        string[] actual=EnumerateTreeNoReparse(root);if(actual.Length!=expected.Count)throw new IOException("Sentinel-pinned deletion tree gained or lost entries before cleanup.");
        foreach(string path in actual){string relative=path.Substring(root.Length).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);int index;if(!expected.TryGetValue(relative,out index))throw new IOException("Sentinel-pinned deletion found an unowned entry: "+relative);string[] current=GetIdentity(path,directories[index]);if(current[0]!=keys[index]||Int64.Parse(current[1],System.Globalization.CultureInfo.InvariantCulture)!=creationTicks[index])throw new IOException("Sentinel-pinned deletion entry identity changed: "+relative);}
        List<int> order=new List<int>();for(int i=0;i<relativePaths.Length;i++)if(i!=keepIndex)order.Add(i);
        order.Sort(delegate(int left,int right){if(directories[left]!=directories[right])return directories[left]?1:-1;int ld=relativePaths[left].Split('/','\\').Length,rd=relativePaths[right].Split('/','\\').Length;return rd.CompareTo(ld);});
        int deleted=0;
        foreach(int index in order){string relative=relativePaths[index].Replace('/',Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);string full=Path.GetFullPath(Path.Combine(root,relative));string slot="delete:"+index.ToString(System.Globalization.CultureInfo.InvariantCulture);cell.Reserve(slot);IntPtr raw=IntPtr.Zero;
            try{const uint READ_DATA=0x1u,READ_ATTRIBUTES=0x80u,WRITE_ATTRIBUTES=0x100u,DELETE=0x00010000u,SYNCHRONIZE=0x00100000u,SHARE_READ=0x1u,OPEN_EXISTING=3u,OPEN_REPARSE=0x00200000u,BACKUP=0x02000000u;uint flags=OPEN_REPARSE|(directories[index]?BACKUP:0u);uint access=READ_ATTRIBUTES|WRITE_ATTRIBUTES|DELETE|SYNCHRONIZE|(directories[index]?0u:READ_DATA);raw=CreateFileWRaw(full,access,SHARE_READ,IntPtr.Zero,OPEN_EXISTING,flags,IntPtr.Zero);if(raw==IntPtr.Zero||raw==new IntPtr(-1)){int error=Marshal.GetLastWin32Error();cell.CancelReservation(slot);throw new Win32Exception(error,"Could not open exact manifest child for deletion: "+relative);}cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;
                BY_HANDLE_FILE_INFORMATION info;using(SafeFileHandle borrowed=Borrow(cell,slot,"Manifest child proof")){if(!GetFileInformationByHandle(borrowed,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not inspect exact manifest child: "+relative);if(((info.FileAttributes&0x10u)!=0u)!=directories[index]||(info.FileAttributes&0x400u)!=0u||NativeKey(info)!=keys[index]||CreationTicks(info)!=creationTicks[index])throw new IOException("Manifest child identity/type changed before deletion: "+relative);if(!directories[index]&&(FileLength(info)!=lengths[index]||HashExactOpenFile(borrowed,lengths[index])!=hashes[index]))throw new IOException("Manifest child content changed before deletion: "+relative);if((info.FileAttributes&0x1u)!=0u){FILE_BASIC_INFO basic=new FILE_BASIC_INFO{FileAttributes=info.FileAttributes&~0x1u};if(!SetBasicFileInformationByHandle(borrowed,0,ref basic,(uint)Marshal.SizeOf(typeof(FILE_BASIC_INFO))))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not clear read-only manifest child: "+relative);}FILE_DISPOSITION_INFO disposition=new FILE_DISPOSITION_INFO{DeleteFile=1};if(!SetFileInformationByHandle(borrowed,4,ref disposition,(uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO))))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not mark exact manifest child delete-pending: "+relative);}
                CloseCheckedNativeHandle(cell,slot,"Manifest child close "+relative,"");if(File.Exists(full)||Directory.Exists(full))throw new IOException("Exact manifest child remained after checked close: "+relative);deleted++;
            }catch(Exception failure){if(raw!=IntPtr.Zero&&raw!=new IntPtr(-1)){cell.AdoptRaw(slot,raw);raw=IntPtr.Zero;}throw new IOException("Sentinel-pinned manifest child deletion failed: "+relative,failure);}
        }
        string[] remaining=EnumerateTreeNoReparse(root);if(remaining.Length!=1)throw new IOException("Sentinel-pinned cleanup did not leave exactly one sentinel entry.");string remainingRelative=remaining[0].Substring(root.Length).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);if(!String.Equals(remainingRelative,keep,StringComparison.OrdinalIgnoreCase))throw new IOException("Sentinel-pinned cleanup retained a non-sentinel entry.");string[] remainingIdentity=GetIdentity(remaining[0],false);if(remainingIdentity[0]!=keepKey||Int64.Parse(remainingIdentity[1],System.Globalization.CultureInfo.InvariantCulture)!=keepCreationTicks)throw new IOException("Sentinel identity changed after ordinary-child cleanup.");
        return new string[]{deleted.ToString(System.Globalization.CultureInfo.InvariantCulture),remainingRelative,DateTime.UtcNow.ToString("o")};
    }
    private static SafeFileHandle OpenForDelete(string path, bool directory, out BY_HANDLE_FILE_INFORMATION info) {
        const uint READ_DATA=0x1,READ_ATTRIBUTES = 0x80, WRITE_ATTRIBUTES = 0x100, DELETE = 0x00010000, SHARE_READ = 1, OPEN_EXISTING = 3;
        const uint OPEN_REPARSE = 0x00200000, BACKUP = 0x02000000;
        uint flags = OPEN_REPARSE | (directory ? BACKUP : 0);
        SafeFileHandle handle = CreateFileW(path, READ_ATTRIBUTES | WRITE_ATTRIBUTES | DELETE | (directory?0u:READ_DATA), SHARE_READ, IntPtr.Zero, OPEN_EXISTING, flags, IntPtr.Zero);
        if (handle.IsInvalid) { handle.Dispose(); throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not exclusively open exact owned deletion entry: " + path); }
        if (!GetFileInformationByHandle(handle, out info)) { int error = Marshal.GetLastWin32Error(); handle.Dispose(); throw new Win32Exception(error, "Could not inspect exact owned deletion entry: " + path); }
        return handle;
    }
    private static void DeleteHandle(OwnedEntry entry) {
        const uint READONLY = 1;
        if ((entry.Attributes & READONLY) != 0) {
            FILE_BASIC_INFO basic = new FILE_BASIC_INFO { FileAttributes = entry.Attributes & ~READONLY };
            if (!SetBasicFileInformationByHandle(entry.Handle, 0, ref basic, (uint)Marshal.SizeOf(typeof(FILE_BASIC_INFO))))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not clear read-only state on exact owned entry: " + entry.FullPath);
        }
        FILE_DISPOSITION_INFO_EX extended = new FILE_DISPOSITION_INFO_EX { Flags = 0x1u | 0x2u | 0x10u };
        if (SetExtendedFileDispositionByHandle(entry.Handle, 21, ref extended, (uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO_EX)))) {
            entry.Dispose();
            if (File.Exists(entry.FullPath) || Directory.Exists(entry.FullPath)) throw new IOException("Extended handle-bound deletion did not remove exact owned entry: " + entry.FullPath);
            return;
        }
        FILE_DISPOSITION_INFO basicDisposition = new FILE_DISPOSITION_INFO { DeleteFile = 1 };
        if (!SetFileInformationByHandle(entry.Handle, 4, ref basicDisposition, (uint)Marshal.SizeOf(typeof(FILE_DISPOSITION_INFO))))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not mark exact owned entry for handle-bound deletion: " + entry.FullPath);
        entry.Dispose();
        if (File.Exists(entry.FullPath) || Directory.Exists(entry.FullPath)) throw new IOException("Handle-bound deletion did not remove exact owned entry: " + entry.FullPath);
    }
    private static string[] EnumerateTreeNoReparse(string rootPath) {
        List<string> paths = new List<string>(); Stack<string> pending = new Stack<string>(); pending.Push(rootPath);
        while (pending.Count > 0) {
            string directory = pending.Pop();
            foreach (string child in Directory.GetFileSystemEntries(directory)) {
                FileAttributes attributes = File.GetAttributes(child);
                if ((attributes & FileAttributes.ReparsePoint) != 0) throw new IOException("Exact owned deletion tree contains a reparse point: " + child);
                paths.Add(child); if ((attributes & FileAttributes.Directory) != 0) pending.Push(child);
            }
        }
        return paths.ToArray();
    }
    public static void DeleteEntryExact(string path, string expectedKey, long expectedCreationTicks, bool expectedDirectory) {
        string full = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        BY_HANDLE_FILE_INFORMATION info; SafeFileHandle handle = OpenForDelete(full, expectedDirectory, out info);
        OwnedEntry entry = new OwnedEntry { RelativePath = Path.GetFileName(full), FullPath = full, IsDirectory = expectedDirectory, Attributes = info.FileAttributes, Handle = handle };
        try {
            bool actualDirectory = (info.FileAttributes & 0x10u) != 0;
            if (actualDirectory != expectedDirectory || (info.FileAttributes & 0x400u) != 0 || NativeKey(info) != expectedKey || CreationTicks(info) != expectedCreationTicks)
                throw new IOException("Exact owned entry identity/type changed before handle-bound deletion: " + full);
            DeleteHandle(entry);
        } finally { entry.Dispose(); }
    }
    private static void RenameEntryExactNoReplaceCore(string path, string destinationPath, string expectedKey, long expectedCreationTicks, bool expectedDirectory) {
        string sourceFull = Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        string destinationFull = Path.GetFullPath(destinationPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (!String.Equals(Path.GetDirectoryName(sourceFull), Path.GetDirectoryName(destinationFull), StringComparison.OrdinalIgnoreCase)) throw new ArgumentException("Exact handle rename must remain in the same parent directory.");
        BY_HANDLE_FILE_INFORMATION info; SafeFileHandle handle = OpenForDelete(sourceFull, expectedDirectory, out info);
        IntPtr buffer = IntPtr.Zero;
        try {
            bool actualDirectory = (info.FileAttributes & 0x10u) != 0;
            if (actualDirectory != expectedDirectory || (info.FileAttributes & 0x400u) != 0 || NativeKey(info) != expectedKey || CreationTicks(info) != expectedCreationTicks) throw new IOException("Exact owned entry identity/type changed before handle-bound rename: " + sourceFull);
            byte[] nameBytes = System.Text.Encoding.Unicode.GetBytes(destinationFull);
            int rootOffset = IntPtr.Size == 8 ? 8 : 4;
            int lengthOffset = IntPtr.Size == 8 ? 16 : 8;
            int nameOffset = IntPtr.Size == 8 ? 20 : 12;
            // Although FileNameLength is authoritative, Windows 10/11 has
            // paths through FileRenameInfo that still read the trailing WCHAR.
            // Supply a zero terminator outside FileNameLength.
            int bufferSize = checked(nameOffset + nameBytes.Length + 2);
            buffer = Marshal.AllocHGlobal(bufferSize);
            for (int i=0;i<bufferSize;i++) Marshal.WriteByte(buffer,i,0);
            Marshal.WriteByte(buffer,0,0); // ReplaceIfExists = FALSE.
            Marshal.WriteIntPtr(buffer,rootOffset,IntPtr.Zero);
            Marshal.WriteInt32(buffer,lengthOffset,nameBytes.Length);
            Marshal.Copy(nameBytes,0,IntPtr.Add(buffer,nameOffset),nameBytes.Length);
            if (!SetFileInformationByHandleRaw(handle,3,buffer,(uint)bufferSize)) throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not quarantine exact owned entry by handle: "+sourceFull);
        } finally {
            if (buffer != IntPtr.Zero) Marshal.FreeHGlobal(buffer);
            handle.Dispose();
        }
        if (File.Exists(sourceFull) || Directory.Exists(sourceFull)) throw new IOException("Handle-bound quarantine rename left the exact owned source path occupied.");
        string[] renamed = GetIdentity(destinationFull, expectedDirectory);
        if (renamed[0] != expectedKey || Int64.Parse(renamed[1],System.Globalization.CultureInfo.InvariantCulture) != expectedCreationTicks) throw new IOException("Handle-bound quarantine destination is not the exact owned entry.");
    }
    private static void RenameEntryExactNoReplacePosixCore(string path, string destinationPath, string expectedKey, long expectedCreationTicks, bool expectedDirectory) {
        string sourceFull=Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
        string destinationFull=Path.GetFullPath(destinationPath).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
        if(!String.Equals(Path.GetDirectoryName(sourceFull),Path.GetDirectoryName(destinationFull),StringComparison.OrdinalIgnoreCase))throw new ArgumentException("Exact POSIX-semantics handle rename must remain in the same parent directory.");
        BY_HANDLE_FILE_INFORMATION info;SafeFileHandle handle=OpenForDelete(sourceFull,expectedDirectory,out info);IntPtr buffer=IntPtr.Zero;
        try {
            bool actualDirectory=(info.FileAttributes&0x10u)!=0u;
            if(actualDirectory!=expectedDirectory||(info.FileAttributes&0x400u)!=0u||NativeKey(info)!=expectedKey||CreationTicks(info)!=expectedCreationTicks)throw new IOException("Exact owned entry identity/type changed before POSIX-semantics handle rename: "+sourceFull);
            byte[] nameBytes=System.Text.Encoding.Unicode.GetBytes(destinationFull);int rootOffset=IntPtr.Size==8?8:4;int lengthOffset=IntPtr.Size==8?16:8;int nameOffset=IntPtr.Size==8?20:12;int bufferSize=checked(nameOffset+nameBytes.Length+2);
            buffer=Marshal.AllocHGlobal(bufferSize);for(int i=0;i<bufferSize;i++)Marshal.WriteByte(buffer,i,0);
            const int FILE_RENAME_FLAG_POSIX_SEMANTICS=0x2;Marshal.WriteInt32(buffer,0,FILE_RENAME_FLAG_POSIX_SEMANTICS);Marshal.WriteIntPtr(buffer,rootOffset,IntPtr.Zero);Marshal.WriteInt32(buffer,lengthOffset,nameBytes.Length);Marshal.Copy(nameBytes,0,IntPtr.Add(buffer,nameOffset),nameBytes.Length);
            if(!SetFileInformationByHandleRaw(handle,22,buffer,(uint)bufferSize))throw new Win32Exception(Marshal.GetLastWin32Error(),"Could not POSIX-rename exact owned entry by handle: "+sourceFull);
        } finally {if(buffer!=IntPtr.Zero)Marshal.FreeHGlobal(buffer);handle.Dispose();}
        if(File.Exists(sourceFull)||Directory.Exists(sourceFull))throw new IOException("POSIX-semantics handle rename left the source path occupied.");
        string[] renamed=GetIdentity(destinationFull,expectedDirectory);if(renamed[0]!=expectedKey||Int64.Parse(renamed[1],System.Globalization.CultureInfo.InvariantCulture)!=expectedCreationTicks)throw new IOException("POSIX-semantics handle rename destination is not the exact owned entry.");
    }
    private static void RequireRoleLeaf(string path, string prefix, string context) {
        string leaf=Path.GetFileName(Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar));
        if(String.IsNullOrWhiteSpace(leaf)||!leaf.StartsWith(prefix,StringComparison.Ordinal))throw new ArgumentException(context+" path does not have its required role prefix: "+leaf);
    }
    private static void RequireExactRoleParent(string path,string destinationPath,string parentPath,string parentKey,long parentCreationTicks,string context) {
        string sourceParent=Path.GetDirectoryName(Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar));
        string destinationParent=Path.GetDirectoryName(Path.GetFullPath(destinationPath).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar));
        string exactParent=Path.GetFullPath(parentPath).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
        if(!String.Equals(sourceParent,exactParent,StringComparison.OrdinalIgnoreCase)||!String.Equals(destinationParent,exactParent,StringComparison.OrdinalIgnoreCase))throw new ArgumentException(context+" escaped its exact admitted parent.");
        string[] identity=GetIdentity(exactParent,true);if(identity[0]!=parentKey||Int64.Parse(identity[1],System.Globalization.CultureInfo.InvariantCulture)!=parentCreationTicks)throw new IOException(context+" parent identity changed.");
    }
    public static void PublishEvidenceStageDirectoryNoReplace(string path,string destinationPath,string expectedKey,long expectedCreationTicks,string parentPath,string parentKey,long parentCreationTicks) {
        RequireRoleLeaf(path,".q009-evidence-stage-","Evidence-stage publication source");
        RequireExactRoleParent(path,destinationPath,parentPath,parentKey,parentCreationTicks,"Evidence-stage publication");
        RenameEntryExactNoReplaceCore(path,destinationPath,expectedKey,expectedCreationTicks,true);
    }
    public static void MovePublishedEvidenceRootAsideForHostileNoReplace(string path,string destinationPath,string expectedKey,long expectedCreationTicks,string parentPath,string parentKey,long parentCreationTicks) {
        string destinationLeaf=Path.GetFileName(Path.GetFullPath(destinationPath).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar));
        if(destinationLeaf.IndexOf(".owned-original-",StringComparison.Ordinal)<0)throw new ArgumentException("Evidence replacement hostile destination lacks its role token.");
        RequireExactRoleParent(path,destinationPath,parentPath,parentKey,parentCreationTicks,"Evidence replacement hostile");
        RenameEntryExactNoReplaceCore(path,destinationPath,expectedKey,expectedCreationTicks,true);
    }
    public static void PublishOwnedEvidenceArtifactNoReplace(string path,string destinationPath,string expectedKey,long expectedCreationTicks,string parentPath,string parentKey,long parentCreationTicks) {
        string sourceLeaf=Path.GetFileName(Path.GetFullPath(path));
        if(sourceLeaf.IndexOf(".tmp-",StringComparison.Ordinal)<0
            &&!sourceLeaf.StartsWith(".summary-stage-",StringComparison.Ordinal)
            &&!sourceLeaf.StartsWith(".terminal-stage-",StringComparison.Ordinal))throw new ArgumentException("Evidence artifact publication source lacks an admitted role token.");
        RequireExactRoleParent(path,destinationPath,parentPath,parentKey,parentCreationTicks,"Evidence artifact publication");
        RenameEntryExactNoReplaceCore(path,destinationPath,expectedKey,expectedCreationTicks,false);
    }
    public static void MoveOwnedCleanupTreeToQuarantineNoReplace(string path,string destinationPath,string expectedKey,long expectedCreationTicks,string parentPath,string parentKey,long parentCreationTicks) {
        RequireRoleLeaf(destinationPath,".q009-delete-","Owned cleanup quarantine destination");
        RequireExactRoleParent(path,destinationPath,parentPath,parentKey,parentCreationTicks,"Owned cleanup quarantine");
        RenameEntryExactNoReplaceCore(path,destinationPath,expectedKey,expectedCreationTicks,true);
    }
    private static void RequireHeldCapabilityRoot(CacheCustodyCell cell,string slot,string expectedKey,long expectedCreationTicks,string context){BY_HANDLE_FILE_INFORMATION info;using(SafeFileHandle borrowed=Borrow(cell,slot,context)){if(!GetFileInformationByHandle(borrowed,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),context+" could not inspect held root");}if(NativeKey(info)!=expectedKey||CreationTicks(info)!=expectedCreationTicks)throw new IOException(context+" held root identity changed");}
    public static void AttemptPinnedCapabilityRootRenameNoReplace(CacheCustodyCell cell,string slot,string path,string destinationPath,string expectedKey,long expectedCreationTicks) {
        RequireRoleLeaf(path,".rw06-q009-sentinel-capability-","Pinned capability source");
        if(!Path.GetFileName(Path.GetFullPath(destinationPath)).EndsWith(".native-move",StringComparison.Ordinal))throw new ArgumentException("Pinned capability destination lacks its role suffix.");
        RequireHeldCapabilityRoot(cell,slot,expectedKey,expectedCreationTicks,"Pinned capability rename");
        RenameEntryExactNoReplaceCore(path,destinationPath,expectedKey,expectedCreationTicks,true);
    }
    public static void AttemptPinnedCapabilityRootPosixRenameNoReplace(CacheCustodyCell cell,string slot,string path,string destinationPath,string expectedKey,long expectedCreationTicks) {
        RequireRoleLeaf(path,".rw06-q009-sentinel-capability-","Pinned POSIX capability source");
        if(!Path.GetFileName(Path.GetFullPath(destinationPath)).EndsWith(".posix-move",StringComparison.Ordinal))throw new ArgumentException("Pinned POSIX capability destination lacks its role suffix.");
        RequireHeldCapabilityRoot(cell,slot,expectedKey,expectedCreationTicks,"Pinned POSIX capability rename");
        RenameEntryExactNoReplacePosixCore(path,destinationPath,expectedKey,expectedCreationTicks,true);
    }
    public static void DeleteTreeExact(string rootPath, string expectedRootKey, long expectedRootCreationTicks, string[] relativePaths, string[] keys, long[] creationTicks, bool[] directories,long[] lengths,string[] hashes) {
        if (relativePaths == null || keys == null || creationTicks == null || directories == null || lengths==null || hashes==null || relativePaths.Length != keys.Length || relativePaths.Length != creationTicks.Length || relativePaths.Length != directories.Length || relativePaths.Length!=lengths.Length || relativePaths.Length!=hashes.Length)
            throw new ArgumentException("Exact owned deletion manifest arrays are malformed.");
        string rootFull = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        Dictionary<string,int> expected = new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
        for (int i=0;i<relativePaths.Length;i++) {
            string relative = relativePaths[i].Replace('/', Path.DirectorySeparatorChar).TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string candidate = Path.GetFullPath(Path.Combine(rootFull, relative));
            if (String.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative) || expected.ContainsKey(relative) || !candidate.StartsWith(rootFull + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || (directories[i]?(lengths[i]!=-1||!String.IsNullOrEmpty(hashes[i])):(lengths[i]<0||hashes[i]==null||hashes[i].Length!=64)))
                throw new ArgumentException("Exact owned deletion manifest has an invalid, duplicate, or escaping path.");
            expected.Add(relative,i);
        }
        List<OwnedEntry> opened = new List<OwnedEntry>(); OwnedEntry root = null;
        try {
            BY_HANDLE_FILE_INFORMATION rootInfo; SafeFileHandle rootHandle = OpenForDelete(rootFull,true,out rootInfo);
            root = new OwnedEntry { RelativePath="", FullPath=rootFull, IsDirectory=true, Attributes=rootInfo.FileAttributes, Handle=rootHandle };
            if ((rootInfo.FileAttributes & 0x400u) != 0 || NativeKey(rootInfo) != expectedRootKey || CreationTicks(rootInfo) != expectedRootCreationTicks)
                throw new IOException("Quarantined deletion root identity changed before handle ownership.");
            string[] actual = EnumerateTreeNoReparse(rootFull);
            if (actual.Length != expected.Count) throw new IOException("Quarantined deletion tree gained or lost entries before handle ownership.");
            Array.Sort(actual,StringComparer.OrdinalIgnoreCase);
            foreach (string path in actual) {
                string relative = path.Substring(rootFull.Length).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);
                int index; if (!expected.TryGetValue(relative,out index)) throw new IOException("Quarantined deletion tree contains an unowned entry: " + relative);
                FileAttributes attributes = File.GetAttributes(path); bool directory = (attributes & FileAttributes.Directory) != 0;
                if ((attributes & FileAttributes.ReparsePoint) != 0 || directory != directories[index]) throw new IOException("Quarantined deletion entry type/reparse state changed: " + relative);
                BY_HANDLE_FILE_INFORMATION info; SafeFileHandle handle = OpenForDelete(path,directory,out info);
                OwnedEntry entry = new OwnedEntry { RelativePath=relative,FullPath=path,IsDirectory=directory,Attributes=info.FileAttributes,Handle=handle }; opened.Add(entry);
                if ((info.FileAttributes & 0x400u) != 0 || NativeKey(info) != keys[index] || CreationTicks(info) != creationTicks[index] || (!directory&&(FileLength(info)!=lengths[index]||HashExactOpenFile(handle,lengths[index])!=hashes[index])))
                    throw new IOException("Quarantined deletion entry was replaced before exact handle ownership: " + relative);
            }
            string[] final = EnumerateTreeNoReparse(rootFull);
            if (final.Length != expected.Count) throw new IOException("Quarantined deletion tree changed after exact handles were acquired.");
            foreach (string path in final) { string relative=path.Substring(rootFull.Length).TrimStart(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar); if(!expected.ContainsKey(relative)) throw new IOException("Quarantined deletion tree gained an unowned entry after exact handles were acquired: "+relative); }
            foreach (OwnedEntry file in opened.FindAll(delegate(OwnedEntry e){return !e.IsDirectory;})) DeleteHandle(file);
            List<OwnedEntry> dirs = opened.FindAll(delegate(OwnedEntry e){return e.IsDirectory;});
            dirs.Sort(delegate(OwnedEntry left,OwnedEntry right){int depth=right.RelativePath.Length.CompareTo(left.RelativePath.Length);return depth!=0?depth:StringComparer.OrdinalIgnoreCase.Compare(right.RelativePath,left.RelativePath);});
            foreach (OwnedEntry directory in dirs) DeleteHandle(directory);
            DeleteHandle(root); root=null;
        } finally { foreach(OwnedEntry entry in opened) entry.Dispose(); if(root!=null) root.Dispose(); }
    }
}
'@
    $script:q009ExactFileSystemTypeInitialized=$true
}

function Get-Q009FileSystemEntryIdentity {
    param([string]$Path)
    $resolved=[IO.Path]::GetFullPath($Path)
    $item=Get-Item -LiteralPath $resolved -Force -ErrorAction Stop
    if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "Exact filesystem identity target is a reparse point: $resolved"}
    $isDirectory=($item.Attributes-band[IO.FileAttributes]::Directory)-ne0
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::GetIdentity($resolved,$isDirectory)
    $nativeAttributes=[uint32]$native[2]
    $nativeDirectory=($nativeAttributes-band[uint32][IO.FileAttributes]::Directory)-ne0
    $nativeReparse=($nativeAttributes-band[uint32][IO.FileAttributes]::ReparsePoint)-ne0
    if($nativeReparse){throw "Exact filesystem identity target became a reparse point: $resolved"}
    if($nativeDirectory-ne$isDirectory){throw "Exact filesystem identity target type changed during capture: $resolved"}
    return [ordered]@{path=$resolved;native_key=[string]$native[0];creation_ticks=[long]$native[1];is_directory=$nativeDirectory;reparse_point=$nativeReparse;attributes=$nativeAttributes;key=('{0}|{1}|{2}'-f$native[0],[long]$native[1],$(if($nativeDirectory){'directory'}else{'file'}))}
}

function New-Q009ExactOwnedDirectory {
    param([string]$Path)
    $candidate=[IO.Path]::GetFullPath($Path);$pathRoot=[IO.Path]::GetPathRoot($candidate);$resolved=if([string]::Equals($candidate,$pathRoot,[StringComparison]::OrdinalIgnoreCase)){$pathRoot}else{$candidate.TrimEnd('\','/')}
    $parent=[IO.Path]::GetDirectoryName($resolved)
    if(-not(Test-Path -LiteralPath $parent -PathType Container)){throw "Exact owned directory parent is missing: $parent"}
    $parentIdentity=Get-Q009FileSystemEntryIdentity $parent
    if(-not[bool]$parentIdentity.is_directory){throw "Exact owned directory parent is not a directory: $parent"}
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::CreateDirectoryNew($parent,[IO.Path]::GetFileName($resolved),[string]$parentIdentity.native_key,[long]$parentIdentity.creation_ticks)
    $nativeAttributes=[uint32]$native[2]
    if(($nativeAttributes-band[uint32][IO.FileAttributes]::ReparsePoint)-ne0-or($nativeAttributes-band[uint32][IO.FileAttributes]::Directory)-eq0){throw "Atomically created owned directory has an invalid native type: $resolved"}
    $identity=[ordered]@{path=$resolved;native_key=[string]$native[0];creation_ticks=[long]$native[1];is_directory=$true;reparse_point=$false;attributes=$nativeAttributes;key=('{0}|{1}|directory'-f$native[0],[long]$native[1])}
    if(-not(Test-Q009FileSystemIdentityMatch $identity)){throw "Atomically created owned directory identity did not survive readback: $resolved"}
    return $identity
}

function New-Q009CacheCustodyCell {
    param([string]$AttemptId)
    if($AttemptId-isnot[string]-or[string]::IsNullOrWhiteSpace($AttemptId)){throw 'Cache custody requires an exact nonempty attempt id'}
    Initialize-Q009ExactFileSystemType
    return [Q009ExactFileSystemNative]::NewCacheCustodyCell($AttemptId)
}

function Get-Q009BytesSha256 {
    param([byte[]]$Bytes)
    if($null-eq$Bytes){throw 'SHA-256 byte payload is null'}
    $algorithm=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-','')}finally{$algorithm.Dispose()}
}

function New-Q009ExactOwnedDirectoryHeld {
    param([string]$Path,[object]$CustodyCell,[string]$Slot='root_creation',[string]$HostileMode='')
    $resolved=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $parent=[IO.Path]::GetDirectoryName($resolved)
    if(-not(Test-Path -LiteralPath $parent -PathType Container)){throw "Exact held directory parent is missing: $parent"}
    $parentIdentity=Get-Q009FileSystemEntryIdentity $parent
    if(-not[bool]$parentIdentity.is_directory){throw "Exact held directory parent is not a directory: $parent"}
    Initialize-Q009ExactFileSystemType
    try{
        $native=[Q009ExactFileSystemNative]::CreateDirectoryNewHeld($CustodyCell,$Slot,$parent,[IO.Path]::GetFileName($resolved),[string]$parentIdentity.native_key,[long]$parentIdentity.creation_ticks,$HostileMode)
        $identity=Get-Q009FileSystemHandleIdentity -CustodyCell $CustodyCell -Slot $Slot -Path $resolved -IsDirectory $true
        if(-not(Test-Q009FileSystemIdentityMatch $identity)){throw "Atomically created held directory identity did not survive exact path readback: $resolved"}
        return [ordered]@{path=$resolved;identity=$identity;handle_slot=$Slot;creation_method='NtCreateFile(FILE_CREATE)';creation_handle_retained=$true;handle_state=[string]$CustodyCell.StateOf($Slot);exclusive_delete_lock=$true;share_delete=$false}
    }catch{
        $failure=$_.Exception;$preservedIdentity=$null
        try{if(Test-Path -LiteralPath $resolved){$preservedIdentity=Get-Q009FileSystemEntryIdentity $resolved}}catch{}
        $message="Atomic held-directory proof failed; the created path was preserved: $resolved"
        $wrapped=[InvalidOperationException]::new($message,$failure)
        $wrapped.Data['preserved_path']=$resolved;$wrapped.Data['preserved_identity']=$preservedIdentity;$wrapped.Data['handle_slot']=$Slot;$wrapped.Data['handle_state']=[string]$CustodyCell.StateOf($Slot)
        throw $wrapped
    }
}

function Assert-Q009PathAbsentStrict {
    param([string]$Path)
    $resolved=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    $parent=[IO.Path]::GetDirectoryName($resolved)
    $leaf=[IO.Path]::GetFileName($resolved)
    if([string]::IsNullOrWhiteSpace($leaf)){throw 'Strict absence path must name one child entry'}
    $parentBefore=Get-Q009FileSystemEntryIdentity $parent
    if(-not[bool]$parentBefore.is_directory){throw "Strict absence parent is not a directory: $parent"}
    $matches=@([IO.Directory]::GetFileSystemEntries($parent)|Where-Object{[string]::Equals([IO.Path]::GetFileName($_),$leaf,[StringComparison]::OrdinalIgnoreCase)})
    $parentAfter=Get-Q009FileSystemEntryIdentity $parent
    if([string]$parentAfter.key-cne[string]$parentBefore.key){throw "Strict absence parent identity changed during enumeration: $parent"}
    if($matches.Count-ne0){throw "Strict absence proof found the path occupied: $resolved"}
    $receipt=[ordered]@{proved=[bool]$true;path=[string]$resolved;parent_identity=$parentBefore;observed_utc=[string][DateTime]::UtcNow.ToString('o')}
    if(-not(Test-Q009StrictAbsenceReceipt $receipt)){throw "Strict absence receipt was malformed: $resolved"}
    return $receipt
}

function Test-Q009StrictAbsenceReceipt {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('proved','path','parent_identity','observed_utc'))){return $false}
    if($Receipt.proved-isnot[bool]-or-not$Receipt.proved-or$Receipt.path-isnot[string]-or[string]::IsNullOrWhiteSpace($Receipt.path)-or-not(Test-Q009FileSystemIdentityShape $Receipt.parent_identity)-or-not[bool]$Receipt.parent_identity.is_directory-or$Receipt.observed_utc-isnot[string]){return $false}
    $parsed=[datetime]::MinValue;return [datetime]::TryParse($Receipt.observed_utc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Get-Q009FileSystemHandleIdentity {
    [CmdletBinding(DefaultParameterSetName='Custody')]
    param(
        [Parameter(Mandatory=$true,ParameterSetName='Custody')][object]$CustodyCell,
        [Parameter(Mandatory=$true,ParameterSetName='Custody')][string]$Slot,
        [Parameter(Mandatory=$true,ParameterSetName='SafeHandle')][Microsoft.Win32.SafeHandles.SafeFileHandle]$Handle,
        [Parameter(Mandatory=$true)][string]$Path,
        [bool]$IsDirectory=$false
    )
    Initialize-Q009ExactFileSystemType
    $native=if($PSCmdlet.ParameterSetName-ceq'SafeHandle'){[Q009ExactFileSystemNative]::GetIdentityFromSafeHandle($Handle)}else{[Q009ExactFileSystemNative]::GetIdentityFromHandle($CustodyCell,$Slot)}
    $resolved=[IO.Path]::GetFullPath($Path)
    $nativeAttributes=[uint32]$native[2]
    $nativeDirectory=($nativeAttributes-band[uint32][IO.FileAttributes]::Directory)-ne0
    $nativeReparse=($nativeAttributes-band[uint32][IO.FileAttributes]::ReparsePoint)-ne0
    if($nativeReparse){throw "Exact handle identity target is a reparse point: $resolved"}
    if($nativeDirectory-ne$IsDirectory){throw "Exact handle identity target type differs from the caller contract: $resolved"}
    return [ordered]@{path=$resolved;native_key=[string]$native[0];creation_ticks=[long]$native[1];is_directory=$nativeDirectory;reparse_point=$nativeReparse;attributes=$nativeAttributes;key=('{0}|{1}|{2}'-f$native[0],[long]$native[1],$(if($nativeDirectory){'directory'}else{'file'}))}
}

function New-Q009ExactOwnedFileHeld {
    param([string]$Path,[byte[]]$Payload,[object]$CustodyCell,[string]$ParentSlot='root_creation',[string]$Slot='sentinel',[object]$ExpectedParentIdentity,[string]$HostileMode='')
    $resolved=[IO.Path]::GetFullPath($Path);$parent=[IO.Path]::GetDirectoryName($resolved)
    if($null-eq$ExpectedParentIdentity-or-not(Test-Q009FileSystemIdentityShape $ExpectedParentIdentity)-or-not[bool]$ExpectedParentIdentity.is_directory-or[string]$ExpectedParentIdentity.path-cne$parent){throw 'Held file requires the exact parent-directory identity receipt'}
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::CreateFileNewHeld($CustodyCell,$ParentSlot,$Slot,[IO.Path]::GetFileName($resolved),[string]$ExpectedParentIdentity.native_key,[long]$ExpectedParentIdentity.creation_ticks,$Payload,$true,$HostileMode)
    $identity=Get-Q009FileSystemHandleIdentity -CustodyCell $CustodyCell -Slot $Slot -Path $resolved -IsDirectory $false
    if(-not(Test-Q009FileSystemIdentityMatch $identity)){throw 'Held file path no longer names its atomically created identity'}
    return [ordered]@{path=$resolved;identity=$identity;handle_slot=$Slot;creation_method='NtCreateFile(FILE_CREATE relative)';payload_sha256=Get-Q009BytesSha256 $Payload;payload_length=$Payload.Length;handle_state=[string]$CustodyCell.StateOf($Slot);share_write=$false;share_delete=$false}
}

function Close-Q009CheckedNativeHandle {
    param([object]$CustodyCell,[string]$Slot,[string]$Context,[ValidateSet('','before','after_success')][string]$HostileMode='')
    Initialize-Q009ExactFileSystemType
    try{$native=[Q009ExactFileSystemNative]::CloseCheckedNativeHandle($CustodyCell,$Slot,$Context,$HostileMode)}catch{throw "$Context checked native handle close failed; terminal state=$([string]$CustodyCell.StateOf($Slot)): $($_.Exception.Message)"}
    if([string]$CustodyCell.StateOf($Slot)-cne'CLOSED_NATIVE_SUCCESS'){throw "$Context native close did not reach CLOSED_NATIVE_SUCCESS"}
    return [ordered]@{released=[bool]$true;slot=[string]$Slot;state=[string]'CLOSED_NATIVE_SUCCESS';context=[string]$Context;released_utc=[string]$native[2]}
}

function Test-Q009CheckedCloseReceipt {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('released','slot','state','context','released_utc'))){return $false}
    if($Receipt.released-isnot[bool]-or-not$Receipt.released-or$Receipt.slot-isnot[string]-or[string]::IsNullOrWhiteSpace($Receipt.slot)-or$Receipt.state-isnot[string]-or[string]$Receipt.state-cne'CLOSED_NATIVE_SUCCESS'-or$Receipt.context-isnot[string]-or[string]::IsNullOrWhiteSpace($Receipt.context)-or$Receipt.released_utc-isnot[string]){return $false}
    $parsed=[datetime]::MinValue;return [datetime]::TryParse($Receipt.released_utc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Close-Q009AllOpenNativeHandles {
    param([object]$CustodyCell,[string]$Context)
    $receipts=[Collections.Generic.List[object]]::new();$errors=[Collections.Generic.List[string]]::new()
    foreach($slot in @($CustodyCell.ClosableSlots())){try{[void]$receipts.Add((Close-Q009CheckedNativeHandle $CustodyCell $slot ($Context+' '+$slot)))}catch{[void]$errors.Add($_.Exception.Message)}}
    return [ordered]@{receipts=@($receipts);errors=@($errors);nonterminal_slots=@($CustodyCell.NonTerminalSlots());state_receipts=@($CustodyCell.StateReceipts());all_terminal=@($CustodyCell.NonTerminalSlots()).Count-eq0}
}

function Open-Q009ExactDirectoryHeld {
    param([string]$Path,[object]$ExpectedIdentity,[object]$CustodyCell,[string]$Slot='final_root',[string]$HostileMode='')
    $candidate=[IO.Path]::GetFullPath($Path);$pathRoot=[IO.Path]::GetPathRoot($candidate);$resolved=if([string]::Equals($candidate,$pathRoot,[StringComparison]::OrdinalIgnoreCase)){$pathRoot}else{$candidate.TrimEnd('\','/')}
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedIdentity)-or-not[bool]$ExpectedIdentity.is_directory-or[string]$ExpectedIdentity.path-cne$resolved){throw 'Final held directory requires an exact matching identity receipt'}
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::OpenDirectoryHeldExact($CustodyCell,$Slot,$resolved,[string]$ExpectedIdentity.native_key,[long]$ExpectedIdentity.creation_ticks,$HostileMode)
    $identity=Get-Q009FileSystemHandleIdentity -CustodyCell $CustodyCell -Slot $Slot -Path $resolved -IsDirectory $true
    if([string]$identity.key-cne[string]$ExpectedIdentity.key){throw 'Final held directory identity differs from the expected cache root'}
    return [ordered]@{path=$resolved;identity=$identity;handle_slot=$Slot;handle_state=[string]$CustodyCell.StateOf($Slot);share_delete=$false;delete_access=$true}
}

function Open-Q009ExactReadDirectoryHeld {
    param([string]$Path,[object]$ExpectedIdentity,[object]$CustodyCell,[string]$Slot,[ValidateSet('','after_acquire','after_proof')][string]$HostileMode='')
    $candidate=[IO.Path]::GetFullPath($Path);$pathRoot=[IO.Path]::GetPathRoot($candidate);$resolved=if([string]::Equals($candidate,$pathRoot,[StringComparison]::OrdinalIgnoreCase)){$pathRoot}else{$candidate.TrimEnd('\','/')}
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedIdentity)-or-not[bool]$ExpectedIdentity.is_directory-or[string]$ExpectedIdentity.path-cne$resolved){throw 'Read-only held directory requires an exact matching identity receipt'}
    Initialize-Q009ExactFileSystemType
    [void][Q009ExactFileSystemNative]::OpenDirectoryReadHeldExact($CustodyCell,$Slot,$resolved,[string]$ExpectedIdentity.native_key,[long]$ExpectedIdentity.creation_ticks,$HostileMode)
    $identity=Get-Q009FileSystemHandleIdentity -CustodyCell $CustodyCell -Slot $Slot -Path $resolved -IsDirectory $true
    if([string]$identity.key-cne[string]$ExpectedIdentity.key){throw 'Read-only held directory identity differs from its expected authority'}
    return [ordered]@{path=$resolved;identity=$identity;handle_slot=$Slot;handle_state=[string]$CustodyCell.StateOf($Slot);share_delete=$false;delete_access=$false;read_list_only=$true}
}

function Open-Q009ExactFileHeld {
    param([string]$Path,[object]$ExpectedIdentity,[object]$CustodyCell,[string]$Slot,[ValidateSet('','after_acquire','after_proof')][string]$HostileMode='')
    $resolved=[IO.Path]::GetFullPath($Path)
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedIdentity)-or[bool]$ExpectedIdentity.is_directory-or[string]$ExpectedIdentity.path-cne$resolved){throw 'Exact held-file open requires the exact ordinary file identity'}
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::OpenFileHeldExact($CustodyCell,$Slot,$resolved,[string]$ExpectedIdentity.native_key,[long]$ExpectedIdentity.creation_ticks,$HostileMode)
    $identity=Get-Q009FileSystemHandleIdentity -CustodyCell $CustodyCell -Slot $Slot -Path $resolved -IsDirectory $false
    if([string]$identity.key-cne[string]$ExpectedIdentity.key){throw 'Exact held-file identity changed during acquisition'}
    return [ordered]@{path=$resolved;identity=$identity;handle_slot=[string]$Slot;handle_state=[string]$CustodyCell.StateOf($Slot);share_write=$false;share_delete=$false}
}

function Test-Q009HeldExclusiveLeaseReceiptShape {
    param([AllowNull()][object]$Receipt,[AllowNull()][object]$RunContext=$null)
    $keys=@('schema_version','path','parent_identity','file_identity','payload_sha256','payload_length','owner_identity','attempt_id','candidate_commit','candidate_tree','context_sha256','file_slot','parent_slot','handle_state','share_none','receipt_sha256')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or$Receipt.schema_version-isnot[int]-or[int]$Receipt.schema_version-ne1-or
        $Receipt.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.path)-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.parent_identity)-or-not[bool]$Receipt.parent_identity.is_directory-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.file_identity)-or[bool]$Receipt.file_identity.is_directory-or
        $Receipt.payload_sha256-isnot[string]-or[string]$Receipt.payload_sha256-cnotmatch'^[0-9A-F]{64}$'-or$Receipt.payload_length-isnot[int]-or[int]$Receipt.payload_length-le0-or
        -not(Test-ProcessIdentityProofShape $Receipt.owner_identity)-or$Receipt.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.attempt_id)-or
        $Receipt.candidate_commit-isnot[string]-or[string]$Receipt.candidate_commit-cnotmatch'^[0-9a-f]{40}$'-or$Receipt.candidate_tree-isnot[string]-or[string]$Receipt.candidate_tree-cnotmatch'^[0-9a-f]{40}$'-or
        $Receipt.context_sha256-isnot[string]-or[string]$Receipt.context_sha256-cnotmatch'^[0-9A-F]{64}$'-or$Receipt.file_slot-isnot[string]-or[string]$Receipt.file_slot-cne'exclusive_lease'-or
        $Receipt.parent_slot-isnot[string]-or[string]$Receipt.parent_slot-cne'lease_parent'-or$Receipt.handle_state-isnot[string]-or[string]$Receipt.handle_state-cne'OPEN'-or
        $Receipt.share_none-isnot[bool]-or-not[bool]$Receipt.share_none-or$Receipt.receipt_sha256-isnot[string]-or[string]$Receipt.receipt_sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    if([string]$Receipt.path-cne[string]$Receipt.file_identity.path-or[IO.Path]::GetDirectoryName([string]$Receipt.path)-cne[string]$Receipt.parent_identity.path){return $false}
    if($null-ne$RunContext){if(-not(Test-Q009RunContextShape $RunContext)-or[string]$Receipt.context_sha256-cne[string]$RunContext.context_sha256-or[string]$Receipt.attempt_id-cne[string]$RunContext.attempt_id-or[string]$Receipt.candidate_commit-cne[string]$RunContext.candidate_commit-or[string]$Receipt.candidate_tree-cne[string]$RunContext.candidate_tree-or[string]$Receipt.owner_identity.key-cne[string]$RunContext.launcher_identity.key){return $false}}
    $payload=[ordered]@{};foreach($key in $keys|Where-Object{$_-cne'receipt_sha256'}){$payload[$key]=$Receipt.$key}
    return [string]$Receipt.receipt_sha256 -ceq (Get-StringSha256 ($payload | ConvertTo-Json -Depth 12 -Compress))
}

function New-Q009HeldExclusiveLease {
    param(
        [string]$Path,
        [string]$Text,
        [object]$RunContext,
        [switch]$ForcePostCreateFailureForTest,
        [switch]$ForceReplacementAttemptBeforeRollbackForTest
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Held EXCLUSIVE creation requires one exact sealed Q-009 run context'}
    $resolved=[IO.Path]::GetFullPath($Path)
    if([IO.Path]::GetDirectoryName($resolved)-cne[string]$RunContext.canonical_lease_root-or[IO.Path]::GetFileName($resolved)-cne'EXCLUSIVE.lease'){throw 'Held EXCLUSIVE path is not the canonical lease object'}
    $cell=New-Q009CacheCustodyCell ([string]$RunContext.attempt_id+'-exclusive-lease')
    $parentIdentity=$RunContext.canonical_lease_root_identity
    try{
        [void](Open-Q009ExactDirectoryHeld -Path $RunContext.canonical_lease_root -ExpectedIdentity $parentIdentity -CustodyCell $cell -Slot lease_parent)
        $bytes=[Text.Encoding]::UTF8.GetBytes($Text);Initialize-Q009ExactFileSystemType
        $native=[Q009ExactFileSystemNative]::CreateFileNewHeld($cell,'lease_parent','exclusive_lease','EXCLUSIVE.lease',[string]$parentIdentity.native_key,[long]$parentIdentity.creation_ticks,$bytes,$false,'')
        $fileIdentity=Get-Q009FileSystemHandleIdentity -CustodyCell $cell -Slot exclusive_lease -Path $resolved -IsDirectory $false
        $description=Get-Q009HeldFileDescription $cell exclusive_lease $resolved
        $receipt=[ordered]@{schema_version=[int]1;path=[string]$resolved;parent_identity=$parentIdentity;file_identity=$fileIdentity;payload_sha256=[string]$description.sha256;payload_length=[int]$bytes.Length;owner_identity=$RunContext.launcher_identity;attempt_id=[string]$RunContext.attempt_id;candidate_commit=[string]$RunContext.candidate_commit;candidate_tree=[string]$RunContext.candidate_tree;context_sha256=[string]$RunContext.context_sha256;file_slot='exclusive_lease';parent_slot='lease_parent';handle_state=[string]$cell.StateOf('exclusive_lease');share_none=[bool]$true}
        $receipt.receipt_sha256=Get-StringSha256 (($receipt|ConvertTo-Json -Depth 12 -Compress))
        if(-not(Test-Q009HeldExclusiveLeaseReceiptShape $receipt $RunContext)){throw 'Held EXCLUSIVE creation receipt failed its exact schema'}
        if($ForcePostCreateFailureForTest){throw 'Forced held EXCLUSIVE post-create failure for hostile validation'}
        return [ordered]@{receipt=$receipt;custody_cell=$cell;released=$false;release_receipts=@()}
    }catch{
        $creationFailure=$_.Exception;$cleanupFailure=''
        try{
            if([string]$cell.StateOf('exclusive_lease')-in@('OPEN','CLOSE_FAILED_HANDLE_RETAINED')){
                if($ForceReplacementAttemptBeforeRollbackForTest){
                    $replacementDenied=$true;$replacementProbe=$resolved+'.replacement-'+[guid]::NewGuid().ToString('N')
                    try{[IO.File]::Move($resolved,$replacementProbe);$replacementDenied=$false}catch{}
                    try{[IO.File]::WriteAllText($resolved,'foreign replacement');$replacementDenied=$false}catch{}
                    if(-not$replacementDenied){throw 'Held EXCLUSIVE no-share native handle allowed a path replacement before rollback'}
                }
                $disposition=Set-Q009HeldHandleDeletePending $cell exclusive_lease 'Held EXCLUSIVE creation rollback'
                if(-not(Test-Q009HeldHandleStateShape $disposition $null $false)-or-not[bool]$disposition.delete_pending){throw 'Held EXCLUSIVE creation rollback did not become delete-pending'}
                $fileClose=Close-Q009CheckedNativeHandle $cell exclusive_lease 'Held EXCLUSIVE creation rollback close'
                if(-not(Test-Q009CheckedCloseReceipt $fileClose)){throw 'Held EXCLUSIVE creation rollback file close was malformed'}
                $absence=Assert-Q009PathAbsentStrict $resolved
                if(-not(Test-Q009StrictAbsenceReceipt $absence)){throw 'Held EXCLUSIVE creation rollback absence receipt was malformed'}
            }
            $allClosed=Close-Q009AllOpenNativeHandles $cell 'Held EXCLUSIVE creation failure terminal release'
            if(-not[bool]$allClosed.all_terminal-or@($allClosed.errors).Count-ne0){throw ('Held EXCLUSIVE creation rollback retained native custody: '+(@($allClosed.errors)-join'; '))}
        }catch{$cleanupFailure=$_.Exception.Message}
        if($cleanupFailure){$wrapped=[InvalidOperationException]::new(('Held EXCLUSIVE creation failed and exact handle-bound rollback did not complete: '+$cleanupFailure),$creationFailure);$wrapped.Data['held_exclusive_custody_cell']=$cell;$wrapped.Data['held_exclusive_path']=$resolved;throw $wrapped}
        throw $creationFailure
    }
}

function Assert-Q009HeldExclusiveLease {
    param([object]$Lease,[object]$RunContext)
    if($null-eq$Lease-or-not(Test-Q009HeldExclusiveLeaseReceiptShape $Lease.receipt $RunContext)-or$Lease.released-isnot[bool]-or[bool]$Lease.released){throw 'Held EXCLUSIVE custody is malformed or already released'}
    $fileState=Get-Q009HeldHandleState $Lease.custody_cell exclusive_lease
    if(-not(Test-Q009HeldHandleStateShape $fileState $Lease.receipt.file_identity $false)-or[bool]$fileState.delete_pending){throw 'Held EXCLUSIVE file handle identity/state changed'}
    $parentState=Get-Q009HeldHandleState $Lease.custody_cell lease_parent
    if(-not(Test-Q009HeldHandleStateShape $parentState $Lease.receipt.parent_identity $true)-or[bool]$parentState.delete_pending){throw 'Held EXCLUSIVE parent handle identity/state changed'}
    $description=Get-Q009HeldFileDescription $Lease.custody_cell exclusive_lease $Lease.receipt.path
    if([long]$description.length-ne[int]$Lease.receipt.payload_length-or[string]$description.sha256-cne[string]$Lease.receipt.payload_sha256){throw 'Held EXCLUSIVE bytes changed'}
    return $Lease.receipt
}

function Close-Q009HeldExclusiveLease {
    param([object]$Lease,[object]$RunContext,[switch]$ForceReplacementAfterFileCloseForTest)
    [void](Assert-Q009HeldExclusiveLease $Lease $RunContext)
    $disposition=Set-Q009HeldHandleDeletePending $Lease.custody_cell exclusive_lease 'Held EXCLUSIVE terminal delete'
    if(-not(Test-Q009HeldHandleStateShape $disposition $Lease.receipt.file_identity $false)-or-not[bool]$disposition.delete_pending){throw 'Held EXCLUSIVE did not enter exact delete-pending state'}
    $fileClose=Close-Q009CheckedNativeHandle $Lease.custody_cell exclusive_lease 'Held EXCLUSIVE terminal close'
    if(-not(Test-Q009CheckedCloseReceipt $fileClose)){throw 'Held EXCLUSIVE file close receipt was malformed'}
    if($ForceReplacementAfterFileCloseForTest){[IO.File]::WriteAllText([string]$Lease.receipt.path,'foreign replacement after exact lease close',[Text.UTF8Encoding]::new($false))}
    $absence=Assert-Q009PathAbsentStrict $Lease.receipt.path
    if(-not(Test-Q009StrictAbsenceReceipt $absence)){throw 'Held EXCLUSIVE absence receipt was malformed'}
    $parentClose=Close-Q009CheckedNativeHandle $Lease.custody_cell lease_parent 'Held EXCLUSIVE parent close'
    if(-not(Test-Q009CheckedCloseReceipt $parentClose)-or@($Lease.custody_cell.NonTerminalSlots()).Count-ne0){throw 'Held EXCLUSIVE parent custody did not close exactly'}
    $Lease.released=$true;$Lease.release_receipts=@($fileClose,$parentClose)
    $release=[ordered]@{released=[bool]$true;file_close=$fileClose;parent_close=$parentClose;absence=$absence;receipt_sha256=[string]$Lease.receipt.receipt_sha256;context_sha256=[string]$RunContext.context_sha256;attempt_id=[string]$RunContext.attempt_id}
    if(-not(Test-Q009HeldExclusiveReleaseReceiptShape $release $Lease.receipt $RunContext)){throw 'Held EXCLUSIVE release receipt failed its exact schema'}
    return $release
}

function Test-Q009HeldExclusiveReleaseReceiptShape {
    param([AllowNull()][object]$Receipt,[AllowNull()][object]$LeaseReceipt,[AllowNull()][object]$RunContext)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('released','file_close','parent_close','absence','receipt_sha256','context_sha256','attempt_id'))-or
        $Receipt.released-isnot[bool]-or-not[bool]$Receipt.released-or
        -not(Test-Q009CheckedCloseReceipt $Receipt.file_close)-or-not(Test-Q009CheckedCloseReceipt $Receipt.parent_close)-or
        -not(Test-Q009StrictAbsenceReceipt $Receipt.absence)-or
        $Receipt.receipt_sha256-isnot[string]-or[string]$Receipt.receipt_sha256-cnotmatch'^[0-9A-F]{64}$'-or
        $Receipt.context_sha256-isnot[string]-or[string]$Receipt.context_sha256-cnotmatch'^[0-9A-F]{64}$'-or
        $Receipt.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.attempt_id)-or
        -not(Test-Q009HeldExclusiveLeaseReceiptShape $LeaseReceipt $RunContext)){return $false}
    return [string]$Receipt.receipt_sha256-ceq[string]$LeaseReceipt.receipt_sha256-and
        [string]$Receipt.context_sha256-ceq[string]$RunContext.context_sha256-and
        [string]$Receipt.attempt_id-ceq[string]$RunContext.attempt_id-and
        [string]$Receipt.absence.path-ceq[string]$LeaseReceipt.path
}

function Get-Q009HeldFinalPath {
    param([object]$CustodyCell,[string]$Slot)
    Initialize-Q009ExactFileSystemType
    return [IO.Path]::GetFullPath([Q009ExactFileSystemNative]::GetFinalPathFromHeldHandle($CustodyCell,$Slot))
}

function Get-Q009SafeHandleFinalPath {
    param([Microsoft.Win32.SafeHandles.SafeFileHandle]$Handle)
    Initialize-Q009ExactFileSystemType
    return [IO.Path]::GetFullPath([Q009ExactFileSystemNative]::GetFinalPathFromSafeHandle($Handle))
}

function Get-Q009HeldFileDescription {
    param([object]$CustodyCell,[string]$Slot,[string]$Path)
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::DescribeHeldFile($CustodyCell,$Slot)
    if($native.Count-ne5){throw 'Exact held-file description was malformed'}
    return [ordered]@{path=[IO.Path]::GetFullPath($Path);native_key=[string]$native[0];creation_ticks=[long]$native[1];attributes=[uint32]$native[2];length=[long]$native[3];sha256=[string]$native[4]}
}

function Test-Q009ExecutablePinReceiptShape {
    param([AllowNull()][object]$Receipt,[string]$ExpectedAttemptId='')
    $keys=@('schema_version','attempt_id','path','final_path','leaf_identity','length','sha256','ancestor_identities','ancestor_final_paths','held','receipt_sha256')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or$Receipt.schema_version-isnot[int]-or[int]$Receipt.schema_version-ne1-or
        $Receipt.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.attempt_id)-or
        $Receipt.path-isnot[string]-or$Receipt.final_path-isnot[string]-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.leaf_identity)-or[bool]$Receipt.leaf_identity.is_directory-or
        $Receipt.length-isnot[long]-or[long]$Receipt.length-lt0-or$Receipt.sha256-isnot[string]-or[string]$Receipt.sha256-cnotmatch'^[0-9A-F]{64}$'-or
        $Receipt.ancestor_identities-isnot[System.Array]-or$Receipt.ancestor_final_paths-isnot[System.Array]-or
        $Receipt.held-isnot[bool]-or-not[bool]$Receipt.held-or$Receipt.receipt_sha256-isnot[string]-or[string]$Receipt.receipt_sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    if($ExpectedAttemptId-and[string]$Receipt.attempt_id-cne$ExpectedAttemptId){return $false}
    if(@($Receipt.ancestor_identities).Count-lt1-or@($Receipt.ancestor_identities).Count-ne@($Receipt.ancestor_final_paths).Count){return $false}
    foreach($identity in @($Receipt.ancestor_identities)){if(-not(Test-Q009FileSystemIdentityShape $identity)-or-not[bool]$identity.is_directory){return $false}}
    foreach($path in @($Receipt.ancestor_final_paths)){if($path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$path)){return $false}}
    if([IO.Path]::GetFullPath([string]$Receipt.path)-cne[string]$Receipt.path-or[IO.Path]::GetFullPath([string]$Receipt.final_path)-cne[string]$Receipt.final_path-or[string]$Receipt.path-cne[string]$Receipt.final_path-or[string]$Receipt.leaf_identity.path-cne[string]$Receipt.path){return $false}
    $payload=[ordered]@{};foreach($key in $keys|Where-Object{$_-cne'receipt_sha256'}){$payload[$key]=$Receipt.$key}
    return [string]$Receipt.receipt_sha256 -ceq (Get-StringSha256 ($payload | ConvertTo-Json -Depth 12 -Compress))
}

function New-Q009ExecutablePin {
    param([string]$Path,[string]$AttemptId,[AllowNull()][object]$ExpectedExecutableIdentity=$null)
    $resolved=[IO.Path]::GetFullPath($Path)
    if([string]::IsNullOrWhiteSpace($AttemptId)){throw 'Executable pin requires an exact nonempty attempt id'}
    $leafIdentity=Get-Q009FileSystemEntryIdentity $resolved
    if([bool]$leafIdentity.is_directory){throw 'Executable pin target is not an ordinary file'}
    $cell=New-Q009CacheCustodyCell ($AttemptId+'-executable-'+[guid]::NewGuid().ToString('N'))
    $ancestorIdentities=[Collections.Generic.List[object]]::new();$ancestorFinalPaths=[Collections.Generic.List[string]]::new();$slots=[Collections.Generic.List[string]]::new()
    try{
        $parent=[IO.Path]::GetDirectoryName($resolved);$root=[IO.Path]::GetPathRoot($parent);$directories=[Collections.Generic.List[string]]::new();[void]$directories.Add($root)
        $relative=$parent.Substring($root.Length).TrimStart('\','/')
        $cursor=$root
        if(-not[string]::IsNullOrWhiteSpace($relative)){foreach($part in $relative.Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries)){$cursor=Join-Path $cursor $part;[void]$directories.Add([IO.Path]::GetFullPath($cursor))}}
        for($index=0;$index-lt$directories.Count;$index+=1){
            $directory=[string]$directories[$index];$identity=Get-Q009FileSystemEntryIdentity $directory;$slot=('ancestor_{0:D3}'-f$index)
            $ancestorHold=Open-Q009ExactReadDirectoryHeld -Path $directory -ExpectedIdentity $identity -CustodyCell $cell -Slot $slot
            if($ancestorHold.delete_access-isnot[bool]-or[bool]$ancestorHold.delete_access-or$ancestorHold.read_list_only-isnot[bool]-or-not[bool]$ancestorHold.read_list_only-or$ancestorHold.share_delete-isnot[bool]-or[bool]$ancestorHold.share_delete){throw 'Executable ancestor authority requested mutation access or delete sharing'}
            $final=Get-Q009HeldFinalPath $cell $slot
            if(-not[string]::Equals([IO.Path]::GetFullPath($directory),$final,[StringComparison]::OrdinalIgnoreCase)){throw "Executable ancestor final path drifted: $directory -> $final"}
            [void]$ancestorIdentities.Add($identity);[void]$ancestorFinalPaths.Add($final);[void]$slots.Add($slot)
        }
        $leafSlot='executable_leaf';[void](Open-Q009ExactFileHeld -Path $resolved -ExpectedIdentity $leafIdentity -CustodyCell $cell -Slot $leafSlot);[void]$slots.Add($leafSlot)
        $finalLeaf=Get-Q009HeldFinalPath $cell $leafSlot
        if(-not[string]::Equals($resolved,$finalLeaf,[StringComparison]::OrdinalIgnoreCase)){throw "Executable leaf final path drifted: $resolved -> $finalLeaf"}
        $description=Get-Q009HeldFileDescription $cell $leafSlot $resolved
        if([string]$description.native_key-cne[string]$leafIdentity.native_key-or[long]$description.creation_ticks-ne[long]$leafIdentity.creation_ticks){throw 'Executable leaf identity changed during handle-bound hashing'}
        if($null-ne$ExpectedExecutableIdentity){
            if([IO.Path]::GetFullPath([string]$ExpectedExecutableIdentity.path)-cne$resolved-or$ExpectedExecutableIdentity.length-isnot[long]-or[long]$ExpectedExecutableIdentity.length-ne[long]$description.length-or$ExpectedExecutableIdentity.sha256-isnot[string]-or[string]$ExpectedExecutableIdentity.sha256-cne[string]$description.sha256-or-not(Test-Q009FileSystemIdentityShape $ExpectedExecutableIdentity.filesystem_identity)-or[string]$ExpectedExecutableIdentity.filesystem_identity.key-cne[string]$leafIdentity.key){throw 'Executable identity/hash changed before the full-chain held launch boundary'}
        }
        $receipt=[ordered]@{schema_version=[int]1;attempt_id=[string]$AttemptId;path=[string]$resolved;final_path=[string]$finalLeaf;leaf_identity=$leafIdentity;length=[long]$description.length;sha256=[string]$description.sha256;ancestor_identities=@($ancestorIdentities);ancestor_final_paths=@($ancestorFinalPaths);held=[bool]$true}
        $receipt.receipt_sha256=Get-StringSha256 (($receipt|ConvertTo-Json -Depth 12 -Compress))
        if(-not(Test-Q009ExecutablePinReceiptShape $receipt $AttemptId)){throw 'Executable pin receipt failed its exact closed schema'}
        return [ordered]@{receipt=$receipt;custody_cell=$cell;slots=@($slots);released=$false;release_receipts=@()}
    }catch{
        try{[void](Close-Q009AllOpenNativeHandles $cell 'Executable pin setup failure')}catch{}
        throw
    }
}

function Assert-Q009ExecutablePinStable {
    param([object]$Pin,[string]$ExpectedAttemptId)
    if($null-eq$Pin-or-not(Test-Q009ExecutablePinReceiptShape $Pin.receipt $ExpectedAttemptId)-or$Pin.released-isnot[bool]-or[bool]$Pin.released){throw 'Executable pin is malformed or already released'}
    for($index=0;$index-lt@($Pin.receipt.ancestor_identities).Count;$index+=1){
        $slot=('ancestor_{0:D3}'-f$index);$final=Get-Q009HeldFinalPath $Pin.custody_cell $slot
        if(-not[string]::Equals([string]$Pin.receipt.ancestor_final_paths[$index],$final,[StringComparison]::OrdinalIgnoreCase)){throw 'Executable ancestor final path changed while held'}
        $state=Get-Q009HeldHandleState $Pin.custody_cell $slot
        if(-not(Test-Q009HeldHandleStateShape $state $Pin.receipt.ancestor_identities[$index] $true)-or[bool]$state.delete_pending){throw 'Executable ancestor handle state/identity changed while held'}
    }
    $leafState=Get-Q009HeldHandleState $Pin.custody_cell executable_leaf
    if(-not(Test-Q009HeldHandleStateShape $leafState $Pin.receipt.leaf_identity $false)-or[bool]$leafState.delete_pending){throw 'Executable leaf handle state/identity changed while held'}
    $description=Get-Q009HeldFileDescription $Pin.custody_cell executable_leaf $Pin.receipt.path
    if([long]$description.length-ne[long]$Pin.receipt.length-or[string]$description.sha256-cne[string]$Pin.receipt.sha256){throw 'Executable bytes changed while the exact leaf handle was held'}
    return $Pin.receipt
}

function Close-Q009ExecutablePin {
    param([object]$Pin,[string]$ExpectedAttemptId)
    [void](Assert-Q009ExecutablePinStable $Pin $ExpectedAttemptId)
    $release=Close-Q009AllOpenNativeHandles $Pin.custody_cell 'Executable pin terminal release'
    if(-not[bool]$release.all_terminal-or@($release.errors).Count-ne0-or@($release.nonterminal_slots).Count-ne0){throw 'Executable pin did not close every exact chain/leaf handle'}
    $Pin.released=$true;$Pin.release_receipts=@($release.receipts)
    return [ordered]@{released=[bool]$true;receipt_sha256=[string]$Pin.receipt.receipt_sha256;closed_handle_count=[int]@($release.receipts).Count;all_terminal=[bool]$true}
}

function Get-Q009HeldHandleState {
    param([object]$CustodyCell,[string]$Slot)
    Initialize-Q009ExactFileSystemType;$native=[Q009ExactFileSystemNative]::GetHeldHandleState($CustodyCell,$Slot)
    return [ordered]@{native_key=[string]$native[0];creation_ticks=[long]$native[1];attributes=[uint32]$native[2];delete_pending=([string]$native[3]-ceq'true');is_directory=([string]$native[4]-ceq'true');link_count=[uint32]$native[5];handle_state=[string]$CustodyCell.StateOf($Slot)}
}

function Set-Q009HeldHandleDeletePending {
    param([object]$CustodyCell,[string]$Slot,[string]$Context,[ValidateSet('','before','after_success')][string]$HostileMode='')
    Initialize-Q009ExactFileSystemType;$native=[Q009ExactFileSystemNative]::MarkHeldHandleDeletePending($CustodyCell,$Slot,$Context,$HostileMode)
    $state=Get-Q009HeldHandleState $CustodyCell $Slot
    if($state.delete_pending-isnot[bool]-or-not[bool]$state.delete_pending){throw "$Context did not produce an exact true delete-pending state"}
    return $state
}

function Remove-Q009ManifestChildrenExceptSentinel {
    param([string]$RootPath,[object]$RootIdentity,[object]$SentinelIdentity,[object]$AuthorizedChainHead,[object]$ExpectedAttemptId,[object]$CustodyCell)
    if($null-eq$CustodyCell){throw 'Sentinel cleanup requires explicit custody, attempt, and manifest-chain authority; ambient fixture authority is forbidden'}
    if($ExpectedAttemptId-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$ExpectedAttemptId)){throw 'Sentinel cleanup requires an exact attempt id'}
    if(-not(Test-Q009FileSystemIdentityShape $RootIdentity)-or-not[bool]$RootIdentity.is_directory){throw 'Sentinel cleanup root identity is malformed'}
    if(-not(Test-Q009FileSystemIdentityShape $SentinelIdentity)-or[bool]$SentinelIdentity.is_directory){throw 'Sentinel cleanup file identity is malformed'}
    $root=[IO.Path]::GetFullPath($RootPath).TrimEnd('\','/');$sentinelPath=[IO.Path]::GetFullPath([string]$SentinelIdentity.path)
    if([string]$RootIdentity.path-cne$root-or[IO.Path]::GetDirectoryName($sentinelPath)-cne$root){throw 'Sentinel cleanup path/identity containment failed'}
    $relative=$sentinelPath.Substring($root.Length).TrimStart('\','/').Replace('\','/')
    if(-not(Test-Q009OwnedChildManifestChainHeadShape $AuthorizedChainHead $RootIdentity $ExpectedAttemptId)){throw 'Sentinel cleanup requires a sealed authorized child-manifest chain head'}
    $Manifest=$AuthorizedChainHead.manifest
    $current=Get-Q009ExactOwnedTreeManifest $root
    if(-not(Test-Q009ExactOwnedTreeManifestShape $current $RootIdentity)-or[string]$current.sha256-cne[string]$Manifest.sha256-or(($current|ConvertTo-Json -Depth 8 -Compress)-cne($Manifest|ConvertTo-Json -Depth 8 -Compress))){throw 'Sentinel cleanup rejected an added, removed, replaced, reordered, or content-mutated child after the terminal owned manifest'}
    Initialize-Q009ExactFileSystemType
    $native=[Q009ExactFileSystemNative]::DeleteManifestChildrenExcept($CustodyCell,$root,[string]$RootIdentity.native_key,[long]$RootIdentity.creation_ticks,$relative,[string]$SentinelIdentity.native_key,[long]$SentinelIdentity.creation_ticks,[string[]]@($Manifest.entries|ForEach-Object{[string]$_.path}),[string[]]@($Manifest.entries|ForEach-Object{[string]$_.native_key}),[long[]]@($Manifest.entries|ForEach-Object{[long]$_.creation_ticks}),[bool[]]@($Manifest.entries|ForEach-Object{[bool]$_.is_directory}),[long[]]@($Manifest.entries|ForEach-Object{[long]$_.length}),[string[]]@($Manifest.entries|ForEach-Object{[string]$_.sha256}))
    $expectedDeleteCount=@($Manifest.entries).Count-1
    if($native.Count-ne3-or[int]$native[0]-ne$expectedDeleteCount-or[string]$native[1]-cne$relative){throw 'Sentinel cleanup native receipt did not match the exact admitted manifest and sentinel'}
    $receipt=[ordered]@{deleted_entry_count=[int]$native[0];remaining_sentinel_relative_path=[string]$native[1];completed_utc=[string]$native[2];manifest_sha256=[string]$Manifest.sha256}
    if(-not(Test-Q009ManifestCleanupReceiptShape $receipt)){throw 'Sentinel cleanup native receipt failed its exact public schema'}
    return $receipt
}

function Test-Q009ExactPublicReceiptKeys {
    param([AllowNull()][object]$Receipt,[string[]]$ExpectedKeys)
    if($null-eq$Receipt-or$null-eq$ExpectedKeys){return $false}
    try{
        $actual=if($Receipt-is[System.Collections.IDictionary]){@($Receipt.Keys|ForEach-Object{if($_-isnot[string]){throw 'non-string key'};$_})}else{@($Receipt.PSObject.Properties|Where-Object{$_.MemberType-eq[System.Management.Automation.PSMemberTypes]::NoteProperty}|ForEach-Object{$_.Name})}
        if($actual.Count-ne$ExpectedKeys.Count-or@($actual|Sort-Object -Unique).Count-ne$actual.Count){return $false}
        for($index=0;$index-lt$ExpectedKeys.Count;$index+=1){
            if([string]$actual[$index]-cne[string]$ExpectedKeys[$index]){return $false}
        }
        return $true
    }catch{return $false}
}

function Test-Q009ExactRoundtripTimestamp {
    param([AllowNull()][object]$Value)
    if($Value-isnot[string]-or[string]::IsNullOrWhiteSpace($Value)){return $false}
    $parsed=[datetime]::MinValue
    return [datetime]::TryParse($Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Test-Q009FileSystemIdentityShape {
    param([AllowNull()][object]$Identity)
    if(-not(Test-Q009ExactPublicReceiptKeys $Identity @('path','native_key','creation_ticks','is_directory','reparse_point','attributes','key'))){return $false}
    if($Identity.path-isnot[string]-or[string]::IsNullOrWhiteSpace($Identity.path)-or$Identity.native_key-isnot[string]-or$Identity.native_key-cnotmatch'^[0-9A-F]{8}:[0-9A-F]{16}$'-or$Identity.creation_ticks-isnot[long]-or$Identity.creation_ticks-le0-or$Identity.is_directory-isnot[bool]-or$Identity.reparse_point-isnot[bool]-or$Identity.reparse_point-or$Identity.attributes-isnot[uint32]-or$Identity.key-isnot[string]){return $false}
    $kind=if($Identity.is_directory){'directory'}else{'file'}
    return [string]$Identity.key-ceq('{0}|{1}|{2}'-f$Identity.native_key,$Identity.creation_ticks,$kind)
}

function Test-Q009RunContextShape {
    param([AllowNull()][object]$Context)
    $keys=@(
        'schema_version','attempt_id','candidate_commit','candidate_tree','launcher_identity',
        'canonical_lease_root','canonical_lease_root_identity','native_exit_sentinel',
        'working_directory','project_root','project_cache_root','launch_mutex_name','context_sha256'
    )
    if(-not(Test-Q009ExactPublicReceiptKeys $Context $keys)){return $false}
    if($Context.schema_version-isnot[int]-or[int]$Context.schema_version-ne1-or
        $Context.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Context.attempt_id)-or
        $Context.candidate_commit-isnot[string]-or[string]$Context.candidate_commit-cnotmatch'^[0-9a-f]{40}$'-or
        $Context.candidate_tree-isnot[string]-or[string]$Context.candidate_tree-cnotmatch'^[0-9a-f]{40}$'-or
        -not(Test-ProcessIdentityProofShape $Context.launcher_identity)-or
        $Context.canonical_lease_root-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Context.canonical_lease_root)-or
        -not(Test-Q009FileSystemIdentityShape $Context.canonical_lease_root_identity)-or-not[bool]$Context.canonical_lease_root_identity.is_directory-or
        $Context.native_exit_sentinel-isnot[int]-or[int]$Context.native_exit_sentinel-ne[int]::MinValue-or
        $Context.working_directory-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Context.working_directory)-or
        $Context.project_root-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Context.project_root)-or
        $Context.project_cache_root-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Context.project_cache_root)-or
        $Context.launch_mutex_name-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Context.launch_mutex_name)-or
        $Context.context_sha256-isnot[string]-or[string]$Context.context_sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    try{
        $lease=[IO.Path]::GetFullPath([string]$Context.canonical_lease_root).TrimEnd('\','/')
        $project=[IO.Path]::GetFullPath([string]$Context.project_root).TrimEnd('\','/')
        $working=[IO.Path]::GetFullPath([string]$Context.working_directory).TrimEnd('\','/')
        $cache=[IO.Path]::GetFullPath([string]$Context.project_cache_root).TrimEnd('\','/')
    }catch{return $false}
    $payload=[ordered]@{}
    foreach($key in $keys|Where-Object{$_-cne'context_sha256'}){$payload[$key]=$Context.$key}
    return [string]$Context.context_sha256-ceq(Get-StringSha256 (($payload|ConvertTo-Json -Depth 12 -Compress)))-and
        [string]$Context.canonical_lease_root-ceq$lease-and
        [string]$Context.canonical_lease_root_identity.path-ceq$lease-and
        [string]$Context.project_root-ceq$project-and[string]$Context.project_cache_root-ceq$cache-and
        [string]$Context.project_cache_root-ceq([IO.Path]::GetFullPath((Join-Path $project '.godot')).TrimEnd('\','/'))-and
        [string]$Context.working_directory-ceq$working-and
        (Test-Q009FileSystemIdentityMatch $Context.canonical_lease_root_identity)-and
        (Test-LiveProcessMatchesIdentity $Context.launcher_identity)
}

function New-Q009RunContext {
    param(
        [string]$AttemptId,[string]$CandidateCommit,[string]$CandidateTree,
        [object]$LauncherIdentity,[string]$CanonicalLeaseRoot,
        [string]$WorkingDirectory,[string]$ProjectRoot,[string]$LaunchMutexName,
        [int]$NativeExitSentinel=[int]::MinValue
    )
    $lease=[IO.Path]::GetFullPath($CanonicalLeaseRoot).TrimEnd('\','/')
    $project=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
    $working=[IO.Path]::GetFullPath($WorkingDirectory).TrimEnd('\','/')
    $cache=[IO.Path]::GetFullPath((Join-Path $project '.godot')).TrimEnd('\','/')
    $context=[ordered]@{
        schema_version=[int]1;attempt_id=[string]$AttemptId;candidate_commit=[string]$CandidateCommit;
        candidate_tree=[string]$CandidateTree;launcher_identity=$LauncherIdentity;
        canonical_lease_root=[string]$lease;canonical_lease_root_identity=Get-Q009FileSystemEntryIdentity $lease;
        native_exit_sentinel=[int]$NativeExitSentinel;working_directory=[string]$working;
        project_root=[string]$project;project_cache_root=[string]$cache;launch_mutex_name=[string]$LaunchMutexName
    }
    $context.context_sha256=Get-StringSha256 (($context|ConvertTo-Json -Depth 12 -Compress))
    if(-not(Test-Q009RunContextShape $context)){throw 'Q-009 run context failed its exact closed immutable schema'}
    return $context
}

function Test-Q009CacheRootReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('path','identity','handle_slot','creation_method','creation_handle_retained','handle_state','exclusive_delete_lock','share_delete'))){return $false}
    return $Receipt.path-is[string]-and-not[string]::IsNullOrWhiteSpace($Receipt.path)-and
        (Test-Q009FileSystemIdentityShape $Receipt.identity)-and[bool]$Receipt.identity.is_directory-and[string]$Receipt.identity.path-ceq[string]$Receipt.path-and
        $Receipt.handle_slot-is[string]-and[string]$Receipt.handle_slot-ceq'root_creation'-and
        $Receipt.creation_method-is[string]-and[string]$Receipt.creation_method-ceq'NtCreateFile(FILE_CREATE)'-and
        $Receipt.creation_handle_retained-is[bool]-and[bool]$Receipt.creation_handle_retained-and
        $Receipt.handle_state-is[string]-and[string]$Receipt.handle_state-ceq'OPEN'-and
        $Receipt.exclusive_delete_lock-is[bool]-and[bool]$Receipt.exclusive_delete_lock-and
        $Receipt.share_delete-is[bool]-and-not[bool]$Receipt.share_delete
}

function Test-Q009SentinelReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('path','identity','handle_slot','creation_method','payload_sha256','payload_length','handle_state','share_write','share_delete'))){return $false}
    return $Receipt.path-is[string]-and-not[string]::IsNullOrWhiteSpace($Receipt.path)-and
        (Test-Q009FileSystemIdentityShape $Receipt.identity)-and-not[bool]$Receipt.identity.is_directory-and[string]$Receipt.identity.path-ceq[string]$Receipt.path-and
        $Receipt.handle_slot-is[string]-and[string]$Receipt.handle_slot-ceq'sentinel'-and
        $Receipt.creation_method-is[string]-and[string]$Receipt.creation_method-ceq'NtCreateFile(FILE_CREATE relative)'-and
        $Receipt.payload_sha256-is[string]-and[string]$Receipt.payload_sha256-cmatch'^[0-9A-F]{64}$'-and
        $Receipt.payload_length-is[int]-and[int]$Receipt.payload_length-gt0-and
        $Receipt.handle_state-is[string]-and[string]$Receipt.handle_state-ceq'OPEN'-and
        $Receipt.share_write-is[bool]-and-not[bool]$Receipt.share_write-and
        $Receipt.share_delete-is[bool]-and-not[bool]$Receipt.share_delete
}

function Test-Q009FinalRootReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('path','identity','handle_slot','handle_state','share_delete','delete_access'))){return $false}
    return $Receipt.path-is[string]-and-not[string]::IsNullOrWhiteSpace($Receipt.path)-and
        (Test-Q009FileSystemIdentityShape $Receipt.identity)-and[bool]$Receipt.identity.is_directory-and[string]$Receipt.identity.path-ceq[string]$Receipt.path-and
        $Receipt.handle_slot-is[string]-and[string]$Receipt.handle_slot-ceq'final_root'-and
        $Receipt.handle_state-is[string]-and[string]$Receipt.handle_state-ceq'OPEN'-and
        $Receipt.share_delete-is[bool]-and-not[bool]$Receipt.share_delete-and
        $Receipt.delete_access-is[bool]-and[bool]$Receipt.delete_access
}

function Test-Q009HeldHandleStateShape {
    param([AllowNull()][object]$Receipt,[AllowNull()][object]$ExpectedIdentity=$null,[AllowNull()][object]$ExpectedDirectory=$null)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('native_key','creation_ticks','attributes','delete_pending','is_directory','link_count','handle_state'))){return $false}
    if($Receipt.native_key-isnot[string]-or$Receipt.native_key-cnotmatch'^[0-9A-F]{8}:[0-9A-F]{16}$'-or$Receipt.creation_ticks-isnot[long]-or[long]$Receipt.creation_ticks-le0-or$Receipt.attributes-isnot[uint32]-or$Receipt.delete_pending-isnot[bool]-or$Receipt.is_directory-isnot[bool]-or$Receipt.link_count-isnot[uint32]-or$Receipt.handle_state-isnot[string]-or[string]$Receipt.handle_state-cne'OPEN'){return $false}
    if($null-ne$ExpectedIdentity){if(-not(Test-Q009FileSystemIdentityShape $ExpectedIdentity)-or[string]$Receipt.native_key-cne[string]$ExpectedIdentity.native_key-or[long]$Receipt.creation_ticks-ne[long]$ExpectedIdentity.creation_ticks){return $false}}
    if($null-ne$ExpectedDirectory){if($ExpectedDirectory-isnot[bool]-or[bool]$Receipt.is_directory-ne[bool]$ExpectedDirectory){return $false}}
    return $true
}

function Test-Q009ManifestCleanupReceiptShape {
    param([AllowNull()][object]$Receipt)
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt @('deleted_entry_count','remaining_sentinel_relative_path','completed_utc','manifest_sha256'))){return $false}
    return $Receipt.deleted_entry_count-is[int]-and[int]$Receipt.deleted_entry_count-ge0-and
        $Receipt.remaining_sentinel_relative_path-is[string]-and-not[string]::IsNullOrWhiteSpace($Receipt.remaining_sentinel_relative_path)-and
        (Test-Q009ExactRoundtripTimestamp $Receipt.completed_utc)-and
        $Receipt.manifest_sha256-is[string]-and[string]$Receipt.manifest_sha256-cmatch'^[0-9A-F]{64}$'
}

function Test-Q009FileSystemIdentityMatch {
    param([AllowNull()][object]$Expected)
    if(-not(Test-Q009FileSystemIdentityShape $Expected)){return $false}
    try{$current=Get-Q009FileSystemEntryIdentity ([string]$Expected.path);return [string]$current.native_key-ceq[string]$Expected.native_key-and[long]$current.creation_ticks-eq[long]$Expected.creation_ticks-and[bool]$current.is_directory-eq[bool]$Expected.is_directory}catch{return $false}
}

function Copy-Q009FileSystemIdentityToPath {
    param([object]$Identity,[string]$Path)
    if(-not(Test-Q009FileSystemIdentityShape $Identity)){throw 'Cannot relocate a malformed exact filesystem identity receipt'}
    $resolved=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    return [ordered]@{path=$resolved;native_key=[string]$Identity.native_key;creation_ticks=[long]$Identity.creation_ticks;is_directory=[bool]$Identity.is_directory;reparse_point=$false;attributes=[uint32]$Identity.attributes;key=('{0}|{1}|{2}'-f$Identity.native_key,[long]$Identity.creation_ticks,$(if([bool]$Identity.is_directory){'directory'}else{'file'}))}
}

function Publish-Q009EvidenceStageDirectory {
    param([string]$SourcePath,[string]$DestinationPath,[object]$SourceIdentity,[object]$ExpectedParentIdentity)
    $source=[IO.Path]::GetFullPath($SourcePath).TrimEnd('\','/');$destination=[IO.Path]::GetFullPath($DestinationPath).TrimEnd('\','/')
    if(-not(Test-Q009FileSystemIdentityShape $SourceIdentity)-or-not[bool]$SourceIdentity.is_directory-or[string]$SourceIdentity.path-cne$source){throw 'Evidence-stage publication requires the exact source identity'}
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedParentIdentity)-or-not[bool]$ExpectedParentIdentity.is_directory-or[string]$ExpectedParentIdentity.path-cne[IO.Path]::GetDirectoryName($source)-or[IO.Path]::GetDirectoryName($destination)-cne[string]$ExpectedParentIdentity.path){throw 'Evidence-stage publication requires one exact shared parent identity'}
    Initialize-Q009ExactFileSystemType
    [Q009ExactFileSystemNative]::PublishEvidenceStageDirectoryNoReplace($source,$destination,[string]$SourceIdentity.native_key,[long]$SourceIdentity.creation_ticks,[string]$ExpectedParentIdentity.path,[string]$ExpectedParentIdentity.native_key,[long]$ExpectedParentIdentity.creation_ticks)
}

function Move-Q009PublishedEvidenceRootAsideForHostile {
    param([string]$SourcePath,[string]$DestinationPath,[object]$SourceIdentity,[object]$ExpectedParentIdentity)
    $source=[IO.Path]::GetFullPath($SourcePath).TrimEnd('\','/');$destination=[IO.Path]::GetFullPath($DestinationPath).TrimEnd('\','/')
    if(-not(Test-Q009FileSystemIdentityShape $SourceIdentity)-or-not[bool]$SourceIdentity.is_directory-or[string]$SourceIdentity.path-cne$source-or-not(Test-Q009FileSystemIdentityShape $ExpectedParentIdentity)-or-not[bool]$ExpectedParentIdentity.is_directory-or[string]$ExpectedParentIdentity.path-cne[IO.Path]::GetDirectoryName($source)-or[IO.Path]::GetDirectoryName($destination)-cne[string]$ExpectedParentIdentity.path){throw 'Hostile evidence move requires exact source and shared-parent identities'}
    Initialize-Q009ExactFileSystemType
    [Q009ExactFileSystemNative]::MovePublishedEvidenceRootAsideForHostileNoReplace($source,$destination,[string]$SourceIdentity.native_key,[long]$SourceIdentity.creation_ticks,[string]$ExpectedParentIdentity.path,[string]$ExpectedParentIdentity.native_key,[long]$ExpectedParentIdentity.creation_ticks)
}

function Publish-Q009OwnedEvidenceArtifact {
    param([string]$SourcePath,[string]$DestinationPath,[object]$SourceIdentity,[object]$ExpectedParentIdentity)
    $source=[IO.Path]::GetFullPath($SourcePath);$destination=[IO.Path]::GetFullPath($DestinationPath)
    if(-not(Test-Q009FileSystemIdentityShape $SourceIdentity)-or[bool]$SourceIdentity.is_directory-or[string]$SourceIdentity.path-cne$source-or-not(Test-Q009FileSystemIdentityShape $ExpectedParentIdentity)-or-not[bool]$ExpectedParentIdentity.is_directory-or[string]$ExpectedParentIdentity.path-cne[IO.Path]::GetDirectoryName($source)-or[IO.Path]::GetDirectoryName($destination)-cne[string]$ExpectedParentIdentity.path){throw 'Artifact publication requires exact source and shared-parent identities'}
    Initialize-Q009ExactFileSystemType
    [Q009ExactFileSystemNative]::PublishOwnedEvidenceArtifactNoReplace($source,$destination,[string]$SourceIdentity.native_key,[long]$SourceIdentity.creation_ticks,[string]$ExpectedParentIdentity.path,[string]$ExpectedParentIdentity.native_key,[long]$ExpectedParentIdentity.creation_ticks)
}

function Invoke-Q009PinnedCapabilityRootRenameHostile {
    param([object]$CustodyCell,[string]$Slot,[string]$SourcePath,[string]$DestinationPath,[object]$SourceIdentity,[switch]$Posix)
    if(-not(Test-Q009FileSystemIdentityShape $SourceIdentity)-or-not[bool]$SourceIdentity.is_directory-or[string]$SourceIdentity.path-cne[IO.Path]::GetFullPath($SourcePath).TrimEnd('\','/')){throw 'Capability rename hostile requires the exact held root identity'}
    Initialize-Q009ExactFileSystemType
    if($Posix){[Q009ExactFileSystemNative]::AttemptPinnedCapabilityRootPosixRenameNoReplace($CustodyCell,$Slot,[string]$SourceIdentity.path,[IO.Path]::GetFullPath($DestinationPath),[string]$SourceIdentity.native_key,[long]$SourceIdentity.creation_ticks)}else{[Q009ExactFileSystemNative]::AttemptPinnedCapabilityRootRenameNoReplace($CustodyCell,$Slot,[string]$SourceIdentity.path,[IO.Path]::GetFullPath($DestinationPath),[string]$SourceIdentity.native_key,[long]$SourceIdentity.creation_ticks)}
}

function Get-Q009ExactOwnedTreeManifest {
    param([string]$RootPath)
    $root=[IO.Path]::GetFullPath($RootPath).TrimEnd('\','/');$rootIdentity=Get-Q009FileSystemEntryIdentity $root
    if(-not[bool]$rootIdentity.is_directory){throw 'Exact owned tree root is not a directory'}
    $entries=[Collections.Generic.List[object]]::new();$pending=[Collections.Generic.Stack[string]]::new();$pending.Push($root)
    while($pending.Count-gt0){$directory=$pending.Pop();foreach($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop|Sort-Object FullName)){if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "Exact owned tree contains a reparse point: $($item.FullName)"};$relative=$item.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/');if($item.PSIsContainer){$identity=Get-Q009FileSystemEntryIdentity $item.FullName;[void]$entries.Add([ordered]@{path=$relative;native_key=[string]$identity.native_key;creation_ticks=[long]$identity.creation_ticks;is_directory=[bool]$true;length=[long]-1;sha256=[string]''});$pending.Push($item.FullName)}else{$stream=$null;$hasher=$null;try{$stream=[IO.File]::Open($item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$identity=Get-Q009FileSystemHandleIdentity -Handle $stream.SafeFileHandle -Path $item.FullName -IsDirectory $false;$hasher=[Security.Cryptography.SHA256]::Create();$hash=([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','').ToUpperInvariant();[void]$entries.Add([ordered]@{path=$relative;native_key=[string]$identity.native_key;creation_ticks=[long]$identity.creation_ticks;is_directory=[bool]$false;length=[long]$stream.Length;sha256=[string]$hash})}finally{if($null-ne$hasher){$hasher.Dispose()};if($null-ne$stream){$stream.Dispose()}}}}}
    $ordered=@($entries|Sort-Object path);$payload=[ordered]@{root_native_key=[string]$rootIdentity.native_key;root_creation_ticks=[long]$rootIdentity.creation_ticks;entries=$ordered};return [ordered]@{root_identity=$rootIdentity;entries=$ordered;sha256=Get-StringSha256 (($payload|ConvertTo-Json -Depth 6 -Compress))}
}

function Test-Q009ExactOwnedTreeManifestShape {
    param([AllowNull()][object]$Manifest,[AllowNull()][object]$ExpectedRootIdentity=$null)
    if(-not(Test-Q009ExactPublicReceiptKeys $Manifest @('root_identity','entries','sha256'))-or-not(Test-Q009FileSystemIdentityShape $Manifest.root_identity)-or-not[bool]$Manifest.root_identity.is_directory-or$Manifest.entries-isnot[System.Array]-or$Manifest.sha256-isnot[string]-or[string]$Manifest.sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    if($null-ne$ExpectedRootIdentity){if(-not(Test-Q009FileSystemIdentityShape $ExpectedRootIdentity)-or[string]$Manifest.root_identity.key-cne[string]$ExpectedRootIdentity.key){return $false}}
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in @($Manifest.entries)){
        if(-not(Test-Q009ExactPublicReceiptKeys $entry @('path','native_key','creation_ticks','is_directory','length','sha256'))-or$entry.path-isnot[string]-or[string]::IsNullOrWhiteSpace($entry.path)-or[IO.Path]::IsPathRooted([string]$entry.path)-or-not$seen.Add([string]$entry.path)-or$entry.native_key-isnot[string]-or$entry.native_key-cnotmatch'^[0-9A-F]{8}:[0-9A-F]{16}$'-or$entry.creation_ticks-isnot[long]-or[long]$entry.creation_ticks-le0-or$entry.is_directory-isnot[bool]-or$entry.length-isnot[long]-or$entry.sha256-isnot[string]){return $false}
        if([bool]$entry.is_directory){if([long]$entry.length-ne-1-or[string]$entry.sha256-cne''){return $false}}elseif([long]$entry.length-lt0-or[string]$entry.sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    }
    $payload=[ordered]@{root_native_key=[string]$Manifest.root_identity.native_key;root_creation_ticks=[long]$Manifest.root_identity.creation_ticks;entries=@($Manifest.entries)}
    return [string]$Manifest.sha256-ceq(Get-StringSha256 (($payload|ConvertTo-Json -Depth 6 -Compress)))
}

function Test-Q009OwnedArtifactRootRequestShape {
    param([AllowNull()][object]$Request)
    if(-not(Test-Q009ExactPublicReceiptKeys $Request @('role','path','root_identity'))){return $false}
    if($Request.role-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Request.role)-or
        $Request.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Request.path)-or
        -not(Test-Q009FileSystemIdentityShape $Request.root_identity)-or-not[bool]$Request.root_identity.is_directory){return $false}
    try{$resolved=[IO.Path]::GetFullPath([string]$Request.path).TrimEnd('\','/')}catch{return $false}
    return [string]$Request.path-ceq$resolved-and[string]$Request.root_identity.path-ceq$resolved
}

function Test-Q009ClosedArtifactManifestReceiptShape {
    param([AllowNull()][object]$Receipt,[AllowNull()][object]$RunContext=$null,[AllowNull()][object]$ProcessIdentity=$null)
    $keys=@('role','path','root_identity','manifest','captured_after_job_close','job_membership_empty','process_identity','attempt_id','captured_utc','receipt_sha256')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or
        $Receipt.role-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.role)-or
        $Receipt.path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.path)-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.root_identity)-or-not[bool]$Receipt.root_identity.is_directory-or
        -not(Test-Q009ExactOwnedTreeManifestShape $Receipt.manifest $Receipt.root_identity)-or
        $Receipt.captured_after_job_close-isnot[bool]-or-not[bool]$Receipt.captured_after_job_close-or
        $Receipt.job_membership_empty-isnot[bool]-or-not[bool]$Receipt.job_membership_empty-or
        -not(Test-ProcessIdentityProofShape $Receipt.process_identity)-or
        $Receipt.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Receipt.attempt_id)-or
        -not(Test-Q009ExactRoundtripTimestamp $Receipt.captured_utc)-or
        $Receipt.receipt_sha256-isnot[string]-or[string]$Receipt.receipt_sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    if([string]$Receipt.path-cne[string]$Receipt.root_identity.path){return $false}
    if($null-ne$RunContext){if(-not(Test-Q009RunContextShape $RunContext)-or[string]$Receipt.attempt_id-cne[string]$RunContext.attempt_id){return $false}}
    if($null-ne$ProcessIdentity){if(-not(Test-ProcessIdentityProofShape $ProcessIdentity)-or[string]$Receipt.process_identity.key-cne[string]$ProcessIdentity.key){return $false}}
    $payload=[ordered]@{};foreach($key in $keys|Where-Object{$_-cne'receipt_sha256'}){$payload[$key]=$Receipt.$key}
    return [string]$Receipt.receipt_sha256-ceq(Get-StringSha256 (($payload|ConvertTo-Json -Depth 12 -Compress)))
}

function New-Q009ClosedArtifactManifestReceipt {
    param([object]$Request,[object]$RunContext,[object]$ProcessIdentity)
    if(-not(Test-Q009OwnedArtifactRootRequestShape $Request)){throw 'Closed-process artifact request failed its exact schema'}
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Closed-process artifact capture requires one exact run context'}
    if(-not(Test-ProcessIdentityProofShape $ProcessIdentity)){throw 'Closed-process artifact capture requires the exact owned process identity'}
    if(-not(Test-Q009FileSystemIdentityMatch $Request.root_identity)){throw "Closed-process artifact root was missing or replaced: $($Request.path)"}
    $manifest=Get-Q009ExactOwnedTreeManifest ([string]$Request.path)
    if(-not(Test-Q009ExactOwnedTreeManifestShape $manifest $Request.root_identity)){throw "Closed-process artifact manifest was malformed: $($Request.path)"}
    $receipt=[ordered]@{
        role=[string]$Request.role;path=[string]$Request.path;root_identity=$Request.root_identity;manifest=$manifest;
        captured_after_job_close=[bool]$true;job_membership_empty=[bool]$true;process_identity=$ProcessIdentity;
        attempt_id=[string]$RunContext.attempt_id;captured_utc=[DateTime]::UtcNow.ToString('o')
    }
    $receipt.receipt_sha256=Get-StringSha256 (($receipt|ConvertTo-Json -Depth 12 -Compress))
    if(-not(Test-Q009ClosedArtifactManifestReceiptShape $receipt $RunContext $ProcessIdentity)){throw 'Closed-process artifact manifest receipt failed its exact schema'}
    return $receipt
}

function Test-Q009OwnedChildManifestChainHeadShape {
    param(
        [AllowNull()][object]$Receipt,
        [AllowNull()][object]$ExpectedRootIdentity=$null,
        [string]$ExpectedAttemptId='',
        [string]$ExpectedBoundary=''
    )
    $keys=@('schema_version','attempt_id','sequence','boundary','owner_kind','owner_receipt_sha256','previous_head_sha256','captured_utc','root_identity','manifest','head_sha256')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)){return $false}
    if($Receipt.schema_version-isnot[int]-or[int]$Receipt.schema_version-ne1-or$Receipt.attempt_id-isnot[string]-or[string]::IsNullOrWhiteSpace($Receipt.attempt_id)-or$Receipt.sequence-isnot[int]-or[int]$Receipt.sequence-lt0-or$Receipt.boundary-isnot[string]-or[string]::IsNullOrWhiteSpace($Receipt.boundary)-or$Receipt.owner_kind-isnot[string]-or[string]::IsNullOrWhiteSpace($Receipt.owner_kind)-or$Receipt.owner_receipt_sha256-isnot[string]-or[string]$Receipt.owner_receipt_sha256-cnotmatch'^[0-9A-F]{64}$'-or$Receipt.previous_head_sha256-isnot[string]-or([string]$Receipt.previous_head_sha256-ne''-and[string]$Receipt.previous_head_sha256-cnotmatch'^[0-9A-F]{64}$')-or-not(Test-Q009ExactRoundtripTimestamp $Receipt.captured_utc)-or-not(Test-Q009FileSystemIdentityShape $Receipt.root_identity)-or-not[bool]$Receipt.root_identity.is_directory-or-not(Test-Q009ExactOwnedTreeManifestShape $Receipt.manifest $Receipt.root_identity)-or$Receipt.head_sha256-isnot[string]-or[string]$Receipt.head_sha256-cnotmatch'^[0-9A-F]{64}$'){return $false}
    if($null-ne$ExpectedRootIdentity-and(-not(Test-Q009FileSystemIdentityShape $ExpectedRootIdentity)-or[string]$Receipt.root_identity.key-cne[string]$ExpectedRootIdentity.key)){return $false}
    if($ExpectedAttemptId-and[string]$Receipt.attempt_id-cne$ExpectedAttemptId){return $false}
    if($ExpectedBoundary-and[string]$Receipt.boundary-cne$ExpectedBoundary){return $false}
    if(([int]$Receipt.sequence-eq0)-ne([string]::IsNullOrEmpty([string]$Receipt.previous_head_sha256))){return $false}
    $payload=[ordered]@{schema_version=[int]$Receipt.schema_version;attempt_id=[string]$Receipt.attempt_id;sequence=[int]$Receipt.sequence;boundary=[string]$Receipt.boundary;owner_kind=[string]$Receipt.owner_kind;owner_receipt_sha256=[string]$Receipt.owner_receipt_sha256;previous_head_sha256=[string]$Receipt.previous_head_sha256;captured_utc=[string]$Receipt.captured_utc;root_identity=$Receipt.root_identity;manifest=$Receipt.manifest}
    return [string]$Receipt.head_sha256-ceq(Get-StringSha256 (($payload|ConvertTo-Json -Depth 12 -Compress)))
}

function New-Q009OwnedChildManifestChainHead {
    param(
        [string]$RootPath,
        [object]$RootIdentity,
        [string]$AttemptId,
        [string]$Boundary,
        [ValidateSet('launcher_fixture','evidence_owner','closed_process_phase','cache_creator','profile_creator','validator_shadow')][string]$OwnerKind,
        [object]$OwnerReceipt,
        [AllowNull()][object]$PreviousHead=$null
    )
    if(-not(Test-Q009FileSystemIdentityShape $RootIdentity)-or-not[bool]$RootIdentity.is_directory-or[string]$RootIdentity.path-cne[IO.Path]::GetFullPath($RootPath).TrimEnd('\','/')){throw 'Owned-child manifest chain requires the exact root identity'}
    if($AttemptId-isnot[string]-or[string]::IsNullOrWhiteSpace($AttemptId)-or$Boundary-isnot[string]-or[string]::IsNullOrWhiteSpace($Boundary)){throw 'Owned-child manifest chain requires exact nonempty attempt and boundary strings'}
    if($null-eq$OwnerReceipt){throw 'Owned-child manifest chain requires a previously validated owner receipt'}
    $previousSha='';$sequence=0
    if($null-ne$PreviousHead){if(-not(Test-Q009OwnedChildManifestChainHeadShape $PreviousHead $RootIdentity $AttemptId)){throw 'Owned-child manifest chain predecessor was malformed or belonged to another root/attempt'};$previousSha=[string]$PreviousHead.head_sha256;$sequence=[int]$PreviousHead.sequence+1}
    $ownerJson=$OwnerReceipt|ConvertTo-Json -Depth 30 -Compress
    if([string]::IsNullOrWhiteSpace($ownerJson)){throw 'Owned-child manifest owner receipt could not be serialized'}
    $manifest=Get-Q009ExactOwnedTreeManifest $RootPath
    $payload=[ordered]@{schema_version=[int]1;attempt_id=[string]$AttemptId;sequence=[int]$sequence;boundary=[string]$Boundary;owner_kind=[string]$OwnerKind;owner_receipt_sha256=Get-StringSha256 $ownerJson;previous_head_sha256=[string]$previousSha;captured_utc=[DateTime]::UtcNow.ToString('o');root_identity=$RootIdentity;manifest=$manifest}
    $receipt=[ordered]@{};foreach($key in $payload.Keys){$receipt[$key]=$payload[$key]};$receipt.head_sha256=Get-StringSha256 (($payload|ConvertTo-Json -Depth 12 -Compress))
    if(-not(Test-Q009OwnedChildManifestChainHeadShape $receipt $RootIdentity $AttemptId $Boundary)){throw 'Owned-child manifest chain head failed its closed schema'}
    return $receipt
}

function Remove-Q009ExactOwnedFile {
    param([string]$Path,[object]$ExpectedIdentity,[string]$ExpectedSha256='')
    $resolved=[IO.Path]::GetFullPath($Path)
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedIdentity)-or[bool]$ExpectedIdentity.is_directory-or[string]$ExpectedIdentity.path-cne$resolved-or-not(Test-Q009FileSystemIdentityMatch $ExpectedIdentity)){throw 'Exact owned file was absent, malformed, or replaced before cleanup'}
    if($ExpectedSha256-and((Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash-cne$ExpectedSha256)){throw 'Exact owned file bytes changed before cleanup'}
    Initialize-Q009ExactFileSystemType;[Q009ExactFileSystemNative]::DeleteEntryExact($resolved,[string]$ExpectedIdentity.native_key,[long]$ExpectedIdentity.creation_ticks,$false)
    if(Test-Path -LiteralPath $resolved){throw 'Exact owned file remained after handle-bound cleanup'}
}

function Remove-Q009ExactOwnedTree {
    param([string]$OwnedPath,[string]$QuarantinePath,[object]$ExpectedRootIdentity,[object]$AuthorizedChainHead,[string]$ExpectedAttemptId,[switch]$ForceQuarantineReplacementForTest)
    $owned=[IO.Path]::GetFullPath($OwnedPath).TrimEnd('\','/');$quarantine=[IO.Path]::GetFullPath($QuarantinePath).TrimEnd('\','/')
    if([IO.Path]::GetDirectoryName($owned)-cne[IO.Path]::GetDirectoryName($quarantine)){throw 'Exact owned tree quarantine must be a same-directory rename'}
    if(-not(Test-Q009FileSystemIdentityShape $ExpectedRootIdentity)-or-not[bool]$ExpectedRootIdentity.is_directory-or[string]$ExpectedRootIdentity.path-cne$owned-or-not(Test-Q009FileSystemIdentityMatch $ExpectedRootIdentity)){throw 'Exact owned tree root was replaced before quarantine'}
    if(Test-Path -LiteralPath $quarantine){throw "Exact owned tree quarantine already exists: $quarantine"}
    if(-not(Test-Q009OwnedChildManifestChainHeadShape $AuthorizedChainHead $ExpectedRootIdentity $ExpectedAttemptId)){throw 'Exact owned tree cleanup requires a previously sealed authorized child-manifest chain head'}
    $AuthorizedManifest=$AuthorizedChainHead.manifest
    $manifest=Get-Q009ExactOwnedTreeManifest $owned
    if([string]$manifest.root_identity.native_key-cne[string]$ExpectedRootIdentity.native_key-or[long]$manifest.root_identity.creation_ticks-ne[long]$ExpectedRootIdentity.creation_ticks-or[string]$manifest.sha256-cne[string]$AuthorizedManifest.sha256-or(($manifest|ConvertTo-Json -Depth 8 -Compress)-cne($AuthorizedManifest|ConvertTo-Json -Depth 8 -Compress))){throw 'Exact owned tree differs from its authoritative pre-cleanup manifest; the tree was preserved'}
    if($ForceQuarantineReplacementForTest){
        $saved=$owned+'.owned-original-'+[guid]::NewGuid().ToString('N')
        [IO.Directory]::Move($owned,$saved)
        [void](New-Q009ExactOwnedDirectory $owned)
        [IO.File]::WriteAllText((Join-Path $owned 'foreign.txt'),'foreign')
    }
    Initialize-Q009ExactFileSystemType
    $parentIdentity=Get-Q009FileSystemEntryIdentity ([IO.Path]::GetDirectoryName($owned))
    [Q009ExactFileSystemNative]::MoveOwnedCleanupTreeToQuarantineNoReplace($owned,$quarantine,[string]$ExpectedRootIdentity.native_key,[long]$ExpectedRootIdentity.creation_ticks,[string]$parentIdentity.path,[string]$parentIdentity.native_key,[long]$parentIdentity.creation_ticks)
    $quarantineIdentity=Get-Q009FileSystemEntryIdentity $quarantine
    if([string]$quarantineIdentity.native_key-cne[string]$ExpectedRootIdentity.native_key-or[long]$quarantineIdentity.creation_ticks-ne[long]$ExpectedRootIdentity.creation_ticks){throw 'Atomically quarantined tree was not the exact owned root'}
    [Q009ExactFileSystemNative]::DeleteTreeExact($quarantine,[string]$quarantineIdentity.native_key,[long]$quarantineIdentity.creation_ticks,[string[]]@($manifest.entries|ForEach-Object{[string]$_.path}),[string[]]@($manifest.entries|ForEach-Object{[string]$_.native_key}),[long[]]@($manifest.entries|ForEach-Object{[long]$_.creation_ticks}),[bool[]]@($manifest.entries|ForEach-Object{[bool]$_.is_directory}),[long[]]@($manifest.entries|ForEach-Object{[long]$_.length}),[string[]]@($manifest.entries|ForEach-Object{[string]$_.sha256}))
    if((Test-Path -LiteralPath $owned)-or(Test-Path -LiteralPath $quarantine)){throw 'Exact owned tree original or quarantine path remained after cleanup'}
    return [ordered]@{removed=$true;manifest_sha256=[string]$manifest.sha256;entry_count=@($manifest.entries).Count;handle_bound=$true}
}

function Assert-LauncherContract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
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
        throw 'Q-009 evidence requires a clean committed candidate tree.'
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

function Get-ProcessByIdStrict {
    param(
        [int]$ProcessId,
        [switch]$ForceEnumerationFailureForTest
    )
    if ($ProcessId -le 0) { return $null }
    if ($ForceEnumerationFailureForTest) {
        throw "Forced process lookup failure for hostile validation: $ProcessId"
    }
    try {
        return [System.Diagnostics.Process]::GetProcessById($ProcessId)
    }
    catch [System.ArgumentException] {
        # GetProcessById documents ArgumentException for an ID that is no
        # longer running.  Every other lookup failure must propagate.
        return $null
    }
    catch {
        throw "Process lookup failed closed for PID $ProcessId`: $($_.Exception.Message)"
    }
}

function Get-AllProcessesStrict {
    param([switch]$ForceEnumerationFailureForTest)
    if ($ForceEnumerationFailureForTest) {
        throw 'Forced process enumeration failure for hostile validation.'
    }
    try {
        return @(Get-Process -ErrorAction Stop)
    }
    catch {
        throw "Process enumeration failed closed: $($_.Exception.Message)"
    }
}

function Get-CimProcessSnapshotStrict {
    param([switch]$ForceEnumerationFailureForTest)
    if ($ForceEnumerationFailureForTest) {
        throw 'Forced CIM process enumeration failure for hostile validation.'
    }
    try {
        return @(Get-CimInstance Win32_Process -ErrorAction Stop)
    }
    catch {
        throw "CIM process enumeration failed closed: $($_.Exception.Message)"
    }
}

function Get-ProcessIdentityOrNullIfExited {
    param([int]$ProcessId)
    $live = Get-ProcessByIdStrict -ProcessId $ProcessId
    if ($null -eq $live) { return $null }
    try {
        return Get-ProcessIdentityRecord -Process $live
    }
    catch {
        # A process may exit between the strict lookup and property reads.  It
        # is clean only if a second strict lookup proves that exact PID absent.
        if ($null -eq (Get-ProcessByIdStrict -ProcessId $ProcessId)) { return $null }
        throw "Could not bind exact identity for live PID $ProcessId`: $($_.Exception.Message)"
    }
}

function Get-LiveGodotProcesses {
    param([switch]$ForceEnumerationFailureForTest)
    return @(Get-AllProcessesStrict -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest | Where-Object {
        $_.ProcessName -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64')
    })
}

function Get-StrictSharedLeaseFiles {
    param([object]$RunContext,[switch]$ForceEnumerationFailureForTest)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Shared lease enumeration requires one exact sealed Q-009 run context'}
    $rootFull = [string]$RunContext.canonical_lease_root
    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
        throw "Shared lease root is missing or is not a directory: $rootFull"
    }
    $rootItem = Get-Item -LiteralPath $rootFull -Force -ErrorAction Stop
    if (
        -not ($rootItem -is [System.IO.DirectoryInfo]) `
        -or ($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    ) {
        throw "Shared lease root is not an ordinary directory: $rootFull"
    }
    if ($ForceEnumerationFailureForTest) {
        throw "Forced shared lease enumeration failure for hostile validation: $rootFull"
    }
    try {
        # Deliberately enumerate every matching filesystem object.  A directory,
        # junction, or symlink named *.lease is invalid evidence, not something
        # that may disappear behind Get-ChildItem -File.
        $entries = @(Get-ChildItem -LiteralPath $rootFull -Filter '*.lease' -Force -ErrorAction Stop)
    }
    catch {
        throw "Shared lease enumeration failed closed for $rootFull`: $($_.Exception.Message)"
    }
    foreach ($entry in $entries) {
        if (
            -not ($entry -is [System.IO.FileInfo]) `
            -or ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        ) {
            throw "Shared lease enumeration found a non-ordinary lease object: $($entry.FullName)"
        }
    }
    return @($entries)
}

function Clear-StaleGodotLeases {
    param([object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Stale-lease cleanup requires one exact sealed Q-009 run context'}
    foreach ($lease in @(Get-StrictSharedLeaseFiles -RunContext $RunContext)) {
        # Malformed leases are deliberately retained.  They block admission;
        # they never become deletion authority merely because a filename PID
        # is absent or has been reused.
        $record = Get-StrictLeaseOwnerRecord -Lease $lease
        if (-not (Test-LiveProcessMatchesIdentity $record.identity)) {
            Remove-Q009ExactOwnedFile -Path $lease.FullName -ExpectedIdentity $record.file_identity
        }
    }
}

function Get-ProcessIdentityRecord {
    param([System.Diagnostics.Process]$Process)
    $startUtc = $Process.StartTime.ToUniversalTime()
    $result=[ordered]@{
        pid = [int]$Process.Id
        name = [string]$Process.ProcessName
        start_utc = $startUtc.ToString('o')
        start_ticks = [long]$startUtc.Ticks
        key = ('{0}|{1}|{2}' -f $Process.Id, $startUtc.Ticks, $Process.ProcessName)
    }
    return $result
}

function Test-LiveProcessMatchesIdentity {
    param([object]$ExpectedIdentity)
    if (-not(Test-ProcessIdentityProofShape $ExpectedIdentity)) {
        return $false
    }
    $liveIdentity = Get-ProcessIdentityOrNullIfExited -ProcessId ([int]$ExpectedIdentity.pid)
    if ($null -eq $liveIdentity) { return $false }
    return [string]$liveIdentity.key -ceq [string]$ExpectedIdentity.key
}

function Test-ProcessIdentityProofShape {
    param([AllowNull()][object]$Identity)
    if (-not(Test-Q009ExactPublicReceiptKeys $Identity @('pid','name','start_utc','start_ticks','key'))) { return $false }
    try {
        if($Identity.pid-isnot[int]-or$Identity.name-isnot[string]-or$Identity.start_utc-isnot[string]-or$Identity.start_ticks-isnot[long]-or$Identity.key-isnot[string]){return $false}
        $pidValue = $Identity.pid
        $nameValue = $Identity.name
        $startTicks = $Identity.start_ticks
        $keyValue = $Identity.key
        $parsedStart = [datetime]::MinValue
        if (
            $pidValue -le 0 `
            -or [string]::IsNullOrWhiteSpace($nameValue) `
            -or $startTicks -le 0 `
            -or [string]::IsNullOrWhiteSpace($Identity.start_utc) `
            -or -not [datetime]::TryParse(
                $Identity.start_utc,
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

function Test-Q009ExecutablePinReleaseReceiptShape {
    param([AllowNull()][object]$Receipt)
    return (Test-Q009ExactPublicReceiptKeys $Receipt @('released','receipt_sha256','closed_handle_count','all_terminal'))-and
        $Receipt.released-is[bool]-and[bool]$Receipt.released-and$Receipt.receipt_sha256-is[string]-and[string]$Receipt.receipt_sha256-cmatch'^[0-9A-F]{64}$'-and
        $Receipt.closed_handle_count-is[int]-and[int]$Receipt.closed_handle_count-ge2-and$Receipt.all_terminal-is[bool]-and[bool]$Receipt.all_terminal
}

function Test-Q009ObservedStartReceiptShape {
    param([AllowNull()][object]$Receipt,[switch]$AllowEmpty)
    if($AllowEmpty-and$null-eq$Receipt){return $true}
    $keys=@('process_id','process_name','launch_lower_utc','launch_lower_ticks','launch_upper_utc','launch_upper_ticks','process_start_utc','process_start_ticks')
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)-or$Receipt.process_id-isnot[int]-or[int]$Receipt.process_id-lt0-or$Receipt.process_name-isnot[string]-or
        $Receipt.launch_lower_utc-isnot[string]-or$Receipt.launch_lower_ticks-isnot[long]-or$Receipt.launch_upper_utc-isnot[string]-or$Receipt.launch_upper_ticks-isnot[long]-or
        $Receipt.process_start_utc-isnot[string]-or$Receipt.process_start_ticks-isnot[long]){return $false}
    foreach($pair in @(@('launch_lower_utc','launch_lower_ticks'),@('launch_upper_utc','launch_upper_ticks'),@('process_start_utc','process_start_ticks'))){
        $text=[string]$Receipt.($pair[0]);$ticks=[long]$Receipt.($pair[1])
        if($ticks-eq0){if($text-cne''){return $false}}else{$parsed=[datetime]::MinValue;if(-not[datetime]::TryParse($text,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)-or[long]$parsed.ToUniversalTime().Ticks-ne$ticks){return $false}}
    }
    return $true
}

function Test-Q009StartProofShape {
    param([AllowNull()][object]$Proof,[switch]$AllowInvalid)
    $keys=@('receipt_valid','validation_error','started','start_observed','process_id_observed','process_start_time_observed','process_name_observed','root_handle_cleanup_succeeded','job_assignment_succeeded','job_accounting_succeeded','job_cleanup_succeeded','job_pretermination_active_process_count','job_pretermination_membership_count','job_final_active_process_count','job_final_membership_empty','identity_ambiguity','process_id','process_identity','identity_capture_complete','observed_start','retained_descendant_identities','unowned_godot_identities','baseline_godot_identity_keys','setup_cleanup_error','process_kind','provenance','launched_image_path','executable_pin_receipt','executable_pin_release')
    if(-not(Test-Q009ExactPublicReceiptKeys $Proof $keys)-or$Proof.receipt_valid-isnot[bool]-or$Proof.validation_error-isnot[string]){return $false}
    foreach($name in @('started','start_observed','process_id_observed','process_start_time_observed','process_name_observed','root_handle_cleanup_succeeded','job_assignment_succeeded','job_accounting_succeeded','job_cleanup_succeeded','job_final_membership_empty','identity_ambiguity','identity_capture_complete')){if($Proof.$name-isnot[bool]){return $false}}
    foreach($name in @('job_pretermination_active_process_count','job_pretermination_membership_count','job_final_active_process_count','process_id')){if($Proof.$name-isnot[int]){return $false}}
    if($Proof.retained_descendant_identities-isnot[System.Array]-or$Proof.unowned_godot_identities-isnot[System.Array]-or$Proof.baseline_godot_identity_keys-isnot[System.Array]-or$Proof.setup_cleanup_error-isnot[string]-or$Proof.process_kind-isnot[string]-or$Proof.provenance-isnot[string]-or$Proof.launched_image_path-isnot[string]){return $false}
    foreach($collection in @($Proof.retained_descendant_identities,$Proof.unowned_godot_identities)){foreach($identity in @($collection)){if(-not(Test-ProcessIdentityProofShape $identity)){return $false}}}
    foreach($key in @($Proof.baseline_godot_identity_keys)){if($key-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$key)){return $false}}
    if(@($Proof.baseline_godot_identity_keys|Sort-Object -Unique).Count-ne@($Proof.baseline_godot_identity_keys).Count){return $false}
    if($null-ne$Proof.executable_pin_receipt-and-not(Test-Q009ExecutablePinReceiptShape $Proof.executable_pin_receipt)){return $false}
    if($null-ne$Proof.executable_pin_release-and-not(Test-Q009ExecutablePinReleaseReceiptShape $Proof.executable_pin_release)){return $false}
    $emptyStart=(-not[bool]$Proof.started-and-not[bool]$Proof.start_observed-and-not[bool]$Proof.process_id_observed-and-not[bool]$Proof.process_start_time_observed-and-not[bool]$Proof.process_name_observed-and-not[bool]$Proof.root_handle_cleanup_succeeded-and-not[bool]$Proof.job_assignment_succeeded-and-not[bool]$Proof.job_accounting_succeeded-and-not[bool]$Proof.job_cleanup_succeeded-and[int]$Proof.job_pretermination_active_process_count-eq-1-and[int]$Proof.job_pretermination_membership_count-eq-1-and[int]$Proof.job_final_active_process_count-eq-1-and-not[bool]$Proof.job_final_membership_empty-and-not[bool]$Proof.identity_ambiguity-and[int]$Proof.process_id-eq0-and$null-eq$Proof.process_identity-and-not[bool]$Proof.identity_capture_complete-and$null-eq$Proof.observed_start-and@($Proof.retained_descendant_identities).Count-eq0-and@($Proof.unowned_godot_identities).Count-eq0-and@($Proof.baseline_godot_identity_keys).Count-eq0-and[string]$Proof.setup_cleanup_error-ceq''-and[string]$Proof.process_kind-ceq''-and[string]$Proof.provenance-ceq'none'-and[string]$Proof.launched_image_path-ceq''-and$null-eq$Proof.executable_pin_receipt-and$null-eq$Proof.executable_pin_release)
    if(-not[bool]$Proof.receipt_valid){return $AllowInvalid-and-not[string]::IsNullOrWhiteSpace([string]$Proof.validation_error)-and$emptyStart}
    if(-not[string]::IsNullOrEmpty([string]$Proof.validation_error)){return $false}
    if(-not[bool]$Proof.started){return $emptyStart}
    if(-not[bool]$Proof.start_observed-or[int]$Proof.process_id-le0-or[string]$Proof.process_kind-notin@('Godot','Python','Exact')-or[string]$Proof.provenance-notin@('start_setup_exception','start_before_identity_exception')-or-not(Test-Q009ObservedStartReceiptShape $Proof.observed_start)){return $false}
    if($null-eq$Proof.executable_pin_receipt-or$null-eq$Proof.executable_pin_release-or-not[string]::Equals([string]$Proof.launched_image_path,[string]$Proof.executable_pin_receipt.final_path,[StringComparison]::OrdinalIgnoreCase)){return $false}
    if([bool]$Proof.identity_capture_complete){if(-not(Test-ProcessIdentityProofShape $Proof.process_identity)-or[int]$Proof.process_id-ne[int]$Proof.process_identity.pid-or[string]$Proof.provenance-cne'start_setup_exception'){return $false}}
    elseif($null-ne$Proof.process_identity-and-not(Test-ProcessIdentityProofShape $Proof.process_identity)){return $false}
    return $true
}

function Test-Q009CompletionResultShape {
    param([AllowNull()][object]$Receipt)
    $keys=@(
        'process_started','process_start_provenance','native_exit_source','native_exit_code',
        'native_exit_observed','native_exit_type','effective_exit_code','timed_out',
        'elapsed_seconds','process_id','started_utc','process_identity',
        'job_assignment_succeeded','job_accounting_succeeded','job_cleanup_succeeded',
        'job_pretermination_active_process_count','job_pretermination_membership_count',
        'job_final_active_process_count','job_final_membership_empty',
        'retained_descendant_identities','launched_image_path','executable_pin_receipt',
        'executable_pin_release','executable_pin_clean','stdout_identity','stderr_identity',
        'owned_artifact_manifests','error'
    )
    if(-not(Test-Q009ExactPublicReceiptKeys $Receipt $keys)){return $false}
    foreach($name in @('process_started','native_exit_observed','timed_out','job_assignment_succeeded','job_accounting_succeeded','job_cleanup_succeeded','job_final_membership_empty','executable_pin_clean')){
        if($Receipt.$name-isnot[bool]){return $false}
    }
    foreach($name in @('native_exit_code','effective_exit_code','process_id','job_pretermination_active_process_count','job_pretermination_membership_count','job_final_active_process_count')){
        if($Receipt.$name-isnot[int]){return $false}
    }
    foreach($name in @('process_start_provenance','native_exit_source','native_exit_type','started_utc','launched_image_path','error')){
        if($Receipt.$name-isnot[string]){return $false}
    }
    if($Receipt.elapsed_seconds-isnot[double]-or[double]$Receipt.elapsed_seconds-lt0-or
        -not[bool]$Receipt.process_started-or[string]$Receipt.process_start_provenance-cne'completed'-or
        [int]$Receipt.process_id-le0-or-not(Test-Q009ExactRoundtripTimestamp $Receipt.started_utc)-or
        -not(Test-ProcessIdentityProofShape $Receipt.process_identity)-or[int]$Receipt.process_id-ne[int]$Receipt.process_identity.pid-or
        $Receipt.retained_descendant_identities-isnot[System.Array]-or$Receipt.owned_artifact_manifests-isnot[System.Array]-or
        [string]::IsNullOrWhiteSpace([string]$Receipt.launched_image_path)-or
        -not(Test-Q009ExecutablePinReceiptShape $Receipt.executable_pin_receipt)-or
        -not(Test-Q009ExecutablePinReleaseReceiptShape $Receipt.executable_pin_release)-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.stdout_identity)-or[bool]$Receipt.stdout_identity.is_directory-or
        -not(Test-Q009FileSystemIdentityShape $Receipt.stderr_identity)-or[bool]$Receipt.stderr_identity.is_directory-or
        -not[bool]$Receipt.executable_pin_clean){return $false}
    foreach($identity in @($Receipt.retained_descendant_identities)){if(-not(Test-ProcessIdentityProofShape $identity)){return $false}}
    $artifactRoles=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($artifact in @($Receipt.owned_artifact_manifests)){
        if(-not(Test-Q009ClosedArtifactManifestReceiptShape $artifact $null $Receipt.process_identity)-or-not$artifactRoles.Add([string]$artifact.role)){return $false}
    }
    if(-not[string]::Equals([IO.Path]::GetFullPath([string]$Receipt.launched_image_path),[IO.Path]::GetFullPath([string]$Receipt.executable_pin_receipt.final_path),[StringComparison]::OrdinalIgnoreCase)){return $false}
    if([bool]$Receipt.native_exit_observed){
        if([string]$Receipt.native_exit_source-cne'owned_native_process_handle'-or[string]$Receipt.native_exit_type-cne'System.Int32'){return $false}
    }elseif([string]$Receipt.native_exit_source-cne'owned_native_process_handle'-or[string]$Receipt.native_exit_type-cne''){
        return $false
    }
    if([bool]$Receipt.timed_out){if([int]$Receipt.effective_exit_code-ne124){return $false}}
    elseif([bool]$Receipt.native_exit_observed-and[int]$Receipt.effective_exit_code-ne[int]$Receipt.native_exit_code-and[string]::IsNullOrWhiteSpace([string]$Receipt.error)){
        return $false
    }
    return $true
}

function New-Q009MissingStartProof {
    param([bool]$Valid=$true,[string]$ValidationError='')
    $result=[ordered]@{
        receipt_valid=[bool]$Valid;validation_error=[string]$ValidationError
        started = $false
        start_observed = $false
        process_id_observed = $false
        process_start_time_observed = $false
        process_name_observed = $false
        root_handle_cleanup_succeeded = $false
        job_assignment_succeeded = $false
        job_accounting_succeeded = $false
        job_cleanup_succeeded = $false
        job_pretermination_active_process_count = -1
        job_pretermination_membership_count = -1
        job_final_active_process_count = -1
        job_final_membership_empty = $false
        identity_ambiguity = $false
        process_id = 0
        process_identity = $null
        identity_capture_complete = $false
        observed_start = $null
        retained_descendant_identities = @()
        unowned_godot_identities = @()
        baseline_godot_identity_keys = @()
        setup_cleanup_error = ''
        process_kind = ''
        provenance = 'none'
        launched_image_path = ''
        executable_pin_receipt = $null
        executable_pin_release = $null
    }
    if(-not(Test-Q009StartProofShape $result -AllowInvalid)){throw 'Missing-start receipt construction failed its exact closed schema'}
    return $result
}

function Get-OwnedProcessStartProofFromException {
    param([System.Exception]$Exception)
    if($null-eq$Exception-or-not$Exception.Data.Contains('owned_start_proof_receipt')){return New-Q009MissingStartProof $false 'exception omitted the exact owned_start_proof_receipt'}
    $proof=$Exception.Data['owned_start_proof_receipt']
    if(-not(Test-Q009StartProofShape $proof -AllowInvalid)){return New-Q009MissingStartProof $false 'exception owned_start_proof_receipt failed its exact closed schema'}
    return $proof
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

function Resolve-VerifiedDescendantIdentityRecords {
    param(
        [object]$RootIdentity,
        [long]$OwnershipEndTicks,
        [string[]]$BaselineIdentityKeys,
        [object[]]$Candidates
    )
    $rootPid = [int]$RootIdentity.pid
    $rootKey = [string]$RootIdentity.key
    $rootStartTicks = [long]$RootIdentity.start_ticks
    if ($rootPid -le 0 -or [string]::IsNullOrWhiteSpace($rootKey) -or $rootStartTicks -le 0 -or $OwnershipEndTicks -lt $rootStartTicks) {
        return @()
    }
    $verifiedIdentityByKey = @{}
    $verifiedIdentityByKey[$rootKey] = $RootIdentity
    $records = [System.Collections.Generic.List[object]]::new()
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($candidate in @($Candidates)) {
            $record = $candidate.identity
            $recordKey = [string]$record.key
            $pidValue = [int]$record.pid
            $parentPid = [int]$candidate.parent_pid
            $parentIdentity = $candidate.parent_identity
            if ($null -eq $parentIdentity) { continue }
            $parentKey = [string]$parentIdentity.key
            if (
                $pidValue -le 0 `
                -or $pidValue -eq $rootPid `
                -or [string]::IsNullOrWhiteSpace($recordKey) `
                -or $verifiedIdentityByKey.ContainsKey($recordKey) `
                -or -not $verifiedIdentityByKey.ContainsKey($parentKey) `
                -or $BaselineIdentityKeys -contains $recordKey
            ) { continue }
            $verifiedParent = $verifiedIdentityByKey[$parentKey]
            if (
                $parentPid -ne [int]$parentIdentity.pid `
                -or $parentPid -ne [int]$verifiedParent.pid `
                -or [string]$parentIdentity.key -cne [string]$verifiedParent.key `
                -or [long]$parentIdentity.start_ticks -ne [long]$verifiedParent.start_ticks `
                -or [string]$parentIdentity.name -cne [string]$verifiedParent.name
            ) { continue }
            $parentStartTicks = [long]$verifiedParent.start_ticks
            $recordStartTicks = [long]$record.start_ticks
            if ($recordStartTicks -lt $rootStartTicks -or $recordStartTicks -lt $parentStartTicks -or $recordStartTicks -gt $OwnershipEndTicks) { continue }
            if (-not (Test-CimCreationMatchesProcessStartTicks -CreationTicks ([long]$candidate.creation_ticks) -ProcessStartTicks $recordStartTicks)) { continue }
            $verifiedIdentityByKey[$recordKey] = $record
            [void]$records.Add($record)
            $changed = $true
        }
    }
    return @($records)
}

function Get-VerifiedDescendantProcessRecords {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [AllowNull()][object]$RootExitTimeUtc = $null,
        [switch]$ForceEnumerationFailureForTest
    )
    if (-not (Test-ProcessIdentityProofShape -Identity $RootIdentity)) { return @() }
    $rootLiveAtStart = Test-LiveProcessMatchesIdentity -ExpectedIdentity $RootIdentity
    if (-not $rootLiveAtStart -and $null -eq $RootExitTimeUtc) { return @() }
    $all = @(Get-CimProcessSnapshotStrict -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)
    # First narrow the immutable CIM snapshot by numeric ancestry.  Exact
    # identity/key and creation-time checks below still make the admission
    # decision; this prefilter avoids probing protected unrelated processes.
    $rawParentByPid = @{}
    foreach ($entry in $all) { $rawParentByPid[[int]$entry.ProcessId] = [int]$entry.ParentProcessId }
    $potentialEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $all) {
        $cursor = [int]$entry.ParentProcessId
        $seen = [System.Collections.Generic.HashSet[int]]::new()
        $reachesRoot = $false
        for ($depth = 0; $depth -lt 64; $depth += 1) {
            if ($cursor -eq [int]$RootIdentity.pid) { $reachesRoot = $true; break }
            if ($cursor -le 0 -or -not $seen.Add($cursor) -or -not $rawParentByPid.ContainsKey($cursor)) { break }
            $cursor = [int]$rawParentByPid[$cursor]
        }
        if ($reachesRoot) { [void]$potentialEntries.Add($entry) }
    }
    $ownershipEndTicks = if ($null -eq $RootExitTimeUtc) { [long]([DateTime]::UtcNow.Ticks) } else { [long]([datetime]$RootExitTimeUtc).ToUniversalTime().Ticks }
    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($potentialEntries)) {
        $pidValue = [int]$entry.ProcessId
        $parentPid = [int]$entry.ParentProcessId
        $record = Get-ProcessIdentityOrNullIfExited -ProcessId $pidValue
        if ($null -eq $record) { continue }
        try {
            $parentIdentity = $null
            if ($parentPid -eq [int]$RootIdentity.pid) {
                # The exact root identity came from our owned process handle.
                # Its observed exit bound disambiguates a later PID reuse.
                $parentIdentity = $RootIdentity
            }
            else {
                $parentIdentity = Get-ProcessIdentityOrNullIfExited -ProcessId $parentPid
                if ($null -eq $parentIdentity) { continue }
                if (-not (Test-ProcessIdentityProofShape -Identity $parentIdentity)) { continue }
            }
            $creationValue = $entry.CreationDate
            $creationUtc = ([datetime]$creationValue).ToUniversalTime()
            [void]$candidates.Add([ordered]@{
                parent_pid = $parentPid
                parent_identity = $parentIdentity
                creation_ticks = [long]$creationUtc.Ticks
                identity = $record
            })
        }
        catch {
            throw "Verified descendant census failed closed for PID $pidValue`: $($_.Exception.Message)"
        }
    }
    if ($null -eq $RootExitTimeUtc -and -not (Test-LiveProcessMatchesIdentity -ExpectedIdentity $RootIdentity)) {
        # Root ownership changed during the census. A caller may retry with the
        # exact observed ExitTime, which bounds post-exit lineage safely.
        return @()
    }
    return @(Resolve-VerifiedDescendantIdentityRecords -RootIdentity $RootIdentity -OwnershipEndTicks $ownershipEndTicks -BaselineIdentityKeys $BaselineIdentityKeys -Candidates @($candidates))
}

function Stop-ExactStartedProcess {
    param(
        [System.Diagnostics.Process]$Process,
        [object]$ProcessIdentity
    )
    if ($null -eq $Process -or $null -eq $ProcessIdentity) { return }
    $live = Get-ProcessByIdStrict -ProcessId ([int]$ProcessIdentity.pid)
    if ($null -eq $live) { return }
    try {
        $liveIdentity = Get-ProcessIdentityRecord -Process $live
        if ([string]$liveIdentity.key -ceq [string]$ProcessIdentity.key) {
            Stop-Process -InputObject $live -Force -ErrorAction Stop
        }
    }
    catch {
        if ($null -ne (Get-ProcessByIdStrict -ProcessId ([int]$ProcessIdentity.pid))) {
            throw "Exact process cleanup failed closed for PID $([int]$ProcessIdentity.pid): $($_.Exception.Message)"
        }
    }
}

function Stop-ExactIdentityRecords {
    param([object[]]$IdentityRecords)
    foreach ($record in @($IdentityRecords | Sort-Object { [int]$_.pid } -Descending)) {
        if (-not (Test-ProcessIdentityProofShape -Identity $record)) {
            throw 'Exact identity-record cleanup received a malformed identity.'
        }
        $live = Get-ProcessByIdStrict -ProcessId ([int]$record.pid)
        if ($null -ne $live) {
            Stop-ExactStartedProcess -Process $live -ProcessIdentity $record
        }
    }
}

function Get-NewGodotIdentityRecordsStrict {
    param(
        [string[]]$BaselineIdentityKeys,
        [object[]]$OwnedIdentityRecords = @(),
        [switch]$ForceEnumerationFailureForTest
    )
    $ownedKeys = @($OwnedIdentityRecords | Where-Object {
        Test-ProcessIdentityProofShape -Identity $_
    } | ForEach-Object { [string]$_.key })
    return @(Get-LiveGodotIdentityRecords -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest | Where-Object {
        $key = [string]$_.key
        $BaselineIdentityKeys -notcontains $key -and $ownedKeys -notcontains $key
    })
}

function Add-RetainedDescendantProcessRecords {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedRecords,
        [AllowNull()][object]$RootExitTimeUtc = $null,
        [switch]$ForceEnumerationFailureForTest
    )
    if ($null -eq $RootIdentity -or $null -eq $RetainedRecords) { return }
    $knownKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($record in @($RetainedRecords)) {
        [void]$knownKeys.Add([string]$record.key)
    }
    foreach ($record in @(Get-VerifiedDescendantProcessRecords -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RootExitTimeUtc $RootExitTimeUtc -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)) {
        if ($knownKeys.Add([string]$record.key)) {
            [void]$RetainedRecords.Add($record)
        }
    }
}

function Add-RetainedDescendantRecordsFromLiveRootHandle {
    param(
        [System.Diagnostics.Process]$RootProcess,
        [int]$ObservedProcessId,
        [datetime]$LaunchLowerUtc,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedRecords,
        [switch]$ForceEnumerationFailureForTest
    )
    if ($null -eq $RootProcess -or $ObservedProcessId -le 0 -or $LaunchLowerUtc -eq [datetime]::MinValue) { return }
    $RootProcess.Refresh()
    if ($RootProcess.HasExited -or [int]$RootProcess.Id -ne $ObservedProcessId) {
        throw 'The launch-bound root handle was not live while provisional descendant custody was established.'
    }
    $snapshot = @(Get-CimProcessSnapshotStrict -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)
    $rootEntries = @($snapshot | Where-Object { [int]$_.ProcessId -eq $ObservedProcessId })
    if ($rootEntries.Count -ne 1) { throw 'The live launch-bound root did not have exactly one CIM identity.' }
    $rootCreationTicks = [long]([datetime]$rootEntries[0].CreationDate).ToUniversalTime().Ticks
    $lowerTicks = [long]$LaunchLowerUtc.ToUniversalTime().Ticks
    $lowerRepresentableTicks = $lowerTicks - ($lowerTicks % 10)
    $ownershipEndTicks = [long][datetime]::UtcNow.Ticks
    if ($rootCreationTicks -lt $lowerRepresentableTicks -or $rootCreationTicks -gt $ownershipEndTicks) {
        throw 'The live root CIM creation time was outside the launch-bound lifetime.'
    }

    $rawParentByPid = @{}
    foreach ($entry in $snapshot) { $rawParentByPid[[int]$entry.ProcessId] = [int]$entry.ParentProcessId }
    $potentialEntries = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $snapshot) {
        $cursor = [int]$entry.ParentProcessId
        $seen = [System.Collections.Generic.HashSet[int]]::new()
        $reachesRoot = $false
        for ($depth = 0; $depth -lt 64; $depth += 1) {
            if ($cursor -eq $ObservedProcessId) { $reachesRoot = $true; break }
            if ($cursor -le 0 -or -not $seen.Add($cursor) -or -not $rawParentByPid.ContainsKey($cursor)) { break }
            $cursor = [int]$rawParentByPid[$cursor]
        }
        if ($reachesRoot) { [void]$potentialEntries.Add($entry) }
    }

    $verifiedByKey = @{}
    $verifiedByPid = @{}
    $knownKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($record in @($RetainedRecords)) {
        if (Test-ProcessIdentityProofShape $record) {
            $verifiedByKey[[string]$record.key] = $record
            $verifiedByPid[[int]$record.pid] = $record
            [void]$knownKeys.Add([string]$record.key)
        }
    }
    $pending = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($potentialEntries)) {
        $pidValue = [int]$entry.ProcessId
        $record = Get-ProcessIdentityOrNullIfExited -ProcessId $pidValue
        if ($null -eq $record -or -not (Test-ProcessIdentityProofShape $record)) { continue }
        $creationTicks = [long]([datetime]$entry.CreationDate).ToUniversalTime().Ticks
        if (-not (Test-CimCreationMatchesProcessStartTicks $creationTicks ([long]$record.start_ticks))) { continue }
        if ([long]$record.start_ticks -lt $rootCreationTicks -or [long]$record.start_ticks -gt $ownershipEndTicks) { continue }
        [void]$pending.Add([ordered]@{
            parent_pid = [int]$entry.ParentProcessId
            identity = $record
        })
    }
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($candidate in @($pending)) {
            $record = $candidate.identity
            $recordKey = [string]$record.key
            if ($knownKeys.Contains($recordKey) -or $BaselineIdentityKeys -contains $recordKey) { continue }
            $parentPid = [int]$candidate.parent_pid
            $parentVerified = $false
            if ($parentPid -eq $ObservedProcessId) {
                $parentVerified = $true
            }
            elseif ($verifiedByPid.ContainsKey($parentPid)) {
                $liveParent = Get-ProcessIdentityOrNullIfExited -ProcessId $parentPid
                $expectedParent = $verifiedByPid[$parentPid]
                $parentVerified = $null -ne $liveParent -and [string]$liveParent.key -ceq [string]$expectedParent.key -and [long]$record.start_ticks -ge [long]$expectedParent.start_ticks
            }
            if (-not $parentVerified) { continue }
            $verifiedByKey[$recordKey] = $record
            $verifiedByPid[[int]$record.pid] = $record
            [void]$knownKeys.Add($recordKey)
            [void]$RetainedRecords.Add($record)
            $changed = $true
        }
    }
    $RootProcess.Refresh()
    if ($RootProcess.HasExited -or [int]$RootProcess.Id -ne $ObservedProcessId) {
        throw 'The launch-bound root exited or changed identity during provisional descendant custody.'
    }
}

function Add-RetainedOwnedJobProcessRecords {
    param(
        [BeatTheHouse.Q009.OwnedJobProcess]$JobProcess,
        [AllowNull()][object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedRecords,
        [switch]$ForceAccountingFailureForTest
    )
    if ($null -eq $JobProcess -or $null -eq $RetainedRecords) {
        throw 'Owned Job Object membership accounting lacked its live context or retention list.'
    }
    if ($ForceAccountingFailureForTest) {
        throw 'Forced owned Job Object accounting failure for hostile validation.'
    }
    $before = @($JobProcess.GetActiveProcessIds())
    $activeBefore = [uint32]$JobProcess.GetActiveProcessCount()
    if ($activeBefore -ne $before.Count) {
        # Membership can legitimately change between the two kernel queries.
        # Retry once as a bounded coherent snapshot; continued churn is an
        # ambiguity and therefore fails closed.
        $before = @($JobProcess.GetActiveProcessIds())
        $activeBefore = [uint32]$JobProcess.GetActiveProcessCount()
        if ($activeBefore -ne $before.Count) {
            throw 'Owned Job Object membership and active-process accounting did not converge.'
        }
    }
    $knownKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($record in @($RetainedRecords)) {
        if (-not (Test-ProcessIdentityProofShape -Identity $record)) {
            throw 'Owned Job Object retained a malformed exact process identity.'
        }
        [void]$knownKeys.Add([string]$record.key)
    }
    foreach ($memberPid in $before) {
        if ($null -ne $RootIdentity -and [int]$memberPid -eq [int]$RootIdentity.pid) { continue }
        $identity = Get-ProcessIdentityOrNullIfExited -ProcessId ([int]$memberPid)
        if ($null -eq $identity) { continue }
        $after = @($JobProcess.GetActiveProcessIds())
        if ($after -notcontains [int]$memberPid) {
            # The job member exited between membership and identity reads.  A
            # recycled external PID is not admitted merely because it has the
            # same number.
            continue
        }
        if ($BaselineIdentityKeys -contains [string]$identity.key) {
            throw "Owned Job Object unexpectedly contained a baseline process identity: $([string]$identity.key)"
        }
        if ($knownKeys.Add([string]$identity.key)) { [void]$RetainedRecords.Add($identity) }
    }
    return [ordered]@{
        active_process_count = [uint32]$JobProcess.GetActiveProcessCount()
        member_process_ids = @($JobProcess.GetActiveProcessIds())
    }
}

function Stop-OwnedJobProcessTree {
    param(
        [BeatTheHouse.Q009.OwnedJobProcess]$JobProcess,
        [AllowNull()][object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedDescendantRecords,
        [uint32]$ExitCode = 125
    )
    if ($null -eq $JobProcess) { throw 'Owned Job Object cleanup lacked its exact native context.' }
    if (-not $JobProcess.JobAssigned -or -not $JobProcess.Resumed) {
        throw 'Owned Job Object cleanup refused an unassigned or unresumed launch.'
    }
    $preTermination = Add-RetainedOwnedJobProcessRecords -JobProcess $JobProcess -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedRecords $RetainedDescendantRecords
    $JobProcess.Terminate($ExitCode)
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do {
        [void](Add-RetainedOwnedJobProcessRecords -JobProcess $JobProcess -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedRecords $RetainedDescendantRecords)
        $active = [uint32]$JobProcess.GetActiveProcessCount()
        if ($active -eq 0) { break }
        [System.Threading.Thread]::Sleep(25)
    } while ([DateTime]::UtcNow -lt $deadline)
    $finalActive = [uint32]$JobProcess.GetActiveProcessCount()
    $finalMembers = @($JobProcess.GetActiveProcessIds())
    if ($finalActive -ne 0 -or $finalMembers.Count -ne 0) {
        throw "Owned Job Object retained active members after termination: active=$finalActive members=$($finalMembers -join ',')"
    }
    return [ordered]@{
        terminated = $true
        pretermination_active_process_count = [int]$preTermination.active_process_count
        pretermination_member_process_ids = @($preTermination.member_process_ids)
        active_process_count = 0
        member_process_ids = @()
    }
}

function Stop-ExactStartedProcessTree {
    param(
        [System.Diagnostics.Process]$ConsoleProcess,
        [object]$ConsoleIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedDescendantRecords,
        [AllowNull()][BeatTheHouse.Q009.OwnedJobProcess]$JobProcess = $null
    )
    if ($null -eq $ConsoleProcess -or $null -eq $ConsoleIdentity) { return }
    if ($null -ne $JobProcess) {
        return (Stop-OwnedJobProcessTree -JobProcess $JobProcess -RootIdentity $ConsoleIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedDescendantRecords $RetainedDescendantRecords)
    }
    Add-RetainedDescendantProcessRecords -RootIdentity $ConsoleIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedRecords $RetainedDescendantRecords
    foreach ($record in (@($RetainedDescendantRecords) | Sort-Object { [int]$_.pid } -Descending)) {
        $child = Get-ProcessByIdStrict -ProcessId ([int]$record.pid)
        if ($child) {
            try {
                $currentIdentity = Get-ProcessIdentityRecord -Process $child
                if ([string]$currentIdentity.key -ceq [string]$record.key) {
                    Stop-Process -InputObject $child -Force -ErrorAction Stop
                }
            }
            catch {
                if ($null -ne (Get-ProcessByIdStrict -ProcessId ([int]$record.pid))) {
                    throw "Exact descendant cleanup failed closed for PID $([int]$record.pid): $($_.Exception.Message)"
                }
            }
        }
    }
    $liveConsole = Get-ProcessByIdStrict -ProcessId ([int]$ConsoleIdentity.pid)
    if ($liveConsole) {
        try {
            $currentConsoleIdentity = Get-ProcessIdentityRecord -Process $liveConsole
            if ([string]$currentConsoleIdentity.key -ceq [string]$ConsoleIdentity.key) {
                Stop-Process -InputObject $liveConsole -Force -ErrorAction Stop
            }
        }
        catch {
            if ($null -ne (Get-ProcessByIdStrict -ProcessId ([int]$ConsoleIdentity.pid))) {
                throw "Exact console cleanup failed closed for PID $([int]$ConsoleIdentity.pid): $($_.Exception.Message)"
            }
        }
    }
}

function Get-ExactOwnedProcessResidualPids {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedDescendantRecords,
        [switch]$ForceEnumerationFailureForTest
    )
    if ($null -eq $RootIdentity -or [int]$RootIdentity.pid -le 0) { return @() }
    $residuals = [System.Collections.Generic.List[int]]::new()
    if (Test-LiveProcessMatchesIdentity -ExpectedIdentity $RootIdentity) {
        $residuals.Add([int]$RootIdentity.pid)
    }
    Add-RetainedDescendantProcessRecords -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedRecords $RetainedDescendantRecords -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest
    foreach ($record in @($RetainedDescendantRecords)) {
        $child = Get-ProcessByIdStrict -ProcessId ([int]$record.pid)
        if ($child) {
            try {
                $currentIdentity = Get-ProcessIdentityRecord -Process $child
                if ([string]$currentIdentity.key -ceq [string]$record.key) {
                    $residuals.Add([int]$record.pid)
                }
            }
            catch {
                if ($null -ne (Get-ProcessByIdStrict -ProcessId ([int]$record.pid))) {
                    throw "Exact residual identity census failed closed for PID $([int]$record.pid): $($_.Exception.Message)"
                }
            }
        }
    }
    return @($residuals | Sort-Object -Unique)
}

function Get-ExactOwnedGodotResidualPids {
    param(
        [object]$RootIdentity,
        [string[]]$BaselineIdentityKeys,
        [System.Collections.Generic.List[object]]$RetainedDescendantRecords,
        [switch]$ForceEnumerationFailureForTest
    )
    return @(Get-ExactOwnedProcessResidualPids -RootIdentity $RootIdentity -BaselineIdentityKeys $BaselineIdentityKeys -RetainedDescendantRecords $RetainedDescendantRecords -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)
}

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

function Start-RedirectedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath,
        [ValidateSet('Godot', 'Python', 'Exact')]
        [string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @(),
        [int]$TimeoutSec,
        [switch]$ForceSecondPumpFailureForTest,
        [switch]$ForceFailureImmediatelyAfterStartForTest,
        [switch]$ForceFailureAfterProcessIdForTest,
        [switch]$ForceFailureAfterStartTimeForTest,
        [switch]$ForceFailureAfterProcessNameForTest,
        [switch]$ForceIdentityCaptureFailureForTest,
        [switch]$ForceNativePostWrapperSetupFailureForTest,
        [int]$ForceIdentityCaptureFailureDelayMsecForTest = 0,
        [AllowNull()][object]$ExpectedExecutableIdentity = $null,
        [object]$RunContext
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Redirected process start requires one exact sealed Q-009 run context'}
    if($null-eq$ExpectedExecutableIdentity){throw 'Redirected process start requires a pre-captured exact executable identity; path-only launch is forbidden'}
    $stdoutStream = $null
    $stderrStream = $null
    $stdoutSourceStream = $null
    $stderrSourceStream = $null
    $process = $null
    $jobProcess = $null
    $jobAssignmentSucceeded = $false
    $jobAccountingSucceeded = $false
    $jobCleanupSucceeded = $false
    $jobPreterminationActiveProcessCount = -1
    $jobPreterminationMembershipCount = -1
    $jobFinalActiveProcessCount = -1
    $jobFinalMembershipEmpty = $false
    $processStarted = $false
    $startObserved = $false
    $processIdObserved = $false
    $processStartTimeObserved = $false
    $processNameObserved = $false
    $rootHandleCleanupSucceeded = $false
    $processId = 0
    $processStartTime = [datetime]::MinValue
    $processName = ''
    $processIdentity = $null
    $observedIdentity = $null
    $identityCaptureComplete = $false
    $launchLowerUtc = [DateTime]::MinValue
    $launchUpperUtc = [DateTime]::MinValue
    $unownedGodotRecords = [System.Collections.Generic.List[object]]::new()
    $setupCleanupError = ''
    $stdoutTask = $null
    $stderrTask = $null
    $stdoutIdentity = $null
    $stderrIdentity = $null
    $retainedDescendantRecords = [System.Collections.Generic.List[object]]::new()
    $executablePin = $null
    $executablePinRelease = $null
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $stdoutStream = [System.IO.FileStream]::new($StdoutPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $stderrStream = [System.IO.FileStream]::new($StderrPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $stdoutIdentity=Get-Q009FileSystemEntryIdentity $StdoutPath
        $stderrIdentity=Get-Q009FileSystemEntryIdentity $StderrPath
        if([bool]$stdoutIdentity.is_directory-or[bool]$stderrIdentity.is_directory){throw 'Redirect channels were not exact ordinary files before process launch'}
        $nativeCommandLine = (ConvertTo-WindowsCommandLineArgument -Value $FilePath)
        if (@($Arguments).Count -gt 0) { $nativeCommandLine += ' ' + (Join-ProcessArguments -Arguments $Arguments) }
        $resolvedExecutable=[IO.Path]::GetFullPath($FilePath)
        $executablePin=New-Q009ExecutablePin -Path $resolvedExecutable -AttemptId ([string]$RunContext.attempt_id) -ExpectedExecutableIdentity $ExpectedExecutableIdentity
        # Every ancestor plus the executable leaf deny delete sharing, and the
        # leaf denies write sharing, through the suspended CreateProcess, Job
        # assignment, resume, execution, and terminal verification sequence.
        $jobProcess = [BeatTheHouse.Q009.NativeJobLauncher]::Start($resolvedExecutable, $nativeCommandLine, [string]$RunContext.working_directory, [bool]$ForceNativePostWrapperSetupFailureForTest)
        if(-not[string]::Equals([string]$jobProcess.LaunchedImagePath,[string]$executablePin.receipt.final_path,[StringComparison]::OrdinalIgnoreCase)){throw 'Suspended owned process image did not bind to the exact full-chain executable pin'}
        $process = $jobProcess.Process
        $stdoutSourceStream = $jobProcess.StandardOutput
        $stderrSourceStream = $jobProcess.StandardError
        $processStarted = $true
        $startObserved = $true
        $jobAssignmentSucceeded = [bool]$jobProcess.JobAssigned
        if (-not $jobAssignmentSucceeded -or -not [bool]$jobProcess.Resumed) {
            throw 'Atomic owned Job Object launch did not prove assignment before resume.'
        }
        $launchLowerUtc = $jobProcess.LaunchLowerUtc
        $launchUpperUtc = $jobProcess.LaunchUpperUtc
        if ($ForceFailureImmediatelyAfterStartForTest) {
            if ($ForceIdentityCaptureFailureDelayMsecForTest -gt 0) { [System.Threading.Thread]::Sleep($ForceIdentityCaptureFailureDelayMsecForTest) }
            throw 'Forced failure immediately after Process.Start before reading Process.Id.'
        }
        $processId = [int]$jobProcess.ProcessId
        if([int]$process.Id-ne$processId){throw 'Managed process wrapper PID drifted from the exact native root handle.'}
        $processIdObserved = $true
        if ($ForceFailureAfterProcessIdForTest) {
            if ($ForceIdentityCaptureFailureDelayMsecForTest -gt 0) { [System.Threading.Thread]::Sleep($ForceIdentityCaptureFailureDelayMsecForTest) }
            throw 'Forced failure after Process.Id before reading Process.StartTime.'
        }
        $processStartTime = $jobProcess.RootStartUtc
        $processStartTimeObserved = $true
        if ($ForceFailureAfterStartTimeForTest) {
            if ($ForceIdentityCaptureFailureDelayMsecForTest -gt 0) { [System.Threading.Thread]::Sleep($ForceIdentityCaptureFailureDelayMsecForTest) }
            throw 'Forced failure after Process.StartTime before reading Process.ProcessName.'
        }
        $processName = [string]$jobProcess.RootProcessName
        $processNameObserved = $true
        $observedStartUtc = $processStartTime.ToUniversalTime()
        $observedIdentity = [ordered]@{
            pid = $processId
            name = $processName
            start_utc = $observedStartUtc.ToString('o')
            start_ticks = [long]$observedStartUtc.Ticks
            key = ('{0}|{1}|{2}' -f $processId, $observedStartUtc.Ticks, $processName)
        }
        if ($ForceFailureAfterProcessNameForTest -or $ForceIdentityCaptureFailureForTest) {
            if ($ForceIdentityCaptureFailureDelayMsecForTest -gt 0) {
                [System.Threading.Thread]::Sleep($ForceIdentityCaptureFailureDelayMsecForTest)
            }
            throw 'Forced failure before exact process identity capture for hostile validation.'
        }
        $processIdentity = $observedIdentity
        if(-not(Test-ProcessIdentityProofShape -Identity $processIdentity)){throw 'Suspended native root identity proof was malformed.'}
        $identityCaptureComplete = $true
        # Both pumps must be active before the bounded wait. A verbose Godot
        # failure can fill both native pipes under Windows PowerShell 5.1.
        $stdoutTask = $stdoutSourceStream.CopyToAsync($stdoutStream)
        if ($ForceSecondPumpFailureForTest) {
            if ($ForceIdentityCaptureFailureDelayMsecForTest -gt 0) { [System.Threading.Thread]::Sleep($ForceIdentityCaptureFailureDelayMsecForTest) }
            throw 'Forced second redirect-pump setup failure for hostile validation.'
        }
        $stderrTask = $stderrSourceStream.CopyToAsync($stderrStream)
        # Every launched process kind owns every exact verified descendant, not
        # only Godot-named children. Capture once before returning, then retain
        # delayed descendants throughout the bounded completion loop.
        Add-RetainedDescendantProcessRecords -RootIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords
        [void](Add-RetainedOwnedJobProcessRecords -JobProcess $jobProcess -RootIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords)
        $jobAccountingSucceeded = $true
        if ($ProcessKind -eq 'Godot') {
            # Capture the console child's immutable identity while the exact
            # root is alive and the global launch mutex is still held. Keep
            # sampling during completion as a defense against delayed spawn.
            $initialCaptureDeadline = [DateTime]::UtcNow.AddSeconds(2)
            do {
                Add-RetainedDescendantProcessRecords -RootIdentity $processIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords
                if (@($retainedDescendantRecords | Where-Object { $_.name -in @('Godot_v4.6-stable_win64_console', 'Godot_v4.6-stable_win64') }).Count -gt 0) { break }
                if ($jobProcess.WaitForRootExit(25)) { break }
            } while ([DateTime]::UtcNow -lt $initialCaptureDeadline)
        }
        return [pscustomobject]@{
            process = $process
            process_id = $processId
            process_start_time = $processStartTime
            process_identity = $processIdentity
            launch_lower_utc = $launchLowerUtc
            launch_upper_utc = $launchUpperUtc
            job_process = $jobProcess
            job_assignment_succeeded = $jobAssignmentSucceeded
            job_accounting_succeeded = $jobAccountingSucceeded
            retained_descendant_records = $retainedDescendantRecords
            stdout_task = $stdoutTask
            stderr_task = $stderrTask
            stdout_stream = $stdoutStream
            stderr_stream = $stderrStream
            stopwatch = $stopwatch
            deadline_utc = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
            file_path = $FilePath
            arguments = @($Arguments)
            launched_image_path = [string]$jobProcess.LaunchedImagePath
            executable_pin = $executablePin
            stdout_identity = $stdoutIdentity
            stderr_identity = $stderrIdentity
        }
    }
    catch {
        $startException = $_.Exception
        # PowerShell wraps static .NET invocation failures in one or more
        # MethodInvocationException/TargetInvocationException layers. Preserve
        # the native launcher's exact setup-cleanup proof from the first inner
        # exception that owns it, then publish the normalized proof on the
        # outer exception that callers actually receive.
        $nativeStartException = $startException
        while ($null -ne $nativeStartException -and
                -not $nativeStartException.Data.Contains('native_process_created') -and
                $null -ne $nativeStartException.InnerException) {
            $nativeStartException = $nativeStartException.InnerException
        }
        $nativeStartData = if ($null -ne $nativeStartException) { $nativeStartException.Data } else { $null }
        if (-not $processStarted -and $null -ne $nativeStartData -and $nativeStartData.Contains('native_process_created') -and [bool]$nativeStartData['native_process_created']) {
            $processStarted = $true
            $startObserved = $true
            $processId = if ($nativeStartData.Contains('native_process_id')) { [int]$nativeStartData['native_process_id'] } else { 0 }
            $jobAssignmentSucceeded = $nativeStartData.Contains('native_job_assigned') -and [bool]$nativeStartData['native_job_assigned']
            $jobAccountingSucceeded = $nativeStartData.Contains('native_job_accounting_succeeded') -and [bool]$nativeStartData['native_job_accounting_succeeded']
            $jobCleanupSucceeded = $nativeStartData.Contains('native_cleanup_succeeded') -and [bool]$nativeStartData['native_cleanup_succeeded']
            $rootHandleCleanupSucceeded = $jobCleanupSucceeded
            $jobPreterminationActiveProcessCount = if ($nativeStartData.Contains('native_job_pretermination_active_process_count')) { [int]$nativeStartData['native_job_pretermination_active_process_count'] } else { -1 }
            $jobPreterminationMembershipCount = if ($nativeStartData.Contains('native_job_pretermination_membership_count')) { [int]$nativeStartData['native_job_pretermination_membership_count'] } else { -1 }
            $jobFinalActiveProcessCount = if ($nativeStartData.Contains('native_job_final_active_process_count')) { [int]$nativeStartData['native_job_final_active_process_count'] } else { -1 }
            $jobFinalMembershipEmpty = $nativeStartData.Contains('native_job_final_membership_count') -and [int]$nativeStartData['native_job_final_membership_count'] -eq 0
        }
        $startException.Data['owned_process_start_observed'] = [bool]$startObserved
        $startException.Data['owned_process_id'] = [int]$processId
        $startException.Data['owned_process_id_observed'] = [bool]$processIdObserved
        $startException.Data['owned_process_start_time_observed'] = [bool]$processStartTimeObserved
        $startException.Data['owned_process_name_observed'] = [bool]$processNameObserved
        $bestIdentity = if (Test-ProcessIdentityProofShape -Identity $processIdentity) { $processIdentity } elseif (Test-ProcessIdentityProofShape -Identity $observedIdentity) { $observedIdentity } else { $null }
        if ($null -ne $bestIdentity) {
            $startException.Data['owned_process_identity'] = $bestIdentity
        }
        $startException.Data['owned_identity_capture_complete'] = [bool]$identityCaptureComplete
        $startException.Data['owned_observed_start'] = [ordered]@{
            process_id = [int]$processId
            process_name = [string]$processName
            launch_lower_utc = if ($launchLowerUtc -eq [DateTime]::MinValue) { '' } else { $launchLowerUtc.ToString('o') }
            launch_lower_ticks = if ($launchLowerUtc -eq [DateTime]::MinValue) { [long]0 } else { [long]$launchLowerUtc.Ticks }
            launch_upper_utc = if ($launchUpperUtc -eq [DateTime]::MinValue) { '' } else { $launchUpperUtc.ToString('o') }
            launch_upper_ticks = if ($launchUpperUtc -eq [DateTime]::MinValue) { [long]0 } else { [long]$launchUpperUtc.Ticks }
            process_start_utc = if ($processStartTime -eq [DateTime]::MinValue) { '' } else { $processStartTime.ToUniversalTime().ToString('o') }
            process_start_ticks = if ($processStartTime -eq [DateTime]::MinValue) { [long]0 } else { [long]$processStartTime.ToUniversalTime().Ticks }
        }
        $startException.Data['owned_process_kind'] = $ProcessKind
        $startException.Data['owned_baseline_godot_identity_keys'] = @($BaselineGodotIdentityKeys)
        $startException.Data['owned_job_assignment_succeeded'] = [bool]$jobAssignmentSucceeded
        if ($processStarted -and $null -ne $process) {
            try {
                if ($null -ne $jobProcess) {
                    [void](Add-RetainedOwnedJobProcessRecords -JobProcess $jobProcess -RootIdentity $bestIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords)
                    $jobAccountingSucceeded = $true
                }
                elseif ($null -ne $bestIdentity) {
                    # Capture exact descendants before terminating the owned
                    # root.  This applies to Exact probes as well as Godot so a
                    # child spawned just before identity setup failed remains
                    # in custody.
                    Add-RetainedDescendantProcessRecords -RootIdentity $bestIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords
                }
                elseif ($processIdObserved) {
                    # Process.Start and the still-live direct handle prove this
                    # numeric PID belongs to our launch even when later identity
                    # property reads failed. Bind children while that handle is
                    # live; never convert the partial root into PID-only kill
                    # authority.
                    Add-RetainedDescendantRecordsFromLiveRootHandle -RootProcess $process -ObservedProcessId $processId -LaunchLowerUtc $launchLowerUtc -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords
                }
                if ($null -ne $jobProcess) {
                    $jobCleanupEvidence = Stop-OwnedJobProcessTree -JobProcess $jobProcess -RootIdentity $bestIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $retainedDescendantRecords
                    $jobCleanupSucceeded = $true
                    $jobPreterminationActiveProcessCount = [int]$jobCleanupEvidence.pretermination_active_process_count
                    $jobPreterminationMembershipCount = @($jobCleanupEvidence.pretermination_member_process_ids).Count
                    $jobFinalActiveProcessCount = [int]$jobProcess.GetActiveProcessCount()
                    $jobFinalMembershipEmpty = @($jobProcess.GetActiveProcessIds()).Count -eq 0
                }
                else {
                    Stop-ExactIdentityRecords -IdentityRecords @($retainedDescendantRecords)
                }
            }
            catch {
                $setupCleanupError = "pre-root exact-tree cleanup: $($_.Exception.Message)"
            }
            # The direct process handle is the only safe cleanup authority if
            # identity properties were incomplete.  Never kill by raw PID.
            try {
                if ($null -eq $jobProcess -and -not $process.HasExited) { $process.Kill() }
                $rootExited = if($null-ne$jobProcess){$jobProcess.WaitForRootExit(5000)}else{$process.WaitForExit(5000)}
                if (-not $rootExited) { throw 'owned root did not exit after handle cleanup' }
                $rootHandleCleanupSucceeded = $true
            }
            catch {
                $setupCleanupError = if ($setupCleanupError) { "$setupCleanupError | root handle cleanup: $($_.Exception.Message)" } else { "root handle cleanup: $($_.Exception.Message)" }
            }
            if ($null -ne $bestIdentity) {
                try {
                    $process.Refresh()
                    if ($process.HasExited) {
                        $setupExitTimeUtc = $process.ExitTime.ToUniversalTime()
                        Add-RetainedDescendantProcessRecords -RootIdentity $bestIdentity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $retainedDescendantRecords -RootExitTimeUtc $setupExitTimeUtc
                        Stop-ExactIdentityRecords -IdentityRecords @($retainedDescendantRecords)
                    }
                }
                catch {
                    $setupCleanupError = if ($setupCleanupError) { "$setupCleanupError | post-root exact-tree cleanup: $($_.Exception.Message)" } else { "post-root exact-tree cleanup: $($_.Exception.Message)" }
                }
            }
            if ($ProcessKind -eq 'Godot') {
                try {
                    $ownedForCensus = @($retainedDescendantRecords)
                    if ($null -ne $bestIdentity) { $ownedForCensus = @($bestIdentity) + $ownedForCensus }
                    foreach ($record in @(Get-NewGodotIdentityRecordsStrict -BaselineIdentityKeys $BaselineGodotIdentityKeys -OwnedIdentityRecords $ownedForCensus)) {
                        if (@($unownedGodotRecords | Where-Object { [string]$_.key -ceq [string]$record.key }).Count -eq 0) {
                            [void]$unownedGodotRecords.Add($record)
                        }
                    }
                }
                catch {
                    $setupCleanupError = if ($setupCleanupError) { "$setupCleanupError | unowned Godot census: $($_.Exception.Message)" } else { "unowned Godot census: $($_.Exception.Message)" }
                }
            }
        }
        $startException.Data['owned_retained_descendant_identities'] = @($retainedDescendantRecords)
        $startException.Data['owned_unowned_godot_identities'] = @($unownedGodotRecords)
        $startException.Data['owned_setup_cleanup_error'] = $setupCleanupError
        $startException.Data['owned_root_handle_cleanup_succeeded'] = [bool]$rootHandleCleanupSucceeded
        $startException.Data['owned_identity_ambiguity'] = -not [bool]$identityCaptureComplete
        $startException.Data['owned_job_accounting_succeeded'] = [bool]$jobAccountingSucceeded
        $startException.Data['owned_job_cleanup_succeeded'] = [bool]$jobCleanupSucceeded
        $startException.Data['owned_job_pretermination_active_process_count'] = [int]$jobPreterminationActiveProcessCount
        $startException.Data['owned_job_pretermination_membership_count'] = [int]$jobPreterminationMembershipCount
        $startException.Data['owned_job_final_active_process_count'] = [int]$jobFinalActiveProcessCount
        $startException.Data['owned_job_final_membership_empty'] = [bool]$jobFinalMembershipEmpty
        $startedPumpTasks = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new()
        if ($null -ne $stdoutTask) { [void]$startedPumpTasks.Add($stdoutTask) }
        if ($null -ne $stderrTask) { [void]$startedPumpTasks.Add($stderrTask) }
        if ($startedPumpTasks.Count -gt 0) {
            try { [void][System.Threading.Tasks.Task]::WaitAll($startedPumpTasks.ToArray(), 5000) } catch {}
        }
        if ($null -ne $stdoutStream) { try { $stdoutStream.Flush() } catch {} }
        if ($null -ne $stderrStream) { try { $stderrStream.Flush() } catch {} }
        if ($null -ne $stdoutStream) { try { $stdoutStream.Dispose() } catch {} }
        if ($null -ne $stderrStream) { try { $stderrStream.Dispose() } catch {} }
        if ($null -ne $stdoutSourceStream) { try { $stdoutSourceStream.Dispose() } catch {} }
        if ($null -ne $stderrSourceStream) { try { $stderrSourceStream.Dispose() } catch {} }
        if ($null -ne $jobProcess) {
            try {
                if (-not $jobProcess.JobClosed -and $jobProcess.GetActiveProcessCount() -eq 0) { $jobProcess.CloseVerifiedEmpty() }
            }
            catch {
                $startException.Data['owned_setup_cleanup_error'] = if ($startException.Data['owned_setup_cleanup_error']) { [string]$startException.Data['owned_setup_cleanup_error'] + ' | job close: ' + $_.Exception.Message } else { 'job close: ' + $_.Exception.Message }
                $startException.Data['owned_job_cleanup_succeeded'] = $false
            }
            try { $jobProcess.Dispose() } catch {}
        }
        if ($null -ne $process) { try { $process.Dispose() } catch {} }
        if($null-ne$executablePin-and-not[bool]$executablePin.released){
            try{$executablePinRelease=Close-Q009ExecutablePin $executablePin ([string]$RunContext.attempt_id)}catch{$startException.Data['owned_setup_cleanup_error']=if($startException.Data['owned_setup_cleanup_error']){[string]$startException.Data['owned_setup_cleanup_error']+' | executable pin release: '+$_.Exception.Message}else{'executable pin release: '+$_.Exception.Message}}
        }
        $startException.Data['owned_executable_pin_release']=$executablePinRelease
        $startException.Data['owned_executable_pin_receipt']=if($null-ne$executablePin){$executablePin.receipt}else{$null}
        $nativeLaunchedImage=if($null-ne$jobProcess){[string]$jobProcess.LaunchedImagePath}elseif($null-ne$nativeStartData-and$nativeStartData.Contains('native_launched_image_path')){[string]$nativeStartData['native_launched_image_path']}else{''}
        $startException.Data['owned_launched_image_path']=$nativeLaunchedImage
        $exactStartProof=if(-not$startObserved){
            New-Q009MissingStartProof
        }else{
            [ordered]@{
                receipt_valid=[bool]$true;validation_error=[string]'';started=[bool]$true;start_observed=[bool]$true
                process_id_observed=[bool]$processIdObserved;process_start_time_observed=[bool]$processStartTimeObserved;process_name_observed=[bool]$processNameObserved
                root_handle_cleanup_succeeded=[bool]$rootHandleCleanupSucceeded;job_assignment_succeeded=[bool]$jobAssignmentSucceeded;job_accounting_succeeded=[bool]$jobAccountingSucceeded;job_cleanup_succeeded=[bool]$jobCleanupSucceeded
                job_pretermination_active_process_count=[int]$jobPreterminationActiveProcessCount;job_pretermination_membership_count=[int]$jobPreterminationMembershipCount;job_final_active_process_count=[int]$jobFinalActiveProcessCount;job_final_membership_empty=[bool]$jobFinalMembershipEmpty
                identity_ambiguity=[bool](-not$identityCaptureComplete);process_id=[int]$processId;process_identity=$bestIdentity;identity_capture_complete=[bool]$identityCaptureComplete
                observed_start=$startException.Data['owned_observed_start'];retained_descendant_identities=[object[]]@($retainedDescendantRecords);unowned_godot_identities=[object[]]@($unownedGodotRecords);baseline_godot_identity_keys=[object[]]@($BaselineGodotIdentityKeys)
                setup_cleanup_error=[string]$startException.Data['owned_setup_cleanup_error'];process_kind=[string]$ProcessKind;provenance=if($identityCaptureComplete){[string]'start_setup_exception'}else{[string]'start_before_identity_exception'}
                launched_image_path=[string]$nativeLaunchedImage;executable_pin_receipt=if($null-ne$executablePin){$executablePin.receipt}else{$null};executable_pin_release=$executablePinRelease
            }
        }
        if(-not(Test-Q009StartProofShape $exactStartProof -AllowInvalid)){$exactStartProof=New-Q009MissingStartProof $false 'owned setup exception could not seal one exact closed start-proof receipt'}
        $startException.Data['owned_start_proof_receipt']=$exactStartProof
        $stopwatch.Stop()
        throw
    }
}

function Complete-RedirectedProcess {
    param(
        [pscustomobject]$Started,
        [int]$TimeoutSec,
        [ValidateSet('Godot', 'Python', 'Exact')]
        [string]$ProcessKind,
        [string[]]$BaselineGodotIdentityKeys = @(),
        [object[]]$OwnedArtifactRoots = @(),
        [object]$RunContext
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Redirected completion requires one exact sealed Q-009 run context'}
    $process = $Started.process
    $processId = [int]$Started.process_id
    $timedOut = $false
    $nativeObserved = $false
    $nativeExitCode = [int]$RunContext.native_exit_sentinel
    $effectiveExitCode = 125
    $errorText = ''
    $jobCleanupSucceeded = $false
    $jobPreterminationActiveProcessCount = -1
    $jobPreterminationMembershipCount = -1
    $jobFinalActiveProcessCount = -1
    $jobFinalMembershipEmpty = $false
    $executablePinRelease = $null
    $executablePinClean = $false
    $closedArtifactManifests=[Collections.Generic.List[object]]::new()
    $artifactRequests=@($OwnedArtifactRoots)
    $artifactRoles=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($request in $artifactRequests){
        if(-not(Test-Q009OwnedArtifactRootRequestShape $request)){throw 'Redirected completion received a malformed owned-artifact root request'}
        if(-not$artifactRoles.Add([string]$request.role)){throw 'Redirected completion received duplicate owned-artifact roles'}
    }
    try {
        [void](Assert-Q009ExecutablePinStable $Started.executable_pin ([string]$RunContext.attempt_id))
        if($Started.launched_image_path-isnot[string]-or-not[string]::Equals([string]$Started.launched_image_path,[string]$Started.executable_pin.receipt.final_path,[StringComparison]::OrdinalIgnoreCase)){throw 'Redirected completion lost its exact suspended-image/executable-pin binding'}
        if ($null -eq $Started.job_process -or -not [bool]$Started.job_assignment_succeeded) {
            throw 'Redirected completion lacked its atomically assigned owned Job Object.'
        }
        $exited = $false
        while ([DateTime]::UtcNow -lt $Started.deadline_utc) {
            Add-RetainedDescendantProcessRecords -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records
            [void](Add-RetainedOwnedJobProcessRecords -JobProcess $Started.job_process -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records)
            $remainingMsec = [Math]::Max(1, [int]([DateTime]::UtcNow.Subtract($Started.deadline_utc).Negate().TotalMilliseconds))
            $waitSliceMsec = [Math]::Min(250, $remainingMsec)
            if ($Started.job_process.WaitForRootExit($waitSliceMsec)) {
                $exited = $true
                break
            }
        }
        if (-not $exited) {
            $timedOut = $true
            $jobTerminationEvidence = Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records -JobProcess $Started.job_process
            if($jobPreterminationActiveProcessCount-lt0){$jobPreterminationActiveProcessCount=[int]$jobTerminationEvidence.pretermination_active_process_count;$jobPreterminationMembershipCount=@($jobTerminationEvidence.pretermination_member_process_ids).Count}
            $jobCleanupSucceeded = $true
            if (-not $Started.job_process.WaitForRootExit(5000)) {
                throw 'Timed-out process did not exit after exact-process cleanup.'
            }
        }
        $process.Refresh()
        if (-not $process.HasExited) {
            throw 'Bounded wait returned without a completed process.'
        }
        $rootExitTimeUtc = $process.ExitTime.ToUniversalTime()
        Add-RetainedDescendantProcessRecords -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records -RootExitTimeUtc $rootExitTimeUtc
        [void](Add-RetainedOwnedJobProcessRecords -JobProcess $Started.job_process -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records)
        $jobTerminationEvidence = Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records -JobProcess $Started.job_process
        if($jobPreterminationActiveProcessCount-lt0){$jobPreterminationActiveProcessCount=[int]$jobTerminationEvidence.pretermination_active_process_count;$jobPreterminationMembershipCount=@($jobTerminationEvidence.pretermination_member_process_ids).Count}
        $jobCleanupSucceeded = $true
        $jobFinalActiveProcessCount = [int]$Started.job_process.GetActiveProcessCount()
        $jobFinalMembershipEmpty = @($Started.job_process.GetActiveProcessIds()).Count -eq 0
        $nativeExitCode = Get-StrictNativeExitCode -RawValue $Started.job_process.GetExactExitCode()
        $nativeObserved = $true
        $pumpDeadline = if ($timedOut) { [DateTime]::UtcNow.AddSeconds(5) } else { $Started.deadline_utc }
        $pumpRemainingMsec = [Math]::Max(1, [int]([DateTime]::UtcNow.Subtract($pumpDeadline).Negate().TotalMilliseconds))
        $pumpTasks = [System.Threading.Tasks.Task[]]@($Started.stdout_task, $Started.stderr_task)
        if (-not [System.Threading.Tasks.Task]::WaitAll($pumpTasks, $pumpRemainingMsec)) {
            throw 'Redirected process streams did not drain within the shared deadline.'
        }
        if ($Started.stdout_task.IsFaulted -or $Started.stderr_task.IsFaulted) {
            throw 'A redirected process stream pump faulted.'
        }
        $Started.stdout_stream.Flush()
        $Started.stderr_stream.Flush()
        $effectiveExitCode = if ($timedOut) { 124 } else { $nativeExitCode }
    }
    catch {
        $errorText = $_.Exception.Message
        $effectiveExitCode = if ($timedOut) { 124 } else { 125 }
        $jobTerminationEvidence = Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records -JobProcess $Started.job_process
        if($jobPreterminationActiveProcessCount-lt0){$jobPreterminationActiveProcessCount=[int]$jobTerminationEvidence.pretermination_active_process_count;$jobPreterminationMembershipCount=@($jobTerminationEvidence.pretermination_member_process_ids).Count}
        $jobCleanupSucceeded = $true
        $jobFinalActiveProcessCount = [int]$Started.job_process.GetActiveProcessCount()
        $jobFinalMembershipEmpty = @($Started.job_process.GetActiveProcessIds()).Count -eq 0
        try { [void]$Started.job_process.WaitForRootExit(5000) } catch {}
        try {
            $process.Refresh()
            if ($process.HasExited) {
                $catchExitTimeUtc = $process.ExitTime.ToUniversalTime()
                Add-RetainedDescendantProcessRecords -RootIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedRecords $Started.retained_descendant_records -RootExitTimeUtc $catchExitTimeUtc
                $jobTerminationEvidence = Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records -JobProcess $Started.job_process
                if($jobPreterminationActiveProcessCount-lt0){$jobPreterminationActiveProcessCount=[int]$jobTerminationEvidence.pretermination_active_process_count;$jobPreterminationMembershipCount=@($jobTerminationEvidence.pretermination_member_process_ids).Count}
                $jobCleanupSucceeded = $true
                $jobFinalActiveProcessCount = [int]$Started.job_process.GetActiveProcessCount()
                $jobFinalMembershipEmpty = @($Started.job_process.GetActiveProcessIds()).Count -eq 0
            }
        }
        catch {}
        try {
            $cleanupTasks = [System.Threading.Tasks.Task[]]@($Started.stdout_task, $Started.stderr_task)
            [void][System.Threading.Tasks.Task]::WaitAll($cleanupTasks, 5000)
        }
        catch {}
    }
    finally {
        try {
            $jobTerminationEvidence = Stop-ExactStartedProcessTree -ConsoleProcess $process -ConsoleIdentity $Started.process_identity -BaselineIdentityKeys $BaselineGodotIdentityKeys -RetainedDescendantRecords $Started.retained_descendant_records -JobProcess $Started.job_process
            if($jobPreterminationActiveProcessCount-lt0){$jobPreterminationActiveProcessCount=[int]$jobTerminationEvidence.pretermination_active_process_count;$jobPreterminationMembershipCount=@($jobTerminationEvidence.pretermination_member_process_ids).Count}
            $jobCleanupSucceeded = $true
            $jobFinalActiveProcessCount = [int]$Started.job_process.GetActiveProcessCount()
            $jobFinalMembershipEmpty = @($Started.job_process.GetActiveProcessIds()).Count -eq 0
        }
        catch {
            $jobCleanupSucceeded = $false
            if ([string]::IsNullOrWhiteSpace($errorText)) { $errorText = $_.Exception.Message } else { $errorText += ' | job cleanup: ' + $_.Exception.Message }
        }
        try { $Started.stdout_stream.Flush() } catch {}
        try { $Started.stderr_stream.Flush() } catch {}
        try{
            if(-not(Test-Q009FileSystemIdentityMatch $Started.stdout_identity)-or-not(Test-Q009FileSystemIdentityMatch $Started.stderr_identity)){throw 'owned redirect channel identity drifted before terminal close'}
        }catch{
            $jobCleanupSucceeded=$false
            if([string]::IsNullOrWhiteSpace($errorText)){$errorText='redirect channel custody: '+$_.Exception.Message}else{$errorText+=' | redirect channel custody: '+$_.Exception.Message}
        }
        try { $Started.stdout_stream.Dispose() } catch {}
        try { $Started.stderr_stream.Dispose() } catch {}
        try { $Started.job_process.StandardOutput.Dispose() } catch {}
        try { $Started.job_process.StandardError.Dispose() } catch {}
        try {
            if ($jobCleanupSucceeded -and $Started.job_process.GetActiveProcessCount() -eq 0) {
                $Started.job_process.CloseVerifiedEmpty()
            }
        }
        catch {
            $jobCleanupSucceeded = $false
            if ([string]::IsNullOrWhiteSpace($errorText)) { $errorText = $_.Exception.Message } else { $errorText += ' | job close: ' + $_.Exception.Message }
        }
        try{
            if(-not$jobCleanupSucceeded-or-not$jobFinalMembershipEmpty-or-not$Started.job_process.JobClosed){throw 'Owned artifact manifests require an empty, verified-closed Job Object'}
            foreach($request in $artifactRequests){[void]$closedArtifactManifests.Add((New-Q009ClosedArtifactManifestReceipt $request $RunContext $Started.process_identity))}
        }catch{
            $jobCleanupSucceeded=$false
            if([string]::IsNullOrWhiteSpace($errorText)){$errorText='closed artifact capture: '+$_.Exception.Message}else{$errorText+=' | closed artifact capture: '+$_.Exception.Message}
        }
        try { $Started.job_process.Dispose() } catch {}
        $Started.stopwatch.Stop()
        try { $process.Dispose() } catch {}
        try{
            if($null-ne$Started.executable_pin-and-not[bool]$Started.executable_pin.released){$executablePinRelease=Close-Q009ExecutablePin $Started.executable_pin ([string]$RunContext.attempt_id)}
            $executablePinClean=$null-ne$executablePinRelease-and[bool]$executablePinRelease.released-and[bool]$executablePinRelease.all_terminal
        }catch{
            $executablePinClean=$false
            if([string]::IsNullOrWhiteSpace($errorText)){$errorText='executable pin release: '+$_.Exception.Message}else{$errorText+=' | executable pin release: '+$_.Exception.Message}
        }
    }
    $result=[ordered]@{
        process_started = $true
        process_start_provenance = 'completed'
        native_exit_source = 'owned_native_process_handle'
        native_exit_code = [int]$nativeExitCode
        native_exit_observed = $nativeObserved
        native_exit_type = if ($nativeObserved) { 'System.Int32' } else { '' }
        effective_exit_code = [int]$effectiveExitCode
        timed_out = $timedOut
        elapsed_seconds = [Math]::Round($Started.stopwatch.Elapsed.TotalSeconds, 3)
        process_id = $processId
        started_utc = $Started.process_start_time.ToUniversalTime().ToString('o')
        process_identity = $Started.process_identity
        job_assignment_succeeded = [bool]$Started.job_assignment_succeeded
        job_accounting_succeeded = [bool]$Started.job_accounting_succeeded
        job_cleanup_succeeded = [bool]$jobCleanupSucceeded
        job_pretermination_active_process_count = [int]$jobPreterminationActiveProcessCount
        job_pretermination_membership_count = [int]$jobPreterminationMembershipCount
        job_final_active_process_count = [int]$jobFinalActiveProcessCount
        job_final_membership_empty = [bool]$jobFinalMembershipEmpty
        retained_descendant_identities = @($Started.retained_descendant_records)
        launched_image_path = [string]$Started.launched_image_path
        executable_pin_receipt = $Started.executable_pin.receipt
        executable_pin_release = $executablePinRelease
        executable_pin_clean = [bool]$executablePinClean
        stdout_identity = $Started.stdout_identity
        stderr_identity = $Started.stderr_identity
        owned_artifact_manifests = @($closedArtifactManifests)
        error = $errorText
    }
    if(-not(Test-Q009CompletionResultShape $result)){throw 'Redirected completion result failed its exact closed schema'}
    return $result
}

function Get-DiagnosticLines {
    param([string]$Text)
    $patterns = @(
        '(?im)^.*SCRIPT ERROR.*$',
        '(?im)^\s*ERROR(?:\s|:).*$',
        '(?im)^\s*WARNING(?:\s|:).*$',
        '(?im)^.*ObjectDB.*(?:leak|still alive|instance).*$'
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

function Read-LeaseFields {
    param([string]$Path)
    $fields = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { throw "Malformed lease line in $Path" }
        $key = $line.Substring(0, $separator)
        if ($fields.ContainsKey($key)) { throw "Duplicate lease field $key in $Path" }
        $fields[$key] = $line.Substring($separator + 1)
    }
    return $fields
}

function Get-StrictLeaseOwnerRecord {
    param([System.IO.FileInfo]$Lease)
    if ($null -eq $Lease -or -not (Test-Path -LiteralPath $Lease.FullName -PathType Leaf)) {
        throw 'Lease owner record requires a live ordinary file.'
    }
    $fileIdentity = Get-Q009FileSystemEntryIdentity $Lease.FullName
    if ([bool]$fileIdentity.is_directory) { throw "Lease object is not a file: $($Lease.FullName)" }
    $fields = Read-LeaseFields -Path $Lease.FullName
    foreach ($required in @('mode','pid','launcher_name','launcher_start_utc','launcher_start_ticks','launcher_key')) {
        if (-not $fields.ContainsKey($required) -or [string]::IsNullOrWhiteSpace([string]$fields[$required])) {
            throw "Lease lacks exact owner field $required in $($Lease.FullName)"
        }
    }
    if ([string]$fields.mode -notin @('exclusive','focused')) {
        throw "Lease mode is invalid in $($Lease.FullName)"
    }
    if ($Lease.Name -ceq 'EXCLUSIVE.lease') {
        if ([string]$fields.mode -cne 'exclusive') { throw 'EXCLUSIVE filename/mode mismatch.' }
    }
    else {
        if ([string]$fields.mode -cne 'focused') { throw "Focused lease mode mismatch in $($Lease.FullName)" }
        $nameMatch = [regex]::Match($Lease.Name, '-(?<pid>[0-9]+)\.lease$', [Text.RegularExpressions.RegexOptions]::CultureInvariant)
        if (-not $nameMatch.Success) { throw "Focused lease filename lacks a terminal PID: $($Lease.FullName)" }
    }
    $pidValue = 0
    $ticksValue = [long]0
    $startUtc = [datetime]::MinValue
    if (-not [int]::TryParse([string]$fields.pid,[ref]$pidValue) -or $pidValue -le 0) { throw "Lease PID is invalid in $($Lease.FullName)" }
    if ($Lease.Name -cne 'EXCLUSIVE.lease' -and [int]$nameMatch.Groups['pid'].Value -ne $pidValue) { throw "Focused lease filename/content PID mismatch in $($Lease.FullName)" }
    if (-not [long]::TryParse([string]$fields.launcher_start_ticks,[ref]$ticksValue) -or $ticksValue -le 0) { throw "Lease owner start ticks are invalid in $($Lease.FullName)" }
    if (-not [datetime]::TryParse([string]$fields.launcher_start_utc,[ref]$startUtc) -or $startUtc.ToUniversalTime().Ticks -ne $ticksValue) { throw "Lease owner UTC start is invalid in $($Lease.FullName)" }
    $identity = [ordered]@{
        pid = $pidValue
        name = [string]$fields.launcher_name
        start_utc = $startUtc.ToUniversalTime().ToString('o')
        start_ticks = $ticksValue
        key = ('{0}|{1}|{2}' -f $pidValue,$ticksValue,[string]$fields.launcher_name)
    }
    if ([string]$fields.launcher_key -cne [string]$identity.key) { throw "Lease owner key is invalid in $($Lease.FullName)" }
    if (-not (Test-Q009FileSystemIdentityMatch $fileIdentity)) {
        throw "Lease file identity changed while its exact owner fields were being read: $($Lease.FullName)"
    }
    return [ordered]@{ fields=$fields; identity=$identity; file_identity=$fileIdentity; path=$Lease.FullName }
}

function Assert-OwnedLease {
    param(
        [string]$Path,
        [string]$Root,
        [string]$Commit,
        [string]$Tree,
        [object]$RunContext,
        [AllowNull()][object]$ExpectedLeaseIdentity=$null
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Owned lease validation requires one exact sealed Q-009 run context'}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw 'The owned Q-009 reservation disappeared before launch.'
    }
    $record = Get-StrictLeaseOwnerRecord -Lease (Get-Item -LiteralPath $Path -Force -ErrorAction Stop)
    $fields = $record.fields
    if($null-ne$ExpectedLeaseIdentity-and(-not(Test-Q009FileSystemIdentityShape $ExpectedLeaseIdentity)-or[string]$record.file_identity.key-cne[string]$ExpectedLeaseIdentity.key)){throw 'The owned Q-009 lease file identity changed'}
    $currentIdentity = $RunContext.launcher_identity
    if ([string]$record.identity.key -cne [string]$currentIdentity.key -or -not (Test-LiveProcessMatchesIdentity $record.identity)) {
        throw 'The owned Q-009 lease owner is not this exact live launcher identity.'
    }
    if (-not [string]::Equals([System.IO.Path]::GetFullPath([string]$fields['worktree']), [System.IO.Path]::GetFullPath($Root), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The owned Q-009 lease worktree does not match the candidate.'
    }
    if ([string]$fields['candidate_commit'] -ne $Commit -or [string]$fields['candidate_tree'] -ne $Tree) {
        throw 'The owned Q-009 lease identity does not match the exact candidate.'
    }
}

function New-OwnedLeaseFile {
    param(
        [string]$Path,
        [string]$Text,
        [System.Collections.IDictionary]$Ownership = $null,
        [switch]$ForceWriteFailureForTest,
        [switch]$ForceRemovalFailureForTest,
        [switch]$ForceReplacementBeforeRemovalForTest
    )
    $cell = New-Q009CacheCustodyCell ('atomic-file-'+[guid]::NewGuid().ToString('N'))
    $created = $false
    $createdIdentity = $null
    $parentReceipt = $null
    $fileReceipt = $null
    $resolved=[System.IO.Path]::GetFullPath($Path)
    $parentPath=[System.IO.Path]::GetDirectoryName($resolved)
    $parentIdentity=Get-Q009FileSystemEntryIdentity $parentPath
    try {
        $parentReceipt=Open-Q009ExactDirectoryHeld -Path $parentPath -ExpectedIdentity $parentIdentity -CustodyCell $cell -Slot lease_parent
        $bytes=[System.Text.Encoding]::UTF8.GetBytes($Text)
        $fileReceipt=New-Q009ExactOwnedFileHeld -Path $resolved -Payload $bytes -CustodyCell $cell -ParentSlot lease_parent -Slot lease_file -ExpectedParentIdentity $parentIdentity
        $created = $true
        # Ownership comes from the still-open native CreateNew handle. The file
        # and its exact parent both deny delete sharing until this transaction
        # either publishes the completed file or marks that exact handle
        # delete-pending. No path lookup is allowed to establish ownership.
        $createdIdentity = $fileReceipt.identity
        if ($null -ne $Ownership) {
            $Ownership.created = $true
            $Ownership.path = $resolved
            $Ownership.identity = $createdIdentity
            $Ownership.write_complete = $false
            $Ownership.removal_failed = $false
            $Ownership.removal_error = ''
        }
        if ($ForceWriteFailureForTest) {
            throw 'Forced lease write failure for hostile validation.'
        }
        $fileClose=Close-Q009CheckedNativeHandle $cell lease_file 'Atomic file successful publish'
        if(-not(Test-Q009CheckedCloseReceipt $fileClose)){throw 'Atomic file successful publish lacked a checked file-close receipt'}
        $parentClose=Close-Q009CheckedNativeHandle $cell lease_parent 'Atomic file successful parent release'
        if(-not(Test-Q009CheckedCloseReceipt $parentClose)-or@($cell.NonTerminalSlots()).Count-ne0){throw 'Atomic file successful publish retained native custody'}
        if(-not(Test-Q009FileSystemIdentityMatch $createdIdentity)){throw 'Atomic file identity changed after successful checked close'}
        if ($null -ne $Ownership) { $Ownership.write_complete = $true }
    }
    catch {
        $creationFailure=$_.Exception
        if ($created) {
            try {
                if ($ForceRemovalFailureForTest) { throw 'Forced lease removal failure for hostile validation.' }
                if ($ForceReplacementBeforeRemovalForTest) {
                    [void](Close-Q009AllOpenNativeHandles $cell 'Atomic-file replacement hostile handoff')
                    $savedPath = [System.IO.Path]::GetFullPath($resolved + '.owned-original-' + [guid]::NewGuid().ToString('N'))
                    [System.IO.File]::Move($resolved, $savedPath)
                    [System.IO.File]::WriteAllText($resolved, 'foreign replacement')
                    if ($null -ne $Ownership) { $Ownership.test_original_path = $savedPath }
                    Remove-Q009ExactOwnedFile -Path $resolved -ExpectedIdentity $createdIdentity
                }else{
                    $disposition=Set-Q009HeldHandleDeletePending $cell lease_file 'Atomic partial file rollback'
                    if(-not(Test-Q009HeldHandleStateShape $disposition $createdIdentity $false)-or-not[bool]$disposition.delete_pending){throw 'Atomic partial file did not enter delete-pending state'}
                    $fileClose=Close-Q009CheckedNativeHandle $cell lease_file 'Atomic partial file rollback close'
                    if(-not(Test-Q009CheckedCloseReceipt $fileClose)){throw 'Atomic partial file rollback lacked a checked file-close receipt'}
                    $absence=Assert-Q009PathAbsentStrict $resolved
                    if(-not(Test-Q009StrictAbsenceReceipt $absence)){throw 'Atomic partial file rollback lacked strict absence proof'}
                    $parentClose=Close-Q009CheckedNativeHandle $cell lease_parent 'Atomic partial file parent release'
                    if(-not(Test-Q009CheckedCloseReceipt $parentClose)-or@($cell.NonTerminalSlots()).Count-ne0){throw 'Atomic partial file rollback retained native custody'}
                }
                if ($null -ne $Ownership) {
                    $Ownership.created = $false
                    $Ownership.identity = $null
                }
            }
            catch {
                try{[void](Close-Q009AllOpenNativeHandles $cell 'Atomic file failed rollback terminal release')}catch{}
                if ($null -ne $Ownership) {
                    $Ownership.created = $true
                    $Ownership.removal_failed = $true
                    $Ownership.removal_error = $_.Exception.Message
                }
                $leaseFailure = [System.InvalidOperationException]::new(
                    "Lease creation failed and the exact partial lease could not be removed: $($_.Exception.Message)",
                    $_.Exception
                )
                $leaseFailure.Data['owned_lease_created'] = $true
                $leaseFailure.Data['owned_lease_path'] = $resolved
                $leaseFailure.Data['owned_lease_identity'] = $createdIdentity
                throw $leaseFailure
            }
        }else{
            try{[void](Close-Q009AllOpenNativeHandles $cell 'Atomic file pre-create failure release')}catch{}
        }
        throw $creationFailure
    }
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
    $treeSpec = '{0}:{1}' -f $Commit, $RelativePath
    $blob = (& git -C $Root rev-parse $treeSpec).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($blob)) {
        throw "Could not bind tracked blob identity for $RelativePath"
    }
    return [ordered]@{
        path = $RelativePath
        git_blob = $blob
        length = [long](Get-Item -LiteralPath $fullPath).Length
        sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
}

function Get-LiveGodotIdentityRecords {
    param([switch]$ForceEnumerationFailureForTest)
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-LiveGodotProcesses -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)) {
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
    param([object]$RunContext)
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Focused lease owner census requires one exact sealed Q-009 run context'}
    $owners = [System.Collections.Generic.List[object]]::new()
    foreach ($lease in @(Get-StrictSharedLeaseFiles -RunContext $RunContext | Where-Object { $_.Name -ne 'EXCLUSIVE.lease' })) {
        $record = Get-StrictLeaseOwnerRecord -Lease $lease
        if (Test-LiveProcessMatchesIdentity $record.identity) {
            [void]$owners.Add($record.identity)
        }
    }
    return @($owners)
}

function ConvertTo-Q009StrictCimAncestryTable {
    param([object[]]$Snapshot)
    $table=@{}
    $idleSeen=$false
    foreach($entry in @($Snapshot)){
        $snapshotProcessId=[int]$entry.ProcessId
        if($snapshotProcessId-eq0){
            if($idleSeen-or[int]$entry.ParentProcessId-ne0-or[string]$entry.Name-cne'System Idle Process'){
                throw 'CIM process ancestry has a duplicate or malformed System Idle PID 0 row'
            }
            $idleSeen=$true
            continue
        }
        if($snapshotProcessId-lt0-or$table.ContainsKey($snapshotProcessId)){throw "CIM process ancestry has an invalid or duplicate positive PID: $snapshotProcessId"}
        $table[$snapshotProcessId]=$entry
    }
    if(-not$idleSeen){throw 'CIM process ancestry omitted the unique System Idle PID 0 row'}
    return $table
}

function Test-ProcessHasLeaseAncestor {
    param(
        [int]$ProcessId,
        [object[]]$LeaseOwnerIdentities,
        [switch]$ForceEnumerationFailureForTest
    )
    if($ProcessId-le0){throw "Lease ancestry child PID must be positive: $ProcessId"}
    if ($LeaseOwnerIdentities.Count -eq 0) { return $false }
    $ownerKeys = @($LeaseOwnerIdentities | ForEach-Object {
        if (-not (Test-ProcessIdentityProofShape $_) -or -not (Test-LiveProcessMatchesIdentity $_)) {
            throw 'Focused lease owner identity is malformed, stale, or PID-reused.'
        }
        [string]$_.key
    })
    $cimTable=ConvertTo-Q009StrictCimAncestryTable -Snapshot @(Get-CimProcessSnapshotStrict -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)
    $cursor = $ProcessId
    $childIdentity = $null
    for ($depth = 0; $depth -lt 32; $depth += 1) {
        if (-not $cimTable.ContainsKey($cursor)) { return $false }
        $cim = $cimTable[$cursor]
        $live = Get-ProcessByIdStrict -ProcessId $cursor
        if ($null -eq $live) { return $false }
        $identity = Get-ProcessIdentityRecord -Process $live
        $creationTicks = $cim.CreationDate.ToUniversalTime().Ticks
        if (-not (Test-CimCreationMatchesProcessStartTicks $creationTicks ([long]$identity.start_ticks))) { return $false }
        if ($null -ne $childIdentity -and [long]$identity.start_ticks -gt [long]$childIdentity.start_ticks) { return $false }
        if ($ownerKeys -contains [string]$identity.key) { return $true }
        $parent = [int]$cim.ParentProcessId
        if ($parent -le 0 -or $parent -eq $cursor) { return $false }
        $childIdentity = $identity
        $cursor = $parent
    }
    return $false
}

function Get-NewUnownedGodotRecords {
    param(
        [string[]]$BaselineKeys,
        [object]$RunContext,
        [switch]$ForceEnumerationFailureForTest
    )
    if(-not(Test-Q009RunContextShape $RunContext)){throw 'Unowned Godot census requires one exact sealed Q-009 run context'}
    $leaseOwnerIdentities = @(Get-LiveFocusedLeaseOwnerIdentities -RunContext $RunContext)
    return @(Get-LiveGodotIdentityRecords -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest | Where-Object {
        $record = $_
        $BaselineKeys -notcontains [string]$record.key -and -not (Test-ProcessHasLeaseAncestor -ProcessId ([int]$record.pid) -LeaseOwnerIdentities $leaseOwnerIdentities -ForceEnumerationFailureForTest:$ForceEnumerationFailureForTest)
    })
}
