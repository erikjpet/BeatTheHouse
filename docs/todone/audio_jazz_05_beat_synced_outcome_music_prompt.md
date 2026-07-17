## Execution Record

- Completed: 2026-07-17
- Implementation: `92e0a971`, integrated by `a94f338d`.
- Verification: the Jazz outcome probe passed, covering live-tempo quantization, event-token deduplication, cooldown and voice limits, controlled per-stem reverb pulses, and the four-consumed-bar big-win envelope; systems checks also passed.
- Deviation: fixture cues prove scheduling and routing only; the engineer will supply and approve the production accents.

# Agent Prompt - Jazz Audio 5: Beat-Synchronized Outcome Music

Copy everything below this line into the implementing agent.

---

Make game outcomes part of the music for the Jazz Club vertical slice. This
depends on the live-tempo transport and phrase/layer scheduler.

## Goal

Wins, losses, jackpots, and important reveals should feel performed by the
band. Musical accents and short reverb movement land on the active beat grid
instead of firing as unrelated sounds over the song.

## Outcome event contract

Introduce one explicit director event API for gameplay outcomes. It receives
at least a stable event token, outcome class, magnitude/tier, source game,
result time, and optional requested quantization. It returns or exposes the
scheduled musical time/boundary so visual result presentation can align when
appropriate without delaying authoritative game-state resolution.

Support at least:

- small win;
- loss;
- big win/jackpot;
- feature start/end;
- neutral or push (normally no accent unless authored).

Deduplicate stable event tokens so UI refreshes cannot replay an outcome.
Keep the existing true four-musical-bar big-win envelope, cooldowns, and voice
limits.

## Musical synchronization

- Quantize authored stingers and effect envelopes to live tempo: next beat,
  half-bar, bar, or phrase as declared by cue metadata.
- Prefer the nearest musically safe subdivision with a strict maximum latency
  for ordinary actions. Never make controls feel blocked while waiting for a
  cue.
- Give result animation/view-model code access to the scheduled boundary for
  optional synchronized flashes, count-ups, or reveals.
- Slot-feature musical events use the same director path, not a disconnected
  SFX music sampler.

## Controlled reverb pulse

Implement win/loss reverb as a short beat-counted envelope on selected
instrument sends or the cue voice. Do not open a shared permanent reverb over
the complete mix.

Metadata must control attack beats, hold beats, release beats, peak send,
eligible roles, outcome classes, and cooldown. Clamp/normalize overlapping
events so repeated wins cannot accumulate into a washed-out song. Losses may
use a distinct, subtler/darker pulse supplied by the engineer.

## Jazz fixture

Add non-production fixture definitions for a small-win accent, loss accent,
and big-win accent with different quantization and controlled send envelopes.
Do not fabricate final engineer audio.

## Tests and acceptance

1. Outcome cues land on the declared boundary at both static and changing
   tempo.
2. Duplicate UI snapshots/event tokens play exactly once.
3. Repeated rapid wins respect cooldown, voice cap, and maximum reverb send.
4. The reverb envelope returns to baseline after its musical duration.
5. Big-win intensity lasts four consumed musical bars, including through a
   tempo ramp.
6. Gameplay state resolves immediately; optional visuals may synchronize but
   input is not held for excessive audio latency.
7. Native listening QA confirms cues feel embedded in the Jazz performance
   and the underlying song remains clear.

Run validation, systems/UI suites, outcome-flow tests, and native listening
QA. After verification, update the engineer contract and archive this prompt
per `docs/todone/RULES.md`.
