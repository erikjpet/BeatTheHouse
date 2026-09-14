Status: DONE — report preserved and repair series merged to `main` on 2026-09-14
Series: Agent playtest sweeps (01 — reusable; rerun any time by resetting Status to READY)

# Agent Prompt — Four-Agent Playtest Bug Sweep

Copy everything below this line into the agent.

---

You are working on **Beat The House**, a Godot 4.6 GDScript roguelite. This
prompt is self-contained: every rule you need is below. Read the named code
before building anything — do not plan from this prompt alone.

## Goal

You are the **main agent**. You will:

1. Prepare a clean copy of the current game and a way for agents to actually
   play it (see, click, read, save/continue).
2. Launch **four playtester sub-agents in parallel**, each playing the real game
   with a different focus.
3. Each playtester returns to you **only** a list of bugs, each explained in
   **exactly two plain sentences**.
4. You merge, de-duplicate, verify, and investigate those bugs, then write
   **one report for the owner** that lists every bug so the owner can confirm
   each one and decide how it gets fixed.

You find, verify, and explain bugs. **You do not fix anything.** No product
code, data, or test changes; no commits; no pushes.

## Hard rules

- **No commits, no pushes, no merges, no stashes, no resets** — anywhere. Leave
  everything you create on disk and list the paths in the report.
- Other agents are working in `D:\Projects\Beat-The-House` right now with
  uncommitted work. **Do not edit, stage, or run the game from that checkout.**
  The only files you may create in the main checkout are the report files named
  in "Deliverables", plus the execution record at the bottom of this file.
- Play the game only through **visible player input** (mouse events pushed into
  the viewport, keyboard events). Never call host action methods, never edit
  `RunState`, never install fixtures or debug shortcuts to reach content. A bug
  that needs a cheat to reach is not a player bug. Reading state snapshots to
  *describe* what is on screen is fine.
- Scratch output, screenshots, logs, and session files go under
  `.tmp/agent_playtest/<YYYY-MM-DD>/` in the worktree (ignored, never committed).

## 1. Source and worktree

- Resolve local `main` HEAD in the main checkout:
  `git -C D:\Projects\Beat-The-House rev-parse main`. Record the hash; this is
  the build under test.
- If `D:\Projects\Beat-The-House-worktrees\agent-playtest` exists, check it is a
  clean detached worktree and move it to that hash
  (`git -C <worktree> checkout --detach <hash>`; if it has local changes other
  than the harness files from a previous run of this prompt, stop and report).
  Otherwise create it:
  `git -C D:\Projects\Beat-The-House worktree add --detach D:\Projects\Beat-The-House-worktrees\agent-playtest <hash>`
- Godot binary: the main checkout's `.tools\godot-4.6-stable\` console exe, or
  `$env:GODOT_BIN`. Do not copy `.tools` into the worktree; point `GODOT_BIN` at
  the main checkout's binary.
- Entry point: `project.godot` → `res://scenes/main.tscn`; host script
  `res://scripts/ui/foundation_main.gd`. Run
  `powershell -File tools\validate_project.ps1` in the worktree once so you know
  the tree is sane before playing; record the result.

## 2. The playable session harness (build once, reuse on later runs)

Agents need a loop of *look → decide → act → look*. The repo has scripted
mouse drivers but no interactive one, so you build a thin one **on top of the
existing tooling** — do not write a parallel input or snapshot system.

Read first:

- `scripts/tests/foundation/harness_production_fidelity.gd` —
  `push_exact_canvas_mouse_click` (real `Viewport.push_input` clicks on an exact
  rendered semantic object id), `observable_host_snapshot` (player-observable
  screen/environment/game/HUD/popup/talk/inventory/message state),
  `resolve_exact_canvas_object`.
- `tools/foundation_visual_qa.gd` — how it clicks visible buttons and game
  surface actions (`_click_game_surface_action`, `_click_canvas_object_data`,
  button lookup helpers) and how it waits for frames.
- `tools/environment_layout_screenshots.gd` — viewport PNG capture (must run
  windowed, not `--headless`).
- `tools/fix06_28_punchline_player_route.gd` — a full production-player route
  (menu → run → rooms → travel → save/continue) using only visible input.

Build `tools/agent_playtest_session.gd` (a `SceneTree` script) plus a
`tools/agent_playtest_session.ps1` launcher:

- Launches `res://scenes/main.tscn` windowed at 1280×720 for one named session.
- **Persistence isolation (required — four games run at once):** set
  `BTH_DISTRIBUTION_DATA_ROOT=user://agent_playtest/<session>` (see
  `scripts/core/persistence_paths.gd`), plus `BTH_USER_SETTINGS_PATH`,
  `BTH_PROFILE_INVENTORY_PATH` and `BTH_META_COLLECTION_PATH` pointed inside the
  same folder. Verify with a quick two-session check that one session's save does
  not appear in the other's Continue. If anything still writes to a shared path,
  note it and serialize that part of play rather than letting sessions collide.
- Polls a session folder for numbered command files and executes each in order,
  writing a numbered result file. Commands (keep it this small):
  - `look` — save a PNG of the viewport, and write JSON: current screen, visible
    message/popup/talk text, HUD values, and a **list of everything clickable
    right now**: visible enabled buttons (text + id) and rendered canvas objects
    (semantic id, label, enabled) and game-surface actions.
  - `click_button <text or id>`, `click_object <semantic id> [double]`,
    `click_action <game action> [index]`, `click_xy <x> <y> [double]`,
    `key <keyname>`, `wait <frames>`.
  - `quit` — clean shutdown.
  - Every action result includes: accepted or refused (with the reason, e.g. id
    not found / disabled), and an automatic `look` afterwards.
- Captures Godot stdout/stderr per session to a log, and surfaces any new
  `SCRIPT ERROR`, `ERROR`, or `WARNING` lines in each result file. Script errors
  are bugs.
- A player can start a run with a typed seed from Run Setup — the harness must
  allow typing text into a focused field (`type <text>`).

Prove the harness before launching agents: start a session, look at the menu,
start a seeded run, enter a room, click an object, open a game, play one round,
save, quit, relaunch, Continue. Open the PNGs yourself. If the harness itself
misbehaves, fix the *harness* (never the game) until this smoke passes. Past
sweeps in this repo filed harness mistakes as game bugs (see
`docs/todone/playtest06_current_source_bug_investigation_2026-09-07.md`: a
selector picked `Room Door` instead of `Leave`) — a harness that clicks the wrong
thing is worse than none.

If an interactive driver already exists from a previous run of this prompt,
reuse it and only fix what is broken.

## 3. The four playtesters

Launch all four in parallel as sub-agents, each with its own harness session
name, seed(s), and focus. Give each the **Playtester brief** below verbatim, with
its focus block filled in. Seeds must differ so the agents cover different runs;
use the named seeds below, and let agents start a second seed of their own if the
first run ends.

| Agent | Session | Seeds | Focus |
|---|---|---|---|
| A — New player | `pt_a` | `AGENTPT-A-01` (then own) | Brand-new profile. Main menu, settings, tutorial/first-time guidance, Run Setup, first night: first rooms, reading objectives, first games, first travel, first save/Continue. Can a newcomer understand what to do? Anything confusing, stuck, unreadable, clipped, or unresponsive. |
| B — Games | `pt_b` | `AGENTPT-B-01` + start-menu Games library | Every game, both from the Games library and inside a run: slots, blackjack, baccarat, roulette, video poker, craps and street craps, bar dice, pull tabs, scratch tickets, coin pusher (all three machines), Back-Room Texas Hold'em, showdown duel. Rules correct, payouts match what the screen says, bets and balances add up, buttons work, exit/replay works, no stuck states or frozen idle animation. |
| C — World & story | `pt_c` | `PLAYTEST06-1-FASTPATH-009`, then `AGENTPT-C-01` | Travel and the world map, rooms and their objects/panels, events and choices, characters and talk, shops/pawn/gas station/clerks, lenders and debt, Crew recruitment/favors/jobs, the Punchline L1→L2→L3 route, revisiting places. Actions that do nothing visible, wrong text, broken branches, dead ends. |
| D — Long run & edges | `pt_d` | `AGENTPT-D-01`, `AGENTPT-D-02` | Play long: economy over many nights, heat/suspicion, going broke, winning, losing, end-of-run report. Then break things: save/quit/Continue mid-game and mid-event, rapid and double clicks, clicking during animations, opening inventory/menus mid-action, backing out of every screen, reduce-motion setting. |

### Playtester brief (give this to each sub-agent)

> You are playtesting **Beat The House**, a casino roguelite, like a real player
> would. Your focus: **<focus block>**. Your session: **<session>**. Your seeds:
> **<seeds>**.
>
> You control the game only through the session harness in
> `D:\Projects\Beat-The-House-worktrees\agent-playtest` (usage:
> **<paste the harness command reference and session folder path>**). Always
> `look` before deciding, and open the PNG — judge what a player would *see*, not
> just the JSON. Do not edit any file in the repo, do not fix anything, do not
> commit.
>
> Play for real: make choices a player would make, follow the objectives, try the
> obvious things and a few unexpected ones. Keep going when you find a bug —
> work around it and keep playing. Aim for broad coverage of your focus, at
> least ~150 actions, and stop when your focus is covered or the game is
> unplayable.
>
> A **bug** is: a crash or script error; a soft-lock or dead end; something
> clickable that does nothing; wrong numbers (money, payouts, odds text, counts);
> rules that don't match what the game says; text that is wrong, missing,
> overlapping, or cut off; art/animation that is broken, frozen, or drawn in the
> wrong place; save/Continue losing or changing state; the game behaving
> differently from what it told you. **Not** bugs (do not report): balance
> opinions, writing-style opinions, missing music, and placeholder/shared object
> glyphs — those are already known.
>
> Before you report a bug, try once more to reproduce it. If it only happened
> once, still report it and say so.
>
> Keep a private notes file at `.tmp/agent_playtest/<date>/<session>/notes.md`
> with, per bug: the seed, the exact command numbers leading to it, and the PNG
> and result-file paths.
>
> **Your final reply is only this list, nothing else:**
>
> ```
> <session>-01 | <two sentences> | evidence: <result file or PNG path>
> <session>-02 | <two sentences> | evidence: <path>
> ```
>
> The two sentences are plain language: **sentence 1 = what happened and where;
> sentence 2 = what should have happened (or why it's wrong).** Exactly two
> sentences — no severity, no fix ideas, no code. If you found no bugs, reply
> `<session> | no bugs found | actions played: <n>`.

## 4. Merge, verify, investigate (main agent)

When all four replies are in:

1. **Collect** every line into a raw ledger (keep the original two sentences
   verbatim, with the agent id).
2. **De-duplicate.** Same underlying problem seen by several agents → one bug,
   listing every agent id that saw it.
3. **Verify each bug yourself.** Open the evidence, read the agent's notes for the
   command sequence, and re-run the repro in a fresh harness session (from the
   same seed). Classify:
   - `CONFIRMED` — reproduced by you;
   - `INTERMITTENT` — seen in evidence but not reproduced in two tries;
   - `HARNESS` — the harness, not the game, caused it (wrong target, timing,
     isolation leak). List these separately and fix the harness if cheap, but
     never count them as game bugs;
   - `NOT A BUG` — working as designed, or an already-known limitation (read
     `docs/plans/0.6_playtest_handoff.md` "Known limitations"). Say why.
4. **Investigate each confirmed/intermittent bug** — read the code, do not
   change it. Find the likely cause (file + function, with a line reference) and
   say how sure you are. Check `docs/todo/` and `docs/plans/` for an existing
   prompt that already owns it and link it if so.
5. **Propose fixes.** For each bug give 1–3 fix options, each one sentence with
   its trade-off, and mark one **Recommended**. Estimate size (S/M/L) and risk.
   If a fix would change design (not just correct a defect), say so plainly —
   that is the owner's call, not yours.
6. **Severity:** `Blocker` (crash, soft-lock, save loss, run can't continue),
   `Major` (feature broken or money/rules wrong), `Minor` (works but wrong or
   ugly), `Polish`.

## 5. Deliverables

Write the report in the **main checkout** (the only product-tree files you create
there):

`D:\Projects\Beat-The-House\docs\plans\agent_playtest\agent_playtest_report_<YYYY-MM-DD>.md`

Structure, in this order:

1. **Header** — date, commit tested, worktree path, harness paths, seeds per
   agent, actions played per agent, validation result.
2. **Summary** — counts by severity and status; the 3–5 bugs the owner should
   look at first, one line each.
3. **Decision table** — one row per bug, sorted Blocker → Polish:
   `| ID | Severity | Status | Where | Bug (two sentences) | Recommended fix | Owner: confirm? | Owner: fix choice |`
   with the last two columns left blank (`☐ Yes ☐ No ☐ Not a bug` and
   `☐ A ☐ B ☐ C ☐ Defer`) for the owner to fill in.
4. **Bug details** — one section per bug, `BUG-NN: <short title>`:
   - Reported by (agent ids) and their original two sentences, verbatim.
   - Status + how you verified (seed, steps, evidence paths, embedded or linked
     PNG).
   - Likely cause (file:line, confidence).
   - Fix options A/B/C with trade-offs, size, risk; Recommended marked; design
     changes flagged.
   - Existing prompt/plan that already covers it, if any.
5. **Not bugs / known issues** — reported items you rejected, with one-line
   reasons.
6. **Harness issues** — problems with the playtest harness itself, and whether
   you fixed them.
7. **Coverage** — what each agent actually reached and what nobody reached, so
   the owner knows the blind spots of this sweep.

Keep bug text plain and short: the owner reads this to make decisions, not to
debug. Put long logs in `.tmp` and link them.

## 6. Completion

1. Confirm `git -C D:\Projects\Beat-The-House status` shows no changes from you
   other than the report file(s) and this prompt file; confirm the worktree has
   no changes other than the two harness files.
2. Quit every harness session and make sure no Godot processes you started are
   still running.
3. Append an execution record to the bottom of **this file**
   (`D:\Projects\Beat-The-House\docs\todo\playtest_agents01_four_agent_bug_sweep_prompt.md`):
   date, commit tested, report path, bug counts by severity/status, harness
   changes, and anything that blocked coverage. Change `Status: READY` to
   `Status: DONE — report awaiting owner review`. Do not move the file.

If the harness cannot be made trustworthy (step 2 smoke fails for reasons you
cannot fix without touching game code), do not launch the playtesters: set
`Status: BLOCKED`, paste the failing output into the execution record, and
explain what game-side change would unblock it.

## Execution record — 2026-09-12

- **Commit tested:** `56de66598a2bcdbc3f171f090b48c361daf35563`
- **Report:** `docs/plans/agent_playtest/agent_playtest_report_2026-09-12.md`
- **Result:** 23 game bugs — 2 Blocker, 10 Major, 11 Minor, 0 Polish; 22 confirmed, 1 intermittent, 0 harness-classified findings; 1 reported item classified Not a Bug.
- **Coverage:** 1,000 visible-input actions across 12 isolated sessions. Organic multi-night victory and natural bankruptcy/debt terminal paths were not completed; terminal-report coverage used Abandon, and controller/touch input was not tested.
- **Harness changes:** created `tools/agent_playtest_session.gd` and `tools/agent_playtest_session.ps1` only in the detached playtest worktree. Fixed PowerShell UTF-8 compatibility, command numbering/relaunch continuity, freed-button inspection, and game-action parsing; the full save/quit/relaunch/Continue smoke and a two-session persistence-isolation check passed.
- **Execution constraints:** host/agent concurrency allowed three playtester sessions alongside the coordinator, so the fourth began immediately when a slot freed rather than at the exact same instant. No game-side issue blocked the sweep.

## Continuation record — 2026-09-12

- **Direction:** after each playtester found an issue and exited, a fresh isolated replacement was launched to look for another distinct issue; replacement cycling stopped only when every continued lane returned `NO NEW BUGS`.
- **Commit tested:** `56de66598a2bcdbc3f171f090b48c361daf35563`
- **Report:** `docs/plans/agent_playtest/agent_playtest_report_2026-09-12.md`
- **Result:** 31 game bugs total — 2 Blocker, 12 Major, 17 Minor, 0 Polish; 30 confirmed, 1 intermittent, 0 harness-classified game findings; 5 reported items classified Not a Bug.
- **Added findings:** BUG-24 Baccarat LEAVE/explainer overlap; BUG-25 Dave consequence clipping; BUG-26 duplicated scenario prompt; BUG-27 Blackjack loss labeled PUSH; BUG-28 Bar Dice guidance clipping; BUG-29 Roulette REBET disabled; BUG-30 truncated Unknown Caller name; BUG-31 undisclosed Vic loan terms.
- **Coverage:** 1,521 visible-input actions across 28 isolated sessions. Final replacements `pt_b8`, `pt_c8`, and `pt_d8` completed fresh targeted passes with no new distinct bugs; original blind spots around organic multi-night victory, natural bankruptcy/debt termination, and controller/touch input remain.
- **Harness changes:** added isolated persistence-directory creation, viewport/ancestor-clipped hit geometry, and a nonempty/parseable-result wait for concurrent large captures. A live Settings persistence write and a large-result parse completed without alerts.
- **Validation:** the original full validation remained PASS; after continuation, live harness compilation/use, PowerShell parsing, environment grounding, and foundation shards passed. Two extra full-wrapper reruns emitted no failure but exceeded two- and five-minute command limits, so they are not claimed as additional full passes.
- **Execution constraints:** one shallow `pt_d5` startup pass was interrupted by the result-file race and retried; no game-side issue blocked the continuation.

## Additional no-finding pass — 2026-09-12

- **Result:** no BUG-32 was established; the total remains 31 game bugs.
- **Coverage:** 75 additional completed visible-input actions in `pt_b9`, `pt_c9`, and `pt_d9`, bringing the cumulative total to 1,596 across 31 isolated sessions. New paths included Scratch Ticket filing/claim setup, merchant selling and keyboard reachability, Debt Spiral through day two, repeated sleep, Payment Calendar, Renew Stay double-click, and relaunch/Continue.
- **Excluded recurrence:** `pt_b9` encountered known BUG-04 in Craps and moved to another game. Renew Stay double-click processed once and charged exactly $45, so it was not a bug.
- **Environment constraint:** with unrelated Godot workers active, free physical memory fell below 250 MB. Two session processes exited with empty stderr and one wrapper capture raised `System.OutOfMemoryException`; successful relaunches showed no action-specific game failure. Concurrency was reduced and further launches stopped when memory stayed unsafe.

## Post-fix 0.6 claim audit — 2026-09-13

- **Code tested:** fixed worktree `C:\Users\theep\.codex\worktrees\Beat-The-House-playtest-fixes`, HEAD `56de66598a2bcdbc3f171f090b48c361daf35563`, uncommitted diff fingerprint `45add38e02d9de93e2ecae3f2092f32714ab5431` (unchanged from start to finish).
- **Report:** `docs/plans/agent_playtest/agent_playtest_postfix_06_claim_audit_2026-09-13.md`.
- **Original fixes:** 21 PASS, 9 FAIL, 1 UNVERIFIED (BUG-26 route could not be reproduced through the original visible-input sequence).
- **New findings:** 6 confirmed — BUG-32 Blackjack post-HIT count pulse collision; BUG-33 Run Content home overwritten; BUG-34 Gas Station Numbers Book label clipping; BUG-35 Pinball zero-ball settlement; BUG-36 Casino Craps refund crosses wallets; BUG-37 both enabled Tier-2 destinations rejected by scenario-layout conflicts.
- **Coverage:** 1,714 visible-input commands across 28 isolated/relaunched sessions, including original-fix replay, commit-derived Hold'em/Blackjack/Coin Pusher/Slots/Craps/world-route claims, a full authored-scenario Save/quit/Continue/aftermath cycle, and a Switch recruitment route.
- **Blind spots:** BUG-26; Vince trade; Hold'em side pots/real-run persistence; Street Craps; old-save compatibility; full Motel tenure/home loss; job lifecycle; heists/the Turn; souvenir sale/cross-run behavior; controller/touch.
- **Harness/process note:** one already-finished `verify31_d3` quit wrapper remained alive and grew to roughly 42 GB working set; after exact command-line verification and confirmation that its game process was gone, only that stale wrapper was terminated. No product crash was counted, all final game sessions exited, and no product code/test/data was edited by the playtest sweep.
