# Inert Motel bed prototype V2

This packet is an unapplied, Motel-only painter and shadow-dispatch proposal. It implements the front-to-back geometry in the V2 design (`bb79e02c...`). No production GDScript, art, runtime, profile or save has been changed. The `.gd.txt` file is intentionally outside Godot discovery; do not rename or copy it into the D project.

The headboard remains visibly attached to the unchanged Sleep target. The mattress, real front foot rail and legs extend below that target. Selection highlights only headboard components inside the original hit rectangle, so it does not suggest that the extended mattress is clickable. Root must judge that usability in the early full populated view.

## Exact source admission

Only these full source forms are admitted:

- Canonical LF: `695359df463096a612c093160ab08169aa8aafe2729e16a400745e6375b1b0b2`, 555698 bytes.
- Current CRLF working copy: `c2ce2abee8827372d66fd6c9647a74e06f5db8fed520bbd812b8c7eb29f4af38`, 566959 bytes.

The canonical LF source is byte-identical to the retained capture canvas. C2CE versus 695359 is a newline difference. This packet does not accept arbitrary files that merely contain a matching function.

The replacement text is `bed_painter.gd.txt`, SHA256 `d830d061ca5e1c4daffd3d413c684c79ac3277df58f9cc2d0668b9f992ef074b`, 7503 bytes, LF. `source-patch.json` supplies all three exact preimages, byte offsets, replacement hashes and expected full output hashes. The legacy painter body remains byte-exact after the new admitted branch; the optional third parameter defaults to an empty dictionary for old callers.

The predicate requires all of: environment `motel_room`, ID `home_sleep:bed`, prop `bed`, `fixed_slot_geometry=true`, exact slot `fixed.home_sleep`, and actual native `Rect2(350,88,286,104)`. Both shadow dispatch and painter use the same predicate. Every other room, prop, bed or rectangle retains the original generic shadow and painter. No geometry epsilon or debug-JSON position parsing is used.

## Smallest later preview sequence

1. Root prepares a fresh, owned E QA source with the existing storage and capped-Job gates (4 GiB writes plus 20 GiB reserve, CPU 12%, memory 2 GiB). Authenticate its committed source/tree and full inert artifact blob/mode/bytes before overlay. Do not migrate a running workspace or profile.
2. Before any source write, authenticate one exact source form and every preimage. Assemble all three changes in memory, require the expected complete hash, then write only the fresh preview copy under the parent's guard. Record old/new hashes and byte spans in its receipt. No direct writer or executable launcher is included in this packet.
3. Pair the painter with the independently reviewed scoped Motel background companion. Only the BG may change under that companion; all 20 motion PNGs, full JSON/index and fixed model/label anchors stay exact. The material donor/companion is still pending. A view on the old background is an explicitly unpaired diagnostic, not a completed prototype.
4. Before capture, find the actual Sleep dictionary from `_active_scene_objects()`, keep native Vector2 position/size, obtain `_natural_model_rect_for_object()`, and require `_motel_bed_visual_prototype_admitted(...)=true`. A false predicate stops qualification; do not silently treat the legacy fallback as the new result.
5. Obtain an early actual full populated Motel view. Show unselected and selected Sleep, with the fixed hit rectangle separately visible in QA. Then compare matched-clock normal/Reduce Motion/low-detail views without pointer-driven animation. Inspect the entire bed, oversized headboard risk, Backpack and other actual props, rug/wood transitions and support shadows before doing more refinement.

Expected complete in-memory outputs are LF `cf1e0f2e7bed7255c0d8686d8b037fab34347bc57ca7d7932dafd26d48fa1ccd` (562059 bytes) or CRLF `3976df21b50788ef61a53fcc1bb3548633036aaff66187ceac415e1bf99c2b55` (573430 bytes). These are predictions from exact byte composition, not proof that a preview source was written, imported or run.

## Paint and remaining risks

The mattress is front-to-back, narrower and deeper than V1. Its pillow is at the far head end, blanket/seams advance toward the front, the right rail is longitudinal and the foot rail is transverse. The near feet end at native 610, with attached shadows through 618 on the original wood beyond the rug ending 588. Old feet 570/shadow 578/inside-rug margin claims do not apply.

The old generic detached bed shadow is explicitly replaced at the admitted bed dispatch. No structural rail hides it. Shadow patches overlap their own support bases; under-bed material remains visible. The old interaction-light function still receives the original rectangle once, with unchanged clock and selection behavior.

The source floor/backing allowance is only the existing V2 plan; no floor donor or art patch is supplied. The broad headboard can still dominate, and actual Base Backpack is mostly a marker rather than loaded-bag clearance. The 20-native-pixel TV bound gap is not an aisle certificate. No global House/Apartment calibration is inferred.

GDScript has not been imported, compiled or executed. No tests, engine, E writes, new art, asset/UID or runtime acceptance were performed. Root's owner hold remains active.
