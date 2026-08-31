Status: DONE
Board row: `board06_1` in `docs/todo/README_0_6_board.md`

## Execution Record

- **Completed:** 2026-08-26
- **Source and landing:** Immutable source `114271b0ad952e72b6545d49e63aff0e67edd78a`; independently accepted head `bf4fbc4673b1237e60942e104b8205944ef84032`; integration merge `3c8139ce833f22f3870f8948e92974c22f0bad90`; main merge `70eaaf80eff2f7a65cec7046b3900ee861cb2b4f`.
- **Landing method:** The entangled, behind source branch was not merged or cherry-picked. Its semantic net payload was reconciled into exactly three documentation files: the active board and its dated Discovery & Decision and Work Log companions. Newer main row truth was preserved.
- **Independent review:** REJECT at `e13ebe08dcceb05fca7c0d352f34a1cbb2ac3b2d` for one P2 duplicate 13-line Logs/history block; `bf4fbc46` removed only that duplicate and received final ACCEPT. Integration `3c8139ce` received ACCEPT_FOR_MAIN.
- **Verification:** Exact-head validation passed in 54.071s; integration validation passed in 51.142s; post-land validation passed in 53.472s. The first post-land Smoke correctly remained red while the ignored native addon was absent and the solver used `gdscript_v3`. After the exact four-file native addon was supplied and imported, corrected Smoke passed every stage on `native_v3`: validation 50.005s, import 20.108s, load 25.346s, foundation 38.820s, UI 57.362s, Dave 7.164s, roulette audio 5.043s and performance 39.095s.
- **Preservation:** 170/170 Discovery & Decision entries and 124/124 historical Work entries were preserved. `scripts/core/streets_run_model.gd.uid` was not deleted: it is ignored owner state present only in the primary worktree. `review_artifacts/` and every other owner-authored or untracked path were untouched. Evidence-preserving cleanup remains pending.
- **Deviations:** The prompt requested deletion of the ignored orphan UID, but landing intentionally preserved the owner's ignored primary-worktree file under the landing program's stronger owner-artifact custody rule. No product or data file landed.

# Agent Prompt — 0.6 board06_1: Board and Repository Hygiene

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a documentation and
repository hygiene row. It touches no game code and changes no behavior. Read
`docs/todo/README_0_6_board.md` in full before editing anything.

## Why this row exists

The 0.6 board has been the single source of execution truth across six owner
design rounds, three programs and thirty-odd rows. It is now roughly 170 KB, it
carries superseded rows beside live ones, and it lists an owner question that
shipped data already answers. Every agent that lands on this board reads all of
it. Cost of confusion compounds with each new program.

## Board and dependencies

Follow the active board protocol. Claim `board06_1`. **Coordinate before
merging:** the Family 1, Family 2 and depth program integrators all edit this
board. Confirm a quiet window with them before making structural changes, and
make the change in one commit so no one loses a claim.

## 1. Close the stale owner question

The Owner Questions section still lists Chip Dump funding authority as
unresolved: "choose one binding model: (A) player-funded temporary escrow, (B) a
finite seeded per-run/member crew float, or (C) both".

`data/crew/plays.json` ships the answer. The `chip_dump` play has
`transfer_amount` 40, `transfer_fee` 6 and direction `cash_to_chips`, funded by
the player, with the stated intent that detection preserves laundering risk and
never creates value. That is model A, implemented and gated.

Move the question to ANSWERED with the citation, note that it was answered by
implementation rather than by a separate ruling, and record it in the Discovery
& Decision Log with today's date. Do not change the play data.

Then re-read every other entry in Owner Questions and apply the same test: is
this still open, or has shipped code answered it? Report each verdict; only
close the ones where the code is unambiguous.

## 2. Retire superseded rows

- The `pusher06_0`, `pusher06_1`, `pusher06_3` and `pusher06_4` rows are
  superseded by the V3 machine rework and marked "Do not claim". Move them into
  an explicit archived section so the live table contains only claimable work.
- `art06_1` is CLOSED — FALSE PREMISE. Keep its finding, which is genuinely
  useful (every environment is procedurally drawn; `visual_context.asset_path`
  is metadata the canvas never consumes), but move it out of the live table.
- Do not delete any row, any note or any log entry. Everything moves, nothing
  disappears. The record of why something was superseded is the point.

## 3. Split the board

- The active task tables, the board protocol and the Owner Questions stay in
  `README_0_6_board.md`.
- Move the Discovery & Decision Log to a dated companion file, and the Work Log
  to another, both linked prominently from the board with an explanation of what
  lives where.
- Preserve every entry verbatim with its date and row attribution. Add a short
  index at the top of each companion so a reader can find a row's history
  without reading the whole file.
- Update the board protocol section so future agents know where to append. The
  protocol must stay binding and must still be read in full by every agent —
  splitting the file must not become an excuse to skip it.

## 4. Reconcile the new program sections

The three new program sections — Family 1 (`game06_*`), Family 2 (`world06_*`)
and Family 3 — were added to the board when the program was authored. Reconcile
rather than recreate them:

- Verify every row's id, prompt filename, dependencies and unblocks against
  `docs/plans/0.6_remaining_work_program.md` and against the prompt files that
  actually exist in `docs/todo/`. A row pointing at a missing prompt, or a
  prompt with no row, is a finding to fix.
- Verify the table format matches the rest of the board exactly: ID, Prompt,
  Status, Depends on, Unblocks, Agent, Started, Finished, Notes.
- Carry the sections into the split structure from section 3 without losing any
  claim an integrator has made in the meantime.

Do not invent statuses, do not claim any row, and do not alter any existing
row's state.

## 5. Repository leftovers

- `scripts/core/streets_run_model.gd.uid` is an ignored leftover whose `.gd` was
  deleted by `rework06_1`. Remove it.
- Scan for other orphaned `.uid` files whose source no longer exists and remove
  only those that are genuinely orphaned and genuinely ignored. Verify with git
  before removing anything; if a `.uid` is tracked, leave it and report it.
- Do not touch `review_artifacts/`, `.tmp`, `.tools` or any untracked user file.
  Those are the owner's and are kept deliberately.

## 6. Acceptance

- The board renders correctly, every link resolves, and no row, note or log entry
  was lost. Prove it with a before-and-after entry count.
- The three new program sections match the program document exactly.
- Every Owner Question has a current verdict with a citation.
- `git status` shows only intended documentation changes and the orphaned `.uid`
  removals. No product code, no data, no user files.
- Run project validation to confirm nothing in the repo depended on a removed
  `.uid`.

Archive with the before-and-after entry counts and the coordination confirmation
from the other integrators recorded on the board.
