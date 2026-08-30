# 0.6 integrated-copy audit — 2026-08-30

Candidate: `D:\bth-0.6-integrated-copy`

Compared against local `main` at
`ffb9e38da781c36252c0785ed1cac6fa2b84b209`.

## Verdict

**NOT LANDABLE AS A COMPLETE 0.6 TREE.**

The candidate is a plain filesystem copy with no Git metadata. A normalized
alternate-index audit (excluding `.godot/`, `.tmp/`, `.tools/`, `builds/`, and
`review_artifacts/`) produced tree
`803e7f1a920a028e1bc7cc181b673e25fed1ee8d`. No local commit has that tree.

Relative to `main`, the candidate contains 94 changed paths: 21 modifications,
73 additions, and approximately 12,978 insertions / 61 deletions. The payload is
mostly early Game06_3/4/6/7 and World06_1–3 work plus evidence captures. It is
not the accepted completion-program composition.

## Blocking evidence

- The authoritative static gate fails:
  `data/crew/world06_1_crew_favor_delivery_sequence.json` has an object root
  while the integrated validator expects an array at that location.
- `docs/todo/README_0_6_board.md` contains duplicate World06_1 rows, one TODO
  and one IN_PROGRESS.
- `docs/todo/game06_5_unreviewed_blocked_handoff.md` explicitly describes the
  included Game06_5 state as unreviewed and blocked, with pull-tab,
  art-alignment, test, and acceptance work absent.
- The candidate contains none of the 31 unlanded paths from the frozen
  Env06_7 completion candidate.
- It contains none of the three Depth06_1 closure paths.
- It contains only partial/outdated blobs from the recovered World spine and
  lacks the World06_4–6 product payloads and World06_7 closure.
- It lacks the product closure for Game06_5, Game06_8, Pusherv3_11,
  Audio06_1, Teach06_2, Integ06_1, Perf06_1, Playtest06_2,
  Playtest06_1, and the balance follow-on.

## Exact-tip coverage sample

The table counts paths still different from `main` in each preserved source and
whether the candidate has the exact source blob at those paths.

| Preserved source | Unlanded paths | Exact in candidate | Different/missing |
| --- | ---: | ---: | ---: |
| Env06_7 `b26f1c10` | 31 | 0 | 31 |
| Game06_3 `679b1d8a` | 11 | 3 | 8 |
| Game06_4 `5ca8494a` | 22 | 3 | 19 |
| Game06_5 `4e68cd79` | 37 | 3 | 34 |
| Game06_6 `bca7a071` | 64 | 27 | 37 |
| Game06_7 `81d56589` | 96 | 57 | 39 |
| Depth06_1 `112443ba` | 3 | 0 | 3 |
| World06_1 `0868279e` | 20 | 6 | 14 |
| World06_2 `74091825` | 26 | 5 | 21 |
| World06_3 `adbc0b68` | 31 | 7 | 24 |
| World06_4 `b11efafa` | 35 | 6 | 29 |
| World06_5 `b1f10f64` | 42 | 6 | 36 |
| World06_6 `8feca160` | 47 | 6 | 41 |

These counts are composition evidence, not acceptance claims for every source
tip. Each row still requires its focused gate and a green integrated main.

## GitHub state

GitHub `main` is `56f219bcfb0bb09963271d50e4a187e9f90fee2b`, a historical board-only commit
based on `28c8b399`. Local `main` is 462 commits ahead and one commit divergent;
the remote-only commit reopens Pusherv3_10 acceptance and does not explain the
candidate payload.

## Reconciliation decision

Do not initialize or commit the filesystem copy wholesale. Build the release
history from the preserved exact branches in dependency order, adapt conflicts
onto current `main`, retain caller-authority and exactly-once protections, run
the row-focused gates, then run the complete post-land gate before publication.
