# Gas storm-shelter scenery loss: fresh native reproduction

Open investigation. Source 0eee2e05, runtime identical to deployed 0b6f18a8.
Normal seed CLOSE061-NORMAL-A, start in Back Alley, select Gas Casino and
confirm travel through public host methods; wait for ordinary cinematic arrival.
No scenario pin, original save modification, fake geometry or test-only event.

Fresh storm room has eight scenario objects. Public Parking Lot Tip / Follow
the tip succeeds but leaves only driver/family objects (2). Public Save, close
app, reopen and Continue succeeds but leaves zero scenario objects. Cash93
remains unchanged. Fourteen explicit scenery assertions fail. Classification:
current native production-path reproduction; precise phase/authority cause
under investigation, not yet a new fix. Browser/WASM appearance not retested.

The separate existing captured-storm cold Continue contract passes: nine
required objects and strict damaged-geometry rejection. Its coverage does not
cover this freshly generated event-then-Continue state.

Raw evidence: E:/CodexQA/BTH/runs/next-bugfinder-storm-20261115-02/evidence.
Guard exited1 from assertions, no timeout and active_at_release0. Probe source
is in next-bugfinder-ledger-20261115-10/evidence/storm_tip_probe.gd.
First run01 did not travel from initial Back Alley; marked not reached, not
a storm pass. No product changes have been made.

worker.log SHA256: b51867c27ed9320edfa4fe214434f4f04907c8675b8f2a9f95454c48ab26a689

job.json SHA256: 7e4c06dd1f17b9a3c40e25788c34fa054610dfe1f2e339b5e1d9a86e3ae12022

## Classification refinement: explicit expiry, not generic save loss

Run03 proves complete strict authority remains valid throughout. The sequence
changes from active/unexpired to cleaned/expired immediately after Follow the
tip, recording expiry:town_action with progress1. The shipped storm definition
explicitly declares expiry after1 town_action with cleanup and removes all
scenario props and actors. This matches the six missing props; two actors linger
until Continue. The legacy storm heading remains unchanged. Whether that
one-action authored lifespan is intended is a content/design question, not
permission to loosen validators or change scenario timing.

Control04 repeats the same normal seed/route but omits the event before Save.
Active scenario objects remain8 before Save and8 after cold Continue; original
captured-storm contract and damaged-authority rejection also pass. Exit0, no
timeout, active_at_release0. Therefore initial14 failures show a mismatch with
our assumed persistence expectation; they are not proof of save corruption.
Remaining investigation is the live-versus-restored actor presentation after
authorized cleanup and potentially stale storm shell. Reviewer assigned to
/root/fix_gas_storm_scene. No content or product edit made.

Final bounded observation (run06): both retained actors are explicit departure
transits. After4 seconds actor_route_time=12.3717, ends_at=16.0154 and16.1957;
initial time=8.1957. They have not reached their normal8-second departure ends.
Continue correctly has no active transits or cleaned actors. This is not a
confirmed live-versus-save mismatch. Independent review agrees the authored
expiry explains disappearance. No runtime fix is indicated by this investigation.
Original rendered report remains open for owner-facing content/lifespan review;
no scenario timing, geometry or progression changed.
