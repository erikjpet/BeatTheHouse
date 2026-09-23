# rw06_2 ending replay design — first-pass implementation

Status: **IMPLEMENTED; LIVE ROUTE ACCEPTANCE PENDING rw06_1/rw06_5**
Implementation base: `origin/main` at `7da3e5dab59b`

The release deliverable is `tools/rw06_2_ending_replay.ps1 -Ending
clean|cheat|heist`. It must drive the production `scenes/main.tscn` host through
the existing player-input bridge, assert a visible terminal win, and exit
nonzero at the first route deviation. It is a player replay, not a state-builder.

## Authority rules

- Start and command isolated sessions through `tools/agent_playtest_session.ps1`.
- Use only rendered `click_button`, semantic `click_object`, `click_action`,
  `click_map`, `click_choice`, `click_inventory`, public text-field entry,
  waits, and quit/relaunch.
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
- Final qualifying evidence intentionally waits for rw06_1 and rw06_5 to land.

## Open route risks

1. Exact visible labels and semantic targets still require live-route audit.
2. No hands-on UI run is permitted yet, so seeds and wager policies are
   provisional.
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
