# Hiroshi Nagai visual study and game-art translation

This study identifies the broad, non-exclusive visual principles that make Nagai's landscapes effective and translates them into an original game-art system. It is not a recipe for reproducing a particular painting.

## Research findings

### 1. Graphic design and background painting come first

Nagai began as a graphic designer and also worked painting television sets and backdrops. That history helps explain why his scenes read immediately: architecture is arranged as a stage, silhouettes remain legible, and the image works at album-cover scale.

For the game, every environment therefore starts with large horizontal bands, a small number of dominant structures, and obvious empty stages for runtime objects.

### 2. Landscapes are constructed, not copied

Nagai has described working from architectural magazines, interior-design books, travel catalogs, and photographs, then remixing those sources into an invented landscape. Architecture and landscaping are edited for mood rather than documented literally.

For the game, each room is a functional remix of its gameplay coordinates: shelves, counters, doors, windows, risers, and stages are moved or redesigned so every runtime object has a believable physical home.

### 3. Light and shadow carry more weight than surface detail

Nagai repeatedly identifies light and shadow as central. Bright sun or artificial light is paired with large, nearly black shadow shapes. Those dark shapes simplify foliage, architecture, cars, and interiors instead of describing every small surface.

For this pass, the generated paintings were reduced to 40 colors at half resolution before being scaled to the game contract. Deep navy, violet, and black-blue masses suppress micro-detail; cyan, pink, coral, white, and amber are reserved for light.

### 4. Blue is structural; pink is an accent

The distinctive skies begin from blue, with lighter color layered from the horizon. Even sunset works usually retain a strong blue framework. Pink and coral become more effective when they interrupt blue rather than replacing it everywhere.

The game palette therefore uses:

- deep ultramarine and midnight navy as the environmental base;
- cyan or pale mint for cool illumination;
- magenta, fuchsia, and coral for selected light planes;
- warm amber or yellow for practical fixtures;
- dark, minimally described foreground silhouettes.

### 5. Stillness and empty space matter

Many images feel populated by a recent presence rather than by crowds: an empty pool, road, terrace, parked car, room, or skyline. The calm allows a small number of shapes and color relationships to dominate.

That principle is especially useful here because gameplay objects are added later. Backgrounds remain quiet where interaction sprites, labels, arrows, characters, particles, and animated highlights appear.

### 6. Tropical imagery is a motif, not a requirement for every scene

Pools, palms, beaches, roads, resorts, and coastal cities are recurring subjects, but the underlying grammar is broader: carefully staged modern architecture, deep blue atmosphere, sharp light/shadow contrast, clear horizons, and selective signs of leisure or city life.

Water is dominant only in `beach`, `delta_queen`, and the Grand Casino atrium. Other locations use inland streets, basements, domestic interiors, highway views, or city skylines. Jazz Club and Apartment may show a distant horizon, but the coast is not their subject.

## Game-art guardrails

1. Use three to five large value masses before adding any small feature.
2. Keep one dominant blue family throughout each scene.
3. Limit bright accents to a few functional locations.
4. Prefer a clean shadow silhouette over textured realism.
5. Make every runtime coordinate land on a shelf, counter, riser, doorway, alcove, rug, or clear floor patch.
6. Never paint runtime game icons, tables, machines, cards, chips, labels, arrows, characters, or animated effects into the background.
7. Keep water location-specific rather than using it as the default backdrop.
8. Treat the high-limit room, back room, and cage as distinct environments, not variants of the main Grand Casino floor.

## Sources

- Hiroshi Nagai interview, UT Magazine: https://www.uniqlo.com/jp/en/contents/feature/ut-magazine/s137/
- Hiroshi Nagai interview, HOUYHNHNM pages 1–3: https://www.houyhnhnm.jp/en/feature/361932/
- Japan Foundation, *Hiroshi Nagai: Paintings for Music*: https://sydney.jpf.go.jp/events/hiroshi-nagai-paintings-for-music/
- Hiroshi Nagai interview, Kaput: https://kaput-mag.com/stories_en/hiroshi-nagai/
- Official artist site: https://hiroshinagai.com/
