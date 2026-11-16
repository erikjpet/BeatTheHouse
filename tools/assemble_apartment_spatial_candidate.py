"""Non-active Apartment floor/contact assembly; root executes only after review.

Exact original silhouettes, patch-only raw NN donors, and a narrow original
floor join. No generation, engine, child, network, cleanup, move or activation.
Kitchen-strip material disposition stays OPEN. Candidate pixels are not approval.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import struct
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import Layout, StorageGuardError, validate_layout
import bth_qa_storage as storage

SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
QA_ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = QA_ROOT / "workspaces/BTH-ENV-SPATIAL-APARTMENTTRIAL-20261116"
ARTIFACT = "review_artifacts/environment_art_sources/apartment-spatial-r1"
BACKGROUND = "assets/art/environments/apartment/background.png"
MANIFEST = "data/art/environments/apartment.json"
INDEX = "data/art/environments/index.json"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
BASELINE_SEAL = "546a482bc114b1a8d0db0400be9bd0b6df7e0837ad49bc0aeac3cf1c82586753"
RAW_SHA = "547e61e06a73c0e9e49502280fe5302bbe1243e8920dea3e2d23802f17c9d2a9"
RAW_BYTES = 1817231
B64_SHA = "68ad91d4f97fd6db31fe5e8b13da5d3b87d113966039362f8d99f96bfc4877c7"
PROVENANCE_SHA = "25dd79abed560f1527d9890dd69720fad2ace838001dbd2941d38eaa8324f92a"
PRESERVATION_SHA = "bb0208c65218cde62ecec4c83d5e2845c6fc0d4204d1db7536fa939906578d38"
PLAN_SHA = "597461fb253d18d693e54ebd849d9496ca958587760be5c161038795e77fc911"
BRIEF = "docs/art/briefs/apartment_spatial_repair_20261116.md"
BRIEF_SHA = "bfe9b2019669e071d8e43b926dbc7cfcabe2a4b8248b639e88a9f3569186d1e0"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
DECODE_EVIDENCE = QA_ROOT / "runs/BTH-ENV-SPATIAL-APARTMENTTRIAL-20261116-rawdecode01/evidence"
CONTEXT_EVIDENCE = QA_ROOT / "runs/BTH-ENVART-APARTMENTTRIAL-20261115-r2-contexts-01/evidence"
CONTEXT_SHA = "a553c9031b9cbae07690031b4e1a7f5c7811902c5ec9679faa4a05ba36b3e1c6"
PACKAGE_NAME = "apartment-spatial-r1-assembled-v1"
IGNORE = b"# Non-active Apartment source/baseline/candidates; exclude from Godot discovery.\n"
HELPERS = {
    "bar_spatial_candidate_check.py": "bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f",
    "bth_qa_storage.py": "cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
    "bth_qa_guarded_run.py": "7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
    "bth_qa_command_paths.py": "bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b",
    "decode_apartment_spatial_raw.py": "0f55f8083928764c2243e71aa162b35282e45d6fbe3aa4ee44d78fecf52dd376",
    "decode_kitty_spatial_raw.py": "532ca2652b9f88f535a7f1d71a7b2f95ac5f2bd387e3961fc212c4ebfd848636",
}
PAYLOAD = {
    "assets/art/environments/apartment/anim/floor_glint_0.png": "bb4f5c707031c24c8f05cca373ab66cb3fb8ea2a729a2dafd6112be0576bc490",
    "assets/art/environments/apartment/anim/floor_glint_1.png": "8c3943c4d07602da082a29d49d5d092f1d26dd1726cdf1789cabef2073b1c21a",
    "assets/art/environments/apartment/anim/floor_glint_2.png": "411d358e941a5867df0c7edc1f58fe72c1c81633c1bc7f1b2c4ed8453156775b",
    "assets/art/environments/apartment/anim/floor_glint_3.png": "18868f32b541dc3a10c44c3dc109054745b7f1e07953883700b4d27ad0ebfa3d",
    "assets/art/environments/apartment/anim/floor_glint_4.png": "36cb42a27c9b0588e0130993d78403243e1c11255fce38a0a16097dd4d1d7147",
    "assets/art/environments/apartment/anim/floor_glint_5.png": "3658013941c5c6b6a3ca7484d9018e893a681aa97eaef8e2f212451a6362ed27",
    "assets/art/environments/apartment/anim/floor_glint_6.png": "d8f87fdc51b4401fef0d151975fb2963bbd43919625a8e6aec9234087627bb57",
    "assets/art/environments/apartment/anim/kitchen_strip.png": "5569d55f5ee1dd1f8517ad567acd2d26829bc0a76a75106b66dd2a668f35e0a4",
    "assets/art/environments/apartment/anim/room_ribbon_0.png": "730e04be2d2c3639746bfedff7e85645fc3cad570ac174d716c94ecc1dd323c7",
    "assets/art/environments/apartment/anim/room_ribbon_1.png": "19e257e358635ceaf248747dc4bf378b2e1271e98359c2bb0e2416005125ac5c",
    "assets/art/environments/apartment/anim/room_ribbon_2.png": "5a0ca53858b0e444f7e2a73adbe5e9a62fd9f15c8db4c30aab6da52980941edb",
    "assets/art/environments/apartment/anim/room_ribbon_3.png": "d1a6c42388bacade61f0155dfc4efd53ef1ff56bb969ed64685b5d3cf7b3a0b4",
    "assets/art/environments/apartment/anim/room_ribbon_4.png": "9386f643045668fde1a419f1b9a26d111513d619da90dd32c775006c27a94b0f",
    "assets/art/environments/apartment/anim/window_pulse.png": "9a80ff9347e6fb44cb9dba58ffde40c923169661d636145273e89abfae44d60e",
    "assets/art/environments/apartment/background.png": "30ef28ec1cde5329b2ac3f6244df850b32d8ef423e77ee23ccdc0943c7fe1f44",
    "data/art/environments/apartment.json": "fbf295a0ecb2b6f22497db5afd8c44e791ce15f3894b0500ae7c59b350f244b9"
}
MASKS = {
    "__none_host_0_adorn.png": "459455b2cc33ce14a17a1e9e910b6187f1e70f100368713d933b3937673be7c6",
    "__none_host_0_body.png": "dd5ae360618fcc4d8c43d8826e093450a59033557d4c6b291a25598263b1452b",
    "__none_host_1_adorn.png": "3cdd60d3e0496d863e3527430e24139ee1fd2dd862ad1bdb001a830ab37cee0c",
    "__none_host_1_body.png": "9fc29fdd874de140e1917f6512cdf65b74274381b94a3b77304ad68b985a934b",
    "__none_host_2_adorn.png": "039a412d4536263bfe6a2f7e90e352d16a4439134d5660f03c8088026dce566e",
    "__none_host_2_body.png": "4c3b336b14fcbdc449e163943ff0878e1005660100b54598b8f3b47a1339fd37",
    "__none_host_3_adorn.png": "9ed61d4a0f8fb8b804f9f56d8a89521297163cb0b18ad0c3e1eaa76e23fa8801",
    "__none_host_3_body.png": "f1333b7262eaa1639ce6a5e9133e85d4548d0d3cfb30c1b0d4a62bedf9f7488a",
    "__none_host_4_adorn.png": "a88594d515aa3c6662b5b703271a281da7da1d4e922ad7b5da66dbbe04feed73",
    "__none_host_4_body.png": "bb3e30d1a2297d98cf53cbfb1555fc05f4cdb3c9a9d88a50c909b3d429ee80d4",
    "__none_host_5_adorn.png": "2fbd7448df5f7c0b381204e003d7939fd3db1d66dff7b37c3eea1389c0bb1143",
    "__none_host_5_body.png": "3a013087a4f94cc169ac5a1857d790d3f80f4828d8f5377066c1859601a9fff2",
    "__none_host_6_adorn.png": "7c9c607f8ad66ad52cc5fc16294e857a6529acbe8163116d05597cdc609c78c3",
    "__none_host_6_body.png": "9ef39a673056f2b71ff86e82d8d13ec09654da53bd7954ac989176777754252b"
}
# Half-open source MATERIAL runs from independent actual-pixel inspection.
PROTECTED = (
    (428, 432, ((652,676),(1044,1068),(1178,1192),(1252,1698))),
    (432, 444, ((652,676),(1044,1068),(1148,1224),(1252,1698))),
    (444, 452, ((1148,1224),(1252,1698))),
)
SKIRT_Y = (434, 436, 438, 440, 444, 446)
# Conservative RAW DONOR rejection boxes, never preservation rectangles.
RAW_SUPPORT_ROIS = ((640,420,68,38),(1038,420,72,38),
                    (1144,420,100,40),(1248,420,470,40))


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def seal(files):
    return sha("\n".join(name+" "+value for name,value in sorted(files.items())).encode())


def plain(value):
    path = Path(value)
    require(path.is_absolute() and ".." not in path.parts, "Explicit absolute ordinary path required")
    for item in (path, *path.parents):
        try:
            info = item.lstat()
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(info.st_mode) and
                not getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT,
                "Symlink/reparse path rejected: "+str(item))
        require(stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode), "Nonordinary path rejected")
        if item != path:
            require(stat.S_ISDIR(info.st_mode), "Nondirectory ancestor rejected")
    require(path.resolve(strict=False) == path, "Resolved path alias rejected")
    return path


def read(value, limit=32*1024**2):
    path = plain(value)
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_size <= limit, "Bounded ordinary input required")
    data = path.read_bytes()
    after = path.lstat()
    require((info.st_size,info.st_mtime_ns,info.st_ino) == (after.st_size,after.st_mtime_ns,after.st_ino)
            and len(data) == info.st_size, "Input changed while reading")
    return data


def read_json(path):
    return json.loads(read(path))


def qualified_job(job, exit_code=0):
    limits = job.get("limits", {})
    return (job.get("exit_code") == exit_code and job.get("active_at_release") == 0 and
        job.get("assigned_before_execution") is True and job.get("timed_out") is False and
        job.get("error") is None and job.get("cleanup_errors") == [] and not job.get("log_error") and
        job.get("log_truncated") is False and limits.get("cpu_rate") == 1200 and
        limits.get("job_memory_limit_bytes") == 2*1024**3 and limits.get("kill_on_close") is True and
        limits.get("breakaway_allowed") is False)


def helpers():
    require(plain(storage.__file__) == SOURCE_ROOT/"tools/bth_qa_storage.py", "Exact D storage import required")
    require(sha(read(sys.executable)) == PYTHON_SHA, "Qualified Python differs")
    for name, expected in HELPERS.items():
        require(sha(read(SOURCE_ROOT/"tools"/name)) == expected, "Frozen helper differs: "+name)


def raw_custody(root):
    artifact = root/ARTIFACT
    receipt_bytes = read(artifact/"raw-preservation-receipt.json")
    require(sha(receipt_bytes) == PRESERVATION_SHA, "Root raw preservation receipt differs")
    receipt = json.loads(receipt_bytes)
    require(receipt["status"] == "EXACT_GENERATED_RAW_PRESERVED" and receipt["PNG_sha256"] == RAW_SHA and
            receipt["bytes"] == RAW_BYTES and receipt["exact_encoded_decoded_and_both_PNG_bytes_equal"] is True and
            receipt["Library"]["status"] == "succeeded" and receipt["Library"]["current_version_number"] == 0,
            "Actual D/E/Library raw preservation identity required")
    record = receipt["qualified_decode_job"]
    for name,key in (("job.json","job_sha256"),("worker.log","log_sha256"),
        ("apartment-spatial-r1-decode.json","own_decode_receipt_sha256"),
        ("storage-manifest.json","storage_manifest_sha256"),("launch-claim.json","launch_claim_sha256")):
        require(sha(read(DECODE_EVIDENCE/name)) == record[key], "Actual closed decoder evidence differs: "+name)
    job = read_json(DECODE_EVIDENCE/"job.json")
    require(qualified_job(job) and job["pid"] == record["pid"] == 43312, "Raw decoder closed caps differ")
    command = [str(Path("C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe")), "-B",
        str(SOURCE_ROOT/"tools/decode_apartment_spatial_raw.py"), "--source-root", str(SOURCE_ROOT),
        "--workspace", str(WORKSPACE), "--output", str(WORKSPACE/"raw_source/apartment-spatial-r1.png")]
    require([str(x).replace("\\","/") for x in job["command"]] ==
            [x.replace("\\","/") for x in command], "Actual decoder command differs")
    storage_record = read_json(DECODE_EVIDENCE/"storage-manifest.json")
    claim = read_json(DECODE_EVIDENCE/"launch-claim.json")
    require(storage_record["prepared"] is True and storage_record["expected_write_bytes"] == 4*1024**3 and
            storage_record["reserve_bytes"] == 20*1024**3 and
            Path(storage_record["paths"]["workspace"]) == WORKSPACE and
            job["storage_manifest_sha256"] == claim["manifest_sha256"] == record["storage_manifest_sha256"],
            "Raw decode admission/claim differs")
    own = read_json(DECODE_EVIDENCE/"apartment-spatial-r1-decode.json")
    require(own["status"] == "EXACT_GENERATED_RAW_PNG_MATERIALIZED" and own["output_sha256"] == RAW_SHA and
            own["historical_kitty_postwrite_stop"]["job_sha256"] ==
            "f6ed8c6be02af3551fb5ff2794c2419b2cbc9c394fe6a4cd7415fd3881e220ea" and
            own["historical_kitty_postwrite_stop"]["retry_cleanup_or_overwrite_performed"] is False,
            "Actual decoder proof/history differs; old Kitty FAIL remains retained")
    encoded = read(artifact/"apartment-spatial-r1.png.b64")
    raw = read(artifact/"apartment-spatial-r1.png")
    require(len(encoded) == 2422977 and sha(encoded) == B64_SHA and encoded.count(b"\n") == 1 and
            encoded.endswith(b"\n") and b"\r" not in encoded and base64.b64decode(encoded[:-1],validate=True) == raw and
            len(raw) == RAW_BYTES and sha(raw) == RAW_SHA and
            read(WORKSPACE/"raw_source/apartment-spatial-r1.png") == raw, "Exact D/E/B64 raw bytes differ")
    return raw, {"root_receipt_sha256":PRESERVATION_SHA, "decoder_job_sha256":record["job_sha256"],
                 "own_decode_receipt_sha256":record["own_decode_receipt_sha256"],
                 "Library":receipt["Library"], "historical_kitty_failure_relabelled":False}


def inputs(root):
    helpers()
    for name, expected in {**PAYLOAD, INDEX:INDEX_SHA, BRIEF:BRIEF_SHA,
        ARTIFACT+"/provenance.json":PROVENANCE_SHA, ARTIFACT+"/assembly-plan.json":PLAN_SHA}.items():
        require(sha(read(root/name)) == expected, "Pinned Apartment source/control differs: "+name)
    require(len(PAYLOAD) == 16 and seal(PAYLOAD) == BASELINE_SEAL and INDEX not in PAYLOAD, "Room16 seal differs")
    manifest = read_json(root/MANIFEST)
    require(len(manifest["animations"]) == 14 and
            all(row["web_low_detail"] is True for row in manifest["animations"]) and
            manifest["counters"] == {}, "Fourteen default-low motifs/zero replays required")
    raw_bytes, custody = raw_custody(root)
    original, raw = decode_png(read(root/BACKGROUND)), decode_png(raw_bytes)
    require((original.width,original.height) == (1800,860) and (raw.width,raw.height) == (1815,867) and
            set(original.rgba[3::4]) == set(raw.rgba[3::4]) == {255}, "Exact opaque original/raw sizes required")
    require(sha(read(CONTEXT_EVIDENCE/"__none_metadata.json")) == CONTEXT_SHA, "Retained actual Base metadata differs")
    context = read_json(CONTEXT_EVIDENCE/"__none_metadata.json")
    require(context["source_paint"]["geometry_equal"] is True and len(context["actual_view"]["objects"]) == 7 and
            len(context["source_paint"]["objects"]) == 7, "Retained Base7 typed geometry required")
    observed_masks = {name:sha(read(CONTEXT_EVIDENCE/name)) for name in MASKS}
    require(observed_masks == MASKS and len(MASKS) == 14, "Retained fourteen source paint masks differ")
    custody.update({"all16_room_sources":PAYLOAD,"index_separate_sha256":INDEX_SHA,
        "retained_base_context_sha256":CONTEXT_SHA,"retained_masks":MASKS,
        "retained_mask_seal":seal(MASKS),"retained_scope":"Base only; no fresh native/clearance authority."})
    return original, raw, custody


def protected(x, y):
    return any(y0 <= y < y1 and any(left <= x < right for left,right in runs)
               for y0,y1,runs in PROTECTED)


def mask_cell(board_x, board_y):
    return 0 <= board_x < 900 and 214 <= board_y < 246 and not protected(2*board_x,2*board_y)


def raw_floor_eligible(x, y):
    return (0 <= x < 1815 and 448 <= y < 494 and
            not any(left <= x < left+width and top <= y < top+height
                    for left,top,width,height in RAW_SUPPORT_ROIS))


def donor(board_x, board_y):
    require(mask_cell(board_x,board_y), "Exact writable cell required")
    x, y = board_x*2, board_y*2
    if board_y == 245 and (x < 520 or x >= 1268):
        return "original_floor_join", x, 492
    sx = ((2*board_x+1)*1815)//1800
    if board_y < 220:
        if 580 <= sx < 1730:
            sx %= 512
        return "raw_skirting", sx, SKIRT_Y[board_y-214]
    sy = 448+((2*(board_y-220)+1)*46)//52
    if not raw_floor_eligible(sx,sy):
        alternatives = [q for left,top,width,height in RAW_SUPPORT_ROIS
                        for q in (left-4,left+width+4) if raw_floor_eligible(q,sy)]
        require(alternatives, "No eligible same-row clean-floor donor")
        sx = min(alternatives,key=lambda q:(abs(q-sx),q))
    require(raw_floor_eligible(sx,sy), "Raw support/rug donor forbidden")
    return "raw_floor", sx, sy


def pixel(image,x,y):
    return image.rgba[(y*image.width+x)*4:(y*image.width+x)*4+4]


def assemble(original, raw):
    require((original.width,original.height) == (1800,860) and (raw.width,raw.height) == (1815,867),
            "Fixed source dimensions required")
    output, ledger = bytearray(original.rgba), []
    for by in range(214,246):
        for bx in range(900):
            if not mask_cell(bx,by):
                continue
            kind,sx,sy = donor(bx,by)
            color = pixel(original if kind == "original_floor_join" else raw,sx,sy)
            require(color[3] == 255, "Donor must remain opaque")
            x,y = bx*2,by*2
            for dy in (0,1):
                at = ((y+dy)*1800+x)*4
                output[at:at+8] = color*2
            ledger.append({"target_2x2":[x,y],"source":kind,"source_pixel":[sx,sy],"RGBA":list(color)})
    return PNGImage(1800,860,bytes(output)),ledger


def verify_pixels(original, candidate, raw, ledger):
    require(len(ledger) == 25538, "Exact25538 writable clusters/102152 pixels required")
    expected = {(2*x,2*y) for y in range(214,246) for x in range(900) if mask_cell(x,y)}
    require({tuple(row["target_2x2"]) for row in ledger} == expected and
            len({tuple(row["target_2x2"]) for row in ledger}) == len(ledger), "Exact unique donor closure required")
    outside = hashlib.sha256()
    protected_count = 0
    for y in range(860):
        if y < 428 or y >= 492:
            a,b = y*7200,(y+1)*7200
            require(original.rgba[a:b] == candidate.rgba[a:b], "Outside band changed")
            outside.update(original.rgba[a:b])
        else:
            for x in range(1800):
                if protected(x,y):
                    require(pixel(original,x,y) == pixel(candidate,x,y), "Original MATERIAL silhouette changed")
                    outside.update(pixel(original,x,y))
                    protected_count += 1
    require(protected_count == 13048, "Actual source material-only trace changed")
    counts = {}
    for row in ledger:
        x,y = row["target_2x2"]
        kind,sx,sy = donor(x//2,y//2)
        color = pixel(original if kind == "original_floor_join" else raw,sx,sy)
        require((row["source"],*row["source_pixel"]) == (kind,sx,sy) and bytes(row["RGBA"]) == color and
                all(pixel(candidate,x+dx,y+dy) == color for dx in (0,1) for dy in (0,1)),
                "Exact raw/original donor NN2 ledger differs")
        counts[kind] = counts.get(kind,0)+1
    require(counts["original_floor_join"] == 526, "Narrow non-rug original floor join differs")
    return {"outside_band_and_actual_material_RGBA_sha256":outside.hexdigest(),"outside_exact_union_equal":True,
        "protected_material_pixels":protected_count,"writable_pixels":len(ledger)*4,"donor_clusters":counts,
        "all_rows492_onward_identical":True,"original_rug_not_copied_upward":True,
        "all_material_and_contact_solids_preserved":True,"all_donors_exact_NN2":True,
        "visual_seams_or_native_clearance_approved":False}


def encode_png(image):
    def chunk(kind,data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
    rows = b"".join(b"\0"+image.rgba[y*image.width*4:(y+1)*image.width*4] for y in range(image.height))
    return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",image.width,image.height,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b"")


def gate(layout, directories):
    dirs = tuple(plain(path) for path in directories)
    require(layout.prepared and layout.root == QA_ROOT and layout.workspace == WORKSPACE and
        layout.expected_write_bytes == 4*1024**3 and layout.reserve_bytes == 20*1024**3,
        "Exact prepared Apartment E layout and4+20GiB budget required")
    require(dirs and all((path.is_relative_to(WORKSPACE) or path.is_relative_to(layout.evidence)) and
        (not path.exists() or path.is_dir()) for path in dirs), "Directory parents only; no file/escape gate")
    validate_layout(layout, extra_write_paths=dirs)


def admitted_layout():
    evidence = plain(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest_path = evidence/"storage-manifest.json"
    record = read_json(manifest_path)
    require(record["schema"] == "bth-qa-storage/v1" and record["prepared"] is True, "Prepared own manifest required")
    layout = Layout(**{name:Path(value) for name,value in record["paths"].items()},
        **{name:record[name] for name in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    require(layout.evidence == evidence and evidence.name == "evidence" and evidence.parent.parent == QA_ROOT/"runs",
            "Actual E evidence binding differs")
    claim = read_json(evidence/"launch-claim.json")
    require(claim["schema"] == "bth.qa_launch_claim/v1" and claim["manifest_sha256"] == sha(read(manifest_path)),
            "Actual parent launch claim differs")
    gate(layout,(WORKSPACE,evidence))
    return layout


def ensure_parent(layout, parent):
    parent = plain(parent)
    missing, current = [], parent
    while not current.exists():
        missing.append(current)
        current = current.parent
    for directory in reversed(missing):
        gate(layout,(directory.parent,))
        directory.mkdir()


def write_new(layout, value, data):
    path = plain(value)
    require(not path.exists(), "Never overwrite an existing assembly artifact")
    ensure_parent(layout,path.parent)
    gate(layout,(path.parent,))
    with path.open("xb") as handle:
        handle.write(data)
    require(read(path) == data, "Exclusive write/readback differs")


def inventory(root, expected):
    root = plain(root)
    wanted_dirs = {p.as_posix() for n in expected for p in PurePosixPath(n).parents if str(p) != "."}
    seen, dirs, pending = {},set(),[root]
    while pending:
        directory = plain(pending.pop())
        require(directory.is_dir(), "Ordinary physical directory required before descent")
        for child in sorted(directory.iterdir()):
            child = plain(child)
            name = child.relative_to(root).as_posix()
            if child.is_dir():
                require(name in wanted_dirs, "Unknown/empty/reparse directory rejected: "+name)
                dirs.add(name)
                pending.append(child)
            else:
                require(name in expected, "Unknown output file rejected: "+name)
                seen[name] = sha(read(child))
    require(seen == expected and dirs == wanted_dirs, "Exact physical file/directory/hash closure differs")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root",type=Path,required=True)
    parser.add_argument("--workspace",type=Path,required=True)
    args = parser.parse_args(argv)
    try:
        root, workspace = plain(args.source_root),plain(args.workspace)
        require(root == SOURCE_ROOT and workspace == WORKSPACE, "Only exact D source/E workspace admitted")
        layout = admitted_layout()
        original,raw,custody = inputs(root)
        baseline,parent = workspace/"source_baseline",workspace/"candidate_sources"
        output = parent/PACKAGE_NAME
        proof = layout.evidence/"apartment-spatial-r1-assembly.json"
        pixels = layout.evidence/"apartment-spatial-r1-pixel-provenance.json"
        require({p.name for p in workspace.iterdir()} == {"raw_source"} and
                {p.name for p in (workspace/"raw_source").iterdir()} == {"apartment-spatial-r1.png"} and
                not baseline.exists() and not parent.exists() and not proof.exists() and not pixels.exists(),
                "Fresh exact workspace/candidate/evidence closure required")
        candidate,ledger = assemble(original,raw)
        verification = verify_pixels(original,candidate,raw,ledger)
        encoded = encode_png(candidate)
        require(decode_png(encoded) == candidate, "Candidate encoding not lossless")
        # Reauthenticate every source before the first assembly directory/write.
        _,_,prewrite = inputs(root)
        require(prewrite == custody, "Input custody changed before first assembly write")
        for name,expected in PAYLOAD.items():
            data = read(root/name)
            require(sha(data) == expected, "Source changed immediately before copy")
            write_new(layout,baseline/name,data)
            write_new(layout,output/name,encoded if name == BACKGROUND else data)
        write_new(layout,baseline/".gdignore",IGNORE)
        write_new(layout,parent/".gdignore",IGNORE)
        files = {name:sha(read(output/name)) for name in PAYLOAD}
        require({name for name in files if files[name] != PAYLOAD[name]} == {BACKGROUND}, "Only BG may change")
        inventory(baseline,{**PAYLOAD,".gdignore":sha(IGNORE)})
        inventory(parent,{**{PACKAGE_NAME+"/"+name:value for name,value in files.items()},".gdignore":sha(IGNORE)})
        _,_,after = inputs(root)
        require(after == custody, "Original source/raw/control/retained masks changed")
        write_new(layout,pixels,(json.dumps({"schema":"bth.apartment_spatial_pixel_provenance/v1",
            "clusters":ledger,"native_pixels":len(ledger)*4,"no_interpolation_or_color_edits":True},
            separators=(",",":"))+"\n").encode())
        report = {"schema":"bth.apartment_spatial_assembly/v1","task_id":"BTH-ENV-SPATIAL-APARTMENT-001",
            "status":"NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT","recipe_sha256":sha(read(__file__)),
            "assembly_plan_sha256":PLAN_SHA,"source_provenance_sha256":PROVENANCE_SHA,
            "raw_sha256":RAW_SHA,"source_custody":custody,"baseline":{"path":str(baseline),"files":PAYLOAD,
                "logical_file_count":16,"seal":BASELINE_SEAL,"auxiliary":{".gdignore":sha(IGNORE)}},
            "candidate":{"path":str(output),"files":files,"logical_file_count":16,"seal":seal(files)},
            "candidate_parent_auxiliary":{".gdignore":sha(IGNORE)},"global_index_separate_sha256":INDEX_SHA,
            "pixel_proof":verification,"pixel_provenance":{"path":str(pixels),"sha256":sha(read(pixels))},
            "all14_motion_PNGs_full_JSON_index_anchors_and_zero_replays_unchanged":True,
            "kitchen_strip_material_disposition":"OPEN; floor-only does not close room",
            "native_trial_approved":False,"production_activation_approved":False,"TEST_updated":False,
            "visual_and_scope_limits":["Actual boundary/contact/grain/seam review pending",
                "Retained Base only; fresh populated/native/RM/no-pointer/actual-clock review pending",
                "No transactions/save/revisit/browser/full-cycle claim"],"outer_closed_capped_Job_required":True}
        write_new(layout,proof,(json.dumps(report,indent=2)+"\n").encode())
        gate(layout,(baseline,parent,output,layout.evidence))
        print(json.dumps({"status":report["status"],"proof":str(proof),"proof_sha256":sha(read(proof)),
                          "candidate":str(output),"package_sha256":seal(files),"native_trial_approved":False}))
        return 0
    except (OSError,ValueError,KeyError,TypeError,StorageGuardError) as error:
        print(json.dumps({"status":"STOPPED","error":str(error),"fallback":False,
                          "cleanup_retry_or_overwrite":False,"production_art_written":False}),file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
