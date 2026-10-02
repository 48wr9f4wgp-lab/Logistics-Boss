extends Node3D
class_name WarehouseArchitecturalFinish

# Static architectural context, batched into one vertex-colour mesh. No goods,
# lights, collision, or simulation state. This is infrastructure even when empty.
const WALL := Color(0.090, 0.145, 0.190)
const EDGE := Color(0.155, 0.220, 0.260)
const SHUTTER := Color(0.200, 0.270, 0.310)
const INK := Color(0.055, 0.095, 0.125)
const PAINT := Color(0.67, 0.72, 0.70)
const AMBER := Color(0.82, 0.48, 0.16)
var _surface: SurfaceTool

func _ready() -> void:
    _surface = SurfaceTool.new()
    _surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Upper fascia, kick plate and repeated upright seams give the shell scale.
    _box(Vector3(15.75,0.18,0.30),Vector3(0,4.12,-4.87),EDGE)
    _box(Vector3(15.75,0.42,0.12),Vector3(0,0.20,-4.70),INK)
    for x in [-6.9,-4.55,-2.2,0.15,2.5,4.85,7.0]:
        _box(Vector3(0.12,3.90,0.10),Vector3(x,2.0,-4.56),EDGE)
        _box(Vector3(0.24,0.62,0.18),Vector3(x,0.30,-4.50),AMBER)
    # Dock doors are visibly part of the wall rather than empty rectangles.
    for x in [-5.25,5.20]:
        _box(Vector3(1.93,2.40,0.06),Vector3(x,1.24,-4.61),SHUTTER)
        for y in [0.35,0.70,1.05,1.40,1.75,2.10]:
            _box(Vector3(1.93,0.035,0.065),Vector3(x,y,-4.56),INK)
        _box(Vector3(1.12,0.12,0.04),Vector3(x,1.45,-4.50),EDGE)
        for dx in [-0.44,0.44]:
            _box(Vector3(0.50,0.29,0.035),Vector3(x+dx,1.77,-4.50),INK)
    # Low cutaway curb and painted corners establish a deliberate diorama edge.
    _box(Vector3(0.16,0.22,10.7),Vector3(-7.75,-0.005,0.48),WALL)
    _box(Vector3(15.65,0.10,0.14),Vector3(0,-0.04,6.54),EDGE)
    for x in [-6.72,6.72]:
        for z in [-3.72,4.67]:
            _box(Vector3(0.80,0.015,0.07),Vector3(x,0.012,z),PAINT)
            _box(Vector3(0.07,0.015,0.72),Vector3(x+(0.36 if x>0 else -0.36),0.012,z+0.32),PAINT)
    # Quiet marked walkway rather than extra animated/non-authoritative routes.
    for z in [-2.8,-1.6,-0.4,0.8]:
        _box(Vector3(0.10,0.015,0.45),Vector3(0.47,0.048,z),PAINT)
    var mesh := MeshInstance3D.new()
    mesh.name = "StaticArchitecturalBatch"
    mesh.mesh = _surface.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.78
    mesh.material_override = material
    add_child(mesh)
    _surface = null

func _box(size: Vector3, center: Vector3, color: Color) -> void:
    var box := BoxMesh.new()
    box.size = size
    var arrays := box.get_mesh_arrays()
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for index in indices:
        _surface.set_color(color)
        _surface.set_normal(normals[index])
        _surface.add_vertex(vertices[index] + center)
