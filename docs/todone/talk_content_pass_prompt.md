## Execution Record

- Completion date: 2026-07-07.
- Implementing commit: not created; the workspace still contains overlapping uncommitted changes from multiple prior tasks, so a task-only commit would risk bundling unrelated work.
- Verification gates:
  - `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite systems` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts` -> PASS.
  - `powershell -ExecutionPolicy Bypass -File tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` -> PASS, hash `2976768356`, checkpoints `316`.
- New talk content verified:
  - Table approach talks: `blackjack_counter_probe`, `roulette_lucky_regular`, `baccarat_off_duty_dealer`, `video_poker_neighbor`, `bar_dice_tipsy_braggart`, `pull_tabs_friendly_local`.
  - Heat-threshold talks: `floor_staff_heat_warning` at 65, `pit_boss_heat_warning` at 85.
- Migrated/person-talk list verified in data:
  - `suspicious_patron` - patron confronts player.
  - `motel_knock` - debt/contact knock at room.
  - `rival_counter` - rival player conversation.
  - `counter_payoff` - social payoff conversation.
  - `snitch_reputation` - snitch pressure conversation.
  - `on_the_house` - temptation/person offer.
  - `the_collector` - collector debt conversation.
  - `shift_change` - staff handoff conversation.
  - `whale_sighting` - patron/staff temptation conversation.
  - `staff_shift_tip` - staff tip conversation.
- Additional talk-presented jazz events are present after the jazz task: `jazz_trio_set_break`, `jazz_connected_regular`, `jazz_after_hours_invitation`.
- Deviations:
  - This prompt was already implemented and left in `VERIFY`; this pass completed the missing determinism/contract evidence and archive step.
  - No push was performed.
  - Local commit was skipped to avoid sweeping unrelated dirty work into a misleading talk-content commit.

# Agent Prompt - Talk Content Pass: Fill the Talk Dock With Real Conversations

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike - see CLAUDE.md). The talk dock shipped as a **system**
(scripts/ui/talk_dock.gd; archived prompt:
docs/todone/talk_overlay_decision_system_prompt.md). This task is the
**content** pass - systems without content was 0.3's lesson. Before
writing anything, audit what the shipped system actually supports (talk
presentation, speaker snapshots, `heat_threshold` and `table_approach`
triggers, action-boundary timing) and, if the dialogue system
(docs/todo/dialogue_system_prompt.md) has landed, author multi-turn pieces
as dialogues instead of single-shot talk entries where noted.

## Content deliverables (all data in data/events/events.json or
data/dialogue/dialogues.json - no new engine mechanics)

### 1. Patron approach events - one per table game (6 total)

Blackjack, roulette, baccarat, video poker (machine neighbor), bar dice,
pull tabs (fellow customer). Each: a seeded `table_approach`-triggered talk
entry whose speaker binds to a live patron, with 2-3 choices carrying real
consequences through existing keys (bankroll, suspicion, luck, item hooks).
Vary the archetypes: a tipsy braggart, a card-counter probing whether YOU
count, a superstitious regular, an off-duty dealer, a snitch fishing for
evidence (suspicion trap), a friendly local with a venue tip. Approaches
must respect the shipped trigger tuning (min_hands, chance) - rare enough
to stay an event, not noise.

### 2. Pit-boss / staff heat pressure at suspicion 65 and 85

The two thresholds already used by the heat system (run_state.gd:1045-1047).
At 65: a floor-staff conversation - polite pressure, choices like play it
cool (heat freeze for N actions), buy a round (money for heat), talk back
(heat up, pride flag). At 85: the pit boss - a real squeeze: walk away from
the table now (forced table exit, heat down), bluff (seeded skill-flavored
roll: heat down or watched-flag up), slip a bribe (scaled cost). Wire
through `heat_threshold` triggers; per-environment where the shipped
system supports it. These two are the strongest candidates for multi-turn
dialogue trees if the dialogue system has landed.

### 3. Migration: existing events to `presentation: "talk"`

Audit all 36 events (types include `social` and `pressure`). Migrate every
event whose fiction is a person addressing the player to talk presentation
with a proper speaker snapshot; leave modal the ones that are genuinely
blocking beats (security busts, showdown-critical). Expect roughly 8-14
migrations; list each with a one-line rationale in the execution record.
The modal popup must keep working for what remains - do not migrate
mechanically.

## Authoring rules

1. Copy voice: terse, diegetic, no lore dumps - match existing event text.
   Simulated gambling only; no real-money framing.
2. Every choice's mechanical effects go through existing consequence keys;
   effect badges must disclose them (the dock's badge row) unless a choice
   is explicitly deceptive.
3. All randomness seeded; expiry (where used) counts action boundaries,
   never wall-clock - the shipped talk contract.
4. Scope-gate new events correctly (venue scopes, table-game contexts) and
   verify with the environment generation audit.
5. No engine changes. If content needs a mechanism the system lacks, note
   it in the execution record as a follow-up instead of hacking it in.

## Coverage to add

(a) Each new event validates and triggers in its intended scope (extend the
event-module foundation checks' data-driven pass), (b) the 65/85
conversations fire once per threshold crossing and never re-fire while
above threshold, (c) migrated events resolve with consequences identical to
their modal behavior (consequence-parity spot checks), (d) determinism
probe hash-matches with approach/pressure events in the mix.

## Verification gates (run at the end)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts` and
   `-FoundationSuite systems`.
3. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`.
4. Move this prompt to docs/todone/ with an execution record per RULES
   (including the migration list); update QUEUE.md. Commit locally; do NOT
   push.
