"""Atomic owned-QA receipts; bounded sharing handling, no permission changes.

Call only inside the launcher's admitted QA output/custody paths. Never applies
to profile contents or game files. Failed pending files remain diagnostic proof.
"""
from pathlib import Path
import ctypes,json,os,re,secrets,time

MAX_BYTES=2*1024**2

def delete_share_probe(path):
    """Non-mutating permission/share check on an existing QA receipt only."""
    from ctypes import wintypes
    api=ctypes.WinDLL('kernel32',use_last_error=True)
    api.CreateFileW.argtypes=[wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,ctypes.c_void_p,wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE]
    api.CreateFileW.restype=wintypes.HANDLE;api.CloseHandle.argtypes=[wintypes.HANDLE]
    directory=Path(path).is_dir()
    # File DELETE access is checked on both files. Parent ADD_FILE permits the
    # rename installation. DELETE_CHILD is an alternative, not required when
    # each file grants DELETE, so requesting it would falsely reject this case.
    access=0x2 if directory else 0x10000
    flags=0x02000000 if directory else 0x80
    handle=api.CreateFileW(str(path),access,0x1|0x2|0x4,None,3,flags,None)
    if handle in (None,ctypes.c_void_p(-1).value):return ctypes.get_last_error()
    if not api.CloseHandle(handle):raise OSError(ctypes.get_last_error(),'CloseHandle QA sharing probe failed')
    return 0

def atomic_json(path,value,token,*,timeout_seconds=.75,_replace=None,_probe=None,_sleep=None,_now=None):
    path=Path(path)
    if not re.fullmatch(r'[0-9a-f]{32}',token) or path.suffix!='.json' or not .05<=timeout_seconds<=1:
        raise ValueError('EXACT_QA_RECEIPT_TOKEN_PATH_AND_BOUND_REQUIRED')
    raw=(json.dumps(value,indent=2)+'\n').encode('utf-8')
    if len(raw)>MAX_BYTES:raise ValueError('QA_RECEIPT_EXCEEDS_2MIB')
    pending=path.with_name(path.name+'.'+token+'.'+secrets.token_hex(8)+'.pending')
    with pending.open('xb') as stream:
        stream.write(raw);stream.flush();os.fsync(stream.fileno())
    replace=_replace or os.replace;probe=_probe or delete_share_probe
    sleep=_sleep or time.sleep;now=_now or time.monotonic;deadline=now()+timeout_seconds
    attempts=0
    while True:
        attempts+=1
        try:replace(pending,path);return
        except OSError as error:
            error.qa_pending_path=str(pending)
            code=getattr(error,'winerror',None)
            if code not in (5,32,33) or attempts>=32 or now()>=deadline:raise
            if code==5:
                # WinError5 is ambiguous. Never retry a persistent access denial.
                # DELETE access is only checked; neither path is removed here.
                try:
                    if path.stat().st_file_attributes & 0x1:raise error
                except FileNotFoundError:raise error
                results=[probe(candidate) for candidate in (pending,path,path.parent)]
                if any(result not in (0,32,33) for result in results):raise
            if now()>=deadline:raise
            sleep(min(.025,max(0,deadline-now())))
            if now()>=deadline:raise
