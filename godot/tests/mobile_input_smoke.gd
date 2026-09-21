extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const ViewScript = preload("res://view/warehouse_view_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim = SimScript.new()
    var view: MobileWarehouseView = ViewScript.new()
    get_root().add_child(view)
    view.bind_sim(sim)
    await process_frame

    if view._camera.keep_aspect != Camera3D.KEEP_WIDTH:
        _fail("portrait mobile camera must preserve horizontal FOV")
        return
    if MobileWarehouseView.MOBILE_MAX_DISTANCE < 30.0:
        _fail("mobile overview must allow a materially wider warehouse view")
        return

    var start_yaw := view._orbit_yaw
    var touch := InputEventScreenTouch.new()
    touch.index = 0
    touch.position = Vector2(100.0, 180.0)
    touch.pressed = true
    view._unhandled_input(touch)

    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = Vector2(260.0, 260.0)
    drag.relative = Vector2(160.0, 80.0)
    view._unhandled_input(drag)
    if is_equal_approx(start_yaw, view._orbit_yaw):
        _fail("single-finger drag must orbit camera")
        return
    if view._orbit_pitch < -0.98 or view._orbit_pitch > -0.48:
        _fail("orbit pitch must stay within mobile readability bounds")
        return

    var before_huge_drag := view._orbit_yaw
    var huge_drag := InputEventScreenDrag.new()
    huge_drag.index = 0
    huge_drag.position = Vector2(900.0, 260.0)
    huge_drag.relative = Vector2(640.0, 0.0)
    view._unhandled_input(huge_drag)
    if absf(view._orbit_yaw - before_huge_drag) > 0.13:
        _fail("large swipe must be rate-limited to avoid jumpy mobile camera motion")
        return

    var second_touch := InputEventScreenTouch.new()
    second_touch.index = 1
    second_touch.position = Vector2(300.0, 180.0)
    second_touch.pressed = true
    view._unhandled_input(second_touch)

    var pinch_prime := InputEventScreenDrag.new()
    pinch_prime.index = 1
    pinch_prime.position = Vector2(310.0, 180.0)
    pinch_prime.relative = Vector2(10.0, 0.0)
    view._unhandled_input(pinch_prime)

    var before_distance := view._camera_distance
    var pinch_move := InputEventScreenDrag.new()
    pinch_move.index = 1
    pinch_move.position = Vector2(370.0, 180.0)
    pinch_move.relative = Vector2(60.0, 0.0)
    view._unhandled_input(pinch_move)
    if is_equal_approx(before_distance, view._camera_distance):
        _fail("two-finger gesture must change camera distance")
        return
    if view._camera_distance < MobileWarehouseView.MOBILE_MIN_DISTANCE or view._camera_distance > MobileWarehouseView.MOBILE_MAX_DISTANCE:
        _fail("pinch zoom must remain inside mobile camera distance bounds")
        return

    view._camera_distance = MobileWarehouseView.MOBILE_MIN_DISTANCE
    view._update_camera(1.0)
    # Capacity framing deliberately uses a tighter near view; keep calibrated bounds
    # without weakening orbit, pinch, aspect or far-overview protection.
    if view._camera.fov < 42.0 or view._camera.fov > 46.0:
        _fail("near work view must stay in the calibrated readable FOV range")
        return

    view._camera_distance = MobileWarehouseView.MOBILE_MAX_DISTANCE
    view._update_camera(1.0)
    if view._camera.fov < 44.0:
        _fail("far mobile overview must remain wide enough to read the whole warehouse")
        return

    for index in [0, 1]:
        var release := InputEventScreenTouch.new()
        release.index = index
        release.position = Vector2.ZERO
        release.pressed = false
        view._unhandled_input(release)

    view.queue_free()
    await process_frame
    print("Godot mobile input smoke passed")
    quit(0)
