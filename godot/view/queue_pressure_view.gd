extends Node3D
class_name WarehouseQueuePressureView

const PACKING_VISUAL_CAP := 12
const ORDER_VISUAL_CAP := 10

const CARTON := Color(0.78, 0.53, 0.26)
const CARTON_TAPE := Color(0.88, 0.76, 0.52)
const TOTE := Color(0.075, 0.24, 0.31)
const TOTE_EDGE := Color(0.18, 0.74, 0.92)

var warehouse_view: WarehouseView
var sim: WarehouseSim

var _packing_root: Node3D
var _orders_root: Node3D
var _last_packing_queue := -1
var _last_open_orders := -1


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    call_deferred("_ensure_roots")
    call_deferred("_sync_queues")


func _ready() -> void:
    _ensure_roots()


func _process(_delta: float) -> void:
    _sync_queues()


func _ensure_roots() -> void:
    if _packing_root == null:
        _packing_root = Node3D.new()
        _packing_root.name = "PackingBacklogVisual"
        add_child(_packing_root)
    if _orders_root == null:
        _orders_root = Node3D.new()
        _orders_root.name = "OrderBacklogVisual"
        add_child(_orders_root)


func _sync_queues() -> void:
    if sim == null:
        return
    _ensure_roots()

    if _last_packing_queue != sim.packing_queue:
        _last_packing_queue = sim.packing_queue
        _rebuild_packing_backlog(mini(maxi(sim.packing_queue, 0), PACKING_VISUAL_CAP))

    if _last_open_orders != sim.open_orders:
        _last_open_orders = sim.open_orders
        _rebuild_order_backlog(mini(maxi(sim.open_orders, 0), ORDER_VISUAL_CAP))


func visible_backlog_counts() -> Dictionary:
    return {
        "packing": _packing_root.get_child_count() / 2 if _packing_root != null else 0,
        "orders": _orders_root.get_child_count() / 2 if _orders_root != null else 0,
    }


func _rebuild_packing_backlog(count: int) -> void:
    _clear_root(_packing_root)
    for i in count:
        var column := i % 3
        var row := (i / 3) % 4
        var stack := i / 12
        var position := Vector3(
            0.88 + float(column) * 0.42,
            0.25 + float(stack) * 0.28,
            0.98 - float(row) * 0.38
        )
        _box_into(_packing_root, "PackingBacklogParcel", Vector3(0.34, 0.26, 0.32), position, CARTON, 0.62)
        _box_into(
            _packing_root,
            "PackingBacklogTape",
            Vector3(0.075, 0.272, 0.334),
            position + Vector3(0.0, 0.008, 0.0),
            CARTON_TAPE,
            0.72
        )


func _rebuild_order_backlog(count: int) -> void:
    _clear_root(_orders_root)
    for i in count:
        var column := i % 2
        var row := (i / 2) % 5
        var position := Vector3(
            -0.62 + float(column) * 0.48,
            0.18,
            1.48 - float(row) * 0.40
        )
        _box_into(_orders_root, "OrderBacklogTote", Vector3(0.40, 0.18, 0.32), position, TOTE, 0.48)
        _box_into(
            _orders_root,
            "OrderBacklogToteEdge",
            Vector3(0.42, 0.045, 0.34),
            position + Vector3(0.0, 0.105, 0.0),
            TOTE_EDGE,
            0.34
        )


func _clear_root(root: Node3D) -> void:
    if root == null:
        return
    for child in root.get_children():
        root.remove_child(child)
        child.queue_free()


func _box_into(
    parent: Node,
    name: String,
    size: Vector3,
    position: Vector3,
    color: Color,
    roughness: float
) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.02
    instance.material_override = material
    parent.add_child(instance)
    return instance
