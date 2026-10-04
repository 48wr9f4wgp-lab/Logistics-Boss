extends SceneTree
const Main = preload("res://prototype/release_main.gd")
var failures := 0
var checks := 0
var app
func _init() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(description)
func settle() -> void:
    for _i in 6: await process_frame
    app.world.refresh()
func verify_labels(expected: int) -> void:
    var world = app.world
    var screen := Rect2(Vector2.ZERO,Vector2(app.viewport.size))
    var occupied: Array[Rect2] = []
    for item in world._callouts.values():
        var label: Label = item.label
        if not label.visible: continue
        check(label.get_theme_font_size("font_size")>=14,"Fixed-pixel caption remains readable")
        check(screen.encloses(label.get_rect()),"Caption is inside warehouse viewport: "+label.text)
        check(label.size.x>=label.get_minimum_size().x,"Caption has its complete natural width: "+label.text)
        check(label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Captions never steal world touches")
        for rect in occupied: check(not rect.intersects(label.get_rect()),"World captions never overlap")
        occupied.append(label.get_rect())
    check(occupied.size()==expected,"Only key locations or selected equipment are labeled")
    for tag in world.find_children("*","Label3D",true,false):
        check(not tag.visible,"No illegibly scaled 3D text remains")
func verify_footprint() -> void:
    var world = app.world
    var screen := Rect2(Vector2.ZERO,Vector2(app.viewport.size))
    var bounds := Rect2()
    var first := true
    for title in ["MainFoundation","AnnexFoundation"]:
        var mesh := world.get_node(title) as MeshInstance3D
        for index in 8:
            var p: Vector2 = world.camera.unproject_position(mesh.global_transform*mesh.get_aabb().get_endpoint(index))
            check(screen.has_point(p),"Entire real warehouse footprint is visible")
            if first:
                bounds = Rect2(p,Vector2.ZERO)
                first = false
            else: bounds = bounds.expand(p)
    check(bounds.size.x>=screen.size.x*.70,"Overview fills the phone width with real geometry")
func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    for size in [Vector2i(375,667),Vector2i(390,844),Vector2i(430,932)]:
        root.size = size
        app = Main.new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        app.hud.show_play()
        app.sim.accept_contract("first_shift")
        app.sim.step(72)
        await settle()
        verify_labels(3)
        verify_footprint()
        var before := var_to_str(app.sim.snapshot())
        app.world.refresh()
        check(var_to_str(app.sim.snapshot())==before,"Rendering never mutates authoritative simulation")
        check(app.world._actors.size()==app.sim.workers.size(),"All actual workers remain rendered")
        check(app.world._callouts.Storage.label.text=="保管床 %d枠"%app.sim.bulk_capacity(),"Floor capacity comes from actual model")
        for id in ["shelf","packing"]:
            app.hud.select_slot(id)
            await settle()
            verify_labels(1)
            var overview_size: float = app.world.camera.size
            var position: Vector3 = app.world._slots[id].position
            check(Rect2(Vector2.ZERO,Vector2(app.viewport.size)).has_point(app.world.camera.unproject_position(position)),"Selected equipment remains visible")
            app._preview_slot(id,"annex")
            await settle()
            verify_labels(2)
            check(app.world.camera.size>=overview_size,"Preview fits both current and proposed locations")
            for point in [position,app.world._ghost.position]:
                check(Rect2(Vector2.ZERO,Vector2(app.viewport.size)).has_point(app.world.camera.unproject_position(point)),"Current and candidate positions stay in frame")
            app.hud.close_sheet()
            await settle()
            verify_labels(3)
            verify_footprint()
        app.sim.step(1200)
        for upgrade in ["worker_4","rack_24","packing_2","floor_2","worker_5"]: app.sim.buy_upgrade(upgrade)
        for id in ["small_orders","pallet_wave","packing_rush","storage_peak","final_dispatch"]:
            check(app.sim.accept_contract(id).ok,"Campaign contract accepted")
            for _i in 1800:
                app.sim.step(1)
                if app.sim.finished: break
            check(app.sim.finished,"Campaign contract completes")
            for upgrade in ["worker_4","rack_24","packing_2","floor_2","worker_5"]: app.sim.buy_upgrade(upgrade)
        app.sim.accept_contract("storage_peak")
        app.sim.step(60)
        await settle()
        verify_labels(3)
        verify_footprint()
        check(app.world._callouts.Storage.label.text=="保管床 8枠","Expanded floor has one readable capacity label")
        app.hud.select_slot("shelf")
        await settle()
        verify_labels(1)
        check(app.world._callouts.Selected.label.text=="棚の容量 24個","Selected shelf shows actual upgraded capacity")
        app.hud.select_slot("packing")
        await settle()
        check(app.world._callouts.Selected.label.text=="梱包 %.1f秒/個" % app.sim.pack_seconds,"Selected packing shows exact seconds per item")
        app.queue_free()
        await process_frame
    print("READABILITY_WORLD %d checks, %d failures"%[checks,failures])
    quit(0 if failures==0 else 1)
