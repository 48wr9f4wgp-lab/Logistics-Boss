extends SceneTree

# Independent, disposable-profile regression matrix. Do not run against a player
# profile. The standard run_polish_checks.sh runner supplies the isolation flag.
const SimScript = preload("res://domain/flotra_v2_sim.gd")
const SaveStoreScript = preload("res://persistence/save_store.gd")
const MainScript = preload("res://main.gd")
const PATHS = [SaveStoreScript.SAVE_PATH, SaveStoreScript.BACKUP_PATH, SaveStoreScript.TEMP_PATH]
const KINDS = ["missing", "current", "old", "future", "corrupt", "array", "object", "null", "directory", "bad_field", "bad_nested"]

var failures: Array[String] = []
var checks := 0
var cases := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
        push_error("Independent save review requires a disposable XDG_DATA_HOME and FLOTRA_POLISH_ISOLATED=1")
        quit(2)
        return
    for primary_kind in KINDS:
        for backup_kind in KINDS:
            _matrix_case(primary_kind, backup_kind, false)
            _matrix_case(primary_kind, backup_kind, true)
    _future_temp_case()
    _backup_recovery_case()
    _latched_and_reset_case()
    _transient_write_failure_case()
    _unreadable_file_cases()
    _known_field_shape_cases()
    _minimal_historical_cases()
    await _main_boundary_case("future", "corrupt")
    await _main_boundary_case("corrupt", "array")
    await _main_boundary_case("future", "current")
    for protect_later in [false, true]:
        for existing_markers in [false, true]:
            for action in ["skip", "complete"]:
                await _protected_marker_case(protect_later, existing_markers, action)
    for action in ["skip", "complete"]:
        await _normal_marker_case(action)
    _cleanup()
    if not failures.is_empty():
        for failure in failures:
            push_error(failure)
        print("Independent save review FAILED: %d failures, %d checks, %d cases" % [failures.size(), checks, cases])
        quit(1)
        return
    print("Independent save preservation review passed: %d checks across %d cases" % [checks, cases])
    quit(0)


func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)


func _matrix_case(primary_kind: String, backup_kind: String, load_first: bool) -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, primary_kind, 13579)
    _seed(SaveStoreScript.BACKUP_PATH, backup_kind, 24680)
    var before := _snapshot()
    var label := "%s/%s load=%s" % [primary_kind, backup_kind, load_first]
    var store: LogisticsSaveStore = SaveStoreScript.new()
    var sim = SimScript.new()
    var has_supported := _valid(primary_kind) or _valid(backup_kind)
    var has_existing := primary_kind != "missing" or backup_kind != "missing"
    var must_protect := primary_kind in ["future", "directory"] or backup_kind in ["future", "directory"] or (not has_supported and has_existing)
    if load_first:
        _check(store.load_into(sim) == has_supported, label + ": load result")
        if has_supported:
            _check(sim.money == (13579 if _valid(primary_kind) else 24680), label + ": restores expected copy")
        _check(store.load_status == ("primary" if _valid(primary_kind) else ("backup" if _valid(backup_kind) else ("failed" if has_existing else "fresh"))), label + ": load status")
    var saved := store.save_sim(sim)
    _check(saved != must_protect, label + ": save result")
    _check(store.write_protected == must_protect, label + ": guard state")
    if must_protect:
        _check(_snapshot() == before, label + ": first denied save preserves all bytes")
        for attempt in range(2):
            store.load_into(sim)
            _check(not store.save_sim(sim), label + ": repeated write stays blocked")
        _check(not SaveStoreScript.new().save_sim(SimScript.new()), label + ": new instance cannot bypass")
        _check(_snapshot() == before, label + ": repeated calls preserve all bytes")
    else:
        _check(store.save_status == "saved", label + ": successful status")
        var restored = SimScript.new()
        _check(SaveStoreScript.new().load_into(restored), label + ": result remains loadable")


func _future_temp_case() -> void:
    for primary_kind in ["missing", "current"]:
        cases += 1
        _cleanup()
        _seed(SaveStoreScript.SAVE_PATH, primary_kind, 13579)
        _seed(SaveStoreScript.TEMP_PATH, "future", 24680)
        var before := _snapshot()
        var store: LogisticsSaveStore = SaveStoreScript.new()
        _check(not store.save_sim(SimScript.new()), primary_kind + "/future temp: direct write denied")
        _check(_snapshot() == before, primary_kind + "/future temp: evidence preserved")
        store.load_into(SimScript.new())
        _check(not store.save_sim(SimScript.new()), primary_kind + "/future temp: loaded write denied")
        _check(_snapshot() == before, primary_kind + "/future temp: still preserved")


func _backup_recovery_case() -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, "corrupt", 0)
    _seed(SaveStoreScript.BACKUP_PATH, "current", 24680)
    var good_backup := FileAccess.get_file_as_bytes(SaveStoreScript.BACKUP_PATH)
    var store: LogisticsSaveStore = SaveStoreScript.new()
    var sim = SimScript.new()
    _check(store.load_into(sim) and sim.money == 24680, "recoverable corruption: restore valid backup")
    _check(store.save_sim(sim), "recoverable corruption: resumed game remains writable")
    _check(FileAccess.get_file_as_bytes(SaveStoreScript.BACKUP_PATH) == good_backup, "recoverable corruption: first repair save retains known-good backup")
    _seed(SaveStoreScript.SAVE_PATH, "corrupt", 0)
    var recovered_again = SimScript.new()
    _check(SaveStoreScript.new().load_into(recovered_again) and recovered_again.money == 24680, "recoverable corruption: backup still recovers after repaired primary fails")


func _latched_and_reset_case() -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, "future", 13579)
    var store: LogisticsSaveStore = SaveStoreScript.new()
    _check(not store.load_into(SimScript.new()), "latched: unsupported load fails")
    _cleanup()
    _check(not store.load_into(SimScript.new()), "latched: absence does not count as restore")
    _check(not store.save_sim(SimScript.new()), "latched: removing files outside reset does not unlock")
    _seed(SaveStoreScript.TEMP_PATH, "directory", 0)
    _write(SaveStoreScript.TEMP_PATH + "/blocker", "keep")
    _check(not store.reset_user_progress(), "latched: incomplete reset reports failure")
    _check(store.write_protected, "latched: incomplete reset cannot clear protection")
    _cleanup()
    _write(SaveStoreScript.FTUE_DONE_PATH, "legacy done")
    _write(SaveStoreScript.V2_RANK1_FTUE_DONE_PATH, "v2 done")
    _check(store.reset_user_progress(), "reset: explicit successful reset works")
    _check(not store.write_protected and store.save_status == "idle", "reset: guard and status clear")
    _check(not FileAccess.file_exists(SaveStoreScript.FTUE_DONE_PATH) and not FileAccess.file_exists(SaveStoreScript.V2_RANK1_FTUE_DONE_PATH), "reset: both onboarding markers removed")
    _check(store.save_sim(SimScript.new()), "reset: fresh game can save")


func _transient_write_failure_case() -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, "current", 13579)
    _seed(SaveStoreScript.BACKUP_PATH, "current", 24680)
    _seed(SaveStoreScript.TEMP_PATH, "current", 13579)
    var before := _snapshot()
    _check(FileAccess.set_unix_permissions(SaveStoreScript.TEMP_PATH, 292) == OK, "transient: configure read-only temp")
    var store: LogisticsSaveStore = SaveStoreScript.new()
    var sim = SimScript.new()
    store.load_into(sim)
    _check(not store.save_sim(sim), "transient: unwritable temp reports failure")
    _check(store.save_status == "failed" and not store.write_protected, "transient: failure does not latch preservation")
    _check(_snapshot() == before, "transient: failed write preserves original bytes")
    _check(FileAccess.set_unix_permissions(SaveStoreScript.TEMP_PATH, 420) == OK, "transient: restore writable temp")
    _check(store.save_sim(sim) and store.save_status == "saved", "transient: successful retry clears failure status")


func _unreadable_file_cases() -> void:
    for unreadable_path in [SaveStoreScript.SAVE_PATH, SaveStoreScript.BACKUP_PATH]:
        cases += 1
        _cleanup()
        _seed(SaveStoreScript.SAVE_PATH, "current", 13579)
        _seed(SaveStoreScript.BACKUP_PATH, "current", 24680)
        var before := _snapshot()
        _check(FileAccess.set_unix_permissions(unreadable_path, 0) == OK, "unreadable: remove file permissions")
        var store: LogisticsSaveStore = SaveStoreScript.new()
        var sim = SimScript.new()
        _check(store.load_into(sim), "unreadable: other supported copy still loads")
        _check(not store.save_sim(sim), "unreadable: preserve unknown unreadable copy")
        _check(not SaveStoreScript.new().save_sim(SimScript.new()), "unreadable: direct save cannot bypass")
        _check(FileAccess.set_unix_permissions(unreadable_path, 420) == OK, "unreadable: restore fixture permissions")
        _check(_snapshot() == before, "unreadable: original file bytes preserved")


func _known_field_shape_cases() -> void:
    var template: Dictionary = SimScript.new().save_data()
    for path in _field_paths(template):
        if path == ["schema_version"]:
            continue
        var invalid := template.duplicate(true)
        var cursor: Dictionary = invalid
        for index in range(path.size() - 1):
            cursor = cursor[path[index]]
        var key: String = path.back()
        cursor[key] = [] if cursor[key] is Dictionary else {}
        _assert_invalid_payload(invalid, "field shape " + str(path))
    for container in ["active_contract", "contract_offers"]:
        for key in ["id", "kind", "title", "duration", "target", "remaining", "progress", "reward_cash", "reward_rp", "reward_rating", "start_shipped"]:
            var invalid := template.duplicate(true)
            var contract := {key: {"broken": true}}
            invalid[container] = [contract] if container == "contract_offers" else contract
            _assert_invalid_payload(invalid, container + ": invalid " + key)


func _field_paths(data: Dictionary, prefix: Array = []) -> Array:
    var paths: Array = []
    for key in data:
        var next := prefix + [key]
        paths.append(next)
        if data[key] is Dictionary:
            paths.append_array(_field_paths(data[key], next))
    return paths


func _assert_invalid_payload(invalid: Dictionary, label: String) -> void:
    cases += 1
    _cleanup()
    _write(SaveStoreScript.SAVE_PATH, JSON.stringify(invalid))
    var before := _snapshot()
    _check(not SaveStoreScript.new().save_sim(SimScript.new()), label + ": direct save denied")
    var store: LogisticsSaveStore = SaveStoreScript.new()
    _check(not store.load_into(SimScript.new()), label + ": invalid restore rejected safely")
    _check(store.write_protected and not store.save_sim(SimScript.new()), label + ": guard latched")
    _check(_snapshot() == before, label + ": bytes retained")


func _minimal_historical_cases() -> void:
    var current_schema: int = SimScript.new().save_data()["schema_version"]
    for schema in range(1, current_schema + 1):
        cases += 1
        _cleanup()
        _write(SaveStoreScript.SAVE_PATH, JSON.stringify({"schema_version": schema, "money": 1777}))
        var store: LogisticsSaveStore = SaveStoreScript.new()
        var sim = SimScript.new()
        _check(store.load_into(sim) and sim.money == 1777, "historical schema %d: missing later fields use defaults" % schema)
        _check(store.save_sim(sim), "historical schema %d: migrated save remains writable" % schema)


func _main_boundary_case(primary_kind: String, backup_kind: String) -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, primary_kind, 13579)
    _seed(SaveStoreScript.BACKUP_PATH, backup_kind, 24680)
    var before := _snapshot()
    var main = MainScript.new()
    get_root().add_child(main)
    main.set_process(false)
    await process_frame
    await process_frame
    _check(main.save_store.write_protected, "main " + primary_kind + "/" + backup_kind + ": startup protection")
    main._process(10.1)
    main._process(10.1)
    main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
    main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
    _check(not main.save_store.save_sim(main.sim), "main: manual save blocked")
    _check(_snapshot() == before, "main " + primary_kind + "/" + backup_kind + ": startup + 20s + suspend + close + manual preserve bytes")
    main.queue_free()
    await process_frame


func _protected_marker_case(protect_later: bool, existing_markers: bool, action: String) -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, "current" if protect_later else "future", 13579)
    if existing_markers:
        _write(SaveStoreScript.FTUE_DONE_PATH, "preserve legacy marker bytes\n")
        _write(SaveStoreScript.V2_RANK1_FTUE_DONE_PATH, "preserve v2 marker bytes\n")
    var marker_before := _marker_snapshot()
    var main = MainScript.new()
    get_root().add_child(main)
    main.set_process(false)
    var hud: MobileGameHud
    for child in main.get_children():
        if child is MobileGameHud:
            hud = child
    var clarity = hud.get_node("MobileInteractionClarity")
    var label := "markers later=%s existing=%s action=%s" % [protect_later, existing_markers, action]
    _check(hud._ftue_coach.sim == main.sim and clarity.coach.sim == main.sim, label + ": actual main coaches are normally bound")
    if existing_markers:
        _check(not hud._ftue_coach.visible and not clarity.coach.visible, label + ": startup respects existing completion markers")
        _check(_marker_snapshot() == marker_before, label + ": binding does not rewrite existing markers")
    if protect_later:
        _check(not main.save_store.write_protected, label + ": session starts writable")
        _seed(SaveStoreScript.SAVE_PATH, "future", 99999)
        _check(not main.save_store.save_sim(main.sim), label + ": later preflight latches protection")
    _check(main.save_store.write_protected, label + ": guarded before action")
    var save_before := _snapshot()
    # Exercise the actual bound signal/method entry points immediately after a
    # later protection event. The fixture never changes _persist_completion.
    for coach in [hud._ftue_coach, clarity.coach]:
        if action == "skip":
            coach._skip_button.pressed.emit()
        else:
            coach._complete_ftue()
        _check(_marker_snapshot() == marker_before, label + ": each coach preserves both marker files")
    await process_frame
    await process_frame
    _check(_marker_snapshot() == marker_before, label + ": deferred callbacks cannot write markers")
    _check(_snapshot() == save_before, label + ": tutorial action leaves protected save bytes intact")
    main.queue_free()
    await process_frame


func _normal_marker_case(action: String) -> void:
    cases += 1
    _cleanup()
    _seed(SaveStoreScript.SAVE_PATH, "current", 13579)
    var main = MainScript.new()
    get_root().add_child(main)
    main.set_process(false)
    var hud: MobileGameHud
    for child in main.get_children():
        if child is MobileGameHud:
            hud = child
    var clarity = hud.get_node("MobileInteractionClarity")
    _check(not main.save_store.write_protected, "normal markers " + action + ": session remains writable")
    for coach in [hud._ftue_coach, clarity.coach]:
        if action == "skip":
            coach._skip_button.pressed.emit()
        else:
            coach._complete_ftue()
    _check(FileAccess.get_file_as_string(SaveStoreScript.FTUE_DONE_PATH) == "core_loop_ftue_v1\n", "normal markers " + action + ": legacy completion persists")
    _check(FileAccess.get_file_as_string(SaveStoreScript.V2_RANK1_FTUE_DONE_PATH) == "flotra_v2_rank1_ftue_v1\n", "normal markers " + action + ": v2 completion persists")
    main.queue_free()
    await process_frame


func _marker_snapshot() -> Array:
    var result: Array = []
    for path in [SaveStoreScript.FTUE_DONE_PATH, SaveStoreScript.V2_RANK1_FTUE_DONE_PATH]:
        result.append(FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else "missing")
    return result


func _valid(kind: String) -> bool:
    return kind == "current" or kind == "old"


func _seed(path: String, kind: String, money: int) -> void:
    if kind == "missing":
        return
    if kind == "directory":
        _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)) == OK, "fixture directory " + path)
        return
    if kind in ["current", "old", "future", "bad_field", "bad_nested"]:
        var sim = SimScript.new()
        sim.money = money
        var data: Dictionary = sim.save_data()
        if kind == "old":
            data["schema_version"] = 7
        elif kind == "future":
            data["schema_version"] = 999
        elif kind == "bad_field":
            data["money"] = {"broken": true}
        elif kind == "bad_nested":
            data["growth_automation"]["extra_moved"] = {"broken": true}
        _write(path, JSON.stringify(data))
    else:
        _write(path, {"corrupt": "{\"unfinished\":", "array": "[1,2,3]", "object": "{}", "null": "null"}[kind])


func _write(path: String, content: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    _check(file != null, "fixture opens " + path)
    if file != null:
        file.store_string(content)
        file.close()


func _snapshot() -> Array:
    var result: Array = []
    for path in PATHS:
        if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
            result.append("directory")
        elif FileAccess.file_exists(path):
            result.append(FileAccess.get_file_as_bytes(path))
        else:
            result.append("missing")
    return result


func _cleanup() -> void:
    for path in PATHS + [SaveStoreScript.FTUE_DONE_PATH, SaveStoreScript.V2_RANK1_FTUE_DONE_PATH]:
        var absolute := ProjectSettings.globalize_path(path)
        if FileAccess.file_exists(path + "/blocker"):
            DirAccess.remove_absolute(absolute + "/blocker")
        if FileAccess.file_exists(path):
            FileAccess.set_unix_permissions(path, 420)
        if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
            DirAccess.remove_absolute(absolute)
