from __future__ import annotations

from beat_the_house.games import build_games_for_floor
from beat_the_house.progression import (
    MetaStore,
    buy_upgrade,
    create_run,
    evaluate_meta_unlocks,
    offer_shop,
)


def choose_int(prompt: str, minimum: int, maximum: int) -> int:
    while True:
        raw = input(prompt).strip()
        if raw.isdigit():
            value = int(raw)
            if minimum <= value <= maximum:
                return value
        print(f"Enter a number between {minimum} and {maximum}.")


def play_floor(state) -> bool:
    print(f"\n=== FLOOR {state.floor} ===")
    games = build_games_for_floor(state.floor)

    while state.day_actions_left > 0 and not state.busted():
        print(
            f"\nBankroll ${state.bankroll} | Heat {state.heat}/{state.suspicion_limit} | Actions left {state.day_actions_left}"
        )
        for idx, game in enumerate(games, start=1):
            print(f"  {idx}. {game.name}")

        game_choice = choose_int("Choose game: ", 1, len(games))
        wager_max = max(1, min(25, state.bankroll))
        wager = choose_int(f"Wager (1-{wager_max}): ", 1, wager_max)

        result = games[game_choice - 1].play(state, wager)
        state.update_bankroll(result.bankroll_delta)
        state.add_heat(result.heat_delta)
        state.spend_action()
        print(f"{result.summary} | Δ${result.bankroll_delta} | +{result.heat_delta} heat")

    if state.busted():
        print("You were caught or went broke. Run ends.")
        return False

    print("Day over. Time to visit the black-market shop.")
    return True


def run_shop(state, meta) -> None:
    offers = offer_shop(state, meta)
    if not offers:
        print("No upgrades unlocked yet.")
        return

    print("\nShop offers:")
    for idx, item in enumerate(offers, start=1):
        permanence = "perm" if item.permanent else "temp"
        print(f"  {idx}. {item.name} (${item.cost}, {permanence}) - {item.description}")
    print("  0. Skip")

    choice = choose_int("Buy item #: ", 0, len(offers))
    if choice == 0:
        return

    item = offers[choice - 1]
    if buy_upgrade(state, item):
        print(f"Purchased {item.name}.")
    else:
        print("Not enough bankroll.")


def main() -> None:
    print("Beat The House (Standalone Prototype)")
    store = MetaStore()
    meta = store.load()
    print(
        f"Meta: runs={meta.total_runs}, max_floor={meta.max_floor_reached}, tokens={meta.prestige_tokens}"
    )

    state = create_run(meta)
    keep_going = True
    while keep_going:
        survived = play_floor(state)
        if not survived:
            break

        run_shop(state, meta)
        if state.bankroll >= 100 * state.floor:
            state.floor += 1
            state.day_actions_left = 8
            state.heat = max(0, state.heat - 20)
            print(f"Traveling to floor {state.floor}.")
        else:
            keep_going = False
            print("You cash out for this run.")

    evaluate_meta_unlocks(meta, state.floor, state.bankroll)
    store.save(meta)
    print(
        f"Run complete: floor {state.floor}, bankroll ${state.bankroll}. Total runs now {meta.total_runs}."
    )


if __name__ == "__main__":
    main()
