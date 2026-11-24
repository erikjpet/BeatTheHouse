#!/usr/bin/env python3
"""Build the plain-language environment art package for an outside artist, and
bring the artist's delivery back into the repository.

    python tools/build_artist_package.py build --out <folder> [--zip]
    python tools/build_artist_package.py import --from <delivered folder> [--dry-run]

Requires Pillow (pip install pillow). Reads repository data only; `import`
writes room backgrounds, counter fronts, matching animation PNGs and doorways.
It never edits manifests, placements or code. See docs/art/artist_package/DEVELOPER.md.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("Pillow is required: pip install pillow")

REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "docs/art/artist_package"
BOARD = (900, 430)
SCALE = 2
ROOMS_DIR = "Rooms"
DOORWAYS_DIR = "Doorways"
ANIM_DIR = "animations (optional)"
F_CURRENT = "1 current version.png"
F_LAYER = "2 guide layer.png"
F_PREVIEW = "3 what goes where.png"
F_REFERENCE = "reference - outside.png"
F_DELIVERY = "background.png"

# Art room id -> placement map id, where they differ.
PLACEMENT_MAP = {
    "punchline_club": "small_underground_casino:club",
    "small_underground_casino": "small_underground_casino:casino",
    "punchline_back_room": "small_underground_casino:back_room",
}
# Art room id -> exterior facade used as color reference, where they differ.
EXTERIOR = {
    "punchline_club": "small_underground_casino",
    "punchline_back_room": "small_underground_casino",
    "grand_casino_high_limit": "grand_casino",
    "grand_casino_back_room": "grand_casino",
    "grand_casino_cage": "grand_casino",
}
DOORWAY_ROOM = {"small_underground_casino": "Punchline Comedy Club"}

RED = (230, 40, 40)
ORANGE = (255, 150, 20)
BLUE = (40, 140, 255)
PURPLE = (200, 80, 255)
GREEN = (40, 220, 90)
YELLOW = (255, 230, 0)
WHITE = (255, 255, 255)
LEGEND = [
    (RED, "Red: the game puts something here. Leave it plain."),
    (ORANGE, "Orange: same, only sometimes."),
    (BLUE, "Blue: counter front. People stand behind it."),
    (PURPLE, "Purple: a surface things sit on. Must look solid."),
    (GREEN, "Green: doorway or exit."),
    (YELLOW, "Yellow line: floor starts here."),
]


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1
        return ImageFont.load_default()


def human(text: str) -> str:
    text = re.sub(r"^(grand|motel|bar|pawn|jazz|kitty|delta|beach|corner_store|back_alley|gas_station)_", "", text)
    return text.replace("_", " ").strip()


def room_list():
    rooms = []
    for path in sorted((SOURCE / "rooms").glob("[0-9][0-9]_*.txt")):
        number, room_id = path.stem.split("_", 1)
        text = path.read_text(encoding="utf-8")
        rooms.append({"number": number, "id": room_id, "name": text.splitlines()[0].strip(), "brief": text})
    if not rooms:
        sys.exit(f"No room briefs found in {SOURCE / 'rooms'}")
    return rooms


def room_folder(room) -> str:
    return f"{room['number']} {room['name']}"


def placement(room_id: str):
    surfaces = load_json(REPO / "data/environments/placement_surfaces.json")
    maps = {m["id"]: m for m in surfaces["maps"]}
    key = PLACEMENT_MAP.get(room_id, room_id)
    overrides = load_json(REPO / "data/environments/developer_placement_overrides.json")["rooms"].get(key, {})
    return maps[key], overrides.get("slot_positions", {})


def effective_slots(pmap, positions):
    """Yield (slot, hit_rect, always) with developer overrides applied."""
    for family, always in (("fixed_slots", True), ("exit_slots", True), ("event_slots", False)):
        for slot in pmap.get(family, []):
            x, y, w, h = slot["hit_rect"]
            px, py = slot["pos"]
            nx, ny = positions.get(slot["id"], [px, py])
            yield slot, [x + nx - px, y + ny - py, w, h], always


def draw_guide(room_id: str, scale: int, labels: bool) -> Image.Image:
    pmap, positions = placement(room_id)
    image = Image.new("RGBA", (BOARD[0] * scale, BOARD[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image, "RGBA")
    small = font(11 * scale)
    texts = []

    def box(rect, color, fill_alpha, width=1, label=None):
        x, y, w, h = rect
        x0, x1 = sorted((x, x + w))
        y0, y1 = sorted((y, y + h))
        r = [x0 * scale, y0 * scale, max(x0 * scale, x1 * scale - 1), max(y0 * scale, y1 * scale - 1)]
        draw.rectangle(r, fill=color + (fill_alpha,), outline=color + (255,), width=width * scale)
        if label and labels:
            texts.append((r[0] + 3 * scale, r[1] + 2 * scale, label, color))

    floor_y = pmap["floor"]["bands"][0][1]
    for doorway in pmap.get("doorways", []):
        box(doorway["bounds"], GREEN, 30, 1, human(doorway["id"]))
    counters = [c for c in pmap.get("counters", []) if not c["id"].startswith("scenario_")]
    for front in (False, True):  # counter fronts last so they stay visible
        for counter in counters:
            if bool(counter.get("foreground_art_id")) != front:
                continue
            rect = [counter["x0"], counter["top_y"], counter["x1"] - counter["x0"], counter["front_y"] - counter["top_y"]]
            if front:
                box(rect, BLUE, 70, 1, "counter front")
            else:
                box(rect, PURPLE, 35, 1, human(counter["id"]))
    for slot, rect, always in effective_slots(pmap, positions):
        if not always:
            box(rect, ORANGE, 40, 1)
    for slot, rect, always in effective_slots(pmap, positions):
        if always:
            box(rect, RED, 90, 1, slot.get("physical_role") or "game object")
    for seat in pmap.get("seats", []):
        sx, sy = seat["point"]
        draw.ellipse([(sx - 3) * scale, (sy - 3) * scale, (sx + 3) * scale, (sy + 3) * scale], fill=WHITE + (220,))
    for x in range(0, BOARD[0] * scale, 12 * scale):
        draw.line([x, floor_y * scale, x + 7 * scale, floor_y * scale], fill=YELLOW + (255,), width=2 * scale)
    if labels:
        texts.append((4 * scale, (floor_y + 2) * scale, "floor starts here", YELLOW))
        for x, y, text, color in texts:
            l, t, r, b = draw.textbbox((x, y), text, font=small)
            draw.rectangle([l - 2, t - 1, r + 2, b + 1], fill=(0, 0, 0, 190))
            draw.text((x, y), text, font=small, fill=color + (255,))
    return image


def preview(room_id: str, background: Image.Image) -> Image.Image:
    board = background.convert("RGBA").resize((BOARD[0] * SCALE, BOARD[1] * SCALE), Image.NEAREST)
    board = Image.alpha_composite(board, Image.new("RGBA", board.size, (0, 0, 0, 70)))
    board = Image.alpha_composite(board, draw_guide(room_id, SCALE, True))
    legend_font = font(26)
    out = Image.new("RGBA", (board.width, board.height + 150), (20, 20, 24, 255))
    out.paste(board, (0, 0))
    draw = ImageDraw.Draw(out)
    for i, (color, text) in enumerate(LEGEND):
        x, y = 20 + (i % 2) * 900, board.height + 14 + (i // 2) * 44
        draw.rectangle([x, y + 4, x + 28, y + 28], fill=color)
        draw.text((x + 40, y), text, font=legend_font, fill=WHITE)
    return out.convert("RGB")


def describe_animations(room_id: str, folder: Path | None):
    manifest = load_json(REPO / f"data/art/environments/{room_id}.json")
    kinds = {
        "pulse": "glow that fades in and out",
        "frames": "flip-book strip",
        "mover": "small piece that slides across",
        "scroll": "repeating pattern that scrolls",
        "sweep": "light beam that swings",
    }
    groups: dict[tuple, list] = {}
    for entry in manifest["animations"]:
        path = REPO / "assets/art/environments" / room_id / entry["texture"]
        size = Image.open(path).size
        if folder is not None:
            shutil.copy2(path, folder / path.name)
        base = re.sub(r"_?\d+$", "", entry["id"])
        on_black = entry.get("blend") == "add"
        key = (base, entry["type"], on_black)
        if path.name not in {name for name, _, _ in groups.get(key, [])}:
            groups.setdefault(key, []).append((path.name, size, entry.get("frames")))
    lines = []
    for (base, kind, on_black), files in groups.items():
        sizes = sorted({f"{w} x {h}" for _, (w, h), _ in files})
        size_text = f"{sizes[0]} px" if len(sizes) == 1 else "different sizes (keep each one's size)"
        frames = files[0][2]
        extra = f", {frames} frames side by side" if frames else ""
        count = f"{len(files)} files" if len(files) > 1 else files[0][0]
        surface = "draw on black" if on_black else "transparent background"
        lines.append(f"- {human(base)}: {kinds[kind]}{extra}. {count}, {size_text}, {surface}.")
    return lines


def build(out: Path, make_zip: bool) -> None:
    if out.exists() and any(out.iterdir()):
        sys.exit(f"{out} is not empty; choose a new folder")
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE / "START_HERE.txt", out / "START HERE.txt")
    for room in room_list():
        room_id = room["id"]
        folder = out / ROOMS_DIR / room_folder(room)
        anim = folder / ANIM_DIR
        anim.mkdir(parents=True)
        background = Image.open(REPO / "assets/art/environments" / room_id / "background.png")
        if background.size != (BOARD[0] * SCALE, BOARD[1] * SCALE):
            sys.exit(f"{room_id}: background is {background.size}, expected 1800 x 860")
        background.convert("RGB").resize(BOARD, Image.NEAREST).save(folder / F_CURRENT)
        draw_guide(room_id, 1, False).save(folder / F_LAYER)
        preview(room_id, background).save(folder / F_PREVIEW)
        exterior = REPO / "assets/art/travel/exteriors" / f"{EXTERIOR.get(room_id, room_id)}.png"
        if exterior.exists():
            shutil.copy2(exterior, folder / F_REFERENCE)
        brief = room["brief"].rstrip() + "\n\nANIMATED PIECES (OPTIONAL, see START HERE)\n"
        brief += "\n".join(describe_animations(room_id, anim)) + "\n"
        brief += "\nWHEN DONE\nSave your picture as background.png in this folder (900 x 430 pixels).\n"
        (folder / "brief.txt").write_text(brief, encoding="utf-8")
    doorways = out / DOORWAYS_DIR
    doorways.mkdir()
    lines = [(SOURCE / "doorways.txt").read_text(encoding="utf-8").rstrip(), "", "FILES"]
    names = {r["id"]: r["name"] for r in room_list()} | DOORWAY_ROOM
    for path in sorted((REPO / "assets/art/travel/doorways").glob("*.png")):
        shutil.copy2(path, doorways / path.name)
        w, h = Image.open(path).size
        lines.append(f"- {path.name}: {names.get(path.stem, human(path.stem))}, {w} x {h}")
    (doorways / "instructions.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Built {out}")
    if make_zip:
        archive = shutil.make_archive(str(out), "zip", out.parent, out.name)
        print(f"Zipped {archive}")


def import_delivery(source: Path, dry_run: bool) -> int:
    rooms = {r["number"]: r for r in room_list()}
    problems, changes = [], []

    def write(image: Image.Image, target: Path, label: str):
        changes.append(label)
        if not dry_run:
            image.save(target)

    for folder in sorted((source / ROOMS_DIR).glob("[0-9][0-9] *")):
        room = rooms.get(folder.name[:2])
        if room is None:
            problems.append(f"{folder.name}: unknown room number")
            continue
        room_id, assets = room["id"], REPO / "assets/art/environments" / room["id"]
        delivered = folder / F_DELIVERY
        if delivered.exists():
            image = Image.open(delivered)
            full = None
            if image.convert("RGBA").getchannel("A").getextrema()[0] < 255:
                problems.append(f"{folder.name}: background.png has transparent pixels")
            elif image.size == BOARD:
                full = image.convert("RGB").resize((BOARD[0] * SCALE, BOARD[1] * SCALE), Image.NEAREST)
            elif image.size == (BOARD[0] * SCALE, BOARD[1] * SCALE):
                full = image.convert("RGB")
            else:
                problems.append(f"{folder.name}: background.png is {image.size[0]} x {image.size[1]}, expected 900 x 430")
            if full is not None:
                write(full, assets / "background.png", f"{room_id}: background")
                manifest = load_json(REPO / f"data/art/environments/{room_id}.json")
                pmap, _ = placement(room_id)
                rects = {c["foreground_art_id"]: c for c in pmap.get("counters", []) if c.get("foreground_art_id")}
                for counter_id, spec in manifest.get("counters", {}).items():
                    c = rects.get(counter_id)
                    if c is None:
                        problems.append(f"{room_id}: no placement rectangle for counter {counter_id}")
                        continue
                    left, top, right, bottom = spec.get("bleed", [0, 0, 0, 0])
                    box = ((c["x0"] - left) * SCALE, (c["top_y"] - top) * SCALE,
                           (c["x1"] + right) * SCALE, (c["front_y"] + bottom) * SCALE)
                    write(full.crop(box), assets / spec["texture"], f"{room_id}: counter front {counter_id} (cropped)")
        anim = folder / ANIM_DIR
        for path in sorted(anim.glob("*.png")) if anim.exists() else []:
            target = assets / "anim" / path.name
            if not target.exists():
                problems.append(f"{room_id}: animation {path.name} has no matching game file (renamed?)")
                continue
            new, old = Image.open(path), Image.open(target)
            if new.size != old.size:
                problems.append(f"{room_id}: animation {path.name} is {new.size}, must stay {old.size}")
            # RGBA getbbox() defaults to alpha-only on recent Pillow.
            elif any(channel.getbbox() is not None for channel in
                     ImageChops.difference(new.convert("RGBA"), old.convert("RGBA")).split()):
                changes.append(f"{room_id}: animation {path.name}")
                if not dry_run:
                    shutil.copy2(path, target)
    for path in sorted((source / DOORWAYS_DIR).glob("*.png")):
        target = REPO / "assets/art/travel/doorways" / path.name
        if not target.exists():
            problems.append(f"doorway {path.name} has no matching game file")
            continue
        new, old = Image.open(path), Image.open(target)
        if new.size != old.size:
            problems.append(f"doorway {path.name} is {new.size}, must stay {old.size}")
        elif ImageChops.difference(new.convert("RGB"), old.convert("RGB")).getbbox() is not None:
            changes.append(f"doorway {path.name}")
            if not dry_run:
                new.convert("RGB").save(target)
    print(("Would change" if dry_run else "Changed") + f" {len(changes)} file(s):")
    for line in changes:
        print("  " + line)
    for line in problems:
        print("PROBLEM: " + line)
    if not dry_run and changes:
        print("Next: python -B tools/check_environment_art_pack.py --all, then review each room in the Environment Library.")
    return 1 if problems else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build", help="Build the artist package")
    b.add_argument("--out", type=Path, required=True)
    b.add_argument("--zip", action="store_true")
    i = sub.add_parser("import", help="Bring an artist delivery into the repository")
    i.add_argument("--from", dest="source", type=Path, required=True)
    i.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.command == "build":
        build(args.out.resolve(), args.zip)
        return 0
    return import_delivery(args.source.resolve(), args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
