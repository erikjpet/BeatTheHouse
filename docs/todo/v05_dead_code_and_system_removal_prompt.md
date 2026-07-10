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
