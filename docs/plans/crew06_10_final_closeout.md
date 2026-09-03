# crew06_10 final closeout

Status: **DONE / ACCEPTED IN THE SHIPPED SAFE SCOPE**

Date: 2026-09-03  
Audited product head: `914e5ac822d8ee3127f210203dc688b182a19c65`  
Audited product tree: `82ea2d051fdef2926f02a390410369bc7bc31ae8`  
Recovered implementation: `0d4529ac` with legacy-tell compatibility fix
`040c0603` and production scenario registration `f1ebe9a7`  
Runtime: Godot 4.6 stable, executable SHA-256
`fc759f9d296fe54f09ab66d41df6ddd2d278493b0e71109f6688ef029ad271ae`

## Verdict

The landed Back-Room Poker implementation is accepted without rebuilding it.
The production table uses an explicit ordered five-card-draw engine, seven
mechanically distinct opponent profiles, five executable room nights, bounded
stacks and raises, durable session reentry, queued action-relative tells,
production room staging, and the existing Turn-compatible Crew memory seam.
Focused contracts, deterministic traces, hostile-authority pairs, production
scenario registration, and actual-renderer visual QA are green.

Three proposed adaptive mutations are intentionally outside the shipped safe
scope because no authentic host-owned authority root exists: consuming
cross-session public poker memory, teaching a tell from an observation, and
applying a room interruption/refund. The landed game fails closed in all three
cases and remains playable on its authored base policy. This is the closeout
program's stated safety default, not a claim that the missing positive controls
exist. A future owner may add those capabilities only after game06_1/env06_6
provide a host-sealed producer. The absence of that optional authority does not
justify a caller-mintable receipt or block this safe row from archival.

## Requirement reconciliation

| Prompt area | Landed implementation and acceptance evidence |
| --- | --- |
| Ordered table and conservation | `scripts/games/crew_draw_poker.gd` owns button/seat order, turn owner, current bet, per-seat round and hand contributions, bounded raise/re-raise, fold continuation, draw order, showdown, and exactly-once settlement. Ten deterministic ordered traces prove legal termination, unique turn receipts, pot/contribution conservation, NPC-only settlement after a player fold, and exact mid-hand/settled restore. |
| Session lifecycle | The friendly session remains capped at five hands and the configured swing boundary. Settlement clears live cards/pot once. A new valid visit advances `session_index`, resets live state and observation receipts, chooses the current authored night, and opens a newly seeded table. Legacy state migration supplies inert ordered-engine defaults without minting authority or replaying a payout. |
| Seven opponents | Rook, Velvet, Knuckles, Switch, Mags, Bishop, and Lucky each retain an authored policy. Seeded black-box samples produce seven distinct behavior signatures and respond to public pressure. Paired fixtures change every hidden/undealt card outside the actor's hand while preserving the action, proving the policy does not inspect private opponent state. |
| Tell staging and compatibility | Ordered observations carry source action/record, ordinal, channel, duration, consumed state, and deterministic presentation. Multiple visible observations remain queued rather than overwriting one slot. Member-specific posture, hand, chip, gaze, card, line, and timing cues are projected without labeling their meaning. The legacy table keeps its existing `crew_record_pattern` behavior; the ordered table preserves neutral `tell_learned(member_id)` compatibility but does not learn from an unsealed or forged observation. |
| Five changing room nights | `friendly_teaching`, `hustle_test`, `debt_court`, `after_job`, and `raid_jitters` are registered to five production Punchline scenarios. Each contains phases, a required task, actor/object operations, and persistent aftermath. The executable contract proves the distinct task boundary and playable deal boundary; the scenario-registration contract proves production metadata selects `ordered_v1` and the intended night. |
| Surface, audio, and accessibility | Production presentation exposes pot, player stack, call amount, turn owner, cards, held state, action rail, seat state, pot/discard objects, lamp/door/chairs, and the visible observation queue. Deal, draw, chip, fold, and showdown cues use the shared surface-audio path. The actual-renderer captures cover exact L3 entry/exit, a two-opponent table, a natural first-hand Rook portrait cue, active draw with five card targets, fresh-seed behavior, idle liveness, and reduced-motion stability at 1280x720. |
| Authority and exactly-once safety | Public-memory receipts, tell-observation receipts, and room interruption claims cannot be minted by the caller. Blank, malformed, recomputed, cross-session, and signed-looking inputs preserve paired state and return the exact unavailable reason. Raw pause/resume/abort requests are typed proposal-only results with no bankroll, refund, table, memory, or environment mutation. |

## Exact replay evidence

- `crew06_10_depth_contract.gd`: PASS, ten ordered seeds, five night
  profiles, seven distinct opponent policies, legal raise/re-raise, continued
  play after player fold, save/restore, bounded memory rollover, and hostile
  authority matrices.
- `crew06_10_scenario_registration_contract.gd`: PASS, five production
  scenarios consuming `ordered_v1` and the intended night identity.
- Focused Foundation Crew Poker suite:
  `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -Suite Contract -FoundationSuite crew_poker -RequireGodot -NoImport -ReportDir .tmp/depth_closeout/crew_poker`.
  PASS: validation 91.334 s, GDScript load 39.635 s, focused suite 214.062 s.
  Summary SHA-256
  `8f60da259d5dd07204dbf49bc2b0ec33d862499060968deef4325907a2f1d0f5`;
  Foundation report SHA-256
  `e8481f8df1275a65f1dc10f4ddf6f213c23ab5a4fd4c389517891be1eb47617b`.
- Actual NVIDIA/OpenGL visual QA: PASS, four 1280x720 captures with exact
  L3 production entry/exit, two seated opponents, a naturally surfaced Rook
  tell, active draw, all five card targets, no label overlap, fresh-seed audit,
  twelve idle redraws, and static reduced motion. Manifest SHA-256
  `2f21c4b210933d9c97a31980b2c3440bd1ad3d73e4cbbc8e5a1139cd602b6397`.
- Current 55-scenario audit: PASS, 55 ids and 1,485 pair comparisons with zero
  failures; report SHA-256
  `36236106fc96b670635ad293b0642f1b18cc5dab9ca3f38a4fe2ae0cd602c5cc`.
  The accepted env06_7 report additionally binds all five poker-night scenario
  dossiers into its 683-capture/14-contact-sheet matrix.

Audited product SHA-256 values:

- `scripts/games/crew_draw_poker.gd`:
  `251ce0d27c4005c664394920fb238565a65b992ba04507a97f57f253159a485a`
- `scripts/core/crew_poker_model.gd`:
  `1e5d892e4c85e5734910cf6eca65d449aa3d6645526ca50501607bb7dd4f07af`
- `data/games/rituals/crew06_10_poker_nights.json`:
  `71ef1f211e864123e2b507f1688836514417824f3178efec03a4b3abdadf1fb9`
- depth contract:
  `2a7ef4d59de4d3554d31ed5b65e45fc59f6fba7e7ab48ca5e18cec60b217b9f5`
- scenario-registration contract:
  `58ec3961d709ff1ebb55aa6c0582f66463c2427886f7cee2538b1dc467e7071c`

## Retained limitation and playtest handoff

No missing host root is disguised as a pass. The exact gaps remain
`host_poker_memory_authority_unavailable`,
`host_tell_observation_authority_unavailable`, and
`host_room_interrupt_authority_unavailable`; the safe neutral behavior and
hostile non-mutation proofs are the accepted result. A later authentic host
integration would be new owner work, not unfinished caller-side poker code.

Deferred to `playtest06_1`: cold-player comprehension of turn order, call/raise
amounts, draw selection, diegetic tell readability, and the experiential
distinction among the five nights. Automated evidence does not claim those
human judgments.
