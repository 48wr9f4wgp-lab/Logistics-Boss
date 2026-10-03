extends SceneTree
const Sim = preload("res://prototype/release_sim.gd")
const Save = preload("res://prototype/release_save.gd")
var failures: Array = []
var checks := 0
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok: failures.append(label)
func rejects(data: Dictionary, label: String) -> void:
    var target := Sim.new()
    target.accept_contract("first_shift")
    target.step(5.0)
    var before: Dictionary = target.export_release_state()
    var result: Dictionary = target.import_release_state(data)
    check(not result.get("ok",false),label+" rejected")
    check(target.export_release_state() == before,label+" leaves live state unchanged")
func _init() -> void:
    var sim := Sim.new()
    var initial: Dictionary = sim.export_release_state()
    var malformed := initial.duplicate(true)
    malformed.schema = 2
    rejects(malformed,"future schema")
    malformed = initial.duplicate(true)
    malformed.campaign.upgrades = [42]
    rejects(malformed,"non-string upgrade")
    malformed = initial.duplicate(true)
    malformed.campaign.last_result = {"earnings":[]}
    rejects(malformed,"malformed last_result")
    malformed = initial.duplicate(true)
    malformed.sim.workload_id = "unknown_mix"
    rejects(malformed,"unknown ready workload")
    check(sim.accept_contract("first_shift").ok,"accept first contract")
    for time in [0.05,4.0,12.0,30.0,55.0]:
        sim.step(time)
        var save := Save.new()
        var encoded: String = save.encode(sim.export_release_state())
        var resumed := Sim.new()
        var result: Dictionary = resumed.import_release_state(save.decode(encoded).data)
        check(result.ok,"active import at "+str(sim.sim_time)+": "+str(result))
        check(resumed.export_release_state() == sim.export_release_state(),"active roundtrip exact at "+str(sim.sim_time))
        sim.step(.65)
        resumed.step(.65)
        check(resumed.export_release_state() == sim.export_release_state(),"resumed same future at "+str(sim.sim_time))
    malformed = sim.export_release_state()
    malformed.campaign.completed_count = 1
    malformed.campaign.results = {"unknown_contract":{"best_time":1.0,"best_medal":"gold","attempts":1,"earned":0}}
    rejects(malformed,"unknown completed contract")
    malformed = sim.export_release_state()
    malformed.sim._move_remaining = 1.0
    malformed.sim._move_duration = 1.0
    malformed.sim.pending_layout_id = ""
    rejects(malformed,"movement without destination/history")
    malformed = sim.export_release_state()
    malformed.sim.pending_layout_id = "clear_aisle"
    malformed.sim.relocation_history = []
    rejects(malformed,"pending movement without history")
    malformed = sim.export_release_state()
    for worker in malformed.sim.workers:
        if worker.phase in ["to_source","to_target"]:
            worker.path = ["inbound","bulk_far"]
            worker.path_index = 0
            break
    rejects(malformed,"disconnected worker path")
    malformed = sim.export_release_state()
    malformed.sim.workers[0].path = ["outside_graph"]
    rejects(malformed,"invalid worker path")
    malformed = sim.export_release_state()
    malformed.sim.bulk_bays[0].reserved_by = 100
    rejects(malformed,"invalid bay owner")
    malformed = sim.export_release_state()
    malformed.sim._edges.values()[0].owners = [100]
    rejects(malformed,"invalid edge owner")
    print(JSON.stringify({"suite":"independent_domain_save","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
