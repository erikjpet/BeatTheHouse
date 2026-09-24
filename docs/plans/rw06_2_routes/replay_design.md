# rw06_2 ending replay design — exploratory implementation

Status: **Q-017A ENGINE-FREE ADMISSION GREEN; LIVE CONTRACT AND QUALIFYING ROUTES PENDING**
The peer branch contains canonical release-closeout reconciliation
`d2605866034fda5d69c0abc4abd418e198352028` and the Q-017A scoreboard mirror
through `d60c5d928f6ca4d973f158410816a00de55f87d3`.
Qualifying runs remain blocked until rw06_1 lands and the resulting immutable
implementation checkpoint receives independent clearance.

The release deliverable is `tools/rw06_2_ending_replay.ps1 -Ending
clean|cheat|heist`. It must drive the production `scenes/main.tscn` host through
the existing player-input bridge, assert a visible terminal win, and exit
nonzero at the first route deviation. It is a player replay, not a state-builder.

## Authority rules

- Start and command isolated sessions through `tools/agent_playtest_session.ps1`.
- Use only rendered `click_button`, semantic `scroll_surface`, `click_object`,
  `click_action`, `click_map`, `click_choice`, `click_inventory`, public
  text-field entry, waits, and quit/relaunch.
- Do not call product handlers directly, edit saves, inject flags/trust/money,
  teleport, use debug shortcuts, inspect hidden cards, or read the private Crew
  capsule.
- Branch only on the bridge's player-observable JSON: rendered screen and room
  identity, controls, room/game actions, status HUD witnesses, feedback,
  dialogue, inventory, and RunReport. Raw objective, run-status, debt-item,
  consequence, or model-state fields are not replay authority.
- Treat any `SCRIPT ERROR`, error, warning, rejected command, ambiguity, missing
  semantic target, or unexpected modal as a hard failure.

## Q-011 boat-to-Beach invariant

Every route treats Delta Queen as having one unconditional public escape to the
Beach. On a fresh boat arrival, on every revisit, and after Save -> relaunch ->
Continue, the production destination list must contain exactly one visible,
zero-fare Beach destination. It must be enabled whenever the ordinary boat
travel lock is clear. During that transient lock it may be disabled only with
the exact public River Queen lock reason, and no other normal destination may
be enabled first.

The replay checks the real public world-map result after each Delta Queen
arrival and after Continue. Metadata-only checks do not qualify: regressions
must not manually unlock Beach or pass an injected `['beach']` target list
around production `_travel_target_ids` selection.

Coverage must also present more than three otherwise eligible visible targets.
Beach is checked in the final capped target list after Grand/event/Tier-2
promotion, so a correct early insertion that is later evicted still fails.

## Controller shape

1. Resolve a per-ending route definition with its verified seed and expected
   public outcome.
2. Start a unique isolated session and parse every command result as JSON.
3. Use intent-level helpers rather than coordinates:
   - click one exact visible button or semantic object;
   - choose one exact dialogue/event action;
   - navigate the visible world graph toward a public destination;
   - settle a legal game using its published actions;
   - wait until a published modal/animation releases input;
   - assert fully rendered money/heat/chip values, exact visible route beats,
     and log health.
4. Write one compact transcript record per accepted player action: ordinal,
   intent, command, screen/environment identity, rendered bankroll/chips/heat,
   event/game surface, and visible result/outcome copy.
5. At the route's required midpoint, open the visible run menu, Save, Main Menu,
   quit the process, relaunch the same session, Continue, and compare a
   canonical public checkpoint signature.
6. At the terminal beat, require:
   - the exact screen is `VICTORY`;
   - the RunReport has an exact boolean-true rendered witness;
   - its exact outcome key matches the requested ending and its `won` field is
     the boolean value `true`;
   - no log alerts or unacknowledged route deviations;
   - the action count is reported against the 150–350 target.

## Determinism proof

For each ending, run the same seed and intent policy twice in clean isolated
profiles. Canonicalize only player-visible progression: accepted command intent,
screen/environment, fully rendered money/heat/chips, dialogue choice IDs, game
actions/results, persistence checkpoint signature, and final public outcome.
Exclude process IDs, paths, screenshots, wall-clock timestamps, control rects,
and animation-only timing. The two canonical traces must be identical.

Then complete a third interactive run on a fresh seed. The fresh run need not
match the fixed trace; it proves the route is understandable rather than merely
memorized. For Heist, Q-017A makes this a distinct `fresh-interactive` role:
exact seed `RW06-HEIST-AUDIT-0000`, exactly one run, the same Count/Plan A route,
and a separately checked natural day-zero Audit witness. No other seed, ending,
repeat count, scenario authority, or Plan B fallback is admissible.

## Evidence layout

The prepared final fixed-repeat launcher creates one ignored aggregate root
with two independently profiled one-run children:

```text
.tmp/rw06_2/final_fixed/<ending>-<timestamp>-<pid>-<nonce>/
  launcher.invoked.ps1
  run-01/
    launcher.stdout.txt
    launcher.stderr.txt
    profile_roaming/
    profile_local/
    replay/<invocation>/
      summary.json
      heist_seed_preflight.json  # Heist only
      run-01/
        public_trace.ndjson
        money_curve.ndjson
        checkpoint_before.json
        checkpoint_after.json
        final_public_checkpoint.json
        summary.json
  run-02/
    launcher.stdout.txt
    launcher.stderr.txt
    profile_roaming/
    profile_local/
    replay/<invocation>/
      summary.json
      heist_seed_preflight.json  # Heist only
      run-01/
        public_trace.ndjson
        money_curve.ndjson
        checkpoint_before.json
        checkpoint_after.json
        final_public_checkpoint.json
        summary.json
  aggregate_summary.json
  run_metadata.json
  artifact_manifest.json
```

`tools/rw06_2_final_evidence.ps1` qualifies only the fixed two-run portion. It
pins the exact Git head/tree and route seed, requires a clean worktree, holds
the Q-009 engine gate across both children, proves each child wrote through its
own profile, and compares the canonical trace, money curve, persistence
checkpoint and terminal checkpoint. A separate `fresh-interactive` evidence
root and experience log are still required for each ending. Q-017 controls only
how that separate Heist run is admitted; it never loosens the exact `0002`
fixed-repeat route.

The inner replay has two explicit admission roles. `fixed-repeat` preserves the
existing route defaults and locks Heist to `RW06-HEIST-AUDIT-0002`.
`fresh-interactive` is Heist-only, requires explicit seed
`RW06-HEIST-AUDIT-0000` and `Repeat 1`, then runs the unchanged
`Invoke-HeistEndingRoute` Count path. Both roles remain child/development and
non-qualifying. The fixed outer launcher passes `fixed-repeat` literally,
validates that role plus its complete admission and natural-Audit receipt at
both summary levels, carries the verified role into each proof, and rejects a
fresh child before fixed promotion.

The inner `rw06_2_ending_replay.ps1` remains non-qualifying even when invoked
directly with `-Repeat 2`, because both iterations inherit that invocation's
single external profile. Only the aggregate launcher may promote the fixed
repeat after it proves two distinct profiles and compares their artifacts.

Keep milestone/failure screenshots rather than reviewing hundreds of redundant
frames. The committed route documents should link the exact transcript,
before/after Continue checkpoints, screenshots, child summaries, aggregate
manifest, and final summary used for acceptance. The fresh-interactive log must
also record the player's believed goal, the exact rendered cue that communicated
it, notable moments, and every arc-breaker disposition.

## Integration and ownership boundaries

- Heavy Godot work must be serialized with the release orchestrator.
- Final acceptance runs happen only after rw06_1 lands.
- rw06_2 should primarily own the new replay script, route documents, and ending/
  Crew arc fixes.
- rw06_5 owns `foundation_action_view_model.gd`, the narrow event/talk hook in
  `foundation_main.gd`, EventModule active-count presentation, ContentLibrary
  condition validation, blackjack, and Cass data/tests. The replay may consume
  those public surfaces but must not edit those files without coordinating with
  the release orchestrator.
- Any balance change belongs to rw06_3 and must be data-only. Do not change RNG,
  odds, payout, wager math, or RTP to make a replay pass.
- Any out-of-scope improvement goes to `docs/plans/0.6.1_backlog.md`.

## Current verification status

- `rw06_2_replay_source_contract.ps1` is engine-free green. It parses both
  PowerShell entry points and enforces exact-case property reads, rendered-only
  semantic input, persistence, visible-terminal outcome, privacy, and
  deterministic trace contracts. Its focused policy matrix currently passes:
  wheel 1 valid/5 hostile, button viewport 2/8, machine jam 2/20, funding 8/59,
  cash event 2/39, and command-open 1/4, plus the runner's semantic regression.
- `tools/validate_project.ps1` passed on the current dirty tree in 138 seconds.
- `rw06_2_public_observation_contract.gd` has been expanded for clipped and
  partial TalkDock/event surfaces, non-boolean witnesses, rendered status HUD
  values, debt-indicator text, terminal visibility, action redaction, and hidden
  twin-state invariance. Its one leased Godot 4.6 invocation passed on the dirty
  tree identified before launch by binary diff SHA-256
  `E7DEBAAAB2AC8B0E08F83949D7961D6746762B2D7F0ADF7B5FCA3D4DC39702D1`.
  The report is `.tmp/rw06_2/public_observation_contract.json` (SHA-256
  `F8F699846DB1CFD6C5659F7A9D10F42C77CAB4F8573C4C5EE19D28E683889195`);
  exit was zero with no warning, error, leak, or surviving engine process.
- The bridge itself compiled and reached `ready.json` in the first live probe.
  That probe exposed a Windows launcher-detach hang before command 0001; the
  launcher now explicitly exits its start-only helper process after publishing
  readiness. A serialized Start → look → second command → quit regression
  passed with atomic command files, strict public observations, zero log alerts,
  no temporary-file residue, and no surviving engine process. Focused evidence:
  `D:\Projects\Beat-The-House-worktrees\rw06_2-prep\.tmp\rw06_2\clean\bridge-20260923-054711-435-14372\summary.json`
  (SHA-256 `79F6D5CB75857BA83A66A475BA4EB5FC6C18A2D9311C7954B5B56AEA2C862CCF`).
  These focused contracts are not full-route acceptance; all qualifying route
  passes remain pending.
- The first owner-directed current-main exploratory clean run on 2026-09-23 was
  explicitly non-qualifying. It accepted PLAY and reached the real tutorial
  Apartment, then the replay stopped after one counted action because Pal's
  visible TalkDock offered **Pick them up** (`continue`) while the coach
  snapshot's **Skip tip** label had no separate rendered button. The player
  path was clear, so this was classified as replay policy rather than a product
  arc breaker. The runner now consumes only the single rendered enabled
  `continue` choice from a public `tutorial_guide:*` TalkDock before applying
  its existing strict coach-dismiss rule. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-main-6a9201e3/20260923-092920-880-9772/run-01/summary.json`
  (SHA-256 `6225DC1798DEE8A4EE5772047E6256D76A2C5B099F886B8F03047E9B6E72CDC9`).
  The exact owned process exited with no survivor; its generic post-exit
  `ObjectDB instances leaked at exit` warning is retained in the session logs.
- A second serialized, non-qualifying clean probe on product base `11c584bd`
  confirmed that tutorial correction: both Pal's rendered `continue` choice
  and the subsequent **Skip tip** control worked. The replay then stopped after
  four counted actions because **Skip Lessons** was below the clipped run-menu
  viewport. The visible scrollbar made this a replay-bridge reachability gap,
  not a product arc, placement, goal, or economy finding. The bridge now
  publishes only the rendered `run_menu` vertical-scroll capability and uses
  real mouse-wheel input with verified movement; the route bounds its public
  scroll search and fails closed on ambiguous or stale surfaces. Seven hostile
  fixtures pass engine-free. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-main-11c584bd-probe2/20260923-094003-789-18960/run-01/summary.json`
  (SHA-256 `D876EF3276898B59AC33B0E9F10C8A7953184E6EA29CA352A3DFFE03E74AF344`).
  The exact owned process exited with empty stderr and no survivor.
- A third serialized, non-qualifying clean probe on product base `006620e5`
  proved the real wheel input and bounded route scroll, then exposed a narrower
  rendered-reachability gap. After one wheel step, only 23 of the 52-pixel
  **Skip Lessons** button intersected the viewport; its label and center were
  still clipped. The bridge nevertheless published its control text, and its
  accepted click did not open the confirmation. The run stopped fail-closed
  after six counted actions. The bridge now publishes a `fully_visible` signal
  derived from the full global and clipped rectangles, rechecks it at click
  time, and the route scrolls until the target is fully visible. Missing,
  false, non-boolean, and ambiguous values fail closed under hostile engine-free
  fixtures. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-main-006620e5-probe3/20260923-103641-220-18380/run-01/summary.json`
  (SHA-256 `AF3293A2F0499FE1FCC9A2599E6C116C6F83B4020DC5387BD1464854B35EB6A1`).
  The exact owned process exited with empty stderr and no survivor. The
  full-visibility correction still requires a later serialized live probe.
- A fourth serialized, non-qualifying clean probe on product base `d7d09f6a`
  proved the full-visibility correction: two wheel steps brought the entire
  **Skip Lessons** button and label into view. Its semantic click reported
  acceptance and visibly hovered the target, but the confirmation did not
  open; the run stopped fail-closed after seven counted actions. Repository UI
  input helpers release wheel-button events before later input, while the
  bridge had emitted only the press. The bridge now publishes the matching
  release immediately after every wheel press, and the source contract rejects
  five hostile order/lifecycle variants. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-main-d7d09f6a-probe4/20260923-105053-444-27868/run-01/summary.json`
  (SHA-256 `E83AE7119BECECA09CE852F8C266DCBD2EB21B55DCD8A9463E057381019A844B`).
  The exact owned process exited with no survivor; its generic post-exit
  `ObjectDB instances leaked at exit` warning remains preserved. The wheel
  release correction still requires a later serialized live probe.
- A fifth serialized, non-qualifying clean probe on current-main documentation
  base `01a5dc32` proved both full visibility and the matching wheel release.
  Clicking **Skip Lessons** visibly opened the native confirmation, including
  enabled **OK** and **Cancel** controls, but those internal
  `ConfirmationDialog` children were absent from the public bridge list. The
  run therefore stopped fail-closed after seven counted actions. The bridge now
  explicitly exposes only those two rendered, enabled controls under exact
  `tutorial_skip_dialog:ok|cancel` ids, and the runner selects by exact surface,
  role, id, and true boolean visibility signals rather than generic button
  text. Seven hostile fixtures cover hidden, disabled, clipped, ambiguous,
  wrong-id, absent-signal, and non-boolean cases. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-main-01a5dc32-probe5/20260923-110216-836-21584/run-01/summary.json`
  (SHA-256 `E0FD3B4623BB0DC43CA5D3C7B09C7C7BD6B3EBFC7807E6A741EB0450FCA9038A`).
  The exact owned process exited with empty stderr and no survivor. The narrow
  dialog-control correction still requires a later serialized live probe.
- A sixth serialized, non-qualifying clean probe at pushed tip `104e4f62`
  proved the dialog whitelist and exact role/id selector. The bridge accepted
  `click_button tutorial_skip_dialog:ok`, but the confirmation remained visible
  and the public run stayed active after 30 more frames. Its button rectangle
  belongs to the embedded ConfirmationDialog Window/Viewport while the generic
  helper sent that local point to the application root Viewport. The bridge now
  binds every button to exactly one live-matching input Viewport, clips in that
  Viewport, and routes the unchanged physical mouse sequence through it; root
  buttons still use the root. Two valid and three null/wrong/ambiguous hostile
  fixtures cover the routing decision engine-free. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-tip-104e4f62-probe6/20260923-112542-759-25648/run-01/summary.json`
  (SHA-256 `8CD5D6AD84C47E7B1844994222D1722B08F8FA4300FBC99F5283491413E86D4C`).
  The exact owned process exited without force; the generic post-exit ObjectDB
  warning remains preserved, and no Godot process survived. This Viewport
  correction still requires a later serialized live probe.
- A seventh serialized, non-qualifying clean probe at pushed tip `7af48369`
  disproved direct input injection into the child Window Viewport: the strict
  route was accepted, but the confirmation and tutorial state were unchanged,
  producing the same public trace and eight-action failure as probe six. The
  embedded Window is physically routed by its parent Viewport, so the bridge
  now translates the exact dialog-local target by `Window.position` and sends
  the unchanged motion/press/release sequence through the root embedder. Root
  buttons remain unchanged. Two valid and six null/wrong/ambiguous/nonembedded/
  nested/untranslated hostile fixtures pass engine-free. Summary evidence is
  `.tmp/rw06_2/exploratory/clean-tip-7af48369-probe7/20260923-113929-307-21240/run-01/summary.json`
  (SHA-256 `CC9EDA352A82F91B183D28E2EB10E827A8DF56A56AC6D71EB48BC1A14EA212F3`).
  The exact owned process exited without force; its generic ObjectDB warning is
  preserved and no Godot process survived. The embedder-coordinate correction
  still requires a later serialized live probe.
- The next authorized launch at pushed tip `f643859d` exited before readiness
  or any gameplay action because the new `dialog.get_parent_viewport()` local
  lacked an explicit GDScript type. The correction now declares it as
  `Viewport`, and the source contract requires that exact annotation. The
  compile-only failure produced no route evidence or product conclusion.
  Preserved stderr is
  `.tmp/agent_playtest/2026-09-23/rw062-clean-14848-1-0bb7d82feb/godot.stderr.log`
  (SHA-256 `AF295127E0E014B1D6E36E00FBF2A3B3A50F8278D481AF6D6B0014A1A42B20E0`).
- The following authorized launch at pushed tip `4c3b9555` was interrupted by
  its caller's five-second shell timeout before the engine's normal
  nine-second readiness publication. The replay issued no gameplay command,
  produced no route summary/trace/curve, and was not repeated under the same
  lease. The exact session later accepted a graceful `quit`; stderr stayed
  empty and the process census returned zero. This is orchestration-only and
  provides no product conclusion. The retained `ready.json` SHA-256 is
  `80A742862239F59C560A6F9F983DCF4ED2C4B00849DFBF526DB8242D3059C078`;
  the graceful quit result SHA-256 is
  `4BD08DBB174B78F2184AB0EDD7C7BF149FBF664F2187ED26D0F75785D74EBB1B`.
  Future invocations keep one long-timeout outer shell call attached and yield
  while waiting for that same call instead of detaching or reinvoking it. An
  engine-free check of that exact orchestration stayed attached for 7.016
  seconds and passed without starting Godot.
- The next attached launch at pushed tip `7e522069` reached the confirmation
  after seven counted actions and then proved `ConfirmationDialog` has no
  `get_parent_viewport()` runtime method. The session's bounded failure path
  issued graceful `quit`, exited without force, and left zero Godot processes.
  This remains a harness-only API blocker before the dialog OK input, with no
  product route or economy conclusion. Summary SHA-256 is
  `205B6BE06FF7BB85FD276D0BB39866114C47031394023F963B04877228751A03`;
  stderr SHA-256 is
  `71B8317D9CA43A2736710BB5B5BA341D52DD0A5D9B214689303D4655A78E17F3`.
  The correction requires the dialog's direct parent to be the application
  node and derives the embedder from that parent's `get_viewport()`, retaining
  every existing identity, embedded-state, root-viewport, and offset guard.
  Two valid and eight hostile route fixtures pass engine-free.
- The next non-qualifying launch at pushed tip `9cb85e3b` proved the dialog
  correction, returned through the start screen, started the fixed normal run,
  and traveled to Gas Station Casino by action 15 ($100 to $93, heat 0 to 1).
  It then exposed a real UI arc breaker: a 106-character normal-run Dealer's
  Advice line overflowed the fixed 144 px ambient bubble, clipping its 40 px
  **Skip tip** control to 23 px and correctly publishing
  `fully_visible: false`. Replay policy also incorrectly selected that partial
  control before the bridge rejected it. The product now uses the existing
  172 px safe coach height (+14 on small screens), with a rendered 1280x720
  long-copy containment regression; replay policy requires one boolean-true
  fully-visible coach dismissal. Summary SHA-256 is
  `98058AD4D2021A7612D58BF2F5789891BC3C137022544E8AB38ED22DE1949EFA`;
  public trace SHA-256 is
  `313C5F9D389E32EBD37887B72312D14EB91D92C2AAD9BDBCE4F2FE65C752E266`.
  Cleanup was graceful with empty stderr and zero surviving Godot processes.
- The following non-qualifying launch at pushed tip `ef082651` proved the coach
  correction and reached the visible High Roller Invitation after 29 counted
  actions. Selecting it published two exact enabled room actions, **Take the
  invite** and **Not yet**. The runner then failed closed because its generic
  event-open helper will not guess among explicit actions. This is a
  replay-script policy defect, not a product arc breaker: the route now uses
  `Invoke-EventObjectChoice` with exact event `grand_casino_invite` and choice
  `accept_invite`, and a source contract prohibits returning to generic open.
  The public trace SHA-256 is
  `7426DB80D6390B9F722A1A39EC5535A98FEEB0FD22DF4B6165C756079E8B326F`;
  the selected-object observation SHA-256 is
  `6EBF309F25CA8A1806A1F2B25771DE72876516E221E2EBDFCDEFDE0FE797DBA3`.
  Cleanup was graceful with empty stderr and zero surviving Godot processes.
  The engine-free replay source and semantic hostile-fixture contracts plus the
  full static project gate pass after the correction.
- The next non-qualifying launch at pushed tip `c7a6c937` proved exact
  invitation acceptance and exposed a product arc-clarity breaker. With $63,
  **The Grand Casino opens** appeared, but the immediate map omitted the Grand
  because its $70 route was disabled and the three-card selector considered
  only enabled routes for event priority. The product now preserves an
  event-unlocked destination inside the existing cap even while disabled, so
  its affordability reason stays visible; no fare or economy math changed.
  Summary SHA-256 is
  `632273E70085DAD0C03D51F5D4C2E0999C5533D951B040CD426B808EC5AF99EF`;
  the immediate-map observation SHA-256 is
  `B50D31500D4C48B33579AD8C213722CF2FE4FA1086E9F921579759989829B5DE`.
  Cleanup was not forced and left zero Godot processes. A generic non-verbose
  ObjectDB exit warning is retained as a qualification warning, not labeled a
  product blocker without retained-object evidence.
- The focused generated-runner `systems/content` check at exact pushed tip
  `91fad55c` passed its sole registered check with zero failures, confirming
  that the invited Grand stays visible at $63 with the exact affordability
  blocker. Report SHA-256 is
  `954BCD9CD63FA2E5AFC5F1E92F8A0712163222A06960448C1A95FF661B7B2E32`;
  stderr was empty and the post-run Godot census was zero. The next
  non-qualifying clean probe closes that visible disabled card, uses only the
  rendered Kitty Cat Lounge slot controls at their displayed stake for at most
  24 spins, and retries the exact Grand card once the public bankroll covers
  its fare. It never selects Nudge, autoplay, a private state field, or an
  unrelated travel destination.
- Probe19 at exact pushed tip `f8c37e10` live-proved the command-open correction:
  command 0068 and every later bounded spin were accepted with no ordinal gap.
  It also disproved slot-only fare recovery for this route seed. Twenty-four
  public $2 spins reduced cash from $63 to $15 while the storm-adjusted Grand
  fare remained $109. This is not yet a product economy wall: the public route
  had skipped visible positive-cash events and disclosed Crew/family lenders,
  and the invitation snapshot still exposed multiple enabled games and routes.
  The next replay policy must prefer strict visible liquidity, verify displayed
  terms and the resulting public cash/debt transition, and loss-stop any random
  fallback. No RTP, economy data, limits, or gate changes belong in rw06_2.
  Probe19's plan/summary/trace/curve SHA-256 values are respectively
  `F8D4D24EA3982AC8C4B3E5D7864ACF7C8240F146DA9746BD1B85A34CDDF52452`,
  `AF647469BC70A4CEB63F3F3287D32B96A8E796077CAC35E66DF774BE030DD824`,
  `F72B12BA13A315E5FDD6D3F4B857B1FF2869ADC85FF8F2BD3756D810DC2A1D81`,
  and `1BB9E5CC5033717D1BB9E1AB3DB8855BF540A1D672C560967B748BD09DFEB6EA`.
  Its generic non-verbose ObjectDB warning is not canonically allowlisted: no
  `Leaked instance:` rows prove zero reference counts. The run remains
  non-qualifying on both the route failure and post-exit log gate.
- The public-liquidity replacement is engine-free green and awaits one fresh
  serialized verbose probe. It requires the rendered Grand fare plus the Clean
  route's existing $50 chip minimum, accepts at most one exact visible offer per
  lender id, and loss-stops the bounded slot fallback. Multiple rendered lenders
  are ordered by exact ordinal semantic id. Lender terms are parsed only from a
  fully rendered TalkDock; the replay verifies the exact armed confirmation,
  disclosed principal, exact bankroll increase, exact Result feedback, and a
  rendered debt-count increase of one. Because the public indicator exposes a
  count rather than debt identities, Crew funding is attempted only from a
  visibly debt-free HUD; no merge is inferred. Cash-event choices use exact
  rendered object/action identities and require the exact causal Result copy plus
  positive rendered bankroll and heat deltas. `machine_jam` always takes the
  exact visible de-escalation choice, **Wait it out**; it never infers hidden
  money or heat consequences. The source topology does not prove the fixed seed
  can retain the dynamic fare plus reserve after travel, so an insufficient route
  remains a classified exploratory finding, never an excuse to change economy,
  RTP, game math, or a gate.
- Final qualifying evidence intentionally waits for rw06_1 to land.

## Open route risks

1. Exact visible labels and semantic targets still require live-route audit.
2. The clean exploratory route reaches the invitation with $63 against a
   storm-adjusted $109 fare. Probe19's 24-spin slot-only policy lost $48. The
   public route also skipped deterministic cash events and disclosed lenders,
   so this is a replay-strategy defect and an rw06_3 friction measurement, not
   yet a proven product wall.
3. The clean lane is sequential: 1/+5, then 3/+15, then 5/+30. Its nine games
   and +$50 total may conflict with shorter player-facing summaries.
4. The Grand Casino route costs $70 before gambling capital.
5. A watched cheat plus contraband can turn the Pit Boss route into immediate
   failure; the replay should carry no classified gear.
6. The exact visible fresh-profile launch rejects stale seed
   `RW06-HEIST-AUDIT-0013`: its initial Grand cycle selects Convention. Q-013A
   adopts `RW06-HEIST-AUDIT-0002`, whose first Grand cycle selects Audit. Lasting
   Count eligibility is earned only by resolving the rendered
   `scenario_audit_roster/read_the_shift` choice; current Audit also qualifies,
   while unvisited seed data, stored prior-cycle hooks, narrative-only claims,
   and non-boolean save values fail closed. The runner does not inject Audit or
   choose Plan B. Fixed repeats reject every Heist seed except exact `0002`.
   Q-017A separately admits only exact `RW06-HEIST-AUDIT-0000` as a
   `fresh-interactive`, Repeat-1 pass after the production model proves its
   natural `day:0` Audit witness (run seed `1262406216`, stream seed `501255064`,
   none roll `96`, weighted roll `22402/26000`). It does not admit another
   natural-Audit candidate, inject a scenario, pin a cycle, or change routes.
   Before plan lock, the runner now requires the later visible
   Convention Crowd badge with no Audit Roster, returns to an enabled Count row,
   and preserves that exact public planning projection across a full
   Save/process-exit/Continue. The fresh hook, hostile revisit, Bishop Inner
   Circle route, restored authorization, and terminal win still need live proof,
   and the relationship/job cadence may exceed the target run length.
7. Plan B is materially longer, more expensive, and has no qualifying replay.
   It is not a fallback: the fixed route fails closed when Plan A is unavailable.
8. Save/quit/Continue must reuse isolated persistence without confusing a stale
   session process for a successful relaunch. Heist now compares the canonical
   public checkpoint plus the full visible planning projection and requires one
   fully rendered and enabled Count lock both before and after restoration,
   before lock mutation.

## Acceptance checklist

- [x] Rebase on the accepted rw06_0 main head and repeat source mapping.
- [ ] Exercise each route interactively through the bridge and freeze exact
      semantic decisions only after they work naturally.
- [x] Implement strict route helpers and public terminal assertions.
- [x] Add persistence checkpoints and canonical trace comparison.
- [x] Add hostile source-level redaction and semantic-command contracts.
- [x] Add Q-017A role/seed admission plus fail-closed source and data contracts;
      preserve exact fixed Heist `0002`, and pin fresh-interactive Heist `0000`
      to one natural-Audit Count run without scenario authority or Plan B.
- [x] Run the expanded Godot public-observation contract under a fresh serialized
      lease and retain its current report.
- [ ] Run each fixed seed twice and one fresh seed once.
- [ ] Update the three route documents from observed evidence.
- [ ] Run the slim rw06_2 gate, then the required post-rw06_1 acceptance pass.
