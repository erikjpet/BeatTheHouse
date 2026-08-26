Status: TODO
Board row: `world06_5` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_5: Coordinated Plays and Police Sweep Encounters

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
five shipped coordinated plays and the Police Sweep encounter ladder. It is not
a redesign of either economy. Read `scripts/core/crew_play_model.gd`
(`config`, `definition`, `default_state`, `normalize_state`, `available_actions`,
`availability` and the rest), `data/crew/plays.json`,
`scripts/core/police_sweep_model.gd` (`reset`, `disable`, `configure_world`,
`advance_to`, `status`, `intel_status`), the archived
`crew06_7_coordinated_plays_prompt.md` and `town06_3_police_sweep_prompt.md`,
the `world06_1` adapter contract and the `game06_1` ritual contract.

## Why this rework exists

The five plays — spotter, distraction, big player, chip dump, table flood — are
the moment the crew is physically in the room with you, and they currently
present as an action that applies a modifier and prints a voice line. The Police
Sweep walks the whole map with a hidden deterministic track and a costed
encounter ladder, and arrives as a choice list. Both are systems whose entire
point is presence.

## Board and dependencies

Follow the active board protocol. Claim `world06_5`. `world06_1` must be landed
and reviewed. The plays half also needs the `game06_1` actor vocabulary; if
Family 1's runtime has not landed, implement the sweep half first and record
that ordering with the integrator. You own `crew_play_model.gd`,
`police_sweep_model.gd`, `data/crew/plays.json` and their tests exclusively.

## 1. Plays become presence at the table

- Each of the five plays stages the member arriving, working and leaving, using
  the `game06_1` actor vocabulary at whichever game the play targets. The
  landed `game_ids` lists are the exact scope: spotter and big player at
  blackjack; distraction and table flood across blackjack, baccarat, roulette,
  craps and video poker; chip dump at baccarat.
- Preserve every landed contract exactly: `minimum_rank`, `uses_per_run`,
  `cash_cost`, `cooldown_boundaries`, `window_boundaries`,
  `detection_chance_percent`, `detection_heat`, the effect payloads, the
  `active_window_cap` and the `pairing_exceptions`.
- The chip dump ships as a player-funded transfer — `transfer_amount` 40,
  `transfer_fee` 6, direction `cash_to_chips`. That is the binding funding model;
  the old open question is answered by shipped data. Stage it as money physically
  changing hands and never let it create value.
- A play's window ending, its cooldown and its use exhaustion must be legible in
  the room, not only in a panel. The member leaving is how a window closes.
- Detection must be a staged beat: being noticed looks like something, and the
  landed heat consequence follows unchanged.
- The authored per-member voice lines stay; give them a body to be spoken from.

## 2. Sweep encounters become street moments

- The sweep's hidden deterministic track, its legibility channels, its wake and
  pressure model and its `intel_status` capabilities stay exactly as landed. This
  row changes the encounter, not the track.
- An encounter becomes a staged street moment with real positions, real exits, a
  readable officer presence and consequences that follow from where you are and
  what you are carrying — including delivery cargo from `world06_2`.
- The costed ladder keeps its landed costs and outcomes. Each rung must be
  distinguishable in play, not only in the resulting number.
- Swept-window looseness keeps its contract, and the aftermath of a sweep
  passing through a node must persist visibly at that node.
- A player who has read the sweep's legibility channels correctly must be able to
  act on that knowledge in the encounter. Intel that cannot be used is not intel.

## 3. Composition

- A play running at a table when a sweep arrives, a delivery in progress during
  an encounter, and a scenario sequence already mounted at the node must all
  compose safely with correct precedence and no lost base functionality.
- Nothing in either system may leak Turn or heist hidden state, including through
  a member's presence, absence or behavior state.

## 4. Persistence and honesty

- Every effect fires exactly once across save, exit, travel, revisit and expiry —
  play uses, costs, detection, heat, sweep encounter costs and aftermath.
- Save and revisit mid-play-window and mid-encounter must restore a legal state
  with no replayed reward, dialogue, audio or one-shot effect.
- A run that ignores the crew path is unaffected by the plays half and fully
  served by the sweep half.

## 5. Tests and acceptance

- All five plays exercised at every game in their landed `game_ids`, with every
  contract value asserted unchanged and money conservation proven for the chip
  dump including its fee.
- `active_window_cap` and `pairing_exceptions` enforced, including the
  `spotter:big_player` exception.
- Detection and non-detection paths staged and asserted at the landed rates
  across 10 seeds.
- Every sweep encounter rung played, with the landed costs and outcomes
  unchanged, including the cargo-carrying case.
- Composition tests: play plus sweep, delivery plus encounter, scenario plus
  encounter, each with save and load in the middle.
- Hidden-state audit across both systems.
- Exactly-once assertions for every effect across save, reload, revisit, expiry.
- 10-seed determinism, native/Web parity, performance with the idle liveness
  counter-gate, accessibility for every new interaction.
- Visual QA: each play arriving, working, detected and leaving at each of its
  games; each encounter rung; sweep aftermath at a node; reduced motion; small
  screen.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA. Archive only with
exact evidence and with the unchanged-contract table for all five plays and the
full encounter ladder attached.
