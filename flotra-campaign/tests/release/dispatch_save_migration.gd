extends SceneTree
## Synthetic fixtures; native I/O refuses to run outside an explicit temp root.
const Sim = preload("res://prototype/dispatch_sim.gd")
const Save = preload("res://prototype/dispatch_save.gd")
const OldSave = preload("res://prototype/release_save.gd")
const V1 = preload("res://prototype/legacy_dispatch/release_sim.gd")
const V2 = preload("res://prototype/legacy_dispatch/growth_v2_sim.gd")
const V3 = preload("res://prototype/legacy_dispatch/growth_sim.gd")
var failures: Array[String] = []
var checks := 0

class FailureStore extends Save:
    var fail_path := ""
    var encodes := 0
    func _atomic_replace(path: String, text: String) -> Dictionary:
        if path == fail_path: return {"ok":false,"reason":"injected_write_failure"}
        return super._atomic_replace(path,text)
    func _encode_bytes(bytes: PackedByteArray) -> String:
        encodes += 1
        return super._encode_bytes(bytes)

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func _initialize() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if sandbox.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(sandbox):
        push_error("Refusing save tests outside an explicitly disposable profile")
        quit(2)
        return
    for version in [1,2,3]:
        migration_case(version)
    new_feature_roundtrip()
    rejection_and_failures()
    size_boundary()
    print(JSON.stringify({"suite":"dispatch_save_migration","checks":checks,"failures":failures,"profile":"explicit_disposable_only"}))
    quit(0 if failures.is_empty() else 1)

func reset_slots() -> void:
    for path in [Save.PATH,Save.BACKUP,Save.OLD_PATH,Save.OLD_BACKUP,Save.PATH+".tmp",Save.BACKUP+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    if DirAccess.dir_exists_absolute(Save.WRITER_LOCK): DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.WRITER_LOCK))

func put(path: String, text: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    check(file != null,"fixture file opens")
    if file == null: return
    file.store_string(text)
    file.close()

func slots() -> Dictionary:
    var result := {}
    for path in [Save.PATH,Save.BACKUP,Save.OLD_PATH,Save.OLD_BACKUP]:
        result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
    return result

func finish(sim, id: String) -> void:
    check(sim.accept_contract(id).ok,"fixture accepts "+id)
    for tick in 10000:
        if sim.finished: break
        sim.step(0.25)
    check(sim.finished and sim.check_invariants().ok,"fixture conserves completed cargo "+id)

func same_old_fields(old: Dictionary, new: Dictionary, label: String) -> void:
    for key in old:
        if key != "schema": check(var_to_bytes(old[key]) == var_to_bytes(new[key]), label+" exact "+str(key))
    check(new.schema==5 and new.dispatch.dispatch_window==6 and "pick_dispatch_board" not in new.campaign.upgrades,label+" default6, unpurchased")

func migration_case(version: int) -> void:
    reset_slots()
    var old = V1.new() if version==1 else (V2.new() if version==2 else V3.new())
    var codec := OldSave.new()
    var idle: Dictionary = old.export_release_state()
    var old_backup := codec.encode(idle)
    finish(old,"first_shift" if version==1 else "growth_1")
    check(old.buy_upgrade("worker_4" if version==1 else "crew_4").ok,"old purchased equipment")
    check(old.accept_contract("small_orders" if version==1 else "growth_2").ok,"old second job")
    for tick in 4000:
        old.step(0.05)
        if not old.pack_jobs.is_empty() and old.workers.any(func(w):return not w.cargo_ids.is_empty()): break
    check(not old.pack_jobs.is_empty(),"old fixture has processing timer")
    var source: Dictionary = old.export_release_state()
    if version == 3:
        # Existing loaders may normalize this valid older label. Migration and
        # every subsequent v5 load must instead retain the historical bytes.
        source.campaign.results.growth_1.best_time = 45.0000001
        source.campaign.results.growth_1.best_medal = "silver"
    var source_bytes := var_to_bytes(source)
    var old_primary := codec.encode(source)
    put(Save.OLD_PATH,old_primary)
    put(Save.OLD_BACKUP,old_backup)
    var store := Save.new()
    var migrated := Sim.new()
    var loaded := store.load_into(migrated)
    check(loaded.ok and loaded.get("migrated",false) and not store.blocked,"schema%d read migration"%version)
    same_old_fields(source,migrated.export_release_state(),"schema%d"%version)
    check(var_to_bytes(source)==source_bytes,"schema%d source argument immutable"%version)
    check(not FileAccess.file_exists(Save.PATH),"read migration creates no v5 save")
    check(store.save_from(migrated).ok,"schema%d first dedicated write"%version)
    check(FileAccess.get_file_as_string(Save.OLD_PATH)==old_primary and FileAccess.get_file_as_string(Save.OLD_BACKUP)==old_backup,"old primary/backup byte-exact retained")
    check(not FileAccess.file_exists(Save.BACKUP),"first v5 write invents no backup")
    var first_v5 := FileAccess.get_file_as_string(Save.PATH)
    check(JSON.parse_string(first_v5).version==5,"dedicated v5 envelope")
    var restored := Sim.new()
    var again := Save.new()
    check(again.load_into(restored).ok and not again.blocked,"v5 reload writable")
    check(var_to_bytes(restored.export_release_state())==var_to_bytes(migrated.export_release_state()),"v5 exact resumed domain")
    for tick in 60:
        old.step(0.05)
        restored.step(0.05)
    check(var_to_bytes(old.export_release_state().sim)==var_to_bytes(restored.export_release_state().sim),"legacy in-flight deterministic continuation")
    check(again.save_from(restored).ok,"v5 next checkpoint")
    check(FileAccess.get_file_as_string(Save.BACKUP)==first_v5,"backup is prior v5 only")
    check(FileAccess.get_file_as_string(Save.OLD_PATH)==old_primary and FileAccess.get_file_as_string(Save.OLD_BACKUP)==old_backup,"old source remains exact after later writes")

func new_feature_roundtrip() -> void:
    reset_slots()
    var sim := Sim.new()
    for id in ["growth_1","growth_2","growth_3","growth_4"]: finish(sim,id)
    var premature: Dictionary = sim.export_release_state()
    premature.campaign.upgrades.append("pick_dispatch_board")
    premature.campaign.wallet -= 300
    reject_domain(premature,"board missing equipment prerequisites despite correct debit")
    for id in ["robot_2","auto_pack","crew_6","robot_4","pick_dispatch_board"]:
        while sim.campaign_wallet < int(sim._upgrade(id).cost): finish(sim,"growth_1")
        check(sim.buy_upgrade(id).ok,"legitimate purchase "+id)
    check(sim.dispatch_window==6,"board purchase keeps six")
    check(sim.set_dispatch_window(12).ok,"choose twelve between jobs")
    check(sim.accept_contract("route_parcel_120").ok,"start new job")
    var saw_twelve := false
    for tick in 10000:
        sim.step(0.05)
        if sim.dispatch_state().wip>6 and not sim.pack_jobs.is_empty():
            saw_twelve = true
            break
        if sim.finished: break
    check(saw_twelve,"real twelve-window in-flight fixture")
    var truncated_window: Dictionary = sim.export_release_state()
    truncated_window.dispatch.dispatch_window = 6
    reject_domain(truncated_window,"cannot reduce active admission to fit an inconsistent save")
    var before := var_to_bytes(sim.export_release_state())
    var store := Save.new()
    check(store.load_into(Sim.new()).fresh,"fresh v5 target")
    check(store.save_from(sim).ok,"owned12 active state saves")
    var resumed := Sim.new()
    check(Save.new().load_into(resumed).ok,"owned12 reloads")
    check(var_to_bytes(resumed.export_release_state())==before,"owned12 cargo/reservations/timers exact")
    check(not resumed.set_dispatch_window(6).ok,"resume remains locked while active")
    for tick in 12000:
        if sim.finished: break
        sim.step(0.05)
        resumed.step(0.05)
    check(sim.finished and resumed.finished,"new job resumed to completion")
    check(var_to_bytes(sim.export_release_state())==var_to_bytes(resumed.export_release_state()),"new job result and payment exact")
    check(store.save_from(sim).ok,"new job history saves")
    var completed := Sim.new()
    check(Save.new().load_into(completed).ok,"new job history reloads")
    check(completed.set_dispatch_window(6).ok,"free return to six after reload")
    for field in ["wallet","results","upgrades"]:
        check(completed.export_release_state().campaign[field]==sim.export_release_state().campaign[field],"free switch preserves "+field)
    var forged: Dictionary = sim.export_release_state()
    forged.dispatch.dispatch_window = 7
    reject_domain(forged,"invalid window")
    forged = sim.export_release_state()
    forged.campaign.wallet += 1
    reject_domain(forged,"new purchase/reward cash mismatch")
    forged = sim.export_release_state()
    forged.campaign.upgrades.append("pick_dispatch_board")
    reject_domain(forged,"duplicate board")

func reject_domain(data: Dictionary, label: String) -> void:
    var target := Sim.new()
    var before := var_to_bytes(target.export_release_state())
    var source_before := var_to_bytes(data)
    check(not target.import_release_state(data).ok,label+" rejected")
    check(var_to_bytes(target.export_release_state())==before and var_to_bytes(data)==source_before,label+" transactional rejection")

func rejection_and_failures() -> void:
    reset_slots()
    var old: Dictionary = V3.new().export_release_state()
    var original := OldSave.new().encode(old)
    put(Save.OLD_PATH,original)
    put(Save.OLD_BACKUP,original)
    var sim := Sim.new()
    var failed := FailureStore.new()
    check(failed.load_into(sim).ok,"failed-first-write fixture loads")
    var before := slots()
    check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(Save.WRITER_LOCK))==OK,"synthetic native writer lock")
    check(failed.save_from(sim).get("reason")=="native_writer_unavailable" and slots()==before,"native concurrent/interrupted writer fails closed")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.WRITER_LOCK))
    failed.fail_path = Save.PATH
    check(not failed.save_from(sim).ok and slots()==before,"failed first write leaves all source bytes and new slots untouched")
    failed.fail_path = ""
    check(failed.save_from(sim).ok,"first-write retry works")
    before = slots()
    failed.fail_path = Save.BACKUP
    sim.set_preference("preferred_speed",4)
    check(not failed.save_from(sim).ok and slots()==before,"backup failure cannot replace primary")
    failed.fail_path = Save.PATH
    check(not failed.save_from(sim).ok,"primary failure after backup rotation")
    check(slots()[Save.PATH]==before[Save.PATH] and slots()[Save.BACKUP]==before[Save.PATH],"primary failure retains complete recoverable checkpoint")
    failed.fail_path = ""
    check(failed.save_from(sim).ok,"retry after own backup rotation works")
    check(slots()[Save.OLD_PATH]==original and slots()[Save.OLD_BACKUP]==original,"all failures leave legacy slots exact")

    for version in [4,99]:
        reset_slots()
        var unknown := old.duplicate(true)
        unknown.schema = version
        put(Save.OLD_PATH,OldSave.new().encode(unknown))
        put(Save.OLD_BACKUP,original)
        before = slots()
        var blocked_store := Save.new()
        var blocked_sim := Sim.new()
        var result := blocked_store.load_into(blocked_sim)
        check(not result.ok and result.reason=="unsupported_schema" and blocked_store.blocked,"unknown old schema safe stop")
        check(not blocked_store.save_from(blocked_sim).ok and slots()==before,"unknown old schema never overwritten or reinterpreted")
    reset_slots()
    put(Save.OLD_PATH,original)
    put(Save.PATH,"{broken v5")
    before = slots()
    var invalid := Save.new()
    check(not invalid.load_into(Sim.new()).ok and invalid.blocked,"broken v5 never falls back to old campaign")
    check(slots()==before,"broken v5 retained")
    put(Save.BACKUP,Save.new().encode(Sim.new().export_release_state()))
    var recovery := Save.new()
    check(recovery.load_into(Sim.new()).get("backup",false) and recovery.blocked,"same-v5 backup recovery read-only")

    var unowned: Dictionary = Sim.new().export_release_state()
    unowned.dispatch.dispatch_window = 12
    reject_domain(unowned,"unowned twelve")
    for version in [4,99]:
        var unknown := old.duplicate(true)
        unknown.schema = version
        reject_domain(unknown,"unknown domain schema")

func padded(seed: Dictionary, target: int) -> Dictionary:
    var state := seed.duplicate(true)
    var chunks: Array = []
    state.sim.comparison = {"size_test":chunks}
    var remaining := target-var_to_bytes(state).size()
    var chunk := "倉".repeat(333)+"a"
    var stride := var_to_bytes(chunk).size()
    while remaining >= stride:
        chunks.append(chunk)
        remaining -= stride
    if remaining > 0 and remaining < 8:
        chunks.pop_back()
        remaining += stride
    if remaining > 0: chunks.append("x".repeat(remaining-8))
    check(var_to_bytes(state).size()==target,"exact size fixture")
    return state

func size_boundary() -> void:
    reset_slots()
    var sim := Sim.new()
    var store := FailureStore.new()
    check(store.load_into(sim).fresh,"size fixture fresh")
    check(store.save_from(sim).ok,"small baseline checkpoint")
    check(Save.MAX_PAYLOAD_BYTES==2000000,"released raw byte ceiling retained")
    check(sim.import_release_state(padded(sim.export_release_state(),2000000)).ok,"exact-ceiling valid domain")
    check(store.save_from(sim).ok,"exact 2MB saves")
    var restored := Sim.new()
    check(Save.new().load_into(restored).ok,"exact 2MB reloads")
    check(var_to_bytes(restored.export_release_state())==var_to_bytes(sim.export_release_state()),"exact-ceiling state preserved")
    check(sim.import_release_state(padded(Sim.new().export_release_state(),2000004)).ok,"oversize fixture domain-valid")
    var before := slots()
    var encodes_before := store.encodes
    put(Save.PATH+".tmp","temporary sentinel")
    check(store.save_from(sim).get("reason")=="too_large","2MB+4 rejected")
    check(store.encodes==encodes_before and slots()==before,"oversize before encoding or slot writes")
    check(FileAccess.get_file_as_string(Save.PATH+".tmp")=="temporary sentinel","oversize leaves temp untouched")
    check(not store.blocked and store.status.contains("未保存の進行が失われます"),"oversize warning without corrupting usable storage")
