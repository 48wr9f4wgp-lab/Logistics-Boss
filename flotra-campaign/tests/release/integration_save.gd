extends SceneTree
const Main = preload("res://prototype/release_main.gd")
const Store = preload("res://prototype/release_save.gd")
var errors: Array = []
var checks := 0
class MemorySave extends Store:
    var current := ""
    var backup := ""
    var writes := 0
    func _read_pair() -> Dictionary: return {"ok":true,"primary":current,"backup":backup}
    func _write_native(text: String) -> Dictionary:
        backup = current
        current = text
        writes += 1
        return {"ok":true}
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: errors.append(label)
func run() -> void:
    var store := MemorySave.new()
    var first = Main.new()
    first.save_store = store
    root.add_child(first)
    first.set_process(false)
    await process_frame
    check(store.writes==0,"fresh intro does not overwrite storage")
    first._accept_contract("first_shift")
    check(store.writes==1,"accept saved immediately")
    first.sim.step(48.25)
    first._pause_trial(true)
    check(store.writes==2,"pause saved immediately")
    first._apply_layout("clear_aisle")
    check(store.writes==3,"pending layout saved immediately")
    var state: Dictionary = first.sim.export_release_state()
    var second = Main.new()
    second.save_store = store
    root.add_child(second)
    second.set_process(false)
    await process_frame
    check(second.sim.export_release_state()==state,"scene reload preserves in-flight cargo and pending layout exactly")
    check(not second.running,"reload starts safely paused")
    first.sim.step(200)
    second.sim.step(200)
    check(first.sim.export_release_state()==second.sim.export_release_state(),"resumed pending relocation remains deterministic")
    check(first.sim.check_invariants().ok and second.sim.check_invariants().ok,"both cargo ledgers conserved")
    first.queue_free()
    second.queue_free()
    await process_frame
    print(JSON.stringify({"suite":"scene_save_integration","checks":checks,"failures":errors}))
    quit(0 if errors.is_empty() else 1)
