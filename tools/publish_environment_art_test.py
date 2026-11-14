"""Install one verified art TEST build without touching main/NEXT or site source."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import uuid

TEST_ROOT = Path("D:/Projects/site/projects/beat-the-house/public/play/test")
TEST_MOUNT = "/userfs/godot/app_userdata/Beat the House/distribution/web_0_6_1_art_test"
MARKER = "BTH_ART_TEST_MANAGED_LAUNCHER_V1"
LAUNCHER = '''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<!-- BTH_ART_TEST_MANAGED_LAUNCHER_V1 -->
<title>Beat the House - Art TEST</title>
<style>body{background:#11101a;color:#e8e5f3;font:18px system-ui;max-width:42em;margin:12vh auto;padding:24px}a{color:#7ef3ff}</style>
<h1>Beat the House: Art TEST</h1><p>Opening the latest audited art preview. TEST uses separate saves from the normal game.</p>
<p id="status"></p><script>
fetch("current",{cache:"no-store"}).then(r=>{if(!r.ok)throw Error("Preview unavailable");return r.text()}).then(s=>{const c=s.trim();if(!/^[a-f0-9]{40}$/.test(c))throw Error("Invalid preview identity");location.replace("./"+c+"/index.html"+location.search+location.hash)}).catch(e=>{document.getElementById("status").textContent=e.message+". Please try again shortly."});
</script>'''


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def no_links(path):
    for candidate in (path, *path.parents):
        if candidate.is_symlink() or getattr(candidate, "is_junction", lambda: False)():
            raise ValueError("Link/junction not allowed: " + str(candidate))


def validate_payload(stage, expected_commit, expected_package):
    no_links(Path(stage).absolute())
    stage = Path(stage).resolve(strict=True)
    if not re.fullmatch("[a-f0-9]{40}", expected_commit):
        raise ValueError("Expected full source commit")
    if not re.fullmatch("[a-f0-9]{64}", expected_package):
        raise ValueError("Expected exact art package SHA256")
    manifest = json.loads((stage / "build_manifest.json").read_text(encoding="utf-8-sig"))
    if (manifest.get("source_commit"), manifest.get("art_package_sha256"), manifest.get("channel")) != (expected_commit, expected_package, "test"):
        raise ValueError("Source/art/channel identity mismatch")
    files = manifest.get("files", {})
    if "index.html" not in files or "index.pck" not in files:
        raise ValueError("Incomplete Web payload")
    expected = {"build_manifest.json"}
    for relative, info in files.items():
        name = PurePosixPath(relative)
        if name.is_absolute() or ".." in name.parts or "\\" in relative or not name.parts:
            raise ValueError("Unsafe payload path")
        path = stage / relative
        no_links(path)
        if not path.is_file() or path.stat().st_size != info["bytes"] or digest(path) != info["sha256"]:
            raise ValueError("Payload bytes mismatch: " + relative)
        expected.add(relative)
    for path in stage.rglob("*"):
        no_links(path)
    actual = {p.relative_to(stage).as_posix() for p in stage.rglob("*") if p.is_file()}
    if actual != expected:
        raise ValueError("Unexpected/missing payload files")
    html = (stage / "index.html").read_text(encoding="utf-8")
    matches = list(re.finditer(r"\bconst\s+GODOT_CONFIG\s*=\s*", html))
    if len(matches) != 1:
        raise ValueError("Expected one Godot config")
    config, _ = json.JSONDecoder().raw_decode(html[matches[0].end():])
    if config.get("args") != ["--", "--bth-art-test"] or config.get("persistentPaths") != [TEST_MOUNT]:
        raise ValueError("TEST persistent mount/flag missing")
    return manifest


def publish(stage, test_root, expected_commit, expected_package, *, reserve_bytes=11 * 1024**3):
    stage, test_root = Path(stage).resolve(strict=True), Path(test_root).absolute()
    no_links(test_root)
    manifest = validate_payload(stage, expected_commit, expected_package)
    parent = test_root.parent.resolve(strict=True)
    if not test_root.resolve().is_relative_to(parent):
        raise ValueError("Target escaped parent")
    total = sum(p.stat().st_size for p in stage.rglob("*") if p.is_file())
    if shutil.disk_usage(parent).free < total * 2 + reserve_bytes:
        raise ValueError("Insufficient deployment space/reserve")
    if test_root.exists() and (test_root / "index.html").exists() and MARKER not in (test_root / "index.html").read_text(encoding="utf-8"):
        raise ValueError("Existing TEST launcher is not managed; refusing overwrite")
    test_root.mkdir(exist_ok=True)
    final = test_root / expected_commit
    if final.exists():
        no_links(final)
        validate_payload(final, expected_commit, expected_package)
        if digest(final / "build_manifest.json") != digest(stage / "build_manifest.json"):
            raise ValueError("Immutable build identity already exists with other bytes")
    else:
        incoming = test_root / (".incoming-" + expected_commit + "-" + uuid.uuid4().hex)
        assert incoming.resolve().is_relative_to(test_root.resolve()) and final.resolve().is_relative_to(test_root.resolve())
        shutil.copytree(stage, incoming)
        validate_payload(incoming, expected_commit, expected_package)
        incoming.rename(final)
    for name, content in (("index.html", LAUNCHER), ("current", expected_commit + "\n")):
        no_links(test_root / name)
        temp = test_root / ("." + name + "-" + uuid.uuid4().hex)
        with temp.open("x", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
        os.replace(temp, test_root / name)
    return {"source_commit": expected_commit, "art_package_sha256": expected_package, "build_manifest_sha256": digest(final / "build_manifest.json"), "files_verified": len(manifest["files"]) + 1, "destination": str(final), "other_lanes_touched": False}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--art-package", required=True)
    args = parser.parse_args(argv)
    if not args.stage.resolve(strict=True).is_relative_to(Path("E:/CodexQA/BTH/workspaces").resolve(strict=True)):
        raise ValueError("Production install requires admitted E: build source")
    print(json.dumps(publish(args.stage, TEST_ROOT, args.source_commit, args.art_package), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
