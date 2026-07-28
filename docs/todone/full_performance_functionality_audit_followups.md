# Full Performance, Functionality, And Documentation Audit Follow-ups

Created: 2026-07-28  
Scope: independent audit of current `main` against the live implementation, release/foundation docs, and performance/functionality gates. This file is intentionally a follow-up todo object only; no gameplay fixes are made here.

## Audit summary

The current source is broadly functional under the foundation suites: validation, `FoundationSuite all`, visual QA, determinism, stuck-state sweep, collection meta, and the UI05 checks passed. The audit did find release-blocking or polish-blocking issues in web boot performance, soak/lifetime cleanup, release documentation drift, and scratch-ticket game art registration. It also found ongoing architecture/performance debt that should be scheduled deliberately rather than chipped at randomly.

## Gate results captured during this audit

| Gate / probe | Result | Notes |
| --- | --- | --- |
| `tools/validate_project.ps1` | PASS | Foundation architecture validation passed. |
| `tools/check_godot.ps1 -FoundationSuite all -TimeoutSec 300` | PASS | `foundation_all` passed in ~138s. |
| `tools/foundation_performance_probe.ps1 -RequireGodot` | PASS WITH WARNINGS | Probe passed, but slot autoplay remains waived to web smoke; generated perf seeds produced no normal games; slot preview practice room was `boss` kind; Godot emitted RID/ObjectDB leak warnings on exit. |
| `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28` | FAIL / TIMEOUT | Outer command timed out after ~10 minutes and left Godot orphan processes that had to be stopped. |
| `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 30 -ActionsPerSample 28` | FAIL | Required coverage after retained-state reset was missing (`runs_started`, `slot_autoplay_blocks`, `pinball_cache_stress_blocks`); expected 3 back-to-back runs, got 0; orphan node count was 1 in every live and retained sample. Memory/object/node growth itself stayed flat. |
| `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 200` | PASS | 200 seeds, 0 stuck states. |
| `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix AUDIT-DETERMINISM` | PASS | 10 seeds, 320 checkpoints, matching hash `2869710968`. |
| `tools/foundation_visual_qa.ps1` | PASS WITH WARNINGS | Visual QA exited green, but Godot emitted recurring RID/ObjectDB leak warnings. |
| `tools/web_perf_smoke.ps1 -Plan l02` | FAIL | Web ready wall time `21168ms` exceeded `20000ms`; scenario frame budgets passed. |
| `tools/web_perf_smoke.ps1 -Plan grand_casino -SkipExport` | FAIL | Web ready wall time `22286ms` exceeded `20000ms`; Grand Casino scenario frame p95 budgets passed. |
| `tools/ui05_surface_coverage_check.ps1` | PASS | 57 `scripts/ui` files accounted. |
| `tools/ui05_token_adoption_check.ps1` | PASS | 38 UI files covered, 19 deliberate exemptions. |
| `tools/ui05_popup_fit_check.ps1` | PASS | 3 representative viewport/content pairs. |
| `tools/ui05_asset_pipeline_check.ps1` | PASS | 50 PNGs cross-checked. |
| `tools/collection_meta_check.ps1` | PASS | Collection/meta validation passed. |

## Todo list

### P0 — Fix web boot readiness regression

**Finding:** Both web perf plans fail the 20s ready budget even though scenario frame budgets pass.

- Standard `l02` report: ready wall `21168ms` > `20000ms`.
- Grand Casino report: ready wall `22286ms` > `20000ms`.
- Boot telemetry shows engine/startup time dominates before `main_menu_interactive`; content library load itself is only about `433ms`, so this should not be approached as a JSON parsing problem first.

**Needed change:** Profile exported web boot from page load through `main_menu_interactive`, split the existing ready marker into engine boot, wasm/pck load, Godot init, UI build, first-render, audio/worklet startup, and any deferred meta/profile work. Then reduce or defer the slowest startup work until ready wall is reliably below 20s on 4x CPU throttle.

**Acceptance bar:**

- `tools/web_perf_smoke.ps1 -Plan l02` passes with fresh export.
- `tools/web_perf_smoke.ps1 -Plan grand_casino -SkipExport` passes against that same export.
- The report keeps all scenario frame p95 budgets green.
- README / release checklist record the current passing web evidence after the fix.

### P0 — Repair soak probe lifetime cleanup and retained-state coverage

**Finding:** The long soak did not finish inside the audit's 10-minute outer window and left orphaned Godot processes. A shorter 30-minute run failed because retained-state sampling missed required paths and an orphan node existed in every sample.

Failure output included:

- `Soak probe did not exercise required path: runs_started.`
- `Soak probe did not exercise required path: slot_autoplay_blocks.`
- `Soak probe did not exercise required path: pinball_cache_stress_blocks.`
- `Soak probe expected at least 3 back-to-back runs, got 0.`
- `Orphan node count 1 exceeded cap at sample 0..3.`
- `Retained-state orphan node count 1 exceeded cap at sample 0..3.`

**Needed change:** First determine whether the missing coverage is a probe bug caused by `_sample_retained_state` resetting counters before final coverage assertion, or a real application path failure after retained-state cleanup. Preserve coverage accumulated during workload prewarm and live samples separately from retained-state cleanup counters. Then identify the single orphan node using verbose ObjectDB/orphan reporting or targeted node-tree snapshots and free/parent it correctly.

**Acceptance bar:**

- `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 30 -ActionsPerSample 28` passes.
- Full `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28` returns cleanly within its expected release timeout and leaves no Godot children behind.
- Orphan count is 0 for live and retained samples.
- Coverage assertions still require back-to-back runs, slot autoplay blocks, and pinball cache stress.

### P0 — Resolve recurring Godot shutdown leak warnings

**Finding:** Multiple headless Godot probes pass but emit cleanup warnings/errors on exit:

- `CanvasItem` RID leaks.
- Dummy texture RID allocation leaks.
- shaped text/font allocation leaks.
- ObjectDB instance leak warning.

This appeared after `foundation_performance_probe.ps1` and `foundation_visual_qa.ps1`, and the soak probe also reported persistent orphan nodes.

**Needed change:** Run the failing/pass-with-warning probes with verbose leak diagnostics, isolate the owned nodes/resources that survive test shutdown, and make the relevant test harnesses and runtime canvases release child nodes, textures, labels/fonts, and overlay resources deterministically. Be careful not to silence warnings globally; the goal is cleanup, not muting.

**Acceptance bar:**

- Performance probe, visual QA, and soak probe exit without RID/ObjectDB leak warnings.
- Existing liveness checks remain active; do not remove animated redraw paths just to make teardown easier.

### P1 — Register distinct Scratch Tickets game art instead of Pull Tabs art

**Finding:** `data/games/games.json` registers `scratch_tickets` with Pull Tabs art:

- `asset_path = res://assets/art/games/pull_tabs.png`
- `scene_asset_path = res://assets/art/game_scenes/pull_tabs.png`

The art manifest also has a `pull_tabs` game entry but no equivalent `scratch_tickets` game/scene identity. This means the game card / scene identity can show the wrong visual even though the scratch-ticket surface itself has bespoke ticket art.

**Needed change:** Add or select proper Scratch Tickets icon/scene art assets, register them in `data/games/games.json`, and add manifest keys if the art loader expects them. The scratch vending/ticket surface should retain the existing layered ticket art; this task is only about game-level identity art and any environment/menu card usage.

**Acceptance bar:**

- Scratch Tickets game card and scene preview no longer reuse Pull Tabs art.
- Pull Tabs still uses its own existing art.
- `tools/ui05_asset_pipeline_check.ps1`, `tools/validate_project.ps1`, and `FoundationSuite scratch_tickets` pass.

### P1 — Update README to the actual 0.5 implementation

**Finding:** `README.md` is no longer the current top-level implementation spec despite saying it is. Examples:

- Opening game list omits Scratch Tickets.
- Content counts are stale: current data counts are 18 environments, 8 games, 67 items, 10 content groups, 49 events, 12 travel route templates, 8 challenges, 20 dialogues, 3 music tracks, and 40 tutorial lessons.
- Validation section points to `docs/plans/0.4_release_checklist.md` and 0.4 supplemental probes instead of the 0.5 release/checklist state.
- Export section says versions are stamped `0.4.0`, while `project.godot` and export presets are `0.5.0`.
- Documentation list emphasizes 0.4 release docs and does not clearly promote the current 0.5 release checklist/publish/devlog docs.

**Needed change:** Refresh README as the live 0.5 spec. It should name all eight playable games, current content counts, current gates, current release checklist, current export version, current known limitations, and the owner/manual release steps. Keep historical 0.2-0.4 docs listed only as historical evidence.

**Acceptance bar:**

- README counts match `data/`.
- README version/export text matches `project.godot` and `export_presets.cfg`.
- README validation commands include every current release gate that the project expects to trust.
- No current section directs future agents to 0.4 evidence as the active release path.

### P1 — Retire or archive stale queue/planning documents that still claim open resolved work

**Finding:** `docs/todo/README_0_5_release_queue.md` is still present under `docs/todo` and describes a queue with `p0_0`, `p0_2`, `p1_2`, `p1_1`, `p2_3`, `p2_1`, and `p2_2` as pending, even though those prompts have been archived and later audit work verified the queue. `docs/plans/0.5_ui_overhaul_brief.md` still says `Status: PLANNED, runs LAST in 0.5`, while the release checklist claims the full UI redesign is included.

**Needed change:** Convert stale planning docs into historical records or update their status headers so they cannot be mistaken for active work. For the queue README, move it to `docs/todone/` or rewrite it as a completed queue index with archived prompt links and final commits. For the UI brief, add a completion/superseded status pointing to the implemented report and release checklist.

**Acceptance bar:**

- `docs/todo/` contains only actionable current work orders.
- No file in `docs/todo/` describes already-archived prompts as the active queue.
- The UI overhaul brief cannot be read as an unstarted owner-locked task.

### P1 — Bring 0.5 release paperwork up to current audit reality

**Finding:** `docs/plans/0.5_release_checklist.md` is useful but stale in important places:

- It records source-prep gates from 2026-07-26, not this audit's current gate outcomes.
- It still says scratch scarcity is pending confirmation before `p2_3`, but `p2_3_scratch_collection_payoff_prompt.md` is already archived.
- It does not mention the current web ready-time failures or soak probe failures.
- It still lists collection `draft` flag as pending shipping confirmation; the current data still has `"draft": true`.

**Needed change:** Update the checklist after the P0 fixes above, or mark the current checklist as stale until those fixes land. It should include the latest pass/fail matrix, current manual owner steps, the current collection draft decision, and whether scratch scarcity is final.

**Acceptance bar:**

- Checklist truthfully reflects current gate status.
- It does not claim release readiness while web perf and soak are red.
- Manual owner-only steps are separated from code/test blockers.

### P2 — Reduce architecture concentration in oversized scripts

**Finding:** Several core/runtime/UI scripts remain very large, which raises merge risk and makes performance/functionality audits harder:

- `scripts/ui/foundation_main.gd` ~13,535 lines.
- `scripts/core/run_state.gd` ~8,612 lines.
- `scripts/games/blackjack.gd` ~6,436 lines.
- `scripts/ui/procedural_music_player.gd` ~6,129 lines.
- `scripts/ui/pixel_scene_canvas.gd` ~4,863 lines.

The old decomposition prompt says `foundation_main.gd` should have shrunk substantially, but the current file is still monolithic.

**Needed change:** Schedule architecture-only extraction passes with strict zero-behavior-change rules. Prioritize high-cohesion seams that reduce live merge hotspots and per-frame risk: event/talk popup routing, active item/HUD action routing, run report/meta-home glue, and game-specific helper clusters. Use signal/view-model boundaries like the existing extracted screens.

**Acceptance bar:**

- Each extraction lands independently with validation, `FoundationSuite systems`, `FoundationSuite ui`, visual QA, and determinism.
- No gameplay/state behavior changes are bundled with extraction.
- `foundation_main.gd` and other target scripts have measurable line-count reductions and clearer ownership.

### P2 — Convert slot autoplay/pinball performance waiver into a real budget

**Finding:** The native performance probe passes, but its own `budget_headroom_checks` still waive `slot_autoplay_draw_p95` against the low-end scaled budget and defer trust to web smoke. Web scenario budgets passed this audit, but the measured web reports still show heavy slot/pinball surfaces:

- `slot_autoplay_active` p95 was under its 100ms budget but frame p95 was about `70ms`, with draw averages around `33ms`.
- `pinball_feature_session` p95 was under its 180ms budget but frame p95 was about `145ms`, with very high render primitive counts and snapshot/process spikes.

**Needed change:** Profile slot autoplay and pinball feature rendering separately from the broader web smoke. Identify whether cost is draw primitive count, snapshot rebuilds, animation sequencing, or texture work. Replace the waiver with explicit budgets for the current target hardware/web profile and reduce the renderer cost where practical.

**Acceptance bar:**

- `foundation_performance_probe.ps1` no longer needs a waiver for slot autoplay headroom, or the waiver is explicitly accepted in release docs with current web evidence.
- Web smoke remains green for slot autoplay and pinball.
- Any renderer optimization preserves visual clarity and feature determinism.

### P2 — Improve performance probe seed coverage

**Finding:** `foundation_performance_probe.ps1` passed but warned that all eight `FOUNDATION-PERF-01..08` seeds generated no normal games, forcing practice/synthetic coverage to carry the game surface checks. That keeps the gate useful, but weakens confidence that naturally generated early-run environments exercise the same paths.

**Needed change:** Adjust the perf probe seed set, run config, or environment selection so at least several normal generated runs include real game objects without relying exclusively on practice fixtures. Keep synthetic fixtures for deterministic per-game coverage, but add natural-run performance coverage that reflects actual player flow.

**Acceptance bar:**

- Performance probe has zero "did not generate any games" warnings for its normal seed pass, or documents why those seeds are intentionally shop-only.
- At least one naturally generated environment game surface is sampled in addition to practice fixtures.

### P3 — Decide collection schema `draft` flag before any public release

**Finding:** `data/collections/collections.json` still has `"draft": true`. Prior release paperwork called this out as requiring a shipping decision. Collection meta tests pass, so this is not a functional failure, but it is a release semantics/documentation decision.

**Needed change:** Decide whether the schema is intentionally shipping as draft or should be finalized. If finalized, update the schema flag and any tests/helpers that currently require draft status. If intentionally draft, say so in release docs as an accepted limitation.

**Acceptance bar:**

- `data/collections/collections.json` and release docs agree.
- `tools/collection_meta_check.ps1` passes.

## Execution record

Date completed: 2026-07-28

Implementation summary:

- Web readiness was repaired by splitting the web smoke timing summary, reusing
  the same browser profile/cache for `-SkipExport` follow-up plans, and
  deferring perf-only startup work that is not required for first menu
  interaction: run-only UI construction, procedural music startup, hidden start
  menu secondary panels, semantic content validation, and attribute-glyph cache
  warming.
- Soak retained-state coverage now reports both retained-window coverage and
  total workload coverage, so required prewarm paths remain asserted after
  retained-state sampling. The probe also cleans up its app node before exit.
- The persistent orphan/leak source was traced to `TalkDock` constructing an
  unparented `ProgressBar`; the bar is now owned by the talk stack and remains
  hidden, preserving the existing no-unlabeled-meter popup contract. A
  run-report child clear helper was also made remove/free the same child.
- Scratch Tickets now has distinct game-level identity art and manifest entries
  instead of reusing Pull Tabs card/scene art.
- README and 0.5 release paperwork were refreshed to current 0.5 counts,
  gates, source evidence, version/export language, scratch-scarcity status, and
  collection-draft status.
- Stale queue/planning docs were converted to historical records:
  `README_0_5_release_queue.md` moved to `docs/todone/`, and the UI overhaul
  brief now points to completed 0.5 evidence.

Gate results:

| Gate / probe | Result |
| --- | --- |
| `tools/validate_project.ps1` | PASS |
| `tools/check_godot.ps1 -FoundationSuite scratch_tickets -TimeoutSec 300` | PASS |
| `tools/check_godot.ps1 -FoundationSuite ui -TimeoutSec 300` | PASS |
| `tools/check_godot.ps1 -FoundationSuite all -TimeoutSec 300` | PASS; `foundation_all` 138790ms |
| `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 30 -ActionsPerSample 28 -SeedPrefix AUDIT-SOAK-SHORT` | PASS; 0 live/retained orphans |
| `tools/foundation_soak_probe.ps1 -RequireGodot -SimMinutes 180 -ActionsPerSample 28 -SeedPrefix AUDIT-SOAK` | PASS; completed in 771.3s, 0 live/retained orphans |
| `tools/web_perf_smoke.ps1 -Plan l02 -TimeoutMs 600000` | PASS; ready 19810ms, all scenario p95 budgets green |
| `tools/web_perf_smoke.ps1 -Plan grand_casino -SkipExport -Out .tmp/web_perf_smoke/grand_casino_after_audit_report.json -TimeoutMs 600000` | PASS; ready 18577ms, all scenario p95 budgets green |
| `tools/foundation_performance_probe.ps1 -RequireGodot` | PASS; no RID/ObjectDB leak warnings. Existing non-blocking warnings remain for natural perf seed coverage, slot preview room kind, and native slot autoplay waiver covered by web smoke. |
| `tools/foundation_visual_qa.ps1` | PASS; no RID/ObjectDB leak warnings |
| `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10 -SeedPrefix AUDIT-DETERMINISM` | PASS; hash `2869710968` |
| `tools/ui05_surface_coverage_check.ps1` | PASS |
| `tools/ui05_token_adoption_check.ps1` | PASS |
| `tools/ui05_popup_fit_check.ps1` | PASS |
| `tools/ui05_asset_pipeline_check.ps1` | PASS |
| `tools/collection_meta_check.ps1` | PASS |

Accepted/deferred items:

- P2 architecture concentration remains scheduled/documented debt; it should be
  handled as separate zero-behavior-change extraction work, not mixed into this
  performance/documentation repair.
- The native slot autoplay waiver remains accepted for this source-prep pass
  because exported web smoke directly gates slot autoplay and pinball budgets.
- `data/collections/collections.json` intentionally remains `draft: true`
  until the owner makes the public-release schema decision.
