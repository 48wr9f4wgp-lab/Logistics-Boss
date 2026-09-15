extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
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

    _cleanup()
    print("Godot save recovery smoke passed")
    quit(0)


func _cleanup() -> void:
    for path in [SaveStoreScript.SAVE_PATH, SaveStoreScript.TEMP_PATH, SaveStoreScript.BACKUP_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
