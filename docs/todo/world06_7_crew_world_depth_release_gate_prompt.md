Status: TODO
Board row: `world06_7` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_7: Crew and World Depth Release Gate

Copy everything below this line into the agent.

---

This is the independent closure gate for the crew and world surface depth
program in `D:\Projects\Beat-The-House`. It depends on `world06_1` through
`world06_6`. Do not implement a substitute mini-pass and do not mark it complete
from child-row notes alone. Inspect the landed code, data, reports and the
player-facing build yourself.

You did not own any of the implementation branches. If you did, you are the
wrong agent for this row.

## Acceptance audit

1. Account for every crew and world interaction named in the `world06_1` seam
   inventory. Each must be either a played sequence or an explicitly justified
   remaining choice. Reject any "sequence" that stages a room and then presents
   the same choice list, any reward-only conversion, and any metadata-only room
   change.
2. Play the full crew path end to end on at least three seeds: recruitment
   through trust rungs, jobs of all five kinds, deliveries and holds, the
   Numbers including a rig route, coordinated plays at their games, a Police
   Sweep encounter while carrying cargo, both heist plans, and the Turn
   confrontation with and without a traitor in play.
3. **Hidden-information audit — the blocking one.** With full access to the
   serialized save, scene state, actor state, captures, logs and test fixtures,
   attempt to determine the traitor, the grievance weights and the resolution
   state before the Turn's contract discloses them. Attempt it for a run where
   a member has turned and one where none has, and confirm the two are
   indistinguishable. Any distinguishing signal is a P0 and blocks closure.
4. Verify all three clue channels emit honestly at their landed rates in staged
   scenes, and that a player can act on a correctly read clue.
5. Verify exactly-once semantics for every consequence in the program — rewards,
   trust, grievances, heat, debts, costs, aftermath — across save, reload,
   travel, revisit, abort and expiry, in every order you can construct.
6. Verify the crew-ignoring run is a true no-op: no mounting, no scanning, no
   rebuilt map nodes, no measurable cost. Run the golden probe and confirm it
   was extended rather than bypassed.
7. Stress composition at shared nodes: crew sequence plus environment scenario
   plus event plus service plus traveler plus Police Sweep plus save and load.
   Verify ordinary travel, ordinary events and base environment functionality
   survive everywhere a crew sequence can mount.
8. Verify every landed economic and contract value is unchanged: job payloads,
   rewards, failures and grievances; play ranks, uses, costs, cooldowns,
   windows, detection rates and heat; sweep encounter costs; Numbers odds,
   payouts and tuning; heist outcome ladders. Compare against the unchanged-value
   tables each row was required to attach.
9. Verify tactile verbs have working keyboard, controller and reduced-motion
   equivalents producing identical outcomes and fair timing.
10. Review unlabeled contact sheets per system. Each staged sequence must be
    identifiable from room, actor and object state without titles or reward text.
11. Performance on the exact tree: no per-frame work that belongs at a boundary,
    no per-frame deep copies, the idle-liveness counter-gate green for every
    touched surface, and Web and low-end checked alongside native. An idle draw
    cost of 0.000 is a failure.
12. Re-run full project, content, systems, UI, save, accessibility, determinism,
    native/Web parity, performance and visual gates on the exact tree, plus the
    full Rourke duel and Players Card route regressions.

## Deliverable

Create a closure report mapping each requirement to code, data, automated
evidence and captures, with a per-system table showing converted interactions,
verbs and their equivalents, actor set, aftermath persistence, unchanged-value
verdict and overall verdict. Attach the complete hidden-information audit as its
own section with the exact method used. List any remediation commits.

This row remains TODO or BLOCKED if any named interaction is still a choice list
without justification, if any consequence can double-fire, if any landed
contract value moved, if the crew-ignoring run is not a true no-op, or if the
hidden-information audit finds any distinguishing signal. On pass, archive this
prompt and note the exact commit and report paths on the board.
