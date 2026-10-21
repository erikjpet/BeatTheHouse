# Room catalog publication: action-freeze correction

Status: focused native ownership/parity checks, no-pointer animation and a real
Web offer plus normal Save/Continue pass. Main/NEXT publication is pending.

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
point on the same click. The contextual Web comparison below measures the work
removed and the remaining action/save blocking separately.

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

## Real Web qualification

The same preserved six-file pre-offer fixture, visible Take the cash selection,
engine/native pins and action/canvas/save marks were used in both cases. Full
hardware Chrome ran muted in a private profile under a 12% CPU / 2 GiB Job.
CPU readings were telemetry only. These are one-pair contextual observations
under different background load, not a statistical benchmark.

| Observed phase | Control | Candidate |
| --- | ---: | ---: |
| Catalog compilation / publication | 241.420 ms | 20.240 ms |
| Model / validated commit | 91.435 ms | 157.490 ms |
| Input to callback completion | 384.225 ms | 227.000 ms |
| Input to engine frame submission | 413.145 ms | 254.905 ms |
| Longest browser task | 411 ms | 253 ms |
| Save snapshot plus dispatch | 179.565 ms | 178.020 ms |
| Input to save completion | 606.005 ms | 633.570 ms |

Frame submission is not proof of compositor presentation. Actual state-boundary
validation/publication remains visible in the model cost; the removed catalog
work was not merely moved in full to that boundary. Synchronous save work is
unchanged and remains a separate long task. This does not establish freeze-free
input, faster save completion, or general improvement across every room.

Both actions apply once with cash 115, heat 8 and one turn. RNG/seed, physical
geometry, manifest and semantic/layout authority match. Each case's normal
engine reload/Continue preserves all six saved files byte-for-byte. Across the
two independently timed Web runs, the full canonical comparison lists four
differences: game_clock_minutes, the latest heat-history clock, music source
position and music transport beats. None are silently excluded.

The observed input clocks are 992 and 923, respectively, and each action's heat
record uses exactly its observed input clock. The candidate's saved clock is
924. Foundation's unchanged frame clock accumulates 1.5 game minutes per real
second and runs before pending autosave in _process; the candidate save capture
starts 443.645 ms after input. A fractional minute crossing on that intervening
frame is the source-supported explanation for the extra saved minute. The exact
clock tick was not instrumented, so this is an inference, not direct tick proof
or exact cross-run Web byte parity. The unchanged clock routines and the native
fixed-input action's exact full saved bytes provide separate correctness
evidence; this limitation remains explicit.

Control host samples during observation ranged from 22.0 to 33.0%, candidate
12.7 to 46.5%; owned Job observations were 6.3 to 8.1% of the 16-processor host,
under the retained 12% quota. No CPU threshold aborted either completed case.

The earlier MAX_PATH/Node ENOENT setup failures remain preserved. Reusing the
installed pinned engine through the deployment helper's typed PowerShell call
in the approved execution context recovered import/export without a download,
toolchain rebuild or archive deletion. The audited candidate PCK is 46,744,512
bytes, SHA256 01f74679c804b18d940b51ce29c5bb77d12213f5744ada43c5ac46bd10b8d374.
The exact underlying OS cause of the earlier direct Node spawn failure remains
unattributed; it no longer blocks qualification.

Evidence is retained in task-2/web-regression/room-publication/real-web-comparison.json,
the two completed room-publication Web run directories, and the warm-export
audit/closure receipts. The candidate browser closed at 17:39:35 UTC; independent
17:40:47 census found all 18 recorded browser/helper/supervisor IDs absent and
port 8096 closed in both address families. Failed pre-game/point-timeout attempts
are retained separately and contribute no action-performance claim.
