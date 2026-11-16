"""Guarded non-active Delta Queen V2 LEFT tabletop perspective assembly.

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
POSTS = ((200,516,56,24),(620,516,36,24))
FAR_LEFT, NEAR_LEFT, FAR_RIGHT, NEAR_RIGHT, RAIL = 124, 64, 676, 712, 8
FAR_Y, FELT_Y, NEAR_Y, APRON_Y, FOOT_Y, BOTTOM_Y = 352, 358, 476, 488, 516, 540
APRON = (72,488,632,28)  # Conceptual right edge704 is behind the exact cabinet.
FACES = ((122,396.08,184,53.76),(466.96,391.11994,190.08,43.2))
PREDECESSOR_ROOT = WORKSPACE/"candidate_sources/delta-queen-spatial-r1-assembled-v1"
PREDECESSOR_REPORT = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-DELTATRIAL-20261116-assemble01/evidence/delta-queen-spatial-r1-assembly.json")
PREDECESSOR_REPORT_SHA = "378cd3a7e29e23ee3fdf3f8042fd04849e87714b8cc8d6c34c76fd9ae4fd5dbc"
PREDECESSOR_SEAL = "a2458f4cad2efaa21f2a5dd992f8b751544a5c2a7369089bd8863d83faa4645a"
PREDECESSOR_BG_SHA = "c1ce98996e9ba0fd86b102ccd075eef3dc15df49bc797b44d1bc55a92b432577"
PREDECESSOR_RECIPE_SHA = "4a604db0b6eecebe5e99c17d792828b3da224fb73bd4f1a76b187ba98468017f"
PREDECESSOR_REVIEW = "docs/testing/delta_queen_spatial_r1_static_review_v1_20261116.json"
PREDECESSOR_REVIEW_SHA = "d1246772b75c8bd0ff8ed8d8d0bf7d580d321c26aa6ed7f6c3a473d210b25504"

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


def green_material(value):
    return value[1]>value[0]+6 and value[1]>value[2]+4


def table_material(value):
    red,green,blue,_=value
    return green_material(value) or (red>=70 and green>=45 and 2*green>=red and 20*blue<13*green)


def trace_material_row(raw,sy):
    """Conservative real table material, excluding the adjacent redwood wall.

    The longest green run is the inner felt, not the outside green reflection
    that precedes the gold rail. Outer chromatic bounds stay inside the actual
    solid table silhouette; dark object pixels between those bounds are kept.
    """
    outer=[x for x in range(105,648) if table_material(pixel(raw,x,sy))]
    require(outer and outer[-1]+1-outer[0]>350,"Missing physical source table row")
    runs=[]; start=None
    for x in range(105,649):
        active=x<648 and green_material(pixel(raw,x,sy))
        if active and start is None:
            start=x
        if not active and start is not None:
            runs.append((start,x)); start=None
    inner=max(runs,key=lambda pair:pair[1]-pair[0]) if runs else (None,None)
    return outer[0],inner[0],inner[1],outer[-1]+1


def source_rows(raw):
    rows={sy:trace_material_row(raw,sy) for sy in range(363,460)}
    for sy in range(374,438):
        outer,left,right,end=rows[sy]
        require(left is not None and right-left>=400 and outer<left<right<end and
                all(green_material(pixel(raw,x,sy)) for x in range(left,right)),
                "Actual inner felt or physical side rail trace differs")
    return rows


def apron_source_bounds(sy):
    require(464<=sy<490,"Exact raw apron row required")
    dy=sy-464
    return 123+(6*dy+24)//25,630-(4*dy+24)//25


def top_bounds(y, near_left=NEAR_LEFT):
    """Full physical top before the fixed cabinet occludes native x660 onward."""
    require(FELT_Y <= y < NEAR_Y and 0 <= near_left < FAR_LEFT, "Exact sloping felt row required")
    # Quantize each pixel-center edge inward; the target rail stays8 pixels wide.
    numerator, denominator = 2*(y-FELT_Y)+1, 2*(NEAR_Y-FELT_Y)
    left = FAR_LEFT - ((FAR_LEFT-near_left)*numerator//denominator)
    right = FAR_RIGHT + ((NEAR_RIGHT-FAR_RIGHT)*numerator//denominator)
    return left,right


def face_points(rect):
    x0,y0,w,h=rect
    return [(x,y) for y in range(int(y0),int(y0+h)+1) for x in range(int(x0),int(x0+w)+1)
            if x0<=x+.5<x0+w and y0<=y+.5<y0+h]


def fit_source(raw,x,y,edges):
    # The original fully opaque cabinet physically occludes the right side.
    # Never synthesize a two-pixel vertical rail in the remaining strip.
    if x >= COUNTER[0]:
        return None
    if FAR_Y <= y < FELT_Y and FAR_LEFT <= x < FAR_RIGHT:
        sy=363+min(10,int((y-FAR_Y+.5)*11/(FELT_Y-FAR_Y)))
        source_left,_,_,source_right=edges[sy]
        sx=source_left+min(source_right-source_left-1,int((x-FAR_LEFT+.5)*(source_right-source_left)/(FAR_RIGHT-FAR_LEFT)))
        return sx,sy,"far_rim"
    if FELT_Y <= y < NEAR_Y:
        left,right=top_bounds(y)
        if not left<=x<right:
            return None
        sy=374+min(63,int((y-FELT_Y+.5)*64/(NEAR_Y-FELT_Y)))
        source_outer,source_left,source_right,source_end=edges[sy]
        if left+RAIL <= x < right-RAIL:
            width=right-left-2*RAIL
            sx=source_left+min(source_right-source_left-1,int((x-left-RAIL+.5)*(source_right-source_left)/width))
            return sx,sy,"felt"
        if x < left+RAIL:
            width=source_left-source_outer
            return source_outer+min(width-1,int((x-left+.5)*width/RAIL)),sy,"left_rail_traced_material"
        width=source_end-source_right
        return source_right+min(width-1,int((x-right+RAIL+.5)*width/RAIL)),sy,"right_rail_traced_material"
    if NEAR_Y <= y < APRON_Y and NEAR_LEFT <= x < NEAR_RIGHT:
        sy=438+min(21,int((y-NEAR_Y+.5)*22/(APRON_Y-NEAR_Y)))
        source_left,_,_,source_right=edges[sy]
        return source_left+min(source_right-source_left-1,int((x-NEAR_LEFT+.5)*(source_right-source_left)/(NEAR_RIGHT-NEAR_LEFT))),sy,"near_rim"
    if inside(x,y,APRON):
        tx,ty,tw,th=APRON
        sy=464+min(25,int((y-ty+.5)*26/th))
        source_left,source_right=apron_source_bounds(sy)
        return source_left+min(source_right-source_left-1,int((x-tx+.5)*(source_right-source_left)/tw)),sy,"quiet_apron"
    for index,rect in enumerate(POSTS):
        if inside(x,y,rect):
            tx,ty,tw,th=rect; sx,sy,sw,sh=SOURCE_POSTS[index]
            if y < 538:
                row=sy+min(35,int((y-FOOT_Y+.5)*36/22))
            else:
                row=526+min(3,int((y-538+.5)*4/2))
            return sx+min(sw-1,int((x-tx+.5)*sw/tw)),row,f"post_{index}_" + ("contact" if y>=538 else "dark_timber")
    return None


def geometry_contract(edges):
    require(NEAR_LEFT==64 and RAIL==8 and APRON==(72,488,632,28), "Exact reviewed V2 geometry required")
    rows=[]
    for y in range(FELT_Y,NEAR_Y):
        left,right=top_bounds(y)
        require(right-RAIL>COUNTER[0] and
                all(fit_source(None,x,y,edges)[2]=="left_rail_traced_material" for x in range(left,left+RAIL)),
                "Physical right edge must be occluded; visible left rail must use8 native pixels of real material")
        rows.append({"native_y":y,"logical_outer":[left,right],"logical_felt":[left+RAIL,right-RAIL],
                     "visible_draw_half_open":[left,COUNTER[0]],"visible_felt_half_open":[left+RAIL,COUNTER[0]]})
    require(rows[0]["logical_outer"][0]-rows[-1]["logical_outer"][0]>=59 and
            rows[-1]["visible_draw_half_open"][1]-rows[-1]["visible_draw_half_open"][0]>
            rows[0]["visible_draw_half_open"][1]-rows[0]["visible_draw_half_open"][0]+58,
            "A constant-width or near-vertical top is forbidden")
    faces=[]
    for index,rect in enumerate(FACES):
        points=face_points(rect)
        require(points and all((part:=fit_source(None,x,y,edges)) is not None and part[2]=="felt" for x,y in points),
                "Actual full generic BJ/Roulette contact face must remain on felt")
        margins=[x-(top_bounds(y)[0]+RAIL) for x,y in points]
        if index==0:
            require(min(margins)>=8, "Blackjack requires at least8 native pixels left felt margin")
        faces.append({"id":("blackjack","roulette")[index],"native_rect":rect,"tested_pixel_centers":len(points),
                      "minimum_left_pixel_margin_native":min(margins),"all_felt":True,
                      "wheel_cards_and_raised_accents_are_not_flat_surface_contact":True})
    comparisons=[]
    for value in (44,64,68,72,84):
        margins=[x-(top_bounds(y,value)[0]+RAIL) for x,y in face_points(FACES[0])]
        comparisons.append({"near_left_native":value,"minimum_BJ_left_pixel_margin_native":min(margins),
                            "near_expansion_from_V1_outer116_native":116-value})
    maximum=max(value for value in range(1,FAR_LEFT) if
                min(x-(top_bounds(y,value)[0]+RAIL) for x,y in face_points(FACES[0]))>=8)
    require(maximum==68 and NEAR_LEFT==maximum-4, "Minimal8px-margin fit comparison changed")
    return {"far_outer_native":[FAR_LEFT,FAR_Y,FAR_RIGHT,FELT_Y],"near_outer_native":[NEAR_LEFT,NEAR_Y,NEAR_RIGHT,APRON_Y],
            "target_felt_rows":rows,"full_generic_face_coverage":faces,"near_left_comparison":comparisons,
            "largest_near_left_meeting8px_BJ_margin_native":maximum,
            "selected_near_left_native":NEAR_LEFT,"additional_safety_expansion_native":maximum-NEAR_LEFT,
            "selection_reason":"64 keeps at least9 native pixel-center margin and a59px visible side convergence;44 adds20px near overhang without a contact need.",
            "right_edge_policy":"True sloping logical rail lies behind the unchanged opaque cabinet; native x660 onward stays original, not a compressed visible rail."}


def assemble(original,raw,sample):
    require(opaque(original,SIZE) and opaque(raw,RAW_SIZE),"Exact opaque original/new raw masters required")
    edges=source_rows(raw); geometry=geometry_contract(edges)
    out=bytearray(original.rgba); donors,components={},{}
    def put(x,y,value,source,kind):
        at=(y*1800+x)*4
        out[at:at+4]=value; donors[x,y]=source; components[x,y]=kind
    for y in range(516,524):
        for x in range(128,604):
            value,where=sample(x,y)
            put(x,y,value,["own_R3_deck",*where],"old_green_bottom_to_own_deck")
    for y in range(FAR_Y,BOTTOM_Y):
        for x in range(NEAR_LEFT,COUNTER[0]):
            part=fit_source(raw,x,y,edges)
            if part:
                sx,sy,kind=part
                require(0<=sx<raw.width and 0<=sy<raw.height,"Table source donor escaped raw")
                put(x,y,pixel(raw,sx,sy),["new_generated_left_table_only",sx,sy],kind)
    image=PNGImage(1800,860,bytes(out)); changed=[]
    for y in range(860):
        for x in range(1800):
            if pixel(image,x,y)!=pixel(original,x,y):
                require((x,y) in donors and NEAR_LEFT<=x<660 and FAR_Y<=y<BOTTOM_Y,
                        "Candidate escaped exact widened LEFT-only physical union")
                changed.append([x,y])
    require(image.rgba[:FAR_Y*1800*4]==original.rgba[:FAR_Y*1800*4] and
            image.rgba[BOTTOM_Y*1800*4:]==original.rgba[BOTTOM_Y*1800*4:],
            "Original title/windows/rail274+ changed")
    require(crop(image,(660,0,1140,860))==crop(original,(660,0,1140,860)) and
            crop(image,COUNTER)==crop(original,COUNTER),"Right cabinet/architecture/master replay changed")
    for y in range(524,540):
        for x in range(1800):
            if not any(inside(x,y,rect) for rect in POSTS):
                require(pixel(image,x,y)==pixel(original,x,y),"Normal/global-seam deck changed outside tight physical posts")
    for rect in FACES:
        require(all(components.get(point)=="felt" for point in face_points(rect)),
                "Actual BJ/Roulette full generic contact face lacks felt support")
    # Every old panel texel remains within the real table silhouette: no newly
    # exposed triangular corner and no invented repeating wall donor.
    for y in range(356,516):
        for x in range(128,604):
            require(components.get((x,y)) not in (None,"old_green_bottom_to_own_deck"),
                    "Exposed old corner would need separate wall-donor review")
    posts=[]
    for index,rect in enumerate(POSTS):
        points=[(x,y) for y in range(rect[1],rect[1]+rect[3]) for x in range(rect[0],rect[0]+rect[2])]
        require(all(components.get(point,"").startswith(f"post_{index}_") for point in points) and
                all(components.get((x,515))=="quiet_apron" for x,y in points if y==516),
                "Complete support/apron connection differs")
        colors=[pixel(image,x,y) for x,y in points]
        require(max(max(p[:3]) for p in colors)<=118 and
                not any(p[0]>=180 and p[1]>=100 and p[0]>=p[2]+30 for p in colors),
                "Support source is not quiet dark timber")
        posts.append({"index":index,"native_rect":rect,"complete_physical_pixels":len(points),
                      "max_rgb":max(max(p[:3]) for p in colors),"connected_opaque_rectangle":True,
                      "attached_to_apron_native_rows":[515,516],"bottom_exclusive":540})
    return image,{"changed_pixels":len(changed),"changed_native_pixels":changed,
        "per_pixel_final_sources":[[x,y,*donors[x,y],components[x,y]] for x,y in sorted(donors,key=lambda p:(p[1],p[0]))],
        "old_table_native_rect":OLD_PANEL,"only_old_bottom_healed":[128,516,476,8],"new_supports":posts,
        "source_material_rows":[[sy,*edges[sy]] for sy in sorted(edges)],"source_material_row_fields":["raw_y","outer_left","inner_felt_left","inner_felt_right_exclusive","outer_right_exclusive"],
        "source_trace_policy":"Conservative first/last chromatic table texels; inner felt is longest contiguous green run. No green-min-minus8 wall donors.",
        "source_rail_width_to_target8":[[sy,edges[sy][1]-edges[sy][0],8] for sy in range(374,438)],
        "source_apron_row_bounds":[[sy,*apron_source_bounds(sy)] for sy in range(464,490)],"plane_geometry":geometry,
        "apron_native_rect":APRON,"source_to_target_y_bands":[[363,374,352,358],[374,438,358,476],[438,460,476,488],
             [464,490,488,516],[490,526,516,538],[526,530,538,540]],
        "physical_overhang_native":{"logical_apron_left_to_left_post":POSTS[0][0]-APRON[0],
             "right_post_to_logical_apron_right":APRON[0]+APRON[2]-POSTS[1][0]-POSTS[1][2],
             "right_post_to_visible_cabinet":660-POSTS[1][0]-POSTS[1][2],
             "left_support_width":POSTS[0][2],"right_support_width":POSTS[1][2],
             "all_supports_alpha_gt0_clearance_checked_before_write":True},
        "explicit_physical_occlusions":{"visible_draw_native_x_half_open":[64,660],"old_authority_board_x":[64,302],
             "cream_pier_audit_native_envelope":[624,340,18,152],"pier_changed_only_inside_actual_left_table_silhouette":True,
             "right_cabinet_exact_native_rect":COUNTER,"global_deck_seam_native_rows":[526,527],"seam_original_outside_POSTS":True},
        "no_exposed_wall_corner_or_general_wall_donor_used":True,"right_master_and_counter_crop_exact_original":True,
        "all_pixels_outside_exact_donor_union_original":True,"original_rows540_onward_exact":True,
        "no_color_transform_blending_generated_floor_or_global_period":True,
        "perspective_gate":"Actual V2 pixels must show the sloping left rail and near apron with the right edge honestly occluded. Geometry/coverage alone does not approve art."}


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


def predecessor_custody(source):
    recipe=source/"tools/assemble_delta_queen_spatial_candidate.py"
    review_path=source/PREDECESSOR_REVIEW
    require(sha(read(recipe))==PREDECESSOR_RECIPE_SHA and sha(read(review_path))==PREDECESSOR_REVIEW_SHA and
            sha(read(PREDECESSOR_REPORT))==PREDECESSOR_REPORT_SHA, "Frozen rejectedV1 recipe/review/report changed")
    review=json.loads(read(review_path)); report=json.loads(read(PREDECESSOR_REPORT))
    files=report["output"]["files"]
    require(review.get("decision")=="NO_GO_FOR_NATIVE_TRIAL" and review.get("background_sha256")==PREDECESSOR_BG_SHA and
            report["recipe_sha256"]==PREDECESSOR_RECIPE_SHA and report["baseline"]["seal"]==BASELINE_SEAL and
            report["output"]["seal"]==seal(files)==PREDECESSOR_SEAL and len(files)==29 and files[BACKGROUND]==PREDECESSOR_BG_SHA and
            Path(report["output"]["path"])==PREDECESSOR_ROOT, "RejectedV1 identity/decision differs")
    exact_existing(PREDECESSOR_ROOT,files)
    inputs={str(recipe):PREDECESSOR_RECIPE_SHA,str(review_path):PREDECESSOR_REVIEW_SHA,
            str(PREDECESSOR_REPORT):PREDECESSOR_REPORT_SHA}
    inputs.update({str(PREDECESSOR_ROOT/name):digest for name,digest in files.items()})
    producer=review["closed_producer"]; job_path=Path(producer["job_path"]); folder=job_path.parent
    job=json.loads(read(job_path)); claim=json.loads(read(folder/"launch-claim.json"))
    for path,digest in ((job_path,producer["job_sha256"]),(folder/"storage-manifest.json",producer["storage_manifest_sha256"]),
                        (folder/"launch-claim.json",producer["launch_claim_sha256"]),(folder/"worker.log",producer["worker_log_sha256"])):
        require(sha(read(path))==digest, "RejectedV1 closed producer custody changed")
        inputs[str(path)]=digest
    require(qualified_job(job) and job["storage_manifest_sha256"]==claim["manifest_sha256"]==producer["storage_manifest_sha256"],
            "RejectedV1 producer is not exact closed/capped/zero")
    return inputs,{"path":str(PREDECESSOR_ROOT),"files":files,"seal":PREDECESSOR_SEAL,
        "background_sha256":PREDECESSOR_BG_SHA,"recipe_sha256":PREDECESSOR_RECIPE_SHA,"review_sha256":PREDECESSOR_REVIEW_SHA,
        "proof_sha256":PREDECESSOR_REPORT_SHA,"closed_job_sha256":producer["job_sha256"],
        "status":"V1 remains rejected for DELTA-V1-TOP-PLANE; no previous result relabeled PASS."}


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
        output=sources/"delta-queen-spatial-r1-assembled-v2"
        evidence=layout.evidence/"delta-queen-spatial-r1-assembly-v2.json"
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
                "docs/art/briefs/delta_queen_spatial_repair_20261116.md",
                PREDECESSOR_REVIEW,"tools/assemble_delta_queen_spatial_candidate.py",
                "tools/assemble_delta_queen_spatial_candidate_v2.README.md","tools/test_assemble_delta_queen_spatial_candidate_v2.py")
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
        predecessor_inputs,predecessor_proof=predecessor_custody(source)
        historical_before.update(predecessor_inputs)
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
            require(all((path.is_dir() and path.name==PREDECESSOR_ROOT.name) or
                        (path.is_file() and path.name in set(preserved)|{".gdignore"}) for path in sources.iterdir()),
                    "Only the exact immutable V1 directory and pinned raw preservation may preexist")
            for path in sources.iterdir():
                if path.name==PREDECESSOR_ROOT.name:
                    exact_existing(path,predecessor_proof["files"])
                else:
                    require(read(path)==(IGNORE if path.name==".gdignore" else preserved[path.name]),
                            "Existing raw/own-source preservation differs")
        require(inventory(source,(*names,*extras))==before and all(sha(read(Path(path)))==value for path,value in historical_before.items()) and
                sha(read(__file__))==recipe_sha and sha(read(decode_png.__code__.co_filename))==decoder_sha,"Read-only preflight custody changed")
        # FIRST QA WRITES: closed sources, exact 232 alpha clearance, own deck,
        # converging plane/contact/volume and all storage gates have passed.
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
                sha(read(__file__))==recipe_sha and sha(read(decode_png.__code__.co_filename))==decoder_sha and
                predecessor_custody(source)[1]==predecessor_proof,"Final input/output custody differs")
        report={"schema":"bth.delta_queen_spatial_assembly/v2","task_id":"BTH-ENV-SPATIAL-DELTA-001",
            "status":"NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT","observed_at":datetime.now(timezone.utc).isoformat(),
            "recipe_sha256":recipe_sha,"decoder_sha256":decoder_sha,"raw_source":{"path":str(sources/"delta-queen-spatial-r1.png"),"sha256":RAW_SHA,"size":RAW_SIZE},
            "baseline":{"path":str(baseline),"seal":BASELINE_SEAL,"file_count":29,"files":original_hashes},
            "output":{"path":str(output),"seal":seal(hashes),"file_count":29,"files":hashes},"changed_payload_paths":[BACKGROUND],
            "global_index_is_separate_unchanged_control":{"path":INDEX,"sha256":before[INDEX],"included_in_room_only29_seal":False},
            "assembly":assembly,"own_R3_deck_calibration":calibration,"context_clearance":context_proof,"preserved_rejected_v1":predecessor_proof,
            "counter_crops_exact_opaque":{"delta_right_table":COUNTER},"right_master_and_counter_PNG_exact_original":True,"no_left_replay_added":True,
            "all26_motion_PNGs_full_manifest_and_global_index_unchanged":True,"normal_entries":26,"default_low_detail_entries":26,
            "source_hashes_before":before,"source_hashes_after":inventory(source,(*names,*extras)),
            "historical_source_hashes_before":historical_before,"historical_source_hashes_after":{path:sha(read(Path(path))) for path in historical_before},
            "all_sources_unchanged":True,"old_recipe_executed":False,"active_files_written":False,"runtime_launched":False,"art_approval":False,"test_updated":False,
            "auxiliary_ignore_sentinels":[str(baseline/".gdignore"),str(sources/".gdignore")],
            "ignore_sentinels_excluded_from_logical_29_file_payload":True,
            "baseline_auxiliary_files":{".gdignore":{"bytes":len(IGNORE),"sha256":sha(IGNORE),"ordinary_file":True}},
            "storage_manifest":str(layout.manifest_path),
            "risks":["Actual converging left top, broad near overhang, physical cream-pier/cabinet occlusion and apron/support mass require independent actual-pixel approval.",
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
