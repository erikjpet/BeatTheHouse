# Agent Prompt - Jazz Audio 4: Phrase, Fill, and Layer Choreography

Copy everything below this line into the implementing agent.

---

Implement composed transition and room-dwell choreography for the Jazz Club.
This depends on the Jazz arrangement recipes and adaptive native transport.

## Goal

Every assembled performance should feel thoughtfully conducted. Instruments
enter and leave at musical boundaries, drum fills introduce changes, sections
have advance notice, and time spent in a room creates a deliberate build and
release rather than a static loop or arbitrary random toggles.

## Look-ahead transition sequence

The arrangement state machine must publish the upcoming destination section
far enough ahead to schedule its fill. Implement the engineer's default
two-bar transition recipe:

1. The current harmonic instruments keep playing.
2. Regular loop drums stop or fade at the boundary two bars before the new
   section.
3. The authored transition fill occupies that lead-in window according to
   its metadata.
4. The destination section and intended drum pattern land together exactly
   on the phrase boundary.

Support configurable 1-, 2-, or 4-bar lead-ins. A fill is a one-shot unless
explicitly declared otherwise. Fill metadata identifies valid source/dest
sections, progression IDs, and optionally the layer/instrument change it is
introducing. If no compatible fill exists, use a quiet authored-safe exit and
entry; never play an incompatible fill.

## Layer arc over room dwell

Add a per-visit, musical-bar-driven layer choreography recipe. It must support:

- beginning sparse;
- introducing layers one at a time;
- reaching a deliberate full-band peak;
- holding or briefly bringing several parts in together;
- gradually fading selected parts out;
- rebuilding with a different compatible instrument/pattern;
- gameplay overrides such as attention/showdown without losing the recipe's
  underlying position.

Use bars/phrases, not wall-clock frame accumulation. Define Jazz Club fixture
stages in data and keep other venues unchanged until authored. Layer changes
must be phase locked, gain-smoothed, and deterministic.

## Fill-on-change policy

Instrument/layer additions and removals can request a drum fill in the gap
before the change. Prevent fill fatigue with recipe metadata, cooldowns, and
priority rules. A major section change outranks a minor layer change. Multiple
changes on the same destination boundary share one compatible fill instead of
stacking several.

## Recovery and feature interaction

- Save/load restores the current stage and scheduled next boundary.
- Slot feature music can temporarily override/duck venue roles; when it ends,
  the Jazz recipe resumes at a valid phrase boundary rather than restarting.
- A missing optional stem/fill degrades musically and never breaks the room.
- Tempo ramps from the prior slice do not change the bar count of a scheduled
  transition.

## Tests and acceptance

1. Timeline snapshots prove loop drums exit two bars early, the fill plays
   once, and the destination lands on the planned boundary.
2. An 8/16-bar fixture progresses through sparse, build, peak, release, and
   rebuild stages in the declared order.
3. AABA/AACA recipe changes and layer choreography never choose incompatible
   stems or fills.
4. Competing fill requests resolve deterministically to one winner.
5. Save/load and feature interruption resume the same musical future.
6. Native listening QA checks that changes are cohesive and not abrupt.

Run validation, systems/UI suites, determinism coverage, and Jazz Club native
listening QA. After verification, archive this prompt per
`docs/todone/RULES.md`.
