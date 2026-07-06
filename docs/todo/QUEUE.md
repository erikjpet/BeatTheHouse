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

Last reviewed: 2026-07-06 by Codex desktop. No entries are currently `ready`.
The PM workspace still has unrelated dirty home/inventory/world-map/event work,
so downstream prompts must stay blocked until that work is committed or cleared.

| # | Prompt | Status | Machine | Notes |
| --- | --- | --- | --- | --- |
| 1 | release_0_3_3_patch_prompt.md | blocked | work server (clean tree) | Still blocked: requires clean release/export context on the work server; current PM tree is dirty |
| 3 | home_environment_feature_prompt.md | in-progress-elsewhere | PM machine | Still in progress elsewhere; PM tree has uncommitted core/world-map/foundation/inventory/test changes, so do not duplicate |
| 4 | environment_semantic_layout_prompt.md | blocked | PM machine | Still blocked: depends on entry 3 home-environment/archetype work landing first |
| 5 | web_audio_bridge_modernization_prompt.md | blocked (2026-07-06, Codex PM workspace) | any (clean tree) | Task A landed in `8eefdc5`; after table-surface fix `eef32ff`, needs fresh clean-tree `tools/web_perf_smoke.ps1` before it can be marked ready/done |
| 6 | attribute_glyph_system_prompt.md | blocked | any | Still blocked: inventory extraction/view-model work is dirty and must land before glyph integration |
| 7 | beach_environment_prompt.md | blocked | PM machine | Still blocked: touches archetypes/routes/items/art/slot item behavior; wait for entries 3 and 4 |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
