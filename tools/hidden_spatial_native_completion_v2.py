"""Explicit guarded continuation of the stopped Hidden V4 native campaign.

The owned QA project still has8727 runtime source. This separately hashed
controller is not asserted to be part of that source commit. No automatic
phase chaining, old receipt writes, project-source edits or profile migration.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import json
from pathlib import Path
from types import SimpleNamespace

import hidden_spatial_native_completion_profile_v2 as policy

base, guard, selected = policy.base, policy.guard, policy.selected
FROZEN_POLICY_SHA = "c3bd15b0e3ebc582f282f060a30f773c5e5924cba941c5c3dc0ad56c698897ae"
PHASES = ("thin-qualify", "thin-strong", *policy.REMAINING_ENGINE_PHASES, "completion-summary")
FILE_PHASES = {"thin-qualify", "completion-summary"}
ENGINE_PHASES = set(PHASES) - FILE_PHASES
CONTROLLER_PATH = Path(__file__).resolve()
OMITTED = {"storage-manifest.json", "trial-inputs.json", "launch-claim.json",
           "job.json", "worker.log", "phase-result.json"}


def config(args):
    policy.require(args.run_prefix == policy.RUN_PREFIX and 1 <= args.timeout <= 1200,
                   "Exact fresh continuation prefix and timeout1..1200 required")
    policy.require(guard.sha(Path(policy.__file__)) == FROZEN_POLICY_SHA,
                   "Reviewed continuation policy bytes changed")
    old = policy.authenticate_base()
    custody = policy.authenticate_old(old)
    history = policy.authenticate_successful_history()
    return {"schema":policy.SCHEMA, "qa_root":str(policy.ROOT), "workspace":str(policy.PROJECT),
            "project":str(policy.PROJECT), "run_prefix":args.run_prefix, "timeout":args.timeout,
            "source_commit":policy.SOURCE_COMMIT, "source_tree":policy.SOURCE_TREE,
            "runtime_source_files":policy.SOURCE_FILES, "runtime_identity_sha256":policy.IDENTITY_SHA,
            "base_config":old, "base_config_sha256":policy.BASE_CONFIG_SHA,
            "base_runner_sha256":policy.BASE_RUNNER_SHA, "base_policy_sha256":policy.BASE_POLICY_SHA,
            "controller_path":str(CONTROLLER_PATH), "controller_sha256":guard.sha(CONTROLLER_PATH),
            "policy_sha256":FROZEN_POLICY_SHA, "transport_catalog_sha256":policy.TRANSPORT_CATALOG_SHA,
            "controller_is_not_in_runtime_source_commit":True,
            "old_custody":custody, "successful_original_history":history,
            "input_workspace_access":"READ_ONLY_RETAINED_NO_PROFILE_MIGRATION",
            "project_source_access":"READ_ONLY_4049_WITH_NORMAL_OWNED_GODOT_CACHE_ONLY",
            "new_outputs":"Fresh per-phase profiles/temp/evidence/claims only; two evidence-only authenticated GD transports",
            "production_art_written":False, "test_updated":False}


def evidence_for(cfg, phase):
    policy.require(phase in PHASES, "Exact continuation phase required")
    return policy.ROOT/"runs"/(cfg["run_prefix"]+"-"+phase)/"evidence"


def observer_path(evidence, phase):
    row = policy.transport_catalog()["transports"][phase]
    return evidence / Path(row["source"]).name


def command(cfg, phase, evidence):
    if phase in FILE_PHASES:
        return [sys.executable, "-B", str(CONTROLLER_PATH), phase,
                "--run-prefix="+cfg["run_prefix"], "--timeout="+str(cfg["timeout"]), "--worker"]
    original_phase = "thin-wrap" if phase == "thin-strong" else phase
    result = base.command(cfg["base_config"], original_phase, SimpleNamespace(evidence=evidence))
    if phase in ("thin-strong", "effective-hits"):
        result[result.index("--script")+1] = str(observer_path(evidence, phase))
    return result


def payload_inventory(evidence):
    """All new ordinary output files; no unknown directory or reparse traversal."""
    files = {}
    for path in sorted(evidence.iterdir()):
        selected.plain(path)
        policy.require(path.is_file(), "Unexpected continuation output directory/non-file: "+str(path))
        if path.name not in OMITTED:
            files[path.name] = guard.sha(path)
    return files


def verify_readonly(cfg):
    policy.require(policy.authenticate_base() == cfg["base_config"] and
                   policy.authenticate_old(cfg["base_config"]) == cfg["old_custody"] and
                   policy.authenticate_successful_history() == cfg["successful_original_history"] and
                   guard.sha(policy.PROJECT/"hidden_spatial_source_identity.json") == policy.IDENTITY_SHA and
                   guard.sha(CONTROLLER_PATH) == cfg["controller_sha256"] and
                   guard.sha(Path(policy.__file__)) == cfg["policy_sha256"] and
                   guard.sha(policy.TRANSPORT_CATALOG_PATH) == cfg["transport_catalog_sha256"],
                   "Old receipts/runtime project/controller custody changed")
    return cfg["old_custody"]


def previous(cfg, phase):
    evidence = evidence_for(cfg, phase)
    record = guard.read_json(evidence/"phase-result.json")
    job, inputs, manifest, claim = (guard.read_json(evidence/name) for name in
        ("job.json", "trial-inputs.json", "storage-manifest.json", "launch-claim.json"))
    policy.require(record["schema"] == policy.PHASE_SCHEMA and record["phase"] == phase and record["status"] == "PASS" and
        record["source_config_sha256"] == guard.fingerprint(cfg) and inputs["source_config"] == cfg and
        inputs["source_config_sha256"] == guard.fingerprint(cfg) and
        inputs["engine_campaign_admission"] is (phase in ENGINE_PHASES) and
        record["controller_sha256"] == cfg["controller_sha256"] and
        record["runtime_source_commit"] == policy.SOURCE_COMMIT and record["runtime_source_tree"] == policy.SOURCE_TREE and
        record["old_supervisor_status"] == "FAILED_UNCHANGED" and record["old_phase_result_written"] is False and
        record["job_sha256"] == guard.sha(evidence/"job.json") and record["log_sha256"] == guard.sha(evidence/"worker.log") and
        selected.qualified_job(job) and job["limits"]["kill_on_close"] is True and job["limits"]["breakaway_allowed"] is False and
        job["storage_gate_before_job"] and job["storage_gate_before_child"] and
        job["command"] == inputs["command"] == command(cfg,phase,evidence) and
        job["timeout_seconds"] == cfg["timeout"] and job["storage"] == manifest and
        job["storage_manifest_sha256"] == claim["manifest_sha256"] == guard.sha(evidence/"storage-manifest.json") and
        selected.same_path(job["storage_manifest"],evidence/"storage-manifest.json") and
        selected.same_path(manifest["paths"]["workspace"],policy.PROJECT) and
        selected.same_path(manifest["paths"]["evidence"],evidence) and manifest["prepared"] is True and
        manifest["schema"] == "bth-qa-storage/v1" and
        manifest["expected_write_bytes"] == 4*1024**3 and manifest["reserve_bytes"] == 20*1024**3 and
        record["custody_before"] == cfg["old_custody"] == record["custody_after"] and
        record["artifact_sha256"] == payload_inventory(evidence) and
        not guard.ERROR_LINE.search((evidence/"worker.log").read_text()),
        "Exact closed new continuation receipt/Job/storage/custody differs: "+phase)
    return record


def prerequisites(phase):
    return PHASES[:PHASES.index(phase)]


def materialize_observer(cfg, phase, layout):
    if phase not in ("thin-strong", "effective-hits"):
        return
    guard.validate_layout(layout)
    raw, provenance = policy.transported_observer(phase,cfg["run_prefix"])
    path = observer_path(layout.evidence,phase)
    provenance.update({"active_path":str(path), "controller_sha256":cfg["controller_sha256"],
                       "policy_sha256":cfg["policy_sha256"], "runtime_identity_sha256":policy.IDENTITY_SHA,
                       "runtime_source_commit":policy.SOURCE_COMMIT, "runtime_source_tree":policy.SOURCE_TREE})
    with path.open("xb") as handle:
        handle.write(raw)
    guard.write_new(layout.evidence/"observer-provenance.json",provenance)


def qualify_worker(cfg):
    custody = verify_readonly(cfg)
    return {"status":"QUALIFIED_EXISTING_ORIGINAL_51_ONLY", "old_custody":custody,
            "old_supervisor_status":"FAILED_UNCHANGED", "old_phase_result_written":False,
            "stronger246_coverage_inferred":False, "engine_restarted":False}


def summary_worker(cfg):
    records = {phase:previous(cfg,phase) for phase in PHASES[:-1]}
    verify_readonly(cfg)
    ids = [name for phase in policy.original.BATCH_SCENARIOS
           for name in records[phase]["artifacts"]["contract"]["case_ids"]]
    policy.require(ids == policy.original.CASE_IDS, "Complete ordered26 original primary cases required")
    return {"status":"CONTINUED_NATIVE_OBSERVATIONS_PASS_PENDING_INDEPENDENT_ART_REVIEW",
            "old_v4_campaign_status":"STOPPED_22_PASS_THIN_SUPERVISOR_FAILED_6_NOT_RUN",
            "old_pass_observations":22, "qualified_existing_51_observations":1,
            "fresh_stronger_246_extra_observations":1, "fresh_original_remaining_engine_observations":5,
            "this_summary_observations":1, "total_observations_including_extra":30,
            "original_phase_slots_covered_excluding_summary":28, "nominal_original_phases_including_summary":29,
            "new_controller_phases":list(PHASES), "new_receipts":{p:guard.sha(evidence_for(cfg,p)/"phase-result.json") for p in records},
            "old_receipts":policy.BASE_RECEIPTS, "old_failed_supervisor_receipt_created":False,
            "source_commit":policy.SOURCE_COMMIT, "source_tree":policy.SOURCE_TREE,
            "runtime_identity_sha256":policy.IDENTITY_SHA, "runtime_source_files":4049,
            "controller_sha256":cfg["controller_sha256"], "controller_not_in_runtime_source_commit":True,
            "primary_cases":26, "primary_case_ids":ids, "native_entries":31, "default_low_detail_entries":31,
            "art_approval":False, "production_art_written":False, "test_updated":False,
            "scope":"Native observer evidence only; no UI lifecycle/save/revisit/browser or independent art/TEST approval."}


def result_for(cfg, phase, layout):
    if phase in FILE_PHASES:
        return guard.read_json(layout.evidence/"worker-result.json")
    report_name = ("thin_wrap_probe.json" if phase == "thin-strong" else base.REPORT_NAMES[phase])
    report = guard.read_json(layout.evidence/report_name)
    counts = (policy.strong_thin_contract(report) if phase == "thin-strong" else policy.remaining_contract(phase,report))
    pngs = base.png_inventory(layout.evidence)
    if phase == "thin-strong":
        policy.require({p["file"] for p in pngs} == set(counts["expected_pngs"]) and
                       all(p["dimensions"] == [1800,860] for p in pngs), "All56 native stronger-thin PNGs required")
    if phase == "effective-hits":
        for row in report["contexts"]:
            detail = guard.read_json(layout.evidence/(row["case_id"]+"_layout_difference.json"))
            policy.require(detail == row["layout_evidence"], "Exact original per-context geometry detail required")
    if phase in ("thin-strong", "effective-hits"):
        raw, expected = policy.transported_observer(phase,cfg["run_prefix"])
        actual = guard.read_json(layout.evidence/"observer-provenance.json")
        policy.require(observer_path(layout.evidence,phase).read_bytes() == raw and
                       all(actual[k] == value for k,value in expected.items()) and
                       actual["controller_sha256"] == cfg["controller_sha256"] and
                       actual["runtime_identity_sha256"] == policy.IDENTITY_SHA, "Materialized observer custody changed")
    return {"report":str(layout.evidence/report_name), "sha256":guard.sha(layout.evidence/report_name),
            "checks":report.get("checks"), "contract":counts, "generated_png_inventory":pngs,
            "runtime_source_commit":policy.SOURCE_COMMIT, "original_observer_assertions_unchanged":True}


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase",choices=("plan",*PHASES))
    parser.add_argument("--run-prefix",required=True)
    parser.add_argument("--timeout",type=int,default=1200)
    parser.add_argument("--engine-go",action="store_true")
    parser.add_argument("--worker",action="store_true",help=argparse.SUPPRESS)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        cfg = config(args)
        if args.worker:
            policy.require(args.phase in FILE_PHASES, "Only new file workers permitted")
            layout = guard.load_layout(cfg)
            inputs = guard.read_json(layout.evidence/"trial-inputs.json")
            policy.require(layout.prepared and inputs["source_config"] == cfg and
                           selected.same_path(layout.evidence,evidence_for(cfg,args.phase)),
                           "Exact fresh guarded file-worker admission required")
            result = qualify_worker(cfg) if args.phase == "thin-qualify" else summary_worker(cfg)
            guard.write_new(layout.evidence/"worker-result.json",result)
            return 0
        phases = PHASES if args.phase == "plan" else (args.phase,)
        layouts = {p:guard.plan_layout(policy.ROOT,policy.PROJECT,cfg["run_prefix"]+"-"+p) for p in phases}
        for layout in layouts.values():
            guard.validate_layout(layout)
        if args.phase == "plan":
            print(json.dumps({"status":"READ_ONLY_SEPARATE_HIDDEN_CONTINUATION_PLAN",
                "source_config":cfg, "source_config_sha256":guard.fingerprint(cfg),
                "phases":[{"phase":p,"command":command(cfg,p,l.evidence),"engine_admission_required":p in ENGINE_PHASES,
                           "workspace":str(l.workspace),"evidence":str(l.evidence)} for p,l in layouts.items()],
                "executed":False},indent=2))
            return 0
        phase, layout = args.phase, layouts[args.phase]
        for prior in prerequisites(phase):
            previous(cfg,prior)
        if phase in ENGINE_PHASES:
            policy.require(args.engine_go, "Explicit fresh continuation --engine-go required")
        before = verify_readonly(cfg)
        layout = guard.prepare_layout(layout)
        materialize_observer(cfg,phase,layout)
        cmd = command(cfg,phase,layout.evidence)
        guard.write_new(layout.evidence/"trial-inputs.json",{"source_config":cfg,
            "source_config_sha256":guard.fingerprint(cfg),"command":cmd,
            "engine_campaign_admission":bool(args.engine_go and phase in ENGINE_PHASES),
            "admission_scope":"Fresh continuation only; no host process/mutex claim"})
        if phase in ENGINE_PHASES:
            with base.engine_admission(args.engine_go):
                job = guard.execute(layout,cmd,timeout=args.timeout,cpu_rate=1200)
        else:
            job = guard.execute(layout,cmd,timeout=args.timeout,cpu_rate=1200)
        policy.require(selected.qualified_job(job) and job["limits"]["kill_on_close"] is True and
                       job["limits"]["breakaway_allowed"] is False and
                       not guard.ERROR_LINE.search((layout.evidence/"worker.log").read_text()),
                       "New guarded Job failed; stop without retry: "+str(layout.evidence))
        after = verify_readonly(cfg)
        artifacts = result_for(cfg,phase,layout)
        receipt = {"schema":policy.PHASE_SCHEMA,"phase":phase,"status":"PASS",
            "source_config_sha256":guard.fingerprint(cfg),"controller_sha256":cfg["controller_sha256"],
            "runtime_source_commit":policy.SOURCE_COMMIT,"runtime_source_tree":policy.SOURCE_TREE,
            "runtime_identity_sha256":policy.IDENTITY_SHA,"controller_not_in_runtime_source_commit":True,
            "job_sha256":guard.sha(layout.evidence/"job.json"),"log_sha256":guard.sha(layout.evidence/"worker.log"),
            "artifact_sha256":payload_inventory(layout.evidence),"artifacts":artifacts,
            "custody_before":before,"custody_after":after,"old_supervisor_status":"FAILED_UNCHANGED",
            "old_phase_result_written":False,"art_approval":False,"production_art_written":False,"test_updated":False}
        guard.validate_layout(layout)
        guard.write_new(layout.evidence/"phase-result.json",receipt)
        print(json.dumps(receipt,indent=2))
        return 0
    except (OSError,ValueError,KeyError,TypeError) as error:
        print(json.dumps({"status":"HIDDEN_COMPLETION_STOPPED","phase":args.phase,"error":str(error),
                          "fallback_attempted":False,"old_receipts_written":False,
                          "production_art_written":False,"test_updated":False}),file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
