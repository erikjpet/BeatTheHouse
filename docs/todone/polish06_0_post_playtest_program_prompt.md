Status: DONE (deliverables remain PARKED; performs no polish work)
Board row: `polish06_0` in `docs/todo/README_0_6_board.md`

Execution Record (2026-08-26): implementation head `be14c1ce471d4bb4cb8b633a2fc76a34c397de47`
was independently accepted with no P0-P3 and merged non-fast-forward as
`dba53fb5`. The parked program, triage/tuning/cleanup prompts and release
templates were delivered; no generated row was started and no release activity
occurred.

# Agent Prompt — 0.6 polish06_0: The Second Half of 0.6

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This row designs the
post-playtest half of 0.6 and then stops. It writes prompts and a program
document. It performs none of the work it defines, and it performs no release
activity of any kind.

Read the board's terminus section in `docs/todo/README_0_6_board.md`,
`docs/todo/voice06_1_voice_pass_prompt.md`,
`docs/todo/release06_1_ship_prompt.md`,
`docs/plans/0.6_remaining_work_program.md`, and the 0.5 release artefacts —
`0.5_release_checklist.md`, `0.5_publish_copy.md`, `0.5.0_devlog_post.md`,
`0.5_trailer_production.md`, `0.5_talking_points.md`,
`0.5_pre_release_audit.md`, `0.5_final_rc_evidence.md` — which are the shape the
0.6 equivalents should take.

## Why this row exists

The owner declared that the polish and cleanup pass following the playtest is the
second half of 0.6. That half currently consists of two parked prompts:
`voice06_1` and `release06_1`. Everything else about it — how findings become
work, who tunes balance, what gets cleaned up, what gets written, what the
release checklist is — exists only as an expectation.

The value of doing this now is that it gets designed while the project is
understood and calm, rather than in the tired stretch after a long playtest when
the temptation is to skip straight to shipping.

## Board and dependencies

Follow the active board protocol. Claim `polish06_0`. It can start immediately.
Its deliverables land PARKED and no agent may claim them until the owner declares
the polish pass open.

**Absolute constraint:** this row performs no version bump, no tag, no packaging,
no publish, no balance tuning, no voice rewriting and no cleanup. It writes the
plan for those. `release06_1` remains the only row permitted to perform release
activity.

## 1. The triage protocol

- Define how an owner playtest finding becomes work, consuming the capture format
  `playtest06_2` delivers.
- Defects become `fix06_*` rows with a defined template: reproduction, expected
  behavior, severity, owning system, and the gate that should have caught it.
  That last field matters — a defect that escaped a gate is also a gate defect.
- Design objections become owner decisions recorded in the roadmap. Write the
  rule that an agent never redirects locked design on its own reading of a
  playtest note, and make the protocol enforce it rather than merely state it.
- Define severity and what makes a finding blocking versus deferred to 0.7, and
  who decides. Where the answer is "the owner", say so plainly rather than
  inventing an agent-side rule.

## 2. The balance tuning pass

- Write the prompt that consumes `balance06_1`'s ranked proposals and the
  playtest's felt experience and actually applies tuning — the row `balance06_1`
  was explicitly forbidden from being.
- It must re-run `balance06_1`'s committed harness after tuning and show the
  before-and-after distributions, not just assert improvement.
- It must not touch presentation, content or rules; only tuning values, and only
  those the report and the playtest jointly support.

## 3. Cleanup and dead code

- Write the prompt for the cleanup pass: dead code from superseded systems, the
  reworks' leftovers, unreferenced assets, stale fixtures, orphaned documentation
  and the accumulated review artefacts that are safe to retire.
- The rule from this project's history applies: `.tmp` and `.tools` artefacts and
  the owner's untracked directories are kept deliberately. The prompt must
  distinguish agent leftovers from owner property and must never remove the
  latter.
- Include a documentation pass: the roadmap, the board and its companion logs,
  and the plans directory reconciled with what actually shipped.

## 4. The release artefacts

Write the prompts or templates for each, following the 0.5 precedents:

- the 0.6 release checklist, with the owner gates enumerated;
- publish copy;
- the devlog post covering the living town, the crew path, the new games and the
  depth programs;
- trailer production notes;
- talking points;
- a pre-release audit and an RC evidence record.

Each should say what it needs from the finished build, so none of them becomes a
blocker discovered on release day.

## 5. Version policy

- State the version 0.6 ships as and the rule for deciding it, given that the
  repository has historically lagged its shipped version and that 0.4.0 was
  built as an RC and never published.
- Define what a hotfix line looks like if the playtest finds something after a
  ship, so that decision is not made under pressure.

## 6. Sequencing

- Produce the ordered program: triage, fixes, balance tuning, cleanup, then
  `voice06_1` reading final strings, then `release06_1` last.
- State what unparks each row and what must be true before it starts.
- Identify what can run in parallel and what genuinely cannot, so the second half
  does not serialize by accident.

## 7. Deliverable

A program document under `docs/plans/` describing the whole second half with its
sequencing and unpark conditions, plus the prompt files it defines, all marked
PARKED, plus board rows for each in the format the board already uses.

Do not claim, start or schedule any of them. Do not modify `voice06_1` or
`release06_1` beyond noting their place in the sequence and any dependency this
document adds.

Run project validation to confirm nothing outside documentation changed. Archive
with the document path and the parked row list recorded on the board.
