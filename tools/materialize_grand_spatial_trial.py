"""Preserve a non-active Grand bitmap trial and exact source package on guarded E:."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import struct

from bth_qa_storage import Layout, validate_layout

B64_SHA = '47c06f947a878142f8416c07f3713bc4a5fa423de5a6de238af1a64f5dd4b419'
PNG_SHA = '31e7a40bfedcbc68a00a615e400b3df88bab03d180558fd3c88749a410147c63'
MASTER_SHA = 'f5b26c4f16b4ff419154c555d48f553013d8c75363284c0090b7eff07d19eb9f'
PACKAGE_SHA = '5b4e87763e85358b85fc0ce73232afc8878f132a4294904970c7fdfbd8f30060'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source-root', type=Path, required=True)
    a = p.parse_args()
    evidence = Path(os.environ['BTH_QA_EVIDENCE_DIR'])
    manifest = json.loads((evidence / 'storage-manifest.json').read_text())
    layout = Layout(**{k:Path(v) for k,v in manifest['paths'].items()},
                    **{k:manifest[k] for k in ('run_id','token','expected_write_bytes','reserve_bytes','prepared')})
    validate_layout(layout, extra_write_paths=(layout.workspace,))
    if any(layout.workspace.iterdir()):
        raise ValueError('Fresh empty workspace required; no overwrites')
    source = a.source_root.resolve(strict=True)
    folder = source / 'assets/art/environments/grand_casino'
    paths = sorted(x for x in folder.rglob('*.png')) + [source / 'data/art/environments/grand_casino.json', source / 'data/art/environments/index.json']
    inventory = {x.relative_to(source).as_posix():sha(x.read_bytes()) for x in paths}
    seal = sha('\n'.join(k+' '+v for k,v in sorted(inventory.items())).encode())
    if len(paths) != 22 or seal != PACKAGE_SHA or inventory['assets/art/environments/grand_casino/background.png'] != MASTER_SHA:
        raise ValueError('Exact original22-file Grand source identity required: '+seal)
    raw_source = source / 'review_artifacts/environment_art_sources/grand-spatial-r1/grand-spatial-r1.png.b64'
    encoded = raw_source.read_bytes()
    if sha(encoded) != B64_SHA:
        raise ValueError('Preserved imagegen base64 identity mismatch')
    raw = base64.b64decode(encoded, validate=False)
    if sha(raw) != PNG_SHA or struct.unpack('>II',raw[16:24]) != (1815,867):
        raise ValueError('Decoded imagegen PNG identity mismatch')
    for path in paths:
        relative = path.relative_to(source)
        data = path.read_bytes()
        if sha(data) != inventory[relative.as_posix()]:
            raise ValueError('Source changed before copy: '+str(relative))
        target = layout.workspace / 'source_baseline' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as f:
            f.write(data)
    target = layout.workspace / 'candidate_sources/grand-spatial-r1.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as f:
        f.write(raw)
    if sha(target.read_bytes()) != PNG_SHA:
        raise ValueError('Materialized PNG mismatch')
    for path in paths:
        if sha(path.read_bytes()) != inventory[path.relative_to(source).as_posix()]:
            raise ValueError('Original source changed after copy')
    proof = dict(task_id='BTH-ENV-SPATIAL-GRAND-001',raw_png=str(target),raw_png_sha256=PNG_SHA,
                 raw_size=[1815,867],original_source_files=inventory,original_package_sha256=seal,
                 production_files_changed=False,qa_runtime_launched=False,candidate_approved=False)
    with (evidence/'source-materialization.json').open('x',encoding='utf-8') as f:
        json.dump(proof,f,indent=2)
        f.write('\n')
    print(json.dumps({k:v for k,v in proof.items() if k != 'original_source_files'}))

if __name__ == '__main__':
    main()
