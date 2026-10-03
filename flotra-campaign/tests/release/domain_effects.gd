extends SceneTree
const Sim = preload("res://prototype/release_sim.gd")
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)
func run(sim, id: String, layout: String) -> Dictionary:
    sim.apply_layout(layout)
    check(sim.accept_contract(id).ok,"accept comparable contract")
    var peak_rack := 0
    var used_extra := false
    var pack_time := 0.0
    for tick in 80000:
        sim.step(.05)
        peak_rack = maxi(peak_rack,sim._rack_occupied()+sim._store_reserved())
        for bay in sim.bulk_bays:
            if bay.id in ["C1","C2"] and (bay.manifest_id>=0 or bay.reserved_by>=0):
                used_extra = true
        if not sim.pack_jobs.is_empty():
            pack_time += .05
        if sim.finished:
            break
    check(sim.finished and sim.check_invariants().ok,"comparable run completes with conserved cargo")
    return {"seconds":sim.sim_time,"peak_rack":peak_rack,"used_extra_bay":used_extra,"packing_busy_seconds":pack_time,"workers":sim.workers.size(),"rack_capacity":sim.rack_capacity,"pack_seconds":sim.pack_seconds,"bulk_capacity":sim.bulk_capacity()}
func _initialize() -> void:
    var base = Sim.new()
    for contract in Sim.CONTRACTS:
        run(base,contract.id,"compact")
    var mature: Dictionary = base.export_release_state()
    var report := {}
    for missing in ["none","worker_5","rack_24","packing_2","floor_2"]:
        var sim = Sim.new()
        check(sim.import_release_state(mature).ok,"valid mature fixture")
        for id in ["worker_4","worker_5","rack_24","packing_2","floor_2"]:
            if id != missing:
                check(sim.buy_upgrade(id).ok,"buy physical upgrade "+id)
        var contract := "storage_peak" if missing == "floor_2" else "packing_rush"
        var stats := run(sim,contract,"clear_aisle")
        report[missing] = stats
        if missing == "none":
            report.full_bulk = run(sim,"storage_peak","clear_aisle")
    check(report.none.workers==5 and report.worker_5.workers==4,"hire contributes another real worker")
    check(report.none.peak_rack>12 and report.rack_24.peak_rack<=12,"larger rack actually holds more reserved physical units")
    check(report.none.packing_busy_seconds < report.packing_2.packing_busy_seconds,"faster packing removes actual per-item work time")
    check(report.full_bulk.used_extra_bay and not report.floor_2.used_extra_bay,"extra physical bays are actually used")
    check(report.full_bulk.seconds < report.floor_2.seconds,"extra bays improve held-pallet completion speed")
    print(JSON.stringify({"checks":checks,"failures":failures,"effects":report}))
    quit(0 if failures.is_empty() else 1)
