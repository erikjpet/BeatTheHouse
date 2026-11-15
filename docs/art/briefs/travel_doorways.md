# Travel doorway replacements: source-only plan v1

Status: planning, not an image-generation release. House is the twentieth interior; these twelve doorway inserts are a separate unfinished Phase 10 deliverable.

## Contract and discrepancy
Read docs/todo/BTH_environment_art_layers_plan.md Phase 10 in the art worktree. Replace only existing doorway PNGs, preserving each exact path and actual pixel dimensions. No travel data, renderer, aperture, door geometry, actor path, timing, or gameplay changes. Update the three existing generation-note documents with exact hashes, tool/provenance and references. Current actual PNG dimensions and matching doorway_reference_size records override the plan's stale shorthand that calls all but Pawn portrait: Grand Casino and Kitty are landscape.

## Complete inventory and sequence
All paths are assets/art/travel/doorways/<id>.png.
1. gas_station_casino: 1024x1536; roadside utilitarian gambling room, match approved Gas package and GAS facade.
2. corner_store: 1024x1536; compact practical retail, approved store material/fixture identity.
3. bar: 1024x1536; neighborhood bar, approved bottle bay and worn timber character.
4. motel: 1024x1536; reception, not the separate guest room.
5. pawn_shop: 1086x1448; approved pawn retail identity, not generic casino.
6. jazz_club: 1024x1536; intimate music venue and approved warm material palette.
7. small_underground_casino: 1024x1536; Punchline PUBLIC comedy facade/interior, not the hidden gambling room despite ID.
8. kitty_cat_lounge: 1536x1024; approved pink/velvet/brass lounge.
9. grand_casino: 1536x1024; public floor only, not High-Limit/Cage/private office.
10. motel_room: 1024x1536; modest guest-room identity.
11. apartment: 1024x1536; reconcile external common entry with approved apartment interior; no invented direct room adjacency without reference review.
12. house: 1024x1536; settled plum timber and warm living-space identity.

No doorway is added for outdoor arrivals, Delta Queen, Beach, Back Alley or internal-only rooms. Do not change vehicle interiors in this scope.

## Visual direction
Each is a static decorative threshold glimpse, not a replacement gameplay layout or new animation pack. Reference BOTH the actual matching facade and finalized interior package in the current branch; use Delta Queen/Gas as crisp pixel craft references, not a universal room palette. Keep distinct venue materials and recognizable existing furnishings. Full-bleed opaque image, no baked outer entrance frame, door leaves, live characters, text, UI or gray void. Retain large readable silhouettes with crisp pixel clusters and localized bright color accents. Do not replicate game interaction labels or stock state.

The renderer uses bottom-aligned cover crop. Establish each actual aperture before its individual brief: leave a grounded unobstructed lower entry floor (starting recommendation 30–35 percent, subject to exact crop), keep identity features centrally visible, and avoid furniture at the player's threshold. Perspective must agree with exterior; no floating tables, raised rug lips or scale jumps. Exact original dimensions must survive final fitting; generated output can require controlled cropping/fitting recorded by auditor, never silent stretching.

## Dependencies and one-package loop
Native owner finishes House export before engine work. Pin the delivered twenty-room source and current travel data. First run existing doorway/entrance checks and capture baseline Gas open-door sequence and aperture, then inspect existing asset, facade, new interior and measured crop. Director freezes one-room brief; artist generates ONE retained source; auditor independently edits/fits and seals it; director reviews exact static; native owner tests isolated candidate; independent auditor approves actual opening/actor contact and video. Commit proof/notes/ledger with the package and publish cumulative TEST only under parent release. Continue one destination at a time. Do not claim existing PNGs are already the updated interiors.

## Proof and scope
Existing scripts/tests/travel_doorway_interior_check.gd covers twelve unique opaque assets, actual overlay loading, missing-art static fallback, closed-door equality, no changed pixels outside aperture, colored interior and independent bottom-aligned cover crop. It expressly uses synthetic visual fixtures, not legal-route proof. travel_entrance_view_check.gd covers hinges, double doors, crop, nearest filtering and front/back ownership. Preserve all checks; never weaken for new images.
Add bounded full cinematic capture for each changed doorway: opening, player approach/entry, leaf closure and automatic transition. Verify current methods reuse the same asset/crop; do not assert all methods validated from one walk-only synthetic fixture. Native owner selects smallest sufficient existing helper coverage, documents exact methods. Check timing unchanged and no seam/stretch/foot-floating at actual resolution. Native render tests are not browser proof; after cumulative TEST deployment inspect each of twelve entrances on TEST where reachable, recording synthetic vs real route distinctly. Original plan names NEXT, but current owner direction is branch/TEST only: do not deploy main/NEXT just to satisfy old wording.

Raw evidence stays E:/CodexQA/BTH; repository receives brief, concise proof/hash list and per-item status/commit. Keep original assets and failed candidates in recoverable provenance, no retiring code or Phase 11 work. Completion requires twelve accepted files, three updated generation notes, exact tested commit and verified TEST identity; any unreachable/repeated-travel/browser limits remain explicit.
