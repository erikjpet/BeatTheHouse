# integ06_1 historical fixture preparation WIP

Status: **PREPARATION ONLY — `integ06_1` is not claimed or accepted**  
Preparation base: `9e8af74b712ed9c3a2bf69f9a330a57719cb0f85`  
Historical source: annotated tag `v0.5.1`, commit
`f1ce7ec814b5034c229f53dcc0db6e799aaaee0b`

## Capture design

`tools/integ06_1_generate_v051_fixtures.ps1` exports the pinned historical
runtime into a disposable directory. It never runs inside or writes to the
preserved detached v0.5.1 worktree. The opt-in historical driver instantiates
the release's genuine `res://scenes/main.tscn` and uses FoundationMain's public
run, gameplay and save boundaries. It does not construct a RunState dictionary
or write narrative, environment, debt, game, tutorial or victory flags.

Every successful fixture receives a sidecar containing the exact release
commit/tree, relevant historical Git blob identities, driver hash, public-call
transcript, and fixture SHA-256/size.

## First smoke attempt

The initial capture reached the real historical SaveService and wrote a valid
schema/version-2 foundation envelope, but the driver failed after that write
while formatting diagnostics:

```text
SCRIPT ERROR: Invalid call. Nonexistent 'int' constructor.
at: _capture (integ06_1_v051_fixture_driver.gd:87)
```

That output was rejected and not copied into the fixture inventory. The fault
was solely in the new opt-in driver: two already-typed RunState properties were
unnecessarily passed through a dynamic `int()` conversion. The conversion is
removed, explicit progress markers and a 90-second in-engine capture watchdog
are now present, and the next smoke rerun remains pending at this checkpoint.

A second pre-fixture attempt exposed an initialization-order bug in that new
watchdog: a SceneTree timer was requested before the tree existed. Its exact
failure was `Cannot call method 'create_timer' on a null value`; no historical
gameplay ran and no output was admitted. Timer setup now occurs on the deferred
capture boundary. The wrapper also owns independent, bounded import/capture
process waits and recursively terminates only its disposable child process tree
if one expires, so even a main-thread stall cannot orphan another capture.

The historical worktree remained clean at `f1ce7ec8` throughout.

## Coverage still required

This checkpoint is infrastructure, not migration evidence. It does not claim
the required 18 archetypes, eight game surfaces, five lender rungs, tutorial
checkpoints, partial scratch state, Grand Casino invite states, victory
thresholds, current-build migration/round-trip, maximal composition, or soak.
