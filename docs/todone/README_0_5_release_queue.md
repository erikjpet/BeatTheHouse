# 0.5 Release Queue - completed historical index

Status: **COMPLETED / ARCHIVED.** This file originally lived in `docs/todo/`
as the execution order for the 0.5 release queue. The queue prompts it named
have since been executed and archived under `docs/todone/`; this file is kept
only as historical context for why the queue was ordered this way. Do not treat
the prompt list below as active work.

Re-assessed 2026-07-26 (second pass) against the tree at `fab0ee82` plus
uncommitted scratch-ticket edits. Run in order; each prompt is self-contained.
On completion a prompt ARCHIVES itself (moves to `docs/todone/` with an
execution record appended) rather than deleting, and PUSHES only after its
gates pass and the work is confirmed working (owner convention, 2026-07-21).

## Since the first assessment

Five commits landed and the scratch-ticket scarcity rework was committed and
retuned:

```
a8953759 Retune scratch payouts and scarce stock
881e69f4 Preserve scratch multi-buy in compact stock rows
8607f19c Make wallet changes subtle and persistent
510a0329 Play pull-tab sounds during auto open
fab0ee82 Surface shops and Jazz Club earlier
```

- **RESOLVED:** the scratch-ticket suite crash (exit -1). `-FoundationSuite
  scratch_tickets` now PASSES with the current working tree.
  `p0_1_scratch_scarcity_finish_or_revert_prompt.md` was therefore deleted as
  stale.
- **NEW BLOCKER:** `-FoundationSuite ui` now FAILS. Verified fresh: the same
  suite PASSES at `544f49f7` in an isolated worktree.
- **STILL OPEN:** the boot viewport error, the red surface-coverage gate, and
  the 0.4.0 release identity are all unchanged from the first pass.

## Queue

| # | Prompt | Why |
| --- | --- | --- |
| 1 | `p0_0_settings_starts_run_regression_prompt.md` | BLOCKER, fresh today. Opening/applying Settings from the main menu now creates a run (`run_state` non-null). Passes at `544f49f7`, fails at HEAD; the assertion is 237 commits old, so behavior regressed. |
| 2 | `p0_2_boot_viewport_error_and_gate_honesty_prompt.md` | BLOCKER. `get_viewport_rect()` before tree entry logs an engine error every boot and clamps the start panel to 1x1 on first layout; `ui05_surface_coverage_check` still RED (`hud_time_watch.gd`); UI report evidence now predates 17 commits. |
| 3 | `p1_2_prerelease_playtest_sweep_prompt.md` | The gates keep passing while UI defects ship. Needs a green tree, so run after 1-2. |
| 4 | `p1_1_release_identity_and_checklist_prompt.md` | Repo still says 0.4.0 in six places; 0.5 has no checklist, publish copy, devlog, or current screenshots. |
| 5 | `p2_3_scratch_collection_payoff_prompt.md` | "X/7 PRINTS FOUND" is persisted and drawn but pays off nowhere, and today's retune made it ~75% out-of-stock per type. Resolve or remove. |
| 6 | `p2_1_career_stats_surface_prompt.md` | Career/stats view was scoped in the brief, never built; lifetime data is persisted but rendered as raw text rows in the inventory list. |
| 7 | `p2_2_token_coverage_and_ui_consistency_sweep_prompt.md` | The token gate enforces 8 of 55 UI files, so drift is unpoliced. |

Items 1-4 should land before the release tag. Items 5-7 are polish the owner
may push to 0.5.1 - though item 5 is a player-visible dead end, so shipping it
unresolved is a deliberate choice, not an oversight.

## Open questions for the owner

- **Scratch scarcity is aggressive.** 75% out-of-stock per type means ~1.75
  of 7 types stocked per machine. Intended, or a tuning overshoot? This
  directly gates item 5.
- **Collection schema is still formally draft.**
  `data/collections/collections.json` carries `"draft": true` and
  `collection_item_resolver.gd:388` REQUIRES it ("must carry draft=true for
  P0 owner review"). Ship 0.5 with it set, or finalize the schema first?
- **Career/stats placement** (brief open question 1) and
  **controller/keyboard-first navigation** (open question 3) remain
  unanswered. Item 6 implements the start-screen entry and leaves a meta-home
  hook attachable; controller support stays out of 0.5.

## Not queued, decided deliberately

- **Authored SFX.** `scripts/ui/sfx_player.gd` is 2,055 lines of procedural
  synthesis; `assets/audio/` holds music only. Deferred all through 0.5.
- **`1 resources still in use at exit`** appears in headless test shutdown.
  Common in Godot headless runs and not player-visible; worth a look during
  item 3 rather than its own task.
