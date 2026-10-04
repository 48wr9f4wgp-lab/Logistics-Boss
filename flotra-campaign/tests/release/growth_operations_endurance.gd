extends SceneTree
const Sim = preload("res://prototype/growth_sim.gd")
var checks := 0
var failures: Array[String] = []
var measurements: Array = []
func check(value: bool, label: String) -> void:
    checks+=1
    if not value:
        failures.append(label)
        push_error(label)
func run(sim, id: String) -> Dictionary:
    check(sim.accept_contract(id).ok,"endurance accepts "+id)
    var max_cart := 0
    var peak_rack := 0
    var peak_pack := 0
    var started := Time.get_ticks_usec()
    while not sim.finished and sim.sim_time < 1200.0:
        sim.step(1.0)
        check(sim.check_invariants().ok,"endurance physical conservation")
        for worker in sim.workers:
            if worker.task in ["pick","ship"]: max_cart=maxi(max_cart,worker.cargo_ids.size())
        peak_rack=maxi(peak_rack,sim._rack_occupied()+sim._store_reserved())
        peak_pack=maxi(peak_pack,sim.packing.size())
    check(sim.finished,"endurance completes "+id)
    check(sim.shipped==sim.cargo.size() and sim.cargo.size()==sim.offered_units,"endurance ships exact offered units")
    return {"contract":id,"mode":sim.operation_mode,"layout":sim.layout_id,"seconds":snappedf(sim.sim_time,.01),"cpu_ms":float(Time.get_ticks_usec()-started)/1000.0,"max_cart":max_cart,"peak_rack":peak_rack,"peak_pack":peak_pack}
func _initialize() -> void:
    var sim=Sim.new()
    for n in range(1,7): run(sim,"growth_%d"%n)
    for option in Sim.GROWTH_UPGRADES:
        while sim.campaign_wallet<int(option.cost): run(sim,"growth_1")
        check(sim.buy_upgrade(option.id).ok,"earned full equipment "+str(option.id))
    var earned_before: int=sim.campaign_wallet
    var lifetime_before: int=sim._lifetime_units()
    for layout in ["compact","clear_aisle","pack_annex","split"]:
        sim.apply_layout(layout)
        for mode in ["balanced","parcel","pallet"]:
            check(sim.set_operation(mode).ok,"choose mature mode")
            measurements.append(run(sim,"route_pick"))
    for mode in ["balanced","parcel","pallet"]:
        sim.apply_layout("compact")
        sim.set_operation(mode)
        measurements.append(run(sim,"route_hub"))
    # A total of 36 further rounds spanning all modes. Domain history belongs
    # only to the current finite round; records aggregate, never append entities.
    for repeat in 36:
        sim.set_operation(["balanced","parcel","pallet"][repeat%3])
        sim.apply_layout(["compact","clear_aisle","pack_annex","split"][repeat%4])
        var row:=run(sim,"route_pick" if repeat%2==0 else "route_bulk")
        check(sim.cargo.size()<=72 and sim.manifests.size()<=12,"repeat keeps current cargo bounded")
        check(sim.mix_history.size()==1 and sim.relocation_history.is_empty(),"repeat histories do not accumulate")
        check(sim.contract_results.size()<=Sim.GROWTH_CONTRACTS.size(),"repeat records aggregate")
        check(sim.workers.size()==10 and sim.bulk_bays.size()==38,"repeat does not duplicate equipment")
        var restored=Sim.new()
        var state: Dictionary=sim.export_release_state()
        var result: Dictionary=restored.import_release_state(state)
        check(result.ok,"repeat save valid "+str(result))
        check(restored.export_release_state()==state,"repeat exact roundtrip")
        if repeat in [0,35]:measurements.append(row)
    check(sim.campaign_wallet>earned_before and sim._lifetime_units()>lifetime_before,"repeats continue paying and counting real work")
    for option in sim.upgrade_options():
        if option.id in ["rack_48","auto_pack"]:
            check(option.has("effect_preview") and option.effect_preview.synergy=="parcel","equipment explains actual cart synergy")
    print(JSON.stringify({"suite":"growth_operations_endurance","checks":checks,"failures":failures,"measurements":measurements,"rounds_after_maturity":51,"final_cargo":sim.cargo.size(),"final_manifests":sim.manifests.size(),"results":sim.contract_results.size()}))
    quit(0 if failures.is_empty() else 1)
