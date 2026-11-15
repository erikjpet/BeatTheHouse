extends SceneTree
const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const PackScript := preload("res://scripts/ui/environment_art_pack.gd")
const RendererScript := preload("res://scripts/ui/environment_art_renderer.gd")
class Probe:
    extends CanvasScript
    var empty_labels: Array = []
    var draw_order: Array = []
    func _draw() -> void:
        empty_labels.clear()
        draw_order.clear()
        super._draw()
    func _neon_text(text: String, pos: Vector2, font_size: int, color: Color) -> void:
        if text == "EMPTY":
            empty_labels.append({"text":text,"pos":[pos.x,pos.y],"size":font_size,"color":color.to_html(true)})
            draw_order.append("empty")
    func _draw_environment_art_animations(_pack: EnvironmentArtPack) -> void:
        draw_order.append("pack")
    func _draw_authored_counter_foregrounds() -> void:
        draw_order.append("foreground")
    func _draw_scene_objects() -> void:
        draw_order.append("objects")
class LabelPixels:
    extends CanvasScript
    var reference := false
    func _draw() -> void:
        if reference:
            _neon_text("EMPTY",Vector2(116,198),13,C_SOFT.darkened(0.25))
        else:
            _draw_cage_gift_stock_empty_label()
var checks := 0
var failures: Array[String] = []
func _init() -> void:
    call_deferred("_run")
func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        push_error(message)
func _run() -> void:
    var cases: Array = [
        {"id":"missing","state":{},"empty":true},
        {"id":"empty","state":{"stock":[]},"empty":true},
        {"id":"all_sold","state":{"stock":[{"sold":true},{"sold":true}]},"empty":true},
        {"id":"populated","state":{"stock":[{"sold":true},{"sold":false}]},"empty":false},
        {"id":"malformed_entries","state":{"stock":[null,7,"bad"]},"empty":true},
        {"id":"missing_sold_flag","state":{"stock":[{}]},"empty":false},
        {"id":"malformed_shop","state":"bad","empty":true}
    ]
    var rows: Array = []
    for item in cases:
        var prior: Array = []
        for packed in [false,true]:
            var viewport := SubViewport.new()
            viewport.size=Vector2i(900,430)
            viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
            root.add_child(viewport)
            var canvas := Probe.new()
            canvas.size=Vector2(900,430)
            canvas.environment_id="grand_casino_cage"
            canvas.foundation_snapshot={"cage_gift_shop_state":item["state"]}
            canvas.reduce_motion=true
            if packed:
                canvas.environment_art_pack=PackScript.new()
                canvas.environment_art_renderer=RendererScript.new()
                canvas.environment_art_renderer.ready_to_present=true
                canvas.add_child(canvas.environment_art_renderer)
            viewport.add_child(canvas)
            for frame in range(3):await process_frame
            canvas.queue_redraw()
            await RenderingServer.frame_post_draw
            var labels: Array=canvas.empty_labels.duplicate(true)
            var order: Array=canvas.draw_order.duplicate()
            _check(labels.size()==(1 if item["empty"] else 0),str(item["id"])+" exactly one/zero EMPTY "+str(packed))
            if item["empty"]:
                _check(labels[0]["pos"]==[116.0,198.0] and labels[0]["size"]==13,"Original position/font")
                _check(order.find("empty")<order.find("foreground") and order.find("foreground")<order.find("objects"),"EMPTY before foreground and live objects")
            if packed:
                _check(labels==prior,str(item["id"])+" packed/fallback exact label equality")
                _check(order[0]=="pack","Packed layer precedes dynamic label")
            else:prior=labels
            rows.append({"case":item["id"],"packed":packed,"labels":labels,"order":order})
            viewport.free()
    var pixel_results: Array=[]
    var reference_bytes := PackedByteArray()
    for mode in ["reference","empty","populated"]:
        var vp:=SubViewport.new()
        vp.size=Vector2i(900,430)
        vp.transparent_bg=true
        vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        root.add_child(vp)
        var c:=LabelPixels.new()
        c.size=Vector2(900,430)
        c.reference=mode=="reference"
        c.foundation_snapshot={"cage_gift_shop_state":{"stock":[{"sold":false}] if mode=="populated" else []}}
        vp.add_child(c)
        for frame in range(3):await process_frame
        await RenderingServer.frame_post_draw
        var img:=vp.get_texture().get_image()
        if mode=="reference":reference_bytes=img.get_data()
        if mode=="empty":_check(img.get_data()==reference_bytes,"Rendered empty label exactly matches original text call")
        if mode=="populated":_check(img.get_used_rect().size==Vector2i.ZERO,"Rendered populated label is transparent")
        else:_check(img.get_used_rect().size!=Vector2i.ZERO,"Rendered empty/reference label has visible pixels")
        var output:=OS.get_environment("BTH_QA_EVIDENCE_DIR")
        if not output.is_empty():img.save_png(output.path_join("label_"+mode+".png"))
        pixel_results.append({"mode":mode,"used_rect":str(img.get_used_rect()),"equals_reference":img.get_data()==reference_bytes})
        vp.free()
    var result={"checks":checks,"failures":failures,"cases":rows,"rendered_label_pixels":pixel_results,"scope":"Actual production _draw branch with intercepted art surface/text calls; no stock mutation or owner save. Exact conditional label semantics and draw-order, not final pack pixel acceptance."}
    var out:=OS.get_environment("BTH_QA_EVIDENCE_DIR")
    if not out.is_empty():
        var f:=FileAccess.open(out.path_join("cage-empty-label-contract.json"),FileAccess.WRITE)
        f.store_string(JSON.stringify(result,"  "))
    print("CAGE_EMPTY_LABEL ",JSON.stringify(result))
    quit(0 if failures.is_empty() else 1)
