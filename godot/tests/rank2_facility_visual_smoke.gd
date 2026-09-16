extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const Rank2FacilityViewScript = preload("res://view/rank2_facility_view.gd")

const CASES := {
    &"double_dock": "Rank2Facility_DoubleDock",
    &"buffer_yard": "Rank2Facility_BufferYard",
    &"fast_pick_rack": "Rank2Facility_FastPickRack",
    &"high_density_rack": "Rank2Facility_HighDensityRack",
    &"parallel_pack": "Rank2Facility_ParallelPack",
    &"fast_pack_cell": "Rank2Facility_FastPackCell",
}


func _init() -> void:
    await _assert_rank2_promotion_changes_silhouette()

    for kind in CASES:
        await _assert_facility_visible(kind, String(CASES[kind]))

    print("Godot Rank 2 facility visual smoke passed")
    quit(0)


func _assert_rank2_promotion_changes_silhouette() -> void:
    var holder := Node3D.new()
    get_root().add_child(holder)

    var sim: WarehouseSim = WarehouseSimScript.new()
    var warehouse: WarehouseView = WarehouseViewScript.new()
    warehouse.bind_sim(sim)
    holder.add_child(warehouse)

    var facility_view: Rank2FacilityView = Rank2FacilityViewScript.new()
    warehouse.add_child(facility_view)
    facility_view.bind(warehouse, sim)

    await process_frame
    await process_frame
    assert(facility_view.find_child("Rank2_OperationsSpine", true, false) == null, "Rank 1 must not show Rank 2 management infrastructure")

    # Promotion itself must be visible before any optional zone purchase. This is
    # the permanent visual proof that the warehouse has become a larger operation.
    sim.facility_rank = 2
    await process_frame
    await process_frame

    var spine := facility_view.find_child("Rank2_OperationsSpine", true, false) as Node3D
    assert(spine != null, "Rank 2 promotion must immediately add a permanent operations spine")
    assert(spine.get_child_count() >= 10, "Rank 2 operations spine must contain enough geometry to change the facility silhouette")

    var deck := spine.find_child("OpsDeck", true, false) as MeshInstance3D
    assert(deck != null, "Rank 2 operations spine must include a visible management deck")
    var deck_mesh := deck.mesh as BoxMesh
    assert(deck_mesh != null and deck_mesh.size.x >= 4.8, "Rank 2 management deck must be broad enough to read at phone scale")
    assert(deck.position.y >= 2.0, "Rank 2 management deck must create a real vertical silhouette change")

    sim.facility_rank = 1
    await process_frame
    await process_frame
    assert(facility_view.find_child("Rank2_OperationsSpine", true, false) == null, "Rank 2 infrastructure must disappear when the synthetic test state returns to Rank 1")

    holder.queue_free()
    await process_frame


func _assert_facility_visible(kind: StringName, expected_name: String) -> void:
    var holder := Node3D.new()
    get_root().add_child(holder)

    var sim := _rank2_sim()
    assert(bool(sim.purchase_facility(kind).get("ok", false)), "%s must purchase for visual smoke" % String(kind))

    var warehouse: WarehouseView = WarehouseViewScript.new()
    warehouse.bind_sim(sim)
    holder.add_child(warehouse)

    var facility_view: Rank2FacilityView = Rank2FacilityViewScript.new()
    warehouse.add_child(facility_view)
    facility_view.bind(warehouse, sim)

    await process_frame
    await process_frame

    var spine := facility_view.find_child("Rank2_OperationsSpine", true, false)
    assert(spine is Node3D, "Rank 2 permanent operations spine must coexist with optional facility purchases")

    var found := facility_view.find_child(expected_name, true, false)
    assert(found is Node3D, "%s must create a visible 3D facility structure" % String(kind))
    assert(found.get_child_count() > 0, "%s visible structure must contain geometry" % String(kind))

    holder.queue_free()
    await process_frame


func _rank2_sim() -> WarehouseSim:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var data := sim.save_data()
    data["facility_rank"] = 2
    data["logistics_rating"] = 8
    data["worker_count"] = 5
    data["money"] = 200000
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "synthetic Rank 2 visual state must load")
    return sim
