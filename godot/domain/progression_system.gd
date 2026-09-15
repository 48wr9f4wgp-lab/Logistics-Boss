extends RefCounted
class_name LogisticsProgression

const RANK2_RATING := 8
const STAFFING_COOLDOWN_SECONDS := 30.0


func generate_offers(first_id: int) -> Array[Dictionary]:
    var offers: Array[Dictionary] = []
    offers.append({
        "id": first_id,
        "kind": "ship",
        "title": "速配 8件",
        "description": "75秒以内に8件を出荷",
        "duration": 75.0,
        "target": 8.0,
        "threshold": 0.0,
        "reward_cash": 2500,
        "reward_rp": 1,
        "reward_rating": 2,
    })
    offers.append({
        "id": first_id + 1,
        "kind": "inbound",
        "title": "搬入口クリーン",
        "description": "入荷6箱以下を24秒維持",
        "duration": 90.0,
        "target": 24.0,
        "threshold": 6.0,
        "reward_cash": 2200,
        "reward_rp": 1,
        "reward_rating": 2,
    })
    offers.append({
        "id": first_id + 2,
        "kind": "throughput",
        "title": "高効率運転",
        "description": "出荷12/分以上を20秒維持",
        "duration": 90.0,
        "target": 20.0,
        "threshold": 12.0,
        "reward_cash": 2600,
        "reward_rp": 1,
        "reward_rating": 2,
    })
    return offers


func start_contract(offer: Dictionary, shipped: int) -> Dictionary:
    var contract: Dictionary = offer.duplicate(true)
    contract["remaining"] = float(contract.get("duration", 0.0))
    contract["progress"] = 0.0
    contract["start_shipped"] = shipped
    return contract


func advance_contract(
    contract: Dictionary,
    dt: float,
    shipped: int,
    inbound_queue: int,
    shipments_per_minute: float
) -> Dictionary:
    var next: Dictionary = contract.duplicate(true)
    next["remaining"] = maxf(0.0, float(next.get("remaining", 0.0)) - maxf(0.0, dt))

    var kind := String(next.get("kind", ""))
    var progress := float(next.get("progress", 0.0))
    match kind:
        "ship":
            progress = maxf(0.0, float(shipped - int(next.get("start_shipped", shipped))))
        "inbound":
            if inbound_queue <= int(next.get("threshold", 6.0)):
                progress += dt
            else:
                progress = maxf(0.0, progress - dt * 0.7)
        "throughput":
            if shipments_per_minute >= float(next.get("threshold", 12.0)):
                progress += dt
            else:
                progress = maxf(0.0, progress - dt * 0.5)
        _:
            return {"contract": next, "success": false, "failed": true}

    next["progress"] = progress
    var success := progress >= float(next.get("target", 1.0))
    var failed := not success and float(next.get("remaining", 0.0)) <= 0.0
    return {"contract": next, "success": success, "failed": failed}


func staffing_roles(plan: String) -> Array[String]:
    var roles: Array[String] = []
    match plan:
        "receiving":
            roles = ["store", "store", "store", "pick", "ship"]
        "picking":
            roles = ["store", "pick", "pick", "pick", "ship"]
        "dock":
            roles = ["store", "store", "pick", "ship", "ship"]
        "shipping":
            roles = ["store", "pick", "pick", "ship", "ship"]
        _:
            roles = ["store", "store", "pick", "pick", "ship"]
    return roles


func staffing_label(plan: String) -> String:
    match plan:
        "receiving":
            return "受入強化 3/1/1"
        "picking":
            return "ピック強化 1/3/1"
        "dock":
            return "両端強化 2/1/2"
        "shipping":
            return "出荷強化 1/2/2"
        _:
            return "均衡 2/2/1"
