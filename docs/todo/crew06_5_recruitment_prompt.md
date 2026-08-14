Status: TODO
Board row: `crew06_5` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 crew06_5: Crew Recruitment (Seven Placements)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The
seven, placed in the world" + trust ladder. The 7 crew characters
(voices authored) are in `data/characters/characters.json`; env06_2/3
placed inert recruitment anchor flags in scenarios. Voice: both voice
bibles (crew = street register, warmth without polish). This prompt is
self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_5`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[crew06_5]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (crew06_6/7/8).

## Dependencies

`crew06_1`, `env06_2`, `env06_3` DONE (trust API + anchors). Verify
anchor flag ids by code.

## Task

### 1. Placements + intro encounters

Wire each member's recruitment where their life happens (anchor
scenarios from env06_2/3; fallback encounters so no member is
unmeetable in a run whose scenarios didn't align — data-tuned
secondary placements):

- **Rook** — already met via the crew loan (the recruiter). Extend
  his post-Marker dialogue: he names the others as they become
  meetable ("Switch works the truck stops") — the path's diegetic
  signposting, subtle, never a quest log.
- **Switch** — gas station *Trucker Convoy* (fallback: back alley).
- **Mags** — pawn shop *Fence Night* (fallback: Punchline L2).
- **Knuckles** — bar *Fight Night* (fallback: Punchline door).
- **Velvet** — kitty lounge *The Buyout* (fallback: Slow Night beat).
- **Bishop** — Grand Casino periphery/cage window (a quiet two-beat
  encounter; he never breaks cover on the floor).
- **Lucky** — beach *Festival Weekend* (fallback: any Numbers venue
  once crew06_3 is live — data-gated).

Each intro: an encounter event (existing event mechanics) with a
choice beat that grants first trust and opens that member's
`associate` job availability. Dialogue per authored voice styles —
each member must sound like their `characters.json` entry.

### 2. Mechanics unlocked by rank (wire the ones that exist)

- `associate`: member's jobs appear on offer surfaces (job board
  arrives in crew06_6; until then the member's own encounter offers).
- Switch `associate+`: wire town06_3's `sweep_status()` capability +
  remote scenario reveal (map heard-tier upgrades via town06_2 —
  data-limited uses per visit).
- Rook `made`: L3 escort flag for env06_4's door.
- Knuckles `associate+`: contraband stash service (pre-sweep stashing
  seam from town06_3 — a stash inventory that survives sweep
  encounters, data-capped).
- Velvet/Bishop/Mags/Lucky rank perks beyond the above land with
  their systems (plays: crew06_7; heist: crew06_8; Numbers:
  crew06_3) — leave their rank gates defined in `data/crew/crew.json`
  so those prompts consume, not invent.

### 3. Presence

- Met members appear in their itinerary/residence locations (ambient
  placement + one contextual line by rank tier). Never omnipresent:
  presence is seeded and legible.

## Hard rules

- No quest log, no tracker UI: signposting is diegetic (Rook's lines,
  rumors).
- A run that ignores the crew entirely must look byte-identical to
  0.5 outside the anchor scenarios' ambient presence (regression).
- Determinism: encounter availability + fallbacks seeded; no
  wall-clock.
- Perf/save/style rules as other prompts; save round-trips met/rank
  state (crew06_1 fields).
- Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Each member recruitable via primary anchor AND fallback in seeds
   lacking the anchor (7×2 fixture matrix).
2. Rank perks gate correctly (Switch intel, Rook escort, Knuckles
   stash) and are absent below rank.
3. Crew-ignoring run regression: no trust movement, no new
   interruptions beyond ambient presence.
4. Rook's signposting lines appear only for genuinely meetable
   members this run.
5. Save/load mid-path preserves met/rank/perk state.
6. Voice check: every new line matches its member's authored style
   (manual review noted in the board).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: placement/fallback table, rank-perk wiring, regression
evidence, and gate results. On an unfixable gate failure: stop at last
green commit, set `BLOCKED`, report verbatim.
