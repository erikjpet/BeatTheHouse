# Agent Prompt — Total Writing & Voice Pass (Neo-Noir, Personal, Coherent)

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike set in a neo-noir, neon-futuristic gambling world. This is a
COMPLETE writing pass over the game's player-facing text. Right now
descriptions, dialogue, and tooltips read like a robot describing things
word-for-word — flat, repetitive, impersonal. Make the whole game sound
like it was WRITTEN BY A PERSON living in this world: personal, snappy,
funny, comedic, sometimes rude — with distinct character voices — never a
manual reciting what things do.

**PHASE 1 IS ALREADY DONE AND OWNER-APPROVED.** The voice bible exists at
`docs/plans/0.5_voice_bible.md` and the owner has signed off on it. Do NOT
re-draft it or re-open the checkpoint — read it, treat it as binding, update
`content_style_guide.md` to reference it if needed, and go straight to
Phase 2 (the rewrite). If you find a character in the data that the bible
does not cover, extend it in the SAME voice and note the addition in your
report; do not change the approved voices.

## Scope — EVERY player-facing string in the game (exhaustive)

This is a TOTAL pass over ALL player-facing text, not just dialogue. Before
rewriting, DISCOVER the full surface: grep the entire `data/` and `scripts/`
tree for player-facing strings and build a coverage checklist so nothing is
missed. At minimum, all of the following, and anything the sweep turns up:

Data packs:
- `data/items/items.json` — item names, descriptions, tooltips.
- `data/events/events.json` — event summaries, choice labels, result text.
- `data/dialogue/dialogues.json` — character dialogue.
- `data/environments/archetypes.json` — environment descriptions, objective
  hints, suspicion cues, moods, name parts.
- `data/debt/lenders.json`, `data/services/services.json` — lender/service
  lines.
- `data/tutorial/lessons.json` — coach/tutorial copy.
- `data/challenges/challenges.json` — challenge names/descriptions.
- `data/travel/routes.json` — route flavor, condition/risk text.
- `data/collections/collections.json` — collection/item flavor text.
- `data/art/attribute_glyphs.json` — any player-facing label/description
  fields (skip pure ids/keys).

Code (hardcoded player-facing strings — a LARGE body, do not skip):
- `scripts/games/*.gd` — EVERY game module (blackjack, roulette, baccarat,
  bar_dice, video_poker, pull_tabs, scratch_tickets, slot, and the
  `grand_casino_showdown_model.gd` / `grand_casino_duel_model.gd`): result
  messages, action/button labels, rule explainers, turn guides, table
  names, dealer/character barks, win/loss/cheat text.
- `scripts/core/run_state.gd` — failure/victory messages (e.g. the
  `*_FAILURE_MESSAGE` constants) and story-log entry text.
- `scripts/ui/*.gd` — HUD readouts/labels, menu/settings/start-screen
  strings, tooltips, run-report outcome copy, meta/collection/sale text,
  coach bubbles, and any other on-screen string.

Reference:
- `docs/plans/0.5_voice_bible.md` — the approved voice (binding).
- `docs/plans/content_style_guide.md` — update it to reference the bible.

Do NOT touch: internal ids, keys, enum values, debug/dev-only strings, log
tags, test fixtures, or anything the player never sees. When unsure whether
a string is player-facing, check where it renders before rewriting it.

## PHASE 1 — DONE (voice bible approved)

`docs/plans/0.5_voice_bible.md` is the approved, binding reference: the
world's neo-noir narrative voice, an identity + tics + sample lines for
every recurring character (Rourke, Linda, Sal, the Crew, the brother-in-law,
the street/motel lenders, June the bartender, dealers, hosts, Dave, and the
patron archetypes), the multiple-lines rule, and the tooltip rule. Update
`content_style_guide.md` to point at it. Then do Phase 2.

## PHASE 2 — Rewrite everything to the approved voice

Rewrite the copy across all the sources above to match the bible:

- **Character dialogue:** each line fits that character's voice from the
  bible. Give every character MULTIPLE lines for the same action/cause —
  pools the game draws from — so they never repeat the same line. Audit
  the data for single-line responses and expand them into varied pools
  (the dialogue/event systems already support option/line variation —
  wire pools through the existing structures, don't invent a new one).
- **Event copy:** personality over instruction. Choice labels and result
  text should have voice and be funny/snappy/rude-in-theme; they should
  NOT baldly state the mechanical effect ("A riskier route opens" →
  something a character would actually say). The consequence still happens
  in data; the TEXT stops narrating it like a spec.
- **Tooltips (items, icons, controls):** BRIEF and descriptive — a short,
  evocative line that conveys the vibe/use with NO excess detail, NO
  word-for-word "this does X + Y + Z." Trim every tooltip to its essence.
- **Item names & descriptions:** flavorful, in-world, personal — not a
  datasheet.
- **Environment descriptions, objective hints, suspicion cues, moods:**
  rewrite in the world's voice — atmospheric and characterful, still
  communicating what the player needs.
- **Game-surface text (every module):** result messages, action/button
  labels, rule explainers, turn guides, table names, and dealer/character
  barks get the same voice treatment — dealers/hosts/patrons speak per the
  bible; rule/result text is in the narrator's dry neo-noir register and
  still clear. Barks and repeated result lines become multi-line pools.
- **Failure/victory & story-log messages (run_state):** the run's end
  lines and logged beats read in-voice — a broke-out line, a police-capture
  line, a taken-out-back line, a clean-cashout line, each with the weight
  the moment deserves, not a status printout.
- **Tutorial/coach, challenges, routes, collections:** all rewritten in
  voice — coach tips stay brief and helpful but human; challenge and route
  flavor gets personality; collection flavor reads in-world.

## Rules

- **Coherence:** the whole game reads as one consistent world and voice.
  No two characters sound the same; no character sounds like the UI.
- **Content boundary:** edgy, dry, rude-in-character is welcome; keep it
  tasteful and in-theme — no slurs, no punching down, nothing that would
  read as genuinely offensive rather than noir-seedy.
- **Meaning preserved:** the player must still understand what a choice/
  item/objective is FOR — personality replaces robotic exposition, it
  doesn't remove necessary information. Tooltips stay descriptive, just
  brief and characterful.
- **Data-only where possible:** copy lives in data; change strings, not
  systems. Where a UI string is hardcoded, move it or edit in place
  cleanly. Do not change mechanics, ids, or structure — only text.
- Style: tabs, typed GDScript for any UI-string edits; keep JSON valid;
  reports under `.tmp/`. Suite timeout = max(300s, ceil(baseline × 1.5)).

## QA

1. Coverage: the discovery sweep's checklist is fully worked — data packs
   AND game modules AND run_state AND ui strings — report the checklist
   with each source marked done, and any player-facing string you
   deliberately left (with why).
2. Content-library validation passes (all ids/refs intact after edits);
   game modules still compile; no id/key/enum accidentally reworded.
3. Repetition audit: assert (or manually verify) that high-frequency
   speakers/actions (dealer barks, result lines, greetings) draw from
   multi-line pools, not a single string.
4. Tooltip brevity: spot-check that tooltips are short and free of excess
   detail.
5. Coherence read-through: play a full session across all eight games, a
   full run to each ending, the meta home, and the tutorial; every screen's
   text reads in-voice and characterful; no robotic leftovers; report any
   you left.
6. No mechanical drift: choices/items/objectives/rules still communicate
   their purpose despite the voicier copy.

## Gates

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (content validation + ui + systems)
- `tools\foundation_visual_qa.ps1`

## On completion

Only after Phase 2 is done, every gate passes, AND you've read the game
through in-voice:

1. Commit in logical units (voice bible + style guide; then rewrites by
   source group).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   voice-bible path, what you rewrote, gate results), and stage the move.
3. PUSH to the remote.
4. Report: the character roster and voices, the multiple-line pools added,
   the tooltip approach, and gate results.

The voice bible is already approved (`docs/plans/0.5_voice_bible.md`) — there
is NO approval checkpoint; go straight to the rewrite. On an unfixable gate,
stop at the last green commit, do NOT push, report verbatim.

---

## Execution record — 2026-07-29

- Voice bible: `docs/plans/0.5_voice_bible.md` was treated as owner-approved and binding; `docs/plans/content_style_guide.md` now references it directly.
- Commits:
  - `a4c7407a` — docs: bind 0.5 voice bible
  - `1c813562` — content: rewrite player-facing copy for 0.5 voice
  - `0fba5ef9` — ui: voice fallback player messages
- Scope completed:
  - Rewrote player-facing copy across characters, dialogue, events, choices, items, services, lenders, challenges, routes, game intros/descriptions/action summaries, environment blurbs, tutorial lessons, content groups, collection flavor, glyph tooltips, and fallback UI/status messages.
  - Expanded recurring character/action voice pools to 3+ lines with no intended back-to-back repeats. Dave's one-line bus warning was preserved because he is a one-off bus encounter and the UI scene test asserts the exact line.
  - Kept JSON IDs, mechanics, prices, effects, flags, gates, and route data intact; copy was adjusted where tests required explicit player-facing keywords such as route unlocks, police/cuffs, shakedown, and starter-card fragility.
- Characters voiced:
  - Rourke, Linda, Sal, the Crew, Gabe, street and motel lenders, June, clerks, hosts, Dave, Niles, jazz trio, patron archetypes, and supporting merchants/contacts not named in the bible but extended in the same neo-noir register.
- Gate results:
  - `tools/validate_project.ps1` — PASS
  - `tools/check_godot.ps1 -FoundationSuite contracts -RequireGodot` — PASS (`content` is not an exposed FoundationSuite name; contracts contains the current content-contract coverage)
  - `tools/check_godot.ps1 -FoundationSuite ui -RequireGodot` — PASS
  - `tools/check_godot.ps1 -FoundationSuite systems -RequireGodot` — PASS
  - `tools/foundation_visual_qa.ps1` — PASS
- Deviations:
  - No approval checkpoint was used, per owner instruction.
  - No mechanics or persistence changes were made.
