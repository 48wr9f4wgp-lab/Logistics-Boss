extends Node3D
class_name SelectedWorkRoutes

var view: WarehouseView
var zone: WarehouseZonePanel
var selected := ""
var lines: Array[MeshInstance3D] = []
var materials: Array[StandardMaterial3D] = []
var toggle: Button

func bind(next_view: WarehouseView, next_zone: WarehouseZonePanel, hud: MobileGameHud) -> void:
    view = next_view
    zone = next_zone
    zone.opened.connect(func(key: String): selected = key)
    # Fixed pool: at most 7 workers with 3 segments and two arrow-head legs each.
    for i in 35:
        var line := CapacityGrowthView.box(self,"Route%d" % i,Vector3(0.095,0.035,1),Vector3.ZERO,Color(0.30,0.85,0.97))
        line.visible = false
        lines.append(line)
        var material := line.material_override as StandardMaterial3D
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        # Inspection overlay only: keep the selected route readable above props.
        material.no_depth_test = true
        material.render_priority = 1
        materials.append(material)
    toggle = Button.new()
    toggle.text = "動線を隠す"
    toggle.anchor_top = 1.0
    toggle.anchor_bottom = 1.0
    toggle.offset_left = 12
    toggle.offset_right = 123
    toggle.offset_top = -148
    toggle.offset_bottom = -104
    toggle.pressed.connect(func(): selected = "")
    hud.add_child(toggle)
    var overview := Button.new()
    overview.text = "作業全体へ"
    overview.anchor_left = 1.0
    overview.anchor_right = 1.0
    overview.anchor_top = 1.0
    overview.anchor_bottom = 1.0
    overview.offset_left = -123
    overview.offset_right = -12
    overview.offset_top = -148
    overview.offset_bottom = -104
    overview.pressed.connect(func():
        if view.has_method("reset_work_overview"):
            view.call("reset_work_overview"))
    hud.add_child(overview)
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity._style_buttons(toggle)
    clarity._style_buttons(overview)
    zone.opened.connect(func(_key: String): overview.visible = false)
    zone.closed.connect(func(): overview.visible = not hud._sheet.visible)
    hud._sheet.visibility_changed.connect(func():
        overview.visible = not hud._sheet.visible
        if hud._sheet.visible: selected = "")

func _process(_delta: float) -> void:
    for line in lines:
        line.visible = false
    toggle.visible = not selected.is_empty() and not zone.is_open()
    if selected.is_empty() or view == null or view.sim == null:
        return
    var task := WarehouseSim.Task.STORE if selected in ["inbound", "storage"] else (WarehouseSim.Task.PICK if selected == "picking" else (WarehouseSim.Task.SHIP if selected == "shipping" else WarehouseSim.Task.IDLE))
    if task == WarehouseSim.Task.IDLE:
        return # PACKING is a machine, not a worker assignment.
    var cursor := 0
    for worker in view.sim.workers:
        if int(worker["task"]) != task or cursor + 5 > lines.size():
            continue
        var a: Vector3 = view.STATION_POSITIONS[worker["source"]]
        var b: Vector3 = view.STATION_POSITIONS[worker["target"]]
        var route := WorkRoutes.points(a,b)
        for i in route.size() - 1:
            _place_line(cursor,route[i],route[i+1]); cursor += 1
        var tip := route[-1]
        var direction := (tip-route[-2]).normalized()
        var side := direction.cross(Vector3.UP)
        _place_line(cursor,tip,tip-direction*0.40+side*0.20); cursor += 1
        _place_line(cursor,tip,tip-direction*0.40-side*0.20); cursor += 1

func _place_line(index: int, a: Vector3, b: Vector3) -> void:
    a.y = 0.18
    b.y = 0.18
    var length := a.distance_to(b)
    if length < 0.01:
        return
    var line := lines[index]
    line.visible = true
    line.position = (a+b)*0.5
    line.scale.z = length
    line.rotation.y = atan2((b-a).x,(b-a).z)
