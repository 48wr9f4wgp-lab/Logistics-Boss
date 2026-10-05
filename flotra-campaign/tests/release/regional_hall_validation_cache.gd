extends SceneTree
const Sim = preload("res://prototype/growth_sim.gd")
const V1 = preload("res://prototype/release_sim.gd")
const V2 = preload("res://prototype/growth_v2_sim.gd")
const V3 = preload("res://prototype/growth_v3_sim.gd")
class Probe extends "res://prototype/growth_sim.gd":
    static var scratch_loads := 0
    static var scratch_aliases := true
    func _load_release_unchecked(data: Dictionary, prepare_routes: bool = true) -> void:
        super._load_release_unchecked(data,prepare_routes)
        if not prepare_routes:
            scratch_loads+=1
            scratch_aliases = scratch_aliases and _bay_order.is_empty()
            for edge in _edges.values(): scratch_aliases = scratch_aliases and is_same(edge,_edge_between(edge.a,edge.b))
            for bay in bulk_bays: scratch_aliases = scratch_aliases and is_same(bay,_bay(bay.id))
var checks := 0
var failures: Array = []
func check(ok: bool, label: String) -> void:
    checks+=1
    if not ok:
        failures.append(label)
        push_error(label)
func finish(sim) -> void:
    while not sim.finished and sim.sim_time<3000: sim.step(1.0)
    check(sim.finished and sim.check_invariants().ok,"real earned fixture drains")
func deeply_read_only(value: Variant) -> bool:
    if value is Dictionary:
        if not value.is_read_only(): return false
        for item in value.values():
            if not deeply_read_only(item): return false
    elif value is Array:
        if not value.is_read_only(): return false
        for item in value:
            if not deeply_read_only(item): return false
    return true
func parity(raw: Dictionary, target, expect_ok: bool, label: String) -> void:
    var before: Dictionary=target.export_release_state()
    var refs: Array=target._edges.values()
    var bay_refs: Array=target.bulk_bays.duplicate()
    var preflight: Dictionary=target.validate_release_state(raw)
    var loaded=Sim.new()
    var imported: Dictionary=loaded.import_release_state(raw)
    check(preflight==imported and preflight.ok==expect_ok,label+" identical complete acceptance flags")
    check(not preflight.has("staged"),label+" no internal candidate returned")
    check(target.export_release_state()==before,label+" validation leaves live payload untouched")
    var unchanged:=true
    for i in refs.size(): unchanged=unchanged and is_same(refs[i],target._edges.values()[i])
    for i in bay_refs.size(): unchanged=unchanged and is_same(bay_refs[i],target.bulk_bays[i])
    check(unchanged,label+" validation leaves live aliases untouched")
    if expect_ok:
        var normalized: Dictionary=raw.duplicate(true)
        if raw.schema<4:
            if raw.schema==1: normalized.growth={"legacy_profile":true}
            if raw.schema<=2: normalized.experience={"operating_profile":false,"operation_mode":"balanced","preferences":{"preferred_speed":2,"pause_on_menus":false,"reduced_motion":false}}
            normalized.hall={"owned":false,"plan":"storage"}
            normalized.schema=4
        check(loaded.export_release_state()==normalized,label+" accepted export exactly raw-plus-required-fields")
        var expected: Dictionary=loaded._expected_static_edges()
        check(deeply_read_only(expected),label+" recursively immutable expected geometry")
        check(is_same(expected,loaded._expected_static_edges()),label+" same trusted geometry cache reused")
        # Duplicates are independent; no live/reference route ever aliases the
        # trusted graph. Mutating the caller's copy cannot poison later checks.
        var copied:=expected.duplicate(true)
        copied.values()[0].capacity=999
        check(expected.values()[0].capacity!=999 and loaded._validate_loaded_release().ok,label+" caller copy cannot poison cache")
        for edge in loaded._edges.values():
            check(not is_same(edge,expected[edge.id]),label+" no live edge aliases frozen geometry")
func _initialize() -> void:
    var path:=ProjectSettings.globalize_path("res://").path_join("../build/prototype-reference/postcap/earned_fixture.var")
    var fixture: Dictionary=FileAccess.open(path,FileAccess.READ).get_var()
    var earned=Sim.new()
    check(earned.import_release_state(fixture).ok,"earned fixture")
    earned.accept_contract("route_hub")
    finish(earned)
    var unowned: Dictionary=earned.export_release_state()
    check(earned.buy_hall().ok,"earned hall")
    var owned: Dictionary=earned.export_release_state()
    var target=Probe.new()
    target.import_release_state(owned)
    target.set_hall_plan("express")
    target.accept_contract("route_regional")
    target.step(45.375)
    for script in [V1,V2,V3]:
        var old=script.new()
        parity(old.export_release_state(),target,true,"old schema%d ready"%old.RELEASE_SCHEMA)
        old.accept_contract("first_shift" if old.RELEASE_SCHEMA==1 else "growth_1")
        old.step(8.375)
        parity(old.export_release_state(),target,true,"old schema%d active"%old.RELEASE_SCHEMA)
        var bad: Dictionary=old.export_release_state()
        bad.campaign.wallet+=1
        parity(bad,target,false,"old schema%d malformed"%old.RELEASE_SCHEMA)
    for plan in ["unowned","storage","express"]:
        for layout in ["compact","clear_aisle","pack_annex","split"]:
            var source=Sim.new()
            source.import_release_state(unowned if plan=="unowned" else owned)
            if plan!="unowned": source.set_hall_plan(plan)
            if source.layout_id!=layout: source.apply_layout(layout)
            source.accept_contract("route_regional")
            source.step(45.375)
            var raw: Dictionary=source.export_release_state()
            var label: String=plan+":"+layout
            parity(raw,target,true,label)
            for mutation in ["static_endpoint","capacity","missing_edge","graph_id","hall_configuration","injected_cache","queue_owner","wallet"]:
                var bad:=raw.duplicate(true)
                match mutation:
                    "static_endpoint": bad.sim._edges.values()[0].to.x+=.125
                    "capacity": bad.sim._edges.values()[0].capacity=999
                    "missing_edge": bad.sim._edges.erase(bad.sim._edges.keys()[0])
                    "graph_id": bad.sim._edges.values()[0].id="forged"
                    "hall_configuration": bad.hall.plan="express" if plan!="express" else "storage"
                    "injected_cache": bad._static_graph_templates={}
                    "queue_owner": bad.sim._edges.values()[0].queue.append(999)
                    "wallet": bad.campaign.wallet+=1
                parity(bad,target,false,label+" warm poison "+mutation)
            # The same reused destination crosses all plans/layouts while the
            # trusted expected cache persists globally. Live indexes stay fresh.
            check(target.import_release_state(raw).ok,label+" reused destination import")
            check(target._validate_loaded_release().ok and target.export_release_state()==raw,label+" no stale topology or cargo")
            check(target._bay_order.size()==target.bulk_capacity() if target.hall_owned else target._bay_order.is_empty(),label+" committed destination has complete playable bay order")
    # Warm templates must also distinguish every bounded pre-hall wing count.
    var growing=Sim.new()
    for n in range(1,7):
        growing.accept_contract("growth_%d"%n)
        finish(growing)
    for wing in range(0,5):
        if wing>0:
            var id: String="wing_%d"%wing
            while growing.campaign_wallet<int(growing._upgrade(id).cost):
                growing.accept_contract("growth_1")
                finish(growing)
            check(growing.buy_upgrade(id).ok,"earned progressive topology "+id)
        for layout in ["compact","clear_aisle","pack_annex","split"]:
            if growing.layout_id!=layout: growing.apply_layout(layout)
            parity(growing.export_release_state(),target,true,"wing%d:%s"%[wing,layout])
    check(Probe.scratch_loads>0 and Probe.scratch_aliases,"scratch validation skips only unused route ordering and retains every live alias")
    print(JSON.stringify({"suite":"regional_hall_validation_cache","checks":checks,"failures":failures,"scratch_validations":Probe.scratch_loads}))
    quit(0 if failures.is_empty() else 1)
