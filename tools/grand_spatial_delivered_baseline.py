"""Read-only certificate for the actually delivered Grand25cc TEST baseline.

No configurable baseline, children, network, writes or declaration-based trust.
Revalidate the real immutable stage and its pinned closed publication evidence.
"""
import sys
sys.dont_write_bytecode = True

import hashlib
import json
import os
from pathlib import Path
import urllib.parse

import grand_spatial_test_profile as grand
import verify_bar_spatial_test_served as served
import bth_qa_selected_source as caps_helper
from bth_qa_selected_source import qualified_job, same_path

SCHEMA = "bth.grand_delivered_baseline_certificate/v1"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GRANDBUILD-20261116")
STAGE = WORKSPACE / ".tmp/web-release-25cc8b27/stage"
RUNS = Path("E:/CodexQA/BTH/runs")
PREFIX = "BTH-ENV-SPATIAL-GRANDBUILD-20261116-v4"
SOURCE = "25cc8b279d35c5ec00d836db150354b77790e825"
TREE = "1cbbe22e7ff650f331ae79534b7cef97b0b88823"
PACKAGE = "563ef08fec04e980c9cb2e215b2801f3612a22dd8f8250ba6247293c12f069d4"
MANIFEST_SHA = "9fc243bc3ba07fb306e666dfe8f8866c78339a72dd32f6bf993cc7bdc8b0898b"
PCK_SHA = "7c3d56ba6d0772d78e6100822c897ee18fd2474277fe3fab9fd530ad32e0fff0"
APPROVAL_SHA = "f326256b6fdf9139d667d738069415e54a66789da86b1bb863c91f46027c9930"
SERVED_SHA = "7a0a0728646dc0712399d947ba726625973c43bf77c5827d57614ddd13b0878d"
DELIVERY = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/grand_spatial_test_delivery_20261116.json")
DELIVERY_SHA = "10c90c55cf6883b35911d7d14819a3f150a88e0fa3e60e2fecd3c4044a39325b"
HELPERS = {
    "bar_spatial_test_build.py": "bd1be0b037d77340e39efd64881b549ab6d9f4d1e726f412e9aa66adf3a4496e",
    "grand_spatial_test_profile.py": "972bd9e6fb2f8e2acf5cddd3086cd043e7789ec2d859e7f7111b6464271ca1ad",
    "grand_spatial_test_build.py": "23a4d963688598a88b0ce52cac2388707e9a86c48fa7a62ed58f8d21f4219444",
    "verify_bar_spatial_test_served.py": "b1190d8acb29c53ba423b11e8f67787588622132cb91da0f332c0871a819d560",
    "verify_grand_spatial_test_served.py": "e0276a21a351fedd8d82a1eb49c1c3974386454761b03e6c0a315249cdc89ca5",
    "publish_environment_art_test.py": "665c5ad5c51f7c44575f133909e6876b10acdf1816b7c002beeb7790f560ef56",
    "prepare_environment_art_build_identity.py": "2a279f3f5092124cfaa719716fca024c2a9f0b764880784d632b265675b5d5fb",
    "audit_pck_manifest.py": "23bb8e453dd84e3bfb840f5c060c238ff408617b1893eaa02fad267ff3bfa1e4",
    "bth_qa_storage.py": "cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
    "bth_qa_guarded_run.py": "7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
    "bth_qa_command_paths.py": "bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b",
}


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(path):
    return served.sha_file(served.plain(path))


def read(path):
    return served.parse_json(served.small_file(path), str(path))


def canonical(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def assert_ref(record, exact_path):
    require(same_path(record["path"], exact_path) and sha(exact_path) == record["sha256"], "Pinned receipt/artifact changed: " + str(exact_path))


def authenticate_job(evidence, expected_sha, entrypoint):
    """Authenticate exact closed Job/storage/claim/actual executable code inputs."""
    evidence = served.plain(evidence)
    require(evidence.parent.parent == RUNS and evidence.name == "evidence", "Exact admitted E run evidence required")
    require(sha(evidence / "job.json") == expected_sha, "Pinned closed Job bytes differ")
    job, manifest, claim = read(evidence / "job.json"), read(evidence / "storage-manifest.json"), read(evidence / "launch-claim.json")
    require(qualified_job(job) and manifest.get("schema") == "bth-qa-storage/v1" and manifest.get("prepared") is True and
            same_path(manifest["paths"]["evidence"], evidence) and same_path(manifest["paths"]["workspace"], WORKSPACE) and
            same_path(job["storage_manifest"], evidence / "storage-manifest.json") and
            job["storage_manifest_sha256"] == claim.get("manifest_sha256") == sha(evidence / "storage-manifest.json") and
            claim.get("schema") == "bth.qa_launch_claim/v1", "Closed baseline Job/storage/claim binding differs")
    command = job.get("command", [])
    require(len(command) >= 3 and command[1] == "-B" and Path(command[2]).name == entrypoint and
            sha(command[2]) == HELPERS[entrypoint] and sha(command[0]) == "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3",
            "Baseline command/Python/entrypoint bytes differ")
    return job


def validate_stream_record(record, expected_bytes, expected_sha, url):
    require(record.get("status") == "VERIFIED" and record.get("http_status") == 200 and
            record.get("default_tls_validation") is True and type(record.get("bytes")) is int and record.get("bytes") == expected_bytes and
            record.get("sha256") == expected_sha and record.get("url") == url, "Actual default-TLS stream receipt differs: " + url)


def load_certificate():
    """Qualify only the fixed actual25cc baseline; never publish or access HTTPS."""
    from publish_environment_art_test import validate_payload
    from prepare_environment_art_build_identity import verify_embedded_identity
    require(sha(DELIVERY) == DELIVERY_SHA, "Frozen delivery evidence index differs")
    require(sha(Path(grand.__file__)) == HELPERS["grand_spatial_test_profile.py"] and
            sha(Path(served.__file__)) == HELPERS["verify_bar_spatial_test_served.py"] and
            sha(Path(caps_helper.__file__)) == "311ab097dd7d57ab0eacdd342b2b4e0b8f6d49af914e827c8f5adbd934c7e353",
            "Actual imported certificate validation code differs")
    delivery = read(DELIVERY)
    for name, expected in HELPERS.items():
        require(sha(Path(__file__).with_name(name)) == expected and sha(WORKSPACE / "tools" / name) == expected,
                "Frozen baseline helper changed: " + name)
    require(sha(STAGE / "build_manifest.json") == MANIFEST_SHA and sha(STAGE / "index.pck") == PCK_SHA, "Actual immutable Grand stage differs")
    manifest = validate_payload(STAGE, SOURCE, PACKAGE)
    require(manifest["source_tree"] == TREE and len(manifest["files"]) == 12 and manifest["active_art_packages"]["bar"] == grand.BAR_SEAL,
            "Actual delivered Grand identity/inventory/Bar differs")
    embedded = verify_embedded_identity(STAGE / "index.pck", manifest)
    approval_path = WORKSPACE / "docs/testing/grand_spatial_v4_art_approval_20261116.json"
    approval = grand.load_approval(approval_path, APPROVAL_SHA)
    grand.validate_manifest(manifest, approval)
    strict = grand.verify_qualified_pck(STAGE / "index.pck", approval)
    verify_evidence = RUNS / (PREFIX + "-verify") / "evidence"
    vr = next(item for item in delivery["strict_build"]["closed_phase_receipts"] if item["phase"] == "verify")
    assert_ref(vr, verify_evidence / "phase-result.json")
    vjob = authenticate_job(verify_evidence, vr["job"]["sha256"], "bar_spatial_test_build.py")
    phase, cfg = read(verify_evidence / "phase-result.json"), read(verify_evidence / "build-inputs.json")
    require(phase.get("schema") == "bth.grand_test_build_phase/v1" and phase.get("status") == "PASS" and phase.get("phase") == "verify" and
            phase.get("config_sha256") == canonical(cfg) and cfg["source_commit"] == SOURCE and cfg["source_tree"] == TREE and
            cfg["art_package_sha256"] == PACKAGE and same_path(cfg["stage"], STAGE) and cfg["adapter_sha256"] == HELPERS["bar_spatial_test_build.py"] and
            "grand_casino" in vjob["command"], "Closed build verification/config does not bind delivered Grand")
    published = delivery["publication"]
    pe = RUNS / (PREFIX + "-publish") / "evidence"
    authenticate_job(pe, published["closed_job"]["sha256"], "publish_environment_art_test.py")
    assert_ref(published["publisher_stdout"], pe / "worker.log")
    result = read(pe / "worker.log")
    require(result["source_commit"] == SOURCE and result["art_package_sha256"] == PACKAGE and result["build_manifest_sha256"] == MANIFEST_SHA and
            result["files_verified"] == 13 and result["other_lanes_touched"] is False, "Pinned publication receipt differs")
    se, be = RUNS / (PREFIX + "-served") / "evidence", RUNS / (PREFIX + "-before") / "evidence"
    evidence = delivery["served_verification"]
    authenticate_job(se, evidence["closed_job"]["sha256"], "verify_grand_spatial_test_served.py")
    authenticate_job(be, evidence["closed_before_job"]["sha256"], "verify_grand_spatial_test_served.py")
    require(sha(se / "served.json") == SERVED_SHA, "Pinned actual Grand served proof differs")
    report, before = read(se / "served.json"), read(be / "before.json")
    assert_ref(evidence["before_proof"], be / "before.json")
    require(report.get("schema") == grand.SERVED_SCHEMA and report.get("status") == "TEST_EXACT_SERVED_BYTES_VERIFIED" and
            report.get("phase") == "verify-after" and report["qualified_stage"]["manifest_sha256"] == MANIFEST_SHA and
            report["qualified_stage"]["source_commit"] == SOURCE and report["qualified_stage"]["source_tree"] == TREE and
            report["qualified_stage"]["art_package_sha256"] == PACKAGE and
            report["qualified_stage"]["grand_profile"]["strict_pck_delta"] == strict and report["qualified_stage"]["embedded_pck_identity"] == embedded,
            "Actual served proof/stage/embedded/strict PCK identities differ")
    require(before.get("schema") == grand.SERVED_SCHEMA and before.get("status") == "BEFORE_SNAPSHOT_VERIFIED" and
            before["qualified_stage"] == report["qualified_stage"] and before["source_inputs"] == report["source_inputs"] and
            report["before_evidence"]["sha256"] == sha(be / "before.json"), "Closed before/after proof custody differs")
    source = report["source_inputs"]
    expected_fields = {"adapter_sha256": "verify_bar_spatial_test_served.py", "publisher_sha256": "publish_environment_art_test.py",
        "embedded_identity_helper_sha256": "prepare_environment_art_build_identity.py", "grand_profile_sha256": "grand_spatial_test_profile.py",
        "grand_pck_helper_sha256": "bar_spatial_test_build.py", "grand_pck_directory_parser_sha256": "audit_pck_manifest.py",
        "grand_entrypoint_sha256": "verify_grand_spatial_test_served.py"}
    require(all(source.get(field) == HELPERS[name] for field, name in expected_fields.items()) and
            source.get("grand_approval_sha256") == APPROVAL_SHA and source.get("fixed_https_base") == served.BASE_URL and
            same_path(source["fixed_play_root"], served.PLAY_ROOT), "Baseline served helper/approval/fixed-root bindings differ")
    tls = report["tls_policy"]
    require(tls.get("context") == "ssl.create_default_context" and tls.get("platform_default_windows_trust") is True and
            tls.get("certificate_validation") == "CERT_REQUIRED" and tls.get("hostname_validation") is True and
            all(tls.get(key) is False for key in ("custom_roots_added", "redirects_allowed", "fallback")), "Baseline TLS receipt is not strict default trust")
    require(report.get("pck_served_equals_qualified_local_embedded_identity") is True and set(report["files"]) == set(manifest["files"]),
            "Actual served file inventory differs")
    immutable = served.BASE_URL + "test/" + SOURCE + "/"
    for name, info in manifest["files"].items():
        validate_stream_record(report["files"][name], info["bytes"], info["sha256"], immutable + urllib.parse.quote(name, safe=""))
    manifest_records = [item for item in report["requests"] if item.get("url") == immutable + "build_manifest.json"]
    require(len(manifest_records) == 1, "Exactly one actual immutable manifest stream proof required")
    validate_stream_record(manifest_records[0], (STAGE / "build_manifest.json").stat().st_size, MANIFEST_SHA, immutable + "build_manifest.json")
    require(report["state"]["test"]["source_commit"] == SOURCE and report["state"]["test"]["managed_launcher"] is True and
            before["state"]["next"] == report["state"]["next"] and report["next_preservation"]["unchanged"] is True,
            "Historical publication current/managed launcher/NEXT evidence differs")
    certificate = {"schema": SCHEMA, "status": "ACTUAL_IMMUTABLE_GRAND_BASELINE_AUTHENTICATED", "baseline_qualified": True,
        "stage": str(STAGE), "source_commit": SOURCE, "source_tree": TREE, "manifest_sha256": MANIFEST_SHA, "pck_sha256": PCK_SHA,
        "grand_package_sha256": PACKAGE, "grand_approval_sha256": APPROVAL_SHA, "served_proof_sha256": SERVED_SHA,
        "delivery_index_sha256": DELIVERY_SHA, "loader_sha256": sha(__file__), "frozen_helpers": dict(HELPERS),
        "current_caps_helper_sha256": "311ab097dd7d57ab0eacdd342b2b4e0b8f6d49af914e827c8f5adbd934c7e353",
        "strict_pck_proof": strict, "manifest": manifest,
        "protected19_room_seals": {name: value for name, value in manifest["active_art_packages"].items() if name != "grand_casino_high_limit"},
        "doorway_seals": manifest["active_doorway_packages"], "served_immutable_files": 13,
        "browser_acceptance": "NOT_RUN", "NEXT_scope": "Historical publication interval only; current NEXT is not read or asserted."}
    return {**certificate, "certificate_sha256": canonical(certificate)}


def main():
    """JSON-only worker entrypoint; caller owns the capped Job and stdout file."""
    from bth_qa_storage import Layout, validate_layout
    try:
        evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
        record = read(evidence / "storage-manifest.json")
        layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
            **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
        validate_layout(layout)
        require(layout.prepared and same_path(layout.evidence, evidence), "Actual own admitted certificate worker manifest required")
        print(json.dumps(load_certificate(), indent=2))
        return 0
    except Exception as error:
        print(json.dumps({"schema": SCHEMA, "status": "BASELINE_CERTIFICATE_REJECTED", "error_type": type(error).__name__,
            "error": str(error), "baseline_qualified": False, "fallback_attempted": False}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
