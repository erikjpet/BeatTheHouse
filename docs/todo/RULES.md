# docs/todo — Rules of Use

This folder is the backlog of record for agent-executable work. It contains
**only** full prompt files: complete, self-contained instructions for a unit of
work that has not yet been executed.

## What belongs here

1. Every file in this folder (except this one) MUST be a complete agent
   prompt: enough context, file/line references, hard constraints, and
   verification gates that an agent with no access to prior conversations can
   execute it correctly.
2. One file = one unit of work. Do not bundle unrelated tasks into one prompt.
3. File names are snake_case and end in `_prompt.md`
   (e.g. `web_audio_bridge_modernization_prompt.md`).
4. Prompts MUST be researched before they are written here. A prompt states
   investigated root causes and cites evidence (file:line, commit hashes,
   external sources), not guesses.
5. Nothing else lives here: no notes, no scratch files, no generated reports,
   no status boards.

## How to execute a prompt

1. **Selection and looping are governed by `QUEUE.md` in this folder.** When
   told to "work on the todo list" (or any equivalent), follow QUEUE.md's
   protocol: claim the first ready entry for your machine, execute it,
   archive it, update QUEUE.md, and repeat until nothing is ready for you.
   A file whose name starts with `CRITICAL_` always outranks everything.
2. Work from the prompt file itself, not from memory of how it came to exist.
3. Honor the prompt's hard constraints and run its verification gates.
4. On completion, move the file to `docs/todone/` (use `git mv`) in the same
   commit as the completed work or its evidence commit, and follow the rules
   in `docs/todone/RULES.md` for the required execution record.
5. If execution is abandoned or the prompt is invalidated, either fix the
   prompt in place or delete it with a commit message stating why, and update
   QUEUE.md. Do not leave stale prompts here.

## Authority

If a prompt here conflicts with current code reality, code reality wins:
update the prompt before executing. This file is binding on agents working in
this repository.
