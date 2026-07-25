"""Build the 0.5 UI sprite exports from the approved source atlases.

The exported PNGs are runtime assets.  Keeping this small deterministic
exporter beside them makes every crop, canvas size, and palette treatment
reproducible for the next artist.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ICON_IDS = (
    "wallet",
    "casino_chips",
    "heat",
    "drink",
    "alert",
    "debt",
    "home",
    "save",
    "time",
    "luck",
    "cheat",
    "danger",
)

PORTRAIT_IDS = (
    "motel_clerk",
    "pit_boss",
    "bartender",
    "pawn_broker",
    "riverboat_dealer",
    "faceless_lender",
)

TITLE_ACCENTS = (
    ("corner_store", "#00f5ff", "awning"),
    ("back_alley", "#ff2d78", "brick"),
    ("motel", "#ffe45c", "vacancy"),
    ("bar", "#00ffd5", "bottle"),
    ("gas_station_casino", "#ffb32d", "road"),
    ("small_underground_casino", "#c44dff", "stairs"),
    ("jazz_club", "#7b3cff", "notes"),
    ("kitty_cat_lounge", "#ff6eb4", "cat"),
    ("delta_queen", "#ffd85a", "paddle"),
    ("beach", "#00e5ff", "wave"),
    ("pawn_shop", "#ffb32d", "diamond"),
    ("grand_casino", "#ff2d78", "crown"),
    ("grand_casino_high_limit", "#ffd85a", "crown"),
    ("grand_casino_back_room", "#9a63ff", "door"),
    ("grand_casino_cage", "#00ffd5", "bars"),
    ("motel_room", "#ffe45c", "key"),
    ("apartment", "#00f5ff", "window"),
    ("house", "#ff6eb4", "roof"),
)


def _make_background_transparent(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            spread = max(red, green, blue) - min(red, green, blue)
            if alpha and min(red, green, blue) >= 205 and spread <= 14:
                pixels[x, y] = (red, green, blue, 0)
    return rgba


def _export_grid(
    source: Path,
    names: tuple[str, ...],
    columns: int,
    rows: int,
    output_dir: Path,
    output_size: tuple[int, int],
) -> None:
    image = _make_background_transparent(Image.open(source))
    cell_width = image.width // columns
    cell_height = image.height // rows
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        column = index % columns
        row = index // columns
        cell = image.crop(
            (
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            )
        )
        bounds = cell.getbbox()
        if bounds:
            cell = cell.crop(bounds)
        canvas = Image.new("RGBA", output_size, (0, 0, 0, 0))
        maximum = (output_size[0] - 8, output_size[1] - 8)
        cell.thumbnail(maximum, Image.Resampling.NEAREST)
        canvas.alpha_composite(
            cell,
            (
                (output_size[0] - cell.width) // 2,
                (output_size[1] - cell.height) // 2,
            ),
        )
        canvas.save(output_dir / f"{name}.png", optimize=True)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        Path("C:/Windows/Fonts/consolab.ttf"),
        Path("C:/Windows/Fonts/courbd.ttf"),
        Path("C:/Windows/Fonts/lucon.ttf"),
    )
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def _draw_title_motif(
    draw: ImageDraw.ImageDraw,
    motif: str,
    accent: str,
) -> None:
    color = accent
    if motif in {"awning", "brick", "bars", "window"}:
        for x in range(8, 88, 14):
            draw.rectangle((x, 9, x + 7, 16), fill=color)
    elif motif in {"vacancy", "road", "stairs", "door", "key"}:
        for step in range(4):
            draw.rectangle((8 + step * 9, 43 - step * 7, 15 + step * 9, 50), fill=color)
    elif motif in {"bottle", "notes", "cat", "diamond"}:
        draw.polygon(((24, 8), (42, 24), (24, 42), (6, 24)), outline=color, width=3)
        draw.rectangle((18, 18, 30, 30), fill=color)
    elif motif in {"paddle", "wave"}:
        for x in range(8, 88, 16):
            draw.arc((x, 18, x + 20, 46), 180, 360, fill=color, width=3)
    else:
        draw.polygon(((8, 38), (18, 16), (28, 31), (40, 10), (51, 38)), fill=color)


def _export_titles(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    font = _font(24)
    small_font = _font(10)
    for index, (archetype_id, accent, motif) in enumerate(TITLE_ACCENTS):
        image = Image.new("RGBA", (384, 64), (5, 6, 10, 245))
        draw = ImageDraw.Draw(image)
        draw.rectangle((1, 1, 382, 62), outline=accent, width=2)
        draw.rectangle((5, 5, 378, 58), outline="#171022", width=2)
        _draw_title_motif(draw, motif, accent)
        display_name = archetype_id.replace("_", " ").upper()
        draw.text((98, 10), display_name, fill="#ffffff", font=font)
        draw.text((100, 43), f"DISTRICT {index + 1:02d}", fill=accent, font=small_font)
        image.save(output_dir / f"{archetype_id}.png", optimize=True)


def _write_source_index(output_root: Path, icon_source: Path, portrait_source: Path) -> None:
    payload = {
        "icon_source": icon_source.name,
        "portrait_source": portrait_source.name,
        "icon_grid": {"columns": 4, "rows": 3, "exports": list(ICON_IDS)},
        "portrait_grid": {"columns": 3, "rows": 2, "exports": list(PORTRAIT_IDS)},
        "title_exports": [entry[0] for entry in TITLE_ACCENTS],
    }
    (output_root / "source_index.json").write_text(
        json.dumps(payload, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--icon-source", required=True, type=Path)
    parser.add_argument("--portrait-source", required=True, type=Path)
    parser.add_argument("--output-root", required=True, type=Path)
    args = parser.parse_args()

    _export_grid(args.icon_source, ICON_IDS, 4, 3, args.output_root / "icons", (64, 64))
    _export_grid(
        args.portrait_source,
        PORTRAIT_IDS,
        3,
        2,
        args.output_root / "portraits",
        (192, 224),
    )
    _export_titles(args.output_root / "environment_titles")
    _write_source_index(args.output_root, args.icon_source, args.portrait_source)


if __name__ == "__main__":
    main()
