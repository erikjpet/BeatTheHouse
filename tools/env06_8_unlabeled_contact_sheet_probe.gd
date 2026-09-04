extends SceneTree

# Production-room visual receipt for env06_8. Every scenario is entered through
# the real travel path. Reachable phase, branch, production-command aftermath,
# and reentry states are then projected through the production layout/controller
# and rasterized by PixelSceneCanvas. Text is removed only from the evidence copy.

const MainScene := preload("res://scenes/main.tscn")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const RunSaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const InteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const LayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")

const VIEW_SIZE := Vector2i(900, 430)
const THUMB_SIZE := Vector2i(300, 143)
const MAX_TRACE_STATES := 512

var app: Control
var evidence_canvas: Control


class CueConsumerSpy extends Node:
	var calls: Array = []
	func bind_surface_audio_authority(_authority: Variant) -> void: pass
	func set_prewarm_events(_events: Array) -> void: pass
	func play_surface_cue(cue_id: String, context: Dictionary, surface_state: Dictionary, _authority: Variant) -> void:
		calls.append({"cue_id": cue_id, "context": context.duplicate(true), "surface_state": surface_state.duplicate(true)})


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := _argument("evidence-dir")
	if output_dir.is_empty():
		printerr("ENV06_8_UNLABELED_FAIL: --evidence-dir is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = VIEW_SIZE
	app = MainScene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.visible = false
	evidence_canvas = PixelSceneCanvasScript.new()
	evidence_canvas.size = Vector2(VIEW_SIZE)
	evidence_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evidence_canvas.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(evidence_canvas)
	await process_frame

	app.call("_ensure_full_content_library_loaded")
	var library: Variant = app.get("library")
	var generator: Variant = app.get("generator")
	var scenarios: Array = []
	var only_scenario := _argument("scenario")
	for archetype_value in library.environment_scenarios.keys():
		for definition_value in _array(library.environment_scenarios.get(archetype_value, [])):
			var definition := SequenceCatalogScript.apply_overlay(_dict(definition_value), library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty() and (only_scenario.is_empty() or str(definition.get("id", "")) == only_scenario):
				scenarios.append({"archetype_id": str(archetype_value), "definition": definition})
	scenarios.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(_dict(left.get("definition", {})).get("id", "")) < str(_dict(right.get("definition", {})).get("id", ""))
	)
	if scenarios.is_empty():
		printerr("ENV06_8_UNLABELED_FAIL: no matching production scenarios were loaded")
		quit(1)
		return

	var failures: Array = []
	var rows: Array = []
	var sheets: Dictionary = {}
	for scenario_value in scenarios:
		var scenario := _dict(scenario_value)
		var archetype_id := str(scenario.get("archetype_id", ""))
		var definition := _dict(scenario.get("definition", {}))
		var scenario_id := str(definition.get("id", ""))
		var original_pool := _array(library.environment_scenarios.get(archetype_id, []))
		library.environment_scenarios[archetype_id] = [definition]
		app.process_mode = Node.PROCESS_MODE_INHERIT
		app.call("start_foundation_run", "ENV06_8-VISUAL-%s" % scenario_id, {}, false)
		var run_state: Variant = app.get("run_state")
		var target_node := archetype_id
		for node_value in _array(run_state.world_map.get("nodes", [])):
			var node := _dict(node_value)
			if str(node.get("archetype_id", "")) == archetype_id:
				target_node = str(node.get("id", archetype_id))
				break
		var travel := _dict(generator.call("travel_environment_result", run_state, target_node, true))
		if not bool(travel.get("ok", false)) or str(run_state.current_environment.get("scenario_id", "")) != scenario_id:
			failures.append("%s could not enter production room: %s" % [scenario_id, JSON.stringify(travel.get("errors", []))])
			library.environment_scenarios[archetype_id] = original_pool
			continue

		var arrival_snapshot := _dict(app.call("_environment_view_snapshot"))
		var environment := _dict(run_state.current_environment)
		var base_records := _array(environment.get("scenario_layout_base_records", []))
		var initial_state := _dict(environment.get("scenario_sequence_state", {}))
		var trace_failures: Array = []
		var candidates := _runtime_states(definition, initial_state, scenario_id, trace_failures)
		failures.append_array(trace_failures)
		var expected_identities: Dictionary = {}
		_collect_expected_create_identities(_dict(definition.get("sequence", {})), expected_identities)
		var expected_action_keys := _authored_action_keys(_dict(definition.get("sequence", {})))
		var expected_action_count := expected_action_keys.size()
		var selected := _select_covering_states(candidates, expected_identities)
		var selected_coverage: Dictionary = {}
		var thumbnails: Array = []
		var captures: Array = []
		var capture_by_path: Dictionary = {}
		var masked_label_count := 0
		for selected_value in selected:
			var selected_state := _dict(selected_value)
			var state := _dict(selected_state.get("state", {}))
			var projection := SequenceRuntimeScript.public_projection(state, definition)
			var projected := InteractionControllerScript.project_sequence_interaction_result(base_records, projection, environment)
			if not bool(projected.get("ok", false)):
				failures.append("%s/%s failed production projection: %s" % [scenario_id, str(selected_state.get("path", "state")), JSON.stringify(projected.get("errors", []))])
				continue
			var renderer_snapshot := LayoutResolverScript.sealed_renderer_snapshot(projected)
			if not bool(renderer_snapshot.get("ok", false)):
				failures.append("%s/%s failed sealed renderer projection: %s" % [scenario_id, str(selected_state.get("path", "state")), JSON.stringify(renderer_snapshot.get("errors", []))])
				continue
			var snapshot := arrival_snapshot.duplicate(true)
			snapshot["interactable_objects"] = _array(projected.get("records", []))
			snapshot["scenario_layout_audit"] = _dict(projected.get("layout_audit", {}))
			snapshot["scenario_layout_authority_digest"] = str(projected.get("layout_authority_digest", ""))
			snapshot["scenario_render_snapshot"] = renderer_snapshot
			var mask_result := _mask_narration(snapshot)
			snapshot = _dict(mask_result.get("snapshot", {}))
			masked_label_count += int(mask_result.get("masked_label_count", 0))
			if not _masked_sources_empty(snapshot):
				failures.append("%s/%s retained a signage, stage, result, reward, label, description, or action text source." % [scenario_id, str(selected_state.get("path", "state"))])
				continue
			app.process_mode = Node.PROCESS_MODE_DISABLED
			var image: Image = await _raster(snapshot)
			if image.is_empty():
				failures.append("%s/%s did not produce an unlabeled production raster." % [scenario_id, str(selected_state.get("path", "state"))])
				continue
			var index := captures.size()
			var file_name := "%s_%02d_unlabeled.png" % [scenario_id, index]
			var path := output_dir.path_join(file_name)
			if image.save_png(path) != OK:
				failures.append("%s/%s could not save its raster." % [scenario_id, str(selected_state.get("path", "state"))])
				continue
			var thumbnail := image.duplicate()
			thumbnail.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_LANCZOS)
			thumbnails.append(thumbnail)
			for key_value in _state_coverage_keys(state): selected_coverage[str(key_value)] = true
			var capture := {
				"path": str(selected_state.get("path", "state")),
				"phase_id": str(state.get("phase_id", "")),
				"status": str(state.get("status", "")),
				"file": file_name,
				"sha256": FileAccess.get_sha256(path),
				"visible_created_objects": _visible_created_identities(state),
				"visible_state_signatures": _visible_state_signatures(state),
			}
			captures.append(capture)
			capture_by_path[str(capture.get("path", ""))] = capture

		var action_state_pairs: Array = []
		for selected_value in selected:
			var selected_state := _dict(selected_value)
			if not bool(selected_state.get("production_action_evidence", false)):
				continue
			var action_path := str(selected_state.get("path", ""))
			var before_path := str(selected_state.get("action_parent_path", ""))
			var before_capture := _dict(capture_by_path.get(before_path, {}))
			var after_capture := _dict(capture_by_path.get(action_path, {}))
			var handler := str(selected_state.get("action_handler", ""))
			var pair := {
				"action_id": str(selected_state.get("action_id", "")),
				"action_occurrence_key": str(selected_state.get("action_occurrence_key", "")),
				"authored_definition_key": str(selected_state.get("authored_definition_key", "")),
				"handler": handler,
				"target_identity": str(selected_state.get("action_target_identity", "")),
				"before_path": before_path,
				"after_path": action_path,
				"before_sha256": str(before_capture.get("sha256", "")),
				"after_sha256": str(after_capture.get("sha256", "")),
			}
			if bool(selected_state.get("action_requires_room_raster", false)):
				pair["visible_channel"] = "settled_room_raster"
				pair["passed"] = not before_capture.is_empty() and not after_capture.is_empty() and str(pair.get("before_sha256", "")) != str(pair.get("after_sha256", ""))
				if before_capture.is_empty() or after_capture.is_empty():
					failures.append("%s action %s is missing its production pre-command or settled-post-command raster." % [scenario_id, str(pair.get("action_id", ""))])
				elif str(pair.get("before_sha256", "")) == str(pair.get("after_sha256", "")):
					failures.append("%s action %s claims a %s consequence on %s but its real settled room raster is unchanged." % [scenario_id, str(pair.get("action_id", "")), handler, str(pair.get("target_identity", ""))])
			else:
				var channel_result := _consume_production_action_channel(run_state, definition, selected_state)
				pair["visible_channel"] = str(channel_result.get("channel", ""))
				pair["passed"] = bool(channel_result.get("ok", false))
				pair["channel_receipt"] = _dict(channel_result.get("receipt", {}))
				if not bool(channel_result.get("ok", false)):
					failures.append("%s action %s did not produce its consumed %s channel: %s" % [scenario_id, str(pair.get("action_id", "")), handler, str(channel_result.get("error", "missing visible consequence"))])
			action_state_pairs.append(pair)
		var represented_action_keys: Dictionary = {}
		for pair_value in action_state_pairs:
			represented_action_keys[str(_dict(pair_value).get("authored_definition_key", ""))] = true
		var missing_action_definitions: Array = []
		for expected_key_value in expected_action_keys.keys():
			if not represented_action_keys.has(str(expected_key_value)): missing_action_definitions.append(str(expected_key_value))
		if not missing_action_definitions.is_empty():
			failures.append("%s action evidence misses %d/%d authored action definitions." % [scenario_id, missing_action_definitions.size(), expected_action_count])

		var missing: Array = []
		for identity_value in expected_identities.keys():
			if not selected_coverage.has("identity:%s" % str(identity_value)):
				missing.append(str(identity_value))
		if not missing.is_empty():
			failures.append("%s visual states miss authored created objects: %s" % [scenario_id, JSON.stringify(missing)])
		if captures.is_empty():
			failures.append("%s produced no material-state captures." % scenario_id)
		var sheet_path := output_dir.path_join("%s_unlabeled_contact_sheet.png" % scenario_id)
		var sheet := _write_sheet(thumbnails, sheet_path)
		if sheet.is_empty():
			failures.append("%s per-scenario contact sheet could not be written." % scenario_id)
		else:
			sheets[scenario_id] = sheet
		rows.append({
			"scenario_id": scenario_id,
			"archetype_id": archetype_id,
			"expected_created_object_count": expected_identities.size(),
			"covered_created_object_count": expected_identities.size() - missing.size(),
			"reachable_material_state_count": candidates.size(),
			"capture_count": captures.size(),
			"masked_label_count": masked_label_count,
			"authored_action_count": expected_action_count,
			"represented_authored_action_count": expected_action_count - missing_action_definitions.size(),
			"discovered_reachable_action_occurrence_count": action_state_pairs.size(),
			"witnessed_reachable_action_occurrence_count": action_state_pairs.size(),
			"missing_authored_action_definitions": missing_action_definitions,
			"missing_created_objects": missing,
			"action_state_pairs": action_state_pairs,
			"captures": captures,
		})
		library.environment_scenarios[archetype_id] = original_pool
		print("ENV06_8_UNLABELED_STAGE %s captures=%d objects=%d/%d" % [scenario_id, captures.size(), expected_identities.size() - missing.size(), expected_identities.size()])

	var expected_scenarios := 1 if not only_scenario.is_empty() else 55
	var authored_action_total := 0
	var represented_action_total := 0
	var witnessed_occurrence_total := 0
	for row_value in rows:
		var row := _dict(row_value)
		authored_action_total += int(row.get("authored_action_count", 0))
		represented_action_total += int(row.get("represented_authored_action_count", 0))
		witnessed_occurrence_total += int(row.get("witnessed_reachable_action_occurrence_count", 0))
	if only_scenario.is_empty() and authored_action_total != 673:
		failures.append("env06_8 visual action inventory changed from 673 to %d." % authored_action_total)
	var manifest := {
		"schema": "env06_8_unlabeled_production_rooms_v2",
		"head": _argument("head"),
		"scenario_count": rows.size(),
		"expected_scenario_count": expected_scenarios,
		"authored_action_count": authored_action_total,
		"represented_authored_action_count": represented_action_total,
		"witnessed_reachable_action_occurrence_count": witnessed_occurrence_total,
		"scenarios": rows,
		"scenario_contact_sheets": sheets,
		"text_sources_removed_from_evidence_render_only": [
			"display_name", "scenario_signage", "scenario_presentation.signage_line",
			"scenario_render_snapshot.active_stages", "outcome_object_id", "outcome_message",
			"outcome_bankroll_delta", "outcome_suspicion_delta", "object labels/descriptions/actions",
		],
		"all_masked_text_sources_asserted_empty": true,
		"failures": failures,
	}
	var manifest_path := output_dir.path_join("manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	var passed := failures.is_empty() and rows.size() == expected_scenarios and sheets.size() == expected_scenarios
	print("ENV06_8_UNLABELED_%s scenarios=%d sheets=%d manifest=%s" % ["PASS" if passed else "FAIL", rows.size(), sheets.size(), manifest_path])
	for failure in failures: printerr("ENV06_8_UNLABELED_FAIL: %s" % str(failure))
	quit(0 if passed else 1)


func _raster(snapshot: Dictionary) -> Image:
	evidence_canvas.call("render_environment_snapshot", snapshot)
	evidence_canvas.call("set_selected_object", "", false)
	evidence_canvas.set("hovered_object_id", "")
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var canvas_transform := evidence_canvas.get_viewport_transform()
	var crop_start := canvas_transform * Vector2.ZERO
	var crop_end := canvas_transform * evidence_canvas.size
	var crop_rect := Rect2i(Vector2i(roundi(crop_start.x), roundi(crop_start.y)), Vector2i(roundi(crop_end.x - crop_start.x), roundi(crop_end.y - crop_start.y))).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(crop_rect) if crop_rect.has_area() else image


func _mask_narration(snapshot_value: Dictionary) -> Dictionary:
	var snapshot := snapshot_value.duplicate(true)
	var records := _array(snapshot.get("interactable_objects", []))
	var masked_label_count := 0
	for index in range(records.size()):
		var record := _dict(records[index])
		if not str(record.get("label", "")).is_empty(): masked_label_count += 1
		for key in ["label", "short_description", "description", "identity_summary", "action_summary", "status_summary", "effect_summary", "impact_summary", "choice_summary", "risk_summary", "classification_summary", "cost_summary", "disabled_reason", "state_label"]:
			record[key] = ""
		for key in ["available_actions", "inline_actions", "scenario_sequence_actions", "input_actions", "attribute_badges"]:
			record[key] = []
		record["confirm_action_id"] = ""
		records[index] = record
	snapshot["interactable_objects"] = records
	snapshot["display_name"] = ""
	snapshot["scenario_signage"] = ""
	var presentation := _dict(snapshot.get("scenario_presentation", {}))
	presentation["signage_line"] = ""
	snapshot["scenario_presentation"] = presentation
	for key in ["outcome_object_id", "outcome_message", "result_message", "reward_message", "stage_message"]:
		snapshot[key] = ""
	for key in ["outcome_bankroll_delta", "outcome_suspicion_delta"]: snapshot[key] = 0
	for key in ["recent_result", "last_result", "reward", "scenario_reward"]: snapshot[key] = {}
	var render_snapshot := _dict(snapshot.get("scenario_render_snapshot", {}))
	render_snapshot["active_stages"] = []
	snapshot["scenario_render_snapshot"] = render_snapshot
	return {"snapshot": snapshot, "masked_label_count": masked_label_count}


func _masked_sources_empty(snapshot: Dictionary) -> bool:
	if not str(snapshot.get("display_name", "")).is_empty() or not str(snapshot.get("scenario_signage", "")).is_empty(): return false
	if not str(_dict(snapshot.get("scenario_presentation", {})).get("signage_line", "")).is_empty(): return false
	if not _array(_dict(snapshot.get("scenario_render_snapshot", {})).get("active_stages", [])).is_empty(): return false
	for key in ["outcome_object_id", "outcome_message", "result_message", "reward_message", "stage_message"]:
		if not str(snapshot.get(key, "")).is_empty(): return false
	for record_value in _array(snapshot.get("interactable_objects", [])):
		var record := _dict(record_value)
		for key in ["label", "short_description", "description", "action_summary", "disabled_reason", "state_label"]:
			if not str(record.get(key, "")).is_empty(): return false
		for key in ["available_actions", "inline_actions", "scenario_sequence_actions", "input_actions"]:
			if not _array(record.get(key, [])).is_empty(): return false
	return true


func _runtime_states(definition: Dictionary, initial_state: Dictionary, scenario_id: String, failures: Array) -> Array:
	var result: Array = []
	var pending: Array = [{"state": initial_state, "path": "arrival"}]
	var visited: Dictionary = {}
	var action_evidence_seen: Dictionary = {}
	var serial := 0
	while not pending.is_empty() and serial < MAX_TRACE_STATES:
		var item := _dict(pending.pop_front())
		var state := _dict(item.get("state", {}))
		var fingerprint := SequenceRuntimeScript.content_fingerprint(SequenceRuntimeScript.public_projection(state, definition))
		if visited.has(fingerprint):
			# Distinct commands can settle on the same state; retain each command's
			# evidence record while avoiding duplicate graph traversal.
			if bool(item.get("production_action_evidence", false)): result.append(item)
			continue
		visited[fingerprint] = true
		result.append(item)
		var reentry := SequenceRuntimeScript.apply_reentry(state, definition, "env06_8_visual_%s_%d" % [scenario_id, serial])
		if bool(reentry.get("ok", false)):
			var reentry_state := _dict(reentry.get("state", {}))
			var reentry_fingerprint := SequenceRuntimeScript.content_fingerprint(SequenceRuntimeScript.public_projection(reentry_state, definition))
			if not visited.has(reentry_fingerprint): pending.append({"state": reentry_state, "path": "%s|reentry" % str(item.get("path", "state"))})
		else:
			failures.append("%s/%s reentry failed: %s" % [scenario_id, str(item.get("path", "state")), JSON.stringify(reentry.get("errors", []))])
		_append_production_action_states(state, definition, str(item.get("path", "state")), scenario_id, serial, pending, failures, action_evidence_seen)
		if str(state.get("status", "")) == SequenceRuntimeScript.STATUS_ACTIVE:
			var phase := SequenceSchemaScript.phase(definition, str(state.get("phase_id", "")))
			var branch_index := 0
			for branch_value in _array(phase.get("branches", [])):
				var branch := _dict(branch_value)
				var condition := _dict(branch.get("condition", {}))
				var applied: Dictionary = {}
				if str(condition.get("type", "")) == "command":
					var command_id := str(condition.get("command_id", ""))
					var origin := _find_action_origin(state, command_id)
					var descriptor := SequenceRuntimeScript._command_descriptor(state, definition, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), command_id, {})
					var command := SequenceRuntimeScript.command(command_id, str(state.get("node_id", "")), str(state.get("phase_id", "")), "env06_8:visual:%s:%d:%d" % [scenario_id, serial, branch_index], {}, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")), str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))
					applied = SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 100000})
				else:
					applied = _apply_trace_fact(state, definition, condition, scenario_id, serial, branch_index)
				if bool(applied.get("ok", false)):
					pending.append({"state": _dict(applied.get("state", {})), "path": "%s>%s" % [str(item.get("path", "state")), str(branch.get("id", branch_index))]})
				elif str(condition.get("type", "")) in ["command", "fact"]:
					failures.append("%s branch %s failed: %s" % [scenario_id, str(branch.get("id", branch_index)), JSON.stringify(applied.get("errors", []))])
				branch_index += 1
		serial += 1
	if serial >= MAX_TRACE_STATES: failures.append("%s exceeded the bounded visual state trace." % scenario_id)
	return result


func _append_production_action_states(state: Dictionary, definition: Dictionary, path: String, scenario_id: String, serial: int, pending: Array, failures: Array, action_evidence_seen: Dictionary) -> void:
	var semantic := _dict(state.get("semantic_state", {}))
	for interaction_value in _dict(semantic.get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		if not bool(interaction.get("enabled", false)): continue
		for action_value in _array(interaction.get("available_actions", [])):
			var action := _dict(action_value)
			var handler := str(action.get("handler", ""))
			var action_id := str(action.get("id", ""))
			var origin := {
				"owner_namespace": str(interaction.get("owner_namespace", "")),
				"stable_object_id": str(interaction.get("stable_object_id", "")),
			}
			var descriptor := SequenceRuntimeScript._command_descriptor(state, definition, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), action_id, {})
			var occurrence_key := "%s|%s|%s|%s|%s|%s" % [
				str(state.get("node_id", "")), str(state.get("phase_id", "")),
				str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")),
				action_id, SequenceRuntimeScript.content_fingerprint(descriptor),
			]
			var authored_definition_key := "%s|%s|%s|%s|%s" % [
				str(state.get("phase_id", "")), str(origin.get("owner_namespace", "")),
				str(origin.get("stable_object_id", "")), action_id,
				SequenceRuntimeScript.content_fingerprint(action),
			]
			if action_evidence_seen.has(occurrence_key):
				continue
			action_evidence_seen[occurrence_key] = true
			var command := SequenceRuntimeScript.command(action_id, str(state.get("node_id", "")), str(state.get("phase_id", "")), "env06_8:visual-action:%s:%d:%s" % [scenario_id, serial, action_id], {}, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")), str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))
			var applied := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 100000})
			if not bool(applied.get("ok", false)):
				failures.append("%s/%s production action %s failed: %s" % [scenario_id, path, action_id, JSON.stringify(applied.get("errors", []))])
				continue
			var result_state := _dict(applied.get("state", {}))
			var inputs := _dict(action.get("inputs", {}))
			var identity := OperationRegistryScript.identity(str(inputs.get("owner_namespace", interaction.get("owner_namespace", ""))), str(inputs.get("stable_object_id", interaction.get("stable_object_id", ""))))
			pending.append({
				"state": result_state,
				"path": "%s|action:%s" % [path, action_id],
				"production_action_evidence": true,
				"action_requires_room_raster": handler not in ["event_bridge", "grant_item", "grant_cash", "play_cue"],
				"action_parent_path": path,
				"action_id": action_id,
				"action_occurrence_key": occurrence_key,
				"authored_definition_key": authored_definition_key,
				"action_handler": handler,
				"action_target_identity": identity,
				"action_inputs": inputs,
				"action_pre_state": state,
				"action_owner_namespace": str(origin.get("owner_namespace", "")),
				"action_stable_object_id": str(origin.get("stable_object_id", "")),
				"action_origin_owner_namespace": str(descriptor.get("action_origin_owner_namespace", "")),
				"action_origin_stable_object_id": str(descriptor.get("action_origin_stable_object_id", "")),
				"action_origin_receipt_key": str(descriptor.get("action_origin_receipt_key", "")),
				"action_origin_boundary_id": str(descriptor.get("action_origin_boundary_id", "")),
				"action_origin_fingerprint": str(descriptor.get("action_origin_fingerprint", "")),
			})


func _consume_production_action_channel(run_state: Variant, definition: Dictionary, evidence: Dictionary) -> Dictionary:
	var handler := str(evidence.get("action_handler", ""))
	if handler not in ["event_bridge", "grant_item", "grant_cash", "play_cue"]:
		return {"ok": false, "channel": "unsupported", "error": "no production consumer is registered for %s" % handler}
	var saved_run: Dictionary = run_state.to_dict()
	var saved_environment: Dictionary = run_state.current_environment.duplicate(true)
	var saved_layout_context := _dict(saved_environment.get("scenario_layout_context", {}))
	var saved_selected_event := str(app.get("selected_event_id"))
	var saved_popup := _dict(app.get("pending_event_choice_popup_snapshot"))
	var saved_sfx: Variant = app.get("environment_sfx_player")
	var cue_spy: CueConsumerSpy = null
	if handler == "play_cue":
		cue_spy = CueConsumerSpy.new()
		app.add_child(cue_spy)
		app.set("environment_sfx_player", cue_spy)
	var result := {"ok": false, "channel": "", "error": "consumer did not run", "receipt": {}}
	var finalized: Dictionary = run_state.scenario_finalize_installed_environment(app.get("library"), saved_layout_context)
	if not bool(finalized.get("ok", false)):
		run_state.from_dict(saved_run)
		_production_restore_boundary(run_state)
		if cue_spy != null:
			app.set("environment_sfx_player", saved_sfx)
			cue_spy.queue_free()
		app.set("selected_event_id", saved_selected_event)
		app.set("pending_event_choice_popup_snapshot", saved_popup)
		return {"ok": false, "channel": handler, "error": "trusted host finalization failed: %s" % JSON.stringify(finalized.get("errors", [])), "receipt": {}}
	var inputs := _dict(evidence.get("action_inputs", {}))
	var item_id := str(inputs.get("item_id", ""))
	if handler == "grant_item":
		while run_state.inventory.has(item_id): run_state.inventory.erase(item_id)
	var bankroll_before := int(run_state.bankroll)
	app.set("selected_event_id", "")
	app.set("pending_event_choice_popup_snapshot", {})
	var receipt_id := "env06_8:consumer:%s:%s" % [str(definition.get("id", "")), str(evidence.get("action_id", ""))]
	var command_result: Dictionary = {"ok": true, "errors": []}
	var predecessor_index := 0
	for predecessor_id_value in _production_action_ids_from_path(str(evidence.get("action_parent_path", ""))):
		command_result = _execute_production_host_action(run_state, definition, str(predecessor_id_value), "%s:pre:%d" % [receipt_id, predecessor_index])
		if not bool(command_result.get("ok", false)): break
		predecessor_index += 1
	if bool(command_result.get("ok", false)):
		command_result = _execute_production_host_action(run_state, definition, str(evidence.get("action_id", "")), receipt_id)
	if not bool(command_result.get("ok", false)):
		result["error"] = "host command failed: %s" % JSON.stringify(command_result.get("errors", []))
	else:
		var pre_consume_state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
		var delivery_receipt := {
			"queued_before_consume": _array(pre_consume_state.get("event_request_queue", [])).size(),
			"history_before_consume": _array(pre_consume_state.get("event_request_history", [])).size(),
			"delivery_receipts_before_consume": _array(pre_consume_state.get("event_request_delivery_receipts", [])).size(),
			"correlation_count": _array(pre_consume_state.get("event_correlations", [])).size(),
			"pending_event_id": str(inputs.get("event_id", "")),
		}
		var consumed_message := ""
		if handler == "play_cue":
			consumed_message = str(app.call("_consume_scenario_transitions"))
		else:
			consumed_message = str(app.call("_consume_scenario_event_requests"))
		if not consumed_message.is_empty(): app.call("_show_message", consumed_message)
		var post_consume_state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
		delivery_receipt.merge({
			"queued_after_consume": _array(post_consume_state.get("event_request_queue", [])).size(),
			"history_after_consume": _array(post_consume_state.get("event_request_history", [])).size(),
			"delivery_receipts_after_consume": _array(post_consume_state.get("event_request_delivery_receipts", [])).size(),
		}, true)
		var once_ok := false
		var channel := ""
		match handler:
			"event_bridge":
				channel = "dialogue_popup"
				var event_id := str(inputs.get("event_id", ""))
				once_ok = str(app.get("selected_event_id")) == event_id \
					and bool(_dict(app.get("pending_event_choice_popup_snapshot")).get("visible", false)) \
					and str(_dict(app.get("pending_event_choice_popup_snapshot")).get("event_id", "")) == event_id
			"grant_item":
				channel = "inventory"
				once_ok = not item_id.is_empty() and run_state.inventory.has(item_id)
			"grant_cash":
				channel = "bankroll"
				once_ok = int(run_state.bankroll) == bankroll_before + int(inputs.get("amount", 0))
			"play_cue":
				channel = "sound_and_stage"
				var stage_rendered := _production_stage_is_composed(_dict(app.call("_environment_view_snapshot")))
				once_ok = not consumed_message.is_empty() and app.get("message_label") != null \
					and str(app.get("message_label").text).strip_edges() == consumed_message.strip_edges() \
					and cue_spy != null and cue_spy.calls.size() == 1 and stage_rendered
		var inventory_after_once: Array = run_state.inventory.duplicate(true)
		var bankroll_after_once := int(run_state.bankroll)
		var pre_save_authority := _persistent_scenario_authority(_dict(run_state.current_environment))
		# Exercise the production save projection, exact integer transport, JSON
		# boundary, and RunState restore—not merely a copied scenario sub-dictionary.
		var encoded := RunSaveCodecScript.encode(run_state.to_dict())
		var transported_value: Variant = JSON.parse_string(JSON.stringify(encoded))
		var decoded := RunSaveCodecScript.decode(_dict(transported_value))
		# Mirror _load_foundation_run_from_slot: clear the UI-only event surface
		# before replacing RunState, then restore onto the room surface.
		app.call("_hide_event_choice_popup")
		app.call("_clear_selected_event_choice")
		app.call("_set_current_screen", "ENVIRONMENT")
		run_state.from_dict(decoded)
		var decoded_authority := _persistent_scenario_authority(_dict(run_state.current_environment))
		var restored_finalize := _production_restore_boundary(run_state)
		var reentry: Dictionary = run_state.scenario_reenter_current("env06_8_consumer_revisit") if bool(restored_finalize.get("ok", false)) else {"ok": false, "errors": restored_finalize.get("errors", [])}
		var authority_round_trip_ok := pre_save_authority == decoded_authority \
			and str(restored_finalize.get("semantic_digest", "")) == str(pre_save_authority.get("semantic_digest", ""))
		var lifecycle_ok := authority_round_trip_ok
		var lifecycle_receipt := {"delivery": delivery_receipt, "pre_save_authority": pre_save_authority, "decoded_authority": decoded_authority, "restore_finalize_ok": bool(restored_finalize.get("ok", false)), "restore_finalize_errors": _array(restored_finalize.get("errors", [])), "reentry_ok": bool(reentry.get("ok", false)), "reentry_errors": _array(reentry.get("errors", []))}
		if handler == "event_bridge":
			var event_id := str(inputs.get("event_id", ""))
			var resolution_id := str(inputs.get("resolution_id", ""))
			var reopened := bool(app.call("_activate_event_object", event_id))
			var reopened_popup := _dict(app.get("pending_event_choice_popup_snapshot"))
			var resolved := _dict(app.call("resolve_event_choice", event_id, resolution_id))
			app.set("selected_event_id", "")
			app.set("pending_event_choice_popup_snapshot", {})
			var post_resolution_reentry: Dictionary = run_state.scenario_reenter_current("env06_8_consumer_resolved_revisit")
			var reopened_after_resolution := not str(app.call("_consume_scenario_event_requests")).is_empty() \
				or bool(_dict(app.get("pending_event_choice_popup_snapshot")).get("visible", false))
			lifecycle_ok = lifecycle_ok and reopened and bool(reopened_popup.get("visible", false)) and str(reopened_popup.get("event_id", "")) == event_id \
				and bool(resolved.get("ok", false)) and bool(post_resolution_reentry.get("ok", false)) \
				and str(run_state.call("_scenario_pending_resolution_for_event", event_id)).is_empty() and not reopened_after_resolution
			lifecycle_receipt.merge({"reopened": reopened, "reopened_popup": bool(reopened_popup.get("visible", false)), "resolved": bool(resolved.get("ok", false)), "resolved_errors": _array(resolved.get("errors", [])), "post_resolution_reentry_ok": bool(post_resolution_reentry.get("ok", false)), "reopened_after_resolution": reopened_after_resolution}, true)
			inventory_after_once = run_state.inventory.duplicate(true)
			bankroll_after_once = int(run_state.bankroll)
		elif handler == "play_cue":
			var stage_survived := _production_stage_is_composed(_dict(app.call("_environment_view_snapshot")))
			var reduced := SequenceRuntimeScript.drain_transitions(_dict(evidence.get("state", {})), definition, true, true)
			var reduced_has_message := false
			for transition_value in _array(reduced.get("transitions", [])):
				var transition := _dict(transition_value)
				if str(transition.get("op", "")) == "stage" and not str(transition.get("message", "")).strip_edges().is_empty() and int(transition.get("duration_boundaries", -1)) == 0:
					reduced_has_message = true
			lifecycle_ok = lifecycle_ok and stage_survived and reduced_has_message
			lifecycle_receipt.merge({"stage_survived_restore": stage_survived, "reduced_motion_message": reduced_has_message, "sfx_call_count": cue_spy.calls.size() if cue_spy != null else 0}, true)
		var replay: Dictionary = run_state.scenario_sequence_command(
			str(evidence.get("action_id", "")), receipt_id, {},
			str(evidence.get("action_owner_namespace", "")), str(evidence.get("action_stable_object_id", "")), _host_interaction_availability(_dict(run_state.current_environment.get("scenario_sequence_state", {}))),
			str(evidence.get("action_origin_owner_namespace", "")), str(evidence.get("action_origin_stable_object_id", "")),
			str(evidence.get("action_origin_receipt_key", "")), str(evidence.get("action_origin_boundary_id", "")),
			str(evidence.get("action_origin_fingerprint", ""))
		)
		var replay_message := str(app.call("_consume_scenario_transitions")) if handler == "play_cue" else str(app.call("_consume_scenario_event_requests"))
		var cue_once := handler != "play_cue" or cue_spy != null and cue_spy.calls.size() == 1
		var no_duplicate: bool = bool(reentry.get("ok", false)) and lifecycle_ok and cue_once and bool(replay.get("ok", false)) and bool(replay.get("replayed", false)) \
			and replay_message.is_empty() and run_state.inventory == inventory_after_once and int(run_state.bankroll) == bankroll_after_once
		result = {
			"ok": once_ok and no_duplicate,
			"channel": channel,
			"error": "" if once_ok and no_duplicate else "first consumption was not visible or replay/revisit duplicated it",
			"receipt": {"host_command_ok": true, "consumed_once": once_ok, "serialized_revisit_ok": bool(reentry.get("ok", false)), "replayed": bool(replay.get("replayed", false)), "replay_errors": _array(replay.get("errors", [])), "duplicate_effect": not no_duplicate, "lifecycle": lifecycle_receipt},
		}
	app.call("_hide_event_choice_popup")
	app.call("_clear_selected_event_choice")
	app.call("_set_current_screen", "ENVIRONMENT")
	run_state.from_dict(saved_run)
	_production_restore_boundary(run_state)
	if cue_spy != null:
		app.set("environment_sfx_player", saved_sfx)
		cue_spy.queue_free()
	app.set("selected_event_id", saved_selected_event)
	app.set("pending_event_choice_popup_snapshot", saved_popup)
	return result


func _production_stage_is_composed(snapshot: Dictionary) -> bool:
	evidence_canvas.call("render_environment_snapshot", snapshot)
	for object_value in _array(evidence_canvas.call("_active_scene_objects")):
		if str(_dict(object_value).get("id", "")).begins_with("scenario:stage:"):
			return true
	return false


func _production_restore_boundary(run_state: Variant) -> Dictionary:
	app.set("interactable_object_view_cache_valid", false)
	app.call("_interactable_object_view_list")
	var environment := _dict(run_state.current_environment)
	var errors := _array(environment.get("scenario_sequence_lifecycle_errors", []))
	var ok := bool(environment.get("scenario_semantic_ready", false)) \
		and not bool(environment.get("scenario_restore_pending_trusted_rebuild", false)) \
		and errors.is_empty()
	return {"ok": ok, "errors": errors, "semantic_digest": str(environment.get("scenario_semantic_digest", "")), "layout_digest": str(environment.get("scenario_layout_authority_digest", ""))}


func _persistent_scenario_authority(environment: Dictionary) -> Dictionary:
	var inventory := _dict(environment.get("scenario_semantic_inventory", {}))
	var state := _dict(environment.get("scenario_sequence_state", {}))
	return {
		"semantic_digest": str(environment.get("scenario_semantic_digest", "")),
		"semantic_inventory_version": int(environment.get("scenario_semantic_inventory_version", inventory.get("schema_version", 0))),
		"semantic_inventory_digest": str(inventory.get("digest", "")),
		"layout_digest": str(environment.get("scenario_layout_authority_digest", "")),
		"restore_contract": str(environment.get("scenario_restore_contract", "")),
		"state_fingerprint": SequenceRuntimeScript.content_fingerprint(state),
		"event_history_count": _array(state.get("event_request_history", [])).size(),
		"event_delivery_receipt_count": _array(state.get("event_request_delivery_receipts", [])).size(),
		"event_correlation_count": _array(state.get("event_correlations", [])).size(),
	}


func _host_interaction_availability(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		var identity := OperationRegistryScript.identity(str(interaction.get("owner_namespace", "")), str(interaction.get("stable_object_id", "")))
		if not identity.is_empty(): result[identity] = bool(interaction.get("enabled", false))
	return result


func _production_action_ids_from_path(path: String) -> Array:
	var result: Array = []
	for part_value in path.split("|", false):
		var part := str(part_value)
		if not part.begins_with("action:"): continue
		var action_id := part.trim_prefix("action:").split(">", false)[0]
		if not action_id.is_empty(): result.append(action_id)
	return result


func _execute_production_host_action(run_state: Variant, definition: Dictionary, action_id: String, receipt_id: String) -> Dictionary:
	var state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
	var origin := _find_action_origin(state, action_id)
	if origin.is_empty():
		return {"ok": false, "errors": ["production predecessor %s is not available in phase %s" % [action_id, str(state.get("phase_id", ""))]]}
	var descriptor := SequenceRuntimeScript._command_descriptor(state, definition, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), action_id, {})
	return run_state.scenario_sequence_command(
		action_id, receipt_id, {}, str(origin.get("owner_namespace", "")), str(origin.get("stable_object_id", "")), _host_interaction_availability(state),
		str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")),
		str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", ""))
	)


func _select_covering_states(candidates: Array, expected_identities: Dictionary) -> Array:
	var targets: Dictionary = {}
	for identity_value in expected_identities.keys(): targets["identity:%s" % str(identity_value)] = true
	for candidate_value in candidates:
		for key_value in _state_coverage_keys(_dict(_dict(candidate_value).get("state", {}))): targets[str(key_value)] = true
	var selected: Array = []
	var covered: Dictionary = {}
	var remaining := candidates.duplicate(true)
	while covered.size() < targets.size() and not remaining.is_empty():
		var best_index := -1
		var best_gain := 0
		for index in range(remaining.size()):
			var gain := 0
			for key_value in _state_coverage_keys(_dict(_dict(remaining[index]).get("state", {}))):
				if targets.has(str(key_value)) and not covered.has(str(key_value)): gain += 1
			if gain > best_gain:
				best_gain = gain
				best_index = index
		if best_index < 0: break
		var chosen := _dict(remaining.pop_at(best_index))
		selected.append(chosen)
		for key_value in _state_coverage_keys(_dict(chosen.get("state", {}))): covered[str(key_value)] = true
	# Every real production command needs a retained evidence record. Room-state
	# commands get an explicit settled-raster pair; event, reward, and cue commands
	# are checked through their production consumer below.
	var selected_paths: Dictionary = {}
	for selected_value in selected:
		selected_paths[str(_dict(selected_value).get("path", ""))] = true
	var candidate_by_path: Dictionary = {}
	for candidate_value in candidates:
		var candidate := _dict(candidate_value)
		candidate_by_path[str(candidate.get("path", ""))] = candidate
	for candidate_value in candidates:
		var candidate := _dict(candidate_value)
		if not bool(candidate.get("production_action_evidence", false)):
			continue
		var parent_path := str(candidate.get("action_parent_path", ""))
		if candidate_by_path.has(parent_path) and not selected_paths.has(parent_path):
			selected.append(_dict(candidate_by_path.get(parent_path, {})))
			selected_paths[parent_path] = true
		var action_path := str(candidate.get("path", ""))
		if not selected_paths.has(action_path):
			selected.append(candidate)
			selected_paths[action_path] = true
	return selected


func _state_coverage_keys(state: Dictionary) -> Array:
	var result: Array = []
	var semantic := _dict(state.get("semantic_state", {}))
	for collection_key in ["scene_objects", "actors"]:
		for identity_value in _dict(semantic.get(collection_key, {})).keys():
			var record := _dict(_dict(semantic.get(collection_key, {})).get(identity_value, {}))
			if not bool(record.get("present", true)): continue
			var identity := str(identity_value)
			result.append("identity:%s" % identity)
			result.append("state:%s|%s|%s|%s|%s|%s|%s|%s" % [
				identity,
				str(record.get("state", "")),
				str(record.get("appearance", "")),
				str(record.get("pose", "")),
				str(record.get("behavior", "")),
				str(record.get("anchor_id", "")),
				str(record.get("zone_id", "")),
				str(bool(record.get("visible", true))),
			])
	return result


func _visible_created_identities(state: Dictionary) -> Array:
	var result: Array = []
	for key_value in _state_coverage_keys(state):
		var key := str(key_value)
		if key.begins_with("identity:"): result.append(key.trim_prefix("identity:"))
	result.sort()
	return result


func _visible_state_signatures(state: Dictionary) -> Array:
	var result: Array = []
	for key_value in _state_coverage_keys(state):
		var key := str(key_value)
		if key.begins_with("state:"): result.append(key.trim_prefix("state:"))
	result.sort()
	return result


func _collect_expected_create_identities(value: Variant, result: Dictionary) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child in value: _collect_expected_create_identities(child, result)
		return
	if typeof(value) != TYPE_DICTIONARY: return
	var row := value as Dictionary
	if str(row.get("family", "")) in ["scene_ops", "actor_ops"] and typeof(row.get("object", row.get("actor", null))) == TYPE_DICTIONARY:
		result[OperationRegistryScript.identity(str(row.get("owner_namespace", "scenario")), str(row.get("stable_object_id", "")))] = true
	for child in row.values(): _collect_expected_create_identities(child, result)


func _authored_action_keys(sequence: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		var phase_id := str(phase.get("id", ""))
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			var interaction := _dict(operation.get("interaction", {}))
			var owner := str(operation.get("owner_namespace", interaction.get("owner_namespace", "scenario")))
			var stable_id := str(operation.get("stable_object_id", interaction.get("stable_object_id", "")))
			var actions := _array(interaction.get("available_actions", operation.get("available_actions", [])))
			for action_value in actions:
				var action := _dict(action_value)
				var key := "%s|%s|%s|%s|%s" % [
					phase_id, owner, stable_id, str(action.get("id", "")),
					SequenceRuntimeScript.content_fingerprint(action),
				]
				result[key] = true
	return result


func _find_action_origin(state: Dictionary, command_id: String) -> Dictionary:
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		if not bool(interaction.get("enabled", false)): continue
		for action_value in _array(interaction.get("available_actions", [])):
			if str(_dict(action_value).get("id", "")) == command_id:
				return {"owner_namespace": str(interaction.get("owner_namespace", "")), "stable_object_id": str(interaction.get("stable_object_id", ""))}
	return {}


func _apply_trace_fact(state: Dictionary, definition: Dictionary, condition: Dictionary, scenario_id: String, serial: int, branch_index: int) -> Dictionary:
	if str(condition.get("type", "")) != "fact": return {"ok": false, "errors": []}
	var fact_type := str(condition.get("fact_type", ""))
	var boundary := int(state.get("boundary_serial", 0)) + 1
	var payload := _trace_fact_payload(fact_type, state)
	for key_value in _dict(condition.get("payload_equals", {})).keys(): payload[str(key_value)] = _dict(condition.get("payload_equals", {})).get(key_value)
	var fact := SequenceRuntimeScript.fact(fact_type, _trace_fact_producer(fact_type), str(state.get("node_id", "")), "env06_8:visual:%s:fact:%d:%d" % [scenario_id, serial, branch_index], 1, boundary, payload)
	var queued := SequenceRuntimeScript.enqueue_fact(state, definition, fact)
	if not bool(queued.get("ok", false)): return queued
	var flushed := SequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), definition, boundary)
	if bool(flushed.get("ok", false)) and str(_dict(flushed.get("state", {})).get("status", "")) == SequenceRuntimeScript.STATUS_ACTIVE:
		var second_boundary := boundary + 1
		var second := SequenceRuntimeScript.fact(fact_type, _trace_fact_producer(fact_type), str(state.get("node_id", "")), "env06_8:visual:%s:fact:%d:%d:second" % [scenario_id, serial, branch_index], 2, second_boundary, payload)
		var second_queued := SequenceRuntimeScript.enqueue_fact(_dict(flushed.get("state", {})), definition, second)
		if bool(second_queued.get("ok", false)): flushed = SequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, second_boundary)
	return flushed


func _trace_fact_producer(fact_type: String) -> String:
	for producer_value in SequenceRuntimeScript.FACT_TYPES_BY_PRODUCER.keys():
		if _array(SequenceRuntimeScript.FACT_TYPES_BY_PRODUCER.get(producer_value, [])).has(fact_type): return str(producer_value)
	return "scenario"


func _trace_fact_payload(fact_type: String, state: Dictionary) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id": "env06_8_game", "action_id": "settled", "won": false, "ended": true, "bankroll_delta": 0, "chips_delta": 0, "applied_heat_delta": 0}
		"event_result": return {"event_id": "env06_8_event", "choice_id": "leave", "resolved": false, "ok": true}
		"service_result": return {"kind": "rest", "service_id": "env06_8_service", "ok": true, "action_id": "resolved"}
		"travel_departed", "travel_arrived": return {"source_id": "env06_8_source", "target_id": "env06_8_target", "travel_kind": "road"}
		"crew_changed": return {"member_id": "crew_switch", "change": "trust", "value": 2}
		"crew_job_changed": return {"job_id": "env06_8_job", "status": "active", "definition_id": "env06_8_job", "member_id": "crew_switch", "outcome": "complete"}
		"heat_changed": return {"previous": 2, "current": 4, "applied_delta": 2, "source": "env06_8"}
		"heat_band_changed": return {"previous_band": "quiet", "current_band": "caution", "current": 25, "source": "env06_8"}
		"sweep_changed": return {"action_index": 1, "node_id": str(state.get("node_id", "")), "segment_index": 1, "active": true}
		"town_transition": return {"action_index": 1, "weather": "storm", "day_type": "night", "happening_ids": ["env06_8_weather"]}
		"world_boundary": return {"amount": 1, "action_index": 1}
		"scenario_command": return {"command_id": "env06_8", "receipt_id": "env06_8_command"}
	return {}


func _write_sheet(thumbnails: Array, path: String) -> Dictionary:
	if thumbnails.is_empty(): return {}
	var columns := 3
	var rows := maxi(1, int(ceil(float(thumbnails.size()) / float(columns))))
	var sheet := Image.create(THUMB_SIZE.x * columns, THUMB_SIZE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("070a12"))
	for index in range(thumbnails.size()):
		var thumbnail: Image = thumbnails[index]
		sheet.blit_rect(thumbnail, Rect2i(Vector2i.ZERO, THUMB_SIZE), Vector2i((index % columns) * THUMB_SIZE.x, (index / columns) * THUMB_SIZE.y))
	if sheet.save_png(path) != OK: return {}
	return {"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "width": sheet.get_width(), "height": sheet.get_height(), "capture_count": thumbnails.size()}


func _argument(name: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
