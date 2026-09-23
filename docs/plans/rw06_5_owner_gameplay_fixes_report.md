# rw06_5 owner gameplay fixes report

Date: 2026-09-23
Branch: `codex/rw06_5-owner-fixes`
Starting base: `7da3e5dab59b7f41b73520dbba8d86a37ebaa8e9`
Status: implementation, focused contracts, static validation, and production
input validation complete. Gameplay behavior is a functional PASS. Integration
is pending; an intermittent exit-only ObjectDB warning remains recorded for
confirmation by the release slim gate.

## Result

- Person and character events now open the existing TalkDock before a response can resolve. The queued conversation, exact live summary, and actor survive save/reload; the actor leaves only when a successful choice resolves the event.
- Word from Across Town presents the live rumor line plus a short importance cue. It does not expose the rumor registry, truth trace, or other hidden state.
- Blackjack shows `YOUR COUNT` between hands only while player counting is active. The value comes from `recorded_running_count`, never the hidden `running_count`, and remains in the existing protected shoe-status region.
- Cass Venn's `share_the_read` and `keep_counting` choices remain visible but disabled until any blackjack table in the current room has counting enabled and a recorded count from its current live shoe. Recorded numeric zero is valid; a shuffled/stale shoe or disabled counting is invalid.

## Complete person-event audit

The permanent `PERSON_INTERACTABLE_EVENT_IDS` contract in
`scripts/tests/foundation/character_chains_contract.gd` compares the complete
content-library census to this exact 30-ID inventory. Every entry is
`interaction_mode: "interactable"` and is classified as a person conversation
through authored `presentation: "talk"`, an active speaker actor, or character
visual presentation. The contract also requires one to three short opening
lines, rejects known hidden-state tokens, proves that an explicitly non-actor
speaker alone is not a person actor, and proves that a successful choice without
`resolve_event` leaves the actor available.

1. `chain06_cass_escalation`
2. `chain06_cass_first_contact`
3. `chain06_cass_proposition`
4. `chain06_dave_last_stop`
5. `chain06_dave_same_bus`
6. `chain06_dave_true_stop`
7. `chain06_nico_favor_call`
8. `chain06_nico_weekly_door`
9. `chain06_nico_what_it_covers`
10. `chain06_rourke_expected`
11. `chain06_sal_estate_item`
12. `chain06_sal_sellback`
13. `chain06_trio_gift_memory`
14. `chain06_trio_rent_payoff`
15. `crew_contact_bishop`
16. `crew_contact_knuckles`
17. `crew_contact_lucky`
18. `crew_contact_mags`
19. `crew_contact_rook`
20. `crew_contact_switch`
21. `crew_contact_velvet`
22. `heist_live_table`
23. `recruitment_bishop`
24. `recruitment_knuckles`
25. `recruitment_lucky`
26. `recruitment_mags`
27. `recruitment_rook_leads`
28. `recruitment_switch`
29. `recruitment_velvet`
30. `town_rumor_staff`

The seven `crew_contact_*` entries and `recruitment_lucky` deliberately set
`environment_actor: false`; they still use TalkDock because their presentation
is explicitly authored as `talk`. A non-talk speaker with that flag is not
classified as a physical person actor.

## Regression evidence

| Check | Result | Evidence |
|---|---|---|
| Static project validation | PASS, exit 0, 128.1 s (repeat run) | `tools/validate_project.ps1 -Quiet` |
| Composite split-runner composition | PASS, 39,212 lines | `.tmp/generated_tests/foundation_check_split_runner.gd`, SHA-256 `BA81CDA4434F6F24B79879C8687A103E407769469DF30C6CFAE17396FFF9C078` |
| Person inventory, rumor/Cass gate, persistence | PASS (`character_chains_contract`, 0 failures) | `.tmp/rw06_5/foundation_person_chain.json` |
| Conversation-first room presentation | PASS (`scenario_sequence_contract`, 0 failures) | `.tmp/rw06_5/foundation_scenario_presentation.json` |
| Blackjack recorded-count behavior and protected region | PASS (`blackjack_game_suite`, 0 failures) | `.tmp/rw06_5/foundation_blackjack.json` |

The person report also contains one pre-existing `town_state_foundation` failure
before the modified test hunk. The blackjack report's broad `content`
prerequisite contains 13 held rw06_1 placement failures. The release
orchestrator independently classified both sets as unrelated; the focused
rw06_5 checks above are green. No gate or assertion was weakened.

## Production-input validation

All interaction commands use `tools/agent_playtest_session.ps1` and the
canonical Godot 4.6 console. Sessions are isolated under
`user://agent_playtest/<session>` and are run serially under the shared Godot
lease.

Execution so far:

- Session `rw06_5_rumor`, commands `0001` through `0008`: all accepted, zero
  log alerts, and no surviving Godot process after quit. Command `0005` visibly
  shows Tomas Reed (the observable role field is `Staff`), the two-line live
  rumor (`Storm is moving in. That's headed toward Bar.` and `Worth knowing
  before you choose your next room.`), the `listen` choice, and the
  still-present/enabled room actor. Command `0007`, after `Listen`, shows the
  TalkDock closed and the actor absent.
- The first `rw06_5_cass_count` attempt exposed a launcher command-file publish
  race: command `0008` was observed while empty and rejected before the game
  executed it. The launcher now publishes command files atomically in the same
  directory and exits cleanly after a commandless start. The shared fix is
  line-identical to the already-reviewed rw06_2 launcher change.
- Session `rw06_5_cass_count_retry` completed the visible-input-only route.
  Command `0005` shows Cass Venn, the one-line missing-count response, both
  choices visibly disabled with that reason, and Cass still present. A live
  `Machine Jam` interruption was resolved through its visible `Wait it out`
  choice. The counted hand then settled through reported production actions;
  command `0019` shows the between-hands surface with `YOUR COUNT +6`.
- The first post-count reopen exposed a stale queued-summary snapshot. That
  production-found defect was fixed by marking new live-condition summaries
  and by inferring the same behavior from the event payload for queued saves
  created before the fix. The regression contract covers both paths.
- After the fix, command `0024` resumed the persisted session with exactly
  `Cass counts from the other end.` and both choices enabled. Command `0025`
  is the stable capture with Cass present. Command `0026` selected `Share the
  read` exactly once; command `0027` shows the TalkDock closed, Cass absent,
  and `Cass checks your count and finds it close enough.` All gameplay
  assertions through `0027` had zero log alerts.
- Command `0028` accepted `quit` and the Godot process exited, but shutdown
  emitted the ObjectDB warning documented below. The calling wrapper retained
  an inherited redirected handle and reached its 120-second shell timeout even
  though the Godot PID was already gone. This is recorded, not waived; final
  classification remains with the release slim gate.

### A. Word from Across Town

Fixture source:
`C:\Users\theep\AppData\Roaming\Godot\app_userdata\Beat the House\saves\bug_investigation_map_probe.json`.
The prepared copy is `.tmp/rw06_5/fixtures/rumor_foundation_ui_autosave.json`
(SHA-256 `7D20CA162F25BD29E9456ABFA85AB97D81A9002754918905A23EBF17B5EC1BB6`).
Copy it to the isolated session as
`agent_playtest/rw06_5_rumor/saves/foundation_ui_autosave.json`, then:

1. Start session `rw06_5_rumor`.
2. `look`
3. `click_button Continue`
4. `wait 30`
5. `click_object event:town_rumor_staff double`
6. `look` and require TalkDock to show Staff, the concrete destination and happening from the live rumor, and the importance line while the room actor remains present.
7. Copy the PNG to `.tmp/rw06_5/rumor_conversation.png` and project only
   player-visible/status fields into the strict allowlist record
   `.tmp/rw06_5/rumor_conversation.public.json`.
8. `click_button Listen`, then `look`; require the event to resolve once and the actor to leave.
9. `quit`.

Completed evidence:

- `.tmp/rw06_5/rumor_conversation.png`, SHA-256
  `F51AB459C4B2D16FBE0C96BB87CCB517ADCC66EC24F4F80BF420D0575389BEAB`
- `.tmp/rw06_5/rumor_conversation.public.json`, SHA-256
  `15B19B5001F097E485E213670C88A2232C0DF2321EFB19262DC99B9BAA9CD884`

### B. Cass and counted blackjack hand

Fixture source:
`docs/plans/evidence/balance06_1/validation/foundation_systems_retry1/user_data/systems_core/Godot/app_userdata/Beat the House/saves/foundation_check_grand_invite_accept.json`.
The isolated copy sets the current/world node to `delta_queen`, reveals that
node, and gives `cass_rival_counter` a current action-window itinerary at the
same node. It does not seed any blackjack count. The prepared copy is
`.tmp/rw06_5/fixtures/cass_count_foundation_ui_autosave.json` (SHA-256
`FBE6D10B97AAA0CC24D35D771A1F68DB07EC6938C32646E8BC01B6129107990E`).

1. Start session `rw06_5_cass_count` and Continue the isolated save.
2. `click_object event:chain06_cass_first_contact double`.
3. `look`; require Cass's no-count line and both count choices visible,
   disabled, with the active-count reason. Copy the retry PNG to
   `.tmp/rw06_5/cass_no_count_disabled_retry.png` and write only the public
   allowlist to `.tmp/rw06_5/cass_no_count_disabled_retry.public.json`.
4. `click_button Hide` to collapse, without resolving, the queued conversation.
5. Enter the room's blackjack table through `click_object game:blackjack double` (fall back to selecting the object and its visible Enter room action if the exact hit is single-click on this layout).
6. `click_action blackjack_count_toggle`, then `click_action blackjack_deal`.
7. After each `look`, click every enabled `blackjack_count_icon <index>` reported by the production surface. Use an enabled legal hand action (`blackjack_stand` is preferred), continue clicking newly reported count icons, and use `blackjack_settle` when enabled. No direct model call or synthetic action is allowed.
8. `look` in the deal/leave state; require visible `YOUR COUNT` and record the
   player-facing value from the screenshot. Copy the PNG to
   `.tmp/rw06_5/blackjack_recorded_count_between_hands.png` and write only the
   public allowlist to
   `.tmp/rw06_5/blackjack_recorded_count_between_hands.public.json`.
9. `click_action surface_back`, then `wait 20`.
10. Reopen the still-unresolved Cass conversation (expand the queued dock or
    click Cass again), then `look`; require both choices enabled. Copy the PNG
    to `.tmp/rw06_5/cass_active_count_enabled.png` and write the strict public
    allowlist to `.tmp/rw06_5/cass_active_count_enabled.public.json`.
11. Choose `Share the read`, then `look`; require first-contact advancement and actor removal exactly once.
12. `quit`.

Completed evidence:

- `.tmp/rw06_5/cass_no_count_disabled_retry.png`, SHA-256
  `265B89CE9D816C06865191D785D2AFD17B3CDCA592AE1A4A8AD43EB765777BCD`
- `.tmp/rw06_5/cass_no_count_disabled_retry.public.json`, SHA-256
  `A0E2CB6E41B25A0D3D1EA75207176F75BA86BCBA7B50706F35B810A1E8B3B2F9`
- `.tmp/rw06_5/blackjack_recorded_count_between_hands.png`, SHA-256
  `DEBB0CF12ADB92AF5B5AEDBF568D3533018415F9ACB5EA1BAC94E56CEAD85685`
- `.tmp/rw06_5/blackjack_recorded_count_between_hands.public.json`, SHA-256
  `96AE7AAFEE4FCB1A526E32AE1E1FCF21175D08F04D28E2CBA6A76E83505A0D97`
- `.tmp/rw06_5/cass_active_count_enabled.png`, SHA-256
  `02B4C8F7F8C8DD5365CB4376C8841011CF1D7DD96C3788A7AF2BDB795EE7723A`
- `.tmp/rw06_5/cass_active_count_enabled.public.json`, SHA-256
  `B636514D4C45CD271277D78B9E03E486FE427E789BF80472F804C6984CE35A3A`
- `.tmp/rw06_5/cass_active_count_resolved.png`, SHA-256
  `B35936B4E89C275EC1059F7FB97A0B8A953ECF26D52F8E9A823A256552290827`
- `.tmp/rw06_5/cass_active_count_resolved.public.json`, SHA-256
  `00E892E897104CDF1F71DF895279058CF1F07CCB4C8B22CEE9894A2DDD2464FD`

All five `*.public.json` records passed a recursive key allowlist and a
case-insensitive forbidden-token scan. They contain only visible/status fields;
the raw harness results contain private diagnostics and are intentionally not
handoff evidence or commit content.

## Shutdown warning retained for the slim gate

The final gameplay quit result is
`.tmp/agent_playtest/2026-09-23/rw06_5_cass_count_retry/0028.result.json`:
`accepted: true`, `command: "quit"`, `reason: ""`. The exact shutdown output
is in
`.tmp/agent_playtest/2026-09-23/rw06_5_cass_count_retry/godot.stderr.log`
(SHA-256
`7E8F5DEB3BF520C8ABB23951DEAFB0669C320CEBB4CEB6668C755C617C5FD7D3`):
`WARNING: ObjectDB instances leaked at exit (run with --verbose for details).`
followed by `at: cleanup (core/object/object.cpp:2641)`. No Godot process
survived the quit. The wrapper timeout itself has no separate persisted log;
it was the 120-second invocation that submitted command `0028`.

The warning text is not new to this patch. Identical exit warnings occur in
prior, unmodified-session evidence retained in the canonical primary checkout
at:

- `review_artifacts/placement_sheets/corner_store/logs/p3_reopened_corner_store_sheets.log:6`
- `review_artifacts/spawn_slots/corner_store_arrival_pass3.log:72`
- `review_artifacts/spawn_slots/corner_store_arrival_pass9.log:53`
- `review_artifacts/spawn_slots/corner_store_refine_e_pass3.err.log:45`
- `review_artifacts/spawn_slots/corner_store_refine_e_pass4.err.log:35`
- `review_artifacts/spawn_slots/delivery_gate_authority.err.log:3`

It is intermittent rather than universal: the `rw06_5_rumor` command `0008`
and initial `rw06_5_cass_count` command `0009` accepted quit with empty stderr
and no surviving process. Accordingly, rw06_5 gameplay is functionally green,
while shutdown cleanliness remains explicitly pending release slim-gate
confirmation.

Raw playtest observation JSON is not handoff evidence: it contains private
diagnostic state. Raw results remain only in the ignored, temporary session
folder and disappear with worktree cleanup. The copied evidence directory
contains PNGs plus the recursively checked public allowlists above; copied raw
result JSON was removed.

The run was observational and visible-input-only. It never packages, uploads,
publishes, changes game data, or bypasses event/game authority.
