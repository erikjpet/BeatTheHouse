Status: TODO
Board row: `world06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_1: Crew and World Sequence Adapter

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). This row builds the bridge that
lets crew and world systems run `env06_6` sequences instead of emitting choice
lists. It owns the seam and the vocabulary, not the content.

Read before editing: the landed `env06_6` runtime and its contract document,
`scripts/core/event_module.gd` in full, `scripts/core/scenario_engine.gd`,
`scripts/core/environment_instance.gd`, and the crew models
(`crew_state_model.gd`, `crew_recruitment_model.gd`, `crew_play_model.gd`,
`crew_heist_model.gd`, `crew_turn_model.gd`, `delivery_run_model.gd`,
`numbers_model.gd`, `police_sweep_model.gd`). Code reality wins.

## Why this rework exists

`env06_6` gives environments spatial operations, actors, objectives, branch
graphs and persistent aftermath. Crew and world systems cannot use any of it.
They reach the player through `EventModule` choice actions — `crew_job_accept`,
`crew_rook_ride`, `crew_practice_rig`, `crew_heist_table_choices()`,
`crew_heist_live_table_choices()` and their siblings — which produce a list of
text options and apply outcomes. The result is that 0.6's flagship pillar is a
menu inside rooms that have just learned to be places.

The completed state must let a crew or world system author a sequence, run it
through the shipped runtime, and get the same persistence, cleanup, reentry and
aftermath guarantees an environment scenario gets — without duplicating the
runtime and without leaking hidden state.

## Board and dependencies

Follow the active board protocol in `docs/todo/README_0_6_board.md`. Claim
`world06_1`. `env06_6` must be landed and reviewed; build only on its accepted
head. This row unblocks `world06_2` through `world06_6`.

## 1. Map the seam before designing

- Produce a written inventory of every crew and world interaction that reaches
  the player through `EventModule`: its producer, its choices, its outcome
  application, its persistence, its expiry and its cleanup.
- For each, classify what it actually is: a decision that belongs in a scene, a
  transaction that belongs at an object, a task that belongs as an objective, or
  a genuine dialogue choice that should stay a choice.
- Not everything should become a sequence. Say which ones should not, and why.
  A one-line acknowledgement does not need a staged room.

## 2. The adapter contract

- Let a crew or world system declare a sequence definition using the `env06_6`
  vocabulary — `scene_ops`, `interaction_ops`, `actor_ops`, `objectives`,
  `transition_ops`, `reentry_policy`, `expiry`, `cleanup`, `aftermath` — sourced
  from crew data rather than the scenario catalog, and validated by the same
  validator.
- Define ownership: a crew sequence mounted at a node must compose with whatever
  environment scenario is already running there. Specify precedence for
  conflicting scene ops, and make conflicts a validation error at authoring time
  rather than a surprise at runtime.
- Define lifecycle: mount, run, complete, abandon, expire, clean up. A crew
  sequence must survive save, exit, travel away and revisit exactly as an
  environment sequence does, and must clean up completely when the crew system
  that owns it ends.
- Define the outcome path: sequence results feed back into the owning crew model
  through its existing API — trust, grievance, job state, delivery state, heat
  and money all keep their landed contracts and their exactly-once semantics.
- Keep the `EventModule` path working. Interactions that stay choices must be
  unaffected, and a system must be able to convert one interaction at a time.

## 3. Hidden-state isolation

This is the part that gets audited hardest.

- The Turn's traitor resolution, its clue channels and the heist's hidden seams
  must never be inferable from a sequence definition, scene state, actor state,
  serialized key, capture, log line or test fixture.
- Provide a neutral storage and addressing scheme so an authored sequence can
  react to hidden state without naming it, and prove that an observer with full
  access to the serialized save and the scene graph cannot distinguish the
  hidden cases.
- Write the leak test as part of this row. `world06_6` and `world06_7` both
  depend on it existing and being honest.

## 4. Determinism, boundaries and no-op discipline

- Everything advances at action boundaries, seeded from run RNG. No wall-clock
  time anywhere in the lifecycle.
- A run that ignores the crew path must be a true no-op: no mounting, no
  scanning, no rebuilt world-map nodes, no cost. `crew_ignored_golden_probe.gd`
  exists because this broke before; extend it rather than writing a parallel
  check.
- Ordinary travel, ordinary events and ordinary environment functionality must
  survive at every node a crew sequence can mount at.
- Nothing new runs per frame. No per-frame deep copies.

## 5. Proof conversion

- Convert exactly one real crew interaction end to end as the proof — the
  smallest genuine one, not a fixture. It must demonstrate mount, play, outcome
  feedback into the owning model, persistence across save and revisit, cleanup,
  and composition with an active environment scenario at the same node.
- If the adapter needs a special case to make the proof work, the adapter is
  wrong. Redesign rather than special-case.

## 6. Tests and acceptance

- Validation tests: conflicting scene ops, unowned outcomes, missing cleanup,
  unreachable objectives, expiry without a policy — each must fail loudly.
- Composition tests: crew sequence plus environment scenario at one node, with
  save, load, travel away, revisit and expiry in every order.
- Exactly-once tests: every outcome kind fires once across save, reload, revisit
  and expiry. Double-fire is the historical failure mode here.
- Hidden-state leak test from section 3, run against the proof conversion.
- Crew-ignoring golden probe extended and green.
- 10-seed determinism, native/Web parity, performance including the idle
  liveness counter-gate, and accessibility for the proof conversion.

## 7. Deliverable

Write a contract document under `docs/plans/` describing the adapter, its data
shape, its composition precedence, its lifecycle, its outcome feedback path, its
hidden-state rules and its validation errors, with the proof conversion as a
worked example. `world06_2` through `world06_6` are written against that
document.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA. Archive only with
exact evidence, and only if the hidden-state leak test is present and passing.
