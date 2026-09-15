extends RefCounted
class_name WorkloadWaveModel

const RECOVERY_SECONDS := 35.0
const SURGE_SECONDS := 50.0

const PHASES := [
    {
        "id": "forecast_inbound",
        "key": "normal",
        "label": "入荷予告",
        "description": "35秒後の入荷便に備える",
        "duration": RECOVERY_SECONDS,
        "is_peak": false,
        "inbound_mult": 1.0,
        "order_mult": 1.8,
    },
    {
        "id": "inbound_surge",
        "key": "inbound_surge",
        "label": "入荷集中",
        "description": "到着便が集中。受入と棚入れを回す",
        "duration": SURGE_SECONDS,
        "is_peak": true,
        "inbound_mult": 0.32,
        "order_mult": 2.2,
    },
    {
        "id": "forecast_orders",
        "key": "normal",
        "label": "注文予告",
        "description": "35秒後の受注ピークに備える",
        "duration": RECOVERY_SECONDS,
        "is_peak": false,
        "inbound_mult": 1.8,
        "order_mult": 1.0,
    },
    {
        "id": "order_surge",
        "key": "order_surge",
        "label": "注文集中",
        "description": "受注が集中。棚から梱包へ流す",
        "duration": SURGE_SECONDS,
        "is_peak": true,
        "inbound_mult": 2.2,
        "order_mult": 0.30,
    },
    {
        "id": "forecast_dispatch",
        "key": "normal",
        "label": "出荷予告",
        "description": "35秒後の集荷締切へ荷物を整える",
        "duration": RECOVERY_SECONDS,
        "is_peak": false,
        "inbound_mult": 2.4,
        "order_mult": 2.0,
    },
    {
        "id": "dispatch_window",
        "key": "dispatch_window",
        "label": "出荷締切",
        "description": "新規流入は落ち着く。締切までに出荷を最大化",
        "duration": SURGE_SECONDS,
        "is_peak": true,
        "inbound_mult": 2.8,
        "order_mult": 2.5,
    },
]


func cycle_duration() -> float:
    var total := 0.0
    for phase in PHASES:
        total += float(phase["duration"])
    return total


func normalized_clock(clock: float) -> float:
    var total := cycle_duration()
    if total <= 0.0:
        return 0.0
    return fposmod(maxf(0.0, clock), total)


func phase_index_at(clock: float) -> int:
    var cursor := normalized_clock(clock)
    for index in PHASES.size():
        var duration := float(PHASES[index]["duration"])
        if cursor < duration:
            return index
        cursor -= duration
    return 0


func phase_id_at(clock: float) -> String:
    return String(PHASES[phase_index_at(clock)]["id"])


func state_at(clock: float) -> Dictionary:
    var normalized := normalized_clock(clock)
    var index := phase_index_at(normalized)
    var phase: Dictionary = PHASES[index]
    var elapsed := normalized
    for prior in index:
        elapsed -= float(PHASES[prior]["duration"])

    var duration := float(phase["duration"])
    var next_peak := _next_peak_from(index, elapsed)
    return {
        "enabled": true,
        "phase_id": String(phase["id"]),
        "key": String(phase["key"]),
        "label": String(phase["label"]),
        "description": String(phase["description"]),
        "is_peak": bool(phase["is_peak"]),
        "elapsed": elapsed,
        "remaining": maxf(0.0, duration - elapsed),
        "duration": duration,
        "progress": clampf(elapsed / maxf(0.001, duration), 0.0, 1.0),
        "inbound_interval_multiplier": float(phase["inbound_mult"]),
        "order_interval_multiplier": float(phase["order_mult"]),
        "next_wave_key": String(next_peak.get("key", "")),
        "next_wave_label": String(next_peak.get("label", "")),
        "seconds_until_next_wave": float(next_peak.get("seconds", 0.0)),
        "cycle_clock": normalized,
        "cycle_duration": cycle_duration(),
    }


func inbound_interval_multiplier(clock: float) -> float:
    return float(PHASES[phase_index_at(clock)]["inbound_mult"])


func order_interval_multiplier(clock: float) -> float:
    return float(PHASES[phase_index_at(clock)]["order_mult"])


func is_dispatch_window(clock: float) -> bool:
    return String(PHASES[phase_index_at(clock)]["key"]) == "dispatch_window"


func _next_peak_from(index: int, elapsed: float) -> Dictionary:
    var seconds := float(PHASES[index]["duration"]) - elapsed
    for offset in range(1, PHASES.size() + 1):
        var next_index := (index + offset) % PHASES.size()
        var candidate: Dictionary = PHASES[next_index]
        if bool(candidate["is_peak"]):
            return {
                "key": String(candidate["key"]),
                "label": String(candidate["label"]),
                "seconds": maxf(0.0, seconds),
            }
        seconds += float(candidate["duration"])
    return {"key": "", "label": "", "seconds": 0.0}
