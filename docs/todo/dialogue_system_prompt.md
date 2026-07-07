# Agent Prompt — Full Dialogue System: Multi-Turn Conversations in the Talk Dock (Pilot: Pull-Tab Clerk)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). The shipped talk dock
(`scripts/ui/talk_dock.gd`, archived prompt:
docs/todone/talk_overlay_decision_system_prompt.md) currently addresses
single comments to the player. This task grows it into a **full dialogue
system**: multi-turn, branching conversations with any human in the game —
shopkeepers, clerks, patrons — where the player makes decisions inside the
conversation and sees the mechanical effects of each choice (heat, money,
story flags, travel unlocks) before picking.

**Pilot content:** the pull-tab clerk. Their dialogue text plus a rendered
model of them appears in the dock, which also becomes **smaller** than it is
today.

## What exists (build on it, never parallel to it)

- `TalkDock` (talk_dock.gd): bottom-left Control, `COLLAPSED_SIZE 380×48`,
  `EXPANDED_SIZE 380×220`, `portrait_panel` stub at 48×54 (:134), ≤4 choice
  buttons, number-key hotkeys, `choice_requested` signal,
  `AttributeBadgeRowScript` already preloaded (:10).
- Talk entries flow through RunState's `pending_triggered_events` queue with
  `presentation: "talk"` and a `speaker` snapshot (see the archived talk
  prompt for the contract).
- Consequence application: event choices resolve through one host path
  (`resolve_event_choice`, foundation_main.gd) applying `consequences` keys
  (`bankroll_delta`, `suspicion_delta`, `resolve_event`, …). Inventory the
  full vocabulary before extending it.
- Character rendering: table games build character dictionaries (name,
  hair/jacket colors, silhouette, role — table_game_visuals.gd:130-142) fed
  to a shared character-drawing helper; pixel_scene_canvas.gd draws the
  corner-store "bored clerk" (:530). Locate the shared helper and reuse it
  for portraits — do not write a second character renderer.
- Pull-tab clerk: pull_tabs.gd exposes a room-side clerk/cashier for
  redeeming winning tabs (:234, :876); clerk events exist in events.json
  (`late_shift_discount`, `chatty_clerk`).

## 1. Dialogue data (`data/dialogue/dialogues.json`, new)

- Dialogue: `id`, `speaker` (same schema as talk-entry speakers: role, name,
  silhouette, palette keys — so patrons/staff/strangers all work), `start`
  node id, `nodes`.
- Node: `text` (what the speaker says), `choices` (1–4): `id`, `label`,
  `effects` (the existing consequence vocabulary), `goto` (next node id) or
  `end: true`. A node with no choices auto-offers a single "..." continue.
- Effects extensions (add to the one consequence applier, minimally):
  `set_story_flag: "<flag>"` (new `story_flags` dict on RunState,
  normalized/serialized) and `unlock_travel_route: "<route_id>"` (wired to
  the world-map visibility/enable path). Everything else (heat, money,
  items) must reuse existing keys — no forked effect semantics.
- Conditions (keep minimal): optional per-choice `requires` on story flags,
  bankroll floor, or heat band, hidden or greyed-with-reason when unmet.
- Validate on load like existing content: unknown nodes/goto targets fail
  validation loudly at load, never at runtime mid-conversation.

## 2. Runtime: conversations ride the existing talk queue

- A conversation is a talk entry carrying `dialogue_id` + `current_node`.
  Picking a choice applies its effects through the shared applier, then
  advances `current_node` in place (same entry, dock re-renders) until an
  `end` node completes the entry through the normal lifecycle.
- Each dialogue advance is a **player action boundary** (clock minutes,
  determinism, autosave cadence all treat it as such). No wall-clock
  anywhere; any randomness in effects uses seeded streams.
- Save/load mid-conversation round-trips (`dialogue_id` + `current_node` +
  speaker snapshot normalize on load; SB.3-style idempotence).
- Starting a conversation: interactable props/NPCs enqueue a dialogue talk
  entry (the same way events enqueue today). Keep the trigger surface
  generic — any environment prop or patron can reference a `dialogue_id`.

## 3. Dock rework: smaller, with a speaker model

- **Shrink it** (owner directive): target ~330×170 expanded (tune to fit 4
  choice rows without scroll where possible; tighten paddings/fonts), same
  bottom-left anchor, collapsed strip stays.
- **Portrait becomes a model**: render the speaker through the shared
  character-drawing helper into the portrait panel (a static pose is fine;
  reuse silhouette/palette from the speaker snapshot so the pull-tab clerk
  in the dock matches the clerk drawn in the room). Cache the rendered
  texture per speaker key — no per-frame regeneration.
- **Effects are visible before choosing**: each choice row shows its
  mechanical effects (heat +2, $ +15, story, route unlock) via the badge
  row (`AttributeBadgeRowScript` is already preloaded; if the glyph
  registry lacks story/route glyphs, add them to
  data/runtime/attribute_glyphs.json). Hidden effects are allowed only when
  a dialogue explicitly marks a choice `effects_hidden: true` (deception is
  a design tool — but the default is honest disclosure).
- Keep non-blocking semantics: gameplay stays interactive; walking away
  (traveling, starting a game action) suspends the conversation entry back
  to the queue rather than stranding it.

## 4. Pilot: the pull-tab clerk

Author `pull_tab_clerk` dialogue (in dialogues.json) and wire it to the
pull-tab room's clerk/cashier interaction:

- Greeting node with flavor consistent with the venue's tone.
- Redeem chatter (ties into the existing redeem flow's messaging, not
  replacing its mechanics).
- One risky branch (e.g. ask about "loose" tickets → heat gain, possible
  payout — seeded roll through existing consequence keys).
- One informational branch: clerk tip that sets a story flag and/or reveals
  a travel route (exercises both new effect keys).
- Also migrate the two existing clerk events (`late_shift_discount`,
  `chatty_clerk`) to short dialogues, proving the migration path from
  one-shot events to conversations.

## Hard constraints

1. Zero per-frame allocations; portrait textures cached; per-frame paths
   stay zero-copy (see CLAUDE.md).
2. One consequence applier — dialogue effects and event effects must never
   diverge in behavior.
3. Determinism gate must keep hash-matching (dialogue advance = action
   boundary; seeded rolls only). Extend the determinism probe's scripted
   actions to walk a dialogue if it does not already exercise talk choices.
4. Extend, do not weaken, suites: (a) dialogue data validation (bad goto =
   load failure), (b) mid-conversation save/load round-trip, (c) input fuzz
   over the resized dock (rapid clicks cannot double-apply a choice's
   effects), (d) effects-badge disclosure matches applied consequences,
   (e) pilot dialogue end-to-end (flags set, route unlocked, heat applied).
5. Match house style: tab indentation, typed GDScript, sparse comments
   stating constraints only. Dialogue text follows the game's terse,
   diegetic tone; simulated gambling only.

## Coordination note

Touches talk_dock.gd, foundation_main.gd, events/consequence paths, and the
glyph registry — coordinate with QUEUE.md: wait for the claimed glyph/beach
entries to land, then pull before starting.

## Verification gates (run at the end, not iteratively)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui` and
   `-FoundationSuite systems`, plus `-FoundationSuite pull_tabs` for the
   pilot wiring.
3. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` —
   hash match with a scripted dialogue walk in the mix.
4. Move this prompt to docs/todone/ with an execution record per RULES;
   update QUEUE.md. Commit locally; do NOT push.
