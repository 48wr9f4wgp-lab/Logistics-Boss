extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualPass3Script = preload("res://view/visual_pass_3.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")
const MobileHudScript = preload("res://ui/game_hud_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)

    var sim = WarehouseSimScript.new()

    var view: WarehouseView = WarehouseViewScript.new()
    root.add_child(view)
    view.bind_sim(sim)

    var pass2: WarehouseVisualPass2 = WarehouseVisualPass2Script.new()
    view.add_child(pass2)
    pass2.bind_view(view)

    var hud: MobileGameHud = MobileHudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)

    var pass3: WarehouseVisualPass3 = WarehouseVisualPass3Script.new()
    view.add_child(pass3)
    pass3.bind(view, hud)

    var composition: WarehouseVisualCompositionFix = WarehouseVisualCompositionFixScript.new()
    view.add_child(composition)
    composition.bind(view)

    await process_frame
    await process_frame

    var roof_nodes := view.find_children("Roof*", "Node3D", true, false)
    assert(roof_nodes.is_empty(), "open-top warehouse must not generate roof trusses or roof lights")

    var utility_nodes := view.find_children("Utility*", "Node3D", true, false)
    assert(utility_nodes.is_empty(), "open-top warehouse must not generate overhead utility bars")

    var left_wall := view.get_node_or_null("LeftWall") as Node3D
    assert(left_wall != null, "readability smoke expects the base facility left wall")
    assert(not left_wall.visible, "foreground side wall must not block the portrait cutaway view")

    # Full runtime composition guard: visual passes must not overwrite the compact
    # shipped HUD after its responsive layout has been applied.
    assert(hud._bottleneck_panel != null, "mobile release HUD must build the bottleneck director")
    assert(hud._bottleneck_panel.offset_bottom <= 123.0, "3D visual passes must not expand the permanent command HUD")
    var money_panel := hud._money.get_parent().get_parent() as Control
    var top_row := money_panel.get_parent() as Control
    assert(top_row.offset_bottom <= 87.0, "live metric row must retain the compact release layout in full runtime composition")

    # The in-world status layer must mirror the authoritative domain bottleneck.
    assert(pass3._flow_signals.size() == 5, "warehouse must expose one operational signal for each bottleneck family")

    _set_stable(sim)
    sim.inbound_queue = 8
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "inbound") > _signal_energy(pass3, "rack"), "inbound congestion must highlight the inbound zone in 3D")

    _set_stable(sim)
    sim.rack_stock = sim.rack_capacity
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "rack") > _signal_energy(pass3, "packing"), "storage pressure must highlight the rack zone in 3D")

    _set_stable(sim)
    sim.packing_queue = 3
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "packing") > _signal_energy(pass3, "outbound"), "packing congestion must highlight the packing zone in 3D")

    _set_stable(sim)
    sim.packed_queue = 4
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "outbound") > _signal_energy(pass3, "orders"), "outbound backlog must highlight the shipping zone in 3D")

    _set_stable(sim)
    sim.open_orders = 6
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "orders") > _signal_energy(pass3, "inbound"), "open-order backlog must highlight the pick/order handoff in 3D")

    _set_stable(sim)
    pass3._sync_domain_bottleneck_signals()
    for key_variant in pass3._flow_signals.keys():
        var key := String(key_variant)
        assert(_signal_energy(pass3, key) <= WarehouseVisualPass3.SIGNAL_IDLE_ENERGY + 0.01, "stable operation must keep all in-world signals visually quiet")

    view._camera_distance = 25.0
    await process_frame
    var camera: Camera3D = root.get_viewport().get_camera_3d()
    assert(camera != null, "overview smoke requires an active camera")
    assert(camera.fov > 38.0, "max pinch distance must widen into a true warehouse overview")

    hud.queue_free()
    root.queue_free()
    await process_frame
    print("Godot warehouse visual readability smoke passed")
    quit(0)


func _set_stable(sim) -> void:
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    sim.open_orders = 0


func _signal_energy(pass3: WarehouseVisualPass3, key: String) -> float:
    var meshes: Array = pass3._flow_signals.get(key, [])
    assert(not meshes.is_empty(), "missing flow signal for %s" % key)
    var mesh := meshes[0] as MeshInstance3D
    assert(mesh != null, "flow signal must be a mesh for %s" % key)
    var material := mesh.material_override as StandardMaterial3D
    assert(material != null and material.emission_enabled, "flow signal must use emissive material for %s" % key)
    return material.emission_energy_multiplier
