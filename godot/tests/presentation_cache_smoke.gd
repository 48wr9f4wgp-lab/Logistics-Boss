extends SceneTree

const Sim = preload("res://domain/flotra_v2_sim.gd")
const View = preload("res://view/warehouse_view.gd")
const Queues = preload("res://view/queue_pressure_view.gd")
var _failures := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var sim := Sim.new()
    var view := View.new()
    get_root().add_child(view)
    view.bind_sim(sim)
    view.set_process(false)
    var queues := Queues.new()
    view.add_child(queues)
    queues.bind(view, sim)
    queues.set_process(false)
    _set_counts(sim, 99)
    view._sync_box_counts()
    queues._sync_queues()
    await process_frame
    var roots: Array[Node] = [view._inbound_boxes, view._rack_boxes, view._packed_boxes, queues._packing_root, queues._orders_root]
    var limits := [12, 20, 10, 24, 20]
    var identities: Array[int] = []
    for i in roots.size():
        _expect(roots[i].get_child_count() == limits[i], "Each physical queue remains capped")
        identities.append(roots[i].get_child(0).get_instance_id())
    _set_counts(sim, 100)
    view._sync_box_counts()
    queues._sync_queues()
    await process_frame
    for i in roots.size():
        _expect(roots[i].get_child(0).get_instance_id() == identities[i], "Above-cap count changes preserve mesh identity")
    _set_counts(sim, 1)
    view._sync_box_counts()
    queues._sync_queues()
    await process_frame
    for i in roots.size():
        _expect(roots[i].get_child_count() == (1 if i < 3 else 2), "Dropping below cap refreshes exact visible quantity")
    _set_counts(sim, 0)
    view._sync_box_counts()
    queues._sync_queues()
    await process_frame
    for root in roots:
        _expect(root.get_child_count() == 0, "Cleared queues remove all displayed cargo")
    view.queue_free()
    await process_frame
    print("Presentation cache checks complete; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)

func _set_counts(sim: WarehouseSim, count: int) -> void:
    sim.inbound_queue = count
    sim.rack_stock = count
    sim.packed_queue = count
    sim.packing_queue = count
    sim.open_orders = count

func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)
