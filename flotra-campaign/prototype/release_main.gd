extends Node

# Campaign entry point. Storage is isolated from all legacy Godot saves.
const SimScript = preload("res://prototype/release_sim.gd")
const HudScript = preload("res://prototype/release_hud.gd")
const ViewScript = preload("res://prototype/release_view.gd")
var sim
var hud: CanvasLayer
var world: Node3D
var viewport: SubViewport
var viewport_container: SubViewportContainer
var running := false
var speed := 1.0
const SaveScript = preload("res://prototype/release_save.gd")
var save_store = SaveScript.new()
var persistence_enabled := true
var _save_elapsed := 0.0
var _last_status := ""
var _loaded := false
var _phone_qa := false
var _qa_elapsed := 0.0

func _ready() -> void:
    # Native window units are already logical pixels. The web drawing buffer is
    # high-DPI device pixels, so use the canvas's CSS rectangle as our layout space.
    if OS.has_feature("web"):
        # String return matches the established bridge contract across Web builds.
        _phone_qa = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get(\"phone_qa\") === \"1\" ? \"1\" : \"0\"", true)) == "1"
        _sync_web_viewport()
    else:
        get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
        get_tree().root.content_scale_size = Vector2i.ZERO
    sim = SimScript.new()
    if persistence_enabled:
        save_store.load_into(sim)
    _loaded = true
    var background := ColorRect.new()
    background.color = Color("101e29")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)
    viewport_container = SubViewportContainer.new()
    viewport_container.name = "WarehouseViewportContainer"
    viewport_container.stretch = true
    viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(viewport_container)
    viewport = SubViewport.new()
    viewport.name = "WarehouseViewport"
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = true
    viewport_container.add_child(viewport)
    world = ViewScript.new()
    viewport.add_child(world)
    world.call("bind_sim", sim)
    hud = HudScript.new()
    hud.call("bind_sim", sim)
    add_child(hud)
    _connect_if("contract_requested", _accept_contract)
    _connect_if("upgrade_requested", _buy_upgrade)
    _connect_if("speed_requested", _set_speed)
    _connect_if("trial_started", _start_trial)
    _connect_if("back_requested", _return_to_intro)
    _connect_if("exit_requested", _exit_trial)
    _connect_if("pause_requested", _pause_trial)
    _connect_if("layout_action_requested", _apply_layout)
    _connect_if("slot_action_requested", _apply_slot)
    _connect_if("workload_requested", _change_workload)
    _connect_if("job_mix_requested", _change_workload)
    _connect_if("reset_requested", _restart_trial)
    _connect_if("selected_layout_changed", _preview_layout)
    _connect_if("selected_slot_changed", _select_slot)
    _connect_if("slot_candidate_changed", _preview_slot)
    _connect_if("world_rect_changed", _resize_world)
    if world.has_signal("slot_selected"):
        world.connect("slot_selected", _world_slot_selected)
    get_viewport().size_changed.connect(_resize_world)
    if OS.has_feature("web"):
        get_tree().root.size_changed.connect(func(): _report_web_viewport.call_deferred())
    _resize_world()
    hud.call("set_save_status", save_store.status if persistence_enabled else "テスト・保存なし")
    if hud.has_method("show_intro"):
        hud.call("show_intro")
    if OS.has_feature("web"):
        _report_web_viewport.call_deferred()

# Keep logical controls and input coordinates independent of the browser's DPR.
# The loader owns the full-resolution backing buffer; Godot stretches canvas
# items and transforms browser input into this exact CSS-pixel coordinate space.
func _apply_logical_viewport(css_size: Vector2i) -> void:
    if css_size.x <= 0 or css_size.y <= 0:
        return
    var window := get_tree().root
    if window.content_scale_size == css_size and window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
        return
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
    window.content_scale_size = css_size
    if OS.has_feature("web"):
        _report_web_viewport.call_deferred()
    if is_instance_valid(hud):
        hud.call("_layout")
        _resize_world.call_deferred()

func _report_web_viewport() -> void:
    if not OS.has_feature("web") or not is_instance_valid(hud):
        return
    var logical := get_viewport().get_visible_rect().size
    var transform := get_viewport().get_screen_transform()
    var dimensions: Vector2 = hud._root.size
    var metrics := {"logicalWidth": logical.x, "logicalHeight": logical.y,
        "rootWidth": get_tree().root.size.x, "rootHeight": get_tree().root.size.y,
        "hudWidth": dimensions.x, "hudHeight": dimensions.y,
        "scaleX": transform.x.length(), "scaleY": transform.y.length()}
    JavaScriptBridge.eval("if (window.FlotraViewport) window.FlotraViewport.engineMetrics = %s" % JSON.stringify(metrics), true)

func _sync_web_viewport() -> void:
    var encoded: Variant = JavaScriptBridge.eval("window.FlotraViewport ? window.FlotraViewport.metricsJSON : ''", true)
    if not encoded is String or encoded.is_empty():
        return
    var metrics: Variant = JSON.parse_string(encoded)
    if metrics is Dictionary:
        _apply_logical_viewport(Vector2i(roundi(float(metrics.get("width", 0))), roundi(float(metrics.get("height", 0)))))

# Opt-in, read-only diagnostics for the actual exported browser/input suite.
# It exposes visible UI geometry, never commands or save/import/reset methods.
func _qa_rect(control: Control) -> Dictionary:
    var rect := control.get_global_rect()
    return {"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y}

func _report_phone_qa() -> void:
    if not _phone_qa or not is_instance_valid(hud): return
    var buttons: Array = []
    var labels: Array = []
    var pending: Array[Node] = [hud._root]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        for child in node.get_children(): pending.append(child)
        if node is Button:
            var data := _qa_rect(node)
            data.merge({"name":str(node.name),"text":node.text,"disabled":node.disabled,
                "visible":node.is_visible_in_tree(),"fontSize":node.get_theme_font_size("font_size")})
            buttons.append(data)
        elif node is Label and node.is_visible_in_tree():
            var data := _qa_rect(node)
            data.merge({"name":str(node.name),"text":node.text,"fontSize":node.get_theme_font_size("font_size")})
            labels.append(data)
    var data := {"sheet":hud._sheet_kind,"trialRunning":hud._trial_running,
        "selectedSlot":world._selected,"buttons":buttons,"labels":labels,"scroll":{}}
    if is_instance_valid(hud._scroll):
        data.scroll = _qa_rect(hud._scroll)
        data.scroll.merge({"scrollVertical":hud._scroll.scroll_vertical,
            "max":hud._scroll.get_v_scroll_bar().max_value,"page":hud._scroll.get_v_scroll_bar().page})
    var slots := {}
    for id in world._slots:
        var point: Vector2 = viewport_container.position + world.camera.unproject_position(world._slots[id].position + Vector3(0,1,0))
        slots[id] = {"x":point.x,"y":point.y}
    data["slots"] = slots
    JavaScriptBridge.eval("if (window.FlotraViewport) window.FlotraViewport.uiMetrics = %s" % JSON.stringify(data), true)

func _connect_if(key: StringName, target: Callable) -> void:
    if hud.has_signal(key):
        hud.connect(key, target)

func _resize_world() -> void:
    var size := get_viewport().get_visible_rect().size
    var top := 158.0
    var bottom := 182.0
    if hud != null and hud.has_method("world_insets"):
        var insets: Vector2 = hud.call("world_insets")
        top = insets.x
        bottom = insets.y
    viewport_container.position = Vector2(0, top)
    viewport_container.size = Vector2(size.x, maxf(96.0, size.y-top-bottom))
    if world != null and world.has_method("fit_camera"):
        world.call("fit_camera", viewport_container.size)

func _process(delta: float) -> void:
    if OS.has_feature("web"):
        _sync_web_viewport()
        if _phone_qa:
            _qa_elapsed += delta
            if _qa_elapsed >= 0.2:
                _qa_elapsed = 0.0
                _report_phone_qa()
    if sim == null:
        return
    if running:
        sim.step(minf(delta, 0.25) * speed)
        _save_elapsed += delta
        var state: Dictionary = sim.release_state()
        if str(state.get("status","")) != _last_status:
            _last_status = str(state.get("status",""))
            _save_now()
        elif _save_elapsed >= 5.0:
            _save_now()
    if hud != null:
        hud.call("refresh")
    if world != null:
        world.call("refresh")

func _start_trial() -> void:
    running = true
    hud.call("set_trial_running", true)

func _pause_trial(paused: bool) -> void:
    running = not paused
    hud.call("set_trial_running", running)
    _save_now()

func _return_to_intro() -> void:
    running = false
    hud.call("set_trial_running", false)
    hud.call("show_intro")

func _apply_layout(id: String) -> void:
    var result: Dictionary = sim.apply_layout(id)
    hud.call("show_action_result", result)
    if result.get("ok",false): _save_now()
    world.call("set_preview", "")
    world.call("refresh")

func _apply_slot(slot_id: String, choice_id: String) -> void:
    var result: Dictionary = sim.apply_slot(slot_id, choice_id)
    hud.call("show_action_result", result)
    if result.get("ok",false): _save_now()
    world.call("refresh")

func _change_workload(id: String) -> void:
    # Changing future contracts must never erase existing cargo or measurement.
    var result: Dictionary = sim.set_mix(id)
    if hud.has_method("show_job_mix_result"):
        hud.call("show_job_mix_result", result)
    else:
        hud.call("show_action_result", result)
    hud.call("refresh")


func _restart_trial() -> void:
    # Legacy reset is intentionally unavailable. Replay requires a completed contract.
    hud.call("show_job_choices")

func _accept_contract(id: String) -> void:
    var result: Dictionary = sim.accept_contract(id)
    hud.call("show_contract_result", result)
    if result.get("ok",false):
        running = true
        hud.call("set_trial_running", true)
        _save_now()
    world.call("refresh")

func _buy_upgrade(id: String) -> void:
    var result: Dictionary = sim.buy_upgrade(id)
    hud.call("show_upgrade_result", result)
    if result.get("ok",false): _save_now()
    world.call("refresh")

func _set_speed(value: float) -> void:
    speed = value if value in [1.0,2.0] else 1.0
    hud.call("set_speed",speed)

func _save_now() -> void:
    _save_elapsed = 0.0
    if not persistence_enabled or not _loaded or sim == null: return
    save_store.save_from(sim)
    if is_instance_valid(hud): hud.call("set_save_status",save_store.status)

func _notification(what: int) -> void:
    if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
        _save_now()

func _preview_layout(id: String) -> void:
    world.call("set_preview", id)

func _select_slot(id: String) -> void:
    world.call("select_slot", id)
    _resize_world()

func _world_slot_selected(id: String) -> void:
    if hud.has_method("select_slot"):
        hud.call("select_slot", id)
    else:
        world.call("select_slot", id)

func isolation_status() -> Dictionary:
    return {"release":true,"persistent_writes":persistence_enabled,"production_save_loaded":false,"web_storage":"flotra.campaign.release.v1","filesystem_persistence":false,"user_directory":OS.get_user_data_dir(),"app_name":ProjectSettings.get_setting("application/config/name")}

func _exit_trial() -> void:
    # This application has its own profile and never enters production main.
    running = false
    get_tree().quit()

func _preview_slot(slot_id: String, choice_id: String) -> void:
    world.call("preview_slot", slot_id, choice_id)
    _resize_world()
