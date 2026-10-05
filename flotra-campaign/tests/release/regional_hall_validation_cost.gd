extends SceneTree
# Read-only phase profiling on synthetic in-memory checkpoints. No save paths.
const Fixture = preload("res://tests/release/regional_hall_fixture.gd")
const Sim = preload("res://prototype/growth_sim.gd")
class Profiled extends "res://prototype/growth_sim.gd":
    static var phases: Dictionary = {}
    func _record(key: String, start: int) -> void:
        var row: Dictionary=phases.get(key,{"calls":0,"us":0})
        row.calls+=1
        row.us+=Time.get_ticks_usec()-start
        phases[key]=row
    func _build_edges() -> void:
        var start:=Time.get_ticks_usec()
        super._build_edges()
        _record("build_edges_inclusive",start)
    func _bind_live_indexes(prepare_routes: bool = true) -> void:
        var start:=Time.get_ticks_usec()
        super._bind_live_indexes(prepare_routes)
        _record("bind_live_indexes",start)
    func _load_release_unchecked(data: Dictionary, prepare_routes: bool = true) -> void:
        var start:=Time.get_ticks_usec()
        super._load_release_unchecked(data,prepare_routes)
        _record("load_inclusive",start)
    func _validate_save_shape(data: Dictionary) -> Dictionary:
        var start:=Time.get_ticks_usec()
        var result:=super._validate_save_shape(data)
        _record("shape",start)
        return result
    func _validate_loaded_release() -> Dictionary:
        var start:=Time.get_ticks_usec()
        var result:=super._validate_loaded_release()
        _record("physical_inclusive",start)
        return result

func finish(sim) -> void:
    while not sim.finished and sim.sim_time<3000: sim.step(1)
func _initialize() -> void:
    var input := Fixture.read_required()
    if not input.ok:
        push_error(str(input.error))
        quit(1)
        return
    var fixture: Dictionary=input.data
    var seed=Sim.new()
    if not seed.import_release_state(fixture).ok: quit(1); return
    seed.accept_contract("route_hub")
    finish(seed)
    var unowned: Dictionary=seed.export_release_state()
    if not seed.buy_hall().ok: quit(1); return
    var owned: Dictionary=seed.export_release_state()
    var samples: Array=[]
    for plan in ["unowned","storage","express"]:
        var source=Sim.new()
        source.import_release_state(unowned if plan=="unowned" else owned)
        if plan!="unowned": source.set_hall_plan(plan)
        source.accept_contract("route_regional")
        source.step(180)
        var raw: Dictionary=source.export_release_state()
        for n in 5:
            var target=Profiled.new()
            Profiled.phases={}
            var start:=Time.get_ticks_usec()
            var result: Dictionary=target.import_release_state(raw)
            var total:=Time.get_ticks_usec()-start
            if not result.ok or target.export_release_state()!=raw: quit(2); return
            var import_phases: Dictionary=Profiled.phases.duplicate(true)
            var pure=Profiled.new()
            var before: Dictionary=pure.export_release_state()
            Profiled.phases={}
            start=Time.get_ticks_usec()
            var preflight: Dictionary=pure.validate_release_state(raw)
            var validation_only:=Time.get_ticks_usec()-start
            if preflight!=result or pure.export_release_state()!=before: quit(3); return
            samples.append({"plan":plan,"sample":n,"total_ms":total/1000.0,"phases":import_phases,"validation_only_ms":validation_only/1000.0,"validation_only_phases":Profiled.phases.duplicate(true)})
    print(JSON.stringify({"suite":"regional_hall_validation_cost","domain_sha256":FileAccess.get_sha256("res://prototype/growth_sim.gd"),"samples":samples}))
    quit()
