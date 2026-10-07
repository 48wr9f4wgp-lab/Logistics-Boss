extends SceneTree
## Focused staged-save proof. All state is synthetic; real file checks require
## the same explicit disposable native profile as the existing save suite.
const Sim = preload("res://prototype/dispatch_sim.gd")
const Save = preload("res://prototype/dispatch_save.gd")
const OldSave = preload("res://prototype/release_save.gd")
const OldSim = preload("res://prototype/legacy_dispatch/growth_sim.gd")
var checks := 0
var failures: Array[String] = []

class MemoryStore extends Save:
    var writes: Array[String] = []
    var attempts := 0
    var encodes := 0
    var reads := 0
    var refusal := ""
    var oversize_envelope := false
    var during_encode: Callable
    var pair := {"ok":true,"source":"v5","primary":"","backup":"","primary_present":false,"backup_present":false}
    func _read_pair() -> Dictionary:
        reads += 1
        return pair.duplicate(true)
    func _write(text: String) -> Dictionary:
        attempts += 1
        if not refusal.is_empty(): return {"ok":false,"reason":refusal}
        writes.append(text)
        return {"ok":true}
    func _encode_bytes(bytes: PackedByteArray) -> String:
        encodes += 1
        if during_encode.is_valid():
            var callback := during_encode
            during_encode = Callable()
            callback.call()
        if oversize_envelope: return "x".repeat(MAX_TEXT+1)
        return super._encode_bytes(bytes)

class CountedSim extends Sim:
    static var constructors := 0
    func _init() -> void:
        super()
        constructors += 1

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func ready_store(sim) -> MemoryStore:
    var store := MemoryStore.new()
    check(store.load_into(sim).ok,"synthetic store starts readable")
    return store

func _initialize() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if sandbox.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(sandbox):
        push_error("Refusing staged-save tests without an explicitly disposable profile")
        quit(2)
        return
    immutable_active_capture()
    explicit_preemption()
    stale_encode_continuation()
    phase_failures()
    blocked_readonly_and_reload()
    raw_size_preflight()
    native_final_conflict()
    print(JSON.stringify({"suite":"dispatch_save_phases","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)

func immutable_active_capture() -> void:
    var sim := Sim.new()
    var store := ready_store(sim)
    check(sim.accept_contract("growth_1").ok,"active snapshot starts a job")
    for tick in 2000:
        sim.step(0.05)
        if not sim.pack_jobs.is_empty(): break
    check(not sim.pack_jobs.is_empty(),"snapshot includes in-flight processing")
    var captured := var_to_bytes(sim.export_release_state())
    var start := store.begin_autosave(sim)
    check(start.ok and start.pending and start.started and start.phase==1,"begin completes only capture/preflight/construction")
    var diagnostic := store.autosave_status()
    check(diagnostic.size()==5 and diagnostic.pending and diagnostic.phase==1 and diagnostic.generation==start.generation,"diagnostics expose scalar phase/generation only")
    diagnostic.phase = 999
    check(store.autosave_status().phase==1,"diagnostic result cannot mutate pending state")
    check(store.encodes==0 and store.attempts==0 and store.last_saved_generation==-1 and store.status=="自動保存中","capture never claims a commit")
    var again := store.begin_autosave(sim)
    check(again.ok and not again.started and again.generation==start.generation,"only one pending capture, no recapture")
    for phase in [2,3]:
        sim.step(0.05)
        var live_before := var_to_bytes(sim.export_release_state())
        var advanced := store.advance_autosave(int(start.generation))
        check(advanced.ok and advanced.pending and advanced.phase==phase,"one validation phase per advance")
        check(store.encodes==0 and store.attempts==0 and store.status=="自動保存中","validation alone is not saved")
        check(var_to_bytes(sim.export_release_state())==live_before,"validation phase does not change advancing live state")
    sim.step(0.05)
    var live_before := var_to_bytes(sim.export_release_state())
    var committed := store.advance_autosave(int(start.generation))
    check(committed.ok and not committed.pending and not store.has_pending_autosave(),"fourth phase commits once")
    check(store.encodes==1 and store.attempts==1 and store.writes.size()==1 and store.last_saved_generation==start.generation and store.status=="自動保存済み","saved status and generation only after actual write")
    check(var_to_bytes(store.decode(store.writes[0]).data)==captured,"committed bytes are the immutable capture")
    check(var_to_bytes(sim.export_release_state())==live_before and live_before!=captured,"live game advanced independently")
    check(store.reads==1,"no observed-state reread during phases")

func explicit_preemption() -> void:
    for completed_phases in [1,2,3]:
        var sim := Sim.new()
        var store := ready_store(sim)
        var old := store.begin_autosave(sim)
        for extra in completed_phases-1: store.advance_autosave()
        check(sim.set_preference("preferred_speed",4).ok,"new committed-action fixture")
        var latest := var_to_bytes(sim.export_release_state())
        check(store.save_from(sim).ok,"synchronous current-state save preempts phase%d"%completed_phases)
        check(store.autosave_status().last_superseded_generation==old.generation,"diagnostics identify superseded capture")
        check(store.writes.size()==1 and var_to_bytes(store.decode(store.writes[0]).data)==latest,"older capture never overwrites explicit latest state")
        var saved_generation := store.last_saved_generation
        var status := store.status
        check(store.advance_autosave(int(old.generation)).reason=="superseded" and store.flush_autosave(int(old.generation)).reason=="superseded","stale phase/flush tokens are rejected")
        check(store.writes.size()==1 and store.status==status and store.last_saved_generation==saved_generation,"stale continuations cannot change saved status")
        var newer := store.begin_autosave(sim)
        check(newer.started and store.advance_autosave(int(old.generation)).reason=="superseded","stale generation cannot advance a newer pending capture")
        check(store._pending.phase==1 and store.status=="自動保存中","new pending stage/status untouched by old token")

    var invalid := Sim.new()
    var store := ready_store(invalid)
    var old := store.begin_autosave(invalid)
    store.advance_autosave()
    store.advance_autosave()
    invalid.campaign_wallet += 1
    check(store.save_from(invalid).get("reason")=="invalid_state" and store.blocked,"latest explicit invalid state stops safely")
    check(not store.has_pending_autosave() and store.attempts==0 and store.advance_autosave(int(old.generation)).reason=="superseded","failed explicit save never revives an older validated capture")

func stale_encode_continuation() -> void:
    var sim := Sim.new()
    var store := ready_store(sim)
    var old := store.begin_autosave(sim)
    store.advance_autosave()
    store.advance_autosave()
    store.during_encode = func():
        sim.set_preference("preferred_speed",4)
        check(store.save_from(sim).ok,"new synchronous capture during an old encode")
    check(store.advance_autosave(int(old.generation)).reason=="superseded","generation rechecked after expensive encode")
    check(store.writes.size()==1 and store.decode(store.writes[0]).data.experience.preferences.preferred_speed==4,"only the newer encoded state writes")
    check(store.status=="自動保存済み" and store.last_saved_generation>int(old.generation),"old continuation cannot replace new success status")
    store = ready_store(sim)
    store.begin_autosave(sim)
    store.advance_autosave()
    store.advance_autosave()
    store.during_encode = func():
        store.blocked = true
        store.status = "保護停止の合成テスト"
    check(store.advance_autosave().get("reason")=="blocked","blocked state rechecked after encode")
    check(store.attempts==0 and not store.has_pending_autosave() and store.status=="保護停止の合成テスト","late blocked state discards pending without write/status overwrite")

func phase_failures() -> void:
    var sim := Sim.new()
    var store := ready_store(sim)
    sim.comparison = {"not_finite":INF}
    check(store.begin_autosave(sim).pending,"unsafe shape captured before shape phase")
    var before := var_to_bytes(sim.export_release_state())
    check(store.advance_autosave().get("reason")=="invalid_state" and store.blocked,"shape safety failure stops")
    check(store.encodes==0 and store.attempts==0 and not store.has_pending_autosave() and var_to_bytes(sim.export_release_state())==before,"shape failure has no encode/write/live mutation")
    sim = Sim.new()
    store = ready_store(sim)
    sim.campaign_wallet += 1
    store.begin_autosave(sim)
    check(store.advance_autosave().pending,"well-typed invalid wallet reaches domain phase")
    check(store.advance_autosave().get("reason")=="invalid_state" and store.blocked and store.encodes==0 and store.attempts==0,"full wallet validation still precedes encoding")
    for reason in ["writer_unavailable","legacy_writer_unavailable","concurrent_change","write_uncertain","storage_write_failed","native_writer_unavailable"]:
        sim = Sim.new()
        store = ready_store(sim)
        store.refusal = reason
        store.begin_autosave(sim)
        var failed := store.flush_autosave()
        check(not failed.ok and failed.reason==reason and not store.has_pending_autosave(),"write failure clears pending: "+reason)
        check(store.blocked==(reason in ["writer_unavailable","legacy_writer_unavailable","concurrent_change","write_uncertain"]),"error blocking semantics unchanged: "+reason)
        check(store.attempts==1 and store.writes.is_empty() and store.last_saved_generation==-1 and store.status!="自動保存済み","failure never claims commit: "+reason)
    sim = Sim.new()
    store = ready_store(sim)
    store.oversize_envelope = true
    store.begin_autosave(sim)
    check(store.flush_autosave().reason=="too_large" and not store.blocked and store.attempts==0 and not store.has_pending_autosave(),"envelope ceiling still rejects before write")

func blocked_readonly_and_reload() -> void:
    var sim := Sim.new()
    var store := MemoryStore.new()
    store.pair.primary = "{broken"
    store.pair.primary_present = true
    store.pair.backup = Save.new().encode(sim.export_release_state())
    store.pair.backup_present = true
    check(store.load_into(sim).get("backup",false) and store.blocked,"backup remains read-only")
    var status := store.status
    check(not store.begin_autosave(sim).ok and not store.flush_autosave().ok and not store.save_from(sim).ok,"all save paths respect blocked backup")
    check(store.attempts==0 and store.status==status and not store.has_pending_autosave(),"readonly protection status preserved")
    sim = Sim.new()
    store = ready_store(sim)
    var pending := store.begin_autosave(sim)
    var newer := Sim.new()
    newer.set_preference("preferred_speed",4)
    store.pair.primary = Save.new().encode(newer.export_release_state())
    store.pair.primary_present = true
    check(store.load_into(sim).ok and sim.preferences.preferred_speed==4,"explicit reload adopts the new source")
    check(store.advance_autosave(int(pending.generation)).reason=="superseded" and store.attempts==0,"explicit reload cancels prior snapshot before reading")

func raw_size_preflight() -> void:
    var sim := CountedSim.new()
    var store := ready_store(sim)
    var chunk := "倉".repeat(333)+"a"
    var chunks: Array = []
    for index in 2050: chunks.append(chunk)
    sim.comparison = {"oversize":chunks}
    check(var_to_bytes(sim.export_release_state()).size()>Save.MAX_PAYLOAD_BYTES,"raw overflow fixture")
    var constructors := CountedSim.constructors
    var rejected := store.begin_autosave(sim)
    check(rejected.reason=="too_large" and rejected.started and not rejected.pending,"preflight failure still counts as a cadence attempt")
    check(CountedSim.constructors==constructors and store.encodes==0 and store.attempts==0 and not store.blocked,"raw overflow before candidate/encoding/write")

func put(path: String, text: String) -> void:
    var file := FileAccess.open(path,FileAccess.WRITE)
    check(file!=null,"disposable source fixture opens")
    if file==null: return
    file.store_string(text)
    file.close()

func native_final_conflict() -> void:
    for path in [Save.PATH,Save.BACKUP,Save.OLD_PATH,Save.OLD_BACKUP,Save.PATH+".tmp",Save.BACKUP+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var original := OldSave.new().encode(OldSim.new().export_release_state())
    put(Save.OLD_PATH,original)
    var store := Save.new()
    var sim := Sim.new()
    check(store.load_into(sim).get("migrated",false),"staged migration reads old source")
    store.begin_autosave(sim)
    store.advance_autosave()
    store.advance_autosave()
    put(Save.OLD_PATH,"external change after capture")
    check(store.advance_autosave().get("reason")=="concurrent_change" and store.blocked,"final transaction rechecks observed source")
    check(not FileAccess.file_exists(Save.PATH) and FileAccess.get_file_as_string(Save.OLD_PATH)=="external change after capture","stale staged snapshot cannot replace concurrent source")
