extends SceneTree

const MainScript = preload("res://main.gd")
const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const SaveStoreScript = preload("res://persistence/save_store.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    _clear_runtime_save()
    push_error(message)
    quit(1)


func _run() -> void:
    _clear_runtime_save()

    # Seed a real experienced Rank 2 save so startup exercises the returning-player
    # path instead of only the fresh-save path.
    var seeded = SimScript.new()
    seeded.money = 42000
    seeded.shipped = 12
    seeded.logistics_rating = 8
    seeded.facility_rank = 2
    seeded.completed_contracts = 4
    seeded.worker_count = 5
    seeded.facilities["buffer_yard"] = true
    var seed_store: LogisticsSaveStore = SaveStoreScript.new()
    if not seed_store.save_sim(seeded):
        _fail("runtime startup smoke must be able to seed a returning-player save")
        return

    var main = MainScript.new()
    get_root().add_child(main)
    await process_frame
    await process_frame

    if main.sim == null:
        _fail("runtime startup must create an authoritative simulation")
        return
    if main.sim.facility_rank != 2 or main.sim.logistics_rating < 8:
        _fail("runtime startup must restore authoritative progression before presentation binds")
        return

    var hud = null
    for child in main.get_children():
        if child is GameHud:
            hud = child
            break
    if hud == null:
        _fail("runtime startup must attach the gameplay HUD")
        return
    if hud.sim == null:
        _fail("runtime startup must bind simulation to HUD")
        return
    if hud._money == null or hud._money.text == "—":
        _fail("runtime HUD must render live money instead of placeholder")
        return

    var resume_brief: LogisticsSessionResumeBrief = null
    for child in hud.get_children():
        if child is LogisticsSessionResumeBrief:
            resume_brief = child as LogisticsSessionResumeBrief
            break
    if resume_brief == null:
        _fail("returning startup must attach the session resume brief")
        return
    if not resume_brief.visible:
        _fail("experienced restored saves must surface the continuity brief on startup")
        return
    if resume_brief._label == null or not resume_brief._label.text.contains("RANK 3まで"):
        _fail("Rank 2 resume brief must expose the next facility milestone")
        return
    if not resume_brief._label.text.contains("拡張 1/3"):
        _fail("resume brief must read restored structural progress from the authoritative Domain")
        return

    if main.analytics == null or not _has_analytics_event(main.analytics.events(), "session_resume"):
        _fail("returning startup must record a provider-neutral session_resume analytics event")
        return

    resume_brief._process(LogisticsSessionResumeBrief.DISPLAY_SECONDS + 0.1)
    if resume_brief.visible:
        _fail("resume brief must yield the warehouse view after its short continuity window")
        return

    var before_time := float(main.sim.sim_time)
    await create_timer(0.25).timeout
    if float(main.sim.sim_time) <= before_time:
        _fail("runtime simulation clock must advance after startup")
        return

    main.queue_free()
    await process_frame
    _clear_runtime_save()
    print("Godot runtime startup and returning-session brief smoke passed")
    quit(0)


func _has_analytics_event(events: Array[Dictionary], event_name: String) -> bool:
    for event in events:
        if String(event.get("name", "")) == event_name:
            return true
    return false


func _clear_runtime_save() -> void:
    for path in [
        SaveStoreScript.SAVE_PATH,
        SaveStoreScript.TEMP_PATH,
        SaveStoreScript.BACKUP_PATH,
    ]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
