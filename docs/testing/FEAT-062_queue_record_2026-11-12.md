# FEAT-062-RECORD — owner-deferred queue recorded, no work started

Date:2026-11-12. Starting commit:1f70b2e4365c221822bb1286f32eb345d9012fd1.
Source: docs/todo/BTH_unfinished_features_audit.md section9 and its owner table.

Before: the audit listed five future decisions; they were not a new worker
authorization. No future item effect, scenario polish, voice pass, leaderboard
or heist enablement has been implemented by this record.

After: all five entries are explicitly open in the JSON ledger and the existing
named plan ledger. Their group is0.6.2, owners/design prerequisites are stated,
and every next action says no work authorized. Existing BTH-11, BTH-15 and
BTH-17 histories and pauses remain intact.

| Ledger ID | Future queue item | Who / boundary |
| --- | --- | --- |
| FEAT-01 | Full item-effect reassessment before any effect change | Owner first, then worker; FEAT-01 parts A-E and docs/item-audit are starting evidence; includes Lucky Penny BTH-15 and Ledger Pencil BTH-17 / LEDGER022. No item effect, text, price or strength work authorized. |
| BTH062-SCENARIO-POLISH | Scenario polish after owner states scope | Owner first; BTH-11 remains open and under its standing pause. The two named FEAT-09 exceptions do not lift this broader hold. |
| FEAT-08 | Voice and copy pass for all text added in0.6 | Owner, by hand; No worker copy or voice edits authorized; perform after item/heist text decisions. |
| BTH062-DAILY-LEADERBOARD | Local in-game Daily Challenge leaderboard | Needs owner design; No online service, sharing panel, platform calls or implementation authorized. FEAT-03 changes only the seed. |
| BTH062-WHALE-TRUST-ARC | Whale Game and Crew trust arc decision | Owner after investigation; Private FEAT-02/07 report is partial; normal Whale play and complete Count measurement remain open. No enablement, trust restoration or pacing change authorized. |

No runtime file, math, item effect, text, price, scenario content, pipeline or
version changed. No future task is Complete. This documentation batch remains
pending NEXT delivery; the existing README cold-import hold is unchanged.

Validation: JSON and named-row presence checked; each future state is open,
group0.6.2, unassigned and has no implementation batch, commit or deployment.
Runtime qualification is reused from unchanged main: Smoke11/11, livenessPASS;
Count accounting70/70. The older golden discrepancy stays open separately.
No extra runtime tests were added for this documentation-only record.
