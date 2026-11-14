# Environment room briefs

Updated: 2026-11-14
Read environment_art_direction.md first. These are production briefs, not approvals of unmade assets.

There are 18 source archetypes and 20 production art identities: The Punchline has three layers, and the Grand Casino has four separate rooms. There are 15 distinct current travel exteriors serving those interiors. Do not invent a 21st production room from shorthand such as "20+".

Every room uses an opaque 1800 x 860 background on the 900 x 430 board. Read its current fixture guide, placement surfaces and effective developer overrides before authoring. Exact contact geometry is not replaced by this prose. Counter dimensions below are without bleed.

The shared owner-reference treatment means unmistakable crisp pixel-art construction, substantial deliberate material-specific color separation, defined pixel planes/contours, contrasting accents, compact bright saturated light cores and preserved fine detail. The owner rejected timid muted grading in the Gas revision. It does not mean global quantization or copying Gas colors everywhere. Keep real label backings quiet and all existing motion motifs visible in actual runtime. Every room also retains an appropriate common moving floor-light reflection.

## 01. Gas Station Casino — gas_station_casino

Register and purpose: Street; bright, cheap, watched. Scratchers, machines, road dust and a cashier reflected in cooler glass. A working converted roadside shop, not a derelict corridor or luxury casino.

Facade anchors: plum/magenta masonry; magenta canopy center bounded by cyan; warm amber tube cores and cool blue glass. Existing detailed utility architecture remains.

Current native-reviewed treatment, R12: the supplied screenshot must contribute the majority visual design, not only a muted color influence. Reuse its archived native source's crisp material patterns substantially beneath current detailed fixed fixtures. Rebuild broad wall bays as vivid plum/aubergine masonry with dark mortar; separate columns into strong lavender-gray shadow/face/edge planes; give the cage a full unmistakable bright gold/ochre perimeter and bar facets; use compact honey-white tube cores and cyan/pink/white fascia cores; enrich purple highway glass and reference-derived sharp perspective floor texture. Keep current fine details, all six motion motifs and exact layout. Preserve coherent dark material under live labels. Remove archived baked cast, frozen ray/headlight streaks and raised road-marker dashes. Judge the actual in-game image against the owner screenshot before calling it responsive. R9 was rejected. R12 passed the exact native art/technical gate; integration0c9eeec1 and bound TEST975a107d1484 are verified. Its final cleanup restored floor-joint continuity and the attendant ledge, made compact lamp cores warm-white, and uses a pale physical ledge/painted wall bay behind the dark-pink Parking Lot Tip glyphs. This is material treatment, not a moved label or new UI plate.

Fixtures: back wall ends at y248; soffit y34..70; fascia y70..78; columns x90/412/770, width22, ending y212; highway window [50,96,258,96]; service ledges y78 and166; cage [660,104,166,120]; camera origin [739,94]; utility rail [100,244,700,10] and supports; lower rail [100,400,700,8]. Do not add a new foreground desk or paint a person in the cage.

Counter: gas_station_staff_window [532,80,104,8], PNG208 x 16. Current Nell override contact is [742,200], not the unoverridden default [600,84]. Preserve both fixture and effective live geometry rather than moving Nell.

Motion inventory: magenta/cyan fascia pulse; three phase-offset fluorescent tube placements; clipped highway headlights; fluorescent scan; continuous narrow security sweep; seven restrained floor glints. All 14 manifest entries must remain represented in the current revision. Sweep must visibly aim left/right, without a disappearing tip or a frozen duplicate ray.

## 02. Corner Store — corner_store

Register and purpose: Street; fluorescent, quiet, watchful. An ordinary functioning low-cost shop, not a Gas industrial-room clone.

Facade anchors: purple masonry reveals, cyan/magenta stripe rhythm, cooler-blue glass, mint-white fluorescent cores, cheap cream laminate and steel.

Fixtures: preserve left shelf unit [42,64,258,148], shelf contacts y108/136/164/192; clerk recess [338,92,246,114] and crosspiece y142..149; full counter [338,206,286,48]; right cooler/support; low phone ledge [170,270,100,16] and legs; floor boundary y245; columns ending y238; clear side access. Do not interpret the clerk recess as an outdoor skyline window.

Counter: corner_store_register, PNG572 x 96. The foreground map is 286 units wide even though one old body drawing was only246. Never narrow the contact to match that old body.

Effective current override contacts include shop items [118,133],[231,135],[92,190],[176,189],[260,190]; clerk[449,227]; phone[374,202]; coin pusher[220,274]; Crew[696,290]; drink[684,183]; Numbers[598,203]; exit[868,390]. Read current data again before final capture.

Remove baked stock, giant bottles, flyer blocks, floor dashes and the old central clerk-like black block from the geometry target. Live inventory and the current clerk own those roles. Modest unbranded cardboard cartons may remain as quiet set-dressing in the existing right cluster.

Motion inventory: all ten overhead tube flickers from the background routine; overhead scan; BEER and LOTTO pulses; the moving mint register-top glint; four glass/metal sparkles; seven common floor lights. The original register glint is 22 units wide and moves from x372 to536 at roughly a one-second back-and-forth cadence. Because animations are below the opaque front, put its 1–2 unit visible core just above contact, around y203..205. Sparkles at [384,220] and [478,224] would be hidden inside the solid front; adapt them to visible trim or adjacent glass. The cooler sparkles at [668,138] and [746,144] remain distinct. Do not cut alpha holes through the front or move contacts.

## 03. Back Alley — back_alley

Register and purpose: Street; wet, electric, dangerous bargains. A real service alley, not a theatrical criminal lair.

Facade anchors: irregular dark-purple masonry, amber exposed bulb, cyan/magenta open-passage light, wet stone/asphalt and restrained reflections.

Keep the room's own table/crate/bin positions, not the exterior's right-side table location. Preserve central folding table[282,192,336,24] and legs, hanging lamp/wire, right crate front, side access and wall/floor boundary y236. Leave live sale bays empty; do not paint hooded cast or duplicate watch merchandise.

Counter: back_alley_crate_display [638,168,208,50], PNG416 x 100.

Clean-target annotations to remove: old static rain lines across the canvas, five colored table-stock rectangles at x334/388/442/496/550,y172,36 x 20, and bottom reflection dashes. Keep actual supports.

Motion inventory: bulb pool/cone breathing, rain, low rain-light streaks, puddle rings, sparse warm glints and common floor light. The old decorative glint at [792,174] falls inside the crate front; place its adapted highlight on visible upper trim, without an alpha hole or contact change. This location may be wet; its wetness must not become the default for homes or every shop.

## 04. Motel lobby — motel

Register and purpose: Street; quiet, pink, temporary. A tired lobby where recovery, rooms, rumors and buses meet. It must remain distinct from the paid private Motel Room.

Facade anchors: faded rose/plum plaster and brick base, oxidized teal coping/metal trim, honey curtain/lantern warmth, pink vacancy light.

Materials: worn low-cost veneer, faded upholstery, cool CRT glass, modest phone/service surfaces. Keep existing table, merchandise counter, door and low phone support. Avoid polished hotel luxury.

Counters: motel_lobby_table PNG520 x 104; motel_merchandise_counter PNG340 x 80.

Motion inventory: motel/vacancy sign pulse, TV static/scan and light bands, small glass glints and common floor reflections. No baked caller, clerk, card dealer or live merchandise.

## 05. Bar — bar

Register and purpose: Street; noisy, loose and local. A worn dive with warmth and gossip, not a refined velvet lounge.

Facade anchors: weathered DEEP TEAL painted paneling, burgundy timber, amber patterned/rippled glass, pink BAR neon.

Materials and fixtures: scarred warm brown-red counter, teal/indigo bottle-mirror surroundings, green pool felt, existing stools, booth and dartboard. Keep all current supports. Do not fill live service surfaces with a second painted drink stock.

Counter: bar_main_counter PNG1096 x 112.

Motion inventory: DIVE/beer sign breathing, tiny existing pool-ball movement, thin high smoke, glass glints and common floor light. Keep practical pools warm and localized; avoid generic purple-brick substitution.

## 06. Pawn Shop — pawn_shop

Register and purpose: Street; quiet, barred, fluorescent. Sal's transactional room of repairs, goods and mistakes.

Facade anchors: violet/plum masonry, cold cyan-lit barred glass, aged yellow/gold sign framing.

Materials: mismatched old wood, dusty glass, dull metal and security mesh. Retain counter, estate shelf and separate display bays. Do not bake the exterior's guitar/camera/jewelry into live sale slots, or turn the room into a luxury jeweler.

Counters: pawn_counter PNG536 x 84; pawn_estate_shelf PNG492 x 56.

Motion inventory: sign pulse, mesh/glass scan, display/practical pulse, very thin high haze, sparse metal glints and common floor light.

## 07. Jazz Club — jazz_club

Register and purpose: Seam; late-1960s, amber, funky and late. An intimate Blue Note music room, not a disco or generic nightclub.

Facade anchors: plum brick, cobalt-blue edge light, orange-gold curtains, warm brass lamps and red timber.

Materials and fixtures: walnut panels, existing low wood stage, gold/copper curtain folds, dark warm tables and bar. Preserve stage/bar/surface geometry. The live band owns its musicians and instruments; do not paint duplicate players.

Counter: jazz_bar PNG568 x 96.

Motion inventory: existing sign pulses, restrained high smoke/light atmosphere, brass/glass glints and common floor light. Any added practical breathing must stay slow and musical, not a stage strobe. The old decorative glint at [704,196] falls inside the solid bar front; adapt it to visible upper trim or glass, without alpha holes or contact changes.

## 08. Punchline public Comedy Club — punchline_club

Register and purpose: Seam; thin, hopeful, performing. A tired public stage with a two-drink minimum and a plain side door.

Facade anchors: purple brick, amber marquee bulbs, red timber/plain door, small cyan/magenta stepped trim.

Preserve current stage, microphone support, round tables, worn wine curtain and unobtrusive side-door geometry. No visible hidden casino floor, painted comic/crowd, or new theatrical props.

Counter: none.

Existing minimum motion is the common floor-light motif. Optional restrained stage practical/sign breathing or faint dust may be added as authored layers, clearly distinguished from preserved legacy motion. Keep the public cover visibly separate from the underground and Crew layers.

## 09. Punchline Hidden Casino — small_underground_casino

Register and purpose: Seam; tight, pink and dangerous. Low voices and better tables below the public performance.

Facade continuity: share the building's plum masonry/red timber and a faint inherited pink/cyan access spill, but low beams, green felt and amber string bulbs establish the hidden basement.

Preserve existing table and cart/door supports and low ceiling. Do not copy the public marquee room, add a luxury poker den, or bake live games/cast into the image.

Counter: punchline_right_table PNG572 x 196. Keep the left table's existing physical fixture too.

Motion inventory: low drifting smoke bands, high haze, independent string bulbs, sparse glints and common floor light.

## 10. Punchline Crew Back Room — punchline_back_room

Register and purpose: lived-in private Crew space within the Seam venue. Rook's room has a shut door, low warm lamp, friendly felt and work waiting nearby. The source says the ceiling stops counting.

Facade continuity: subdued red timber door, plum structural tones and warm lamp hardware, not public neon spectacle.

Keep planning table, job-board support, Numbers desk, Mags bench/rig supports and existing door. Live events/characters own their offers and actions. Do not paint Rook, job rewards, playing hands or a second practice rig on top of live hosts.

Counter: none.

Existing minimum motion is the common floor-light motif. Optional low lamp breathing and faint dust may be added. Do not add surveillance, camera rays or a smoke blanket.

## 11. Kitty Cat Lounge — kitty_cat_lounge

Register and purpose: House; velvet, champagne and attentive stage-lit courtesy with a hook.

Facade anchors: wine/burgundy velvet, pink scalloped gold-edged canopy rhythm, honey lamps and the existing cat/champagne sign language.

Keep current stage, booths, champagne bar and live game clearances. Echo the scallop/curtain motif in existing valance geometry, not a new canopy across the room. No explicit cast, crowd, new cat statues or extra live-host duplicates.

Counter: kitty_champagne_bar PNG536 x 96.

Motion inventory: sign pulse, thin high pink/cool atmosphere, small candle-like floor/table light variation, restrained glints and common floor reflections. Control bright accents so the room reads as maintained hospitality rather than garish spectacle. The old decorative glint at [704,236] falls inside the solid bar front; adapt it to visible upper trim or glass, without alpha holes or contact changes.

## 12. Delta Queen — delta_queen

Register and purpose: House; river, brass, practiced courtesy and a temporary lack of exit. A mid-stakes vessel, not a generic brown tavern.

Facade anchors: white/cream painted structure with magenta edges, honey windows, brass rails, red/burgundy timber and deep teal river context.

Retain warm varnished wood and green felt, but make cream structural trim and selective magenta accents visible. Preserve all table, window, rail and boarding/access geometry. Do not paint the exterior boat or an extra paddlewheel inside the room.

Counter: delta_right_table PNG540 x 184.

Motion inventory: sign breathing, both authored water/ripple motifs translated coherently, passing dock light through correct openings, sparse brass glints and common floor light. Do not add water beneath live walkable actors merely to make the room feel nautical.

## 13. Beach — beach

Register and purpose: Seam recovery; salt, neon, quiet and open air. The outdoor scene is its own facade.

Anchors: tawny warm sand, amber weathered timber boardwalk, cyan surf/foam, a modest distant pink pier.

Keep towel stall, access and boardwalk supports. No resort casino, new tables, tropical pool or generic purple indoor floor. Dry sand should not mirror neon like wet asphalt.

Counter: beach_towel_stall PNG340 x 72.

Motion inventory: coherent surf motion from both old drawing paths, small distant boat, restrained BEACH sign pulse/glints and common moving light adapted to timber/sand rather than neon stripes.

## 14. Grand Casino Main Floor — grand_casino

Register and purpose: House boss destination; polished, watched, expensive hospitality. The institution can afford gracious control.

Facade anchors: plum/magenta panels, disciplined broad gold framing, warm chandelier-like practicals and small cyan edges.

Preserve actual machine bays, two table supports, host station, kiosk/cocktail supports and room doors. Live machines and staff remain separate. Use current detailed pixel treatment, measured symmetry and clearly separated green felt/gold/plum materials, not a blue-gray arcade or chaotic treasure hall.

Counters: grand_table_left PNG544 x 72; grand_table_right PNG544 x 72; grand_host_station PNG424 x 96.

Motion inventory: architectural lamp pulses, title/sign glow, sparse expensive glints and common floor reflections. Respect the existing Web detail/cadence path.

## 15. Grand Casino High-Limit Room — grand_casino_high_limit

Register and purpose: House; hushed velvet and exact attention. Bigger stakes with less noise.

Facade continuity: the same plum/gold/amber institution, deepened into quieter velvet, polished trim and fewer light pools.

Keep the exact two-table support geometry and private central desk. Do not inherit the public machine bank, cocktail shelf or HOST identity. No unrelated hotel-lobby décor.

Counters: grand_table_left PNG544 x 72; grand_table_right PNG544 x 72.

Motion inventory: restrained practical/sign breathing, sparse highlights and common floor light. Preserve the old room's meaningful ambient motifs without public-floor spectacle.

## 16. Grand Casino Back Room — grand_casino_back_room

Register and purpose: the purest House voice; private, still, final. Rourke's polite certainty, not a horror interrogation room or a private refuge.

Facade continuity: immaculate dark plum/wood, restrained brass/gold institutional detail and one controlled warm practical.

Preserve table/desk fixtures and guarded routes. No crowd, violent trophies, giant surveillance display or new dramatic spotlight. Keep clear green felt and the existing private OFFICE identity rather than public HOST signs.

Counters: grand_table_left PNG544 x 72; grand_table_right PNG544 x 72.

Motion inventory: the existing low-energy lamp/sign variation, tiny highlights and common floor light, treated with the lowest visual energy of the public House rooms.

## 17. Grand Casino Cage — grand_casino_cage

Register and purpose: House spoken at the Seam; barred, private and cold-lit, with Linda's warmth behind glass.

Facade continuity: restrained plum/gold lintel, threshold and counter metal ties it to the Grand. Colder cyan glass, gray bars and warm ledger/task light keep its service identity distinct.

Keep three teller openings, trays, gift-case supports, separated ATM and return door. Leave live stock bays empty of baked offers. Linda remains the existing featureless live silhouette; never paint a face or second body.

Counter: grand_cage_teller_counter PNG776 x 112.

Motion inventory: sign pulse, terminal scan, moving bar reflections and common floor light. This is not a pawn shop or a flashy public machine room.

## 18. Private Motel Room — motel_room

Register and purpose: Private; cheap, buzzing and temporarily quiet. A paid pause behind thin walls.

Facade anchors: faded plum/rose plaster, minor teal-painted trim, honey curtains/lamps and burgundy door tones.

Preserve existing bedding, TV, rug and storage supports. Keep it separate from the lobby. No added camera, watcher, lender or theatrical menace.

Counter: none.

Motion inventory: outside sign spill, CRT scan, tiny bedspread movement and bed-edge light variation, plus common floor light softened to warm domestic material. No gratuitous full-room neon wash.

## 19. Apartment — apartment

Register and purpose: Private; a compact city walkup with better locks and softer silence.

Facade anchors: purple-brick window/door reveals, warm cream curtains/lamps, muted plum furnishing/wood and modest black-iron/stone details.

Keep sofa, print, floor lamp, kitchenette/fridge and rug anchoring current belongings. A dark matte domestic floor replaces nightclub shine. Do not add a skyline window beyond the current one, cameras or billboard neon.

Counter: none.

Motion inventory: existing window-light pulse, very thin light/dust atmosphere, kitchen/warm-band variation and common floor reflection adapted to household light. No invented smoke source.

## 20. House — house

Register and purpose: Private; old timber, thin light and an earned roof still carrying payments. Modest, worn, warm and calm.

Facade anchors: weathered plum timber, amber curtain/porch warmth, orange-brown wood and a small natural-green garden cue where an existing view/print allows.

Preserve all sofa/table/cabinet/storage supports. Do not turn it into a mansion, casino room or surveillance set.

Counter: none.

Motion inventory: existing window/light pulse and alpha variation, tiny shelf-object/highlight movement, faint warm light/dust and common moving floor light. Use warm cream/amber material glints, not Gas neon streaks.

## Later doorway phase

After interiors settle, replace the 12 existing travel doorway PNGs at their existing paths and sizes: 1024 x 1536, except pawn_shop at1086 x 1448. Match accepted interior materials/light at the threshold. Keep travel geometry, doors and code unchanged. This is a later coordinated phase, not permission to retire old sources.

## Per-room execution checklist

Before advancing any queued brief:
- re-read current geometry and effective overrides;
- inspect that room's actual facade and background-only guide;
- remove live-stock/cast/frozen-motion annotations;
- preserve and inventory all meaningful legacy motion, including common floor light;
- create a sealed exact-size package and actual-motion preview;
- verify label contrast, counter replay, scenarios, Reduce Motion and no-input liveness;
- record current owner feedback and exact audit scope;
- only then integrate the exact passed package and verify TEST.
