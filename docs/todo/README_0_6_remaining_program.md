# 0.6 Remaining Work — PM operating page

Created: 2026-08-25. Program design:
`docs/plans/0.6_remaining_work_program.md`. Execution state stays on
`docs/todo/README_0_6_board.md`, which is still the single source of truth.

This page is for the project manager. It says what to launch, when, and what to
do while it runs. The agents get the prompts; the PM gets this.

## The shape

Twenty-five rows in three families, each family driven by one launcher prompt
that a PM copies into a single primary integrator agent. That integrator employs
sub-agents, reviews their branches independently, merges through its own
integration branch, and merges back when its release gate passes.

| Family | Launcher | Rows | Gate |
| --- | --- | --- | --- |
| 1 — Game depth parity | `game06_0_game_depth_orchestration_prompt.md` | `game06_1`–`game06_8` | `game06_8` |
| 2 — Crew and world depth | `world06_0_crew_world_depth_orchestration_prompt.md` | `world06_1`–`world06_7` | `world06_7` |
| 3 — Cross-cutting | `cross06_0_cross_cutting_orchestration_prompt.md` | ten rows, mixed timing | per-row |

Each launcher is self-contained: authority, preflight, worktree topology, waves,
self-review protocol, independent review protocol, merge discipline, final merge,
and terminal conditions. A PM does not need to explain the house rules to an
integrator — the launcher does it.

## Launch order

**Today, with no further dependencies:**

- Family 3's Wave 1 — `meta06_1`, `balance06_1`, `board06_1`, `polish06_0`.
  Launch `cross06_0` now; its own scheduling section holds the later rows until
  their dependencies land.

**When `craps06_3` lands (from the in-flight depth program):**

- Family 1. `game06_1` must generalize the craps ritual rather than invent a
  rival vocabulary, so it cannot start earlier. Launch `game06_0` at that point;
  the integrator uses the waiting time for its read-only audits.

**When `env06_6` lands (from the in-flight depth program):**

- Family 2. `world06_1` bridges crew systems onto that runtime. Launch
  `world06_0` at that point.

**When `pusherv3_10` lands:**

- `pusherv3_11`, inside Family 3. It must be owned by an agent that implemented
  no V3 row.

**After both depth families merge:**

- Family 3's Wave 3 and 4 — `audio06_1`, then `integ06_1` and `perf06_1` in
  parallel, then `teach06_2`, then `playtest06_2` last.

Families 1 and 2 can run concurrently once their dependencies clear. They touch
different files: Family 1 owns the game modules and the shared surface layer,
Family 2 owns the crew models and the EventModule crew seam. `world06_5` is the
one row that needs both — it uses Family 1's actor vocabulary for crew presence
at tables, and its prompt says to build the sweep half first if that vocabulary
has not landed.

## What the PM does

1. **Launch one integrator per family.** Do not split a family across two
   integrators; the launcher assumes one accountable owner of the board section
   and the merge queue.
2. **Arbitrate the board.** Three integrators plus the depth program will all
   want to edit `README_0_6_board.md`. Only integrators edit it, only for their
   own section, and `board06_1` needs a confirmed quiet window before it
   restructures the file.
3. **Route audit findings.** `balance06_1`, `integ06_1`, `perf06_1` and
   `pusherv3_11` produce findings, not fixes. They become `fix06_*` rows or go
   back to the owning family. An audit branch that quietly rewrites the thing it
   audits has destroyed its own evidence — that rule is in every audit prompt and
   the PM enforces it.
4. **Hold the line on scope.** No row in this program performs release activity.
   No row changes RTP, EV, payout tables, odds or any landed economic value.
   `polish06_0` designs the second half and stops. `release06_1` remains the only
   row that ships anything, and it stays parked.
5. **Answer, or escalate, the questions the integrators raise.** A genuine
   blocker arrives with three attempted approaches, exact evidence and the
   smallest decision needed. Anything else is work.

## The standards every row inherits

These recur in every prompt because this project has been burned by each:

- **Idle liveness.** An idle draw cost of 0.000 is a failure, not a pass. The
  counter-gate in `scripts/ui/performance_liveness_guard.gd` is mandatory
  wherever a surface is touched. Four recorded regressions.
- **No per-frame deep copies.** The slot bonus watchdog cost 32.6 ms/frame.
- **Action boundaries, never wall-clock.** Everything seeded from run RNG.
- **Exactly once.** Every consequence fires once across save, reload, travel,
  revisit, abort and expiry.
- **Hidden state is absolute.** No Turn, traitor, grievance, rigged-draw or
  unrevealed-ticket information may leak through scene data, serialized keys,
  captures, audio or fixtures. A leak is an automatic P0.
- **The crew-ignoring run is a true no-op.** It broke once; the golden probe
  exists because of it.
- **Rules and math are preserved.** Depth changes presentation and interaction.
  A depth row that needs a math change files it instead of making it.
- **A sequence replaces a choice list.** Staging a room and then presenting the
  same four choices has converted nothing.

## Terminus

Unchanged: the board still ends at the owner's playtest. These three families sit
between where the board is now and that handoff. `playtest06_2` rewrites what
`playtest06_1` verifies so the handoff describes the game that will actually be
played. `voice06_1` and `release06_1` stay parked until the owner opens the
second half, and `polish06_0` is what defines that half before it is needed.
