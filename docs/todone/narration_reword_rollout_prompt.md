# Agent Prompt: Narration and Dialogue Reword, Full Rollout

**EXECUTED 2026-08-05. All 7 phases complete.** Phases 1 and 2 landed earlier
(archetypes, events). Phases 3 to 7 executed in this pass: 339 strings across
13 data files, plus full contraction and elision restoration.

Results: `docs/plans/0.6_rollout_reword_diff.md`.
Spec: `docs/plans/0.6_voice_bible_world_register.md`.

Outstanding, deliberately not done:
- Never render-verified. Godot is not installed on the project manager
  machine, so no string has been seen on screen.
- Dave Harlan's `bus_warning` line pool still has 1 line against the 0.5
  rule of 3 or more. Expanding it is new writing and needs an owner call.
- The ~2,100 hardcoded player-facing strings in `scripts/ui`, `scripts/games`,
  and `scripts/core` remain untouched by any voice pass. Out of scope here;
  needs its own prompt.

Copy everything below the line into the worker agent. This is the full pass:
**811 strings across 15 data files**, covering narration *and* character
dialogue. A 104 string calibration pilot already ran and was approved; this
covers everything else and must match the voice it established.

Owner decisions locked 2026-08-05 and reflected below: dialogue is in scope,
character definitions and personalities are not, and the neutral register is
accepted as street-leaning by design.

Prior art, both worth reading first: `docs/plans/0.6_pilot_reword_diff.md`
(104 approved before/after lines, the calibration target) and
`docs/plans/0.6_voice_bible_world_register.md` (the spec). Character voices
are defined in `docs/plans/0.5_voice_bible.md` and remain binding.

---

You are in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike. This is a **writing task with a data edit**, not a code task. You
are rewording existing strings in JSON. Every rule is inlined below.

## What you are doing

Rewording **811 remaining strings** so they fit the world's theme and read
more clearly to a player. Two goals, both required:

1. **Fit the theme.** Apply the register system defined below.
2. **Make more sense to a player.** Where the original is opaque about what
   is happening or what a choice does, make it legible. This is a real
   license: if a line is atmospheric but confusing, clarity wins.

**What "preserve meaning" means here:** the mechanical outcome, the slot, and
the authorial intent stay identical. The *prose* may become clearer than the
original was. You are not free to change what an event does, what an item is,
or who a character is. You are free, and expected, to make a murky line
legible.

A pilot of 104 strings already landed in `items.json`, `games.json`,
`services.json`, `events.json`, and `archetypes.json`. **Do not redo those.**
Read `docs/plans/0.6_pilot_reword_diff.md` first and match its voice. If your
line would look out of place in that table, it is wrong.

## The setting

A gambling town where the future arrived but the vices didn't change: a 1960s
that never moved on culturally, with the technology that followed showing up
inside it anyway. No apocalypse. Advanced systems sit in old rooms nobody
redecorated.

This is a **methodology, not a costume.** No period slang, no pastiche, no
"old-timey" phrasing. The past comes through sentence construction. The
future comes through implication only.

## The theme

**Courtesy is how power gets expressed. Bluntness is how powerlessness gets
expressed.**

The house can afford to be gracious about what it takes, and being gracious
is part of taking it. The street can't afford the dressing, so it says the
thing. Same machine, same transaction, opposite sentence.

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

## The two budgets (both enforced, check every line)

**1. Per-string:** a rewritten string may not exceed its original by more
than **20% characters**.

**2. Per-field-kind width:** a rewritten string may not exceed the **longest
pre-existing string of its own field kind in that file**. Compute the maximum
per field kind **before** writing and treat it as a hard ceiling.

The first protects rhythm. The second protects layout: no panel has ever
rendered an item description longer than 41 characters, and a writing pass is
not the place to find out what breaks at 47. The pilot tripped this five
times and had to walk lines back.

These self-calibrate per field. Dialogue node text gets measured against
dialogue node text, not against item descriptions.

## The registers

**House**: control expressed as courtesy.
- Machines take verbs of service: keeps, provides, sees to, looks after
- Passive voice for anything unpleasant: guests are asked, the matter is handled
- Machines may take warm adjectives: careful, attentive, exact

**Street**: control expressed as imposition.
- Machines take verbs of taking: counts, remembers, doesn't forget
- Active, blunt, short
- Machines take **no** adjectives; they just do things
- Resentment lives in what is withheld. Never complain outright.

**Seam**: House grammar on Street specifics. The room reaching for courtesy
it cannot afford. House verbs on visibly worn objects. Linda, delivering
house warmth through barred glass, is the cast model.

**Private**: outside both. The three `home` archetypes are the only rooms
nobody else owns. No ceiling counts here, no courtesy extended, nothing
taken. Plain and quiet, **no watching verbs at all**, never a machine as
grammatical subject. Existing lines already do it: "A rented pause.",
"Better locks. Softer silence.", "Your roof. For now." The absence of the
machinery is the point. Do not add any.

**Neutral**: no register markers either way. No courtesy grammar, no machine
adjectives, no taking-verbs with a machine as subject. People may still act.

**Neutral leans Street, and that is intentional.** Owner decision: the
objects and rooms neutral describes are mostly worn and cheap, the player
carries them up from the street, and a true-center neutral would read
bloodless. Let it lean. Do not re-center it, and do not flag it again.

Same noun, both ways:

| | House | Street |
|---|---|---|
| the ceiling | "The ceiling keeps the room pleasant." | "The ceiling counts. Never wrong, never fair." |
| the arithmetic | "The arithmetic is checked nightly." | "The arithmetic knew before you sat down." |
| the file | "Your file is kept discreetly." | "There's a file. You've never seen it." |

**The check:** if a line couldn't plausibly sit next to that venue's
characters, the register is wrong. Street lines sit beside Sal or June. House
lines sit beside Vivienne or Rourke.

## Register is decided by the union of a string's placements

**The pilot got this wrong. Read it twice.**

A string does not take the register of the venue you happened to read it out
of. It takes the register of **every** place it can appear. If that set spans
more than one register, the string is **neutral**.

There are **two** placement mechanisms and you must union both:

1. **`event_pool` / `service_pool`** membership in `archetypes.json`.
2. **`scopes`** on the entry itself, matched against each archetype's
   `event_scopes`.

Compute it, do not eyeball it.

### Archetype registers (all 18)

| register | archetypes |
|---|---|
| **Street** | `corner_store`, `back_alley`, `motel`, `bar`, `gas_station_casino`, `pawn_shop` |
| **House** | `grand_casino`, `grand_casino_high_limit`, `grand_casino_back_room`, `grand_casino_cage`, `delta_queen`, `kitty_cat_lounge` |
| **Seam** | `small_underground_casino`, `jazz_club`, `beach` |
| **Private** | `motel_room`, `apartment`, `house` |

### Scope registers

| scope | archetypes it reaches | register |
|---|---|---|
| `boss` | 4 grand casino rooms | **House** |
| `home` | apartment, house, motel_room | **Private** |
| `meta` | pawn_shop | **Street** |
| `recovery` | beach | **Seam** |
| `shop` | back_alley, corner_store, jazz_club, motel, pawn_shop | Seam+Street, so **neutral** |
| `casino` | bar, delta_queen, gas_station_casino, kitty_cat_lounge, small_underground_casino | all three, so **neutral** |
| `any` | everything | **neutral** |

Known trap: `high_roller_cashout` has no pool membership but is
`scopes: ["boss"]`, which makes it **House**, not neutral. It is the only
entry where pool membership and scope disagree in a way that matters. Every
other pool-less entry carries `any`.

Known data oddity, flag but do not fix: some events use scope values `bar`
and `club`, which no archetype declares. They change no register here because
every affected entry also carries `any`.

`grand_casino_back_room` is Rourke's and takes the purest House voice in the
game. `grand_casino_cage` is Linda's: House grammar through barred glass.

## Character-owned entries

Where an entry belongs to a named character, **the character's register wins
over the placement register.** Placement register is for rooms; these are
people, and the narration renders directly beside that character's own lines.
A neutral frame around a Rourke line reads as a seam in the writing.

| entry | owner | register |
|---|---|---|
| `pit_boss_heat_warning` | Elias Rourke | House |
| `floor_staff_heat_warning` | Nadia Price, staff | House |
| `high_roller_cashout` | boss-scoped | House |
| `family_loan` | Gabe Mercer, Brother-in-Law | Street |
| `dave_bus_warning` | Dave Harlan | outside both |
| game-patron probes (6) | named patrons | neutral, leaning Street |

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

Drawn from strings already in the data ("The ceiling loves a pattern.",
"your name in the book"), not invented. Keep them consistent.

## Hard constraints

1. **The player speaks, but their words are never shown.** The player
   character talks: they ask, haggle, refuse, negotiate out loud in the
   fiction. The player simply never sees the line. Narration and NPC dialogue
   may freely reference that the player spoke and what it accomplished ("A
   word passes. He owes you a quiet one."), and NPCs may answer what the
   player said. Never surface the player's wording, in quotes or in
   paraphrase specific enough to read as a quote.
2. **Choice labels are never edited.** Not in events, not in dialogues.
   `Haggle`, `Move On`, `Ask too quietly`, `Trade for a route`. They are
   player intents with personality, not speech. `Ask too quietly` is the
   model. Leave all 94 dialogue labels and every event label untouched.
3. **Character definitions and personalities are locked.** Owner decision.
   Do not touch `voice.style`, `display_name`, `title`, `role`, or any
   personality description in `characters.json`, and do not alter any
   character's characterisation from `docs/plans/0.5_voice_bible.md`. You are
   rewriting **what they say**, never **who they are**. A rewritten Sal line
   must still be gruff, mocking, transactional and secretly fond. A rewritten
   Vivienne line must still frame surveillance as hospitality.
4. **Meaning is preserved, clarity may improve.** Same mechanical outcome,
   same slot, same intent. Murky prose may become legible.
5. **No renaming.** Venues, characters, games, items, themes are set.
6. **No numbers as prose.** Glyphs and badges carry values. "+2 luck for 3
   turns" as words is banned. If a line announces its own mechanic ("Opens
   the Small Underground Casino route."), reword to keep the information
   without the spec-sheet voice.
7. **No schema changes.** Reword in place. Never add, remove, or rename a
   key. Never change the length of a line pool array.
8. **No em dashes and no en dashes.** Not in data, not in your report, not in
   any doc you write. Use commas, colons, or full stops.

## Restore contractions and elisions

**This is the highest-yield rule in the pass. Apply it everywhere.**

The 0.5 writing pass shipped on 2026-07-29 (commit `1c813562`) and then
something stripped every apostrophe out of the result. The approved bible
lines and the lines actually in the data no longer match:

```
bible:  "Casino chips. They wouldn't cash 'em and you bring 'em to me. Cute."
data:   "Casino chips. They would not cash them and you bring them to me. Cute."

bible:  "I got you. It's nothing. It's a little something. It's not nothing."
data:   "I got you. It is nothing. It is a little something. It is not nothing."

bible:  "Pay me when you're flush. You'll be flush. Right? Right."
data:   "Pay me when you are flush. You will be flush. Right? Right."
```

Contraction-free speech reads stiff and formal, which is exactly the
"old-timey costume" effect this spec forbids. It is also the single biggest
reason the dialogue does not currently sound like people talking.

**Restore contractions and elisions wherever a person is speaking**, and in
narration wherever the contraction is the natural form. This is restoration
toward the approved bible, not new writing, and it does not count against
your budgets.

- `do not` to `don't`, `it is` to `it's`, `you are` to `you're`, `I am` to
  `I'm`, `will not` to `won't`, `let us` to `let's`, and so on.
- Restore elisions where the bible has them: `'em` for `them`, `'Course` for
  `Of course`. The bible uses 4 instances of `'em`; the data has 1.
- Do **not** contract where the formal form is deliberate. Rourke is precise
  by character, and "I am certain" may be stronger than "I'm certain."
  Judgment per line, per the speaker's `voice.style`.

41 strings currently carry formal expansions, concentrated in
`characters.json` (28) and `dialogues.json` (7), so most of this lands in
phases 6 and 7. The rest are scattered across events, items, lenders, and
collections; fix them in whichever phase you meet them.

No sanitizer, hook, or validator rule that would re-strip apostrophes exists
in the repo, so the restoration will stick. **If apostrophes revert after you
write them, stop and report it** rather than working around it.

**Do not add emphasis markup.** The bible italicises a word here and there
(`bring 'em to *me*`), but the data contains zero BBCode and the UI does not
use `RichTextLabel`, so asterisks would render literally. Carry the emphasis
in word order instead.

## Dialogue-specific rules

Dialogue is in scope by owner decision. Two files carry it.

- **`data/characters/characters.json`**: rewrite every string inside
  `voice.lines[*]` (202 strings). Keep `voice.style` exactly as written; it
  is the definition that governs your rewrite.
- **`data/dialogue/dialogues.json`**: rewrite `nodes[*].text` (73 strings)
  and the other prose fields. **Never** touch `nodes[*].choices[*].label`.

The 0.5 bible's content rules still hold: every recurring speaker draws from
a pool of at least 3 lines, and a pool never mixes registers. Keep each pool
at its existing length. **Flag but do not fix:** Dave Harlan's `bus_warning`
pool has only 1 line, which violates that rule. Expanding it is new writing,
so it needs an owner decision, not your judgment.

Dialogue is where "make more sense to a player" matters most. If a node's
text leaves the player unsure what they are being offered, fix that while
keeping the speaker's voice intact.

## Phases

Stop after each phase, report, and wait for owner review. Register flows
downhill from venues, so phase 1 is first and is not optional.

| phase | scope | strings |
|---|---|---|
| **1** | `archetypes.json`, the 10 remaining venues | 62 |
| **2** | `events.json`, the 27 remaining events | 128 |
| **3** | `items.json` (55) + `collections.json` (40) + `games.json` (19) | 114 |
| **4** | `services.json` (36) + `lenders.json` (15) + `challenges.json` (18) + `routes.json` (13) | 82 |
| **5** | `attribute_glyphs.json` (30) + `environment_ui.json` (18) + `groups.json` (10) + `run_outcome_icons.json` (7) | 65 |
| **6** | `characters.json`, `voice.lines` only | 202 |
| **7** | `dialogues.json`, node text only | 113 |

**Phase 1 establishes Seam and Private, neither of which has a written line
yet.** Get it approved before anything inherits from it.

Phase 3: items travel with the player, so all are **neutral** unless an item
is exclusive to one register's venues. Phase 4: services take the union rule;
lenders are Street per the cast bible. Phase 5 is UI chrome, **neutral** by
default, since it is the game talking to the player rather than a room
talking; keep it brief and characterful per the 0.5 tooltip rule.

## Deliverables

1. The JSON edits, in place, valid, byte-for-byte identical outside the
   reworded string values.
2. `docs/plans/0.6_rollout_reword_diff.md`: a before/after table per phase
   with file, id, register, field, before, after, char delta.
3. A computed register derivation table for phases 2 and 4 showing, per
   entry, its pool membership, its scopes, and the register the union
   produced.
4. Any line where a budget and the meaning could not both be satisfied, with
   what you chose. Leaving a string unchanged is acceptable and is preferred
   over breaking a budget.

## Acceptance

- Every changed string within +20% of its original and within its field
  kind's pre-existing maximum width.
- Every original mechanical meaning intact; clarity equal or better.
- No key added, removed, or renamed. No line-pool array resized.
- **No choice label changed**, in events or dialogues.
- **No `voice.style`, `display_name`, `title`, or `role` changed.**
- Every character still reads as their 0.5 bible characterisation.
- All edited JSON parses. `powershell -ExecutionPolicy Bypass -File
  tools\validate_project.ps1` passes.
- Zero em dashes and zero en dashes anywhere in `data/`.
- Street lines carry no adjectives on machines. House lines carry no
  taking-verbs with a machine as subject. Private lines contain no watching
  verbs and no machine subjects at all.
- Every multi-register entry is neutral, verified against a computed
  derivation table covering **both** pools and scopes, not by eye.
- No two items share phrasing, and nothing duplicates a pilot line.

## Rules for this task

- **Do not commit and do not push.** Leave all changes on disk. The owner
  reviews and commits.
- Do not refactor code, fix unrelated issues, or touch files outside the
  current phase.
- Stop between phases for review. Do not run start to finish.
- If the spec and a line genuinely conflict, follow the spec and flag the
  line rather than inventing an exception.

## Not verified, and cannot be from the project manager's machine

Godot is not installed there, so **no string in the pilot has ever been
rendered on screen.** The per-field width ceiling is a proxy for a render
test, not a substitute. If you have a working Godot install, run
`tools\check_godot.ps1 -FoundationSuite all` plus a real playthrough to the
corner store and the Grand, and report what the panels actually look like.
That evidence is wanted.
