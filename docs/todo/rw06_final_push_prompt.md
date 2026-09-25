# rw06 FINAL PUSH — shared prompt for every lane (2026-09-25)

Self-contained. It replaces every older rw06 prompt's process rules. Every lane
(A, B, C, and any new one) runs this same prompt and pulls work from the queue
in `docs/todo/rw06_final_queue.md` until the queue is empty.

## Goal

Ship Beat the House 0.6.0 as two playtest-ready zips, Web and Windows. All three
endings (clean, cheat, heist) must be winnable through normal play, and balance
must be sensible. The owner uploads the zips personally.

## The rules (binding; older prompts that conflict are void)

1. **Keep working.** When your task finishes or blocks, immediately claim the
   next open task in the queue. Only stop when every task in the queue is DONE,
   or when the only remaining work is an owner question you've already asked.
2. **Nobody needs to clear you.** No "engine-free" holds, no census, no
   clearances, no reruns waiting for approval, no audits, no evidence hashes, no
   independent reviews. Launching Godot is always allowed:
   - use `D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe`;
   - give each run its own worktree and APPDATA folder;
   - at most 4 Godot processes at once machine-wide.
3. **Confirmation means using it once.** Play the game or use the feature
   through the normal game or `tools/agent_playtest_session.ps1`. Save a
   screenshot to `D:\Projects\Beat-The-House\.tmp\owner_review\` when it's
   visual. Test suites are allowed only in task T6.
4. **Blocked? Narrow it and keep going.**
   - Pick the sensible option.
   - Cut scope if needed (for example, one heist plan) and log the cut in
     `docs/plans/0.6.1_backlog.md`.
   - Only a true product decision goes to the owner, as a short question with
     options appended to
     `D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Then keep
     working on anything else.
5. **Git:**
   - work in your own worktree branch `codex/final-<lane>-<task>`;
   - rebase on `main`, merge, and push as soon as something works, at least
     every 2 hours;
   - delete the branch and worktree when the task is done;
   - never force-push, never leave a branch behind.
6. **Unchanged rules:**
   - game rules, RTP, odds and payout tables stay as they are;
   - no hidden information on screen;
   - never run butler, `-Push`, or any upload.
7. **Web-safe code.** The Web engine build strips some classes (see
   `native/coin_pusher/godot_web_release_build_profile.json`); RegEx and
   CanvasLayer are both missing. Never use a stripped class in production
   scripts.

## The queue

Claim and track work in `docs/todo/rw06_final_queue.md`:

1. `git pull` on `main`.
2. Put your lane letter in the Owner column and set State to `IN PROGRESS`.
3. Commit ("claim T#"), push, and retry if the push races someone else.
4. Update your own row's Notes when you merge something.
5. Set State to `DONE` when finished.
6. Only edit your own rows.

Never claim a task whose "Needs" column isn't DONE yet. Take an open task that
is ready.

## When everything is DONE

The last lane to finish:
- confirms that `git branch -a` shows only `main` and
  `codex/wip-0.6-consolidated`;
- asks the owner the final artifact-handoff question (zip paths and SHA-256
  hashes);
- stops.
