# Transition Plan for Independently Painted Endpoints

The Test 11 daytime images and Test 04 nighttime images are separate paintings. The transition should therefore use authored intermediate scenes rather than a palette interpolation.

## Proposed endpoints

1. Noon — the new full-color daytime painting.
2. Late afternoon — same scene with longer warm shadows.
3. Sunset — warm sky and reflected coral/gold light; practical lights begin activating.
4. Blue hour — darker sky and surfaces, first visible neon accents.
5. Midnight — the restored Test 04 neon night image.

## Registration rules

All intermediate images should reuse the Test 11 noon image as their direct edit target while also referencing the Test 04 night endpoint. The camera, major edges, doorways, windows, gameplay platforms and object footprints should be held as fixed anchors.

Before integration, register each keyframe to 900 × 430 and verify the anchor points. Use short cross-dissolves only between adjacent registered keyframes. Avoid a single direct noon-to-midnight dissolve, which would expose differences between the independently painted endpoints.

Animated overlays—water, signs, windows, reflections, ceiling fixtures, curtains, smoke and similar elements—should remain separate game layers. Their position and timing can stay fixed while their opacity, hue and emission change through the day cycle.
