extends SceneTree

const Store = preload("res://persistence/save_store.gd")
const Sim = preload("res://domain/flotra_v2_sim.gd")
const Fixture = preload("res://tests/save_preservation_fixtures.gd")
var _checks := 0
var _failures := 0


func _init() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error(message)


func _run() -> void:
    if not Fixture.isolated():
        push_error("save_preservation_smoke requires an isolated profile")
        quit(1)
        return
    _verify_regular_saves()
    _verify_protected_files()
    _verify_latch_and_reset()
    _verify_failed_write_retry()
    Fixture.clear()
    print("Save preservation checks=%d failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _verify_regular_saves() -> void:
    for kind in ["fresh", "current", "backup"]:
        Fixture.seed(kind)
        var store := Store.new()
        var sim := Sim.new()
        var restored := store.load_into(sim)
        _expect(restored == (kind != "fresh"), "%s load result" % kind)
        _expect(not store.write_protected, "%s remains writable" % kind)
        _expect(store.load_status == {"fresh": "fresh", "current": "primary", "backup": "backup"}[kind], "%s explicit load status" % kind)
        var previous_backup: Variant = Fixture.snapshot()[Store.BACKUP_PATH]
        var expected_money := sim.money + 111
        sim.money = expected_money
        _expect(store.save_sim(sim), "%s save succeeds" % kind)
        _expect(store.save_status == "saved", "%s success is reported after commit" % kind)
        if kind == "backup":
            _expect(Fixture.snapshot()[Store.BACKUP_PATH] == previous_backup, "Recovery does not rotate corrupt primary over usable backup")
        var reentered := Sim.new()
        var another := Store.new()
        _expect(another.load_into(reentered) and reentered.money == expected_money, "%s reentry restores saved progress" % kind)
        _expect(another.save_sim(reentered), "%s resumed session still saves" % kind)

    Fixture.clear()
    Fixture.write(Store.BACKUP_PATH, Fixture.current())
    var store := Store.new()
    var sim := Sim.new()
    _expect(store.load_into(sim) and store.load_status == "backup", "Missing primary restores current backup")
    var backup_before: Variant = Fixture.snapshot()[Store.BACKUP_PATH]
    _expect(store.save_sim(sim), "Backup-only session can save")
    _expect(Fixture.snapshot()[Store.BACKUP_PATH] == backup_before, "Backup-only first save retains good backup")

    Fixture.seed("current")
    Fixture.write(Store.BACKUP_PATH, "[not valid")
    store = Store.new()
    _expect(store.load_into(sim) and store.load_status == "primary", "Usable primary does not depend on a malformed backup")
    _expect(store.save_sim(sim), "Current primary can replace malformed backup through ordinary rotation")


func _verify_protected_files() -> void:
    var future := {"schema_version": 999, "future_progress": "keep"}
    var invalid_money := Fixture.current()
    invalid_money["money"] = {"broken": true}
    var invalid_staffing := Fixture.current()
    invalid_staffing["zone_staffing"]["inbound"] = []
    var invalid_contract := Fixture.current()
    invalid_contract["active_contract"] = {"remaining": {"broken": true}}
    var invalid_offer := Fixture.current()
    invalid_offer["contract_offers"] = [{"reward_cash": {"broken": true}}]
    var cases := [
        ["both corrupt", "{broken", "[broken", null, false],
        ["both non-object", "[]", "null", null, false],
        ["missing schema", {"money": 9}, {}, null, false],
        ["invalid schema type", {"schema_version": {}}, {"schema_version": -1}, null, false],
        ["invalid money field", invalid_money, null, null, false],
        ["invalid nested staffing", invalid_staffing, null, null, false],
        ["invalid active contract", invalid_contract, null, null, false],
        ["invalid contract offer", invalid_offer, null, null, false],
        ["future primary", future, null, null, false],
        ["future backup", null, future, null, false],
        ["both future", future, future, null, false],
        ["future primary/current backup", future, Fixture.current(), null, true],
        ["current primary/future backup", Fixture.current(), future, null, true],
        ["future temporary/current primary", Fixture.current(), null, future, true],
        ["orphan current temporary", null, null, Fixture.current(), false],
        ["orphan corrupt temporary", null, null, "{interrupted", false],
    ]
    for item in cases:
        Fixture.clear()
        for pair in [[Store.SAVE_PATH, item[1]], [Store.BACKUP_PATH, item[2]], [Store.TEMP_PATH, item[3]]]:
            if pair[1] != null:
                Fixture.write(pair[0], pair[1])
        var before := Fixture.snapshot()
        var direct := Store.new()
        _expect(not direct.save_sim(Sim.new()), "%s direct save without load is refused" % item[0])
        _expect(direct.write_protected, "%s direct protection is latched" % item[0])
        _expect(Fixture.snapshot() == before, "%s direct save preserves every byte" % item[0])
        var store := Store.new()
        for attempt in 3:
            var sim := Sim.new()
            _expect(store.load_into(sim) == item[4], "%s load attempt %d reports usable fallback truthfully" % [item[0], attempt])
            _expect(store.write_protected and store.save_status == "protected", "%s repeated load cannot clear protection" % item[0])
            sim.money += 5000
            _expect(not store.save_sim(sim), "%s normal save remains refused" % item[0])
            _expect(Fixture.snapshot() == before, "%s load/save preserves source bytes" % item[0])
        var reentered := Store.new()
        reentered.load_into(Sim.new())
        _expect(reentered.write_protected and not reentered.save_sim(Sim.new()), "%s new store cannot bypass protection" % item[0])
        _expect(Fixture.snapshot() == before, "%s reentry preserves source bytes" % item[0])


func _verify_latch_and_reset() -> void:
    Fixture.seed("future")
    var store := Store.new()
    var sim := Sim.new()
    store.load_into(sim)
    Fixture.seed("current") # Only the isolated fixture replaces files externally.
    _expect(store.load_into(sim), "A latched store may read a subsequently usable file")
    _expect(store.write_protected and not store.save_sim(sim), "Read retry never silently clears a prior protection decision")
    var blocked_dir := ProjectSettings.globalize_path(Store.V2_RANK1_FTUE_DONE_PATH)
    _expect(DirAccess.make_dir_absolute(blocked_dir) == OK, "Prepare isolated reset failure")
    var child := FileAccess.open(blocked_dir.path_join("keep"), FileAccess.WRITE)
    child.store_string("fixture")
    child.close()
    _expect(not store.reset_user_progress(), "Incomplete explicit reset reports failure")
    _expect(store.write_protected and not store.save_sim(sim), "Failed reset cannot unlock writes")
    DirAccess.remove_absolute(blocked_dir.path_join("keep"))
    DirAccess.remove_absolute(blocked_dir)
    _expect(store.reset_user_progress(), "Complete explicit reset succeeds")
    _expect(not store.write_protected and store.load_status == "fresh", "Only complete explicit reset clears the latch")
    _expect(store.save_sim(Sim.new()), "Explicitly reset new game is writable")


func _verify_failed_write_retry() -> void:
    Fixture.seed("current")
    var store := Store.new()
    var sim := Sim.new()
    store.load_into(sim)
    var before := Fixture.snapshot()
    _expect(Fixture.set_writable(false) == OK, "Make only isolated save directory read-only")
    var saved := store.save_sim(sim)
    Fixture.set_writable(true)
    _expect(not saved and store.save_status == "failed", "Actual failed file creation reports a save failure")
    _expect(not store.write_protected, "Transient save error does not masquerade as an incompatible restore")
    _expect(Fixture.snapshot() == before, "Failed temporary creation leaves committed files unchanged")
    _expect(store.save_sim(sim) and store.save_status == "saved", "Next successful retry clears actual failed-save status")
