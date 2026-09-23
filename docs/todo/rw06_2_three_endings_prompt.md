# rw06_2 — Three endings, start to finish, through the real UI

Status: TODO. Self-contained. Launch with this file only.
Depends on rw06_0 being DONE. Runs in parallel with rw06_1, with a final pass
after rw06_1 lands.

## Goal

Prove, and make true, that a player can start a new run and reach the **win
state** of each of the three endings using normal play. Along the way, make the
run feel like a coherent experience: the player always knows the next goal, and
no stretch of play is dead.

| Ending | Win state |
| --- | --- |
| Clean | Linda's Players Card ladder completed, then the clean Grand Casino ending screen |
| Cheat | Rourke's walk, pat-down and interrogation survived, five-hand duel won, then the cheat ending screen |
| Crew/heist | Crew trust built, a heist plan executed at the Grand Casino, then the heist win state |

Read `docs/plans/grand_casino_endgame_design.md` and the Crew/heist sections of
`docs/plans/0.6_living_world_roadmap.md` for the intended routes.

## Owner decisions (binding)

- All three endings must reach their win state for 0.6.
- An ending may be **narrowed** rather than fully expanded. For example, one
  heist plan fully working is enough if the other is broken. When you narrow an
  ending:
  - the remaining path must be complete and satisfying;
  - the cut part must be gated off cleanly, never left half-reachable;
  - the cut must be logged in `docs/plans/0.6.1_backlog.md` under "Endings".
- Fix only what breaks the arc. Everything else goes to the backlog.
- Run length: a normal route takes about 150–350 actions (30–60 minutes).
  Jackpots or legitimate fast routes may finish much sooner; that is intended.

## Owner questions (binding for every agent)

All owner decisions, including the hard gates, go through
`D:\Projects\Beat-The-House\docs\todo\rw06_owner_questions.md`. Always use that absolute path (the primary checkout copy). Follow
its protocol:

- append a short, precise question with options and a recommendation;
- mark your work `WAITING Q-NNN`;
- keep working on anything that doesn't depend on the answer.

Read the file at the start of every session. Pick up any ANSWERED entry whose
`Resume` is yours, even if another agent asked it. Never talk to the owner any
other way, and never stall waiting.

## Method

1. **Drive the real game.** Use `tools/agent_playtest_session.ps1` and
   `tools/agent_playtest_session.gd` (production input; each command returns a
   screenshot plus player-observable JSON).
   - Qualifying runs use no debug shortcuts, no state injection and no hidden
     information.
   - For fast iteration you may use a clearly labeled developer checkpoint to
     reach late stages, but it never counts as qualifying.
2. **Write a route per ending:** `docs/plans/rw06_2_routes/<ending>.md`. Record
   the seed, then the sequence of player decisions at the level of intent
   ("play blackjack until $X", "accept Crew delivery job"), not coordinates.
   Include one save → quit → Continue in the middle of each route.
3. **Keep an experience log per run.** For each act of the run, record:
   - the actions taken and the money curve;
   - what the player believes the next goal is, and where the game tells them;
   - notable moments;
   - **arc breakers**:
     - softlock or dead end;
     - the next step can't be found from what's on screen;
     - an action with no visible feedback;
     - wrong or misleading text;
     - more than about 25 actions with no new goal or event;
     - an economy that makes the ending practically unreachable without
       exploits;
     - a crash or script error.
4. **Fix the arc breakers with root-cause fixes.** Game rules, math and RTP
   don't change here. Economy tuning belongs to rw06_3; record the numbers it
   needs.
5. **Make each route replayable without an agent in the loop.** Once a route
   works, encode it as a command script that
   `tools/rw06_2_ending_replay.ps1 -Ending clean|cheat|heist` feeds through the
   same production-input bridge (`agent_playtest_session`). The script asserts
   the win state and exits nonzero on any deviation. Reruns, the post-rw06_1
   pass, rw06_3 and the rw06_4 release gate all use this script, not
   hand-play.
   - Read the JSON observations. Open screenshots only when needed; a
     300-action run is too large to review image by image.
6. **Rerun until each ending passes:** on its route seed twice (the runs must
   be deterministically identical, which the replay script proves) and on one
   fresh seed played interactively.

## File ownership

- rw06_1 owns room placement, including `scenario_layout_resolver.gd`,
  `environment_instance.gd`, `pixel_scene_canvas.gd` and the placement JSONs.
  Don't touch them.
- If an arc breaker is a placement problem, report it to the scoreboard for
  rw06_1.
- You may edit game, event, Crew, ending, tutorial text and UI flow code.
- Rebase on `main` often.

## Rules

- Never weaken a test, budget, liveness floor or deterministic assertion.
- Everything is seeded and happens at action boundaries. Every consequence fires
  exactly once across save, reload, travel and revisit.
- No hidden-state leaks.
- A run that ignores the Crew stays a true no-op for Crew systems (the golden
  probe).
- Add a focused regression test for each fix.

## Acceptance

- 3/3 endings reach the win state through the real UI. This is re-verified on
  `main` **after rw06_1 has landed**.
- Each ending passes twice on its route seed and once on a fresh seed.
- Smoke and Contract are no worse than when you started.
- Routes and experience logs are committed under `docs/plans/rw06_2_routes/`.
- `tools/rw06_2_ending_replay.ps1` passes all three endings on `main`, and it
  is the release gate's ending check in rw06_4.

## Finish

- Commit in a worktree branch, verify, fast-forward `main`, and push. Never force-push. Then delete the branch (local and origin) and remove the
  worktree. The row is not DONE while its branch exists.
- After every full pass, report the ending status and open P1/P2 counts to the
  orchestrator, who updates the scoreboard, so progress is visible daily.
- Hand rw06_3 a short list of economy friction with the numbers attached, in
  `docs/plans/rw06_2_routes/economy_notes.md`.
