# BTH-NEXT-QA-PROFILE-CUSTODY-001: QA companion custody correction

Classification: harness/profile-custody error, not a confirmed gameplay defect. Source main1fa3ffe7438ae4df1650d200097a5ae975060ace. No runtime patch or guard change.

Normal public actions on the retained O campaign reached Punchline Back Room (9/9), offered The Count (2/2 inspection), and locked it in setup. Two immediate Save/fresh Host Continue probes then correctly failed closed to aborted/private_authority_unavailable (8/9 each). Read-only inspection found the *input* campaign already carried crew_state.private_authority_error plus the narrative error flag and no private capsule before locking. This is not evidence of a newly broken heist save.

Cause: successive QA profile copies carried save_dir and localappdata but omitted appdata, including user://.crew_host_authority_v1. The original generated profile at E:/CodexQA/BTH/runs/next-bugfinder-alley-discovery-20261115-01 still has its companion and a capsule-bearing O save with no error. All61 inspected later O save copies have the error. No key or capsule value is printed, committed, or reconstructed. Copies with errors remain preserved; do not clear flags or manufacture private state.

## Evidence scope correction

Earlier O-campaign reports still record actual public actions and their measured cash, game, room, ticket and public-job comparisons. They do NOT qualify intact private Crew authority, hidden grievance continuity, full heist progress or equivalent original-player state. Their naturally earned public progress occurred on a custody-damaged QA profile. Broad BTH061-006 acceptance remains open. Subsequent faithful Crew qualification must start from the intact original profile and preserve all companion directories on every isolated copy; reproducing only the later public state is insufficient.

The Numbers low-funds branch additionally played six bounded attempts from $28: three paid rounds reached $7, below the cabinet's $9 minimum; remaining attempts did not change cash. Fresh Continue retained public state (5/5). Zero-bankroll end-of-run timing was not reached and remains unqualified.

## Next action

Copy the intact original campaign's save_dir, appdata and localappdata into an admitted isolated run. Verify no Crew authority error after real Host Continue and companion presence without exposing values; then resume natural public progression. Never replace user saves or repair the damaged campaign by editing hidden state.

## Raw evidence hashes

- next-bugfinder-ordinary-vp-lowfunds-20261115-01: worker.log SHA-256 `16b52d1b31db415a9823fbe3feca1197221a719d84364ce798ced66fa7799b9f`.

- next-bugfinder-ordinary-crew-planning-20261115-01: worker.log SHA-256 `867ca08440cc5893483bc5d0673c0126f306c1749780efa7533419d017d3577d`.

- next-bugfinder-ordinary-planning-offer-20261115-01: worker.log SHA-256 `37d2922f4f7bc29b28f1a7f375074d2ebabcb8dbc21c5b5da504b43b4290fd48`.

- next-bugfinder-ordinary-count-lock-20261115-01: worker.log SHA-256 `f354bf2b130a12ff547c67e08e19d5df94c4ad155b6226c544a9cf52715375e2`.

- next-bugfinder-ordinary-count-lock-20261115-02: worker.log SHA-256 `0a91fe439f3c4a2bd8350214e4d6c11e09af570bcf184f66a3e321383f2dbb59`.

- next-bugfinder-count-custody-20261115-01: worker.log SHA-256 `4de154793fe56c67355c492b1afc2460328c0be916f1b6d08ab1e6190b4cbb1d`.

- next-bugfinder-count-custody-20261115-02: worker.log SHA-256 `53fd04aa3a80fd4c1ca0eb935e7f2c4fca29323c395bff22eda14dbbccb2be77`.

## Intact reconstruction started

Copied original save_dir, appdata and localappdata together into an admitted fresh profile. Actual Host Continue confirms no Crew private-authority error. Normal offered Crew loan, room controls and local continuation pass16/16 ($100 to $170); no private data was edited. This starts reconstruction, not full heist qualification. Raw next-bugfinder-ordinary-intact-restart-20261115-01 worker.log SHA-256 `d4fc81811a3a558c7b560bf592b750609ce058162e10ba3e9a4cf2f381dbf54c`.
