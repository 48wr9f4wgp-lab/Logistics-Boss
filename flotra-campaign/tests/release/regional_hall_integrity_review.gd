extends SceneTree

# Independent domain-only review. Reads one synthetic fixture; never uses a save
# store, writes campaign data, or modifies any project/domain source.
const Fixture = preload("res://tests/release/regional_hall_fixture.gd")
const Sim = preload("res://prototype/growth_sim.gd")
const Frozen = preload("res://prototype/growth_v3_sim.gd")
const Legacy = preload("res://prototype/release_sim.gd")
const V2 = preload("res://prototype/growth_v2_sim.gd")
var checks := 0
var failures: Array[String] = []
var known_limitations: Array[String] = []
var fixture: Dictionary
var owned_seed: Dictionary

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func finish(sim, label: String) -> bool:
    for second in 3000:
        if sim.finished: break
        sim.step(1.0)
    check(sim.finished and sim.check_invariants().ok, label + " finishes with conserved cargo")
    return sim.finished

func aliases(sim, label: String) -> void:
    var edges_ok := true
    var adjacency_ok := true
    for edge in sim._edges.values():
        for pair in [[edge.a,edge.b],[edge.b,edge.a]]:
            edges_ok = edges_ok and is_same(edge, sim._edge_between(pair[0],pair[1]))
            var found := false
            for indexed in sim._adjacency.get(pair[0],[]):
                if is_same(edge,indexed): found = true
            adjacency_ok = adjacency_ok and found
    check(edges_ok, label + " edge lookup aliases every live reservation dictionary")
    check(adjacency_ok, label + " adjacency aliases every live reservation dictionary")
    var bay_ok := true
    for bay in sim.bulk_bays:
        bay_ok = bay_ok and is_same(bay, sim._bay(bay.id))
    for entry in sim._bay_order:
        bay_ok = bay_ok and is_same(entry.bay,sim._bay(entry.id)) and entry.bay.available
    check(bay_ok, label + " bay indexes alias loaded bay dictionaries")
    check(sim.hall_owned or sim._bay_order.is_empty(), label + " no stale hall bay order")
    if sim.hall_owned:
        check(sim._bay_order.size() == sim.bulk_capacity(), label + " every available hall bay remains allocatable")
    var path: Array = sim._find_path("inbound","outbound",false)
    var path_value := path.duplicate()
    path.clear()
    check(sim._find_path("inbound","outbound",false)==path_value, label + " caller cannot mutate cached path")

func refs(sim) -> Dictionary:
    return {"edges":sim._edges.values(),"bays":sim.bulk_bays.duplicate(),"lookup":sim._edge_lookup.duplicate(),"adjacency":sim._adjacency.duplicate(),"bay_order":sim._bay_order.duplicate()}

func unchanged_refs(sim, old: Dictionary, label: String) -> void:
    var good: bool = old.edges.size()==sim._edges.size() and old.bays.size()==sim.bulk_bays.size()
    for index in old.edges.size(): good = good and is_same(old.edges[index],sim._edges.values()[index])
    for index in old.bays.size(): good = good and is_same(old.bays[index],sim.bulk_bays[index])
    for key in old.lookup: good = good and is_same(old.lookup[key],sim._edge_lookup.get(key))
    for key in old.adjacency: good = good and is_same(old.adjacency[key],sim._adjacency.get(key))
    for index in old.bay_order.size(): good = good and is_same(old.bay_order[index],sim._bay_order[index])
    check(good,label+" preserves live and index reference identity")

func roundtrip(sim, label: String, destination = null) -> void:
    var raw: Dictionary = sim.export_release_state()
    var next = Sim.new() if destination == null else destination
    var result: Dictionary = next.import_release_state(raw)
    check(result.ok,label+" imports: "+str(result))
    if not result.ok: return
    check(next.export_release_state()==raw,label+" preserves whole payload")
    aliases(next,label+" imported")
    var original_refs := refs(next)
    var validated: Dictionary = next._validate_loaded_release()
    check(validated.ok,label+" explicit physical validation: "+str(validated))
    check(next.export_release_state()==raw,label+" physical validation preserves state")
    unchanged_refs(next,original_refs,label+" physical validation")
    aliases(next,label+" post-validation")
    for tick in 80:
        var dt: float = [.017,.113,.037,.283][tick%4]
        sim.step(dt)
        next.step(dt)
    check(next.export_release_state()==sim.export_release_state(),label+" identical irregular continuation")

func rejects(raw: Dictionary, label: String, target) -> void:
    var before: Dictionary = target.export_release_state()
    var original_refs := refs(target)
    var result: Dictionary = target.import_release_state(raw)
    check(not result.get("ok",false),label+" rejected: "+str(result))
    check(before==target.export_release_state(),label+" rejection is exact and atomic")
    unchanged_refs(target,original_refs,label+" rejection")

func historical_reuse() -> void:
    # Reuse a warmed opposite-plan destination; regression coverage for stale
    # point/link revisions and bay-order aliases that value equality misses.
    for script in [Legacy,V2,Frozen]:
        var source = script.new()
        source.accept_contract("first_shift" if script==Legacy else "growth_1")
        source.step(8.375)
        var raw: Dictionary = source.export_release_state()
        var target = Sim.new()
        check(target.import_release_state(owned_seed).ok,"warm owned destination imports")
        check(target.set_hall_plan("express").ok,"warm opposite plan selected")
        target._find_path("hall_0_0","hall_3_3",true)
        target.snapshot()
        var result: Dictionary = target.import_release_state(raw)
        check(result.ok,"schema%d imports into hall-warmed destination: %s"%[raw.schema,result])
        if not result.ok: continue
        var preserved: Dictionary = target.export_release_state()
        preserved.schema = raw.schema
        preserved.erase("hall")
        if raw.schema==1: preserved.erase("growth")
        if raw.schema<=2: preserved.erase("experience")
        check(preserved==raw,"schema%d old fields preserved exactly after warm import"%raw.schema)
        check(var_to_bytes(preserved.sim)==var_to_bytes(raw.sim) and var_to_bytes(preserved.campaign)==var_to_bytes(raw.campaign),"schema%d old simulation and history remain byte-identical"%raw.schema)
        aliases(target,"schema%d warm import"%raw.schema)
        var tick := 0
        while not source.finished and source.sim_time<800:
            var dt: float = [.017,.113,.037,.283][tick%4]
            tick += 1
            source.step(dt)
            target.step(dt)
        check(source.finished and target.finished,"schema%d drains against frozen model"%raw.schema)
        check(target.export_release_state().sim==source.export_release_state().sim,"schema%d physics remains exactly frozen through completion"%raw.schema)
        check(target.export_release_state().campaign==source.export_release_state().campaign,"schema%d wallet/history exactly frozen through completion"%raw.schema)

func mutation_review() -> void:
    var target = Sim.new()
    check(target.import_release_state(owned_seed).ok,"rejection destination imports")
    check(target.set_hall_plan("express").ok,"rejection destination corridor")
    check(target.accept_contract("route_regional").ok,"rejection destination active regional")
    target.step(45.375)
    aliases(target,"active rejection destination")
    var valid: Dictionary = target.export_release_state()
    var mutations: Array = []
    var bad := valid.duplicate(true)
    bad.hall.owned = false
    bad.hall.plan = "storage"
    mutations.append(["false ownership with purchase",bad])
    bad = valid.duplicate(true)
    bad.campaign.upgrades.erase("regional_hall")
    bad.campaign.wallet += Sim.HALL_PRICE
    mutations.append(["true ownership without purchase",bad])
    bad = valid.duplicate(true)
    bad.campaign.upgrades.append("regional_hall")
    bad.campaign.wallet -= Sim.HALL_PRICE
    mutations.append(["duplicate paid ownership",bad])
    bad = valid.duplicate(true)
    bad.campaign.wallet += 1
    mutations.append(["hall refund forgery",bad])
    bad = valid.duplicate(true)
    bad.hall.plan = "corridor"
    mutations.append(["unknown plan alias",bad])
    bad = valid.duplicate(true)
    bad.hall.owned = 1
    mutations.append(["coerced ownership",bad])
    bad = valid.duplicate(true)
    bad.hall.cached_points = {}
    mutations.append(["untrusted derived topology",bad])
    bad = valid.duplicate(true)
    bad.schema = 4.0
    mutations.append(["coerced schema float",bad])
    bad = valid.duplicate(true)
    bad.sim.bulk_bays[-1].node = "inbound"
    mutations.append(["hall bay node forgery",bad])
    bad = valid.duplicate(true)
    bad.sim._edges.values()[-1].capacity += 1
    mutations.append(["hall edge geometry forgery",bad])
    bad = valid.duplicate(true)
    bad.sim.bulk_dwell -= 1.0
    mutations.append(["regional dwell forgery",bad])
    bad = valid.duplicate(true)
    bad.campaign.results.erase("route_hub")
    bad.campaign.completed_count -= 1
    bad.campaign.wallet -= 1800
    mutations.append(["hall without completed hub",bad])
    bad = fixture.duplicate(true)
    bad.campaign.upgrades.append("regional_hall")
    mutations.append(["schema3 forged hall purchase",bad])
    bad = valid.duplicate(true)
    bad.campaign.upgrades.erase("wing_4")
    mutations.append(["hall with only three wings",bad])
    bad = valid.duplicate(true)
    bad.erase("hall")
    mutations.append(["missing hall configuration",bad])
    bad = valid.duplicate(true)
    bad.hall.erase("plan")
    mutations.append(["missing hall plan",bad])
    bad = fixture.duplicate(true)
    bad.campaign.results.route_regional = {"best_time":500.0,"best_medal":"gold","attempts":1,"earned":1200}
    bad.campaign.completed_count += 1
    bad.campaign.wallet += 1200
    mutations.append(["schema3 forged regional history",bad])
    for mutation in mutations: rejects(mutation[1],mutation[0],target)
    var reused = Sim.new()
    check(reused.import_release_state(owned_seed).ok,"warm other-plan import target")
    aliases(reused,"warm storage before corridor import")
    roundtrip(target,"active exact reservations after rejected imports",reused)

func repeated_drained_flows() -> void:
    var sim = Sim.new()
    check(sim.import_release_state(owned_seed).ok,"repeated flow seed")
    for plan in ["storage","express","storage"]:
        check(sim.set_hall_plan(plan).ok,"drained selection "+plan)
        var same: Dictionary = sim.export_release_state()
        var old_refs := refs(sim)
        check(sim.set_hall_plan(plan).ok,"repeated selection "+plan)
        check(sim.export_release_state()==same,"repeated selection preserves exact history "+plan)
        unchanged_refs(sim,old_refs,"repeated selection "+plan)
        roundtrip(sim,"drained plan "+plan)
        check(sim.accept_contract("route_regional").ok,"repeated regional begins "+plan)
        sim.step(45.375)
        var moving: Dictionary = sim.export_release_state()
        check(not sim.set_hall_plan("express" if plan=="storage" else "storage").ok,"moving topology switch rejected "+plan)
        check(sim.export_release_state()==moving,"moving switch leaves exact live state "+plan)
        roundtrip(sim,"moving plan "+plan)
        if not finish(sim,"regional "+plan): return
        roundtrip(sim,"completed regional "+plan)
        var hall_history := {}
        for manifest in sim.manifests.values():
            if str(manifest.bay_id).begins_with("H"): hall_history[manifest.bay_id] = true
        check(hall_history.size()==(32 if plan=="storage" else 16),"completed round exercises every available hall bay "+plan)
        for layout in ["clear_aisle","pack_annex","split","compact"]:
            check(sim.apply_layout(layout).ok,"drained layout changes "+plan+" "+layout)
            roundtrip(sim,"completed layout "+plan+" "+layout)
    # The old public legacy replay cannot preserve a mature growth checkpoint.
    # Hall owners now reject that unsupported transition before any mutation.
    var old = Frozen.new()
    check(old.import_release_state(fixture).ok,"legacy replay baseline fixture")
    var old_attempt: Dictionary = old.accept_contract("first_shift")
    var old_result: Dictionary = Frozen.new().import_release_state(old.export_release_state())
    if old_attempt.ok and not old_result.ok:
        known_limitations.append("Frozen schema3 permits first_shift replay from mature growth, then rejects its export ("+str(old_result.get("detail"))+"). The hall-owned schema4 transition is now rejected atomically; hall-free behavior remains unchanged.")
    var before: Dictionary = sim.export_release_state()
    var old_refs := refs(sim)
    var legacy_attempt: Dictionary = sim.accept_contract("first_shift")
    check(not legacy_attempt.ok and legacy_attempt.get("reason")=="hall_requires_growth_profile","hall-owned legacy replay rejected with bounded reason")
    check(sim.export_release_state()==before,"rejected legacy replay leaves entire checkpoint unchanged")
    unchanged_refs(sim,old_refs,"rejected hall-owned legacy replay")
    roundtrip(sim,"hall state after rejected legacy replay")

func without_hall_prerequisites() -> void:
    var sim = Sim.new()
    check(sim.import_release_state(fixture).ok,"unowned regional seed imports")
    check(not sim.hall_owned and sim._contract_unlocked("route_regional"),"regional work unlocks before hall purchase")
    check(sim.accept_contract("route_regional").ok,"regional without hall starts")
    sim.step(45.375)
    roundtrip(sim,"active regional without hall")
    if finish(sim,"regional without hall"):
        check(not sim.hall_owned and "regional_hall" not in sim.purchased_upgrades,"regional completion does not grant free ownership")
        check(sim.campaign_wallet==int(fixture.campaign.wallet)+1200,"unowned regional pays exact 1200 reward")
        roundtrip(sim,"completed regional without hall")

    # These counterfactual synthetic fixtures remove one historical purchase or
    # reward from the known-earned seed and restart via the public contract API.
    # The frozen validator must accept each resulting old-schema checkpoint.
    var old = Frozen.new()
    check(old.import_release_state(fixture).ok,"three-wing prerequisite seed")
    old.purchased_upgrades.erase("wing_4")
    old.campaign_wallet += int(old._upgrade("wing_4").cost)
    check(old.accept_contract("route_hub").ok,"three wings can run the existing hub")
    var raw: Dictionary = old.export_release_state()
    check(Frozen.new().import_release_state(raw).ok,"three-wing fixture is valid under frozen rules")
    var three = Sim.new()
    check(three.import_release_state(raw).ok,"three-wing fixture migrates")
    check(not three._contract_unlocked("route_regional"),"completed hub with three wings does not unlock regional")
    check(not three.buy_hall().ok,"three-wing active game cannot buy hall")
    if finish(three,"three-wing hub"):
        var before: Dictionary = three.export_release_state()
        var outcome: Dictionary = three.buy_hall()
        check(not outcome.ok and outcome.get("reason")=="four_wings_and_hub_required","completed three-wing game rejects hall prerequisite")
        check(three.export_release_state()==before,"three-wing purchase rejection preserves exact state")

    old = Frozen.new()
    check(old.import_release_state(fixture).ok,"no-hub prerequisite seed")
    old.campaign_wallet -= int(old.contract_results.route_hub.earned)
    old.contract_results.erase("route_hub")
    old.completed_count -= 1
    check(old.accept_contract("growth_1").ok,"no-hub fixture restarts existing paid work")
    raw = old.export_release_state()
    check(Frozen.new().import_release_state(raw).ok,"four-wing no-hub fixture is valid under frozen rules")
    var no_hub = Sim.new()
    check(no_hub.import_release_state(raw).ok,"four-wing no-hub fixture migrates")
    check(not no_hub._contract_unlocked("route_regional"),"four wings without completed hub do not unlock regional")
    if finish(no_hub,"four-wing no-hub starter"):
        var before: Dictionary = no_hub.export_release_state()
        var outcome: Dictionary = no_hub.buy_hall()
        check(not outcome.ok and outcome.get("reason")=="four_wings_and_hub_required","four-wing no-hub game rejects hall prerequisite")
        check(no_hub.export_release_state()==before,"missing-hub purchase rejection preserves exact state")

func _initialize() -> void:
    check(FileAccess.get_sha256("res://prototype/jobs_sim.gd")=="cfe35051566561dcd21d4b021b19118a66afdd6d9e3f9847fbf32e8066d4dfeb","shared legacy physics dependency remains pinned")
    check(FileAccess.get_sha256("res://prototype/growth_v2_sim.gd")=="fb888e047c279ee5a12b408f949b46e0662094ca89c589a4c2131dd256bd0bee","schema2 validator remains frozen")
    check(FileAccess.get_file_as_string("res://prototype/growth_v3_sim.gd").replace("class_name FlotraGrowthV3Sim","class_name FlotraGrowthSim").sha256_text()=="f3394819b34d6dcfba011db2f5953562871df6c2d0c40519f6074657c459b904","schema3 validator differs only in class name")
    var input := Fixture.read_required()
    check(input.ok,"synthetic earned fixture readable and hash-valid")
    if not input.ok:
        push_error(str(input.error))
        quit(1)
        return
    fixture=input.data
    var sim = Sim.new()
    check(sim.import_release_state(fixture).ok,"earned schema3 fixture accepted")
    check(sim.accept_contract("route_hub").ok,"earn one more hub reward")
    if not finish(sim,"earned funding hub"):
        quit(1)
        return
    var before: Dictionary = sim.export_release_state()
    check(sim.buy_hall().ok,"purchase funded hall")
    check(sim.campaign_wallet==before.campaign.wallet-Sim.HALL_PRICE,"single exact hall debit")
    check(sim.last_result==before.campaign.last_result,"purchase preserves previous result")
    check(not sim.buy_hall().ok,"repeated purchase rejected")
    owned_seed=sim.export_release_state()
    roundtrip(sim,"new purchase")
    historical_reuse()
    mutation_review()
    without_hall_prerequisites()
    repeated_drained_flows()
    print(JSON.stringify({"suite":"regional_hall_integrity_review","checks":checks,"failures":failures,"known_limitations":known_limitations}))
    quit(0 if failures.is_empty() else 1)
