"""Verdict-only existing Crew authority inspection; no restore or admission."""
import sys
sys.dont_write_bytecode=True
import hashlib,json
from pathlib import Path
import crew_cj2_failed_inspection as i

ROOT=i.ROOT;SOURCE=i.SOURCE
PUBLIC=ROOT/'runs/crew-failed-inspect1-261116/evidence/inspection.json'
PRESERVATION=ROOT/'runs/crew-failed-inspect1-261116/evidence/preservation.json'
PUBLIC_SHA='0bf97816fd4273f1cc62d83e19dea1b842a7063449581fb54595048acf5505ef'
PRESERVATION_SHA='85a289e8e2764248447446e7fe18e9c702c13857d3a311ae58f5c0900f791368'
KEY=i.n.ORIGIN_RUN_ROOT/'appdata/Godot/app_userdata/Beat the House/.crew_host_authority_v1'
PRIMARY=i.n.ORIGIN_RUN_ROOT/'save_dir/distribution/saves'/(i.n.SLOT+'.json')
BACKUP=Path(str(PRIMARY)+'.bak')
EXTRA_SOURCES=('tools/crew_cj2_private_inspection.py','tools/crew_cj2_private_inspect.gd','tools/tests/test_bth_qa_private_inspection.py')
PRIVATE_SCOPE='Existing explicit read-only key, current private capsule validation verdict and public receipt correlation only. No hidden payload, key, capsule or plaintext emitted; no restore/save/action/admission.'

def parse_args(argv=None):
 a=i.parse_args(argv)
 prefix='crew-failed-qual-private' if a.mode=='qualify' else 'crew-failed-inspect-private'
 if not a.run_id.startswith(prefix):raise ValueError('Private inspection case prefix required')
 if a.mode=='inspect' and not a.qualification.startswith('crew-failed-qual-private'):raise ValueError('Private qualification required')
 return a

def source_files(pin):
 files=i.validate_source(pin)
 files.update({name:i.sha(SOURCE/name) for name in EXTRA_SOURCES})
 return files

def validate_public(public,preservation):
 if not (public.get('ok') is True and all(public.get(k) is False for k in ('main_instantiated','run_state_instantiated','private_authority_validated','custody_recovery_authorized','gameplay_authorized')) and preservation.get('before')==preservation.get('after') and preservation.get('original_profile_bytes_unchanged') is True and preservation.get('original_evidence_unchanged') is True and preservation.get('gameplay_admitted') is False and preservation.get('custody_sha256')==i.CUSTODY_SHA):raise ValueError('Qualified original read-only evidence differs')
 for kind in ('primary','backup'):
  generation=public.get('generations',{}).get(kind,{})
  if not (generation.get('binding_ok') is True and generation.get('loadable_content') is True):raise ValueError('Current generation content proof missing')
  summary=generation.get('summary',{});delivery=summary.get('delivery',{})
  expected={'cash':151,'standing':87,'duties':2,'clock':1230,'action_index':12}
  counts=('commands','room_outcomes','room_acknowledgements','pending_outcomes','owner_results','registration_acknowledgements')
  owners=summary.get('owners')
  if not (all(type(summary.get(k)) is int and summary[k]==v for k,v in expected.items()) and summary.get('rng')=='950800549' and delivery.get('status')=='active' and delivery.get('cargo_status')=='carried' and delivery.get('closed_checkpoint_present') is False and isinstance(owners,list) and len(owners)==1 and all(isinstance(o,dict) and all(type(o.get(k)) is int and o[k]==0 for k in counts) for o in owners)):raise ValueError('Exact pre-handoff persisted-state proof differs')
 key_size=preservation.get('before',{}).get(str(KEY),{}).get('size')
 if type(key_size) is not int or key_size!=32:raise ValueError('Existing exact 32-byte authority key required; no installer')

def verdict_contract(result):
 keys={'schema','mode','ok','failures','generations','main_instantiated','run_state_instantiated','key_installer_called','original_handoff_replayed','gameplay_authorized','custody_recovery_authorized','private_cache_unchanged','scope'}
 if not (isinstance(result,dict) and set(result)==keys and result.get('schema')=='bth.qa_cj2_private_inspection/v1' and result.get('mode')=='inspect' and result.get('scope')==PRIVATE_SCOPE and result.get('ok') is True and result.get('failures')==[] and result.get('private_cache_unchanged') is True and all(result.get(name) is False for name in ('main_instantiated','run_state_instantiated','key_installer_called','original_handoff_replayed','custody_recovery_authorized','gameplay_authorized'))):raise ValueError('Private read-only result contract differs')
 verdicts=result.get('generations',{})
 if not isinstance(verdicts,dict) or set(verdicts)!={'primary','backup'}:raise ValueError('Both exact stored generations required')
 correlation_keys={'supported_public_receipt_shapes','closed_checkpoint_absent','commands_absent','outcomes_absent','acknowledgements_absent','pending_delivery_work_absent','matches_inspected_prehandoff_receipts','historical_observed_handoff_may_be_replayed','economic_authority_proven_by_private_capsule'}
 for verdict in verdicts.values():
  if not (isinstance(verdict,dict) and set(verdict)=={'exists','content_supported','supported','valid','error_code','public_correlation'} and all(type(verdict.get(k)) is bool for k in ('exists','content_supported','supported','valid')) and type(verdict.get('error_code')) is str and verdict.get('error_code') in ('','input_absent','content_unsupported','input_binding_failed','unsupported_private_shape','private_validation_failed')):raise ValueError('Verdict-only output required')
  if verdict['valid'] and not (verdict['exists'] and verdict['content_supported'] and verdict['supported'] and verdict['error_code']==''):raise ValueError('Inconsistent valid authority verdict')
  if not verdict['valid'] and verdict['error_code']=='':raise ValueError('Invalid authority requires a bounded error code')
  correlation=verdict['public_correlation']
  if not isinstance(correlation,dict):raise ValueError('Boolean receipt correlation required')
  if not correlation:
   if verdict['content_supported']:raise ValueError('Supported content requires receipt correlation')
  elif not (set(correlation)==correlation_keys and all(type(v) is bool for v in correlation.values()) and correlation['historical_observed_handoff_may_be_replayed'] is False and correlation['economic_authority_proven_by_private_capsule'] is False):raise ValueError('Unknown or unsafe receipt correlation')
 return all(v['supported'] and v['valid'] for v in verdicts.values())

def qualify(a,layout,files):
 jobs={}
 for kind,command in (
  ('guard',[sys.executable,'-B','-m','unittest','discover','-s',str(SOURCE/'tools/tests'),'-p','test_bth_qa_private_inspection.py','-v']),
  ('codec',[str(i.n.GODOT),'--headless','--path',str(SOURCE),'--script',str(SOURCE/'tools/crew_cj2_private_inspect.gd'),'--','--qualify','--output','OUTPUT'])):
  child=i.g.prepare_layout(i.g.plan_layout(ROOT,SOURCE,a.run_id+'-'+kind))
  command=[str(child.evidence/'inspection.json') if x=='OUTPUT' else x for x in command]
  if source_files(a.expected_commit)!=files:raise ValueError('Qualified private source changed')
  job=i.execute(child,command,timeout=120);i.closed(job)
  jobs[kind]={'run_id':child.run_id,'job_sha256':i.sha(child.evidence/'job.json'),'log_sha256':i.sha(child.evidence/'worker.log')}
  if kind=='codec':
   result=json.loads((child.evidence/'inspection.json').read_text())
   if not (result.get('ok') is True and result.get('qualified') is True and result.get('failures')==[] and result.get('mode')=='qualify'):raise ValueError('Private crypto qualification failed')
 if source_files(a.expected_commit)!=files:raise ValueError('Private source changed during qualification')
 receipt={'qualified':True,'purpose':'private_authority_verdict_only','source_files':files,'source_commit':a.expected_commit,'product_inputs_sha256':i.PRODUCT,'jobs':jobs,'profile_contents_read':False,'gameplay_admitted':False}
 i.write(layout.evidence/'qualification.json',receipt)
 return receipt

def inspect(a,layout,files):
 i.verify_qualification(a,files)
 q,_=i.n._owned_json(ROOT/'runs'/a.qualification/'evidence/qualification.json')
 if q.get('purpose')!='private_authority_verdict_only':raise ValueError('Separate private qualification required')
 for path,digest in ((PUBLIC,PUBLIC_SHA),(PRESERVATION,PRESERVATION_SHA),(i.SCOPE,i.SCOPE_SHA)):
  if i.sha(path)!=digest:raise ValueError('Bound public inspection evidence changed')
 public=json.loads(PUBLIC.read_text());preservation=json.loads(PRESERVATION.read_text());validate_public(public,preservation)
 scope=i.validate_scope(json.loads(i.SCOPE.read_text()))
 mutex='Local\\BTH-QA-Native-CJ2-'+hashlib.sha256(i.g._key(i.n.ORIGIN_RUN_ROOT).encode()).hexdigest()
 owned,error=i.n._mutex_acquire(mutex)
 if error:raise ValueError('Original campaign lease unavailable: '+error)
 job=None;attempted=False
 try:
  inventory=i.inventory(scope)
  if inventory!=preservation['directory_inventory']:raise ValueError('Original directory inventory changed since first read-only inspection')
  paths=sorted(set(inventory['files'])|set(scope['metadata_hashes'])|{str(i.SCOPE),str(PUBLIC),str(PRESERVATION)})
  with i.ReadLocks(paths) as locks:
   before=locks.snapshot()
   for path,previous in preservation['before'].items():
    if before.get(path)!=previous:raise ValueError('Original input changed since first read-only inspection')
   def recheck():
    if source_files(a.expected_commit)!=files or i.inventory(scope)!=inventory or locks.snapshot()!=before:raise ValueError('Private inspection input drift')
   recheck()
   command=[str(i.n.GODOT),'--headless','--path',str(SOURCE),'--script',str(SOURCE/'tools/crew_cj2_private_inspect.gd'),'--','--inspect','--primary',str(PRIMARY),'--primary-sha256',before[str(PRIMARY)]['sha256'],'--backup',str(BACKUP),'--backup-sha256',before[str(BACKUP)]['sha256'],'--key',str(KEY),'--key-sha256',before[str(KEY)]['sha256'],'--output',str(layout.evidence/'inspection.json')]
   sys.path.insert(0,str(Path(r'D:\Projects\site\scripts\bth_cpu_job')))
   from native_proof_worker import SuspendedWorker
   class Gated:
    def __init__(self,w):self.w=w
    def __getattr__(self,key):return getattr(self.w,key)
    def resume(self):recheck();return self.w.resume()
   def factory(job,cmd,**kwargs):
    nonlocal attempted
    recheck();attempted=True
    return Gated(SuspendedWorker(job,cmd,**kwargs))
   job=i.execute(layout,command,timeout=120,worker_factory=factory);i.closed(job);recheck()
   result=json.loads((layout.evidence/'inspection.json').read_text());valid=verdict_contract(result)
   i.write(layout.evidence/'preservation.json',{'before':before,'after':locks.snapshot(),'directory_inventory':inventory,'source_files':files,'custody_sha256':i.CUSTODY_SHA,'custody_status':'CASE_FAILED','private_verdicts_valid':valid,'gameplay_admitted':False,'profile_copied':False,'original_profile_bytes_unchanged':True,'original_evidence_unchanged':True})
 finally:
  if not i.closure_proven(job,attempted):raise RuntimeError('Private inspector child closure uncertain; mutex not released, no admission')
  api,handle=owned
  if not api.ReleaseMutex(handle):raise OSError('Inspection mutex release failed')
  api.CloseHandle(handle)
 return {'inspection_completed':True,'private_verdicts_valid':valid,'custody_status':'CASE_FAILED','gameplay_admitted':False,'evidence':str(layout.evidence/'inspection.json')}

def main():
 a=parse_args();layout=i.g.prepare_layout(i.g.plan_layout(ROOT,SOURCE,a.run_id));files=source_files(a.expected_commit)
 result=qualify(a,layout,files) if a.mode=='qualify' else inspect(a,layout,files)
 print(json.dumps(result))

if __name__=='__main__':main()
