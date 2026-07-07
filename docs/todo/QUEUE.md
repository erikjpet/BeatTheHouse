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
| 8 | item_meta_p0_collections_schema_prompt.md | claimed (2026-07-06, Codex desktop; local only) | any (new files only) | Executing now; local commit only per user instruction, no push |
| 9 | time_system_open_hours_prompt.md | claimed (2026-07-06, Codex desktop; user override) | any | Executing by explicit user override despite attribute-glyph dirty overlap; preserve current glyph/inventory/world-map work |
| 10 | dialogue_system_prompt.md | blocked | any | Multi-turn branching dialogue in a smaller talk dock with speaker models + per-choice effect badges; pilot = pull-tab clerk. Touches talk_dock/foundation_main/glyph registry — wait for claimed entries 8 and 9 to land, then flip to ready |
| 11 | profile_persistence_completion_prompt.md | blocked | any | Parked T5.3: run history, streaks, lifetime stats in the main-menu profile. Wait for entry 8 (align persistence patterns with MetaCollectionService) and entry 9 (foundation_main overlap) |
| 12 | act_two_seam_prompt.md | blocked | any | Parked T8.1: cross-act payload, save act marker, per-route victory hook replacing "not implemented yet". Wait for entry 9 (foundation_main) and ideally entry 11 (profile records the payload) |
| 13 | item_meta_p1_bag_drops_prompt.md | blocked | any | Bag drops at run milestones/special locations, single-button open + reveal, collection browser. Hard dependency: entry 8 (P0) archived in todone |
| 14 | talk_content_pass_prompt.md | blocked | any | Content pass: 6 patron approach events, pit-boss heat talks at 65/85, migrate ~8-14 events to talk presentation. Wait for entries 9 and 10 so content is authored once against the final talk/dialogue system |
| 15 | jazz_club_content_completion_prompt.md | blocked | PM machine preferred | Parked T4.2: coherent service menu, 2-3 club events, concrete musician reward. Wait for entry 9 (archetypes/open-hours churn); pairs well after entry 14's talk patterns exist |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
