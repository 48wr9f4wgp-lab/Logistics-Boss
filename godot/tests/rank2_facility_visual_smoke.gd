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
    for kind in CASES:
        await _assert_facility_visible(kind, String(CASES[kind]))

    print("Godot Rank 2 facility visual smoke passed")
    quit(0)


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

    var found := facility_view.find_child(expected_name, "Node3D", true, false)
    assert(found != null, "%s must create a visible 3D facility structure" % String(kind))
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
