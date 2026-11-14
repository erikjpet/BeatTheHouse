import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location("art_test_web",ROOT/"tools/prepare_environment_art_test_web.py")
TOOL=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)
class ArtTestLauncherTests(unittest.TestCase):
    def setUp(self):
        self.core=(ROOT/"scripts/core/persistence_paths.gd").read_text(encoding="utf-8-sig")
        self.html='const GODOT_CONFIG = {"args":[],"executable":"index","fileSizes":{"index.pck":123}};\nconst engine = new Engine(GODOT_CONFIG);'
    def config(self,text):
        return json.JSONDecoder().raw_decode(text.split("=",1)[1].lstrip())[0]
    def test_args_and_separate_database(self):
        cfg=self.config(TOOL.prepare_test_html(self.html,self.core))
        self.assertEqual(cfg["args"],["--","--bth-art-test"])
        self.assertEqual(cfg["persistentPaths"],TOOL.TEST_PERSISTENT_PATHS)
        self.assertNotIn("/userfs",cfg["persistentPaths"])
    def test_other_fields_and_bootstrap_preserved(self):
        result=TOOL.prepare_test_html(self.html,self.core)
        self.assertEqual(self.config(result)["fileSizes"],{"index.pck":123})
        self.assertEqual(result.split(";",1)[1],self.html.split(";",1)[1])
    def test_idempotence(self):
        result=TOOL.prepare_test_html(self.html,self.core)
        self.assertEqual(TOOL.prepare_test_html(result,self.core),result)
    def test_windows_line_endings(self):
        self.assertEqual(TOOL.prepare_test_html(self.html,self.core),TOOL.prepare_test_html(self.html,self.core.replace("\n","\r\n")))
    def test_default_mount_replaced(self):
        original=self.html.replace('"args":[]','"args":[],"persistentPaths":["/userfs"]')
        self.assertEqual(self.config(TOOL.prepare_test_html(original,self.core)),self.config(TOOL.prepare_test_html(self.html,self.core)))
    def test_unreviewed_core_rejected(self):
        with self.assertRaises(ValueError):TOOL.prepare_test_html(self.html,self.core+'# altered')
    def test_foreign_arguments_rejected(self):
        with self.assertRaises(ValueError):TOOL.prepare_test_html(self.html.replace('"args":[]','"args":["--other"]'),self.core)
    def test_foreign_mount_rejected(self):
        with self.assertRaises(ValueError):TOOL.prepare_test_html(self.html.replace('"args":[]','"args":[],"persistentPaths":["/foreign"]'),self.core)
    def test_invalid_config_rejected(self):
        for html in (self.html.replace('"args":[],',''),self.html+self.html,'const GODOT_CONFIG = nope;'):
            with self.subTest(html=html),self.assertRaises(ValueError):TOOL.prepare_test_html(html,self.core)
    def test_cli_preserves_input_and_refuses_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);original=root/'original.html';output=root/'test.html';original.write_text(self.html)
            TOOL.main(['--input-html',str(original),'--output-html',str(output)])
            self.assertEqual(original.read_text(),self.html)
            self.assertEqual(self.config(output.read_text())["args"],TOOL.TEST_ARGS)
            with self.assertRaises(ValueError):TOOL.main(['--input-html',str(original),'--output-html',str(output)])
            with self.assertRaises(ValueError):TOOL.main(['--input-html',str(original),'--output-html',str(original)])
if __name__=='__main__':unittest.main()
