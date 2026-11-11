extends SceneTree
const Inventory := preload("res://scripts/core/environment_semantic_inventory.gd")
const NATIVE_RECT_JSON := '{"character:nell":{"h":0.167441860465116,"w":0.08,"x":0.784444444444445,"y":0.297674418604651}}'
const WEB_RECT_JSON := '{"character:nell":{"h":0.167441860465116,"w":0.08,"x":0.784444444444444,"y":0.297674418604651}}'
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:
	# Exact observed IEEE-754 payload, not an engine-dependent decimal parser.
	var tie := PackedByteArray([0x70,0x5e,0x4d,0x3c,0x2b,0x1a,0xe9,0x3f]).decode_double(0)
	var rect := {"x":tie,"y":0.297674418604651,"w":0.08,"h":0.167441860465116}
	var rects := {"character:nell":rect}
	_check(Inventory._legacy_layout_rects_json(rects,true)==NATIVE_RECT_JSON,"Frozen native candidate bytes")
	_check(Inventory._legacy_layout_rects_json(rects,false)==WEB_RECT_JSON,"Frozen Web candidate bytes")
	var inventory := Inventory.for_instance({"id":"legacy_geometry_test","world_node_id":"legacy_geometry_test","archetype_id":"motel","layout":{"object_rects":rects}})
	_check(Inventory.validate(inventory).is_empty(),"Synthetic instance starts with a valid complete proof")
	var original:=var_to_bytes(inventory)
	for half_up in [true,false]:
		var historical:=inventory.duplicate(true)
		historical.digest=Inventory._legacy_layout_digest(historical,half_up)
		_check(not str(historical.digest).is_empty() and Inventory.validate(historical).is_empty(),"Exact complete historical candidate accepted")
		_check(not Inventory.exact_collections(historical).is_empty(),"Historical proof remains usable by exact collections")
		var changed:=historical.duplicate(true);changed.source_provenance.layout_object_rects["character:nell"].x+=0.000000001
		_check(not Inventory.validate(changed).is_empty(),"Changed valid geometry cannot reuse stored historical digest")
		for digest in ["","0".repeat(64),str(historical.digest).to_upper(),"f".repeat(63),123]:
			changed=historical.duplicate(true);changed.digest=digest
			_check(not Inventory.validate(changed).is_empty(),"Malformed or different digest rejected")
		for kind in ["catalog",false,1]:
			changed=historical.duplicate(true);changed.kind=kind
			_check(Inventory._legacy_layout_digest(changed,true).is_empty() and not Inventory.validate(changed).is_empty(),"Wrong kind cannot use instance compatibility")
		for schema in ["2",2.0,0,3]:
			changed=historical.duplicate(true);changed.schema_version=schema
			_check(Inventory._legacy_layout_digest(changed,true).is_empty() and not Inventory.validate(changed).is_empty(),"Wrong schema type/version rejected")
		changed=historical.duplicate(true);changed.source_provenance["unknown_authority"]=true
		changed.digest=Inventory._legacy_layout_digest(changed,half_up)
		_check(not str(changed.digest).is_empty() and not Inventory.validate(changed).is_empty(),"Even a matching candidate cannot erase unknown authority errors")
		changed=historical.duplicate(true);changed.source_provenance.erase("object_manifest_authority")
		changed.digest=Inventory._legacy_layout_digest(changed,half_up)
		_check(not Inventory.validate(changed).is_empty(),"Missing authority remains invalid")
		changed=historical.duplicate(true);changed.guaranteed.scene_objects.append("base::event:forged")
		changed.digest=Inventory._legacy_layout_digest(changed,half_up)
		_check(not Inventory.validate(changed).is_empty(),"Added unproven identity remains invalid")
		changed=historical.duplicate(true);changed.guaranteed.scene_objects.clear()
		changed.digest=Inventory._legacy_layout_digest(changed,half_up)
		_check(not Inventory.validate(changed).is_empty(),"Missing identity remains invalid")
		for value in ["0.2",false,INF,NAN,-0.0000000000001]:
			changed=historical.duplicate(true);changed.source_provenance.layout_object_rects["character:nell"].x=value
			_check(Inventory._legacy_layout_digest(changed,half_up).is_empty() and not Inventory.validate(changed).is_empty(),"Malformed rectangle cannot use compatibility")
		changed=historical.duplicate(true);changed.source_provenance.layout_object_rects["character:nell"]["extra"]=1
		_check(Inventory._legacy_layout_digest(changed,half_up).is_empty() and not Inventory.validate(changed).is_empty(),"Extra rectangle key rejected")
		changed=historical.duplicate(true);changed.source_provenance.layout_object_rects["character:nell"].erase("w")
		_check(Inventory._legacy_layout_digest(changed,half_up).is_empty() and not Inventory.validate(changed).is_empty(),"Missing rectangle key rejected")
		changed=historical.duplicate(true);changed.source_provenance.layout_object_rects["character:nell"].w=0.00000000000000000001;changed.digest=""
		_check(not Inventory._legacy_layout_digest_matches(changed) and not Inventory.validate(changed).is_empty(),"Empty digest plus unsupported tiny width cannot match empty candidate")
	var negative_zero:=PackedByteArray([0,0,0,0,0,0,0,0x80]).decode_double(0)
	_check(Inventory._legacy_layout_float_text(negative_zero,true).is_empty() and Inventory._legacy_layout_float_text(negative_zero,false).is_empty(),"Negative-zero compatibility deliberately declines")
	var catalog:=Inventory.for_archetype({"id":"legacy_catalog_test"})
	catalog.digest=""
	_check(Inventory._legacy_layout_digest(catalog,true).is_empty() and not Inventory.validate(catalog).is_empty(),"Empty catalog digest cannot match unsupported instance candidate")
	_check(var_to_bytes(inventory)==original,"All comparisons preserve original complete body and digest")
	for failure in failures:push_error(failure)
	print("SCENARIO_INVENTORY_LEGACY_SERIALIZATION checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
