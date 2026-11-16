"""Guarded non-active Hidden table assembly from exact generated and R2 sources.

Only the parent runs this worker. All source, own-underlay calibration, physical
clearance and storage preflight precede its first QA write. No children, original
recipe execution, color transforms, active files, saves or TEST changes.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import zipfile
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import Layout, validate_layout

ROOM = "small_underground_casino"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-HIDDENTRIAL-20261116")
ART = "assets/art/environments/" + ROOM + "/"
BACKGROUND, FRONT = ART + "background.png", ART + "counters/punchline_right_table.png"
MANIFEST, INDEX = "data/art/environments/" + ROOM + ".json", "data/art/environments/index.json"
SIZE, RAW_SIZE = (1800, 860), (1815, 867)
SOURCE_DIR = "review_artifacts/environment_art_sources/hidden-spatial-r1"
RAW_REL = SOURCE_DIR + "/hidden-spatial-r1.png"
RAW_SHA = "8a46e49c462f741b75c79099bf6480092fb11a498bd138fc5e9498be5a3bee99"
BASELINE_SEAL = "4c43fd48d180010a801f511c885d44b983c67c2fbb7fb4eac25c94fbdab027ff"
MASTER_SHA = "884b50866cd064e6a04ca3f49f8fae3da5d996d92779eca533a1d743492efb87"
MANIFEST_SHA = "bb4dc0bfb830fc9d7ad73179b8d1b9ee0fb7c0e6e59fafc42f9a54aa78bef568"
ARCHIVE = "review_artifacts/environment_art_sources/small_underground_casino-v1-r2/small_underground_casino-v1-r2-source.zip"
ARCHIVE_SHA = "6ed40caf03d5a694bbef49f338dd26f5e4f4f61341a9166c04121312632c938f"
MEMBERS = {
    "source/background-guide-v1.png": "27156ddb75d7a70f41d1e78fb333f4ef8dba2a56184104ce1c5b4181bfbb341d",
    "source/floor-material-v1.png": "159b69b0466557a9b4d3140deb635d80032d4396f948d51ad73676dad18c437c",
    "recipe/assemble_hidden_v1r2.py": "d21ddb8deb31b105d390df54f6fdfdd79f3f146fcbf6436188da9da0d3173768",
    "package/" + BACKGROUND: MASTER_SHA,
}
OLD_BLOCKED = ((98, 149, 345, 244), (432, 137, 730, 249), (742, 86, 855, 271), (37, 166, 112, 273))
SOURCE_Y, TARGET_Y = (0,22,34,44,60,66,69,78,104,113,249,267), (0,26,34,42,56,62,68,76,102,110,236,245)
SOURCE_X = (0,96,169,240,311,383,455,527,600,671,744,816,888,900)
TARGET_X = (0,96,168,240,312,384,456,528,600,672,744,816,888,900)
PROTECTED = {"cart_body": (80,376,140,164), "cart_top": (96,336,108,40),
             "door": (1488,176,216,356), "middle_glint_envelope": (1062,264,16,16)}
COUNTER = (876,284,572,196)
TABLES = (
    {"id": "left", "old": (200,308,484,172), "source_y": (320,424,428,448,472,536,544),
     "target_y": (308,440,444,450,466,506,510), "source_far": (278,634), "source_near": (220,695),
     "target_far": (248,668), "target_near": (200,684), "source_apron": (234,683),
     "leg_centers": (360,540), "source_legs": ((300,339),(576,616))},
    {"id": "right", "old": (876,284,572,196), "source_y": (310,422,428,448,472,536,544),
     "target_y": (284,436,440,446,466,506,510), "source_far": (912,1394), "source_near": (856,1455),
     "target_far": (916,1414), "target_near": (876,1448), "source_apron": (873,1440),
     "leg_centers": (948,1388), "source_legs": ((952,992),(1333,1373))},
)
ANIMATION_IDS = tuple([f"string_core_{i}" for i in range(10)] + [f"long_pink_drift_{i}" for i in range(6)] +
    [f"thin_bobbing_ribbon_{i}" for i in range(5)] + [f"teal_material_glint_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
CONTROLS = ("data/environments/placement_surfaces.json", "data/environments/developer_placement_overrides.json",
            "scripts/ui/pixel_scene_canvas.gd", "scripts/ui/environment_art_renderer.gd", "scripts/ui/environment_art_pack.gd")
CONTEXT_ROOT = Path("E:/CodexQA/BTH/runs/BTH-ENVART-HIDDENR2-20261114-current4-01/evidence")
CONTEXTS = {
    "__none": (12,"a41e8bb6d35142fbf6be045bb3ef2d69b4839c5196a60fca1c63ed4edc67785d","1cbfa7c63863037d78f333033d4e9d1099453c53bc7ebb6ba28ff7ddc9034b78"),
    "punchline_high_stakes_night": (20,"a2334dd13aaa0ea2704e182373c42bdeebb07a15fc1b0520c0e851fa5c5e4ac2","e14df994cbe3c3e9690b7942e8c9f56ede1b5af71d9154d397d961d97c1ebde6"),
    "punchline_greased_week": (20,"1b588d771eb6a775c5759c855a06e2e224c6a0bdc047313e5e03ba3f75259a75","ba3b8713b2403b2502ead169aa7506714ccf13a9778c482921e5f79888ba77aa"),
    "punchline_new_muscle": (19,"cfac02a29969941f2d8f3eced599437debfdc96cb087ff0fd13ccd023358b683","60af7f66674271527391d8673b3f79c4ef6b970268f2a578f7d5455b71e1c664"),
}
PAINT_ROOT = Path("E:/CodexQA/BTH/runs/BTH-ENVART-HIDDENR2-20261114-source-paint01/evidence")
PAINT_SHA = "602db8c2193be06f398e1a00ec1be82893c812025af54afc0b201c0370038058"
IGNORE = b"# Non-active Hidden source/baseline/candidates; exclude from Godot discovery.\n"

def require(condition, message):
    if not condition:
        raise ValueError(message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read(path):
    path = Path(path)
    for item in (path, *path.parents):
        info = item.lstat()
        require(not (getattr(info, "st_file_attributes", 0) & 0x400) and not stat.S_ISLNK(info.st_mode), "Reparse input: " + str(item))
    require(path.is_file(), "Missing source file: " + str(path))
    return path.read_bytes()

def inventory(root, names):
    return {name: sha(read(root / name)) for name in sorted(names)}

def seal(hashes):
    return sha("\n".join(path + " " + value for path, value in sorted(hashes.items())).encode())

def opaque(image, size):
    return (image.width, image.height) == size and image.rgba[3::4] == b"\xff" * (image.width * image.height)

def pixel(image, x, y):
    at = (y * image.width + x) * 4
    return image.rgba[at:at + 4]

def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)

def encode(image):
    compressor = zlib.compressobj(9)
    stride = image.width * 4
    data = b"".join(compressor.compress(b"\0" + image.rgba[y * stride:(y + 1) * stride]) for y in range(image.height)) + compressor.flush()
    result = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)) + chunk(b"IDAT", data) + chunk(b"IEND", b"")
    require(decode_png(result) == image, "Lossless PNG roundtrip failed")
    return result

def crop(image, rect):
    x, y, width, height = rect
    return PNGImage(width, height, b"".join(image.rgba[((y + row) * image.width + x) * 4:((y + row) * image.width + x + width) * 4]
                                           for row in range(height)))

def inside(x, y, rect):
    a,b,w,h = rect
    return a <= x < a+w and b <= y < b+h


def protected(x, y):
    return any(inside(x,y,rect) for rect in PROTECTED.values())


def package_names(manifest):
    require(manifest.get("environment_id") == ROOM and manifest.get("board_size") == [900,430] and manifest.get("pixel_scale") == 2,
            "Exact Hidden casino board required")
    rows = manifest["animations"]
    require(tuple(row["id"] for row in rows) == ANIMATION_IDS and all("web_low_detail" not in row for row in rows),
            "Original31 default-low-detail motion entries must remain exact")
    require(len({row["texture"] for row in rows}) == 26 and set(manifest["counters"]) == {"punchline_right_table"},
            "Exact26 motion PNGs and one right-only replay required")
    require(manifest["animations"][22]["rect"] == [531,132,8,8], "Middle R2 material glint anchor differs")
    names = {BACKGROUND, FRONT, MANIFEST, INDEX, *(ART + row["texture"] for row in rows)}
    require(len(names) == 30 and all(not Path(name).is_absolute() and ".." not in Path(name).parts and "\\" not in name for name in names),
            "Exact safe logical30 source members required")
    return tuple(sorted(names))


def nearest_map(source_start, source_end, target_count):
    # Historical Pillow NN advances a floating position. Multiplication instead
    # mis-selects the exact y204 tie (215 instead of214) in the R2 wall fit.
    step = (source_end-source_start) / target_count
    position, result = source_start + step*.5, []
    for _ in range(target_count):
        result.append(min(source_end-1, int(position)))
        position += step
    return result


def piecewise_map(source, target):
    result = []
    for a,b,c,d in zip(source,source[1:],target,target[1:]):
        # Pillow cropped each tile first: accumulation is tile-relative.
        result.extend(a + value for value in nearest_map(0,b-a,d-c))
    require(len(result) == target[-1], "Incomplete piecewise map")
    return result


def archive_sources(data):
    require(sha(data) == ARCHIVE_SHA, "Exact own R2 source archive required")
    with zipfile.ZipFile(io.BytesIO(data)) as package:
        require(len(package.namelist()) == len(set(package.namelist())), "Duplicate archive member")
        inputs = {name: package.read(name) for name in MEMBERS}
    require({name:sha(value) for name,value in inputs.items()} == MEMBERS, "Pinned source/recipe/archive master member differs")
    guide, floor = decode_png(inputs["source/background-guide-v1.png"]), decode_png(inputs["source/floor-material-v1.png"])
    require(opaque(guide,RAW_SIZE) and opaque(floor,RAW_SIZE), "Opaque exact original source/floor dimensions required")
    return guide, floor


def own_underlay(guide):
    raw_x,raw_y = nearest_map(0,guide.width,900), nearest_map(0,guide.height,430)
    wall_x,wall_y = piecewise_map(SOURCE_X,TARGET_X), piecewise_map(SOURCE_Y,TARGET_Y)
    require(wall_y[204] == 214, "Historical incremental NN tie differs")
    cache = {}
    def sample(nx,ny):
        bx,by = nx//2,ny//2
        require(0 <= by < 245, "Healed wall sample cannot invent floor")
        qx,qy = wall_x[bx],wall_y[by]
        if (qx,qy) not in cache:
            blocked = lambda x,y: any(a <= x < c and b <= y < d for a,b,c,d in OLD_BLOCKED)
            donor_x = qx
            if blocked(qx,qy):
                choices = [qx+47*k for k in range(-20,21) if 0 <= qx+47*k < 900 and not blocked(qx+47*k,qy)]
                if not choices:
                    choices = [x for x in range(900) if not blocked(x,qy)]
                donor_x = min(choices,key=lambda x:abs(x-qx))
            require(not blocked(donor_x,qy), "Healed wall donor enters original fixture")
            cache[qx,qy] = (raw_x[donor_x],raw_y[qy],donor_x,qy)
        sx,sy,dx,dy = cache[qx,qy]
        return pixel(guide,sx,sy), [sx,sy,dx,dy,qx,qy]
    return sample


def calibrate(original,floor,underlay):
    rings = []
    for table in TABLES:
        a,b,w,h = table["old"]; a,b,w,h = a//2,b//2,w//2,h//2
        checked = 0
        for by in range(b-2,b+h+2):
            for bx in range(a-2,a+w+2):
                if a <= bx < a+w and b <= by < b+h or protected(bx*2,by*2):
                    continue
                value,_ = underlay(bx*2,by*2)
                require(all(pixel(original,bx*2+xx,by*2+yy) == value for xx in range(2) for yy in range(2)),
                        "Own healed-wall outside-perimeter calibration differs")
                checked += 1
        require(checked == (1160 if table["id"] == "left" else 1552), "Exact protected perimeter inventory differs")
        rings.append({"table":table["id"],"exact_board_samples":checked,"native_pixels":checked*4})
    checked = 0
    for by in range(245,430):
        for bx in range(900):
            if protected(bx*2,by*2):
                continue
            value = pixel(floor,8+bx*2,151+(by-245)*2)
            require(all(pixel(original,bx*2+xx,by*2+yy) == value for xx in range(2) for yy in range(2)),
                    "Own floor-plate crop/NN/source horizon calibration differs")
            checked += 1
    require(checked > 160000, "Incomplete original same-XY floor calibration")
    return {"healed_wall_ring_checks":rings,"historical_y204_maps_source214":True,
            "original_floor_board_samples":checked,"floor_plate_native_crop":[7,150,1800,370],
            "floor_starts_native_y":490,"all_open_floor_between_supports_uses_original_same_xy":True,
            "no_old_fixture_fringe_beyond_exact_pasted_modules_observed":True}


def table_sample(table,x,y,raw):
    ty = table["target_y"]; sy = table["source_y"]
    if not ty[0] <= y < ty[-1]:
        return None
    band = next(i for i in range(len(ty)-1) if ty[i] <= y < ty[i+1])
    row = sy[band] + min(sy[band+1]-sy[band]-1,int((y-ty[band]+.5)*(sy[band+1]-sy[band])/(ty[band+1]-ty[band])))
    if y < ty[1]:
        f = (y-ty[0]+.5)/(ty[1]-ty[0])
        sl,sr = (table["source_far"][i]+f*(table["source_near"][i]-table["source_far"][i]) for i in range(2))
        tl,tr = (table["target_far"][i]+f*(table["target_near"][i]-table["target_far"][i]) for i in range(2))
        if tl <= x+.5 < tr:
            return min(raw.width-1,int(sl+(x+.5-tl)*(sr-sl)/(tr-tl))),row,"tabletop"
    elif y < ty[3]:
        tl,tr = table["target_near"]; sl,sr = table["source_near"]
        if tl <= x < tr:
            return min(sr-1,int(sl+(x-tl+.5)*(sr-sl)/(tr-tl))),row,"near_rail"
    elif y < ty[4]:
        tl,tr = table["target_near"]; sl,sr = table["source_near"]
        sx = int(sl+(x-tl+.5)*(sr-sl)/(tr-tl))
        if tl <= x < tr and table["source_apron"][0] <= sx < table["source_apron"][1]:
            return sx,row,"shallow_apron"
    else:
        for index,center in enumerate(table["leg_centers"]):
            contact = y >= ty[5]
            width = 32 if contact else 24
            if center-width//2 <= x < center+width//2:
                a,b = table["source_legs"][index]
                if contact:
                    a,b = a-7,b+7
                sx = min(b-1,int(a+(x-(center-width//2)+.5)*(b-a)/width))
                rgba = pixel(raw,sx,row)
                if not contact or max(rgba[:3]) <= 45:
                    return sx,row,f"leg_{index}_" + ("tight_contact" if contact else "dark_timber")
    return None


def assemble(original,raw,underlay):
    out = bytearray(original.rgba); donors,components,allowed = {},{},set()
    old_cleanup = 0
    def put(x,y,value,source):
        at = (y*1800+x)*4
        out[at:at+4] = value; allowed.add((x,y)); donors[x,y] = source
    for table in TABLES:
        a,b,w,h = table["old"]
        for y in range(b,b+h):
            for x in range(a,a+w):
                if protected(x,y):
                    continue
                value,where = underlay(x,y)
                put(x,y,value,["own_R2_healed_wall",*where]); old_cleanup += 1
        # Tight new legs can cross existing wall480..489 and floor490+, but
        # only their selected physical timber/contact pixels are copied.
        for y in range(table["target_y"][0],510):
            for x in range(a,a+w):
                if protected(x,y):
                    continue
                part = table_sample(table,x,y,raw)
                if part:
                    sx,sy,kind = part
                    require(0 <= sx < raw.width and 0 <= sy < raw.height,"Generated donor outside source")
                    put(x,y,pixel(raw,sx,sy),["new_generated_table_only",sx,sy])
                    components[x,y] = table["id"]+"_"+kind
    require(old_cleanup == 193120,"Exact old module-minus-cart cleanup inventory differs")
    image = PNGImage(1800,860,bytes(out))
    changed = []
    for y in range(860):
        for x in range(1800):
            if pixel(image,x,y) != pixel(original,x,y):
                require((x,y) in allowed and not protected(x,y),"Candidate escaped exact repair union/protection")
                changed.append([x,y])
    for name,rect in PROTECTED.items():
        require(crop(image,rect) == crop(original,rect),"Protected original changed: "+name)
    require(image.rgba[:284*1800*4] == original.rgba[:284*1800*4],"Original beams/housings/glint plaster changed")
    for y in range(490,860):
        for x in range(1800):
            if "_leg_" not in components.get((x,y),""):
                require(pixel(image,x,y) == pixel(original,x,y),"Open floor must remain original same coordinate")
    require(all(components.get((x,y),"").startswith("right_tabletop") for y in range(284,326) for x in range(920,1030)),
            "Right far plane must cover Ox conservative lower paint, not replay plaster")
    require(all(components.get((x,387),"").startswith("left_tabletop") for x in range(568,668)),
            "Left far plane misses Sable conservative lower dealer paint")
    supports = []
    for table in TABLES:
        for index,center in enumerate(table["leg_centers"]):
            points = [point for point,kind in components.items() if kind.startswith(table["id"]+f"_leg_{index}_")]
            require(points and min(y for x,y in points) == 466 and max(y for x,y in points) == 509,
                    "Complete physical support/contact must reach floor255")
            point_set = set(points)
            seen, pending = {(center,466)}, [(center,466)]
            while pending:
                x,y = pending.pop()
                for dx in (-1,0,1):
                    for dy in (-1,0,1):
                        neighbour = (x+dx,y+dy)
                        if neighbour in point_set and neighbour not in seen:
                            seen.add(neighbour); pending.append(neighbour)
            require(seen == point_set and len(points) == {360:1072,540:1075,948:1056,1388:1057}[center] and
                    all(components.get((x,465)) == table["id"]+"_shallow_apron" for x,y in points if y == 466),
                    "Support/sole must be connected to the actual apron with no isolated floor specks")
            supports.append({"id":table["id"]+f"_leg_{index}","center_native_x":center,"center_board_x":center/2,
                "native_bounds":[min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1,max(y for x,y in points)+1],
                "floor_contact_bottom_exclusive":510,"physical_pixels":len(points),"connected_8_neighbours":True,
                "apron_attachment_native_rows":[465,466]})
    return image,components,{"tables":TABLES,"protected_native_rects":PROTECTED,"old_cleanup_native_pixels":old_cleanup,
        "old_cleanup_fringe_extension":False,"underlay_donor_rule":"Own archived nearest same-row x+47*k outside all4 old blocked regions; not a texture period",
        "changed_pixels":len(changed),"changed_native_pixels":changed,"complete_supports":supports,
        "per_pixel_final_donors":[[x,y,*donors[x,y]] for x,y in sorted(donors,key=lambda p:(p[1],p[0]))],
        "generated_table_pixels":len(components),"fixed_body_tops_native":[308,284],
        "painted_near_rails_native_proposals":[444,440],"floor_horizon_native_unchanged":490,
        "all_open_floor_same_original_xy":True,"outside_exact_old_modules_plus_tight_support_masks_original":True,
        "cart_priority_exact":True,"door_and_access_lane_exact":True,"middle_glint_envelope_exact":True,
        "no_motion_manifest_mask_reanchor_or_gameplay_change":True,"no_color_transform_or_blending":True}


def historical_inputs(components):
    hashes,views = {},[]
    for scenario,(count,png_sha,metadata_sha) in CONTEXTS.items():
        for suffix,expected in (("_actual_play.png",png_sha),("_metadata.json",metadata_sha)):
            path = CONTEXT_ROOT / (scenario+suffix)
            require(sha(read(path)) == expected,"Retained actual context changed: "+str(path))
            hashes[str(path)] = expected
        metadata = json.loads(read(CONTEXT_ROOT / (scenario+"_metadata.json")))
        require(len(metadata["actual_view"]["objects"]) == count,"Retained actual object count differs")
        views.append({"scenario":scenario,"initial_objects":count,"scope":"Historical actual full-app; fresh candidate not yet reviewed"})
    report_path = PAINT_ROOT / "hidden_source_paint.json"
    require(sha(read(report_path)) == PAINT_SHA,"Pinned Hidden source-paint report changed")
    hashes[str(report_path)] = PAINT_SHA
    report = json.loads(read(report_path))
    require(not report["findings"] and [row["scenario"] for row in report["contexts"]] == list(CONTEXTS),
            "Exact four source-paint contexts required")
    leg_points = [point for point,kind in components.items() if "_leg_" in kind]
    checks = []
    for context in report["contexts"]:
        require(context["geometry_equal"] is True and len(context["objects"]) == CONTEXTS[context["scenario"]][0],
                "Source-paint geometry/object inventory differs")
        for row in context["objects"]:
            for key in ("body_png","adorn_png"):
                name = row[key]
                require(Path(name).name == name and name.endswith(".png"),"Unsafe typed source filename")
                path = PAINT_ROOT / name
                hashes[str(path)] = sha(read(path))
            label = row["object"].get("label","")
            if label not in {"Sable","Ox","Vic Mercer","High-stakes guard","Table runner","Moving inspector","Payoff runner","New guard lead","Checkpoint rover"}:
                continue
            body = decode_png(read(PAINT_ROOT / row["body_png"]))
            require((body.width,body.height) == SIZE,"Native1800 typed body required")
            strong = [(x,y) for x,y in leg_points if pixel(body,x,y)[3] >= 64]
            weak = sum(pixel(body,x,y)[3] > 0 for x,y in leg_points)
            require(not strong,"New supports intersect actual strong actor paint: "+context["scenario"]+"/"+label)
            checks.append({"scenario":context["scenario"],"id":row["object"]["id"],"label":label,
                "typed_body_sha256":hashes[str(PAINT_ROOT / row["body_png"])],"leg_strong_alpha_ge64_intersections":0,
                "leg_alpha_gt0_intersections":weak,"weak_glows_are_not_body_opacity":True})
    require(len(views) == 4 and sum(row["initial_objects"] for row in views) == 71 and len(checks) >= 17,
            "Incomplete retained four-context actor-foot clearance")
    return hashes,{"views":views,"actual_initial_objects":71,"typed_actor_leg_checks":checks,
        "all_actor_hit_label_anchors_and_depth_logic_unchanged":True,
        "typed_PNG_hash_custody_origin":"Read-only admission inventory; historical paint report names PNGs but did not seal their individual hashes",
        "caveat":"Historical transparent body paint only; new integrated dealer/actor/label/depth review in all four contexts remains mandatory."}


def exact_existing(root,hashes,ignore=False):
    if not root.exists():
        return
    wanted = {**hashes,**({".gdignore":sha(IGNORE)} if ignore else {})}
    dirs = {p.as_posix() for name in hashes for p in PurePosixPath(name).parents if p.as_posix() != "."}
    actual,seen_dirs = {},set()
    for path in root.rglob("*"):
        info = path.lstat()
        require(not (getattr(info,"st_file_attributes",0)&0x400) and not stat.S_ISLNK(info.st_mode),"Reparse output path")
        name = path.relative_to(root).as_posix()
        if stat.S_ISDIR(info.st_mode):
            require(name in dirs,"Unexpected preserved directory: "+name); seen_dirs.add(name)
        else:
            require(stat.S_ISREG(info.st_mode) and name in wanted,"Unexpected preserved file: "+name)
            actual[name] = sha(read(path))
    require(actual == wanted and seen_dirs == dirs,"Existing immutable payload differs: "+str(root))


def layout_from_environment():
    path = Path(os.environ["BTH_QA_EVIDENCE_DIR"]) / "storage-manifest.json"
    record = json.loads(read(path))
    layout = Layout(**{key:Path(value) for key,value in record["paths"].items()},
        **{key:record[key] for key in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    validate_layout(layout)
    require(layout.prepared and layout.workspace == WORKSPACE,"Exact prepared Hidden E workspace required")
    return layout


def write_fresh(path,data,layout):
    validate_layout(layout,extra_write_paths=(path.parent,))
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as handle:
        handle.write(data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root",type=Path,required=True)
    args = parser.parse_args(argv)
    try:
        layout = layout_from_environment()
        baseline,sources = WORKSPACE/"source_baseline",WORKSPACE/"candidate_sources"
        output = sources/"hidden-spatial-r1-assembled-v1"
        evidence = layout.evidence/"hidden-spatial-r1-assembly.json"
        validate_layout(layout,extra_write_paths=(baseline,sources,output,evidence))
        require(not output.exists() and not evidence.exists(),"Fresh immutable Hidden candidate/report required")
        source = args.source_root.absolute()
        require(source == Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers"),"Exact art worktree source required")
        recipe_sha,decoder_sha = sha(read(__file__)),sha(read(decode_png.__code__.co_filename))
        payload_manifest = read(source/MANIFEST)
        require(sha(payload_manifest) == MANIFEST_SHA,"Original Hidden manifest pin differs")
        manifest = json.loads(payload_manifest); names = package_names(manifest)
        extras = (*CONTROLS,RAW_REL,RAW_REL+".b64",SOURCE_DIR+"/prompt.txt",SOURCE_DIR+"/provenance.json",
                  ARCHIVE,"docs/art/briefs/hidden_spatial_repair_20261116.md")
        before = inventory(source,(*names,*extras)); baseline_hashes = {name:before[name] for name in names}
        require(seal(baseline_hashes) == BASELINE_SEAL and before[BACKGROUND] == MASTER_SHA and before[RAW_REL] == RAW_SHA and
                before[ARCHIVE] == ARCHIVE_SHA,"Exact original30/raw/own-archive identities required")
        require(before[RAW_REL+".b64"] == "8a3543591309ef2cbd4b6c35e7edf7f0ffee95f0124e79a6b4d74dce3023a6f3" and
                base64.b64decode(b"".join(read(source/(RAW_REL+".b64")).split()),validate=True) == read(source/RAW_REL) and
                before[SOURCE_DIR+"/prompt.txt"] == "e72e6eaf13d4ccc49bf89907c4218693c4bac3b2d1aa3d493d1ed6dcffdf338e",
                "Frozen raw/base64/prompt identities differ")
        pack_source = read(source/"scripts/ui/environment_art_pack.gd").decode("utf-8")
        require("var web_low_detail := true" in pack_source and 'entry.web_low_detail = value.get("web_low_detail", true)' in pack_source,
                "Actual parser/entry default-low-detail inclusion differs")
        payload = {name:read(source/name) for name in names}
        original,raw = decode_png(payload[BACKGROUND]),decode_png(read(source/RAW_REL))
        require(opaque(original,SIZE) and opaque(raw,RAW_SIZE),"Opaque exact original/generated image required")
        guide,floor = archive_sources(read(source/ARCHIVE))
        underlay = own_underlay(guide)
        calibration = calibrate(original,floor,underlay)
        candidate,components,assembly = assemble(original,raw,underlay)
        old_front = decode_png(payload[FRONT])
        require(opaque(old_front,COUNTER[2:]) and old_front == crop(original,COUNTER),"Original sole replay is not exact opaque master crop")
        front = crop(candidate,COUNTER)
        require(opaque(front,COUNTER[2:]),"New sole right replay must remain opaque")
        payload[BACKGROUND],payload[FRONT] = encode(candidate),encode(front)
        require(payload[MANIFEST] == payload_manifest and all(payload[name] == read(source/name) for name in names if name not in (BACKGROUND,FRONT)),
                "Motion PNGs/manifest/index/source payload changed")
        hashes = {name:sha(payload[name]) for name in names}
        require({name for name in names if hashes[name] != baseline_hashes[name]} == {BACKGROUND,FRONT},
                "Only master and one exact right foreground may change")
        historical_before,context_proof = historical_inputs(components)
        exact_existing(baseline,baseline_hashes,ignore=True)
        preserved = {"hidden-spatial-r1.png":read(source/RAW_REL),"hidden-spatial-r1.png.b64":read(source/(RAW_REL+".b64")),
                     "prompt.txt":read(source/(SOURCE_DIR+"/prompt.txt")),"provenance.json":read(source/(SOURCE_DIR+"/provenance.json")),
                     "hidden-r2-source.zip":read(source/ARCHIVE)}
        if sources.exists():
            allowed = set(preserved)|{".gdignore"}
            require(all(path.is_file() and path.name in allowed for path in sources.iterdir()),"Unexpected existing Hidden source preservation")
            for path in sources.iterdir():
                require(read(path) == (IGNORE if path.name == ".gdignore" else preserved[path.name]),"Preserved Hidden raw/underlay differs")
        require(inventory(source,(*names,*extras)) == before and all(sha(read(Path(name))) == value for name,value in historical_before.items()) and
                sha(read(__file__)) == recipe_sha and sha(read(decode_png.__code__.co_filename)) == decoder_sha,
                "Read-only source/context/recipe/decoder changed during preflight")
        # FIRST QA WRITES. All own-wall/floor calibration, exact preservation,
        # physical axes/contact/actor checks and storage admission succeeded.
        validate_layout(layout,extra_write_paths=(baseline,sources,output,evidence))
        baseline.mkdir(exist_ok=True); sources.mkdir(exist_ok=True)
        for directory in (baseline,sources):
            if not (directory/".gdignore").exists():
                write_fresh(directory/".gdignore",IGNORE,layout)
        for name in names:
            if not (baseline/name).exists():
                write_fresh(baseline/name,read(source/name),layout)
        for name,data in preserved.items():
            if not (sources/name).exists():
                write_fresh(sources/name,data,layout)
        output.mkdir()
        for name in names:
            write_fresh(output/name,payload[name],layout)
        exact_existing(output,hashes)
        exact_existing(baseline,baseline_hashes,ignore=True)
        require(all(read(sources/name) == data for name,data in preserved.items()) and
                all(read(directory/".gdignore") == IGNORE for directory in (baseline,sources)) and
                inventory(source,(*names,*extras)) == before and all(sha(read(Path(name))) == value for name,value in historical_before.items()) and
                sha(read(__file__)) == recipe_sha and sha(read(decode_png.__code__.co_filename)) == decoder_sha,
                "Output/baseline/raw/context/source/recipe custody changed")
        report = {"schema":"bth.hidden_spatial_assembly/v1","task_id":"BTH-ENV-SPATIAL-HIDDEN-001",
            "status":"NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT","observed_at":datetime.now(timezone.utc).isoformat(),
            "recipe_sha256":recipe_sha,"decoder_sha256":decoder_sha,"raw_source":{"path":str(sources/"hidden-spatial-r1.png"),"sha256":RAW_SHA,"size":RAW_SIZE},
            "baseline":{"path":str(baseline),"seal":BASELINE_SEAL,"file_count":30,"files":baseline_hashes},
            "output":{"path":str(output),"seal":seal(hashes),"file_count":30,"files":hashes},
            "changed_payload_paths":[BACKGROUND,FRONT],"assembly":assembly,"own_underlay_calibration":calibration,
            "own_immutable_underlay_archive":{"sha256":ARCHIVE_SHA,"preserved":str(sources/"hidden-r2-source.zip"),"members":MEMBERS,"recipe_executed":False},
            "counter_crops_exact_opaque":{"punchline_right_table":COUNTER},"no_left_replay_added":True,
            "manifest_and_all26_motion_PNGs_byte_identical":True,"native_entries":31,"default_low_detail_entries":31,
            "motion_masks_reanchors_timing_and_gameplay_changes":False,"context_clearance":context_proof,
            "historical_context_source_hashes_before":historical_before,"historical_context_source_hashes_after":{name:sha(read(Path(name))) for name in historical_before},
            "source_hashes_before":before,"source_hashes_after":inventory(source,(*names,*extras)),"all_sources_unchanged":True,
            "auxiliary_ignore_sentinels":[str(baseline/".gdignore"),str(sources/".gdignore")],
            "ignore_sentinels_excluded_from_logical_30_file_payload":True,
            "baseline_auxiliary_files":{".gdignore":{"bytes":len(IGNORE),"sha256":sha(IGNORE),"ordinary_file":True}},
            "storage_manifest":str(layout.manifest_path),"active_files_written":False,"runtime_launched":False,"art_approval":False,"test_updated":False,
            "risks":["Generated edges, own wall joins and complete quiet timber/contact shapes require actual integrated pixel review.",
                     "All four actual actor/label/depth compositions, dealer interpretation and opaque full-right replay need fresh native acceptance.",
                     "All31 normal/default-low/RM/wrap/liveness, source-specific work/outcome checks, authentic preview and TEST remain gated."]}
        write_fresh(evidence,(json.dumps(report,indent=2)+"\n").encode(),layout)
        print(json.dumps({"status":report["status"],"package":str(output),"report":str(evidence),"art_approval":False}))
        return 0
    except (OSError,ValueError,KeyError,TypeError,RuntimeError,zipfile.BadZipFile) as error:
        print(json.dumps({"status":"HIDDEN_ASSEMBLY_STOPPED","error":str(error),"active_files_written":False,"art_approval":False,"test_updated":False}),file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
