extends RefCounted
class_name FlowMeasurement

const WINDOW_SECONDS := 25.0
const HISTORY_SECONDS := 90.0
const RESULT_IMPROVEMENT_RATIO := 0.05
const RESULT_MIN_DELTA := 0.5

var _state_samples: Array[Dictionary] = []
var _order_samples: Array[Dictionary] = []
var _shipment_events: Array[Dictionary] = []
var _active_measurements: Array[Dictionary] = []


static func classify_result(before: Dictionary, after: Dictionary) -> Dictionary:
    var before_rate := float(before.get("shipments_per_min", 0.0))
    var after_rate := float(after.get("shipments_per_min", 0.0))
    var delta := after_rate - before_rate
    var threshold := maxf(RESULT_MIN_DELTA, absf(before_rate) * RESULT_IMPROVEMENT_RATIO)

    var state := "flat"
    var headline := "横ばい"
    if delta >= threshold:
        state = "improved"
        headline = "改善"
    elif delta <= -threshold:
        state = "regressed"
        headline = "要再判断"

    return {
        "state": state,
        "headline": headline,
        "delta": delta,
        "threshold": threshold,
    }


func record_state(at: float, dt: float, inbound: int, packing: int, outbound: int, orders: int = 0) -> void:
    if dt <= 0.0:
        return
    _state_samples.append({
        "at": at,
        "dt": dt,
        "inbound": inbound,
        "packing": packing,
        "outbound": outbound,
        "orders": orders,
    })
    _prune(at)


func record_orders(at: float, dt: float, orders: int) -> void:
    if dt <= 0.0:
        return
    _order_samples.append({
        "at": at,
        "dt": dt,
        "orders": maxi(0, orders),
    })
    _prune(at)


func record_shipment(at: float, value: int) -> void:
    _shipment_events.append({"at": at, "value": value})
    _prune(at)


func begin_investment(kind: StringName, cost: int, at: float) -> Dictionary:
    var before := _metrics(at - WINDOW_SECONDS, at)
    _active_measurements.append({
        "kind": String(kind),
        "cost": cost,
        "started_at": at,
        "before": before,
    })
    return before


func collect_completed(at: float) -> Array[Dictionary]:
    var completed: Array[Dictionary] = []
    var remaining: Array[Dictionary] = []

    for measurement in _active_measurements:
        var started_at := float(measurement.get("started_at", 0.0))
        if at + 0.0001 < started_at + WINDOW_SECONDS:
            remaining.append(measurement)
            continue

        var before: Dictionary = measurement.get("before", {})
        var after := _metrics(started_at, started_at + WINDOW_SECONDS)
        var verdict: Dictionary = classify_result(before, after)
        completed.append({
            "kind": String(measurement.get("kind", "")),
            "cost": int(measurement.get("cost", 0)),
            "window_seconds": WINDOW_SECONDS,
            "before": before,
            "after": after,
            "verdict": verdict,
            "delta": {
                "shipments_per_min": float(after.get("shipments_per_min", 0.0)) - float(before.get("shipments_per_min", 0.0)),
                "revenue_per_min": float(after.get("revenue_per_min", 0.0)) - float(before.get("revenue_per_min", 0.0)),
                "inbound_queue": float(after.get("inbound_queue", 0.0)) - float(before.get("inbound_queue", 0.0)),
                "packing_queue": float(after.get("packing_queue", 0.0)) - float(before.get("packing_queue", 0.0)),
                "outbound_queue": float(after.get("outbound_queue", 0.0)) - float(before.get("outbound_queue", 0.0)),
                "open_orders": float(after.get("open_orders", 0.0)) - float(before.get("open_orders", 0.0)),
            },
        })

    _active_measurements = remaining
    return completed


func _metrics(start_at: float, end_at: float) -> Dictionary:
    var requested_duration := maxf(0.001, end_at - start_at)
    var shipments := 0
    var revenue := 0

    for shipment in _shipment_events:
        var event_at := float(shipment.get("at", -INF))
        if event_at > start_at and event_at <= end_at:
            shipments += 1
            revenue += int(shipment.get("value", 0))

    var weighted_inbound := 0.0
    var weighted_packing := 0.0
    var weighted_outbound := 0.0
    var weighted_state_orders := 0.0
    var sampled_duration := 0.0

    for sample in _state_samples:
        var sample_at := float(sample.get("at", -INF))
        if sample_at <= start_at or sample_at > end_at:
            continue
        var sample_dt := maxf(0.0, float(sample.get("dt", 0.0)))
        sampled_duration += sample_dt
        weighted_inbound += float(sample.get("inbound", 0)) * sample_dt
        weighted_packing += float(sample.get("packing", 0)) * sample_dt
        weighted_outbound += float(sample.get("outbound", 0)) * sample_dt
        weighted_state_orders += float(sample.get("orders", 0)) * sample_dt

    var weighted_orders := 0.0
    var order_sampled_duration := 0.0
    for sample in _order_samples:
        var sample_at := float(sample.get("at", -INF))
        if sample_at <= start_at or sample_at > end_at:
            continue
        var sample_dt := maxf(0.0, float(sample.get("dt", 0.0)))
        order_sampled_duration += sample_dt
        weighted_orders += float(sample.get("orders", 0)) * sample_dt

    var rate_duration := maxf(0.001, minf(requested_duration, sampled_duration if sampled_duration > 0.0 else requested_duration))
    var average_duration := maxf(0.001, sampled_duration)
    var order_average := 0.0
    if order_sampled_duration > 0.0:
        order_average = weighted_orders / order_sampled_duration
    elif sampled_duration > 0.0:
        order_average = weighted_state_orders / average_duration

    return {
        "window_seconds": requested_duration,
        "sampled_seconds": sampled_duration,
        "baseline_complete": sampled_duration >= requested_duration * 0.90,
        "shipments": shipments,
        "shipments_per_min": float(shipments) * 60.0 / rate_duration,
        "revenue": revenue,
        "revenue_per_min": float(revenue) * 60.0 / rate_duration,
        "inbound_queue": weighted_inbound / average_duration if sampled_duration > 0.0 else 0.0,
        "packing_queue": weighted_packing / average_duration if sampled_duration > 0.0 else 0.0,
        "outbound_queue": weighted_outbound / average_duration if sampled_duration > 0.0 else 0.0,
        "open_orders": order_average,
        "open_orders_sampled_seconds": order_sampled_duration,
    }


func _prune(at: float) -> void:
    var cutoff := at - HISTORY_SECONDS
    while not _state_samples.is_empty() and float(_state_samples[0].get("at", 0.0)) < cutoff:
        _state_samples.pop_front()
    while not _order_samples.is_empty() and float(_order_samples[0].get("at", 0.0)) < cutoff:
        _order_samples.pop_front()
    while not _shipment_events.is_empty() and float(_shipment_events[0].get("at", 0.0)) < cutoff:
        _shipment_events.pop_front()
