extends "res://prototype/jobs_sim.gd"
class_name FlotraReleaseSim

# Bounded campaign layered over the original physical cargo ledger. Contract
# rewards have a separate wallet; base money remains shipment-value accounting.
const RELEASE_SCHEMA := 1
const CAMPAIGN_STARTING_WALLET := 100
const CONTRACTS := [
    {"id":"first_shift","label":"01 はじめての出荷","description":"まとめ便3・単品便3。36個を最後まで届けよう。","manifest_quota":6,"bulk_manifests":3,"pick_manifests":3,"mix":"balanced","interval":4.0,"dwell":18.0,"reward":180,"gold_seconds":145.0,"silver_seconds":210.0},
    {"id":"small_orders","label":"02 小さな注文ラッシュ","description":"まとめ便2・単品便8。棚と梱包の位置を見直そう。","manifest_quota":10,"bulk_manifests":2,"pick_manifests":8,"mix":"pick_heavy","interval":3.0,"dwell":24.0,"reward":260,"gold_seconds":220.0,"silver_seconds":320.0},
    {"id":"pallet_wave","label":"03 パレットの波","description":"まとめ便10・単品便2。保管床の空きが鍵。","manifest_quota":12,"bulk_manifests":10,"pick_manifests":2,"mix":"bulk_heavy","interval":2.5,"dwell":45.0,"reward":300,"gold_seconds":210.0,"silver_seconds":310.0},
    {"id":"packing_rush","label":"04 梱包フル稼働","description":"まとめ便4・単品便12。72個の集品と梱包を回そう。","manifest_quota":16,"bulk_manifests":4,"pick_manifests":12,"mix":"pick_heavy","interval":2.3,"dwell":32.0,"reward":380,"gold_seconds":300.0,"silver_seconds":430.0},
    {"id":"storage_peak","label":"05 保管床の勝負","description":"まとめ便16・単品便4。長い保管時間を乗り越えよう。","manifest_quota":20,"bulk_manifests":16,"pick_manifests":4,"mix":"bulk_heavy","interval":2.0,"dwell":65.0,"reward":450,"gold_seconds":340.0,"silver_seconds":480.0},
    {"id":"final_dispatch","label":"06 最後の大型契約","description":"まとめ便12・単品便12。144個を届けて全契約達成。","manifest_quota":24,"bulk_manifests":12,"pick_manifests":12,"mix":"balanced","interval":1.8,"dwell":50.0,"reward":600,"gold_seconds":360.0,"silver_seconds":510.0},
]
const UPGRADES := [
    {"id":"worker_4","label":"4人目を採用","description":"運搬・集品を行う作業員が3人から4人に。","cost":220,"unlock_after":1},
    {"id":"rack_24","label":"棚を24個に","description":"実際の棚容量が12個から24個に。補充待ちを減らす。","cost":200,"unlock_after":1},
    {"id":"packing_2","label":"梱包台を改善","description":"1個の梱包に必要な時間が3秒から2秒に。","cost":260,"unlock_after":2},
    {"id":"floor_2","label":"増築に保管2枠","description":"増築内の空き床にパレット用の実保管枠C1・C2を追加。","cost":300,"unlock_after":2},
    {"id":"worker_5","label":"5人目を採用","description":"4人目の採用後、作業員を5人に。","cost":420,"unlock_after":3},
]
# Both one-metre squares are entirely inside the existing annex, clear of every
# equipment position and of every transport lane (including trolley radius).
# They share the established pack_annex access face, like paired original bays.
const EXTRA_BAYS := [
    {"id":"C1","position":Vector3(3.6,0,-2.75),"node":"pack_annex"},
    {"id":"C2","position":Vector3(6.4,0,-2.75),"node":"pack_annex"},
]
const SIM_FIELDS := [
    "walk_speed","bulk_dwell","arrival_interval","pack_seconds","rack_capacity",
    "layout_id","workload_id","pending_layout_id","sim_time","duration","time_scale","finished",
    "shipped","bulk_shipped","pick_shipped","revenue","money","arrived","initial_cargo",
    "inbound_blocked","offered_units","open_orders","travel_seconds","loaded_travel_seconds",
    "aisle_wait_seconds","relocation_seconds","relocation_count","stored","picked","packed",
    "workers","cargo","manifests","inbound","external_backlog","bulk_storage","storage","packing",
    "ready","shipped_ids","pack_jobs","comparison","mix_history","relocation_history","bulk_bays",
    "_edges","_next_cargo","_next_manifest","_inbound_timer","_accumulator","_move_remaining",
    "_move_duration","_round_robin","_mix_credit",
]
var campaign_wallet := CAMPAIGN_STARTING_WALLET
var completed_count := 0
var purchased_upgrades: Array[String] = []
var current_contract_id := ""
var campaign_status := "ready"
var manifest_cursor := 0
var contract_results: Dictionary = {}
var last_result: Dictionary = {}

func _init() -> void:
    super()
    _apply_equipment()
    finished = true

func _contract(id: String) -> Dictionary:
    for item in CONTRACTS:
        if item.id == id:
            return item
    return {}

func _upgrade(id: String) -> Dictionary:
    for item in UPGRADES:
        if item.id == id:
            return item
    return {}

func contract_options() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in CONTRACTS.size():
        var option: Dictionary = CONTRACTS[index].duplicate(true)
        var unlocked := _contract_unlocked(str(option.id))
        option.total_units = int(option.manifest_quota) * MANIFEST_SIZE
        option.completed = contract_results.has(option.id)
        option.is_replay = option.completed
        option.available = campaign_status != "running" and unlocked
        option.locked_reason = "作業中の契約を完了してください" if campaign_status == "running" else ("前の契約を完了すると解放" if not unlocked else "")
        option.best_time = float(contract_results.get(option.id, {}).get("best_time", 0.0))
        option.best_medal = str(contract_results.get(option.id, {}).get("best_medal", ""))
        result.append(option)
    return result

func _contract_unlocked(id: String) -> bool:
    match id:
        "first_shift":
            return true
        "small_orders", "pallet_wave":
            return contract_results.has("first_shift")
        "packing_rush", "storage_peak":
            return contract_results.has("small_orders") and contract_results.has("pallet_wave")
        "final_dispatch":
            return contract_results.has("packing_rush") and contract_results.has("storage_peak")
    return false

func upgrade_options() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for definition in UPGRADES:
        var option: Dictionary = definition.duplicate(true)
        option.owned = option.id in purchased_upgrades
        option.available = false
        option.locked_reason = ""
        if option.owned:
            option.locked_reason = "導入済み"
        elif completed_count < int(option.unlock_after):
            option.locked_reason = "契約%d件達成で解放" % int(option.unlock_after)
        elif option.id == "worker_5" and "worker_4" not in purchased_upgrades:
            option.locked_reason = "先に4人目を採用"
        elif campaign_status == "running":
            option.locked_reason = "契約の間に導入できます"
        elif campaign_wallet < int(option.cost):
            option.locked_reason = "資金が%d不足" % (int(option.cost)-campaign_wallet)
        else:
            option.available = true
        result.append(option)
    return result

func accept_contract(id: String) -> Dictionary:
    if campaign_status == "running":
        return {"ok":false,"reason":"contract_in_progress"}
    var definition := _contract(id)
    if definition.is_empty():
        return {"ok":false,"reason":"unknown_contract"}
    if not _contract_unlocked(id):
        return {"ok":false,"reason":"locked_contract"}
    if cargo.size() != shipped or not pending_layout_id.is_empty() or _move_remaining > 0.0:
        return {"ok":false,"reason":"unshipped_cargo"}
    var retained_layout := layout_id
    var retained_speed := time_scale
    current_contract_id = id
    manifest_cursor = 0
    arrival_interval = float(definition.interval)
    bulk_dwell = float(definition.dwell)
    super.restart(str(definition.mix), retained_layout)
    time_scale = retained_speed
    _apply_equipment()
    campaign_status = "running"
    last_result = {}
    return {"ok":true,"contract_id":id,"is_replay":contract_results.has(id)}

func buy_upgrade(id: String) -> Dictionary:
    if _upgrade(id).is_empty():
        return {"ok":false,"reason":"unknown_upgrade"}
    for option in upgrade_options():
        if option.id != id:
            continue
        if not option.available:
            return {"ok":false,"reason":"already_owned" if option.owned else "unavailable","detail":option.locked_reason}
        campaign_wallet -= int(option.cost)
        purchased_upgrades.append(id)
        _apply_equipment()
        return {"ok":true,"upgrade_id":id,"cost":option.cost,"wallet":campaign_wallet}
    return {"ok":false,"reason":"unknown_upgrade"}

func _apply_equipment() -> void:
    rack_capacity = 24 if "rack_24" in purchased_upgrades else 12
    pack_seconds = 2.0 if "packing_2" in purchased_upgrades else 3.0
    var count := 5 if "worker_5" in purchased_upgrades else (4 if "worker_4" in purchased_upgrades else 3)
    # Equipment is applied only between contracts, so adding/removing off-shift
    # workers cannot drop a reservation or carried cargo.
    while workers.size() > count:
        workers.pop_back()
    while workers.size() < count:
        var worker: Dictionary = workers[0].duplicate(true)
        worker.id = workers.size()
        worker.node = "inbound"
        worker.position = POINTS.inbound
        worker.task = "idle"
        worker.phase = "idle"
        worker.cargo_ids = []
        worker.cargo_id = -1
        worker.manifest_id = -1
        worker.bay_id = ""
        worker.carrying = false
        worker.waiting = false
        worker.path = []
        worker.path_index = 0
        worker.edge_id = ""
        worker.edge_from = ""
        worker.edge_to = ""
        worker.edge_progress = 0.0
        worker.work_remaining = 0.0
        worker.source = ""
        worker.target = ""
        worker.travel_seconds = 0.0
        worker.wait_seconds = 0.0
        workers.append(worker)
    if "floor_2" in purchased_upgrades and _bay("C1").is_empty():
        for definition in EXTRA_BAYS:
            var bay: Dictionary = definition.duplicate(true)
            bay.footprint = Rect2(bay.position.x-.5,bay.position.z-.5,1.0,1.0)
            bay.manifest_id = -1
            bay.reserved_by = -1
            bulk_bays.append(bay)
    _round_robin %= workers.size()
    _build_edges()

func set_mix(_next_mix: String) -> Dictionary:
    return {"ok":false,"reason":"contract_mix_fixed"}

func apply_layout(next_layout: String) -> Dictionary:
    if campaign_status == "running":
        return super.apply_layout(next_layout)
    if _option(next_layout).is_empty():
        return {"ok":false,"reason":"unknown"}
    if next_layout == layout_id:
        return {"ok":false,"reason":"same"}
    layout_id = next_layout
    _build_edges()
    return {"ok":true,"pending":false,"cost":0}

func step(real_dt: float) -> void:
    if campaign_status == "running":
        super.step(real_dt)

func _spawn(dt: float) -> void:
    var definition := _contract(current_contract_id)
    if definition.is_empty():
        return
    _inbound_timer -= dt
    while _inbound_timer <= .000001 and manifest_cursor < int(definition.manifest_quota):
        _inbound_timer += arrival_interval
        var kind := _manifest_kind(definition, manifest_cursor)
        _new_manifest(kind)
        manifest_cursor += 1
    if manifest_cursor >= int(definition.manifest_quota):
        _inbound_timer = 0.0
    # Every offered manifest remains in this ledger, including external backlog.
    while not external_backlog.is_empty() and inbound.size() < INBOUND_MANIFEST_LIMIT:
        var id: int = external_backlog.pop_front()
        inbound.append(id)
        manifests[id].stage = "inbound"
        for unit_id in manifests[id].unit_ids:
            cargo[unit_id].stage = "inbound"
        arrived += MANIFEST_SIZE

func _manifest_kind(definition: Dictionary, index: int) -> String:
    var before := int(floor(float(index * int(definition.bulk_manifests))/float(definition.manifest_quota)))
    var after := int(floor(float((index+1) * int(definition.bulk_manifests))/float(definition.manifest_quota)))
    return "bulk" if after > before else "pick"

func _tick(dt: float) -> void:
    super._tick(dt)
    var definition := _contract(current_contract_id)
    if not definition.is_empty() and manifest_cursor == int(definition.manifest_quota) and shipped == int(definition.manifest_quota)*MANIFEST_SIZE and pending_layout_id.is_empty() and _move_remaining <= 0.0:
        _complete_contract(definition)

func _medal(definition: Dictionary, elapsed: float) -> String:
    return "gold" if elapsed <= float(definition.gold_seconds) else ("silver" if elapsed <= float(definition.silver_seconds) else "bronze")

func _complete_contract(definition: Dictionary) -> void:
    finished = true
    var first_completion := not contract_results.has(current_contract_id)
    var previous: Dictionary = contract_results.get(current_contract_id, {})
    var best := minf(float(previous.get("best_time", INF)), sim_time)
    var earned := int(definition.reward) if first_completion else 0
    campaign_wallet += earned
    if first_completion:
        completed_count += 1
    var attempts := int(previous.get("attempts", 0))+1
    contract_results[current_contract_id] = {"best_time":best,"best_medal":_medal(definition,best),"attempts":attempts,"earned":int(definition.reward)}
    last_result = {"contract_id":current_contract_id,"label":definition.label,"elapsed":sim_time,"best_time":best,"medal":_medal(definition,sim_time),"earnings":earned,"first_completion":first_completion,"new_best":sim_time < float(previous.get("best_time", INF)),"shipped":shipped,"total_units":int(definition.manifest_quota)*MANIFEST_SIZE,"worker_count":workers.size(),"layout_id":layout_id,"upgrades":purchased_upgrades.duplicate()}
    campaign_status = "campaign_complete" if completed_count == CONTRACTS.size() else "contract_complete"

func release_state() -> Dictionary:
    var definition := _contract(current_contract_id).duplicate(true)
    var total := int(definition.get("manifest_quota",0))*MANIFEST_SIZE
    var available: Array[String] = []
    for option in contract_options():
        if option.available:
            available.append(str(option.id))
    var objective := "最初の契約を受けよう"
    if campaign_status == "running":
        objective = "残り%d個を出荷する（受付は全%d便で終了）" % [total-shipped,int(definition.manifest_quota)]
    elif completed_count == CONTRACTS.size():
        objective = "全6契約を達成！ 配置を変えてベストタイムに挑戦しよう"
    elif completed_count > 0:
        objective = "設備と配置を選び、次の契約を受けよう"
    return {"schema":RELEASE_SCHEMA,"status":campaign_status,"wallet":campaign_wallet,"completed_count":completed_count,"total_contracts":CONTRACTS.size(),"campaign_complete":completed_count==CONTRACTS.size(),"current_contract":definition,"current_contract_id":current_contract_id,"progress":{"shipped":shipped,"total":total,"offered":offered_units,"manifests_offered":manifest_cursor,"manifest_quota":int(definition.get("manifest_quota",0)),"remaining":maxi(0,total-shipped),"fraction":float(shipped)/float(total) if total>0 else 0.0},"elapsed":sim_time,"best_time":float(contract_results.get(current_contract_id,{}).get("best_time",0.0)),"last_earnings":int(last_result.get("earnings",0)),"last_result":last_result.duplicate(true),"objective":objective,"available":available,"upgrades":purchased_upgrades.duplicate(),"worker_count":workers.size(),"results":contract_results.duplicate(true)}

func snapshot() -> Dictionary:
    var state := super.snapshot()
    state.prototype = false
    state.continuous = false
    state.release = release_state()
    state.budget_description = "棚%d個・梱包%.0f秒・%d人・床%d枠" % [rack_capacity,pack_seconds,workers.size(),bulk_bays.size()]
    state.equipment_signature = "rack%d:1;bench%.1fs:1;workers:%d;pallet_floor:%d;annex:1" % [rack_capacity,pack_seconds,workers.size(),bulk_bays.size()]
    for slot in state.slots:
        if slot.id == "shelf":
            for choice in slot.choices:
                var count := bulk_capacity("compact" if choice.id == "core" else "clear_aisle")
                choice.label = ("主棟" if choice.id == "core" else "増築") + "・保管%d枠" % count
                if choice.id == "core":
                    choice.benefit = "まとめ保管%d枠" % count
                else:
                    choice.tradeoff = "まとめ保管%d枠・棚が床4枠を使う" % count
    return state

func export_release_state() -> Dictionary:
    var simulation := {}
    for field in SIM_FIELDS:
        var value = get(field)
        simulation[field] = value.duplicate(true) if value is Array or value is Dictionary else value
    return {"schema":RELEASE_SCHEMA,"campaign":{"wallet":campaign_wallet,"completed_count":completed_count,"upgrades":purchased_upgrades.duplicate(),"current_contract_id":current_contract_id,"status":campaign_status,"manifest_cursor":manifest_cursor,"results":contract_results.duplicate(true),"last_result":last_result.duplicate(true)},"sim":simulation}

func import_release_state(data: Dictionary) -> Dictionary:
    # Validate into a disposable instance; a rejected save never mutates this run.
    var validation := _validate_save_shape(data)
    if not validation.ok:
        return validation
    var candidate = get_script().new()
    candidate._load_release_unchecked(data)
    var result: Dictionary = candidate._validate_loaded_release()
    if not result.ok:
        return result
    _load_release_unchecked(data)
    return {"ok":true,"schema":RELEASE_SCHEMA}

func _load_release_unchecked(data: Dictionary) -> void:
    var campaign: Dictionary = data.campaign
    campaign_wallet = campaign.wallet
    completed_count = campaign.completed_count
    purchased_upgrades.assign(campaign.upgrades)
    current_contract_id = campaign.current_contract_id
    campaign_status = campaign.status
    manifest_cursor = campaign.manifest_cursor
    contract_results = campaign.results.duplicate(true)
    last_result = campaign.last_result.duplicate(true)
    for field in SIM_FIELDS:
        var value = data.sim[field]
        set(field,value.duplicate(true) if value is Array or value is Dictionary else value)

func _bad(reason: String) -> Dictionary:
    return {"ok":false,"reason":"invalid_save","detail":reason}

func _safe_variant(value, depth: int = 0) -> bool:
    if depth > 20:
        return false
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME, TYPE_RECT2, TYPE_VECTOR3:
            if value is String or value is StringName:
                return str(value).length() <= 1000
            if value is Vector3:
                return value.is_finite()
            if value is Rect2:
                return value.position.is_finite() and value.size.is_finite()
            return true
        TYPE_FLOAT:
            return is_finite(value)
        TYPE_ARRAY:
            if value.size() > 10000:
                return false
            for item in value:
                if not _safe_variant(item,depth+1):
                    return false
            return true
        TYPE_DICTIONARY:
            if value.size() > 10000:
                return false
            for key in value:
                if typeof(key) not in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT]:
                    return false
                if not _safe_variant(value[key],depth+1):
                    return false
            return true
    return false

func _keys_and_types(value: Dictionary, template: Dictionary) -> bool:
    if value.size() != template.size():
        return false
    for key in template:
        if not value.has(key) or typeof(value[key]) != typeof(template[key]):
            return false
    return true

func _validate_save_shape(data: Dictionary) -> Dictionary:
    if not _safe_variant(data) or not _keys_and_types(data,{"schema":1,"campaign":{},"sim":{}}) or data.schema != RELEASE_SCHEMA:
        return _bad("schema")
    var campaign: Dictionary = data.campaign
    if not _keys_and_types(campaign,{"wallet":0,"completed_count":0,"upgrades":[],"current_contract_id":"","status":"","manifest_cursor":0,"results":{},"last_result":{}}):
        return _bad("campaign_shape")
    for id in campaign.upgrades:
        if not id is String:
            return _bad("upgrade_type")
    for id in campaign.results:
        if not id is String or _contract(id).is_empty():
            return _bad("unknown_result")
    if not campaign.last_result.is_empty():
        var expected_result := {"contract_id":"","label":"","elapsed":0.0,"best_time":0.0,"medal":"","earnings":0,"first_completion":false,"new_best":false,"shipped":0,"total_units":0,"worker_count":0,"layout_id":"","upgrades":[]}
        if not _keys_and_types(campaign.last_result,expected_result):
            return _bad("last_result_shape")
        for id in campaign.last_result.upgrades:
            if not id is String or _upgrade(id).is_empty():
                return _bad("last_result_upgrade")
    var simulation: Dictionary = data.sim
    if simulation.size() != SIM_FIELDS.size():
        return _bad("sim_fields")
    for field in SIM_FIELDS:
        if not simulation.has(field) or typeof(simulation[field]) != typeof(get(field)):
            return _bad("sim_type_"+field)
    for field in ["inbound","external_backlog","bulk_storage","storage","packing","ready","shipped_ids"]:
        for value in simulation[field]:
            if not value is int:
                return _bad("queue_type")
    var worker_template: Dictionary = workers[0]
    if simulation.workers.size() < 3 or simulation.workers.size() > 5:
        return _bad("worker_count")
    for worker in simulation.workers:
        if not worker is Dictionary or not _keys_and_types(worker,worker_template):
            return _bad("worker_shape")
    for item in simulation.cargo.values():
        if not item is Dictionary or not _keys_and_types(item,{"id":0,"manifest_id":0,"kind":"","ordinal":0,"stage":"","node":"","worker_id":0,"bay_id":"","created_at":0.0,"stored_at":0.0,"picked_at":0.0,"packed_at":0.0,"shipped_at":0.0}):
            return _bad("cargo_shape")
    for manifest in simulation.manifests.values():
        if not manifest is Dictionary or not _keys_and_types(manifest,{"id":0,"kind":"","unit_ids":[],"size":0,"hold_seconds":0.0,"stage":"","mix_id":"","created_at":0.0,"stored_at":0.0,"release_at":0.0,"completed_at":0.0,"bay_id":"","shipped_units":0}):
            return _bad("manifest_shape")
    for bay in simulation.bulk_bays:
        if not bay is Dictionary or not _keys_and_types(bay,bulk_bays[0]):
            return _bad("bay_shape")
    for edge in simulation._edges.values():
        if not edge is Dictionary or not _keys_and_types(edge,_edges.values()[0]):
            return _bad("edge_shape")
    for job in simulation.pack_jobs:
        if not job is Dictionary or not _keys_and_types(job,{"cargo_id":0,"remaining":0.0}):
            return _bad("packing_shape")
    for row in simulation.mix_history:
        if not row is Dictionary or not _keys_and_types(row,{"at":0.0,"mix_id":"","first_manifest":0}):
            return _bad("mix_history_shape")
    for row in simulation.relocation_history:
        if not row is Dictionary or row.size() not in [5,6] or not row.has_all(["requested_at","from","to","started_at","completed_at"]):
            return _bad("relocation_history_shape")
        for key in row:
            if key in ["from","to"]:
                if not row[key] is String or _option(row[key]).is_empty():
                    return _bad("relocation_layout")
            elif key not in ["requested_at","started_at","completed_at","downtime"] or not row[key] is float:
                return _bad("relocation_time")
    return {"ok":true}

func _validate_loaded_release() -> Dictionary:
    if campaign_status not in ["ready","running","contract_complete","campaign_complete"] or completed_count < 0 or completed_count > CONTRACTS.size():
        return _bad("campaign_status")
    if contract_results.size() != completed_count:
        return _bad("completion_count")
    var expected_wallet := CAMPAIGN_STARTING_WALLET
    for index in CONTRACTS.size():
        var definition: Dictionary = CONTRACTS[index]
        if contract_results.has(definition.id) and not _contract_unlocked(str(definition.id)):
            return _bad("completion_order")
        if contract_results.has(definition.id):
            var result = contract_results[definition.id]
            if not result is Dictionary or not _keys_and_types(result,{"best_time":0.0,"best_medal":"","attempts":0,"earned":0}):
                return _bad("result_shape")
            if result.best_time <= 0.0 or result.attempts < 1 or result.earned != definition.reward or result.best_medal != _medal(definition,result.best_time):
                return _bad("result_value")
            expected_wallet += int(result.earned)
    var seen_upgrades := {}
    for id in purchased_upgrades:
        var upgrade := _upgrade(id)
        if upgrade.is_empty() or seen_upgrades.has(id) or completed_count < int(upgrade.unlock_after):
            return _bad("upgrade_unlock")
        seen_upgrades[id] = true
        expected_wallet -= int(upgrade.cost)
    if "worker_5" in purchased_upgrades and "worker_4" not in purchased_upgrades:
        return _bad("worker_prerequisite")
    if campaign_wallet != expected_wallet or campaign_wallet < 0:
        return _bad("wallet")
    var expected_workers := 5 if "worker_5" in purchased_upgrades else (4 if "worker_4" in purchased_upgrades else 3)
    if workers.size() != expected_workers or rack_capacity != (24 if "rack_24" in purchased_upgrades else 12) or pack_seconds != (2.0 if "packing_2" in purchased_upgrades else 3.0) or walk_speed != WALK_SPEED:
        return _bad("equipment")
    if _option(layout_id).is_empty() or _workload(workload_id).is_empty() or (not pending_layout_id.is_empty() and _option(pending_layout_id).is_empty()) or time_scale < 0.0 or time_scale > 12.0 or duration != 0.0 or sim_time < 0.0 or sim_time > 10000000.0:
        return _bad("simulation_parameters")
    if finished != (campaign_status != "running") or _round_robin < 0 or _round_robin >= workers.size() or _accumulator < 0.0 or (not finished and _accumulator > TICK+0.00001) or _accumulator > 100000000.0 or _move_remaining < 0.0 or _move_remaining > _move_duration:
        return _bad("simulation_clock")
    var definition := _contract(current_contract_id)
    if campaign_status == "ready":
        if not current_contract_id.is_empty() or completed_count != 0 or not cargo.is_empty() or manifest_cursor != 0 or sim_time != 0.0:
            return _bad("ready_state")
    elif definition.is_empty() or not _contract_unlocked(current_contract_id):
        return _bad("current_contract")
    else:
        if arrival_interval != float(definition.interval) or bulk_dwell != float(definition.dwell) or workload_id != str(definition.mix) or manifest_cursor < 0 or manifest_cursor > int(definition.manifest_quota):
            return _bad("contract_parameters")
        if _inbound_timer < 0.0 or _inbound_timer > arrival_interval:
            return _bad("arrival_clock")
        if campaign_status != "running" and (shipped != int(definition.manifest_quota)*MANIFEST_SIZE or not contract_results.has(current_contract_id) or not pending_layout_id.is_empty()):
            return _bad("incomplete_cargo")
    if (campaign_status == "campaign_complete") != (completed_count == CONTRACTS.size() and campaign_status != "running"):
        return _bad("campaign_completion")
    if campaign_status in ["ready","running"]:
        if not last_result.is_empty():
            return _bad("unexpected_last_result")
    else:
        if last_result.is_empty() or last_result.contract_id != current_contract_id or last_result.label != definition.label or last_result.elapsed != sim_time or last_result.best_time != contract_results[current_contract_id].best_time or last_result.medal != _medal(definition,sim_time) or last_result.earnings != (int(definition.reward) if last_result.first_completion else 0) or last_result.shipped != shipped or last_result.total_units != shipped or last_result.worker_count not in [3,4,5] or _option(last_result.layout_id).is_empty():
            return _bad("last_result_value")
        var result_upgrades := {}
        for id in last_result.upgrades:
            if id not in purchased_upgrades or result_upgrades.has(id):
                return _bad("last_result_upgrade")
            result_upgrades[id] = true
    if _move_remaining > 0.0 and pending_layout_id.is_empty():
        return _bad("relocation_destination")
    if not pending_layout_id.is_empty():
        if relocation_history.is_empty() or relocation_history[-1].to != pending_layout_id or relocation_history[-1].from != layout_id or relocation_history[-1].completed_at != -1.0:
            return _bad("relocation_history")
        if _move_remaining > 0.0 and (not relocation_history[-1].has("downtime") or relocation_history[-1].started_at < 0.0):
            return _bad("relocation_started")
    elif not relocation_history.is_empty() and relocation_history[-1].completed_at < 0.0:
        return _bad("relocation_unfinished")
    if manifests.size() != manifest_cursor or cargo.size() != manifest_cursor*MANIFEST_SIZE or _next_manifest != manifest_cursor+1 or _next_cargo != cargo.size()+1:
        return _bad("manifest_counter")
    for field in ["shipped","bulk_shipped","pick_shipped","revenue","money","arrived","initial_cargo","inbound_blocked","offered_units","open_orders","travel_seconds","loaded_travel_seconds","aisle_wait_seconds","relocation_seconds","relocation_count","stored","picked","packed"]:
        if get(field) < 0:
            return _bad("negative_"+field)
    var expected_bays: Array = BAY_DEFS.duplicate(true)
    if "floor_2" in purchased_upgrades:
        expected_bays.append_array(EXTRA_BAYS)
    if bulk_bays.size() != expected_bays.size():
        return _bad("bay_count")
    for index in bulk_bays.size():
        var bay: Dictionary = bulk_bays[index]
        var expected: Dictionary = expected_bays[index]
        if bay.id != expected.id or bay.position != expected.position or bay.node != expected.node or bay.footprint != Rect2(expected.position.x-.5,expected.position.z-.5,1.0,1.0) or bay.available != _bay_available_in(bay,layout_id):
            return _bad("bay_geometry")
        if (bay.manifest_id != -1 and not manifests.has(bay.manifest_id)) or bay.reserved_by < -1 or bay.reserved_by >= workers.size():
            return _bad("bay_reference")
    for id in range(1,manifest_cursor+1):
        if not manifests.has(id):
            return _bad("missing_manifest")
        var manifest: Dictionary = manifests[id]
        if manifest.id != id or manifest.kind != _manifest_kind(definition,id-1) or manifest.size != MANIFEST_SIZE or manifest.hold_seconds != (bulk_dwell if manifest.kind=="bulk" else 0.0) or manifest.mix_id != workload_id or manifest.unit_ids.size() != MANIFEST_SIZE:
            return _bad("manifest_identity")
        if manifest.stage not in ["external","inbound","bulk_store","bulk_storage","bulk_ship","restock","unit_fulfillment","completed"] or (not str(manifest.bay_id).is_empty() and _bay(manifest.bay_id).is_empty()):
            return _bad("manifest_stage")
        for ordinal in MANIFEST_SIZE:
            var unit_id := (id-1)*MANIFEST_SIZE+ordinal+1
            if manifest.unit_ids[ordinal] != unit_id or not cargo.has(unit_id):
                return _bad("manifest_units")
            var item: Dictionary = cargo[unit_id]
            if item.id != unit_id or item.manifest_id != id or item.kind != manifest.kind or item.ordinal != ordinal or not POINTS.has(item.node) or item.worker_id < -1 or item.worker_id >= workers.size() or (not str(item.bay_id).is_empty() and _bay(item.bay_id).is_empty()):
                return _bad("cargo_reference")
    for field in ["inbound","external_backlog","bulk_storage"]:
        for id in get(field):
            if not manifests.has(id):
                return _bad("manifest_queue_reference")
    for field in ["storage","packing","ready","shipped_ids"]:
        for id in get(field):
            if not cargo.has(id):
                return _bad("unit_queue_reference")
    for job in pack_jobs:
        if not cargo.has(job.cargo_id) or job.remaining < 0.0 or job.remaining > pack_seconds:
            return _bad("packing_reference")
    if pack_jobs.size() > 1:
        return _bad("packing_capacity")
    for index in workers.size():
        var worker: Dictionary = workers[index]
        if worker.id != index or (worker.phase == "idle") != (worker.task == "idle") or worker.phase not in ["idle","to_source","work","to_target"] or worker.task not in ["idle","evacuate","bulk_store","bulk_ship","restock","pick","ship"] or not POINTS.has(worker.node) or worker.edge_progress < 0.0 or worker.edge_progress > 1.0 or worker.path_index < 0 or (worker.phase != "idle" and worker.path_index > worker.path.size()) or worker.lane not in [0,1]:
            return _bad("worker_state")
        if (worker.manifest_id != -1 and not manifests.has(worker.manifest_id)) or (worker.cargo_id != -1 and not cargo.has(worker.cargo_id)) or (not str(worker.bay_id).is_empty() and _bay(worker.bay_id).is_empty()):
            return _bad("worker_reference")
        for node in worker.path:
            if not node is String or not POINTS.has(node):
                return _bad("worker_path")
        for path_index in maxi(0,worker.path.size()-1):
            var edge := _edge_between(worker.path[path_index],worker.path[path_index+1])
            if edge.is_empty() or edge.capacity <= 0:
                return _bad("worker_disconnected_path")
        if worker.phase != "idle":
            if str(worker.source).is_empty() and worker.task != "evacuate":
                return _bad("worker_source")
            if str(worker.target).is_empty() or (worker.task != "evacuate" and (worker.manifest_id < 1 or worker.cargo_ids.is_empty())):
                return _bad("worker_target_or_load")
        for field in ["source","target","edge_from","edge_to"]:
            if not str(worker[field]).is_empty() and not POINTS.has(worker[field]):
                return _bad("worker_node")
        if not str(worker.edge_id).is_empty() and not _edges.has(worker.edge_id):
            return _bad("worker_edge")
        if worker.task not in ["idle","evacuate"]:
            var expected_size := MANIFEST_SIZE if worker.task in ["bulk_store","bulk_ship","restock"] else 1
            if worker.cargo_ids.size() != expected_size or worker.cargo_id != worker.cargo_ids[0] or worker.carrying != (worker.phase in ["work","to_target"]):
                return _bad("worker_load_shape")
        for id in worker.cargo_ids:
            if not id is int or not cargo.has(id) or cargo[id].worker_id != index:
                return _bad("worker_cargo")
            var expected_stage := ("reserved_" if worker.phase == "to_source" else "carried_")+str(worker.task)
            if cargo[id].stage != expected_stage or cargo[id].manifest_id != worker.manifest_id:
                return _bad("worker_cargo_stage")
        if worker.phase == "idle" and (not worker.cargo_ids.is_empty() or not str(worker.edge_id).is_empty()):
            return _bad("idle_worker_cargo")
    # The static graph must be exactly reproducible; preserve only its live
    # reservations/queues after checking, never rebuild over a loaded movement.
    var live_edges := _edges.duplicate(true)
    _build_edges()
    var expected_edges := _edges.duplicate(true)
    _edges = live_edges
    if live_edges.size() != expected_edges.size():
        return _bad("graph_size")
    for key in expected_edges:
        if not live_edges.has(key):
            return _bad("graph_key")
        var edge: Dictionary = live_edges[key]
        var static_edge := edge.duplicate(true)
        static_edge.owners = []
        static_edge.queue = []
        static_edge.wait_seconds = 0.0
        if static_edge != expected_edges[key] or edge.wait_seconds < 0.0:
            return _bad("graph_geometry")
        for collection in [edge.owners,edge.queue]:
            var seen := {}
            for owner in collection:
                if not owner is int or owner < 0 or owner >= workers.size() or seen.has(owner):
                    return _bad("edge_reference")
                seen[owner] = true
        for owner in edge.queue:
            if not str(workers[owner].edge_id).is_empty():
                return _bad("queued_worker_moving")
    for worker in workers:
        if not str(worker.edge_id).is_empty():
            var edge: Dictionary = _edges[worker.edge_id]
            if worker.id not in edge.owners or worker.path_index >= worker.path.size()-1 or worker.edge_from != worker.path[worker.path_index] or worker.edge_to != worker.path[worker.path_index+1]:
                return _bad("worker_unowned_edge")
    for pair in [[inbound,"inbound"],[external_backlog,"external"],[bulk_storage,"bulk_storage"]]:
        for id in pair[0]:
            if manifests[id].stage != pair[1]:
                return _bad("manifest_queue_stage")
            for unit in manifests[id].unit_ids:
                if cargo[unit].stage != pair[1] or cargo[unit].worker_id != -1:
                    return _bad("manifest_unit_stage")
    for pair in [[storage,"storage"],[packing,"packing_queue"],[ready,"packed"],[shipped_ids,"shipped"]]:
        for id in pair[0]:
            if cargo[id].stage != pair[1] or cargo[id].worker_id != -1:
                return _bad("unit_queue_stage")
    for job in pack_jobs:
        if cargo[job.cargo_id].stage != "packing" or cargo[job.cargo_id].worker_id != -1:
            return _bad("packing_stage")
    var invariant := check_invariants()
    if not invariant.ok:
        return _bad(str(invariant))
    return {"ok":true}
