"""Read-only certificate for ACTUAL delivered Grand Back Room e07 TEST baseline.

No configurable baseline, network, child, save/profile operation or file write.
The frozen GBR qualifier recomputes GBR from HL, HL from Grand and Grand from7b.
"""
import sys
sys.dont_write_bytecode = True

import json
import os
from pathlib import Path
from types import SimpleNamespace
import urllib.parse

import grand_back_room_spatial_test_release_profile as gbr
import grand_back_room_spatial_test_build as builder
import verify_grand_back_room_spatial_test_served as gbr_served
import grand_spatial_delivered_baseline as ancestor
import verify_bar_spatial_test_served as served
from bth_qa_selected_source import qualified_job, same_path

SCHEMA = "bth.grand_back_room_delivered_baseline_certificate/v1"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRBUILD-20261116/qa_source")
STAGE = WORKSPACE / ".tmp/web-release-e07ca928/stage"
RUNS = Path("E:/CodexQA/BTH/runs")
PREFIX = "BTH-ENV-SPATIAL-GBRBUILD-20261116-v1"
SOURCE = "e07ca9280f4eebc531ef83dd50a79d76ec51ad23"
TREE = "53f6647622e8b61a8fb50f3494887acd9e5fcd57"
PACKAGE = "e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7"
MANIFEST_SHA = "00e1251b4e4580429fb57a764831ab8a7d7ad224f81a06b671c75415e467a215"
PCK_SHA = "be8602a091e96f3f24cc146a5e611d47f493f10c06459bbb302cb701e04bd037"
APPROVAL = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/grand_back_room_spatial_v2_test_build_approval_20261116.json")
APPROVAL_SHA = "56c5aa87df2d9c214b6b888c2f1609bf573d5ca80dc50b1d0d72498f2384ff01"
NATIVE_ART_REVIEW_SHA = "dda141cafab20e7f12db27e83011aa8896cf31f3e3099890ea3463302c7163a9"
SERVED_SHA = "99d8bd4a4523b55ab289398e585cc19ef24e5ac1d0d038c3e7bb9d423d2c8d6c"
SERVED_JOB_SHA = "2b8affde049368471a804fc66ba290fe6ba129208a60f651fe0e6b325a23e09d"
STRICT_SHA = "56ba00e01a163e694078edfe84188f8ed9d424c05787660c8e1c51e09b58e602"
HL_CERTIFICATE_SHA = "c4855fca42f7b7990b853e7cd9786c2562c634d0e923b1f509e48ad819d8c465"
DELIVERY = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/grand_back_room_spatial_test_delivery_20261116.json")
DELIVERY_SHA = "a4076f22c2e7966fbe47173def682a8661a1d955075d2b4cf2c9a13efdea13ce"
BUILD_CONFIG_SHA = "8b8301356e5a13d8c05693d53a87c1f0b455d4aedb297c953241c19722a1b08d"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
require, sha, read, canonical, assert_ref = ancestor.require, ancestor.sha, ancestor.read, ancestor.canonical, ancestor.assert_ref
validate_stream_record = ancestor.validate_stream_record

HELPERS = {'audit_pck_manifest.py': '23bb8e453dd84e3bfb840f5c060c238ff408617b1893eaa02fad267ff3bfa1e4',
 'bth_qa_command_paths.py': 'bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b',
 'bth_qa_guarded_run.py': '7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e',
 'bth_qa_selected_source.py': '311ab097dd7d57ab0eacdd342b2b4e0b8f6d49af914e827c8f5adbd934c7e353',
 'bth_qa_selected_source_v2.py': '051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625',
 'bth_qa_storage.py': 'cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837',
 'grand_back_room_spatial_test_build.py': '75144acd4986c06508d07b9f824c83b714fe97e77ee7c5f0900572ebca17b022',
 'grand_back_room_spatial_test_profile_v2.py': '0af8ccae95bea02dbb772c02ade08e9fc25804d7bc62cbed7a38ac1f03b75574',
 'grand_back_room_spatial_test_release_profile.py': '306a4f49126ac7cae6caa9461834f69b629de646432d55f6d0e8262b9dc962c0',
 'grand_spatial_delivered_baseline.py': 'bf68e3aa53786b259ce63336cba175fb88be78970ec21782eeafbb964ca1f674',
 'high_limit_spatial_delivered_baseline.py': 'fe17fa193e5ce5d4df2e250f7cf5858b3500e8e2e0582d608ae75a93be27f9c1',
 'high_limit_spatial_test_profile.py': 'f001191f6a1d3f0cb7a4b05bf93d8c16898eabdc5248c8d911a983500a839e18',
 'prepare_environment_art_build_identity.py': '2a279f3f5092124cfaa719716fca024c2a9f0b764880784d632b265675b5d5fb',
 'prepare_environment_art_test_web.py': '205fef9ddacc09d980bd8661e5d5ecc28a094f6d8e55c09b6a8153b2791e50e9',
 'publish_environment_art_test.py': '665c5ad5c51f7c44575f133909e6876b10acdf1816b7c002beeb7790f560ef56',
 'verify_bar_spatial_test_served.py': 'b1190d8acb29c53ba423b11e8f67787588622132cb91da0f332c0871a819d560',
 'verify_grand_back_room_spatial_test_served.py': '64207b1fe7df14466ab88c688b94f125b88f1c89f495aa19e84dcc4d2d48007e',
 'web_gl_handles.lock.json': '1c129ff20ed33f16ba9297ef0353152c11e00aad5e84e729ec4cb5b6aad2ded0',
 'web_gl_handles.mjs': '496d770ba2d8509fd3b97ede25a5fc8edce46104c5a258009206815d750c938a',
 'web_gl_handles_allocator.txt': 'e07f1157319c45dce251b06ad9cb73cae20c96745f689ee1b7f8332390be4da8'}
COMMANDS = {'before': ['C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe',
            '-B',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/verify_grand_back_room_spatial_test_served.py',
            'snapshot-before',
            '--stage',
            'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRBUILD-20261116/qa_source/.tmp/web-release-e07ca928/stage',
            '--source-commit',
            'e07ca9280f4eebc531ef83dd50a79d76ec51ad23',
            '--source-tree',
            '53f6647622e8b61a8fb50f3494887acd9e5fcd57',
            '--art-package-sha256',
            'e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7',
            '--approval-json',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/grand_back_room_spatial_v2_test_build_approval_20261116.json',
            '--approval-sha256',
            '56c5aa87df2d9c214b6b888c2f1609bf573d5ca80dc50b1d0d72498f2384ff01',
            '--build-verify-evidence',
            'E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRBUILD-20261116-v1-verify/evidence'],
 'publish': ['C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe',
             '-B',
             'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRBUILD-20261116/qa_source/tools/publish_environment_art_test.py',
             '--stage',
             'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRBUILD-20261116/qa_source/.tmp/web-release-e07ca928/stage',
             '--source-commit',
             'e07ca9280f4eebc531ef83dd50a79d76ec51ad23',
             '--art-package',
             'e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7'],
 'served': ['C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe',
            '-B',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/tools/verify_grand_back_room_spatial_test_served.py',
            'verify-after',
            '--stage',
            'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRBUILD-20261116/qa_source/.tmp/web-release-e07ca928/stage',
            '--source-commit',
            'e07ca9280f4eebc531ef83dd50a79d76ec51ad23',
            '--source-tree',
            '53f6647622e8b61a8fb50f3494887acd9e5fcd57',
            '--art-package-sha256',
            'e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7',
            '--approval-json',
            'D:/Projects/Beat-The-House/.tmp/environment-art-layers/docs/testing/grand_back_room_spatial_v2_test_build_approval_20261116.json',
            '--approval-sha256',
            '56c5aa87df2d9c214b6b888c2f1609bf573d5ca80dc50b1d0d72498f2384ff01',
            '--build-verify-evidence',
            'E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRBUILD-20261116-v1-verify/evidence',
            '--before-evidence',
            'E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRBUILD-20261116-v1-before/evidence/before.json']}


def authenticate_job(evidence, expected_sha, entrypoint):
    """Only actual fixed HL publication/before/served Jobs, exact full argv."""
    evidence = served.plain(evidence)
    require(evidence.parent.parent == RUNS and evidence.name == "evidence" and
            evidence.parent.name.startswith(PREFIX + "-"), "Exact admitted GBR baseline evidence required")
    phase = evidence.parent.name.removeprefix(PREFIX + "-")
    require(phase in COMMANDS and sha(evidence / "job.json") == expected_sha, "Fixed closed GBR baseline Job differs")
    job, manifest, claim = (read(evidence / name) for name in ("job.json", "storage-manifest.json", "launch-claim.json"))
    require(qualified_job(job) and manifest.get("schema") == "bth-qa-storage/v1" and manifest.get("prepared") is True and
        manifest.get("expected_write_bytes") == 4 * 1024 ** 3 and manifest.get("reserve_bytes") == 20 * 1024 ** 3 and
        same_path(manifest["paths"]["workspace"], WORKSPACE) and same_path(manifest["paths"]["evidence"], evidence) and
        same_path(manifest["paths"]["run_root"], evidence.parent) and same_path(job["storage_manifest"], evidence / "storage-manifest.json") and
        job["storage_manifest_sha256"] == claim.get("manifest_sha256") == sha(evidence / "storage-manifest.json") and
        claim.get("schema") == "bth.qa_launch_claim/v1", "Closed GBR Job/storage/claim/capacity custody differs")
    command = job.get("command")
    require(command == COMMANDS[phase] and len(command) >= 3 and command[1] == "-B" and
        Path(command[2]).name == entrypoint and sha(command[2]) == HELPERS[entrypoint] and sha(command[0]) == PYTHON_SHA,
        "Actual GBR baseline command/Python/entrypoint differs")
    return job


def authenticate_indexed_job(record, evidence, entrypoint):
    require(same_path(record["evidence"], evidence), "Delivered index Job path differs")
    job = authenticate_job(evidence, record["job_sha256"], entrypoint)
    for name, key in (("worker.log", "log_sha256"), ("storage-manifest.json", "storage_manifest_sha256"),
                      ("launch-claim.json", "launch_claim_sha256")):
        require(sha(evidence / name) == record[key], "Delivered index custody changed: " + name)
    require(job["pid"] == record["pid"] and record["exit_code"] == record["active_at_release"] == 0,
            "Actual indexed GBR Job process/closure differs")
    return job


def validate_historical_window(before, report, delivery):
    """Compare actual lane observation timestamps, not enclosing worker clocks."""
    require(report["state"]["test"]["source_commit"] == SOURCE and report["state"]["test"]["managed_launcher"] is True and
        before["state"]["next"] == report["state"]["next"] and report["next_preservation"]["unchanged"] is True and
        report["next_preservation"]["source_commit"] == "6bfbecfb959b28a3148a1bafb44e85e0bee6ed0d" and
        before["state"]["started_utc"] == delivery["served_verification"]["actual_publication_observation_window"]["from"] and
        report["state"]["finished_utc"] == delivery["served_verification"]["actual_publication_observation_window"]["through"], "Historical TEST/NEXT window differs")



def validate_delivery(delivery, manifest, qualification, source_seal):
    """Compare actual indexed facts to independently recomputed immutable facts.

    This component accepts no authority declaration; load_certificate owns the
    fixed file hashes, native/build qualification and closed receipt chain.
    """
    require(delivery.get("schema") == "bth.grand_back_room_spatial_test_delivery/v1" and
        delivery.get("status") == "BOUNDED_GRAND_BACK_ROOM_REPAIR_DELIVERED_TEST" and
        delivery.get("environment_id") == "grand_casino_back_room", "Actual GBR delivered index required")
    export, built = delivery["export_identity"], delivery["strict_build"]
    require((export["source_commit"], export["source_tree"], export["manifest_sha256"], export["pck_sha256"],
        export["art_package_21_file_sha256"]) == (SOURCE, TREE, MANIFEST_SHA, PCK_SHA, PACKAGE) and
        same_path(export["stage"], STAGE), "Delivered GBR index source/stage identity differs")
    require((manifest["source_commit"], manifest["source_tree"], manifest["art_package_sha256"], manifest["channel"]) ==
        (SOURCE, TREE, PACKAGE, "test") and manifest.get("source_dirty") is False,
        "Immutable GBR manifest identity differs")
    require(export["active_art_packages"] == manifest["active_art_packages"] and
        export["doorway_packages"] == manifest["active_doorway_packages"] and len(manifest["active_art_packages"]) == 20 and
        len(manifest["active_doorway_packages"]) == 12 and manifest["active_art_packages"]["grand_casino_back_room"] == PACKAGE,
        "Delivered GBR protected20 room/12 doorway maps differ")
    require(export["source_scope"] == manifest["source_archive_scope"] == "PARTIAL_SELECTED_PATH_ARCHIVE" and
        export.get("full_repository_archive") is manifest.get("full_repository_archive") is False and
        export["source_selection_sha256"] == manifest["source_selection_sha256"] and
        export["source_archive_sha256"] == manifest["source_archive_sha256"] and
        canonical(export["actual_attributes_proof"]) == canonical(manifest["source_attributes_policy"]),
        "Honest retained partial-source selection/archive/attribute identity differs")
    require(len(manifest["art_source_files"]) == 421 and len(manifest["compiled_art_sha256"]) == 400 and
        source_seal["all421_source_hashes"] == manifest["art_source_files"] and len(manifest["files"]) == 12 and
        manifest["files"]["index.pck"]["sha256"] == PCK_SHA and
        manifest["files"]["index.pck"]["bytes"] == export["pck_bytes"], "Actual421 source/400 CTEX/payload identity differs")
    bridge = delivery["native_source_and_export_bridge"]
    native = qualification["grand_back_room_profile"]["native_qualification"]
    require(bridge["native_source_commit"] == native["source_commit"] and bridge["native_source_tree"] == native["source_tree"] and
        type(bridge["actual_original_code_files_equal"]) is int and
        source_seal["native_export_original_code_files_equal"] == bridge["actual_original_code_files_equal"] == 760 and
        type(bridge["actual_raw_source_count"]) is int and bridge["actual_raw_source_count"] == 421 and
        type(bridge["approved_changed_sources"]) is int and bridge["approved_changed_sources"] == 10 and
        bridge.get("other411_raw_sources_byte_exact") is True, "Actual760 original-code bridge differs from full421 raw-source scope")
    strict = qualification["grand_back_room_profile"]["strict_pck_delta"]
    require(canonical(strict) == built["strict_pck_delta_canonical_sha256"] == STRICT_SHA and
        canonical(built["qualified_stage"]) == canonical(qualification) and
        built["approval_sha256"] == APPROVAL_SHA and built["actual_delivered_HL_baseline_certificate_sha256"] == HL_CERTIFICATE_SHA and
        built["actual_delivered_HL_source"] == gbr.delivered.SOURCE and type(built["phase_count"]) is int and built["phase_count"] == 15 and
        strict["changed"] == built["changed_resources"] and len(strict["changed"]) == 11 and
        strict["resources"] == built["PCK_resources"] == 2107 and strict["uid_bindings"] == built["UID_mappings_verified"] == 1605 and
        strict.get("uid_cache_bytes_equal") is strict.get("class_cache_bytes_equal") is True and
        strict.get("all_scn_gdc_bytes_equal") is built.get("all_GDC_SCN_bytes_equal") is True and
        strict.get("all_other_room_and_doorway_resources_equal") is built.get("all_other_room_doorway_resources_equal") is True,
        "Actual recomputed GBR strict PCK/UID/cache/SCN/GDC or closed qualification differs")



def authenticate_build_phases(refs, cfg):
    """Authenticate all actual15 indexed Jobs and their retained artifacts."""
    require(canonical(cfg) == BUILD_CONFIG_SHA and cfg["run_prefix"] == PREFIX and
        cfg["python_sha256"] == PYTHON_SHA and cfg["baseline_certificate_sha256"] == HL_CERTIFICATE_SHA and
        all(name in HELPERS and HELPERS[name] == expected for name, expected in cfg["helpers"].items()),
        "Fixed actual GBR build config/Python/helper bindings differ")
    require(tuple(refs) == tuple(builder.PHASES), "All actual fifteen GBR phase references required")
    for phase in builder.PHASES:
        evidence = RUNS / (PREFIX + "-" + phase) / "evidence"
        record = refs[phase]
        require(same_path(record["evidence"], evidence), "GBR phase path differs")
        for name, key in (("phase-result.json", "phase_result_sha256"), ("job.json", "job_sha256"), ("worker.log", "log_sha256"),
                          ("storage-manifest.json", "storage_manifest_sha256"), ("launch-claim.json", "launch_claim_sha256")):
            require(sha(evidence / name) == record[key], "Actual closed GBR phase indexed bytes differ: " + phase + "/" + name)
        result = builder.previous(cfg, phase)
        job, storage, claim = (read(evidence / name) for name in ("job.json", "storage-manifest.json", "launch-claim.json"))
        require(result["source_commit"] == SOURCE and result["source_tree"] == TREE and result["status"] == "PASS" and
            job["pid"] == record["pid"] and record["exit_code"] == record["active_at_release"] == 0 and
            record.get("assigned_before_execution") is True and record["limits"] == job["limits"] and
            storage.get("schema") == "bth-qa-storage/v1" and storage.get("prepared") is True and
            storage.get("expected_write_bytes") == 4 * 1024 ** 3 and storage.get("reserve_bytes") == 20 * 1024 ** 3 and
            same_path(storage["paths"]["run_root"], evidence.parent) and claim.get("schema") == "bth.qa_launch_claim/v1",
            "Actual closed GBR phase process/source/storage budget differs: " + phase)


def load_certificate():
    """Qualify only actual e07/00e/be/99d8 with no network or child."""
    require(sha(DELIVERY) == DELIVERY_SHA, "Frozen actual GBR delivery index differs")
    delivery = read(DELIVERY)
    require(delivery.get("schema") == "bth.grand_back_room_spatial_test_delivery/v1" and
            delivery.get("status") == "BOUNDED_GRAND_BACK_ROOM_REPAIR_DELIVERED_TEST", "Actual GBR delivered index required")
    for name, expected in HELPERS.items():
        require(sha(Path(__file__).with_name(name)) == sha(WORKSPACE / "tools" / name) == expected,
                "Frozen GBR baseline helper changed: " + name)
    require(sha(Path(gbr.__file__)) == HELPERS["grand_back_room_spatial_test_release_profile.py"] and
        sha(Path(builder.__file__)) == HELPERS["grand_back_room_spatial_test_build.py"] and
        sha(Path(gbr_served.__file__)) == HELPERS["verify_grand_back_room_spatial_test_served.py"] and
        sha(Path(ancestor.__file__)) == HELPERS["grand_spatial_delivered_baseline.py"] and
        sha(Path(gbr.delivered.__file__)) == HELPERS["high_limit_spatial_delivered_baseline.py"], "Actual imported baseline validators differ")
    require(sha(STAGE / "build_manifest.json") == MANIFEST_SHA and sha(STAGE / "index.pck") == PCK_SHA,
            "Actual immutable delivered GBR stage differs")
    approval = gbr.load_approval(APPROVAL, APPROVAL_SHA)
    require(approval["final_art_review_sha256"] == NATIVE_ART_REVIEW_SHA and
            approval["baseline_certificate"]["certificate_sha256"] == HL_CERTIFICATE_SHA,
            "Actual GBR native/art or ancestor HL certificate differs")
    qualification = gbr.qualify_stage(STAGE, SOURCE, TREE, PACKAGE, approval)
    source_seal = gbr.source_seal(WORKSPACE, approval)
    manifest = read(STAGE / "build_manifest.json")
    strict = qualification["grand_back_room_profile"]["strict_pck_delta"]
    validate_delivery(delivery, manifest, qualification, source_seal)
    verify_evidence = RUNS / (PREFIX + "-verify") / "evidence"
    cfg = read(verify_evidence / "build-inputs.json")
    require(same_path(cfg["workspace"], WORKSPACE) and same_path(cfg["stage"], STAGE) and cfg["source_commit"] == SOURCE and
            cfg["source_tree"] == TREE and cfg["approval_sha256"] == APPROVAL_SHA, "Actual GBR build source/config differs")
    authenticate_build_phases(delivery["strict_build"]["phase_receipts"], cfg)
    require(sha(cfg["archive"]) == builder.previous(cfg, "archive")["archive_sha256"] == manifest["source_archive_sha256"],
            "Actual retained selected source archive changed")
    build_identity = gbr.authenticate_build_verify(verify_evidence, qualification)
    pe, be, se = (RUNS / (PREFIX + "-" + phase) / "evidence" for phase in ("publish", "before", "served"))
    published = delivery["publication"]
    authenticate_indexed_job(published["closed_job"], pe, "publish_environment_art_test.py")
    authenticate_indexed_job(published["before_job"], be, "verify_grand_back_room_spatial_test_served.py")
    authenticate_indexed_job(delivery["served_verification"]["closed_job"], se, "verify_grand_back_room_spatial_test_served.py")
    pub = read(pe / "worker.log")
    require(pub["source_commit"] == SOURCE and pub["art_package_sha256"] == PACKAGE and pub["build_manifest_sha256"] == MANIFEST_SHA and
            pub["files_verified"] == 13 and pub["other_lanes_touched"] is False, "Actual GBR publisher result differs")
    require(sha(se / "served.json") == SERVED_SHA and sha(se / "job.json") == SERVED_JOB_SHA and
            sha(be / "before.json") == published["before_proof_sha256"], "Actual served/before evidence differs")
    report, before = read(se / "served.json"), read(be / "before.json")
    require(report.get("schema") == gbr.SERVED_SCHEMA and report.get("phase") == "verify-after" and
        report.get("status") == "TEST_EXACT_SERVED_BYTES_VERIFIED" and report["qualified_stage"] == qualification and
        before.get("schema") == gbr.SERVED_SCHEMA and before.get("phase") == "snapshot-before" and
        before.get("status") == "BEFORE_SNAPSHOT_VERIFIED" and before["qualified_stage"] == qualification,
        "Actual closed before/served stage qualification differs")
    args = SimpleNamespace(stage=STAGE, source_commit=SOURCE, source_tree=TREE, art_package_sha256=PACKAGE,
        approval_json=APPROVAL, approval_sha256=APPROVAL_SHA, build_verify_evidence=verify_evidence, request_timeout=30)
    inputs = gbr_served.source_inputs(approval, build_identity)
    require(report["source_inputs"] == before["source_inputs"] == inputs and report.get("source_inputs_unchanged_before_after") is True,
            "Actual baseline served helper/native/approval/build inputs differ")
    gbr_served.authenticate_before_job(be / "before.json", args, SimpleNamespace(workspace=WORKSPACE), before, inputs)
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
    certificate = {"schema": SCHEMA, "status": "ACTUAL_IMMUTABLE_GRAND_BACK_ROOM_BASELINE_AUTHENTICATED", "baseline_qualified": True,
        "stage": str(STAGE), "source_commit": SOURCE, "source_tree": TREE, "manifest_sha256": MANIFEST_SHA, "pck_sha256": PCK_SHA,
        "grand_back_room_package_sha256": PACKAGE, "grand_back_room_approval_sha256": APPROVAL_SHA, "native_art_review_sha256": NATIVE_ART_REVIEW_SHA,
        "served_proof_sha256": SERVED_SHA, "served_job_sha256": SERVED_JOB_SHA, "delivery_index_sha256": DELIVERY_SHA,
        "loader_sha256": sha(__file__), "frozen_helpers": dict(HELPERS), "ancestor_high_limit_certificate_sha256": HL_CERTIFICATE_SHA,
        "strict_pck_proof": strict, "manifest": manifest, "room_seals": dict(manifest["active_art_packages"]),
        "doorway_seals": manifest["active_doorway_packages"], "served_immutable_files": 13,
        "native_export_original_code_files_equal": source_seal["native_export_original_code_files_equal"],
        "source_archive_scope": manifest["source_archive_scope"], "full_repository_archive": False,
        "source_selection_sha256": manifest["source_selection_sha256"], "source_archive_sha256": manifest["source_archive_sha256"],
        "all421_raw_sources_verified": True, "compiled_art_textures": len(manifest["compiled_art_sha256"]),
        "closed_build_phases": len(builder.PHASES), "native_phase_authority": "Frozen GBR qualifier authenticates all13 original native phases; inherited HL/Grand qualification remains unchanged.",
        "browser_acceptance": "NOT_RUN", "NEXT_scope": "Historical 13:27:16..13:40:38 publication window only; current NEXT is not read or asserted."}
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
        require(layout.prepared and same_path(layout.evidence, evidence) and
            layout.expected_write_bytes == 4 * 1024 ** 3 and layout.reserve_bytes == 20 * 1024 ** 3, "Actual own admitted certificate worker manifest required")
        require(len(sys.argv) == 1, "Fixed certificate CLI accepts no baseline or other arguments")
        print(json.dumps(load_certificate(), indent=2))
        return 0
    except Exception as error:
        print(json.dumps({"schema": SCHEMA, "status": "BASELINE_CERTIFICATE_REJECTED", "error_type": type(error).__name__,
            "error": str(error), "baseline_qualified": False, "fallback_attempted": False}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
