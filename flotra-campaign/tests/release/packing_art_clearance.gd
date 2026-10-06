extends SceneTree
## Renderer-only regression: synthetic stage records exercise the real parcel
## placement code without adding anything to the simulation or changing saves.
const View = preload("res://prototype/growth_view.gd")
const Sim = preload("res://prototype/growth_sim.gd")
const EPSILON := 0.00001
var checks := 0
var failures: Array[String] = []
var tested_parts := 0
var tested_faces := 0
func _init(): run.call_deferred()
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)

func triangle_enters_box(a: Vector3, b: Vector3, c: Vector3, bounds: AABB) -> bool:
    # Shrink the box by a small world-space tolerance: touching a supporting
    # surface is allowed, but a face entering the carton/tape interior is not.
    var interior := bounds.grow(-EPSILON)
    var center := interior.get_center()
    var half := interior.size * .5
    var vertices: Array[Vector3] = [a-center,b-center,c-center]
    for axis in 3:
        var low := minf(vertices[0][axis],minf(vertices[1][axis],vertices[2][axis]))
        var high := maxf(vertices[0][axis],maxf(vertices[1][axis],vertices[2][axis]))
        if low >= half[axis] or high <= -half[axis]: return false
    var edges: Array[Vector3] = [vertices[1]-vertices[0],vertices[2]-vertices[1],vertices[0]-vertices[2]]
    var normal := edges[0].cross(edges[1])
    if normal.length_squared() < 1e-18: return false
    var axes: Array[Vector3] = [normal]
    for edge in edges:
        for basis_axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:
            var separating: Vector3 = edge.cross(basis_axis)
            if separating.length_squared() > 1e-18: axes.append(separating)
    # Complete triangle/AABB separating-axis test: 3 box normals above,
    # 1 triangle normal, and 9 edge/box-axis products. Triangle bounds alone
    # would incorrectly reject some nonintersecting diagonal bevel faces.
    for axis in axes:
        var radius := half.x*absf(axis.x)+half.y*absf(axis.y)+half.z*absf(axis.z)
        var p0 := vertices[0].dot(axis)
        var p1 := vertices[1].dot(axis)
        var p2 := vertices[2].dot(axis)
        if minf(p0,minf(p1,p2)) >= radius or maxf(p0,maxf(p1,p2)) <= -radius: return false
    return true

func mesh_contains_point(mesh: Mesh, transform: Transform3D, point: Vector3) -> bool:
    # Signed solid-angle winding detects full containment even when no surface
    # cuts the carton. All authored closed parts share winding, so overlapping
    # machine parts add rather than cancel as an odd/even ray count would.
    var faces := mesh.get_faces()
    var solid_angle := 0.0
    for index in range(0,faces.size(),3):
        var a: Vector3 = transform*faces[index]-point
        var b: Vector3 = transform*faces[index+1]-point
        var c: Vector3 = transform*faces[index+2]-point
        var denominator := a.length()*b.length()*c.length()+a.dot(b)*c.length()+b.dot(c)*a.length()+c.dot(a)*b.length()
        solid_angle += 2.0*atan2(a.dot(b.cross(c)),denominator)
    return absf(solid_angle) > TAU

func mesh_enters_box(mesh: Mesh, transform: Transform3D, bounds: AABB) -> bool:
    var faces := mesh.get_faces()
    for index in range(0,faces.size(),3):
        tested_faces += 1
        if triangle_enters_box(transform*faces[index],transform*faces[index+1],transform*faces[index+2],bounds): return true
    return mesh_contains_point(mesh,transform,bounds.get_center())

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    var sim = Sim.new()
    var before: Dictionary = sim.export_release_state()
    var view = View.new()
    root.add_child(view)
    view.bind_sim(sim)
    for frame in 3: await process_frame
    var packing: Node3D = view._slots.packing
    var items: Array = []
    var id := 0
    # Per-stage grouping gives each of these real renderer paths its own 12
    # positions: 3 columns, 2 depth positions, and 2 height rows.
    for stage in ["packing_queue","packing","packed"]:
        for slot in 12:
            items.append({"id":id,"stage":stage,"kind":"pick","job_kind":"pick","position":packing.position,"carried":false})
            id += 1
    view._refresh_cargo(items)
    check(view._cargo.size()==36,"All three real stage paths produce their 12 retained slots")
    var packing_from_world := packing.global_transform.affine_inverse()
    var installed: MeshInstance3D = packing.get_node("PackingEquipment/EquipmentArtwork")
    var artwork_transform := packing_from_world*installed.global_transform
    var first_carton := AABB()
    var first_tape := AABB()
    for index in items.size():
        var parcel: Node3D = view._cargo[str(index)]
        var slot := index % 12
        var expected := Vector3((slot%3-1)*.47,.74+(slot/6)*.36,(slot%6/3)*.44)
        var actual: Vector3 = packing_from_world*parcel.global_position
        check(actual.is_equal_approx(expected),"Real renderer retains existing parcel transform "+str(index))
        for name in ["Carton","Tape"]:
            var part: MeshInstance3D = parcel.get_node(name)
            var bounds: AABB = packing_from_world*part.global_transform*part.get_aabb()
            check(part.is_visible_in_tree(),"Actual parcel part remains visible "+name+str(index))
            if index==0:
                if name=="Carton": first_carton=bounds
                else: first_tape=bounds
            for kind in ["packing_manual","packing_auto"]:
                tested_parts += 1
                check(not mesh_enters_box(view._art_mesh(kind),artwork_transform,bounds),"No "+kind+" face penetrates "+str(items[index].stage)+" slot "+str(slot)+" "+name)
    check(is_equal_approx(first_carton.position.y,.59375),"Real .39 carton retains its .59375 lower bound")
    check(is_equal_approx(first_tape.end.y,.8942),"Real parcel tape is tested through its .8942 upper bound")
    # Negative controls ensure the test catches the original regressions rather
    # than merely asserting a broad equipment envelope or visible counts.
    var old_deck := BoxMesh.new()
    old_deck.size=Vector3(1.56,.12,.94)
    check(mesh_enters_box(old_deck,Transform3D(Basis.IDENTITY,Vector3(0,.60,0)),first_carton),"Detector rejects original penetrating manual deck")
    var old_head := BoxMesh.new()
    old_head.size=Vector3(.25,.12,.92)
    check(mesh_enters_box(old_head,Transform3D(Basis.IDENTITY,Vector3(.20,.89,0)),AABB(Vector3(-.195,.59375,-.156),Vector3(.39,.2925,.312))),"Detector rejects original wide sealing crossbar")
    var contact := BoxMesh.new()
    contact.size=Vector3(.8,.01,.8)
    check(not mesh_enters_box(contact,Transform3D(Basis.IDENTITY,Vector3(first_carton.get_center().x,first_carton.position.y-.005,first_carton.get_center().z)),first_carton),"Exact supporting contact is allowed")
    var tape_only := BoxMesh.new()
    tape_only.size=Vector3(.02,.004,.08)
    var tape_transform := Transform3D(Basis.IDENTITY,Vector3(first_tape.get_center().x,.891,first_tape.get_center().z))
    check(not mesh_enters_box(tape_only,tape_transform,first_carton),"Tape-only witness misses carton body")
    check(mesh_enters_box(tape_only,tape_transform,first_tape),"Detector catches a tape-only penetration")
    var enclosure := BoxMesh.new()
    enclosure.size=first_carton.size+Vector3.ONE*.20
    check(mesh_enters_box(enclosure,Transform3D(Basis.IDENTITY,first_carton.get_center()),first_carton),"Detector catches full solid containment without a face crossing")
    check(not triangle_enters_box(Vector3(.9,1.2,.5),Vector3(1.2,.9,.5),Vector3(1.2,1.2,.5),AABB(Vector3.ZERO,Vector3.ONE)),"SAT rejects a diagonal triangle whose bounds overlap but whose face misses")
    check(sim.export_release_state()==before,"Renderer clearance fixture never changes the actual simulation/save")
    view.queue_free()
    await process_frame
    print(JSON.stringify({"suite":"packing_art_clearance","checks":checks,"failures":failures,"stage_slots":36,"variant_part_pairs":tested_parts,"triangles_tested":tested_faces,"tolerance":EPSILON,"scope":"Actual retained stage-slot and tape bounds versus both packing-art variants; exact triangle/AABB interior contact plus solid containment, no domain edits"}))
    quit(0 if failures.is_empty() else 1)
