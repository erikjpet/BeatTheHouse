"""Guarded non-active Delta Queen LEFT-only mechanical art assembly.

The parent alone runs this worker in its prepared capped E: Job. All exact source,
R3 deck calibration, 232 alpha-mask clearance and storage checks precede writes.
No old recipe executes; no children, color transforms, active files, JSON edits,
save/profile migration, right-counter edits or TEST publication.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import struct
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bar_spatial_native_suite import qualified_job
from bth_qa_storage import Layout, validate_layout

ROOM = "delta_queen"
WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-DELTATRIAL-20261116")
ART = "assets/art/environments/delta_queen/"
BACKGROUND, FRONT = ART+"background.png", ART+"counters/delta_right_table.png"
MANIFEST, INDEX = "data/art/environments/delta_queen.json", "data/art/environments/index.json"
SOURCE_DIR = "review_artifacts/environment_art_sources/delta-queen-spatial-r1"
RAW_REL = SOURCE_DIR+"/delta-queen-spatial-r1.png"
PROVENANCE_SHA = "42f59da09305dbae5144910c7eea35f52b5afe3a8033f2f887bf2265e5057cda"
RAW_SHA = "a4b3b127e2194c5fe24a9636e1f608277ee9b5d9b0caac53a6c02a2a0176c61d"
MASTER_SHA = "c928cb461b44b10ab8548250fb5c870ddad4a727de8d724d213ee523a676619f"
BASELINE_SEAL = "ca8ecad1e0d4205f4921765aabe099321509116196684c4e459c77a9d9fca41e"
MANIFEST_SHA = "f8e80a75bbbf552bd339421d19d3b1e2df0359a21ef6aa7d3e232257edd89b70"
ALL_MASK_SEAL = "1ec2d8396838f03d0b056ba385a20fbe682d5d49e9df9bb72fb5def9b4c94f74"
RELEVANT_MASK_SEAL = "f458a5332f8e2252583905aa48a8335ee2a6ea5f14e9aaac351d8e0ea50270f1"
SIZE, RAW_SIZE = (1800,860), (1815,867)
OLD_RAW = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-ARTIST-20261115/sources/delta-queen-source-r1.png")
OLD_RAW_SHA = "9f54bb4d2b79ea469087de9f62abbae5ba11384f897fd499d93a9515c634d1a3"
OLD_RECIPE = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/assemble_delta_v1r3.py")
OLD_RECIPE_SHA = "29f8d1506549efc0d6d0187fdae0825c392aa8c989fcdde8e1c228fe26fe10d7"
CONTEXT_ROOT = Path("E:/CodexQA/BTH/runs/BTH-ENVART-DELTATRIAL-20261115-r3-six-context-trace-01/evidence")
CONTEXT_REPORT_SHA = "bb370b9aa824d278b51e5da1579d9dd64fd965976ed6a4f59245e89892dee645"
JOB_SHA = "beebe3009746eb22804d2124f5fa007611066c5489df3b74e84e3c07cb2f18c8"
COUNTER = (660,340,540,184)
OLD_PANEL = (128,356,476,168)
POSTS = ((216,516,36,24),(628,516,28,24))
SOURCE_POSTS = ((129,490,51,40),(574,490,52,40))
ANIMATION_IDS = tuple([f"background_river_reflection_{i}" for i in range(7)] +
    [f"scene_life_river_reflection_{i}" for i in range(7)] + ["delta_sign_pulse","dock_light_and_stem"] +
    [f"window_sparkle_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
CONTROLS = (INDEX,"data/environments/placement_surfaces.json","data/environments/developer_placement_overrides.json",
            "scripts/ui/pixel_scene_canvas.gd","scripts/ui/environment_art_renderer.gd","scripts/ui/environment_art_pack.gd")
IGNORE = b"# Non-active Delta Queen source/baseline/candidates; exclude from Godot discovery.\n"

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

def inside(x,y,rect):
    a,b,w,h = rect
    return a <= x < a+w and b <= y < b+h


def nearest_map(length,count):
    step = length/count
    position,result = step*.5,[]
    for _ in range(count):
        result.append(min(length-1,int(position))); position += step
    return result


def package_names(manifest,provenance):
    require(manifest.get("environment_id") == ROOM and manifest.get("board_size") == [900,430] and manifest.get("pixel_scale") == 2,
            "Exact Delta Queen board required")
    require(tuple(row["id"] for row in manifest["animations"]) == ANIMATION_IDS and
            all("web_low_detail" not in row for row in manifest["animations"]), "Original26 default-low motion entries required")
    require(set(manifest["counters"]) == {"delta_right_table"},"Only the unchanged right replay is admitted")
    names = {BACKGROUND,FRONT,MANIFEST,*(ART+row["texture"] for row in manifest["animations"])}
    require(len(names) == 29 and names == set(provenance["current"]["files"]) and INDEX not in names and
            all(".." not in Path(name).parts and "\\" not in name and not Path(name).is_absolute() for name in names),
            "Exact room-only29 members required; global index is a separate unchanged control")
    return tuple(sorted(names))


def deck_sampler(old):
    require(opaque(old,RAW_SIZE),"Opaque pinned R3 raw dimensions required")
    xs,ys = nearest_map(old.width,900),nearest_map(old.height,430)
    def sample(x,y):
        bx,by = x//2,y//2
        require(246 <= by <= 263,"Deck donor outside exact R3 first deck crop")
        sx,sy = xs[bx],ys[by+112]
        return pixel(old,sx,sy),(sx,sy,bx,by+112)
    return sample


def calibrate_deck(original,sample):
    rows = []
    for y in range(516,528,2):
        count = 0
        for yy in (y,y+1):
            for x in range(1800):
                if inside(x,yy,OLD_PANEL) or inside(x,yy,COUNTER):
                    continue
                value,_ = sample(x,yy)
                require(pixel(original,x,yy) == value,"Own R3 same-X dry-deck calibration differs")
                count += 1
        require(count == (1568 if y < 524 else 3600),"Exact unoccluded deck row inventory differs")
        rows.append({"target_native_rows":[y,y+1],"source_board_y":y//2+112,"exact_pixels":count})
    return {"rows":rows,"donor_law":"Original R3 normalized source same board X, sourceY=targetY+112; no period",
            "old_panel_bottom_only_to_heal":[128,516,476,8],"rows262_263_are_existing_deck_not_shadow":True}


def felt_edges(raw):
    result = {}
    for sy in range(374,446):
        hits = [x for x in range(108,648) if (lambda p:p[1]>p[0]+6 and p[1]>p[2]+4)(pixel(raw,x,sy))]
        require(len(hits) > 380,"Actual source felt row is missing/narrow")
        result[sy] = (min(hits),max(hits)+1)
    return result


def fit_source(raw,x,y,edges):
    if 356 <= y < 362 and 116 <= x < 660:
        sy = 360+min(13,int((y-356+.5)*14/6))
        sx = 171+min(410,int((x-116+.5)*411/544))
        return sx,sy,"far_rim"
    if 362 <= y < 476 and 116 <= x < 660:
        sy = 374+min(71,int((y-362+.5)*72/114))
        left,right = edges[sy]
        if 120 <= x < 658:
            sx = left+min(right-left-1,int((x-120+.5)*(right-left)/538))
            return sx,sy,"felt"
        if x < 120:
            sx = left-8+min(7,int((x-116+.5)*8/4))
            return sx,sy,"left_rail_compressed"
        sx = right+min(7,int((x-658+.5)*8/2))
        return sx,sy,"right_rail_compressed"
    if 476 <= y < 480 and 116 <= x < 660:
        return 107+min(540,int((x-116+.5)*541/544)),446+int((y-476+.5)*16/4),"near_rim"
    if 480 <= y < 516 and 124 <= x < 660:
        return 123+min(506,int((x-124+.5)*507/536)),464+min(25,int((y-480+.5)*26/36)),"quiet_apron"
    for index,rect in enumerate(POSTS):
        if inside(x,y,rect):
            tx,ty,tw,th = rect; sx,sy,sw,sh = SOURCE_POSTS[index]
            if y < 538:
                row = sy+min(35,int((y-516+.5)*36/22))
            else:
                row = 526+min(3,int((y-538+.5)*4/2))
            return sx+min(sw-1,int((x-tx+.5)*sw/tw)),row,f"post_{index}_" + ("contact" if y>=538 else "dark_timber")
    return None


def assemble(original,raw,sample):
    require(opaque(original,SIZE) and opaque(raw,RAW_SIZE),"Exact opaque original/new raw masters required")
    edges = felt_edges(raw)
    out = bytearray(original.rgba); donors,components = {},{}
    def put(x,y,value,source,kind):
        at=(y*1800+x)*4
        out[at:at+4]=value; donors[x,y]=source; components[x,y]=kind
    # Only the proved green old bottom258..261 is cleared. Its dry-deck
    # underlay is known from R3; normal row262/global seam263 are not cleared.
    for y in range(516,524):
        for x in range(128,604):
            value,where = sample(x,y)
            put(x,y,value,["own_R3_deck",*where],"old_green_bottom_to_own_deck")
    for y in range(356,540):
        for x in range(116,660):
            part=fit_source(raw,x,y,edges)
            if part:
                sx,sy,kind=part
                require(0<=sx<raw.width and 0<=sy<raw.height,"Table source donor escaped raw")
                put(x,y,pixel(raw,sx,sy),["new_generated_left_table_only",sx,sy],kind)
    image=PNGImage(1800,860,bytes(out)); changed=[]
    for y in range(860):
        for x in range(1800):
            if pixel(image,x,y)!=pixel(original,x,y):
                require((x,y) in donors and x<660 and y<540,"Candidate escaped exact LEFT-only repair union")
                changed.append([x,y])
    require(image.rgba[:356*1800*4] == original.rgba[:356*1800*4] and
            image.rgba[540*1800*4:] == original.rgba[540*1800*4:],"Original title/windows/rail274+ changed")
    require(crop(image,(660,0,1140,860)) == crop(original,(660,0,1140,860)),"Right cabinet/architecture changed")
    require(crop(image,COUNTER) == crop(original,COUNTER),"Right master replay crop changed")
    for y in (526,527):
        for x in range(1800):
            if not any(inside(x,y,rect) for rect in POSTS):
                require(pixel(image,x,y) == pixel(original,x,y),"Global deck seam was erased outside physical posts")
    for y in range(524,540):
        for x in range(1800):
            if not any(inside(x,y,rect) for rect in POSTS):
                require(pixel(image,x,y) == pixel(original,x,y),"Normal deck changed outside tight physical posts")
    for rect in ((122,396.08,184,53.76),(466.96,391.11994,190.08,43.2)):
        x0,y0,w,h=rect
        points=[(x,y) for y in range(int(y0),int(y0+h)+1) for x in range(int(x0),int(x0+w)+1)
                if x0<=x+.5<x0+w and y0<=y+.5<y0+h]
        require(points and all(components.get(point)=="felt" for point in points),"Actual BJ/Roulette generic face lacks felt support")
    for y in range(356,516):
        for x in range(128,604):
            require(components.get((x,y)) not in (None,"old_green_bottom_to_own_deck"),"Exposed old corner would need separate wall-donor review")
    posts=[]
    for index,rect in enumerate(POSTS):
        points=[(x,y) for y in range(rect[1],rect[1]+rect[3]) for x in range(rect[0],rect[0]+rect[2])]
        require(all(components.get(point,"").startswith(f"post_{index}_") for point in points) and
                all(components.get((x,515))=="quiet_apron" for x,y in points if y==516),"Complete support/apron connection differs")
        colors=[pixel(image,x,y) for x,y in points]
        require(max(max(p[:3]) for p in colors)<=118 and not any(p[0]>=180 and p[1]>=100 and p[0]>=p[2]+30 for p in colors),
                "Support source is not the observed quiet dark timber")
        posts.append({"index":index,"native_rect":rect,"complete_physical_pixels":len(points),"max_rgb":max(max(p[:3]) for p in colors),
                      "connected_opaque_rectangle":True,"attached_to_apron_native_rows":[515,516],"bottom_exclusive":540})
    return image,{"changed_pixels":len(changed),"changed_native_pixels":changed,
        "per_pixel_final_sources":[[x,y,*donors[x,y],components[x,y]] for x,y in sorted(donors,key=lambda p:(p[1],p[0]))],
        "old_table_native_rect":OLD_PANEL,"only_old_bottom_healed":[128,516,476,8],"new_supports":posts,
        "source_felt_rows":[[sy,*edges[sy]] for sy in sorted(edges)],
        "painted_felt_native_rect":[120,362,538,114],"outer_top_native_rect":[116,356,544,124],
        "apron_native_rect":[124,480,536,36],"source_to_target_y_bands":[[360,374,356,362],[374,446,362,476],[446,462,476,480],[464,490,480,516],[490,526,516,538],[526,530,538,540]],
        "source_frame_compression":{"left_side":"8 source px to4 native px","right_side":"8 source px to2 native px",
            "roulette_generic_right_board":328.52,"felt_right_board":329,"felt_margin_board":0.48,"fixed_right_counter_left_board":330,"physical_right_rail_board_width":1},
        "explicit_physical_occlusions":{"paint_overhang_board_x":[58,330],"old_authority_board_x":[64,302],
            "cream_pier_audit_native_envelope":[624,340,18,152],"pier_changed_only_inside_actual_left_table_silhouette":True,
            "global_deck_seam_native_rows":[526,527],"seam_original_outside_POSTS":True},
        "no_exposed_wall_corner_or_general_wall_donor_used":True,"right_master_and_counter_crop_exact_original":True,
        "all_non_left_table_pixels_outside_new_silhouette_plus_old_bottom_exact":True,"original_rows540_onward_exact":True,
        "no_color_transform_blending_generated_floor_or_global_period":True,
        "perspective_gate":"Compressed wide top/very thin right rail and cabinet adjacency need independent actual-pixel approval; coverage alone is not art approval."}


def historical_inputs(provenance):
    inputs={}
    for path,info in {**provenance["retained_evidence"],**provenance["old_source_recipe"]}.items():
        require(sha(read(Path(path)))==info["sha256"],"Frozen historical/R3 source changed: "+path)
        inputs[path]=info["sha256"]
    require(sha(read(OLD_RAW))==OLD_RAW_SHA and sha(read(OLD_RECIPE))==OLD_RECIPE_SHA and
            sha(read(CONTEXT_ROOT/"delta_preart_metadata.json"))==CONTEXT_REPORT_SHA and
            sha(read(CONTEXT_ROOT/"job.json"))==JOB_SHA and qualified_job(json.loads(read(CONTEXT_ROOT/"job.json"))),
            "Pinned own R3 inputs/closed native source Job differ")
    report=json.loads(read(CONTEXT_ROOT/"delta_preart_metadata.json"))
    require(not report["findings"] and report["checks"]==15411 and
            list(report["views"])==list(provenance["observed_object_counts"]),"Exact six retained contexts required")
    files,ids={},set()
    records=[]
    for scenario,view in report["views"].items():
        rows=view["source_paint"]["objects"]
        require(len(rows)==provenance["observed_object_counts"][scenario],"Retained context object count changed")
        for row in rows:
            ids.add(row["object"]["id"])
            for key in ("body_png","adorn_png"):
                name=row[key]
                require(Path(name).name==name and name.endswith(".png") and name not in files,"Unsafe/duplicate typed PNG")
                files[name]=sha(read(CONTEXT_ROOT/name))
                records.append((name,scenario,row["object"]["id"],key))
    require(len(files)==232 and len(ids)==55 and seal(files)==ALL_MASK_SEAL,"Actual232 PNG/116-record/55-ID mask trace differs")
    relevant={name:row["sha256"] for name,row in provenance["typed_mask_evidence"]["relevant_files"].items()}
    require(len(relevant)==58 and seal(relevant)==RELEVANT_MASK_SEAL and all(files.get(name)==value for name,value in relevant.items()),
            "Pinned58 relevant actor/game mask identities differ")
    cache,checks={},[]
    points=[(x,y) for a,b,w,h in POSTS for y in range(b,b+h) for x in range(a,a+w)]
    for name,scenario,identity,kind in records:
        digest=files[name]
        if digest not in cache:
            image=decode_png(read(CONTEXT_ROOT/name))
            require((image.width,image.height)==SIZE,"Typed PNG must remain actual native1800 canvas")
            collisions=[(x,y) for x,y in points if pixel(image,x,y)[3]>0]
            require(not collisions,"New support intersects actual body/adornment alpha>0: "+name)
            cache[digest]={"positive_alpha_intersections":0,"tested_physical_support_pixels":len(points)}
        checks.append({"png":name,"sha256":digest,"scenario":scenario,"object_id":identity,"kind":kind,**cache[digest]})
        inputs[str(CONTEXT_ROOT/name)]=digest
    return inputs,{"contexts":provenance["observed_object_counts"],"initial_typed_records":116,"distinct_ids":55,
        "all_mask_files":232,"all_mask_seal":ALL_MASK_SEAL,"relevant_mask_files":58,"relevant_mask_seal":RELEVANT_MASK_SEAL,
        "strict_post_alpha_gt0_checks":checks,"reused_identical_PNG_decodes":232-len(cache),
        "all_actor_hit_label_draw_order_and_gameplay_geometry_unchanged":True,
        "scope":"Historical six settled initial scenes only; fresh all-six actual material/depth/selection/motion checks remain mandatory."}


def exact_existing(root,hashes,ignore=False):
    if not root.exists():
        return
    wanted={**hashes,**({".gdignore":sha(IGNORE)} if ignore else {})}
    dirs={p.as_posix() for name in hashes for p in PurePosixPath(name).parents if p.as_posix()!="."}
    files,seen_dirs={},set()
    for path in root.rglob("*"):
        info=path.lstat()
        require(not (getattr(info,"st_file_attributes",0)&0x400) and not stat.S_ISLNK(info.st_mode),"Reparse output path")
        name=path.relative_to(root).as_posix()
        if stat.S_ISDIR(info.st_mode):
            require(name in dirs,"Unexpected existing directory: "+name);seen_dirs.add(name)
        else:
            require(stat.S_ISREG(info.st_mode) and name in wanted,"Unexpected existing payload: "+name)
            files[name]=sha(read(path))
    require(files==wanted and seen_dirs==dirs,"Existing immutable payload differs: "+str(root))


def layout_from_environment():
    record=json.loads(read(Path(os.environ["BTH_QA_EVIDENCE_DIR"])/"storage-manifest.json"))
    layout=Layout(**{key:Path(value) for key,value in record["paths"].items()},
        **{key:record[key] for key in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    validate_layout(layout)
    require(layout.prepared and layout.workspace==WORKSPACE,"Exact prepared Delta E workspace required")
    return layout


def write_fresh(path,data,layout):
    validate_layout(layout,extra_write_paths=(path.parent,))
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open("xb") as handle:
        handle.write(data)


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root",type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        layout=layout_from_environment()
        baseline,sources=WORKSPACE/"source_baseline",WORKSPACE/"candidate_sources"
        output=sources/"delta-queen-spatial-r1-assembled-v1"
        evidence=layout.evidence/"delta-queen-spatial-r1-assembly.json"
        validate_layout(layout,extra_write_paths=(baseline,sources,output,evidence))
        require(not output.exists() and not evidence.exists(),"Fresh immutable candidate/report required")
        source=args.source_root.absolute()
        require(source==Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers"),"Exact art worktree source required")
        recipe_sha,decoder_sha=sha(read(__file__)),sha(read(decode_png.__code__.co_filename))
        provenance_data=read(source/(SOURCE_DIR+"/provenance.json"))
        require(sha(provenance_data)==PROVENANCE_SHA,"Frozen Delta provenance differs")
        provenance=json.loads(provenance_data)
        manifest_data=read(source/MANIFEST)
        require(sha(manifest_data)==MANIFEST_SHA,"Original Delta manifest pin differs")
        manifest=json.loads(manifest_data);names=package_names(manifest,provenance)
        extras=(*CONTROLS,RAW_REL,RAW_REL+".b64",SOURCE_DIR+"/prompt.txt",SOURCE_DIR+"/provenance.json",
                "docs/art/briefs/delta_queen_spatial_repair_20261116.md")
        before=inventory(source,(*names,*extras));original_hashes={name:before[name] for name in names}
        require(seal(original_hashes)==BASELINE_SEAL and original_hashes==provenance["current"]["files"] and
                before[BACKGROUND]==MASTER_SHA and before[RAW_REL]==RAW_SHA and
                before[INDEX]=="11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24",
                "Exact room-only29/raw/separate global index required")
        require(before[RAW_REL+".b64"]=="a3ca51f10e452e1ad8ed6fa784fcf789e5cda4ff1bbe3c5df2e9678afc51a116" and
                base64.b64decode(b"".join(read(source/(RAW_REL+".b64")).split()),validate=True)==read(source/RAW_REL) and
                before[SOURCE_DIR+"/prompt.txt"]=="7355122b0b57564d5ea4a7591ebeff4e589b1f8acb49ac6d0089c8b4c9a97511",
                "Frozen new raw/base64/prompt source differs")
        pack_source=read(source/"scripts/ui/environment_art_pack.gd").decode("utf-8")
        require("var web_low_detail := true" in pack_source and 'entry.web_low_detail = value.get("web_low_detail", true)' in pack_source,
                "Actual entry/parser default-low motion inclusion differs")
        historical_before,context_proof=historical_inputs(provenance)
        payload={name:read(source/name) for name in names}
        original,raw=decode_png(payload[BACKGROUND]),decode_png(read(source/RAW_REL))
        old=decode_png(read(OLD_RAW));sample=deck_sampler(old)
        calibration=calibrate_deck(original,sample)
        candidate,assembly=assemble(original,raw,sample)
        front=decode_png(payload[FRONT])
        require(opaque(front,COUNTER[2:]) and front==crop(original,COUNTER)==crop(candidate,COUNTER),
                "Full540x184 right replay/master crop must remain opaque and pixel-exact")
        payload[BACKGROUND]=encode(candidate)
        hashes={name:sha(payload[name]) for name in names}
        require({name for name in names if hashes[name]!=original_hashes[name]}=={BACKGROUND} and
                all(payload[name]==read(source/name) for name in names if name!=BACKGROUND),
                "Only LEFT-repaired master may change; right PNG/motion/JSON are immutable")
        exact_existing(baseline,original_hashes,ignore=True)
        preserved={"delta-queen-spatial-r1.png":read(source/RAW_REL),"delta-queen-spatial-r1.png.b64":read(source/(RAW_REL+".b64")),
            "prompt.txt":read(source/(SOURCE_DIR+"/prompt.txt")),"provenance.json":provenance_data,
            "delta-original-r3-source.png":read(OLD_RAW),"assemble_delta_v1r3.py.txt":read(OLD_RECIPE)}
        for path in provenance["old_source_recipe"]:
            if path not in (str(OLD_RAW).replace("\\","/"),str(OLD_RECIPE).replace("\\","/")):
                preserved["delta-original-title-source.png"]=read(Path(path))
        if sources.exists():
            require(all(path.is_file() and path.name in set(preserved)|{".gdignore"} for path in sources.iterdir()),
                    "Unexpected source preservation; never overwrite or remove it")
            for path in sources.iterdir():
                require(read(path)==(IGNORE if path.name==".gdignore" else preserved[path.name]),"Existing raw/own-source preservation differs")
        require(inventory(source,(*names,*extras))==before and all(sha(read(Path(path)))==value for path,value in historical_before.items()) and
                sha(read(__file__))==recipe_sha and sha(read(decode_png.__code__.co_filename))==decoder_sha,"Read-only preflight custody changed")
        # FIRST QA WRITES: closed sources, exact 232 alpha clearance, own deck,
        # coverage/rail compression/volume and all storage gates have passed.
        validate_layout(layout,extra_write_paths=(baseline,sources,output,evidence))
        baseline.mkdir(exist_ok=True);sources.mkdir(exist_ok=True)
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
        exact_existing(baseline,original_hashes,ignore=True)
        require(all(read(sources/name)==data for name,data in preserved.items()) and
                all(read(directory/".gdignore")==IGNORE for directory in (baseline,sources)) and
                inventory(source,(*names,*extras))==before and all(sha(read(Path(path)))==value for path,value in historical_before.items()) and
                sha(read(__file__))==recipe_sha and sha(read(decode_png.__code__.co_filename))==decoder_sha,"Final input/output custody differs")
        report={"schema":"bth.delta_queen_spatial_assembly/v1","task_id":"BTH-ENV-SPATIAL-DELTA-001",
            "status":"NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT","observed_at":datetime.now(timezone.utc).isoformat(),
            "recipe_sha256":recipe_sha,"decoder_sha256":decoder_sha,"raw_source":{"path":str(sources/"delta-queen-spatial-r1.png"),"sha256":RAW_SHA,"size":RAW_SIZE},
            "baseline":{"path":str(baseline),"seal":BASELINE_SEAL,"file_count":29,"files":original_hashes},
            "output":{"path":str(output),"seal":seal(hashes),"file_count":29,"files":hashes},"changed_payload_paths":[BACKGROUND],
            "global_index_is_separate_unchanged_control":{"path":INDEX,"sha256":before[INDEX],"included_in_room_only29_seal":False},
            "assembly":assembly,"own_R3_deck_calibration":calibration,"context_clearance":context_proof,
            "counter_crops_exact_opaque":{"delta_right_table":COUNTER},"right_master_and_counter_PNG_exact_original":True,"no_left_replay_added":True,
            "all26_motion_PNGs_full_manifest_and_global_index_unchanged":True,"normal_entries":26,"default_low_detail_entries":26,
            "source_hashes_before":before,"source_hashes_after":inventory(source,(*names,*extras)),
            "historical_source_hashes_before":historical_before,"historical_source_hashes_after":{path:sha(read(Path(path))) for path in historical_before},
            "all_sources_unchanged":True,"old_recipe_executed":False,"active_files_written":False,"runtime_launched":False,"art_approval":False,"test_updated":False,
            "auxiliary_ignore_sentinels":[str(baseline/".gdignore"),str(sources/".gdignore")],
            "ignore_sentinels_excluded_from_logical_29_file_payload":True,
            "baseline_auxiliary_files":{".gdignore":{"bytes":len(IGNORE),"sha256":sha(IGNORE),"ordinary_file":True}},
            "storage_manifest":str(layout.manifest_path),
            "risks":["Wide top and side-rail compression, physical cream-pier occlusion and right-cabinet adjacency require independent actual-pixel approval.",
                     "232 masks prove only retained settled initial-paint clearance; fresh all-six populated/selection/depth/motion/liveness/work-outcome gates remain.",
                     "Deck seam stays exact outside tight physical supports; no source-coverage or static-code result implies art/TEST approval."]}
        write_fresh(evidence,(json.dumps(report,indent=2)+"\n").encode(),layout)
        print(json.dumps({"status":report["status"],"package":str(output),"report":str(evidence),"art_approval":False}))
        return 0
    except (OSError,ValueError,KeyError,TypeError,RuntimeError) as error:
        print(json.dumps({"status":"DELTA_ASSEMBLY_STOPPED","error":str(error),"active_files_written":False,"art_approval":False,"test_updated":False}),file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
