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
| 1 | release_0_3_3_patch_prompt.md | blocked | work server (clean tree) | GitHub source release is being cut from the PM tree; keep only if a separate export/hash package gate is still required |
| 2 | playtest_root_fix_agent_prompt.md | claimed (2026-07-06, Codex PM workspace; user override) | PM machine | Taking over existing dirty-tree implementation; preserve in-progress work |
| 3 | home_environment_feature_prompt.md | in-progress-elsewhere | PM machine | Partially implemented, uncommitted on the PM machine (archetypes/data/art) |
| 4 | environment_semantic_layout_prompt.md | blocked | PM machine | Touches archetypes.json, which carries uncommitted home-environment work; wait for entry 3 |
| 5 | web_audio_bridge_modernization_prompt.md | blocked (2026-07-06, Codex PM workspace) | any (clean tree) | Task A implemented and UI gate green, but DONE gate fails `tools/web_perf_smoke.ps1`: table idle budgets exceed p95 limits (`baccarat_idle`, `roulette_idle`, `bar_dice_idle`, `blackjack_idle`; latest `.tmp/web_audio_bridge_after_rerun/report.summary.json`) |
| 6 | attribute_glyph_system_prompt.md | blocked | any | Wants inventory extraction landed and committed before inventory rows integration |
| 7 | beach_environment_prompt.md | blocked | PM machine | New beach environment plus hidden legendary slot item; touches archetypes/routes/items/art/slot item behavior, so wait for entries 3 and 4 |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
