# CLOSE-02 — complete Bar Dice financial labels

Registered before implementation under CLOSE-02 and BTH061-RC-BARDICE-COVER-CLIP-001.
Baseline source973f0ba2 (CLOSE-01 code and strict Smoke qualified; NEXT delivery pending
an explicit storage exception for its two approved C5 text files).

## Reproduction and classification before the product edit

Product defect: _draw_bar_room truncates its numeric OPP label at29 characters
and its COV/RISK/RET label at34. PlayerText writes each chip amount as N CHIPS,
so a valid chip header loses its RET value. Preserve every numeric value, source,
ownership and rule; remove both truncations and state CHIPS once in the lower
line. Cash formatting stays the same.

Extend the existing real MainScene cover-display trace, preserving all unfunded
cash94/ante6 controls and exact account/root-RNG checks. Then use a separate
normal GameSurfaceCanvas with the real module and inherited theme, driven only
by queued redraws, for presentation-only1/3/4-digit chip snapshots plus a cash
control. Observe the actual surface_label draw arguments, full RET suffix and
themed-font ink/shadow bounds inside the authored236×48 header at1280×720.
No fixture amount is applied to a player account; the original live run is
compared before/after. Run this extended test red before the product edit.

Valid red reproduction:119 checks, 9 failures, all in the new exact numeric-text cases; original94 live cash-trace checks retain their values. One initial observer type-inference error was corrected before this valid reproduction; its raw output is retained.

```json
{
  "failures": [
    "Complete numeric chips header for [9, 6, 3]",
    "Full RET value reaches the real draw call",
    "Complete numeric chips header for [999, 666, 333]",
    "Full RET value reaches the real draw call",
    "Complete numeric chips header for [9999, 6666, 3333]",
    "Full RET value reaches the real draw call",
    "Full opponent amount reaches the real draw call",
    "Complete numeric cash header for [9999, 6666, 3333]",
    "Full RET value reaches the real draw call"
  ],
  "headers": [
    {
      "bounds_inside": true,
      "box": "[P: (332.0, 18.0), S: (236.0, 48.0)]",
      "currency": "chips",
      "expected": "CHIPS  ·  COV 9  ·  RISK 6  ·  RET 3",
      "ink": "[P: (344.0, 48.0), S: (109.0, 12.0)]",
      "new_draw": true,
      "opponent": "AGREE WAGER  ·  OPP 9 CHIPS",
      "text": "COV 9 CHIPS  ·  RISK 6 CHIPS  ·  R",
      "values": [
        9,
        6,
        3
      ]
    },
    {
      "bounds_inside": true,
      "box": "[P: (332.0, 18.0), S: (236.0, 48.0)]",
      "currency": "chips",
      "expected": "CHIPS  ·  COV 999  ·  RISK 666  ·  RET 333",
      "ink": "[P: (344.0, 48.0), S: (115.0, 12.0)]",
      "new_draw": true,
      "opponent": "AGREE WAGER  ·  OPP 999 CHIPS",
      "text": "COV 999 CHIPS  ·  RISK 666 CHIPS  ",
      "values": [
        999,
        666,
        333
      ]
    },
    {
      "bounds_inside": true,
      "box": "[P: (332.0, 18.0), S: (236.0, 48.0)]",
      "currency": "chips",
      "expected": "CHIPS  ·  COV 9999  ·  RISK 6666  ·  RET 3333",
      "ink": "[P: (344.0, 48.0), S: (119.0, 12.0)]",
      "new_draw": true,
      "opponent": "AGREE WAGER  ·  OPP 9999 CHIP",
      "text": "COV 9999 CHIPS  ·  RISK 6666 CHIPS",
      "values": [
        9999,
        6666,
        3333
      ]
    },
    {
      "bounds_inside": true,
      "box": "[P: (332.0, 18.0), S: (236.0, 48.0)]",
      "currency": "cash",
      "expected": "COV $9999  ·  RISK $6666  ·  RET $3333",
      "ink": "[P: (344.0, 48.0), S: (111.0, 12.0)]",
      "new_draw": true,
      "opponent": "AGREE WAGER  ·  OPP $9999",
      "text": "COV $9999  ·  RISK $6666  ·  RET $",
      "values": [
        9999,
        6666,
        3333
      ]
    }
  ]
}
```

## Local after result

The exact extended check now exits0:119 checks/0 failures, versus119/9 before.
All94 original cash94/ante6 checks remain;25 numeric/draw/geometry/account
checks were added. Cash4-digit RET was also cut before and now remains complete.
Chip measured ink/shadow widths are108,132 and144 board units for1/3/4 digits;
the cash control is127. Each fits within the authored236-wide box with its
12-unit inset, and all actual Canvas draws keep autonomous processing enabled.
The separate presentation cases leave the live account/root RNG unchanged.
No game rule, table value, payout, wager source or settlement code changes.

Animation liveness without pointer input passes immediately after this surface
change. Both bounded worker children exit0, error lists empty; job cleanup has
zero active processes and no errors. NEXT Grand Casino practice verification is
pending the CLOSE-01 delivery path; it is not claimed as a rendered Web pass yet.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: native-private-close061-s02-red, native-private-close061-s02-red2, native-private-close061-s02-green.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\close061-s02-record-green-proof-and-scope\evidence\raw-evidence-index.json | 5f05a8900146b7be94cdefe9473aaec2693e49166f069de8d8f3ddff59defdab |
| E:\CodexQA\BTH\runs\native-private-close061-s02-red\evidence\results.json | 7540d8a74102594ad508f13e126871686a98c422ea1f69b70b4c2119c5bf14c8 |
| E:\CodexQA\BTH\runs\native-private-close061-s02-red2\evidence\results.json | 7c729a376a3207515b9c16e79b7651607d53ef0f357da451bf02b15dc623dcd2 |
| E:\CodexQA\BTH\runs\native-private-close061-s02-green\evidence\results.json | 8d6f821862e0d4f995e661b85062a7cc320e3b87009efe2c5924a614cecf6a2d |
| E:\CodexQA\BTH\runs\native-private-close061-s02-red2\evidence\01-bar_dice_cover_display_check.json | 858257f5c7a178bb5f8e454462c477b41f9cc781dbd7eda42364a6ca93c45699 |
| E:\CodexQA\BTH\runs\native-private-close061-s02-green\evidence\01-bar_dice_cover_display_check.json | e50efb5ba1d83fb344d96e311929919b8084a84c899e71db27a33dcf5b214003 |
| E:\CodexQA\BTH\runs\native-private-close061-s02-green\evidence\02-animation_liveness_without_pointer_check.txt | 4aa90b818755c832570c41cf65aef64934fc6dae4864ac8dedd09a5703ec22c3 |
