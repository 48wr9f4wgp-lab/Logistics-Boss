extends "res://prototype/jobs_view.gd"
## Visual equipment changes mirror campaign capacities; never change the model.
func refresh() -> void:
    super.refresh()
    if sim == null or not is_node_ready(): return
    if _slots.has("shelf"):
        var shelf: Node3D = _slots.shelf
        var rack := shelf.get_node_or_null("RackEquipment") as Node3D
        if rack != null:
            var inserts := rack.get_node_or_null("CapacityInserts") as Node3D
            if inserts == null:
                inserts = Node3D.new()
                inserts.name = "CapacityInserts"
                rack.add_child(inserts)
                for y in [.59,1.25,1.78]:
                    _box(inserts,"ExtraShelf",Vector3(2.12,.055,1.12),Vector3(0,y,0),TEAL.darkened(.2))
            inserts.visible = sim.rack_capacity > 12
        var label := shelf.get_node_or_null("PlotLabel") as Label3D
        if label != null: label.text = "棚 %d個" % sim.rack_capacity
    if _slots.has("packing"):
        var bench: Node3D = _slots.packing
        var tool := bench.get_node_or_null("PackingUpgrade") as Node3D
        if tool == null:
            tool = Node3D.new()
            tool.name = "PackingUpgrade"
            bench.add_child(tool)
            _box(tool,"TapeDispenser",Vector3(.28,.18,.3),Vector3(.4,1.03,0),TEAL)
        tool.visible = sim.pack_seconds < 3.0
        var label := bench.get_node_or_null("PlotLabel") as Label3D
        if label != null: label.text = "梱包 %.0f秒" % sim.pack_seconds
