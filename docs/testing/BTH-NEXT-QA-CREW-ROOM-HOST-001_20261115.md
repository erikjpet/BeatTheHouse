# BTH-NEXT-QA-CREW-ROOM-HOST-001: Crew package acceptance loses cabinet room

Date: 2026-11-15 UTC. Status: **open; native reproduced, fix in progress**.
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
