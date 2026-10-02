extends RefCounted

const Store = preload("res://persistence/save_store.gd")
const Sim = preload("res://domain/flotra_v2_sim.gd")
const PATHS := [Store.SAVE_PATH, Store.BACKUP_PATH, Store.TEMP_PATH, Store.FTUE_DONE_PATH, Store.V2_RANK1_FTUE_DONE_PATH]


static func isolated() -> bool:
    return OS.get_environment("FLOTRA_POLISH_ISOLATED") == "1"


static func clear() -> void:
    assert(isolated(), "Save fixtures require a disposable XDG profile")
    set_writable(true)
    for path in PATHS:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func current(money: int = 43210) -> Dictionary:
    var sim := Sim.new() as FlotraV2Sim
    sim.money = money
    sim.shipped = 10
    return sim.save_data()


static func write(path: String, value: Variant) -> void:
    assert(isolated() and path in PATHS)
    var file := FileAccess.open(path, FileAccess.WRITE)
    assert(file != null, "Fixture file must be writable")
    file.store_string(value if value is String else JSON.stringify(value))
    file.close()


static func seed(kind: String) -> void:
    clear()
    match kind:
        "future":
            write(Store.SAVE_PATH, {"schema_version": 999, "money": 98765, "future_progress": "retain-primary"})
            write(Store.BACKUP_PATH, {"schema_version": 999, "money": 87654, "future_progress": "retain-backup"})
        "backup":
            write(Store.SAVE_PATH, "{broken")
            write(Store.BACKUP_PATH, current())
        "current":
            write(Store.SAVE_PATH, current())
            write(Store.BACKUP_PATH, current(32000))
        "corrupt":
            write(Store.SAVE_PATH, "{broken-primary")
            write(Store.BACKUP_PATH, "[broken-backup")
        "fresh":
            pass


static func snapshot() -> Dictionary:
    var result := {}
    for path in PATHS:
        result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
    return result


static func set_writable(writable: bool) -> Error:
    assert(isolated())
    # Linux test/capture fixtures only: make the disposable profile directory
    # read+execute-only, not the existing save files, then restore owner access.
    return FileAccess.set_unix_permissions(ProjectSettings.globalize_path("user://"), 448 if writable else 320)
