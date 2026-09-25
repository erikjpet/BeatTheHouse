# rw06 final queue

Rules: `rw06_final_push_prompt.md`. Claim by putting your lane in Owner and setting State to IN PROGRESS. Edit only your own rows. Never claim a task whose Needs are not DONE.

| ID | Task | Needs | Owner | State | Notes |
| --- | --- | --- | --- | --- | --- |
| T1 | **Heist ending.** Reach the Crew heist win screen through normal play and save `.tmp\owner_review\ending_heist.png`. Narrow to one plan or fewer recruits if needed; log the cuts. Includes merging the Switch overflow handoff. | — | C | IN PROGRESS | continue from `codex/reset-c-heist` (worktree `reset-c-heist-part3`) |
| T2 | **Balance: clean and cheat.** Replay both finished routes and record the action count and money curve. Tune data (prices, rewards, lender terms, gates) so each takes about 150–350 actions for a normal player; jackpots and fast routes may be quicker. Log changes in `docs/plans/rw06_3_balance_changes.md`. Don't touch heist or Crew files until T1 is DONE. | — | A | IN PROGRESS | |
| T3 | **Full-run bug pass: clean.** Play the clean ending start to finish on current `main` like a new player, in the Windows build or the Web build at `http://localhost:8088/p/beat-the-house/play/latest/v0.6.0/`. Fix anything that breaks the run: crashes, dead ends, unclickable objects, script errors, wrong text. After T2 merges, replay once more. | — | B | IN PROGRESS | |
| T3b | **Full-run bug pass: cheat.** Same as T3, for the cheat ending. | — | D | IN PROGRESS | Claimed on current `main`; running the complete Cheat route through the production-input playtest bridge. |
| T4 | **Balance: heist.** Same as T2, for the heist route. | T1 | | OPEN | |
| T5 | **Full-run bug pass: heist.** Same as T3, for the heist. | T1 | | OPEN | |
| T6 | **Test repair.** Run `tools/check_godot.ps1 -Suite Smoke` and then `-Suite Contract` once each, alone on the machine. Fix every red by fixing the product, or by updating a test that encodes superseded behavior (rooms, tutorial, Cass and similar), noting why. Never weaken a real guarantee. | T2, T3, T3b, T4, T5 | | OPEN | |
| T7 | **Final release.** Update the release copy in `docs/plans/release_0_6_0_copy.md` with the final facts (read the Q-022 answer in the questions file first). Build the final Windows and Web zips from `main` with `tools/export_itch.ps1` (no `-Push`, never upload), then launch each once. Refresh the site's web channels at `D:\Projects\site\projects\beat-the-house\public\play\{latest,dev}\v0.6.0\`. Ask the owner the artifact-handoff question with zip paths and SHA-256 hashes. | T6 | | OPEN | |
