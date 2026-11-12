# FEAT-10 — three older bugs rechecked through visible controls

Date: 2026-11-12. Documentation starting source:
`d95c817d510695598edcc5cd911be1251ef7109e`.
Rendered source: exact served NEXT `070fc937ad69de8d152b0dddae769f5206704821`,
at 1280×720, fresh admitted disposable browser profiles. No FS/save/game-state
access, scene override, input injection through gameplay APIs or private state
capture was used. Public native object discovery helped select a visible Vic
seed; it is navigation evidence, not the rendered pass.

## Results

| Historical item | Current observation | Disposition and limits |
| --- | --- | --- |
| BUG-10, Vic absent/unhittable | Hidden Casino, base scenario, visible seed `UF061-VIC-1`: Vic is drawn. After his autonomous walk settled, clicking his body opened the lender panel with his name, terms and Use control. | Not reproduced; reopen on recurrence. The current Crew Back Room is a separate layer with different contents; Vic's current lender route is Hidden Casino. No loan was taken for this check. |
| BUG-34, Numbers Book clipped | Gas Station Casino normal practice room: the full label wraps to two lines; clicking opens the full `Gas Station Casino Numbers Book` title and Open Book action. | Not reproduced; reopen on recurrence. Actual 1280×720 render and hit observed, not a string-width inference. |
| BUG-37, both enabled Tier-2 trips rejected | A normal run uses Skip Lessons, then Play, Back Alley → Gas Casino → Motel → Bar → Lounge → Riverboat. Both enabled/affordable Tier-2 Travel controls installed their destination. The Lounge's No Line scenario exit resolves; both base Leave controls open their normal map information. | Not reproduced in current normal route sampling. The original September seed was not replayed and these rolled No Line Lounge / base Riverboat, not the two original scenarios. |
| BUG-37 named scenario layouts | Visible Environment Library selectors additionally render Wedding Charter and Bachelorette Storm. Wedding Best man table and base Leave are separate and Leave is hittable. Bachelorette Guest marker appears at bottom left, base Leave at bottom right; Leave is hittable. | Supplemental layout/hit evidence only. Practice initializes at noon and Kitty closing handling advances its scenario; no claim that an active-night Bachelorette or Wedding campaign trip was played in this supplemental check. |

The old scenario-label overlap rejection has not recurred in these samples.
No runtime repair is justified by the observed results. Dated closure lines
were added to the historical reports without deleting their original failures.
All three remain reopenable, and these samples are not a full scenario matrix.

## Decisive raw captures

- `uf061-feat10-play/004-numbers-book-hit.png`: full label/title and action.
- `uf061-feat10-play/013-vic-seeded-room.png`: visible Vic, initial walking position.
- `uf061-feat10-play/015-vic-mercer-interaction.png`: settled body hit opens lender.
- `uf061-feat10-play/034-lounge-tier-two-route.png` and `035-tier-two-lounge-arrival.png`:
  enabled Travel then installed Lounge, wallet 79 → 63 with shown $16 cost.
- `uf061-feat10-play/037-lounge-safe-exit-resolution.png`: normal scenario exit.
- `uf061-feat10-play/039-riverboat-enabled-route.png` and `040-tier-two-riverboat-arrival.png`:
  enabled Travel then installed Delta Queen, wallet 63 → 47 with shown $16 cost.
- `uf061-feat10-play/041-riverboat-base-exit-hit.png`: normal base Leave control.
- `uf061-feat10-play/043-wedding-charter-layout.png` and `044-wedding-base-leave-hit.png`.
- `uf061-feat10-contexts2/002-bachelorette-initial-selector.png` and
  `003-bachelorette-base-exit-hit.png`: supplemental exact-scenario layout/hit.

All paths above are beneath `E:\CodexQA\BTH\runs\<run>\evidence`.
Both browser workers exit 0, with no page errors, console warnings/errors or
cleanup errors; owned process count at release is zero. One longer-duration
launch was rejected before child creation by the existing timeout1-1200 guard;
the exact refusal is retained. Subsequent workers use the original caps and
18-minute bound. No guard or resource cap was changed.

## Test comparison

Before this task the audit marked 3 historical bugs as needing play; after it,
3 were rechecked and not reproduced in the stated samples. No executable
source or expectation was changed and no test was deleted, skipped or weakened.
The existing source qualification is reused with its original scope: full
Smoke 10/11 versus baseline 9/11, loader 832/0 versus 831/0, liveness PASS,
and separate unchanged validator retry PASS with zero cache changes. The first
full Smoke cache-census failure remains retained. No fresh full suite is claimed
for documentation-only edits.

## NEXT delivery

Gameplay checks were made on exact served 070fc937. Documentation delivery is
pending: the current branch is held before import by the existing cold-import
qualification requirement for the prior requested Crossword audit CSV note.
No new room behavior is being shipped, and no pipeline workaround was made.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-feat10-play, uf061-feat10-contexts2, uf061-vic-public-probe, uf061-play-duration-cap-correction, uf061-daily-smoke, uf061-daily-validator-retry2.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-feat10-proof-commit\evidence\raw-evidence-index.json | 8b95756367527dbba55ad94c9a7d9f46d9aaf3ef5e9400ac84484e4252f57ab8 |
| E:\CodexQA\BTH\runs\uf061-feat10-play\evidence\result.json | 7148bac248ad3e8aaf23323406d613c529a71822951ff458319bd887752efe56 |
| E:\CodexQA\BTH\runs\uf061-feat10-contexts2\evidence\result.json | e679b697e08af1871bc6f92215f0f6c4fa824808b24b6685bcd8e21270c24f3a |
| E:\CodexQA\BTH\runs\uf061-vic-public-probe\evidence\worker.log | ad6f65de9f953e75814160d47bf83592a998dfb6de597c00e7840120d2f4087c |
| E:\CodexQA\BTH\runs\uf061-play-duration-cap-correction\evidence\launch-rejection.json | b97504fab218910ed92eb3cdeea08d0c364ea43b1c44126bb299e3dc9a0ca5d7 |
