extends SceneTree
const Sim = preload("res://prototype/growth_sim.gd")
const View = preload("res://prototype/growth_view.gd")
const Store = preload("res://prototype/release_save.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool,text: String):
    checks += 1
    if not ok:failures.append(text);push_error(text)
func _init(): run.call_deferred()
func run():
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FLOTRA_GROWTH_FIXTURES")+"/complete.json"))
    var decoded: Dictionary = Store.new().decode(data.encoded)
    for size in [Vector2i(375,207),Vector2i(390,484),Vector2i(430,572),Vector2i(568,96)]:
        root.size=size
        for shelf in ["core","annex"]:
            for packing in ["front","annex"]:
                var sim=Sim.new()
                check(sim.import_release_state(decoded.data).ok,"Completed earned mature state imports")
                var shelf_result: Dictionary = sim.apply_slot("shelf",shelf)
                check(shelf_result.ok or shelf_result.get("reason","")=="same","Actual shelf location applies")
                var pack_result: Dictionary = sim.apply_slot("packing",packing)
                check(pack_result.ok or pack_result.get("reason","")=="same","Actual packing location applies")
                var view=View.new()
                root.add_child(view)
                view.bind_sim(sim)
                for i in 3:await process_frame
                view.fit_camera(Vector2(size))
                var before=sim.export_release_state()
                for turn in 4:
                    var screen:=Rect2(Vector2.ZERO,Vector2(size))
                    for equipment in sim.snapshot().equipment:
                        var dims: Vector3=equipment.size
                        var bounds:=AABB(equipment.position-Vector3(dims.x*.5,0,dims.z*.5),dims)
                        for i in 8:check(screen.grow(-1).has_point(view.camera.unproject_position(bounds.get_endpoint(i))),"Work preset fits actual equipment "+shelf+"/"+packing+" "+str(size)+" turn"+str(turn))
                    view.camera_action("right")
                check(sim.export_release_state()==before,"Framing alternate layouts does not change save")
                view.queue_free()
                for i in 3:await process_frame
    print(JSON.stringify({"suite":"work_camera_layouts","checks":checks,"failures":failures,"scope":"All four real equipment layout combinations, four rotations, four viewport geometries"}))
    quit(0 if failures.is_empty() else 1)
