"""Sequential focused Godot cases inside an existing guarded fresh Job."""
import sys
sys.dont_write_bytecode = True
import argparse
import ctypes
import json
import os
from pathlib import Path
import subprocess
import time
from bth_qa_storage import Layout, check_launch, validate_layout
from bth_qa_command_paths import command_write_paths

CASES = {
 'manifest': [('manifest','scripts/tests/environment_object_manifest_check.gd',[])],
 'rooms': [('rooms','scripts/tests/grand_coin_pusher_room_check.gd',[])],
 'legacy': [('legacy','scripts/tests/grand_coin_pusher_legacy_layout_check.gd',[])],
 'rooms-legacy': [('rooms','scripts/tests/grand_coin_pusher_room_check.gd',[]),('legacy','scripts/tests/grand_coin_pusher_legacy_layout_check.gd',[])],
 'core': [('accounting','scripts/tests/coin_pusher_grand_check.gd',[]),('rooms','scripts/tests/grand_coin_pusher_room_check.gd',[]),('legacy','scripts/tests/grand_coin_pusher_legacy_layout_check.gd',[])],
 'price': [('producer','scripts/tests/coin_pusher_drop_price_check.gd',[]),('cold','scripts/tests/coin_pusher_drop_price_check.gd',['--cold'])],
 'historical': [('producer','scripts/tests/pull_tab_grand_save_check.gd',[]),('cold','scripts/tests/pull_tab_grand_save_check.gd',['--cold'])],
 'audit': [('producer','scripts/tests/pull_tab_grand_save_check.gd',['--audit']),('cold','scripts/tests/pull_tab_grand_save_check.gd',['--audit','--cold'])],
 'elapsed': [('producer','scripts/tests/pull_tab_grand_save_check.gd',['--elapsed']),('cold','scripts/tests/pull_tab_grand_save_check.gd',['--elapsed','--cold'])],
 'custody': [('producer','scripts/tests/pull_tab_custody_restore_matrix_check.gd',[]),('cold','scripts/tests/pull_tab_custody_restore_matrix_check.gd',['--cold'])],
 'payout': [('producer','scripts/tests/pull_tab_grand_legacy_payout_check.gd',[]),('cold','scripts/tests/pull_tab_grand_legacy_payout_check.gd',['--cold'])],
 'adjacent': [('continuous','scripts/tests/coin_pusher_continuous_input_check.tscn',[]),('compaction','scripts/tests/coin_pusher_input_compaction_check.tscn',[]),('paid','scripts/tests/coin_pusher_paid_resolution_check.gd',[]),('liveness','scripts/tests/animation_liveness_without_pointer_check.gd',[])],
 'rendered': [('rendered','scripts/tests/coin_pusher_rendered_copy_check.gd',[])],
 'rendered-practice': [('practice','scripts/tests/coin_pusher_rendered_copy_check.gd',['--practice-only'])],
 'rendered-rooms': [('rooms','scripts/tests/coin_pusher_rendered_copy_check.gd',['--rooms-only'])],
 'rendered-extra': [('practice','scripts/tests/coin_pusher_rendered_copy_check.gd',['--practice-only']),('rooms','scripts/tests/coin_pusher_rendered_copy_check.gd',['--rooms-only'])],
}

def in_job(handle):
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.IsProcessInJob.argtypes=[ctypes.c_void_p,ctypes.c_void_p,ctypes.POINTER(ctypes.c_int)]
    kernel.IsProcessInJob.restype=ctypes.c_int
    present=ctypes.c_int()
    if not kernel.IsProcessInJob(handle,None,ctypes.byref(present)):
        raise ctypes.WinError(ctypes.get_last_error())
    return bool(present.value)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',required=True)
    parser.add_argument('--suite',choices=CASES,required=True)
    parser.add_argument('--phase-timeout',type=int,default=240)
    args=parser.parse_args()
    if not 1<=args.phase_timeout<=500:
        raise ValueError('Bounded phase timeout1..500 required')
    manifest=Path(os.environ['BTH_QA_RUN_DIR'])/'evidence/storage-manifest.json'
    data=json.loads(manifest.read_text())
    if data.get('schema')!='bth-qa-storage/v1' or not data.get('prepared'):
        raise ValueError('Prepared fresh guard manifest required')
    names=('root','workspace','run_root','profile','temp','evidence','appdata','localappdata','home','cache','save_dir','pycache')
    layout=Layout(**{name:Path(data['paths'][name]) for name in names},run_id=data['run_id'],token=data['token'],expected_write_bytes=data['expected_write_bytes'],reserve_bytes=data['reserve_bytes'],prepared=True)
    env=dict(os.environ)
    validate_layout(layout,prepared=True,extra_write_paths=[layout.evidence])
    check_launch(layout,cwd=layout.workspace,env=env,extra_write_paths=[layout.evidence])
    if not in_job(ctypes.c_void_p(-1)):
        raise RuntimeError('Supervisor is outside guarded Job')
    receipt_path=layout.evidence/'suite.json'
    if receipt_path.exists(): raise ValueError('Single-use suite receipt already exists')
    receipt={'suite':args.suite,'inherited_job':True,'phases':[],'complete':False}
    for phase,resource,extra in CASES[args.suite]:
        prefix=args.suite+'-'+phase
        stdout=layout.evidence/(prefix+'.stdout.log')
        godot_log=layout.evidence/(prefix+'.godot.log')
        report=layout.evidence/(prefix+'.result.json')
        for output in (stdout,godot_log,report):
            if output.exists(): raise ValueError('Occupied case output: '+str(output))
        child_env=dict(env,BTH_TARGET_OUTPUT=str(report))
        command=[args.godot]
        if not args.suite.startswith('rendered'): command.append('--headless')
        command+=['--path',str(layout.workspace),'--log-file',str(godot_log)]
        command+=['--script','res://'+resource] if resource.endswith('.gd') else ['res://'+resource]
        if extra: command+=['--',*extra]
        # Outputs are declared through their admitted parent; individual known
        # CLI leaves are checked while still absent, never reclassified as dirs.
        command_write_paths(layout,command)
        gate=check_launch(layout,cwd=layout.workspace,env=child_env,extra_write_paths=[layout.evidence])
        record={'phase':phase,'command':command,'started_epoch':time.time(),'launch_gate':gate}
        with stdout.open('xb') as handle:
            child=subprocess.Popen(command,cwd=layout.workspace,env=child_env,stdin=subprocess.DEVNULL,stdout=handle,stderr=subprocess.STDOUT,creationflags=0)
            record['pid']=child.pid
            try:
                if not in_job(child._handle): raise RuntimeError('Godot child did not inherit guarded Job')
                record['inherited_job']=True
                record['exit_code']=child.wait(timeout=args.phase_timeout)
            except BaseException:
                if child.poll() is None: child.kill()
                child.wait(timeout=10)
                raise
            finally:
                record['closed']=child.poll() is not None
                record['finished_epoch']=time.time()
                receipt['phases'].append(record)
                receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
        print(json.dumps({'phase':phase,'exit_code':record['exit_code'],'closed':record['closed'],'stdout':str(stdout)}),flush=True)
        if record['exit_code']!=0: return 1
    receipt['complete']=True
    receipt_path.write_text(json.dumps(receipt,indent=2)+'\n')
    return 0

if __name__=='__main__': raise SystemExit(main())
