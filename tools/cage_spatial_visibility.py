"""Read-only Cage conservative visibility and exact retained R2 reproduction.

Only pure image analysis and bounded input reads. The caller owns storage/Job
admission, output writing, source-to-motion custody and native acceptance.
No Pillow, dynamic execution, image output, subprocess or CLI entry point.
"""
import sys
sys.dont_write_bytecode = True

from array import array
import hashlib
import json
import math
from pathlib import Path
import stat

from bar_spatial_candidate_check import PNGImage, decode_png

SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
HISTORICAL_MOTION = Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-motion-01/evidence")
HISTORICAL_CONTEXTS = Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-contexts-01/evidence")
HISTORICAL_REFERENCE = Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGE-20261115-occlusion-r2-01/evidence/cage-base-occlusion.json")
REFERENCE_SHA = "3b709d8bad84c15b5ae10e865c01cd4a93234f2e379eea3463061e827b62ead6"
DECODER = SOURCE_ROOT / "tools/bar_spatial_candidate_check.py"
DECODER_SHA = "bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f"
CHECKERS = {
    "E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/check_cage_occlusion.py":
        "36443e4cfc825153ee4e450d30c194e0a23d1d870ee1bae1dc064fc73cc33c78",
    "E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/check_grand_occlusion.py":
        "3c2b329fbf43fcd7af86ee9554ebb2e73240c7bf68fcdd56b8295368dd0570a7",
}
HISTORICAL_INPUTS = {
    "motion/grand_casino_cage_animation_probe.json": "9529d04a00798f4dc88c42cc7a4c32115d046166aeb25b5298599476efe11ea7",
    "contexts/__none_metadata.json": "3cdf393984aa8dbcf6e8e92e6178611fefffec8541e67c6e144a5c0ecda78480",
    "motion/cage_sign_pulse_live_a.png": "ee066ab2b3f9d40b4a4bf7e5b242e4abe5d9b5ae0f6ec7f1cdba2b1ac861e889",
    "motion/cage_sign_pulse_live_b.png": "b4c98caf82a3172488285334bdae191223832be3b96c85cbbe540feb832eed6b",
    "motion/cage_sign_pulse_low_live_a.png": "ee066ab2b3f9d40b4a4bf7e5b242e4abe5d9b5ae0f6ec7f1cdba2b1ac861e889",
    "motion/cage_sign_pulse_low_live_b.png": "b4c98caf82a3172488285334bdae191223832be3b96c85cbbe540feb832eed6b",
    "motion/atm_scan_live_a.png": "870cf397708223e212e37ee225feb4b48fb38d20ab0419733f60b3f5dca64a79",
    "motion/atm_scan_live_b.png": "c5f99b5479c94261399dcf635c9e5945079372afb53c5d35034075dc11bb1806",
    "motion/atm_scan_low_live_a.png": "870cf397708223e212e37ee225feb4b48fb38d20ab0419733f60b3f5dca64a79",
    "motion/atm_scan_low_live_b.png": "c5f99b5479c94261399dcf635c9e5945079372afb53c5d35034075dc11bb1806",
    "motion/cage_glint_0_live_a.png": "e4f6f04dcc7ac990c364814a31f74eeb289f27282a80604143e36affbdc1eda9",
    "motion/cage_glint_0_live_b.png": "f1c42e1329f26dcbf2b4dcc51638c6c2b5d580d5d67fd09309fd842e2c0a1e80",
    "motion/cage_glint_0_low_live_a.png": "e4f6f04dcc7ac990c364814a31f74eeb289f27282a80604143e36affbdc1eda9",
    "motion/cage_glint_0_low_live_b.png": "f1c42e1329f26dcbf2b4dcc51638c6c2b5d580d5d67fd09309fd842e2c0a1e80",
    "motion/cage_glint_1_live_a.png": "2c8ec1877334add5c6d6f6104eee655b2720f4f78e16c5441cbbedc09042d260",
    "motion/cage_glint_1_live_b.png": "238ff0404eafeea346b65f00e4e5949c6d14bba2ac06d36dda6aca073fc509f1",
    "motion/cage_glint_1_low_live_a.png": "2c8ec1877334add5c6d6f6104eee655b2720f4f78e16c5441cbbedc09042d260",
    "motion/cage_glint_1_low_live_b.png": "238ff0404eafeea346b65f00e4e5949c6d14bba2ac06d36dda6aca073fc509f1",
    "motion/cage_glint_2_live_a.png": "8ddc7d2472c8c5c205b4bfd1aa38667e9d6657f239080c3b08ec8ac1d29d904f",
    "motion/cage_glint_2_live_b.png": "efde9ddd66403b29fcac59b3e056110bb7e32f195cae355512aad7b1802b924a",
    "motion/cage_glint_2_low_live_a.png": "8ddc7d2472c8c5c205b4bfd1aa38667e9d6657f239080c3b08ec8ac1d29d904f",
    "motion/cage_glint_2_low_live_b.png": "efde9ddd66403b29fcac59b3e056110bb7e32f195cae355512aad7b1802b924a",
    "motion/cage_glint_3_live_a.png": "7b3f19d5e75227825b3ae54edcac0fd3956ae50091e3a4637ed116b1c4d1f7ce",
    "motion/cage_glint_3_live_b.png": "13fb35d1a22b009a98990ed4d9d995fcf9aa6b9236234f1063e16850075b4d9c",
    "motion/cage_glint_3_low_live_a.png": "7b3f19d5e75227825b3ae54edcac0fd3956ae50091e3a4637ed116b1c4d1f7ce",
    "motion/cage_glint_3_low_live_b.png": "13fb35d1a22b009a98990ed4d9d995fcf9aa6b9236234f1063e16850075b4d9c",
    "motion/cage_glint_4_live_a.png": "f621fa340432f91d1eb5bc0917a2950b03ff2578dd071364a8699fafeaeebd63",
    "motion/cage_glint_4_live_b.png": "f8d6954bf7b9f32c9f8314b742ba5b1de3398355116944b653ab9d883bd4301a",
    "motion/cage_glint_4_low_live_a.png": "f621fa340432f91d1eb5bc0917a2950b03ff2578dd071364a8699fafeaeebd63",
    "motion/cage_glint_4_low_live_b.png": "f8d6954bf7b9f32c9f8314b742ba5b1de3398355116944b653ab9d883bd4301a",
    "motion/cage_glint_5_live_a.png": "68e8078249384974599a40d93ec8694a1ab7c4a77c4489152de8fad7c6e11a56",
    "motion/cage_glint_5_live_b.png": "018a4667cd34f6ac399345db54681fa13e37e456ae6f2af7f208aa61e0e0b12f",
    "motion/cage_glint_5_low_live_a.png": "68e8078249384974599a40d93ec8694a1ab7c4a77c4489152de8fad7c6e11a56",
    "motion/cage_glint_5_low_live_b.png": "018a4667cd34f6ac399345db54681fa13e37e456ae6f2af7f208aa61e0e0b12f",
    "motion/cage_glint_6_live_a.png": "a2614a28360ad786380927ede89358f0b9988f217e6076e09b62a8f958696b34",
    "motion/cage_glint_6_live_b.png": "2f5fd8e2e550d132bb315afcbaa8b047f5c59557ef6f5444486f3a6207c6a0c1",
    "motion/cage_glint_6_low_live_a.png": "a2614a28360ad786380927ede89358f0b9988f217e6076e09b62a8f958696b34",
    "motion/cage_glint_6_low_live_b.png": "2f5fd8e2e550d132bb315afcbaa8b047f5c59557ef6f5444486f3a6207c6a0c1",
    "motion/cage_glint_7_live_a.png": "6ebd2fb03da01ff087f4eb0cae27a6c4781a0b87f0d005f46c336971f7f1949e",
    "motion/cage_glint_7_live_b.png": "1ace2eb90b88c3ccc21d47a9ae26558785f537c40253efbd085d34722bfac0b7",
    "motion/cage_glint_7_low_live_a.png": "6ebd2fb03da01ff087f4eb0cae27a6c4781a0b87f0d005f46c336971f7f1949e",
    "motion/cage_glint_7_low_live_b.png": "1ace2eb90b88c3ccc21d47a9ae26558785f537c40253efbd085d34722bfac0b7",
    "motion/cage_glint_8_live_a.png": "258bc82d6466760a47cdc83f770b136d56a6c3cf3815f3ad69fddb8bba2f73ee",
    "motion/cage_glint_8_live_b.png": "c4d53dd88da17489ed84628dc638585983d9501bbee3713a11a7099a4de769a1",
    "motion/cage_glint_8_low_live_a.png": "258bc82d6466760a47cdc83f770b136d56a6c3cf3815f3ad69fddb8bba2f73ee",
    "motion/cage_glint_8_low_live_b.png": "c4d53dd88da17489ed84628dc638585983d9501bbee3713a11a7099a4de769a1",
    "motion/cage_glint_9_live_a.png": "900dd69675df9fce0ab18e693f5fd939e4ad3ba8904d77f71bb9a2348d17bc43",
    "motion/cage_glint_9_live_b.png": "a2c25a62995c5ed1628ae9596c90d2a22a00f45562f3bab4988114cfbe02cc79",
    "motion/cage_glint_9_low_live_a.png": "900dd69675df9fce0ab18e693f5fd939e4ad3ba8904d77f71bb9a2348d17bc43",
    "motion/cage_glint_9_low_live_b.png": "a2c25a62995c5ed1628ae9596c90d2a22a00f45562f3bab4988114cfbe02cc79",
    "motion/cage_glint_10_live_a.png": "aff317111af974cc0ec0cdc383e5b9bc8feed17a50c26d8228e2c0b9d5d9c049",
    "motion/cage_glint_10_live_b.png": "0f016c7b1da8cd1fae4ad0563fb09ac7ea581c83837044fc46609ef45b175f71",
    "motion/cage_glint_10_low_live_a.png": "aff317111af974cc0ec0cdc383e5b9bc8feed17a50c26d8228e2c0b9d5d9c049",
    "motion/cage_glint_10_low_live_b.png": "0f016c7b1da8cd1fae4ad0563fb09ac7ea581c83837044fc46609ef45b175f71",
    "motion/floor_glint_0_live_a.png": "cde50d6bc70e7f6556a775fa5038ccb50ed6ec216bcf3f2900e41ec128b1d64e",
    "motion/floor_glint_0_live_b.png": "28053e017e8fc270fd7ee020fe4e4e25e800b85bd06dbbc11e2cb6ccefb5fb79",
    "motion/floor_glint_0_low_live_a.png": "cde50d6bc70e7f6556a775fa5038ccb50ed6ec216bcf3f2900e41ec128b1d64e",
    "motion/floor_glint_0_low_live_b.png": "28053e017e8fc270fd7ee020fe4e4e25e800b85bd06dbbc11e2cb6ccefb5fb79",
    "motion/floor_glint_1_live_a.png": "513f51dc7e0737b0acc24fcb7c966318b48760b2b6e5abf8c1a24e080de58ada",
    "motion/floor_glint_1_live_b.png": "217aedc5b1f66a8b177ab43bed9cd71fbb9a76118cf180c871ab35f89d5c5a48",
    "motion/floor_glint_1_low_live_a.png": "513f51dc7e0737b0acc24fcb7c966318b48760b2b6e5abf8c1a24e080de58ada",
    "motion/floor_glint_1_low_live_b.png": "217aedc5b1f66a8b177ab43bed9cd71fbb9a76118cf180c871ab35f89d5c5a48",
    "motion/floor_glint_2_live_a.png": "b2ef80021ee9c675abead4f9bdbfc897219185e90ba4760b7cb11bf9f8aff9e8",
    "motion/floor_glint_2_live_b.png": "d3c1124e4da9bbfcdb5b3b797b2230085496c3d19a2df0ecda0ded481e2b2433",
    "motion/floor_glint_2_low_live_a.png": "b2ef80021ee9c675abead4f9bdbfc897219185e90ba4760b7cb11bf9f8aff9e8",
    "motion/floor_glint_2_low_live_b.png": "d3c1124e4da9bbfcdb5b3b797b2230085496c3d19a2df0ecda0ded481e2b2433",
    "motion/floor_glint_3_live_a.png": "dc59998d892f0a4380711113862bc81f7a2f27c58dbccb2c5209b1187f34abcd",
    "motion/floor_glint_3_live_b.png": "71700eea0b861dadd3cfa443b20a5bc820fc5ee2d2e75adbb1316de273b0ece7",
    "motion/floor_glint_4_live_a.png": "b3910d74d52120ff14d86061b82dc68a708c1dd742b710091d99fedacfa73e2d",
    "motion/floor_glint_4_live_b.png": "cdc73a7ac888281c5582fe5460572807953599083c8509630780d6419668a61d",
    "motion/floor_glint_5_live_a.png": "58551d8b334c5990d2b2f0066d4cf717edaf120750fc9fe7dec9d2bff1d0a559",
    "motion/floor_glint_5_live_b.png": "46a811e3bdd4644ef2f761381d2edcf58b279c4436058f0317aeff8432b042bf",
    "motion/floor_glint_6_live_a.png": "06f3586e709dabde2b394a65d54dd9a7cc4462fdf4125ef7cebc0c53ba34e2ab",
    "motion/floor_glint_6_live_b.png": "7698f241227e052a0891f7c8421766c389d4727676956a2570bd245b75a751bf",
    "contexts/__none_host_0_adorn.png": "f2042f53b0de90853b8ee9a3b02f2f0909477e9355c6cc73c7257d2f48d90558",
    "contexts/__none_host_0_body.png": "598a55a80b694a63efffa352def2be1dad5bd0a67e265c7ef681b369059266af",
    "contexts/__none_host_1_adorn.png": "904fef1387697f7c8f0fd32cbc22711a9f43aeb2ccd66c3991bb0a739b7a1366",
    "contexts/__none_host_1_body.png": "34b10a71fb3ba0d27cf410443f508ca6e88377ca8685c9bda6eb301a5956c3f8",
    "contexts/__none_host_2_adorn.png": "f4b56240540bdb2291a907b5eda58fa01ffa9177941069f3180927a17beb3600",
    "contexts/__none_host_2_body.png": "92fa9f16e023df8b08a96a0fb7e207079f56011d2d86c7fa176c529fe641d194",
    "contexts/__none_host_3_adorn.png": "29a4fb1500b29cb94a2639431836f092f955fa0aac2a606fcbe5b281bb02c84a",
    "contexts/__none_host_3_body.png": "eeae7524b954523fa18be32f09d6556bd1fe9c46eb14fbcc19f55356281bfe8a",
    "contexts/__none_host_4_adorn.png": "a77e00fcefc93493ba355f11b5090f70d17d0a57cd23b8503703cec1703e6cea",
    "contexts/__none_host_4_body.png": "94dd68af353e2cba8876c9db444ee493240a1179b1190931b5de4ef0ac1333a7",
    "contexts/__none_source_mode2_clock0.0_lowfalse_cleanfalse.png": "e1718275d159fbb5fd8545ccac7f4fbfbddfe93055d5bb32df848abf7b6e3d34"
}
ANIMATION_IDS = ("cage_sign_pulse", "atm_scan",
                 *("cage_glint_" + str(i) for i in range(11)),
                 *("floor_glint_" + str(i) for i in range(7)))
LOW_IDS = frozenset(ANIMATION_IDS) - {
    "floor_glint_3", "floor_glint_4", "floor_glint_5", "floor_glint_6"}
HOST_IDS = ("staff:grand_casino_linda", "casino_fixture:cage_atm",
            "casino_fixture:cage_counter", "travel:grand_casino", "travel:leave")
SIZE = (1800, 860)
SIGN = "assets/art/environments/grand_casino_cage/anim/cage_sign_pulse.png"
BACKGROUND = "assets/art/environments/grand_casino_cage/background.png"
MANIFEST = "data/art/environments/grand_casino_cage.json"
CANDIDATE_PINS = {
    SIGN: "f9e0c563b34546dc31f67bc5a963b1d098509ba5f6608388ab959596d59dd661",
    BACKGROUND: "9c6f7bb773711b56fbdbddd65d1318342df397ef0130b83c1565784757c7a2f7",
    MANIFEST: "ab70b2d0fc3e7d02a0b8c645cb1b71a0e056e1e63d7d1c029669cbb3f66c1b9e",
}
GLYPH_COMPONENTS = (
    (140, (350, 44, 367, 66)), (233, (369, 44, 387, 66)),
    (186, (392, 44, 405, 67)), (174, (415, 44, 432, 67)),
    (224, (433, 44, 453, 67)), (241, (454, 44, 473, 67)),
    (185, (476, 44, 490, 66)))
MAX_BYTES = 32 * 1024 * 1024
SCOPE = ("Cage fixed-clock native art-target pairs conservatively composited beneath "
         "the exact teller front and all actual Base typed body/adornment masks, "
         "including Linda and her live bars. Base only, not full stock or Linda "
         "progression. Surviving pixel change is separate from actual-time "
         "playback/perceptual prominence.")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def _read(path):
    path = Path(path)
    require(path.is_absolute(), "Explicit absolute input path required")
    for p in (path, *path.parents):
        info = p.lstat()
        require(not stat.S_ISLNK(info.st_mode) and
                not (getattr(info, "st_file_attributes", 0) & 0x400),
                "Reparse/symlink input forbidden: " + str(p))
    require(path.is_file() and path.stat().st_size <= MAX_BYTES,
            "Missing/oversized input: " + str(path))
    data = path.read_bytes()
    require(len(data) <= MAX_BYTES, "Input grew beyond byte limit")
    return data


class _Reader:
    def __init__(self, expected=None):
        self.hashes = {}
        self.expected = expected

    def read(self, path):
        path = Path(path)
        key = str(path)
        data = _read(path)
        value = digest(data)
        if self.expected is not None:
            require(self.expected.get(key) == value,
                    "Historical input hash differs/unlisted: " + key)
        require(key not in self.hashes or self.hashes[key] == value,
                "Input changed during analysis: " + key)
        self.hashes[key] = value
        return data

    def image(self, path):
        image = decode_png(self.read(path))
        require((image.width, image.height) == SIZE, "Native image must be1800x860")
        return image

    def finish(self):
        if self.expected is not None:
            require(set(self.hashes) == set(self.expected),
                    "Historical authenticated input closure incomplete")
        for path, value in self.hashes.items():
            require(digest(_read(path)) == value, "Read-only input custody changed: " + path)


def _words(data):
    # RGBA words always use R in bits0..7, independent of host byte order.
    if sys.byteorder == "little":
        return memoryview(data).cast("I")
    value = array("I")
    value.frombytes(data)
    value.byteswap()
    return value


def _div255(value):
    return ((value >> 8) + value) >> 8


def alpha_over_pixel(destination, source):
    """Pillow-compatible straight RGBA integer source-over (7-bit coefficients)."""
    sa = source >> 24
    if sa == 0:
        return destination
    da = destination >> 24
    if sa == 255 or da == 0:
        return source
    blend = da * (255 - sa)
    alpha255 = sa * 255 + blend
    coefficient1 = sa * 255 * 255 * 128 // alpha255
    coefficient2 = 255 * 128 - coefficient1
    result = _div255(alpha255 + 128) << 24
    for shift in (0, 8, 16):
        value = ((source >> shift) & 255) * coefficient1
        value += ((destination >> shift) & 255) * coefficient2
        result |= (_div255(value + (128 << 7)) >> 7) << shift
    return result


def composite_rgba(destination, source):
    """Exact source-over; transparent source preserves destination including RGB."""
    require((destination.width, destination.height) == (source.width, source.height),
            "Composite dimensions differ")
    output = array("I", _words(destination.rgba))
    for i, value in enumerate(_words(source.rgba)):
        if value >> 24:
            output[i] = alpha_over_pixel(output[i], value)
    if sys.byteorder != "little":
        output.byteswap()
    return PNGImage(destination.width, destination.height, output.tobytes())


def visibility_metrics(a, b, overlay, *, allowed_changed_pixels=None):
    """Original RGB max-difference histogram count/max after conservative overlay."""
    require((a.width, a.height) == (b.width, b.height) == (overlay.width, overlay.height),
            "Visibility dimensions differ")
    count_pixels = a.width * a.height
    require(a.rgba[3::4] == b"\xff" * count_pixels and
            b.rgba[3::4] == b"\xff" * count_pixels,
            "Rendered art-target pairs must be opaque RGBA")
    changed, maximum, raw_changed, outside = 0, 0, 0, 0
    for i, (av, bv, ov) in enumerate(zip(_words(a.rgba), _words(b.rgba), _words(overlay.rgba))):
        if av == bv:
            continue
        raw_changed += 1
        if allowed_changed_pixels is not None and i not in allowed_changed_pixels:
            outside += 1
        if ov >> 24 == 255:
            continue
        if ov >> 24:
            av, bv = alpha_over_pixel(av, ov), alpha_over_pixel(bv, ov)
        delta = max(abs(((av >> shift) & 255) - ((bv >> shift) & 255))
                    for shift in (0, 8, 16))
        if delta:
            changed += 1
            maximum = max(maximum, delta)
    require(outside == 0, "Fresh sign motion changes pixels outside5532 glyph support")
    return {"surviving_changed_pixels": changed, "maximum_channel_delta": maximum,
            "visible_pixel_change_under_conservative_overlay": changed > 0,
            "raw_changed_pixels": raw_changed, "outside_glyph_changed_pixels": outside}


def typed_mapping(metadata):
    paint = metadata.get("source_paint", {})
    require(paint.get("geometry_equal") is True, "Actual source-paint geometry differs")
    require(paint.get("requested_host_ids") == list(HOST_IDS), "Exact five requested Cage hosts required")
    require([row.get("id") for row in metadata.get("actual_view", {}).get("objects", [])] == list(HOST_IDS),
            "Exact actual Base object IDs/order required")
    objects = paint.get("objects", [])
    require(len(objects) == 5, "Exactly five actual source-paint objects required")
    names = []
    for i, row in enumerate(objects):
        require(row.get("object", {}).get("id") == HOST_IDS[i], "Typed host identity/order differs")
        for kind in ("body", "adorn"):
            name = "__none_host_" + str(i) + "_" + kind + ".png"
            require(row.get(kind + "_png") == name, "Exact typed mask filename required")
            names.append(name)
    return names


def motion_contract(report):
    entries = report.get("entries", [])
    low = report.get("simulated_low_detail_entries", [])
    require(report.get("checks") == 82 and report.get("failures") == [] and
            report.get("simulated_low_detail_count") == 16,
            "Actual Cage82-check/20native/16low motion contract required")
    require([r.get("id") for r in entries] == list(ANIMATION_IDS) and
            [r.get("id") for r in low] == list(ANIMATION_IDS),
            "Exact20 native and low-detail motion identities/order required")
    for entry, reduced in zip(entries, low):
        require(entry.get("live_visible_change") is True and entry.get("reduce_motion_stable") is True,
                "Native live/RM declaration failed")
        require(reduced.get("included") is (entry["id"] in LOW_IDS) and
                reduced.get("live_change") is (entry["id"] in LOW_IDS) and
                reduced.get("reduce_motion_stable") is True,
                "Actual low-detail renderer contract differs")
        require(all(type(entry.get(k)) in (int, float) and math.isfinite(entry[k])
                    for k in ("clock_a", "clock_b")), "Finite actual per-entry clocks required")
    return entries


def _components(points):
    remaining, result = set(points), []
    while remaining:
        first = min(remaining)
        remaining.remove(first)
        pending, found = [first], [first]
        while pending:
            x, y = pending.pop()
            for q in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if q in remaining:
                    remaining.remove(q)
                    pending.append(q)
                    found.append(q)
        result.append((len(found), (min(x for x, y in found), min(y for x, y in found),
                                   max(x for x, y in found)+1, max(y for x, y in found)+1)))
    return tuple(sorted(result, key=lambda row: row[1]))


def glyph_contract(sign, background):
    require((sign.width, sign.height) == (464, 112) and
            (background.width, background.height) == SIZE, "Exact sign/master dimensions required")
    support, board = set(), set()
    for y in range(112):
        for x in range(464):
            at = (y*464+x)*4
            source = ((72+y)*1800+668+x)*4
            r, g, b, alpha = background.rgba[source:source+4]
            gold = r >= 100 and g >= 70 and 10*r >= 9*g and 4*g >= 5*b
            require(alpha == 255, "Original master must be opaque in sign clip")
            require(sign.rgba[at:at+3] == b"\xff\xe4\x5c", "Sign RGB differs from original")
            require(sign.rgba[at+3] == (46 if gold else 0),
                    "Candidate sign must preserve exactly glyph alpha46 and zero outside")
            if gold:
                support.add((72+y)*1800+668+x)
                board.add(((668+x)//2, (72+y)//2))
    require(len(support) == 5532 and len(board) == 1383 and _components(board) == GLYPH_COMPONENTS,
            "Exact seven glyph components/5532native/1383board support required")
    for y in range(0, 112, 2):
        for x in range(0, 464, 2):
            at = (y*464+x)*4
            p = sign.rgba[at:at+4]
            require(all(sign.rgba[((y+dy)*464+x+dx)*4:((y+dy)*464+x+dx)*4+4] == p
                        for dx, dy in ((1, 0), (0, 1), (1, 1))), "Nonuniform signNN2 block")
    return frozenset(support), {
        "expected_encoded_sign_sha256": CANDIDATE_PINS[SIGN], "retained_alpha46_native_texels": 5532,
        "zero_alpha_native_texels": 46436, "board_glyph_pixels": 1383,
        "four_connected_board_components": GLYPH_COMPONENTS, "all_RGB_original_exact": True,
        "only_glyph_motion_allowed": True, "NN2_exact": True}


def _candidate_contract(root, reader):
    root = Path(root)
    data = {name: reader.read(root/name) for name in CANDIDATE_PINS}
    require({name: digest(value) for name, value in data.items()} == CANDIDATE_PINS,
            "Exact reviewed fresh candidate sign/master/manifest required")
    spec = json.loads(data[MANIFEST])
    require([row["id"] for row in spec["animations"]] == list(ANIMATION_IDS) and
            {row["id"] for row in spec["animations"] if row["web_low_detail"]} == LOW_IDS,
            "Candidate manifest20/16 identities or flags differ")
    support, proof = glyph_contract(decode_png(data[SIGN]), decode_png(data[BACKGROUND]))
    proof["candidate_root"] = str(root)
    proof["sign_sha256"] = digest(data[SIGN])
    proof["input_hashes"] = {str(root/name): digest(value) for name, value in data.items()}
    return support, proof


def _visibility_report(motion_dir, contexts_dir, candidate_root=None, expected=None):
    motion_dir, contexts_dir = Path(motion_dir), Path(contexts_dir)
    reader = _Reader(expected)
    require(digest(reader.read(DECODER)) == DECODER_SHA, "Frozen stdlib PNG decoder differs")
    report = json.loads(reader.read(motion_dir/"grand_casino_cage_animation_probe.json"))
    entries = motion_contract(report)
    metadata = json.loads(reader.read(contexts_dir/"__none_metadata.json"))
    typed = typed_mapping(metadata)
    bodies = [name for name in typed if name.endswith("_body.png")]
    adorns = [name for name in typed if name.endswith("_adorn.png")]
    require({p.name for p in contexts_dir.glob("__none_host_*_body.png")} == set(bodies) and
            {p.name for p in contexts_dir.glob("__none_host_*_adorn.png")} == set(adorns),
            "Physical typed mask membership must be exact10")
    fronts = sorted(contexts_dir.glob("__none_source_mode2*.png"))
    require(len(fronts) == 1, "Exactly one Base teller source_mode2 foreground required")
    mask_paths = fronts + [contexts_dir/n for n in sorted(bodies)] + [contexts_dir/n for n in sorted(adorns)]
    overlay = PNGImage(*SIZE, bytes(SIZE[0]*SIZE[1]*4))
    mask_hashes = {}
    for path in mask_paths:
        image = reader.image(path)
        mask_hashes[str(path)] = reader.hashes[str(path)]
        overlay = composite_rgba(overlay, image)
    allowed, candidate_proof = None, None
    if candidate_root is not None:
        allowed, candidate_proof = _candidate_contract(candidate_root, reader)
    rows, glyph_motion = [], []
    for entry in entries:
        ident = entry["id"]
        for mode in ("normal", "simulated_low_detail") if ident in LOW_IDS else ("normal",):
            prefix = "_low_" if mode == "simulated_low_detail" else "_"
            a = reader.image(motion_dir/(ident+prefix+"live_a.png"))
            b = reader.image(motion_dir/(ident+prefix+"live_b.png"))
            metrics = visibility_metrics(a, b, overlay,
                allowed_changed_pixels=allowed if ident == "cage_sign_pulse" else None)
            rows.append({"context": "__none", "mode": mode, "id": ident,
                         **{key: metrics[key] for key in ("surviving_changed_pixels", "maximum_channel_delta",
                                                         "visible_pixel_change_under_conservative_overlay")}})
            if ident == "cage_sign_pulse":
                glyph_motion.append({"mode": mode, **metrics})
    require(len(rows) == 36, "Exact36 Base visibility rows required")
    reader.finish()
    return {"status": "PASS" if all(r["visible_pixel_change_under_conservative_overlay"] for r in rows) else "REVIEW",
            "scope": SCOPE, "motion_evidence": str(motion_dir), "checks": 36,
            "mask_hashes": mask_hashes, "rows": rows, "input_hashes": reader.hashes,
            "source_contract": {"native_entries": 20, "default_low_entries": 16,
                                "Base_objects": 5, "typed_masks": 10, "teller_fronts": 1},
            "candidate_glyph_contract": candidate_proof, "sign_pair_metrics": glyph_motion,
            "method": "Integer straight-RGBA source-over, original overlay order, RGB max-difference histogram law.",
            "actual_clock_or_browser_claim": False, "read_only": True}


def visibility_report(motion_dir, contexts_dir, *, candidate_root=None):
    """Read inputs and return36 rows. Fresh use must supply exact candidate_root."""
    return _visibility_report(motion_dir, contexts_dir, candidate_root)


def historical_visibility_contract():
    """Recompute all36 retained R2 rows; exact reference equality is mandatory."""
    controls = {**CHECKERS, str(HISTORICAL_REFERENCE): REFERENCE_SHA}
    for path, value in controls.items():
        require(digest(_read(path)) == value, "Frozen visibility law/reference differs: " + path)
    expected = {}
    for name, value in HISTORICAL_INPUTS.items():
        group, filename = name.split("/", 1)
        parent = HISTORICAL_MOTION if group == "motion" else HISTORICAL_CONTEXTS
        expected[str(parent/filename)] = value
    expected[str(DECODER)] = DECODER_SHA
    reference = json.loads(_read(HISTORICAL_REFERENCE))
    result = _visibility_report(HISTORICAL_MOTION, HISTORICAL_CONTEXTS, expected=expected)
    require(reference["checks"] == result["checks"] == 36 and
            reference["status"] == result["status"] == "PASS" and
            reference["rows"] == result["rows"] and
            reference["mask_hashes"] == result["mask_hashes"] and
            reference["motion_evidence"] == result["motion_evidence"],
            "Stdlib recomputation differs from actual historical36-row Cage result")
    for path, value in controls.items():
        require(digest(_read(path)) == value, "Historical law/reference changed during read")
    return {"schema": "bth.cage_visibility_historical_reproduction/v1", "status": "PASS", "checks": 36,
            "exact_reference_rows_equal": True, "reference": {"path": str(HISTORICAL_REFERENCE), "sha256": REFERENCE_SHA},
            "law_and_reference_hashes": controls, "input_hashes": result["input_hashes"],
            "historical_authenticated_input_count": len(expected),
            "source_contract": result["source_contract"], "mask_hashes": result["mask_hashes"],
            "rows": result["rows"], "method": result["method"], "fresh_candidate_qualified": False,
            "scope": "Historical R2 Base reproducer only; caller must run fresh candidate visibility separately.",
            "read_only": True}
