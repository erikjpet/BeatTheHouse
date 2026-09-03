# integ06_1 historical fixture preparation WIP

Status: **PREPARATION ONLY — `integ06_1` is not claimed or accepted**  
Preparation base: `9e8af74b712ed9c3a2bf69f9a330a57719cb0f85`  
Historical source: annotated tag `v0.5.1`, commit
`f1ce7ec814b5034c229f53dcc0db6e799aaaee0b`

## Capture design

`tools/integ06_1_generate_v051_fixtures.ps1` exports the pinned historical
runtime into a disposable directory. It never runs inside or writes to the
preserved detached v0.5.1 worktree. The opt-in historical driver instantiates
the release's genuine `res://scenes/main.tscn` and uses FoundationMain's public
run, gameplay and save boundaries. It does not construct a RunState dictionary
or write narrative, environment, debt, game, tutorial or victory flags.

Every successful fixture receives a sidecar containing the exact release
commit/tree, relevant historical Git blob identities, driver hash, public-call
transcript, and fixture SHA-256/size.

## First smoke attempt

The initial capture reached the real historical SaveService and wrote a valid
schema/version-2 foundation envelope, but the driver failed after that write
while formatting diagnostics:

```text
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
at: _capture (integ06_1_v051_fixture_driver.gd:87)
```

That output was rejected and not copied into the fixture inventory. The fault
was solely in the new opt-in driver: two already-typed RunState properties were
unnecessarily passed through a dynamic `int()` conversion. The conversion is
removed, explicit progress markers and a 90-second in-engine capture watchdog
are now present, and the next smoke rerun remains pending at this checkpoint.

A second pre-fixture attempt exposed an initialization-order bug in that new
watchdog: a SceneTree timer was requested before the tree existed. Its exact
failure was `Cannot call method 'create_timer' on a null value`; no historical
gameplay ran and no output was admitted. Timer setup now occurs on the deferred
capture boundary. The wrapper also owns independent, bounded import/capture
process waits and recursively terminates only its disposable child process tree
if one expires, so even a main-thread stall cannot orphan another capture.

The historical worktree remained clean at `f1ce7ec8` throughout.

## Genuine smoke fixture

The corrected bounded run produced
`scripts/tests/fixtures/integ06_1/v0_5_1/v051_smoke_foundation_run.json`
from the historical House start. It was generated twice with the same seed and
both captures had SHA-256
`81B4C5EAB4571E8BCB836647E9D25CA0F2EB31608C24D5C89933ADBEFAB2F17B`.
The checked-in sidecar records the exact historical Git identities, driver
hash, public-call transcript, save size and save hash. Temporary capture paths
are normalized out of the sidecar.

The single-fixture generating command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/integ06_1_generate_v051_fixtures.ps1 -OutputDirectory scripts/tests/fixtures/integ06_1/v0_5_1
```

The smoke fixture covers a genuine active run at the `house` archetype, before
any player action. `scripts/tests/foundation/integ06_1_v051_migration_smoke.gd`
loads it through current FoundationMain, saves it again through the current
public save boundary, reloads it, and checks its playable invariants.

## First verified batch

The driver and wrapper accept the checked-in `capture_plan.json`, allowing one
isolated historical process to produce several independent runs. Every case
still starts a fresh run and uses only the public gameplay/save calls recorded
in its sidecar. The batch command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/integ06_1_generate_v051_fixtures.ps1 -PlanPath scripts/tests/fixtures/integ06_1/v0_5_1/capture_plan.json -OutputDirectory scripts/tests/fixtures/integ06_1/v0_5_1
```

The first admitted batch contains six fixtures:

| Fixture | Historical state | SHA-256 |
|---|---|---|
| `v051_smoke_foundation_run` | House, active run start | `81B4C5EAB4571E8BCB836647E9D25CA0F2EB31608C24D5C89933ADBEFAB2F17B` |
| `v051_gas_station_mid_game` | Gas Station Casino, Slot surface entered | `9A1AEC5AE9B548C451DA0F4F534F0926A4DD372893CFCCA19E47B56368FE890A` |
| `v051_gas_station_pull_tabs_mid_game` | Gas Station Casino, Pull Tabs surface entered | `CB5071718271F6410963AF5BBAE7A4C35787175DF95963A3321F662B566FB47B` |
| `v051_gas_station_scratch_mid_game` | Gas Station Casino, Scratch Tickets surface entered (not yet partially scratched) | `D011F019105AA9D5913338E65772B028254DED713B37ABED6915D0B66E1149D5` |
| `v051_motel_environment` | Motel after public travel | `04E4F2655F57545B23A6AEB616BF918CC9C63FC51BB80D3CDAD95388DB8D5714` |
| `v051_corner_store_environment` | Corner Store after House -> Gas Station -> Corner Store | `114095087B770E2772091F0D132C88265E7B1F409AE832EF211D406F5ACA1810` |

The current-build migration check is now plan-driven. Before admitting each
fixture it recomputes its byte hash and size and verifies its historical source
identity, envelope, expected route/game identity, and exact public-call
transcript against the sidecar. It then loads through current FoundationMain,
saves through the current public boundary, reloads through SaveService, and
compares the preserved gameplay contract. All six pass. This remains fixture
preparation only and does not claim `integ06_1` acceptance.

## Second verified batch

The wrapper now keeps one imported disposable v0.5.1 archive but launches one
fresh historical Godot process per capture case. This prevents static/resource
state from crossing fixture boundaries. It also treats `ERROR:` or
`SCRIPT ERROR` output as failure even if Godot reports process exit code zero,
and requires exactly one provenance result per case before copying any output.

Five additional fixtures are admitted:

- Bar environment and a Bar Dice surface-entered save.
- Pawn Shop environment.
- Back Alley environment.
- Small Underground Casino reached by resolving the real Parking Lot Tip,
  borrowing from the Crew through `FoundationMain.use_lender_hook`, and using
  the resulting public travel route. That save contains the genuine active
  Crew favor debt generated by v0.5.1.

The strict current-build matrix passes all 11 fixtures. Coverage is now eight
of 18 environment archetypes and four of eight game surfaces. The lender path
has one real rung, but the required lender matrix is not complete.

## Third verified batch

The capture plan now defines reusable ordered public-gameplay sequences for the
Underground, Kitty Cat Lounge, Delta Queen, Beach and Jazz Club routes. The
historical driver resolves those routes with FoundationMain travel, event and
lender methods; cases can append further public steps without copying or
editing RunState data. The current-build verifier independently expands the
same plan before checking each sidecar's exact public-call transcript.

Ten additional fixtures are admitted:

- Blackjack and Video Poker surfaces at the Small Underground Casino.
- Kitty Cat Lounge environment and Roulette surface saves, plus a second Kitty
  save after accepting the Grand Casino invitation through the real event.
- Delta Queen environment, Blackjack and Video Poker surface saves.
- Beach and Jazz Club environments reached through their historical public
  routes. The Beach route clears the genuine river travel lock with two real
  Delta Queen event choices before traveling.

These routes also exercise the historical Street Lender cash debt in addition
to the Crew favor debt. All captures were regenerated from the exact v0.5.1
Git archive, and the strict current-build matrix passes all 21 fixtures with
verified provenance and stable public save/reload contracts. Coverage is now
12 of 18 environment archetypes and seven of eight game surfaces. This remains
fixture preparation only and does not claim `integ06_1` acceptance.

## Fourth verified batch

Nine more fixtures extend the matrix to 30. A reproducible custom challenge is
used only as a legitimate historical run configuration for the long Grand
Casino route; its exact challenge id and modifiers are recorded in each
sidecar. The route still earns its invitation, reveals its nodes, borrows from
the historical lender hooks, travels, and saves exclusively through runtime
boundaries.

This batch adds:

- Grand Casino Main Floor, Cage, and High-Limit Room states reached by public
  travel after accepting the real invitation.
- Baccarat entered on the generated High-Limit surface, completing all eight
  historical game families.
- Apartment and Motel Room starts produced through their real custom-home run
  configuration, raising environment coverage to 17 of 18 archetypes.
- A Motel Friend cash debt created through its live lender hook, bringing the
  represented lender types to Crew, Street Lender, and Motel Friend.
- A tutorial checkpoint started through
  `FoundationMain.start_tutorial_run`; its provenance is checked against the
  tutorial challenge embedded in the historical save.
- A genuinely interrupted Scratch Tickets state. The driver enters the game,
  selects the first stocked row, emits the same canvas action as a player
  click, then emits a pointer drag. Admission requires a purchased active
  ticket with a positive foil-mask revision that is not result-ready.

The current-build matrix passes all 30 fixtures, including the specialized
partial-scratch assertions before and after its public save/reload round trip.
This remains fixture preparation only and does not claim `integ06_1`.

## Fifth verified batch

Two more fixtures complete the five-lender historical surface. The driver now
supports public item purchases and the pawn-counter inventory surface in
addition to ordinary lender hooks:

- `v051_brother_in_law_mid_debt` follows the generated Motel phone event,
  resolves the triggered Family Loan event, and accepts it through
  FoundationMain's event-choice boundary. Its historical fixture SHA-256 is
  `CDF166B40DDF7555CD142EF6A08A1CD7DDEC0EC83BE08FF3272819C0DCEB1AFB`.
- `v051_sals_pawn_ticket_mid_debt` buys the generated Return Spring through
  the public item-offer flow, opens Sal's Pawn Counter, and emits the real
  `RunInventoryScreen.pawn_requested` action. Its historical fixture SHA-256
  is `0363CC6DA1809F04E2A562EA6D960EAB9CCA80943CE706402316F1FBE87499A6`.

Admission now explicitly requires an active debt record naming the intended
lender. The same assertion runs after current FoundationMain migration and
again after current SaveService round trip. Existing Crew, Street Lender, and
Motel Friend cases carry the same explicit requirement, so all five historical
lender types are now proven rather than inferred from route transcripts.

The exact historical batch passes 32 of 32 captures. The current-build matrix
passes all 32 with verified provenance, preserved mid-state contracts, and
stable public save/reload. This remains fixture preparation only and does not
claim `integ06_1`.

## Coverage still required

This checkpoint is historical migration evidence, but not the complete row. It
does not claim the Grand Casino Back Room, later tutorial checkpoints, victory
thresholds, maximal composition, or soak. It also does not yet cover the
promised mid-0.6 Punchline, delivery, coin-pusher, or scenario-snapshot schemas.
The 32 checked-in fixtures do pass the current-build migration and public
save/reload contract.
