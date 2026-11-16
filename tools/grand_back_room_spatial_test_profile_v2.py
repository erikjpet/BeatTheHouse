"""Grand Back Room V2 pure TEST package contracts; no release entrypoint.

No file/child/network/profile writes or baseline loader. A caller-supplied
manifest/PCK is never authenticated as a delivered baseline by these functions.
Actual delivered HL custody and a separate final build approval are future gates.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import json
import re

# Frozen stateless primitives only; no environment/global replacement.
from high_limit_spatial_test_profile import require, sha, full_hash, same_typed, json_value

SCHEMA = "bth.grand_back_room_spatial_test_policy/v2"
ENVIRONMENT = "grand_casino_back_room"
TASK_ID = "BTH-ENV-SPATIAL-GBR-001"
ART = "assets/art/environments/" + ENVIRONMENT + "/"
GBR_JSON = "data/art/environments/" + ENVIRONMENT + ".json"
INDEX_JSON = "data/art/environments/index.json"
BASE_GBR_JSON_SHA = "bb6d6c293824bf9e6347dfba6db5df0e874469fc11e0d094b8f1bd108f45a067"
GBR_JSON_SHA = "cc8553a5856289c7fe6b42754db43b4bd02d07e5c793ca1fea54e7655eca103d"
BASE_ACTIVATION_SHA = "c94d12614f9b6c2b86311999acc6ae9ec0711c71e1cdeb596a2e7937c7593117"
BASE_PACKAGE_SHA = "065a5f98dfabb2b435bc31af76a0273921a370d1ebb9d9887ce6283c3231fbbb"
PACKAGE_SHA = "e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7"
NATIVE_ART_REVIEW_SHA = "dda141cafab20e7f12db27e83011aa8896cf31f3e3099890ea3463302c7163a9"
NATIVE_ADAPTER_SHA = "a516fcdb782c0764e39d1ef9e59d5f87520a8ad146ad7f21c3f2d908973c443b"
NATIVE_POLICY_SHA = "c34375889ac8e35f8852c724cbe0e801d5c181920c9fae7583883583a21cb594"
SELECTED_SOURCE_SHA = "051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625"
STATELESS_POLICY_SHA = "f001191f6a1d3f0cb7a4b05bf93d8c16898eabdc5248c8d911a983500a839e18"
UID_SHA = "587514374b37d67f6c0e795cc82d840f1d4a5f9f0b0c2f3c80586ce4eb38b4db"
UID_MAP_SHA = "293bcadacffd15543a5686b5e40cc6cd409495e80628d77bc0e5e62c2eb61b55"
CLASS_SHA = "43ed255c77d8ef9809383d0fef148e952dabddbbf434c69b0276790b6da5816d"
PROTECTED_SEALS = {
    "bar": "e001ad4d76344f0bb2e0542a21fa3f4936656c8c2a63ace475a6294cb9ca723e",
    "grand_casino": "563ef08fec04e980c9cb2e215b2801f3612a22dd8f8250ba6247293c12f069d4",
    "grand_casino_high_limit": "481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4",
}
ANIMATION_IDS = tuple(["casino_light_" + str(i) for i in range(5)] + ["casino_sign_pulse"] +
                      ["casino_sparkle_" + str(i) for i in range(3)] + ["floor_glint_" + str(i) for i in range(7)])
LOW_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse", "floor_glint_0", "floor_glint_1", "floor_glint_2")

BASE_PAYLOAD_SHAS = {'assets/art/environments/grand_casino_back_room/anim/casino_light_0.png': '79e4cdf8e410e9c77ba6e9ce60ad83430581618663cc8ced905bf468131d1402',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_1.png': '79e4cdf8e410e9c77ba6e9ce60ad83430581618663cc8ced905bf468131d1402',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_2.png': '79e4cdf8e410e9c77ba6e9ce60ad83430581618663cc8ced905bf468131d1402',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_3.png': '79e4cdf8e410e9c77ba6e9ce60ad83430581618663cc8ced905bf468131d1402',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_4.png': '79e4cdf8e410e9c77ba6e9ce60ad83430581618663cc8ced905bf468131d1402',
 'assets/art/environments/grand_casino_back_room/anim/casino_sign_pulse.png': 'f19e6db5291b7c49e0131892968232f46aa8a712402e86c81eafee44ca7abd36',
 'assets/art/environments/grand_casino_back_room/anim/casino_sparkle_0.png': '708f74e612c96714f96e9db45ad935643627687a49987ced947f9cd919f046dc',
 'assets/art/environments/grand_casino_back_room/anim/casino_sparkle_1.png': '708f74e612c96714f96e9db45ad935643627687a49987ced947f9cd919f046dc',
 'assets/art/environments/grand_casino_back_room/anim/casino_sparkle_2.png': '708f74e612c96714f96e9db45ad935643627687a49987ced947f9cd919f046dc',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_0.png': 'bb4f5c707031c24c8f05cca373ab66cb3fb8ea2a729a2dafd6112be0576bc490',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_1.png': '8c3943c4d07602da082a29d49d5d092f1d26dd1726cdf1789cabef2073b1c21a',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_2.png': '411d358e941a5867df0c7edc1f58fe72c1c81633c1bc7f1b2c4ed8453156775b',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_3.png': '18868f32b541dc3a10c44c3dc109054745b7f1e07953883700b4d27ad0ebfa3d',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_4.png': '36cb42a27c9b0588e0130993d78403243e1c11255fce38a0a16097dd4d1d7147',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_5.png': '3658013941c5c6b6a3ca7484d9018e893a681aa97eaef8e2f212451a6362ed27',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_6.png': 'd8f87fdc51b4401fef0d151975fb2963bbd43919625a8e6aec9234087627bb57',
 'assets/art/environments/grand_casino_back_room/background.png': 'f9d2ca14641e3ac7dd67c92af9453ce4993f0a7dec22156b4f96d6f046f8fcdf',
 'assets/art/environments/grand_casino_back_room/counters/grand_table_left.png': 'e8aed6c50f04bd4475f2c1a33a03fccbcd10ee4ebe984345be59f6afa082cd5f',
 'assets/art/environments/grand_casino_back_room/counters/grand_table_right.png': '9f9c2c24e735c177d16ebdfacb2d91f7a0fb39aa508d7a5f9791fefc97c38489',
 'data/art/environments/grand_casino_back_room.json': 'bb6d6c293824bf9e6347dfba6db5df0e874469fc11e0d094b8f1bd108f45a067',
 'data/art/environments/index.json': '11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24'}
PAYLOAD_SHAS = {'assets/art/environments/grand_casino_back_room/anim/casino_light_0.png': '988e0207c99758ba1f5d7f30d4bfa9b7439beb9faf15b3c9ff9a76c55ba27340',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_1.png': 'f9e2470a1a73e3ab62b6f3c2f23102ef4184003d7b7b98bf4691d39583221515',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_2.png': '0fac3ccc158a14a64b034e55acbb242436e145bf47bc822b8b7ba41aca239595',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_3.png': '74b88031a6733ffcacbf97bbd910e9e30ba139ac37132f72fd00e62963b40bf1',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_4.png': '7964ba8bd36745aeb5b44feeee7cff613d813e1b4a4fd5aebc91deb877663ba9',
 'assets/art/environments/grand_casino_back_room/anim/casino_sign_pulse.png': 'dceb1dc0df381fa98592cb9c58822e1863512f7a44f64b5c5bdd88faea8d51ed',
 'assets/art/environments/grand_casino_back_room/anim/casino_sparkle_0.png': '708f74e612c96714f96e9db45ad935643627687a49987ced947f9cd919f046dc',
 'assets/art/environments/grand_casino_back_room/anim/casino_sparkle_1.png': '708f74e612c96714f96e9db45ad935643627687a49987ced947f9cd919f046dc',
 'assets/art/environments/grand_casino_back_room/anim/casino_sparkle_2.png': '708f74e612c96714f96e9db45ad935643627687a49987ced947f9cd919f046dc',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_0.png': 'bb4f5c707031c24c8f05cca373ab66cb3fb8ea2a729a2dafd6112be0576bc490',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_1.png': '8c3943c4d07602da082a29d49d5d092f1d26dd1726cdf1789cabef2073b1c21a',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_2.png': '411d358e941a5867df0c7edc1f58fe72c1c81633c1bc7f1b2c4ed8453156775b',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_3.png': '18868f32b541dc3a10c44c3dc109054745b7f1e07953883700b4d27ad0ebfa3d',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_4.png': '36cb42a27c9b0588e0130993d78403243e1c11255fce38a0a16097dd4d1d7147',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_5.png': '3658013941c5c6b6a3ca7484d9018e893a681aa97eaef8e2f212451a6362ed27',
 'assets/art/environments/grand_casino_back_room/anim/floor_glint_6.png': 'd8f87fdc51b4401fef0d151975fb2963bbd43919625a8e6aec9234087627bb57',
 'assets/art/environments/grand_casino_back_room/background.png': '46492785829f659c5869d91a6510d424ea4977e6921b1ece7de1225aa804e6ca',
 'assets/art/environments/grand_casino_back_room/counters/grand_table_left.png': '9a96841d98e0f5ee53d15563c94881f3ce34ab4569182f7009f6b0609c4dafac',
 'assets/art/environments/grand_casino_back_room/counters/grand_table_right.png': 'de3a5e82cce15772a929306eb423aaf44b96ff3302cf8c73aec1eb12b7dc0964',
 'data/art/environments/grand_casino_back_room.json': 'cc8553a5856289c7fe6b42754db43b4bd02d07e5c793ca1fea54e7655eca103d',
 'data/art/environments/index.json': '11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24'}
PNG_SHAS = {'assets/art/environments/grand_casino_back_room/anim/casino_light_0.png': '988e0207c99758ba1f5d7f30d4bfa9b7439beb9faf15b3c9ff9a76c55ba27340',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_1.png': 'f9e2470a1a73e3ab62b6f3c2f23102ef4184003d7b7b98bf4691d39583221515',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_2.png': '0fac3ccc158a14a64b034e55acbb242436e145bf47bc822b8b7ba41aca239595',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_3.png': '74b88031a6733ffcacbf97bbd910e9e30ba139ac37132f72fd00e62963b40bf1',
 'assets/art/environments/grand_casino_back_room/anim/casino_light_4.png': '7964ba8bd36745aeb5b44feeee7cff613d813e1b4a4fd5aebc91deb877663ba9',
 'assets/art/environments/grand_casino_back_room/anim/casino_sign_pulse.png': 'dceb1dc0df381fa98592cb9c58822e1863512f7a44f64b5c5bdd88faea8d51ed',
 'assets/art/environments/grand_casino_back_room/background.png': '46492785829f659c5869d91a6510d424ea4977e6921b1ece7de1225aa804e6ca',
 'assets/art/environments/grand_casino_back_room/counters/grand_table_left.png': '9a96841d98e0f5ee53d15563c94881f3ce34ab4569182f7009f6b0609c4dafac',
 'assets/art/environments/grand_casino_back_room/counters/grand_table_right.png': 'de3a5e82cce15772a929306eb423aaf44b96ff3302cf8c73aec1eb12b7dc0964'}
IMPORT_BINDINGS = {'assets/art/environments/grand_casino_back_room/anim/casino_light_0.png': {'baseline_compiled_sha256': '35adc7d57dfcda374a3e39316326736050d20fe0712c5773ac2b3e09c945aef6',
                                                                            'compiled_target': '.godot/imported/casino_light_0.png-7ab6396de1bc23ad35bc33bf2f248be1.ctex',
                                                                            'pck_import_sha256': 'd05ff5c80ec87e47808b453a3e303ead872103d96bdd917e4e8235599f9cdace',
                                                                            'source_import_sha256': '8234362944ed95d99618b4a2631b9f835ab6d8fd3caa7848d0eade76932b2010'},
 'assets/art/environments/grand_casino_back_room/anim/casino_light_1.png': {'baseline_compiled_sha256': '35adc7d57dfcda374a3e39316326736050d20fe0712c5773ac2b3e09c945aef6',
                                                                            'compiled_target': '.godot/imported/casino_light_1.png-a18574706641a31fd2dd7d4a1f4fd174.ctex',
                                                                            'pck_import_sha256': '04e0d0b8ce8bf86b4554b34ceeb671eee41ccec2fb5ce57dc381cf27347ea505',
                                                                            'source_import_sha256': 'c502968e1bd999c741d054d97bc1cb1dd22db619374d3f90012aaf9d6afa6e7a'},
 'assets/art/environments/grand_casino_back_room/anim/casino_light_2.png': {'baseline_compiled_sha256': '35adc7d57dfcda374a3e39316326736050d20fe0712c5773ac2b3e09c945aef6',
                                                                            'compiled_target': '.godot/imported/casino_light_2.png-5e2e1795b620579184280a8e0db224f7.ctex',
                                                                            'pck_import_sha256': 'cfe3d97f09db4fad50ed370c7af52a7502a4cbd338619d6cab5435f2d878eeb8',
                                                                            'source_import_sha256': '9234fa39a2a93947f77f0f3dc2fd956eceb1c51f3101591fc8ba0fa9f4432d89'},
 'assets/art/environments/grand_casino_back_room/anim/casino_light_3.png': {'baseline_compiled_sha256': '35adc7d57dfcda374a3e39316326736050d20fe0712c5773ac2b3e09c945aef6',
                                                                            'compiled_target': '.godot/imported/casino_light_3.png-620a9dd674d4319e5b08dabc40d79fce.ctex',
                                                                            'pck_import_sha256': 'f683b40ecb391344af58d67a880bac7533e06a5f6d2d25f25eab723e2317c9e2',
                                                                            'source_import_sha256': '2adac9d81a5db5445a4b4f81a7b8c8c07961775d48f59722594b651948dbbe5a'},
 'assets/art/environments/grand_casino_back_room/anim/casino_light_4.png': {'baseline_compiled_sha256': '35adc7d57dfcda374a3e39316326736050d20fe0712c5773ac2b3e09c945aef6',
                                                                            'compiled_target': '.godot/imported/casino_light_4.png-65e67d2b69ce6db1e21bf70c9d189eb2.ctex',
                                                                            'pck_import_sha256': 'ea40a9177a64e0748edae6ae56b6ea827c37ed5e542261ed4ab275c5a0e7724f',
                                                                            'source_import_sha256': '590497f37e8af34d3470f9fb9899646661daa85884410b3dad2c2bd8896f77f6'},
 'assets/art/environments/grand_casino_back_room/anim/casino_sign_pulse.png': {'baseline_compiled_sha256': 'd91915dc5af4af70527b753c66b9fde8c8d6c4df511f16fd42f3f34d81de3ca7',
                                                                               'compiled_target': '.godot/imported/casino_sign_pulse.png-846c616eab127d71cc0d2710808a850e.ctex',
                                                                               'pck_import_sha256': 'c2afb86ef34d26b721c8d1d531941bb6d249717c356a5c944d4957df03274d30',
                                                                               'source_import_sha256': 'a600a35652e9bf2dc1c5acc7434491e674b2261f88a6a39e8dd65db51e9fbbc8'},
 'assets/art/environments/grand_casino_back_room/background.png': {'baseline_compiled_sha256': 'd5ae39a752afe9b6c51b48f0c8a5cb9011623cab33399e01d5ab03310082bc35',
                                                                   'compiled_target': '.godot/imported/background.png-56d2a70110771ce5725317a0cb58e891.ctex',
                                                                   'pck_import_sha256': 'e590d6ce6fdcf4c295fc5a34192ae98292e1bf66eeb6ce773cad7b2ada813f80',
                                                                   'source_import_sha256': '138a8d100071774deba84fbd71b94ea8d6375a90d3d32490961f8378675611b3'},
 'assets/art/environments/grand_casino_back_room/counters/grand_table_left.png': {'baseline_compiled_sha256': 'e49ec1c3fb7548fe06d17fafff23f4d7512975f3b5db948c326121a9ca02a724',
                                                                                  'compiled_target': '.godot/imported/grand_table_left.png-7d6a013080834d6578c52888303c6614.ctex',
                                                                                  'pck_import_sha256': '20ec50dd0f27ae849d44dd2a51c434c2e729d0304d69616fee3a907e22d179ed',
                                                                                  'source_import_sha256': 'c863feaa656cff5af4abe263cbfa8b155da5c47fc7680e6997efea47560bbcf6'},
 'assets/art/environments/grand_casino_back_room/counters/grand_table_right.png': {'baseline_compiled_sha256': '6fbd42b0ddf52b7859b7904c30c13053340fa80bfdc392186d824cdfd831ba8b',
                                                                                   'compiled_target': '.godot/imported/grand_table_right.png-599583cad6acf8e328e6322be39593b3.ctex',
                                                                                   'pck_import_sha256': '3998185a5ea902f65e4da034a871db150ca6e702a8a19b4e4d5664d80e1ad4b1',
                                                                                   'source_import_sha256': '3c46ec9761bd521470da4443aea36df4c2d5dac791f9d0705e7f6f0f3fb25128'}}
IMPORT_SHAS = {name + ".import": row["source_import_sha256"] for name, row in IMPORT_BINDINGS.items()}


def component_result(**values):
    return {**values, "schema": SCHEMA, "baseline_qualified": False, "art_approval": False,
        "native_receipts_authenticated": False, "embedded_identity_authenticated": False}


def check_json_semantics(original_raw, candidate_raw):
    """Exactly one typed lamp2 rect.x450->448; every other value/type equal."""
    original, candidate = json_value(original_raw), json_value(candidate_raw)
    require(isinstance(original, dict) and original.get("environment_id") == ENVIRONMENT and
            same_typed(original.get("board_size"), [900, 430]) and type(original.get("pixel_scale")) is int and
            original["pixel_scale"] == 2, "Original GBR board namespace/type differs")
    expected = deepcopy(original)
    rows = expected.get("animations", [])
    require(isinstance(rows, list) and all(isinstance(row, dict) for row in rows) and
            tuple(row.get("id") for row in rows) == ANIMATION_IDS and
            tuple(row["id"] for row in rows if row.get("web_low_detail") is True) == LOW_IDS,
            "Original GBR16/seven animation inventory differs")
    rect = rows[2].get("rect")
    require(same_typed(rect, [450, 124, 52, 8]), "Original casino_light_2 integer rect differs")
    rows[2]["rect"][0] = 448
    require(same_typed(expected, candidate), "Only casino_light_2 integer rect.x450->448 is admitted")
    return candidate


def check_json(original_raw, candidate_raw):
    candidate = check_json_semantics(original_raw, candidate_raw)
    require(sha(original_raw) == BASE_GBR_JSON_SHA and sha(candidate_raw) == GBR_JSON_SHA,
            "Actual reviewed GBR original/candidate JSON bytes differ")
    return candidate


def package_seal(hashes):
    return sha("\n".join(name + " " + hashes[name] for name in sorted(hashes)).encode())


def payload_paths(baseline):
    paths = {name for name in baseline["art_source_files"] if name.startswith(ART)} | {GBR_JSON, INDEX_JSON}
    require(paths == set(BASE_PAYLOAD_SHAS) and len(paths) == 21 and
            sum(name.endswith(".png") for name in paths) == 19, "Exact original GBR21 package membership required")
    require({name: baseline["art_source_files"][name] for name in paths} == BASE_PAYLOAD_SHAS and
            package_seal(BASE_PAYLOAD_SHAS) == BASE_PACKAGE_SHA, "Original GBR package bytes differ")
    return sorted(paths)


def candidate_hashes(baseline, observed):
    paths = payload_paths(baseline)
    require(set(observed) == set(paths) and observed == PAYLOAD_SHAS and package_seal(observed) == PACKAGE_SHA,
            "Actual GBR21 payload differs from reviewed V2")
    require({name for name in observed if observed[name] != baseline["art_source_files"][name]} == set(PNG_SHAS) | {GBR_JSON},
            "Exactly nine PNGs and GBR JSON must differ")
    return component_result(package_sha256=PACKAGE_SHA, files=dict(observed), status="PACKAGE_MATCH_ONLY")


def expected_raw(baseline):
    raw = baseline["art_source_files"]
    require(len(raw) == 421 and sum(name.endswith(".png") for name in raw) == 400 and
            sum(name.endswith(".json") for name in raw) == 21 and len(baseline["compiled_art_sha256"]) == 400 and
            len(baseline["active_art_packages"]) == 20 and len(baseline["active_doorway_packages"]) == 12,
            "Complete421raw/400CTEX/20room/12doorway runtime inventory required")
    require(all(baseline["active_art_packages"].get(name) == value for name, value in PROTECTED_SEALS.items()) and
            baseline["active_art_packages"].get(ENVIRONMENT) == BASE_ACTIVATION_SHA,
            "Delivered HL/Grand/Bar or original GBR package seal differs")
    payload_paths(baseline)
    for value in raw.values():
        full_hash(value)
    return {**raw, **PNG_SHAS, GBR_JSON: GBR_JSON_SHA}


def check_source_hashes(baseline, observed):
    require(observed == expected_raw(baseline), "Actual421 sources changed outside exact reviewed GBR delta")
    return candidate_hashes(baseline, {name: observed[name] for name in payload_paths(baseline)})


def check_import_hashes(observed):
    require(observed == IMPORT_SHAS, "Actual canonical nine GBR source import metadata hashes differ")
    return component_result(canonical_imports_match=True, files=dict(observed))


def check_native_review_declaration(value):
    """Pure shape/content check only; does not authenticate file or closed Jobs."""
    require(value.get("schema") == "bth.grand_back_room_spatial_native_art_review/v1" and
            value.get("decision") == "GO_FOR_TEST_BUILD" and value.get("task_id") == TASK_ID and
            value.get("room") == ENVIRONMENT and value.get("environment") == ENVIRONMENT and
            value.get("production_activation_approved") is True and
            isinstance(value.get("independent_reviewer"), str) and value["independent_reviewer"].strip(),
            "Separate final GBR native/art review declaration required")
    require(value.get("approved_package_files_sha256") == PAYLOAD_SHAS and
            value.get("package_21_file_sha256") == PACKAGE_SHA and value.get("grand_back_room_json_sha256") == GBR_JSON_SHA,
            "Declared final GBR native/art payload differs")
    require(value.get("native_adapter_sha256") == NATIVE_ADAPTER_SHA and value.get("native_policy_sha256") == NATIVE_POLICY_SHA and
            value.get("selected_source_helper_sha256") == SELECTED_SOURCE_SHA, "Declared actual GBR native helper identities differ")
    for name in ("source_commit", "source_tree"):
        full_hash(value.get(name), 40)
    for name in ("native_source_config_sha256", "native_identity_sha256", "native_capture_inputs_sha256", "native_contexts_sha256",
                 "native_motion_sha256", "native_liveness_sha256", "native_capture_sha256"):
        full_hash(value.get(name))
    required = {"source-identity", "tree", "baseline-tree", "select", "archive", "prepare", "install", "import",
                "identity", "contexts", "motion", "liveness", "capture"}
    require(isinstance(value.get("native_phase_receipts"), dict) and set(value["native_phase_receipts"]) == required,
            "Exact thirteen GBR native phase references required")
    return component_result(status="NATIVE_REVIEW_DECLARATION_ONLY_NOT_QUALIFICATION")


def validate_manifest(manifest, baseline, targets):
    """Inventory component only; actual delivered HL authority is external."""
    check_source_hashes(baseline, manifest["art_source_files"])
    active = {**baseline["active_art_packages"], ENVIRONMENT: PACKAGE_SHA}
    require(manifest["active_art_packages"] == active and manifest["active_doorway_packages"] == baseline["active_doorway_packages"] and
            manifest.get("art_package_sha256") == PACKAGE_SHA, "Protected room/doorway activation map changed")
    old, new = baseline["compiled_art_sha256"], manifest["compiled_art_sha256"]
    require(set(targets) == {row["compiled_target"] for row in IMPORT_BINDINGS.values()} and len(targets) == 9 and
            set(targets).issubset(old) and new.keys() == old.keys() and len(new) == 400, "Exact nine canonical GBR CTEX/400 inventory required")
    for name, prior in old.items():
        full_hash(prior)
        full_hash(new[name])
        require((name in targets) != (new[name] == prior), "Compiled change outside exact nine GBR targets: " + name)
    require(manifest["files"].keys() == baseline["files"].keys() and manifest.get("channel") == baseline.get("channel") == "test",
            "TEST channel or Web file inventory changed")
    for name in ("platform", "engine_sha256", "export_presets_sha256", "native_library_path", "native_library_sha256",
                 "template_sha256", "persistence_core_sha256", "test_args", "persistent_paths"):
        require(name in baseline and name in manifest and same_typed(manifest[name], baseline[name]),
                "Protected engine/native/template/persistence pin changed: " + name)
    for name, prior in baseline["files"].items():
        require(name in ("index.html", "index.pck") or same_typed(manifest["files"][name], prior),
                "Protected engine/native/template/WebGL payload changed: " + name)
    return component_result(status="MANIFEST_DELTA_ONLY_NOT_BASELINE_QUALIFICATION")


def verify_pck_delta(old, new, baseline, manifest, expected_baseline_pck_sha256):
    """Bounded immutable PCK comparison, never a receipt/identity authenticator."""
    import audit_pck_manifest
    from bar_spatial_test_build import pck_entry_bytes, decode_uid_cache
    require(type(old) is bytes and type(new) is bytes and 112 <= len(old) <= 512 * 1024 ** 2 and
            112 <= len(new) <= 512 * 1024 ** 2, "Bounded immutable standalone PCK byte inputs required")
    full_hash(expected_baseline_pck_sha256)
    require(sha(old) == expected_baseline_pck_sha256, "Actual declared baseline PCK bytes differ")
    od, nd = audit_pck_manifest.find_directory(old), audit_pck_manifest.find_directory(new)
    oe, ne = {row["path"]: row for row in od["entries"]}, {row["path"]: row for row in nd["entries"]}
    require(od["pack_offset"] == nd["pack_offset"] == 0 and
            len(oe) == len(od["entries"]) == len(ne) == len(nd["entries"]) == 2107 and oe.keys() == ne.keys(),
            "Exact standalone2107 PCK resource inventory required")
    read = lambda data, directory, rows, name: pck_entry_bytes(data, directory, rows[name])
    targets = set()
    for source, binding in IMPORT_BINDINGS.items():
        original_import = read(old, od, oe, source + ".import")
        found = re.findall(r'^path="res://([^"\n]+\.ctex)"\r?$', original_import.decode("utf-8"), re.M)
        require(sha(original_import) == binding["pck_import_sha256"] and found == [binding["compiled_target"]] and
                baseline["compiled_art_sha256"][binding["compiled_target"]] == binding["baseline_compiled_sha256"],
                "Original source/import/CTEX binding differs: " + source)
        targets.add(found[0])
    validate_manifest(manifest, baseline, targets)
    changed = {name for name in oe if read(old, od, oe, name) != read(new, nd, ne, name)}
    require(changed == targets | {GBR_JSON, "build_manifest.json"},
            "PCK delta is not exactly nine GBR textures, its one-integer-X JSON and identity")
    old_uid, new_uid = read(old, od, oe, ".godot/uid_cache.bin"), read(new, nd, ne, ".godot/uid_cache.bin")
    uid = decode_uid_cache(old_uid)
    require(old_uid == new_uid and len(uid) == 1605 and sha(old_uid) == UID_SHA and
            sha(json.dumps(uid, sort_keys=True, separators=(",", ":")).encode()) == UID_MAP_SHA and
            sha(read(old, od, oe, ".godot/global_script_class_cache.cfg")) == CLASS_SHA, "Canonical1605 UID/cache/class proof differs")
    check_json(read(old, od, oe, GBR_JSON), read(new, nd, ne, GBR_JSON))
    for name, expected in baseline["compiled_art_sha256"].items():
        require(sha(read(old, od, oe, name)) == expected, "Actual baseline400 CTEX bytes differ from manifest")
    for name, expected in manifest["compiled_art_sha256"].items():
        require(sha(read(new, nd, ne, name)) == expected, "Actual new400 CTEX bytes differ from manifest")
    for name, expected in baseline["art_source_files"].items():
        if name.endswith(".json"):
            require(sha(read(old, od, oe, name)) == expected, "Actual baseline packed art JSON differs")
    for name, expected in manifest["art_source_files"].items():
        if name.endswith(".json"):
            require(sha(read(new, nd, ne, name)) == expected, "Actual new packed art JSON differs")
    return component_result(scope="PCK_DELTA_ONLY_NOT_BASELINE_QUALIFICATION", baseline_pck_sha256=sha(old),
        pck_sha256=sha(new), changed=sorted(changed), resources=2107, uid_bindings=1605,
        uid_cache_bytes_equal=True, class_cache_bytes_equal=True, all_scn_gdc_bytes_equal=True,
        all_other_room_and_doorway_resources_equal=True)
