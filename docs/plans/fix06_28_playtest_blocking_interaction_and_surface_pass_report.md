# fix06_28 Playtest-Blocking Interaction and Surface Pass

Date: 2026-09-07  
Implementation branch: `codex/fix06_28-playtest-interactions`

## Outcome

The owner-playtest blocker is fixed. The production `FoundationMain` host now
gives an immediate visible acknowledgement for accepted scenario actions,
clears stale travel/result text at action boundaries, and retains the room's
authenticated semantic inventory across revisit and save/load. Distinct,
state-aware room props make the selectable objects and machine surfaces
recognizable without exposing hidden outcome state.

The production-fidelity working-order pass used real viewport mouse input,
resolved every target by exact semantic id, and accepted only player-visible
outcomes. Three deterministic seeds completed with zero failures: 130 rendered
object selections and 74 actions across 43/24, 39/23, and 48/27
object/action inventories. Every seed also repeated travel/revisit and
Save/Continue. Focused Crew, Punchline, slot, Coin Pusher, Scratch, Pull Tabs,
Video Poker, Roulette, Dice, and card-surface routes passed.

## Why the former suite was falsely green

Four evidence defects combined to admit a build the owner could not play:

1. The old surface harness called `start_game_test_session()` and the private
   `_on_game_surface_action()` method. It bypassed the room, the selectable
   object, and actual viewport input.
2. The old visual harness injected fixture environments and direct state, then
   accepted generic focus, surface, or serialized-state changes even when the
   player saw no acknowledgement.
3. Direct execution of split Foundation runners could hit a missing dynamic
   shard method, still print `PASS`, and exit zero.
4. The acceptance wrapper reported a successful handoff despite 65 Crew-route
   failures.

The replacement authority contract requires the production host, exact
semantic id, actual mouse input, and a visible result. Direct split runners are
now fail-closed, the shared harness records the rendered target it actually
clicked, and the acceptance wrapper rejects any failed route.

## Player-facing and authority repairs

- All 673 clickable scenario actions have a visible acknowledgement path; the
  729-handler inventory also includes 56 subscribed state/feedback handlers.
- Scenario and world-sequence actions clear stale result text before execution
  and project their immediate acknowledgement into a visible result surface.
- Revisit/save preserves a valid, exactly bound scenario inventory. Only newly
  validated, unconsumed dynamic delivery/NPC sources may extend it; forged,
  removed, or unrelated sources fail closed.
- Presentation fingerprints exclude presentation caches. Hidden state does not
  enter labels, icons, public descriptions, or the 40-bit visible marker.
- Per-frame packed-array construction was removed from four drawing paths, and
  every tested idle surface retained a nonzero draw/liveness counter.

## Verification

- Project validation: PASS on the implementation tree.
- Production-fidelity three-seed working-order pass: PASS, 130 object
  selections and 74 actions, including repeated travel/revisit and
  Save/Continue.
- Six surface families: PASS. Coin Pusher accepted 48 pointer drops, drained
  its queue, and displayed the terminal no-payout result exactly once.
- Slot production entry: PASS for two seeds; actual mouse input changed spin
  count `0 -> 1`, cleared pending state, rendered a six/five-column cabinet,
  and rejected a stale causal token.
- Slot content and contract smoke: PASS under the direct fail-closed runner.
- Machine ritual, cabinet visuals, idle liveness, and acceptance-authority
  contracts: PASS.
- Crew recruitment: PASS for all seven routes, Plan B, visible favor/job/
  delivery actions, and the no-op golden.
- Punchline: PASS through club/casino travel, revisit, Save/Continue, and all
  rendered-object audits. The naturally gated L3 back-room entry was not
  earned in this bounded run and is filed exactly as `fix06_29`.

An additional broad generated `contracts` runner is not claimed green. It
timed out after 300 seconds with 70 existing nil-helper script errors in
scenario-sequence lifecycle probes before it could return a verdict. The
required direct slot and product-fidelity gates passed; the broad runner defect
is filed separately as `fix06_30` so it cannot become another false-green gap.

The ignored Crew golden was refreshed only after a recursive full-value
comparison against `25d9231d`: both seeds were identical through initial Bar,
action boundary, and ordinary travel. Revisit/save added exactly the persisted
`scenario_semantic_inventory` at two mirrored environment paths, with zero
Crew-state differences.

No money, RNG, RTP, payout, odds, schema, or migration logic changed. No Web
export, package, tag, publish, version bump, or release gate was run.

## Landing and owner build

Implementation head `8b0b74c3` merged cleanly to `main` at `f8ab6851`.
Whole-project validation passed on both the implementation head (79.4 seconds)
and merge head (82.5 seconds).

The first authorized Windows export exposed the previously recorded wrapper
false negative: the Windows branch assigned Godot's stdout and its final zero
exit status together, so the array compared unequal to zero after a successful
pack. `bac514c6` records only `$LASTEXITCODE` after forwarding stdout, and a
permanent owner-build contract forbids the capture form. That contract passed.

`tools/export_itch.ps1 -Target windows -NoPackage` then passed in 86.6 seconds.
It created `builds/windows/BeatTheHouse.exe` at 171,530,840 bytes with SHA-256
`0A0C4004E4E86B4E738A09D1B194D1D57526E3A9A80249FB9664187E6B39AE68`.
The executable remained alive for the complete 12-second launch-smoke window.
The process was then stopped by exact pid. No archive or upload artifact was
created.

