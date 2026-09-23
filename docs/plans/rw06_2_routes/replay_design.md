# rw06_2 ending replay design — first-pass implementation

Status: **IMPLEMENTED; EXPLORATORY LIVE RUN STARTED; ACCEPTANCE PENDING rw06_1**
Implementation base: `origin/main` at `7da3e5dab59b`

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
- Branch only on the bridge's player-observable JSON: screen/environment,
  rendered controls, room/game actions, HUD/objective, feedback, dialogue,
  inventory, and run report.
- Treat any `SCRIPT ERROR`, error, warning, rejected command, ambiguity, missing
  semantic target, or unexpected modal as a hard failure.

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
   - assert public money, heat, objective, route beat, and log health.
4. Write one compact transcript record per accepted player action: ordinal,
   intent, command, screen/environment identity, bankroll/chips/heat, public
   objective signature, event/game surface, and result/outcome copy.
5. At the route's required midpoint, open the visible run menu, Save, Main Menu,
   quit the process, relaunch the same session, Continue, and compare a
   canonical public checkpoint signature.
6. At the terminal beat, require:
   - `status_hud.run_status == "ended"`;
   - the public demo objective/report is complete;
   - the run report's player-facing outcome matches the requested ending;
   - no log alerts or unacknowledged route deviations;
   - the action count is reported against the 150–350 target.

## Determinism proof

For each ending, run the same seed and intent policy twice in clean isolated
profiles. Canonicalize only player-visible progression: accepted command intent,
screen/environment, public money/heat/objective, dialogue choice IDs, game
actions/results, persistence checkpoint signature, and final public outcome.
Exclude process IDs, paths, screenshots, wall-clock timestamps, control rects,
and animation-only timing. The two canonical traces must be identical.

Then complete a third interactive run on a fresh seed. The fresh run need not
match the fixed trace; it proves the route is understandable rather than merely
memorized.

## Evidence layout

Each invocation creates an ignored timestamp/PID root:

```text
.tmp/rw06_2/<ending>/<timestamp>-<pid>/
  run-01/
    public_trace.ndjson
    money_curve.ndjson
    summary.json
  run-02/
    public_trace.ndjson
    money_curve.ndjson
    summary.json
  summary.json
```

Keep milestone/failure screenshots rather than reviewing hundreds of redundant
frames. The committed route documents should link the exact transcript,
checkpoint, screenshots, and final summary used for acceptance.

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

- `rw06_2_replay_source_contract.ps1` passes. It parses both PowerShell entry
  points and enforces route, semantic-input, persistence, terminal-outcome,
  privacy, and deterministic-hash source contracts.
- `rw06_2_public_observation_contract.gd` passes against hostile twin fixtures.
  Concealed hole cards, shoe/order, run/session state, narrative flags, trigger
  context, Crew private capsule fields, and scenario audit fields do not alter
  the public fingerprint or appear in serialized output. Revealing the dealer
  hand through its public flag does alter the checkpoint as intended. Focused
  evidence: `D:\Projects\Beat-The-House-worktrees\rw06_2-prep\.tmp\rw06_2\public_observation_contract.json`
  (SHA-256 `F8F699846DB1CFD6C5659F7A9D10F42C77CAB4F8573C4C5EE19D28E683889195`).
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
- Final qualifying evidence intentionally waits for rw06_1 to land.

## Open route risks

1. Exact visible labels and semantic targets still require live-route audit.
2. Exploratory UI runs have not reached the route economy yet, so seeds and
   wager policies remain provisional.
3. The clean lane is sequential: 1/+5, then 3/+15, then 5/+30. Its nine games
   and +$50 total may conflict with shorter player-facing summaries.
4. The Grand Casino route costs $70 before gambling capital.
5. A watched cheat plus contraband can turn the Pit Boss route into immediate
   failure; the replay should carry no classified gear.
6. Plan A needs a naturally reached Audit Night plus Bishop Inner Circle. The
   relationship/job cadence may exceed the target run length.
7. Plan B is materially longer and more expensive, so it is a fallback route,
   not the initial replay target.
8. Save/quit/Continue must reuse isolated persistence without confusing a stale
   session process for a successful relaunch; the replay compares only a
   canonical public checkpoint.

## Acceptance checklist

- [x] Rebase on the accepted rw06_0 main head and repeat source mapping.
- [ ] Exercise each route interactively through the bridge and freeze exact
      semantic decisions only after they work naturally.
- [x] Implement strict route helpers and public terminal assertions.
- [x] Add persistence checkpoints and canonical trace comparison.
- [x] Add hostile redaction and semantic-command contracts.
- [ ] Run each fixed seed twice and one fresh seed once.
- [ ] Update the three route documents from observed evidence.
- [ ] Run the slim rw06_2 gate, then the required post-rw06_1 acceptance pass.
