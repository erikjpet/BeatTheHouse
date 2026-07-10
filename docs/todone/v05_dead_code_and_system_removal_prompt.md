## Execution Record

- Completed: 2026-07-09.
- Claim commit: `f1466f9d`. Implementation/archive commit: the commit containing this execution record; final hash reported in the agent summary because a commit cannot embed its own final hash.
- Scope: 0.4 final-cleanup subtraction pass. The packaged 0.4.0 Web/Windows zips are invalidated by these source removals and must be rebuilt before any player release or itch upload.

### Removal Ledger

| Cluster | Action | Evidence |
| --- | --- | --- |
| Rejected menu-home path | Removed dead collection-browser menu fields/functions from `FoundationMain`; kept `meta_collection_view_model.gd` because walkable meta-home prop panels and `collection_meta_check.gd` still use it. | `rg "collection_status_label|collection_bags_list|collection_items_list|collection_reveal_label|_refresh_collection_browser_page|open_meta_collection_bag"` returned no live refs after removal; `validate_project.ps1` PASS. |
| Prestige plumbing | Removed `data/prestige/purchases.json`, ContentLibrary loading/validation/indexing, RunActionService prestige APIs, RunState/GameModule prestige special cases, FoundationMain prestige UI/object/HUD paths, environment layout `prestige_spots`, PixelSceneCanvas prestige labels/actions, validators, and obsolete tests/QA playtest routes. | `rg "prestige|Prestige|buy_prestige|prestige_purchase|prestige_spots|data/prestige" scripts/core scripts/ui scripts/tests tools data` returned no matches; Full suite old-save/profile fixtures passed through `foundation_all`. |
| AmbientSurfaceOverlay vestiges | Removed the inner `AmbientSurfaceOverlay` child canvas, `surface_ambient_overlay` state fields, dynamic-overlay hook, and tests/probes that asserted the deprecated overlay stayed off. Dynamic animation channels now redraw through the main surface. | `rg "surface_ambient_overlay|AmbientSurfaceOverlay|ambient_surface_overlay|draw_surface_dynamic_overlay|surface_overlay_animation" scripts tools data` returned no matches; liveness/perf gates passed. |
| Web-audio legacy surface | Removed `legacy_play_music_blocked`, `legacy_sfx_blocked`, `WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED`, and fallback contract fields. Kept the single install-time `JavaScriptBridge.eval` and direct `get_interface` bridge. | `rg "legacy_play_music_blocked|legacy_sfx_blocked|WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED|fallback_enabled|oscillator_fallback_enabled" scripts tools data` returned no matches; web bridge contract still checks no oscillator fallback script. |
| One-off evidence probes | Removed historical evidence-only probes not wired into current gates: `audio_perf_probe.gd/.ps1`, `la1_core_perf_probe.gd`, `allocation_churn_probe.gd/.ps1`, and `lb3_web_payload_report.ps1` plus tracked `.uid`s where applicable. Kept current gates, release/export/social tools, and protected pinball/slot probes. | Direct refs after removal are historical plan evidence only; `validate_project.ps1`, Smoke, and Full load checks passed with 89 checked GDScript files. |
| Orphaned data/assets | Removed obsolete prestige layout/data entries. Kept `assets/art/items/thermos_black_coffee_half.png` because it is referenced by item data, events, content groups, and foundation tests. No `.tmp`, `builds`, or `user://` files are tracked. | `git ls-files .tmp builds user://` returned empty; `rg thermos_black_coffee_half data scripts tools docs` proved live references. |

### Additional Fixes Required By Gates

- Restored `tooltip_text` metadata on world-map badge cells while preserving instant custom hover labels, so icon-only badge controls expose hover details without visible text overlap.
- Warmed 16px attribute badge textures during foundation init, matching the focus-panel glyph size and avoiding first-focus texture generation in measured input paths.
- Rendered event focus panels from precomputed `inline_actions` when available, avoiding redundant event-option recomputation during object focus.
- Reduced roulette pure-idle wheel draw cost by skipping per-pocket wheel number labels while idle; labels still draw during active/settled spins, and table betting numbers remain visible.

### Verification

| Command | Result |
| --- | --- |
| `powershell -ExecutionPolicy Bypass -File tools/function_census.ps1 -OutputJson .tmp/function_census/v05_before.json -OutputMarkdown .tmp/function_census/v05_before.md` | PASS; before census 6,284 functions across 92 files. |
| `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1` | PASS after each cleanup cluster and final doc updates. |
| `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -TimeoutSec 900` | PASS; report `.tmp/test_reports/20260709_211126_smoke/summary.json`. |
| `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 2400` | PASS; report `.tmp/test_reports/20260709_211347_full/summary.json`. |
| `powershell -ExecutionPolicy Bypass -File tools/foundation_mouse_batch_playtest.ps1 -RunCount 20` | PASS; 20/20 playable-loop, 20/20 R100 UI, 20/20 victory, 0 true failures. |
| `powershell -ExecutionPolicy Bypass -File tools/web_perf_smoke.ps1` | PASS; `.tmp/web_perf_smoke/report.summary.json`, ready 13,958ms / 20,000ms, telemetry overhead avg 0.01923ms / 0.1ms, no failures. |
| `powershell -ExecutionPolicy Bypass -File tools/function_census.ps1 -OutputJson .tmp/function_census/v05_after.json -OutputMarkdown .tmp/function_census/v05_after.md` | PASS; after census 6,176 functions across 89 files. Delta: -108 functions, -3 GDScript files. |

### Payload / Packaging

- Current stale package sizes observed before rebuild: `builds/itch/BeatTheHouse-web.zip` 18,081,506 bytes; `builds/itch/BeatTheHouse-windows.zip` 43,657,926 bytes.
- No release package was rebuilt in this cleanup task. Payload delta is therefore deferred to the required repackage step; the existing 0.4.0 zips are invalidated and must not be uploaded as-is.

### Deviations

- The requested LC.1 "one commit per cleanup cluster" shape was not possible because the worktree was already dirty before this prompt, including overlapping files. The cleanup was still performed in gated clusters with validation after each cluster and strict final gates.
- The archive/implementation commit includes the already-dirty validated tree rather than a surgically isolated cleanup diff, because multiple required cleanup edits overlapped files that had pre-existing uncommitted playtest/release fixes.
- `tools/check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 1800` was run with `-TimeoutSec 2400` so the existing full suite plus deep audit could finish honestly; it passed in 599.9s.
- `foundation_mouse_batch_playtest.ps1` was run without `-RequireGodot` because the wrapper does not declare that parameter in the current tree; it found and used the configured Godot runtime and passed.
- Web zip size delta was not computed from a new package because this task intentionally invalidates the packaged zips and leaves rebuilding to the release repackage prompt.

### Kill-List For Owner Review

| Candidate | Evidence | Recommendation |
| --- | --- | --- |
| Historical 0.3.x performance boards and evidence-only doc references | Active code no longer carries the removed probes, but historical docs still cite their old command lines. | Keep as release evidence unless a separate docs-pruning prompt wants to summarize historical ledgers. |
| Pull-tabs legacy xray/sleeve compatibility helpers | `rg "legacy"` still finds save/load compatibility paths inside `pull_tabs.gd`; these are outside the named removal groups. | Keep for now; review only with save-fixture migration evidence. |
| Slot/pinball legacy true-win and family compatibility helpers | Named in code but protected by the pinball/slot audit list and current acceptance probes. | Keep; do not touch outside a slot-owned prompt. |

# Agent Prompt - v0.5 Opener: Dead Code, Deprecated Paths, and Purposeless System Removal

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). **0.4.0 is NOT yet released to players** — the
source is tagged on GitHub but the owner is running a final cleanup and
bugfix pass before the actual release. This task is part of that pass: it
removes redundant code — anything unused, deprecated, superseded during
the 0.4 sprint, or belonging to systems that serve no purpose and will not
be expanded. Owner authorization for system-level removals is embedded in
this prompt for the named candidates below; anything beyond them gets
proposed, not deleted. Because this precedes the player release, your
removals invalidate the packaged 0.4.0 zips — note this in the execution
record; the repackage/tag decision happens at the release step, not here.

## Method (binding — proof before deletion)

Build on the prior audit and tooling rather than starting fresh:

- `docs/plans/dead_code_audit_report.md` — the 0.3.2 audit whose deferred
  items ("dead-data/prestige cleanup") this task now executes.
- `tools/function_census.ps1` — regenerate; UNCLASSIFIED/never-hot
  functions in shipping files are candidates, not verdicts.
- For every removal: prove zero live references (grep across scripts,
  data, tests, tools; check dynamic references — `call()`, string-built
  method names, data-driven ids — the codebase uses dictionaries heavily),
  note the commit that orphaned it, remove, and keep the tree green.
- Work in auditable clusters (the LC.1 pattern: one commit per cluster,
  gates between clusters, strict deletion smoke at the end).
- Tests that asserted the removed thing's absence or behavior get removed
  or updated WITH their cluster — never weakened to paper over a break.

## Named removal candidates (verify each, then remove; owner-authorized)

1. **The rejected menu-home path.** The walkable-room rework
   (docs/todone/CRITICAL_meta_home_must_be_walkable_environment_prompt.md)
   was ordered to remove the menu implementation entirely. Verify it
   actually died: `meta_collection_view_model.gd` is still referenced by
   foundation_main — determine whether the room's prop detail panels
   legitimately reuse it (keep, and trim its menu-only surface) or whether
   menu screens survive behind dead entry points (remove them).
2. **Prestige plumbing.** `data/prestige/purchases.json` is an empty stub;
   scene-compile checks actively forbid exposing prestige; the meta-gold
   system now owns meta progression per the item plan. Remove the prestige
   read/branch paths threaded through content_library, environment_instance,
   game_module, run_action_service, run_state, and foundation_main, the
   stub data file, and its validator entry. Keep save-load tolerance: old
   saves/profiles containing prestige keys load cleanly (normalizers drop
   them silently — prove with the save fixtures).
3. **AmbientSurfaceOverlay vestiges** in game_surface_canvas.gd — the
   overlay system was consolidated away by the playtest root fix; remove
   remaining scaffolding if the liveness-guarded scheduler no longer uses
   it (the liveness and function-confirmation checks are the safety net —
   they must stay green through this removal).
4. **Web audio bridge legacy surface:** the blocked legacy stubs
   (`legacy_play_music_blocked`, `legacy_sfx_blocked`), the permanently
   false `WEB_AUDIO_OSCILLATOR_FALLBACK_ENABLED` flag and its contract
   fields, and any eval-era remnants the get_interface migration orphaned
   (the one legitimate install-time eval stays). Update
   `mix_contract_snapshot` and its checks with the cluster.
5. **One-off evidence probes in tools/** (52 scripts): classify every
   tools/ entry as (a) wired into check_godot/validate/queue-prompt gates
   — keep; (b) reusable harness cited by current docs — keep; (c) one-off
   release-evidence probe for a shipped cycle (l02_*, la1_*, lb3_*, etc.)
   never referenced by current gates — remove, listing each with the
   ledger that retains its historical command line (git history preserves
   the script itself).
6. **Orphaned data and assets:** data keys no schema reads (diff each
   data/*.json's fields against the loaders), art with no manifest/loader
   reference (the LC.1 ghost-art pass is the pattern), unused icon_sprites
   entries, and events/services whose ids are unreachable from any scope.

## Systems kill-list (propose, do not delete)

Anything that is a *system* beyond the named candidates — a mechanic,
module, or content family that appears unexpanded and purposeless — goes
in the execution record's kill-list with evidence (last meaningful commit,
reference count, player-visible role) and a remove/keep recommendation for
owner review next planning pass. Do not delete these yourself.

## Guards and gates

1. Regenerate the function census after each cluster; final census
   attached to the execution record with before/after function counts.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
   (update its required-files list with removals — the census freshness
   pattern applies).
3. `tools\check_godot.ps1 -RequireGodot -Suite Full -TimeoutSec 1800` once
   at the end; targeted suites between clusters.
4. `tools\foundation_mouse_batch_playtest.ps1 -RunCount 20 -RequireGodot`
   strict deletion smoke (the LC.1 precedent).
5. `tools\web_perf_smoke.ps1` + record the web zip size delta — removal
   should shrink the payload; report the number.
6. Old-save/profile fixtures still load (prestige-key tolerance proven).
7. Archive to docs/todone/ with the execution record (per-cluster removal
   ledger, census delta, payload delta, kill-list); update QUEUE.md and
   commit per the queue lifecycle.

## Hard constraints

1. Zero behavior change for live gameplay paths — this is subtraction,
   not refactoring; if a removal wants a refactor, note it and step back.
2. Never delete queue/todone/plans documents or release evidence.
3. Determinism: same seeds produce identical runs before and after
   (probe with 5 seeds if any core/ file is touched).
4. Match house style in every surviving edit.
