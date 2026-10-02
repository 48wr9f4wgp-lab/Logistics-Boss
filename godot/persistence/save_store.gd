extends RefCounted
class_name LogisticsSaveStore

signal status_changed

const SAVE_PATH := "user://logistics_boss_godot_save.json"
const TEMP_PATH := "user://logistics_boss_godot_save.tmp"
const BACKUP_PATH := "user://logistics_boss_godot_save.bak"
const FTUE_DONE_PATH := "user://logistics_boss_ftue_v1.done"
const V2_RANK1_FTUE_DONE_PATH := "user://flotra_v2_rank1_ftue_v1.done"
const CONTRACT_FIELDS := {
    "id": 0, "kind": "", "title": "", "description": "", "duration": 0.0,
    "target": 0.0, "threshold": 0.0, "reward_cash": 0, "reward_rp": 0,
    "reward_rating": 0, "remaining": 0.0, "progress": 0.0, "start_shipped": 0,
}

# Session status is deliberately outside the save payload. A failed restore is
# not a new game, and no caller may overwrite unresolved files by saving a fresh
# simulation. Protection remains latched until the explicit reset succeeds.
var load_status := "unchecked"
var save_status := "idle"
var write_protected := false
var protection_reason := ""


func save_sim(sim: WarehouseSim) -> bool:
    var payload := sim.save_data()
    if write_protected:
        _set_save_status("protected")
        return false
    # Check at the boundary on every call, including callers that never loaded
    # first and another SaveStore instance. Never touch TEMP_PATH before this.
    var files := _inspect_saves()
    if not _disk_is_safe_to_write(files, int(payload.get("schema_version", -1)), payload):
        _set_save_status("protected")
        return false
    var json := JSON.stringify(payload)

    var temp := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if temp == null:
        _set_save_status("failed")
        return false
    temp.store_string(json)
    temp.flush()
    var write_error := temp.get_error()
    temp.close()
    if write_error != OK:
        _set_save_status("failed")
        return false

    var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
    var temp_abs := ProjectSettings.globalize_path(TEMP_PATH)
    var backup_abs := ProjectSettings.globalize_path(BACKUP_PATH)

    # When loading fell back from a corrupt primary, retain the usable backup
    # instead of replacing it with the corrupt bytes. Rename installs the
    # completed temporary file over the old primary without deleting it first.
    var preserve_backup := not _supported_file(files["primary"], int(payload["schema_version"]), payload) and _supported_file(files["backup"], int(payload["schema_version"]), payload)
    if FileAccess.file_exists(SAVE_PATH) and not preserve_backup:
        if FileAccess.file_exists(BACKUP_PATH):
            if DirAccess.remove_absolute(backup_abs) != OK:
                _set_save_status("failed")
                return false
        if DirAccess.rename_absolute(save_abs, backup_abs) != OK:
            _set_save_status("failed")
            return false

    if DirAccess.rename_absolute(temp_abs, save_abs) != OK:
        if not preserve_backup and FileAccess.file_exists(BACKUP_PATH):
            DirAccess.rename_absolute(backup_abs, save_abs)
        _set_save_status("failed")
        return false

    _set_save_status("saved")
    return true


func load_into(sim: WarehouseSim) -> bool:
    var files := _inspect_saves()
    var shape := sim.save_data()
    var supported_schema := int(shape.get("schema_version", -1))
    _disk_is_safe_to_write(files, supported_schema, shape)
    var primary: Dictionary = files["primary"]
    if _supported_file(primary, supported_schema, shape) and sim.load_data(primary["data"]):
        load_status = "primary"
        status_changed.emit()
        return true

    var backup: Dictionary = files["backup"]
    if _supported_file(backup, supported_schema, shape) and sim.load_data(backup["data"]):
        load_status = "backup"
        status_changed.emit()
        return true
    var existing := bool(primary["exists"]) or bool(backup["exists"]) or _path_exists(TEMP_PATH)
    load_status = "failed" if existing or write_protected else "fresh"
    if existing:
        _protect("unreadable")
    status_changed.emit()
    return false


func reset_user_progress() -> bool:
    var ok := true
    for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH, FTUE_DONE_PATH, V2_RANK1_FTUE_DONE_PATH]:
        if not _path_exists(path):
            continue
        var absolute := ProjectSettings.globalize_path(path)
        if DirAccess.remove_absolute(absolute) != OK:
            ok = false
    if ok:
        write_protected = false
        protection_reason = ""
        load_status = "fresh"
        save_status = "idle"
        status_changed.emit()
    return ok


func _inspect_saves() -> Dictionary:
    return {"primary": _inspect_file(SAVE_PATH), "backup": _inspect_file(BACKUP_PATH), "temporary": _inspect_file(TEMP_PATH)}


func _disk_is_safe_to_write(files: Dictionary, supported_schema: int, shape: Dictionary) -> bool:
    if write_protected:
        return false
    var has_supported := false
    var has_existing := false
    for key in ["primary", "backup", "temporary"]:
        var entry: Dictionary = files[key]
        has_existing = has_existing or bool(entry["exists"])
        if String(entry["state"]) == "unreadable":
            _protect("unreadable")
            return false
        if _schema(entry["data"]) > supported_schema:
            _protect("newer_version")
            return false
        # A temporary file is evidence of an interrupted write, not a restored
        # session. It cannot by itself authorize replacing existing progress.
        if key != "temporary":
            has_supported = has_supported or _supported_file(entry, supported_schema, shape)
    if not has_supported and (has_existing or _path_exists(TEMP_PATH)):
        _protect("unreadable")
        return false
    return true


func _supported_file(entry: Dictionary, supported_schema: int, shape: Dictionary) -> bool:
    var schema := _schema(entry["data"])
    if String(entry["state"]) != "parsed" or schema < 1 or schema > supported_schema:
        return false
    var data: Dictionary = entry["data"]
    if not _matches_known_fields(data, shape):
        return false
    # These dictionaries can be empty in the live simulation. Validate their
    # known fields explicitly before Domain/HUD conversion code can encounter
    # a corrupt object where a number or string belongs.
    if data.has("active_contract") and not _matches_known_fields(data["active_contract"], CONTRACT_FIELDS):
        return false
    if data.has("contract_offers"):
        for offer in data["contract_offers"]:
            if not _matches_known_fields(offer, CONTRACT_FIELDS):
                return false
    return true


func _matches_known_fields(value: Variant, example: Variant) -> bool:
    if example is Dictionary:
        if value is not Dictionary:
            return false
        for key in example:
            if value.has(key) and not _matches_known_fields(value[key], example[key]):
                return false
        return true
    if example is Array:
        if value is not Array:
            return false
        if not example.is_empty():
            for item in value:
                if not _matches_known_fields(item, example[0]):
                    return false
        return true
    if example is int or example is float:
        return (value is int or value is float) and is_finite(float(value))
    return typeof(value) == typeof(example)


func _schema(data: Dictionary) -> int:
    var value: Variant = data.get("schema_version", -1)
    if value is int or value is float:
        if not is_finite(float(value)):
            return -1
        if float(value) > 2147483647.0:
            return 2147483647
        if float(value) < 1.0:
            return -1
        return int(value)
    if value is String and value.is_valid_int():
        return int(value)
    return -1


func _protect(reason: String) -> void:
    if write_protected:
        return
    write_protected = true
    protection_reason = reason
    save_status = "protected"
    status_changed.emit()


func _set_save_status(next_status: String) -> void:
    if save_status == next_status:
        return
    save_status = next_status
    status_changed.emit()


func _path_exists(path: String) -> bool:
    return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _inspect_file(path: String) -> Dictionary:
    if not _path_exists(path):
        return {"exists": false, "state": "missing", "data": {}}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {"exists": true, "state": "unreadable", "data": {}}

    var text := file.get_as_text()
    var read_error := file.get_error()
    file.close()
    if read_error != OK and read_error != ERR_FILE_EOF:
        return {"exists": true, "state": "unreadable", "data": {}}
    # Expected corrupt-save fixtures must not emit an engine script diagnostic.
    var parser := JSON.new()
    if parser.parse(text) != OK or parser.data is not Dictionary:
        return {"exists": true, "state": "invalid", "data": {}}
    return {"exists": true, "state": "parsed", "data": parser.data}
