# Crew package appointments and solicitation cadence

Regular Crew favor, board and member-contact courier jobs share one active
delivery slot. Acceptance checks this slot before creating a job, so repeated
choices and alternate sources cannot replace cargo or charge a second failure.
The UI retains the advertised quote through selection and acceptance while the
normal game clock continues. Existing scripted heist, lookout and collection
mechanics retain their separate authored behavior.

Each courier stop has an absolute `[opens, closes)` appointment: the opening
minute is valid; the closing minute is late. A stop lasts 30 game minutes.
The first opening is rounded up to the next half hour after the greater of
150 minutes or walking travel time plus 30 minutes. A later stop opens after
the previous close, walking time and another 30-minute allowance. A complete
window must fit the destination's existing hours; otherwise it moves to the next
opening. Hidden routes use the real graph distance. One generated check offered
the counter clerk at Store, **Day 1, 2:30 PM–3:00 PM**.

Offers identify the contact, destination, day, opening and closing time before
acceptance. The package strip and map retain this information. Early arrival
explains availability; both direct and sequence-owned handoffs enforce it.
Normal clock advances, travel and service time skips can expire a missed stop,
including across midnight and before a later stop's deadline.

Consequences remain authored: no reward, the owning member's existing trust
loss and grievance, plus any event failure Heat. The favor retains trust **−5**,
one existing grievance and **Heat +9**. Successful favor delivery retains $22,
Heat +4, the existing trust reward and clearing one favor. Existing delivery
resolution/checkpoint authority applies rewards and failures once. The failure
message remains visible in the package strip and story history.

Unsolicited favor calls occur at most once per **six game hours**. The saved
cooldown starts on enqueue and is renewed on acceptance or rejection. Quiet
visit bypass no longer bypasses this gate. Explicit requests for optional board
work remain possible when no route is active. Showdown pending/active state
(including Rourke's duel), heist setup/play/interview/getaway, closing-time
sequences, other active triggered encounters, tutorials and terminal runs reject
solicitation before event construction/choice projection. Old queued calls wait
outside incompatible scenes. Accepted-route saves retire stale offer entries.

Only active legacy regular courier assignments without appointment data migrate:
they retain targets/cargo/job identity and receive one fresh feasible appointment
from the restored game clock. Loading never charges a miss. The appointment is
saved, so another Continue cannot extend it. Resolved receipts never migrate or
repay/reapply consequences. Existing save/private-authority conventions remain.

## Focused evidence

- `scripts/tests/crew_package_windows_check.gd`: generated real-map walking and
  event acceptance, quote stability while clock/actions advance, early/open/late
  boundaries, midnight/skip/intermediate deadline, duplicate sources, board
  assignment, SaveService cold Continue, one reward/failure, action-count and
  expired-clock legacy grace, cooldown/reentry, and old queued showdown calls.
- `scripts/tests/crew_duel_offer_timing_check.gd`: six actually dealt/settled
  native duel hands and actual TalkDock construction. A synthetic 100% offer
  roll isolates eligibility; the product's probability is unchanged. Baseline
  `04a114c0` displayed six calls, fixed code displayed zero. Baseline first
  TalkDock build took 213.7 ms, later builds 2.7–3.0 ms. The fixed path took
  0.034–0.043 ms; core settlement remained about 2.5–3.2 ms. This measures native
  headless UI work, excluding browser rendering and persistence, and does not
  certify every cause of a visible Web pause.
- Both scripts refuse execution without an explicit isolated distribution data
  root. Runs used the pinned Godot 4.6 console engine, Dummy audio, private
  profiles/saves and a kill-on-close Job capped at 5% host CPU / 2 GiB.
  Local commands, logs and zero-active-process receipts are in the task's
  `evidence/` directory (`windows-verified`, `duel-verified`,
  `duel-ui-baseline-final`). A final integrated-source receipt is recorded there
  separately. No full suite or unrelated audit was run.

The engine emitted its existing root-certificate-store initialization warning;
no trust or security setting was changed.

The old standalone board-decline fixture also rejects on unchanged baseline
`04a114c0` with `Room object authority is invalid.` Its synthetic room lacks the
current authority proof. That historical fixture was retained; the focused
board-view check verifies the appointment text and single flavor line, and the
generated favor flow exercises actual event resolution and durable saves.
