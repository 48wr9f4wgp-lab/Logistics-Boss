extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
    call_deferred("_run")

func expect(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func settle() -> void:
    for _i in 8: await process_frame

func _run() -> void:
    get_root().size = Vector2i(390,844)
    var app := load("res://scenes/main.tscn").instantiate() as Node
    get_root().add_child(app)
    app.set_process(false)
    var sim: FlotraV2Sim = app.get("sim")
    sim.set_time_scale(0.0)
    var view: WarehouseView
    for child in app.get_children():
        if child is WarehouseView: view = child
    await settle()
    var composition: WarehouseVisualCompositionFix
    var zones: WarehouseZoneInteractionView
    for child in view.get_children():
        if child is WarehouseVisualCompositionFix: composition = child
        if child is WarehouseZoneInteractionView: zones = child
    var batch := composition.get_node("ArchitecturalFinish/StaticArchitecturalBatch") as MeshInstance3D
    expect(batch.mesh.get_surface_count() == 1, "Static finish remains a single batched draw surface")
    expect((batch.material_override as StandardMaterial3D).vertex_color_use_as_albedo, "Batched finish preserves its material family")
    var light_count := 0
    var shadow_count := 0
    for light in view.find_children("*", "Light3D", true, false):
        if light.light_energy > 0.0:
            light_count += 1
            if light.shadow_enabled: shadow_count += 1
    expect(light_count == 5 and shadow_count == 1, "One key shadow and four local work lights bound mobile cost")
    sim.money = 250000
    expect(bool(sim.purchase_rank1_project(&"rack_wing").get("ok", false)), "Real rack-wing purchase succeeds")
    await settle()
    expect(bool(sim.purchase_rank1_project(&"second_packing_bench").get("ok", false)), "Real secondary packing purchase succeeds")
    await settle()
    for mesh in view.find_children("*", "MeshInstance3D", true, false):
        var role := String(mesh.get_meta("finish_role", ""))
        var material := mesh.material_override as StandardMaterial3D
        if role in ["RackPost","RackWingPost"]: expect(material.albedo_color == WarehouseVisualCompositionFix.PREMIUM_STEEL, "Real purchases retain every repeated navy rack post")
        if role in ["RackBeam","RackWingBeam","SecondPackRail"]: expect(material.albedo_color == WarehouseVisualCompositionFix.SAFETY_AMBER, "Real purchases retain every repeated amber beam/rail")
        if role == "SecondPackBench": expect(material.albedo_color == WarehouseVisualCompositionFix.BRUSHED_STEEL, "Secondary packing bench follows the steel family")
    sim.shipped = 20
    expect(bool(sim.purchase_warehouse_expansion().get("ok",false)), "Real warehouse expansion succeeds")
    await settle()
    expect(bool(sim.purchase_facility(&"fast_pick_rack").get("ok",false)), "Real rank2 rack purchase succeeds")
    await settle()
    for mesh in view.find_children("*", "MeshInstance3D", true, false):
        var role := String(mesh.get_meta("finish_role", ""))
        if role in ["QuickBeam","DenseBeam"]:
            expect((mesh.material_override as StandardMaterial3D).albedo_color == WarehouseVisualCompositionFix.SAFETY_AMBER, "Rank2 construction receives the same beam finish")
    sim.inbound_queue = 12
    sim.rack_stock = 20
    sim.packed_queue = 10
    view._sync_box_counts()
    await settle()
    expect(view._carton_meshes.size() <= 9, "Carton finish cache stays bounded")
    var carton := view._inbound_boxes.get_child(0) as MeshInstance3D
    var repeated := view._inbound_boxes.get_child(3) as MeshInstance3D
    expect(carton.mesh == repeated.mesh and carton.material_override == repeated.material_override, "Repeated carton tones share mesh/material")
    expect(carton.mesh.get_surface_count() == 1, "Tape and label do not add carton surfaces")
    var arrays := carton.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    for index in range(0, vertices.size(), 3):
        var face := (vertices[index+1]-vertices[index]).cross(vertices[index+2]-vertices[index])
        expect(face.dot(normals[index]) < 0.0, "Carton faces must use Godot exterior clockwise winding")
    for root in [view._inbound_boxes,view._rack_boxes,view._packed_boxes]:
        for mesh in root.get_children(): expect(mesh.get_child_count() == 0, "Carton detail adds no scene nodes")
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    sim.open_orders = 0
    view._sync_box_counts()
    await settle()
    expect(view._inbound_boxes.get_child_count() == 0 and view._rack_boxes.get_child_count() == 0 and view._packed_boxes.get_child_count() == 0, "Empty inventory remains physically empty")
    sim.inbound_queue = 8
    sim.rack_stock = 12
    sim.packing_queue = 7
    sim.packed_queue = 4
    sim.open_orders = 9
    for size in [Vector2i(375,667),Vector2i(390,844),Vector2i(430,932)]:
        get_root().size = size
        zones._refresh_zone_labels()
        await settle()
        var keys := zones.zone_keys()
        for i in keys.size():
            var rect := zones.zone_label_visual_screen_rect(keys[i])
            expect(rect.has_area(), "Busy caption remains visible on %s" % str(size))
            for j in range(i+1,keys.size()):
                expect(not rect.intersects(zones.zone_label_visual_screen_rect(keys[j])), "Busy zone captions must not overlap: %s / %s at %s" % [keys[i],keys[j],str(size)])
    app.queue_free()
    await process_frame
    print("WAREHOUSE_COHESION_SMOKE checks=%d failures=%d" % [checks,failures])
    quit(0 if failures == 0 else 1)
