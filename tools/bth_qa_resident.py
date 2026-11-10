"""Closed QA resident-profile admission. No profile content reads or migration.

An explicit resident binding is separate from a fresh Layout. A process-held named
mutex serializes guarded launchers; only QA custody/job/state JSON is read/hashed.
Keep custody unchanged until the last child is assigned, then update it before
resuming that profile's worker. Further child admission will reject changed custody.
Release the lease only after the owned capped Job is drained to zero.
"""
from dataclasses import dataclass,replace,asdict
from pathlib import Path
import ctypes,hashlib,json,os,re,stat
import bth_qa_storage as g

@dataclass(frozen=True)
class ResidentBinding:
    campaign_id: str
    origin: str
    expected_commit: str
    profile: str
    custody: str
    last_output: str
    last_case: str
    profile_identity: tuple
    metadata_hashes: tuple
    mutex_name: str
    recovery_policy: str = ""
    def as_dict(self):
        result=asdict(self)
        if not self.recovery_policy:result.pop('recovery_policy')
        result['profile_identity']=list(self.profile_identity)
        result['metadata_hashes']=dict(self.metadata_hashes)
        return result

MAX_QA_JSON_BYTES=2*1024*1024
_leases={}
_lease_profiles={}

def _owned_json(path):
    path=g._path(path);g._inspect(path.parent)
    exists,directory,reparse=g._probe(path)
    if not exists or directory or reparse:
        g._fail('resident_receipt_invalid',path,'plain owned QA receipt required')
    if path.stat().st_size>MAX_QA_JSON_BYTES:
        g._fail('resident_receipt_bound',path,'QA receipt exceeds2MiB')
    with path.open('rb') as stream:raw=stream.read(MAX_QA_JSON_BYTES+1)
    if len(raw)>MAX_QA_JSON_BYTES:g._fail('resident_receipt_bound',path,'QA receipt grew beyond2MiB')
    try:value=json.loads(raw)
    except (ValueError,UnicodeError):g._fail('resident_receipt_invalid',path,'invalid QA JSON')
    if not isinstance(value,dict):g._fail('resident_receipt_invalid',path,'QA JSON object required')
    return value,hashlib.sha256(raw).hexdigest()

def _dir_identity(path):
    info=os.stat(path,follow_symlinks=False)
    if not stat.S_ISDIR(info.st_mode) or info.st_ino<=0:g._fail('resident_identity_unavailable',path,'plain directory file identity required')
    return (info.st_dev,info.st_ino)

def _recovery_module(name):
    if name=='r17-1307-closed-inspection':
        import bth_qa_closed_inspection as policy
    elif name=='r17-1315-receipt-crash-inspection':
        import bth_qa_crash_inspection as policy
    elif name=='r17-1350-paid-trip-cold-inspection':
        import bth_qa_paid_trip_inspection as policy
    else:g._fail('resident_recovery_policy_unknown',str(name),'Only exact reviewed policies are supported')
    return policy


def _snapshot(workspace,profile,custody,campaign,origin,commit,*,recovery_policy="",run_id=""):
    if not isinstance(campaign,str) or not isinstance(commit,str) or not re.fullmatch(r'[a-z][a-z0-9-]{2,60}',campaign) or not re.fullmatch(r'[0-9a-f]{40}',commit):
        g._fail('resident_identity_invalid',profile,'explicit campaign and pinned commit required')
    match=re.fullmatch(r'http://127\.0\.0\.1:([1-9][0-9]{0,4})',origin) if isinstance(origin,str) else None
    if not match or int(match[1])>65535:g._fail('resident_origin_invalid',origin,'explicit loopback origin required')
    if g._key(profile)!=g._key(workspace/'qa-resident-profiles'/campaign) or g._key(custody)!=g._key(workspace/'evidence'/(campaign+'-custody.json')):
        g._fail('resident_path_identity',profile,'profile/custody must match the declared existing QA campaign')
    g._inspect(profile)
    if g._probe(profile)!=(True,True,False):g._fail('resident_profile_invalid',profile,'existing plain directory required')
    record,ch=_owned_json(custody)
    case=record.get('last_case','')
    if not isinstance(case,str) or not re.fullmatch(r'[a-z][a-z0-9-]{2,70}',case):g._fail('resident_custody_invalid',custody,'exact previous case required')
    out=workspace/'evidence'/case
    if (not recovery_policy and record.get('status')!='CLEAN_CLOSED') or record.get('campaign_id')!=campaign or record.get('origin')!=origin or g._key(record.get('profile_path',''))!=g._key(profile) or g._key(record.get('last_output',''))!=g._key(out):
        g._fail('resident_custody_invalid',custody,'clean, matching campaign custody required')
    job,jh=_owned_json(out/'job.json');state,sh=_owned_json(out/'state.json')
    if job.get('campaign_id')!=campaign or state.get('profile_identity')!=campaign or job.get('origin')!=origin or state.get('origin')!=origin or job.get('tested_commit')!=commit or state.get('tested_commit')!=commit or g._key(job.get('profile_path',''))!=g._key(profile) or g._key(state.get('profile_path',''))!=g._key(profile):
        g._fail('resident_receipt_identity',out,'previous job/state identity differs')
    if not recovery_policy and (
        type(job.get('browser_exit')) is not int or job['browser_exit'] != 0 or
        type(job.get('active_at_release')) is not int or job['active_at_release'] != 0 or
        job.get('timed_out') is not False or job.get('error') is not None or
        job.get('cleanup_errors') != [] or
        not all(state.get(k) is True for k in ('closed', 'completed', 'context_close_completed')) or
        state.get('inflight') is not None or state.get('error') is not None
    ):
        g._fail('resident_not_closed',out,'owned browser/job closure not proven')
    if record.get('mode') not in ('create','resume') or record['mode']!=job.get('mode') or record['mode']!=state.get('profile_mode') or state.get('persistent_profile') is not True or not isinstance(state.get('game_dom'),dict) or state['game_dom'].get('url')!=origin+'/index.html':
        g._fail('resident_receipt_identity',out,'previous profile mode/origin not proven')
    hashes={'custody':ch,'job':jh,'state':sh}
    if recovery_policy:
        policy=_recovery_module(recovery_policy)
        policy.validate_scope(g.DEFAULT_ROOT,workspace,run_id,profile,custody,campaign,origin,commit,recovery_policy)
        _,hashes=policy.collect(workspace,profile,custody,campaign,origin,commit,run_id,
            {'custody':record,'job':job,'state':state},hashes)
    elif job.get('recovery_policy') or state.get('recovery_policy') or case in ('qa-batch-1308-r17-closed-bound-cold','qa-batch-1316-r17b-crash-cold-inspection','qa-batch-1351-r17b-motel-cold-inspection'):
        exact={'qa-batch-1308-r17-closed-bound-cold':'r17-1307-closed-inspection',
          'qa-batch-1316-r17b-crash-cold-inspection':'r17-1315-receipt-crash-inspection',
          'qa-batch-1351-r17b-motel-cold-inspection':'r17-1350-paid-trip-cold-inspection'}
        policy=_recovery_module(exact.get(case) or job.get('recovery_policy') or state.get('recovery_policy'))
        hashes.update(policy.review_success(out,job,state))
    mutex='Local\\BTH-QA-Resident-'+hashlib.sha256(g._key(profile).encode()).hexdigest()
    return ResidentBinding(campaign,origin,commit,str(profile),str(custody),str(out),case,_dir_identity(profile),
        tuple(sorted(hashes.items())),mutex,recovery_policy)

def validate_structure(layout,paths):
    b=layout.resident_binding
    if isinstance(b,ResidentBinding) and b.recovery_policy:
        policy=_recovery_module(b.recovery_policy)
        policy.validate_scope(layout.root,layout.workspace,layout.run_id,layout.profile,Path(b.custody),b.campaign_id,b.origin,b.expected_commit,b.recovery_policy)
    if not isinstance(b,ResidentBinding) or g._key(paths['profile'])!=g._key(b.profile):
        g._fail('resident_binding_invalid',paths['profile'],'typed resident identity required')
    if g._key(paths['profile'])!=g._key(paths['workspace']/'qa-resident-profiles'/b.campaign_id):
        g._fail('resident_path_identity',paths['profile'],'profile must belong to this exact QA workspace')

def validate_binding(layout,require_lease=False):
    b=layout.resident_binding
    current=_snapshot(layout.workspace,layout.profile,Path(b.custody),b.campaign_id,b.origin,b.expected_commit,recovery_policy=b.recovery_policy,run_id=layout.run_id)
    if current!=b:g._fail('resident_binding_changed',layout.profile,'directory identity or QA receipts changed since planning',layout)
    if require_lease and (layout.token not in _leases or _lease_profiles.get(b.mutex_name)!=layout.token):g._fail('resident_lease_required',layout.profile,'owned exclusive lease is not held',layout)

def plan(root,workspace,run_id,*,profile,custody,campaign_id,origin,expected_commit,expected_write_bytes,reserve_bytes,recovery_policy=""):
    base=g.plan_layout(root,workspace,run_id,expected_write_bytes,reserve_bytes)
    profile=g._path(profile);custody=g._path(custody)
    if not g._inside(base.root,profile) or not g._inside(base.root,custody):g._fail('root_escape',profile,'resident metadata/profile must stay under admitted root',base)
    binding=_snapshot(base.workspace,profile,custody,campaign_id,origin,expected_commit,recovery_policy=recovery_policy,run_id=run_id)
    layout=replace(base,profile=profile,resident_binding=binding)
    g.validate_layout(layout)
    return layout

def _mutex_acquire(name):
    g._require_windows()
    api=ctypes.WinDLL('kernel32',use_last_error=True)
    api.CreateMutexW.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_wchar_p];api.CreateMutexW.restype=ctypes.c_void_p
    api.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32];api.WaitForSingleObject.restype=ctypes.c_uint32
    api.ReleaseMutex.argtypes=[ctypes.c_void_p];api.CloseHandle.argtypes=[ctypes.c_void_p]
    handle=api.CreateMutexW(None,False,name)
    if not handle:raise OSError(ctypes.get_last_error(),'CreateMutexW failed')
    result=api.WaitForSingleObject(handle,0)
    if result!=0:
        if result==128:api.ReleaseMutex(handle)
        api.CloseHandle(handle)
        return None,'resident_lease_abandoned' if result==128 else 'resident_profile_busy'
    return (api,handle),None

def acquire_lease(layout):
    if layout.token in _leases:g._fail('resident_lease_duplicate',layout.profile,'lease already held',layout)
    validate_binding(layout)
    name=layout.resident_binding.mutex_name
    if name in _lease_profiles:g._fail('resident_profile_busy',layout.profile,'this process already holds the resident profile lease',layout)
    try:owned,error=_mutex_acquire(name)
    except OSError as e:g._fail('resident_lease_error',layout.profile,str(e),layout)
    if error:g._fail(error,layout.profile,'exclusive profile admission unavailable; no retry/fallback',layout)
    _leases[layout.token]=owned
    _lease_profiles[name]=layout.token
    try:validate_binding(layout,require_lease=True)
    except BaseException:
        release_lease(layout,active_owned_processes=0)
        raise

def release_lease(layout,*,active_owned_processes):
    if type(active_owned_processes) is not int or active_owned_processes!=0:
        g._fail('resident_processes_active',layout.profile,'release requires owned Job drained to zero',layout)
    b=layout.resident_binding
    if not isinstance(b,ResidentBinding) or _lease_profiles.get(b.mutex_name)!=layout.token:
        g._fail('resident_lease_owner_mismatch',layout.profile,'lease binding does not belong to this layout',layout)
    owned=_leases.get(layout.token)
    if owned is None:g._fail('resident_lease_required',layout.profile,'owned lease absent',layout)
    api,handle=owned
    if not api.ReleaseMutex(handle):raise OSError(ctypes.get_last_error(),'ReleaseMutex failed')
    api.CloseHandle(handle);del _leases[layout.token]
    del _lease_profiles[layout.resident_binding.mutex_name]
