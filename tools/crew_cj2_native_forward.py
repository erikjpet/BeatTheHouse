"""One qualified in-place native Continue for the exact fresh CJ2 QA campaign."""
import sys
sys.dont_write_bytecode=True
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(r'E:\CodexQA\BTH');SOURCE=ROOT/'workspaces/crew-ui-261116/source';REPO=Path(r'D:\Projects\Beat-The-House')
sys.path.insert(0,str(SOURCE/'tools'))
import bth_qa_storage as g
import bth_qa_native_forward as native
from bth_qa_guarded_run import execute
from bth_qa_atomic_receipt import atomic_json
QUALIFIED_SOURCES={'tools/bth_qa_storage.py','tools/bth_qa_native_forward.py','tools/bth_qa_resident.py','tools/bth_qa_guarded_run.py','tools/tests/test_bth_qa_native_forward.py','tools/crew_cj2_native_forward.py','tools/crew_cj2_native_forward.gd','tools/tests/test_bth_qa_native_ui_compat.py'}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def new_json(path,value):
 with path.open('xb') as stream:stream.write(native.receipt_bytes(value))
def assert_closed(job):
 assert type(job.get('exit_code')) is int and job['exit_code']==0,'Native worker failed; inspect its immutable campaign and Job receipts'
 assert type(job.get('active_at_release')) is int and job['active_at_release']==0
 assert job.get('timed_out') is False and job.get('assigned_before_execution') is True
 assert job.get('error') is None and job.get('cleanup_errors')==[]
def verify_qualification(run_id, filename):
 assert filename in ('qualification.json','syntax-qualification.json','control-qualification.json'),'Unknown qualification kind'
 prefix={'qualification.json':'crew-native-guards','syntax-qualification.json':'crew-native-syntax','control-qualification.json':'crew-native-controls'}[filename]
 assert native._case(run_id) and run_id.startswith(prefix),'Qualification must be an explicit own-campaign guard/syntax run'
 path=ROOT/'runs'/run_id/'evidence'/filename
 value,_=native._owned_json(path);assert value.get('qualified') is True,'Qualification did not pass'
 assert_closed(read(path.parent/'job.json'))
 assert value['worker_log_sha256']==digest(path.parent/'worker.log'),'Qualification log changed'
 return value,path
def qualified_sources(value):
 sources=value.get('source_files')
 assert isinstance(sources,dict) and set(sources)==QUALIFIED_SOURCES,'Qualification must cover the exact native guard/worker source set'
 assert all(native._hash_text(sha) for sha in sources.values()),'Qualification hashes must be full SHA256 values'
 return sources
class OwnedWorker:
 def __init__(self,worker,start_error):self.worker=worker;self.start_error=start_error
 def __getattr__(self,key):return getattr(self.worker,key)
 def resume(self):
  if self.start_error is not None:raise RuntimeError('Native custody was not installed before resume: '+str(self.start_error))
  return self.worker.resume()

def assigned_worker(worker,job,install_start):
 error=None
 try:
  assert job.contains(worker._handle) and worker.resumed is False,'Child must be assigned and still suspended before custody changes'
  install_start()
 except BaseException as exc:error=exc
 return OwnedWorker(worker,error)

def parse_args(argv=None):
 tokens=list(sys.argv[1:] if argv is None else argv)
 p=argparse.ArgumentParser(allow_abbrev=False);p.add_argument('--run-id',required=True);p.add_argument('--expected-commit',required=True);p.add_argument('--guards',required=True);p.add_argument('--syntax',required=True);p.add_argument('--controls',required=True);p.add_argument('--mode',choices=['inspect','wait','interact','respond','travel-back-alley','handoff-back-alley','wait-recipient'],default='inspect');p.add_argument('--object-id',default='');p.add_argument('--event-id',default='');p.add_argument('--choice-id',default='');p.add_argument('--wait-seconds',type=int,default=60);p.add_argument('--root-confirmed-no-duplicate-crew-job',action='store_true',required=True)
 flags=[token.split('=',1)[0] for token in tokens if token.startswith('--')]
 if len(flags)!=len(set(flags)):p.error('Duplicate flags are forbidden')
 a=p.parse_args(tokens)
 if not native._case(a.run_id) or len(a.run_id)>65:p.error('Exact bounded native case ID required')
 if len(a.expected_commit)!=40 or any(c not in '0123456789abcdef' for c in a.expected_commit):p.error('Full lowercase source commit required')
 if not 1<=a.wait_seconds<=90:p.error('Wait must be between1 and90 seconds')
 if a.mode in ('travel-back-alley','handoff-back-alley','wait-recipient') and any((a.object_id,a.event_id,a.choice_id)):p.error('Fixed route controls cannot be overridden')
 return a

def main():
 a=parse_args();PIN=a.expected_commit
 # Standard admission precedes every new adapter directory/write. It never
 # binds a profile or launches a child; persistent paths use only native mode.
 admission=g.prepare_layout(g.plan_layout(ROOT,SOURCE,a.run_id+'-admit'))
 qualified,qual_path=verify_qualification(a.guards,'qualification.json')
 for name,sha in qualified_sources(qualified).items():assert digest(SOURCE/name)==sha,'Qualified source changed: '+name
 syntax,syntax_path=verify_qualification(a.syntax,'syntax-qualification.json')
 controls,controls_path=verify_qualification(a.controls,'control-qualification.json')
 script=SOURCE/'tools/crew_cj2_native_forward.gd';script_sha=digest(script)
 assert script_sha==syntax['script_sha256']==controls['script_sha256'],'Native worker changed after syntax/control qualification'
 assert native._current_head()==PIN,'QA source pin changed'
 g.validate_layout(admission,extra_write_paths=[native.CUSTODY_PATH.parent])
 if not native.CUSTODY_PATH.exists():
  initial=native.bootstrap_custody(PIN)
  native.CUSTODY_PATH.parent.mkdir(parents=True,exist_ok=True)
  new_json(native.CUSTODY_PATH,initial)
 new_json(admission.evidence/'admission.json',{'source_commit':PIN,'qualification':str(qual_path),'syntax':str(syntax_path),'controls':str(controls_path),'script_sha256':script_sha,'campaign_id':native.CAMPAIGN_ID,'autosave_slot':native.SLOT,'native_custody':str(native.CUSTODY_PATH),'no_profile_copy':True,'root_runtime_check_no_duplicate_crew_job':True})
 layout=g.prepare_layout(g.plan_native_forward_layout(ROOT,SOURCE,a.run_id,expected_commit=PIN,custody=native.CUSTODY_PATH))
 binding=layout.native_binding;record=None;started=None;worker_created=False;successor=False;released=False;error=None;outcome={}
 try:
  g.validate_layout(layout,extra_write_paths=[layout.temp,layout.evidence,native.CUSTODY_PATH.parent])
  custody_bytes=native.CUSTODY_PATH.read_bytes();assert hashlib.sha256(custody_bytes).hexdigest()==dict(binding.metadata_hashes)[str(native.CUSTODY_PATH)]
  with (layout.evidence/'native-custody-before.json').open('xb') as stream:stream.write(custody_bytes)
  previous=read(Path(binding.last_output)/'campaign-result.json')
  assert digest(Path(binding.last_output)/'campaign-result.json')==binding.previous_campaign_sha256
  new_json(layout.evidence/'expected-public-state.json',previous['facts']['final'])
  target=layout.temp/'native_forward.gd'
  with target.open('xb') as stream:stream.write(script.read_bytes())
  engine_sha=digest(native.GODOT)
  new_json(layout.evidence/'native-inputs.json',{'source_commit':PIN,'original_fresh_source_commit':native.ORIGIN_COMMIT,'origin_product_digest':native.PRODUCT_DIGEST,'admitted_product_digest':binding.product_inputs_sha256,'qualification':str(qual_path),'qualified_guard_sources':qualified['source_files'],'syntax_qualification':str(syntax_path),'control_qualification':str(controls_path),'script_sha256':script_sha,'engine_sha256':engine_sha,'slot':native.SLOT,'mode':a.mode,'persistent_paths':dict(binding.persistent_paths),'directory_identities':binding.as_dict()['directory_identities'],'previous_case':binding.last_case,'previous_campaign_sha256':binding.previous_campaign_sha256,'profile_copy_performed':False,'original_evidence_modified':False,'persistence_note':'Normal forward autosaves may update this same QA campaign; no old-save bytes are copied, migrated or replayed.'})
  helpers=Path(r'D:\Projects\site\scripts\bth_cpu_job');sys.path.insert(0,str(helpers))
  from native_proof_worker import SuspendedWorker
  def factory(job,command,**kwargs):
   nonlocal started,worker_created
   worker=SuspendedWorker(job,command,**kwargs);worker_created=True
   def install_start():
    nonlocal started
    g.validate_layout(layout,extra_write_paths=[native.CUSTODY_PATH.parent])
    candidate=native.start_record(binding,layout.run_id,layout.evidence,script_sha)
    assert digest(native.CUSTODY_PATH)==hashlib.sha256(custody_bytes).hexdigest(),'Native custody changed before assignment'
    atomic_json(native.CUSTODY_PATH,candidate,layout.token)
    started=candidate
   return assigned_worker(worker,job,install_start)
  command=[str(native.GODOT),'--headless','--path',str(SOURCE),'--script',str(target),'--','--autosave-slot',native.SLOT,'--evidence-output',str(layout.evidence/'campaign-result.json'),'--expected-state-file',str(layout.evidence/'expected-public-state.json'),'--previous-case',binding.last_case,'--previous-campaign-sha256',binding.previous_campaign_sha256,'--mode',a.mode,'--max-wait-seconds',str(a.wait_seconds),'--object-id',a.object_id,'--event-id',a.event_id,'--choice-id',a.choice_id]
  record=execute(layout,command,timeout=180,cpu_rate=1200,extra_write_paths=[layout.temp,layout.evidence,native.CUSTODY_PATH.parent],worker_factory=factory)
  assert_closed(record)
  result=read(layout.evidence/'campaign-result.json')
  assert digest(target)==script_sha and digest(native.GODOT)==engine_sha,'Worker or engine changed during execution'
  for name,sha in qualified['source_files'].items():assert digest(SOURCE/name)==sha,'Qualified guard source changed during execution'
  closed=native.close_record(binding,started,record,result)
  new_json(layout.evidence/'state.json',closed['state'])
  assert read(native.CUSTODY_PATH)==started,'In-progress custody changed before native closure'
  atomic_json(native.CUSTODY_PATH,closed['custody'],layout.token);successor=True
  outcome={'run_id':a.run_id,'source_commit':PIN,'mode':a.mode,'checks':result['checks'],'failures':result['failures'],'previous_case':binding.last_case,'final_public_state':result['facts']['final'],'concurrent_board':result['facts'].get('concurrent_board'),'collection_actual_button':result['facts'].get('collection_actual_button'),'worker_log_sha256':digest(layout.evidence/'worker.log'),'profile_copy_performed':False,'persistent_paths_unchanged':True,'custody_status':'CLEAN_CLOSED','job':{k:record.get(k) for k in ('pid','exit_code','active_at_release','timed_out','error','cleanup_errors','assigned_before_execution')}}
 except BaseException as exc:
  error=str(exc)
  if started is not None and not successor and read(native.CUSTODY_PATH)==started:
   failed={**started,'status':'CASE_FAILED','failure':error,'job_receipt':str(layout.evidence/'job.json'),'native_result':str(layout.evidence/'campaign-result.json')}
   atomic_json(native.CUSTODY_PATH,failed,layout.token)
  outcome={'run_id':a.run_id,'error':error,'profile_copy_performed':False,'custody_status':read(native.CUSTODY_PATH).get('status'),'job':{k:record.get(k) for k in ('pid','exit_code','active_at_release','timed_out','error','cleanup_errors')} if record else None}
 finally:
  active=record.get('active_at_release') if record is not None else (0 if not worker_created else None)
  if type(active) is int and active==0:
   g.release_native_forward_layout(layout,active_owned_processes=active);released=True
  outcome['lease_released']=released
 if successor and released:
  admitted=g.plan_native_forward_layout(ROOT,SOURCE,a.run_id+'-readmit',expected_commit=PIN,custody=native.CUSTODY_PATH)
  assert admitted.native_binding.last_case==a.run_id
  outcome['successor_readmission_verified_without_launch']=True
 new_json(layout.evidence/'native-forward-result.json',outcome)
 print(json.dumps(outcome));return 0 if error is None and successor and released else 1
if __name__=='__main__':
 try:raise SystemExit(main())
 except g.StorageGuardError as exc:
  print(json.dumps({'status':'NATIVE_ADMISSION_STOPPED',**exc.as_dict()}),file=sys.stderr);raise SystemExit(2)
 except (OSError,ValueError,AssertionError) as exc:
  print(json.dumps({'status':'NATIVE_ADAPTER_STOPPED','error':str(exc)}),file=sys.stderr);raise SystemExit(1)
