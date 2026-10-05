extends SceneTree
## Diagnostic latency only: full real save/export/import/I/O, disposable profile.
const Fixture = preload("res://tests/release/regional_hall_fixture.gd")
const Sim = preload("res://prototype/growth_sim.gd")
const Save = preload("res://prototype/release_save.gd")
var failures: Array[String] = []

class TimedStore extends Save:
    var commit_ms := 0.0
    var force_full_importer := false
    func _valid_data_for_sim(data: Dictionary,sim) -> bool:
        if not force_full_importer: return super(data,sim)
        var schema: Variant = data.get("schema")
        if not schema is int or schema < 1 or schema > 4: return false
        var candidate = sim.get_script().new()
        var imported: Dictionary = candidate.import_release_state(data)
        return imported.get("ok",false)
    func _write_native(text: String) -> Dictionary:
        var started := Time.get_ticks_usec()
        var result := super(text)
        commit_ms = float(Time.get_ticks_usec()-started)/1000.0
        return result

func phase_profile(store,sim) -> Dictionary:
    var started := Time.get_ticks_usec()
    var data: Dictionary = sim.export_release_state()
    var exported := Time.get_ticks_usec()
    var text: String = store.encode(data,store._archive_digest)
    var encoded := Time.get_ticks_usec()
    var decoded: Dictionary = store.decode(text)
    var decoded_at := Time.get_ticks_usec()
    var candidate = sim.get_script().new()
    var constructed := Time.get_ticks_usec()
    var result: Dictionary = candidate.import_release_state(decoded.data)
    var imported := Time.get_ticks_usec()
    require_ok(result.get("ok",false),"profiling strict import accepted")
    return {"export_ms":float(exported-started)/1000.0,"encode_ms":float(encoded-exported)/1000.0,"decode_ms":float(decoded_at-encoded)/1000.0,"candidate_construct_ms":float(constructed-decoded_at)/1000.0,"strict_import_ms":float(imported-constructed)/1000.0}


func require_ok(ok: bool,label: String) -> void:
    if not ok: failures.append(label)

func measured_save(store,sim) -> Dictionary:
    var before := Time.get_ticks_usec()
    var result: Dictionary = store.save_from(sim)
    return {"ok":result.get("ok",false),"reason":result.get("reason",""),"total_ms":float(Time.get_ticks_usec()-before)/1000.0,"text_bytes":FileAccess.get_file_as_bytes(Save.PATH).size(),"units_offered":sim.offered_units,"units_shipped":sim.shipped,"native_commit_ms":store.commit_ms}

func _init() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if sandbox.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(sandbox.trim_suffix("/")+"/"):
        print(JSON.stringify({"suite":"postcap_save_cost","failures":["explicit disposable native root required"]}))
        quit(1)
        return
    for path in [Save.PATH,Save.BACKUP,Save.ARCHIVE,Save.WRITER_LOCK]:
        if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
            print(JSON.stringify({"suite":"postcap_save_cost","failures":["benchmark requires a fresh disposable profile"]}))
            quit(1)
            return
    var input := Fixture.read_required()
    if not input.ok:
        print(JSON.stringify({"suite":"postcap_save_cost","failures":[str(input.error)]}))
        quit(1)
        return
    var fixture: Dictionary = input.data
    var store := TimedStore.new()
    var original := "\n  "+store.encode(fixture)+" \n"
    require_ok(store._valid_archive(original),"earned original passes frozen schema3 validator")
    require_ok(store._write_file(Save.PATH,original),"write synthetic fixture into disposable profile")
    var sim := Sim.new()
    require_ok(store.load_into(sim).get("ok",false) and not store.blocked,"load old checkpoint without writes")
    require_ok(sim.accept_contract("route_hub").get("ok",false),"earned funding hub starts")
    for _tick in 10000:
        sim.step(.283)
        if sim.finished: break
    require_ok(sim.finished,"funding hub completes")
    require_ok(sim.buy_hall().get("ok",false),"buy hall with earned funds")
    require_ok(sim.accept_contract("route_regional").get("ok",false),"regional starts")
    for _tick in 220: sim.step(.283)
    require_ok(sim.offered_units == 480 and not sim.finished,"active actual 480-unit state")
    var phases: Array = []
    for _sample in 5: phases.append(phase_profile(store,sim))
    var first := measured_save(store,sim)
    require_ok(first.ok,"first active480 migration save succeeds")
    require_ok(FileAccess.get_file_as_string(Save.ARCHIVE) == original,"first save archives exact old checkpoint")
    var samples: Array = []
    var times: Array[float] = []
    for _sample in 24:
        sim.step(5.0)
        var sample := measured_save(store,sim)
        samples.append(sample)
        times.append(sample.total_ms)
        require_ok(sample.ok,"later autosave succeeds")
    times.sort()
    var paired: Array = []
    var shared_times: Array[float] = []
    var importer_times: Array[float] = []
    for pair_index in 10:
        var row := {"order":"shared_first" if pair_index%2 == 0 else "importer_first"}
        for force_importer in ([false,true] if pair_index%2 == 0 else [true,false]):
            store.force_full_importer = force_importer
            var sample := measured_save(store,sim)
            require_ok(sample.ok,"paired save accepted")
            if force_importer:
                row.full_importer = sample
                importer_times.append(sample.total_ms)
            else:
                row.shared_acceptance = sample
                shared_times.append(sample.total_ms)
        paired.append(row)
    store.force_full_importer = false
    shared_times.sort()
    importer_times.sort()
    require_ok(FileAccess.get_file_as_string(Save.ARCHIVE) == original,"many real native autosaves preserve archive")
    var restored := Sim.new()
    var loader := Save.new()
    require_ok(loader.load_into(restored).get("ok",false) and not loader.blocked,"latest linked save reloads")
    require_ok(restored.export_release_state() == sim.export_release_state(),"exact latest active state reloads")
    print(JSON.stringify({"suite":"postcap_save_cost","engine":Engine.get_version_info().string,"scope":"headless cloud Linux native; synchronous export+encode+strict import validation+filesystem writes; no device/browser frame claim", "first_save_context":"stress case defers first migration save until active480; ordinary scene normally archives earlier on its first action", "paired_same_state":{"samples":paired,"shared_median_ms":shared_times[shared_times.size()/2],"importer_median_ms":importer_times[importer_times.size()/2],"scope":"alternating order, identical active480 state and same real store; both complete strict acceptance"},"phase_profile_samples":phases,"first_archive_creation":first,"later_5s_autosaves":{"count":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[ceili(times.size()*.95)-1],"max_ms":times[-1],"samples":samples},"failures":failures}))
    quit(0 if failures.is_empty() else 1)
