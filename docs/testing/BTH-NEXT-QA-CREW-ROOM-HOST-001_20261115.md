# BTH-NEXT-QA-CREW-ROOM-HOST-001: Crew package acceptance loses cabinet room

Date: 2026-11-15 UTC. Status: **open; fix qualified, NEXT delivery pending**.
Source: exact NEXT e5152c34bfe146600214fb206ec80a5e3e8a27cb.
Owner: /root/fix_crew_room_return. This commit records diagnosis only.

## Classification and reproduction

A product-path failure is reproduced in generated native campaign rooms, not merely
an orphan-warning expectation. The original crew_delivery_game_return_check passes
because it checks the retained game module, but never exits these cabinet cases.
An external subclass adds observations and calls the production back_to_environment
method after the original case, without modifying product code or its assertions.

The existing fixture builds real Gas Casino rooms with authenticated placement and
manifest checks, Save/Continue and normal game entry. Crew trust/obligation and a
successful solicitation seed are explicit synthetic prerequisites. It is not a
captured user save, physical-pointer playtest or browser/WASM reproduction.

| Game / generated scenario | Initial catalog | Accept then exit | Refuse then exit |
| --- | ---: | --- | --- |
| Scratch / Graveyard Shift | 17 | 0, TRAVEL recovery | 17, ENVIRONMENT |
| Slot / Tour Bus Stop | 17 | 0, TRAVEL recovery | 17, ENVIRONMENT |
| Video Poker / Trucker Convoy | 17 | 0, TRAVEL recovery | 8, ENVIRONMENT |

All accepted cases show: "This room could not be displayed. Your saved run was
kept; choose a safe destination on the map." The broader Video Poker refusal
scenario retirement is not classified as a defect by this probe.

A second scratch-only run adds two assertions: return to ENVIRONMENT and retain a
nonempty room catalog. It exits 1 with **2 failures out of 45 checks**; the refusal
controls pass. Underlying warnings originate in prepare_room_catalog_at_boundary
and _attach_action_only_records. The final catalog is empty. The precise invalidation
cause still needs diagnosis; no validator or authority contract was weakened.

## Other fresh bounded regression evidence

All runs used pinned Godot 4.6 and bth_qa_guarded_run.py with new isolated E storage,
resource-capped Jobs, assignment before execution, and zero owned processes at exit.
No original saves were read, changed, uploaded or committed.

- Back Alley incident: 8/8, no repeated cash/clock/RNG settlement.
- Crew expired handoff: 305/305, including exact/late expiry, mounted cleanup and
  cold Continue. Stale-UI dispatch returned in 27ms. Not rendered Jazz acceptance.
- Eleven-game Crew accept/refuse: 401/401, 22 cases, but 25 missing-host warnings.
  Assertion-green is not warning-free or complete room-exit coverage.
- Paid Blackjack/Roulette/Coin Pusher variants: 197/197, 9 cases including three
  paid actions and selected Save/Continue. No browser claim.
- Three-cabinet observation: original 115 checks pass; additional observations
  expose the room-exit failure. Scratch-only added assertions make that gap red.

## Raw evidence and commands

Raw evidence remains under E:/CodexQA/BTH/runs, not in Git. Each listed run contains
its exact command, admission manifest, job receipt and worker.log in evidence/:

- next-bugfinder-alley-20261115-01
- next-bugfinder-crewexpiry-20261115-01
- next-bugfinder-crewreturn-20261115-01
- next-bugfinder-crewpaid-20261115-01
- next-bugfinder-roomhosts-20261115-01
- next-bugfinder-roomhosts-red-20261115-01

Observation script: next-bugfinder-crewpaid-20261115-01/evidence/crew_room_host_probe.gd.
Red script: next-bugfinder-roomhosts-20261115-01/evidence/crew_room_host_regression.gd.
Run the red script through the existing guarded runner with BTH_DISTRIBUTION_BUILD=1
and BTH_CREW_RETURN_GAMES=scratch_tickets, --headless, exact source --path and a fresh
admitted run ID. No guard bypass or original-save input is required.

Red worker.log SHA256: 43f1dfc8c55c71bd7f8b0d7582c341e926f0f6553f7dee8f402988da655e0712.
Red job.json SHA256: a71bac3f4608524512dec60ae123141ec37f19a6431df22406b5d1885aa7350c.
Broader result/hash index: next-bugfinder-crewpaid-20261115-01/evidence/native-summary.json,
SHA256 8bbc1b77289b961e6e4af0f00f07003eba2385d8e6527aadea84e9a18c3b14c5.

The red job is a genuine assertion failure, not a timeout: exit1, timed_out false,
active_at_release0, no cleanup errors. All prior jobs exited0 with the same clean
closure. Product fixes, revised qualification and NEXT delivery remain open.

## Additional authority diagnosis and registry checkpoint

The scratch accept/refuse authority probe (next-bugfinder-authority-20261115-02)
shows nonempty publication, valid proof and finalized result, 9 finalized records,
17 live/published manifest rows and no manifest/base-slot authority errors before
and after acceptance. After acceptance the published/live environment keys match
(excluding game_states), yet the final room catalog is empty. This narrows the
failure to later interaction projection/composition rather than missing publication
or rejected base authority. Exact cause remains assigned to the fix worker.
The first diagnostic probe had a script indentation error and is retained as setup
failure, not a product finding.

Manual ledger reconciliation with this worker's current owner/owned-zero evidence
completed in next-bugfinder-ledger-20261115-05: 115 findings elsewhere, zero findings
for this new ID; global exit1 is not a clean whole-project ledger claim. Earlier
schema-input errors while preparing this new record are retained in runs01-04.
No unrelated entries were edited, closed or reassigned. This objective stays Open.

## Root cause and qualified repair

The valid publication was retained. After acceptance, Rook lost available dialogue
choices and the producer renamed the same physical contact from
`event:crew_contact_rook` to an unbound `crew_presence:crew_rook`. The composed
room correctly rejected that new identity without an authored slot.
The narrow fix retains contact identity only for an existing active physical
manifest host that has not been resolved. Choices remain disabled when absent.
Absent, inactive, nonphysical, other-contact and resolved hosts do not qualify.
No geometry, placement, validation, gameplay values or canvas scheduling changed.

Final qualification:
- crew_contact_identity_check: 11/11, including negative retirement/manifest cases.
- crew_delivery_game_return_check: 525/525, all 11 games accept/refuse plus three
  paid actions. All four cabinet games return to usable floor and cold Continue.
  Rook retains one inert bound host; Pull Tabs Switch retains available actions.
- cold_continue_room_projection_check: PASS, restored_objects=9 and
  damaged_authority_rejected=true.
All final guarded jobs exited 0, timed_out=false, active_at_release=0.

The first expanded matrix reported 2/521 failures solely because new assertions
incorrectly expected Rook in the Pull Tabs fixture, which generates Switch.
An external presence probe confirmed the fixture. Assertions now explicitly
require each expected member/contact rather than silently skipping absent ones.
Original assertions and unconditional room/Continue coverage were preserved.
The failed attempt remains in next-bugfinder-fixedall-20261115-01.

These are native synthetic production-path regressions, not deployed browser
playthrough or a reproduction from the owner's save. NEXT delivery remains open.

### Final evidence hashes

- next-bugfinder-stages-20261115-01/evidence/worker.log: `a2675ee7760fb8a1cf4e9bc9e60caf4e31f2ac0bfbc2060ed56c5ccb002d1c29`
- next-bugfinder-stages-20261115-01/evidence/job.json: `988db71c7f1fae7c60646559a9652e5619e06b5a795799c878073985ab830427`
- next-bugfinder-identity-20261115-01/evidence/worker.log: `ae6e7e21afa5cb74f22421f3312db4cb57199d6aa6d23b9552250eb81cf71af7`
- next-bugfinder-identity-20261115-01/evidence/job.json: `ee8da0cdfd1a60718117f2101a855c7b874e84bc449600c88f64179eba3c587a`
- next-bugfinder-sealed-20261115-01/evidence/worker.log: `bd612d20b28df2d07e4fd5ce72ae4d8bb3488780f81ed27a742c23c5a2791f9e`
- next-bugfinder-sealed-20261115-01/evidence/job.json: `359458ac314dcb8e50c36da8e174a4112de93b37aa5adf623f6a0d3508db30a0`
- next-bugfinder-fixedall-20261115-01/evidence/worker.log: `0b85029a2d06306da38155b1759c91710e3a9d09d72dd8ec34adcf2ab29e3cfc`
- next-bugfinder-fixedall-20261115-01/evidence/job.json: `24f9e1a085751b2a378d4f2d34509757e8822a63a46062eef7aa40db5be15ca8`
- next-bugfinder-fixedall-20261115-02/evidence/worker.log: `8dda5996acd47f714e5eee1885ad6bea2b97260ceb119f4506b7b7a17916b6ce`
- next-bugfinder-fixedall-20261115-02/evidence/job.json: `7b1efcdff875c5ff41da6ca89cf6bc723924a25e7e27f00762488a2a42f79cf6`

Fix commit: ed37dd276c57a6febeb00bc1b9984704c585db9b, pushed to main.
Manual checkpoint next-bugfinder-ledger-20261115-06 reports 115 unrelated
findings and zero for this objective. NEXT watcher was stopped; the authorized
normal capped watcher restart now fetches this commit. Delivery is not yet proved.
