# Room catalog publication: action-freeze correction

Status: private candidate. Focused native checks and no-pointer animation pass;
Web response qualification and production publication remain blocked.

The regression bracket is 0.5.1 to 0.6.0. Commit
202a25663de754f0dc8cdb9d43fe24f3396a5bd3 introduced scenario finalization during
catalog construction. Later physical/semantic checks made that read path much
more expensive. A current Web trace measured about 149 ms in the controller's
scenario finalization/projection phase. This is an architectural lead, not a
claim that one historical commit alone accounts for every observed stall.

## Ownership and authority

- RunState owns a runtime-only detached room publication. Its constructor copies
  the committed environment and proof; getters copy every exposed container.
  Opaque game buffers are excluded. The publication is not saved.
- Replacing the room invalidates the publication. Accepted scenario operations,
  physical membership reconciliation, finalization and consumed-event binding
  release publish after their existing validation. World-sequence writers
  explicitly invalidate and retain their existing composed compiler at the next
  owner refresh. This candidate claims no world-sequence optimization.
- The scenario engine already authenticates causal state and produces a sealed
  projection/layout during its real command/fact commit. Normal catalog display
  consumes that committed product instead of rebuilding its immutable baseline,
  rebinding physical records and finalizing the scenario again.
- Foundation publishes a detached render catalog at its owner refresh. Catalog
  getters only return owned copies. Selection/hover decoration cannot prepare,
  bind, finalize, repair, or mutate the room.
- Character-offer synchronization/selection occurs at owner refresh and actual
  clock/background-state boundaries. Prepared view and presence lookups are
  read-only; the existing action-facing model APIs remain compatible.
- Legacy live room aliases remain owned by their established modules. A display
  snapshot never authorizes an effect. Event/scenario ingress and physical room
  dispatch validate the live envelope. Existing game ledger/settlement authority
  is unchanged. A retained mutable alias cannot use an old display proof to
  authorize changed slot geometry.
- Lifecycle and detached-turn rollback retain the immutable publication pointer;
  restore installs it after mutable room roots. UI catalog caches are also
  restored with the lifecycle image.

The reviewed game presentation entry points retain their established preview
contracts: Slot uses an owned machine view, Scratch and Coin Pusher request
nonpersisting projections, Pull Tabs uses its read-only portable merge, and the
card/dice tables return detached previews. These functions do not install physical
room membership during catalog preparation. Game runtime commits still refresh
live presentation through Foundation's explicit runtime refresh. This review
does not turn legacy internal room aliases into public immutable objects.

The old UI base binder also removed scenario-owned occupants from the base
layout. That ownership cleanup now happens at publication after incoming proof
validation, followed by unchanged strict validation of the candidate. Scenario
geometry remains in its sealed scenario authority. This preserves persistence
without requiring a view request to clean up duplicate base-plane bindings.

The work removed is the second baseline/layout/finalization pass formerly reached
from a catalog request after the scenario command had already committed its
projection. The real command/fact finalizer and live action validation remain.
Owner refresh still gathers current labels/availability and joins them to the
committed physical proof; it does not move the entire old finalizer to another
point on the same click. Actual savings have not yet been measured for this
candidate.

## Focused evidence

Private genuine pre-offer fixture and authority companions were preserved.
Initial saved-state comparison found four extra scenario bindings; that candidate
was not accepted. The corrected native action produces the exact baseline primary:
143,338 bytes, SHA256
0cac99f09b88c48f33efd89f4328fd7d8d2b15c5b7ccb16528ec548044bb5db2.
There are zero state, metadata, clock or music differences. Cash/heat, action
count, RNG, manifest, slot geometry and semantic/layout digests match.

Focused checks cover detached outputs, read purity, room replacement, lifecycle
rollback, live slot tampering and rejection without effects/healing. The genuine
offer applies exactly once and the normal saved primary loads. These are native
functional checks, not Web latency evidence. The required no-pointer animation
check passed separately on the candidate at 17:14:53--17:15:01 UTC in the existing
12%/2 GiB contained Job. It exited naturally; the independent 17:15:42 census
found all six recorded IDs absent.

The rejected validation-on-every-lookup prototype remains on
codex/compiled-scenario-host-20261021, final record ae4400cd64c00dac022b3b86b43ce33b0b673d07.
It is not part of this candidate.

## Remaining qualification

Use the existing private genuine-action Web recipe, finite 12% CPU/2 GiB Job,
muted audio, private profile and exact cleanup. CPU is telemetry, not an abort
condition. Record actual callback/frame submission and browser long tasks;
distinguish frame submission from compositor presentation. Keep synchronous save
capture/dispatch separate: the earlier Web sample measured about 181 ms there,
and this change does not alter the save pipeline. Do not claim a freeze-free
result or a Web improvement from native timings.

The private export is concretely blocked before the engine starts. After a first
MAX_PATH extraction failure, the shortened second run archived and extracted the
exact f134 base plus the pinned candidate/action-mark overlay successfully. At
17:04:54 UTC, Node returned `spawnSync ...Godot_v4.6-stable_win64_console.exe
ENOENT` with PID 0 at import. The executable had passed its SHA256 check and
remained present afterward. The cause of the process-creation error is not yet
attributed. No Godot import, PCK, browser or candidate Web action resulted. The
supervisor reported Job0/no force/errors, and an independent 17:13:01 census found
all six recorded process IDs absent. The failed archives, overlay proof and logs
remain retained for the working deployment route; no production push is justified
by the native checks alone.
