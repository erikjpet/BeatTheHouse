# Environment animation translation ledger

Updated: 2026-11-14

The authored art packs preserve meaningful motion and atmosphere, not a literal PNG or manifest entry for every procedural draw call. Consolidation must be explicit and visually reviewed. Every new authored animation asset still needs an honest actual-runtime preview.

## Gas Station Casino: reflective floor light

After reading both source helpers directly, art direction approves the seven irregular floor-light movers in exact R12 as a consolidated translation of two older reflective-floor families:

- _draw_floor_sheen(): seven horizontal movers across rows274,288,302,316, with the original speeds and phases.
- _floor_reflections(): sixteen small lower-floor rectangles bobbing around y378, reduced to eight in the old Web low-detail path, plus static lower glint stripes.

The shared meaning is living light reflected on the floor. The authored interpretation retains moving low-energy reflection clusters on matte material and intentionally does not reproduce the raised-looking lower dash-marker treatment. It is not a claim of identical legacy positions, primitive counts or bobbing motion.

The seven movers retain their original common-sheen rows, widths, speeds and phases. No additional lower bob layer is required for this accepted floor interpretation. The full source inventory remains recorded here rather than silently treating the old helper as static.

This decision does not change the exact R12 bytes or sealed native PASS report:
- Package SHA-256: 1e9a88be562db041248d4561619d0110d0b267310f42be25acd362bfae64b560.
- Native PASS report SHA-256: dd456d9bf2bc564bde426fa459a3830808eacfa91b2d537252f0e1c15215c679.

Integration and TEST/Web verification remain separate gates.

## Corner Store: same floor-light family, different material palette

The same explicit consolidation is approved for Corner Store, using restrained mint/cream reflections appropriate to its matte shop floor. Do not copy Gas floorboards or neon colors.

This consolidation does not replace the room's other distinct motions: all ten overhead tube flickers, overhead scan, BEER and LOTTO pulses, moving register glint and four glass/metal sparkles must receive considered visible treatment. Two sparkles and the register glint require visible top-trim/glass placement because an opaque counter front would hide their old decorative positions. Counter contacts and live objects remain unchanged.

## Distinct motions in later rooms

This floor decision is not a blanket waiver for unrelated effects. Preserve and consider each room's background-clock expressions as well as its scene-life branch. Examples that remain distinct include:
- rain, puddle rings and practical-light breathing;
- river water and passing dock light;
- surf and distant boat motion;
- Motel Room bedding/bed-edge movement and CRT variation;
- House left-window breathing and upper-cabinet highlight movement.

Where two source passes describe the same river or surf surface, a coherent consolidated animation may be appropriate, but record and review that room-specific decision. Seed-selected palette colors are not animation.

For each later package, record meaningful source motions, the authored translation, any deliberate consolidation and the exact reviewed package identity. A moving clock or nonzero pixel difference alone is not proof that the result is visibly alive in the game or in the converted preview.
