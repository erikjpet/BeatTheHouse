# craps06_3 final closeout

Status: **DONE / ACCEPTED**

Date: 2026-09-03  
Audited product head: `914e5ac822d8ee3127f210203dc688b182a19c65`  
Audited product tree: `82ea2d051fdef2926f02a390410369bc7bc31ae8`  
Recovered implementation: `7d230a63` (`1905a115` / `e483ac65` payload)  
Runtime: Godot 4.6 stable, executable SHA-256
`fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae`

## Verdict

The landed implementation satisfies the Craps depth row without rebuilding or
changing its rules, odds, payouts, RNG, economy, schema, migration, or budgets.
No product remediation was needed in this closeout. Grand Casino Craps is a
recognizable staffed table with explicit bet correction and a deterministic
offer/aim/throw/bounce/settle ritual. Street Craps is a distinct cash circle
with warning, interruption, returned unresolved stakes, dispersal, and durable
terminal presentation.

The later owner playtest still owns the human-comprehension questions. That is
not an automated implementation blocker.

## Requirement reconciliation

| Prompt area | Landed implementation and acceptance evidence |
| --- | --- |
| Rules and wager usability | `scripts/games/craps/craps_rules.gd`, `scripts/games/craps/craps_surface_view_model.gd`, and `scripts/games/craps.gd` retain pass/don't-pass, come/don't-come, odds, place 4/5/6/8/9/10, and field. The surface exposes $1/$5/$10/$25 selection, add, remove, undo, clear, repeat, re-bet, legal-target reasons, available funds, pending stake, working stake, payout, returned stake, and per-bet results. The focused Foundation suite exercises conservation, working behavior, save/restore, cheats, luck, activation, street currency isolation, and the complete intended bet matrix. |
| Tactile throw and phases | `scripts/games/craps.gd` owns `dice_offered`, `aiming_throw`, `bounce_read`, `dealer_settlement`, and `betting`; pointer drag/release and keyboard/controller offer resolve through the same `roll_craps` boundary. `_throw_trajectory` produces offer/travel/wall contact/bounce/separation/rest geometry from the submitted vector while the seeded rules roll remains authoritative. Invalid/short gestures return without resolve or charge. Save/restore uses the run simulation clock, and a live roll rejects double input. |
| Staff, patrons, and energy | `_ritual_actors` and `_ritual_scene_objects` materialize stickperson, base dealers, box/pit presence, shooter, crowd/rail actors, point puck or chalk ring, dice, chips, and security/lookout states. The row contract proves all three energy tiers differ in actor/object state; the casino capture proves the idle rail advances and reduced motion is static. Authored game audio declares chip, dice, call, payout, crowd, and street cues through the existing surface-audio path. |
| Dynamic environment integration | `data/games/rituals/craps06_3_sequences.json` defines exactly five executable profiles: ordinary casino, hot/high-stakes, security/audit, ordinary street, and interrupted street. `data/games/rituals/craps06_3_environment_bindings.json` and `scripts/core/craps06_3_environment_binding.gd` route only committed public Craps facts into restricted scenario-owned actor/object/route operations. Nine hostile authority cases fail closed. Casino and street targets are materially distinct. The accepted env06_6/env06_7 runtime supplies persistence/revisit and the tracked Back Alley sequence evidence. |
| Street arrival, pressure, recovery | The street variant stages the cash-only chalk circle, bounded participants, lookout warning, live dice, breakup, and terminal scattered circle. `_resolve_street_disperse` returns every unresolved working stake once, clears the table, records the reason, and disables further play. The focused suite covers training, sweep/heat dispersal, save/restore, and exact core/street rules parity. |
| Presentation and accessibility | The production 1280x720 captures show the full casino table, dense working-bet rail, live dice, reduced-motion state, street circle, live street dice, and dispersed aftermath. Manifests require 1280x720 output, expected targets, liveness, deterministic presentation, and reduced-motion stability. Pointer verbs retain the shared keyboard/controller semantic action path; labels and shape/position cues do not rely on color alone. |
| Exactly once, privacy, and caller authority | The game publishes typed public facts only after a committed roll boundary. Environment responses require a committed host transaction, exact context/table/profile/boundary/receipt identity, and a registered response fingerprint. Recomputed payloads, receipts, boundaries, contexts, tables, profiles, premature facts, and arbitrary recomputed response operations are rejected without facts, responses, or mutation. No private RNG state or future die is published. |

## Exact replay evidence

- Static validation: PASS on the audited product tree.
- `craps06_3_depth_contract.gd`: PASS, five profiles, frozen
  `game_ritual/1`, ten deterministic trajectory fixtures.
- `craps06_3_environment_integration_contract.gd`: PASS, five distinct
  responses and nine hostile-authority cases.
- Focused Foundation Craps suite:
  `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -Suite Contract -FoundationSuite craps -RequireGodot -NoImport -ReportDir .tmp/depth_closeout/craps`.
  PASS: validation 81.406 s, GDScript load 33.565 s, focused suite
  204.446 s. Summary SHA-256
  `a6712929ffd59272da89546c1cab7d03824a7f1efebaff34eaa7f6ded61b0642`;
  Foundation report SHA-256
  `2f327f3607f23b74d1701554d2392b9900a33bd745b07bc47bbadb47cdabff62`.
- Million-decision RTP audit: PASS for pass line `0.986500`, don't pass
  `0.985362`, come `0.984672`, don't come `0.986533`, odds `1.000909`,
  place 4/10 `0.929835`, place 5/9 `0.960382`, place 6/8 `0.985682`, and
  field `0.973065`; dice-setting fairness reduction `0.025462`; exact
  street/core parity `0.988326`.
- Actual NVIDIA/OpenGL visual QA: casino manifest PASS with five captures,
  dense 13-target/8-working-bet state, moving idle rail, live dice, and static
  reduced motion. Manifest SHA-256
  `3838a321b4fb4ed2b6bbf299c73ca855787629e181cf151343b423466bc0fcbd`.
  Street manifest PASS with three captures and returned-stake dispersal;
  SHA-256
  `a60af3b3b72d4a81ee51d2f8cc17ce4a9a5a82798b31005d0c88c91a348b907c`.
- Current 55-scenario audit: PASS, 55 ids and 1,485 pair comparisons with
  zero failures; report SHA-256
  `36236106fc96b670635ad293b0642f1b18cc5dab9ca3f38a4fe2ae0cd602c5cc`.
  The accepted env06_6 native/Web semantic result and env06_7's 683 tracked
  captures/14 contact sheets remain the environment-platform evidence used by
  this public-fact consumer.

## Retained history and follow-on

The early standalone replay before import is retained as a non-product setup
red: a fresh isolated worktree had no Godot class cache. After the required
import, the unchanged contract passed. No test, golden, threshold, timing cap,
or fixture was weakened.

Deferred to `playtest06_1`: confirm a cold player can place/remove a line bet,
identify the point, complete a throw, read the settlement, and leave safely.
