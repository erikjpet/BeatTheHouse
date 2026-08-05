# Agent Prompt — Meaningful Destination Decisions (+ tutorial route branch)

Last reconciled: 2026-08-05
Release target: 0.5.0
Status: **PARTIAL / WHOLE-GAME DECISION CONTRACT OPEN**

The tutorial Gas Casino versus Underground branch now exists, is deterministic,
and rejoins the guided finale. That satisfies only Part 2's structural fork.
The 2026-08-05 audit found no whole-game offer-versus-forfeit comparison or
data contract proving that visible destination choices create materially
different opportunity costs. Existing cost/risk/scouting previews are inputs,
not completion of Part 1. Preserve the working fork and build the missing
normal-run decision system at the route/environment/event seam.

Begin only after `v05_release_gate_truth_and_regression_prompt.md` closes the
current travel-content and map-focus failures. Those fixes must be reused, not
reimplemented here.

Copy everything below the line into the worker agent. This is one of two
feature prompts split out of the tutorial playtest pass
(`tutorial_playtest_fixes_prompt.md`, notes 10 and 26) because it is a design
feature, not a tweak. The map-mechanics bugs (hover-focus, seen-node
persistence, backtracking, scroll — H-1..H-4) stay in that sibling pass;
this prompt is about making the CHOICE matter.

## Decisions to confirm at kickoff (owner may answer inline; else use the
## recommended default)

1. **Commitment:** are destination choices one-way (you give something up by
   going — recommended, that is what creates weight) or freely reversible?
   This interacts with backtracking (H-3 in the sibling pass): recommended is
   that you CAN travel back where a route exists, but each choice still costs
   time/opportunity so it is not free.
2. **How divergent are the two tutorial paths?** Recommended: meaningfully
   different — the gas-station casino is the safer, smaller intro (fewer games,
   low heat, gentle money); straight underground is higher stakes (more games,
   faster heat, quicker toward the Grand Casino invite line). Confirm the shape.
3. **How many real decision points** in the guided run — just the one branch
   (recommended for the tutorial), or a couple?

Proceed on the recommended defaults if not told otherwise; note the choices in
your report.

---

You are in `D:\Projects\Beat-The-House`, Godot 4.6 GDScript. Systems: travel /
map model `scripts/core/world_map.gd`, `scripts/ui/foundation_travel_view_model.gd`,
`scripts/ui/world_map_overlay_controller.gd`; routes `data/travel/routes.json`;
events `data/events/events.json`; the tutorial engine `scripts/core/tutorial_flow.gd`
+ `data/tutorial/lessons.json`.

## Part 1 — Make the destination decision impactful (whole game)

Right now choosing where to go feels inconsequential. Give the decision weight:
- Destinations lead to **meaningfully different content and consequence** — a
  different mix of games, events, characters, heat, and reward — not the same
  loop with a different backdrop.
- The pre-travel presentation must make the trade **legible**: what this
  destination offers AND what you are giving up by not taking the other (clear
  opportunity-cost framing), so the player feels the choice.
- Keep it honest to the sim: consequences fire in data
  (`routes.json` / `events.json`), determinism preserved. Coordinate with the
  sibling pass's backtracking rule (H-3) so "impactful" does not mean "you can
  never see the other place" — it means the choice costs something.

## Part 2 — The tutorial route branch

In the guided run, add the real fork the playtest asked for: **gas-station
casino** vs **straight underground**.
- Both branches are selectable, deterministic, and dead-end free (a caught or
  broke state still continues — see B-4 in the sibling pass).
- Each branch teaches through genuinely different early play per decision 2
  above, and both converge back into the tutorial's finale so no path is a
  worse tutorial.
- The choice is framed with the same opportunity-cost clarity as Part 1, and
  the coach explains it once without deciding for the player.

## Acceptance

- The pre-travel decision UI shows what each destination gives and what it
  costs; the choice visibly changes the run.
- The tutorial fork is playable both ways end to end, deterministic, no
  soft-lock, both converging to the finale.
- Determinism probe stable (same seed + same choices → same run). Before/after
  captures of the decision UI and each tutorial branch under `.tmp/`.

## Hard rules

- Real design and root cause, not flavor text over an unchanged loop.
  Determinism preserved (seeded; branch at action boundaries, never
  wall-clock). Zero-copy per-frame; idle liveness untouched. Tabs, typed
  GDScript, sparse comments. Player-facing copy follows
  `docs/plans/0.5_voice_bible.md`. Captures under `.tmp/`. Never revert or stage
  unrelated user-owned work.
- Commit in logical units (decision framing/system; tutorial branch; content).

## Gates (all must pass)

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (systems + ui)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_mouse_batch_playtest.ps1` (strict — no soft-locks)
- `tools\foundation_visual_qa.ps1`

## On completion

Only after every gate passes and both tutorial branches are confirmed playable
and soft-lock-free: commit per unit, then ARCHIVE this prompt (git mv
`docs/todo/` → `docs/todone/`) with an execution record (date, commit hashes,
the design choices taken, before/after captures, gate results), and report. If
blocked, stop at the last green commit, do NOT push, and report what remains.
