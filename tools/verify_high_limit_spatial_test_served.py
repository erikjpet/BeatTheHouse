"""Guarded High Limit TEST served-byte worker; no children or publishing.

Compose only frozen generic HTTPS primitives, never their room dispatchers.
Actual delivered-Grand certificate, final HL GO and closed HL build are required.
Default TLS trust only. One exclusive JSON proof in this worker's admitted E run.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import json
from pathlib import Path

import verify_bar_spatial_test_served as common
import high_limit_spatial_test_release_profile as release
import high_limit_spatial_test_profile as policy
from bth_qa_selected_source import qualified_job, same_path
from bth_qa_storage import validate_layout


def source_inputs(approval, build_identity):
    names = ("verify_high_limit_spatial_test_served.py", "high_limit_spatial_test_release_profile.py", "high_limit_spatial_test_profile.py",
        "grand_spatial_delivered_baseline.py", "high_limit_spatial_test_build.py", "verify_bar_spatial_test_served.py",
        "bth_qa_storage.py", "bth_qa_guarded_run.py", "bth_qa_command_paths.py", "bth_qa_selected_source.py", "bth_qa_selected_source_v2.py",
        "audit_pck_manifest.py", "prepare_environment_art_build_identity.py", "publish_environment_art_test.py")
    return {"helpers": {name: release.sha(Path(__file__).with_name(name)) for name in names},
        "entrypoint": str(Path(__file__).absolute()),
        "python": sys.executable, "python_sha256": release.sha(sys.executable), "approval_path": approval["approval_path"],
        "approval_sha256": approval["approval_sha256"], "baseline_certificate_sha256": approval["baseline_certificate"]["certificate_sha256"],
        "closed_HL_build_verify": build_identity, "fixed_play_root": str(common.PLAY_ROOT), "fixed_https_base": common.BASE_URL}


def authenticate_before_command(command, args, inputs):
    policy.require(isinstance(command, list) and len(command) >= 4 and command[1] == "-B" and
        same_path(command[0], inputs["python"]) and release.sha(command[0]) == inputs["python_sha256"] and
        same_path(command[2], inputs["entrypoint"]) and Path(command[2]).name == "verify_high_limit_spatial_test_served.py" and
        release.sha(command[2]) == inputs["helpers"]["verify_high_limit_spatial_test_served.py"] and command[3] == "snapshot-before",
        "Prior before Job did not execute the exact authenticated HL snapshot worker")
    expected = {"--stage": str(args.stage), "--source-commit": args.source_commit, "--source-tree": args.source_tree,
        "--art-package-sha256": args.art_package_sha256, "--approval-json": str(args.approval_json),
        "--approval-sha256": args.approval_sha256, "--build-verify-evidence": str(args.build_verify_evidence)}
    flags, index = {}, 4
    while index < len(command):
        flag, equal, value = command[index].partition("=")
        index += 1
        policy.require(flag in {*expected, "--request-timeout"} and flag not in flags, "Unexpected/repeated prior before worker flag")
        if not equal:
            policy.require(index < len(command), "Missing prior before flag value")
            value = command[index]
            index += 1
        flags[flag] = value
    policy.require(set(flags) in (set(expected), {*expected, "--request-timeout"}), "Incomplete prior HL before command")
    for key, value in expected.items():
        policy.require(same_path(flags[key], value) if key in ("--stage", "--approval-json", "--build-verify-evidence") else flags[key] == value,
            "Prior before command source/stage/approval/build differs: " + key)
    policy.require(flags.get("--request-timeout", "30") == str(args.request_timeout), "Prior before request timeout differs")


def authenticate_before_job(path, args, layout, before, inputs):
    path = common.plain(path)
    evidence = path.parent
    job = common.parse_json(common.small_file(evidence / "job.json"), "closed HL before Job")
    storage_raw = common.small_file(evidence / "storage-manifest.json")
    storage = common.parse_json(storage_raw, "before storage manifest")
    claim = common.parse_json(common.small_file(evidence / "launch-claim.json"), "before launch claim")
    policy.require(qualified_job(job) and storage.get("schema") == "bth-qa-storage/v1" and storage.get("prepared") is True and
        same_path(storage["paths"]["workspace"], layout.workspace) and same_path(storage["paths"]["evidence"], evidence) and
        same_path(storage["paths"]["run_root"], evidence.parent) and same_path(job["storage_manifest"], evidence / "storage-manifest.json") and
        claim.get("schema") == "bth.qa_launch_claim/v1" and
        common.digest(storage_raw) == job["storage_manifest_sha256"] == claim.get("manifest_sha256") == before["storage_manifest_sha256"] and
        same_path(before["launcher_receipt_policy"]["job_receipt"], evidence / "job.json"),
        "Prior HL before Job/storage/claim/workspace/evidence custody differs")
    authenticate_before_command(job["command"], args, inputs)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("snapshot-before", "verify-after"))
    for key in ("stage", "approval-json", "build-verify-evidence"):
        parser.add_argument("--" + key, type=Path, required=True)
    for key in ("source-commit", "source-tree", "art-package-sha256", "approval-sha256"):
        parser.add_argument("--" + key, required=True)
    parser.add_argument("--before-evidence", type=Path)
    parser.add_argument("--request-timeout", type=int, default=30)
    args = parser.parse_args(argv)
    layout = client = None
    code = 1
    report = {"schema": release.SERVED_SCHEMA, "task_id": policy.TASK_ID, "phase": args.phase, "status": "FAILED",
        "started_utc": common.utc_now(), "publication_performed_by_this_worker": False, "profiles_or_saves_accessed": False,
        "downloaded_payload_files_written": False, "browser_acceptance": "NOT_RUN; HTTPS byte identity does not establish browser startup, visuals or gameplay."}
    try:
        layout, manifest_sha = common.load_layout()
        report["storage_manifest_sha256"] = manifest_sha
        report["launcher_receipt_policy"] = {"job_receipt": str(layout.evidence / "job.json"), "required_cpu_rate": 1200,
            "required_memory_bytes": 2 * 1024 ** 3, "required_assigned_before_execution": True, "required_active_at_release": 0,
            "scope": "Supervisor must authenticate the successful final closed Job; this worker does not claim its pending cleanup."}
        for value, length, name in ((args.source_commit, 40, "source commit"), (args.source_tree, 40, "source tree"),
                (args.art_package_sha256, 64, "HL package"), (args.approval_sha256, 64, "final HL approval")):
            common.require_hash(value, length, name)
        policy.require(args.art_package_sha256 == policy.PACKAGE_SHA and 1 <= args.request_timeout <= 60 and
            bool(args.before_evidence) == (args.phase == "verify-after"), "Exact HL package, bounded timeout and phase-specific before proof required")
        stage = common.plain(args.stage)
        policy.require(stage.name == "stage" and stage.is_relative_to(layout.workspace.resolve(strict=True)), "Explicit qualified stage must belong to this admitted E workspace")
        approval = release.load_approval(args.approval_json, args.approval_sha256)
        qualification = release.qualify_stage(stage, args.source_commit, args.source_tree, args.art_package_sha256, approval)
        build_identity = release.authenticate_build_verify(args.build_verify_evidence, qualification)
        inputs = source_inputs(approval, build_identity)
        report.update(qualified_stage=qualification, source_inputs=inputs)
        manifest_raw = common.small_file(stage / "build_manifest.json")
        manifest = common.parse_json(manifest_raw, "qualified HL manifest")
        before = None
        if args.phase == "verify-after":
            before, identity = common.read_before(args, layout, qualification, inputs, release.SERVED_SCHEMA)
            authenticate_before_job(args.before_evidence, args, layout, before, inputs)
            report["before_evidence"] = identity
        client = common.HTTPSBytes(args.request_timeout)
        report["tls_policy"] = {"context": "ssl.create_default_context", "platform_default_windows_trust": True,
            "custom_roots_added": False, "certificate_validation": "CERT_REQUIRED", "hostname_validation": True,
            "redirects_allowed": False, "fallback": False, "openssl_version": common.ssl.OPENSSL_VERSION}
        if args.phase == "snapshot-before":
            report["state"] = common.capture_state(client)
            report["status"] = "BEFORE_SNAPSHOT_VERIFIED"
        else:
            state, files, preservation = common.verify_after(args, client, stage, manifest_raw, manifest, before)
            report.update(state=state, files=files, next_preservation=preservation,
                test_url=common.BASE_URL + "test/", immutable_url=common.BASE_URL + "test/" + args.source_commit + "/index.html",
                pck_served_equals_qualified_local_embedded_identity=True)
            policy.require(preservation["status"] != "CHANGED_REQUIRES_REVIEW", "TEST bytes verified; NEXT changed without sufficient independent watcher evidence")
            report["status"] = "TEST_EXACT_SERVED_BYTES_VERIFIED" if preservation["unchanged"] else "TEST_EXACT_SERVED_BYTES_VERIFIED_NEXT_ADVANCED"
        # Recheck all source/approval/baseline/build inputs after the complete
        # streaming observation. No cache substitutes for actual input custody.
        after_approval = release.load_approval(args.approval_json, args.approval_sha256)
        after_qualification = release.qualify_stage(stage, args.source_commit, args.source_tree, args.art_package_sha256, after_approval)
        after_build = release.authenticate_build_verify(args.build_verify_evidence, after_qualification)
        policy.require(after_qualification == qualification and source_inputs(after_approval, after_build) == inputs,
            "HL stage/helper/baseline/approval/native/build input changed during served verification")
        report["source_inputs_unchanged_before_after"] = True
        code = 0
    except Exception as error:
        report.update(status="FAILED", error_type=type(error).__name__, error=str(error), fallback_attempted=False)
    finally:
        report["finished_utc"] = common.utc_now()
        if client is not None:
            report["requests"] = client.records
        if layout is not None:
            try:
                output = layout.evidence / ("before.json" if args.phase == "snapshot-before" else "served.json")
                validate_layout(layout, extra_write_paths=(layout.evidence,))
                with output.open("x", encoding="utf-8", newline="\n") as handle:
                    json.dump(report, handle, indent=2)
                    handle.write("\n")
            except Exception as error:
                report.update(status="FAILED_TO_WRITE_ADMITTED_PROOF", proof_write_error=str(error))
                code = 1
        print(json.dumps({key: report.get(key) for key in ("schema", "phase", "status", "error_type", "error", "proof_write_error", "finished_utc")}))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
