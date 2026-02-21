from beat_the_house.progression import MetaProgression, evaluate_meta_unlocks


def test_unlocks_from_successful_run():
    meta = MetaProgression()
    evaluate_meta_unlocks(meta, completed_floor=3, final_bankroll=200)

    assert meta.total_runs == 1
    assert "ace_up_sleeve" in meta.unlocked_upgrades
    assert "insider_tips" in meta.unlocked_upgrades
    assert "magnet_watch" in meta.unlocked_upgrades
