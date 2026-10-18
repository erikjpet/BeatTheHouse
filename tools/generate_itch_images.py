"""Generate the version 0.6 itch.io storefront and theme artwork.

The theme deliberately uses the live 0.6 visual tokens and real 0.6 captures:
near-black/navy surfaces, cyan interaction lines, magenta pressure accents,
yellow focus marks, hard pixel edges, and restrained scanlines.

Outputs to branding/itch/0.6/:
  01_cover_logo.png             630x500   (storefront cover)
  06_logo_background.png        1280x720  (full gallery splash)
  00_itch_banner.png            1920x480  (displayed by itch at 960x240)
  00_itch_page_background.png   3840x2160 (4K-safe, centered, fixed, no-repeat)
  00_itch_embed_background.png  1600x900  (matches the configured game frame)
"""

from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets" / "art"
BRANDING = ROOT / "branding"
OUT = BRANDING / "itch" / "0.6"
OUT.mkdir(parents=True, exist_ok=True)

CAPTURE_BLUE_NOTE = OUT / "02_environment_blue_note.png"
CAPTURE_GRAND_CASINO = OUT / "03_environment_grand_casino.png"
LOGO = ART / "ui" / "beat_the_house_logo.png"


def rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


DARK = rgb("#05060a")
DARK_2 = rgb("#0b0b18")
DARK_3 = rgb("#101427")
PINK = rgb("#ff2d78")
PINK_2 = rgb("#ff6eb4")
CYAN = rgb("#00f5ff")
CYAN_2 = rgb("#0096a6")
TEAL = rgb("#00ffd5")
YELLOW = rgb("#ffe45c")
AMBER = rgb("#ffb32d")
SOFT = rgb("#d8e8ea")


def load_capture(path: Path, fallback: str) -> Image.Image:
    if path.exists():
        return Image.open(path).convert("RGBA")
    return Image.open(ART / "environments" / f"{fallback}.png").convert("RGBA")


def cover(image: Image.Image, size: tuple[int, int], *, pixel: bool = True) -> Image.Image:
    width, height = size
    scale = max(width / image.width, height / image.height)
    result = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.NEAREST if pixel else Image.Resampling.LANCZOS,
    )
    left = (result.width - width) // 2
    top = (result.height - height) // 2
    return result.crop((left, top, left + width, top + height))


def scene_only(image: Image.Image) -> Image.Image:
    """Remove the 0.6 HUD while retaining the in-game environment view."""
    if image.width >= 1200 and image.height >= 700:
        return image.crop((0, 126, image.width, image.height))
    return image


def darken(image: Image.Image, amount: float, saturation: float = 0.9) -> Image.Image:
    image = ImageEnhance.Color(image.convert("RGB")).enhance(saturation)
    image = ImageEnhance.Brightness(image).enhance(amount)
    return image.convert("RGBA")


def gradient_base(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    width, height = size
    y = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None, None]
    top_array = np.array(top, dtype=np.float32)[None, None, :]
    bottom_array = np.array(bottom, dtype=np.float32)[None, None, :]
    row = top_array * (1.0 - y) + bottom_array * y
    data = np.repeat(row, width, axis=1).astype(np.uint8)
    return Image.fromarray(data, "RGB").convert("RGBA")


def add_radial_glow(
    image: Image.Image,
    center: tuple[int, int],
    radius: tuple[int, int],
    color: tuple[int, int, int],
    alpha: int,
    blur: int,
) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    cx, cy = center
    rx, ry = radius
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=color + (alpha,))
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur)))


def add_scanlines(image: Image.Image, alpha: int = 16, spacing: int = 4) -> None:
    lines = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(lines)
    for y in range(0, image.height, spacing):
        draw.line((0, y, image.width, y), fill=(0, 0, 0, alpha), width=1)
    image.alpha_composite(lines)


def add_neon_line(
    image: Image.Image,
    points: list[tuple[int, int]],
    color: tuple[int, int, int],
    width: int = 2,
    alpha: int = 255,
) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.line(points, fill=color + (min(alpha, 180),), width=max(6, width * 4), joint="curve")
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(max(5, width * 3))))
    ImageDraw.Draw(image).line(points, fill=color + (alpha,), width=width, joint="curve")


def add_pixel_icon(image: Image.Image, name: str, position: tuple[int, int], scale: int, alpha: int) -> None:
    icon = Image.open(ART / "games" / f"{name}.png").convert("RGBA")
    icon = icon.resize((icon.width * scale, icon.height * scale), Image.Resampling.NEAREST)
    icon.putalpha(icon.getchannel("A").point(lambda value: value * alpha // 255))
    image.alpha_composite(icon, position)


def fitted_logo(maximum_size: tuple[int, int]) -> Image.Image:
    """Load the exact transparent logo used by the in-game main menu."""
    logo = Image.open(LOGO).convert("RGBA")
    scale = min(maximum_size[0] / logo.width, maximum_size[1] / logo.height)
    return logo.resize(
        (round(logo.width * scale), round(logo.height * scale)),
        Image.Resampling.LANCZOS,
    )


def composite_logo_with_glow(
    image: Image.Image,
    logo: Image.Image,
    position: tuple[int, int],
    glow_color: tuple[int, int, int] = CYAN,
    glow_alpha: int = 92,
    blur: int = 22,
) -> None:
    glow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    silhouette = Image.new("RGBA", logo.size, glow_color + (0,))
    silhouette.putalpha(logo.getchannel("A").point(lambda value: value * glow_alpha // 255))
    glow.alpha_composite(silhouette, position)
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur)))
    image.alpha_composite(logo, position)


def add_center_scrim(
    image: Image.Image,
    box: tuple[int, int, int, int],
    alpha: int,
    blur: int,
) -> None:
    scrim = Image.new("RGBA", image.size, (0, 0, 0, 0))
    ImageDraw.Draw(scrim).rectangle(box, fill=DARK + (alpha,))
    image.alpha_composite(scrim.filter(ImageFilter.GaussianBlur(blur)))


def edge_scene_layer(source: Image.Image, size: tuple[int, int], side: str) -> Image.Image:
    width, height = size
    panel = cover(scene_only(source), size)
    panel = darken(panel, 0.30, 0.78)
    alpha = Image.new("L", size)
    alpha_pixels = np.zeros((height, width), dtype=np.uint8)
    ramp = np.linspace(205, 0, width, dtype=np.uint8)
    if side == "right":
        ramp = ramp[::-1]
    alpha_pixels[:] = ramp
    alpha = Image.fromarray(alpha_pixels, "L")
    panel.putalpha(alpha)
    return panel


def make_cover_photo() -> Path:
    size = (630, 500)
    source = scene_only(load_capture(CAPTURE_GRAND_CASINO, "grand_casino"))
    image = darken(cover(source, size), 0.48, 0.84)
    image.alpha_composite(Image.new("RGBA", size, DARK + (58,)))
    add_radial_glow(image, (315, 238), (270, 190), CYAN, 32, 66)
    add_radial_glow(image, (315, 285), (230, 165), PINK, 34, 62)
    add_center_scrim(image, (20, 84, 610, 376), 128, 24)

    logo = fitted_logo((590, 255))
    logo_position = ((size[0] - logo.width) // 2, 118)
    composite_logo_with_glow(image, logo, logo_position, CYAN, 92, 16)

    add_pixel_icon(image, "cards", (71, 392), 2, 205)
    add_pixel_icon(image, "roulette", (283, 392), 2, 220)
    add_pixel_icon(image, "dice", (495, 392), 2, 205)
    add_neon_line(image, [(0, 14), (630, 14)], PINK, 3, 245)
    add_neon_line(image, [(0, 486), (630, 486)], CYAN, 2, 225)
    add_scanlines(image, alpha=10, spacing=4)

    output = OUT / "01_cover_logo.png"
    image.convert("RGB").save(output, optimize=True)
    return output


def make_logo_background() -> Path:
    size = (1280, 720)
    source = scene_only(load_capture(CAPTURE_GRAND_CASINO, "grand_casino"))
    image = darken(cover(source, size), 0.46, 0.82)
    image.alpha_composite(Image.new("RGBA", size, DARK + (62,)))
    add_radial_glow(image, (640, 330), (510, 300), CYAN, 34, 105)
    add_radial_glow(image, (640, 385), (430, 245), PINK, 32, 95)
    add_center_scrim(image, (98, 100, 1182, 620), 126, 38)

    logo = fitted_logo((1080, 430))
    logo_position = ((size[0] - logo.width) // 2, 145)
    composite_logo_with_glow(image, logo, logo_position, CYAN, 96, 24)

    add_neon_line(image, [(0, 18), (1280, 18)], PINK, 4, 245)
    add_neon_line(image, [(0, 702), (1280, 702)], CYAN, 3, 230)
    add_scanlines(image, alpha=11, spacing=4)

    output = OUT / "06_logo_background.png"
    image.convert("RGB").save(output, optimize=True)
    return output


def update_gallery_manifest(cover: Path, logo_background: Path) -> None:
    manifest_path = OUT / "manifest.json"
    if not manifest_path.exists():
        return
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    captures = manifest.setdefault("captures", [])

    def entry(path: Path, caption: str) -> dict:
        with Image.open(path) as image:
            width, height = image.size
        return {
            "caption": caption,
            "file": path.name,
            "height": height,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "width": width,
        }

    replacements = {
        cover.name: entry(cover, "Beat the House 0.6 storefront cover using the in-game logo"),
        logo_background.name: entry(logo_background, "Full Beat the House logo over the Grand Casino"),
    }
    updated = []
    for capture in captures:
        filename = capture.get("file", "")
        updated.append(replacements.pop(filename, capture))
    updated.extend(replacements.values())
    manifest["captures"] = updated
    manifest_path.write_text(json.dumps(manifest, indent="\t") + "\n", encoding="utf-8")


def make_banner() -> Path:
    size = (1920, 480)
    source = scene_only(load_capture(CAPTURE_GRAND_CASINO, "grand_casino"))
    image = darken(cover(source, size), 0.42, 0.82)

    # Quiet the center behind the marquee while retaining the current casino at the edges.
    shade = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shade)
    draw.rectangle((0, 0, size[0], size[1]), fill=DARK + (54,))
    draw.rectangle((320, 20, 1600, 460), fill=DARK + (135,))
    image.alpha_composite(shade.filter(ImageFilter.GaussianBlur(28)))
    add_radial_glow(image, (960, 220), (560, 190), CYAN, 24, 80)
    add_radial_glow(image, (960, 265), (460, 160), PINK, 24, 72)

    logo = fitted_logo((1180, 446))
    logo_position = ((size[0] - logo.width) // 2, (size[1] - logo.height) // 2)
    composite_logo_with_glow(image, logo, logo_position, CYAN, 88, 20)

    add_neon_line(image, [(0, 16), (1920, 16)], PINK, 3, 245)
    add_neon_line(image, [(0, 464), (1920, 464)], CYAN, 2, 210)
    add_scanlines(image, alpha=10, spacing=4)

    output = OUT / "00_itch_banner.png"
    image.convert("RGB").save(output, optimize=True)
    return output


def make_page_background() -> Path:
    # itch.io renders page backgrounds at native size and does not offer a
    # background-size: cover control. A 4K canvas therefore avoids exposed
    # edges on common wide and high-DPI displays while remaining centered.
    size = (3840, 2160)
    blue_note = darken(cover(scene_only(load_capture(CAPTURE_BLUE_NOTE, "jazz_club")), size), 0.34, 0.76)
    grand_casino = darken(cover(scene_only(load_capture(CAPTURE_GRAND_CASINO, "grand_casino")), size), 0.34, 0.76)

    # Blend two real 0.6 rooms across the full canvas so there are no hard
    # side panels or visible crop boundaries at different browser widths.
    blend_mask_data = np.zeros((size[1], size[0]), dtype=np.uint8)
    blend_ramp = np.clip((np.arange(size[0], dtype=np.float32) - 1280.0) / 1280.0, 0.0, 1.0)
    blend_mask_data[:] = np.round(blend_ramp * 255.0).astype(np.uint8)
    scene = Image.composite(grand_casino, blue_note, Image.fromarray(blend_mask_data, "L"))
    image = gradient_base(size, DARK_3, DARK)
    image = Image.blend(image, scene, 0.78)

    add_radial_glow(image, (790, 500), (720, 760), PINK, 46, 240)
    add_radial_glow(image, (3050, 640), (760, 860), CYAN, 44, 250)
    add_radial_glow(image, (1920, 560), (1080, 760), rgb("#142044"), 48, 260)

    # The live itch page has a 1600px game frame. This 1840px quiet corridor
    # allows for page padding and remains useful when the viewport is cropped.
    x = np.arange(size[0], dtype=np.float32)
    distance = np.abs(x - size[0] / 2.0)
    quiet = 1.0 - np.clip((distance - 920.0) / 520.0, 0.0, 1.0)
    corridor_alpha = np.round(quiet * 190.0 + 10.0).astype(np.uint8)
    corridor_alpha = np.repeat(corridor_alpha[None, :], size[1], axis=0)
    corridor = Image.new("RGBA", size, DARK + (255,))
    corridor.putalpha(Image.fromarray(corridor_alpha, "L"))
    image.alpha_composite(corridor)

    # Fade all four outer edges into the configured BG color, so displays
    # larger than 4K still transition cleanly instead of showing a hard seam.
    edge_x = np.minimum(np.arange(size[0]), np.arange(size[0])[::-1]).astype(np.float32)
    edge_y = np.minimum(np.arange(size[1]), np.arange(size[1])[::-1]).astype(np.float32)
    fade_x = 1.0 - np.clip(edge_x / 260.0, 0.0, 1.0)
    fade_y = 1.0 - np.clip(edge_y / 220.0, 0.0, 1.0)
    edge_fade = np.maximum(fade_y[:, None], fade_x[None, :])
    edge_alpha = np.round(edge_fade * 208.0).astype(np.uint8)
    edge_layer = Image.new("RGBA", size, DARK + (255,))
    edge_layer.putalpha(Image.fromarray(edge_alpha, "L"))
    image.alpha_composite(edge_layer)

    # Low-contrast pixel motifs live well outside the 1600px content area.
    add_neon_line(image, [(120, 290), (720, 290), (720, 510), (920, 510)], PINK, 4, 172)
    add_neon_line(image, [(3720, 290), (3120, 290), (3120, 510), (2920, 510)], CYAN, 4, 172)
    add_neon_line(image, [(3720, 1650), (3120, 1650), (3120, 1870), (2920, 1870)], CYAN, 4, 138)
    add_pixel_icon(image, "roulette", (760, 520), 8, 112)
    add_pixel_icon(image, "cards", (720, 1460), 7, 82)
    add_pixel_icon(image, "slot", (2824, 520), 8, 108)
    add_pixel_icon(image, "dice", (2940, 1490), 7, 80)

    details = ImageDraw.Draw(image)
    for px, py, color in [
        (210, 160, YELLOW), (610, 910, CYAN), (930, 1890, PINK_2),
        (2910, 690, AMBER), (3410, 1110, TEAL), (3690, 1990, YELLOW),
    ]:
        details.rectangle((px, py, px + 9, py + 9), fill=color + (145,))
        details.rectangle((px - 6, py + 4, px + 15, py + 5), fill=color + (72,))
    add_scanlines(image, alpha=12, spacing=4)

    output = OUT / "00_itch_page_background.png"
    image.convert("RGB").save(output, optimize=True)
    return output


def make_embed_background() -> Path:
    # The live itch page declares a 1600x900 game frame, so this image must match it.
    size = (1600, 900)
    source = scene_only(load_capture(CAPTURE_GRAND_CASINO, "grand_casino"))
    image = darken(cover(source, size), 0.48, 0.84)
    image.alpha_composite(Image.new("RGBA", size, DARK + (72,)))
    add_radial_glow(image, (800, 450), (470, 270), CYAN, 34, 115)

    focus = Image.new("RGBA", size, (0, 0, 0, 0))
    focus_draw = ImageDraw.Draw(focus)
    focus_draw.rectangle((560, 320, 1040, 580), fill=DARK + (150,), outline=CYAN + (170,), width=2)
    focus_draw.rectangle((576, 336, 1024, 564), outline=PINK + (130,), width=2)
    image.alpha_composite(focus.filter(ImageFilter.GaussianBlur(5)))
    image.alpha_composite(focus)

    logo = fitted_logo((660, 250))
    logo_position = ((size[0] - logo.width) // 2, 50)
    composite_logo_with_glow(image, logo, logo_position, PINK, 72, 20)

    add_neon_line(image, [(0, 12), (1600, 12)], PINK, 3, 235)
    add_neon_line(image, [(0, 888), (1600, 888)], CYAN, 2, 220)
    add_scanlines(image, alpha=13, spacing=4)

    output = OUT / "00_itch_embed_background.png"
    image.convert("RGB").save(output, optimize=True)
    return output


def main() -> None:
    cover = make_cover_photo()
    logo_background = make_logo_background()
    outputs = [cover, logo_background, make_banner(), make_page_background(), make_embed_background()]
    update_gallery_manifest(cover, logo_background)
    for path in outputs:
        with Image.open(path) as image:
            print(f"{path.relative_to(ROOT)}  {image.width}x{image.height}  {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
