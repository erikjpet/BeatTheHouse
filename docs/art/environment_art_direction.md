# Beat the House: environment art direction

Updated: 2026-11-14
Scope: all 20 production room-art identities, then 12 matching travel doorway images.
Status: active creative direction. A room brief is not approval of a generated asset.

## Current reference hierarchy

1. The owner's latest supplied Gas Station Casino screenshot is the dominant visual-design reference for the current Gas revision and a strong pixel-art/color philosophy reference for future rooms. Its SHA-256 is 0d804084cebfdd578ad79a479951bf65ba497be9257027fbd0b2182fb29dbbe7 (1280 x 720, 297331 bytes). The director and image-authoring/audit reviewers inspected the actual pixels.
2. Current Delta Queen travel facade artwork remains an approved reference for rich, convincing material detail and polished clustered pixel painting. Use assets/art/travel/exteriors/delta_queen.png and its matching backdrop. Foreground SHA-256: 4414fe5c94f850fb233c3f0e14cabed29291aac08b881823c12db4cdf4241767.
3. Each room's own current travel exterior supplies its local colors, materials and shared motifs. All 15 distinct exterior images serving the 20 interiors have been visually assessed. Carry two or three recognizable anchors into the interior without copying exterior layout.
4. README.md, the active content style guide, the two voice bibles, archetypes and environment UI data supply narrative and venue identity.
5. Current fixture drawings, placement surfaces and effective placement overrides supply geometry. Art must fit them, not move them.

The latest supplied screenshot requires substantial design fidelity, not a loose mood reference. Its preserved native material source is assets/art/environments/gas_station_casino/background.png in the original art-pass archive, SHA-256 afd2bab7d8c6300abda5ce26e5eefe13a807a6daabcacb30d704563397f69880. Reuse the authentic brick, column, floor and rim language substantially while retaining current fixed fixtures and authored fine detail. Exclude old baked characters, machines, UI, frozen effects and obsolete functional placement.

## What the owner is asking for now

The owner rejected the muted r9 treatment because it did not use a majority of the supplied design. Keep the current authored content and fine detail, but rebuild the material treatment with substantially closer fidelity and brighter color separation. The uploaded example has rich aubergine/pink masonry, sharply separated lavender-gray columns, compact honey-white lamp cores, crisp cyan/magenta trim, warm ochre booth details and a strongly readable violet floor.

Current Gas r7 through r9 retain useful detail and geometry but are too muted and gray by comparison. R10 is a surface/design rebuild, not another slight grade: broad vivid plum brick wall bays, decisive lavender-gray shadow/face/edge column planes, a full unmistakable gold/ochre cage border and bar facets, compact bright honey-white and cyan/pink lamp cores, rich purple highway glass, and a sharper reference-derived purple perspective floor. Preserve all real motion and fixed geometry. Quiet label-supporting material may remain dark. A global saturation wash, blur/sharpen pass, uniform grain, or crude low-color quantizer does not satisfy this direction.

This philosophy applies strongly to future designs, adapted to their own facades and narrative registers. It does not mean giving private homes the Gas Station's neon palette.

## The game's world and mood

README describes a single-player casino roguelike about surviving debt and heat, travelling between low-stakes rooms and the Grand Casino. It is a fictional simulation, not a real-money gambling product or a celebratory resort advertisement.

The active creative sources describe neo-noir on a neon budget: a late-night gambling town where technology advanced but the vices did not change. The house's control is expressed through polished courtesy; the street's lack of power is expressed through blunt practicality.

Visual applications are design inferences from those sources:

- Street rooms show tired functional materials, exposed utility and imperfect maintenance. They remain working places, not abandoned industrial ruins.
- House rooms disguise control as attentive hospitality: expensive materials, measured light, maintained symmetry and discreet boundaries.
- Seam rooms reach for courtesy with visibly worn objects. They are neither luxury resorts nor caricatures of poverty.
- Private homes provide a quiet contrast. Do not add surveillance or theatrical menace.
- The Crew Back Room is a special private, lived-in workspace. Its source explicitly says the ceiling stops counting.
- Future technology is ordinary furniture, not an attraction. No hologram spectacle or broad science-fiction laser.
- Seedy noir is not cruelty. Avoid demeaning caricatures, gore, sinister trophies or cartoon villain architecture.

## Visual language

- Make every material readable through a small set of deliberate local color planes, clustered shadows and placed hard highlights.
- Preserve the current fine forms, bevels, rivets, wood/brick detail and contact shadows.
- Keep clean stepped edges and an intentional pixel grid. Judge at the actual 900 x 430 board and in the real game, not only a large source image or smoothly scaled thumbnail.
- Use nearest-neighbor operations when normalizing assets. Preserve original generated files unchanged.
- Favor richer hue separation over gray-on-gray modeling. Saturated accents need dark, readable neighboring planes.
- Light cores can be bright and compact; halos should be restrained.
- Keep the background quieter than live objects and labels. Magenta and yellow labels must not land on similarly colored bright material.
- Do not add rectangular UI-like backing patches. Darken or simplify the actual supporting material coherently.
- Matte floors may have subtle material seams, perspective structure and small moving light reflections. Do not turn every floor into wet neon pavement.
- Local material palettes differ. Teal bar paneling, warm home timber, beach sand and Grand Casino gold must remain distinct.

## Live objects and immutable geometry

The live layer owns games and cabinets, people, sale items, drinks/services, lenders, scenario props, travel exits, labels and interactions. Do not bake duplicates into backgrounds.

Use these sources together:
- scripts/ui/pixel_scene_canvas.gd for existing physical fixtures;
- data/environments/placement_surfaces.json for authored contacts and foreground IDs;
- data/environments/developer_placement_overrides.json for effective current positions;
- exact background-only geometry guides and real same-snapshot previews.

The unoverridden fixed-slot table is not necessarily the current live layout. Gas and Corner Store both have significant effective overrides. Preserve those bytes and do not relocate an object to make art fit.

Guides contain removable annotations. Baked stock rectangles, crude card/player motifs, static rain, frozen scanner rays and procedural reflection dashes are not immutable architecture. Remove those before generation while preserving real supports and contacts. Freeze a guide path and hash after handoff; use a new versioned path for later corrections.

## File and layer contract

Each room is a fixed 900 x 430 board. Background PNGs are exactly 1800 x 860, opaque, pixel_scale 2. Rectangles, positions, speeds and counter contacts use board units.

Room manifest: data/art/environments/<environment_id>.json
Room assets: assets/art/environments/<environment_id>/
Background: background.png
Motion textures: anim/<name>.png
Counter fronts: counters/<foreground_art_id>.png

The manifest schema is bth.environment_art/v1. Texture dimensions must be twice the destination rectangle; frame strips are horizontal and every frame must meet that rule. Counter PNGs must match the exact mapped front rectangle plus explicitly declared bleed.

Layer order is background, authored animations, counter fronts, scenario wash, focus dim, live objects and overlays. Behind-counter people receive the identical counter-front replay. Scenario treatment stays tint-only.

Animations use the existing five types: frames, pulse, mover, scroll and sweep. Do not add per-room renderer code, change placements, camera, game rules, export settings or pipeline pins to accommodate an asset.

For a decorative glint hidden by the new counter layer order, use a visible top edge or adjacent glass treatment without changing contacts. Do not punch alpha holes through a solid counter to expose a light.

## Motion completeness and previews

Inventory motion in BOTH the room's background drawing function and its scene-life branch. Also preserve the common floor-light sheen. Seed-selected color choices are not motion.

Known background-clock examples include Corner Store fluorescent opacity, Motel Room bedspread/CRT motion, House window/shelf variation, Delta water and Beach surf. Redraw coherent motifs rather than duplicating redundant procedural passes literally.

Every entry must:
- animate without pointer input;
- remain active while placement tools are open;
- have a stable, appropriate Reduce Motion pose;
- respect applicable Web detail behavior;
- remain visually discernible in real rendering.

A nonzero clock or changing endpoint metadata alone is not proof of visible movement. The security sweep must visibly aim left and right; its tip must not disappear. Animated previews must show actual production-rendered motion, not pans, zooms, slides or preview-only amplification.

Show every real animated asset/motif. Use a 10-12 second room excerpt plus clearly labelled faithful crops when necessary. Longer wrap cycles can be checked with fixed-phase probes rather than making the owner watch a minute-long GIF. Preserve pixel edges and sufficient palette detail during GIF conversion.

The owner wants previews of failures as well as passes, with the revision and remaining issue stated honestly.

## Sequential production and release gate

Only one package is actively advanced through the art gate at a time. Reference collection and briefs for later rooms may be prepared in advance.

1. Inspect the room's facade, narrative sources, current guide, overrides and live composition.
2. Clean and freeze a geometry target.
3. Author sources using explicit geometry, local facade and shared treatment reference roles.
4. Normalize/assemble with original sources preserved.
5. Review a static exact-pixel candidate and an actual live animated preview.
6. Audit the exact sealed package and its file hashes: dimensions/alpha/schema, all motion, all relevant scenarios, current geometry/labels/hits, Reduce Motion, liveness and counter replay.
7. Only the exact passed package may enter the target art branch and TEST build.
8. Verify the served TEST identity and changed room. Do not call native evidence a Web or deployment pass.

Keep previously passed room IDs enabled when enabling the next room. Never let a one-room delivery index silently disable earlier packs.

Keep durable readable progress in GitHub commits on codex/environment-art-layers. Commit documentation and accurately labelled work-in-progress checkpoints without implying an unapproved asset is deployed. Do not change the audience or approved content scope. Keep old flat art and fallback code until separate retirement approval.

## Sources

- README.md
- docs/plans/content_style_guide.md
- docs/archive/0.5/plans/0.5_voice_bible.md
- docs/plans/0.6_voice_bible_world_register.md
- docs/plans/grand_casino_endgame_design.md
- data/environments/archetypes.json
- data/ui/environment_ui.json
- docs/art/environment_art_packs.md
- docs/todo/BTH_environment_art_layers_plan.md

See environment_room_briefs.md for all 20 room briefs and environment_art_progress.md for the current queue and feedback state.
