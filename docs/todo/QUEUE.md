# Queue Order â€” maintained by the project manager

Agents told to "work on the todo list" (or similar) follow this protocol:

1. Read this file. Take the **first entry whose Status is `ready`** and whose
   Machine constraint matches where you are running.
2. Claim it: change its Status to `claimed (<date>, <machine/session>)`,
   commit and push this file **before** starting work, and pull first â€” if
   someone else claimed it in the meantime, take the next entry.
3. Execute the prompt per `RULES.md`, archive it to `docs/todone/` with an
   execution record, update this file (remove the entry), commit, push.
4. **Repeat from step 1** until no entry is `ready` for your machine, then
   report which entries remain and why they are blocked.

Never execute an entry marked `in-progress-elsewhere` or `blocked` â€” and
NEVER re-implement work a status note says already exists somewhere.

Last reviewed: 2026-07-07 by Codex for the v0.4 Act 1 completion plan.
`docs/plans/0.4_act1_completion_plan.md` is the current release path. The first
task must reconcile the existing dirty worktree and stale prompt/archive moves
before new feature work proceeds.

| # | Prompt | Status | Machine | Notes |
| --- | --- | --- | --- | --- |
| 11 | v04_post_release_verification_prompt.md | ready; owner-launch only | PM machine | Unblocked by archived `v04_publish_and_tag_prompt.md`; start only when the owner pastes the kickoff prompt. Verifies the LIVE builds players receive (itch web + published Windows zip), generates devlog #4 card/copy assets, marks the plan SHIPPED. Devlog posting stays with the owner. |

Only the project manager adds entries or reorders this table; executing
agents only flip Status fields for claims and remove completed entries.
"Owner-launch only" entries are never taken by agents running the generic
todo-list loop, even when their blockers clear; they start only when the
owner pastes their kickoff prompt.
