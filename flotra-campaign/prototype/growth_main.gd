extends Node

# Campaign entry point. Storage is isolated from all legacy Godot saves.
const SimScript = preload("res://prototype/dispatch_sim.gd")
const HudScript = preload("res://prototype/dispatch_hud.gd")
const ViewScript = preload("res://prototype/growth_view.gd")
var sim
var hud: CanvasLayer
var world: Node3D
var viewport: SubViewport
var viewport_container: SubViewportContainer
var running := false
var speed := 2.0
const SaveScript = preload("res://prototype/dispatch_save.gd")
var save_store = SaveScript.new()
var persistence_enabled := true
var _save_elapsed := 0.0
const AUTOSAVE_CAPTURE_SECONDS := 5.0
const MAX_AUTOSAVE_SUBSEQUENT_FRAMES := 3
const MAX_AUTOSAVE_FOREGROUND_SECONDS := 1.0
var _autosave_subsequent_frames := 0
var _autosave_foreground_elapsed := 0.0
var _last_status := ""
var _loaded := false
var _save_load_result: Dictionary = {}
var _phone_qa := false
var _qa_elapsed := 0.0
var _web_touch_cancel_callback: JavaScriptObject
var _menu_paused := false
var _preferences := {"preferred_speed": 2, "pause_on_menus": false, "reduced_motion": false}
const MAX_FOREGROUND_FRAME_SECONDS := 0.25
# Godot's process delta is catch-up capped on very slow renderers. Use a
# monotonic foreground clock within the existing per-frame work budget.
# Longer stalls are discarded instead of creating an expensive catch-up spiral.
# Callable injection keeps slow-frame/pause tests deterministic.
var frame_clock: Callable = func() -> int: return Time.get_ticks_usec()
var _last_frame_usec := -1
var _clock_active := false

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
        _save_load_result = save_store.load_into(sim)
    _apply_preferences()
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
    # Small CSS-sized 3D surface: smooth subpixel rack/floor edges without
    # increasing its resolution or changing the full-DPR HUD.
    viewport.msaa_3d = Viewport.MSAA_2X
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = true
    viewport_container.add_child(viewport)
    world = ViewScript.new()
    viewport.add_child(world)
    world.call("bind_sim", sim)
    hud = HudScript.new()
    hud.call("bind_sim", sim)
    add_child(hud)
    world.input_gate = func(): return is_instance_valid(hud) and hud._sheet_kind in ["", "editor"] and not hud._background_input_blocked()
    world.camera_input_gate = func(): return is_instance_valid(hud) and hud._sheet_kind.is_empty()
    _connect_if("camera_requested", _camera_action)
    hud.call("set_speed",speed)
    _connect_if("contract_requested", _accept_contract)
    _connect_if("upgrade_requested", _buy_upgrade)
    _connect_if("speed_requested", _set_speed)
    _connect_if("preference_requested", _set_preference)
    _connect_if("operation_requested", _set_operation)
    _connect_if("dispatch_window_requested", _set_dispatch_window)
    _connect_if("cancel_layout_requested", _cancel_layout)
    _connect_if("sheet_changed", _sheet_clock_changed)
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
    _apply_preferences()
    hud.call("set_save_status", save_store.status if persistence_enabled else "テスト・保存なし")
    if hud.has_method("show_intro"):
        hud.call("show_intro")
    _update_world_visibility()
    if _save_protected() and hud.has_method("show_save_protection"):
        hud.call("show_save_protection", save_store.status)
    if OS.has_feature("web"):
        _web_touch_cancel_callback = JavaScriptBridge.create_callback(_cancel_web_touch)
        var bridge := JavaScriptBridge.get_interface("FlotraViewport")
        if bridge != null:
            bridge.setTouchCancelHandler(_web_touch_cancel_callback)
        _report_web_viewport.call_deferred()

func _exit_tree() -> void:
    if OS.has_feature("web"):
        var bridge := JavaScriptBridge.get_interface("FlotraViewport")
        if bridge != null:
            bridge.setTouchCancelHandler(null)

func _cancel_web_touch(_arguments: Array = []) -> void:
    # DOM capture runs before Godot queues its (uncanceled) touchend. Drain
    # earlier starts first: invalidating only the current epoch loses a race
    # when several start/cancel pairs arrive before one rendered frame.
    Input.flush_buffered_events()
    if is_instance_valid(hud): hud.cancel_pointer_input()
    if is_instance_valid(world): world.cancel_pointer_input()

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
    data["worldVisible"] = viewport_container.visible
    data["worldRect"] = _qa_rect(viewport_container)
    data["camera"] = world.camera_metrics()
    var floors: Array = []
    for mesh in world._growth_floors + world._connector_floors:
        var point: Vector2 = viewport_container.position + world.camera.unproject_position(mesh.global_position)
        floors.append({"x":point.x,"y":point.y,"name":str(mesh.name)})
    data["camera"]["floorPoints"] = floors
    var callouts: Array = []
    for item in world._callouts.values():
        var label: Label = item.label
        var rect := _qa_rect(label)
        rect.merge({"text":label.text,"visible":label.visible,"fontSize":label.get_theme_font_size("font_size"), "anchorX":item.anchor.x, "anchorY":item.anchor.y})
        callouts.append(rect)
    data["camera"]["callouts"] = callouts
    var release: Dictionary = sim.release_state()
    data["growth"] = release.growth
    data["progress"] = release.progress
    data["status"] = sim.campaign_status
    data["wallet"] = sim.campaign_wallet
    data["upgrades"] = sim.purchased_upgrades.duplicate()
    data["currentContract"] = sim.current_contract_id
    data["jobComparison"] = sim.job_comparison()
    data["currentBest"] = release.get("best_time", 0.0)
    data["results"] = release.get("results", {})
    data["simTime"] = sim.sim_time
    data["speed"] = speed
    data["menuPaused"] = _menu_paused
    if persistence_enabled and save_store.has_method("autosave_status"):
        # Scalar-only inspection: never expose captures or a save command.
        data["autosave"] = save_store.autosave_status()
    data["preferences"] = release.get("preferences", {})
    data["operation"] = release.get("operations", {})
    data["batchWorkers"] = sim.workers.filter(func(worker): return worker.task in ["pick", "ship"] and worker.cargo_ids.size() > 1).size()
    data["layout"] = {"current":sim.layout_id,"pending":sim.pending_layout_id,"moving":sim._move_remaining > 0.0}
    data["performance"] = {"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"processMs":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0}
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
    if world != null and world.has_method("cancel_pointer_input"):
        world.call("cancel_pointer_input")
    if world != null and world.has_method("fit_camera"):
        world.call("fit_camera", viewport_container.size)

func _camera_action(action: String) -> void:
    if is_instance_valid(world): world.camera_action(action)

func _input(event: InputEvent) -> void:
    if not is_instance_valid(world) or not is_instance_valid(viewport_container): return
    if OS.has_feature("web") and event is InputEventMouseMotion and world._camera_mouse_down:
        # Godot Web retains its old button mask after a missed mouseup. The DOM
        # capture listener runs before the engine handler for this same event.
        var buttons := int(JavaScriptBridge.eval("window.FlotraViewport && typeof window.FlotraViewport.mouseButtons === 'number' ? window.FlotraViewport.mouseButtons : -1", true))
        if buttons >= 0 and (buttons & 1) == 0:
            world.cancel_pointer_input()
            return
    # A world gesture ends when it crosses into HUD space. Observe before GUI
    # consumes the event, so a release over a button cannot leave a held camera.
    if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
        if not viewport_container.get_global_rect().has_point(event.position):
            world.cancel_pointer_input()

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
    if _save_protected() and running:
        _reject_if_save_protected()
    _menu_paused = running and bool(_preferences.pause_on_menus) and is_instance_valid(hud) and not str(hud._sheet_kind).is_empty()
    var active := running and not _menu_paused
    var now_usec: int = frame_clock.call()
    var foreground_seconds := 0.0
    if active and _clock_active and _last_frame_usec >= 0 and now_usec >= _last_frame_usec:
        foreground_seconds = minf(float(now_usec - _last_frame_usec) / 1000000.0, MAX_FOREGROUND_FRAME_SECONDS)
    _last_frame_usec = now_usec
    _clock_active = active
    # Service an older immutable capture before granting more live progress.
    # This is a foreground-progress/frame bound, not a wall-clock deadline:
    # suspended render frames cannot finish a staged write by themselves.
    _advance_autosave(foreground_seconds)
    if active and not _save_protected():
        sim.step(foreground_seconds * speed)
        _save_elapsed += foreground_seconds
        if sim.campaign_status != _last_status:
            _last_status = sim.campaign_status
            _save_now()
        elif _save_elapsed >= AUTOSAVE_CAPTURE_SECONDS:
            _begin_autosave()
    if hud != null:
        hud.call("refresh")
    if world != null:
        _update_world_visibility()
        if viewport_container.visible:
            world.call("refresh")

func _update_world_visibility() -> void:
    # Full-height reading sheets cover the warehouse. Keep its simulation and
    # autosaves running, but do not render a hidden 3D scene behind those sheets.
    if not is_instance_valid(hud) or not is_instance_valid(viewport): return
    var visible_world: bool = hud._sheet_kind not in ["entry","jobs","records","controls"]
    viewport_container.visible = visible_world
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible_world else SubViewport.UPDATE_DISABLED

func _start_trial() -> void:
    if _reject_if_save_protected(): return
    # An imported domain-level pause remains intact until explicit Resume.
    if sim.time_scale == 0.0: sim.time_scale = 1.0
    running = true
    _reset_frame_clock()
    hud.call("set_trial_running", true)

func _pause_trial(paused: bool) -> void:
    if not paused and _reject_if_save_protected(): return
    if not paused and sim.time_scale == 0.0: sim.time_scale = 1.0
    running = not paused
    _reset_frame_clock()
    hud.call("set_trial_running", running)
    _save_now()

func _return_to_intro() -> void:
    running = false
    _reset_frame_clock()
    hud.call("set_trial_running", false)
    hud.call("show_intro")
    _save_now()

func _apply_layout(id: String) -> void:
    if _reject_if_save_protected(): return
    var result: Dictionary = sim.apply_layout(id)
    hud.call("show_action_result", result)
    if result.get("ok",false): _save_now()
    world.call("set_preview", "")
    world.call("refresh")

func _apply_slot(slot_id: String, choice_id: String) -> void:
    if _reject_if_save_protected(): return
    var result: Dictionary = sim.apply_slot(slot_id, choice_id)
    hud.call("show_action_result", result)
    if result.get("ok",false): _save_now()
    world.call("refresh")

func _change_workload(id: String) -> void:
    if _reject_if_save_protected(): return
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
    if _reject_if_save_protected(): return
    var result: Dictionary = sim.accept_contract(id)
    hud.call("show_contract_result", result)
    if result.get("ok",false):
        if sim.time_scale == 0.0: sim.time_scale = 1.0
        running = true
        _reset_frame_clock()
        hud.call("set_trial_running", true)
        _save_now()
    world.call("refresh")

func _buy_upgrade(id: String) -> void:
    if _reject_if_save_protected(): return
    var result: Dictionary = sim.buy_upgrade(id)
    hud.call("show_upgrade_result", result)
    if result.get("ok",false): _save_now()
    world.call("refresh")

func _set_speed(value: float) -> void:
    if _reject_if_save_protected(): return
    speed = value if value in [1.0,2.0,4.0] else 2.0
    if sim.has_method("set_preference"):
        sim.set_preference("preferred_speed", int(speed))
    hud.call("set_speed",speed)
    _reset_frame_clock()
    _save_now()

func _apply_preferences() -> void:
    if sim == null: return
    var preferences: Dictionary = sim.release_state().get("preferences", {})
    for key in _preferences:
        if preferences.has(key): _preferences[key] = preferences[key]
    speed = float(preferences.get("preferred_speed", 2))
    if is_instance_valid(hud):
        hud.call("set_speed", speed)
        if hud.has_method("set_preferences"): hud.call("set_preferences", preferences)
    if is_instance_valid(world) and world.has_method("set_reduced_motion"):
        world.call("set_reduced_motion", bool(preferences.get("reduced_motion", false)))

func _set_preference(key: String, value: Variant) -> void:
    if _reject_if_save_protected(): return
    if not sim.has_method("set_preference"): return
    var result: Dictionary = sim.set_preference(key, value)
    if result.get("ok", false):
        _apply_preferences()
        if key in ["pause_on_menus", "preferred_speed"]: _reset_frame_clock()
        _save_now()

func _reset_frame_clock() -> void:
    _last_frame_usec = frame_clock.call()
    _clock_active = running and not (bool(_preferences.pause_on_menus) and is_instance_valid(hud) and not str(hud._sheet_kind).is_empty())

func _sheet_clock_changed(_kind: String) -> void:
    if is_instance_valid(world): world.cancel_pointer_input()
    # Anchor at the actual close/open action, not at the next rendered frame.
    # A long paused menu contributes no elapsed time after it is dismissed.
    if bool(_preferences.pause_on_menus): _reset_frame_clock()

func _set_operation(id: String) -> void:
    if _reject_if_save_protected(): return
    if not sim.has_method("set_operation"): return
    var result: Dictionary = sim.set_operation(id)
    if hud.has_method("show_operation_result"): hud.call("show_operation_result", result)
    if result.get("ok", false): _save_now()
    world.call("refresh")

func _cancel_layout() -> void:
    if _reject_if_save_protected(): return
    if not sim.has_method("cancel_layout"): return
    var result: Dictionary = sim.cancel_layout()
    if hud.has_method("show_cancel_layout_result"): hud.call("show_cancel_layout_result", result)
    if result.get("ok", false): _save_now()
    world.call("refresh")

func _set_dispatch_window(value: int) -> void:
    if _reject_if_save_protected(): return
    var result: Dictionary = sim.set_dispatch_window(value)
    if hud.has_method("show_dispatch_window_result"): hud.call("show_dispatch_window_result", result)
    if result.get("ok", false): _save_now()

func _save_protected() -> bool:
    return persistence_enabled and (save_store.blocked or bool(_save_load_result.get("blocked", false)))

func _reject_if_save_protected() -> bool:
    if not _save_protected(): return false
    running = false
    _reset_frame_clock()
    if is_instance_valid(hud):
        hud.call("set_trial_running", false)
        hud.call("set_save_status", save_store.status)
        if hud.has_method("show_save_protection"): hud.call("show_save_protection", save_store.status)
    return true

func _supports_staged_autosave() -> bool:
    # Older in-memory adapters and the no-save review path stay usable.
    return save_store.has_method("begin_autosave") and save_store.has_method("advance_autosave") and save_store.has_method("flush_autosave") and save_store.has_method("has_pending_autosave")

func _publish_save_status() -> void:
    # A writer conflict or uncertain write is terminal for this session. Show
    # the stop immediately, including saves made while already paused.
    if _reject_if_save_protected(): return
    if is_instance_valid(hud): hud.call("set_save_status",save_store.status)

func _begin_autosave() -> void:
    if not persistence_enabled or not _loaded or sim == null or not _supports_staged_autosave():
        _save_now()
        return
    var result: Dictionary = save_store.begin_autosave(sim)
    if result.get("started", false):
        # Capture cadence is independent of when the staged commit finishes.
        _save_elapsed = 0.0
        _autosave_subsequent_frames = 0
        _autosave_foreground_elapsed = 0.0
    _publish_save_status()

func _advance_autosave(foreground_seconds: float) -> void:
    if not persistence_enabled or not _loaded or not _supports_staged_autosave() or not save_store.has_pending_autosave(): return
    _autosave_subsequent_frames += 1
    var previous_status: String = save_store.status
    if _autosave_subsequent_frames >= MAX_AUTOSAVE_SUBSEQUENT_FRAMES or _autosave_foreground_elapsed + foreground_seconds > MAX_AUTOSAVE_FOREGROUND_SECONDS:
        save_store.flush_autosave()
    else:
        save_store.advance_autosave()
    if previous_status != save_store.status or _save_protected():
        _publish_save_status()
    if save_store.has_pending_autosave():
        _autosave_foreground_elapsed += foreground_seconds
    else:
        _autosave_subsequent_frames = 0
        _autosave_foreground_elapsed = 0.0

func _save_now() -> void:
    _save_elapsed = 0.0
    _autosave_subsequent_frames = 0
    _autosave_foreground_elapsed = 0.0
    if not persistence_enabled or not _loaded or sim == null: return
    # The store invalidates the older generation before capturing current state.
    save_store.save_from(sim)
    _publish_save_status()

func _notification(what: int) -> void:
    if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
        # A background tab/app never silently keeps advancing a player's job.
        # Returning is deliberately paused until an explicit Resume action.
        running = false
        _reset_frame_clock()
        if is_instance_valid(hud): hud.call("set_trial_running", false)
        _save_now()
    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
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
    return {"release":true,"persistent_writes":persistence_enabled,"production_save_loaded":false,"web_storage":"flotra.campaign.dispatch.v5","filesystem_persistence":false,"user_directory":OS.get_user_data_dir(),"app_name":ProjectSettings.get_setting("application/config/name")}

func _exit_trial() -> void:
    # This application has its own profile and never enters production main.
    running = false
    _reset_frame_clock()
    _save_now()
    if _save_protected(): return
    get_tree().quit()

func _preview_slot(slot_id: String, choice_id: String) -> void:
    world.call("preview_slot", slot_id, choice_id)
    _resize_world()
