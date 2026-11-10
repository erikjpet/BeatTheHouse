"""Exact1350 cold recovery. QA metadata only; never replays or relabels the trip."""
from pathlib import Path
import hashlib,json
import bth_qa_storage as g

POLICY='r17-1350-paid-trip-cold-inspection'
ROOT=Path(r'E:\CodexQA\BTH\Broad\r10-20261104')
APPROVED_ROOT=Path(r'E:\CodexQA\BTH')
CAMPAIGN='broad-standard-r17'; ORIGIN='http://127.0.0.1:8137'
COMMIT='ac877121d68561c818f39fe3c81b892e8a13b932'
FAILED='qa-batch-1350-r17b-motel-route'
NEXT='qa-batch-1351-r17b-motel-cold-inspection'
PRIOR='qa-batch-1349-r17b-caller-interaction'
BROWSER='1f8d60f60fd4791e5ef2d9e2a04961734d48475e18f2ae4d30cb5b5da3303a89'
OLD_LAUNCHER='4d29591a75ca3d44709ec1e9d0eef68e9ef3ba9b95d324525b0db76d804fadc1'
EXPECTED={'custody': 'f925813b6a4c622b4b1a659f663c2f33693dfd9512b3cae9eb4f299cdb0e6109', 'job': '58a875a110b39f41b2ff3f95d4c6d91f900c4e5ecc71e978a2dc549a7853c876', 'state': '513aa99ef756df2dde7bc2ab334fd144497f5c3850001789b8678a320e79396e', 'exit': '8f284070fc8a9cf77edf08c2bef81f473c73e4255d131945dfa1ec47048e9d3c', 'manifest': 'c4e92b6565dedc29ac21c235efd00988871dc2dec7190ecfdf9120126b3f3d45', 'prior_job': 'dfe809f1f2866df91eb681036f2218b5a34d14a7fc3d787a14e34fd28afc6c72', 'prior_state': '6130350686869ed8e007fcdd02c220187ecb8909971de986afeed8829fd5f5fe', 'attempt': '6b03fc6bfe3c2a92b367b33507601ae06f418698431834f9a8b1f12849d198cb', 'queue1': '1ba0355c7e98aae25c18480e0f543dba03a7fb98760120b56b4125f8b654ff2c', 'done1': 'df032cec325662c524586e01b16812b12e30bc3019a4e4f286d5c2682dc174d5', 'admission1': 'b4002ee0cae73de477eab5a51ba697a50c5ee705dbdea414dad1e267c168473f', 'queue2': '1400297e0d1af1e783d11ab32ecb0ce29fbacf68e9fb1ae570b0dcb835d6e4b1', 'done2': 'b23a36bca066999539aa330b066bec7f4114345da7372fe308f5c433eb533e24', 'admission2': '42d9de87db4d6afd8736d2e7775473cb816f0bc1beed619e80e09069e26d240f', 'queue3': '1efaad4d5d7ee8571a7dd4456fc05f21778e8a1314fff665a69cbadb705c9e70', 'done3': '40bf6a96c32c0bca6b0aaf2d19087da649d56827b6987742d0df0525d3e13fac', 'admission3': '2d60c95001cbbb9a67917b42ef06f94eb61a08cab839660b45434c758405f557'}

def require(ok,message):
    if not ok:g._fail('resident_paid_trip_recovery_proof',ROOT/'evidence'/FAILED,message)

def same(a,b):return isinstance(a,(str,Path)) and g._key(a)==g._key(b)

def validate_scope(root,workspace,run_id,profile,custody,campaign,origin,commit,policy):
    require(policy==POLICY and run_id==NEXT,'Exact named successor required')
    require(same(root,APPROVED_ROOT) and same(workspace,ROOT),'Exact root/workspace required')
    require(same(profile,ROOT/'qa-resident-profiles'/CAMPAIGN),'Original profile required')
    require(same(custody,ROOT/'evidence'/(CAMPAIGN+'-custody.json')),'Exact custody required')
    require((campaign,origin,commit)==(CAMPAIGN,ORIGIN,COMMIT),'Exact campaign/origin/build required')

def verify_fingerprints(actual):
    require(set(actual)==set(EXPECTED),'Exact frozen artifact set required')
    for name,pin in EXPECTED.items():require(actual[name]==pin,'Frozen '+name+' changed')

def files(custody=None):
    out=ROOT/'evidence'/FAILED; prior=ROOT/'evidence'/PRIOR
    result={'custody':custody or ROOT/'evidence'/(CAMPAIGN+'-custody.json'),
        'job':out/'job.json','state':out/'state.json','exit':out/'adapter-exit.json',
        'manifest':APPROVED_ROOT/'runs'/FAILED/'evidence/storage-manifest.json',
        'prior_job':prior/'job.json','prior_state':prior/'state.json','attempt':out/'one-ordinary-trip-attempt.json'}
    for i in range(1,4):
        result.update({f'queue{i}':out/'commands'/f'{i:03}.json',f'done{i}':out/f'done-{i}.json',f'admission{i}':out/f'queue-admission-{i}.json'})
    return result

def frozen(custody=None):
    from bth_qa_resident import _owned_json
    values={};hashes={}
    for name,path in files(custody).items():values[name],hashes[name]=_owned_json(path)
    verify_fingerprints(hashes)
    out=ROOT/'evidence'/FAILED
    values['queue_names']=sorted(p.name for p in (out/'commands').iterdir())
    values['done_names']=sorted(p.name for p in out.glob('done-*.json'))
    return values,hashes

def identity(value,state=False):
    return value.get('profile_identity' if state else 'campaign_id')==CAMPAIGN and value.get('origin')==ORIGIN and value.get('tested_commit')==COMMIT and same(value.get('profile_path'),ROOT/'qa-resident-profiles'/CAMPAIGN)

def validate_facts(v):
    c,j,s,e,m=(v[k] for k in ('custody','job','state','exit','manifest'))
    require(c.get('status')=='RECONCILIATION_REQUIRED' and c.get('last_case')==FAILED and same(c.get('last_output'),ROOT/'evidence'/FAILED),'Failed custody history required')
    require(c.get('campaign_id')==CAMPAIGN and c.get('origin')==ORIGIN and same(c.get('profile_path'),ROOT/'qa-resident-profiles'/CAMPAIGN),'Custody identity differs')
    for d,isstate in [(j,False),(s,True),(e,False),(v['prior_job'],False),(v['prior_state'],True)]:require(identity(d,isstate),'Receipt identity differs')
    require(c.get('mode')==j.get('mode')==s.get('profile_mode')==e.get('mode')=='resume','Resume only')
    for end in (j,e):
        require(type(end.get('browser_exit')) is int and end['browser_exit']==1 and type(end.get('active_at_release')) is int and end['active_at_release']==0,'Owned closed Job required')
        require(end.get('error') is None and end.get('cleanup_errors')==[] and end.get('timed_out') is False,'Unexpected wrapper failure')
    require(e.get('resident_lease_released') is True and e.get('profile_worker_assigned') is True and e.get('custody_started') is True,'Lease/assignment closure required')
    require(all(s.get(k) is True for k in ('ready','closed','context_close_completed','deadline_hit','persistent_profile')) and s.get('completed') is False and s.get('inflight') is None and s.get('error')=='270_SECOND_BOUND','Exact completed-context deadline required')
    require(type(s.get('page_errors')) is int and s['page_errors']==0 and s.get('next_sequence')==4 and s.get('secondary_events')==[] and s.get('game_dom',{}).get('url')==ORIGIN+'/index.html','Unexpected input/error/origin')
    start=s.get('controller_start_ms'); end=s.get('deadline_ms'); trigger=s.get('exit_trigger',{})
    require(type(start) is int and type(end) is int and end-start==270000 and s.get('work_deadline_ms')==start+180000,'Exact deadlines required')
    require(trigger.get('reason')=='270_SECOND_BOUND' and type(trigger.get('at_ms')) is int and end<=trigger['at_ms']<=end+10000,'Bound trigger differs')
    commands=s.get('commands',[])
    require([(x.get('sequence'),x.get('id'),x.get('intent')) for x in commands]==[(1,'cold-and-inspect-motel-quote','play'),(2,'refresh-ordinary-route-terms','play'),(3,'one-ordinary-visible-trip','paid')],'Exact three completed commands required')
    expected_dispatches=[]
    for i,cmd in enumerate(commands,1):
        require(cmd.get('input_dispatch_completed') is True and v[f'queue{i}']=={k:cmd.get(k) for k in ('id','intent','actions')},'Queue/command mismatch')
        d=v[f'done{i}'];a=v[f'admission{i}']
        require(d.get('completed') is True and d.get('input_dispatch_completed') is True and d.get('id')==cmd['id'],'Completion uncertain')
        require(a.get('sequence')==i and a.get('id')==cmd['id'] and a.get('budget',{}).get('ok') is True and a['budget'].get('intent')==cmd['intent'],'Admission differs')
        expected_dispatches.extend((i,cmd['id'],n,action) for n,action in enumerate(cmd['actions']))
    ds=s.get('action_dispatches',[]);require(len(ds)==len(expected_dispatches),'Extra/uncertain dispatch')
    for d,(seq,ci,n,action) in zip(ds,expected_dispatches):
        require((d.get('sequence'),d.get('id'),d.get('action_index'),d.get('action'))==(seq,ci,n,action) and d.get('dispatch_status')=='api_returned','Dispatch changed')
        require(type(d.get('dispatch_started_at_ms')) is int and type(d.get('dispatch_completed_at_ms')) is int and start<=d['dispatch_started_at_ms']<=d['dispatch_completed_at_ms']<end,'Dispatch timing uncertain')
    require(v['queue_names']==['001.json','002.json','003.json'] and v['done_names']==['done-1.json','done-2.json','done-3.json'],'Extra queued/completed command')
    require(commands[2]['actions']==[{'type':'click','x':729,'y':310},{'type':'wait','milliseconds':1000},{'type':'screenshot','name':'ordinary-route-arrival.png'}],'Accepted trip control differs')
    proof=v['admission3'].get('reviewed_quote_context',{})
    require(proof.get('operator_quoted_price')==4 and proof.get('maximum_cash_cost')==4 and proof.get('comparison',{}).get('match') is True and proof.get('no_auto') is True,'Accepted trip quote differs')
    require(v['attempt'].get('sequence')==3 and v['attempt'].get('no_retry') is True and v['attempt'].get('point')==[729,310],'Once-only trip reservation differs')
    require(j.get('browser_source_sha256')==BROWSER and j.get('launcher_source_sha256')==OLD_LAUNCHER,'Original sources differ')
    lim=j.get('limits',{});require(lim.get('cpu_rate')==1200 and lim.get('job_memory_limit_bytes')==2*1024**3 and lim.get('kill_on_close') is True and lim.get('breakaway_allowed') is False and j.get('timeout_seconds')==300,'Original caps differ')
    require(j.get('storage')==e.get('storage')==m and m.get('run_id')==FAILED and m.get('prepared') is True and j.get('storage_manifest_sha256')==EXPECTED['manifest'],'Storage manifest differs')
    binding=m.get('resident_profile_binding',{})
    require(binding.get('last_case')==PRIOR and binding.get('metadata_hashes',{}).get('job')==EXPECTED['prior_job'] and binding.get('metadata_hashes',{}).get('state')==EXPECTED['prior_state'],'Prior chain differs')
    pj,ps=v['prior_job'],v['prior_state']
    require(pj.get('browser_exit')==0 and pj.get('active_at_release')==0 and pj.get('error') is None and all(ps.get(k) is True for k in ('closed','completed','context_close_completed')) and ps.get('inflight') is None,'Prior normal Save closure differs')
    require(ps.get('commands',[])[-1].get('id')=='save-night-route-checkpoint' and ps['commands'][-1].get('input_dispatch_completed') is True,'Earlier Save receipt differs')
    return {'policy':POLICY,'failed_case_completed':False,'accepted_trip_commands':1,'replay_authorized':False,'scope':'cold UI observation only'}

def collect(workspace,profile,custody,campaign,origin,commit,run_id,common,common_hashes):
    from bth_qa_resident import _dir_identity
    validate_scope(APPROVED_ROOT,workspace,run_id,profile,custody,campaign,origin,commit,POLICY)
    values,hashes=frozen()
    for key in ('custody','job','state'):require(common_hashes.get(key)==hashes[key] and common[key]==values[key],'Receipt race')
    result=validate_facts(values)
    require(list(_dir_identity(profile))==values['manifest']['resident_profile_binding']['profile_identity'],'Original directory identity changed')
    return result,hashes

def recovery_command():
    return {'id':'reconciled-cold-observe-close','intent':'checkpoint_close','actions':[
        {'type':'click','x':480,'y':405},{'type':'wait','milliseconds':1000},
        {'type':'screenshot','name':'recovery-cold-visible.png'},
        {'type':'click','x':875,'y':34},{'type':'wait','milliseconds':200},
        {'type':'screenshot','name':'recovery-cold-menu.png'},{'type':'close'}]}

def constrain_controller(source):
    marker='function validate(c){';require(source.count(marker)==1 and source.count('const state={')==1,'Exact original controller seams required')
    require(hashlib.sha256(source.encode()).hexdigest()==BROWSER,'Pinned original controller required')
    check='\n const recoveryExpected='+json.dumps(recovery_command(),separators=(',',':'))+';\n'
    check+=" if(state.next_sequence!==1||Date.now()-controllerStarted>90000||JSON.stringify(fs.readdirSync(path.join(ROOT,'commands')).sort())!==JSON.stringify(['001.json']))throw Error('RECOVERY_SINGLE_EARLY_COMMAND_ONLY');\n"
    check+=" if(!c||c.id!==recoveryExpected.id||c.intent!==recoveryExpected.intent||JSON.stringify(c.actions)!==JSON.stringify(recoveryExpected.actions))throw Error('RECOVERY_EXACT_COLD_CLOSE_ONLY');\n"
    return source.replace(marker,marker+check,1).replace('const state={','const state={recovery_policy:'+json.dumps(POLICY)+',',1)

def review_success(out,job,state):
    from bth_qa_resident import _owned_json
    require(same(out,ROOT/'evidence'/NEXT),'Exact recovery output required')
    review,rh=_owned_json(out/'recovery-observation-review.json')
    previous,ph=_owned_json(out/'previous-custody.json')
    require(ph==EXPECTED['custody'] and job.get('preserved_custody_sha256')==ph,'Failed custody archive changed')
    old,hashes=frozen(out/'previous-custody.json');validate_facts(old)
    require(job.get('recovery_policy')==state.get('recovery_policy')==POLICY,'Recovery provenance differs')
    cmd=state.get('commands',[]);require(len(cmd)==1 and cmd[0].get('input_dispatch_completed') is True and {k:cmd[0].get(k) for k in ('id','intent','actions')}==recovery_command(),'Recovery command differs')
    actions=recovery_command()['actions'];ds=state.get('action_dispatches',[])
    start=state.get('controller_start_ms');end=state.get('deadline_ms')
    require(len(ds)==len(actions) and type(start) is int and type(end) is int and end-start==270000,'Recovery count/clock differs')
    for i,(d,a) in enumerate(zip(ds,actions)):
        require(d.get('sequence')==1 and d.get('id')==recovery_command()['id'] and d.get('action_index')==i and d.get('action')==a and d.get('dispatch_status')==('controller_close_requested' if i==len(actions)-1 else 'api_returned'),'Recovery input differs')
        require(type(d.get('dispatch_started_at_ms')) is int and type(d.get('dispatch_completed_at_ms')) is int and start<=d['dispatch_started_at_ms']<=d['dispatch_completed_at_ms']<end,'Recovery input timing uncertain')
    require(review.get('policy')==POLICY and review.get('case')==NEXT and review.get('approved_for_ordinary_successor') is True and review.get('profile_contents_read') is False,'Explicit observation review required')
    require(review.get('observed')=={'location':'Sunset Motel','cash':74,'heat':0,'day':3,'minute':240,'menu_visible':True},'Actual post-trip cold state must match; old save must not replay')
    for n in ('job','state'):
        _,digest=_owned_json(out/(n+'.json'));require(review.get(n+'_sha256')==digest,'Reviewed final '+n+' changed')
    for name in ('recovery-cold-visible.png','recovery-cold-menu.png'):
        p=out/name;g._inspect(p.parent)
        require(g._probe(p)==(True,False,False) and p.stat().st_size<=8*1024**2,'Bounded actual screenshot required')
        with p.open('rb') as stream:raw=stream.read(8*1024**2+1)
        require(len(raw)<=8*1024**2 and review.get('screenshots',{}).get(name)==hashlib.sha256(raw).hexdigest(),'Reviewed screenshot changed')
    return dict({'predecessor/'+k:v for k,v in hashes.items()},recovery_review=rh,failed_custody_archive=ph)
