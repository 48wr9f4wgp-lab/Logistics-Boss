extends SceneTree

const Sim = preload("res://prototype/growth_sim.gd")
const Old = preload("res://prototype/growth_v2_sim.gd")
const Save = preload("res://prototype/release_save.gd")
const LAYOUTS := ["compact","clear_aisle","pack_annex","split"]
var checks := 0
var failures: Array[String] = []
var measurements: Array = []

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func finish(sim, label: String, limit: float = 1200.0) -> Dictionary:
    var peak_rack := 0
    var peak_pack := 0
    var max_load := 0
    var saw_exclusive_cart := false
    while not sim.finished and sim.sim_time < limit:
        sim.step(.5)
        var invariant: Dictionary = sim.check_invariants()
        if not invariant.ok:
            check(false,label+" conserves cargo: "+str(invariant))
            break
        peak_rack = maxi(peak_rack,sim._rack_occupied()+sim._store_reserved())
        peak_pack = maxi(peak_pack,sim.packing.size())
        for worker in sim.workers:
            if worker.task in ["pick","ship"]:
                max_load = maxi(max_load,worker.cargo_ids.size())
                if worker.carrying and worker.cargo_ids.size() > 1 and not str(worker.edge_id).is_empty():
                    saw_exclusive_cart = true
                    check(sim._edges[worker.edge_id].owners == [worker.id],label+" cart owns exclusive physical route")
    check(sim.finished,label+" finishes")
    check(sim.shipped==sim.offered_units and sim.shipped==sim.cargo.size(),label+" ships all actual units")
    return {"seconds":snappedf(sim.sim_time,.01),"peak_rack":peak_rack,"peak_pack":peak_pack,"max_load":max_load,"exclusive_cart":saw_exclusive_cart}

func run(sim, id: String, label: String) -> Dictionary:
    var wallet: int = sim.campaign_wallet
    var result: Dictionary = sim.accept_contract(id)
    check(result.ok,label+" accepts: "+str(result))
    if not result.ok: return {}
    var metrics := finish(sim,label)
    check(sim.campaign_wallet-wallet==int(sim._contract(id).reward),label+" same advertised reward")
    return metrics

func fixture(saved: Dictionary, layout: String, mode: String, equipment: Array = []):
    var sim = Sim.new()
    check(sim.import_release_state(saved).ok,"comparison imports earned fixture")
    sim.apply_layout(layout)
    check(sim.set_operation(mode).ok,"select free "+mode)
    for id in equipment: check(sim.buy_upgrade(id).ok,"buy "+str(id))
    return sim

func roundtrip(sim, label: String) -> void:
    var state: Dictionary = sim.export_release_state()
    var store = Save.new()
    var decoded: Dictionary = store.decode(store.encode(state))
    check(decoded.ok,label+" safe codec")
    var restored = Sim.new()
    var result: Dictionary = restored.import_release_state(decoded.data)
    check(result.ok,label+" imports: "+str(result))
    if not result.ok: return
    check(restored.export_release_state()==state,label+" exact complete state")
    for dt in [.017,.113,.037,.283]:
        restored.step(dt)
        sim.step(dt)
    check(restored.export_release_state()==sim.export_release_state(),label+" deterministic continuation")

func rejects(data: Dictionary, label: String) -> void:
    var target = Sim.new()
    target.accept_contract("growth_1")
    target.step(4.5)
    var before: Dictionary = target.export_release_state()
    check(not target.import_release_state(data).ok,label+" rejects")
    check(target.export_release_state()==before,label+" rejection preserves target")

func batch_roundtrips(saved: Dictionary) -> void:
    var sim = fixture(saved,"compact","parcel",["auto_pack"])
    sim.accept_contract("route_pick")
    var seen := {}
    var active: Dictionary = {}
    while not sim.finished:
        sim.step(.05)
        for worker in sim.workers:
            if worker.task in ["pick","ship"] and worker.cargo_ids.size()>1:
                var key := str(worker.task)+"_"+str(worker.phase)
                if not seen.has(key):
                    seen[key]=true
                    roundtrip(sim,key)
                if active.is_empty(): active=sim.export_release_state()
        if not sim.pack_jobs.is_empty() and not seen.has("packing"):
            seen.packing=true
            roundtrip(sim,"physical packing with cart profile")
    for key in ["pick_to_source","pick_work","pick_to_target","packing"]:
        check(seen.has(key),"observed "+key)
    check(seen.has("ship_to_source") and seen.has("ship_work") and seen.has("ship_to_target"),"observed cart dispatch in every phase")
    check(not active.is_empty(),"captured active batch")
    if active.is_empty(): return
    var bad := active.duplicate(true)
    bad.experience.operation_mode="balanced"
    rejects(bad,"multiunit parcel cannot masquerade as default")
    bad=active.duplicate(true)
    bad.experience.operating_profile=false
    rejects(bad,"legacy profile cannot batch parcels")
    var index := -1
    for worker in active.sim.workers:
        if worker.task in ["pick","ship"] and worker.cargo_ids.size()>1:
            index=worker.id
            break
    check(index>=0,"batch worker available")
    if index>=0:
        bad=active.duplicate(true)
        bad.sim.workers[index].cargo_ids.append(bad.sim.workers[index].cargo_ids[0])
        rejects(bad,"duplicate batch ownership")
        bad=active.duplicate(true)
        bad.sim.workers[index].cargo_ids.append_array([1,2,3])
        rejects(bad,"over-capacity batch")
        bad=active.duplicate(true)
        bad.sim.workers[index].source="outbound"
        rejects(bad,"forged batch source")
        bad=active.duplicate(true)
        bad.sim.workers[index].work_remaining=999999.0
        rejects(bad,"forged batch handling time")
    var before: Dictionary = sim.export_release_state()
    check(sim.set_operation("balanced").ok,"completed job can reconfigure")
    check(sim.campaign_wallet==before.campaign.wallet and sim.cargo==before.sim.cargo,"reconfiguration costs nothing and preserves delivered cargo")
    roundtrip(sim,"reconfigured completed batch result")

func old_state_parity() -> void:
    for phase in ["ready","moving","paused","pending","relocating","complete"]:
        var old = Old.new()
        if phase != "ready": old.accept_contract("growth_1")
        if phase in ["moving","paused","pending"]: old.step(5.375)
        if phase=="paused": old.time_scale=0.0
        if phase in ["pending","relocating"]: old.apply_layout("pack_annex")
        if phase=="relocating": old.step(.05)
        if phase=="complete": finish(old,"frozen completed fixture")
        var original: Dictionary = old.export_release_state()
        var sim = Sim.new()
        var result: Dictionary = sim.import_release_state(original)
        check(result.ok and result.get("migrated",false),phase+" old schema2 validated")
        if not result.ok: continue
        var migrated: Dictionary = sim.export_release_state()
        check(migrated.sim==original.sim and migrated.campaign==original.campaign and migrated.growth==original.growth,phase+" exact old domain preserved")
        check(not sim.operating_profile and sim.operation_mode=="balanced",phase+" retains old operating rules")
        for dt in [.017,.113,.037,.283]:
            old.step(dt)
            sim.step(dt)
        check(sim.export_release_state().sim==old.export_release_state().sim and sim.export_release_state().campaign==old.export_release_state().campaign,phase+" identical old continuation")
        roundtrip(sim,phase+" migrated schema3")

func preferences_and_cancel() -> void:
    var sim=Sim.new()
    check(sim.preferences=={"preferred_speed":2,"pause_on_menus":false,"reduced_motion":false},"comfort defaults")
    for key in ["preferred_speed","pause_on_menus","reduced_motion"]:
        check(sim.set_preference(key,4 if key=="preferred_speed" else true).ok,"save preference "+key)
    check(sim.time_scale==1.0,"preferences never rewrite live clock")
    roundtrip(sim,"comfort preferences")
    for pair in [["preferred_speed",3],["preferred_speed",2.0],["pause_on_menus",1],["reduced_motion","true"],["unknown",false]]:
        var before: Dictionary = sim.export_release_state()
        check(not sim.set_preference(pair[0],pair[1]).ok and sim.export_release_state()==before,"invalid preference has no effect "+str(pair))
    for mode in ["balanced","parcel","pallet"]:
        check(sim.set_operation(mode).ok,"free mode available before first job")
    check(sim.set_operation("balanced").ok,"return to default")
    sim.accept_contract("growth_1")
    sim.step(5.0)
    for mode in ["balanced","parcel","pallet","unknown"]:
        var before: Dictionary=sim.export_release_state()
        check(not sim.set_operation(mode).ok and sim.export_release_state()==before,"inflight mode rejected without changes "+mode)
    var before: Dictionary=sim.export_release_state()
    check(sim.apply_layout("clear_aisle").ok,"queue layout while workers carry")
    check(sim._move_remaining==0.0 and not sim.pending_layout_id.is_empty(),"queued move has not started")
    check(sim.cancel_layout().ok and sim.export_release_state()==before,"cancel queued move restores exact state")
    roundtrip(sim,"cancelled pending layout")
    var moving=Sim.new()
    moving.accept_contract("growth_1")
    moving.apply_layout("clear_aisle")
    moving.step(.05)
    check(moving._move_remaining>0.0,"physical move started")
    before=moving.export_release_state()
    check(not moving.cancel_layout().ok and moving.export_release_state()==before,"cannot cancel physical move")
    var bad: Dictionary=sim.export_release_state()
    bad.experience.preferences.preferred_speed=8
    rejects(bad,"forged saved speed")
    bad=sim.export_release_state()
    bad.experience.extra=true
    rejects(bad,"unexpected experience key")
    bad=sim.export_release_state()
    bad.experience.preferences.pause_on_menus=1
    rejects(bad,"forged saved boolean")


func cancel_during_evacuation(saved: Dictionary) -> void:
    var sim=fixture(saved,"compact","balanced")
    sim.accept_contract("route_bulk")
    sim.step(3.0)
    sim.apply_layout("clear_aisle")
    var found := false
    while not sim.finished and not sim.pending_layout_id.is_empty() and sim.sim_time<240.0:
        sim.step(.05)
        if sim._move_remaining==0.0 and sim.workers.any(func(worker):return worker.task=="evacuate"):
            found=true
            var carriers: Array=sim.workers.duplicate(true)
            var edges: Dictionary=sim._edges.duplicate(true)
            var cargo: Dictionary=sim.cargo.duplicate(true)
            check(sim.cancel_layout().ok,"cancel while workers clear future equipment footprint")
            check(sim.workers==carriers and sim._edges==edges and sim.cargo==cargo,"cancel retains evacuation route and every cargo owner")
            roundtrip(sim,"canceled move with live evacuation")
            break
    check(found,"observed real evacuation before moving equipment")
    finish(sim,"canceled evacuation completes remaining work")
    check(sim.workers.all(func(worker):return worker.phase=="idle"),"completion does not freeze an evacuation mid-edge")
    roundtrip(sim,"completed evacuation cancellation")

func _initialize() -> void:
    old_state_parity()
    preferences_and_cancel()
    var earned=Sim.new()
    for n in range(1,4): run(earned,"growth_%d"%n,"earn milestone "+str(n))
    var saved: Dictionary=earned.export_release_state()
    batch_roundtrips(saved)
    cancel_during_evacuation(saved)
    for mode in ["balanced","parcel","pallet"]:
        for layout in LAYOUTS:
            var sim=fixture(saved,layout,mode)
            var parcels=run(sim,"route_pick",mode+" "+layout+" parcels")
            var pallets=run(sim,"route_bulk",mode+" "+layout+" pallets")
            check(parcels.seconds<=220.0 and pallets.seconds<=220.0,"all modes remain bounded without purchases")
            measurements.append({"mode":mode,"layout":layout,"parcels":parcels,"pallets":pallets})
    var baseline=run(fixture(saved,"compact","balanced"),"route_pick","baseline")
    var cart=run(fixture(saved,"compact","parcel"),"route_pick","cart")
    var packed=run(fixture(saved,"compact","parcel",["auto_pack"]),"route_pick","cart with automatic packing")
    var stocked=run(fixture(saved,"compact","parcel",["rack_48"]),"route_pick","cart with larger rack")
    check(cart.seconds<baseline.seconds*.8,"free parcel carts materially reduce trips")
    check(packed.seconds<cart.seconds*.9,"automatic packing materially helps cart bursts")
    check(stocked.seconds<cart.seconds*.95 and stocked.peak_rack>cart.peak_rack,"larger rack supplies actual stock and faster cart work")
    check(cart.max_load==3 and cart.exclusive_cart,"parcel option uses real three-unit trolley")
    var mid_equipment=["wing_1","crew_4","robot_2"]
    var mid_balanced=run(fixture(saved,"clear_aisle","balanced",mid_equipment),"route_bulk","expanded balanced storage")
    var mid_pallet=run(fixture(saved,"clear_aisle","pallet",mid_equipment),"route_bulk","expanded pallet-priority storage")
    var mid_parcel=run(fixture(saved,"clear_aisle","parcel",mid_equipment),"route_bulk","expanded parcel-first storage")
    check(mid_pallet.seconds<mid_balanced.seconds*.9 and mid_pallet.seconds<mid_parcel.seconds,"pallet option beats both alternatives on expanded storage work")
    measurements.append({"synergy":{"balanced":baseline,"cart":cart,"auto_pack_cart":packed,"rack_cart":stocked},"expanded_storage":{"balanced":mid_balanced,"parcel":mid_parcel,"pallet":mid_pallet}})
    print(JSON.stringify({"suite":"growth_operations","checks":checks,"failures":failures,"measurements":measurements}))
    quit(0 if failures.is_empty() else 1)
