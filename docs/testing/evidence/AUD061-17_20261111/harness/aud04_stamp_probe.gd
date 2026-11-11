extends SceneTree
func _init() -> void:
	var project := str(ProjectSettings.get_setting("application/config/version", ""))
	var display := BuildIdentity.display_version()
	var failures: Array[String] = []
	if project != "0.6.1": failures.append("project stamp is " + project)
	if display != "0.6.1": failures.append("source display is " + display)
	print(JSON.stringify({"checks":2,"failure_count":failures.size(),"failures":failures,"project_version":project,"source_display":display,"source_probe_only":true}))
	quit(0 if failures.is_empty() else 1)
