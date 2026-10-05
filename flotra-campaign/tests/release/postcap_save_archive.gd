extends SceneTree
## Every profile below is constructed here. No user progress is opened.
const Save = preload("res://prototype/release_save.gd")
const Sim = preload("res://prototype/growth_sim.gd")
const V1 = preload("res://prototype/release_sim.gd")
const V2 = preload("res://prototype/growth_v2_sim.gd")
const V3 = preload("res://prototype/growth_v3_sim.gd")
var failures: Array[String] = []
var checks := 0

class MemoryStore extends Save:
    var files: Dictionary = {}
    var writes: Array = []
    var fail_write := ""
    var fail_rename := ""
    var archive_replaced := false
    func _read_pair() -> Dictionary:
        var pair := {"ok":true}
        for entry in [["primary",PATH],["backup",BACKUP],["archive",ARCHIVE]]:
            pair[entry[0]] = str(files.get(entry[1],""))
            pair[entry[0]+"_exists"] = files.has(entry[1])
        return pair
    func _write_file(path: String,text: String) -> bool:
        writes.append(["stage",path])
        files[path] = text.substr(0,7) if path == fail_write else text
        return path != fail_write
    func _rename_file(from: String,to: String) -> bool:
        writes.append(["rename",to])
        if to == fail_rename: return false
        if to == ARCHIVE and files.has(to): archive_replaced = true
        files[to] = files[from]
        files.erase(from)
        return true
    func _native_archive_exists() -> bool:
        return files.has(ARCHIVE)
    func _write_native(text: String) -> Dictionary:
        return _write_native_locked(text)

class InvalidExportSim extends Sim:
    func export_release_state() -> Dictionary:
        return {"error":"prototype_no_save"}

class InvalidShapeSim extends Sim:
    func export_release_state() -> Dictionary:
        return {"schema":4}

class NativeFaultStore extends Save:
    var fail_write := ""
    var fail_rename := ""
    func _write_file(path: String,text: String) -> bool:
        if path == fail_write:
            var file := FileAccess.open(path,FileAccess.WRITE)
            if file != null:
                file.store_string("partial-test-write")
                file.close()
            return false
        return super(path,text)
    func _rename_file(from: String,to: String) -> bool:
        if to == fail_rename: return false
        return super(from,to)

func check(value: bool,label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func old_text(model) -> String:
    return "\n  "+Save.new().encode(model.export_release_state())+" \n"

func copy_store(original: MemoryStore) -> MemoryStore:
    var result := MemoryStore.new()
    result.files = original.files.duplicate(true)
    return result

func live_slots(store: MemoryStore) -> Dictionary:
    var result := {}
    for path in [Save.PATH,Save.BACKUP,Save.ARCHIVE]:
        if store.files.has(path): result[path] = store.files[path]
    return result

func assert_read_only(store: MemoryStore,label: String,expected_restored := true) -> void:
    var before := live_slots(store)
    var sim := Sim.new()
    var result: Dictionary = store.load_into(sim)
    check(result.get("restored",false) == expected_restored,label+" readable status")
    check(store.blocked and not result.get("fresh",false),label+" not fresh and read-only")
    check(not store.save_from(sim).get("ok",false),label+" write blocked")
    check(live_slots(store) == before and store.writes.is_empty(),label+" all originals unchanged")
    check(not store.status.is_empty(),label+" clear visible status")

func migration_matrix() -> void:
    for version in [1,2,3]:
        for phase in ["ready","active","paused","complete"]:
            var legacy = [V1,V2,V3][version-1].new()
            if phase != "ready":
                check(legacy.accept_contract("first_shift" if version == 1 else "growth_1").ok,"old fixture starts")
                legacy.step(7.375)
                if phase == "paused": legacy.time_scale = 0.0
                if phase == "complete":
                    for _tick in 3000:
                        legacy.step(.283)
                        if legacy.finished: break
                    check(legacy.finished,"old fixture complete")
            var label := "schema%d %s" % [version,phase]
            var original := old_text(legacy)
            var store := MemoryStore.new()
            store.files[Save.PATH] = original
            var sim := Sim.new()
            var loaded: Dictionary = store.load_into(sim)
            check(loaded.get("ok",false) and loaded.get("migrated",false) and loaded.get("source_schema") == version,label+" load reports migration")
            check(not store.blocked,label+" migration remains writable")
            check(store.writes.is_empty() and live_slots(store) == {Save.PATH:original},label+" zero writes on load")
            check(sim.export_release_state().sim == legacy.export_release_state().sim,label+" exact old physics in memory")
            check(sim.export_release_state().campaign == legacy.export_release_state().campaign,label+" exact old campaign in memory")
            check(store.save_from(sim).get("ok",false),label+" first schema4 save succeeds")
            check(store.files.get(Save.BACKUP) == original and store.files.get(Save.ARCHIVE) == original,label+" exact old primary in backup and immutable archive")
            check(store.decode(store.files[Save.PATH]).data.schema == 4,label+" writes domain schema4")
            check(store.decode(store.files[Save.PATH]).pre_v4_sha256 == original.sha256_text(),label+" binds exact archive digest")
            for _tick in 7:
                sim.step(.037)
                check(store.save_from(sim).get("ok",false),label+" later autosave")
            check(store.files[Save.ARCHIVE] == original and not store.archive_replaced,label+" archive immutable across autosaves")
            var restored_store := copy_store(store)
            var restored := Sim.new()
            check(restored_store.load_into(restored).get("ok",false) and not restored_store.blocked,label+" linked schema4 reload writable")
            check(restored.export_release_state() == sim.export_release_state(),label+" exact latest model resumes")
            check(restored_store.save_from(restored).get("ok",false) and restored_store.files[Save.ARCHIVE] == original,label+" later launch preserves archive")

func protections() -> void:
    var legacy := V3.new()
    legacy.accept_contract("growth_1")
    legacy.step(5.375)
    var original := old_text(legacy)
    var other := old_text(V3.new())
    var current := Sim.new()
    check(current.import_release_state(legacy.export_release_state()).ok,"prepare actual schema4")
    var store := MemoryStore.new()
    var unlinked := store.encode(current.export_release_state())
    var linked := store.encode(current.export_release_state(),original.sha256_text())
    var corrupt_domain: Dictionary = legacy.export_release_state()
    corrupt_domain.campaign.wallet += 1
    var future: Dictionary = legacy.export_release_state()
    future.schema = 99
    var malformed_old: Dictionary = legacy.export_release_state()
    malformed_old.schema = 3.0
    var corruptions: Array = ["", "{broken", original.replace('"version":1','"version":2'), original.replace('"sha256":"','"sha256":"bad'), store.encode(corrupt_domain), store.encode(future), store.encode(malformed_old), unlinked, store.encode({"error":"prototype_no_save"}), "x".repeat(Save.MAX_TEXT+1)]
    for index in corruptions.size():
        var bad := MemoryStore.new()
        bad.files = {Save.PATH:original,Save.ARCHIVE:corruptions[index]}
        assert_read_only(bad,"bad archive %d" % index)
    var conflict := MemoryStore.new()
    conflict.files = {Save.PATH:original,Save.ARCHIVE:other}
    assert_read_only(conflict,"valid but conflicting archive")
    var replacement := MemoryStore.new()
    replacement.files = {Save.PATH:linked,Save.BACKUP:linked,Save.ARCHIVE:other}
    assert_read_only(replacement,"digest identifies replaced valid archive after both slots schema4")
    var missing := MemoryStore.new()
    missing.files = {Save.PATH:linked,Save.BACKUP:linked}
    assert_read_only(missing,"linked archive missing")
    var unproven := MemoryStore.new()
    unproven.files = {Save.PATH:unlinked,Save.BACKUP:unlinked,Save.ARCHIVE:original}
    assert_read_only(unproven,"unlinked schema4 cannot adopt unrelated archive")
    for bad in ["{broken",store.encode(future),store.encode({"error":"prototype_no_save"})]:
        var bad_primary := MemoryStore.new()
        bad_primary.files = {Save.PATH:bad,Save.BACKUP:original}
        assert_read_only(bad_primary,"backup fallback with protected primary")
        var bad_backup := MemoryStore.new()
        bad_backup.files = {Save.PATH:original,Save.BACKUP:bad}
        assert_read_only(bad_backup,"valid primary protected unknown backup")
    var both := MemoryStore.new()
    both.files = {Save.PATH:"broken",Save.BACKUP:"broken",Save.ARCHIVE:original}
    assert_read_only(both,"archive is not automatic rollback",false)
    var only := MemoryStore.new()
    only.files = {Save.ARCHIVE:original}
    assert_read_only(only,"archive only never means fresh",false)
    var backup_only := MemoryStore.new()
    backup_only.files = {Save.BACKUP:original}
    assert_read_only(backup_only,"missing primary plus valid backup")
    var matching := MemoryStore.new()
    matching.files = {Save.PATH:original,Save.ARCHIVE:original}
    var migrated := Sim.new()
    check(matching.load_into(migrated).get("ok",false) and not matching.blocked,"existing exact validated archive accepted")
    check(matching.save_from(migrated).ok and not matching.archive_replaced,"existing exact archive never rewritten")
    var mixed := MemoryStore.new()
    mixed.files = {Save.PATH:unlinked,Save.BACKUP:original}
    check(mixed.load_into(migrated).ok and not mixed.blocked,"schema4 primary with old backup selected safely")
    check(mixed.save_from(migrated).ok and mixed.files[Save.ARCHIVE] == original,"original backup selected without normalization")
    check(mixed.files[Save.BACKUP] == unlinked,"rolling backup retains actual previous primary")
    for slot in [Save.PATH,Save.BACKUP,Save.ARCHIVE]:
        var concurrent := copy_store(mixed)
        check(concurrent.load_into(migrated).ok and not concurrent.blocked,"concurrency fixture loaded")
        concurrent.files[slot] = other
        var before := live_slots(concurrent)
        check(concurrent.save_from(migrated).get("reason") == "concurrent_change" and concurrent.blocked,"changed slot blocks stale native writer")
        check(live_slots(concurrent) == before,"concurrent slot remains untouched")
    var source := MemoryStore.new()
    source.files[Save.PATH] = original
    check(source.save_from(current).get("reason") == "validation_required","unloaded existing progress cannot be overwritten")
    var fresh := MemoryStore.new()
    var fresh_sim := Sim.new()
    check(fresh.load_into(fresh_sim).fresh and fresh.save_from(fresh_sim).ok,"new installation writes valid schema4")
    check(not fresh.files.has(Save.ARCHIVE) and fresh.decode(fresh.files[Save.PATH]).pre_v4_sha256 == "","new installation does not invent legacy archive")
    for invalid in [InvalidExportSim.new(),InvalidShapeSim.new()]:
        var rejected := MemoryStore.new()
        check(rejected.save_from(invalid).get("reason") == "invalid_export","diagnostic or malformed export refused before encoding into storage")
        check(rejected.files.is_empty() and rejected.writes.is_empty(),"invalid exporter never writes or creates archive")

func validation_parity() -> void:
    var store := Save.new()
    var target := Sim.new()
    for version in [1,2,3,4]:
        var model = [V1,V2,V3,Sim][version-1].new()
        for phase in ["ready","active","paused","complete"]:
            if phase == "active":
                check(model.accept_contract("first_shift" if version == 1 else "growth_1").ok,"parity active fixture")
                model.step(8.375)
            elif phase == "paused": model.time_scale = 0.0
            elif phase == "complete":
                model.time_scale = 1.0
                for _tick in 3000:
                    model.step(.283)
                    if model.finished: break
                check(model.finished,"parity completion fixture")
            var valid: Dictionary = model.export_release_state()
            var cases: Array = [{"label":"valid","data":valid,"accept":true}]
            for schema in [99,3.0,"3",true]:
                var bad := valid.duplicate(true)
                bad.schema = schema
                cases.append({"label":"schema type","data":bad,"accept":false})
            var bad := valid.duplicate(true)
            bad.campaign.wallet += 1
            cases.append({"label":"unearned wallet","data":bad,"accept":false})
            bad = valid.duplicate(true)
            bad.sim.walk_speed = INF
            cases.append({"label":"nonfinite physics","data":bad,"accept":false})
            bad = valid.duplicate(true)
            bad.sim.workers[0].path = ["inbound","outside_graph"]
            cases.append({"label":"unknown physical route","data":bad,"accept":false})
            bad = valid.duplicate(true)
            bad.extra = "unexpected"
            cases.append({"label":"unknown field","data":bad,"accept":false})
            bad = valid.duplicate(true)
            bad.erase("campaign")
            cases.append({"label":"missing campaign","data":bad,"accept":false})
            if version == 4:
                bad = valid.duplicate(true)
                bad.hall.plan = "turbo"
                cases.append({"label":"unknown hall plan","data":bad,"accept":false})
            for item in cases:
                var original: PackedByteArray = var_to_bytes(item.data)
                var encoded := store.encode(item.data)
                var direct := store._valid_data_for_sim(item.data,target)
                var indirect := store._valid_for_sim(encoded,target)
                var label := "schema%d %s %s" % [version,phase,item.label]
                var importer := Sim.new()
                var imported: Dictionary = importer.import_release_state(item.data)
                check(direct == indirect and direct == item.accept,label+" direct/codec strict acceptance parity")
                check(direct == imported.get("ok",false),label+" shared acceptance/full importer parity")
                var preflight := Sim.new()
                var before_preflight: Dictionary = preflight.export_release_state()
                var accepted: Dictionary = preflight.validate_release_state(item.data)
                check(accepted == imported,label+" exact shared acceptance flags/errors match full importer")
                check(preflight.export_release_state() == before_preflight,label+" shared preflight never commits state")
                check(var_to_bytes(item.data) == original and store.encode(item.data) == encoded,label+" exact input and encoded output unchanged")
                if item.accept:
                    if version < 4: check(store._valid_data_for_sim(item.data,model) and store._valid_for_sim(encoded,model),label+" frozen strict importer fallback")
                    var a := Sim.new()
                    var b := Sim.new()
                    check(a.import_release_state(item.data).ok and b.import_release_state(store.decode(encoded).data).ok,label+" both import routes valid")
                    check(var_to_bytes(a.export_release_state()) == var_to_bytes(b.export_release_state()),label+" exact imported output parity")

func memory_failures() -> void:
    var original := old_text(V3.new())
    var older := old_text(V2.new())
    for failure in ["write","backup_write","archive_write","archive_rename","backup_rename","primary_rename"]:
        var store := MemoryStore.new()
        store.files = {Save.PATH:original,Save.BACKUP:older}
        var sim := Sim.new()
        check(store.load_into(sim).ok and not store.blocked,failure+" fixture load")
        match failure:
            "write": store.fail_write = Save.PATH+".tmp"
            "backup_write": store.fail_write = Save.BACKUP+".tmp"
            "archive_write": store.fail_write = Save.ARCHIVE+".tmp"
            "archive_rename": store.fail_rename = Save.ARCHIVE
            "backup_rename": store.fail_rename = Save.BACKUP
            "primary_rename": store.fail_rename = Save.PATH
        check(not store.save_from(sim).get("ok",false),failure+" reports failure")
        check(store.files[Save.PATH] == original,failure+" old primary readable and unchanged")
        check(store.files[Save.BACKUP] in [older,original],failure+" backup never partial")
        check(not store.files.has(Save.ARCHIVE) or store.files[Save.ARCHIVE] == original,failure+" archive absent or exact never partial")
        check(store.blocked and not store.save_from(sim).ok,failure+" no new writes after failed native transaction")
        var readable := copy_store(store)
        var reloaded := Sim.new()
        check(readable.load_into(reloaded).ok,failure+" old progress can still load after failure")
        check(reloaded.export_release_state().campaign == sim.export_release_state().campaign,failure+" no reset")

func native_clear() -> void:
    for path in [Save.PATH,Save.BACKUP,Save.ARCHIVE,Save.PATH+".tmp",Save.BACKUP+".tmp",Save.ARCHIVE+".tmp",Save.WRITER_LOCK]:
        if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func native_failures() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    var isolated := not sandbox.is_empty() and ProjectSettings.globalize_path("user://").begins_with(sandbox.trim_suffix("/")+"/")
    check(isolated,"native tests explicitly restricted to disposable HOME/XDG")
    if not isolated: return
    var original := old_text(V3.new())
    var older := old_text(V2.new())
    for failure in ["write","backup_write","archive_write","archive_rename","backup_rename","primary_rename","success"]:
        native_clear()
        var setup := Save.new()
        check(setup._write_file(Save.PATH,original) and setup._write_file(Save.BACKUP,older),failure+" create only synthetic native fixtures")
        var store := NativeFaultStore.new()
        var sim := Sim.new()
        check(store.load_into(sim).ok and not store.blocked,failure+" actual native load")
        match failure:
            "write": store.fail_write = Save.PATH+".tmp"
            "backup_write": store.fail_write = Save.BACKUP+".tmp"
            "archive_write": store.fail_write = Save.ARCHIVE+".tmp"
            "archive_rename": store.fail_rename = Save.ARCHIVE
            "backup_rename": store.fail_rename = Save.BACKUP
            "primary_rename": store.fail_rename = Save.PATH
        var result: Dictionary = store.save_from(sim)
        check(result.get("ok",false) == (failure == "success"),failure+" actual native transaction outcome")
        if failure != "success": check(FileAccess.get_file_as_string(Save.PATH) == original,failure+" actual native primary exact")
        check(FileAccess.get_file_as_string(Save.BACKUP) in [older,original],failure+" actual native backup intact")
        check(not FileAccess.file_exists(Save.ARCHIVE) or FileAccess.get_file_as_string(Save.ARCHIVE) == original,failure+" actual native archive intact")
        check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(Save.WRITER_LOCK)),failure+" native writer released")
        if failure == "success":
            for _tick in 12: check(store.save_from(sim).ok,"native later autosave")
            check(FileAccess.get_file_as_string(Save.ARCHIVE) == original,"actual native archive never rotates")
            var reload := Save.new()
            check(reload.load_into(sim).ok and not reload.blocked,"actual linked native reload")
            check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(Save.WRITER_LOCK)) == OK,"synthetic second native writer lock")
            check(reload.save_from(sim).get("reason") == "writer_unavailable","unresolved native writer lock fails closed")
            check(FileAccess.get_file_as_string(Save.ARCHIVE) == original,"native contention leaves archive unchanged")
    native_clear()
    var setup := Save.new()
    check(setup._write_file(Save.PATH,original),"native unreadable-slot fixture")
    for slot in [Save.BACKUP,Save.ARCHIVE]:
        check(setup._write_file(slot,"x".repeat(Save.MAX_TEXT+1)),"oversized protected slot fixture")
        var oversized := Save.new()
        var model := Sim.new()
        check(oversized.load_into(model).get("restored",false) and oversized.blocked,"oversized native protected slot still permits readable primary")
        check(FileAccess.get_file_as_string(Save.PATH) == original,"oversized native slot cannot reset primary")
        DirAccess.remove_absolute(ProjectSettings.globalize_path(slot))
    native_clear()

func _init() -> void:
    migration_matrix()
    protections()
    validation_parity()
    memory_failures()
    native_failures()
    print(JSON.stringify({"suite":"postcap_save_archive","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
