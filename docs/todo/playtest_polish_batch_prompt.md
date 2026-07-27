# Agent Prompt — Playtest Polish Batch (Root-Caused Fixes)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas, foundation_main host,
per-game modules, data-driven `data/*.json`). This is a STRUCTURED WORK
ORDER of owner playtest findings. Each item below has a symptom, a
root-cause hypothesis with file anchors (CONFIRM against current code —
line numbers may have drifted; code reality wins), a resolution, and an
acceptance bar. Fix each from the ground up, cleanly and completely — not
a surface patch. Commit each item (or tight group) as its own logical
unit so partial progress is preserved.

Video poker cheating is handled by a SEPARATE prompt
(`video_poker_cheat_minigame_rework_prompt.md`) — do not touch the video
poker cheat here.

## Hard rules (apply to every item)

- Fix root causes, never symptoms; never weaken or skip a test to get
  green; determinism preserved (seeded, action-boundary); zero-copy
  per-frame; idle-animation liveness untouched (never accept a 0.000
  idle-draw number without the liveness check); tabs, typed GDScript,
  sparse comments; captures under `.tmp/`. Suite timeout = max(300s,
  ceil(recorded baseline × 1.5)).
- The working tree may contain uncommitted user-owned work; never revert,
  reformat, or stage files you did not author. Stage explicitly.

---

## 1. Route-unlocking event copy must say it opens travel

**Symptom:** picking up the parking-lot tip (and similar) silently adds a
new travel destination; the player isn't told.

**Root cause:** events that apply `add_next_archetypes` in their choice
consequences (`data/events/events.json` — `parking_lot_tip` ~:93 sets
`underground_tip` + `add_next_archetypes`, and several other events use
`add_next_archetypes` at ~:120,:168,:374,:442,:545,:782,:3116) do not
state in their player-facing summary/choice text that a new route opens.

**Fix:** audit EVERY event choice in `events.json` that contains
`add_next_archetypes` (or `travel_hooks_add`) and update its choice label
and/or result copy to make the new-travel outcome explicit ("A new route
opens on your map." / name the destination when known). Keep the content
style-guide voice. Add a test/audit assertion that any choice granting
`add_next_archetypes` has non-empty copy referencing new travel.

**Acceptance:** every travel-unlocking choice tells the player a route
opened; a data test guards it.

## 2. "You are here" on the world map

**Symptom:** the player can't tell which node is their current location.

**Root cause:** `scripts/ui/world_map_canvas.gd` (~:384-428) computes
`is_current` but only nudges alpha/color slightly — no distinct marker or
label.

**Fix:** render a clear current-location indicator on the current node: a
distinct marker (e.g. a pulsing ring / pin in a reserved token color) AND
a short "YOU ARE HERE" / current-stop label, legible at 1280×720 and
small-screen, reduce-motion safe (no pulse when reduce-motion). Use design
tokens, not raw literals.

**Acceptance:** the current node is unmistakable at a glance on both the
in-run map overlay and anywhere the map renders.

## 3. Item cards show which game they affect + post-buy nudge

**Symptom:** players don't know what game an item helps; after buying,
they don't know where to use it.

**Root cause:** items carry `domain`/effects (`data/items/items.json`;
`data/art/attribute_glyphs.json` is mostly `"domain": "global"`), but item
cards show no per-game affinity symbol, and buying an item gives no
guidance toward the relevant game.

**Fix:** (a) add a game-affinity GLYPH to the attribute-glyph/badge system
so an item that affects a specific game (blackjack, video poker, bar dice,
roulette, baccarat, slots, scratch, pull tabs) shows that game's symbol on
its card; global items show a global glyph. Derive affinity from the
item's effect keys (many effect keys are game-scoped, e.g.
`video_poker_*`, `blackjack_*`) — map effect-key prefixes to games in
data, don't hardcode in UI. (b) After a purchase whose item has a game
affinity, surface a brief nudge ("Try it at the blackjack table") using
the existing message/coach affordance — and, where that game is present in
the current environment, a light highlight on that game object.

**Acceptance:** every game-scoped item shows its game glyph; buying one
points the player at the right game.

## 4. Tutorial/coach popup can't be dismissed

**Symptom:** a tutorial popup has no way to go away, trapping the player.

**Root cause:** `scripts/ui/coach_overlay.gd` only shows its "Got it"
button when `completion_type == "explicit_ok"` (~:203-236). A lesson whose
completion is an anchored/any action — but whose anchor is unreachable, or
which gates input such that the completing action can't be taken — leaves
NO dismiss path.

**Fix:** guarantee every coach bubble is dismissible from the ground up:
always provide a dismiss/skip affordance (a close control or "Skip tip")
that resolves the lesson and never soft-locks, regardless of
`completion_type`. Audit the lesson data for any lesson whose completion
condition cannot be met in its context and fix the data too. A gating
tutorial lesson must still expose the skip path.

**Acceptance:** no coach popup can trap the player; a test drives a lesson
whose anchor never fires and asserts a dismiss path exists.

## 6. Alcohol blur must not distort text boxes

**Symptom:** the drunk effect blurs/warps text, hurting readability.

**Root cause:** `scripts/ui/drunk_distortion_overlay.gd` (via
`game_surface_canvas.gd` `_update_drunk_distortion_overlay`) distorts the
surface region without excluding text/dialog rects. Protected-rect
machinery exists for some elements but text boxes aren't protected.

**Fix:** exclude text-bearing rects (result text, dialog/explainer panels,
prize/rule legends, HUD readouts) from the drunk distortion — either by
registering them as protected rects or by drawing text ABOVE the
distortion layer. The world may wobble; the words must stay crisp.

**Acceptance:** with high drunk level, all text remains sharp and readable
while non-text visuals still distort; assert protected coverage in a test.

## 7. Bar dice: clarify the rules and the outcome

**Symptom:** players don't understand Ship-Captain-Crew rules or what just
happened.

**Root cause:** `scripts/games/bar_dice.gd` explainer/turn-guide text
(`_bar_dice_explainer`, `_bar_dice_turn_guide` ~:275) under-communicates
the ruleset and the resolution.

**Fix:** make the surface teach as it plays: a persistent concise rules
line (you need Ship→Captain, then Crew is your score), clear per-phase
guidance (what to keep/reroll and why), and an unambiguous outcome readout
(what you rolled, what the opponent rolled, who won, how the pot resolved).
Readable at both sizes.

**Acceptance:** a first-time player can follow SCC and read the result
without external help.

## 8. Bar dice: bets are broken

**Symptom:** betting in bar dice does not work correctly.

**Root cause (confirm precisely — this is a real bug, root-cause it):**
trace the bar dice stake/pot flow — `_active_stake_from_context`, the
stake ladder (`_generated_stake_ladder`), `_working_pot`, rake, and the
payout at settle (`hosted_payout_percent`, `EDGE_PAYOUT_PERCENT`), plus
`wager_cost_for_context` (~:204) and `surface_stake_controls_required:
false`. Find exactly where the wager charged, the working pot, and the
payout diverge from intent (e.g. stake not deducted, pot mis-summed,
payout percent misapplied, or the surface not exposing stake selection).

**Fix:** correct the bet lifecycle end-to-end so the amount staked, the
pot, and the payout are consistent and correct, with a deterministic test
covering a win, a loss, and a push across stake tiers.

**Acceptance:** staking N deducts N, the pot and payout math are correct
and match the displayed numbers, verified by tests.

## 9. Rourke event: one selection path, no duplicate controls

**Symptom:** the Rourke showdown offers duplicate ways to make the same
selection.

**Root cause:** the showdown beats (`scripts/games/grand_casino_showdown_
model.gd`, surfaced via `foundation_main.gd` ~:1729-1759) render selectable
choices in more than one place (e.g. the event-choice popup AND the talk
dock or an inline surface control).

**Fix:** collapse to a SINGLE canonical selection surface for showdown
choices; remove the duplicate control path so each choice appears once.
Keep the choice set and outcomes identical.

**Acceptance:** each showdown beat presents exactly one control per choice;
a test asserts no duplicate choice ids are rendered.

## 10. Rourke duel: doubling must not end the run

**Symptom:** doubling during the Rourke duel ends the run.

**Root cause:** the duel (`scripts/games/grand_casino_duel_model.gd`,
built on blackjack — `blackjack.gd` `blackjack_double` ~:882 →
`_settle_completed_round_command`) treats a double as a terminal settle
that resolves the duel/run instead of a normal in-hand action within the
duel's own win/lose ladder.

**Fix:** doubling is an ordinary hand action inside the duel; only the
duel's defined outcome ladder (win / narrow / taken-out-back) may end the
run. Ensure a doubled hand resolves as a hand result feeding the duel
stack, never as a premature run terminal.

**Acceptance:** doubling in the duel plays the hand and continues the duel;
the run ends only on the duel's real conclusion. Test the doubled-hand
path end to end.

## 11. Run-report map: show all visited locations and correct movement

**Symptom:** the end-of-game map omits visited locations and the movement
doesn't render correctly.

**Root cause:** `scripts/ui/run_report_view_model.gd` `_resolved_report_
path(world_map, transitions, travel_entries)` (~:374) reconstructs the
traveled path incompletely, so segments/nodes are missing and the replay
movement is wrong.

**Fix:** rebuild the visited-path reconstruction from the authoritative
run history so EVERY visited node appears in order and every movement
between them renders as a segment the replay can animate. Cross-check
against `environment_history` / the world map `visited_path` / transitions;
handle revisits and the start node. Then verify the timeline canvas
(`run_report_timeline_canvas.gd`) draws the full path and the replay cursor
tracks it.

**Acceptance:** the report map shows the complete visited route in order
with correct movement between stops, across several seeds and a
multi-stop run; a test asserts path completeness against the run's true
visit sequence.

---

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (discover the list; do not guess)
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`

## On completion

Only after every gate passes AND you have confirmed each fix in the running
game:

1. Commit the work in logical units (one per item or tight group).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, per-item commit
   hashes, gate results, any item you could not fully resolve and why),
   and stage the move.
3. PUSH to the remote.
4. Report per item: confirmed root cause, the fix, and its acceptance
   result.

On an unfixable item, land the others, leave that item's finding in the
report, and (if it needs more than this batch) write a focused follow-up
prompt into `docs/todo/`. On a gate you cannot green, stop at the last
green commit, do NOT push, and report verbatim.
