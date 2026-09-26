# rw06 RESET step 2 — Three implementation lanes (implementation only)

Status: TODO. Self-contained. Launch **three** agents with this file, each told
its lane: **A**, **B** or **C**. Start only after
`docs/todo/rw06_reset_status.md` exists on `main` (consolidation done).

## Owner rules (binding, override every older prompt)

- **Implementation only.** Build the feature, then confirm it works by using it
  once (see "Confirmation").
- **No testing of any kind:**
  - no test suites (Smoke/Contract/Full/Audit);
  - no focused contracts;
  - no new or updated test files;
  - no audits, independent reviews, verification passes or "fail-closed"
    investigations;
  - no evidence hashes or archives.

  Ignore failing tests; they get fixed at the end of the release.
- **Everything lands on `main`.** Work in your own worktree branch
  (`codex/reset-<lane>`). Merge to `main` and push whenever a piece works, at
  least every 2 hours. Rebase on `main` before merging. At the end, delete your
  branch (local and origin) and worktree. No leftover branches.
- Never force-push. Never upload or publish.
- Owner decisions go through
  `D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`, but only
  when truly blocked. Otherwise pick the sensible option and keep going.
- Godot: the canonical console is
  `D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`.
  Up to 4 Godot processes may run at once machine-wide, each in its own worktree
  with its own APPDATA/LOCALAPPDATA folder and log file. Don't touch Godot
  processes you didn't start.
- **Progress file:** `docs/todo/rw06_reset_status.md`. Edit only your lane's
  line: what works now, what's next, and the time. Update it after each merge.
- Keep game rules, RTP and payouts unchanged. Don't leak hidden information
  (Turn, traitor, rigged draws, unrevealed tickets) on screen.

## Confirmation (the only check allowed)

- Launch the game and do the thing once, through the normal game or the
  existing agent playtest bridge (`tools/agent_playtest_session.ps1`).
- For visual work, save a screenshot under
  `D:\Projects\Beat-The-House\.tmp\owner_review\` in the primary checkout, and
  check that it opens.
- If it doesn't work, fix it and look again. That's all.

## Lane A — Rooms (the priority; this must land)

Make every room lay out like a real place. Owner feedback, all binding, is in
Q-006, Q-007 and Q-008 in the questions file. Read those answers in full. In
short:

1. **Fixed, named slots by type.** `game_1..N`, `shop_item_1..N`, `staff_*`,
   `patron_*`, `event_*` and fixed prop spots (phone on the counter, drinks by
   the BEER sign). Positions never change; only which game, item or person
   fills a slot is random. Adding a slot is a data edit.
2. **Only physical things get room slots:** people, games, shop items, and
   props with real art. Abstract scenario things (tasks, zones, routes,
   barriers, ledgers, seals, "work zone", "Close Other Zones", "Route 1/2/3")
   go to the room action list. Remove placeholder boxes and silhouettes from
   the room.
3. **Behind-counter people are really behind the counter:** draw them before
   the counter art so it hides their lower body (`pixel_scene_canvas.gd`).
   Everyone else stands on the floor. Nothing floats.
4. **Place slots by looking at the rendered room.** Render each room's empty
   art with numbered slot markers, adjust, and re-render until each slot sits
   where it belongs. No slots on the board's top edge.
5. **Grand Casino: redo it against its art.** Table games on the felt tables,
   one aligned row of machines, staff at their stations, no route lines in the
   player view, and clear area groups.

**Order:**
1. Fix the drawing problems (items 2 and 3).
2. Place slots for Bar, Corner Store and Grand Casino.
3. Save `.tmp\owner_review\rooms_A.png`: those three rooms in normal view, with
   the busiest scenario and with the base room, and no debug outlines. Ask the
   owner in the questions file.
4. While waiting, do every other room the same way, and save
   `.tmp\owner_review\rooms_all.png`.

Merge each working step to `main`.

## Lane B — Endings

Make all three endings winnable to their win screen: clean (Linda's Players
Card ladder), cheat (Rourke's walk, pat-down, interrogation, five-hand duel),
and crew/heist (a heist plan executed at the Grand Casino). Read
`docs/plans/grand_casino_endgame_design.md` and the endings notes in
`docs/plans/rw06_2_routes/`.

1. For each ending, play it on current `main` through the game's normal
   actions or the playtest bridge.
2. Fix whatever stops you: dead ends, missing or unclear next steps, economy
   walls, broken ending logic. You may narrow an ending, for example to one
   heist plan, but it must reach its win state. Log what you cut in
   `docs/plans/0.6.1_backlog.md`.
3. A normal run takes about 150–350 actions. Jackpots and legitimate fast
   routes may be faster.
4. Confirmation: each ending reached its win screen once. Save a screenshot of
   each win screen to `.tmp\owner_review\ending_<name>.png`.
5. Don't edit room placement files (`scenario_layout_resolver.gd`,
   `environment_instance.gd`, `environment_slot_binder.gd`,
   `pixel_scene_canvas.gd`, the placement JSONs). If a room problem blocks
   you, note it in the status file for Lane A.

## Lane C — Pull-tab glimmer, then help rooms

1. Finish the pull-tab yellow glimmer (Q-014 in the questions file;
   `docs/todo/rw06_6_pull_tab_glimmer_prompt.md` "Product contract" only; skip
   its testing sections).
   Confirmation: watch a pull-tab machine until the glimmer shows. Save
   `.tmp\owner_review\pulltab_glimmer.png`.
2. Then help Lane A: take the rooms Lane A lists as "open for Lane C" in the
   status file, one room at a time. Before starting, claim the room on your
   lane's line in the status file. Only edit your claimed rooms' entries in
   `placement_surfaces.json`, following Lane A's rules above.

## Lane D — Release prep (added 2026-09-24)

This doesn't depend on final game code. Don't edit game logic, rooms or endings.

1. Set the version to `0.6.0` everywhere the release reads it:
   - `project.godot` `config/version`;
   - the export presets;
   - README and CHANGELOG;
   - `scripts/core/build_identity.gd`, if it stores a version.
2. Draft player-facing copy from the templates in `docs/todo/`:
   - `release06_1_devlog_post_template.md`;
   - `release06_1_publish_copy_template.md` (the itch page);
   - `release06_1_talking_points_template.md`;
   - a CHANGELOG entry.

   Base the copy on what's actually on `main`: rooms, endings, the Crew path,
   new games, and the owner-requested fixes in
   `docs/plans/rw06_5_owner_gameplay_fixes_report.md`. Save the drafts in
   `docs/plans/release_0_6_0_copy.md` for owner review.
3. Build trial Windows and Web zips from the current `main` with
   `tools/export_itch.ps1`, **without** `-Push`. Never upload, never run
   butler. Confirmation:
   - the Windows `.exe` launches, shows 0.6.0, and starts a run;
   - the Web build loads in a browser and starts a run.

   Fix any export or packaging problem you hit; that's the point of the trial.
   Put the zips in `D:\Projects\Beat-The-House\.tmp\trial_builds\` and note
   their paths in your status line. These are trial builds only; the final
   zips come after the rooms and endings land.
4. Tell the owner in the questions file that the copy draft and trial builds
   are ready. Then mark your line DONE.

## Lane C part 3 — Heist ending (added 2026-09-24; takes heist from Lane B)

Lane C owns the **crew/heist ending**. Lane B keeps **clean** and **cheat**.

1. Record the handoff on your Lane C status line (reopen it from DONE). If Lane B has uncommitted heist
   work, coordinate through the status file before touching it.
2. Make the heist ending winnable, following Lane B's rules above:
   - build Crew trust, run a heist plan at the Grand Casino, and reach the heist
     win screen;
   - you may narrow to one heist plan if the other is broken; log the cut in
     `docs/plans/0.6.1_backlog.md`;
   - read `docs/plans/rw06_2_routes/heist.md` and the Crew/heist sections of
     `docs/plans/0.6_living_world_roadmap.md`.
3. Don't edit room placement files. Heist and Crew files are yours; clean and
   cheat ending files are Lane B's. For shared files (`foundation_main.gd`,
   `run_state.gd`, `game_module.gd`), make small edits and merge often.
4. Confirmation: reach the heist win screen once. Save
   `.tmp\owner_review\ending_heist.png`.

## Done

- Lane A: the owner approves the rooms in the questions file, and all rooms
  are on `main`.
- Lane B: all three win screenshots saved, and the work is on `main`.
- Lane C: the glimmer is on `main`, and your claimed rooms are done.

After that, each lane deletes its branch and worktree, marks its line DONE in
the status file, and stops. The final test-and-fix pass and the release builds
come afterwards, as a separate step.
