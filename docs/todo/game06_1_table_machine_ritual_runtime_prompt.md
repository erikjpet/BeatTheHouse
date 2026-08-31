Status: IN_PROGRESS — implementation landed on `main`; Family 1 release-gate closeout remains open
Board row: `game06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 game06_1: Table and Machine Ritual Runtime

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). This row builds the shared runtime
that lets every game become a played sequence instead of a control panel. It is
the games-side equivalent of `env06_6`. It owns vocabulary, not content.

Read before editing: `scripts/core/game_module.gd`,
`scripts/games/table_game_visuals.gd`, `scripts/ui/game_surface_canvas.gd`, the
landed `craps06_3` implementation and its archived prompt, and
`scripts/games/scratch_tickets.gd` plus `scripts/games/coin_pusher.gd` — today
those two are the only modules that implement `surface_pointer_command`, so they
are the existing evidence of what tactile interaction costs here. Code reality
wins over this prompt.

## Why this rework exists

Every game module implements the same four seams: `surface_state`,
`draw_surface`, `surface_action_command`, and optionally
`surface_pointer_command`. `table_game_visuals.gd` draws the room, table, dealer
station, patrons, gaze focus, wager badges and round timer for every table game.
That layer can draw a scene but cannot stage one: there is no vocabulary for a
multi-beat committed action, for an actor with a behavior state that reacts to
money and heat, for a room object that changes state, or for energy that moves
anything other than music values and a line of patron text.

`craps06_3` builds the first such ritual for one game. This row generalizes that
seam so the remaining eight games and the duel can be converted in parallel
without eight agents editing the same shared files.

## Board and dependencies

Follow the active board protocol in `docs/todo/README_0_6_board.md`. Claim
`game06_1` before work and log discoveries. `craps06_3` must be DONE before
implementation starts — read its accepted head first. This row unblocks
`game06_2` through `game06_7`.

## 1. Harvest the craps ritual before designing

- Produce a written inventory of what `craps06_3` landed: presentation phases,
  pointer verbs and their bounds, rejection and return behavior, staged
  settlement, actor states, energy projection, audio hooks, accessibility
  equivalents, and persistence of mid-ritual state.
- Classify every item as general (belongs in this runtime), table-specific
  (belongs to craps), or accidental. Justify each classification.
- The contract you build must re-express the landed craps ritual with no
  craps-specific branch in shared code. If it cannot, the contract is wrong —
  redesign rather than special-case.

## 2. The ritual contract

Add a validated, versioned contract. Exact names may adapt to code reality, but
every capability below is mandatory:

- `ritual_phases`: stable phase ids per game with entry conditions, permitted
  actions per phase, and explicit transitions. A phase machine must make
  double-commit, double-settle and act-out-of-turn structurally impossible.
- `staged_commitment`: place, correct, undo, clear, repeat and confirm as
  distinct steps over a pending wager set, with the at-risk total, the
  available funds and the per-item resolution readable at all times. A player
  must never destroy a whole bet set to fix one item.
- `pointer_verbs`: registered drag, hold, flick, place and reveal verbs bound to
  named board regions, with bounds, rejection semantics that never charge or
  advance, and mandatory keyboard, controller and reduced-motion equivalents
  producing identical outcomes and fair timing.
- `actors`: dealers, staff, opponents, neighbours and onlookers as addressable
  entities with authored positions, poses and a bounded behavior state set.
  Actors react to game facts, not to frame counts.
- `scene_objects`: stable semantic ids for machinery and props with visual and
  functional state, hit regions where interactive, and z-order and text-safety
  participation. Metadata-only props fail this contract.
- `energy`: a per-game tier model whose application must touch at least one
  actor, object or interactable state. It may also drive music; music alone is
  a validation failure and the tests must enforce that.
- `game_facts`: typed facts published at safe boundaries for other systems to
  consume — round start, commitment, resolution, streak tier, large swing,
  cheat attempt and result, attention or heat change, session end.
- `ritual_persistence`: what mid-ritual state serializes, what is transient,
  and how a restore lands in a legal phase with no replayed reward, dialogue,
  audio or one-shot effect.

Complex behavior uses small registered handlers with explicit input, output,
persistence and deterministic-RNG contracts. Data must not carry arbitrary code,
reflection targets, resource paths outside allowlists, or raw node paths.

## 3. Shared visual layer

- Extend `table_game_visuals.gd` so actors and scene objects are first-class:
  authored anchors, bounded pose and behavior states, gaze and attention already
  present in `dealer_focus_for_state` generalized, and reaction staging.
- Extend the canvas layer with the hit-region, design-space and animation-channel
  support the pointer verbs need, reusing the existing channel and liveness
  machinery rather than adding a parallel one.
- Add a layout validator: object bounds, reachability of every interactive
  region, z-order, text safety, small-screen and reduced-motion layouts, and
  colorblind distinguishability of anything the player must tell apart.
- Everything is opt-in. A game that has not adopted the contract must render and
  behave byte-for-byte as before, and the tests must prove that for all eleven
  games at the time this row lands.

## 4. Determinism, performance and platform

- Authoritative outcomes stay seeded and rules-owned. Presentation may never
  reroll, reorder or alter a result, and may never read wall-clock time for one.
- Phase advancement and fact publication happen at action boundaries. Nothing
  new runs per frame that can run at a boundary, and no per-frame deep copy of
  state is permitted — the slot bonus watchdog is the recorded precedent for
  that failure.
- The idle-liveness counter-gate in `scripts/ui/performance_liveness_guard.gd`
  is mandatory for every surface touched. An idle draw cost of 0.000 is a
  failure, not a pass; this project has regressed on that four times.
- Native and Web must produce identical outcomes for identical input traces.

## 5. Tests and acceptance

- Contract validation tests: malformed phases, unreachable transitions, unbound
  pointer verbs, actors without behavior states, objects without bounds, energy
  tiers that touch nothing but music — each must fail loudly.
- Phase-machine property tests: no input sequence can double-commit,
  double-settle, act out of phase, charge on a rejected verb, or strand a wager.
- Opt-out proof: all eleven games unmodified in behavior and rendering, with
  before/after captures for each.
- Craps re-expression proof: the landed ritual runs on the contract, its full
  rules, RTP, determinism and visual gates still pass, and shared code contains
  no craps-specific branch.
- Accessibility: every pointer verb has an equivalent path; reduced motion
  removes travel and shake while preserving phase and result clarity.
- Save, exit and restore at every phase boundary of the proof game.

## 6. Deliverable

Write a contract document under `docs/plans/` describing every capability, its
data shape, its persistence rules and its validation errors, with a worked
example. `game06_2` through `game06_7` are written against that document, so an
ambiguity here becomes six divergent implementations.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA. Archive only with
exact evidence, and only if the craps re-expression proof passes without a
shared-code special case.
