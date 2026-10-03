extends SceneTree
const Sim = preload("res://prototype/release_sim.gd")
var failures: Array[String] = []
var checks := 0
var measurements: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func complete(sim, label: String) -> float:
    for second in 3600:
        sim.step(1.0)
        var invariant: Dictionary = sim.check_invariants()
        if not invariant.ok:
            check(false,label+": "+str(invariant))
            return -1.0
        if sim.finished:
            check(sim.shipped == sim.offered_units and sim.cargo.size() == sim.shipped,label+" conserves every unit")
            return sim.sim_time
    check(false,label+" completes within bounded horizon")
    return -1.0

func roundtrip(sim, label: String) -> void:
    var saved: Dictionary = bytes_to_var(var_to_bytes(sim.export_release_state()))
    var restored = Sim.new()
    var result: Dictionary = restored.import_release_state(saved)
    check(result.ok,label+" accepted "+str(result))
    if not result.ok:
        return
    check(restored.export_release_state() == saved,label+" exact state on load")
    for index in 180:
        var dt := 0.037 if index%3 == 0 else 0.113
        sim.step(dt)
        restored.step(dt)
    check(restored.export_release_state() == sim.export_release_state(),label+" exact deterministic continuation")

func _initialize() -> void:
    var moving_equipment = Sim.new()
    moving_equipment.accept_contract("first_shift")
    moving_equipment.step(1.0)
    moving_equipment.apply_layout("clear_aisle")
    moving_equipment.step(.05)
    check(moving_equipment._move_remaining > 0.0,"equipment save fixture actually relocating")
    roundtrip(moving_equipment,"active equipment relocation save")
    var initial = Sim.new()
    check(initial.workers.size()==3 and initial.campaign_wallet==100,"small starting fleet and wallet")
    check(initial.contract_options().filter(func(o):return o.available).size()==1,"only intro initially available")
    check(not initial.accept_contract("final_dispatch").ok,"final locked initially")
    check(not initial.buy_upgrade("worker_4").ok,"hire gated before first contract")
    roundtrip(initial,"ready save")
    check(initial.accept_contract("first_shift").ok,"accept intro")
    initial.step(17.375)
    check(initial.workers.any(func(w):return not str(w.edge_id).is_empty()),"midmovement fixture actually moving")
    var before := initial.export_release_state()
    check(not initial.accept_contract("first_shift").ok and initial.export_release_state()==before,"active double accept retains all cargo")
    check(not initial.set_mix("bulk_heavy").ok,"contract demand cannot be rerolled")
    roundtrip(initial,"midmovement save")
    initial.apply_layout("clear_aisle")
    roundtrip(initial,"pending relocation save")
    complete(initial,"intro adaptive")
    check(initial.completed_count==1 and initial.campaign_wallet==280,"first reward credited exactly once")
    check(initial.contract_options().filter(func(o):return o.available and not o.is_replay).size()==2,"two genuine new work choices after intro")
    check(initial.buy_upgrade("worker_4").ok,"first meaningful hire choice")
    var after_buy := initial.export_release_state()
    check(not initial.buy_upgrade("worker_4").ok and initial.export_release_state()==after_buy,"doubletap cannot repurchase or spend twice")
    check(not initial.buy_upgrade("rack_24").ok,"cannot afford all first choices")
    roundtrip(initial,"hired save")
    var wallet: int = initial.campaign_wallet
    var count: int = initial.completed_count
    check(initial.accept_contract("first_shift").ok,"completed contract can replay")
    complete(initial,"intro replay")
    check(initial.campaign_wallet==wallet and initial.completed_count==count,"replay cannot farm cash or unlock count")
    check(initial.contract_results.first_shift.attempts==2,"replay records another scored attempt")
    # Full first-clear campaigns in all four layouts. No upgrade is required to
    # escape a dead end; preserving all cargo is checked on every simulated sec.
    var baseline_times := {}
    for layout in ["compact","clear_aisle","pack_annex","split"]:
        var sim = Sim.new()
        sim.apply_layout(layout)
        var times := {}
        var total := 0.0
        for contract in Sim.CONTRACTS:
            check(sim.accept_contract(contract.id).ok,layout+" accepts "+str(contract.id))
            var elapsed := complete(sim,layout+" "+str(contract.id))
            total += elapsed
            times[contract.id] = elapsed
            check(sim.manifests.size()==contract.manifest_quota,"exact finite manifest count")
            check(sim.bulk_shipped==contract.bulk_manifests*6 and sim.pick_shipped==contract.pick_manifests*6,"exact bulk and pick quotas")
            var frozen := sim.export_release_state()
            sim.step(5000.0)
            check(frozen==sim.export_release_state(),"completed work never spawns another manifest")
            check(sim.layout_id==layout,"layout survives contract transitions")
        check(sim.completed_count==6 and sim.campaign_status=="campaign_complete",layout+" campaign reachable with starting fleet")
        baseline_times[layout] = times
        measurements.append({"layout":layout,"fleet":3,"times":times,"total_sim_seconds":total})
        roundtrip(sim,layout+" completed campaign save")
    check(baseline_times.clear_aisle.small_orders < baseline_times.compact.small_orders,"short-pick layout favored on pick contract")
    check(baseline_times.compact.storage_peak < baseline_times.clear_aisle.storage_peak,"wide storage floor favored on bulk contract")
    var alternate = Sim.new()
    for id in ["first_shift","pallet_wave","small_orders","storage_peak","packing_rush","final_dispatch"]:
        check(alternate.accept_contract(id).ok,"branch can be completed in alternative order "+id)
        complete(alternate,"alternative branch "+id)
        roundtrip(alternate,"alternative completion "+id)
    check(alternate.completed_count==6,"both branch orders reach campaign completion")
    var growing = Sim.new()
    var growing_total := 0.0
    for contract in Sim.CONTRACTS:
        for option in growing.upgrade_options():
            if option.available and growing.campaign_wallet >= option.cost:
                check(growing.buy_upgrade(option.id).ok,"buy unlocked upgrade "+str(option.id))
        growing.apply_layout("clear_aisle" if contract.pick_manifests>contract.bulk_manifests else "compact")
        check(growing.accept_contract(contract.id).ok,"upgraded campaign accepts "+str(contract.id))
        growing_total += complete(growing,"upgraded "+str(contract.id))
    for option in growing.upgrade_options():
        if option.available and growing.campaign_wallet >= option.cost:
            check(growing.buy_upgrade(option.id).ok,"buy remaining permanent upgrade")
    check(growing.workers.size()==5 and growing.rack_capacity==24 and growing.pack_seconds==2.0,"all upgrades change actual equipment")
    check(growing.bulk_bays.size()==8 and growing.bulk_capacity("compact")==8 and growing.bulk_capacity("clear_aisle")==4,"floor upgrade adds two physical bays in both layouts")
    for bay in growing.bulk_bays:
        if bay.id not in ["C1","C2"]:
            continue
        check(Rect2(-2,-7.8,9,5.8).encloses(bay.footprint),"extra bay fully inside annex")
        for layout in ["compact","clear_aisle","pack_annex","split"]:
            check(growing._bay_available_in(bay,layout),"extra bay clear of equipment in "+layout)
            growing.apply_layout(layout)
            for edge in growing._edges.values():
                for lane in edge.bulk_lanes:
                    for sample in 41:
                        var t := float(sample)/40.0
                        var a: Vector3 = edge.from
                        var b: Vector3 = edge.to
                        var direction := (b-a).normalized()
                        var normal := Vector3(-direction.z,0,direction.x)
                        var point := a.lerp(b,t)+normal*(-.32 if lane==0 else .32)*sin(PI*t)
                        if bay.footprint.grow(Sim.MANIFEST_RADIUS).has_point(Vector2(point.x,point.z)):
                            check(false,"extra bay intersects transport lane "+str(edge.id))
    roundtrip(growing,"all equipment save")
    measurements.append({"fleet":"growing","total_sim_seconds":growing_total,"wallet":growing.campaign_wallet,"upgrades":growing.purchased_upgrades})
    # Compare upgrades with a replay of identical demand and no free money.
    var upgraded_times := {}
    for layout in ["compact","clear_aisle"]:
        growing.apply_layout(layout)
        growing.accept_contract("storage_peak")
        upgraded_times[layout] = complete(growing,"fully upgraded replay "+layout)
    check(upgraded_times.compact < baseline_times.compact.storage_peak,"permanent equipment improves repeatable bulk run")
    measurements.append({"fully_upgraded_storage_peak":upgraded_times})
    print(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}))
    quit(0 if failures.is_empty() else 1)
