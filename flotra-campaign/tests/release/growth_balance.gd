extends SceneTree

const Sim = preload("res://prototype/growth_sim.gd")
const LAYOUTS := ["compact", "clear_aisle", "pack_annex", "split"]
var checks := 0
var failures: Array[String] = []
var measurements: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func run(sim, id: String, label: String, limit: float = 1200.0) -> Dictionary:
    var before_wallet: int = sim.campaign_wallet
    var accepted: Dictionary = sim.accept_contract(id)
    check(accepted.ok, label+" accepted: "+str(accepted))
    if not accepted.ok: return {}
    var seen_wings := {}
    var robot_work := false
    var peak_bays := 0
    var first_ship := -1.0
    var active_hub_saved := false
    while not sim.finished and sim.sim_time < limit:
        sim.step(.5)
        var invariant: Dictionary = sim.check_invariants()
        if not invariant.ok:
            check(false, label+" conserves physical cargo: "+str(invariant))
            break
        if sim.shipped > 0 and first_ship < 0.0: first_ship = sim.sim_time
        var occupied := 0
        for bay in sim.bulk_bays:
            if bay.manifest_id >= 0 or bay.reserved_by >= 0:
                occupied += 1
                if str(bay.id).begins_with("W"):
                    seen_wings[str(bay.id).split("-")[0]] = true
        peak_bays = maxi(peak_bays, occupied)
        for worker in sim.workers:
            if worker.id >= sim._human_count() and not worker.cargo_ids.is_empty(): robot_work = true
        if id=="route_hub" and not active_hub_saved and sim.sim_time>=60.0:
            active_hub_saved = true
            var saved: Dictionary = bytes_to_var(var_to_bytes(sim.export_release_state()))
            var restored = Sim.new()
            var result: Dictionary = restored.import_release_state(saved)
            check(result.ok,label+" expanded active save accepted: "+str(result))
            if result.ok:
                check(restored.export_release_state()==saved,label+" expanded active save preserves all288 cargo units and reservations")
                sim.step(.375)
                restored.step(.375)
                check(restored.export_release_state()==sim.export_release_state(),label+" expanded active resume stays deterministic")
    check(sim.finished, label+" finishes without timer failure or softlock")
    if sim.finished:
        check(sim.shipped == sim.offered_units and sim.shipped == sim.cargo.size(), label+" ships every offered unit")
        check(sim.campaign_wallet-before_wallet == int(sim._contract(id).reward), label+" pays the advertised reward")
    return {"seconds":snappedf(sim.sim_time,.01),"first_ship":first_ship,"peak_bays":peak_bays,"wings_used":seen_wings.keys(),"robot_work":robot_work,"units":sim.shipped}

func earn(sim, required: int, label: String) -> void:
    for attempt in 30:
        if sim.campaign_wallet >= required: return
        run(sim,"growth_1",label+" recovery round "+str(attempt))
    check(sim.campaign_wallet >= required,label+" can earn money without an entry fee")

func equipped_fixture(saved: Dictionary, excluded: Array[String]):
    var sim = Sim.new()
    check(sim.import_release_state(saved).ok,"equipment comparison fixture imports")
    for definition in Sim.GROWTH_UPGRADES:
        if definition.id in excluded: continue
        earn(sim,int(definition.cost),"comparison "+str(definition.id))
        check(sim.buy_upgrade(definition.id).ok,"comparison buys "+str(definition.id))
    return sim

func _initialize() -> void:
    var mature_save := {}
    for layout in LAYOUTS:
        var sim = Sim.new()
        sim.apply_layout(layout)
        var total := 0.0
        var rows := []
        for number in range(1,7):
            var row := run(sim,"growth_%d"%number,layout+" starter step "+str(number))
            if row.is_empty(): continue
            check(row.seconds <= (55.0 if number==1 else 240.0),layout+" step "+str(number)+" stays snappy even without upgrades")
            total += row.seconds
            rows.append(row)
        check(sim._milestones()==6,layout+" all milestones reachable with starting equipment")
        check(sim.workers.size()==3 and sim.purchased_upgrades.is_empty(),layout+" baseline buys no hidden equipment")
        run(sim,"route_bulk",layout+" starter repeat bulk")
        run(sim,"route_pick",layout+" starter repeat pick")
        var hub_option: Dictionary = sim.contract_options().filter(func(option): return option.id=="route_hub")[0]
        check(not hub_option.available and not str(hub_option.locked_reason).is_empty(),layout+" large dispatch explains required facilities")
        var before_hub: Dictionary = sim.export_release_state()
        check(not sim.accept_contract("route_hub").ok and sim.export_release_state()==before_hub,layout+" starter cannot accidentally enter a twenty-minute large dispatch")
        measurements.append({"layout":layout,"starter_milestones":rows,"total_sim_seconds":total})
        if layout=="compact": mature_save = sim.export_release_state()

    # Either first choice is safe, and the first payout can fund both together.
    for order in [["wing_1","crew_4"],["crew_4","wing_1"]]:
        var sim = Sim.new()
        run(sim,"growth_1","first purchase choice")
        for id in order: check(sim.buy_upgrade(id).ok,"first payout affords "+id)
        check(sim.campaign_wallet==0,"first two useful improvements can use the entire wallet")
        run(sim,"growth_2","zero wallet still accepts paid work")

    for layout in LAYOUTS:
        var minimum = Sim.new()
        check(minimum.import_release_state(mature_save).ok,"minimum large-dispatch fixture imports")
        for id in ["wing_1","wing_2","wing_3","robot_2"]:
            check(minimum.buy_upgrade(id).ok,"minimum large-dispatch buys "+id)
        minimum.apply_layout(layout)
        var minimum_stats := run(minimum,"route_hub",layout+" minimum qualifying large dispatch")
        check(minimum_stats.seconds<=480.0,layout+" minimum qualifying large dispatch remains bounded and forgiving")
        measurements.append({"minimum_hub_layout":layout,"stats":minimum_stats})

    var mature = Sim.new()
    check(mature.import_release_state(mature_save).ok,"mature no-upgrade fixture imports")
    for definition in Sim.GROWTH_UPGRADES:
        earn(mature,int(definition.cost),"buy "+str(definition.id))
        var before: Dictionary = mature.export_release_state()
        var bought: Dictionary = mature.buy_upgrade(definition.id)
        check(bought.ok,"buy all growth equipment "+str(definition.id)+": "+str(bought))
        if not bought.ok: continue
        check(mature.campaign_wallet == int(before.campaign.wallet)-int(definition.cost),"purchase spends exactly its price")
        var after: Dictionary = mature.export_release_state()
        check(not mature.buy_upgrade(definition.id).ok and mature.export_release_state()==after,"double purchase cannot spend twice")
    check(mature._wing_count()==4 and mature.bulk_bays.size()==38,"four wings add thirty-two real pallet bays")
    check(mature._human_count()==6 and mature._robot_count()==4 and mature.workers.size()==10,"humans and robots are actual carriers")
    check(mature.rack_capacity==48 and is_equal_approx(mature.pack_seconds,.7),"rack and auto-packing change real processing capacity")
    var snapshot: Dictionary = mature.snapshot()
    check(snapshot.world.growth_wings.size()==4 and snapshot.world.nodes.size()>Sim.POINTS.size(),"warehouse floor and routing graph both grow")
    for bay in mature.bulk_bays:
        if not str(bay.id).begins_with("W"): continue
        check(snapshot.world.growth_wings.any(func(rect): return rect.encloses(bay.footprint)),"new bay is inside a purchased physical wing")
        var lane_clear := true
        for edge in mature._edges.values():
            for lane in edge.bulk_lanes:
                for sample in 61:
                    var t := float(sample)/60.0
                    var a: Vector3 = edge.from
                    var b: Vector3 = edge.to
                    var direction := (b-a).normalized()
                    var normal := Vector3(-direction.z,0,direction.x)
                    var point := a.lerp(b,t)+normal*(-.32 if lane==0 else .32)*sin(PI*t)
                    if bay.footprint.grow(Sim.MANIFEST_RADIUS).has_point(Vector2(point.x,point.z)):
                        lane_clear = false
        check(lane_clear,"new bay and trolley transport lanes never overlap: "+str(bay.id))
    var mature_stats := run(mature,"route_hub","fully equipped large dispatch")
    check(mature_stats.robot_work,"robots actually reserve and move cargo")
    check("W4" in mature_stats.wings_used,"large dispatch uses the newest physical wing")
    measurements.append({"mature_hub":mature_stats})
    var three_wings = equipped_fixture(mature_save,["wing_4"])
    var three_stats := run(three_wings,"route_hub","matched large dispatch with three wings")
    check(mature_stats.seconds<three_stats.seconds,"fourth wing improves identical-demand completion time")
    check(mature_stats.peak_bays>three_stats.peak_bays,"fourth wing supplies additional simultaneous real storage")
    var two_robots = equipped_fixture(mature_save,["robot_4"])
    var two_robot_stats := run(two_robots,"route_pick","matched parcel dispatch with two robots")
    var four_robot_stats := run(mature,"route_pick","matched parcel dispatch with four robots")
    var zero_robots = equipped_fixture(mature_save,["robot_2","robot_4"])
    var zero_robot_stats := run(zero_robots,"route_pick","matched parcel dispatch without robots")
    check(two_robot_stats.seconds<zero_robot_stats.seconds,"first robot pair improves identical-demand parcel throughput")
    check(four_robot_stats.seconds<two_robot_stats.seconds,"four robots improve identical-demand parcel throughput")
    measurements.append({"three_wing_hub":three_stats,"zero_robot_parcels":zero_robot_stats,"two_robot_parcels":two_robot_stats,"four_robot_parcels":four_robot_stats})
    for layout in ["clear_aisle","pack_annex","split"]:
        mature.apply_layout(layout)
        var layout_stats := run(mature,"route_hub","fully equipped "+layout+" large dispatch")
        check(layout_stats.seconds<=420.0,"fully equipped nonoptimal layout still clears large dispatch promptly")
        measurements.append({"mature_layout":layout,"hub":layout_stats})
    var full_save: Dictionary = mature.export_release_state()
    var starting_lifetime: int = mature._lifetime_units()
    var starting_cash: int = mature.campaign_wallet
    for repeat in 4:
        run(mature,"route_bulk","post-buyout paid dispatch "+str(repeat))
        check(mature.cargo.size()==72 and mature.manifests.size()==12,"each completed round has a bounded physical ledger")
        check(mature.contract_results.size()<=Sim.GROWTH_CONTRACTS.size(),"repeats aggregate results rather than append forever")
    check(mature.campaign_wallet>starting_cash and mature._lifetime_units()>starting_lifetime,"work and income remain available after every upgrade")
    check(mature.campaign_status!="campaign_complete","full buyout does not close the operating warehouse")
    var reloaded = Sim.new()
    check(reloaded.import_release_state(full_save).ok,"fully equipped result saves correctly")
    print(JSON.stringify({"suite":"growth_balance","checks":checks,"failures":failures,"measurements":measurements}))
    quit(0 if failures.is_empty() else 1)
