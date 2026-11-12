# Travel ground materials atlas

- File: `travel_ground_materials.png`
- Generated: 2026-11-11 using the built-in `image_gen` tool.
- Source: new generation; no reference image inputs.
- Image: 1774 × 887 pixels, native 2:1 aspect ratio, opaque 24-bit RGB PNG.
- Size: 1,462,221 bytes.
- SHA-256: `952f8f3bcbd95d48ef27edebda5f56dbcac4309ad6d21ddab3eb6b3993c78df7`.
- Preservation: the exact returned PNG bytes are saved without resizing, cropping, recoloring, compositing, or other image postprocessing.

## Sampling

The atlas contains three approximately equal-height full-width strips: asphalt at the top, concrete in the middle, gravel at the bottom. Use normalized source rectangles:

| Material | U range | V range | Approximate integer source rectangle (x, y, width, height) |
| --- | --- | --- | --- |
| Asphalt | 0.01–0.99 | 0.08–0.23 | 18, 71, 1738, 133 |
| Concrete | 0.01–0.99 | 0.41–0.56 | 18, 364, 1738, 133 |
| Gravel / packed earth | 0.01–0.99 | 0.75–0.90 | 18, 665, 1738, 133 |

Source UV rectangles expressed as origin and size are (0.01, 0.08, 0.98, 0.15), (0.01, 0.41, 0.98, 0.15), and (0.01, 0.75, 0.98, 0.15). Preserve the source pixel proportions when mapping these to the lower ground plane. Integer rectangles are rounded examples; normalized rectangles are the intended source definition.

## Visual validation

The full generated image and saved PNG were inspected. All three requested sampling bands contain only flat ground materials. No buildings, vehicles, people, stairs, fountains, foliage, curbs, lane markings, labels, or prop shadows appear. The concrete band contains two broad, low-contrast vertical slab seams, as requested. The strip boundaries are outside all requested sampling bands. The native image is opaque RGB. Exact horizontal edge equality was not guaranteed or validated; do not assume mathematically seamless tiling.

## Exact generation prompt

```text
Use case: stylized-concept.
Asset type: a clean replaceable ground-material atlas for a low-resolution pixel-art nighttime game cutscene.

Generate exactly one opaque PNG image with native 2:1 width-to-height aspect ratio, ideally 2048 by 1024 pixels. Fill the canvas edge to edge with THREE separate horizontal material strips of EXACTLY EQUAL HEIGHT, stacked directly on each other. Every strip spans the entire image width. Sharp material change at one-third and two-thirds height, with NO borders, padding, labels or separator graphics.

TOP THIRD: dark urban asphalt. Black-purple base with sparse coarse low-contrast pixel grain, a few restrained desaturated cyan and warm-brown microflecks. No road paint or other markings.
MIDDLE THIRD: muted dusty purple-gray concrete slabs. Even flat concrete, only a FEW broad slab seams in very low contrast. Huge simple rectangular slabs, far larger than paving bricks. No stripes, kerbs or added details.
BOTTOM THIRD: dark crushed gravel and packed earth. Low-contrast naturally clustered small pebble pixel texture, muted deep violet-black and warm charcoal-brown. No plants or objects.

View is a completely flat straight-on orthographic material swatch, not a landscape or scene. No vanishing point, no perspective convergence, no directional depth, no horizon. Each material stays even in scale, color, texture density and brightness throughout its whole strip. Prefer horizontally seamless left and right edges. Restrained nighttime black-purple, dusty lavender-gray, muted cyan and warm-neon reflected microtones matching a moody pixel-art street game. Crisp deliberate square pixels and small pixel clusters, no smooth photorealistic noise, no blur.

Critical functional requirement: this texture will be sampled across almost its full horizontal width using internal vertical bands y=0.08 to 0.23 for asphalt, y=0.41 to 0.56 for concrete, and y=0.75 to 0.90 for gravel. All those bands MUST contain only the flat ground material, absolutely no drawn objects or markings. Ground is the only subject.

Do NOT draw any objects, people, vehicles, buildings, windows, signs, neon signs, grass, flowers, trees, bushes, stairs, steps, fountains, drains, manholes, railings, lane lines, lane paint, road markings, curbs, cables, litter, silhouettes, footprints, cast shadows of props, text, letters, labels, watermark, frame, panel border or separators. No vertical walls, no 3D raised edges, no scenery. Three plain empty material swatches only.
```
