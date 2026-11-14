"""Prepare a new art TEST HTML bound to reviewed isolated save code.

Use a fresh owned Web export. Never write to NEXT or an existing publication.
The caller still verifies source commit, PCK, engine/native pins and served bytes.
"""
import hashlib,json,re,sys
from pathlib import Path
REVIEWED_CORE_SHA256 = "c4baa91d7a72d803040ee3b043f205d73271c115202b66efed23262066393b61"
TEST_ARGS = ["--", "--bth-art-test"]
TEST_PERSISTENT_PATHS = ["/userfs/godot/app_userdata/Beat the House/distribution/web_0_6_1_art_test"]
def prepare_test_html(html,core_source):
    canonical=core_source.replace("\r\n","\n").encode("utf-8")
    if hashlib.sha256(canonical).hexdigest()!=REVIEWED_CORE_SHA256:
        raise ValueError("TEST save-isolation core source not reviewed; refusing launcher")
    matches=list(re.finditer(r"\bconst\s+GODOT_CONFIG\s*=\s*",html))
    if len(matches)!=1:
        raise ValueError("Expected one literal Godot config")
    start=matches[0].end()
    config,length=json.JSONDecoder().raw_decode(html[start:])
    if not isinstance(config,dict) or not isinstance(config.get("args"),list):
        raise ValueError("Godot config args missing")
    existing_paths=config.get("persistentPaths")
    if existing_paths not in (None,["/userfs"],TEST_PERSISTENT_PATHS):
        raise ValueError("Unexpected persistent mount; refusing override")
    if config["args"]==TEST_ARGS and existing_paths==TEST_PERSISTENT_PATHS:
        return html
    if config["args"] not in ([],TEST_ARGS):
        raise ValueError("Unexpected existing launch arguments; refusing override")
    config["args"]=list(TEST_ARGS)
    # IDBFS names its database after the mountpoint. Mount only TEST storage,
    # never /userfs, so parallel TEST/NEXT syncs cannot read/remove each other.
    config["persistentPaths"]=list(TEST_PERSISTENT_PATHS)
    return html[:start]+json.dumps(config,separators=(",",":"),ensure_ascii=False)+html[start+length:]
def main(argv=None):
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-html",type=Path,required=True)
    parser.add_argument("--output-html",type=Path,required=True)
    parser.add_argument("--core-source",type=Path,default=Path(__file__).resolve().parents[1]/"scripts/core/persistence_paths.gd")
    args=parser.parse_args(argv)
    if args.input_html.resolve()==args.output_html.resolve() or args.output_html.exists():
        raise ValueError("Output must be a new staged HTML, never the input or an existing file")
    original=args.input_html.read_bytes()
    core=args.core_source.read_text(encoding="utf-8-sig")
    result=prepare_test_html(original.decode("utf-8"),core).encode("utf-8")
    with args.output_html.open("xb") as handle:
        handle.write(result)
    print(json.dumps({"schema":"bth.art_test_launcher/v1","input_sha256":hashlib.sha256(original).hexdigest(),"output_sha256":hashlib.sha256(result).hexdigest(),"core_sha256":REVIEWED_CORE_SHA256,"args":TEST_ARGS,"persistent_paths":TEST_PERSISTENT_PATHS}))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
