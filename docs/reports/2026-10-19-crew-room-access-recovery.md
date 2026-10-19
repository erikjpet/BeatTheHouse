# Crew Back Room access and recovery — 2026-10-19

User report: entered Crew Back Room without credentials, then saw an empty room
with no objects or exit. No user save was read, modified, or reset for this fix.
The named room maps to The Punchline's back_room layer in the authored catalog.

Confirmed access defects:

- The shipped private-door path explicitly allowed `stranger` rank.
- Remembered discovery bypassed all credential checks, including stale saved doors.
- The canonical Crew config requires Made standing (`layer_3_min_rank`, currently
  60 trust); the older environment migration hardcoded Associate instead.

The door now follows canonical Made standing or the existing Rook escort flag.
Both current and saved door snapshots upgrade their access policy; discovery
remains remembered but cannot grant private access. Denied authoritative actions
leave the run unchanged. No credentials or trust are granted.

The exact empty-room cause remains unconfirmed. Production-fidelity runs at
seeds WAVE-B-COMPOSITION-08, PUNCHLINE-L3, and CREW-REPRO-1 showed 11 normal room
records, including the casino door and Leave, immediately on entry and after
cold Continue. Reproducing the original empty view still needs its seed/save or
specific entry sequence; a synthetic rejected envelope is not claimed as that
reproduction.

Protection and recovery:

- Interior installation seals final Crew membership and validates the private
  room's authored exit/slot proof before publishing it; failure rolls back.
- If the rendered private room lacks its usable casino door, a separate
  `Room unavailable - Return to casino` control appears outside room geometry.
- Recovery returns only from that private room to its existing saved casino.
  It validates the destination through normal scenario, manifest and slot rules.
  It preserves the exact rejected private-room payload in layer_states, cash,
  inventory, clock and RNG. Missing/invalid parent state retains the active run.
- Recovery reports what happened and saves only after successful recovery. It
  does not regenerate loot, grant access, reposition hitboxes or reset progress.

Validation: existing `punchline_layer_contract.gd` passes with focused additions
for stranger denial, exact 59/60 Made threshold, discovered/legacy-door denial,
legitimate escort, cold-save exit, rejected-envelope recovery retaining exact
payload/economy/clock/RNG, and missing/invalid parent rollback. Separate headless
Foundation UI compile/predicate check passed: missing/rejected exit enables
recovery, valid exit does not. `git diff --check` passed.

Actual deployed NEXT verification is coordinated by the integrating site owner
and is separate from these source/headless checks.


## Continue-path follow-up

A separate clean, isolated fixture exposed a concrete empty-room class at the
actual `load_foundation_run()` boundary: seed `CREW-CONTINUE-REJECTED`, Rook Made
standing at exactly 60 trust, Punchline Back Room. This deliberately established
standing fixture is not claimed to be the user's original save or entry path.

The saved room's derived placement hints did not describe the Crew contact
records now produced by the current catalog. The loaded envelope initially
validated, but live contact records `crew_contact_rook` and
`recruitment_rook_leads` lacked manifest family/binding annotations; the strict
live binder rejected the entire room presentation. Refreshing the derived
physical envelope with the trusted current ContentLibrary before publishing the
restored screen restores those records to existing authored event-reserve slots.
It does not change gameplay arrays, payout rates, credentials or save progression.

Actual SaveService + Foundation Continue verification in isolated persistence
roots succeeded: SCREEN_ENVIRONMENT/back_room, cash $141, valid room records and
casino exit, recovery button hidden. Cash, inventory, game clock and RNG were
all identical before and after Continue. Evidence remains local in
`crew-continue-final.log` and the isolated slot under
`state/bth-next/crew-continue-clean-data`; no personal save was used.

Remaining fallback limitation: fault-injected rejected geometry after Continue
shows the recovery control, but a saved casino parent with the
`punchline_high_stakes_night` immutable semantic baseline can itself fail strict
validation: that baseline's captured rectangles omit Crew contact identities now
required by its physical manifest. Direct saved-parent validation also fails.
The recovery action correctly rolls back and preserves the active run instead
of bypassing semantic validation. The general callback is therefore not claimed
as verified for that parent state. Resolving it requires a separately justified
semantic-baseline compatibility correction; this follow-up does not alter or
silently reseal immutable scenario authority.

The integrating owner separately captured an ordinary Gas Station web save.
Actual native Continue of those exact bytes renders its games, scenario objects,
Nell and Leave with no geometry rejections and $93 preserved. The owner confirmed
that the browser view becomes populated after its initial presentation delay.
That case is not evidence for the Crew binding defect.


## Strict old-baseline compatibility correction

The preceding fallback limitation is resolved for the preserved affected parent.
Its immutable sequence `semantic_state.target_inventory.scene_objects` already
contains `event::event:crew_contact_rook`, `event::event:recruitment_mags`, and
`event::event:recruitment_rook_leads`. Only the derived baseline rectangle hint
omits them. The prior finalizer treated that incomplete hint as the entire
physical membership list, conflicting with its already-sealed scene inventory.

The correction reconstructs the detached proof's rectangle hint for recognized
Crew event identities only when the Punchline casino's persisted inventory
version/digest and sequence reference agree. Coordinates come from current slot
bindings and trusted catalog generation. It leaves the stored baseline hint,
semantic target inventory and reference unchanged; the existing full manifest,
slot, semantic inventory and exact original digest validation still runs. A
catalog-aware contact binding refresh precedes parent finalization during
recovery. No semantic error is ignored, no new inventory target is added, and
no scenario is restarted.

Preserved fixture: `CREW-CONTINUE-REJECTED`, Rook Made at 60 trust, parent
`punchline_high_stakes_night`. Direct parent finalization succeeds as a replay
with original digest
`bbe8a40c6a476a575e5e2af68d46758e100890a8dd8dad87bfb9686c1f18d300`.
Actual JSON SaveService Continue then deliberately rejected active-room geometry
shows the separate recovery button. Its real Foundation callback succeeds and
returns to casino. Cash, inventory, clock and RNG remain identical; the parent
semantic digest and full progression/receipt state (excluding derived semantic
state) remain identical; the exact rejected Back Room payload remains retained.
This actual callback run includes the final strict integer/string/reference-hash
gates in production code. Evidence: local `crew-parent-supplemented.log` and
`crew-continue-recovery-compatible.log`.

The unchanged existing focused Punchline contract passes, including its existing
missing/invalid-parent rollback checks. Automatic approval review rejected
adding the requested new compatibility negative cases to that contract because
of the standing hold on extending game tests/fixtures/validators/harnesses.
Accordingly, newly proposed tampered-reference, missing-reference and removed
sealed-contact regression cases were not added or run. Explicit human approval
to override that hold is required for those test extensions. The strict helper
and unchanged final digest rejection were reviewed in source; additional terminal
state variants were not newly exercised. Existing evidence proves preservation
of the active parent's complete progression/receipt state.
