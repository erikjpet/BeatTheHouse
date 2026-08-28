# craps06_3 readable bet matrix

The shipped no-hardways/no-proposition-bets scope remains binding.

| Bet | Availability and working behavior | Settlement/payout | Correction and help |
| --- | --- | --- | --- |
| Pass Line | Come-out; persists through point | Natural/craps then point-before-seven; even money | Specific pending removal, undo, clear, repeat; point puck and target state explain phase |
| Don't Pass | Come-out; persists through point | Inverse line; 12 bars; even money | Same correction verbs; label states the bar rule |
| Come | Point-on only; travels to rolled number | Come-out semantics, then number before seven | Specific pending removal before commit; working row shows destination |
| Don't Come | Point-on only; travels to rolled number | Inverse Come; 12 bars | Same correction verbs and working-row visibility |
| Pass Odds | Point-on with working Pass stake; up to posted multiple | Exact mathematical odds | Added/removed as a distinct pending wager; disabled reason comes from rules validation |
| Come Odds | Established Come number; up to posted multiple | Exact odds; off on come-out per authored rule | Number-specific target/removal and working-row state |
| Place 4/5/6/8/9/10 | Point-on; remains working after hit; off on come-out | Authored 9:5, 7:5, or 7:6 | Number-specific pending correction; persistent at-risk total remains visible |
| Field | Single-roll wager | 2 pays 2:1, 12 pays 3:1, other authored winners 1:1 | Removed/undone before commit; per-bet result identifies resolution |

Accounting projections distinguish available funds, new pending total,
at-risk working total, returned stake, payout, net change, and itemized results.
Exit/save keeps point and working wagers authoritative; transient throw gesture
coordinates are discarded and never alter the seeded result.
