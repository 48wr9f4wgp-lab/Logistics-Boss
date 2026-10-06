extends "res://prototype/growth_sim.gd"
class_name FlotraDispatchSim

# Dispatch admission is a work-in-progress reservation, not physical storage.
const StateCodec = preload("res://prototype/dispatch_state_codec.gd")
const DISPATCH_SCHEMA := 5
const DISPATCH_UPGRADE := {"id":"pick_dispatch_board","label":"集品指示盤",
    "description":"仕事の合間に先行集品を6 / 12枠から無料で選べます。多く先行すると通路待ちが増え、仕事によって遅くなる場合があります。",
    "cost":300,"unlock_after":4}
const DISPATCH_CONTRACT := {"id":"route_parcel_120","label":"定期便：単品連続120個",
    "description":"単品20便、120個。先行集品の量を仕事に合わせて選ぼう。",
    "manifest_quota":20,"bulk_manifests":0,"pick_manifests":20,"mix":"pick_heavy",
    "interval":0.5,"dwell":0.0,"reward":300,"gold_seconds":180.0,"silver_seconds":320.0}
var dispatch_window := 6

func _contracts() -> Array:
    return super._contracts() + [DISPATCH_CONTRACT]

func _upgrades() -> Array:
    return super._upgrades() + [DISPATCH_UPGRADE]

func _contract_unlocked(id: String) -> bool:
    if id == str(DISPATCH_CONTRACT.id): return contract_results.has("growth_4")
    return super._contract_unlocked(id)

func _remaining_contracts(id: String) -> String:
    if id == str(DISPATCH_CONTRACT.id): return "ステップ4を完了すると選べます"
    return super._remaining_contracts(id)

func contract_options() -> Array[Dictionary]:
    var options := super.contract_options()
    var option: Dictionary = DISPATCH_CONTRACT.duplicate(true)
    option.repeatable = true
    option.total_units = 120
    option.completed = contract_results.has(option.id)
    option.is_replay = option.completed
    option.available = campaign_status != "running" and _contract_unlocked(str(option.id))
    option.locked_reason = "作業中の契約を完了してください" if campaign_status == "running" else ("" if _contract_unlocked(str(option.id)) else _remaining_contracts(str(option.id)))
    option.best_time = float(contract_results.get(option.id,{}).get("best_time",0.0))
    option.best_medal = str(contract_results.get(option.id,{}).get("best_medal",""))
    options.append(option)
    return options

func dispatch_unlock_reasons() -> Array[String]:
    var reasons: Array[String] = []
    if not contract_results.has("growth_4"): reasons.append("ステップ4を完了")
    if "crew_6" not in purchased_upgrades: reasons.append("スタッフ6人")
    if "robot_4" not in purchased_upgrades: reasons.append("運搬ロボット4台")
    if "auto_pack" not in purchased_upgrades: reasons.append("自動梱包機")
    return reasons

func upgrade_options() -> Array[Dictionary]:
    var options := super.upgrade_options()
    var option: Dictionary = DISPATCH_UPGRADE.duplicate(true)
    option.owned = str(option.id) in purchased_upgrades
    option.unlocked = dispatch_unlock_reasons().is_empty()
    option.available = false
    option.locked_reason = ""
    option.effect_preview = {"before":6,"after":12,"unit":"dispatch_admission","reversible":true}
    if option.owned: option.locked_reason = "導入済み"
    elif not option.unlocked: option.locked_reason = "必要条件：" + "・".join(dispatch_unlock_reasons())
    elif campaign_status == "running": option.locked_reason = "仕事が終わると購入できます"
    elif campaign_wallet < int(option.cost): option.locked_reason = "資金があと%d必要です" % (int(option.cost)-campaign_wallet)
    else: option.available = true
    options.append(option)
    return options

func buy_upgrade(id: String) -> Dictionary:
    var result := super.buy_upgrade(id)
    if result.ok and id == str(DISPATCH_UPGRADE.id):
        # Buying the choice never silently enables more work in progress.
        dispatch_window = 6
        _snapshot_dirty = true
    return result

func set_dispatch_window(value: int) -> Dictionary:
    if campaign_status == "running": return {"ok":false,"reason":"running"}
    if value not in [6,12]: return {"ok":false,"reason":"unknown"}
    if value == 12 and str(DISPATCH_UPGRADE.id) not in purchased_upgrades:
        return {"ok":false,"reason":"not_owned"}
    if not pending_layout_id.is_empty() or _move_remaining > 0.0:
        return {"ok":false,"reason":"relocating"}
    dispatch_window = value
    _snapshot_dirty = true
    return {"ok":true,"dispatch_window":value,"cost":0}

func _pick_admission_limit() -> int:
    if operating_profile and not legacy_profile and str(DISPATCH_UPGRADE.id) in purchased_upgrades:
        return dispatch_window
    return 6

func dispatch_state() -> Dictionary:
    var units := {"reserved_on_rack":[],"in_transit":[],"waiting_at_packer":packing.duplicate(),"processing":[]}
    for worker in workers:
        if worker.task != "pick": continue
        if worker.phase in ["to_source","work"]: units.reserved_on_rack.append_array(worker.cargo_ids)
        elif worker.phase == "to_target": units.in_transit.append_array(worker.cargo_ids)
    for job in pack_jobs: units.processing.append(job.cargo_id)
    var can_switch := campaign_status != "running" and pending_layout_id.is_empty() and _move_remaining <= 0.0
    return {"owned":str(DISPATCH_UPGRADE.id) in purchased_upgrades,"selected_window":dispatch_window,
        "effective_window":_pick_admission_limit(),"can_switch":can_switch,
        "blocked_reason":"仕事中は変更できません。全出荷後に無料で切り替えられます。一時停止中も同じです。" if campaign_status == "running" else ("設備の移動完了を待ってください" if not can_switch else ""),
        "units":units,"wip":packing.size()+pack_jobs.size()+_pick_units_in_transit()}

func _next_goal() -> String:
    if legacy_profile and campaign_status == "running": return super._next_goal()
    var previous_catalog := super.upgrade_options()
    if contract_results.has("growth_4") and str(DISPATCH_UPGRADE.id) not in purchased_upgrades and previous_catalog.all(func(option): return bool(option.owned)):
        if campaign_wallet < int(DISPATCH_UPGRADE.cost):
            return "集品指示盤まで資金あと%d。定期便でためよう" % (int(DISPATCH_UPGRADE.cost)-campaign_wallet)
        return "集品指示盤で、仕事に合わせた先行量を選ぼう"
    return super._next_goal()

func release_state() -> Dictionary:
    var state := super.release_state()
    state.schema = DISPATCH_SCHEMA
    state.dispatch = dispatch_state()
    return state

func _completed_run_summary() -> Dictionary:
    var result := super._completed_run_summary()
    result.dispatch_window = _pick_admission_limit()
    return result

func check_invariants() -> Dictionary:
    var result := super.check_invariants()
    if not result.ok: return result
    if dispatch_window not in [6,12]: return {"ok":false,"reason":"dispatch_window"}
    if packing.size()+pack_jobs.size()+_pick_units_in_transit() > _pick_admission_limit():
        return {"ok":false,"reason":"dispatch_wip_overbooked"}
    return result

func export_release_state() -> Dictionary:
    return StateCodec.export_state(self,super.export_release_state())

func import_release_state(data: Dictionary) -> Dictionary:
    return StateCodec.import_state(self,data)
