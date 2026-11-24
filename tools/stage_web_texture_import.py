"""Make a disposable Web export project with an independent Godot import cache."""
import re
import shutil
import subprocess
import sys
from pathlib import Path

BACKDROPS = (
    "apartment", "back_alley", "bar", "beach", "gas_station_casino", "house",
    "jazz_club", "kitty_cat_lounge", "motel", "motel_room", "pawn_shop",
    "small_underground_casino",
)
SKIP_ROOTS = {"builds", ".godot", ".tmp", ".tools", ".git"}


def stage(source: Path, destination: Path) -> None:
    if destination.exists():
        raise ValueError(f"Web import destination must not exist: {destination}")
    destination.mkdir()
    rows = subprocess.check_output([
        "git", "-C", str(source), "ls-files", "-z", "--cached", "--others", "--exclude-standard"
    ]).decode("utf-8").split("\0")
    for name in sorted(set(rows).difference({""})):
        relative = Path(name)
        if relative.parts[0] in SKIP_ROOTS or relative.parts[:2] == ("addons", "coin_pusher_native"):
            continue  # Copy the built extension separately, including ignored binaries.
        origin = source / relative
        if origin.is_file():
            if origin.is_symlink() or not origin.resolve().is_relative_to(source):
                raise ValueError(f"Web source escapes its checkout: {relative}")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(origin, target)
    extension = Path("addons/coin_pusher_native")
    shutil.copytree(source / extension, destination / extension,
                    ignore=shutil.ignore_patterns(".git", ".godot", "*.pdb"))
    for name in BACKDROPS:
        png = destination / f"assets/art/travel/backdrops/{name}.png"
        if not png.is_file():
            raise ValueError(f"Missing Web compression input: {png}")
        sidecar = png.with_suffix(".png.import")
        content = sidecar.read_text(encoding="utf-8") if sidecar.exists() else (
            '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
        )
        if 'importer="texture"' not in content or "[params]" not in content:
            raise ValueError(f"Unexpected Web texture import settings: {sidecar}")
        for setting, value in (("compress/mode", "1"), ("compress/lossy_quality", "0.93")):
            key = re.escape(setting)
            if re.search(rf"^{key}=.*$", content, re.M):
                content = re.sub(rf"^{key}=.*$", f"{setting}={value}", content, flags=re.M)
            else:
                content = content.replace("[params]\n", f"[params]\n{setting}={value}\n", 1)
        sidecar.write_text(content, encoding="utf-8")


def verify(destination: Path) -> None:
    for name in BACKDROPS:
        sidecar = destination / f"assets/art/travel/backdrops/{name}.png.import"
        content = sidecar.read_text(encoding="utf-8")
        imported = re.search(r'^path="res://(\.godot/imported/[^"]+\.ctex)"$', content, re.M)
        if (not imported or not (destination / imported[1]).is_file()
                or not re.search(r"^compress/mode=1$", content, re.M)
                or not re.search(r"^compress/lossy_quality=0\.93$", content, re.M)):
            raise ValueError(f"Web texture import did not produce the requested compression: {sidecar}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "stage":
        stage(Path(sys.argv[2]).resolve(), Path(sys.argv[3]).resolve())
    elif len(sys.argv) == 3 and sys.argv[1] == "verify":
        verify(Path(sys.argv[2]).resolve())
    else:
        raise SystemExit("usage: stage_web_texture_import.py stage SOURCE DEST | verify DEST")
