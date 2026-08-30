# world06_4 host-rooted recovery

## Candidate

- Exact base: `adbc0b6804e295bf38e84f3fa6a1dc057135c650` (`world06_3` frozen candidate).
- Branch: `codex/finish06-world4-recovery-adbc`.
- Worktree: `C:\bth-finish06-world4-recovery-adbc`.
- Recovered source: the complete `world06_4` proposal/data package through
  `4a5be2b154bf579257feb1475b910b79be01f9af`, already present in the exact base.
- Approved ruling: Option A, extending the recovered proposal package with a
  RunState-owned host boundary. No job, recruitment, Numbers, delivery, or
  world execution was rebuilt.

## Preserved authored contract

- `data/crew/jobs.json` and `data/crew/recruitment.json` are byte-identical to
  the exact World 3 base.
- The catalog still contains exactly 13 jobs, all seven members, and the six
  shipped kinds: `package_delivery`, `package_run`, `numbers_route`,
  `lookout_hold`, `stake_horse`, and `collection`.
- Every expiry, payload, reward, failure, trust, grievance, heat, and authored
  semantic verb remains unchanged.
- Delivery-shaped work still executes through the landed delivery host;
  Numbers work still consumes the landed Numbers APIs; game settlement still
  enters through the shared game-result seam.

## Authority closure

- `job_offer`, `job_accept`, `job_activate`, and `job_resolve` now require the
  owning RunState's non-serialized `RefCounted` capability. Direct calls return
  an empty result and cannot mutate job sequence, jobs, cash, trust, grievance,
  or heat.
- The job board and member-contact surface remain the player entry points.
  They validate current physical presence and rank, then the host creates and
  activates the immutable catalog definition.
- Recruitment no longer accepts direct member promotion. EventModule supplies
  its exact resolved action result while the event is still mounted. RunState
  derives the member, primary/fallback placement, and refusal/deferral/
  acceptance outcome from trusted content and the current environment.
- Recruitment history is canonical, sparse, and durable. Acceptance is terminal
  and replay-safe; refusal and deferral remain distinct public actor aftermath.
  Contact standing is derived from current trust, active jobs, and the private
  grievance ledger without exposing ledger fields or Turn eligibility.

## Recovered execution coverage

- Package and route jobs retain real pickup, travel, multi-stop, hold, and
  handoff execution.
- All three stake jobs retain stake handover, named venue/game evidence,
  witnessed win/loss, and repay/shrug aftermath.
- Both collection jobs retain real-map travel followed by friendly/press
  resolution, including their distinct cash and heat effects.
- Expiry, delivery failure, abandonment, and completed outcomes converge on the
  capability-gated settlement seam, whose resolved status makes configured
  effects exactly once across repeated calls and save/load.
- Layer 3 residency, job board filtering, service occupancy, Rook's ride,
  Mags' bench, Numbers desk, planning table, and Practice Rig remain the landed
  implementations.

## Evidence

- `tools/validate_project.ps1`: PASS twice (`65.8s`, `64.7s`).
- `git diff --check`: PASS.
- Authored Crew job and recruitment data versus exact base: no diff.
- Static catalog audit: `JOB_COUNT=13`; all seven member ids; all six shipped
  kinds.
- Focused tests cover all 13 host starts, direct lifecycle rejection,
  refusal-to-acceptance history and save/load, Bishop deferral, replay-safe
  trust, delivery/stake/collection execution, and hidden-state projections.
- Godot execution is serialized by Warden and remains pending there; this lane
  did not invoke Godot.

