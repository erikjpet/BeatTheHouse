# rw06_5 — Owner-requested gameplay fixes: talking to people, blackjack count, Cass gate

Status: DONE. Completed 2026-09-23 by the release orchestrator.
Depends on rw06_0 being DONE. Runs in parallel with rw06_1 and rw06_2.

## Execution record

- The implementation landed on `main` and `origin/main` at
  `1038a31fc1ae938e80c3802e2e6eddb91d435a4d`.
- Independent static validation passed on the merged tree. Production-input
  checks exercised the rumor conversation, counted blackjack hand, and Cass
  without and with an active count; the public screenshots, allowlisted JSON,
  and SHA-256 hashes are recorded in
  `docs/plans/rw06_5_owner_gameplay_fixes_report.md`.
- Merged-main Smoke closed 10/10 by the same composite rule recorded for
  rw06_0: 9/10 stages passed in the full run, whose sole miss was a stochastic
  performance sample; an immediate isolated rerun of the exact unchanged
  authored profile passed. No threshold, budget, assertion, or liveness floor
  changed.
- Merged-main Contract passed all 18/18 Foundation shards and every later
  UI/tutorial/audio stage. The only red stage was the inherited
  `game06_2_repeated_reprieve_contract` fingerprint baseline already present at
  release-week start.
- The product branch and closeout branch were merged, pushed, and removed
  locally and from origin, and their worktrees were removed before the row was
  declared DONE.

## Owner questions (binding for every agent)

All owner decisions go through
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Always use that
absolute path (the primary checkout copy). Follow its protocol:

- append a short, precise question with options and a recommendation;
- mark your work `WAITING Q-NNN`;
- keep working on anything that doesn't depend on the answer.

Read the file at the start of every session. Pick up any ANSWERED entry whose
`Resume` is yours. Never talk to the owner any other way, and never stall
waiting.

## Fix 1 — Clicking a person starts a conversation

**Owner report.** Clicking a person to interact does not start a conversation.
Example: "Word from Across Town" (`town_rumor_staff` in
`data/events/events.json`) disappears and walks away when clicked.

**Cause found in the PM audit (verify it).** The actor carries the event's only
response as an inline action (`event_response:town_rumor_staff:listen`; see
`scripts/tests/foundation/scenario_presentation_contract.gd`). A click fires it
directly. The choice has `resolve_event: true`, so the event resolves and the
actor exits before any dialogue is shown. The rumor content itself goes only to
the map preview.

**Required behavior (a general fix, not one event):**

- Clicking any person or character event (`presentation: "talk"`, a
  character/speaker actor, or `visual_type: "character"`) opens a
  **conversation** first:
  - the speaker's name or role, plus 1–3 short spoken lines that
    **deliberately hand the player the event's actual information**;
  - for the rumor event, that means the concrete rumor: which place, what's
    happening there, and why it matters, taken from the live rumor data;
  - the player makes their choice inside that conversation.
- Keep the lines short and in the speaker's voice. Don't dump the full event
  description.
- Where authored dialogue doesn't exist, generate the lines from the event's
  structured data (summary, rumor truth trace, consequence summary), not
  placeholder text.
- The actor stays in place while the conversation is open. It leaves only after
  the choice resolves, and only if the event resolves.
- Reuse the existing dialogue/talk presentation. Search `data/dialogue/`, the
  talk/dialogue UI in `scripts/ui/`, and `EnvironmentInteractionController`.
  Don't build a parallel system.
- Accessibility: keyboard, controller and touch; `modal_focus_scope.gd`
  conventions; 44-pixel targets.
- Hidden state must never appear in the lines (Turn, traitor, rigged draws,
  unrevealed tickets, untold rumor truth tiers).
- Consequences fire exactly once across save, reload and revisit, including a
  save made while the conversation is open.
- Audit **every** `interaction_mode: "interactable"` event with a person actor
  for the same instant-resolve problem, and fix them all through the same path.
  List them in your report.

## Fix 2 — Show the player's count between blackjack hands

**Owner request.** When a blackjack hand ends and the player is deciding
whether to deal again, show the count they're keeping, as long as they are
counting.

- Show it on the between-hands (deal / leave) state whenever counting is active
  for the player at that table. Hide it when counting is off.
- Show the **player's own recorded count** (`recorded_running_count` /
  `persisted_recorded_running_count` in `scripts/games/blackjack.gd`), never the
  hidden true count (`running_count`). If the player missed count icons, the
  display must show their imperfect count. Showing the true count would leak
  hidden state.
- If the game already derives a player-facing true count or deck estimate from
  the player's recorded count, you may show it next to the recorded count.
- Match the existing blackjack surface style.
- Keep it inside `_blackjack_ui_protected_regions` so it never overlaps cards,
  chips or buttons in normal or expanded layouts.
- Idle-liveness rules apply to any animation.

## Fix 3 — Cass Venn needs a real count before a hand-off

**Owner report.** `chain06_cass_first_contact` (Cass Venn, the rival counter;
seen at the Delta Queen riverboat casino) lets the player trade or share a count
before the player has an active count.

**Required:**

- `share_the_read`, and any Cass choice that implies you have a count
  (including `keep_counting`), requires an **active player count**. That means
  counting is enabled and the player has a recorded count on a live, unshuffled
  shoe at a blackjack table.
- Add this as a reusable, data-driven condition, for example
  `requires_active_count: true`, supported wherever event and choice
  `conditions` are evaluated. Validate it in `content_library.gd`.
- Without an active count:
  - clicking Cass opens the conversation (Fix 1) with one short line in her
    voice, such as "Come back when you're actually counting";
  - the count choices appear disabled, with that reason;
  - the event does **not** resolve, and the chain does not advance, so it can
    be offered again later.
- With an active count, the existing chain proceeds unchanged: escalation,
  proposition, tip-off, flameout, and the Heat values in
  `data/story/character_chains.json`.
- If "active count" has an ambiguous edge (for example, a count kept at a
  different table in the same room), ask in the questions file and use the
  stricter reading until answered.

## File ownership

- rw06_1 owns placement: `scenario_layout_resolver.gd`,
  `environment_instance.gd`, `pixel_scene_canvas.gd` and the placement JSONs.
  If click routing for Fix 1 lives there, first check with the orchestrator.
  Prefer a narrow hook in the interaction controller or talk UI.
- rw06_2 may also touch event and UI flow code, so rebase often and keep
  commits small.
- You own `scripts/games/blackjack.gd`, the Cass events and the chain data, and
  the talk-conversation path.

## Rules

- Never weaken a test, budget, idle-liveness floor or deterministic assertion.
  The existing `scenario_presentation_contract.gd` assertion about a *direct*
  Listen response encodes the bug. Replace it with an assertion of the new
  conversation-first behavior, and record the change in your report.
- Everything is seeded and happens at action boundaries. Every consequence fires
  exactly once.
- No hidden-state leaks.
- A run that ignores the Crew stays a true no-op.
- Game rules, RTP and payouts don't change.

## Acceptance

- Focused regression tests for each fix:
  - rumor conversation shows the concrete rumor and resolves once;
  - the actor stays until the choice is made;
  - the count is shown between hands only while counting, and it is the
    recorded count, not the true count;
  - Cass without a count doesn't advance, and with a count does.
- Verify through production input with `tools/agent_playtest_session.ps1`:
  click "Word from Across Town"; finish a counted blackjack hand; meet Cass with
  and without a count. Save screenshots under `.tmp/rw06_5/`.
- `tools/validate_project.ps1`, Smoke, and Contract no worse than at start.

## Finish

- Commit in a worktree branch, verify, fast-forward `main`, and push. Never
  force-push. Delete the branch (local and origin) and remove the worktree. The
  row is not DONE while its branch exists.
- Report the results and screenshot paths to the orchestrator for the
  scoreboard. Log any similar issues you found but didn't fix in
  `docs/plans/0.6.1_backlog.md`.
