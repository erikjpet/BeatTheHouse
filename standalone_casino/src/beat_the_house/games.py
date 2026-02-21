from __future__ import annotations

from dataclasses import dataclass
from beat_the_house.models import RunState


@dataclass
class GameResult:
    summary: str
    bankroll_delta: int
    heat_delta: int


class CasinoGame:
    name: str = "unknown"

    def play(self, state: RunState, wager: int) -> GameResult:
        raise NotImplementedError


class SlotsGame(CasinoGame):
    name = "slots"
    symbols = ["bar", "barbar", "barbarbar", "7", "cherry", "bell"]

    def play(self, state: RunState, wager: int) -> GameResult:
        weighted = list(self.symbols)
        if "lucky_coin" in state.all_upgrades:
            weighted += ["7", "7"]

        reels = [state.rng.choice(weighted) for _ in range(3)]
        heat = 2
        payout = -wager

        if len(set(reels)) == 1:
            match reels[0]:
                case "7":
                    payout = wager * 10
                    heat += 7
                case "barbarbar":
                    payout = wager * 5
                case "barbar":
                    payout = wager * 4
                case "bar":
                    payout = wager * 3
                case "bell":
                    payout = wager * 2
                case "cherry":
                    payout = wager
        return GameResult(
            summary=f"Reels: {' | '.join(reels)}",
            bankroll_delta=payout,
            heat_delta=heat,
        )


class DiceGame(CasinoGame):
    name = "dice"

    def play(self, state: RunState, wager: int) -> GameResult:
        player = [state.rng.randint(1, 6) for _ in range(5)]
        house = [state.rng.randint(1, 6) for _ in range(5)]

        if "loaded_dice" in state.all_upgrades:
            player[state.rng.randrange(5)] = 6

        p_score = sum(player)
        h_score = sum(house)
        payout = -wager
        heat = 3

        if p_score > h_score:
            payout = wager * 2
        elif p_score == h_score:
            payout = 0

        return GameResult(
            summary=f"You {player} ({p_score}) vs House {house} ({h_score})",
            bankroll_delta=payout,
            heat_delta=heat,
        )


class PullTabsGame(CasinoGame):
    name = "pull_tabs"

    def play(self, state: RunState, wager: int) -> GameResult:
        roll = state.rng.random()
        heat = 1
        payout = -wager

        if roll < 0.05:
            payout = wager * 8
        elif roll < 0.20:
            payout = wager * 3
        elif roll < 0.45:
            payout = wager

        if "insider_tips" in state.all_upgrades:
            payout += wager // 2
            heat += 2

        return GameResult(
            summary=f"Pull-tab roll: {roll:.2f}", bankroll_delta=payout, heat_delta=heat
        )


class BlackjackGame(CasinoGame):
    name = "blackjack"

    def play(self, state: RunState, wager: int) -> GameResult:
        player = state.rng.randint(12, 21)
        house = state.rng.randint(14, 22)

        if "ace_up_sleeve" in state.all_upgrades and player < 21:
            player += 1

        payout = -wager
        heat = 5
        if player > 21:
            payout = -wager
        elif house > 21 or player > house:
            payout = wager * 2
        elif player == house:
            payout = 0

        return GameResult(
            summary=f"Blackjack totals: you {player}, house {house}",
            bankroll_delta=payout,
            heat_delta=heat,
        )


class RouletteGame(CasinoGame):
    name = "roulette"

    def play(self, state: RunState, wager: int) -> GameResult:
        chosen = state.rng.randint(0, 36)
        landed = state.rng.randint(0, 36)
        payout = -wager
        heat = 4

        if chosen == landed:
            payout = wager * 35
            heat += 8
        elif chosen % 2 == landed % 2:
            payout = wager

        if "magnet_watch" in state.all_upgrades and payout < 0:
            payout = 0
            heat += 4

        return GameResult(
            summary=f"Bet {chosen}; landed {landed}", bankroll_delta=payout, heat_delta=heat
        )


def build_games_for_floor(floor: int) -> list[CasinoGame]:
    games: list[CasinoGame] = [SlotsGame(), PullTabsGame(), DiceGame()]
    if floor >= 2:
        games.append(BlackjackGame())
    if floor >= 3:
        games.append(RouletteGame())
    return games
