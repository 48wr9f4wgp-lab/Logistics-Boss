extends SceneTree
const Sim = preload("res://prototype/release_sim.gd")
func _initialize() -> void:
    var sim = Sim.new()
    print(sim.release_state())
    print(sim.accept_contract("first_shift"))
    for second in 1200:
        sim.step(1)
        if not sim.check_invariants().ok:
            push_error(str(sim.check_invariants()))
            quit(1)
            return
        if sim.finished:
            break
    print(sim.release_state())
    var loaded = Sim.new()
    var saved: Dictionary = bytes_to_var(var_to_bytes(sim.export_release_state()))
    print("SAFE ",loaded._safe_variant(saved)," KEYS ",loaded._keys_and_types(saved,{"schema":1,"campaign":{},"sim":{}}))
    for key in saved.sim:
        if not loaded._safe_variant(saved.sim[key]):
            print("BADFIELD ",key)
    var result: Dictionary = loaded.import_release_state(saved)
    print(result)
    quit(0 if result.ok and sim.finished else 1)
