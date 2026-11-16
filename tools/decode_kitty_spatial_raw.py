"""Rehydrate one pinned imagegen PNG under the parent's prepared capped E Job.

Byte decoding only: no pixel edits, transforms, subprocesses, network, cleanup,
moves or art activation. Root must authenticate the closed outer Job separately.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import zlib

from bth_qa_storage import Layout, validate_layout
import bth_qa_storage as storage

SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
QA_ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = QA_ROOT/"workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116"
INPUT_RELATIVE = "review_artifacts/environment_art_sources/kitty-spatial-r1/kitty-spatial-r1.png.b64"
INPUT_SHA = "0039b3d7d43eb1079b94bfcd493834a967f115b63879f16502ab9b89f71f1f4f"
INPUT_BYTES = 2470317
PNG_SHA = "aa1078eab763def23c3d8a1b7232413384b5fcc26a86d7008866dcbf857526eb"
PNG_BYTES = 1852735
STORAGE_SHA = "cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def plain(path):
    path=Path(path)
    require(path.is_absolute() and ".." not in path.parts,"Explicit absolute path without traversal required")
    for item in (path,*path.parents):
        if item.exists():
            mode=item.lstat()
            require(not item.is_symlink() and not getattr(mode,"st_file_attributes",0)&stat.FILE_ATTRIBUTE_REPARSE_POINT,
                    "Linked/reparse path rejected: "+str(item))
    return path


def png_structure(data):
    require(len(data)==PNG_BYTES and sha(data)==PNG_SHA and data[:8]==b"\x89PNG\r\n\x1a\n",
            "Exact generated PNG length/hash/signature differs")
    offset=8; chunks=[]; saw_end=False
    while offset<len(data):
        require(offset+12<=len(data),"Truncated PNG chunk")
        size=struct.unpack(">I",data[offset:offset+4])[0]
        kind=data[offset+4:offset+8]
        require(size<=len(data)-offset-12,"PNG chunk bounds differ")
        payload=data[offset+8:offset+8+size]
        crc=struct.unpack(">I",data[offset+8+size:offset+12+size])[0]
        require(zlib.crc32(kind+payload)&0xffffffff==crc,"PNG chunk CRC differs")
        chunks.append(kind)
        if kind==b"IHDR":
            require(len(chunks)==1 and size==13 and
                    struct.unpack(">IIBBBBB",payload)==(1815,867,8,2,0,0,0),"Exact RGB1815x867 IHDR differs")
        if kind==b"IEND":
            require(size==0 and offset+12==len(data),"PNG terminal IEND differs")
            saw_end=True
        offset+=size+12
    require(saw_end and chunks.count(b"IHDR")==1 and chunks.count(b"IEND")==1 and b"IDAT" in chunks,
            "Complete single PNG chunk structure required")
    return {"width":1815,"height":867,"bit_depth":8,"color_type":2,"opaque_RGB":True,
            "all_chunk_CRCs_verified":True,"chunk_count":len(chunks)}


def decode_bytes(encoded):
    require(len(encoded)==INPUT_BYTES and sha(encoded)==INPUT_SHA and encoded.endswith(b"\n") and
            encoded.count(b"\n")==1 and b"\r" not in encoded,"Exact one-line ASCII base64 artifact required")
    data=base64.b64decode(encoded[:-1],validate=True)
    return data,png_structure(data)


def admitted_layout(workspace,output):
    evidence=plain(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest=plain(evidence/"storage-manifest.json")
    require(sha(plain(storage.__file__).read_bytes())==STORAGE_SHA,"Maintained storage helper differs")
    record=json.loads(manifest.read_bytes())
    require(record.get("schema")=="bth-qa-storage/v1" and record.get("prepared") is True,
            "Parent-prepared ordinary storage manifest required")
    layout=Layout(**{key:Path(value) for key,value in record["paths"].items()},
        **{key:record[key] for key in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    require(layout.root==QA_ROOT and layout.workspace==workspace==WORKSPACE and layout.evidence==evidence and
            layout.manifest_path==manifest and layout.expected_write_bytes==4*1024**3 and
            layout.reserve_bytes==20*1024**3,"Exact Kitty E workspace and4+20GiB admission required")
    validate_layout(layout,extra_write_paths=(output.parent,output))
    return layout,manifest


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root",type=Path,required=True)
    parser.add_argument("--workspace",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        root,workspace,output=map(plain,(args.source_root,args.workspace,args.output))
        require(root==SOURCE_ROOT and workspace==WORKSPACE and output==workspace/"raw_source/kitty-spatial-r1.png",
                "Only exact source and fresh declared Kitty raw output allowed")
        layout,manifest=admitted_layout(workspace,output)
        path=plain(root/INPUT_RELATIVE)
        before=path.read_bytes()
        data,structure=decode_bytes(before)
        receipt=layout.evidence/"kitty-spatial-r1-decode.json"
        require(not output.parent.exists() and not output.exists() and not receipt.exists(),
                "Fresh absent raw directory/PNG/receipt required; never overwrite or clean up")
        validate_layout(layout,extra_write_paths=(output.parent,output))
        output.parent.mkdir()
        validate_layout(layout,extra_write_paths=(output.parent,output))
        with output.open("xb") as handle:
            handle.write(data)
        require(output.read_bytes()==data and path.read_bytes()==before,"Output or retained base64 changed")
        result={"schema":"bth.kitty_spatial_raw_decode/v1","status":"EXACT_GENERATED_RAW_PNG_MATERIALIZED",
            "input":str(path),"input_sha256":INPUT_SHA,"input_bytes":INPUT_BYTES,
            "output":str(output),"output_sha256":PNG_SHA,"output_bytes":PNG_BYTES,"PNG":structure,
            "storage_manifest":str(manifest),"storage_manifest_sha256":sha(manifest.read_bytes()),
            "source_base64_retained_unchanged":True,"only_byte_decoding":True,
            "pixel_editing_or_transforms":False,"network_or_children":False,"production_art_written":False,
            "outer_closed_capped_Job_receipt_required":True,"candidate_or_art_approval":False}
        validate_layout(layout,extra_write_paths=(output.parent,output))
        with receipt.open("x",encoding="utf-8",newline="\n") as handle:
            json.dump(result,handle,indent=2);handle.write("\n")
        print(json.dumps(result))
        return 0
    except (OSError,ValueError,KeyError,TypeError) as error:
        print(json.dumps({"status":"STOPPED","error":str(error),"fallback_attempted":False}),file=sys.stderr)
        return 1


if __name__=="__main__":
    raise SystemExit(main())
