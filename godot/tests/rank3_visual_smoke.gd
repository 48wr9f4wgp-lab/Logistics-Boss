extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const Rank3ReceivingAnnexViewScript = preload("res://view/rank3_receiving_annex_view.gd")
const Rank3RoutingHubViewScript = preload("res://view/rank3_routing_hub_view.gd")


func _init() -> void:
    var holder := Node3D.new()
    get_root().add_child(holder)

    var sim = _rank3_sim()
    var warehouse: WarehouseView = WarehouseViewScript.new()
    warehouse.bind_sim(sim)
    holder.add_child(warehouse)

    var rank3_view: Rank3ReceivingAnnexView = Rank3ReceivingAnnexViewScript.new()
    warehouse.add_child(rank3_view)
    rank3_view.bind(warehouse, sim)

    var routing_view: Rank3RoutingHubView = Rank3RoutingHubViewScript.new()
    warehouse.add_child(routing_view)
    routing_view.bind(warehouse, sim)
    await process_frame
    await process_frame

    var rank_mark := rank3_view.find_child("Rank3_FulfillmentCenterMark", true, false)
    assert(rank_mark is Node3D, "Rank 3 promotion must create visible Fulfillment Center evolution")
    assert(rank_mark.get_child_count() >= 15, "Rank 3 promotion must add facility-scale geometry, not only a small badge")
    assert(rank3_view.find_child("Rank3_ReceivingAnnex", true, false) == null, "unowned Receiving Annex must not render as if purchased")

    # Promotion alone must be visibly larger than the Rank 2 management spine:
    # wider site shoulders plus a taller rear control crown make Rank 3 readable
    # before the optional Annex or carrier program are purchased.
    var bridge := rank_mark.find_child("Rank3ControlBridge", true, false) as MeshInstance3D
    assert(bridge != null, "Rank 3 promotion must add a rear fulfillment control bridge")
    var bridge_mesh := bridge.mesh as BoxMesh
    assert(bridge_mesh != null and bridge_mesh.size.x >= 7.0, "Rank 3 control bridge must be wider than the Rank 2 operations deck")
    assert(bridge.position.y >= 3.0, "Rank 3 control bridge must create a taller facility crown")

    var tower := rank_mark.find_child("Rank3ScaleTowerL", true, false) as MeshInstance3D
    assert(tower != null, "Rank 3 promotion must add tall scale markers")
    var tower_mesh := tower.mesh as BoxMesh
    assert(tower_mesh != null and tower_mesh.size.y >= 3.4, "Rank 3 scale tower must create a substantial vertical silhouette")

    var shoulder := rank_mark.find_child("Rank3ServiceShoulderL", true, false) as MeshInstance3D
    assert(shoulder != null, "Rank 3 promotion must widen the visible site footprint")
    assert(absf(shoulder.position.x) > 8.0, "Rank 3 site shoulder must extend beyond the base warehouse footprint")

    var routing_hub := routing_view.find_child("Rank3_RoutingHub", true, false)
    assert(routing_hub is Node3D, "Rank 3 must create a visible routing hub")
    assert(routing_view.find_child("RoutingHub_Balanced", true, false) is Node3D, "Balanced Parcel must have visible 3D routing state")

    assert(bool(sim.set_routing_mode("express").get("ok", false)), "visual smoke must switch to Express Dispatch")
    await process_frame
    await process_frame
    assert(routing_view.find_child("RoutingHub_Express", true, false) is Node3D, "Express Dispatch must visibly change the routing hub")

    assert(bool(sim.set_routing_mode("consolidated").get("ok", false)), "visual smoke must switch to Consolidated Linehaul")
    await process_frame
    await process_frame
    var consolidated := routing_view.find_child("RoutingHub_Consolidated", true, false)
    assert(consolidated is Node3D, "Consolidated Linehaul must visibly change the routing hub")
    assert(consolidated.get_child_count() >= 8, "Consolidated routing state must show substantial batch-staging geometry")

    assert(bool(sim.purchase_receiving_annex().get("ok", false)), "visual smoke must purchase Receiving Annex")
    await process_frame
    await process_frame

    var annex := rank3_view.find_child("Rank3_ReceivingAnnex", true, false)
    assert(annex is Node3D, "purchased Receiving Annex must create visible 3D expansion")
    assert(annex.get_child_count() >= 10, "Receiving Annex visible expansion must contain substantial geometry")

    holder.queue_free()
    await process_frame
    print("Godot Rank 3 visual smoke passed")
    quit(0)


func _rank3_sim():
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 6
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 100000
    data["receiving_annex_unlocked"] = false
    data["active_routing_mode"] = "balanced"
    data["staffing_plan"] = "balanced"
    data["rack_capacity"] = 12
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic Rank 3 visual state must load")
    return sim
