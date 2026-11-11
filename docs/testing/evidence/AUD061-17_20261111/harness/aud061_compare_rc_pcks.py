from pathlib import Path
import os,sys,json,hashlib,re
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(os.environ['BTH_QA_WORKSPACE'])/'tools'))
import audit_pck_manifest as pck
out=Path(os.environ['BTH_QA_EVIDENCE_DIR'])
packs=[Path(v) for v in sys.argv[1:]]
assert len(packs)==2
reports=[];payloads=[]
for index,path in enumerate(packs):
 data=path.read_bytes();directory=pck.find_directory(data);entries=directory['entries']
 problems=pck.audit(entries);content={}
 for e in entries:
  start=directory['pack_offset']+directory['file_base']+e['offset']
  raw=data[start:start+e['bytes']]
  assert len(raw)==e['bytes'] and hashlib.md5(raw).hexdigest()==e['md5'],e['path']
  assert not e['path'].startswith(('Microsoft/','userfs/','save_dir/','appdata/','localappdata/')),e['path']
  assert Path(e['path']).name not in ('foundation_ui_autosave.json','profile_inventory.json','meta_collection.json','user_settings.json'),e['path']
  content[e['path']]=raw
 assert not problems,problems
 report={'package':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'file_count':len(entries),'audit_failures':problems,'all_payload_md5_verified':True,'engine_version':directory['engine_version'],'files':sorted(entries,key=lambda e:e['path'])}
 (out/('manifest-'+str(index+1)+'.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
 reports.append(report);payloads.append(content)
a,b=payloads;paths=sorted(set(a)|set(b));changed=[p for p in paths if a.get(p)!=b.get(p)]
semantic=None
if changed==['.godot/global_script_class_cache.cfg']:
 def classes(raw):
  s=raw.decode('utf-8');assert s.startswith('list=')
  entries=json.loads(re.sub(r'&(?=")','',s[5:]))
  mapping={r['class']:r for r in entries};assert len(mapping)==len(entries)
  return mapping
 ca,cb=classes(a[changed[0]]),classes(b[changed[0]])
 semantic={'same_class_to_all_fields_map':ca==cb,'classes':[len(ca),len(cb)],'changed_classes':sorted(k for k in set(ca)|set(cb) if ca.get(k)!=cb.get(k))}
 for i,blob in enumerate([a[changed[0]],b[changed[0]]],1):(out/('class-cache-'+str(i)+'.cfg')).write_bytes(blob)
result={'schema':'bth.frozen_rc_pck_comparison/v1','source_commit':'fcfe0204d4d04089ac23d615eef1ab9f9ea1d1cc','source_tree':'2d49cb17f83379715435a2576473c5cba52728ff','packages':[{k:r[k] for k in ('package','bytes','sha256','file_count','all_payload_md5_verified','audit_failures')} for r in reports],'identical_file_sets':set(a)==set(b),'changed_payloads':changed,'class_cache_semantics':semantic,'same_payload_bytes':not changed,'private_exports_not_published':True}
result['passed']=set(a)==set(b) and (not changed or changed==['.godot/global_script_class_cache.cfg'] and semantic['same_class_to_all_fields_map'])
(out/'comparison.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
sys.exit(0 if result['passed'] else 1)
