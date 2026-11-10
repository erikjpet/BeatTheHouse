"""Fail-closed Windows QA storage preflight; this is not a child-process sandbox."""
from __future__ import annotations

from dataclasses import dataclass, replace
import json
import ntpath
import os
from pathlib import Path
import re
import secrets
import shutil
import stat
from typing import Mapping

GIB = 1024 ** 3
DEFAULT_ROOT = r"E:\CodexQA\BTH"
SCHEMA = "bth-qa-storage/v1"
_LEAVES = ("profile", "temp", "evidence", "appdata", "localappdata", "home", "cache", "save_dir", "pycache")
_ENV_PATHS = {
    "TEMP": "temp", "TMP": "temp", "TMPDIR": "temp", "APPDATA": "appdata", "LOCALAPPDATA": "localappdata",
    "USERPROFILE": "home", "HOME": "home", "XDG_CACHE_HOME": "cache",
    "XDG_CONFIG_HOME": "appdata", "XDG_DATA_HOME": "localappdata", "XDG_STATE_HOME": "localappdata",
    "PYTHONPYCACHEPREFIX": "pycache", "BTH_QA_WORKSPACE": "workspace",
    "BTH_QA_PROFILE_DIR": "profile", "BTH_WEB_EVIDENCE_DIR": "evidence",
    "BTH_QA_EVIDENCE_DIR": "evidence", "BTH_SAVE_DIR": "save_dir",
    "BTH_QA_TEMP_DIR": "temp", "BTH_QA_RUN_DIR": "run_root",
}
_ENV_RELATIVE = {
    "BTH_DISTRIBUTION_DATA_ROOT": ("save_dir", "distribution"),
    "BTH_WORLD_REENTRY_ROOT": ("save_dir", "world-reentry"),
    "BTH_USER_SETTINGS_PATH": ("localappdata", "settings.json"),
    "BTH_PROFILE_INVENTORY_PATH": ("localappdata", "profile-inventory.json"),
    "BTH_META_COLLECTION_PATH": ("localappdata", "meta-collection.json"),
}


class StorageGuardError(RuntimeError):
    def __init__(self, code, target, message, required_bytes=None, available_bytes=None):
        self.code, self.target = code, str(target)
        self.required_bytes, self.available_bytes = required_bytes, available_bytes
        super().__init__(f"{code}: {target}: {message}")

    def as_dict(self):
        return {"error": self.code, "target": self.target, "message": str(self),
                "required_bytes": self.required_bytes, "available_bytes": self.available_bytes}


@dataclass(frozen=True)
class Layout:
    root: Path
    workspace: Path
    run_root: Path
    profile: Path
    temp: Path
    evidence: Path
    appdata: Path
    localappdata: Path
    home: Path
    cache: Path
    save_dir: Path
    pycache: Path
    run_id: str
    token: str
    expected_write_bytes: int = 4 * GIB
    reserve_bytes: int = 20 * GIB
    prepared: bool = False
    resident_binding: object | None = None

    @property
    def manifest_path(self):
        return self.evidence / "storage-manifest.json"

    def as_dict(self):
        names = ("root", "workspace", "run_root") + _LEAVES
        result = {"schema": SCHEMA, "run_id": self.run_id, "token": self.token,
                "prepared": self.prepared, "expected_write_bytes": self.expected_write_bytes,
                "reserve_bytes": self.reserve_bytes,
                "required_bytes": self.expected_write_bytes + self.reserve_bytes,
                "paths": {name: str(getattr(self, name)) for name in names},
                "manifest_path": str(self.manifest_path)}
        if self.resident_binding is not None:
            result["schema"] = "bth-qa-storage/resident-v1"
            result["resident_profile_binding"] = self.resident_binding.as_dict()
        return result


def _fail(code, target, message, layout=None, available=None):
    required = None if layout is None else layout.reserve_bytes + layout.expected_write_bytes
    raise StorageGuardError(code, target, message, required, available)


def _require_windows():
    if os.name != "nt":
        _fail("unsupported_platform", os.name, "Windows is required")


def _path(value):
    try:
        raw = os.fspath(value)
    except TypeError:
        _fail("invalid_path", value, "path must be a string or filesystem path")
    if not isinstance(raw, str) or not re.match(r"^[A-Za-z]:[\\/](?![\\/])", raw):
        _fail("invalid_path", raw, "use an absolute local drive path, not UNC or drive-relative")
    if raw[:2].lower() == "c:":
        _fail("system_volume", raw, "QA writable paths must not use C:")
    parts = raw[3:].replace("/", "\\").split("\\")
    if any(p in (".", "..") or p.endswith((" ", ".")) or
           re.search(r'[<>:"|?*\x00-\x1f]', p) or
           re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", p) for p in parts if p):
        _fail("invalid_path", raw, "path traversal and ambiguous Windows path components are forbidden")
    return Path(ntpath.normpath(raw))


def _key(path):
    return ntpath.normcase(str(path))


def _inside(root, path):
    try:
        return _key(ntpath.commonpath((str(root), str(path)))) == _key(root) and _key(path) != _key(root)
    except ValueError:
        return False


def _probe(path):
    """Return (exists, directory, reparse); lstat never follows a reparse leaf."""
    try:
        info = os.lstat(path)
    except FileNotFoundError:
        return False, False, False
    return True, stat.S_ISDIR(info.st_mode), bool(
        info.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT
        if hasattr(info, "st_file_attributes") else stat.S_ISLNK(info.st_mode))


def _inspect(path):
    """Inspect every ancestor before querying real space on the nearest existing one."""
    ancestors = list(reversed(path.parents)) + [path]
    nearest = None
    for ancestor in ancestors:
        exists, directory, reparse = _probe(ancestor)
        if reparse:
            _fail("reparse_path", ancestor, "symlink, junction or reparse ancestors are forbidden")
        if exists:
            if not directory:
                _fail("not_directory", ancestor, "a writable path ancestor is not a directory")
            nearest = ancestor
    if nearest is None:
        _fail("missing_volume", path, "no existing local volume ancestor")
    return nearest


def _free_bytes(path):
    return shutil.disk_usage(path).free


def _resolve_path(path):
    return path.resolve(strict=False)


def _budget(value, name):
    if type(value) is not int or value < 0:
        _fail("invalid_budget", name, "budget must be a nonnegative integer byte count")


def _structure(layout):
    _require_windows()
    _budget(layout.expected_write_bytes, "expected_write_bytes")
    _budget(layout.reserve_bytes, "reserve_bytes")
    if not isinstance(layout.run_id, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,79}", layout.run_id):
        _fail("invalid_run_id", layout.run_id, "use 1-80 letters, digits, underscores or hyphens")
    if not isinstance(layout.token, str) or not re.fullmatch(r"[0-9a-f]{32}", layout.token):
        _fail("invalid_token", layout.run_id, "invalid ownership token")
    root = _path(layout.root)
    paths = {name: _path(getattr(layout, name)) for name in ("workspace", "run_root") + _LEAVES}
    for name, path in paths.items():
        if not _inside(root, path):
            _fail("root_escape", path, f"{name} must be strictly below approved root {root}", layout)
    expected_run = root / "runs" / layout.run_id
    if _key(paths["run_root"]) != _key(expected_run):
        _fail("layout_mismatch", paths["run_root"], "run directory does not match root and run ID", layout)
    if layout.resident_binding is not None:
        from bth_qa_resident import validate_structure
        validate_structure(layout, paths)
    for name in _LEAVES:
        if name == "profile" and layout.resident_binding is not None:
            continue
        if _key(paths[name]) != _key(expected_run / name):
            _fail("layout_mismatch", paths[name], f"{name} differs from the planned dedicated directory", layout)
    leaves = [paths["workspace"]] + [paths[name] for name in _LEAVES]
    for i, left in enumerate(leaves):
        for right in leaves[i + 1:]:
            if layout.resident_binding is not None and _key(left) == _key(paths["workspace"]) and _key(right) == _key(paths["profile"]) and _inside(left, right):
                continue  # Explicit, receipt-bound resident profile inside its existing QA workspace.
            if _key(left) == _key(right) or _inside(left, right) or _inside(right, left):
                _fail("overlap", left, f"writable directory overlaps {right}", layout)
    if _inside(paths["workspace"], expected_run) or _inside(expected_run, paths["workspace"]):
        _fail("overlap", paths["workspace"], "workspace overlaps the run directory", layout)
    return {"root": root, **paths}


def _check_space(layout, paths):
    observations = {}
    for path in paths:
        nearest = _inspect(path)
        resolved = _path(_resolve_path(path))
        if _key(resolved) != _key(path):
            _fail("resolved_alias", path, f"actual resolved path is {resolved}; drive aliases are forbidden", layout)
        available = _free_bytes(nearest)
        observations[str(path)] = {"probe": str(nearest), "available_bytes": available}
        if available < layout.reserve_bytes + layout.expected_write_bytes:
            _fail("insufficient_space", path, "insufficient free bytes; no fallback volume is permitted", layout, available)
    return observations


def _read_manifest(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_layout(layout, prepared=None, extra_write_paths=()):
    """Read-only validation, including current free space and prepared manifest identity."""
    if prepared is not None and prepared != layout.prepared:
        _fail("prepared_state_mismatch", layout.run_root, "prepared flag differs from this layout receipt", layout)
    paths = _structure(layout)
    if not _probe(paths["root"])[0]:
        _fail("missing_root", paths["root"], "approved root must already exist", layout)
    extras = [_path(path) for path in extra_write_paths]
    for path in extras:
        if not any(_key(path) == _key(owned) or _inside(owned, path)
                   for owned in (layout.workspace, layout.run_root)):
            _fail("root_escape", path, "extra output must belong to this workspace or this run", layout)
    if layout.resident_binding is not None:
        from bth_qa_resident import validate_binding
        validate_binding(layout, require_lease=layout.prepared)
    observations = _check_space(layout, list(paths.values()) + extras)
    if not layout.prepared:
        if _probe(layout.run_root)[0]:
            _fail("occupied_run", layout.run_root, "run directory already exists; use a fresh run ID", layout)
    else:
        for name in ("workspace", "run_root") + _LEAVES:
            if not _probe(paths[name])[0]:
                _fail("missing_prepared_directory", paths[name], "prepared directory is absent", layout)
        exists, directory, reparse = _probe(layout.manifest_path)
        if not exists or directory or reparse:
            _fail("invalid_manifest", layout.manifest_path, "exclusive ownership manifest is absent or unsafe", layout)
        try:
            receipt = _read_manifest(layout.manifest_path)
        except (OSError, ValueError) as error:
            _fail("invalid_manifest", layout.manifest_path, str(error), layout)
        if receipt != layout.as_dict():
            _fail("manifest_mismatch", layout.manifest_path, "manifest does not match this exact prepared layout", layout)
    return observations


def plan_layout(root, workspace, run_id, expected_write_bytes=4 * GIB, reserve_bytes=20 * GIB):
    """Plan under an explicitly approved existing root; performs no filesystem writes."""
    _require_windows()
    root, workspace = _path(root), _path(workspace)
    run_root = root / "runs" / str(run_id)
    layout = Layout(root=root, workspace=workspace, run_root=run_root,
                    **{name: run_root / name for name in _LEAVES}, run_id=run_id,
                    token=secrets.token_hex(16), expected_write_bytes=expected_write_bytes, reserve_bytes=reserve_bytes)
    validate_layout(layout)
    return layout


def _mkdir_new(path):
    path.mkdir()  # No exist_ok: a competing or occupied output is an error.


def _ensure_parents(path):
    if _probe(path)[0]:
        _inspect(path)
        return
    _ensure_parents(path.parent)
    _mkdir_new(path)


def _write_manifest(layout):
    with open(layout.manifest_path, "x", encoding="utf-8") as handle:
        json.dump(layout.as_dict(), handle, indent=2)
        handle.write("\n")


def prepare_layout(layout):
    """Create fresh output directories and optionally an empty workspace; never reuse a run."""
    if layout.prepared:
        _fail("already_prepared", layout.run_root, "prepare may only be called once", layout)
    validate_layout(layout)  # All path/space checks finish before any mkdir/write.
    success = False
    if layout.resident_binding is not None:
        from bth_qa_resident import acquire_lease, release_lease
        acquire_lease(layout)
    try:
        _ensure_parents(layout.run_root.parent)
        _mkdir_new(layout.run_root)
        if not _probe(layout.workspace)[0]:
            _ensure_parents(layout.workspace.parent)
            _mkdir_new(layout.workspace)
        for name in _LEAVES:
            if name == "profile" and layout.resident_binding is not None:
                continue  # Never mkdir, copy or change the existing resident profile.
            _mkdir_new(getattr(layout, name))
        _check_space(layout, _structure(layout).values())
        prepared = replace(layout, prepared=True)
        _write_manifest(prepared)
        validate_layout(prepared)
        success = True
        return prepared
    except OSError as error:
        _fail("prepare_failed", getattr(error, "filename", None) or layout.run_root,
              f"{error}; partial new directories are retained, never overwritten or removed", layout)
    finally:
        if layout.resident_binding is not None and not success:
            release_lease(layout, active_owned_processes=0)


def child_environment(layout, parent_env: Mapping[str, str]):
    """Return child-only overrides. Does not mutate the caller's environment."""
    _structure(layout)
    env = dict(parent_env)
    # Windows environment names are case-insensitive: remove differently cased duplicates.
    controlled = set(_ENV_PATHS) | set(_ENV_RELATIVE) | {"PYTHONDONTWRITEBYTECODE", "HOMEDRIVE", "HOMEPATH"}
    env = {key: value for key, value in env.items() if key.upper() not in controlled}
    env.update({key: str(getattr(layout, attr)) for key, attr in _ENV_PATHS.items()})
    env.update({key: str(getattr(layout, attr) / name) for key, (attr, name) in _ENV_RELATIVE.items()})
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["HOMEDRIVE"], env["HOMEPATH"] = ntpath.splitdrive(str(layout.home))
    return env


def check_launch(layout, cwd, env, extra_write_paths=()):
    """Recheck actual launch arguments immediately before caller creates its child."""
    if not layout.prepared:
        _fail("not_prepared", layout.run_root, "prepare_layout must succeed before launch", layout)
    observations = validate_layout(layout, extra_write_paths=extra_write_paths)
    if _key(_path(cwd)) != _key(layout.workspace):
        _fail("cwd_mismatch", cwd, "child cwd must be the planned workspace", layout)
    folded = {}
    for key, value in env.items():
        if key.upper() in folded:
            _fail("duplicate_environment", key, "duplicate case-insensitive child environment key", layout)
        folded[key.upper()] = value
    for key, attr in _ENV_PATHS.items():
        value = folded.get(key)
        if value is None or _key(_path(value)) != _key(getattr(layout, attr)):
            _fail("environment_spill", value or key, f"{key} must match guarded {attr}", layout)
    for key, (attr, name) in _ENV_RELATIVE.items():
        value = folded.get(key)
        target = getattr(layout, attr) / name
        if value is None or _key(_path(value)) != _key(target):
            _fail("environment_spill", value or key, f"{key} must match guarded {target}", layout)
        if _probe(target)[2]:
            _fail("reparse_path", target, "native output path must not be a reparse alias", layout)
    drive, home = ntpath.splitdrive(str(layout.home))
    for key, expected in {"PYTHONDONTWRITEBYTECODE": "1", "HOMEDRIVE": drive, "HOMEPATH": home}.items():
        if folded.get(key) != expected:
            _fail("environment_spill", key, f"must be {expected}", layout)
    return observations


def plan_resident_layout(root, workspace, run_id, *, profile, custody, campaign_id, origin, expected_commit, expected_write_bytes=4 * GIB, reserve_bytes=20 * GIB):
    """Explicit closed-QA resident binding; fresh plan_layout stays unchanged."""
    from bth_qa_resident import plan
    return plan(root, workspace, run_id, profile=profile, custody=custody, campaign_id=campaign_id,
                origin=origin, expected_commit=expected_commit, expected_write_bytes=expected_write_bytes, reserve_bytes=reserve_bytes)


def release_resident_layout(layout, *, active_owned_processes):
    """Only after the capped Job drained to zero. Does not touch profile contents."""
    from bth_qa_resident import release_lease
    return release_lease(layout, active_owned_processes=active_owned_processes)


def plan_closed_inspection_recovery_layout(root, workspace, run_id, *, profile, custody, campaign_id, origin, expected_commit, expected_write_bytes=4*GIB, reserve_bytes=20*GIB):
    """Explicit exact failed-inspection successor; normal resident API stays strict."""
    from bth_qa_closed_inspection import POLICY,validate_scope
    from bth_qa_resident import plan
    validate_scope(root,workspace,run_id,profile,custody,campaign_id,origin,expected_commit,POLICY)
    return plan(root,workspace,run_id,profile=profile,custody=custody,campaign_id=campaign_id,
        origin=origin,expected_commit=expected_commit,expected_write_bytes=expected_write_bytes,
        reserve_bytes=reserve_bytes,recovery_policy=POLICY)


def plan_receipt_crash_recovery_layout(root, workspace, run_id, *, profile, custody, campaign_id, origin, expected_commit, expected_write_bytes=4*GIB, reserve_bytes=20*GIB):
    """Exact1315→1316 cold observation; never treats the crashed case as clean."""
    from bth_qa_crash_inspection import POLICY,validate_scope
    from bth_qa_resident import plan
    validate_scope(root,workspace,run_id,profile,custody,campaign_id,origin,expected_commit,POLICY)
    return plan(root,workspace,run_id,profile=profile,custody=custody,campaign_id=campaign_id,
        origin=origin,expected_commit=expected_commit,expected_write_bytes=expected_write_bytes,
        reserve_bytes=reserve_bytes,recovery_policy=POLICY)


def plan_paid_trip_cold_recovery_layout(root, workspace, run_id, *, profile, custody, campaign_id, origin, expected_commit, expected_write_bytes=4*GIB, reserve_bytes=20*GIB):
    """Exact1350-to1351 inspection only; accepted trip is never replayed."""
    from bth_qa_paid_trip_inspection import POLICY,validate_scope
    from bth_qa_resident import plan
    validate_scope(root,workspace,run_id,profile,custody,campaign_id,origin,expected_commit,POLICY)
    return plan(root,workspace,run_id,profile=profile,custody=custody,campaign_id=campaign_id,
        origin=origin,expected_commit=expected_commit,expected_write_bytes=expected_write_bytes,
        reserve_bytes=reserve_bytes,recovery_policy=POLICY)
