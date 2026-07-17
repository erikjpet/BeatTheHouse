## Execution Record

- Completed: 2026-07-17
- Implementation: `af81e057`, integrated by `a94f338d`.
- Verification: the adaptive-tempo probe passed, covering heat mapping, bounded slew, hysteresis, live musical boundaries, phase alignment, and save/restore state; systems checks also passed.
- Deviation: web uses fixed authored tempo. Native Steam/mobile uses the adaptive, pitch-preserving shared transport as required.

# Agent Prompt - Jazz Audio 3: Native Heat-Driven Adaptive Tempo

Copy everything below this line into the implementing agent.

---

Implement true, subtle, native adaptive tempo for synchronized authored
stems. This depends on the Jazz delivery and harmony-safe arrangement slices.

## Goal

Casino stakes should have a natural musical climb. Heat raises tempo and
falling heat lowers it, but movement is gradual enough that most players feel
increased or decreased urgency without consciously hearing a tempo jump.
Each venue owns its range: low-stakes rooms stay near the lower end; premium
casinos can operate higher. The lowest authored baseline across the game may
start around 100 BPM.

Jazz Club is the first implementation. Use a data-driven initial profile
centered on its established 120 BPM identity (initial test range may be
approximately 116-124 BPM), with all values plainly tunable after engineer
listening feedback. Do not hard-code that range into the transport.

## Tempo profile

Add per-track/per-environment metadata for at least:

- base, minimum, and maximum BPM;
- heat-to-target curve;
- maximum BPM change per second or musical bar;
- attack/release smoothing and hysteresis/deadband;
- optional high-stakes/low-stakes classification;
- whether tempo adaptation is enabled for the track.

## Native transport requirement

- Implement actual playback-tempo change for native Godot targets. Do not
  substitute drum density, layer intensity, or a fake BPM display.
- Preserve musical pitch while tempo moves. Use an appropriate native
  time-stretch/pitch-compensation path; if built-in processing cannot keep
  parallel stems sample/phase aligned, implement a shared native transport or
  decoder that can.
- All stems use one authoritative tempo ratio and transport clock.
- Beat/bar/phrase calculations, stingers, fills, outcome events, and big-win
  bar envelopes follow the live tempo, not the original static BPM.
- Rate changes must not restart a loop, scramble arrangement history, or
  create stem flamming.
- Web may keep fixed tempo or a documented lower-cost fallback, but it must
  not weaken native behavior.

## Runtime behavior

Heat updates set a target only. The audio process slews toward it continuously
within the configured limit. Rapid heat oscillation must not make tempo pump
or repeatedly reverse. Moving from high to low heat is as deliberate as
moving upward.

Expose the current BPM, target BPM, ratio, slew direction, source heat,
profile range, and transport beat/bar/phrase in a zero-copy-friendly debug
snapshot.

## Tests and acceptance

1. Heat 0, 50, and 100 map monotonically inside the Jazz profile range.
2. A large heat jump cannot exceed the configured slew rate.
3. Falling heat returns smoothly and respects hysteresis.
4. Parallel stem phase error stays below an explicit tiny tolerance through
   a long ramp up/down test.
5. Phrase changes, fills, one-shots, and a four-bar big-win envelope land on
   the correct live-tempo boundaries.
6. Save/load restores the target/current tempo and deterministic next musical
   boundary without an audible jump beyond documented tolerance.
7. Native listening QA checks low, rising, high, and falling heat with pitch
   stability and headphones for flamming/artifacts.

Run project validation, systems/UI tests, the determinism probe, and a native
audio stress fixture. Record the tested Godot/native processing choice in the
delivery contract. After verification, archive this prompt per
`docs/todone/RULES.md`.
