Status: PARKED — do not claim until owner playtest findings and final copy exist
Board row: `voice06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 voice06_1: Full Voice Pass (Voice Bible II)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding contracts:
`docs/plans/0.5_voice_bible.md` (fully binding) +
`docs/plans/0.6_voice_bible_world_register.md` (the theme: courtesy is
how power gets expressed, bluntness is how powerlessness gets
expressed; narration register rules; period methodology; measurable
brevity rule). This is a copy-quality pass over ALL text added in 0.6
— no mechanical changes. This prompt is self-contained for rules and
scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `voice06_1`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop. **Precondition: every
   content-bearing row (env/town/crew/craps/push/streets/chain/content)
   is DONE** — verify on the board before claiming.
2. Log discoveries/deviations tagged `[voice06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Task

1. **Inventory**: diff all `data/*.json` and script-embedded strings
   added since the 0.5 release boundary (`v0.5.0`); build the audit
   list in `.tmp/` (id, surface, speaker side).
2. **Register audit**: every line classified house-side or
   street-side; house lines carry courtesy-with-a-hook; street lines
   say the thing flatly. The Punchline is the showcase (the street
   *performing* — its L1 comedy lines must be bad on purpose and
   period-true); the Grand Casino heist copy is the house register
   under pressure.
3. **Brevity rule**: apply the bible's measurable rule to every
   audited line; fix violations.
4. **Character consistency**: crew lines against their authored voice
   styles in `data/characters/characters.json`; Vivienne/Rourke/Linda
   against the 0.5 cast entries; new speakers (comics, tote-man,
   whale) get one-line style notes added to the 0.6 bible's cast
   appendix (extend the doc, don't rewrite it).
5. **Discipline double-check**: while touching every string, verify
   crew06_9's rule — nothing player-visible names the hidden systems
   (Turn/clues/ledger, past-posting mechanics beyond diegetic talk).
6. Fix in place (data edits; script-embedded strings edited without
   logic changes). Anything that can't be fixed without mechanical
   change: board Discovery entry, not a code change.

## Hard rules

- Zero mechanical/behavioral changes: string-only diffs (enforce by
  review; tests must pass unchanged with no re-tuning).
- Ids, flags, and keys never change — display text only.
- Determinism untouched (no string used as an RNG input may change —
  audit for that anti-pattern first; if found, board Discovery, skip
  the string).
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Full suite green with zero non-string diffs (mechanical-diff audit
   script evidence in `.tmp/`).
2. Audit list coverage: every 0.6-added string classified + checked
   (list attached to board note).
3. Spot manual pass: 20 random surfaces in-game read correctly;
   screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: audit coverage stats, register fixes count, bible appendix
additions, and gate results. On an unfixable gate failure: stop at
last green commit, set `BLOCKED`, report verbatim.
