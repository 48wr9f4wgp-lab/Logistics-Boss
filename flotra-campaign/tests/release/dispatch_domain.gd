extends SceneTree
const Sim = preload("res://prototype/dispatch_sim.gd")
const Old = preload("res://prototype/growth_sim.gd")
var failures: Array[String] = []
var covered: Array[String] = []

func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)

func finish(sim, id: String) -> void:
    var before: int = sim.campaign_wallet
    var result: Dictionary = sim.accept_contract(id)
    check(result.ok,"Accept "+id)
    if not result.ok: return
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
        if not sim.check_invariants().ok:
            check(false,"Cargo invariant "+id)
            break
    check(sim.finished and sim.shipped==sim.offered_units,"Complete every unit "+id)
    check(sim.campaign_wallet-before==int(sim._contract(id).reward),"One advertised reward "+id)

func earn(sim, needed: int) -> void:
    for i in 10:
        if sim.campaign_wallet>=needed: return
        finish(sim,"route_pick")
    check(false,"Earn prerequisite funds")

func _initialize() -> void:
    var sim = Sim.new()
    var old = Old.new()
    for definition in old._contracts():
        check(sim._contract(definition.id)==definition,"Old contract unchanged "+definition.id)
    for definition in old._upgrades():
        check(sim._upgrade(definition.id)==definition,"Old upgrade unchanged "+definition.id)
    check(sim.dispatch_window==6 and sim._pick_admission_limit()==6,"Default six")
    check(not sim.buy_upgrade("pick_dispatch_board").ok,"Locked board rejects")
    check(not sim.set_dispatch_window(12).ok,"Unowned twelve rejects")
    check(not sim._contract_unlocked("route_parcel_120"),"New route locked before growth4")
    covered.append("Existing contract/equipment definitions unchanged; initial and locked states retain six")
    # Presentation-only mature fixture: do not claim the old equipment catalog
    # is still incomplete when only the newly added board remains.
    var goal_probe = Sim.new()
    goal_probe.purchased_upgrades.assign(Old.GROWTH_UPGRADES.map(func(option): return str(option.id)))
    goal_probe.contract_results["growth_4"] = {}
    goal_probe.campaign_wallet = 150
    check(goal_probe._next_goal().contains("集品指示盤") and goal_probe._next_goal().contains("150"),"Mature next goal identifies the new board shortfall")


    # Same old opening, same physical outcome and exact old-format fields.
    check(sim.accept_contract("growth_1").ok and old.accept_contract("growth_1").ok,"Opening accepted")
    while not old.finished and old.sim_time<1200:
        old.step(0.25)
        sim.step(0.25)
        var projected: Dictionary = sim.export_release_state()
        projected.erase("dispatch")
        projected.schema = 3
        check(projected==old.export_release_state(),"Default-six old opening preserves exact state")
        if not failures.is_empty(): break
    for number in [2,3,4]: finish(sim,"growth_%d"%number)
    check(sim._contract_unlocked("route_parcel_120"),"New route available before board purchase after growth4")
    for id in ["crew_4","robot_2","auto_pack","crew_6","robot_4","rack_48"]:
        earn(sim,int(sim._upgrade(id).cost))
        check(sim.buy_upgrade(id).ok,"Real purchase "+id)
    earn(sim,300)
    covered.append("Real deliveries earn growth4, prerequisite equipment and purchase funds")

    for missing in ["crew_6","robot_4","auto_pack"]:
        var probe = Sim.new()
        check(probe.import_release_state(sim.export_release_state()).ok,"Copy earned candidate")
        probe.purchased_upgrades.erase(missing)
        var before: Dictionary = probe.export_release_state()
        check(not probe.buy_upgrade("pick_dispatch_board").ok and probe.export_release_state()==before,"Missing prerequisite rejects without mutation "+missing)
    var initial_wallet: int = sim.campaign_wallet
    check(sim.buy_upgrade("pick_dispatch_board").ok,"Board purchase succeeds")
    check(sim.campaign_wallet==initial_wallet-300 and sim.dispatch_window==6,"One debit300 and retain six")
    var purchased: Dictionary = sim.export_release_state()
    check(not sim.buy_upgrade("pick_dispatch_board").ok and sim.export_release_state()==purchased,"Repeated purchase cannot debit")
    check(sim.set_dispatch_window(12).ok and sim.campaign_wallet==initial_wallet-300,"Free twelve")
    check(sim.set_dispatch_window(6).ok and sim.set_dispatch_window(12).ok,"Free reversal before job")
    check(not sim.set_dispatch_window(7).ok and sim.dispatch_window==12,"Invalid window rejects")
    covered.append("Single purchase debit, duplicate/missing prerequisite rejection and reversible free selection")

    check(sim.accept_contract("route_parcel_120").ok,"Start new route")
    sim.step(0.45)
    check(sim.offered_units==0,"No arrival before0.50s")
    sim.step(0.05)
    check(sim.offered_units==6,"First six arrive at0.50s")
    var running: Dictionary = sim.export_release_state()
    check(not sim.set_dispatch_window(6).ok and not sim.accept_contract("route_parcel_120").ok,"Running switch/restart rejected")
    check(sim.export_release_state()==running,"Rejected running actions preserve all cargo and clocks")
    var peak_wip := 0
    var before_reward: int = sim.campaign_wallet
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
        peak_wip = maxi(peak_wip,int(sim.dispatch_state().wip))
        check(sim.check_invariants().ok and sim.pack_jobs.size()<=1 and is_equal_approx(sim.pack_seconds,0.7),"Cargo/WIP and unchanged one-packer timing")
        if not failures.is_empty(): break
    check(sim.finished and sim.shipped==120 and sim.offered_units==120 and sim.packed==120,"New route completes all120")
    check(sim.manifests.size()==20 and sim.manifests.values().all(func(m):return m.kind=="pick"),"Exactly20 pure-pick manifests")
    check(sim.campaign_wallet==before_reward+300,"New route reward exactly300")
    check(peak_wip>6 and peak_wip<=12,"Selected twelve is used by actual work")
    var completed: Dictionary = sim.export_release_state()
    sim.step(5.0)
    check(sim.export_release_state()==completed,"No duplicate completion reward")
    check(sim.set_dispatch_window(6).ok,"Return to six after actual completion")
    var reverted: Dictionary = sim.export_release_state()
    reverted.dispatch.dispatch_window=12
    check(reverted==completed,"Reversal changes only dispatch selection")
    covered.append("One new120-parcel run: real WIP>6, one reward, running lock, completed-state return to six")

    print("DISPATCH_DOMAIN ",JSON.stringify({"covered":covered,"failures":failures,"peak_wip":peak_wip,"engine":Engine.get_version_info().string}))
    quit(0 if failures.is_empty() else 1)
