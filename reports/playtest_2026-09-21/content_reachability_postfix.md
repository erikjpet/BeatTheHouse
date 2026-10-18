# Beat the House — Post-Fix Content Reachability and Composition Audit

**Test date:** 2026-09-21  
**Audited revision:** `b7c51bf4749422c434e9689b02852084d66ac192` (`b7c51bf4 Remediate code health audit findings`)  
**Method:** static-only data and production-consumer audit; no Godot process launched  
**Product fixes made:** none

## Executive summary

The final content-composition wave found one new, supportable Low-severity defect: the Craps dice-switching bonus accepts an item ID, `precision_loaded_dice`, that has no item definition or acquisition path anywhere in the project. The other configured option, `mags_loaded_dice`, is valid and reachable, so the core action and its bonus are not wholly blocked. The defect is a dead authored bonus source and a content-validation coverage gap.

No other dangling production IDs, impossible same-gate prerequisites, mutually contradictory flag gates, orphaned scenario overlays, unreachable authored event definitions, negative service costs, or unsupported lender/economy values were identified in the audited scope.

| ID | Severity | Confidence | Summary |
| --- | --- | --- | --- |
| CR-PF-001 | P3 / Low | High; deterministic source trace and repository-wide definition search | Craps lists nonexistent `precision_loaded_dice` as a valid source of the loaded-dice switching bonus. |

## Scope and method

The audit covered these production catalogs and their consumers:

| Content family | Definitions audited | Cross-checks |
| --- | ---: | --- |
| Items | 89 | direct grants, offers, prizes, recipes, repair targets, synergy requirements, game-specific item gates, content groups |
| Services | 18 | archetype pools, scenario additions, event effects, costs and rewards |
| Lenders | 5 | archetype hooks, required hooks, event references, debt terms and rewards |
| Events | 159 | archetype pools, required events, event-to-event triggers, character encounters, scenarios, items, games and lenders |
| Environment archetypes | 18 | game/item/event/service/lender pools, required IDs, next destinations, rare destinations and travel hooks |
| Legacy scenarios | 55 across 12 archetype keys | weights, archetype ownership, exclusive opportunity IDs, mutation references and authored gates |
| Scenario sequence overlays | 55 | one-to-one coverage of legacy scenarios, duplicate IDs, authoring references, phase/objective/branch composition |
| Games | 11 | module routing, content pools, game-specific item and dialogue references, prerequisite arrays |
| Travel routes | 12 | destination archetypes, free-from archetypes and authored prices |
| Crew recruitment and jobs | all authored entries | member, event, contact-event, archetype, scenario, game and target-node references |

The pass also recursively compared co-located `requires_flags`/`missing_flags`/`blocked_by_flags`, required/blocked item sets, and required/blocked game sets for direct contradictions. It reviewed the authored economy audit at `data/economy/content06_1_audit.json`, item buy/sell bands, service costs/rewards, route costs, and lender terms for static inconsistencies. Values that are intentionally free rewards, crafted crew gear, scenario souvenirs, telemetry identifiers, or local ritual parameter placeholders were not misclassified as dangling production content.

## CR-PF-001 — Craps loaded-dice bonus contains a nonexistent item ID

**Severity:** P3 / Low  
**Type:** dangling content reference, unreachable authored content, validation gap  
**Affected system:** Craps dice switching  
**Confidence:** High

### Player impact

One of the two item identities configured to award the Craps dice-switching loaded-dice bonus can never be owned, spawned, purchased, crafted, or awarded. A player can still receive the bonus through the valid `mags_loaded_dice` item, so this does not block the action or make the bonus globally unavailable. It does, however, leave dead configuration in a player-facing game mechanic and creates ambiguity about whether a missing item/reward path was intended.

### Evidence

The Craps definition lists both `precision_loaded_dice` and `mags_loaded_dice` in `craps_config.switching.loaded_dice_item_ids`:

- `data/games/games.json:3585-3594`

The production Craps module reads that exact array and awards the configured bias bonus when the run owns any listed item:

- `scripts/games/craps.gd:1006-1015`

`mags_loaded_dice` is a real item with a complete production path:

- Item definition: `data/items/items.json:1991-1993`
- Mags' Bench recipe output: `data/events/events.json:4541-4545`
- Crew-gear content group: `data/content_groups/groups.json:188-192`

In contrast, a repository-wide exact search finds `precision_loaded_dice` only in the Craps configuration entry. It has no item-catalog row, art manifest entry, content group, offer, event reward, recipe, starting inventory path, or scripted grant.

### Deterministic reproduction

1. Enumerate every item definition in `data/items/items.json` and every item-producing offer, prize, recipe, and scripted grant.
2. Observe that none defines or produces `precision_loaded_dice`.
3. Inspect the Craps switching configuration and observe that `precision_loaded_dice` is nevertheless listed as a qualifying loaded-dice item.
4. Follow `scripts/games/craps.gd:1014`: the bonus is conditional on `_has_any_item()` matching one of those strings in the live inventory.
5. Because no production path can place `precision_loaded_dice` in that inventory, this branch can never match that configured identity.

### Expected result

Every item identity used by a production game mechanic should resolve to a defined, reachable item, or the configuration should contain only the intended valid identities.

### Actual result

`precision_loaded_dice` is accepted by the game-specific configuration but is absent from the item catalog and all acquisition sources.

### Root cause

The generic game validator checks content-group tags, module paths, and legal/cheat action shape, but does not validate game-specific nested content references. In `scripts/core/content_library.gd:1784-1797`, `_validate_game_definitions()` never traverses or checks `craps_config.switching.loaded_dice_item_ids` against the item catalog. This allows a stale, renamed, or never-created item ID to survive otherwise successful content validation.

The likely authoring history is a superseded design name: `precision_loaded_dice` remained in the Craps tuning data while the implemented crew-crafted item shipped as `mags_loaded_dice`. That history is an inference from the definitions; the missing reference itself is directly established.

### Fix options

1. If both item variants are intended, add a complete `precision_loaded_dice` item definition and an explicit acquisition path.
2. If Mags' item replaced the earlier concept, remove `precision_loaded_dice` from `loaded_dice_item_ids`.
3. If the entry was meant to name a different existing item, replace it with that canonical item ID and verify the intended balance.
4. Extend content validation to recursively or explicitly verify game-specific item-reference fields such as `required_item_ids`, `practice_item_ids`, and `loaded_dice_item_ids` against the item catalog. A focused contract should fail on an unknown configured ID.

### Regression checks

- Content loading reports an error for an unknown ID in any game-specific item-reference array.
- Every remaining `loaded_dice_item_ids` entry has a catalog definition and at least one intended acquisition path.
- Owning each configured loaded-dice item independently awards exactly the authored `loaded_dice_bias_bonus_permille` on a successful dice-switching attempt.
- Owning neither configured item does not award that bonus.

## Clean audit results

The following suspicious-looking cases were traced and are not defects:

- `mags_loaded_dice` is intentionally absent from ordinary shop price bands because it is produced by Mags' Bench; its item definition, recipe, art, and content group agree.
- `pile_of_pull_tabs`, `pile_of_scratch_tickets`, and `show_drummer_glasses` are referenced through code-owned special service/reward paths rather than ordinary event-pool data.
- Apartment, house, motel-room, and Grand Casino subroom archetypes are entered through special room/transition logic rather than the ordinary public travel graph.
- Zero-price scenario souvenirs are free event rewards with deliberately nonzero resale values; the economy audit describes the resale band as a small, one-resolution source rather than a repeatable income route.
- Scenario sequence `event_id`, `service_id`, and `game_id` values used in telemetry predicates can be local fact payload values rather than catalog references; these were separated from production launch/grant references.
- Ritual schema values such as `qualified_id` are parameter type placeholders, not item IDs.

No additional supportable defect was found in:

- archetype game, item, event, service, or lender pools;
- required-event, required-game, and required-lender hooks;
- scenario-to-archetype ownership, weights, mutations, exclusive opportunities, and 55 sequence overlays;
- travel destinations and free-route origins;
- crew recruitment, contacts, jobs, venue targets, and reward references;
- item repair and synergy references;
- direct mutually exclusive prerequisite/blocked flag combinations;
- authored negative costs or direct static buy/sell arbitrage in the reviewed item, service, lender, route, and release-0.6 economy metadata.

## Release recommendation

CR-PF-001 is not a release blocker by itself because `mags_loaded_dice` preserves the player-accessible bonus path. It should be corrected during the next content-integrity pass, and the validator should be expanded at the same time so future nested game-specific references cannot silently become dead content.
