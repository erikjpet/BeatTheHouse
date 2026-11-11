import sys,os,json,time,subprocess,hashlib,re
from pathlib import Path
sys.dont_write_bytecode=True
sys.path.insert(0,r'D:\Projects\Beat-The-House\tools')
from bth_qa_storage import Layout,check_launch
out=Path(os.environ['BTH_QA_EVIDENCE_DIR'])
m=json.loads((out/'storage-manifest.json').read_text(encoding='utf-8'))
l=Layout(**{k:Path(v) for k,v in m['paths'].items()},run_id=m['run_id'],token=m['token'],prepared=True,expected_write_bytes=m['expected_write_bytes'],reserve_bytes=m['reserve_bytes'])
check_launch(l,cwd=os.getcwd(),env=os.environ,extra_write_paths=(l.run_root,l.evidence,l.profile,l.save_dir,l.temp))
godot=r'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
results=[]
for index,spec in enumerate(sys.argv[1:],1):
 parts=spec.split('|');name=parts[0];args=parts[1:]
 env=dict(os.environ);env.update(BTH_DISTRIBUTION_BUILD='1',PYTHONUTF8='1',BTH_CREW_RETURN_PAID='1')
 key=str(index).zfill(2)+'-'+name+('-'+'-'.join(re.sub(r'[^a-zA-Z0-9_-]','_',v) for v in args) if args else '')
 isqa=name.startswith('aud061_')
 relative=('.tmp/' if isqa else 'scripts/tests/')+name+'.gd'
 resource='res://'+relative
 if name in ('bar_dice_reveal_save_restore_check','bar_dice_cover_display_check'):
  env.update(BTH_BAR_DICE_RESTORE_STAGE=args[0] if args else 'warm',BTH_BAR_DICE_RESTORE_PRIVATE_ROOT=str(l.run_root),BTH_BAR_DICE_COVER_PRIVATE_ROOT=str(l.run_root),BTH_TARGET_OUTPUT=str(out/(key+'.json')))
  if args and args[0]=='settled':
   for prior in results:
    for line in prior['footer']:
     if line.startswith('BAR_DICE_REVEAL_SAVE_RESTORE_RESULT '):
      data=json.loads(line.split(' ',1)[1])
      if data.get('facts',{}).get('stage')=='cold' and 'final_cash' in data.get('facts',{}).get('cold',{}):
       env['BTH_DICE_EXPECTED_FINAL_CASH']=str(data['facts']['cold']['final_cash'])
  args=[]
 scene=l.workspace/'scripts/tests'/(name+'.tscn')
 cmd=[godot,'--headless','--path',str(l.workspace)]+(['res://scripts/tests/'+name+'.tscn'] if scene.exists() else ['--script',resource])
 if args:cmd+=['--']+args
 started=time.monotonic()
 with (out/(key+'.txt')).open('xb') as stream:
  gate=check_launch(l,cwd=str(l.workspace),env=env,extra_write_paths=(l.run_root,l.evidence,l.profile,l.save_dir,l.temp))
  child=subprocess.Popen(cmd,cwd=l.workspace,env=env,stdout=stream,stderr=subprocess.STDOUT)
  (out/(key+'-launch.json')).write_text(json.dumps({'gate':gate,'command':cmd,'pid':child.pid,'environment_stage':env.get('BTH_BAR_DICE_RESTORE_STAGE')},indent=2),encoding='utf-8')
  try:code=child.wait(timeout=240)
  except subprocess.TimeoutExpired:
   child.kill();child.wait();code='TIMEOUT'
 raw=(out/(key+'.txt')).read_bytes();lines=raw.decode('utf-8',errors='replace').splitlines()
 footer=[x for x in lines if ('RESULT' in x or 'REPORT ' in x or 'OBSERVATIONS ' in x or 'checks=' in x or 'RESUME11 ' in x or 'passed' in x.lower() or 'PASS' in x)]
 result={'key':key,'script':name,'args':parts[1:],'exit':code,'seconds':round(time.monotonic()-started,2),'source_sha256':hashlib.sha256((l.workspace/relative).read_bytes()).hexdigest(),'footer':footer,'errors':[x for x in lines if 'ERROR:' in x or x.startswith('FAIL')]}
 results.append(result)
 (out/'results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
 print(json.dumps({'key':key,'exit':code,'seconds':result['seconds'],'footer':[x[:180] for x in footer[-2:]],'errors':result['errors'][:5]},ensure_ascii=True),flush=True)
sys.exit(0 if all(r['exit']==0 for r in results) else 1)
