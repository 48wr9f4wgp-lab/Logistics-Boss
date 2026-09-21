extends "res://tests/mobile_interaction_clarity_smoke.gd"

# Exercise Input's emulation stage, which Viewport.push_input() bypasses.
# Godot 4.7.2 dispatches the emulated MouseButton BEFORE its ScreenTouch.
# These are isolated UI fixtures, not human-device or fun evidence.

func _run() -> void:
    get_root().size = Vector2i(390, 844)
    var old_mouse := Input.emulate_mouse_from_touch
    var old_touch := Input.emulate_touch_from_mouse
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    await _verify_engine_input()
    Input.emulate_mouse_from_touch = old_mouse
    Input.emulate_touch_from_mouse = old_touch
    print("Engine touch emulation checks finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)


func _engine_touch(position: Vector2, pressed: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = position
    event.pressed = pressed
    event.canceled = canceled
    Input.parse_input_event(event)
    Input.flush_buffered_events()


func _engine_tap(button: Button) -> void:
    var position := button.get_global_rect().get_center()
    _engine_touch(position, true)
    _engine_touch(position, false)


func _verify_engine_input() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var zone: WarehouseZonePanel = context["zone"]
    var clarity: MobileInteractionClarity = context["clarity"]
    var goal := hud._v2_growth_goal
    var position := goal.get_global_rect().get_center()
    _engine_touch(position, true)
    await _settle()
    print("Engine touch down: pointer=%d blocked=%s" % [clarity.router._pointer, str(clarity.router._blocked_touches)])
    _expect(clarity.router._pointer == 0 and clarity.router.is_pressing(goal), "Engine-emulated mouse must not steal the finger or cancel its press")
    _engine_touch(position, false)
    await _settle()
    print("Engine touch up: pointer=%d sheet=%s" % [clarity.router._pointer, str(hud._sheet.visible)])
    _expect(clarity.router._pointer == -1 and clarity.router._blocked_touches.is_empty(), "Engine touch release must not leave a stuck mouse pointer")
    _expect(hud._sheet.visible, "Engine-parsed tap must actually open Management")
    if not hud._sheet.visible:
        hud.queue_free()
        await _settle()
        return

    for _index in 3:
        _engine_tap(hud._manage_button)
        await _settle()
        _expect(not hud._sheet.visible, "Repeated engine tap must close Management")
        _engine_tap(hud._manage_button)
        await _settle()
        _expect(hud._sheet.visible, "Repeated engine tap must reopen Management")

    # Contracts remain optional; navigate to their explicit tab.
    _engine_tap(clarity._tabs["contracts"] as Button)
    await _settle()
    var contract := hud._contract_buttons[0]
    var count := {"value": 0}
    contract.pressed.connect(func(): count["value"] = int(count["value"]) + 1)
    position = contract.get_global_rect().get_center()
    _engine_touch(position, true)
    _engine_touch(position, false, true)
    await _settle()
    _expect(sim.active_contract.is_empty() and int(count["value"]) == 0, "Engine touch cancellation must not accept a contract")
    _expect(clarity.router._pointer == -1, "Cancellation must leave the router reusable")
    _engine_tap(contract)
    await _settle()
    _expect(not sim.active_contract.is_empty() and int(count["value"]) == 1, "Engine touch plus emulation must accept exactly one contract")
    _expect(not hud._sheet.visible, "Accepted contract must return to the warehouse")

    zone.open_zone("storage")
    await _settle()
    var before := sim.money
    _engine_tap(zone._capital_action)
    await _settle()
    _expect(sim.money == before and zone.preview_kind() == &"rack_wing", "Engine touch must preview without spending")
    _engine_tap(zone._capital_action)
    await _settle()
    _expect(sim.money < before and sim.rank1_project_owned(&"rack_wing"), "Next engine gesture must build exactly once")
    _expect(not zone.is_open(), "Construction reveals the warehouse immediately")
    zone.open_zone("storage")
    await _settle()
    _engine_tap(zone._close_button)
    await _settle()
    _expect(not zone.is_open(), "Engine touch must close the reopened Zone Panel")

    # Ordinary desktop mouse input must still work after the touch cooldown.
    await create_timer(0.5).timeout
    position = hud._manage_button.get_global_rect().get_center()
    for pressed in [true, false]:
        var mouse := InputEventMouseButton.new()
        mouse.device = 0
        mouse.position = position
        mouse.global_position = position
        mouse.button_index = MOUSE_BUTTON_LEFT
        mouse.pressed = pressed
        Input.parse_input_event(mouse)
    Input.flush_buffered_events()
    await _settle()
    _expect(hud._sheet.visible, "Genuine mouse input must remain usable")
    hud.queue_free()
    await _settle()
