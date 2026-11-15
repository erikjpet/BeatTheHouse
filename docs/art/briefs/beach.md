# Beach execution direction v3

2026-11-15. Queue room 13. FIRST SINGLE SOURCE RELEASE. Director personally inspected all four current actual scenes, own facade, original geometry guide and exact cleaned guide. This is permission for one source generation, not art acceptance or deployment.

## Theme and style

Night beach below casino docks: salt wind, heat kept low, quiet neon and informal refuge. Current exterior reference assets/art/travel/exteriors/beach.png supplies tawny amber sand, vivid cyan/teal surf, dark red-brown boardwalk, deep navy night and localized magenta/amber practical accents. Use approved Delta Queen pixel craft and owner Gas reference's crisp material planes, rich differentiated hues and fine details, not those rooms' palette or furnishings. No generic purple wall, road, velvet lounge, new pier building, fence, lamps, grass or casino tables. Existing live scenarios own bonfires, people, beach rental props and festival structures.

## Exact geometry and contact

Board 900x430; opaque 1800x860 background, pixel_scale 2, exact nearest-grid fitting. Do not change runtime, labels, actors, placements, contacts, camera or rules.
- Sky/night band 0..80. Retain quiet static far light strip rhythm at x18+120i,y26,64x8 pink and x40+120i,y42,84x6 cyan. No added horizon landmark.
- Sea [0,78,900,112]; sand begins180. Boardwalk [0,238,900,78] with top edge238 and existing seam rhythm. Source static sand marks near184 stay distinct from removed wave helpers.
- LOWER316..430 must become grounded dark tawny/umber sand, continuous usable shore beneath actual Sand Pile, exits and Festival vendor/stalls. No water pit or new platform. Use quiet granular planes with localized amber grains, not bright yellow floor that fights names.
- Storm's Late Swimmer is intentionally in existing shallows; keep dark teal source water there, no dock under actor and no coordinate changes. Other shoreline actors retain current placement.
- Towel stall [76,198,170,36], foreground beach_towel_stall, exact340x72 opaque replay without bleed. CURRENT SOURCE AND ACTUALS HAVE FIVE cloth blocks: x88,122,156,190,224; y206; size20x20; purple/teal/pink/purple/teal. Auditor verified all five guide pixel centers100/134/168/202/236,y215, with last panel224..244; image thumbnail made its count ambiguous. All five are present. Current source mode2 frame is exact foreground authority; guide pink green-channel differs by one rendering value (33 versus34), which is a provenance detail, not absent cloth. This is existing decoration, no extra merchandise or painted shopkeeper. Exact wooden front and top edge preserved.
- Umbrella polex300,y198..272; outer pink canopy300,198/248,232/352,232; inner cyan300,198/270,238/330,238. Preserve silhouette and fabric panel count, pole support; no chairs or new table beneath it.
- Fixed BEACH sign [616,192,130,42], title634,220,size21. Keep exact text and position. Festival cable stage partially overlaps it in actual baseline; do not move either to solve art visibility.

## Quiet material for actual labels

Gold Sand Pile x686.9..751.1,y322..337 and Festival Stall vendor16..80.8,y387..402 need dark tawny ground. Lost child80..150,y236..251 lies near boardwalk boundary. Pink Storm-Watching Stranger699..825,y296..322 needs quiet wood-to-sand material. Cyan Craft stall87.1..162.9,y337..352 and Food stall188..258,y337..352 must read on lower sand. No small label-sized plates or runtime label changes.

Water/sky titles include Slot137..185,y112..127; Night swimmers327.4..420.6,y98..113; Late swimmer218.2..299.8,y64..79; Rising tide marker575.8..692.2,y120..135; Storm warning flag717.8..834.2,y101..116; Festival stage615..741,y136..162. Keep broad sea planes dark enough and animated highlights restrained so these cyan/gold names remain clear. Foreground shoreline signs/props can overlap as in source; no invented clearance.

## Motion contract

Retain two EIGHT-wave families, not just eight waves total. Background: y90+13i+int(sin(1.1t+i)*2), diagonal-8,alpha0.14. Scene-life: y92+13i+int(sin(1.6t+i)*4),diagonal-8,alpha0.12. All16 should be separate/factually accounted motifs; whole-line four-pose pingpong translation can use compact7200wide atlases as Delta, preserving period/phase/amplitude and documenting approximation. No endpoint pivot substitute or oversized atlas. Do not bake transient wave lines into static background; quiet underlying surf texture is allowed.

Moving distant boat source x=int(fmod(t*16,980))-80, hull64x9 at y72,amber0.26; cabin28x16 atx+16,y56,pink0.20. Preserve single coherent horizon-crossing boat and cabin silhouette, no additional vessel/animation/prop. Three warm glints128,96;448,96;744,96,alpha0.12 are sea reflections, not new lamps. Seven common floor-light movers remain represented on grounded surfaces, no frozen duplicate floor-helper dashes.

APPROVED SIGN ADAPTATION: source sign pulse was an unrelated translucent sky rectangle[650,66,132,44]. Move that one motif to the EXISTING BEACH sign/glyph at its fixed physical location, using original yellow strength0.12 and speed4.2 cadence. Document coordinate translation; do not create a new sign/sky box or boost opacity. Actual sign can be partly covered by Festival stage as source; ensure remaining glyph pixels change visibly. Expected28 entries if16waves+1combined boat+1sign+3glints+7floor,29 if boat/cabin separately represented. Actual visibility, not count alone, is required.

## Exact reference release and baseline

Use geometry image1 E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/guides/beach_clean_geometry_v1_1800x860.png SHA3c68381fa8c1cdc9cfe93cc35d0fb62c66d694b5031e368dc6c836afbdc37ea0. Only eight frozen BACKGROUND sea waves and lower commonfloor helpers removed; original above156 and360..631 native pixels unchanged. Other eight SCENE-LIFE waves were never in this guide but remain required. Director personally viewed guide. Five-panel current source and guide identity has been pixel-verified; use exact replay dimensions and source mode2 as final authority.

Current source04861/c5 captured Base, Bonfire Night, Storm Coming, Festival Weekend:14,899 checks,zero findings,29distinct IDs,38selected/typed pairs;7283 sourcefiles+c5 unchanged. Exact union E:/CodexQA/BTH/runs/BTH-ENVART-BEACH-20261115-union-01/evidence/beach_preart_union.json SHA8d8c506e3b23bd510fb259fec1f301ecea02ba93e14e037725c1688da48516a9. All four full-app actuals personally reviewed. These are constructed initial contexts, not later lifecycle/player progression/save/revisit proof.

Artist may generate ONE reference-locked source; preserve PNG bytes/prompt/hash immediately. Auditor owns precise module fitting, exact five-panel replay, independent material/geometry/motion review and corrections. Native owner owns isolated tests, Git checkpoint and art-branch TEST integration after exact PASS. No main/NEXT changes or concurrent export. All motifs must survive four-context counter+typed actor masks, Reduce Motion stable, original no-pointer liveness preserved, truthful actual-motion preview. Raw evidence on E:/CodexQA/BTH, concise proof/hash/ledger commits only.

Revision note: v2 was an unissued diagnostic draft that incorrectly described a missing fifth guide panel based on thumbnail appearance. Pixel verification corrected that in this v3; no image or geometry edit is needed.
