# Agent Prompt — Talk Overlay: Bottom-Left Non-Blocking Decision Dock + NPC Approach Events

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (1280×720 fixed viewport; game surfaces render immediate-mode onto a
900×430 design board — see CLAUDE.md for the architecture summary). You are
building the **talk system**: a persistent, non-blocking decision UI docked in
the bottom-left of the screen, plus the event structure for NPCs (including
patrons seated at the player's table) approaching and speaking to the player.

## Product intent (binding)

1. The dock is the "menu" for event triggers: when something happens — someone
   talks to the player, heat/suspicion pressure crosses a threshold, an event
   chain advances — it surfaces **here**, in one known location, and lets the
   player decide.
2. Gameplay is never overlapped or overpowered: the gambling/environment game
   stays fully playable while a talk entry is pending. No modal takeover, no
   input-route freeze, no covering the game board's play area.
3. The dock has its own timing system (visible urgency countdown where a
   decision expires) and its own selection method (mouse/touch on choice
   buttons plus number-key hotkeys), independent of game-surface input.

## Current architecture you are extending (investigated)

- **Blocking popup today:** triggered events currently present through
  `event_choice_popup_overlay` (foundation_main.gd:225-229), which is modal —
  `_guard_player_input_route`-adjacent gating at foundation_main.gd:394 blocks
  world interaction while it is visible, and the comment block at
  foundation_main.gd:314-319 documents both triggered and interactable events
  using it. The talk dock **demotes most decisions out of this popup**; the
  modal path must remain only for events explicitly marked blocking (e.g.
  showdown-critical beats).
- **Event queue backbone (reuse, do not duplicate):** `RunState` has
  `pending_triggered_events` / `active_triggered_event` with dedup enqueue
  (run_state.gd:3644-3666), `next_pending_triggered_event` (:3668),
  `begin_triggered_event_resolution` (:3676), `complete_triggered_event_resolution`
  (:3692), serialization (:4035-4036, :4077) and a normalizer
  (`_normalize_triggered_event_entry`). Event chains enqueue via
  `event_module.gd:273`.
- **Event data:** `data/events/events.json` — 33 entries with `id`,
  `display_name`, `type`, `interaction_mode`, `scopes`, `trigger`, and
  `payload.choices[]` where each choice has `id`, `label`, `text`,
  `consequences` (e.g. `bankroll_delta`, `suspicion_delta`, `resolve_event`).
- **Speakers already exist as patrons:** table games carry a `patrons` array
  in their table dictionaries (rendered by
  `table_game_visuals.gd::draw_table_patrons`, :114-153) with `name`, `mood`,
  `behavior`, `silhouette`, hair/jacket colors, `watching_player`,
  `snitch_risk`/`snitch_threshold`, `tell`, `chip_stack`. Foundation tests
  manipulate `table["patrons"]` directly (foundation_check.gd:7846-7854,
  :8045-8053).
- **Heat:** the suspicion system (`run_state.gd:93`, `suspicion_level()`
  :1000, per-environment :1010) with meaningful thresholds at 65 and 85
  (:1045-1047).

## Design to implement

### 1. Data schema (data/events/events.json + content_library validation)

Add optional fields, all normalized with safe defaults so every existing
event remains valid unchanged:

- Top level: `"presentation": "talk" | "modal"` (default `"modal"` to preserve
  current behavior; migrate suitable existing events to `"talk"` as a final
  content pass).
- `"speaker"`: `{ "role": "patron" | "staff" | "stranger" | "lender",
  "name": "...", "silhouette": "...", "bind": "table_patron" | "none" }`.
  When `bind == "table_patron"` and the player is seated at a table game with
  patrons, the runtime binds the speaker to a live patron (see §4) instead of
  the static name.
- `payload.timing`: `{ "expires": bool, "duration_actions": int,
  "timeout_choice_id": "..." }` — see §5 for why the unit is actions, not
  seconds.
- New trigger type alongside `"manual"`: `{ "type": "heat_threshold",
  "level": 65 | 85 }` and `{ "type": "table_approach", "games": [...],
  "min_hands": int, "chance": float }` (seeded roll, see §5).

Validate all new fields in the content library load path
(scripts/core/content_library.gd) the same way existing event fields are
validated; malformed values must fall back to defaults, never crash.

### 2. RunState (extend the existing queue)

- Extend `_normalize_triggered_event_entry` to carry `presentation`,
  `speaker`, and timing state. Bump nothing structurally — entries remain
  dictionaries in the same queue, so SB.3 save/load fuzz idempotence
  (`to_dict -> from_dict -> to_dict`) holds automatically once the normalizer
  round-trips the new keys. Add the new keys to the normalizer's output
  unconditionally (stable shape) so serialization is idempotent.
- Talk entries do **not** use `begin_triggered_event_resolution`'s exclusive
  `active_triggered_event` slot (that is the modal contract). Add a parallel
  non-exclusive accessor: the dock shows the head of the talk-presentation
  subset of `pending_triggered_events`; modal entries keep the existing flow
  untouched. One entry is "focused" at a time in the dock; the rest queue
  behind a visible counter badge.
- Choice resolution routes through the same consequence application code the
  modal popup uses today (`resolve_event_choice`, foundation_main.gd:1138) —
  do not fork consequence semantics. Factor, don't copy.

### 3. The dock UI (foundation_main.gd + new script)

- New Control (own script, e.g. `scripts/ui/talk_dock.gd`) anchored to the
  **bottom-left of the 1280×720 viewport**, added by foundation_main alongside
  the existing overlay Controls. Before choosing exact geometry, inventory
  what currently occupies the bottom-left region (check `_show_message`
  presentation and any HUD panels there) and either dock above/beside it or
  relocate the lesser element — nothing may stack on the dock's known
  location. Maximum expanded footprint ~380×220; it must never cover the
  centered game board's interactive area.
- Two visual states: **collapsed** (one-line speaker + summary strip, queue
  badge) and **expanded** (portrait/name header, event text, up to 4 choice
  buttons, urgency bar when timed). Expansion is player-controlled (click the
  strip) and automatic when a timed entry arrives; it never steals keyboard
  focus from an in-progress game action.
- Selection: standard Control buttons (mouse + touch — touch parity is an
  SB.4 contract), plus number-key hotkeys 1–4 routed only when the dock is
  expanded and the key is not claimed by an active game surface. Confirm
  destructive/irreversible choices with a second click on the same button
  (armed state), not a nested popup.
- It is **not** modal: do not add it to the visibility gate at
  foundation_main.gd:394, and `_guard_player_input_route` must not treat it
  as an overlay. Interacting with the world while the dock is open is legal
  and must not strand it (input-fuzz coverage below).
- Rendering discipline (0.3.1/0.3.2 idle-draw rules are release-gated): the
  dock is a Control-node UI, not a per-frame canvas redraw. Text/portrait
  update only on state change; the urgency bar may animate but only while a
  timed entry is focused, and must stop scheduling redraws when the dock is
  idle. Zero per-frame allocations; never `duplicate(true)` live state per
  frame.

### 4. NPC approach structure (patrons speak)

- New shared helper (natural home: scripts/core/run_action_service.gd or the
  event module) that, on table-game action boundaries (hand resolved, wager
  placed), evaluates `table_approach` triggers: a seeded roll (see §5) picks
  a patron from the current table's `patrons` array and enqueues a talk event
  whose speaker snapshot copies that patron's identity fields (`name`, `mood`,
  `silhouette`, colors) **by value** into the event entry — the entry must
  stay valid after the player leaves the table (mutation firewall: reading
  patrons for the snapshot must not mutate the table dictionary).
- While that patron's talk entry is focused in the dock, set the existing
  per-patron presentation fields the renderer already understands
  (`watching_player`, `tell_active` — table_game_visuals.gd:124-128) through
  the game module's normal state pipeline so the seated patron visibly turns
  toward the player. Do it in the module's state-building path, not by
  mutating live table state from the UI (SB.2 mutation firewall: draw/preview
  paths must not mutate RunState).
- Heat triggers: on suspicion crossing 65/85 (per-environment where
  applicable), enqueue the matching `heat_threshold` talk event (pit boss /
  floor staff pressure). Crossing detection belongs where suspicion deltas
  are applied, not in a per-frame poll.

### 5. Timing and determinism (hard constraint)

The 0.3.1 determinism gate (`tools/foundation_determinism_probe.ps1`, SB.5)
requires two separate processes replaying the same seeds to produce identical
state hashes, and it covers event chains. Therefore:

- **No wall-clock decision timers in state.** `payload.timing.duration_actions`
  counts player action boundaries (the same boundaries §4 hooks). When the
  count is exhausted, the timeout choice auto-resolves at the *next action
  boundary* — deterministic in both processes. The on-screen urgency bar may
  render smooth wall-clock motion as presentation, but expiry is decided only
  by the action counter carried in the entry.
- **All randomness is seeded.** `table_approach` chance rolls and patron
  selection draw from the run's seeded RNG streams (find the existing pattern
  — grep run_generator.gd / run_state.gd for how event and travel rolls derive
  from the run seed) — never `randf()` on an unseeded global stream, never
  time-based seeds.
- New wait states must be sweep-safe: a pending talk entry with `expires ==
  false` must never gate run progress (the stuck-state sweep,
  `tools/foundation_stuck_state_sweep.ps1`, generalizes over wait states —
  extend its inventory if it enumerates them; grep foundation_check.gd for the
  SB.6 wait-state inventory first).

### 6. What this does NOT include

- No voice/audio work, no portrait art generation (reuse the existing
  character-drawing helpers used for patrons/dealer if a portrait is cheap;
  otherwise a colored silhouette block is fine for this task).
- No rewriting of existing modal events' content beyond flipping suitable
  entries to `"presentation": "talk"` at the end.
- No home-environment integration (that is a separate prompt in this folder);
  design the trigger surface so environment scopes can enqueue talk events
  later without schema changes.

## Hard constraints

1. Per-frame paths stay zero-copy (measured 32.6 ms/frame regression history —
   see CLAUDE.md). Talk evaluation happens on action boundaries only.
2. Do not break the modal popup contract for events that remain modal; the
   fuzz and firewall suites assert its behavior (grep foundation_check.gd for
   `event_choice_popup` before touching it).
3. New RunState fields must survive SB.3 interruption fuzz: normalize on
   load, stable dictionary shapes, no functions-as-state.
4. Extend, do not weaken, the release-gated suites: add foundation coverage
   for (a) talk entry enqueue/dedup/normalize round-trip, (b) dock choice
   resolution equals modal resolution consequence-for-consequence, (c) action
   -counter expiry determinism, (d) input fuzz over dock hit regions
   (rapid/illegal clicks + touch parity must not strand or double-resolve),
   (e) patron speaker snapshot immutability after leaving the table.
5. Match existing style: tab indentation, typed GDScript, sparse comments
   stating constraints only. UI strings follow existing tone (terse, diegetic).
6. Simulated gambling only — no real-money framing in any new content text.

## Verification gates (run at the end, not iteratively)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. Targeted suites: `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui`
   and `-FoundationSuite systems`, plus one table-game suite (blackjack) for
   the approach hooks.
3. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` —
   must hash-match with talk events in the mix; add a seed prefix that
   exercises them.
4. `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 50` — no
   new stuck states.
5. One `tools\foundation_mouse_batch_playtest.ps1 -RunCount 10 -RequireGodot`
   batch as an integration smoke.
