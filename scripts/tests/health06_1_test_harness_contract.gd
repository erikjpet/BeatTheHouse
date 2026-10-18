extends SceneTree

const FoundationTestHarnessScript := preload("res://scripts/tests/foundation/foundation_test_harness.gd")


func _init() -> void:
	var failures: Array = []
	var harness = FoundationTestHarnessScript.new(failures)
	if not harness._expect(true, "should not fail", {"case": "true"}):
		push_error("CH-24: true expectation returned false.")
		quit(1)
		return
	if harness._expect(false, "fixture failed", {"seed": "H06", "step": 4}):
		push_error("CH-24: false expectation returned true.")
		quit(1)
		return
	if failures.size() != 1 or str(failures[0]).find("fixture failed") == -1 or str(failures[0]).find("H06") == -1:
		push_error("CH-24: harness did not retain message and actionable context: %s" % JSON.stringify(failures))
		quit(1)
		return
	print("HEALTH06_1_TEST_HARNESS PASS")
	quit(0)
