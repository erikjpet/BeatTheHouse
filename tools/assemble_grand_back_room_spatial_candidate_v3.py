"""Guarded GBR composition R3 prototype; explicit full-height source registration.

Parent executes under bth_qa_guarded_run only after source review. No children,
active writes, cleanup, cache changes, coordinate changes or visual GO. The
manual physical contours and floor join remain actual-populated-review risks.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
from collections import Counter
from copy import deepcopy
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import stat

import assemble_grand_back_room_spatial_candidate as legacy
from bth_qa_storage import Layout, validate_layout

ROOM = "grand_casino_back_room"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-GBRCOMPOSITION-R3-20261116")
SOURCE = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
RECIPE_REL = "tools/grand_back_room_spatial_r3_recipe.json"
RECIPE_SHA = "f21cbaa60932f1793824ab7e61076757de6cfbd020f106045d1f44b092b2f27f"
LEGACY_SHA = "2dc30990563c5881b9b7546e306cbf1479867e20275ffee8d4cc342a94156ac3"
BASE_SEAL = "e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7"
BG_SHA = "46492785829f659c5869d91a6510d424ea4977e6921b1ece7de1225aa804e6ca"
JSON_SHA = "cc8553a5856289c7fe6b42754db43b4bd02d07e5c793ca1fea54e7655eca103d"
RAW_DIR = "review_artifacts/environment_art_sources/grand-back-room-composition-r3"
RAW_PINS = {
    "grand-back-room-composition-r3.png": "b7bdfde4f88ec32bd5cf21b7b9bc8de1954a5e572a82fb98907cc716b4e6fc7a",
    "grand-back-room-composition-r3.png.b64": "5f8ad82095005b9d4d7237f0e4006580ec2ee7692eae989bd26c8dbc56a32b48",
    "prompt.txt": "1a2d585f2958e47db34bc093dd03256235a0e9abfa27ed1ec46adef1f5af951a",
    "provenance.json": "9d3b5d6946c1df86a66a2dfd5693b31a5b6b922d301c98af93c3f1f2ec280dbf",
    "raw-materialization-descriptor.json": "4644a1a159b98d11d869d0854e96a12bb6899b2b204eac08accf255e82e4279a",
}
ART = legacy.ART
BACKGROUND, MANIFEST, INDEX = legacy.BACKGROUND, legacy.MANIFEST, legacy.INDEX
CONTROLS = (*legacy.CONTROLS, "scripts/core/environment_placement.gd",
            "scripts/ui/game_props/craps_room_prop.gd", "scripts/ui/game_props/game_prop_kit.gd")
CONTEXT = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRNATIVE-20261116-v3-contexts/evidence")
CAPTURE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRNATIVE-20261116-v3-capture/evidence/capture/animation_capture.json")
CAPTURE_SHA = "3342ed79ece4a408f567cfae8afbdab01bd1612d441a623e24ed2086e8908afd"
CONTEXT_REPORT = CONTEXT / "grand_casino_back_room_preart_metadata.json"
CONTEXT_REPORT_SHA = "6a7a6717c948b8e5dcd4d8a78bbbfacaf12d0303496531f7df7c98bde08b9870"
PAINT_PINS = {
    "__none_metadata.json": "d60c2b0c127ffda44ef2e2887d889f4bed395d41a820af79158b843597a1276c",
    "__none_host_0_body.png": "00796388634d8a17b03db46d2f1eb1c3bf3fd1916b9058b056e28ff3abc999e2",
    "__none_host_0_adorn.png": "ce3346ab23b7c7c964eb9610cba8e57000bece61e0eeb3fe4a243d9b530c8a20",
    "__none_host_1_body.png": "9f4dac08430771743a540d112b014616c13fa06d968a75840eae41a2f40a88a9",
    "__none_host_1_adorn.png": "0c1361b7664e6d1b28d32169d9befd23c7cdd340241f2e7f86ac780274f6836f",
    "__none_host_2_body.png": "9e48e21dc14348a228fe4dac02a90453c45769df952f76f0b558f43649efc439",
    "__none_host_2_adorn.png": "8dc5d8c5c33d86604d6226a735ecbf73004c5f0c5e846047e8e079a10f422ce5",
}
IGNORE = b"# Non-active GBR composition R3 source/candidates; exclude from Godot discovery.\n"
OUTPUT_NAME = "grand-back-room-composition-r3-assembled-v1"
PROOF_NAME = "grand-back-room-composition-r3-assembly.json"
require, sha, read = legacy.require, legacy.sha, legacy.read
decode_png, PNGImage, pixel, encode = legacy.decode_png, legacy.PNGImage, legacy.pixel, legacy.encode


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def integer(value):
    return type(value) is int


def ordinary(path, missing=False):
    path = Path(path)
    for item in (path, *path.parents):
        try:
            info = item.lstat()
        except FileNotFoundError:
            if missing:
                continue
            raise
        require(not stat.S_ISLNK(info.st_mode) and not (getattr(info, "st_file_attributes", 0) & 0x400),
                "Reparse path: " + str(item))


def exact_tree(root, wanted, sentinel=False):
    ordinary(root)
    expected = dict(wanted)
    if sentinel:
        expected[".gdignore"] = sha(IGNORE)
    dirs = {p.as_posix() for n in expected for p in PurePosixPath(n).parents if p.as_posix() != "."}
    found, actual_dirs, pending = {}, set(), [root]
    while pending:
        directory = pending.pop()
        ordinary(directory)
        require(stat.S_ISDIR(directory.lstat().st_mode), "Ordinary directory required: " + str(directory))
        for p in sorted(directory.iterdir()):
            ordinary(p)
            rel = p.relative_to(root).as_posix()
            info = p.lstat()
            if stat.S_ISDIR(info.st_mode):
                require(rel in dirs, "Unknown directory: " + str(p))
                actual_dirs.add(rel); pending.append(p)
            else:
                require(stat.S_ISREG(info.st_mode) and rel in expected, "Unknown file: " + str(p))
                found[rel] = sha(read(p))
    require(found == expected and actual_dirs == dirs, "Exact physical package differs: " + str(root))


def layout_from_environment():
    p = Path(os.environ["BTH_QA_EVIDENCE_DIR"]) / "storage-manifest.json"
    record = json.loads(read(p))
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
                    **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and layout.workspace == WORKSPACE, "Exact prepared composition R3 workspace required")
    require(layout.expected_write_bytes >= 4 * 1024**3 and layout.reserve_bytes >= 20 * 1024**3,
            "Original 4+20 GiB storage budget required")
    return layout


def grown_rect(raw, bleed):
    require(len(raw) == 4 and len(bleed) == 4 and all(integer(v) for v in (*raw, *bleed)), "Integer geometry required")
    require(all(v >= 0 for v in bleed), "Negative bleed")
    x, y, w, h = raw; left, top, right, bottom = bleed
    rect = [x-left, y-top, w+left+right, h+top+bottom]
    require(rect[0] >= 0 and rect[1] >= 0 and rect[0]+rect[2] <= 900 and rect[1]+rect[3] <= 430,
            "Grown rectangle outside board")
    return rect, [v*2 for v in rect]


def inside(x, y, polygon):
    result = False
    for i, (ax, ay) in enumerate(polygon):
        bx, by = polygon[i-1]
        if (ay > y) != (by > y) and x < (bx-ax)*(y-ay)/(by-ay)+ax:
            result = not result
    return result


def inverse_y(target, sources, targets):
    require(len(sources) == len(targets) >= 2 and all(integer(v) for v in (*sources, *targets)), "Bad Y registration")
    require(all(a < b for a, b in zip(sources, sources[1:])) and
            all(a < b for a, b in zip(targets, targets[1:])), "Nonmonotone registration")
    for sy0, sy1, ty0, ty1 in zip(sources, sources[1:], targets, targets[1:]):
        if ty0 <= target <= ty1:
            return math.floor(sy0 + (target-ty0)*(sy1-sy0)/(ty1-ty0))
    raise ValueError("Target outside explicit furniture registration")


def block_points(x, y):
    return ((x, y), (x+1, y), (x, y+1), (x+1, y+1))


def put_block(out, x, y, rgba):
    for px, py in block_points(x, y):
        at = (py*1800+px)*4
        out[at:at+4] = rgba


def mask_record(points):
    rows = {}
    for x, y in points:
        require(integer(x) and integer(y) and 0 <= x < 1800 and 0 <= y < 860, "Mask outside native canvas")
        rows.setdefault(y, []).append(x)
    runs = []
    for y in sorted(rows):
        xs = sorted(set(rows[y])); start = prev = xs[0]
        for x in xs[1:]:
            if x != prev+1:
                runs.append([y, start, prev+1]); start = x
            prev = x
        runs.append([y, start, prev+1])
    return {"schema":"bth.native_row_runs/v1", "canvas":[1800,860], "coordinates":"absolute_native_xy", "runs":runs}


def office_mask(recipe):
    bands = recipe.get("office_row_bands", [])
    require(bands, "Actual independent Office row trace is required")
    points = set()
    for y0, y1, x0, x1 in bands:
        require(all(integer(v) for v in (y0,y1,x0,x1)) and 0 <= x0 < x1 <= 1800 and 0 <= y0 < y1 <= 860,
                "Bad Office physical row band")
        points.update((x,y) for y in range(y0,y1) for x in range(x0,x1))
    return points


def assemble(original, raw, recipe):
    require(legacy.opaque(original, (1800,860)) and legacy.opaque(raw, (1815,867)), "Opaque exact master/raw dimensions required")
    require(recipe["floor"]["target_y"] == [330,616] and recipe["floor"]["clean_source_x"] == [754,1060],
            "Only parent-selected hybrid floor admitted")
    require(recipe["furniture_registration"]["source_y"] == [364,496,508,564,704] and
            recipe["furniture_registration"]["target_y"] == [390,512,524,576,702], "Whole-furniture registration changed")
    require(recipe["protected_outer_frame_width"] == 4 and recipe["protected_header_end_exclusive"] == 330,
            "Header/frame protection changed")
    protected_office = office_mask(recipe)
    out = bytearray(original.rgba); ledger = []; floor_points = set()
    for y in range(330,616,2):
        sy = math.floor(366+(y+1-330)*501/530)
        require(366 <= sy < 640, "Floor source entered raw Office/gold")
        for x in range(4,1796,2):
            sx = 754 + ((x+1)%306)
            require(754 <= sx < 1060, "Floor donor left actual clean corridor")
            put_block(out,x,y,pixel(raw,sx,sy)); floor_points.update(block_points(x,y))
            ledger.append([x,y,2,2,"raw",sx,sy,"clean_floor_corridor"])
    components, masks, excluded, boundaries = {}, {}, {}, {}
    for art_id, table in recipe["counters"].items():
        expected_raw = [82,258,272,36] if art_id == "grand_table_left" else [546,258,272,36]
        require(table["raw_rect_board"] == expected_raw, "Raw counter authority changed")
        board, rect = grown_rect(table["raw_rect_board"],table["bleed_board"])
        x0,y0,w,h = rect; mask=set(); exclusion=set(); parts={key:set() for key in table["source_components"]}
        require(set(parts) == {"top_and_rail","apron","front_leg_left","front_leg_right","foot_left","foot_right",
                               "rear_leg_left","rear_leg_right","brace_left","brace_right","stretcher"}, "Incomplete physical components")
        for y in range(y0,y0+h,2):
            sy=inverse_y(y+1,recipe["furniture_registration"]["source_y"],recipe["furniture_registration"]["target_y"])
            for x in range(x0,x0+w,2):
                sx=x+1+table["source_x_offset"]
                kinds=[key for key, poly in table["source_components"].items() if inside(sx,sy,poly)]
                if not kinds:
                    continue
                block=set(block_points(x,y))
                # Office may have one-native-pixel edge steps. Exclude exact
                # physical pixels, then reject partial NN2 rather than flatten
                # those steps into an opaque rectangular floor matte.
                kept=block-protected_office
                exclusion.update(block & protected_office)
                if not kept:
                    continue
                require(kept == block, "Office intersects partial 2x2 block; use independently reviewed block-aligned contour")
                put_block(out,x,y,pixel(raw,sx,sy)); mask.update(block)
                for key in kinds:parts[key].update(block)
                ledger.append([x,y,2,2,"raw",sx,sy,"furniture:"+art_id+":"+"+".join(kinds)])
        require(mask and all(parts.values()), "Missing complete furniture component")
        require(all(x0<=x<x0+w and y0<=y<y0+h for x,y in mask), "Furniture clipped by replay extent")
        for key in ("foot_left","foot_right"):
            require(max(y for x,y in parts[key]) >= 697, "Complete foot was compressed to old apron gate")
        masks[art_id]=mask;components[art_id]=parts;excluded[art_id]=exclusion;boundaries[art_id]=(board,rect)
    image=PNGImage(1800,860,bytes(out))
    for y in range(860):
        for x in range(1800):
            if y<330 or x<4 or x>=1796 or y>=856 or (x,y) in protected_office:
                require(pixel(image,x,y)==pixel(original,x,y),"Protected header/frame/Office changed")
            if y>=702:
                require(pixel(image,x,y)==pixel(original,x,y),"Lower original/white legs/contact/gold changed")
    require(image.rgba[3::4] == b"\xff"*(1800*860), "Master opacity changed")
    return image,masks,components,excluded,boundaries,protected_office,floor_points,ledger


def foreground(master, rect, points):
    x0,y0,w,h=rect; out=bytearray(w*h*4)
    for x,y in points:
        at=((y-y0)*w+x-x0)*4;out[at:at+4]=pixel(master,x,y)
    result=PNGImage(w,h,bytes(out))
    require(set(result.rgba[3::4])=={0,255},"Binary foreground alpha required")
    for y in range(h):
        for x in range(w):
            rgba=pixel(result,x,y);glob=(x+x0,y+y0)
            require((rgba[3]==255)==(glob in points),"Physical mask/alpha differs")
            require(rgba==pixel(master,*glob) if rgba[3] else rgba==b"\0\0\0\0","Foreground solid RGB/transparent zero differs")
    for y in range(0,h,2):
        for x in range(0,w,2):
            require(len({pixel(result,x+dx,y+dy)[3] for dx in (0,1) for dy in (0,1)})==1,"Non-NN2 mask")
    return result


def green_felt(rgba):
    r,g,b,a=rgba
    return a==255 and g>25 and 4*g>5*r and 20*g>21*b


def paint_evidence(master, helpers):
    reports=[];support={};typed={}
    for name,digest in PAINT_PINS.items():
        path=CONTEXT/name;require(sha(read(path))==digest,"Actual typed-paint source changed")
        helpers[str(path)]=digest
        if not name.endswith(".png"):
            continue
        image=decode_png(read(path));require((image.width,image.height)==(1800,860),"Typed-paint dimensions differ")
        points={(i%(1800),i//1800) for i,a in enumerate(image.rgba[3::4]) if a}
        typed[name]=points
        if name in ("__none_host_0_body.png","__none_host_1_body.png"):
            opaque={(i%1800,i//1800) for i,a in enumerate(image.rgba[3::4]) if a==255}
            missed=[]
            for x,y in opaque:
                if not green_felt(pixel(master,x,y)):missed.append([x,y])
            require(opaque and not missed,"Actual opaque game paint leaves registered green felt: "+name+" "+str(missed[:8]))
            support[name]=opaque
            reports.append({"source":str(path),"sha256":digest,"opaque_game_pixels":len(opaque),"outside_green_felt":0,
                            "scope":"Actual retained opaque body at one clock; badges/shadows/adornments are separate."})
    return reports,support,typed


def write_fresh(path,data,layout):
    validate_layout(layout,extra_write_paths=(path.parent,));ordinary(path,missing=True)
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as handle:handle.write(data)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root",type=Path,required=True)
    parser.add_argument("--recipe",type=Path,required=True)
    parser.add_argument("--recipe-sha256",required=True)
    args=parser.parse_args(argv)
    try:
        layout=layout_from_environment()
        require(args.source_root.absolute()==SOURCE and args.recipe.absolute()==SOURCE/RECIPE_REL,"Exact read-only source/recipe required")
        recipe_data=read(args.recipe);require(sha(recipe_data)==args.recipe_sha256==RECIPE_SHA,"Frozen actual recipe hash required")
        recipe=json.loads(recipe_data)
        require(recipe["schema"]=="bth.gbr_composition_recipe/v1" and recipe["assembly_version"]==3 and recipe["room"]==ROOM,"Wrong recipe")
        require(recipe["scope"]=="PARENT_AUTHORIZED_FIRST_PROTOTYPE_NOT_VISUAL_ACCEPTANCE","Wrong scope")
        require(sha(read(legacy.__file__))==LEGACY_SHA,"Pure legacy PNG primitives changed")
        helper_paths=[Path(__file__),Path(legacy.__file__),Path(decode_png.__code__.co_filename),args.recipe]
        helpers={str(p):sha(read(p)) for p in helper_paths}
        manifest_data=read(SOURCE/MANIFEST);require(sha(manifest_data)==JSON_SHA,"Current manifest changed")
        manifest=json.loads(manifest_data);names=legacy.package_names(manifest)
        payload={n:read(SOURCE/n) for n in names};before={n:sha(b) for n,b in payload.items()}
        require(legacy.seal(before)==BASE_SEAL and before[BACKGROUND]==BG_SHA,"Current e206 baseline required")
        control_before={n:sha(read(SOURCE/n)) for n in CONTROLS}
        raw_root=SOURCE/RAW_DIR;exact_tree(raw_root,RAW_PINS)
        raw_bytes=read(raw_root/"grand-back-room-composition-r3.png")
        require(base64.b64decode(b"".join(read(raw_root/"grand-back-room-composition-r3.png.b64").split()),validate=True)==raw_bytes,
                "Frozen raw/base64 differ")
        require(sha(read(CAPTURE))==CAPTURE_SHA,"Actual baseline capture changed");helpers[str(CAPTURE)]=CAPTURE_SHA
        require(sha(read(CONTEXT_REPORT))==CONTEXT_REPORT_SHA,"Actual baseline context report changed")
        helpers[str(CONTEXT_REPORT)]=CONTEXT_REPORT_SHA
        native_layout=json.loads(read(CONTEXT_REPORT))["views"]["__none"]["actual_view"]["object_layout"]
        require(native_layout==json.loads(read(CONTEXT/"__none_metadata.json"))["actual_view"]["object_layout"],
                "Pinned baseline layout witnesses disagree")
        baseline=WORKSPACE/"source_baseline";parent=WORKSPACE/"candidate_sources";output=parent/OUTPUT_NAME
        report_path=layout.evidence/PROOF_NAME;mask_root=layout.evidence/"material_masks"
        validate_layout(layout,extra_write_paths=(baseline,parent,output,report_path.parent,mask_root))
        for p in (output,report_path,mask_root):
            ordinary(p,missing=True);require(not p.exists(),"Fresh immutable output required: "+str(p))
        if baseline.exists():exact_tree(baseline,before,sentinel=True)
        if parent.exists():exact_tree(parent,{},sentinel=True)
        original,raw=decode_png(payload[BACKGROUND]),decode_png(raw_bytes)
        master,masks,components,excluded,bounds,office,floor_points,ledger=assemble(original,raw,recipe)
        game_report,support,typed=paint_evidence(master,helpers)
        updated=deepcopy(manifest)
        for art_id,table in recipe["counters"].items():
            require(set(updated["counters"][art_id])=={"texture"},"Unexpected original counter fields")
            updated["counters"][art_id]["bleed"]=table["bleed_board"]
        reverse=deepcopy(updated)
        for row in reverse["counters"].values():del row["bleed"]
        require(reverse==manifest and updated["animations"]==manifest["animations"],"Only two counter bleed additions admitted")
        payload[MANIFEST]=json_bytes(updated);payload[BACKGROUND]=encode(master)
        all_masks={};material={}
        def add_mask(name,points):
            data=json_bytes(mask_record(points));p=mask_root/(name+".json");all_masks[p]=data
            return {"path":str(p),"sha256":sha(data),"pixels":len(points)}
        office_ref=add_mask("office-original-physical",office)
        for art_id,points in masks.items():
            board,rect=bounds[art_id];x0,y0,w,h=rect
            path=ART+updated["counters"][art_id]["texture"]
            payload[path]=encode(foreground(master,rect,points))
            area={(x,y) for y in range(y0,y0+h) for x in range(x0,x0+w)}
            floor_negative=area-points-office
            under={(x,y) for x,y in floor_negative if y>=576}
            physical=add_mask(art_id+"-physical",points)
            material[art_id]={"raw_rect_board":recipe["counters"][art_id]["raw_rect_board"],
                "bleed_board":recipe["counters"][art_id]["bleed_board"],"grown_rect_board":board,"grown_rect_native":rect,
                "texture_rel":path,"texture_sha256":sha(payload[path]),
                "physical_mask":{**physical,"format":"bth.native_row_runs/v1","dimensions":[1800,860],
                                 "solid_pixels":len(points),"transparent_pixels":w*h-len(points),"alpha_values":[0,255],"nn2_exact":True},
                "component_masks":{key:add_mask(art_id+"-"+key,value) for key,value in components[art_id].items()},
                "rgb_matches_master":True,"negative_space":{
                    "floor":add_mask(art_id+"-floor-negative",floor_negative),
                    "under_table":add_mask(art_id+"-under-table-negative",under),"office":office_ref},
                "office_excluded_pixels":len(excluded[art_id]),"semantic_scope":"Manual prototype source contour; actual populated review required."}
        require(legacy.package_names(updated)==names,"Logical21 membership changed")
        hashes={n:sha(payload[n]) for n in names};changed=sorted(n for n in names if hashes[n]!=before[n])
        expected={BACKGROUND,MANIFEST,*(ART+manifest["counters"][k]["texture"] for k in masks)}
        require(set(changed)==expected,"Only BG/two foregrounds/two-bleed manifest may change")
        edited=floor_points|set().union(*masks.values())
        changed_points={(x,y) for y in range(860) for x in range(1800) if pixel(master,x,y)!=pixel(original,x,y)}
        require(changed_points<=edited and not (set().union(*masks.values())&office),"Edit union/Office law failed")
        donor_bytes=json_bytes({"schema":"bth.native_block_donors/v1","block":[2,2],
            "ordered_last_write_wins":True,
            "columns":["target_x","target_y","width","height","source","source_x","source_y","component"],
            "sources":{"raw":sha(raw_bytes)},"rows":ledger})
        donor_path=layout.evidence/"pixel-donors.json"
        require(not donor_path.exists(),"Fresh donor proof required")
        edit_ref=add_mask("approved-edit-union",edited)
        band={(x,y) for y in range(604,616) for x in range(1800)}
        band_refs={k:add_mask(k+"-band-solid",v&band) for k,v in masks.items()}
        paint_refs={key:add_mask("typed-"+key.replace(".png",""),value) for key,value in typed.items()}
        host_ids={"__none_host_0":"game:craps","__none_host_1":"game:blackjack","__none_host_2":"travel:leave"}
        support_refs={host_ids[key.rsplit("_body.png",1)[0]]:add_mask("support-"+key.replace(".png",""),value)
                      for key,value in support.items()}
        surface_masks={"game:blackjack":{p for p in masks["grand_table_left"] if green_felt(pixel(master,*p))},
                       "game:craps":{p for p in masks["grand_table_right"] if green_felt(pixel(master,*p))}}
        for object_id,contact in (("game:blackjack",(428,496)),("game:craps",(1360,494))):
            require(contact in surface_masks[object_id],"Fixed native game contact leaves actual felt")
        surface_refs={key:add_mask("felt-"+key.replace(":","_"),value) for key,value in surface_masks.items()}
        typed_pairs={object_id:{kind:{"path":str(CONTEXT/(host+"_"+kind+".png")),
                                      "sha256":PAINT_PINS[host+"_"+kind+".png"]}
                                for kind in ("body","adorn")}
                     for host,object_id in host_ids.items()}
        source_after={n:sha(read(SOURCE/n)) for n in names}
        controls_after={n:sha(read(SOURCE/n)) for n in CONTROLS}
        exact_tree(raw_root,RAW_PINS)
        require(source_after==before and controls_after==control_before and
                {p:sha(read(p)) for p in helpers}==helpers,"Read-only source/helper custody changed")
        # FIRST WRITE only after every image/control/physical membership check.
        validate_layout(layout,extra_write_paths=(baseline,parent,output,report_path.parent,mask_root,donor_path.parent))
        if not baseline.exists():
            baseline.mkdir();write_fresh(baseline/".gdignore",IGNORE,layout)
            for n in names:write_fresh(baseline/n,read(SOURCE/n),layout)
        if not parent.exists():
            parent.mkdir();write_fresh(parent/".gdignore",IGNORE,layout)
        output.mkdir()
        for n in names:write_fresh(output/n,payload[n],layout)
        for p,data in all_masks.items():write_fresh(p,data,layout)
        write_fresh(donor_path,donor_bytes,layout)
        exact_tree(output,hashes);exact_tree(baseline,before,sentinel=True)
        exact_tree(parent,{OUTPUT_NAME+"/"+n:digest for n,digest in hashes.items()},sentinel=True)
        exact_tree(mask_root,{p.name:sha(data) for p,data in all_masks.items()})
        source_final={n:sha(read(SOURCE/n)) for n in names}
        controls_final={n:sha(read(SOURCE/n)) for n in CONTROLS}
        require(source_final==before and controls_final==control_before and
                {p:sha(read(p)) for p in helpers}==helpers,"Postwrite read-only custody changed")
        exact_tree(raw_root,RAW_PINS)
        proof={"schema":"bth.gbr_composition_assembly/v1","room":ROOM,"assembly_version":3,
            "recipe_sha256":RECIPE_SHA,"assembler_sha256":helpers[str(Path(__file__))],"source_base":recipe["source_base"],
            "source_baseline":{"path":str(baseline),"files":before,"seal":BASE_SEAL,"room_file_count":20,"index_control_count":1,
                               "auxiliary_files":{".gdignore":sha(IGNORE)}},
            "raw_source":{"path":str(raw_root/"grand-back-room-composition-r3.png"),"sha256":sha(raw_bytes),"dimensions":[1815,867],
                          "provenance_sha256":RAW_PINS["provenance.json"],"prompt_sha256":RAW_PINS["prompt.txt"],
                          "review_ref":"Parent authorized bounded prototype; raw full-room perspective remains OPEN."},
            "output":{"path":str(output),"files":hashes,"seal":legacy.seal(hashes)},
            "material_proof":{"coordinate_system":{"board":[900,430],"native":[1800,860],"pixel_scale":2},
                "master":{"path":str(output/BACKGROUND),"sha256":hashes[BACKGROUND],"dimensions":[1800,860],"opaque":True,
                          "edit_union":edit_ref,"changed_pixels":len(changed_points),"outside_edit_union_exact":True,
                          "donor_ledger":str(donor_path),"donor_ledger_sha256":sha(donor_bytes),"every_change_sourced":True},
                "counters":material,
                "floor_band":{"native_y":[604,616],"protected_mask":office_ref,
                    "solid_intersections":band_refs,
                    "outside_approved_union_exact":True,"source_material_rows":"See hashed block donor ledger; gray band removed by authorized floor replacement.",
                    "join_616_status":"OPEN_VISUAL_REVIEW","hybrid_floor_recipe":recipe["floor"]},
                "paint_contacts":{"baseline_capture":{"path":str(CAPTURE),"sha256":CAPTURE_SHA},
                    "baseline_context_report":{"path":str(CONTEXT_REPORT),"sha256":CONTEXT_REPORT_SHA},
                    "native_layout":native_layout,"typed_paint_masks":typed_pairs,"typed_paint_alpha_masks":paint_refs,
                    "support_required_masks":support_refs,"support_surface_masks":surface_refs,"support_checks":game_report,
                    "selected_paint_law":"Actual retained body alpha255 pixels (all meet A>=64); all are required, translucent shadows/glows remain separate.",
                    "felt_predicate":"a==255 and g>25 and 4*g>5*r and 20*g>21*b",
                    "controls_unchanged":True,"scope_and_uncovered_states":"Retained Base opaque bodies at one clock; no people. All later actor/state/visual acceptance remains OPEN."},
                "motion_controls":{"native_count":16,"low_count":7,"ordered_ids":list(legacy.ANIMATION_IDS),
                    "original_rows_equal":True,"animation_pngs_equal":True},
                "protected_controls":{"files":list(CONTROLS),"before":control_before,"after":controls_final,"all_equal":True}},
            "custody":{"input_before":before,"input_after":source_final,"helper_hashes_before":helpers,
                "helper_hashes_after":{p:sha(read(p)) for p in helpers},"exact_physical_membership":True,
                "active_files_written":False,"children_launched":False},
            "changed_files":changed,"visual_acceptance":False,"status":"PROTOTYPE_ASSEMBLED_PENDING_ACTUAL_POPULATED_REVIEW"}
        write_fresh(report_path,json_bytes(proof),layout)
        require({n:sha(read(SOURCE/n)) for n in names}==before and
                {n:sha(read(SOURCE/n)) for n in CONTROLS}==control_before and
                {p:sha(read(p)) for p in helpers}==helpers,"Final read-only custody changed")
        exact_tree(raw_root,RAW_PINS)
        exact_tree(output,hashes);exact_tree(baseline,before,sentinel=True)
        exact_tree(parent,{OUTPUT_NAME+"/"+n:digest for n,digest in hashes.items()},sentinel=True)
        exact_tree(mask_root,{p.name:sha(data) for p,data in all_masks.items()})
        require(read(donor_path)==donor_bytes,"Donor evidence drift")
        print(json.dumps({"status":"PASS","proof":str(report_path),"proof_sha256":sha(read(report_path)),
                          "candidate":str(output),"seal":legacy.seal(hashes),"visual_acceptance":False}))
        return 0
    except (OSError,ValueError,KeyError,TypeError) as exc:
        print(json.dumps({"status":"STOPPED","error":str(exc)}));return 1


if __name__ == "__main__":
    raise SystemExit(main())
