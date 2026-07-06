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

| # | Prompt | Status | Machine | Notes |
| --- | --- | --- | --- | --- |
| 1 | CRITICAL_table_environments_not_loading_prompt.md | ready | PM machine ONLY | Bug exists only in the PM machine's uncommitted tree; blocks entries 3–6 |
| 2 | release_0_3_3_patch_prompt.md | ready | work server (clean tree) | Independent of the critical bug (pushed main is clean); may run in parallel with entry 1 |
| 3 | playtest_root_fix_agent_prompt.md | in-progress-elsewhere | PM machine | Partially implemented, uncommitted on the PM machine — do not start fresh |
| 4 | run_inventory_screen_extraction_prompt.md | in-progress-elsewhere | PM machine | IMPLEMENTED but uncommitted on the PM machine; mid-review, ui-suite gate pending. Do NOT re-implement |
| 5 | home_environment_feature_prompt.md | in-progress-elsewhere | PM machine | Partially implemented, uncommitted on the PM machine (archetypes/data/art) |
| 6 | environment_semantic_layout_prompt.md | blocked | PM machine | Touches archetypes.json, which carries uncommitted home-environment work; wait for entries 1 and 5 |
| 7 | web_audio_bridge_modernization_prompt.md | ready | any (clean tree) | Independent; safe on the work server |
| 8 | attribute_glyph_system_prompt.md | blocked | any | Wants entry 4 landed (inventory rows integration) |
| 9 | talk_overlay_decision_system_prompt.md | blocked | any | Wants entries 3 (foundation_main consolidation) and 8 (choice badges) |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
