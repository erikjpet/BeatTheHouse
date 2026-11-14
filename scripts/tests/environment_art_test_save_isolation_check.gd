extends SceneTree
const Candidate := preload("res://scripts/core/persistence_paths.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var flag := PackedStringArray([Candidate.WEB_ART_TEST_ARGUMENT])
    _check(Candidate._resolve_distribution_root(true, true, PackedStringArray(), "") == Candidate.WEB_DISTRIBUTION_ROOT, "ordinary Web/NEXT root stable")
    _check(Candidate._resolve_distribution_root(true, true, flag, "") == Candidate.WEB_ART_TEST_ROOT, "TEST Web flag isolated")
    _check(Candidate.WEB_ART_TEST_ROOT != Candidate.WEB_DISTRIBUTION_ROOT, "TEST and NEXT roots differ")
    _check(Candidate._resolve_distribution_root(true, false, flag, "") == Candidate.DISTRIBUTION_ROOT, "native root ignores TEST flag")
    _check(Candidate._resolve_distribution_root(false, true, flag, "") == "", "development root ignores TEST flag")
    _check(Candidate._resolve_distribution_root(true, true, PackedStringArray(["--bth-art-test-other"]), "") == Candidate.WEB_DISTRIBUTION_ROOT, "prefix does not activate TEST")
    _check(Candidate._resolve_distribution_root(true, true, PackedStringArray(["--bth-art-test=/arbitrary"]), "") == Candidate.WEB_DISTRIBUTION_ROOT, "arbitrary path argument ignored")
    _check(Candidate._resolve_distribution_root(true, true, flag, "user://qa-explicit") == "user://qa-explicit", "QA explicit root retains priority")
    _check(Candidate._resolve_distribution_root(false, false, flag, "E:/QA/explicit/") == "E:/QA/explicit", "native QA absolute root normalization stable")
    _check(Candidate._resolve_distribution_root(true, true, flag, "user://../escape") == Candidate.WEB_ART_TEST_ROOT, "unsafe traversal override rejected")
    _check(Candidate._resolve_distribution_root(true, true, PackedStringArray(["--bth-art-test", "--bth-art-test"]), "") == Candidate.WEB_ART_TEST_ROOT, "repeated flag stable")
    var actual_override := Candidate._normalized_distribution_root(OS.get_environment(Candidate.DISTRIBUTION_ROOT_ENV))
    _check(not actual_override.is_empty() and Candidate.distribution_root() == actual_override, "actual guarded process stays in admitted QA save root")
    _check(Candidate.file_path("user://legacy.json", "saves/autosave.json").begins_with(actual_override + "/"), "actual save path stays in guarded root")
    print("ENVART_TEST_NAMESPACE ", JSON.stringify({"checks": checks, "failures": failures, "next_root": Candidate.WEB_DISTRIBUTION_ROOT, "test_root": Candidate.WEB_ART_TEST_ROOT, "disk_writes": false, "source_prototype_only": false}))
    quit(0 if failures.is_empty() else 1)
func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)
