extends Node3D
class_name WarehouseInvestmentFeedbackView

const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")
const CYAN := Color(0.16, 0.80, 1.0)
const FLAT_BLUE := Color(0.40, 0.68, 0.92)
const AMBER := Color(1.0, 0.62, 0.16)
const MINT := Color(0.24, 0.95, 0.67)
const RANK_CYAN := Color(0.32, 0.88, 1.0)
const INVESTMENT_LIFETIME := 0.72
const RESULT_LIFETIME := 0.82
const RANK_LIFETIME := 1.08
const MAX_ACTIVE_PULSES := 6

const CENTER_FLOOR := Vector3(0.0, 0.14, 2.25)
const INBOUND_CENTER := Vector3(-5.25, 0.14, 1.25)
const STORAGE_CENTER := Vector3(-1.60, 0.14, -0.15)
const PACKING_CENTER := Vector3(2.55, 0.14, -0.05)
const OUTBOUND_CENTER := Vector3(5.15, 0.14, 1.25)
const FORKLIFT_CENTER := Vector3(-3.70, 0.14, 1.45)
const ANNEX_CENTER := Vector3(-5.25, 0.14, 6.10)
const FACILITY_CENTER := Vector3(0.0, 0.14, 0.55)

var warehouse_view: WarehouseView
var sim: WarehouseSim
var feedback_count := 0
var last_event_type := ""
var last_result_state := ""
var last_center := Vector3.ZERO
var last_half_extents := Vector2.ZERO
var last_lifetime := 0.0
var last_color := Color.TRANSPARENT

var _pulse_sequence := 0
var _active_pulses: Array[Node3D] = []


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)

    warehouse_view = view
    sim = next_sim
    if sim != null and not sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.connect(_on_sim_event)


func _on_sim_event(event: Dictionary) -> void:
    var event_type := String(event.get("type", ""))
    match event_type:
        "upgrade_purchased":
            var kind := String(event.get("kind", ""))
            _spawn_feedback(
                _upgrade_center(kind),
                _upgrade_extent(kind),
                AMBER if kind == "packing" or kind == "forklift" else CYAN,
                INVESTMENT_LIFETIME,
                event_type
            )
        "rank1_project_purchased":
            var project_kind := String(event.get("kind", ""))
            _spawn_feedback(
                _rank1_project_center(project_kind),
                _rank1_project_extent(project_kind),
                AMBER if project_kind == "second_packing_bench" or project_kind == "forklift_project" else CYAN,
                INVESTMENT_LIFETIME,
                event_type
            )
        "facility_purchased":
            var group := String(event.get("group", ""))
            _spawn_feedback(
                _facility_group_center(group),
                Vector2(1.65, 1.15),
                CYAN if group != "packing" else AMBER,
                INVESTMENT_LIFETIME,
                event_type
            )
        "receiving_annex_purchased", "inbound_carrier_program_purchased":
            _spawn_feedback(
                ANNEX_CENTER,
                Vector2(2.10, 1.45),
                MINT,
                INVESTMENT_LIFETIME,
                event_type
            )
        "routing_changed":
            _spawn_feedback(
                OUTBOUND_CENTER,
                Vector2(1.70, 1.15),
                MINT,
                INVESTMENT_LIFETIME,
                event_type
            )
        "rank_up":
            # Rank promotion is intentionally broader and longer than a normal
            # purchase. It outlines the facility footprint so progression reads
            # as a change in the whole operation, not as another button click.
            _spawn_feedback(
                FACILITY_CENTER,
                Vector2(7.15, 4.65),
                RANK_CYAN,
                RANK_LIFETIME,
                event_type
            )
        "measurement_completed":
            var before: Dictionary = event.get("before", {})
            var after: Dictionary = event.get("after", {})
            var verdict: Dictionary = event.get("verdict", {})
            if verdict.is_empty():
                verdict = FlowMeasurementScript.classify_result(before, after)
            var result_state := String(verdict.get("state", "flat"))
            var measurement_kind := String(event.get("kind", ""))
            last_result_state = result_state
            _spawn_feedback(
                _measurement_center(measurement_kind),
                _measurement_extent(measurement_kind),
                _measurement_color(result_state),
                RESULT_LIFETIME,
                event_type
            )
        _:
            return


func _rank1_project_center(kind: String) -> Vector3:
    match kind:
        "rack_wing":
            return STORAGE_CENTER
        "second_packing_bench":
            return PACKING_CENTER
        "forklift_project":
            return FORKLIFT_CENTER
        "worker_hire":
            return CENTER_FLOOR
        _:
            return CENTER_FLOOR


func _rank1_project_extent(kind: String) -> Vector2:
    match kind:
        "rack_wing":
            return Vector2(2.20, 2.45)
        "second_packing_bench":
            return Vector2(1.65, 1.45)
        "forklift_project":
            return Vector2(1.25, 1.10)
        _:
            return Vector2(1.55, 1.15)


func _upgrade_center(kind: String) -> Vector3:
    match kind:
        "rack":
            return STORAGE_CENTER
        "packing":
            return PACKING_CENTER
        "forklift":
            return FORKLIFT_CENTER
        "worker", "speed":
            return CENTER_FLOOR
        _:
            return CENTER_FLOOR


func _upgrade_extent(kind: String) -> Vector2:
    match kind:
        "rack":
            return Vector2(1.65, 2.35)
        "packing":
            return Vector2(1.65, 1.45)
        "forklift", "rank1_forklift_project":
            return Vector2(1.25, 1.10)
        _:
            return Vector2(1.55, 1.15)


func _facility_group_center(group: String) -> Vector3:
    match group:
        "intake":
            return INBOUND_CENTER
        "storage":
            return STORAGE_CENTER
        "packing":
            return PACKING_CENTER
        _:
            return CENTER_FLOOR


func _measurement_center(kind: String) -> Vector3:
    match kind:
        "worker", "speed":
            return CENTER_FLOOR
        "rack", "rank1_rack_wing", "facility_fast_pick_rack", "facility_high_density_rack":
            return STORAGE_CENTER
        "packing", "rank1_second_packing_bench", "facility_parallel_pack", "facility_fast_pack_cell":
            return PACKING_CENTER
        "forklift", "rank1_forklift_project":
            return FORKLIFT_CENTER
        "rank1_worker_hire":
            return CENTER_FLOOR
        "facility_double_dock", "facility_buffer_yard":
            return INBOUND_CENTER
        "receiving_annex", "inbound_carrier_program":
            return ANNEX_CENTER
        "routing_balanced", "routing_express", "routing_consolidated":
            return OUTBOUND_CENTER
        _:
            return CENTER_FLOOR


func _measurement_extent(kind: String) -> Vector2:
    match kind:
        "rack", "rank1_rack_wing", "facility_fast_pick_rack", "facility_high_density_rack":
            return Vector2(1.90, 2.35)
        "packing", "rank1_second_packing_bench", "facility_parallel_pack", "facility_fast_pack_cell":
            return Vector2(1.65, 1.45)
        "facility_double_dock", "facility_buffer_yard":
            return Vector2(1.80, 1.35)
        "receiving_annex", "inbound_carrier_program":
            return Vector2(2.10, 1.45)
        "routing_balanced", "routing_express", "routing_consolidated":
            return Vector2(1.70, 1.15)
        "forklift":
            return Vector2(1.25, 1.10)
        _:
            return Vector2(1.55, 1.15)


func _measurement_color(state: String) -> Color:
    match state:
        "improved":
            return MINT
        "regressed":
            return AMBER
        _:
            return FLAT_BLUE


func _spawn_feedback(
    center: Vector3,
    half_extents: Vector2,
    color: Color,
    lifetime: float,
    event_type: String
) -> void:
    _pulse_sequence += 1
    var pulse := Node3D.new()
    pulse.name = "OperationalFeedbackPulse_%d" % _pulse_sequence
    pulse.position = center
    pulse.scale = Vector3(0.72, 1.0, 0.72)
    add_child(pulse)

    var edge_thickness := 0.075
    _pulse_bar(
        pulse,
        "North",
        Vector3(half_extents.x * 2.0, 0.035, edge_thickness),
        Vector3(0.0, 0.0, -half_extents.y),
        color
    )
    _pulse_bar(
        pulse,
        "South",
        Vector3(half_extents.x * 2.0, 0.035, edge_thickness),
        Vector3(0.0, 0.0, half_extents.y),
        color
    )
    _pulse_bar(
        pulse,
        "West",
        Vector3(edge_thickness, 0.035, half_extents.y * 2.0),
        Vector3(-half_extents.x, 0.0, 0.0),
        color
    )
    _pulse_bar(
        pulse,
        "East",
        Vector3(edge_thickness, 0.035, half_extents.y * 2.0),
        Vector3(half_extents.x, 0.0, 0.0),
        color
    )

    # A short center beacon makes small investments readable on a phone without
    # adding a dynamic light, particle system or gameplay object.
    _pulse_bar(
        pulse,
        "Beacon",
        Vector3(0.10, 0.62, 0.10),
        Vector3(0.0, 0.32, 0.0),
        color
    )

    feedback_count += 1
    last_event_type = event_type
    last_center = center
    last_half_extents = half_extents
    last_lifetime = lifetime
    last_color = color

    _active_pulses.append(pulse)
    while _active_pulses.size() > MAX_ACTIVE_PULSES:
        var oldest: Node3D = _active_pulses.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

    var tween := pulse.create_tween()
    tween.set_parallel(true)
    tween.tween_property(
        pulse,
        "scale",
        Vector3(1.13, 1.0, 1.13),
        lifetime
    ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    for child in pulse.get_children():
        var mesh := child as MeshInstance3D
        if mesh == null:
            continue
        var material := mesh.material_override as StandardMaterial3D
        if material == null:
            continue
        tween.tween_property(
            material,
            "emission_energy_multiplier",
            0.25,
            lifetime
        ).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

    tween.chain().tween_callback(_finish_pulse.bind(pulse))


func _pulse_bar(
    parent: Node3D,
    node_name: String,
    size: Vector3,
    position: Vector3,
    color: Color
) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.38
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 3.6
    instance.material_override = material
    parent.add_child(instance)
    return instance


func _finish_pulse(pulse: Node3D) -> void:
    _active_pulses.erase(pulse)
    if is_instance_valid(pulse):
        pulse.queue_free()


func active_pulse_count() -> int:
    var count := 0
    for pulse in _active_pulses:
        if is_instance_valid(pulse):
            count += 1
    return count


func _exit_tree() -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
