extends SceneTree
## Independent camera regression through real root input dispatch. Uses only an
## isolated in-memory campaign; headless geometry is not physical-device proof.
const Main = preload("res://prototype/growth_main.gd")
const Sim = preload("res://prototype/growth_sim.gd")
var app
var checks := 0
var failures: Array[String] = []
var minimum_visible_floor_fraction := 1.0

func _initialize() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func settle(frames: int = 4) -> void:
    if is_instance_valid(app): app._update_world_visibility()
    for frame in frames: await process_frame
    await physics_frame

func guard() -> void:
    var until := Time.get_ticks_msec() + 200
    while Time.get_ticks_msec() < until or app.hud._background_input_blocked():
        await process_frame
    await settle()

func touch(point: Vector2, down: bool, index: int = 0, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.position = point
    event.index = index
    event.pressed = down
    event.canceled = canceled
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func drag(point: Vector2, previous: Vector2, index: int = 0) -> void:
    var event := InputEventScreenDrag.new()
    event.position = point
    event.relative = point - previous
    event.screen_relative = event.relative
    event.index = index
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func mouse(point: Vector2, down: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = down
    event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func motion(point: Vector2, previous: Vector2, held: bool = true) -> void:
    var event := InputEventMouseMotion.new()
    event.position = point
    event.global_position = point
    event.relative = point - previous
    event.screen_relative = event.relative
    event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func wheel(point: Vector2, zoom_in: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = MOUSE_BUTTON_WHEEL_UP if zoom_in else MOUSE_BUTTON_WHEEL_DOWN
    event.pressed = true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func camera_button(title: String) -> Button:
    return app.hud._root.find_child(title, true, false) as Button

func tap_button(title: String) -> void:
    var button := camera_button(title)
    check(button != null and button.is_visible_in_tree(), "Camera action is visible: " + title)
    if button == null: return
    var point := button.get_global_rect().get_center()
    touch(point, true)
    await settle()
    touch(point, false)
    await settle()

func world_rect() -> Rect2:
    return app.viewport_container.get_global_rect()

func slot_point(id: String) -> Vector2:
    return app.viewport_container.position + app.world.camera.unproject_position(app.world._slots[id].position + Vector3(0, 1, 0))

func geometry(dimensions: Vector2i) -> void:
    var display := Rect2(Vector2.ZERO, Vector2(dimensions))
    for title in ["CameraLeft", "CameraRight", "CameraOut", "CameraIn", "CameraWork", "CameraReset"]:
        var button := camera_button(title)
        check(button != null and button.is_visible_in_tree(), "Overview camera controls remain visible " + title + str(dimensions))
        if button == null: continue
        check(button.size.x >= 56 and button.size.y >= 56, "Camera touch target is at least56px " + title)
        check(button.get_theme_font_size("font_size") >= 18, "Camera text is at least18px " + title)
        check(display.encloses(button.get_global_rect()), "Camera control stays onscreen " + title + str(dimensions))
        check(not world_rect().intersects(button.get_global_rect()), "Camera control does not cover warehouse " + title)
        check(not app.hud._bottom.get_global_rect().intersects(button.get_global_rect()), "Camera control does not overlap bottom HUD " + title)
    var floors: Array = [app.world.get_node("MainFoundation"), app.world.get_node("AnnexFoundation")]
    floors.append_array(app.world._growth_floors)
    floors.append_array(app.world._connector_floors)
    for floor_mesh in floors:
        for index in 8:
            var point: Vector3 = floor_mesh.global_transform * floor_mesh.get_aabb().get_endpoint(index)
            var projected: Vector2 = app.world.camera.unproject_position(point)
            check(Rect2(Vector2.ZERO, app.viewport_container.size).has_point(projected), "Every purchased floor corner fits overview " + str(dimensions))

func visible_floor_fraction() -> float:
    var floors: Array = [app.world.get_node("MainFoundation"), app.world.get_node("AnnexFoundation")]
    floors.append_array(app.world._growth_floors)
    floors.append_array(app.world._connector_floors)
    var dimensions: Vector2 = app.viewport_container.size
    var viewport_polygon := PackedVector2Array([Vector2.ZERO, Vector2(dimensions.x, 0), dimensions, Vector2(0, dimensions.y)])
    var visible_area := 0.0
    for floor_mesh in floors:
        var corners := PackedVector2Array()
        for index in 8:
            var point: Vector3 = floor_mesh.global_transform * floor_mesh.get_aabb().get_endpoint(index)
            corners.append(app.world.camera.unproject_position(point))
        var projected := Geometry2D.convex_hull(corners)
        for polygon in Geometry2D.intersect_polygons(projected, viewport_polygon):
            var area := 0.0
            for index in polygon.size():
                area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
            visible_area += absf(area) * .5
    return visible_area / maxf(1, dimensions.x * dimensions.y)

func complete(sim) -> void:
    for second in 3000:
        sim.step(1.0)
        if sim.finished: return
    check(false, "Earned mature fixture finishes bounded job")

func mature_fixture():
    var sim = Sim.new()
    for number in range(1, 7):
        check(sim.accept_contract("growth_%d" % number).ok, "Mature fixture accepts real milestone")
        complete(sim)
    for definition in Sim.GROWTH_UPGRADES:
        for attempt in 30:
            if sim.campaign_wallet >= definition.cost: break
            check(sim.accept_contract("growth_1").ok, "Mature fixture earns purchase funds")
            complete(sim)
        check(sim.buy_upgrade(definition.id).ok, "Mature fixture buys real upgrade " + definition.id)
    check(sim._wing_count() == 4 and sim.check_invariants().ok, "All four mature wings are earned and conserved")
    return sim

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    root.size = Vector2i(390, 844)
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    app.hud.show_play()
    await guard()
    var saved: Dictionary = app.sim.export_release_state()
    # This retained suite exercises the explicit whole-warehouse preset.
    # The new default work preset has its own work_camera_smoke suite.
    app.world.camera_action("reset")
    geometry(root.size)
    await tap_button("CameraRight")
    check(app.world._camera_turn == 1, "Real GUI right button rotates once, despite emulation")
    await tap_button("CameraLeft")
    check(app.world._camera_turn == 0, "Real GUI left button rotates opposite direction")
    await tap_button("CameraIn")
    check(is_equal_approx(app.world._camera_zoom, 1.25), "Real GUI zoom button applies once")
    await tap_button("CameraReset")
    check(app.world._camera_zoom == 1.0 and app.world._camera_pan == Vector2.ZERO and app.world._camera_turn == 0, "Whole warehouse action restores default overview")

    # Wheel zoom preserves the point beneath the mouse within the pan limits.
    var anchor := world_rect().get_center() + Vector2(30, -20)
    var local_anchor: Vector2 = anchor - app.viewport_container.position
    var anchored_point: Vector3 = app.world.camera.project_position(local_anchor, 50)
    wheel(anchor, true)
    await settle()
    check(app.world._camera_zoom > 1, "Native mouse wheel zooms warehouse")
    check(app.world.camera.unproject_position(anchored_point).distance_to(local_anchor) < .01, "Mouse wheel keeps its world anchor under the cursor")
    app.world.camera_action("reset")
    camera_button("CameraRight").grab_focus()
    var key := InputEventKey.new()
    key.keycode = KEY_ENTER
    key.physical_keycode = KEY_ENTER
    key.pressed = true
    Input.parse_input_event(key)
    key = key.duplicate()
    key.pressed = false
    Input.parse_input_event(key)
    await settle()
    check(app.world._camera_turn == 1, "Keyboard activation operates a focused camera control once")
    app.world.camera_action("reset")

    # Native mouse plus emulated touch must have exactly the same result as one
    # physical touch path. Test away from pan limits.
    for action in ["in", "in", "in"]: app.world.camera_action(action)
    var center := world_rect().get_center()
    var move := Vector2(24, 0)
    touch(center, true)
    drag(center + move, center)
    touch(center + move, false)
    await settle()
    var touch_pan: Vector2 = app.world._camera_pan
    app.world.camera_action("reset")
    for action in ["in", "in", "in"]: app.world.camera_action(action)
    motion(center, center, false)
    mouse(center, true)
    motion(center + move, center)
    mouse(center + move, false)
    await settle()
    check(app.world._camera_pan.is_equal_approx(touch_pan), "Mouse drag is not doubled by synthesized touch")
    check(app.world._camera_touches.is_empty() and not app.world._camera_mouse_down, "Mouse release clears all gesture ownership")

    app.world.camera_action("reset")
    var point := slot_point("shelf")
    touch(point, true)
    drag(point + Vector2(30, 0), point)
    drag(point, point + Vector2(30, 0))
    touch(point, false)
    await settle()
    check(app.hud._sheet_kind.is_empty(), "Drag out and back never becomes an equipment tap")
    app.world.camera_action("reset")
    point = slot_point("shelf")
    touch(point, true)
    touch(point, false, 0, true)
    await settle()
    check(app.hud._sheet_kind.is_empty() and app.world._camera_touches.is_empty(), "Canceled touch cannot select equipment")

    # Two/three-finger changes retain identity and never select equipment when
    # a pinching finger lifts, then another finger continues the gesture.
    center = world_rect().get_center()
    var first := center - Vector2(42, 0)
    var second := center + Vector2(42, 0)
    touch(first, true, 3)
    touch(second, true, 7)
    drag(first - Vector2(30, 0), first, 3)
    first -= Vector2(30, 0)
    drag(second + Vector2(30, 0), second, 7)
    second += Vector2(30, 0)
    check(app.world._camera_zoom > 1, "Two distinct touch IDs perform pinch zoom")
    touch(center, true, 9)
    drag(center + Vector2(0, 12), center, 9)
    touch(first, false, 3)
    drag(second + Vector2(0, 10), second, 7)
    second += Vector2(0, 10)
    touch(center + Vector2(0, 12), false, 9)
    drag(second + Vector2(10, 0), second, 7)
    touch(second + Vector2(10, 0), false, 7)
    await settle()
    check(app.hud._sheet_kind.is_empty() and app.world._camera_touches.is_empty(), "Three-to-two-to-one finger transitions never select or stick")
    check(app.world._camera_zoom >= 1 and app.world._camera_zoom <= 3, "Multi-touch transition stays in zoom bounds")

    app.world.camera_action("reset")
    point = slot_point("shelf")
    touch(point, true)
    var outside := camera_button("CameraIn").get_global_rect().get_center()
    drag(outside, point)
    touch(outside, false)
    await settle()
    check(app.world._camera_touches.is_empty() and app.hud._sheet_kind.is_empty() and app.world._camera_zoom == 1, "World gesture crossing UI neither sticks nor activates camera button")
    # A touch that begins in UI must not gain world ownership mid-drag.
    touch(outside, true)
    drag(point, outside)
    touch(point, false)
    await settle()
    check(app.hud._sheet_kind.is_empty() and app.world._camera_touches.is_empty(), "UI-started gesture cannot select underlying equipment")

    for interruption in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
        app.world.camera_action("reset")
        point = slot_point("shelf")
        touch(point, true)
        root.propagate_notification(interruption)
        touch(point, false)
        await settle()
        check(app.hud._sheet_kind.is_empty() and app.world._camera_touches.is_empty(), "Focus/app interruption cancels camera touch " + str(interruption))
    point = slot_point("shelf")
    touch(point, true)
    root.size = Vector2i(375, 567)
    await settle()
    touch(point, false)
    await settle()
    check(app.hud._sheet_kind.is_empty() and app.world._camera_touches.is_empty(), "Resize rejects old world gesture")

    # An interrupted camera button also uses the inherited dismissal epoch.
    var camera_in := camera_button("CameraIn")
    var held_point := camera_in.get_global_rect().get_center()
    touch(held_point, true)
    root.size = Vector2i(390, 844)
    await settle()
    touch(held_point, false)
    await settle()
    check(app.world._camera_zoom == 1, "Resize cancels a held camera button")
    held_point = camera_in.get_global_rect().get_center()
    touch(held_point, true)
    root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    touch(held_point, false)
    await settle()
    check(app.world._camera_zoom == 1, "Focus loss cancels a held camera button")
    point = slot_point("shelf")
    touch(point, true)
    app.hud.show_controls()
    check(app.world._camera_touches.is_empty(), "Opening a sheet immediately cancels world ownership")
    touch(point, false)
    app.hud.close_sheet()
    await guard()
    check(app.world._selected.is_empty() and app.hud._sheet_kind.is_empty(), "Sheet dismissal cannot replay an interrupted world touch")
    app.world.camera_action("reset")
    for action in ["right", "in", "in"]: app.world.camera_action(action)
    center = world_rect().get_center()
    touch(center, true)
    drag(center + Vector2(18, 12), center)
    touch(center + Vector2(18, 12), false)
    await settle()
    var overview := [app.world._camera_turn, app.world._camera_zoom, app.world._camera_pan]
    point = slot_point("packing")
    touch(point, true)
    touch(point, false)
    await settle()
    check(app.hud._sheet_kind == "editor" and app.world._selected == "packing", "Equipment tap still opens exact layout editor after camera movement")
    check(not camera_button("CameraReset").is_visible_in_tree(), "Camera controls hide during editor")
    var editor_transform: Transform3D = app.world.camera.transform
    app.world.camera_action("right")
    check(app.world.camera.transform.is_equal_approx(editor_transform), "Camera actions do not interfere with editor focus")
    app.hud.close_sheet()
    await guard()
    check(overview == [app.world._camera_turn, app.world._camera_zoom, app.world._camera_pan], "Closing editor restores session-only overview preferences")
    app.hud.show_controls()
    await settle()
    check(not camera_button("CameraReset").is_visible_in_tree(), "Camera controls hide behind settings sheet")
    app.hud.close_sheet()
    await guard()
    check(app.sim.export_release_state() == saved, "Camera actions, UI crossing and editor previews do not mutate saved campaign")

    var mature = mature_fixture()
    for fixture in [app.sim, mature]:
        app.world.bind_sim(fixture)
        app.hud.bind_sim(fixture)
        app.hud.show_play()
        await guard()
        var fixture_saved: Dictionary = fixture.export_release_state()
        for dimensions in [Vector2i(320, 568), Vector2i(347, 567), Vector2i(348, 567), Vector2i(351, 567), Vector2i(375, 567), Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932), Vector2i(568, 320)]:
            root.size = dimensions
            await settle()
            app.world.camera_action("reset")
            for rotation in 4:
                geometry(dimensions)
                for index in 20: app.world.camera_action("in")
                check(app.world._camera_zoom == 3, "Zoom never exceeds3x " + str(dimensions))
                for direction in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
                    app.world._pan_camera(direction * 100000)
                    var fraction := visible_floor_fraction()
                    minimum_visible_floor_fraction = minf(minimum_visible_floor_fraction, fraction)
                    check(fraction > .01, "Even diagonal extreme pan retains actual purchased floor " + str(dimensions) + " " + str(direction))
                    var extent: Vector2 = app.world._camera_projected_size
                    check(absf(app.world._camera_pan.x) < extent.x * .5 and absf(app.world._camera_pan.y) < extent.y * .5, "Large pan remains inside purchased building bounds")
                for index in 20: app.world.camera_action("out")
                check(app.world._camera_zoom == 1, "Zoom never goes below overview1x " + str(dimensions))
                app.world.camera_action("right")
            app.world.camera_action("reset")
            geometry(dimensions)
        check(fixture.export_release_state() == fixture_saved, "Camera sweep never mutates authoritative fixture state")
    app.free()
    print(JSON.stringify({"suite":"camera_interaction_review", "checks":checks, "failures":failures, "minimumVisibleFloorFraction":minimum_visible_floor_fraction, "scope":"Native root input dispatch and geometry; no physical-device or browser screenshot claim"}))
    quit(0 if failures.is_empty() else 1)
