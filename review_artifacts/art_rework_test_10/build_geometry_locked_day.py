from __future__ import annotations

import colorsys
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "art_rework_test_04" / "environments"
CALIBRATION = ROOT.parent / "art_rework_test_09" / "calibration_refs"

CATEGORY = {
    "apartment": "apartment",
    "back_alley": "bar",
    "bar": "bar",
    "beach": "grand_casino",
    "corner_store": "apartment",
    "delta_queen": "grand_casino",
    "gas_station_casino": "grand_casino",
    "grand_casino": "grand_casino",
    "grand_casino_back_room": "bar",
    "grand_casino_cage": "bar",
    "grand_casino_high_limit": "bar",
    "house": "apartment",
    "jazz_club": "bar",
    "kitty_cat_lounge": "bar",
    "motel": "apartment",
    "motel_room": "apartment",
    "pawn_shop": "bar",
    "small_underground_casino": "bar",
}

# Small identity shifts keep each venue distinct without returning to a neon wash.
TINT = {
    "back_alley": (-0.02, 0.92, 0.91),
    "bar": (0.00, 1.00, 0.94),
    "beach": (0.00, 1.08, 1.03),
    "corner_store": (0.05, 0.96, 0.98),
    "delta_queen": (-0.02, 0.96, 0.92),
    "gas_station_casino": (0.03, 1.03, 0.97),
    "grand_casino_back_room": (-0.01, 0.94, 0.88),
    "grand_casino_cage": (0.02, 0.92, 0.94),
    "grand_casino_high_limit": (0.06, 1.00, 0.91),
    "house": (-0.01, 0.90, 0.97),
    "jazz_club": (0.00, 0.94, 0.90),
    "kitty_cat_lounge": (0.00, 1.05, 0.96),
    "motel": (0.01, 1.00, 0.98),
    "motel_room": (-0.02, 0.91, 0.96),
    "pawn_shop": (0.03, 1.00, 0.91),
    "small_underground_casino": (0.00, 0.92, 0.88),
}


def rgb_luma(rgb: tuple[int, int, int]) -> float:
    values = []
    for channel in rgb:
        value = channel / 255
        values.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
    return 0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2]


def hue_distance(a: float, b: float) -> float:
    delta = abs(a - b)
    return min(delta, 1 - delta)


def minimum_cost_assignment(costs: list[list[float]]) -> list[int]:
    """Return the minimum-cost column for each row using the Hungarian method."""
    size = len(costs)
    potentials_rows = [0.0] * (size + 1)
    potentials_columns = [0.0] * (size + 1)
    matched_row = [0] * (size + 1)
    path = [0] * (size + 1)
    for row in range(1, size + 1):
        matched_row[0] = row
        column = 0
        minimum = [math.inf] * (size + 1)
        used = [False] * (size + 1)
        while True:
            used[column] = True
            current_row = matched_row[column]
            delta = math.inf
            next_column = 0
            for candidate in range(1, size + 1):
                if used[candidate]:
                    continue
                reduced = (
                    costs[current_row - 1][candidate - 1]
                    - potentials_rows[current_row]
                    - potentials_columns[candidate]
                )
                if reduced < minimum[candidate]:
                    minimum[candidate] = reduced
                    path[candidate] = column
                if minimum[candidate] < delta:
                    delta = minimum[candidate]
                    next_column = candidate
            for candidate in range(size + 1):
                if used[candidate]:
                    potentials_rows[matched_row[candidate]] += delta
                    potentials_columns[candidate] -= delta
                else:
                    minimum[candidate] -= delta
            column = next_column
            if matched_row[column] == 0:
                break
        while True:
            previous = path[column]
            matched_row[column] = matched_row[previous]
            column = previous
            if column == 0:
                break
    result = [0] * size
    for column in range(1, size + 1):
        result[matched_row[column] - 1] = column - 1
    return result


def mapped_day_hue(hue: float, category: str) -> float:
    # Preserve naturally legible material families while translating night magenta
    # into the calibration references' coral, wood and lavender accents.
    if hue < 0.055 or hue >= 0.94:
        return 0.035 if category != "grand_casino" else 0.02
    if hue < 0.14:
        return 0.085
    if hue < 0.36:
        return 0.27
    if hue < 0.53:
        return 0.48
    if hue < 0.70:
        return 0.56
    if hue < 0.84:
        return 0.74
    return 0.02 if category != "grand_casino" else 0.76


def extract_palette(
    reference: Path, count: int = 40
) -> tuple[list[tuple[int, int, int]], dict[tuple[int, int, int], int]]:
    image = Image.open(reference).convert("RGB")
    quantized = image.quantize(colors=count, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    raw = quantized.getpalette()[: count * 3]
    palette = [tuple(raw[index : index + 3]) for index in range(0, len(raw), 3)]
    if len(set(palette)) != count:
        raise RuntimeError(f"Reference palette did not produce {count} unique colors: {reference}")
    index_counts = {
        index: pixel_count
        for pixel_count, index in quantized.getcolors(maxcolors=image.width * image.height)
    }
    usage = {palette[index]: index_counts.get(index, 0) for index in range(count)}
    return palette, usage


def tint_palette(
    palette: list[tuple[int, int, int]],
    usage: dict[tuple[int, int, int], int],
    environment: str,
) -> tuple[list[tuple[int, int, int]], dict[tuple[int, int, int], int]]:
    hue_shift, saturation_scale, value_scale = TINT.get(environment, (0.0, 1.0, 1.0))
    result = []
    result_usage = {}
    occupied: set[tuple[int, int, int]] = set()
    for rank, rgb in enumerate(sorted(palette, key=rgb_luma)):
        h, s, v = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb))
        h = (h + hue_shift) % 1
        s = max(0.05, min(0.82, s * saturation_scale))
        v = max(0.06, min(0.98, v * value_scale))
        candidate = tuple(round(channel * 255) for channel in colorsys.hsv_to_rgb(h, s, v))
        # Maintain a bijective palette even after small rounding collisions.
        while candidate in occupied:
            channel = rank % 3
            mutable = list(candidate)
            mutable[channel] = min(255, mutable[channel] + 1)
            candidate = tuple(mutable)
        occupied.add(candidate)
        result.append(candidate)
        result_usage[candidate] = usage[rgb]
    return result, result_usage


def assign_palette(
    source: list[tuple[int, int, int]],
    source_usage: dict[tuple[int, int, int], int],
    target: list[tuple[int, int, int]],
    target_usage: dict[tuple[int, int, int], int],
    category: str,
) -> dict[tuple[int, int, int], tuple[int, int, int]]:
    source_sorted = sorted(source, key=rgb_luma)
    target_sorted = sorted(target, key=rgb_luma)
    size = len(source_sorted)
    source_frequency_order = {
        color: rank / (size - 1)
        for rank, color in enumerate(sorted(source, key=lambda color: source_usage[color]))
    }
    target_frequency_order = {
        color: rank / (size - 1)
        for rank, color in enumerate(sorted(target, key=lambda color: target_usage[color]))
    }
    costs: list[list[float]] = []
    for source_rank, source_rgb in enumerate(source_sorted):
        sh, ss, _ = colorsys.rgb_to_hsv(*(channel / 255 for channel in source_rgb))
        desired_hue = mapped_day_hue(sh, category)
        row = []
        for target_rank, target_rgb in enumerate(target_sorted):
            th, ts, _ = colorsys.rgb_to_hsv(*(channel / 255 for channel in target_rgb))
            rank_gap = abs(source_rank - target_rank) / (size - 1)
            hue_gap = hue_distance(desired_hue, th)
            # Rank is dominant so line/shadow separation survives. Hue is secondary
            # and primarily chooses among colors of comparable daylight brightness.
            hue_weight = 0.30 + min(1.0, ss + ts)
            frequency_gap = abs(
                source_frequency_order[source_rgb] - target_frequency_order[target_rgb]
            )
            row.append(
                34.0 * rank_gap**2
                + 2.5 * hue_weight * hue_gap**2
                + 7.0 * frequency_gap**2
            )
        costs.append(row)
    columns = minimum_cost_assignment(costs)
    return {source_sorted[row]: target_sorted[column] for row, column in enumerate(columns)}


def source_path(environment: str) -> Path:
    exact = SOURCE / f"{environment}.png"
    if exact.is_file():
        return exact
    matches = list(SOURCE.glob(f"{environment}_*.png"))
    if len(matches) != 1:
        raise RuntimeError(f"Expected one source for {environment}, found {matches}")
    return matches[0]


def make_contact_sheet(phase: str) -> None:
    files = sorted((ROOT / phase).glob("*.png"))
    width, height, label_height = 450, 215, 24
    sheet = Image.new("RGB", (width * 3, (height + label_height) * 6), (8, 9, 16))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, path in enumerate(files):
        x = index % 3 * width
        y = index // 3 * (height + label_height)
        image = Image.open(path).convert("RGB").resize((width, height), Image.Resampling.NEAREST)
        sheet.paste(image, (x, y))
        name = path.stem.removesuffix(f"_{phase}").replace("_", " ").upper()
        draw.text((x + 6, y + height + 7), f"{name} - {phase.upper()}", fill=(228, 229, 238), font=font)
    sheet.save(ROOT / f"{phase}_contact_sheet.png", optimize=True)


def make_pair_sheet() -> None:
    files = sorted((ROOT / "noon").glob("*_noon.png"))
    width, height, label_height = 450, 215, 24
    sheet = Image.new("RGB", (width * 4, (height + label_height) * 9), (8, 9, 16))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, day_path in enumerate(files):
        environment = day_path.stem.removesuffix("_noon")
        night_path = ROOT / "midnight" / f"{environment}_midnight.png"
        row, pair_column = divmod(index, 2)
        for phase_column, (phase, path) in enumerate((("NOON", day_path), ("MIDNIGHT", night_path))):
            x = (pair_column * 2 + phase_column) * width
            y = row * (height + label_height)
            image = Image.open(path).convert("RGB").resize((width, height), Image.Resampling.NEAREST)
            sheet.paste(image, (x, y))
            label = environment.replace("_", " ").upper()
            draw.text((x + 6, y + height + 7), f"{label} - {phase}", fill=(228, 229, 238), font=font)
    sheet.save(ROOT / "day_night_contact_sheet.png", optimize=True)


def main() -> None:
    (ROOT / "noon").mkdir(parents=True, exist_ok=True)
    (ROOT / "midnight").mkdir(parents=True, exist_ok=True)
    (ROOT / "calibration_refs").mkdir(parents=True, exist_ok=True)
    for reference in CALIBRATION.glob("*.png"):
        shutil.copy2(reference, ROOT / "calibration_refs" / reference.name)

    references = {
        "apartment": extract_palette(CALIBRATION / "apartment_noon_calibration.png"),
        "bar": extract_palette(CALIBRATION / "bar_noon_calibration.png"),
        "grand_casino": extract_palette(CALIBRATION / "grand_casino_noon_calibration.png"),
    }
    palette_maps = {}
    for environment, category in CATEGORY.items():
        source = source_path(environment)
        night_destination = ROOT / "midnight" / f"{environment}_midnight.png"
        shutil.copy2(source, night_destination)
        night = Image.open(source).convert("RGB")
        pixels = list(night.getdata())
        source_palette = sorted(set(pixels), key=rgb_luma)
        if len(source_palette) != 40:
            raise RuntimeError(f"{environment} has {len(source_palette)} colors, expected 40")
        source_usage = {color: pixels.count(color) for color in source_palette}
        reference_palette, reference_usage = references[category]
        target_palette, target_usage = tint_palette(
            reference_palette, reference_usage, environment
        )
        mapping = assign_palette(
            source_palette,
            source_usage,
            target_palette,
            target_usage,
            category,
        )
        day = Image.new("RGB", night.size)
        day.putdata([mapping[pixel] for pixel in pixels])
        day.save(ROOT / "noon" / f"{environment}_noon.png", optimize=True)
        palette_maps[environment] = [
            {
                "from": "#" + "".join(f"{channel:02x}" for channel in source_rgb),
                "to": "#" + "".join(f"{channel:02x}" for channel in mapping[source_rgb]),
                "count": pixels.count(source_rgb),
            }
            for source_rgb in source_palette
        ]

    (ROOT / "palette_maps.json").write_text(json.dumps(palette_maps, indent=2) + "\n", encoding="utf-8")
    make_contact_sheet("noon")
    make_contact_sheet("midnight")
    make_pair_sheet()


if __name__ == "__main__":
    main()
