# Agent Prompt - Playtest Fix: Bankroll Must Not Reveal Results Before They Are Presented

Priority: playtest blocker for the 0.4 release (runs before the repackage
step).

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House` (Godot 4.6 GDScript casino
roguelike — see CLAUDE.md). Owner playtest: **the player bankroll updates
the moment a bet starts/resolves internally, not after the result is
visually apparent — spoiling game outcomes.** Watch the top bar during a
roulette spin: the payout is readable before the wheel stops.

## The architectural constraint that shapes this fix (binding)

The simulation deliberately settles at action time — e.g. roulette
resolves at spin START and the wheel animation plays out the already-known
`last_result`. That design is what keeps runs deterministic, save-safe,
and fuzz-proof, and it MUST NOT change. Do not delay actual settlement,
do not mutate RunState on animation timelines, do not touch resolve paths.
This is a **presentation-layer contract**: the *displayed* bankroll lags
the *actual* bankroll until the result-reveal moment.

## Required behavior

1. **Stake deduction may show immediately** — placing a bet visibly
   reducing the bankroll is correct and expected.
2. **Winnings/net results appear only when the result is apparent**: the
   wheel has stopped, the cards are revealed, the dice have landed, the
   reels have settled, the tab is opened. Concretely: introduce a
   presented-bankroll display value in the host bar that syncs to the
   actual bankroll at result-presentation boundaries (each game already
   has a payout-presentation moment/channel — reuse those signals; do not
   invent per-game timers).
3. Applies to **all seven games**, including multi-stage flows: slot
   autoplay chains sync per spin presentation; pinball/buffalo bonuses
   sync when the bonus presentation completes; blackjack multi-hand
   settles per-hand as each is revealed if the presentation is per-hand,
   else at round presentation.
4. Edge cases that must not desync the display:
   - Leaving the surface / traveling mid-animation → display snaps to
     actual immediately.
   - Save/load mid-presentation → on load, display equals actual (the
     presented value is derived state; it is NEVER serialized).
   - Closing-time eviction during grace, talk-dock interactions, and any
     bankroll change from a non-game source (event consequence, service)
     → display syncs to actual at once; only in-flight game results lag.
5. Anything else on the bar derived from bankroll (affordability tints,
   bet-availability states) must read the same presented value while a
   presentation is in flight, so the bar cannot leak the result through a
   side channel (e.g. a travel option lighting up before the wheel stops).

## Guard (so this cannot regress silently)

Foundation coverage per table game: script bet → resolve; sample the
host's displayed bankroll DURING the result animation window and assert
it equals the pre-result value; after the presentation completes, assert
it equals the settled value. Add the leave-mid-animation snap case and
the non-game-source immediate-sync case. Wire into the suites that
already run (ui/games), not an opt-in script.

## Verification

1. Manual: roulette spin with a winning bet — bankroll holds steady until
   the wheel stops, then pays; same spot-check in blackjack and slot
   autoplay.
2. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
3. `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`
   and `-FoundationSuite games -TimeoutSec 600` (with the new guard).
4. `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 5
   -SeedPrefix V04-BANKROLL` — proves the presentation layer touched
   nothing deterministic.
5. Note that 0.4.0 packages remain stale until the repackage step.
   Archive to docs/todone/ with the execution record; update QUEUE.md and
   commit per the queue lifecycle.

## Hard constraints

1. RunState/simulation untouched; presented value is derived, never
   serialized, never read by game logic.
2. One shared presented-bankroll mechanism in the host — not seven
   per-game copies.
3. Zero per-frame allocations; sync on presentation events, not polling.
4. Match house style: tabs, typed GDScript, sparse constraint comments.
