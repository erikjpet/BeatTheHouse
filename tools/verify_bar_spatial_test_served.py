"""Verify Bar TEST publication bytes from an already admitted guarded worker.

No child processes, publishing, browser, downloaded payload files, custom trust
roots or certificate bypasses. The caller owns bth_qa_guarded_run and its final
process/cleanup receipt. This worker writes one JSON proof in that run's evidence.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import ssl
import time
import urllib.error
import urllib.parse
import urllib.request

from bth_qa_storage import Layout, validate_layout


SCHEMA = "bth.bar_test_served/v1"
BASE_URL = "https://192.168.0.36:8443/p/beat-the-house/play/"
PLAY_ROOT = Path("D:/Projects/site/projects/beat-the-house/public/play")
MARKER = b"BTH_ART_TEST_MANAGED_LAUNCHER_V1"
TEST_ARGS = ["--", "--bth-art-test"]
TEST_MOUNT = ["/userfs/godot/app_userdata/Beat the House/distribution/web_0_6_1_art_test"]
MAX_META = 4 * 1024 ** 2
MAX_FILE = 1024 ** 3
MAX_TOTAL = 2 * 1024 ** 3
CHUNK = 1024 ** 2


class VerificationError(ValueError):
    pass


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sha_file(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for part in iter(lambda: handle.read(CHUNK), b""):
            value.update(part)
    return value.hexdigest()


def plain(path, *, exists=True):
    path = Path(path)
    if not path.is_absolute():
        raise VerificationError("Explicit absolute path required: " + str(path))
    for candidate in (path, *path.parents):
        if not candidate.exists() and not candidate.is_symlink():
            continue
        if (candidate.is_symlink() or getattr(candidate, "is_junction", lambda: False)() or
                getattr(candidate.lstat(), "st_file_attributes", 0) & 0x400):
            raise VerificationError("Link/reparse path is not admitted: " + str(candidate))
    resolved = path.resolve(strict=exists)
    if os.path.normcase(str(resolved)) != os.path.normcase(str(path)):
        raise VerificationError("Aliased/noncanonical path is not admitted: " + str(path))
    return resolved


def small_file(path, limit=MAX_META):
    path = plain(path)
    if not path.is_file() or path.stat().st_size > limit:
        raise VerificationError("Expected bounded regular input file: " + str(path))
    with path.open("rb") as handle:
        data = handle.read(limit + 1)
    if len(data) > limit:
        raise VerificationError("Input grew beyond its bound: " + str(path))
    return data


def parse_json(data, label):
    try:
        result = json.loads(data.decode("utf-8-sig"))
    except (ValueError, UnicodeError) as error:
        raise VerificationError("Invalid UTF-8 JSON: " + label) from error
    if not isinstance(result, dict):
        raise VerificationError("Expected a JSON object: " + label)
    return result


def require_hash(value, length, label):
    if not isinstance(value, str) or not re.fullmatch(r"[a-f0-9]{%d}" % length, value) or value == "0" * length:
        raise VerificationError("Expected nonzero full lowercase " + label)
    return value


def pointer(data, label):
    try:
        return require_hash(data.decode("utf-8").strip(), 40, label)
    except UnicodeError as error:
        raise VerificationError("Invalid UTF-8 pointer: " + label) from error


def load_layout():
    evidence = plain(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest_path = evidence / "storage-manifest.json"
    raw = small_file(manifest_path)
    manifest = parse_json(raw, "guarded storage manifest")
    if manifest.get("schema") != "bth-qa-storage/v1" or manifest.get("prepared") is not True:
        raise VerificationError("A fresh prepared bth_qa_guarded_run storage manifest is required")
    layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
                    **{key: manifest[key] for key in ("run_id", "token", "prepared", "expected_write_bytes", "reserve_bytes")})
    if layout.evidence.resolve(strict=True) != evidence or layout.manifest_path != manifest_path:
        raise VerificationError("Evidence environment differs from its exact prepared manifest")
    validate_layout(layout, extra_write_paths=(layout.evidence,))
    claim = parse_json(small_file(evidence / "launch-claim.json"), "guarded launch claim")
    if claim.get("manifest_sha256") != digest(raw):
        raise VerificationError("The worker has no matching guarded launch claim")
    return layout, digest(raw)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        raise VerificationError("Unexpected HTTP redirect for fixed identity endpoint: " + request.full_url)


class HTTPSBytes:
    def __init__(self, timeout):
        if os.name != "nt":
            raise VerificationError("This verifier requires Windows default TLS trust")
        if os.environ.get("SSL_CERT_FILE") or os.environ.get("SSL_CERT_DIR"):
            raise VerificationError("Custom SSL_CERT_FILE/SSL_CERT_DIR trust is not permitted")
        self.context = ssl.create_default_context(purpose=ssl.Purpose.SERVER_AUTH)
        if not self.context.check_hostname or self.context.verify_mode != ssl.CERT_REQUIRED:
            raise VerificationError("Default certificate and hostname validation must remain enabled")
        self.opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=self.context))
        self.timeout = timeout
        self.records = []

    def get(self, relative, *, limit, collect=False, expected_bytes=None, expected_sha256=None):
        url = BASE_URL + relative
        if urllib.parse.urlsplit(url).scheme != "https" or not url.startswith(BASE_URL):
            raise VerificationError("Only the fixed HTTPS publication base is permitted")
        request = urllib.request.Request(url, headers={"Accept-Encoding": "identity", "Cache-Control": "no-cache", "Pragma": "no-cache"})
        record = {"url": url, "status": "REQUESTING", "default_tls_validation": True}
        self.records.append(record)
        started = time.monotonic()
        try:
            with self.opener.open(request, timeout=self.timeout) as response:
                if response.status != 200 or response.geturl() != url:
                    raise VerificationError("Expected exact endpoint HTTP200: " + url)
                if response.headers.get("Content-Encoding", "identity").lower() not in ("", "identity"):
                    raise VerificationError("Encoded response cannot establish exact payload bytes: " + url)
                declared = response.headers.get("Content-Length")
                if declared is not None and (not declared.isdigit() or int(declared) > limit):
                    raise VerificationError("Response Content-Length exceeds its bound: " + url)
                value, count, parts = hashlib.sha256(), 0, []
                while True:
                    part = response.read(CHUNK)
                    if not part:
                        break
                    count += len(part)
                    if count > limit:
                        raise VerificationError("Stream exceeds its exact permitted size: " + url)
                    value.update(part)
                    if collect:
                        parts.append(part)
                observed_sha = value.hexdigest()
                if declared is not None and count != int(declared):
                    raise VerificationError("Response size differs from Content-Length: " + url)
                if expected_bytes is not None and count != expected_bytes:
                    raise VerificationError("Served length differs from qualified manifest: " + url)
                if expected_sha256 is not None and observed_sha != expected_sha256:
                    raise VerificationError("Served SHA256 differs from qualified manifest: " + url)
                record.update(status="VERIFIED", http_status=200, bytes=count, sha256=observed_sha,
                              elapsed_seconds=round(time.monotonic() - started, 4))
                return b"".join(parts) if collect else dict(record)
        except Exception as error:
            record.update(status="FAILED", error_type=type(error).__name__, error=str(error),
                          elapsed_seconds=round(time.monotonic() - started, 4))
            raise


def paired(client, relative, limit=MAX_META):
    name = PurePosixPath(relative)
    if name.is_absolute() or ".." in name.parts or "\\" in relative or name.as_posix() != relative:
        raise VerificationError("Invalid fixed publication-relative path")
    local_path = plain(PLAY_ROOT / relative)
    local = small_file(local_path, limit)
    remote = client.get(relative, limit=limit, collect=True, expected_bytes=len(local), expected_sha256=digest(local))
    if local != remote:
        raise VerificationError("Local and HTTPS metadata differ: " + relative)
    return local, {"local_path": str(local_path), "url": BASE_URL + relative,
                   "bytes": len(local), "sha256": digest(local), "local_equals_https": True}


def capture_state(client):
    started = utc_now()
    next_raw, next_record = paired(client, "next.json")
    next_json = parse_json(next_raw, "NEXT pointer")
    next_commit = require_hash(next_json.get("source_commit"), 40, "NEXT source commit")
    next_tree = require_hash(next_json.get("source_tree"), 40, "NEXT source tree")
    dev_raw, dev_record = paired(client, "dev/current", 4096)
    if pointer(dev_raw, "NEXT dev/current") != next_commit:
        raise VerificationError("NEXT next.json and dev/current changed or disagree")
    immutable = "dev/" + next_commit + "/build_manifest.json"
    next_manifest_raw, next_manifest_record = paired(client, immutable)
    next_manifest = parse_json(next_manifest_raw, "NEXT immutable manifest")
    if (next_manifest.get("source_commit"), next_manifest.get("source_tree")) != (next_commit, next_tree):
        raise VerificationError("NEXT immutable manifest differs from its pointers")
    test_raw, test_record = paired(client, "test/current", 4096)
    test_commit = pointer(test_raw, "TEST current")
    launcher_raw, launcher_record = paired(client, "test/index.html", 256 * 1024)
    from publish_environment_art_test import LAUNCHER
    if MARKER not in launcher_raw or launcher_raw != LAUNCHER.encode("utf-8"):
        raise VerificationError("TEST launcher bytes differ from the maintained managed launcher")
    return {"started_utc": started, "finished_utc": utc_now(),
            "next": {"source_commit": next_commit, "source_tree": next_tree,
                     "pointer": next_record, "dev_current": dev_record, "manifest": next_manifest_record},
            "test": {"source_commit": test_commit, "current": test_record,
                     "launcher": launcher_record, "managed_launcher": True}}


def qualify_stage(args, layout):
    stage = plain(args.stage)
    if stage.name != "stage" or not stage.is_relative_to(layout.workspace.resolve(strict=True)):
        raise VerificationError("Qualified stage must be an explicit stage directory inside this admitted E workspace")
    manifest_raw = small_file(stage / "build_manifest.json")
    manifest = parse_json(manifest_raw, "qualified local manifest")
    if (manifest.get("source_commit"), manifest.get("source_tree"), manifest.get("art_package_sha256"), manifest.get("channel")) != (
            args.source_commit, args.source_tree, args.art_package_sha256, "test"):
        raise VerificationError("Qualified local manifest does not match requested source/tree/Bar seal/channel")
    files = manifest.get("files")
    if not isinstance(files, dict) or not 1 <= len(files) <= 64:
        raise VerificationError("Expected a bounded Web payload file inventory")
    required = {"index.html", "index.pck", "index.js", "index.wasm", "index.side.wasm", "web-gl-handles.json"}
    if not required.issubset(files):
        raise VerificationError("Qualified manifest lacks required Web payload or maintained WebGL receipt")
    total = 0
    for relative, info in files.items():
        name = PurePosixPath(relative)
        if (not isinstance(relative, str) or not relative or name.name != relative or
                relative in (".", "..", "build_manifest.json") or "\\" in relative or ":" in relative or
                len(relative) > 128 or name.is_absolute()):
            raise VerificationError("Unsafe/non-flat payload filename")
        if not isinstance(info, dict) or type(info.get("bytes")) is not int or not 0 <= info["bytes"] <= MAX_FILE:
            raise VerificationError("Invalid bounded payload length: " + relative)
        require_hash(info.get("sha256"), 64, "payload SHA256")
        total += info["bytes"]
    if total > MAX_TOTAL:
        raise VerificationError("Payload exceeds the bounded verification inventory")
    if files["index.html"]["bytes"] > MAX_META:
        raise VerificationError("HTML exceeds the bounded metadata collection size")
    # Both helpers are maintained, read-only validators. They independently bind
    # local files and actual embedded PCK identity before any HTTPS equivalence.
    from publish_environment_art_test import validate_payload
    from prepare_environment_art_build_identity import verify_embedded_identity
    validate_payload(stage, args.source_commit, args.art_package_sha256)
    embedded = verify_embedded_identity(stage / "index.pck", manifest)
    return stage, manifest_raw, manifest, {"stage": str(stage), "manifest_sha256": digest(manifest_raw),
        "source_commit": args.source_commit, "source_tree": args.source_tree,
        "art_package_sha256": args.art_package_sha256, "files": len(files), "payload_bytes": total,
        "embedded_pck_identity": embedded}


def read_before(args, layout, qualification, source_inputs):
    path = plain(args.before_evidence)
    runs = (layout.root / "runs").resolve(strict=True)
    if path.name != "before.json" or path.parent.name != "evidence" or not path.is_relative_to(runs) or path.parent == layout.evidence:
        raise VerificationError("Before proof must be a closed prior E run's evidence/before.json")
    before = parse_json(small_file(path), "before proof")
    if (before.get("schema"), before.get("phase"), before.get("status")) != (SCHEMA, "snapshot-before", "BEFORE_SNAPSHOT_VERIFIED"):
        raise VerificationError("Prior before proof is not a successful snapshot")
    if before.get("qualified_stage") != qualification or before.get("source_inputs") != source_inputs:
        raise VerificationError("Before and after source, stage, verifier, or helper identity differs")
    job = parse_json(small_file(path.parent / "job.json"), "closed before Job receipt")
    if (job.get("exit_code") != 0 or job.get("active_at_release") != 0 or
            not job.get("assigned_before_execution") or job.get("error") or job.get("cleanup_errors") or
            job.get("timed_out") or job.get("log_error") or job.get("log_truncated") or
            "storage_gate_before_job" not in job or "storage_gate_before_child" not in job or
            job.get("limits", {}).get("cpu_rate") != 1200 or
            job.get("limits", {}).get("job_memory_limit_bytes") != 2 * 1024 ** 3):
        raise VerificationError("Before worker is not closed with a successful exact capped Job receipt")
    storage_raw = small_file(path.parent / "storage-manifest.json")
    if job.get("storage_manifest_sha256") != digest(storage_raw) or before.get("storage_manifest_sha256") != digest(storage_raw):
        raise VerificationError("Before Job/proof storage manifest custody differs")
    return before, {"path": str(path), "sha256": sha_file(path), "job_receipt_sha256": sha_file(path.parent / "job.json")}


def compare_next(before, after):
    if before["state"]["next"] == after["next"]:
        return {"status": "UNCHANGED", "unchanged": True, "source_commit": after["next"]["source_commit"]}
    status_path = plain(PLAY_ROOT / "next-status.json")
    raw = small_file(status_path)
    watcher = parse_json(raw, "independent NEXT watcher status")
    evidence = {key: watcher.get(key) for key in ("automation", "source_branch", "phase", "deployed_commit", "deployed_at", "build_finished_at", "build_log")}
    try:
        deployed = datetime.fromisoformat(str(watcher.get("deployed_at", "")).replace("Z", "+00:00"))
        first = datetime.fromisoformat(before["state"]["started_utc"])
        last = datetime.fromisoformat(after["finished_utc"])
        timely = first <= deployed <= last
    except (ValueError, TypeError):
        timely = False
    verified = (watcher.get("automation") == "enabled" and watcher.get("source_branch") == "main" and
                watcher.get("deployed_commit") == after["next"]["source_commit"] and timely)
    result = {"status": "ADVANCED_WITH_INDEPENDENT_WATCHER_EVIDENCE" if verified else "CHANGED_REQUIRES_REVIEW",
              "unchanged": False, "before_source_commit": before["state"]["next"]["source_commit"],
              "after_source_commit": after["next"]["source_commit"], "watcher_status_path": str(status_path),
              "watcher_status_sha256": digest(raw), "watcher_evidence": evidence,
              "scope": "NEXT changed; do not describe it as unchanged. Watcher evidence is separately recorded."}
    return result


def verify_after(args, client, stage, manifest_raw, manifest, before):
    state = capture_state(client)
    if state["test"]["source_commit"] != args.source_commit:
        raise VerificationError("TEST local/HTTPS current is not the exact requested source")
    relative = "test/" + args.source_commit + "/"
    served_manifest = client.get(relative + "build_manifest.json", limit=MAX_META, collect=True,
                                 expected_bytes=len(manifest_raw), expected_sha256=digest(manifest_raw))
    if served_manifest != manifest_raw:
        raise VerificationError("Served manifest bytes differ from the qualified local stage")
    remote = parse_json(served_manifest, "served immutable manifest")
    if (remote.get("source_commit"), remote.get("source_tree"), remote.get("art_package_sha256"), remote.get("channel")) != (
            args.source_commit, args.source_tree, args.art_package_sha256, "test"):
        raise VerificationError("Served manifest source/tree/Bar seal/channel differs")
    records = {}
    for name, info in sorted(manifest["files"].items()):
        encoded_name = urllib.parse.quote(name, safe="")
        is_html = name == "index.html"
        result = client.get(relative + encoded_name, limit=info["bytes"], collect=is_html,
                            expected_bytes=info["bytes"], expected_sha256=info["sha256"])
        records[name] = dict(client.records[-1])
        if is_html:
            html = result.decode("utf-8")
            matches = list(re.finditer(r"\bconst\s+GODOT_CONFIG\s*=\s*", html))
            if len(matches) != 1:
                raise VerificationError("Served HTML lacks exactly one literal Godot config")
            config, _ = json.JSONDecoder().raw_decode(html[matches[0].end():])
            if config.get("args") != TEST_ARGS or config.get("persistentPaths") != TEST_MOUNT:
                raise VerificationError("Served HTML does not use the isolated TEST arguments and mount")
    # Re-observe pointers after the full streaming pass, so a racing publication
    # cannot silently turn a verified immutable payload into a different current.
    final_state = capture_state(client)
    if final_state["test"]["source_commit"] != args.source_commit:
        raise VerificationError("TEST current changed while served payload verification was running")
    preservation = compare_next(before, final_state)
    return final_state, records, preservation


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("snapshot-before", "verify-after"))
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--source-tree", required=True)
    parser.add_argument("--art-package-sha256", required=True)
    parser.add_argument("--before-evidence", type=Path)
    parser.add_argument("--request-timeout", type=int, default=30)
    args = parser.parse_args(argv)
    layout = client = None
    report = {"schema": SCHEMA, "task_id": "BTH-ENV-SPATIAL-BAR-001", "phase": args.phase,
              "status": "FAILED", "started_utc": utc_now(), "publication_performed_by_this_worker": False,
              "browser_acceptance": "NOT_RUN; HTTPS bytes do not establish browser startup, visuals, or gameplay",
              "profiles_or_saves_accessed": False, "downloaded_payload_files_written": False}
    code = 1
    try:
        layout, manifest_sha = load_layout()
        report["storage_manifest_sha256"] = manifest_sha
        report["launcher_receipt_policy"] = {"job_receipt": str(layout.evidence / "job.json"),
            "required_cpu_rate": 1200, "required_memory_bytes": 2 * 1024 ** 3,
            "required_assigned_before_execution": True, "required_active_at_release": 0,
            "scope": "The supervisor finalizes this worker's Job receipt after exit; this proof does not assert its pending cleanup."}
        for value, length, name in ((args.source_commit, 40, "source commit"), (args.source_tree, 40, "source tree"),
                                    (args.art_package_sha256, 64, "Bar package SHA256")):
            require_hash(value, length, name)
        if not 1 <= args.request_timeout <= 60:
            raise VerificationError("Request timeout must be 1..60 seconds")
        if bool(args.before_evidence) != (args.phase == "verify-after"):
            raise VerificationError("Only verify-after requires --before-evidence")
        adapter_sha = sha_file(__file__)
        report["source_inputs"] = {"adapter": str(Path(__file__).resolve()), "adapter_sha256": adapter_sha,
            "python": sys.executable, "python_sha256": sha_file(sys.executable),
            "publisher_sha256": sha_file(Path(__file__).with_name("publish_environment_art_test.py")),
            "embedded_identity_helper_sha256": sha_file(Path(__file__).with_name("prepare_environment_art_build_identity.py")),
            "fixed_play_root": str(PLAY_ROOT), "fixed_https_base": BASE_URL}
        stage, manifest_raw, manifest, qualification = qualify_stage(args, layout)
        report["qualified_stage"] = qualification
        before = None
        if args.phase == "verify-after":
            before, before_identity = read_before(args, layout, qualification, report["source_inputs"])
            report["before_evidence"] = before_identity
        client = HTTPSBytes(args.request_timeout)
        report["tls_policy"] = {"context": "ssl.create_default_context", "platform_default_windows_trust": True,
            "custom_roots_added": False, "certificate_validation": "CERT_REQUIRED", "hostname_validation": True,
            "redirects_allowed": False, "fallback": False, "openssl_version": ssl.OPENSSL_VERSION}
        if args.phase == "snapshot-before":
            report["state"] = capture_state(client)
            report["status"] = "BEFORE_SNAPSHOT_VERIFIED"
            code = 0
        else:
            state, files, preservation = verify_after(args, client, stage, manifest_raw, manifest, before)
            report.update(state=state, files=files, next_preservation=preservation,
                          test_url=BASE_URL + "test/", immutable_url=BASE_URL + "test/" + args.source_commit + "/index.html",
                          pck_served_equals_qualified_local_embedded_identity=True)
            if preservation["status"] == "CHANGED_REQUIRES_REVIEW":
                raise VerificationError("TEST bytes verified, but NEXT changed without sufficient independent watcher evidence")
            report["status"] = ("TEST_EXACT_SERVED_BYTES_VERIFIED" if preservation["unchanged"] else
                                "TEST_EXACT_SERVED_BYTES_VERIFIED_NEXT_ADVANCED")
            code = 0
    except Exception as error:
        report.update(status="FAILED", error_type=type(error).__name__, error=str(error), fallback_attempted=False)
    finally:
        report["finished_utc"] = utc_now()
        if client is not None:
            report["requests"] = client.records
        if layout is not None:
            try:
                output = layout.evidence / ("before.json" if args.phase == "snapshot-before" else "served.json")
                validate_layout(layout, extra_write_paths=(layout.evidence,))
                if output.exists():
                    raise VerificationError("Evidence output already exists; preserve it and use a fresh run")
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
