# Agent Prompt — Final Performance & Cleanup Audit (No Stutter, Hangs, or Slowdown)

## 2026-08-03 queue reconciliation

This prompt remains **OPEN**. The prior execution produced
`docs/plans/0.5_performance_audit.md`, fixed several defects, and passed every
recorded gate except the binding full retained-state soak. The final slope was
279,116.400 bytes/sample against the unchanged 262,144-byte/sample limit, so
the report correctly remains **NOT RELEASE-READY**.

The primary worktree now contains later uncommitted integration work including
Scratch Ticket receipt/mask compaction, portable ticket state, tutorial/
TalkDock/UI changes, SFX changes, and new probes. Integrate it through
`current_worktree_integration_gate_recovery_prompt.md` before rerunning the
final audit verdict.

The independent 2026-08-03 real-interface Web tutorial playtest also observed
a main-thread blocking warning during launch. Reproduce, measure, and
root-cause it as a performance follow-up. Do not claim it caused the tutorial
opening soft-lock without evidence.

Additional binding requirements for the resumed audit:

- Test the exact final integrated release-candidate source, not the earlier
  audit worktree or a partially dirty snapshot.
- Prove completed Scratch Ticket compaction is backward-compatible,
  deterministic, bounded, and improves retained memory rather than only
  serialized JSON size.
- Repeat the full 180-minute/504-action soak after integration and tutorial
  completion; short diagnostic soaks cannot close the blocker.
- Keep the 262,144-byte/sample budget unchanged. Do not relabel allocator
  growth harmless without bounded proof accepted by the owner.
- Refresh every gate below because the 2026-07-31 evidence is historical after
  later source changes.
- Add a dated resumed-audit section to the existing performance report with
  final before/after evidence and a truthful new verdict.

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike shipping 0.5 to Web/itch.io and Windows. This is the FINAL
pre-release performance and cleanup pass: drive the whole game as a player
would and make sure it runs SMOOTH everywhere — no stutter, no hitches, no
hangs/freezes, no slowdown over a session — then fix what you find and do a
bounded cleanup. This game has a documented history of two performance
failure modes that keep recurring; this pass is the last guard against them
shipping:
- **Per-frame deep copies / allocation in hot paths** (a measured 32.6 ms/
  frame regression once came from a per-frame `duplicate(true)`).
- **Idle-animation liveness regressions** (shipped FOUR times: an "idle
  optimization" freezes table/scene animation because a 0.000 idle-draw was
  accepted without the liveness floor).

Recent large reworks (video poker cabinets, scratch tickets, the Grand Casino
rooms/Cage, meta home) added new hot surfaces that must be verified.

## Part A — Typical-play smoothness hunt (find every stutter/hang/slowdown)

Drive the game end-to-end, repeatedly, watching for ANY frame spike, hitch,
hang/freeze, or gradual slowdown, using the existing tooling plus manual play:
`tools\foundation_mouse_batch_playtest.ps1` (strict), `foundation_mouse_
playtest.ps1`, `foundation_soak_probe.ps1`, and manual play across EVERY
surface — all eight games (especially the reworked video poker and scratch
tickets), every room (corner store → tier-2 → Grand Casino Main Floor/High-
Limit/Cage/Back Room), the meta home and its map, all popups/overlays
(events, wager, inventory, journal, map, cage window, coach bubbles, run
report, bag-open reel). For each: no dropped frames on interaction, no
momentary freeze on a transition, and no slowdown as a session goes long.
Log every `ERROR:`/`SCRIPT ERROR:` seen during play — each is a defect.
Produce a defect list with the surface, the repro, and a frame-time capture.

## Part B — Per-frame allocation / hot-path audit (the recurring killer)

Audit every allocation reachable from a per-frame path — `_process`,
`_physics_process`, `_draw`, `queue_redraw` handlers, and the surface-snapshot
builders that run each frame — across `scripts/games/` and `scripts/ui/`.
Known concentration (verify which are actually per-frame vs action-boundary):
`video_poker.gd` (~26 `duplicate(true)`), `scratch_tickets.gd` (~12),
`game_surface_canvas.gd`, `pixel_scene_canvas.gd`, `foundation_main.gd`
(~84 — mostly action-boundary; confirm). ANY `duplicate(true)`, deep copy,
dictionary/array rebuild, or texture regeneration that runs EVERY FRAME is a
defect — hoist it to change-time, cache it, or make it zero-copy. Prove the
hot paths are allocation-free with a counter/spy assertion (e.g. snapshot/
copy counters do not advance across N idle frames on each surface).

## Part C — Idle-animation liveness (never game the zero)

Run `tools\foundation_performance_probe.ps1` and confirm EVERY animated idle
surface both meets its frame budget AND advances its liveness floor
(`GAME_IDLE_LIVENESS` in `foundation_performance_probe.gd`). A 0.000 idle-draw
with a stalled liveness counter is a FAIL, not a pass — the only legitimate
zeros are the documented static idles. Verify the newly reworked surfaces
(video poker cabinets, scratch machine/tickets) have correct liveness floors,
not accidental zeros.

## Part D — Per-surface frame budgets

Measure avg/p95/max for every game surface, room, popup, and overlay via the
performance probe. Anything over `MAX_SURFACE_DRAW_P95_MS` (5.0) or the
low-end frame budget (16.6 ms) is fixed at the cause. Do NOT relax a budget to
pass — a budget change requires measured before/after evidence that the game
did not get slower, documented in the commit. Report the full budget table.

## Part E — Hangs / hitches (main-thread blocking)

Find and fix anything that blocks a frame during play: save writes, snapshot
builds, the scratch mask rasterization, multi-hand deck shuffles, texture/icon
generation, an RTP/audit routine accidentally reachable at runtime, or any
sync loop that scales with state. A visible freeze on deal/scratch/travel/
save is a defect. Move heavy work off the interaction frame (precompute,
cache, or defer) without changing behavior or determinism.

## Part F — Web export performance (the itch target)

First impressions happen in the browser. Run `tools\web_perf_smoke.ps1` (and
`l02_web_perf_probe.mjs` / `serve_web.ps1` if useful) and verify: acceptable
cold load, smooth sustained play over a long session, no memory growth trend,
and the web audio bridge not spiking frames. Fix web-specific slowdowns.

## Part G — Memory / leak soak

Run `tools\foundation_soak_probe.ps1` and check for unbounded growth over a
long session — story log/history caps holding, snapshot churn not leaking,
texture/icon caches bounded, RngStream/objects not accumulating. Fix any
growth trend.

## Part H — Cleanup (bounded)

- Remove leftover debug `print()`/`prints()` in shipping scripts (verified
  hits: `pixel_scene_canvas.gd`, `save_service.gd` — keep legitimate
  `push_error`/`push_warning`, remove stray prints; `perf_telemetry_overlay.gd`
  is a dev overlay, leave its intentional output but confirm it is gated off
  in normal play).
- Remove dead hot-path code and redundant per-frame work you find; tidy.
- Report larger refactors as follow-up prompts rather than doing them here —
  this pass is performance + tidy, not architecture.
- Do NOT delete anything under `.tmp/`, `.tools/`, or `builds/` (owner keeps
  these).

## Hard rules

- Zero-copy per-frame is binding; idle-animation liveness may never be gamed
  (no accepting a 0.000 idle without the floor). Determinism unchanged
  (seeds→hashes identical); any fix that could shift simulation is out of
  scope — report it. Fix causes, never weaken a test or budget to go green.
- Style: tabs, typed GDScript, sparse comments; the performance report and
  captures under `.tmp/`. Suite timeout = max(300s, ceil(recorded baseline ×
  1.5)). Working tree may contain uncommitted user-owned work; never revert or
  stage it.

## Deliverable

`docs/plans/0.5_performance_audit.md`: the defect list (surface, repro,
before/after frame time), the hot-path allocation findings + fixes, the full
per-surface budget table, the web + soak results, the cleanup summary, and a
plain verdict on whether typical play is smooth everywhere.

## Gates (all must pass)

- `tools\validate_project.ps1`
- every supported `-FoundationSuite`
- `tools\foundation_performance_probe.ps1 -RequireGodot` (budgets + liveness)
- `tools\foundation_soak_probe.ps1 -RequireGodot`
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\web_perf_smoke.ps1`
- `tools\foundation_mouse_batch_playtest.ps1` (strict) — smooth, zero errors
- `tools\foundation_visual_qa.ps1`

## On completion

Only after every gate passes AND typical play is confirmed smooth everywhere
(no stutter, hangs, or slowdown):

1. Commit in logical units (per-surface fixes; hot-path de-allocation;
   hitch/hang fixes; cleanup).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   budget table, defects fixed, gate results), and stage the move.
3. PUSH to the remote.
4. Report: the defect list and fixes, the before/after budget table, the
   web/soak results, the cleanup summary, and your honest verdict on
   smoothness.

On an unfixable gate or a slowdown you cannot resolve, stop at the last green
commit, do NOT push, and report exactly what still stutters/hangs/slows.
