"""Exact R17/1307 bounded-inspection recovery; no game/save/profile content reads.

This policy never marks the failed case successful. Normal resident admission
continues to require CLEAN_CLOSED. Only one named cold-observation successor is
eligible, using the preserved immutable evidence below.
"""
from pathlib import Path
import hashlib
import bth_qa_storage as g

POLICY = 'r17-1307-closed-inspection'
ROOT = Path(r'E:\CodexQA\BTH\Broad\r10-20261104')
APPROVED_ROOT = Path(r'E:\CodexQA\BTH')
CAMPAIGN = 'broad-standard-r17'
ORIGIN = 'http://127.0.0.1:8137'
COMMIT = 'f3058b6daab820e9d747c4c4aabc2d983e9ae32e'
FAILED = 'qa-batch-1307-r17-riverboat-return'
NEXT = 'qa-batch-1308-r17-closed-bound-cold'
PRIOR = 'qa-batch-1279-r17-public-journal-check'
BROWSER_SHA = '963c1c6634ddaa343b60bfd13e3bbfc531aef53f5e2440f4f81414d098fce2c6'
FAILED_LAUNCHER_SHA = '10cef212109b17be2719136e44e5f8311f955cad1bac8efd1f7e701c5e7f4f69'
EXPECTED = {
 'custody':'b80f53056eea36d196bbcab099191af05465b6d990e63cea1134541fa03057d2',
 'job':'0e8a186b33f0693a24599f5d44338aa725f3f508d57eb74a2d36a2ccfc8c7721',
 'state':'6e20186f621d9adb243a6b44fe42da4cb42f1d4fd752945c9b4859ea969bc92e',
 'exit':'ce8eddc1123605932103f2971e739bb8cea0b26c0f359ea8100f36bd0c9aed61',
 'queue':'159507ada774792bb474ecb8628004a850bab4693ec857e14c10b54be33baa74',
 'done':'67e75579fe222244f1281a5a37d1a1c6ca249311a8d6407aed15b640cd98a02a',
 'manifest':'50e2f427a07cfac6e31228c99ffa3f278fe67cd1dd11ebd47eafda8e626d7f7a',
 'prior_job':'a3bdaa88692f5ac712c43afcab810e89ccdf2bf50c707f7f6587bbf4128bde19',
 'prior_state':'5956d4d633d05a7284adfdf0f1d53e6cf273b430e043212b3671dc1b8a51e072',
 'admission':'e02b3bbf7a0512c3d836f9ab0bee7494df0aa9753d2cf00ad6ab340f10df4b82',
}
EXPECTED_FILES = sorted(('commands','adapter-exit.json','browser.log','cold-paused.png',
 'done-1.json','job.json','ordinary_game.cjs','queue-admission-1.json','server-ready.json',
 'server.log','startup.png','state.json'))
OLD_COMMAND = {'id':'cold-continue-menu','intent':'play','actions':[
 {'type':'click','x':480,'y':405},{'type':'wait','milliseconds':1000},
 {'type':'click','x':875,'y':34},{'type':'wait','milliseconds':200},
 {'type':'screenshot','name':'cold-paused.png'}]}


def require(value, message):
    if not value:
        g._fail('resident_recovery_proof', ROOT/'evidence'/FAILED, message)


def same_path(left, right):
    return isinstance(left, (str, Path)) and g._key(left) == g._key(right)


def validate_scope(root, workspace, run_id, profile, custody, campaign, origin, commit, policy):
    require(policy == POLICY and run_id == NEXT, 'Only the exact named recovery successor is allowed')
    require(same_path(root, APPROVED_ROOT) and same_path(workspace, ROOT), 'Recovery workspace/root differ')
    require(same_path(profile, ROOT/'qa-resident-profiles'/CAMPAIGN), 'Recovery profile differs')
    require(same_path(custody, ROOT/'evidence'/(CAMPAIGN+'-custody.json')), 'Recovery custody differs')
    require((campaign, origin, commit) == (CAMPAIGN, ORIGIN, COMMIT), 'Recovery campaign/origin/build differ')


def verify_fingerprints(actual):
    require(set(EXPECTED) <= set(actual), 'Recovery fingerprints are incomplete')
    for name, expected in EXPECTED.items():
        require(actual[name] == expected, 'Preserved '+name+' bytes changed')


def identity(value, *, state=False):
    return (value.get('profile_identity' if state else 'campaign_id') == CAMPAIGN and
        same_path(value.get('profile_path'), ROOT/'qa-resident-profiles'/CAMPAIGN) and
        value.get('origin') == ORIGIN and value.get('tested_commit') == COMMIT)


def validate_facts(bundle):
    c,j,s,e,m = (bundle[name] for name in ('custody','job','state','exit','manifest'))
    require(c.get('status') == 'RECONCILIATION_REQUIRED' and c.get('last_case') == FAILED and
        same_path(c.get('last_output'), ROOT/'evidence'/FAILED), 'Failed custody must remain unreconciled history')
    require(c.get('campaign_id') == CAMPAIGN and c.get('origin') == ORIGIN and
        same_path(c.get('profile_path'), ROOT/'qa-resident-profiles'/CAMPAIGN), 'Failed custody identity differs')
    require(all(identity(value, state=is_state) for value,is_state in (
        (j,False),(s,True),(e,False),(bundle['prior_job'],False),(bundle['prior_state'],True))), 'Receipt identity differs')
    require(c.get('mode') == j.get('mode') == s.get('profile_mode') == e.get('mode') == 'resume', 'Recovery is resume-only')
    require(s.get('persistent_profile') is True and s.get('game_dom',{}).get('url') == ORIGIN+'/index.html', 'Original resident origin is not proven')
    require(type(j.get('browser_exit')) is int and j['browser_exit'] == 1 and
        type(j.get('active_at_release')) is int and j['active_at_release'] == 0 and
        j.get('error') is None and j.get('timed_out') is False and j.get('cleanup_errors') == [], 'Original owned Job closure is not proven')
    require(e.get('browser_exit') == 1 and type(e.get('active_at_release')) is int and e['active_at_release'] == 0 and
        e.get('error') is None and e.get('cleanup_errors') == [] and e.get('resident_lease_released') is True and
        e.get('profile_worker_assigned') is True and e.get('custody_started') is True, 'Final cleanup receipt is not proven')
    require(s.get('ready') is True and s.get('closed') is True and s.get('context_close_completed') is True and
        s.get('completed') is False and s.get('inflight') is None and s.get('error') == '270_SECOND_BOUND' and
        s.get('deadline_hit') is True and type(s.get('page_errors')) is int and s['page_errors'] == 0 and
        type(s.get('next_sequence')) is int and s['next_sequence'] == 2, 'Only the closed inspection deadline is eligible')
    start=s.get('controller_start_ms');deadline=s.get('deadline_ms');trigger=s.get('exit_trigger',{})
    require(type(start) is int and type(deadline) is int and deadline-start == 270000 and
        s.get('work_deadline_ms') == start+180000 and trigger.get('reason') == '270_SECOND_BOUND' and
        type(trigger.get('at_ms')) is int and deadline <= trigger['at_ms'] <= deadline+10000, 'Deadline evidence differs')
    secondary=s.get('secondary_events',[])
    require(len(secondary) == 1 and secondary[0].get('reason') == 'BROWSER_DISCONNECTED_BEFORE_COMPLETION' and
        trigger['at_ms'] <= secondary[0].get('at_ms',-1) <= trigger['at_ms']+10000, 'Unexpected exit event exists')
    commands=s.get('commands',[])
    require(len(commands) == 1 and commands[0].get('sequence') == 1 and
        {k:commands[0].get(k) for k in ('id','intent','actions')} == OLD_COMMAND and
        commands[0].get('input_dispatch_completed') is True, 'Only the exact cold inspection command is eligible')
    require(bundle['queue'] == OLD_COMMAND and bundle['done'].get('id') == OLD_COMMAND['id'] and
        bundle['done'].get('completed') is True and bundle['done'].get('input_dispatch_completed') is True, 'Queue/completion receipts differ')
    dispatches=s.get('action_dispatches',[])
    require(len(dispatches) == len(OLD_COMMAND['actions']), 'Unexpected input dispatch exists')
    for index,event in enumerate(dispatches):
        require(event.get('sequence') == 1 and event.get('id') == OLD_COMMAND['id'] and
            event.get('action_index') == index and event.get('action') == OLD_COMMAND['actions'][index] and
            event.get('dispatch_status') == 'api_returned' and
            type(event.get('dispatch_started_at_ms')) is int and type(event.get('dispatch_completed_at_ms')) is int and
            start <= event['dispatch_started_at_ms'] <= event['dispatch_completed_at_ms'] < deadline, 'Inspection dispatch is uncertain or different')
    require(bundle['queue_names'] == ['001.json'] and bundle['done_names'] == ['done-1.json'] and
        bundle['file_names'] == EXPECTED_FILES, 'Extra queue, intent, reservation or output artifact exists')
    admission=bundle['admission']
    require(admission.get('sequence') == 1 and admission.get('id') == OLD_COMMAND['id'] and
        admission.get('reviewed_quote_context') is None and admission.get('budget',{}).get('intent') == 'play' and
        admission['budget'].get('ok') is True, 'Original command admission differs')
    limits=j.get('limits',{})
    require(limits.get('cpu_rate') == 1200 and limits.get('aggregate_job_cpu_percent') == 12 and
        limits.get('job_memory_limit_bytes') == 2*1024**3 and limits.get('kill_on_close') is True and
        limits.get('breakaway_allowed') is False and j.get('timeout_seconds') == 300, 'Original caps differ')
    require(j.get('browser_source_sha256') == BROWSER_SHA and j.get('launcher_source_sha256') == FAILED_LAUNCHER_SHA and
        bundle['browser_source_sha256'] == BROWSER_SHA, 'Original controller/launcher evidence differs')
    require(j.get('storage') == m and j.get('storage_manifest_sha256') == EXPECTED['manifest'] and
        same_path(j.get('storage_manifest'), APPROVED_ROOT/'runs'/FAILED/'evidence/storage-manifest.json'), 'Original storage manifest differs')
    paths=m.get('paths',{});binding=m.get('resident_profile_binding',{})
    require(m.get('schema') == 'bth-qa-storage/resident-v1' and m.get('prepared') is True and m.get('run_id') == FAILED and
        same_path(paths.get('workspace'),ROOT) and same_path(paths.get('profile'),ROOT/'qa-resident-profiles'/CAMPAIGN) and
        binding.get('last_case') == PRIOR and same_path(binding.get('last_output'),ROOT/'evidence'/PRIOR), 'Prior identity chain differs')
    require(binding.get('metadata_hashes',{}).get('job') == EXPECTED['prior_job'] and
        binding.get('metadata_hashes',{}).get('state') == EXPECTED['prior_state'], 'Prior closed receipt fingerprints differ')
    for prior in (bundle['prior_job'],):
        require(prior.get('browser_exit') == 0 and prior.get('active_at_release') == 0 and prior.get('error') is None and
            prior.get('timed_out') is False, 'Earlier clean Job is not proven')
    ps=bundle['prior_state']
    require(all(ps.get(k) is True for k in ('closed','completed','context_close_completed')) and ps.get('inflight') is None,
        'Earlier completed observation is not proven')
    return {'policy':POLICY,'failed_case':FAILED,'failed_case_completed':False,'next_case':NEXT,
        'classification':'closed bounded cold inspection, not successful gameplay','accepted_commands':1,
        'gameplay_replay_authorized':False,'profile_contents_read':False}


def collect(workspace,profile,custody,campaign,origin,commit,run_id,common,common_hashes):
    from bth_qa_resident import _owned_json,_dir_identity
    validate_scope(APPROVED_ROOT,workspace,run_id,profile,custody,campaign,origin,commit,POLICY)
    out=ROOT/'evidence'/FAILED;prior=ROOT/'evidence'/PRIOR
    paths={'exit':out/'adapter-exit.json','queue':out/'commands/001.json','done':out/'done-1.json',
        'manifest':APPROVED_ROOT/'runs'/FAILED/'evidence/storage-manifest.json',
        'prior_job':prior/'job.json','prior_state':prior/'state.json','admission':out/'queue-admission-1.json'}
    bundle=dict(common);hashes=dict(common_hashes)
    for name,path in paths.items():bundle[name],hashes[name]=_owned_json(path)
    verify_fingerprints(hashes)
    for directory in (out,out/'commands'):g._inspect(directory)
    bundle.update(queue_names=sorted(p.name for p in (out/'commands').iterdir()),
        done_names=sorted(p.name for p in out.glob('done-*.json')),file_names=sorted(p.name for p in out.iterdir()))
    source=out/'ordinary_game.cjs'
    require(g._probe(source) == (True,False,False) and source.stat().st_size <= 1024**2, 'Original QA controller is absent/unsafe')
    with source.open('rb') as stream:raw=stream.read(1024**2+1)
    require(len(raw) <= 1024**2, 'Original QA controller exceeded bound')
    bundle['browser_source_sha256']=hashlib.sha256(raw).hexdigest()
    hashes['controller']=bundle['browser_source_sha256']
    facts=validate_facts(bundle)
    require(list(_dir_identity(profile)) == bundle['manifest']['resident_profile_binding'].get('profile_identity'), 'Original profile directory identity changed')
    return facts,hashes


def recovery_command():
    return {'id':'reconciled-cold-observe-close','intent':'checkpoint_close','actions':[
        {'type':'click','x':480,'y':405},{'type':'wait','milliseconds':1000},
        {'type':'click','x':875,'y':34},{'type':'wait','milliseconds':200},
        {'type':'screenshot','name':'recovery-cold-menu.png'},{'type':'close'}]}


def constrain_controller(source):
    """QA controller only: all unlisted commands reject before input dispatch."""
    import json
    marker='function validate(c){'
    require(source.count(marker) == 1, 'Original controller validation seam differs')
    expected=recovery_command()
    check='\n const recoveryExpected='+json.dumps(expected,separators=(',',':'))+';\n'
    check+=" if(state.next_sequence!==1||Date.now()-controllerStarted>90000||JSON.stringify(fs.readdirSync(path.join(ROOT,'commands')).sort())!==JSON.stringify(['001.json']))throw Error('RECOVERY_SINGLE_EARLY_COMMAND_ONLY');\n"
    check+=" if(!c||c.id!==recoveryExpected.id||c.intent!==recoveryExpected.intent||JSON.stringify(c.actions)!==JSON.stringify(recoveryExpected.actions))throw Error('RECOVERY_EXACT_COLD_CLOSE_ONLY');\n"
    require(source.count('const state={') == 1, 'Original controller state seam differs')
    return source.replace(marker,marker+check,1).replace('const state={','const state={recovery_policy:'+json.dumps(POLICY)+',',1)


def review_success(out,job,state):
    """Ordinary admission additionally needs an explicit archived UI review."""
    from bth_qa_resident import _owned_json
    require(same_path(out,ROOT/'evidence'/NEXT), 'Recovery successor output differs')
    review,rh=_owned_json(out/'recovery-observation-review.json')
    previous,ph=_owned_json(out/'previous-custody.json')
    require(ph == EXPECTED['custody'] and job.get('preserved_custody_sha256') == ph and
        previous.get('status')=='RECONCILIATION_REQUIRED' and previous.get('last_case')==FAILED,
        'Failed predecessor custody not preserved')
    for value in (job,state):
        require(value.get('recovery_policy') == POLICY, 'Recovery provenance missing')
    require(state.get('commands') and len(state['commands']) == 1 and
        {k:state['commands'][0].get(k) for k in ('id','intent','actions')} == recovery_command(), 'Recovery actions differ')
    dispatches=state.get('action_dispatches',[])
    require(len(dispatches) == 6, 'Recovery dispatch count differs')
    start=state.get('controller_start_ms');end=state.get('deadline_ms')
    require(type(start) is int and type(end) is int and end-start==270000, 'Recovery time authority differs')
    for i,d in enumerate(dispatches):
        require(d.get('sequence')==1 and d.get('id')==recovery_command()['id'] and d.get('action_index')==i and
            d.get('action')==recovery_command()['actions'][i] and
            d.get('dispatch_status')==('controller_close_requested' if i==5 else 'api_returned') and
            type(d.get('dispatch_started_at_ms')) is int and type(d.get('dispatch_completed_at_ms')) is int and
            start<=d['dispatch_started_at_ms']<=d['dispatch_completed_at_ms']<end, 'Recovery dispatch differs or is uncertain')
    require(review.get('policy') == POLICY and review.get('case') == NEXT and
        review.get('approved_for_ordinary_successor') is True and review.get('profile_contents_read') is False and
        review.get('observed') == {'location':'Jazz Club','cash':1,'heat':0,'day':5,'minute':45,'menu_visible':True},
        'Explicit cold Menu observation review required')
    for name in ('job','state'):
        _,digest=_owned_json(out/(name+'.json'))
        require(review.get(name+'_sha256') == digest, 'Review does not bind final '+name)
    image=out/'recovery-cold-menu.png';g._inspect(image.parent)
    require(g._probe(image) == (True,False,False) and image.stat().st_size <= 8*1024**2, 'Reviewed screenshot unavailable/unsafe')
    with image.open('rb') as stream:raw=stream.read(8*1024**2+1)
    require(len(raw)<=8*1024**2 and review.get('screenshot_sha256') == hashlib.sha256(raw).hexdigest(), 'Reviewed screenshot changed')
    return {'recovery_review':rh,'recovery_screenshot':hashlib.sha256(raw).hexdigest(),'failed_custody_archive':ph}
