#!/usr/bin/env python3
"""Generate the nine procedural reveal icons used by current scratch tickets.

The shipped *_background_pro.png faces and pro_* reveal icons are authored art.
Their runtime geometry is measured by scratch_ticket_alignment_audit.py.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SYMBOLS_DIR = ROOT / "assets" / "art" / "scratch_tickets" / "reveal_symbols"



def mix(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def font(size: int, bold: bool = False, condensed: bool = False) -> ImageFont.FreeTypeFont:
    candidates = []
    if condensed:
        candidates.extend([
            Path("C:/Windows/Fonts/impact.ttf"),
            Path("C:/Windows/Fonts/arialbd.ttf"),
        ])
    if bold:
        candidates.extend([
            Path("C:/Windows/Fonts/arialbd.ttf"),
            Path("C:/Windows/Fonts/seguibl.ttf"),
        ])
    candidates.extend([
        Path("C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeui.ttf"),
    ])
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def text_bbox(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.ImageFont) -> tuple[int, int, int, int]:
    return draw.textbbox((0, 0), text, font=fnt, stroke_width=0)


def center_text(
    draw: ImageDraw.ImageDraw,
    rect: tuple[float, float, float, float],
    text: str,
    size: int,
    fill: tuple[int, int, int, int],
    *,
    bold: bool = True,
    condensed: bool = False,
    stroke_fill: tuple[int, int, int, int] | None = None,
    stroke_width: int = 0,
    max_shrink: int = 5,
) -> None:
    if not text:
        return
    x, y, w, h = rect
    chosen = font(size, bold=bold, condensed=condensed)
    for trial in range(size, max_shrink - 1, -1):
        chosen = font(trial, bold=bold, condensed=condensed)
        bx = text_bbox(draw, text, chosen)
        if bx[2] - bx[0] <= w - 4 and bx[3] - bx[1] <= h - 2:
            break
    bx = text_bbox(draw, text, chosen)
    tx = x + (w - (bx[2] - bx[0])) / 2 - bx[0]
    ty = y + (h - (bx[3] - bx[1])) / 2 - bx[1]
    draw.text((tx, ty), text, font=chosen, fill=fill, stroke_fill=stroke_fill, stroke_width=stroke_width)


def normalize_rect_abs(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = box
    return (min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))


def rounded(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill, outline=None, width: int = 1) -> None:
    box = normalize_rect_abs(box)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def star_points(cx: float, cy: float, outer: float, inner: float, points: int = 5, rotation: float = -math.pi / 2) -> list[tuple[float, float]]:
    out: list[tuple[float, float]] = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        angle = rotation + math.pi * i / points
        out.append((cx + math.cos(angle) * r, cy + math.sin(angle) * r))
    return out


def symbol_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img, "RGBA")


def save_symbol(name: str, draw_fn: Callable[[ImageDraw.ImageDraw], None]) -> None:
    img, d = symbol_canvas()
    draw_fn(d)
    img = img.filter(ImageFilter.UnsharpMask(radius=0.4, percent=120, threshold=2))
    img.save(SYMBOLS_DIR / f"{name}.png")


def generate_symbols() -> None:
    """Generate high-legibility reveal icons.

    Runtime overlays the actual numbers, letters, and card ranks, so these
    assets should read as unmistakable icon backplates at tiny in-game sizes:
    big silhouettes, thick outlines, and quiet interiors behind text.
    """
    SYMBOLS_DIR.mkdir(parents=True, exist_ok=True)

    def plaque(d, box, fill, outline, width: int = 6, radius: int = 12):
        rounded(d, (box[0] + 5, box[1] + 6, box[2] + 5, box[3] + 6), radius, (0, 0, 0, 105))
        rounded(d, box, radius, fill, outline, width)

    def coin(d, fill, outline, inner=(255, 255, 255, 115)):
        d.ellipse((9, 10, 119, 120), fill=(0, 0, 0, 90))
        d.ellipse((7, 5, 117, 115), fill=fill, outline=outline, width=7)
        d.ellipse((23, 21, 101, 99), fill=mix(fill, (255, 255, 255, 255), 0.18), outline=inner, width=5)

    def centered_word(d, text, fill, stroke, y=39, size=32):
        center_text(d, (12, y, 104, 44), text, size, fill, condensed=True, stroke_fill=stroke, stroke_width=3)

    save_symbol("number_coin", lambda d: (coin(d, (255, 221, 82, 255), (59, 38, 12, 255)), d.rectangle((40, 58, 88, 69), fill=(97, 65, 17, 180))))
    save_symbol("lucky_seven", lambda d: (coin(d, (19, 78, 40, 255), (255, 230, 62, 255)), center_text(d, (22, 12, 84, 88), "7", 82, (246, 33, 67, 255), condensed=True, stroke_fill=(255, 238, 92, 255), stroke_width=4)))
    save_symbol("gold_bar", lambda d: (d.rectangle((17, 69, 111, 102), fill=(0, 0, 0, 95)), d.polygon([(13, 51), (97, 51), (113, 91), (29, 91)], fill=(255, 211, 59, 255), outline=(91, 55, 8, 255)), d.polygon([(32, 28), (83, 28), (99, 51), (15, 51)], fill=(255, 239, 118, 255), outline=(91, 55, 8, 255)), centered_word(d, "GOLD", (74, 45, 8, 255), (255, 246, 153, 255), 51, 24)))
    save_symbol("brass_bar", lambda d: (d.rectangle((17, 69, 111, 102), fill=(0, 0, 0, 95)), d.polygon([(13, 51), (97, 51), (113, 91), (29, 91)], fill=(165, 101, 43, 255), outline=(60, 38, 21, 255)), d.polygon([(32, 28), (83, 28), (99, 51), (15, 51)], fill=(206, 145, 68, 255), outline=(60, 38, 21, 255)), centered_word(d, "BRASS", (255, 230, 158, 255), (55, 36, 20, 255), 52, 22)))
    save_symbol("bingo_ball", lambda d: (d.ellipse((8, 9, 120, 121), fill=(0, 0, 0, 85)), d.ellipse((6, 5, 118, 117), fill=(255, 247, 220, 255), outline=(18, 96, 50, 255), width=7), d.ellipse((31, 30, 93, 92), fill=(255, 255, 250, 255), outline=(255, 179, 47, 255), width=6)))
    save_symbol("multiplier_coin", lambda d: (coin(d, (255, 214, 74, 255), (67, 42, 13, 255)), centered_word(d, "X", (67, 42, 13, 255), (255, 246, 151, 255), 36, 48)))
    save_symbol("vault_sealed", lambda d: (plaque(d, (14, 18, 114, 112), (29, 32, 40, 255), (204, 164, 68, 255), 6, 12), d.ellipse((38, 37, 90, 89), outline=(238, 192, 79, 255), width=9), d.line((46, 46, 82, 82), fill=(238, 192, 79, 255), width=6), d.line((82, 46, 46, 82), fill=(238, 192, 79, 255), width=6)))
    save_symbol("vault_open", lambda d: (plaque(d, (10, 24, 84, 114), (31, 34, 42, 255), (202, 162, 65, 255), 5, 10), plaque(d, (64, 17, 119, 106), (100, 77, 32, 255), (255, 217, 82, 255), 5, 10), d.polygon(star_points(58, 66, 29, 13), fill=(255, 239, 88, 235), outline=(105, 70, 14, 255))))
    save_symbol("wild_card", lambda d: (plaque(d, (20, 9, 108, 119), (34, 22, 42, 255), (242, 199, 72, 255), 6, 8), centered_word(d, "WILD", (255, 245, 177, 255), (0, 0, 0, 255), 42, 27)))


def main() -> None:
    generate_symbols()
    print(f"Generated 9 scratch-ticket reveal icons under {SYMBOLS_DIR}")


if __name__ == "__main__":
    main()
