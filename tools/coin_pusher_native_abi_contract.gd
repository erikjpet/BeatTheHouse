extends SceneTree

const RngStream := preload("res://scripts/core/rng_stream.gd")


func _init() -> void:
	var expect_live_batch := true
	for argument in OS.get_cmdline_user_args():
		if argument == "--expect-live-batch=false":
			expect_live_batch = false
		elif argument == "--expect-live-batch=true":
			expect_live_batch = true
	print("COIN_PUSHER_NATIVE_ABI_STAGE script_started")
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		_fail("CoinPusherNativeCore was not registered by the descriptor-bound library.")
		return
	var native: Object = ClassDB.instantiate("CoinPusherNativeCore")
	if native == null:
		_fail("CoinPusherNativeCore could not be instantiated.")
		return
	print("COIN_PUSHER_NATIVE_ABI_STAGE instantiated")
	for method_name in ["backend_id", "solver_contract", "step_ticks"]:
		if not native.has_method(method_name):
			_fail("Descriptor-bound native library omitted method: %s" % method_name)
			return
	if str(native.call("backend_id")) != "coin_pusher_native_integer_v3":
		_fail("Descriptor-bound native library returned the wrong backend identity.")
		return
	var has_supports := native.has_method("supports_live_batch_capture")
	var has_builder := native.has_method("build_live_render_batch")
	if not expect_live_batch:
		if has_supports or has_builder:
			_fail("Basic control library unexpectedly exposed the live batch ABI.")
			return
		print("COIN_PUSHER_NATIVE_ABI_STAGE methods_bound")
		print("COIN_PUSHER_NATIVE_ABI_CONTRACT PASS backend=native_v3 live_batch=false platform=%s" % OS.get_name())
		quit(0)
		return
	if not has_supports or not has_builder:
		_fail("Descriptor-bound native library omitted its live batch ABI.")
		return
	if not bool(native.call("supports_live_batch_capture")):
		_fail("Descriptor-bound native library did not advertise live batch capture.")
		return
	var batch: Variant = native.call("build_live_render_batch", {}, [], [], 1.0)
	if typeof(batch) != TYPE_DICTIONARY or int((batch as Dictionary).get("count", -1)) != 0:
		_fail("Live batch ABI did not return an empty deterministic batch.")
		return
	if not _cache_lifetime_contract():
		return
	print("COIN_PUSHER_NATIVE_ABI_STAGE methods_bound")
	print("COIN_PUSHER_NATIVE_ABI_CONTRACT PASS backend=native_v3 live_batch=true platform=%s" % OS.get_name())
	quit(0)


func _cache_lifetime_contract() -> bool:
	var native: Object = ClassDB.instantiate("CoinPusherNativeCore")
	if native == null:
		_fail("Cache-lifetime native backend could not be instantiated.")
		return false
	var state := {
		"schema": "coin_pusher_machine_v3",
		"version": 3,
		"tick": 0,
		"bodies": [],
	}
	var first_rng := RngStream.new()
	first_rng.configure(101)
	var first_weak := weakref(first_rng)
	var first_config := {
		"live_cache_key": "abi-lifetime:first",
		"live_cache_reset": true,
		"rng": first_rng,
	}
	var first_result: Variant = native.call("step_ticks", state.duplicate(true), first_config, 0)
	first_result = null
	first_config = {}
	first_rng = null
	if first_weak.get_ref() == null:
		_fail("Live kernel cache did not retain its keyed per-call configuration.")
		return false

	var second_rng := RngStream.new()
	second_rng.configure(202)
	var second_weak := weakref(second_rng)
	var second_config := {
		"live_cache_key": "abi-lifetime:second",
		"live_cache_reset": true,
		"rng": second_rng,
	}
	var second_result: Variant = native.call("step_ticks", state.duplicate(true), second_config, 0)
	second_result = null
	second_config = {}
	second_rng = null
	if first_weak.get_ref() != null:
		_fail("Replacing the live kernel cache retained the prior configuration.")
		return false
	if second_weak.get_ref() == null:
		_fail("Replacement live kernel cache did not retain its keyed configuration.")
		return false

	native = null
	if second_weak.get_ref() != null:
		_fail("Releasing the native backend did not release its live kernel cache.")
		return false
	print("COIN_PUSHER_NATIVE_ABI_STAGE cache_lifetime_released")
	return true


func _fail(message: String) -> void:
	push_error("COIN_PUSHER_NATIVE_ABI_CONTRACT FAIL %s" % message)
	quit(1)
