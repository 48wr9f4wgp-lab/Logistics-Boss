extends RefCounted
class_name FlotraJobsSim

# ISOLATED DOMAIN EXPERIMENT. No disk access, production save/schema changes,
# layout-specific rates, score multipliers, or hidden demand deletion.
# Each manifest has six equal-volume units. Bulk moves intact, occupies one
# physical pallet bay, waits for its scheduled release, and bypasses packing.
# Pick manifests are replenishment totes: one store trip, six actual unit picks.
const TICK := 0.05
const WALK_SPEED := 2.4
const WORKER_RADIUS := 0.18
const MANIFEST_RADIUS := 0.25 # Compact hand-trolley footprint; exclusive edge reservation.
const MERGE_OPPOSING_PROGRESS := 0.50
const STARTING_CASH := 5000
const UNIT_VALUE := 500
const MANIFEST_SIZE := 6
const ARRIVAL_INTERVAL := 12.0
const BULK_DWELL := 60.0
const SHELF_CAPACITY := 12
const PACK_SECONDS := 3.0
const INBOUND_MANIFEST_LIMIT := 12
const POINTS := {
    "inbound":Vector3(-8,0,-2), "west":Vector3(-5,0,0),
    "shelf_core":Vector3(-5,0,-3), "neck_w":Vector3(-2,0,0),
    "neck_e":Vector3(2,0,0), "pack_front":Vector3(5,0,0),
    "outbound":Vector3(8,0,3), "annex_entry":Vector3(2,0,-4),
    "shelf_annex":Vector3(0,0,-4), "pack_annex":Vector3(5,0,-4),
    "bulk_junction":Vector3(2,0,-5.95),
    "bulk_left":Vector3(-0.65,0,-5.95), "bulk_right":Vector3(0.65,0,-5.95),
    "bulk_east":Vector3(3.6,0,-6.1), "bulk_far":Vector3(5.6,0,-6.1),
}
const LINKS := [
    ["inbound","west"],["west","shelf_core"],["west","neck_w"],
    ["neck_w","neck_e"],["neck_e","pack_front"],["pack_front","outbound"],
    ["neck_e","annex_entry"],["annex_entry","shelf_annex"],
    ["annex_entry","pack_annex"],["pack_annex","pack_front"],
    ["annex_entry","bulk_junction"],["bulk_junction","bulk_right"],
    ["bulk_right","bulk_left"],["bulk_junction","bulk_east"],["bulk_east","bulk_far"],
]
const BAY_DEFS := [
    {"id":"A1","position":Vector3(-.65,0,-4.85),"node":"bulk_left"},
    {"id":"A2","position":Vector3(.65,0,-4.85),"node":"bulk_right"},
    {"id":"A3","position":Vector3(-.65,0,-7.05),"node":"bulk_left"},
    {"id":"A4","position":Vector3(.65,0,-7.05),"node":"bulk_right"},
    {"id":"B1","position":Vector3(3.6,0,-7.20),"node":"bulk_east"},
    {"id":"B2","position":Vector3(5.6,0,-7.20),"node":"bulk_far"},
]
var walk_speed := WALK_SPEED
var bulk_dwell := BULK_DWELL
var arrival_interval := ARRIVAL_INTERVAL
var pack_seconds := PACK_SECONDS
var rack_capacity := SHELF_CAPACITY
var layout_id := "compact"
var workload_id := "balanced"
var pending_layout_id := ""
var sim_time := 0.0
var duration := 0.0
var time_scale := 1.0
var finished := false
var shipped := 0
var bulk_shipped := 0
var pick_shipped := 0
var revenue := 0
var money := STARTING_CASH
var arrived := 0
var initial_cargo := 0
var inbound_blocked := 0
var offered_units := 0
var open_orders := 0
var travel_seconds := 0.0
var loaded_travel_seconds := 0.0
var aisle_wait_seconds := 0.0
var relocation_seconds := 0.0
var relocation_count := 0
var stored := 0
var picked := 0
var packed := 0
var workers: Array[Dictionary] = []
var cargo: Dictionary = {}
var manifests: Dictionary = {}
var inbound: Array[int] = [] # Manifest IDs, not individual units.
var external_backlog: Array[int] = [] # All offered work remains in the ledger.
var bulk_storage: Array[int] = []
var storage: Array[int] = [] # Pick units.
var packing: Array[int] = []
var ready: Array[int] = []
var shipped_ids: Array[int] = []
var pack_jobs: Array[Dictionary] = []
var comparison: Dictionary = {}
var mix_history: Array[Dictionary] = []
var relocation_history: Array[Dictionary] = []
var bulk_bays: Array[Dictionary] = []
var _edges: Dictionary = {}
var _next_cargo := 1
var _next_manifest := 1
var _inbound_timer := ARRIVAL_INTERVAL
var _accumulator := 0.0
var _move_remaining := 0.0
var _move_duration := 0.0
var _round_robin := 0
var _mix_credit := 0.0

func _points() -> Dictionary:
    return POINTS

func _links() -> Array:
    return LINKS

func _init() -> void:
    restart()

func layout_options() -> Array[Dictionary]:
    return [
        {"id":"compact","label":"広い保管床","description":"棚は主棟。増築のパレット6枠を使えるが、単品ピックは長い。","benefit":"まとめ保管6枠","tradeoff":"単品ピックが中央通路を往復","cost_label":"同じ設備・移動中は作業停止","slot_label":"棚：主棟 / 梱包：出荷側","shelf_slot":"core","packing_slot":"front"},
        {"id":"clear_aisle","label":"短いピック動線","description":"棚を増築へ。単品の集品は短く、パレット床4枠を棚が使う。","benefit":"ピック距離短縮・中央2人通行","tradeoff":"まとめ保管は2枠","cost_label":"同じ設備・移動中は作業停止","slot_label":"棚：増築 / 梱包：出荷側","shelf_slot":"annex","packing_slot":"front"},
        {"id":"pack_annex","label":"増築で集品・梱包","description":"棚と梱包を増築へ。集品はさらに短いが、出荷搬送が長い。","benefit":"集品から梱包まで短い","tradeoff":"まとめ保管2枠・出荷が遠い","cost_label":"同じ設備・移動中は作業停止","slot_label":"棚：増築 / 梱包：増築","shelf_slot":"annex","packing_slot":"annex"},
        {"id":"split","label":"保管床と増築梱包","description":"棚は主棟、梱包は増築。保管床は広いが単品ルートが長い。","benefit":"まとめ保管6枠","tradeoff":"集品と出荷の搬送が長い","cost_label":"同じ設備・移動中は作業停止","slot_label":"棚：主棟 / 梱包：増築","shelf_slot":"core","packing_slot":"annex"},
    ]

func workload_options() -> Array[Dictionary]:
    return [
        {"id":"bulk_heavy","label":"まとめ便が多い","description":"今後の受付：まとめ保管80% / 単品集品20%。総入荷は毎分30個。","bulk_fraction":.8,"duration":0.0},
        {"id":"balanced","label":"半分ずつ","description":"今後の受付：まとめ保管50% / 単品集品50%。総入荷は毎分30個。","bulk_fraction":.5,"duration":0.0},
        {"id":"pick_heavy","label":"単品注文が多い","description":"今後の受付：まとめ保管20% / 単品集品80%。総入荷は毎分30個。","bulk_fraction":.2,"duration":0.0},
    ]

func mix_options() -> Array[Dictionary]:
    var options := workload_options()
    for option in options:
        option.bulk_share = option.bulk_fraction
    return options

func job_mix_options() -> Array[Dictionary]:
    return mix_options()

func _option(id: String) -> Dictionary:
    for option in layout_options():
        if option.id == id:
            return option
    return {}

func _workload(id: String) -> Dictionary:
    for option in workload_options():
        if option.id == id:
            return option
    return {}

func restart(next_workload: String = "balanced", next_layout: String = "compact") -> Dictionary:
    if _workload(next_workload).is_empty() or _option(next_layout).is_empty():
        return {"ok":false,"reason":"unknown"}
    workload_id = next_workload
    layout_id = next_layout
    pending_layout_id = ""
    sim_time = 0.0
    duration = 0.0
    time_scale = 1.0
    finished = false
    shipped = 0
    bulk_shipped = 0
    pick_shipped = 0
    revenue = 0
    money = STARTING_CASH
    arrived = 0
    initial_cargo = 0
    inbound_blocked = 0
    offered_units = 0
    open_orders = 0
    travel_seconds = 0.0
    loaded_travel_seconds = 0.0
    aisle_wait_seconds = 0.0
    relocation_seconds = 0.0
    relocation_count = 0
    stored = 0
    picked = 0
    packed = 0
    for list in [inbound,external_backlog,bulk_storage,storage,packing,ready,shipped_ids,pack_jobs,workers,mix_history,relocation_history,bulk_bays]:
        list.clear()
    cargo.clear()
    manifests.clear()
    comparison.clear()
    _next_cargo = 1
    _next_manifest = 1
    _inbound_timer = arrival_interval
    _accumulator = 0.0
    _move_remaining = 0.0
    _move_duration = 0.0
    _round_robin = 0
    _mix_credit = 0.0
    for definition in BAY_DEFS:
        var bay: Dictionary = definition.duplicate(true)
        bay.footprint = Rect2(bay.position.x-.5,bay.position.z-.5,1.0,1.0)
        bay.manifest_id = -1
        bay.reserved_by = -1
        bulk_bays.append(bay)
    _build_edges()
    for i in 5:
        workers.append({"id":i,"role":"flex","node":"inbound","position":_points().inbound,"task":"idle","phase":"idle","cargo_id":-1,"cargo_ids":[],"manifest_id":-1,"bay_id":"","carrying":false,"waiting":false,"path":[],"path_index":0,"edge_id":"","edge_progress":0.0,"edge_from":"","edge_to":"","lane":0,"work_remaining":0.0,"source":"","target":"","travel_seconds":0.0,"wait_seconds":0.0})
    mix_history.append({"at":0.0,"mix_id":workload_id,"first_manifest":_next_manifest})
    return {"ok":true}

func set_mix(next_mix: String) -> Dictionary:
    if _workload(next_mix).is_empty():
        return {"ok":false,"reason":"unknown"}
    if finished:
        return {"ok":false,"reason":"finished"}
    if next_mix == workload_id:
        return {"ok":false,"reason":"same"}
    workload_id = next_mix
    # Keep fractional credit, jobs, arrival clock and all queues. No reroll/reset.
    mix_history.append({"at":sim_time,"mix_id":workload_id,"first_manifest":_next_manifest})
    return {"ok":true,"future_only":true,"first_manifest":_next_manifest}

func set_workload(next_mix: String) -> Dictionary:
    return set_mix(next_mix)

func _shelf_node(id: String = "") -> String:
    return "shelf_" + str(_option(layout_id if id.is_empty() else id).shelf_slot)

func _pack_node(id: String = "") -> String:
    return "pack_" + str(_option(layout_id if id.is_empty() else id).packing_slot)

func _shelf_equipment_position(id: String) -> Vector3:
    return Vector3(-3.35,0,-1.7) if _option(id).shelf_slot == "core" else Vector3(0,0,-5.95)

func _pack_equipment_position(id: String) -> Vector3:
    return Vector3(6.5,0,-1.3) if _option(id).packing_slot == "front" else Vector3(5,0,-5.3)

func _shelf_footprint(id: String) -> Rect2:
    var center := _shelf_equipment_position(id)
    return Rect2(center.x-1.1,center.z-1.4,2.2,2.8)

func _pack_footprint(id: String) -> Rect2:
    var center := _pack_equipment_position(id)
    return Rect2(center.x-.8,center.z-.5,1.6,1.0)

func _bay_available_in(bay: Dictionary, id: String) -> bool:
    return not bay.footprint.intersects(_shelf_footprint(id)) and not bay.footprint.intersects(_pack_footprint(id))

func bulk_capacity(id: String = "") -> int:
    var count := 0
    for bay in bulk_bays:
        if _bay_available_in(bay,layout_id if id.is_empty() else id):
            count += 1
    return count

func _segment_hits_rect(a: Vector2, b: Vector2, bounds: Rect2) -> bool:
    if bounds.has_point(a) or bounds.has_point(b):
        return true
    var corners := [bounds.position,bounds.position+Vector2(bounds.size.x,0),bounds.end,bounds.position+Vector2(0,bounds.size.y)]
    for i in 4:
        if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null:
            return true
    return false

func _build_edges() -> void:
    _edges.clear()
    for bay in bulk_bays:
        bay.available = _bay_available_in(bay,layout_id)
    var obstacles := [{"id":"shelf","rect":_shelf_footprint(layout_id).grow(WORKER_RADIUS)},{"id":"packing","rect":_pack_footprint(layout_id).grow(WORKER_RADIUS)}]
    for link in _links():
        var key := str(link[0])+":"+str(link[1])
        var a: Vector3 = _points()[link[0]]
        var b: Vector3 = _points()[link[1]]
        var direction := (b-a).normalized()
        var normal := Vector3(-direction.z,0,direction.x)
        var lanes: Array[Dictionary] = []
        var available: Array[int] = []
        var blocked_by := ""
        for lane in 2:
            var offset := normal * (-.32 if lane == 0 else .32)
            var lane_a := a+offset
            var lane_b := b+offset
            var blocker := ""
            for obstacle in obstacles:
                if _segment_hits_rect(Vector2(lane_a.x,lane_a.z),Vector2(lane_b.x,lane_b.z),obstacle.rect):
                    blocker = obstacle.id
                    break
            lanes.append({"id":lane,"from":lane_a,"to":lane_b,"blocked":not blocker.is_empty(),"blocked_by":blocker})
            if blocker.is_empty():
                available.append(lane)
            else:
                blocked_by = blocker
        var bulk_lanes: Array[int] = []
        for lane in available:
            var safe := true
            for sample in 41:
                var t := float(sample)/40.0
                var position := a.lerp(b,t)+normal*(-.32 if lane==0 else .32)*sin(PI*t)
                for bounds in [_shelf_footprint(layout_id),_pack_footprint(layout_id)]:
                    if bounds.grow(MANIFEST_RADIUS).has_point(Vector2(position.x,position.z)):
                        safe = false
            if safe:
                bulk_lanes.append(lane)
        _edges[key] = {"bulk_lanes":bulk_lanes,"id":key,"a":link[0],"b":link[1],"from":a,"to":b,"capacity":available.size(),"lanes":lanes,"open_lanes":available,"owners":[],"queue":[],"wait_seconds":0.0,"blocked_by":blocked_by}

func _walk_speed() -> float:
    return walk_speed

func _worker_speed(_worker: Dictionary) -> float:
    return _walk_speed()

func _worker_handling_seconds(worker: Dictionary) -> float:
    return _handling_seconds(str(worker.task))

func _path_edge_cost(edge: Dictionary) -> float:
    return (edge.to as Vector3).distance_to(edge.from)

func _handling_seconds(task: String) -> float:
    # Pallet/tote handling and unit handling have physical meanings; every layout
    # and mix uses these exact same constants.
    return {"bulk_store":2.0,"bulk_ship":2.0,"restock":2.0,"pick":1.2,"ship":1.2}.get(task,0.0)

func timing_info() -> Dictionary:
    return {"model":"manifest_logistics","rack_capacity":rack_capacity,"shipment_unit_value":UNIT_VALUE,"holding_rule":"minimum_elapsed_since_storage","transport_radius":MANIFEST_RADIUS,"manifest_exclusive_corridor":true,"walk_units_per_second":walk_speed,"manifest_units":MANIFEST_SIZE,"arrival_interval":arrival_interval,"bulk_dwell_seconds":bulk_dwell,"packing_seconds":pack_seconds,"handling_seconds":{"bulk_store":2.0,"bulk_ship":2.0,"restock":2.0,"pick":1.2,"ship":1.2},"notes":"6個を1便で入荷。まとめ便は床保管後に直送。単品便は棚へ補充し、1個ずつ集品・梱包・出荷。"}

func apply_slot(slot_id: String, choice_id: String) -> Dictionary:
    if slot_id not in ["shelf","packing"]:
        return {"ok":false,"reason":"unknown_slot"}
    var option := _option(layout_id)
    var shelf := choice_id if slot_id == "shelf" else str(option.shelf_slot)
    var bench := choice_id if slot_id == "packing" else str(option.packing_slot)
    for candidate in layout_options():
        if candidate.shelf_slot == shelf and candidate.packing_slot == bench:
            return apply_layout(candidate.id)
    return {"ok":false,"reason":"unknown_choice"}

func apply_layout(next_layout: String) -> Dictionary:
    if _option(next_layout).is_empty():
        return {"ok":false,"reason":"unknown"}
    if finished:
        return {"ok":false,"reason":"finished"}
    if not pending_layout_id.is_empty():
        return {"ok":false,"reason":"busy"}
    if next_layout == layout_id:
        return {"ok":false,"reason":"same"}
    pending_layout_id = next_layout
    relocation_history.append({"requested_at":sim_time,"from":layout_id,"to":next_layout,"started_at":-1.0,"completed_at":-1.0})
    return {"ok":true,"pending":true,"reason":"draining","cost":0}

func step(real_dt: float) -> void:
    if finished or real_dt <= 0.0 or not is_finite(real_dt):
        return
    _accumulator += real_dt * maxf(0.0,time_scale)
    while _accumulator + .0000001 >= TICK and not finished:
        _accumulator = maxf(0.0,_accumulator-TICK)
        _tick(TICK)

func _tick(dt: float) -> void:
    sim_time = minf(duration,sim_time+dt) if duration>0 else sim_time+dt
    _spawn(dt)
    if _move_remaining > 0:
        relocation_seconds += dt
        _move_remaining = maxf(0.0,_move_remaining-dt)
        if _move_remaining <= .000001:
            _finish_relocation()
    else:
        _update_pack(dt)
        for offset in workers.size():
            var index := (_round_robin+offset)%workers.size()
            _update_worker(workers[index],dt)
        _round_robin = (_round_robin+1)%workers.size()
        if not pending_layout_id.is_empty():
            _try_relocation()
        if _move_remaining <= 0:
            for worker in workers:
                if worker.phase == "idle":
                    _assign(worker)
    if duration > 0 and sim_time+.000001 >= duration:
        sim_time = duration
        finished = true

func _spawn(dt: float) -> void:
    _inbound_timer -= dt
    while _inbound_timer <= .000001:
        _inbound_timer += arrival_interval
        _mix_credit += float(_workload(workload_id).bulk_fraction)
        var kind := "bulk" if _mix_credit + .000001 >= 1.0 else "pick"
        if kind == "bulk":
            _mix_credit -= 1.0
        _new_manifest(kind)
    while not external_backlog.is_empty() and inbound.size() < INBOUND_MANIFEST_LIMIT:
        var id: int = external_backlog.pop_front()
        inbound.append(id)
        manifests[id].stage = "inbound"
        for unit_id in manifests[id].unit_ids:
            cargo[unit_id].stage = "inbound"
        arrived += MANIFEST_SIZE

func _new_manifest(kind: String) -> void:
    var manifest_id := _next_manifest
    _next_manifest += 1
    var ids: Array[int] = []
    for i in MANIFEST_SIZE:
        var id := _next_cargo
        _next_cargo += 1
        cargo[id] = {"id":id,"manifest_id":manifest_id,"kind":kind,"ordinal":i,"stage":"external","node":"inbound","worker_id":-1,"bay_id":"","created_at":sim_time,"stored_at":-1.0,"picked_at":-1.0,"packed_at":-1.0,"shipped_at":-1.0}
        ids.append(id)
    manifests[manifest_id] = {"id":manifest_id,"kind":kind,"unit_ids":ids,"size":MANIFEST_SIZE,"hold_seconds":bulk_dwell if kind=="bulk" else 0.0,"stage":"external","mix_id":workload_id,"created_at":sim_time,"stored_at":-1.0,"release_at":-1.0,"completed_at":-1.0,"bay_id":"","shipped_units":0}
    external_backlog.append(manifest_id)
    offered_units += MANIFEST_SIZE
    if inbound.size() >= INBOUND_MANIFEST_LIMIT:
        inbound_blocked += MANIFEST_SIZE
    if kind == "pick":
        open_orders += MANIFEST_SIZE

func _update_pack(dt: float) -> void:
    if pack_jobs.is_empty() and not packing.is_empty():
        var id: int = packing.pop_front()
        cargo[id].stage = "packing"
        pack_jobs.append({"cargo_id":id,"remaining":pack_seconds})
    for index in range(pack_jobs.size()-1,-1,-1):
        pack_jobs[index].remaining = maxf(0.0,float(pack_jobs[index].remaining)-dt)
        if pack_jobs[index].remaining <= .000001:
            var id: int = pack_jobs[index].cargo_id
            cargo[id].stage = "packed"
            cargo[id].packed_at = sim_time
            ready.append(id)
            packed += 1
            pack_jobs.remove_at(index)

func _free_bay() -> Dictionary:
    for bay in bulk_bays:
        if bay.available and int(bay.manifest_id)<0 and int(bay.reserved_by)<0:
            return bay
    return {}

func _bay(id: String) -> Dictionary:
    for bay in bulk_bays:
        if bay.id == id:
            return bay
    return {}

func _store_reserved() -> int:
    var count := 0
    for worker in workers:
        if worker.task == "restock":
            count += worker.cargo_ids.size()
    return count

func _rack_occupied() -> int:
    # A reserved pick still physically occupies its rack cell until pickup ends.
    var count := storage.size()
    for worker in workers:
        if worker.task=="pick" and worker.phase in ["to_source","work"]:
            count += worker.cargo_ids.size()
    return count

func _assign(worker: Dictionary) -> void:
    var task := ""
    var source := ""
    var target := ""
    var ids: Array = []
    var manifest_id := -1
    var bay_id := ""
    # Finish released commitments before opening new work. Workers share one
    # pool; neither job type receives hidden dedicated or additional labour.
    for id in bulk_storage:
        if float(manifests[id].release_at) <= sim_time:
            manifest_id = id
            task = "bulk_ship"
            bay_id = manifests[id].bay_id
            source = str(_bay(bay_id).node)
            target = "outbound"
            ids = manifests[id].unit_ids.duplicate()
            bulk_storage.erase(id)
            break
    if task.is_empty() and not ready.is_empty():
        var id: int = ready.pop_front()
        ids = [id]
        task = "ship"
        source = _pack_node()
        target = "outbound"
    # During relocation drain only already started packing and released pallets.
    # Keep all remaining rack stock; it moves with the rack at relocation speed.
    if task.is_empty() and pending_layout_id.is_empty() and not storage.is_empty() and packing.size()+pack_jobs.size()+_worker_count("pick") < 6:
        var id: int = storage.pop_front()
        ids = [id]
        task = "pick"
        source = _shelf_node()
        target = _pack_node()
    if task.is_empty() and pending_layout_id.is_empty():
        var free_bay := _free_bay()
        for id in inbound:
            var manifest: Dictionary = manifests[id]
            if manifest.kind == "bulk":
                var bay := free_bay
                if bay.is_empty():
                    continue
                task = "bulk_store"
                bay_id = bay.id
                bay.reserved_by = worker.id
                target = bay.node
                manifests[id].bay_id = bay_id
            elif _rack_occupied()+_store_reserved()+MANIFEST_SIZE <= rack_capacity:
                task = "restock"
                target = _shelf_node()
            else:
                continue
            manifest_id = id
            ids = manifest.unit_ids.duplicate()
            source = "inbound"
            inbound.erase(id)
            break
    if task.is_empty():
        return
    if manifest_id < 0:
        manifest_id = cargo[ids[0]].manifest_id
    worker.role = "store" if task in ["restock","bulk_store"] else ("pick" if task == "pick" else "ship")
    worker.task = task
    worker.phase = "to_source"
    worker.cargo_ids = ids
    worker.cargo_id = ids[0]
    worker.manifest_id = manifest_id
    worker.bay_id = bay_id
    worker.source = source
    worker.target = target
    worker.carrying = false
    for id in ids:
        cargo[id].stage = "reserved_"+task
        cargo[id].worker_id = worker.id
    if task in ["restock","bulk_store","bulk_ship"]:
        manifests[manifest_id].stage = task
    _set_path(worker,source)

func _merge_entry_blocked(worker: Dictionary, edge: Dictionary, entry: String) -> bool:
    # Opposing traffic inside the endpoint merge owns that merge until it exits.
    # This prevents sinusoidal lane tapers from merging two head-on bodies.
    for owner_id in edge.owners:
        var owner: Dictionary = workers[owner_id]
        if owner.edge_to == entry and float(owner.edge_progress) >= MERGE_OPPOSING_PROGRESS:
            return true
        if owner.edge_from == entry and float(owner.edge_progress) < 0.25:
            return true
    return false

func _set_path(worker: Dictionary, target: String) -> void:
    worker.path = _find_path(str(worker.node), target,worker.carrying and worker.cargo_ids.size()>1)
    worker.path_index = 0
    worker.waiting = worker.path.is_empty()

func _find_path(source: String, target: String, manifest_transport: bool = false) -> Array:
    if source == target:
        return [source]
    var distances := {source:0.0}
    var previous := {}
    var remaining: Array = _points().keys()
    while not remaining.is_empty():
        var closest := ""
        var best := INF
        for node in remaining:
            var distance := float(distances.get(node, INF))
            if distance < best:
                best = distance
                closest = node
        if closest.is_empty() or closest == target:
            break
        remaining.erase(closest)
        for edge in _edges.values():
            if int(edge.capacity) <= 0 or (manifest_transport and edge.bulk_lanes.is_empty()):
                continue
            var other := ""
            if edge.a == closest:
                other = edge.b
            elif edge.b == closest:
                other = edge.a
            if other.is_empty() or other not in remaining:
                continue
            var distance := best + _path_edge_cost(edge)
            if distance < float(distances.get(other, INF)):
                distances[other] = distance
                previous[other] = closest
    var result: Array = [target]
    var cursor := target
    while cursor != source:
        if not previous.has(cursor):
            return []
        cursor = previous[cursor]
        result.push_front(cursor)
    return result

func _edge_between(a: String, b: String) -> Dictionary:
    for edge in _edges.values():
        if (edge.a == a and edge.b == b) or (edge.a == b and edge.b == a):
            return edge
    return {}

func _update_worker(worker: Dictionary, dt: float) -> void:
    if worker.phase == "idle":
        return
    if worker.path.is_empty() and worker.phase != "work":
        worker.waiting = true
        worker.wait_seconds += dt
        return
    if worker.phase == "work":
        worker.work_remaining = maxf(0.0, float(worker.work_remaining) - dt)
        if worker.work_remaining <= 0.000001:
            worker.phase = "to_target"
            if worker.task=="bulk_ship":
                # The bay becomes reusable once the intact pallet leaves its
                # service face, not after an unrelated outbound travel delay.
                _bay(worker.bay_id).manifest_id = -1
            _set_path(worker, worker.target)
        return
    if int(worker.path_index) >= worker.path.size() - 1:
        if worker.phase == "to_source":
            worker.phase = "work"
            worker.carrying = true
            worker.work_remaining = _worker_handling_seconds(worker)
            for cargo_id in worker.cargo_ids:
                cargo[cargo_id].stage = "carried_" + str(worker.task)
        else:
            _deliver(worker)
        return
    var a: String = worker.path[worker.path_index]
    var b: String = worker.path[worker.path_index + 1]
    var edge := _edge_between(a, b)
    if edge.is_empty():
        return
    if str(worker.edge_id).is_empty():
        if worker.id not in edge.queue:
            edge.queue.append(worker.id)
        var own_bulk: bool = worker.carrying and worker.cargo_ids.size()>1
        var any_bulk := false
        for owner in edge.owners:
            if workers[owner].carrying and workers[owner].cargo_ids.size()>1:
                any_bulk = true
        if edge.owners.size() >= int(edge.capacity) or edge.queue[0] != worker.id or _merge_entry_blocked(worker,edge,a) or any_bulk or (own_bulk and not edge.owners.is_empty()):
            worker.waiting = true
            worker.wait_seconds += dt
            aisle_wait_seconds += dt
            edge.wait_seconds += dt
            return
        edge.queue.pop_front()
        var used_lanes: Array = []
        for owner in edge.owners:
            used_lanes.append(int(workers[owner].lane))
        for lane in (edge.bulk_lanes if own_bulk else edge.open_lanes):
            if lane not in used_lanes:
                worker.lane = lane
                break
        edge.owners.append(worker.id)
        worker.edge_id = edge.id
        worker.edge_from = a
        worker.edge_to = b
        worker.edge_progress = 0.0
    worker.waiting = false
    var length := (_points()[a] as Vector3).distance_to(_points()[b])
    var before := float(worker.edge_progress)
    worker.edge_progress = minf(1.0, before + dt * _worker_speed(worker) / length)
    var actual_dt := (float(worker.edge_progress) - before) * length / _worker_speed(worker)
    travel_seconds += actual_dt
    worker.travel_seconds += actual_dt
    if worker.carrying:
        loaded_travel_seconds += actual_dt
    worker.position = (_points()[a] as Vector3).lerp(_points()[b], float(worker.edge_progress))
    if not edge.lanes.is_empty():
        var direction: Vector3 = (edge.to - edge.from).normalized()
        var lateral := Vector3(-direction.z, 0.0, direction.x)
        var side := -0.32 if int(worker.lane) == 0 else 0.32
        worker.position += lateral * side * sin(PI * float(worker.edge_progress))
    if worker.edge_progress >= 1.0 - 0.000001:
        worker.node = b
        worker.position = _points()[b]
        worker.path_index += 1
        worker.edge_id = ""
        edge.owners.erase(worker.id)

func _deliver(worker: Dictionary) -> void:
    var task: String = worker.task
    for id in worker.cargo_ids:
        cargo[id].worker_id = -1
        cargo[id].node = worker.target
        match task:
            "bulk_store":
                cargo[id].stage = "bulk_storage"
                cargo[id].bay_id = worker.bay_id
                cargo[id].stored_at = sim_time
                stored += 1
            "restock":
                storage.append(id)
                cargo[id].stage = "storage"
                cargo[id].stored_at = sim_time
                stored += 1
            "pick":
                packing.append(id)
                cargo[id].stage = "packing_queue"
                cargo[id].picked_at = sim_time
                picked += 1
            "ship", "bulk_ship":
                shipped_ids.append(id)
                cargo[id].stage = "shipped"
                cargo[id].shipped_at = sim_time
                shipped += 1
                if task == "bulk_ship":
                    bulk_shipped += 1
                else:
                    pick_shipped += 1
                    open_orders -= 1
                manifests[cargo[id].manifest_id].shipped_units += 1
                if manifests[cargo[id].manifest_id].shipped_units == MANIFEST_SIZE:
                    manifests[cargo[id].manifest_id].completed_at = sim_time
                    manifests[cargo[id].manifest_id].stage = "completed"
    if task == "bulk_store":
        var manifest: Dictionary = manifests[worker.manifest_id]
        manifest.stage = "bulk_storage"
        manifest.stored_at = sim_time
        manifest.release_at = sim_time+float(manifest.hold_seconds)
        bulk_storage.append(worker.manifest_id)
        var bay := _bay(worker.bay_id)
        bay.manifest_id = worker.manifest_id
        bay.reserved_by = -1
    elif task == "restock":
        manifests[worker.manifest_id].stage = "unit_fulfillment"
        manifests[worker.manifest_id].stored_at = sim_time
    revenue = shipped*UNIT_VALUE
    money = STARTING_CASH+revenue
    worker.cargo_ids = []
    worker.cargo_id = -1
    worker.manifest_id = -1
    worker.bay_id = ""
    worker.carrying = false
    worker.task = "idle"
    worker.phase = "idle"
    worker.waiting = false
    worker.path = []

func _estimated_relocation_stop(next_layout: String) -> float:
    var shelf_distance := _shelf_equipment_position(layout_id).distance_to(_shelf_equipment_position(next_layout))
    var pack_distance := _pack_equipment_position(layout_id).distance_to(_pack_equipment_position(next_layout))
    return 2.0+maxf(shelf_distance,pack_distance)+(storage.size()*.2 if shelf_distance>0 else 0.0)

func _try_relocation() -> void:
    for bay in bulk_bays:
        if not _bay_available_in(bay,pending_layout_id) and (bay.manifest_id >= 0 or bay.reserved_by >= 0):
            return
    for worker in workers:
        if worker.phase != "idle":
            return
    if not packing.is_empty() or not pack_jobs.is_empty() or not ready.is_empty():
        return
    for worker in workers:
        var position: Vector3 = worker.position
        var future_footprint := _shelf_footprint(pending_layout_id).grow(WORKER_RADIUS)
        if future_footprint.has_point(Vector2(position.x,position.z)):
            worker.task = "evacuate"
            worker.phase = "to_target"
            worker.target = "annex_entry"
            _set_path(worker,"annex_entry")
            return
    var shelf_distance := _shelf_equipment_position(layout_id).distance_to(_shelf_equipment_position(pending_layout_id))
    var pack_distance := _pack_equipment_position(layout_id).distance_to(_pack_equipment_position(pending_layout_id))
    # Five workers move the existing equipment and its retained stock. Distance
    # and load determine downtime, not a per-layout purchase penalty or buff.
    _move_duration = _estimated_relocation_stop(pending_layout_id)
    _move_remaining = _move_duration
    relocation_history[-1].started_at = sim_time
    relocation_history[-1].downtime = _move_duration

func _finish_relocation() -> void:
    layout_id = pending_layout_id
    pending_layout_id = ""
    for id in storage:
        cargo[id].node = _shelf_node()
    for id in ready:
        cargo[id].node = _pack_node()
    _move_remaining = 0.0
    relocation_count += 1
    relocation_history[-1].completed_at = sim_time
    _build_edges()
    # Workers evacuated through the old graph before movement; none teleport.

func _worker_count(task: String) -> int:
    var count := 0
    for worker in workers:
        if worker.task == task and worker.phase != "idle":
            count += 1
    return count

func _cargo_position(item: Dictionary) -> Vector3:
    if item.worker_id >= 0 and workers[item.worker_id].carrying:
        return workers[item.worker_id].position
    if item.kind == "bulk" and not str(item.bay_id).is_empty() and item.stage in ["bulk_storage","reserved_bulk_ship"]:
        return _bay(item.bay_id).position
    if _move_remaining > 0 and item.stage == "storage":
        return (_points()[_shelf_node()] as Vector3).lerp(_points()[_shelf_node(pending_layout_id)],1.0-_move_remaining/_move_duration)
    return _points()[item.node]

func slot_options() -> Array:
    return snapshot().slots

func _bottleneck() -> String:
    if not pending_layout_id.is_empty():
        return "設備と在庫を移動中" if _move_remaining>0 else "運搬と保管床が空くまで変更待ち"
    if not external_backlog.is_empty():
        return "入荷場の外にも受付済みの便が待機"
    if _free_bay().is_empty():
        return "まとめ保管床が満杯"
    if _rack_occupied()+_store_reserved() >= rack_capacity:
        return "単品棚が満杯"
    for worker in workers:
        if worker.waiting:
            return "通路で譲り合い中"
    return "2種類の仕事を運搬・処理中"

func snapshot() -> Dictionary:
    var visible_workers: Array[Dictionary] = []
    for worker in workers:
        var item := worker.duplicate(true)
        var positions: Array[Vector3] = []
        for node in worker.path:
            positions.append(_points()[node])
        item.path = positions
        item.progress = float(worker.edge_progress)
        item.job_kind = str(manifests[worker.manifest_id].kind) if worker.manifest_id>=0 else ""
        item.units = worker.cargo_ids.size()
        item.transport_radius = MANIFEST_RADIUS if item.units>1 else WORKER_RADIUS
        visible_workers.append(item)
    var visible_cargo: Array[Dictionary] = []
    for item in cargo.values():
        if item.stage in ["shipped","external"]:
            continue
        var visible: Dictionary = item.duplicate(true)
        visible.position = _cargo_position(item)
        visible.job_kind = item.kind
        visible.units = 1
        visible_cargo.append(visible)
    var visible_edges: Array[Dictionary] = []
    for edge in _edges.values():
        var item: Dictionary = edge.duplicate(true)
        item.occupied = edge.owners.size()
        item.waiters = edge.queue.size()
        visible_edges.append(item)
    var bays: Array[Dictionary] = []
    for bay in bulk_bays:
        var item := bay.duplicate(true)
        item.available = _bay_available_in(bay,layout_id)
        item.occupied = bay.manifest_id>=0
        item.reserved = bay.reserved_by>=0
        item.blocked_by = "shelf" if not item.available else ""
        item.remaining_hold = maxf(0.0,float(manifests[bay.manifest_id].release_at)-sim_time) if bay.manifest_id>=0 else 0.0
        bays.append(item)
    var option := _option(layout_id)
    var slots: Array[Dictionary] = [
        {"id":"shelf","label":"棚と保管床","position":_shelf_equipment_position(layout_id),"kind":"shelf","size":Vector3(2.2,2.2,2.8),"footprint":_shelf_footprint(layout_id),"choice_id":option.shelf_slot,"choices":[{"id":"core","label":"主棟・保管6枠","position":_shelf_equipment_position("compact"),"benefit":"まとめ保管6枠","tradeoff":"単品ピックが長い・中央1人","cost_label":"購入費なし・移動中は作業停止"},{"id":"annex","label":"増築・保管2枠","position":_shelf_equipment_position("clear_aisle"),"benefit":"単品ピックが短い・中央2人","tradeoff":"棚が保管床4枠を使う","cost_label":"購入費なし・保管床が空いてから移動"}]},
        {"id":"packing","label":"梱包の設置枠","position":_pack_equipment_position(layout_id),"size":Vector3(1.6,.95,1),"kind":"packing","choice_id":option.packing_slot,"choices":[{"id":"front","label":"出荷側","position":_pack_equipment_position("compact"),"benefit":"梱包から出荷が近い","tradeoff":"増築棚からは横断","cost_label":"購入費なし・移動中は作業停止"},{"id":"annex","label":"増築","position":_pack_equipment_position("pack_annex"),"benefit":"増築棚から梱包が短い","tradeoff":"出荷まで長い","cost_label":"購入費なし・移動中は作業停止"}]},
    ]
    for slot in slots:
        for choice in slot.choices:
            for candidate in layout_options():
                if candidate.shelf_slot == (choice.id if slot.id=="shelf" else option.shelf_slot) and candidate.packing_slot == (choice.id if slot.id=="packing" else option.packing_slot):
                    choice.relocation_stop_seconds = _estimated_relocation_stop(candidate.id)
                    choice.cost_label = "作業停止 約%d秒＋運搬・床の空き待ち"%ceili(choice.relocation_stop_seconds)
                    break
    var shelf_position := _shelf_equipment_position(layout_id)
    var pack_position := _pack_equipment_position(layout_id)
    if _move_remaining>0:
        shelf_position = shelf_position.lerp(_shelf_equipment_position(pending_layout_id),1.0-_move_remaining/_move_duration)
        pack_position = pack_position.lerp(_pack_equipment_position(pending_layout_id),1.0-_move_remaining/_move_duration)
    var jobs_by_type := {"bulk":{"shipped_units":bulk_shipped,"queued_jobs":0,"queued_units":0},"small":{"shipped_units":pick_shipped,"queued_jobs":0,"queued_units":0}}
    for manifest in manifests.values():
        var key := "bulk" if manifest.kind=="bulk" else "small"
        if manifest.shipped_units<MANIFEST_SIZE:
            jobs_by_type[key].queued_jobs += 1
            jobs_by_type[key].queued_units += MANIFEST_SIZE-int(manifest.shipped_units)
    return {"prototype":true,"jobs_by_type":jobs_by_type,"job_mix_id":workload_id,"job_mix_label":_workload(workload_id).label,"bottleneck_detail":"受付済みの便は場外待機も含めて保持。まとめ便は荷下ろしから最低%d秒保管して直送。単品便は1個ずつ集品・梱包。"%int(bulk_dwell),"timing":timing_info(),"layout_id":layout_id,"layout_label":option.label,"pending_layout_id":pending_layout_id,"workload_id":workload_id,"mix_id":workload_id,"workload_label":_workload(workload_id).label,"scenario_description":_workload(workload_id).description,"sim_time":sim_time,"duration":duration,"continuous":duration<=0,"finished":finished,"shipped":shipped,"bulk_shipped":bulk_shipped,"pick_shipped":pick_shipped,"revenue":revenue,"money":money,"arrived":arrived,"offered_units":offered_units,"initial_cargo":initial_cargo,"inbound_blocked":inbound_blocked,"stored":stored,"picked":picked,"packed":packed,"rack_capacity":rack_capacity,"rack_occupied":_rack_occupied(),"bulk_capacity":bulk_capacity(),"bulk_occupied":bulk_storage.size(),"bulk_bays":bays,"manifest_size":MANIFEST_SIZE,"manifests":manifests.duplicate(true),"mix_history":mix_history.duplicate(true),"travel_seconds":travel_seconds,"loaded_travel_seconds":loaded_travel_seconds,"aisle_wait_seconds":aisle_wait_seconds,"relocation_seconds":relocation_seconds,"relocation_count":relocation_count,"relocation_history":relocation_history.duplicate(true),"relocating":_move_remaining>0,"relocation_remaining":_move_remaining,"annex_open":true,"equipment_budget":0,"budget_description":"棚1・梱包台1・5人・床6枠を配置で使い分け","equipment_signature":"rack%d:1;bench%.1fs:1;workers:5;pallet_floor:6;annex:1"%[rack_capacity,pack_seconds],"queues":{"inbound":inbound.size()*MANIFEST_SIZE,"external":external_backlog.size()*MANIFEST_SIZE,"storage":storage.size(),"bulk_storage":bulk_storage.size()*MANIFEST_SIZE,"picking":_worker_count("pick"),"packing":packing.size(),"processing":pack_jobs.size(),"packed":ready.size(),"orders":open_orders},"workers":visible_workers,"cargo":visible_cargo,"slots":slots,"edges":visible_edges,"equipment":[{"id":"shelf","kind":"shelf","slot":option.shelf_slot,"position":shelf_position,"access_position":_points()[_shelf_node()],"size":Vector3(2.2,2.2,2.8),"capacity":rack_capacity},{"id":"packing","kind":"packing","slot":option.packing_slot,"position":pack_position,"access_position":_points()[_pack_node()],"size":Vector3(1.6,.95,1),"capacity":1}],"world":{"width":20.0,"height":12.0,"annex":Rect2(-2,-7.8,9,5.8),"aisle":Rect2(-5,-.65,3,1.3),"inbound":_points().inbound,"outbound":_points().outbound,"nodes":_points().duplicate()},"reservations":{"store_slots":_store_reserved(),"cargo":workers.filter(func(w):return w.phase != "idle").size()},"bottleneck":_bottleneck(),"comparison":comparison.duplicate(true),"invariant":check_invariants()}

func check_invariants() -> Dictionary:
    var owners: Array = []
    for queue in [inbound,external_backlog,bulk_storage]:
        for id in queue:
            owners.append_array(manifests[id].unit_ids)
    for queue in [storage,packing,ready,shipped_ids]:
        owners.append_array(queue)
    for job in pack_jobs:
        owners.append(job.cargo_id)
    for worker in workers:
        owners.append_array(worker.cargo_ids)
    var seen := {}
    for id in owners:
        if seen.has(id) or not cargo.has(id):
            return {"ok":false,"reason":"duplicate_or_unknown_cargo","cargo_id":id}
        seen[id] = true
    if owners.size()!=cargo.size() or cargo.size()!=offered_units or offered_units!=manifests.size()*MANIFEST_SIZE:
        return {"ok":false,"reason":"manifest_conservation","owned":owners.size(),"created":cargo.size(),"offered":offered_units}
    if arrived+external_backlog.size()*MANIFEST_SIZE != offered_units:
        return {"ok":false,"reason":"offered_admitted_backlog"}
    if revenue!=shipped*UNIT_VALUE or shipped_ids.size()!=shipped or money!=STARTING_CASH+revenue or bulk_shipped+pick_shipped!=shipped:
        return {"ok":false,"reason":"shipment_cash"}
    if _rack_occupied()+_store_reserved()>rack_capacity:
        return {"ok":false,"reason":"rack_overbooked"}
    var bay_manifests := {}
    for bay in bulk_bays:
        if bay.manifest_id>=0 or bay.reserved_by>=0:
            if not _bay_available_in(bay,layout_id):
                return {"ok":false,"reason":"occupied_blocked_bay","bay":bay.id}
        if bay.manifest_id>=0:
            if bay_manifests.has(bay.manifest_id):
                return {"ok":false,"reason":"duplicate_bay_manifest"}
            bay_manifests[bay.manifest_id] = true
        if bay.reserved_by>=0 and workers[bay.reserved_by].bay_id != bay.id:
            return {"ok":false,"reason":"bay_reservation"}
    for manifest in manifests.values():
        if manifest.unit_ids.size()!=MANIFEST_SIZE:
            return {"ok":false,"reason":"manifest_size"}
        var completed := 0
        var first_ship := -1.0
        for id in manifest.unit_ids:
            var item: Dictionary = cargo[id]
            if item.manifest_id!=manifest.id or item.kind!=manifest.kind:
                return {"ok":false,"reason":"manifest_identity"}
            if item.stage == "shipped":
                completed += 1
                if item.stored_at<item.created_at:
                    return {"ok":false,"reason":"shipment_skipped_storage"}
                if item.kind=="pick" and (item.picked_at<item.stored_at or item.packed_at<item.picked_at or item.shipped_at<item.packed_at):
                    return {"ok":false,"reason":"pick_skipped_stage"}
                if item.kind=="bulk" and (item.picked_at>=0 or item.packed_at>=0 or item.shipped_at<manifest.release_at):
                    return {"ok":false,"reason":"bulk_wrong_route"}
                if first_ship<0:
                    first_ship = item.shipped_at
                elif item.kind=="bulk" and not is_equal_approx(first_ship,item.shipped_at):
                    return {"ok":false,"reason":"bulk_split_shipment"}
        if completed != manifest.shipped_units or (manifest.kind=="bulk" and completed not in [0,MANIFEST_SIZE]):
            return {"ok":false,"reason":"manifest_shipment_ledger"}
    for worker in workers:
        if worker.phase in ["to_source","to_target"] and worker.path.is_empty():
            return {"ok":false,"reason":"unreachable_worker_task","worker":worker.id,"task":worker.task,"source":worker.source,"target":worker.target}
    for edge in _edges.values():
        var lanes := {}
        for owner in edge.owners:
            if str(workers[owner].edge_id)!=str(edge.id) or lanes.has(workers[owner].lane) or workers[owner].lane not in edge.open_lanes:
                return {"ok":false,"reason":"edge_owner_or_lane","edge":edge.id}
            lanes[workers[owner].lane] = true
        if edge.owners.size()>int(edge.capacity):
            return {"ok":false,"reason":"edge_overbooked","edge":edge.id}
    return {"ok":true,"total":owners.size(),"in_system":owners.size()-shipped,"shipped":shipped,"manifests":manifests.size()}

func compare_layouts(seconds: float = 300.0) -> Dictionary:
    var results: Array[Dictionary] = []
    for workload in workload_options():
        for option in layout_options():
            var other = get_script().new()
            other.restart(workload.id,option.id)
            other.duration = seconds
            while not other.finished:
                other.step(.5)
            results.append({"workload_id":workload.id,"layout_id":option.id,"shipped":other.shipped,"bulk_shipped":other.bulk_shipped,"pick_shipped":other.pick_shipped,"offered_units":other.offered_units,"remaining_cargo":other.cargo.size()-other.shipped,"travel_seconds":other.travel_seconds,"aisle_wait_seconds":other.aisle_wait_seconds,"bulk_capacity":other.bulk_capacity(),"conserved":other.check_invariants().ok})
    comparison = {"duration":seconds,"same_equipment":true,"same_start_per_workload":true,"same_offered_units":true,"depth_validated":false,"scenario_type":"6個単位の同量入荷・5人で2種類の実仕事を比較","results":results}
    return comparison.duplicate(true)
