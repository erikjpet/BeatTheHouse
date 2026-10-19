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
