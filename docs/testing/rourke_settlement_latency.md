# Rourke settlement latency

The isolated Web check on `4b043333` completed all five preserved-fixture duel
hands without a Crew package modal, but a screenshot-free fourth-hand probe
recorded a 3,973 ms main-thread task and a 4,074.8 ms frame gap after Stand.
The browser used the supported Playwright `chromium` channel (new headless),
hardware ANGLE/D3D11 on the RTX 4070 Ti, sandboxing, muted output, and the
maintained 12% aggregate CPU / 2 GiB Windows Job limits.

The same fixture through the native Foundation control path took about
1.27–1.32 seconds per settlement. Sealed action resolution accounted for about
0.94 seconds, and delivery preflight about 0.30 seconds. Post-action Crew and
event checks took only a few milliseconds. Full-run authority serialization
repeatedly projected and fingerprinted inactive rooms and the world map.

Rourke now supplies evidence for the current room and every non-world run root,
including narrative, Crew, inventory, balances, RNG, history and terminal state.
Only large `world_map`, `town_state`, and `grand_casino_room_states` storage
are omitted at the source. The proof separately includes room configuration and
the town reputation ledger, type registry, action index and propagation topology:
the taken-out-back ending records a reputation incident. The stored Back Room's
table mirrors the current room already present in the proof. This projection is
never used to save, restore or publish a run. Both executions receive independent
full transaction candidates, including all world models; the ordinary narrow
machine candidate would alias narrative and other collections and is unsuitable.
Scenario-bound and Crew actions retain their full snapshot proof. The room
variant selects the broad Rourke proof even after the last hand clears the
active-duel flags. Canonical serialization and accounting/RNG rules are unchanged.

Focused check:

```powershell
godot --headless --path . --script res://scripts/tests/rourke_authority_evidence_check.gd
```

Set `BTH_DISTRIBUTION_BUILD=1` and an isolated `BTH_DISTRIBUTION_DATA_ROOT` before
running. The check loads the unchanged repository v0.5.1 duel fixture through
SaveService/RunSaveCodec, compares all five hands with the former full-proof
path, compares complete public run snapshots including the world, audits both
executions for unrelated world mutations and exact table mirroring, checks
exactly-once replay and terminal Continue, and injects narrative and reputation
replay mismatches to verify failure atomicity. It uses
real surface intents and the production sealed host, with a verification-only
subclass auditing each proposal. It is native evidence, not Web visual evidence.

The initial isolated native Foundation measurement after the change was about
0.12 seconds per settlement. Final native receipts and the current deployed Web
identity/observations are kept in the task evidence directory. Do not treat the
earlier `4b043333` screenshots as qualification of later user placement changes.

The first deployed `907fb140` Web check reduced hands 1-4 to 382-410 ms
maximum frame gaps, with no Crew package modal. The fifth hand still reached
the correct ending but took 1,947 ms to enter the run report. A focused native
trace separated 205 ms of synchronous saving, 141 ms of report input snapshot,
65 ms of report model building, and 18 ms of screen installation. The profile
ledger also requested a full-world snapshot.

The terminal follow-up retains synchronous checkpoint durability. It passes the
same immutable environment compilations already used by asynchronous autosaves
into the existing codec. Report/profile readers instead receive route geometry,
scenario labels and the heard-rumor ledger, without unrelated machine or
scenario-program storage. The preserved fixture and an explicitly annotated
terminal copy match the full visible report model and profile ledger; only
unrendered map-node environment storage differs. Projection plus model building
takes about 7 ms natively in that focused check. The Rourke authority check also
compares old/new encoded terminal payloads before checking actual save/Continue.
Final Web timing belongs to the task's exact-build receipt, not these native
measurements.

The same native terminal-route diagnostic after this follow-up took about
195 ms total (168 ms synchronous save, 1 ms report snapshot, 8 ms model, 4 ms
screen installation), compared with 587 ms before. No save phase was deferred.

A later two-hand trace on `d5c9c568`, under the same 12%/2 GiB limit, recorded
301.846 ms elapsed / 300.500 ms renderer-thread CPU for the ordinary settlement
task and 742.809 ms elapsed / 742.344 ms CPU for the terminal task. These are
synchronous computation costs rather than animation waits or substantial CPU
throttling. Raw Chromium `dur`/`tdur` events are retained in the task evidence.

The next follow-up opts only Rourke compact evidence into native sorted JSON
encoding after a JSON-shape check, with the historical coercion path retained.
Canonical bytes are compared with the old path in 318 focused cases and at all
five preserved-fixture hand boundaries. Rourke terminal Web checkpoints use the
existing encode/pack/install phases on separate frames; report navigation still
drains pending work and writes synchronously before leaving. Failed checkpoint
installation clears its acknowledgement for retry. Native Web-phase emulation
covers completion, queued/in-flight navigation, and failure/recovery. Native
terminal saving and other games retain their existing paths.

The popup-containing descendant startup receipt proves basic startup only. It
does not visually qualify popup amount accumulation.

Further narrow timing found redundant generic action selection before an already
prepared Rourke settlement. Only the non-tutorial, non-scenario Rourke
`play_basic` settlement now uses the existing direct-command route, carrying the
exact sealed stake; receipt verification, independent full replay and publication
remain in the same resolver. Other actions and tables retain their existing route.
The native sorted encoding also covers the compact proposal input and output,
where the older serializer was still walking the broad Rourke evidence again.

Detached turn snapshots already own their complete TownState/NumbersModel data
and definitions. Restoring a candidate now transfers those owned records instead
of recursively copying each complete wrapper and then its members again. Legacy
publication fallback still copies incoming data; accepted publication retains live
model identities. No state or validation coverage is removed.

`rourke_prepared_surface_route_check.gd` compares a real Foundation Deal/Stand with
the former selection route and serializer: all public state, RNG, balances and
the complete authority ledger/receipts match; the duplicate selection is absent.
Its native fixture input clock is fixed for parity, so it does not qualify Web
animation. `owned_model_snapshot_check.gd` checks legacy value parity, nested
candidate isolation/discard, publication and retained model identities. The
existing five-hand authority, mismatch rejection and terminal save/Continue check
and no-pointer liveness check cover the material adjacent risks. Exact deployed
Web timing and cleanup are recorded separately in the task evidence.

The Rourke Web/nothreads UI now uses the existing finite, per-frame transaction
scheduling pattern also used for event responses. Preparation still publishes the
pending delivery synchronously. Subsequent frames revalidate live authority and
resolve/replay/commit through the unchanged sealed host, consume that committed
result once, construct the terminal report, then release the host owner after a
draw. Canvas animation processing remains autonomous. Input, simulation and
background persistence wait while this one action is pending. Result consumption
does not invoke a second authoritative resolution.
The presentation clock remains live during that transaction pause; other focus
and modal pause owners still pause timed feedback normally.

Save and normal navigation synchronously drain the accepted action before their
existing durable write. Pre-commit cancellation uses the existing pending-delivery
rollback. Rourke stores its cards in both the host ledger and its serialized duel
session; the provider recovery hook now restores both, including after a pending
save is reloaded. A committed settlement is completed rather than undone. Late
callbacks carry a generation guard and cannot affect a replacement action.

`rourke_phased_resolution_check.gd` emulates only the Web selection predicate
natively. It covers full public-state parity at the same completed-action boundary,
separate actual engine frames, repeated input, stale authority, cancellation,
automatic settlement after card animation, and Main Menu/cold Continue on either
side of commit. `rourke_phased_interruption_check.gd` adds terminal money/RNG/duel
parity, delayed report construction, durable terminal navigation, failed Save and
retry, scene teardown, and normal auto recovery of a genuinely persisted pending
delivery. Its save service uses the existing Web encode/pack/install phases.

The next follow-up separates the authoritative proposal work itself: input
sealing/replay candidate construction, accepted execution, independent replay,
live revalidation plus atomic commit, UI result consumption, terminal profile
recording, and report construction run on successive frames. Synchronous callers
retain the same proposal branch and share the extracted preparation/commit code;
the phased proposal path is restricted to Rourke without a native runtime owner.

Pending-delivery publication transfers stored model fields into retained live
objects. Broad replay therefore detaches those models again before speculative
rules execute. This protects intermediate frames and rejected synchronous endings.
The five-hand check now injects a final-hand reputation replay mismatch and
compares every live field with the pending boundary, proving that the rejected
ending cannot leak reputation, terminal state, money or RNG changes. The phased
check also audits live state after every speculative step and cancels at each
pre-commit boundary. The storage codec and save format are unchanged.

Exact-build Web observations on `287aa0cc` put the action-related renderer tasks
within the first 500 ms of Stand at at most 80.9 ms thread CPU. Later autosave
tasks still reached 145–155 ms CPU. A narrow native component probe found that
unchanged inactive rooms dominated the codec's remaining recursive encode walk.
The existing bounded immutable room compilation now retains its encoded form
when the graph contains only plain containers and scalar values. Each save gets
a native deep copy before registry compaction; packed mutable leaves retain the
original explicit-copy path. Encoded storage counts against the same 4 MiB
admission budget, and exact source equality still controls invalidation.

`inactive_storage_encoding_check.gd` compares exact JSON bytes with the original
uncached projection and audits nested output mutation, alias invalidation,
rollback, cold restore, packed fallback and cache-budget refusal. On the preserved
fixture, native encode time was approximately 15 ms versus 26 ms without encoded
compilations. This is native component evidence; final Web timing is recorded
separately. Compressed-save parsing also returns its already private fresh JSON
graph directly, avoiding one redundant full copy. Storage content/hash validation,
legacy integer repair, atomic installation, backups and format remain unchanged.

The content-only save validator skips legacy ledger integer-token repair: it
still decompresses, checks the exact source hash, parses JSON and requires the
same root fields. Only actual loads need the repaired numeric identities and
retain the default repair path. The storage check explicitly covers an intact
legacy 64-bit authority integer, real-load precision, damaged content and missing
root fields, alongside the existing atomic-failure and retry cases.

A subsequent root-level snapshot probe found that rebuilding the one stored
casino room cost about 13.6 ms of a 15 ms native capture. Inactive casino rooms
now use the same immutable projection/encoded compilation and total admission
budget as stored world rooms. World pruning and casino pruning retain each
other's entries; removed or active casino rooms release their inactive entry.
Cold restore primes both sets before gameplay. Normal full snapshot callers
still receive the original dictionary projection. Exact JSON parity and source
alias invalidation, prior-generation isolation and removed-room release are
checked by the same focused encoding contract. Native capture on the genuine
hand-three save falls to about 2.1 ms, with no state or format reduction.

The remaining ordinary Web save-install interval reached 109 ms renderer CPU on
`9a1a733b`. A diagnostic copy of the exact durable writer, using the genuine
hand-three save, measured about 55 ms natively for a known primary: approximately
51 ms in temporary-generation validation, versus 1–2 ms for rotation/install and
less than 1 ms for each digest check. An unknown primary correctly receives an
additional full validation. The writer's durability/rollback code is unchanged.

A browser-parser experiment (0faaeb34 through 6444bd0c) did not reduce the
remaining interval and is removed. Native Godot JSON acceptance remains unchanged.
The existing Web save job instead separates decompressed-byte/hash validation,
JSON/root validation and final atomic installation into individual frames after
packing. Only after both content stages succeed does it retain a private copy
of the exact compressed envelope as a validation proof. The durable writer still
reads/parses the actual temporary file and verifies installed bytes; its validator
reuses the proof only for the identical envelope. Changed or unknown content,
including a different old primary, takes the original full content validator.

The encoded generation remains owned before the first yield. Save/navigation
drain the bounded remaining phases; acknowledgement still follows successful
atomic installation. No temporary file is created by prevalidation, so failure
or raw teardown before install leaves both durable generations untouched.
The phased-save check covers exact bytes, distinct engine frames, mutation after
byte validation, corrupt content/JSON, unknown-primary validation, failed install,
retry and extra drains. The native JSON corpus retains malformed grammar,
numeric/Unicode/depth and content-hash cases, including genuine saved states.
In the same genuine native saved-state diagnostic, the actual production writer
took about 53.4 ms with full inline validation versus 13.4 ms with the exact
prevalidated envelope. This excludes the validation already performed on prior
frames; total save work is preserved. Both installs returned the digest of their
actual installed bytes. Final Web timing is recorded separately.
