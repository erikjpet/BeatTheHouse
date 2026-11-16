"""Named CJ2 failed-case read-only codec inspection. Never admits gameplay.

All writes use a new ordinary storage Layout. Original files are only read while
the existing native mutex and GENERIC_READ/non-write-sharing handles are held.
No Main, RunState restore, Save, key creation, custody writer or recovery mode.
"""
import sys
sys.dont_write_bytecode=True
import argparse,ctypes,hashlib,json,os,re,stat
from contextlib import ExitStack
from pathlib import Path
import bth_qa_storage as g
import bth_qa_native_forward as n
from bth_qa_guarded_run import execute

ROOT=n.ROOT;SOURCE=n.WORKSPACE
FAILED='crew-native-cj2-handoff-fixed1-261116'
PRODUCT='c9ada2a2cf6a42dd4fa6d6fc3cb15d59628582320f52fffcc6e55bd9053a299b'
SCOPE=ROOT/'runs/crew-failed-freeze1-261116/evidence/frozen-scope.json'
SCOPE_SHA='a19d87187c57aa0fcd9c88807eb19b6cd343657bc33ea06e660ebf361ad302fb'
CUSTODY_SHA='ec2e39f4134387538007b42467c1908ea5e462a57be87f1d32e48f3e41a1e00d'
SOURCES=('tools/crew_cj2_failed_inspection.py','tools/crew_cj2_failed_inspect.gd','tools/tests/test_bth_qa_failed_inspection.py','tools/bth_qa_storage.py','tools/bth_qa_native_forward.py','tools/bth_qa_resident.py','tools/bth_qa_guarded_run.py','tools/bth_qa_command_paths.py')
MAX_FILE=64*1024**2;MAX_TOTAL=256*1024**2;MAX_FILES=4096

def sha(path):
 with Path(path).open('rb') as f:return hash_stream(f,MAX_FILE)

def hash_stream(stream,limit):
 if type(limit) is not int or limit<0:raise ValueError('Nonnegative explicit read bound required')
 h=hashlib.sha256();total=0
 while True:
  block=stream.read(min(1024**2,limit-total+1))
  if not block:break
  total+=len(block)
  if total>limit:raise ValueError('Read bound exceeded')
  h.update(block)
 return h.hexdigest()

def parse_args(argv=None):
 args=list(sys.argv[1:] if argv is None else argv)
 p=argparse.ArgumentParser(allow_abbrev=False)
 p.add_argument('--run-id',required=True);p.add_argument('--expected-commit',required=True)
 p.add_argument('--mode',required=True,choices=('qualify','inspect'));p.add_argument('--qualification',default='')
 p.add_argument('--root-confirmed-no-owned-live-job',required=True,action='store_true')
 flags=[x.split('=',1)[0] for x in args if x.startswith('--')]
 if len(flags)!=len(set(flags)):p.error('Duplicate flags forbidden')
 a=p.parse_args(args)
 if not re.fullmatch(r'crew-failed-[a-z0-9][a-z0-9_-]{0,48}',a.run_id):p.error('Named bounded failed-inspection case required')
 if not re.fullmatch(r'[0-9a-f]{40}',a.expected_commit):p.error('Full exact source commit required')
 if not a.run_id.startswith('crew-failed-qual' if a.mode=='qualify' else 'crew-failed-inspect'):p.error('Case prefix must match fixed mode')
 if a.mode=='qualify' and a.qualification:p.error('Qualification cannot consume a previous qualification')
 if a.mode=='inspect' and not re.fullmatch(r'crew-failed-qual[a-z0-9_-]{1,45}',a.qualification):p.error('Explicit own qualification receipt required')
 return a

def validate_source(expected_commit):
 if n._current_head()!=expected_commit:raise ValueError('Exact source HEAD changed')
 if n._current_product_digest()!=PRODUCT:raise ValueError('Unqualified product inputs')
 result={name:sha(SOURCE/name) for name in SOURCES}
 with n.GODOT.open('rb') as stream:result['@engine']=hash_stream(stream,512*1024**2)
 return result

def validate_scope(scope):
 if not (scope.get('schema')=='bth.cj2_failed_inspection_scope/v1' and scope.get('case')==FAILED
  and scope.get('custody_sha256')==CUSTODY_SHA and scope.get('product_inputs_sha256')==PRODUCT
  and scope.get('profile_contents_read') is False and scope.get('archived_clean_predecessor_validated') is True
  and scope.get('original_failed_status_preserved') is True):raise ValueError('Frozen failed-case scope differs')
 if set(scope.get('directory_identities',{}))!=set(n.PERSISTENT_LEAVES):raise ValueError('Original directory identity set differs')
 if not isinstance(scope.get('metadata_hashes'),dict) or len(scope['metadata_hashes'])!=111:raise ValueError('Frozen receipt coverage differs')
 return scope

class ReadLocks:
 def __init__(self,paths):self.paths=tuple(Path(p) for p in paths);self.files={};self.stack=ExitStack()
 def __enter__(self):
  import msvcrt
  self.api=ctypes.WinDLL('kernel32',use_last_error=True)
  self.api.CreateFileW.argtypes=[ctypes.c_wchar_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p]
  self.api.CreateFileW.restype=ctypes.c_void_p
  self.api.CloseHandle.argtypes=[ctypes.c_void_p]
  try:
   for path in self.paths:
    g._inspect(path.parent)
    if g._probe(path)!=(True,False,False):raise ValueError('Plain existing input required')
    info=path.stat(follow_symlinks=False)
    if not stat.S_ISREG(info.st_mode) or info.st_nlink!=1 or info.st_size>MAX_FILE:raise ValueError('Input identity or size bound invalid')
    # No write/delete sharing and no reparse traversal. No ACL/attribute changes.
    handle=self.api.CreateFileW(str(path),0x80000000,1,None,3,0x00200000|0x08000000,None)
    if handle==ctypes.c_void_p(-1).value:raise OSError(ctypes.get_last_error(),'Read-only input lock unavailable')
    try:fd=msvcrt.open_osfhandle(int(handle),os.O_RDONLY|os.O_BINARY)
    except BaseException:self.api.CloseHandle(handle);raise
    try:stream=os.fdopen(fd,'rb')
    except BaseException:os.close(fd);raise
    stream=self.stack.enter_context(stream)
    opened=os.fstat(stream.fileno())
    if (opened.st_dev,opened.st_ino)!=(info.st_dev,info.st_ino):raise ValueError('Input replaced during read-only open')
    self.files[str(path)]=stream
   return self
  except BaseException:self.stack.close();raise
 def snapshot(self):
  result={};total=0
  for path,stream in self.files.items():
   g._inspect(Path(path).parent)
   info=os.fstat(stream.fileno());named=os.stat(path,follow_symlinks=False)
   if (info.st_dev,info.st_ino,info.st_size)!=(named.st_dev,named.st_ino,named.st_size):raise ValueError('Input pathname identity changed')
   total+=info.st_size
   if total>MAX_TOTAL:raise ValueError('Aggregate input bound exceeded')
   stream.seek(0)
   result[path]={'dev':info.st_dev,'ino':info.st_ino,'size':info.st_size,'sha256':hash_stream(stream,MAX_FILE)}
  return result
 def __exit__(self,*args):self.stack.close()

def inventory(scope):
 files=[];directories={};total=0
 for name in n.PERSISTENT_LEAVES:
  base=n.ORIGIN_RUN_ROOT/name
  if list(n._dir_identity(base))!=scope['directory_identities'][name]:raise ValueError('Original campaign directory identity changed')
  pending=[(base,0)]
  while pending:
   path,depth=pending.pop();g._inspect(path)
   if depth>16:raise ValueError('Profile directory depth exceeded')
   info=path.stat(follow_symlinks=False);directories[str(path)]=[info.st_dev,info.st_ino]
   if len(directories)>MAX_FILES:raise ValueError('Profile directory count exceeded')
   for child in sorted(path.iterdir()):
    exists,isdir,reparse=g._probe(child)
    if not exists or reparse:raise ValueError('Profile contains unsafe entry')
    if isdir:pending.append((child,depth+1))
    else:
     info=child.stat(follow_symlinks=False);total+=info.st_size
     if not stat.S_ISREG(info.st_mode) or info.st_nlink!=1 or info.st_size>MAX_FILE or total>MAX_TOTAL:raise ValueError('Profile file/aggregate bound exceeded')
     files.append(child)
     if len(files)>MAX_FILES:raise ValueError('Profile file count exceeded')
 return {'files':sorted(map(str,files)),'directories':directories}

def closed(job):
 limits=job.get('limits',{})
 if not (type(job.get('exit_code')) is int and job['exit_code']==0 and type(job.get('active_at_release')) is int and job['active_at_release']==0 and job.get('assigned_before_execution') is True and job.get('timed_out') is False and job.get('error') is None and job.get('cleanup_errors')==[] and job.get('log_truncated') is False and job.get('log_error') is None and limits.get('cpu_rate')==1200 and limits.get('job_memory_limit_bytes')==2*g.GIB and limits.get('kill_on_close') is True and limits.get('breakaway_allowed') is False and limits.get('active_processes')==0):raise ValueError('Successful exact capped Job closure required')

def write(path,value):
 with Path(path).open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')

def closure_proven(job,construction_attempted):
 return not construction_attempted or (isinstance(job,dict) and type(job.get('active_at_release')) is int and job['active_at_release']==0)

def qualify(a,layout,source_files):
 jobs={}
 for kind,command in (
  ('guard',[sys.executable,'-B','-m','unittest','discover','-s',str(SOURCE/'tools/tests'),'-p','test_bth_qa_failed_inspection.py','-v']),
  ('codec',[str(n.GODOT),'--headless','--path',str(SOURCE),'--script',str(SOURCE/'tools/crew_cj2_failed_inspect.gd'),'--','--qualify','--output','OUTPUT'])):
  child=g.prepare_layout(g.plan_layout(ROOT,SOURCE,a.run_id+'-'+kind))
  command=[str(child.evidence/'inspection.json') if x=='OUTPUT' else x for x in command]
  if validate_source(a.expected_commit)!=source_files:raise ValueError('Source changed before qualification')
  job=execute(child,command,timeout=120);closed(job)
  jobs[kind]={'run_id':child.run_id,'job_sha256':sha(child.evidence/'job.json'),'log_sha256':sha(child.evidence/'worker.log')}
  if kind=='codec':
   result=json.loads((child.evidence/'inspection.json').read_text())
   if result.get('failures')!=[] or not result.get('qualified') or result.get('mode')!='qualify':raise ValueError('Codec qualification failed')
 if validate_source(a.expected_commit)!=source_files:raise ValueError('Source changed during qualification')
 receipt={'qualified':True,'mode':'qualification','source_files':source_files,'source_commit':a.expected_commit,'product_inputs_sha256':PRODUCT,'jobs':jobs,'profile_contents_read':False,'gameplay_admitted':False}
 write(layout.evidence/'qualification.json',receipt)
 return receipt

def verify_qualification(a,source_files):
 path=ROOT/'runs'/a.qualification/'evidence/qualification.json'
 value,_=n._owned_json(path)
 if not (value.get('qualified') is True and value.get('source_files')==source_files and value.get('product_inputs_sha256')==PRODUCT and value.get('profile_contents_read') is False and value.get('gameplay_admitted') is False):raise ValueError('Exact read-only qualification differs')
 for kind,row in value['jobs'].items():
  if kind not in ('guard','codec') or row['run_id']!=a.qualification+'-'+kind:raise ValueError('Qualification Job scope differs')
  ev=ROOT/'runs'/row['run_id']/'evidence';closed(json.loads((ev/'job.json').read_text()))
  if sha(ev/'job.json')!=row['job_sha256'] or sha(ev/'worker.log')!=row['log_sha256']:raise ValueError('Qualification evidence changed')
 if set(value['jobs'])!={'guard','codec'}:raise ValueError('Qualification coverage differs')

def inspect(a,layout,source_files):
 verify_qualification(a,source_files)
 if sha(SCOPE)!=SCOPE_SHA:raise ValueError('Frozen inspection scope changed')
 scope=validate_scope(json.loads(SCOPE.read_text()))
 mutex='Local\\BTH-QA-Native-CJ2-'+hashlib.sha256(g._key(n.ORIGIN_RUN_ROOT).encode()).hexdigest()
 owned,error=n._mutex_acquire(mutex)
 if error:raise ValueError('Original campaign mutex unavailable: '+error)
 job=None;construction_attempted=False
 try:
  for path,digest in scope['metadata_hashes'].items():
   if n._file_hash(Path(path))!=digest:raise ValueError('Frozen original QA evidence changed')
  before_inventory=inventory(scope)
  paths=sorted(set(before_inventory['files'])|set(scope['metadata_hashes'])|{str(SCOPE)})
  with ReadLocks(paths) as locks:
   before=locks.snapshot()
   def recheck():
    if validate_source(a.expected_commit)!=source_files or inventory(scope)!=before_inventory or locks.snapshot()!=before:raise ValueError('Original/source input drift; inspection stopped')
   recheck()
   primary=n.ORIGIN_RUN_ROOT/'save_dir/distribution/saves'/(n.SLOT+'.json');backup=Path(str(primary)+'.bak')
   command=[str(n.GODOT),'--headless','--path',str(SOURCE),'--script',str(SOURCE/'tools/crew_cj2_failed_inspect.gd'),'--','--inspect','--primary',str(primary),'--primary-sha256',before.get(str(primary),{}).get('sha256','ABSENT'),'--backup',str(backup),'--backup-sha256',before.get(str(backup),{}).get('sha256','ABSENT'),'--output',str(layout.evidence/'inspection.json')]
   class GatedWorker:
    def __init__(self,worker):self.worker=worker
    def __getattr__(self,key):return getattr(self.worker,key)
    def resume(self):recheck();return self.worker.resume()
   def factory(owned_job,cmd,**kwargs):
    nonlocal construction_attempted
    recheck()
    construction_attempted=True
    return GatedWorker(SuspendedWorker(owned_job,cmd,**kwargs))
   # Import maintained helper only after fresh storage admission, as execute does.
   sys.path.insert(0,str(Path(r'D:\Projects\site\scripts\bth_cpu_job')))
   from native_proof_worker import SuspendedWorker
   job=execute(layout,command,timeout=120,worker_factory=factory);closed(job);recheck()
   result=json.loads((layout.evidence/'inspection.json').read_text())
   if not (result.get('mode')=='inspect' and result.get('ok') is True and result.get('failures')==[] and all(result.get(key) is False for key in ('main_instantiated','run_state_instantiated','private_authority_validated','custody_recovery_authorized','gameplay_authorized'))):raise ValueError('Read-only codec inspection failed')
   write(layout.evidence/'preservation.json',{'before':before,'after':locks.snapshot(),'directory_inventory':before_inventory,'source_files':source_files,'product_inputs_sha256':PRODUCT,'custody_status':'CASE_FAILED','custody_sha256':CUSTODY_SHA,'original_evidence_unchanged':True,'original_profile_bytes_unchanged':True,'gameplay_admitted':False,'profile_copied':False})
 finally:
  # execute drains its Job before returning/raising; a missing/uncertain closure
  # is never treated as qualified or admitted for gameplay.
  api,handle=owned
  if not closure_proven(job,construction_attempted):raise RuntimeError('Owned child closure unproven; mutex is not released and no inspection/gameplay admission exists')
  if not api.ReleaseMutex(handle):raise OSError('Failed to release inspection mutex')
  api.CloseHandle(handle)
 return {'inspection_completed':True,'custody_status':'CASE_FAILED','gameplay_admitted':False,'evidence':str(layout.evidence/'inspection.json')}

def main():
 a=parse_args();layout=g.prepare_layout(g.plan_layout(ROOT,SOURCE,a.run_id))
 source_files=validate_source(a.expected_commit)
 result=qualify(a,layout,source_files) if a.mode=='qualify' else inspect(a,layout,source_files)
 print(json.dumps(result))

if __name__=='__main__':main()
