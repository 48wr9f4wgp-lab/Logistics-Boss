extends Node
## Disposable diagnostic scene only. Production scripts remain byte-identical.
## Both variants share a paused domain and frozen decorative process clock.
const Main = preload("res://prototype/growth_main.gd")
const Store = preload("res://prototype/release_save.gd")
const MARGIN := 4.0
var app
var callback: JavaScriptObject
var original: MultiMesh
var compacted: MultiMesh
var original_domain := ""
var anchor: Dictionary = {}
var view_name := "normal"
var variant := "A"
var ready_for_commands := false
var retained: Array[int] = []
var failures: Array[String] = []
var sequence := 0

func fail(message: String) -> void:
    failures.append(message)
    push_error(message)

func digest(value: Variant) -> String:
    return hash_bytes(var_to_bytes(value))

func hash_bytes(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    if not bytes.is_empty(): context.update(bytes)
    return context.finish().hex_encode()

func batch_digest(batch: MultiMeshInstance3D) -> String:
    var buffer: Variant = batch.multimesh.buffer if OS.has_feature("web") else app.world._box_batch_states[app.world._box_batches.find(batch)]
    return digest([buffer, batch.multimesh.instance_count,
        batch.multimesh.visible_instance_count, batch.transform, batch.cast_shadow,
        batch.visible, batch.material_override.get_instance_id(), batch.multimesh.mesh.get_instance_id()])

func invariant_state() -> Dictionary:
    var camera: Camera3D = app.world.camera
    var ground: MultiMeshInstance3D = app.world._box_batches[0]
    var material: StandardMaterial3D = ground.material_override
    var lights: Array = []
    for child in app.world.get_children():
        if child is DirectionalLight3D:
            lights.append([child.transform,child.light_color,child.light_energy,
                child.shadow_enabled,child.directional_shadow_mode,child.shadow_bias])
        elif child is WorldEnvironment:
            lights.append([child.environment.get_instance_id(),child.environment.ambient_light_color,
                child.environment.ambient_light_energy,child.environment.background_mode])
    return {"domain":digest(app.sim.export_release_state()),
        "camera":digest([camera.transform,camera.size,camera.fov,camera.projection,
            camera.keep_aspect,camera.near,camera.far,app.world.camera_metrics()]),
        "warehouse":batch_digest(app.world._box_batches[1]),
        "emissive":batch_digest(app.world._box_batches[2]),
        "quality":digest([app.viewport.size,app.viewport.msaa_3d,app.viewport.screen_space_aa,
            get_tree().root.size,get_tree().root.content_scale_size,
            get_tree().root.content_scale_mode,ProjectSettings.get_setting("rendering/renderer/rendering_method"),lights]),
        "groundMaterial":digest([material.get_instance_id(),material.albedo_color,
            material.roughness,material.metallic_specular,material.vertex_color_use_as_albedo,
            material.emission_enabled,ground.cast_shadow,ground.transform,ground.visible,
            ground.multimesh.mesh.get_instance_id()]),
        "paused":not app.running,"savingDisabled":not app.persistence_enabled}

func screen_bounds(source: MeshInstance3D) -> Rect2:
    var rect := Rect2()
    for corner in 8:
        var position: Vector3 = source.global_transform * source.get_aabb().get_endpoint(corner)
        var point: Vector2 = app.world.camera.unproject_position(position)
        if corner == 0: rect = Rect2(point,Vector2.ZERO)
        else: rect = rect.expand(point)
    return rect

func prepare_variant() -> void:
    var ground: MultiMeshInstance3D = app.world._box_batches[0]
    ground.multimesh = original
    variant = "A"
    if ground.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
        fail("Ground unexpectedly casts shadows; no culling allowed")
        return
    if app.world.camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        fail("Conservative screen bounds require the unchanged orthographic camera")
        return
    var sources: Array = app.world._box_batch_sources[0]
    if sources.size() != original.visible_instance_count:
        fail("Ground source and original visible-instance count mismatch")
        return
    var screen := Rect2(Vector2.ZERO,Vector2(app.viewport.size)).grow(MARGIN)
    retained.clear()
    for index in sources.size():
        if screen.intersects(screen_bounds(sources[index]),true): retained.append(index)
    compacted = MultiMesh.new()
    compacted.transform_format = original.transform_format
    compacted.use_colors = original.use_colors
    compacted.use_custom_data = original.use_custom_data
    compacted.mesh = original.mesh
    compacted.instance_count = original.instance_count
    # Headless Godot's dummy renderer cannot return GPU buffers. Native checks
    # use the unchanged source-state cache and make no rendered-buffer claim.
    if OS.has_feature("web"):
        if original.buffer.is_empty(): fail("Original rendered buffer is unavailable");return
        compacted.buffer = original.buffer
    else:
        for index in sources.size():
            compacted.set_instance_transform(index,app.world._box_batch_states[0][index][1])
            compacted.set_instance_color(index,app.world._box_batch_states[0][index][2])
    for index in retained.size():
        var transform: Transform3D = original.get_instance_transform(retained[index]) if OS.has_feature("web") else app.world._box_batch_states[0][retained[index]][1]
        var color: Color = original.get_instance_color(retained[index]) if OS.has_feature("web") else app.world._box_batch_states[0][retained[index]][2]
        compacted.set_instance_transform(index,transform)
        compacted.set_instance_color(index,color)
        if OS.has_feature("web") and compacted.get_instance_transform(index) != transform:
            fail("Retained transform differs")
        if OS.has_feature("web") and compacted.get_instance_color(index) != color:
            fail("Retained color differs")
    compacted.visible_instance_count = retained.size()
    if compacted.mesh != original.mesh or compacted.instance_count != original.instance_count:
        fail("Mesh or reserved capacity changed")
    anchor = invariant_state()
    if anchor.domain != original_domain: fail("Preparing culling changed domain state")

func status() -> Dictionary:
    var current := invariant_state()
    if current != anchor: fail("Invariant state differs from this camera's A anchor")
    if current.domain != original_domain: fail("Domain state changed")
    return {"sequence":sequence,"ready":ready_for_commands,"view":view_name,
        "variant":variant,"originalCount":original.visible_instance_count,
        "retainedCount":retained.size(),"marginCssPixels":MARGIN,
        "actualVisibleCount":app.world._box_batches[0].multimesh.visible_instance_count,
        "groundBufferHash":hash_bytes(app.world._box_batches[0].multimesh.buffer.to_byte_array()) if OS.has_feature("web") else "unavailable_in_dummy_renderer",
        "invariants":current,"anchor":anchor,"failures":failures,
        "cameraMetrics":app.world.camera_metrics(),"worldViewport":[app.viewport.size.x,app.viewport.size.y],
        "clockScope":"Same paused imported snapshot; main/world decorative process callbacks frozen in both variants"}

func publish() -> void:
    var result := status()
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.FlotraGroundProfileState="+JSON.stringify(result),true)

func invoke(args: Array) -> void:
    if not ready_for_commands or args.is_empty(): return
    var command := str(args[0])
    if command == "A" or command == "B":
        app.world._box_batches[0].multimesh = original if command == "A" else compacted
        variant = command
    elif command == "normal" or command == "near":
        app.world._box_batches[0].multimesh = original
        if command == "near" and app.world._inspection_slot.is_empty():
            if not app.world.begin_equipment_inspection("packing"): fail("Inspection entry failed")
        elif command == "normal" and not app.world._inspection_slot.is_empty():
            app.world.end_equipment_inspection()
        app.hud.set_equipment_inspection(command == "near")
        view_name = command
        prepare_variant()
    elif command != "status":
        fail("Unknown command: "+command)
    sequence += 1
    publish()

func _ready() -> void:
    if not OS.has_feature("web"): get_tree().root.size = Vector2i(390,844)
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://diagnostic/late.json"))
    var decoded = Store.new().decode(fixture.encoded)
    if not decoded.ok: fail("Fixture decode failed");return
    app = Main.new()
    app.persistence_enabled = false
    add_child(app)
    app.set_process(false)
    app.world.set_process(false)
    if not app.sim.import_release_state(decoded.data).ok: fail("Fixture import failed");return
    app.hud.show_play()
    app._update_world_visibility()
    app._resize_world()
    app.hud.refresh()
    app.world.refresh()
    for frame in 8: await get_tree().process_frame
    app._resize_world()
    app.world.refresh()
    for frame in 4: await get_tree().process_frame
    original = app.world._box_batches[0].multimesh
    original_domain = digest(app.sim.export_release_state())
    prepare_variant()
    ready_for_commands = true
    if OS.has_feature("web"):
        callback = JavaScriptBridge.create_callback(invoke)
        JavaScriptBridge.get_interface("window").FlotraGroundProfileInvoke = callback
        app._report_web_viewport()
        publish()
    else:
        # Native structural validation does not stand in for browser pixels/timing.
        var records: Array = [status()]
        for command in ["B","A","near","B","A","normal"]:
            invoke([command])
            records.append(status())
        var output := OS.get_environment("FLOTRA_GROUND_NATIVE_OUTPUT")
        if not output.is_empty():
            var file := FileAccess.open(output,FileAccess.WRITE)
            file.store_string(JSON.stringify({"scope":"Headless structure/domain only","records":records,"failures":failures},"  "))
        print("GROUND_PROFILE_NATIVE_PASS" if failures.is_empty() else "GROUND_PROFILE_NATIVE_FAILED")
        get_tree().quit(0 if failures.is_empty() else 1)

func _process(_delta: float) -> void:
    if ready_for_commands and OS.has_feature("web"):
        JavaScriptBridge.eval("window.FlotraGroundProfileTelemetry="+JSON.stringify({
            "processMs":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
            "drawCalls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
            "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}),true)
