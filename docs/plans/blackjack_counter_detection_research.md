# Blackjack counter detection research and implementation model

## Decision summary

Beat the House should not treat the private act of keeping an accurate count as observable misconduct. Casino staff can observe wagers, playing decisions, session patterns, repeat visits, and conspicuous physical behavior; they cannot directly observe a mental running count. The game therefore models counter detection as a rolling evidence problem rather than a Heat award attached to finishing a count challenge.

The implemented model has four binding rules:

1. Accurate counting with a flat wager adds no counter Heat or detection chance, even across many hands.
2. A wager that grows when the shoe becomes favorable, or shrinks when it cools, begins to add evidence. Strong count-to-bet correlation only becomes eligible after at least six observed counted hands.
3. One missed count pulse is a small tell. Multiple errors in a hand or repeated error hands create meaningful but capped Heat.
4. Count-sensitive strategy deviations remain observable evidence, especially when paired with a large wager, but they are assessed at hand settlement rather than when the player merely records a count.

This is a simulation model, not a claim that casinos use one universal numerical threshold. The thresholds below are design judgments chosen to reproduce the sequence described by the evidence: observation, pattern formation, evaluation, then possible intervention.

## What casinos can actually see

The strongest published technical evidence models detection by combining card recognition with chip-stack recognition and then correlating wagers with the count over time. Zutis and Hoey explicitly describe temporal analysis of plays and bets, and report that changing bet size accounts for roughly 70–90% of a counter's edge while playing deviations account for the remainder.[1] DeepGamble follows the same structure: it digitizes cards, bets, and player decisions, then evaluates the relationship between the player's betting pattern and the scaled count.[2]

That matters for game design. Clicking the correct bubbles represents cognition and attention, not something a dealer can prove from one settled hand. The observable tell is what the player does with the information. A flat bettor can maintain a perfect count without creating the wager correlation these monitoring systems are designed to detect.

Operational accounts support a multi-stage process rather than instant certainty. A long-serving Las Vegas surveillance director described the usual trigger as a pit call or a pattern across repeated winning trips. The evaluation then checks basic-strategy competence, wager spread, whether wagers move with the count, and count-dependent deviations. The same account says a useful evaluation generally watches one or two shoes for a favorable count and notes what the player does then.[3] That is materially different from adding large Heat every time one hand's count is settled.

The most conspicuous signals reinforce one another. A surveillance professional interviewed by Blackjack Apprenticeship explains that a high wager plus a count-sensitive play such as splitting tens causes surveillance to reconstruct the count and review the pattern; repeating that combination at high positive counts is much more revealing than the isolated choice.[4] A March 2026 interview with a former advantage player working in surveillance similarly identifies table-game review, insurance and other key deviations, unusual buy-in/chip behavior, and identity refusal as practical indicators used during a rundown.[5]

Winning alone is insufficient evidence. The surveillance interview says a large win does not automatically produce a counter finding when wager spread and skilled play are absent, and a player whose evaluation finds only luck may continue to play while the house uses ordinary defensive measures.[3] The model should therefore never infer counter behavior merely from payout or count accuracy.

## Legal and semantic distinction

Nevada case law distinguishes using one's skill and the information naturally exposed by play from manipulating a game. In *Childs v. State*, the Nevada Supreme Court summarized its earlier conclusion that mental card counting and taking advantage of an accidentally exposed dealer card were not cheating under the cited cheating statute because the player used skill and what play afforded.[6] Nevada separately prohibits devices or software used with intent to assist card counting; the Gaming Control Board has issued an industry notice specifically warning about that device statute.[7]

Beat the House can still call counting an “advantage action” and allow a private casino to back the player off. It should not mechanically equate an accurate mental count with a caught physical cheat such as hole-card peeking. In particular, the old shared caught bonus was semantically wrong: it could add the same large penalty used for blatant cheating after a single imperfect count.

## False positives and the need for a sample

Bet variation is important but not complete proof. The 2026 UNLV conference abstract on disguised coordinated advantage play notes that fixed wagers and the absence of individual bet/count correlation defeat standard heuristics based on bet variation, individual correlation, or profit and loss.[8] This is useful negative evidence: a realistic system should allow low-observability play to last, while a game system should not invent certainty from an internal count value.

Short sessions are also noisy. The surveillance director notes that short-session software can be misled by camouflage, which is why trained review and longer observation remain important.[3] The implementation uses a minimum of six counted hands before ordinary bet/count evidence can roll a detection chance. Six is intentionally shorter than a real one-to-two-shoe evaluation so the mechanic can resolve during a game session, but it preserves the essential requirement that a pattern must exist first.

## Implemented surveillance state

Each Blackjack table now persists a bounded rolling profile:

- total counted hands observed;
- the latest 24 `{count, bet}` samples;
- cumulative evidence points;
- consecutive count-error hands; and
- a compact last-assessment record for diagnostics and tests.

The window is bounded so evaluation cost and save size do not grow with a long play session. Twenty-four samples are sufficient to include many hands and changes in shoe conditions without retaining an unbounded history.

For each counted hand, the model records the true count available when the wager was placed and the wager itself. It evaluates:

- a meaningful wager increase at a count of +2 or higher;
- a meaningful wager decrease after a favorable shoe cools;
- a smaller signal when both count and wager rise materially;
- Pearson correlation across the rolling sample, only after six observations and at least a 2:1 spread; and
- missed pulses, wrong count distance, bad/late hits, and consecutive error hands.

Strong correlated ramps generate material Heat and a bounded detection chance. Flat wagers have zero bet variance, so their correlation is deliberately zero and they cannot create counter evidence. A single missed pulse adds one Heat and no detection chance. Multiple/repeated misses reach a per-hand cap of six, preventing one interaction failure from racing the global meter to its top bands.

Count settlement is assessed exactly once. Recording the answer now preserves the hand and adds zero Heat; the eventual hand settlement combines the count outcome with the wager and decisions. Previously, a standalone “record count” resolution could assess Heat, and the hand settlement could assess the same challenge again. Removing that double boundary is as important as retuning the numbers.

## UI performance finding

Count bubbles activate on pointer entry. Before this change, every claim entered the general sealed Blackjack transaction path. That path is appropriate for wagers and settlements: it can isolate a candidate run, normalize the complete Blackjack table, validate its authority ledger, and publish a safe result. A count pulse, however, changes only the already sealed transient table session. It spends no funds, advances no environment turn, consumes no RNG, and issues no economic result.

The new path validates the existing authority ledger in place, deep-copies only the small session being changed, invokes a closed Blackjack-owned handler that accepts only `blackjack_count_icon`, rejects any command that attempts to resolve or name an economic action, and stages the new session back into the same table. The economic boundary remains fail-closed while the expensive world/table copy is removed from hover.

The performance regression uses a late-run-shaped history and 48 live pulses. The optimized host processed all 48 claims in approximately 38 ms on the development machine (under 1 ms per claim); the intermediate implementation that still normalized the table took approximately 2.3 seconds for the same fixture. The automated budget is deliberately loose at 250 ms total to remain stable on slower CI hardware.

## Acceptance scenarios

The implementation is accepted only if all of these remain true:

- at least sixteen accurate flat-bet counted hands add zero Heat, zero evidence, and zero catch chance;
- a sustained wager ramp from minimum bets into +2 through +5 counts produces strong positive correlation, meaningful Heat, and eventual detection eligibility;
- the first isolated missed pulse is minor, while repeated/multiple misses become meaningful without exceeding the six-Heat per-hand error cap;
- the rolling sample never exceeds 24 entries while the lifetime observation counter continues to advance;
- merely recording an accurate or inaccurate answer adds no Heat before the hand settles;
- hover still claims each pulse once on entry and again only after exit/re-entry; and
- the session-only authority path claims every supplied pulse inside its performance budget without weakening economic action authority.

## Sources

1. Krists Zutis and Jesse Hoey, [“Who’s Counting?: Real-Time Blackjack Monitoring for Card Counting Detection”](https://cs.uwaterloo.ca/~jhoey/papers/zutis_hoey_blackjack09.pdf), *Computer Vision Systems*, 2009.
2. Danish Syed et al., [“DeepGamble: Towards unlocking real-time player intelligence using multi-layer instance segmentation and attribute detection”](https://arxiv.org/abs/2012.08011), 2020.
3. Arnold Snyder, [“Surveillance Talks”](https://www.lasvegasadvisor.com/gambling-with-an-edge/surveillance-talks/), interview with a Las Vegas surveillance director, *Blackjack Forum* archive.
4. Colin Jones, [“Behind the Black Dome Interview”](https://www.blackjackapprenticeship.com/behind-the-black-dome-interview/), interview with surveillance professional T. Dane.
5. Blackjack Apprenticeship Podcast, [“Ex-AP Turned Casino Surveillance Reveals How They Catch Card Counters”](https://bjapodcast.podbean.com/e/ex-ap-turned-casino-surveillance-reveals-how-they-catch-card-counters-bja180/), March 25, 2026.
6. Supreme Court of Nevada, [*Childs v. State*, 816 P.2d 1079](https://law.justia.com/cases/nevada/supreme-court/1991/21373-1.html), 1991.
7. Nevada Gaming Control Board, [Industry Notice on card-counting devices and NRS 465.075](https://gaming.nv.gov/uploadedFiles/gamingnvgov/content/about/industry-notices/2009-02-05-.pdf), February 5, 2009.
8. University of Nevada, Las Vegas International Gaming Institute, [“On Parrondo’s Paradox and Disguised Advantage Play in Blackjack”](https://oasis.library.unlv.edu/gaming_institute/2026/May26/47/), 2026 conference abstract.
