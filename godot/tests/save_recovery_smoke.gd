extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const SaveStoreScript = preload("res://persistence/save_store.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    _cleanup()
    quit(1)


func _run() -> void:
    _cleanup()
    var store: LogisticsSaveStore = SaveStoreScript.new()
    var first = SimScript.new()
    first.money = 4321
    if not store.save_sim(first):
        _fail("first save must succeed")
        return

    var second = SimScript.new()
    second.money = 9876
    if not store.save_sim(second):
        _fail("second save must succeed and create a backup")
        return

    if not FileAccess.file_exists(SaveStoreScript.BACKUP_PATH):
        _fail("second save must preserve the previous primary as backup")
        return

    var corrupt_primary := FileAccess.open(SaveStoreScript.SAVE_PATH, FileAccess.WRITE)
    if corrupt_primary == null:
        _fail("test must be able to replace primary save")
        return
    corrupt_primary.store_string(JSON.stringify({"schema_version": 999, "money": 1}))
    corrupt_primary.close()

    var restored = SimScript.new()
    if not store.load_into(restored):
        _fail("invalid primary schema must fall back to valid backup")
        return
    if int(restored.money) != 4321:
        _fail("backup recovery must restore the previous committed save")
        return

    _verify_full_progress_reset(store)

    _cleanup()
    print("Godot save recovery smoke passed")
    quit(0)


func _verify_full_progress_reset(store: LogisticsSaveStore) -> void:
    var sim = SimScript.new()
    sim.money = 7654
    if not store.save_sim(sim):
        _fail("reset smoke seed save must succeed")
        return

    var temp := FileAccess.open(SaveStoreScript.TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        _fail("reset smoke must create temp save")
        return
    temp.store_string("{}")
    temp.close()

    var marker := FileAccess.open(SaveStoreScript.FTUE_DONE_PATH, FileAccess.WRITE)
    if marker == null:
        _fail("reset smoke must create legacy FTUE marker")
        return
    marker.store_string("core_loop_ftue_v1\n")
    marker.close()

    var v2_marker := FileAccess.open(SaveStoreScript.V2_RANK1_FTUE_DONE_PATH, FileAccess.WRITE)
    if v2_marker == null:
        _fail("reset smoke must create v2 Rank 1 FTUE marker")
        return
    v2_marker.store_string("flotra_v2_rank1_ftue_v1\n")
    v2_marker.close()

    if not store.reset_user_progress():
        _fail("full progress reset must report success")
        return

    for path in [
        SaveStoreScript.SAVE_PATH,
        SaveStoreScript.TEMP_PATH,
        SaveStoreScript.BACKUP_PATH,
        SaveStoreScript.FTUE_DONE_PATH,
        SaveStoreScript.V2_RANK1_FTUE_DONE_PATH,
    ]:
        if FileAccess.file_exists(path):
            _fail("full progress reset must remove %s" % path)
            return

    var fresh = SimScript.new()
    if store.load_into(fresh):
        _fail("fresh state after reset must not restore deleted progress")
        return
    if fresh.money != 5000 or fresh.facility_rank != 1 or fresh.shipped != 0:
        _fail("fresh state after reset must return to Rank 1 defaults")
        return


func _cleanup() -> void:
    for path in [
        SaveStoreScript.SAVE_PATH,
        SaveStoreScript.TEMP_PATH,
        SaveStoreScript.BACKUP_PATH,
        SaveStoreScript.FTUE_DONE_PATH,
    ]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
