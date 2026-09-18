extends RefCounted
class_name LogisticsSaveStore

const SAVE_PATH := "user://logistics_boss_godot_save.json"
const TEMP_PATH := "user://logistics_boss_godot_save.tmp"
const BACKUP_PATH := "user://logistics_boss_godot_save.bak"
const FTUE_DONE_PATH := "user://logistics_boss_ftue_v1.done"
const V2_RANK1_FTUE_DONE_PATH := "user://flotra_v2_rank1_ftue_v1.done"


func save_sim(sim: WarehouseSim) -> bool:
    var payload := sim.save_data()
    var json := JSON.stringify(payload)

    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(json)
    temp.flush()
    temp.close()

    var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
    var temp_abs := ProjectSettings.globalize_path(TEMP_PATH)
    var backup_abs := ProjectSettings.globalize_path(BACKUP_PATH)

    if FileAccess.file_exists(SAVE_PATH):
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.remove_absolute(backup_abs)
        if DirAccess.rename_absolute(save_abs, backup_abs) != OK:
            return false

    if DirAccess.rename_absolute(temp_abs, save_abs) != OK:
        if FileAccess.file_exists(BACKUP_PATH):
            DirAccess.rename_absolute(backup_abs, save_abs)
        return false

    return true


func load_into(sim: WarehouseSim) -> bool:
    var primary := _read_json(SAVE_PATH)
    if not primary.is_empty() and sim.load_data(primary):
        return true

    var backup := _read_json(BACKUP_PATH)
    if backup.is_empty():
        return false
    return sim.load_data(backup)


func reset_user_progress() -> bool:
    var ok := true
    for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH, FTUE_DONE_PATH, V2_RANK1_FTUE_DONE_PATH]:
        if not FileAccess.file_exists(path):
            continue
        var absolute := ProjectSettings.globalize_path(path)
        if DirAccess.remove_absolute(absolute) != OK:
            ok = false
    return ok


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}

    var text := file.get_as_text()
    file.close()

    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed
