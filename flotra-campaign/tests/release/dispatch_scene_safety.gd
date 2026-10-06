extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
const Save = preload("res://prototype/dispatch_save.gd")
var failures: Array[String] = []

class RefusedWebWriter extends Save:
    var refusal := "writer_unavailable"
    func _write(_text: String) -> Dictionary:
        return {"ok":false,"reason":refusal}

func check(ok: bool, label: String) -> void:
    if not ok:
        failures.append(label)
        push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
    var app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    for frame in 3: await process_frame
    var before: Dictionary = app.sim.export_release_state()
    # Synthetic blocked adapter state. No user directory is read or written.
    app.save_store.blocked = true
    app.save_store.status = "既存セーブを保護しています。対応する版を確認してください"
    app.persistence_enabled = true
    app._accept_contract("growth_1")
    app._start_trial()
    app._pause_trial(false)
    app._apply_layout("clear_aisle")
    app._set_operation("parcel")
    app._set_dispatch_window(12)
    app._set_speed(4.0)
    app._set_preference("reduced_motion",true)
    app._buy_upgrade("pick_dispatch_board")
    app.running = true
    app._process(0.25)
    check(not app.running,"Blocked store stops foreground progress")
    check(app.sim.export_release_state()==before,"Protected actions preserve the entire loaded state")
    check(app.hud._sheet_kind=="save_protection","Protected load has an explicit stop sheet")
    # The no-save verification route is still usable, and normal actions bind
    # to the new model without touching any adapter files.
    app.persistence_enabled = false
    app._accept_contract("growth_1")
    check(app.running and app.sim.campaign_status=="running","No-save scene can start normal work")
    app._pause_trial(true)
    check(not app.running and app.sim.campaign_status=="running","Pause preserves job status for selection guard")
    for refusal in ["writer_unavailable", "legacy_writer_unavailable"]:
        var store := RefusedWebWriter.new()
        store.refusal = refusal
        store._read_ready = true
        app.save_store = store
        app.persistence_enabled = true
        app._save_load_result = {}
        before = app.sim.export_release_state()
        app._save_now()
        check(store.blocked, "Refused Web writer becomes terminal " + refusal)
        check(app.hud._sheet_kind=="save_protection" and not app.running, "Refused paused save shows protection immediately " + refusal)
        app._pause_trial(false)
        app._set_preference("reduced_motion",true)
        check(app.sim.export_release_state()==before, "Refused Web writer blocks later mutations " + refusal)
    app.free()
    print("DISPATCH_SCENE_SAFETY ",JSON.stringify({"failures":failures,"scope":"Blocked-load mutation/clock boundary plus no-save action binding"}))
    quit(0 if failures.is_empty() else 1)
