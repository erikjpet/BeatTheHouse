Status: TODO — independent review for `env06_8`; run by an agent that did not implement it
Board row: `env06_8` in `docs/todo/README_0_6_board.md`

# Review Prompt — env06_8: Environment Readability and Object Presentation

Copy everything below this line into a reviewer agent. **You must not have
implemented any part of `env06_8`.** If you did, you are the wrong agent.

---

You are the independent reviewer for `env06_8` in `D:\Projects\Beat-The-House`.
Read `docs/todo/env06_8_environment_readability_and_object_presentation_prompt.md`
in full before looking at the diff.

The owner reported this regression from their own playtest. Your job is to
determine whether a player would now experience the rooms the way the owner
asked for — not whether the tests pass.

## Verdict format

Exactly one of:

- `ACCEPT <exact-head>` with evidence per section below, or
- `REJECT <exact-head>` with actionable findings classified P0 / P1 / P2 / P3.

Acceptance is void the moment the head changes. Re-review the new head.

**Two rejections on this row escalate to the owner, not a third round.**

## 1. Sample the build yourself — do not read reports

Reading the implementer's evidence is not review. Launch the game and play it.

- Enter at least two scenarios per archetype, plus every scenario the implementer
  flagged as hard, unusual, or remediated.
- In each: select every object in the room. Confirm each has an icon, a label,
  a description, and a populated panel — actionable options or read-only flavor.
- Confirm `"Inspect this first."` is unreachable and no panel is ever empty.
- Advance the scenario through a material state change, then re-read the same
  objects. Confirm descriptions changed and are correct for the new state.
- Leave a scenario mid-sequence and return. Confirm you can reconstruct what
  happened from the room alone.

## 2. Verify the numbers against the baseline

The prompt records a measured baseline. Re-derive it on the accepted head and
compare — do not trust the implementer's table.

| Baseline | Was |
| --- | --- |
| Objects with no `zone_id` | 768 of 1,108 (69%) |
| Actions with no handler | 355 of 673 |
| `event_bridge` uses | 1 |
| Item or cash grants | 0 |

Reject if zoning is not complete, if actions still carry no handler, or if
conversation, reward and scene-change handlers are not genuinely in use. A table
that improved only because objects were deleted is a reject — check counts.

## 3. Descriptions must not lie

For a sample across archetypes, verify each description that implies a mechanical
effect against the actual effect in code or data. A description implying an
effect the object does not have is a P1. This is the most likely way this row
goes subtly wrong, because plausible-sounding flavor is easy to write and hard to
falsify by testing.

Also confirm the prose reads as authored narrative in the project's voice, not as
regenerated templates. Template prose is what this row exists to remove; if the
implementer generated new templates, that is a P1 regardless of how the tests
look.

## 4. Hidden-information audit — P0, blocking

This is the highest-risk part of the row and the reason it must be reviewed by
someone who did not write it.

Independently construct paired runs: identical seeds differing only in hidden
state — a crew member who has turned versus one who has not, a rigged Numbers
draw versus a clean one, an unrevealed ticket. Diff the complete description sets
from every object in every reachable state.

**Any difference is a P0.** Do not accept the implementer's proof; build your
own. Confirm no description, in any state, allows inference of the Turn's traitor
or grievance weighting, a rigged draw before its discovery conditions, unrevealed
ticket contents, or any other hidden system.

## 5. Placement and readability

- Confirm every phase passes overlap, reachability, z-order, text safety,
  small-screen and reduced-motion validation.
- Walk exit and service lanes in play. Confirm no scenario traps the player, and
  that any blocked route supplies a readable alternate exit.
- Review unlabeled contact sheets: objects must be identifiable from icon and room
  state alone, without titles or reward text.

## 6. Scope and parallel-safety

Other agents are working concurrently. Confirm the diff touches only the paths
`env06_8` owns and did not reach into `scripts/games/*`, performance harnesses
and budgets, `integ06_1` fixtures, tutorial lesson data, audio manifests, or the
`world06_*` crew models. Confirm `foundation_main.gd` changes are confined to the
scenario-object functions the prompt names, with no bulk reformatting.

Confirm no test was weakened, no golden refreshed without proof the content
legitimately changed, and no budget raised. Confirm RTP, EV, payouts, odds, wager
math, schema and migration are untouched.

## 7. Gates on the exact head

Project validation, scenario and sequence contracts, determinism, native/Web
parity, performance with the mandatory idle-liveness counter-gate — an idle draw
cost of 0.000 is a failure, not a pass — accessibility, save and revisit, and
visual QA. Confirm exactly-once behavior for every new consequence across save,
reload, travel, revisit, abort and expiry.

## 8. The row is not done until it is on `main`

**Do not issue `ACCEPT` on a branch and call the row finished.** Per the board
protocol, a pushed branch is `IN_PROGRESS` and branch existence is never
completion evidence.

After acceptance, the work must be merged to `main`, `main` must be green at that
exact head, the prompt archived to `docs/todone/`, and the board row must record
the merge commit. Verify that final state yourself and say so explicitly in your
report. If you accept the head but the merge has not happened, your report must
state that the row remains `IN_PROGRESS` and name what remains.

## Report

Lead with the verdict and the exact head. Then: what you played and where, the
re-derived baseline comparison table, your independent hidden-state proof method
and result, placement and contact-sheet findings, scope confirmation, the gate
table with commands and durations, and — if accepted — the merge commit on `main`
and its green gate result.
