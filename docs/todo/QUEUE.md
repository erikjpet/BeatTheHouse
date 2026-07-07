# Queue Order — maintained by the project manager

Agents told to "work on the todo list" (or similar) follow this protocol:

1. Read this file. Take the **first entry whose Status is `ready`** and whose
   Machine constraint matches where you are running.
2. Claim it: change its Status to `claimed (<date>, <machine/session>)`,
   commit and push this file **before** starting work, and pull first — if
   someone else claimed it in the meantime, take the next entry.
3. Execute the prompt per `RULES.md`, archive it to `docs/todone/` with an
   execution record, update this file (remove the entry), commit, push.
4. **Repeat from step 1** until no entry is `ready` for your machine, then
   report which entries remain and why they are blocked.

Never execute an entry marked `in-progress-elsewhere` or `blocked` — and
NEVER re-implement work a status note says already exists somewhere.

Last reviewed: 2026-07-06 by PM (Claude) — maintenance pass. Home environment
shipped in `c9a719d` (0.3.3) and moved to todone; the 0.3.3 release prompt was
deleted as obsolete (release shipped manually without its gate matrix). Known
red gate: `ui_scene_compile` exit -1 crash disclosed in the playtest_root_fix
execution record — untracked, PM flagging for owner. Remaining dirty PM-tree
files (run_state, world_map, foundation_main, inventory screen/view-model,
both test files) belong to the two claimed Codex entries.

| # | Prompt | Status | Machine | Notes |
| --- | --- | --- | --- | --- |
| 4 | environment_semantic_layout_prompt.md | blocked | PM machine | Home/archetype work landed in `c9a719d`, but entry 7 (beach) is claimed and touches archetypes/routes — unblocks when entry 7 completes |
| 5 | web_audio_bridge_modernization_prompt.md | blocked (2026-07-06, Codex PM workspace) | any (clean tree) | Task A landed in `8eefdc5`; after table-surface fix `eef32ff`, needs fresh clean-tree `tools/web_perf_smoke.ps1` before it can be marked ready/done |
| 6 | attribute_glyph_system_prompt.md | claimed (2026-07-06, Codex desktop; user override) | any | Executing by explicit user override despite dirty inventory/view-model blocker; preserve current inventory work |
| 7 | beach_environment_prompt.md | claimed (2026-07-06, Codex desktop; user override) | PM machine | Executing by explicit user override despite blockers; preserve dirty home/layout/inventory work |
| 8 | item_meta_p0_collections_schema_prompt.md | ready | any (new files only) | Item collection meta P0: collections schema + MetaCollectionService + 4-float engine. Creates only NEW files, safe beside the dirty PM tree; prompt forbids touching foundation_check.gd / ui_scene_compile_check.gd |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
