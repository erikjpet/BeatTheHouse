# Owner Questions — the only channel between agents and the owner

**Canonical copy:** `D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`
(the primary checkout). Always read and edit that absolute path, even when you
work in a worktree. Worktree or `origin/main` copies may be stale.

## Protocol (every agent)

1. **Ask and move on.** When you need an owner decision:
   - append one entry at the end of this file;
   - set your row's scoreboard or ledger note to `WAITING Q-NNN`;
   - immediately continue with other work that doesn't depend on the answer.

   Never sit idle waiting.
2. **Check before continuing.** At the start of every work session, and before
   any step marked "owner decision", read this file. For every `ANSWERED` entry
   whose `Resume` names work you now own, do that work. Then set the entry's
   status to `RESOLVED by <agent> <date>`. The agent that resumes does not have
   to be the one that asked.
3. **Editing rules.**
   - Re-read the file immediately before every edit.
   - Append new entries at the end. Change only the `Status` line of existing
     entries.
   - Never edit or delete `Answer`.
   - Number entries `Q-001`, `Q-002`, and so on, in order.
4. **Writing a question.**
   - Keep it short, precise and non-verbose. The owner answers within a few
     hours.
   - Give the options and your recommendation, so the owner can reply "A".
   - Put the context the next agent needs in `Resume`, not in the question.
5. **Git.** Only the orchestrator commits this file, from the primary checkout,
   after `git pull --ff-only`, as a commit touching this file alone. Other agents
   only edit it on disk. Hard owner gates (source approval, artifact approval,
   publish authorization, day-2 room sample) are asked here too.

Entry format:

```
### Q-NNN · <row> · <short title>
Status: OPEN | ANSWERED | RESOLVED by <agent> <date>
Asked: <agent>, <date>
Question: <one or two sentences>
Options: A) … (recommended)  B) …
Resume: <exactly what to do, and where, once answered>
Answer: <owner writes here, then sets Status: ANSWERED>
```

---

## Entries

### Q-001 · rw06_4 · itch.io target
Status: RESOLVED by release orchestrator 2026-09-23
Asked: PM, 2026-09-22
Question: What is the itch.io butler target (`user/game-slug`) for Beat the House, and is butler already logged in on this machine?
Options: A) `<your-user>/beat-the-house`, logged in  B) other (write it)
Resume: rw06_4 uses it for `tools/export_itch.ps1 -Push -ItchTarget <target>`, only after publish authorization (a separate question). Agents never enter credentials; if butler isn't logged in, the owner logs in.
Answer:

i am not looking foryou to ever update the web version for me i will always do this so please do not execute that command. continue without updating the web version simply provide the zip to upload

### Q-002 · rw06_5 · Cass count scope
Status: RESOLVED by release orchestrator 2026-09-23
Asked: release orchestrator, 2026-09-22
Question: Which blackjack count may Cass accept as an active count?
Options: A) Only the live, unshuffled shoe at the player's current table (recommended)  B) Any live table in the current room
Resume: rw06_5 continues with strict option A while OPEN; once answered, apply the selected scope to `requires_active_count`, its disabled reason, and Cass regression coverage.
Answer:

B is fine as llong as you hvae something to pass to them

### Q-003 · rw06_4 · Owner directive: never upload; deliver zips
Status: RESOLVED by release orchestrator 2026-09-23
Asked: PM (owner directive, from Q-001), 2026-09-23
Question: None; this is a standing owner directive. The committed `rw06_4_release_gate_ship_prompt.md` and `README_0_6_release_week.md` still describe `tools/export_itch.ps1 -Push` and an itch upload. That contradicts the Q-001 answer and must be amended so no later sub-agent follows it.
Options: A) Amend as described in Resume (the owner's decision)
Resume: Orchestrator: amend `rw06_4_release_gate_ship_prompt.md`, `README_0_6_release_week.md` (Deliverable) and `rw06_execute_release_week_prompt.md` so that:
1. No agent ever runs `export_itch.ps1 -Push`, butler, or any upload or publish command.
2. The deliverable is two upload-ready zips, the itch.io Web build and the Windows `.exe` build, both at 0.6.0, built with `tools/export_itch.ps1` (no `-Push`). Each passes the PCK audit and the packaged smoke checks.
3. The "publish authorization" gate becomes "artifact handoff": post the zip paths and SHA-256 hashes here for the owner, who uploads them personally.
4. Tagging `v0.6.0` happens after the owner confirms in this file that they uploaded.
Commit the amendments, then set this entry to RESOLVED.
Answer: A. The owner always updates the web version personally. Provide the zips only.

### Q-004 · rw06_1 · Interim three-room room layout
Status: RESOLVED by release orchestrator 2026-09-23
Asked: release orchestrator, 2026-09-23
Question: Does the interim fixed-slot layout direction look right for Corner Store, the Bar and Grand Casino in normal and expanded views? The current-tip sheet is `D:\Projects\Beat-The-House-worktrees\rw06_1-phase0\.tmp\rw06_1\contact_sheet\interim_44758fad\day2_contact_sheet.png`.
Options: A) Direction approved; continue (recommended)  B) Needs changes; list the rooms or issues in Answer
Resume: rw06_1 continues while OPEN. When ANSWERED, the orchestrator applies any layout feedback across all rooms, records non-blocking polish in `docs/plans/0.6.1_backlog.md`, and marks this RESOLVED.
Answer:

There is no image as you suggested in that location, and the image all_rooms_contact_sheet.png does not show anything useful in making this decision. it seems fine for whats placed but this sint the full picture i need to confirm

### Q-005 · rw06_1/rw06_2 · Owner morning execution steer
Status: RESOLVED by release orchestrator 2026-09-23
Asked: PM (owner directive), 2026-09-23
Question: None; this is the owner's binding release-week steer.
Options: A) Execute the directive in Resume (the owner's decision)
Resume: Ask Q-004 from an interim current-tip contact sheet now. Land rw06_1 on `main` by end of 2026-09-24; if optional walk/swept-route work threatens that, keep the actor stationary and log it for 0.6.1, and send non-fitting objects to overflow. Never weaken overlap, exit, action-reachability or hidden-state guarantees. Run focused rw06_1 Godot contracts now. Start non-qualifying rw06_2 exploratory ending runs on current `main` now; qualifying runs remain after rw06_1 lands.
Answer: A. Directive received from the owner on 2026-09-23 morning.

### Q-006 · rw06_1 · Reviewable three-room fixed-slot sample
Status: RESOLVED by release orchestrator 2026-09-23
Asked: release orchestrator, 2026-09-23
Question: Does this fixed-slot direction look right for Bar, Corner Store and Grand Casino in normal and expanded views? Sheet: `D:\Projects\Beat-The-House-worktrees\rw06_1-phase0\.tmp\rw06_1\contact_sheet\day2_4fd4c350_repair2_20260923-1312\day2_contact_sheet.png` (SHA-256 `8F37493B765573E4BDFE0C5F03A196B82F6E537A9600405EB0E6AC8E127D29C1`).
Options: A) Direction approved; continue (recommended)  B) Needs changes; list the rooms or issues in Answer
Resume: rw06_1 continues while OPEN. When ANSWERED, the release orchestrator applies blocking layout feedback before landing, logs non-blocking polish in `docs/plans/0.6.1_backlog.md`, updates the scoreboard, and marks Q-006 RESOLVED.
Answer:

B: this is not only disfunctional but worse than it was. things need to be in assigned locations but still randomized. for example game 1 2 and 3 must always be in the same spot. shop slot 1,2,3 etc. so it is defined where items go but the specific instances of items or games, or events is the randomized part. do you understand? so here is my specific responses.
BAR: all games should be on counter event objects should go in slots by pool table bar and floor. people need to be behind bar not floating in air. bartender behind bar etc. intuitively place items where they would be in a real situation of the environment.
STORE: good that items are on left shelf but they need to be alligned and not overlapping, also we need to ensure scenerio objects dont overlapp and are place in an intuitive close lcoation like below item shelf etc. ensure all people are on ground except shopkeeper who is lined up behind counter. we need to make sure all of the shopkeeper dialogue events span here by him, also make the counter phone on the counter consistently and drinks solf by the beer sign.
grand casino: this is the worst one. objects ar eeverywhere we need clear defined areas for each so they are intuitive and in known groupings instead of random and no  associated with the background general layout and background image. re assess this rooms palcement completely and ensure slots are in known locations card tables coorelate with background locations and machines are alligned accordingly.
### Q-007 · rw06_1 · Owner amendment to Q-006: hand-authored, art-aligned slots
Status: RESOLVED by release orchestrator 2026-09-23
Asked: PM (owner amendment), 2026-09-23
Question: None; this is a binding owner amendment that clarifies how to apply Q-006.
Options: A) Apply as described in Resume (the owner's decision)
Resume: rw06_1 must rework the slot layout under these rules before landing:
1. Place slots by hand against each room's background art, not computed by `tools/rw06_1_author_fixed_slots.py` or any search or solver. The generator may only be used to write out hand-chosen coordinates.
2. Give each room named, typed slot groups in fixed positions:
   - `game_1..N` on counters, tables or machine rows that match the art;
   - `shop_item_1..N` on shelves, aligned and non-overlapping;
   - `staff_*` behind counters;
   - `patron_*` on the floor;
   - `event_*` near the matching fixture (pool table, bar, shelf, counter);
   - fixed spots for recurring props (phone on the counter, drinks by the beer sign).
   Only which instance fills a slot is random.
3. Nothing floats: people stand on the floor or behind counters, and objects sit on a surface.
4. Scenario objects get their own slots next to the fixture they relate to. They never overlap base objects.
5. Grand Casino: redo it completely. Card tables go where the art shows tables, machines line up in rows, and each area gets a clear grouping.
6. Before landing, ask a new questions-file item with a fresh 3-room sheet (Bar, Corner Store, Grand Casino), shown without debug overlays so the owner sees what a player sees. Also apply these rules to all other rooms.
Answer: A. Owner amendment to Q-006, 2026-09-23.

### Q-008 · rw06_1 · Fresh hand-authored three-room player view
Status: OPEN
Asked: release orchestrator, 2026-09-23
Question: Does the fresh player-view layout for Bar, Corner Store and Grand Casino match the hand-authored, art-aligned direction? Sheet from exact commit `8a7a1ae8`: `D:\Projects\Beat-The-House-worktrees\rw06_1-phase0\.tmp\rw06_1\contact_sheet\day2_8a7a1ae8_20260923-1854\day2_contact_sheet.png` (SHA-256 `40CF5E5B771C9A8BEF01562E486CAC5A6429434BA2DF2D3FF1C24C0C5500E6BF`).
Options: A) Approve this direction (recommended)  B) Needs blocking changes; list the room and issue in Answer
Resume: rw06_1 continues its remaining acceptance gates while OPEN. When ANSWERED, the release orchestrator applies any blocking feedback before landing, records non-blocking polish in `docs/plans/0.6.1_backlog.md`, and marks Q-008 RESOLVED; A clears the visual gate.
Answer:
