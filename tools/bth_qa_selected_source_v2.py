"""Version2 exact selected Git sources with one exact review-only attribute suffix.

This is a PARTIAL_SELECTED_PATH_ARCHIVE, never a full repository checkout.
Pure planning/verification APIs start no children and write nothing. The CLI
starts each explicit Git or file worker only through bth_qa_guarded_run.execute.
No existing campaign, profile, save, archive or frozen adapter is modified.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import tarfile

from bth_qa_storage import Layout, StorageGuardError, plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute


SCHEMA = "bth.qa_selected_source/v2"
PHASE_SCHEMA = "bth.qa_selected_source_phase/v2"
SCOPE = "PARTIAL_SELECTED_PATH_ARCHIVE"
ROOT = Path("E:/CodexQA/BTH")
PATHS = (
    "assets", "data", "native", "scenes", "scripts", "tools",
    ".gdlintrc", ".gitattributes", ".gitignore", "AGENTS.md", "CHANGELOG.md", "README.md",
    "default_bus_layout.tres", "export_presets.cfg", "icon.svg", "project.godot",
    "docs/.gdignore", "docs/plans/world06_1_crew_sequence_adapter_contract.md",
    "docs/archive/0.5/plans/0.5_voice_bible.md",
    "docs/todo/environment_slot_family_manifest_legacy_mapping.json",
    "docs/todo/environment_slot_consolidation_disposition.json",
)
CORE = PATHS[:6]
FIXTURES = PATHS[16:]
PHASES = ("source-identity", "tree", "baseline-tree", "select", "archive", "verify-tar", "extract", "verify-extracted")
BASE_COMMIT = "7b284648642a896e534c8bfd53c8e7abbc55108d"
BASE_TREE = "f7d316a268984bfdd7fafef71d0971c9fff0956e"
BASE_STAGE = ROOT / "workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/.tmp/web-release-7b284648/stage"
BASE_MANIFEST_SHA = "5855381ff2137ece43c2b097b169c70c50b658f1caa6d86e1461b42b22bbe447"
BASE_PCK_SHA = "a84ed267a7d664ada937d441be1d053419fe78df5e6725e217c99d60b0bc4ba1"
BASE_UID_SHA = "587514374b37d67f6c0e795cc82d840f1d4a5f9f0b0c2f3c80586ce4eb38b4db"
BASE_UID_MAP_SHA = "293bcadacffd15543a5686b5e40cc6cd409495e80628d77bc0e5e62c2eb61b55"
BASE_CLASSES_SHA = "43ed255c77d8ef9809383d0fef148e952dabddbbf434c69b0276790b6da5816d"
DESCRIPTOR = "addons/coin_pusher_native/coin_pusher_native.gdextension"
DESCRIPTOR_SHA = "80b9af791b34cfd93a6017ac11cbcbfb3abae10a71189a2db8eb044a0af8fe96"
CODE_SUFFIXES = (".gd", ".tscn", ".tres", ".gdshader", ".gdextension")
PIN_FILES = ("project.godot", "export_presets.cfg", "default_bus_layout.tres", "icon.svg", ".gitattributes")

# Exact committed bytes; never normalize, replace or synthesize an archived file.
BASELINE_ATTRIBUTES = b'# These historical inventories are authenticated as exact BOM+CRLF bytes.\n/scripts/tests/fixtures/integ06_1/mid_0_6/mid06_pre_environment_depth_bar_dice.custody.json -text\n/scripts/tests/fixtures/integ06_1/mid_0_6/mid06_pre_game_depth_slot.custody.json -text\n/scripts/tests/fixtures/integ06_1/mid_0_6/mid06_pre_world_depth_crew_debt.custody.json -text\n# Audited art-pack JSON retains exact sealed bytes across Git operations.\n/data/art/environments/gas_station_casino.json -text whitespace=cr-at-eol\n/data/art/environments/index.json -text whitespace=cr-at-eol\n/data/art/environments/corner_store.json -text whitespace=cr-at-eol\n/data/art/environments/back_alley.json -text whitespace=cr-at-eol\n/data/art/environments/motel.json -text whitespace=cr-at-eol\n\nreview_artifacts/environment_art_sources/pawn_shop-preart-v1/pawn_preart_union.json -text whitespace=cr-at-eol\n\nreview_artifacts/environment_art_sources/pawn_shop-preart-v1/pawn_preart_closure.json -text whitespace=cr-at-eol\n/data/art/environments/bar.json -text whitespace=cr-at-eol\n/data/art/environments/pawn_shop.json -text whitespace=cr-at-eol\n/data/art/environments/jazz_club.json -text whitespace=cr-at-eol\n/data/art/environments/punchline_club.json -text whitespace=cr-at-eol\n/data/art/environments/small_underground_casino.json -text whitespace=cr-at-eol\n/data/art/environments/punchline_back_room.json -text whitespace=cr-at-eol\ndata/art/environments/kitty_cat_lounge.json -text\n\n/data/art/environments/delta_queen.json -text whitespace=cr-at-eol\n\ndata/art/environments/beach.json -text\n\ndata/art/environments/grand_casino.json -text\ndata/art/environments/grand_casino_high_limit.json -text\n\ndata/art/environments/grand_casino_back_room.json -text\ndata/art/environments/grand_casino_cage.json -text\ndata/art/environments/motel_room.json -text\ndata/art/environments/apartment.json -text\ndata/art/environments/house.json -text\n'
REVIEW_ATTRIBUTES_SUFFIX = b'\n# Preserve the independently authenticated High Limit canonical-metadata receipt.\n/review_artifacts/environment_art_sources/high-limit-canonical-import-metadata/provenance.json -text whitespace=cr-at-eol\n'
BASELINE_ATTRIBUTES_SHA = "8aee1678b0fbba7a01fb435680f33e011cb17161d77666875e7913d029528699"
REVIEW_ATTRIBUTES_SHA = "8d7388ac3cd2be265a2de7730c8f695230649e05856f608d225ff2e99586f79a"


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()


def attributes_bytes_policy(raw):
    """Only the two literal committed forms; no attribute parser/allowlist."""
    require(type(raw) is bytes and raw in (BASELINE_ATTRIBUTES, BASELINE_ATTRIBUTES + REVIEW_ATTRIBUTES_SUFFIX),
            "Attributes differ from exact baseline or exact reviewed suffix bytes")
    require(hashlib.sha256(BASELINE_ATTRIBUTES).hexdigest() == BASELINE_ATTRIBUTES_SHA and
            hashlib.sha256(BASELINE_ATTRIBUTES + REVIEW_ATTRIBUTES_SUFFIX).hexdigest() == REVIEW_ATTRIBUTES_SHA,
            "Frozen attribute byte constants differ")
    applied = raw != BASELINE_ATTRIBUTES
    return {"schema": "bth.qa_review_only_attributes/v1", "baseline_bytes": len(BASELINE_ATTRIBUTES),
        "baseline_sha256": BASELINE_ATTRIBUTES_SHA, "source_bytes": len(raw), "source_sha256": hashlib.sha256(raw).hexdigest(),
        "source_git_blob_oid": hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest(),
        "review_only_suffix_applied": applied, "exact_suffix_ascii": REVIEW_ATTRIBUTES_SUFFIX.decode("ascii") if applied else "",
        "sole_added_directive": "/review_artifacts/environment_art_sources/high-limit-canonical-import-metadata/provenance.json -text whitespace=cr-at-eol" if applied else "",
        "all_baseline_prefix_bytes_unchanged": True, "runtime_paths_or_export_directives_changed": False,
        "source_bytes_substituted": False}


def attributes_record_policy(baseline_record, source_record):
    """Authenticate literal byte identity from genuine Git blob OID+mode+size."""
    require(all(isinstance(record, dict) and set(record) == {"mode", "oid", "bytes"} and
            type(record["bytes"]) is int and isinstance(record["mode"], str) and isinstance(record["oid"], str)
            for record in (baseline_record, source_record)), "Typed exact attribute Git records required")
    original = attributes_bytes_policy(BASELINE_ATTRIBUTES)
    require(baseline_record == {"mode": "100644", "oid": original["source_git_blob_oid"], "bytes": original["source_bytes"]},
            "Pinned7b baseline attribute Git record differs")
    for raw in (BASELINE_ATTRIBUTES, BASELINE_ATTRIBUTES + REVIEW_ATTRIBUTES_SUFFIX):
        evidence = attributes_bytes_policy(raw)
        if source_record == {"mode": "100644", "oid": evidence["source_git_blob_oid"], "bytes": evidence["source_bytes"]}:
            return evidence
    raise ValueError("Source attribute Git record is not one of the two exact permitted byte forms")


def attributes_for_plan(plan):
    original = attributes_bytes_policy(BASELINE_ATTRIBUTES)
    return attributes_record_policy({"mode": "100644", "oid": original["source_git_blob_oid"], "bytes": original["source_bytes"]},
        plan["files"][".gitattributes"])


def file_sha(path):
    result = hashlib.sha256()
    with plain(path, file=True).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def plain(path, *, file=False):
    require(".." not in Path(path).parts, "Parent traversal forbidden: " + str(path))
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.exists():
            info = item.lstat()
            require(not stat.S_ISLNK(info.st_mode) and not (getattr(info, "st_file_attributes", 0) & 0x400),
                    "Links/reparse paths forbidden: " + str(item))
    if file:
        require(path.is_file() and stat.S_ISREG(path.stat().st_mode), "Ordinary input file required: " + str(path))
    return path


def read_json(path):
    return json.loads(plain(path, file=True).read_text(encoding="utf-8-sig"))


def same_path(a, b):
    return os.path.normcase(str(Path(a).absolute())) == os.path.normcase(str(Path(b).absolute()))


def full_hash(value, size=40):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % size, value) and value != "0" * size,
            "Full nonzero lowercase hash required")


def relative_name(name):
    require(isinstance(name, str) and name and name.isascii() and not any(ord(c) < 32 or ord(c) == 127 for c in name) and
            len(name) <= 1024 and not any(c in name for c in "\\:\"<>|?*") and not name.startswith("/"), "Unsafe source path: " + repr(name))
    path = PurePosixPath(name)
    require(path.as_posix() == name and ".." not in path.parts and all(part not in ("", ".") and len(part) <= 255 and
            not part.endswith((".", " ")) and part.split(".", 1)[0].upper() not in
            {"CON", "PRN", "AUX", "NUL", *("COM" + str(i) for i in range(1, 10)), *("LPT" + str(i) for i in range(1, 10))}
            for part in path.parts), "Noncanonical/Windows-aliased source path: " + name)
    return name


def selected(name):
    return name in PATHS[6:] or any(name.startswith(prefix + "/") for prefix in CORE)


def ancestor_dirs(names):
    return {parent.as_posix() for name in names for parent in PurePosixPath(name).parents if parent.as_posix() != "."}


def check_path_set(names):
    directories = ancestor_dirs(names)
    require(not (set(names) & directories), "Source file/directory collision")
    all_paths = set(names) | directories
    require(len({name.casefold() for name in all_paths}) == len(all_paths), "Case-aliased source directory/file path")


def parse_ls_tree(text):
    """Parse complete NUL-terminated `git ls-tree -r -l -z <fullcommit>` output."""
    if isinstance(text, str):
        text = text.encode("utf-8")
    require(isinstance(text, bytes) and text.endswith(b"\0") and len(text) <= 16 * 1024 ** 2,
            "Complete bounded NUL-terminated Git tree output required")
    result, folded = {}, set()
    for raw in text[:-1].split(b"\0"):
        match = re.fullmatch(rb"(100644|100755) blob ([0-9a-f]{40}) +([0-9]+)\t([^\0]+)", raw)
        require(match is not None, "Git tree row is malformed, non-blob or has unsupported/link mode")
        mode, oid, length, name = match.groups()
        full_hash(oid.decode())
        name = relative_name(name.decode("utf-8", errors="strict"))
        require(name not in result and name.casefold() not in folded, "Duplicate/case-aliased Git path: " + name)
        require(len(length) <= 12, "Oversized source length")
        size = int(length)
        require(size <= 8 * 1024 ** 3, "Source blob exceeds bounded archive policy")
        result[name] = {"mode": mode.decode(), "oid": oid.decode(), "bytes": size}
        folded.add(name.casefold())
    require(1 <= len(result) <= 100000, "Bounded nonempty source tree required")
    check_path_set(result)
    return result


def selection_plan(identity_text, tree_text, source_commit, source_tree):
    """Consume authentic *already guarded* Git outputs; no child, read or write."""
    full_hash(source_commit)
    full_hash(source_tree)
    if isinstance(identity_text, bytes):
        identity_text = identity_text.decode("ascii", errors="strict")
    require(identity_text.strip().splitlines() == [source_commit, source_tree], "Git full commit/root tree identity differs")
    records = parse_ls_tree(tree_text)
    files = {name: row for name, row in records.items() if selected(name)}
    for selector in PATHS:
        require((any(name.startswith(selector + "/") for name in files) if selector in CORE else selector in files),
                "Mandatory selector absent or wrong type: " + selector)
    result = {"schema": SCHEMA, "scope": SCOPE, "source_commit": source_commit, "source_tree": source_tree,
        "full_repository_archive": False, "pathspec": list(PATHS), "files": files,
        "selection_sha256": digest(files), "selected_files": len(files), "selected_bytes": sum(row["bytes"] for row in files.values()),
        "full_tree_records_sha256": digest(records), "full_tree_files": len(records),
        "full_tree_blob_bytes": sum(row["bytes"] for row in records.values()),
        "acceptance_scope": "Environment/native/TEST sources and identified assertion fixtures; not repository hygiene or historical proof archives."}
    result["attributes_policy"] = attributes_for_plan(result)
    validate_plan(result)
    return result


def validate_plan(plan):
    require(plan.get("schema") == SCHEMA and plan.get("scope") == SCOPE and plan.get("full_repository_archive") is False and
            plan.get("pathspec") == list(PATHS), "Exact partial selected-path policy required")
    full_hash(plan.get("source_commit"))
    full_hash(plan.get("source_tree"))
    files, folded = plan.get("files"), set()
    require(isinstance(files, dict) and 1 <= len(files) <= 100000, "Invalid selected source inventory")
    for name, row in files.items():
        relative_name(name)
        require(selected(name) and name.casefold() not in folded and isinstance(row, dict) and
                set(row) == {"mode", "oid", "bytes"} and row["mode"] in ("100644", "100755") and
                type(row["bytes"]) is int and 0 <= row["bytes"] <= 8 * 1024 ** 3, "Invalid source record: " + name)
        full_hash(row["oid"])
        folded.add(name.casefold())
    check_path_set(files)
    require(all((any(name.startswith(selector + "/") for name in files) if selector in CORE else selector in files) for selector in PATHS),
            "Mandatory selected source/fixture absent")
    require(plan.get("selection_sha256") == digest(files) and type(plan.get("selected_files")) is int and
            plan["selected_files"] == len(files) and type(plan.get("selected_bytes")) is int and
            plan["selected_bytes"] == sum(row["bytes"] for row in files.values()), "Selected inventory digest/count differs")
    require(plan.get("attributes_policy") == attributes_for_plan(plan), "Exact source attribute policy binding differs")
    return files


def write_budget(plan, expected_write_bytes):
    """Conservative tar+extraction+evidence bound; no smaller-drive fallback."""
    files = validate_plan(plan)
    require(type(expected_write_bytes) is int and expected_write_bytes > 0, "Explicit positive storage write budget required")
    # Up to four tar blocks for a 1024-byte PAX path, plus record/padding and
    # directory headers, charged at 8KiB each; evidence allowance is 32MiB.
    overhead = (len(files) + len(ancestor_dirs(files))) * 8192 + 32 * 1024 ** 2
    bound = 2 * plan["selected_bytes"] + overhead
    require(bound <= expected_write_bytes, "Selected tar/extraction/evidence upper bound " + str(bound) +
            " bytes exceeds admitted expected_write_bytes=" + str(expected_write_bytes))
    return {"archive_extraction_evidence_upper_bound_bytes": bound, "expected_write_bytes": expected_write_bytes,
        "capacity_reserve_unchanged": True, "policy": "Two payload copies plus bounded tar metadata/padding and32MiB evidence; no reduction of headroom."}


def hash_blob(handle, length):
    git = hashlib.sha1(b"blob " + str(length).encode("ascii") + b"\0")
    raw, total = hashlib.sha256(), 0
    for block in iter(lambda: handle.read(1024 * 1024), b""):
        total += len(block)
        require(total <= length, "Blob longer than its selected Git length")
        git.update(block)
        raw.update(block)
    require(total == length, "Blob shorter than its selected Git length")
    return git.hexdigest(), raw.hexdigest()


def verify_tar_stream(package, plan):
    """Read an open TarFile, authenticating every exact Git blob; no writes."""
    files = validate_plan(plan)
    require(package.pax_headers == {"comment": plan["source_commit"]}, "Git archive PAX commit differs/has unreviewed global transforms")
    expected_dirs = ancestor_dirs(files)
    observed, dirs, seen, folded = {}, set(), set(), set()
    for member in package:
        name = relative_name(member.name.rstrip("/") if member.isdir() else member.name)
        require(name not in seen and name.casefold() not in folded, "Duplicate/case-aliased tar member: " + name)
        seen.add(name)
        folded.add(name.casefold())
        require(not member.linkname and not member.issym() and not member.islnk() and not member.issparse(), "Tar links/sparse entries forbidden")
        require(set(member.pax_headers).issubset({"comment", "path"}) and
                ("comment" not in member.pax_headers or member.pax_headers["comment"] == plan["source_commit"]) and
                ("path" not in member.pax_headers or member.pax_headers["path"].rstrip("/") == name), "Unsupported tar PAX overrides")
        if member.isdir():
            require(name in expected_dirs and member.size == 0 and member.mode == 0o755,
                    "Unexpected/unsafe tar directory: " + name)
            dirs.add(name)
            continue
        require(member.isfile() and name in files, "Unexpected/non-regular tar member: " + name)
        row = files[name]
        require(member.size == row["bytes"] and member.mode & 0o7777 == (0o755 if row["mode"] == "100755" else 0o644),
                "Tar selected length/Git mode differs: " + name)
        handle = package.extractfile(member)
        require(handle is not None, "Missing tar payload: " + name)
        with handle:
            oid, sha256 = hash_blob(handle, row["bytes"])
        require(oid == row["oid"], "Tar content transformed or differs from Git blob: " + name)
        observed[name] = {**row, "sha256": sha256}
    require(set(observed) == set(files) and dirs == expected_dirs, "Tar selected files/directories missing or extra")
    # TarFile stops at its first zero header. Reject an appended second archive
    # or unparsed trailing payload as well as a truncated/missing EOF record.
    stream = package.fileobj
    require(stream.seekable(), "Seekable complete uncompressed Git tar required")
    stream.seek(package.offset)
    trailer = stream.read(11265)
    require(1024 <= len(trailer) <= 11264 and len(trailer) % 512 == 0 and not any(trailer),
            "Selected tar has missing/truncated EOF or extra trailing bytes")
    attributes = attributes_for_plan(plan)
    require(observed[".gitattributes"]["sha256"] == attributes["source_sha256"], "Actual archived attribute bytes differ from exact source form")
    return {"schema": "bth.qa_selected_tar/v1", "scope": SCOPE, "source_commit": plan["source_commit"],
        "source_tree": plan["source_tree"], "selection_sha256": plan["selection_sha256"], "files": observed,
        "file_count": len(observed), "directory_count": len(dirs), "all_git_blobs_verified": True,
        "attributes_policy": {**attributes, "actual_archive_bytes_verified": True}}


def verify_tar(path, plan):
    path = plain(path, file=True)
    before = file_sha(path)
    with tarfile.open(path, "r:") as package:
        proof = verify_tar_stream(package, plan)
    require(before == file_sha(path), "Selected archive changed during verification")
    return {**proof, "archive_path": str(path), "archive_sha256": before, "archive_bytes": path.stat().st_size}


def validate_tar_proof(plan, proof):
    files = validate_plan(plan)
    require(proof.get("schema") == "bth.qa_selected_tar/v1" and proof.get("scope") == SCOPE and
            proof.get("source_commit") == plan["source_commit"] and proof.get("source_tree") == plan["source_tree"] and
            proof.get("selection_sha256") == plan["selection_sha256"] and proof.get("all_git_blobs_verified") is True and
            set(proof.get("files", {})) == set(files), "Qualified selected archive proof differs")
    require(proof.get("attributes_policy") == {**attributes_for_plan(plan), "actual_archive_bytes_verified": True}, "Actual archived attribute proof differs")
    for name, row in files.items():
        recorded = proof["files"][name]
        require(isinstance(recorded, dict) and {key: recorded.get(key) for key in row} == row and
                set(recorded) == {"mode", "oid", "bytes", "sha256"}, "Tar proof source record differs: " + name)
        full_hash(recorded.get("sha256"), 64)
    return files


def verify_extracted(root, plan, tar_proof):
    """Exact pre-overlay extraction; native/candidate overlays must be separate."""
    files = validate_tar_proof(plan, tar_proof)
    root = plain(root)
    require(root.is_dir(), "Selected extraction directory is absent")
    observed, dirs = {}, set()
    for directory, names, basenames in os.walk(root, followlinks=False):
        parent = Path(directory)
        plain(parent)
        for name in names:
            child = plain(parent / name)
            require(child.is_dir(), "Unexpected extracted directory type")
            dirs.add(relative_name(child.relative_to(root).as_posix()))
        for name in basenames:
            child = plain(parent / name, file=True)
            relative = relative_name(child.relative_to(root).as_posix())
            require(relative in files and child.stat().st_size == files[relative]["bytes"], "Extra/wrong-length extracted source: " + relative)
            with child.open("rb") as handle:
                oid, sha256 = hash_blob(handle, files[relative]["bytes"])
            require(oid == files[relative]["oid"] and sha256 == tar_proof["files"][relative]["sha256"],
                    "Extracted selected blob/SHA256 differs: " + relative)
            if os.name != "nt":
                require(stat.S_IMODE(child.stat().st_mode) == (0o755 if files[relative]["mode"] == "100755" else 0o644),
                        "Extracted POSIX file mode differs: " + relative)
            observed[relative] = {**files[relative], "sha256": sha256}
    require(set(observed) == set(files) and dirs == ancestor_dirs(files), "Extracted selected files/directories missing or extra")
    return {"schema": "bth.qa_selected_extraction/v1", "scope": SCOPE, "source_commit": plan["source_commit"],
        "source_tree": plan["source_tree"], "selection_sha256": plan["selection_sha256"], "files": observed,
        "file_count": len(observed), "all_git_blobs_and_sha256_verified": True,
        "attributes_policy": {**attributes_for_plan(plan), "actual_extracted_bytes_verified": True},
        "mode_policy": "Git modes authenticated in archive; NTFS ordinary-file/reparse checks, no POSIX executable-mode claim."
            if os.name == "nt" else "Every extracted POSIX permission mode equals authenticated Git mode."}


def extract_verified(path, plan, destination, layout):
    """Storage-aware file worker; no children, no overwrite, never extractall."""
    write_budget(plan, layout.expected_write_bytes)
    destination = plain(destination)
    require(not destination.exists() and destination.is_relative_to(layout.workspace) and destination != layout.workspace,
            "Fresh absent extraction destination strictly inside owned workspace required")
    validate_layout(layout, extra_write_paths=(destination,))
    proof = verify_tar(path, plan)  # Authenticate the entire archive before the first source write.
    validate_layout(layout, extra_write_paths=(destination,))
    destination.mkdir()  # Parent must be existing admitted workspace/directory.
    for name in sorted(ancestor_dirs(plan["files"]), key=lambda name: (name.count("/"), name)):
        output = plain(destination / name)
        validate_layout(layout, extra_write_paths=(output,))
        output.mkdir()
    with tarfile.open(plain(path, file=True), "r:") as package:
        for member in package:
            if not member.isfile():
                continue
            name = relative_name(member.name)
            require(name in proof["files"], "Archive member changed after admission")
            output = plain(destination / name)
            validate_layout(layout, extra_write_paths=(output.parent,))
            handle = package.extractfile(member)
            require(handle is not None, "Selected payload disappeared")
            with handle, output.open("xb") as target:
                remaining = proof["files"][name]["bytes"]
                while remaining:
                    block = handle.read(min(1024 * 1024, remaining))
                    require(bool(block), "Selected payload truncated during extraction")
                    target.write(block)
                    remaining -= len(block)
                require(not handle.read(1), "Selected payload grew during extraction")
            if os.name != "nt":
                validate_layout(layout, extra_write_paths=(output.parent,))
                output.chmod(0o755 if proof["files"][name]["mode"] == "100755" else 0o644)
    require(file_sha(path) == proof["archive_sha256"], "Selected archive changed during extraction; preserve failed outputs")
    return {"archive": proof, "extraction": verify_extracted(destination, plan, proof)}


def uid_map(raw):
    require(len(raw) >= 4, "Truncated UID cache")
    count, cursor, result, ids = struct.unpack_from("<I", raw)[0], 4, {}, set()
    require(count == 1605, "Complete baseline 1605 UID bindings required")
    for _ in range(count):
        require(cursor + 12 <= len(raw), "Truncated UID record")
        uid, size = struct.unpack_from("<QI", raw, cursor)
        cursor += 12
        require(0 < size <= 65536 and cursor + size <= len(raw), "Truncated UID path")
        path = raw[cursor:cursor + size].decode("utf-8")
        cursor += size
        require(path.startswith("res://") and path not in result and uid not in ids, "Duplicate/non-resource UID binding")
        relative_name(path[6:])
        result[path] = str(uid)
        ids.add(uid)
    require(cursor == len(raw), "UID cache trailing bytes")
    return result


def prove_closure(plan, baseline_stage, overlay_descriptor, baseline_tree_text):
    """Read-only actual immutable PCK proof; no art approval/build-equivalence claim."""
    import audit_pck_manifest
    files = validate_plan(plan)
    stage = plain(baseline_stage)
    require(same_path(stage, BASE_STAGE) and file_sha(stage / "build_manifest.json") == BASE_MANIFEST_SHA and
            file_sha(stage / "index.pck") == BASE_PCK_SHA, "Actual immutable7b baseline stage differs")
    manifest = read_json(stage / "build_manifest.json")
    require(manifest.get("source_commit") == BASE_COMMIT and manifest.get("source_tree") == BASE_TREE,
            "Qualified baseline commit/tree differs")
    require(file_sha(overlay_descriptor) == DESCRIPTOR_SHA, "Explicit qualified native descriptor overlay differs")
    base = parse_ls_tree(baseline_tree_text)
    base_selected = {name: row for name, row in base.items() if selected(name)}
    current_code = {name: row for name, row in files.items() if name.endswith(CODE_SUFFIXES) and name.startswith(tuple(root + "/" for root in CORE))}
    base_code = {name: row for name, row in base_selected.items() if name.endswith(CODE_SUFFIXES) and name.startswith(tuple(root + "/" for root in CORE))}
    gd = [name for name in current_code if name.endswith(".gd")]
    require(len(current_code) == 921 and current_code == base_code and len(gd) == 900 and
            sum(name.startswith("scripts/tests/") for name in gd) == 502 and sum(name.startswith("tools/") for name in gd) == 161,
            "Visible code/test/observer resource paths or original source bytes changed")
    for name in PIN_FILES:
        if name == ".gitattributes":
            continue  # Exact literal two-form check below; no generic attribute allowance.
        require(files[name] == base_selected[name], "Original project/export/icon/attribute pin changed: " + name)
    attributes = attributes_record_policy(base_selected[".gitattributes"], files[".gitattributes"])
    require(attributes == plan["attributes_policy"], "Baseline/source attribute provenance differs")
    require({name: row for name, row in files.items() if name.startswith("native/")} ==
            {name: row for name, row in base_selected.items() if name.startswith("native/")}, "Native source/toolchain pins changed")
    for prefix in ("assets/", "data/"):
        require({name for name in files if name.startswith(prefix) and not name.endswith((".import", ".uid"))} ==
                {name for name in base_selected if name.startswith(prefix) and not name.endswith((".import", ".uid"))},
                "Runtime source path inventory changed: " + prefix)
    data = (stage / "index.pck").read_bytes()
    directory = audit_pck_manifest.find_directory(data)
    entries = {item["path"]: item for item in directory["entries"]}
    require(len(entries) == len(directory["entries"]) == 2107 and not audit_pck_manifest.audit(directory["entries"]), "Baseline PCK directory differs")
    def payload(name):
        row = entries[name]
        start = directory["file_base"] + row["offset"]
        require(row["flags"] == 0 and start >= audit_pck_manifest.HEADER_BYTES and row["bytes"] > 0 and
                start + row["bytes"] <= len(data), "Invalid actual baseline PCK bounds/flags")
        value = data[start:start + row["bytes"]]
        require(hashlib.md5(value).hexdigest() == row["md5"], "Actual PCK payload MD5 differs: " + name)
        return value
    raw_uid = payload(".godot/uid_cache.bin")
    uids = uid_map(raw_uid)
    require(hashlib.sha256(raw_uid).hexdigest() == BASE_UID_SHA and digest(uids) == BASE_UID_MAP_SHA,
            "Actual complete1605 UID map/cache differs")
    uid_sources = {path.removeprefix("res://") for path in uids}
    require(uid_sources - set(files) == {DESCRIPTOR} and len(uid_sources & set(files)) == 1604, "Selected UID source closure missing")
    classes = payload(".godot/global_script_class_cache.cfg")
    class_paths = re.findall(r'"path":\s*"res://([^"]+)"', classes.decode("utf-8"))
    require(hashlib.sha256(classes).hexdigest() == BASE_CLASSES_SHA and len(class_paths) == len(set(class_paths)) == 224 and
            set(class_paths).issubset(files), "Selected class-cache path closure differs")
    raw, compiled = manifest["art_source_files"], manifest["compiled_art_sha256"]
    require(len(raw) == 421 and len(compiled) == 400 and set(raw).issubset(files), "Complete421 raw/400 texture source closure missing")
    linked = set()
    for name, old_sha in raw.items():
        if name.endswith(".png"):
            text = payload(name + ".import").decode("utf-8")
            targets = re.findall(r'^path="res://([^"\n]+\.ctex)"\r?$', text, re.MULTILINE)
            require(len(targets) == 1 and targets[0] in compiled, "Baseline source/import/CTEX linkage differs")
            target = targets[0]
            require(hashlib.sha256(payload(target)).hexdigest() == compiled[target], "Actual baseline CTEX payload SHA differs")
            linked.add(target)
        else:
            require(hashlib.sha256(payload(name)).hexdigest() == old_sha, "Actual baseline art JSON payload SHA differs")
    require(linked == set(compiled), "Not every compiled texture has an exact retained source link")
    mapped, generated, external = {}, [], []
    for name in entries:
        if name.startswith(".godot/") or name == "build_manifest.json":
            generated.append(name)
            continue
        source = "project.godot" if name == "project.binary" else name
        if source.endswith(".gdc"):
            source = source[:-1]
        elif source.endswith(".import"):
            source = source[:-7]
        elif source.endswith(".remap"):
            source = source[:-6]
        if source in files:
            mapped[name] = source
        else:
            external.append((name, source))
    require(len(mapped) == 1395 and len(generated) == 711 and external == [(DESCRIPTOR, DESCRIPTOR)], "Complete actual PCK source closure differs")
    return {"schema": "bth.qa_selected_closure/v1", "scope": SCOPE, "selection_sha256": plan["selection_sha256"],
        "attributes_policy": attributes,
        "baseline_source_commit": BASE_COMMIT, "baseline_source_tree": BASE_TREE, "baseline_manifest_sha256": BASE_MANIFEST_SHA,
        "baseline_pck_sha256": BASE_PCK_SHA, "baseline_tree_records_sha256": digest(base),
        "uid_cache_sha256": BASE_UID_SHA, "uid_map_sha256": BASE_UID_MAP_SHA, "uid_bindings": 1605, "selected_uid_sources": 1604,
        "external_native_overlay": {"path": DESCRIPTOR, "input": str(plain(overlay_descriptor, file=True)), "sha256": DESCRIPTOR_SHA},
        "class_cache_sha256": BASE_CLASSES_SHA, "class_paths": 224, "raw_art_sources": 421, "compiled_texture_sources": 400,
        "direct_pck_source_mappings": 1395, "generated_pck_resources": 711, "visible_code_resources": 921,
        "visible_gd_sources": 900, "test_gd_sources": 502, "tool_gd_sources": 161,
        "all_visible_code_original_records_unchanged": True, "required_document_fixtures": list(FIXTURES),
        "source_art_approved": False, "fresh_import_build_equivalence_proven": False,
        "remaining_gate": "Independent art approval and fresh strict PCK/UID/class/SCN/GDC equivalence; no allowlist change."}


def qualified_job(job):
    limits = job.get("limits", {})
    return (job.get("schema") == "bth.qa_guarded_run/v1" and job.get("exit_code") == 0 and job.get("active_at_release") == 0 and
        job.get("assigned_before_execution") is True and all(not job.get(key) for key in
        ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and bool(job.get("storage_gate_before_job")) and
        bool(job.get("storage_gate_before_child")) and limits.get("cpu_rate") == 1200 and
        limits.get("job_memory_limit_bytes") == 2 * 1024 ** 3 and limits.get("kill_on_close") is True and
        limits.get("breakaway_allowed") is False and type(job.get("finished_epoch")) in (int, float) and math.isfinite(job["finished_epoch"]))


def evidence_for(cfg, phase):
    return ROOT / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence"


def phase_command(cfg, phase):
    git = [cfg["git"], "--git-dir=" + cfg["git_dir"], "-c", "core.quotePath=false", "-c", "tar.umask=0022"]
    if phase == "source-identity":
        return git + ["show", "-s", "--format=%H%n%T", cfg["source_commit"]]
    if phase in ("tree", "baseline-tree"):
        return git + ["ls-tree", "-r", "-l", "-z", BASE_COMMIT if phase == "baseline-tree" else cfg["source_commit"]]
    if phase == "archive":
        return git + ["archive", "--format=tar", "--output=" + cfg["archive"], cfg["source_commit"], *PATHS]
    tokens = []
    for key in ("workspace", "archive", "destination", "git", "git_dir", "source_commit", "source_tree", "baseline_stage", "overlay_descriptor", "run_prefix", "timeout"):
        tokens += ["--" + key.replace("_", "-"), str(cfg[key])]
    return [sys.executable, "-B", str(Path(__file__).absolute()), phase, "--worker", *tokens]


def previous(cfg, phase):
    evidence = evidence_for(cfg, phase)
    result, job, inputs = (read_json(evidence / name) for name in ("phase-result.json", "job.json", "phase-inputs.json"))
    manifest, claim = read_json(evidence / "storage-manifest.json"), read_json(evidence / "launch-claim.json")
    require(result.get("schema") == PHASE_SCHEMA and result.get("phase") == phase and result.get("status") == "PASS" and
        result.get("scope") == SCOPE and result.get("config_sha256") == digest(cfg) and qualified_job(job) and
        job.get("command") == phase_command(cfg, phase) == inputs.get("command") and inputs.get("config") == cfg and
        inputs.get("config_sha256") == digest(cfg) and same_path(result.get("job_receipt", ""), evidence / "job.json") and
        result.get("job_sha256") == file_sha(evidence / "job.json") and result.get("log_sha256") == file_sha(evidence / "worker.log") and
        manifest.get("prepared") is True and same_path(manifest["paths"]["workspace"], cfg["workspace"]) and
        same_path(manifest["paths"]["evidence"], evidence) and same_path(job.get("storage_manifest", ""), evidence / "storage-manifest.json") and
        job.get("storage_manifest_sha256") == claim.get("manifest_sha256") == file_sha(evidence / "storage-manifest.json"),
        "Prior exact guarded selected-source phase is not closed PASS: " + phase)
    required_artifacts = {"worker-result.json", "selection.json", "closure.json"} if phase == "select" else (
        {"worker-result.json"} if phase in ("verify-tar", "extract", "verify-extracted") else set())
    require(isinstance(result.get("artifact_sha256"), dict) and set(result["artifact_sha256"]) == required_artifacts,
            "Prior selected source artifact custody is incomplete: " + phase)
    for name, expected in result["artifact_sha256"].items():
        full_hash(expected, 64)
        require(file_sha(evidence / relative_name(name)) == expected, "Prior selected source artifact changed: " + name)
    return result


def selected_inputs(cfg):
    previous(cfg, "select")
    evidence = evidence_for(cfg, "select")
    return read_json(evidence / "selection.json"), read_json(evidence / "closure.json")


def write_new(path, value, layout):
    path = plain(path)
    validate_layout(layout, extra_write_paths=(path.parent,))
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def worker(cfg, phase):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    stored = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in stored["paths"].items()},
        **{key: stored[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same_path(layout.workspace, cfg["workspace"]) and same_path(layout.evidence, evidence_for(cfg, phase)) and
        read_json(evidence / "phase-inputs.json").get("config") == cfg, "Exact selected source worker admission required")
    if phase == "select":
        for name in ("source-identity", "tree", "baseline-tree"):
            previous(cfg, name)
        plan = selection_plan((evidence_for(cfg, "source-identity") / "worker.log").read_bytes(),
            (evidence_for(cfg, "tree") / "worker.log").read_bytes(), cfg["source_commit"], cfg["source_tree"])
        closure = prove_closure(plan, cfg["baseline_stage"], cfg["overlay_descriptor"],
            (evidence_for(cfg, "baseline-tree") / "worker.log").read_bytes())
        closure["storage_write_budget"] = write_budget(plan, layout.expected_write_bytes)
        write_new(evidence / "selection.json", plan, layout)
        write_new(evidence / "closure.json", closure, layout)
        result = {"selection_sha256": plan["selection_sha256"], "selected_files": plan["selected_files"], "selected_bytes": plan["selected_bytes"]}
    else:
        plan, closure = selected_inputs(cfg)
        require(closure["selection_sha256"] == plan["selection_sha256"], "Selected source closure binding differs")
        previous(cfg, "archive")
        require(file_sha(cfg["archive"]) == previous(cfg, "archive")["archive_sha256"], "Selected archive changed since its closed Git phase")
        if phase == "verify-tar":
            result = verify_tar(cfg["archive"], plan)
        elif phase == "extract":
            previous(cfg, "verify-tar")
            approved = read_json(evidence_for(cfg, "verify-tar") / "worker-result.json")
            require(approved["archive_sha256"] == file_sha(cfg["archive"]), "Verified selected tar changed before extraction")
            result = extract_verified(cfg["archive"], plan, Path(cfg["destination"]), layout)
        elif phase == "verify-extracted":
            previous(cfg, "verify-tar")
            previous(cfg, "extract")
            result = verify_extracted(cfg["destination"], plan, read_json(evidence_for(cfg, "verify-tar") / "worker-result.json"))
        else:
            raise ValueError("Unsupported selected-source worker phase")
    write_new(evidence / "worker-result.json", result, layout)
    print(json.dumps({"status": "WORKER_PASS_PENDING_JOB_CLOSE", "scope": SCOPE, "phase": phase}), flush=True)


def config(args):
    full_hash(args.source_commit)
    full_hash(args.source_tree)
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,65}", args.run_prefix) and 1 <= args.timeout <= 1200, "Fresh prefix/bounded timeout required")
    paths = {key: plain(getattr(args, key)) for key in ("workspace", "archive", "destination", "git", "git_dir", "baseline_stage", "overlay_descriptor")}
    require(all(Path(getattr(args, key)).is_absolute() for key in paths) and paths["workspace"].drive.casefold() == "e:" and
        paths["workspace"].is_relative_to(ROOT) and paths["workspace"] != ROOT / "workspaces" and paths["workspace"].is_relative_to(ROOT / "workspaces") and
        paths["archive"].is_relative_to(paths["workspace"]) and paths["archive"] != paths["workspace"] and
        paths["destination"].parent == paths["workspace"] and paths["destination"] != paths["archive"] and
        not paths["archive"].is_relative_to(paths["destination"]) and same_path(paths["baseline_stage"], BASE_STAGE) and
        not paths["workspace"].is_relative_to(BASE_STAGE) and not BASE_STAGE.is_relative_to(paths["workspace"]), "Explicit disjoint admitted E source outputs/baseline required")
    require(paths["git_dir"].is_dir(), "Existing explicit repository Git directory required")
    for key in ("git", "overlay_descriptor"):
        plain(paths[key], file=True)
    return {"schema": SCHEMA, "scope": SCOPE, **{key: str(value) for key, value in paths.items()},
        "source_commit": args.source_commit, "source_tree": args.source_tree, "run_prefix": args.run_prefix, "timeout": args.timeout,
        "git_sha256": file_sha(paths["git"]), "python_sha256": file_sha(sys.executable), "adapter_sha256": file_sha(__file__),
        "dependencies": {name: file_sha(Path(__file__).with_name(name)) for name in
            ("bth_qa_storage.py", "bth_qa_guarded_run.py", "bth_qa_command_paths.py", "audit_pck_manifest.py")}}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    for key in ("workspace", "archive", "destination", "git", "git-dir", "baseline-stage", "overlay-descriptor"):
        parser.add_argument("--" + key, type=Path, required=True)
    for key in ("source-commit", "source-tree", "run-prefix"):
        parser.add_argument("--" + key, required=True)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        cfg = config(args)
        if args.worker:
            require(args.phase in ("select", "verify-tar", "extract", "verify-extracted"), "Only file phases may enter worker mode")
            worker(cfg, args.phase)
            return 0
        phases = PHASES if args.phase == "plan" else (args.phase,)
        layouts = {phase: plan_layout(ROOT, cfg["workspace"], cfg["run_prefix"] + "-" + phase) for phase in phases}
        outputs = (Path(cfg["archive"]), Path(cfg["destination"]))
        for layout in layouts.values():
            validate_layout(layout, extra_write_paths=outputs)
        if args.phase == "plan":
            print(json.dumps({"status": "READ_ONLY_SELECTED_SOURCE_PLAN", "scope": SCOPE, "config": cfg,
                "commands": {phase: phase_command(cfg, phase) for phase in phases}, "executed": False}, indent=2))
            return 0
        phase = args.phase
        if phase == "source-identity":
            require(not Path(cfg["workspace"]).exists() or not any(Path(cfg["workspace"]).iterdir()), "First phase requires fresh empty workspace")
        else:
            previous(cfg, PHASES[PHASES.index(phase) - 1])
        if phase == "archive":
            require(not Path(cfg["archive"]).exists(), "Selected archive must be absent; no overwrite")
            plan, _ = selected_inputs(cfg)
            write_budget(plan, layouts[phase].expected_write_bytes)
        if phase == "extract":
            require(not Path(cfg["destination"]).exists(), "Selected extraction destination must be absent; no migration/overwrite")
        layout = prepare_layout(layouts[phase])
        if phase == "archive":
            validate_layout(layout, extra_write_paths=outputs)
            Path(cfg["archive"]).parent.mkdir(parents=True, exist_ok=True)
        command = phase_command(cfg, phase)
        write_new(layout.evidence / "phase-inputs.json", {"config": cfg, "config_sha256": digest(cfg), "command": command}, layout)
        job = execute(layout, command, timeout=cfg["timeout"], cpu_rate=1200, extra_write_paths=outputs)
        require(qualified_job(job), "Selected source Job failed/not closed at zero; retain all evidence")
        if phase == "source-identity":
            require((layout.evidence / "worker.log").read_text(encoding="utf-8").strip().splitlines() ==
                [cfg["source_commit"], cfg["source_tree"]], "Actual Git source identity differs")
        elif phase in ("tree", "baseline-tree"):
            parse_ls_tree((layout.evidence / "worker.log").read_bytes())
        artifacts = {}
        if phase in ("select", "verify-tar", "extract", "verify-extracted"):
            artifacts["worker-result.json"] = file_sha(layout.evidence / "worker-result.json")
        if phase == "select":
            artifacts.update({name: file_sha(layout.evidence / name) for name in ("selection.json", "closure.json")})
        result = {"schema": PHASE_SCHEMA, "scope": SCOPE, "phase": phase, "status": "PASS", "config_sha256": digest(cfg),
            "job_receipt": str(layout.evidence / "job.json"), "job_sha256": file_sha(layout.evidence / "job.json"),
            "log_sha256": file_sha(layout.evidence / "worker.log"), "artifact_sha256": artifacts,
            "source_commit": cfg["source_commit"], "source_tree": cfg["source_tree"], "published": False}
        if phase == "archive":
            result.update(archive_sha256=file_sha(cfg["archive"]), archive_bytes=Path(cfg["archive"]).stat().st_size)
        write_new(layout.evidence / "phase-result.json", result, layout)
        print(json.dumps(result, indent=2))
        return 0
    except StorageGuardError as error:
        print(json.dumps({"status": "SELECTED_SOURCE_STORAGE_REJECTED", "scope": SCOPE, "phase": args.phase,
            **error.as_dict(), "fallback_attempted": False, "old_data_modified": False}), file=sys.stderr, flush=True)
        return 2
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, UnicodeError, struct.error, tarfile.TarError) as error:
        print(json.dumps({"status": "SELECTED_SOURCE_STOPPED", "scope": SCOPE, "phase": args.phase, "error": str(error),
            "fallback_attempted": False, "old_data_modified": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
