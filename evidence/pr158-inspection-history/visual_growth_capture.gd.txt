extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
var app
var output: String
var results: Array = []
func _init() -> void: call_deferred("run")
func settle() -> void:
    app._update_world_visibility()
    app.hud.refresh()
    app.world._rendered_snapshot = {}
    app.world.refresh()
    for i in 8: await process_frame
    await RenderingServer.frame_post_draw
func capture(name: String) -> void:
    var before := var_to_bytes(app.sim.export_release_state())
    await settle()
    assert(before == var_to_bytes(app.sim.export_release_state()))
    assert(not app.persistence_enabled)
    assert(root.get_texture().get_image().save_png(output.path_join(name+".png")) == OK)
    var machine=app.world._slots.packing.get_node_or_null("VisualAutoPack")
    results.append({"name":name,"domainUnchanged":true,"savingDisabled":true,"packSeconds":app.sim.pack_seconds,"upgrades":app.sim.purchased_upgrades.duplicate(),"machineVisible":machine!=null and machine.visible,"packCargo":machine.get_meta("actual_pack_cargo_id",-1) if machine!=null else -1,"fraction":machine.get_meta("actual_pack_fraction",0) if machine!=null else 0,"drawCalls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
func finish_job(id: String) -> void:
    assert(app.sim.accept_contract(id).ok)
    while not app.sim.finished and app.sim.sim_time<800: app.sim.step(.25)
    assert(app.sim.finished)
func run() -> void:
    output=OS.get_environment("FLOTRA_VISUAL_OUTPUT")
    assert(not output.is_empty())
    DirAccess.make_dir_recursive_absolute(output)
    var earned: Dictionary={}
    for size in [Vector2i(390,844),Vector2i(375,567)]:
        root.size=size
        app=Main.new()
        app.persistence_enabled=false
        root.add_child(app)
        app.set_process(false)
        app.hud.show_play()
        if earned.is_empty():
            finish_job("growth_1")
            finish_job("growth_2")
            earned=app.sim.export_release_state().duplicate(true)
        else: assert(app.sim.import_release_state(earned).ok)
        await capture("%d-before-purchase"%size.x)
        assert(app.sim.buy_upgrade("auto_pack").ok)
        await capture("%d-after-purchase"%size.x)
        assert(app.sim.accept_contract("growth_2").ok)
        for tick in 8000:
            if not app.sim.pack_jobs.is_empty():break
            app.sim.step(.05)
        assert(not app.sim.pack_jobs.is_empty())
        await capture("%d-active-overview"%size.x)
        if size.x==390:
            # Existing reversible camera controls only, not a new close-camera policy.
            app.world.select_slot("packing")
            app.world.fit_camera(Vector2(app.viewport.size))
            await capture("390-active-detail")
            var frozen: Vector3 = app.world._slots.packing.get_node("VisualAutoPack/SealingHead").position
            await settle()
            assert(frozen == app.world._slots.packing.get_node("VisualAutoPack/SealingHead").position)
            for frame in 24:
                await capture("motion-%02d"%frame)
                app.sim.step(.05)
        app.queue_free()
        await process_frame
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
        app.world.visible_growth_enabled=false
        await capture("%d-mature-original"%size.x)
        app.world.visible_growth_enabled=true
        await capture("%d-mature-machine"%size.x)
        app.queue_free()
        await process_frame
    var f:=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify({"scope":"Native Linux rendered preview; no WebGL or physical phone verification","base":"a6f885e4f70ed3122fc1c776c3c6fa0661ca954a","results":results},"  "))
    print("VISIBLE_GROWTH_CAPTURE_PASS")
    quit()
