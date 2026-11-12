# Vehicle passenger cabin generation

Generated with the built-in image_gen tool on 2026-11-12 for the isolated travel prototype. Each PNG contains only a cabin insert, not a vehicle sprite. Existing vehicle images were inspected visually for palette, material, and passenger-side orientation; no source vehicle pixels were edited.

## Preservation and validation

The returned data URLs were retained in tool state, written as base64 evidence after storage admission, then decoded directly into each PNG. The final files preserve the exact returned PNG bytes. No resizing, cropping, painting, compositing, raster editing, or re-encoding was performed. Pillow was used only for read-only validation. Each file is fully opaque RGB. Requested square size was 1024x1024; the built-in tool returned 1254x1254 for both cabs, retained unchanged. Runtime owns masking and crop.

Each decoding/verification child ran through tools/bth_qa_guarded_run.py, with a fresh E: run, 12% aggregate CPU, 2 GiB Job memory, 4 GiB write budget plus 20 GiB reserve, explicit output paths, assignment before execution, and zero active processes at release.

- bus.png: 1024x1536, 2,220,684 bytes. SHA256: 9652255dcb99d999a251a1db5bd86f721eba01ac472905e60231e3b2257e4a7a
- taxi.png: 1254x1254, 2,233,768 bytes. SHA256: 099b0aea458cc63103ce415de759454ad895e5c8f80fc76a4333e6bfead564ef
- night_cab.png: 1254x1254, 2,071,526 bytes. SHA256: 16686b12fc47a323131a414f3f9c8ff9d31f4a847aad02e59bdf32963ab4a024

## Visual inspection

Bus: amber lamps, plum seat backs, yellow rails with teal reflections, and three ribbed rubber/metal entry steps. Intended for center/bottom cover crop into the tall bus entrance. The thick entrance rails are near image edges; a thinner interior rail remains near the center-left in a narrower crop.

Taxi: warm upholstered rear bench on the left, front-seat back on the right, seatbelt buckle, ribbed rubber floor mat, and amber trim with neon reflections. Night cab: distinct plum quilted leather bench and carpeted floor, with cyan/magenta ambient light. In both cabs the far-side inner trim and window belong to the cabin; there is no near-side exterior door or frame. No people or text.

## QA evidence

Evidence root: E:/CodexQA/BTH/runs/
- vehicle-cabin-art-bus-20261112-01/evidence/: storage admission, raw bus base64, decoder source.
- vehicle-cabin-decode-bus-20261112-02/evidence/: storage manifest, launch/job receipt, bus-verification.json.
- vehicle-cabin-art-cabs-20261112-03/evidence/: storage admission and both raw cab base64 payloads.
- vehicle-cabin-decode-taxi-20261112-04/evidence/: storage manifest, launch/job receipt, taxi-verification.json.
- vehicle-cabin-decode-nightcab-20261112-05/evidence/: storage manifest, launch/job receipt, night_cab-verification.json.

## Exact prompts

### bus.png

Use case: stylized-concept.
Asset type: fully opaque pixel-art cabin insert texture for a 2D neon-noir side-view game. Generate a NEW standalone image, not a vehicle exterior. Native portrait 1024x1536, 2:3 aspect.
Primary request: the passenger entrance interior of an empty vintage city bus as seen by someone standing just outside the open passenger entrance at street level. View into the warmly lit bus: three clearly readable black ribbed rubber and brushed-metal entry steps occupy the bottom 40%, yellow brass grab rails with subtle teal reflections run vertically beside the steps, and plum upholstered seat backs and a short glimpse of the central aisle are visible beyond the top step.
Composition: fill the entire rectangular image edge to edge with the interior. Important details centered inside the middle 65% of the image because a narrow portrait doorway crops both sides. Center and bottom crop must retain two bright yellow grab rails, horizontal step edges, and a recognizable seat back. Camera aligned approximately perpendicular to the side passenger entrance; plausible bus interior, not an ornate room or a long central corridor.
Style: detailed crisp pixel art matching richly shaded high-resolution 2D game vehicle sprites, visible square pixel clusters and stepped edges, restrained dithering, no smooth photographic rendering. Purple/plum upholstery and shadow, warm amber cabin lamps, subtle teal reflections, metallic wear. Readable midtones and bright edges, not underexposed. Keep the steps and rails distinct at tiny runtime scale.
Constraints: interior content only, fully opaque all the way to all four canvas edges. No bus exterior, no entrance door or door frame, no borders, no vignette, no people, no driver, no text, no signage, no logos, no UI, no watermark, no gray empty rectangle, no transparent areas.

### taxi.png

Use case: stylized-concept.
Asset type: fully opaque pixel-art sedan rear passenger cabin insert for a 2D neon-noir side-view game. Generate a NEW standalone image, native 1024x1024 square.
Primary request: a close side-on view into an empty vintage yellow taxicab's rear passenger compartment, seen from outside through the missing near-side rear door. The vehicle front is to the viewer's RIGHT, so the rear bench backrest sits toward the LEFT and its cushion extends toward the RIGHT. Clearly recognizable warm dark plum-brown upholstered rear bench, chunky headrest, ribbed stitched cushion, a little of the back of the front seat at far right, seatbelt buckle, dark rubber footwell and floor in the lower third. Visible interior trim with warm amber highlights. A restrained cyan/magenta reflected edge supplies neon atmosphere.
Composition: cabin fills the image edge-to-edge. Camera low and approximately perpendicular to the vehicle side, not facing backward from the front dashboard and not an exterior wide shot. Rear bench/headrest and floor must be legible within a square crop. Emphasize a simple readable seat silhouette and lit fabric details rather than empty darkness. Use warm dark purple shadows with honey amber cabin lighting, consistent with a richly shaded yellow taxi sprite.
Style: detailed crisp pixel art for a 2D game, square pixel clusters, stepped edges, restrained dithering and visible upholstery texture, not photography or smooth 3D rendering.
Constraints: only the interior, no near-side door panel, no door frame, no exterior bodywork, no wheels, no car silhouette, no borders, no people, no text, no sign, no UI, no logos, no watermark. Fully opaque entire canvas. No gray blank rectangle, no empty black void, no transparency, no panoramic scenery.

### night_cab.png

Use case: stylized-concept.
Asset type: fully opaque pixel-art luxury night-cab rear passenger cabin insert for a 2D neon-noir side-view game. Generate a NEW standalone image, native 1024x1024 square.
Primary request: close side-on view into an empty dark-purple luxury sedan rear compartment, seen from outside through its missing near-side rear door. The front of the car is to the viewer's RIGHT. Rear bench backrest toward LEFT, seat cushion projects toward RIGHT, with one large plush headrest, rich plum leather upholstery with restrained diamond quilting and stitched edges, a padded rear bench clearly readable across lower left and center, a cropped front-seat back at far right, and a recognizable carpeted footwell and floor occupying lower right.
Composition: edge-to-edge interior texture with no exterior rim. Low camera approximately perpendicular to the passenger side, not looking backward from the front dashboard. Side view of rear seat, no symmetrical lounge or limousine bar. Keep the seat silhouette, cushion, and floor visible at tiny runtime scale. A thin cyan light strip along the far interior trim and soft magenta ambient accents reveal the purple leather, balanced by a gentle warm amber dome light. Readable midtones, not crushed darkness.
Style: detailed crisp square-pixel 2D game art, stepped edges, subtle dithering, material texture, rich neon-noir purple/teal palette, not photographic or smooth 3D. More luxurious and cooler than an ordinary yellow taxi, but still a plausible vintage sedan cabin.
Constraints: only interior content. No near-side door panel, no door frame, no exterior metal bodywork, no wheels, no car outline, no border. No people, text, signage, logos, UI, watermark, drinks, objects on the seats. No gray placeholder, no empty black void, no transparency. All pixels fully opaque, all four edges filled by interior.
