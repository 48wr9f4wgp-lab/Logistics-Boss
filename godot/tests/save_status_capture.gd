extends "res://tests/polish_render_capture.gd"

const SaveStoreScript := preload("res://persistence/save_store.gd")
const SimScript := preload("res://domain/flotra_v2_sim.gd")
const SaveFixtures := preload("res://tests/save_preservation_fixtures.gd")

func _run() -> void:
    _directory = OS.get_environment("FLOTRA_POLISH_CAPTURE_DIR")
    if _directory.is_empty() or OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Save status capture requires output and disposable profile")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(_directory)
    for viewport in [Vector2i(375,667), Vector2i(390,844), Vector2i(430,932)]:
        get_root().size = viewport
        await _capture_state("protected", viewport.x)
        await _capture_state("backup", viewport.x)
        await _capture_state("failure", viewport.x)
    print("SAVE_STATUS_CAPTURE_OK actual-main isolated-synthetic-save-state native-render not-device-QA")
    quit(0)

func _capture_state(state: String, width: int) -> void:
    _clear_fixture_files()
    var seed := SimScript.new()
    seed.money = 43210
    seed.shipped = 20
    seed.logistics_rating = 2
    var payload := seed.save_data()
    if state == "protected":
        payload["schema_version"] = 999
        _write(SaveStoreScript.SAVE_PATH, JSON.stringify(payload))
        _write(SaveStoreScript.BACKUP_PATH, JSON.stringify(payload))
    elif state == "backup":
        _write(SaveStoreScript.SAVE_PATH, "{interrupted test save")
        _write(SaveStoreScript.BACKUP_PATH, JSON.stringify(payload))
    else:
        _write(SaveStoreScript.SAVE_PATH, JSON.stringify(payload))
    _app = MainScene.instantiate()
    get_root().add_child(_app)
    _app.set_process(false)
    _sim = _app.get("sim")
    for child in _app.get_children():
        if child is WarehouseView: _view = child
        if child is MobileGameHud: _hud = child
    _hud._speed_index = 3
    _hud._cycle_speed()
    var clarity := _hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity.coach._persist_completion = false
    var store := _app.get("save_store") as LogisticsSaveStore
    if state == "failure":
        # Genuine write rejection, only inside this disposable Linux profile.
        if SaveFixtures.set_writable(false) != OK:
            push_error("Could not create isolated write-failure fixture")
            quit(1)
            return
        var saved := store.save_sim(_sim)
        SaveFixtures.set_writable(true)
        if saved:
            push_error("Read-only capture fixture unexpectedly saved")
            quit(1)
            return
    await _save("%s-%d.png" % [state, width])
    if state == "protected":
        clarity.open_section("field")
        await _save("protected-management-%d.png" % width)
        _hud._sheet.visible = false
        clarity.zone.open_zone("storage")
        await _save("protected-zone-%d.png" % width)
        clarity.zone.close()
    elif state == "failure":
        if not store.save_sim(_sim):
            push_error("Recovered capture must genuinely save the isolated current session")
            quit(1)
            return
        await _save("recovered-%d.png" % width)
    _app.queue_free()
    await process_frame
    _clear_fixture_files()

func _write(path: String, content: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(content)
    file.close()

func _clear_fixture_files() -> void:
    for path in [SaveStoreScript.SAVE_PATH, SaveStoreScript.BACKUP_PATH, SaveStoreScript.TEMP_PATH, SaveStoreScript.FTUE_DONE_PATH, SaveStoreScript.V2_RANK1_FTUE_DONE_PATH]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
