class_name ScenarioSequenceRolloutManifest
extends RefCounted

const EXPECTED_COUNT := 55
const CATALOG_IDS := [
	"back_alley_cruiser_parked", "back_alley_fence_night", "back_alley_nothing_moving", "back_alley_street_craps",
	"bar_darts_league_night", "bar_dead_tuesday", "bar_fight_night", "bar_live_band", "bar_lock_in", "bar_payday_rush", "bar_wake",
	"beach_bonfire_night", "beach_festival_weekend", "beach_storm_coming",
	"corner_store_aftermath", "corner_store_dead_shift", "corner_store_delivery_day", "corner_store_inventory_night", "corner_store_lotto_fever",
	"delta_queen_captains_invitational", "delta_queen_engine_trouble", "delta_queen_fog_delay", "delta_queen_wedding_charter", "delta_queen_whale_aboard",
	"gas_station_graveyard_shift", "gas_station_road_crew_payday", "gas_station_storm_shelter", "gas_station_tour_bus_stop", "gas_station_trucker_convoy",
	"grand_casino_audit_night", "grand_casino_convention_crowd", "grand_casino_gala_night",
	"jazz_club_guest_legend", "jazz_club_recording_night", "jazz_club_rent_party", "jazz_club_union_trouble",
	"kitty_cat_lounge_amateur_night", "kitty_cat_lounge_bachelorette_storm", "kitty_cat_lounge_buyout", "kitty_cat_lounge_slow_night",
	"motel_conventioneers", "motel_stakeout", "motel_wedding_overflow", "motel_weekly_rates",
	"pawn_shop_estate_lot_day", "pawn_shop_sals_mood", "pawn_shop_serial_check_day",
	"punchline_bringer_show", "punchline_debt_court", "punchline_greased_week", "punchline_headliner_night", "punchline_high_stakes_night", "punchline_new_muscle", "punchline_open_mic_night", "punchline_raid_jitters",
]
const SEQUENCE_REQUIRED_IDS := []


static func expected_ids() -> Array:
	return CATALOG_IDS.duplicate()


static func required_sequence_ids() -> Array:
	return SEQUENCE_REQUIRED_IDS.duplicate()
