"""In-memory byte/contract regressions. Synthetic fixtures are not art approval.

Source author does not import or run these tests. Parent guarded execution only;
no test creates directories, outputs, profiles, network requests or children.
"""
import sys
sys.dont_write_bytecode = True
import ast
import base64
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import struct
import unittest
from unittest.mock import patch
import zlib

import materialize_environment_spatial_raw as worker


def fixture():
    # Tiny valid RGBA PNG, only an in-memory parser fixture, never a room source.
    parts=[(b"IHDR",struct.pack(">IIBBBBB",1,1,8,6,0,0,0)),(b"caBX",b"synthetic provenance"),
        (b"iTXt",b"fixture\x00\x00\x00\x00\x00in-memory only"),(b"IDAT",zlib.compress(b"\x00\x00\x00\x00\xff")),(b"IEND",b"")]
    data=b"\x89PNG\r\n\x1a\n"+b"".join(struct.pack(">I",len(v))+k+v+struct.pack(">I",zlib.crc32(k+v)&0xffffffff) for k,v in parts)
    pin={"sha256":worker.sha(data),"bytes":len(data),"width":1,"height":1,"bit_depth":8,"color_type":6,
        "compression":0,"filter":0,"interlace":0,"chunks":[{"kind":k.decode(),"bytes":len(v),"payload_sha256":worker.sha(v)} for k,v in parts]}
    encoded=base64.b64encode(data)+b"\n"
    directory=worker.ARTIFACTS/"materializer-test-fixture"
    ref=lambda name,n:{"path":str(directory/name),"bytes":n,"sha256":"a"*64}
    room="grand_casino_back_room"
    value={"schema":worker.DESCRIPTOR_SCHEMA,"room":room,"base64":{**ref("raw.png.b64",len(encoded)),
        "sha256":worker.sha(encoded),"data_url_sha256":worker.sha(b"data:image/png;base64,"+encoded[:-1]),
        "encoding":"ASCII_BASE64_ONE_LINE_LF"},"png":pin,"prompt":ref("prompt.txt",5),"provenance":ref("provenance.json",10),
        "original_controls":{"assets/art/environments/"+room+"/background.png":"a"*64,
            "data/art/environments/"+room+".json":"b"*64,"data/art/environments/index.json":"c"*64},
        "output":{"workspace":str(worker.QA/"workspaces/BTH-MATERIALIZER-TEST-FIXTURE"),
            "png":"raw_source/fixture.png","receipt":"raw_source/receipt.json"}}
    # Every mutated test starts from the same fully qualified intact fixture.
    worker.png_structure(data,pin)
    actual,_=worker.decode_bytes(encoded,value)
    assert actual==data
    workspace=Path(value["output"]["workspace"])
    worker.descriptor_contract(value,directory/"descriptor.json",workspace,workspace/"raw_source")
    return data,encoded,value,directory/"descriptor.json"


class ByteMaterializerChecks(unittest.TestCase):
    def contract(self,value,path):
        workspace=worker.QA/"workspaces/BTH-MATERIALIZER-TEST-FIXTURE"
        return worker.descriptor_contract(value,path,workspace,workspace/"raw_source")

    def test_fixture_bytes_and_all_chunks_are_retained(self):
        data,encoded,value,_=fixture()
        actual,proof=worker.decode_bytes(encoded,value)
        self.assertEqual(actual,data)
        self.assertEqual([r["kind"] for r in proof["chunks"]],["IHDR","caBX","iTXt","IDAT","IEND"])
        self.assertTrue(proof["all_original_chunks_preserved"])
        self.assertFalse(proof["pixel_decoding_or_transform_performed"])

    def test_complete_payload_sha_and_size_are_required(self):
        data,_,value,_=fixture()
        for field,new in (("sha256","0"*64),("bytes",len(data)-1)):
            pin=deepcopy(value["png"]);pin[field]=new
            with self.subTest(field=field),self.assertRaises(ValueError):
                worker.png_structure(data,pin)

    def test_CRC_is_checked_independently_of_the_file_and_payload_hashes(self):
        data,_,value,_=fixture();changed=bytearray(data)
        changed[41]^=1  # caBX payload byte; keep its stored CRC deliberately stale.
        changed=bytes(changed);pin=deepcopy(value["png"]);pin["sha256"]=worker.sha(changed)
        pin["chunks"][1]["payload_sha256"]=worker.sha(changed[41:41+pin["chunks"][1]["bytes"]])
        with self.assertRaises(ValueError):
            worker.png_structure(changed,pin)

    def test_caBX_payload_identity_is_mandatory(self):
        data,_,value,_=fixture();pin=deepcopy(value["png"]);pin["chunks"][1]["payload_sha256"]="0"*64
        with self.assertRaises(ValueError):
            worker.png_structure(data,pin)

    def test_unknown_ancillary_chunks_cannot_be_silently_dropped(self):
        data,_,value,_=fixture();pin=deepcopy(value["png"]);del pin["chunks"][2]
        with self.assertRaises(ValueError):
            worker.png_structure(data,pin)

    def test_trailing_bytes_rejected_even_if_whole_hash_is_updated(self):
        data,_,value,_=fixture();pin=deepcopy(value["png"]);data+=b"x";pin.update(bytes=len(data),sha256=worker.sha(data))
        with self.assertRaises(ValueError):
            worker.png_structure(data,pin)

    def test_exact_IHDR_dimensions_are_checked(self):
        data,_,value,_=fixture();pin=deepcopy(value["png"]);pin["width"]=2
        with self.assertRaises(ValueError):
            worker.png_structure(data,pin)

    def test_B64_format_is_exact_and_has_no_whitespace_fallback(self):
        _,encoded,value,_=fixture()
        for changed in (encoded[:-1],encoded.replace(b"\n",b"\r\n"),b" "+encoded,encoded+b"\n"):
            pin=deepcopy(value);pin["base64"].update(bytes=len(changed),sha256=worker.sha(changed))
            with self.subTest(value=changed[-3:]),self.assertRaises(ValueError):
                worker.decode_bytes(changed,pin)

    def test_original_returned_data_URL_is_independently_bound(self):
        _,encoded,value,_=fixture();value["base64"]["data_url_sha256"]="0"*64
        with self.assertRaises(ValueError):
            worker.decode_bytes(encoded,value)

    def test_valid_descriptor_is_only_a_shape_contract(self):
        _,_,value,path=fixture();output,receipt=self.contract(value,path)
        self.assertEqual(output.parent,receipt.parent)
        self.assertEqual(output.name,"fixture.png")
        self.assertNotIn("approval",value)

    def test_foreign_input_and_control_paths_are_rejected(self):
        for mutate in ("B64","prompt","control","backslash_control","stream_control"):
            _,_,value,path=fixture()
            if mutate=="B64":value["base64"]["path"]=str(worker.SOURCE/"unrelated.b64")
            elif mutate=="prompt":value["prompt"]["path"]=str(worker.SOURCE/"unrelated.txt")
            elif mutate=="control":value["original_controls"]["assets/art/environments/bar/background.png"]="d"*64
            elif mutate=="backslash_control":value["original_controls"]["assets/art/environments/grand_casino_back_room/..\\bar\\background.png"]="d"*64
            else:value["original_controls"]["assets/art/environments/grand_casino_back_room/background.png:stream.png"]="d"*64
            with self.subTest(mutate=mutate),self.assertRaises(ValueError):
                self.contract(value,path)

    def test_missing_original_BG_JSON_index_is_rejected(self):
        _,_,original,path=fixture()
        for key in original["original_controls"]:
            value=deepcopy(original);del value["original_controls"][key]
            with self.subTest(key=key),self.assertRaises(ValueError):
                self.contract(value,path)

    def test_output_cannot_leave_the_exact_raw_directory(self):
        for leaf in ("../other.png","raw_source/../other.png","raw_source/sub/other.png","raw_source/x.json"):
            _,_,value,path=fixture();value["output"]["png"]=leaf
            with self.subTest(leaf=leaf),self.assertRaises(ValueError):
                self.contract(value,path)

    def test_foreign_or_C_workspace_is_rejected(self):
        _,_,value,path=fixture()
        with self.assertRaises(ValueError):
            worker.descriptor_contract(value,path,Path("C:/scratch"),Path("C:/scratch/raw_source"))

    def test_invalid_header_mode_is_rejected_before_writes(self):
        _,_,value,path=fixture();value["png"]["color_type"]=99
        with self.assertRaises(ValueError):
            self.contract(value,path)

    def test_duplicate_keys_and_nonfinite_JSON_are_not_normalized(self):
        self.assertEqual(worker.json_value(b'{"x":1,"nested":[true,null,0.5]}'),
            {"x":1,"nested":[True,None,0.5]})
        for raw in (b'{"x":1,"x":2}',b'{"x":NaN}',b'{"x":Infinity}'):
            with self.subTest(raw=raw),self.assertRaises(ValueError):
                worker.json_value(raw)

    def test_overflow_numbers_rejected_after_valid_JSON_control(self):
        self.assertEqual(worker.json_value(b'{"x":1e308}'),{"x":1e308})
        for raw in (b'{"x":1e999}',b'{"nested":[-1e999]}'):
            with self.subTest(raw=raw),self.assertRaises(ValueError):
                worker.json_value(raw)

    def test_write_gate_accepts_parents_not_an_existing_PNG(self):
        root=worker.SOURCE/"tools"
        with patch.object(worker.storage,"validate_layout") as gate:
            worker.write_gate(object(),root)
            gate.assert_called_once()
            self.assertEqual(gate.call_args.kwargs["extra_write_paths"],(root,))
        with patch.object(worker.storage,"validate_layout") as gate,self.assertRaises(ValueError):
            worker.write_gate(object(),worker.SOURCE/"tools/materialize_environment_spatial_raw.py")
        gate.assert_not_called()

    def test_existing_matching_bytes_are_observed_read_only(self):
        path=worker.SOURCE/"tools/materialize_environment_spatial_raw.py"
        before=worker.read_file(path,1024**2)
        result=worker.existing_output_state(path,worker.sha(before))
        self.assertTrue(result["present"] and result["exact_pinned_bytes"])
        self.assertEqual(result["inspection_access"],"READ_ONLY_STOP_NO_RETRY")
        self.assertEqual(worker.read_file(path,1024**2),before)

    def test_no_child_network_cleanup_retry_or_nonexclusive_output_calls(self):
        tree=ast.parse(Path(worker.__file__).read_text())
        calls=[n for n in ast.walk(tree) if isinstance(n,ast.Call)]
        names={n.func.id if isinstance(n.func,ast.Name) else n.func.attr for n in calls if isinstance(n.func,(ast.Name,ast.Attribute))}
        self.assertFalse(names&{"Popen","execute","prepare_layout","unlink","remove","rmdir","rename","replace","urlopen"})
        opens=[n for n in calls if isinstance(n.func,ast.Attribute) and n.func.attr=="open"]
        self.assertEqual({n.args[0].value for n in opens},{"xb","x"})


if __name__=="__main__":
    unittest.main()
