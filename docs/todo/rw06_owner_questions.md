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
Status: OPEN
Asked: release orchestrator, 2026-09-23
Question: Does this fixed-slot direction look right for Bar, Corner Store and Grand Casino in normal and expanded views? Sheet: `D:\Projects\Beat-The-House-worktrees\rw06_1-phase0\.tmp\rw06_1\contact_sheet\day2_4fd4c350_repair2_20260923-1312\day2_contact_sheet.png` (SHA-256 `8F37493B765573E4BDFE0C5F03A196B82F6E537A9600405EB0E6AC8E127D29C1`).
Options: A) Direction approved; continue (recommended)  B) Needs changes; list the rooms or issues in Answer
Resume: rw06_1 continues while OPEN. When ANSWERED, the release orchestrator applies blocking layout feedback before landing, logs non-blocking polish in `docs/plans/0.6.1_backlog.md`, updates the scoreboard, and marks Q-006 RESOLVED.
Answer:
