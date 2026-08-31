extends SceneTree

const PLAYS_PATH := "res://data/crew/plays.json"
const EXPECTED_GOVERNING_SHA256 := "0886fe9e677437e54c6884398e74432a7e7fa3585134a26beac64090b53e9e1e"
const EXPECTED_GAMES := {
	"spotter": ["blackjack"],
	"distraction": ["blackjack", "baccarat", "roulette", "craps", "video_poker"],
	"big_player": ["blackjack"],
	"chip_dump": ["baccarat"],
	"table_flood": ["blackjack", "baccarat", "roulette", "craps", "video_poker"],
}


func _initialize() -> void:
	var failures: Array = []
	var rows := _load_array(PLAYS_PATH)
	if rows.size() != 1 or typeof(rows[0]) != TYPE_DICTIONARY:
		failures.append("plays.json must retain exactly one root object.")
	else:
		var root: Dictionary = rows[0]
		var governing := root.duplicate(true)
		var stripped_plays: Array = []
		for play_value in root.get("plays", []):
			var play: Dictionary = (play_value as Dictionary).duplicate(true)
			_check_semantics(play, failures)
			play.erase("semantics")
			stripped_plays.append(play)
		governing["plays"] = stripped_plays
		var governing_hash := JSON.stringify(_canonical(governing)).sha256_text()
		if governing_hash != EXPECTED_GOVERNING_SHA256:
			failures.append("Existing governing play catalog changed: expected %s found %s." % [EXPECTED_GOVERNING_SHA256, governing_hash])
		_check_chip_dump(root, failures)
	if failures.is_empty():
		print("world06_5 plays authored semantics contract passed plays=5 game_surfaces=13 governing_values=unchanged")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_semantics(play: Dictionary, failures: Array) -> void:
	var play_id := str(play.get("id", ""))
	if not EXPECTED_GAMES.has(play_id) or play.get("game_ids", []) != EXPECTED_GAMES.get(play_id, []):
		failures.append("Play %s changed or omitted its exact game_id scope." % play_id)
		return
	var semantics: Dictionary = play.get("semantics", {}) if typeof(play.get("semantics", {})) == TYPE_DICTIONARY else {}
	var semantic_keys := semantics.keys(); semantic_keys.sort()
	if semantic_keys != ["actor_role", "games"] or str(semantics.get("actor_role", "")).is_empty():
		failures.append("Play %s lacks its closed actor/game semantic descriptor." % play_id)
		return
	var games: Dictionary = semantics.get("games", {}) if typeof(semantics.get("games", {})) == TYPE_DICTIONARY else {}
	var game_keys := games.keys(); game_keys.sort()
	var expected_keys: Array = (EXPECTED_GAMES.get(play_id, []) as Array).duplicate(); expected_keys.sort()
	if game_keys != expected_keys:
		failures.append("Play %s semantics do not cover every exact game_id." % play_id)
	for game_id in expected_keys:
		var descriptor: Dictionary = games.get(game_id, {}) if typeof(games.get(game_id, {})) == TYPE_DICTIONARY else {}
		var keys := descriptor.keys(); keys.sort()
		if keys != ["aftermath", "arrival", "detected", "leave", "object_role", "place_role", "public_verbs", "work"]:
			failures.append("Play %s/%s lacks the closed arrival/work/detected/leave/aftermath descriptor." % [play_id, game_id])
			continue
		for key in ["aftermath", "arrival", "detected", "leave", "object_role", "place_role", "work"]:
			if str(descriptor.get(key, "")).strip_edges().is_empty(): failures.append("Play %s/%s has empty %s semantics." % [play_id, game_id, key])
		var verbs: Array = descriptor.get("public_verbs", []) if typeof(descriptor.get("public_verbs", [])) == TYPE_ARRAY else []
		if verbs.size() < 4 or str(verbs[0]) != "arrive" or str(verbs[-1]) not in ["leave", "withdraw"]:
			failures.append("Play %s/%s lacks public arrival/work/leave verbs." % [play_id, game_id])
	if _contains_number(semantics): failures.append("Play %s semantics introduced a governing numeric value." % play_id)
	for forbidden in ["rank", "uses", "cost", "cooldown", "window", "chance", "heat", "effect", "amount", "fee", "direction", "cap", "pairing"]:
		if _contains_key_fragment(semantics, forbidden): failures.append("Play %s semantics leaked governing key fragment %s." % [play_id, forbidden])


func _check_chip_dump(root: Dictionary, failures: Array) -> void:
	for play_value in root.get("plays", []):
		var play: Dictionary = play_value
		if str(play.get("id", "")) != "chip_dump": continue
		var effect: Dictionary = play.get("effect", {})
		if int(effect.get("transfer_amount", -1)) != 40 or int(effect.get("transfer_fee", -1)) != 6 or str(effect.get("direction", "")) != "cash_to_chips" or effect.size() != 3 or int(play.get("cash_cost", -1)) != 0:
			failures.append("Chip Dump changed amount 40, fee 6, cash_to_chips, or zero activation cost.")
		return
	failures.append("Chip Dump is missing.")


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result := {}; var keys := (value as Dictionary).keys(); keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys: result[str(key)] = _canonical((value as Dictionary).get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array: result.append(_canonical(entry))
		return result
	return value


static func _contains_number(value: Variant) -> bool:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]: return true
	if typeof(value) == TYPE_DICTIONARY:
		for child in (value as Dictionary).values():
			if _contains_number(child): return true
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			if _contains_number(child): return true
	return false


static func _contains_key_fragment(value: Variant, fragment: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key in (value as Dictionary).keys():
			if str(key).to_lower().contains(fragment) or _contains_key_fragment((value as Dictionary).get(key), fragment): return true
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			if _contains_key_fragment(child, fragment): return true
	return false


static func _load_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []
