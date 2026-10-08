# Documentation Guide

This directory contains current specifications and historical development
records. Their dates and status matter: a completed release checklist or task
prompt is evidence about that exact source boundary, not a description of the
current game.

## Current authority

- `../README.md` — public project overview, setup, architecture, exports,
  validation, and current limitations.
- `current_game_state.md` — maintained internal summary of current `main`, its
  content inventory, implemented systems, verification state, and remaining
  release procedure.
- `game_reference.md` — source-backed authority for the 11-game roster, current
  behavior, catalog actions, and all 47 scripts under `scripts/games/`.
- `code_reference.md` — maintained runtime ownership, source navigation, and
  production code-comment contract.
- `plans/release_0_6_0_copy.md` — maintained draft of public 0.6 release copy;
  it remains owner-gated and must not be posted before approval.
- `plans/0.6_living_world_roadmap.md` — owner-approved 0.6 design intent.
- `plans/content_style_guide.md`, `plans/0.5_voice_bible.md`, and
  `plans/0.6_voice_bible_world_register.md` — current player-facing copy and
  voice rules.

When these disagree about implemented behavior, current code/data and passing
tests win. Correct maintained references, but preserve dated evidence and its
recorded source boundary.

## Maintained feature references

- `code_reference.md` — architecture boundaries, common change traces, and the
  standard enforced for module/function context comments.
- `game_reference.md` — complete 0.6 game roster, mechanics, actions, source
  modules, supporting scripts, and data inventory.
- `character_authoring.md` — reusable character and encounter authoring.
- `plans/world_map_design.md` — seeded persistent travel graph contract.
- `plans/grand_casino_endgame_design.md` — Act 1 Grand Casino ending contract.
- `plans/coin_pusher_v3_machine_rework_plan.md` — implemented binding design
  for the three deterministic Coin Pusher cabinets.
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
- `plans/perf06_1_performance_platform_report.md` — historical non-binding
  Phase 3 ledger. It is retained as measured evidence, not the current release
  boundary or a description of the later accepted performance work.
- `plans/code_deprecation_unused_audit_2026-10-08.md` — current source-backed
  inventory of unreachable code, unreferenced function islands, retained
  compatibility seams, and staged cleanup recommendations.

## Historical records

The following are intentionally not rewritten to match current `main`:

- versioned release checklists, publish copy, devlogs, audits, and screenshots;
- dated closeout reports and evidence manifests under `plans/`;
- completed execution prompts under `todone/`;
- append-only landing, work, and discovery ledgers;
- genuine 0.5.1 and mid-0.6 migration-fixture documentation.

Those files preserve what was known, tested, or approved at a particular time.
Use their commit/tag/date boundaries when citing them.

Some agent-playtest reports link to temporary worktree evidence that was valid
during the recorded run but was deliberately removed after integration. Those
absolute links are provenance, not portable repository resources; the reports'
commit ids and accepted board rows remain the durable disposition record.

## Active work

Files under `todo/` are claimable only when their own status and the active
board say so. A `PARKED` prompt is prepared work, not permission to execute it.
The old 0.6 boards are historical unless their own release-week override says
otherwise. At the current boundary, 0.6 is feature-complete in source. The one
remaining authoring task is the manual 75-context environment slot-placement
procedure, followed by coordinate promotion, focused validation, final
packaging, and explicit owner publication.
