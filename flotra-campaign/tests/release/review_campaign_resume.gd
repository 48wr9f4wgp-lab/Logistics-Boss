extends SceneTree
const Sim = preload("res://prototype/release_sim.gd")
const Save = preload("res://prototype/release_save.gd")
var checks := 0
var failures: Array = []
var timings: Array = []
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok and failures.size()<25: failures.append(label)
func _init() -> void:
    var sim := Sim.new()
    var store := Save.new()
    var layouts := ["clear_aisle","compact","pack_annex","split","compact","clear_aisle"]
    var saw_relocation := false
    for index in Sim.CONTRACTS.size():
        var definition: Dictionary = Sim.CONTRACTS[index]
        var id := str(definition.id)
        check(sim.accept_contract(id).ok,"accept "+id)
        var expected_state: Dictionary = sim.export_release_state()
        check(not sim.accept_contract(id).ok and sim.export_release_state() == expected_state,"duplicate accept preserves cargo "+id)
        var mutated := false
        var next_resume := 11.0
        while sim.campaign_status == "running" and sim.sim_time < 3000.0:
            sim.step(.25)
            var invariant: Dictionary = sim.check_invariants()
            check(invariant.ok,"cargo invariant "+id+": "+str(invariant))
            if not mutated and sim.sim_time >= 20.0:
                var prior_count: int = sim.cargo.size()
                sim.apply_layout(layouts[index])
                check(sim.cargo.size() == prior_count,"layout preserves ledger "+id)
                mutated = true
            if sim.sim_time >= next_resume:
                next_resume += 11.0
                var before: Dictionary = sim.export_release_state()
                var encoded: String = store.encode(before)
                var resumed := Sim.new()
                var imported: Dictionary = resumed.import_release_state(store.decode(encoded).data)
                check(imported.ok,"resume valid "+id+" at "+str(sim.sim_time)+": "+str(imported))
                if imported.ok:
                    check(resumed.export_release_state() == before,"resume exact "+id)
                    sim = resumed
            saw_relocation = saw_relocation or sim._move_remaining > 0.0
        check(sim.campaign_status != "running","reachable completion "+id)
        check(sim.shipped == int(definition.manifest_quota)*6,"all accepted cargo shipped "+id)
        check(sim.manifest_cursor == int(definition.manifest_quota),"finite demand "+id)
        timings.append({"contract":id,"seconds":sim.sim_time,"shipped":sim.shipped,"wallet":sim.campaign_wallet})
    check(saw_relocation,"real relocation phase covered")
    check(sim.campaign_status == "campaign_complete" and sim.completed_count == 6,"campaign reaches clear ending")
    var wallet: int = sim.campaign_wallet
    var done_count: int = sim.completed_count
    check(sim.accept_contract("first_shift").ok,"completed campaign permits replay")
    while sim.campaign_status == "running" and sim.sim_time < 1000.0:
        sim.step(.5)
    check(sim.campaign_status == "campaign_complete","replay returns campaign completion")
    check(sim.campaign_wallet == wallet and sim.completed_count == done_count,"replay does not duplicate reward or count")
    check(sim.contract_results.first_shift.attempts == 2,"replay attempt counted")
    print(JSON.stringify({"suite":"independent_campaign_resume","checks":checks,"failures":failures,"timings":timings}))
    quit(0 if failures.is_empty() else 1)
