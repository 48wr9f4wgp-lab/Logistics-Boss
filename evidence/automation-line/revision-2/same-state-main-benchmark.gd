extends Node
## Diagnostic only: production Main path, real isolated storage, deterministic
## existing frame-clock seam. Never used as the production project's main scene.
const Main = preload("res://prototype/growth_main.gd")
const Save = preload("res://prototype/release_save.gd")
var app
var clock_usec := 0
func _ready() -> void: run.call_deferred()
func run() -> void:
    app = Main.new()
    add_child(app)
    app.set_process(false)
    app.world.set_process(false)
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://benchmark-fixture.json"))
    var decoded: Dictionary = Save.new().decode(fixture.encoded)
    if not decoded.ok:
        push_error("Fixture decode failed")
        return
    var imported: Dictionary = app.sim.import_release_state(decoded.data)
    if not imported.ok or app.sim.sim_time <= 0 or app.sim.campaign_status != "running":
        push_error("Expected actual in-flight fixture")
        return
    app.hud.show_play()
    app._update_world_visibility()
    if OS.has_feature("web"): app._sync_web_viewport()
    app.world.refresh()
    app.hud.refresh()
    for i in 16: await get_tree().process_frame
    app._start_trial()
    app.frame_clock = func(): return clock_usec
    app._clock_active = true
    app._last_frame_usec = 0
    var rows: Array = []
    for index in 120:
        if index == 24: JavaScriptBridge.eval("window.flotraBenchmarkSampling = true", true)
        clock_usec += 250000
        app.world._pulse = app.sim.sim_time
        var start := Time.get_ticks_usec()
        app._process(.25)
        var main_usec := Time.get_ticks_usec() - start
        var saved: Dictionary = app.save_store.autosave_status()
        if not app.running or app._save_protected():
            push_error("Main stopped or save protection blocked benchmark")
            return
        var state: PackedByteArray = var_to_bytes(app.sim.export_release_state())
        await RenderingServer.frame_post_draw
        if index >= 24:
            rows.append({"index":index, "time":app.sim.sim_time, "ledger":state.hex_encode().sha256_text(), "main_usec":main_usec, "packing":app.sim.pack_jobs.duplicate(true), "save_phase":saved.phase, "save_pending":saved.pending, "generation":saved.generation, "last_saved_generation":saved.last_saved_generation, "nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)})
        await get_tree().process_frame
    JavaScriptBridge.eval("window.flotraBenchmarkSampling = false", true)
    app._pause_trial(true)
    var frozen: PackedByteArray = var_to_bytes(app.sim.export_release_state())
    var unchanged: Array = []
    for i in 48:
        clock_usec += 250000
        var start := Time.get_ticks_usec()
        app._process(.25)
        unchanged.append(Time.get_ticks_usec() - start)
        await get_tree().process_frame
    if frozen != var_to_bytes(app.sim.export_release_state()):
        push_error("Paused Main advanced cargo")
        return
    var result := {"scope":"Full production Main including autosave; deterministic .25s foreground steps via existing test clock seam, isolated fresh browser storage", "rows":rows, "unchanged_view_usec":unchanged, "ledger_unchanged_by_view":true}
    JavaScriptBridge.eval("window.flotraStateBenchmark = " + JSON.stringify(result), true)
