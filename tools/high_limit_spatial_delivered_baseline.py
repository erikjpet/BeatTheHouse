"""Read-only certificate for ACTUAL delivered High Limit b354 TEST baseline.

No configurable baseline, network, child, save/profile operation or file write.
The frozen HLv2 qualifier recomputes HL from Grand and Grand from7b.
"""
import sys
sys.dont_write_bytecode = True

import json
import os
from pathlib import Path
from types import SimpleNamespace
import urllib.parse

import high_limit_spatial_test_release_profile_v2 as hl
import high_limit_spatial_test_build_v2 as builder
import verify_high_limit_spatial_test_served_v2 as hl_served
import grand_spatial_delivered_baseline as ancestor
import verify_bar_spatial_test_served as served
from bth_qa_selected_source import qualified_job, same_path

SCHEMA = "bth.high_limit_delivered_baseline_certificate/v1"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD2-20261116/qa_source")
STAGE = WORKSPACE / ".tmp/web-release-b35412ac/stage"
RUNS = Path("E:/CodexQA/BTH/runs")
PREFIX = "BTH-ENV-SPATIAL-HLBUILD2-20261116-v2"
SOURCE = "b35412ac003983e2bdce620ec9fd75f4810078cd"
TREE = "1e9e7c8e8ad2e4fa9543163bfd4d5b5d64294e0d"
PACKAGE = "481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4"
MANIFEST_SHA = "8fff3a29d0bfd41527324ace7fd55e56c4307c5027504fd30e84ca9b02e46810"
PCK_SHA = "4f0b958fb10b8e0083fad2865c830a10cd29bade6579cd88f05642a8a4bfd136"
APPROVAL = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/high_limit_spatial_v2_test_build_approval_20261116.json")
APPROVAL_SHA = "46e8685cf4dab2a49c8d0cbcda08c816612bb32614d5e1ec3798cbaf0208b1d7"
NATIVE_ART_REVIEW_SHA = "871b8e811a05b12b40da059732b0e6de94633143fa44ac0bc6cba16149ecea9b"
SERVED_SHA = "fab304ee748827a6bbec53b989284bb9df586fadbaa58e054f43b01d98610ce8"
SERVED_JOB_SHA = "4023a6f7e7f8156b786a30d0470f417965bafd143423f94af0d472869b8003b8"
STRICT_SHA = "f1d75253897b9f7dbd79a9204f5f8e2eac1e988f4237ca7c28b14614da3aba6c"
GRAND_CERTIFICATE_SHA = "c355c3fb638233016d0bb169ceb92942376db24011d1e2ef48c6443da9140356"
DELIVERY = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/high_limit_spatial_test_delivery_20261116.json")
DELIVERY_SHA = "b4650bd3538419c0242b58429d1eb84da0a75abc239ff03f659ed8b1d1552261"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
require, sha, read, canonical, assert_ref = ancestor.require, ancestor.sha, ancestor.read, ancestor.canonical, ancestor.assert_ref
validate_stream_record = ancestor.validate_stream_record

HELPERS = {'audit_pck_manifest.py': '23bb8e453dd84e3bfb840f5c060c238ff408617b1893eaa02fad267ff3bfa1e4',
 'bth_qa_command_paths.py': 'bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b',
 'bth_qa_guarded_run.py': '7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e',
 'bth_qa_selected_source.py': '311ab097dd7d57ab0eacdd342b2b4e0b8f6d49af914e827c8f5adbd934c7e353',
 'bth_qa_selected_source_v2.py': '051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625',
 'bth_qa_storage.py': 'cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837',
 'grand_spatial_delivered_baseline.py': 'bf68e3aa53786b259ce63336cba175fb88be78970ec21782eeafbb964ca1f674',
 'high_limit_spatial_test_build_v2.py': '6d8483d69f936903651026021dba39f496ab0ca948098d1d0c789d7ff1bc6ab3',
 'high_limit_spatial_test_profile.py': 'f001191f6a1d3f0cb7a4b05bf93d8c16898eabdc5248c8d911a983500a839e18',
 'high_limit_spatial_test_release_profile_v2.py': 'd770c69a3a7f30b8fea9fb219229f29fd7f68e362d95e6b87d1e376e2b4040da',
 'prepare_environment_art_build_identity.py': '2a279f3f5092124cfaa719716fca024c2a9f0b764880784d632b265675b5d5fb',
 'prepare_environment_art_test_web.py': '205fef9ddacc09d980bd8661e5d5ecc28a094f6d8e55c09b6a8153b2791e50e9',
 'publish_environment_art_test.py': '665c5ad5c51f7c44575f133909e6876b10acdf1816b7c002beeb7790f560ef56',
 'verify_bar_spatial_test_served.py': 'b1190d8acb29c53ba423b11e8f67787588622132cb91da0f332c0871a819d560',
 'verify_high_limit_spatial_test_served_v2.py': 'eb0b42d26fd534dab141c9a5da1d559279a3943aec1aca8312fe405ee6e1577c',
 'web_gl_handles.lock.json': '1c129ff20ed33f16ba9297ef0353152c11e00aad5e84e729ec4cb5b6aad2ded0',
 'web_gl_handles.mjs': '496d770ba2d8509fd3b97ede25a5fc8edce46104c5a258009206815d750c938a',
 'web_gl_handles_allocator.txt': 'e07f1157319c45dce251b06ad9cb73cae20c96745f689ee1b7f8332390be4da8'}
COMMANDS = {'before': ['C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe',
            '-B',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/verify_high_limit_spatial_test_served_v2.py',
            'snapshot-before',
            '--stage',
            'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD2-20261116/qa_source/.tmp/web-release-b35412ac/stage',
            '--source-commit',
            'b35412ac003983e2bdce620ec9fd75f4810078cd',
            '--source-tree',
            '1e9e7c8e8ad2e4fa9543163bfd4d5b5d64294e0d',
            '--art-package-sha256',
            '481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4',
            '--approval-json',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/high_limit_spatial_v2_test_build_approval_20261116.json',
            '--approval-sha256',
            '46e8685cf4dab2a49c8d0cbcda08c816612bb32614d5e1ec3798cbaf0208b1d7',
            '--build-verify-evidence',
            'E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-HLBUILD2-20261116-v2-verify/evidence'],
 'publish': ['C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe',
             '-B',
             'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD2-20261116/qa_source/tools/publish_environment_art_test.py',
             '--stage',
             'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD2-20261116/qa_source/.tmp/web-release-b35412ac/stage',
             '--source-commit',
             'b35412ac003983e2bdce620ec9fd75f4810078cd',
             '--art-package',
             '481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4'],
 'served': ['C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe',
            '-B',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/verify_high_limit_spatial_test_served_v2.py',
            'verify-after',
            '--stage',
            'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HLBUILD2-20261116/qa_source/.tmp/web-release-b35412ac/stage',
            '--source-commit',
            'b35412ac003983e2bdce620ec9fd75f4810078cd',
            '--source-tree',
            '1e9e7c8e8ad2e4fa9543163bfd4d5b5d64294e0d',
            '--art-package-sha256',
            '481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4',
            '--approval-json',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/high_limit_spatial_v2_test_build_approval_20261116.json',
            '--approval-sha256',
            '46e8685cf4dab2a49c8d0cbcda08c816612bb32614d5e1ec3798cbaf0208b1d7',
            '--build-verify-evidence',
            'E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-HLBUILD2-20261116-v2-verify/evidence',
            '--before-evidence',
            'E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-HLBUILD2-20261116-v2-before/evidence/before.json']}


def authenticate_job(evidence, expected_sha, entrypoint):
    """Only actual fixed HL publication/before/served Jobs, exact full argv."""
    evidence = served.plain(evidence)
    require(evidence.parent.parent == RUNS and evidence.name == "evidence" and
            evidence.parent.name.startswith(PREFIX + "-"), "Exact admitted HL baseline evidence required")
    phase = evidence.parent.name.removeprefix(PREFIX + "-")
    require(phase in COMMANDS and sha(evidence / "job.json") == expected_sha, "Fixed closed HL baseline Job differs")
    job, manifest, claim = (read(evidence / name) for name in ("job.json", "storage-manifest.json", "launch-claim.json"))
    require(qualified_job(job) and manifest.get("schema") == "bth-qa-storage/v1" and manifest.get("prepared") is True and
        manifest.get("expected_write_bytes") == 4 * 1024 ** 3 and manifest.get("reserve_bytes") == 20 * 1024 ** 3 and
        same_path(manifest["paths"]["workspace"], WORKSPACE) and same_path(manifest["paths"]["evidence"], evidence) and
        same_path(manifest["paths"]["run_root"], evidence.parent) and same_path(job["storage_manifest"], evidence / "storage-manifest.json") and
        job["storage_manifest_sha256"] == claim.get("manifest_sha256") == sha(evidence / "storage-manifest.json") and
        claim.get("schema") == "bth.qa_launch_claim/v1", "Closed HL Job/storage/claim/capacity custody differs")
    command = job.get("command")
    require(command == COMMANDS[phase] and len(command) >= 3 and command[1] == "-B" and
        Path(command[2]).name == entrypoint and sha(command[2]) == HELPERS[entrypoint] and sha(command[0]) == PYTHON_SHA,
        "Actual HL baseline command/Python/entrypoint differs")
    return job


def authenticate_indexed_job(record, evidence, entrypoint):
    require(same_path(record["evidence"], evidence), "Delivered index Job path differs")
    job = authenticate_job(evidence, record["job_sha256"], entrypoint)
    for name, key in (("worker.log", "log_sha256"), ("storage-manifest.json", "storage_manifest_sha256"),
                      ("launch-claim.json", "launch_claim_sha256")):
        require(sha(evidence / name) == record[key], "Delivered index custody changed: " + name)
    require(job["pid"] == record["pid"] and record["exit_code"] == record["active_at_release"] == 0,
            "Actual indexed HL Job process/closure differs")
    return job


def validate_historical_window(before, report, delivery):
    """Compare actual lane observation timestamps, not enclosing worker clocks."""
    require(report["state"]["test"]["source_commit"] == SOURCE and report["state"]["test"]["managed_launcher"] is True and
        before["state"]["next"] == report["state"]["next"] and report["next_preservation"]["unchanged"] is True and
        report["next_preservation"]["source_commit"] == "7a86258d81e10a0546f11569653c5be9a3b587fb" and
        before["state"]["started_utc"] == delivery["served_verification"]["observation_window_start"] and
        report["state"]["finished_utc"] == delivery["served_verification"]["observation_window_end"], "Historical TEST/NEXT window differs")


def load_certificate():
    """Qualify only actual b354/8fff/4f/fab304 with no network or child."""
    require(sha(DELIVERY) == DELIVERY_SHA, "Frozen actual HL delivery index differs")
    delivery = read(DELIVERY)
    require(delivery.get("schema") == "bth.high_limit_spatial_test_delivery/v1" and
            delivery.get("status") == "BOUNDED_HIGH_LIMIT_REPAIR_DELIVERED_TEST", "Actual HL delivered index required")
    for name, expected in HELPERS.items():
        require(sha(Path(__file__).with_name(name)) == sha(WORKSPACE / "tools" / name) == expected,
                "Frozen HL baseline helper changed: " + name)
    require(sha(Path(hl.__file__)) == HELPERS["high_limit_spatial_test_release_profile_v2.py"] and
        sha(Path(builder.__file__)) == HELPERS["high_limit_spatial_test_build_v2.py"] and
        sha(Path(hl_served.__file__)) == HELPERS["verify_high_limit_spatial_test_served_v2.py"] and
        sha(Path(ancestor.__file__)) == HELPERS["grand_spatial_delivered_baseline.py"], "Actual imported baseline validators differ")
    require(sha(STAGE / "build_manifest.json") == MANIFEST_SHA and sha(STAGE / "index.pck") == PCK_SHA,
            "Actual immutable delivered HL stage differs")
    approval = hl.load_approval(APPROVAL, APPROVAL_SHA)
    require(approval["final_art_review_sha256"] == NATIVE_ART_REVIEW_SHA and
            approval["baseline_certificate"]["certificate_sha256"] == GRAND_CERTIFICATE_SHA,
            "Actual HL native/art or ancestor Grand certificate differs")
    qualification = hl.qualify_stage(STAGE, SOURCE, TREE, PACKAGE, approval)
    source_seal = hl.source_seal(WORKSPACE, approval)
    manifest = read(STAGE / "build_manifest.json")
    strict = qualification["high_limit_profile"]["strict_pck_delta"]
    require(canonical(strict) == STRICT_SHA and len(manifest["files"]) == 12 and
            delivery["strict_build"]["actual_strict_pck_proof_sha256"] == STRICT_SHA,
            "Actual recomputed HL strict PCK proof differs")
    export = delivery["export_identity"]
    require((export["source_commit"], export["source_tree"], export["manifest_sha256"], export["pck_sha256"]) ==
            (SOURCE, TREE, MANIFEST_SHA, PCK_SHA) and same_path(export["stage"], STAGE) and
            export["active_art_packages"] == manifest["active_art_packages"] and export["doorway_packages"] == manifest["active_doorway_packages"],
            "Delivered HL index identity/protected maps differ")
    bridge = delivery["native_source_and_export_bridge"]["actual_closed_source_bridge_scalar_results"]
    require(source_seal["native_export_original_code_files_equal"] == bridge["native_export_original_code_files_equal"] == 760,
            "Actual native/export original-code source bridge differs")
    verify_evidence = RUNS / (PREFIX + "-verify") / "evidence"
    cfg = read(verify_evidence / "build-inputs.json")
    require(same_path(cfg["workspace"], WORKSPACE) and same_path(cfg["stage"], STAGE) and cfg["source_commit"] == SOURCE and
            cfg["source_tree"] == TREE and cfg["approval_sha256"] == APPROVAL_SHA, "Actual HL build source/config differs")
    refs = delivery["strict_build"]["phase_receipts"]
    require(tuple(refs) == tuple(builder.PHASES), "All actual fifteen HL phase references required")
    for phase in builder.PHASES:
        evidence = RUNS / (PREFIX + "-" + phase) / "evidence"
        record = refs[phase]
        require(same_path(record["evidence"], evidence), "HL phase path differs")
        for name, key in (("phase-result.json", "phase_result_sha256"), ("job.json", "job_sha256"), ("worker.log", "log_sha256"),
                          ("storage-manifest.json", "storage_manifest_sha256"), ("launch-claim.json", "launch_claim_sha256")):
            require(sha(evidence / name) == record[key], "Actual closed HL phase indexed bytes differ: " + phase + "/" + name)
        result = builder.previous(cfg, phase)
        require(result["source_commit"] == SOURCE and result["source_tree"] == TREE and result["status"] == "PASS",
                "Actual closed HL phase source differs")
    require(sha(cfg["archive"]) == builder.previous(cfg, "archive")["archive_sha256"] == manifest["source_archive_sha256"],
            "Actual retained selected source archive changed")
    build_identity = hl.authenticate_build_verify(verify_evidence, qualification)
    pe, be, se = (RUNS / (PREFIX + "-" + phase) / "evidence" for phase in ("publish", "before", "served"))
    published = delivery["publication"]
    authenticate_indexed_job(published["closed_job"], pe, "publish_environment_art_test.py")
    authenticate_indexed_job(published["before_job"], be, "verify_high_limit_spatial_test_served_v2.py")
    authenticate_indexed_job(delivery["served_verification"]["closed_job"], se, "verify_high_limit_spatial_test_served_v2.py")
    pub = read(pe / "worker.log")
    require(pub["source_commit"] == SOURCE and pub["art_package_sha256"] == PACKAGE and pub["build_manifest_sha256"] == MANIFEST_SHA and
            pub["files_verified"] == 13 and pub["other_lanes_touched"] is False, "Actual HL publisher result differs")
    require(sha(se / "served.json") == SERVED_SHA and sha(se / "job.json") == SERVED_JOB_SHA and
            sha(be / "before.json") == published["before_proof_sha256"], "Actual served/before evidence differs")
    report, before = read(se / "served.json"), read(be / "before.json")
    require(report.get("schema") == hl.SERVED_SCHEMA and report.get("phase") == "verify-after" and
        report.get("status") == "TEST_EXACT_SERVED_BYTES_VERIFIED" and report["qualified_stage"] == qualification and
        before.get("schema") == hl.SERVED_SCHEMA and before.get("phase") == "snapshot-before" and
        before.get("status") == "BEFORE_SNAPSHOT_VERIFIED" and before["qualified_stage"] == qualification,
        "Actual closed before/served stage qualification differs")
    args = SimpleNamespace(stage=STAGE, source_commit=SOURCE, source_tree=TREE, art_package_sha256=PACKAGE,
        approval_json=APPROVAL, approval_sha256=APPROVAL_SHA, build_verify_evidence=verify_evidence, request_timeout=30)
    inputs = hl_served.source_inputs(approval, build_identity)
    require(report["source_inputs"] == before["source_inputs"] == inputs and report.get("source_inputs_unchanged_before_after") is True,
            "Actual baseline served helper/native/approval/build inputs differ")
    hl_served.authenticate_before_job(be / "before.json", args, SimpleNamespace(workspace=WORKSPACE), before, inputs)
    assert_ref(report["before_evidence"], be / "before.json")
    require(report["before_evidence"]["job_receipt_sha256"] == sha(be / "job.json"), "Actual before closed Job hash differs")
    tls = report["tls_policy"]
    require(tls.get("context") == "ssl.create_default_context" and tls.get("platform_default_windows_trust") is True and
        tls.get("certificate_validation") == "CERT_REQUIRED" and tls.get("hostname_validation") is True and
        all(tls.get(key) is False for key in ("custom_roots_added", "redirects_allowed", "fallback")), "Actual strict default TLS proof required")
    require(report.get("pck_served_equals_qualified_local_embedded_identity") is True and set(report["files"]) == set(manifest["files"]),
            "Actual immutable served inventory differs")
    immutable = served.BASE_URL + "test/" + SOURCE + "/"
    for name, info in manifest["files"].items():
        validate_stream_record(report["files"][name], info["bytes"], info["sha256"], immutable + urllib.parse.quote(name, safe=""))
    streams = [item for item in report["requests"] if item.get("url") == immutable + "build_manifest.json"]
    require(len(streams) == 1, "Exactly one immutable manifest stream proof required")
    validate_stream_record(streams[0], (STAGE / "build_manifest.json").stat().st_size, MANIFEST_SHA, immutable + "build_manifest.json")
    validate_historical_window(before, report, delivery)
    certificate = {"schema": SCHEMA, "status": "ACTUAL_IMMUTABLE_HIGH_LIMIT_BASELINE_AUTHENTICATED", "baseline_qualified": True,
        "stage": str(STAGE), "source_commit": SOURCE, "source_tree": TREE, "manifest_sha256": MANIFEST_SHA, "pck_sha256": PCK_SHA,
        "high_limit_package_sha256": PACKAGE, "high_limit_approval_sha256": APPROVAL_SHA, "native_art_review_sha256": NATIVE_ART_REVIEW_SHA,
        "served_proof_sha256": SERVED_SHA, "served_job_sha256": SERVED_JOB_SHA, "delivery_index_sha256": DELIVERY_SHA,
        "loader_sha256": sha(__file__), "frozen_helpers": dict(HELPERS), "ancestor_grand_certificate_sha256": GRAND_CERTIFICATE_SHA,
        "strict_pck_proof": strict, "manifest": manifest, "protected19_room_seals": {
            name: value for name, value in manifest["active_art_packages"].items() if name != "grand_casino_back_room"},
        "doorway_seals": manifest["active_doorway_packages"], "served_immutable_files": 13,
        "native_export_original_code_files_equal": source_seal["native_export_original_code_files_equal"],
        "browser_acceptance": "NOT_RUN", "NEXT_scope": "Historical 11:56:22..12:02:01 publication window only; current NEXT is not read or asserted."}
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
