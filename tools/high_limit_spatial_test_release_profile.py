"""Authenticated High Limit release policy layered over delivered Grand25cc.

Read-only. No child, engine, publishing, network, profiles or output writes.
The frozen pure f001 policy remains unchanged and never grants baseline trust.
"""
import sys
sys.dont_write_bytecode = True

import json
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace

import high_limit_spatial_test_profile as policy
import grand_spatial_delivered_baseline as delivered
import verify_bar_spatial_test_served as served

SCHEMA = "bth.high_limit_spatial_test_release/v1"
SERVED_SCHEMA = "bth.high_limit_spatial_test_served/v1"
PURE_POLICY_SHA = "f001191f6a1d3f0cb7a4b05bf93d8c16898eabdc5248c8d911a983500a839e18"
TASK_ID = policy.TASK_ID
ENVIRONMENT = policy.ENVIRONMENT
NATIVE_PHASES = ("identity", "contexts", "motion", "liveness", "capture")
NATIVE_TOOLS = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools")


def sha(path):
    return delivered.sha(path)


def read(path):
    return delivered.read(path)


def require(value, message):
    policy.require(value, message)


def baseline():
    require(sha(Path(policy.__file__)) == PURE_POLICY_SHA, "Frozen pure HL policy changed")
    return delivered.load_certificate()


def validate_baseline_binding(declaration, certificate):
    """A supplied declaration must equal the independently authenticated input."""
    policy.check_baseline_declaration(declaration)
    pairs = {"source_commit": "source_commit", "source_tree": "source_tree", "manifest_sha256": "manifest_sha256",
        "pck_sha256": "pck_sha256", "grand_approval_sha256": "grand_approval_sha256", "grand_served_proof_sha256": "served_proof_sha256"}
    require(all(declaration[left] == certificate[right] for left, right in pairs.items()) and
        delivered.same_path(declaration["stage"], delivered.STAGE) and declaration["protected_room_seals"] == certificate["protected19_room_seals"] and
        declaration["grand_strict_pck_proof_sha256"] == delivered.canonical(certificate["strict_pck_proof"]) and
        declaration["grand_served_job_sha256"] == "ef3ffbef0bcd24fd3da81430d94bba55d6287279f11b9c3fa9ce2a3118947b84" and
        delivered.same_path(declaration["grand_approval_path"], delivered.WORKSPACE / "docs/testing/grand_spatial_v4_art_approval_20261116.json") and
        delivered.same_path(declaration["grand_served_proof_path"], delivered.RUNS / (delivered.PREFIX + "-served") / "evidence/served.json") and
        delivered.same_path(declaration["grand_strict_pck_proof_path"], declaration["grand_served_proof_path"]),
        "HL approval declaration differs from actual authenticated delivered Grand baseline")


def authenticate_native(value):
    records = value.get("native_phase_receipts")
    require(isinstance(records, dict) and set(records) == set(NATIVE_PHASES), "Exact closed HL identity/context/motion/liveness/capture receipts required")
    policy.full_hash(value.get("native_adapter_sha256"))
    policy.full_hash(value.get("native_policy_sha256"))
    native_path = NATIVE_TOOLS / "high_limit_spatial_native_trial_v4.py"
    require(sha(native_path) == value["native_adapter_sha256"] == "e1fe5dc3168a23f07aad03c0c6270e1915c1714182769d70ce2496ad1576c72d" and
            sha(NATIVE_TOOLS / "high_limit_spatial_native_profile_v2.py") == value["native_policy_sha256"] ==
            "db7e8944a7d4e7ede36b24f9cfd4f5ee2b844e17cd92551b12b89ee2da9a3d6b",
            "Actual final native adapter/policy bytes differ from final approval")
    # Load the authenticated actual runner path, so its receipt command builder
    # binds the original D: entrypoint even when this profile is archived on E:.
    # This creates a private module; no frozen module globals are replaced.
    spec = importlib.util.spec_from_file_location("_bth_hl_final_native_v4", native_path)
    require(spec is not None and spec.loader is not None, "Actual native runner loader unavailable")
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    evidence = served.plain(Path(records["identity"]["path"]).parent)
    inputs = read(evidence / "trial-inputs.json")
    cfg = inputs["source_config"]
    require(cfg.get("schema") == "bth.high_limit_spatial_inputs/v1" and cfg["source_commit"] == value["source_commit"] and
            cfg["source_tree"] == value["source_tree"] and cfg["adapter_sha256"] == value["native_adapter_sha256"] and
            cfg["dependencies"]["high_limit_spatial_native_profile_v2.py"] == value["native_policy_sha256"], "Actual HL native source/config differs from approval")
    require(cfg["dependencies"].get("bth_qa_selected_source_v2.py") == "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625" and
            sha(sys.executable) == cfg["python_sha256"], "Actual captured native selected helper/Python differs")
    for name, expected in cfg["dependencies"].items():
        require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9_.-]+", name) and sha(NATIVE_TOOLS / name) == expected,
                "Captured native dependency byte changed: " + str(name))
    for phase in NATIVE_PHASES:
        expected = Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence/phase-result.json"
        delivered.assert_ref(records[phase], expected)
        result = native.previous(cfg, phase)
        require(result["source_commit"] == value["source_commit"] and result["source_tree"] == value["source_tree"], "HL native receipt source differs")
        if phase in ("contexts", "motion", "capture"):
            require(result["artifacts"]["sha256"] == value["native_" + phase + "_sha256"], "HL native actual report hash differs: " + phase)
        elif phase == "liveness":
            require(sha(expected.parent / "worker.log") == value["native_liveness_sha256"], "Actual no-pointer liveness log hash differs")
    identity = Path(cfg["project"]) / "highlimit_spatial_source_identity.json"
    require(sha(identity) == value["native_identity_sha256"] and
            native.previous(cfg, "identity")["artifacts"]["candidate_package_sha256"] == policy.PACKAGE_SHA,
            "Final native current-source/candidate21 identity differs")
    native.verify_identity(cfg)
    review_path = served.plain(value["final_art_review_path"])
    require(sha(review_path) == value["final_art_review_sha256"], "Final independent native/art review bytes differ")
    review = read(review_path)
    require(review.get("decision") == "GO_FOR_TEST_BUILD" and review.get("task_id") == TASK_ID and
            review.get("package_21_file_sha256") == policy.PACKAGE_SHA and review.get("source_commit") == value["source_commit"] and
            review.get("source_tree") == value["source_tree"] and review.get("independent_reviewer") == value["reviewer"] and
            review.get("native_phase_receipts") == records and review.get("production_activation_approved") is True,
            "Static/native-trial approval cannot substitute for final HL native/art GO")
    return {"source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "project": cfg["project"],
        "identity_sha256": value["native_identity_sha256"], "phase_receipts": records,
        "final_review_sha256": value["final_art_review_sha256"], "native_receipts_authenticated": True}


def load_approval(path, expected_sha):
    policy.full_hash(expected_sha)
    path = served.plain(path)
    require(path.stat().st_size <= 1024 ** 2 and sha(path) == expected_sha, "Exact bounded final HL approval document required")
    value = read(path)
    # Reject STATIC_GO before expensive baseline/native reads; there is no plan/build fallback.
    require(value.get("schema") == policy.APPROVAL_SCHEMA and value.get("verdict") == "GO_FOR_TEST_BUILD" and
            value.get("environment_id") == ENVIRONMENT, "Actual FINAL_HL_GO_FOR_TEST_BUILD is required")
    cert = baseline()
    policy.check_approval_declaration(value, cert["manifest"])
    validate_baseline_binding(value["baseline"], cert)
    require(value.get("baseline_certificate_sha256") == cert["certificate_sha256"], "Final HL GO does not bind actual baseline certificate")
    require(not delivered.same_path(value["final_art_review_path"], path), "Final native/art review must be a separate document; approval cannot hash itself")
    native = authenticate_native(value)
    return {**value, "approval_path": str(path), "approval_sha256": expected_sha, "baseline_certificate": cert,
        "native_qualification": native, "release_profile_sha256": sha(__file__), "final_HL_GO_authenticated": True}


def source_seal(workspace, approval):
    workspace = served.plain(workspace)
    cert = approval["baseline_certificate"]
    base = cert["manifest"]
    observed = {name: sha(workspace / name) for name in base["art_source_files"]}
    result = policy.check_source_hashes(base, observed)
    policy.check_import_hashes({name: sha(workspace / name) for name in policy.IMPORT_SHAS})
    policy.check_json((delivered.WORKSPACE / policy.HL_JSON).read_bytes(), (workspace / policy.HL_JSON).read_bytes())
    native_identity = read(Path(approval["native_qualification"]["project"]) / "highlimit_spatial_source_identity.json")
    code = {name: value for name, value in native_identity["files"].items() if name.startswith("native/") or
            name.startswith(("scripts/", "scenes/")) and name.endswith((".gd", ".tscn", ".tres", ".gdshader"))}
    require(all(sha(workspace / name) == expected for name, expected in code.items()), "Native/export original code source bridge differs")
    return {**result, "approval_sha256": approval["approval_sha256"], "baseline_certificate_sha256": cert["certificate_sha256"],
        "native_export_original_code_files_equal": len(code), "all421_source_hashes": observed}


def validate_selected_identity(manifest, packed_identity, actual_attributes=None):
    from bth_qa_selected_source import SCOPE
    require(manifest.get("source_archive_scope") == SCOPE and manifest.get("full_repository_archive") is False,
            "Honest partial selected-source identity required")
    for name in ("source_archive_scope", "full_repository_archive", "source_selection_sha256", "source_archive_sha256", "source_attributes_policy"):
        require(name in packed_identity and name in manifest and policy.same_typed(packed_identity[name], manifest[name]),
                "Embedded/external selected-source provenance differs: " + name)
    policy.full_hash(manifest["source_selection_sha256"])
    policy.full_hash(manifest["source_archive_sha256"])
    attributes = manifest["source_attributes_policy"]
    require(isinstance(attributes, dict) and attributes.get("actual_extracted_bytes_verified") is True and
            attributes.get("runtime_paths_or_export_directives_changed") is False and attributes.get("source_bytes_substituted") is False,
            "Actual unmodified selected-source attribute byte proof required")
    if actual_attributes is not None:
        import bth_qa_selected_source_v2 as selected
        require(sha(Path(selected.__file__)) == "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625" and
                policy.same_typed(attributes, {**selected.attributes_bytes_policy(actual_attributes), "actual_extracted_bytes_verified": True}),
                "Actual archived/extracted attribute bytes differ from exact selected_v2 policy")


def qualify_stage(stage, source_commit, source_tree, package, approval):
    from publish_environment_art_test import validate_payload
    from prepare_environment_art_build_identity import verify_embedded_identity
    stage = served.plain(stage)
    require(package == policy.PACKAGE_SHA and approval.get("final_HL_GO_authenticated") is True, "Authenticated final HL approval required")
    manifest_raw = served.small_file(stage / "build_manifest.json")
    manifest = read(stage / "build_manifest.json")
    require((manifest["source_commit"], manifest["source_tree"], manifest["art_package_sha256"], manifest["channel"]) ==
            (source_commit, source_tree, package, "test"), "Exact requested HL export identity differs")
    validate_payload(stage, source_commit, package)
    embedded = verify_embedded_identity(stage / "index.pck", manifest)
    import audit_pck_manifest
    from bar_spatial_test_build import pck_entry_bytes
    pck = (stage / "index.pck").read_bytes()
    directory = audit_pck_manifest.find_directory(pck)
    rows = {row["path"]: row for row in directory["entries"]}
    require(len(rows) == len(directory["entries"]) == 2107, "Exact retained2107 PCK resources required")
    packed_identity = policy.json_value(pck_entry_bytes(pck, directory, rows["build_manifest.json"]))
    validate_selected_identity(manifest, packed_identity, served.plain(stage.parents[2] / ".gitattributes").read_bytes())
    cert = approval["baseline_certificate"]
    strict = policy.verify_pck_delta((delivered.STAGE / "index.pck").read_bytes(), (stage / "index.pck").read_bytes(),
        cert["manifest"], manifest, delivered.PCK_SHA)
    return {"stage": str(stage), "manifest_sha256": served.digest(manifest_raw), "source_commit": source_commit,
        "source_tree": source_tree, "art_package_sha256": package, "files": len(manifest["files"]),
        "payload_bytes": sum(item["bytes"] for item in manifest["files"].values()), "embedded_pck_identity": embedded,
        "high_limit_profile": {"approval_sha256": approval["approval_sha256"], "baseline_certificate_sha256": cert["certificate_sha256"],
            "strict_pck_delta": strict, "native_qualification": approval["native_qualification"],
            "selected_source_embedded_identity_verified": True, "PCK_resources": 2107}}


def authenticate_build_verify(evidence, qualification):
    """Additional served gate: exact stage must have a closed new-HL verify Job."""
    evidence = served.plain(evidence)
    require(evidence.name == "evidence" and evidence.parent.parent == delivered.RUNS, "Closed HL build evidence must be admitted E run evidence")
    cfg = read(evidence / "build-inputs.json")
    path = NATIVE_TOOLS / "high_limit_spatial_test_build.py"
    require(sha(path) == cfg["helpers"]["high_limit_spatial_test_build.py"] and
            delivered.same_path(cfg["stage"], qualification["stage"]) and cfg["source_commit"] == qualification["source_commit"] and
            cfg["source_tree"] == qualification["source_tree"] and cfg["art_package_sha256"] == policy.PACKAGE_SHA,
            "Actual HL build helper/source/stage differs")
    spec = importlib.util.spec_from_file_location("_bth_hl_closed_build_verify", path)
    require(spec is not None and spec.loader is not None, "Exact HL build receipt validator unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    require(delivered.same_path(module.evidence(cfg, "verify"), evidence), "Not the exact closed HL verify evidence")
    module.previous(cfg, "verify")
    require(read(evidence / "worker-result.json") == qualification, "Closed HL verify result does not match actual qualified stage")
    return {"evidence": str(evidence), "job_sha256": sha(evidence / "job.json"), "phase_result_sha256": sha(evidence / "phase-result.json"),
        "worker_result_sha256": sha(evidence / "worker-result.json"), "manifest_sha256": qualification["manifest_sha256"]}
