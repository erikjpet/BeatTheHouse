# game06_2 contract-only successor handoff

Status: UNREVIEWED first-rejection remediation candidate
Branch: `codex/game06_2-remediation`
Frozen base: `a2760d816c781e711ff0923c296f97b786662453`
Supersedes: blocked `codex/game06_2-impl` head `2def171d` (preserved unchanged; do not land)

## First-rejection remediation

This named successor begins at the Integrator-frozen contract-only head
`e699d0bcfb566a022f4c4115920690874d0991ab`. It changes only the rejected
Blackjack consumer, its row-local proof, and this handoff:

- the one charged/resolving deal action, `blackjack_place_bet`, is now declared
  exactly once, permitted only at wagering, accepted by the closed
  `blackjack_authority` handler, and carried by the live direct-resolve command
  inside a closed, fingerprinted `game_ritual/1` command envelope;
- actor, object, anchor, and region declarations use the same stable dotted IDs
  emitted by live projection;
- pending/working items emit target, denomination/amount, source, edit ordinal,
  eligibility, and disabled reason; resolutions emit item and authoritative
  result IDs, stake disposition, returned stake, payout, net change, and public
  explanation;
- pointer, keyboard, controller, and reduced-motion routes reach the same live
  Blackjack action handlers with explicit `focus`/`cycle` target selection;
- hostile proof rejects bypass action IDs, cross-source/cross-target IDs,
  cross-session boundaries, unknown envelope fields, wrong phases, and invalid
  equivalent targets without a charge.

No shared runtime, rules math, RTP, timing, economy, environment, crew, world,
music, board, or main file changed in this remediation.

### Exact remediation proof manifest

| Proof | Exact result |
| --- | --- |
| `scripts/tests/foundation/game06_2_depth_contract.gd` | PASS after isolated editor import warm-up; includes envelope/handler, declared/live ID, complete authority record, live equivalent binding, target-selection, malformed/cross-ID/wrong-phase, no-charge, energy, restore, accounting, and ten-seed projection assertions. |
| `tools/blackjack_seed_audit.ps1 -SeedCount 10 -Output user://game06_2_remediation_seed.json -RequireGodot` | PASS: 10 generated tables and clean resolves; 1,410 compact UI/action samples; 1,010 resolves at avg/p95/max `1.454/1.976/4.121 ms`; surface state avg/p95/max `2.2724/2.5960/4.1690 ms`; 49 count icons and zero empty count hands; 1,000-hand main drift `-214 / 5475 = -0.0391`. |
| `tools/blackjack_terminal_presentation_probe.gd` | PASS: deal duration `1600 ms`, terminal bubble spawn `12541`. |
| `tools/blackjack_heat_backoff_probe.gd` | PASS. |
| `git diff --check` | PASS. |

## Scope and ancestry

This successor is based directly on the accepted `game06_1` contract commit and
contains no rejected `game06_1` runtime. `44fefe5f` is not an ancestor. The diff
is restricted to:

- `docs/plans/game06_2_blackjack_consumer_audit.md`;
- `scripts/games/blackjack.gd`;
- `scripts/tests/foundation/game06_2_depth_contract.gd`;
- this handoff.

No shared runtime, contract, environment, crew, world, board, `.tmp`, `.tools`,
or `review_artifacts` file is staged.

## Delivered behavior

- A closed Blackjack-owned `game_ritual/1` definition using the accepted exact
  top-level families: phases, action declarations, staged commitments, pointer
  verbs, actors, objects, energy, facts, persistence, handlers, and targets.
  It is declarative and imports no shared executable runtime.
- Visible `wagering -> initial_deal -> player_turn -> dealer_procedure ->
  settlement -> wagering` projection over the shipped rules authority.
- Pending, working, and resolved wager items with separate available, pending,
  at-risk, returned-stake, payout, and net totals. Each main/side resolution has
  an exact public reason; the shipped debit/settlement ledger remains authority.
- Add/correct/remove-one/undo/clear/repeat/re-bet/confirm wager operations.
  Invalid and incomplete operations do not charge or advance.
- Tactile chip placement, shoe cut, hand tap, and wave-off paths with the same
  semantic handlers as button/keyboard/controller actions and declared
  reduced-motion equivalents.
- Dealer, neighbour, pit, shoe, discard rack, wager, hole-card, and rail states
  rendered from the row-local projection. Neighbours explicitly carry no
  outcome authority. Quiet/engaged/watched/hot tiers materially change actors,
  objects, or interactions; heat makes the pit visible and narrows/blocks rail
  space.
- Rourke's duel variant remains outside this Blackjack ritual projection and is
  behaviorally untouched.

## Evidence at candidate source

| Gate | Result |
| --- | --- |
| `scripts/tests/foundation/game06_2_depth_contract.gd` | PASS: closed contract, all five phases, all commitment concepts, exact per-item accounting/reasons, invalid gesture no-charge, duplicate-cut rejection, actual watched/hot material state, save/restore shoe and phase preservation, and ten-seed projection non-mutation/neighbour isolation. |
| `tools/blackjack_seed_audit.gd` | PASS: 120 generated tables, 120 clean resolves, 1,667 compact UI/action samples, 1,120 resolves, 1,000-hand payout drift `-214 / 5475 = -0.0391`, no zero-icon count hands, cheat/patron probes; surface state avg/p95/max `2.1044/2.2600/3.8030 ms`. |
| `tools/blackjack_terminal_presentation_probe.gd` | PASS: deal duration `1600 ms`, terminal bubble spawn `12541`. |
| `tools/blackjack_heat_backoff_probe.gd` | PASS. |
| `tools/validate_project.ps1 -Quiet` | PASS, `51.5 s`. |
| `tools/blackjack_table_visual_capture.gd` (native GUI) | PASS; idle, initial deal, and live player hand inspected at 1280x720. Generated tracked captures were restored and are not part of the diff. |
| Web export | PASS after locked Web native-plugin build. Exported plugin SHA-256: `58E4CA6C6D8B73DAA42143A70579A75342D6160640AEDC2C8A3E93F211E3277F`. |
| Final exact-head Windows rerun | BLOCKED before row execution: the fresh locked Windows native-plugin build crashes Godot while loading. Gate Service artifact/decision required. |

## Disclosed gate blockers / remaining reviewer decisions

1. `check_table_games.gd` is un-runnable at the frozen base because it cannot
   resolve `check_slots_surfaces.gd`, followed by the inherited missing-helper
   parse cascade. `check_core_content.gd` has the same base missing-helper parse
   cascade. This row does not own either shared test.
2. `tutorial_dialogue_trigger_cadence_check.gd` reproducibly fails at “required
   third blackjack hand did not create the counting bubbles.” The same failure
   reproduces on the preserved frozen-base-derived `game06_5` lane without these
   Blackjack changes, so it is inherited. Focused Blackjack count coverage in
   the 120-table seed audit passes with 672 nonzero icons and zero empty count
   hands.
3. The Web browser performance probe did not launch because the lane has no
   Node `playwright` package. The Web export and hashed native plugin completed;
   browser runtime/performance remains an environment gate, not waived evidence.
4. Independent review should decide whether the native 1280x720 captures plus
   executable energy/reduced-motion contract assertions are sufficient for this
   contract-only successor or whether it requires additional retained captures
   for hot, settlement, reduced-motion, and small-screen states before acceptance.
5. The fresh locked Windows native-plugin build completed, but Godot crashes
   while loading its generated DLL before the exact-head row test can execute.
   That DLL's SHA-256 is
   `3E2092B478B1C94476F2D32544D9BD84182FD614B1AF83B333BE2C9F162AF6A4`.
   The Gate Service's read-only artifact at main has SHA-256
   `BDCB843DF652475530CFB9756348641582238126F83853D413AD11C350B050C7`.
   The artifacts differ. No main/Gate artifact was copied or modified; the Gate
   Service must supply or authorize a known-good artifact and own the bounded
   final rerun.

## Review focus

- Verify the declarative consumer does not smuggle authority into projection or
  import scenario lifecycle/shared game-specific branches.
- Recompute returned stake versus profit for blackjack, push, surrender, bust,
  ordinary win/loss, and side wagers.
- Exercise all pending-wager corrections and confirm invalid gesture paths keep
  bankroll, RNG, phase, facts, and settlement unchanged.
- Confirm actor/object/energy rendering is legible and non-overlapping in the
  required visual states, especially the compact chip rail and money strip.
