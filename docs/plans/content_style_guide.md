# Beat the House Content Style Guide

Status: active for the unreleased v0.4 Act 1 release-path content.

This guide defines the release voice and copy guardrails for player-facing text
in `data/` and obvious release-path script constants. It complements the
existing compact-copy validators under `scripts/tests/foundation/`.

## Release Voice

Beat the House speaks in terse casino noir:

- Short, concrete, and playable.
- Stakes are readable before the player commits.
- Consequences are implied through heat, debt, money, time, and access.
- Rooms feel grounded: counters, felt, smoke, neon, rain, uniforms, doors.
- The house is a pressure system, not a cartoon villain.
- The player is chasing survival, not real-world gambling profit.

Avoid:

- TODO, placeholder, dev-only, test-only, debug-only, or "coming soon" copy.
- Real-money gambling framing, cash-prize framing, monetization language, or
  anything that sounds like a real gambling product.
- Promising Act 2 content from Act 1 release screens.
- Long jokes, lore dumps, and explanatory paragraphs inside compact UI panels.
- Exact stat spoilers in item descriptions when glyphs or structured UI already
  communicate the mechanical class.

## Length Rules

The existing foundation validators are the hard UI limits:

| Copy type | Limit |
| --- | ---: |
| Item/game/route/service/lender descriptions | 8 words |
| Event summaries | 8 words |
| Event start summaries | 10 words |
| Environment visual descriptions | 8 words |
| Compact description strings | 72 characters |

Longer explanation belongs in structured mechanics, result messages, or docs,
not small labels.

## Environments

Environment names should be specific places, not feature labels:

- Prefer "Corner Store", "Delta Queen", "Kitty Cat Lounge".
- Avoid "Shop Level", "Tier 2 Venue", "Debug Room".
- Descriptions should name the room texture or pressure in one beat.
- Visual context may carry era, sound, crowd, and lighting, but player-facing
  labels stay short.

Travel/world-map text may hint at risk, price, scouting, lockouts, or access,
but it should not promise exact hidden outcomes.

## Events And Choices

Events should read as a decision at the table or in the room:

- Summary: what is happening.
- Choice label: what the player does.
- Choice description: the visible bargain.
- Result message: what changed, with enough context to trust the result.

Use plain verbs: pay, duck out, take the drink, press, leave, count, palm, ride.
Do not expose internal trigger names, test ids, or implementation states.

## Services, Lenders, And Debt

Service copy should make the cost and category legible without overexplaining
the math. Lender copy should feel like pressure:

- Keep lender names human or institutional.
- State debt plainly as debt, interest, collateral, favors, or pawn value.
- Do not make loans feel like a real financial product.
- Avoid exact formula prose unless the UI is already showing the number.

Debt result messages should name the new obligation and the immediate relief.

## Travel And World Map Routes

Routes are paths through the city, not menu teleporters:

- Name the destination or route mood.
- Surface cost, lock, or danger through structured UI and short text.
- Scouting copy can preview likely games, services, or heat.
- Route-risk events should feel like street pressure, not random punishment.

## Items, Collections, And Bags

Item descriptions should be short object fantasies:

- "Warm drink. Steady hands."
- "Old frames. Cooler face."
- "Marked edge, risky pocket."

Do not put full stat changes in the description. Use glyphs, detail panels,
cost fields, and result messages for mechanics. Collection items can mention
condition and theme, but not future marketplace or real-money value.

Bag copy should describe opening, rarity, and collection flavor. It must not
sound like paid loot boxes or gambling monetization.

## Profile And Meta Text

Profile copy covers local progress only:

- Challenge flags, collection ownership, run history, and settings.
- No platform inventory promises unless the platform feature is shipped.
- No Act 2 unlock promises in v0.4 release-path copy.
- No real-money trading, marketplace, or cash-out language.

If a feature is dormant, hide it or describe it as absent in docs, not in
player-facing UI.

## Terminal Victory And Failure Summaries

Terminal copy should state the ending and preserve the run story:

- Victory: the player leaves the Grand Casino by the clean Players Card route
  or by surviving Rourke's back-room pressure.
- Failure: name the cause without a lecture.
- Keep future-act seams deliberate and non-placeholder.

The Act 2 seam is deliberately diegetic: Players Card victories imply opened
doors, while showdown victories imply Rourke remembers the player. Release copy
checks no longer tolerate "not implemented" text in Grand Casino success paths.

## Simulated-Gambling Safety Copy

Beat the House is a single-player casino roguelike, not a gambling product.
Public and in-game safety copy should stay consistent:

- No real-money wagering.
- No cash prizes.
- No gambling monetization.
- No store credentials or payment calls in source.
- Odds, payouts, and risk are game simulation, not real betting advice.

Use "bankroll", "stake", "debt", "heat", and "run" for fiction. Avoid "deposit",
"withdraw", "cash prize", "real-money", and similar product language.

## Audit Checklist

Before release:

1. Run `rg` for TODO, placeholder, not implemented, coming soon, debug-only,
   dev-only, and test-only in `data/` and release-path scripts.
2. Confirm only documented follow-ups remain.
3. Run `tools/validate_project.ps1`.
4. Run the relevant `check_godot.ps1` foundation suites.
5. Archive the owning prompt with the exact gate evidence.
