Status: IN_PROGRESS — implementation landed on `main`; Family 2 release-gate closeout remains open
Board row: `world06_4` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_4: Back Room — Job Board, Jobs and Recruitment

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped Layer 3 back room, the job system and the seven recruitment encounters.
It is not a redesign of the trust ladder or the job economy. Read
`scripts/core/crew_state_model.gd` (`job_definition`, `job_definitions_for_member`,
`job_definitions`, `default_trust`, `normalize_trust` and the rest),
`scripts/core/crew_recruitment_model.gd` (`member_definition`,
`recruitment_event_ids`, `contact_event_ids`, `apply_to_environment`,
`crew_path_started`), `data/crew/jobs.json`, `data/crew/recruitment.json`,
`data/crew/crew.json`, the archived `crew06_5_recruitment_prompt.md` and
`crew06_6_layer3_jobs_prompt.md`, and the `world06_1` adapter contract.

## Why this rework exists

The back room is where the crew path is supposed to feel like a place you belong
to. It ships as a furnished layer with a residency rotation, a job board, a
Numbers desk, a planning table and a Practice Rig — all of which the player
experiences as choice lists. Meeting a crew member for the first time, the
single most characterful beat in the pillar, is an event with options.

## Board and dependencies

Follow the active board protocol. Claim `world06_4`. `world06_1` must be landed
and reviewed; build only on its accepted head. You own
`crew_recruitment_model.gd`, the job seams in `crew_state_model.gd`,
`data/crew/jobs.json`, `data/crew/recruitment.json` and their tests exclusively.
Delivery-shaped job kinds execute through `world06_2`; the Numbers desk belongs
to `world06_3`; the planning table belongs to `world06_6`. Consume their APIs,
do not reimplement them.

## 1. The room and who is in it

- Layer 3 becomes a room whose occupancy is visible and changes with the shipped
  residency rotation. Who is here tonight must be readable on arrival without
  opening anything.
- Each of the seven members is an actor with authored positions, poses and
  bounded behavior states reflecting their trust rung, their current grievances
  and whether they have a job out with you. Their voice stays per Voice Bible II.
- The job board, the Numbers desk, the planning table, Mags' bench, Rook's ride
  and the Practice Rig are scene objects with state, occupancy and reachability.
  Objects that are in use by an actor must read as in use.
- Rank services keep their landed gating and costs exactly. Approaching a service
  becomes going to where it is and speaking to whoever runs it.

## 2. Recruitment as encounters

- All seven recruitment paths and their fallbacks become staged encounters in the
  environments where they are seeded, using the adapter. Keep every landed
  presence condition, seed, fallback path and diegetic signpost exactly.
- A first meeting must be a scene: where they are, what they are doing, what
  interrupts it, and how it ends. Refusal, deferral and acceptance need distinct
  staging and distinct aftermath.
- Contact encounters after recruitment must reflect standing — a member who is
  aggrieved does not greet you the way one who is not does.
- Nothing in recruitment staging may reveal Turn eligibility, grievance weights
  or any hidden state.

## 3. Jobs become work

- All thirteen shipped jobs across the five kinds — `package_run`, `stake_horse`,
  `numbers_route`, `lookout_hold`, `collection`, plus the seeded
  `package_delivery` — must be offered, accepted, performed and resolved as
  sequences. Keep every landed payload, expiry, reward, failure, trust and
  grievance value exactly.
- Offering is a conversation with the member who owns the job, at the place they
  are, not a board entry that appears. The board shows what is open; the person
  gives you the work.
- `stake_horse` and `collection` are the two kinds with no played execution
  today. They must get real sequences: a stake handed over and its outcome
  witnessed; a collection that involves going somewhere and dealing with someone
  who does not want to pay. Neither may become a reward overlay.
- Abandonment, expiry and failure need staged consequences and persistent
  aftermath, consistent with the landed `job_abandoned` grievance contract.
- The Practice Rig becomes apparatus you use, with the shared progress contract
  preserved exactly.

## 4. Persistence and honesty

- Every reward, trust change, grievance and heat effect fires exactly once
  across save, exit, travel, revisit and expiry.
- Aftermath persists in the room and in the world: a job you abandoned is
  remembered, a member you disappointed is positioned differently, a collection
  target's node reflects what happened there.
- A run that ignores the crew path must remain a true no-op with no cost.
- Ordinary Punchline layer navigation, ordinary events and ordinary environment
  functionality must survive everywhere this row mounts sequences.

## 5. Tests and acceptance

- All seven recruitment paths and all documented fallbacks played to completion,
  including refusal and deferral, across the seeds the landed contract names.
- All thirteen jobs offered, accepted, performed, completed, failed, abandoned
  and expired, with landed values asserted unchanged.
- `stake_horse` and `collection` specifically proven to have played sequences
  with distinct verbs and distinct failure, not reward overlays.
- Residency rotation reflected in room occupancy across boundaries and saves.
- Exactly-once assertions for every effect across save, reload, revisit and
  expiry.
- Hidden-state audit: no recruitment, job or room state exposes Turn eligibility
  or grievance weighting.
- Crew-ignoring golden probe extended and green.
- 10-seed determinism, native/Web parity, performance with the idle liveness
  counter-gate, accessibility for every new interaction.
- Visual QA: empty room, each residency configuration, every member state, job
  offered, job out, job failed, each service in use, Practice Rig in use, all
  seven first meetings, reduced motion, small screen.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA. Archive only with
exact evidence and with the unchanged-values table for jobs and trust attached.
