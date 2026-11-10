# Roulette warm Web acceptance, 10 November 2026

**Passed:** the fresh rendered same-process Blackjack Deal/Stand, Leave, Copper Rotor Red $9, Spin/first Confirm path on deployed NEXT `8e2addc3c58010afd36b54d0cf584e38ceb91309`, tree `113af8750f02426df947c80243579a6978b594ed`.

This is actual Web pixel evidence using the documented `http://localhost:8088` QA route, an isolated E-drive profile and the predeclared independent B fixture. The only HTML adaptation preloads that fixture before game startup. No original R08 data, state mutation, RNG inspection, outcome search or runtime-internal probe was used. Roulette source blob `11c22a1c5b86f2d51529e3c8c63ec5d4dddb0b31` is identical between the prior b6 build and this deployed build.

## Decisive observations

1. Continue displayed independent seed B and cash $80. Ordinary Blackjack Deal made cash $71, player 18. One Stand exposed Machine Jam. One ordinary visible Wait cost $3; settled dealer 20/player 18 showed cash $68. Leave returned to the room without any restart.
2. Copper Rotor opened with no spins, cash $68, draft $0 and $9 denomination. One Red $9 chip, one Spin and exactly one Confirm were dispatched.
3. First Confirm displayed cash $59, bet $0 and the live No More Bets presentation. The next PNG started 10.399 seconds after Confirm, before any menu or cold reset: cash $77, winning red 23 box, highlighted 23, Recent 23 and net +$9 result were all visible.
4. The warm public Journal showed exactly four rows: Blackjack -9, Blackjack +0, Machine Jam -3, Roulette +9. No second Confirm or additional Roulette spin was used.
5. Explicit browser close completed. Capped supervisor exited 0, did not time out and drained its owned Job to 0 with no cleanup error. No page errors, console errors or failed requests were recorded.

The locally retained decisive PNGs are `roulette-first-confirm.png`, `roulette-first-result.png` and `warm-journal.png` under `E:\CodexQA\BTH\runs\roulette-8e-web-stages-20261110\evidence\r08-warm-session-10`. The JSON receipt records their exact hashes and all other evidence identities. No raw fixture, save, authority key or browser profile is committed.

## Startup investigation and safety

The earlier b6 attempt remains a startup/harness timeout, not a game result. It combined goto, readiness and screenshot into one stage. This retry separated those boundaries, added independent outer timeouts and a heartbeat, and retained all ordinary-input safety gates. On the current build goto returned at 5.274 seconds, readiness followed 7.402 seconds later and the startup PNG followed 1.205 seconds later. The stall did not reproduce. A 15% capped Job and 900-second supervisor replaced the earlier 6%/490-second run. Multiple inputs changed, so CPU starvation is only a possible explanation, not an established root cause.

The run admitted every workspace/profile/temp/cache/evidence/output path under the approved E root before writes and again before child/browser creation, with 4 GiB expected writes plus 20 GiB reserve. Assignment-before-resume, 2 GiB memory cap, kill-on-close and no breakaway remained enforced. Browser sandbox options were unchanged. No TLS validation, certificate warning, browser security or system setting was bypassed.

## Scope and remaining limits

This closes the independent same-process warm first-result/payout/history Web gate. It does not qualify LAN HTTPS rendered access, a general game sweep or cold Continue persistence. The original sealed R08 first rejection remains protected and unattributed. Historical native and b6 receipts remain unchanged at their own identities. Stable, itch, hosting audience and watcher machinery were not changed.

Machine-readable receipt: [roulette_web_warm_acceptance_20261110.json](roulette_web_warm_acceptance_20261110.json).
