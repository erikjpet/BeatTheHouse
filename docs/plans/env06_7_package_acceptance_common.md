# env06_7 Package Acceptance — Common Checklist

Status: fixed before package implementation

Applies to every `env06_7` archetype package and the assembly candidate. The
full row prompt remains binding. Package checklists add identity-specific proof;
they do not replace this checklist.

## Authority and ownership

- [ ] The candidate cites the exact accepted `env06_6` implementation and
  vocabulary head. Package code uses only authenticated public commands, facts,
  operations, projections, seals, and receipts.
- [ ] Established scenario ids, weights, rumor anchors, compatible
  consequences, and selection behavior are inventoried before edits. A change
  has a logged code-reality reason and compatibility test.
- [ ] One squad owns each complete archetype. No archetype is split across
  squads and no file has two writers.
- [ ] Package squads own only uniquely assigned scenario definitions, dossiers,
  focused fixtures, and captures. The assembly owner alone owns shared catalog
  indexes/loaders, cross-catalog tests/reports, and any monolithic catalog file.
- [ ] env06_6 runtime/schema/renderer files remain with the env06_6 owner.
  Crew/world models and the EventModule crew seam remain exclusively with the
  parallel former-PM lane. `main`, the board, assignment order, Gate Service,
  and Review Pool records remain program-director property.
- [ ] Shared-file needs are handed to the recorded owner as an adapter request;
  a package never edits around ownership.

## Per-scenario dossier and sequence

For every assigned id:

- [ ] A machine-readable dossier binds id, archetype, exact definition path,
  phase graph, terminal branches, object/actor/interactable diffs, player verbs,
  objectives, world-system connections, reentry/cleanup, signature, seeds,
  tests, and capture ids.
- [ ] Arrival is identifiable without title, sign text, tint, music, or an info
  panel and differs materially from the base room and sibling variants.
- [ ] At least two semantic objects/actors change across the sequence and are
  real in prepared render, hit, route, or interaction state. Metadata-only props
  fail.
- [ ] The graph has arrival -> complication/opportunity -> branch aftermath,
  at least two consequential player/world action boundaries, and public
  diegetic objective progress.
- [ ] At least one scenario-specific interaction or altered core task exists.
  Cash/item/flag/reputation grants are not the primary verb or entire sequence.
- [ ] Meaningful success, failure, refusal/ignore, interruption, and clean-exit
  behavior are reachable.
- [ ] At least two outcomes differ materially in space, actors, interactions,
  services, routes, or game behavior. Reward amount and dialogue alone do not
  distinguish outcomes.
- [ ] Partial and every terminal reentry policy are authored. Expiry and cleanup
  restore base functionality except for explicit persistent aftermath.
- [ ] At least one game, crew, town, sweep, travel, heat, security, economy, or
  rumor connection changes play rather than flavor.

## Authority, persistence, and safety

- [ ] Commands validate phase, authenticated semantic target, availability,
  preconditions, cost authority, receipt, and fingerprint before mutation.
- [ ] Duplicate receipt plus identical command returns the recorded result;
  receipt reuse with different content rejects atomically.
- [ ] Facts apply only at named safe boundaries. No authoritative outcome uses
  wall-clock time, frame count, renderer state, dictionary order, or unowned RNG.
- [ ] Save/load at every phase and immediately before/after each branch matches
  the complete semantic snapshot. Reward, trust, heat, suspicion, inventory,
  rumor, dialogue, audio, transition, cleanup, and consequence fire exactly once
  across reload, travel, revisit, abort, expiry, and retry.
- [ ] Public projections reveal no hidden branch, unrevealed actor intent,
  private local state, receipt journal, tombstone, RNG state, or sealed inventory
  internals. A hidden-information leak is P0.
- [ ] Failed command, operation batch, fact batch, cleanup, reentry,
  finalization, or render preparation is atomic and fails closed.
- [ ] Base services, games, events, travelers, sweep pressure, and exits coexist
  under declared priority/conflict rules; no orphan hit region or inaccessible
  exit remains.

## Distinctness, presentation, and platform

- [ ] The normalized mechanic signature includes verbs, pressure, phase graph,
  branch topology, operations, world connection, and aftermath. Renaming fields
  or rewards cannot evade similarity review.
- [ ] Pairwise comparison against all existing and concurrently authored
  variants finds no equivalent complete signature. Shared primitives have a
  different second verb, pressure, connection, topology, and aftermath.
- [ ] All phases, branches, and ids are fixture-reachable; scenario selection is
  seed-reachable without changing established weights.
- [ ] Semantic layout validation passes for bounds, access lanes, interaction
  reachability, z-order, text safety, touch targets, small screen, reduced
  motion, and colorblind/non-color-only state.
- [ ] Pointer, keyboard, and controller paths reach every required action.
  Reduced motion preserves cause/effect and state clarity.
- [ ] No per-frame schema evaluation, reconstruction, authority decision, or
  deep copy is introduced. Idle liveness advances; `0.000` without liveness is
  a failure.
- [ ] Identical seed/action traces produce identical semantic state, layout,
  routes, actor states, outcomes, and receipts on native and Web.

## Package evidence and handoff

- [ ] Each arrival, phase, terminal aftermath, partial revisit, terminal
  revisit, reduced-motion layout, small-screen layout, and obstruction/hit
  overlay has a current capture id.
- [ ] A title/sign-free contact sheet makes every assigned variant identifiable
  by layout and actors alone.
- [ ] Focused validation covers invalid refs, unreachable phases, missing
  cleanup, orphan regions, duplicate consequences, state-only transitions, and
  signature collisions.
- [ ] The exact immutable handoff names base/head, complete path list, ownership
  proof, per-id dossier/capture/test matrix, known reds, deferred defects, and
  excludes `.tmp/`, `.tools/`, `review_artifacts/`, generated output, and all
  unrelated files.
- [ ] Independent review is by someone outside the implementing package. A
  second rejection escalates to the program director.
