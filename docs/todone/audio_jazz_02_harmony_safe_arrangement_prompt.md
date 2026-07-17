## Execution Record

- Completed: 2026-07-17
- Implementation: `b3a280c9`, integrated by `a94f338d`.
- Verification: two fresh Godot processes each completed 5,000 deterministic selections with identical output (SHA-256 `159ff00ca23fdd989f63f40d455c02988a743505b9c6cc1c85823de03acb29e2`); incompatible chord/bass combinations were never selected.
- Deviation: none in the arrangement contract. Musical approval of the supplied progressions still belongs to the engineer after real recordings arrive.

# Agent Prompt - Jazz Audio 2: Harmony-Safe Arrangement Recipes

Copy everything below this line into the implementing agent.

---

Implement harmony-safe, deliberately authored arrangement selection for the
Jazz Club. This depends on
`docs/todo/audio_jazz_01_delivery_and_ingestion_prompt.md` being complete.

## Musical rule

Chord progression selection is the authority for a phrase. A bassline is
never selected independently from an unrelated chord progression. The
engineer expects a typical chord voicing to contain roughly three or four
notes while the bass usually follows one root note per chord change. Preserve
that relationship by metadata, not by guessing from filenames or audio.

## Data model

Extend the authored manifest with explicit compatibility bundles/sets:

- stable `progression_id` or equivalent;
- ordered chord/root description for validation and engineer readability;
- key and harmonic section;
- compatible Chords, Bass, Lead, drum, texture, and optional tension variants;
- role requirements versus optional roles;
- pattern weights/tags/exclusions inside the compatible set;
- arrangement recipes such as `AABA` and `AACA`.

The selector must first choose the progression/section bundle, then select
only compatible variants inside it. A bass variant cannot enter the candidate
pool unless its compatibility set matches the chosen chord progression.

Different recorded keys must not be freely cross-selected or transposed.
Support multiple keys only when the engineer supplies a complete compatible
bundle for each key. Key changes happen at declared phrase boundaries using
the transition system.

## Deliberate form

Add a deterministic arrangement recipe state machine capable of instructions
such as:

- keep the main progression for three phrases, then use B (`AABA`);
- later keep the main progression but change a chosen instrument on the third
  contrasting phrase (`AACA`);
- change one instrument every N core-progression repetitions;
- retain motif/instrument identity for a configured number of phrases before
  another weighted choice becomes eligible.

This state must advance from musical phrase events, not frame time or repeated
snapshot reconstruction. Store enough compact state for deterministic
save/load continuation.

## Selection behavior

- Choices remain deterministic for the run seed, venue visit identity,
  recipe cycle, and musical event history.
- Weighted variation is allowed only inside the authored compatibility set.
- Mutual exclusions and existing gameplay tags still apply.
- A missing optional role is silent. A missing required compatible role
  invalidates that bundle with a useful content error.
- Do not create arbitrary combinations merely because individual files share
  BPM and length. The result should sound intentionally assembled.

## Jazz fixture

Create a representative Jazz Club recipe containing at least:

- one A progression with two compatible chord-instrument choices;
- bass patterns explicitly tied to that A progression;
- one B progression or contrasting instrument bundle;
- an `AABA` cycle followed by an `AACA`-style cycle;
- proof that an intentionally incompatible bass file is never selected.

## Tests and acceptance

1. Thousands of deterministic fixture selections produce zero incompatible
   chord/bass pairings.
2. The same seed/history yields the same phrase sequence across processes.
3. The fixture emits the declared AABA then AACA timeline.
4. Save/load in the middle of a cycle resumes the same next phrase.
5. Snapshot output includes progression ID, recipe ID, cycle index, phrase
   index, chosen variants, and why candidates were excluded.
6. Existing intensity, tags, exclusions, and sparse-stem behavior regressions
   remain green.

Run project validation, systems tests, and the determinism probe. After
verification, archive this prompt per `docs/todone/RULES.md`.
