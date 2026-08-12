#!/usr/bin/env python3
"""Generate and verify scratch-ticket geometry against the shipped _pro art.

The JSON emitted by --generate is the runtime source of truth.  Geometry is
measured as individual connected components; no repeated pitch is inferred.
Crossword is measured too, but remains decision_required because its printed
puzzle/content disagreement needs the owner's Phase 5 choice.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
LAYERS = ROOT / "assets" / "art" / "scratch_tickets" / "layers"
DATA = ROOT / "data" / "games" / "scratch_ticket_regions.json"
OUT = ROOT / ".tmp" / "scratch_alignment_audit"
SIZES = {"two_fer": (500, 224), "lucky_7s": (354, 356), "tic_tac_gold": (354, 356),
         "crossword_corner": (548, 356), "bonus_bingo": (548, 356),
         "high_roller_holdem": (292, 366), "golden_vault": (292, 366)}


def image_data(type_id: str):
    path = LAYERS / f"{type_id}_background_pro.png"
    image = Image.open(path).convert("RGB")
    return path, image, np.asarray(image).astype(int).mean(axis=2)


def components(type_id, bright, threshold, min_px, max_px, y_band, fill=.6):
    _, image, lum = image_data(type_id)
    w, h = image.size
    selected = lum > threshold if bright else lum < threshold
    band = np.zeros_like(selected)
    band[int(y_band[0] * h):int(y_band[1] * h)] = True
    labels, _ = ndimage.label(selected & band)
    found = []
    for index, slices in enumerate(ndimage.find_objects(labels), 1):
        if slices is None:
            continue
        ys, xs = slices
        bw, bh = xs.stop - xs.start, ys.stop - ys.start
        if not (min_px[0] <= bw <= max_px[0] and min_px[1] <= bh <= max_px[1]):
            continue
        if (labels[slices] == index).sum() / (bw * bh) < fill:
            continue
        found.append((xs.start / w, ys.start / h, bw / w, bh / h))
    found.sort(key=lambda r: (round(r[1], 3), r[0]))
    return found


def entry(id_, section, label, rect, shape="rect", **extra):
    value = {"id": id_, "section_id": section, "label": label, "shape": shape,
             "art_rect": [round(float(v), 7) for v in rect]}
    value.update(extra)
    return value


def measured_regions(type_id: str):
    if type_id == "two_fer":
        wells = components(type_id, True, 170, (200, 80), (600, 300), (.40, .80), .55)
        return [entry(f"play_{i:02d}", "play", f"SPOT {i+1}", r) for i, r in enumerate(wells)]
    if type_id == "lucky_7s":
        wells = components(type_id, False, 50, (60, 60), (200, 200), (.38, .95), .55)
        play_wells = wells[:8]
        top = sorted(play_wells, key=lambda r: r[1])[:4]
        bottom = sorted(play_wells, key=lambda r: r[1])[4:]
        top.sort(key=lambda r: r[0]); bottom.sort(key=lambda r: r[0])
        play_wells = [top[0], bottom[0], *top[1:], *bottom[1:]]
        out = [entry(f"winning_numbers_{i:02d}", "winning_numbers", f"WIN {i+1}", play_wells[i], "ellipse") for i in range(2)]
        out += [entry(f"your_numbers_{i+2:02d}", "your_numbers", f"YOUR {i+1}", play_wells[i+2], "ellipse",
                      content_split=[0.0, 0.0, 1.0, 0.68]) for i in range(6)]
        out.append(entry("bonus_08", "bonus", "BONUS", wells[8]))
        return out
    if type_id == "tic_tac_gold":
        wells = [r for r in components(type_id, True, 185, (110, 80), (230, 230), (.38, .85), .70) if r[0] < .70]
        out = [entry(f"board_{i:02d}", "board", f"GRID {i+1}", r) for i, r in enumerate(wells[:9])]
        out.append(entry("bonus_09", "bonus", "BONUS", (773/1053, 756/1494, 201/1053, 209/1494)))
        return out
    if type_id == "bonus_bingo":
        callers = components(type_id, True, 200, (30, 30), (50, 50), (.28, .43), .60)
        cells = components(type_id, True, 195, (50, 40), (60, 52), (.48, .80), .75)
        out = [entry(f"callers_{i:02d}", "callers", f"CALL {i+1}", r, "ellipse") for i, r in enumerate(callers)]
        card_major = []
        for left, right in ((0.0,.25),(.25,.50),(.50,.74),(.74,1.0)):
            card = [r for r in cells if left <= r[0] < right]
            card.sort(key=lambda r: (round(r[1], 2), r[0]))
            card_major.extend(card)
        for i, r in enumerate(card_major):
            card, cell = i // 25, i % 25
            out.append(entry(f"card_{card+1}_{i+24:02d}", f"card_{card+1}", f"CARD {card+1}-{cell+1}", r))
        return out
    if type_id == "high_roller_holdem":
        wells = components(type_id, True, 190, (80, 90), (200, 260), (.30, .90), .70)
        out = [entry(f"your_hand_{i:02d}", "your_hand", f"YOUR CARD {i+1}", wells[i]) for i in range(5)]
        out += [entry(f"dealer_hand_{i+5:02d}", "dealer_hand", f"DEALER CARD {i+1}", wells[i+5]) for i in range(5)]
        out.append(entry("wild_10", "wild", "WILD", (467/1122, 1058/1402, 186/1122, 88/1402)))
        return out
    if type_id == "golden_vault":
        wells = components(type_id, True, 120, (200, 30), (900, 110), (.33, .95), .75)
        labels = [("multiplier_00", "multiplier", "MULTIPLIER")]
        labels += [(f"cash_ladder_{i:02d}", "cash_ladder", f"RUNG {i}") for i in range(1, 6)]
        labels += [("gold_bar_06", "gold_bar", "GOLD BAR"), ("final_vault_07", "final_vault", "FINAL VAULT")]
        return [entry(*labels[i], wells[i]) for i in range(8)]
    if type_id == "crossword_corner":
        # Detector finds the 27 printed grid cells and 18 printed letter wells.
        found = components(type_id, True, 180, (40, 30), (110, 160), (.30, .82), .70)
        grid, bank = [r for r in found if r[0] < .56], [r for r in found if r[0] >= .56]
        # Keep the currently shipped mechanical mapping inert until Phase 5 is chosen.
        legacy = []
        for i in range(18):
            col, row = i % 6, i // 6
            cw, ch = (0.378 - .006 * 5) / 6, (0.37 - .012 * 2) / 3
            legacy.append(entry(f"letter_bank_{i:02d}", "letter_bank", f"LETTER {i+1}",
                                (.585 + col*(cw+.006), .42 + row*(ch+.012), cw, ch)))
        cells = [(1,1),(1,9),(2,1),(2,7),(2,9),(3,1),(3,7),(3,9),(4,1),(4,2),(4,3),(4,4),(4,5),(4,7),(4,9),(5,4),(5,7),(6,3),(6,4),(6,5),(6,6),(7,4),(9,2),(9,3),(9,4),(9,5),(9,6)]
        for i, (col, row) in enumerate(cells, 18):
            legacy.append(entry(f"crossword_{i:02d}", "crossword", f"GRID {col+1},{row+1}",
                                (.06+col*.50/11, .32+row*.48/10, .50/11, .48/10)))
        return legacy, {"printed_grid_wells": [list(r) for r in grid], "printed_letter_wells": [list(r) for r in bank]}
    raise KeyError(type_id)


def generate():
    payload = {"layout_version": 9, "source_art": {}, "regions": {}, "alignment_status": {}}
    for type_id in SIZES:
        path, image, _ = image_data(type_id)
        payload["source_art"][type_id] = {"file": path.name, "w": image.width, "h": image.height,
                                                  "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        result = measured_regions(type_id)
        if type_id == "crossword_corner":
            payload["regions"][type_id], payload["crossword_detected_reference"] = result
            payload["alignment_status"][type_id] = "decision_required"
        else:
            payload["regions"][type_id] = result
            payload["alignment_status"][type_id] = "measured"
    DATA.parent.mkdir(parents=True, exist_ok=True)
    DATA.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"generated {DATA}")


def frame(size, art_size):
    scale = min(size[0]/art_size[0], size[1]/art_size[1])
    return art_size[0]*scale, art_size[1]*scale


def old_regions(type_id):
    out = []
    if type_id == "two_fer":
        out = [(0.105+i*.292, .495, .225, .225) for i in range(3)]
    elif type_id == "lucky_7s":
        out = [(.095, .425+i*.145, .145, .105) for i in range(2)]
        out += [(.335+(i%3)*.205, .425+(i//3)*.145, .145, .105) for i in range(6)]
        out += [(.285, .755, .19, .13)]
    elif type_id == "tic_tac_gold":
        out = [(.095+(i%3)*.205, .42+(i//3)*.12, .18, .105) for i in range(9)] + [(.73,.50,.21,.17)]
    elif type_id == "bonus_bingo":
        out = [(.175+(i%12)*.058, .295+(i//12)*.065, .038, .05) for i in range(24)]
        for card in range(4):
            out += [(.053+card*.231+(i%5)*.040, .51+(i//5)*.052, .038, .05) for i in range(25)]
    elif type_id == "high_roller_holdem":
        out = [(.132+i*.151,.338,.12,.164) for i in range(5)] + [(.132+i*.151,.558,.12,.145) for i in range(5)] + [(.405,.748,.19,.075)]
    elif type_id == "golden_vault":
        out = [(.17,.40,.66,.06)] + [(.12,.51+i*.052,.76,.043) for i in range(5)] + [(.11,.80,.34,.07),(.55,.80,.34,.07)]
    return out


def metric(actual, measured, screen):
    center = (((actual[0]+actual[2]/2-measured[0]-measured[2]/2)*screen[0])**2 +
              ((actual[1]+actual[3]/2-measured[1]-measured[3]/2)*screen[1])**2)**.5
    size = max(abs(actual[2]-measured[2])/measured[2], abs(actual[3]-measured[3])/measured[3])*100
    return center, size


def report():
    data = json.loads(DATA.read_text(encoding="utf-8"))
    print("ticket,before_center_px,before_size_pct,after_center_px,after_size_pct")
    for type_id in SIZES:
        if data["alignment_status"].get(type_id) != "measured":
            print(f"{type_id},PENDING_PHASE_5,PENDING_PHASE_5,PENDING_PHASE_5,PENDING_PHASE_5")
            continue
        expected = measured_regions(type_id)
        source = data["source_art"][type_id]
        old_screen, new_screen = SIZES[type_id], frame(SIZES[type_id], (source["w"], source["h"]))
        before = [metric(old, measured["art_rect"], old_screen) for old, measured in zip(old_regions(type_id), expected)]
        after = [metric(value["art_rect"], measured["art_rect"], new_screen) for value, measured in zip(data["regions"][type_id], expected)]
        print(f"{type_id},{max(v[0] for v in before):.2f},{max(v[1] for v in before):.2f},{max(v[0] for v in after):.2f},{max(v[1] for v in after):.2f}")


def verify(write_overlays=False):
    data = json.loads(DATA.read_text(encoding="utf-8"))
    failures, worst_center, worst_size = [], 0.0, 0.0
    if write_overlays:
        OUT.mkdir(parents=True, exist_ok=True)
    for type_id, entries in data["regions"].items():
        source = data["source_art"][type_id]
        path = LAYERS/source["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != source["sha256"]:
            failures.append(f"{type_id}: source SHA mismatch")
            continue
        if data["alignment_status"].get(type_id) != "measured":
            print(f"SKIP {type_id}: owner Phase 5 decision required")
            continue
        expected = measured_regions(type_id)
        fw, fh = frame(SIZES[type_id], (source["w"], source["h"]))
        for actual, measured in zip(entries, expected):
            ar, mr = actual["art_rect"], measured["art_rect"]
            center = (((ar[0]+ar[2]/2-mr[0]-mr[2]/2)*fw)**2 + ((ar[1]+ar[3]/2-mr[1]-mr[3]/2)*fh)**2)**.5
            size_error = max(abs(ar[2]-mr[2])/mr[2], abs(ar[3]-mr[3])/mr[3]) * 100
            worst_center, worst_size = max(worst_center, center), max(worst_size, size_error)
            if center > 1.0 or size_error > 5.0:
                failures.append(f"{type_id}/{actual['id']}: center={center:.2f}px size={size_error:.2f}%")
        if write_overlays:
            image = Image.open(path).convert("RGBA")
            draw = ImageDraw.Draw(image)
            for value in entries:
                x,y,w,h = value["art_rect"]
                draw.rectangle((x*image.width,y*image.height,(x+w)*image.width,(y+h)*image.height), outline="magenta", width=3)
            image.save(OUT/f"measured_{type_id}.png")
    print(f"VERIFY worst_center={worst_center:.3f}px worst_size={worst_size:.3f}% checked=6 pending=crossword_corner")
    if failures:
        print("\n".join(failures))
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate", action="store_true")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--overlay", action="store_true")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()
    if args.generate:
        generate()
    if args.verify or args.overlay or not args.generate:
        result = verify(args.overlay)
        if args.report:
            report()
        raise SystemExit(result)


if __name__ == "__main__":
    main()
