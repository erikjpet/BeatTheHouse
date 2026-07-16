# Agent Prompt - Dave Bus Encounter: Cruel and Unusual

Copy everything below this line into the implementing agent.

---

Add a one-time Dave encounter when the player travels by bus in
`D:\Projects\Beat-The-House`. Keep this independent from the audio slices,
although it is last in the meeting-notes execution sequence.

## Existing seam

Travel completes in `scripts/ui/foundation_main.gd`, which enqueues triggered
events using the previous environment and a travel context. World-map travel
already exposes a human-facing method such as `Walk`, `Bus ticket`, `Taxi
ride`, or `Night cab`, but the current triggered-event context does not carry
a normalized method. `EventModule` already supports `trigger.type = travel`
and `conditions.requires_context`.

Audit the current code before editing; keep the implementation data-driven.

## Deliverables

1. Add a canonical, stable travel-method kind (`walk`, `bus`, `taxi`, or
   equivalent) to the route/choice result and triggered-event context. Derive
   UI display copy from the same source so logic never compares against the
   literal label `Bus ticket`.
2. Ensure every route keeps its current travel behavior and copy unless its
   normalized method is explicitly authored/derived.
3. Add a triggered talk event with stable ID such as `dave_bus_warning`:
   - eligible only after a completed travel whose normalized method is `bus`;
   - presented through the existing talk/triggered-event pipeline;
   - speaker name `Dave`, with a suitable existing stranger silhouette unless
     a Dave portrait is already present;
   - Dave tells the player exactly: `Seek out the cruel and unusual.`
   - one acknowledgement choice with no invented reward or penalty;
   - sets a stable seen/story flag and writes a followable story-log entry.
4. Make the meeting one-time per run. Repeated bus rides do not enqueue it
   after acknowledgement, including after save/load.
5. The first eligible bus ride should reliably trigger Dave unless an active
   modal must finish first; in that case queue Dave safely and show him next.
   Do not make this key direction depend on an unseeded random roll.

## Tests and acceptance

1. A local-distance `Bus ticket` route enqueues Dave; walk, taxi, and night-cab
   travel do not.
2. The event shows Dave's name and exact sentence through talk presentation.
3. Acknowledgement sets the seen flag/story entry and resolves cleanly.
4. A second bus ride does not repeat Dave.
5. Saving before resolution preserves the queued/active encounter; saving
   after resolution preserves its one-time status.
6. Existing travel costs, risks, suspicion decay, destination generation,
   and event cadence remain unchanged.
7. Project validation, systems/UI suites, and relevant travel determinism
   coverage pass.

After verification, archive this prompt per `docs/todone/RULES.md`.
