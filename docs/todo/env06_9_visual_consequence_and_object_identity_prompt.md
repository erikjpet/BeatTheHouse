Status: PARKED — do not claim until the owner sets the acceptance bar in section 3
Board row: `env06_9` in `docs/todo/README_0_6_board.md`
Origin: the two P1 findings from the `env06_8` second review (`REJECT 9c4196dd`, 2026-09-06)
Owner decision: `env06_8` was split on 2026-09-06; its structural half lands separately, this is its visual half

# Agent Prompt — 0.6 env06_9: Visual Consequence and Object Identifiability

**This row is parked.** It carries real, independently verified findings, but its
acceptance bar is a design decision the owner has not yet made. Do not start it,
and do not guess the bar. Section 3 holds the three questions that unpark it.

---

## 1. Why this row exists

The `env06_8` second review found, and an independent reviewer confirmed on ten
sampled contact sheets:

- **127 failures across 53/55 scenarios** on a completed production visual probe:
  45 unchanged settled-room rasters, 3 failed cue/event consumer receipts, 31
  missing action-definition receipts, 27 missing before/after rasters, 12 missing
  created objects, 9 projection failures.
- **Objects are not reliably identifiable without their labels** — sampled sheets
  repeatedly reuse generic note, screen and fixture glyphs.

`env06_8` was rejected twice against this bar before the owner determined the bar
was unreachable from that row's scope. The findings were never disputed. Only
their ownership changed.

## 2. Root cause — established, do not re-derive

Both findings share one mechanism in `scripts/ui/pixel_scene_canvas.gd`:

```gdscript
func _fallback_event_prop(visual_key: String, icon_key: String) -> String:
```

**Object `state` is not an input to prop selection.**

Consequences:

1. `change_scene_object` — the dominant scenario consequence handler, 360 uses —
   changes an object's `state`, which changes its `description_variants` entry
   and therefore its panel text. It **cannot** change the object's glyph. A
   settled-room raster is therefore byte-identical before and after the action,
   which is exactly the "45 unchanged settled-room rasters" finding.
2. Of 827 scenario object ops, **365 carry an authored `icon_key` and 462 do
   not.** Unauthored objects are routed by
   `EnvironmentInteractionController._scenario_icon_key()` into the synthesized
   key `"scenario_scene <label> <role>"`, which `_fallback_event_prop` resolves
   through a keyword ladder into a fixed vocabulary of roughly two dozen shared
   glyphs (`paper_note`, `room_barrier`, `room_seating`, `room_signal`,
   `room_refreshment`, `room_surface`, `room_storage`, `room_display`,
   `room_vehicle`, `room_hazard`, `room_fixture`, …). Many distinct objects
   collapse onto the same glyph.

A replication of the first seven keyword rules put roughly 300 distinct object
labels in the generic tail. Treat that as an **upper bound**, not an exact count —
the real ladder has more rules. Re-derive it properly when this row is claimed.

**The implication for scoping:** this is renderer and art work, not scenario-data
work. Fixing it means either teaching prop selection to read `state`, authoring
`icon_key` for the unauthored objects, expanding the glyph vocabulary, or some
combination. That is why it is its own row.

## 3. Owner questions — this row stays parked until these are answered

1. **What counts as "visible consequence"?** The owner's original `env06_8`
   ruling said acting on an object must produce "a conversation, an item, a
   change in the room. Never a silent flip." Does a changed panel description
   satisfy that, or must the object's glyph change in the room raster? If the
   latter, `_fallback_event_prop` must take `state`, and every state-bearing
   object needs at least two visual states.
2. **How much distinct art?** How many of the 462 unauthored object ops need
   their own glyph, versus a shared glyph plus a distinct label being acceptable?
   A per-object answer is an art program; a "top N most-seen objects" answer is a
   contained pass.
3. **Is this 0.6 scope at all?** The alternative is the post-playtest polish
   pass, alongside `voice06_1`. Distinct per-object art is exactly the kind of
   thing the owner's own playtest is best placed to prioritize — they will know
   which rooms actually feel indistinct in play.

Record the answers here before claiming the row.

## 4. Known-good scope boundary when this row is claimed

Owns: `scripts/ui/pixel_scene_canvas.gd` prop/glyph selection, the icon
vocabulary, and `icon_key` authoring in
`data/environments/scenario_sequences/*.json`.

Must not change: money, RNG, RTP, payouts, odds, schema, migration, scenario
handlers, zoning, or any structural guarantee that the re-scoped `env06_8`
established. Those are landed and independently accepted; this row is additive.

## 5. Evidence that already exists

- The second-review escalation record: `docs/plans/env06_8_second_review_escalation.md`
- The rejected candidate and its full gate record: `9c4196dd`, preserved on
  `codex/env06_8-clean`
- Four orphaned visual-evidence harnesses on branch `codex/closeout06-final`:
  `env06_8_environment_geometry_check.gd`, `env06_8_hidden_boundary_check.gd`,
  `tools/env06_8_all_scenario_contact_sheet_probe.gd`,
  `tools/env06_8_capture_contact_sheets.ps1`.
  **They call contract functions that no longer exist** and will break the
  177-file load gate if imported unmodified. They are safe on that branch;
  reconcile their API before reusing them. The owner's standing default is **not**
  to port the alternate contract they belong to.

## 6. Standards this row inherits

- **Idle draw cost of 0.000 is a failure, not a pass.** The counter-gate in
  `scripts/ui/performance_liveness_guard.gd` is mandatory wherever a surface is
  touched. Four recorded regressions, and this row touches the renderer.
- **No per-frame deep copies.** The slot bonus watchdog once cost 32.6 ms/frame.
- **Hidden state is absolute.** A glyph must never reveal Turn, traitor,
  grievance, rigged-draw or unrevealed-ticket state. A leak is an automatic P0.
- **Any harness that travels between rooms must finalize on arrival** exactly as
  the production host does, or it will produce false failures. Four recorded
  incidents.
- Never weaken a test, budget, liveness floor, or deterministic assertion to go
  green.
