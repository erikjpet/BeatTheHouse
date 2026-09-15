# Documentation Guide

This directory contains current specifications and historical development
records. Their dates and status matter: a completed release checklist or task
prompt is evidence about that exact source boundary, not a description of the
current game.

## Current authority

- `../README.md` — public project overview, setup, architecture, game roster,
  exports, validation, and current limitations.
- `current_game_state.md` — maintained internal summary of current `main`, its
  content inventory, implemented gameplay systems, verification state, and
  open release blockers.
- `todo/README_0_6_board.md` — canonical 0.6 execution state and dependency
  order.
- `plans/0.6_living_world_roadmap.md` — owner-approved 0.6 design intent.
- `plans/content_style_guide.md`, `plans/0.5_voice_bible.md`, and
  `plans/0.6_voice_bible_world_register.md` — current player-facing copy and
  voice rules.

When these disagree about implemented behavior, current code/data and passing
tests win. Record the discrepancy on the active board instead of silently
rewriting dated evidence.

## Maintained feature references

- `character_authoring.md` — reusable character and encounter authoring.
- `plans/world_map_design.md` — seeded persistent travel graph contract.
- `plans/grand_casino_endgame_design.md` — Act 1 Grand Casino ending contract.
- `plans/item_collection_meta_system_plan.md` — implemented local collection,
  housing, loadout, bag, trade-up, and pawn systems plus explicitly deferred
  external inventory work.
- `plans/skill_based_cheating_methods_plan.md` — shared cheat/advantage action
  vocabulary and per-game methods.
- `plans/video_poker_reference.md` — current video-poker machine rules and UI
  rhythm.
- `plans/pinball_feature_rework_plan.md` and
  `plans/pinball_feel_reference.md` — current pinball feature architecture and
  feel contract; their pre-rework sections are retained as rationale.
- `plans/music_system_rework_plan.md`, `plans/music_listening_pass.md`, and the
  audio engineer documents — current adaptive-music architecture, listening
  reference, and external delivery contract.
- `plans/tutorial_completion_report.md` — original tutorial evidence with 0.6
  addenda and the remaining human-only gate.

## Historical records

The following are intentionally not rewritten to match current `main`:

- versioned release checklists, publish copy, devlogs, audits, and screenshots;
- dated closeout reports and evidence manifests under `plans/`;
- completed execution prompts under `todone/`;
- append-only landing, work, and discovery ledgers;
- genuine 0.5.1 and mid-0.6 migration-fixture documentation.

Those files preserve what was known, tested, or approved at a particular time.
Use their commit/tag/date boundaries when citing them.

## Active work

Files under `todo/` are claimable only when their own status and the active
board say so. A `PARKED` prompt is prepared work, not permission to execute it.
At the current boundary, room/scenario composition must be corrected before the
binding performance, playtest, balance, voice, and release sequence resumes.
