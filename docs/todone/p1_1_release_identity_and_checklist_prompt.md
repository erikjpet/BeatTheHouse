# Agent Prompt - P1: 0.5 Release Identity, Checklist, and Publish Copy

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This file is self-contained. The 0.5 feature work is done; the
release paperwork does not exist yet.

## Current state (measured 2026-07-26)

The repository still identifies itself as 0.4.0 everywhere:

| Location | Current value |
| --- | --- |
| `project.godot` `config/version` | `0.4.0` |
| `export_presets.cfg` `application/file_version` | `0.4.0` |
| `export_presets.cfg` `application/product_version` | `0.4.0` |
| `export_presets.cfg` Android `version/code` / `version/name` | `7` / `0.4.0` |
| `export_presets.cfg` iOS `application/short_version` / `application/version` | `0.4.0` |
| `scripts/ui/foundation_main.gd:10766` and `:10768` | hardcoded `"0.4.0"` fallback |

There is a `v0.4.0` git tag, but 0.4.0 was NEVER published - an earlier
candidate was tagged, playtest defects were found, and development continued.
`docs/plans/0.4_release_checklist.md` records this status. 0.5.0 is therefore
the first cut that will actually ship since 0.3.3.

Every prior release has a checklist doc (`0.2`, `0.3`, `0.3.1`, `0.3.2`,
`0.4`) and publish copy (`0.3.3_publish_copy.md`, `0.4_devlog_post.md`,
`0.4_publish_copy.md`). **0.5 has neither.** `docs/plans/` contains 0.5
feature plans only.

## Task

### 1. Release identity

Bump every location above to `0.5.0` (Android `version/code` to `8`). For the
`foundation_main.gd` fallback, prefer removing the duplicated hardcoded string
in favor of a single source of truth if that is clean to do; otherwise update
both occurrences. Add or extend a test that asserts the rendered in-game
version matches `ProjectSettings` so this cannot drift again.

### 2. `docs/plans/0.5_release_checklist.md`

Model it on `docs/plans/0.4_release_checklist.md` (same section shape:
Release Identity table, Included Scope, gate evidence, known limitations,
publish steps). It must state honestly what is verified and what is pending.
Scope it from what actually landed in 0.5 - read the git log and the 0.5
plan docs rather than assuming. At minimum 0.5 includes:

- the Grand Casino three-room rework, chips-and-Cage economy, walkable Cage
  with Linda, sequential Bronze/Silver/Gold Players Card claims, the
  four-phase back-room showdown and playable heads-up Rourke duel, Players
  Card meta lifecycle and prestige rules;
- the onboarding/tutorial arc including the Cage gift shop tutorial;
- scratch tickets as the eighth game;
- Sal's pawn shop resale shelf;
- the spatial inventory / item-interaction renovation;
- the full UI redesign (design tokens, HUD with wallet + heat/drunk meters +
  status icons + interactive clock, per-environment title headers, cheat
  dock, autosized popups, animated conversation UI, redesigned menus and
  sale showcase);
- post-overhaul conversation and event-popup work (multi-person lender
  conversations, Crew group conversations, portraits) and the environment
  clock changes.

Mark clearly that owner playtest, export packaging, itch/GitHub upload, and
the release tag are release-owner actions that remain pending.

### 3. Publish copy

Write `docs/plans/0.5_publish_copy.md` and `docs/plans/0.5_devlog_post.md`
following the tone and structure of the 0.4/0.3.3 equivalents. Lead with what
a player will actually notice: the endgame, the new game, and the fact that
the whole interface was rebuilt. Do not invent features - verify each claim
against the tree.

### 4. Fresh screenshots

`docs/screenshots/` currently holds only scratch-ticket art iterations. The
UI has been completely redesigned since any promo capture was taken. Produce a
fresh 0.5 capture set (`tools/promo_screenshots_0_4.gd` shows the
drive-and-capture pattern; extend a 0.5 variant) covering: start screen, the
new HUD in a room, a conversation popup, the cheat dock, a game surface, the
Cage, the sale showcase, and the run report. Store them where the prior
release's promo captures live and index them in the publish copy.

## Hard rules

- Do NOT create the git tag, do NOT push a release, do NOT upload anything.
  Those are the owner's actions. Your job ends at "everything is staged and
  documented so the owner can publish."
- Working tree may contain other people's uncommitted work; treat it as
  user-owned. Never revert, reformat, or stage files you did not author.
  Stage explicitly, file by file.
- Verify every factual claim in the docs against the repo. A checklist that
  overstates verification is worse than no checklist.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite ui` and `systems` (version assertions live here)
- a Web export run to confirm the version change did not break packaging

## On completion

Only after every gate passes AND the docs/captures are complete and verified:

1. Commit the work in logical units.
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append a short execution record to the bottom of the moved
   file (date, implementing commit hashes, gate results, deviations), and
   stage the moved file so the archive lands in the final commit.
3. PUSH to the remote (code + docs only — do NOT create the git tag, do NOT
   publish, do NOT upload; those remain the owner's actions).
4. Report: the identity bump locations, the checklist's pending items, and the
   capture index.

On an unfixable failure, stop at the last green commit, do NOT push or
archive, and report verbatim.

---

## Execution Record

Date: 2026-07-26

Implementing commits:

- `0fe1e547` - Stamp 0.5 release identity
- `6fb25a50` - Add 0.5 release paperwork and captures

Gate results:

- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` - PASS
- `powershell -ExecutionPolicy Bypass -File tools\export_itch.ps1 -Target web` - PASS; local Web zip SHA256 `8A140E44F065C875F06570AC11FEBF3E0C5FEEEEA4D626C0783D62685ADEB1DC`

Fresh captures:

- `docs/screenshots/0.5/01_start_screen.png`
- `docs/screenshots/0.5/02_room_hud.png`
- `docs/screenshots/0.5/03_conversation_popup.png`
- `docs/screenshots/0.5/04_cheat_dock.png`
- `docs/screenshots/0.5/05_game_surface.png`
- `docs/screenshots/0.5/06_cage.png`
- `docs/screenshots/0.5/07_sale_showcase.png`
- `docs/screenshots/0.5/08_run_report.png`

Deviations:

- The prompt file was untracked in `docs/todo/`, so it was archived by moving
  the exact file to `docs/todone/` and adding the archived copy rather than
  using `git mv`.
- Final release packaging/upload/tag were not performed; they remain owner
  actions as requested.
