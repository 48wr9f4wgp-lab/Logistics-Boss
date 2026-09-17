extends Node3D
class_name WarehouseVisualCompositionFix

const BASE_FOV := 32.5
const OVERVIEW_FOV := 38.5
const OVERVIEW_START_DISTANCE := 20.5
const OVERVIEW_MAX_DISTANCE := 25.0

const PREMIUM_FLOOR := Color(0.072, 0.095, 0.112)
const PREMIUM_NAVY := Color(0.018, 0.038, 0.052)
const PREMIUM_STEEL := Color(0.080, 0.125, 0.150)
const BRUSHED_STEEL := Color(0.185, 0.245, 0.270)
const DARK_EQUIPMENT := Color(0.047, 0.075, 0.090)
const INBOUND_TINT := Color(0.050, 0.145, 0.195)
const PACK_TINT := Color(0.180, 0.105, 0.035)
const OUTBOUND_TINT := Color(0.040, 0.145, 0.110)
const APRON_TINT := Color(0.075, 0.095, 0.110)
const SITE_CONCRETE := Color(0.030, 0.041, 0.049)
const SERVICE_CONCRETE := Color(0.052, 0.066, 0.075)
const ROAD_TINT := Color(0.022, 0.029, 0.034)
const YARD_LINE := Color(0.30, 0.34, 0.35)
const YARD_WARM := Color(1.0, 0.66, 0.30)
const PRACTICAL_WARM := Color(1.0, 0.78, 0.52)
const PRACTICAL_COOL := Color(0.46, 0.78, 1.0)
const SAFETY_AMBER := Color(0.88, 0.43, 0.075)
const FLOOR_JOINT := Color(0.105, 0.125, 0.135)

var warehouse_view: WarehouseView


func bind(view: WarehouseView) -> void:
    warehouse_view = view
    warehouse_view._camera_distance = 16.7
    warehouse_view._orbit_pitch = -0.69
    warehouse_view._orbit_yaw = -0.80
    if warehouse_view.sim != null and not warehouse_view.sim.event_emitted.is_connected(_on_domain_event):
        warehouse_view.sim.event_emitted.connect(_on_domain_event)
    call_deferred("_apply_composition")


func _process(_delta: float) -> void:
    if warehouse_view == null:
        return

    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return

    # Preserve the approved normal framing, but let the current pinch limit act
    # as a true overview on portrait phones. Widening only near max distance is
    # equivalent to moving the camera farther away without making the normal
    # play view smaller.
    var overview_t := clampf(
        (warehouse_view._camera_distance - OVERVIEW_START_DISTANCE)
        / (OVERVIEW_MAX_DISTANCE - OVERVIEW_START_DISTANCE),
        0.0,
        1.0
    )
    camera.fov = lerpf(BASE_FOV, OVERVIEW_FOV, smoothstep(0.0, 1.0, overview_t))


func _apply_composition() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        camera.fov = BASE_FOV

    _reduce_foreground_structure()
    _build_site_context()
    _build_floor_finish_details()
    _build_premium_practicals()
    _apply_north_star_environment()
    _apply_north_star_palette()
    _limit_dynamic_shadow_cost()
    _deemphasize_truck()


func _on_domain_event(event: Dictionary) -> void:
    # Facility/rack geometry is rebuilt after authoritative purchases. Re-apply
    # the same controlled material family on the next idle frame so newly created
    # modules do not fall back to the older flat-plastic look.
    var event_type := String(event.get("type", ""))
    if event_type in [
        "upgrade_purchased",
        "facility_purchased",
        "rank_up",
        "receiving_annex_purchased",
        "routing_mode_changed",
        "inbound_carrier_purchased",
    ]:
        call_deferred("_apply_north_star_palette")


func _reduce_foreground_structure() -> void:
    if warehouse_view == null:
        return

    for child in warehouse_view.get_children():
        _tune_structure_recursive(child)


func _tune_structure_recursive(node: Node) -> void:
    if node is Node3D:
        var n := node as Node3D
        # LOGISTICS BOSS uses an open-top cutaway. Anything that can become a
        # large foreground slab or cross the portrait camera is removed from the
        # gameplay view; the back wall and columns still carry warehouse identity.
        if n.name == "RoofTruss" or n.name == "RoofLight" or n.name == "LeftWall":
            n.visible = false

    for child in node.get_children():
        _tune_structure_recursive(child)


func _build_site_context() -> void:
    if get_node_or_null("SiteContext") != null:
        return

    # The warehouse previously floated in a near-black void. A low-detail site
    # slab, service apron and road create the miniature logistics-campus read of
    # the North Star without introducing fake gameplay objects or expensive art.
    var root := Node3D.new()
    root.name = "SiteContext"
    add_child(root)

    _site_box(root, "SiteSlab", Vector3(23.5, 0.10, 18.8), Vector3(0.0, -0.35, 0.55), SITE_CONCRETE, 0.96, 0.0)
    _site_box(root, "RearServiceApron", Vector3(17.8, 0.055, 3.25), Vector3(0.0, -0.275, -6.45), SERVICE_CONCRETE, 0.92, 0.0)
    _site_box(root, "FrontServiceRoad", Vector3(19.2, 0.055, 3.10), Vector3(1.10, -0.275, 5.85), ROAD_TINT, 0.98, 0.0)

    # Sparse lane paint gives the exterior enough scale cues at overview distance.
    for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
        _site_box(root, "RearBayMark", Vector3(0.055, 0.018, 2.15), Vector3(x, -0.235, -6.35), YARD_LINE, 0.82, 0.0)
    for x in [-6.0, -2.0, 2.0, 6.0]:
        _site_box(root, "RoadDash", Vector3(1.35, 0.018, 0.06), Vector3(x, -0.235, 5.82), Color(0.48, 0.50, 0.47), 0.78, 0.0)

    # Emissive-only yard beacons add the impression of a working site with almost
    # no runtime lighting cost. They intentionally cast no dynamic light/shadow.
    for p in [Vector3(-8.55, 0.0, -6.85), Vector3(8.55, 0.0, -6.85), Vector3(-8.75, 0.0, 5.95), Vector3(8.75, 0.0, 5.95)]:
        _site_box(root, "YardLampPost", Vector3(0.10, 2.45, 0.10), p + Vector3(0.0, 0.88, 0.0), PREMIUM_STEEL, 0.68, 0.15)
        _site_emissive_box(root, "YardLampGlow", Vector3(0.30, 0.12, 0.24), p + Vector3(0.0, 2.10, 0.0), YARD_WARM, 2.2)


func _build_floor_finish_details() -> void:
    if get_node_or_null("PremiumFloorDetails") != null:
        return

    # Thin low-contrast expansion joints break the single-slab look without
    # competing with the operational lane markings or inventing a second flow map.
    var root := Node3D.new()
    root.name = "PremiumFloorDetails"
    add_child(root)

    for z in [-2.25, 0.45, 3.05]:
        _site_box(root, "FloorJoint", Vector3(14.15, 0.010, 0.022), Vector3(0.0, -0.025, z), FLOOR_JOINT, 0.93, 0.0)
    for x in [-3.85, 0.75, 4.25]:
        _site_box(root, "FloorJoint", Vector3(0.022, 0.010, 9.70), Vector3(x, -0.025, 0.55), FLOOR_JOINT, 0.93, 0.0)

    # Small neutral kick plates make the packing hero cell feel installed rather
    # than placed on top of the floor. These remain non-semantic and non-emissive.
    _site_box(root, "PackKickPlateL", Vector3(0.11, 0.055, 2.45), Vector3(1.08, 0.045, -0.08), BRUSHED_STEEL, 0.42, 0.30)
    _site_box(root, "PackKickPlateR", Vector3(0.11, 0.055, 2.45), Vector3(4.02, 0.045, -0.08), BRUSHED_STEEL, 0.42, 0.30)


func _build_premium_practicals() -> void:
    if get_node_or_null("PremiumPracticals") != null:
        return

    # Four emissive fixture bars create a premium human-scale work-light rhythm.
    # They do not cast light or shadows: the existing bounded Omni lights still
    # provide illumination, while these meshes only make the light sources visible.
    var root := Node3D.new()
    root.name = "PremiumPracticals"
    add_child(root)

    var fixtures := [
        {"position": Vector3(-5.25, 3.08, -4.70), "color": PRACTICAL_WARM},
        {"position": Vector3(-1.60, 3.18, -4.70), "color": PRACTICAL_COOL},
        {"position": Vector3(2.55, 3.05, -4.70), "color": PRACTICAL_WARM},
        {"position": Vector3(5.15, 3.08, -4.70), "color": PRACTICAL_WARM},
    ]
    for fixture_variant in fixtures:
        var fixture: Dictionary = fixture_variant
        var p: Vector3 = fixture["position"]
        var color: Color = fixture["color"]
        _site_box(root, "PracticalHousing", Vector3(1.18, 0.12, 0.12), p, PREMIUM_STEEL, 0.46, 0.22)
        _site_emissive_box(root, "PracticalGlow", Vector3(0.96, 0.045, 0.045), p + Vector3(0.0, -0.015, 0.075), color, 1.65)


func _apply_north_star_environment() -> void:
    if warehouse_view == null:
        return

    for child in warehouse_view.get_children():
        if child is WorldEnvironment:
            var world := child as WorldEnvironment
            if world.environment != null:
                # Dark industrial base with enough navy lift that the warehouse
                # reads as a site at night rather than a model floating in black.
                world.environment.background_color = Color(0.009, 0.021, 0.032)
                world.environment.ambient_light_color = Color(0.18, 0.27, 0.34)
                world.environment.ambient_light_energy = 0.54
            return


func _apply_north_star_palette() -> void:
    if warehouse_view == null:
        return

    for child in warehouse_view.get_children():
        _retint_recursive(child)


func _retint_recursive(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        match str(mesh_instance.name):
            "Floor":
                _retint_mesh(mesh_instance, PREMIUM_FLOOR, 0.78, 0.015)
            "BackWall", "WallColumn", "StorageEndcap":
                _retint_mesh(mesh_instance, PREMIUM_NAVY, 0.62, 0.08)
            "CentralAisle":
                _retint_mesh(mesh_instance, Color(0.085, 0.115, 0.130), 0.74, 0.01)
            "InboundPad", "InboundZone":
                _retint_mesh(mesh_instance, INBOUND_TINT, 0.66, 0.02)
            "PackingPad", "PackZone", "PackHeroBase":
                _retint_mesh(mesh_instance, PACK_TINT, 0.64, 0.01)
            "OutboundPad", "OutboundZone":
                _retint_mesh(mesh_instance, OUTBOUND_TINT, 0.66, 0.02)
            "TruckApron", "FloorPlate":
                _retint_mesh(mesh_instance, APRON_TINT, 0.82, 0.01)
            "PackTable", "PackSideTable", "PackTable2", "RackShelf", "QuickShelf", "DenseShelf", "OpsDeck", "ForkL", "ForkR", "AGVBase":
                _retint_mesh(mesh_instance, BRUSHED_STEEL, 0.36, 0.34)
            "RackPost", "QuickPost", "DensePost", "DockPost", "DockPostL", "DockPostR", "OpsSupport", "PackGantryPost", "PackGantryTop", "ForkRoof":
                _retint_mesh(mesh_instance, PREMIUM_STEEL, 0.48, 0.18)
            "Conveyor", "AGVTop", "CellOpening":
                _retint_mesh(mesh_instance, DARK_EQUIPMENT, 0.56, 0.12)
            "Roller":
                _retint_mesh(mesh_instance, Color(0.31, 0.38, 0.41), 0.32, 0.42)
            "RackBeam", "QuickBeam", "DenseBeam", "PackRail2", "CellAccent":
                _retint_mesh(mesh_instance, SAFETY_AMBER, 0.43, 0.08)

    for child in node.get_children():
        _retint_recursive(child)


func _retint_mesh(mesh_instance: MeshInstance3D, color: Color, roughness: float, metallic: float) -> void:
    var material := mesh_instance.material_override as StandardMaterial3D
    if material == null:
        return
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic


func _limit_dynamic_shadow_cost() -> void:
    if warehouse_view == null:
        return

    # The North Star depends on contrast and local practicals, not on many mobile
    # shadow maps. Keep the directional key shadow, but make all point lights
    # shadow-free so visual density can scale without consuming the phone budget.
    for child in warehouse_view.get_children():
        _limit_light_recursive(child)


func _limit_light_recursive(node: Node) -> void:
    if node is OmniLight3D:
        var omni := node as OmniLight3D
        omni.shadow_enabled = false
        omni.light_energy = minf(omni.light_energy, 2.8)
    elif node is DirectionalLight3D:
        var directional := node as DirectionalLight3D
        directional.shadow_enabled = true
        directional.light_energy = 0.78
        directional.light_color = Color(0.72, 0.84, 0.95)

    for child in node.get_children():
        _limit_light_recursive(child)


func _deemphasize_truck() -> void:
    if warehouse_view == null:
        return

    var body := warehouse_view.get_node_or_null("TruckBody") as MeshInstance3D
    if body != null:
        var body_mat := body.material_override as StandardMaterial3D
        if body_mat != null:
            body_mat.albedo_color = Color(0.30, 0.37, 0.42)
            body_mat.roughness = 0.66
            body_mat.metallic = 0.04

    var cab := warehouse_view.get_node_or_null("TruckCab") as MeshInstance3D
    if cab != null:
        var cab_mat := cab.material_override as StandardMaterial3D
        if cab_mat != null:
            cab_mat.albedo_color = Color(0.045, 0.115, 0.175)
            cab_mat.roughness = 0.56
            cab_mat.metallic = 0.08


func _site_box(parent: Node, name: String, size: Vector3, position: Vector3, color: Color, roughness: float, metallic: float) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    instance.material_override = material
    parent.add_child(instance)
    return instance


func _site_emissive_box(parent: Node, name: String, size: Vector3, position: Vector3, color: Color, energy: float) -> MeshInstance3D:
    var instance := _site_box(parent, name, size, position, color, 0.40, 0.02)
    var material := instance.material_override as StandardMaterial3D
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    return instance
