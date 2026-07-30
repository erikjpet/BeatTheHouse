# 0.5 Post-RC Polish Queue — execution order

Re-assessed 2026-07-28. The 0.5 release-blocker queue and the follow-up
polish have almost entirely DRAINED and archived to `docs/todone/`:
version is `0.5.0`; the UI overhaul, release identity/checklist,
career/stats surface, token sweep, boot/settings fixes, scratch payoff,
the cage environment rework, the playtest polish batch (dice/Rourke/
tutorial/map fixes), the video poker cheat rework, and the trailer
production task all landed.

**Only one prompt is pending.**

## Queue

| # | Prompt | What |
| --- | --- | --- |
| 1 | `sfx_rework_pass_prompt.md` | Full procedural re-synthesis of ALL sound effects → casino-smooth, warm, fun (remove ringy/metallic). Music system untouched. Land first so video poker reuses its synth helpers. |
| 2 | `video_poker_machine_rework_prompt.md` | Complete video poker rework to slot-machine polish: 3 cabinets — Jacks or Better (1 hand), Double Deuces (Deuces Wild, 2 hands), Triple Double Bonus (Double Double Bonus, 3 hands) — full cabinet art/layout/buttons/sounds/displays, correct multi-hand + paytables + RTP, and a reworked per-cabinet skill-timed cheat with BLUNT outcome feedback. |
| 3 | `writing_voice_pass_prompt.md` | Total writing pass. Phase 1: character voice bible + style guide → OWNER APPROVAL CHECKPOINT. Phase 2: rewrite all descriptions/dialogue/tooltips/environment copy in a personal neo-noir voice, multi-line pools, brief tooltips. |
| 4 | `edge_state_and_feature_polish_prompt.md` | Empty/first-run/edge states look intentional; new 0.5 systems (chips/Cage/ATM, card tiers, showdown, scratch, cheating, prestige) made clear and intuitive for new players via the coach/tip engine. |

(Meta-home UI pass completed and archived 2026-07-28.)

## State notes

- The working tree currently carries uncommitted user-owned work
  (recently: `run_state.gd`, `bar_dice.gd`, `roulette.gd`,
  `scratch_tickets.gd`, `video_poker.gd`, `cage_economy_model.gd`,
  `foundation_main.gd`). Reconcile with it; never revert or clobber it.
  Stage explicitly, file by file.
- On completion a prompt ARCHIVES itself (moves to `docs/todone/` with an
  execution record appended) rather than deleting, and PUSHES only after
  its gates pass and the work is confirmed working.
- File contention (run serial, or worktree-isolate if parallelizing):
  the meta-home pass and video poker rework both touch `foundation_main.gd`
  wiring; the SFX pass and video poker rework both touch audio
  (`sfx_player.gd`) — SFX should land first so the video poker cabinets
  reuse its casino-smooth synth helpers; the writing pass edits copy that
  the video poker cabinets and edge-state cues also reference — run the
  writing voice bible early, but its Phase-2 rewrite can trail the feature
  work. Recommended order: meta-home → SFX → video poker → writing → edge
  states. All are large; the video poker rework and writing pass are the
  heaviest.

## Done since the last assessment (for reference; all in docs/todone)

- `playtest_polish_batch_prompt.md` — 12 root-caused playtest fixes.
- `video_poker_cheat_minigame_rework_prompt.md` — center-focus cheat chain.
- `trailer_production_prompt.md` — gameplay trailer pipeline.
- `cage_environment_rework_prompt.md` — walkable Cage sub-environment.
