# Incremental Video Poker hint candidate, 10 November 2026

BTH-PERF-20261104-002 remains Open. This is a tested implementation candidate, not completed performance qualification or main/NEXT delivery.

## Change

Cold Deal now publishes READING THE HAND before strategy completions run. Existing foreground realtime refreshes advance private advice work with a 3 ms deadline and a hard 512-completion limit. Finished advice is cached. Holds and Draw remain usable. Session reset, changed hand/context, removed hat and leaving Hold cancel partial work without callbacks or stale publication. Cancellation followed by reentry reproduces the same advice.

Numeric scratch cards and scalar payout classification remove per-completion descriptor allocation. Settlement/display evaluation, paytables, progressive/sequential bonuses, sample and RNG order, tie-breaks, run state, saves and autonomous animation scheduling are unchanged. No host code changed.

## Passed evidence

- Final native: 82,180 numeric payout cases, 1,083 legacy payout cases and 96 exact mask EVs match the retained old oracle. All variants, tiers/bets, wild/rank shapes, ordering, duplicate/missing rows and progressive/sequential bonuses are covered.
- Final native incremental: all 96 mask EVs and expanded lifecycle cases pass. Cold projections are 0.79-1.02 ms; largest projection is 3.85 ms. The run/hand remain unchanged. Required no-pointer animation liveness passes.
- Final Web incremental: 96 exact EVs, cache/read-only state, cancellation/reentry, actual hand replacement, item removal and hard completion bounds pass.
- The maintained focused video_poker_game_suite passes in 21.1 seconds, including existing hat, win-heat, double-up and RTP checks. This is not an aggregate suite pass.
- Rendered production FoundationMain Web flow passes ordinary pointer Deal, Hold while pending, completed advice, Draw, second Deal and early Draw after the normal 760 ms flip guard. First Hold paints in 69.8 ms with zero prior advice completions; early Draw clears the job. Four reviewed screenshots and error-free browser receipt are retained. This run preceded timing-only instrumentation; its product hash is recorded in JSON.

## Unresolved boundary

The standalone Web harness recorded unexplained wall-time outliers: 307 ms cold setup, 344 ms step, and a final 188 ms step. Most projections are about 4 ms, but the work bound does not establish a 50 ms wall-time guarantee. Do not claim responsiveness fully qualified.

The final timing-instrumented rendered retry hit its 150-second bound after scene-added and before a ready fixture, so its live timing gate was not executed. No startup/product failure attribution is made. Qualify the exact deployed NEXT payload under the real environment before closing this objective.

Aggregate validation is separately blocked by an unrelated WindowsPowerShell Get-FileHash failure in hostile launcher validation. A broad direct attempt timed out in content; an initial filter used an unregistered name. Final qualification uses the supported registered game-suite filter and preserves those failures.

All runs use synthetic disposable E-drive storage and capped Jobs. Accepted workers exit 0 with zero owned processes at release. Source/PCK hashes, commands, exact reports, failed receipts and cleanup are in the matching JSON file. Original personal saves and browser profiles were not accessed. The whole-game performance audit remains Open.
