from beat_the_house.games import SlotsGame, DiceGame
from beat_the_house.models import RunState


def test_slots_returns_result_shape():
    state = RunState(seed=123)
    result = SlotsGame().play(state, wager=2)
    assert isinstance(result.summary, str)
    assert result.heat_delta >= 2


def test_loaded_dice_pushes_score_upward():
    base_state = RunState(seed=9)
    rigged_state = RunState(seed=9)
    rigged_state.permanent_upgrades.add("loaded_dice")

    base = DiceGame().play(base_state, wager=5)
    rigged = DiceGame().play(rigged_state, wager=5)

    assert rigged.bankroll_delta >= base.bankroll_delta
