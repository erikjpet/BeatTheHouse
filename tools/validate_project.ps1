param(
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "split_test_runner_helpers.ps1")
. (Join-Path $PSScriptRoot "health06_1_static_source_rules.ps1")

function Get-ProjectRelativePath {
    param([string]$Path)
    $rootPath = [System.IO.Path]::GetFullPath($root)
    if (-not $rootPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $rootPath += [System.IO.Path]::DirectorySeparatorChar
    }
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $rootUri = [System.Uri]$rootPath
    $pathUri = [System.Uri]$fullPath
    return [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($pathUri).ToString()) -replace "\\", "/"
}

function Test-JsonObjectRoot {
    param([AllowNull()][object]$Value)
    return $null -ne $Value -and $Value.GetType() -eq [System.Management.Automation.PSCustomObject]
}

function Test-ExactJsonString {
    param([AllowNull()][object]$Value)
    return $null -ne $Value -and $Value -is [string]
}

function Assert-ExactJsonString {
    param([AllowNull()][object]$Value, [string]$FieldName)
    if (-not (Test-ExactJsonString $Value)) {
        throw "$FieldName must be an exact JSON string scalar"
    }
}

function Get-Rw061GdScriptTopLevelFunctionExtent {
    param([string]$Source,[string]$FunctionName)
    if([string]::IsNullOrWhiteSpace($Source)-or$FunctionName-cnotmatch'^[A-Za-z_][A-Za-z0-9_]*$'){throw 'rw06_1 validator GDScript function lookup requires one exact identifier and nonempty source'}
    $declarations=[regex]::Matches($Source,'(?m)^(?:static[ \t]+)?func[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')
    $matches=@($declarations|Where-Object{[string]$_.Groups[1].Value-ceq$FunctionName})
    if($matches.Count-ne1){throw "rw06_1 validator GDScript function extent was not unique: $FunctionName"}
    $start=[int]$matches[0].Index;$end=$Source.Length
    foreach($declaration in $declarations){if([int]$declaration.Index-gt$start){$end=[int]$declaration.Index;break}}
    $extent=$Source.Substring($start,$end-$start)
    if($extent.Contains('"""')-or$extent.Contains("'''")){throw "rw06_1 validator refuses multiline-string ambiguity in $FunctionName"}
    return $extent
}

function Get-Rw061GdScriptNestedFunctionExtent {
    param([string]$ClassExtent,[string]$FunctionName)
    if([string]::IsNullOrWhiteSpace($ClassExtent)-or$FunctionName-cnotmatch'^[A-Za-z_][A-Za-z0-9_]*$'){throw 'rw06_1 validator nested GDScript function lookup requires one exact identifier and nonempty class source'}
    $declarations=[regex]::Matches($ClassExtent,'(?m)^\tfunc[ \t]+([A-Za-z_][A-Za-z0-9_]*)[ \t]*\(')
    $matches=@($declarations|Where-Object{[string]$_.Groups[1].Value-ceq$FunctionName})
    if($matches.Count-ne1){throw "rw06_1 validator nested GDScript function extent was not unique: $FunctionName"}
    $start=[int]$matches[0].Index;$end=$ClassExtent.Length
    foreach($declaration in $declarations){if([int]$declaration.Index-gt$start){$end=[int]$declaration.Index;break}}
    return $ClassExtent.Substring($start,$end-$start)
}

function Get-Rw061AuditTravelSourceIssues {
    param([string]$Source)
    $issues=[Collections.Generic.List[string]]::new()
    try{
        if($Source.Contains('"""')-or$Source.Contains("'''")){throw 'rw06_1 validator refuses any GDScript multiline-string ambiguity'}
        $simulate=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_simulate_run'
        $record=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_record_environment'
        $choices=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_travel_choices'
        $targets=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_travel_target_ids'
        $productionHost=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_production_foundation_travel_host'
        $overlay=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_qualifying_world_travel_contract_holds'
        $travel=Get-Rw061GdScriptTopLevelFunctionExtent $Source '_travel_to'
        $hostStart=$Source.IndexOf('class AuditFoundationTravelHost:',[StringComparison]::Ordinal)
        $hostEnd=$Source.IndexOf('var library: ContentLibrary',$hostStart,[StringComparison]::Ordinal)
        if($hostStart-lt0-or$hostEnd-le$hostStart-or$Source.IndexOf('class AuditFoundationTravelHost:',$hostStart+1,[StringComparison]::Ordinal)-ge0){throw 'rw06_1 validator production travel host adapter extent was not exact and unique'}
        $foundationHost=$Source.Substring($hostStart,$hostEnd-$hostStart)
        $hostMethodReturns=[ordered]@{
            _is_meta_session='return false'
            _travel_base_cache_key='return str(view_model_script.travel_base_cache_key(self))'
            _enabled_world_route_ids='return view_model_script.enabled_world_route_ids(self, source_id)'
            _world_route_for_target='return view_model_script.world_route_for_target(self, target_id, path_query)'
            _environment_archetype='return view_model_script.environment_archetype(self, archetype_id)'
            _travel_clock_minutes_for_route='return int(view_model_script.travel_clock_minutes_for_route(self, route, force_walk))'
            _arrival_minute_for_route='return int(view_model_script.arrival_minute_for_route(self, route, force_walk))'
            _environment_open_status_at='return view_model_script.environment_open_status_at(self, archetype, minute_of_day)'
            _travel_label_from_archetype='return str(view_model_script.travel_label_from_archetype(self, archetype, fallback_id))'
            _travel_full_preview_enabled='return bool(view_model_script.travel_full_preview_enabled(self))'
            _travel_full_preview_enabled_for='return bool(view_model_script.travel_full_preview_enabled_for(self, target_id))'
            _local_parent_home_door_travel_choice='return {}'
            _closing_time_blocks_environment_actions='return false'
            _closing_time_walk_fallback_target_id='return ""'
            _travel_target_ids='return view_model_script.travel_target_ids(self)'
            _travel_choice='return view_model_script.travel_choice(self, target_id, known_target_ids)'
        }
        foreach($methodName in @($hostMethodReturns.Keys)){
            $methodExtent=Get-Rw061GdScriptNestedFunctionExtent $foundationHost ([string]$methodName)
            $expectedReturn=[string]$hostMethodReturns[$methodName]
            if([regex]::Matches($methodExtent,'(?m)^\t\treturn[ \t]+').Count-ne1-or[regex]::Matches($methodExtent,'(?m)^\t\t'+[regex]::Escape($expectedReturn)+'[ \t]*$').Count-ne1){[void]$issues.Add("Foundation host adapter method was not exact: $methodName")}
        }
        foreach($preloadLine in @('const FoundationTravelViewModelScript := preload("res://scripts/ui/foundation_travel_view_model.gd")','const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")','const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")')){if([regex]::Matches($Source,'(?m)^'+[regex]::Escape($preloadLine)+'[ \t]*$').Count-ne1){[void]$issues.Add("Foundation dependency binding was not exact: $preloadLine")}}
        foreach($hostConstant in @('const TRAVEL_CLOCK_MINUTES_PER_BLOCK := 6','const WALK_CLOCK_MINUTES_PER_BLOCK := 10')){if([regex]::Matches($foundationHost,'(?m)^\t'+[regex]::Escape($hostConstant)+'[ \t]*$').Count-ne1){[void]$issues.Add("Foundation timing constant was not exact: $hostConstant")}}
        if([regex]::Matches($foundationHost,'(?m)^\tvar world_map_overlay: Variant = null[ \t]*$').Count-ne1){[void]$issues.Add('Foundation host omitted the explicit null world-map overlay used by scouting preview gating')}
        $hostInit=Get-Rw061GdScriptNestedFunctionExtent $foundationHost '_init'
        if([regex]::Matches($hostInit,'(?ms)^\tfunc _init\([ \t]*\r?\n\t\tp_view_model_script: Script,[ \t]*\r?\n\t\tp_world_map_script: Script,[ \t]*\r?\n\t\tp_tutorial_flow_script: Script,[ \t]*\r?\n\t\tp_attribute_badges_script: Script,[ \t]*\r?\n\t\tp_run_state: Variant,[ \t]*\r?\n\t\tp_generator: Variant,[ \t]*\r?\n\t\tp_library: Variant[ \t]*\r?\n\t\) -> void:[ \t]*$').Count-ne1){[void]$issues.Add('Foundation host constructor signature/order was not exact')}
        foreach($assignment in @('view_model_script = p_view_model_script','WorldMapScript = p_world_map_script','TutorialFlowScript = p_tutorial_flow_script','AttributeBadgesScript = p_attribute_badges_script','run_state = p_run_state','generator = p_generator','library = p_library')){if([regex]::Matches($hostInit,'(?m)^\t\t'+[regex]::Escape($assignment)+'[ \t]*$').Count-ne1){[void]$issues.Add("Foundation host constructor omitted exact assignment: $assignment")}}
        if([regex]::Matches($simulate,'(?m)^\trecord\["travel_after_events"\][ \t]*=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1){[void]$issues.Add('post-event producer escaped _simulate_run')}
        if([regex]::Matches($record,'(?m)^\tvar[ \t]+travel_initial[ \t]*:=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1-or[regex]::Matches($record,'(?m)^\t\t"travel_initial"[ \t]*:[ \t]*travel_initial,[ \t]*$').Count-ne1){[void]$issues.Add('initial producer/record escaped _record_environment')}
        if([regex]::Matches($Source,'(?m)^[ \t]*record\["travel_after_events"\][ \t]*=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1-or[regex]::Matches($Source,'(?m)^[ \t]*var[ \t]+travel_initial[ \t]*:=[ \t]*_travel_choices\(run_state, false\)[ \t]*$').Count-ne1-or[regex]::Matches($Source,'(?m)^[ \t]*"travel_initial"[ \t]*:[ \t]*travel_initial,[ \t]*$').Count-ne1-or[regex]::IsMatch($Source,'(?m)^[ \t]*(?:record\["travel_after_events"\][ \t]*=|var[ \t]+travel_initial[ \t]*:=)[ \t]*_travel_choices\(run_state, true\)')){[void]$issues.Add('public producer tokens were duplicated, omitted, or hidden-inclusive')}
        if([regex]::Matches($targets,'(?m)^\tif not _qualifying_world_travel_contract_holds\(run_state\):[ \t]*$').Count-ne1-or[regex]::Matches($targets,'(?m)^\treturn _production_foundation_travel_host\(run_state\)\._travel_target_ids\(\)[ \t]*$').Count-ne1-or[regex]::Matches($targets,'(?m)^\treturn[ \t]+').Count-ne2-or$targets.Contains('WorldMapScript.travel_target_ids')-or$targets.Contains('generator._world_travel_target_ids')){[void]$issues.Add('target catalog bypasses the exact production Foundation view/overlay guard')}
        if([regex]::Matches($productionHost,'(?m)^\treturn[ \t]+').Count-ne1-or[regex]::Matches($productionHost,'(?ms)^\treturn AuditFoundationTravelHost\.new\([ \t]*\r?\n\t\tFoundationTravelViewModelScript,[ \t]*\r?\n\t\tWorldMapScript,[ \t]*\r?\n\t\tTutorialFlowScript,[ \t]*\r?\n\t\tAttributeBadgesScript,[ \t]*\r?\n\t\trun_state,[ \t]*\r?\n\t\tgenerator,[ \t]*\r?\n\t\tlibrary[ \t]*\r?\n\t\)[ \t]*$').Count-ne1){[void]$issues.Add('Foundation travel host was not constructed in exact order from the shipped collaborators and run state')}
        if([regex]::Matches($choices,'(?m)^\tvar target_ids := _travel_target_ids\(run_state\)[ \t]*$').Count-ne1-or[regex]::Matches($choices,'(?m)^\tvar production_host := _production_foundation_travel_host\(run_state\)[ \t]*$').Count-ne1-or[regex]::Matches($choices,'(?m)^\t\tvar production_choice: Dictionary = production_host\._travel_choice\(str\(target_id\), target_ids\)[ \t]*$').Count-ne1-or[regex]::Matches($choices,'(?m)^\t\t\t"enabled": bool\(production_choice\.get\("enabled", false\)\),[ \t]*$').Count-ne1-or$choices.Contains('generator._world_target_is_available')){[void]$issues.Add('choice projection bypasses the production Foundation choice')}
        foreach($required in @('not run_state.has_world_map()','run_state.is_tutorial_run()','run_state.narrative_flags.get("_meta_home_session", false)','run_state.delivery_has_active_run()','run_state.closing_time_forced_travel_required()','run_state.travel_option_bonus() != 0','_string_array(local_flags.get("casino_room_targets", [])).is_empty()')){if(-not$overlay.Contains($required)){[void]$issues.Add("overlay exclusion omitted: $required")}}
        if([regex]::Matches($overlay,'(?m)^\t\t\tfailures\.append\(message\)[ \t]*$').Count-ne1-or[regex]::Matches($overlay,'(?m)^\treturn[ \t]+').Count-ne2-or[regex]::Matches($overlay,'(?m)^\t\treturn true[ \t]*$').Count-ne1-or[regex]::Matches($overlay,'(?m)^\treturn false[ \t]*$').Count-ne1){[void]$issues.Add('overlay violation bypasses exact failure control flow')}
        if([regex]::Matches($travel,'_travel_target_ids\(run_state\)').Count-ne2){[void]$issues.Add('pre/post-heat admission bypasses the constrained production target catalog')}
    }catch{[void]$issues.Add($_.Exception.Message)}
    return @($issues)
}

if($null-ne('BeatTheHouse.Rw061.ValidatorReadPinNativeV2' -as [type])){
    throw 'rw06_1 validator refuses ambient reuse of its native read-pin authority type.'
}
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;
namespace BeatTheHouse.Rw061 {
  public static class ValidatorReadPinNativeV2 {
    [StructLayout(LayoutKind.Sequential)] private struct FILETIME { public uint Low; public uint High; }
    [StructLayout(LayoutKind.Sequential)] private struct BY_HANDLE_FILE_INFORMATION {
      public uint FileAttributes; public FILETIME CreationTime; public FILETIME LastAccessTime; public FILETIME LastWriteTime;
      public uint VolumeSerialNumber; public uint FileSizeHigh; public uint FileSizeLow; public uint NumberOfLinks;
      public uint FileIndexHigh; public uint FileIndexLow;
    }
    [DllImport("kernel32.dll", SetLastError=true)] private static extern bool GetFileInformationByHandle(SafeFileHandle handle,out BY_HANDLE_FILE_INFORMATION info);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] private static extern uint GetFinalPathNameByHandle(SafeFileHandle handle,StringBuilder path,uint length,uint flags);
    private static long Ticks(FILETIME value){long raw=unchecked((long)(((ulong)value.High<<32)|value.Low));return DateTime.FromFileTimeUtc(raw).Ticks;}
    private static string FinalPath(SafeFileHandle handle){var path=new StringBuilder(32768);uint n=GetFinalPathNameByHandle(handle,path,(uint)path.Capacity,0u);if(n==0||n>=(uint)path.Capacity)throw new Win32Exception(Marshal.GetLastWin32Error(),"validator pin final-path proof failed");string value=path.ToString();if(value.StartsWith(@"\\?\UNC\",StringComparison.OrdinalIgnoreCase))return @"\\"+value.Substring(8);if(value.StartsWith(@"\\?\",StringComparison.OrdinalIgnoreCase))return value.Substring(4);return value;}
    public static string[] Describe(SafeFileHandle handle){if(handle==null||handle.IsInvalid||handle.IsClosed)throw new ArgumentException("validator pin handle is not live");BY_HANDLE_FILE_INFORMATION info;if(!GetFileInformationByHandle(handle,out info))throw new Win32Exception(Marshal.GetLastWin32Error(),"validator pin native identity proof failed");long length=unchecked((long)(((ulong)info.FileSizeHigh<<32)|info.FileSizeLow));return new[]{FinalPath(handle),info.VolumeSerialNumber.ToString("X8")+":"+(((ulong)info.FileIndexHigh<<32)|info.FileIndexLow).ToString("X16"),Ticks(info.CreationTime).ToString(),info.FileAttributes.ToString(),length.ToString()};}
  }
}
'@

function Open-Rw061ValidatorReadPin {
    param([string]$Path)
    $resolved = [IO.Path]::GetFullPath($Path)
    $stream = $null
    $memory = $null
    $hasher = $null
    try {
        # FileShare.Read is deliberate: while this handle is live the exact
        # source may be read by a child, but it cannot be rewritten, replaced,
        # renamed, or deleted between hashing and execution.
        $stream = [IO.FileStream]::new(
            $resolved,
            [IO.FileMode]::Open,
            [IO.FileAccess]::Read,
            [IO.FileShare]::Read
        )
        $memory = [IO.MemoryStream]::new()
        $stream.CopyTo($memory)
        $bytes = $memory.ToArray()
        $stream.Position = 0
        $hasher = [Security.Cryptography.SHA256]::Create()
        $sha256 = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '')
        $native=[BeatTheHouse.Rw061.ValidatorReadPinNativeV2]::Describe($stream.SafeFileHandle)
        $finalPath=[IO.Path]::GetFullPath([string]$native[0])
        $attributes=[uint32]$native[3]
        if(-not[string]::Equals($resolved,$finalPath,[StringComparison]::OrdinalIgnoreCase)-or($attributes-band[IO.FileAttributes]::Directory)-ne0-or($attributes-band[IO.FileAttributes]::ReparsePoint)-ne0-or[long]$native[4]-ne[long]$bytes.LongLength){throw 'Validator source pin failed native final-path/type/length admission before execution.'}
        return [ordered]@{
            path = $resolved
            final_path = $finalPath
            native_key = [string]$native[1]
            creation_ticks = [long]$native[2]
            attributes = $attributes
            length = [long]$bytes.LongLength
            sha256 = [string]$sha256
            bytes = $bytes
            stream = $stream
        }
    }
    catch {
        if ($null -ne $stream) { try { $stream.Dispose() } catch {} }
        throw
    }
    finally {
        if ($null -ne $hasher) { $hasher.Dispose() }
        if ($null -ne $memory) { $memory.Dispose() }
    }
}

function Close-Rw061ValidatorReadPin {
    param([AllowNull()][object]$Pin)
    if ($null -eq $Pin -or $null -eq $Pin.stream) { return }
    $Pin.stream.Dispose()
}

function Close-Rw061ValidatorShadowReadPins {
    param([AllowNull()][System.Collections.Generic.List[object]]$ReadPins)
    if ($null -eq $ReadPins) { return }
    $closeErrors = [System.Collections.Generic.List[string]]::new()
    for ($index = $ReadPins.Count - 1; $index -ge 0; $index -= 1) {
        $pin = $ReadPins[$index]
        try {
            [void](Get-Rw061ValidatorReadPinReceipt $pin)
            $safeHandle = $pin.stream.SafeFileHandle
            Close-Rw061ValidatorReadPin $pin
            if (-not $safeHandle.IsClosed) {
                throw "Validator shadow read pin remained open after disposal: $($pin.path)"
            }
            $ReadPins.RemoveAt($index)
        }
        catch {
            [void]$closeErrors.Add($_.Exception.Message)
        }
    }
    if ($closeErrors.Count -ne 0) {
        throw "Validator shadow read-pin release failed: $($closeErrors -join ' | ')"
    }
}

function Get-Rw061ValidatorReadPinReceipt {
    param([object]$Pin)
    if ($null -eq $Pin -or $null -eq $Pin.stream -or $Pin.stream.SafeFileHandle.IsClosed -or $Pin.stream.SafeFileHandle.IsInvalid) {
        throw 'Validator source pin was absent or closed before receipt capture.'
    }
    $native=[BeatTheHouse.Rw061.ValidatorReadPinNativeV2]::Describe($Pin.stream.SafeFileHandle)
    $finalPath=[IO.Path]::GetFullPath([string]$native[0])
    if (-not [string]::Equals([IO.Path]::GetFullPath($Pin.path), $finalPath, [StringComparison]::OrdinalIgnoreCase) -or
        $finalPath-cne[string]$Pin.final_path-or[string]$native[1]-cne[string]$Pin.native_key-or[long]$native[2]-ne[long]$Pin.creation_ticks-or[uint32]$native[3]-ne[uint32]$Pin.attributes-or[long]$native[4]-ne[long]$Pin.length-or
        ([uint32]$native[3]-band[IO.FileAttributes]::ReparsePoint)-ne0-or([uint32]$native[3]-band[IO.FileAttributes]::Directory)-ne0) {
        throw "Validator source pin final path changed: $($Pin.path) -> $finalPath"
    }
    if ($Pin.length -isnot [long] -or [long]$Pin.length -le 0 -or $Pin.sha256 -isnot [string] -or $Pin.sha256 -cnotmatch '^[0-9A-F]{64}$') {
        throw 'Validator source pin length/hash receipt was malformed.'
    }
    return [ordered]@{
        path = [string]$Pin.path
        final_path = [string]$finalPath
        identity = [ordered]@{path=[string]$Pin.path;native_key=[string]$Pin.native_key;creation_ticks=[long]$Pin.creation_ticks;is_directory=[bool]$false;reparse_point=[bool]$false;attributes=[uint32]$Pin.attributes;key=('{0}|{1}|file'-f[string]$Pin.native_key,[long]$Pin.creation_ticks)}
        length = [long]$Pin.length
        sha256 = [string]$Pin.sha256
        held = $true
    }
}

function New-Rw061ValidatorShadowFile {
    param(
        [object]$CustodyCell,
        [object]$RootReceipt,
        [string]$Path,
        [string]$Slot,
        [byte[]]$Bytes,
        [System.Collections.Generic.List[object]]$ReadPins
    )
    $receipt = New-Q009ExactOwnedFileHeld -Path $Path -Payload $Bytes -CustodyCell $CustodyCell -ParentSlot 'root_creation' -Slot $Slot -ExpectedParentIdentity $RootReceipt.identity
    if ($receipt.path -cne [IO.Path]::GetFullPath($Path) -or $receipt.handle_state -cne 'OPEN') {
        throw "Validator shadow file did not return exact held custody: $Path"
    }
    # The native creation handle necessarily has write access. Keeping it live
    # makes a child read pin fail Windows' symmetric share check even though
    # the creation handle grants FILE_SHARE_READ. Transition immediately to a
    # read-only FileShare.Read pin, rechecking the same native identity, length,
    # and bytes before the shadow is exposed to any child. The bounded
    # close/reopen boundary fails closed on replacement or a competing writer.
    [void](Close-Q009CheckedNativeHandle $CustodyCell $Slot "Validator shadow creation handoff $Slot")
    $readPin = $null
    try {
        $readPin = Open-Rw061ValidatorReadPin $Path
        $pinReceipt = Get-Rw061ValidatorReadPinReceipt $readPin
        if ([string]$pinReceipt.identity.key -cne [string]$receipt.identity.key -or
                [long]$pinReceipt.length -ne [long]$receipt.payload_length -or
                [string]$pinReceipt.sha256 -cne [string]$receipt.payload_sha256) {
            throw "Validator shadow read-only handoff changed identity or bytes: $Path"
        }
        [void]$ReadPins.Add($readPin)
        $readPin = $null
        return [ordered]@{
            path = [string]$receipt.path
            identity = $pinReceipt.identity
            creation_method = [string]$receipt.creation_method
            payload_sha256 = [string]$receipt.payload_sha256
            payload_length = [int]$receipt.payload_length
            creation_handle_slot = [string]$Slot
            creation_handle_state = 'CLOSED'
            authority_kind = 'VALIDATOR_READ_PIN'
            read_pin_held = [bool]$true
            share_read = [bool]$true
            share_write = [bool]$false
            share_delete = [bool]$false
        }
    }
    finally {
        if ($null -ne $readPin) { Close-Rw061ValidatorReadPin $readPin }
    }
}

function Open-Rw061ValidatorShadowArtifact {
    param(
        [object]$CustodyCell,
        [object]$RootReceipt,
        [string]$Path,
        [string]$Slot
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetDirectoryName($resolved) -cne [string]$RootReceipt.identity.path) {
        throw "Validator artifact escaped the exact owned shadow root: $resolved"
    }
    $identity = Get-Q009FileSystemEntryIdentity $resolved
    if ([bool]$identity.is_directory -or [bool]$identity.reparse_point) {
        throw "Validator artifact was not an ordinary file: $resolved"
    }
    [void](Open-Q009ExactFileHeld -Path $resolved -ExpectedIdentity $identity -CustodyCell $CustodyCell -Slot $Slot)
    $description = Get-Q009HeldFileDescription $CustodyCell $Slot $resolved
    if ([string]$description.native_key -cne [string]$identity.native_key -or [long]$description.creation_ticks -ne [long]$identity.creation_ticks) {
        throw "Validator artifact identity changed during handle-bound capture: $resolved"
    }
    return [ordered]@{
        path = $resolved
        identity = $identity
        length = [long]$description.length
        sha256 = [string]$description.sha256
        slot = [string]$Slot
        held = $true
    }
}

function Assert-Rw061ValidatorArtifactsBoundToClosedProcess {
    param([object]$Completion,[object]$RunContext,[object]$RootReceipt,[object[]]$ArtifactReceipts)
    if (-not (Test-Q009CompletionResultShape $Completion)) { throw 'validator artifact binding requires one exact completion receipt' }
    $closed = @($Completion.owned_artifact_manifests | Where-Object { [string]$_.role -ceq 'validator_shadow' })
    if ($closed.Count -ne 1 -or -not (Test-Q009ClosedArtifactManifestReceiptShape $closed[0] $RunContext $Completion.process_identity) -or
            [string]$closed[0].root_identity.key -cne [string]$RootReceipt.identity.key) {
        throw 'validator child omitted or changed its exact closed shadow-root manifest'
    }
    foreach ($artifact in @($ArtifactReceipts)) {
        $relative = [IO.Path]::GetFileName([string]$artifact.path)
        $matches = @($closed[0].manifest.entries | Where-Object { [string]$_.path -ceq $relative })
        if ($matches.Count -ne 1 -or [bool]$matches[0].is_directory -or
                [string]$matches[0].native_key -cne [string]$artifact.identity.native_key -or
                [long]$matches[0].creation_ticks -ne [long]$artifact.identity.creation_ticks -or
                [long]$matches[0].length -ne [long]$artifact.length -or
                [string]$matches[0].sha256 -cne [string]$artifact.sha256) {
            throw "validator child artifact was not byte/identity-bound to its closed producer job: $relative"
        }
    }
    return $closed[0]
}

function Assert-Rw061ValidatorShadowMembers {
    param([string]$RootPath,[string[]]$ExpectedLeafNames)
    $rootPathFull = [IO.Path]::GetFullPath($RootPath).TrimEnd('\','/')
    $entries = @(Get-ChildItem -LiteralPath $rootPathFull -Force -ErrorAction Stop | Sort-Object Name)
    foreach ($entry in $entries) {
        if (-not ($entry -is [IO.FileInfo]) -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Validator shadow root contained a non-ordinary child: $($entry.FullName)"
        }
    }
    $actual = @($entries | ForEach-Object { [string]$_.Name })
    $expected = @($ExpectedLeafNames | Sort-Object)
    if (($actual -join "`n") -cne ($expected -join "`n") -or @($actual | Sort-Object -Unique).Count -ne $actual.Count) {
        throw "Validator shadow root exact member set drifted. Expected: $($expected -join ', '); actual: $($actual -join ', ')"
    }
}

function Test-Rw061CodexHostTelemetryProcess {
    param([Diagnostics.Process]$Process)
    if ($null -eq $Process -or $Process.ProcessName -cne 'powershell') { return $false }
    $native = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f [int]$Process.Id) -ErrorAction SilentlyContinue
    if ($null -eq $native -or [string]$native.Name -cne 'powershell.exe') { return $false }
    $command = [string]$native.CommandLine
    if (-not $command.Contains('powershell.exe -NoProfile -NonInteractive -Command') -or
            -not $command.Contains('Get-CimInstance Win32_PerfFormattedData_PerfProc_Process') -or
            -not $command.Contains('Get-CimInstance Win32_Process -Filter') -or
            -not $command.Contains("Name='CpuPercent'") -or
            -not $command.Contains("Name='AgeSeconds'") -or
            -not $command.Contains('ConvertTo-Json -Depth 2')) {
        return $false
    }
    $parent = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f [int]$native.ParentProcessId) -ErrorAction SilentlyContinue
    if ($null -eq $parent -or [string]$parent.Name -cne 'ChatGPT (Beta).exe') { return $false }
    $parentPath = [string]$parent.ExecutablePath
    return $parentPath.Contains('\WindowsApps\OpenAI.CodexBeta_') -and
        $parentPath.EndsWith('\app\ChatGPT (Beta).exe', [StringComparison]::OrdinalIgnoreCase)
}

function Get-Rw061ValidatorProcessCensus {
    $names = @('powershell','pwsh','python','python3','Godot_v4.6-stable_win64_console','Godot_v4.6-stable_win64')
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($process in @(Get-Process -ErrorAction Stop | Where-Object { $names -contains $_.ProcessName })) {
        try {
            # Codex desktop samples machine resource usage in a short-lived,
            # non-project PowerShell child during long tool calls. Authenticate
            # that exact host-owned command and parent before excluding it; all
            # validator/project shells remain part of the unchanged census.
            if (Test-Rw061CodexHostTelemetryProcess $process) { continue }
            $start = $process.StartTime.ToUniversalTime()
            [void]$records.Add([ordered]@{
                pid = [int]$process.Id
                name = [string]$process.ProcessName
                start_ticks = [long]$start.Ticks
                key = ('{0}|{1}|{2}' -f [int]$process.Id,[long]$start.Ticks,[string]$process.ProcessName)
            })
        }
        catch {
            try { [void][Diagnostics.Process]::GetProcessById([int]$process.Id) }
            catch [ArgumentException] { continue }
            throw "Could not bind validator process census identity for PID $($process.Id): $($_.Exception.Message)"
        }
    }
    return @($records | Sort-Object key)
}

function Get-Rw061ValidatorLeaseCensus {
    param([string]$LeaseRoot)
    $rootPath = [IO.Path]::GetFullPath($LeaseRoot)
    if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) { return @() }
    $rootItem = Get-Item -LiteralPath $rootPath -Force -ErrorAction Stop
    if (-not ($rootItem -is [IO.DirectoryInfo]) -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Canonical lease root is not an ordinary directory during validator census.'
    }
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @(Get-ChildItem -LiteralPath $rootPath -Filter '*.lease' -Force -ErrorAction Stop | Sort-Object FullName)) {
        $isFile = $entry -is [IO.FileInfo]
        $isReparse = ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        $sha = ''
        if ($isFile -and -not $isReparse) { $sha = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash }
        [void]$records.Add([ordered]@{
            path = [IO.Path]::GetFullPath($entry.FullName)
            type = if ($isFile) { 'file' } else { 'non_file' }
            reparse = $isReparse
            creation_ticks = [long]$entry.CreationTimeUtc.Ticks
            length = if ($isFile) { [long]$entry.Length } else { -1L }
            sha256 = $sha
        })
    }
    return @($records)
}

function Get-Rw061ValidatorSelfTestResidueCensus {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @(Get-ChildItem -LiteralPath $tempRoot -Filter 'rw06-q009-selftest-*' -Force -ErrorAction Stop | Sort-Object FullName)) {
        [void]$records.Add([ordered]@{
            path = [IO.Path]::GetFullPath($entry.FullName)
            type = if ($entry -is [IO.DirectoryInfo]) { 'directory' } elseif ($entry -is [IO.FileInfo]) { 'file' } else { 'other' }
            reparse = (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
            creation_ticks = [long]$entry.CreationTimeUtc.Ticks
        })
    }
    return @($records)
}

function Get-Rw061ValidatorTreeCensus {
    param([string]$Path)
    $rootPath = [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if (-not (Test-Path -LiteralPath $rootPath)) {
        return [ordered]@{present=$false;root=$null;entries=[object[]]@()}
    }
    $rootItem = Get-Item -LiteralPath $rootPath -Force -ErrorAction Stop
    if (-not ($rootItem -is [IO.DirectoryInfo]) -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Validator tree census root is not an ordinary directory: $rootPath"
    }
    $entries = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($rootPath)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($entry in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop | Sort-Object FullName)) {
            $full = [IO.Path]::GetFullPath($entry.FullName)
            $isReparse = ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ($isReparse) { throw "Validator tree census found a reparse point: $full" }
            $isDirectory = $entry -is [IO.DirectoryInfo]
            [void]$entries.Add([ordered]@{
                path = $full.Substring($rootPath.Length).TrimStart('\','/').Replace('\','/')
                type = if ($isDirectory) { 'directory' } elseif ($entry -is [IO.FileInfo]) { 'file' } else { 'other' }
                creation_ticks = [long]$entry.CreationTimeUtc.Ticks
                last_write_ticks = [long]$entry.LastWriteTimeUtc.Ticks
                length = if ($entry -is [IO.FileInfo]) { [long]$entry.Length } else { -1L }
                sha256 = if ($entry -is [IO.FileInfo]) { (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash } else { '' }
            })
            if ($isDirectory) { $pending.Push($full) }
        }
    }
    return [ordered]@{
        present = $true
        root = [ordered]@{path=$rootPath;creation_ticks=[long]$rootItem.CreationTimeUtc.Ticks;last_write_ticks=[long]$rootItem.LastWriteTimeUtc.Ticks}
        entries = @($entries | Sort-Object path)
    }
}

function Get-Rw061ValidatorEnvironmentCensus {
    $snapshot = [ordered]@{}
    foreach ($name in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME','XDG_CACHE_HOME','XDG_CONFIG_HOME')) {
        $snapshot[$name] = [Environment]::GetEnvironmentVariable($name,'Process')
    }
    return $snapshot
}

function Get-Rw061ValidatorFileIdentityCensus {
    param([string[]]$Paths)
    $records = [ordered]@{}
    foreach ($path in $Paths) {
        $full = [IO.Path]::GetFullPath($path)
        $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if (-not ($item -is [IO.FileInfo]) -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Validator-bound source is not an ordinary file: $full" }
        $records[$full] = [ordered]@{length=[long]$item.Length;creation_ticks=[long]$item.CreationTimeUtc.Ticks;last_write_ticks=[long]$item.LastWriteTimeUtc.Ticks;sha256=(Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash}
    }
    return $records
}

function Get-FoundationUiContentSelectionScan {
    param([string]$Source)
    $normalized = $Source.Replace("`r`n", "`n")
    $hostSecurityAllowlist = @'
const SEALED_ACTION_HOST_SKIP_ENVIRONMENT_TURN_ALLOWLIST := {
	"slot": ["slot_handpay_acknowledge"],
}
'@
    $hostSecurityAllowlist = $hostSecurityAllowlist.Replace("`r`n", "`n")
    $matchCount = [regex]::Matches($normalized, [regex]::Escape($hostSecurityAllowlist)).Count
    $scanText = $normalized
    if ($matchCount -eq 1) {
        $scanText = $normalized.Replace($hostSecurityAllowlist, "")
    }
    return @{
        HostSecurityAllowlistCount = $matchCount
        ScanText = $scanText
    }
}

$requiredFiles = @(
    "README.md",
    "project.godot",
    "export_presets.cfg",
    "scenes/main.tscn",
    "scripts/core/run_state.gd",
    "scripts/core/environment_instance.gd",
    "scripts/core/environment_placement.gd",
    "scripts/core/developer_placement_store.gd",
    "scripts/core/game_module.gd",
    "scripts/core/item_effect.gd",
    "scripts/core/event_module.gd",
    "scripts/core/platform_services.gd",
    "scripts/core/profile_inventory.gd",
    "scripts/core/attribute_badges.gd",
    "scripts/core/content_library.gd",
    "scripts/core/scenario_sequence_catalog.gd",
    "scripts/core/scenario_sequence_schema.gd",
    "scripts/core/scenario_sequence_runtime.gd",
    "scripts/core/scenario_operation_registry.gd",
    "scripts/core/character_roster.gd",
    "scripts/core/crew_state_model.gd",
    "scripts/core/crew_recruitment_model.gd",
    "scripts/core/crew_heist_model.gd",
    "scripts/core/rng_stream.gd",
    "scripts/core/run_generator.gd",
    "scripts/core/save_service.gd",
    "scripts/ui/foundation_main.gd",
    "scripts/ui/attribute_badge_row.gd",
    "scripts/ui/visual_style.gd",
    "scripts/tests/foundation/check_lenders_release_saves.gd",
    "scripts/tests/foundation/interactable_event_class_guard.gd",
    "scripts/tests/foundation/crew_recruitment_contract.gd",
    "scripts/tests/foundation/crew_layer3_jobs_contract.gd",
    "scripts/tests/foundation/crew_plays_contract.gd",
    "scripts/tests/foundation/crew_heist_contract.gd",
    "scripts/tests/foundation/crew_turn_contract.gd",
    "scripts/tests/foundation/character_chains_contract.gd",
    "scripts/tests/foundation/content_depth_contract.gd",
    "scripts/tests/foundation/scenario_sequence_contract.gd",
    "scripts/tests/foundation/harness_production_fidelity.gd",
    "scripts/tests/foundation/crew_ignored_golden_probe.gd",
    "scripts/tests/fixtures/crew06_5_ignored_run_baseline.json",
    "scripts/tests/foundation/check_scratch_tickets.gd",
    "scripts/tests/developer_placement_mode_check.gd",
    "scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd",
    "tools/check_godot.ps1",
    "tools/split_test_runner_helpers.ps1",
    "tools/function_census.ps1",
    "tools/gdscript_load_check.gd",
    "tools/foundation_visual_qa.ps1",
    "tools/foundation_visual_qa.gd",
    "tools/scenario_sequence_audit.ps1",
    "tools/scenario_sequence_audit.gd",
    "tools/environment_grounding_static_check.ps1",
    "tools/environment_grounding_contract.gd",
    "tools/environment_fixed_slot_static_check.py",
    "tools/environment_generation_audit.gd",
    "tools/rw06_q009_process_support.ps1",
    "tools/rw06_1_environment_exact_seed_contract_test.ps1",
    "tools/fixtures/rw06_1_environment_exact_seed_manifest.json",
    "tools/fix06_31_contact_sheets.ps1",
    "tools/scenario_room_multiseed_finalization.gd",
    "tools/scenario_sequence_probe_support.gd",
    "tools/scenario_sequence_probe_main.gd",
    "tools/scenario_sequence_probe_main.tscn",
    "tools/scenario_sequence_visual_capture.ps1",
    "tools/scenario_sequence_web_capture.mjs",
    "tools/scenario_sequence_parity_performance.ps1",
    "data/art/art_manifest.json",
    "data/art/attribute_glyphs.json",
    "data/environments/archetypes.json",
    "data/environments/placement_surfaces.json",
    "data/environments/developer_placement_overrides.json",
    "data/environments/scenario_sequences/env06_7_shops_streets.json",
    "data/items/items.json",
    "data/events/events.json",
    "data/characters/characters.json",
    "data/characters/pools.json",
    "data/games/games.json",
    "data/games/scratch_tickets.json",
    "data/debt/lenders.json",
    "data/crew/crew.json",
    "data/crew/recruitment.json",
    "data/crew/jobs.json",
    "data/crew/plays.json",
    "data/crew/heist.json",
    "data/services/services.json",
    "data/travel/routes.json",
    "scripts/games/slot.gd",
    "scripts/games/pull_tabs.gd",
    "scripts/games/scratch_tickets.gd",
    "scripts/games/bar_dice.gd",
    "scripts/games/blackjack.gd",
    "scripts/games/video_poker.gd",
    "assets/art/environments/corner_store.png",
    "assets/art/environments/back_alley.png",
    "assets/art/environments/motel.png",
    "assets/art/environments/bar.png",
    "assets/art/environments/jazz_club.png",
    "assets/art/environments/gas_station_casino.png",
    "assets/art/environments/small_underground_casino.png",
    "assets/art/environments/grand_casino.png",
    "assets/art/game_scenes/slot.png",
    "assets/art/game_scenes/pull_tabs.png",
    "assets/art/game_scenes/bar_dice.png",
    "assets/art/game_scenes/blackjack.png",
    "assets/art/game_scenes/video_poker.png",
    "assets/art/game_scenes/poker.png"
)

$failures = New-Object System.Collections.Generic.List[string]

# health06_1 gdlint: keep lint configuration discoverable at repository root and
# run it when gdtoolkit is available. The project does not acquire a new runtime
# dependency; the deterministic source checks below remain active everywhere.
$gdLintConfigPath = Join-Path $root ".gdlintrc"
if (-not (Test-Path -LiteralPath $gdLintConfigPath)) {
    $failures.Add("Missing repository gdlint configuration: .gdlintrc")
} else {
    $gdLintConfig = Get-Content -LiteralPath $gdLintConfigPath -Raw
    foreach ($requiredPolicy in @("mixed indentation", "one separating blank line", "top-level functions use two", "(Script|Scene)")) {
        if (-not $gdLintConfig.Contains($requiredPolicy)) {
            $failures.Add(".gdlintrc is missing house-style policy: $requiredPolicy")
        }
    }
}

$shippingGdFiles = @(Get-ChildItem (Join-Path $root "scripts/core"),(Join-Path $root "scripts/games"),(Join-Path $root "scripts/ui") -Recurse -Filter "*.gd" -File)
$healthSourceRuleErrors = @(Invoke-Health06StaticSourceRules -Paths @($shippingGdFiles.FullName))
foreach ($sourceRuleError in $healthSourceRuleErrors) {
    $failures.Add($sourceRuleError)
}
foreach ($gdFile in $shippingGdFiles) {
    $lineNumber = 0
    foreach ($sourceLine in Get-Content -LiteralPath $gdFile.FullName) {
        $lineNumber++
        if ($sourceLine -match '^ +\S') {
            $failures.Add("GDScript indentation must use tabs: $(Get-ProjectRelativePath $gdFile.FullName):$lineNumber")
        }
        if ($sourceLine -match '^const\s+(?<name>[A-Za-z0-9_]+)\s*(?::?=)\s*preload\("(?<path>[^"]+)"\)') {
            $constantName = $Matches.name
            $resourcePath = $Matches.path
            $requiredSuffix = if ($resourcePath.EndsWith(".gd")) { "Script" } elseif ($resourcePath.EndsWith(".tscn")) { "Scene" } else { "" }
            if ($requiredSuffix -and -not $constantName.EndsWith($requiredSuffix)) {
                $failures.Add("Preload constant must end in ${requiredSuffix}: $(Get-ProjectRelativePath $gdFile.FullName):$lineNumber ($constantName)")
            }
        }
    }
}

$gdLintCommand = Get-Command gdlint -ErrorAction SilentlyContinue
if ($null -ne $gdLintCommand) {
    $gdLintOutput = & $gdLintCommand.Source @($shippingGdFiles.FullName) 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("gdlint failed:`n$($gdLintOutput -join "`n")")
    }
} elseif (-not $Quiet) {
    Write-Host "gdlint is not installed; repository-native style checks remain active."
}

$objectRootContractFixtures = @(
    @{ Label = "object"; Value = ('{"fixture":true}' | ConvertFrom-Json); Expected = $true },
    @{ Label = "array"; Value = ('[1,2]' | ConvertFrom-Json); Expected = $false },
    @{ Label = "null"; Value = ('null' | ConvertFrom-Json); Expected = $false },
    @{ Label = "string"; Value = ('"fixture"' | ConvertFrom-Json); Expected = $false },
    @{ Label = "number"; Value = ('7' | ConvertFrom-Json); Expected = $false },
    @{ Label = "boolean"; Value = ('true' | ConvertFrom-Json); Expected = $false }
)
foreach ($fixture in $objectRootContractFixtures) {
    if ((Test-JsonObjectRoot $fixture.Value) -ne $fixture.Expected) {
        $failures.Add("JSON object-root classifier contract failed for $($fixture.Label).")
    }
}

$foundationUiClassifierAllowedFixture = @'
const SEALED_ACTION_HOST_SKIP_ENVIRONMENT_TURN_ALLOWLIST := {
	"slot": ["slot_handpay_acknowledge"],
}
'@
$foundationUiClassifierAllowed = Get-FoundationUiContentSelectionScan $foundationUiClassifierAllowedFixture
if ([int]$foundationUiClassifierAllowed.HostSecurityAllowlistCount -ne 1 -or ([string]$foundationUiClassifierAllowed.ScanText).Contains('"slot"')) {
    $failures.Add("Foundation UI content-id classifier did not exempt only the exact host security allowlist literal.")
}
$foundationUiClassifierHostile = Get-FoundationUiContentSelectionScan ($foundationUiClassifierAllowedFixture + "`nvar hostile_content_choice := `"slot`"")
if (-not ([string]$foundationUiClassifierHostile.ScanText).Contains('"slot"')) {
    $failures.Add("Foundation UI content-id classifier hid a hardcoded slot outside the exact host security allowlist.")
}

foreach ($relative in $requiredFiles) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Missing required file: $relative")
    }
}

$scenarioAuditSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_audit.gd") -Raw
if ($scenarioAuditSource -match 'definitions\.size\(\)\s*==\s*1') {
    $failures.Add("Scenario sequence audit must not require a singleton catalog for hostile fixtures.")
}
foreach ($requiredAuditSeam in @(
    'HOSTILE_FIXTURE_SCENARIO_ID := "corner_store_delivery_day"',
    'static func hostile_fixture_report_for_definitions',
    'static func report_has_exact_shape'
)) {
    if (-not $scenarioAuditSource.Contains($requiredAuditSeam)) {
        $failures.Add("Scenario sequence audit is missing rollout seam: $requiredAuditSeam")
    }
}
$scenarioContractSource = Get-Content -LiteralPath (Join-Path $root "scripts/tests/foundation/scenario_sequence_contract.gd") -Raw
foreach ($requiredGrowthProbe in @(
    'for rollout_count_value in [13, 55]',
	'hostile_fixture_report_for_definitions(reversed_definitions)',
	'package_for_scenario(DELIVERY_SCENARIO_ID, expanded_catalog)',
	'"label": "unsupported_choice"',
	'base_collision_result',
	'broad_only_event_bridge'
)) {
    if (-not $scenarioContractSource.Contains($requiredGrowthProbe)) {
        $failures.Add("Scenario sequence contract is missing growth/authority probe: $requiredGrowthProbe")
    }
}
$runtimeDefinitionMatch = [regex]::Match(
    $scenarioContractSource,
    '(?ms)^static func _runtime_definition\(\) -> Dictionary:\r?\n(?<body>.*?)(?=^static func )'
)
if (-not $runtimeDefinitionMatch.Success) {
    $failures.Add("Scenario sequence contract is missing _runtime_definition for focused static validation.")
} else {
    $runtimeDefinitionBody = $runtimeDefinitionMatch.Groups['body'].Value
    foreach ($declaration in @('cleanup', 'cleanup_operations')) {
        $declarationCount = [regex]::Matches($runtimeDefinitionBody, "(?m)^`tvar $declaration(?:\s|:)").Count
        if ($declarationCount -ne 1) {
            $failures.Add("Scenario sequence _runtime_definition must declare $declaration exactly once (found $declarationCount).")
        }
    }
}
$scenarioEvidenceFiles = @(
    "tools/scenario_sequence_probe_support.gd",
    "tools/scenario_sequence_probe_main.gd",
    "tools/scenario_sequence_probe_main.tscn",
    "tools/scenario_sequence_visual_capture.ps1",
    "tools/scenario_sequence_web_capture.mjs",
    "tools/scenario_sequence_parity_performance.ps1"
)
foreach ($relative in $scenarioEvidenceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        $failures.Add("Executable scenario evidence file is missing: $relative")
    }
}
foreach ($relative in @("tools/scenario_sequence_visual_capture.ps1", "tools/scenario_sequence_parity_performance.ps1")) {
    $parseTokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative), [ref]$parseTokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        $failures.Add("Executable scenario evidence PowerShell syntax error in $relative`: $($parseError.Message)")
    }
}
$scenarioProbeSupportSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_probe_support.gd") -Raw
$scenarioProbeMainSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_probe_main.gd") -Raw
$scenarioProbeSceneSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_probe_main.tscn") -Raw
$scenarioVisualWrapperSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_visual_capture.ps1") -Raw
$scenarioWebCaptureSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_web_capture.mjs") -Raw
$scenarioParityWrapperSource = Get-Content -LiteralPath (Join-Path $root "tools/scenario_sequence_parity_performance.ps1") -Raw
foreach ($requiredEvidenceSeam in @(
    'PACKAGE_PATH := "res://data/environments/scenario_sequences/env06_7_shops_streets.json"',
    'SCENARIO_ID := "corner_store_delivery_day"',
    'PROOF_SEED := "corner_store_delivery_day_env06_6"',
    'static func canonical_semantic_sha256',
    'static func validate_probe_report',
    'static func validate_capture_manifest',
    'static func obstruction_target_contract',
    'EXPECTED_OBSTRUCTION_TARGET_IDS',
    'EXPECTED_TRACE_ROWS',
    '_validate_runtime_trace',
    'REQUIRED_PERFORMANCE_ROWS'
)) {
    if (-not $scenarioProbeSupportSource.Contains($requiredEvidenceSeam)) {
        $failures.Add("Scenario evidence support is missing fail-closed authority: $requiredEvidenceSeam")
    }
}
foreach ($requiredObstructionAuthority in @(
    '"scenario::delivery_event_gate"',
    '"scenario::delivery_exit"',
    '["inspect_manifest"]',
    '["ignore_delivery", "refuse_sort"]',
    '"semantic_role", record.get("role", "")',
    'action_origin_receipt_key',
    'action_origin_fingerprint'
)) {
    if (-not $scenarioProbeSupportSource.Contains($requiredObstructionAuthority)) {
        $failures.Add("Scenario obstruction support lost exact production target/action authority: $requiredObstructionAuthority")
    }
}
$expectedTraceRows = @(
    'arrival_delivery_blocked|arrival|active|', 'base_event_pre_request_gated|arrival|active|',
    'obstruction_overlay_zero_overlap|arrival|active|', 'hit_target_overlay_44_minimum|arrival|active|',
    'sorting_aisle_rerouted|sorting|active|', 'verification_station_ready|verification|active|',
    'awaiting_stock_choice|awaiting_stock|active|', 'base_event_request_delivered|awaiting_stock|active|',
    'partial_revisit_awaiting_stock|awaiting_stock|active|', 'resolution_repaired|resolution|aftermath|repaired',
    'terminal_revisit_repaired|resolution|aftermath|repaired', 'resolution_broken|resolution|aftermath|broken',
    'terminal_revisit_broken|resolution|aftermath|broken', 'resolution_refused|resolution|aftermath|refused',
    'terminal_revisit_refused|resolution|aftermath|refused', 'base_event_terminal_gated|resolution|aftermath|refused',
    'resolution_interrupted|resolution|aftermath|interrupted', 'terminal_revisit_interrupted|resolution|aftermath|interrupted',
    'expired_revisit_night_end|arrival|cleaned|', 'reduced_motion_arrival|arrival|active|',
    'small_screen_104x76|arrival|active|'
)
$traceBlock = [regex]::Match($scenarioProbeSupportSource, '(?s)const EXPECTED_TRACE_ROWS := \[(.*?)\]\s*const PERFORMANCE_BUDGETS')
$actualTraceRows = @()
if ($traceBlock.Success) {
    foreach ($traceMatch in [regex]::Matches($traceBlock.Groups[1].Value, '\{"label": "([^"]+)", "phase_id": "([^"]+)", "status": "([^"]+)", "outcomes": \[([^\]]*)\]\}')) {
        $outcome = $traceMatch.Groups[4].Value.Replace('"', '').Trim()
        $actualTraceRows += "$($traceMatch.Groups[1].Value)|$($traceMatch.Groups[2].Value)|$($traceMatch.Groups[3].Value)|$outcome"
    }
}
if ($actualTraceRows.Count -ne 21 -or (Compare-Object -ReferenceObject $expectedTraceRows -DifferenceObject $actualTraceRows -SyncWindow 0)) {
    $failures.Add("Scenario evidence support lost the exact 21-row runtime label/phase/status/outcome contract.")
}
foreach ($requiredMainSeam in @(
    'extends Node',
    'res://scenes/main.tscn',
    'start_foundation_run", ProbeSupport.PROOF_SEED, {}, false',
    'current_environment_view_snapshot',
    'activate_interactable_object',
    'global_rect_for_object',
    'object_id_at_local_position',
    'scenario_reenter_current',
    'scenario_apply_expiry',
    'RenderingServer.frame_post_draw',
    'current_environment_result_feedback_snapshot',
    'environment_reserved_global_rect',
    '_obstruction_target_evidence',
    'obstruction_center_hit_count',
    'intersection(reserved).get_area() > 0.0',
    'load_foundation_run',
    'ENV06_6_SEQUENCE_PROBE='
)) {
    if (-not $scenarioProbeMainSource.Contains($requiredMainSeam)) {
        $failures.Add("Scenario evidence main scene is missing production seam: $requiredMainSeam")
    }
}
if ($scenarioProbeMainSource.Contains('scenario_flush_facts') -or $scenarioProbeMainSource.Contains('_interactable_object_view_list') -or $scenarioProbeMainSource.Contains('var scenario_added := false') -or $scenarioProbeMainSource.Contains('scenario_hit_rects.size() != 1') -or $scenarioProbeMainSource.Contains('intersection(reserved).get_area() > 0.5')) {
    $failures.Add("Scenario evidence main scene must not manually flush facts, use the private interactable list, or collapse the two production obstruction targets.")
}
if (-not $scenarioProbeSceneSource.Contains('type="Node"') -or -not $scenarioProbeSceneSource.Contains('scenario_sequence_probe_main.gd')) {
    $failures.Add("Scenario evidence entry scene must attach the Node-backed probe script.")
}
if ($scenarioVisualWrapperSource.Contains('"--headless"') -or -not $scenarioVisualWrapperSource.Contains('scenario_sequence_probe_main.tscn') -or -not $scenarioVisualWrapperSource.Contains('Get-FileHash') -or -not $scenarioVisualWrapperSource.Contains('BTH_DISTRIBUTION_DATA_ROOT') -or -not $scenarioVisualWrapperSource.Contains('expectedRuntimeTraceIds') -or -not $scenarioVisualWrapperSource.Contains('expectedRuntimeStateById')) {
    $failures.Add("Scenario visual wrapper must be direct, windowed, isolated, and byte-hash fail-closed.")
}
foreach ($requiredWebSeam in @('launchPersistentContext', 'Emulation.setCPUThrottlingRate', 'pageerror', 'requestfailed', 'ENV06_6_SEQUENCE_PROBE=')) {
    if (-not $scenarioWebCaptureSource.Contains($requiredWebSeam)) {
        $failures.Add("Scenario Web capture is missing fail-closed browser seam: $requiredWebSeam")
    }
}
foreach ($requiredParitySeam in @(
    'native_process_1', 'native_process_2', 'web_process_1', 'web_process_2', 'native_web_semantic_exact',
    'transientAddon', 'BTH_DISTRIBUTION_DATA_ROOT', 'run_transient_scons.py',
    'expectedRuntimeTraceLabels', 'expectedRuntimeStateByLabel', 'semantic.checkpoints',
    'Copy-Item -LiteralPath $canonicalAddon', 'Required Windows host library is unavailable',
    'Get-ChildItem -LiteralPath (Join-Path $transientAddon "bin") -Filter "*.wasm"'
)) {
    if (-not $scenarioParityWrapperSource.Contains($requiredParitySeam)) {
        $failures.Add("Scenario parity/performance wrapper is missing acceptance seam: $requiredParitySeam")
    }
}
if ($scenarioParityWrapperSource.Contains('tools\build_native_solver.ps1') -or $scenarioParityWrapperSource.Contains('Join-Path $root "addons"')) {
    $failures.Add("Scenario parity/performance Web build must keep compiler outputs inside its ignored OutDir.")
}
$scenarioPresentationSource = Get-Content -LiteralPath (Join-Path $root "scripts/tests/foundation/scenario_presentation_contract.gd") -Raw
foreach ($requiredOverlayProbe in @('collision_overlay', 'z_equal_augment', 'sweep_unique')) {
    if (-not $scenarioPresentationSource.Contains($requiredOverlayProbe)) {
        $failures.Add("Scenario presentation contract is missing collision probe: $requiredOverlayProbe")
    }
}
foreach ($requiredLiveReconciliationProbe in @(
    '_check_live_base_record_reconciliation', 'lender:brother_in_law',
    'event:call_brother_in_law', 'PRIVATE_PHONE_RUNTIME',
    'Scenario live reconciliation resurrected an absent dynamic service/lender',
    'Production room rendering did not show Counter Phone'
)) {
    if (-not $scenarioPresentationSource.Contains($requiredLiveReconciliationProbe)) {
        $failures.Add("Scenario presentation contract is missing live base reconciliation probe: $requiredLiveReconciliationProbe")
    }
}
$environmentInteractionControllerSource = Get-Content -LiteralPath (Join-Path $root "scripts/ui/environment_interaction_controller.gd") -Raw
foreach ($requiredLiveReconciliationSeam in @(
    'LIVE_AVAILABILITY_ACTION_FIELDS', 'LIVE_PRESENTATION_FIELDS',
    'LIVE_RENDER_FIELDS', 'LIVE_MEMBERSHIP_OBJECT_TYPES',
    '_requires_live_membership'
)) {
    if (-not $environmentInteractionControllerSource.Contains($requiredLiveReconciliationSeam)) {
        $failures.Add("Environment interaction controller is missing live base reconciliation seam: $requiredLiveReconciliationSeam")
    }
}

$assetDimensions = @{
    "assets/art/environments/corner_store.png" = @(900, 430)
    "assets/art/environments/back_alley.png" = @(900, 430)
    "assets/art/environments/motel.png" = @(900, 430)
    "assets/art/environments/bar.png" = @(900, 430)
    "assets/art/environments/jazz_club.png" = @(900, 430)
    "assets/art/environments/gas_station_casino.png" = @(900, 430)
    "assets/art/environments/small_underground_casino.png" = @(900, 430)
    "assets/art/environments/grand_casino.png" = @(900, 430)
    "assets/art/game_scenes/slot.png" = @(900, 430)
    "assets/art/game_scenes/pull_tabs.png" = @(900, 430)
    "assets/art/game_scenes/bar_dice.png" = @(900, 430)
    "assets/art/game_scenes/blackjack.png" = @(900, 430)
    "assets/art/game_scenes/video_poker.png" = @(900, 430)
    "assets/art/game_scenes/poker.png" = @(900, 430)
}

$iconFolders = @("assets/art/items", "assets/art/events", "assets/art/games", "assets/art/ui")
foreach ($folder in $iconFolders) {
    $iconRoot = Join-Path $root $folder
    if (Test-Path -LiteralPath $iconRoot) {
        foreach ($iconFile in Get-ChildItem -LiteralPath $iconRoot -Filter "*.png" -File) {
            $relativeIcon = Get-ProjectRelativePath $iconFile.FullName
            $assetDimensions[$relativeIcon] = @(32, 32)
        }
    }
}

# These are scalable menu surfaces stored beside the 32x32 UI icons. Keep
# their authored source dimensions explicit so the generic icon contract does
# not misclassify them as HUD glyphs.
$assetDimensions["assets/art/ui/beat_the_house_logo.png"] = @(1141, 440)
$assetDimensions["assets/art/ui/main_menu_button_plate.png"] = @(384, 192)

foreach ($entry in $assetDimensions.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (-not (Test-Path -LiteralPath $path)) {
        $failures.Add("Missing required art asset: $($entry.Key)")
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 24 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x4e -or $bytes[3] -ne 0x47) {
        $failures.Add("Art asset is not a readable PNG: $($entry.Key)")
        continue
    }
    $width = [BitConverter]::ToUInt32(([byte[]]($bytes[19], $bytes[18], $bytes[17], $bytes[16])), 0)
    $height = [BitConverter]::ToUInt32(([byte[]]($bytes[23], $bytes[22], $bytes[21], $bytes[20])), 0)
    $expected = $entry.Value
    if ($width -ne $expected[0] -or $height -ne $expected[1]) {
        $failures.Add("Art asset has wrong dimensions: $($entry.Key) is ${width}x${height}, expected $($expected[0])x$($expected[1])")
    }
}

$objectJsonFiles = @(
    "data/art/art_manifest.json",
    "data/art/attribute_glyphs.json",
    "data/games/bar_dice_game_ritual_v1.json",
    "data/games/showdown_duel_game_ritual_v1.json",
    "data/games/showdown_duel_ritual_v1.json",
    "data/games/scratch_ticket_regions.json",
    "data/environments/scenarios.json",
    "data/environments/placement_surfaces.json",
    "data/environments/developer_placement_overrides.json",
    "data/story/character_chains.json"
)
$objectJsonDirectories = @(
    "data/environments/scenario_sequences/"
)

$jsonFiles = Get-ChildItem -LiteralPath (Join-Path $root "data") -Filter "*.json" -File -Recurse -ErrorAction SilentlyContinue

foreach ($jsonFile in $jsonFiles) {
    try {
        $content = Get-Content -LiteralPath $jsonFile.FullName -Raw
        $parsed = $content | ConvertFrom-Json
        if ($null -eq $parsed) {
            $failures.Add("JSON file parsed to null: $($jsonFile.FullName)")
        }
        $relativeJson = Get-ProjectRelativePath $jsonFile.FullName
        $requiresObject = $objectJsonFiles -contains $relativeJson
        foreach ($directory in $objectJsonDirectories) {
            if ($relativeJson.StartsWith($directory, [System.StringComparison]::OrdinalIgnoreCase)) {
                $requiresObject = $true
                break
            }
        }
        if ($requiresObject) {
            if (-not (Test-JsonObjectRoot $parsed)) {
                $failures.Add("JSON file must contain an object: $($jsonFile.FullName)")
            }
        }
        elseif ($parsed -isnot [System.Array]) {
            $failures.Add("JSON file must contain an array: $($jsonFile.FullName)")
        }
    }
    catch {
        $failures.Add("Invalid JSON in $($jsonFile.FullName): $($_.Exception.Message)")
    }
}

$placementOverridePath = Join-Path $root "data/environments/developer_placement_overrides.json"
try {
    $placementOverrides = Get-Content -LiteralPath $placementOverridePath -Raw | ConvertFrom-Json
    if (-not (Test-JsonObjectRoot $placementOverrides) -or [int]$placementOverrides.schema_version -ne 1 -or -not (Test-JsonObjectRoot $placementOverrides.rooms)) {
        $failures.Add("Developer placement overrides require schema_version 1 and an object-valued rooms collection.")
    }
    else {
        $allowedPlacementFields = @("object_slot_positions", "scenario_object_slot_positions", "category_slot_positions")
        foreach ($roomProperty in $placementOverrides.rooms.PSObject.Properties) {
            if (-not (Test-JsonObjectRoot $roomProperty.Value)) {
                $failures.Add("Developer placement room must be an object: $($roomProperty.Name)")
                continue
            }
            foreach ($fieldProperty in $roomProperty.Value.PSObject.Properties) {
                if ($allowedPlacementFields -notcontains $fieldProperty.Name -or -not (Test-JsonObjectRoot $fieldProperty.Value)) {
                    $failures.Add("Developer placement room $($roomProperty.Name) has an unsupported placement collection: $($fieldProperty.Name)")
                    continue
                }
                foreach ($slotProperty in $fieldProperty.Value.PSObject.Properties) {
                    $coordinates = @($slotProperty.Value)
                    if ($coordinates.Count -ne 2) {
                        $failures.Add("Developer placement $($roomProperty.Name)/$($fieldProperty.Name)/$($slotProperty.Name) must contain exactly two coordinates.")
                        continue
                    }
                    foreach ($coordinate in $coordinates) {
                        $number = 0.0
                        if (-not [double]::TryParse([string]$coordinate, [ref]$number) -or [double]::IsNaN($number) -or [double]::IsInfinity($number)) {
                            $failures.Add("Developer placement $($roomProperty.Name)/$($fieldProperty.Name)/$($slotProperty.Name) contains a non-finite coordinate.")
                        }
                    }
                }
            }
        }
    }
}
catch {
    $failures.Add("Developer placement override schema validation failed: $($_.Exception.Message)")
}

$readme = Get-Content -LiteralPath (Join-Path $root "README.md") -Raw -Encoding UTF8
$mojibakeMarkers = @(
    [string][char]0x00E2,
    [string][char]0xFFFD,
    [string][char]0x20AC
)
foreach ($marker in $mojibakeMarkers) {
    if ($readme.Contains($marker)) {
        $failures.Add("README still contains broken character marker with code point U+$('{0:X4}' -f [int][char]$marker)")
    }
}

$expectedClasses = @{
    "scripts/core/run_state.gd" = "class_name RunState"
    "scripts/core/environment_instance.gd" = "class_name EnvironmentInstance"
    "scripts/core/game_module.gd" = "class_name GameModule"
    "scripts/core/item_effect.gd" = "class_name ItemEffect"
    "scripts/core/event_module.gd" = "class_name EventModule"
    "scripts/core/platform_services.gd" = "class_name PlatformServices"
    "scripts/core/profile_inventory.gd" = "class_name ProfileInventory"
    "scripts/core/content_library.gd" = "class_name ContentLibrary"
    "scripts/core/scenario_engine.gd" = "class_name ScenarioEngine"
    "scripts/core/crew_recruitment_model.gd" = "class_name CrewRecruitmentModel"
    "scripts/core/rng_stream.gd" = "class_name RngStream"
    "scripts/core/run_generator.gd" = "class_name RunGenerator"
    "scripts/core/save_service.gd" = "class_name SaveService"
}

foreach ($entry in $expectedClasses.GetEnumerator()) {
    $path = Join-Path $root $entry.Key
    if (Test-Path -LiteralPath $path) {
        $content = Get-Content -LiteralPath $path -Raw
        if (-not $content.Contains($entry.Value)) {
            $failures.Add("Expected $($entry.Value) in $($entry.Key)")
        }
    }
}

$exportPresets = Get-Content -LiteralPath (Join-Path $root "export_presets.cfg") -Raw
$windowsPresetPattern = '(?s)name="Windows Steam".*?\[preset\.0\.options\].*?binary_format/embed_pck=true'
if ($exportPresets -notmatch $windowsPresetPattern) {
    $failures.Add("Windows Steam export must embed its PCK so BeatTheHouse.exe is standalone.")
}

$authoredMusicRoot = Join-Path $root "assets/audio/music"
foreach ($wavFile in Get-ChildItem -LiteralPath $authoredMusicRoot -Filter "*.wav" -File -Recurse -ErrorAction SilentlyContinue) {
    $importPath = "$($wavFile.FullName).import"
    if (-not (Test-Path -LiteralPath $importPath)) {
        $failures.Add("Authored music source is missing its portable Keep File import contract: $(Get-ProjectRelativePath $wavFile.FullName)")
        continue
    }
    $importContent = Get-Content -LiteralPath $importPath -Raw
    if ($importContent -notmatch '(?m)^importer="keep"\s*$') {
        $failures.Add("Authored music source must use Keep File for exact runtime PCM decoding: $(Get-ProjectRelativePath $wavFile.FullName)")
    }
}

$trackedGeneratedFiles = @()
try {
    $trackedGeneratedFiles = @(git -C $root ls-files "*.import" "*.uid" 2>$null)
}
catch {
    $failures.Add("Could not inspect git-tracked generated files: $($_.Exception.Message)")
}
$reviewedArchivedUidPaths = @{}
$archiveToolManifestPath = Join-Path $root "tools/archive/health06_1_row_tools_manifest.json"
if (-not (Test-Path -LiteralPath $archiveToolManifestPath -PathType Leaf)) {
    $failures.Add("Reviewed archive-tool manifest is missing; tracked UID companions cannot be admitted.")
}
else {
    try {
        $archiveToolManifest = Get-Content -LiteralPath $archiveToolManifestPath -Raw | ConvertFrom-Json
        foreach ($companion in @($archiveToolManifest.companion_moves)) {
            $destination = ([string]$companion.destination).Replace('\', '/').TrimStart('/')
            if ($destination -notmatch '^tools/archive/.+\.gd\.uid$') {
                $failures.Add("Reviewed UID companion has an invalid archive destination: $destination")
                continue
            }
            if ($reviewedArchivedUidPaths.ContainsKey($destination)) {
                $failures.Add("Reviewed UID companion destination is duplicated: $destination")
                continue
            }
            $uidPath = Join-Path $root $destination
            $scriptPath = $uidPath -replace '\.uid$', ''
            if (-not (Test-Path -LiteralPath $uidPath -PathType Leaf) -or -not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                $failures.Add("Reviewed UID companion or its archived GDScript is missing: $destination")
                continue
            }
            $uidRawText = Get-Content -LiteralPath $uidPath -Raw
            $canonicalUidText = $uidRawText.Replace("`r`n", "`n").Replace("`r", "`n")
            if ($canonicalUidText -notmatch '^uid://[a-z0-9]+\n\z') {
                $failures.Add("Reviewed UID companion is malformed: $destination")
                continue
            }
            $uidText = $canonicalUidText.Substring(0, $canonicalUidText.Length - 1)
            $uidSha = [Security.Cryptography.SHA256]::Create()
            try {
                # Manifest hashes are canonical LF text hashes so checkout line-ending
                # conversion cannot create platform-specific false drift.
                $canonicalBytes = [Text.Encoding]::UTF8.GetBytes($canonicalUidText)
                $actualHash = ([BitConverter]::ToString($uidSha.ComputeHash($canonicalBytes))).Replace("-", "").ToLowerInvariant()
            }
            finally { $uidSha.Dispose() }
            if ($actualHash -cne ([string]$companion.sha256).ToLowerInvariant()) {
                $failures.Add("Reviewed UID companion hash drifted: $destination")
                continue
            }
            $reviewedArchivedUidPaths[$destination] = $true
        }
    }
    catch {
        $failures.Add("Could not validate reviewed archive UID companions: $($_.Exception.Message)")
    }
}
foreach ($trackedGeneratedFile in $trackedGeneratedFiles) {
    $relativeGeneratedPath = ([string]$trackedGeneratedFile).Trim().Replace('\', '/')
    $isAuthoredMusicKeepContract = $relativeGeneratedPath -match '^assets/audio/music/.+\.wav\.import$'
    $isReviewedArchivedUid = $reviewedArchivedUidPaths.ContainsKey($relativeGeneratedPath)
    if (-not [string]::IsNullOrWhiteSpace($relativeGeneratedPath) -and -not $isAuthoredMusicKeepContract -and -not $isReviewedArchivedUid) {
        $failures.Add("Generated Godot metadata must not be git-tracked: $relativeGeneratedPath")
    }
}

try {
    $censusScript = Join-Path $root "tools/function_census.ps1"
    if (Test-Path -LiteralPath $censusScript) {
        $censusOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $censusScript -Check -Quiet 2>&1
        $censusExitCode = $LASTEXITCODE
        if ($censusExitCode -ne 0) {
            $message = ($censusOutput | ForEach-Object { [string]$_ }) -join " "
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = "tools/function_census.ps1 exited with code $censusExitCode."
            }
            $failures.Add("Function census generation failed: $message")
        }
    }
}
catch {
    $failures.Add("Function census generation failed: $($_.Exception.Message)")
}

function Get-ProjectText {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return ""
    }
    return Get-Content -LiteralPath $path -Raw
}

function Require-Text {
    param([string]$RelativePath, [string]$Needle, [string]$Message)
    $content = Get-ProjectText $RelativePath
    if (-not $content.Contains($Needle)) {
        $failures.Add($Message)
    }
}

function Require-TextInAny {
    param([string[]]$RelativePaths, [string]$Needle, [string]$Message)
    foreach ($relativePath in $RelativePaths) {
        $content = Get-ProjectText $relativePath
        if ($content.Contains($Needle)) {
            return
        }
    }
    $failures.Add($Message)
}

function Forbid-Text {
    param([string]$RelativePath, [string]$Needle, [string]$Message)
    $content = Get-ProjectText $RelativePath
    if ($content.Contains($Needle)) {
        $failures.Add($Message)
    }
}

function Read-JsonArray {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        return @()
    }
    try {
        $parsed = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($parsed -is [System.Array]) {
            return @($parsed)
        }
        return @($parsed)
    }
    catch {
        return @()
    }
}

function Get-JsonProperty {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    if ($property.Value -is [System.Array]) {
        return ,$property.Value
    }
    return $property.Value
}

function Test-JsonProperty {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) {
        return $false
    }
    return $null -ne $Object.PSObject.Properties[$Name]
}

function New-ContentIdSet {
    param([string]$RelativePath)
    $ids = @{}
    foreach ($entry in (Read-JsonArray $RelativePath)) {
        $id = [string](Get-JsonProperty $entry "id")
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            $ids[$id] = $true
        }
    }
    return $ids
}

function Assert-JsonRequiredFields {
    param([string]$RelativePath, [string]$Label, [string[]]$Fields)
    $entries = Read-JsonArray $RelativePath
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $entry = $entries[$index]
        $id = [string](Get-JsonProperty $entry "id")
        if ([string]::IsNullOrWhiteSpace($id)) {
            $failures.Add("$Label[$index] is missing required id.")
        }
        foreach ($field in $Fields) {
            if (-not (Test-JsonProperty $entry $field)) {
                $name = if ([string]::IsNullOrWhiteSpace($id)) { "[$index]" } else { $id }
                $failures.Add("$Label $name is missing required field: $field")
            }
        }
    }
}

function Assert-JsonUniqueIds {
    param([string]$RelativePath, [string]$Label)
    $seen = @{}
    $entries = Read-JsonArray $RelativePath
    for ($index = 0; $index -lt $entries.Count; $index++) {
        $id = [string](Get-JsonProperty $entries[$index] "id")
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }
        if ($seen.ContainsKey($id)) {
            $failures.Add("$Label contains duplicate id: $id")
        }
        else {
            $seen[$id] = $true
        }
    }
}

function Assert-IdArrayReferences {
    param([string]$Label, [object]$Values, [hashtable]$ValidIds)
    if ($null -eq $Values) {
        return
    }
    $normalizedValues = if ($Values -is [System.Array]) { @($Values) } else { @($Values) }
    foreach ($value in $normalizedValues) {
        $id = [string]$value
        if ([string]::IsNullOrWhiteSpace($id)) {
            $failures.Add("$Label contains an empty id.")
        }
        elseif (-not $ValidIds.ContainsKey($id)) {
            $failures.Add("$Label references unknown id: $id")
        }
    }
}

function ConvertTo-ValueArray {
    param([object]$Value)
    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [System.Array]) {
        return @($Value)
    }
    return @($Value)
}

function Assert-DeltaKeys {
    param([string]$Label, [object]$Delta, [string[]]$AllowedKeys)
    if ($null -eq $Delta) {
        return
    }
    if ($Delta -isnot [pscustomobject]) {
        $failures.Add("$Label must be an object when present.")
        return
    }
    foreach ($property in $Delta.PSObject.Properties) {
        if ($AllowedKeys -notcontains $property.Name) {
            $failures.Add("$Label uses unsupported result key: $($property.Name)")
        }
    }
}

function Assert-NonNegativeIntProperty {
    param([string]$Label, [object]$Object, [string]$PropertyName)
    if (-not (Test-JsonProperty $Object $PropertyName)) {
        return
    }
    try {
        $value = [int](Get-JsonProperty $Object $PropertyName)
        if ($value -lt 0) {
            $failures.Add("$Label $PropertyName must be non-negative.")
        }
    }
    catch {
        $failures.Add("$Label $PropertyName must be an integer.")
    }
}

function Assert-ArtAssetPath {
    param([string]$Label, [object]$Object)
    $assetPath = [string](Get-JsonProperty $Object "asset_path")
    if ([string]::IsNullOrWhiteSpace($assetPath)) {
        $failures.Add("$Label must define asset_path for replaceable object art.")
        return
    }
    if (-not $assetPath.StartsWith("res://assets/art/")) {
        $failures.Add("$Label asset_path must stay under res://assets/art/: $assetPath")
        return
    }
    $relativeAssetPath = $assetPath.Substring(6).Replace("/", "\")
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativeAssetPath))) {
        $failures.Add("$Label references missing asset_path: $assetPath")
    }
}

function Assert-EnvironmentLayoutSpots {
    param([string]$ArchetypeId, [object]$Layout)
    if ($null -eq $Layout) {
        return
    }
    if ($Layout -isnot [pscustomobject]) {
        $failures.Add("environment $ArchetypeId layout must be an object when present.")
        return
    }
    $spotFields = @("game_spots", "event_spots", "item_spots", "shopkeeper_spots", "travel_spots", "service_spots", "lender_spots", "numbers_spots", "numbers_silas_spots")
    foreach ($field in $spotFields) {
        $spots = Get-JsonProperty $Layout $field
        if ($null -eq $spots) {
            continue
        }
        if ($spots -isnot [array]) {
            $failures.Add("environment $ArchetypeId layout.$field must be an array of [x, y] board coordinates.")
            continue
        }
        $spotList = @($spots)
        if ($spotList.Count -ge 2 -and $spotList[0] -isnot [array] -and $spotList[0] -isnot [pscustomobject] -and $spotList[1] -isnot [array] -and $spotList[1] -isnot [pscustomobject]) {
            $spotList = @(, @($spotList[0], $spotList[1]))
        }
        for ($i = 0; $i -lt $spotList.Count; $i++) {
            $spot = $spotList[$i]
            $x = $null
            $y = $null
            if ($spot -is [array] -and $spot.Count -ge 2) {
                $x = $spot[0]
                $y = $spot[1]
            }
            elseif ($spot -is [pscustomobject]) {
                $x = Get-JsonProperty $spot "x"
                $y = Get-JsonProperty $spot "y"
            }
            else {
                $failures.Add("environment $ArchetypeId layout.$field[$i] must be [x, y] or an object with x/y.")
                continue
            }
            try {
                $xi = [int]$x
                $yi = [int]$y
                if ($xi -lt 0 -or $xi -gt 900 -or $yi -lt 0 -or $yi -gt 430) {
                    $failures.Add("environment $ArchetypeId layout.$field[$i] must stay within the 900x430 board.")
                }
            }
            catch {
                $failures.Add("environment $ArchetypeId layout.$field[$i] must use numeric x/y coordinates.")
            }
        }
    }
}

$deprecatedDemoFiles = @(
    "scripts/ui/main.gd",
    "scripts/core/runtime_content.gd",
    "scripts/core/game_ui_module.gd",
    "scripts/games/bar_dice_ui.gd",
    "scripts/games/blackjack_ui.gd",
    "scripts/games/last_chance_ui.gd",
    "scripts/games/poker_ui.gd",
    "scripts/games/pull_tabs_ui.gd",
    "scripts/games/scratch_tickets_ui.gd",
    "scripts/games/slots_ui.gd",
    "scripts/games/street_dice_ui.gd",
    "scripts/games/three_card_monte_ui.gd",
    "scripts/games/video_poker_ui.gd",
    "data/runtime/core_content.json",
    "data/runtime/environment_slots.json",
    "data/runtime/icon_sprites.json",
    "tools/capture_environment_screens.gd",
    "tools/capture_game_screens.gd",
    "tools/export_runtime_content.gd",
    "tools/generate_pixel_art.gd",
    "tools/playtest_30_victories.gd",
    "tools/playtest_demo.gd",
    "docs/RUNTIME_CONTENT.md"
)
foreach ($relativeDemoPath in $deprecatedDemoFiles) {
    if (Test-Path -LiteralPath (Join-Path $root $relativeDemoPath)) {
        $failures.Add("Deprecated demo runtime file remains in the production path: $relativeDemoPath")
    }
}

$mainSceneText = Get-ProjectText "scenes/main.tscn"
if (-not $mainSceneText.Contains('path="res://scripts/ui/foundation_main.gd"')) {
    $failures.Add("Active main scene is not wired to the foundation UI shell.")
}
if ($mainSceneText.Contains('path="res://scripts/ui/main.gd"')) {
    $failures.Add("Active main scene is still wired to the demo runtime main.gd.")
}

$foundationUi = "scripts/ui/foundation_main.gd"
Require-Text $foundationUi "ContentLibrary.new()" "Foundation UI shell must load content through ContentLibrary."
Require-Text $foundationUi "RunState.new()" "Foundation UI shell must own runs through RunState."
Require-Text $foundationUi "RunGenerator.new(library)" "Foundation UI shell must generate environments through RunGenerator."
Require-Text $foundationUi "GameModule" "Foundation UI shell must route gameplay through GameModule."
Require-Text $foundationUi "RunActionServiceScript.new()" "Foundation UI shell must route item/hook actions through RunActionService."
Require-Text "scripts/core/run_action_service.gd" "ItemEffectScript.new()" "RunActionService must route item effects through ItemEffect."
Require-Text $foundationUi "EventModule.new()" "Foundation UI shell must route events through EventModule."
Require-Text $foundationUi "save_service.save_run" "Foundation UI shell must save runs through SaveService."
Require-Text $foundationUi "save_service.load_run" "Foundation UI shell must load runs through SaveService."
Require-Text $foundationUi "PlatformServices.new()" "Foundation UI shell must keep platform calls behind PlatformServices."
Require-Text $foundationUi "run_state.create_rng()" "Foundation UI shell must resolve simulation through RunState/RngStream."
Forbid-Text $foundationUi "RuntimeContent" "Foundation UI shell must not depend on RuntimeContent."
Forbid-Text $foundationUi "GameUiModule" "Foundation UI shell must not instantiate GameUiModule."
Forbid-Text $foundationUi "core_content.json" "Foundation UI shell must not depend on data/runtime/core_content.json."
Forbid-Text $foundationUi 'preload("res://data/runtime' "Foundation UI shell must not load data/runtime paths."
Forbid-Text $foundationUi 'load("res://data/runtime' "Foundation UI shell must not load data/runtime paths."

$contentLibrary = "scripts/core/content_library.gd"
$requiredPackStrings = @(
    "res://data/environments/archetypes.json",
    "res://data/games/games.json",
    "res://data/items/items.json",
    "res://data/events/events.json",
    "res://data/characters/characters.json",
    "res://data/characters/pools.json",
    "res://data/challenges/challenges.json",
    "res://data/debt/lenders.json",
    "res://data/services/services.json",
    "res://data/travel/routes.json"
)
foreach ($packPath in $requiredPackStrings) {
    Require-Text $contentLibrary $packPath "ContentLibrary is missing README data pack path: $packPath"
}
Forbid-Text $contentLibrary "RuntimeContent" "ContentLibrary must not use RuntimeContent as a foundation loader."
Forbid-Text $contentLibrary "core_content.json" "ContentLibrary must not load data/runtime/core_content.json."
Forbid-Text $contentLibrary "res://data/runtime" "ContentLibrary must not load data/runtime paths."

$foundationTestFiles = @()
$foundationTestFiles += @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/foundation") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })
$foundationTestFiles += @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/ui_scene") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })
$foundationCheckFiles = @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/foundation") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })
$uiSceneCheckFiles = @(Get-ChildItem -LiteralPath (Join-Path $root "scripts/tests/ui_scene") -Filter "*.gd" | ForEach-Object { Get-ProjectRelativePath $_.FullName })

# Game surface modules render against the real canvas in production and the
# compact SurfaceHarness in Foundation checks. Keep every directly reachable
# surface/draw call represented in the harness so production API growth cannot
# turn a Contract run into a late RefCounted method-not-found failure.
$surfaceHarnessPath = Join-Path $root "scripts/tests/foundation/check_core_content.gd"
$surfaceHarnessSource = [System.IO.File]::ReadAllText($surfaceHarnessPath)
$surfaceHarnessBlock = [regex]::Match($surfaceHarnessSource, '(?ms)^class SurfaceHarness:\r?\n(?<body>.*?)(?=^[^\t\r\n])')
if (-not $surfaceHarnessBlock.Success) {
    $failures.Add("Could not locate the Foundation SurfaceHarness class body.")
} else {
    $surfaceHarnessMethods = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($methodMatch in [regex]::Matches($surfaceHarnessBlock.Groups['body'].Value, '(?m)^\tfunc\s+([A-Za-z0-9_]+)\s*\(')) {
        [void]$surfaceHarnessMethods.Add($methodMatch.Groups[1].Value)
    }
    $requiredSurfaceMethods = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.HashSet[string]]' ([System.StringComparer]::Ordinal)
    $directSurfaceCallPattern = [regex]'\bsurface\s*\.\s*((?:surface|draw)_[A-Za-z0-9_]+)\s*\('
    $dynamicSurfaceCallPattern = [regex]'\bsurface\s*\.\s*(?:call|has_method)\s*\(\s*["''](surface_[A-Za-z0-9_]+)["'']'
    foreach ($gameScript in Get-ChildItem -LiteralPath (Join-Path $root "scripts/games") -Filter "*.gd" -File -Recurse) {
        $gameSource = [System.IO.File]::ReadAllText($gameScript.FullName)
        foreach ($callMatch in @($directSurfaceCallPattern.Matches($gameSource)) + @($dynamicSurfaceCallPattern.Matches($gameSource))) {
            $methodName = $callMatch.Groups[1].Value
            if (-not $requiredSurfaceMethods.ContainsKey($methodName)) {
                $requiredSurfaceMethods[$methodName] = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
            }
            [void]$requiredSurfaceMethods[$methodName].Add((Get-ProjectRelativePath $gameScript.FullName))
        }
    }
    foreach ($methodName in @($requiredSurfaceMethods.Keys | Sort-Object)) {
        if (-not $surfaceHarnessMethods.Contains($methodName)) {
            $sources = @($requiredSurfaceMethods[$methodName] | Sort-Object)
            $failures.Add("SurfaceHarness is missing game-called method $methodName (sources=$($sources -join ', ')).")
        }
    }
    if (-not $surfaceHarnessSource.Contains('surface_add_invisible_hit(rect, action, index, false)')) {
        $failures.Add("SurfaceHarness exact-invisible hits must disable touch-target expansion.")
    }
    if (-not $surfaceHarnessSource.Contains('return hovered_index if hovered_action == action else -1')) {
        $failures.Add("SurfaceHarness hovered-index lookup must mirror GameSurfaceCanvas semantics.")
    }
}
$forbiddenFoundationTestTokens = @(
    "RuntimeContentScript",
    "runtime_content.gd",
    "RuntimeContent.new",
    "GameUiModuleScript",
    "game_ui_module.gd",
    "GameUiModule.new",
    "core_content.json"
)
foreach ($testFile in $foundationTestFiles) {
    foreach ($token in $forbiddenFoundationTestTokens) {
        Forbid-Text $testFile $token "Foundation validation test $testFile must not depend on demo runtime token: $token"
    }
}

Require-TextInAny $foundationCheckFiles "ContentLibraryScript.new()" "Foundation tests must load content through ContentLibrary."
Require-TextInAny $foundationCheckFiles "RunGeneratorScript.new" "Foundation tests must exercise RunGenerator."
Require-TextInAny $foundationCheckFiles "EnvironmentInstance" "Foundation tests must exercise EnvironmentInstance."
Require-TextInAny $foundationCheckFiles "GameModule" "Foundation tests must exercise GameModule."
Require-TextInAny $foundationCheckFiles "ItemEffect.new()" "Foundation tests must exercise ItemEffect."
Require-TextInAny $foundationCheckFiles "EventModule.new()" "Foundation tests must exercise EventModule."
Require-TextInAny $foundationCheckFiles "SaveServiceScript.new()" "Foundation tests must exercise SaveService."
Require-TextInAny $foundationCheckFiles "RngStream.new()" "Foundation tests must exercise RngStream."
Require-TextInAny $foundationCheckFiles "PlatformServicesScript.new()" "Foundation tests must exercise PlatformServices."
Require-TextInAny $uiSceneCheckFiles "res://scenes/main.tscn" "UI scene compile check must instantiate the active main scene."
Require-TextInAny $uiSceneCheckFiles "res://scripts/ui/foundation_main.gd" "UI scene compile check must verify the foundation UI shell."
Require-TextInAny $uiSceneCheckFiles "render_environment_snapshot" "UI scene compile check must verify environment snapshot rendering."
Require-TextInAny $uiSceneCheckFiles "render_game_snapshot" "UI scene compile check must verify game snapshot rendering."
Require-Text "tools/check_godot.ps1" 'Get-FoundationSplitRunnerPath' "Godot check script must assemble the split foundation check runner."
Require-Text "tools/check_godot.ps1" 'scripts/tests/foundation/check_lenders_release_saves.gd' "Godot check script must include the split foundation terminal source."
Require-Text "tools/check_godot.ps1" 'Get-UiSceneSplitRunnerPath' "Godot check script must assemble the split UI scene compile runner."
Require-Text "tools/check_godot.ps1" 'scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd' "Godot check script must include the split UI scene terminal source."
Require-Text "tools/check_godot.ps1" 'Get-SplitTestRunnerLines' "Godot check script must use the marker-aware split runner assembler."
Require-Text "tools/check_godot.ps1" 'ValidateSet("Smoke", "Contract", "Audit", "Full")' "Godot check script must expose suite selection."
Require-Text "tools/check_godot.ps1" '[switch]$PostLand' "Godot check script must expose the fail-closed post-land mode."
Require-Text "tools/check_godot.ps1" 'Add-PostLandIdentityStage' "Post-land verification must bind exact main, tree, and native identities at both gate boundaries."
Require-Text "tools/check_godot.ps1" 'ExpectedNativePluginSha256' "Post-land verification must bind the supplied plugin to the approved Gate Service build hash."
Require-Text "tools/check_godot.ps1" 'Get-GDExtensionWindowsDebugTarget' "Post-land verification must resolve the canonical Windows debug target from the native descriptor."
Require-Text "tools/check_godot.ps1" 'Post-land verification cannot skip the required Godot import with NoImport.' "Post-land verification must reject and override import narrowing."
Require-Text "tools/check_godot.ps1" 'native_coin_pusher_smoke.gd' "Post-land verification must prove the supplied Windows plugin executes as native_v3."
Require-Text "tools/check_godot.ps1" 'scenario_room_multiseed_finalization.gd' "Godot audit/full suites must include the permanent 8x55 scenario room finalization gate."
Require-Text "tools/check_godot.ps1" 'environment_grounding_contract.gd' "Godot audit/full suites must include the focused environment grounding mechanism contract."
Require-Text "tools/check_godot.ps1" 'Invoke-GameReworkVerificationGates' "Godot audit/full suites must retain the game rework verification gate group."
Require-Text "tools/check_godot.ps1" 'craps_extensive_playtest.gd' "Game rework verification must retain the extensive Craps settlement gate."
Require-Text "tools/check_godot.ps1" 'craps_rtp_audit.gd' "Game rework verification must retain the million-roll Craps RTP gate."
Require-Text "tools/check_godot.ps1" 'crew_holdem_gameplay_audit.gd' "Game rework verification must retain the Hold'em gameplay gate."
Require-Text "tools/check_godot.ps1" 'crew_holdem_dynamic_table_audit.gd' "Game rework verification must retain the Hold'em production-table gate."
Require-Text "tools/check_godot.ps1" 'crew_holdem_production_host_audit.gd' "Game rework verification must retain the Hold'em save, replay, arithmetic, and all-streets production-host gate."
Require-Text "tools/check_godot.ps1" 'slot_autoplay_cadence_probe.gd' "Game rework verification must retain the slot autoplay cadence gate."
Require-Text "tools/check_godot.ps1" 'slot_foreground_autoplay_performance_probe.gd' "Game rework verification must retain the foreground autoplay performance gate."
Require-Text "tools/check_godot.ps1" 'blackjack_counter_surveillance_probe.gd' "Game rework verification must retain the blackjack surveillance gate."
Require-Text "tools/check_godot.ps1" 'function Invoke-Perf06ContractChecks' "Godot checks must expose the permanent cheap perf06 contract stage."
Require-Text "tools/check_godot.ps1" 'Invoke-Perf06ContractChecks -SuiteLabel "audit"' "Godot Audit must run the permanent cheap perf06 contracts."
Require-Text "tools/check_godot.ps1" 'Invoke-Perf06ContractChecks -SuiteLabel "full"' "Godot Full must run the permanent cheap perf06 contracts."
Require-Text "tools/check_godot.ps1" 'perf06_phase_qualification_contract_test.ps1' "Godot Audit/Full must enforce perf06 timing/liveness pairing."
Require-Text "tools/check_godot.ps1" 'perf06_allocation_contract_test.ps1' "Godot Audit/Full must enforce perf06 per-frame allocation and zero-deep-copy assertions."
Require-Text "tools/check_godot.ps1" 'integ06_1_terminal_soak_launcher_contract_test.ps1' "Godot Audit/Full must enforce exact-candidate terminal-soak host-library discovery."
Require-Text "tools/integ06_1_terminal_soak_launcher_contract_test.ps1" '$candidateAddon = Join-Path $root "addons\coin_pusher_native"' "Terminal-soak contract must require host libraries from the exact candidate worktree."
Require-Text "tools/check_godot.ps1" 'eligible_for_done' "Post-land reports must make DONE eligibility explicitly fail closed."
Require-Text "tools/check_godot.ps1" 'gdscript_load_check.gd' "Godot check script must run the one-process GDScript load checker."
Require-Text "tools/check_godot.ps1" 'Stop-NewGodotProcesses' "Godot check script must clean up timed-out Godot child processes."
$checkGodotSource = Get-ProjectText "tools/check_godot.ps1"
$strictObjectDbStageBlock = [regex]::Match($checkGodotSource, '(?ms)\$script:StrictObjectDbLeakStageNames\s*=\s*@\((.*?)\r?\n\)')
$expectedStrictObjectDbStages = @(
    "standalone_contract_fixsweep06_1_accessibility_contract",
    "standalone_contract_rw06_1_overflow_action_ui_contract"
)
if (-not $strictObjectDbStageBlock.Success) {
    $failures.Add("Godot checks do not declare the reviewed strict ObjectDB-leak stage set.")
} else {
    $actualStrictObjectDbStages = @([regex]::Matches($strictObjectDbStageBlock.Groups[1].Value, '"([^"\r\n]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $strictObjectDbDifference = @(Compare-Object -ReferenceObject @($expectedStrictObjectDbStages | Sort-Object) -DifferenceObject $actualStrictObjectDbStages)
    if ($strictObjectDbDifference.Count -ne 0) {
        $failures.Add("Strict ObjectDB-leak stages must be exactly the accessibility and overflow standalone contracts: $($strictObjectDbDifference | Out-String)")
    }
}
$strictObjectDbPlumbing = @(
    'Get-GodotStderrIssues -StdoutText $stdoutTask.Result -StderrText $stderrTask.Result -StrictObjectDbLeaks:$StrictObjectDbLeaks',
    'Invoke-ProcessStage -Name $Name -FilePath $script:Godot -Arguments $args -StageTimeoutSec $StageTimeoutSec -StrictObjectDbLeaks:$StrictObjectDbLeaks',
    '$strictObjectDbLeaks = $script:StrictObjectDbLeakStageNames -contains $stageName',
    'Invoke-GodotScript -Name $stageName -ScriptPath $resourcePath -StageTimeoutSec (Get-StageTimeout "standalone_contract") -StrictObjectDbLeaks:$strictObjectDbLeaks'
)
foreach ($plumbingNeedle in $strictObjectDbPlumbing) {
    if (-not $checkGodotSource.Contains($plumbingNeedle)) {
        $failures.Add("Strict ObjectDB-leak policy is declared but not plumbed through the focused standalone stage: $plumbingNeedle")
    }
}
Require-TextInAny $foundationCheckFiles '--suite=' "Foundation check must support suite selection."
Require-TextInAny $foundationCheckFiles 'FOUNDATION_SUITES' "Foundation check must declare available suites."
Require-TextInAny $foundationCheckFiles 'FOUNDATION_DEFAULT_REPORT_PATH' "Foundation check must write a structured report."
Require-Text "tools/gdscript_load_check.gd" 'checked_files' "GDScript load check must report checked files."
Require-Text "tools/gdscript_load_check.gd" 'res://scripts' "GDScript load check must cover live scripts by default."
Require-Text "tools/gdscript_load_check.gd" 'res://tools' "GDScript load check must cover tool scripts by default."

$uiSplitSources = @(
    "scripts/tests/ui_scene/compile_components_and_main_flow.gd",
    "scripts/tests/ui_scene/compile_environment_layout.gd",
    "scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd"
)
$splitBeginMarker = Get-SplitTestRunnerOmitBeginMarker
$splitEndMarker = Get-SplitTestRunnerOmitEndMarker
$parentSplitLines = [System.IO.File]::ReadAllLines((Join-Path $root $uiSplitSources[0]))
$beginMarkerCount = @($parentSplitLines | Where-Object { $_.Trim() -eq $splitBeginMarker }).Count
$endMarkerCount = @($parentSplitLines | Where-Object { $_.Trim() -eq $splitEndMarker }).Count
if ($beginMarkerCount -ne 1 -or $endMarkerCount -ne 1) {
    $failures.Add("UI split parent must contain exactly one balanced descendant-stub marker block.")
}

# Hostile tool fixtures prove the assembler rejects malformed marker structure
# and removes only the explicitly marked span from a multi-source runner.
$hostileMarkedLines = @(
    "func _unmarked_before() -> void:",
    $splitBeginMarker,
    "func _hostile_duplicate_stub() -> void:",
    $splitEndMarker,
    "func _unmarked_after() -> void:"
)
$hostileFilteredLines = @(Remove-SplitTestRunnerOmittedBlocks -Lines $hostileMarkedLines -SourceLabel "hostile balanced fixture" -OmitMarkedBlocks $true)
if (($hostileFilteredLines -join "`n") -ne "func _unmarked_before() -> void:`nfunc _unmarked_after() -> void:") {
    $failures.Add("Split-runner omit markers must remove only marked content and preserve adjacent unmarked lines exactly.")
}
$hostileStandaloneLines = @(Remove-SplitTestRunnerOmittedBlocks -Lines $hostileMarkedLines -SourceLabel "hostile standalone fixture" -OmitMarkedBlocks $false)
if (($hostileStandaloneLines -join "`n") -ne ($hostileMarkedLines -join "`n")) {
    $failures.Add("Single-source split runners must preserve marked standalone fixture stubs byte-for-byte.")
}
$malformedMarkerFixtures = @(
    @($splitBeginMarker, "func _never_closed() -> void:"),
    @($splitEndMarker),
    @($splitBeginMarker, $splitBeginMarker, $splitEndMarker, $splitEndMarker)
)
foreach ($fixture in $malformedMarkerFixtures) {
    $rejected = $false
    try {
        [void](Remove-SplitTestRunnerOmittedBlocks -Lines $fixture -SourceLabel "hostile malformed fixture" -OmitMarkedBlocks $true)
    }
    catch {
        $rejected = $true
    }
    if (-not $rejected) {
        $failures.Add("Split-runner assembler must reject unbalanced or nested omit markers.")
    }
}

$generatedUiLines = @()
try {
    $generatedUiLines = @(Get-SplitTestRunnerLines -ProjectRoot $root -SourceRelativePaths $uiSplitSources)
}
catch {
    $failures.Add("Could not assemble marker-aware UI split runner: $($_.Exception.Message)")
}
$generatedUiFunctionNames = @($generatedUiLines | ForEach-Object {
    if ($_ -match '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
        $Matches[1]
    }
})
$descendantFunctionNames = @($uiSplitSources[1..($uiSplitSources.Count - 1)] | ForEach-Object {
    [System.IO.File]::ReadAllLines((Join-Path $root $_)) | ForEach-Object {
        if ($_ -match '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
            $Matches[1]
        }
    }
})
foreach ($functionName in ($descendantFunctionNames | Sort-Object -Unique)) {
    $generatedCount = @($generatedUiFunctionNames | Where-Object { $_ -eq $functionName }).Count
    if ($generatedCount -ne 1) {
        $failures.Add("Generated UI split runner must contain descendant function $functionName exactly once; found $generatedCount.")
    }
}

$insideStubBlock = $false
$stubFunctionNames = New-Object System.Collections.Generic.List[string]
$stubCallNames = New-Object System.Collections.Generic.List[string]
$stubBlockHasUnexpectedContent = $false
foreach ($line in $parentSplitLines) {
    if ($line.Trim() -eq $splitBeginMarker) {
        $insideStubBlock = $true
        continue
    }
    if ($line.Trim() -eq $splitEndMarker) {
        $insideStubBlock = $false
        continue
    }
    if (-not $insideStubBlock) {
        continue
    }
    $trimmedStubLine = $line.Trim()
    if (-not [string]::IsNullOrWhiteSpace($trimmedStubLine) -and
        $trimmedStubLine -notmatch '^func\s+' -and
        $trimmedStubLine -notmatch '^_missing_descendant_fixture\(' -and
        $trimmedStubLine -notmatch '^return\s+') {
        $stubBlockHasUnexpectedContent = $true
    }
    if ($line -match '^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(') {
        $stubFunctionNames.Add($Matches[1])
    }
    if ($line -match '_missing_descendant_fixture\("([A-Za-z_][A-Za-z0-9_]*)"\)') {
        $stubCallNames.Add($Matches[1])
    }
}
if (($stubFunctionNames -join "`n") -ne ($stubCallNames -join "`n") -or $stubFunctionNames.Count -eq 0 -or $stubBlockHasUnexpectedContent) {
    $failures.Add("UI split omit block may contain only declared descendant-fixture stubs with matching guards.")
}
foreach ($functionName in $stubFunctionNames) {
    $descendantCount = @($descendantFunctionNames | Where-Object { $_ -eq $functionName }).Count
    if ($descendantCount -ne 1) {
        $failures.Add("Omitted UI parent stub $functionName must have exactly one descendant implementation; found $descendantCount.")
    }
}
if (@($generatedUiLines | Where-Object { $_.Trim() -eq $splitBeginMarker -or $_.Trim() -eq $splitEndMarker }).Count -ne 0) {
    $failures.Add("Generated multi-source UI runner must not retain split-runner omit markers.")
}

$m2DataPacks = @{
    "lenders" = @{
        Path = "data/debt/lenders.json"
        RequiredFields = @("id", "display_name", "lender_type", "description", "debt_profile", "consequences")
    }
    "services" = @{
        Path = "data/services/services.json"
        RequiredFields = @("id", "display_name", "category", "description", "cost", "effect")
    }
    "travel_routes" = @{
        Path = "data/travel/routes.json"
        RequiredFields = @("id", "label", "destination_archetype", "description", "cost", "risk")
    }
}
foreach ($pack in $m2DataPacks.GetEnumerator()) {
    Assert-JsonRequiredFields $pack.Value.Path $pack.Key $pack.Value.RequiredFields
    Assert-JsonUniqueIds $pack.Value.Path $pack.Key
    if ((Read-JsonArray $pack.Value.Path).Count -eq 0) {
        $failures.Add("M2 data pack must contain at least one vertical-slice entry: $($pack.Value.Path)")
    }
}

$environmentIds = New-ContentIdSet "data/environments/archetypes.json"
$gameIds = New-ContentIdSet "data/games/games.json"
$itemIds = New-ContentIdSet "data/items/items.json"
$eventIds = New-ContentIdSet "data/events/events.json"
$lenderIds = New-ContentIdSet "data/debt/lenders.json"
$serviceIds = New-ContentIdSet "data/services/services.json"
$routeIds = New-ContentIdSet "data/travel/routes.json"
$resultDeltaKeys = @(
    "bankroll_delta",
    "suspicion_delta",
    "alcohol_intake",
    "drunk_delta",
    "pending_drunk_absorption_delta",
    "drunk_distortion_suppression_turns",
    "heat_cooldown_actions",
    "heat_cooldown_per_action",
    "alcoholic_delta",
    "baseline_luck_delta",
    "debt_changes",
    "inventory_add",
    "inventory_remove",
    "flags_set",
    "story_flags_set",
    "travel_hooks_add",
    "travel_changes",
    "story_log",
    "messages",
    "pending_bags",
    "ended",
    "item_hooks",
    "event_hooks",
    "environment_layer_discovery",
    "demo_finale"
)
$eventConsequenceKeys = $resultDeltaKeys + @(
    "debt",
    "flags",
    "flags_set",
    "set_story_flag",
    "set_story_flags",
    "story_flags_set",
    "unlock_travel_route",
    "unlock_travel_routes",
    "set_next_archetypes",
    "add_next_archetypes",
    "check",
    "resolve_event",
    "trigger_event",
    "crew_recruit_member",
    "crew_meet_member",
    "lender_hook",
    "debt_settlement_discount_percent"
)
$objectInfoTextLimit = 64

function Assert-ObjectInfoTextLength {
    param([string]$Label, [string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return
    }
    if ($Text.Length -gt $objectInfoTextLimit) {
        $failures.Add("$Label must fit the in-scene object info card ($($Text.Length)/$objectInfoTextLimit chars): $Text")
    }
    if ($Text.Contains("...")) {
        $failures.Add("$Label must use fitted authored copy instead of ellipsis truncation: $Text")
    }
}

foreach ($archetype in (Read-JsonArray "data/environments/archetypes.json")) {
    $archetypeId = [string](Get-JsonProperty $archetype "id")
    $gamePool = Get-JsonProperty $archetype "game_pool"
    $requiredGameIds = Get-JsonProperty $archetype "required_game_ids"
    Assert-IdArrayReferences "environment $archetypeId game_pool" $gamePool $gameIds
    Assert-IdArrayReferences "environment $archetypeId required_game_ids" $requiredGameIds $gameIds
    $gamePoolValues = ConvertTo-ValueArray $gamePool
    foreach ($requiredGameId in (ConvertTo-ValueArray $requiredGameIds)) {
        if (-not $gamePoolValues.Contains($requiredGameId)) {
            $failures.Add("environment $archetypeId required_game_ids includes $requiredGameId but game_pool does not.")
        }
    }
    Assert-IdArrayReferences "environment $archetypeId item_pool" (Get-JsonProperty $archetype "item_pool") $itemIds
    Assert-IdArrayReferences "environment $archetypeId event_pool" (Get-JsonProperty $archetype "event_pool") $eventIds
    Assert-IdArrayReferences "environment $archetypeId service_pool" (Get-JsonProperty $archetype "service_pool") $serviceIds
    Assert-IdArrayReferences "environment $archetypeId lender_hooks" (Get-JsonProperty $archetype "lender_hooks") $lenderIds
    Assert-IdArrayReferences "environment $archetypeId travel_hooks" (Get-JsonProperty $archetype "travel_hooks") $environmentIds
    if ($routeIds.Count -gt 0) {
        Assert-IdArrayReferences "environment $archetypeId travel_hooks route metadata" (Get-JsonProperty $archetype "travel_hooks") $routeIds
    }
    Assert-EnvironmentLayoutSpots $archetypeId (Get-JsonProperty $archetype "layout")
}

foreach ($route in (Read-JsonArray "data/travel/routes.json")) {
    $routeId = [string](Get-JsonProperty $route "id")
    Assert-ObjectInfoTextLength "travel_routes $routeId description" ([string](Get-JsonProperty $route "description"))
    Assert-NonNegativeIntProperty "travel_routes $routeId" $route "cost"
    Assert-NonNegativeIntProperty "travel_routes $routeId" $route "risk_decay"
    if (Test-JsonProperty $route "risk_decay") {
        try {
            $riskDecay = [int](Get-JsonProperty $route "risk_decay")
            if ($riskDecay -gt 100) {
                $failures.Add("travel_routes $routeId risk_decay must be between 0 and 100.")
            }
        }
        catch {
        }
    }
    $distance = [string](Get-JsonProperty $route "distance")
    $validDistances = @("same", "near", "local", "far", "remote")
    if (-not [string]::IsNullOrWhiteSpace($distance) -and -not $validDistances.Contains($distance.ToLowerInvariant())) {
        $failures.Add("travel_routes $routeId distance must be one of: same, near, local, far, remote.")
    }
    Assert-NonNegativeIntProperty "travel_routes $routeId" $route "requires_travel_count_min"
    if ((Test-JsonProperty $route "hide_until_travel_count_met") -and (Get-JsonProperty $route "hide_until_travel_count_met") -isnot [bool]) {
        $failures.Add("travel_routes $routeId hide_until_travel_count_met must be a boolean.")
    }
    $destination = [string](Get-JsonProperty $route "destination_archetype")
    if (-not [string]::IsNullOrWhiteSpace($destination) -and -not $environmentIds.ContainsKey($destination)) {
        $failures.Add("travel_routes $routeId references unknown destination_archetype: $destination")
    }
    $requiresFlags = Get-JsonProperty $route "requires_flags"
    if ($null -ne $requiresFlags -and $requiresFlags -isnot [pscustomobject]) {
        $failures.Add("travel_routes $routeId requires_flags must be an object when present.")
    }
}

foreach ($item in (Read-JsonArray "data/items/items.json")) {
    $itemId = [string](Get-JsonProperty $item "id")
    Assert-ObjectInfoTextLength "items $itemId description" ([string](Get-JsonProperty $item "description"))
    Assert-ArtAssetPath "items $itemId" $item
    if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $item "icon_key"))) {
        $failures.Add("items $itemId must define icon_key for environment/inventory art.")
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $item "environment_prop"))) {
        $failures.Add("items $itemId must define environment_prop for room presentation.")
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $item "surface"))) {
        $failures.Add("items $itemId must define surface for room presentation.")
    }
    if (-not (Test-JsonProperty $item "sellable")) {
        $failures.Add("items $itemId must define sellable for merchant sale rules.")
    }
    elseif ((Get-JsonProperty $item "sellable") -isnot [bool]) {
        $failures.Add("items $itemId sellable must be a boolean.")
    }
    if (-not (Test-JsonProperty $item "sale_price")) {
        $failures.Add("items $itemId must define sale_price for merchant sale values.")
    }
    else {
        Assert-NonNegativeIntProperty "items $itemId" $item "sale_price"
    }
}

foreach ($service in (Read-JsonArray "data/services/services.json")) {
    $serviceId = [string](Get-JsonProperty $service "id")
    Assert-ObjectInfoTextLength "services $serviceId description" ([string](Get-JsonProperty $service "description"))
    Assert-NonNegativeIntProperty "services $serviceId" $service "cost"
    Assert-DeltaKeys "services $serviceId effect" (Get-JsonProperty $service "effect") $resultDeltaKeys
}

foreach ($lender in (Read-JsonArray "data/debt/lenders.json")) {
    $lenderId = [string](Get-JsonProperty $lender "id")
    Assert-ObjectInfoTextLength "lenders $lenderId description" ([string](Get-JsonProperty $lender "description"))
    $profile = Get-JsonProperty $lender "debt_profile"
    if ($profile -isnot [pscustomobject]) {
        $failures.Add("lenders $lenderId debt_profile must be an object.")
    }
    else {
        Assert-NonNegativeIntProperty "lenders $lenderId debt_profile" $profile "principal_min"
        Assert-NonNegativeIntProperty "lenders $lenderId debt_profile" $profile "principal_max"
        Assert-NonNegativeIntProperty "lenders $lenderId debt_profile" $profile "deadline_turns"
        $principalMin = [int](Get-JsonProperty $profile "principal_min")
        $principalMax = [int](Get-JsonProperty $profile "principal_max")
        if ($principalMin -gt $principalMax) {
            $failures.Add("lenders $lenderId principal_min greater than principal_max.")
        }
    }
    Assert-DeltaKeys "lenders $lenderId effect" (Get-JsonProperty $lender "effect") $resultDeltaKeys
    $effect = Get-JsonProperty $lender "effect"
    $debtChanges = Get-JsonProperty $effect "debt_changes"
    if ($null -ne $debtChanges) {
        foreach ($debtChange in (ConvertTo-ValueArray $debtChanges)) {
            $debtLenderId = [string](Get-JsonProperty $debtChange "lender_id")
            if (-not [string]::IsNullOrWhiteSpace($debtLenderId) -and -not $lenderIds.ContainsKey($debtLenderId)) {
                $failures.Add("lenders $lenderId effect debt_changes references unknown lender_id: $debtLenderId")
            }
        }
    }
}

$grandCasino = $null
$undergroundCasino = $null
foreach ($archetype in (Read-JsonArray "data/environments/archetypes.json")) {
    $archetypeId = [string](Get-JsonProperty $archetype "id")
    if ($archetypeId -eq "grand_casino") {
        $grandCasino = $archetype
    }
    elseif ($archetypeId -eq "small_underground_casino") {
        $undergroundCasino = $archetype
    }
}
if ($null -eq $grandCasino) {
    $failures.Add("Demo objective requires a grand_casino environment archetype.")
}
else {
    $objective = Get-JsonProperty $grandCasino "demo_objective"
    if ($objective -isnot [pscustomobject]) {
        $failures.Add("grand_casino must define a demo_objective object.")
    }
    else {
        if ([string](Get-JsonProperty $objective "type") -ne "bankroll_target") {
            $failures.Add("grand_casino demo_objective type must be bankroll_target.")
        }
        $targetBankroll = [int](Get-JsonProperty $objective "target_bankroll")
        if ($targetBankroll -ne 0) {
            $failures.Add("grand_casino demo_objective target_bankroll must stay 0 because the clean win uses Grand Casino net winnings.")
        }
        $highRollerTargetBankroll = [int](Get-JsonProperty $objective "high_roller_target_bankroll")
        if ($highRollerTargetBankroll -ne 0) {
            $failures.Add("grand_casino high_roller_target_bankroll must stay 0 because the Players Card is not gated by total bankroll.")
        }
        $highRollerNetWinnings = [int](Get-JsonProperty $objective "high_roller_net_winnings")
        $highRollerMinGames = [int](Get-JsonProperty $objective "high_roller_min_grand_casino_games")
        if ($highRollerNetWinnings -ne 30 -or $highRollerMinGames -ne 5) {
            $failures.Add("grand_casino Gold review must require exactly five settled games and 30 net winnings.")
        }
        $bronzeGames = [int](Get-JsonProperty $objective "players_card_bronze_min_games")
        $bronzeNet = [int](Get-JsonProperty $objective "players_card_bronze_net_winnings")
        $silverGames = [int](Get-JsonProperty $objective "players_card_silver_min_games")
        $silverNet = [int](Get-JsonProperty $objective "players_card_silver_net_winnings")
        $goldGames = [int](Get-JsonProperty $objective "players_card_gold_min_games")
        $goldNet = [int](Get-JsonProperty $objective "players_card_gold_net_winnings")
        if ($bronzeGames -ne 1 -or $bronzeNet -ne 5 -or $silverGames -ne 3 -or $silverNet -ne 15 -or $goldGames -ne 5 -or $goldNet -ne 30) {
            $failures.Add("grand_casino Players Card tiers must use Bronze 1/5, Silver 3/15, and Gold 5/30 thresholds.")
        }
        if ([int](Get-JsonProperty $objective "players_card_look_away_max_heat_gain") -ne 5) {
            $failures.Add("grand_casino Linda look-away threshold must remain data-tuned at five heat.")
        }
    }
    $securityProfile = Get-JsonProperty $grandCasino "security_profile"
    $pitBoss = Get-JsonProperty $securityProfile "pit_boss"
    if ($pitBoss -isnot [pscustomobject]) {
        $failures.Add("grand_casino security_profile must define pit_boss watch data.")
    }
    else {
        if ((Get-JsonProperty $pitBoss "enabled") -ne $true) {
            $failures.Add("grand_casino pit_boss must be enabled.")
        }
        if ([int](Get-JsonProperty $pitBoss "cheat_heat_bonus") -lt 20) {
            $failures.Add("grand_casino pit_boss cheat_heat_bonus should be a meaningful danger.")
        }
    }
}
if ($null -eq $undergroundCasino) {
    $failures.Add("Demo objective route requires small_underground_casino.")
}
else {
    Assert-IdArrayReferences "small_underground_casino next_archetypes" (Get-JsonProperty $undergroundCasino "next_archetypes") $environmentIds
    $undergroundTargets = ConvertTo-ValueArray (Get-JsonProperty $undergroundCasino "next_archetypes")
    if (-not ($undergroundTargets -contains "grand_casino")) {
        $failures.Add("small_underground_casino must route to grand_casino.")
    }
}
$grandRoute = $null
foreach ($route in (Read-JsonArray "data/travel/routes.json")) {
    if ([string](Get-JsonProperty $route "id") -eq "grand_casino") {
        $grandRoute = $route
        break
    }
}
if ($null -eq $grandRoute) {
    $failures.Add("Demo objective requires a grand_casino travel route.")
}
elseif ([int](Get-JsonProperty $grandRoute "cost") -lt 70) {
    $failures.Add("grand_casino travel route should keep the release-tuned meaningful buy-in.")
}
else {
    $expectedGrandFreeOrigins = @("beach", "delta_queen", "kitty_cat_lounge")
    $grandFreeOrigins = @(
        ConvertTo-ValueArray (Get-JsonProperty $grandRoute "free_from_archetypes") |
            ForEach-Object { [string]$_ }
    )
    $grandFreeOriginsMatch = $grandFreeOrigins.Count -eq $expectedGrandFreeOrigins.Count
    foreach ($expectedOrigin in $expectedGrandFreeOrigins) {
        if ($grandFreeOrigins -cnotcontains $expectedOrigin) {
            $grandFreeOriginsMatch = $false
        }
    }
    foreach ($actualOrigin in $grandFreeOrigins) {
        if ($expectedGrandFreeOrigins -cnotcontains $actualOrigin) {
            $grandFreeOriginsMatch = $false
        }
    }
    if (-not $grandFreeOriginsMatch) {
        $failures.Add("grand_casino free_from_archetypes must contain exactly kitty_cat_lounge, delta_queen, and beach.")
    }
}

$grandInvite = $null
foreach ($event in (Read-JsonArray "data/events/events.json")) {
    if ([string](Get-JsonProperty $event "id") -eq "grand_casino_invite") {
        $grandInvite = $event
        break
    }
}
if ($null -eq $grandInvite) {
    $failures.Add("Demo objective requires the grand_casino_invite event.")
}
else {
    $grandInvitePayload = Get-JsonProperty $grandInvite "payload"
    $grandInviteChoices = @(ConvertTo-ValueArray (Get-JsonProperty $grandInvitePayload "choices"))
    $acceptInviteChoices = @($grandInviteChoices | Where-Object { [string](Get-JsonProperty $_ "id") -eq "accept_invite" })
    $declineInviteChoices = @($grandInviteChoices | Where-Object { [string](Get-JsonProperty $_ "id") -eq "not_yet" })
    if ($acceptInviteChoices.Count -ne 1) {
        $failures.Add("grand_casino_invite must define exactly one accept_invite choice.")
    }
    else {
        $acceptInviteConsequences = Get-JsonProperty $acceptInviteChoices[0] "consequences"
        if ([int](Get-JsonProperty $acceptInviteConsequences "bankroll_delta") -ne 50) {
            $failures.Add("grand_casino_invite accept_invite must grant exactly +50 bankroll.")
        }
    }
    if ($declineInviteChoices.Count -ne 1) {
        $failures.Add("grand_casino_invite must define exactly one not_yet choice.")
    }
    else {
        $declineInviteConsequences = Get-JsonProperty $declineInviteChoices[0] "consequences"
        if ([int](Get-JsonProperty $declineInviteConsequences "bankroll_delta") -ne 0) {
            $failures.Add("grand_casino_invite not_yet must not grant bankroll.")
        }
    }
}

foreach ($event in (Read-JsonArray "data/events/events.json")) {
    $eventId = [string](Get-JsonProperty $event "id")
    Assert-ArtAssetPath "events $eventId" $event
    $eventInteractionMode = [string](Get-JsonProperty $event "interaction_mode")
    if ([string]::IsNullOrWhiteSpace($eventInteractionMode)) {
        $failures.Add("events $eventId must define interaction_mode.")
    }
    elseif (($eventInteractionMode -ne "interactable") -and ($eventInteractionMode -ne "triggered")) {
        $failures.Add("events $eventId has unknown interaction_mode: $eventInteractionMode.")
    }
    $eventIconKey = [string](Get-JsonProperty $event "icon_key")
    $eventEnvironmentProp = [string](Get-JsonProperty $event "environment_prop")
    if ($eventInteractionMode -eq "triggered") {
        if (-not [string]::IsNullOrWhiteSpace($eventIconKey)) {
            $failures.Add("events $eventId is triggered and must not define icon_key.")
        }
        if (-not [string]::IsNullOrWhiteSpace($eventEnvironmentProp)) {
            $failures.Add("events $eventId is triggered and must not define environment_prop.")
        }
    }
    else {
        if ([string]::IsNullOrWhiteSpace($eventIconKey)) {
            $failures.Add("events $eventId must define icon_key for room art.")
        }
        elseif ($eventIconKey -eq "event") {
            $failures.Add("events $eventId must not use the generic event icon_key.")
        }
        if ([string]::IsNullOrWhiteSpace($eventEnvironmentProp)) {
            $failures.Add("events $eventId must define environment_prop such as patron_talk, paper_note, side_door, or security_camera.")
        }
        if ([string]::IsNullOrWhiteSpace([string](Get-JsonProperty $event "start_summary"))) {
            $failures.Add("events $eventId must define start_summary for the player-facing interaction starter.")
        }
    }
    $payload = Get-JsonProperty $event "payload"
    Assert-ObjectInfoTextLength "events $eventId payload.summary" ([string](Get-JsonProperty $payload "summary"))
    $choices = Get-JsonProperty $payload "choices"
    if ($choices -isnot [System.Array]) {
        $failures.Add("events $eventId payload choices must be an array.")
        continue
    }
    foreach ($choice in $choices) {
        $choiceId = [string](Get-JsonProperty $choice "id")
        $consequences = Get-JsonProperty $choice "consequences"
        Assert-DeltaKeys "events $eventId choice $choiceId consequences" $consequences $eventConsequenceKeys
        Assert-IdArrayReferences "events $eventId choice $choiceId set_next_archetypes" (Get-JsonProperty $consequences "set_next_archetypes") $environmentIds
        Assert-IdArrayReferences "events $eventId choice $choiceId add_next_archetypes" (Get-JsonProperty $consequences "add_next_archetypes") $environmentIds
        $debt = Get-JsonProperty $consequences "debt"
        if ($debt -is [pscustomobject]) {
            $debtLenderId = [string](Get-JsonProperty $debt "lender_id")
            if (-not [string]::IsNullOrWhiteSpace($debtLenderId) -and -not $lenderIds.ContainsKey($debtLenderId)) {
                $failures.Add("events $eventId choice $choiceId debt references unknown lender_id: $debtLenderId")
            }
        }
    }
}

Require-Text "scripts/core/run_state.gd" "var economic_state" "M2 economy state must live in RunState."
Require-Text "scripts/core/run_state.gd" "var debt" "M2 debt state must live in RunState."
Require-Text "scripts/core/run_state.gd" "var suspicion" "M2 suspicion/security state must live in RunState."
Require-Text "scripts/core/run_state.gd" "var unlocked_travel" "M2 travel state must live in RunState."
Require-Text "scripts/core/run_state.gd" "func travel_route_status" "Travel conditions must be evaluated through RunState."
Require-Text "scripts/core/run_state.gd" "func service_hook_status" "Service availability must be evaluated through RunState."
Require-Text "scripts/core/run_state.gd" "func lender_hook_status" "Lender availability must be evaluated through RunState."
Require-Text "scripts/core/game_module.gd" "func apply_result" "M2 result-deltas must apply through the shared GameModule/RunState path."
Require-Text "scripts/core/item_effect.gd" "class_name ItemEffect" "Items must use ItemEffect."
Require-Text "scripts/core/event_module.gd" "class_name EventModule" "Events must use EventModule."
Require-Text "scripts/core/save_service.gd" "class_name SaveService" "Foundation run save/load must use SaveService."

$forbiddenM2Managers = @(
    "scripts/core/economy_service.gd",
    "scripts/core/debt_manager.gd",
    "scripts/core/suspicion_service.gd",
    "scripts/core/security_manager.gd",
    "scripts/core/travel_service.gd",
    "scripts/core/service_manager.gd",
    "scripts/core/narrative_service.gd"
)
foreach ($managerPath in $forbiddenM2Managers) {
    if (Test-Path -LiteralPath (Join-Path $root $managerPath)) {
        $failures.Add("M2 architecture must stay in RunState/module contracts; unexpected manager/service file exists: $managerPath")
    }
}

Require-TextInAny $foundationCheckFiles "_check_m2_pack_availability" "Foundation tests must validate canonical M2 pack availability."
Require-TextInAny $foundationCheckFiles "_check_economy_pressure_foundation" "Foundation tests must cover economy pressure."
Require-TextInAny $foundationCheckFiles "_check_travel_route_foundation" "Foundation tests must cover route cost/risk/conditions."
Require-TextInAny $foundationCheckFiles "_check_service_hook_foundation" "Foundation tests must cover services."
Require-TextInAny $foundationCheckFiles "_check_lender_debt_foundation" "Foundation tests must cover debt/lenders."
Require-TextInAny $foundationCheckFiles "_check_suspicion_security_foundation" "Foundation tests must cover suspicion/security."
Require-TextInAny $foundationCheckFiles "_check_item_build_interaction_foundation" "Foundation tests must cover item build interactions."
Require-TextInAny $foundationCheckFiles "_check_event_system_state_foundation" "Foundation tests must cover event state conditions."
Require-TextInAny $foundationCheckFiles "_check_m2_system_interaction_scenario" "Foundation tests must cover an M2 system interaction scenario."

$visualQa = "tools/foundation_visual_qa.gd"
$environmentInteractionController = "scripts/ui/environment_interaction_controller.gd"
$environmentInteractionControllerText = Get-ProjectText $environmentInteractionController
$environmentInteractionControllerApi = @(
    "interactable_object_view_list",
    "numbers_interactable_objects",
    "game_hook_interactable_objects",
    "home_interactable_objects",
    "hook_interactable_objects",
    "interactable_object",
    "parent_home_return_interactable_object",
    "casino_spatial_interactable_objects",
    "environment_layer_interactable_objects",
    "travel_leave_interactable_object",
    "local_parent_home_door_travel_choice",
    "casino_room_door_travel_choice",
    "local_parent_home_door_kind",
    "current_environment_archetype_id",
    "parent_home_node_id",
    "parent_home_parent_target_id"
)
foreach ($methodName in $environmentInteractionControllerApi) {
    $methodPattern = "(?m)^static func " + [regex]::Escape($methodName) + "\("
    if ($environmentInteractionControllerText -notmatch $methodPattern) {
        $failures.Add("Environment interaction controller must expose public static API method: $methodName")
    }
}
Require-Text $environmentInteractionController 'var silas_here: bool =' "Silas itinerary presence must keep an explicit bool type so the controller compiles under warnings-as-errors."
Require-Text "scripts/core/run_state.gd" "func numbers_silas_is_here" "Silas interactable generation and paid exchange must share the production physical-presence predicate."
Require-Text "scripts/ui/foundation_main.gd" "EnvironmentInteractionControllerScript.game_hook_interactable_objects" "Foundation UI must route Poker and other game hooks through the controller public API."
Require-Text "scripts/ui/foundation_main.gd" "EnvironmentInteractionControllerScript.interactable_object_view_list" "Foundation UI must route Numbers and room interactables through the controller public API."
Require-Text $visualQa '"interaction_mode": "visible_controls"' "Foundation visual QA must identify visible control interaction mode."
Require-Text $visualQa '"core_flow_driver": "visible_canvas_and_controls"' "Foundation visual QA must drive the core flow through visible controls."
Require-Text $visualQa '"direct_debug_helper_methods_used": false' "Foundation visual QA must declare that it avoids debug helper gameplay paths."
Require-Text $visualQa "visible_button_signal" "Foundation visual QA must click visible buttons."
Require-Text $visualQa "canvas_mouse_double_click" "Foundation visual QA must double-click visible world objects."
Require-Text $visualQa "game_surface_mouse_click" "Foundation visual QA must click visible game surface regions."
Require-Text $visualQa "serialized_before_legal_click == _serialized_run_text()" "Foundation visual QA must prove surface selection does not mutate RunState."
Require-Text $visualQa "serialized_before_legal_resolve != _serialized_run_text()" "Foundation visual QA must prove visible resolve changes RunState."
Require-Text "tools/foundation_visual_qa.ps1" 'res://tools/foundation_visual_qa.gd' "Visual QA PowerShell wrapper must run the foundation visual QA script."
Forbid-Text $visualQa "RuntimeContent" "Foundation visual QA must not use RuntimeContent."
Forbid-Text $visualQa "GameUiModule" "Foundation visual QA must not instantiate GameUiModule."
Forbid-Text $visualQa "core_content.json" "Foundation visual QA must not depend on data/runtime/core_content.json."
Forbid-Text $visualQa "res://data/runtime" "Foundation visual QA must not load data/runtime paths."

$gameDefinitions = Read-JsonArray "data/games/games.json"
foreach ($gameDefinition in $gameDefinitions) {
    $gameId = [string]$gameDefinition.id
    Assert-ObjectInfoTextLength "games $gameId description" ([string](Get-JsonProperty $gameDefinition "description"))
    Assert-ObjectInfoTextLength "games $gameId intro" ([string](Get-JsonProperty $gameDefinition "intro"))
    $modulePath = [string]$gameDefinition.module_path
    if ($modulePath.EndsWith("_ui.gd") -or $modulePath.Contains("data/runtime")) {
        $failures.Add("Foundation game definition routes through demo/runtime module: $gameId -> $modulePath")
        continue
    }
    if ($modulePath.StartsWith("res://")) {
        $relativeModule = $modulePath.Substring(6)
        $moduleText = Get-ProjectText $relativeModule
        if (-not $moduleText.Contains("extends GameModule")) {
            $failures.Add("Foundation game module does not extend GameModule: $gameId -> $modulePath")
        }
    }
}

$contentIdFiles = @(
    "data/environments/archetypes.json",
    "data/games/games.json",
    "data/items/items.json",
    "data/events/events.json",
    "data/debt/lenders.json",
    "data/services/services.json",
    "data/travel/routes.json"
)
$contentIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($contentFile in $contentIdFiles) {
    foreach ($entry in (Read-JsonArray $contentFile)) {
        $id = [string]$entry.id
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            [void]$contentIds.Add($id)
        }
    }
}
$foundationUiText = Get-ProjectText $foundationUi
$foundationUiContentSelectionScan = Get-FoundationUiContentSelectionScan $foundationUiText
if ([int]$foundationUiContentSelectionScan.HostSecurityAllowlistCount -ne 1) {
    $failures.Add("Foundation UI host security allowlist classification must match exactly once.")
}
$foundationUiContentSelectionText = [string]$foundationUiContentSelectionScan.ScanText
foreach ($id in $contentIds) {
    if ($foundationUiContentSelectionText.Contains('"' + $id + '"') -or $foundationUiContentSelectionText.Contains("'" + $id + "'")) {
        $failures.Add("Foundation UI shell hardcodes content id instead of deriving it from ContentLibrary: $id")
    }
}

$simulationSearchRoots = @(
    "scripts/core",
    "scripts/games"
)
foreach ($searchRoot in $simulationSearchRoots) {
    $absoluteSearchRoot = Join-Path $root $searchRoot
    if (-not (Test-Path -LiteralPath $absoluteSearchRoot)) {
        continue
    }
    foreach ($script in Get-ChildItem -LiteralPath $absoluteSearchRoot -Filter "*.gd" -Recurse) {
        $relativeScript = Get-ProjectRelativePath $script.FullName
        $scriptText = Get-Content -LiteralPath $script.FullName -Raw
        if ($scriptText -match '\brandomize\s*\(' -or $scriptText -match '\brandf\s*\(' -or $scriptText -match '\brandi\s*\(' -or $scriptText.Contains("RandomNumberGenerator")) {
            $failures.Add("Foundation simulation must use RngStream instead of engine-global randomness: $relativeScript")
        }
    }
}

try {
    & (Join-Path $root "tools/environment_grounding_static_check.ps1") -Root $root | Out-Null
}
catch {
    $failures.Add("Environment grounding static check failed: $($_.Exception.Message)")
}

try {
    $exactSeedCandidateLauncher = Join-Path $root "tools/rw06_1_environment_exact_seed_contract_test.ps1"
    $exactSeedCandidateSupport = Join-Path $root "tools/rw06_q009_process_support.ps1"
    $exactSeedManifest = Join-Path $root "tools/fixtures/rw06_1_environment_exact_seed_manifest.json"
    $exactSeedAudit = Join-Path $root "tools/environment_generation_audit.gd"
    $exactSeedStaticChecker = Join-Path $root "tools/environment_fixed_slot_static_check.py"
    $exactSeedScenarioCatalog = Join-Path $root "data/environments/scenarios.json"
    $exactSeedFidelityHelper = Join-Path $root "scripts/tests/foundation/harness_production_fidelity.gd"
    $exactSeedFoundationTravelViewModel = Join-Path $root "scripts/ui/foundation_travel_view_model.gd"
    $exactSeedTutorialFlow = Join-Path $root "scripts/core/tutorial_flow.gd"
    $exactSeedAttributeBadges = Join-Path $root "scripts/core/attribute_badges.gd"
    $exactSeedValidatorNonce = [Guid]::NewGuid().ToString("N")
    $exactSeedAttemptId = "rw06-q009-validator-$exactSeedValidatorNonce"
    $exactSeedSupportPin = $null
    $exactSeedLauncherPin = $null
    $exactSeedPowerShellPin = $null
    $exactSeedDependencyPins = [ordered]@{}
    $exactSeedDependencyPinReceipts = [ordered]@{}
    $exactSeedShadowReadPins = [System.Collections.Generic.List[object]]::new()
    $exactSeedHeldGitBlobs = [ordered]@{}
    $exactSeedShadowCell = $null
    $exactSeedShadowRootReceipt = $null
    $exactSeedShadowChain = $null
    $exactSeedShadowCleanupReceipt = $null
    $exactSeedShadowMembers = [System.Collections.Generic.List[string]]::new()
    $exactSeedInnerFailure = $null
    $exactSeedShadowRoot = Join-Path ([System.IO.Path]::GetTempPath()) $exactSeedAttemptId
    $exactSeedShadowQuarantine = $exactSeedShadowRoot + '.quarantine-' + $exactSeedValidatorNonce
    $exactSeedLauncher = Join-Path $exactSeedShadowRoot 'rw06_1_environment_exact_seed_contract_test.ps1'
    $exactSeedSupport = Join-Path $exactSeedShadowRoot 'rw06_q009_process_support.ps1'
    $exactSeedSelfTestReport = Join-Path $exactSeedShadowRoot 'selftest-report.json'
    $exactSeedLauncherStdout = Join-Path $exactSeedShadowRoot 'selftest.stdout.log'
    $exactSeedLauncherStderr = Join-Path $exactSeedShadowRoot 'selftest.stderr.log'
    $exactSeedIndependentDriver = Join-Path $exactSeedShadowRoot 'independent-driver.ps1'
    $exactSeedIndependentReport = Join-Path $exactSeedShadowRoot 'independent-report.json'
    $exactSeedIndependentStdout = Join-Path $exactSeedShadowRoot 'independent.stdout.log'
    $exactSeedIndependentStderr = Join-Path $exactSeedShadowRoot 'independent.stderr.log'
    $exactSeedLeaseRoot = 'D:\Projects\Beat-The-House-worktrees\.godot_leases'
    $exactSeedProjectCache = Join-Path $root '.godot'
    $exactSeedBoundPaths = @($exactSeedCandidateLauncher,$exactSeedCandidateSupport,$exactSeedManifest,$exactSeedAudit,$exactSeedStaticChecker,$exactSeedScenarioCatalog,$exactSeedFidelityHelper,$exactSeedFoundationTravelViewModel,$exactSeedTutorialFlow,$exactSeedAttributeBadges,$PSCommandPath)
    $exactSeedPreFileCensus = Get-Rw061ValidatorFileIdentityCensus $exactSeedBoundPaths
    $exactSeedPreProcessCensus = @(Get-Rw061ValidatorProcessCensus)
    $exactSeedPreLeaseCensus = @(Get-Rw061ValidatorLeaseCensus $exactSeedLeaseRoot)
    $exactSeedPreResidueCensus = @(Get-Rw061ValidatorSelfTestResidueCensus)
    $exactSeedPreCacheCensus = Get-Rw061ValidatorTreeCensus $exactSeedProjectCache
    $exactSeedPreEnvironmentCensus = Get-Rw061ValidatorEnvironmentCensus
    if (@($exactSeedPreProcessCensus | Where-Object { [string]$_.name -like 'Godot*' }).Count -ne 0) {
        throw 'rw06_1 engine-free validator refuses to run while Godot is active.'
    }
    if ((Test-Path -LiteralPath $exactSeedShadowRoot) -or (Test-Path -LiteralPath $exactSeedShadowQuarantine)) {
        throw 'rw06_1 validator shadow or quarantine path already exists.'
    }
    # Pin both source files before loading any helper by path. The exact support
    # bytes are evaluated in memory; only byte-identical held copies are later
    # exposed to a child process.
    $exactSeedSupportPin = Open-Rw061ValidatorReadPin $exactSeedCandidateSupport
    $exactSeedLauncherPin = Open-Rw061ValidatorReadPin $exactSeedCandidateLauncher
    $exactSeedDependencyMap=[ordered]@{
        manifest=$exactSeedManifest;audit=$exactSeedAudit;static_checker=$exactSeedStaticChecker;
        scenario_catalog=$exactSeedScenarioCatalog;fidelity_helper=$exactSeedFidelityHelper;
        foundation_travel_view_model=$exactSeedFoundationTravelViewModel;tutorial_flow=$exactSeedTutorialFlow;
        attribute_badges=$exactSeedAttributeBadges;validator=$PSCommandPath
    }
    foreach($dependency in $exactSeedDependencyMap.GetEnumerator()){
        $pin=Open-Rw061ValidatorReadPin ([string]$dependency.Value)
        $exactSeedDependencyPins[[string]$dependency.Key]=$pin
        $exactSeedDependencyPinReceipts[[string]$dependency.Key]=Get-Rw061ValidatorReadPinReceipt $pin
    }
    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    # Capture native identity, final path, ordinary-file/reparse status, length,
    # and held bytes before the support can define any helper or native type.
    $exactSeedSupportPinReceipt = Get-Rw061ValidatorReadPinReceipt $exactSeedSupportPin
    $exactSeedLauncherPinReceipt = Get-Rw061ValidatorReadPinReceipt $exactSeedLauncherPin
    foreach($blobSpec in @(
        @('launcher_git_blob',$exactSeedCandidateLauncher),@('support_git_blob',$exactSeedCandidateSupport),
        @('manifest_git_blob',$exactSeedManifest),@('audit_gd_git_blob',$exactSeedAudit),
        @('static_checker_git_blob',$exactSeedStaticChecker),@('scenario_catalog_git_blob',$exactSeedScenarioCatalog),
        @('fidelity_helper_git_blob',$exactSeedFidelityHelper),@('foundation_travel_view_model_git_blob',$exactSeedFoundationTravelViewModel),
        @('tutorial_flow_git_blob',$exactSeedTutorialFlow),@('attribute_badges_git_blob',$exactSeedAttributeBadges),@('validator_git_blob',$PSCommandPath)
    )){
        $blobOutput=@(& git -C $root hash-object -- ([string]$blobSpec[1]) 2>&1)
        if($LASTEXITCODE-ne0-or$blobOutput.Count-ne1-or[string]$blobOutput[0]-notmatch'^[0-9a-f]{40}$'){throw "could not pre-bind held Git blob for $([string]$blobSpec[0])"}
        $exactSeedHeldGitBlobs[[string]$blobSpec[0]]=[string]$blobOutput[0]
    }
    $exactSeedSupportScript = [scriptblock]::Create($strictUtf8.GetString([byte[]]$exactSeedSupportPin.bytes))
    . $exactSeedSupportScript
    # Independently inspect only the qualifying runtime bodies from the held
    # source bytes. The launcher's ValidateOnly checklist is removed from the
    # search region, so these gates cannot satisfy themselves with literals.
    $exactSeedHeldLauncherSource = $strictUtf8.GetString([byte[]]$exactSeedLauncherPin.bytes)
    $exactSeedHeldSupportSource = $strictUtf8.GetString([byte[]]$exactSeedSupportPin.bytes)
    $heldLauncherTokens = $null
    $heldLauncherParseErrors = $null
    $heldLauncherAst = [Management.Automation.Language.Parser]::ParseInput($exactSeedHeldLauncherSource,[ref]$heldLauncherTokens,[ref]$heldLauncherParseErrors)
    if ($heldLauncherParseErrors.Count -ne 0) { throw 'held rw06_1 qualifying supervisor source did not parse' }
    $heldValidateOnlyFunctions = @($heldLauncherAst.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Invoke-ValidateOnlySelfTest'},$true))
    if ($heldValidateOnlyFunctions.Count -ne 1) { throw 'held rw06_1 supervisor did not expose exactly one removable ValidateOnly checklist' }
    $heldValidateOnlyExtent = $heldValidateOnlyFunctions[0].Extent
    $heldRuntimeSource = $exactSeedHeldLauncherSource.Substring(0,$heldValidateOnlyExtent.StartOffset) + $exactSeedHeldLauncherSource.Substring($heldValidateOnlyExtent.EndOffset)
    if ($heldRuntimeSource.Contains('runtime-source-custody-lifecycle-provenance-seams')) { throw 'held runtime source still contains its self-test checklist' }
    $heldEntryMarker = 'if($LoadAdmissionFunctionsOnly){return}'
    $heldEntryOffset = $heldRuntimeSource.IndexOf($heldEntryMarker,[StringComparison]::Ordinal)
    if ($heldEntryOffset -lt 0) { throw 'held runtime source lacked the admission-only boundary' }
    $heldRuntimeEntry = $heldRuntimeSource.Substring($heldEntryOffset + $heldEntryMarker.Length)
    foreach ($requiredRuntimeToken in @(
        '[void](Remove-ExactOwnedTree $EvidenceRoot $profileRoot $profileRootIdentity $profileManifestChain $attemptId)',
        '$dependencyPins=New-Q009TrackedDependencyPins $pinned $runContext',
        '$dependencyPinReceipts=Assert-Q009TrackedDependencyPinsStable $pinned $dependencyPins $runContext',
        '$prePublicationCustody=Invoke-Q009MutexCritical -RunContext $runContext -Body {',
        'Test-Q009PrePublicationCustodyShape $prePublicationCustody $runContext $heldExclusiveLease.receipt $pinned $dependencyPinReceipts',
        'Test-Q009EvidenceTerminalOwnerReceiptShape $evidenceTerminalOwnerReceipt $runContext $evidenceRootOwnership $heldExclusiveReceipt $pinned $dependencyPinReceipts',
        "-Boundary 'evidence_terminal_before_summary'",
        '$summaryPublication=Publish-SummaryPairNoOverwrite $EvidenceRoot $summaryPath $summaryShaPath $summary $evidenceTerminalManifestChain $attemptId',
        "-Boundary 'summary_published_under_exclusive'",
        '$releaseDependencyPins=Close-Q009TrackedDependencyPins $pinned $dependencyPins $runContext $dependencyPinReceipts',
        '$releaseReceipt=Close-Q009HeldExclusiveLease $heldExclusiveLease $runContext',
        'Test-Q009ReleaseEvidenceShape $preReleaseZeroGodot $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts',
        'Test-Q009TerminalCompletionReceiptShape $terminalReceipt $runContext $heldExclusiveReceipt $summaryPublication $pinned $dependencyPinReceipts',
        "-ArtifactName 'terminal.json'",
        'Test-Q009TerminalTreeDelta $postSummaryManifestChain.manifest $finalEvidenceTree $terminalPublication'
    )) {
        if (-not $heldRuntimeEntry.Contains($requiredRuntimeToken)) { throw "held rw06_1 runtime entry lost independent custody seam: $requiredRuntimeToken" }
    }
    $heldPrePublicationToken = '$prePublicationCustody=Invoke-Q009MutexCritical -RunContext $runContext -Body {'
    $heldPrePublicationShapeToken = 'if(-not(Test-Q009PrePublicationCustodyShape $prePublicationCustody $runContext $heldExclusiveLease.receipt $pinned $dependencyPinReceipts))'
    $heldTerminalSafeToken = '$terminalEvidenceSafe=$cleanupSucceeded-and$finalProvenanceValid-and$leaseOwned-and(Test-Q009RunContextShape $runContext)-and(Test-Q009PrePublicationCustodyShape $prePublicationCustody $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts)'
    $heldTerminalOwnerToken = '$evidenceTerminalOwnerReceipt=[ordered]@{'
    $heldTerminalOwnerShapeToken = 'if(-not(Test-Q009EvidenceTerminalOwnerReceiptShape $evidenceTerminalOwnerReceipt $runContext $evidenceRootOwnership $heldExclusiveReceipt $pinned $dependencyPinReceipts))'
    $heldTerminalManifestToken = "`$evidenceTerminalManifestChain=New-Q009OwnedChildManifestChainHead -RootPath `$EvidenceRoot -RootIdentity `$evidenceRootOwnership.root_identity -AttemptId `$attemptId -Boundary 'evidence_terminal_before_summary'"
    $heldSummaryConstructionToken = '$summary=[ordered]@{'
    $heldSummaryPublishToken = '$summaryPublication=Publish-SummaryPairNoOverwrite $EvidenceRoot $summaryPath $summaryShaPath $summary $evidenceTerminalManifestChain $attemptId'
    $heldPostSummaryManifestToken = "`$postSummaryManifestChain=New-Q009OwnedChildManifestChainHead -RootPath `$EvidenceRoot -RootIdentity `$evidenceRootOwnership.root_identity -AttemptId `$attemptId -Boundary 'summary_published_under_exclusive'"
    $heldPreReleaseToken = '$preReleaseZeroGodot=Invoke-Q009MutexCritical -RunContext $runContext -Body {'
    $heldDependencyReleaseToken = '$releaseDependencyPins=Close-Q009TrackedDependencyPins $pinned $dependencyPins $runContext $dependencyPinReceipts'
    $heldReleaseCloseToken = '$releaseReceipt=Close-Q009HeldExclusiveLease $heldExclusiveLease $runContext'
    $heldReleaseShapeToken = 'if(-not(Test-Q009ReleaseEvidenceShape $preReleaseZeroGodot $runContext $heldExclusiveReceipt $pinned $dependencyPinReceipts))'
    $heldTerminalCompletionToken = '$terminalReceipt=[ordered]@{'
    $heldTerminalCompletionShapeToken = 'if(-not(Test-Q009TerminalCompletionReceiptShape $terminalReceipt $runContext $heldExclusiveReceipt $summaryPublication $pinned $dependencyPinReceipts))'
    $heldTerminalPublishToken = "`$terminalPublication=Publish-SummaryPairNoOverwrite `$EvidenceRoot `$terminalPath `$terminalShaPath `$terminalReceipt `$postSummaryManifestChain `$attemptId -ArtifactName 'terminal.json'"
    $heldFinalTreeToken = '$finalEvidenceTree=Get-Q009ExactOwnedTreeManifest $EvidenceRoot'
    $heldFinalTreeDeltaToken = 'Test-Q009TerminalTreeDelta $postSummaryManifestChain.manifest $finalEvidenceTree $terminalPublication'
    $heldSummaryReceiptToken = '$summaryReceiptHash=if($summaryPublished)'
    $heldLifecyclePositions = @(
        $heldRuntimeEntry.IndexOf($heldPrePublicationToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldPrePublicationShapeToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalSafeToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalOwnerToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalOwnerShapeToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalManifestToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldSummaryConstructionToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldSummaryPublishToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldPostSummaryManifestToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldPreReleaseToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldDependencyReleaseToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldReleaseCloseToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldReleaseShapeToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalCompletionToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalCompletionShapeToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldTerminalPublishToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldFinalTreeToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldFinalTreeDeltaToken,[StringComparison]::Ordinal),
        $heldRuntimeEntry.IndexOf($heldSummaryReceiptToken,[StringComparison]::Ordinal)
    )
    for ($heldLifecycleIndex = 0; $heldLifecycleIndex -lt $heldLifecyclePositions.Count; $heldLifecycleIndex += 1) {
        if ($heldLifecyclePositions[$heldLifecycleIndex] -lt 0 -or ($heldLifecycleIndex -gt 0 -and $heldLifecyclePositions[$heldLifecycleIndex] -le $heldLifecyclePositions[$heldLifecycleIndex - 1])) {
            throw 'held rw06_1 runtime entry lost the independently ordered held-EXCLUSIVE summary publication, exact release, terminal receipt, and final-tree lifecycle'
        }
    }
    $heldSupportTokens = $null
    $heldSupportParseErrors = $null
    $heldSupportAst = [Management.Automation.Language.Parser]::ParseInput($exactSeedHeldSupportSource,[ref]$heldSupportTokens,[ref]$heldSupportParseErrors)
    if ($heldSupportParseErrors.Count -ne 0) { throw 'held rw06_1 shared Q-009 support source did not parse' }
    $requiredSupportFunctionBodies = [ordered]@{
        'Remove-Q009ExactOwnedTree' = @('MoveOwnedCleanupTreeToQuarantineNoReplace','DeleteTreeExact','Test-Q009OwnedChildManifestChainHeadShape')
        'New-OwnedLeaseFile' = @('New-Q009ExactOwnedFileHeld','Set-Q009HeldHandleDeletePending','Assert-Q009PathAbsentStrict')
        'New-Q009HeldExclusiveLease' = @('CreateFileNewHeld','Set-Q009HeldHandleDeletePending','Close-Q009CheckedNativeHandle')
        'Close-Q009HeldExclusiveLease' = @('Set-Q009HeldHandleDeletePending','Close-Q009CheckedNativeHandle','Assert-Q009PathAbsentStrict','ForceReplacementAfterFileCloseForTest')
    }
    foreach ($functionName in $requiredSupportFunctionBodies.Keys) {
        $targetFunctionName = [string]$functionName
        $matches = @($heldSupportAst.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $targetFunctionName},$true))
        if ($matches.Count -ne 1) { throw "held Q-009 support function was not unique: $functionName" }
        $body = $matches[0].Extent.Text
        foreach ($requiredBodyToken in $requiredSupportFunctionBodies[$functionName]) {
            if (-not $body.Contains($requiredBodyToken)) { throw "held Q-009 support function $functionName lost exact seam $requiredBodyToken" }
        }
        if ([regex]::IsMatch($body,'(?im)^\s*Remove-Item\b|\[IO\.(?:File|Directory)\]::Delete\s*\(')) { throw "held Q-009 support function $functionName retained path-based deletion" }
    }
    $heldPublicationFunctions = @($heldLauncherAst.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq 'Publish-SummaryPairNoOverwrite'},$true))
    if ($heldPublicationFunctions.Count -ne 1) { throw 'held rw06_1 summary publication function was not unique' }
    $heldPublicationBody = $heldPublicationFunctions[0].Extent.Text
    $heldPublicationPositions = @(
        $heldPublicationBody.IndexOf('$authorizedManifest=Get-Q009ExactOwnedTreeManifest $OwnedRoot',[StringComparison]::Ordinal),
        $heldPublicationBody.IndexOf("-Boundary 'summary_pair_staged'",[StringComparison]::Ordinal),
        $heldPublicationBody.IndexOf('Publish-Q009OwnedEvidenceArtifact -SourcePath $stageSha -DestinationPath $ShaPath',[StringComparison]::Ordinal),
        $heldPublicationBody.IndexOf("-Boundary 'summary_sidecar_committed_json_staged'",[StringComparison]::Ordinal),
        $heldPublicationBody.IndexOf('Test-Q009SummaryPublicationReceiptShape $publication',[StringComparison]::Ordinal),
        $heldPublicationBody.IndexOf('Publish-Q009OwnedEvidenceArtifact -SourcePath $stageJson -DestinationPath $JsonPath',[StringComparison]::Ordinal),
        $heldPublicationBody.IndexOf('$committed=$true',[StringComparison]::Ordinal)
    )
    for ($heldPublicationIndex = 0; $heldPublicationIndex -lt $heldPublicationPositions.Count; $heldPublicationIndex += 1) {
        if ($heldPublicationPositions[$heldPublicationIndex] -lt 0 -or ($heldPublicationIndex -gt 0 -and $heldPublicationPositions[$heldPublicationIndex] -le $heldPublicationPositions[$heldPublicationIndex - 1])) {
            throw 'held rw06_1 summary publisher lost terminal-manifest admission, sidecar-first publication, exact receipt validation, or JSON-last commit ordering'
        }
    }
    $exactSeedShadowCell = New-Q009CacheCustodyCell ($exactSeedAttemptId + '-shadow')
    $exactSeedShadowRootReceipt = New-Q009ExactOwnedDirectoryHeld -Path $exactSeedShadowRoot -CustodyCell $exactSeedShadowCell -Slot 'root_creation'
    if (-not (Test-Q009CacheRootReceiptShape $exactSeedShadowRootReceipt)) {
        throw 'rw06_1 validator shadow root creation receipt was malformed.'
    }
    Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @()
    $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'held-shadow-root-empty' -OwnerKind validator_shadow -OwnerReceipt $exactSeedShadowRootReceipt
    $shadowSupportReceipt = New-Rw061ValidatorShadowFile $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedSupport 'shadow_support' ([byte[]]$exactSeedSupportPin.bytes) $exactSeedShadowReadPins
    if ([string]$shadowSupportReceipt.payload_sha256 -cne [string]$exactSeedSupportPinReceipt.sha256 -or [int]$shadowSupportReceipt.payload_length -ne [long]$exactSeedSupportPinReceipt.length) {
        throw 'held support shadow did not remain byte-identical to its no-write/no-delete source pin'
    }
    [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedSupport))
    Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
    $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'held-shadow-support' -OwnerKind validator_shadow -OwnerReceipt $shadowSupportReceipt -PreviousHead $exactSeedShadowChain
    $shadowLauncherReceipt = New-Rw061ValidatorShadowFile $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedLauncher 'shadow_launcher' ([byte[]]$exactSeedLauncherPin.bytes) $exactSeedShadowReadPins
    if ([string]$shadowLauncherReceipt.payload_sha256 -cne [string]$exactSeedLauncherPinReceipt.sha256 -or [int]$shadowLauncherReceipt.payload_length -ne [long]$exactSeedLauncherPinReceipt.length) {
        throw 'held launcher shadow did not remain byte-identical to its no-write/no-delete source pin'
    }
    [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedLauncher))
    Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
    $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'held-shadow-launcher' -OwnerKind validator_shadow -OwnerReceipt $shadowLauncherReceipt -PreviousHead $exactSeedShadowChain
    $expectedExactSeedSelfTestCases = @(
        "manifest-exact-order-distribution-and-identity",
        "manifest-substitution-order-extra-types-and-safe-name-collision",
        "authority-conflict-and-seed009-combination-shapes",
        "base-authority-enabled-disabled-and-seal-geometry",
        "nested-attempt-and-seed-tuple-binding",
        "final-post-event-visited-arrival-travel-and-admission-cross-binding",
        "initial-arrival-independent-identity-index-and-type-hostiles",
        "historical-six-visit-five-link-semantic-mutation-matrix",
        "exact-index-arrays-envelope-bool-and-decimal-time-hostiles",
        "ordinary-row-arrival-errors-and-authority-collection-hostiles",
        "inactive-independent-projection-sentinel",
        "private-turn-traitor-rigged-ticket-field-scan",
        "diagnostics-log-only-warning-leak-orphan-rid",
        "qualifying-predicate-and-product-red-diagnostics-exactly-report-bound",
        "native-diagnostic-fixed-schema-types-and-derived-totals",
        "envelope-collection-object-types-and-incomplete-product-matrix",
        "native-exit-strict-types",
        "lineage-reused-intermediate-negative-and-exact-cim-ticks",
        "lease-create-write-removal-failure-contention-and-replacement",
        "exclusive-reservation-waits-for-focused-lease-or-godot",
        "process-cim-enumeration-failures-block-readiness-residual-and-release",
        "import-cache-immediate-prelaunch-race-is-not-owned-or-deleted",
        "cache-exclusive-creator-claim-not-lifetime-adoption",
        "handle-bound-tree-quarantine-rejects-path-replacement",
        "stale-cache-and-cleanup-retains-exclusive-policy",
        "atomic-evidence-root-pre-post-move-native-identity",
        "attempt-owner-hash-containment-and-executable-provenance",
        "executable-swap-before-handle-locked-launch-is-rejected",
        "runtime-source-custody-lifecycle-provenance-seams",
        "abandoned-launch-mutex-owned-release-and-fail-closed",
        "windows-argv-space-quote-trailing-slash-empty",
        "dual-256k-pipes-and-nonzero-int-exit",
        "owned-job-three-level-setup-exception-exact-python-godot",
        "true-post-start-property-failure-matrix-and-child-custody",
        "owned-job-three-level-normal-exact-python-godot",
        "owned-job-three-level-timeout-124-exact-python-godot",
        "tip-blob-environment-drift-pure-guards",
        "exact-remote-tip-not-ancestor-or-symbolic",
        "static-count-schema-json-fraction-finite-range-and-identity",
        "summary-pair-staging-collisions-and-commit-marker"
    )
    try {
        $canonicalWindowsPowerShell = [System.IO.Path]::GetFullPath((Join-Path $PSHOME "powershell.exe"))
        $canonicalPowerShellHome = [System.IO.Path]::GetFullPath($PSHOME).TrimEnd("\", "/")
        if (-not (Test-Path -LiteralPath $canonicalWindowsPowerShell -PathType Leaf)) {
            throw "canonical Windows PowerShell executable is missing: $canonicalWindowsPowerShell"
        }
        $canonicalWindowsPowerShellItem = Get-Item -LiteralPath $canonicalWindowsPowerShell -Force -ErrorAction Stop
        if (-not ($canonicalWindowsPowerShellItem -is [System.IO.FileInfo]) -or
                ($canonicalWindowsPowerShellItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or
                [System.IO.Path]::GetFullPath($canonicalWindowsPowerShellItem.DirectoryName).TrimEnd("\", "/") -cne $canonicalPowerShellHome -or
                $canonicalWindowsPowerShellItem.Name -cne "powershell.exe") {
            throw "canonical Windows PowerShell path/type validation failed"
        }
        $exactSeedPowerShellPin = Open-Rw061ValidatorReadPin $canonicalWindowsPowerShell
        $exactSeedPowerShellPinReceipt = Get-Rw061ValidatorReadPinReceipt $exactSeedPowerShellPin
        $exactSeedValidatorCommit = (& git -C $root rev-parse HEAD).Trim()
        $exactSeedValidatorCommitExit = $LASTEXITCODE
        $exactSeedValidatorTree = (& git -C $root rev-parse 'HEAD^{tree}').Trim()
        $exactSeedValidatorTreeExit = $LASTEXITCODE
        if ($exactSeedValidatorCommitExit -ne 0 -or $exactSeedValidatorTreeExit -ne 0 -or $exactSeedValidatorCommit -notmatch '^[0-9a-f]{40}$' -or $exactSeedValidatorTree -notmatch '^[0-9a-f]{40}$') {
            throw 'could not bind validator-owned child context to the current commit/tree'
        }
        $exactSeedValidatorLauncherIdentity = Get-ProcessIdentityRecord ([Diagnostics.Process]::GetCurrentProcess())
        $exactSeedValidatorRunContext = New-Q009RunContext -AttemptId $exactSeedAttemptId -CandidateCommit $exactSeedValidatorCommit -CandidateTree $exactSeedValidatorTree -LauncherIdentity $exactSeedValidatorLauncherIdentity -CanonicalLeaseRoot $exactSeedLeaseRoot -WorkingDirectory $root -ProjectRoot $root -LaunchMutexName ('Local\BeatTheHouse-Q009-validator-'+$exactSeedValidatorNonce)
        $exactSeedPowerShellExpectedIdentity = [ordered]@{
            path = [string]$exactSeedPowerShellPinReceipt.final_path
            length = [long]$exactSeedPowerShellPinReceipt.length
            sha256 = [string]$exactSeedPowerShellPinReceipt.sha256
            filesystem_identity = $exactSeedPowerShellPinReceipt.identity
        }
        $ambientShadowPath = Join-Path $exactSeedShadowRoot "powershell.cmd"
        $ambientShadowBytes = [Text.ASCIIEncoding]::new().GetBytes("@echo AMBIENT_POWERSHELL_SHADOW_INVOKED`r`n@exit /b 97`r`n")
        $ambientShadowReceipt = New-Rw061ValidatorShadowFile $exactSeedShadowCell $exactSeedShadowRootReceipt $ambientShadowPath 'ambient_powershell_shadow' $ambientShadowBytes $exactSeedShadowReadPins
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($ambientShadowPath))
        Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
        $exactSeedShadowOwnerReceipt = [ordered]@{
            attempt_id = $exactSeedAttemptId
            support_source = $exactSeedSupportPinReceipt
            launcher_source = $exactSeedLauncherPinReceipt
            powershell_source = $exactSeedPowerShellPinReceipt
            dependency_sources = $exactSeedDependencyPinReceipts
            shadow_support = $shadowSupportReceipt
            shadow_launcher = $shadowLauncherReceipt
            ambient_shadow = $ambientShadowReceipt
        }
        $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'held-shadow-sources' -OwnerKind validator_shadow -OwnerReceipt $exactSeedShadowOwnerReceipt -PreviousHead $exactSeedShadowChain
        $priorValidatorPath = [Environment]::GetEnvironmentVariable("PATH", "Process")
        try {
            [Environment]::SetEnvironmentVariable("PATH", ($exactSeedShadowRoot + [System.IO.Path]::PathSeparator + $priorValidatorPath), "Process")
            $ambientPowerShell = Get-Command powershell -CommandType Application -ErrorAction Stop | Select-Object -First 1
            if ([System.IO.Path]::GetFullPath($ambientPowerShell.Source) -cne [System.IO.Path]::GetFullPath($ambientShadowPath)) {
                throw "ambient PowerShell hostile shadow was not active"
            }
            $exactSeedLauncherStarted = Start-RedirectedProcess -FilePath $canonicalWindowsPowerShell -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$exactSeedLauncher,'-ProjectRoot',$root,'-ValidateOnly','-SelfTestReport',$exactSeedSelfTestReport) -StdoutPath $exactSeedLauncherStdout -StderrPath $exactSeedLauncherStderr -ProcessKind Exact -BaselineGodotIdentityKeys @() -TimeoutSec 300 -ExpectedExecutableIdentity $exactSeedPowerShellExpectedIdentity -RunContext $exactSeedValidatorRunContext
            $exactSeedLauncherCompletion = Complete-RedirectedProcess -Started $exactSeedLauncherStarted -TimeoutSec 300 -ProcessKind Exact -BaselineGodotIdentityKeys @() -OwnedArtifactRoots @([ordered]@{role='validator_shadow';path=[IO.Path]::GetFullPath($exactSeedShadowRoot).TrimEnd('\','/');root_identity=$exactSeedShadowRootReceipt.identity}) -RunContext $exactSeedValidatorRunContext
            if (-not (Test-Q009CompletionResultShape $exactSeedLauncherCompletion) -or -not [bool]$exactSeedLauncherCompletion.native_exit_observed -or [bool]$exactSeedLauncherCompletion.timed_out -or -not [bool]$exactSeedLauncherCompletion.job_cleanup_succeeded -or -not [bool]$exactSeedLauncherCompletion.job_final_membership_empty -or [int]$exactSeedLauncherCompletion.job_final_active_process_count -ne 0 -or -not [bool]$exactSeedLauncherCompletion.executable_pin_clean -or -not [string]::IsNullOrWhiteSpace([string]$exactSeedLauncherCompletion.error)) {
                throw 'validator-owned hostile launcher process did not complete with exact empty-job/executable/channel custody'
            }
            $exactSeedLauncherExitCode = [int]$exactSeedLauncherCompletion.native_exit_code
        }
        finally {
            [Environment]::SetEnvironmentVariable("PATH", $priorValidatorPath, "Process")
        }
        if (-not (Test-Path -LiteralPath $exactSeedLauncherStdout -PathType Leaf) -or -not (Test-Path -LiteralPath $exactSeedLauncherStderr -PathType Leaf)) {
            throw "launcher hostile contracts did not produce separate stdout/stderr captures"
        }
        $exactSeedLauncherStdoutReceipt = Open-Rw061ValidatorShadowArtifact $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedLauncherStdout 'selftest_stdout'
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedLauncherStdout))
        $exactSeedLauncherStderrReceipt = Open-Rw061ValidatorShadowArtifact $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedLauncherStderr 'selftest_stderr'
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedLauncherStderr))
        $exactSeedLauncherOutput = @(Get-Content -LiteralPath $exactSeedLauncherStdout)
        $exactSeedLauncherErrorText = [System.IO.File]::ReadAllText($exactSeedLauncherStderr)
        if (-not [string]::IsNullOrEmpty($exactSeedLauncherErrorText)) {
            throw "launcher hostile contracts emitted stderr: $exactSeedLauncherErrorText"
        }
        if ($exactSeedLauncherExitCode -ne 0) {
            $launcherDetail = ($exactSeedLauncherOutput | ForEach-Object { [string]$_ }) -join " | "
            throw "launcher hostile contracts exited $exactSeedLauncherExitCode. $launcherDetail"
        }
        if (-not (Test-Path -LiteralPath $exactSeedSelfTestReport -PathType Leaf)) {
            throw "launcher hostile contracts did not publish the requested structured self-test report"
        }
        $exactSeedSelfTestReportReceipt = Open-Rw061ValidatorShadowArtifact $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedSelfTestReport 'selftest_report'
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedSelfTestReport))
        [void](Assert-Rw061ValidatorArtifactsBoundToClosedProcess $exactSeedLauncherCompletion $exactSeedValidatorRunContext $exactSeedShadowRootReceipt @($exactSeedLauncherStdoutReceipt,$exactSeedLauncherStderrReceipt,$exactSeedSelfTestReportReceipt))
        if ([string]$exactSeedLauncherCompletion.stdout_identity.key -cne [string]$exactSeedLauncherStdoutReceipt.identity.key -or
                [string]$exactSeedLauncherCompletion.stderr_identity.key -cne [string]$exactSeedLauncherStderrReceipt.identity.key) {
            throw 'validator hostile launcher redirect identities did not match their held closed-job artifacts'
        }
        Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
        $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'selftest-terminal-artifacts' -OwnerKind validator_shadow -OwnerReceipt ([ordered]@{exit_code=[int]$exactSeedLauncherExitCode;stdout=$exactSeedLauncherStdoutReceipt;stderr=$exactSeedLauncherStderrReceipt;report=$exactSeedSelfTestReportReceipt}) -PreviousHead $exactSeedShadowChain
        $exactSeedSelfTest = Get-Content -LiteralPath $exactSeedSelfTestReport -Raw | ConvertFrom-Json
        if (-not (Test-JsonObjectRoot $exactSeedSelfTest)) {
            throw "launcher hostile-contract report must be an object"
        }
        $oneElementStringArray = ('{"value":["string"]}' | ConvertFrom-Json -ErrorAction Stop).value
        if (Test-ExactJsonString $oneElementStringArray) {
            throw "exact JSON string validator accepted a parsed one-element JSON array"
        }
        $expectedExactSeedTopLevelKeys = @(
            "tool", "schema_version", "marker", "passed", "mode", "godot_started",
            "canonical_lease_touched", "canonical_cache_touched", "case_count", "case_names",
            "cases", "hashes", "completed_utc"
        )
        $actualExactSeedTopLevelKeys = @($exactSeedSelfTest.PSObject.Properties.Name | Sort-Object)
        if (($actualExactSeedTopLevelKeys -join "`n") -cne (@($expectedExactSeedTopLevelKeys | Sort-Object) -join "`n")) {
            throw "launcher hostile-contract report has unexpected or missing top-level keys"
        }
        foreach ($topLevelStringField in @("tool", "marker", "mode", "completed_utc")) {
            Assert-ExactJsonString $exactSeedSelfTest.$topLevelStringField "launcher hostile-contract $topLevelStringField"
        }
        [DateTimeOffset]$exactSeedCompletedUtc = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse(
                $exactSeedSelfTest.completed_utc,
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$exactSeedCompletedUtc
            ) -or $exactSeedCompletedUtc.Offset -ne [TimeSpan]::Zero) {
            throw "launcher hostile-contract completed_utc is not a parseable UTC timestamp"
        }
        $numericSchemaVersion = ($exactSeedSelfTest.schema_version -is [int]) -or ($exactSeedSelfTest.schema_version -is [long])
        $numericCaseCount = ($exactSeedSelfTest.case_count -is [int]) -or ($exactSeedSelfTest.case_count -is [long])
        if ($exactSeedSelfTest.tool -cne "rw06_1_environment_qualifying_supervisor_selftest" -or
                -not $numericSchemaVersion -or [int]$exactSeedSelfTest.schema_version -ne 2 -or
                $exactSeedSelfTest.marker -cne "RW06_1_Q009_VALIDATE_ONLY_PASS" -or
                -not ($exactSeedSelfTest.passed -is [bool]) -or -not [bool]$exactSeedSelfTest.passed -or
                $exactSeedSelfTest.mode -cne "Historical22" -or
                -not ($exactSeedSelfTest.godot_started -is [bool]) -or [bool]$exactSeedSelfTest.godot_started -or
                -not ($exactSeedSelfTest.canonical_lease_touched -is [bool]) -or [bool]$exactSeedSelfTest.canonical_lease_touched -or
                -not ($exactSeedSelfTest.canonical_cache_touched -is [bool]) -or [bool]$exactSeedSelfTest.canonical_cache_touched -or
                -not $numericCaseCount -or [int]$exactSeedSelfTest.case_count -ne $expectedExactSeedSelfTestCases.Count) {
            throw "launcher hostile-contract report has an invalid closed top-level schema"
        }
        $actualExactSeedCaseNames = @($exactSeedSelfTest.case_names)
        for ($caseNameIndex = 0; $caseNameIndex -lt $actualExactSeedCaseNames.Count; $caseNameIndex++) {
            Assert-ExactJsonString $actualExactSeedCaseNames[$caseNameIndex] "launcher hostile-contract case_names[$caseNameIndex]"
        }
        $actualExactSeedCases = @($exactSeedSelfTest.cases)
        if ($actualExactSeedCaseNames.Count -ne $expectedExactSeedSelfTestCases.Count -or
                ($actualExactSeedCaseNames -join "`n") -cne ($expectedExactSeedSelfTestCases -join "`n") -or
                @($actualExactSeedCaseNames | Select-Object -Unique).Count -ne $expectedExactSeedSelfTestCases.Count -or
                $actualExactSeedCases.Count -ne $expectedExactSeedSelfTestCases.Count) {
            throw "launcher hostile-contract report does not contain the exact ordered $($expectedExactSeedSelfTestCases.Count)-case matrix"
        }
        $expectedExactSeedCaseKeys = @("name", "passed", "detail")
        for ($caseIndex = 0; $caseIndex -lt $expectedExactSeedSelfTestCases.Count; $caseIndex++) {
            $case = $actualExactSeedCases[$caseIndex]
            if (-not (Test-JsonObjectRoot $case)) {
                throw "launcher hostile-contract case $caseIndex is not an object"
            }
            Assert-ExactJsonString $case.name "launcher hostile-contract cases[$caseIndex].name"
            Assert-ExactJsonString $case.detail "launcher hostile-contract cases[$caseIndex].detail"
            $actualCaseKeys = @($case.PSObject.Properties.Name | Sort-Object)
            if (($actualCaseKeys -join "`n") -cne (@($expectedExactSeedCaseKeys | Sort-Object) -join "`n") -or
                    $case.name -cne $expectedExactSeedSelfTestCases[$caseIndex] -or
                    -not ($case.passed -is [bool]) -or -not [bool]$case.passed -or
                    $case.detail -cne "") {
                throw "launcher hostile-contract case $caseIndex is malformed or did not pass"
            }
        }
        if (-not (Test-JsonObjectRoot $exactSeedSelfTest.hashes)) {
            throw "launcher hostile-contract report is missing its exact source hashes"
        }
        $expectedExactSeedHashes = [ordered]@{
            launcher_sha256 = [string]$exactSeedLauncherPinReceipt.sha256
            support_sha256 = [string]$exactSeedSupportPinReceipt.sha256
            manifest_sha256 = [string]$exactSeedDependencyPinReceipts.manifest.sha256
            audit_gd_sha256 = [string]$exactSeedDependencyPinReceipts.audit.sha256
            static_checker_sha256 = [string]$exactSeedDependencyPinReceipts.static_checker.sha256
            scenario_catalog_sha256 = [string]$exactSeedDependencyPinReceipts.scenario_catalog.sha256
            fidelity_helper_sha256 = [string]$exactSeedDependencyPinReceipts.fidelity_helper.sha256
            foundation_travel_view_model_sha256 = [string]$exactSeedDependencyPinReceipts.foundation_travel_view_model.sha256
            tutorial_flow_sha256 = [string]$exactSeedDependencyPinReceipts.tutorial_flow.sha256
            attribute_badges_sha256 = [string]$exactSeedDependencyPinReceipts.attribute_badges.sha256
        }
        foreach ($hashName in $expectedExactSeedHashes.Keys) {
            Assert-ExactJsonString $exactSeedSelfTest.hashes.$hashName "launcher hostile-contract hashes.$hashName"
            if ($exactSeedSelfTest.hashes.$hashName -cne [string]$expectedExactSeedHashes[$hashName]) {
                throw "launcher hostile-contract report $hashName does not bind the validated file"
            }
        }
        $expectedExactSeedBlobs = [ordered]@{
            launcher_git_blob=[string]$exactSeedHeldGitBlobs.launcher_git_blob
            support_git_blob=[string]$exactSeedHeldGitBlobs.support_git_blob
            manifest_git_blob=[string]$exactSeedHeldGitBlobs.manifest_git_blob
            audit_gd_git_blob=[string]$exactSeedHeldGitBlobs.audit_gd_git_blob
            static_checker_git_blob=[string]$exactSeedHeldGitBlobs.static_checker_git_blob
            scenario_catalog_git_blob=[string]$exactSeedHeldGitBlobs.scenario_catalog_git_blob
            fidelity_helper_git_blob=[string]$exactSeedHeldGitBlobs.fidelity_helper_git_blob
            foundation_travel_view_model_git_blob=[string]$exactSeedHeldGitBlobs.foundation_travel_view_model_git_blob
            tutorial_flow_git_blob=[string]$exactSeedHeldGitBlobs.tutorial_flow_git_blob
            attribute_badges_git_blob=[string]$exactSeedHeldGitBlobs.attribute_badges_git_blob
        }
        foreach ($blobName in $expectedExactSeedBlobs.Keys) {
            Assert-ExactJsonString $exactSeedSelfTest.hashes.$blobName "launcher hostile-contract hashes.$blobName"
            if ($exactSeedSelfTest.hashes.$blobName -cne [string]$expectedExactSeedBlobs[$blobName]) {
                throw "launcher hostile-contract report $blobName does not bind the validated file"
            }
        }
        $expectedExactSeedHashKeys = @($expectedExactSeedHashes.Keys) + @($expectedExactSeedBlobs.Keys)
        $actualExactSeedHashKeys = @($exactSeedSelfTest.hashes.PSObject.Properties.Name | Sort-Object)
        if (($actualExactSeedHashKeys -join "`n") -cne (@($expectedExactSeedHashKeys | Sort-Object) -join "`n")) {
            throw "launcher hostile-contract report has unexpected or missing source-hash keys"
        }
        $expectedSelfTestMarker = "RW06_1_Q009_VALIDATE_ONLY_PASS report=$exactSeedSelfTestReport cases=$($expectedExactSeedSelfTestCases.Count) sha256=$($exactSeedSelfTestReportReceipt.sha256) native_key=$($exactSeedSelfTestReportReceipt.identity.native_key) creation_ticks=$($exactSeedSelfTestReportReceipt.identity.creation_ticks)"
        if ($exactSeedLauncherOutput.Count -ne 1 -or
                -not (Test-ExactJsonString $exactSeedLauncherOutput[0]) -or
                $exactSeedLauncherOutput[0] -cne $expectedSelfTestMarker) {
            throw "launcher hostile contracts did not emit only the exact success marker on stdout"
        }

        $auditSource = $strictUtf8.GetString([byte[]]$exactSeedDependencyPins.audit.bytes)
        if (@(Get-Rw061AuditTravelSourceIssues $auditSource).Count -ne 0) {
            throw 'environment generation evidence does not function-scope both catalogs to the constrained production world-route view'
        }
        $misScopedAudit=$auditSource.Replace('func _simulate_run(','func _misplaced_simulate_run(')+"`nfunc _simulate_run() -> void:`n`tpass`n"
        if(@(Get-Rw061AuditTravelSourceIssues $misScopedAudit).Count-eq0){throw 'validator hostile accepted a post-event catalog producer moved outside _simulate_run'}
        $missingOverlayGuard=$auditSource.Replace('if run_state != null and run_state.delivery_has_active_run():','if run_state != null and false:')
        if(@(Get-Rw061AuditTravelSourceIssues $missingOverlayGuard).Count-eq0){throw 'validator hostile accepted a missing delivery-overlay exclusion'}
        $manualTargetCatalog=$auditSource.Replace('return _production_foundation_travel_host(run_state)._travel_target_ids()','return WorldMapScript.travel_target_ids(run_state.world_map, run_state.current_world_node_id(), 2, 3, [])')
        if(@(Get-Rw061AuditTravelSourceIssues $manualTargetCatalog).Count-eq0){throw 'validator hostile accepted a hand-built world target catalog'}
        $earlyTargetReturn=$auditSource.Replace('func _travel_target_ids(run_state: RunState) -> Array:',"func _travel_target_ids(run_state: RunState) -> Array:`n`treturn []")
        if(@(Get-Rw061AuditTravelSourceIssues $earlyTargetReturn).Count-eq0){throw 'validator hostile accepted an extra early return before the production Foundation catalog'}
        $choiceHostBypass=$auditSource.Replace('return view_model_script.travel_choice(self, target_id, known_target_ids)','return {}')
        if(@(Get-Rw061AuditTravelSourceIssues $choiceHostBypass).Count-eq0){throw 'validator hostile accepted a bypassed production Foundation travel choice'}
        $walkTimingBypass=$auditSource.Replace('const WALK_CLOCK_MINUTES_PER_BLOCK := 10','const WALK_CLOCK_MINUTES_PER_BLOCK := 6')
        if(@(Get-Rw061AuditTravelSourceIssues $walkTimingBypass).Count-eq0){throw 'validator hostile accepted generator-style timing for authored Walk routes'}
        $multilineTravelAmbiguity='"""hostile`n'+$auditSource
        if(@(Get-Rw061AuditTravelSourceIssues $multilineTravelAmbiguity).Count-eq0){throw 'validator hostile accepted multiline-string GDScript ambiguity'}
        if ([regex]::Matches($auditSource,'(?m)^\s*"fingerprint"\s*:\s*_json_sha256\(\{"active"\s*:\s*false\}\),\s*$').Count -ne 1) {
            throw 'environment generation evidence lacks exactly one canonical inactive projection producer witness'
        }
        $inactiveBytes = [Text.Encoding]::UTF8.GetBytes('{"active":false}')
        $inactiveHasher = [Security.Cryptography.SHA256]::Create()
        try { $inactiveFingerprint = ([BitConverter]::ToString($inactiveHasher.ComputeHash($inactiveBytes))).Replace('-','').ToLowerInvariant() }
        finally { $inactiveHasher.Dispose() }
        if ($inactiveFingerprint -cne '78b558bd2357fbe7ad52804fb3af1b8664b23db096b1deb22d215dde25b152bf') {
            throw 'validator canonical inactive producer payload fingerprint changed'
        }

        $independentDriverSource = @'
param([Parameter(Mandatory=$true)][string]$LauncherPath,[Parameter(Mandatory=$true)][string]$ProjectRoot,[Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
. $LauncherPath -LoadAdmissionFunctionsOnly -ProjectRoot $ProjectRoot
$cases=[Collections.Generic.List[object]]::new()
function Add-IndependentMutation([string]$Name,[scriptblock]$Mutate){
    $fixture=New-HistoricalSemanticSelfTestFixture
    & $Mutate $fixture
    $raw=$fixture.report|ConvertTo-Json -Depth 100
    $issues=@(Get-AuditSemanticIssues $fixture.report $fixture.attempt_id 1 6 5 $fixture.expectation $fixture.combo $raw)
    if($issues.Count-le0){throw "independent mutation was accepted: $Name"}
    [void]$cases.Add([ordered]@{name=$Name;passed=$true;issue_count=$issues.Count})
}
$baseline=New-HistoricalSemanticSelfTestFixture
$baselineRaw=$baseline.report|ConvertTo-Json -Depth 100
$baselineIssues=@(Get-AuditSemanticIssues $baseline.report $baseline.attempt_id 1 6 5 $baseline.expectation $baseline.combo $baselineRaw)
if($baselineIssues.Count-ne0){throw ('independent baseline was rejected: '+($baselineIssues-join'; '))}
Add-IndependentMutation 'omitted-arrival-seed-field' {param($f)$f.report.environment_records[2].arrival_receipt.PSObject.Properties.Remove('challenge_daily_id')}
Add-IndependentMutation 'initial-finalization-true' {param($f)$f.report.environment_records[0].arrival_receipt.production_scenario_finalized=$true;$f.report.runs[0].initial_arrival_receipt.production_scenario_finalized=$true}
Add-IndependentMutation 'travel-finalization-false' {param($f)$f.report.environment_records[1].arrival_receipt.production_scenario_finalized=$false;$f.report.travel_records[0].arrival_receipt.production_scenario_finalized=$false}
Add-IndependentMutation 'post-heat-target-removal' {param($f)$f.report.travel_records[0].admitted_targets_after_heat=[object[]]@('spare-a')}
Add-IndependentMutation 'travel-errors-count-mismatch' {param($f)$f.report.environment_records[1].arrival_receipt.travel_errors=[object[]]@('forged travel error');$f.report.environment_records[1].arrival_receipt.travel_error_count=0}
Add-IndependentMutation 'ordinary-authority-bool-count-tamper' {param($f)$f.report.environment_records[0].runtime_scenario_layout.authority_receipts[0].authority_valid=$false;$f.report.environment_records[0].runtime_scenario_layout.actionable_authority_count=0}
Add-IndependentMutation 'selected-choice-resealed-splice' {param($f)$f.report.travel_records[0].selected_choice.label='validator-resealed-splice';$f.report.travel_records[0].selected_choice_digest=Get-Q009CanonicalJsonSha256 $f.report.travel_records[0].selected_choice}
Add-IndependentMutation 'public-catalog-digest-mismatch' {param($f)$f.report.environment_records[1].travel_after_events_digest='0'.PadLeft(64,'0')}
Add-IndependentMutation 'catalog-extra-resealed' {param($f)$extra=$f.report.environment_records[0].travel_after_events[0]|ConvertTo-Json -Depth 20|ConvertFrom-Json;$extra.id='validator-extra';$extra.label='validator-extra';$f.report.environment_records[0].travel_after_events=[object[]]@($f.report.environment_records[0].travel_after_events)+@($extra);$f.report.environment_records[0].travel_after_events_digest=Get-Q009CanonicalJsonSha256 $f.report.environment_records[0].travel_after_events}
Add-IndependentMutation 'catalog-null-resealed' {param($f)$f.report.environment_records[0].travel_after_events[1].risk_event=$null;$f.report.environment_records[0].travel_after_events_digest=Get-Q009CanonicalJsonSha256 $f.report.environment_records[0].travel_after_events}
Add-IndependentMutation 'admission-reordered-resealed' {param($f)$row=$f.report.travel_records[0];$row.admitted_targets_before=[object[]]@($row.admitted_targets_before[2],$row.admitted_targets_before[1],$row.admitted_targets_before[0]);$row.admitted_targets_before_digest=Get-Q009CanonicalJsonSha256 $row.admitted_targets_before}
$expected=@('omitted-arrival-seed-field','initial-finalization-true','travel-finalization-false','post-heat-target-removal','travel-errors-count-mismatch','ordinary-authority-bool-count-tamper','selected-choice-resealed-splice','public-catalog-digest-mismatch','catalog-extra-resealed','catalog-null-resealed','admission-reordered-resealed')
if($cases.Count-ne$expected.Count-or(@($cases|ForEach-Object{[string]$_.name})-join"`n")-cne($expected-join"`n")){throw 'independent mutation matrix order/count drifted'}
if(Test-Path -LiteralPath $ReportPath){throw 'independent mutation report already exists'}
$report=[ordered]@{tool='rw06_1_validator_independent_admission_hostiles';schema_version=1;passed=$true;case_count=$cases.Count;case_names=@($cases|ForEach-Object{[string]$_.name});cases=@($cases)}
[IO.File]::WriteAllText($ReportPath,($report|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Output "RW06_1_INDEPENDENT_ADMISSION_PASS report=$ReportPath cases=$($cases.Count)"
'@
        $independentDriverBytes = [Text.UTF8Encoding]::new($false).GetBytes($independentDriverSource)
        $exactSeedIndependentDriverReceipt = New-Rw061ValidatorShadowFile $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedIndependentDriver 'independent_driver' $independentDriverBytes $exactSeedShadowReadPins
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedIndependentDriver))
        Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
        $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'independent-driver-held' -OwnerKind validator_shadow -OwnerReceipt $exactSeedIndependentDriverReceipt -PreviousHead $exactSeedShadowChain
        $exactSeedIndependentStarted = Start-RedirectedProcess -FilePath $canonicalWindowsPowerShell -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$exactSeedIndependentDriver,'-LauncherPath',$exactSeedLauncher,'-ProjectRoot',$root,'-ReportPath',$exactSeedIndependentReport) -StdoutPath $exactSeedIndependentStdout -StderrPath $exactSeedIndependentStderr -ProcessKind Exact -BaselineGodotIdentityKeys @() -TimeoutSec 300 -ExpectedExecutableIdentity $exactSeedPowerShellExpectedIdentity -RunContext $exactSeedValidatorRunContext
        $exactSeedIndependentCompletion = Complete-RedirectedProcess -Started $exactSeedIndependentStarted -TimeoutSec 300 -ProcessKind Exact -BaselineGodotIdentityKeys @() -OwnedArtifactRoots @([ordered]@{role='validator_shadow';path=[IO.Path]::GetFullPath($exactSeedShadowRoot).TrimEnd('\','/');root_identity=$exactSeedShadowRootReceipt.identity}) -RunContext $exactSeedValidatorRunContext
        if (-not (Test-Q009CompletionResultShape $exactSeedIndependentCompletion) -or -not [bool]$exactSeedIndependentCompletion.native_exit_observed -or [bool]$exactSeedIndependentCompletion.timed_out -or -not [bool]$exactSeedIndependentCompletion.job_cleanup_succeeded -or -not [bool]$exactSeedIndependentCompletion.job_final_membership_empty -or [int]$exactSeedIndependentCompletion.job_final_active_process_count -ne 0 -or -not [bool]$exactSeedIndependentCompletion.executable_pin_clean -or -not [string]::IsNullOrWhiteSpace([string]$exactSeedIndependentCompletion.error)) {
            throw 'validator-owned independent mutation process did not complete with exact empty-job/executable/channel custody'
        }
        $exactSeedIndependentExitCode=[int]$exactSeedIndependentCompletion.native_exit_code
        $exactSeedIndependentStdoutReceipt = Open-Rw061ValidatorShadowArtifact $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedIndependentStdout 'independent_stdout'
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedIndependentStdout))
        $exactSeedIndependentStderrReceipt = Open-Rw061ValidatorShadowArtifact $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedIndependentStderr 'independent_stderr'
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedIndependentStderr))
        $independentError=[IO.File]::ReadAllText($exactSeedIndependentStderr)
        $independentOutput=@(Get-Content -LiteralPath $exactSeedIndependentStdout)
        if($exactSeedIndependentExitCode-ne0-or-not[string]::IsNullOrEmpty($independentError)-or-not(Test-Path -LiteralPath $exactSeedIndependentReport -PathType Leaf)){
            throw "independent validator-authored admission hostiles failed: exit=$exactSeedIndependentExitCode stderr=$independentError stdout=$($independentOutput-join' | ')"
        }
        $exactSeedIndependentReportReceipt = Open-Rw061ValidatorShadowArtifact $exactSeedShadowCell $exactSeedShadowRootReceipt $exactSeedIndependentReport 'independent_report'
        [void]$exactSeedShadowMembers.Add([IO.Path]::GetFileName($exactSeedIndependentReport))
        [void](Assert-Rw061ValidatorArtifactsBoundToClosedProcess $exactSeedIndependentCompletion $exactSeedValidatorRunContext $exactSeedShadowRootReceipt @($exactSeedIndependentStdoutReceipt,$exactSeedIndependentStderrReceipt,$exactSeedIndependentReportReceipt))
        if ([string]$exactSeedIndependentCompletion.stdout_identity.key -cne [string]$exactSeedIndependentStdoutReceipt.identity.key -or
                [string]$exactSeedIndependentCompletion.stderr_identity.key -cne [string]$exactSeedIndependentStderrReceipt.identity.key) {
            throw 'validator independent-run redirect identities did not match their held closed-job artifacts'
        }
        Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
        $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'independent-terminal-artifacts' -OwnerKind validator_shadow -OwnerReceipt ([ordered]@{exit_code=[int]$exactSeedIndependentExitCode;stdout=$exactSeedIndependentStdoutReceipt;stderr=$exactSeedIndependentStderrReceipt;report=$exactSeedIndependentReportReceipt}) -PreviousHead $exactSeedShadowChain
        $independentReport=Get-Content -LiteralPath $exactSeedIndependentReport -Raw|ConvertFrom-Json
        $expectedIndependentNames=@('omitted-arrival-seed-field','initial-finalization-true','travel-finalization-false','post-heat-target-removal','travel-errors-count-mismatch','ordinary-authority-bool-count-tamper','selected-choice-resealed-splice','public-catalog-digest-mismatch','catalog-extra-resealed','catalog-null-resealed','admission-reordered-resealed')
        $expectedIndependentTopKeys=@('tool','schema_version','passed','case_count','case_names','cases')|Sort-Object
        if(-not(Test-JsonObjectRoot $independentReport)-or(@($independentReport.PSObject.Properties.Name|Sort-Object)-join"`n")-cne($expectedIndependentTopKeys-join"`n")){throw 'independent validator-authored admission hostile report root schema was invalid'}
        Assert-ExactJsonString $independentReport.tool 'independent validator-authored tool'
        if($independentReport.tool-cne'rw06_1_validator_independent_admission_hostiles'-or-not($independentReport.schema_version-is[int]-or$independentReport.schema_version-is[long])-or[int]$independentReport.schema_version-ne1-or-not($independentReport.passed-is[bool])-or-not[bool]$independentReport.passed-or-not($independentReport.case_count-is[int]-or$independentReport.case_count-is[long])-or[int]$independentReport.case_count-ne$expectedIndependentNames.Count-or-not($independentReport.case_names-is[System.Array])-or-not($independentReport.cases-is[System.Array])-or@($independentReport.case_names).Count-ne$expectedIndependentNames.Count-or@($independentReport.cases).Count-ne$expectedIndependentNames.Count){throw 'independent validator-authored admission hostile report schema/order was invalid'}
        for($nameIndex=0;$nameIndex-lt$expectedIndependentNames.Count;$nameIndex+=1){Assert-ExactJsonString $independentReport.case_names[$nameIndex] "independent case_names[$nameIndex]";if($independentReport.case_names[$nameIndex]-cne$expectedIndependentNames[$nameIndex]){throw "independent case_names[$nameIndex] changed"}}
        $expectedIndependentCaseKeys=@('name','passed','issue_count')|Sort-Object
        for($index=0;$index-lt$expectedIndependentNames.Count;$index+=1){$case=$independentReport.cases[$index];if(-not(Test-JsonObjectRoot $case)-or(@($case.PSObject.Properties.Name|Sort-Object)-join"`n")-cne($expectedIndependentCaseKeys-join"`n")){throw "independent admission case $index schema was malformed"};Assert-ExactJsonString $case.name "independent cases[$index].name";if($case.name-cne$expectedIndependentNames[$index]-or-not($case.passed-is[bool])-or-not[bool]$case.passed-or-not($case.issue_count-is[int]-or$case.issue_count-is[long])-or[int]$case.issue_count-le0){throw "independent admission case $index was malformed or did not reject"}}
        $expectedIndependentMarker="RW06_1_INDEPENDENT_ADMISSION_PASS report=$exactSeedIndependentReport cases=$($expectedIndependentNames.Count)"
        if($independentOutput.Count-ne1-or$independentOutput[0]-cne$expectedIndependentMarker){throw 'independent admission hostile runner did not emit only its exact success marker'}
        $supportPinTerminal = Get-Rw061ValidatorReadPinReceipt $exactSeedSupportPin
        $launcherPinTerminal = Get-Rw061ValidatorReadPinReceipt $exactSeedLauncherPin
        $powerShellPinTerminal = Get-Rw061ValidatorReadPinReceipt $exactSeedPowerShellPin
        if (($supportPinTerminal | ConvertTo-Json -Depth 8 -Compress) -cne ($exactSeedSupportPinReceipt | ConvertTo-Json -Depth 8 -Compress) -or
                ($launcherPinTerminal | ConvertTo-Json -Depth 8 -Compress) -cne ($exactSeedLauncherPinReceipt | ConvertTo-Json -Depth 8 -Compress) -or
                ($powerShellPinTerminal | ConvertTo-Json -Depth 8 -Compress) -cne ($exactSeedPowerShellPinReceipt | ConvertTo-Json -Depth 8 -Compress)) {
            throw 'validator held source/executable identity changed across child execution'
        }
        foreach($dependencyName in @($exactSeedDependencyPins.Keys)){
            $terminal=Get-Rw061ValidatorReadPinReceipt $exactSeedDependencyPins[$dependencyName]
            if(($terminal|ConvertTo-Json -Depth 8 -Compress)-cne($exactSeedDependencyPinReceipts[$dependencyName]|ConvertTo-Json -Depth 8 -Compress)){throw "validator held dependency identity changed across child execution: $dependencyName"}
        }
        Assert-Rw061ValidatorShadowMembers $exactSeedShadowRoot @($exactSeedShadowMembers)
        $exactSeedShadowChain = New-Q009OwnedChildManifestChainHead -RootPath $exactSeedShadowRoot -RootIdentity $exactSeedShadowRootReceipt.identity -AttemptId $exactSeedAttemptId -Boundary 'validator-terminal-green' -OwnerKind validator_shadow -OwnerReceipt ([ordered]@{selftest_exit=[int]$exactSeedLauncherExitCode;independent_exit=[int]$exactSeedIndependentExitCode;support_pin=$supportPinTerminal;launcher_pin=$launcherPinTerminal;powershell_pin=$powerShellPinTerminal}) -PreviousHead $exactSeedShadowChain
    }
    catch {
        $exactSeedInnerFailure = $_.Exception
    }
    finally {
        $shadowCleanupError = ''
        if ($null -ne $exactSeedShadowCell) {
            try {
                Close-Rw061ValidatorShadowReadPins $exactSeedShadowReadPins
                $shadowRelease = Close-Q009AllOpenNativeHandles $exactSeedShadowCell 'rw06_1 validator shadow terminal handle release'
                if (-not [bool]$shadowRelease.all_terminal -or @($shadowRelease.errors).Count -ne 0 -or @($shadowRelease.nonterminal_slots).Count -ne 0) {
                    throw 'validator shadow handles did not all close with checked native success'
                }
                if ($null -eq $exactSeedShadowRootReceipt -or -not (Test-Q009OwnedChildManifestChainHeadShape $exactSeedShadowChain $exactSeedShadowRootReceipt.identity $exactSeedAttemptId)) {
                    throw 'validator shadow lacked a sealed authorized child-manifest chain at cleanup'
                }
                $exactSeedShadowCleanupReceipt = Remove-Q009ExactOwnedTree -OwnedPath $exactSeedShadowRoot -QuarantinePath $exactSeedShadowQuarantine -ExpectedRootIdentity $exactSeedShadowRootReceipt.identity -AuthorizedChainHead $exactSeedShadowChain -ExpectedAttemptId $exactSeedAttemptId
                if ($exactSeedShadowCleanupReceipt.removed -isnot [bool] -or -not [bool]$exactSeedShadowCleanupReceipt.removed -or (Test-Path -LiteralPath $exactSeedShadowRoot) -or (Test-Path -LiteralPath $exactSeedShadowQuarantine)) {
                    throw 'validator shadow cleanup did not prove exact root/quarantine absence'
                }
            }
            catch {
                $shadowCleanupError = $_.Exception.Message
            }
        }
        foreach ($sourcePin in @($exactSeedPowerShellPin,$exactSeedLauncherPin,$exactSeedSupportPin)+@($exactSeedDependencyPins.Values)) {
            try { Close-Rw061ValidatorReadPin $sourcePin } catch { $shadowCleanupError = if ($shadowCleanupError) { $shadowCleanupError + ' | source pin close: ' + $_.Exception.Message } else { 'source pin close: ' + $_.Exception.Message } }
        }
        if (-not [string]::IsNullOrWhiteSpace($shadowCleanupError)) {
            $cleanupFailure = [InvalidOperationException]::new('rw06_1 validator exact shadow cleanup failed: ' + $shadowCleanupError)
            if ($null -eq $exactSeedInnerFailure) { $exactSeedInnerFailure = $cleanupFailure }
            else { $exactSeedInnerFailure = [AggregateException]::new('rw06_1 validator inner failure plus exact shadow cleanup failure', @($exactSeedInnerFailure,$cleanupFailure)) }
        }
    }
    $exactSeedPostFileCensus = Get-Rw061ValidatorFileIdentityCensus $exactSeedBoundPaths
    foreach($path in $exactSeedPreFileCensus.Keys){
        $before=$exactSeedPreFileCensus[$path];$after=$exactSeedPostFileCensus[$path]
        if($null-eq$after-or($before|ConvertTo-Json -Compress)-cne($after|ConvertTo-Json -Compress)){throw "rw06_1 validator-bound source identity drifted: $path"}
    }
    $exactSeedPostProcessCensus=@(Get-Rw061ValidatorProcessCensus);$preProcessKeys=@($exactSeedPreProcessCensus|ForEach-Object{[string]$_.key});$newProcesses=@($exactSeedPostProcessCensus|Where-Object{$preProcessKeys-notcontains[string]$_.key})
    if($newProcesses.Count-ne0){throw "rw06_1 validator left or observed new relevant process identities: $(@($newProcesses|ForEach-Object{[string]$_.key})-join', ')"}
    $exactSeedPostLeaseCensus=@(Get-Rw061ValidatorLeaseCensus $exactSeedLeaseRoot)
    if((@($exactSeedPreLeaseCensus)|ConvertTo-Json -Compress -Depth 5)-cne(@($exactSeedPostLeaseCensus)|ConvertTo-Json -Compress -Depth 5)){throw 'rw06_1 engine-free validator changed the canonical Q-009 lease census'}
    $exactSeedPostResidueCensus=@(Get-Rw061ValidatorSelfTestResidueCensus)
    if((@($exactSeedPreResidueCensus)|ConvertTo-Json -Compress -Depth 5)-cne(@($exactSeedPostResidueCensus)|ConvertTo-Json -Compress -Depth 5)){throw 'rw06_1 launcher self-test created or changed a residual rw06-q009-selftest root'}
    $exactSeedPostCacheCensus=Get-Rw061ValidatorTreeCensus $exactSeedProjectCache
    if(($exactSeedPreCacheCensus|ConvertTo-Json -Compress -Depth 8)-cne($exactSeedPostCacheCensus|ConvertTo-Json -Compress -Depth 8)){throw 'rw06_1 launcher self-test changed the candidate project cache tree'}
    $exactSeedPostEnvironmentCensus=Get-Rw061ValidatorEnvironmentCensus
    if(($exactSeedPreEnvironmentCensus|ConvertTo-Json -Compress)-cne($exactSeedPostEnvironmentCensus|ConvertTo-Json -Compress)){throw 'rw06_1 launcher self-test changed the validator process environment'}
    if($null-ne$exactSeedInnerFailure){throw $exactSeedInnerFailure}
}
catch {
    $failures.Add("rw06_1 exact-seed launcher hostile contracts failed: $($_.Exception.Message)")
}
finally {
    # This fallback covers failures before the inner execution/cleanup block was
    # entered. It never invents ownership: an unsealed or changed shadow is
    # retained and reported instead of being adopted or removed by pathname.
    if ($null -ne $exactSeedShadowCell -and $null -ne $exactSeedShadowRootReceipt -and (Test-Path -LiteralPath $exactSeedShadowRoot)) {
        try {
            Close-Rw061ValidatorShadowReadPins $exactSeedShadowReadPins
            $fallbackRelease = Close-Q009AllOpenNativeHandles $exactSeedShadowCell 'rw06_1 validator outer fallback handle release'
            if (-not [bool]$fallbackRelease.all_terminal -or @($fallbackRelease.errors).Count -ne 0 -or @($fallbackRelease.nonterminal_slots).Count -ne 0) {
                throw 'outer fallback did not close every exact shadow handle'
            }
            if (-not (Test-Q009OwnedChildManifestChainHeadShape $exactSeedShadowChain $exactSeedShadowRootReceipt.identity $exactSeedAttemptId)) {
                throw 'outer fallback refused an unsealed validator shadow'
            }
            $fallbackCleanup = Remove-Q009ExactOwnedTree -OwnedPath $exactSeedShadowRoot -QuarantinePath $exactSeedShadowQuarantine -ExpectedRootIdentity $exactSeedShadowRootReceipt.identity -AuthorizedChainHead $exactSeedShadowChain -ExpectedAttemptId $exactSeedAttemptId
            if ($fallbackCleanup.removed -isnot [bool] -or -not [bool]$fallbackCleanup.removed -or (Test-Path -LiteralPath $exactSeedShadowRoot) -or (Test-Path -LiteralPath $exactSeedShadowQuarantine)) {
                throw 'outer fallback did not prove validator shadow absence'
            }
        }
        catch {
            $failures.Add("rw06_1 validator retained an exact shadow after fail-closed cleanup: $($_.Exception.Message)")
        }
    }
    foreach ($sourcePin in @($exactSeedPowerShellPin,$exactSeedLauncherPin,$exactSeedSupportPin)+@($exactSeedDependencyPins.Values)) {
        try { Close-Rw061ValidatorReadPin $sourcePin }
        catch { $failures.Add("rw06_1 validator source pin close failed: $($_.Exception.Message)") }
    }
}

try {
    & (Join-Path $root "tools/foundation_systems_shards_test.ps1") -Quiet
}
catch {
    $failures.Add("Foundation systems shard hostile contracts failed: $($_.Exception.Message)")
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    exit 1
}

if (-not $Quiet) {
    Write-Host "Beat the House foundation architecture validation passed."
}
