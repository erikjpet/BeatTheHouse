# Agent Prompt — Profile & Out-of-Run Persistence Completion (parked T5.3)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). This promotes the parked Act-1 board task T5.3
(docs/plans/act_one_feature_complete_task_board.md:1163). Goal: finish what
persists across runs and present it in the main-menu profile view.

## What exists (read first)

- `scripts/core/profile_inventory.gd` (`ProfileInventory`): load/save,
  to_dict/from_dict, reference chips, item quantities, and challenge
  completion flags (`mark_challenge_completed` :102,
  `has_challenge_completion` :115). This is the profile store — extend it,
  do not create a second profile file.
- `scripts/core/user_settings.gd`: the atomic-write pattern (:6, :67).
- `MetaCollectionService` (item meta P0, if archived in docs/todone/): the
  newest persistence layer. **Alignment requirement:** profile and meta
  stores must share the same discipline — schema_version field, atomic
  write, corrupt-file → defaults, normalize-on-load, unknown keys
  preserved. Match its conventions so future migrations are one pattern,
  not two. Do NOT merge the files; ProfileInventory stays the profile
  store.
- Main-menu profile view in `scripts/ui/foundation_main.gd` (grep
  "Profile" / the Inventory main-menu section) and daily-run selection.

## Scope: what persists (Act 1 only)

1. **Run history** — last 20 results, appended at every run end (victory
   AND each failure route: bust, arrest, debt default, abandon): `seed`,
   `route/outcome`, `final_bankroll`, `day_count`, `duration_actions`,
   completion timestamp (calendar date is acceptable here — this is
   out-of-run bookkeeping, not run-deterministic state).
2. **Daily runs** — current streak, best streak, best daily result. Streak
   rules: consecutive calendar days with a completed daily run; document
   the timezone/day-boundary rule in a comment.
3. **Lifetime stats** — total runs, victories per route (players-card
   cashout vs showdown), biggest single win, total bankroll won/lost,
   games-played tallies per game id.
4. **Challenge flags** — already exist; surface them (list completed
   challenges with titles in the profile view).

Explicitly NOT in scope (T5.3's own boundary): unlockables, meta-currency,
Act 2 unlocks — those belong to the item-meta and act-seam tracks.

## Presentation

Extend the existing main-menu profile view: run-history list (most recent
first, one line each), streak + lifetime stat summary block, completed
challenges. Reuse existing main-menu list/label patterns; no new scene
architecture. Numbers format through existing helpers.

## Where recording happens

One choke point: the run-conclusion path in foundation_main/run_state where
victory and failure routes already resolve (grep the victory summary build
and each terminal-state handler). Every terminal route calls the same
`record_run_result(profile, snapshot)` helper — no per-route copies.

## Hard constraints

1. Corrupt/missing profile files load defaults without crashing (test it).
2. Recording is at run boundaries only; nothing per-frame; nothing inside
   the deterministic run simulation reads profile state to make decisions
   (profile is write-mostly from runs; the daily-seed selection may read
   streak data in the menu, outside runs).
3. Old profile files without the new keys normalize to defaults; version
   bump with migration default block.
4. Coverage: (a) profile round-trips across simulated restarts, (b) every
   terminal route appends exactly one history entry with correct fields,
   (c) corrupt file → defaults, (d) streak math over crafted date
   sequences (gap breaks streak, same-day repeat does not double-count).
5. Match house style: tabs, typed GDScript, sparse constraint comments.

## Verification gates (run at the end)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` and
   `-FoundationSuite ui`.
3. Move this prompt to docs/todone/ with an execution record per RULES;
   update QUEUE.md. Commit locally; do NOT push.
