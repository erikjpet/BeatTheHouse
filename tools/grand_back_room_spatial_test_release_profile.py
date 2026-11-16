"""Authenticated GBR-only TEST release over actual delivered HL b354.

Read-only policy; no jobs/network/publish/profile/source writes. No fallback.
The separate actual native/art review and a new build approval are mandatory.
"""
import sys
sys.dont_write_bytecode = True

import importlib.util
from pathlib import Path
import re

import grand_back_room_spatial_test_profile_v2 as policy
import high_limit_spatial_delivered_baseline as delivered
import verify_bar_spatial_test_served as served

SCHEMA = "bth.grand_back_room_spatial_test_release/v1"
SERVED_SCHEMA = "bth.grand_back_room_spatial_test_served/v1"
APPROVAL_SCHEMA = "bth.grand_back_room_spatial_test_approval/v1"
BASELINE_SCHEMA = "bth.grand_back_room_spatial_test_baseline_declaration/v1"
PURE_POLICY_SHA = "0af8ccae95bea02dbb772c02ade08e9fc25804d7bc62cbed7a38ac1f03b75574"
TASK_ID, ENVIRONMENT = policy.TASK_ID, policy.ENVIRONMENT
NATIVE_PHASES = ("source-identity", "tree", "baseline-tree", "select", "archive", "prepare", "install", "import", "identity", "contexts", "motion", "liveness", "capture")
NATIVE_TOOLS = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools")


def sha(path):
    return delivered.sha(path)


def read(path):
    return delivered.read(path)


def require(value, message):
    policy.require(value, message)


def baseline():
    require(sha(Path(policy.__file__)) == PURE_POLICY_SHA and
        sha(Path(policy.__file__).with_name("high_limit_spatial_test_profile.py")) == policy.STATELESS_POLICY_SHA,
        "Frozen pure GBRv2/stateless utility bytes changed")
    return delivered.load_certificate()


def baseline_declaration(certificate):
    """Exact declaration recipe; the certificate itself must already be authenticated."""
    return {"schema": BASELINE_SCHEMA, "source_commit": certificate["source_commit"], "source_tree": certificate["source_tree"],
        "manifest_sha256": certificate["manifest_sha256"], "pck_sha256": certificate["pck_sha256"],
        "high_limit_approval_sha256": certificate["high_limit_approval_sha256"],
        "high_limit_strict_pck_proof_sha256": delivered.canonical(certificate["strict_pck_proof"]),
        "high_limit_served_proof_sha256": certificate["served_proof_sha256"], "high_limit_served_job_sha256": certificate["served_job_sha256"],
        "high_limit_delivery_index_sha256": certificate["delivery_index_sha256"],
        "ancestor_grand_certificate_sha256": certificate["ancestor_grand_certificate_sha256"],
        "uid_cache_sha256": policy.UID_SHA, "uid_map_sha256": policy.UID_MAP_SHA, "class_cache_sha256": policy.CLASS_SHA,
        "protected_room_seals": certificate["protected19_room_seals"], "stage": str(delivered.STAGE).replace("\\", "/"),
        "high_limit_approval_path": str(delivered.APPROVAL).replace("\\", "/"),
        "high_limit_served_proof_path": str(delivered.RUNS / (delivered.PREFIX + "-served") / "evidence/served.json").replace("\\", "/"),
        "high_limit_delivery_index_path": str(delivered.DELIVERY).replace("\\", "/")}


def validate_baseline_binding(declaration, certificate):
    require(policy.same_typed(declaration, baseline_declaration(certificate)),
            "GBR approval baseline declaration differs from actual authenticated delivered HL")
    require(len(declaration["protected_room_seals"]) == 19 and ENVIRONMENT not in declaration["protected_room_seals"] and
            all(declaration["protected_room_seals"].get(name) == value for name, value in policy.PROTECTED_SEALS.items()),
            "Delivered HL/Grand/Bar protected19 map differs")


def check_approval_declaration(value, certificate):
    require(value.get("schema") == APPROVAL_SCHEMA and value.get("environment_id") == ENVIRONMENT and
        value.get("verdict") == "GO_FOR_TEST_BUILD", "Actual final GBR build approval required")
    require(value.get("approved_package_files_sha256") == policy.PAYLOAD_SHAS and
        value.get("grand_back_room_json_sha256") == policy.GBR_JSON_SHA and value.get("grand_back_room_package_sha256") == policy.PACKAGE_SHA,
        "Final GBR approval exact21 package/JSON differs")
    require(isinstance(value.get("reviewer"), str) and value["reviewer"].strip() and isinstance(value.get("evidence"), list) and
        value["evidence"] and all(isinstance(item, str) and item.strip() for item in value["evidence"]), "Final reviewer/evidence required")
    for name in ("source_commit", "source_tree"):
        policy.full_hash(value.get(name), 40)
    for name in ("native_adapter_sha256", "native_policy_sha256", "native_identity_sha256", "native_contexts_sha256", "native_motion_sha256",
                 "native_liveness_sha256", "native_capture_sha256", "native_capture_inputs_sha256", "native_source_config_sha256", "final_art_review_sha256"):
        policy.full_hash(value.get(name))
    validate_baseline_binding(value.get("baseline"), certificate)


def authenticate_native(value):
    records = value.get("native_phase_receipts")
    require(isinstance(records, dict) and set(records) == set(NATIVE_PHASES), "Exact actual thirteen GBR native phase receipts required")
    native_path = NATIVE_TOOLS / "grand_back_room_spatial_native_trial_v2.py"
    require(sha(native_path) == value["native_adapter_sha256"] == policy.NATIVE_ADAPTER_SHA and
        sha(NATIVE_TOOLS / "grand_back_room_spatial_native_profile.py") == value["native_policy_sha256"] == policy.NATIVE_POLICY_SHA,
        "Actual frozen GBR native runner/policy bytes differ")
    spec = importlib.util.spec_from_file_location("_bth_gbr_final_native_v2", native_path)
    require(spec is not None and spec.loader is not None, "Actual native runner loader unavailable")
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    inputs = read(served.plain(Path(records["identity"]["path"]).parent) / "trial-inputs.json")
    cfg = inputs["source_config"]
    require(cfg.get("schema") == "bth.grand_back_room_spatial_inputs/v1" and cfg["source_commit"] == value["source_commit"] and
        cfg["source_tree"] == value["source_tree"] and cfg["adapter_sha256"] == value["native_adapter_sha256"] and
        cfg["dependencies"].get("grand_back_room_spatial_native_profile.py") == policy.NATIVE_POLICY_SHA and
        inputs["source_config_sha256"] == value["native_source_config_sha256"], "Actual GBR native source/config differs")
    require(cfg["dependencies"].get("bth_qa_selected_source_v2.py") == policy.SELECTED_SOURCE_SHA and sha(sys.executable) == cfg["python_sha256"],
            "Actual native selected helper/Python differs")
    for name, expected in cfg["dependencies"].items():
        require(isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9_.-]+", name) and sha(NATIVE_TOOLS / name) == expected,
                "Captured GBR native dependency changed: " + str(name))
    for phase in NATIVE_PHASES:
        path = Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence/phase-result.json"
        record = records[phase]
        delivered.assert_ref(record, path)
        result = native.previous(cfg, phase)
        job = read(path.parent / "job.json")
        require(result["source_commit"] == value["source_commit"] and result["source_tree"] == value["source_tree"] and
            result["job_sha256"] == record["job_sha256"] and result["log_sha256"] == record["log_sha256"] and
            result["artifact_sha256"] == record["artifact_sha256"] and job["pid"] == record["pid"] and
            record["exit_code"] == record["active_at_release"] == 0, "Actual detailed native phase reference differs: " + phase)
        if phase in ("contexts", "motion", "capture"):
            require(result["artifacts"]["sha256"] == value["native_" + phase + "_sha256"], "Actual native report hash differs")
        elif phase == "liveness":
            require(sha(path.parent / "worker.log") == value["native_liveness_sha256"], "Actual original no-pointer liveness log differs")
    project = Path(cfg["project"])
    identity = project / "grandback_spatial_source_identity.json"
    require(sha(identity) == value["native_identity_sha256"] and sha(project / "grandback_capture_inputs.json") == value["native_capture_inputs_sha256"] and
        native.previous(cfg, "identity")["artifacts"]["candidate_package_sha256"] == policy.PACKAGE_SHA,
        "Actual current GBR source/capture/package identity differs")
    native.verify_identity(cfg)
    review_path = served.plain(value["final_art_review_path"])
    require(sha(review_path) == value["final_art_review_sha256"] == policy.NATIVE_ART_REVIEW_SHA, "Actual separate final native/art review bytes differ")
    review = read(review_path)
    policy.check_native_review_declaration(review)
    require(review["source_commit"] == value["source_commit"] and review["source_tree"] == value["source_tree"] and
        review["independent_reviewer"] == value["reviewer"] and review["native_phase_receipts"] == records and
        all(review[name] == value[name] for name in ("native_adapter_sha256", "native_policy_sha256", "native_identity_sha256", "native_contexts_sha256",
            "native_motion_sha256", "native_liveness_sha256", "native_capture_sha256", "native_capture_inputs_sha256", "native_source_config_sha256")),
        "Static/borrowed review cannot substitute for actual final GBR native/art GO")
    return {"source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "project": str(project),
        "identity_sha256": value["native_identity_sha256"], "phase_receipts": records,
        "final_review_sha256": value["final_art_review_sha256"], "native_receipts_authenticated": True}


def authenticate_release_policy_refs(value):
    refs = value.get("release_policy")
    require(isinstance(refs, dict), "Explicit actual GBR helper approval references required")
    names = (("profile", "grand_back_room_spatial_test_release_profile.py"), ("build_entrypoint", "grand_back_room_spatial_test_build.py"),
        ("served_entrypoint", "verify_grand_back_room_spatial_test_served.py"), ("baseline_loader", "high_limit_spatial_delivered_baseline.py"),
        ("pure_policy", "grand_back_room_spatial_test_profile_v2.py"))
    for key, name in names:
        require(key in refs, "Missing actual GBR approval helper reference: " + key)
        delivered.assert_ref(refs[key], NATIVE_TOOLS / name)
    return {key: refs[key] for key, name in names}


def load_approval(path, expected_sha):
    policy.full_hash(expected_sha)
    path = served.plain(path)
    require(path.stat().st_size <= 1024 ** 2 and sha(path) == expected_sha, "Exact bounded final GBR approval required")
    value = read(path)
    require(value.get("schema") == APPROVAL_SCHEMA and value.get("verdict") == "GO_FOR_TEST_BUILD" and
            value.get("environment_id") == ENVIRONMENT, "Actual FINAL_GBR_GO_FOR_TEST_BUILD is required")
    authenticate_release_policy_refs(value)
    cert = baseline()
    check_approval_declaration(value, cert)
    require(value.get("baseline_certificate_sha256") == cert["certificate_sha256"], "Final GBR GO does not bind actual HL certificate")
    require(not delivered.same_path(value["final_art_review_path"], path), "Native/art review must be a separate document, never a self-hash")
    native = authenticate_native(value)
    return {**value, "approval_path": str(path), "approval_sha256": expected_sha, "baseline_certificate": cert,
        "native_qualification": native, "release_profile_sha256": sha(__file__), "final_GBR_GO_authenticated": True}


def source_seal(workspace, approval):
    workspace = served.plain(workspace)
    base = approval["baseline_certificate"]["manifest"]
    observed = {name: sha(workspace / name) for name in base["art_source_files"]}
    result = policy.check_source_hashes(base, observed)
    policy.check_import_hashes({name: sha(workspace / name) for name in policy.IMPORT_SHAS})
    policy.check_json((delivered.WORKSPACE / policy.GBR_JSON).read_bytes(), (workspace / policy.GBR_JSON).read_bytes())
    identity = read(Path(approval["native_qualification"]["project"]) / "grandback_spatial_source_identity.json")
    code = {name: value for name, value in identity["files"].items() if name.startswith("native/") or
        name.startswith(("scripts/", "scenes/")) and name.endswith((".gd", ".tscn", ".tres", ".gdshader"))}
    require(all(sha(workspace / name) == expected for name, expected in code.items()), "Native/export original code source bridge differs")
    return {**result, "approval_sha256": approval["approval_sha256"], "baseline_certificate_sha256": approval["baseline_certificate"]["certificate_sha256"],
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
    require(package == policy.PACKAGE_SHA and approval.get("final_GBR_GO_authenticated") is True, "Authenticated final GBR approval required")
    manifest_raw = served.small_file(stage / "build_manifest.json")
    manifest = read(stage / "build_manifest.json")
    require((manifest["source_commit"], manifest["source_tree"], manifest["art_package_sha256"], manifest["channel"]) ==
            (source_commit, source_tree, package, "test"), "Exact requested GBR export identity differs")
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
        "grand_back_room_profile": {"approval_sha256": approval["approval_sha256"], "baseline_certificate_sha256": cert["certificate_sha256"],
            "strict_pck_delta": strict, "native_qualification": approval["native_qualification"],
            "selected_source_embedded_identity_verified": True, "PCK_resources": 2107}}


def authenticate_build_verify(evidence, qualification):
    """Additional served gate: exact stage must have a closed new-GBR verify Job."""
    evidence = served.plain(evidence)
    require(evidence.name == "evidence" and evidence.parent.parent == delivered.RUNS, "Closed GBR build evidence must be admitted E run evidence")
    cfg = read(evidence / "build-inputs.json")
    path = NATIVE_TOOLS / "grand_back_room_spatial_test_build.py"
    require(cfg.get("schema") == "bth.grand_back_room_test_build_inputs/v1" and
            sha(path) == cfg["helpers"]["grand_back_room_spatial_test_build.py"] and
            delivered.same_path(cfg["stage"], qualification["stage"]) and cfg["source_commit"] == qualification["source_commit"] and
            cfg["source_tree"] == qualification["source_tree"] and cfg["art_package_sha256"] == policy.PACKAGE_SHA,
            "Actual GBR build helper/source/stage differs")
    spec = importlib.util.spec_from_file_location("_bth_gbr_closed_build_verify", path)
    require(spec is not None and spec.loader is not None, "Exact GBR build receipt validator unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    require(delivered.same_path(module.evidence(cfg, "verify"), evidence), "Not the exact closed GBR verify evidence")
    module.previous(cfg, "verify")
    require(read(evidence / "worker-result.json") == qualification, "Closed GBR verify result does not match actual qualified stage")
    return {"evidence": str(evidence), "job_sha256": sha(evidence / "job.json"), "phase_result_sha256": sha(evidence / "phase-result.json"),
        "worker_result_sha256": sha(evidence / "worker-result.json"), "manifest_sha256": qualification["manifest_sha256"]}
