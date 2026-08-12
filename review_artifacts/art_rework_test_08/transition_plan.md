# Revised Day/Night Transition Plan

## Approved direction

- Midnight visual master: exact Test 04 artwork
- Daytime color reference: current Test 06 noon set
- Production geometry master: Test 04 midnight composition

The Test 04 night artwork supplies the correct filled shadows, reflected neon, material color, environmental detail, and atmospheric depth. Future time states must preserve this structure rather than reducing it to outlines or applying a global palette transform.

## Required geometry-alignment pass

Before the final continuous animation is implemented:

1. Lock each Test 04 night image as the environment's immutable geometry master.
2. Create the final noon image as a lighting and palette edit of that master.
3. Preserve every wall, platform, doorway, window, reflection boundary, furniture silhouette, and gameplay bay.
4. Keep the same 450 × 215 logical pixels across all time states.
5. Generate intermediate states from that same master only.

This prevents ghosted architecture, shifting platforms, or double furniture during texture blending.

## Planned time states

1. `midnight` — restored Test 04 art
2. `dawn` — dark navy/magenta room with a pale cyan horizon and practical lights still active
3. `morning` — softened daylight, reduced neon, visible local materials
4. `noon` — restrained colorful daytime state, never high-key white
5. `golden_hour` — coral and amber directional light with long graphic shadows
6. `dusk` — cobalt sky, magenta horizon, practical lights activating

## Game-clock schedule

```text
00:00–05:30  midnight
05:30–06:30  midnight → dawn
06:30–08:00  dawn → morning
08:00–11:00  morning → noon
11:00–16:30  noon
16:30–18:00  noon → golden hour
18:00–19:30  golden hour → dusk
19:30–21:00  dusk → midnight
21:00–24:00  midnight
```

## Pixel-preserving animation

- Sample every state with nearest-neighbor filtering.
- Use identical UVs and whole logical-pixel camera placement.
- Blend only aligned lighting states.
- Quantize intermediate shader output to prevent smooth gradient drift.
- Keep runtime objects, labels, characters, particles, rain, water shimmer, floor sheen, and interaction highlights above the background blend.
- Give practical lights a separate activation curve so lamps, windows, and signs can turn on before full night.

## Interim behavior

Until the aligned daytime master is produced, use a short pixel-dither dissolve when switching between the current noon concept and restored midnight artwork. Avoid a slow transparent crossfade, because it would reveal the separately drawn geometry.
