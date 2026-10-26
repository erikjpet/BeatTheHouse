extends SceneTree
const Run := preload("res://scripts/core/run_state.gd")
const Resolver := preload("res://scripts/core/scenario_layout_resolver.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
var failures: Array[String]=[]
var checks := 0
func _initialize() -> void:
	var run := Run.new()
	var rect := {"x":0.2,"y":0.3,"w":0.1,"h":0.1}
	var keep := {"slot_id":"event.wall_2","slot_family":"event","presentation_mode":"room"}
	var later := {"slot_id":"event.wall_1","slot_family":"event","presentation_mode":"room"}
	var fixture := {"slot_id":"fixed.counter","slot_family":"fixed","presentation_mode":"room"}
	var bindings := {"event:later_contact":later,"event:original_contact":keep,"casino_fixture:counter":fixture,"scenario::owned_event":keep}
	run.current_environment={"id":"independent_room","archetype_id":"motel","event_ids":["later_contact","original_contact"],"resolved_event_ids":["consumed_contact"],"scenario_semantic_inventory":{"source_provenance":{"event_ids":["consumed_contact","original_contact"]}},"scenario_sequence_base_layout_object_rects":{"event:consumed_contact":rect,"event:original_contact":rect,"casino_fixture:counter":rect},"layout":{"object_rects":{"event:later_contact":rect,"event:original_contact":rect,"casino_fixture:counter":rect},"slot_bindings":bindings,"slot_binding_digest":Binder.binding_digest(bindings),"slot_overflow_ids":["event:later_contact","event:original_contact"],"grounding_signature":"live-only-cache"}}
	var before := run.current_environment.duplicate(true)
	var rng := run.rng_state
	var proof: Dictionary=run._scenario_authoritative_environment_for_finalization({})
	var layout: Dictionary=proof.get("layout",{})
	var proof_bindings: Dictionary=layout.get("slot_bindings",{})
	_check(proof.event_ids==["consumed_contact","original_contact"] and proof.resolved_event_ids.is_empty(),"Historical proof retains the original identity set required by its immutable seal")
	_check(not proof_bindings.has("event:later_contact"),"Post-seal event cannot reserve an original event's historical proof slot")
	_check(proof_bindings.get("event:original_contact")==keep,"Original surviving event binding remains exact")
	_check(proof_bindings.get("casino_fixture:counter")==fixture,"Fixed fixture binding remains exact")
	_check(proof_bindings.has("scenario::owned_event"),"Scenario-owned identities are outside the ordinary event filter")
	_check(not layout.object_rects.has("event:later_contact"),"Post-seal event geometry cannot leak into entry inventory")
	_check(not layout.slot_overflow_ids.has("event:later_contact") and layout.slot_overflow_ids.has("event:original_contact"),"Only post-seal event overflow reservation is removed")
	_check(layout.slot_binding_digest==Binder.binding_digest(proof_bindings),"Detached proof binding digest matches the retained envelope")
	_check(not layout.has("grounding_signature"),"Changed proof membership invalidates only its derived grounding cache")
	_check(run.current_environment==before and run.rng_state==rng,"Live room bindings, resolved journal and RNG are untouched")
	_check(run._scenario_authoritative_environment_for_finalization({})==proof,"Historical proof reconstruction is deterministic")
	var consumed := {"object_id":"event:consumed_contact","object_type":"event","source_id":"consumed_contact","owner_namespace":"event","slot_family":"event"}
	var fixed_event := consumed.duplicate(true);fixed_event["object_id"]="event:fixed_contact";fixed_event["slot_family"]="fixed"
	var scenario_event := consumed.duplicate(true);scenario_event["object_id"]="scenario::owned_event";scenario_event["owner_namespace"]="scenario"
	var current_event := consumed.duplicate(true);current_event["object_id"]="event:later_contact";current_event["source_id"]="later_contact"
	var semantic := {"scene_objects":{"event::event:consumed_contact":{"owner_namespace":"event","presentation_object_id":"event:consumed_contact"},"scenario::owned_event":{"owner_namespace":"scenario","presentation_object_id":"scenario::owned_event"}},"interactions":{"event::event:consumed_contact":{"owner_namespace":"event","presentation_object_id":"event:consumed_contact"}},"target_inventory":{"scene_objects":["event::event:consumed_contact"]}}
	var derived := {"semantic_state":semantic.duplicate(true)}
	var layout_records: Array=Resolver._live_layout_records([consumed,fixed_event,scenario_event,current_event],derived,run.current_environment)
	_check(layout_records==[fixed_event,scenario_event,current_event],"Only consumed ordinary event-family presence is removed from live layout")
	_check(not derived.semantic_state.scene_objects.has("event::event:consumed_contact"),"Consumed event's derived visual cannot claim the replacement's slot")
	_check(not derived.semantic_state.interactions.has("event::event:consumed_contact"),"Consumed event's derived action is absent")
	_check(derived.semantic_state.scene_objects.has("scenario::owned_event"),"Scenario-owned visual retains independent authority")
	_check(derived.semantic_state.target_inventory==semantic.target_inventory,"Immutable declared identity inventory is not rewritten")
	_check(run.current_environment==before and run.rng_state==rng,"Live projection filtering leaves durable journal, bindings and RNG unchanged")
	# Engine causal commits call the resolver directly, bypassing RunState's cold
	# finalization. The shared entry point must apply the same live membership.
	var only_consumed := {"semantic_state":{"scene_objects":{"event::event:consumed_contact":semantic.scene_objects["event::event:consumed_contact"]},"interactions":{"event::event:consumed_contact":semantic.interactions["event::event:consumed_contact"]},"target_inventory":semantic.target_inventory.duplicate(true)}}
	var input_before := only_consumed.duplicate(true)
	var direct := Resolver.resolve([consumed],only_consumed,run.current_environment)
	_check(bool(direct.get("ok",false)),"Direct resolver used by causal advancement retires consumed presence")
	_check(direct.get("projection",{}).get("semantic_state",{}).get("scene_objects",{}).is_empty(),"Causal resolver cannot reseal the retired event visual")
	_check(direct.get("projection",{}).get("semantic_state",{}).get("interactions",{}).is_empty(),"Causal resolver cannot reseal the retired event action")
	_check(only_consumed==input_before,"Resolver filtering owns its derived projection and preserves caller inputs")
	_check(direct.get("projection",{}).get("semantic_state",{}).get("target_inventory")==semantic.target_inventory,"Direct resolver leaves immutable entry inventory intact")
	var cache_before := ScenarioEngineScript._sequence_layout_input_digest(run.current_environment,only_consumed)
	var changed_lifetime := run.current_environment.duplicate(true);changed_lifetime["resolved_event_ids"]=[]
	_check(ScenarioEngineScript._sequence_layout_input_digest(changed_lifetime,only_consumed)!=cache_before,"Resolved event lifetime invalidates causal geometry reuse")
	for failure in failures:push_error(failure)
	print("SCENARIO_EVENT_RESTORE_BINDING checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
