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
