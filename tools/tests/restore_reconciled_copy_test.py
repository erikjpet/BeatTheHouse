"""Disposable Git/private recovery fixtures; no game runtime or browser."""
import hashlib,importlib.util,json,os,subprocess,tempfile
from pathlib import Path
B=Path(__file__).resolve().parents[2];TOOL=B/'tools/restore_reconciled_copy.py'
spec=importlib.util.spec_from_file_location('recovery_tool',TOOL);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
cases=[]
def case(name,fn):
 fn();cases.append({'name':name,'passed':True})
def rejected(fn,kind=ValueError):
 try:fn()
 except kind:return
 raise AssertionError('Expected refusal')
with tempfile.TemporaryDirectory(prefix='bth-recovery-fixture-') as d:
 root=Path(d);repo=root/'repo';subprocess.run(['git','init',str(repo)],capture_output=True,check=True)
 data=b'raw\r\nsource\n\x00\xff\x01';oid=subprocess.run(['git','-C',str(repo),'hash-object','-w','--stdin'],input=data,capture_output=True,check=True).stdout.decode().strip()
 row={'action':'represent_in_retained_git','original_relative':'old/source.bin','git_blob_oid':oid,'logical_bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'mtime_ns':1700000000000000000,'alternate_streams':[]}
 manifest=root/'manifest.jsonl';manifest.write_text(json.dumps(row)+'\n',encoding='utf-8')
 def git_restore():
  out=root/'restored.bin';r=mod.restore(repo,row,out);assert r['restored'] and out.read_bytes()==data
 case('Real Git raw binary and mixed-line-ending restoration',git_restore)
 case('No-output dry run performs no writes',lambda: (mod.restore(repo,row,None)['dry_run'] is True) or (_ for _ in ()).throw(AssertionError()))
 out=root/'existing.bin';out.write_bytes(b'user-owned')
 case('Existing user file refused and unchanged',lambda: (rejected(lambda:mod.restore(repo,row,out),FileExistsError),out.read_bytes()==b'user-owned')[-1] or (_ for _ in ()).throw(AssertionError()))
 bad={**row,'sha256':'0'*64};target=root/'bad.bin'
 case('Corrupt hash refuses output and cleans only generated partial',lambda: (rejected(lambda:mod.restore(repo,bad,target)),not target.exists() and not list(root.glob('bad.bin.partial-*')))[-1] or (_ for _ in ()).throw(AssertionError()))
 private=repo/'.tmp/evidence/private-case/profile.json';private.parent.mkdir(parents=True);private.write_bytes(b'{"fixture":"synthetic only"}')
 pdat=private.read_bytes();pr={**row,'action':'move_exact_private_evidence','destination_relative':'.tmp/evidence/private-case/profile.json','logical_bytes':len(pdat),'sha256':hashlib.sha256(pdat).hexdigest()}
 if os.name=='nt':
  stream=b'[ZoneTransfer]\r\nZoneId=3\r\n';open(str(private)+':Zone.Identifier:$DATA','wb').write(stream)
  pr['alternate_streams']=[{'name':':Zone.Identifier:$DATA','bytes':len(stream),'sha256':hashlib.sha256(stream).hexdigest()}]
 def private_restore():
  out=root/'private-restored.json';mod.restore(repo,pr,out);assert out.read_bytes()==pdat and private.read_bytes()==pdat
  if os.name=='nt':assert open(str(out)+':Zone.Identifier:$DATA','rb').read()==stream
 case('Private fixture restores exact bytes/ADS while original stays unchanged',private_restore)
 case('Private traversal rejected before output',lambda:rejected(lambda:mod.restore(repo,{**pr,'destination_relative':'../private.json'},root/'escape.json')))
 case('Manifest lookup rejects unsafe original paths',lambda:rejected(lambda:mod.select_record(manifest,'../outside')))
 case('Manifest lookup returns only exact indexed original',lambda:mod.select_record(manifest,'old/source.bin')==row or (_ for _ in ()).throw(AssertionError()))
 case('Missing retained Git blob cannot leave a claimed output',lambda:(rejected(lambda:mod.restore(repo,{**row,'git_blob_oid':'f'*40},root/'missing.bin')),not (root/'missing.bin').exists())[-1] or (_ for _ in ()).throw(AssertionError()))
 def timestamp_failure():
  target=root/'timestamp.bin';original_utime=mod.os.utime
  def fail_utime(*args,**kwargs):raise PermissionError('Synthetic fixture metadata failure')
  try:
   mod.os.utime=fail_utime
   rejected(lambda:mod.restore(repo,row,target),PermissionError)
  finally:mod.os.utime=original_utime
  assert not target.exists() and not list(root.glob('timestamp.bin.partial-*'))
 case('Timestamp failure cleans partial before publishing final output',timestamp_failure)
 def long_path_restore():
  parts=['long-private-case-'+str(i)+'-'+'x'*35 for i in range(6)]
  deep=repo/'.tmp/evidence'/Path(*parts);os.makedirs(mod.io_path(deep))
  original=deep/'fixture.json';open(mod.io_path(original),'wb').write(pdat)
  rowlong={**pr,'destination_relative':original.relative_to(repo).as_posix(),'alternate_streams':[]}
  try:
   out=root/'long-restored.json';mod.restore(repo,rowlong,out);assert out.read_bytes()==pdat
  finally:
   os.unlink(mod.io_path(original))
   for _ in parts:os.rmdir(mod.io_path(deep));deep=deep.parent
 case('Long Windows private evidence paths restore exactly',long_path_restore)
r={'state':'ALL_RECOVERY_FIXTURES_PASS','cases':cases,'runtime_or_browser':False,'fixture_cleanup':'System temporary fixture directory removed normally; only generated fixture data.'}
print(json.dumps(r,indent=2))
