extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
var app
var output: String
var results: Array=[]
func _init():run.call_deferred()
func settle():
    app._update_world_visibility()
    app.hud.refresh()
    app.world.refresh()
    for i in 8:await process_frame
    await RenderingServer.frame_post_draw
func capture(name: String):
    await settle()
    assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
func tap(button: Button):
    var down:=InputEventScreenTouch.new()
    down.index=0
    down.position=button.get_global_rect().get_center()
    down.pressed=true
    root.push_input(down,true)
    for i in 2:await process_frame
    var up:=InputEventScreenTouch.new()
    up.index=0
    up.position=down.position
    up.pressed=false
    root.push_input(up,true)
    for i in 4:await process_frame
func camera_state() -> Dictionary:
    return {"zoom":app.world._camera_zoom,"turn":app.world._camera_turn,"pan":app.world._camera_pan,"transform":app.world.camera.transform,"size":app.world.camera.size}
func run():
    output=OS.get_environment("FLOTRA_VISUAL_OUTPUT")
    DirAccess.make_dir_recursive_absolute(output)
    var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/workspace/scratch/401574fe42e3/flotra-recovered-web-evidence-20261007/fixtures/late.json"))
    var decoded=preload("res://prototype/release_save.gd").new().decode(fixture.encoded)
    assert(decoded.ok)
    for size in [Vector2i(390,844),Vector2i(375,667)]:
        root.size=size
        app=Main.new()
        app.persistence_enabled=false
        root.add_child(app)
        app.set_process(false)
        assert(app.sim.import_release_state(decoded.data).ok)
        app.hud.show_play()
        await settle()
        app._camera_action("right")
        app._camera_action("in")
        app.world._camera_pan=Vector2(.4,.6)
        app.world._apply_camera_view()
        await capture("%d-original-camera"%size.x)
        var prior:=camera_state()
        var domain:=var_to_bytes(app.sim.export_release_state())
        app.hud._open_upgrades()
        await capture("%d-inspection-entry"%size.x)
        var entry:Button=app.hud._content.find_child("InspectOwnedAutoPack",true,false)
        assert(entry!=null and not entry.disabled)
        await tap(entry)
        await capture("%d-inspection-close"%size.x)
        assert(app.world._inspection_slot=="packing")
        assert(app.hud._camera_buttons[4].text=="戻る")
        assert(app.world._selected.is_empty())
        var slot:Node3D=app.world._slots.packing
        assert(app.world._slot_at(app.world.camera.unproject_position(slot.position))=="")
        app._camera_action("left")
        app._camera_action("in")
        await capture("%d-inspection-turned"%size.x)
        await tap(app.hud._camera_buttons[4])
        await capture("%d-returned-camera"%size.x)
        assert(camera_state()==prior)
        assert(app.world._inspection_slot.is_empty())
        assert(app.hud._camera_buttons[4].text=="全体")
        assert(domain==var_to_bytes(app.sim.export_release_state()))
        # Repeat entry, then interrupt with the existing controls menu.
        app.hud._open_upgrades()
        await settle()
        await tap(app.hud._content.find_child("InspectOwnedAutoPack",true,false))
        await settle()
        app.hud.show_controls()
        await settle()
        app.hud.close_sheet()
        await settle()
        assert(camera_state()==prior)
        assert(not app.hud._equipment_inspection_active)
        assert(domain==var_to_bytes(app.sim.export_release_state()))
        results.append({"width":size.x,"height":size.y,"restoredExactCamera":true,"domainUnchanged":true,"repeatMenuInterruption":true,"savingDisabled":not app.persistence_enabled})
        app.queue_free()
        await process_frame
    var f:=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify({"scope":"Native rendered isolated optional inspection, native synthetic-touch entry/return; not real device touch or WebGL performance","results":results},"  "))
    print("OPTIONAL_INSPECTION_CAPTURE_PASS")
    quit()
