"""Separate guarded GBR composition preview; no formal-suite/release authority.

The chosen base and actual sealed overlay are admitted before planning/writing.
Original production context/liveness scripts remain unchanged. No capture phase,
cleanup, profile migration, publishing or old-receipt adoption is implemented.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import hashlib
import zipfile

import gbr_composition_preview_profile as policy
import grand_spatial_native_trial as guard
import bth_qa_selected_source_v2 as selected
from bth_qa_storage import plan_layout,prepare_layout,validate_layout,Layout,StorageGuardError
from bth_qa_guarded_run import execute

SCHEMA="bth.gbr_composition_preview_phase/v1"
INPUT_SCHEMA="bth.gbr_composition_preview_inputs/v1"
PHASES=("source-identity","tree","baseline-tree","select","archive","prepare","install","import","identity","liveness","contexts")
GIT_PHASES={"source-identity","tree","baseline-tree","archive"}
FILE_PHASES={"select","prepare","install","identity"}
OUTER_PHASES=GIT_PHASES|{"select","prepare"}
ENGINE_PHASES={"import","liveness","contexts"}
IDENTITY_NAMES={"gbr_composition_preview_identity.json","grandback_capture_inputs.json"}
HELPERS=("gbr_composition_preview.py","gbr_composition_preview_profile.py","grand_spatial_native_trial.py",
    "grand_back_room_spatial_native_profile.py","bth_qa_selected_source_v2.py","bth_qa_selected_source.py",
    "bth_qa_storage.py","bth_qa_guarded_run.py","bth_qa_command_paths.py","bar_spatial_native_suite.py",
    "bar_spatial_candidate_check.py","audit_pck_manifest.py")
FROZEN={"grand_spatial_native_trial.py":"650e14dfd71197bd55021553e3ec9adfe1f67533ea3e7c930a456e05bcd3ac6a",
    "grand_back_room_spatial_native_profile.py":"c34375889ac8e35f8852c724cbe0e801d5c181920c9fae7583883583a21cb594",
    "bth_qa_selected_source_v2.py":"051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625",
    "bth_qa_selected_source.py":"311ab097dd7d57ab0eacdd342b2b4e0b8f6d49af914e827c8f5adbd934c7e353",
    "bth_qa_storage.py":"cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
    "bth_qa_guarded_run.py":"7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
    "bth_qa_command_paths.py":"bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b",
    "bar_spatial_native_suite.py":"2bbb359859449141118f1ce21ba08d698bd1abf4d6c5e16fa1da8defde55eea4",
    "bar_spatial_candidate_check.py":"bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f",
    "audit_pck_manifest.py":"23bb8e453dd84e3bfb840f5c060c238ff408617b1893eaa02fad267ff3bfa1e4"}
PYTHON_SHA="3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
PRIVATE_RAW_GDS=tuple("tools/envart_private_spatial_"+n+".gd" for n in ("base_acceptance","lucky_acceptance","probe"))
require,sha,read=policy.require,policy.sha,policy.read


def evidence(cfg,phase):
    require(phase in PHASES,"Unknown preview phase")
    return policy.ROOT/"runs"/(cfg["run_prefix"]+"-"+phase)/"evidence"


def write_paths(cfg,phase):
    require(phase in PHASES,"Unknown preview output phase")
    if phase=="archive":return (Path(cfg["archive"]).parent,)
    if phase=="prepare":return (Path(cfg["project"]),)
    if phase in OUTER_PHASES:return ()
    return (Path(cfg["project"]),)


def helper_snapshot():
    values={n:sha(Path(__file__).with_name(n)) for n in HELPERS}
    require(all(values[n]==h for n,h in FROZEN.items()),"Frozen shared source changed")
    return values


def config(args):
    # This is deliberately first: no Layout preparation or write/child can occur
    # without an actual assembled, reviewed, hash-bound custody record.
    admission=policy.load_admission(args.custody_json,args.custody_sha256)
    archived_control=policy.archived_context_control()
    paths={n:selected.plain(getattr(args,n)) for n in ("workspace","qa_root","engine","git","git_dir","baseline_stage","native_extension_descriptor","editor_native_library")}
    require(all(Path(getattr(args,n)).is_absolute() for n in paths),"Explicit absolute inputs required")
    outer=paths["workspace"];project=outer/"qa_source"
    require(paths["qa_root"]==policy.ROOT and outer.parent==policy.ROOT/"workspaces" and
        re.fullmatch(r"BTH-ENV-SPATIAL-GBRPREVIEW-[A-Za-z0-9_-]+",outer.name) and
        re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,65}",args.run_prefix) and 1<=args.timeout<=1200,
        "Fresh explicit disjoint GBR preview workspace/prefix/timeout required")
    protected=[policy.FIXED_SOURCE,policy.original.LEGACY,Path(admission["candidate_root"]),Path(admission["source_baseline"]),
        policy.ROOT/"workspaces/BTH-ENV-SPATIAL-GBRTRIAL-20261116"]
    require(all(not outer.is_relative_to(p) and not p.is_relative_to(outer) for p in protected),"Never reuse/migrate a retained source or profile workspace")
    require((args.source_commit,args.source_tree)==(policy.BASE_SOURCE,policy.BASE_TREE),"Exact root-chosen source base required")
    require(sha(paths["engine"])==guard.ENGINE_SHA and sha(paths["engine"].with_name("Godot_v4.6-stable_win64.exe"))==guard.RUNTIME_SHA and
        sha(sys.executable)==PYTHON_SHA and paths["baseline_stage"]==selected.BASE_STAGE and
        paths["git_dir"].is_dir(),"Exact Python/engine/runtime/selected baseline/Git directory required")
    require(paths["native_extension_descriptor"].is_relative_to(policy.ROOT) and paths["editor_native_library"].is_relative_to(policy.ROOT) and
        sha(paths["native_extension_descriptor"])==guard.NATIVE_DESCRIPTOR_SHA and sha(paths["editor_native_library"])==guard.EDITOR_DLL_SHA and
        paths["editor_native_library"].name==guard.EDITOR_DLL_NAME,"Explicit qualified native overlay inputs required")
    helpers=helper_snapshot()
    require(admission["custody"]["driver_helpers"]==helpers,"Actual owner custody must bind every exact new/frozen driver helper")
    return {"schema":INPUT_SCHEMA,**{n:str(p) for n,p in paths.items()},"project":str(project),"run_prefix":args.run_prefix,
        "source_commit":args.source_commit,"source_tree":args.source_tree,"source_scope":selected.SCOPE,"full_repository_archive":False,
        "custody_path":str(selected.plain(args.custody_json,file=True)),"custody_sha256":args.custody_sha256,
        "custody_control_sha256":admission["control_sha256"],"candidate_root":admission["candidate_root"],"candidate_files":admission["candidate_files"],
        "candidate_seal":admission["custody"]["candidate"]["seal"],"baseline_files":admission["baseline_files"],
        "archive":str(policy.ROOT/"runs"/(args.run_prefix+"-archive")/"evidence/source.tar"),
        "timeout":args.timeout,"position":args.position,"python_sha256":PYTHON_SHA,"git_sha256":sha(paths["git"]),
        "helpers":helpers,"original_helpers":dict(policy.original.HELPERS),"original_provenance":dict(policy.original.PROVENANCE),
        "native_only_observer_targets":list(policy.EXTERNAL_GDS),"archived_context_positive_control":archived_control,"limits":dict(policy.LIMITS)}


def controls(cfg):
    value=policy.load_admission(cfg["custody_path"],cfg["custody_sha256"])
    require(value["control_sha256"]==cfg["custody_control_sha256"] and value["candidate_files"]==cfg["candidate_files"] and
        helper_snapshot()==cfg["helpers"] and sha(sys.executable)==cfg["python_sha256"] and sha(cfg["git"])==cfg["git_sha256"],"Preview source/admission/helper custody changed")
    for name,h in {**cfg["original_helpers"],**cfg["original_provenance"]}.items():
        require(sha(policy.original.LEGACY/name)==h,"Original observer/provenance source changed")
    require(sha(cfg["engine"])==guard.ENGINE_SHA and sha(Path(cfg["engine"]).with_name("Godot_v4.6-stable_win64.exe"))==guard.RUNTIME_SHA and
        sha(cfg["native_extension_descriptor"])==guard.NATIVE_DESCRIPTOR_SHA and sha(cfg["editor_native_library"])==guard.EDITOR_DLL_SHA,
        "Pinned engine/native donor changed across phase")
    return value


def command(cfg,phase,layout=None):
    if phase in GIT_PHASES:return selected.phase_command(cfg,phase)
    if phase in FILE_PHASES:
        tokens=[]
        for key in ("workspace","qa_root","engine","git","git_dir","baseline_stage","native_extension_descriptor","editor_native_library","source_commit","source_tree","run_prefix","timeout","position","custody_json","custody_sha256"):
            value=cfg["custody_path"] if key=="custody_json" else cfg[key]
            tokens += ["--"+key.replace("_","-")+"="+str(value)]
        return [sys.executable,"-B",str(Path(__file__).absolute()),phase,"--worker",*tokens]
    require(phase in ENGINE_PHASES,"No capture/export/old phase fallback in preview adapter")
    result=[cfg["engine"]]+(["--headless"] if phase in ("import","liveness") else [])+["--path",cfg["project"]]
    if phase=="import":return result+["--editor","--import"]
    if phase=="liveness":return result+["--script","res://scripts/tests/animation_liveness_without_pointer_check.gd"]
    return result+["--rendering-method","gl_compatibility","--audio-driver","Dummy","--resolution","1280x720",
        "--position",cfg["position"],"--script","res://tools/envart_grandback_preart_metadata.gd"]


def previous(cfg,phase):
    e=evidence(cfg,phase);result,job,inputs,manifest,claim=(read(e/n) for n in
        ("phase-result.json","job.json","trial-inputs.json","storage-manifest.json","launch-claim.json"))
    require(result.get("schema")==SCHEMA and result.get("phase")==phase and result.get("status")=="PASS" and
        result.get("source_config_sha256")==selected.digest(cfg) and selected.qualified_job(job) and
        job["command"]==inputs["command"]==command(cfg,phase) and inputs["source_config"]==cfg and
        inputs["source_config_sha256"]==selected.digest(cfg) and inputs["engine_campaign_admission"] is (phase in ENGINE_PHASES) and
        result["source_commit"]==cfg["source_commit"] and result["source_tree"]==cfg["source_tree"] and
        result["limits"]==policy.LIMITS and result["job_sha256"]==sha(e/"job.json") and result["log_sha256"]==sha(e/"worker.log") and
        selected.same_path(result["job_receipt"],e/"job.json") and manifest["schema"]=="bth-qa-storage/v1" and manifest["prepared"] is True and
        manifest["expected_write_bytes"]==4*1024**3 and manifest["reserve_bytes"]==20*1024**3 and
        selected.same_path(manifest["paths"]["workspace"],cfg["workspace"] if phase in OUTER_PHASES else cfg["project"]) and
        selected.same_path(manifest["paths"]["evidence"],e) and selected.same_path(manifest["paths"]["run_root"],e.parent) and
        selected.same_path(job["storage_manifest"],e/"storage-manifest.json") and claim["schema"]=="bth.qa_launch_claim/v1" and
        job["storage_manifest_sha256"]==claim["manifest_sha256"]==sha(e/"storage-manifest.json") and
        not guard.ERROR_LINE.search((e/"worker.log").read_text(encoding="utf-8",errors="replace")),"Prior own preview phase is not exact closed PASS: "+phase)
    expected={"worker-result.json"} if phase in FILE_PHASES else set()
    if phase=="select":expected|={"selection.json","closure.json"}
    if phase=="contexts":expected|={"grand_casino_back_room_preart_metadata.json","preview-output-inventory.json"}
    require(set(result["artifact_sha256"])==expected,"Incomplete preview artifact custody")
    for n,h in result["artifact_sha256"].items():require(sha(e/selected.relative_name(n))==h,"Preview artifact changed")
    return result


def write(path,value,layout):
    validate_layout(layout,extra_write_paths=(Path(path).parent,))
    with selected.plain(path).open("x",encoding="utf-8",newline="\n") as handle:json.dump(value,handle,indent=2);handle.write("\n")


def verify_prepared(cfg):
    e=evidence(cfg,"prepare");r=previous(cfg,"prepare");project=Path(cfg["project"])
    path=project/"qa_reference/prepared-source.json"
    require(sha(path)==r["artifacts"]["prepared_identity_sha256"],"Prepared source record changed")
    prepared=read(path);installed_path=project/"qa_reference/candidate-install.json"
    installed=None
    if installed_path.exists():
        ir=previous(cfg,"install");installed=read(installed_path)
        require(sha(installed_path)==ir["artifacts"]["candidate_install_sha256"] and installed==ir["artifacts"]["record"],"Owned candidate record changed")
    for name,h in prepared["files"].items():
        expected=installed["files"].get(name,h) if installed else h
        require(sha(project/name)==expected,"Prepared source/native UID/helper changed: "+name)
    policy.validate_project(project,installed["files"] if installed else None)
    return prepared,installed


def identity_files(project):
    return {n:h for n,h in guard.scan(project).items() if n not in IDENTITY_NAMES}


def verify_identity(cfg):
    r=previous(cfg,"identity");project=Path(cfg["project"])
    require(sha(project/"gbr_composition_preview_identity.json")==r["artifacts"]["identity_sha256"] and
        sha(project/"grandback_capture_inputs.json")==r["artifacts"]["capture_inputs_sha256"],"Own preview identity changed")
    value=read(project/"gbr_composition_preview_identity.json")
    require(identity_files(project)==value["files"],"Source inventory changed after preview identity")
    verify_prepared(cfg)
    require(import_links(cfg)==value["candidate_import_links"],"Actually imported candidate linkage changed")
    return value


def import_links(cfg):
    """Fresh Godot import must bind actual new PNG bytes, not stale CTEXs."""
    root=Path(cfg["project"]);result={}
    for name in sorted(policy.PNG_CHANGES):
        source=selected.plain(root/name,file=True)
        require(sha(source)==cfg["candidate_files"][name],"Candidate source PNG differs before texture load")
        metadata=selected.plain(root/(name+".import"),file=True).read_text(encoding="utf-8-sig")
        paths=re.findall(r'^path="res://([^"\n]+\.ctex)"\r?$',metadata,re.M)
        require(len(paths)==1 and paths[0].startswith(".godot/imported/") and 'source_file="res://'+name+'"' in metadata,
            "Exact source/import/remap linkage required")
        texture=selected.plain(root/selected.relative_name(paths[0]),file=True)
        digest=hashlib.md5(source.read_bytes()).hexdigest()
        md5=selected.plain(texture.with_suffix(".md5"),file=True).read_text(encoding="utf-8-sig")
        require('source_md5="'+digest+'"' in md5 and texture.stat().st_size>32,"Fresh compiled texture/source MD5 differs")
        result[name]={"source_sha256":sha(source),"source_md5":digest,"compiled_path":paths[0],"compiled_sha256":sha(texture),
            "import_sha256":sha(root/(name+".import"))}
    return result


def require_cold_import(cfg):
    require(not(Path(cfg["project"])/".godot").exists(),"Cold import requires absent cache; no stale cache reuse")


def worker(cfg,phase,layout):
    require(phase in FILE_PHASES,"Only explicit own file workers")
    controls(cfg);project=Path(cfg["project"])
    if phase=="select":
        for p in ("source-identity","tree","baseline-tree"):previous(cfg,p)
        plan=selected.selection_plan((evidence(cfg,"source-identity")/"worker.log").read_bytes(),
            (evidence(cfg,"tree")/"worker.log").read_bytes(),cfg["source_commit"],cfg["source_tree"])
        selected.write_budget(plan,layout.expected_write_bytes)
        closure=selected.prove_closure(plan,cfg["baseline_stage"],cfg["native_extension_descriptor"],(evidence(cfg,"baseline-tree")/"worker.log").read_bytes())
        forbidden=(*PRIVATE_RAW_GDS,*policy.EXTERNAL_GDS)
        require(all(n not in plan["files"] and n+".uid" not in plan["files"] for n in forbidden),"Native-only/untracked observer GD/UID may not be staged from working tree")
        for n,v in (("selection.json",plan),("closure.json",closure)):write(layout.evidence/n,v,layout)
        return {"selection_sha256":plan["selection_sha256"],"selected_files":plan["selected_files"],"selected_bytes":plan["selected_bytes"],"scope":selected.SCOPE}
    if phase=="prepare":
        previous(cfg,"select");archive=previous(cfg,"archive")["artifacts"];plan=read(evidence(cfg,"select")/"selection.json")
        require(sha(cfg["archive"])==archive["sha256"],"Immutable selected archive changed")
        proof=selected.verify_tar(cfg["archive"],plan)
        expected=policy.fixed_art();runtime=policy.runtime_controls(policy.FIXED_SOURCE)
        require(len(runtime)==policy.RUNTIME_COUNT and selected.digest(runtime)==policy.RUNTIME_SHA,"Fixed runtime donor changed")
        for name,h in {**runtime,**expected,**policy.original.CANONICAL_IMPORTS}.items():
            require(proof["files"].get(name,{}).get("sha256")==h,"Chosen committed source incompatible before extraction: "+name)
        extracted=selected.extract_verified(cfg["archive"],plan,project,layout)
        for rel,source,h in ((selected.DESCRIPTOR,cfg["native_extension_descriptor"],guard.NATIVE_DESCRIPTOR_SHA),
            ("addons/coin_pusher_native/bin/"+guard.EDITOR_DLL_NAME,cfg["editor_native_library"],guard.EDITOR_DLL_SHA)):
            target=project/rel;require(not target.exists() and sha(source)==h,"Qualified overlay occupied/changed")
            validate_layout(layout,extra_write_paths=(target.parent,));target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("xb") as handle:handle.write(Path(source).read_bytes())
            require(sha(target)==h,"Qualified overlay copy differs")
        bindings={}
        for name,h in cfg["original_helpers"].items():
            target=project/name;raw=(policy.original.LEGACY/name).read_bytes()
            require(sha(policy.original.LEGACY/name)==h,"Original helper source changed")
            if target.exists():require(target.read_bytes()==raw,"Original selected observer byte/assertion change")
            else:
                validate_layout(layout,extra_write_paths=(target.parent,))
                with target.open("xb") as handle:handle.write(raw)
            bindings[name]={"original_sha256":h,"active_sha256":sha(target),"assertions_unchanged":True,"native_only":name in policy.EXTERNAL_GDS}
        reference=project/"qa_reference";validate_layout(layout,extra_write_paths=(reference,));reference.mkdir()
        with (reference/".gdignore").open("x") as handle:handle.write("# Exclude original observer provenance from Godot discovery.\n")
        with zipfile.ZipFile(reference/"gbr-preview-original-observers.zip","x",compression=zipfile.ZIP_DEFLATED) as saved:
            for name,h in sorted({**cfg["original_helpers"],**cfg["original_provenance"]}.items()):
                require(sha(policy.original.LEGACY/name)==h,"Original provenance changed");saved.writestr(name,(policy.original.LEGACY/name).read_bytes())
        validate_layout(layout,extra_write_paths=(project,))
        with (project/"override.cfg").open("xb") as handle:handle.write(guard.IMPORT_POLICY)
        policy.validate_project(project)
        value={"source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],"source_scope":selected.SCOPE,
            "source_archive_sha256":archive["sha256"],"selection_sha256":plan["selection_sha256"],"files":guard.scan(project),
            "original_helper_bindings":bindings,"verified_selected_extraction":extracted,"external_driver_helpers":cfg["helpers"],
            "driver_is_external_to_chosen_base_commit":True,"limits":dict(policy.LIMITS)}
        write(reference/"prepared-source.json",value,layout)
        return {"prepared_identity_sha256":sha(reference/"prepared-source.json"),"files":len(value["files"]),"selection_sha256":plan["selection_sha256"]}
    if phase=="install":
        prepared,installed=verify_prepared(cfg);require(installed is None,"Fresh candidate install only")
        for name,h in cfg["candidate_files"].items():
            require(sha(project/name)==cfg["baseline_files"][name],"Owned source differs from selected baseline before install")
            if h!=cfg["baseline_files"][name]:
                validate_layout(layout,extra_write_paths=((project/name).parent,))
                with (project/name).open("wb") as handle:handle.write((Path(cfg["candidate_root"])/name).read_bytes())
            require(sha(project/name)==h,"Owned overlay differs after copy")
        policy.validate_project(project,cfg["candidate_files"])
        value={"files":cfg["candidate_files"],"candidate_seal":cfg["candidate_seal"],"custody_sha256":cfg["custody_sha256"],"limits":dict(policy.LIMITS)}
        write(project/"qa_reference/candidate-install.json",value,layout)
        return {"candidate_install_sha256":sha(project/"qa_reference/candidate-install.json"),"record":value}
    previous(cfg,"import");prepared,installed=verify_prepared(cfg);require(installed is not None,"Installed custody-bound overlay required")
    require(not any((project/n).exists() for n in IDENTITY_NAMES),"No rebinding existing identities")
    files=identity_files(project);extras=set(files)-set(prepared["files"])-{"qa_reference/prepared-source.json","qa_reference/candidate-install.json"}
    require(all(n.endswith(".uid") and n[:-4] in policy.EXTERNAL_GDS for n in extras),"Only declared native-observer UID additions admitted")
    require(read(project/"data/environments/scenarios.json").get(policy.ROOM,[])==[],"Actual GBR Base-only catalog required")
    write(project/"grandback_capture_inputs.json",{"source_hashes":files,"catalog":["__none"]},layout)
    value={"schema":"bth.gbr_composition_preview_identity/v1","files":files,"source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],
        "source_config_sha256":selected.digest(cfg),"candidate_seal":cfg["candidate_seal"],"custody_sha256":cfg["custody_sha256"],
        "native_only_observers":list(policy.EXTERNAL_GDS),"candidate_import_links":import_links(cfg),"limits":dict(policy.LIMITS)}
    write(project/"gbr_composition_preview_identity.json",value,layout)
    return {"identity_sha256":sha(project/"gbr_composition_preview_identity.json"),"capture_inputs_sha256":sha(project/"grandback_capture_inputs.json"),
        "source_files":len(files),"expected_context_checks":2*len(files)+41}


@contextmanager
def engine_admission(enabled):
    require(enabled,"Root's explicit exclusive engine grant required")
    key="BTH_GRANDBACK_PREART_ENGINE_GO";old=os.environ.get(key);os.environ[key]="EXPLICIT_PARENT_SAFE_GAP_GO"
    try:yield
    finally:
        if old is None:os.environ.pop(key,None)
        else:os.environ[key]=old


def png_outputs(e):
    result={};pending=[selected.plain(e)]
    while pending:
        parent=pending.pop()
        for child in parent.iterdir():
            child=selected.plain(child)
            if child.is_dir():pending.append(child)
            elif child.suffix.lower()==".png":
                child=selected.plain(child,file=True);n=child.relative_to(e).as_posix()
                result[n]={"sha256":sha(child),"bytes":child.stat().st_size}
    return result


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("phase",choices=("plan",*PHASES))
    for n in ("workspace","qa-root","engine","git","git-dir","baseline-stage","native-extension-descriptor","editor-native-library","custody-json"):
        parser.add_argument("--"+n,type=Path,required=True)
    for n in ("source-commit","source-tree","run-prefix","custody-sha256"):parser.add_argument("--"+n,required=True)
    parser.add_argument("--position",default="-32000,-32000");parser.add_argument("--timeout",type=int,default=1200)
    parser.add_argument("--engine-go",action="store_true");parser.add_argument("--worker",action="store_true",help=argparse.SUPPRESS)
    args=parser.parse_args(argv)
    try:
        cfg=config(args);phase=args.phase
        if args.worker:
            require(phase in FILE_PHASES,"Only own file workers may enter internal mode")
            e=Path(os.environ["BTH_QA_EVIDENCE_DIR"]);record=read(e/"storage-manifest.json")
            layout=Layout(**{k:Path(v) for k,v in record["paths"].items()},**{k:record[k] for k in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
            validate_layout(layout,extra_write_paths=write_paths(cfg,phase))
            require(layout.prepared and selected.same_path(layout.evidence,evidence(cfg,phase)) and layout.run_id==cfg["run_prefix"]+"-"+phase and
                selected.same_path(layout.workspace,cfg["workspace"] if phase in OUTER_PHASES else cfg["project"]) and
                selected.same_path(layout.run_root,evidence(cfg,phase).parent) and record["schema"]=="bth-qa-storage/v1" and
                read(e/"trial-inputs.json")=={"source_config":cfg,"source_config_sha256":selected.digest(cfg),"command":command(cfg,phase),
                    "engine_campaign_admission":False,"scope":"PREVIEW_CUSTODY_ONLY; no host-idle or formal-suite claim"} and
                layout.expected_write_bytes==4*1024**3 and layout.reserve_bytes==20*1024**3,
                "Exact admitted own file-worker Layout required")
            claim=read(e/"launch-claim.json")
            require(claim["schema"]=="bth.qa_launch_claim/v1" and claim["manifest_sha256"]==sha(e/"storage-manifest.json"),"Actual worker launch claim required before first write")
            result=worker(cfg,phase,layout);controls(cfg);write(e/"worker-result.json",result,layout);return 0
        phases=PHASES if phase=="plan" else (phase,)
        layouts={p:plan_layout(policy.ROOT,cfg["workspace"] if p in OUTER_PHASES else cfg["project"],cfg["run_prefix"]+"-"+p) for p in phases}
        for p,layout in layouts.items():validate_layout(layout,extra_write_paths=write_paths(cfg,p))
        if phase=="plan":
            print(json.dumps({"schema":INPUT_SCHEMA,"status":"READ_ONLY_PREVIEW_CUSTODY_PLAN","config":cfg,
                "phases":[{"phase":p,"command":command(cfg,p),"engine_grant_required":p in ENGINE_PHASES} for p in PHASES],
                "limits":policy.LIMITS,"executed":False},indent=2));return 0
        layout=layouts[phase]
        if phase=="source-identity":require(not Path(cfg["project"]).exists() and
            (not Path(cfg["workspace"]).exists() or not any(Path(cfg["workspace"]).iterdir())),"Fresh absent/empty preview workspace required")
        else:previous(cfg,PHASES[PHASES.index(phase)-1])
        if phase=="archive":
            require(not Path(cfg["archive"]).exists(),"Never overwrite an archive")
            plan=read(evidence(cfg,"select")/"selection.json")
            require((plan["source_commit"],plan["source_tree"])==(cfg["source_commit"],cfg["source_tree"]),"Own selected source binding changed")
            selected.write_budget(plan,layout.expected_write_bytes)
        if phase in ENGINE_PHASES:
            require(args.engine_go,"Explicit root engine grant required")
            verify_prepared(cfg) if phase=="import" else verify_identity(cfg)
            if phase=="import":require_cold_import(cfg)
        layout=prepare_layout(layout);controls(cfg)
        cmd=command(cfg,phase)
        write(layout.evidence/"trial-inputs.json",{"source_config":cfg,"source_config_sha256":selected.digest(cfg),"command":cmd,
            "engine_campaign_admission":phase in ENGINE_PHASES,"scope":"PREVIEW_CUSTODY_ONLY; no host-idle or formal-suite claim"},layout)
        if phase in ENGINE_PHASES:
            with engine_admission(args.engine_go):job=execute(layout,cmd,timeout=cfg["timeout"],cpu_rate=1200,extra_write_paths=write_paths(cfg,phase))
        else:job=execute(layout,cmd,timeout=cfg["timeout"],cpu_rate=1200,extra_write_paths=write_paths(cfg,phase))
        require(selected.qualified_job(job) and not guard.ERROR_LINE.search((layout.evidence/"worker.log").read_text(encoding="utf-8",errors="replace")),
            "Preview Job/report failed or did not close at zero; preserve all evidence")
        controls(cfg)
        if phase in FILE_PHASES:artifacts=read(layout.evidence/"worker-result.json")
        elif phase=="source-identity":
            require((layout.evidence/"worker.log").read_text().strip().splitlines()==[cfg["source_commit"],cfg["source_tree"]],"Actual Git identity differs")
            artifacts={"commit":cfg["source_commit"],"tree":cfg["source_tree"]}
        elif phase in ("tree","baseline-tree"):
            rows=selected.parse_ls_tree((layout.evidence/"worker.log").read_bytes());artifacts={"sha256":selected.digest(rows),"files":len(rows)}
        elif phase=="archive":artifacts={"sha256":sha(cfg["archive"]),"bytes":Path(cfg["archive"]).stat().st_size}
        elif phase=="import":verify_prepared(cfg);artifacts={"source_and_canonical_UIDs_preserved":True,"candidate_import_links":import_links(cfg)}
        elif phase=="liveness":
            verify_identity(cfg);require("Animation liveness without pointer input: PASS" in (layout.evidence/"worker.log").read_text(),"Original no-pointer PASS marker absent")
            artifacts={"no_pointer_liveness":True}
        else:
            identity=verify_identity(cfg);report=read(layout.evidence/"grand_casino_back_room_preart_metadata.json")
            metrics=policy.check_context_report(report,len(identity["files"]));outputs=png_outputs(layout.evidence)
            require("__none_actual_play.png" in outputs and "__none_production_board_1800x860.png" in outputs and
                all(r[k] in outputs for r in report["views"]["__none"]["source_paint"]["objects"] for k in ("body_png","adorn_png")),"Actual full populated image/native paint outputs required")
            write(layout.evidence/"preview-output-inventory.json",outputs,layout)
            artifacts={"report_sha256":sha(layout.evidence/"grand_casino_back_room_preart_metadata.json"),"outputs":outputs,"metrics":metrics,
                "observer_historical_commit":report.get("commit"),"historical_label_is_not_chosen_source":True,"visual_review_pending":True}
        names={"worker-result.json"} if phase in FILE_PHASES else set()
        if phase=="select":names|={"selection.json","closure.json"}
        if phase=="contexts":names|={"grand_casino_back_room_preart_metadata.json","preview-output-inventory.json"}
        result={"schema":SCHEMA,"phase":phase,"status":"PASS","source_config_sha256":selected.digest(cfg),"source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],
            "job_receipt":str(layout.evidence/"job.json"),"job_sha256":sha(layout.evidence/"job.json"),"log_sha256":sha(layout.evidence/"worker.log"),
            "artifact_sha256":{n:sha(layout.evidence/n) for n in sorted(names)},"artifacts":artifacts,"limits":dict(policy.LIMITS)}
        write(layout.evidence/"phase-result.json",result,layout);print(json.dumps(result,indent=2));return 0
    except (OSError,ValueError,TypeError,KeyError,RuntimeError,zipfile.BadZipFile,StorageGuardError) as error:
        message={"status":"GBR_PREVIEW_STOPPED","phase":args.phase,"error":str(error),"fallback_retry_cleanup":False,"limits":policy.LIMITS}
        if isinstance(error,StorageGuardError):message["storage_error"]=error.as_dict()
        print(json.dumps(message),file=sys.stderr);return 1


if __name__=="__main__":
    raise SystemExit(main())
