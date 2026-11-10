"""Exact R17/1315 receipt-writer crash reconciliation; never replays Save5.

Job-zero is not graceful context closure. Only this frozen failure may admit one
new cold inspection. Default clean admission remains strict. Old receipts remain
failed, and a reviewed visible successor is required before ordinary play.
"""
from pathlib import Path
import hashlib,json
import bth_qa_storage as g

POLICY='r17-1315-receipt-crash-inspection'
ROOT=Path(r'E:\CodexQA\BTH\Broad\r10-20261104')
APPROVED_ROOT=Path(r'E:\CodexQA\BTH')
CAMPAIGN='broad-standard-r17';ORIGIN='http://127.0.0.1:8137'
COMMIT='f3058b6daab820e9d747c4c4aabc2d983e9ae32e'
FAILED='qa-batch-1315-r17b-stable-route';NEXT='qa-batch-1316-r17b-crash-cold-inspection'
PRIOR='qa-batch-1314-r17b-normal-onward'
OLD_LAUNCHER='fb4384ea5a82ab1c3ada7807ea5decec01f32b10f532079fb920e8194b12430a'
BROWSER='963c1c6634ddaa343b60bfd13e3bbfc531aef53f5e2440f4f81414d098fce2c6'
SEED='RUN-20261105-192080-002'
FINGERPRINTS={'custody': '49697b918d67912cdca18bc84efce1768eb7f5bd76db333a8df8ad73a4d61e90', 'manifest': 'ba55bace889ea249e1ab9403b8dd7d09266a93ad7d679df2028f9e6199822be7', 'prior_job': '0e91bf0ef807cae5362467ee106b204eafe4c94377cc0e6d6cad0507d07830c4', 'prior_state': '4705cb38ee6218a1abf1a3948779f64d22230b9be0290b24b90aa924534b9c7f', 'failed/adapter-exit.json': 'ac056c5386291b84f716d9f67b30764f73ae61e3a60f953b2144941cc46cd64b', 'failed/browser.log': '44d35555660db562b3bfd1a7c40985f0783c4f6bea315ddac51b0453c185cb62', 'failed/cold-paused.png': '5815362ad7df92ed8946cd79b1aea0f692a1355f307821be7803f9179ebc3a47', 'failed/done-1.json': '0c948eb56244705fe777ffe8c28773141a229cfc6866252bb3d38c324256f824', 'failed/done-2.json': '3f82b722dadee28d1af7e08fd8646d6750ba78e59fc24bf7b8bbba3e7cb86786', 'failed/done-3.json': '65c270141f1baf18a14f0eef270d5cdba4600c3259c8cc2ba7a69af85e8aba9e', 'failed/done-4.json': 'e91cb0e23b4ee4b3ea4bf1a1e6db9b366e5092346a0f5e6c632a9c01a1540093', 'failed/fresh1315-route-quote-metadata.png': '6b20cd938b23338ee7215e4f72b9c63aa4b834eb9c2e3d74b90112d92ce98808', 'failed/fresh1315-route-quote.png': '96c499f7b6a0556deea9f058d86aebc737e279a208eeb718d5b77fade7f90101', 'failed/job.json': '87f359f0d2f248d41c157fee8dda51e928d85753291f89c96c35b75d45a0678b', 'failed/job.json.0dd2c92b73039984210b6ce75a215d4d.pending': 'db8924c176dbef825c248811b7e6b33def9c329c92321bb09f59183226eee433', 'failed/leave-card.png': '62cea4074eed279730431f3e62b2a13fa67f35275fa103fd391d0e4ca0bde968', 'failed/ordinary_game.cjs': '963c1c6634ddaa343b60bfd13e3bbfc531aef53f5e2440f4f81414d098fce2c6', 'failed/queue-admission-1.json': 'ee02581bceda86c2526eff8a12a2e24d0451bd64f35d71e8d329132f85debd13', 'failed/queue-admission-2.json': '9ef85f55e05bc83ce83f87fa53616e22e311da824c4d58ef6bc6e988c15970fa', 'failed/queue-admission-3.json': '7dc2c6fa69ec39f7004caf134ecc0bfdb1c9cb2c5e7abc3b78ad29f9de4dd56e', 'failed/queue-admission-4.json': '1523b82d77040e9cd367f9a9ee0aac3ca00bb4ad54f8ac06c1e2c473b39039da', 'failed/queue-admission-5.json': 'df5c255c805b5382d126f4798d2ca612be2f530f771c372717b34e50f753b7cb', 'failed/reviewed1315-route-terms.png': '8b289360bf52f0c128b4317b87bb61ce25293207f66ec0d7154c60db4c15d99a', 'failed/route-map.png': '20eb3f9f70299847bf9281b1287d7707cc3732ae9a7eddb6a2b56fa12a395ddb', 'failed/server-ready.json': '47b3dfe4a49c98f8a3f578f49f87d2bcc01c8ebefc61d1e9d2c1b1e00a17ea31', 'failed/server.log': '374da7335ed671be640d1d5c350ea6d15717e12a8b64858421b41b5e9d91c72b', 'failed/settled1315-route-proof.png': '6a39971405a7074f5c0a58631829925d5589d369c64c4c2b66ceb9ca7847b1e3', 'failed/startup.png': '14350dc17b4d249981415afd9cd4d600cf19a9ca5b568dd1e7d44296ddd248ff', 'failed/state.json': '3dc7b4569cb9dd6c6f233599028325a3e6c9783e68a4cfac4468efb6ee4dc10a', 'queue/1': '1d7c32ce16cd1c6b0399b79de54c39ebdf892c3d4f045bd851b1fa0691dd70cc', 'queue/2': '607ed791e9ea55101ee3fb68dc7c352c9cc5dff3009a55eea8c44a0d91d67950', 'queue/3': '3160df1062bc6adca7699163063cfd91d49182076c81aa9350c38193547f304c', 'queue/4': '644235e6f4575e215d9f4fa281fe77f3550d9da4fe874947d86cbb48d5450d66', 'queue/5': 'ec3954b1a7ea3afd660c1e255677986a388e9223a72111757df418f96f1a0d93'}
FILE_NAMES=['adapter-exit.json', 'browser.log', 'cold-paused.png', 'commands', 'done-1.json', 'done-2.json', 'done-3.json', 'done-4.json', 'fresh1315-route-quote-metadata.png', 'fresh1315-route-quote.png', 'job.json', 'job.json.0dd2c92b73039984210b6ce75a215d4d.pending', 'leave-card.png', 'ordinary_game.cjs', 'queue-admission-1.json', 'queue-admission-2.json', 'queue-admission-3.json', 'queue-admission-4.json', 'queue-admission-5.json', 'reviewed1315-route-terms.png', 'route-map.png', 'server-ready.json', 'server.log', 'settled1315-route-proof.png', 'startup.png', 'state.json']
EXPECTED={'custody':FINGERPRINTS.get('custody')}

def require(ok,message):
    if not ok:g._fail('resident_crash_recovery_proof',ROOT/'evidence'/FAILED,message)

def same(left,right):
    return isinstance(left,(str,Path)) and g._key(left)==g._key(right)

def validate_scope(root,workspace,run_id,profile,custody,campaign,origin,commit,policy):
    require(policy==POLICY and run_id==NEXT,'Exact1316 inspection only')
    require(same(root,APPROVED_ROOT) and same(workspace,ROOT),'Exact root/workspace required')
    require(same(profile,ROOT/'qa-resident-profiles'/CAMPAIGN) and same(custody,ROOT/'evidence'/(CAMPAIGN+'-custody.json')),'Exact resident paths required')
    require((campaign,origin,commit)==(CAMPAIGN,ORIGIN,COMMIT),'Exact campaign/origin/build required')

def paths():
    out=ROOT/'evidence'/FAILED;prior=ROOT/'evidence'/PRIOR
    result={'custody':ROOT/'evidence'/(CAMPAIGN+'-custody.json'),
      'manifest':APPROVED_ROOT/'runs'/FAILED/'evidence/storage-manifest.json',
      'prior_job':prior/'job.json','prior_state':prior/'state.json'}
    for name in FILE_NAMES:
        if name!='commands':result['failed/'+name]=out/name
    for i in range(1,6):result['queue/'+str(i)]=out/'commands'/('%03d.json'%i)
    return result

def bounded_file(path,maximum=8*1024**2):
    g._inspect(path.parent)
    require(g._probe(path)==(True,False,False) and path.stat().st_size<=maximum,'Plain bounded QA artifact required: '+path.name)
    with path.open('rb') as stream:raw=stream.read(maximum+1)
    require(len(raw)<=maximum,'QA artifact exceeded bound')
    return raw

def verify_fingerprints(hashes):
    require(set(hashes)==set(FINGERPRINTS),'Frozen proof coverage differs')
    for name,digest in hashes.items():require(FINGERPRINTS[name]==digest,'Preserved QA artifact changed: '+name)

def frozen_artifacts(custody_archive=None):
    out=ROOT/'evidence'/FAILED;g._inspect(out);g._inspect(out/'commands')
    require(sorted(p.name for p in out.iterdir())==FILE_NAMES,'Failure artifact membership changed')
    require(sorted(p.name for p in (out/'commands').iterdir())==['%03d.json'%i for i in range(1,6)],'Queued commands differ')
    raws={};hashes={}
    sources=paths()
    if custody_archive is not None:
        require(same(custody_archive,ROOT/'evidence'/NEXT/'previous-custody.json'),'Only exact preserved predecessor permitted')
        sources['custody']=custody_archive
    for name,path in sources.items():
        raw=bounded_file(path);digest=hashlib.sha256(raw).hexdigest()
        require(FINGERPRINTS.get(name)==digest,'Preserved QA artifact changed: '+name)
        raws[name]=raw;hashes[name]=digest
    verify_fingerprints(hashes)
    return raws,hashes

def validate_facts(values):
    c,j,s,e,m=(values[k] for k in ('custody','job','state','exit','manifest'))
    require(c.get('status')=='RECONCILIATION_REQUIRED' and c.get('last_case')==FAILED and same(c.get('last_output'),ROOT/'evidence'/FAILED),'Original failed custody required')
    for value,state in ((c,False),(j,False),(s,True),(e,False),(values['prior_job'],False),(values['prior_state'],True)):
        require(value.get('profile_identity' if state else 'campaign_id')==CAMPAIGN and value.get('origin')==ORIGIN and
          same(value.get('profile_path'),ROOT/'qa-resident-profiles'/CAMPAIGN),'Receipt identity differs')
    for value in (j,s,e,values['prior_job'],values['prior_state']):require(value.get('tested_commit')==COMMIT,'Build receipt differs')
    require(c.get('mode')==j.get('mode')==s.get('profile_mode')==e.get('mode')=='resume','Resume-only proof required')
    require(s.get('persistent_profile') is True and s.get('game_dom',{}).get('url')==ORIGIN+'/index.html','Resident origin not proven')
    require(j.get('browser_exit') is None and j.get('active_at_release') is None and j.get('error') is None,'Stale job receipt was relabeled')
    require(s.get('ready') is True and s.get('closed') is False and s.get('context_close_completed') is None and
      s.get('completed') is None and s.get('inflight') is None and s.get('error') is None and s.get('page_errors')==0 and
      s.get('next_sequence')==5,'Original open/stale observation differs')
    require(type(e.get('active_at_release')) is int and e['active_at_release']==0 and e.get('resident_lease_released') is True and
      e.get('profile_worker_assigned') is True and e.get('custody_started') is True and e.get('browser_exit') is None,'Final capped Job zero not proven')
    require(str(e.get('error','')).startswith('[WinError 5] Access is denied:') and len(e.get('cleanup_errors',[]))==1 and
      e['cleanup_errors'][0].startswith('CLOSURE_RECEIPT_NOT_PERSISTED:'),'Exact writer fault required')
    limits=e.get('limits',{})
    require(limits.get('cpu_rate')==1200 and limits.get('job_memory_limit_bytes')==2*1024**3 and
      limits.get('kill_on_close') is True and limits.get('breakaway_allowed') is False,'Original Job safeguards differ')
    require(e.get('browser_source_sha256')==BROWSER and e.get('launcher_source_sha256')==OLD_LAUNCHER,'Original sources differ')
    commands=s.get('commands',[]);require(len(commands)==4,'Only four completed commands eligible')
    expected_dispatches=[]
    for i,command in enumerate(commands,1):
        require(command.get('sequence')==i and command.get('intent')=='play' and command.get('input_dispatch_completed') is True,
          'Paid or uncertain completed command exists')
        require(values['queue'+str(i)]=={k:command.get(k) for k in ('id','intent','actions')},'Queue/accepted input differ')
        done=values['done'+str(i)]
        require(done.get('completed') is True and done.get('input_dispatch_completed') is True and done.get('id')==command['id'],'Completion differs')
        expected_dispatches.extend((i,command['id'],n,action) for n,action in enumerate(command['actions']))
    dispatches=s.get('action_dispatches',[]);require(len(dispatches)==len(expected_dispatches),'Unknown input exists')
    for d,(sequence,command_id,index,action) in zip(dispatches,expected_dispatches):
        require((d.get('sequence'),d.get('id'),d.get('action_index'),d.get('action'))==(sequence,command_id,index,action) and
          d.get('dispatch_status')=='api_returned','Input dispatch uncertain/different')
    save=values['queue5']
    require(save.get('id')=='save-after-budget-refusal' and save.get('intent')=='checkpoint_close' and
      values['admission5'].get('sequence')==5 and values['admission5'].get('id')==save['id'],'Queued uncertain Save differs')
    require(not any(d.get('sequence')==5 for d in dispatches),'Do not reinterpret a Save dispatch')
    require(j.get('storage')==m and e.get('storage')==m and m.get('run_id')==FAILED and m.get('prepared') is True,'Frozen manifest differs')
    b=m.get('resident_profile_binding',{})
    require(b.get('last_case')==PRIOR and b.get('metadata_hashes',{}).get('job')==FINGERPRINTS['prior_job'] and
      b.get('metadata_hashes',{}).get('state')==FINGERPRINTS['prior_state'],'Earlier closed save chain differs')
    pj,ps=values['prior_job'],values['prior_state']
    require(pj.get('browser_exit')==0 and pj.get('active_at_release')==0 and not pj.get('error') and
      all(ps.get(k) is True for k in ('closed','completed','context_close_completed')) and ps.get('inflight') is None,'Prior closure not proven')
    return {'policy':POLICY,'old_context_graceful_close':'unproven','old_Save5':'uncertain_not_retried','paid_commands':0,'new_scope':'cold inspection only'}

def collect(workspace,profile,custody,campaign,origin,commit,run_id,common,common_hashes):
    from bth_qa_resident import _dir_identity
    validate_scope(APPROVED_ROOT,workspace,run_id,profile,custody,campaign,origin,commit,POLICY)
    raws,hashes=frozen_artifacts()
    for name,key in [('custody','custody'),('job','failed/job.json'),('state','failed/state.json')]:
        require(common_hashes[name]==hashes[key],'Common receipt race')
    def parsed(key):
        require(len(raws[key])<=2*1024**2,'QA JSON exceeds contract');return json.loads(raws[key])
    values=dict(custody=parsed('custody'),job=parsed('failed/job.json'),state=parsed('failed/state.json'),
      exit=parsed('failed/adapter-exit.json'),manifest=parsed('manifest'),prior_job=parsed('prior_job'),prior_state=parsed('prior_state'),
      admission5=parsed('failed/queue-admission-5.json'))
    for i in range(1,6):values['queue'+str(i)]=parsed('queue/'+str(i))
    for i in range(1,5):values['done'+str(i)]=parsed('failed/done-%d.json'%i)
    facts=validate_facts(values)
    require(list(_dir_identity(profile))==values['manifest']['resident_profile_binding']['profile_identity'],'Profile directory identity changed')
    return facts,hashes

def recovery_command():
    return {'id':'reconciled-cold-observe-close','intent':'checkpoint_close','actions':[
      {'type':'click','x':480,'y':405},{'type':'wait','milliseconds':1000},{'type':'click','x':875,'y':34},
      {'type':'wait','milliseconds':200},{'type':'screenshot','name':'recovery-cold-menu.png'},{'type':'close'}]}

def constrain_controller(source):
    from bth_qa_closed_inspection import constrain_controller as original
    result=original(source)
    require(result.count('r17-1307-closed-inspection')==1,'Original fixed-inspection seam differs')
    return result.replace('r17-1307-closed-inspection',POLICY)

def review_success(out,job,state):
    from bth_qa_resident import _owned_json
    require(same(out,ROOT/'evidence'/NEXT),'Exact crash-inspection successor required')
    review,rh=_owned_json(out/'recovery-observation-review.json');previous,ph=_owned_json(out/'previous-custody.json')
    require(ph==FINGERPRINTS['custody'] and job.get('preserved_custody_sha256')==ph and previous.get('last_case')==FAILED,'Failed custody not preserved')
    _,old_hashes=frozen_artifacts(out/'previous-custody.json')
    require(job.get('recovery_policy')==state.get('recovery_policy')==POLICY,'Matching crash policy flags required')
    command=state.get('commands',[])
    require(len(command)==1 and {k:command[0].get(k) for k in ('id','intent','actions')}==recovery_command(),'Cold inspection command differs')
    ds=state.get('action_dispatches',[]);require(len(ds)==6,'Cold dispatch count differs')
    start=state.get('controller_start_ms');end=state.get('deadline_ms')
    require(type(start) is int and type(end) is int and end-start==270000,'Cold time authority differs')
    for i,(d,action) in enumerate(zip(ds,recovery_command()['actions'])):
        require(d.get('sequence')==1 and d.get('id')==recovery_command()['id'] and d.get('action_index')==i and d.get('action')==action and
          d.get('dispatch_status')==('controller_close_requested' if i==5 else 'api_returned') and
          type(d.get('dispatch_started_at_ms')) is int and type(d.get('dispatch_completed_at_ms')) is int and
          start<=d['dispatch_started_at_ms']<=d['dispatch_completed_at_ms']<end,'Cold dispatch differs')
    observed={'seed':SEED,'location':'Back Alley/Wet Alley','cash':100,'heat':0,'day':1,'minute':780,'menu_visible':True}
    require(review.get('policy')==POLICY and review.get('case')==NEXT and review.get('approved_for_ordinary_successor') is True and
      review.get('observed')==observed and review.get('old_Save5')=='uncertain_not_retried','Explicit actual cold UI review required')
    for name in ('job','state'):
        _,digest=_owned_json(out/(name+'.json'));require(review.get(name+'_sha256')==digest,'Review final receipt changed')
    raw=bounded_file(out/'recovery-cold-menu.png');ih=hashlib.sha256(raw).hexdigest()
    require(review.get('screenshot_sha256')==ih,'Reviewed image changed')
    return dict({'predecessor/'+name:digest for name,digest in old_hashes.items()},
      recovery_review=rh,recovery_screenshot=ih,failed_custody_archive=ph)
