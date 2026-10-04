extends "res://prototype/jobs_sim.gd"
class_name FlotraGrowthV2Sim

# Bounded campaign layered over the original physical cargo ledger. Contract
# rewards have a separate wallet; base money remains shipment-value accounting.
const RELEASE_SCHEMA := 2
const CAMPAIGN_STARTING_WALLET := 100
const LEGACY_CONTRACTS := [
    {"id":"first_shift","label":"01 はじめての出荷","description":"まとめ便3・単品便3。36個を最後まで届けよう。","manifest_quota":6,"bulk_manifests":3,"pick_manifests":3,"mix":"balanced","interval":4.0,"dwell":18.0,"reward":180,"gold_seconds":145.0,"silver_seconds":210.0},
    {"id":"small_orders","label":"02 小さな注文ラッシュ","description":"まとめ便2・単品便8。棚と梱包の位置を見直そう。","manifest_quota":10,"bulk_manifests":2,"pick_manifests":8,"mix":"pick_heavy","interval":3.0,"dwell":24.0,"reward":260,"gold_seconds":220.0,"silver_seconds":320.0},
    {"id":"pallet_wave","label":"03 パレットの波","description":"まとめ便10・単品便2。保管床の空きが鍵。","manifest_quota":12,"bulk_manifests":10,"pick_manifests":2,"mix":"bulk_heavy","interval":2.5,"dwell":45.0,"reward":300,"gold_seconds":210.0,"silver_seconds":310.0},
    {"id":"packing_rush","label":"04 梱包フル稼働","description":"まとめ便4・単品便12。72個の集品と梱包を回そう。","manifest_quota":16,"bulk_manifests":4,"pick_manifests":12,"mix":"pick_heavy","interval":2.3,"dwell":32.0,"reward":380,"gold_seconds":300.0,"silver_seconds":430.0},
    {"id":"storage_peak","label":"05 保管床の勝負","description":"まとめ便16・単品便4。長い保管時間を乗り越えよう。","manifest_quota":20,"bulk_manifests":16,"pick_manifests":4,"mix":"bulk_heavy","interval":2.0,"dwell":65.0,"reward":450,"gold_seconds":340.0,"silver_seconds":480.0},
    {"id":"final_dispatch","label":"06 最後の大型契約","description":"まとめ便12・単品便12。144個を届けて全契約達成。","manifest_quota":24,"bulk_manifests":12,"pick_manifests":12,"mix":"balanced","interval":1.8,"dwell":50.0,"reward":600,"gold_seconds":360.0,"silver_seconds":510.0},
]
const LEGACY_UPGRADES := [
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
const LegacySim = preload("res://prototype/release_sim.gd")
const GROWTH_CONTRACTS := [
    {"id":"growth_1","label":"01 小さな倉庫の一歩","description":"12個を出荷して、最初の増築へ。","manifest_quota":2,"bulk_manifests":1,"pick_manifests":1,"mix":"balanced","interval":1.5,"dwell":6.0,"reward":140,"gold_seconds":45.0,"silver_seconds":80.0},
    {"id":"growth_2","label":"02 町の配送拠点","description":"24個の注文。増築か人手を選ぼう。","manifest_quota":4,"bulk_manifests":2,"pick_manifests":2,"mix":"balanced","interval":1.2,"dwell":6.0,"reward":200,"gold_seconds":75.0,"silver_seconds":140.0},
    {"id":"growth_3","label":"03 ロボットの出番","description":"36個を出荷。自動化で流れを変えよう。","manifest_quota":6,"bulk_manifests":4,"pick_manifests":2,"mix":"bulk_heavy","interval":1.0,"dwell":8.0,"reward":260,"gold_seconds":100.0,"silver_seconds":180.0},
    {"id":"growth_4","label":"04 大きな配送センター","description":"48個の出荷。新しい棟へ仕事を広げよう。","manifest_quota":8,"bulk_manifests":5,"pick_manifests":3,"mix":"bulk_heavy","interval":0.8,"dwell":10.0,"reward":340,"gold_seconds":125.0,"silver_seconds":220.0},
    {"id":"growth_5","label":"05 街をつなぐ物流基地","description":"60個の出荷。保管と自動梱包を使い分けよう。","manifest_quota":10,"bulk_manifests":7,"pick_manifests":3,"mix":"bulk_heavy","interval":0.7,"dwell":12.0,"reward":450,"gold_seconds":150.0,"silver_seconds":260.0},
    {"id":"growth_6","label":"06 巨大倉庫へ","description":"72個の出荷。完成後も定期便で増築できる。","manifest_quota":12,"bulk_manifests":8,"pick_manifests":4,"mix":"bulk_heavy","interval":0.6,"dwell":14.0,"reward":600,"gold_seconds":180.0,"silver_seconds":320.0},
    {"id":"route_bulk","label":"定期便：まとめ配送","description":"保管床と運搬力を活かす。毎回報酬あり。","manifest_quota":12,"bulk_manifests":10,"pick_manifests":2,"mix":"bulk_heavy","interval":0.5,"dwell":16.0,"reward":300,"gold_seconds":180.0,"silver_seconds":320.0},
    {"id":"route_pick","label":"定期便：小口配送","description":"棚・梱包・ロボットを活かす。毎回報酬あり。","manifest_quota":6,"bulk_manifests":1,"pick_manifests":5,"mix":"pick_heavy","interval":0.7,"dwell":6.0,"reward":300,"gold_seconds":180.0,"silver_seconds":320.0},
    {"id":"route_hub","label":"大型便：物流センター","description":"288個の保管配送。完成した倉庫で取り組む大型便。","manifest_quota":48,"bulk_manifests":40,"pick_manifests":8,"mix":"bulk_heavy","interval":0.35,"dwell":120.0,"reward":900,"gold_seconds":360.0,"silver_seconds":600.0},
]
const GROWTH_UPGRADES := [
    {"id":"wing_1","label":"第1棟を増築","description":"北へ広げ、実際に使う保管床を8枠追加。","cost":150,"unlock_after":1},
    {"id":"crew_4","label":"仲間を1人迎える","description":"作業員が3人から4人へ。並行して運べる。","cost":90,"unlock_after":1},
    {"id":"robot_2","label":"配送ロボット2台","description":"配送ロボット2台。人の1.3倍の速さで実際に荷物を運ぶ。","cost":260,"unlock_after":2},
    {"id":"auto_pack","label":"自動梱包機","description":"1個の梱包を1.5秒から0.7秒に。","cost":240,"unlock_after":2},
    {"id":"wing_2","label":"第2棟を増築","description":"さらに北へ。保管8枠と接続通路を追加。","cost":350,"unlock_after":2},
    {"id":"rack_48","label":"大型棚48個","description":"棚の実容量を48個へ。補充待ちを減らす。","cost":180,"unlock_after":2},
    {"id":"crew_6","label":"6人のチームへ","description":"人の作業員を6人に。採用済みの仲間も引き継ぐ。","cost":280,"unlock_after":3},
    {"id":"wing_3","label":"第3棟を増築","description":"配送センターを拡張。保管8枠追加。","cost":650,"unlock_after":3},
    {"id":"robot_4","label":"ロボットを4台へ","description":"ロボット2台追加。連携制御で4台とも移動が25%速くなる。","cost":500,"unlock_after":4},
    {"id":"wing_4","label":"第4棟を増築","description":"4棟をつなぐ巨大倉庫へ。保管8枠追加。","cost":1000,"unlock_after":4},
]
var legacy_profile := false
var _cached_snapshot: Dictionary = {}
var _snapshot_dirty := true
var _graph_cache_revision := -1
var _points_cache: Dictionary = {}
var _links_cache: Array = []
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

func _contracts() -> Array:
    return LEGACY_CONTRACTS + GROWTH_CONTRACTS

func _upgrades() -> Array:
    return LEGACY_UPGRADES + GROWTH_UPGRADES

func _milestones() -> int:
    var count := 0
    for index in 6:
        if contract_results.has("growth_%d" % (index+1)): count += 1
    return count

func _wing_count() -> int:
    var count := 0
    for index in 4:
        if "wing_%d" % (index+1) in purchased_upgrades: count += 1
    return 0 if legacy_profile else count

func _human_count() -> int:
    if not legacy_profile and "crew_6" in purchased_upgrades: return 6
    if "worker_5" in purchased_upgrades: return 5
    if "worker_4" in purchased_upgrades or (not legacy_profile and "crew_4" in purchased_upgrades): return 4
    return 3

func _robot_count() -> int:
    if legacy_profile: return 0
    return 4 if "robot_4" in purchased_upgrades else (2 if "robot_2" in purchased_upgrades else 0)

func _points() -> Dictionary:
    var count := _wing_count()
    if count == _graph_cache_revision and not _points_cache.is_empty(): return _points_cache
    _graph_cache_revision = count
    _links_cache = []
    var points := POINTS.duplicate()
    for tier in _wing_count():
        var z := -10.2-4.4*tier
        points["wing_%d_spine" % tier] = Vector3(2,0,z)
        points["wing_%d_west" % tier] = Vector3(-8,0,z)
        points["wing_%d_east" % tier] = Vector3(9,0,z)
        for index in 4:
            points["wing_%d_%d" % [tier,index]] = Vector3([-6.0,-3.0,5.0,7.0][index],0,z)
    _points_cache = points
    return points

func _links() -> Array:
    _points()
    if not _links_cache.is_empty(): return _links_cache
    var links := LINKS.duplicate(true)
    for tier in _wing_count():
        var spine := "wing_%d_spine" % tier
        links.append(["bulk_junction" if tier==0 else "wing_%d_spine" % (tier-1),spine])
        links.append([spine,"wing_%d_1" % tier])
        links.append(["wing_%d_1" % tier,"wing_%d_0" % tier])
        links.append([spine,"wing_%d_2" % tier])
        links.append(["wing_%d_2" % tier,"wing_%d_3" % tier])
        # Two real side service aisles connect receiving and dispatch to every
        # wing, relieving the original single central neck for northbound work.
        if tier == 0:
            links.append(["inbound","wing_0_west"])
            links.append(["outbound","wing_0_east"])
        else:
            links.append(["wing_%d_west" % (tier-1),"wing_%d_west" % tier])
            links.append(["wing_%d_east" % (tier-1),"wing_%d_east" % tier])
        links.append(["wing_%d_west" % tier,"wing_%d_0" % tier])
        links.append(["wing_%d_east" % tier,"wing_%d_3" % tier])
    _links_cache = links
    return links

func _expected_bays() -> Array:
    var result := BAY_DEFS.duplicate(true)
    if "floor_2" in purchased_upgrades: result.append_array(EXTRA_BAYS)
    for tier in _wing_count():
        for index in 4:
            for side in 2:
                result.append({"id":"W%d-%d-%d" % [tier+1,index+1,side+1],"position":Vector3([-6.0,-3.0,5.0,7.0][index],0,-10.2-4.4*tier+(-1.1 if side==0 else 1.1)),"node":"wing_%d_%d" % [tier,index]})
    return result

func _expected_rack() -> int:
    return 48 if not legacy_profile and "rack_48" in purchased_upgrades else (24 if "rack_24" in purchased_upgrades else 12)

func _expected_pack() -> float:
    if legacy_profile: return 2.0 if "packing_2" in purchased_upgrades else 3.0
    return 0.7 if "auto_pack" in purchased_upgrades else (1.2 if "packing_2" in purchased_upgrades else 1.5)

func _handling_seconds(task: String) -> float:
    return super._handling_seconds(task) * (1.0 if legacy_profile else 0.65)

func _worker_speed(worker: Dictionary) -> float:
    if not legacy_profile and int(worker.id) >= _human_count():
        return 6.0 if "robot_4" in purchased_upgrades else 4.8
    return walk_speed

func _worker_handling_seconds(worker: Dictionary) -> float:
    var seconds := _handling_seconds(str(worker.task))
    return seconds * (0.6 if not legacy_profile and int(worker.id) >= _human_count() else 1.0)

func _contract(id: String) -> Dictionary:
    for item in _contracts():
        if item.id == id:
            return item
    return {}

func _upgrade(id: String) -> Dictionary:
    for item in _upgrades():
        if item.id == id:
            return item
    return {}

func contract_options() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for definition in GROWTH_CONTRACTS:
        var option: Dictionary = definition.duplicate(true)
        option.repeatable = true
        var unlocked := _contract_unlocked(str(option.id))
        option.total_units = int(option.manifest_quota) * MANIFEST_SIZE
        option.completed = contract_results.has(option.id)
        option.is_replay = option.completed
        option.available = campaign_status != "running" and unlocked
        option.locked_reason = "作業中の契約を完了してください" if campaign_status == "running" else (_remaining_contracts(str(option.id)) if not unlocked else "")
        option.best_time = float(contract_results.get(option.id, {}).get("best_time", 0.0))
        option.best_medal = str(contract_results.get(option.id, {}).get("best_medal", ""))
        result.append(option)
    return result

func _remaining_contracts(id: String) -> String:
    if id.begins_with("growth_"):
        return "先にステップ%dを達成" % (int(id.trim_prefix("growth_"))-1)
    if id == "route_hub": return "ステップ6・増築3棟・ロボット2台で解放"
    return "ステップ1で解放"

func _contract_unlocked(id: String) -> bool:
    if id.begins_with("growth_"):
        var number := int(id.trim_prefix("growth_"))
        return number == 1 or contract_results.has("growth_%d" % (number-1))
    if id in ["route_bulk","route_pick"]: return _milestones() >= 1
    if id == "route_hub": return _milestones() >= 6 and _wing_count() >= 3 and _robot_count() >= 2
    # Original definitions and unlock graph are frozen for old saves.
    match id:
        "first_shift": return true
        "small_orders", "pallet_wave": return contract_results.has("first_shift")
        "packing_rush", "storage_peak": return contract_results.has("small_orders") and contract_results.has("pallet_wave")
        "final_dispatch": return contract_results.has("packing_rush") and contract_results.has("storage_peak")
    return false

func _upgrade_prerequisite(id: String) -> String:
    if id.begins_with("wing_") and int(id.trim_prefix("wing_")) > 1:
        return "wing_%d" % (int(id.trim_prefix("wing_"))-1)
    if id == "robot_4": return "robot_2"
    return ""

func upgrade_options() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for definition in GROWTH_UPGRADES:
        var option: Dictionary = definition.duplicate(true)
        option.owned = option.id in purchased_upgrades
        option.available = false
        option.locked_reason = ""
        if option.owned:
            option.locked_reason = "導入済み"
        elif _milestones() < int(option.unlock_after):
            option.locked_reason = "ステップ%dで解放" % int(option.unlock_after)
        elif not _upgrade_prerequisite(option.id).is_empty() and _upgrade_prerequisite(option.id) not in purchased_upgrades:
            option.locked_reason = "先に" + str(_upgrade(_upgrade_prerequisite(option.id)).label)
        elif option.id == "crew_4" and _human_count() >= 4:
            option.owned = true
            option.locked_reason = "採用済み"
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
    legacy_profile = not (id.begins_with("growth_") or id.begins_with("route_"))
    _snapshot_dirty = true
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
    _snapshot_dirty = true
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
    rack_capacity = _expected_rack()
    pack_seconds = _expected_pack()
    walk_speed = WALK_SPEED if legacy_profile else 3.6
    var count := _human_count()+_robot_count()
    _snapshot_dirty = true
    # Equipment is applied only between contracts, so adding/removing off-shift
    # workers cannot drop a reservation or carried cargo.
    while workers.size() > count:
        workers.pop_back()
    while workers.size() < count:
        var worker: Dictionary = workers[0].duplicate(true)
        worker.id = workers.size()
        worker.node = "inbound"
        worker.position = _points().inbound
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
    for definition in _expected_bays():
        if not _bay(definition.id).is_empty(): continue
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
    _snapshot_dirty = true
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
        _snapshot_dirty = true
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
    # The authoritative clock advances in 0.05-second ticks. Compare the same
    # centisecond precision shown to players, not accumulated binary float noise.
    var elapsed_cs := roundi(elapsed * 100.0)
    return "gold" if elapsed_cs <= roundi(float(definition.gold_seconds)*100.0) else ("silver" if elapsed_cs <= roundi(float(definition.silver_seconds)*100.0) else "bronze")

func _saved_medal_valid(value: String, definition: Dictionary, elapsed: float) -> bool:
    var legacy := "gold" if elapsed <= float(definition.gold_seconds) else ("silver" if elapsed <= float(definition.silver_seconds) else "bronze")
    return value == _medal(definition,elapsed) or value == legacy

func _normalize_saved_medals() -> void:
    # Only invoked after the entire legacy/new save has passed strict validation.
    for id in contract_results:
        contract_results[id].best_medal = _medal(_contract(id),float(contract_results[id].best_time))
    if not last_result.is_empty():
        last_result.medal = _medal(_contract(str(last_result.contract_id)),float(last_result.elapsed))

func _complete_contract(definition: Dictionary) -> void:
    finished = true
    var first_completion := not contract_results.has(current_contract_id)
    var previous: Dictionary = contract_results.get(current_contract_id, {})
    var best := minf(float(previous.get("best_time", INF)), sim_time)
    var earned := int(definition.reward) if first_completion or not legacy_profile else 0
    campaign_wallet += earned
    if first_completion:
        completed_count += 1
    var attempts := int(previous.get("attempts", 0))+1
    contract_results[current_contract_id] = {"best_time":best,"best_medal":_medal(definition,best),"attempts":attempts,"earned":int(previous.get("earned",0))+earned}
    last_result = {"contract_id":current_contract_id,"label":definition.label,"elapsed":sim_time,"best_time":best,"medal":_medal(definition,sim_time),"earnings":earned,"first_completion":first_completion,"new_best":sim_time < float(previous.get("best_time", INF)),"shipped":shipped,"total_units":int(definition.manifest_quota)*MANIFEST_SIZE,"worker_count":workers.size(),"layout_id":layout_id,"upgrades":purchased_upgrades.duplicate()}
    campaign_status = "contract_complete"

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
    elif completed_count == _contracts().size():
        objective = "全6契約を達成！ 配置を変えてベストタイムに挑戦しよう"
    elif completed_count > 0:
        objective = "設備と配置を選び、次の契約を受けよう"
    var growth := {"wing_count":_wing_count(),"area":223.886+83.6*_wing_count()+(14.554 if _wing_count()>0 else 0.0),"human_count":_human_count(),"robot_count":_robot_count(),"completed_milestones":_milestones(),"next_goal":_next_goal(),"legacy_profile":legacy_profile,"lifetime_units":_lifetime_units()}
    return {"growth":growth,"schema":RELEASE_SCHEMA,"status":campaign_status,"wallet":campaign_wallet,"completed_count":completed_count,"total_contracts":_contracts().size(),"campaign_complete":completed_count==_contracts().size(),"current_contract":definition,"current_contract_id":current_contract_id,"progress":{"shipped":shipped,"total":total,"offered":offered_units,"manifests_offered":manifest_cursor,"manifest_quota":int(definition.get("manifest_quota",0)),"remaining":maxi(0,total-shipped),"fraction":float(shipped)/float(total) if total>0 else 0.0},"elapsed":sim_time,"best_time":float(contract_results.get(current_contract_id,{}).get("best_time",0.0)),"last_earnings":int(last_result.get("earnings",0)),"last_result":last_result.duplicate(true),"objective":objective,"available":available,"upgrades":purchased_upgrades.duplicate(),"worker_count":workers.size(),"results":contract_results.duplicate(true)}

func _next_goal() -> String:
    if legacy_profile and campaign_status == "running": return "以前の荷物を届けて、増築の新しい一歩へ"
    if _milestones() == 0: return "12個を届けて第1棟を増築しよう"
    for option in upgrade_options():
        if option.available: return "%sを導入できる！" % option.label
    if _milestones() < 6: return "次の配送で資金をためよう"
    if _wing_count() < 4: return "定期便の報酬で4棟の巨大倉庫へ"
    if _robot_count() < 4 or "auto_pack" not in purchased_upgrades: return "配送ロボットと自動梱包で仕上げよう"
    return "巨大物流センター完成！ 大型便やベスト記録に挑戦"

func _lifetime_units() -> int:
    var total := 0
    for id in contract_results:
        total += int(contract_results[id].attempts)*int(_contract(id).manifest_quota)*MANIFEST_SIZE
    return total + (shipped if campaign_status=="running" else 0)

func snapshot() -> Dictionary:
    if not _snapshot_dirty and not _cached_snapshot.is_empty(): return _cached_snapshot
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
    var wings: Array[Rect2] = []
    for tier in _wing_count(): wings.append(Rect2(-9,-12.4-4.4*tier,19,4.4))
    state.world.growth_wings = wings
    state.world.growth_connectors = [Rect2(-9,-8,2,6),Rect2(8,-8,2,11)] if _wing_count()>0 else []
    state.topology_revision = _wing_count()
    state.human_count = _human_count()
    state.robot_count = _robot_count()
    _cached_snapshot = state
    _snapshot_dirty = false
    return state

func export_release_state() -> Dictionary:
    var simulation := {}
    for field in SIM_FIELDS:
        var value = get(field)
        simulation[field] = value.duplicate(true) if value is Array or value is Dictionary else value
    return {"schema":RELEASE_SCHEMA,"growth":{"legacy_profile":legacy_profile},"campaign":{"wallet":campaign_wallet,"completed_count":completed_count,"upgrades":purchased_upgrades.duplicate(),"current_contract_id":current_contract_id,"status":campaign_status,"manifest_cursor":manifest_cursor,"results":contract_results.duplicate(true),"last_result":last_result.duplicate(true)},"sim":simulation}

func import_release_state(data: Dictionary) -> Dictionary:
    if data.get("schema") == 1:
        var legacy = LegacySim.new()
        var validated: Dictionary = legacy.import_release_state(data)
        if not validated.ok: return validated
        var preserved: Dictionary = legacy.export_release_state()
        preserved.schema = RELEASE_SCHEMA
        preserved.growth = {"legacy_profile":true}
        _load_release_unchecked(preserved)
        _snapshot_dirty = true
        return {"ok":true,"schema":RELEASE_SCHEMA,"migrated":true}
    var validation := _validate_save_shape(data)
    if not validation.ok: return validation
    var candidate = get_script().new()
    candidate._load_release_unchecked(data)
    var result: Dictionary = candidate._validate_loaded_release()
    if not result.ok: return result
    candidate._normalize_saved_medals()
    _load_release_unchecked(candidate.export_release_state())
    _snapshot_dirty = true
    return {"ok":true,"schema":RELEASE_SCHEMA}

func _load_release_unchecked(data: Dictionary) -> void:
    legacy_profile = data.growth.legacy_profile
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
    if not _safe_variant(data) or not _keys_and_types(data,{"schema":2,"growth":{},"campaign":{},"sim":{}}) or data.schema != RELEASE_SCHEMA:
        return _bad("schema")
    if not _keys_and_types(data.growth,{"legacy_profile":false}): return _bad("growth_shape")
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
    if simulation.workers.size() < 3 or simulation.workers.size() > 10:
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
    if not current_contract_id.is_empty() and legacy_profile != LEGACY_CONTRACTS.any(func(item): return item.id == current_contract_id):
        return _bad("contract_profile")
    if campaign_status not in ["ready","running","contract_complete","campaign_complete"] or completed_count < 0 or completed_count > _contracts().size():
        return _bad("campaign_status")
    if contract_results.size() != completed_count:
        return _bad("completion_count")
    var expected_wallet := CAMPAIGN_STARTING_WALLET
    for index in _contracts().size():
        var definition: Dictionary = _contracts()[index]
        if contract_results.has(definition.id) and not _contract_unlocked(str(definition.id)):
            return _bad("completion_order")
        if contract_results.has(definition.id):
            var result = contract_results[definition.id]
            if not result is Dictionary or not _keys_and_types(result,{"best_time":0.0,"best_medal":"","attempts":0,"earned":0}):
                return _bad("result_shape")
            if result.best_time <= 0.0 or result.attempts < 1 or result.earned != int(definition.reward)*(int(result.attempts) if str(definition.id).begins_with("growth_") or str(definition.id).begins_with("route_") else 1) or not _saved_medal_valid(result.best_medal,definition,result.best_time):
                return _bad("result_value")
            expected_wallet += int(result.earned)
    var seen_upgrades := {}
    for id in purchased_upgrades:
        var upgrade := _upgrade(id)
        if upgrade.is_empty() or seen_upgrades.has(id) or (_milestones() if id in GROWTH_UPGRADES.map(func(item): return item.id) else completed_count) < int(upgrade.unlock_after):
            return _bad("upgrade_unlock")
        if not _upgrade_prerequisite(id).is_empty() and _upgrade_prerequisite(id) not in purchased_upgrades: return _bad("growth_upgrade_prerequisite")
        seen_upgrades[id] = true
        expected_wallet -= int(upgrade.cost)
    if "worker_5" in purchased_upgrades and "worker_4" not in purchased_upgrades:
        return _bad("worker_prerequisite")
    if campaign_wallet != expected_wallet or campaign_wallet < 0:
        return _bad("wallet")
    var expected_workers := _human_count()+_robot_count()
    if workers.size() != expected_workers or rack_capacity != _expected_rack() or pack_seconds != _expected_pack() or walk_speed != (WALK_SPEED if legacy_profile else 3.6):
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
        if _inbound_timer < -0.000001 or _inbound_timer > arrival_interval+0.000001:
            return _bad("arrival_clock")
        if campaign_status != "running" and (shipped != int(definition.manifest_quota)*MANIFEST_SIZE or not contract_results.has(current_contract_id) or not pending_layout_id.is_empty()):
            return _bad("incomplete_cargo")
    if campaign_status == "campaign_complete" and (not legacy_profile or completed_count != 6):
        return _bad("campaign_completion")
    if campaign_status in ["ready","running"]:
        if not last_result.is_empty():
            return _bad("unexpected_last_result")
    else:
        if last_result.is_empty() or last_result.contract_id != current_contract_id or last_result.label != definition.label or last_result.elapsed != sim_time or last_result.best_time != contract_results[current_contract_id].best_time or not _saved_medal_valid(last_result.medal,definition,sim_time) or last_result.earnings != (int(definition.reward) if last_result.first_completion or not legacy_profile else 0) or last_result.shipped != shipped or last_result.total_units != shipped or last_result.worker_count < 3 or last_result.worker_count > 10 or _option(last_result.layout_id).is_empty():
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
    var expected_bays: Array = _expected_bays()
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
        if manifest.kind == "bulk":
            if manifest.stored_at >= 0.0:
                if manifest.stored_at > sim_time+0.000001 or absf(float(manifest.release_at)-float(manifest.stored_at)-float(manifest.hold_seconds)) > 0.000001:
                    return _bad("bulk_release_clock")
            elif manifest.stored_at != -1.0 or manifest.release_at != -1.0:
                return _bad("bulk_unstored_clock")
        if manifest.stage not in ["external","inbound","bulk_store","bulk_storage","bulk_ship","restock","unit_fulfillment","completed"] or (not str(manifest.bay_id).is_empty() and _bay(manifest.bay_id).is_empty()):
            return _bad("manifest_stage")
        for ordinal in MANIFEST_SIZE:
            var unit_id := (id-1)*MANIFEST_SIZE+ordinal+1
            if manifest.unit_ids[ordinal] != unit_id or not cargo.has(unit_id):
                return _bad("manifest_units")
            var item: Dictionary = cargo[unit_id]
            if item.id != unit_id or item.manifest_id != id or item.kind != manifest.kind or item.ordinal != ordinal or not _points().has(item.node) or item.worker_id < -1 or item.worker_id >= workers.size() or (not str(item.bay_id).is_empty() and _bay(item.bay_id).is_empty()):
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
        if worker.id != index or (worker.phase == "idle") != (worker.task == "idle") or worker.phase not in ["idle","to_source","work","to_target"] or worker.task not in ["idle","evacuate","bulk_store","bulk_ship","restock","pick","ship"] or not _points().has(worker.node) or worker.edge_progress < 0.0 or worker.edge_progress > 1.0 or worker.path_index < 0 or (worker.phase != "idle" and worker.path_index > worker.path.size()) or worker.lane not in [0,1]:
            return _bad("worker_state")
        if (worker.manifest_id != -1 and not manifests.has(worker.manifest_id)) or (worker.cargo_id != -1 and not cargo.has(worker.cargo_id)) or (not str(worker.bay_id).is_empty() and _bay(worker.bay_id).is_empty()):
            return _bad("worker_reference")
        for node in worker.path:
            if not node is String or not _points().has(node):
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
            if not str(worker[field]).is_empty() and not _points().has(worker[field]):
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
