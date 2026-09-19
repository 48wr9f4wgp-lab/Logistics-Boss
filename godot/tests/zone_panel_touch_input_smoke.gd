extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_touch_preview_and_commit():
        return
    if not await _verify_mouse_fallback_preview():
        return

    print("Godot Zone Panel raw touch fallback smoke passed")
    quit(0)


func _fresh_panel() -> Dictionary:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000

    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.open_zone("inbound")

    return {
        "sim": sim,
        "panel": panel,
    }


func _verify_touch_preview_and_commit() -> bool:
    var context := _fresh_panel()
    var sim: FlotraV2Sim = context["sim"]
    var panel: WarehouseZonePanel = context["panel"]

    await process_frame
    await process_frame

    var button := panel._capital_action
    if button == null or not button.visible or button.disabled:
        _fail("fresh Rank 1 INBOUND must expose an enabled capital action")
        return false

    var center := button.get_global_rect().get_center()
    var cash_before := sim.money

    _push_touch(center, true, 0)
    _push_touch(center, false, 0)
    await process_frame

    if panel.preview_kind() != &"forklift_project":
        _fail("real screen-touch tap must enter Forklift Project preview")
        return false
    if sim.money != cash_before:
        _fail("first real screen-touch tap must not spend cash")
        return false
    if not button.text.contains("建設する"):
        _fail("first real screen-touch tap must immediately change the button to 建設する")
        return false

    # iOS/Web may emit a synthetic mouse sequence after touch. The fallback
    # must swallow that duplicate so one physical tap cannot preview+commit.
    _push_mouse(center, true)
    _push_mouse(center, false)
    await process_frame
    if sim.money != cash_before:
        _fail("synthetic mouse after touch must not double-fire the capital action")
        return false
    if panel.preview_kind() != &"forklift_project":
        _fail("synthetic mouse suppression must preserve the active preview")
        return false

    _push_touch(center, true, 1)
    _push_touch(center, false, 1)
    await process_frame

    if sim.money >= cash_before:
        _fail("second explicit screen-touch tap must commit and spend cash")
        return false
    if not sim.rank1_project_owned(&"forklift_project"):
        _fail("second explicit screen-touch tap must purchase the authoritative Forklift Project")
        return false
    if panel.preview_kind() != &"":
        _fail("successful touch commit must clear the preview state")
        return false

    panel.queue_free()
    await process_frame
    return true


func _verify_mouse_fallback_preview() -> bool:
    var context := _fresh_panel()
    var sim: FlotraV2Sim = context["sim"]
    var panel: WarehouseZonePanel = context["panel"]

    await process_frame
    await process_frame

    var button := panel._capital_action
    var center := button.get_global_rect().get_center()
    var cash_before := sim.money

    panel._suppress_mouse_until_msec = 0
    _push_mouse(center, true)
    _push_mouse(center, false)
    await process_frame

    if panel.preview_kind() != &"forklift_project":
        _fail("mouse-only Web fallback must enter the same Forklift preview")
        return false
    if sim.money != cash_before:
        _fail("mouse-only fallback preview must not spend cash")
        return false
    if not button.text.contains("建設する"):
        _fail("mouse-only fallback must visibly acknowledge the first tap")
        return false

    panel.queue_free()
    await process_frame
    return true


func _push_touch(position: Vector2, pressed: bool, index: int) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = pressed
    get_root().push_input(event, true)


func _push_mouse(position: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = position
    event.pressed = pressed
    get_root().push_input(event, true)
