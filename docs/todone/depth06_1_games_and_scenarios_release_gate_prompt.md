Status: COMPLETE — independent current-tree depth closure accepted 2026-09-03
Board row: `depth06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 depth06_1: Craps, Poker, and Scenario Depth Release Gate

Copy everything below this line into the agent.

---

This is the independent closure gate for the owner-requested depth program in
`D:\Projects\Beat-The-House`. It depends on `env06_6`, `env06_7`,
`craps06_3`, and `crew06_10`. Do not implement a substitute mini-pass and do
not mark it complete from child-row notes alone. Inspect the landed code,
content, reports, and player-facing build.

## Acceptance audit

1. Re-run the complete scenario dossier/uniqueness audit and account for all
   55 stable scenario ids. Reject missing ids, incomplete branches, duplicate
   mechanic signatures, reward-only sequences, and metadata-only room changes.
2. Randomly select at least two scenarios per archetype plus every high-risk
   multi-phase/game/crew/travel/sweep integration. Play arrival, partial exit,
   save/load, success, failure/refusal, terminal revisit, and expiry/cleanup.
3. Review per-archetype unlabeled contact sheets. Each variant must be visually
   identifiable from room/actor/object state without title, signage, palette,
   or reward text. Similarity requires remediation, not a waiver.
4. Play full Grand Casino and street-craps sessions covering bet correction,
   tactile throw, point lifecycle, dense working bets, energy tiers, cheats,
   dynamic room reactions, warning/relocation/dispersal, accessibility, and
   revisit. Re-verify math/RTP and money conservation.
5. Play multiple back-room poker nights with all seven members, ordered betting,
   raises/folds/showdown, overlapping tells, leave/revisit/new session, every
   authored night sequence, and Turn clue compatibility. Verify pot/cash/trust
   exactly once and no hidden-information leak.
6. Stress composition: scenario + game + event + service + traveler + Police
   Sweep + save/load at the same node. Verify safe exits and no lost base
   functionality or orphaned object/hit state.
7. Re-run full project, content, systems, UI, save, accessibility, determinism,
   native/Web parity, performance, RTP, and visual gates on the exact tree.

## Deliverable

Create a closure report mapping each requirement to code/data, automated
evidence, and captures. List any remediation commits. This row remains TODO or
BLOCKED if even one of the 55 variations lacks a unique playable sequence, if
craps/poker still resolve as static control panels, or if a consequence can
double-fire across save/revisit. On pass, archive this prompt and note the exact
commit and report paths on the board.

## Execution record — 2026-09-03

Audited the landed product tree without rebuilding it. All four child rows are
accepted together; the current audit reports 55 stable ids, 1,485 pair
comparisons, zero failures, complete hard-definition/lifecycle dossiers, and
reviewed warning-band visuals. A reproducible two-per-archetype sample passed,
as did the focused Craps/Poker, RTP, hostile authority, scenario registration,
actual-renderer visual, and byte-identical two-pass 10-seed determinism gates.
Depth-owned native/Web and performance evidence remains green. An overlapping
broad performance run's Coin-Pusher-only red is retained and routed rather
than misreported as a depth pass. Exact evidence and human-playtest handoff are
in `docs/plans/depth06_1_final_closeout.md`.
