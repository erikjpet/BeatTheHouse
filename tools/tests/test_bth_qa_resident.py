"""Synthetic custody/metadata only; never opens an actual browser profile."""
from dataclasses import replace
from pathlib import Path
import hashlib,json,unittest
from unittest.mock import patch
import bth_qa_storage as g
import bth_qa_resident as r
import test_bth_qa_storage as base_tests

class API:
    def ReleaseMutex(self,handle):return True
    def CloseHandle(self,handle):pass

class ResidentTests(unittest.TestCase):
    plan=base_tests.StorageGuardTests.plan
    fails=base_tests.StorageGuardTests.fails
    def setUp(self):
        base_tests.StorageGuardTests.setUp(self);r._leases.clear();r._lease_profiles.clear()
        self.workspace=Path(r'E:\CodexQA\BTH\workspaces\resident')
        self.campaign='broad-standard-unit';self.origin='http://127.0.0.1:8138';self.commit='a'*40
        self.profile=self.workspace/'qa-resident-profiles'/self.campaign
        self.custody=self.workspace/'evidence'/(self.campaign+'-custody.json')
        self.out=self.workspace/'evidence/qa-batch-unit'
        for leaf in (self.workspace,self.profile,self.out):
            for p in list(reversed(leaf.parents))+[leaf]:self.fs.entries[g._key(p)]='dir'
        self.records={
          g._key(self.custody):{'campaign_id':self.campaign,'origin':self.origin,'profile_path':str(self.profile),
            'last_case':self.out.name,'last_output':str(self.out),'status':'CLEAN_CLOSED','mode':'resume'},
          g._key(self.out/'job.json'):{'campaign_id':self.campaign,'origin':self.origin,'profile_path':str(self.profile),
            'tested_commit':self.commit,'mode':'resume','browser_exit':0,'active_at_release':0,'timed_out':False,'error':None,'cleanup_errors':[]},
          g._key(self.out/'state.json'):{'profile_identity':self.campaign,'origin':self.origin,'profile_path':str(self.profile),
            'tested_commit':self.commit,'profile_mode':'resume','persistent_profile':True,'game_dom':{'url':self.origin+'/index.html'},
            'closed':True,'completed':True,'context_close_completed':True,'inflight':None}}
        def reader(path):
            value=self.records[g._key(path)]
            return value,hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()
        self.file_id=(11,22)
        for name,value in [('_owned_json',reader),('_dir_identity',lambda p:self.file_id),('_mutex_acquire',lambda n:((API(),1),None))]:
            p=patch.object(r,name,value);p.start();self.addCleanup(p.stop)
        self.addCleanup(r._leases.clear);self.addCleanup(r._lease_profiles.clear)

    def resident(self,run='resident-unit',**kwargs):
        args=dict(root=g.DEFAULT_ROOT,workspace=self.workspace,run_id=run,profile=self.profile,
                  custody=self.custody,campaign_id=self.campaign,origin=self.origin,expected_commit=self.commit)
        args.update(kwargs);return g.plan_resident_layout(**args)

    def test_resident_plan_is_read_only_and_truthful(self):
        lay=self.resident();self.assertEqual(self.fs.writes,[])
        self.assertEqual(lay.profile,self.profile)
        self.assertEqual(lay.as_dict()['paths']['profile'],str(self.profile))
        self.assertEqual(lay.as_dict()['schema'],'bth-qa-storage/resident-v1')

    def test_resident_prepare_never_mkdirs_or_writes_profile(self):
        lay=g.prepare_layout(self.resident())
        self.assertNotIn(str(self.profile),self.fs.writes)
        self.assertFalse(any(g._inside(self.profile,Path(x)) for x in self.fs.writes))
        env=g.child_environment(lay,{})
        self.assertEqual(env['BTH_QA_PROFILE_DIR'],str(self.profile))
        self.assertTrue(g.check_launch(lay,lay.workspace,env))
        g.release_resident_layout(lay,active_owned_processes=0)
        self.fails('resident_lease_required',lambda:g.check_launch(lay,lay.workspace,env))

    def test_fresh_layout_still_rejects_resident_substitution(self):
        fresh=self.plan(workspace=self.workspace)
        self.fails('layout_mismatch',lambda:g.validate_layout(replace(fresh,profile=self.profile)))

    def test_record_drift_before_prepare_leaves_no_writes(self):
        lay=self.resident();self.records[g._key(self.out/'state.json')]['extra']='changed'
        self.fails('resident_binding_changed',lambda:g.prepare_layout(lay));self.assertEqual(self.fs.writes,[])

    def test_directory_identity_drift_rejects(self):
        lay=self.resident();self.file_id=(11,23)
        self.fails('resident_binding_changed',lambda:g.prepare_layout(lay))

    def test_busy_and_abandoned_fail_before_new_directories(self):
        for error in ('resident_profile_busy','resident_lease_abandoned'):
            with self.subTest(error=error),patch.object(r,'_mutex_acquire',return_value=(None,error)):
                self.fails(error,lambda:g.prepare_layout(self.resident()))
                self.assertEqual(self.fs.writes,[])

    def test_same_process_cannot_recursively_admit_profile(self):
        one=g.prepare_layout(self.resident('resident-one'))
        self.fails('resident_profile_busy',lambda:g.prepare_layout(self.resident('resident-two')))
        self.fails('resident_processes_active',lambda:g.release_resident_layout(one,active_owned_processes=1))
        self.assertIn(one.token,r._leases)
        g.release_resident_layout(one,active_owned_processes=0)

    def test_c_or_wrong_profile_origin_or_build_rejects(self):
        for args,code in [({'profile':r'C:\user\profile'},'system_volume'),({'profile':self.workspace/'other'},'resident_path_identity'),
          ({'origin':'https://example.test'},'resident_origin_invalid'),({'expected_commit':'b'*40},'resident_receipt_identity')]:
            with self.subTest(args=args):self.fails(code,lambda:g.prepare_layout(self.resident(**args)))
        self.assertEqual(self.fs.writes,[])

    def test_open_uncertain_or_mismatched_custody_rejects(self):
        cases=[(self.custody,'status','CASE_IN_PROGRESS','resident_custody_invalid'),
          (self.out/'job.json','active_at_release',1,'resident_not_closed'),
          (self.out/'job.json','timed_out',True,'resident_not_closed'),
          (self.out/'state.json','closed',False,'resident_not_closed'),
          (self.out/'state.json','origin','http://127.0.0.1:9999','resident_receipt_identity'),
          (self.out/'state.json','game_dom',None,'resident_receipt_identity')]
        for path,key,value,code in cases:
            data=self.records[g._key(path)];old=data.get(key);data[key]=value
            try:self.fails(code,lambda:self.resident())
            finally:data[key]=old
        self.assertEqual(self.fs.writes,[])

    def test_every_launch_rechecks_budget_receipts_and_env(self):
        lay=g.prepare_layout(self.resident());env=g.child_environment(lay,{})
        self.fs.free=23*g.GIB
        self.fails('insufficient_space',lambda:g.check_launch(lay,lay.workspace,env))
        self.fs.free=100*g.GIB
        wrong=dict(env,BTH_QA_PROFILE_DIR=str(lay.run_root/'profile'))
        self.fails('environment_spill',lambda:g.check_launch(lay,lay.workspace,wrong))
        self.records[g._key(self.custody)]['status']='CASE_IN_PROGRESS'
        self.fails('resident_custody_invalid',lambda:g.check_launch(lay,lay.workspace,env))
        g.release_resident_layout(lay,active_owned_processes=0)

    def test_fresh_profile_cannot_overlap_any_other_leaf(self):
        lay=self.resident()
        self.fails('layout_mismatch',lambda:g.prepare_layout(replace(lay,temp=self.profile)))



    def test_replaced_binding_cannot_release_another_lease(self):
        lay=g.prepare_layout(self.resident())
        forged=replace(lay,resident_binding=replace(lay.resident_binding,mutex_name='Local\\wrong'))
        self.fails('resident_lease_owner_mismatch',lambda:g.release_resident_layout(forged,active_owned_processes=0))
        self.assertIn(lay.token,r._leases)
        g.release_resident_layout(lay,active_owned_processes=0)


    def test_receipt_race_at_mutex_acquire_has_zero_writes_and_releases(self):
        lay=self.resident()
        def race(name):
            self.records[g._key(self.out/'state.json')]['changed_during_acquire']=True
            return (API(),1),None
        with patch.object(r,'_mutex_acquire',side_effect=race):
            self.fails('resident_binding_changed',lambda:g.prepare_layout(lay))
        self.assertEqual(self.fs.writes,[])
        self.assertNotIn(lay.token,r._leases)
        self.assertNotIn(lay.resident_binding.mutex_name,r._lease_profiles)


    def test_closure_requires_typed_zero_and_explicit_clean_job(self):
        job=self.records[g._key(self.out/'job.json')]
        for key,value in [('browser_exit',False),('active_at_release',False),
                          ('timed_out',None),('cleanup_errors',['close failed']),
                          ('cleanup_errors',None),('error','')]:
            with self.subTest(key=key,value=value):
                old=job[key];job[key]=value
                try:self.fails('resident_not_closed',lambda:self.resident())
                finally:job[key]=old
        for key in ('browser_exit','active_at_release','timed_out','cleanup_errors'):
            old=job.pop(key)
            try:self.fails('resident_not_closed',lambda:self.resident())
            finally:job[key]=old
        state=self.records[g._key(self.out/'state.json')]
        for key,value in [('inflight',False),('inflight',[]),('error','')]:
            existed=key in state;old=state.get(key);state[key]=value
            try:self.fails('resident_not_closed',lambda:self.resident())
            finally:
                if existed:state[key]=old
                else:state.pop(key)

class RealOwnedMetadataTests(unittest.TestCase):
    def test_bounded_plain_qa_json_reader_only_on_engineering_temp(self):
        import tempfile
        self.assertEqual(Path(tempfile.gettempdir()).drive.upper(),'E:')
        with tempfile.TemporaryDirectory(prefix='resident-synthetic-') as tmp:
            p=Path(tmp)/'synthetic.json';p.write_text('{"fixture":true}')
            value,digest=r._owned_json(p)
            self.assertEqual(value,{'fixture':True});self.assertEqual(len(digest),64)
            for content,code in [('[]','resident_receipt_invalid'),('bad','resident_receipt_invalid'),('x'*(2*1024*1024+1),'resident_receipt_bound')]:
                p.write_text(content)
                with self.assertRaises(g.StorageGuardError) as error:r._owned_json(p)
                self.assertEqual(error.exception.code,code)
            self.assertNotEqual(r._dir_identity(Path(tmp)),(0,0))

    def test_receipt_growth_after_stat_is_bounded_and_rejected(self):
        import io,tempfile
        self.assertEqual(Path(tempfile.gettempdir()).drive.upper(),'E:')
        class Tracking(io.BytesIO):
            def read(self,n=-1):
                self.requested=n
                return super().read(n)
        with tempfile.TemporaryDirectory(prefix='resident-growth-fixture-') as tmp:
            p=Path(tmp)/'small-metadata.json';p.write_text('{}')
            stream=Tracking(b' '* (r.MAX_QA_JSON_BYTES+64))
            with patch.object(Path,'open',return_value=stream):
                with self.assertRaises(g.StorageGuardError) as error:r._owned_json(p)
            self.assertEqual(error.exception.code,'resident_receipt_bound')
            self.assertEqual(stream.requested,r.MAX_QA_JSON_BYTES+1)

    def test_real_mutex_blocks_another_thread_without_any_profile(self):
        import threading,uuid
        name='Local\\BTH-QA-Resident-UNIT-'+uuid.uuid4().hex
        held,error=r._mutex_acquire(name);self.assertIsNone(error)
        api,handle=held;result=[]
        try:
            thread=threading.Thread(target=lambda:result.append(r._mutex_acquire(name)))
            thread.start();thread.join(2);self.assertFalse(thread.is_alive())
            self.assertEqual(result,[(None,'resident_profile_busy')])
        finally:api.ReleaseMutex(handle);api.CloseHandle(handle)
        again,error=r._mutex_acquire(name);self.assertIsNone(error)
        api,handle=again;api.ReleaseMutex(handle);api.CloseHandle(handle)

if __name__=='__main__':unittest.main()
