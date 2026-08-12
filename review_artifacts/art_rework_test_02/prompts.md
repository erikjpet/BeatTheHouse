# Art Rework Test 02 — Generation Briefs

All source art was made with the built-in image-generation tool and then converted locally to the game’s exact raster contracts. The shared direction is an original retro coastal casino look: simple geometric construction, hard-edged pixels, calm resort architecture, cobalt/coral/ivory color, strong graphic light and limited detail. No specific artist was copied.

## Environment brief

Use the existing production image or live scene capture as the edit target. Preserve the exact first-person camera, ultra-wide composition, functional landmarks and open overlay zones. Restyle only the background with broad flat shapes, a limited palette and simple hard-edge pixel construction. Do not add UI, dynamic objects, item pickups, interaction labels, arrows or foreground characters.

### Beach invariants

Keep the horizontal sky/ocean/sand/deck bands, towel at left, umbrella near left-center, BEACH sign near right-center and slot kiosk upper-right. Leave the lower-left recovery zone, lower-right sand-pile zone and far-right exit zone empty.

### Jazz Club invariants

Keep the three-player stage across the left side, sax/bass/drums placement, three light cones, right-side bar shelves and pull-tabs zone. Leave the lower half dark and open for generated objects and labels.

### Grand Casino invariants

Keep the tall upper wall bays, left and right table masses, machine zones, central watch/aisle area and dark open lower third. Keep the scene restrained enough for generated machines, staff, events and travel arrows to remain legible.

## Item brief

Use each existing 32×32 icon as the silhouette reference. Recreate one centered item as chunky hard-edge pixel art on a flat removable chroma background. Preserve the existing angle and compact framing. Use navy, cobalt/cyan, coral, ivory and restrained gold. No shadows, text, UI or extra objects.

## Character brief

Use Pal’s prior model sheet as identity reference. Produce one front-facing full-body neutral pixel sprite with navy cap, teal jacket, ivory shirt, coral accent, navy trousers and ivory shoes. Keep the design readable at 64×96 and avoid props, labels or extra views.

## Conversion

- Environment sources were resized to `900 × 430` with nearest-neighbor sampling and reduced to 32 colors.
- Chroma-key item and character sources were converted to alpha PNGs.
- Items were resized to `32 × 32`, hard-alpha thresholded and mapped to the game palette.
- Pal was resized to `64 × 96`, hard-alpha thresholded and reduced to 24 colors.
