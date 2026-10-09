extends Node
## Diagnostic microbenchmark: real saved cargo + deterministic domain steps.
## Export this same scene in isolated public-control and candidate project copies.
## The live game clock/save path is NOT replaced in the production project.
const Main = preload("res://prototype/growth_main.gd")
const Save = preload("res://prototype/release_save.gd")
var app
func _ready() -> void: run.call_deferred()
func run() -> void:
    app = Main.new()
    app.persistence_enabled = false
    add_child(app)
    app.set_process(false)
    app.world.set_process(false)
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://benchmark-fixture.json"))
    var decoded: Dictionary = Save.new().decode(fixture.encoded)
    if not decoded.ok:
        push_error("Benchmark fixture decode failed")
        return
    var imported: Dictionary = app.sim.import_release_state(decoded.data)
    if not imported.ok or app.sim.sim_time <= 0 or app.sim.campaign_status != "running":
        push_error("Benchmark requires an actual in-flight fixture")
        return
    app.hud.show_play()
    app._update_world_visibility()
    if OS.has_feature("web"): app._sync_web_viewport()
    app.world.refresh()
    app.hud.refresh()
    for i in 16: await get_tree().process_frame
    var rows: Array = []
    var unchanged: Array = []
    # Includes real processing and rendering. Every measured row has the same
    # complete ledger hash across variants; no wall-clock-dependent progression.
    for index in 120:
        var start := Time.get_ticks_usec()
        app.sim.step(.125)
        var sim_usec := Time.get_ticks_usec() - start
        app.world._pulse = app.sim.sim_time
        var before: PackedByteArray = var_to_bytes(app.sim.export_release_state())
        start = Time.get_ticks_usec()
        app.world.refresh()
        var view_usec := Time.get_ticks_usec() - start
        if before != var_to_bytes(app.sim.export_release_state()):
            push_error("View mutated the actual cargo ledger")
            return
        start = Time.get_ticks_usec()
        app.hud.refresh()
        var hud_usec := Time.get_ticks_usec() - start
        await RenderingServer.frame_post_draw
        if index >= 24:
            rows.append({"index": index, "time": app.sim.sim_time, "ledger": before.hex_encode().sha256_text(), "shipped": app.sim.shipped, "packing": app.sim.pack_jobs.duplicate(true), "sim_usec": sim_usec, "view_usec": view_usec, "hud_usec": hud_usec, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
        await get_tree().process_frame
    var frozen: PackedByteArray = var_to_bytes(app.sim.export_release_state())
    for i in 96:
        var start := Time.get_ticks_usec()
        app.world.refresh()
        unchanged.append(Time.get_ticks_usec() - start)
        await get_tree().process_frame
    if frozen != var_to_bytes(app.sim.export_release_state()):
        push_error("Paused view mutated the cargo ledger")
        return
    var result := {"scope": "Same actual cargo ledger per row; renderer microbenchmark, excludes live autosave scheduling", "rows": rows, "unchanged_view_usec": unchanged, "ledger_unchanged_by_view": true}
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.flotraStateBenchmark = " + JSON.stringify(result), true)
    else:
        print(JSON.stringify(result))
        get_tree().quit()
