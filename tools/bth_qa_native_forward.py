"""CJ2-only native forward admission; no save/profile contents, copies or writes.

Install as bth_qa_native_forward.py only with the separate storage-core dispatch.
Fresh Layout and browser ResidentBinding policies are not relaxed by this module.
All writers belong to the lease-owning launcher. It archives exact custody bytes,
writes CASE_IN_PROGRESS after suspended-child assignment, then writes state.json
and CLEAN_CLOSED custody only after successful capped-Job closure. Serialize new
receipts with receipt_bytes(). A failed/interrupted case remains blocked.
"""

from dataclasses import asdict, dataclass, replace
from pathlib import Path
import hashlib
import json
import os
import re
import stat

import bth_qa_storage as g


ROOT = Path(r"E:\CodexQA\BTH")
WORKSPACE = ROOT / "workspaces" / "crew-ui-261116" / "source"
BASE_SOURCE = ROOT / "workspaces" / "fix-back-alley-20261112" / "source"
CAMPAIGN_ID = "crew-fresh-cj2-261116"
ORIGIN_RUN_ROOT = ROOT / "runs" / CAMPAIGN_ID
SLOT = "CREW-FRESH-CJ2-261116"
ORIGIN_COMMIT = "6bfbecfb959b28a3148a1bafb44e85e0bee6ed0d"
PRODUCT_DIGEST = "2161dd546f16b8255b696db2a07bc6a08a3d0b432e9202c95fc890e6980650ab"
CUSTODY_PATH = WORKSPACE / "evidence" / (CAMPAIGN_ID + "-native-custody.json")
GODOT = Path(r"D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe")
PERSISTENT_LEAVES = ("profile", "save_dir", "appdata", "localappdata", "home", "cache")
PRODUCT_ROOTS = ("project.godot", "export_presets.cfg", "scripts", "scenes", "data", "assets")
CUSTODY_SCHEMA = "bth.qa_native_cj2_custody/v1"
STATE_SCHEMA = "bth.qa_native_cj2_state/v1"
MAX_QA_JSON_BYTES = 2 * 1024 * 1024
MAX_QA_FILE_BYTES = 16 * 1024 * 1024
MAX_CHAIN = 256
ORIGIN_HASHES = {
    "storage-manifest.json": "e6d9e9b7a7e8f203818c56be9797595dc361a58e6f2307c233f0e4a38ef568db",
    "fresh-profile-origin.json": "b748c4dc2a4f96450461e485b180022511122f344ac1ca4109a19621aa2e59e5",
    "fresh-launch-result.json": "34efe44d6cf91a8b088223078ced507bca19db1cfc870e82ed8884041f5e43be",
    "source-files.json": "84212015837cccef54fd0604f2863445356a9158da536b1538005d01194d2513",
    "job.json": "f0cb40ea61d454f1e06e8d1422aa4abdd69258a389ac4d4c2eed99ef37b95853",
    "campaign-result.json": "36c28c70fd5a024b6a1a7b97999dd142ecac5ce8b6158ad378bf50a412cb5c20",
    "worker.log": "0861be68deba297ac00d07acf7e81e5f675dad43fad3c0b2522f5825535b6797",
}
_leases = {}
_lease_profiles = {}
_lease_bindings = {}
_lease_layouts = {}


@dataclass(frozen=True)
class Cj2NativeBinding:
    campaign_id: str
    autosave_slot: str
    expected_commit: str
    workspace: str
    origin_run_root: str
    custody: str
    product_inputs_sha256: str
    persistent_paths: tuple
    directory_identities: tuple
    metadata_hashes: tuple
    last_case: str
    last_output: str
    previous_campaign_sha256: str
    mutex_name: str

    def as_dict(self):
        value = asdict(self)
        value["persistent_paths"] = dict(self.persistent_paths)
        value["directory_identities"] = {name: list(identity) for name, identity in self.directory_identities}
        value["metadata_hashes"] = dict(self.metadata_hashes)
        return value


def receipt_bytes(value):
    return (json.dumps(value, indent=2) + "\n").encode("utf-8")


def _fail(code, path, message, layout=None):
    g._fail("native_" + code, path, message, layout)


def _hash_text(value):
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _case(value):
    return isinstance(value, str) and re.fullmatch(r"crew-native-[a-z0-9][a-z0-9_-]{0,67}", value) is not None


def _same(left, right):
    return g._key(left) == g._key(right)


def _paths():
    return {name: str(ORIGIN_RUN_ROOT / name) for name in PERSISTENT_LEAVES}


def _plain_file(path, bound):
    path = g._path(path)
    g._inspect(path.parent)
    if g._probe(path) != (True, False, False):
        _fail("receipt_invalid", path, "plain owned QA evidence file required")
    if path.stat().st_size > bound:
        _fail("receipt_bound", path, "owned QA evidence exceeds its read bound")
    return path


def _owned_json(path):
    path = _plain_file(path, MAX_QA_JSON_BYTES)
    with path.open("rb") as stream:
        raw = stream.read(MAX_QA_JSON_BYTES + 1)
    if len(raw) > MAX_QA_JSON_BYTES:
        _fail("receipt_bound", path, "QA JSON grew beyond its read bound")
    try:
        value = json.loads(raw)
    except (ValueError, UnicodeError):
        _fail("receipt_invalid", path, "valid owned QA JSON required")
    if not isinstance(value, dict):
        _fail("receipt_invalid", path, "QA JSON object required")
    return value, hashlib.sha256(raw).hexdigest()


def _file_hash(path):
    path = _plain_file(path, MAX_QA_FILE_BYTES)
    digest = hashlib.sha256()
    total = 0
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            total += len(block)
            if total > MAX_QA_FILE_BYTES:
                _fail("receipt_bound", path, "QA evidence grew beyond its read bound")
            digest.update(block)
    return digest.hexdigest()


def _dir_identity(path):
    g._inspect(path)
    if g._probe(path) != (True, True, False):
        _fail("directory_invalid", path, "existing plain native directory required")
    info = os.stat(path, follow_symlinks=False)
    if not stat.S_ISDIR(info.st_mode) or info.st_ino <= 0:
        _fail("directory_identity", path, "stable native directory identity required")
    return (info.st_dev, info.st_ino)


def _current_head():
    marker = _plain_file(WORKSPACE / ".git", 1024)
    text = marker.read_text(encoding="utf-8").strip()
    if not text.startswith("gitdir: "):
        _fail("source_identity", marker, "exact linked source checkout required")
    directory = g._path(text.removeprefix("gitdir: "))
    parent = BASE_SOURCE / ".git" / "worktrees"
    if not g._inside(parent, directory):
        _fail("source_identity", directory, "linked checkout metadata owner differs")
    g._inspect(directory)
    if not _same(directory.resolve(strict=True), directory):
        _fail("source_identity", directory, "linked metadata aliases are forbidden")
    head = _plain_file(directory / "HEAD", 128).read_text(encoding="ascii").strip()
    if not re.fullmatch(r"[0-9a-f]{40}", head):
        _fail("source_identity", directory, "explicit detached commit required")
    return head


def _current_product_digest():
    # Only declared source inputs are read. Native persistence directories are
    # never enumerated, hashed, opened or decoded by this module.
    rows = []
    for root_name in PRODUCT_ROOTS:
        pending = [WORKSPACE / root_name]
        while pending:
            path = pending.pop()
            exists, directory, reparse = g._probe(path)
            if not exists or reparse:
                _fail("source_input", path, "plain existing product input required")
            if directory:
                pending.extend(sorted(path.iterdir(), reverse=True))
            else:
                digest = hashlib.sha256()
                with path.open("rb") as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        digest.update(block)
                rows.append([path.relative_to(WORKSPACE).as_posix(), path.stat().st_size, digest.hexdigest()])
    rows.sort(key=lambda row: row[0])
    return hashlib.sha256(json.dumps(rows, separators=(",", ":")).encode("utf-8")).hexdigest()


def _argument(command, name):
    values = []
    if not isinstance(command, list) or not all(isinstance(value, str) for value in command):
        _fail("job_identity", name, "explicit native command required")
    for index, value in enumerate(command):
        if value == name:
            if index + 1 >= len(command):
                _fail("job_identity", name, "command argument has no value")
            values.append(command[index + 1])
        elif value.startswith(name + "="):
            values.append(value[len(name) + 1:])
    if len(values) != 1:
        _fail("job_identity", name, "exactly one command argument required")
    return values[0]


def _job_ok(job, output):
    limits = job.get("limits", {})
    if (job.get("schema") != "bth.qa_guarded_run/v1"
            or type(job.get("timeout_seconds")) is not int or not 1 <= job["timeout_seconds"] <= 180
            or type(job.get("exit_code")) is not int or job["exit_code"] != 0
            or type(job.get("active_at_release")) is not int or job["active_at_release"] != 0
            or job.get("timed_out") is not False or job.get("error") is not None
            or job.get("cleanup_errors") != [] or job.get("assigned_before_execution") is not True
            or job.get("log_truncated") is not False or job.get("log_error") is not None
            or not isinstance(limits, dict) or type(limits.get("cpu_rate")) is not int or limits["cpu_rate"] != 1200
            or type(limits.get("job_memory_limit_bytes")) is not int or limits["job_memory_limit_bytes"] != 2 * g.GIB
            or limits.get("aggregate_job_cpu_percent") != 12.0
            or type(limits.get("active_processes")) is not int or limits["active_processes"] != 0
            or limits.get("kill_on_close") is not True or limits.get("breakaway_allowed") is not False):
        _fail("job_not_closed", output, "successful assigned capped native Job closure required")
    command = job.get("command")
    if (not isinstance(command, list) or not command or not _same(command[0], GODOT)
            or "--headless" not in command or not _same(_argument(command, "--path"), WORKSPACE)
            or _argument(command, "--autosave-slot") != SLOT
            or not _same(_argument(command, "--evidence-output"), output / "campaign-result.json")):
        _fail("job_identity", output, "native executable, source, slot or output differs")
    script = g._path(_argument(command, "--script"))
    if not g._inside(output.parent / "temp", script) or script.suffix.lower() != ".gd":
        _fail("job_identity", script, "case-owned native worker script required")
    return script


def _campaign_ok(campaign, previous=None):
    facts = campaign.get("facts", {})
    save = facts.get("final_save", {}) if isinstance(facts, dict) else {}
    if (type(campaign.get("checks")) is not int or campaign["checks"] <= 0
            or campaign.get("failures") != [] or not isinstance(facts, dict)
            or facts.get("slot") != SLOT or not isinstance(facts.get("final"), dict) or not facts["final"]
            or not isinstance(save, dict) or save.get("slot_id") != SLOT
            or not all(save.get(key) is True for key in ("has_loadable", "primary_exists", "primary_loadable"))
            or save.get("primary_corrupt") is not False):
        _fail("campaign_not_saved", SLOT, "passing actual same-slot native output and saved final state required")
    if previous is not None:
        forward = campaign.get("native_forward", {})
        if (not isinstance(forward, dict)
                or forward.get("previous_case") != previous["last_case"]
                or forward.get("previous_campaign_sha256") != previous["receipt_hashes"]["campaign"]
                or not all(forward.get(key) is True for key in
                           ("prior_state_matched", "save_completed", "closed", "completed"))
                or "inflight" not in forward or forward["inflight"] is not None
                or "error" not in forward or forward["error"] is not None):
            _fail("forward_state_unproven", SLOT, "actual prior-state match and completed native save/worker boundary required")


def _origin_metadata():
    documents, hashes = {}, {}
    output = ORIGIN_RUN_ROOT / "evidence"
    for name, expected in ORIGIN_HASHES.items():
        if name.endswith(".json"):
            value, digest = _owned_json(output / name)
            documents[name] = value
        else:
            digest = _file_hash(output / name)
        if digest != expected:
            _fail("origin_changed", output / name, "exact original CJ2 QA evidence differs")
        hashes[name] = digest
    manifest = documents["storage-manifest.json"]
    origin = documents["fresh-profile-origin.json"]
    result = documents["fresh-launch-result.json"]
    sources = documents["source-files.json"]
    if (manifest.get("schema") != "bth-qa-storage/v1" or manifest.get("prepared") is not True
            or manifest.get("run_id") != CAMPAIGN_ID
            or not all(_same(manifest.get("paths", {}).get(name, ""), ORIGIN_RUN_ROOT / name) for name in g._LEAVES)
            or not _same(manifest.get("paths", {}).get("workspace", ""), WORKSPACE)
            or origin.get("schema") != "bth.crew_fresh_native/v1"
            or origin.get("run_id") != CAMPAIGN_ID or origin.get("autosave_slot") != SLOT
            or origin.get("source_commit") != ORIGIN_COMMIT
            or not all(origin.get(key) is False for key in
                       ("historical_profiles_read", "profile_copy_performed", "profile_resume_performed"))
            or not all(origin.get("empty_before_worker", {}).get(name, {}).get("empty") is True
                       for name in ("profile", "save_dir", "appdata", "localappdata"))
            or result.get("schema") != "bth.crew_fresh_native_result/v1"
            or result.get("source_commit") != ORIGIN_COMMIT or result.get("source_commit_after") != ORIGIN_COMMIT
            or result.get("autosave_slot") != SLOT or result.get("closure_ok") is not True
            or result.get("product_inputs_unchanged") is not True or result.get("copied_script_unchanged") is not True
            or result.get("product_inputs_before_sha256") != PRODUCT_DIGEST
            or result.get("product_inputs_after_sha256") != PRODUCT_DIGEST
            or result.get("worker_log_sha256") != hashes["worker.log"]
            or sources.get("source_commit") != ORIGIN_COMMIT
            or sources.get("product_inputs_before", {}).get("tree_sha256") != PRODUCT_DIGEST):
        _fail("origin_identity", ORIGIN_RUN_ROOT, "fresh CJ2 origin, source, no-copy or product identity differs")
    _job_ok(documents["job.json"], output)
    _campaign_ok(documents["campaign-result.json"])
    return documents, hashes


def _identities():
    identities = {}
    for name in PERSISTENT_LEAVES:
        identity = _dir_identity(ORIGIN_RUN_ROOT / name)
        if (not isinstance(identity, tuple) or len(identity) != 2
                or any(type(value) is not int for value in identity) or identity[0] < 0 or identity[1] <= 0):
            _fail("directory_identity", ORIGIN_RUN_ROOT / name, "typed stable native directory identity required")
        identities[name] = list(identity)
    return identities


def _common(identities):
    return {"schema": CUSTODY_SCHEMA, "campaign_id": CAMPAIGN_ID, "autosave_slot": SLOT,
            "origin_run_root": str(ORIGIN_RUN_ROOT), "workspace": str(WORKSPACE),
            "persistent_paths": _paths(), "directory_identities": identities,
            "product_inputs_sha256": PRODUCT_DIGEST}


def _origin_closed(identities, hashes):
    return {**_common(identities), "status": "CLEAN_CLOSED", "last_case": CAMPAIGN_ID,
            "last_kind": "fresh_origin", "last_output": str(ORIGIN_RUN_ROOT / "evidence"),
            "last_source_commit": ORIGIN_COMMIT,
            "receipt_hashes": {"job": hashes["job.json"], "state": hashes["fresh-launch-result.json"],
                               "campaign": hashes["campaign-result.json"], "worker_log": hashes["worker.log"]},
            "previous_custody_path": None, "previous_custody_sha256": None}


def _source_ok(expected_commit):
    if not isinstance(expected_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", expected_commit):
        _fail("source_identity", expected_commit, "explicit current source commit required")
    if _current_head() != expected_commit:
        _fail("source_identity", WORKSPACE, "current linked HEAD differs from the admitted commit")
    if _current_product_digest() != PRODUCT_DIGEST:
        _fail("product_changed", WORKSPACE, "current product inputs differ from original CJ2; no compatibility waiver")


def bootstrap_custody(expected_commit):
    """Return an honest initial receipt; root must install with exclusive 'xb'.

    Never replace an existing custody record with a newly generated origin.
    The exclusive initial writer closes the race after this read-only check.
    """
    if g._probe(CUSTODY_PATH)[0]:
        _fail("bootstrap_occupied", CUSTODY_PATH, "native custody already exists; never reset its chain")
    _source_ok(expected_commit)
    _, hashes = _origin_metadata()
    return _origin_closed(_identities(), hashes)


def _check_common(record, identities):
    recorded_ids = record.get("directory_identities")
    if (not isinstance(recorded_ids, dict) or set(recorded_ids) != set(PERSISTENT_LEAVES)
            or any(not isinstance(value, list) or len(value) != 2
                   or any(type(part) is not int for part in value) for value in recorded_ids.values())):
        _fail("custody_identity", CUSTODY_PATH, "typed native directory identities required")
    for name, expected in _common(identities).items():
        if record.get(name) != expected:
            _fail("custody_identity", CUSTODY_PATH, "native campaign, paths, directory identities or product differs")
    if record.get("status") != "CLEAN_CLOSED":
        _fail("not_closed", CUSTODY_PATH, "native custody is not CLEAN_CLOSED; no recovery/replay policy exists")


def _collect_chain(record, identities, origin_hashes, tracked, seen=None, depth=0):
    if depth >= MAX_CHAIN:
        _fail("chain_bound", CUSTODY_PATH, "native custody chain exceeds admission bound")
    seen = set() if seen is None else seen
    _check_common(record, identities)
    if record.get("last_kind") == "fresh_origin":
        if record != _origin_closed(identities, origin_hashes):
            _fail("custody_identity", CUSTODY_PATH, "initial custody must identify the actual original fresh CJ2 case")
        return
    case = record.get("last_case")
    if record.get("last_kind") != "native_forward" or not _case(case) or case in seen:
        _fail("chain_invalid", CUSTODY_PATH, "unique native-forward case chain required")
    seen.add(case)
    output = ROOT / "runs" / case / "evidence"
    prior_path = output / "native-custody-before.json"
    if not _same(record.get("last_output", ""), output) or not _same(record.get("previous_custody_path", ""), prior_path):
        _fail("chain_invalid", output, "case or archived native predecessor path differs")
    previous, prior_hash = _owned_json(prior_path)
    tracked[str(prior_path)] = prior_hash
    if record.get("previous_custody_sha256") != prior_hash:
        _fail("chain_changed", prior_path, "archived predecessor custody differs")
    _collect_chain(previous, identities, origin_hashes, tracked, seen, depth + 1)
    job, job_hash = _owned_json(output / "job.json")
    state, state_hash = _owned_json(output / "state.json")
    campaign, campaign_hash = _owned_json(output / "campaign-result.json")
    log_hash = _file_hash(output / "worker.log")
    hashes = {"job": job_hash, "state": state_hash, "campaign": campaign_hash, "worker_log": log_hash}
    if record.get("receipt_hashes") != hashes:
        _fail("chain_changed", output, "native job/state/output/log evidence differs")
    script = _job_ok(job, output)
    _campaign_ok(campaign, previous)
    script_hash = _file_hash(script)
    commit = record.get("last_source_commit", "")
    if not isinstance(commit, str) or not re.fullmatch(r"[0-9a-f]{40}", commit):
        _fail("state_identity", output, "native source commit required")
    expected_state = _state_record(record, previous, hashes, commit, script_hash)
    if state != expected_state:
        _fail("state_identity", output, "flat native state receipt differs from actual successful evidence")
    tracked.update({str(output / name): digest for name, digest in
                    (("job.json", job_hash), ("state.json", state_hash),
                     ("campaign-result.json", campaign_hash), ("worker.log", log_hash))})
    tracked[str(script)] = script_hash


def _snapshot(expected_commit, custody):
    if not _same(custody, CUSTODY_PATH):
        _fail("custody_path", custody, "only the explicit CJ2 native custody path is admitted")
    _source_ok(expected_commit)
    _, origin_hashes = _origin_metadata()
    identities = _identities()
    record, custody_hash = _owned_json(CUSTODY_PATH)
    tracked = {str(CUSTODY_PATH): custody_hash}
    tracked.update({str(ORIGIN_RUN_ROOT / "evidence" / name): digest for name, digest in origin_hashes.items()})
    _collect_chain(record, identities, origin_hashes, tracked)
    mutex = "Local\\BTH-QA-Native-CJ2-" + hashlib.sha256(g._key(ORIGIN_RUN_ROOT).encode()).hexdigest()
    return Cj2NativeBinding(CAMPAIGN_ID, SLOT, expected_commit, str(WORKSPACE), str(ORIGIN_RUN_ROOT),
                           str(CUSTODY_PATH), PRODUCT_DIGEST, tuple(sorted(_paths().items())),
                           tuple(sorted((name, tuple(identity)) for name, identity in identities.items())),
                           tuple(sorted(tracked.items())), record["last_case"], record["last_output"],
                           record["receipt_hashes"]["campaign"], mutex)


def validate_structure(layout, paths):
    binding = getattr(layout, "native_binding", None)
    if type(binding) is not Cj2NativeBinding or getattr(layout, "resident_binding", None) is not None:
        _fail("binding_invalid", layout.profile, "separate typed CJ2 native binding required", layout)
    if not _same(layout.root, ROOT) or not _same(layout.workspace, WORKSPACE) or not _case(layout.run_id):
        _fail("scope", layout.run_root, "only exact CJ2 workspace/root and a fresh crew-native case are admitted", layout)
    if (binding.campaign_id != CAMPAIGN_ID or binding.autosave_slot != SLOT
            or binding.workspace != str(WORKSPACE) or binding.origin_run_root != str(ORIGIN_RUN_ROOT)
            or binding.custody != str(CUSTODY_PATH) or binding.product_inputs_sha256 != PRODUCT_DIGEST
            or dict(binding.persistent_paths) != _paths()):
        _fail("binding_invalid", layout.profile, "native binding identity differs", layout)
    for name in PERSISTENT_LEAVES:
        if not _same(paths[name], ORIGIN_RUN_ROOT / name):
            _fail("path_identity", paths[name], "persistent native leaf must remain at the exact original CJ2 path", layout)


def validate_binding(layout, require_lease=False):
    binding = getattr(layout, "native_binding", None)
    if type(binding) is not Cj2NativeBinding:
        _fail("binding_invalid", layout.profile, "typed native binding required", layout)
    validate_structure(layout, {name: getattr(layout, name) for name in PERSISTENT_LEAVES})
    if _snapshot(binding.expected_commit, Path(binding.custody)) != binding:
        _fail("binding_changed", layout.profile, "native directory identity or QA custody/evidence changed", layout)
    if require_lease and (layout.token not in _leases or _lease_profiles.get(binding.mutex_name) != layout.token
                          or _lease_bindings.get(layout.token) != binding):
        _fail("lease_required", layout.profile, "owned exclusive native lease is not held", layout)


def plan(root, workspace, run_id, *, expected_commit, custody=CUSTODY_PATH,
         expected_write_bytes=4 * g.GIB, reserve_bytes=20 * g.GIB):
    if not _same(g._path(root), ROOT) or not _same(g._path(workspace), WORKSPACE) or not _case(run_id):
        _fail("scope", run_id, "exact CJ2 source/root and a unique crew-native case required")
    base = g.plan_layout(root, workspace, run_id, expected_write_bytes, reserve_bytes)
    binding = _snapshot(expected_commit, g._path(custody))
    layout = replace(base, native_binding=binding, **{name: ORIGIN_RUN_ROOT / name for name in PERSISTENT_LEAVES})
    g.validate_layout(layout)
    return layout


def _mutex_acquire(name):
    # Reuse only the native Windows mutex primitive, never browser admission.
    from bth_qa_resident import _mutex_acquire as acquire
    return acquire(name)


def acquire_lease(layout):
    if layout.token in _leases:
        _fail("lease_duplicate", layout.profile, "native lease already held", layout)
    validate_binding(layout)
    binding = layout.native_binding
    if binding.mutex_name in _lease_profiles:
        _fail("profile_busy", layout.profile, "this process already holds the native profile", layout)
    try:
        owned, error = _mutex_acquire(binding.mutex_name)
    except OSError as error:
        _fail("lease_error", layout.profile, str(error), layout)
    if error:
        _fail("lease_abandoned" if error == "resident_lease_abandoned" else "profile_busy",
              layout.profile, "exclusive native admission unavailable; no retry/fallback", layout)
    _leases[layout.token] = owned
    _lease_profiles[binding.mutex_name] = layout.token
    _lease_bindings[layout.token] = binding
    _lease_layouts[layout.token] = layout
    try:
        validate_binding(layout, require_lease=True)
    except BaseException:
        release_lease(layout, active_owned_processes=0)
        raise


def release_lease(layout, *, active_owned_processes):
    if type(active_owned_processes) is not int or active_owned_processes != 0:
        _fail("processes_active", layout.profile, "release requires actual owned Job zero", layout)
    binding = getattr(layout, "native_binding", None)
    if (type(binding) is not Cj2NativeBinding or _lease_profiles.get(binding.mutex_name) != layout.token
            or _lease_bindings.get(layout.token) != binding):
        _fail("lease_owner_mismatch", layout.profile, "native lease belongs to another binding", layout)
    owned = _leases.get(layout.token)
    if owned is None:
        _fail("lease_required", layout.profile, "native lease absent", layout)
    api, handle = owned
    if not api.ReleaseMutex(handle):
        raise OSError("ReleaseMutex failed")
    api.CloseHandle(handle)
    del _leases[layout.token], _lease_profiles[binding.mutex_name], _lease_bindings[layout.token], _lease_layouts[layout.token]


def _leased_layout(binding):
    if type(binding) is not Cj2NativeBinding:
        _fail("binding_invalid", CUSTODY_PATH, "typed native binding required")
    token = _lease_profiles.get(binding.mutex_name)
    if token not in _leases or _lease_bindings.get(token) != binding:
        _fail("lease_required", CUSTODY_PATH, "lifecycle receipts require the owned native lease")
    return _lease_layouts[token]


def start_record(binding, newcase, output, script_hash):
    """Pure receipt builder; caller has assigned the still-suspended last child.

    Before execute, archive exact existing custody bytes at the returned archive
    path without modifying custody. Write this CASE_IN_PROGRESS record only after
    the final gate and confirmed Job assignment, then allow the worker to resume.
    """
    layout = _leased_layout(binding)
    validate_binding(layout, require_lease=True)
    output = g._path(output)
    if newcase != layout.run_id or not _case(newcase) or not _same(output, layout.evidence) or not _hash_text(script_hash):
        _fail("case_identity", output, "exact admitted native case/output/script required", layout)
    prior_path = output / "native-custody-before.json"
    previous, previous_hash = _owned_json(prior_path)
    current, current_hash = _owned_json(CUSTODY_PATH)
    if previous != current or previous_hash != current_hash or current_hash != dict(binding.metadata_hashes)[str(CUSTODY_PATH)]:
        _fail("chain_changed", prior_path, "exact predecessor custody bytes must be archived before launch", layout)
    return {**_common({name: list(value) for name, value in binding.directory_identities}),
            "status": "CASE_IN_PROGRESS", "last_case": newcase, "last_kind": "native_forward",
            "last_output": str(output), "last_source_commit": binding.expected_commit,
            "previous_custody_path": str(prior_path), "previous_custody_sha256": previous_hash,
            "script_sha256": script_hash, "lease_token": layout.token}


def _state_record(custody, previous, hashes, commit, script_hash):
    common = _common(custody["directory_identities"])
    common["schema"] = STATE_SCHEMA
    return {**common, "status": "CLEAN_CLOSED", "case_id": custody["last_case"],
            "source_commit": commit, "closed": True, "completed": True, "save_completed": True,
            "inflight": None, "error": None, "profile_copy_performed": False,
            "previous_case": previous["last_case"],
            "previous_campaign_sha256": previous["receipt_hashes"]["campaign"],
            "previous_custody_path": custody["previous_custody_path"],
            "previous_custody_sha256": custody["previous_custody_sha256"],
            "guarded_job_sha256": hashes["job"], "native_worker_result_sha256": hashes["campaign"],
            "worker_log_sha256": hashes["worker_log"], "script_sha256": script_hash}


def close_record(binding, started_record, guarded_job, native_worker_result):
    """Return state and successor custody; write neither here.

    Root writes state.json using receipt_bytes(), then CAS-replaces only the
    exact CASE_IN_PROGRESS custody. Never call on failure, timeout or uncertainty.
    """
    layout = _leased_layout(binding)
    _source_ok(binding.expected_commit)
    identities = _identities()
    if identities != {name: list(value) for name, value in binding.directory_identities}:
        _fail("binding_changed", layout.profile, "native directory identities changed during the worker", layout)
    current, _ = _owned_json(CUSTODY_PATH)
    if (current != started_record or current.get("status") != "CASE_IN_PROGRESS"
            or current.get("last_case") != layout.run_id or current.get("lease_token") != layout.token
            or current.get("last_source_commit") != binding.expected_commit):
        _fail("inprogress_changed", CUSTODY_PATH, "exact owned in-progress custody required", layout)
    output = layout.evidence
    previous, previous_hash = _owned_json(output / "native-custody-before.json")
    if previous_hash != started_record.get("previous_custody_sha256") or previous_hash != dict(binding.metadata_hashes)[str(CUSTODY_PATH)]:
        _fail("chain_changed", output, "predecessor custody changed", layout)
    job, job_hash = _owned_json(output / "job.json")
    campaign, campaign_hash = _owned_json(output / "campaign-result.json")
    if job != guarded_job or campaign != native_worker_result:
        _fail("result_changed", output, "actual persisted job/native output differs from the supplied result", layout)
    script = _job_ok(job, output)
    _campaign_ok(campaign, previous)
    script_hash = _file_hash(script)
    if script_hash != started_record.get("script_sha256"):
        _fail("script_changed", script, "executed native worker differs from admitted script", layout)
    hashes = {"job": job_hash, "campaign": campaign_hash, "worker_log": _file_hash(output / "worker.log")}
    state = _state_record(started_record, previous, hashes, binding.expected_commit, script_hash)
    hashes["state"] = hashlib.sha256(receipt_bytes(state)).hexdigest()
    custody = {**_common(identities), "status": "CLEAN_CLOSED", "last_case": layout.run_id,
               "last_kind": "native_forward", "last_output": str(output),
               "last_source_commit": binding.expected_commit, "receipt_hashes": hashes,
               "previous_custody_path": started_record["previous_custody_path"],
               "previous_custody_sha256": previous_hash}
    return {"state": state, "custody": custody}
