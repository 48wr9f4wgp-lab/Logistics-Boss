extends SceneTree

const Fixture = preload("res://tests/release/regional_hall_fixture.gd")
const Sim = preload("res://prototype/growth_sim.gd")
const V3 = preload("res://prototype/growth_v3_sim.gd")
const V2 = preload("res://prototype/growth_v2_sim.gd")
const V1 = preload("res://prototype/release_sim.gd")
const Save = preload("res://prototype/release_save.gd")
const LAYOUTS = ["compact","clear_aisle","pack_annex","split"]
const MODES = ["balanced","parcel","pallet"]
var checks := 0
var failures: Array = []
var coverage := {}
var fixture: Dictionary = {}
var purchased: Dictionary = {}
var rows: Array = []

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func old_fields(data: Dictionary, schema: int) -> Dictionary:
    var old := data.duplicate(true)
    old.erase("hall")
    old.schema = schema
    if schema <= 2: old.erase("experience")
    if schema == 1: old.erase("growth")
    return old

func observe(sim) -> void:
    for worker in sim.workers:
        if worker.phase != "idle": coverage[worker.task+":"+worker.phase] = true
        if worker.carrying and worker.cargo_ids.size()>1: coverage["exclusive_loaded"] = true
        if worker.task in ["pick","ship"] and worker.cargo_ids.size()>1: coverage["parcel_batch"] = true
    if not sim.external_backlog.is_empty(): coverage["external_backlog"] = true
    if not sim.pack_jobs.is_empty(): coverage["packing"] = true
    if not sim.bulk_storage.is_empty(): coverage["stored_dwell"] = true
    for edge in sim._edges.values():
        if not edge.queue.is_empty(): coverage["edge_queue"] = true

func aliases(sim, label: String) -> void:
    var raw: Dictionary = sim.export_release_state()
    var validated: Dictionary = sim._validate_loaded_release()
    check(validated.ok,label+" physical validation: "+str(validated))
    check(sim.export_release_state()==raw,label+" validator preserves all values")
    var identity_ok := true
    for edge in sim._edges.values():
        var prior: float = edge.wait_seconds
        edge.wait_seconds = prior + 1.0
        identity_ok = identity_ok and sim._edge_between(edge.a,edge.b).wait_seconds == edge.wait_seconds
        var bound := false
        for indexed in sim._adjacency.get(edge.a,[]):
            if indexed.id == edge.id: bound = indexed.wait_seconds == edge.wait_seconds
        identity_ok = identity_ok and bound
        edge.wait_seconds = prior
    for bay in sim.bulk_bays:
        var prior: int = bay.reserved_by
        bay.reserved_by = 999
        identity_ok = identity_ok and sim._bay(bay.id).reserved_by == 999
        for entry in sim._bay_order:
            if entry.id == bay.id: identity_ok = identity_ok and entry.bay.reserved_by == 999
        bay.reserved_by = prior
    check(identity_ok,label+" every edge, adjacency and bay index binds live references")
    var route: Array = sim._find_path("inbound","outbound",false)
    var pristine := route.duplicate()
    route.append("mutated_local_array")
    check(sim._find_path("inbound","outbound",false)==pristine,label+" route arrays independent")
    check(sim.export_release_state()==raw,label+" alias audit leaves authoritative state untouched")

func roundtrip(sim, label: String):
    var raw: Dictionary = sim.export_release_state()
    var decoded: Dictionary = Save.new().decode(Save.new().encode(raw))
    check(decoded.ok,label+" actual save codec")
    var copy = Sim.new()
    var accepted: Dictionary = copy.import_release_state(decoded.data if decoded.ok else raw)
    check(accepted.ok,label+" strict schema4 import: "+str(accepted))
    if accepted.ok:
        check(copy.export_release_state()==raw,label+" exact schema4 roundtrip")
        aliases(copy,label)
    return copy

func finish(sim, label: String) -> void:
    while not sim.finished and sim.sim_time < 3000.0: sim.step(1.0)
    check(sim.finished and sim.check_invariants().ok,label+" drained conserved completion")

func paired_finish(original, restored, schema: int, label: String) -> void:
    var ticks := 0
    while not original.finished and original.sim_time < 3000.0:
        var dt: float = [.017,.113,.037,.283][ticks%4]
        original.step(dt)
        restored.step(dt)
        if ticks%127==0:
            var expected: Dictionary = original.export_release_state()
            var actual: Dictionary = restored.export_release_state()
            check((old_fields(actual,schema) if schema<4 else actual)==expected,label+" irregular continuation "+str(ticks))
            check(restored.check_invariants().ok,label+" real cargo conserved "+str(ticks))
            observe(restored)
        ticks += 1
    check(original.finished and restored.finished,label+" both reach drained completion")
    check((old_fields(restored.export_release_state(),schema) if schema<4 else restored.export_release_state())==original.export_release_state(),label+" complete exact state and single reward")

func reject(data: Dictionary, target, label: String) -> void:
    var raw: Dictionary = target.export_release_state()
    var edge_ref: Dictionary = target._edges.values()[0]
    var old_wait: float = edge_ref.wait_seconds
    var result: Dictionary = target.import_release_state(data)
    check(not result.ok,label+" rejects")
    check(target.export_release_state()==raw,label+" atomic values")
    edge_ref.wait_seconds += 1.0
    check(target._edges.values()[0].wait_seconds==edge_ref.wait_seconds,label+" original live graph identity preserved")
    edge_ref.wait_seconds = old_wait

func migrations() -> void:
    for old_script in [V1,V2,V3]:
        var old = old_script.new()
        var schema: int = old.RELEASE_SCHEMA
        for state in ["ready","active","paused","queued","relocating","completed"]:
            old = old_script.new()
            if state != "ready": old.accept_contract("first_shift" if schema==1 else "growth_1")
            if state in ["active","paused","queued"]: old.step(8.375)
            if state == "paused": old.time_scale=0.0
            if state == "queued": old.apply_layout("pack_annex")
            if state == "relocating":
                old.step(1.0)
                old.apply_layout("clear_aisle")
                old.step(.05)
                check(old._move_remaining>0.0,"old active relocation fixture "+str(schema))
            if state == "completed": finish(old,"old completed fixture")
            var raw: Dictionary = old.export_release_state()
            var restored = Sim.new()
            var result: Dictionary = restored.import_release_state(raw)
            check(result.ok and result.get("migrated",false) and result.get("source_schema")==schema,"schema%d %s migration flags"%[schema,state])
            if not result.ok: continue
            check(old_fields(restored.export_release_state(),schema)==raw,"schema%d %s exact raw fields"%[schema,state])
            if state == "paused":
                restored.step(1000)
                check(old_fields(restored.export_release_state(),schema)==raw,"paused old progress never advances")
            elif state != "ready": paired_finish(old,restored,schema,"schema%d %s"%[schema,state])
            roundtrip(restored,"schema%d %s current roundtrip"%[schema,state])
            var malformed := raw.duplicate(true)
            malformed.campaign.wallet += 1
            reject(malformed,restored,"old unearned wallet "+str(schema))
    for layout in LAYOUTS:
        for mode in MODES:
            var old = V3.new()
            check(old.import_release_state(fixture).ok,"frozen mature fixture")
            if layout != old.layout_id: check(old.apply_layout(layout).ok,"old matrix layout")
            check(old.set_operation(mode).ok,"old matrix mode")
            check(old.accept_contract("route_hub").ok,"old matrix hub")
            old.step(45.375)
            var raw: Dictionary = old.export_release_state()
            var restored = Sim.new()
            var result: Dictionary = restored.import_release_state(raw)
            check(result.ok,"schema3 matrix imports "+layout+mode+str(result))
            if not result.ok: continue
            check(old_fields(restored.export_release_state(),3)==raw,"schema3 entire payload preserved "+layout+mode)
            aliases(restored,"old matrix "+layout+mode)
            paired_finish(old,restored,3,"old matrix "+layout+mode)
    # Reproduces a valid historical floating-boundary badge; frozen validation
    # may normalize its own copy but migration must preserve the raw input badge.
    var medal = V3.new()
    medal.accept_contract("growth_1")
    finish(medal,"medal fixture")
    var raw: Dictionary = medal.export_release_state()
    var elapsed := 80.00000000000001
    raw.sim.sim_time=elapsed
    raw.campaign.results.growth_1.best_time=elapsed
    raw.campaign.results.growth_1.best_medal="bronze"
    raw.campaign.last_result.elapsed=elapsed
    raw.campaign.last_result.best_time=elapsed
    raw.campaign.last_result.medal="bronze"
    var migrated = Sim.new()
    check(V3.new().import_release_state(raw).ok,"frozen validator accepts legacy boundary medal")
    check(migrated.import_release_state(raw).ok,"raw boundary imports")
    check(old_fields(migrated.export_release_state(),3)==raw,"boundary medal raw fields preserved")
    roundtrip(migrated,"boundary medal later schema4")

func hall_matrix() -> void:
    for plan in ["storage","express"]:
        for layout in LAYOUTS:
            for mode in MODES:
                var label: String = plan+":"+layout+":"+mode
                var sim = Sim.new()
                check(sim.import_release_state(purchased).ok,label+" initial purchased import")
                check(sim.set_hall_plan(plan).ok,label+" selected plan")
                if layout != sim.layout_id: check(sim.apply_layout(layout).ok,label+" layout")
                check(sim.set_operation(mode).ok,label+" operating mode")
                check(sim.bulk_capacity()==(70 if layout in ["compact","split"] else 66)-(16 if plan=="express" else 0),label+" exact capacity")
                check(sim.bulk_bays.filter(func(b):return str(b.id).begins_with("H")).size()==32,label+" fixed hall bay ledger")
                roundtrip(sim,label+" configuration")
                check(sim.accept_contract("route_regional").ok,label+" regional accepted")
                sim.step(45.375)
                observe(sim)
                var restored = roundtrip(sim,label+" in-flight")
                var before: Dictionary = sim.export_release_state()
                check(not sim.set_hall_plan("express" if plan=="storage" else "storage").ok and sim.export_release_state()==before,label+" live switch atomic rejection")
                # Import into a formerly opposite-plan model must discard its
                # revision/path/bay indexes while preserving loaded live movement.
                var reused = Sim.new()
                reused.import_release_state(purchased)
                reused.set_hall_plan("express" if plan=="storage" else "storage")
                reused._find_path("inbound","hall_3_1",true)
                check(reused.import_release_state(before).ok and reused.export_release_state()==before,label+" reused opposite-plan destination")
                aliases(reused,label+" reused destination")
                sim.step(135.0)
                restored.step(135.0)
                check(sim.export_release_state()==restored.export_release_state(),label+" warm/cold caches identical at near-full storage")
                roundtrip(sim,label+" dwell and backlog")
                paired_finish(sim,restored,4,label)
                check(sim.shipped==480 and sim.bulk_shipped==432 and sim.pick_shipped==48,label+" 480 actual units")
                check(sim.last_result.earnings==1200 and sim.contract_results.route_regional.attempts==1,label+" exact reward/attempt")
                var completed: Dictionary = sim.export_release_state()
                check(sim.set_hall_plan("express" if plan=="storage" else "storage").ok,label+" completed switch")
                check(sim.cargo==completed.sim.cargo and sim.manifests==completed.sim.manifests and sim.last_result==completed.campaign.last_result,label+" history and delivered references preserved")
                roundtrip(sim,label+" completed switch roundtrip")
                check(sim.set_hall_plan(plan).ok,label+" repeated switch back")
                roundtrip(sim,label+" repeated switch back roundtrip")
                var wallet: int = sim.campaign_wallet
                sim.accept_contract("route_regional")
                finish(sim,label+" replay")
                check(sim.contract_results.route_regional.attempts==2 and sim.campaign_wallet==wallet+1200,label+" replay reward once")
                rows.append({"plan":plan,"layout":layout,"mode":mode,"seconds":sim.sim_time,"capacity":sim.bulk_capacity()})
                print("matrix "+label+" complete")

func legacy_floor_hall() -> void:
    # Synthetic historically legal schema3 checkpoint retaining the former
    # floor_2 purchase. The frozen validator, not schema4, establishes validity.
    var old = V3.new()
    old.import_release_state(fixture)
    old.purchased_upgrades.append("floor_2")
    old.campaign_wallet -= int(old._upgrade("floor_2").cost)
    old.accept_contract("growth_1")
    finish(old,"legacy floor historical checkpoint")
    var raw: Dictionary=old.export_release_state()
    check(V3.new().import_release_state(raw).ok,"legacy floor fixture is frozen-valid")
    var sim = Sim.new()
    check(sim.import_release_state(raw).ok,"legacy floor fixture migrates")
    while sim.campaign_wallet<Sim.HALL_PRICE:
        sim.accept_contract("route_hub")
        finish(sim,"legacy floor earns hall funds")
    check(sim.buy_hall().ok,"legacy floor player buys hall")
    for plan in ["storage","express"]:
        sim.set_hall_plan(plan)
        for layout in LAYOUTS:
            if sim.layout_id!=layout: sim.apply_layout(layout)
            check(sim.bulk_capacity()==(72 if layout in ["compact","split"] else 68)-(16 if plan=="express" else 0),"legacy floor adds exact two bays "+plan+layout)
            check(not sim._bay("C1").is_empty() and not sim._bay("C2").is_empty(),"legacy floor bay identity retained "+plan+layout)
            roundtrip(sim,"legacy floor plus hall "+plan+layout)

func relocation() -> void:
    for state in ["queued","active","cancel_before","cancel_evacuating"]:
        var sim = Sim.new()
        sim.import_release_state(purchased)
        sim.set_hall_plan("express")
        sim.set_operation("parcel")
        sim.accept_contract("route_regional")
        if state=="cancel_evacuating":
            # Explicit synthetic, strictly validated pre-settlement checkpoint:
            # every regional unit is actually delivered, one idle worker still
            # occupies the future shelf footprint. No invented cargo or reward.
            finish(sim,"evacuation real regional deliveries")
            sim.campaign_status="running"
            sim.finished=false
            # Reconstruct the exact settlement boundary, excluding unused real
            # frame time that a finished model is allowed to retain.
            sim._accumulator=0.0
            sim.campaign_wallet=purchased.campaign.wallet
            sim.completed_count=purchased.campaign.completed_count
            sim.contract_results=purchased.campaign.results.duplicate(true)
            sim.last_result={}
            sim.workers[0].node="bulk_left"
            sim.workers[0].position=sim._points().bulk_left
        elif state!="active": sim.step(20.0)
        check(sim.apply_layout("clear_aisle").ok,"hall relocation "+state)
        if state=="active":
            # Request before the first arrival so actual physical movement can
            # begin immediately rather than merely queuing behind workers.
            sim.step(.05)
            check(sim._move_remaining>0.0,"hall relocation physically active")
        if state=="cancel_before": check(sim.cancel_layout().ok,"cancel hall queued before movement")
        if state=="cancel_evacuating":
            var validated: Dictionary=Sim.new().import_release_state(sim.export_release_state())
            check(validated.ok,"synthetic pre-settlement hall fixture passes strict validation: "+str(validated))
            sim.step(.05)
            check(sim._move_remaining<=0.0 and sim.workers.any(func(w):return w.task=="evacuate"),"hall cancellation evacuation fixture")
            check(sim.cancel_layout().ok,"cancel hall pending evacuation")
            var wallet: int=sim.campaign_wallet
            sim.step(.05)
            check(not sim.finished and sim.campaign_wallet==wallet,"last cargo delivered waits for canceled evacuation before settlement")
        var restored = roundtrip(sim,"hall relocation "+state)
        paired_finish(sim,restored,4,"hall relocation "+state)
        roundtrip(sim,"hall relocation completed "+state)

func malformed() -> void:
    var target = Sim.new()
    target.import_release_state(purchased)
    target.accept_contract("route_regional")
    target.step(45.375)
    var raw: Dictionary = target.export_release_state()
    for kind in ["missing_hall","unknown_hall_field","hall_owned_type","unknown_plan","unowned_plan","no_purchase","duplicate_purchase","unearned_wallet","refund","missing_wing","missing_hub","future_schema","float_schema","string_schema","prototype_envelope","injected_derived_cache","forged_hall_geometry","unknown_bay_node","invalid_queue_owner","nan_clock"]:
        var bad := raw.duplicate(true)
        match kind:
            "missing_hall": bad.erase("hall")
            "unknown_hall_field": bad.hall.price=0
            "hall_owned_type": bad.hall.owned=1
            "unknown_plan": bad.hall.plan="fast"
            "unowned_plan": bad.hall.owned=false
            "no_purchase": bad.campaign.upgrades.erase("regional_hall")
            "duplicate_purchase": bad.campaign.upgrades.append("regional_hall")
            "unearned_wallet": bad.campaign.wallet+=1
            "refund": bad.campaign.wallet+=1800
            "missing_wing": bad.campaign.upgrades.erase("wing_4")
            "missing_hub": bad.campaign.results.erase("route_hub")
            "future_schema": bad.schema=5
            "float_schema": bad.schema=4.0
            "string_schema": bad.schema="4"
            "prototype_envelope": bad={"prototype_schema":1,"hall":bad.hall,"domain":bad}
            "injected_derived_cache": bad.sim._edge_lookup={}
            "forged_hall_geometry": bad.sim.bulk_bays[-1].position.x+=1.0
            "unknown_bay_node": bad.sim.bulk_bays[-1].node="forged_node"
            "invalid_queue_owner": bad.sim._edges.values()[0].queue.append(999)
            "nan_clock": bad.sim.sim_time=NAN
        reject(bad,target,kind)
    for schema in [1,2,3]:
        var bad := fixture.duplicate(true)
        bad.schema=schema
        bad.campaign.upgrades.append("regional_hall")
        reject(bad,target,"old schema forged hall "+str(schema))
        bad=fixture.duplicate(true)
        bad.schema=schema
        bad.campaign.results.route_regional={"best_time":500.0,"best_medal":"gold","attempts":1,"earned":1200}
        reject(bad,target,"old schema forged regional job "+str(schema))
    var unowned = Sim.new()
    var initial: Dictionary = unowned.export_release_state()
    for forged in ["purchase","plan","ownership"]:
        var bad := initial.duplicate(true)
        if forged=="purchase": bad.campaign.upgrades.append("regional_hall")
        if forged=="plan": bad.hall.plan="express"
        if forged=="ownership": bad.hall.owned=true
        reject(bad,target,"unearned ready hall "+forged)
    check(not unowned.buy_hall().ok and not unowned._contract_unlocked("route_regional"),"unearned hall and regional locked")
    aliases(target,"after rejected imports")

func _initialize() -> void:
    check(FileAccess.get_sha256("res://prototype/release_sim.gd")=="7dcfef204d0e1a26f0a088bd6c0aeed764ca0ee46212761b3e7988985e2ad682","frozen schema1 dependency hash")
    check(FileAccess.get_sha256("res://prototype/jobs_sim.gd")=="cfe35051566561dcd21d4b021b19118a66afdd6d9e3f9847fbf32e8066d4dfeb","frozen shared physical dependency hash")
    check(FileAccess.get_sha256("res://prototype/growth_v2_sim.gd")=="fb888e047c279ee5a12b408f949b46e0662094ca89c589a4c2131dd256bd0bee","frozen schema2 dependency hash")
    var original_v3 := FileAccess.get_file_as_string("res://prototype/growth_v3_sim.gd").replace("class_name FlotraGrowthV3Sim","class_name FlotraGrowthSim")
    check(original_v3.sha256_text()=="f3394819b34d6dcfba011db2f5953562871df6c2d0c40519f6074657c459b904","frozen schema3 entire original source hash")
    var input := Fixture.read_required()
    if not input.ok:
        push_error(str(input.error))
        quit(1)
        return
    check(input.sha256==Fixture.SHA256,"earned old fixture hash")
    fixture = input.data
    migrations()
    var earned = Sim.new()
    check(earned.import_release_state(fixture).ok,"earned mature import")
    check(earned.campaign_wallet==970 and earned._contract_unlocked("route_regional"),"earned checkpoint and regional unlock")
    var prior: Dictionary = earned.export_release_state()
    check(not earned.buy_hall().ok and earned.export_release_state()==prior,"earned but insufficient wallet rejected atomically")
    earned.accept_contract("route_hub")
    finish(earned,"one further hub funds hall")
    var prior_result: Dictionary = earned.last_result.duplicate(true)
    check(earned.campaign_wallet==1870,"one hub produces 1870")
    check(earned.buy_upgrade("regional_hall").ok and earned.campaign_wallet==70,"one earned 1800 hall")
    check(earned.last_result==prior_result,"purchase does not rewrite historical result equipment")
    check(is_equal_approx(earned.release_state().growth.area,878.84),"actual 304+2m2 footprint union area")
    prior=earned.export_release_state()
    check(not earned.buy_hall().ok and earned.export_release_state()==prior,"repeat hall purchase rejects atomically")
    purchased=prior
    roundtrip(earned,"immediately purchased")
    malformed()
    hall_matrix()
    legacy_floor_hall()
    relocation()
    for required in ["bulk_store:to_source","bulk_store:work","bulk_store:to_target","bulk_ship:to_source","bulk_ship:work","bulk_ship:to_target","pick:to_source","pick:work","pick:to_target","ship:to_source","ship:work","ship:to_target","exclusive_loaded","parcel_batch","external_backlog","packing","stored_dwell","edge_queue"]:
        check(coverage.has(required),"observed real resume coverage "+required)
    print(JSON.stringify({"suite":"regional_hall_domain_test","checks":checks,"failures":failures,"coverage":coverage,"matrix":rows}))
    quit(0 if failures.is_empty() else 1)
