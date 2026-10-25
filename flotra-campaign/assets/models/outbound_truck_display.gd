extends Node3D
## Stationary presentation at the outbound boundary. Not a simulated vehicle.
const Body = preload("res://assets/models/truck_body_asset.gd")

static func create() -> Node3D:
    var body := Body.instantiate_body()
    if body == null:
        return null
    var display := Node3D.new()
    display.name = "OutboundTruckDisplay"
    display.rotation.y = PI
    display.scale = Vector3.ONE * .9
    display.add_child(body)
    # Four low-poly wheels share one mesh, material and draw submission.
    var tyre := CylinderMesh.new()
    tyre.top_radius = .31
    tyre.bottom_radius = .31
    tyre.height = .20
    tyre.radial_segments = 12
    tyre.rings = 1
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("17252e")
    material.roughness = .95
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = tyre
    instances.instance_count = 4
    var index := 0
    for x in [-1.45, .7]:
        for z in [-.78, .78]:
            instances.set_instance_transform(index, Transform3D(Basis(Vector3.RIGHT, PI * .5), Vector3(x, .42, z)))
            index += 1
    var wheels := MultiMeshInstance3D.new()
    wheels.name = "TruckWheels"
    wheels.multimesh = instances
    wheels.material_override = material
    display.add_child(wheels)
    return display
