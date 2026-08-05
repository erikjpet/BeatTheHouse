# Agent Prompt: Narration Reword, Calibration Pilot

**EXECUTED 2026-08-05.** 104 string values changed across 5 data files.
Results: `docs/plans/0.6_pilot_reword_diff.md`. Spec:
`docs/plans/0.6_voice_bible_world_register.md`. Full rollout:
`docs/todo/narration_reword_rollout_prompt.md`.

Known defect found after execution: this prompt told the worker to assign
register from the pool an entry was read out of ("Corner store entries are
Street. Grand casino entries are House."). That is wrong for entries pooled
by venues of differing registers. `door_bribe` was written in House courtesy
and appears at a gas station; corrected same day. The rollout prompt replaces
that instruction with the union rule.

Copy everything below the line into the worker agent. This is a **pilot
slice, not the full pass.** It rewords ~60 narration strings so the owner can
judge the voice at length before ~1,480 get touched. The worker stops at the
end and reports. A follow-up prompt covers full rollout once approved.

---

You are in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This is a **writing task with a data edit**, not a code task. You
are rewording existing narration strings in JSON. Everything you need is
inlined below. You do not need to read any other document to do the work.

Background if you want it: `docs/plans/0.5_voice_bible.md` (the cast, still
binding in full) and `docs/plans/0.6_voice_bible_world_register.md` (this
spec, in full). Neither is required reading.

## What you are doing

Rewording ~60 existing narration strings. This is a **reword pass**: every
string keeps its existing meaning, slot, and mechanical implication. You are
changing how lines are worded, not what they say. No new fiction, no new
concepts, no dropped information, no schema changes.

**You are not touching character dialogue.** Named-cast speech is governed by
a separate document and is out of scope entirely.

## The setting

A gambling town where the future arrived but the vices didn't change: a
1960s that never moved on culturally, with the technology that followed
showing up inside it anyway. No apocalypse. Advanced systems sit in old rooms
nobody redecorated.

This is a **methodology, not a costume.** No period slang, no pastiche, no
"old-timey" phrasing. The past comes through sentence construction. The
future comes through implication only.

## The theme

**Courtesy is how power gets expressed. Bluntness is how powerlessness gets
expressed.**

The house can afford to be gracious about what it takes, and being gracious
is part of taking it. The street can't afford the dressing, so it says the
thing. Same machine, same transaction, opposite sentence.

The existing cast already performs this. The Grand Casino host's written
tic is "frames surveillance as hospitality," the pit boss says "the cameras
love you, so do I," while a street-side rival counter says "keep 'em where
the cameras can't fall in love." Narration is the one place that split isn't
yet expressed. You are expressing it.

## The three method rules

1. **Plain declaratives, concrete nouns, no slang from any era.** Slang reads
   as costume and dates the writing. Period feel comes from unadorned
   construction: short, unhedged, physical. Nothing should sound old. It
   should sound plain.
2. **Nobody marvels at the future.** No one in 1962 was amazed by their
   refrigerator. Tech appears only as a mundane convenience or a mundane
   annoyance. Never admired, never explained, never called technology.
3. **Name the effect, not the device.** Not "surveillance system," not "the
   house eye." Write *"the ceiling counts."* The player assembles the tech
   themselves.

## The brevity rule (enforced, check every line)

The corpus averages 23 characters per string, two beats, 3 to 8 words.

**A rewritten string may not exceed its original by more than 20%
characters.** Verify per string and report the delta.

House register is *gracious*, not verbose. Street is *blunt*, not clipped
into nonsense. Character and context must survive inside the budget. If a
line needs more room, the line is wrong, not the budget.

## The two registers

**House**: control expressed as courtesy.
- Machines take verbs of service: keeps, provides, sees to, looks after
- Passive voice for anything unpleasant: guests are asked, the matter is handled
- Machines may take warm adjectives: careful, attentive, exact
- Courteous rhythm, still short

**Street**: control expressed as imposition.
- Machines take verbs of taking: counts, remembers, doesn't forget
- Active, blunt, short
- Machines take **no** adjectives; they just do things
- Resentment lives in what is withheld. Never complain outright.

Same noun, both ways:

| | House | Street |
|---|---|---|
| the ceiling | "The ceiling keeps the room pleasant." | "The ceiling counts. Never wrong, never fair." |
| the arithmetic | "The arithmetic is checked nightly." | "The arithmetic knew before you sat down." |
| the file | "Your file is kept discreetly." | "There's a file. You've never seen it." |

**The check:** if a narration line couldn't plausibly sit next to that
venue's characters, the register is wrong.

## Renamed nouns

Effect-first (rule 3) is always preferred. Use these only when the thing must
be named. **Do not extend this list.** If a concept isn't covered, describe
its effect in plain words.

| The thing | What they call it |
|---|---|
| surveillance / monitoring | the ceiling, the floorman |
| biometric scan / ID check | getting your picture took |
| data, records, history | the file, the book, the tape |
| networked comms | the line |
| drone | a little bird |
| predictive odds engine | the arithmetic |
| implant / worn device | a gadget |

## Hard constraints

1. **The player speaks, but their words are never shown.** The player
   character talks: they ask, haggle, refuse, and negotiate out loud in the
   fiction. The player simply never sees the line. Narration may freely
   report that speech happened and what it accomplished ("A word passes. He
   owes you a quiet one."), but never surfaces the wording itself, in quotes
   or in paraphrase specific enough to read as a quote.
   Choice labels stay intent-shaped: `Haggle`, `Move On`, `Ask too quietly`,
   `Trade for a route`. These already have personality without being speech;
   `Ask too quietly` is the model. **Never** convert a label into quoted
   player speech.
2. **Meaning is preserved.** Same semantic content, same slot, same
   mechanical implication.
3. **No renaming.** Venues, characters, games, items, themes are set.
4. **No numbers as prose.** Glyphs and badges carry values. "+2 luck for 3
   turns" as words is banned.
5. **No schema changes.** Reword in place. Do not add, remove, or rename any
   key.
6. **Do not touch dialogue node text** in `data/dialogue/dialogues.json`.
   Out of scope.

## Scope: exactly these, nothing else

### A. The 15 global items in `data/items/items.json` (`domain: "global"`)

Register: **neutral**. They follow the player across all venues, so they
must read correctly in both a gas station and the Grand Casino.

`creased_luck_card`, `pile_of_pull_tabs`, `pile_of_scratch_tickets`,
`instant_coffee`, `ledger_pencil`, `cashout_envelope`,
`thermos_black_coffee`, `thermos_black_coffee_half`, `pickled_olive_jar`,
`lucky_bar_napkin`, `lucky_keychain`, `payment_calendar`,
`jazz_sax_lucky_coin`, `jazz_cello_lucky_coin`, `jazz_drummer_lucky_coin`

Rewrite each `description`. Every line stays distinct, no shared phrasing.

Worked example:
`"Bent paper. Still likes your hand."` → `"Bent paper. Unread, and still lucky."`

### B. `corner_store` in `data/environments/archetypes.json`

Register: **Street**. Rewrite `objective_hint` and
`visual_context.description`.

Current hint: `"Build cash. Bigger rooms keep invitations warm."`

### C. `grand_casino` in `data/environments/archetypes.json`

Register: **House**. Rewrite `objective_hint` and
`visual_context.description`.

### D. The 8 game descriptions in `data/games/games.json`

Register: **neutral**. `blackjack`, `slot`, and `video_poker` each appear at
tiers 1, 2, and 3, so one string must serve both ends. Write flat and let the
venue carry the color.

`scratch_tickets`, `pull_tabs`, `slot`, `bar_dice`, `blackjack`, `baccarat`,
`video_poker`, `roulette`

Worked example:
`"Beat twenty-one without becoming interesting."` →
`"Beat twenty-one without becoming worth watching."`

### E. Events and services pooled in `corner_store` and `grand_casino`

Read those two archetypes' `event_pool` and `service_pool`, then rewrite
`description` / `start_summary` / `payload.summary` for **only** the entries
those pools name, in `data/events/events.json` and
`data/services/services.json`. Corner store entries are Street. Grand casino
entries are House.

Rewrite `choices[].text`. **Do not** rewrite `choices[].label`, since labels are
player intents and stay exactly as they are.

## Deliverables

1. The JSON edits, in place, valid, byte-for-byte identical outside the
   reworded string values.
2. `docs/plans/0.6_pilot_reword_diff.md`, a before/after table of every
   changed string: file, id, register, before, after, char delta. Grouped by
   scope section (A to E).
3. A short note on any line where the 20% budget and the meaning could not
   both be satisfied, with what you chose and why.

## Acceptance

- Every changed string is within +20% characters of its original.
- Every string's original meaning is intact.
- No key added, removed, or renamed anywhere.
- No choice label changed. No dialogue node text changed.
- All edited JSON parses.
- The game boots and a run reaches the corner store with the new strings
  rendering, with no truncation or overflow in the item and environment panels.
- Street lines carry no adjectives on machines. House lines carry no blunt
  taking-verbs.
- No two items share phrasing.
- Register check: each Street line could sit beside Sal or June; each House
  line could sit beside Vivienne or Rourke.

## Rules for this task

- **Do not commit and do not push.** Leave all changes on disk. The owner
  reviews and commits.
- Do not refactor code, fix unrelated issues, or touch anything outside the
  files named above.
- Do not expand scope to the rest of the corpus. This is a calibration slice.
  The point is that the owner judges ~60 lines before ~1,480 are touched.
- If the spec and a specific line genuinely conflict, follow the spec and
  flag the line in your report rather than inventing an exception.

## Report

Finish with: what you changed, the diff doc path, any budget conflicts, and
your own read on whether the neutral register in sections A and D holds up at
length or reads flat next to the Street and House lines.
