# game06_1 runtime proof manifest

Implementation branch: `codex/game06_1-impl`

Frozen contract base: `a2760d81`

The accepted contract files and fixtures were not revised. The product runtime
implements the accepted `game_ritual/1` vocabulary through neutral shared code.

## Product inventory

- `game_ritual_schema.gd`: closed, versioned definition validation.
- `game_ritual_runtime.gd`: action-boundary phase execution, allowlisted host
  handlers, staged commitments, canonical request binding, receipts, typed fact
  publication, energy projection, and restore without replay.
- `game_ritual_layout.gd`: design-space, object, hit-region, z-order, text-safety,
  touch-size, overlap, and accessibility-equivalent validation plus semantic hit
  compilation.
- `table_game_visuals.gd`: opt-in actor and scene-object projection drawing.
- `game_surface_canvas.gd`: opt-in adapter from compiled pointer verbs to the
  existing exact, drag, and hold hit/capture machinery.

No shared implementation contains a game id, rules term, resource path, raw node
path, or reflection target. Rules and outcomes remain owned by sealed host
handlers. Existing game modules never invoke the new opt-in methods implicitly.

## Acceptance trace

`scripts/tests/game_ritual_runtime_test.gd` proves:

- the frozen worked example passes schema and layout validation;
- malformed phases, actors, objects, energy tiers, pointer equivalence, and
  out-of-design-space layouts fail;
- rejected and out-of-phase actions do not change authoritative state;
- place, correct, undo, confirm, and readable totals preserve staged sets;
- canonical replay is byte-identical, conflicting reuse fails, and a
  phase-changing confirmation cannot commit twice;
- an allowlisted rules handler advances the phase and publishes one typed fact
  at the action boundary;
- restore at the resolving boundary preserves authoritative state and replays no
  cue, reward, dialogue, or fact;
- acknowledgement returns to a legal phase and an energy tier changes an actor;
- ten deterministic input traces produce identical canonical responses and
  serialized state for native/Web-equivalent consumers;
- the pointer compiler and canvas preserve semantic pointer identity while
  reusing existing capture paths.

The same check is registered in the existing table-game surface contract path.

## Recorded gates

| Gate | Result | Duration/evidence |
| --- | --- | --- |
| frozen vocabulary contract | PASS | 72 negative fixtures; 7 neutrality targets |
| focused ritual runtime | PASS | direct Godot test runner |
| project validation | PASS | 49.5 s |
| GDScript load check | PASS | 26.2 s |
| all game module contracts | PASS | 10.98 s including load, 0 failures |
| game surface contracts | PASS | 18.3 s including load; check body 7.58 s, 0 failures |

The monolithic `foundation_games` wrapper was not used as the final evidence: on
this checkout it exceeded a 304-second outer process ceiling without producing a
report. Its two setup stages passed, and its two relevant registered checks were
then run directly through the generated foundation runner as recorded above.

## Consumer boundary

The frozen example re-expresses a table ritual entirely through declarations and
one allowlisted authoritative handler. Game-specific rules, RTP, outcome RNG,
and content remain consumer responsibilities; this row adds no game-specific
branch. Downstream Family 1 rows can adopt the shared runtime without editing its
neutral files.
