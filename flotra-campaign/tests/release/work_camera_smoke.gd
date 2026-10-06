extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
const Store = preload("res://prototype/release_save.gd")
var app
var checks := 0
var failures: Array[String] = []
var samples: Array = []
func _init(): run.call_deferred()
func check(ok: bool, message: String):
    checks += 1
    if not ok: failures.append(message); push_error(message)
func settle(frames := 4):
    for i in frames: await process_frame
func guard():
    var until := Time.get_ticks_msec() + 220
    while Time.get_ticks_msec() < until or app.hud._background_input_blocked(): await process_frame
    await settle()
func button(title: String) -> Button:
    return app.hud._root.find_child(title, true, false) as Button
func touch(pos: Vector2, pressed: bool, canceled := false):
    var event := InputEventScreenTouch.new()
    event.position = pos
    event.index = 0
    event.pressed = pressed
    event.canceled = canceled
    Input.parse_input_event(event)
    Input.flush_buffered_events()
func dimensions_fit(label: String):
    var viewport: Rect2 = Rect2(Vector2.ZERO,app.viewport_container.size)
    for equipment in app.sim.snapshot().equipment:
        var size: Vector3 = equipment.size
        var origin: Vector3 = app.world._slots[str(equipment.id)].position
        var bounds := AABB(origin-Vector3(size.x*.5,0,size.z*.5),size)
        for i in 8:
            var pixel: Vector2 = app.world.camera.unproject_position(bounds.get_endpoint(i))
            check(viewport.grow(-2).has_point(pixel),label+" whole actual "+str(equipment.id)+" fits")
func run():
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FLOTRA_GROWTH_FIXTURES")+"/late.json"))
    var decoded: Dictionary = Store.new().decode(fixture.encoded)
    for dimensions in [Vector2i(320,568),Vector2i(347,567),Vector2i(348,567),Vector2i(351,567),Vector2i(375,567),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320)]:
        root.size = dimensions
        app = Main.new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        check(app.sim.import_release_state(decoded.data).ok,"Actual earned mature fixture imports")
        app.world.bind_sim(app.sim)
        app.hud.bind_sim(app.sim)
        app.hud.show_play()
        await guard()
        check(app.world._camera_work_mode,"New session starts with work framing")
        if dimensions.x < 348:
            check(app.hud._safe_note.is_visible_in_tree(),"Narrow camera controls preserve visible save status")
        var saved: Dictionary = app.sim.export_release_state()
        var work_size: float = app.world.camera.size
        dimensions_fit(str(dimensions)+" default")
        var display := Rect2(Vector2.ZERO,Vector2(dimensions))
        var controls: Array[Rect2] = []
        for title in ["CameraLeft","CameraRight","CameraOut","CameraIn","CameraWork","CameraReset"]:
            var item := button(title)
            check(item != null and item.is_visible_in_tree(),"Visible control "+title)
            check(item.size.x >= 55.99 and item.size.y >= 56,"Full 56px control "+title+str(dimensions))
            check(display.encloses(item.get_global_rect()),"Control remains on screen")
            check(not app.viewport_container.get_global_rect().intersects(item.get_global_rect()),"Camera control does not cover 3D scene")
            for existing in controls: check(not existing.intersects(item.get_global_rect()),"Camera controls never overlap")
            controls.append(item.get_global_rect())
        # Whole view retains its exact fit and gives a measurable scale contrast.
        app.world.camera_action("reset")
        var whole_size: float = app.world.camera.size
        check(app.world._camera_zoom == 1 and app.world._camera_pan == Vector2.ZERO,"Whole preset restores overview")
        check(whole_size/work_size >= 1.4,"Work equipment renders at least1.4x larger than full mature warehouse")
        samples.append({"viewport":str(dimensions),"world":str(app.viewport_container.size),"whole_size":whole_size,"work_size":work_size,"linear_enlargement":whole_size/work_size})
        app.world.camera_action("work")
        for rotation in 4:
            dimensions_fit(str(dimensions)+" rotation"+str(rotation))
            app.world.camera_action("right")
            check(app.world._camera_work_mode,"Explicit rotation keeps work area framed")
        var prior: Transform3D = app.world.camera.transform
        var prior_size: float = app.world.camera.size
        for tick in 5:
            app.sim.step(.25)
            app.world.refresh()
        check(app.world.camera.transform.is_equal_approx(prior) and is_equal_approx(app.world.camera.size,prior_size),"Running simulation never pans or follows actors")
        # Restore fixture so all later interaction-only changes can be compared.
        check(app.sim.import_release_state(decoded.data).ok,"In-flight state restores")
        app.world.refresh()
        app.world.camera_action("in")
        app.world._pan_camera(Vector2(12,8))
        check(not app.world._camera_work_mode,"Manual input releases work preset")
        var manual: Array = [app.world._camera_turn,app.world._camera_zoom,app.world._camera_pan]
        app.hud.select_slot("packing")
        await settle()
        var editor: Transform3D = app.world.camera.transform
        app.world.camera_action("work")
        check(app.world.camera.transform.is_equal_approx(editor),"Work action cannot override equipment editor")
        app.hud.close_sheet()
        await guard()
        check(manual==[app.world._camera_turn,app.world._camera_zoom,app.world._camera_pan],"Editor returns to the exact manual session view")
        app.world.camera_action("work")
        var work_state: Array = [app.world._camera_turn,app.world._camera_zoom,app.world._camera_pan]
        app.hud.select_slot("shelf")
        await settle()
        app.hud.close_sheet()
        await guard()
        check(work_state==[app.world._camera_turn,app.world._camera_zoom,app.world._camera_pan],"Editor returns to the exact work preset")
        # Canceled new Work button uses the same guarded button infrastructure.
        app.world.camera_action("reset")
        var pos := button("CameraWork").get_global_rect().get_center()
        touch(pos,true)
        await settle()
        touch(pos,false,true)
        await settle()
        check(not app.world._camera_work_mode and app.world._camera_zoom==1,"Canceled Work touch cannot reframe")
        touch(pos,true)
        await settle()
        touch(pos,false)
        await settle()
        check(app.world._camera_work_mode,"Fresh real Work touch reframes once")
        if dimensions.x == 320:
            app.world.camera_action("reset")
            var held_pos := button("CameraWork").get_global_rect().get_center()
            touch(held_pos,true)
            await settle()
            root.size = Vector2i(348,568)
            await settle()
            touch(held_pos,false)
            await settle()
            check(not app.world._camera_work_mode,"Held Work is invalidated when resizing across the two-row breakpoint")
            var fresh_pos := button("CameraWork").get_global_rect().get_center()
            touch(fresh_pos,true)
            await settle()
            touch(fresh_pos,false)
            await settle()
            check(app.world._camera_work_mode,"Fresh Work touch recovers on the one-row side of breakpoint")
            root.size = dimensions
            await settle()
            dimensions_fit("Restored narrow portrait after held-input resize")
        check(app.sim.export_release_state()==saved,"Camera mode and all editing/cancellation actions leave save unchanged")
        app.queue_free()
        await settle()
    print(JSON.stringify({"suite":"work_camera_smoke","checks":checks,"failures":failures,"samples":samples,"scope":"Exact equipment bounds, input, stable camera, session-only state; no physical-device claim"}))
    quit(0 if failures.is_empty() else 1)
