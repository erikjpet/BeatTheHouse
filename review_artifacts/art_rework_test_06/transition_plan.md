# Animated Day/Night Transition Plan

## Objective

Use the game clock to transition every environment between its aligned noon and midnight artwork. The world should feel alive while retaining hard pixel edges, stable architecture, readable interaction locations, and the existing animated overlay system.

## Endpoint behavior

- Noon endpoint: game minute 720 (12:00 PM)
- Midnight endpoint: game minute 0 (12:00 AM)
- Full daytime hold: 8:00 AM–6:00 PM
- Sunrise transition: 6:00–8:00 AM
- Sunset transition: 6:00–8:00 PM
- Full nighttime hold: 8:00 PM–6:00 AM

The schedule should remain data-driven so individual locations can open lights earlier or retain daylight later.

## Rendering method

1. Load the paired noon and midnight textures for the current environment.
2. Sample both with nearest-neighbor filtering and identical UV coordinates.
3. Calculate a `night_weight` from the current in-game minute using eased sunrise and sunset ramps.
4. Blend endpoint colors only; never interpolate positions, crop rectangles, or camera geometry.
5. Quantize the blended result in the environment shader to a small number of channel steps. This prevents intermediate frames from becoming smooth, blurry gradients.
6. Snap the environment surface and camera to whole logical pixels before the existing 2× presentation scale.

Recommended first implementation:

```text
06:00–08:00  night_weight eases 1 → 0
08:00–18:00  night_weight = 0
18:00–20:00  night_weight eases 0 → 1
20:00–06:00  night_weight = 1
```

Use a smooth cubic easing curve for time, followed by palette quantization. Do not use a soft-focus dissolve.

## Practical-light timing

Lighting should not be tied directly to the color blend. Add a separate `light_weight` so signs, lamps, windows, and casino fixtures can activate before the environment becomes fully dark.

- Exterior signs and casino neon: begin around 5:30 PM
- Interior practical lamps: begin around 6:00 PM
- Residential lamps: begin around 6:30 PM
- Dawn shutoff: stagger between 6:15 and 7:15 AM

The current endpoint differences can seed per-location light masks. Future masks should stay on the same 450 × 215 logical grid.

## Existing animated elements

Keep the current runtime elements above the background blend:

- interactable objects and labels
- game machines and table surfaces
- characters and patrons
- rain, puddle ripples, sparkles, scan bands, and sign pulses
- water shimmer and floor sheen
- selection lights, arrows, warnings, and outcome effects

Their colors can respond to `night_weight`, but their locations and animation clocks should remain independent of the background transition.

## Future intermediate art

After endpoint approval, create four additional aligned states from the same noon master:

1. `dawn` — cool navy shadows, pale cyan sky, warm practical lights still active
2. `morning` — softer daylight and longer shadows
3. `golden_hour` — coral/amber directional light with reduced neon
4. `dusk` — cobalt sky, magenta horizon, practical lights activating

These must be palette-and-lighting edits of the approved master, never independent architectural redraws. A later timeline can blend noon → golden hour → dusk → midnight and midnight → dawn → morning → noon.

## Integration path

1. Add paired background paths to the production art manifest.
2. Extend the environment snapshot with the current game minute or normalized day phase.
3. Update the environment canvas to load both endpoints and send `night_weight` to a pixel-preserving shader.
4. Add optional light masks and per-location timing offsets.
5. Verify every environment at 6:00 AM, 7:00 AM, noon, 6:00 PM, 7:00 PM, and midnight.
6. Test paused time, accelerated time, room travel, camera focus, and reduced-motion mode.

Reduced-motion mode should still update lighting when the game clock changes; it should only remove temporal shimmer or rapid palette stepping.
