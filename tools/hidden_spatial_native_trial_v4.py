"""Hidden selected-source native runner; no automatic phase chaining.

Thirteen core phases remain distinct from the fifteen original Hidden
acceptance phases. Historical observers are retained, with only authenticated
quoted input-path transport and explicit current-source hash metadata rebinding.
Use explicit current Git commit/tree; no whole-repository fallback or import
sidecar auto-copy. No phase here claims final independent art/TEST acceptance.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from contextlib import contextmanager
import json
import math
import os
from pathlib import Path
import re
import struct
import tarfile
from types import SimpleNamespace
import zipfile

import grand_spatial_native_trial as guard
import bth_qa_selected_source_v2 as selected
import hidden_spatial_native_profile_v4 as policy

PREVIOUS_RUNNER_SHA = "744c7760283029c943f6cd313f5e24a32e3d8c6f2046faf1c683881ef6125674"
# V4 corrects the glint-source-paint report filename; all observer code/assertions are unchanged.
FROZEN_GUARD_SHA = "650e14dfd71197bd55021553e3ec9adfe1f67533ea3e7c930a456e05bcd3ac6a"
SELECTED_SOURCE_SHA = "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625"
FROZEN_POLICY_SHA = "5363ea2df478aec1bb59481964d923d4b325ab82b77f37e78be37b0c4671ac57"
CORE_PHASES = ("source-identity","tree","baseline-tree","select","archive","prepare","install","import","identity","contexts","motion","liveness","capture")
ACCEPTANCE_PHASES = ("current-rm","full-composite","full-composite-rm","source-paint","glint-focus","glint-source-paint",
    "counter-replay","floor-wrap","long-wrap","thin-wrap","work-highstakes","work-greased","work-muscle","effective-hits","placement")
PHASES = (*CORE_PHASES,*ACCEPTANCE_PHASES,"acceptance-summary")
GIT_PHASES = {"source-identity","tree","baseline-tree","archive"}
FILE_PHASES = {"select","prepare","install","identity","acceptance-summary"}
OUTER_PHASES = GIT_PHASES | {"select","prepare"}
ENGINE_PHASES = {"import","contexts","motion","liveness","capture",*ACCEPTANCE_PHASES}
IDENTITY_NAMES = {"hidden_capture_inputs.json","hidden_spatial_source_identity.json"}
PHASE_SCHEMA = "bth.hidden_spatial_trial_phase/v1"
SCRIPTS = {
    "contexts":"envart_hidden_initial_r2.gd","motion":"envart_hidden_animation_probe_r2.gd","capture":"envart_hidden_animation_capture_r2.gd",
    "current-rm":"envart_hidden_current_rm_r2.gd","full-composite":"envart_hidden_full_composite_r2.gd",
    "full-composite-rm":"envart_hidden_full_composite_rm_r2.gd","source-paint":"envart_hidden_source_paint_r2.gd",
    "glint-focus":"envart_hidden_glint_focus_r2.gd","glint-source-paint":"envart_hidden_glint_source_paint_r2.gd",
    "counter-replay":"envart_hidden_counter_replay_r2.gd","floor-wrap":"envart_hidden_floor_wrap_r2.gd",
    "long-wrap":"envart_hidden_long_wrap_r2.gd","thin-wrap":"envart_hidden_thin_wrap_r2.gd",
    "work-highstakes":"envart_hidden_sequence_proof_r2.gd","work-greased":"envart_hidden_sequence_proof_r2.gd",
    "work-muscle":"envart_hidden_sequence_proof_r2.gd","effective-hits":"envart_hidden_effective_hits_r2.gd",
    "placement":"envart_hidden_placement_closing_r2.gd",
}
REPORT_NAMES = {"contexts":"hidden_r2_initial_metadata.json","motion":"hidden_animation_probe.json","capture":"capture/animation_capture.json",
    "current-rm":"hidden_r2_current_rm_metadata.json","full-composite":"hidden_full_composite.json",
    "full-composite-rm":"hidden_full_composite_rm.json","source-paint":"hidden_source_paint.json",
    "glint-focus":"hidden_glint_focus.json","glint-source-paint":"hidden_glint_source_paint.json",
    "counter-replay":"hidden_counter_replay.json","floor-wrap":"floor_wrap_probe.json","long-wrap":"long_wrap_probe.json",
    "thin-wrap":"thin_wrap_probe.json","work-highstakes":"hidden_sequence_live_proof.json","work-greased":"hidden_sequence_live_proof.json",
    "work-muscle":"hidden_sequence_live_proof.json","effective-hits":"hidden_effective_hit_proof.json","placement":"hidden_placement_closing.json"}


def config(args):
    selected.full_hash(args.source_commit)
    selected.full_hash(args.source_tree)
    policy.require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,65}",args.run_prefix) and
        1 <= args.timeout <= 1200 and 0 < args.capture_seconds <= 20, "Fresh prefix/timeout1..1200/capture0..20 required")
    paths = {name:selected.plain(getattr(args,name)) for name in ("workspace","qa_root","engine","git","git_dir","baseline_stage",
        "native_extension_descriptor","editor_native_library","candidate_root","candidate_manifest","review")}
    policy.require(all(Path(getattr(args,n)).is_absolute() for n in paths) and selected.same_path(paths["qa_root"],selected.ROOT) and
        paths["workspace"].parent == paths["qa_root"]/"workspaces" and paths["workspace"].name == policy.WORKSPACE_NAME,
        "Exact admitted Hidden campaign and explicit absolute inputs required")
    roles=policy.workspace_roles(paths["workspace"],policy.RETAINED_INPUT_WORKSPACE)
    workspace,input_workspace=roles["qa_workspace"],roles["input_workspace"]
    policy.require(paths["candidate_root"]==input_workspace/"candidate_sources"/policy.APPROVAL["candidate_directory"] and
        paths["candidate_manifest"]==policy.ASSEMBLY_EVIDENCE/"hidden-spatial-r1-assembly.json",
        "Candidate and assembly proof must remain in the exact original retained input campaign")
    state=policy.baseline_state(input_workspace)
    custody=policy.source_contract(input_workspace,state["payload_files"])
    policy.require(guard.sha(paths["engine"])==guard.ENGINE_SHA and guard.sha(paths["engine"].with_name("Godot_v4.6-stable_win64.exe"))==guard.RUNTIME_SHA and
        guard.sha(Path(guard.__file__))==FROZEN_GUARD_SHA and guard.sha(Path(selected.__file__))==SELECTED_SOURCE_SHA and
        guard.sha(Path(policy.__file__))==FROZEN_POLICY_SHA, "Frozen engine/runtime/650guard/051selection/Hidden policy differ")
    descriptor,library=paths["native_extension_descriptor"],paths["editor_native_library"]
    policy.require(descriptor.is_relative_to(paths["qa_root"]) and library.is_relative_to(paths["qa_root"]) and
        guard.sha(descriptor)==guard.NATIVE_DESCRIPTOR_SHA and guard.sha(library)==guard.EDITOR_DLL_SHA and
        library.name==guard.EDITOR_DLL_NAME and selected.same_path(paths["baseline_stage"],selected.BASE_STAGE),
        "Exactly qualified descriptor+editorDLL and W2 baseline stage required")
    lines=[r.strip() for r in descriptor.read_text(encoding="utf-8-sig").splitlines() if r.strip().startswith("windows.debug")]
    policy.require(any('"res://addons/coin_pusher_native/bin/'+guard.EDITOR_DLL_NAME+'"' in r for r in lines), "Descriptor DLL binding differs")
    deps={name:guard.sha(Path(__file__).with_name(name)) for name in
        ("hidden_spatial_native_profile_v4.py","grand_spatial_native_trial.py","bth_qa_selected_source_v2.py","bth_qa_selected_source.py",
         "bth_qa_storage.py","bth_qa_guarded_run.py","bth_qa_command_paths.py","bar_spatial_native_suite.py","bar_spatial_candidate_check.py","audit_pck_manifest.py")}
    cfg={"schema":"bth.hidden_spatial_inputs/v1",**{n:str(p) for n,p in paths.items()},
        "input_workspace":str(input_workspace),"input_workspace_access":"READ_ONLY_RETAINED_NO_PROFILE_MIGRATION",
        "project":str(workspace/"qa_source"),"run_prefix":args.run_prefix,"source_commit":args.source_commit,"source_tree":args.source_tree,
        "timeout":args.timeout,"position":args.position,"capture_seconds":float(args.capture_seconds),
        "adapter_sha256":guard.sha(__file__),"python_sha256":guard.sha(sys.executable),"git_sha256":guard.sha(paths["git"]),
        "dependencies":deps,"baseline_files":state["payload_files"],"baseline_seal":policy.BASELINE_SEAL,
        "baseline_auxiliary_files":state["auxiliary_files"],"baseline_auxiliary_policy":"exact_single_sentinel_v2",
        "candidate_approval":policy.APPROVAL,"nonactive_source_custody":custody,"source_scope":selected.SCOPE,"full_repository_archive":False,
        "historical_observer_commit":policy.HISTORICAL_COMMIT,"canonical_imports_must_be_committed":policy.CANONICAL_IMPORTS,
        "observer_original_hashes":policy.original_observers(),
        "native_overlay":{"descriptor_input":str(descriptor),"descriptor_sha256":guard.NATIVE_DESCRIPTOR_SHA,
            "editor_dll_input":str(library),"editor_dll_sha256":guard.EDITOR_DLL_SHA,
            "scope":"Two explicit qualified native-only overlay inputs beyond authenticated selected Git source"}}
    cfg["archive"]=str(guard.evidence_for(cfg,"archive")/"source.tar")
    cfg["observer_literal_path_bindings"]=policy.literal_bindings(cfg)
    return cfg


def verify_baseline(cfg):
    roles=policy.workspace_roles(Path(cfg["workspace"]),Path(cfg["input_workspace"]))
    policy.require(cfg["input_workspace_access"]=="READ_ONLY_RETAINED_NO_PROFILE_MIGRATION",
        "Retained input campaign must remain read-only and separate from fresh QA outputs")
    state=policy.baseline_state(roles["input_workspace"])
    policy.require(state["payload_files"]==cfg["baseline_files"] and state["auxiliary_files"]==cfg["baseline_auxiliary_files"] and
        policy.source_contract(roles["input_workspace"],state["payload_files"])==cfg["nonactive_source_custody"] and
        policy.original_observers()==cfg["observer_original_hashes"], "External baseline/source/observer custody changed")
    return state["auxiliary_files"]


def command(cfg,phase,layout):
    if phase in GIT_PHASES:
        return selected.phase_command(cfg,phase)
    if phase in FILE_PHASES:
        arguments=[]
        for key in ("workspace","qa_root","engine","git","git_dir","baseline_stage","native_extension_descriptor","editor_native_library",
                    "candidate_root","candidate_manifest","review","source_commit","source_tree","run_prefix","timeout","capture_seconds","position"):
            arguments += ["--"+key.replace("_","-")+"="+str(cfg[key])]
        return [sys.executable,"-B",str(Path(__file__).resolve()),phase,*arguments,"--worker"]
    result=[cfg["engine"]]+(["--headless"] if phase in ("import","liveness") else [])+["--path",cfg["project"]]
    if phase=="import":
        return result+["--editor","--import"]
    if phase=="liveness":
        return result+["--script","res://scripts/tests/animation_liveness_without_pointer_check.gd"]
    result += ["--rendering-method","gl_compatibility","--audio-driver","Dummy","--resolution","1280x720","--position",cfg["position"],
               "--script","res://tools/"+SCRIPTS[phase],"--"]
    if phase=="capture":
        return result+["--out="+str(layout.evidence/"capture"),"--excerpt-seconds="+str(cfg["capture_seconds"]),
                       "--archetype="+policy.ROOM,"--layer=casino","--scenario=__none"]
    result += ["--out="+str(layout.evidence)]
    if phase in policy.BATCH_SCENARIOS:
        result += ["--baseline-source="+str(policy.LEGACY_CANVAS),"--hidden-scenario="+policy.BATCH_SCENARIOS[phase]]
    return result


def previous(cfg, phase):
    result = guard.prior(cfg, phase)
    evidence = guard.evidence_for(cfg, phase)
    job, inputs = guard.read_json(evidence / "job.json"), guard.read_json(evidence / "trial-inputs.json")
    manifest, claim = (guard.read_json(evidence / name) for name in ("storage-manifest.json", "launch-claim.json"))
    required = {"worker-result.json"} if phase in FILE_PHASES else set()
    if phase == "select":
        required |= {"selection.json", "closure.json"}
    if phase in REPORT_NAMES:
        required.add(REPORT_NAMES[phase])
    workspace = cfg["workspace"] if phase in OUTER_PHASES else cfg["project"]
    policy.require(result.get("schema") == PHASE_SCHEMA and selected.qualified_job(job) and
        result.get("source_commit") == cfg["source_commit"] and result.get("source_tree") == cfg["source_tree"] and
        result.get("source_scope") == cfg["source_scope"] == selected.SCOPE and
        result.get("baseline_auxiliary_files_before") == cfg["baseline_auxiliary_files"] == result.get("baseline_auxiliary_files_after") and
        result.get("baseline_auxiliary_files_unchanged") is True and
        result.get("job_sha256") == guard.sha(evidence / "job.json") and result.get("log_sha256") == guard.sha(evidence / "worker.log") and
        inputs.get("source_config") == cfg and inputs.get("source_config_sha256") == guard.fingerprint(cfg) and
        job.get("command") == inputs.get("command") == command(cfg, phase, SimpleNamespace(evidence=evidence)) and
        selected.same_path(result.get("job_receipt", ""), evidence / "job.json") and manifest.get("schema") == "bth-qa-storage/v1" and manifest.get("prepared") is True and
        selected.same_path(manifest["paths"]["workspace"], workspace) and selected.same_path(manifest["paths"]["evidence"], evidence) and
        selected.same_path(job.get("storage_manifest", ""), evidence / "storage-manifest.json") and
        job.get("storage_manifest_sha256") == claim.get("manifest_sha256") == guard.sha(evidence / "storage-manifest.json") and
        set(result.get("artifact_sha256", {})) == required and
        not guard.ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "Prior exact closed phase custody differs: " + phase)
    for name, digest in result["artifact_sha256"].items():
        policy.require(guard.sha(evidence / selected.relative_name(name)) == digest, "Prior phase artifact changed: " + name)
    return result

def selection(cfg):
    result = previous(cfg, "select")
    evidence = guard.evidence_for(cfg, "select")
    plan, closure = guard.read_json(evidence / "selection.json"), guard.read_json(evidence / "closure.json")
    selected.validate_plan(plan)
    policy.require(plan["source_commit"] == cfg["source_commit"] and plan["source_tree"] == cfg["source_tree"] and
        closure["selection_sha256"] == plan["selection_sha256"] == result["artifacts"]["selection_sha256"], "Selected current source binding changed")
    return plan, closure

def select_worker(cfg, layout):
    for phase in ("source-identity", "tree", "baseline-tree"):
        previous(cfg, phase)
    plan = selected.selection_plan((guard.evidence_for(cfg, "source-identity") / "worker.log").read_bytes(),
        (guard.evidence_for(cfg, "tree") / "worker.log").read_bytes(), cfg["source_commit"], cfg["source_tree"])
    selected.write_budget(plan, layout.expected_write_bytes)
    closure = selected.prove_closure(plan, cfg["baseline_stage"], cfg["native_extension_descriptor"],
        (guard.evidence_for(cfg, "baseline-tree") / "worker.log").read_bytes())
    policy.require(set(policy.CANONICAL_IMPORTS).issubset(plan["files"]), "Root must first commit the two independently audited canonical Hidden imports")
    for name, value in (("selection.json", plan), ("closure.json", closure)):
        guard.write_new(layout.evidence / name, value)
    return {"selection_sha256": plan["selection_sha256"], "selected_files": plan["selected_files"], "selected_bytes": plan["selected_bytes"], "scope": selected.SCOPE}

def prepare_worker(cfg,layout):
    plan,closure=selection(cfg)
    archive=previous(cfg,"archive")["artifacts"]
    policy.require(guard.sha(cfg["archive"])==archive["sha256"], "Selected Git archive changed")
    selected.write_budget(plan,layout.expected_write_bytes)
    proof=selected.verify_tar(cfg["archive"],plan)
    for name,expected in {**cfg["baseline_files"],**policy.CANONICAL_IMPORTS}.items():
        policy.require(proof["files"].get(name,{}).get("sha256")==expected, "Committed Hidden baseline/import differs: "+name)
    project=Path(cfg["project"])
    extracted=selected.extract_verified(cfg["archive"],plan,project,layout)
    policy.canonical_imports(project)
    for relative,source,expected in (
        (selected.DESCRIPTOR,cfg["native_extension_descriptor"],guard.NATIVE_DESCRIPTOR_SHA),
        ("addons/coin_pusher_native/bin/"+guard.EDITOR_DLL_NAME,cfg["editor_native_library"],guard.EDITOR_DLL_SHA)):
        target=project/relative
        policy.require(not target.exists() and guard.sha(source)==expected, "Explicit overlay occupied or changed")
        guard.validate_layout(layout,extra_write_paths=(target.parent,))
        target.parent.mkdir(parents=True,exist_ok=True)
        with target.open("xb") as f:
            f.write(Path(source).read_bytes())
    bindings={}
    for name,expected in policy.HELPERS.items():
        target,original=project/name,(policy.LEGACY/name).read_bytes()
        active,operations=policy.transport_bytes(name,original,cfg["observer_literal_path_bindings"])
        existing=target.exists()
        if existing:
            prior=target.read_bytes()
            policy.require(prior.replace(b"\r\n",b"\n")==original.replace(b"\r\n",b"\n"),
                           "Committed observer differs beyond line endings: "+name)
            if not operations:
                active=prior
        if not existing or target.read_bytes()!=active:
            guard.validate_layout(layout,extra_write_paths=(target.parent,))
            target.parent.mkdir(parents=True,exist_ok=True)
            with target.open("wb" if existing else "xb") as f:
                f.write(active)
        policy.require(target.read_bytes()==active, "Actual observer transport bytes differ")
        bindings[name]={"original_sha256":expected,"active_sha256":guard.sha(target),"assertions_unchanged":True,
                        "literal_path_transports":operations,"line_endings_only_other_difference":True,"canonical_uid_overwritten":False}
    original_catalog=guard.read_json(policy.LEGACY/policy.CATALOG_PATH)
    source_hashes={name:guard.sha(project/name) for name in original_catalog["source_files_sha256"]}
    active_catalog=policy.rebind_catalog(original_catalog,source_hashes,project)
    catalog_target=project/policy.CATALOG_PATH
    if catalog_target.exists():
        policy.require(guard.read_json(catalog_target)==original_catalog, "Occupied source catalog differs")
    guard.validate_layout(layout,extra_write_paths=(catalog_target.parent,))
    with catalog_target.open("w" if catalog_target.exists() else "x",encoding="utf-8",newline="\n") as f:
        json.dump(active_catalog,f,indent=2);f.write("\n")
    catalog_binding={"original_sha256":policy.PROVENANCE[policy.CATALOG_PATH],"active_sha256":guard.sha(catalog_target),
        "metadata_fields_rebound":["source_files_sha256","source_workspace"],"case_assertions_and_commands_unchanged":True,
        "source_hashes_before":original_catalog["source_files_sha256"],"source_hashes_current":source_hashes}
    reference=project/"qa_reference"
    guard.validate_layout(layout,extra_write_paths=(reference,project/"override.cfg"))
    reference.mkdir()
    with (reference/".gdignore").open("x") as f:
        f.write("# Historical observers are excluded from Godot discovery.\n")
    with zipfile.ZipFile(reference/"hidden-original-observers.zip","x",compression=zipfile.ZIP_DEFLATED) as saved:
        for name in sorted({**policy.HELPERS,**policy.PROVENANCE}):
            saved.writestr(name,(policy.LEGACY/name).read_bytes())
    with (project/"override.cfg").open("xb") as f:
        f.write(guard.IMPORT_POLICY)
    result={"source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],"source_scope":selected.SCOPE,
        "source_archive_sha256":archive["sha256"],"selection_sha256":plan["selection_sha256"],"selected_archive_proof":extracted,
        "qualified_baseline_closure":closure,"files":guard.scan(project),"helper_bindings":bindings,"catalog_binding":catalog_binding,
        "core_original_gd_count":5,"complete_original_gd_closure":19,"explicit_qualified_native_overlay":cfg["native_overlay"],
        "historical_identity_labels_are_not_current_source":True,"candidate_sources_not_imported":True,
        "canonical_tracked_uid_sidecars_preserved":True,"legacy_adapter_executed":False,
        "baseline_auxiliary_files":verify_baseline(cfg),"baseline_auxiliary_not_extracted_into_project":True}
    guard.write_new(reference/"prepared-source.json",result)
    return {"project":str(project),"source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],
        "source_scope":selected.SCOPE,"prepared_identity_sha256":guard.sha(reference/"prepared-source.json"),"files":len(result["files"])}



def identity_catalog(project):
    """Use the original observer's casino filter, then authenticate all three rows.

    Original envart_hidden_initial_r2.gd6242a7... lines61..66 filters the eight-row
    archetype catalog by layer_id=="casino". Historical initial_inputs5177124...
    already contains only those three complete rows. Club cases remain excluded.
    """
    document=guard.read_json(project/"data/environments/scenarios.json")
    policy.require(type(document) is dict and type(document.get(policy.ROOM)) is list,
        "Actual Hidden scenario catalog must be a typed room list")
    rows=document[policy.ROOM]
    policy.require(all(type(row) is dict and type(row.get("id")) is str and bool(row["id"]) and
        row.get("archetype_id")==policy.ROOM and type(row.get("layer_id")) is str and
        row["layer_id"] in ("club","casino") for row in rows),
        "Actual Hidden rows require source IDs/archetype and explicit supported layer types")
    policy.require(len({row["id"] for row in rows})==len(rows),"Duplicate actual Hidden scenario ID")
    reference=policy.LEGACY/"hidden_r2_initial_inputs.json"
    policy.require(guard.sha(reference)==policy.PROVENANCE["hidden_r2_initial_inputs.json"],
        "Original three-row Hidden catalog reference changed")
    historical=guard.read_json(reference)["catalog"]
    expected=list(policy.CONTEXT_COUNTS)[1:]
    policy.require(type(historical) is list and [row["id"] for row in historical]==expected and
        all(row["layer_id"]=="casino" for row in historical),"Original ordered three casino rows required")
    # Same selection predicate as the original frozen GD; no source data changes.
    casino=[row for row in rows if row["layer_id"]=="casino"]
    policy.require([row["id"] for row in casino]==expected and
        json.dumps(casino,sort_keys=True,separators=(",",":"),allow_nan=False)==
        json.dumps(historical,sort_keys=True,separators=(",",":"),allow_nan=False),
        "Exact ordered three full Hidden casino scenario rows required")
    return casino


def identity_worker(cfg,layout):
    previous(cfg,"import")
    prepared,installed=verify_prepared(cfg)
    policy.require(installed is not None, "Reviewed candidate installation required")
    project=Path(cfg["project"])
    policy.require(not any((project/n).exists() for n in IDENTITY_NAMES), "No existing identity rebinding")
    files=identity_files(project)
    extras=set(files)-set(prepared["files"])-{"qa_reference/prepared-source.json","qa_reference/candidate-install.json"}
    policy.require(all((n.endswith(".uid") and (project/n[:-4]).is_file()) or
        (n.endswith(".import") and (project/n[:-7]).is_file()) for n in extras), "Unknown post-import source addition")
    catalog=identity_catalog(project)
    guard.write_new(project/"hidden_capture_inputs.json",{"source_hashes":files,"catalog":catalog,
        "baseline_auxiliary_files":verify_baseline(cfg),"external_auxiliary_excluded_from_res_source_hashes":True})
    result={"schema":"bth.hidden_current_source_identity/v1","source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],
        "source_scope":selected.SCOPE,"selection_sha256":prepared["selection_sha256"],"source_archive_sha256":prepared["source_archive_sha256"],
        "source_config_sha256":guard.fingerprint(cfg),"files":files,"capture_inputs_sha256":guard.sha(project/"hidden_capture_inputs.json"),
        "original_observers":prepared["helper_bindings"],"catalog_binding":prepared["catalog_binding"],
        "historical_observer_report_commit_label":policy.HISTORICAL_COMMIT,"historical_label_is_not_current_source_identity":True,
        "canonical_tracked_uid_sidecars_preserved":True,"baseline_auxiliary_files":verify_baseline(cfg),"baseline_auxiliary_not_in_project_inventory":True}
    guard.write_new(project/"hidden_spatial_source_identity.json",result)
    return {"identity_sha256":guard.sha(project/"hidden_spatial_source_identity.json"),"capture_inputs_sha256":result["capture_inputs_sha256"],
            "source_files":len(files),"expected_context_checks":2*len(files)+609,"expected_current_rm_checks":2*len(files)+400,
            "candidate_package_sha256":installed["package_sha256"]}


def png_inventory(evidence):
    result=[]
    for item in sorted(evidence.rglob("*.png")):
        path=selected.plain(item,file=True)
        with path.open("rb") as f:
            header=f.read(24)
        policy.require(len(header)==24 and header[:8]==b"\x89PNG\r\n\x1a\n" and header[8:16]==b"\0\0\0\rIHDR", "Malformed actual PNG")
        result.append({"file":path.relative_to(evidence).as_posix(),"sha256":guard.sha(path),"bytes":path.stat().st_size,
                       "dimensions":list(struct.unpack(">II",header[16:24]))})
    return result


def capture_contract(report):
    frames=report.get("frames",[])
    clocks=[r.get("clock") for r in frames]
    inventory=report.get("animation_inventory",[])
    policy.require(report.get("archetype")==policy.ROOM and report.get("layer")=="casino" and report.get("scenario")=="__none" and
        report.get("pack_active") is True and [r.get("id") for r in inventory]==list(policy.ANIMATION_IDS) and
        all(r.get("web_low_detail") is True for r in inventory) and len(frames)>=2 and
        all(type(c) in (int,float) and math.isfinite(c) for c in clocks) and all(b>a for a,b in zip(clocks,clocks[1:])) and
        abs(report["actual_clock_span"]-(clocks[-1]-clocks[0]))<=.00001 and
        report.get("reduce_motion",{}).get("active") is True and
        report.get("reduce_motion",{}).get("production_art_texture_pixels_stable") is True and
        "no pointer input during capture" in report.get("note",""), "Authentic Hidden31 actual-clock/RM capture required")
    states={name:set() for name in policy.ANIMATION_IDS[:10]}
    for frame in frames:
        policy.require(frame.get("width")==1280 and frame.get("height")==720 and
            [r["id"] for r in frame["animation_states"]]==list(policy.ANIMATION_IDS), "Capture fullapp/31-state frame changed")
        for row in frame["animation_states"][:10]:
            states[row["id"]].add(row["frame"])
    policy.require(all(values==set(range(32)) for values in states.values()), "Actual capture did not observe all32 frames for each of ten cores")
    return {"frames":len(frames),"actual_clock_span":report["actual_clock_span"],"observed_core_frames":{k:sorted(v) for k,v in states.items()},
        "fullapp_is_actual_production":True,"board900_is_diagnostic_clone":True,"native1800_excludes_live_objects":True,
        "no_pointer_input_during_capture":True,"no_interpolation_resizing_or_frame_clock_rewrite":True}


def result_for(cfg,phase,layout):
    if phase in FILE_PHASES:
        value=guard.read_json(layout.evidence/"worker-result.json")
        return {"candidate_install_sha256":guard.sha(Path(cfg["project"])/"qa_reference/candidate-install.json"),"record":value} if phase=="install" else value
    log=(layout.evidence/"worker.log").read_text(encoding="utf-8",errors="strict")
    if phase=="source-identity":
        policy.require(log.strip().splitlines()==[cfg["source_commit"],cfg["source_tree"]], "Actual Git commit/tree differ")
        return {"commit":cfg["source_commit"],"tree":cfg["source_tree"]}
    if phase in ("tree","baseline-tree"):
        rows=selected.parse_ls_tree((layout.evidence/"worker.log").read_bytes())
        return {"records_sha256":selected.digest(rows),"files":len(rows)}
    if phase=="archive":
        return {"path":cfg["archive"],"sha256":guard.sha(cfg["archive"]),"bytes":Path(cfg["archive"]).stat().st_size}
    if phase=="import":
        return {"canonical_source_files_verified":True,"candidate_installed":True}
    if phase=="liveness":
        policy.require("Animation liveness without pointer input: PASS" in log, "Original no-pointer PASS marker absent")
        return {"no_pointer_liveness":True}
    path=layout.evidence/REPORT_NAMES[phase]
    report=guard.read_json(path)
    counts=(capture_contract(report) if phase=="capture" else
            policy.report_contract(phase,report,source_files=previous(cfg,"identity")["artifacts"]["source_files"]))
    pngs=png_inventory(layout.evidence)
    if phase in ("source-paint","glint-source-paint"):
        expected={r[k] for view in report["contexts"] for r in view["objects"] for k in ("body_png","adorn_png")}
        policy.require(len(expected)==142 and expected=={r["file"] for r in pngs} and all(r["dimensions"]==[1800,860] for r in pngs),
                       "Exact actual71 body/adornment PNG pairs required")
    if phase=="capture":
        expected={("capture/"+selected.relative_name(frame[key]),tuple(size)) for frame in report["frames"] for key,size in
                  (("file",(1280,720)),("board900_file",(900,430)),("board2x_file",(1800,860)))}
        actual={(r["file"],tuple(r["dimensions"])) for r in pngs}
        policy.require(expected<=actual and len(expected)==len(report["frames"])*3, "Actual capture PNG families/paths/dimensions changed")
    return {"report":str(path),"sha256":guard.sha(path),"checks":report.get("checks"),"contract":counts,
        "generated_png_inventory":pngs,"current_source_commit":cfg["source_commit"],
        "observer_embedded_historical_commit":report.get("commit"),"historical_label_is_not_current_source_identity":True,
        "encoding":"None; actual clocks must be retained by later preview encoding"}


def prerequisites(phase):
    if phase in CORE_PHASES[1:9]:
        return [CORE_PHASES[CORE_PHASES.index(phase)-1]]
    if phase in ("contexts","motion","liveness"):
        return ["identity"]
    if phase=="capture":
        return ["contexts","motion","liveness"]
    if phase=="source-paint":
        return ["full-composite"]
    if phase=="glint-source-paint":
        return ["glint-focus"]
    if phase=="effective-hits":
        return ["contexts",*policy.BATCH_SCENARIOS]
    if phase in ACCEPTANCE_PHASES:
        return ["identity"]
    if phase=="acceptance-summary":
        return ["contexts","motion","liveness","capture",*ACCEPTANCE_PHASES]
    return []


def acceptance_worker(cfg,layout):
    records={p:previous(cfg,p) for p in prerequisites("acceptance-summary")}
    verify_identity(cfg)
    ids=[]
    for phase in policy.BATCH_SCENARIOS:
        ids+=records[phase]["artifacts"]["contract"]["case_ids"]
    policy.require(ids==policy.CASE_IDS, "Complete26 primary case union required")
    return {"status":"ORIGINAL_HIDDEN_NATIVE_ASSERTIONS_PASS_PENDING_INDEPENDENT_ART_REVIEW",
        "core_phases":list(CORE_PHASES),"acceptance_phases":list(ACCEPTANCE_PHASES),
        "native_entries":31,"default_low_detail_entries":31,"initial_objects_and_selections":71,
        "typed_object_pairs_in_separate_source_paint":71,"primary_cases":26,"primary_case_ids":ids,
        "source_commit":cfg["source_commit"],"source_tree":cfg["source_tree"],
        "phase_receipt_sha256":{p:guard.sha(guard.evidence_for(cfg,p)/"phase-result.json") for p in records},
        "art_approval":False,"production_art_written":False,"test_updated":False,
        "scope":"No UI-earned lifecycle/save/revisit or final independent art/TEST approval is inferred."}


def install_worker(cfg, layout):
    previous(cfg, "prepare")
    prepared, installed = guard.verify_prepared(cfg)
    policy.require(installed is None, "Fresh install only; no candidate overwrite")
    policy.require(prepared.get("baseline_auxiliary_files") == verify_baseline(cfg), "Prepared external auxiliary binding changed")
    result = policy.candidate(Path(cfg["candidate_root"]), Path(cfg["input_workspace"]), Path(cfg["candidate_manifest"]), Path(cfg["review"]), cfg["baseline_files"])
    project = Path(cfg["project"])
    for name, baseline in cfg["baseline_files"].items():
        policy.require(guard.sha(project / name) == baseline, "Prepared baseline changed before installation")
    for name, expected in result["files"].items():
        if expected != cfg["baseline_files"][name]:
            guard.validate_layout(layout, extra_write_paths=((project / name).parent,))
            with (project / name).open("wb") as handle:
                handle.write((Path(cfg["candidate_root"]) / name).read_bytes())
        policy.require(guard.sha(project / name) == expected, "Candidate copy mismatch: " + name)
    policy.canonical_imports(project)
    result["baseline_auxiliary_files"] = verify_baseline(cfg)
    guard.write_new(project / "qa_reference/candidate-install.json", result)
    return result

def identity_files(project):
    return {name: value for name, value in guard.scan(project).items() if name not in IDENTITY_NAMES}

def verify_prepared(cfg):
    previous(cfg, "prepare")
    previous(cfg, "install")
    prepared, installed = guard.verify_prepared(cfg)
    auxiliary = verify_baseline(cfg)
    policy.require(prepared.get("baseline_auxiliary_files") == auxiliary and
        (installed is None or installed.get("baseline_auxiliary_files") == auxiliary),
        "Prepared/installed external auxiliary proof differs")
    return prepared, installed

def verify_identity(cfg):
    qualified = previous(cfg, "identity")["artifacts"]
    project = Path(cfg["project"])
    policy.require(guard.sha(project / "hidden_spatial_source_identity.json") == qualified["identity_sha256"] and
        guard.sha(project / "hidden_capture_inputs.json") == qualified["capture_inputs_sha256"], "Current frozen identity/observer input changed")
    identity = guard.read_json(project / "hidden_spatial_source_identity.json")
    policy.require(identity_files(project) == identity["files"], "Selected source/candidate/native overlay/UID inventory changed")
    auxiliary = verify_baseline(cfg)
    capture_inputs = guard.read_json(project / "hidden_capture_inputs.json")
    policy.require(identity.get("baseline_auxiliary_files") == capture_inputs.get("baseline_auxiliary_files") == auxiliary and
        capture_inputs.get("external_auxiliary_excluded_from_res_source_hashes") is True,
        "Identity/capture external auxiliary proof differs")
    return identity

@contextmanager
def engine_admission(enabled):
    policy.require(enabled, "Explicit --engine-go campaign admission required")
    key, token = "BTH_HIDDEN_PREART_ENGINE_GO", "EXPLICIT_PARENT_SAFE_GAP_GO"
    old = os.environ.get(key)
    os.environ[key] = token
    try:
        yield
    finally:
        if old is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = old

def parse_args(argv=None):
    tokens = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    for name in ("workspace", "engine", "git", "git-dir", "candidate-root", "candidate-manifest", "review"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--qa-root", type=Path, default=selected.ROOT)
    parser.add_argument("--baseline-stage", type=Path, default=selected.BASE_STAGE)
    parser.add_argument("--native-extension-descriptor", type=Path, default=guard.QUALIFIED_NATIVE_SOURCE / "coin_pusher_native.gdextension")
    parser.add_argument("--editor-native-library", type=Path, default=guard.QUALIFIED_NATIVE_SOURCE / "bin" / guard.EDITOR_DLL_NAME)
    for name in ("source-commit", "source-tree", "run-prefix"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--engine-go", action="store_true")
    parser.add_argument("--capture-seconds", type=float, default=20.0)
    parser.add_argument("--position", default="-32000,-32000")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    return parser.parse_args(tokens)

def main(argv=None):
    args = parse_args(argv)
    try:
        cfg = config(args)
        baseline_auxiliary_before = verify_baseline(cfg)
        if args.worker:
            policy.require(args.phase in FILE_PHASES, "Only internal file phases allowed")
            layout = guard.load_layout(cfg)
            inputs = guard.read_json(layout.evidence / "trial-inputs.json")
            policy.require(layout.prepared and inputs.get("source_config") == cfg and
                selected.same_path(layout.evidence, guard.evidence_for(cfg, args.phase)), "Exact worker admission required")
            workers = {"select": select_worker, "prepare": prepare_worker, "install": install_worker, "identity": identity_worker, "acceptance-summary": acceptance_worker}
            result = workers[args.phase](cfg, layout)
            policy.require(verify_baseline(cfg) == baseline_auxiliary_before, "External baseline changed during file worker")
            guard.write_new(layout.evidence / "worker-result.json", result)
            return 0
        phases = PHASES if args.phase == "plan" else (args.phase,)
        layouts = {phase: guard.plan_layout(args.qa_root, cfg["workspace"] if phase in OUTER_PHASES else cfg["project"], args.run_prefix + "-" + phase) for phase in phases}
        for layout in layouts.values():
            guard.validate_layout(layout, extra_write_paths=(Path(cfg["project"]),))
        if args.phase == "plan":
            print(json.dumps({"status": "READ_ONLY_HIDDEN_PLAN", "source_config": cfg, "source_config_sha256": guard.fingerprint(cfg),
                "phases": [{"phase": phase, "workspace": str(layout.workspace), "command": command(cfg, phase, layout),
                    "engine_admission_required": phase in ENGINE_PHASES} for phase, layout in layouts.items()], "executed": False}, indent=2))
            return 0
        phase, layout = args.phase, layouts[args.phase]
        if phase == "source-identity":
            policy.require(not Path(cfg["project"]).exists(), "Fresh absent qa_source required before new campaign")
        for required in prerequisites(phase):
            previous(cfg, required)
        if phase == "archive":
            plan, _ = selection(cfg)
            selected.write_budget(plan, layout.expected_write_bytes)
            policy.require(not Path(cfg["archive"]).exists(), "No overwriting a selected source archive")
        if phase in ENGINE_PHASES:
            policy.require(args.engine_go, "Explicit --engine-go campaign admission required")
            verify_prepared(cfg) if phase == "import" else verify_identity(cfg)
        layout = guard.prepare_layout(layout)
        cmd = command(cfg, phase, layout)
        extra = (Path(cfg["project"]),) if phase in OUTER_PHASES else ()
        if phase == "capture":
            extra += (layout.evidence / "capture",)
        guard.write_new(layout.evidence / "trial-inputs.json", {"source_config": cfg, "source_config_sha256": guard.fingerprint(cfg), "command": cmd,
            "engine_campaign_admission": args.engine_go if phase in ENGINE_PHASES else False, "admission_scope": "Explicit campaign admission; no host-zero or mutex claim"})
        if phase in ENGINE_PHASES:
            with engine_admission(args.engine_go):
                job = guard.execute(layout, cmd, timeout=args.timeout, cpu_rate=1200, extra_write_paths=extra)
        else:
            job = guard.execute(layout, cmd, timeout=args.timeout, cpu_rate=1200, extra_write_paths=extra)
        log = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")
        policy.require(verify_baseline(cfg) == baseline_auxiliary_before, "External baseline changed during guarded phase")
        policy.require(selected.qualified_job(job) and not guard.ERROR_LINE.search(log), "Guarded Job/native log failed; retained evidence: " + str(layout.evidence))
        if phase == "import":
            verify_prepared(cfg)
        elif phase in ENGINE_PHASES:
            verify_identity(cfg)
        artifacts = result_for(cfg, phase, layout)
        names = {"worker-result.json"} if phase in FILE_PHASES else set()
        if phase == "select":
            names |= {"selection.json", "closure.json"}
        if phase in REPORT_NAMES:
            names.add(REPORT_NAMES[phase])
        receipt = {"schema": PHASE_SCHEMA, "phase": phase, "status": "PASS", "source_config_sha256": guard.fingerprint(cfg),
            "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "source_scope": selected.SCOPE,
            "job_receipt": str(layout.evidence / "job.json"), "job_sha256": guard.sha(layout.evidence / "job.json"), "log_sha256": guard.sha(layout.evidence / "worker.log"),
            "artifact_sha256": {name: guard.sha(layout.evidence / name) for name in sorted(names)}, "artifacts": artifacts,
            "baseline_auxiliary_files_before": baseline_auxiliary_before, "baseline_auxiliary_files_after": verify_baseline(cfg),
            "baseline_auxiliary_files_unchanged": True,
            "art_approval": False, "production_art_written": False, "test_updated": False}
        guard.validate_layout(layout)
        guard.write_new(layout.evidence / "phase-result.json", receipt)
        print(json.dumps(receipt, indent=2))
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, TypeError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "HIDDEN_TRIAL_STOPPED", "phase": args.phase, "error": str(error), "fallback_attempted": False,
            "production_art_written": False, "test_updated": False}), file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main())
