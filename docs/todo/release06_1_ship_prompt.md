Status: PARKED — do not claim until playtest, triage, tuning, voice, and cleanup are complete
Board row: `release06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 release06_1: Balance, Verification, Release

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). This is the 0.6
closure task, modeled on the 0.5 release discipline
(`docs/plans/0.5_release_checklist.md`,
`docs/todone/README_0_5_release_queue_final.md` in historical records).
Binding design contract: `docs/plans/0.6_living_world_roadmap.md`.
This prompt is self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `release06_1` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. **Precondition: ALL other rows DONE and the
   owner-triggered playtest round's `fix06_*` prompts (if any) DONE**
   — verify on the board; if the playtest round hasn't happened, set
   `BLOCKED` with "awaiting owner playtest round" and stop.
2. Log discoveries/deviations tagged `[release06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; final Work Log entry
   closing the board.

## Task

### 1. Balance pass

- Consume content06_1's economy audit map: tune the flagged
  imbalances across Numbers EV, pusher bands, crew cuts, stake-horse
  targets, heist payout bands, sweep costs — data-only changes,
  documented per tuning in the commit messages. Re-run every EV/RTP
  harness after tuning.

### 2. Full-system verification on exact source

- One clean commit; the complete matrix on that exact source:
  `tools/validate_project.ps1`, every `-FoundationSuite`,
  `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`,
  `tools/foundation_visual_qa.ps1`, the performance/soak suite at 0.5
  budgets (idle-liveness floors unchanged — a 0.000 idle number
  without its liveness counter is an automatic FAIL per the recurring
  regression pattern), Web + Windows export smoke, save-migration
  matrix (0.5-release saves + mid-0.6 dev saves load correctly), and
  long-run stability (the 0.5 soak precedent).
- Cross-system integration proofs the matrix might miss — drive each
  end-to-end at least once headless: full crew path to both heist
  plans + all four ladder outcomes; the Turn's both guarantees; solo
  run untouched-by-crew regression; Numbers fix + past-post + leak;
  sweep full lifecycle; a run using only 0.5 features (the "nothing
  changed if you ignore 0.6" guarantee).

### 3. Release records + versioning

- Version to 0.6.0 across `project.godot`/README/CHANGELOG; write
  `docs/plans/0.6_release_checklist.md` and the devlog/publish copy
  drafts (owner approves copy before any publish); reconcile the
  roadmap doc's status line to "shipped as 0.6.0" with the release
  commit hash.
- **Owner gates (hard stops — request explicitly, never assume):**
  final source approval, packaged-artifact approval, and
  publish/upload authorization. Package only after source approval;
  publish only after explicit authorization; tag `v0.6.0` at the
  exact published source.

## Hard rules

- Never weaken a test, budget, liveness floor, deterministic
  assertion, or gate to go green.
- Any post-approval code change invalidates the candidate: rerun
  affected gates and rebuild artifacts.
- Historical reports prove only the hash they tested — the matrix
  runs on the exact candidate source.
- Data-only balance changes in this task; code fixes discovered here
  become scoped `fix06_*` prompts on the board (add rows), not
  drive-by edits.
- Suite timeout = max(300s, baseline×1.5).

## QA / Evidence

- The full matrix summary (`.tmp/` reports), integration-proof list
  with seeds, migration matrix results, and packaged-artifact
  playtests — all referenced from the Execution Record and the
  release checklist.

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: the candidate hash, matrix summary, tuning changelog, and the
owner-gate status (what is awaiting owner action). On an unfixable
gate failure: stop at last green commit, set `BLOCKED`, report
verbatim.
