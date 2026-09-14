# game06_4 Slot and Video Poker final closeout

Date: 2026-09-02
Recovered product integration: `e874d6bc1636ab8094bd88c0c304a5db29902535`
Final gate/fairness remediation: `bd77ac54da2c9a911587802968d66cd589a7a1c9`
Remediation tree: `21de448bdd595d37577708d2e4ebb68546e82449`

## Verdict

`game06_4` is complete. The substantial Slot and Video Poker cabinet work was
recovered from the already-landed integration instead of rebuilt. Both games
now satisfy the machine-depth contract, keep their shipped rules and math, and
have exact automated evidence for authority, lifecycle, presentation,
performance, accessibility, determinism, and native/Web parity.

Closeout found two product-facing polish gaps. Slot's recovered presentation
declared idle as static even though the row requires bounded cabinet machinery
and actor life. It now advances only shallow presentation scalars at idle,
without rebuilding or mutating authoritative machine state. Video Poker's
sealed Holdout input used the host wall clock while the cabinet rendered its
own simulation clock; a slow frame could therefore grade a visually perfect
press as merely good. The shared sealed-input boundary now supplies the exact
cabinet simulation time the player sees. The same sealed authority, receipts,
RNG, paytables, detection rules, wager costs, and settlement remain unchanged.

## Authority and product disposition

- Owner-selected W0 + H0 is final: both games wager and settle directly against
  bankroll through the sealed host. There is no machine-credit balance,
  buy-in/cash-out conversion, or split ledger.
- Video Poker has no hand-pay qualification, state, or acknowledgement.
- Slot jackpot/grand acknowledgement remains a sealed host action. Tests prove
  it is durable, receipt-bound, exact on replay, and neutral to bankroll, RNG,
  and environment-turn settlement.
- Rejected and incomplete actions are side-effect-free. Slot cannot
  double-spin/double-pay; Video Poker cannot hold after draw or duplicate a
  charge. Pointer, keyboard, controller, touch, and reduced-motion equivalents
  preserve the same authoritative action and target index.
- Slot families, formats, generators, reels, feature rules, paytables, and
  Video Poker variants/paytables were not redesigned or rewritten.

## Exact-tree automated evidence

- Final project/load/full Slot acceptance: PASS. Validation 71.391s, script
  load 30.830s, Slot suite 316.534s. Report SHA-256:
  `60AD8039E5589662B0F68BD30B325AE621595A7770B8D34120399D69D6E717CC`;
  wrapper summary SHA-256:
  `351CF6643D07AC5A3479D804EAF800AE4525B613F009437534DDC2A1792E15A9`.
- Slot 10,000-spin matrices: Pinball classic RTP 0.95176, Pinball video
  0.97507, Buffalo line 0.94640, and Buffalo video 0.96964. Buffalo conversion
  activity was nonzero in both samples (129 and 87). Pinball/Buffalo feature
  lifecycle, nudge, event causality, payout variety, item effects, and feature
  Monte Carlo checks passed.
- Full Video Poker functional content and shipped game suite: PASS with zero
  failures. Jacks or Better/full-pay/one-hand RTP 0.9973, Deuces Wild/full-pay/
  two-hand 0.8866, and Double Double Bonus/full-pay/three-hand 0.9365. Report
  SHA-256:
  `5F385CAE47178E1C433D2D6B3AC186F063A9826B17CA64FB7BE24C29630E8D83`.
  The separate 10,000-round cabinet audit also passed (observed RTP 0.9665,
  0.9261, and 0.9344 respectively).
- `game06_4_machine_ritual_contract.gd`: PASS, including closed declarations,
  direct-bankroll conservation, hostile replay rejection, Slot acknowledgement,
  save/revisit, exact Video Poker held/drawn indices, no Video Poker hand-pay,
  observer privacy, tactile rejection, and Slot realtime non-mutation.
  `game06_2_depth_contract.gd`: PASS on the shared sealed dependency.
- Native machine platform probe: PASS for ten Slot outcomes, ten Video Poker
  hands, and ten complete Pinball bonus sequences. Fresh Web release export:
  PASS, ten files / 69,197,590 bytes. Chrome 152 at CPU4: PASS with zero console,
  page, or request errors and the exact native/Web semantic SHA-256
  `b00b75c790aac73e61dbfd794ee25408d4e763e517b815be28ac73b4d9566164`.
  Native/Web report SHA-256 values are
  `13A141736207F112687035E98F60E8301D8DEDB34E2B9903894157415F1AD0A7`
  and `DE4BD9D24493C31CBBDB04369C5BA8EF8B403FA71257B584A7ED7DFC76EF75EF`;
  final export-log SHA-256 is
  `29FB89277337C6F14BCC5ACC2E75F77B1CC20EBB4CC96DFD2EE9CFC498FD374F`.
- Two independent ten-seed foundation determinism runs: PASS, 560 checkpoints
  each, identical combined hash `2085164144`, and byte-identical report
  SHA-256
  `6910143D8E0862315565E5859E497FFA8441301467459C54DE9BF42D6B2679AF`.
- Final performance/liveness probe: PASS, 73 observations and zero failures.
  Slot resolve was 1.668ms average / 3.221ms p95 / 3.491ms max against
  6/8/10ms budgets; Video Poker was 0.984/1.077/1.093ms against 2.5/4.5/5ms.
  Slot and Video Poker each made zero full-snapshot calls. Idle liveness measured
  50 and 49 redraws respectively against the mandatory floor of 8 per 120
  frames. Report SHA-256:
  `174B75FEC8165B2766028E8225D8881DD25164A4C50471FF7EB31BBCDB4C0488`.
  The existing Slot autoplay low-end proxy waiver remains owned by its explicit
  Web smoke gate; this row did not alter or misstate it.
- Canonical Foundation visual/accessibility QA: PASS with zero failures and
  zero warnings. Report SHA-256:
  `C3475F71D11067B51F1A312A930029E57B69D0DBB26E53A494F08405B476CF8B`.
- Slot cabinet visual QA: PASS for all six family/format cabinets, attract and
  reel staging, near miss, true/big wins, Buffalo nudge/feature modes, Pinball
  prelaunch controls, moving trajectories, and video multiball.
- Real-renderer Video Poker proof: PASS across all three cabinets, independent
  multi-hand outcomes, DEAL/HOLD/DRAW, perfect Holdout, unfinished-Holdout
  escape, double-up, 1280x720 mouse and 960x600 touch. Fifteen PNG captures were
  produced. Report SHA-256:
  `3201C01C7BD552F24453F7AC4755EA00554384F9F9F27F3D89480AB5B23B6486`.

## Retained non-green attempts and corrections

No failed attempt was erased or relabeled as a pass.

- The initial Slot acceptance run had seven fixture failures. A fixed RNG stream
  was incorrectly required to generate a Buffalo collection conversion despite
  the actual 10,000-spin family samples producing healthy nonzero conversions;
  feature-reveal fixtures also omitted the current animation id after stale-id
  rejection had been hardened. The tests were corrected to assert an exact
  four-animal state transition, require conversions in every Monte Carlo sample,
  and provide the live animation id. The complete final suite passed.
- The Video Poker wrapper was timing-only red at 199.582s against a stale
  128.703s wrapper allowance. Both functional reports inside it passed with zero
  failures (150.423s content and 19.766s shipped game suite). No timing cap was
  changed.
- A first Video Poker capture used the headless renderer and produced null
  images, so it is invalid visual evidence. Real OpenGL reruns retained a
  Holdout grading failure that exposed the hidden-clock fairness defect. After
  the product input-clock correction, the same real-pointer proof passed.
- The first broad determinism pass stopped on one unrelated Numbers fixture
  whose earlier seeded encounters left less than its fixed $10 late-book stake.
  The route fixture now funds only its missing test amount, matching the later
  camouflage fixture's existing policy. The full two-process ten-seed rerun
  passed all 560 checkpoints byte-for-byte.
- Two final Web export invocations failed before compilation because a relative
  output folder was resolved under the isolated project. The absolute-path
  export immediately succeeded; no source, export preset, or acceptance
  threshold changed because of those setup-only attempts.

## Remaining human check

No implementation or automated-verification work remains for `game06_4`.
The program-level playtest should confirm that a new player can commit and read
a direct-bankroll Slot wager/settlement, understand Pinball/Buffalo feature
progression and attendant acknowledgement, and play a Video Poker hand while
correctly reading held cards and the paytable line. That experiential check is
not represented as automated evidence and remains part of the later playtest
gate.
