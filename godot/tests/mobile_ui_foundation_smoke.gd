extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")
const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")

const TAP_MOVE := 20.0


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_mobile_font_tree():
        return
    if not await _verify_management_touch_navigation():
        return
    if not await _verify_button_drag_still_scrolls():
        return

    print("Godot mobile UI foundation smoke passed")
    quit(0)


func _fresh_hud() -> Dictionary:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000

    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)

    return {
        "sim": sim,
        "hud": hud,
    }


func _verify_mobile_font_tree() -> bool:
    var context := _fresh_hud()
    var hud: MobileGameHud = context["hud"]
    await process_frame
    await process_frame

    var checked := 0
    var problems: Array[String] = []
    _collect_font_problems(hud, checked, problems)

    if checked < 10:
        _fail("mobile font smoke must inspect a meaningful set of text controls")
        return false
    if not problems.is_empty():
        _fail("mobile text controls must use the bundled Japanese font: %s" % ", ".join(problems))
        return false

    for codepoint in ["倉".unicode_at(0), "庫".unicode_at(0), "評".unicode_at(0), "価".unicode_at(0)]:
        if not JAPANESE_UI_FONT.has_char(codepoint):
            _fail("bundled Japanese font must contain required gameplay glyphs")
            return false

    hud.queue_free()
    await process_frame
    return true


func _collect_font_problems(node: Node, checked: int, problems: Array[String]) -> int:
    var next_checked := checked

    if node is Label:
        var label := node as Label
        if not label.text.is_empty():
            next_checked += 1
            var font := label.get_theme_font("font")
            if font != JAPANESE_UI_FONT:
                problems.append(label.name)
    elif node is Button:
        var button := node as Button
        if not button.text.is_empty():
            next_checked += 1
            var font := button.get_theme_font("font")
            if font != JAPANESE_UI_FONT:
                problems.append(button.name)

    for child in node.get_children():
        next_checked = _collect_font_problems(child, next_checked, problems)

    return next_checked


func _verify_management_touch_navigation() -> bool:
    var context := _fresh_hud()
    var hud: MobileGameHud = context["hud"]
    await process_frame
    await process_frame

    hud._sheet.visible = true
    hud._apply_v2_primary_hud()
    hud._apply_v2_management_scope()
    await process_frame

    var requested := {"zone": ""}
    var on_nav := func(zone_key: String) -> void:
        requested["zone"] = zone_key
    hud.zone_navigation_requested.connect(on_nav)

    var storage := hud._v2_zone_nav_buttons.get("storage") as Button
    if storage == null or not storage.visible or storage.disabled:
        _fail("Management must expose an enabled STORAGE navigation button")
        return false
    if storage.mouse_filter != Control.MOUSE_FILTER_STOP:
        _fail("Management buttons must own taps instead of passing them to ScrollContainer")
        return false

    _push_touch(storage.get_global_rect().get_center(), true, 0)
    _push_touch(storage.get_global_rect().get_center(), false, 0)
    await process_frame

    if String(requested["zone"]) != "storage":
        _fail("real ScreenTouch on Management STORAGE must trigger Zone navigation")
        return false
    if hud._sheet.visible:
        _fail("Management touch navigation must close the sheet before opening the Zone")
        return false

    if hud.zone_navigation_requested.is_connected(on_nav):
        hud.zone_navigation_requested.disconnect(on_nav)
    hud.queue_free()
    await process_frame
    return true


func _verify_button_drag_still_scrolls() -> bool:
    var context := _fresh_hud()
    var hud: MobileGameHud = context["hud"]
    await process_frame
    await process_frame

    hud._sheet.visible = true
    hud._apply_v2_primary_hud()
    hud._apply_v2_management_scope()
    await process_frame

    var project := hud._v2_rank1_project_nav_buttons.get("rack_wing") as Button
    if project == null or not project.visible:
        _fail("Rank 1 Management must expose Rack Wing route for drag-scroll smoke")
        return false

    var start_scroll := hud._mobile_scroll.scroll_vertical
    var start := project.get_global_rect().get_center()

    _push_touch(start, true, 1)
    _push_drag(start + Vector2(0.0, -TAP_MOVE), Vector2(0.0, -TAP_MOVE), 1)
    _push_touch(start + Vector2(0.0, -TAP_MOVE), false, 1)
    await process_frame

    if hud._mobile_scroll.scroll_vertical <= start_scroll:
        _fail("dragging on top of a STOP Button must still scroll via global mobile drag handling")
        return false

    hud.queue_free()
    await process_frame
    return true


func _push_touch(position: Vector2, pressed: bool, index: int) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = pressed
    get_root().push_input(event, true)


func _push_drag(position: Vector2, relative: Vector2, index: int) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = position
    event.relative = relative
    get_root().push_input(event, true)
